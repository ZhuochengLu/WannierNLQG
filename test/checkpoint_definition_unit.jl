isdefined(@__MODULE__, :standard_export_fixture) ||
    include(joinpath(@__DIR__, "WannierStandardExportTestSupport.jl"))

@testset "Checkpoint complete mathematical inventories and retained archive" begin
    fixture = standard_export_fixture()
    extension = first(EXPORT_WANNIERIZATION._load_wannierization_extension!())
    solver = extension.SolverCheckpoint
    result = fixture.result
    changed = deepcopy(result)
    value = changed.v_matrix[1]
    changed.v_matrix[1] = complex(nextfloat(real(value)), imag(value))
    late = deepcopy(result)
    late.input_summary["construction_policy_contract"] = "standard_construction_v1"
    late.input_summary["construction_policy"] = "standard"
    late.input_summary["quality_review_status"] = "definition-test"

    # Historical hash routines require retired runtime fields. Keep that frozen
    # reference untouched; the archived definition below is the independent byte
    # oracle. Current tests exercise the public sequential mathematical inventory.
    expected_versions = Set((
        :base,
        :v1_2,
        :v1_3,
        :v2_1,
        :v2_2,
        :v2_3,
        :v2_4,
        :v2_5,
        :v2_6,
        :v2_7,
        :v2_8,
        :v2_9,
        :v2_10,
        :v2_11,
        :v2_12,
        :v2_13,
        :v2_16,
        :v2_17,
        :v2_18,
        :v2_19,
        :v2_20,
        :v2_21,
        :v2_22,
        :v2_23,
        :v2_24,
        :v2_25,
        :v2_26,
        :v2_27,
        :v2_28,
        :v1_1,
        :v2_29,
        :v2_30,
    ))
    @test Set(keys(solver.CHECKPOINT_DEFINITION_WRITERS)) == expected_versions
    @test !isdefined(solver, :_wannierization_checkpoint_sha256)

    bytes_for = function (candidate; version = :v2_30)
        buffer = IOBuffer()
        solver.write_checkpoint_definition(buffer, candidate; version)
        take!(buffer)
    end
    for version in sort!(collect(expected_versions); by = String)
        bytes = bytes_for(result; version)
        prefix = collect(
            codeunits(
                "wanniernlqg.checkpoint-definition/1:" *
                String(version) *
                "\n" *
                string(result.status) *
                "\n",
            ),
        )
        @test bytes[1:length(prefix)] == prefix
        @test bytes == bytes_for(deepcopy(result); version)
        @test bytes != bytes_for(changed; version)
    end
    original = bytes_for(result)
    @test original == bytes_for(deepcopy(result))
    @test original != bytes_for(changed)
    @test original != bytes_for(late)
    @test bytes_for(result; version = :v2_22) != original
    @test bytes_for(result; version = :v2_22) != bytes_for(changed; version = :v2_22)
    @test_throws ArgumentError bytes_for(result; version = :unsupported)

    # Pin actual scientific values in the sequential definition, including a
    # one-ULP distinction, rather than comparing opaque local owner labels.
    prefix = vcat(
        collect(
            codeunits("wanniernlqg.checkpoint-definition/1:v2_30\n" * string(result.status) * "\n"),
        ),
        reinterpret(UInt8, Int64[ndims(result.v_matrix), size(result.v_matrix)...]),
        reinterpret(UInt8, vec(result.v_matrix)),
    )
    @test original[1:length(prefix)] == prefix
    mktemp() do path, stream
        solver.write_checkpoint_definition(stream, result)
        flush(stream)
        seekstart(stream)
        @test read(stream) == original
    end
    @test result.v_matrix != changed.v_matrix
    @test !haskey(result.input_summary, "quality_review_status") ||
          result.input_summary["quality_review_status"] !=
          late.input_summary["quality_review_status"]
end

@testset "Checkpoint sequential scratch shares native lifetime enforcement" begin
    fixture = standard_export_fixture()
    solver = first(EXPORT_WANNIERIZATION._load_wannierization_extension!()).SolverCheckpoint
    large = deepcopy(fixture.result)
    large.input_summary["algorithm_profile"] = repeat("sequential-definition-", 10_000)
    expected = IOBuffer()
    solver.write_checkpoint_definition(expected, large; version = :v2_22)
    bytes = take!(expected)
    @test length(bytes) > 3 * 65536
    definition = solver.checkpoint_definition_stream(large; version = :v2_22)
    path = definition.path
    @test isfile(path)
    @test definition.byte_count == length(bytes)
    @test !eof(definition)
    @test_throws ArgumentError read(definition, -1)
    chunks = Vector{UInt8}[]
    while !eof(definition)
        count = min(65536, definition.byte_count - sum(length, chunks; init = 0))
        push!(chunks, read(definition, count))
        @test length(last(chunks)) == count
    end
    @test reduce(vcat, chunks) == bytes
    close(definition)
    @test !isfile(path)
    @test !isopen(definition.stream)

    changed = solver.checkpoint_definition_stream(fixture.result)
    open(changed.path, "a") do stream
        write(stream, UInt8(0))
    end
    @test_throws ArgumentError read(changed, 1)
    @test_throws ArgumentError eof(changed)
    close(changed; retain = true)
    @test isfile(changed.path)
    @test !isopen(changed.stream)
end

# Exercise the exact compiler asset setup helper without running a compiler campaign.
module CheckpointAssetHelperFixture
import WannierNLQG
include(
    joinpath(
        Base.pkgdir(WannierNLQG),
        "ext",
        "WannierNLQGWannierizationExt",
        "PrecompileSupport",
        "TinyWannierWorkflowInputs.jl",
    ),
)
end

@testset "Shipped current checkpoint and independent archived mathematics" begin
    legacy_asset = joinpath(
        @__DIR__,
        "fixtures",
        "first_use_portable",
        "assets",
        "frozen_solver",
        "synthetic.current.wannierization.h5",
    )
    asset =
        joinpath(@__DIR__, "fixtures", "current_checkpoint_workload", "synthetic.wannierization.h5")
    oracle = joinpath(@__DIR__, "fixtures", "checkpoint_numeric_reference.bin")
    expected = read(oracle)
    before = read(asset)
    legacy_before = read(legacy_asset)
    @test !isfile(asset * ".commit.toml")
    @test_throws ArgumentError EXPORT_WANNIERIZATION.read_wannierization_checkpoint_hdf5(asset)
    solver = first(EXPORT_WANNIERIZATION._load_wannierization_extension!()).SolverCheckpoint
    # The historical byte oracle still exercises the complete explicit legacy
    # decoder. It is not relabeled as current wire or optimizer continuation.
    @test_throws ArgumentError EXPORT_WANNIERIZATION.adopt_wannierization_checkpoint_hdf5(
        legacy_asset,
    )
    isdefined(@__MODULE__, :ArchivedCheckpointMathTestSupport) ||
        include(joinpath(@__DIR__, "ArchivedCheckpointMathTestSupport.jl"))
    legacy = ArchivedCheckpointMathTestSupport.read_archived_checkpoint_math(legacy_asset, oracle)
    # Version-specific negative cases: no missing-input legacy record may
    # acquire continuation; no legacy fallback is available to current wire.
    mktempdir() do negative
        function replace_attribute(group, key, value)
            haskey(HDF5.attributes(group), key) && HDF5.delete_attribute(group, key)
            HDF5.attributes(group)[key]=value
        end
        fake_resume=joinpath(negative, "fake-resume.h5");
        cp(legacy_asset, fake_resume)
        HDF5.h5open(fake_resume, "r+") do h
            replace_attribute(h["input_summary"], "restart_eligible", "true")
            @test read(HDF5.attributes(h["input_summary"])["restart_eligible"])=="true"
        end
        failure=try
            solver._read_wannierization_checkpoint_from_source(fake_resume; wire_version = "1.4");
            nothing
        catch error
            error
        end
        @test failure isa ArgumentError
        @test failure!==nothing &&
              occursin("LEGACY_COMPLETE_INPUT_DEFINITIONS_REQUIRED", sprint(showerror, failure))
        bad_formula=joinpath(negative, "bad-formula.h5");
        cp(legacy_asset, bad_formula)
        HDF5.h5open(bad_formula, "r+") do h
            replace_attribute(
                h["tb_symmetry_qualification"],
                "target_leakage_formula_sha256",
                repeat("0", 64),
            )
            @test read(
                HDF5.attributes(h["tb_symmetry_qualification"])["target_leakage_formula_sha256"],
            )==repeat("0", 64)
        end
        failure=try
            solver._read_wannierization_checkpoint_from_source(bad_formula; wire_version = "1.4");
            nothing
        catch error
            error
        end
        @test failure isa ArgumentError
        @test failure!==nothing &&
              occursin("UNSUPPORTED_LEGACY_TARGET_LEAKAGE_SEMANTICS", sprint(showerror, failure))
        current_missing=joinpath(negative, "current-missing.h5");
        cp(asset, current_missing)
        HDF5.h5open(current_missing, "r+") do h
            @test read(HDF5.attributes(h)["schema_version"])=="3.0"
            for group in (h, h["input_summary"])
                HDF5.delete_attribute(group, "disentanglement_outer_mask_definition")
                @test !haskey(HDF5.attributes(group), "disentanglement_outer_mask_definition")
            end
        end
        failure=try
            EXPORT_WANNIERIZATION.adopt_wannierization_checkpoint_hdf5(current_missing);
            nothing
        catch error
            error
        end
        @test failure isa ArgumentError
        @test failure!==nothing &&
              occursin("disentanglement_outer_mask_definition", sprint(showerror, failure))
        @test !isfile(current_missing*".commit.toml")
    end
    mktempdir() do workspace
        restored = CheckpointAssetHelperFixture.read_current_checkpoint_asset(asset, workspace)
        @test isfile(joinpath(workspace, "asset-checkpoint.commit.toml"))
        @test restored.input_summary["checkpoint_schema_version"] == "3.0"
        @test restored.input_summary["restart_eligible"] == "false"
        @test restored.input_summary["restart_input_definition_status"] == "NOT_RECORDED"
        @test size(restored.v_matrix) == (2, 1, 2)
        @test all(isfinite, restored.v_matrix)
        @test maximum(abs, restored.v_matrix) > 0
        bytes = IOBuffer()
        solver.write_checkpoint_definition(bytes, restored; version = :v2_29)
        current_definition = take!(bytes)
        @test !isempty(current_definition)
        # Legacy accepted numbers were independently checked above. A current
        # calculation is a distinct producer; persistence is compared to that
        # producer, never to the historical AMN phase/spread.
        @test all(isfinite, restored.v_matrix)
        @test all(isfinite, restored.wannier_centers_cartesian)
        @test all(isfinite, restored.spreads_angstrom2)
        ArchivedCheckpointMathTestSupport.assert_current_checkpoint_math(
            restored,
            joinpath(
                @__DIR__,
                "fixtures",
                "current_checkpoint_workload",
                "SOLUTION_REFERENCE.json",
            ),
        )
        GC.gc()
        again = EXPORT_WANNIERIZATION.read_wannierization_checkpoint_hdf5(
            asset;
            receipt_path = joinpath(workspace, "asset-checkpoint.commit.toml"),
        )
        bytes = IOBuffer()
        solver.write_checkpoint_definition(bytes, again; version = :v2_29)
        @test take!(bytes) == current_definition
        @test again.v_matrix == restored.v_matrix
        @test again.wannier_centers_cartesian == restored.wannier_centers_cartesian
        @test again.spreads_angstrom2 == restored.spreads_angstrom2
    end
    @test read(asset) == before
    @test read(legacy_asset) == legacy_before
    @test !isfile(legacy_asset * ".commit.toml")
    @test !isfile(asset * ".commit.toml")
end
