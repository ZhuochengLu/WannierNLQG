"""Adopt one private sequential checkpoint definition for bounded comparison."""
function checkpoint_definition_stream(
    result::WannierizationResult;
    version::Symbol = :v2_30,
    reference_root = nothing,
)
    if reference_root !== nothing
        definition = scientific_input_definition_bytes(;
            reference_root,
            directory = reference_root,
        ) do stream
            write_checkpoint_definition(stream, result; version)
        end
        return scientific_input_reference_reader(definition; owns_backing = true)
    end
    return scientific_definition_stream(;
        changed_error = "CHECKPOINT_DEFINITION_STREAM_CHANGED",
    ) do stream
        write_checkpoint_definition(stream, result; version)
    end
end

const CHECKPOINT_DEFINITION_COMPARISON_CHUNK_BYTES = 65536

"""Agree on actual terminal field bytes before any rank persists a result.

Preparation, equal lengths, the fixed bounded chunk schedule, complete reads and
scratch release are collective phases. A peer read error drains that schedule;
a root read error is broadcast before every rank leaves it. Local file states
protect private scratch only and never decide cross-rank scientific equality.
"""
function _checkpoint_definition_agreement(make_definition::F; comm = MPI.COMM_WORLD) where {F}
    MPI.Initialized() || throw(ArgumentError("Checkpoint agreement requires initialized MPI"))
    rank = MPI.Comm_rank(comm)
    ranks = MPI.Comm_size(comm)
    definition = nothing
    try
        packet = try
            definition = make_definition()
            (; ok = true, byte_count = definition.byte_count, error = "")
        catch exception
            (; ok = false, byte_count = 0, error = sprint(showerror, exception))
        end
        byte_count = 0
        for owner in 0:(ranks - 1)
            received = MPI.bcast(rank == owner ? packet : nothing, owner, comm)
            received.ok || throw(
                ArgumentError(
                    "MPI_PAYLOAD_DEFINITION_PREPARATION_FAILED rank=$owner: $(received.error)",
                ),
            )
            if owner == 0
                byte_count = received.byte_count
            else
                received.byte_count == byte_count || throw(
                    ArgumentError(
                        "MPI_PAYLOAD_DEFINITION_MISMATCH: definition length differs on rank $owner",
                    ),
                )
            end
        end
        matches = true
        local_error = ""
        first_mismatch_offset = nothing
        for offset in 0:CHECKPOINT_DEFINITION_COMPARISON_CHUNK_BYTES:(byte_count - 1)
            count = min(CHECKPOINT_DEFINITION_COMPARISON_CHUNK_BYTES, byte_count - offset)
            bytes = try
                read(definition, count)
            catch exception
                isempty(local_error) && (local_error = sprint(showerror, exception))
                UInt8[]
            end
            packet =
                rank == 0 ?
                (;
                    ok = length(bytes) == count && isempty(local_error),
                    bytes,
                    error = isempty(local_error) ? "incomplete root definition chunk" : local_error,
                ) : nothing
            reference = MPI.bcast(packet, 0, comm)
            reference.ok ||
                throw(ArgumentError("MPI_PAYLOAD_DEFINITION_ROOT_READ_FAILED: $(reference.error)"))
            equal_chunk = length(bytes) == count && bytes == reference.bytes
            if !equal_chunk && first_mismatch_offset === nothing
                first_mismatch_offset = offset
            end
            matches &= equal_chunk
        end
        packet = try
            complete = eof(definition)
            (;
                ok = matches && complete && isempty(local_error),
                error = isempty(local_error) ?
                        "definition bytes differ or incomplete; first differing chunk offset=$(first_mismatch_offset)" :
                        local_error,
            )
        catch exception
            (; ok = false, error = sprint(showerror, exception))
        end
        for owner in 0:(ranks - 1)
            received = MPI.bcast(rank == owner ? packet : nothing, owner, comm)
            received.ok || throw(
                ArgumentError("MPI_PAYLOAD_DEFINITION_MISMATCH rank=$owner: $(received.error)"),
            )
        end
        packet = try
            close(definition)
            definition = nothing
            (; ok = true, error = "")
        catch exception
            (; ok = false, error = sprint(showerror, exception))
        end
        for owner in 0:(ranks - 1)
            received = MPI.bcast(rank == owner ? packet : nothing, owner, comm)
            received.ok || throw(
                ArgumentError(
                    "MPI_PAYLOAD_DEFINITION_RELEASE_FAILED rank=$owner: $(received.error)",
                ),
            )
        end
        return nothing
    finally
        if definition !== nothing
            try
                close(definition; retain = true)
            catch exception
                @warn "Failed checkpoint definition scratch retained; close failed" path =
                    definition.path exception
            end
        end
    end
end

"""Compare a supplied complete scientific stream through the bounded collective protocol.

The supplier owns its backing lifetime. A referenced reader with `owns_backing=false`
keeps immutable accepted inputs in place on both success and failure.
"""
function agree_scientific_definition_stream(make_definition::F; comm = MPI.COMM_WORLD) where {F}
    return _checkpoint_definition_agreement(make_definition; comm)
end

"""Compare accepted state and complete actual continuation inputs before persistence."""
function agree_terminal_checkpoint_definition(
    result::WannierizationResult;
    comm = MPI.COMM_WORLD,
    reference_root = nothing,
)
    return _checkpoint_definition_agreement(; comm) do
        checkpoint_definition_stream(result; version = :v2_30, reference_root)
    end
end
