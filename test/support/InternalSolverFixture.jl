module InternalSolverFixture
import WannierNLQG
const W = WannierNLQG.Wannierization

"""Retain nondefault internal algorithms in existing strict scientific fixtures.

This test-only factory is not a supported user configuration route. Public
constructor/input rejection is checked separately; numerical fixtures retain
their original internal constants and all scientific assertions.
"""
function solver_config(; acceleration = nothing, kwargs...)
    solver = W.WannierizationSolverConfig(; kwargs...)
    acceleration === nothing && return solver
    names = fieldnames(typeof(solver))
    return W.WannierizationSolverConfig(
        (name === :acceleration ? acceleration : getfield(solver, name) for name in names)...,
    )
end

function replace_group(group, replacements)
    names = fieldnames(typeof(group))
    return typeof(group)(
        (
            haskey(replacements, name) ? getproperty(replacements, name) : getfield(group, name) for
            name in names
        )...,
    )
end
end
