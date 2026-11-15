"""Actual dimension and d-dimensional measure, independent of the three tensor axes."""
function berry_multipole_integration_measure(cfg, model)
    dimension = cfg.integration_bounds === nothing ? length(cfg.k_mesh) : integration_dimension(cfg)
    if native_direct_low_dimensional(cfg)
        # A strictly 1D physical model has zero Berry two-form. The same padded
        # three-axis kernel computes that zero; no transverse dynamics is added.
        cfg.integration_bounds === nothing && return 3, inv(abs(det(model.lattice)))
        # Same physical d-domain, now expressed per completed 3D reference cell.
        # The raw moment tensor and its adaptive error norm remain unchanged.
        return 3, inv(abs(integration_cell_measure(cfg, model)))
    end
    dimension in (2, 3) ||
        throw(ArgumentError("BCD/BCQ conductivity supports 2D sheet or 3D bulk integration"))
    if cfg.integration_bounds === nothing
        cell =
            dimension == 2 ? norm(cross(model.lattice[1, :], model.lattice[2, :])) :
            abs(det(model.lattice))
        isfinite(cell) && cell > 0 || throw(ArgumentError("invalid physical cell measure"))
        return dimension, inv(cell)
    end
    lower, upper = cfg.integration_bounds
    measure =
        cfg.integration_affine_region === nothing ?
        prod(upper[axis] - lower[axis] for axis in 1:3 if upper[axis] > lower[axis]) :
        cfg.integration_affine_region.measure
    isfinite(measure) && measure > 0 ||
        throw(ArgumentError("invalid Cartesian integration measure"))
    return dimension, measure / (2pi)^dimension
end

const BERRY_MULTIPOLE_FINITE_REGION_WARNING = "\u6709\u9650\u533a\u57df\u79ef\u5206；\u672a\u5305\u542b\u8fb9\u754c\u4fee\u6b63，\u4e0d\u4fdd\u8bc1\u4e0d\u540c\u5206\u90e8\u79ef\u5206\u8868\u8fbe\u5728\u8be5\u533a\u57df\u5185\u76f8\u7b49。\u8bf7\u8bc4\u4f30\u622a\u65ad\u53ca\u533a\u57df\u5916\u8d21\u732e。"

"""BCD/BCQ consumer of the existing scheduler, cubature, MPI and ownership ports."""
function prepare_berry_multipole(
    cfg,
    ctx,
    specs;
    prepare_only = false,
    progress_owner = true,
    shared_sources = nothing,
    mixed_memory_limit_bytes = mixed_fourier_memory_limit(),
)
    spec = only(specs)
    settings = something(cfg.berry_multipole)
    parameters = settings.parameters
    tensor_plan = berry_multipole_tensor_plan(settings)
    slice = spec.calculation == :kslice
    adaptive = cfg.integration_algorithm isa HAdaptiveCubature
    loaded = shared_sources === nothing ? load_runtime_model_and_sources(ctx, cfg) : shared_sources
    matrix_workers = MatrixElementWorkspace[]
    cleaned = Ref(false)
    function cleanup!()
        cleaned[] && return nothing
        cleaned[] = true
        release_mixed_worker_buffers!(matrix_workers; timing = true)
        shared_sources === nothing && release_runtime_storage!(loaded)
        return nothing
    end
    try
        model = loaded.model
        model isa Union{TightBindingModel, AnalyticKModel} ||
            throw(ArgumentError("orthogonal BCD/BCQ model required"))
        # Slice values carry a local SI density, with no physical integration dimension
        # or lattice/plane measure applied. Three Cartesian tensor axes are retained.
        dimension, measure = slice ? (3, 1.0) : berry_multipole_integration_measure(cfg, model)
        comm = bundle_mpi_comm_world()
        rank, ranks = bundle_mpi_comm_rank(comm), bundle_mpi_comm_size(comm)
        workers = Threads.nthreads()
        if model isa AnalyticKModel && cfg.derivative_backend != :finite_difference
            maximum_order = settings.local_derivative_order + 1
            for order in 1:maximum_order
                MatrixElements.geometry_hamiltonian_derivative_source(model.input, order)
                MatrixElements.geometry_position_derivative_source(model.input, order)
            end
        end
        qualification = assess_response_qualification(loaded.manifest, ctx, cfg, specs)
        progress_response_qualification!(qualification)
        plan = bundle_matrix_element_plan(specs, cfg)
        batches =
            [KPointBatchWorkspace(model, plan, KPointOffset[KPointOffset()]) for _ in 1:workers]
        append!(matrix_workers, [batch.matrix_elements for batch in batches])
        for worker in matrix_workers
            prepare_real_space!(worker, model)
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
        fourier = build_fourier_execution_plan(
            cfg,
            specs,
            model,
            first(matrix_workers),
            ranks,
            workers,
            (nd, nf) -> mixed_fourier_grid(model, cfg.k_mesh; nkdiv = nd, nkfft = nf);
            rank_memory_limit_bytes = mixed_memory_limit_bytes,
        )
        fourier.grid === nothing ||
            throw(ArgumentError("BCD/BCQ first scope requires Direct; no implicit provider switch"))
        geometry_bytes =
            plan.geometry_derivatives === nothing ? 0 :
            MatrixElements.orthogonal_geometry_storage_bytes(
                model.num_orbitals,
                plan.geometry_derivatives,
            )
        # Count declared new storage through the maintained ESKernel mechanism.
        # Response contraction temporaries and callback/AD/native/compiler
        # storage remain outside this retained-array estimate and RSS-guarded.
        planning = WorkspacePlanning
        lanes = adaptive || slice ? 1 : _deterministic_integral_lane_count(points)
        local_components =
            Responses.berry_multipole_local_components(tensor_plan, settings.local_derivative_order)
        envelope = planning.workspace_envelope(
            (
                Base.checked_mul(workers, geometry_bytes),
                planning.checked_array_bytes(
                    Float64,
                    (workers, model.num_orbitals, length(local_components) + 4),
                ),
                planning.checked_array_bytes(
                    Float64,
                    (
                        lanes + workers + 1,
                        length(cfg.fermi_energies),
                        length(tensor_plan.moment_components),
                    ),
                ),
                planning.checked_array_bytes(
                    Float64,
                    (
                        slice ? points : 0,
                        length(cfg.fermi_energies),
                        2length(tensor_plan.moment_components) + length(tensor_plan.components),
                    ),
                ),
            ),
            ();
            limit_bytes = mixed_memory_limit_bytes,
            native_bytes_known = false,
        )
        offsets =
            cfg.derivative_backend == :finite_difference ?
            finite_difference_step_matrix(model, cfg.finite_difference_step) : zeros(3, 3)
        geometry_workers = [
            Responses.make_berry_multipole_geometry(
                matrix_workers[i],
                batches[i],
                tensor_plan,
                settings.local_derivative_order;
                surface = parameters.integral_form == :fermi_surface,
                derivative_backend = cfg.derivative_backend,
                finite_difference_vectors = offsets,
                gap_tolerance = cfg.degeneracy_threshold,
            ) for i in 1:workers
        ]
        buffers = [
            zeros(length(cfg.fermi_energies), length(tensor_plan.moment_components)) for
            _ in 1:lanes
        ]
        scratch = [similar(first(buffers)) for _ in 1:workers]
        slice_values = zeros(
            slice ? points : 0,
            length(cfg.fermi_energies),
            length(tensor_plan.moment_components),
        )
        kpoints = [zeros(3) for _ in 1:workers]
        worker_errors = Union{Nothing, Exception}[nothing for _ in 1:workers]
        adaptive_result = Ref{Any}(nothing)
        progress_system_summary!(model)
        progress_task_start!(spec)
        progress_fourier_backend!(fourier_execution_summary(cfg, fourier, matrix_workers))
        cfg.integration_bounds === nothing || runtime_notice(BERRY_MULTIPOLE_FINITE_REGION_WARNING)
        function point_value!(worker, point)
            try
                Responses.prepare_berry_multipole_geometry!(
                    geometry_workers[worker],
                    model,
                    point;
                    denominator_regularization = cfg.denominator_regularization,
                    gap_tolerance = cfg.degeneracy_threshold,
                    finite_difference_step = cfg.finite_difference_step,
                )
                return Responses.berry_multipole_moments!(
                    scratch[worker],
                    geometry_workers[worker],
                    cfg.fermi_energies,
                    parameters,
                )
            catch exception
                throw(
                    ArgumentError(
                        "BCD/BCQ point $(Tuple(point)) failed: $(sprint(showerror, exception))",
                    ),
                )
            end
        end
        point_evaluators = [
            ResponsePointEvaluator(
                point_value!,
                worker,
                (
                    shape = size(scratch[worker]),
                    prefactor = :raw_berry_multipole_moment,
                    arbitrary_k = fourier.grid === nothing,
                ),
            ) for worker in 1:workers
        ]
        function consume_point!(worker, index, lane, value)
            if slice
                slice_values[index, :, :] .= value
            else
                buffers[lane] .+= value
            end
            return nothing
        end
        grid_consumer = ResponseGridConsumer(
            point_evaluators,
            grid,
            kpoints,
            slice ? kslice_kpoint! : integral_kpoint!,
            response_grid_request(matrix_workers, fourier.grid, grid, slice),
            consume_point!,
        )
        function execute_point!(worker, index, lane)
            worker_errors[worker] === nothing || return nothing
            try
                grid_consumer(worker, index, lane)
            catch exception
                # A failing owner must not strand peers inside the subsequent
                # reduction. Keep the actual error, skip this failed worker's
                # remaining visits, and reject collectively before any output.
                # No placeholder contribution is published as a valid result.
                worker_errors[worker] = exception
            end
            return nothing
        end
        function execute_adaptive!(worker, index, lane)
            domain = response_integration_domain(cfg)
            evaluator = ResponseNodeEvaluator(point_evaluators[worker], domain, model)
            adaptive_result[] = integrate_response_mpi(
                evaluator,
                domain,
                cfg.integration_algorithm;
                normalization = :domain_average,
                comm,
            )
            return nothing
        end
        function finish!()
            for owner in 0:(ranks - 1)
                bundle_mpi_root_call(; root = owner, comm) do
                    failure = findfirst(error -> error !== nothing, worker_errors)
                    failure === nothing || throw(worker_errors[failure])
                    nothing
                end
            end
            moments =
                slice ? bundle_mpi_reduce_sum(slice_values, 0, comm) : zeros(size(first(buffers)))
            if slice
                nothing
            elseif adaptive
                rank == 0 && (moments .= adaptive_result[].value)
            else
                for buffer in buffers
                    reduced = bundle_mpi_reduce_sum(buffer, 0, comm)
                    rank == 0 && (moments .+= reduced)
                end
                rank == 0 && (moments ./= points)
            end
            gaps = zeros(Float64, ranks)
            gaps[rank + 1] = minimum(workspace.minimum_gap_ev for workspace in geometry_workers)
            global_gaps = bundle_mpi_reduce_sum(gaps, 0, comm)
            outputs = String[]
            if rank == 0
                slice || (moments .*= measure)
                conductivity = if slice
                    density = zeros(points, length(cfg.fermi_energies), length(tensor_plan.components))
                    for index in 1:points
                        # Reuse the original field/current contraction and SI multiplier.
                        # Its bulk factor expects an A^-3 integrated moment. Multiplying
                        # by m^3 converts the raw local moment to the SI k-density;
                        # no cell, slice area, mesh divisor or (2pi)^-d enters here.
                        density[index, :, :] .=
                            Responses.berry_multipole_dc_components(
                                view(moments,index,:,:),
                                tensor_plan,
                                parameters;
                                spatial_dimension = 3,
                            ) .* 1e-30
                    end
                    density
                else
                    Responses.berry_multipole_dc_components(
                        moments,
                        tensor_plan,
                        parameters;
                        spatial_dimension = dimension,
                    )
                end
                tensor_rank = length(first(tensor_plan.components))
                moment_unit =
                    tensor_rank == 3 ? (dimension == 3 ? "dimensionless" : "Angstrom") :
                    (dimension == 3 ? "Angstrom" : "Angstrom^2")
                conductivity_unit =
                    tensor_rank == 3 ? (dimension == 3 ? "A/V^2" : "A*m/V^2") :
                    (dimension == 3 ? "A*m/V^3" : "A*m^2/V^3")
                minimum_gap = minimum(global_gaps)
                metadata = merge(
                    integration_domain_metadata(cfg),
                    (;
                        integral_form = parameters.integral_form,
                        derivative_backend_requested = cfg.derivative_backend_was_explicit ?
                                                       cfg.derivative_backend : "not specified",
                        derivative_backend_effective = cfg.derivative_backend,
                        temperature_k = cfg.temperature,
                        relaxation_time_fs = parameters.relaxation_time_fs,
                        fs_kind = parameters.integral_form == :fermi_sea ? "not applicable" :
                                  cfg.temperature > 0 ? "thermal Fermi-Dirac" : "gaussian",
                        eta_fs_ev = parameters.eta_fs_ev === nothing ? "not applicable" :
                                    parameters.eta_fs_ev,
                        denominator_regularization_ev = cfg.denominator_regularization,
                        finite_difference_step_A_inverse = cfg.derivative_backend ==
                                                           :finite_difference ?
                                                           cfg.finite_difference_step :
                                                           "not applicable",
                        raw_hamiltonian_derivative_source = model isa AnalyticKModel ?
                                                            (
                            cfg.derivative_backend == :finite_difference ?
                            "existing raw-source resolver; explicit H1=$(model.input.derivatives[1] !== nothing); fallback=$(model.input.derivative_method)" :
                            string(
                                MatrixElements.geometry_hamiltonian_derivative_source(
                                    model.input,
                                    settings.local_derivative_order + 1,
                                ),
                            )
                        ) : "exact real-space Fourier derivative",
                        raw_position_derivative_source = model isa AnalyticKModel ?
                                                         (
                            cfg.derivative_backend == :finite_difference ?
                            "existing raw-source resolver; explicit A1=$(haskey(model.input.operators, :position_derivative)); basis=$(model.input.basis); fallback=$(model.input.derivative_method)" :
                            string(
                                MatrixElements.geometry_position_derivative_source(
                                    model.input,
                                    settings.local_derivative_order + 1,
                                ),
                            )
                        ) : "exact real-space Fourier derivative",
                        minimum_gap_ev = isfinite(minimum_gap) ? minimum_gap :
                                         "no complementary band",
                        isolation_threshold_ev = cfg.degeneracy_threshold,
                        spin_counting = "one contribution per explicit state; no extra factor two",
                        band_selection = "all explicit isolated bands; no occupation-based isolation exemption",
                        curvature_input_semantics = "full orthogonal H and declared position connection; no omitted-operator zero substitution",
                        model_periodicity = model isa AnalyticKModel ? model.input.periodic : true,
                        parent_metadata_file = joinpath(ctx.run_dir, "metadata.txt"),
                        physical_integration_dimension = native_direct_low_dimensional(cfg) ?
                                                         native_physical_dimension(
                            cfg.native_model_input,
                        ) : dimension,
                        response_measure = dimension == 2 ? "sheet" : "bulk",
                        integration_average_to_measure_factor = measure,
                        boundary_corrections = "not included",
                        finite_region_warning = cfg.integration_bounds === nothing ?
                                                "not applicable (complete periodic grid)" :
                                                BERRY_MULTIPOLE_FINITE_REGION_WARNING,
                        executed_points = adaptive ? adaptive_result[].evaluations : points,
                        declared_buffer_bytes = envelope.total_bytes,
                        buffer_estimate_scope = "known retained arrays only; contraction temporaries, AD, native and compiler storage excluded; process RSS guard retained",
                        native_and_AD_storage_in_estimate = "unknown; separate process RSS guard retained",
                    ),
                )
                stem = ctx.system_name * (tensor_rank == 3 ? "_bcdc" : "_bcqc")
                if slice
                    metadata = merge(
                        metadata,
                        (;
                            scope = "unweighted local conductivity k-density",
                            physical_integration_dimension = "not applied",
                            response_measure = "local SI density; no sheet/bulk normalization",
                            integration_average_to_measure_factor = "not applied",
                            coordinates = "reciprocal fractional kx ky kz",
                            integration_contract = "integrate with d^d k_SI/(2pi)^d, or average full periodic fractional grid then divide by physical cell measure in m^d",
                            local_expression_contract = "selected FS or sea expression; no pointwise integration-by-parts equivalence claimed",
                            moment_unit = tensor_rank == 3 ? "Angstrom^3" : "Angstrom^4",
                        ),
                    )
                    coordinates = zeros(points, 3)
                    point = zeros(3)
                    for index in 1:points
                        kslice_kpoint!(point, grid, index)
                        coordinates[index, :] .= point
                    end
                    append!(
                        outputs,
                        write_berry_multipole_kslice(
                            ctx.run_dir,
                            stem * "k",
                            coordinates,
                            cfg.fermi_energies,
                            cfg.temperature,
                            parameters.relaxation_time_fs,
                            moments,
                            tensor_plan.moment_components,
                            conductivity,
                            tensor_plan.components;
                            moment_unit = tensor_rank == 3 ? "Angstrom^3" : "Angstrom^4",
                            conductivity_unit = tensor_rank == 3 ? "A*m^3/V^2 k_integrand" :
                                                "A*m^4/V^3 k_integrand",
                            metadata,
                            digits = resolved_response_output_digits(cfg),
                        ),
                    )
                else
                    append!(
                        outputs,
                        write_berry_multipole_dc(
                            ctx.run_dir,
                            stem,
                            cfg.fermi_energies,
                            cfg.temperature,
                            parameters.relaxation_time_fs,
                            moments,
                            tensor_plan.moment_components,
                            conductivity,
                            tensor_plan.components;
                            moment_unit,
                            conductivity_unit,
                            metadata,
                            digits = resolved_response_output_digits(cfg),
                        ),
                    )
                end
                adaptive && push!(
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
                fourier_execution_summary(cfg, fourier, matrix_workers),
                NamedTuple(),
                NamedTuple(),
                runtime_replica_summary(loaded.replica_summary),
                qualification,
                runtime_model_geometry(model),
            )
        end
        units =
            adaptive ? [(1, 1, 1)] :
            response_access_units(points, rank, ranks; policy = :canonical_lanes)
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
    catch
        cleanup!()
        rethrow()
    end
end
