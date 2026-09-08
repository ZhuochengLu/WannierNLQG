#!/usr/bin/env julia

import Pkg
Pkg.activate(joinpath(@__DIR__, "..", "test"); io = devnull)
using JuliaFormatter
include(joinpath(@__DIR__, "FormatterPaths.jl"))

for path in formatter_paths()
    JuliaFormatter.format(path; overwrite = true, verbose = false)
end

println("formatted active Julia sources")
