module WannierNLQGSymmetrizationExt

import Dates
import Dates: @dateformat_str
import EzXML
import HDF5
import JSON3
import LinearAlgebra: Diagonal, Hermitian, I, det, dot, eigvals, norm, opnorm, rank, svdvals
import SHA
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
    real_space_cartesian_to_fractional
import WannierNLQG.IO:
    OPERATOR_PROFILE_INVENTORIES,
    WannierCHK,
    WannierEIG,
    WannierHR,
    WannierMMN,
    operator_storage_name,
    read_real_space_operator_bundle,
    read_response_symmetry_artifact,
    read_wannier_amn,
    read_wannier_chk,
    read_wannier_eig,
    read_wannier_hr,
    read_wannier_mmn,
    read_wannier_spn,
    read_wannier_tb,
    validate_operator_profile,
    write_real_space_operator_bundle,
    write_wannier_hr,
    write_wannier_tb
import WannierNLQG.MatrixElements:
    PairWignerSeitzSpinQToRTransform,
    RealSpaceReplicaPolicyResult,
    WANNIER_DERIVATIVE_OPERATOR_KINDS,
    WannierPairWignerSeitzTransformPlan,
    apply_real_space_replica_policy,
    compute_spin_velocity_real_space_streaming_with_transform,
    compute_spin_velocity_real_space_with_transform,
    construct_wannier_derivative_operators,
    mp_residue_grid,
    nearest_wigner_seitz_images,
    real_space_link_length_summary,
    spn_to_wannier_gauge_q,
    transform_pair_wigner_seitz_spin_q_to_r,
    unit_degeneracy_roundtrip_error,
    wannier_centers_fractional,
    wannier_q_to_pair_wigner_seitz
import WannierNLQG.SymmetryFoundation:
    BOHR_TO_ANGSTROM,
    BandRepresentation,
    CrystalStructure,
    DEFAULT_MAXIMUM_CARTESIAN_ROTATION_CORRECTION,
    EFFECTIVE_CARTESIAN_ROTATION_TOLERANCE,
    MagneticSymmetryInventory,
    RealSpaceProjectionContext,
    RealSpaceSymmetrizationResult,
    SymmetryOperation,
    WannierSymmetryPlan,
    build_band_product_table,
    canonical_band_operation_key,
    configure_band_qualification_window!,
    detect_magnetic_symmetry_inventory,
    detect_tb_compatibility_symmetry_operations,
    group_invariant_cartesian_rotation_data,
    maximum_real_space_covariance_error,
    r_vector_key,
    read_band_representation_hdf5,
    read_poscar_structure,
    resolve_cartesian_rotation_policy,
    resolve_spglib_symprec_angstrom,
    symmetrize_real_space_operator,
    symmetry_detection_backend_provenance,
    validate_band_representation,
    write_band_representation_hdf5,
    write_band_representation_summary
import WannierNLQG.Symmetrization:
    FAILED_BAND_REPRESENTATION,
    FAILED_INPUT_PROVENANCE,
    FAILED_INPUT_SUBSPACE_NOT_CLOSED,
    FAILED_PHYSICAL_BAND_PRESERVATION,
    FAILED_POSITION_VALIDATION,
    GaugeAwareSymmetrizationConfig,
    GaugeAwareSymmetrizationResult,
    GaugeAwareSymmetrizationStatus,
    GaugeAwareSymmetrizationThresholds,
    GaugeAwareThresholdEvent,
    HOLD_POSITION_PENDING,
    MagneticMomentConfig,
    MeshScreenConfig,
    OperatorValidationSummary,
    PASS,
    PASS_WITH_WARNINGS,
    SymmetrizationConfig,
    SymmetrizationResult
import WannierNLQG.WannierProjection:
    WannierProjectionBasis,
    WannierWinData,
    build_wannier_projection_basis,
    build_wannier_symmetry_plan,
    crystal_structure,
    parse_input_boolean,
    parse_wannier_float,
    read_wannier_win,
    strip_input_comment

include("components/ValidationComponent.jl")
include("components/SewingComponent.jl")
include("components/ProjectionComponent.jl")
include("components/PersistenceComponent.jl")
include("components/WorkflowComponent.jl")

export screen_wannier_mesh, symmetrize_wannier_operators
export write_response_symmetry_artifact, qualify_response_symmetry_wannier90
export symmetrize_existing_wannier_model

end
