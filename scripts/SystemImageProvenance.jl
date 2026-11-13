"""Cold provenance checks for an explicitly selected optional system image."""
module SystemImageProvenance
using TOML, SHA

# Hash only files consumed by the explicit image build/verification operation.
file_sha256(path) = bytes2hex(sha256(read(path)))

"""Record the declared native library files from an explicit preference document."""
function native_preference_files(path)
    preferences = TOML.parsefile(path)
    files = Dict{String, String}()
    for (table, key) in (("MPIPreferences", "libmpi"), ("HDF5", "libhdf5"), ("HDF5", "libhdf5_hl"))
        value = get(get(preferences, table, Dict()), key, nothing)
        value isa String && isabspath(value) && isfile(value) || error(
            "Missing or invalid $table.$key in $path: expected an absolute path to an existing library file. Use matching MPI/HDF5 libraries and rebuild with these preferences; see docs/PRECOMPILATION.md.",
        )
        files[realpath(value)] = file_sha256(value)
    end
    return files
end

"""Verify source payload bytes named by the release inventory, without loading the package."""
function verify_source_payload(source)
    lines = readlines(joinpath(source, "SOURCE_MANIFEST.tsv"))
    first(lines) == "type\tbytes\tsha256\tpath" || error("Unsupported source inventory.")
    for line in lines[2:end]
        kind, bytes, digest, name = split(line, '\t'; limit = 4)
        kind == "file" && !isabspath(name) && !(".." in splitpath(name)) ||
            error("Invalid source inventory entry.")
        path = joinpath(source, name)
        isfile(path) && filesize(path) == parse(Int, bytes) && file_sha256(path) == digest ||
            error("Source payload changed: $name. Rebuild the system image.")
    end
    return nothing
end

"""Reject mismatched source, runtime, host target, preferences, libraries or image bytes before launch.

This explicit cold check reads the image and declared source files. Its cost belongs
in user end-to-end measurements; it does not qualify ABI behavior or first-call speed.
"""
function verify_system_image(source, directory, preferences)
    source, directory, preferences = realpath(source), realpath(directory), realpath(preferences)
    record = TOML.parsefile(joinpath(directory, "image.toml"))
    record["schema"] == "wanniernlqg.local-sysimage/1" || error("Unsupported image record.")
    realpath(record["source"]) == source ||
        error("Image is bound to a different source path; rebuild it.")
    record["julia_version"] == string(VERSION) &&
    record["julia_binary_sha256"] == file_sha256(first(Base.julia_cmd().exec)) ||
        error("Julia runtime changed; rebuild the image.")
    record["cpu_target"] == "native" &&
    record["cpu_name"] == Sys.CPU_NAME &&
    record["architecture"] == string(Sys.ARCH) &&
    record["kernel"] == string(Sys.KERNEL) ||
        error("Native CPU/platform image binding changed; rebuild it.")
    file_sha256(joinpath(source, "SOURCE_MANIFEST.tsv")) == record["source_manifest_sha256"] ||
        error("Source inventory changed; rebuild the image.")
    verify_source_payload(source)
    file_sha256(preferences) == record["preferences_sha256"] ||
        error("Preferences changed; rebuild the image.")
    native_preference_files(preferences) == record["native_preference_files"] ||
        error("Declared native libraries changed; rebuild the image.")
    image = joinpath(directory, basename(record["image"]))
    isfile(image) &&
    filesize(image) == record["image_bytes"] &&
    file_sha256(image) == record["image_sha256"] || error("Image file changed or is incomplete.")
    build = joinpath(directory, "environment")
    for name in ("Project.toml", "Manifest.toml", "LocalPreferences.toml")
        file_sha256(joinpath(build, name)) == record["build_environment_sha256"][name] ||
            error("Image environment changed: $name.")
    end
    return (; image, build)
end
end
