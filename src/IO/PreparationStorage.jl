"""Local lifetime and layout of one atomically published private disk element."""
struct PreparationDiskPublication
    generation::String
    state::NamedTuple
    layout::NamedTuple
end

"""Private bounded vector whose elements are atomically stored outside the Julia heap.

The format is a process-version-bound workspace, never a public scientific artifact.
Each element is serialized without changing any numerical arithmetic. Callers must
not mutate elements after publication. Reads are serialized and retain one element.
"""
mutable struct PreparationDiskVector{T} <: AbstractVector{T}
    directory::String
    count::Int
    publications::Vector{Union{Nothing, PreparationDiskPublication}}
    cached_index::Int
    cached_value::Union{Nothing, T}
    mutex::ReentrantLock
end

"""Declare linear indexing for private preparation storage."""
Base.IndexStyle(::Type{<:PreparationDiskVector}) = IndexLinear()
"""Return the number of stored preparation elements."""
Base.size(values::PreparationDiskVector) = (values.count,)

"""Read an immutable source through one bounded, task-independent cache."""
mutable struct PreparationSourceVector{T, F} <: AbstractVector{T}
    loader::F
    count::Int
    cached_index::Int
    cached_value::Union{Nothing, T}
    mutex::ReentrantLock
end
"""Declare linear indexing for private preparation storage."""
Base.IndexStyle(::Type{<:PreparationSourceVector}) = IndexLinear()
"""Return the number of stored preparation elements."""
Base.size(values::PreparationSourceVector) = (values.count,)

"""Read one verified preparation element under its exclusive cache lock."""
function Base.getindex(values::PreparationSourceVector{T}, index::Int) where {T}
    checkbounds(values, index)
    return lock(values.mutex) do
        values.cached_index == index && return something(values.cached_value)
        value = values.loader(index)::T
        values.cached_index = index
        values.cached_value = value
        return value
    end
end

"""Register one bounded immutable-source provider in the current storage scope."""
function preparation_source_vector(loader::F, ::Type{T}, count::Int) where {F, T}
    values = PreparationSourceVector{T, F}(loader, count, 0, nothing, ReentrantLock())
    context = get(task_local_storage(), :wannier_preparation_storage, nothing)
    context === nothing || push!(context.vectors, values)
    return values
end

"""Describe the stored type and array shape without inspecting coefficient values."""
_preparation_disk_layout(value) = (;
    payload_type = string(typeof(value)),
    dimensions = value isa AbstractArray ? size(value) : nothing,
)

"""Read one owned publication, checking its lifetime, envelope, type and layout.

These observations are local publication credentials, not portable byte certificates.
Only one element is reconstructed at a time, including during restart validation.
"""
function _read_preparation_disk_entry(values::PreparationDiskVector{T}, index::Int) where {T}
    publication = values.publications[index]
    publication === nothing && throw(UndefRefError())
    path = joinpath(values.directory, string(index) * ".bin")
    isequal(scientific_file_state(path), publication.state) ||
        throw(ArgumentError("PREPARATION_STORAGE_PUBLICATION_CHANGED: index=$(index)"))
    value = open(path, "r") do stream
        record = Serialization.deserialize(stream)
        record isa NamedTuple &&
        keys(record) == (:schema, :generation, :payload) &&
        record.schema == "wanniernlqg.preparation-disk-element/2" &&
        record.generation == publication.generation &&
        record.payload isa T &&
        eof(stream) ||
            throw(ArgumentError("PREPARATION_STORAGE_ENVELOPE_INVALID: index=$(index)"))
        record.payload
    end
    isequal(_preparation_disk_layout(value), publication.layout) &&
    isequal(scientific_file_state(path), publication.state) ||
        throw(ArgumentError("PREPARATION_STORAGE_LAYOUT_OR_LIFETIME_CHANGED: index=$(index)"))
    return value
end

"""Read one element; even a resident hit must retain its publication lifetime."""
function Base.getindex(values::PreparationDiskVector{T}, index::Int) where {T}
    checkbounds(values, index)
    return lock(values.mutex) do
        publication = values.publications[index]
        publication === nothing && throw(UndefRefError())
        path = joinpath(values.directory, string(index) * ".bin")
        isequal(scientific_file_state(path), publication.state) ||
            throw(ArgumentError("PREPARATION_STORAGE_PUBLICATION_CHANGED: index=$(index)"))
        values.cached_index == index && return something(values.cached_value)
        value = _read_preparation_disk_entry(values, index)
        values.cached_index = index
        values.cached_value = value
        return value
    end
end

"""Publish one element atomically without retaining its large payload."""
function Base.setindex!(values::PreparationDiskVector{T}, value::T, index::Int) where {T}
    checkbounds(values, index)
    lock(values.mutex) do
        path = joinpath(values.directory, string(index) * ".bin")
        temporary, stream = mktemp(values.directory)
        try
            generation = scientific_data_generation(ScientificDataOwner())
            Serialization.serialize(
                stream,
                (; schema = "wanniernlqg.preparation-disk-element/2", generation, payload = value),
            )
            close(stream)
            mv(temporary, path; force = true)
            values.publications[index] = PreparationDiskPublication(
                generation,
                scientific_file_state(path),
                _preparation_disk_layout(value),
            )
            values.cached_index = 0
            values.cached_value = nothing
        finally
            isopen(stream) && close(stream)
            isfile(temporary) && rm(temporary)
        end
    end
    return value
end

"""Append one element under the vector publication lock."""
function Base.push!(values::PreparationDiskVector{T}, value::T) where {T}
    lock(values.mutex) do
        values.count += 1
        push!(values.publications, nothing)
        values[values.count] = value
    end
    return values
end

"""Allocate an ordinary vector unless the task has opted into disk-backed preparation."""
function preparation_vector(::Type{T}, label::String, count::Int = 0) where {T}
    context = get(task_local_storage(), :wannier_preparation_storage, nothing)
    context === nothing && return Vector{T}(undef, count)
    directory = mktempdir(context.directory; prefix = label * "-", cleanup = false)
    values = PreparationDiskVector{T}(
        directory,
        count,
        Union{Nothing, PreparationDiskPublication}[nothing for _ in 1:count],
        0,
        nothing,
        ReentrantLock(),
    )
    push!(context.vectors, values)
    return values
end

"""Prepare an owned storage scope before entering a collective numerical phase."""
function prepare_preparation_storage_context(directory::String)
    mkpath(directory)
    return (directory = directory, vectors = Any[])
end

"""Install a prepared scope without performing file-system operations."""
function with_preparation_storage_context(f::Function, context::NamedTuple)
    return task_local_storage(f, :wannier_preparation_storage, context)
end

"""Run one task with explicitly scoped private storage; nested calls restore their context."""
function with_preparation_storage(f::Function, directory::String)
    return with_preparation_storage_context(f, prepare_preparation_storage_context(directory))
end

"""Drop cached elements at a work boundary, preserving every published payload."""
function preparation_release!()
    context = get(task_local_storage(), :wannier_preparation_storage, nothing)
    context === nothing && return nothing
    for values in context.vectors
        lock(values.mutex) do
            values.cached_index = 0
            values.cached_value = nothing
        end
    end
    GC.gc(false)
    return nothing
end

const PREPARATION_CHECKPOINT_PREFIX =
    "WANNIERNLQG_PREPARATION_CHECKPOINT_V3:" * string(VERSION) * "\n"

"""Reject an old workspace explicitly, without migrating or overwriting its files."""
function _require_preparation_checkpoint_format(path::String)
    islink(path) && throw(ArgumentError("PREPARATION_CHECKPOINT_LINK_UNSUPPORTED"))
    supported = open(path, "r") do stream
        read(stream, ncodeunits(PREPARATION_CHECKPOINT_PREFIX)) ==
        collect(codeunits(PREPARATION_CHECKPOINT_PREFIX))
    end
    supported || throw(ArgumentError("PREPARATION_CHECKPOINT_FORMAT_UNSUPPORTED: $(path)"))
    return nothing
end

"""Publish a private payload and an independently atomic local commit receipt.

Serialization adopts the numerical values without a second full-payload hash pass.
The receipt binds the complete contract, publication generation, Julia version,
stored type/layout and observed file lifetime. It is not a portable certificate.
"""
function write_preparation_checkpoint(path::String, contract::String, payload)
    ispath(path) && _require_preparation_checkpoint_format(path)
    mkpath(dirname(path))
    temporary, stream = mktemp(dirname(path))
    generation = scientific_data_generation(ScientificDataOwner())
    try
        write(stream, PREPARATION_CHECKPOINT_PREFIX)
        Serialization.serialize(
            stream,
            (;
                schema = "wanniernlqg.preparation-checkpoint/3",
                julia_version = string(VERSION),
                generation,
                contract,
                payload,
            ),
        )
        close(stream)
        mv(temporary, path; force = true)
        receipt = Dict(
            "schema" => "wanniernlqg.preparation-commit/3",
            "julia_version" => string(VERSION),
            "generation" => generation,
            "contract" => contract,
            "payload_identity" => scientific_file_identity(path),
            "payload_layout" => repr(_preparation_disk_layout(payload)),
        )
        write_task_input_file(path * ".commit.toml", receipt)
    finally
        isopen(stream) && close(stream)
        isfile(temporary) && rm(temporary)
    end
    return path
end

"""Return only a committed owned checkpoint with exactly the requested contract."""
function read_preparation_checkpoint(path::String, contract::String)
    verified = _read_preparation_checkpoint_verified(path, contract)
    return verified === nothing ? nothing : verified.payload
end

"""Read a bounded commit receipt through the central parser.

Malformed/truncated receipts are uncommitted work. A recognized incompatible
schema is an explicit error, preserving the old workspace for its original reader.
"""
function _preparation_commit_receipt(path)
    filesize(path) <= 1024^2 || throw(ArgumentError("PREPARATION_COMMIT_RECEIPT_TOO_LARGE"))
    parsed = try
        read_task_input_file(path)
    catch exception
        exception isa TOML.ParserError || rethrow()
        return nothing
    end
    document = parsed.document
    fields =
        ("schema", "julia_version", "generation", "contract", "payload_identity", "payload_layout")
    Set(keys(document)) == Set(fields) &&
    all(key -> document[key] isa String, fields) &&
    document["schema"] == "wanniernlqg.preparation-commit/3" &&
    document["julia_version"] == string(VERSION) &&
    !isempty(document["generation"]) ||
        throw(ArgumentError("PREPARATION_COMMIT_SCHEMA_UNSUPPORTED"))
    return (; document, identity = parsed.identity)
end

"""Read once under a committed local lifetime; domain validators remain at consumers.

The optional generation is used only when refreshing a resident payload after a
metadata-only observation change. That caller must compare against its owned copy
before publishing any refreshed receipt.
"""
function _read_preparation_checkpoint_verified(
    path::String,
    contract::String;
    resident_generation::Union{Nothing, String} = nothing,
)
    isfile(path) || return nothing
    ready = path * ".commit.toml"
    # A legacy commit is recognized only to reject its old payload explicitly.
    isfile(ready) || isfile(path * ".sha256") || return nothing
    _require_preparation_checkpoint_format(path)
    isfile(ready) || return nothing
    receipt = _preparation_commit_receipt(ready)
    receipt === nothing && return nothing
    document = receipt.document
    document["contract"] == contract || return nothing
    before = scientific_file_state(path)
    if resident_generation === nothing
        scientific_file_identity(before) == document["payload_identity"] || return nothing
    else
        document["generation"] == resident_generation || return nothing
    end
    record = open(path, "r") do stream
        read(stream, ncodeunits(PREPARATION_CHECKPOINT_PREFIX)) ==
        collect(codeunits(PREPARATION_CHECKPOINT_PREFIX)) || return nothing
        value = Serialization.deserialize(stream)
        eof(stream) || return nothing
        value
    end
    isequal(before, scientific_file_state(path)) &&
    receipt.identity == scientific_file_identity(ready) ||
        throw(ArgumentError("PREPARATION_CHECKPOINT_CHANGED_DURING_READ: $(path)"))
    record isa NamedTuple &&
    keys(record) == (:schema, :julia_version, :generation, :contract, :payload) &&
    record.schema == "wanniernlqg.preparation-checkpoint/3" &&
    record.julia_version == string(VERSION) ||
        throw(ArgumentError("PREPARATION_CHECKPOINT_SCHEMA_UNSUPPORTED: $(path)"))
    record.contract == contract &&
    record.generation == document["generation"] &&
    repr(_preparation_disk_layout(record.payload)) == document["payload_layout"] || return nothing
    return (; payload = record.payload, generation = record.generation, receipt = document)
end

"""Validate and register every disk-vector dependency of a private stage checkpoint.

Only scientific containers are traversed. Numeric arrays are leaves. Each owned
serialized dependency is reconstructed independently to check its envelope, type
and shape; the complete coefficient inventory is never materialized together.
"""
function preparation_restore_vectors!(
    payload;
    verify::Bool = true,
    register::Bool = true,
    retained_directories = Set{String}(),
)
    context = get(task_local_storage(), :wannier_preparation_storage, nothing)
    seen = IdDict{Any, Bool}()
    vectors = Any[]
    function visit(value)
        value isa Number ||
            value isa AbstractString ||
            value isa Symbol ||
            value === nothing ||
            value isa Function ||
            value isa Type ||
            value isa Module ||
            value isa ReentrantLock ||
            isbitstype(typeof(value)) ? (return true) : nothing
        haskey(seen, value) && return true
        seen[value] = true
        if value isa PreparationDiskVector
            value.cached_index = 0
            value.cached_value = nothing
            length(value.publications) == value.count || return false
            if verify
                for index in eachindex(value.publications)
                    path = joinpath(value.directory, string(index) * ".bin")
                    isfile(path) && !islink(path) || return false
                    value.publications[index] === nothing && return false
                    try
                        _read_preparation_disk_entry(value, index)
                    catch exception
                        exception isa Union{ArgumentError, EOFError, TypeError} || rethrow()
                        return false
                    end
                end
            end
            push!(retained_directories, normpath(value.directory))
            push!(vectors, value)
            return true
        elseif value isa PreparationSourceVector
            return false # Live reader closures are never restart payloads.
        elseif value isa PreparationDiskDict
            return visit(value.values)
        elseif value isa AbstractArray
            isbitstype(eltype(value)) && return true
            return all(visit, value)
        elseif value isa AbstractDict
            return all(pair -> visit(first(pair)) && visit(last(pair)), value)
        end
        return all(name -> visit(getfield(value, name)), fieldnames(typeof(value)))
    end
    visit(payload) || return false
    (context === nothing || !register) || append!(context.vectors, vectors)
    return true
end

"""Private keyed index over a bounded coefficient store."""
struct PreparationDiskDict{K, V} <: AbstractDict{K, V}
    indices::Dict{K, Int}
    values::PreparationDiskVector{V}
end
"""Return the keyed preparation inventory size."""
Base.length(values::PreparationDiskDict) = length(values.indices)
"""Expose keys without loading coefficient payloads."""
Base.keys(values::PreparationDiskDict) = keys(values.indices)
"""Test membership without loading coefficient payloads."""
Base.haskey(values::PreparationDiskDict, key) = haskey(values.indices, key)
"""Read one keyed coefficient payload through bounded storage."""
Base.getindex(values::PreparationDiskDict, key) = values.values[values.indices[key]]
"""Publish one keyed coefficient payload with the underlying atomic store."""
function Base.setindex!(values::PreparationDiskDict{K, V}, value::V, key::K) where {K, V}
    if haskey(values.indices, key)
        values.values[values.indices[key]] = value
    else
        push!(values.values, value)
        values.indices[key] = length(values.values)
    end
    return value
end
"""Iterate keyed values in the original Dict inventory order."""
function Base.iterate(values::PreparationDiskDict, state...)
    next = iterate(values.indices, state...)
    next === nothing && return nothing
    pair, position = next
    return (first(pair) => values.values[last(pair)], position)
end
"""Allocate keyed disk storage only inside a preparation storage scope."""
function preparation_dictionary(::Type{K}, ::Type{V}, label::String) where {K, V}
    context = get(task_local_storage(), :wannier_preparation_storage, nothing)
    context === nothing && return Dict{K, V}()
    return PreparationDiskDict(Dict{K, Int}(), preparation_vector(V, label))
end
"""Overlay sealed representatives without copying the complete wavefunction grid."""
function preparation_sealed_vector(parent::AbstractVector{T}, replacements, indices) where {T}
    if get(task_local_storage(), :wannier_preparation_storage, nothing) === nothing
        points = copy(parent)
        for index in indices
            points[index] = replacements[index]
        end
        return points
    end
    selected = Set(indices)
    return preparation_source_vector(T, length(parent)) do index
        index in selected ? replacements[index] : parent[index]
    end
end

"""Release superseded private arrays only after a merged payload is atomically committed.

Per-star checkpoints remain intact. Earlier stage records whose arrays are superseded
will fail dependency validation if the merged payload itself ever needs rebuilding.
"""
function preparation_compact_workspace!(payload)
    context = get(task_local_storage(), :wannier_preparation_storage, nothing)
    context === nothing && return (removed_directories = String[], removed_bytes = 0)
    retained = Set{String}()
    preparation_restore_vectors!(
        payload;
        verify = false,
        register = false,
        retained_directories = retained,
    ) || return (removed_directories = String[], removed_bytes = 0)
    removed = String[]
    bytes = 0
    prefix = normpath(context.directory) * string(Base.Filesystem.path_separator)
    for values in context.vectors
        values isa PreparationDiskVector || continue
        directory = normpath(values.directory)
        directory in retained && continue
        startswith(directory, prefix) && isdir(directory) || continue
        for (root, _, names) in walkdir(directory), name in names
            bytes += filesize(joinpath(root, name))
        end
        rm(directory; recursive = true)
        push!(removed, directory)
    end
    filter!(context.vectors) do values
        !(values isa PreparationDiskVector) || normpath(values.directory) in retained
    end
    return (removed_directories = removed, removed_bytes = bytes)
end

"""Bind one cached block to every actual input value with bounded reference IO.

The index locates a local reference; its name/state never proves equality. A
complete streamed comparison precedes cache reuse. Changed inputs create a new
reference and contract, retaining earlier references and accepted cache bytes.
"""
function _preparation_block_input_contract(values, item, path, contract)
    path===nothing && return repr(("preparation-uncached-input/1", contract))
    index_path=path*".input.toml"
    if isfile(index_path)
        filesize(index_path)<=1024^2 || throw(ArgumentError("PREPARATION_INPUT_INDEX_TOO_LARGE"))
        document=read_task_input_file(index_path).document
        Set(keys(document))==Set(["schema", "reference"]) &&
        document["schema"]=="wanniernlqg.preparation-block-input/1" &&
        document["reference"] isa String ||
            throw(ArgumentError("PREPARATION_INPUT_INDEX_SCHEMA_UNSUPPORTED"))
        name=document["reference"]
        basename(name)==name && !isabspath(name) && startswith(name, basename(path)*".input-") ||
            throw(ArgumentError("PREPARATION_INPUT_REFERENCE_PATH_INVALID"))
        reference=joinpath(dirname(path), name)
        if isfile(reference)
            before=scientific_file_state(reference)
            definition=ScientificInputDefinition(reference, before, Int(before.bytes))
            equal=try
                validate_scientific_input_definition_bytes(definition) do stream
                    write_native_definition_value(
                        stream,
                        ("preparation-block-values/1", values(item)),
                    )
                end
                true
            catch exception
                exception isa ArgumentError &&
                exception.msg=="SCIENTIFIC_INPUT_DEFINITION_MISMATCH" || rethrow()
                false
            end
            equal && return repr(("preparation-block-input/1", contract, before))
        end
    end
    definition=scientific_input_definition_bytes() do stream
        write_native_definition_value(stream, ("preparation-block-values/1", values(item)))
    end
    mkpath(dirname(path))
    reference=joinpath(dirname(path), basename(path)*".input-"*basename(definition.path))
    with_scientific_input_definition_bytes(definition) do source
        # Close the observation before rename; no other process owns this scratch.
        definition.byte_count>0 || throw(ArgumentError("PREPARATION_INPUT_REFERENCE_EMPTY"))
    end
    mv(definition.path, reference; force = false)
    before=scientific_file_state(reference)
    write_task_input_file(
        index_path,
        Dict("schema"=>"wanniernlqg.preparation-block-input/1", "reference"=>basename(reference)),
    )
    return repr(("preparation-block-input/1", contract, before))
end

"""Bound independent pure work; loading and persistence stay on the coordinator task."""
function foreach_preparation_block(
    work,
    load,
    consume,
    count::Int;
    contract::String,
    label::String,
    fingerprint = item -> "",
    fingerprint_index = nothing,
    input_values = nothing,
    reuse_completed_blocks::Bool = true,
)
    input_values!==nothing &&
        fingerprint_index!==nothing &&
        throw(ArgumentError("PREPARATION_COMPLETE_INPUT_REQUIRES_LOADED_BLOCK"))
    execution = get(task_local_storage(), :wannier_preparation_execution, nothing)
    mode = execution === nothing ? :streaming_serial : execution.mode
    mode in (:dense_reference, :streaming_serial, :streaming_threads) ||
        throw(ArgumentError("invalid preparation execution mode"))
    requested = execution === nothing ? 1 : execution.max_workers
    1 <= requested <= 4 || throw(ArgumentError("preparation workers must be between 1 and 4"))
    budget = execution === nothing ? 24 * 1024^3 : execution.memory_budget_bytes
    budget > 0 || throw(ArgumentError("preparation memory budget must be positive"))
    workers = mode == :streaming_threads ? min(requested, Threads.nthreads()) : 1
    directory = execution === nothing ? nothing : execution.checkpoint_directory
    occursin(r"^[a-zA-Z0-9_-]+$", label) || throw(ArgumentError("invalid preparation stage label"))
    index = 1
    while index <= count
        stop_file = get(ENV, "WANNIERNLQG_PREPARATION_STOP_FILE", "")
        isempty(stop_file) ||
            !isfile(stop_file) ||
            throw(ArgumentError("MEMORY_BUDGET_HOLD: preparation stop requested"))
        tasks = Tuple{Int, String, Bool, Task}[]
        batch_start = time()
        try
            for _ in 1:workers
                index > count && break
                current = index
                index += 1
                path =
                    directory === nothing ? nothing :
                    joinpath(directory, label, "block-$(current).bin")
                # Loading, fingerprinting and all persistence are coordinator-owned.
                item = fingerprint_index === nothing ? load(current) : nothing
                if input_values!==nothing && path!==nothing
                    reference_bytes=Base.summarysize(item)+65536
                    reference_allowance=floor(Int, 0.75budget)-max(2*1024^3, Sys.maxrss())
                    reference_bytes<=reference_allowance || throw(
                        ArgumentError("MEMORY_BUDGET_HOLD: preparation input reference workspace"),
                    )
                end
                item_contract =
                    input_values===nothing ?
                    contract *
                    ":" *
                    (fingerprint_index === nothing ? fingerprint(item) : fingerprint_index(current)) :
                    _preparation_block_input_contract(input_values, item, path, contract)
                saved =
                    path === nothing || !execution.resume || !reuse_completed_blocks ? nothing :
                    read_preparation_checkpoint(path, item_contract)
                if saved !== nothing
                    task = let value = saved
                        Threads.@spawn identity(value)
                    end
                    push!(tasks, (current, item_contract, true, task))
                    continue
                end
                fingerprint_index === nothing || (item = load(current))
                estimate =
                    6 * Base.summarysize(item) +
                    (input_values===nothing || path===nothing ? 0 : 65536)
                reserve = max(2 * 1024^3, Sys.maxrss())
                allowance = floor(Int, 0.75 * budget) - reserve
                estimate <= allowance || throw(
                    ArgumentError(
                        "MEMORY_BUDGET_HOLD: single preparation block exceeds working-set allowance",
                    ),
                )
                workers = min(workers, max(1, allowance ÷ max(1, estimate)))
                task = Threads.@spawn work($current, $item)
                push!(tasks, (current, item_contract, false, task))
                length(tasks) >= workers && break
            end
            for (current, item_contract, resumed, task) in tasks
                result = fetch(task)
                # Validate the consumer contract before recording a completed payload.
                consume(current, result)
                if directory !== nothing && !resumed
                    write_preparation_checkpoint(
                        joinpath(directory, label, "block-$(current).bin"),
                        item_contract,
                        result,
                    )
                end
            end
            if directory !== nothing
                mkpath(directory)
                open(joinpath(directory, "execution_events.jsonl"), "a") do stream
                    println(
                        stream,
                        "{\"stage\":\"",
                        label,
                        "\",\"event\":\"BATCH_COMMITTED\",\"next_index\":",
                        index,
                        ",\"workers\":",
                        workers,
                        ",\"wall_seconds\":",
                        time() - batch_start,
                        ",\"peak_rss_bytes\":",
                        Sys.maxrss(),
                        ",\"resumed_blocks\":",
                        Base.count(record -> record[3], tasks),
                        "}",
                    )
                end
            end
        finally
            # Never leave pure worker tasks running after a load/compute/commit failure.
            for record in tasks
                try
                    wait(record[4])
                catch
                    # fetch above retains the canonical first failure.
                end
            end
            preparation_release!()
        end
    end
    return nothing
end

"""Limit durable derived artifacts to one explicitly input- and implementation-bound scope."""
function with_preparation_artifact_cache(
    f::F,
    directory::AbstractString,
    contract::AbstractString;
    max_artifact_bytes::Int = 256 * 1024^2,
    max_resident_bytes::Int = 64 * 1024^2,
) where {F}
    isempty(contract) && throw(ArgumentError("PREPARATION_CACHE_CONTRACT_REQUIRED"))
    max_artifact_bytes > 0 || throw(ArgumentError("PREPARATION_CACHE_INVALID_BUDGET"))
    max_resident_bytes >= 0 || throw(ArgumentError("PREPARATION_CACHE_INVALID_BUDGET"))
    context = (
        directory = abspath(directory),
        contract = String(contract),
        max_artifact_bytes = max_artifact_bytes,
        max_resident_bytes = max_resident_bytes,
        resident_bytes = Ref(0),
        resident = Dict{String, Any}(),
        catalogs = Dict{String, Any}(),
        recency = String[],
        owner = current_task(),
    )
    return task_local_storage(f, :wannier_preparation_artifact_cache, context)
end

"""Append coordinator-owned progress without changing scientific cache payloads."""
function _preparation_artifact_event(context, label, event, unit, seconds)
    mkpath(context.directory)
    open(joinpath(context.directory, "preparation_progress.jsonl"), "a") do stream
        println(
            stream,
            "{\"stage\":\"",
            label,
            "\",\"event\":\"",
            event,
            "\",\"unit\":",
            unit === nothing ? "null" : string(unit),
            ",\"wall_seconds\":",
            seconds,
            ",\"time_unix\":",
            time(),
            "}",
        )
    end
    return nothing
end

"""Observe a payload and its commit receipt without scanning coefficient arrays."""
function _preparation_artifact_identity(path)
    isfile(path) && isfile(path * ".commit.toml") || return nothing
    return map((path, path * ".commit.toml")) do file
        value = stat(file)
        (value.device, value.inode, value.size, value.mtime, value.ctime)
    end
end

"""Refresh only after directly comparing a changed publication with the owned payload.

Ordinary resident hits compare bounded observations only. A ctime-only change
requires a new read and exact value comparison, retaining the original resident
copy and generation. Other lifetime changes invalidate the entry.
"""
function _preparation_verified_artifact_identity(
    path,
    identity,
    generation;
    payload = nothing,
    contract = nothing,
)
    current = _preparation_artifact_identity(path)
    current == identity && return current
    current === nothing && return nothing
    identity === nothing && return nothing
    all(i -> current[i][1:4] == identity[i][1:4], eachindex(current)) || return nothing
    contract === nothing && return nothing
    payload_before = scientific_file_state(path)
    (
        payload_before.device,
        payload_before.inode,
        payload_before.bytes,
        payload_before.mtime,
        payload_before.ctime,
    ) == current[1] || return nothing
    saved = _read_preparation_checkpoint_verified(path, contract; resident_generation = generation)
    saved === nothing && return nothing
    isequal(saved.payload, payload) || return nothing
    after = _preparation_artifact_identity(path)
    isequal(after, current) || return nothing
    receipt = copy(saved.receipt)
    receipt["payload_identity"] = scientific_file_identity(payload_before)
    write_task_input_file(path * ".commit.toml", receipt)
    refreshed = _preparation_artifact_identity(path)
    refreshed === nothing && return nothing
    isequal(refreshed[1], current[1]) || return nothing
    return refreshed
end

"""Evict one private compact artifact and update its resident byte accounting."""
function _preparation_forget_artifact!(context, key)
    entry = pop!(context.resident, key)
    context.resident_bytes[] -= entry.bytes
    deleteat!(context.recency, something(findfirst(==(key), context.recency)))
    return nothing
end

"""Retain an isolated committed payload within the explicit resident byte budget."""
function _preparation_remember_artifact!(context, key, payload, identity, generation)
    bytes = Base.summarysize(payload)
    bytes <= context.max_resident_bytes || return nothing
    while context.resident_bytes[] + bytes > context.max_resident_bytes
        _preparation_forget_artifact!(context, first(context.recency))
    end
    context.resident[key] = (; payload = deepcopy(payload), identity, generation, bytes)
    push!(context.recency, key)
    context.resident_bytes[] += bytes
    return nothing
end

"""Read the actual contract-to-slot catalog; old hash-named artifacts stay untouched."""
function _preparation_contract_catalog(context, label, path)
    isfile(path) || return Dict{String, Int}()
    state = scientific_file_identity(path)
    cached = get(context.catalogs, label, nothing)
    cached !== nothing && cached.identity == state && return copy(cached.slots)
    filesize(path) <= context.max_artifact_bytes ||
        throw(ArgumentError("PREPARATION_CACHE_CATALOG_TOO_LARGE"))
    parsed = read_task_input_file(path)
    document = parsed.document
    Set(keys(document)) == Set(["schema", "julia_version", "entries"]) &&
    document["schema"] == "wanniernlqg.preparation-contract-catalog/2" &&
    document["julia_version"] == string(VERSION) ||
        throw(ArgumentError("PREPARATION_CACHE_CATALOG_SCHEMA_UNSUPPORTED"))
    document["entries"] isa AbstractVector ||
        throw(ArgumentError("PREPARATION_CACHE_CATALOG_ENTRIES_INVALID"))
    slots = Dict{String, Int}()
    assigned = Set{Int}()
    for entry in document["entries"]
        Set(keys(entry)) == Set(["contract", "slot"]) &&
        entry["contract"] isa String &&
        entry["slot"] isa Int &&
        entry["slot"] > 0 || throw(ArgumentError("PREPARATION_CACHE_CATALOG_ENTRY_INVALID"))
        haskey(slots, entry["contract"]) &&
            throw(ArgumentError("PREPARATION_CACHE_CATALOG_DUPLICATE_CONTRACT"))
        entry["slot"] in assigned &&
            throw(ArgumentError("PREPARATION_CACHE_CATALOG_DUPLICATE_SLOT"))
        slots[entry["contract"]] = entry["slot"]
        push!(assigned, entry["slot"])
    end
    context.catalogs[label] = (; identity = parsed.identity, slots = copy(slots))
    return slots
end

"""Locate durable artifacts by their complete definition, with atomic slot allocation.

The short-lived directory lock protects only catalog publication. A stale lock
fails explicitly; it never authorizes process signaling or automatic lock removal.
"""
function _preparation_contract_path(context, label, contract; create::Bool)
    directory = joinpath(context.directory, label)
    version = replace(string(VERSION), '.' => '_', '-' => '_', '+' => '_')
    catalog = joinpath(directory, "artifact-index-v2-" * version * ".toml")
    slots = _preparation_contract_catalog(context, label, catalog)
    slot = get(slots, contract, nothing)
    if slot === nothing && create
        mkpath(directory)
        lock_path = catalog * ".lock"
        deadline = time() + 5.0
        while true
            try
                mkdir(lock_path)
                break
            catch exception
                isdir(lock_path) || rethrow()
                time() < deadline || throw(ArgumentError("PREPARATION_CACHE_CATALOG_LOCK_BUSY"))
                sleep(0.01)
            end
        end
        try
            # Another coordinator may have committed a slot before this lock.
            delete!(context.catalogs, label)
            slots = _preparation_contract_catalog(context, label, catalog)
            slot = get(slots, contract, nothing)
            if slot === nothing
                slot = isempty(slots) ? 1 : maximum(values(slots)) + 1
                slots[contract] = slot
                Base.summarysize(slots) <= context.max_artifact_bytes ||
                    throw(ArgumentError("PREPARATION_CACHE_CATALOG_TOO_LARGE"))
                temporary, stream = mktemp(directory)
                try
                    TOML.print(
                        stream,
                        Dict(
                            "schema" => "wanniernlqg.preparation-contract-catalog/2",
                            "julia_version" => string(VERSION),
                            "entries" => [
                                Dict("contract" => key, "slot" => value) for
                                (key, value) in sort!(collect(slots); by = last)
                            ],
                        );
                        sorted = true,
                    )
                    close(stream)
                    mv(temporary, catalog; force = true)
                finally
                    isopen(stream) && close(stream)
                    isfile(temporary) && rm(temporary)
                end
                context.catalogs[label] =
                    (; identity = scientific_file_identity(catalog), slots = copy(slots))
            end
        finally
            rm(lock_path)
        end
    end
    slot === nothing && return nothing
    return joinpath(directory, "artifact-v3-" * version * "-" * string(slot) * ".bin")
end

"""Reuse compact derived data; mutable wavefunction state is never retained here."""
function cached_preparation_artifact(
    builder::F,
    label::String,
    identity::G;
    unit::Union{Nothing, Int} = nothing,
    build_missing::Bool = true,
) where {F, G}
    context = get(task_local_storage(), :wannier_preparation_artifact_cache, nothing)
    context === nothing && return build_missing ? builder() : nothing
    context.owner === current_task() ||
        throw(ArgumentError("PREPARATION_ARTIFACT_CACHE_COORDINATOR_REQUIRED"))
    occursin(r"^[a-zA-Z0-9_-]+$", label) || throw(ArgumentError("invalid derived artifact label"))
    contract = repr((
        scope = context.contract,
        julia_version = string(VERSION),
        label = label,
        input_definition = String(identity()),
    ))
    key = contract
    path = _preparation_contract_path(context, label, contract; create = build_missing)
    path === nothing && return nothing
    started = time()
    identity_before = _preparation_artifact_identity(path)
    if haskey(context.resident, key)
        entry = context.resident[key]
        refreshed = _preparation_verified_artifact_identity(
            path,
            entry.identity,
            entry.generation;
            payload = entry.payload,
            contract = contract,
        )
        if refreshed !== nothing
            context.resident[key] = merge(entry, (; identity = refreshed))
            deleteat!(context.recency, something(findfirst(==(key), context.recency)))
            push!(context.recency, key)
            _preparation_artifact_event(context, label, "MEMORY_HIT", unit, time() - started)
            return deepcopy(entry.payload)
        end
        _preparation_forget_artifact!(context, key)
    end
    verified = _read_preparation_checkpoint_verified(path, contract)
    if verified !== nothing
        payload = verified.payload
        identity_after =
            _preparation_verified_artifact_identity(path, identity_before, verified.generation)
        identity_after !== nothing ||
            throw(ArgumentError("PREPARATION_CACHE_CHANGED_DURING_READ: $(label)"))
        _preparation_remember_artifact!(context, key, payload, identity_after, verified.generation)
        _preparation_artifact_event(context, label, "CACHE_HIT", unit, time() - started)
        return payload
    end
    build_missing || return nothing
    _preparation_artifact_event(context, label, "BUILD_STARTED", unit, 0.0)
    payload = builder()
    Base.summarysize(payload) <= context.max_artifact_bytes ||
        throw(ArgumentError("PREPARATION_CACHE_ARTIFACT_TOO_LARGE: $(label)"))
    write_preparation_checkpoint(path, contract, payload)
    _preparation_artifact_event(context, label, "BUILD_COMMITTED", unit, time() - started)
    return payload
end

"""Allocate a sibling candidate for verifying an interrupted operator publication."""
function operator_publication_candidate(output::AbstractString)
    path, io = mktemp(dirname(abspath(output)); cleanup = false)
    close(io)
    return path
end

"""Retain the original operator unless the reconstructed file is byte-identical.

A mismatching candidate remains on disk as failure evidence. This routine never
replaces or repairs the existing output.
"""
function verify_operator_publication_candidate(candidate::AbstractString, output::AbstractString)
    candidate_state = scientific_file_state(candidate)
    output_state = scientific_file_state(output)
    identical = open(candidate, "r") do candidate_stream
        open(output, "r") do output_stream
            left = Vector{UInt8}(undef, 65536)
            right = similar(left)
            while true
                count_left = readbytes!(candidate_stream, left, length(left))
                count_right = readbytes!(output_stream, right, length(right))
                count_left == count_right || return false
                count_left == 0 && return true
                view(left, 1:count_left) == view(right, 1:count_right) || return false
            end
        end
    end
    identical &&
    isequal(candidate_state, scientific_file_state(candidate)) &&
    isequal(output_state, scientific_file_state(output)) || throw(
        ArgumentError(
            "OPERATOR_PUBLICATION_RECOVERY_MISMATCH: original=$(output), candidate=$(candidate)",
        ),
    )
    rm(candidate)
    return String(output)
end
"""Publish one owned ComplexF64 array for immutable, same-host preparation reads.

This private workspace layout is not a checkpoint format. The descriptor retains
the complete file observation; it is not a scientific equality credential.
"""
function publish_preparation_shared_array(directory::String, values::Array{ComplexF64, N}) where {N}
    all(isfinite, values) || throw(ArgumentError("PREPARATION_SHARED_ARRAY_NONFINITE"))
    mkpath(directory)
    path, stream = mktemp(directory; cleanup = false)
    try
        write(stream, values) == sizeof(values) ||
            throw(ArgumentError("PREPARATION_SHARED_ARRAY_INCOMPLETE"))
        flush(stream)
    finally
        close(stream)
    end
    chmod(path, 0o444)
    descriptor = (;
        path = realpath(path),
        dimensions = size(values),
        byte_count = sizeof(values),
        state = scientific_file_state(path),
    )
    mapped = read_preparation_shared_array(descriptor)
    all(index -> isequal(mapped[index], values[index]), eachindex(values)) ||
        throw(ArgumentError("PREPARATION_SHARED_ARRAY_VALUE_MISMATCH"))
    return descriptor
end

"""Map an owned immutable array without a private heap copy or writable mapping."""
function read_preparation_shared_array(descriptor; finite_partition = nothing)
    path = descriptor.path
    isabspath(path) && isfile(path) && !islink(path) && realpath(path) == path ||
        throw(ArgumentError("PREPARATION_SHARED_ARRAY_PATH_MISMATCH"))
    dimensions = descriptor.dimensions
    !isempty(dimensions) && all(>(0), dimensions) ||
        throw(ArgumentError("PREPARATION_SHARED_ARRAY_LAYOUT_MISMATCH"))
    count = foldl(Base.Checked.checked_mul, dimensions; init = sizeof(ComplexF64))
    count == descriptor.byte_count == filesize(path) ||
        throw(ArgumentError("PREPARATION_SHARED_ARRAY_EXTENT_MISMATCH"))
    validate_scientific_source_state(descriptor.state; declared_path = path)
    values = open(path, "r") do stream
        Mmap.mmap(stream, Array{ComplexF64, length(dimensions)}, dimensions; shared = true)
    end
    # The MPI caller checks disjoint portions collectively. This keeps the
    # complete finite-value gate while avoiding a full-file page fault in
    # every rank's RSS. Standalone callers retain the original full scan.
    selected = if finite_partition === nothing
        values
    else
        finite_partition isa Tuple{Int, Int} &&
        !(finite_partition[1] isa Bool) &&
        !(finite_partition[2] isa Bool) ||
            throw(ArgumentError("PREPARATION_SHARED_ARRAY_PARTITION_INVALID"))
        rank, workers = finite_partition
        0 <= rank < workers ||
            throw(ArgumentError("PREPARATION_SHARED_ARRAY_PARTITION_INVALID"))
        first_index = fld(rank * length(values), workers) + 1
        last_index = fld((rank + 1) * length(values), workers)
        @view values[first_index:last_index]
    end
    all(isfinite, selected) || throw(ArgumentError("PREPARATION_SHARED_ARRAY_NONFINITE"))
    validate_scientific_source_state(descriptor.state; declared_path = path)
    return values
end
