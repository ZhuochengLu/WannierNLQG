#!/usr/bin/env julia

import Pkg
Pkg.activate(joinpath(@__DIR__, "..", "test"); io = devnull)
using JuliaFormatter
include(joinpath(@__DIR__, "FormatterPaths.jl"))

all_formatted =
    all(path -> JuliaFormatter.format(path; overwrite = false, verbose = false), formatter_paths())
all_formatted || error("JuliaFormatter check failed; run `julia --project=. scripts/format.jl`")

println("formatter check passed")
