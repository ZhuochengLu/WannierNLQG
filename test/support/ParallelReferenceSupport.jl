module ParallelReferenceSupport
using JSON3
using SHA

const REFERENCE_ENV = "WANNIERNLQG_PARALLEL_REFERENCE_DIR"
const ENVIRONMENT_KEYS = (
    "JULIA_DEPOT_PATH",
    "JULIA_PKG_OFFLINE",
    "JULIA_CPU_TARGET",
    "JULIA_PKG_PRECOMPILE_AUTO",
    "JULIA_NUM_GC_THREADS",
    "OPENBLAS_NUM_THREADS",
    "OMP_NUM_THREADS",
    "MKL_NUM_THREADS",
    "VECLIB_MAXIMUM_THREADS",
    "DYLD_LIBRARY_PATH",
    "LD_LIBRARY_PATH",
)
file_digest(path) = bytes2hex(sha256(read(path)))

# Pkg creates a new sandbox directory for each full shard. Its dependency graph
# must match exactly; the random directory spelling is not a dependency identity.
function qualified_load_path()
    raw = get(ENV, "JULIA_LOAD_PATH", "DEFAULT")
    rows = Any[]
    for entry in split(raw, Sys.iswindows() ? ';' : ':')
        if isabspath(entry)
            project = joinpath(entry, "Project.toml")
            manifest = joinpath(entry, "Manifest.toml")
            preferences = joinpath(entry, "LocalPreferences.toml")
            isfile(project) && (isfile(manifest) || isfile(preferences)) ||
                error("Unqualified load-path graph or preferences overlay")
            push!(
                rows,
                Dict(
                    "project_sha256" => file_digest(project),
                    "manifest_sha256" => isfile(manifest) ? file_digest(manifest) : "ABSENT",
                    "preferences_sha256" =>
                        isfile(preferences) ? file_digest(preferences) : "ABSENT",
                ),
            )
        else
            push!(rows, entry)
        end
    end
    return rows
end

# The manifest covers runtime, test probe, fixtures and package preferences. Bind
# the interpreter and qualified depot environment separately; no portable reuse.
function validate_reference_source_manifest(package)
    manifest = joinpath(package, "SOURCE_MANIFEST.tsv")
    isfile(manifest) || error("Shared parallel reference requires a frozen source manifest")
    lines = eachline(manifest)
    header = split(first(lines), '\t')
    Set(header) == Set(("path", "type", "bytes", "sha256")) && length(header) == 4 ||
        error("Unsupported source manifest header")
    seen = Set{String}()
    for line in Iterators.drop(eachline(manifest), 1)
        cells = split(line, '\t')
        length(cells) == length(header) || error("Invalid source manifest row")
        row = Dict(zip(header, cells))
        relative, kind, bytes, digest = row["path"], row["type"], row["bytes"], row["sha256"]
        kind == "file" || error("Unsupported manifest row")
        !isabspath(relative) &&
        !isempty(relative) &&
        all(part -> !(part in ("", ".", "..")), splitpath(relative)) ||
            error("Invalid source manifest path")
        relative in seen && error("Duplicate source manifest path")
        push!(seen, relative)
        target = joinpath(package, relative)
        isfile(target) &&
        !islink(target) &&
        filesize(target) == parse(Int, bytes) &&
        file_digest(target) == digest || error("Changed frozen source leaf: $(relative)")
    end
    isempty(seen) && error("Empty source manifest")
    return manifest
end

function reference_identity(package, probe)
    manifest = validate_reference_source_manifest(package)
    preferences = joinpath(package, "LocalPreferences.toml")
    return Dict{String, Any}(
        "source_root" => realpath(package),
        "source_manifest_sha256" => file_digest(manifest),
        "probe_sha256" => file_digest(probe),
        "julia_version" => string(VERSION),
        "julia_executable" => realpath(joinpath(Sys.BINDIR, Base.julia_exename())),
        "julia_executable_sha256" => file_digest(joinpath(Sys.BINDIR, Base.julia_exename())),
        "base_julia_command" => string(Base.julia_cmd()),
        "machine" => string(Sys.MACHINE, "/", Sys.KERNEL, "/", Sys.WORD_SIZE),
        "preferences_sha256" => isfile(preferences) ? file_digest(preferences) : "ABSENT",
        "environment" => Dict(key => get(ENV, key, "ABSENT") for key in ENVIRONMENT_KEYS),
        "probe_flags" => "--compiled-modules=no --startup-file=no --threads=1",
        "load_path_graphs" => qualified_load_path(),
    )
end

function shared_directory(package)
    raw = get(ENV, REFERENCE_ENV, "")
    isempty(raw) && return nothing
    isabspath(raw) || error("Parallel reference directory must be absolute")
    directory = normpath(raw)
    relative = relpath(directory, realpath(package))
    first(splitpath(relative)) == ".." || error("Parallel reference must be outside the package")
    islink(directory) && error("Parallel reference directory cannot be a symbolic link")
    return directory
end

function read_reference(directory, expected)
    record = JSON3.read(read(joinpath(directory, "reference.json"), String), Dict{String, Any})
    Set(keys(record)) == Set(("schema", "identity", "numerical_sha256", "log_sha256")) ||
        error("Invalid parallel reference record")
    record["schema"] == "wanniernlqg.parallel-serial-reference/1" ||
        error("Invalid reference schema")
    record["identity"] == expected || error("Stale parallel serial reference")
    numerical = joinpath(directory, "numerical.json")
    log_path = joinpath(directory, "probe.log")
    any(islink, (numerical, log_path, joinpath(directory, "reference.json"))) &&
        error("Reference files cannot be symbolic links")
    file_digest(numerical) == record["numerical_sha256"] || error("Changed numerical reference")
    file_digest(log_path) == record["log_sha256"] || error("Changed serial probe log")
    log = read(log_path, String)
    occursin("PER_TASK_PARALLEL_PROBE_PASS", log) || error("Incomplete serial reference")
    return log, JSON3.read(read(numerical, String))
end

# MPI consumes the already completed single-thread reference. Only the non-MPI
# shard may produce it, in an exclusively created owner-stage directory.
function serial_reference(package, probe, output_root, command; mpi_consumer)
    directory = shared_directory(package)
    if directory === nothing
        started = time()
        log = read(command, String)
        println("[parallel-reference:fresh] elapsed_s=", time() - started)
        return log, JSON3.read(read(joinpath(output_root, "numerical.json"), String))
    end
    expected = reference_identity(package, probe)
    if ispath(directory)
        result = read_reference(directory, expected)
        println(
            "[parallel-reference:reused] numerical_sha256=",
            file_digest(joinpath(directory, "numerical.json")),
        )
        return result
    end
    mpi_consumer && error("MPI shared reference is missing; run its non-MPI producer first")
    mkpath(dirname(directory))
    mkdir(directory) # Exclusive creation; no overwrite or parallel producer fallback.
    started = time()
    log = read(command, String)
    occursin("PER_TASK_PARALLEL_PROBE_PASS", log) || error("Incomplete serial probe")
    numerical = joinpath(output_root, "numerical.json")
    cp(numerical, joinpath(directory, "numerical.json"))
    write(joinpath(directory, "probe.log"), log)
    expected == reference_identity(package, probe) ||
        error("Reference identity changed during production")
    record = Dict(
        "schema" => "wanniernlqg.parallel-serial-reference/1",
        "identity" => expected,
        "numerical_sha256" => file_digest(numerical),
        "log_sha256" => file_digest(joinpath(directory, "probe.log")),
    )
    write(joinpath(directory, "reference.json"), JSON3.write(record))
    println("[parallel-reference:produced] elapsed_s=", time() - started)
    return read_reference(directory, expected)
end
end
