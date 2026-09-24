using Test
using WannierNLQG
using HDF5
using JSON3

@testset "Public storage schema readback in a fresh process" begin
    root = normpath(joinpath(@__DIR__, ".."))
    fixtures = joinpath(@__DIR__, "fixtures", "schema_compatibility")
    old_checkpoint = joinpath(fixtures, "restart_checkpoint_2_28.h5")
    old_bundle = joinpath(fixtures, "packed_6_3.h5")
    new_bundle =
        joinpath(root, "examples", "fixtures", "synthetic_runtime", "synthetic_operators.h5")
    mktempdir() do directory
        probe = raw"""
        using WannierNLQG, Test
        w = WannierNLQG.Wannierization
        checkpoint_error = try
            w.read_wannierization_checkpoint_hdf5(ARGS[1])
            nothing
        catch caught
            caught
        end
        @assert checkpoint_error isa ArgumentError
        @assert occursin("CHECKPOINT_MIGRATION_REQUIRED", sprint(showerror, checkpoint_error))
        bundle_error = try
            WannierNLQG.IO.read_real_space_operator_bundle(ARGS[2])
            nothing
        catch caught
            caught
        end
        @assert bundle_error isa ArgumentError
        @assert occursin("operator-bundle migration required", sprint(showerror, bundle_error))
        new_bundle = WannierNLQG.IO.read_real_space_operator_bundle(ARGS[3])
        @assert new_bundle.manifest.schema_version == "1.1"
        println("STORAGE_SCHEMA_FRESH_PROCESS_PASS")
        """
        command =
            `$(Base.julia_cmd()) --startup-file=no --threads=1 --project=$(root) -e $(probe) $(old_checkpoint) $(old_bundle) $(new_bundle)`
        output = read(
            addenv(
                command,
                "OPENBLAS_NUM_THREADS" => "1",
                "OMP_NUM_THREADS" => "1",
                "VECLIB_MAXIMUM_THREADS" => "1",
            ),
            String,
        )
        @test occursin("STORAGE_SCHEMA_FRESH_PROCESS_PASS", output)
    end
end

@testset "Publication lattice probe accepts only current Packed schema" begin
    root = normpath(joinpath(@__DIR__, ".."))
    probe = joinpath(root, "scripts", "visualization", "model_lattice_probe.jl")
    old = joinpath(@__DIR__, "fixtures", "schema_compatibility", "packed_6_3.h5")
    current = joinpath(root, "examples", "fixtures", "synthetic_runtime", "synthetic_operators.h5")
    old_command = `$(Base.julia_cmd()) --startup-file=no --project=$(root) $(probe) $(old)`
    @test !success(pipeline(old_command; stdout = devnull, stderr = devnull))
    command = `$(Base.julia_cmd()) --startup-file=no --project=$(root) $(probe) $(current)`
    payload = JSON3.read(read(command, String))
    @test payload.bundle_schema_version == "1.1"
    @test payload.schema_version == "1.0"
    @test size(payload.lattice_rows_angstrom) == (3,)
    mktempdir() do directory
        invalid = joinpath(directory, "unsupported.h5")
        cp(current, invalid)
        HDF5.h5open(invalid, "r+") do handle
            HDF5.delete_attribute(handle, "schema_version")
            HDF5.attributes(handle)["schema_version"] = "unknown"
        end
        command = `$(Base.julia_cmd()) --startup-file=no --project=$(root) $(probe) $(invalid)`
        @test !success(pipeline(command; stdout = devnull, stderr = devnull))
    end
end
