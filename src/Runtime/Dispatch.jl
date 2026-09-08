"""
Validate and execute a `EffectiveTaskConfig`, returning a `RunResult` containing output and evidence paths.

Resolve input files, initialize requested MPI execution, run the fused task bundle, and write root-rank metadata/progress. Input or numerical failures propagate after failure logging; progress environment/state is restored on exit. Energy, temperature and tensor conventions follow the validated configuration.
"""
function run(cfg::EffectiveTaskConfig)
    specs = validate_config(cfg)
    bundle_mpi_initialize()
    mpi_bundle_start!()
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
            ) : ""
        progress_run_done!(
            outputs,
            metadata_path;
            family_counts = bundle_result.family_counts,
            fourier_summary = bundle_result.fourier_summary,
            response_symmetry_summary = bundle_result.response_symmetry_summary,
            band_summary = bundle_result.band_summary,
            replica_summary = bundle_result.replica_summary,
        )

        return RunResult(
            cfg.tasks,
            specs,
            ctx.run_dir,
            outputs,
            metadata_path,
            ctx.progress_out_path,
            ctx.progress_jsonl_path,
        )
    catch err
        progress_run_failed!(err)
        rethrow()
    finally
        mpi_bundle_finish!()
        progress_clear!()
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
        :model_sha256,
        :model_input_mode,
        :real_space_operator_bundle_file,
        :paired_tb_validation_file,
        :num_orbitals,
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
function write_task_run_index(path::String, ids::Vector{String}, results, sharing)
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
                ],
            )
        end
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
    ids = String[task.id for task in config.tasks]
    bundle_mpi_initialize()
    mpi_bundle_start!()
    loaded_sources = nothing
    prepared = PreparedResponseTask[]
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
                    ),
                )
            end
        else
            shared_context = context_with_demand(contexts, combined_operator_demand(contexts))
            loaded_sources = load_runtime_model_and_sources(shared_context, first(configs))
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
                        progress_owner = task_index == 1,
                        shared_sources = loaded_sources,
                        mixed_memory_limit_bytes = task_memory_limit,
                    )
                elseif plan isa KSliceBundlePlan
                    _run_kslice_bundle_fused!(
                        cfg,
                        ctx,
                        specs;
                        prepare_only = true,
                        progress_owner = task_index == 1,
                        shared_sources = loaded_sources,
                        mixed_memory_limit_bytes = task_memory_limit,
                    )
                else
                    error("Unsupported executor plan $(typeof(plan)) in shared response preparation.")
                end
                push!(prepared, prepared_task)
            end
            stats = execute_prepared_tasks!(prepared)
            sharing = (
                rank = bundle_mpi_comm_rank(bundle_mpi_comm_world()),
                workers = length(stats),
                model_loads = 1,
                fourier_counter_unit = "raw operator-group evaluations (FFT calls are reported separately)",
                worker_statistics = stats,
            )
            for (prepared_task, id, cfg, ctx, specs) in
                zip(prepared, ids, configs, contexts, identities)
                value = prepared_task.finish!()
                if !isempty(keys(value.response_symmetry_summary))
                    push!(
                        response_symmetry_summaries,
                        (task_id = id, summary = value.response_symmetry_summary),
                    )
                end
                metadata =
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
                    ),
                )
            end
        end
        if mpi_is_root_process()
            for (task, result) in zip(config.tasks, results)
                summary = task_parameter_summary(config, task)
                open(result.metadata_path, "a") do io
                    metadata_section(
                        io,
                        "EffectiveTaskConfiguration",
                        Pair{String, String}[
                            string(key) => metadata_value(value) for (key, value) in pairs(summary)
                        ],
                    )
                end
            end
        end
        outputs = reduce(vcat, [result.outputs for result in results]; init = String[])
        metadata =
            mpi_is_root_process() ? write_task_run_index(index_path, ids, results, sharing) : ""
        progress_run_done!(
            outputs,
            metadata;
            response_symmetry_summaries = response_symmetry_summaries,
        )
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
        )
    catch err
        progress_run_failed!(err)
        rethrow()
    finally
        for task in prepared
            task.cleanup!()
        end
        loaded_sources === nothing || release_runtime_storage!(loaded_sources)
        progress_clear!()
        mpi_bundle_finish!()
    end
end
