using Test

const MPI_ENVIRONMENT_PROBE = raw"""
using Test, WannierNLQG, MPI
R = WannierNLQG.Runtime
mode = ARGS[1]
@test !MPI.Initialized()
@test fieldnames(R.MPIExecutionContext) == (:has_mpi, :started)
if mode == "disabled"
    # Simulate a cache created when a launcher or explicit opt-in was present.
    R.BUNDLE_MPI_CONTEXT.has_mpi = true
    R.bundle_mpi_initialize()
    @test !R.BUNDLE_MPI_CONTEXT.has_mpi
    @test !MPI.Initialized()
elseif mode == "enabled"
    R.BUNDLE_MPI_CONTEXT.has_mpi = false
    R.bundle_mpi_initialize()
    @test R.BUNDLE_MPI_CONTEXT.has_mpi
    @test R.BUNDLE_MPI_CONTEXT.started
    @test MPI.Initialized()
    R.mpi_context_force_finalize!(R.BUNDLE_MPI_CONTEXT)
    @test MPI.Finalized()
    @test_throws ErrorException R.bundle_mpi_initialize()
elseif mode == "external"
    MPI.Init()
    R.BUNDLE_MPI_CONTEXT.has_mpi = false
    R.bundle_mpi_initialize()
    @test R.BUNDLE_MPI_CONTEXT.has_mpi
    @test !R.BUNDLE_MPI_CONTEXT.started
    R.mpi_context_force_finalize!(R.BUNDLE_MPI_CONTEXT)
    @test !MPI.Finalized()
    MPI.Finalize()
end
println("MPI_ENVIRONMENT_PROBE_PASS ", mode)
"""

# Keep this process free of a Main.MPI import: the first binding is created inside the call.
const MPI_FUNCTION_ENTRY_PROBE = raw"""
using Test, WannierNLQG
const R = WannierNLQG.Runtime
@test !isdefined(Main, :MPI)
@test fieldnames(R.MPIExecutionContext) == (:has_mpi, :started)
function function_entry()
    R.bundle_mpi_initialize()
    @test !R.BUNDLE_MPI_CONTEXT.has_mpi && !R.BUNDLE_MPI_CONTEXT.started
    ENV["WANNIERNLQG_USE_MPI"] = "1"
    R.bundle_mpi_initialize()
    @test R.BUNDLE_MPI_CONTEXT.has_mpi && R.BUNDLE_MPI_CONTEXT.started
    comm = R.bundle_mpi_comm_world()
    @test R.bundle_mpi_comm_rank(comm) == 0 && R.bundle_mpi_comm_size(comm) == 1
    @test R.bundle_mpi_reduce_sum([3.0], 0, comm) == [3.0]
    @test R.bundle_mpi_bcast((value = 7,), 0, comm) == (value = 7,)
    @test R.bundle_mpi_barrier(comm) === nothing
    R.mpi_context_force_finalize!(R.BUNDLE_MPI_CONTEXT)
    @test Base.invokelatest(() -> getproperty(R, :MPI).Finalized())
end
function_entry()
println("MPI_ENVIRONMENT_PROBE_PASS function_entry")
"""

@testset "MPI runtime request and lifecycle are independent of cached flags" begin
    request_names = (
        "WANNIERNLQG_USE_MPI",
        "WANNIERNLQG_CONVENTIONAL_USE_MPI",
        "WANNIERNLQG_CONVENTIONAL_GEOMETRY_USE_MPI",
        "WANNIERNLQG_INJECTION_CURRENT_USE_MPI",
        "WANNIERNLQG_PROJECTOR_USE_MPI",
        "WANNIERNLQG_GEOMETRIC_LOOP_USE_MPI",
    )
    environment = Dict{String, Union{Nothing, String}}(name => "0" for name in request_names)
    for name in (WannierNLQG.Runtime.MPI_RANK_ENV_KEYS..., WannierNLQG.Runtime.MPI_SIZE_ENV_KEYS...)
        environment[name] = nothing
    end
    environment["WANNIERNLQG_BENCHMARK_DEFER_MPI_FINALIZE"] = "0"
    for mode in ("disabled", "enabled", "external", "function_entry")
        environment["WANNIERNLQG_USE_MPI"] = mode in ("disabled", "function_entry") ? "0" : "1"
        probe = mode == "function_entry" ? MPI_FUNCTION_ENTRY_PROBE : MPI_ENVIRONMENT_PROBE
        command = `$(Base.julia_cmd()) --startup-file=no --project=$(ROOT) -e $(probe) $(mode)`
        output = read(addenv(command, environment), String)
        @test occursin("MPI_ENVIRONMENT_PROBE_PASS " * mode, output)
    end
    if isdefined(@__MODULE__, :RUN_FULL_TESTS) && RUN_FULL_TESTS
        environment["WANNIERNLQG_USE_MPI"] = "1"
        command =
            `$(Base.julia_cmd()) --startup-file=no --compiled-modules=no --project=$(ROOT) -e $(MPI_ENVIRONMENT_PROBE) enabled`
        @test occursin(
            "MPI_ENVIRONMENT_PROBE_PASS enabled",
            read(addenv(command, environment), String),
        )
    end
end
