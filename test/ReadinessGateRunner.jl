module ReadinessGateRunner

# Resolve the bounded subprocess pool without modifying the caller's environment.
function readiness_jobs(environment = ENV)
    value = get(environment, "WANNIERNLQG_READINESS_JOBS", "1")
    value in ("1", "2") || error("WANNIERNLQG_READINESS_JOBS must be 1 or 2")
    return parse(Int, value)
end

# Run every independent gate once and return records in the original inventory order.
function run_readiness_gates(entries; jobs::Int = 1, output_root::AbstractString = mktempdir())
    jobs in (1, 2) || error("readiness jobs must be 1 or 2")
    started_pool_ns = time_ns()
    names = first.(entries)
    length(unique(names)) == length(names) || error("duplicate readiness gate")
    directory = joinpath(output_root, "readiness")
    mkpath(directory)
    println(
        "[readiness-pool:start] jobs=$(jobs) gates=$(length(entries)) log_directory=$(directory)",
    )
    flush(stdout)
    records = Vector{Any}(undef, length(entries))
    order = sortperm(
        collect(eachindex(entries));
        by = index -> (
            names[index] == "check_progress_output.jl" ? 0 :
            names[index] == "check_response_symmetry_catalog.jl" ? 1 : 2,
            index,
        ),
    )
    queue = Channel{Int}(length(entries))
    foreach(index -> put!(queue, index), order)
    close(queue)
    @sync for _ in 1:jobs
        @async for index in queue
            name, command = entries[index]
            path = joinpath(directory, "$(index)-$(basename(name)).log")
            started_ns = time_ns()
            println("[gate:start] name=$(name) log=$(path)")
            flush(stdout)
            exit_code = -1
            open(path, "w") do log
                try
                    process = Base.run(
                        pipeline(
                            ignorestatus(
                                addenv(
                                    command,
                                    "JULIA_NUM_THREADS" => "1",
                                    "JULIA_NUM_PRECOMPILE_TASKS" => "1",
                                    "OMP_NUM_THREADS" => "1",
                                    "MKL_NUM_THREADS" => "1",
                                    "OPENBLAS_NUM_THREADS" => "1",
                                    "VECLIB_MAXIMUM_THREADS" => "1",
                                ),
                            );
                            stdout = log,
                            stderr = log,
                        ),
                    )
                    exit_code = process.exitcode
                catch exception
                    showerror(log, exception)
                    println(log)
                end
            end
            elapsed_s = (time_ns() - started_ns) / 1.0e9
            records[index] = (; name, exit_code, elapsed_s, log_path = path)
            status = exit_code == 0 ? "pass" : "fail"
            println(
                "[gate:$(status)] name=$(name) exit_code=$(exit_code) elapsed_s=$(round(elapsed_s; digits = 3)) log=$(path)",
            )
            flush(stdout)
        end
    end
    elapsed_s = (time_ns() - started_pool_ns) / 1.0e9
    println(
        "[readiness-pool:complete] jobs=$(jobs) gates=$(length(records)) elapsed_s=$(round(elapsed_s; digits = 3)) log_directory=$(directory)",
    )
    flush(stdout)
    return records
end

end
