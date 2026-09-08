module SolverCheckpoint

import HDF5
import JSON3
import LinearAlgebra
import LinearAlgebra:
    ColumnNorm,
    Diagonal,
    Hermitian,
    I,
    det,
    diag,
    dot,
    eigen,
    eigvals,
    mul!,
    norm,
    opnorm,
    qr,
    rank,
    schur,
    svd,
    svdvals
import MPI
import Random: MersenneTwister, randn
import SHA
import WannierNLQG.Core: reciprocal_lattice
import WannierNLQG.IO: WannierCHK, WannierEIG, WannierMMN
import WannierNLQG.SymmetryFoundation:
    BandRepresentation,
    BandRepresentationQualificationScope,
    SymmetryOperation,
    WannierSymmetryPlan,
    qualification_mask_sha256,
    sha256_file,
    validate_authoritative_hamiltonian_key,
    validate_public_band_representation_contract,
    validate_unified_representation_mode_contract
import WannierNLQG.WannierProjection: WannierProjectionBasis, projection_radial_transform_contract
import WannierNLQG.Wannierization:
    AMNExactFrozenInitialization,
    AugmentationAwareSewing,
    BandRepresentationPreparationConfig,
    COMPLETED,
    COMPLETED_WITH_WARNINGS,
    CoefficientMappingSewing,
    DisentanglementState,
    GATE_NOT_EVALUATED,
    INVALID_INPUT,
    IN_PROGRESS_CHECKPOINT,
    IO_FAILURE,
    LOCALIZATION_FAILED,
    MAX_ITERATIONS,
    REPRESENTATION_INCOMPATIBLE,
    REPRESENTATION_UNDETERMINED,
    REPRESENTATION_VALIDATION_UNDETERMINED,
    RepresentationCompatibilityReport,
    SINGULAR_LOCALIZATION,
    SMVFletcherReevesTwoStageAuditThresholds,
    SMV_FLETCHER_REEVES_TWO_STAGE_ALGORITHM_CONTRACT_VERSION,
    SMV_FLETCHER_REEVES_TWO_STAGE_AUDIT_PASS_STATUS,
    SMV_FLETCHER_REEVES_TWO_STAGE_AUDIT_SCHEMA,
    SMV_FLETCHER_REEVES_TWO_STAGE_AUDIT_SCHEMA_VERSION,
    PAWSCDMInputArtifact,
    PAWSCDMInitialization,
    NativeEigenstateGauge,
    ProjectabilityDisentanglementInitialization,
    SymmetryAdaptedWannierizationConfig,
    StarCovariantPAWGauge,
    WannierizationAccelerationConfig,
    WannierizationArtifacts,
    WannierInitializationKPointDiagnostic,
    WannierInitializationReport,
    WannierizationResult,
    WannierizationDiagnostic,
    WannierizationFiniteDifferenceStencil,
    WannierizationFixedSubspace,
    WannierizationIteration,
    WannierizationIterationDiagnostics,
    WannierizationOptimizerState,
    WannierizationRestartState,
    WannierizationNumericalThresholds,
    WannierizationStatus,
    authoritative_hamiltonian_key
import ..WannierizationInternalSupport:
    atomic_hdf5_write,
    band_sewing_backend_key,
    complete_window_indices,
    empty_group_law_worst_cases,
    hungarian_maximum_assignment,
    projection_basis_sha256,
    read_string_dictionary,
    read_tb_symmetry_qualification_group,
    required_attribute,
    target_representation,
    tb_symmetry_not_run,
    validate_persisted_authority_key,
    validate_smv_fletcher_reeves_two_stage_audit_thresholds,
    wavefunction_gauge_backend_key,
    write_generation_environment,
    write_string_dictionary,
    write_tb_symmetry_qualification_group
import ..RepresentationPreparation:
    antiunitary_projector_covariance_residual,
    build_representation_product_table,
    configured_num_wannier,
    effective_wannierization_algorithms,
    effective_wannierization_mode,
    representation_diagnostic,
    representation_diagnostics_for_policy,
    representation_source,
    representation_static_sha256,
    symmetry_constraints_applied,
    validate_band_representation_compatibility,
    validate_selected_kramers_ranks,
    validate_target_operation_inventory
import ..PAWMatrixElements: TARGET_LEAKAGE_WEIGHT_FORMULA_SHA256, TARGET_LEAKAGE_WEIGHT_SEMANTICS

include("../SMVFletcherReevesAudit.jl")
include("../solver/LinearAlgebra.jl")
include("../solver/SymmetryFrames.jl")
include("../solver/Initialization.jl")
include("../solver/Localization.jl")
include("../solver/Optimizer.jl")
include("../solver/RestartContract.jl")
include("../solver/RestartWorkflow.jl")
include("../solver/SolverPreparation.jl")
include("../solver/SolverInitialization.jl")
include("../solver/SolverProposal.jl")
include("../solver/SolverAcceptance.jl")
include("../solver/SolverTermination.jl")
include("../solver/SolverIteration.jl")
include("../hdf5/FixedSubspace.jl")
include("../hdf5/CheckpointDigests.jl")
include("../hdf5/Writer.jl")
include("../hdf5/LegacyMigration.jl")
include("../hdf5/Reader.jl")
include("../WannierizationNoSymmetry.jl")

# Stable, non-private names form the only cross-component solver surface.
const checkpoint_stopping_reason = _checkpoint_stopping_reason
const finite_difference_weights = _finite_difference_weights
const identity_band_representation = _identity_band_representation
const identity_wannier_plan = _identity_wannier_plan
const is_symmetry_projected_smv_fr = _is_symmetry_projected_smv_fr
const no_symmetry_compatibility_contract = _no_symmetry_compatibility_contract
const orthonormalize_columns = _orthonormalize_columns
const projector_covariance_tolerance = _projector_covariance_tolerance
const restart_config_sha256 = _restart_config_sha256
const solve_symmetry_adapted_wannierization = _solve_symmetry_adapted_wannierization
const validate_no_symmetry_identity_representation = _validate_no_symmetry_identity_representation
const wannierization_checkpoint_sha256 = _wannierization_checkpoint_sha256
const wannierization_checkpoint_sha256_v1_2 = _wannierization_checkpoint_sha256_v1_2
const wannierization_checkpoint_sha256_v2_2 = _wannierization_checkpoint_sha256_v2_2
const wannierization_checkpoint_sha256_v2_21 = _wannierization_checkpoint_sha256_v2_21
const wannierization_checkpoint_sha256_v2_22 = _wannierization_checkpoint_sha256_v2_22
const wannierization_checkpoint_sha256_v2_3 = _wannierization_checkpoint_sha256_v2_3
const wannierization_checkpoint_sha256_v2_4 = _wannierization_checkpoint_sha256_v2_4
const wannierization_checkpoint_sha256_v2_5 = _wannierization_checkpoint_sha256_v2_5
const wannierization_checkpoint_sha256_v2_6 = _wannierization_checkpoint_sha256_v2_6
const wannierization_production_eligible = _wannierization_production_eligible
const wannierization_result_is_finite = _wannierization_result_is_finite

const SOLVER_CHECKPOINT_INTEGRATION_API = (
    :SYMMETRY_PROJECTED_SMV_FR_CONTRACT,
    :TargetSymmetryTangentPlan,
    :WannierizationRestartContract,
    :checkpoint_stopping_reason,
    :finite_difference_weights,
    :identity_band_representation,
    :identity_wannier_plan,
    :is_symmetry_projected_smv_fr,
    :no_symmetry_compatibility_contract,
    :orthonormalize_columns,
    :projector_covariance_tolerance,
    :restart_config_sha256,
    :solve_symmetry_adapted_wannierization,
    :validate_no_symmetry_identity_representation,
    :wannierization_checkpoint_sha256,
    :wannierization_checkpoint_sha256_v1_2,
    :wannierization_checkpoint_sha256_v2_2,
    :wannierization_checkpoint_sha256_v2_21,
    :wannierization_checkpoint_sha256_v2_22,
    :wannierization_checkpoint_sha256_v2_3,
    :wannierization_checkpoint_sha256_v2_4,
    :wannierization_checkpoint_sha256_v2_5,
    :wannierization_checkpoint_sha256_v2_6,
    :wannierization_production_eligible,
    :wannierization_result_is_finite,
    :classify_wannierization_u_periodicity,
    :evaluate_full_3d_wannier_spreads,
    :read_wannierization_checkpoint_hdf5,
    :read_wannierization_fixed_subspace_hdf5,
    :smv_fletcher_reeves_two_stage_audit,
    :smv_fletcher_reeves_two_stage_audit_contract_sha256,
    :write_wannierization_u_convergence_diagnostics_hdf5,
    :write_wannierization_checkpoint_hdf5,
    :write_wannierization_fixed_subspace_hdf5,
)

const SOLVER_CHECKPOINT_TEST_API = (
    :_acceleration_trial_action,
    :_accepted_unitary_displacement,
    :_adaptive_next_mixing,
    :_amn_target_qualification_metrics,
    :_anderson_trial_policy,
    :_anderson_z_proposal,
    :_backtracking_step_scale,
    :_best_fletcher_reeves_finite_descent,
    :_build_target_symmetry_tangent_plans,
    :_candidate_invariant_failure,
    :_candidate_invariant_residuals,
    :_centers_spreads_and_directions,
    :_complete_selected_subspace_star,
    :_complex_field_sha256,
    :_corepresentation_aware_maximum_subspace_result,
    :_deterministic_sealed_subspace_perturbation,
    :_disentanglement_candidate,
    :_evaluate_full_mesh_centers_spreads_and_directions,
    :_evaluate_mv_localization,
    :_expand_ibz_frames,
    :_expand_ibz_target_tangents,
    :_finite_difference_weights,
    :_fixed_subspace_initial_frames,
    :_fixed_subspace_projector_drift_tolerance,
    :_frame_geodesic_distance,
    :_frozen_indices,
    :_frozen_target_embedding,
    :_global_permutation_phase_diagnostic,
    :_initial_frames,
    :_initial_frames_with_diagnostics,
    :_initial_wannier_centers,
    :_is_complete_outer_space,
    :_legacy_initial_frames,
    :_localization_backtracking_limit,
    :_localization_directional_derivative,
    :_localization_objective_accepts,
    :_localization_svd_polar,
    :_localization_sweep_entry_count,
    :_maximum_projector_covariance_error,
    :_maximum_projector_drift,
    :_maximum_projector_step,
    :_maximum_subspace,
    :_maximum_subspace_result,
    :_maximum_target_frame_symmetry_error,
    :_mesh_neighbor_displacement,
    :_minimum_diagonal_phase_margin,
    :_minimum_norm_clarke_combination,
    :_minimum_z_boundary_gap,
    :_mix_unitaries,
    :_mix_z_fields,
    :_mv_centered_full_mesh_centers_spreads_and_directions,
    :_mv_centered_gradient_data,
    :_mv_generalized_directional_derivative,
    :_mv_localization_phase,
    :_mv_spread_gradient,
    :_objective_aware_anderson_decision,
    :_orthonormalize_columns,
    :_orthonormalize_columns_result,
    :_pack_complex_real,
    :_polar_retracted_tangent_step,
    :_polar_retraction_curve_velocity,
    :_project_target_symmetry_tangent,
    :_projector_covariance_tolerance,
    :_qualify_nonconverged_disentanglement_state,
    :_rank_gated_polar_columns,
    :_rank_gated_svd_polar_columns,
    :_raw_amn_localization_reference,
    :_raw_z_field,
    :_record_terminal_state!,
    :_reduce_full_star_hermitian_field,
    :_repair_expanded_frozen_frame,
    :_representation_target_subspace_contract,
    :_restart_config_repr,
    :_restart_config_sha256,
    :_restart_config_sha256_pre_v2_11,
    :_restart_config_sha256_pre_v2_6,
    :_restart_config_sha256_pre_v2_7,
    :_restart_matrix_field,
    :_restore_expanded_frames_to_subspaces,
    :_riemannian_lbfgs_direction,
    :_rotate_hermitian_field_entry,
    :_rotate_localized_overlap_state,
    :_sealed_amn_polar,
    :_select_wannierization_multistart,
    :_shrunken_acceleration_mixing,
    :_solve_symmetry_adapted_wannierization,
    :_symmetry_projected_spread_gradient,
    :_target_symmetry_tangent_plan,
    :_transport_selected_subspace_corepresentation,
    :_unitary_geodesic_plan,
    :_unitary_geodesic_step,
    :_unpack_complex_real,
    :_validate_hermitian_eigensystem,
    :_validated_hermitian_spectrum,
    :_wannier90_reference_amn_polar,
    :_wannier90_reference_b_cartesian,
    :_wannier90_reference_complex_exponential,
    :_wannier90_reference_dis_project,
    :_wannier90_reference_edge_b_cartesian,
    :_wannier90_reference_finite_difference_weights,
    :_wannier90_reference_gfortran_column_conjugate_product,
    :_wannier90_reference_gfortran_column_division,
    :_wannier90_reference_gfortran_complex_product,
    :_wannier90_reference_gfortran_magnitude_squared,
    :_wannier90_reference_gfortran_phase_column_product,
    :_wannier90_reference_gfortran_scalar_magnitude_squared,
    :_wannier90_reference_gradient_center_accumulate,
    :_wannier90_reference_invariant_spread,
    :_wannier90_reference_maximum_subspace_result,
    :_wannier90_reference_objective_center_accumulate,
    :_wannier90_reference_omega_d_accumulate,
    :_wannier90_reference_optimal_step,
    :_wannier90_reference_phase,
    :_wannier90_reference_search_direction,
    :_wannier90_reference_unitary_step,
    :_wannier90_reference_weight_total,
    :_wannier90_reference_zdot,
    :_wannier90_reference_zgemm,
    :_wannier90_reference_zhpevx,
)

for name in SOLVER_CHECKPOINT_INTEGRATION_API
    @eval export $name
end

end
