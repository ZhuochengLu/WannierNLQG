using Test
using MPI

@testset "Wannierization U-localization MPI edge parity" begin
    probe = joinpath(@__DIR__, "WannierizationULocalizationMpiProbe.jl")
    digests = String[]
    launcher = MPI.mpiexec()
    for ranks in (1, 2, 4, 8, 16)
        command = addenv(
            `$(launcher) -n $(ranks) $(Base.julia_cmd()) --compiled-modules=no --startup-file=no --threads=1 --project=$(dirname(@__DIR__)) $(probe)`,
            "OMP_NUM_THREADS" => "1",
            "MKL_NUM_THREADS" => "1",
            "OPENBLAS_NUM_THREADS" => "1",
            "VECLIB_MAXIMUM_THREADS" => "1",
        )
        output = read(command, String)
        matched = match(r"WANNIERIZATION_U_MPI_PARITY_DIGEST=([0-9a-f]{64})", output)
        @test matched !== nothing
        matched === nothing || push!(digests, matched.captures[1])
        @test occursin("WANNIERIZATION_U_MPI_PARITY_MAX_EVAL=0.0", output)
        @test occursin("WANNIERIZATION_U_MPI_PARITY_MAX_SWEEP=0.0", output)
    end
    @test length(unique(digests)) == 1
end
