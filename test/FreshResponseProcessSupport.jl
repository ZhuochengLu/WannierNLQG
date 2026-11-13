# Test-only standalone child command. A direct exec child is not a rank of
# the parent's mpirun session. Preserve numerical/resource/depot settings, but
# do not connect this child to its parent's launcher rendezvous.
function fresh_response_command(command::Cmd)
    args = collect(command)
    probe_index = findfirst(arg -> endswith(arg, "Probe.jl"), args)
    probe_index === nothing && error("fresh response probe script is required")
    probe = args[probe_index]
    basename(probe) in ("OperatorTaskSelectionProbe.jl", "NeighborOrderFreshProbe.jl") ||
        error("unsupported fresh response probe")
    insert!(args, probe_index, joinpath(@__DIR__, "FreshResponseProcess.jl"))
    isolated = Cmd(args)
    removals = Pair{String, Nothing}[
        key => nothing for key in keys(ENV) if
        startswith(key, "OMPI_") || startswith(key, "PMIX_") || startswith(key, "PMI_")
    ]
    return addenv(isolated, removals...)
end
