"""Verify content again after a metadata-only identity change.

The identity is `(device, inode, size, mtime, ctime)` and the digest is the
previously verified hexadecimal SHA-256. Return an updated identity without
mutating the caller's credential. A changed ctime can reflect filesystem metadata
updates; accept it only after comparing a fresh content digest. Other identity
changes or a content mismatch raise an ArgumentError with `change_error`.

This IO integration contract is shared by preparation and operator
attestations; unchanged identities require no content read.
"""
function verified_file_digest_identity(
    path,
    identity,
    digest;
    file_hasher = p -> open(io -> bytes2hex(SHA.sha256(io)), p, "r"),
    change_error = "VERIFIED_INPUT_CHANGED",
)
    current = file_digest_identity(path)
    current == identity && return current
    current[1:4] == identity[1:4] || throw(ArgumentError("$(change_error): $(path)"))
    observed = file_hasher(path)
    after = file_digest_identity(path)
    after[1:4] == current[1:4] && observed == digest ||
        throw(ArgumentError("$(change_error): $(path)"))
    # Keep the identity captured immediately before the verified content read.
    # Some filesystems publish a delayed ctime-only refresh after metadata
    # changes.  Returning `after` would then force an unnecessary third hash
    # on the next lookup despite the checked content and stable device/inode,
    # size, and mtime.  A later identity change still re-enters this strict
    # verification path.
    return current
end

"""Compute a streaming SHA-256, reusing a verified execution-scoped credential."""
function sha256_file(filename::AbstractString)
    isfile(filename) || throw(ArgumentError("input file does not exist: $(filename)"))
    registry = get(task_local_storage(), :wannier_verified_file_digests, nothing)
    if registry !== nothing
        path = realpath(filename)
        if haskey(registry, path)
            identity, digest = registry[path]
            current = verified_file_digest_identity(path, identity, digest)
            if current != identity
                refreshed = copy(registry)
                refreshed[path] = (current, digest)
                task_local_storage(:wannier_verified_file_digests, refreshed)
            end
            return digest
        end
    end
    return open(filename, "r") do io
        bytes2hex(SHA.sha256(io))
    end
end

"""Identify changes to an already content-verified input within one execution scope."""
function file_digest_identity(path::AbstractString)
    information = stat(path)
    return (
        information.device,
        information.inode,
        information.size,
        information.mtime,
        information.ctime,
    )
end

"""Verify declared inputs once and reuse their digests only for the callback lifetime.

The registry is immutable once shared and never serialized. Nested scopes and
metadata refreshes use private copies. A ctime-only change requires a fresh
content match before replacing the task-local credential. Undeclared files retain
streaming hashes.
"""
function with_verified_file_digests(f::F, paths; file_hasher = sha256_file) where {F}
    parent = get(task_local_storage(), :wannier_verified_file_digests, nothing)
    registry = parent === nothing ? Dict{String, Tuple{Tuple, String}}() : copy(parent)
    for filename in paths
        path = realpath(filename)
        if haskey(registry, path)
            identity, digest = registry[path]
            registry[path] = (verified_file_digest_identity(path, identity, digest), digest)
            continue
        end
        before = file_digest_identity(path)
        digest = file_hasher(path)
        after = verified_file_digest_identity(
            path,
            before,
            digest;
            change_error = "INPUT_CHANGED_DURING_DIGEST",
        )
        registry[path] = (after, digest)
    end
    return task_local_storage(f, :wannier_verified_file_digests, registry)
end
