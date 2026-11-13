module ConventionalKSliceBandSelectionTests

using Test, WannierNLQG

# Measure the concrete hot call, excluding dynamic Module-property dispatch.
selection_allocation_probe(selection, screen) =
    @allocated WannierNLQG.Runtime._prepare_conventional_kslice_pairs!(selection, screen)

@testset "Conventional slice external transition selection" begin
    runtime = WannierNLQG.Runtime
    screen = runtime.make_transition_screen_workspace(4, 1, 1)
    screen.has_bands = true
    screen.band_start = 1
    screen.band_end = 4
    screen.occupations .= [1.0, 1.0, 0.0, 0.0]
    energies = [-3.0, -2.0, 1.0, 2.0]
    for broadening in ["Gaussian", "Lorentzian"]
        runtime._fill_transition_screen!(screen, energies, [4.0], broadening, 1.0, 5.0)
        original_mask = copy(screen.active_pair_mask)
        original_delta = copy(screen.delta)
        original_pairs = copy(screen.active_pairs_nmajor)
        selection = runtime._make_conventional_kslice_pair_selection(([4], [1]), 4)
        count = runtime._prepare_conventional_kslice_pairs!(selection, screen)
        @test count.active_pair_count == 1
        @test selection.active_pairs_nmajor[1] == (1, 4)
        @test selection.active_pairs_mmajor[1] == (1, 4)
        @test findall(selection.active_pair_mask) == [CartesianIndex(1, 4)]
        @test count.derivative_pair_count == 2
        @test selection.derivative_required_pairs_nmajor[1:2] == [(1, 4), (4, 1)]
        @test screen.active_pair_mask == original_mask
        @test screen.delta == original_delta
        @test screen.active_pairs_nmajor == original_pairs
        selection_allocation_probe(selection, screen) # compile the measurement wrapper
        @test selection_allocation_probe(selection, screen) == 0
        screen.active_pair_mask[1, 4] = false
        @test runtime._prepare_conventional_kslice_pairs!(selection, screen).active_pair_count == 0
        @test !any(selection.active_pair_mask)
    end
    @test_throws Exception runtime._make_conventional_kslice_pair_selection(([1], [1]), 4)
    @test_throws Exception runtime._make_conventional_kslice_pair_selection(([5], [1]), 4)
    @test_throws Exception runtime._make_conventional_kslice_pair_selection(([3, 3], [1]), 4)
    @test_throws Exception runtime._make_conventional_kslice_pair_selection((Int[], [1]), 4)
end

end # module ConventionalKSliceBandSelectionTests
