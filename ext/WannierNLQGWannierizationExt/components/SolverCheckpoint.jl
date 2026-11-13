module SolverCheckpoint

import WannierNLQG.IO: read_hdf5_attribute_value

import WannierNLQG.Wannierization:
    wannier_stage_stability,
    WannierizationStageControls,
    WannierizationSolverConfig,
    ExternalOverlapProjectionMatrices,
    TB_TARGET_LEAKAGE_WEIGHT_FORMULA_SHA256,
    uses_generated_native_eigenvalues,
    uses_native_operator_generation

import WannierNLQG.Core:
    validate_ordinary_construction_policy, ScientificDataOwner, scientific_data_generation

import WannierNLQG.IO:
    write_scientific_file_publication, with_scientific_file_publication, scientific_file_state

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
import WannierNLQG.IO:
    WannierCHK,
    WannierEIG,
    WannierMMN,
    with_scientific_source,
    scientific_definition_stream,
    ScientificInputDefinition,
    scientific_reference_root,
    ScientificReferenceBuilder,
    append_scientific_input_reference!,
    scientific_input_definition_reference,
    scientific_input_reference_reader,
    scientific_input_definition_bytes,
    with_scientific_input_definition_bytes,
    validate_scientific_input_definition_bytes,
    validate_scientific_input_definitions_equal,
    write_native_definition_value
import WannierNLQG.SymmetryFoundation:
    BandRepresentation,
    BandRepresentationQualificationScope,
    SymmetryOperation,
    WannierSymmetryPlan,
    qualification_mask_definition,
    sha256_file,
    validate_authoritative_hamiltonian_key,
    validate_public_band_representation_contract,
    validate_unified_representation_mode_contract
import WannierNLQG.WannierProjection:
    WannierProjectionBasis, projection_radial_transform_contract, projection_basis_input_values
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
    WannierizationConfig,
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
    WannierizationRestartInputDefinition,
    WannierizationNumericalThresholds,
    WannierizationStatus,
    WannierizationEligibility,
    WANNIERIZATION_ELIGIBILITY_SUMMARY_KEYS,
    wannierization_eligibility_summary,
    wannierization_eligibility_from_summary,
    not_evaluated_wannierization_eligibility,
    authoritative_hamiltonian_key
import ..WannierizationInternalSupport:
    write_scientific_input_reference_hdf5,
    read_scientific_input_reference_hdf5,
    atomic_hdf5_write,
    band_sewing_backend_key,
    complete_window_indices,
    empty_group_law_worst_cases,
    hungarian_maximum_assignment,
    projection_basis_definition,
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
    construction_compatibility_quality_failure,
    antiunitary_projector_covariance_residual,
    build_representation_product_table,
    configured_num_wannier,
    effective_wannierization_algorithms,
    effective_wannierization_mode,
    representation_diagnostic,
    representation_diagnostics_for_policy,
    representation_source,
    representation_static_definition,
    symmetry_constraints_applied,
    validate_band_representation_compatibility,
    validate_selected_kramers_ranks,
    validate_target_operation_inventory
import ..PAWMatrixElements:
    TARGET_LEAKAGE_WEIGHT_FORMULA_DEFINITION, TARGET_LEAKAGE_WEIGHT_SEMANTICS

include("../SMVFletcherReevesAudit.jl")
include("../solver/LinearAlgebra.jl")
include("../solver/SymmetryFrames.jl")
include("../solver/Initialization.jl")
include("../solver/Localization.jl")
include("../solver/Optimizer.jl")
include("../solver/RestartContract.jl")
include("../solver/WannierizationRestartInputDefinitions.jl")
include("../solver/RestartWorkflow.jl")
include("../solver/SolverPreparation.jl")
include("../solver/SolverInitialization.jl")
include("../solver/SolverProposal.jl")
include("../solver/SolverAcceptance.jl")
include("../solver/SolverTermination.jl")
include("../solver/SolverIteration.jl")
include("../hdf5/FixedSubspace.jl")
include("../hdf5/CheckpointDigests.jl")
include("../solver/CheckpointDefinitionAgreement.jl")
include("../hdf5/WannierizationRestartInputIO.jl")
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
const solve_symmetry_adapted_wannierization = _solve_symmetry_adapted_wannierization
const validate_no_symmetry_identity_representation = _validate_no_symmetry_identity_representation
const wannierization_production_eligible = _wannierization_production_eligible
const wannierization_scoped_production_eligible = _wannierization_scoped_production_eligible
const wannierization_result_is_finite = _wannierization_result_is_finite

const SOLVER_CHECKPOINT_INTEGRATION_API = (
    :SYMMETRY_PROJECTED_SMV_FR_CONTRACT,
    :TargetSymmetryTangentPlan,
    :WannierizationRestartContract,
    :checkpoint_stopping_reason,
    :write_checkpoint_definition,
    :checkpoint_definition_stream,
    :agree_terminal_checkpoint_definition,
    :agree_scientific_definition_stream,
    :finite_difference_weights,
    :identity_band_representation,
    :identity_wannier_plan,
    :is_symmetry_projected_smv_fr,
    :no_symmetry_compatibility_contract,
    :orthonormalize_columns,
    :projector_covariance_tolerance,
    :solve_symmetry_adapted_wannierization,
    :validate_no_symmetry_identity_representation,
    :validate_restart_scientific_inputs,
    :wannierization_production_eligible,
    :wannierization_scoped_production_eligible,
    :wannierization_result_is_finite,
    :classify_wannierization_u_periodicity,
    :evaluate_full_3d_wannier_spreads,
    :read_wannierization_checkpoint_hdf5,
    :adopt_wannierization_checkpoint_hdf5,
    :read_checkpoint_publication,
    :smv_fletcher_reeves_two_stage_audit,
    :smv_fletcher_reeves_two_stage_audit_contract_sha256,
    :write_wannierization_u_convergence_diagnostics_hdf5,
    :write_wannierization_checkpoint_hdf5,
)

const SOLVER_CHECKPOINT_TEST_API = (
    :_accepted_unitary_displacement,
    :_amn_target_qualification_metrics,
    :_backtracking_step_scale,
    :_best_fletcher_reeves_finite_descent,
    :_build_target_symmetry_tangent_plans,
    :_candidate_invariant_failure,
    :_candidate_invariant_residuals,
    :_centers_spreads_and_directions,
    :_complete_selected_subspace_star,
    :_corepresentation_aware_maximum_subspace_result,
    :_deterministic_sealed_subspace_perturbation,
    :_disentanglement_candidate,
    :_evaluate_full_mesh_centers_spreads_and_directions,
    :_evaluate_mv_localization,
    :_expand_ibz_frames,
    :_expand_ibz_target_tangents,
    :_finite_difference_weights,
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
    :_restart_matrix_field,
    :_restore_expanded_frames_to_subspaces,
    :_rotate_hermitian_field_entry,
    :_rotate_localized_overlap_state,
    :_sealed_amn_polar,
    :_select_wannierization_multistart,
    :_solve_symmetry_adapted_wannierization,
    :_symmetry_projected_spread_gradient,
    :_target_symmetry_tangent_plan,
    :_transport_selected_subspace_corepresentation,
    :_unitary_geodesic_plan,
    :_unitary_geodesic_step,
    :_unpack_complex_real,
    :_validate_hermitian_eigensystem,
    :_validated_hermitian_spectrum,
    :_recursive_localization_amn_polar,
    :_recursive_localization_b_cartesian,
    :_recursive_localization_complex_exponential,
    :_recursive_localization_dis_project,
    :_recursive_localization_edge_b_cartesian,
    :_recursive_localization_finite_difference_weights,
    :_recursive_localization_ordered_column_conjugate_product,
    :_recursive_localization_ordered_column_division,
    :_recursive_localization_ordered_complex_product,
    :_recursive_localization_ordered_magnitude_squared,
    :_recursive_localization_ordered_phase_column_product,
    :_recursive_localization_ordered_scalar_magnitude_squared,
    :_recursive_localization_gradient_center_accumulate,
    :_recursive_localization_invariant_spread,
    :_recursive_localization_maximum_subspace_result,
    :_recursive_localization_objective_center_accumulate,
    :_recursive_localization_omega_d_accumulate,
    :_recursive_localization_optimal_step,
    :_recursive_localization_phase,
    :_recursive_localization_search_direction,
    :_recursive_localization_unitary_step,
    :_recursive_localization_weight_total,
    :_recursive_localization_zdot,
    :_recursive_localization_zgemm,
    :_recursive_localization_zhpevx,
    :_mv_branch_orbit_definition,
    :_u_branch_definition,
    :_validate_u_branch_definition,
    :_write_restart_branch_definition_hdf5,
    :_read_restart_branch_definition_hdf5,
    :_restart_input_definition,
)

for name in SOLVER_CHECKPOINT_INTEGRATION_API
    @eval export $name
end

end
