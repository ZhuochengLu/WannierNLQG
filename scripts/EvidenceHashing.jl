module EvidenceHashing

using SHA

include(joinpath(@__DIR__, "ValidationPolicy.jl"))
using .ValidationPolicy

export EVIDENCE_HASH_SCHEMA_VERSION,
    evidence_change_set,
    evidence_hash_classes,
    evidence_reuse_decision,
    file_sha256,
    normalized_hash_classes,
    scoped_tree_sha256

const EVIDENCE_HASH_SCHEMA_VERSION = "2.1"
const HASH_CLASS_NAMES = ("runtime_source", "test_contract", "campaign_tools")
const HASH_ALGORITHM = "SHA256(relative_path + NUL + file_bytes, sorted recursively)"

function _generated_cache_file(root::AbstractString, path::AbstractString)
    relative = replace(relpath(path, root), '\\' => '/')
    components = split(relative, '/')
    return (
               !isempty(components) &&
               first(components) == ".git" &&
               !islink(joinpath(root, ".git"))
           ) ||
           "__pycache__" in components ||
           endswith(relative, ".pyc") ||
           endswith(relative, ".pyo")
end

function _scope_files(root::AbstractString, entries)
    files = String[]
    for relative in entries
        path = joinpath(root, relative)
        if isfile(path)
            push!(files, path)
        elseif isdir(path)
            for (directory, directories, names) in walkdir(path)
                if normpath(directory) == normpath(root)
                    filter!(
                        name -> name != ".git" || islink(joinpath(directory, name)),
                        directories,
                    )
                end
                append!(
                    files,
                    [
                        joinpath(directory, name) for
                        name in sort(names) if isfile(joinpath(directory, name))
                    ],
                )
            end
        end
    end
    filter!(path -> !_generated_cache_file(root, path), files)
    return sort!(unique!(files))
end

function scoped_tree_sha256(root::AbstractString, entries)
    files = _scope_files(root, entries)
    buffer = IOBuffer()
    for file in files
        write(buffer, codeunits(relpath(file, root)))
        write(buffer, UInt8(0))
        open(file, "r") do io
            while !eof(io)
                write(buffer, read(io, 1024 * 1024))
            end
        end
    end
    return (sha256 = bytes2hex(SHA.sha256(take!(buffer))), file_count = length(files))
end

function file_sha256(path::AbstractString)
    return open(path, "r") do io
        bytes2hex(SHA.sha256(io))
    end
end

function _class_inventory(root::AbstractString, entries, class_name::AbstractString)
    return [
        Dict(
            "path" => replace(relpath(path, root), '\\' => '/'),
            "sha256" => file_sha256(path),
            "size_bytes" => filesize(path),
            "classes" => [class_name],
        ) for path in _scope_files(root, entries)
    ]
end

function _merged_inventory(class_inventories)
    merged = Dict{String, Dict{String, Any}}()
    for inventory in values(class_inventories), record in inventory
        path = record["path"]
        if haskey(merged, path)
            merged[path]["sha256"] == record["sha256"] ||
                error("file digest differs between evidence classes: $(path)")
            push!(merged[path]["classes"], only(record["classes"]))
            sort!(unique!(merged[path]["classes"]))
        else
            merged[path] = deepcopy(record)
        end
    end
    return [merged[path] for path in sort!(collect(keys(merged)))]
end

function _complete_inventory(root::AbstractString, classified_inventory)
    classified = Dict(record["path"] => record for record in classified_inventory)
    all_files = _scope_files(root, (".",))
    for path in all_files
        relative = replace(relpath(path, root), '\\' => '/')
        haskey(classified, relative) && continue
        classified[relative] = Dict(
            "path" => relative,
            "sha256" => file_sha256(path),
            "size_bytes" => filesize(path),
            "classes" => ["unclassified"],
        )
    end
    return [classified[path] for path in sort!(collect(keys(classified)))]
end

function _evidence_summary_sha256(hashes)
    buffer = IOBuffer()
    for name in HASH_CLASS_NAMES
        write(buffer, codeunits(name))
        write(buffer, UInt8(0))
        write(buffer, codeunits(hashes[name]))
        write(buffer, UInt8(0))
    end
    return bytes2hex(SHA.sha256(take!(buffer)))
end

function evidence_hash_classes(root::AbstractString)
    runtime_scope = ("src", "ext", "Project.toml", "Manifest.toml")
    test_scope = Tuple(test_contract_entries())
    campaign_scope = ("scripts",)
    scopes = Dict(
        "runtime_source" => runtime_scope,
        "test_contract" => test_scope,
        "campaign_tools" => campaign_scope,
    )
    class_inventories =
        Dict(name => _class_inventory(root, entries, name) for (name, entries) in scopes)
    class_digests = Dict(name => scoped_tree_sha256(root, entries) for (name, entries) in scopes)
    hashes = Dict(name => class_digests[name].sha256 for name in HASH_CLASS_NAMES)
    classes = Dict(
        name => Dict(
            "sha256" => class_digests[name].sha256,
            "file_count" => class_digests[name].file_count,
            "scope" => collect(scopes[name]),
        ) for name in HASH_CLASS_NAMES
    )
    inventory = _complete_inventory(root, _merged_inventory(class_inventories))
    return Dict(
        "schema_version" => EVIDENCE_HASH_SCHEMA_VERSION,
        "hash_algorithm" => HASH_ALGORITHM,
        "evidence_summary_sha256" => _evidence_summary_sha256(hashes),
        "classes" => classes,
        "file_inventory" => inventory,
        "unclassified_files" =>
            [record["path"] for record in inventory if "unclassified" in record["classes"]],
        "runtime_source_sha256" => hashes["runtime_source"],
        "runtime_source_file_count" => class_digests["runtime_source"].file_count,
        "runtime_source_scope" => collect(runtime_scope),
        "test_contract_sha256" => hashes["test_contract"],
        "test_contract_file_count" => class_digests["test_contract"].file_count,
        "test_contract_scope" => collect(test_scope),
        "campaign_tools_sha256" => hashes["campaign_tools"],
        "campaign_tools_file_count" => class_digests["campaign_tools"].file_count,
        "campaign_tools_scope" => collect(campaign_scope),
    )
end

function _get(payload, key::AbstractString, default = nothing)
    haskey(payload, key) && return payload[key]
    symbol = Symbol(key)
    haskey(payload, symbol) && return payload[symbol]
    return default
end

function normalized_hash_classes(payload)
    hashes_payload = _get(payload, "hashes")
    hashes_payload !== nothing && return normalized_hash_classes(hashes_payload)
    normalized = Dict{String, Any}(
        "schema_version" => string(_get(payload, "schema_version", "legacy")),
        "file_inventory" => _get(payload, "file_inventory", Any[]),
        "unclassified_files" => _get(payload, "unclassified_files", Any[]),
    )
    classes = _get(payload, "classes")
    for name in HASH_CLASS_NAMES
        flat = _get(payload, "$(name)_sha256")
        nested = classes === nothing ? _get(payload, name) : _get(classes, name)
        digest = flat === nothing && nested !== nothing ? _get(nested, "sha256") : flat
        normalized["$(name)_sha256"] = digest === nothing ? "" : String(digest)
    end
    summary = _get(payload, "evidence_summary_sha256")
    if summary === nothing &&
       all(!isempty(normalized["$(name)_sha256"]) for name in HASH_CLASS_NAMES)
        summary = _evidence_summary_sha256(
            Dict(name => normalized["$(name)_sha256"] for name in HASH_CLASS_NAMES),
        )
    end
    normalized["evidence_summary_sha256"] = summary === nothing ? "" : String(summary)
    return normalized
end

function _inventory_by_path(payload)
    normalized = normalized_hash_classes(payload)
    inventory = normalized["file_inventory"]
    isempty(inventory) && return nothing
    return Dict(String(_get(record, "path")) => record for record in inventory)
end

function evidence_change_set(previous, current)
    before = _inventory_by_path(previous)
    after = _inventory_by_path(current)
    if before === nothing || after === nothing
        return Dict(
            "closed" => false,
            "reason" => "one or both evidence snapshots lack a per-file inventory",
            "files" => Any[],
        )
    end
    changes = Dict{String, Any}[]
    for path in sort!(collect(union(keys(before), keys(after))))
        old = get(before, path, nothing)
        new = get(after, path, nothing)
        status = if old === nothing
            "ADDED"
        elseif new === nothing
            "DELETED"
        elseif _get(old, "sha256") != _get(new, "sha256")
            "MODIFIED"
        else
            continue
        end
        classes = String[]
        old !== nothing && append!(classes, String.(_get(old, "classes", String[])))
        new !== nothing && append!(classes, String.(_get(new, "classes", String[])))
        push!(
            changes,
            Dict(
                "path" => path,
                "status" => status,
                "classes" => sort!(unique!(classes)),
                "previous_sha256" => old === nothing ? "" : String(_get(old, "sha256")),
                "current_sha256" => new === nothing ? "" : String(_get(new, "sha256")),
            ),
        )
    end
    return Dict("closed" => true, "reason" => "exact per-file comparison", "files" => changes)
end

function evidence_reuse_decision(
    previous,
    current;
    prior_status::AbstractString = "PASS",
    manifest_sealed::Bool = true,
)
    old = normalized_hash_classes(previous)
    new = normalized_hash_classes(current)
    changes = evidence_change_set(previous, current)
    reasons = String[]
    prior_status == "PASS" || push!(reasons, "prior engineering status is not PASS")
    manifest_sealed || push!(reasons, "prior engineering manifest is not sealed")
    runtime_unchanged = old["runtime_source_sha256"] == new["runtime_source_sha256"]
    tests_unchanged = old["test_contract_sha256"] == new["test_contract_sha256"]
    campaign_unchanged = old["campaign_tools_sha256"] == new["campaign_tools_sha256"]
    runtime_unchanged || push!(reasons, "runtime_source_sha256 changed")
    tests_unchanged || push!(reasons, "test_contract_sha256 changed")
    isempty(new["unclassified_files"]) ||
        push!(reasons, "current evidence snapshot contains unclassified files")

    if isempty(reasons) && changes["closed"] && campaign_unchanged && !isempty(changes["files"])
        push!(reasons, "file inventory changed without a classified hash change")
    elseif isempty(reasons) && !campaign_unchanged
        if !changes["closed"]
            push!(reasons, changes["reason"])
        else
            for record in changes["files"]
                classes = Set(record["classes"])
                if "runtime_source" in classes ||
                   "test_contract" in classes ||
                   !("campaign_tools" in classes)
                    push!(reasons, "changed file is not campaign-only: $(record["path"])")
                end
            end
        end
    end
    mode = isempty(reasons) ? "REUSE_WITH_FOCUSED_CHECKS" : "RUN_FULL_ONCE"
    return Dict(
        "mode" => mode,
        "reuse_eligible" => isempty(reasons),
        "reasons" => unique!(reasons),
        "runtime_source_unchanged" => runtime_unchanged,
        "test_contract_unchanged" => tests_unchanged,
        "campaign_tools_unchanged" => campaign_unchanged,
        "changes" => changes,
    )
end

end
