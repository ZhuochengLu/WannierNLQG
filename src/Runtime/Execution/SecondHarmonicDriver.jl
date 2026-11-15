"""
Prepare SHG using the existing shared sampling scheduler, Fourier planner and MPI lanes.

The same response kernel serves BZ integration and planar densities. Lane ownership
is independent of thread/rank counts. The retained input model defines spin counting;
one electron per explicit model state is used, including spinor models.
"""
function prepare_second_harmonic(
    cfg,
    ctx,
    specs;
    prepare_only = false,
    progress_owner = true,
    shared_sources = nothing,
    mixed_memory_limit_bytes = mixed_fourier_memory_limit(),
    evaluation_policy::Symbol = :canonical_lanes,
)
    evaluation_policy in (:canonical_lanes, :whole_blocks) ||
        throw(ArgumentError("SHG_EVALUATION_POLICY"))
    spec = only(specs)
    slice = spec.calculation == :kslice
    adaptive = cfg.integration_algorithm isa HAdaptiveCubature
    adaptive_result = Ref{Any}(nothing)
    adaptive && bundle_mpi_initialize()
    loaded = shared_sources === nothing ? load_runtime_model_and_sources(ctx, cfg) : shared_sources
    model = loaded.model
    qualification = assess_response_qualification(loaded.manifest, ctx, cfg, specs)
    progress_response_qualification!(qualification)
    comm = bundle_mpi_comm_world()
    rank = bundle_mpi_comm_rank(comm)
    ranks = bundle_mpi_comm_size(comm)
    workers = Threads.nthreads()
    components = slice ? [Tuple(Int.(cfg.tensor_indices))] : SECOND_HARMONIC_COMPONENTS
    plan = bundle_matrix_element_plan(specs, cfg)
    workspaces = [MatrixElementWorkspace(model, plan) for _ in 1:workers]
    for workspace in workspaces
        prepare_real_space!(workspace, model)
    end
    grid =
        slice ?
        first(
            make_kslice_grid(
                collect(cfg.k_mesh),
                [1, 2],
                collect(cfg.kslice_origin),
                collect(cfg.kslice_vector_1),
                collect(cfg.kslice_vector_2),
            ),
        ) : _integral_k_grid(cfg, model)
    points = length(grid)
    builder =
        slice ?
        (
            (nd, nf) -> mixed_fourier_kslice_grid(
                model,
                cfg.k_mesh,
                collect(cfg.kslice_origin),
                collect(cfg.kslice_vector_1),
                collect(cfg.kslice_vector_2);
                nkdiv = nd,
                nkfft = nf,
            )
        ) : ((nd, nf) -> mixed_fourier_grid(model, cfg.k_mesh; nkdiv = nd, nkfft = nf))
    fourier = build_fourier_execution_plan(
        cfg,
        specs,
        model,
        first(workspaces),
        ranks,
        workers,
        builder;
        rank_memory_limit_bytes = mixed_memory_limit_bytes,
    )
    route = nothing
    provider_limit = fourier.memory_limit_bytes
    if evaluation_policy === :whole_blocks
        eligible = !slice && !adaptive && ranks > 1 && workers == 1 && fourier.grid !== nothing
        width =
            Base.checked_mul(length(cfg.photon_energies), Base.checked_mul(length(components), 14))
        proposed =
            eligible ?
            response_block_route_plan(
                ComplexF64,
                fourier.grid,
                points,
                width,
                rank,
                ranks,
                fourier.memory_limit_bytes,
            ) : nothing
        feasible = proposed !== nothing
        if feasible
            remaining = fourier.memory_limit_bytes-proposed.reserved_bytes
            feasible =
                remaining > 0 &&
                MatrixElements.mixed_fourier_buffer_estimate(
                    fourier.grid,
                    first(workspaces),
                    model;
                    memory_limit_bytes = remaining,
                ).estimated_bytes <= remaining
        end
        if bundle_mpi_all_true(feasible, comm)
            route = proposed
            provider_limit -= route.reserved_bytes
        end
    end
    route_seconds = Ref(0.0)
    if fourier.grid !== nothing
        prepare_mixed_worker_buffers!(
            workspaces,
            model,
            fourier.grid;
            memory_limit_bytes = provider_limit,
        )
    end
    lanes = adaptive ? 1 : _deterministic_integral_lane_count(points)
    rows = slice ? points : length(cfg.photon_energies)
    buffers = [zeros(ComplexF64, rows, length(components), 7, 2) for _ in 1:(slice ? 1 : lanes)]
    scratch = [
        zeros(ComplexF64, length(cfg.photon_energies), length(components), 7, 2) for _ in 1:workers
    ]
    kpoints = [zeros(3) for _ in 1:workers]
    coordinates = zeros(rows, slice ? 4 : 1)
    if slice
        point = zeros(3)
        for index in 1:points
            kslice_kpoint!(point, grid, index)
            coordinates[index, 1:3] .= point
            coordinates[index, 4] = only(cfg.photon_energies)
        end
    else
        coordinates[:, 1] .= cfg.photon_energies
    end
    volume = abs(integration_cell_measure(cfg, model))
    factors = (
        1.602176634e-19 / (8.8541878128e-12 * volume) * 1e12,
        1.602176634e-19^2 / (1.054571817e-34 * volume),
    )
    completed = Threads.Atomic{Int}(0)
    lock = ReentrantLock()
    started = time()
    progress_system_summary!(model)
    progress_task_start!(spec)
    progress_fourier_backend!(fourier_execution_summary(cfg, fourier, workspaces))
    function point_value!(worker, point)
        workspace = workspaces[worker]
        data = compute_kpoint!(workspace, model, point)
        values = scratch[worker]
        second_harmonic_response!(
            values,
            data,
            cfg.photon_energies,
            components;
            fermi_energy = cfg.fermi_energy,
            temperature = cfg.temperature,
            broadening = cfg.broadening,
            low_frequency_broadening = cfg.shg_low_frequency_broadening,
            gaussian = cfg.broadening_type == "Gaussian",
            intermediate_regularization = cfg.shg_intermediate_regularization,
            eta_correction = cfg.shg_eta_correction,
            degeneracy_threshold = cfg.degeneracy_threshold,
        )
        all(isfinite, values) || error("Nonfinite SHG response at fractional k $(Tuple(point))")
        return values
    end
    point_evaluators = [
        ResponsePointEvaluator(
            point_value!,
            worker,
            (
                shape = size(scratch[worker]),
                prefactor = :raw_shg_density,
                arbitrary_k = fourier.grid === nothing,
            ),
        ) for worker in 1:workers
    ]
    function consume_point!(worker, index, lane, values)
        if route !== nothing
            response_route_record!(route, index, values)
        elseif slice
            buffers[1][index, :, :, :] .= @view values[1, :, :, :]
        else
            buffers[lane] .+= values
        end
        done = Threads.atomic_add!(completed, 1) + 1
        if done == 1 || done % max(1, points ÷ 100) == 0
            bundle_debug_log(
                lock,
                "[kloop] SHG finished=$(done) full_grid_k_points=$(points) elapsed=$(time()-started)s",
            )
        end
        return nothing
    end
    execute_point! = ResponseGridConsumer(
        point_evaluators,
        grid,
        kpoints,
        slice ? kslice_kpoint! : integral_kpoint!,
        response_grid_request(workspaces, fourier.grid, grid, slice),
        consume_point!,
    )
    domain = adaptive ? response_integration_domain(cfg) : nothing
    function adaptive_units!(values)
        for quantity in 1:2
            values[:, :, :, quantity] .*= factors[quantity]
        end
        return values
    end
    evaluator =
        ResponseNodeEvaluator(first(point_evaluators), domain, model; transform! = adaptive_units!)
    function execute_adaptive!(worker, index, lane)
        adaptive_result[] = integrate_response_mpi(
            evaluator,
            domain,
            cfg.integration_algorithm;
            normalization = :domain_average,
        )
        return nothing
    end
    function finish!()
        if route !== nothing
            t0=time_ns()
            response_route_finish!(route, buffers, points, lanes, comm)
            route_seconds[]=(time_ns()-t0)*1e-9
        end
        bundle_mpi_collective_call(; enabled = true, comm) do
            progress_localized_run_diagnostics!(workspaces, comm)
        end
        result = zeros(ComplexF64, rows, length(components), 7, 2)
        for buffer in buffers
            reduced = bundle_mpi_reduce_sum(buffer, 0, comm)
            rank == 0 && (result .+= reduced)
        end
        outputs = String[]
        if rank == 0
            if adaptive
                result .= adaptive_result[].value
            else
                for quantity in 1:2
                    result[:, :, :, quantity] .*= factors[quantity] / (slice ? 1 : points)
                end
            end
            outputs = write_second_harmonic(
                ctx.run_dir,
                coordinates,
                result,
                components,
                SECOND_HARMONIC_TERMS;
                output = cfg.shg_output,
                response = cfg.shg_response,
                digits = resolved_response_output_digits(cfg, 12),
                slice,
                integration_dimension = integration_output_dimension(cfg),
                region = cfg.integration_bounds !== nothing,
                domain_metadata = integration_domain_metadata(cfg),
            )
        end
        if adaptive && rank==0
            push!(
                outputs,
                write_response_integration_diagnostics(
                    ctx.run_dir,
                    adaptive_result[],
                    cfg.integration_algorithm,
                    cfg,
                ),
            )
        end
        progress_task_done!(spec, outputs)
        return FusedBundleRunResult(
            outputs,
            ["second_harmonic_generation"],
            NamedTuple[],
            merge(
                fourier_execution_summary(cfg, fourier, workspaces),
                (
                    requested_evaluation_policy = String(evaluation_policy),
                    effective_evaluation_policy = route===nothing ? "canonical_lanes" :
                                                  "whole_blocks_canonical_replay",
                    route_reserved_bytes = route===nothing ? 0 : route.reserved_bytes,
                    route_send_bytes = route===nothing ? 0 : sizeof(route.sendvalues),
                    route_receive_bytes = route===nothing ? 0 : sizeof(route.recvvalues),
                    response_route_seconds = route_seconds[],
                ),
            ),
            NamedTuple(),
            NamedTuple(),
            runtime_replica_summary(loaded.replica_summary),
            qualification,
            runtime_model_geometry(model),
        )
    end
    function cleanup!()
        release_mixed_worker_buffers!(workspaces)
        shared_sources === nothing && release_runtime_storage!(loaded)
        return nothing
    end
    units =
        adaptive ? [(1, 1, 1)] :
        response_access_units(
            points,
            rank,
            ranks;
            grid = fourier.grid,
            policy = route===nothing ? :canonical_lanes : :whole_blocks,
        )
    prepared = PreparedResponseTask(
        units,
        adaptive ? execute_adaptive! : execute_point!,
        finish!,
        cleanup!;
        point_evaluators,
    )
    prepare_only && return prepared
    try
        execute_prepared_tasks!([prepared])
        return finish!()
    finally
        cleanup!()
    end
end
