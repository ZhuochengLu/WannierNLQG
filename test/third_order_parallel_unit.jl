using Test, WannierNLQG

# Collect numeric spectra only: metadata intentionally records actual process counts.
function third_order_parallel_tables(directory)
    tables=Dict{String, Vector{Float64}}()
    for (path, _, files) in walkdir(directory), file in files
        endswith(file, ".dat") || continue
        numbers=Float64[]
        for line in eachline(joinpath(path, file))
            startswith(strip(line), "#") && continue
            append!(numbers, parse.(Float64, split(line)))
        end
        tables[relpath(joinpath(path, file), directory)]=numbers
    end
    return tables
end

@testset "Jerk/THG mixed tasks: exact deterministic Threads/MPI spectra" begin
    root=dirname(@__DIR__)
    probe=joinpath(@__DIR__, "ThirdOrderDeterminismProbe.jl")
    mode=get(ENV, "WANNIERNLQG_TEST_MODE", "full-shard")
    cases=mode=="mpi-only" ? ((1, 1), (2, 1)) : ((1, 1), (1, 2))
    mktempdir() do temporary
        for backend in ("Direct", "Mixed")
            reference=nothing
            for (ranks, threads) in cases
                destination=joinpath(temporary, backend*"_$(ranks)_$(threads)")
                command=`$(Base.julia_cmd()) --startup-file=no --threads=$threads --project=$root $probe $destination $backend`
                environment=Dict(
                    "OPENBLAS_NUM_THREADS"=>"1",
                    "OMP_NUM_THREADS"=>"1",
                    "WANNIERNLQG_USE_MPI"=>mode=="mpi-only" ? "1" : "0",
                )
                if mode=="mpi-only"
                    @eval import MPI
                    command=`$(MPI.mpiexec()) -n $ranks $command`
                end
                @test success(
                    pipeline(addenv(command, environment); stdout = devnull, stderr = stderr),
                )
                tables=third_order_parallel_tables(destination)
                @test !isempty(tables)
                if reference===nothing
                    reference=tables
                else
                    @test keys(tables)==keys(reference)
                    for name in keys(tables)
                        @test tables[name]==reference[name]
                    end
                end
            end
        end
    end
end
