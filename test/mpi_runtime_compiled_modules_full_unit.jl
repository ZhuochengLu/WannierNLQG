using Test

const MPI_COMPILED_MODULES_PROBE = raw"""
using Test, WannierNLQG, MPI
R = WannierNLQG.Runtime
@test !MPI.Initialized()
@test fieldnames(R.MPIExecutionContext) == (:has_mpi, :started)
R.BUNDLE_MPI_CONTEXT.has_mpi = false
R.bundle_mpi_initialize()
@test R.BUNDLE_MPI_CONTEXT.has_mpi
@test R.BUNDLE_MPI_CONTEXT.started
@test MPI.Initialized()
R.mpi_context_force_finalize!(R.BUNDLE_MPI_CONTEXT)
@test MPI.Finalized()
@test_throws ErrorException R.bundle_mpi_initialize()
println("MPI_ENVIRONMENT_PROBE_PASS enabled")
"""

@testset "MPI runtime compiled-modules-disabled lifecycle" begin
    environment = Dict{String, Union{Nothing, String}}(
        "WANNIERNLQG_USE_MPI" => "1",
        "WANNIERNLQG_BENCHMARK_DEFER_MPI_FINALIZE" => "0",
    )
    for name in (WannierNLQG.Runtime.MPI_RANK_ENV_KEYS..., WannierNLQG.Runtime.MPI_SIZE_ENV_KEYS...)
        environment[name] = nothing
    end
    command =
        `$(Base.julia_cmd()) --startup-file=no --compiled-modules=no --project=$(ROOT) -e $(MPI_COMPILED_MODULES_PROBE)`
    @test occursin("MPI_ENVIRONMENT_PROBE_PASS enabled", read(addenv(command, environment), String))
end
