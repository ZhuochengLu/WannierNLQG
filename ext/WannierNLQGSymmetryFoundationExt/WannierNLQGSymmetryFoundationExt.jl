module WannierNLQGSymmetryFoundationExt

using Dates
using HDF5
using LinearAlgebra
using Printf
using SHA
using Spglib
using WannierNLQG.Core
using WannierNLQG.IO
using WannierNLQG.SymmetryFoundation
import JSON3
import WannierNLQG
import WannierNLQG.SymmetryFoundation:
    DEFAULT_MAXIMUM_CARTESIAN_ROTATION_CORRECTION,
    EFFECTIVE_CARTESIAN_ROTATION_TOLERANCE,
    RAW_CARTESIAN_ORTHOGONALITY_WARNING_TOLERANCE,
    _band_preparation_metadata_digest,
    canonical_band_block_labels,
    canonical_band_operation_key,
    build_canonical_band_representation,
    group_invariant_cartesian_rotation_data,
    magnetic_point_group_catalog_entry,
    magnetic_point_group_catalog_provenance,
    qualification_mask_sha256,
    read_vasp_wavefunctions,
    resolve_cartesian_rotation_policy,
    resolve_spglib_symprec_angstrom,
    response_group_generators,
    spin_action_matrix,
    _validate_unified_representation_mode_contract

include("SymmetryOperationDetection.jl")
include("ResponseSymmetryGroupClassification.jl")
include("TBSymmetryDetectionCompatibility.jl")
include("VASPBandRepresentationBuilder.jl")
include("BandRepresentationPersistence.jl")

export detect_symmetry_operations, detect_magnetic_symmetry_inventory
export detect_tb_compatibility_symmetry_operations, symmetry_detection_backend_provenance
export response_symmetry_group_report
export generate_vasp_band_representation
export read_band_representation_hdf5, write_band_representation_hdf5
export band_representation_schema_version

end
