module PAWMatrixElements

import FFTW
import HDF5
import JSON3
import LinearAlgebra:
    ColumnNorm,
    Diagonal,
    Hermitian,
    I,
    SymTridiagonal,
    cholesky,
    cross,
    det,
    diag,
    dot,
    eigen,
    eigvals,
    mul!,
    norm,
    opnorm,
    pinv,
    qr,
    rank,
    svd,
    svdvals,
    tr
import Printf: @sprintf
import SHA
import SHA: sha256
import WannierNLQG.Core: reciprocal_lattice
import WannierNLQG.IO:
    WannierAMN,
    WannierEIG,
    WannierMMN,
    WannierMMNTopology,
    WannierNNKP,
    WannierSPN,
    foreach_wannier_mmn_block,
    foreach_wannier_uiu_block,
    read_fortran_record,
    read_wannier_amn,
    read_wannier_mmn,
    read_wannier_mmn_topology,
    read_wannier_nnkp,
    read_wannier_spn,
    write_wannier_amn,
    write_wannier_eig,
    write_wannier_mmn,
    write_wannier_spn
import WannierNLQG.SymmetryFoundation:
    AbstractWavefunctionSource,
    BOHR_TO_ANGSTROM,
    BandRepresentation,
    BandRepresentationQualificationScope,
    CrystalStructure,
    HARTREE_TO_EV,
    NativeWavefunctionData,
    PlaneWaveKPoint,
    QuantumEspressoWavefunctionSource,
    SymmetryOperation,
    VASPWavecarHeader,
    VASPWavefunctionSource,
    build_canonical_kpoint_action,
    canonical_band_block_labels,
    canonical_band_operation_key,
    canonical_irreducible_star_plan,
    detect_magnetic_symmetry_inventory,
    infer_mp_grid,
    read_band_representation_hdf5,
    read_vasp_wavecar_header,
    read_vasp_wavefunctions,
    sha256_file,
    spin_action_matrix,
    validate_authoritative_hamiltonian_key,
    validate_canonical_antiunitary_channel
import WannierNLQG.WannierProjection:
    WannierProjectionBasis, WannierProjectionBlock, projection_orbital_values
import WannierNLQG.Wannierization:
    AbstractAuthoritativeHamiltonian,
    AbstractDiscreteHamiltonianCorrection,
    AbstractPAWBlockPartitionPolicy,
    AdaptiveEvidencePAWBlockPartition,
    AugmentationAwareSewing,
    ClosureDrivenBandBuffer,
    ControlledHamiltonianSymmetryThresholds,
    FarBandCovarianceCorrection,
    FixedGapPAWBlockPartition,
    HamiltonianWeightedPAWBlockPartition,
    NativeDFTHamiltonian,
    NoDiscreteHamiltonianCorrection,
    PAWBlockPartitionAuditConfig,
    PAWBlockPartitionAuditResult,
    PAWGaugeThresholds,
    PAWSCDMInputArtifact,
    QEPAWArrayParityMetrics,
    QEPAWMatrixElementResult,
    QEPAWParityThresholds,
    QEPAWSPNResult,
    RepresentationProductTable,
    StarCovariantPAWGauge,
    SymmetrizedDFTHamiltonian,
    SymmetryCovariantWavefunctionPreparationConfig,
    SymmetryCovariantWavefunctionPreparationResult,
    TargetSubspaceQualificationContract,
    VASPPAWArrayParityMetrics,
    VASPPAWMatrixElementResult,
    VASPPAWParityThresholds,
    VASPPAWSPNResult,
    VASPPAWSPNThresholds,
    VASPPAWSolverGaugeDiagnostics,
    WannierUIUGenerationConfig,
    WannierUIUGenerationResult,
    WannierUIUGenerationThresholds,
    WannierUIUParityMetrics,
    WannierOperatorTargetContract,
    WannierizationDiagnostic,
    authoritative_hamiltonian_key,
    wannier_operator_target_contract_sha256
import ..WannierizationInternalSupport:
    BAND_FRAME_TRANSFORM_CONTRACT_SCHEMA,
    BAND_FRAME_TRANSFORM_CONTRACT_SCHEMA_VERSION,
    BandFrameTransformContract,
    NATIVE_DFT_BAND_GAUGE,
    SAWF_COMPLETED_NATIVE_DFT_BAND_GAUGE,
    SYMMETRIZED_DFT_BAND_GAUGE,
    atomic_hdf5_write,
    band_frame_contract_metadata,
    band_frame_contract_sha256,
    band_frame_contract_summary,
    band_sewing_backend_key,
    build_augmentation_aware_band_representation,
    discrete_hamiltonian_correction_key,
    hungarian_maximum_assignment,
    is_symmetrized_authority,
    paw_block_partition_policy_key,
    projection_basis_sha256,
    read_string_dictionary,
    write_band_frame_contract_attributes!,
    write_string_dictionary
import ..RepresentationPreparation:
    QEProjectorAtomPlan,
    QEProjectorChannel,
    QEProjectorPlan,
    QEUPFData,
    VASPPawAtomLayout,
    VASPPawChannel,
    VASPPawDataset,
    VASPPawSystem,
    build_qe_projector_plan,
    build_representation_product_table,
    group_law_combination_index,
    paw_logarithmic_simpson,
    paw_radial_q0,
    qe_metric_kind_label,
    qe_wavefunction_file,
    qe_xml_numbers,
    qe_xml_required,
    read_qe_raw_wavefunctions,
    read_qe_upf_data,
    read_qe_wavefunction_header,
    read_qe_wavefunction_kpoint,
    read_qe_wavefunctions,
    read_qe_xml,
    read_vasp_paw_system,
    validate_band_group_law,
    validate_band_representation_compatibility,
    validate_symmetry_covariant_wavefunction_preparation_config

include("../VASPPawMatrixElements.jl")
include("../VASPPawSpinMatrixElements.jl")
include("../QEPAWMatrixElements.jl")
include("../WannierUIUGeneration.jl")
include("../QEPAWSpinMatrixElements.jl")
include("../AugmentationAwareBandSewing.jl")
include("../star_gauge/FrameContract.jl")
include("../star_gauge/StarTransport.jl")
include("../star_gauge/PartitionReynolds.jl")
include("../star_gauge/Persistence.jl")
include("../star_gauge/ConstructionWorkflow.jl")
include("../PAWSCDMInitialization.jl")
include("../PAWBlockPartitionAudit.jl")
include("../SymmetryCompletedQEPAWMatrixElements.jl")
include("../GaugeProvenanceContracts.jl")

# Stable, non-private names form the only cross-component PAW surface.
const StarCovariantPAWPayload = _StarCovariantPAWPayload
const generation_band_gauge_contract = _generation_band_gauge_contract
const generate_vasp_paw_matrix_elements_impl = _generate_vasp_paw_matrix_elements
const native_hamiltonian_gauge_covariance_residual = _native_hamiltonian_gauge_covariance_residual
const paw_metric_passes = _paw_metric_passes
const qe_spn_payload_sha256 = _qe_spn_payload_sha256
const read_and_validate_spn_provenance = _read_and_validate_spn_provenance
const read_augmentation_aware_native_source = _read_augmentation_aware_native_source
const read_star_covariant_paw_gauge_hdf5 = _read_star_covariant_paw_gauge_hdf5
const rotate_generation_link = _rotate_generation_link
const rotate_generation_single = _rotate_generation_single
const spn_provenance_contract_sha256 = _spn_provenance_contract_sha256
const star_array_sha256 = _star_array_sha256
const star_authoritative_hamiltonian_metadata = _star_authoritative_hamiltonian_metadata
const star_authoritative_hamiltonian_sha256 = _star_authoritative_hamiltonian_sha256
const star_hamiltonian_correction_sha256 = _star_hamiltonian_correction_sha256
const star_rotate_parent_amn = _star_rotate_parent_amn
const star_rotate_parent_mmn = _star_rotate_parent_mmn
const star_transform_sewing_gauge = _star_transform_sewing_gauge
const uiu_atomic_json = _uiu_atomic_json
const uiu_center_neighbor_block = _uiu_center_neighbor_block
const uiu_kpoint_fractional = _uiu_kpoint_fractional
const uiu_source_state = _uiu_source_state
const validate_authoritative_mmn_binding = _validate_authoritative_mmn_binding
const operator_target_oracle_mmn_file = _operator_target_oracle_mmn_file
const validate_generation_output_paths = _validate_generation_output_paths
const validate_operator_target_contract_files = _validate_operator_target_contract_files
const validate_operator_target_contract_config = _validate_operator_target_contract_config
const validate_operator_target_contract_frame = _validate_operator_target_contract_frame
const validate_star_gauge_source_identity = _validate_star_gauge_source_identity
const validate_generation_spn_provenance = _validate_generation_spn_provenance

const PAW_MATRIX_ELEMENTS_INTEGRATION_API = (
    :QE_PAW_SPN_SCHEMA,
    :QE_PAW_SPN_SCHEMA_VERSION,
    :STAR_COVARIANT_PAW_GAUGE_SCHEMA,
    :TARGET_LEAKAGE_WEIGHT_FORMULA_SHA256,
    :TARGET_LEAKAGE_WEIGHT_SEMANTICS,
    :WANNIER_UIU_GENERATION_SCHEMA,
    :WANNIER_UIU_GENERATION_SCHEMA_VERSION,
    :StarCovariantPAWPayload,
    :generation_band_gauge_contract,
    :generate_vasp_paw_matrix_elements_impl,
    :native_hamiltonian_gauge_covariance_residual,
    :paw_metric_passes,
    :qe_spn_payload_sha256,
    :read_and_validate_spn_provenance,
    :read_augmentation_aware_native_source,
    :read_star_covariant_paw_gauge_hdf5,
    :rotate_generation_link,
    :rotate_generation_single,
    :spn_provenance_contract_sha256,
    :star_array_sha256,
    :star_authoritative_hamiltonian_metadata,
    :star_authoritative_hamiltonian_sha256,
    :star_hamiltonian_correction_sha256,
    :star_rotate_parent_amn,
    :star_rotate_parent_mmn,
    :star_transform_sewing_gauge,
    :uiu_atomic_json,
    :uiu_center_neighbor_block,
    :uiu_kpoint_fractional,
    :uiu_source_state,
    :validate_authoritative_mmn_binding,
    :operator_target_oracle_mmn_file,
    :validate_generation_output_paths,
    :validate_operator_target_contract_files,
    :validate_operator_target_contract_config,
    :validate_operator_target_contract_frame,
    :validate_star_gauge_source_identity,
    :validate_generation_spn_provenance,
    :audit_paw_block_partitions,
    :generate_qe_paw_matrix_elements,
    :generate_qe_paw_spn,
    :generate_symmetry_completed_qe_paw_matrix_elements,
    :generate_vasp_paw_matrix_elements,
    :generate_vasp_paw_spn,
    :generate_wannier_uiu,
    :prepare_paw_scdm_input_artifact,
    :prepare_symmetry_covariant_wavefunctions,
    :read_paw_scdm_input_artifact,
    :read_qe_paw_spn_provenance,
    :read_vasp_paw_spn_provenance,
)

const PAW_MATRIX_ELEMENTS_TEST_API = ()

for name in PAW_MATRIX_ELEMENTS_INTEGRATION_API
    @eval export $name
end

end
