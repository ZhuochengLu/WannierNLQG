using MPI
using Test
using TOML

@testset "Wannierization MPI root-only workflow persistence" begin
    probe = joinpath(@__DIR__, "WannierizationWorkflowMpiProbe.jl")
    launcher = MPI.mpiexec()
    mktempdir() do directory
        command = addenv(
            `$(launcher) -n 2 $(Base.julia_cmd()) --compiled-modules=no --startup-file=no --threads=1 --project=$(dirname(@__DIR__)) $(probe) $(directory)`,
            "OMP_NUM_THREADS" => "1",
            "MKL_NUM_THREADS" => "1",
            "OPENBLAS_NUM_THREADS" => "1",
            "VECLIB_MAXIMUM_THREADS" => "1",
        )
        output = read(command, String)
        @test count(
            occursin("WANNIERIZATION_MPI_WORKFLOW_ROOT_CHECKPOINT="),
            split(output, '\n'),
        ) == 1
        @test isfile(joinpath(directory, "synthetic.wannierization.h5"))
        @test !isfile(joinpath(directory, "synthetic.wannierization.h5.tmp"))
        serial_directory = joinpath(directory, "serial")
        serial_command = addenv(
            `$(Base.julia_cmd()) --compiled-modules=no --startup-file=no --threads=1 --project=$(dirname(@__DIR__)) $(probe) $(serial_directory) serial`,
            "OMP_NUM_THREADS" => "1",
            "MKL_NUM_THREADS" => "1",
            "OPENBLAS_NUM_THREADS" => "1",
            "VECLIB_MAXIMUM_THREADS" => "1",
        )
        read(serial_command, String)
        mpi_payload = TOML.parsefile(joinpath(directory, "numerical-payload.toml"))
        serial_payload = TOML.parsefile(joinpath(serial_directory, "numerical-payload.toml"))
        @test !isempty(mpi_payload)
        @test mpi_payload == serial_payload
        println("WANNIERIZATION_SERIAL_MPI_EXACT leaves=$(length(mpi_payload)) max_abs=0.0")
    end
end
