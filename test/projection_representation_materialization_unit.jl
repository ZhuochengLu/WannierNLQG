using LinearAlgebra
using Test
using WannierNLQG

const PROJECTION_MATERIAL_W = WannierNLQG.Wannierization
const PROJECTION_MATERIAL_S = WannierNLQG.Symmetrization
const PROJECTION_MATERIAL_EXT =
    first(PROJECTION_MATERIAL_W._load_wannierization_extension!()).ProjectionSearch

function projection_materialization_fixture()
    scope = WannierNLQG.SymmetryFoundation.BandRepresentationQualificationScope(
        trues(1, 1),
        trues(1, 1),
    )
    contract = PROJECTION_MATERIAL_W.TargetSubspaceQualificationContract(
        scope;
        outer_min_ev = -2.0,
        outer_max_ev = 2.0,
        frozen_min_ev = -2.0,
        frozen_max_ev = 0.0,
        num_wannier = 1,
    )
    operation = WannierNLQG.SymmetryFoundation.SymmetryOperation(
        Matrix{Int}(I, 3, 3),
        zeros(3),
        Matrix{Float64}(I, 3, 3),
    )
    representation = WannierNLQG.SymmetryFoundation.BandRepresentation(
        "1.17",
        :synthetic,
        false,
        Matrix{Float64}(I, 3, 3),
        2.0pi .* Matrix{Float64}(I, 3, 3),
        (1, 1, 1),
        zeros(1, 3),
        reshape([-1.0], 1, 1),
        [operation],
        ones(Int, 1, 1),
        zeros(Int, 3, 1, 1),
        ones(ComplexF64, 1, 1, 1, 1),
        ones(Int, 1, 1),
        [1],
        [1],
        [1];
        conventions = Dict(
            "target_subspace_contract_sha256" => contract.contract_sha256,
            "outer_mask_sha256" => scope.outer_mask_sha256,
            "frozen_mask_sha256" => scope.frozen_mask_sha256,
        ),
        input_sha256 = Dict("TARGET_SUBSPACE_CONTRACT_SHA256" => contract.contract_sha256),
    )
    spec = WannierNLQG.WannierProjection.ProjectionSpec(
        selector = "X",
        orbital_sets = "s",
        positions = zeros(3, 1),
    )
    candidate = PROJECTION_MATERIAL_W.ProjectionCandidateSpec(
        id = "X:s",
        specs = [spec],
        fixed_multiplicity = 1,
        max_multiplicity = 1,
    )
    config = PROJECTION_MATERIAL_W.ProjectionRepresentationSearchConfig(
        band_representation = representation,
        target_subspace_contract = contract,
        candidates = [candidate],
    )
    result = PROJECTION_MATERIAL_W.search_projection_representations(config)
    result.complete || error("synthetic materialization search did not complete")
    template = PROJECTION_MATERIAL_W.SymmetryAdaptedWannierizationConfig(
        input = PROJECTION_MATERIAL_W.WannierizationInputConfig(
            wannierization_mode = :symmetry_adapted,
            win_file = "synthetic.win",
            eig_file = "synthetic.eig",
            mmn_file = "synthetic.mmn",
            band_representation = representation,
            num_wannier = 1,
            outer_min_ev = -2.0,
            outer_max_ev = 2.0,
            frozen_min_ev = -2.0,
            frozen_max_ev = 0.0,
        ),
        solver = PROJECTION_MATERIAL_W.WannierizationSolverConfig(),
        checkpoint = PROJECTION_MATERIAL_W.WannierizationCheckpointConfig(),
        runtime = PROJECTION_MATERIAL_W.WannierizationRuntimeConfig(),
        output = PROJECTION_MATERIAL_W.WannierizationOutputConfig(),
    )
    return (; scope, contract, representation, result, template)
end

function projection_result_with_solution(result, solution)
    provisional = PROJECTION_MATERIAL_W.ProjectionRepresentationSearchResult(
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
        [solution],
        result.diagnostics,
    )
    return Base.invokelatest(PROJECTION_MATERIAL_EXT._projection_seal_search_result, provisional)
end

function projection_result_with_validation(result, validation_status)
    original = only(result.solutions)
    residuals = if validation_status == PROJECTION_MATERIAL_W.PROJECTION_VALIDATION_NOT_RUN
        Dict{String, Float64}()
    else
        Dict("frozen_to_target" => 1.0e-7, "target_to_outer" => 1.0e-7)
    end
    validation_sha = Base.invokelatest(
        PROJECTION_MATERIAL_EXT._projection_solution_validation_sha256,
        original.candidate_ids,
        original.coefficients,
        validation_status,
        residuals,
    )
    solution = PROJECTION_MATERIAL_W.ProjectionRepresentationSolution(
        original.candidate_ids,
        original.coefficients,
        original.total_dimension,
        original.nonzero_candidate_types,
        original.total_block_multiplicity,
        original.signature_multiplicities,
        validation_status,
        residuals,
        validation_sha,
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
        fixture.result.representation_sha256,
        fixture.result.contract_sha256,
        fixture.result.compatibility_info,
        fixture.result.config_sha256,
        fixture.result.payload_sha256,
        fixture.result.spinor,
        fixture.result.num_wannier,
        fixture.result.outer_mask_sha256,
        fixture.result.frozen_mask_sha256,
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
        original.coefficients,
        original.total_dimension,
        original.nonzero_candidate_types,
        original.total_block_multiplicity,
        original.signature_multiplicities,
        PROJECTION_MATERIAL_W.PROJECTION_VALIDATION_PASSED,
        original.embedding_residuals,
        repeat("0", 64),
    )
    self_consistent_payload = projection_result_with_solution(fixture.result, invalid_solution)
    @test self_consistent_payload.payload_sha256 == Base.invokelatest(
        PROJECTION_MATERIAL_EXT._projection_search_payload_sha256,
        self_consistent_payload,
    )
    @test_throws ArgumentError PROJECTION_MATERIAL_W.materialize_projection_basis(
        self_consistent_payload,
    )

    mismatched_template = PROJECTION_MATERIAL_W.SymmetryAdaptedWannierizationConfig(
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
        solver = PROJECTION_MATERIAL_W.WannierizationSolverConfig(),
        checkpoint = PROJECTION_MATERIAL_W.WannierizationCheckpointConfig(),
        runtime = PROJECTION_MATERIAL_W.WannierizationRuntimeConfig(),
        output = PROJECTION_MATERIAL_W.WannierizationOutputConfig(),
    )
    @test_throws ArgumentError PROJECTION_MATERIAL_W.materialize_symmetry_adapted_wannierization_config(
        mismatched_template,
        fixture.result,
    )
end
