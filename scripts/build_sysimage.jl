# Optional explicit offline compiler entry; never resolve versions or alter the source project.
if ARGS == ["--help"] || ARGS == ["-h"]
    println(
        """
Optional local system-image builder (ordinary use does not require an image).
Usage: julia --project=COMPILER_ENV scripts/build_sysimage.jl SOURCE NEW_OUTPUT_DIRECTORY LOCAL_PREFERENCES
Build profile: Julia 1.13.0; PackageCompiler 2.4.4 in a separate tool environment;
explicit matching system MPI/HDF5 libraries. Prepare ordinary dependencies first.
No packages are installed automatically; failed partial output is retained.
See docs/PRECOMPILATION.md for preparation, examples, and checked image launching.
""",
    )
    exit(0)
end
using TOML, SHA, Libdl, Pkg
length(ARGS) == 3 || error(
    "Usage: build_sysimage.jl SOURCE NEW_OUTPUT_DIRECTORY LOCAL_PREFERENCES. Use --help for preparation instructions.",
)
VERSION == v"1.13.0" || error(
    "This image build profile requires Julia 1.13.0; selected $(VERSION). Use ordinary precompilation on other supported versions (docs/PRECOMPILATION.md).",
)
Base.find_package("PackageCompiler") !== nothing || error(
    "PackageCompiler is missing from the selected tool environment. Prepare a separate PackageCompiler 2.4.4 environment and rerun with --project=COMPILER_ENV; see docs/PRECOMPILATION.md. Ordinary use does not require it.",
)
try
    @eval using PackageCompiler
catch
    @error "Cannot load PackageCompiler from the selected tool environment. Check its Julia version and dependencies; no packages were installed or changed by this script. See docs/PRECOMPILATION.md."
    rethrow()
end
Base.pkgversion(PackageCompiler) == v"2.4.4" || error(
    "This image build profile requires PackageCompiler 2.4.4; selected $(Base.pkgversion(PackageCompiler)). Select the separate matching tool environment; ordinary precompilation is still available.",
)
include("SystemImageProvenance.jl")
using .SystemImageProvenance: file_sha256, native_preference_files, verify_source_payload
isdir(ARGS[1]) ||
    error("Source directory does not exist: $(ARGS[1]). Select the unpacked package root.")
isfile(ARGS[3]) || error(
    "Preferences file does not exist: $(ARGS[3]). Prepare matching MPI/HDF5 preferences as described in docs/PRECOMPILATION.md.",
)
source, output, preferences = realpath(ARGS[1]), abspath(ARGS[2]), realpath(ARGS[3])
ispath(output) && error(
    "Output directory already exists: $output. Keep previous build evidence and choose a new directory.",
)
project = TOML.parsefile(joinpath(source, "Project.toml"))
@assert project["name"] == "WannierNLQG" && project["version"] == "1.2.0"
manifest = TOML.parsefile(joinpath(source, "Manifest.toml"))
verify_source_payload(source)
native_files = native_preference_files(preferences)
source_identity = file_sha256(joinpath(source, "SOURCE_MANIFEST.tsv"))
# The upstream compiler calls Pkg.instantiate; keep parent and children offline.
Pkg.offline(true)
mkdir(output)
build = joinpath(output, "environment")
mkdir(build)
# Preserve the locked package graph; make its existing dependencies visible to
# the writer without modifying or resolving either source or tool environment.
dependencies = copy(project["deps"])
dependencies["WannierNLQG"] = project["uuid"]
open(io -> TOML.print(io, Dict("deps" => dependencies)), joinpath(build, "Project.toml"), "w")
manifest["deps"]["WannierNLQG"][1]["path"] = source
open(io -> TOML.print(io, manifest), joinpath(build, "Manifest.toml"), "w")
cp(preferences, joinpath(build, "LocalPreferences.toml"))
image = joinpath(output, "WannierNLQG." * Libdl.dlext)
writer = joinpath(@__DIR__, "SystemImageWriterCheck.jl")
workload = joinpath(@__DIR__, "SystemImageWorkload.jl")
started = time_ns()
withenv(
    "WN_IMAGE_SOURCE" => source,
    "WN_IMAGE_SOURCE_MANIFEST" => source_identity,
    "WN_IMAGE_ARTIFACT_DIRECTORY" => output,
    "JULIA_PROJECT" => build,
    "JULIA_PKG_OFFLINE" => "true",
    "JULIA_PKG_PRECOMPILE_AUTO" => "0",
) do
    PackageCompiler.create_sysimage(
        Symbol.(["WannierNLQG"; sort!(collect(keys(project["deps"])))]);
        project = build,
        include_transitive_dependencies = false,
        sysimage_path = image,
        precompile_execution_file = workload,
        script = writer,
        incremental = true,
        cpu_target = "native",
        sysimage_build_args = `--threads=1 --gcthreads=1,0`,
    )
end
@assert isfile(image) && filesize(image) > 0
@assert native_preference_files(preferences) == native_files
@assert file_sha256(joinpath(source, "SOURCE_MANIFEST.tsv")) == source_identity
record = Dict(
    "schema" => "wanniernlqg.local-sysimage/1",
    "source" => source,
    "source_manifest_sha256" => source_identity,
    "julia_version" => string(VERSION),
    "tool_version" => string(Base.pkgversion(PackageCompiler)),
    "cpu_target" => "native",
    "explicit_roots" => ["WannierNLQG"; sort!(collect(keys(project["deps"])))],
    "include_transitive_dependencies" => false,
    "julia_binary_sha256" => file_sha256(first(Base.julia_cmd().exec)),
    "cpu_name" => Sys.CPU_NAME,
    "architecture" => string(Sys.ARCH),
    "kernel" => string(Sys.KERNEL),
    "native_preference_files" => native_files,
    "build_environment_sha256" => Dict(
        name => file_sha256(joinpath(build, name)) for
        name in ("Project.toml", "Manifest.toml", "LocalPreferences.toml")
    ),
    "image" => image,
    "image_sha256" => file_sha256(image),
    "image_bytes" => filesize(image),
    "project_sha256" => file_sha256(joinpath(source, "Project.toml")),
    "manifest_sha256" => file_sha256(joinpath(source, "Manifest.toml")),
    "preferences_sha256" => file_sha256(preferences),
    "preferences_file" => preferences,
    "build_project" => build,
    "build_seconds" => (time_ns()-started)/1e9,
    "writer" => TOML.parsefile(joinpath(output, "writer.toml")),
    "workload" => TOML.parsefile(joinpath(output, "workload.toml")),
    "qualification" => "BUILT_ONLY_NOT_USER_PATH_PERFORMANCE_MPI_OR_SCIENCE_QUALIFIED",
)
open(io -> TOML.print(io, record), joinpath(output, "image.toml"), "w")
