using HDF5
using Test
using WannierNLQG

const PROJECTION_PERSIST_W = WannierNLQG.Wannierization
const PROJECTION_PERSIST_S = WannierNLQG.Symmetrization
const PROJECTION_PERSIST_EXT =
    first(PROJECTION_PERSIST_W._load_wannierization_extension!()).ProjectionSearch

# Construct one sealed result with a single retained scalar projection.
function synthetic_projection_search_result(;
    validation_status = PROJECTION_PERSIST_W.PROJECTION_VALIDATION_PASSED,
    residuals = Dict("frozen_to_target" => 0.0, "target_to_outer" => 0.0),
)
    spec = WannierNLQG.WannierProjection.ProjectionSpec(
        selector = "X",
        orbital_sets = "s",
        positions = zeros(3, 1),
    )
    candidate = PROJECTION_PERSIST_W.ProjectionCandidateSpec(id = "X:s", specs = [spec])
    compatibility = PROJECTION_PERSIST_W.ProjectionRepresentationCompatibilityInfo(
        "WannierBerri",
        "1.7.0",
        "50265d5d1cef184f8377f87ed691c8d9a2f6cdbf",
        "8552e056b568860c4c7dbd868e997fe4e9e6fb4a0349b182665aee2c8330d5c2",
        true,
        :spinless_unitary,
        1.0e-3,
        3,
        1.0e-5,
    )
    signature =
        PROJECTION_PERSIST_W.ProjectionRepresentationSignature(1, ["A"], [1], [:unitary], [1], [1])
    residual_values = Dict{String, Float64}(residuals)
    validation_sha256 = Base.invokelatest(
        PROJECTION_PERSIST_EXT._projection_solution_validation_sha256,
        ["X:s"],
        [1],
        validation_status,
        residual_values,
    )
    solution = PROJECTION_PERSIST_W.ProjectionRepresentationSolution(
        ["X:s"],
        [1],
        1,
        1,
        1,
        [[1]],
        validation_status,
        residual_values,
        validation_sha256,
    )
    provisional = PROJECTION_PERSIST_W.ProjectionRepresentationSearchResult(
        PROJECTION_PERSIST_W.PROJECTION_SEARCH_COMPLETE,
        true,
        repeat("4", 64),
        repeat("5", 64),
        compatibility,
        repeat("6", 64),
        "",
        false,
        1,
        repeat("7", 64),
        repeat("8", 64),
        [candidate],
        WannierNLQG.WannierProjection.ProjectionRadialTransformConfig(),
        3,
        1,
        false,
        [signature],
        [solution],
        ["synthetic persistence fixture"],
    )
    return Base.invokelatest(PROJECTION_PERSIST_EXT._projection_seal_search_result, provisional)
end

# Rebuild one result with a deliberately supplied payload identity.
function projection_result_with_payload(result, payload_sha256)
    return PROJECTION_PERSIST_W.ProjectionRepresentationSearchResult(
        result.status,
        result.complete,
        result.representation_sha256,
        result.contract_sha256,
        result.compatibility_info,
        result.config_sha256,
        payload_sha256,
        result.spinor,
        result.num_wannier,
        result.outer_mask_sha256,
        result.frozen_mask_sha256,
        result.candidates,
        result.radial_transform,
        result.visited_nodes,
        result.total_solution_count,
        result.truncated,
        result.signatures,
        result.solutions,
        result.diagnostics,
    )
end

# Rebuild one result with selected compatibility, spin, and solution fields.
function projection_result_with_changes(
    result;
    compatibility_info = result.compatibility_info,
    spinor = result.spinor,
    solutions = result.solutions,
)
    return PROJECTION_PERSIST_W.ProjectionRepresentationSearchResult(
        result.status,
        result.complete,
        result.representation_sha256,
        result.contract_sha256,
        compatibility_info,
        result.config_sha256,
        "",
        spinor,
        result.num_wannier,
        result.outer_mask_sha256,
        result.frozen_mask_sha256,
        result.candidates,
        result.radial_transform,
        result.visited_nodes,
        result.total_solution_count,
        result.truncated,
        result.signatures,
        solutions,
        result.diagnostics,
    )
end

# Rebuild one solution with selected derived and validation fields.
function projection_solution_with_changes(
    solution;
    nonzero_candidate_types = solution.nonzero_candidate_types,
    validation_sha256 = solution.validation_sha256,
)
    return PROJECTION_PERSIST_W.ProjectionRepresentationSolution(
        solution.candidate_ids,
        solution.coefficients,
        solution.total_dimension,
        nonzero_candidate_types,
        solution.total_block_multiplicity,
        solution.signature_multiplicities,
        solution.validation_status,
        solution.embedding_residuals,
        validation_sha256,
    )
end

# Inventory every typed dataset and attribute, including the original digest strings.
function projection_persistence_inventory(object, path = "")
    rows = Dict{String, Any}()
    for key in keys(HDF5.attributes(object))
        rows[path * "@" * key] = read(HDF5.attributes(object)[key])
    end
    if object isa HDF5.Dataset
        data = read(object)
        rows[path * "#type"] = string(typeof(data))
        rows[path * "#shape"] = data isa AbstractArray ? size(data) : ()
        rows[path * "#value"] = data
        if data isa AbstractArray{<:Number}
            rows[path * "#bytes"] = collect(reinterpret(UInt8, vec(data)))
        end
    else
        for key in keys(object)
            merge!(rows, projection_persistence_inventory(object[key], path * "/" * key))
        end
    end
    return rows
end

@testset "projection-representation original 2.1 migration preserves full content" begin
    legacy_path = joinpath(@__DIR__, "fixtures", "schema_compatibility", "projection_search_2_1.h5")
    @test bytes2hex(PROJECTION_PERSIST_EXT.SHA.sha256(read(legacy_path))) ==
          "44f9af72b868398e392e98ec85e038f315344f59c757ec29eba1dace43353d7d"
    legacy = PROJECTION_PERSIST_W.read_projection_representation_search_hdf5(legacy_path)
    mktempdir() do directory
        path = joinpath(directory, "search-1.0.h5")
        PROJECTION_PERSIST_W.write_projection_representation_search_hdf5(path, legacy)
        restored = PROJECTION_PERSIST_W.read_projection_representation_search_hdf5(path)
        @test restored.payload_sha256 == legacy.payload_sha256
        old_rows = HDF5.h5open(projection_persistence_inventory, legacy_path, "r")
        new_rows = HDF5.h5open(projection_persistence_inventory, path, "r")
        @test keys(old_rows) == keys(new_rows)
        @test sort!([key for key in keys(old_rows) if !isequal(old_rows[key], new_rows[key])]) == ["@schema_version"]
        # Wire 1.0 is an alias for the complete 2.1 contract. A complete historical
        # payload with that label is valid, unlike the actual historical 1.0 layout.
        cp(legacy_path, path; force = true)
        HDF5.h5open(path, "r+") do handle
            write(HDF5.attributes(handle)["schema_version"], "1.0")
        end
        @test PROJECTION_PERSIST_W.read_projection_representation_search_hdf5(path).payload_sha256 ==
              legacy.payload_sha256
    end
end

@testset "projection-representation schema-1.0 HDF5 and canonical JSON" begin
    result = synthetic_projection_search_result()
    mktempdir() do directory
        hdf5_path = joinpath(directory, "search.h5")
        json_a = joinpath(directory, "search-a.json")
        json_b = joinpath(directory, "search-b.json")
        PROJECTION_PERSIST_W.write_projection_representation_search_hdf5(hdf5_path, result)
        roundtrip = PROJECTION_PERSIST_W.read_projection_representation_search_hdf5(hdf5_path)

        @test roundtrip.payload_sha256 == result.payload_sha256
        @test roundtrip.compatibility_info.upstream_commit ==
              result.compatibility_info.upstream_commit
        @test roundtrip.compatibility_info.parity_eligible
        @test only(roundtrip.solutions).candidate_ids == only(result.solutions).candidate_ids
        @test only(roundtrip.solutions).coefficients == only(result.solutions).coefficients
        @test only(roundtrip.solutions).validation_status ==
              PROJECTION_PERSIST_W.PROJECTION_VALIDATION_PASSED
        @test only(roundtrip.solutions).validation_sha256 ==
              only(result.solutions).validation_sha256
        @test roundtrip.candidates[1].specs[1].positions_fractional == zeros(3, 1)
        HDF5.h5open(hdf5_path, "r") do handle
            @test String(read(HDF5.attributes(handle)["schema_version"])) == "1.0"
            @test haskey(handle, "compatibility")
            @test String(read(HDF5.attributes(handle["solutions/000001"])["validation_status"])) ==
                  "PROJECTION_VALIDATION_PASSED"
        end

        Base.invokelatest(
            PROJECTION_PERSIST_EXT._write_projection_representation_search_json,
            json_a,
            result,
        )
        Base.invokelatest(
            PROJECTION_PERSIST_EXT._write_projection_representation_search_json,
            json_b,
            result,
        )
        @test read(json_a) == read(json_b)
    end
end

@testset "projection-representation validation states roundtrip" begin
    for status in (
        PROJECTION_PERSIST_W.PROJECTION_VALIDATION_NOT_RUN,
        PROJECTION_PERSIST_W.PROJECTION_VALIDATION_PASSED,
        PROJECTION_PERSIST_W.PROJECTION_VALIDATION_FAILED,
        PROJECTION_PERSIST_W.PROJECTION_VALIDATION_NUMERICAL_UNCERTAIN,
    )
        residuals =
            status == PROJECTION_PERSIST_W.PROJECTION_VALIDATION_NOT_RUN ? Dict{String, Float64}() :
            Dict("residual" => 1.0e-12)
        result =
            synthetic_projection_search_result(validation_status = status, residuals = residuals)
        mktempdir() do directory
            path = joinpath(directory, "validation-state.h5")
            PROJECTION_PERSIST_W.write_projection_representation_search_hdf5(path, result)
            roundtrip = PROJECTION_PERSIST_W.read_projection_representation_search_hdf5(path)
            @test only(roundtrip.solutions).validation_status == status
            @test only(roundtrip.solutions).embedding_residuals == residuals
        end
    end
end

@testset "projection-representation pinned compatibility and derived invariants" begin
    result = synthetic_projection_search_result()
    info = result.compatibility_info
    wrong_profile = PROJECTION_PERSIST_W.ProjectionRepresentationCompatibilityInfo(
        info.upstream_package,
        "1.7.1",
        info.upstream_commit,
        info.upstream_source_sha256,
        info.parity_eligible,
        info.scope,
        info.character_tolerance,
        info.character_round_digits,
        info.little_group_tolerance,
    )
    inconsistent_scope = PROJECTION_PERSIST_W.ProjectionRepresentationCompatibilityInfo(
        info.upstream_package,
        info.upstream_version,
        info.upstream_commit,
        info.upstream_source_sha256,
        false,
        :spinless_unitary,
        info.character_tolerance,
        info.character_round_digits,
        info.little_group_tolerance,
    )
    wrong_count_solution =
        projection_solution_with_changes(only(result.solutions); nonzero_candidate_types = 0)
    wrong_sha_solution = projection_solution_with_changes(
        only(result.solutions);
        validation_sha256 = repeat("0", 64),
    )
    invalid_results = (
        projection_result_with_changes(result; compatibility_info = wrong_profile),
        projection_result_with_changes(result; compatibility_info = inconsistent_scope),
        projection_result_with_changes(result; spinor = true),
        projection_result_with_changes(result; solutions = [wrong_count_solution]),
        projection_result_with_changes(result; solutions = [wrong_sha_solution]),
    )
    mktempdir() do directory
        for (index, invalid_result) in enumerate(invalid_results)
            @test_throws ArgumentError PROJECTION_PERSIST_W.write_projection_representation_search_hdf5(
                joinpath(directory, "invalid-$(index).h5"),
                invalid_result,
            )
        end
    end
end

@testset "projection-representation fresh-process readback" begin
    result = synthetic_projection_search_result()
    mktempdir() do directory
        path = joinpath(directory, "fresh-process.h5")
        PROJECTION_PERSIST_W.write_projection_representation_search_hdf5(path, result)
        probe = joinpath(@__DIR__, "WannierizationFreshProcessProbe.jl")
        project_root = dirname(@__DIR__)
        command =
            `$(Base.julia_cmd()) --startup-file=no --threads=1 --project=$(project_root) $(probe) projection-search-readback $(path) $(result.payload_sha256)`
        output = read(
            addenv(
                command,
                "OMP_NUM_THREADS" => "1",
                "MKL_NUM_THREADS" => "1",
                "OPENBLAS_NUM_THREADS" => "1",
                "VECLIB_MAXIMUM_THREADS" => "1",
            ),
            String,
        )
        @test occursin("PROJECTION_SEARCH_FRESH_PROCESS_PASS", output)
    end
end

@testset "projection-representation stale and tampered artifacts fail closed" begin
    result = synthetic_projection_search_result()
    stale = projection_result_with_payload(result, repeat("0", 64))
    mktempdir() do directory
        @test_throws ArgumentError PROJECTION_PERSIST_W.write_projection_representation_search_hdf5(
            joinpath(directory, "stale.h5"),
            stale,
        )

        typed_path = joinpath(directory, "typed-tamper.h5")
        PROJECTION_PERSIST_W.write_projection_representation_search_hdf5(typed_path, result)
        HDF5.h5open(typed_path, "r+") do handle
            handle["solutions/000001/coefficients"][:] = [2]
        end
        @test_throws ArgumentError PROJECTION_PERSIST_W.read_projection_representation_search_hdf5(
            typed_path,
        )

        json_path = joinpath(directory, "json-tamper.h5")
        PROJECTION_PERSIST_W.write_projection_representation_search_hdf5(json_path, result)
        HDF5.h5open(json_path, "r+") do handle
            payload = String(read(handle["canonical_payload_json"]))
            altered = replace(payload, "\"complete\":true" => "\"complete\":fals"; count = 1)
            write(handle["canonical_payload_json"], altered)
        end
        @test_throws ArgumentError PROJECTION_PERSIST_W.read_projection_representation_search_hdf5(
            json_path,
        )

        validation_path = joinpath(directory, "validation-tamper.h5")
        PROJECTION_PERSIST_W.write_projection_representation_search_hdf5(validation_path, result)
        HDF5.h5open(validation_path, "r+") do handle
            write(
                HDF5.attributes(handle["solutions/000001"])["validation_status"],
                "PROJECTION_VALIDATION_FAILED",
            )
        end
        @test_throws ArgumentError PROJECTION_PERSIST_W.read_projection_representation_search_hdf5(
            validation_path,
        )
    end
end

@testset "projection-representation legacy schema-1.0/2.0 artifacts are rejected" begin
    result = synthetic_projection_search_result()
    for old_version in ("1.0", "2.0")
        mktempdir() do directory
            path = joinpath(directory, "old-schema.h5")
            PROJECTION_PERSIST_W.write_projection_representation_search_hdf5(path, result)
            HDF5.h5open(path, "r+") do handle
                write(HDF5.attributes(handle)["schema_version"], old_version)
                old_version == "1.0" && HDF5.delete_attribute(handle, "mirror_sha256")
            end
            error = try
                PROJECTION_PERSIST_W.read_projection_representation_search_hdf5(path)
                nothing
            catch caught
                caught
            end
            @test error isa ArgumentError
            @test occursin("schema version $(old_version) is unsupported", sprint(showerror, error))
            @test occursin("regenerate", sprint(showerror, error))
        end
    end
end

@testset "projection-representation writer rejects nonfinite validation evidence" begin
    result = synthetic_projection_search_result()
    solution = only(result.solutions)
    nonfinite_solution = PROJECTION_PERSIST_W.ProjectionRepresentationSolution(
        solution.candidate_ids,
        solution.coefficients,
        solution.total_dimension,
        solution.nonzero_candidate_types,
        solution.total_block_multiplicity,
        solution.signature_multiplicities,
        solution.validation_status,
        Dict("residual" => Inf),
        solution.validation_sha256,
    )
    nonfinite_result = PROJECTION_PERSIST_W.ProjectionRepresentationSearchResult(
        result.status,
        result.complete,
        result.representation_sha256,
        result.contract_sha256,
        result.compatibility_info,
        result.config_sha256,
        "",
        result.spinor,
        result.num_wannier,
        result.outer_mask_sha256,
        result.frozen_mask_sha256,
        result.candidates,
        result.radial_transform,
        result.visited_nodes,
        result.total_solution_count,
        result.truncated,
        result.signatures,
        [nonfinite_solution],
        result.diagnostics,
    )
    mktempdir() do directory
        @test_throws ArgumentError PROJECTION_PERSIST_W.write_projection_representation_search_hdf5(
            joinpath(directory, "nonfinite.h5"),
            nonfinite_result,
        )
    end
end
