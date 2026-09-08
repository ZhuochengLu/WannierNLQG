using Test
using LinearAlgebra
import Spglib

const RESPONSE_GROUP_FOUNDATION = WannierNLQG.SymmetryFoundation
const RESPONSE_GROUP_RUNTIME = WannierNLQG.Runtime
const RESPONSE_GROUP_IO = WannierNLQG.IO

function response_group_test_operation(
    rotation;
    translation = zeros(3),
    antiunitary = false,
    source_index = 1,
)
    return (
        rotation_fractional = Matrix{Int}(rotation),
        translation_fractional = Vector{Float64}(translation),
        antiunitary = Bool(antiunitary),
        source_index = Int(source_index),
    )
end

response_group_test_point_key(operation) =
    (Tuple(vec(operation.rotation_fractional)), operation.antiunitary)

function response_group_test_point_product(left, right)
    return (
        rotation_fractional = left.rotation_fractional * right.rotation_fractional,
        translation_fractional = zeros(3),
        antiunitary = xor(left.antiunitary, right.antiunitary),
        source_index = 0,
    )
end

function response_group_test_payload_operation(payload)
    rotation = reduce(vcat, [permutedims(Int.(row)) for row in payload["rotation_fractional"]])
    return response_group_test_operation(
        rotation;
        translation = Float64.(payload["translation_fractional"]),
        antiunitary = payload["antiunitary"],
        source_index = payload["source_operation_index"],
    )
end

function response_group_test_generated_point_keys(operations, report)
    by_key = Dict(response_group_test_point_key(operation) => operation for operation in operations)
    identity = response_group_test_operation(Matrix{Int}(I, 3, 3))
    generated = Dict(response_group_test_point_key(identity) => identity)
    for payload in report["generators"]
        operation = response_group_test_payload_operation(payload)
        generated[response_group_test_point_key(operation)] = operation
    end
    changed = true
    while changed
        changed = false
        current = collect(values(generated))
        for left in current, right in current
            product = response_group_test_point_product(left, right)
            key = response_group_test_point_key(product)
            haskey(by_key, key) || error("reported generators leave the reference point group")
            if !haskey(generated, key)
                generated[key] = by_key[key]
                changed = true
            end
        end
    end
    return Set(keys(generated))
end

function response_group_test_assert_point_group(operations)
    identity_key =
        response_group_test_point_key(response_group_test_operation(Matrix{Int}(I, 3, 3)))
    keys = Set(response_group_test_point_key(operation) for operation in operations)
    @test identity_key in keys
    for left in operations, right in operations
        @test response_group_test_point_key(response_group_test_point_product(left, right)) in keys
    end
    for operation in operations
        @test any(operations) do inverse
            response_group_test_point_key(response_group_test_point_product(operation, inverse)) ==
            identity_key &&
                response_group_test_point_key(
                    response_group_test_point_product(inverse, operation),
                ) == identity_key
        end
    end
end

@testset "generated 1651-to-122 magnetic point-group catalog" begin
    provenance = RESPONSE_GROUP_FOUNDATION.magnetic_point_group_catalog_provenance()
    entries = [RESPONSE_GROUP_FOUNDATION.magnetic_point_group_catalog_entry(uni) for uni in 1:1651]
    @test length(entries) == 1651
    @test length(Set(entry.magnetic_point_group_number for entry in entries)) == 122
    @test all(entry -> !isempty(entry.hermann_mauguin), entries)
    @test !hasproperty(provenance, :catalog_sha256)
    @test length(provenance.display_catalog_sha256) == 64
    @test all(entry -> length(entry.operation_digest) == 64, entries)
    @test all(
        entry ->
            entry.operation_digest_contract == "wanniernlqg.magnetic-point-group-operations/1.0",
        entries,
    )
    @test all(entry -> entry.symbol_convention == "wanniernlqg.spglib-canonical/1.0", entries)
    @test all(entry -> !hasproperty(entry, :catalog_sha256), entries)
    @test RESPONSE_GROUP_FOUNDATION.magnetic_point_group_catalog_entry(1).hermann_mauguin == "1"
    @test RESPONSE_GROUP_FOUNDATION.magnetic_point_group_catalog_entry(2).hermann_mauguin == "1'"
    @test RESPONSE_GROUP_FOUNDATION.magnetic_point_group_catalog_entry(1651).hermann_mauguin ==
          "m'-3'm'"
    @test_throws ArgumentError RESPONSE_GROUP_FOUNDATION.magnetic_point_group_catalog_entry(0)
    @test_throws ArgumentError RESPONSE_GROUP_FOUNDATION.magnetic_point_group_catalog_entry(1652)
end

function response_group_test_assert_identity(group)
    @test group["magnetic_point_group_number"] in 1:122
    @test length(group["operation_digest"]) == 64
    @test group["operation_digest_contract"] == "wanniernlqg.magnetic-point-group-operations/1.0"
    @test !isempty(group["hermann_mauguin"])
    @test group["symbol_convention"] == "wanniernlqg.spglib-canonical/1.0"
    @test group["equivalent_axis_notation"] isa Bool
    basis = group["basis_transform_to_input"]
    @test basis["shape"] == [3, 3]
    @test length(basis["numerator_rows"]) == 3
    @test all(row -> length(row) == 3, basis["numerator_rows"])
    @test basis["denominator"] isa Integer
    @test basis["denominator"] > 0
    @test occursin("v_input", basis["definition"])
end

@testset "point-group generators reconstruct identity, inverses, and closure" begin
    identity = Matrix{Int}(I, 3, 3)
    mirror_x = Diagonal(Int[-1, 1, 1]) |> Matrix
    mirror_y = Diagonal(Int[1, -1, 1]) |> Matrix
    rotation_2z = mirror_x * mirror_y
    operations = [
        response_group_test_operation(identity; source_index = 41),
        response_group_test_operation(mirror_x; source_index = 13),
        response_group_test_operation(mirror_y; source_index = 29),
        response_group_test_operation(rotation_2z; source_index = 7),
    ]
    response_group_test_assert_point_group(operations)
    report = RESPONSE_GROUP_FOUNDATION.response_group_generators(operations; seitz = false)
    @test report["closure_verified"]
    @test report["group_order"] == 4
    @test report["reconstructed_group_order"] == 4
    @test report["generator_count"] == 2
    @test response_group_test_generated_point_keys(operations, report) ==
          Set(response_group_test_point_key(operation) for operation in operations)

    shuffled_report =
        RESPONSE_GROUP_FOUNDATION.response_group_generators(reverse(operations); seitz = false)
    @test RESPONSE_GROUP_RUNTIME.progress_json_value(report) ==
          RESPONSE_GROUP_RUNTIME.progress_json_value(shuffled_report)

    grey_operations =
        vcat(operations, [merge(operation, (antiunitary = true,)) for operation in operations])
    response_group_test_assert_point_group(grey_operations)
    grey_report =
        RESPONSE_GROUP_FOUNDATION.response_group_generators(grey_operations; seitz = false)
    @test grey_report["group_order"] == 8
    @test grey_report["unitary_operation_count"] == 4
    @test grey_report["antiunitary_operation_count"] == 4
    @test any(generator -> generator["kind"] == "ANTIUNITARY", grey_report["generators"])
    @test response_group_test_generated_point_keys(grey_operations, grey_report) ==
          Set(response_group_test_point_key(operation) for operation in grey_operations)
end

@testset "finite Seitz generators preserve fractional translation" begin
    identity = Matrix{Int}(I, 3, 3)
    operations = [
        response_group_test_operation(
            identity;
            translation = [fraction / 4, 0.0, 0.0],
            source_index = fraction + 1,
        ) for fraction in 0:3
    ]
    report = RESPONSE_GROUP_FOUNDATION.response_group_generators(
        operations;
        seitz = true,
        tolerance = 1.0e-10,
    )
    @test report["closure_verified"]
    @test report["group_order"] == 4
    @test report["generator_count"] == 1
    @test report["reconstructed_group_order"] == 4
    generator = only(report["generators"])
    @test generator["translation_fractional_rational"] == ["1/4", "0", "0"]
    @test generator["rotation_fractional"] == [[1, 0, 0], [0, 1, 0], [0, 0, 1]]
    shuffled_report = RESPONSE_GROUP_FOUNDATION.response_group_generators(
        reverse(operations);
        seitz = true,
        tolerance = 1.0e-10,
    )
    @test RESPONSE_GROUP_RUNTIME.progress_json_value(report) ==
          RESPONSE_GROUP_RUNTIME.progress_json_value(shuffled_report)
end

@testset "generator validation rejects an incomplete closure" begin
    identity = Matrix{Int}(I, 3, 3)
    quarter_turn = [0 -1 0; 1 0 0; 0 0 1]
    incomplete = [
        response_group_test_operation(identity; source_index = 1),
        response_group_test_operation(quarter_turn; source_index = 2),
    ]
    @test_throws ErrorException RESPONSE_GROUP_FOUNDATION.response_group_generators(
        incomplete;
        seitz = false,
    )
end

function response_group_test_p1_payload(; include_time_reversal)
    identity_operation = Dict(
        "rotation_fractional" => [[1, 0, 0], [0, 1, 0], [0, 0, 1]],
        "translation_fractional" => [0.0, 0.0, 0.0],
        "antiunitary" => false,
        "source_space_group_indices" => [1],
    )
    antiunitary_identity = merge(
        deepcopy(identity_operation),
        Dict("antiunitary" => true, "source_space_group_indices" => [2]),
    )
    active_operations =
        include_time_reversal ? [identity_operation, antiunitary_identity] : [identity_operation]
    return Dict{String, Any}(
        "provenance" => Dict(
            "include_time_reversal" => include_time_reversal,
            "spglib_version" => string(pkgversion(Spglib)),
            "spglib_symprec_angstrom" => 1.0e-5,
        ),
        "structure" => Dict(
            "lattice_rows_angstrom" => [[1.0, 0.0, 0.0], [0.2, 1.1, 0.0], [0.1, 0.3, 1.3]],
            "elements" => ["X", "Y", "Z"],
            "positions_fractional_columns" =>
                [[0.13, 0.27, 0.39], [0.22, 0.41, 0.58], [0.71, 0.17, 0.83]],
            "magnetic_moments_cartesian_columns" => [zeros(3) for _ in 1:3],
        ),
        "symmetry" => Dict(
            "magnetic" => false,
            "msg_type" => include_time_reversal ? 2 : 1,
            "uni_number" => nothing,
            "hall_number" => 1,
            "unitary_operation_count" => 1,
            "antiunitary_operation_count" => include_time_reversal ? 1 : 0,
            "space_group_operations" => active_operations,
            "point_group_operations" => deepcopy(active_operations),
            "checks" => Dict(
                "space_group" => Dict("translation_tolerance_fractional" => 1.0e-8),
                "tolerance_stability" => Dict("status" => "PASS"),
            ),
        ),
    )
end

@testset "disabled time reversal separates full grey group from active unitary subgroup" begin
    report = RESPONSE_GROUP_FOUNDATION.response_symmetry_group_report(
        response_group_test_p1_payload(include_time_reversal = false);
        strict = true,
    )
    classification = report["group_classification"]
    active = report["active_constraint_group"]
    generators = report["generators"]
    @test report["status"] == "RESOLVED"
    @test classification["structural_space_group"]["international_number"] == 1
    @test classification["structural_space_group"]["hall_number"] == 1
    @test classification["structural_space_group"]["hall_symbol"] == "P 1"
    @test classification["structural_space_group"]["setting"] == "standard"
    @test classification["structural_point_group"]["hermann_mauguin"] == "1"
    @test classification["full_magnetic_point_group"]["hermann_mauguin"] == "1'"
    response_group_test_assert_identity(classification["full_magnetic_point_group"])
    @test !active["include_time_reversal"]
    @test active["uses_unitary_subgroup_only"]
    @test active["hermann_mauguin"] == "1"
    response_group_test_assert_identity(active)
    @test active["magnetic_point_group_number"] == 1
    @test active["operation_digest"] !=
          classification["full_magnetic_point_group"]["operation_digest"]
    @test active["group_order"] == 1
    @test active["unitary_operation_count"] == 1
    @test active["antiunitary_operation_count"] == 0
    @test generators["magnetic_point_group"]["group_order"] == 2
    @test generators["active_point_group"]["group_order"] == 1
end

@testset "legacy group-report records remain unresolved diagnostics" begin
    report = RESPONSE_GROUP_FOUNDATION.response_symmetry_group_report(
        Dict{String, Any}("symmetry" => Dict{String, Any}());
        strict = false,
    )
    @test report["status"] == "UNRESOLVED"
    @test report["group_classification"]["status"] == "UNRESOLVED"
    @test report["classification_source"]["status"] == "NOT_RECORDED"
    @test !isempty(report["warnings"])
end

@testset "enabled time reversal uses the complete nonmagnetic grey group" begin
    report = RESPONSE_GROUP_FOUNDATION.response_symmetry_group_report(
        response_group_test_p1_payload(include_time_reversal = true);
        strict = true,
    )
    classification = report["group_classification"]
    active = report["active_constraint_group"]
    generators = report["generators"]
    @test classification["magnetic_space_group"]["type"] == "Type II (nonmagnetic gray group)"
    @test classification["full_magnetic_point_group"]["hermann_mauguin"] == "1'"
    @test active["include_time_reversal"]
    @test !active["uses_unitary_subgroup_only"]
    @test active["hermann_mauguin"] == "1'"
    response_group_test_assert_identity(classification["full_magnetic_point_group"])
    response_group_test_assert_identity(active)
    @test active["magnetic_point_group_number"] ==
          classification["full_magnetic_point_group"]["magnetic_point_group_number"]
    @test active["operation_digest"] ==
          classification["full_magnetic_point_group"]["operation_digest"]
    @test active["group_order"] == 2
    @test active["unitary_operation_count"] == 1
    @test active["antiunitary_operation_count"] == 1
    @test generators["magnetic_point_group"]["group_order"] == 2
    @test generators["active_point_group"]["group_order"] == 2
end

@testset "point operations ignore the translation representative" begin
    baseline_payload = response_group_test_p1_payload(include_time_reversal = false)
    translated_payload = deepcopy(baseline_payload)
    translated_payload["symmetry"]["point_group_operations"][1]["translation_fractional"] =
        [0.37, 0.11, 0.83]
    baseline =
        RESPONSE_GROUP_FOUNDATION.response_symmetry_group_report(baseline_payload; strict = true)
    translated =
        RESPONSE_GROUP_FOUNDATION.response_symmetry_group_report(translated_payload; strict = true)
    @test translated["active_constraint_group"] == baseline["active_constraint_group"]
    @test translated["generators"]["active_point_group"] ==
          baseline["generators"]["active_point_group"]
end

@testset "strict group reporting rejects Hall and point-operation mismatches" begin
    wrong_hall = response_group_test_p1_payload(include_time_reversal = false)
    wrong_hall["symmetry"]["hall_number"] = 2
    @test_throws ErrorException RESPONSE_GROUP_FOUNDATION.response_symmetry_group_report(
        wrong_hall;
        strict = true,
    )

    wrong_point = response_group_test_p1_payload(include_time_reversal = false)
    identity = deepcopy(only(wrong_point["symmetry"]["point_group_operations"]))
    mirror = merge(
        deepcopy(identity),
        Dict(
            "rotation_fractional" => [[-1, 0, 0], [0, 1, 0], [0, 0, 1]],
            "source_space_group_indices" => [2],
        ),
    )
    wrong_point["symmetry"]["point_group_operations"] = [identity, mirror]
    @test_throws ErrorException RESPONSE_GROUP_FOUNDATION.response_symmetry_group_report(
        wrong_point;
        strict = true,
    )
end

function response_group_test_operation_payload(operation, index)
    return Dict(
        "rotation_fractional" =>
            [[operation.rotation_fractional[row, column] for column in 1:3] for row in 1:3],
        "translation_fractional" => collect(operation.translation_fractional),
        "antiunitary" => operation.antiunitary,
        "source_space_group_indices" => [index],
    )
end

function response_group_test_payload(structure; include_time_reversal = true)
    inventory = RESPONSE_GROUP_FOUNDATION.detect_magnetic_symmetry_inventory(
        structure;
        include_time_reversal,
    )
    space_operations = [
        response_group_test_operation_payload(operation, index) for
        (index, operation) in enumerate(inventory.operations)
    ]
    point_by_key = Dict{Tuple{Tuple, Bool}, Dict{String, Any}}()
    for operation in space_operations
        rotation =
            reduce(vcat, [permutedims(Int.(row)) for row in operation["rotation_fractional"]])
        key = (Tuple(vec(rotation)), Bool(operation["antiunitary"]))
        haskey(point_by_key, key) || (point_by_key[key] = deepcopy(operation))
    end
    return Dict{String, Any}(
        "provenance" => Dict(
            "include_time_reversal" => include_time_reversal,
            "spglib_version" => string(pkgversion(Spglib)),
            "spglib_symprec_angstrom" => inventory.symmetry_tolerance,
        ),
        "structure" => Dict(
            "lattice_rows_angstrom" =>
                [[structure.lattice[row, column] for column in 1:3] for row in 1:3],
            "elements" => structure.species,
            "positions_fractional_columns" => [
                collect(structure.positions_fractional[:, atom]) for
                atom in eachindex(structure.species)
            ],
            "magnetic_moments_cartesian_columns" => [
                collect(structure.magnetic_moments_cartesian[:, atom]) for
                atom in eachindex(structure.species)
            ],
        ),
        "symmetry" => Dict(
            "magnetic" => inventory.magnetic,
            "msg_type" => inventory.msg_type,
            "uni_number" => inventory.uni_number,
            "hall_number" => inventory.hall_number,
            "unitary_operation_count" => inventory.unitary_operation_count,
            "antiunitary_operation_count" => inventory.antiunitary_operation_count,
            "space_group_operations" => space_operations,
            "point_group_operations" => collect(values(point_by_key)),
            "checks" => Dict(
                "space_group" => Dict("translation_tolerance_fractional" => 1.0e-8),
                "tolerance_stability" => Dict("status" => "PASS"),
            ),
        ),
    )
end

@testset "Spglib Type I--IV group-report classification" begin
    type1_noncollinear = RESPONSE_GROUP_FOUNDATION.CrystalStructure(
        [1.0 0.0 0.0; 0.2 1.3 0.0; 0.1 0.3 1.7],
        ["X", "Y"],
        [0.13 0.61; 0.27 0.19; 0.39 0.82];
        magnetic_moments_cartesian = [0.31 -0.22; 0.47 0.73; 0.83 0.16],
    )
    type3_collinear = RESPONSE_GROUP_FOUNDATION.CrystalStructure(
        2.87 / 2 .* [-1.0 1 1; 1 -1 1; 1 1 -1],
        ["Fe"],
        zeros(3, 1);
        magnetic_moments_cartesian = reshape([0.0, 0.0, 1.0], 3, 1),
    )
    type4_collinear = RESPONSE_GROUP_FOUNDATION.CrystalStructure(
        4.2 .* [1.0 0.5 0.5; 0.5 1 0.5; 0.5 0.5 1],
        ["Ni", "Ni", "O", "O"],
        [0.0 0.5 0.25 0.75; 0.0 0.5 0.25 0.75; 0.0 0.5 0.25 0.75];
        magnetic_moments_cartesian = [0.0 0 0 0; 0 0 0 0; 1 -1 0 0],
    )
    cases = (
        (expected_type = 1, structure = type1_noncollinear),
        (expected_type = 3, structure = type3_collinear),
        (expected_type = 4, structure = type4_collinear),
    )
    observed_types = Int[]
    for case in cases
        report = RESPONSE_GROUP_FOUNDATION.response_symmetry_group_report(
            response_group_test_payload(case.structure);
            strict = true,
        )
        magnetic = report["group_classification"]["magnetic_space_group"]
        active = report["active_constraint_group"]
        push!(observed_types, parse(Int, last(split(magnetic["type"]))))
        @test magnetic["type"] == "Type $(case.expected_type)"
        @test magnetic["uni_number"] isa Integer
        @test magnetic["bns_number"] isa AbstractString
        @test magnetic["og_number"] isa AbstractString
        @test active["include_time_reversal"]
        response_group_test_assert_identity(
            report["group_classification"]["full_magnetic_point_group"],
        )
        response_group_test_assert_identity(active)
        @test active["group_order"] == report["generators"]["magnetic_point_group"]["group_order"]
    end
    gray_report = RESPONSE_GROUP_FOUNDATION.response_symmetry_group_report(
        response_group_test_p1_payload(include_time_reversal = true);
        strict = true,
    )
    @test gray_report["group_classification"]["magnetic_space_group"]["type"] ==
          "Type II (nonmagnetic gray group)"
    @test observed_types == [1, 3, 4]

    wrong_uni = response_group_test_payload(type1_noncollinear)
    wrong_uni["symmetry"]["uni_number"] += 1
    @test_throws ErrorException RESPONSE_GROUP_FOUNDATION.response_symmetry_group_report(
        wrong_uni;
        strict = true,
    )
end

@testset "response symmetry summary 1.0 retains its marker with additive fields" begin
    identity = Matrix{Int}(I, 3, 3)
    response_operation = RESPONSE_GROUP_IO.ResponseSymmetryOperation(
        identity,
        zeros(3),
        Matrix{Float64}(identity),
        false,
    )
    tensor = RESPONSE_GROUP_RUNTIME._response_tensor_symmetry_plan(
        :shift_current,
        3,
        [response_operation];
        numerical_reduction = false,
    )
    group_report = Dict{String, Any}(
        "group_classification" => Dict("status" => "RESOLVED"),
        "active_constraint_group" => Dict("include_time_reversal" => false, "group_order" => 1),
        "generators" => Dict(
            "active_point_group" =>
                Dict("closure_verified" => true, "reconstructed_group_order" => 1),
        ),
        "classification_source" => Dict("spglib" => string(pkgversion(Spglib))),
    )
    plan = RESPONSE_GROUP_RUNTIME.ResponseSymmetryExecutionPlan(
        "fixture.json",
        repeat("a", 64),
        "wanniernlqg.response-symmetry/1.0",
        true,
        true,
        repeat("b", 64),
        repeat("c", 64),
        :strict,
        :full,
        true,
        :PASS,
        "PASS",
        0.0,
        1.0e-10,
        String[],
        [response_operation],
        [1],
        [1],
        1,
        [tensor],
        group_report,
    )
    summary = RESPONSE_GROUP_RUNTIME._response_symmetry_summary_payload(plan)
    @test summary["schema"] == "wanniernlqg.response-symmetry-summary/1.0"
    for legacy_key in (
        "status",
        "policy",
        "kmesh_mode",
        "warnings",
        "artifact_file",
        "artifact_sha256",
        "artifact_schema",
        "integrand_covariance",
        "k_mesh",
        "responses",
    )
        @test haskey(summary, legacy_key)
    end
    for new_key in
        ("group_classification", "active_constraint_group", "generators", "classification_source")
        @test haskey(summary, new_key)
    end
    @test summary["active_constraint_group"]["include_time_reversal"] === false
    @test summary["generators"]["active_point_group"]["closure_verified"] === true
end

function response_group_test_basis(numerator_rows)
    return Dict(
        "definition" => "v_input = B * v_canonical; W_input = B * W_canonical * inv(B)",
        "shape" => [3, 3],
        "numerator_rows" => numerator_rows,
        "denominator" => 1,
    )
end

function response_group_test_progress_summary(
    task_id;
    group_symbol = "mm2",
    group_order = 4,
    group_number = 21,
    operation_digest = lpad(string(group_number), 64, '0'),
    basis = response_group_test_basis([[1, 0, 0], [0, 1, 0], [0, 0, 1]]),
)
    identity = Dict(
        "magnetic_point_group_number" => group_number,
        "operation_digest" => operation_digest,
        "operation_digest_contract" => "wanniernlqg.magnetic-point-group-operations/1.0",
        "hermann_mauguin" => group_symbol,
        "symbol_convention" => "wanniernlqg.spglib-canonical/1.0",
        "equivalent_axis_notation" => false,
        "basis_transform_to_input" => basis,
    )
    classification = Dict(
        "status" => "RESOLVED",
        "structural_point_group" => Dict("hermann_mauguin" => group_symbol),
        "full_magnetic_point_group" => merge(identity, Dict("group_order" => group_order)),
    )
    active = merge(identity, Dict("group_order" => group_order, "include_time_reversal" => true))
    generators = Dict(
        "closure_verified" => true,
        "reconstructed_group_order" => group_order,
        "generators" => [Dict("operation_symbol" => "2", "kind" => "UNITARY")],
    )
    return (
        status = :PASS,
        policy = :strict,
        kmesh_mode = :full,
        numerical_tensor_projection_applied = false,
        summary_file = "$(task_id)/response_symmetry_summary.json",
        human_summaries = NamedTuple[],
        symmetry_warnings = String[],
        group_classification = classification,
        active_constraint_group = active,
        point_group_generators = generators,
    )
end

@testset "multi-task progress aggregation preserves or separates group reports" begin
    first_summary = response_group_test_progress_summary("task-a")
    same_summary = response_group_test_progress_summary("task-b")
    common = RESPONSE_GROUP_RUNTIME.progress_aggregate_response_symmetry_summaries([
        (task_id = "task-a", summary = first_summary),
        (task_id = "task-b", summary = same_summary),
    ])
    @test common.group_classification == first_summary.group_classification
    @test common.active_constraint_group == first_summary.active_constraint_group
    @test common.point_group_generators == first_summary.point_group_generators
    @test common.symmetry_warning_count == 0

    different_summary = response_group_test_progress_summary(
        "task-c";
        group_symbol = "4mm",
        group_order = 8,
        group_number = 48,
    )
    multiple = RESPONSE_GROUP_RUNTIME.progress_aggregate_response_symmetry_summaries([
        "task-a" => first_summary,
        "task-c" => different_summary,
    ])
    @test multiple.group_classification["status"] == "MULTIPLE_TASK_GROUPS"
    @test multiple.active_constraint_group["status"] == "MULTIPLE_TASK_GROUPS"
    @test multiple.point_group_generators["status"] == "MULTIPLE_TASK_GROUPS"
    @test isempty(multiple.point_group_generators["generators"])
    @test multiple.symmetry_warning_count == 1
    @test only(multiple.symmetry_warnings) ==
          "TASK bundle contains distinct response-symmetry groups; group classification remains per-task in machine-readable summaries"

    swapped_basis = response_group_test_basis([[0, 1, 0], [1, 0, 0], [0, 0, 1]])
    rebased_summary = response_group_test_progress_summary("task-d"; basis = swapped_basis)
    rebased = RESPONSE_GROUP_RUNTIME.progress_aggregate_response_symmetry_summaries([
        "task-a" => first_summary,
        "task-d" => rebased_summary,
    ])
    @test rebased.group_classification["status"] == "MULTIPLE_INPUT_BASES"
    @test rebased.active_constraint_group["status"] == "MULTIPLE_INPUT_BASES"
    @test rebased.point_group_generators["status"] == "MULTIPLE_INPUT_BASES"
    @test rebased.group_classification["full_magnetic_point_group"]["operation_digest"] ==
          first_summary.group_classification["full_magnetic_point_group"]["operation_digest"]
    @test rebased.group_classification["full_magnetic_point_group"]["basis_transform_to_input"] ==
          Dict("status" => "MULTIPLE_INPUT_BASES")
    @test only(rebased.symmetry_warnings) ==
          "TASK bundle contains one response-symmetry identity in multiple input bases; basis-dependent group details remain per-task in machine-readable summaries"
end
