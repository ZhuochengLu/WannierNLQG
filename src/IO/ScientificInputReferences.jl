"""One immutable transport object; its digest is not scientific qualification."""
struct ScientificReferenceObject
    path::String
    byte_count::Int
    sha256::String
    state::NamedTuple
end

"""Ordered byte slices reconstructing the unchanged complete scientific value stream."""
struct ScientificReferenceLayout
    root::String
    objects::Tuple{Vararg{ScientificReferenceObject}}
    segments::Tuple{Vararg{NTuple{3, Int}}}
    byte_count::Int
    function ScientificReferenceLayout(root, objects, segments, byte_count)
        byte_count >= 0 || throw(ArgumentError("SCIENTIFIC_REFERENCE_EXTENT_MISMATCH"))
        total = 0
        for (index, offset, count) in segments
            1 <= index <= length(objects) ||
                throw(ArgumentError("SCIENTIFIC_REFERENCE_OBJECT_INDEX_INVALID"))
            object = objects[index]
            0 <= offset <= object.byte_count && 0 <= count <= object.byte_count-offset ||
                throw(ArgumentError("SCIENTIFIC_REFERENCE_EXTENT_MISMATCH"))
            total = Base.Checked.checked_add(total, count)
        end
        total == byte_count || throw(ArgumentError("SCIENTIFIC_REFERENCE_EXTENT_MISMATCH"))
        return new(String(root), Tuple(objects), Tuple(segments), Int(byte_count))
    end
end

"""Return the physical backing observation, retaining the original three-field descriptor."""
scientific_input_definition_backing_state(d::ScientificInputDefinition) =
    hasproperty(d.state, :reference_layout) ? d.state.backing_state : d.state

"""Resolve an explicitly referenced definition; ordinary definitions stay byte-backed."""
scientific_input_definition_reference_layout(d::ScientificInputDefinition) =
    hasproperty(d.state, :reference_layout) ? d.state.reference_layout : nothing

"""Resolve a caller-bound source root without inferring a root from artifact contents."""
function scientific_reference_root(root::AbstractString)
    isdir(root) || throw(ArgumentError("SCIENTIFIC_REFERENCE_ROOT_REQUIRED"))
    return realpath(root)
end

"""Require a regular canonical object within the explicitly bound source root."""
function scientific_reference_path(root::AbstractString, path::AbstractString)
    isfile(path) || throw(ArgumentError("SCIENTIFIC_REFERENCE_OBJECT_UNAVAILABLE: $(path)"))
    canonical = realpath(path)
    relative = relpath(canonical, root)
    (
        relative != "." &&
        !isabspath(relative) &&
        !any(==(".."), splitpath(relative)) &&
        !islink(canonical) &&
        isfile(canonical)
    ) || throw(ArgumentError("SCIENTIFIC_REFERENCE_PATH_OUTSIDE_ROOT"))
    return canonical
end

"""Freeze one complete source once under the existing read-lifetime guard."""
function scientific_reference_object(
    path,
    root;
    expected_state = nothing,
    expected_sha256 = nothing,
)
    canonical = scientific_reference_path(root, path)
    observed = with_scientific_source(
        canonical;
        expected_record = expected_state === nothing ? nothing :
                          scientific_file_record(expected_state),
    ) do filename
        sha256_file(filename)
    end
    expected_sha256 === nothing ||
        observed.value == expected_sha256 ||
        throw(ArgumentError("SCIENTIFIC_REFERENCE_CONTENT_CHANGED"))
    return ScientificReferenceObject(
        canonical,
        Int(observed.state.bytes),
        observed.value,
        observed.state,
    )
end

"""Build a segmented stream while writing only new literal state to private scratch."""
mutable struct ScientificReferenceBuilder <: Base.IO
    path::String
    output::IOStream
    root::String
    objects::Vector{ScientificReferenceObject}
    indices::Dict{String, Int}
    segments::Vector{NTuple{3, Int}}
    literal_stop::Int
    byte_count::Int
end

# Literal writes are owned by the builder; fixed sources are appended as slices.
Base.isopen(s::ScientificReferenceBuilder) = isopen(s.output)
"""Report that the reference builder accepts literal byte writes."""
Base.iswritable(::ScientificReferenceBuilder) = true
"""Flush pending literal bytes to the owned backing file."""
Base.flush(s::ScientificReferenceBuilder) = flush(s.output)
"""Return the logical byte count including appended source slices."""
Base.position(s::ScientificReferenceBuilder) = s.byte_count

"""Write literal bytes without copying any appended source objects."""
function Base.unsafe_write(s::ScientificReferenceBuilder, bytes::Ptr{UInt8}, count::UInt)
    count <= typemax(Int) || throw(ArgumentError("SCIENTIFIC_REFERENCE_EXTENT_OVERFLOW"))
    n = Base.unsafe_write(s.output, bytes, count)
    s.byte_count = Base.Checked.checked_add(s.byte_count, Int(n))
    return n
end

"""Preserve the scalar byte writes used by canonical scientific encoders."""
function Base.write(s::ScientificReferenceBuilder, byte::UInt8)
    n = write(s.output, byte)
    s.byte_count = Base.Checked.checked_add(s.byte_count, n)
    return n
end

"""Close the current literal slice before appending another immutable object."""
function scientific_reference_flush_literal!(s::ScientificReferenceBuilder)
    stop = Int(position(s.output))
    stop == s.literal_stop || push!(s.segments, (0, s.literal_stop, stop-s.literal_stop))
    s.literal_stop = stop
    return nothing
end

"""Reuse the same actual file across source roles, retaining complete value semantics."""
function scientific_reference_register!(
    s::ScientificReferenceBuilder,
    object::ScientificReferenceObject,
)
    scientific_reference_path(s.root, object.path) == object.path ||
        throw(ArgumentError("SCIENTIFIC_REFERENCE_PATH_CHANGED"))
    validate_scientific_source_state(object.state; declared_path = object.path)
    if haskey(s.indices, object.path)
        index = s.indices[object.path]
        previous = s.objects[index]
        previous.byte_count == object.byte_count && previous.sha256 == object.sha256 ||
            throw(ArgumentError("SCIENTIFIC_REFERENCE_CONTENT_CHANGED"))
        return index
    end
    push!(s.objects, object)
    return s.indices[object.path] = length(s.objects)
end

"""Reuse a source already observed by this builder while its file lifetime is unchanged."""
function scientific_reference_object(s::ScientificReferenceBuilder, path; expected_state = nothing)
    canonical=scientific_reference_path(s.root, path)
    if haskey(s.indices, canonical)
        object=s.objects[s.indices[canonical]]
        validate_scientific_source_state(object.state; declared_path = canonical)
        expected_state === nothing ||
            validate_scientific_source_state(expected_state; declared_path = canonical)
        return object
    end
    return scientific_reference_object(canonical, s.root; expected_state)
end

"""Append a complete existing definition without creating another full byte file."""
function append_scientific_input_reference!(
    s::ScientificReferenceBuilder,
    d::ScientificInputDefinition,
)
    validate_scientific_source_state(
        scientific_input_definition_backing_state(d);
        declared_path = d.path,
    )
    scientific_reference_flush_literal!(s)
    layout = scientific_input_definition_reference_layout(d)
    if layout === nothing
        object = scientific_reference_object(s, d.path; expected_state = d.state)
        object.byte_count == d.byte_count ||
            throw(ArgumentError("SCIENTIFIC_REFERENCE_EXTENT_MISMATCH"))
        push!(s.segments, (scientific_reference_register!(s, object), 0, d.byte_count))
    else
        indices = [scientific_reference_register!(s, object) for object in layout.objects]
        append!(s.segments, [(indices[i], offset, count) for (i, offset, count) in layout.segments])
    end
    s.byte_count = Base.Checked.checked_add(s.byte_count, d.byte_count)
    return nothing
end

"""Reference a labelled raw source instead of duplicating it in a collection file."""
function write_scientific_collection_file(s::ScientificReferenceBuilder, filename, count, scratch)
    scientific_reference_flush_literal!(s)
    object = scientific_reference_object(s, filename)
    object.byte_count == count || throw(ArgumentError("SCIENTIFIC_SOURCE_EXTENT_CHANGED"))
    push!(s.segments, (scientific_reference_register!(s, object), 0, count))
    s.byte_count = Base.Checked.checked_add(s.byte_count, count)
    return nothing
end

"""Freeze literal state and source slices, retaining failed scratch as before."""
function scientific_input_referenced_definition(writer, root; directory = tempdir())
    root = scientific_reference_root(root)
    path, output = mktemp(directory; cleanup = false)
    s = ScientificReferenceBuilder(
        path,
        output,
        root,
        ScientificReferenceObject[],
        Dict{String, Int}(),
        NTuple{3, Int}[],
        0,
        0,
    )
    try
        writer(s)
        scientific_reference_flush_literal!(s)
        flush(output)
        close(output)
        if any(segment -> first(segment)==0, s.segments)
            push!(s.objects, scientific_reference_object(path, root))
            literal_index = length(s.objects)
            s.segments =
                [(i==0 ? literal_index : i, offset, count) for (i, offset, count) in s.segments]
        end
        state = scientific_file_state(path)
        layout = ScientificReferenceLayout(root, s.objects, s.segments, s.byte_count)
        return ScientificInputDefinition(
            path,
            (backing_state = state, reference_layout = layout),
            s.byte_count,
        )
    finally
        isopen(output) && close(output)
    end
end

"""Read one referenced canonical stream with at most one open source and bounded chunks."""
mutable struct ScientificReferenceReader <: Base.IO
    layout::ScientificReferenceLayout
    path::String
    backing_state::NamedTuple
    byte_count::Int
    segment::Int
    offset::Int
    consumed::Int
    source::Union{Nothing, IOStream}
    current_object::Int
    opened::Bool
    owns_backing::Bool
end

# The logical position counts reconstructed value bytes, not backing-file bytes.
Base.isopen(s::ScientificReferenceReader) = s.opened
"""Report that an open reference reader provides logical value bytes."""
Base.isreadable(::ScientificReferenceReader) = true
"""Return the number of reconstructed value bytes consumed."""
Base.position(s::ScientificReferenceReader) = s.consumed
"""Report complete consumption of the declared logical reference extent."""
Base.eof(s::ScientificReferenceReader) = s.consumed == s.byte_count

"""Close an observed object after checking its unchanged publication lifetime."""
function scientific_reference_close_object!(s::ScientificReferenceReader)
    if s.source !== nothing
        close(s.source)
        s.source = nothing
        object = s.layout.objects[s.current_object]
        validate_scientific_source_state(object.state; declared_path = object.path)
        s.current_object = 0
    end
    return nothing
end

"""Read reconstructed slices directly into the caller's bounded byte buffer."""
function Base.readbytes!(
    s::ScientificReferenceReader,
    bytes::Vector{UInt8},
    count::Integer = length(bytes);
    all::Bool = true,
)
    s.opened || throw(ArgumentError("SCIENTIFIC_REFERENCE_READER_CLOSED"))
    0 <= count <= typemax(Int) || throw(ArgumentError("SCIENTIFIC_REFERENCE_EXTENT_OVERFLOW"))
    requested = Int(count)
    length(bytes) < requested && resize!(bytes, requested)
    copied = 0
    while copied < requested && s.segment <= length(s.layout.segments)
        object_index, start, extent = s.layout.segments[s.segment]
        if s.offset == extent
            scientific_reference_close_object!(s)
            s.segment += 1
            s.offset = 0
            continue
        end
        if s.source === nothing
            object = s.layout.objects[object_index]
            validate_scientific_source_state(object.state; declared_path = object.path)
            s.source = open(object.path, "r")
            s.current_object = object_index
            seek(s.source, start+s.offset)
        end
        n = min(requested-copied, extent-s.offset)
        GC.@preserve bytes Base.unsafe_read(s.source, pointer(bytes, copied+1), UInt(n))
        copied += n
        s.offset += n
        s.consumed += n
    end
    return copied
end

"""Match ordinary `read(io,n)` including a short final chunk."""
function Base.read(s::ScientificReferenceReader, count::Integer)
    0 <= count <= typemax(Int) || throw(ArgumentError("SCIENTIFIC_REFERENCE_EXTENT_OVERFLOW"))
    bytes = Vector{UInt8}(undef, Int(count))
    resize!(bytes, readbytes!(s, bytes, count))
    return bytes
end

"""Support scalar decoders without materializing the referenced stream."""
function Base.read(s::ScientificReferenceReader, ::Type{UInt8})
    bytes = read(s, 1)
    isempty(bytes) && throw(EOFError())
    return only(bytes)
end

"""Serve exact primitive/array reads with a fixed-size scratch buffer."""
function Base.unsafe_read(s::ScientificReferenceReader, destination::Ptr{UInt8}, count::UInt)
    count <= typemax(Int) || throw(ArgumentError("SCIENTIFIC_REFERENCE_EXTENT_OVERFLOW"))
    remaining = Int(count)
    scratch = Vector{UInt8}(undef, min(65536, remaining))
    offset = 0
    while remaining > 0
        n = min(65536, remaining)
        readbytes!(s, scratch, n)==n || throw(EOFError())
        GC.@preserve scratch unsafe_copyto!(destination+offset, pointer(scratch), n)
        offset += n;
        remaining -= n
    end
    return nothing
end

"""Release handles; only an explicitly owned agreement backing may be removed."""
function Base.close(s::ScientificReferenceReader; retain::Bool = false)
    s.opened || return nothing
    scientific_reference_close_object!(s)
    validate_scientific_source_state(s.backing_state; declared_path = s.path)
    for object in s.layout.objects
        validate_scientific_source_state(object.state; declared_path = object.path)
    end
    s.opened = false
    s.owns_backing && !retain && rm(s.path)
    return nothing
end

"""Open a new reader after checking every referenced object's current lifetime."""
function scientific_input_reference_reader(d::ScientificInputDefinition; owns_backing::Bool = false)
    layout = scientific_input_definition_reference_layout(d)
    layout isa ScientificReferenceLayout ||
        throw(ArgumentError("SCIENTIFIC_REFERENCE_LAYOUT_REQUIRED"))
    layout.byte_count == d.byte_count ||
        throw(ArgumentError("SCIENTIFIC_REFERENCE_EXTENT_MISMATCH"))
    backing = scientific_input_definition_backing_state(d)
    validate_scientific_source_state(backing; declared_path = d.path)
    for object in layout.objects
        validate_scientific_source_state(object.state; declared_path = object.path)
    end
    return ScientificReferenceReader(
        layout,
        d.path,
        backing,
        d.byte_count,
        1,
        0,
        0,
        nothing,
        0,
        true,
        owns_backing,
    )
end

"""Run a complete-value consumer while retaining immutable source objects."""
function with_scientific_reference_reader(reader, definition)
    stream = scientific_input_reference_reader(definition)
    try
        return reader(stream)
    finally
        close(stream)
    end
end

"""Reference existing owned bytes without changing their complete logical value stream."""
function scientific_input_definition_reference(
    d::ScientificInputDefinition,
    reference_root::AbstractString,
)
    validate_scientific_source_state(
        scientific_input_definition_backing_state(d);
        declared_path = d.path,
    )
    root = scientific_reference_root(reference_root)
    layout = scientific_input_definition_reference_layout(d)
    if layout === nothing
        object = scientific_reference_object(d.path, root; expected_state = d.state)
        object.byte_count == d.byte_count ||
            throw(ArgumentError("SCIENTIFIC_REFERENCE_EXTENT_MISMATCH"))
        layout = ScientificReferenceLayout(root, [object], [(1, 0, d.byte_count)], d.byte_count)
    else
        for object in layout.objects
            scientific_reference_path(root, object.path)
            validate_scientific_source_state(object.state; declared_path = object.path)
        end
        layout = ScientificReferenceLayout(root, layout.objects, layout.segments, layout.byte_count)
    end
    return ScientificInputDefinition(
        d.path,
        (backing_state = scientific_input_definition_backing_state(d), reference_layout = layout),
        d.byte_count,
    )
end

"""Encode relative object locations and slice framing; never serialize host inode credentials."""
function scientific_input_reference_toml(
    d::ScientificInputDefinition,
    reference_root::AbstractString,
)
    reference = scientific_input_definition_reference(d, reference_root)
    layout = scientific_input_definition_reference_layout(reference)
    layout.byte_count > 0 || throw(ArgumentError("EMPTY_SCIENTIFIC_INPUT_REFERENCE"))
    document = Dict(
        "schema" => "wanniernlqg.scientific-input-reference/1",
        "expanded_byte_count" => layout.byte_count,
        "objects" => [
            Dict(
                "relative_path"=>relpath(o.path, layout.root),
                "byte_count"=>o.byte_count,
                "sha256"=>o.sha256,
            ) for o in layout.objects
        ],
        "segments" => [
            Dict("object_index"=>i, "offset"=>offset, "byte_count"=>count) for
            (i, offset, count) in layout.segments
        ],
    )
    buffer = IOBuffer()
    TOML.print(buffer, document; sorted = true)
    return String(take!(buffer))
end

"""Require exact nonnegative storage extents before arithmetic or filesystem access."""
function scientific_reference_extent(value, error)
    value isa Integer && !(value isa Bool) && 0 <= value <= typemax(Int) ||
        throw(ArgumentError(error))
    return Int(value)
end

"""Decode an explicit source bundle and verify every unique object's full content once.

The caller must bind the source root. A stored path, digest or object generation
never grants a mathematical or physical PASS. Subsequent comparison still reads
the original complete logical byte stream under each observed source lifetime.
"""
function scientific_input_definition_from_reference_toml(
    text::AbstractString,
    reference_root::AbstractString;
    directory::AbstractString = tempdir(),
)
    ncodeunits(text) <= 16*1024^2 || throw(ArgumentError("SCIENTIFIC_REFERENCE_INDEX_TOO_LARGE"))
    document = TOML.parse(text)
    Set(keys(document)) == Set(["schema", "expanded_byte_count", "objects", "segments"]) &&
    document["schema"] == "wanniernlqg.scientific-input-reference/1" ||
        throw(ArgumentError("SCIENTIFIC_REFERENCE_SCHEMA_UNSUPPORTED"))
    root = scientific_reference_root(reference_root)
    extent = scientific_reference_extent(
        document["expanded_byte_count"],
        "SCIENTIFIC_REFERENCE_EXTENT_INVALID",
    )
    extent > 0 || throw(ArgumentError("EMPTY_SCIENTIFIC_INPUT_REFERENCE"))
    raw_objects, raw_segments = document["objects"], document["segments"]
    raw_objects isa AbstractVector && raw_segments isa AbstractVector ||
        throw(ArgumentError("SCIENTIFIC_REFERENCE_LAYOUT_INVALID"))
    objects = ScientificReferenceObject[]
    seen = Set{String}()
    for entry in raw_objects
        entry isa AbstractDict &&
        Set(keys(entry))==Set(["relative_path", "byte_count", "sha256"]) ||
            throw(ArgumentError("SCIENTIFIC_REFERENCE_OBJECT_INVALID"))
        name, digest = entry["relative_path"], entry["sha256"]
        name isa String &&
        !isempty(name) &&
        !occursin('\0', name) &&
        !isabspath(name) &&
        name != "." &&
        normpath(name)==name &&
        !any(==(".."), splitpath(name)) &&
        !(name in seen) || throw(ArgumentError("SCIENTIFIC_REFERENCE_PATH_OUTSIDE_ROOT"))
        digest isa String && occursin(r"^[0-9a-f]{64}$", digest) ||
            throw(ArgumentError("SCIENTIFIC_REFERENCE_DIGEST_INVALID"))
        push!(seen, name)
        count =
            scientific_reference_extent(entry["byte_count"], "SCIENTIFIC_REFERENCE_EXTENT_INVALID")
        path = joinpath(root, name)
        isfile(path) && !islink(path) && realpath(path)==path ||
            throw(ArgumentError("SCIENTIFIC_REFERENCE_OBJECT_MISSING_OR_REDIRECTED"))
        filesize(path)==count || throw(ArgumentError("SCIENTIFIC_REFERENCE_EXTENT_MISMATCH"))
        # Validate framing before any potentially large content verification.
        push!(objects, ScientificReferenceObject(path, count, digest, scientific_file_state(path)))
    end
    segments = NTuple{3, Int}[]
    used = Set{Int}()
    total = 0
    for entry in raw_segments
        entry isa AbstractDict && Set(keys(entry))==Set(["object_index", "offset", "byte_count"]) ||
            throw(ArgumentError("SCIENTIFIC_REFERENCE_SEGMENT_INVALID"))
        i = scientific_reference_extent(
            entry["object_index"],
            "SCIENTIFIC_REFERENCE_SEGMENT_INVALID",
        )
        offset =
            scientific_reference_extent(entry["offset"], "SCIENTIFIC_REFERENCE_SEGMENT_INVALID")
        count =
            scientific_reference_extent(entry["byte_count"], "SCIENTIFIC_REFERENCE_SEGMENT_INVALID")
        1 <= i <= length(objects) || throw(ArgumentError("SCIENTIFIC_REFERENCE_SEGMENT_INVALID"))
        stop = Base.Checked.checked_add(offset, count)
        stop <= objects[i].byte_count ||
            throw(ArgumentError("SCIENTIFIC_REFERENCE_EXTENT_MISMATCH"))
        total = Base.Checked.checked_add(total, count)
        push!(segments, (i, offset, count));
        push!(used, i)
    end
    total==extent && used==Set(eachindex(objects)) ||
        throw(ArgumentError("SCIENTIFIC_REFERENCE_EXTENT_MISMATCH"))
    objects = [
        scientific_reference_object(
            o.path,
            root;
            expected_state = o.state,
            expected_sha256 = o.sha256,
        ) for o in objects
    ]
    layout = ScientificReferenceLayout(root, objects, segments, extent)
    backing = scientific_input_definition_bytes(; directory) do stream
        write(stream, text)
    end
    return ScientificInputDefinition(
        backing.path,
        (backing_state = backing.state, reference_layout = layout),
        extent,
    )
end
