#!/usr/bin/env julia

include(joinpath(@__DIR__, "visualization", "Launcher.jl"))

if abspath(PROGRAM_FILE) == @__FILE__
    exit(VisualizationLauncher.launch_visualization("kslice", ARGS, @__FILE__))
end
