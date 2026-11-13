using MPI
using Test
using WannierNLQG
import JSON3

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
        mpi_payload =
            WannierNLQG.IO.read_task_input_file(joinpath(directory, "numerical-payload.toml")).document
        serial_payload = WannierNLQG.IO.read_task_input_file(
            joinpath(serial_directory, "numerical-payload.toml"),
        ).document
        @test !isempty(mpi_payload)
        differing = sort!([
            key for key in union(keys(mpi_payload), keys(serial_payload)) if
            get(mpi_payload, key, nothing) != get(serial_payload, key, nothing)
        ])
        if haskey(ENV, "WANNIERNLQG_WORKFLOW_MPI_DIAGNOSTIC")
            diagnostic = Dict(
                "schema" => "wanniernlqg.workflow-mpi-exact-diagnostic/1",
                "source_root" => dirname(@__DIR__),
                "mpi_payload" => mpi_payload,
                "serial_payload" => serial_payload,
                "differing_keys" => differing,
                "exact" => mpi_payload == serial_payload,
            )
            open(ENV["WANNIERNLQG_WORKFLOW_MPI_DIAGNOSTIC"], "w") do stream
                JSON3.write(stream, diagnostic)
            end
        end
        if isempty(differing)
            println("WANNIERIZATION_SERIAL_MPI_EXACT leaves=$(length(mpi_payload)) max_abs=0.0")
        else
            println(
                "WANNIERIZATION_SERIAL_MPI_MISMATCH leaves=$(length(mpi_payload)) differing_keys=$(repr(differing))",
            )
        end
        @test mpi_payload == serial_payload
    end
end
