# Reuse the original eight-iteration portable fixture in every declared mode.
using MPI, JSON3
length(ARGS) == 4 || error("execution, expected MPI size, output and payload required")
execution, expected_size, output, payload = ARGS
execution in ("serial", "mpi", "threads") || error("invalid localization execution")
output = abspath(output)
payload = abspath(payload)
project = dirname(Base.active_project())
startswith(relpath(output, project), "..") || error("output must be outside package")
initialization = @timed execution == "mpi" && MPI.Init()
rank = execution == "mpi" ? MPI.Comm_rank(MPI.COMM_WORLD) : 0
sizevalue = execution == "mpi" ? MPI.Comm_size(MPI.COMM_WORLD) : 1
sizevalue == parse(Int, expected_size) || error("actual MPI size mismatch")
ENV["LOCALIZATION_EXECUTION"] = execution
ENV["LOCALIZATION_RANK"] = string(rank)
ENV["LOCALIZATION_COMMON_OUTPUT"] = joinpath(output, "fixture_output")
ENV["FIRSTUSE_EXPECTED_PACKAGE_ROOT"] = project
ENV["FIRSTUSE_PORTABLE_PAYLOAD_ROOT"] = payload
ENV["FIRSTUSE_PORTABLE_ENTRY_ID"] = "construct_symmetry_adapted_wannier_functions__localization8__mpi12"
ENV["FIRSTUSE_FIXTURE_SUPPORTS"] = ""
rankdir = joinpath(output, "rank_" * string(rank))
mkpath(rankdir)
write(
    joinpath(rankdir, "initialization.json"),
    JSON3.write((
        rank = rank,
        size = sizevalue,
        threads = Threads.nthreads(),
        mpi_library = MPI.Get_library_version(),
        initialization_time = initialization.time,
        initialization_compile = initialization.compile_time,
    )),
)
empty!(ARGS)
append!(
    ARGS,
    [
        "construct_symmetry_adapted_wannier_functions",
        joinpath(payload, "fixtures", "entry_5.jl"),
        joinpath(rankdir, "receipt.json"),
    ],
)
Base.include(Main, joinpath(@__DIR__, "expert_probe.jl"))
execution == "mpi" && MPI.Finalize()
