module WorkflowOrchestration

import WannierNLQG.Core: validate_ordinary_construction_policy

import HDF5
import JSON3
import LinearAlgebra: I, svdvals
import MPI
import SHA
import WannierNLQG.Core
import WannierNLQG.IO
import WannierNLQG.SymmetryFoundation:
    AbstractWavefunctionSource,
    BandRepresentation,
    BandRepresentationQualificationScope,
    QuantumEspressoWavefunctionSource,
    RepresentationRawDiagnostic,
    VASPWavefunctionSource,
    detect_magnetic_symmetry_inventory,
    read_band_representation_hdf5,
    write_band_representation_hdf5
import WannierNLQG.SymmetryFoundation
import WannierNLQG.WannierProjection:
    WannierProjectionBasis, build_wannier_projection_basis, build_wannier_symmetry_plan
import WannierNLQG.WannierProjection
import WannierNLQG.Wannierization
import ..WannierizationInternalSupport:
    AbstractBandSewingBackend,
    AbstractAuthoritativeHamiltonian,
    AbstractWavefunctionGaugeBackend,
    AMNExactFrozenInitialization,
    AugmentationAwareSewing,
    BandRepresentationPreparationConfig,
    BandRepresentationPreparationResult,
    COMPLETED,
    COMPLETED_WITH_WARNINGS,
    CoefficientMappingSewing,
    INVALID_INPUT,
    IO_FAILURE,
    REPRESENTATION_INCOMPATIBLE,
    REPRESENTATION_UNDETERMINED,
    REPRESENTATION_VALIDATION_UNDETERMINED,
    RepresentationCompatibilityReport,
    ExternalOverlapProjectionMatrices,
    FarBandCovarianceCorrection,
    NativeQEPAWMatrices,
    NativeEigenstateGauge,
    NativeVASPPAWMatrices,
    PAWGaugeThresholds,
    PAWSCDMInitialization,
    WannierizationConfig,
    StarCovariantPAWGauge,
    SymmetryCompletedQEPAWMatrices,
    SymmetrizedDFTHamiltonian,
    TargetSubspaceQualificationContract,
    VASPPAWMatrixElementResult,
    VASPPAWParityThresholds,
    WannierizationDiagnostic,
    WannierizationIteration,
    WannierizationArtifacts,
    WannierizationResult,
    WannierizationStatus,
    WannierizationEligibility,
    WANNIERIZATION_ELIGIBILITY_SUMMARY_KEYS,
    wannierization_eligibility_summary,
    wannierization_eligibility_from_summary,
    not_evaluated_wannierization_eligibility,
    authoritative_hamiltonian_key,
    canonical_band_block_labels,
    read_band_representation_preparation_hdf5,
    sha256_file,
    atomic_hdf5_write,
    window_masks_from_energies,
    write_tb_symmetry_qualification_group,
    updated_wannierization_result,
    band_sewing_backend_key,
    discrete_hamiltonian_correction_key,
    wavefunction_gauge_backend_key,
    projection_basis_definition,
    replace_wannierization_config
import ..RepresentationPreparation:
    construction_compatibility_quality_failure,
    build_band_representation,
    configured_num_wannier,
    constraint_scoped_representation,
    select_detected_operations,
    effective_wannierization_algorithms,
    effective_wannierization_mode,
    generate_amn,
    read_wannier_amn,
    record_wannier_gauge_link_summary!,
    representation_source,
    symmetry_constraints_applied,
    wannier_gauge_link_diagnostics,
    read_native_source,
    validate_band_representation_compatibility,
    validate_wannierization_config
import ..PAWMatrixElements:
    _star_hamiltonian_correction_metadata,
    with_spn_provenance_reuse,
    native_preparation_source_files,
    preparation_implementation_paths,
    TARGET_LEAKAGE_WEIGHT_FORMULA_DEFINITION,
    TARGET_LEAKAGE_WEIGHT_SEMANTICS,
    generate_vasp_paw_matrix_elements_impl,
    paw_metric_passes,
    read_augmentation_aware_native_source,
    read_star_covariant_paw_gauge_hdf5,
    star_authoritative_hamiltonian_metadata,
    star_authoritative_hamiltonian_definition,
    star_hamiltonian_correction_definition,
    star_rotate_parent_amn,
    star_rotate_parent_mmn,
    star_transform_sewing_gauge,
    validate_star_gauge_source_identity,
    generate_qe_paw_matrix_elements,
    generate_symmetry_completed_qe_paw_matrix_elements,
    read_paw_scdm_input_artifact
import ..SolverCheckpoint:
    checkpoint_stopping_reason,
    agree_terminal_checkpoint_definition,
    agree_scientific_definition_stream,
    finite_difference_weights,
    identity_band_representation,
    identity_wannier_plan,
    no_symmetry_compatibility_contract,
    solve_symmetry_adapted_wannierization,
    validate_no_symmetry_identity_representation,
    wannierization_production_eligible,
    wannierization_scoped_production_eligible,
    wannierization_result_is_finite,
    read_wannierization_checkpoint_hdf5,
    write_wannierization_checkpoint_hdf5
import ..OperatorExport:
    atomic_checkpoint_copy,
    bind_packed_checkpoint_publication!,
    accepted_state_tb_export_allowed,
    accepted_state_tb_export_gate,
    export_wannierization_tb,
    open_wannierization_log,
    preflight_wannierization_operator_profile,
    validate_completed_operator_pair,
    validate_completed_operator_set,
    operator_profile_source_files,
    wannier_operator_target_contract,
    wannierization_observer,
    tb_symmetry_incomplete,
    tb_symmetry_unavailable,
    wannierization_output_paths,
    write_wannierization_final,
    write_tb_symmetry_json,
    qualify_exported_wannierization_tb,
    operator_output_requires_target_contract

include("../NativeOperatorOutputGeneration.jl")
include("../WannierizationWorkflow.jl")

const WORKFLOW_ORCHESTRATION_INTEGRATION_API = (
    :construct_wannier_functions,
    :construct_wannier_functions_with_native_inputs,
    :prepare_band_representation,
    :prepare_wannier_operator_target_contract,
)

const WORKFLOW_ORCHESTRATION_TEST_API = (
    :_publish_native_input_views,
    :_adopt_native_input_views,
    :_native_input_reuse_phase,
    :_validate_native_input_view_lifetimes,
)

for name in WORKFLOW_ORCHESTRATION_INTEGRATION_API
    @eval export $name
end

end
