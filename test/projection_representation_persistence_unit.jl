using HDF5
using Test
using WannierNLQG

const PROJECTION_PERSIST_W = WannierNLQG.Wannierization
const PROJECTION_PERSIST_S = WannierNLQG.Symmetrization
const PROJECTION_PERSIST_EXT =
    first(PROJECTION_PERSIST_W._load_wannierization_extension!()).ProjectionSearch

if !isdefined(@__MODULE__, :projection_materialization_fixture)
    include(joinpath(@__DIR__, "support", "ProjectionSearchFixtureSupport.jl"))
end

# Reuse the real tiny search's complete definitions. Requested validation states
# below are codec cases; changing a label does not certify embedding quality.
function synthetic_projection_search_result(;
    validation_status = PROJECTION_PERSIST_W.PROJECTION_VALIDATION_PASSED,
    residuals = Dict("frozen_to_target" => 0.0, "target_to_outer" => 0.0),
)
    result = projection_materialization_fixture().result
    original = only(result.solutions)
    solution = PROJECTION_PERSIST_W.ProjectionRepresentationSolution(
        original.candidate_ids,
        original.coefficients,
        original.total_dimension,
        original.nonzero_candidate_types,
        original.total_block_multiplicity,
        original.signature_multiplicities,
        validation_status,
        Dict{String, Float64}(residuals),
    )
    return PROJECTION_PERSIST_W.ProjectionRepresentationSearchResult(
        result.status,
        result.complete,
        result.representation_definition,
        result.contract_definition,
        result.algorithm_info,
        result.spinor,
        result.num_wannier,
        result.outer_mask_definition,
        result.frozen_mask_definition,
        result.candidates,
        result.radial_transform,
        result.visited_nodes,
        result.total_solution_count,
        result.truncated,
        result.signatures,
        [solution],
        result.diagnostics,
    )
end

# Rebuild one result with selected compatibility, spin, and solution fields.
function projection_result_with_changes(
    result;
    complete = result.complete,
    algorithm_info = result.algorithm_info,
    spinor = result.spinor,
    solutions = result.solutions,
)
    return PROJECTION_PERSIST_W.ProjectionRepresentationSearchResult(
        result.status,
        complete,
        result.representation_definition,
        result.contract_definition,
        algorithm_info,
        spinor,
        result.num_wannier,
        result.outer_mask_definition,
        result.frozen_mask_definition,
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
    embedding_residuals = solution.embedding_residuals,
)
    return PROJECTION_PERSIST_W.ProjectionRepresentationSolution(
        solution.candidate_ids,
        solution.coefficients,
        solution.total_dimension,
        nonzero_candidate_types,
        solution.total_block_multiplicity,
        solution.signature_multiplicities,
        solution.validation_status,
        embedding_residuals,
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

@testset "projection-representation digest-only 2.1 requires explicit regeneration" begin
    legacy_path = joinpath(@__DIR__, "fixtures", "schema_compatibility", "projection_search_2_1.h5")
    @test bytes2hex(PROJECTION_PERSIST_EXT.SHA.sha256(read(legacy_path))) ==
          "f63aad96e8ded08a5b607b303c9a009a5c8c90c17175039ba22ddaacece67b1e"
    @test_throws ArgumentError PROJECTION_PERSIST_W.read_projection_representation_search_hdf5(
        legacy_path,
    )
end

@testset "projection-representation schema-1.0 HDF5 and canonical JSON" begin
    result = synthetic_projection_search_result()
    mktempdir() do directory
        hdf5_path = joinpath(directory, "search.h5")
        json_a = joinpath(directory, "search-a.json")
        json_b = joinpath(directory, "search-b.json")
        PROJECTION_PERSIST_W.write_projection_representation_search_hdf5(hdf5_path, result)
        roundtrip = PROJECTION_PERSIST_W.read_projection_representation_search_hdf5(hdf5_path)

        @test PROJECTION_PERSIST_EXT._projection_search_payload_json(roundtrip) ==
              PROJECTION_PERSIST_EXT._projection_search_payload_json(result)
        @test roundtrip.algorithm_info.algorithm_contract_sha256 ==
              result.algorithm_info.algorithm_contract_sha256
        @test roundtrip.algorithm_info.canonical_reduction_eligible
        @test only(roundtrip.solutions).candidate_ids == only(result.solutions).candidate_ids
        @test only(roundtrip.solutions).coefficients == only(result.solutions).coefficients
        @test only(roundtrip.solutions).validation_status ==
              PROJECTION_PERSIST_W.PROJECTION_VALIDATION_PASSED
        @test only(roundtrip.solutions).embedding_residuals ==
              only(result.solutions).embedding_residuals
        @test roundtrip.candidates[1].specs[1].positions_fractional == zeros(3, 1)
        HDF5.h5open(hdf5_path, "r") do handle
            @test String(read(HDF5.attributes(handle)["schema_version"])) == "4.0"
            @test haskey(handle, "algorithm")
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
    info = result.algorithm_info
    wrong_profile = PROJECTION_PERSIST_W.ProjectionRepresentationAlgorithmInfo(
        info.algorithm_name,
        "1.7.1",
        info.algorithm_contract_sha256,
        info.implementation_sha256,
        info.canonical_reduction_eligible,
        info.scope,
        info.character_tolerance,
        info.character_round_digits,
        info.little_group_tolerance,
    )
    inconsistent_scope = PROJECTION_PERSIST_W.ProjectionRepresentationAlgorithmInfo(
        info.algorithm_name,
        info.algorithm_version,
        info.algorithm_contract_sha256,
        info.implementation_sha256,
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
        embedding_residuals = Dict("residual" => Inf),
    )
    invalid_results = (
        projection_result_with_changes(result; algorithm_info = wrong_profile),
        projection_result_with_changes(result; algorithm_info = inconsistent_scope),
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
            `$(Base.julia_cmd()) --startup-file=no --threads=1 --project=$(project_root) $(probe) projection-search-readback $(path) $(PROJECTION_PERSIST_EXT._projection_search_payload_json(result))`
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
    stale = projection_result_with_changes(result; complete = false)
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

# Deliberately invalid current copies test version admission; they are not archived assets.
@testset "projection-representation unsupported version headers fail before decoding" begin
    result = synthetic_projection_search_result()
    for unsupported_version in ("1.0", "2.0", "3.0", "5.0")
        mktempdir() do directory
            path = joinpath(directory, "unsupported-version.h5")
            PROJECTION_PERSIST_W.write_projection_representation_search_hdf5(path, result)
            canonical_before = HDF5.h5open(path, "r+") do handle
                attribute = HDF5.attributes(handle)["schema_version"]
                try
                    @test String(read(attribute)) == "4.0"
                    write(attribute, unsupported_version)
                finally
                    close(attribute)
                end
                String(read(handle["canonical_payload_json"]))
            end
            # Reopen the file so the consumer sees the actual persisted mutation.
            HDF5.h5open(path, "r") do handle
                @test String(read(HDF5.attributes(handle)["schema"])) ==
                      "WannierNLQG.projection_representation_search"
                @test String(read(HDF5.attributes(handle)["schema_version"])) == unsupported_version
                @test String(read(handle["canonical_payload_json"])) == canonical_before
            end
            error = try
                PROJECTION_PERSIST_W.read_projection_representation_search_hdf5(path)
                nothing
            catch caught
                caught
            end
            @test error isa ArgumentError
            @test sprint(showerror, error) ==
                  "ArgumentError: unsupported projection search schema version: $(unsupported_version); expected 4.0"
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
    )
    nonfinite_result = PROJECTION_PERSIST_W.ProjectionRepresentationSearchResult(
        result.status,
        result.complete,
        result.representation_definition,
        result.contract_definition,
        result.algorithm_info,
        result.spinor,
        result.num_wannier,
        result.outer_mask_definition,
        result.frozen_mask_definition,
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
