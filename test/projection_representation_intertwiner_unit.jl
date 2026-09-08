using LinearAlgebra
using Test

const PROJECTION_INTERTWINER_WANNIERIZATION = WannierNLQG.Wannierization
const PROJECTION_INTERTWINER_IMPLEMENTATION =
    first(PROJECTION_INTERTWINER_WANNIERIZATION._load_wannierization_extension!()).ProjectionSearch

@testset "Complex-linear representation embedding certificate" begin
    source_actions = [Matrix{ComplexF64}(I, 2, 2), ComplexF64[1 0; 0 -1]]
    target_actions = [ones(ComplexF64, 1, 1), ones(ComplexF64, 1, 1)]
    certificate = PROJECTION_INTERTWINER_IMPLEMENTATION._certify_representation_embedding(
        source_actions,
        target_actions,
        falses(2),
    )
    @test certificate.complete
    @test !certificate.uncertain
    @test certificate.target_rank == 1
    @test certificate.outer_rank == 2
    @test certificate.outer_residual <= 1.0e-10

    mismatched_target = [ones(ComplexF64, 1, 1), -ones(ComplexF64, 1, 1)]
    too_small = PROJECTION_INTERTWINER_IMPLEMENTATION._certify_representation_embedding(
        target_actions,
        source_actions,
        falses(2),
    )
    @test !too_small.complete
    @test !too_small.uncertain
    @test too_small.target_rank == 0

    negative = PROJECTION_INTERTWINER_IMPLEMENTATION._certify_representation_embedding(
        target_actions,
        mismatched_target,
        falses(2),
    )
    @test !negative.complete
    @test !negative.uncertain
end

@testset "Real-linear Kramers corepresentation embedding certificate" begin
    identity_action = Matrix{ComplexF64}(I, 2, 2)
    time_reversal = ComplexF64[0 1; -1 0]
    certificate = PROJECTION_INTERTWINER_IMPLEMENTATION._certify_representation_embedding(
        [identity_action, time_reversal],
        [identity_action, time_reversal],
        [false, true],
    )
    @test certificate.complete
    @test !certificate.uncertain
    @test certificate.target_rank == 2
    @test certificate.outer_residual <= 1.0e-10

    scalar_time_reversal = [ones(ComplexF64, 1, 1), ones(ComplexF64, 1, 1)]
    kramers_mismatch = PROJECTION_INTERTWINER_IMPLEMENTATION._certify_representation_embedding(
        [identity_action, time_reversal],
        scalar_time_reversal,
        [false, true],
    )
    @test !kramers_mismatch.complete
end
