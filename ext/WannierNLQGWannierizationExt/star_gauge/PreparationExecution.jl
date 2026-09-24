"""Enumerate preparation dependencies without decoding native coefficients."""
function _preparation_source_files(source::QuantumEspressoWavefunctionSource)
    metadata = read_qe_xml(source)
    files = Dict("data-file-schema.xml" => metadata.xml_file)
    for (label, path) in metadata.upf_files
        files["UPF:$(label):$(basename(path))"] = path
    end
    for index in eachindex(metadata.kpoint_nodes)
        path = qe_wavefunction_file(source, index)
        files[basename(path)] = path
    end
    return files
end

"""Bind VASP preparation to structure, coefficients, spin settings, and POTCAR."""
function _preparation_source_files(source::VASPWavefunctionSource)
    files = Dict("POSCAR" => source.poscar_file, "WAVECAR" => source.wavecar_file)
    source.incar_file === nothing || (files["INCAR"] = something(source.incar_file))
    source.potcar_file === nothing || (files["POTCAR"] = something(source.potcar_file))
    return files
end

"""Enumerate implementation files once for the preparation digest registry."""
function _preparation_implementation_paths()
    root = normpath(joinpath(@__DIR__, "..", "..", ".."))
    paths = String[]
    for child in ("src", "ext")
        for (directory, _, names) in walkdir(joinpath(root, child)), name in names
            endswith(name, ".jl") && push!(paths, joinpath(directory, name))
        end
    end
    return root, sort!(paths)
end

"""Dispatch the unchanged preparation algebra through an explicit storage policy."""
function prepare_symmetry_covariant_wavefunctions(
    config::SymmetryCovariantWavefunctionPreparationConfig,
)
    execution = config.execution
    execution.mode in (:dense_reference, :streaming_serial, :streaming_threads) ||
        throw(ArgumentError("INVALID_PREPARATION_EXECUTION_MODE"))
    1 <= execution.max_workers <= 4 || throw(ArgumentError("INVALID_PREPARATION_WORKER_COUNT"))
    execution.memory_budget_bytes > 0 || throw(ArgumentError("INVALID_PREPARATION_MEMORY_BUDGET"))
    validate_symmetry_covariant_wavefunction_preparation_config(config)
    _, implementation_paths = _preparation_implementation_paths()
    files = _preparation_source_files(config.source)
    return with_verified_file_digests(vcat(collect(values(files)), implementation_paths)) do
        if execution.mode == :dense_reference
            return _prepare_symmetry_covariant_wavefunctions_impl(config)
        end
        directory = something(
            execution.checkpoint_directory,
            splitext(config.output_hdf5)[1] * ".preparation",
        )
        with_preparation_storage(joinpath(directory, "workspace")) do
            _prepare_symmetry_covariant_wavefunctions_impl(config)
        end
    end
end

"""Record non-scientific resource events separately from deterministic diagnostics."""
function _preparation_stage!(config, stage::String; star_index::Int = 0)
    directory = something(
        config.execution.checkpoint_directory,
        splitext(config.output_hdf5)[1] * ".preparation",
    )
    mkpath(directory)
    open(joinpath(directory, "resource_events.jsonl"), "a") do io
        JSON3.write(
            io,
            (
                stage = stage,
                star_index = star_index,
                time_unix = time(),
                peak_rss_bytes = Sys.maxrss(),
                cumulative_allocated_bytes = Base.gc_total_bytes(Base.gc_num()),
                cumulative_gc_seconds = Base.gc_num().total_time / 1.0e9,
            ),
        )
        write(io, '\n')
    end
    return nothing
end

"""Give one star an exclusive finite-momentum augmentation cache."""
function _preparation_private_metric(metric::_QEStrictSewingMetric)
    return _QEStrictSewingMetric(
        metric.upf_data,
        metric.plan,
        metric.projectors,
        metric.projector_bases,
        metric.spinorbit,
        copy(metric.finite_b_cache),
        metric.metric_kind,
    )
end
"""Reuse immutable VASP projector data without adding a mutable cache."""
_preparation_private_metric(metric::_VASPStrictSewingMetric) = metric

"""Bind private restart records to the numerical configuration, source, and implementation."""
function _preparation_contract(config, common)
    buffer = IOBuffer()
    write(buffer, "preparation-star-v1\n", string(VERSION), '\n')
    for name in fieldnames(typeof(config))
        name in (
            :execution,
            :output_hdf5,
            :preflight_diagnostics_jsonl,
            :maximum_star_count,
            :selected_star_indices,
        ) && continue
        write(buffer, string(name), '=', repr(getfield(config, name)), '\n')
    end
    for (name, digest) in sort!(collect(common.raw_native.input_sha256); by = first)
        write(buffer, name, '=', digest, '\n')
    end
    # Every stage depends on the PAW source files, including VASP POTCAR,
    # which is not part of the raw WAVECAR reader's input dictionary.
    for (name, path) in sort!(collect(_preparation_source_files(config.source)); by = first)
        write(buffer, "source_file:", name, '=', sha256_file(path), '\n')
    end
    root, paths = _preparation_implementation_paths()
    for path in sort!(paths)
        write(buffer, relpath(path, root), '\0', sha256_file(path), '\n')
    end
    return bytes2hex(sha256(take!(buffer)))
end

"""Conservative star workspace estimate; the external RSS guard remains authoritative."""
function _preparation_star_execution(config, common, stars)
    indices =
        config.selected_star_indices === nothing ? collect(eachindex(stars)) :
        sort!(unique(something(config.selected_star_indices)))
    config.maximum_star_count === nothing ||
        (indices = first(indices, min(length(indices), something(config.maximum_star_count))))
    largest_point_bytes = maximum(sizeof(point.coefficients) for point in common.native.kpoints)
    largest_star = maximum(length(stars[index]) for index in indices)
    # Raw, completed, transport, reconstruction, and eigensolver temporaries.
    per_worker = max(64 * 1024^2, 6 * largest_star * largest_point_bytes)
    reserved_bytes = max(2 * 1024^3, Sys.maxrss())
    available = floor(Int, 0.75 * config.execution.memory_budget_bytes) - reserved_bytes
    per_worker <= available ||
        throw(ArgumentError("MEMORY_BUDGET_HOLD: one star exceeds planned workspace"))
    workers =
        config.execution.mode == :streaming_threads ?
        min(config.execution.max_workers, Threads.nthreads(), max(1, available ÷ per_worker)) : 1
    directory = something(
        config.execution.checkpoint_directory,
        splitext(config.output_hdf5)[1] * ".preparation",
    )
    open(joinpath(directory, "resource_events.jsonl"), "a") do io
        JSON3.write(
            io,
            (
                stage = "scheduler_resolved",
                time_unix = time(),
                requested_workers = config.execution.max_workers,
                resolved_workers = workers,
                per_worker_estimated_bytes = per_worker,
                reserved_bytes = reserved_bytes,
                budget_bytes = config.execution.memory_budget_bytes,
                usable_fraction = 0.75,
            ),
        )
        write(io, '\n')
    end
    return (
        config = config,
        common = common,
        stars = stars,
        indices = indices,
        workers = workers,
        directory = directory,
        contract = _preparation_contract(config, common),
        pending = Dict{Int, Task}(),
        launched = Set{Int}(),
    )
end

"""Restore a committed star or compute and atomically checkpoint it."""
function _run_preparation_star(state, index)
    config = state.config
    path = joinpath(state.directory, "stars", "star-$(index).bin")
    contract = state.contract * ":$(index)"
    if config.execution.mode != :dense_reference && config.execution.resume
        cached = read_preparation_checkpoint(path, contract)
        cached === nothing || return merge(cached, (reused = true,))
    end
    records = Any[]
    payload = task_local_storage(:wannier_preparation_diagnostics, records) do
        _compute_preparation_star(state.common, index, state.stars[index])
    end
    result = (payload = payload, records = records, reused = false)
    if config.execution.mode != :dense_reference
        write_preparation_checkpoint(path, contract, result)
    end
    return result
end

"""Bound the launch frontier and consume completed work in canonical star order."""
function _preparation_star_result!(state, index, star)
    stop_file = get(ENV, "WANNIERNLQG_PREPARATION_STOP_FILE", "")
    if !isempty(stop_file) && isfile(stop_file)
        for task in values(state.pending)
            try
                wait(task)
            catch
                # Each successfully finished task seals its own checkpoint.
            end
        end
        throw(ArgumentError("MEMORY_BUDGET_HOLD: resource monitor requested a safe stop"))
    end
    if state.workers == 1 || index == first(state.indices)
        result = _run_preparation_star(state, index)
        push!(state.launched, index)
        return result
    end
    for next_index in state.indices
        next_index in state.launched && continue
        length(state.pending) >= state.workers && break
        push!(state.launched, next_index)
        state.pending[next_index] = Threads.@spawn _run_preparation_star(state, $next_index)
    end
    task = pop!(state.pending, index)
    try
        return fetch(task)
    catch
        for pending in values(state.pending)
            try
                wait(pending)
            catch
            end
        end
        rethrow()
    end
end

"""Reduce local maxima and rebuild cumulative JSONL fields in the original star order."""
function _merge_preparation_star_diagnostics!(config, maxima, contexts, result)
    previous = copy(maxima)
    previous_contexts = copy(contexts)
    for (key, value) in result.payload.maxima
        if value > get(maxima, key, -Inf)
            maxima[key] = value
            haskey(result.payload.contexts, key) && (contexts[key] = result.payload.contexts[key])
        end
    end
    for original in result.records
        record = deepcopy(original)
        if haskey(record, "raw_preflight_maxima")
            values = record["raw_preflight_maxima"]
            locations = record["raw_preflight_maximum_contexts"]
            for (key, value) in previous
                startswith(key, "pre_symmetrization_") ||
                    startswith(key, "raw_preflight_") ||
                    startswith(key, "hamiltonian_covariance_before") ||
                    continue
                if value >= get(values, key, -Inf)
                    values[key] = value
                    haskey(previous_contexts, key) && (locations[key] = previous_contexts[key])
                end
            end
            record["raw_preflight_diagnostic_status"] =
                get(values, "raw_preflight_diagnostic_exceeded", 0.0) > 0 ?
                "RAW_PREFLIGHT_DIAGNOSTIC_EXCEEDED" : "WITHIN_DIAGNOSTIC_REFERENCE"
        end
        _star_append_preflight_diagnostic(config, record)
    end
    return nothing
end

"""Resume one completed stage only after verifying all out-of-core dependencies."""
function _preparation_cached_stage(f::Function, config, contract, label::String)
    config.execution.mode == :dense_reference && return f()
    directory = something(
        config.execution.checkpoint_directory,
        splitext(config.output_hdf5)[1] * ".preparation",
    )
    path = joinpath(directory, "stages", label * ".bin")
    key = contract * ":" * label
    if config.execution.resume
        cached = read_preparation_checkpoint(path, key)
        if cached !== nothing && preparation_restore_vectors!(cached)
            _preparation_stage!(config, label * "_resumed")
            return cached
        end
    end
    result = f()
    preparation_release!()
    write_preparation_checkpoint(path, key, result)
    _preparation_stage!(config, label * "_committed")
    return result
end
