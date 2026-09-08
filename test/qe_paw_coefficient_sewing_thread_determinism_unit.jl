using Test

@testset "QE PAW coefficient-sewing 1/2/4-thread determinism" begin
    probe = joinpath(@__DIR__, "QECoefficientSewingDeterminismProbe.jl")
    digests = Dict{Int, String}()
    for threads in (1, 2, 4)
        command = addenv(
            `$(Base.julia_cmd()) --startup-file=no --threads=$(threads) --project=$(dirname(@__DIR__)) $(probe)`,
            "OMP_NUM_THREADS" => "1",
            "MKL_NUM_THREADS" => "1",
            "OPENBLAS_NUM_THREADS" => "1",
            "VECLIB_MAXIMUM_THREADS" => "1",
        )
        output = read(command, String)
        matched = match(r"QE_PAW_COEFFICIENT_SEWING_DIGEST=([0-9a-f]{64})", output)
        @test matched !== nothing
        digests[threads] = something(matched).captures[1]
    end
    @test digests[1] == digests[2] == digests[4]
end
