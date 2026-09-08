using LinearAlgebra
using Test
using WannierNLQG

const PROJECTION_SEARCH_W = WannierNLQG.Wannierization
const PROJECTION_SEARCH_EXT =
    first(PROJECTION_SEARCH_W._load_wannierization_extension!()).ProjectionSearch

function synthetic_projection_integer_problem(;
    lower = 2,
    upper = 3,
    complete = true,
    uncertain = false,
    minima = [0, 0],
    maxima = [10, 10],
)
    signature = PROJECTION_SEARCH_W.ProjectionRepresentationSignature(
        1,
        ["A"],
        [1],
        [:unitary],
        [lower],
        [upper],
    )
    return PROJECTION_SEARCH_W.ProjectionRepresentationProblem(
        [signature],
        ["B", "A"],
        [2, 1],
        reshape([1, 1], 1, 2),
        [lower],
        [upper],
        minima,
        maxima,
        complete,
        uncertain,
        String[],
    )
end

function synthetic_c1_projection_adapter_fixture()
    scope = WannierNLQG.SymmetryFoundation.BandRepresentationQualificationScope(
        trues(1, 1),
        trues(1, 1),
    )
    contract = PROJECTION_SEARCH_W.TargetSubspaceQualificationContract(
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
        [1],
    )
    spec = WannierNLQG.WannierProjection.ProjectionSpec(
        selector = "X",
        orbital_sets = "s",
        positions = zeros(3, 1),
    )
    candidate = PROJECTION_SEARCH_W.ProjectionCandidateSpec(
        id = "X:s",
        specs = [spec],
        fixed_multiplicity = 1,
        max_multiplicity = 1,
    )
    return (; representation, contract, candidate)
end

@testset "deterministic projection-representation branch-and-bound" begin
    problem = synthetic_projection_integer_problem()
    outcome = Base.invokelatest(
        PROJECTION_SEARCH_EXT._search_projection_integer_combinations,
        problem,
        3;
        max_results = 1,
        max_search_nodes = 10_000,
    )
    @test outcome.complete
    @test !outcome.uncertain
    @test outcome.total_solution_count == 2
    @test length(outcome.retained) == 1
    @test only(outcome.retained) == [0, 3]
    @test outcome.visited_nodes > outcome.total_solution_count

    repeated = Base.invokelatest(
        PROJECTION_SEARCH_EXT._search_projection_integer_combinations,
        problem,
        3;
        max_results = 1,
        max_search_nodes = 10_000,
    )
    @test repeated.visited_nodes == outcome.visited_nodes
    @test repeated.total_solution_count == outcome.total_solution_count
    @test repeated.retained == outcome.retained

    all_retained = Base.invokelatest(
        PROJECTION_SEARCH_EXT._search_projection_integer_combinations,
        problem,
        3;
        max_results = 10,
        max_search_nodes = 10_000,
    )
    @test all_retained.total_solution_count == outcome.total_solution_count
    @test all_retained.retained == [[0, 3], [1, 1]]

    limited = Base.invokelatest(
        PROJECTION_SEARCH_EXT._search_projection_integer_combinations,
        problem,
        3;
        max_results = 100,
        max_search_nodes = 1,
    )
    @test !limited.complete
    @test limited.visited_nodes == 1
    @test limited.total_solution_count == 0

    fixed = synthetic_projection_integer_problem(minima = [1, 1], maxima = [1, 1])
    fixed_outcome =
        Base.invokelatest(PROJECTION_SEARCH_EXT._search_projection_integer_combinations, fixed, 3)
    @test fixed_outcome.complete
    @test fixed_outcome.total_solution_count == 1
    @test only(fixed_outcome.retained) == [1, 1]

    empty_problem = synthetic_projection_integer_problem(lower = 4, upper = 4)
    empty_outcome = Base.invokelatest(
        PROJECTION_SEARCH_EXT._search_projection_integer_combinations,
        empty_problem,
        3,
    )
    @test empty_outcome.complete
    @test empty_outcome.total_solution_count == 0
    @test isempty(empty_outcome.retained)

    uncertain_problem = synthetic_projection_integer_problem(uncertain = true)
    uncertain_outcome = Base.invokelatest(
        PROJECTION_SEARCH_EXT._search_projection_integer_combinations,
        uncertain_problem,
        3,
    )
    @test uncertain_outcome.uncertain
    @test uncertain_outcome.complete
    @test uncertain_outcome.total_solution_count == 2
end

@testset "spinless-unitary target-action problem and public search" begin
    fixture = synthetic_c1_projection_adapter_fixture()
    thresholds = PROJECTION_SEARCH_W.ProjectionRepresentationSearchThresholds()
    problem = Base.invokelatest(
        PROJECTION_SEARCH_EXT._build_projection_representation_problem,
        fixture.representation,
        fixture.contract,
        [fixture.candidate];
        thresholds,
    )
    @test problem.complete
    @test !problem.uncertain
    @test problem.candidate_dimensions == [1]
    @test problem.lower_bounds == problem.upper_bounds
    @test problem.candidate_signatures[:, 1] == problem.lower_bounds

    embedding = Base.invokelatest(
        PROJECTION_SEARCH_EXT._validate_projection_representation_embedding,
        fixture.representation,
        fixture.contract,
        [fixture.candidate],
        [1];
        thresholds,
    )
    @test embedding.complete
    @test !embedding.uncertain
    @test embedding.frozen_rank == 1
    @test embedding.target_rank == 1
    @test embedding.outer_rank == 1
    @test embedding.frozen_residual <= thresholds.representation
    @test embedding.outer_residual <= thresholds.representation

    config = PROJECTION_SEARCH_W.ProjectionRepresentationSearchConfig(
        band_representation = fixture.representation,
        target_subspace_contract = fixture.contract,
        candidates = [fixture.candidate],
    )
    result = PROJECTION_SEARCH_W.search_projection_representations(config)
    @test result.status == PROJECTION_SEARCH_W.PROJECTION_SEARCH_COMPLETE
    @test result.complete
    @test result.total_solution_count == 1
    @test length(result.solutions) == 1
    @test result.compatibility_info.parity_eligible
    @test result.compatibility_info.scope == :spinless_unitary
    @test only(result.solutions).validation_status ==
          PROJECTION_SEARCH_W.PROJECTION_VALIDATION_PASSED
    @test length(only(result.solutions).validation_sha256) == 64

    unvalidated_config = PROJECTION_SEARCH_W.ProjectionRepresentationSearchConfig(
        band_representation = fixture.representation,
        target_subspace_contract = fixture.contract,
        candidates = [fixture.candidate],
        validate_retained_solutions = false,
    )
    unvalidated = PROJECTION_SEARCH_W.search_projection_representations(unvalidated_config)
    @test unvalidated.complete
    @test unvalidated.total_solution_count == result.total_solution_count
    @test only(unvalidated.solutions).validation_status ==
          PROJECTION_SEARCH_W.PROJECTION_VALIDATION_NOT_RUN
    @test isempty(only(unvalidated.solutions).embedding_residuals)
    @test length(only(unvalidated.solutions).validation_sha256) == 64
end

@testset "independent embedding validation states" begin
    passed = PROJECTION_SEARCH_W.ProjectionRepresentationEmbeddingCertificate(
        0.0,
        0.0,
        1,
        1,
        1,
        true,
        false,
        String[],
    )
    failed = PROJECTION_SEARCH_W.ProjectionRepresentationEmbeddingCertificate(
        Inf,
        Inf,
        1,
        0,
        0,
        false,
        false,
        ["no embedding"],
    )
    uncertain = PROJECTION_SEARCH_W.ProjectionRepresentationEmbeddingCertificate(
        1.0e-7,
        1.0e-7,
        1,
        0,
        1,
        false,
        true,
        ["bounded search inconclusive"],
    )

    @test first(
        Base.invokelatest(PROJECTION_SEARCH_EXT._projection_validation_state, false, nothing),
    ) == PROJECTION_SEARCH_W.PROJECTION_VALIDATION_NOT_RUN
    @test first(
        Base.invokelatest(PROJECTION_SEARCH_EXT._projection_validation_state, true, passed),
    ) == PROJECTION_SEARCH_W.PROJECTION_VALIDATION_PASSED
    failed_status, failed_residuals =
        Base.invokelatest(PROJECTION_SEARCH_EXT._projection_validation_state, true, failed)
    @test failed_status == PROJECTION_SEARCH_W.PROJECTION_VALIDATION_FAILED
    @test all(isfinite, values(failed_residuals))
    outcome = Base.invokelatest(
        PROJECTION_SEARCH_EXT._search_projection_integer_combinations,
        synthetic_projection_integer_problem(),
        3;
        max_results = 1,
    )
    failed_solution = Base.invokelatest(
        PROJECTION_SEARCH_EXT._projection_public_solution,
        synthetic_projection_integer_problem(),
        only(outcome.retained),
        failed_status,
        failed_residuals,
    )
    @test outcome.total_solution_count == 2
    @test failed_solution.validation_status == PROJECTION_SEARCH_W.PROJECTION_VALIDATION_FAILED
    @test first(
        Base.invokelatest(PROJECTION_SEARCH_EXT._projection_validation_state, true, uncertain),
    ) == PROJECTION_SEARCH_W.PROJECTION_VALIDATION_NUMERICAL_UNCERTAIN
end

@testset "projection-representation problem fails closed on malformed bounds" begin
    malformed = PROJECTION_SEARCH_W.ProjectionRepresentationProblem(
        PROJECTION_SEARCH_W.ProjectionRepresentationSignature[],
        ["X"],
        [1],
        zeros(Int, 1, 1),
        [1],
        [0],
        [0],
        [1],
        true,
        false,
        String[],
    )
    @test_throws ArgumentError Base.invokelatest(
        PROJECTION_SEARCH_EXT._search_projection_integer_combinations,
        malformed,
        1,
    )
end
