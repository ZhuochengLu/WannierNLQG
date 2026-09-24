"""Private bounded vector whose elements are atomically stored outside the Julia heap.

The format is a process-version-bound workspace, never a public scientific artifact.
Each element is serialized without changing any numerical arithmetic. Callers must
not mutate elements after publication. Reads are serialized and retain one element.
"""
mutable struct PreparationDiskVector{T} <: AbstractVector{T}
    directory::String
    count::Int
    digests::Vector{String}
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

"""Read one verified preparation element under its exclusive cache lock."""
function Base.getindex(values::PreparationDiskVector{T}, index::Int) where {T}
    checkbounds(values, index)
    return lock(values.mutex) do
        values.cached_index == index && return something(values.cached_value)
        isempty(values.digests[index]) && throw(UndefRefError())
        path = joinpath(values.directory, string(index) * ".bin")
        digest = open(SHA.sha256, path)
        bytes2hex(digest) == values.digests[index] ||
            throw(ArgumentError("PREPARATION_STORAGE_DIGEST_MISMATCH: index=$(index)"))
        value = open(Serialization.deserialize, path)::T
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
            Serialization.serialize(stream, value)
            close(stream)
            digest = bytes2hex(open(SHA.sha256, temporary))
            mv(temporary, path; force = true)
            values.digests[index] = digest
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
        push!(values.digests, "")
        values[values.count] = value
    end
    return values
end

"""Allocate an ordinary vector unless the task has opted into disk-backed preparation."""
function preparation_vector(::Type{T}, label::String, count::Int = 0) where {T}
    context = get(task_local_storage(), :wannier_preparation_storage, nothing)
    context === nothing && return Vector{T}(undef, count)
    directory = mktempdir(context.directory; prefix = label * "-", cleanup = false)
    values =
        PreparationDiskVector{T}(directory, count, fill("", count), 0, nothing, ReentrantLock())
    push!(context.vectors, values)
    return values
end

"""Run one task with explicitly scoped private storage; nested calls restore their context."""
function with_preparation_storage(f::Function, directory::String)
    mkpath(directory)
    context = (directory = directory, vectors = Any[])
    return task_local_storage(f, :wannier_preparation_storage, context)
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

"""Atomically seal a private checkpoint and its checksum, without materializing a byte copy."""
function write_preparation_checkpoint(path::String, contract::String, payload)
    mkpath(dirname(path))
    temporary, stream = mktemp(dirname(path))
    try
        Serialization.serialize(stream, (contract = contract, payload = payload))
        close(stream)
        digest = bytes2hex(open(SHA.sha256, temporary))
        mv(temporary, path; force = true)
        ready = path * ".sha256"
        # A fixed sidecar temporary name races when independent preparation
        # tasks seal different artifacts under the same checkpoint directory.
        # Use a unique sibling so each write has an atomic publication path.
        checksum_temporary, checksum_stream = mktemp(dirname(path))
        try
            write(checksum_stream, digest)
            close(checksum_stream)
            mv(checksum_temporary, ready; force = true)
        finally
            isopen(checksum_stream) && close(checksum_stream)
            isfile(checksum_temporary) && rm(checksum_temporary)
        end
    finally
        isopen(stream) && close(stream)
        isfile(temporary) && rm(temporary)
    end
    return path
end

"""Return only a checksum-verified checkpoint with exactly the requested contract."""
function read_preparation_checkpoint(path::String, contract::String)
    verified = _read_preparation_checkpoint_verified(path, contract)
    return verified === nothing ? nothing : verified.payload
end

"""Retain the checksum already computed by the checkpoint reader for cache attestation."""
function _read_preparation_checkpoint_verified(path::String, contract::String)
    isfile(path) && isfile(path * ".sha256") || return nothing
    digest = bytes2hex(open(SHA.sha256, path))
    digest == read(path * ".sha256", String) || return nothing
    record = open(Serialization.deserialize, path)
    record.contract == contract || return nothing
    return (; payload = record.payload, digest)
end

"""Validate and register every disk-vector dependency of a private stage checkpoint.

Only scientific containers are traversed. Numeric arrays are leaves; no coefficient
array is reconstructed merely to validate a dependency checksum.
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
            length(value.digests) == value.count || return false
            if verify
                for index in eachindex(value.digests)
                    path = joinpath(value.directory, string(index) * ".bin")
                    isfile(path) || return false
                    bytes2hex(open(SHA.sha256, path)) == value.digests[index] || return false
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
)
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
                item_contract =
                    contract *
                    ":" *
                    (fingerprint_index === nothing ? fingerprint(item) : fingerprint_index(current))
                saved =
                    path === nothing || !execution.resume ? nothing :
                    read_preparation_checkpoint(path, item_contract)
                if saved !== nothing
                    task = let value = saved
                        Threads.@spawn identity(value)
                    end
                    push!(tasks, (current, item_contract, true, task))
                    continue
                end
                fingerprint_index === nothing || (item = load(current))
                estimate = 6 * Base.summarysize(item)
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

"""Identify mutations to a checkpoint already content-verified in this process."""
function _preparation_artifact_identity(path)
    isfile(path) && isfile(path * ".sha256") || return nothing
    return map((path, path * ".sha256")) do file
        value = stat(file)
        (value.device, value.inode, value.size, value.mtime, value.ctime)
    end
end

"""Refresh metadata-only changes after verifying both the payload and checksum file."""
function _preparation_verified_artifact_identity(path, identity, digest)
    current = _preparation_artifact_identity(path)
    current == identity && return current
    current === nothing && return nothing
    identity === nothing && return nothing
    all(i -> current[i][1:4] == identity[i][1:4], eachindex(current)) || return nothing
    bytes2hex(open(SHA.sha256, path)) == digest || return nothing
    read(path * ".sha256", String) == digest || return nothing
    after = _preparation_artifact_identity(path)
    after === nothing && return nothing
    all(i -> after[i][1:4] == current[i][1:4], eachindex(current)) || return nothing
    return after
end

"""Evict one private compact artifact and update its resident byte accounting."""
function _preparation_forget_artifact!(context, key)
    entry = pop!(context.resident, key)
    context.resident_bytes[] -= entry.bytes
    deleteat!(context.recency, something(findfirst(==(key), context.recency)))
    return nothing
end

"""Retain an isolated copy only after durable content verification, within the byte budget."""
function _preparation_remember_artifact!(context, key, payload, identity, digest)
    bytes = Base.summarysize(payload)
    bytes <= context.max_resident_bytes || return nothing
    while context.resident_bytes[] + bytes > context.max_resident_bytes
        _preparation_forget_artifact!(context, first(context.recency))
    end
    context.resident[key] = (; payload = deepcopy(payload), identity, digest, bytes)
    push!(context.recency, key)
    context.resident_bytes[] += bytes
    return nothing
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
    contract = context.contract * ":" * string(VERSION) * ":" * label * ":" * identity()
    key = bytes2hex(SHA.sha256(contract))
    path = joinpath(context.directory, label, key * ".bin")
    started = time()
    identity_before = _preparation_artifact_identity(path)
    if haskey(context.resident, key)
        entry = context.resident[key]
        refreshed = _preparation_verified_artifact_identity(path, entry.identity, entry.digest)
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
            _preparation_verified_artifact_identity(path, identity_before, verified.digest)
        identity_after !== nothing ||
            throw(ArgumentError("PREPARATION_CACHE_CHANGED_DURING_READ: $(label)"))
        _preparation_remember_artifact!(context, key, payload, identity_after, verified.digest)
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
    digest(path) =
        open(path, "r") do io
            bytes2hex(SHA.sha256(io))
        end
    digest(candidate) == digest(output) || throw(
        ArgumentError(
            "OPERATOR_PUBLICATION_RECOVERY_MISMATCH: original=$(output), candidate=$(candidate)",
        ),
    )
    rm(candidate)
    return String(output)
end
