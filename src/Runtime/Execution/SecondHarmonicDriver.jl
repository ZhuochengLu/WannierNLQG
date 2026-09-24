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
)
    spec = only(specs)
    slice = spec.calculation == :kslice
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
        ) : _integral_k_grid(cfg.k_mesh)
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
    if fourier.grid !== nothing
        for workspace in workspaces
            enable_mixed_fourier!(
                workspace,
                model,
                fourier.grid;
                memory_limit_bytes = fourier.memory_limit_bytes,
            )
        end
    end
    lanes = _deterministic_integral_lane_count(points)
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
    volume = abs(det(model.lattice))
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
    function execute_point!(worker, index, lane)
        # Do not capture the outer slice-coordinate scratch in this threaded callback.
        local point = kpoints[worker]
        slice ? kslice_kpoint!(point, grid, index) : integral_kpoint!(point, grid, index)
        workspace = workspaces[worker]
        if fourier.grid !== nothing
            if slice
                u_index, v_index = kslice_indices(grid, index)
                begin_mixed_kpoint!(workspace, point, (u_index - 1, v_index - 1, 0))
            else
                begin_mixed_kpoint!(workspace, point)
            end
        end
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
            intermediate_regularization = cfg.denominator_regularization,
            eta_correction = cfg.shg_eta_correction,
            degeneracy_threshold = cfg.degeneracy_threshold,
        )
        all(isfinite, values) || error("Nonfinite SHG response at k index $(index)")
        if slice
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
    function finish!()
        result = zeros(ComplexF64, rows, length(components), 7, 2)
        for buffer in buffers
            reduced = bundle_mpi_reduce_sum(buffer, 0, comm)
            rank == 0 && (result .+= reduced)
        end
        outputs = String[]
        if rank == 0
            for quantity in 1:2
                result[:, :, :, quantity] .*= factors[quantity] / (slice ? 1 : points)
            end
            outputs = write_second_harmonic(
                ctx.run_dir,
                coordinates,
                result,
                components,
                SECOND_HARMONIC_TERMS;
                output = cfg.shg_output,
                response = cfg.shg_response,
                digits = max(12, cfg.response_output_digits),
                slice,
            )
        end
        progress_task_done!(spec, outputs)
        return FusedBundleRunResult(
            outputs,
            ["second_harmonic_generation"],
            NamedTuple[],
            fourier_execution_summary(cfg, fourier, workspaces),
            NamedTuple(),
            NamedTuple(),
            runtime_replica_summary(loaded.replica_summary),
            qualification,
        )
    end
    function cleanup!()
        for workspace in workspaces
            disable_mixed_fourier!(workspace)
        end
        shared_sources === nothing && release_runtime_storage!(loaded)
        return nothing
    end
    units = NTuple{3, Int}[
        (index, index, lane) for lane in _local_deterministic_integral_lanes(lanes, rank, ranks) for
        index in _deterministic_integral_lane_range(points, lanes, lane)
    ]
    prepared = PreparedResponseTask(units, execute_point!, finish!, cleanup!)
    prepare_only && return prepared
    try
        execute_prepared_tasks!([prepared])
        return finish!()
    finally
        cleanup!()
    end
end
