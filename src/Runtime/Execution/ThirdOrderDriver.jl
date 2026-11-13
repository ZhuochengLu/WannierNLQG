"""Retain ordinary input eligibility; material convergence remains separate evidence."""
function third_order_response_qualification(base)
    return ResponseQualificationResult(
        base.execution_eligible,
        base.qualification_status,
        base.production_eligible,
        base.quality_review_recommended,
        base.reasons,
        base.verified_contracts,
        vcat(base.unverified_contracts, ["third_order.material_convergence"]),
        base.conflicting_contracts,
        base.input_qualification,
    )
end

"""SI conversion from raw eV/Angstrom kernels and the shared model/domain measure.

Periodic BZ and slice values retain the original three-dimensional reference-cell
normalization. A selected Cartesian region retains its original domain fraction.
Response-layer sheet and effective-thickness conversions are not applied.
"""
function third_order_si_factors(model, jerk, cfg = nothing)
    charge=1.602176634e-19
    hbar=1.054571817e-34
    epsilon0=8.8541878128e-12
    volume=abs(det(model.lattice))
    measure_factor=1e-10/(cfg===nothing ? volume : abs(integration_cell_measure(cfg, model)))
    return jerk ? (2pi*charge^4/hbar^3*measure_factor,) :
           (charge^2/hbar*measure_factor, charge/epsilon0*measure_factor)
end

"""
Prepare third-order using the existing shared sampling scheduler, Fourier planner and MPI lanes.

The same response kernel serves BZ integration and planar densities. Lane ownership
is independent of thread/rank counts. The retained input model defines spin counting;
one electron per explicit model state is used, including spinor models.
"""
function prepare_third_order(
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
    adaptive=cfg.integration_algorithm isa HAdaptiveCubature
    adaptive_result=Ref{Any}(nothing)
    loaded = shared_sources === nothing ? load_runtime_model_and_sources(ctx, cfg) : shared_sources
    cleanup_workspaces = MatrixElementWorkspace[]
    cleaned = Ref(false)
    function cleanup!()
        cleaned[] && return nothing
        cleaned[] = true
        release_mixed_worker_buffers!(cleanup_workspaces; timing = true)
        shared_sources === nothing && release_runtime_storage!(loaded)
        return nothing
    end
    try
        model = loaded.model
        qualification = third_order_response_qualification(
            assess_response_qualification(loaded.manifest, ctx, cfg, specs),
        )
        progress_response_qualification!(qualification)
        comm = bundle_mpi_comm_world()
        rank = bundle_mpi_comm_rank(comm)
        ranks = bundle_mpi_comm_size(comm)
        workers = Threads.nthreads()
        options = something(cfg.third_order)
        jerk = spec.quantity == :jerk_current
        components =
            slice ? [Tuple(Int.(cfg.tensor_indices))] :
            isempty(options.components) ?
            (jerk ? JERK_CURRENT_COMPONENTS : THIRD_HARMONIC_COMPONENTS) :
            collect(options.components)
        plan = bundle_matrix_element_plan(specs, cfg)
        workspaces = [MatrixElementWorkspace(model, plan) for _ in 1:workers]
        append!(cleanup_workspaces, workspaces)
        count = model.num_orbitals
        response_workspaces =
            jerk ? [JerkCurrentGeometry(count) for _ in 1:workers] :
            [ThirdHarmonicWorkspace(count) for _ in 1:workers]
        occupations = [zeros(count) for _ in 1:workers]
        for workspace in workspaces
            fourier_timing_enabled() && enable_fourier_timing!(workspace)
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
        if fourier.grid !== nothing
            prepare_mixed_worker_buffers!(
                workspaces,
                model,
                fourier.grid;
                memory_limit_bytes = fourier.memory_limit_bytes,
            )
        end
        lanes = _deterministic_integral_lane_count(points)
        rows = slice ? points : length(cfg.photon_energies)
        buffers = [
            zeros(ComplexF64, rows, length(components), jerk ? 1 : 4, jerk ? 1 : 2, jerk ? 1 : 2) for _ in 1:(slice ? 1 : lanes)
        ]
        scratch = [
            zeros(
                ComplexF64,
                length(cfg.photon_energies),
                length(components),
                jerk ? 1 : 4,
                jerk ? 1 : 2,
                jerk ? 1 : 2,
            ) for _ in 1:workers
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
        factors = third_order_si_factors(model, jerk, cfg)
        diagnostic_buffers = [zeros(Int, 1) for _ in 1:lanes]
        gap_diagnostic_buffers = [zeros(2) for _ in 1:lanes]
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
            if jerk
                jerk_current_response!(
                    view(values,:,:,1,1,1),
                    response_workspaces[worker],
                    occupations[worker],
                    data,
                    cfg.photon_energies,
                    components;
                    fermi_energy = cfg.fermi_energy,
                    temperature = cfg.temperature,
                    broadening = cfg.broadening,
                    gaussian = cfg.broadening_type=="Gaussian",
                    regularization = cfg.denominator_regularization,
                    transition_window_factor = cfg.transition_window_factor,
                    band_window_size = cfg.band_window_size,
                    projection = options.projection,
                )
            else
                try
                    third_harmonic_response!(
                        values,
                        response_workspaces[worker],
                        data,
                        cfg.photon_energies,
                        components;
                        fermi_energy = cfg.fermi_energy,
                        temperature = cfg.temperature,
                        policy = options.frequency_policy,
                        eta_correction = options.eta_correction,
                        exact_occupations = options.exact_occupations,
                        formulation = options.formulation,
                    )
                catch exception
                    if exception isa ArgumentError &&
                       occursin("THG_UNRESOLVED_DEGENERACY", sprint(showerror, exception))
                        throw(
                            ArgumentError(
                                "$(sprint(showerror,exception)); fractional k=$(Tuple(point))",
                            ),
                        )
                    end
                    rethrow()
                end
            end
            all(isfinite, values) ||
                error("Nonfinite third-order response at fractional k $(Tuple(point))")
            return values
        end
        function record_point_diagnostics!(worker, lane)
            geometry = jerk ? response_workspaces[worker] : response_workspaces[worker].geometry
            diagnostic_buffers[lane] .+= geometry.diagnostics
            gap_diagnostic_buffers[lane][1]=max(
                gap_diagnostic_buffers[lane][1],
                inv(geometry.gap_diagnostics[1]),
            )
            gap_diagnostic_buffers[lane][2]=max(
                gap_diagnostic_buffers[lane][2],
                geometry.gap_diagnostics[2],
            )
            return nothing
        end
        point_evaluators = [
            ResponsePointEvaluator(
                point_value!,
                worker,
                (
                    shape = size(scratch[worker]),
                    prefactor = :raw_third_order_density,
                    arbitrary_k = fourier.grid === nothing,
                ),
            ) for worker in 1:workers
        ]
        function consume_point!(worker, index, lane, values)
            record_point_diagnostics!(worker, lane)
            if slice
                buffers[1][index, :, :, :, :] .= @view values[1, :, :, :, :]
            else
                buffers[lane] .+= values
            end
            done = Threads.atomic_add!(completed, 1) + 1
            if done == 1 || done % max(1, points ÷ 100) == 0
                bundle_debug_log(
                    lock,
                    "[kloop] third-order finished=$(done) full_grid_k_points=$(points) elapsed=$(time()-started)s",
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
        function execute_adaptive!(worker, index, lane)
            domain=response_integration_domain(cfg)
            function adaptive_units!(values)
                record_point_diagnostics!(worker, lane)
                for quantity in axes(values, 4)
                    values[:, :, :, quantity, :] .*= factors[quantity]
                end
                return values
            end
            evaluator = ResponseNodeEvaluator(
                point_evaluators[worker],
                domain,
                model;
                transform! = adaptive_units!,
            )
            adaptive_result[]=integrate_response_mpi(
                evaluator,
                domain,
                cfg.integration_algorithm;
                normalization = :domain_average,
            )
            return nothing
        end
        function finish!()
            result = zeros(
                ComplexF64,
                rows,
                length(components),
                jerk ? 1 : 4,
                jerk ? 1 : 2,
                jerk ? 1 : 2,
            )
            for buffer in buffers
                reduced = bundle_mpi_reduce_sum(buffer, 0, comm)
                rank == 0 && (result .+= reduced)
            end
            diagnostics = zeros(Int, 1)
            for buffer in diagnostic_buffers
                reduced = bundle_mpi_reduce_sum(buffer, 0, comm)
                rank==0 && (diagnostics .+= reduced)
            end
            gap_diagnostics=zeros(2)
            # Uniform lanes have one rank owner. Adaptive lane one collects
            # different nodes on every rank and therefore needs a maximum.
            for buffer in gap_diagnostic_buffers
                reduced=adaptive ? bundle_mpi_reduce_max(buffer, 0, comm) :
                        bundle_mpi_reduce_sum(buffer, 0, comm)
                rank==0 && (gap_diagnostics .= max.(gap_diagnostics, reduced))
            end
            outputs = String[]
            if rank == 0
                if adaptive
                    result .= adaptive_result[].value
                else
                    for quantity in axes(result, 4)
                        result[:, :, :, quantity, :] .*= factors[quantity] / (slice ? 1 : points)
                    end
                end
                response_diagnostics = (;
                    minimum_gap_ev = inv(gap_diagnostics[1]),
                    velocity_dipole_identity_max_abs = gap_diagnostics[2],
                    endpoint_protection_ev = 1e-12,
                    bare_rotation_protection_ev = 1e-7,
                    exact_gap_pairs = diagnostics[1],
                    regularization_ev = cfg.denominator_regularization,
                    prescription = "distribution_broadening",
                    occupation_derivative_mode = options.exact_occupations ? "fermi_dirac" :
                                                 "shg_gaussian",
                )
                if jerk
                    response_diagnostics = merge(
                        response_diagnostics,
                        (;
                            occupation_derivative_mode = "NOT_APPLICABLE",
                            occupation_policy = "core-fermi-dirac/1",
                        ),
                    )
                end
                outputs = write_third_order(
                    ctx.run_dir,
                    coordinates,
                    result,
                    components;
                    jerk,
                    projection = options.projection,
                    formulation = options.formulation,
                    response = options.response,
                    output = options.output,
                    digits = max(16, cfg.response_output_digits),
                    slice,
                    domain_metadata = integration_domain_metadata(cfg),
                    effective_dimension = integration_output_dimension(cfg),
                    diagnostics = response_diagnostics,
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
                [string(spec.quantity)],
                NamedTuple[],
                fourier_execution_summary(cfg, fourier, workspaces),
                NamedTuple(),
                NamedTuple(),
                runtime_replica_summary(loaded.replica_summary),
                qualification,
                runtime_model_geometry(model),
            )
        end
        units = response_access_units(
            points,
            rank,
            ranks;
            grid = fourier.grid,
            policy = :canonical_lanes,
        )
        prepared =
            adaptive ?
            PreparedResponseTask(
                [(1, 1, 1)],
                execute_adaptive!,
                finish!,
                cleanup!;
                point_evaluators,
            ) : PreparedResponseTask(units, execute_point!, finish!, cleanup!; point_evaluators)
        prepare_only && return prepared
        try
            execute_prepared_tasks!([prepared])
            return finish!()
        finally
            cleanup!()
        end
    catch
        cleanup!()
        rethrow()
    end
end
