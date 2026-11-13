module CheckpointReceiptRecoverySupport
using WannierNLQG, HDF5, JSON3, MPI
isdefined(@__MODULE__, :ArchivedCheckpointMathTestSupport) ||
    include(joinpath(@__DIR__, "ArchivedCheckpointMathTestSupport.jl"))
const W = WannierNLQG.Wannierization
const SOLVER = first(W._load_wannierization_extension!()).SolverCheckpoint

function qualified_input(destination, role)
    root = Base.pkgdir(WannierNLQG)
    asset = joinpath(
        root,
        "test",
        "fixtures",
        "current_checkpoint_workload",
        "synthetic.wannierization.h5",
    )
    receipt = joinpath(destination, "qualified-input-$(role).commit.toml")
    W.adopt_wannierization_checkpoint_hdf5(asset; receipt_path = receipt)
    result = W.read_wannierization_checkpoint_hdf5(asset; receipt_path = receipt)
    return result
end

function definition_bytes(result; version = :v2_30)
    stream = IOBuffer()
    SOLVER.write_checkpoint_definition(stream, result; version)
    return take!(stream)
end

function produce_failure(destination)
    mkpath(destination)
    @assert !MPI.Initialized()
    result = qualified_input(destination, "producer")
    ArchivedCheckpointMathTestSupport.assert_current_checkpoint_math(
        result,
        joinpath(
            Base.pkgdir(WannierNLQG),
            "test",
            "fixtures",
            "current_checkpoint_workload",
            "SOLUTION_REFERENCE.json",
        ),
    )
    expected = definition_bytes(result)
    oracle =
        joinpath(Base.pkgdir(WannierNLQG), "test", "fixtures", "checkpoint_numeric_reference.bin")
    legacy_asset = joinpath(
        Base.pkgdir(WannierNLQG),
        "test",
        "fixtures",
        "first_use_portable",
        "assets",
        "frozen_solver",
        "synthetic.current.wannierization.h5",
    )
    legacy = ArchivedCheckpointMathTestSupport.read_archived_checkpoint_math(legacy_asset, oracle)
    @assert all(
        all(isfinite, getfield(result, field)) for
        field in (:v_matrix, :wannier_centers_cartesian, :spreads_angstrom2)
    )
    write(joinpath(destination, "expected_definition.bin"), expected)
    checkpoint = joinpath(destination, "accepted.wannierization.h5")
    @assert !ispath(checkpoint)
    caught = nothing
    try
        SOLVER.write_wannierization_checkpoint_hdf5(
            checkpoint,
            result;
            publish_receipt = function (args...; kwargs...)
                error("INJECTED_RECEIPT_STAGE_FAILURE_AFTER_COMPLETE_HDF_CLOSE")
            end,
        )
    catch exception
        caught = sprint(showerror, exception)
    end
    @assert caught !== nothing && occursin("INJECTED_RECEIPT_STAGE_FAILURE", caught)
    @assert isfile(checkpoint) && !isfile(checkpoint * ".commit.toml")
    strict_rejected = try
        W.read_wannierization_checkpoint_hdf5(checkpoint)
        false
    catch exception
        exception isa ArgumentError
    end
    @assert strict_rejected
    record = Dict(
        "schema" => "wanniernlqg.checkpoint-receipt-failure/1",
        "source_root" => realpath(Base.pkgdir(WannierNLQG)),
        "julia_version" => string(VERSION),
        "mpi_initialized" => MPI.Initialized(),
        "payload_persisted" => true,
        "strict_reader_rejects_unpublished" => strict_rejected,
        "failure_stage" => "publication",
        "earliest_restart_stage" => "publication",
        "definition_bytes" => length(expected),
        "solver_executed" => false,
        "archived_mathematics_equal" => true,
        "qualified_oracle_equal" => false,
        "legacy_full_byte_identity" => "NOT_A_CURRENT_WIRE_CLAIM",
        "error" => caught,
    )
    open(joinpath(destination, "publication_failure.json"), "w") do stream
        JSON3.write(stream, record)
    end
    return record
end

function recover_publication(destination)
    @assert !MPI.Initialized()
    checkpoint = joinpath(destination, "accepted.wannierization.h5")
    @assert isfile(checkpoint) && !isfile(checkpoint * ".commit.toml")
    W.adopt_wannierization_checkpoint_hdf5(checkpoint)
    result = W.read_wannierization_checkpoint_hdf5(checkpoint)
    actual = definition_bytes(result)
    write(joinpath(destination, "recovered_definition.bin"), actual)
    @assert actual == read(joinpath(destination, "expected_definition.bin"))
    reference = qualified_input(destination, "consumer")
    arrays = [
        Dict(
            "name" => string(field),
            "shape_equal" => size(getfield(reference, field)) == size(getfield(result, field)),
            "bytes_equal" =>
                reinterpret(UInt8, vec(getfield(reference, field))) ==
                reinterpret(UInt8, vec(getfield(result, field))),
            "maximum_absolute_error" => maximum(
                abs.(getfield(reference, field) .- getfield(result, field));
                init = 0.0,
            ),
        ) for field in (:v_matrix, :wannier_centers_cartesian, :spreads_angstrom2)
    ]
    @assert all(
        row -> row["shape_equal"] && row["bytes_equal"] && row["maximum_absolute_error"] == 0,
        arrays,
    )
    record = Dict(
        "schema" => "wanniernlqg.checkpoint-publication-recovered/1",
        "source_root" => realpath(Base.pkgdir(WannierNLQG)),
        "julia_version" => string(VERSION),
        "mpi_initialized" => MPI.Initialized(),
        "definition_equal" => true,
        "definition_bytes" => length(actual),
        "arrays" => arrays,
        "receipt_schema" =>
            WannierNLQG.IO.read_task_input_file(checkpoint * ".commit.toml").document["schema"],
        "solver_executed" => false,
        "restart_stage" => "publication",
    )
    open(joinpath(destination, "publication_recovery.json"), "w") do stream
        JSON3.write(stream, record)
    end
    return record
end
end
