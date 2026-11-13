"""Replace a same-directory checkpoint with one OS rename, never unlink or copy fallback."""
function atomic_file_replace(temporary, destination)
    dirname(abspath(temporary))==dirname(abspath(destination)) ||
        throw(ArgumentError("CheckpointRenameRequiresSameDirectory"))
    error_code=ccall(:jl_fs_rename, Int32, (Cstring, Cstring), temporary, destination)
    error_code<0 && Base.uv_error("atomic checkpoint rename", error_code)
    return destination
end

const SCIENTIFIC_CHECKPOINT_POINTER_SCHEMA = "wanniernlqg.scientific-checkpoint-pointer/1"

# Check every Serialization write without allocating a duplicate numerical payload.
mutable struct ScientificCheckpointWriteStream{T <: Base.IO} <: Base.IO
    stream::T
    byte_count::Int
end
"""Start a checked checkpoint output stream with a zero byte count."""
ScientificCheckpointWriteStream(stream::Base.IO) = ScientificCheckpointWriteStream(stream, 0)
"""Report whether the underlying checkpoint output remains open."""
Base.isopen(stream::ScientificCheckpointWriteStream) = isopen(stream.stream)
"""Forward the underlying checkpoint stream write capability."""
Base.iswritable(stream::ScientificCheckpointWriteStream) = iswritable(stream.stream)
"""Return the underlying checkpoint output position."""
Base.position(stream::ScientificCheckpointWriteStream) = position(stream.stream)
"""Check and count one serialized byte written to checkpoint storage."""
function Base.write(stream::ScientificCheckpointWriteStream, byte::UInt8)
    count = write(stream.stream, byte)
    count == 1 || error("IncompleteScientificCheckpointWrite")
    stream.byte_count += count
    return count
end
"""Reject short block writes while counting serialized checkpoint bytes."""
function Base.unsafe_write(stream::ScientificCheckpointWriteStream, bytes::Ptr{UInt8}, count::UInt)
    written = unsafe_write(stream.stream, bytes, count)
    written == count || error("IncompleteScientificCheckpointWrite")
    stream.byte_count += Int(written)
    return written
end

# The pointer is small configuration, parsed only through the central input port.
function _scientific_checkpoint_pointer(path, schema, version)
    document = try
        read_task_input_file(path).document
    catch exception
        exception isa TOML.ParserError || rethrow()
        throw(ArgumentError("SCIENTIFIC_CHECKPOINT_MIGRATION_REQUIRED_OR_INVALID_POINTER"))
    end
    Set(keys(document)) == Set((
        "schema",
        "artifact_schema",
        "artifact_version",
        "publication_identity",
        "payload_file",
    )) &&
    document["schema"] == SCIENTIFIC_CHECKPOINT_POINTER_SCHEMA &&
    document["artifact_schema"] == schema &&
    document["artifact_version"] == version ||
        throw(ArgumentError("SCIENTIFIC_CHECKPOINT_MIGRATION_REQUIRED_OR_INVALID_POINTER"))
    document["publication_identity"] isa AbstractString ||
        throw(ArgumentError("SCIENTIFIC_CHECKPOINT_PUBLICATION_INVALID"))
    _scientific_publication_label(document["publication_identity"])
    filename = document["payload_file"]
    filename isa AbstractString &&
    !isempty(filename) &&
    basename(filename) == filename &&
    !(filename in (".", "..")) &&
    !occursin('\\', filename) &&
    !occursin('\0', filename) ||
        throw(ArgumentError("SCIENTIFIC_CHECKPOINT_PAYLOAD_MUST_BE_ADJACENT"))
    return document
end

"""Observe the commit pointer across the complete payload callback.

The label selects one immutable accepted-state publication; it is never numerical
identity. Reads of the payload must retain their own file/receipt observation.
"""
function with_scientific_checkpoint_pointer(
    reader::F,
    path::AbstractString;
    artifact_schema::AbstractString,
    artifact_version::AbstractString,
) where {F}
    observed = with_scientific_source(path) do pointer
        document = _scientific_checkpoint_pointer(pointer, artifact_schema, artifact_version)
        payload = joinpath(dirname(pointer), document["payload_file"])
        reader(payload, document["publication_identity"])
    end
    return observed
end

"""Commit one accepted state only after payload and receipt are complete.

Two owned payload slots bound storage. The active slot is untouched while its
successor is written and checked; the original atomic rename commits only the
small pointer. A failed payload/receipt/pointer preparation preserves the previous
readable state. The per-file OS writer lock releases on close or process exit;
this is IO serialization, not a process/resource supervisor.
"""
function write_scientific_checkpoint_pointer(
    payload_writer::F,
    path::AbstractString;
    artifact_schema::AbstractString,
    artifact_version::AbstractString,
    publication_identity::AbstractString,
    publish::P,
    prepare_publication = write_scientific_file_publication,
) where {F, P}
    Sys.isunix() || throw(ArgumentError("SCIENTIFIC_CHECKPOINT_WRITER_LOCK_UNSUPPORTED"))
    schema = _scientific_publication_label(artifact_schema)
    version = _scientific_publication_label(artifact_version)
    identity = _scientific_publication_label(publication_identity)
    absolute = abspath(path)
    parent = dirname(absolute)
    mkpath(parent)
    open(absolute * ".writer.lock", "a+") do lock_stream
        ccall(:flock, Cint, (Cint, Cint), fd(lock_stream), 2 | 4) == 0 ||
            throw(SystemError("ScientificCheckpointWriterLock", Libc.errno()))
        first_slot, second_slot = (absolute * suffix for suffix in (".payload-a", ".payload-b"))
        active = if isfile(absolute)
            _scientific_checkpoint_pointer(absolute, schema, version)["payload_file"]
        else
            nothing
        end
        payload = active == basename(first_slot) ? second_slot : first_slot
        temporary, stream = mktemp(parent)
        try
            checked = ScientificCheckpointWriteStream(stream)
            payload_writer(checked)
            expected_bytes = checked.byte_count
            close(stream)
            filesize(temporary) == expected_bytes || error("IncompleteScientificCheckpointFile")
            atomic_file_replace(temporary, payload)
        finally
            isopen(stream) && close(stream)
            isfile(temporary) && rm(temporary)
        end
        prepare_publication(
            payload;
            artifact_schema = schema,
            artifact_version = version,
            publication_identity = identity,
        )
        # A truncated small TOML receipt must not reach the commit rename either.
        with_scientific_file_publication(
            payload;
            artifact_schema = schema,
            artifact_version = version,
        ) do _, actual_identity
            actual_identity == identity || error("ScientificCheckpointPublicationMismatch")
            nothing
        end
        document = Dict(
            "schema" => SCIENTIFIC_CHECKPOINT_POINTER_SCHEMA,
            "artifact_schema" => schema,
            "artifact_version" => version,
            "publication_identity" => identity,
            "payload_file" => basename(payload),
        )
        pointer, pointer_stream = mktemp(parent)
        close(pointer_stream)
        try
            write_task_input_file(pointer, document)
            _scientific_checkpoint_pointer(pointer, schema, version) == document ||
                error("IncompleteScientificCheckpointPointer")
            publish(pointer, absolute)
        finally
            isfile(pointer) && rm(pointer)
        end
    end
    return path
end
