module OperatorExport

import Dates: UTC, now
import HDF5
import LinearAlgebra: Diagonal, Hermitian, I, diag, dot, eigvals, norm, rank, svdvals
import Printf: @printf, @sprintf
import SHA
import JSON3
import WannierNLQG
import WannierNLQG.Core:
    REAL_SPACE_AXIAL_DERIVATIVE_OVERLAP,
    REAL_SPACE_DERIVATIVE_OVERLAP_TENSOR,
    REAL_SPACE_HAMILTONIAN,
    REAL_SPACE_HAMILTONIAN_WEIGHTED_AXIAL_DERIVATIVE_OVERLAP,
    REAL_SPACE_HAMILTONIAN_WEIGHTED_CONNECTION,
    REAL_SPACE_POSITION,
    REAL_SPACE_SPIN,
    REAL_SPACE_SPIN_TIMES_HAMILTONIAN,
    REAL_SPACE_SPIN_TIMES_HAMILTONIAN_POSITION,
    REAL_SPACE_SPIN_TIMES_POSITION,
    REAL_SPACE_SYMMETRIC_DERIVATIVE_OVERLAP,
    RealSpaceOperator,
    RealSpaceOperatorKind,
    RealSpaceOperatorSymmetrySpec,
    TightBindingModel,
    real_space_operator_name
import WannierNLQG.Core
import WannierNLQG.IO:
    WannierCHK,
    WannierEIG,
    WannierMMN,
    foreach_wannier_uiu_block,
    operator_storage_name,
    write_wannier_tb
import WannierNLQG.IO
import WannierNLQG.MatrixElements:
    PairWignerSeitzSpinQToRTransform,
    apply_wannier_center_phases!,
    build_finite_difference_stencil,
    construct_wannier_derivative_operators,
    derive_axial_and_symmetric_derivative_overlaps,
    hermitianize_real_space_pairs,
    nearest_wigner_seitz_images,
    match_finite_difference_stencil_to_mmn,
    spn_to_wannier_gauge_q,
    transform_pair_wigner_seitz_spin_q_to_r,
    unit_degeneracy_roundtrip_error,
    wannier_q_to_pair_wigner_seitz,
    WannierDerivativeOperatorSet,
    WannierPairWignerSeitzTransformPlan
import WannierNLQG.SymmetryFoundation:
    AbstractWavefunctionSource,
    BandRepresentation,
    WannierSymmetryPlan,
    maximum_real_space_covariance_error,
    qualification_mask_sha256,
    read_band_representation_hdf5,
    sha256_file,
    symmetrize_real_space_operator,
    validate_authoritative_hamiltonian_key
import WannierNLQG.SymmetryFoundation
import WannierNLQG.Wannierization:
    COMPLETED,
    COMPLETED_WITH_WARNINGS,
    ExactWannierOperatorBundleConfig,
    ExactWannierOperatorBundleResult,
    IN_PROGRESS_CHECKPOINT,
    LOCALIZATION_FAILED,
    MAX_ITERATIONS,
    NativeDFTHamiltonian,
    SMV_FLETCHER_REEVES_TWO_STAGE_ALGORITHM_CONTRACT_VERSION,
    SymmetrizedDFTHamiltonian,
    SymmetryAdaptedWannierizationConfig,
    TB_SYMMETRY_QUALIFICATION_SCHEMA,
    TB_SYMMETRY_QUALIFICATION_SCHEMA_VERSION,
    TBSymmetryMetric,
    TBSymmetryQualification,
    WannierGaugeChainDiagnosticConfig,
    WannierGaugeChainDiagnosticResult,
    WannierHamiltonianOperatorGenerationConfig,
    WannierHamiltonianOperatorGenerationResult,
    WannierOperatorTargetContract,
    WannierizationArtifacts,
    WannierizationDiagnostic,
    WannierizationIteration,
    WannierizationResult,
    authoritative_hamiltonian_key,
    tb_symmetry_payload_sha256,
    wannier_operator_target_contract_sha256
import ..WannierizationInternalSupport:
    SYMMETRIZED_DFT_BAND_GAUGE,
    atomic_hdf5_write,
    band_frame_contract_sha256,
    band_frame_contract_summary,
    projection_basis_sha256,
    read_tb_symmetry_qualification_group,
    required_attribute,
    tb_symmetry_not_run,
    updated_wannierization_result,
    validate_persisted_authority_key,
    write_string_dictionary,
    write_tb_symmetry_qualification_group
import ..RepresentationPreparation:
    compare_wannier_projectors,
    effective_wannierization_algorithms,
    effective_wannierization_mode,
    representation_source,
    symmetry_constraints_applied,
    wannier_gauge_link_diagnostics
import ..PAWMatrixElements:
    STAR_COVARIANT_PAW_GAUGE_SCHEMA,
    WANNIER_UIU_GENERATION_SCHEMA,
    WANNIER_UIU_GENERATION_SCHEMA_VERSION,
    generation_band_gauge_contract,
    native_hamiltonian_gauge_covariance_residual,
    read_and_validate_spn_provenance,
    read_star_covariant_paw_gauge_hdf5,
    rotate_generation_link,
    rotate_generation_single,
    star_authoritative_hamiltonian_sha256,
    uiu_atomic_json,
    uiu_center_neighbor_block,
    uiu_source_state,
    operator_target_oracle_mmn_file,
    validate_generation_output_paths,
    validate_authoritative_mmn_binding,
    validate_operator_target_contract_files,
    validate_operator_target_contract_config,
    validate_operator_target_contract_frame,
    validate_generation_spn_provenance
import ..SolverCheckpoint:
    SYMMETRY_PROJECTED_SMV_FR_CONTRACT,
    checkpoint_stopping_reason,
    finite_difference_weights,
    is_symmetry_projected_smv_fr,
    orthonormalize_columns,
    projector_covariance_tolerance,
    restart_config_sha256,
    wannierization_checkpoint_sha256_v2_5,
    wannierization_production_eligible,
    wannierization_result_is_finite,
    read_wannierization_checkpoint_hdf5,
    write_wannierization_checkpoint_hdf5

include("../ExactWannierDerivativeOperators.jl")
include("../ExactWannierOperatorBundle.jl")
include("../AuthoritativeBandHamiltonian.jl")
include("../WannierHamiltonianOperatorGeneration.jl")
include("../TightBindingConstruction.jl")
include("../OperatorProfileAssembly.jl")
include("../WannierGaugeChainDiagnostics.jl")
include("../WannierizationOutputs.jl")
include("../TBSymmetryQualification.jl")

# Stable, non-private names form the only cross-component export surface.
const atomic_checkpoint_copy = _atomic_checkpoint_copy
const bind_packed_checkpoint_sha256! = _bind_packed_checkpoint_sha256!
const diagnostic_nonconverged_tb_export_allowed = _diagnostic_nonconverged_tb_export_allowed
const diagnostic_nonconverged_tb_export_gate = _diagnostic_nonconverged_tb_export_gate
const export_wannierization_tb = _export_wannierization_tb
const open_wannierization_log = _open_wannierization_log
const preflight_wannierization_operator_profile = _preflight_wannierization_operator_profile
const wannier_operator_target_contract = _wannier_operator_target_contract
const real_space_hermiticity_error = _real_space_hermiticity_error
const wannierization_observer = _wannierization_observer
const tb_symmetry_incomplete = _tb_symmetry_incomplete
const tb_symmetry_unavailable = _tb_symmetry_unavailable
const wannierization_output_paths = _wannierization_output_paths
const write_wannierization_final = _write_wannierization_final
const write_tb_symmetry_json = _write_tb_symmetry_json

const OPERATOR_EXPORT_INTEGRATION_API = (
    :AuthoritativeBandHamiltonian,
    :atomic_checkpoint_copy,
    :bind_packed_checkpoint_sha256!,
    :diagnostic_nonconverged_tb_export_allowed,
    :diagnostic_nonconverged_tb_export_gate,
    :export_wannierization_tb,
    :open_wannierization_log,
    :preflight_wannierization_operator_profile,
    :wannier_operator_target_contract,
    :real_space_hermiticity_error,
    :wannierization_observer,
    :tb_symmetry_incomplete,
    :tb_symmetry_unavailable,
    :wannierization_output_paths,
    :write_wannierization_final,
    :write_tb_symmetry_json,
    :authoritative_band_hamiltonian,
    :build_wannier_tight_binding_model,
    :diagnose_wannier_gauge_chain,
    :generate_wannier_shu,
    :generate_wannier_siu,
    :generate_wannier_uhu,
    :prepare_exact_wannier_operator_bundle,
    :qualify_exported_wannierization_tb,
)

const OPERATOR_EXPORT_TEST_API = ()

for name in OPERATOR_EXPORT_INTEGRATION_API
    @eval export $name
end

end
