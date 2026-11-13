# Verify an explicitly selected image, then enter the ordinary public CLI.
if ARGS == ["--help"] || ARGS == ["-h"]
    println("Usage: run_with_sysimage.jl IMAGE_DIRECTORY LOCAL_PREFERENCES COMMAND [ARGUMENTS...]")
    println(
        "Example: run_with_sysimage.jl /absolute/image-directory /absolute/LocalPreferences.toml run examples/text_input/band-column-nodes.toml --records /absolute/run-records",
    )
    println(
        "The image must match this source path, Julia binary, CPU, dependency lock, preferences and native files. See docs/PRECOMPILATION.md; ordinary use needs no image.",
    )
    exit(0)
end
include("SystemImageProvenance.jl")
using .SystemImageProvenance: verify_system_image
length(ARGS) >= 3 ||
    error("usage: run_with_sysimage.jl IMAGE_DIRECTORY LOCAL_PREFERENCES COMMAND [ARGUMENTS...]")
source = normpath(joinpath(@__DIR__, ".."))
paths = verify_system_image(source, ARGS[1], ARGS[2])
julia = first(Base.julia_cmd().exec)
command = Cmd([
    julia,
    "--startup-file=no",
    "--project=" * paths.build,
    "--sysimage=" * paths.image,
    joinpath(@__DIR__, "wanniernlqg.jl"),
    ARGS[3:end]...,
])
exit(run(ignorestatus(command)).exitcode)
