using JSON3
using MPI
using SHA
using WannierNLQG
include(joinpath(@__DIR__, "OperatorBundleTestSupport.jl"))
import WannierNLQG.Runtime:
    mpi_benchmark_finalize!,
    mpi_process_rank,
    load_runtime_model_and_sources,
    release_runtime_storage!,
    OperatorDemandPlan,
    RunContext,
    NormalizedTaskSpec

length(ARGS) == 1 || error("usage: MDRSRuntimeMpiProbe.jl OUTPUT_ROOT")

rank = mpi_process_rank()
root = abspath(only(ARGS))
model_file = joinpath(root, "mdrs_runtime_tb.dat")
wsvec_file = joinpath(root, "mdrs_runtime_wsvec.dat")
bundle_file = joinpath(root, "mdrs_runtime_operators.h5")
fixture_ready_file = joinpath(root, "mdrs_runtime_fixture.ready")

function write_runtime_tb(path)
    open(path, "w") do io
        println(io, "WannierNLQG MDRS MPI fixture")
        println(io, "1.0 0.0 0.0")
        println(io, "0.0 1.0 0.0")
        println(io, "0.0 0.0 1.0")
        println(io, 2)
        println(io, 2)
        println(io, "2 4")
        for (r_index, r_vector) in enumerate(((0, 0, 0), (1, 0, 0)))
            println(io)
            println(io, join(r_vector, " "))
            for column in 1:2, row in 1:2
                value = if r_index == 1
                    row == column ? (row == 1 ? -2.0 : 2.0) : 0.0
                else
                    row == column ? (row == 1 ? 4.0 : -4.0) : 2.0
                end
                println(io, "$(row) $(column) $(value) 0.0")
            end
        end
        for (r_index, r_vector) in enumerate(((0, 0, 0), (1, 0, 0)))
            println(io)
            println(io, join(r_vector, " "))
            for column in 1:2, row in 1:2
                values = if r_index == 1
                    row == column ? (0.5, 0.0, 0.0) : (0.0, 0.0, 0.0)
                else
                    sign = row == column ? (row == 1 ? 1.0 : -1.0) : 0.5
                    (2.0 * sign, sign, 0.5 * sign)
                end
                println(io, "$(row) $(column) $(values[1]) 0.0 $(values[2]) 0.0 $(values[3]) 0.0")
            end
        end
    end
    return path
end

function write_runtime_wsvec(path)
    fixed(values...) = join(lpad.(string.(values), 5))
    open(path, "w") do io
        println(io, "written on 04Sep2026 at 00:00:00 use_ws_distance=.true.")
        for r_vector in ((0, 0, 0), (1, 0, 0)), left in 1:2, right in 1:2
            println(io, fixed(r_vector..., left, right))
            if r_vector == (0, 0, 0)
                println(io, fixed(1))
                println(io, fixed(0, 0, 0))
            else
                println(io, fixed(2))
                println(io, fixed(-2, 0, 0))
                println(io, fixed(0, 0, 0))
            end
        end
    end
    return path
end

function record_check!(errors, condition, message)
    condition || push!(errors, message)
    return nothing
end

function runtime_model_payload_digest(model)
    payload_buffer = IOBuffer()
    write(payload_buffer, reinterpret(UInt8, Int64.(model.r_vectors)))
    write(payload_buffer, reinterpret(UInt8, Int64.(model.r_degeneracies)))
    write(payload_buffer, reinterpret(UInt8, vec(model.hamiltonian_r)))
    write(payload_buffer, reinterpret(UInt8, vec(model.position_r)))
    return SHA.sha256(take!(payload_buffer))
end

function record_rank_digest_agreement!(errors, digest, label)
    all_digests = reshape(MPI.Allgather(digest, MPI.COMM_WORLD), length(digest), :)
    all(all_digests[:, column] == digest for column in axes(all_digests, 2)) ||
        push!(errors, "MPI ranks disagree on $(label) payload SHA")
    return nothing
end

function release_twice_and_record!(errors, loaded, label)
    try
        release_runtime_storage!(loaded)
        release_runtime_storage!(loaded)
    catch exception
        push!(errors, "$(label) release was not idempotent: $(sprint(showerror, exception))")
    end
    return nothing
end

function collective_failure_message(errors, rank)
    counts = vec(MPI.Allgather(Int32[length(errors)], MPI.COMM_WORLD))
    any(count -> count > 0, counts) || return nothing
    local_details = isempty(errors) ? "peer rank reported validation errors" : join(errors, "; ")
    return "MDRS MPI validation failed on rank $(rank); error_counts=$(counts): $(local_details)"
end

if rank == 0
    mkpath(root)
    write_runtime_tb(model_file)
    write_runtime_wsvec(wsvec_file)
    input_model = WannierNLQG.IO.read_wannier_tb(model_file)
    operators = Dict(
        WannierNLQG.Core.REAL_SPACE_HAMILTONIAN => WannierNLQG.Core.RealSpaceOperator(
            WannierNLQG.Core.RealSpaceOperatorSymmetrySpec(
                WannierNLQG.Core.REAL_SPACE_HAMILTONIAN,
                0,
                1,
                1,
            ),
            input_model.r_vectors,
            input_model.hamiltonian_r,
        ),
        WannierNLQG.Core.REAL_SPACE_POSITION => WannierNLQG.Core.RealSpaceOperator(
            WannierNLQG.Core.RealSpaceOperatorSymmetrySpec(
                WannierNLQG.Core.REAL_SPACE_POSITION,
                1,
                -1,
                1,
            ),
            input_model.r_vectors,
            input_model.position_r,
        ),
    )
    WannierNLQG.IO.write_real_space_operator_bundle(
        bundle_file,
        input_model.lattice,
        input_model.r_degeneracies,
        operators;
        profile = :hamiltonian_position,
        paired_tb_sha256 = WannierNLQG.Runtime.checksum_file(model_file),
        geometry = test_operator_bundle_geometry(
            input_model.lattice,
            input_model.r_degeneracies,
            operators,
        ),
    )
    touch(fixture_ready_file)
else
    deadline = time() + 30.0
    while !isfile(fixture_ready_file)
        time() < deadline || error("timed out waiting for MPI root fixture")
        sleep(0.01)
    end
end

cfg = WannierNLQG.Runtime.EffectiveTaskConfig(
    tasks = [("SC", "Conventional", "Integral")],
    model_file = model_file,
    output_root = root,
    system_name = "mdrs_mpi",
    k_mesh = (2, 2),
    fourier_backend = "direct",
    photon_energies = [0.2],
    fermi_energy = 0.0,
    real_space_replica_policy = "minimum_distance",
    wsvec_file = wsvec_file,
    mp_grid = nothing,
    progress_enabled = true,
)
result = WannierNLQG.run(cfg)
validation_errors = String[]
record_check!(
    validation_errors,
    isempty(WannierNLQG.Runtime.ACTIVE_MPI_SHARED_OPERATOR_STORAGES),
    "shared storage remained registered after Runtime.run",
)

# Exercise the production root-prepare/distribute path again and inspect the
# actual prepared component payload received by every rank.
demand = OperatorDemandPlan(
    WannierNLQG.Core.RealSpaceOperatorKind[
        WannierNLQG.Core.REAL_SPACE_HAMILTONIAN,
        WannierNLQG.Core.REAL_SPACE_POSITION,
    ],
    Dict(
        WannierNLQG.Core.REAL_SPACE_HAMILTONIAN => [(Int8(0), Int8(0))],
        WannierNLQG.Core.REAL_SPACE_POSITION => [(Int8(axis), Int8(0)) for axis in 1:3],
    ),
    false,
)
ctx = RunContext(
    NormalizedTaskSpec[],
    root,
    model_file,
    "",
    :legacy,
    nothing,
    nothing,
    2,
    demand,
    "mdrs_mpi",
    "",
    "",
    "",
    nothing,
)
loaded = load_runtime_model_and_sources(ctx, cfg)
model = loaded.model
record_check!(
    validation_errors,
    loaded.read_mode == :mpi_node_shared,
    "Legacy load did not use node-shared storage",
)
record_check!(
    validation_errors,
    loaded.storage_owner !== nothing,
    "Legacy node-shared load did not return a storage owner",
)
expected_hamiltonian = zeros(ComplexF64, 2, 2, 3)
expected_hamiltonian[:, :, 1] .= ComplexF64[0.5 0.25; 0.25 -0.5]
expected_hamiltonian[:, :, 2] .= ComplexF64[-1.0 0.0; 0.0 1.0]
expected_hamiltonian[:, :, 3] .= expected_hamiltonian[:, :, 1]
expected_position = zeros(ComplexF64, 2, 2, 3, 3)
expected_position[:, :, 1, 1] .= ComplexF64[0.25 0.125; 0.125 -0.25]
expected_position[:, :, 2, 1] .= ComplexF64[0.125 0.0625; 0.0625 -0.125]
expected_position[:, :, 3, 1] .= ComplexF64[0.0625 0.03125; 0.03125 -0.0625]
expected_position[:, :, 1, 2] .= ComplexF64[0.25 0.0; 0.0 0.25]
expected_position[:, :, :, 3] .= expected_position[:, :, :, 1]
record_check!(
    validation_errors,
    model.r_vectors == [-1 0 1; 0 0 0; 0 0 0],
    "Legacy node-shared load returned incorrect prepared R support",
)
record_check!(
    validation_errors,
    model.r_degeneracies == ones(Int, 3),
    "Legacy node-shared load returned non-unit prepared degeneracies",
)
record_check!(
    validation_errors,
    model.hamiltonian_r == expected_hamiltonian,
    "Legacy node-shared load returned incorrect prepared Hamiltonian",
)
record_check!(
    validation_errors,
    model.position_r == expected_position,
    "Legacy node-shared load returned incorrect prepared position",
)
legacy_shared_digest = runtime_model_payload_digest(model)
legacy_shared_summary = loaded.replica_summary
all_support = MPI.Allgather(Int[model.num_r_vectors], MPI.COMM_WORLD)
record_check!(
    validation_errors,
    all(value == model.num_r_vectors for value in all_support),
    "MPI ranks disagree on prepared Legacy R support",
)
legacy_shared_owner = loaded.storage_owner
release_twice_and_record!(validation_errors, loaded, "Legacy node-shared storage")
MPI.Barrier(MPI.COMM_WORLD)
record_check!(
    validation_errors,
    legacy_shared_owner !== nothing && legacy_shared_owner.released,
    "Legacy node-shared owner was not marked released",
)
record_check!(
    validation_errors,
    isempty(WannierNLQG.Runtime.ACTIVE_MPI_SHARED_OPERATOR_STORAGES),
    "shared storage remained registered after Legacy release",
)
record_rank_digest_agreement!(validation_errors, legacy_shared_digest, "Legacy node-shared")

# Exercise the same node-shared lifecycle for a Packed HDF5 component bundle.
packed_cfg = WannierNLQG.Runtime.EffectiveTaskConfig(
    tasks = [("SC", "Conventional", "Integral")],
    model_file = model_file,
    real_space_operator_bundle_file = bundle_file,
    output_root = root,
    system_name = "mdrs_mpi_packed",
    k_mesh = (2, 2),
    fourier_backend = "direct",
    photon_energies = [0.2],
    fermi_energy = 0.0,
    real_space_replica_policy = "input",
    progress_enabled = false,
)
packed_ctx = RunContext(
    NormalizedTaskSpec[],
    root,
    bundle_file,
    "",
    :packed_hdf5,
    bundle_file,
    model_file,
    2,
    demand,
    "mdrs_mpi_packed",
    "",
    "",
    "",
    nothing,
)
packed_loaded = load_runtime_model_and_sources(packed_ctx, packed_cfg)
packed_model = packed_loaded.model
record_check!(
    validation_errors,
    packed_loaded.read_mode == :mpi_node_shared,
    "Packed HDF5 load did not use node-shared storage",
)
record_check!(
    validation_errors,
    packed_loaded.storage_owner !== nothing,
    "Packed HDF5 node-shared load did not return a storage owner",
)
expected_input_hamiltonian = zeros(ComplexF64, 2, 2, 2)
expected_input_hamiltonian[:, :, 1] .= ComplexF64[-2.0 0.0; 0.0 2.0]
expected_input_hamiltonian[:, :, 2] .= ComplexF64[4.0 2.0; 2.0 -4.0]
expected_input_position = zeros(ComplexF64, 2, 2, 3, 2)
expected_input_position[:, :, 1, 1] .= ComplexF64[0.5 0.0; 0.0 0.5]
expected_input_position[:, :, 1, 2] .= ComplexF64[2.0 1.0; 1.0 -2.0]
expected_input_position[:, :, 2, 2] .= ComplexF64[1.0 0.5; 0.5 -1.0]
expected_input_position[:, :, 3, 2] .= ComplexF64[0.5 0.25; 0.25 -0.5]
record_check!(
    validation_errors,
    packed_model.r_vectors == [0 1; 0 0; 0 0],
    "Packed HDF5 node-shared load returned incorrect R support",
)
record_check!(
    validation_errors,
    packed_model.r_degeneracies == [2, 4],
    "Packed HDF5 node-shared load returned incorrect degeneracies",
)
record_check!(
    validation_errors,
    packed_model.hamiltonian_r == expected_input_hamiltonian,
    "Packed HDF5 node-shared Hamiltonian disagrees with the input oracle",
)
record_check!(
    validation_errors,
    packed_model.position_r == expected_input_position,
    "Packed HDF5 node-shared position disagrees with the input oracle",
)
packed_shared_digest = runtime_model_payload_digest(packed_model)
packed_shared_summary = packed_loaded.replica_summary
packed_shared_owner = packed_loaded.storage_owner
release_twice_and_record!(validation_errors, packed_loaded, "Packed HDF5 node-shared storage")
MPI.Barrier(MPI.COMM_WORLD)
record_check!(
    validation_errors,
    packed_shared_owner !== nothing && packed_shared_owner.released,
    "Packed HDF5 node-shared owner was not marked released",
)
record_check!(
    validation_errors,
    isempty(WannierNLQG.Runtime.ACTIVE_MPI_SHARED_OPERATOR_STORAGES),
    "shared storage remained registered after Packed HDF5 release",
)
record_rank_digest_agreement!(validation_errors, packed_shared_digest, "Packed HDF5 node-shared")

isempty(validation_errors) && write(
    joinpath(root, "mdrs_mpi_packed_rank$(rank).marker"),
    "Packed HDF5 node-shared payload and release verified\n",
)

# Force the public rank-private fallback in the same MPI job and require exact
# parity with both node-shared transports after their collective release.
disable_shared_key = "WANNIERNLQG_DISABLE_MPI_SHARED"
disable_shared_was_set = haskey(ENV, disable_shared_key)
disable_shared_previous = get(ENV, disable_shared_key, "")
legacy_private_digest = zeros(UInt8, length(legacy_shared_digest))
packed_private_digest = zeros(UInt8, length(packed_shared_digest))
try
    ENV[disable_shared_key] = "1"
    MPI.Barrier(MPI.COMM_WORLD)

    legacy_private_loaded = nothing
    try
        legacy_private_loaded = load_runtime_model_and_sources(ctx, cfg)
        legacy_private_model = legacy_private_loaded.model
        record_check!(
            validation_errors,
            legacy_private_loaded.read_mode == :mpi_rank_private,
            "Legacy fallback did not use rank-private storage",
        )
        record_check!(
            validation_errors,
            legacy_private_loaded.storage_owner === nothing,
            "Legacy rank-private fallback unexpectedly returned a storage owner",
        )
        legacy_private_digest .= runtime_model_payload_digest(legacy_private_model)
        record_check!(
            validation_errors,
            legacy_private_digest == legacy_shared_digest,
            "Legacy rank-private payload is not byte-exact with node-shared payload",
        )
        record_check!(
            validation_errors,
            legacy_private_loaded.replica_summary == legacy_shared_summary,
            "Legacy rank-private replica summary differs from node-shared summary",
        )
    catch exception
        push!(
            validation_errors,
            "Legacy rank-private validation raised $(sprint(showerror, exception))",
        )
    finally
        legacy_private_loaded === nothing || release_twice_and_record!(
            validation_errors,
            legacy_private_loaded,
            "Legacy rank-private storage",
        )
    end
    MPI.Barrier(MPI.COMM_WORLD)
    record_check!(
        validation_errors,
        isempty(WannierNLQG.Runtime.ACTIVE_MPI_SHARED_OPERATOR_STORAGES),
        "shared storage was registered during Legacy rank-private fallback",
    )
    record_rank_digest_agreement!(validation_errors, legacy_private_digest, "Legacy rank-private")

    packed_private_loaded = nothing
    try
        packed_private_loaded = load_runtime_model_and_sources(packed_ctx, packed_cfg)
        packed_private_model = packed_private_loaded.model
        record_check!(
            validation_errors,
            packed_private_loaded.read_mode == :mpi_rank_private,
            "Packed HDF5 fallback did not use rank-private storage",
        )
        record_check!(
            validation_errors,
            packed_private_loaded.storage_owner === nothing,
            "Packed HDF5 rank-private fallback unexpectedly returned a storage owner",
        )
        record_check!(
            validation_errors,
            packed_private_model.hamiltonian_r == expected_input_hamiltonian,
            "Packed HDF5 rank-private Hamiltonian disagrees with the input oracle",
        )
        record_check!(
            validation_errors,
            packed_private_model.position_r == expected_input_position,
            "Packed HDF5 rank-private position disagrees with the input oracle",
        )
        packed_private_digest .= runtime_model_payload_digest(packed_private_model)
        record_check!(
            validation_errors,
            packed_private_digest == packed_shared_digest,
            "Packed HDF5 rank-private payload is not byte-exact with node-shared payload",
        )
        record_check!(
            validation_errors,
            packed_private_loaded.replica_summary == packed_shared_summary,
            "Packed HDF5 rank-private replica summary differs from node-shared summary",
        )
    catch exception
        push!(
            validation_errors,
            "Packed HDF5 rank-private validation raised $(sprint(showerror, exception))",
        )
    finally
        packed_private_loaded === nothing || release_twice_and_record!(
            validation_errors,
            packed_private_loaded,
            "Packed HDF5 rank-private storage",
        )
    end
    MPI.Barrier(MPI.COMM_WORLD)
    record_check!(
        validation_errors,
        isempty(WannierNLQG.Runtime.ACTIVE_MPI_SHARED_OPERATOR_STORAGES),
        "shared storage was registered during Packed HDF5 rank-private fallback",
    )
    record_rank_digest_agreement!(
        validation_errors,
        packed_private_digest,
        "Packed HDF5 rank-private",
    )
finally
    if disable_shared_was_set
        ENV[disable_shared_key] = disable_shared_previous
    else
        delete!(ENV, disable_shared_key)
    end
end
MPI.Barrier(MPI.COMM_WORLD)

isempty(validation_errors) && write(
    joinpath(root, "mdrs_mpi_rank_private_rank$(rank).marker"),
    "Legacy and Packed HDF5 rank-private parity verified\n",
)

postrun_marker = joinpath(root, "mdrs_mpi_postrun_rank$(rank).marker")
if rank == 0
    try
        record_check!(
            validation_errors,
            length(result.outputs) == 1,
            "root did not receive one output",
        )
        if length(result.outputs) == 1
            output = only(result.outputs)
            record_check!(validation_errors, isfile(output), "root output is missing: $(output)")
        end
        record_check!(validation_errors, isfile(result.metadata_path), "root metadata is missing")
        record_check!(
            validation_errors,
            isfile(result.progress_jsonl_path),
            "root progress JSON is missing",
        )
        if isfile(result.metadata_path)
            metadata = read(result.metadata_path, String)
            record_check!(
                validation_errors,
                occursin(r"source\s*= wsvec", metadata),
                "root metadata lost wsvec source",
            )
            record_check!(
                validation_errors,
                occursin(r"effective_num_r_vectors\s*= 3", metadata),
                "root metadata lost prepared R support",
            )
        end
        if isfile(result.progress_jsonl_path)
            events = JSON3.read.(filter(!isempty, strip.(readlines(result.progress_jsonl_path))))
            done_events = filter(event -> String(event.event) == "run_done", events)
            record_check!(
                validation_errors,
                length(done_events) == 1,
                "root progress must contain exactly one run_done event",
            )
            if length(done_events) == 1
                replica = only(done_events).replica_summary
                record_check!(
                    validation_errors,
                    String(replica.source) == "wsvec",
                    "root progress lost wsvec source",
                )
                record_check!(
                    validation_errors,
                    Int(replica.effective_num_r_vectors) == 3,
                    "root progress lost prepared support",
                )
            end
        end
    catch exception
        push!(
            validation_errors,
            "root publication validation raised $(sprint(showerror, exception))",
        )
    end
    isempty(validation_errors) &&
        write(postrun_marker, "root publication and collective prepared payload verified\n")
else
    record_check!(
        validation_errors,
        isempty(result.metadata_path),
        "non-root received a metadata publication path",
    )
    isempty(validation_errors) &&
        write(postrun_marker, "non-root prepared payload and publication path verified\n")
end

# The probe needs the returned root-only paths after `run`; defer the normal
# one-bundle finalize until those assertions and their markers have completed.
failure_message = collective_failure_message(validation_errors, rank)
mpi_benchmark_finalize!()
failure_message === nothing || error(failure_message)
