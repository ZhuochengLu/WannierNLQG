module ParallelepipedRegionMpiTests
using WannierNLQG, MPI, JSON3, Test
include(joinpath(@__DIR__, "support", "FullMPIRankProfile.jl"))

"""Use the existing MPI executable and project, with explicit single-threaded libraries."""
function probe_command(destination; ranks = nothing)
    julia =
        `$(Base.julia_cmd()) --startup-file=no --threads=1 --project=$(dirname(@__DIR__)) $(joinpath(@__DIR__, "support", "ParallelepipedRegionMpiProbe.jl")) $destination`
    command = ranks === nothing ? julia : `$(MPI.mpiexec()) -n $ranks $julia`
    return addenv(
        command,
        "WANNIERNLQG_USE_MPI" => ranks === nothing ? "0" : "1",
        "JULIA_NUM_THREADS" => "1",
        "OPENBLAS_NUM_THREADS" => "1",
        "OMP_NUM_THREADS" => "1",
        "MKL_NUM_THREADS" => "1",
        "VECLIB_MAXIMUM_THREADS" => "1",
    )
end

@testset "Parallelepiped global index and public tensor reduction: serial/MPI1/MPI2" begin
    mktempdir() do directory
        records = Dict{String, Any}()
        for (label, ranks) in [
            ("serial", nothing);
            [("mpi$ranks", ranks) for ranks in FullMPIRankProfile.affine_ranks()]
        ]
            destination = joinpath(directory, label)
            mkpath(destination)
            log = read(probe_command(destination; ranks), String)
            @test occursin("PARALLELEPIPED_REGION_MPI_PROBE_PASS", log)
            records[label] = JSON3.read(read(joinpath(destination, "numerical.json"), String))
        end
        for ranks in FullMPIRankProfile.affine_ranks()
            label = "mpi$ranks"
            @test Set(keys(records[label])) == Set(keys(records["serial"]))
            for mesh in keys(records["serial"])
                reference, actual = records["serial"][mesh], records[label][mesh]
                @test Set(keys(reference)) == Set(keys(actual))
                for table in keys(reference)
                    @test reference[table] == actual[table]
                end
            end
        end
        if FullMPIRankProfile.is_air_profile()
            # Actual model callbacks prove normal empty ownership, rather than
            # inferring it from the rank count or from an exception-only case.
            key = string((1, 1, 1))
            serial = JSON3.read(read(joinpath(directory, "serial", "rank-0.json"), String))
            reference = serial.owned_cartesian_points[key]
            @test isempty(serial.unknown_cartesian_points[key])
            @test !isempty(serial.preflight_cartesian_points[key])
            @test Set(Tuple.(serial.observed_cartesian_points[key])) ==
                  union(Set(Tuple.(reference)), Set(Tuple.(serial.preflight_cartesian_points[key])))
            @test !isempty(reference)
            for ranks in FullMPIRankProfile.affine_ranks()
                rank_records = [
                    JSON3.read(read(joinpath(directory, "mpi$ranks", "rank-$rank.json"), String)) for rank in 0:(ranks - 1)
                ]
                for record in rank_records
                    @test isempty(record.unknown_cartesian_points[key])
                    @test !isempty(record.preflight_cartesian_points[key])
                    @test Set(Tuple.(record.observed_cartesian_points[key])) == union(
                        Set(Tuple.(record.owned_cartesian_points[key])),
                        Set(Tuple.(record.preflight_cartesian_points[key])),
                    )
                end
                owned = [record.owned_cartesian_points[key] for record in rank_records]
                @test count(!isempty, owned) == 1
                @test only(filter(!isempty, owned)) == reference
                @test count(isempty, owned) == ranks - 1
            end
        end
    end
end
end
