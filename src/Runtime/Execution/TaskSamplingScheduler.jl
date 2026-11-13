"""Opt-in measurements of one shared point invocation; phase times can overlap.

These counters do not select physical work, own MPI resources, or change point/lane
order. A shared invocation is recorded as shared, never divided into task timings.
"""
Base.@kwdef mutable struct PreparedExecutionDiagnostics
    wall_seconds::Float64 = 0.0
    allocated_bytes::Int = 0
    gc_seconds::Float64 = 0.0
    compile_seconds::Float64 = 0.0
    recompile_seconds::Float64 = 0.0
    matrix_seconds::Float64 = 0.0
    eigensystem_seconds::Float64 = 0.0
    generations::Int = 0
    diagonalizations::Int = 0
    fourier_evaluations::Int = 0
    fourier_hits::Int = 0
    spectrum_hits::Int = 0
    coexecuted_tasks::Int = 0
end

"""
Prepared response instance with its original point/lane ownership and private state.

Each work unit is `(global_point, local_evaluation, deterministic_lane)`. The point
callback consumes one worker slot; finalization performs the unchanged reduction.
The cleanup callback detaches registrations and owned input storage idempotently.
"""
struct PreparedResponseTask{E, F, C, D, P}
    units::Vector{NTuple{3, Int}}
    execute_point!::E
    finish!::F
    cleanup!::C
    point_order::Union{Nothing, Dict{Int, Int}}
    interpolation_limits::Union{Nothing, NTuple{2, Int}}
    execution_diagnostics::D
    point_evaluators::P
end

# Existing tasks retain their physical mesh ordering unless explicitly prepared otherwise.
PreparedResponseTask(units, execute_point!, finish!, cleanup!; point_evaluators = nothing) =
    PreparedResponseTask(
        units,
        execute_point!,
        finish!,
        cleanup!,
        nothing,
        nothing,
        nothing,
        point_evaluators,
    )

# Existing complete scheduler construction has no independently exposed point plan.
PreparedResponseTask(
    units,
    execute_point!,
    finish!,
    cleanup!,
    point_order,
    interpolation_limits,
    diagnostics,
) = PreparedResponseTask(
    units,
    execute_point!,
    finish!,
    cleanup!,
    point_order,
    interpolation_limits,
    diagnostics,
    nothing,
)

# Existing prepared tasks keep their original cache policy unless a paired path declares bounds.
PreparedResponseTask(units, execute_point!, finish!, cleanup!, point_order) =
    PreparedResponseTask(units, execute_point!, finish!, cleanup!, point_order, nothing)

# Existing six-argument preparation keeps diagnostics disabled and its exact lane order.
PreparedResponseTask(units, execute_point!, finish!, cleanup!, point_order, interpolation_limits) =
    PreparedResponseTask(
        units,
        execute_point!,
        finish!,
        cleanup!,
        point_order,
        interpolation_limits,
        nothing,
    )

"""Find a scheduling component without changing its deterministic root."""
function sampling_component_root!(parents::Vector{Int}, index::Int)
    while parents[index] != index
        parents[index] = parents[parents[index]]
        index = parents[index]
    end
    return index
end

"""
Partition shared points without splitting any task's deterministic reduction lane.

Connected components unite points belonging to one task lane. Components may run
on separate workers, while points within a component follow the original monotone
mesh order. Task-specific MPI ownership is already encoded by each unit list.
"""
function sampling_components(prepared)
    selected_order = length(prepared) == 1 ? only(prepared).point_order : nothing
    any(task -> task.point_order !== nothing, prepared) &&
        length(prepared) != 1 &&
        error("Block-local scheduling requires a single prepared task")
    order(point) = selected_order === nothing ? point : selected_order[point]
    # Keep the integer point collection independent of erased callback types.
    # Preserve traversal, first-occurrence deduplication and final point order.
    points = Int[]
    for task in prepared
        for unit in task.units
            push!(points, unit[1])
        end
    end
    sort!(unique!(points); by = order)
    positions = Dict(point => index for (index, point) in enumerate(points))
    parents = collect(eachindex(points))
    visits = [Tuple{Int, Int, Int}[] for _ in points]
    for (task_index, task) in enumerate(prepared)
        lane_roots = Dict{Int, Int}()
        previous_by_lane = Dict{Int, Int}()
        for (point, evaluation, lane) in task.units
            order(point) > get(previous_by_lane, lane, 0) ||
                error("Task lane must preserve its declared deterministic point order")
            previous_by_lane[lane] = order(point)
            position = positions[point]
            push!(visits[position], (task_index, evaluation, lane))
            if haskey(lane_roots, lane)
                first_root = sampling_component_root!(parents, lane_roots[lane])
                second_root = sampling_component_root!(parents, position)
                parents[max(first_root, second_root)] = min(first_root, second_root)
            else
                lane_roots[lane] = position
            end
        end
    end
    grouped = Dict{Int, Vector{Int}}()
    for position in eachindex(points)
        root = sampling_component_root!(parents, position)
        push!(get!(grouped, root, Int[]), position)
    end
    components = [grouped[root] for root in sort!(collect(keys(grouped)))]
    return components, visits
end

"""Execute original point/lane visits with worker-private caches and unchanged order."""
function _execute_prepared_workers!(prepared, components, visits, caches, workers)
    Threads.@threads :static for worker in 1:workers
        for component_index in worker:workers:length(components)
            for position in components[component_index]
                cache = caches[worker]
                MatrixElements.begin_shared_interpolation!(cache)
                MatrixElements.with_shared_interpolation(cache) do
                    for (task_index, evaluation, lane) in visits[position]
                        prepared[task_index].execute_point!(worker, evaluation, lane)
                    end
                end
            end
        end
    end
    return nothing
end

"""
Evaluate all instances through a shared point scheduler and worker-local caches.

No response state or reduction lane is shared between workers. Cache generations
end at each central mesh point, bounding storage independently of mesh size.
"""
function execute_prepared_tasks!(prepared)
    components, visits = sampling_components(prepared)
    workers = Threads.nthreads()
    limits =
        [task.interpolation_limits for task in prepared if task.interpolation_limits !== nothing]
    max_entries = isempty(limits) ? typemax(Int) : minimum(first, limits)
    max_bytes = isempty(limits) ? typemax(Int) : minimum(last, limits)
    caches = [
        MatrixElements.SharedInterpolationCache(;
            reuse = length(prepared) > 1 || !isempty(limits),
            max_entries,
            max_bytes,
            measure_timings = fourier_timing_enabled() || !isempty(limits),
        ) for _ in 1:workers
    ]
    diagnose = any(task -> task.execution_diagnostics !== nothing, prepared)
    measured = if diagnose
        @timed _execute_prepared_workers!(prepared, components, visits, caches, workers)
    else
        _execute_prepared_workers!(prepared, components, visits, caches, workers)
        nothing
    end
    if diagnose
        for task in prepared
            d = task.execution_diagnostics
            d === nothing && continue
            d.wall_seconds = measured.time
            d.allocated_bytes = measured.bytes
            d.gc_seconds = measured.gctime
            d.compile_seconds = measured.compile_time
            d.recompile_seconds = measured.recompile_time
            d.matrix_seconds = sum(cache.matrix_seconds for cache in caches)
            d.eigensystem_seconds = sum(cache.eigensystem_seconds for cache in caches)
            d.generations = sum(cache.generations for cache in caches)
            d.diagonalizations = sum(cache.diagonalizations for cache in caches)
            d.fourier_evaluations = sum(cache.fourier_evaluations for cache in caches)
            d.fourier_hits = sum(cache.fourier_hits for cache in caches)
            d.spectrum_hits = sum(cache.spectrum_hits for cache in caches)
            d.coexecuted_tasks = length(prepared)
        end
    end
    stats = MatrixElements.shared_interpolation_stats.(caches)
    return stats
end
