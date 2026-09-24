
using Test, WannierNLQG, LinearAlgebra
isdefined(@__MODULE__, :spectral_test_model) ||
    include(joinpath(@__DIR__, "SpectralResponseTestSupport.jl"))

# Compare only physical numeric files; task manifests intentionally contain different paths/rank counts.
function spectral_parallel_tables(directory)
    tables=Dict{String, Matrix{Float64}}()
    for (path, _, files) in walkdir(directory), file in files
        endswith(file, ".dat") || continue
        tables[relpath(joinpath(path, file), directory)]=spectral_test_table(joinpath(path, file))
    end
    return tables
end

@testset "Spectral responses deterministic Threads and MPI" begin
    root=dirname(@__DIR__);
    temporary=mktempdir()
    model=joinpath(temporary, "closed_tb.dat")
    WannierNLQG.IO.write_wannier_tb(model, spectral_test_model())
    probe=joinpath(@__DIR__, "SpectralResponseDeterminismProbe.jl")
    mode=get(ENV, "WANNIERNLQG_TEST_MODE", "full-shard")
    cases=mode=="mpi-only" ? ((1, 1), (2, 1)) : ((1, 1), (1, 2))
    for backend in ("Direct", "Mixed")
        reference=nothing
        for (ranks, threads) in cases
            destination=joinpath(temporary, backend*"_"*string(ranks)*"_"*string(threads))
            command=`$(Base.julia_cmd()) --startup-file=no --threads=$threads --project=$root $probe $destination $model $backend`
            environment=Dict{String, Union{Nothing, String}}(
                "OPENBLAS_NUM_THREADS"=>"1",
                "OMP_NUM_THREADS"=>"1",
                "WANNIERNLQG_USE_MPI"=>mode=="mpi-only" ? "1" : "0",
            )
            if mode=="mpi-only"
                @eval import MPI
                command=`$(MPI.mpiexec()) -n $ranks $command`
            end
            @test success(pipeline(addenv(command, environment); stdout = devnull, stderr = stderr))
            tables=spectral_parallel_tables(destination)
            @test !isempty(tables)
            if reference!==nothing
                @test keys(tables)==keys(reference)
                for name in keys(tables)
                    @test tables[name]==reference[name]
                end
            else
                reference=tables
            end
        end
    end
end
