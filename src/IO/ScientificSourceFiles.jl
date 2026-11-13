"""Observe a regular scientific input without authenticating its contents.

The observation protects one local read lifetime. It neither establishes byte
equality across copied files nor grants scientific or material qualification.
"""
function scientific_file_state(path::AbstractString)
    declared = abspath(path)
    isfile(declared) && !islink(declared) ||
        throw(ArgumentError("Scientific input must be an existing regular file: $declared"))
    # Store the resolved parent path once. Darwin tempdir commonly starts at
    # /var while realpath names /private/var; that alias is not a replacement.
    # Retaining this canonical observation also detects later parent retargeting.
    absolute = realpath(declared)
    information = stat(absolute)
    return (
        path = absolute,
        device = information.device,
        inode = information.inode,
        bytes = information.size,
        mtime = information.mtime,
        ctime = information.ctime,
    )
end

"""Run a streaming scientific read under one observed local publication lifetime.

The callback receives the already observed path. It may stream a large text/HDF5
payload directly into owned data; this port does not duplicate or hash the file.
An expected record is a local lifetime condition, never an authenticity claim.
`resolve_links=true` preserves ordinary configured input aliases while checking
that their complete resolved path still names the same observed file on return.
The default keeps strict regular-file admission for publication and native ports.
"""
function with_scientific_source(
    f::F,
    path::AbstractString;
    expected_record = nothing,
    resolve_links::Bool = false,
) where {F}
    declared_path = abspath(path)
    before = scientific_file_state(resolve_links ? realpath(declared_path) : declared_path)
    expected_record === nothing || validate_scientific_file_record(expected_record, before)
    value = f(before.path)
    (!resolve_links && islink(declared_path)) && throw(
        ArgumentError("Scientific input became a symbolic link during reading: $declared_path"),
    )
    realpath(declared_path) != before.path &&
        throw(ArgumentError("Scientific input path changed during reading: $declared_path"))
    isequal(before, scientific_file_state(before.path)) ||
        throw(ArgumentError("Scientific input changed during reading: $(before.path)"))
    return (; value, state = before)
end

"""Validate one previously observed local source lifetime without reading payload bytes.

This check establishes only the continued availability of the same local file.
It is not content equivalence, authenticity, or scientific qualification.
"""
function validate_scientific_source_state(state::NamedTuple; declared_path = nothing)
    declared_path===nothing ||
        realpath(declared_path)==state.path ||
        throw(ArgumentError("Scientific input path changed during use: $declared_path"))
    isequal(state, scientific_file_state(state.path)) ||
        throw(ArgumentError("Scientific input changed during use: $(state.path)"))
    return nothing
end

"""Check early source readability without reading or hashing numerical contents."""
function observe_scientific_source(path::AbstractString)
    observed = with_scientific_source(path) do filename
        open(filename, "r") do stream
            isreadable(stream) || throw(ArgumentError("Scientific source is not readable"))
            nothing
        end
    end
    return observed.state
end

"""Read once for parsing and reject replacement or modification during that read."""
function read_scientific_source(path::AbstractString; reader = read)
    observed = with_scientific_source(reader, path)
    length(observed.value) == observed.state.bytes ||
        throw(ArgumentError("Scientific input read was incomplete: $(observed.state.path)"))
    return (; bytes = observed.value, state = observed.state)
end

"""Record bounded local file metadata, with exact IEEE timestamp values.

No numerical payload is inspected. Copying or editing the publication requires
new adoption; this record does not establish portable content equivalence.
"""
function scientific_file_record(state::NamedTuple)
    return Dict(
        "schema" => "wanniernlqg.local-file-publication/1",
        "device" => string(state.device),
        "inode" => string(state.inode),
        "bytes" => Int(state.bytes),
        "mtime_ieee" => string(reinterpret(UInt64, Float64(state.mtime))),
        "ctime_ieee" => string(reinterpret(UInt64, Float64(state.ctime))),
    )
end

"""Reject stale, malformed or historical file bindings before consuming a payload."""
function validate_scientific_file_record(record, state::NamedTuple)
    expected = scientific_file_record(state)
    record isa AbstractDict &&
    Set(keys(record)) == Set(keys(expected)) &&
    record["bytes"] isa Integer &&
    !(record["bytes"] isa Bool) &&
    all(
        key -> record[key] isa AbstractString,
        ("schema", "device", "inode", "mtime_ieee", "ctime_ieee"),
    ) &&
    record == expected || throw(ArgumentError("SCIENTIFIC_FILE_PUBLICATION_CHANGED_OR_INVALID"))
    return nothing
end

"""Encode bounded observed file metadata for ordinary provenance records."""
function scientific_file_identity(path::AbstractString)
    return scientific_file_identity(scientific_file_state(path))
end

"""Label an already observed state without reopening the scientific input."""
scientific_file_identity(state::NamedTuple) = "wanniernlqg.file-state/1:" * repr(state)

"""Private sequential scientific definition, backed by one owned temporary file.

Only a bounded read buffer is needed. Content equality uses actual complete
definition bytes; owner generations describe local lifetimes only.
"""
struct ScientificDefinitionStream <: Base.IO
    path::String
    stream::IOStream
    state::NamedTuple
    byte_count::Int
    changed_error::String
    negative_read_error::String
end

"""Reject replacement or modification of an owned scientific definition buffer."""
function _validate_scientific_definition_stream(definition::ScientificDefinitionStream)
    observed = scientific_file_state(definition.path)
    isequal(observed, definition.state) || throw(
        ArgumentError(
            "$(definition.changed_error): expected=$(definition.state); observed=$observed",
        ),
    )
    return nothing
end

"""Adopt a complete sequential definition; retained failed buffers stay in private TMPDIR."""
function scientific_definition_stream(
    writer::F;
    changed_error::AbstractString = "SCIENTIFIC_DEFINITION_STREAM_CHANGED",
    negative_read_error::AbstractString = "negative scientific definition chunk length",
    directory::AbstractString = tempdir(),
) where {F}
    path, stream = mktemp(directory; cleanup = false)
    try
        writer(stream)
        flush(stream)
        seekstart(stream)
        before = scientific_file_state(path)
        observed = scientific_file_state(path)
        isequal(before, observed) ||
            throw(ArgumentError("$changed_error: expected=$before; observed=$observed"))
        seekstart(stream)
        return ScientificDefinitionStream(
            path,
            stream,
            before,
            Int(before.bytes),
            String(changed_error),
            String(negative_read_error),
        )
    catch
        isopen(stream) && close(stream)
        rethrow()
    end
end

"""Read a bounded scientific definition chunk under the published file observation."""
function Base.read(definition::ScientificDefinitionStream, count::Int)
    count >= 0 || throw(ArgumentError(definition.negative_read_error))
    _validate_scientific_definition_stream(definition)
    bytes = read(definition.stream, count)
    _validate_scientific_definition_stream(definition)
    return bytes
end

"""Check complete sequential consumption without reading numerical input arrays again."""
function Base.eof(definition::ScientificDefinitionStream)
    _validate_scientific_definition_stream(definition)
    return eof(definition.stream)
end

"""Release only this owned scratch buffer; preserve it when admission fails."""
function Base.close(definition::ScientificDefinitionStream; retain::Bool = false)
    try
        retain || _validate_scientific_definition_stream(definition)
    finally
        isopen(definition.stream) && close(definition.stream)
    end
    retain || rm(definition.path)
    return nothing
end

const SCIENTIFIC_FILE_PUBLICATION_SCHEMA = "wanniernlqg.scientific-file-publication/2"

# Shared filesystem timestamps/size describe publication lifetime, not data equality.
# Device and inode are intentionally checked only by each local read observation.
function _scientific_publication_lifetime(state)
    return Dict(
        "schema" => "wanniernlqg.filesystem-publication-lifetime/1",
        "bytes" => Int(state.bytes),
        "mtime_ieee" => string(reinterpret(UInt64, Float64(state.mtime))),
        "ctime_ieee" => string(reinterpret(UInt64, Float64(state.ctime))),
    )
end

"""Require the receipt to match the complete observed publication lifetime record."""
function _validate_scientific_publication_lifetime(record, state)
    expected = _scientific_publication_lifetime(state)
    record isa AbstractDict &&
    Set(keys(record)) == Set(keys(expected)) &&
    record["bytes"] isa Integer &&
    !(record["bytes"] isa Bool) &&
    all(key -> record[key] isa AbstractString, ("schema", "mtime_ieee", "ctime_ieee")) &&
    record == expected || throw(ArgumentError("SCIENTIFIC_FILE_PUBLICATION_CHANGED_OR_INVALID"))
    return nothing
end

# Keep publication labels bounded and distinct from numerical content definitions.
function _scientific_publication_label(value)
    value isa AbstractString &&
    !isempty(strip(value)) &&
    ncodeunits(value) <= 1024 &&
    !occursin('\0', value) || throw(ArgumentError("SCIENTIFIC_FILE_PUBLICATION_LABEL_INVALID"))
    return String(value)
end

"""Resolve an existing scientific payload to its actual publication referent."""
function _scientific_publication_source(path::AbstractString)
    isfile(path) || throw(ArgumentError("Scientific publication does not exist: $path"))
    return realpath(path)
end

# Nodes may keep their own admission receipts without rewriting a shared file.
function _scientific_publication_receipt(source, receipt_path)
    receipt = receipt_path === nothing ? source * ".commit.toml" : abspath(receipt_path)
    receipt != source || throw(ArgumentError("Scientific receipt cannot overwrite its payload"))
    if ispath(receipt)
        target = stat(receipt)
        payload = stat(source)
        (target.device, target.inode) != (payload.device, payload.inode) ||
            throw(ArgumentError("Scientific receipt cannot alias its payload"))
    end
    return receipt
end

"""Atomically publish a bounded local receipt after a scientific writer has closed.

The caller supplies the artifact's schema, version and descriptive publication
label. No scientific payload is read or hashed. A modified or copied file needs
explicit new adoption; this receipt does not establish scientific equivalence.
An adopter passes the state returned by its completed decoder as `expected_state`;
publication rejects a different file lifetime before touching its receipt.
"""
function write_scientific_file_publication(
    path::AbstractString;
    artifact_schema::AbstractString,
    artifact_version::AbstractString,
    publication_identity::AbstractString,
    receipt_path::Union{Nothing, AbstractString} = nothing,
    expected_state = nothing,
)
    schema = _scientific_publication_label(artifact_schema)
    version = _scientific_publication_label(artifact_version)
    identity = _scientific_publication_label(publication_identity)
    source = _scientific_publication_source(path)
    before = scientific_file_state(source)
    expected_state === nothing ||
        isequal(before, expected_state) ||
        throw(ArgumentError("SCIENTIFIC_FILE_PUBLICATION_VALIDATED_SOURCE_CHANGED"))
    receipt = _scientific_publication_receipt(source, receipt_path)
    write_task_input_file(
        receipt,
        Dict(
            "schema" => SCIENTIFIC_FILE_PUBLICATION_SCHEMA,
            "artifact_schema" => schema,
            "artifact_version" => version,
            "artifact_file" => basename(source),
            "publication_identity" => identity,
            "file_lifetime" => _scientific_publication_lifetime(before),
        ),
    )
    isequal(before, scientific_file_state(source)) ||
        throw(ArgumentError("SCIENTIFIC_FILE_PUBLICATION_CHANGED_DURING_COMMIT"))
    return receipt
end

"""Read one scientific publication under stable payload and receipt observations.

The callback receives the canonical payload path and the adopted publication
label, which its format decoder must compare with that payload's own declaration.
Only exact current artifact schemas/versions and local file observations pass.
All format, shape, finite-value and domain validation remains in the decoder.
"""
function with_scientific_file_publication(
    reader::F,
    path::AbstractString;
    artifact_schema::AbstractString,
    artifact_version::AbstractString,
    receipt_path::Union{Nothing, AbstractString} = nothing,
) where {F}
    schema = _scientific_publication_label(artifact_schema)
    version = _scientific_publication_label(artifact_version)
    source = _scientific_publication_source(path)
    scoped=get(task_local_storage(), :wannier_scientific_publication_receipts, nothing)
    selected_receipt=receipt_path===nothing && scoped!==nothing ? get(scoped, source, nothing) :
                     receipt_path
    observed =
        with_scientific_source(_scientific_publication_receipt(source, selected_receipt)) do receipt
            document = read_task_input_file(receipt).document
            get(document, "schema", nothing) == SCIENTIFIC_FILE_PUBLICATION_SCHEMA || throw(
                ArgumentError("SCIENTIFIC_FILE_PUBLICATION_MIGRATION_REQUIRED: expected receipt2"),
            )
            Set(keys(document)) == Set((
                "schema",
                "artifact_schema",
                "artifact_version",
                "artifact_file",
                "publication_identity",
                "file_lifetime",
            )) &&
            document["schema"] == SCIENTIFIC_FILE_PUBLICATION_SCHEMA &&
            document["artifact_schema"] == schema &&
            document["artifact_version"] == version &&
            document["artifact_file"] == basename(source) ||
                throw(ArgumentError("SCIENTIFIC_FILE_PUBLICATION_FORMAT_UNSUPPORTED"))
            identity = _scientific_publication_label(document["publication_identity"])
            payload = with_scientific_source(source) do filename
                _validate_scientific_publication_lifetime(
                    document["file_lifetime"],
                    scientific_file_state(filename),
                )
                reader(filename, identity)
            end
            (; value = payload.value, state = payload.state, publication_identity = identity)
        end
    return merge(observed.value, (; receipt_state = observed.state))
end

"""Select already explicit private admission receipts for one reader callback.

No input is adopted or written here. Each actual read validates the selected
receipt's format, publication identity and complete file lifetimes as usual.
Nested scopes use private dictionaries and restore their parent on return/error.
This supports read-only frozen fixtures without modifying the source directory.
"""
function with_scientific_publication_receipts(reader::F, records::AbstractDict) where {F}
    parent=get(task_local_storage(), :wannier_scientific_publication_receipts, nothing)
    selected=parent===nothing ? Dict{String, String}() : copy(parent)
    for (source, receipt) in records
        source isa AbstractString && receipt isa AbstractString ||
            throw(ArgumentError("PublicationReceiptPathsMustBeStrings"))
        selected[realpath(source)]=abspath(receipt)
    end
    return task_local_storage(reader, :wannier_scientific_publication_receipts, selected)
end
