using Base.Threads

"""
Output paths and family/Fourier/symmetry/band/replica summaries returned after the shared k loop and output stage.
"""
struct FusedBundleRunResult
    outputs::Vector{String}
    matrix_families::Vector{String}
    family_counts::Vector{NamedTuple}
    fourier_summary::NamedTuple
    response_symmetry_summary::NamedTuple
    band_summary::NamedTuple
    replica_summary::NamedTuple
end

"""
A family label with atomic active/skipped point counters; the label-only constructor starts both counters at zero.
"""
mutable struct BundleFamilyCounter
    label::String
    active::Threads.Atomic{Int}
    skipped::Threads.Atomic{Int}
end

# Initialize independent atomic counters for a newly encountered family label.
BundleFamilyCounter(label::String) =
    BundleFamilyCounter(label, Threads.Atomic{Int}(0), Threads.Atomic{Int}(0))

"""
Requested Cartesian indices and the deduplicated first/second derivative axes needed for one tensor component.
"""
struct ResponseComponentPlan
    tensor_indices::Vector{Int}
    derivative_axes::Vector{Int}
    projector_axes::Vector{Int}
    projector_axis_pairs::Vector{Tuple{Int64, Int64}}
end

"""
Construct response component plan.
"""
function make_response_component_plan(tensor_indices::AbstractVector{<:Integer})
    length(tensor_indices) >= 3 || error(
        "A response component plan requires at least three tensor indices; got $(tensor_indices).",
    )
    indices = Int[x for x in tensor_indices]
    a = indices[1]
    b = indices[end - 1]
    c = indices[end]
    projector_axes = sort!(unique!(Int[a, b, c]))
    projector_axis_pairs = Tuple{Int64, Int64}[]
    for other in (b, c)
        other == a && continue
        pair = a < other ? (Int64(a), Int64(other)) : (Int64(other), Int64(a))
        pair in projector_axis_pairs || push!(projector_axis_pairs, pair)
    end
    return ResponseComponentPlan(indices, Int[a], projector_axes, projector_axis_pairs)
end

"""
One central eigensystem, occupations, delta weights and stable n-major/m-major active-pair lists with valid-prefix lengths.

Mutable masks and band-window bounds belong to one worker and are refreshed before kernel evaluation.
"""
mutable struct TransitionScreenWorkspace{W, D}
    matrix_elements::W
    data::D
    occupations::Vector{Float64}
    occupation_differences::Matrix{Float64}
    delta::Array{Float64, 3}
    active_pair_mask::Matrix{Bool}
    active_pairs_mmajor::Vector{NTuple{2, Int}}
    active_pairs_mmajor_length::Int
    active_pairs_nmajor::Vector{NTuple{2, Int}}
    active_pairs_nmajor_length::Int
    derivative_required_pairs_nmajor::Vector{NTuple{2, Int}}
    derivative_required_pairs_nmajor_length::Int
    eligible_pair_count::Int
    use_active_pair_list::Bool
    active_bands::BitVector
    band_start::Int64
    band_end::Int64
    has_bands::Bool
    active::Bool
end

"""
Construct transition screen workspace.
"""
function make_transition_screen_workspace(
    num_orbitals::Int64,
    num_r_vectors::Int64,
    num_photon_energies::Int64;
    matrix_elements = nothing,
    central_data = nothing,
)
    if matrix_elements === nothing
        plan = compile_matrix_plan(MatrixElementRequest(SPECTRUM))
        matrix_elements = MatrixElementWorkspace(num_orbitals, num_r_vectors, plan)
    end
    data = central_data === nothing ? matrix_elements.data : central_data
    return TransitionScreenWorkspace(
        matrix_elements,
        data,
        zeros(Float64, num_orbitals),
        zeros(Float64, num_orbitals, num_orbitals),
        zeros(Float64, num_photon_energies, num_orbitals, num_orbitals),
        fill(false, num_orbitals, num_orbitals),
        Vector{NTuple{2, Int}}(undef, num_orbitals^2),
        0,
        Vector{NTuple{2, Int}}(undef, num_orbitals^2),
        0,
        Vector{NTuple{2, Int}}(undef, num_orbitals^2),
        0,
        0,
        false,
        falses(num_orbitals),
        1,
        0,
        false,
        false,
    )
end

"""
Separate valence/conduction momenta, energies/occupations and band windows with cross-leg delta weights and active-pair lists.

Valid prefix lengths delimit reusable pair storage; each worker owns its own masks and buffers.
"""
mutable struct PhotonDragTransitionScreenWorkspace{W, D}
    matrix_elements::W
    valence_data::D
    conduction_data::D
    valence_kpoint::Vector{Float64}
    conduction_kpoint::Vector{Float64}
    valence_occupations::Vector{Float64}
    conduction_occupations::Vector{Float64}
    occupation_differences::Matrix{Float64}
    transition_energies::Matrix{Float64}
    delta::Array{Float64, 3}
    active_pair_mask::Matrix{Bool}
    active_pairs_mmajor::Vector{NTuple{2, Int}}
    active_pairs_mmajor_length::Int
    active_pairs_nmajor::Vector{NTuple{2, Int}}
    active_pairs_nmajor_length::Int
    eligible_pair_count::Int
    use_active_pair_list::Bool
    active_valence_bands::BitVector
    active_conduction_bands::BitVector
    valence_band_start::Int64
    valence_band_end::Int64
    conduction_band_start::Int64
    conduction_band_end::Int64
    has_bands::Bool
    active::Bool
end

"""
Construct photon drag transition screen workspace.
"""
function make_photon_drag_transition_screen_workspace(
    num_orbitals::Int64,
    num_r_vectors::Int64,
    num_photon_energies::Int64;
    matrix_elements = nothing,
    valence_data = nothing,
    conduction_data = nothing,
)
    if matrix_elements === nothing
        plan = compile_matrix_plan(MatrixElementRequest(SPECTRUM))
        matrix_elements = MatrixElementWorkspace(num_orbitals, num_r_vectors, plan)
    end
    valence_common =
        valence_data === nothing ?
        KPointMatrixData(num_orbitals, num_r_vectors, matrix_elements.plan) : valence_data
    conduction_common =
        conduction_data === nothing ?
        KPointMatrixData(num_orbitals, num_r_vectors, matrix_elements.plan) : conduction_data
    return PhotonDragTransitionScreenWorkspace(
        matrix_elements,
        valence_common,
        conduction_common,
        zeros(Float64, 3),
        zeros(Float64, 3),
        zeros(Float64, num_orbitals),
        zeros(Float64, num_orbitals),
        zeros(Float64, num_orbitals, num_orbitals),
        zeros(Float64, num_orbitals, num_orbitals),
        zeros(Float64, num_photon_energies, num_orbitals, num_orbitals),
        fill(false, num_orbitals, num_orbitals),
        Vector{NTuple{2, Int}}(undef, num_orbitals^2),
        0,
        Vector{NTuple{2, Int}}(undef, num_orbitals^2),
        0,
        0,
        false,
        falses(num_orbitals),
        falses(num_orbitals),
        1,
        0,
        1,
        0,
        false,
        false,
    )
end

"""
Per-task deterministic lane tensors and optional reduced symmetry coefficients with local/global buffers and output paths.

Rank-root reduction populates global storage; worker lanes do not share mutable accumulators.
"""
mutable struct IntegralTaskAccumulator{N}
    spec::NormalizedTaskSpec
    outputs::Vector{String}
    worker_data::Vector{Array{ComplexF64, N}}
    local_data::Array{ComplexF64, N}
    global_data::Array{ComplexF64, N}
    tensor_symmetry_plan::Union{Nothing, ResponseTensorSymmetryPlan}
    worker_coefficients::Union{Nothing, Vector{Matrix{ComplexF64}}}
    local_coefficients::Union{Nothing, Matrix{ComplexF64}}
    global_coefficients::Union{Nothing, Matrix{ComplexF64}}
    scratch_data::Union{Nothing, Vector{Array{ComplexF64, N}}}
end

"""
Preserve the pre-response-symmetry construction contract for internal expert
code and tests that create a conventional full-tensor accumulator directly.
"""
function IntegralTaskAccumulator(
    spec::NormalizedTaskSpec,
    outputs::Vector{String},
    worker_data::Vector{Array{ComplexF64, N}},
    local_data::Array{ComplexF64, N},
    global_data::Array{ComplexF64, N},
) where {N}
    return IntegralTaskAccumulator{N}(
        spec,
        outputs,
        worker_data,
        local_data,
        global_data,
        nothing,
        nothing,
        nothing,
        nothing,
        nothing,
    )
end

"""
Per-task band/subspace labels and worker/local/global complex slice matrices with their output paths.

Each logical k point has a unique owner before deterministic reduction.
"""
mutable struct KSliceTaskAccumulator
    spec::NormalizedTaskSpec
    band_label::Union{Nothing, Int, Symbol, String}
    band_group::Union{Nothing, Vector{Int}}
    outputs::Vector{String}
    worker_data::Vector{Matrix{ComplexF64}}
    local_data::Matrix{ComplexF64}
    global_data::Matrix{ComplexF64}
end

"""
Copied Cartesian indices, photon momentum and fractional slice origin/spanning vectors shared by the validated bundle.
"""
struct NormalizedRunControls
    tensor_indices::Vector{Int}
    photon_momentum::Vector{Float64}
    kslice_origin::Vector{Float64}
    kslice_vector_1::Vector{Float64}
    kslice_vector_2::Vector{Float64}
end

# Normalize shared tensor/momentum/slice controls and reject incompatible task ranks or Cartesian axis limits.
function _normalized_run_controls(cfg::EffectiveTaskConfig, specs::Vector{NormalizedTaskSpec})
    ranks = unique(expected_cidx_rank.(specs))
    if length(ranks) != 1
        is_mixed_rank_integral_current_bundle(specs) ||
            error("Mixed tasks require incompatible tensor_indices ranks: got $(ranks).")
        return NormalizedRunControls(
            Int[],
            Float64[x for x in cfg.photon_momentum],
            Float64[x for x in cfg.kslice_origin],
            Float64[x for x in cfg.kslice_vector_1],
            Float64[x for x in cfg.kslice_vector_2],
        )
    end
    limits = unique(Tuple(tensor_axis_limits(spec, cfg.spatial_dimension)) for spec in specs)
    length(limits) == 1 ||
        error("Mixed tasks require incompatible tensor_indices axis limits: got $(limits).")
    return NormalizedRunControls(
        normalize_cartesian_indices(cfg.tensor_indices, collect(first(limits)), "tensor_indices"),
        Float64[x for x in cfg.photon_momentum],
        Float64[x for x in cfg.kslice_origin],
        Float64[x for x in cfg.kslice_vector_1],
        Float64[x for x in cfg.kslice_vector_2],
    )
end

# Return the task's integral or real/imaginary slice output paths, honoring real-only and band/subspace naming contracts.
function _bundle_outputs(
    ctx::RunContext,
    spec::NormalizedTaskSpec;
    band::Union{Nothing, Int, Symbol, String} = nothing,
)
    if spec.calculation == :integral
        return String[result_output_path(ctx, spec.quantity, spec.method, spec.calculation)]
    end
    if is_real_only_kslice_quantity(spec.quantity)
        return String[result_output_path(
            ctx,
            spec.quantity,
            spec.method,
            spec.calculation;
            band = band,
        )]
    end
    return String[
        result_output_path(
            ctx,
            spec.quantity,
            spec.method,
            spec.calculation;
            part = :r,
            band = band,
        ),
        result_output_path(
            ctx,
            spec.quantity,
            spec.method,
            spec.calculation;
            part = :i,
            band = band,
        ),
    ]
end

# Construct integral state.
function _make_integral_state(
    cfg::EffectiveTaskConfig,
    ctx::RunContext,
    spec::NormalizedTaskSpec,
    num_reduction_lanes::Int;
    response_symmetry_plan = nothing,
    num_scratch_workers::Int = Threads.nthreads(),
)
    num_photon_energies = length(cfg.photon_energies)
    axis_sizes = tensor_axis_limits(spec, Int(cfg.spatial_dimension))
    response_size = (num_photon_energies, axis_sizes...)
    tensor_plan =
        response_symmetry_plan === nothing ? nothing :
        response_tensor_symmetry_plan(response_symmetry_plan, spec.quantity)
    worker_data =
        tensor_plan === nothing ?
        [zeros(ComplexF64, response_size) for _ in 1:num_reduction_lanes] :
        Array{ComplexF64, length(response_size)}[]
    coefficient_size =
        tensor_plan === nothing ? nothing :
        (num_photon_energies, size(tensor_plan.basis, 2) + size(tensor_plan.imaginary_basis, 2))
    worker_coefficients =
        tensor_plan === nothing ? nothing :
        [zeros(ComplexF64, coefficient_size) for _ in 1:num_reduction_lanes]
    scratch_data =
        tensor_plan === nothing ? nothing :
        [zeros(ComplexF64, response_size) for _ in 1:num_scratch_workers]
    return IntegralTaskAccumulator(
        spec,
        _bundle_outputs(ctx, spec),
        worker_data,
        zeros(ComplexF64, response_size),
        zeros(ComplexF64, response_size),
        tensor_plan,
        worker_coefficients,
        tensor_plan === nothing ? nothing : zeros(ComplexF64, coefficient_size),
        tensor_plan === nothing ? nothing : zeros(ComplexF64, coefficient_size),
        scratch_data,
    )
end

# Select the lane-owned full tensor or symmetry scratch tensor.
function integral_accumulator_target(
    state::IntegralTaskAccumulator,
    lane_id::Int,
    scratch_worker_id::Int,
)
    return state.tensor_symmetry_plan === nothing ? state.worker_data[lane_id] :
           something(state.scratch_data)[scratch_worker_id]
end

# Return selected Cartesian tuples for a compact response kernel.
function integral_symmetry_component_vectors(state::IntegralTaskAccumulator)
    tensor_plan = state.tensor_symmetry_plan
    tensor_plan === nothing && return nothing
    tensor_plan.accumulation_path == :selected_component_kernel_compact_coefficients ||
        return nothing
    components = response_component_tuples(state.spec.quantity, size(state.global_data, 2))
    return [Int[components[index]...] for index in tensor_plan.raw_component_indices]
end

# Clear thread-local raw-component scratch tensors before one k point.
function prepare_integral_symmetry_scratch!(states, scratch_worker_id::Int)
    for state in states
        state.tensor_symmetry_plan === nothing && continue
        fill!(something(state.scratch_data)[scratch_worker_id], COMPLEX_ZERO)
    end
    return nothing
end

# Contract raw scratch components into lane-owned invariant coefficients.
function accumulate_integral_symmetry_coefficients!(states, lane_id::Int, scratch_worker_id::Int)
    for state in states
        tensor_plan = state.tensor_symmetry_plan
        tensor_plan === nothing && continue
        scratch = something(state.scratch_data)[scratch_worker_id]
        coefficients = something(state.worker_coefficients)[lane_id]
        components = response_component_tuples(state.spec.quantity, size(scratch, 2))
        real_count = size(tensor_plan.basis, 2)
        for energy_index in axes(scratch, 1), basis_index in 1:real_count
            value = 0.0
            for component_index in tensor_plan.raw_component_indices
                component = components[component_index]
                value +=
                    tensor_plan.basis[component_index, basis_index] *
                    real(scratch[energy_index, component...])
            end
            coefficients[energy_index, basis_index] += value
        end
        for energy_index in axes(scratch, 1), basis_index in axes(tensor_plan.imaginary_basis, 2)
            value = 0.0
            for component_index in tensor_plan.raw_component_indices
                component = components[component_index]
                value +=
                    tensor_plan.imaginary_basis[component_index, basis_index] *
                    imag(scratch[energy_index, component...])
            end
            coefficients[energy_index, real_count + basis_index] += value
        end
    end
    return nothing
end

# Reconstruct the complete response tensor from reduced invariant coefficients.
function reconstruct_integral_symmetry_tensor!(state::IntegralTaskAccumulator)
    tensor_plan = state.tensor_symmetry_plan
    tensor_plan === nothing && return state.global_data
    coefficients = something(state.global_coefficients)
    components = response_component_tuples(state.spec.quantity, size(state.global_data, 2))
    fill!(state.global_data, COMPLEX_ZERO)
    for energy_index in axes(state.global_data, 1),
        (component_index, component) in enumerate(components)

        real_value = 0.0
        for basis_index in axes(tensor_plan.basis, 2)
            real_value +=
                tensor_plan.basis[component_index, basis_index] *
                real(coefficients[energy_index, basis_index])
        end
        imaginary_value = 0.0
        real_count = size(tensor_plan.basis, 2)
        for basis_index in axes(tensor_plan.imaginary_basis, 2)
            imaginary_value +=
                tensor_plan.imaginary_basis[component_index, basis_index] *
                real(coefficients[energy_index, real_count + basis_index])
        end
        state.global_data[energy_index, component...] = complex(real_value, imaginary_value)
    end
    return state.global_data
end

# Construct kslice state.
function _make_kslice_state(
    ctx::RunContext,
    spec::NormalizedTaskSpec,
    num_u_points::Int,
    num_v_points::Int,
    num_workers::Int;
    band::Union{Nothing, Int, Symbol, String} = nothing,
    band_group::Union{Nothing, Vector{Int}} = nothing,
)
    worker_data = [zeros(ComplexF64, num_u_points, num_v_points) for _ in 1:num_workers]
    return KSliceTaskAccumulator(
        spec,
        band,
        band_group,
        _bundle_outputs(ctx, spec; band = band),
        worker_data,
        zeros(ComplexF64, num_u_points, num_v_points),
        zeros(ComplexF64, num_u_points, num_v_points),
    )
end

# Return the first accumulator matching a quantity/method pair, or nothing if absent.
function _find_state(states, quantity::Symbol, method::Symbol)
    for state in states
        if state.spec.quantity == quantity && state.spec.method == method
            return state
        end
    end
    return nothing
end

# Find a quantity/method accumulator and assert its expected tensor rank, retaining nothing for absent tasks.
function _find_integral_state(states, quantity::Symbol, method::Symbol, ::Val{N}) where {N}
    state = _find_state(states, quantity, method)
    state === nothing && return nothing
    return state::IntegralTaskAccumulator{N}
end

# Collect all accumulators matching a quantity/method pair in their original order.
function _find_states(states, quantity::Symbol, method::Symbol)
    return [
        state for state in states if state.spec.quantity == quantity && state.spec.method == method
    ]
end

# Test whether the accumulator collection contains a matching quantity/method pair.
function _state_exists(states, quantity::Symbol, method::Symbol)
    return _find_state(states, quantity, method) !== nothing
end
