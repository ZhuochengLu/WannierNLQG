#!/usr/bin/env julia

using JSON3
using SHA
using WannierNLQG
import WannierNLQG.SymmetryFoundation:
    magnetic_point_group_catalog_entry, magnetic_point_group_catalog_provenance

const ROOT = normpath(joinpath(@__DIR__, ".."))
const EXPECTED_RESPONSE_SYMMETRY_CATALOG = (
    generated_source_sha256 = "2d2f30a33e3b85b42840c2c14e6509577ebba99c94dd438b935d7331c32ad7d6",
    display_catalog_sha256 = "4ac72113a12da0557105b3d0689d30e623c3ce6b0bcba52dc2c1cb355946290e",
    operation_digest_contract = "wanniernlqg.magnetic-point-group-operations/1.0",
    symbol_convention = "wanniernlqg.spglib-canonical/1.0",
    generation_contract = "wanniernlqg.spglib-magnetic-point-group-catalog/1.0",
    generator_sha256 = "4fb2133cbbbf9bab2cc5e961abe5b68a149bcf28a50f9184c23f9e1a14ac6821",
    canonicalization_sha256 = "4570b2df131e7983d6c44a78e825edafd26d4298d1ac42b150cf5fd839d1a336",
    specification_sha256 = "01bd5b3882d0cf965c8000563208206c238a723288bc1591d9874af9eead62a4",
    spglib_jl_tree = "8f1b4a9e4d3d4ce9670c09355ce402ec5418b8e6",
    spglib_jll_tree = "2a960ec298d1932df7c9fe8fad2923d548e973d1",
    spglib_c_version = "2.7.0",
    spglib_artifact_variants = [
        (
            platform = "aarch64-apple-darwin",
            artifact_tree = "1366d8dabbf6499f8c606426215fbd46ac2cb18a",
            archive_sha256 = "17114aff9114b8d2e32ff213772caade1b7d7b7936b77e7996ecd05c6b0cd73b",
            library_sha256 = "2a332bace4e3ac377d15a505348451bbbbf363e7fe7bfedf6f840172ecf6c0f7",
        ),
        (
            platform = "x86_64-linux-gnu",
            artifact_tree = "ceefa619e483d9651436478e4956ba71abc49fc8",
            archive_sha256 = "ba908668d97c410a6d53cf20c129a0fdcff7814dfc0177e129fefc8eec869aae",
            library_sha256 = "f92c825ed7042fe947dde71187bcd24f6cebd185baa454e345bd1361f244cfa0",
        ),
    ],
    locked_spglib_sha256 = "3e06126b0a3608c18c6d321d408b6f0cdd3673e68c4c9dabb033c9d8b43aaab3",
    forbidden_inputs_sha256 = "031406ff73867de9f086fdd3e2cb82a3d252e5c3e9b8750743b772f499ddf4a3",
    uni_count = 1651,
    magnetic_point_group_count = 122,
)

"""Return the lowercase SHA-256 digest of one release file."""
_catalog_file_sha256(path) = bytes2hex(open(sha256, path))

"""Assert exact equality with one contextual catalog diagnostic."""
function _catalog_equal(label, actual, expected)
    actual == expected ||
        error("response-symmetry catalog $(label) mismatch: expected=$(expected), actual=$(actual)")
    return actual
end

"""Fail if the active clean-room input closure mentions a forbidden external source path."""
function _catalog_check_input_closure()
    generator_path = joinpath(ROOT, "scripts", "generate_response_symmetry_catalog.jl")
    generated_path =
        joinpath(ROOT, "src", "SymmetryFoundation", "GeneratedMagneticPointGroupCatalog.jl")
    runtime_catalog_path =
        joinpath(ROOT, "src", "SymmetryFoundation", "ResponseSymmetryGroupReporting.jl")
    generator = read(generator_path, String)
    for forbidden in (
        "magnetic_data.txt",
        "mpg_dicts.py",
        "Downloads.",
        "HTTP.",
        "Sockets.",
        "curl ",
        "https://",
        "http://",
        "historical/",
        "backup/",
    )
        occursin(forbidden, generator) &&
            error("catalog generator contains forbidden external input/network token $(forbidden)")
    end
    active_source = read(generated_path, String) * read(runtime_catalog_path, String)
    for forbidden in (
        "ISO-MAG",
        "PythMPG",
        "Litvin 3D magnetic point groups",
        "2b11217ae10687b0836d8151846db2fad57b0d77211da90bb138ccd123a7b1fc",
        "78d322cf106949614370f7c3ab66cbf77fff0aa296a10e1a192732db82a12e22",
        "3c19f07f3465ef5d975ff47cb1bb39e37533dcdaae5c3c6555b0bc37b6e9ad41",
    )
        occursin(forbidden, active_source) &&
            error("active catalog/runtime source contains legacy lookup token $(forbidden)")
    end
    occursin(r"(?<!display_)catalog_sha256", active_source) &&
        error("active catalog/runtime source retains the removed catalog_sha256 identity")
    return true
end

"""Validate the deterministic generation receipt and its local file hashes."""
function _catalog_check_receipt(expected)
    receipt_path = joinpath(ROOT, "catalog-generation-receipt.json")
    receipt = JSON3.read(read(receipt_path, String))
    _catalog_equal(
        "receipt schema",
        String(receipt.schema),
        "wanniernlqg.catalog-generation-receipt/1.0",
    )
    _catalog_equal("receipt status", String(receipt.status), "PASS")
    _catalog_equal(
        "generation contract",
        String(receipt.generation_contract),
        expected.generation_contract,
    )
    _catalog_equal(
        "operation digest contract",
        String(receipt.operation_digest_contract),
        expected.operation_digest_contract,
    )
    _catalog_equal(
        "symbol convention",
        String(receipt.symbol_convention),
        expected.symbol_convention,
    )
    receipt.network_required === false || error("catalog generation receipt permits network access")
    _catalog_equal(
        "forbidden-input closure",
        bytes2hex(sha256(JSON3.write(receipt.forbidden_inputs))),
        expected.forbidden_inputs_sha256,
    )
    _catalog_equal(
        "locked Spglib identity",
        bytes2hex(sha256(JSON3.write(receipt.locked_spglib))),
        expected.locked_spglib_sha256,
    )
    _catalog_equal("receipt UNI coverage", Int(receipt.validation.uni_coverage), expected.uni_count)
    _catalog_equal(
        "receipt class coverage",
        Int(receipt.validation.magnetic_point_group_classes),
        expected.magnetic_point_group_count,
    )
    _catalog_equal("receipt digest conflicts", Int(receipt.validation.digest_conflicts), 0)
    _catalog_equal(
        "receipt coordinate basis cases",
        Int(receipt.validation.coordinate_basis_cases_checked),
        599,
    )
    _catalog_equal(
        "Spglib.jl tree",
        String(receipt.locked_spglib.spglib_jl.git_tree_sha1),
        expected.spglib_jl_tree,
    )
    _catalog_equal(
        "spglib_jll tree",
        String(receipt.locked_spglib.spglib_jll.git_tree_sha1),
        expected.spglib_jll_tree,
    )
    _catalog_equal(
        "Spglib C version",
        String(receipt.locked_spglib.spglib_c.version),
        expected.spglib_c_version,
    )
    artifact_variants = [
        (
            platform = String(variant.platform),
            artifact_tree = String(variant.artifact_tree),
            archive_sha256 = String(variant.archive_sha256),
            library_sha256 = String(variant.library_sha256),
        ) for variant in receipt.locked_spglib.spglib_c.verified_generation_artifacts
    ]
    _catalog_equal(
        "Spglib verified generation artifacts",
        artifact_variants,
        expected.spglib_artifact_variants,
    )
    _catalog_equal(
        "generator SHA-256",
        String(receipt.inputs.generator_sha256),
        expected.generator_sha256,
    )
    _catalog_equal(
        "canonicalization SHA-256",
        String(receipt.inputs.canonicalization_sha256),
        expected.canonicalization_sha256,
    )
    _catalog_equal(
        "specification SHA-256",
        String(receipt.inputs.specification_sha256),
        expected.specification_sha256,
    )
    _catalog_equal(
        "generated source SHA-256",
        String(receipt.outputs.generated_source_sha256),
        expected.generated_source_sha256,
    )
    _catalog_equal(
        "display catalog SHA-256",
        String(receipt.outputs.display_catalog_sha256),
        expected.display_catalog_sha256,
    )
    paths = (
        generator = joinpath(ROOT, "scripts", "generate_response_symmetry_catalog.jl"),
        canonicalization = joinpath(
            ROOT,
            "src",
            "SymmetryFoundation",
            "MagneticPointGroupCanonicalization.jl",
        ),
        specification = joinpath(ROOT, "docs", "MAGNETIC_POINT_GROUP_CONVENTION.md"),
        generated = joinpath(
            ROOT,
            "src",
            "SymmetryFoundation",
            "GeneratedMagneticPointGroupCatalog.jl",
        ),
    )
    _catalog_equal(
        "generator file SHA-256",
        _catalog_file_sha256(paths.generator),
        expected.generator_sha256,
    )
    _catalog_equal(
        "canonicalization file SHA-256",
        _catalog_file_sha256(paths.canonicalization),
        expected.canonicalization_sha256,
    )
    _catalog_equal(
        "specification file SHA-256",
        _catalog_file_sha256(paths.specification),
        expected.specification_sha256,
    )
    _catalog_equal(
        "generated source file SHA-256",
        _catalog_file_sha256(paths.generated),
        expected.generated_source_sha256,
    )
    return receipt
end

"""Run the generator in a fresh Julia process and require byte-exact replay."""
function _catalog_check_fresh_replay()
    command =
        `$(Base.julia_cmd()) --startup-file=no --project=$(ROOT) $(joinpath(ROOT, "scripts", "generate_response_symmetry_catalog.jl")) --check`
    success(pipeline(command; stdout = devnull, stderr = stderr)) ||
        error("fresh-process Spglib catalog replay failed")
    return true
end

"""Require the generator's altered and missing artifact identities to fail closed."""
function _catalog_check_spglib_identity_negative_tests()
    command =
        `$(Base.julia_cmd()) --startup-file=no --project=$(ROOT) $(joinpath(ROOT, "scripts", "generate_response_symmetry_catalog.jl")) --identity-self-test`
    success(pipeline(command; stdout = devnull, stderr = stderr)) ||
        error("Spglib artifact identity negative tests failed")
    return true
end

"""Verify the Spglib-only 1651-to-122 response-symmetry identity catalog."""
function check_response_symmetry_catalog(;
    expected = EXPECTED_RESPONSE_SYMMETRY_CATALOG,
    replay::Bool = true,
)
    provenance = magnetic_point_group_catalog_provenance()
    _catalog_equal(
        "display catalog SHA-256",
        provenance.display_catalog_sha256,
        expected.display_catalog_sha256,
    )
    _catalog_equal(
        "operation digest contract",
        provenance.operation_digest_contract,
        expected.operation_digest_contract,
    )
    _catalog_equal("symbol convention", provenance.symbol_convention, expected.symbol_convention)
    _catalog_equal(
        "generation contract",
        provenance.generation_contract,
        expected.generation_contract,
    )

    entries = [magnetic_point_group_catalog_entry(uni) for uni in 1:expected.uni_count]
    _catalog_equal("UNI coverage", length(entries), expected.uni_count)
    class_numbers = Set(entry.magnetic_point_group_number for entry in entries)
    _catalog_equal(
        "magnetic point-group coverage",
        class_numbers,
        Set(1:expected.magnetic_point_group_count),
    )
    class_to_digest = Dict{Int, String}()
    digest_to_class = Dict{String, Int}()
    for entry in entries
        get!(class_to_digest, entry.magnetic_point_group_number, entry.operation_digest) ==
        entry.operation_digest || error("one class number maps to multiple operation digests")
        get!(digest_to_class, entry.operation_digest, entry.magnetic_point_group_number) ==
        entry.magnetic_point_group_number ||
            error("one operation digest maps to multiple class numbers")
        entry.operation_digest_contract == expected.operation_digest_contract ||
            error("catalog entry operation-digest contract mismatch")
        entry.symbol_convention == expected.symbol_convention ||
            error("catalog entry display convention mismatch")
        entry.basis_transform_to_input.denominator > 0 ||
            error("catalog entry basis denominator is not positive")
    end
    _catalog_equal("operation digest coverage", length(digest_to_class), 122)

    vectors = Dict(
        1 => (1, "1", 1),
        2 => (2, "1'", 2),
        3 => (2, "1'", 4),
        6 => (5, "-1'", 3),
        101 => (19, "2'22'", 3),
        1651 => (122, "m'-3'm'", 3),
    )
    for (uni, (class_number, symbol, msg_type)) in vectors
        entry = entries[uni]
        _catalog_equal("UNI $(uni) class", entry.magnetic_point_group_number, class_number)
        _catalog_equal("UNI $(uni) display", entry.hermann_mauguin, symbol)
        _catalog_equal("UNI $(uni) MSG type", entry.msg_type, msg_type)
    end
    display_migration =
        Dict(19 => "2'22'", 89 => "6'2'2", 93 => "6'm'm", 103 => "6'/mm'm", 104 => "6'/m'm'm")
    for (class_number, symbol) in display_migration
        representatives =
            filter(entry -> entry.magnetic_point_group_number == class_number, entries)
        !isempty(representatives) || error("display migration class $(class_number) is absent")
        all(entry -> entry.hermann_mauguin == symbol, representatives) ||
            error("display migration class $(class_number) is not deterministic")
        all(entry -> entry.equivalent_axis_notation, representatives) ||
            error("display migration class $(class_number) lacks equivalent-axis provenance")
    end
    count(entry -> haskey(display_migration, entry.magnetic_point_group_number), entries) == 49 ||
        error("display migration classes do not cover exactly 49 UNI records")
    try
        magnetic_point_group_catalog_entry(0)
        error("response-symmetry catalog accepted UNI 0")
    catch exception
        exception isa ArgumentError || rethrow()
    end
    try
        magnetic_point_group_catalog_entry(expected.uni_count + 1)
        error("response-symmetry catalog accepted UNI $(expected.uni_count + 1)")
    catch exception
        exception isa ArgumentError || rethrow()
    end

    _catalog_check_input_closure()
    _catalog_check_receipt(expected)
    if replay
        _catalog_check_spglib_identity_negative_tests()
        _catalog_check_fresh_replay()
    end
    return (
        display_catalog_sha256 = provenance.display_catalog_sha256,
        uni_count = length(entries),
        magnetic_point_group_count = length(class_numbers),
        operation_digest_count = length(digest_to_class),
        replayed = replay,
    )
end

function main()
    result = check_response_symmetry_catalog()
    println(
        "response-symmetry catalog passed uni_count=$(result.uni_count) " *
        "magnetic_point_group_count=$(result.magnetic_point_group_count) " *
        "operation_digest_count=$(result.operation_digest_count) " *
        "display_catalog_sha256=$(result.display_catalog_sha256)",
    )
    return nothing
end

abspath(PROGRAM_FILE) == abspath(@__FILE__) && main()
