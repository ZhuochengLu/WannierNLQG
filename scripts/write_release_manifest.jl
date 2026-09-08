#!/usr/bin/env julia

using SHA

const ROOT = normpath(joinpath(@__DIR__, ".."))
const GENERATED = Set(["SOURCE_MANIFEST.tsv", "SHA256SUMS"])

function release_files()
    paths = String[]
    for (directory, directories, files) in walkdir(ROOT)
        filter!(
            name ->
                !(directory == ROOT && name == ".git" && !islink(joinpath(directory, name))) &&
                name != "__pycache__",
            directories,
        )
        sort!(directories)
        for name in sort!(files)
            directory == ROOT && name == ".git" && !islink(joinpath(directory, name)) && continue
            (endswith(name, ".pyc") || endswith(name, ".pyo")) && continue
            path = joinpath(directory, name)
            relative = replace(relpath(path, ROOT), '\\' => '/')
            relative in GENERATED && continue
            islink(path) && error("release manifest does not accept symbolic links: $(relative)")
            isfile(path) && push!(paths, relative)
        end
    end
    return sort!(paths)
end

paths = release_files()
function source_manifest_text(paths)
    io = IOBuffer()
    println(io, "type\tbytes\tsha256\tpath")
    for relative in paths
        path = joinpath(ROOT, relative)
        println(io, "file\t$(filesize(path))\t$(bytes2hex(sha256(read(path))))\t$(relative)")
    end
    return String(take!(io))
end

function sha256sums_text(paths)
    io = IOBuffer()
    for relative in paths
        digest = bytes2hex(sha256(read(joinpath(ROOT, relative))))
        println(io, "$(digest)  $(relative)")
    end
    return String(take!(io))
end

source_manifest = source_manifest_text(paths)
sha256sums = sha256sums_text(paths)
if ARGS == ["--check"]
    read(joinpath(ROOT, "SOURCE_MANIFEST.tsv"), String) == source_manifest ||
        error("SOURCE_MANIFEST.tsv is stale or inconsistent")
    read(joinpath(ROOT, "SHA256SUMS"), String) == sha256sums ||
        error("SHA256SUMS is stale or inconsistent")
    println("release manifest verified: $(length(paths)) files")
elseif isempty(ARGS)
    write(joinpath(ROOT, "SOURCE_MANIFEST.tsv"), source_manifest)
    write(joinpath(ROOT, "SHA256SUMS"), sha256sums)
    println("release manifest written: $(length(paths)) files")
else
    error("usage: julia --project=. scripts/write_release_manifest.jl [--check]")
end
