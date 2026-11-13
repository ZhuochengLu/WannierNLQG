using LinearAlgebra
using WannierNLQG

# Existing one-state search fixture shared by materialization and codec tests.
function projection_materialization_fixture()
    scope = WannierNLQG.SymmetryFoundation.BandRepresentationQualificationScope(
        trues(1, 1),
        trues(1, 1);
        content_authentication = false,
    )
    contract = WannierNLQG.Wannierization.TargetSubspaceQualificationContract(
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
            "content_authentication" => "NOT_PERFORMED",
            "target_subspace_contract_definition" => contract.contract_definition,
            "outer_mask_definition" => scope.outer_mask_definition,
            "frozen_mask_definition" => scope.frozen_mask_definition,
        ),
        input_sha256 = Dict("TARGET_SUBSPACE_CONTRACT_DEFINITION" => contract.contract_definition),
    )
    spec = WannierNLQG.WannierProjection.ProjectionSpec(
        selector = "X",
        orbital_sets = "s",
        positions = zeros(3, 1),
    )
    candidate = WannierNLQG.Wannierization.ProjectionCandidateSpec(
        id = "X:s",
        specs = [spec],
        fixed_multiplicity = 1,
        max_multiplicity = 1,
    )
    config = WannierNLQG.Wannierization.ProjectionRepresentationSearchConfig(
        band_representation = representation,
        target_subspace_contract = contract,
        candidates = [candidate],
    )
    result = WannierNLQG.Wannierization.search_projection_representations(config)
    result.complete || error("synthetic materialization search did not complete")
    template = WannierNLQG.Wannierization.WannierizationConfig(
        input = WannierNLQG.Wannierization.WannierizationInputConfig(
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
        solver = WannierNLQG.Wannierization.WannierizationSolverConfig(),
        checkpoint = WannierNLQG.Wannierization.WannierizationCheckpointConfig(),
        runtime = WannierNLQG.Wannierization.WannierizationRuntimeConfig(),
        output = WannierNLQG.Wannierization.WannierizationOutputConfig(),
    )
    return (; scope, contract, representation, result, template)
end
