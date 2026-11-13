module MatrixElements

using LinearAlgebra
using FFTW
import ..Core.ESKernel: DenseSpectra, FFTBuffers, WorkspacePlanning
using ForwardDiff
using Mmap
using Printf
using SHA
using ..Core
using ..Core: _localized_spin_indices
using ..IO

include("Interpolated/MixedFourierPrimitives.jl")
include("Interpolated/OrthogonalGeometryDerivativePlan.jl")
include("Interpolated/MatrixElementPlan.jl")
include("Interfaces.jl")
include("AnalyticDerivativeDiagnostics.jl")
export make_analytic_derivative_diagnostics,
    merge_analytic_derivative_diagnostics, validate_analytic_model
include("AnalyticModelEvaluation.jl")
include("Interpolated/SubspacePositionMatrixElements.jl")
include("Interpolated/MatrixElementWorkspace.jl")
include("NativeModelSources.jl")
include("Interpolated/WannierCenterConventionTransforms.jl")
include("Interpolated/MixedFourierMatrixElements.jl")
include("Interpolated/SharedInterpolationCache.jl")
include("Interpolated/HamiltonianMatrixElements.jl")
include("Interpolated/PositionVertexRegularization.jl")
include("Interpolated/PositionMatrixElements.jl")
include("Interpolated/PositionCurvatureProjection.jl")
include("Interpolated/SubspacePositionEvaluation.jl")
include("Interpolated/QuantumMetricCompletion.jl")
include("Interpolated/OpticalPositionDerivatives.jl")
include("Interpolated/ThirdOrderGeometry.jl")
export ThirdOrderGeometry,
    JerkCurrentGeometry,
    prepare_jerk_current_geometry!,
    prepare_third_order_geometry!,
    prepare_third_order_band_geometry!,
    prepare_third_order_combined_geometry!,
    optical_derivative_combination
include("Interpolated/SpinMatrixElements.jl")
include("Interpolated/SpinVelocityMatrixElements.jl")
include("NonorthogonalOpticalCutoffVertices.jl")
include("NonorthogonalMatrixElements.jl")
include("NonorthogonalFourier.jl")
export NonorthogonalPositionMatrixData,
    nonorthogonal_operator_matrices, nonorthogonal_metric_diagnostics, isolated_band_curvature
include("RealSpaceReplicaPolicies.jl")
include("Interpolated/WannierPairWignerSeitzTransforms.jl")
include("Interpolated/WannierDerivativeOperators.jl")
include("ModelTransforms.jl")
include("Interpolated/WannierCellImageTransforms.jl")
include("ResponseDegeneracyGroups.jl")
include("ProjectorMatrixElements.jl")
include("GeometricLoopMatrixElements.jl")
include("ConventionCovariantTransport.jl")
include("OpticalMomentumOverlap.jl")
include("AnalyticMatrixElements.jl")
include("PointOrbitalSymmetryEvaluation.jl")
include("Interpolated/OrthogonalGeometryJets.jl")
include("Interpolated/OrthogonalBandDerivatives.jl")
export point_orbital_geometry, validate_point_orbital_group, validate_point_orbital_covariance
include("MatrixElementsIntegrationContracts.jl")

export native_matrix_sources
export analytic_hamiltonian, analytic_hamiltonian_derivative
export bare_energy_inverse,
    regularized_energy_inverse,
    regularized_energy_weight,
    eigenvector_corrections!,
    position_vertices!,
    physical_velocity_vertices!,
    raw_position_connections!,
    physical_velocity_vertices
export optical_position_vertices, cutoff_optical_position_vertices, OPTICAL_CUTOFF_VERTICES
export MatrixElementKind, MatrixElementRequest, MatrixElementPlan, MatrixElementSources
export MatrixElementWorkspace, KPointBatchWorkspace, KPointMatrixData, KPointOffset
export MatrixElementEvaluationCounts, matrix_data!
export SPECTRUM, ENERGY_DIFFERENCES, HAMILTONIAN_DERIVATIVES
export HAMILTONIAN_SECOND_DERIVATIVES, WANNIER_POSITION, INTERNAL_CONNECTION
export INTERNAL_CONNECTION_DERIVATIVES, GAUGE_CORRECTION, BERRY_CONNECTION, VELOCITY_VERTICES
export WANNIER_CURVATURE
export SPIN, SPIN_TIMES_HAMILTONIAN, SPIN_TIMES_POSITION
export SPIN_TIMES_HAMILTONIAN_POSITION, SPIN_VELOCITY
export compile_matrix_plan, has_capability, is_requested, resolve_kpoint_offset!
export prepare_real_space!, compute_spectrum!, compute_remaining!, compute_kpoint!, matrix
export compute_checked_spectrum!
export transform_to_hamiltonian_gauge!, canonicalize_eigenvectors!
export MixedFourierGrid, MixedFourierLayout, MixedFourierBlockStore
export mixed_fourier_grid, mixed_fourier_local_k_indices, resolve_mixed_fourier_factors
export mixed_fourier_memory_limit
export mixed_fourier_buffer_estimate
export enable_mixed_fourier!, begin_mixed_kpoint!, disable_mixed_fourier!
export mixed_fourier_stats, mixed_fourier_kslice_grid
export enable_fourier_timing!, disable_fourier_timing!, fourier_timing_stats

export HamiltonianMatrixData, PositionMatrixData, SpinMatrixData, SpinVelocityMatrixData
export SpinRealSpaceData, SpinGaugeDiagnostics, SpinTransformDiagnostics
export SpinVelocityRealSpaceData, SpinVelocityRealSpaceDiagnostics
export DerivativeOverlapRealSpaceData
export SpinVelocityTransformDiagnostics, FiniteDifferenceStencil
export spn_to_wannier_gauge_q, spn_to_wannier_gauge_q_diagnostics
export spin_q_to_r, spin_q_to_r_diagnostics, spin_r_to_wannier_gauge!
export spin_velocity_q_to_r, spin_velocity_q_to_r_diagnostics
export build_finite_difference_stencil, match_finite_difference_stencil_to_mmn
export RealSpaceReplicaPolicyResult, real_space_mp_residue
export nearest_wigner_seitz_images, apply_real_space_replica_policy
export real_space_link_length_summary
export WannierPairWignerSeitzTransformPlan, PairWignerSeitzSpinQToRTransform
export WannierDerivativeOperatorSet, WANNIER_DERIVATIVE_OPERATOR_KINDS
export construct_wannier_derivative_operators
export compute_spin_velocity_real_space
export compute_spin_velocity_real_space_streaming

export ProjectorMatrixData, ProjectorMatrixWorkspace
export bind_kpoint_offset!
export compute_projector_spectrum!, compute_wilson_shifted!
export projector_reference_projectors!,
    projector_projectors!, projector_fill_projectors_from_groups!
export projector_diff_projectors!,
    projector_pure_diff_projectors!, projector_second_diff_projectors!
export prepare_projector_covariant_geometry!, transport_projector_matrix_to_reference!
export GeometricLoopMatrixData, GeometricLoopMatrixWorkspace
export mark_degenerate_groups!,
    mark_geometric_response_groups!, degenerate_group_summary, extract_wannier_centers
export ConventionFrameConnector,
    IdentityConventionFrameConnector, WannierCenterConventionFrameConnector
export make_convention_frame_connector, compute_convention_covariant_overlap!

include("Interpolated/SpectralResponseGeometry.jl")
include("IntrinsicHallGeometry.jl")
include("IntrinsicHallWorkspace.jl")
export intrinsic_hall_geometry, prepare_intrinsic_hall_geometry!
include("Interpolated/OrbitalResponseOperators.jl")
export OrbitalCompletion,
    finite_model_orbital_completion,
    OrbitalRealSpaceSources,
    orbital_completion,
    validate_orbital_sources,
    SpectralResponseGeometry,
    NonorthogonalSpectralResponseGeometry,
    spectral_response_geometry,
    conventional_spectral_pair,
    projector_spectral_pair

# First-use compilation is driven by the public workloads.

end
