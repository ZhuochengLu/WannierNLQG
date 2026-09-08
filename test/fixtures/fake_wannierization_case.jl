using JSON3

length(ARGS) == 3 || error("expected RUN_ROOT CASE_NAME READONLY_REPRESENTATION")
run_root, case_name, representation = ARGS

environment = Dict(
    name => get(ENV, name, "MISSING") for name in (
        "JULIA_NUM_THREADS",
        "OMP_NUM_THREADS",
        "MKL_NUM_THREADS",
        "OPENBLAS_NUM_THREADS",
        "VECLIB_MAXIMUM_THREADS",
        "WANNIERNLQG_USE_MPI",
    )
)
environment["julia_threads_observed"] = string(Threads.nthreads())
environment["representation_write_bits"] = string(Int(stat(representation).mode & 0o222))
open(joinpath(run_root, "environment.json"), "w") do io
    JSON3.pretty(io, environment)
    println(io)
end

println("FAKE_CASE_START $(case_name)")
if case_name == "case_error"
    println(stderr, "intentional isolated fake-case failure")
    exit(7)
end

sleep(case_name == "case_slow" ? 0.45 : 0.08)
open(joinpath(run_root, "checkpoint.fake"), "w") do io
    println(io, case_name)
end
open(joinpath(run_root, "status.json"), "w") do io
    JSON3.pretty(
        io,
        Dict(
            "case" => case_name,
            "solver_status" => "FAKE_COMPLETE",
            "diagnostic_classification" => "CONVERGED",
            "completed" => true,
            "tb_available" => false,
            "production_eligible" => false,
        ),
    )
    println(io)
end
println("FAKE_CASE_COMPLETE $(case_name)")
