using Test, WannierNLQG, HDF5, JSON3, LinearAlgebra
isdefined(@__MODULE__, :test_operator_bundle_geometry) || include("OperatorBundleTestSupport.jl")

@testset "Packed construction evidence seals" begin
    core = WannierNLQG.Core
    io = WannierNLQG.IO
    ext = Base.get_extension(WannierNLQG, :WannierNLQGOperatorBundleExt)
    lattice = Matrix{Float64}(I, 3, 3)
    rv = zeros(Int, 3, 1)
    operators = Dict(
        core.REAL_SPACE_HAMILTONIAN => core.RealSpaceOperator(
            core.RealSpaceOperatorSymmetrySpec(core.REAL_SPACE_HAMILTONIAN, 0, 1, 1),
            rv,
            fill(ComplexF64(1), 1, 1, 1),
        ),
        core.REAL_SPACE_POSITION => core.RealSpaceOperator(
            core.RealSpaceOperatorSymmetrySpec(core.REAL_SPACE_POSITION, 1, -1, 1),
            rv,
            zeros(ComplexF64, 1, 1, 3, 1),
        ),
    )
    geometry = test_operator_bundle_geometry(lattice, [1], operators)
    geometry["production_eligible"] = false
    records = [
        Dict(
            "code" => "TEST_QUALITY",
            "severity" => "error",
            "message" => "retained original failure",
            "context" => Dict(
                "gate_result" => "FAIL",
                "action" => "CONTINUE_DIAGNOSTIC",
                "stage" => "preparation",
                "value" => "1e-7",
                "threshold" => "1e-10",
            ),
        ),
    ]
    metadata = Dict{String, Any}(
        "construction_policy" => "diagnostic",
        "construction_gate_records_json" => String(JSON3.write(records)),
        "manual_review_required" => true,
        "construction_quality_failed" => true,
        "diagnostic_classification" => "DIAGNOSTIC_ONLY_QUALITY_FAILED",
        "diagnostic_only" => true,
        "production_eligible" => false,
    )
    function write_bundle(path; values = metadata)
        io.write_real_space_operator_bundle(
            path,
            lattice,
            [1],
            operators;
            profile = :hamiltonian_position,
            geometry,
            diagnostics = values,
            eligibility = values,
        )
    end
    function set_attribute(group, name, value)
        haskey(HDF5.attributes(group), name) && HDF5.delete_attribute(group, name)
        HDF5.attributes(group)[name] = value
    end
    readers = (
        io.read_real_space_operator_bundle_manifest,
        io.read_real_space_operator_bundle,
        io.read_operator_bundle_payload,
        path -> io.read_real_space_operator_bundle(path; verify_digests = false),
        path -> io.read_operator_bundle_components(
            path,
            Dict(core.REAL_SPACE_HAMILTONIAN => [(0, 0)]),
        ),
    )
    mktempdir() do dir
        original = write_bundle(joinpath(dir, "original.h5"))
        path = joinpath(dir, "original.h5")
        @test all(reader -> reader(path) !== nothing, readers)
        h5open(path, "r") do f
            @test String(read(HDF5.attributes(f["construction_evidence"])["schema_version"])) ==
                  "1.0"
            @test read(
                HDF5.attributes(f["construction_evidence"])["construction_gate_records_json"],
            ) == metadata["construction_gate_records_json"]
        end
        alterations = (
            f -> set_attribute(f["diagnostics"], "construction_gate_records_json", "[]"),
            f -> set_attribute(
                f["construction_evidence"],
                "construction_gate_records_json",
                "{malformed JSON",
            ),
            f -> HDF5.delete_object(f, "construction_evidence"),
            f -> HDF5.delete_attribute(f, "construction_evidence_sha256"),
            f -> set_attribute(f, "manual_review_required", false),
            f -> set_attribute(f["diagnostics"], "construction_quality_failed", false),
            f -> set_attribute(f["construction_evidence"], "construction_policy", "strict"),
            f -> begin
                HDF5.delete_object(f, "construction_evidence")
                HDF5.delete_attribute(f, "construction_evidence_sha256")
            end,
        )
        for (index, alter) in enumerate(alterations)
            changed = joinpath(dir, "tamper$(index).h5")
            cp(path, changed)
            h5open(alter, changed, "r+")
            for reader in readers
                @test_throws ArgumentError reader(changed)
            end
        end
        for name in ("construction_quality_failed", "manual_review_required", "diagnostic_only")
            invalid = copy(metadata);
            invalid[name] = false
            @test_throws ArgumentError write_bundle(
                joinpath(dir, "invalid$(name).h5");
                values = invalid,
            )
        end
        invalid = copy(metadata);
        invalid["construction_gate_records_json"] = "{}"
        @test_throws ArgumentError write_bundle(joinpath(dir, "invalidjson.h5"); values = invalid)
        legacy = joinpath(dir, "legacy.h5")
        write_bundle(legacy; values = Dict{String, Any}())
        legacy_manifest = io.read_real_space_operator_bundle_manifest(legacy)
        @test legacy_manifest.scientific_content_sha256 !=
              io.read_real_space_operator_bundle_manifest(path).scientific_content_sha256
        h5open(legacy, "r") do f
            @test !haskey(f, "construction_evidence")
            @test !haskey(HDF5.attributes(f), "construction_evidence_sha256")
        end
        # Existing checked-in historical bytes still validate with the unchanged old digest layout.
        fixture = joinpath(@__DIR__, "fixtures", "schema_compatibility", "packed_6_3.h5")
        stored =
            h5open(f -> String(read(HDF5.attributes(f)["scientific_content_sha256"])), fixture, "r")
        @test io.read_real_space_operator_bundle(fixture).manifest.scientific_content_sha256 ==
              stored
        # Explicitly omitted evidence adds no tag or bytes to old digest calls.
        args = (
            :hamiltonian_position,
            [core.REAL_SPACE_HAMILTONIAN],
            lattice,
            rv,
            [1],
            [repeat("a", 64)],
            nothing,
        )
        legacy_digest = ext._scientific_content_digest(args...)
        @test length(legacy_digest) == 64
    end
end
