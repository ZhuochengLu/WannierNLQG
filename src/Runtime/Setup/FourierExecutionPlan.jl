const FOURIER_MEMORY_SAFETY_FACTOR = 1.20

const FOURIER_CAPABILITY_LABELS = (
    (:spectrum, SPECTRUM),
    (:energy_differences, ENERGY_DIFFERENCES),
    (:hamiltonian_derivatives, HAMILTONIAN_DERIVATIVES),
    (:hamiltonian_second_derivatives, HAMILTONIAN_SECOND_DERIVATIVES),
    (:wannier_position, WANNIER_POSITION),
    (:internal_connection, INTERNAL_CONNECTION),
    (:internal_connection_derivatives, INTERNAL_CONNECTION_DERIVATIVES),
    (:gauge_correction, GAUGE_CORRECTION),
    (:berry_connection, BERRY_CONNECTION),
    (:wannier_curvature, WANNIER_CURVATURE),
    (:velocity_vertices, VELOCITY_VERTICES),
    (:spin, SPIN),
    (:spin_times_hamiltonian, SPIN_TIMES_HAMILTONIAN),
    (:spin_times_position, SPIN_TIMES_POSITION),
    (:spin_times_hamiltonian_position, SPIN_TIMES_HAMILTONIAN_POSITION),
    (:spin_velocity, SPIN_VELOCITY),
)

const FourierOffsetSignature = Tuple{NTuple{3, Int}, Int}

"""Concrete, explicit Fourier execution contract constructed before the k loop."""
struct FourierExecutionPlan
    backend::Symbol
    grid::Union{Nothing, MixedFourierGrid}
    factor_source::Symbol
    memory_limit_bytes::Int
    estimated_memory_bytes::Int
    load_imbalance::Float64
    blocks_per_rank::Vector{Int}
    kpoints_per_rank::Vector{Int}
    task_signatures::Vector{String}
    union_capabilities::Vector{Symbol}
    union_fourier_groups::Vector{Symbol}
    union_offset_signatures::Vector{String}
    union_group_offset_counts::Vector{NamedTuple}
    symmetry_workload_enabled::Bool
    evaluation_kpoint_count::Int
    response_component_workload::Int
    auto_direct_cost_estimate::Float64
    auto_mixed_cost_estimate::Float64
end

"""
Normalize the required explicit Fourier backend.
"""
function normalized_fourier_backend(cfg::EffectiveTaskConfig)
    backend = Symbol(_canonical_key(cfg.fourier_backend))
    backend in (:mixed, :direct, :auto) || error(
        "fourier_backend=$(repr(cfg.fourier_backend)) is invalid; use direct, mixed, or auto.",
    )
    return backend
end

"""
Format one task signature for execution evidence.
"""
fourier_task_signature(
    spec::NormalizedTaskSpec,
) = "$(spec.quantity)/$(spec.method)/$(spec.calculation)"

"""
Add first-order Cartesian stencil offsets.
"""
function fourier_push_axis_offsets!(
    offsets::Set{FourierOffsetSignature},
    spatial_dimension::Int,
    photon_half_steps::Int = 0,
)
    for axis in 1:spatial_dimension
        forward = ntuple(direction -> direction == axis ? 1 : 0, 3)
        backward = ntuple(direction -> direction == axis ? -1 : 0, 3)
        push!(offsets, (forward, photon_half_steps))
        push!(offsets, (backward, photon_half_steps))
    end
    return offsets
end

"""
Add second-order Cartesian stencil offsets.
"""
function fourier_push_second_offsets!(offsets::Set{FourierOffsetSignature}, spatial_dimension::Int)
    for first_axis in 1:spatial_dimension
        for second_axis in first_axis:spatial_dimension
            for first_sign in (-1, 1), second_sign in (-1, 1)
                coefficients = ntuple(
                    direction ->
                        first_sign * (direction == first_axis) +
                        second_sign * (direction == second_axis),
                    3,
                )
                push!(offsets, (coefficients, 0))
            end
        end
    end
    return offsets
end

"""
Enumerate the exact shifted k-points required by one task.
"""
function fourier_task_offset_signatures(cfg::EffectiveTaskConfig, spec::NormalizedTaskSpec)
    definition = task_definition(spec.quantity, spec.method, spec.calculation)
    definition === nothing && error("Missing TaskDefinition for $(spec.label).")
    policy = definition.fourier_policy
    finite_q =
        policy == FOURIER_GEOMETRIC_FINITE_Q && any(value -> !iszero(value), cfg.photon_momentum)
    offsets =
        finite_q ? Set{FourierOffsetSignature}() : Set{FourierOffsetSignature}([((0, 0, 0), 0)])
    spatial_dimension = cfg.spatial_dimension
    if !finite_q && policy == FOURIER_PROJECTOR
        fourier_push_axis_offsets!(offsets, spatial_dimension)
        for first_axis in 1:(spatial_dimension - 1)
            for second_axis in (first_axis + 1):spatial_dimension
                forward = ntuple(
                    direction -> direction == first_axis || direction == second_axis ? 1 : 0,
                    3,
                )
                backward = ntuple(
                    direction -> direction == first_axis || direction == second_axis ? -1 : 0,
                    3,
                )
                push!(offsets, (forward, 0))
                push!(offsets, (backward, 0))
            end
        end
    elseif !finite_q && policy in (FOURIER_GEOMETRIC_Q0, FOURIER_WILSON)
        fourier_push_axis_offsets!(offsets, spatial_dimension)
    end

    if spec.quantity in
       (:berry_curvature_dipole, :quantum_metric_dipole, :quantum_christoffel_symbol)
        fourier_push_axis_offsets!(offsets, spatial_dimension)
    elseif spec.quantity in (:berry_curvature_quadrupole, :quantum_metric_quadrupole)
        fourier_push_axis_offsets!(offsets, spatial_dimension)
        fourier_push_second_offsets!(offsets, spatial_dimension)
    end

    if finite_q
        for photon_half_steps in (-1, 1)
            push!(offsets, ((0, 0, 0), photon_half_steps))
            spec.quantity == :photon_drag_shift_current &&
                fourier_push_axis_offsets!(offsets, spatial_dimension, photon_half_steps)
        end
    end
    return offsets
end

"""
Serialize one offset for metadata.
"""
function fourier_offset_string(offset::FourierOffsetSignature)
    coefficients, photon_half_steps = offset
    return "fd=$(coefficients);photon_half_steps=$(photon_half_steps)"
end

"""
Test whether an offset is the central k-point.
"""
fourier_is_central_offset(offset::FourierOffsetSignature) = offset == ((0, 0, 0), 0)

"""
Reduce shifted-point capabilities without changing the provider union plan.
"""
function fourier_reduced_offset_plan(
    cfg::EffectiveTaskConfig,
    spec::NormalizedTaskSpec,
    offset::FourierOffsetSignature,
    central_plan::MatrixElementPlan,
)
    fourier_is_central_offset(offset) && return central_plan
    finite_difference_coefficients, _ = offset
    any(value -> !iszero(value), finite_difference_coefficients) || return central_plan
    definition = task_definition(spec.quantity, spec.method, spec.calculation)
    definition === nothing && error("Missing TaskDefinition for $(spec.label).")
    capability =
        definition.fourier_policy == FOURIER_PROJECTOR ? SPECTRUM :
        definition.fourier_policy == FOURIER_WILSON ? BERRY_CONNECTION : nothing
    capability === nothing && return central_plan
    return compile_matrix_plan(
        MatrixElementRequest(
            capability;
            spatial_dimension = cfg.spatial_dimension,
            denominator_regularization = cfg.denominator_regularization,
            degeneracy_threshold = cfg.degeneracy_threshold,
        ),
        central_plan.direction_requirements,
        wannier_center_convention = central_plan.wannier_center_convention,
    )
end

"""Return the exact offset-to-provider-group graph used by explicit Mixed-FFT."""
function fourier_task_offset_graph(
    cfg::EffectiveTaskConfig,
    spec::NormalizedTaskSpec,
    provider_plan::MatrixElementPlan = bundle_matrix_element_plan(NormalizedTaskSpec[spec], cfg),
)
    graph = Dict{FourierOffsetSignature, Vector{Symbol}}()
    for offset in fourier_task_offset_signatures(cfg, spec)
        layout = MixedFourierLayout(fourier_reduced_offset_plan(cfg, spec, offset, provider_plan))
        graph[offset] = copy(layout.groups)
    end
    return graph
end

"""
List capabilities owned by the fused provider plan.
"""
function fourier_union_capabilities(plan::MatrixElementPlan)
    return Symbol[
        label for
        (label, capability) in FOURIER_CAPABILITY_LABELS if has_capability(plan, capability)
    ]
end

"""
Merge per-task offset graphs for memory preflight.
"""
function fourier_union_offset_summary(
    cfg::EffectiveTaskConfig,
    specs::Vector{NormalizedTaskSpec},
    union_plan::MatrixElementPlan,
)
    union_offsets = Set{FourierOffsetSignature}()
    union_offset_groups = Dict{FourierOffsetSignature, Set{Symbol}}()
    for spec in specs
        graph = fourier_task_offset_graph(cfg, spec, union_plan)
        union!(union_offsets, keys(graph))
        for (offset, groups) in graph
            union!(get!(union_offset_groups, offset, Set{Symbol}()), groups)
        end
    end
    group_counts = Dict{Symbol, Int}()
    for groups in values(union_offset_groups), group in groups
        group_counts[group] = get(group_counts, group, 0) + 1
    end
    summary = NamedTuple[
        (group = group, offset_count = group_counts[group]) for
        group in sort!(collect(keys(group_counts)))
    ]
    return (
        offsets = sort!(fourier_offset_string.(collect(union_offsets))),
        groups = sort!(collect(keys(group_counts))),
        group_counts = summary,
    )
end

"""
Estimate resident Mixed-FFT buffers for the exact union offset graph.
"""
function fourier_offset_memory_estimate(
    grid::MixedFourierGrid,
    workspace::MatrixElementWorkspace,
    model::TightBindingModel,
    group_offset_counts::Vector{NamedTuple},
)
    base =
        mixed_fourier_buffer_estimate(grid, workspace, model; offset_count = 1, safety_factor = 1.0)
    bytes_by_group = Dict(item.group => item.bytes for item in base.group_bytes)
    raw_bytes =
        sum(get(bytes_by_group, item.group, 0) * item.offset_count for item in group_offset_counts)
    return ceil(Int, FOURIER_MEMORY_SAFETY_FACTOR * raw_bytes)
end

"""
Calculate deterministic MPI block ownership for explicit factors.
"""
function fourier_rank_load(nkdiv::NTuple{3, Int}, nkfft::NTuple{3, Int}, ranks::Int)
    ranks > 0 || error("MPI rank count must be positive; got $(ranks).")
    blocks = prod(nkdiv)
    block_points = prod(nkfft)
    quotient, remainder = divrem(blocks, ranks)
    blocks_per_rank = Int[quotient + (rank < remainder ? 1 : 0) for rank in 0:(ranks - 1)]
    points_per_rank = block_points .* blocks_per_rank
    average_points = blocks * block_points / ranks
    return (
        blocks_per_rank = blocks_per_rank,
        points_per_rank = points_per_rank,
        load_imbalance = maximum(points_per_rank; init = 0) / max(average_points, 1.0),
    )
end

"""Construct one direct execution plan with auditable selection evidence."""
function _direct_fourier_execution_plan(
    task_signatures;
    factor_source::Symbol = :not_applicable,
    symmetry_workload_enabled::Bool = false,
    evaluation_kpoint_count::Int = 0,
    response_component_workload::Int = 0,
    auto_direct_cost_estimate::Float64 = 0.0,
    auto_mixed_cost_estimate::Float64 = 0.0,
)
    return FourierExecutionPlan(
        :direct,
        nothing,
        factor_source,
        0,
        0,
        1.0,
        Int[],
        Int[],
        task_signatures,
        Symbol[],
        Symbol[],
        String[],
        NamedTuple[],
        symmetry_workload_enabled,
        evaluation_kpoint_count,
        response_component_workload,
        auto_direct_cost_estimate,
        auto_mixed_cost_estimate,
    )
end

# Estimate Direct work from representative k points and raw components.
function _response_symmetry_direct_cost(
    model::TightBindingModel,
    workspace::MatrixElementWorkspace,
    evaluation_kpoint_count::Int,
    response_component_workload::Int,
)
    channels = MixedFourierLayout(workspace.plan).channel_count
    return Float64(
        evaluation_kpoint_count * (model.num_r_vectors * channels + response_component_workload),
    )
end

# Estimate Mixed-FFT work from occupied blocks and response workload.
function _response_symmetry_mixed_cost(
    grid::MixedFourierGrid,
    model::TightBindingModel,
    workspace::MatrixElementWorkspace,
    evaluation_kpoint_indices::Vector{Int},
    response_component_workload::Int,
)
    blocks = Set{NTuple{3, Int}}()
    for index in evaluation_kpoint_indices
        zero_index = index - 1
        logical = (
            zero_index % grid.mesh[1],
            (zero_index ÷ grid.mesh[1]) % grid.mesh[2],
            zero_index ÷ (grid.mesh[1] * grid.mesh[2]),
        )
        push!(blocks, ntuple(axis -> mod(logical[axis], grid.nkdiv[axis]), 3))
    end
    channels = MixedFourierLayout(workspace.plan).channel_count
    fft_points = prod(grid.nkfft)
    fft_work = fft_points * max(log2(max(fft_points, 2)), 1.0)
    block_work = model.num_r_vectors * channels + fft_work * channels
    extraction_work = length(evaluation_kpoint_indices) * channels
    response_work = length(evaluation_kpoint_indices) * response_component_workload
    return length(blocks) * block_work + extraction_work + response_work
end

"""Build a Direct, Mixed, or deterministic Auto/fallback plan before the k loop."""
function build_fourier_execution_plan(
    cfg::EffectiveTaskConfig,
    specs::Vector{NormalizedTaskSpec},
    model::TightBindingModel,
    workspace::MatrixElementWorkspace,
    ranks::Int,
    workers::Int,
    grid_builder::Function,
    ;
    evaluation_kpoint_indices::Union{Nothing, AbstractVector{<:Integer}} = nothing,
    response_component_workload::Integer = 0,
    rank_memory_limit_bytes::Int = mixed_fourier_memory_limit(),
)
    backend = normalized_fourier_backend(cfg)
    task_signatures = fourier_task_signature.(specs)
    auto_requested = backend == :auto
    symmetry_workload_enabled = evaluation_kpoint_indices !== nothing
    evaluation_indices =
        symmetry_workload_enabled ? Int[x for x in evaluation_kpoint_indices] : Int[]
    isempty(evaluation_indices) &&
        symmetry_workload_enabled &&
        error("response-symmetry Fourier workload requires at least one representative k point.")
    full_kpoint_count = prod(cfg.k_mesh)
    all(index -> 1 <= index <= full_kpoint_count, evaluation_indices) ||
        error("response-symmetry Fourier workload contains an out-of-range k-point index.")
    component_workload = Int(response_component_workload)
    component_workload >= 0 || error("response_component_workload must be non-negative.")
    evaluation_count = symmetry_workload_enabled ? length(evaluation_indices) : 0
    direct_cost =
        symmetry_workload_enabled ?
        _response_symmetry_direct_cost(model, workspace, evaluation_count, component_workload) : 0.0
    if backend == :direct || (auto_requested && cfg.NKdiv === nothing && cfg.NKFFT === nothing)
        factor_source = auto_requested ? :auto_direct_no_factors : :not_applicable
        return _direct_fourier_execution_plan(
            task_signatures;
            factor_source,
            symmetry_workload_enabled,
            evaluation_kpoint_count = evaluation_count,
            response_component_workload = component_workload,
            auto_direct_cost_estimate = direct_cost,
        )
    end

    workers > 0 || error("Julia worker count must be positive; got $(workers).")
    grid, reason = grid_builder(cfg.NKdiv, cfg.NKFFT)
    if grid === nothing
        auto_requested && return _direct_fourier_execution_plan(
            task_signatures;
            factor_source = :auto_fallback_grid,
            symmetry_workload_enabled,
            evaluation_kpoint_count = evaluation_count,
            response_component_workload = component_workload,
            auto_direct_cost_estimate = direct_cost,
        )
        error("Explicit Mixed-FFT is unavailable: $(reason)")
    end
    union = fourier_union_offset_summary(cfg, specs, workspace.plan)
    rank_memory_limit_bytes > 0 || error("Mixed per-rank memory budget must be positive.")
    memory_limit_bytes = max(1, div(mixed_fourier_memory_limit(), workers))
    estimated_memory_bytes =
        fourier_offset_memory_estimate(grid, workspace, model, union.group_counts)
    if estimated_memory_bytes > memory_limit_bytes
        auto_requested && return _direct_fourier_execution_plan(
            task_signatures;
            factor_source = :auto_fallback_memory,
            symmetry_workload_enabled,
            evaluation_kpoint_count = evaluation_count,
            response_component_workload = component_workload,
            auto_direct_cost_estimate = direct_cost,
        )
        error(
            "Explicit Mixed-FFT estimated buffers=$(estimated_memory_bytes) bytes exceed " *
            "per-workspace limit=$(memory_limit_bytes) bytes. Choose smaller NKFFT/larger NKdiv " *
            "or raise WANNIERNLQG_MIXED_MEMORY_LIMIT_BYTES.",
        )
    end
    mixed_cost =
        symmetry_workload_enabled ?
        _response_symmetry_mixed_cost(
            grid,
            model,
            workspace,
            evaluation_indices,
            component_workload,
        ) : 0.0
    if auto_requested && symmetry_workload_enabled && mixed_cost >= direct_cost
        return _direct_fourier_execution_plan(
            task_signatures;
            factor_source = :auto_fallback_symmetry_workload_cost,
            symmetry_workload_enabled,
            evaluation_kpoint_count = evaluation_count,
            response_component_workload = component_workload,
            auto_direct_cost_estimate = direct_cost,
            auto_mixed_cost_estimate = mixed_cost,
        )
    end
    load = fourier_rank_load(grid.nkdiv, grid.nkfft, ranks)
    memory_limit_bytes = max(1, div(rank_memory_limit_bytes, workers))
    estimated_memory_bytes <= memory_limit_bytes || error(
        "Mixed-FFT estimated buffers=$(estimated_memory_bytes) bytes exceed the concurrent " *
        "task's per-workspace budget=$(memory_limit_bytes) bytes. Reduce the task count or " *
        "NKFFT, or raise WANNIERNLQG_MIXED_MEMORY_LIMIT_BYTES. Auto backend selection is " *
        "not changed by other tasks.",
    )
    return FourierExecutionPlan(
        :mixed,
        grid,
        auto_requested ? Symbol("auto_" * String(grid.factor_source)) : grid.factor_source,
        memory_limit_bytes,
        estimated_memory_bytes,
        load.load_imbalance,
        load.blocks_per_rank,
        load.points_per_rank,
        task_signatures,
        fourier_union_capabilities(workspace.plan),
        union.groups,
        union.offsets,
        union.group_counts,
        symmetry_workload_enabled,
        evaluation_count,
        component_workload,
        direct_cost,
        mixed_cost,
    )
end
