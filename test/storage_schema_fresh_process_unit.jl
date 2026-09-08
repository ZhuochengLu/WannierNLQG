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
        new_checkpoint = joinpath(directory, "checkpoint.h5")
        w = WannierNLQG.Wannierization
        w.write_wannierization_checkpoint_hdf5(
            new_checkpoint,
            w.read_wannierization_checkpoint_hdf5(old_checkpoint),
        )
        probe = raw"""
        using WannierNLQG, Test
        w = WannierNLQG.Wannierization
        old = w.read_wannierization_checkpoint_hdf5(ARGS[1])
        new = w.read_wannierization_checkpoint_hdf5(ARGS[2])
        @assert old.input_summary["checkpoint_schema_version"] == "2.28"
        @assert new.input_summary["checkpoint_schema_version"] == "1.0"
        @assert old.input_summary["construction_policy"] == new.input_summary["construction_policy"] == "strict"
        @assert new.input_summary["construction_policy_contract"] == "diagnostic_construction_v1"
        @assert old.input_summary["restart_eligible"] == new.input_summary["restart_eligible"] == "true"
        @assert old.v_matrix == new.v_matrix
        @assert old.spreads_angstrom2 == new.spreads_angstrom2
        @assert isequal(old.history, new.history)
        old_bundle = WannierNLQG.IO.read_real_space_operator_bundle(ARGS[3])
        new_bundle = WannierNLQG.IO.read_real_space_operator_bundle(ARGS[4])
        @assert old_bundle.manifest.schema_version == "6.3"
        @assert new_bundle.manifest.schema_version == "1.0"
        @assert old_bundle.manifest.operator_qualification_sha256 == new_bundle.manifest.operator_qualification_sha256
        for kind in old_bundle.manifest.inventory
            @assert old_bundle.operators[kind].data == new_bundle.operators[kind].data
        end
        println("STORAGE_SCHEMA_FRESH_PROCESS_PASS")
        """
        command =
            `$(Base.julia_cmd()) --startup-file=no --threads=1 --project=$(root) -e $(probe) $(old_checkpoint) $(new_checkpoint) $(old_bundle) $(new_bundle)`
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

@testset "Publication lattice probe accepts current and historical Packed schemas" begin
    root = normpath(joinpath(@__DIR__, ".."))
    probe = joinpath(root, "scripts", "visualization", "model_lattice_probe.jl")
    old = joinpath(@__DIR__, "fixtures", "schema_compatibility", "packed_6_3.h5")
    current = joinpath(root, "examples", "fixtures", "synthetic_runtime", "synthetic_operators.h5")
    lattices = []
    for (path, version) in ((old, "6.3"), (current, "1.0"))
        command = `$(Base.julia_cmd()) --startup-file=no --project=$(root) $(probe) $(path)`
        payload = JSON3.read(read(command, String))
        @test payload.bundle_schema_version == version
        @test payload.schema_version == "1.0"
        push!(lattices, payload.lattice_rows_angstrom)
    end
    @test lattices[1] == lattices[2]
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
