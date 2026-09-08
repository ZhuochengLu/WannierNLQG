# Response workspaces own formula and accumulation buffers only.

"""
Three orbital-square buffers for connection/Hamiltonian commutators and temporary matrix products.

The size constructor allocates zeroed ComplexF64 arrays owned by one response workspace.
"""
mutable struct _ConventionalGeneralizedDerivativeScratch
    connection_commutator::Matrix{ComplexF64}
    hamiltonian_commutator::Matrix{ComplexF64}
    product_scratch::Matrix{ComplexF64}
end

# Three orbital-square buffers for connection/Hamiltonian commutators and temporary matrix products.
#
# The size constructor allocates zeroed ComplexF64 arrays owned by one response workspace.
function _ConventionalGeneralizedDerivativeScratch(num_orbitals::Int)
    return _ConventionalGeneralizedDerivativeScratch(
        zeros(ComplexF64, num_orbitals, num_orbitals),
        zeros(ComplexF64, num_orbitals, num_orbitals),
        zeros(ComplexF64, num_orbitals, num_orbitals),
    )
end

"""
Shared interpolation data plus generalized-position derivatives, rank-three response kernel, local spectrum and frequency-contraction buffers.

Constructor overloads fill newly required scratch while retaining the caller's supplied matrices; this mutable workspace is private to one execution slot.
"""
mutable struct ShiftCurrentConventionalWorkspace{W, D}
    scratch::W
    data::D
    generalized_position_derivative::Array{ComplexF64, 4}
    generalized_derivative_scratch::_ConventionalGeneralizedDerivativeScratch
    response_kernel::Array{ComplexF64, 5}
    local_response::Array{ComplexF64, 4}
    frequency_weights::Vector{Float64}
    frequency_contraction_scratch::_FrequencyContractionScratch
    spin_frequency_contraction_scratch::_FrequencyContractionScratch
end

# Shared interpolation data plus generalized-position derivatives, rank-three response kernel, local spectrum and frequency-contraction buffers.
#
# Constructor overloads fill newly required scratch while retaining the caller's supplied matrices; this mutable workspace is private to one execution slot.
function ShiftCurrentConventionalWorkspace(
    scratch,
    data,
    generalized_position_derivative::Array{ComplexF64, 4},
    response_kernel::Array{ComplexF64, 5},
    local_response::Array{ComplexF64, 4},
    frequency_weights::Vector{Float64},
)
    return ShiftCurrentConventionalWorkspace(
        scratch,
        data,
        generalized_position_derivative,
        _ConventionalGeneralizedDerivativeScratch(size(generalized_position_derivative, 1)),
        response_kernel,
        local_response,
        frequency_weights,
        _FrequencyContractionScratch(
            length(frequency_weights),
            size(response_kernel, 3)^3;
            pair_block = min(256, size(response_kernel, 1)^2),
        ),
        _FrequencyContractionScratch(
            length(frequency_weights),
            3 * size(response_kernel, 3)^3;
            pair_block = min(256, size(response_kernel, 1)^2),
        ),
    )
end

"""
Connection, velocity, effective-mass and two-photon spin vertices with rank-four response and contraction scratch.

Spin direction remains a separate three-component axis; all temporary arrays belong to one execution slot.
"""
mutable struct ShiftSpinCurrentConventionalWorkspace{W, D}
    scratch::W
    data::D
    physical_connection::Array{ComplexF64, 3}
    physical_connection_derivative::Array{ComplexF64, 4}
    velocity_vertex::Array{ComplexF64, 3}
    effective_mass_vertex::Array{ComplexF64, 4}
    spin_two_photon_vertex::Array{ComplexF64, 5}
    generalized_spin_derivative::Array{ComplexF64, 5}
    response_kernel::Array{ComplexF64, 6}
    regularized_inverse_energy::Matrix{Float64}
    matrix_scratch_1::Matrix{ComplexF64}
    matrix_scratch_2::Matrix{ComplexF64}
    matrix_scratch_3::Matrix{ComplexF64}
    matrix_scratch_4::Matrix{ComplexF64}
    frequency_weights::Vector{Float64}
    frequency_pair_weights::Matrix{Float64}
    frequency_contraction_scratch::_FrequencyContractionScratch
end

"""
Allocate conventional shift-spin-current buffers sized by orbitals, spatial dimension and photon energies.

Request spin velocity, connection derivatives and Hamiltonian Hessians; optionally share a supplied matrix workspace and central data while keeping response scratch private.
"""
function make_shift_spin_current_conventional_workspace(
    num_orbitals::Int64,
    num_r_vectors::Int64,
    spatial_dimension::Int64,
    num_photon_energies::Int64 = 1;
    matrix_elements = nothing,
    central_data = nothing,
)
    plan = compile_matrix_plan(
        MatrixElementRequest(
            SPIN_VELOCITY,
            INTERNAL_CONNECTION,
            INTERNAL_CONNECTION_DERIVATIVES,
            HAMILTONIAN_SECOND_DERIVATIVES;
            spatial_dimension = spatial_dimension,
        );
        source_gauge_required = false,
    )
    shared_matrix_elements =
        matrix_elements === nothing ? MatrixElementWorkspace(num_orbitals, num_r_vectors, plan) :
        matrix_elements
    data = central_data === nothing ? shared_matrix_elements.data : central_data
    return ShiftSpinCurrentConventionalWorkspace(
        shared_matrix_elements,
        data,
        zeros(ComplexF64, num_orbitals, num_orbitals, spatial_dimension),
        zeros(ComplexF64, num_orbitals, num_orbitals, spatial_dimension, spatial_dimension),
        zeros(ComplexF64, num_orbitals, num_orbitals, spatial_dimension),
        zeros(ComplexF64, num_orbitals, num_orbitals, spatial_dimension, spatial_dimension),
        zeros(ComplexF64, num_orbitals, num_orbitals, 3, spatial_dimension, spatial_dimension),
        zeros(ComplexF64, num_orbitals, num_orbitals, 3, spatial_dimension, spatial_dimension),
        zeros(
            ComplexF64,
            num_orbitals,
            num_orbitals,
            spatial_dimension,
            3,
            spatial_dimension,
            spatial_dimension,
        ),
        zeros(Float64, num_orbitals, num_orbitals),
        zeros(ComplexF64, num_orbitals, num_orbitals),
        zeros(ComplexF64, num_orbitals, num_orbitals),
        zeros(ComplexF64, num_orbitals, num_orbitals),
        zeros(ComplexF64, num_orbitals, num_orbitals),
        zeros(Float64, num_photon_energies),
        zeros(Float64, num_orbitals, num_orbitals),
        _FrequencyContractionScratch(
            num_photon_energies,
            3 * spatial_dimension^3;
            pair_block = min(256, num_orbitals^2),
        ),
    )
end

"""
Allocate generalized-derivative, rank-three current and frequency-contraction buffers.

Compile the required connection/velocity/Hessian plan when matrix storage is not supplied; supplied matrix workspace and central data are aliased deliberately.
"""
function make_shift_current_conventional_workspace(
    num_orbitals::Int64,
    num_r_vectors::Int64,
    spatial_dimension::Int64,
    num_photon_energies::Int64,
    ;
    matrix_elements = nothing,
    central_data = nothing,
)
    plan = compile_matrix_plan(
        MatrixElementRequest(
            BERRY_CONNECTION,
            INTERNAL_CONNECTION_DERIVATIVES,
            HAMILTONIAN_SECOND_DERIVATIVES,
            VELOCITY_VERTICES;
            spatial_dimension = spatial_dimension,
        );
        source_gauge_required = false,
    )
    shared_matrix_elements =
        matrix_elements === nothing ? MatrixElementWorkspace(num_orbitals, num_r_vectors, plan) :
        matrix_elements
    data = central_data === nothing ? shared_matrix_elements.data : central_data
    return ShiftCurrentConventionalWorkspace(
        shared_matrix_elements,
        data,
        zeros(ComplexF64, num_orbitals, num_orbitals, spatial_dimension, spatial_dimension),
        _ConventionalGeneralizedDerivativeScratch(num_orbitals),
        zeros(
            ComplexF64,
            num_orbitals,
            num_orbitals,
            spatial_dimension,
            spatial_dimension,
            spatial_dimension,
        ),
        zeros(
            ComplexF64,
            num_photon_energies,
            spatial_dimension,
            spatial_dimension,
            spatial_dimension,
        ),
        zeros(Float64, num_photon_energies),
        _FrequencyContractionScratch(
            num_photon_energies,
            spatial_dimension^3;
            pair_block = min(256, num_orbitals^2),
        ),
        _FrequencyContractionScratch(
            num_photon_energies,
            3 * spatial_dimension^3;
            pair_block = min(256, num_orbitals^2),
        ),
    )
end

"""
Shared matrix scratch, current k-point data and optional discrete-offset cache for conventional geometry derivatives.

Shifted evaluations rebind `data`; the central cache binding is restored by derivative routines.
"""
mutable struct ConventionalQuantumGeometryWorkspace{W, D, B}
    scratch::W
    data::D
    matrix_batch::B
end

"""
Construct conventional geometry storage with connection, curvature, connection-derivative, Hessian and velocity capabilities.

Reuse optional supplied matrix workspace, central data and offset cache; no geometry is evaluated during construction.
"""
function make_conventional_quantum_geometry_workspace(
    num_orbitals::Int64,
    num_r_vectors::Int64,
    spatial_dimension::Int64,
    num_photon_energies::Int64,
    ;
    matrix_elements = nothing,
    central_data = nothing,
    matrix_batch = nothing,
)
    plan = compile_matrix_plan(
        MatrixElementRequest(
            BERRY_CONNECTION,
            WANNIER_CURVATURE,
            INTERNAL_CONNECTION_DERIVATIVES,
            HAMILTONIAN_SECOND_DERIVATIVES,
            VELOCITY_VERTICES;
            spatial_dimension = spatial_dimension,
        );
        source_gauge_required = false,
    )
    shared_matrix_elements =
        matrix_elements === nothing ? MatrixElementWorkspace(num_orbitals, num_r_vectors, plan) :
        matrix_elements
    data = central_data === nothing ? shared_matrix_elements.data : central_data
    return ConventionalQuantumGeometryWorkspace(shared_matrix_elements, data, matrix_batch)
end

"""
Central and shifted projector data, finite-difference arrays, trace multiplication scratch and rank-three response accumulators.

Degenerate-band activity is tracked separately; mutable buffers must not be shared across concurrent k-point workers.
"""
mutable struct ProjectorResponseWorkspace{W, D}
    scratch::W
    central_data::D
    forward_data::D
    backward_data::D
    second_forward_data::D
    second_backward_data::D
    forward_projectors::Array{ComplexF64, 4}
    backward_projectors::Array{ComplexF64, 4}
    pure_projector_derivatives::Array{ComplexF64, 4}
    response_kernel::Array{ComplexF64, 5}
    qhc_response_kernel::Array{ComplexF64, 5}
    local_response::Array{ComplexF64, 4}
    kernel_tmp1::Matrix{ComplexF64}
    kernel_tmp2::Matrix{ComplexF64}
    kernel_tmp3::Matrix{ComplexF64}
    kernel_tmp4::Matrix{ComplexF64}
    kernel_tmp5::Matrix{ComplexF64}
    kernel_tmp6::Matrix{ComplexF64}
    active_bands::BitVector
end

"""
Allocate central and four shifted Projector data slots, derivative/trace buffers and frequency accumulators.

Optionally share interpolation and central data; newly allocated projector/response scratch remains private to the caller.
"""
function make_projector_response_workspace(
    num_orbitals::Int64,
    num_r_vectors::Int64,
    spatial_dimension::Int64,
    num_photon_energies::Int64,
    ;
    matrix_elements = nothing,
    matrix_batch = nothing,
    central_common = nothing,
)
    scratch =
        matrix_elements === nothing ?
        ProjectorMatrixWorkspace(num_orbitals, num_r_vectors, spatial_dimension) :
        ProjectorMatrixWorkspace(matrix_elements, matrix_batch)
    plan = scratch.matrix_elements.plan
    shared_central =
        central_common === nothing ? KPointMatrixData(num_orbitals, num_r_vectors, plan) :
        central_common
    central_data = ProjectorMatrixData(shared_central, spatial_dimension)
    forward_data =
        ProjectorMatrixData(KPointMatrixData(num_orbitals, num_r_vectors, plan), spatial_dimension)
    backward_data =
        ProjectorMatrixData(KPointMatrixData(num_orbitals, num_r_vectors, plan), spatial_dimension)
    second_forward_data =
        ProjectorMatrixData(KPointMatrixData(num_orbitals, num_r_vectors, plan), spatial_dimension)
    second_backward_data =
        ProjectorMatrixData(KPointMatrixData(num_orbitals, num_r_vectors, plan), spatial_dimension)
    return ProjectorResponseWorkspace(
        scratch,
        central_data,
        forward_data,
        backward_data,
        second_forward_data,
        second_backward_data,
        zeros(ComplexF64, num_orbitals, num_orbitals, num_orbitals, spatial_dimension),
        zeros(ComplexF64, num_orbitals, num_orbitals, num_orbitals, spatial_dimension),
        zeros(ComplexF64, num_orbitals, num_orbitals, num_orbitals, spatial_dimension),
        zeros(
            ComplexF64,
            num_orbitals,
            num_orbitals,
            spatial_dimension,
            spatial_dimension,
            spatial_dimension,
        ),
        zeros(
            ComplexF64,
            num_orbitals,
            num_orbitals,
            spatial_dimension,
            spatial_dimension,
            spatial_dimension,
        ),
        zeros(
            ComplexF64,
            num_photon_energies,
            spatial_dimension,
            spatial_dimension,
            spatial_dimension,
        ),
        zeros(ComplexF64, num_orbitals, num_orbitals),
        zeros(ComplexF64, num_orbitals, num_orbitals),
        zeros(ComplexF64, num_orbitals, num_orbitals),
        zeros(ComplexF64, num_orbitals, num_orbitals),
        zeros(ComplexF64, num_orbitals, num_orbitals),
        zeros(ComplexF64, num_orbitals, num_orbitals),
        trues(num_orbitals),
    )
end

"""
Six central/shifted band frames, convention transport, overlap links, velocity insertions and cached covariant derivatives for geometric loops.

Validity masks track populated directions/pairs; response kernels and local spectra are owned by one worker.
"""
mutable struct GeometricLoopResponseWorkspace{W, D, F <: ConventionFrameConnector}
    scratch::W
    valence_central_data::D
    conduction_central_data::D
    valence_forward_data::D
    conduction_forward_data::D
    valence_backward_data::D
    conduction_backward_data::D
    frame_connector::F
    frame_phase_factors::Vector{ComplexF64}
    frame_rotated_eigenvectors::Matrix{ComplexF64}
    frame_generator_band::Matrix{ComplexF64}
    valence_source_external_connection::Array{ComplexF64, 3}
    conduction_source_external_connection::Array{ComplexF64, 3}
    forward_overlap_1::Matrix{ComplexF64}
    forward_overlap_2::Matrix{ComplexF64}
    forward_overlap_3::Matrix{ComplexF64}
    backward_overlap_1::Matrix{ComplexF64}
    backward_overlap_2::Matrix{ComplexF64}
    backward_overlap_3::Matrix{ComplexF64}
    central_overlap_4::Matrix{ComplexF64}
    forward_third_insertions::Array{ComplexF64, 3}
    backward_third_insertions::Array{ComplexF64, 3}
    central_second_insertions::Array{ComplexF64, 3}
    central_third_insertions::Array{ComplexF64, 3}
    forward_transported_insertions::Array{ComplexF64, 3}
    backward_transported_insertions::Array{ComplexF64, 3}
    covariant_insertion_derivatives::Array{ComplexF64, 3}
    transport_temporary_1::Matrix{ComplexF64}
    transport_temporary_2::Matrix{ComplexF64}
    covariant_derivative_valid::BitArray{3}
    covariant_derivative_axis::Int
    forward_loop_links::Array{ComplexF64, 4}
    backward_loop_links::Array{ComplexF64, 4}
    loop_link_valid::BitArray{4}
    response_kernel::Array{ComplexF64, 5}
    local_response::Array{ComplexF64, 4}
end

"""
Allocate geometric-loop link/insertion/transport buffers and response arrays for the requested orbitals and dimensions.

Reuse optional matrix workspace, offset cache and central legs; construct a frame connector from the underlying Wannier-center convention.
"""
function make_geometric_loop_response_workspace(
    num_orbitals::Int64,
    num_r_vectors::Int64,
    spatial_dimension::Int64,
    num_photon_energies::Int64,
    ;
    matrix_elements = nothing,
    matrix_batch = nothing,
    valence_central_common = nothing,
    conduction_central_common = nothing,
)
    scratch =
        matrix_elements === nothing ?
        GeometricLoopMatrixWorkspace(num_orbitals, num_r_vectors, spatial_dimension) :
        GeometricLoopMatrixWorkspace(matrix_elements, matrix_batch)
    plan = scratch.matrix_elements.plan
    frame_connector = make_convention_frame_connector(plan.wannier_center_convention)
    make_data() = GeometricLoopMatrixData(KPointMatrixData(num_orbitals, num_r_vectors, plan))
    valence_central =
        valence_central_common === nothing ? make_data() :
        GeometricLoopMatrixData(valence_central_common)
    conduction_central =
        conduction_central_common === nothing ? make_data() :
        GeometricLoopMatrixData(conduction_central_common)
    return GeometricLoopResponseWorkspace(
        scratch,
        valence_central,
        conduction_central,
        make_data(),
        make_data(),
        make_data(),
        make_data(),
        frame_connector,
        ones(ComplexF64, num_orbitals),
        zeros(ComplexF64, num_orbitals, num_orbitals),
        zeros(ComplexF64, num_orbitals, num_orbitals),
        zeros(ComplexF64, num_orbitals, num_orbitals, spatial_dimension),
        zeros(ComplexF64, num_orbitals, num_orbitals, spatial_dimension),
        zeros(ComplexF64, num_orbitals, num_orbitals),
        zeros(ComplexF64, num_orbitals, num_orbitals),
        zeros(ComplexF64, num_orbitals, num_orbitals),
        zeros(ComplexF64, num_orbitals, num_orbitals),
        zeros(ComplexF64, num_orbitals, num_orbitals),
        zeros(ComplexF64, num_orbitals, num_orbitals),
        zeros(ComplexF64, num_orbitals, num_orbitals),
        zeros(ComplexF64, num_orbitals, num_orbitals, spatial_dimension),
        zeros(ComplexF64, num_orbitals, num_orbitals, spatial_dimension),
        zeros(ComplexF64, num_orbitals, num_orbitals, spatial_dimension),
        zeros(ComplexF64, num_orbitals, num_orbitals, spatial_dimension),
        zeros(ComplexF64, num_orbitals, num_orbitals, spatial_dimension),
        zeros(ComplexF64, num_orbitals, num_orbitals, spatial_dimension),
        zeros(ComplexF64, num_orbitals, num_orbitals, spatial_dimension),
        zeros(ComplexF64, num_orbitals, num_orbitals),
        zeros(ComplexF64, num_orbitals, num_orbitals),
        falses(num_orbitals, num_orbitals, spatial_dimension),
        0,
        zeros(ComplexF64, num_orbitals, num_orbitals, spatial_dimension, spatial_dimension),
        zeros(ComplexF64, num_orbitals, num_orbitals, spatial_dimension, spatial_dimension),
        falses(num_orbitals, num_orbitals, spatial_dimension, spatial_dimension),
        zeros(
            ComplexF64,
            num_orbitals,
            num_orbitals,
            spatial_dimension,
            spatial_dimension,
            spatial_dimension,
        ),
        zeros(
            ComplexF64,
            num_photon_energies,
            spatial_dimension,
            spatial_dimension,
            spatial_dimension,
        ),
    )
end

const WilsonFrameConnector = ConventionFrameConnector
const IdentityWilsonFrameConnector = IdentityConventionFrameConnector
const WannierCenterWilsonFrameConnector = WannierCenterConventionFrameConnector

# Resolve the concrete Wilson-link frame policy once during workspace construction.
function _make_wilson_frame_connector(convention::WannierCenterConvention)
    return make_convention_frame_connector(convention)
end

"""
Store Wilson-loop response workspace state.

The worker-local workspace owns a concrete Convention frame policy, preallocated
link buffers, the source-eigenvector-gauge internal connection, transported
subspace derivatives, response kernels, and deterministic local accumulators.
It performs no output or process/thread coordination.
"""
mutable struct WilsonLoopResponseWorkspace{W, D, F <: WilsonFrameConnector}
    scratch::W
    central_data::D
    forward_data::Vector{D}
    backward_data::Vector{D}
    frame_connector::F
    frame_phase_factors::Vector{ComplexF64}
    frame_rotated_eigenvectors::Matrix{ComplexF64}
    frame_generator_band::Matrix{ComplexF64}
    source_internal_connection::Array{ComplexF64, 3}
    central_to_forward_overlap::Array{ComplexF64, 3}
    forward_to_central_overlap::Array{ComplexF64, 3}
    central_to_backward_overlap::Array{ComplexF64, 3}
    backward_to_central_overlap::Array{ComplexF64, 3}
    transported_connection_derivatives::Array{ComplexF64, 3}
    transported_derivative_valid::BitArray{3}
    transported_derivative_axis::Int
    shift_vector_forward_loops::Array{ComplexF64, 4}
    shift_vector_backward_loops::Array{ComplexF64, 4}
    shift_vector_loop_valid::BitArray{4}
    shift_vector_loop_axis::Int
    response_kernel::Array{ComplexF64, 5}
    qhc_response_kernel::Array{ComplexF64, 5}
    shift_vector_response_kernel::Array{ComplexF64, 5}
    local_response::Array{ComplexF64, 4}
end

"""
Allocate Wilson central/shifted frames, covariant link buffers, transported derivatives and frequency accumulators.

Reuse optional matrix/offset storage and preserve its Wannier-center convention; validity masks mark which cached block derivatives can be read.
"""
function make_wilson_loop_response_workspace(
    num_orbitals::Int64,
    num_r_vectors::Int64,
    spatial_dimension::Int64,
    num_photon_energies::Int64,
    ;
    matrix_elements = nothing,
    matrix_batch = nothing,
    central_common = nothing,
)
    scratch =
        matrix_elements === nothing ?
        GeometricLoopMatrixWorkspace(num_orbitals, num_r_vectors, spatial_dimension) :
        GeometricLoopMatrixWorkspace(matrix_elements, matrix_batch)
    plan = scratch.matrix_elements.plan
    frame_connector = _make_wilson_frame_connector(plan.wannier_center_convention)
    central_data = GeometricLoopMatrixData(
        central_common === nothing ? KPointMatrixData(num_orbitals, num_r_vectors, plan) :
        central_common,
    )
    forward_data = [
        GeometricLoopMatrixData(KPointMatrixData(num_orbitals, num_r_vectors, plan)) for
        _ in 1:spatial_dimension
    ]
    backward_data = [
        GeometricLoopMatrixData(KPointMatrixData(num_orbitals, num_r_vectors, plan)) for
        _ in 1:spatial_dimension
    ]
    return WilsonLoopResponseWorkspace(
        scratch,
        central_data,
        forward_data,
        backward_data,
        frame_connector,
        ones(ComplexF64, num_orbitals),
        zeros(ComplexF64, num_orbitals, num_orbitals),
        zeros(ComplexF64, num_orbitals, num_orbitals),
        zeros(ComplexF64, num_orbitals, num_orbitals, spatial_dimension),
        zeros(ComplexF64, num_orbitals, num_orbitals, spatial_dimension),
        zeros(ComplexF64, num_orbitals, num_orbitals, spatial_dimension),
        zeros(ComplexF64, num_orbitals, num_orbitals, spatial_dimension),
        zeros(ComplexF64, num_orbitals, num_orbitals, spatial_dimension),
        zeros(ComplexF64, num_orbitals, num_orbitals, spatial_dimension),
        falses(num_orbitals, num_orbitals, spatial_dimension),
        0,
        zeros(ComplexF64, num_orbitals, num_orbitals, spatial_dimension, spatial_dimension),
        zeros(ComplexF64, num_orbitals, num_orbitals, spatial_dimension, spatial_dimension),
        falses(num_orbitals, num_orbitals, spatial_dimension, spatial_dimension),
        0,
        zeros(
            ComplexF64,
            num_orbitals,
            num_orbitals,
            spatial_dimension,
            spatial_dimension,
            spatial_dimension,
        ),
        zeros(
            ComplexF64,
            num_orbitals,
            num_orbitals,
            spatial_dimension,
            spatial_dimension,
            spatial_dimension,
        ),
        zeros(
            ComplexF64,
            num_orbitals,
            num_orbitals,
            spatial_dimension,
            spatial_dimension,
            spatial_dimension,
        ),
        zeros(
            ComplexF64,
            num_photon_energies,
            spatial_dimension,
            spatial_dimension,
            spatial_dimension,
        ),
    )
end

"""
Separate valence/conduction momentum-leg data, cross-frame overlaps and velocity insertions with ordered-pair current kernels.

Frequency and matrix scratch is private to one worker; spin-independent source-gauge vertices retain their input energy/length units.
"""
mutable struct PhotonDragInjectionCurrentConventionalWorkspace{W, D}
    scratch::W
    valence_data::D
    conduction_data::D
    explicit_center_phase_enabled::Bool
    overlap_1::Matrix{ComplexF64}
    overlap_2::Matrix{ComplexF64}
    matrix_scratch_1::Matrix{ComplexF64}
    matrix_scratch_2::Matrix{ComplexF64}
    forward_velocity_vertex::Array{ComplexF64, 3}
    backward_velocity_vertex::Array{ComplexF64, 3}
    response_kernel::Array{ComplexF64, 5}
    local_response::Array{ComplexF64, 4}
    frequency_denominator_weights::Vector{Float64}
    frequency_weight_scratch::Vector{Float64}
    frequency_contraction_scratch::_FrequencyContractionScratch
end

"""
Allocate two momentum-leg matrix data sets, overlap/velocity scratch and photon-energy contraction buffers.

Reuse optional shared matrix storage and central legs; allocation performs no finite-q response evaluation.
"""
function make_photon_drag_injection_current_conventional_workspace(
    num_orbitals::Int64,
    num_r_vectors::Int64,
    spatial_dimension::Int64,
    num_photon_energies::Int64,
    ;
    photon_energies::Union{Nothing, AbstractVector{<:Real}} = nothing,
    denominator_regularization::Real = 0.001,
    matrix_elements = nothing,
    valence_data = nothing,
    conduction_data = nothing,
)
    plan = compile_matrix_plan(
        MatrixElementRequest(
            BERRY_CONNECTION,
            INTERNAL_CONNECTION_DERIVATIVES,
            HAMILTONIAN_SECOND_DERIVATIVES,
            VELOCITY_VERTICES;
            spatial_dimension = spatial_dimension,
        ),
    )
    shared_matrix_elements =
        matrix_elements === nothing ? MatrixElementWorkspace(num_orbitals, num_r_vectors, plan) :
        matrix_elements
    valence_common =
        valence_data === nothing ?
        KPointMatrixData(num_orbitals, num_r_vectors, shared_matrix_elements.plan) : valence_data
    conduction_common =
        conduction_data === nothing ?
        KPointMatrixData(num_orbitals, num_r_vectors, shared_matrix_elements.plan) : conduction_data
    frequency_denominator_weights = zeros(Float64, num_photon_energies)
    if photon_energies !== nothing
        length(photon_energies) == num_photon_energies || throw(
            DimensionMismatch(
                "photon_energies length=$(length(photon_energies)) does not match " *
                "num_photon_energies=$(num_photon_energies).",
            ),
        )
        frequency_denominator_weights .=
            real(
                (
                    Float64[energy for energy in photon_energies] .+ 1.0im * Float64(denominator_regularization)
                ) .^ (-1),
            ) .^ 2
    end
    return PhotonDragInjectionCurrentConventionalWorkspace(
        shared_matrix_elements,
        valence_common,
        conduction_common,
        shared_matrix_elements.plan.wannier_center_convention == CONVENTION_II,
        zeros(ComplexF64, num_orbitals, num_orbitals),
        zeros(ComplexF64, num_orbitals, num_orbitals),
        zeros(ComplexF64, num_orbitals, num_orbitals),
        zeros(ComplexF64, num_orbitals, num_orbitals),
        zeros(ComplexF64, num_orbitals, num_orbitals, spatial_dimension),
        zeros(ComplexF64, num_orbitals, num_orbitals, spatial_dimension),
        zeros(
            ComplexF64,
            num_orbitals,
            num_orbitals,
            spatial_dimension,
            spatial_dimension,
            spatial_dimension,
        ),
        zeros(
            ComplexF64,
            num_photon_energies,
            spatial_dimension,
            spatial_dimension,
            spatial_dimension,
        ),
        frequency_denominator_weights,
        zeros(Float64, num_photon_energies),
        _FrequencyContractionScratch(
            num_photon_energies,
            spatial_dimension^3;
            pair_block = min(256, num_orbitals^2),
        ),
    )
end
