using Test, JSON3, MPI
isdefined(@__MODULE__, :FullMPIRankProfile) ||
    include(joinpath(@__DIR__, "support", "FullMPIRankProfile.jl"))

function nonorthogonal_adaptive_mpi_command(directory, ranks)
    probe = joinpath(@__DIR__, "NonorthogonalAdaptiveMpiProbe.jl")
    julia =
        `$(Base.julia_cmd()) --compiled-modules=no --startup-file=no --threads=1 --project=$(dirname(@__DIR__)) $(probe) $(directory)`
    return addenv(
        `$(MPI.mpiexec()) -n $(ranks) $(julia)`,
        "WANNIERNLQG_USE_MPI" => "1",
        "OPENBLAS_NUM_THREADS" => "1",
        "OMP_NUM_THREADS" => "1",
        "MKL_NUM_THREADS" => "1",
        "VECLIB_MAXIMUM_THREADS" => "1",
    )
end

# The ordinary whole-MPI wrapper keeps its original temporary lifetime and read.
# The explicit application entry retains raw outputs and actual launcher waits.
function nonorthogonal_adaptive_directory(callback::Function)
    if isempty(get(ENV, "WANNIERNLQG_MPI_APPLICATION", ""))
        return mktempdir(callback)
    end
    directory = joinpath(ENV["WANNIERNLQG_TEST_OUTPUT_ROOT"], "adaptive")
    ispath(directory) && error("Adaptive evidence directory must be fresh")
    mkpath(directory)
    return callback(directory)
end

function nonorthogonal_adaptive_read(command, output, ranks)
    isempty(get(ENV, "WANNIERNLQG_MPI_APPLICATION", "")) && return read(command, String)
    started = time()
    process = open(command, "r", devnull)
    processes = process isa Base.Process ? [process] : process.processes
    length(processes) == 1 || error("single MPI launcher required")
    launcher = only(processes)
    pid = getpid(launcher)
    log = read(process.out, String)
    succeeded = success(process)
    wait_record = Dict(
        "schema" => "wanniernlqg.mpi-launcher-wait/1",
        "pid" => pid,
        "ranks" => ranks,
        "argv" => collect(command.exec),
        "started_at" => started,
        "waited_at" => time(),
        "actual_exit" => launcher.exitcode,
        "termsignal" => launcher.termsignal,
        "julia_version" => string(VERSION),
        "parent_source" => realpath(dirname(@__DIR__)),
    )
    write(joinpath(output, "launcher-wait.json"), JSON3.write(wait_record))
    write(joinpath(output, "launcher-stdout.log"), log)
    succeeded || error("Adaptive launcher failed with an actual recorded wait status")
    return log
end

@testset "Nonorthogonal adaptive MPI profile ranks retain exact public numerical contracts" begin
    nonorthogonal_adaptive_directory() do directory
        records = Dict{Int, Any}()
        rank_plan = FullMPIRankProfile.adaptive_ranks()
        for ranks in rank_plan
            output = joinpath(directory, "ranks$(ranks)")
            mkpath(output)
            log = nonorthogonal_adaptive_read(
                nonorthogonal_adaptive_mpi_command(output, ranks),
                output,
                ranks,
            )
            @test occursin("NONORTHOGONAL_ADAPTIVE_MPI_PROBE_PASS", log)
            records[ranks] = JSON3.read(read(joinpath(output, "numerical.json"), String))
            @test length(records[ranks]) == 21
            for rank in 0:(ranks - 1)
                receipt = JSON3.read(read(joinpath(output, "rank-$(rank).json"), String))
                @test receipt.rank == rank
                @test receipt.ranks == ranks
                @test receipt.normal_constant_local_nodes == length((rank + 1):ranks:15)
            end
        end
        for ranks in rank_plan
            @test Set(keys(records[1])) == Set(keys(records[ranks]))
            for id in keys(records[1])
                reference, actual = records[1][id], records[ranks][id]
                @test reference.diagnostics == actual.diagnostics
                @test Set(keys(reference.tables)) == Set(keys(actual.tables))
                for name in keys(reference.tables)
                    @test reference.tables[name] == actual.tables[name]
                end
            end
        end
    end
end
