using LinearAlgebra
using Random
using Test

const FROZEN_WANNIERIZATION = WannierNLQG.Wannierization
const FROZEN_SYMMETRIZATION = WannierNLQG.Symmetrization

function frozen_initializer_fixture(; num_bands::Int = 22, num_wannier::Int = 18)
    identity_operation = WannierNLQG.SymmetryFoundation.SymmetryOperation(
        Matrix{Int}(I, 3, 3),
        zeros(3),
        Matrix{Float64}(I, 3, 3),
    )
    representation = WannierNLQG.SymmetryFoundation.BandRepresentation(
        "1.0",
        :synthetic,
        true,
        Matrix{Float64}(I, 3, 3),
        2.0pi .* Matrix{Float64}(I, 3, 3),
        (1, 1, 1),
        zeros(1, 3),
        reshape(collect(range(-5.0, 5.0; length = num_bands)), num_bands, 1),
        [identity_operation],
        ones(Int, 1, 1),
        zeros(Int, 3, 1, 1),
        reshape(Matrix{ComplexF64}(I, num_bands, num_bands), num_bands, num_bands, 1, 1),
        reshape(collect(1:num_bands), num_bands, 1),
        [1],
        [1],
        [1];
        input_sha256 = Dict("fixture" => repeat("a", 64)),
    )
    local_bases = repeat(reshape(Matrix{Float64}(I, 3, 3), 3, 3, 1), 1, 1, num_wannier)
    block = WannierNLQG.WannierProjection.WannierProjectionBlock(
        "X",
        "s",
        zeros(3, num_wannier),
        reshape(collect(1:num_wannier), 1, num_wannier),
        local_bases,
        true,
    )
    basis = WannierNLQG.WannierProjection.WannierProjectionBasis([block], num_wannier, true)
    config = FROZEN_WANNIERIZATION.SymmetryAdaptedWannierizationConfig(
        input = FROZEN_WANNIERIZATION.WannierizationInputConfig(
            wannierization_mode = :ordinary,
            win_file = "synthetic.win",
            eig_file = "synthetic.eig",
            mmn_file = "synthetic.mmn",
            amn_file = "synthetic.amn",
            projection_basis = basis,
            num_wannier = num_wannier,
            representation_tolerance = 1.0e-8,
        ),
        solver = FROZEN_WANNIERIZATION.WannierizationSolverConfig(
            algorithm_profile = :custom,
            initialization = :amn,
        ),
        checkpoint = FROZEN_WANNIERIZATION.WannierizationCheckpointConfig(),
        runtime = FROZEN_WANNIERIZATION.WannierizationRuntimeConfig(),
        output = FROZEN_WANNIERIZATION.WannierizationOutputConfig(),
    )
    return (; representation, basis, config)
end

function frozen_projector_residual(frame, frozen)
    projector = frame * frame'
    return maximum(norm(@view(projector[:, band]) - (1:size(frame, 1) .== band)) for band in frozen)
end

@testset "no-symmetry exact-frozen AMN row-space initializer" begin
    fixture = frozen_initializer_fixture()
    num_bands = size(fixture.representation.energies_ev, 1)
    num_wannier = fixture.basis.num_wannier
    frozen = [collect(1:14)]
    outer = [collect(1:num_bands)]

    # The old whole-frame alignment sees rank 14 and fails. The new algorithm
    # completes the four free target/band directions without weakening frozen
    # inclusion.
    amn = zeros(ComplexF64, num_bands, num_wannier, 1)
    for index in 1:14
        amn[index, index, 1] = 1.0
    end
    @test_throws ArgumentError FROZEN_WANNIERIZATION._legacy_initial_frames(
        fixture.config,
        fixture.representation,
        outer,
        frozen,
        num_wannier,
        amn,
        nothing,
    )
    frames, diagnostics, invariants, report =
        FROZEN_WANNIERIZATION._initial_frames_with_diagnostics(
            fixture.config,
            fixture.representation,
            outer,
            frozen,
            num_wannier,
            amn,
            nothing,
        )
    @test report.algorithm == :amn_full_bz_exact_frozen_embedding
    @test report.algorithm_version == "nosym_exact_frozen_rowspace_v2"
    @test report.status == :COMPLETED_WITH_WARNING
    @test only(diagnostics).band_completion_count == 4
    @test only(diagnostics).target_completion_count == 0
    @test maximum(abs, frames[1]' * frames[1] - I) <= 1.0e-8
    @test frozen_projector_residual(frames[1], only(frozen)) <= 1.0e-8
    @test invariants.maximum_isometry <= 1.0e-8
    @test invariants.maximum_frozen_residual <= 1.0e-8

    # A projected-free AMN rank of two is evidence and causes exactly two
    # deterministic band completions.
    partial = copy(amn)
    partial[15, 15, 1] = 1.0
    partial[16, 16, 1] = 1.0
    partial_frames, partial_diagnostics, _, partial_report =
        FROZEN_WANNIERIZATION._initial_frames_with_diagnostics(
            fixture.config,
            fixture.representation,
            outer,
            frozen,
            num_wannier,
            partial,
            nothing,
        )
    @test partial_report.status == :COMPLETED_WITH_WARNING
    @test only(partial_diagnostics).projected_free_rank == 2
    @test only(partial_diagnostics).band_completion_count == 2
    @test maximum(abs, partial_frames[1]' * partial_frames[1] - I) <= 1.0e-8
    @test frozen_projector_residual(partial_frames[1], only(frozen)) <= 1.0e-8

    # Geometry, capacity, and finite-value errors remain hard failures.
    @test_throws ArgumentError FROZEN_WANNIERIZATION._initial_frames_with_diagnostics(
        fixture.config,
        fixture.representation,
        [collect(1:17)],
        frozen,
        num_wannier,
        amn,
        nothing,
    )
    @test_throws ArgumentError FROZEN_WANNIERIZATION._initial_frames_with_diagnostics(
        fixture.config,
        fixture.representation,
        outer,
        [collect(1:19)],
        num_wannier,
        amn,
        nothing,
    )
    nonfinite = copy(amn)
    nonfinite[1, 1, 1] = ComplexF64(NaN, 0.0)
    @test_throws ArgumentError FROZEN_WANNIERIZATION._initial_frames_with_diagnostics(
        fixture.config,
        fixture.representation,
        outer,
        frozen,
        num_wannier,
        nonfinite,
        nothing,
    )
end

@testset "unaffected initializer paths retain established behavior" begin
    fixture = frozen_initializer_fixture()
    num_bands = size(fixture.representation.energies_ev, 1)
    num_wannier = fixture.basis.num_wannier
    outer = [collect(1:num_bands)]
    no_frozen = [Int[]]
    rng = MersenneTwister(0xabe)
    amn =
        randn(rng, ComplexF64, num_bands, num_wannier, 1) .+
        1.0im .* randn(rng, ComplexF64, num_bands, num_wannier, 1)
    legacy = FROZEN_WANNIERIZATION._legacy_initial_frames(
        fixture.config,
        fixture.representation,
        outer,
        no_frozen,
        num_wannier,
        amn,
        nothing,
    )
    frames, diagnostics, invariants, report =
        FROZEN_WANNIERIZATION._initial_frames_with_diagnostics(
            fixture.config,
            fixture.representation,
            outer,
            no_frozen,
            num_wannier,
            amn,
            nothing,
        )
    @test frames == legacy
    @test isempty(diagnostics)
    @test invariants === nothing
    @test report === nothing

    random_config = FROZEN_WANNIERIZATION._replace_wannierization_config(
        fixture.config;
        solver = (initialization = :random,),
    )
    random_frames, _, _, random_report = FROZEN_WANNIERIZATION._initial_frames_with_diagnostics(
        random_config,
        fixture.representation,
        outer,
        [collect(1:14)],
        num_wannier,
        nothing,
        nothing,
    )
    @test random_report === nothing
    @test maximum(abs, random_frames[1]' * random_frames[1] - I) <= 1.0e-8
end
