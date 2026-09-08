using Test
using MPI

@testset "Wannierization contiguous raw-Z MPI 1/2/4/8/16 determinism" begin
    probe = joinpath(@__DIR__, "WannierizationRawZMpiProbe.jl")
    launcher = MPI.mpiexec()
    digests = String[]
    for ranks in (1, 2, 4, 8, 16)
        command = addenv(
            `$(launcher) -n $(ranks) $(Base.julia_cmd()) --compiled-modules=no --startup-file=no --threads=1 --project=$(dirname(@__DIR__)) $(probe)`,
            "OMP_NUM_THREADS" => "1",
            "MKL_NUM_THREADS" => "1",
            "OPENBLAS_NUM_THREADS" => "1",
            "VECLIB_MAXIMUM_THREADS" => "1",
        )
        output = read(command, String)
        matched = match(r"WANNIERIZATION_RAW_Z_MPI_DIGEST=([0-9a-f]{64})", output)
        @test matched !== nothing
        matched === nothing || push!(digests, matched.captures[1])
        residual_match = match(r"WANNIERIZATION_RAW_Z_LEGACY_MAX_ABS=([^\n]+)", output)
        @test residual_match !== nothing
        residual_match === nothing || @test parse(Float64, residual_match.captures[1]) <= 1.0e-12
    end
    @test length(unique(digests)) == 1
end
