"""Broadcast any source admission or completion failure through the existing MPI root-call contract."""
function synchronize_input_source_setup(exception)
    comm = bundle_mpi_comm_world()
    for source_rank in 0:(bundle_mpi_comm_size(comm) - 1)
        bundle_mpi_root_call(; root = source_rank, comm) do
            exception === nothing || throw(exception)
            nothing
        end
    end
    return nothing
end

"""Observe declared scientific inputs for one complete ordinary run.

Only root observes retained file-backed inputs; native collective preflight owns
native sources. All ranks enter the original setup collective before numerical
work and the same completion collective after successful callback return. A
changed input rejects the run without hashing numerical file contents here.
Numerical exceptions preserve the original propagation and cleanup path.
"""
function with_runtime_input_sources(f::F, configs, identities) where {F}
    entered_setup_collective = false
    try
        paths = String[]
        for (cfg, specs) in zip(configs, identities)
            if cfg.native_model_input !== nothing &&
               cfg.response_symmetry_file !== nothing &&
               !isempty(strip(cfg.response_symmetry_file))
                declaration = resolve_path(
                    cfg.response_symmetry_file,
                    cfg.response_symmetry_file;
                    base = resolve_case_root(cfg.case_root),
                )
                observe_scientific_source(declaration)
            end
            if cfg.native_model_input !== nothing || mpi_is_root_process()
                append!(paths, runtime_input_source_paths(cfg, specs))
            end
        end
        observations = [
            (; declared_path = abspath(path), state = observe_scientific_source(realpath(path))) for path in unique(paths)
        ]
        entered_setup_collective = true
        synchronize_input_source_setup(nothing)
        result = f()
        completion_error = try
            foreach(observations) do observation
                validate_scientific_source_state(
                    observation.state;
                    declared_path = observation.declared_path,
                )
            end
            nothing
        catch exception
            exception
        end
        synchronize_input_source_setup(completion_error)
        return result
    catch exception
        entered_setup_collective && rethrow()
        synchronize_input_source_setup(exception)
        rethrow()
    end
end

"""
Validate and execute a `EffectiveTaskConfig`, returning a `RunResult` containing output and evidence paths.

Resolve input files, initialize requested MPI execution, run the fused task bundle, and write root-rank metadata/progress. Input or numerical failures propagate after failure logging; progress environment/state is restored on exit. Energy, temperature and tensor conventions follow the validated configuration.
"""
function run(cfg::EffectiveTaskConfig)
    specs = validate_config(cfg)
    bundle_mpi_initialize()
    mpi_bundle_start!()
    try
        return with_runtime_input_sources([cfg], [specs]) do
            run_validated_task(cfg, specs)
        end
    finally
        mpi_bundle_finish!()
        progress_clear!()
    end
end

"""Execute one already validated task inside the declared-input source lifetime."""
function run_validated_task(cfg::EffectiveTaskConfig, specs)
    try
        ctx = prepare_run_context(cfg, specs)
        definitions =
            [task_definition(spec.quantity, spec.method, spec.calculation) for spec in specs]
        band_structure =
            all(definition -> definition !== nothing && _is_band_structure(definition), definitions)
        execution_mode = band_structure ? "kpath_band_structure" : "fused_kloop"
        matrix_families = bundle_matrix_families(specs, cfg)
        progress_start!(cfg, ctx, execution_mode, matrix_families)
        bundle_result = run_task_bundle_fused!(cfg, ctx, specs)
        outputs = bundle_result.outputs
        metadata_path =
            mpi_is_root_process() ?
            write_metadata(
                cfg,
                ctx,
                outputs,
                execution_mode;
                matrix_families = bundle_result.matrix_families,
                family_counts = bundle_result.family_counts,
                fourier_summary = bundle_result.fourier_summary,
                response_symmetry_summary = bundle_result.response_symmetry_summary,
                band_summary = bundle_result.band_summary,
                replica_summary = bundle_result.replica_summary,
                qualification_summary = response_qualification_summary(bundle_result.qualification),
                model_geometry = bundle_result.model_geometry,
            ) : ""
        progress_run_done!(
            outputs,
            metadata_path;
            family_counts = bundle_result.family_counts,
            fourier_summary = bundle_result.fourier_summary,
            response_symmetry_summary = bundle_result.response_symmetry_summary,
            band_summary = bundle_result.band_summary,
            replica_summary = bundle_result.replica_summary,
            qualification_summary = response_qualification_summary(bundle_result.qualification),
        )

        return RunResult(
            cfg.tasks,
            specs,
            ctx.run_dir,
            outputs,
            metadata_path,
            ctx.progress_out_path,
            ctx.progress_jsonl_path,
            bundle_result.qualification,
        )
    catch err
        progress_run_failed!(err)
        rethrow()
    end
end

"""Combine validated operator component demands without widening any task's formula."""
function combined_operator_demand(contexts::Vector{RunContext})
    operators = RealSpaceOperatorKind[]
    components = Dict{RealSpaceOperatorKind, Vector{NTuple{2, Int8}}}()
    for context in contexts
        append!(operators, context.operator_demand.required_operators)
        for (kind, selected) in context.operator_demand.required_components
            append!(get!(components, kind, NTuple{2, Int8}[]), selected)
        end
    end
    for selected in values(components)
        sort!(unique!(selected))
    end
    return OperatorDemandPlan(
        canonical_operator_inventory(unique(operators)),
        components,
        any(context.operator_demand.requires_full_projector_geometry for context in contexts),
    )
end

"""Copy one validated context with a resolved shared demand and optional common seed inputs."""
function context_with_demand(
    context::RunContext,
    demand::OperatorDemandPlan;
    seed_inputs::Union{Nothing, SeedInputPaths} = context.seed_inputs,
)
    return RunContext(
        (
            name == :operator_demand ? demand :
            name == :seed_inputs ? seed_inputs : getfield(context, name) for
            name in fieldnames(RunContext)
        )...,
    )
end

"""Check common model identity and merge task-derived seed dependencies before sharing input data."""
function context_with_demand(contexts::Vector{RunContext}, demand::OperatorDemandPlan)
    isempty(contexts) && throw(ArgumentError("A shared input context requires at least one task."))
    reference = first(contexts)
    identity_fields = (
        :model_file,
        :model_identity,
        :model_input_mode,
        :real_space_operator_bundle_file,
        :paired_tb_validation_file,
        :num_orbitals,
        :native_admission,
    )
    for context in contexts, name in identity_fields
        getfield(context, name) == getfield(reference, name) || throw(
            ArgumentError(
                "Tasks cannot share different model input contracts: $(name) differs between $(reference.run_dir) and $(context.run_dir).",
            ),
        )
    end
    seeds = SeedInputPaths[
        context.seed_inputs for context in contexts if context.seed_inputs !== nothing
    ]
    shared_seed = isempty(seeds) ? nothing : first(seeds)
    if shared_seed !== nothing
        shared_seed.model_file == reference.model_file || throw(
            ArgumentError("Shared seed-derived model path differs from the validated model input."),
        )
        for seed in seeds, name in fieldnames(SeedInputPaths)
            getfield(seed, name) == getfield(shared_seed, name) || throw(
                ArgumentError(
                    "Tasks cannot share conflicting seed input contracts: $(name) differs.",
                ),
            )
        end
    end
    return context_with_demand(reference, demand; seed_inputs = shared_seed)
end

"""Persist the task-ID index and measured sharing counters alongside task metadata."""
function write_task_run_index(
    path::String,
    ids::Vector{String},
    results,
    sharing,
    qualification::ResponseQualificationResult,
)
    qualification_summary = response_qualification_summary(qualification)
    open(path, "w") do io
        metadata_section(
            io,
            "Run",
            Pair{String, String}[
                "execution_mode" => "shared_sampling_per_task",
                "tasks.count" => string(length(ids)),
            ],
        )
        for (id, result) in zip(ids, results)
            metadata_section(
                io,
                "Task " * id,
                Pair{String, String}[
                    "id" => id,
                    "metadata" => relpath(result.metadata_path, dirname(path)),
                    "outputs" => metadata_value(relpath.(result.outputs, dirname(path))),
                    "qualification_status" => result.qualification.qualification_status,
                    "production_eligible" => string(result.qualification.production_eligible),
                ],
            )
        end
        metadata_section(
            io,
            "Qualification",
            Pair{String, String}[
                string(key) => metadata_value(value) for
                (key, value) in pairs(qualification_summary)
            ],
        )
        metadata_section(
            io,
            "SharedInterpolation",
            Pair{String, String}[
                string(key) => metadata_value(value) for (key, value) in pairs(sharing)
            ],
        )
    end
    return path
end

"""
Execute independently specified tasks on one model and sampling domain.

Validate every task before numerical execution. Share only parameter-independent
interpolation data; every task retains its own weights, selectors and reduction
lanes. Results are indexed by the explicit task ID and numerical files preserve
the registered units and column contracts.
"""
function run(config::TaskConfig)
    configs = compile_task_configs(config)
    identities = validate_config.(configs)
    bundle_mpi_initialize()
    mpi_bundle_start!()
    try
        return with_runtime_input_sources(configs, identities) do
            # Keep validation and declared-input failures before backend activation.
            # Packed IO adds methods to a later Julia world. Enter its cached public
            # response tree once, outside numerical loops and inside original cleanup.
            if config.model isa ModelInput
                bundle = config.model.real_space_operator_bundle_file
                if bundle !== nothing && !isempty(strip(bundle))
                    backend_error = nothing
                    try
                        _load_operator_bundle_extension!()
                    catch exception
                        backend_error = exception
                    end
                    synchronize_input_source_setup(backend_error)
                    return Base.invokelatest(run_validated_tasks, config, configs, identities)
                end
            end
            run_validated_tasks(config, configs, identities)
        end
    finally
        mpi_bundle_finish!()
        progress_clear!()
    end
end

"""Execute shared tasks with verified input-file credentials and normal MPI cleanup."""
function run_validated_tasks(config, configs, identities)
    ids = String[task.id for task in config.tasks]
    loaded_sources = nothing
    prepared = PreparedResponseTask[]
    response_completion =
        any(spec -> spec.calculation in (:integral, :kslice), Iterators.flatten(identities))
    try
        contexts = [prepare_run_context(cfg, specs) for (cfg, specs) in zip(configs, identities)]
        # One run owns one progress stream; child metadata must reference that real stream.
        progress_context = first(contexts)
        contexts = [
            RunContext(
                (
                    name in (:progress_out_path, :progress_jsonl_path) ?
                    getfield(progress_context, name) : getfield(context, name) for
                    name in fieldnames(RunContext)
                )...,
            ) for context in contexts
        ]
        run_dir = dirname(first(contexts).run_dir)
        index_path = joinpath(run_dir, "metadata.txt")
        bundle_mpi_root_call(; comm = bundle_mpi_comm_world()) do
            for context in contexts
                isempty(readdir(context.run_dir)) ||
                    error("Task output directory is not empty: $(context.run_dir)")
            end
            isfile(index_path) && error("Run output already exists: $(run_dir)")
            nothing
        end
        task_display_records = NamedTuple[
            (id = id, spec = only(specs), cfg = cfg) for
            (id, cfg, specs) in zip(ids, configs, identities)
        ]
        progress_start!(
            first(configs),
            first(contexts),
            "shared_sampling_per_task",
            unique(
                reduce(
                    vcat,
                    [
                        bundle_matrix_families(specs, cfg) for
                        (cfg, specs) in zip(configs, identities)
                    ],
                ),
            ),
            task_display_records = task_display_records,
        )
        results = RunResult[]
        response_symmetry_summaries = NamedTuple[]
        sharing = NamedTuple()
        plans = [make_bundle_plan(cfg, specs) for (cfg, specs) in zip(configs, identities)]
        band_plan_flags = map(plan -> plan isa BandStructureBundlePlan, plans)
        any(band_plan_flags) &&
            !all(band_plan_flags) &&
            error(
                "A single shared-sampling run cannot mix BandStructure and response executor plans.",
            )
        if all(band_plan_flags)
            for (cfg, ctx, specs, plan) in zip(configs, contexts, identities, plans)
                value = run_task_bundle_fused!(cfg, ctx, plan)
                metadata =
                    mpi_is_root_process() ?
                    write_metadata(
                        cfg,
                        ctx,
                        value.outputs,
                        "kpath_band_structure";
                        matrix_families = value.matrix_families,
                        family_counts = value.family_counts,
                        fourier_summary = value.fourier_summary,
                        band_summary = value.band_summary,
                        replica_summary = value.replica_summary,
                        qualification_summary = response_qualification_summary(value.qualification),
                        model_geometry = value.model_geometry,
                    ) : ""
                push!(
                    results,
                    RunResult(
                        cfg.tasks,
                        specs,
                        ctx.run_dir,
                        value.outputs,
                        metadata,
                        first(contexts).progress_out_path,
                        first(contexts).progress_jsonl_path,
                        value.qualification,
                    ),
                )
            end
        else
            shared_context = context_with_demand(contexts, combined_operator_demand(contexts))
            has_paired_momenta = any(cfg -> cfg.photon_momentum_path !== nothing, configs)
            paired_source_start = has_paired_momenta ? time_ns() : UInt64(0)
            loaded_sources = load_runtime_model_and_sources(shared_context, first(configs))
            has_paired_momenta && (loaded_sources = freeze_paired_runtime_sources(loaded_sources))
            paired_source_seconds =
                has_paired_momenta ? (time_ns() - paired_source_start) * 1.0e-9 : 0.0
            task_memory_limit = div(mixed_fourier_memory_limit(), length(configs))
            for (task_index, (cfg, ctx, specs, plan)) in
                enumerate(zip(configs, contexts, identities, plans))
                prepared_task = if plan isa IntegralBundlePlan
                    _run_integral_bundle_fused!(
                        cfg,
                        ctx,
                        specs,
                        plan.controls;
                        prepare_only = true,
                        block_local_order = length(configs) == 1,
                        progress_owner = task_index == 1,
                        # Dispatch retains the owning record until its finally block.
                        # Integral preparation borrows the same numerical objects.
                        shared_sources = borrow_runtime_numerical_sources(loaded_sources),
                        mixed_memory_limit_bytes = task_memory_limit,
                    )
                elseif plan isa KSliceBundlePlan
                    _run_kslice_bundle_fused!(
                        cfg,
                        ctx,
                        specs;
                        prepare_only = true,
                        block_local_order = length(configs) == 1,
                        progress_owner = task_index == 1,
                        shared_sources = loaded_sources,
                        mixed_memory_limit_bytes = task_memory_limit,
                    )
                else
                    error("Unsupported executor plan $(typeof(plan)) in shared response preparation.")
                end
                push!(prepared, prepared_task)
            end
            stats = bundle_mpi_collective_call(; enabled = response_completion) do
                execute_prepared_tasks!(prepared)
            end
            sharing = (
                rank = bundle_mpi_comm_rank(bundle_mpi_comm_world()),
                workers = length(stats),
                model_loads = 1,
                fourier_counter_unit = "raw operator-group evaluations (FFT calls are reported separately)",
                worker_statistics = stats,
            )
            has_paired_momenta && (
                sharing = merge(
                    sharing,
                    (;
                        paired_source_load_and_snapshot_seconds = paired_source_seconds,
                        paired_source_timing_scope = "rank-local wall span including physical source read and owned snapshot; compilation is not subtracted",
                    ),
                )
            )
            for (prepared_task, id, cfg, ctx, specs) in
                zip(prepared, ids, configs, contexts, identities)
                value =
                    bundle_mpi_collective_call(prepared_task.finish!; enabled = response_completion)
                if !isempty(keys(value.response_symmetry_summary))
                    push!(
                        response_symmetry_summaries,
                        (task_id = id, summary = value.response_symmetry_summary),
                    )
                end
                metadata = bundle_mpi_collective_call(; enabled = response_completion) do
                    mpi_is_root_process() ?
                    write_metadata(
                        cfg,
                        ctx,
                        value.outputs,
                        "shared_sampling_per_task";
                        matrix_families = value.matrix_families,
                        family_counts = value.family_counts,
                        fourier_summary = value.fourier_summary,
                        response_symmetry_summary = value.response_symmetry_summary,
                        replica_summary = value.replica_summary,
                        qualification_summary = response_qualification_summary(value.qualification),
                        model_geometry = value.model_geometry,
                        metadata_centers = ctx.model_input_mode == :legacy &&
                                           cfg.real_space_replica_policy == "input" ?
                                           extract_wannier_centers(loaded_sources.model) :
                                           nothing,
                    ) : ""
                end
                push!(
                    results,
                    RunResult(
                        cfg.tasks,
                        specs,
                        ctx.run_dir,
                        value.outputs,
                        metadata,
                        first(contexts).progress_out_path,
                        first(contexts).progress_jsonl_path,
                        value.qualification,
                    ),
                )
            end
        end
        bundle_mpi_collective_call(; enabled = response_completion) do
            loaded_sources === nothing ||
                persist_native_derivative_records(loaded_sources.model, run_dir)
            if config.model isa AnalyticKInput &&
               loaded_sources === nothing &&
               mpi_is_root_process()
                write_native_derivative_records(
                    joinpath(run_dir, "native_derivatives.tsv"),
                    Dict{Int, NamedTuple}(),
                )
            end
            if mpi_is_root_process()
                for (task, result) in zip(config.tasks, results)
                    summary = task_parameter_summary(config, task)
                    open(result.metadata_path, "a") do io
                        metadata_section(
                            io,
                            "EffectiveTaskConfiguration",
                            Pair{String, String}[
                                string(key) => metadata_value(value) for
                                (key, value) in pairs(summary)
                            ],
                        )
                    end
                end
            end
            nothing
        end
        outputs = reduce(vcat, [result.outputs for result in results]; init = String[])
        qualification = aggregate_response_qualifications(
            ResponseQualificationResult[result.qualification for result in results],
        )
        metadata = bundle_mpi_collective_call(; enabled = response_completion) do
            local_metadata =
                mpi_is_root_process() ?
                write_task_run_index(index_path, ids, results, sharing, qualification) : ""
            progress_run_done!(
                outputs,
                local_metadata;
                response_symmetry_summaries = response_symmetry_summaries,
                qualification_summary = response_qualification_summary(qualification),
            )
            local_metadata
        end
        return RunResult(
            reduce(vcat, [cfg.tasks for cfg in configs]),
            reduce(vcat, identities),
            run_dir,
            outputs,
            metadata,
            first(contexts).progress_out_path,
            first(contexts).progress_jsonl_path,
            ids,
            results,
            sharing,
            qualification,
        )
    catch err
        if loaded_sources !== nothing &&
           loaded_sources.model isa AnalyticKModel &&
           @isdefined(run_dir)
            model=loaded_sources.model
            if model.evaluation_diagnostics !== nothing
                records=merge_analytic_derivative_diagnostics(model.evaluation_diagnostics)
                write_native_derivative_records(
                    joinpath(
                        run_dir,
                        "native_derivatives_failed_rank_$(bundle_mpi_comm_rank(bundle_mpi_comm_world())).tsv",
                    ),
                    records,
                )
            end
        end
        progress_run_failed!(err)
        rethrow()
    finally
        for task in prepared
            task.cleanup!()
        end
        loaded_sources === nothing || release_runtime_storage!(loaded_sources)
    end
end
