module IO

using LinearAlgebra
using Mmap
using Printf
using SHA
using Serialization
using TOML
using ..Core
import ..Core: native_physical_dimension

include("ScientificSourceFiles.jl")
include("ScientificInputDefinitions.jl")
include("ScientificInputReferences.jl")
export scientific_file_state, scientific_file_identity, read_scientific_source
export validate_scientific_source_state
export with_scientific_source,
    observe_scientific_source, scientific_file_record, validate_scientific_file_record
include("TaskInputFiles.jl")
include("NativeGeometryMetadata.jl")
include("WannierMeshFiles.jl")
export read_vasp_kpoint_mesh, read_vasp_xml_mesh, read_qe_input_mesh
export read_qe_geometry_metadata, read_qe_mesh_declaration
include("VASPGeometryMetadata.jl")
export read_vasp_geometry_metadata
include("ScientificCheckpointPublication.jl")
include("PhotonMomentumPathRecords.jl")
include("PhotonMomentumTables.jl")
export read_photon_momentum_table
export read_task_input_file, write_task_input_file, write_task_input_text, task_input_toml_value
export write_task_input_json

include("VerifiedFileDigests.jl")
export sha256_file, verified_file_digest_identity, with_verified_file_digests, file_digest_identity

include("OpenMXLocalizedInput.jl")
export read_openmx_localized_input

include("PreparationStorage.jl")
export publish_preparation_shared_array, read_preparation_shared_array
include("WannierTB.jl")
include("ScientificSourceDefinitions.jl")
export scientific_source_definition_stream, operator_component_reference
include("WannierTBWriter.jl")
include("WannierWSVEC.jl")
include("WannierHR.jl")
include("WannierAMN.jl")
include("WannierNNKP.jl")
include("RealSpaceOperatorBundles.jl")
include("SpinReaders.jl")
include("WannierUIU.jl")
include("WannierHamiltonianOperatorFiles.jl")
include("SpinVelocityReaders.jl")
include("WannierMMNWriter.jl")
include("ResultWriters.jl")
include("SecondHarmonicWriters.jl")
include("ThirdOrderWriters.jl")
include("SpectralResponseWriters.jl")
export write_spectral_response_table, write_spectral_response_metadata, spectral_task_definition
export release_tree_sha256, read_linear_transport_result, read_orbital_magnetization_result
include("BandStructureWriters.jl")
include("ResponseSymmetryArtifacts.jl")

export WannierSPN, WannierCHK, WannierEIG, WannierMMN, WannierMMNTopology, WannierAMN
export WannierNNKP, read_wannier_nnkp, owned_wannier_topology
export WannierHR
export read_fortran_record
export WannierUIUHeader, read_wannier_uiu_header, foreach_wannier_uiu_block, write_wannier_uiu
export WannierUHUHeader, WannierSHUHeader, WannierSIUHeader
export read_wannier_uhu_header, read_wannier_shu_header, read_wannier_siu_header
export foreach_wannier_uhu_block, foreach_wannier_shu_block, foreach_wannier_siu_block
export write_wannier_uhu, write_wannier_shu, write_wannier_siu
export read_wannier_tb, read_wannier_tb_num_orbitals, write_wannier_tb
export WannierWSVEC, read_wannier_wsvec
export read_wannier_spn, write_wannier_spn
export read_wannier_chk
export read_wannier_hr, write_wannier_hr
export read_wannier_eig, write_wannier_eig
export read_wannier_mmn, read_wannier_mmn_topology, write_wannier_mmn
export read_wannier_amn, write_wannier_amn
export foreach_wannier_mmn_block
export validate_packed_paired_tb, adopt_real_space_operator_bundle
export OPERATOR_BUNDLE_SCHEMA, OPERATOR_BUNDLE_SCHEMA_VERSION
export FULL_DERIVATIVE_OVERLAP_ALGORITHM_VERSION
export OPERATOR_PROFILE_INVENTORIES, OperatorBundleIndexEntry, OperatorBundleManifest
export PackedCartesianOperator
export operator_storage_name, operator_kind_from_storage_name
export canonical_operator_inventory, infer_operator_profile, validate_operator_profile
export available_matrix_capabilities
export OPERATOR_SELECTION_PROFILES, OperatorSelection
export operator_selection_mode, resolved_operator_profile, resolved_operator_inventory
export resolved_source_inventory, resolved_task_closure
export operator_selection_registry_version, operator_selection_sha256
export operator_inventory_source_closure, operator_task_token, operator_task_from_token
export operator_tasks_from_tokens
export resolve_operator_selection, validate_task_derived_operator_selection
export write_real_space_operator_bundle, read_real_space_operator_bundle
export read_real_space_operator_bundle_manifest, read_operator_bundle_payload
export read_operator_bundle_components
export write_integration_diagnostics
export write_third_order
export write_second_harmonic
export write_response_tensor, write_kslice, kslice_output_size
include("BerryMultipoleResultWriters.jl")
export write_berry_multipole_dc, write_berry_multipole_kslice
export write_band_structure
export RESPONSE_SYMMETRY_SCHEMA, ResponseSymmetryArtifact, ResponseSymmetryOperation
export read_response_symmetry_artifact

include("NativeModelProvenance.jl")
include("NativeResponseSymmetry.jl")
include("NativeDerivativeRecords.jl")
export write_native_derivative_records
export NativeResponseSymmetryArtifact,
    read_native_response_symmetry,
    write_native_symmetry_artifact,
    NATIVE_RESPONSE_SYMMETRY_SCHEMA,
    validate_native_response_symmetry_source,
    validate_native_response_symmetry_model
export native_source_file_identity, native_parameters_metadata
export write_native_model_definition, native_model_definition_stream, write_native_definition_value
export scientific_definition_stream
export write_scientific_file_publication, with_scientific_file_publication
export with_scientific_publication_receipts

end
