isdefined(@__MODULE__, :InternalSolverFixture) ||
    include(joinpath(@__DIR__, "support", "InternalSolverFixture.jl"))
using LinearAlgebra
using Test
using WannierNLQG

const PROJECTION_MATERIAL_W = WannierNLQG.Wannierization
const PROJECTION_MATERIAL_S = WannierNLQG.Symmetrization
const PROJECTION_MATERIAL_EXT =
    first(PROJECTION_MATERIAL_W._load_wannierization_extension!()).ProjectionSearch

if !isdefined(@__MODULE__, :projection_materialization_fixture)
    include(joinpath(@__DIR__, "support", "ProjectionSearchFixtureSupport.jl"))
end

function projection_result_with_solution(result, solution)
    provisional = PROJECTION_MATERIAL_W.ProjectionRepresentationSearchResult(
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
    return provisional
end

function projection_result_with_validation(result, validation_status)
    original = only(result.solutions)
    residuals = if validation_status == PROJECTION_MATERIAL_W.PROJECTION_VALIDATION_NOT_RUN
        Dict{String, Float64}()
    else
        Dict("frozen_to_target" => 1.0e-7, "target_to_outer" => 1.0e-7)
    end
    solution = PROJECTION_MATERIAL_W.ProjectionRepresentationSolution(
        original.candidate_ids,
        original.coefficients,
        original.total_dimension,
        original.nonzero_candidate_types,
        original.total_block_multiplicity,
        original.signature_multiplicities,
        validation_status,
        residuals,
    )
    return projection_result_with_solution(result, solution)
end

@testset "projection basis and SAWF config materialization" begin
    fixture = projection_materialization_fixture()
    @test only(fixture.result.solutions).validation_status ==
          PROJECTION_MATERIAL_W.PROJECTION_VALIDATION_PASSED
    basis = PROJECTION_MATERIAL_W.materialize_projection_basis(fixture.result)
    @test basis.num_wannier == 1
    @test !basis.spinor
    @test only(basis.blocks).indices == ones(Int, 1, 1)

    materialized = PROJECTION_MATERIAL_W.materialize_symmetry_adapted_wannierization_config(
        fixture.template,
        fixture.result,
    )
    @test materialized.input.projection_basis.num_wannier == basis.num_wannier
    @test materialized.input.projection_basis.spinor == basis.spinor
    @test only(materialized.input.projection_basis.blocks).indices == only(basis.blocks).indices
    for name in fieldnames(PROJECTION_MATERIAL_W.WannierizationInputConfig)
        name == :projection_basis && continue
        @test isequal(getfield(materialized.input, name), getfield(fixture.template.input, name))
    end
    for name in (:solver, :checkpoint, :runtime, :output)
        @test isequal(getfield(materialized, name), getfield(fixture.template, name))
    end
end

@testset "projection materialization fails closed" begin
    fixture = projection_materialization_fixture()
    incomplete = PROJECTION_MATERIAL_W.ProjectionRepresentationSearchResult(
        PROJECTION_MATERIAL_W.PROJECTION_SEARCH_LIMIT_REACHED,
        false,
        fixture.result.representation_definition,
        fixture.result.contract_definition,
        fixture.result.algorithm_info,
        fixture.result.spinor,
        fixture.result.num_wannier,
        fixture.result.outer_mask_definition,
        fixture.result.frozen_mask_definition,
        fixture.result.candidates,
        fixture.result.radial_transform,
        fixture.result.visited_nodes,
        fixture.result.total_solution_count,
        fixture.result.truncated,
        fixture.result.signatures,
        fixture.result.solutions,
        fixture.result.diagnostics,
    )
    @test_throws ArgumentError PROJECTION_MATERIAL_W.materialize_projection_basis(incomplete)

    for status in (
        PROJECTION_MATERIAL_W.PROJECTION_VALIDATION_NOT_RUN,
        PROJECTION_MATERIAL_W.PROJECTION_VALIDATION_FAILED,
        PROJECTION_MATERIAL_W.PROJECTION_VALIDATION_NUMERICAL_UNCERTAIN,
    )
        result = projection_result_with_validation(fixture.result, status)
        @test_throws ArgumentError PROJECTION_MATERIAL_W.materialize_projection_basis(result)
    end

    original = only(fixture.result.solutions)
    invalid_solution = PROJECTION_MATERIAL_W.ProjectionRepresentationSolution(
        original.candidate_ids,
        original.coefficients .+ 1,
        original.total_dimension,
        original.nonzero_candidate_types,
        original.total_block_multiplicity,
        original.signature_multiplicities,
        PROJECTION_MATERIAL_W.PROJECTION_VALIDATION_PASSED,
        original.embedding_residuals,
    )
    self_consistent_payload = projection_result_with_solution(fixture.result, invalid_solution)
    @test !hasproperty(self_consistent_payload, :payload_sha256)
    @test_throws ArgumentError PROJECTION_MATERIAL_W.materialize_projection_basis(
        self_consistent_payload,
    )

    mismatched_template = PROJECTION_MATERIAL_W.WannierizationConfig(
        input = PROJECTION_MATERIAL_W.WannierizationInputConfig(
            wannierization_mode = :symmetry_adapted,
            win_file = "synthetic.win",
            eig_file = "synthetic.eig",
            mmn_file = "synthetic.mmn",
            band_representation = fixture.representation,
            num_wannier = 1,
            outer_min_ev = -2.0,
            outer_max_ev = 2.0,
            frozen_min_ev = 0.5,
            frozen_max_ev = 1.0,
        ),
        solver = InternalSolverFixture.solver_config(),
        checkpoint = PROJECTION_MATERIAL_W.WannierizationCheckpointConfig(),
        runtime = PROJECTION_MATERIAL_W.WannierizationRuntimeConfig(),
        output = PROJECTION_MATERIAL_W.WannierizationOutputConfig(),
    )
    @test_throws ArgumentError PROJECTION_MATERIAL_W.materialize_symmetry_adapted_wannierization_config(
        mismatched_template,
        fixture.result,
    )
end
