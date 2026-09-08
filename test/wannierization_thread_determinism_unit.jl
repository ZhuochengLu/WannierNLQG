@testset "Wannierization exact 1/2/4-thread determinism" begin
    probe = joinpath(@__DIR__, "WannierizationThreadDeterminismProbe.jl")
    digests = String[]
    for threads in (1, 2, 4)
        command =
            `$(Base.julia_cmd()) --startup-file=no --threads=$(threads) --project=$(ROOT) $(probe)`
        output = read(
            addenv(
                command,
                "OMP_NUM_THREADS" => "1",
                "MKL_NUM_THREADS" => "1",
                "OPENBLAS_NUM_THREADS" => "1",
                "VECLIB_MAXIMUM_THREADS" => "1",
            ),
            String,
        )
        matched = match(r"WANNIERIZATION_THREAD_DIGEST=([0-9a-f]{64})", output)
        @test matched !== nothing
        push!(digests, something(matched).captures[1])
    end
    @test all(==(first(digests)), digests)
end
