using Test
using JSON3
using MPI

# Launch the real public API with deterministic BLAS and no MPI opt-in in the parent driver.
function per_task_parallel_command(directory; threads, ranks = nothing)
    probe = joinpath(@__DIR__, "support", "per_task_parallel_runner.jl")
    julia =
        `$(Base.julia_cmd()) --compiled-modules=no --startup-file=no --threads=$(threads) --project=$(dirname(@__DIR__)) $(probe) $(directory)`
    command = ranks === nothing ? julia : `$(MPI.mpiexec()) -n $(ranks) $(julia)`
    return addenv(
        command,
        "WANNIERNLQG_USE_MPI" => ranks === nothing ? "0" : "1",
        "WANNIERNLQG_BENCHMARK_DEFER_MPI_FINALIZE" => "0",
        "OPENBLAS_NUM_THREADS" => "1",
        "OMP_NUM_THREADS" => "1",
        "MKL_NUM_THREADS" => "1",
        "VECLIB_MAXIMUM_THREADS" => "1",
    )
end

# Compare every numerical datum, preserving task IDs, row order and output column shapes.
function check_per_task_parallel_outputs(reference, actual)
    @test Set(keys(reference)) == Set(keys(actual))
    for key in keys(reference)
        @test length(reference[key]) == length(actual[key])
        for (expected_row, actual_row) in zip(reference[key], actual[key])
            @test length(expected_row) == length(actual_row)
            @test maximum(abs.(Float64.(expected_row) .- Float64.(actual_row)); init = 0.0) == 0.0
        end
    end
end

@testset "Independent task parameters: 1/2 threads and MPI ranks" begin
    mktempdir() do directory
        cases = NamedTuple[
            (label = "threads1", threads = 1, ranks = nothing),
            (label = "threads2", threads = 2, ranks = nothing),
        ]
        if isdefined(@__MODULE__, :RUN_MPI_TESTS) && RUN_MPI_TESTS
            append!(
                cases,
                [
                    (label = "mpi1", threads = 1, ranks = 1),
                    (label = "mpi2", threads = 1, ranks = 2),
                ],
            )
        end
        records = Dict{String, Any}()
        for case in cases
            output_root = joinpath(directory, case.label)
            mkpath(output_root)
            command =
                per_task_parallel_command(output_root; threads = case.threads, ranks = case.ranks)
            log = read(command, String)
            @test occursin("PER_TASK_PARALLEL_PROBE_PASS", log)
            records[case.label] = JSON3.read(read(joinpath(output_root, "numerical.json"), String))
            @test length(records[case.label]) >= 8
        end
        for case in cases[2:end]
            check_per_task_parallel_outputs(records["threads1"], records[case.label])
        end
    end
end
