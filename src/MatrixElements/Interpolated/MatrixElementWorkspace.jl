"""
Spin matrices in `(orbital,orbital,Cartesian,R)` Wannier order with upstream spin units unchanged.

Require exactly three spin components; copy input storage by default or retain it explicitly with `copy_data=false`.
"""
struct SpinRealSpaceData{S <: AbstractArray{ComplexF64, 4}}
    spin_r::S

    function SpinRealSpaceData(spin_r::AbstractArray{ComplexF64, 4}; copy_data::Bool = true)
        size(spin_r, 3) == 3 || throw(ArgumentError("spin_r must have three Cartesian components"))
        values = copy_data ? Array{ComplexF64, 4}(spin_r) : spin_r
        return new{typeof(values)}(values)
    end
end

"""
Maximum absolute q-to-R-to-q roundtrip residual for one transformed operator, in that operator's input units.
"""
struct SpinVelocityTransformDiagnostics
    max_roundtrip_error::Float64
end

"""
Separate maximum absolute roundtrip residuals for spin, spin-Hamiltonian, spin-position and spin-Hamiltonian-position operators.
"""
struct SpinVelocityRealSpaceDiagnostics
    max_spin_roundtrip_error::Float64
    max_spin_hamiltonian_roundtrip_error::Float64
    max_spin_position_roundtrip_error::Float64
    max_spin_hamiltonian_position_roundtrip_error::Float64
end

"""
Peer Wannier real-space spin and spin-weighted Hamiltonian/position arrays with their roundtrip diagnostics.

The spin object is shared with matrix sources; operators retain their upstream spin and eV/length factors.
"""
struct SpinVelocityRealSpaceData{S, H, R, HR}
    spin::S
    spin_hamiltonian_r::H
    spin_position_r::R
    spin_hamiltonian_position_r::HR
    diagnostics::SpinVelocityRealSpaceDiagnostics
end

"""
Complete real-space derivative-overlap tensor
`Dprime[orbital,orbital,mu,beta,R] = <partial_mu 0|partial_beta R>`.

The runtime Projector kernel accepts this source only when the enclosing
operator-bundle manifest proves `full_hilbert_space` completeness.
"""
struct DerivativeOverlapRealSpaceData{D <: AbstractArray{ComplexF64, 5}}
    derivative_overlap_r::D

    function DerivativeOverlapRealSpaceData(
        derivative_overlap_r::AbstractArray{ComplexF64, 5};
        copy_data::Bool = true,
    )
        size(derivative_overlap_r, 3) == 3 && size(derivative_overlap_r, 4) == 3 ||
            throw(ArgumentError("derivative_overlap_r must have two Cartesian dimensions"))
        values = copy_data ? Array{ComplexF64, 5}(derivative_overlap_r) : derivative_overlap_r
        return new{typeof(values)}(values)
    end
end

"""
Optional spin, spin-velocity and full derivative-overlap inputs for capability validation.

If both spin inputs are supplied they must share the same `SpinRealSpaceData` object; otherwise spin is inherited from the spin-velocity source.
"""
struct MatrixElementSources{S, V, D}
    spin::S
    spin_velocity::V
    derivative_overlap::D
end

# Optional spin, spin-velocity and full derivative-overlap inputs for capability validation.
#
# If both spin inputs are supplied they must share the same `SpinRealSpaceData` object; otherwise spin is inherited from the spin-velocity source.
function MatrixElementSources(;
    spin::Union{Nothing, SpinRealSpaceData} = nothing,
    spin_velocity::Union{Nothing, SpinVelocityRealSpaceData} = nothing,
    derivative_overlap::Union{Nothing, DerivativeOverlapRealSpaceData} = nothing,
)
    if spin !== nothing && spin_velocity !== nothing
        spin === spin_velocity.spin ||
            error("spin and spin_velocity must share the same SpinRealSpaceData object.")
    end
    resolved_spin = spin === nothing && spin_velocity !== nothing ? spin_velocity.spin : spin
    return MatrixElementSources(resolved_spin, spin_velocity, derivative_overlap)
end

"""
Cached band energy differences, first/second Cartesian Hamiltonian derivatives and source-gauge derivatives.

Optional fields follow the compiled capability plan; energies use eV and derivatives include the corresponding powers of length.
"""
mutable struct HamiltonianMatrixData{E, D, H, S}
    energy_differences::E
    derivatives::D
    second_derivatives::H
    source_gauge_derivatives::S
end

"""
Capability-selected Wannier/internal/Berry connections, connection derivatives, curvature, and velocity vertices.

Arrays retain their declared Wannier, Hamiltonian or native source gauge; absent capabilities use `nothing` and must not be accessed.
"""
mutable struct PositionMatrixData{W, I, GW, G, N, C, B, F, FH, V, D, S, T}
    wannier_gauge::W
    internal_connection::I
    wannier_connection_derivatives::GW
    internal_connection_derivatives::G
    inverse_energy_differences::N
    gauge_correction::C
    berry_connection::B
    wannier_curvature::F
    hamiltonian_curvature::FH
    velocity_vertices::V
    source_gauge_hamiltonian_derivatives::D
    source_gauge_berry_connection::S
    source_gauge_velocity_vertices::T
end

"""
Reusable Wannier- and Hamiltonian-gauge spin matrices in `(orbital,orbital,Cartesian)` order.

Gauge rotation preserves the spin unit of the upstream SPN/operator source.
"""
mutable struct SpinMatrixData
    wannier_gauge::Array{ComplexF64, 3}
    hamiltonian_gauge::Array{ComplexF64, 3}
end

"""
Energy derivatives, regularized denominators and spin-weighted connection terms used to assemble Hamiltonian-gauge spin velocity.

Trailing axes distinguish velocity and spin directions; all arrays are caller-owned work storage.
"""
mutable struct SpinVelocityMatrixData
    energy_derivatives::Matrix{Float64}
    inverse_energy_differences::Matrix{Float64}
    gauge_correction::Array{ComplexF64, 3}
    spin_times_hamiltonian::Array{ComplexF64, 3}
    spin_times_position::Array{ComplexF64, 4}
    spin_times_hamiltonian_position::Array{ComplexF64, 4}
    connection_term::Array{ComplexF64, 4}
    hamiltonian_connection_term::Array{ComplexF64, 4}
    hamiltonian_gauge::Array{ComplexF64, 4}
end

"""
One reusable eigensystem and capability-selected matrix payload, with Fourier factors, fractional k point and cache-generation mask.

Constructors allocate only the plan's required channels; subsequent evaluations mutate these buffers and invalidate stale capability bits.
"""
mutable struct KPointMatrixData{H, P, S, V}
    spectrum::KPointSpectrum
    fourier_factors::Vector{ComplexF64}
    hamiltonian::H
    position::P
    spin::S
    spin_velocity::V
    computed_mask::UInt64
    generation::UInt64
    kpoint::Vector{Float64}
end

# Expose compatibility matrix-property names through the shared k-point payload; read all other names as stored fields.
function Base.getproperty(data::KPointMatrixData, name::Symbol)
    if name === :num_orbitals
        return length(getfield(data, :spectrum).energies)
    elseif name === :energy_differences
        return getfield(data, :hamiltonian).energy_differences
    elseif name === :hamiltonian_derivatives
        return getfield(data, :hamiltonian).derivatives
    elseif name === :hamiltonian_second_derivatives
        return getfield(data, :hamiltonian).second_derivatives
    elseif name === :inverse_energy_differences
        return getfield(data, :position).inverse_energy_differences
    elseif name === :internal_connection
        return getfield(data, :position).internal_connection
    elseif name === :internal_connection_derivatives
        return getfield(data, :position).internal_connection_derivatives
    elseif name === :gauge_correction
        return getfield(data, :position).gauge_correction
    elseif name === :berry_connection
        return getfield(data, :position).berry_connection
    elseif name === :wannier_curvature
        return getfield(data, :position).wannier_curvature
    elseif name === :hamiltonian_curvature
        return getfield(data, :position).hamiltonian_curvature
    elseif name === :source_gauge_hamiltonian_derivatives
        return getfield(data, :hamiltonian).source_gauge_derivatives
    elseif name === :source_gauge_berry_connection
        return getfield(data, :position).source_gauge_berry_connection
    elseif name === :source_gauge_velocity_vertices
        return getfield(data, :position).source_gauge_velocity_vertices
    elseif name === :velocity_vertices
        return getfield(data, :position).velocity_vertices
    end
    return getfield(data, name)
end

"""
Wannier and real-space first/second Hamiltonian derivative work arrays, compacted to requested Cartesian channels.
"""
mutable struct HamiltonianMatrixScratch{G, H, GR, HR}
    gradient_wannier::G
    hessian_wannier::H
    gradient_real_space::GR
    hessian_real_space::HR
end

"""
Wannier connection, Cartesian derivative and source-frame multiplication scratch selected by the matrix plan.
"""
mutable struct PositionMatrixScratch{W, G, GR, S}
    wannier_gauge::W
    gradient_wannier::G
    gradient_real_space::GR
    source_internal_temporary::S
end

"""
Temporary Wannier-gauge spin matrices for Fourier interpolation before eigensystem rotation.
"""
mutable struct SpinMatrixScratch
    wannier_gauge::Array{ComplexF64, 3}
end

"""
Temporary Wannier-gauge spin-weighted Hamiltonian, position and Hamiltonian-position matrices used during interpolation.
"""
mutable struct SpinVelocityMatrixScratch
    spin_times_hamiltonian_wannier::Array{ComplexF64, 3}
    spin_times_position_wannier::Array{ComplexF64, 3}
    spin_times_hamiltonian_position_wannier::Array{ComplexF64, 3}
end

"""
Shared Fourier factors, Hamiltonian/multiplication buffers, Wannier-center phases and optional capability-specific scratch.

Construction sizes buffers from the compiled plan; this mutable storage must be owned by one execution slot.
"""
mutable struct MatrixElementScratch{H, P, S, V}
    fourier_factors::Vector{ComplexF64}
    hamiltonian_wannier::Matrix{ComplexF64}
    matrix_temporary::Matrix{ComplexF64}
    wannier_centers_cartesian::Matrix{Float64}
    wannier_centers_fractional::Matrix{Float64}
    center_phase_factors::Vector{ComplexF64}
    center_home_r_index::Int
    centers_initialized::Bool
    hamiltonian::H
    position::P
    spin::S
    spin_velocity::V
end

"""
Mutable counts of Fourier transforms, diagonalizations and computations per capability; the default constructor initializes every count to zero.
"""
mutable struct MatrixElementEvaluationCounts
    fourier_transforms::Int
    diagonalizations::Int
    capability_computations::Dict{MatrixElementKind, Int}
end

# Mutable counts of Fourier transforms, diagonalizations and computations per capability; the default constructor initializes every count to zero.
MatrixElementEvaluationCounts() =
    MatrixElementEvaluationCounts(0, 0, Dict(kind => 0 for kind in _ALL_MATRIX_ELEMENT_KINDS))

"""
One execution slot's compiled plan, validated sources, cached k-point data, scratch, preparation flag and counters.

Constructors validate required operator sources and share Fourier-factor storage between data and scratch; do not share a mutable workspace across concurrent evaluations.
"""
mutable struct MatrixElementWorkspace{D, S, I}
    plan::MatrixElementPlan
    sources::I
    data::D
    scratch::S
    prepared::Bool
    counts::MatrixElementEvaluationCounts
end

"""
Offset-keyed k-point cache sharing one matrix workspace; the central slot aliases that workspace's data.

Constructors preallocate requested offsets, while `matrix_data!` allocates additional slots lazily.
"""
mutable struct KPointBatchWorkspace{W, D}
    matrix_elements::W
    slots::Dict{KPointOffset, D}
end

# Offset-keyed k-point cache sharing one matrix workspace; the central slot aliases that workspace's data.
#
# Constructors preallocate requested offsets, while `matrix_data!` allocates additional slots lazily.
function KPointBatchWorkspace(
    model::TightBindingModel,
    plan::MatrixElementPlan,
    offsets::AbstractVector{KPointOffset} = KPointOffset[KPointOffset()],
    sources::MatrixElementSources = MatrixElementSources(),
)
    matrix_elements = MatrixElementWorkspace(model, plan, sources)
    data_type = typeof(matrix_elements.data)
    slots = Dict{KPointOffset, data_type}()
    slots[KPointOffset()] = matrix_elements.data
    for offset in offsets
        haskey(slots, offset) ||
            (slots[offset] = KPointMatrixData(model.num_orbitals, model.num_r_vectors, plan))
    end
    return KPointBatchWorkspace(matrix_elements, slots)
end

"""
Return the cached data object for an exact `KPointOffset`, creating a plan-sized slot on first use.

The returned buffers alias the batch cache and may be overwritten by later evaluation of that slot.
"""
function matrix_data!(batch::KPointBatchWorkspace, offset::KPointOffset)
    return get!(batch.slots, offset) do
        KPointMatrixData(
            length(batch.matrix_elements.data.spectrum.energies),
            length(batch.matrix_elements.scratch.fourier_factors),
            batch.matrix_elements.plan,
        )
    end
end

# Allocate zeroed ComplexF64 storage only when the capability is required; otherwise return nothing.
@inline _optional_array(required::Bool, dimensions::Vararg{Int}) =
    required ? zeros(ComplexF64, dimensions...) : nothing

# Construct hamiltonian data.
function _make_hamiltonian_data(num_orbitals::Int, spatial_dimension::Int, plan::MatrixElementPlan)
    needs_energy_differences = has_capability(plan, ENERGY_DIFFERENCES)
    needs_gradient = has_capability(plan, HAMILTONIAN_DERIVATIVES)
    needs_hessian = has_capability(plan, HAMILTONIAN_SECOND_DERIVATIVES)
    if !(needs_energy_differences || needs_gradient || needs_hessian)
        return nothing
    end
    energy_differences =
        needs_energy_differences ? zeros(Float64, num_orbitals, num_orbitals) : nothing
    derivatives = _optional_array(needs_gradient, num_orbitals, num_orbitals, spatial_dimension)
    source_derivatives =
        _optional_array(needs_gradient, num_orbitals, num_orbitals, spatial_dimension)
    second_derivatives = _optional_array(
        needs_hessian,
        num_orbitals,
        num_orbitals,
        spatial_dimension,
        spatial_dimension,
    )
    return HamiltonianMatrixData(
        energy_differences,
        derivatives,
        second_derivatives,
        source_derivatives,
    )
end

# Construct position data.
function _make_position_data(num_orbitals::Int, spatial_dimension::Int, plan::MatrixElementPlan)
    needs_wannier = has_capability(plan, WANNIER_POSITION)
    needs_internal = has_capability(plan, INTERNAL_CONNECTION)
    needs_internal_derivatives = has_capability(plan, INTERNAL_CONNECTION_DERIVATIVES)
    needs_gauge = has_capability(plan, GAUGE_CORRECTION)
    needs_berry = has_capability(plan, BERRY_CONNECTION)
    needs_curvature = has_capability(plan, WANNIER_CURVATURE)
    needs_velocity = has_capability(plan, VELOCITY_VERTICES)
    if !(
        needs_wannier ||
        needs_internal ||
        needs_internal_derivatives ||
        needs_gauge ||
        needs_berry ||
        needs_curvature ||
        needs_velocity
    )
        return nothing
    end
    wannier = _optional_array(needs_wannier, num_orbitals, num_orbitals, spatial_dimension)
    internal = _optional_array(needs_internal, num_orbitals, num_orbitals, spatial_dimension)
    internal_derivatives = _optional_array(
        needs_internal_derivatives,
        num_orbitals,
        num_orbitals,
        spatial_dimension,
        spatial_dimension,
    )
    wannier_derivatives = _optional_array(
        needs_internal_derivatives,
        num_orbitals,
        num_orbitals,
        spatial_dimension,
        spatial_dimension,
    )
    inverse_energy_differences = needs_gauge ? zeros(Float64, num_orbitals, num_orbitals) : nothing
    gauge = _optional_array(needs_gauge, num_orbitals, num_orbitals, spatial_dimension)
    berry = _optional_array(needs_berry, num_orbitals, num_orbitals, spatial_dimension)
    wannier_curvature = _optional_array(
        needs_curvature,
        num_orbitals,
        num_orbitals,
        spatial_dimension,
        spatial_dimension,
    )
    hamiltonian_curvature = _optional_array(
        needs_curvature,
        num_orbitals,
        num_orbitals,
        spatial_dimension,
        spatial_dimension,
    )
    velocity = _optional_array(needs_velocity, num_orbitals, num_orbitals, spatial_dimension)
    source_derivatives = _optional_array(needs_berry, num_orbitals, num_orbitals, spatial_dimension)
    source_berry = _optional_array(needs_berry, num_orbitals, num_orbitals, spatial_dimension)
    source_velocity = _optional_array(needs_velocity, num_orbitals, num_orbitals, spatial_dimension)
    return PositionMatrixData(
        wannier,
        internal,
        wannier_derivatives,
        internal_derivatives,
        inverse_energy_differences,
        gauge,
        berry,
        wannier_curvature,
        hamiltonian_curvature,
        velocity,
        source_derivatives,
        source_berry,
        source_velocity,
    )
end

# Construct spin data.
function _make_spin_data(num_orbitals::Int, plan::MatrixElementPlan)
    has_capability(plan, SPIN) || return nothing
    return SpinMatrixData(
        zeros(ComplexF64, num_orbitals, num_orbitals, 3),
        zeros(ComplexF64, num_orbitals, num_orbitals, 3),
    )
end

# Construct spin velocity data.
function _make_spin_velocity_data(num_orbitals::Int, plan::MatrixElementPlan)
    needs_component =
        has_capability(plan, SPIN_TIMES_HAMILTONIAN) ||
        has_capability(plan, SPIN_TIMES_POSITION) ||
        has_capability(plan, SPIN_TIMES_HAMILTONIAN_POSITION) ||
        has_capability(plan, SPIN_VELOCITY)
    needs_component || return nothing
    return SpinVelocityMatrixData(
        zeros(Float64, num_orbitals, 3),
        zeros(Float64, num_orbitals, num_orbitals),
        zeros(ComplexF64, num_orbitals, num_orbitals, 3),
        zeros(ComplexF64, num_orbitals, num_orbitals, 3),
        zeros(ComplexF64, num_orbitals, num_orbitals, 3, 3),
        zeros(ComplexF64, num_orbitals, num_orbitals, 3, 3),
        zeros(ComplexF64, num_orbitals, num_orbitals, 3, 3),
        zeros(ComplexF64, num_orbitals, num_orbitals, 3, 3),
        zeros(ComplexF64, num_orbitals, num_orbitals, 3, 3),
    )
end

# One reusable eigensystem and capability-selected matrix payload, with Fourier factors, fractional k point and cache-generation mask.
#
# Constructors allocate only the plan's required channels; subsequent evaluations mutate these buffers and invalidate stale capability bits.
function KPointMatrixData(num_orbitals::Integer, num_r_vectors::Integer, plan::MatrixElementPlan)
    count = Int(num_orbitals)
    r_vector_count = Int(num_r_vectors)
    r_vector_count >= 0 || throw(ArgumentError("num_r_vectors must be non-negative"))
    dimension = plan.spatial_dimension
    return KPointMatrixData(
        KPointSpectrum(count),
        zeros(ComplexF64, r_vector_count),
        _make_hamiltonian_data(count, dimension, plan),
        _make_position_data(count, dimension, plan),
        _make_spin_data(count, plan),
        _make_spin_velocity_data(count, plan),
        UInt64(0),
        UInt64(0),
        zeros(Float64, 3),
    )
end

# Construct hamiltonian scratch.
function _make_hamiltonian_scratch(
    num_orbitals::Int,
    num_r_vectors::Int,
    spatial_dimension::Int,
    plan::MatrixElementPlan,
)
    needs_gradient = has_capability(plan, HAMILTONIAN_DERIVATIVES)
    needs_hessian = has_capability(plan, HAMILTONIAN_SECOND_DERIVATIVES)
    if !(needs_gradient || needs_hessian)
        return nothing
    end
    gradient_channels = _axis_channel_count(plan, HAMILTONIAN_DERIVATIVES)
    hessian_channels = _pair_channel_count(plan, HAMILTONIAN_SECOND_DERIVATIVES)
    gradient_wannier =
        _optional_array(needs_gradient, num_orbitals, num_orbitals, gradient_channels)
    hessian_wannier = _optional_array(needs_hessian, num_orbitals, num_orbitals, hessian_channels)
    gradient_real_space = _optional_array(
        needs_gradient,
        num_orbitals,
        num_orbitals,
        gradient_channels,
        num_r_vectors,
    )
    hessian_real_space =
        _optional_array(needs_hessian, num_orbitals, num_orbitals, hessian_channels, num_r_vectors)
    return HamiltonianMatrixScratch(
        gradient_wannier,
        hessian_wannier,
        gradient_real_space,
        hessian_real_space,
    )
end

# Construct position scratch.
function _make_position_scratch(
    num_orbitals::Int,
    num_r_vectors::Int,
    spatial_dimension::Int,
    plan::MatrixElementPlan,
)
    needs_wannier = has_capability(plan, WANNIER_POSITION)
    needs_gradient = has_capability(plan, INTERNAL_CONNECTION_DERIVATIVES)
    if !(needs_wannier || needs_gradient)
        return nothing
    end
    wannier_channels = _axis_channel_count(plan, WANNIER_POSITION)
    gradient_channels = _pair_channel_count(plan, INTERNAL_CONNECTION_DERIVATIVES)
    return PositionMatrixScratch(
        _optional_array(needs_wannier, num_orbitals, num_orbitals, wannier_channels),
        _optional_array(needs_gradient, num_orbitals, num_orbitals, gradient_channels),
        _optional_array(
            needs_gradient,
            num_orbitals,
            num_orbitals,
            gradient_channels,
            num_r_vectors,
        ),
        _optional_array(has_capability(plan, BERRY_CONNECTION), num_orbitals, num_orbitals),
    )
end

# Construct spin scratch.
function _make_spin_scratch(num_orbitals::Int, plan::MatrixElementPlan)
    has_capability(plan, SPIN) || return nothing
    return SpinMatrixScratch(
        zeros(ComplexF64, num_orbitals, num_orbitals, _axis_channel_count(plan, SPIN)),
    )
end

# Construct spin velocity scratch.
function _make_spin_velocity_scratch(num_orbitals::Int, plan::MatrixElementPlan)
    needs_component =
        has_capability(plan, SPIN_TIMES_HAMILTONIAN) ||
        has_capability(plan, SPIN_TIMES_POSITION) ||
        has_capability(plan, SPIN_TIMES_HAMILTONIAN_POSITION) ||
        has_capability(plan, SPIN_VELOCITY)
    needs_component || return nothing
    return SpinVelocityMatrixScratch(
        zeros(
            ComplexF64,
            num_orbitals,
            num_orbitals,
            _axis_channel_count(plan, SPIN_TIMES_HAMILTONIAN),
        ),
        zeros(
            ComplexF64,
            num_orbitals,
            num_orbitals,
            _pair_channel_count(plan, SPIN_TIMES_POSITION),
        ),
        zeros(
            ComplexF64,
            num_orbitals,
            num_orbitals,
            _pair_channel_count(plan, SPIN_TIMES_HAMILTONIAN_POSITION),
        ),
    )
end

# Shared Fourier factors, Hamiltonian/multiplication buffers, Wannier-center phases and optional capability-specific scratch.
#
# Construction sizes buffers from the compiled plan; this mutable storage must be owned by one execution slot.
function MatrixElementScratch(count::Integer, num_r_vectors_input::Integer, plan::MatrixElementPlan)
    num_orbitals = Int(count)
    num_r_vectors = Int(num_r_vectors_input)
    dimension = plan.spatial_dimension
    return MatrixElementScratch(
        zeros(ComplexF64, num_r_vectors),
        zeros(ComplexF64, num_orbitals, num_orbitals),
        zeros(ComplexF64, num_orbitals, num_orbitals),
        zeros(Float64, 3, num_orbitals),
        zeros(Float64, 3, num_orbitals),
        ones(ComplexF64, num_orbitals),
        0,
        false,
        _make_hamiltonian_scratch(num_orbitals, num_r_vectors, dimension, plan),
        _make_position_scratch(num_orbitals, num_r_vectors, dimension, plan),
        _make_spin_scratch(num_orbitals, plan),
        _make_spin_velocity_scratch(num_orbitals, plan),
    )
end

# Shared Fourier factors, Hamiltonian/multiplication buffers, Wannier-center phases and optional capability-specific scratch.
#
# Construction sizes buffers from the compiled plan; this mutable storage must be owned by one execution slot.
MatrixElementScratch(model::TightBindingModel, plan::MatrixElementPlan) =
    MatrixElementScratch(model.num_orbitals, model.num_r_vectors, plan)

# Reject missing spin, spin-velocity or derivative-overlap inputs required by the compiled matrix capability plan.
function _validate_sources(plan::MatrixElementPlan, sources::MatrixElementSources)
    has_capability(plan, SPIN) &&
        sources.spin === nothing &&
        error("The compiled matrix-element plan requires SpinRealSpaceData.")
    needs_spin_velocity_source =
        has_capability(plan, SPIN_TIMES_HAMILTONIAN) ||
        has_capability(plan, SPIN_TIMES_POSITION) ||
        has_capability(plan, SPIN_TIMES_HAMILTONIAN_POSITION) ||
        has_capability(plan, SPIN_VELOCITY)
    needs_spin_velocity_source &&
        sources.spin_velocity === nothing &&
        error("The compiled matrix-element plan requires SpinVelocityRealSpaceData.")
    return sources
end

# One execution slot's compiled plan, validated sources, cached k-point data, scratch, preparation flag and counters.
#
# Constructors validate required operator sources and share Fourier-factor storage between data and scratch; do not share a mutable workspace across concurrent evaluations.
function MatrixElementWorkspace(
    num_orbitals::Integer,
    num_r_vectors::Integer,
    plan::MatrixElementPlan,
    sources::MatrixElementSources = MatrixElementSources(),
)
    _validate_sources(plan, sources)
    data = KPointMatrixData(num_orbitals, num_r_vectors, plan)
    scratch = MatrixElementScratch(num_orbitals, num_r_vectors, plan)
    scratch.fourier_factors = data.fourier_factors
    return MatrixElementWorkspace(
        plan,
        sources,
        data,
        scratch,
        false,
        MatrixElementEvaluationCounts(),
    )
end

# One execution slot's compiled plan, validated sources, cached k-point data, scratch, preparation flag and counters.
#
# Constructors validate required operator sources and share Fourier-factor storage between data and scratch; do not share a mutable workspace across concurrent evaluations.
MatrixElementWorkspace(
    model::TightBindingModel,
    plan::MatrixElementPlan,
    sources::MatrixElementSources = MatrixElementSources(),
) = MatrixElementWorkspace(model.num_orbitals, model.num_r_vectors, plan, sources)

"""
Return the workspace-owned matrix or spectrum for an explicitly requested capability.

Reject capabilities absent from the request mask, even when available as prerequisites; the returned object is not copied and may be overwritten by later evaluation.
"""
function matrix(workspace::MatrixElementWorkspace, kind::MatrixElementKind)
    is_requested(workspace.plan, kind) ||
        error("Matrix-element capability $(kind) was not requested.")
    data = workspace.data
    if kind == SPECTRUM
        return data.spectrum
    elseif kind == ENERGY_DIFFERENCES
        return data.hamiltonian.energy_differences
    elseif kind == HAMILTONIAN_DERIVATIVES
        return data.hamiltonian.derivatives
    elseif kind == HAMILTONIAN_SECOND_DERIVATIVES
        return data.hamiltonian.second_derivatives
    elseif kind == WANNIER_POSITION
        return data.position.wannier_gauge
    elseif kind == INTERNAL_CONNECTION
        return data.position.internal_connection
    elseif kind == INTERNAL_CONNECTION_DERIVATIVES
        return data.position.internal_connection_derivatives
    elseif kind == GAUGE_CORRECTION
        return data.position.gauge_correction
    elseif kind == BERRY_CONNECTION
        return data.position.berry_connection
    elseif kind == VELOCITY_VERTICES
        return data.position.velocity_vertices
    elseif kind == SPIN
        return data.spin.hamiltonian_gauge
    elseif kind == SPIN_TIMES_HAMILTONIAN
        return data.spin_velocity.spin_times_hamiltonian
    elseif kind == SPIN_TIMES_POSITION
        return data.spin_velocity.spin_times_position
    elseif kind == SPIN_TIMES_HAMILTONIAN_POSITION
        return data.spin_velocity.spin_times_hamiltonian_position
    elseif kind == SPIN_VELOCITY
        return data.spin_velocity.hamiltonian_gauge
    end
    error("Unhandled MatrixElementKind $(kind).")
end
