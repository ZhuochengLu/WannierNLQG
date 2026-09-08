using MPI
using Test

@testset "MDRS MPI root-only publication and prepared support" begin
    probe = joinpath(@__DIR__, "MDRSRuntimeMpiProbe.jl")
    launcher = MPI.mpiexec()
    mktempdir() do directory
        command = addenv(
            `$(launcher) -n 2 $(Base.julia_cmd()) --compiled-modules=no --startup-file=no --threads=1 --project=$(dirname(@__DIR__)) $(probe) $(directory)`,
            "WANNIERNLQG_USE_MPI" => "1",
            "WANNIERNLQG_BENCHMARK_DEFER_MPI_FINALIZE" => "1",
            "OMP_NUM_THREADS" => "1",
            "MKL_NUM_THREADS" => "1",
            "OPENBLAS_NUM_THREADS" => "1",
            "VECLIB_MAXIMUM_THREADS" => "1",
        )
        Base.run(command)
        @test isfile(joinpath(directory, "mdrs_mpi_sc_conv.dat"))
        @test isfile(joinpath(directory, "metadata.txt"))
        @test isfile(joinpath(directory, "progress.jsonl"))
        @test read(joinpath(directory, "mdrs_mpi_postrun_rank0.marker"), String) ==
              "root publication and collective prepared payload verified\n"
        @test read(joinpath(directory, "mdrs_mpi_postrun_rank1.marker"), String) ==
              "non-root prepared payload and publication path verified\n"
        @test read(joinpath(directory, "mdrs_mpi_packed_rank0.marker"), String) ==
              "Packed HDF5 node-shared payload and release verified\n"
        @test read(joinpath(directory, "mdrs_mpi_packed_rank1.marker"), String) ==
              "Packed HDF5 node-shared payload and release verified\n"
        @test read(joinpath(directory, "mdrs_mpi_rank_private_rank0.marker"), String) ==
              "Legacy and Packed HDF5 rank-private parity verified\n"
        @test read(joinpath(directory, "mdrs_mpi_rank_private_rank1.marker"), String) ==
              "Legacy and Packed HDF5 rank-private parity verified\n"
    end
end
