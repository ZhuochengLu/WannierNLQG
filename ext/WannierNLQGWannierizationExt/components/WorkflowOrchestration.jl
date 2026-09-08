module WorkflowOrchestration

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
    ExternalWannier90Matrices,
    FarBandCovarianceCorrection,
    NativeQEPAWMatrices,
    NativeEigenstateGauge,
    NativeVASPPAWMatrices,
    PAWGaugeThresholds,
    PAWSCDMInitialization,
    SymmetryAdaptedWannierizationConfig,
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
    projection_basis_sha256,
    replace_wannierization_config
import ..RepresentationPreparation:
    build_band_representation,
    configured_num_wannier,
    constraint_scoped_fixed_subspace,
    constraint_scoped_representation,
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
    TARGET_LEAKAGE_WEIGHT_FORMULA_SHA256,
    TARGET_LEAKAGE_WEIGHT_SEMANTICS,
    generate_vasp_paw_matrix_elements_impl,
    paw_metric_passes,
    read_augmentation_aware_native_source,
    read_star_covariant_paw_gauge_hdf5,
    star_authoritative_hamiltonian_metadata,
    star_authoritative_hamiltonian_sha256,
    star_hamiltonian_correction_sha256,
    star_rotate_parent_amn,
    star_rotate_parent_mmn,
    star_transform_sewing_gauge,
    validate_star_gauge_source_identity,
    generate_qe_paw_matrix_elements,
    generate_symmetry_completed_qe_paw_matrix_elements,
    read_paw_scdm_input_artifact
import ..SolverCheckpoint:
    checkpoint_stopping_reason,
    finite_difference_weights,
    identity_band_representation,
    identity_wannier_plan,
    no_symmetry_compatibility_contract,
    restart_config_sha256,
    solve_symmetry_adapted_wannierization,
    validate_no_symmetry_identity_representation,
    wannierization_checkpoint_sha256,
    wannierization_checkpoint_sha256_v1_2,
    wannierization_checkpoint_sha256_v2_2,
    wannierization_checkpoint_sha256_v2_21,
    wannierization_checkpoint_sha256_v2_22,
    wannierization_checkpoint_sha256_v2_3,
    wannierization_checkpoint_sha256_v2_4,
    wannierization_checkpoint_sha256_v2_6,
    wannierization_production_eligible,
    wannierization_result_is_finite,
    read_wannierization_checkpoint_hdf5,
    read_wannierization_fixed_subspace_hdf5,
    write_wannierization_checkpoint_hdf5
import ..OperatorExport:
    atomic_checkpoint_copy,
    bind_packed_checkpoint_sha256!,
    diagnostic_nonconverged_tb_export_allowed,
    diagnostic_nonconverged_tb_export_gate,
    export_wannierization_tb,
    open_wannierization_log,
    preflight_wannierization_operator_profile,
    wannier_operator_target_contract,
    wannierization_observer,
    tb_symmetry_incomplete,
    tb_symmetry_unavailable,
    wannierization_output_paths,
    write_wannierization_final,
    write_tb_symmetry_json,
    qualify_exported_wannierization_tb

include("../WannierizationWorkflow.jl")

const WORKFLOW_ORCHESTRATION_INTEGRATION_API = (
    :construct_symmetry_adapted_wannier_functions,
    :prepare_band_representation,
    :prepare_wannier_operator_target_contract,
)

const WORKFLOW_ORCHESTRATION_TEST_API = ()

for name in WORKFLOW_ORCHESTRATION_INTEGRATION_API
    @eval export $name
end

end
