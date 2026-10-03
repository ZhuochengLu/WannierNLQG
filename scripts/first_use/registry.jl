#!/usr/bin/env julia

using WannierNLQG
using JSON3

const ROOT = normpath(joinpath(@__DIR__, "..", ".."))
const RUNTIME = WannierNLQG.Runtime

function registry_rows()
    rows = NamedTuple[]
    for definition in RUNTIME.TASK_DEFINITIONS
        quantity = String(RUNTIME.quantity_symbol(definition.quantity))
        method = String(RUNTIME.method_symbol(definition.method))
        calculation = String(RUNTIME.calculation_symbol(definition.calculation))
        family = calculation == "kpath" ? "band" : calculation
        filename = calculation == "kpath" ? "band_structure.jl" : "$(quantity)_$(method).jl"
        relative = joinpath(family, filename)
        isfile(joinpath(ROOT, "examples", "tasks", relative)) ||
            error("registered task has no public example: $(relative)")
        push!(
            rows,
            (
                id = "$(calculation)__$(quantity)__$(method)",
                quantity = quantity,
                method = method,
                calculation = calculation,
                example = replace(relative, '\\' => '/'),
            ),
        )
    end
    length(rows) == 52 || error("expected 52 registered paths, found $(length(rows))")
    return sort!(rows; by = row -> row.id)
end

const FROZEN_REGISTRY = joinpath(@__DIR__, "path_registry.json")
value = JSON3.write(registry_rows()) * "\n"
if ARGS == ["--check"]
    isfile(FROZEN_REGISTRY) && read(FROZEN_REGISTRY, String) == value ||
        error("FIRST_USE_PATH_REGISTRY_STALE")
    println("first-use registry verified: 52 paths")
elseif isempty(ARGS)
    print(value)
else
    error("usage: registry.jl [--check]")
end
