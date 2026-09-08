const MAGNETIC_POINT_GROUP_CATALOG_PROVENANCE = (
    catalog = "Spglib-generated magnetic point-group records",
    generation_contract = MAGNETIC_POINT_GROUP_GENERATION_CONTRACT,
    operation_digest_contract = MAGNETIC_POINT_GROUP_OPERATION_DIGEST_CONTRACT,
    symbol_convention = MAGNETIC_POINT_GROUP_SYMBOL_CONVENTION,
    spglib_jl_version = "1.2.0",
    spglib_jl_commit = "d7666d94b95da444eb0e0d1d980cf6b45381893a",
    spglib_jl_git_tree_sha1 = "8f1b4a9e4d3d4ce9670c09355ce402ec5418b8e6",
    spglib_jll_version = "2.7.0+0",
    spglib_jll_commit = "41936ad9b44ba55aa1800b27660e8effdafc6996",
    spglib_jll_git_tree_sha1 = "2a960ec298d1932df7c9fe8fad2923d548e973d1",
    spglib_c_version = "2.7.0",
    spglib_c_commit = "12355c77fb7c505a55f52cae36341d73b781a065",
    spglib_artifact_tree = "1366d8dabbf6499f8c606426215fbd46ac2cb18a",
    generator_sha256 = MAGNETIC_POINT_GROUP_GENERATOR_SHA256,
    specification_sha256 = MAGNETIC_POINT_GROUP_SPECIFICATION_SHA256,
    display_catalog_sha256 = MAGNETIC_POINT_GROUP_DISPLAY_CATALOG_SHA256,
)

"""Return Spglib-only catalog provenance after validating its generated identity arrays."""
function magnetic_point_group_catalog_provenance()
    length(MAGNETIC_POINT_GROUP_SYMBOLS) == 122 ||
        error("magnetic point-group catalog does not contain exactly 122 display symbols")
    length(MAGNETIC_POINT_GROUP_OPERATION_DIGESTS) == 122 ||
        error("magnetic point-group catalog does not contain exactly 122 operation digests")
    length(Set(MAGNETIC_POINT_GROUP_OPERATION_DIGESTS)) == 122 ||
        error("magnetic point-group catalog contains an operation-digest collision")
    length(UNI_TO_MAGNETIC_POINT_GROUP_INDEX) == 1651 ||
        error("magnetic point-group catalog does not cover all 1651 UNI numbers")
    length(UNI_TO_MAGNETIC_SPACE_GROUP_TYPE) == 1651 ||
        error("magnetic point-group catalog lacks complete MSG type provenance")
    length(UNI_TO_MAGNETIC_POINT_GROUP_BASIS_NUMERATORS) == 1651 ||
        error("magnetic point-group catalog lacks complete basis transforms")
    length(UNI_TO_MAGNETIC_POINT_GROUP_BASIS_DENOMINATORS) == 1651 ||
        error("magnetic point-group catalog lacks complete basis denominators")
    Set(Int.(UNI_TO_MAGNETIC_POINT_GROUP_INDEX)) == Set(1:122) ||
        error("magnetic point-group catalog does not cover all 122 operation classes")
    all(type -> 1 <= type <= 4, UNI_TO_MAGNETIC_SPACE_GROUP_TYPE) ||
        error("magnetic point-group catalog contains an invalid MSG type")
    all(denominator -> denominator > 0, UNI_TO_MAGNETIC_POINT_GROUP_BASIS_DENOMINATORS) ||
        error("magnetic point-group catalog contains a nonpositive basis denominator")
    return MAGNETIC_POINT_GROUP_CATALOG_PROVENANCE
end

"""Return the Spglib-generated magnetic point-group identity for one UNI number."""
function magnetic_point_group_catalog_entry(uni_number::Integer)
    provenance = magnetic_point_group_catalog_provenance()
    1 <= uni_number <= 1651 ||
        throw(ArgumentError("UNI number $(uni_number) is outside the Spglib catalog"))
    uni = Int(uni_number)
    class_number = Int(UNI_TO_MAGNETIC_POINT_GROUP_INDEX[uni])
    basis_values = UNI_TO_MAGNETIC_POINT_GROUP_BASIS_NUMERATORS[uni]
    basis_rows = [[basis_values[3 * (row - 1) + column] for column in 1:3] for row in 1:3]
    return (
        uni_number = uni,
        msg_type = Int(UNI_TO_MAGNETIC_SPACE_GROUP_TYPE[uni]),
        magnetic_point_group_number = class_number,
        operation_digest = MAGNETIC_POINT_GROUP_OPERATION_DIGESTS[class_number],
        operation_digest_contract = MAGNETIC_POINT_GROUP_OPERATION_DIGEST_CONTRACT,
        hermann_mauguin = MAGNETIC_POINT_GROUP_SYMBOLS[class_number],
        symbol_convention = MAGNETIC_POINT_GROUP_SYMBOL_CONVENTION,
        equivalent_axis_notation = MAGNETIC_POINT_GROUP_EQUIVALENT_AXIS_NOTATION[class_number],
        basis_transform_to_input = (
            definition = MAGNETIC_POINT_GROUP_BASIS_DEFINITION,
            shape = [3, 3],
            numerator_rows = basis_rows,
            denominator = UNI_TO_MAGNETIC_POINT_GROUP_BASIS_DENOMINATORS[uni],
        ),
        display_catalog_sha256 = provenance.display_catalog_sha256,
    )
end
