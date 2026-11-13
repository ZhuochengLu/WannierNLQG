using Test
using MPI
isdefined(@__MODULE__, :FullMPIRankProfile) ||
    include(joinpath(@__DIR__, "support", "FullMPIRankProfile.jl"))

@testset "Wannierization U-localization MPI edge parity" begin
    probe = joinpath(@__DIR__, "WannierizationULocalizationMpiProbe.jl")
    launcher = MPI.mpiexec()
    for variant in FullMPIRankProfile.u_fixture_variants()
        digests = String[]
        arguments = variant == "original" ? String[] : [variant]
        for ranks in FullMPIRankProfile.wannierization_ranks()
            command = addenv(
                `$(launcher) -n $(ranks) $(Base.julia_cmd()) --compiled-modules=no --startup-file=no --threads=1 --project=$(dirname(@__DIR__)) $(probe) $arguments`,
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
            if variant == "empty-owner-1d" && ranks > 2
                @test occursin("WANNIERIZATION_U_EMPTY_OWNER_PROBE_PASS", output)
            end
        end
        @test length(unique(digests)) == 1
    end
end
