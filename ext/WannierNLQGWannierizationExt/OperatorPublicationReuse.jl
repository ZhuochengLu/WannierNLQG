"""Build an operator publication without digest-only receipt reuse.

Old compact receipts contain no complete source definitions. They cannot prove
current input equality after content authentication is removed, so they are not
read or rewritten. The original builder retains its numerical validation,
publication, overwrite and failure behavior; existing files are never silently
adopted or replaced here.
"""
function _with_operator_publication_receipt(
    builder::F,
    config,
    operator::Symbol,
    paths,
    additional_inputs;
    execution = nothing,
    native_execution = execution,
    published::P,
) where {F, P}
    return if config.source isa QuantumEspressoWavefunctionSource
        _with_qe_operator_artifacts(
            builder,
            config.source,
            config.topology_file,
            dirname(paths.output),
            config.max_cached_wavefunction_kpoints;
            execution = native_execution,
            additional_inputs = additional_inputs,
        )
    else
        builder()
    end
end

"""Record existing point checkpoints on the coordinator without copying their payloads."""
function _record_spn_publication_blocks(kind, execution, label, contract, count)
    context = get(task_local_storage(), :wannier_spn_publication_blocks, nothing)
    context === nothing && return nothing
    context.owner === current_task() || throw(ArgumentError("SPN_PUBLICATION_COORDINATOR_REQUIRED"))
    execution.checkpoint_directory === nothing &&
        throw(ArgumentError("SPN_PUBLICATION_BLOCK_DIRECTORY_REQUIRED"))
    context.slot[] = (
        kind = kind,
        directory = abspath(execution.checkpoint_directory),
        label = label,
        contract = contract,
        count = count,
    )
    return nothing
end

"""Provide owned fresh point blocks without adopting digest-only publication receipts."""
function _with_spn_publication_receipt(builder, config, paths, inputs; execution = nothing)
    selected =
        execution === nothing ? get(task_local_storage(), :wannier_preparation_execution, nothing) :
        execution
    if selected !== nothing && (!selected.resume || selected.mode == :dense_reference)
        return builder(selected)
    end
    base =
        selected === nothing || selected.checkpoint_directory === nothing ?
        joinpath(dirname(paths.output), ".wannier_preparation") : selected.checkpoint_directory
    mkpath(base)
    # Each fresh publication owns its scratch; no path hash or uncertain old
    # block cache can stand in for current scientific input equality.
    working = mktempdir(base; prefix = "spin-publication-blocks-", cleanup = false)
    effective = (
        mode = selected === nothing ? :streaming_serial : selected.mode,
        max_workers = selected === nothing ? 1 : selected.max_workers,
        memory_budget_bytes = selected === nothing ? 24 * 1024^3 : selected.memory_budget_bytes,
        checkpoint_directory = working,
        resume = false,
    )
    context = (owner = current_task(), slot = Ref{Any}(nothing))
    run =
        () -> task_local_storage(() -> builder(effective), :wannier_spn_publication_blocks, context)
    return _with_operator_publication_receipt(
        run,
        config,
        :SPN,
        paths,
        inputs;
        execution = effective,
        native_execution = selected,
        published = result -> haskey(result.artifacts, "spn"),
    )
end
