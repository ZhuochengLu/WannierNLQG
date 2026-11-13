@testset "Frozen containment uses complete selected states" begin
    W = WANNIERIZATION
    support = WANNIERIZATION_IMPLEMENTATION.WannierizationInternalSupport
    energies = reshape([-1.0, 0.0, 1.0, 2.0], 4, 1)
    labels = reshape([1, 2, 3, 4], 4, 1)
    make_config(; kwargs...) = W.WannierizationConfig(
        input = W.WannierizationInputConfig(;
            eig_file = "unused.eig",
            mmn_file = "unused.mmn",
            kwargs...,
        ),
    )
    masks(config; values = energies, blocks = labels) =
        support.window_masks_from_energies(config, values, blocks)
    baseline = make_config(
        outer_min_ev = -1.0,
        outer_max_ev = 2.0,
        frozen_min_ev = -1.0,
        frozen_max_ev = 0.0,
    )
    lower_overhang = make_config(
        outer_min_ev = -1.0,
        outer_max_ev = 2.0,
        frozen_min_ev = -18.0,
        frozen_max_ev = 0.0,
    )
    @test masks(lower_overhang) == masks(baseline)
    upper_overhang = make_config(
        outer_min_ev = -1.0,
        outer_max_ev = 2.0,
        frozen_min_ev = 1.0,
        frozen_max_ev = 18.0,
    )
    @test masks(upper_overhang)[2] == [BitVector([false, false, true, true])]
    outside = make_config(
        outer_min_ev = 0.0,
        outer_max_ev = 2.0,
        frozen_min_ev = -18.0,
        frozen_max_ev = 0.0,
    )
    @test_throws ArgumentError masks(outside)
    explicit_outside = make_config(outer_min_ev = 0.0, outer_max_ev = 2.0, frozen_states = [(1, 1)])
    @test_throws ArgumentError masks(explicit_outside)
    # Both masks still complete entire degeneracy blocks, not clipped energy rows.
    @test masks(baseline; blocks = reshape([1, 2, 2, 3], 4, 1))[2] ==
          [BitVector([true, true, true, false])]
    empty = make_config(outer_min_ev = -1.0, outer_max_ev = 2.0)
    @test !any(only(masks(empty)[2]))
    @test_throws ArgumentError masks(baseline; blocks = ones(Int, 3, 1))
    # The preparation entry uses the same materialization and containment check.
    prep = W.BandRepresentationPreparationConfig(
        eig_file = "unused.eig",
        outer_min_ev = -1.0,
        outer_max_ev = 2.0,
        frozen_min_ev = -18.0,
        frozen_max_ev = 0.0,
    )
    @test masks(prep) == masks(lower_overhang)
end
