#!/usr/bin/env julia

using JSON3
using LinearAlgebra
using SHA
using Spglib
using TOML

const ROOT = normpath(joinpath(@__DIR__, ".."))
const CANONICALIZATION_SOURCE =
    joinpath(ROOT, "src", "SymmetryFoundation", "MagneticPointGroupCanonicalization.jl")
const GENERATED_SOURCE =
    joinpath(ROOT, "src", "SymmetryFoundation", "GeneratedMagneticPointGroupCatalog.jl")
const SPECIFICATION = joinpath(ROOT, "docs", "MAGNETIC_POINT_GROUP_CONVENTION.md")
const RECEIPT = joinpath(ROOT, "catalog-generation-receipt.json")

include(CANONICALIZATION_SOURCE)

const GENERATION_CONTRACT = "wanniernlqg.spglib-magnetic-point-group-catalog/1.0"
const RECEIPT_SCHEMA = "wanniernlqg.catalog-generation-receipt/1.0"
const EXPECTED_SPGLIB = (
    julia_version = v"1.2.0",
    julia_commit = "d7666d94b95da444eb0e0d1d980cf6b45381893a",
    julia_tree = "8f1b4a9e4d3d4ce9670c09355ce402ec5418b8e6",
    julia_license_sha256 = "d495fa3541792178d81ed5532e083a3e4e6ec1bb45ec4a3e1d14974c5c00c6db",
    jll_version = v"2.7.0+0",
    jll_commit = "41936ad9b44ba55aa1800b27660e8effdafc6996",
    jll_tree = "2a960ec298d1932df7c9fe8fad2923d548e973d1",
    jll_license_sha256 = "70359aa3bc81c2c882a4a6b473a2110e3638bbb2c05b285dc4c8c1a7d57ed90c",
    c_version = v"2.7.0",
    c_commit = "12355c77fb7c505a55f52cae36341d73b781a065",
    artifact_variants = (
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
    ),
    c_license_sha256 = "9c4e602ce15bf48206dad105b666ddaeedba747eeda6465807106bc11f4f587f",
    msg_database_c_sha256 = "b313ad5c89f0cf16da3d6c9418f6024b75e2df59d0b2c8c9fda69f1253b6683e",
    msg_database_h_sha256 = "9e75aa82e2f33ebe5f7e8a1d13ddb2af4b534741b9f9953d00e4ab3bf277fffa",
    magnetic_hall_symbols_sha256 = "6e3d7e2de1540c20a3ef13ad3554fac3e68e399c10c435e2feb86c933229d088",
    msg_numbers_sha256 = "7f1c92556be68f20999971a6c18631ba460c367f3b2d0e2f892643e811d0f539",
    make_mhall_db_sha256 = "50f659a884b70d8068674fd6a93dc824684ba212670e90fdb747c741bd70037f",
    make_msgtype_db_sha256 = "8c6a467c8671dad68a2328b3e61743f232efd0c9ac1bf4be50ee2c45db030551",
)

"""Return the lowercase SHA-256 of one local file."""
_generation_sha256(path) = bytes2hex(open(sha256, path))

"""Find a named package record in the locked Manifest without invoking Pkg."""
function _generation_manifest_package(name)
    manifest = TOML.parsefile(joinpath(ROOT, "Manifest.toml"))
    records = get(manifest["deps"], name, nothing)
    records isa AbstractVector && length(records) == 1 ||
        error("Manifest must contain exactly one $(name) record")
    return only(records)
end

"""Return the exact release-generation platform identity supported by this receipt."""
function _generation_platform_key()
    Sys.isapple() && Sys.ARCH == :aarch64 && return "aarch64-apple-darwin"
    Sys.islinux() && Sys.ARCH == :x86_64 && return "x86_64-linux-gnu"
    error("unsupported Spglib catalog-generation platform: $(Sys.MACHINE)")
end

"""Select exactly one pinned binary artifact for the active generation platform."""
function _generation_artifact_variant(expected)
    platform = _generation_platform_key()
    variants = filter(variant -> variant.platform == platform, expected.artifact_variants)
    length(variants) == 1 ||
        error("Spglib artifact allowlist must contain exactly one entry for $(platform)")
    return only(variants)
end

"""Return the loaded package root for a module without recording Pkg usage."""
_generation_package_root(module_value) = normpath(joinpath(dirname(pathof(module_value)), ".."))

"""Resolve the already-loaded spglib_jll module used by Spglib.jl."""
function _generation_spglib_jll()
    package_id = Base.PkgId(Base.UUID("ac4a9f1e-bdb2-5204-990c-47c8b2f70d4e"), "spglib_jll")
    haskey(Base.loaded_modules, package_id) || error("Spglib did not load spglib_jll")
    return Base.loaded_modules[package_id]
end

"""Fail closed unless the locally loaded Spglib dependency closure matches the release pins."""
function verify_spglib_identity(; expected = EXPECTED_SPGLIB)
    Base.pkgversion(Spglib) == expected.julia_version || error("Spglib.jl version mismatch")
    Spglib.get_version() == expected.c_version || error("Spglib C version mismatch")
    spglib_record = _generation_manifest_package("Spglib")
    string(spglib_record["version"]) == string(expected.julia_version) ||
        error("Manifest Spglib.jl version mismatch")
    string(spglib_record["git-tree-sha1"]) == expected.julia_tree ||
        error("Manifest Spglib.jl tree mismatch")
    jll_record = _generation_manifest_package("spglib_jll")
    string(jll_record["version"]) == string(expected.jll_version) ||
        error("Manifest spglib_jll version mismatch")
    string(jll_record["git-tree-sha1"]) == expected.jll_tree ||
        error("Manifest spglib_jll tree mismatch")

    spglib_license = joinpath(_generation_package_root(Spglib), "LICENSE")
    _generation_sha256(spglib_license) == expected.julia_license_sha256 ||
        error("Spglib.jl license digest mismatch")
    jll_module = _generation_spglib_jll()
    jll_license = joinpath(_generation_package_root(jll_module), "LICENSE")
    _generation_sha256(jll_license) == expected.jll_license_sha256 ||
        error("spglib_jll license digest mismatch")
    artifact_variant = _generation_artifact_variant(expected)
    library_path = realpath(Spglib.libsymspg)
    artifact_root = dirname(dirname(library_path))
    basename(artifact_root) == artifact_variant.artifact_tree ||
        error("Spglib artifact tree mismatch for $(artifact_variant.platform)")
    _generation_sha256(library_path) == artifact_variant.library_sha256 ||
        error("Spglib shared-library digest mismatch")
    c_license = joinpath(artifact_root, "share", "licenses", "spglib", "COPYING")
    _generation_sha256(c_license) == expected.c_license_sha256 ||
        error("Spglib C license digest mismatch")
    return (spglib_license, jll_license, library_path, artifact_root, c_license)
end

"""Exercise exact fail-closed handling for altered or missing platform artifact identities."""
function verify_spglib_identity_negative_tests()
    active = _generation_artifact_variant(EXPECTED_SPGLIB)
    altered_tree = merge(active, (artifact_tree = repeat("0", 40),))
    altered_library = merge(active, (library_sha256 = repeat("0", 64),))
    other =
        filter(variant -> variant.platform != active.platform, EXPECTED_SPGLIB.artifact_variants)
    cases = (
        merge(EXPECTED_SPGLIB, (artifact_variants = (altered_tree, other...),)),
        merge(EXPECTED_SPGLIB, (artifact_variants = (altered_library, other...),)),
        merge(EXPECTED_SPGLIB, (artifact_variants = Tuple(other),)),
    )
    for expected in cases
        rejected = false
        try
            verify_spglib_identity(; expected)
        catch
            rejected = true
        end
        rejected || error("altered Spglib artifact identity was not rejected")
    end
    println("PASS Spglib artifact identity negative tests platform=", active.platform)
    return true
end

"""Call Spglib's ordinary point-group standardizer for exact integer rotations."""
function _generation_pointgroup(rotations)
    keys = sort(unique(_magnetic_point_group_matrix_key.(rotations)))
    count = length(keys)
    raw_rotations = Array{Cint}(undef, 3, 3, count)
    for (index, key) in enumerate(keys)
        raw_rotations[:, :, index] .= transpose(_magnetic_point_group_key_matrix(key))
    end
    raw_symbol = fill(Cchar(0), 6)
    raw_transform = zeros(Cint, 3, 3)
    point_group_number = @ccall Spglib.libsymspg.spg_get_pointgroup(
        raw_symbol::Ptr{Cchar},
        raw_transform::Ptr{Cint},
        raw_rotations::Ptr{Cint},
        count::Cint,
    )::Cint
    point_group_number == 0 && error("spg_get_pointgroup failed")
    ordinary_hm = String(UInt8[byte for byte in raw_symbol if byte != 0x00])
    standard_transform = Matrix{Int}(transpose(raw_transform))
    return Int(point_group_number), ordinary_hm, standard_transform
end

"""Check exact closure of a deduplicated colored point-operation set."""
function _generation_validate_closure(rotations, antiunitary)
    operations = Set(
        (_magnetic_point_group_matrix_key(rotation), Bool(parity)) for
        (rotation, parity) in zip(rotations, antiunitary)
    )
    for (left_key, left_parity) in operations, (right_key, right_parity) in operations
        product = (
            _magnetic_point_group_matrix_key(
                _magnetic_point_group_key_matrix(left_key) *
                _magnetic_point_group_key_matrix(right_key),
            ),
            xor(left_parity, right_parity),
        )
        product in operations || error("colored point-operation closure failure")
    end
    return length(operations)^2
end

"""Build the 32 ordinary canonical operation sets from minimum-UNI Spglib records."""
function _generation_ordinary_canonical_groups()
    groups = Dict{Int, Set{_MagneticPointGroupMatrixKey}}()
    for uni_number in 1:1651
        rotations, _, antiunitary = Spglib.get_magnetic_symmetry_from_database(uni_number)
        ordinary_number, _, transform = _generation_pointgroup(rotations)
        haskey(groups, ordinary_number) && continue
        input_colors = Dict{_MagneticPointGroupMatrixKey, Set{Bool}}()
        for (rotation, parity) in zip(rotations, antiunitary)
            key = _magnetic_point_group_matrix_key(Matrix{Int}(rotation))
            push!(get!(input_colors, key, Set{Bool}()), Bool(parity))
        end
        standardized = _magnetic_point_group_conjugate_colors(input_colors, transform)
        standardized === nothing && error("ordinary point-group standardization failed")
        groups[ordinary_number] = Set(keys(standardized))
    end
    length(groups) == 32 || error("Spglib did not provide all 32 ordinary point groups")
    return groups
end

"""Build all generated records from Spglib without reading the committed catalog."""
function generate_catalog_records(
    canonical_groups;
    reverse_input::Bool = false,
    verify_closure::Bool = true,
)
    rows = NamedTuple[]
    class_by_digest = Dict{String, Int}()
    class_identity = Dict{Int, NamedTuple}()
    closure_products = 0
    for uni_number in 1:1651
        rotations, _, antiunitary = Spglib.get_magnetic_symmetry_from_database(uni_number)
        reverse_input && begin
            rotations = reverse(rotations)
            antiunitary = reverse(antiunitary)
        end
        verify_closure && (closure_products += _generation_validate_closure(rotations, antiunitary))
        ordinary_number, ordinary_hm, transform = _generation_pointgroup(rotations)
        canonical = _magnetic_point_group_canonical_form(
            rotations,
            antiunitary,
            ordinary_number,
            ordinary_hm,
            transform,
            canonical_groups[ordinary_number],
        )
        class_number =
            get!(class_by_digest, canonical.operation_digest, length(class_by_digest) + 1)
        identity = (
            operation_digest = canonical.operation_digest,
            hermann_mauguin = canonical.hermann_mauguin,
            equivalent_axis_notation = canonical.equivalent_axis_notation,
        )
        if haskey(class_identity, class_number)
            class_identity[class_number] == identity ||
                error("inconsistent generated identity for class $(class_number)")
        else
            class_identity[class_number] = identity
        end
        msg_type = Int(Spglib.get_magnetic_spacegroup_type(uni_number).type)
        push!(
            rows,
            (;
                uni_number,
                msg_type,
                ordinary_number,
                ordinary_hm,
                class_number,
                operation_digest = canonical.operation_digest,
                hermann_mauguin = canonical.hermann_mauguin,
                equivalent_axis_notation = canonical.equivalent_axis_notation,
                basis_transform_to_input = canonical.basis_transform_to_input,
                colored_operation_count = canonical.colored_operation_count,
                spatial_rotation_count = canonical.spatial_rotation_count,
            ),
        )
    end
    length(rows) == 1651 || error("generated catalog does not cover 1651 UNI numbers")
    length(class_by_digest) == 122 || error("generated catalog does not contain 122 digest classes")
    Set(values(class_by_digest)) == Set(1:122) ||
        error("generated class numbering is not contiguous")
    length(unique(row.operation_digest for row in rows)) == 122 ||
        error("generated catalog contains a digest collision")
    return (; rows, class_identity, closure_products)
end

"""Conjugate input rotations by one exact basis, returning nothing if nonintegral."""
function _generation_conjugate_input(rotations, basis)
    inverse_basis = inv(Rational{Int}.(basis))
    transformed = Matrix{Int}[]
    for rotation in rotations
        exact = inverse_basis * Matrix{Int}(rotation) * basis
        all(isinteger, exact) || return nothing
        push!(transformed, Int.(exact))
    end
    return transformed
end

"""Verify operation-digest covariance on one representative of every generated class."""
function _generation_covariance_audit(catalog, canonical_groups)
    transforms = (
        [0 1 0; 1 0 0; 0 0 1],
        [0 0 1; 1 0 0; 0 1 0],
        [1 1 0; 0 1 0; 0 0 1],
        [1 0 1; 0 1 0; 0 0 1],
        [1 1 0; -1 1 0; 0 0 1],
        [1 1 0; -1 2 0; 0 0 1],
    )
    first_by_class = Dict{Int, Int}()
    for row in catalog.rows
        get!(first_by_class, row.class_number, row.uni_number)
    end
    checked = 0
    for (class_number, uni_number) in sort!(collect(first_by_class))
        rotations, _, antiunitary = Spglib.get_magnetic_symmetry_from_database(uni_number)
        expected_digest = catalog.class_identity[class_number].operation_digest
        for basis in transforms
            transformed = _generation_conjugate_input(rotations, basis)
            transformed === nothing && continue
            ordinary_number, ordinary_hm, standard_transform = _generation_pointgroup(transformed)
            canonical = _magnetic_point_group_canonical_form(
                transformed,
                antiunitary,
                ordinary_number,
                ordinary_hm,
                standard_transform,
                canonical_groups[ordinary_number],
            )
            canonical.operation_digest == expected_digest ||
                error("operation digest changes under allowed basis for class $(class_number)")
            checked += 1
        end
    end
    checked > 0 || error("operation-digest covariance audit did not exercise any basis")
    return checked
end

"""Serialize the display catalog for its explicitly display-only provenance hash."""
function _generation_display_serialization(catalog)
    output = IOBuffer()
    println(output, GENERATION_CONTRACT)
    for row in catalog.rows
        basis = row.basis_transform_to_input
        numerator_key = join(Iterators.flatten(basis.numerator_rows), ',')
        println(
            output,
            join(
                (
                    row.uni_number,
                    row.msg_type,
                    row.class_number,
                    row.operation_digest,
                    row.hermann_mauguin,
                    row.equivalent_axis_notation ? 1 : 0,
                    numerator_key,
                    basis.denominator,
                ),
                '|',
            ),
        )
    end
    return String(take!(output))
end

"""Render one Julia string literal without environment-dependent pretty printing."""
_generation_julia_string(value) = repr(String(value))

"""Render the deterministic generated Julia catalog source."""
function render_generated_source(catalog, canonical_groups, generator_sha256, specification_sha256)
    classes = [catalog.class_identity[index] for index in 1:122]
    display_serialization = _generation_display_serialization(catalog)
    display_catalog_sha256 = bytes2hex(sha256(display_serialization))
    output = IOBuffer()
    println(output, "# This file is generated by scripts/generate_response_symmetry_catalog.jl.")
    println(output, "# Do not edit it by hand or use it as an input to the generator.")
    println(output)
    println(
        output,
        "const MAGNETIC_POINT_GROUP_ORDINARY_CANONICAL_KEYS = Dict{Int, Set{_MagneticPointGroupMatrixKey}}(",
    )
    for ordinary_number in sort!(collect(keys(canonical_groups)))
        keys = sort!(collect(canonical_groups[ordinary_number]))
        key_text = join(("(" * join(key, ", ") * ")" for key in keys), ", ")
        println(
            output,
            "    ",
            ordinary_number,
            " => Set{_MagneticPointGroupMatrixKey}([",
            key_text,
            "]),",
        )
    end
    println(output, ")")
    println(output)
    println(
        output,
        "const MAGNETIC_POINT_GROUP_GENERATION_CONTRACT = ",
        _generation_julia_string(GENERATION_CONTRACT),
    )
    println(
        output,
        "const MAGNETIC_POINT_GROUP_GENERATOR_SHA256 = ",
        _generation_julia_string(generator_sha256),
    )
    println(
        output,
        "const MAGNETIC_POINT_GROUP_SPECIFICATION_SHA256 = ",
        _generation_julia_string(specification_sha256),
    )
    println(
        output,
        "const MAGNETIC_POINT_GROUP_DISPLAY_CATALOG_SHA256 = ",
        _generation_julia_string(display_catalog_sha256),
    )
    println(output)
    println(output, "const MAGNETIC_POINT_GROUP_SYMBOLS = String[")
    for identity in classes
        println(output, "    ", _generation_julia_string(identity.hermann_mauguin), ",")
    end
    println(output, "]")
    println(output, "const MAGNETIC_POINT_GROUP_OPERATION_DIGESTS = String[")
    for identity in classes
        println(output, "    ", _generation_julia_string(identity.operation_digest), ",")
    end
    println(output, "]")
    println(
        output,
        "const MAGNETIC_POINT_GROUP_EQUIVALENT_AXIS_NOTATION = Bool[",
        join((identity.equivalent_axis_notation for identity in classes), ", "),
        "]",
    )
    println(
        output,
        "const MAGNETIC_POINT_GROUP_DIGEST_TO_NUMBER = Dict(\n",
        join(
            (
                "    " *
                _generation_julia_string(identity.operation_digest) *
                " => " *
                string(index) *
                "," for (index, identity) in enumerate(classes)
            ),
            '\n',
        ),
        "\n)",
    )
    println(
        output,
        "const UNI_TO_MAGNETIC_POINT_GROUP_INDEX = UInt8[\n    ",
        join((row.class_number for row in catalog.rows), ", "),
        "\n]",
    )
    println(
        output,
        "const UNI_TO_MAGNETIC_SPACE_GROUP_TYPE = UInt8[\n    ",
        join((row.msg_type for row in catalog.rows), ", "),
        "\n]",
    )
    println(output, "const UNI_TO_MAGNETIC_POINT_GROUP_BASIS_NUMERATORS = NTuple{9, Int}[")
    for row in catalog.rows
        values = collect(Iterators.flatten(row.basis_transform_to_input.numerator_rows))
        println(output, "    (", join(values, ", "), "),")
    end
    println(output, "]")
    println(output, "const UNI_TO_MAGNETIC_POINT_GROUP_BASIS_DENOMINATORS = Int[")
    println(
        output,
        "    ",
        join((row.basis_transform_to_input.denominator for row in catalog.rows), ", "),
    )
    println(output, "]")
    return String(take!(output)), display_catalog_sha256
end

"""Build the deterministic generation receipt after rendering the generated source."""
function render_generation_receipt(
    generated_source_sha256,
    display_catalog_sha256,
    generator_sha256,
    canonicalization_sha256,
    specification_sha256,
    catalog,
)
    receipt = (
        schema = RECEIPT_SCHEMA,
        status = "PASS",
        generation_contract = GENERATION_CONTRACT,
        operation_digest_contract = MAGNETIC_POINT_GROUP_OPERATION_DIGEST_CONTRACT,
        symbol_convention = MAGNETIC_POINT_GROUP_SYMBOL_CONVENTION,
        command = "julia --project=. scripts/generate_response_symmetry_catalog.jl",
        network_required = false,
        forbidden_inputs = [
            "PythMPG source, dictionaries, ordering, or generated results",
            "ISO-MAG data files or generated results",
            "historical catalog or catalog receipt",
        ],
        inputs = (
            spglib_api = ["get_magnetic_symmetry_from_database", "spg_get_pointgroup"],
            generator_sha256,
            canonicalization_sha256,
            specification_sha256,
        ),
        locked_spglib = (
            spglib_jl = (
                version = string(EXPECTED_SPGLIB.julia_version),
                commit = EXPECTED_SPGLIB.julia_commit,
                git_tree_sha1 = EXPECTED_SPGLIB.julia_tree,
                license = "MIT",
                license_sha256 = EXPECTED_SPGLIB.julia_license_sha256,
            ),
            spglib_jll = (
                version = string(EXPECTED_SPGLIB.jll_version),
                commit = EXPECTED_SPGLIB.jll_commit,
                git_tree_sha1 = EXPECTED_SPGLIB.jll_tree,
                license = "MIT",
                license_sha256 = EXPECTED_SPGLIB.jll_license_sha256,
            ),
            spglib_c = (
                version = string(EXPECTED_SPGLIB.c_version),
                commit = EXPECTED_SPGLIB.c_commit,
                verified_generation_artifacts = collect(EXPECTED_SPGLIB.artifact_variants),
                license = "BSD-3-Clause",
                license_sha256 = EXPECTED_SPGLIB.c_license_sha256,
            ),
            database_sources = (
                msg_database_c_sha256 = EXPECTED_SPGLIB.msg_database_c_sha256,
                msg_database_h_sha256 = EXPECTED_SPGLIB.msg_database_h_sha256,
                magnetic_hall_symbols_yaml_sha256 = EXPECTED_SPGLIB.magnetic_hall_symbols_sha256,
                msg_numbers_csv_sha256 = EXPECTED_SPGLIB.msg_numbers_sha256,
                make_mhall_db_py_sha256 = EXPECTED_SPGLIB.make_mhall_db_sha256,
                make_msgtype_db_py_sha256 = EXPECTED_SPGLIB.make_msgtype_db_sha256,
            ),
        ),
        validation = (
            uni_coverage = length(catalog.rows),
            magnetic_point_group_classes = length(catalog.class_identity),
            digest_conflicts = 0,
            closure_products_checked = catalog.closure_products,
            coordinate_basis_cases_checked = catalog.coordinate_basis_cases_checked,
            type_counts = Dict(
                string(type) => count(row -> row.msg_type == type, catalog.rows) for type in 1:4
            ),
        ),
        outputs = (
            generated_source = "src/SymmetryFoundation/GeneratedMagneticPointGroupCatalog.jl",
            generated_source_sha256,
            display_catalog_sha256,
        ),
    )
    buffer = IOBuffer()
    JSON3.pretty(buffer, receipt; allow_inf = false)
    println(buffer)
    return String(take!(buffer))
end

"""Generate catalog source and receipt text after validating the locked dependency closure."""
function generate_catalog_artifacts()
    verify_spglib_identity()
    generator_sha256 = _generation_sha256(@__FILE__)
    canonicalization_sha256 = _generation_sha256(CANONICALIZATION_SOURCE)
    specification_sha256 = _generation_sha256(SPECIFICATION)
    canonical_groups = _generation_ordinary_canonical_groups()
    catalog = generate_catalog_records(canonical_groups)
    reversed =
        generate_catalog_records(canonical_groups; reverse_input = true, verify_closure = false)
    [(row.class_number, row.operation_digest, row.hermann_mauguin) for row in reversed.rows] == [(row.class_number, row.operation_digest, row.hermann_mauguin) for row in catalog.rows] ||
        error("catalog generation changes when database operations are reversed")
    catalog = merge(
        catalog,
        (coordinate_basis_cases_checked = _generation_covariance_audit(catalog, canonical_groups),),
    )
    generated_source, display_catalog_sha256 =
        render_generated_source(catalog, canonical_groups, generator_sha256, specification_sha256)
    receipt = render_generation_receipt(
        bytes2hex(sha256(generated_source)),
        display_catalog_sha256,
        generator_sha256,
        canonicalization_sha256,
        specification_sha256,
        catalog,
    )
    return (; generated_source, receipt, catalog)
end

"""Write or byte-compare the deterministic generated artifacts."""
function main(arguments = ARGS)
    arguments in (String[], ["--check"], ["--identity-self-test"]) ||
        error("usage: generate_response_symmetry_catalog.jl [--check|--identity-self-test]")
    arguments == ["--identity-self-test"] && return verify_spglib_identity_negative_tests()
    artifacts = generate_catalog_artifacts()
    if arguments == ["--check"]
        isfile(GENERATED_SOURCE) || error("generated catalog source is missing")
        isfile(RECEIPT) || error("catalog generation receipt is missing")
        read(GENERATED_SOURCE, String) == artifacts.generated_source ||
            error("committed generated catalog differs from clean replay")
        read(RECEIPT, String) == artifacts.receipt ||
            error("committed catalog receipt differs from clean replay")
    else
        open(GENERATED_SOURCE, "w") do output
            write(output, artifacts.generated_source)
        end
        open(RECEIPT, "w") do output
            write(output, artifacts.receipt)
        end
    end
    println(
        "PASS rows=1651 classes=122 conflicts=0 generated_sha256=",
        bytes2hex(sha256(artifacts.generated_source)),
    )
    return nothing
end

abspath(PROGRAM_FILE) == abspath(@__FILE__) && main()
