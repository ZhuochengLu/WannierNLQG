"""Reuse complete native operator publications after verifying their dependencies.

This private receipt contains a compact result and hashes, never a second copy of
large scientific payloads. Callers retain ownership of early validation and the
original numerical kernels; only a successfully published result may be sealed.
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
    pack_result = identity,
    restore_result = identity,
) where {F, P}
    files = collect(values(_preparation_source_files(config.source)))
    append!(files, additional_inputs)
    root, implementation = _preparation_implementation_paths()
    project = Base.active_project()
    environment_paths =
        project === nothing ? String[] : [project, joinpath(dirname(project), "Manifest.toml")]
    environment_files = filter(isfile, environment_paths)
    return with_verified_file_digests(vcat(files, implementation, environment_files)) do
        inputs = sort!([(realpath(path), sha256_file(path)) for path in unique(files)])
        code = [(relpath(path, root), sha256_file(path)) for path in implementation]
        environment = [
            (basename(path), isfile(path) ? sha256_file(path) : "NOT_PRESENT") for
            path in environment_paths
        ]
        numerical_config = [
            (name, getfield(config, name)) for name in fieldnames(typeof(config)) if name ∉ (
                :execution,
                :overwrite,
                :resume,
                :scratch_directory,
                :output_file,
                :provenance_json,
            )
        ]
        binding = bytes2hex(
            SHA.sha256(
                repr((
                    "published-native-operator-v1",
                    VERSION,
                    Sys.MACHINE,
                    environment,
                    operator,
                    (paths.output, paths.provenance),
                    numerical_config,
                    inputs,
                    code,
                )),
            ),
        )
        directory = something(
            execution === nothing ? nothing : execution.checkpoint_directory,
            joinpath(dirname(paths.output), ".wannier_preparation"),
        )
        receipt = joinpath(
            directory,
            "published-operators",
            basename(paths.output) * "." * string(operator) * ".bin",
        )
        saved = read_preparation_checkpoint(receipt, binding)
        if saved !== nothing && isfile(paths.output) && isfile(paths.provenance)
            sha256_file(paths.output) == saved.output_sha256 &&
            sha256_file(paths.provenance) == saved.provenance_sha256 ||
                throw(ArgumentError("OPERATOR_PUBLISHED_CONTENT_MISMATCH: $(operator)"))
            restored = restore_result(saved.result)
            if restored !== nothing
                @info "operator publication reused" operator output = paths.output
                return restored
            end
        end
        result = if config.source isa QuantumEspressoWavefunctionSource
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
        if published(result)
            write_preparation_checkpoint(
                receipt,
                binding,
                (
                    output_sha256 = sha256_file(paths.output),
                    provenance_sha256 = sha256_file(paths.provenance),
                    result = pack_result(result),
                ),
            )
        end
        return result
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

"""Seal a thin result plus references to the original full-precision spin blocks."""
function _pack_spn_publication_result(result, context)
    blocks = context.slot[]
    blocks === nothing && throw(ArgumentError("SPN_PUBLICATION_BLOCK_CONTRACT_MISSING"))
    spn = something(result.spn)
    fields = ntuple(index -> getfield(result, index + 1), fieldcount(typeof(result)) - 1)
    return (
        schema = "spn-block-result-v1",
        blocks = blocks,
        fields = fields,
        shape = size(spn.data),
        array_sha256 = _star_array_sha256(spn.data),
    )
end

"""Restore the exact original SPN tensor; never infer discarded entries from its text format."""
function _restore_spn_publication_result(saved)
    saved.schema == "spn-block-result-v1" || throw(ArgumentError("SPN_PUBLICATION_SCHEMA_MISMATCH"))
    blocks = saved.blocks
    blocks.kind in (:qe, :vasp) || throw(ArgumentError("SPN_PUBLICATION_SOURCE_MISMATCH"))
    length(saved.shape) == 4 && saved.shape[3] == 3 && saved.shape[4] == blocks.count ||
        throw(ArgumentError("SPN_PUBLICATION_DIMENSION_MISMATCH"))
    data = Array{ComplexF64}(undef, saved.shape)
    expected = saved.shape[1:3]
    for kpoint in 1:blocks.count
        path = joinpath(blocks.directory, blocks.label, "block-$(kpoint).bin")
        block = read_preparation_checkpoint(path, blocks.contract * ":" * string(kpoint))
        block === nothing && return nothing
        value = if blocks.kind == :qe
            block[1]
        else
            size(block[1]) == expected && size(block[2]) == expected ||
                throw(ArgumentError("SPN_PUBLICATION_BLOCK_DIMENSION_MISMATCH"))
            # This is the same elementwise addition used by the original diagnostics.
            block[1] .+ block[2]
        end
        size(value) == expected && all(isfinite, value) ||
            throw(ArgumentError("SPN_PUBLICATION_BLOCK_INVALID"))
        data[:, :, :, kpoint] .= value
    end
    _star_array_sha256(data) == saved.array_sha256 ||
        throw(ArgumentError("SPN_PUBLICATION_ARRAY_DIGEST_MISMATCH"))
    spn = WannierSPN(saved.shape[1], saved.shape[4], data)
    return blocks.kind == :qe ? QEPAWSPNResult(spn, saved.fields...) :
           VASPPAWSPNResult(spn, saved.fields...)
end

"""Provide durable point blocks and compact publication receipts for both native SPN sources."""
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
    working =
        selected !== nothing && selected.checkpoint_directory !== nothing ? base :
        joinpath(base, "spin-publication-blocks", bytes2hex(SHA.sha256(paths.output)))
    effective = (
        mode = selected === nothing ? :streaming_serial : selected.mode,
        max_workers = selected === nothing ? 1 : selected.max_workers,
        memory_budget_bytes = selected === nothing ? 24 * 1024^3 : selected.memory_budget_bytes,
        checkpoint_directory = working,
        resume = true,
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
        published = result -> haskey(result.artifacts, "spn_sha256"),
        pack_result = result -> _pack_spn_publication_result(result, context),
        restore_result = _restore_spn_publication_result,
    )
end
