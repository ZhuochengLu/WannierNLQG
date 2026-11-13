using MPI, JSON3, WannierNLQG, LinearAlgebra
include(joinpath(@__DIR__, "WannierStandardExportTestSupport.jl"))
MPI.Init()
const COMM = MPI.COMM_WORLD
const RANK = MPI.Comm_rank(COMM)
const RANKS = MPI.Comm_size(COMM)
const DESTINATION = abspath(only(ARGS))
const SOLVER = first(EXPORT_WANNIERIZATION._load_wannierization_extension!()).SolverCheckpoint
const CASES = [
    "equal",
    "one_ulp_difference",
    "late_definition_difference",
    "definition_length_difference",
    "preparation_failure",
    "root_read_failure",
    "peer_read_failure",
    "changed_scratch",
    "recovery_equal",
]

function case_result(name)
    result = standard_export_fixture().result
    result.input_summary["algorithm_profile"] = repeat("sequential-definition-", 10_000)
    different = RANKS > 1 && RANK == RANKS - 1
    if name == "one_ulp_difference" && different
        value = result.v_matrix[1]
        result.v_matrix[1] = complex(nextfloat(real(value)), imag(value))
    elseif name == "late_definition_difference" && different
        value = result.input_summary["algorithm_profile"]
        result.input_summary["algorithm_profile"] = value[1:(end - 1)] * "X"
    elseif name == "definition_length_difference" && different
        result.input_summary["algorithm_profile"] *= "X"
    end
    return result
end

rows = Any[]
try
    for name in CASES
        result = case_result(name)
        saved = Ref{Any}(nothing)
        output = joinpath(DESTINATION, "persistence", name)
        expected_rejection =
            name in
            ("preparation_failure", "root_read_failure", "peer_read_failure", "changed_scratch") ||
            RANKS > 1 && name in
            ("one_ulp_difference", "late_definition_difference", "definition_length_difference")
        rejected = false
        message = ""
        try
            SOLVER._checkpoint_definition_agreement(; comm = COMM) do
                if name == "preparation_failure" && RANK == RANKS - 1
                    throw(ArgumentError("intentional checkpoint preparation failure"))
                end
                definition = SOLVER.checkpoint_definition_stream(result; version = :v2_22)
                saved[] = definition
                if name == "root_read_failure" && RANK == 0 ||
                   name == "peer_read_failure" && RANK == RANKS - 1
                    close(definition.stream)
                elseif name == "changed_scratch" && RANK == RANKS - 1
                    open(definition.path, "a") do stream
                        write(stream, UInt8(0))
                    end
                end
                definition
            end
            if RANK == 0
                mkpath(output)
                write(
                    joinpath(output, "accepted.marker"),
                    "actual complete checkpoint definition agreement\n",
                )
            end
        catch exception
            rejected = true
            message = sprint(showerror, exception)
        end
        MPI.Barrier(COMM)
        definition = saved[]
        definition_prepared = definition !== nothing
        definition_bytes = definition_prepared ? definition.byte_count : 0
        scratch_closed = !definition_prepared || !isopen(definition.stream)
        scratch_released = definition_prepared && !isfile(definition.path)
        failed_scratch_retained = !definition_prepared || isfile(definition.path)
        no_output_created = !ispath(output)
        publication_created = isfile(joinpath(output, "accepted.marker"))
        okay =
            rejected == expected_rejection &&
            scratch_closed &&
            (
                expected_rejection ?
                no_output_created && failed_scratch_retained && !isempty(message) :
                publication_created && scratch_released && isempty(message)
            )
        okay &= MPI.Allreduce(Int(okay), min, COMM) == 1
        push!(
            rows,
            (;
                name,
                passed = okay,
                expected_rejection,
                rejected,
                message,
                definition_inventory = "v2_22",
                definition_prepared,
                definition_bytes,
                scratch_closed,
                scratch_released,
                failed_scratch_retained,
                no_output_created,
                publication_created,
            ),
        )
        MPI.Barrier(COMM)
    end
    payload = (;
        schema = "wanniernlqg.checkpoint-definition-mpi-rank/1",
        source_root = normpath(dirname(@__DIR__)),
        rank = RANK,
        ranks = RANKS,
        pid = getpid(),
        julia_version = string(VERSION),
        mpi_library = MPI.Get_library_version(),
        rows,
        passed = all(row.passed for row in rows),
        rank_actual_exit = "NOT_OBSERVED_BY_CORE",
        kernel_containment = "UNKNOWN",
    )
    open(joinpath(DESTINATION, "rank-$(RANK).json"), "w") do stream
        JSON3.write(stream, payload)
    end
    MPI.Barrier(COMM)
    @assert payload.passed
finally
    MPI.Initialized() && !MPI.Finalized() && MPI.Finalize()
end
