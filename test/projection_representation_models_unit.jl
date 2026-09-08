using Test

const PROJECTION_SEARCH_MODELS_W = WannierNLQG.Wannierization
const PROJECTION_SEARCH_MODELS_S = WannierNLQG.Symmetrization

@testset "projection-representation stable request models" begin
    thresholds = PROJECTION_SEARCH_MODELS_W.ProjectionRepresentationSearchThresholds()
    @test thresholds.position == 1.0e-8
    @test thresholds.representation == 1.0e-8
    @test thresholds.group_law == 1.0e-8
    @test thresholds.integer == 1.0e-6

    spec = WannierNLQG.WannierProjection.ProjectionSpec(
        selector = "X",
        orbital_sets = "s",
        positions = reshape([0.0, 0.0, 0.0], 3, 1),
    )
    candidate = PROJECTION_SEARCH_MODELS_W.ProjectionCandidateSpec(
        id = "X:s@1a",
        specs = [spec],
        min_multiplicity = 0,
    )
    @test candidate.id == "X:s@1a"
    @test candidate.fixed_multiplicity === nothing
    @test candidate.max_multiplicity == 1
    @test_throws ArgumentError PROJECTION_SEARCH_MODELS_W.ProjectionCandidateSpec(
        id = "implicit",
        specs = [WannierNLQG.WannierProjection.ProjectionSpec(selector = "X", orbital_sets = "s")],
    )
    @test_throws ArgumentError PROJECTION_SEARCH_MODELS_W.ProjectionCandidateSpec(
        id = "indexed",
        specs = [
            WannierNLQG.WannierProjection.ProjectionSpec(
                selector = "X",
                orbital_sets = "s",
                positions = reshape([0.0, 0.0, 0.0], 3, 1),
                indices = reshape([1], 1, 1),
            ),
        ],
    )

    compatibility = PROJECTION_SEARCH_MODELS_W.ProjectionRepresentationCompatibilityInfo(
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
    @test compatibility.parity_eligible
    @test compatibility.scope == :spinless_unitary
    for old_scope in (:wannierberri_native, :wanniernlqg_extension)
        @test_throws ArgumentError PROJECTION_SEARCH_MODELS_W.ProjectionRepresentationCompatibilityInfo(
            compatibility.upstream_package,
            compatibility.upstream_version,
            compatibility.upstream_commit,
            compatibility.upstream_source_sha256,
            compatibility.parity_eligible,
            old_scope,
            compatibility.character_tolerance,
            compatibility.character_round_digits,
            compatibility.little_group_tolerance,
        )
    end
    @test_throws ArgumentError PROJECTION_SEARCH_MODELS_W.ProjectionRepresentationCompatibilityInfo(
        "WannierBerri",
        "1.7.0",
        "short",
        compatibility.upstream_source_sha256,
        true,
        :spinless_unitary,
        1.0e-3,
        3,
        1.0e-5,
    )

    outer = trues(2, 1)
    frozen = BitMatrix(reshape([true, false], 2, 1))
    scope = WannierNLQG.SymmetryFoundation.BandRepresentationQualificationScope(outer, frozen)
    contract = PROJECTION_SEARCH_MODELS_W.TargetSubspaceQualificationContract(
        scope;
        outer_min_ev = -1.0,
        outer_max_ev = 1.0,
        frozen_min_ev = -0.5,
        frozen_max_ev = 0.5,
        num_wannier = 1,
    )
    config = PROJECTION_SEARCH_MODELS_W.ProjectionRepresentationSearchConfig(
        band_representation_hdf5 = "representation.h5",
        target_subspace_contract = contract,
        candidates = [candidate],
    )
    @test config.validate_retained_solutions
    @test config.max_results == 100
    @test config.max_search_nodes == 1_000_000
    @test_throws ArgumentError PROJECTION_SEARCH_MODELS_W.ProjectionRepresentationSearchConfig(
        target_subspace_contract = contract,
        candidates = [candidate],
    )
    @test_throws ArgumentError PROJECTION_SEARCH_MODELS_W.ProjectionRepresentationSearchConfig(
        band_representation_hdf5 = "representation.h5",
        target_subspace_contract = contract,
        candidates = [candidate, candidate],
    )
end
