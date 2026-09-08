module RepresentationPreparation

import EzXML
import HDF5
import LinearAlgebra:
    Diagonal, Hermitian, I, det, diag, dot, eigvals, norm, opnorm, svd, svdvals, tr
import Random: MersenneTwister, randn
import SHA
import SHA: sha256
import WannierNLQG.Core: reciprocal_lattice
import WannierNLQG.IO:
    WannierAMN,
    WannierMMN,
    read_fortran_record,
    read_wannier_amn as read_wannier_amn_file,
    write_wannier_amn
import WannierNLQG.SymmetryFoundation:
    AbstractWavefunctionSource,
    BOHR_TO_ANGSTROM,
    BandRepresentation,
    CrystalStructure,
    HARTREE_TO_EV,
    NativeWavefunctionData,
    PlaneWaveKPoint,
    QuantumEspressoWavefunctionSource,
    SymmetryOperation,
    VASPWavefunctionSource,
    WannierSymmetryPlan,
    validate_unified_representation_mode_contract,
    build_canonical_band_representation,
    infer_mp_grid,
    is_identity_group_representation,
    plane_wave_energy_ev,
    read_vasp_wavefunctions,
    row_major_matrix,
    selected_band_range,
    sha256_file,
    spin_action_matrix
import WannierNLQG.WannierProjection:
    WannierProjectionBasis, projection_orbital_values, projection_radial_transform_contract
import WannierNLQG.Wannierization:
    AMNExactFrozenInitialization,
    AbstractBandSewingBackend,
    AugmentationAwareSewing,
    BandRepresentationPreparationConfig,
    CoefficientMappingSewing,
    ExternalWannier90Matrices,
    FarBandCovarianceCorrection,
    GATE_DEFINITION_INVALID,
    GATE_VALID,
    NativeDFTHamiltonian,
    NativeEigenstateGauge,
    NativeQEPAWMatrices,
    NativeVASPPAWMatrices,
    PAWGaugeThresholds,
    PAWSCDMInitialization,
    ProjectabilityDisentanglementInitialization,
    REPRESENTATION_COMPATIBLE,
    REPRESENTATION_INCOMPATIBLE_ASSESSMENT,
    RepresentationCompatibilityReport,
    RepresentationProductTable,
    StarCovariantPAWGauge,
    SymmetrizedDFTHamiltonian,
    SymmetryAdaptedWannierizationConfig,
    SymmetryCompletedQEPAWMatrices,
    SymmetryCovariantWavefunctionPreparationConfig,
    WannierGaugeLinkDiagnostics,
    WannierProjectorComparison,
    WannierizationDiagnostic,
    WannierizationFixedSubspace
import ..WannierizationInternalSupport:
    atomic_hdf5_write,
    band_sewing_backend_key,
    build_augmentation_aware_band_representation,
    empty_group_law_worst_cases,
    is_symmetrized_authority,
    projection_basis_sha256,
    target_representation,
    validate_smv_fletcher_reeves_two_stage_audit_thresholds,
    write_generation_environment,
    write_string_dictionary

include("../RepresentationDiagnostics.jl")
include("../RepresentationGroupLaw.jl")
include("../SewingMatrixAlignment.jl")
include("../AntiunitaryCompatibility.jl")
include("../WannierGaugeDiagnostics.jl")
include("../WannierizationConfigValidation.jl")
include("../QuantumEspressoWavefunctions.jl")
include("../QEUPFData.jl")
include("../BandRepresentationBuilder.jl")
include("../VASPPawData.jl")
include("../ConstraintOperationScopes.jl")
include("../NativeSourceDispatch.jl")

# Cross-component callers use these non-private integration bindings. The
# original underscored names remain local implementation and test hooks.
const antiunitary_projector_covariance_residual = _antiunitary_projector_covariance_residual
const build_band_representation = _build_band_representation
const build_qe_projector_plan = _build_qe_projector_plan
const build_representation_product_table = _build_representation_product_table
const compare_wannier_projectors = _compare_wannier_projectors
const configured_num_wannier = _configured_num_wannier
const constraint_scoped_fixed_subspace = _constraint_scoped_fixed_subspace
const constraint_scoped_representation = _constraint_scoped_representation
const effective_wannierization_algorithms = _effective_wannierization_algorithms
const effective_wannierization_mode = _effective_wannierization_mode
const generate_amn = _generate_amn
const group_law_combination_index = _group_law_combination_index
const paw_logarithmic_simpson = _paw_logarithmic_simpson
const paw_radial_q0 = _paw_radial_q0
const qe_metric_kind_label = _qe_metric_kind_label
const qe_wavefunction_file = _qe_wavefunction_file
const qe_xml_numbers = _qe_xml_numbers
const qe_xml_required = _qe_xml_required
const read_qe_raw_wavefunctions = _read_qe_raw_wavefunctions
const read_qe_upf_data = _read_qe_upf_data
const read_qe_wavefunction_header = _read_qe_wavefunction_header
const read_qe_wavefunction_kpoint = _read_qe_wavefunction_kpoint
const read_qe_wavefunctions = _read_qe_wavefunctions
const read_qe_xml = _read_qe_xml
const read_vasp_paw_system = _read_vasp_paw_system
const read_wannier_amn = _read_wannier_amn
const record_wannier_gauge_link_summary! = _record_wannier_gauge_link_summary!
const representation_diagnostic = _representation_diagnostic
const representation_diagnostics_for_policy = _representation_diagnostics_for_policy
const representation_source = _representation_source
const representation_static_sha256 = _representation_static_sha256
const symmetry_constraints_applied = _symmetry_constraints_applied
const validate_band_group_law = _validate_band_group_law
const validate_selected_kramers_ranks = _validate_selected_kramers_ranks
const validate_symmetry_covariant_wavefunction_preparation_config =
    _validate_symmetry_covariant_wavefunction_preparation_config
const validate_target_operation_inventory = _validate_target_operation_inventory
const validate_wannierization_config = _validate_wannierization_config
const wannier_gauge_link_diagnostics = _wannier_gauge_link_diagnostics

const REPRESENTATION_PREPARATION_INTEGRATION_API = (
    :QEProjectorAtomPlan,
    :QEProjectorChannel,
    :QEProjectorPlan,
    :QEUPFData,
    :VASPPawAtomLayout,
    :VASPPawChannel,
    :VASPPawDataset,
    :VASPPawSystem,
    :antiunitary_projector_covariance_residual,
    :build_band_representation,
    :build_qe_projector_plan,
    :build_representation_product_table,
    :compare_wannier_projectors,
    :configured_num_wannier,
    :constraint_scoped_fixed_subspace,
    :constraint_scoped_representation,
    :effective_wannierization_algorithms,
    :effective_wannierization_mode,
    :generate_amn,
    :group_law_combination_index,
    :paw_logarithmic_simpson,
    :paw_radial_q0,
    :qe_metric_kind_label,
    :qe_wavefunction_file,
    :qe_xml_numbers,
    :qe_xml_required,
    :read_qe_raw_wavefunctions,
    :read_qe_upf_data,
    :read_qe_wavefunction_header,
    :read_qe_wavefunction_kpoint,
    :read_qe_wavefunctions,
    :read_qe_xml,
    :read_vasp_paw_system,
    :read_wannier_amn,
    :record_wannier_gauge_link_summary!,
    :representation_diagnostic,
    :representation_diagnostics_for_policy,
    :representation_source,
    :representation_static_sha256,
    :symmetry_constraints_applied,
    :validate_band_group_law,
    :validate_selected_kramers_ranks,
    :validate_symmetry_covariant_wavefunction_preparation_config,
    :validate_target_operation_inventory,
    :validate_wannierization_config,
    :wannier_gauge_link_diagnostics,
    :generate_wannier_amn,
    :read_native_source,
    :validate_band_representation_compatibility,
)

const REPRESENTATION_PREPARATION_TEST_API = (
    :_block_alignment_unitary,
    :_build_representation_product_table,
    :_classify_wannier_gauge_chain_cause,
    :_common_degeneracy_blocks,
    :_compare_wannier_projectors,
    :_effective_wannierization_algorithms,
    :_effective_wannierization_mode,
    :_gauge_transform_sewing,
    :_group_law_combination_index,
    :_match_symmetry_operations,
    :_paired_matrix_residual_metrics,
    :_representation_static_sha256,
    :_stable_subspace_alignment,
    :_symmetry_constraints_applied,
    :_validate_band_representation_preparation_config,
    :_validate_symmetry_covariant_wavefunction_preparation_config,
    :_validate_target_operation_inventory,
    :_validate_wannierization_config,
    :_wannier_gauge_link_diagnostics,
)

for name in REPRESENTATION_PREPARATION_INTEGRATION_API
    @eval export $name
end

end
