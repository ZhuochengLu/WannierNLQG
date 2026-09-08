using Test

@testset "augmentation-aware sewing 1/2/4-thread determinism" begin
    probe = joinpath(@__DIR__, "AugmentationAwareSewingDeterminismProbe.jl")
    digests = String[]
    for threads in (1, 2, 4)
        command = addenv(
            `$(Base.julia_cmd()) --startup-file=no --threads=$(threads) --project=$(dirname(@__DIR__)) $(probe)`,
            "OMP_NUM_THREADS" => "1",
            "MKL_NUM_THREADS" => "1",
            "OPENBLAS_NUM_THREADS" => "1",
            "VECLIB_MAXIMUM_THREADS" => "1",
        )
        output = read(command, String)
        matched = match(r"AUGMENTATION_AWARE_SEWING_DIGEST=([0-9a-f]{64})", output)
        @test matched !== nothing
        push!(digests, something(matched).captures[1])
    end
    @test length(unique(digests)) == 1
end
