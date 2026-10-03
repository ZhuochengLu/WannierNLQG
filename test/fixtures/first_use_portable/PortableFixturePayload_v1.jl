module PortableFixturePayload
using JSON3, SHA, Serialization
include(joinpath(@__DIR__, "PortableFixturePathIO_v1.jl"))
using .PortableFixturePathIO
export verify_payload, load_arguments, argument_mapping
function safe_relative(root, relative)
    text = String(relative)
    isabspath(text) && error("FIXTURE_ABSOLUTE_PATH_FORBIDDEN")
    occursin('\0', text) && error("FIXTURE_PATH_INVALID")
    parts = split(replace(text, '\\' => '/'), '/'; keepempty = true)
    any(x -> x in ("", ".", ".."), parts) && error("FIXTURE_PATH_ESCAPE")
    base = abspath(root)
    islink(base) && error("FIXTURE_SYMLINK_FORBIDDEN")
    p = base
    for part in parts
        p = joinpath(p, part)
        islink(p) && error("FIXTURE_SYMLINK_FORBIDDEN")
    end
    return p
end
function verify_payload(root)
    isdir(root) || error("FIXTURE_ROOT_MISSING")
    manifest_file = safe_relative(root, "manifest.json")
    manifest = JSON3.read(read(manifest_file, String))
    manifest.schema == "wanniernlqg.first-use-fixture-payload" && manifest.schema_version == "1" ||
        error("FIXTURE_SCHEMA_MISMATCH")
    names = String[String(x.file) for x in manifest.files]
    length(unique(names)) == length(names) || error("FIXTURE_DUPLICATE_FILE")
    records = Dict(String(x.file) => x for x in manifest.files)
    for item in manifest.files
        file = safe_relative(root, String(item.file))
        isfile(file) || error("FIXTURE_FILE_MISSING")
        filesize(file) == item.bytes || error("FIXTURE_SIZE_MISMATCH")
        bytes2hex(open(sha256, file)) == item.sha256 || error("FIXTURE_SHA_MISMATCH")
    end
    ids = String[String(x.id) for x in manifest.arguments]
    length(unique(ids)) == length(ids) || error("FIXTURE_DUPLICATE_ARGUMENT")
    for item in manifest.arguments
        haskey(records, String(item.file)) || error("FIXTURE_ARGUMENT_NOT_DECLARED")
        records[String(item.file)].sha256 == item.sha256 || error("FIXTURE_ARGUMENTS_SHA_MISMATCH")
    end
    for item in values(manifest.paths)
        item.role in ("input", "output") || error("FIXTURE_ROLE_INVALID")
        safe_relative(root, String(item.relative))
    end
    if hasproperty(manifest, :expert_entries)
        entries = String[String(x.id) for x in manifest.expert_entries]
        length(unique(entries)) == length(entries) || error("FIXTURE_DUPLICATE_ENTRY")
        for item in manifest.expert_entries
            haskey(records, String(item.fixture)) || error("FIXTURE_ENTRY_NOT_DECLARED")
        end
    end
    return manifest
end
function argument_mapping(manifest, root, output_root)
    mapping = Dict{String, String}()
    for (token, value) in pairs(manifest.paths)
        value.role in ("input", "output") || error("FIXTURE_ROLE_INVALID")
        target = safe_relative(value.role == "input" ? root : output_root, String(value.relative))
        if value.role == "input"
            ispath(target) || error("FIXTURE_INPUT_MISSING")
        else
            mkpath(dirname(target))
        end
        mapping[String(token)] = target
    end
    return mapping
end
function load_arguments(root, id, output_root; verify = true)
    manifest =
        verify ? verify_payload(root) :
        JSON3.read(read(safe_relative(root, "manifest.json"), String))
    selected = filter(x -> String(x.id) == id, manifest.arguments)
    length(selected) == 1 || error("FIXTURE_ARGUMENT_ID_MISSING")
    record = only(selected)
    file = safe_relative(root, String(record.file))
    bytes2hex(open(sha256, file)) == record.sha256 || error("FIXTURE_ARGUMENTS_SHA_MISMATCH")
    mapping = argument_mapping(manifest, root, output_root)
    return open(file, "r") do stream
        deserialize(FixturePathIO(stream, mapping))
    end
end
end
