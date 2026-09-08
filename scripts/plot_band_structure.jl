#!/usr/bin/env julia

module BandStructurePlot

include(joinpath(@__DIR__, "visualization", "Launcher.jl"))
using .VisualizationLauncher

const REMOVED_LEGACY_FLAGS = Set(("--bands", "--path"))

"""Reject the removed positional/flag interface before launching the shared renderer."""
function validate_cli_contract(args::Vector{String})
    any(argument -> argument in REMOVED_LEGACY_FLAGS, args) &&
        error("the legacy --bands/--path interface was removed; use --config CONFIG.json")
    isempty(args) && error("missing --config CONFIG.json")
    any(argument -> argument in ("--help", "-h", "--dump-default-config"), args) && return nothing
    "--config" in args || error(
        "the positional BANDS.dat BAND_PATH.json interface was removed; use --config CONFIG.json",
    )
    return nothing
end

"""Launch the audited shared band renderer."""
function main(args::Vector{String} = ARGS)
    validate_cli_contract(args)
    return VisualizationLauncher.launch_visualization("band", args, @__FILE__)
end

end

if abspath(PROGRAM_FILE) == @__FILE__
    exit(BandStructurePlot.main())
end
