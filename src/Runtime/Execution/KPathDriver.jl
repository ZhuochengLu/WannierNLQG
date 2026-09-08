"""Normalized high-symmetry path with shared endpoints represented once."""
struct KPathPlan
    labels::Vector{String}
    nodes::Vector{NTuple{3, Float64}}
    kpoints_per_segment::Vector{Int}
    kpoints::Matrix{Float64}
    cumulative_distances::Vector{Float64}
    node_indices::Vector{Int}
end

"""Collected k-resolved values and diagnostics in deterministic global path order."""
struct KPathExecutionResult
    values::Matrix{Float64}
    residuals::Vector{Float64}
    mpi_size::Int
    worker_count::Int
end

"""Build an unfurled fractional path using the package row-lattice convention."""
function make_kpath_plan(cfg::EffectiveTaskConfig, lattice::AbstractMatrix{<:Real})
    reciprocal = reciprocal_lattice(lattice)
    labels = first.(cfg.kpath_nodes)
    nodes = last.(cfg.kpath_nodes)
    point_count = sum(cfg.kpoints_per_segment) - length(cfg.kpoints_per_segment) + 1
    kpoints = Matrix{Float64}(undef, point_count, 3)
    node_indices = Vector{Int}(undef, length(nodes))
    cursor = 0
    for segment in eachindex(cfg.kpoints_per_segment)
        start_node = nodes[segment]
        stop_node = nodes[segment + 1]
        count = cfg.kpoints_per_segment[segment]
        node_indices[segment] = segment == 1 ? 1 : cursor
        for local_index in 1:count
            segment > 1 && local_index == 1 && continue
            cursor += 1
            fraction = (local_index - 1) / (count - 1)
            for axis in 1:3
                kpoints[cursor, axis] =
                    (1.0 - fraction) * start_node[axis] + fraction * stop_node[axis]
            end
        end
    end
    node_indices[end] = point_count
    cursor == point_count || error("internal KPath point-count mismatch")
    for node in eachindex(nodes)
        maximum(abs, @view(kpoints[node_indices[node], :]) .- collect(nodes[node])) <= 1.0e-14 ||
            error("normalized KPath is discontinuous at node $(node)")
    end
    distances = zeros(Float64, point_count)
    for point in 2:point_count
        delta = @view(kpoints[point, :]) .- @view(kpoints[point - 1, :])
        distances[point] = distances[point - 1] + norm(delta' * reciprocal)
    end
    all(isfinite, distances) || error("KPath distances are non-finite")
    return KPathPlan(
        copy(labels),
        copy(nodes),
        copy(cfg.kpoints_per_segment),
        kpoints,
        distances,
        node_indices,
    )
end

# Build the geometry-only high-symmetry path sidecar payload.
function _kpath_payload(plan::KPathPlan)
    nodes = [
        (
            label = plan.labels[index],
            fractional_coordinates = collect(plan.nodes[index]),
            point_index_one_based = plan.node_indices[index],
            cumulative_distance_A_inverse = plan.cumulative_distances[plan.node_indices[index]],
        ) for index in eachindex(plan.nodes)
    ]
    segments = [
        (
            segment_index_one_based = index,
            start_node_index_one_based = index,
            end_node_index_one_based = index + 1,
            start_point_index_one_based = plan.node_indices[index],
            end_point_index_one_based = plan.node_indices[index + 1],
            kpoints_including_endpoints = plan.kpoints_per_segment[index],
        ) for index in eachindex(plan.kpoints_per_segment)
    ]
    return (
        schema = "wanniernlqg.kpath",
        schema_version = "1.0",
        node_chain = nodes,
        segments = segments,
        total_kpoints = size(plan.kpoints, 1),
        shared_segment_endpoints_written_once = true,
        fractional_coordinates_folded = false,
        lattice_convention = "row-lattice",
        reciprocal_lattice_convention = "B=2pi*A^(-T)",
        distance_unit = "A^-1",
    )
end

# Atomically serialize a deterministic geometry sidecar using the Runtime encoder.
function _write_kpath_json(path::AbstractString, plan::KPathPlan)
    isdir(dirname(path)) || mkpath(dirname(path))
    temporary, stream = mktemp(dirname(path); cleanup = false)
    try
        println(stream, progress_json_value(_kpath_payload(plan)))
        close(stream)
        mv(temporary, path; force = true)
    catch
        isopen(stream) && close(stream)
        isfile(temporary) && rm(temporary; force = true)
        rethrow()
    end
    return String(path)
end

"""
Execute one concrete k-resolved kernel over a KPath with deterministic thread and MPI ownership.

The kernel supplies `_kpath_result_width`, `_prepare_kpath_worker`, and
`_evaluate_kpath_point!` methods. This driver owns only sampling and reduction order.
"""
function execute_kpath_driver(kernel::K, plan::KPathPlan, model, comm) where {K}
    rank = bundle_mpi_comm_rank(comm)
    mpi_size = bundle_mpi_comm_size(comm)
    point_count = size(plan.kpoints, 1)
    local_indices = Int[index for index in 1:point_count if mod(index - 1, mpi_size) == rank]
    result_width = _kpath_result_width(kernel, model)
    result_width > 0 || error("KPath kernel result width must be positive")

    worker_count = Threads.nthreads()
    workers = [_prepare_kpath_worker(kernel, model) for _ in 1:worker_count]
    local_values = fill(NaN, length(local_indices), result_width)
    local_residuals = fill(NaN, length(local_indices))
    thread_errors = fill("", worker_count)
    Threads.@threads :static for worker in 1:worker_count
        try
            for local_position in worker:worker_count:length(local_indices)
                global_index = local_indices[local_position]
                local_residuals[local_position] = _evaluate_kpath_point!(
                    @view(local_values[local_position, :]),
                    kernel,
                    workers[worker],
                    model,
                    @view(plan.kpoints[global_index, :]),
                )
            end
        catch exception
            thread_errors[worker] = sprint(showerror, exception, catch_backtrace())
        end
    end
    local_error = join(filter(value -> !isempty(value), thread_errors), "\n")
    local_packet = (
        ok = isempty(local_error),
        error = local_error,
        indices = local_indices,
        values = local_values,
        residuals = local_residuals,
    )

    values = rank == 0 ? Matrix{Float64}(undef, point_count, result_width) : zeros(0, 0)
    residuals = rank == 0 ? Vector{Float64}(undef, point_count) : Float64[]
    failures = String[]
    for owner in 0:(mpi_size - 1)
        packet = bundle_mpi_bcast(rank == owner ? local_packet : nothing, owner, comm)
        if packet.ok
            if rank == 0
                values[packet.indices, :] .= packet.values
                residuals[packet.indices] .= packet.residuals
            end
        else
            push!(failures, "rank $(owner): $(packet.error)")
        end
    end
    isempty(failures) ||
        error("KPath task failed before output publication:\n" * join(failures, "\n"))
    return KPathExecutionResult(values, residuals, mpi_size, worker_count)
end
