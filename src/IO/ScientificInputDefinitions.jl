"""Complete scientific input values backed by private bytes or explicit source references.

This descriptor records local lifetime only. Equality is established by streaming
all actual values against the saved bytes. Its local path/state are not serialized into model HDF.
`state` retains either the byte-file observation or an observed backing index and
its source-reference layout. Use the bounded reader rather than reading `path`
directly: a referenced definition's backing file contains only its literal bytes.
Scratch stays in the caller's TMPDIR for the existing artifact lifecycle; failed
or abandoned definitions are not automatically removed.
"""
struct ScientificInputDefinition
    path::String
    state::NamedTuple
    byte_count::Int
end

"""Retain a complete reference stream supplied by a schema-validating IO decoder."""
function scientific_input_definition_bytes(
    writer::F;
    directory::AbstractString = tempdir(),
    reference_root::Union{Nothing, AbstractString} = nothing,
) where {F}
    reference_root === nothing ||
        return scientific_input_referenced_definition(writer, reference_root; directory)
    definition=scientific_definition_stream(writer; directory)
    try
        return ScientificInputDefinition(definition.path, definition.state, definition.byte_count)
    finally
        close(definition; retain = true)
    end
end

"""Expose one fresh bounded reference reader under its unchanged file observation."""
function with_scientific_input_definition_bytes(
    reader::F,
    definition::ScientificInputDefinition,
) where {F}
    backing = scientific_input_definition_backing_state(definition)
    observed=with_scientific_source(
        definition.path;
        expected_record = scientific_file_record(backing),
    ) do filename
        validate_scientific_source_state(backing; declared_path = filename)
        layout = scientific_input_definition_reference_layout(definition)
        layout === nothing ? open(reader, filename, "r") :
        with_scientific_reference_reader(reader, definition)
    end
    return observed.value
end

"""Compare an encoded persisted reference with the original complete input bytes."""
function validate_scientific_input_definition_bytes(
    writer::F,
    definition::ScientificInputDefinition;
    mismatch_error = "SCIENTIFIC_INPUT_DEFINITION_MISMATCH",
) where {F}
    with_scientific_input_definition_bytes(definition) do source
        stream=ScientificDefinitionComparison(source, Vector{UInt8}(undef, 65536), true, 0)
        writer(stream)
        stream.equal && eof(source) && stream.byte_count==definition.byte_count ||
            throw(ArgumentError(mismatch_error))
    end
    return nothing
end

# The scientific writer emits actual input bytes; this sink compares them against
# a fresh private reference reader without a second full current-value file.
mutable struct ScientificDefinitionComparison{S <: Base.IO} <: Base.IO
    source::S
    scratch::Vector{UInt8}
    equal::Bool
    byte_count::Int
end
# This sink accepts the complete actual value stream.
Base.iswritable(::ScientificDefinitionComparison)=true
# The private reference reader determines stream lifetime.
Base.isopen(stream::ScientificDefinitionComparison)=isopen(stream.source)
# Comparison does not buffer pending writes.
Base.flush(::ScientificDefinitionComparison)=nothing

# Compare bounded byte chunks and consume the entire supplied extent.
function Base.unsafe_write(stream::ScientificDefinitionComparison, bytes::Ptr{UInt8}, count::UInt)
    count<=typemax(Int) || throw(ArgumentError("ScientificDefinitionWriteOverflow"))
    remaining=Int(count);
    offset=0
    while remaining>0
        requested=min(65536, remaining)
        resize!(stream.scratch, 65536)
        got=readbytes!(stream.source, stream.scratch, requested)
        stream.equal &= got==requested
        if got>0
            scratch=stream.scratch
            equal=GC.@preserve scratch begin
                ccall(
                    :memcmp,
                    Cint,
                    (Ptr{UInt8}, Ptr{UInt8}, Csize_t),
                    pointer(scratch),
                    bytes+offset,
                    got,
                )==0
            end
            stream.equal &= equal
        end
        offset+=requested;
        remaining-=requested
    end
    stream.byte_count=Base.Checked.checked_add(stream.byte_count, Int(count))
    return count
end

# Preserve scalar writes used by Julia array serialization.
function Base.write(stream::ScientificDefinitionComparison, value::UInt8)
    resize!(stream.scratch, 65536)
    count=readbytes!(stream.source, stream.scratch, 1)
    stream.equal &= count==1 && stream.scratch[1]==value
    stream.byte_count=Base.Checked.checked_add(stream.byte_count, 1)
    return 1
end

export ScientificInputDefinition,
    scientific_input_definition_bytes,
    with_scientific_input_definition_bytes,
    validate_scientific_input_definition_bytes

"""Write a complete labelled source collection using bounded buffers, without a digest.

Labels are part of the scientific source contract; absolute locations are not.
The source lifetime guard checks each file throughout its read. Consumers must
compare this stream with a retained complete definition, not compare paths or
file sizes as substitutes for contents.
"""
function write_scientific_source_collection(
    stream,
    sources::AbstractDict{<:AbstractString, <:AbstractString},
)
    labels = sort!(collect(keys(sources)))
    print(stream, "scientific-source-collection/1\n", length(labels), '\n')
    scratch = Vector{UInt8}(undef, 65536)
    for label in labels
        bytes = codeunits(label)
        print(stream, length(bytes), ':')
        write(stream, bytes)
        with_scientific_source(sources[label]; resolve_links = true) do filename
            count = filesize(filename)
            print(stream, count, ':')
            write_scientific_collection_file(stream, filename, count, scratch)
        end
    end
    return nothing
end

"""Retain actual labelled source bytes for later explicit nonhash comparison."""
function scientific_source_collection_definition(
    sources::AbstractDict{<:AbstractString, <:AbstractString},
    ;
    reference_root::Union{Nothing, AbstractString} = nothing,
    directory::AbstractString = tempdir(),
)
    return scientific_input_definition_bytes(; reference_root, directory) do stream
        write_scientific_source_collection(stream, sources)
    end
end

"""Copy one source extent into an ordinary complete reference using bounded memory."""
function write_scientific_collection_file(stream, filename, count, scratch)
    copied = open(filename, "r") do source
        total = 0
        while !eof(source)
            n = readbytes!(source, scratch, length(scratch))
            n > 0 || throw(EOFError())
            write(stream, @view scratch[1:n])
            total = Base.Checked.checked_add(total, n)
        end
        total
    end
    copied == count || throw(ArgumentError("SCIENTIFIC_SOURCE_EXTENT_CHANGED"))
    return nothing
end

"""Reject any changed label, source extent or byte against a complete reference."""
function validate_scientific_source_collection(
    sources::AbstractDict{<:AbstractString, <:AbstractString},
    definition::ScientificInputDefinition,
)
    return validate_scientific_input_definition_bytes(
        definition;
        mismatch_error = "SCIENTIFIC_SOURCE_COLLECTION_MISMATCH",
    ) do stream
        write_scientific_source_collection(stream, sources)
    end
end

"""Compare complete current source bytes with bounded memory and lifetime checks.

This establishes equality for this read operation only. It creates no persistent
fingerprint and offers no authentication of a future replacement of either file.
"""
function scientific_source_contents_equal(left::AbstractString, right::AbstractString)
    return with_scientific_source(left; resolve_links = true) do left_path
        with_scientific_source(right; resolve_links = true) do right_path
            open(left_path, "r") do left_stream
                open(right_path, "r") do right_stream
                    left_bytes = Vector{UInt8}(undef, 65536)
                    right_bytes = similar(left_bytes)
                    equal = true
                    while !eof(left_stream) || !eof(right_stream)
                        nl = readbytes!(left_stream, left_bytes, 65536)
                        nr = readbytes!(right_stream, right_bytes, 65536)
                        equal &= nl == nr
                        for index in 1:min(nl, nr)
                            equal &= left_bytes[index] == right_bytes[index]
                        end
                    end
                    return equal
                end
            end
        end.value
    end.value
end

"""Compare two complete retained definitions under both original lifetime guards.

This performs bounded actual-byte comparison, not content authentication.
"""
function validate_scientific_input_definitions_equal(
    current::ScientificInputDefinition,
    reference::ScientificInputDefinition;
    mismatch_error = "SCIENTIFIC_INPUT_DEFINITION_MISMATCH",
)
    return validate_scientific_input_definition_bytes(reference; mismatch_error) do target
        with_scientific_input_definition_bytes(current) do source
            scratch = Vector{UInt8}(undef, 65536)
            while !eof(source)
                count = readbytes!(source, scratch, length(scratch))
                count > 0 || throw(EOFError())
                write(target, @view scratch[1:count])
            end
        end
    end
end
