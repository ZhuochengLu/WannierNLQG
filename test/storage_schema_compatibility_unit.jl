using HDF5
using SHA
using Test
using WannierNLQG

@testset "Current storage identity rejects unmigrated legacy files" begin
    fixture_root = joinpath(@__DIR__, "fixtures", "schema_compatibility")
    for line in eachline(joinpath(fixture_root, "SHA256SUMS"))
        digest, filename = split(line; limit = 2)
        @test bytes2hex(SHA.sha256(read(joinpath(fixture_root, strip(filename))))) == digest
    end

    io = WannierNLQG.IO
    w = WannierNLQG.Wannierization
    solver = first(w._load_wannierization_extension!()).SolverCheckpoint
    @test solver.WANNIERIZATION_CHECKPOINT_SCHEMA_VERSION == "3.0"
    @test solver.WANNIERIZATION_CHECKPOINT_READABLE_SCHEMA_VERSIONS == ()
    @test io.OPERATOR_BUNDLE_SCHEMA_VERSION == "3.0"

    old_checkpoint = joinpath(fixture_root, "restart_checkpoint_2_28.h5")
    old_abnormal_checkpoint = joinpath(fixture_root, "checkpoint_2_28.h5")
    old_bundle = joinpath(fixture_root, "packed_6_3.h5")

    for path in (old_checkpoint, old_abnormal_checkpoint)
        error = try
            w.read_wannierization_checkpoint_hdf5(path)
            nothing
        catch caught
            caught
        end
        @test error isa ArgumentError
        @test occursin("CHECKPOINT_SCHEMA_UNSUPPORTED", sprint(showerror, error))
    end

    for reader in (
        io.read_real_space_operator_bundle_manifest,
        io.read_real_space_operator_bundle,
        io.read_operator_bundle_payload,
    )
        error = try
            reader(old_bundle)
            nothing
        catch caught
            caught
        end
        @test error isa ArgumentError
        @test occursin("MODEL_SCHEMA_UNSUPPORTED", sprint(showerror, error))
    end

    mktempdir() do directory
        relabeled_checkpoint = joinpath(directory, "relabeled-checkpoint.h5")
        cp(old_checkpoint, relabeled_checkpoint)
        chmod(relabeled_checkpoint, 0o600)
        HDF5.h5open(relabeled_checkpoint, "r+") do handle
            HDF5.delete_attribute(handle, "schema_version")
            HDF5.attributes(handle)["schema_version"] = "1.1"
        end
        @test_throws ArgumentError w.read_wannierization_checkpoint_hdf5(relabeled_checkpoint)

        relabeled_bundle = joinpath(directory, "relabeled-bundle.h5")
        cp(old_bundle, relabeled_bundle)
        chmod(relabeled_bundle, 0o600)
        HDF5.h5open(relabeled_bundle, "r+") do handle
            HDF5.delete_attribute(handle, "schema_version")
            HDF5.attributes(handle)["schema_version"] = "1.1"
        end
        @test_throws ArgumentError io.read_real_space_operator_bundle(relabeled_bundle)
    end
end

@testset "Producer identity compatibility preserves the independent Packed wire gate" begin
    io = WannierNLQG.IO
    fixture = joinpath(
        @__DIR__,
        "..",
        "examples",
        "fixtures",
        "synthetic_runtime",
        "synthetic_operators.h5",
    )
    readers = (
        io.read_real_space_operator_bundle_manifest,
        io.read_real_space_operator_bundle,
        io.read_operator_bundle_payload,
    )
    mktempdir() do directory
        current_wire = joinpath(directory, "current-wire-111-producer.h5")
        cp(fixture, current_wire)
        chmod(current_wire, 0o600)
        HDF5.h5open(current_wire, "r+") do handle
            haskey(HDF5.attributes(handle), "wanniernlqg_version") &&
                HDF5.delete_attribute(handle, "wanniernlqg_version")
            HDF5.attributes(handle)["wanniernlqg_version"] = "1.1.1"
        end
        io.adopt_real_space_operator_bundle(current_wire)
        for reader in readers
            @test reader(current_wire) !== nothing
        end
        HDF5.h5open(current_wire, "r+") do handle
            HDF5.delete_attribute(handle, "schema_version")
            HDF5.attributes(handle)["schema_version"] = "1.1"
        end
        for reader in readers
            @test_throws ArgumentError reader(current_wire)
        end
    end
end
