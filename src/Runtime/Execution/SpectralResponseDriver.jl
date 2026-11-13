# Only scheduling and owned response storage live here. The existing full
# Matrix/Projector geometry and the original deterministic lane sums are reused.
_spectral_block_route_plan(
    grid,
    points::Int,
    width::Int,
    rank::Int,
    ranks::Int,
    memory_limit_bytes::Int,
) = response_block_route_plan(Float64, grid, points, width, rank, ranks, memory_limit_bytes)

# Write each locally owned spectral point once into its declared send slot and tensor-lane order.
function _spectral_route_record!(route, index, value, energies, components, terms)
    slot=route.sendslots[index]
    slot>0 && !route.written[slot] || error("SPECTRAL_ROUTE_POINT_OWNERSHIP")
    ordinal=0
    for term in eachindex(terms), component in components, e in eachindex(energies)
        ordinal+=1
        route.sendvalues[(slot - 1) * route.width + ordinal]=value[
            e,
            component[1],
            component[2],
            term,
        ]
    end
    ordinal==route.width || error("SPECTRAL_ROUTE_RESPONSE_SHAPE")
    route.written[slot]=true
    return nothing
end

# Collectively reject missing spectral slots before exchanging and placing the response lanes.
function _spectral_route_finish!(route, buffers, points, lanes, energies, components, terms, comm)
    bundle_mpi_all_true(all(route.written), comm) || error("SPECTRAL_ROUTE_INCOMPLETE")
    bundle_mpi_exchange_responses!(
        route.sendvalues,
        route.sendcounts,
        route.recvvalues,
        route.recvcounts,
        comm,
    )
    bundle_mpi_all_true(all(isfinite, route.recvvalues), comm) || error("SPECTRAL_ROUTE_NONFINITE")
    for lane in route.local_lanes
        target=buffers[lane]
        for index in _deterministic_integral_lane_range(points, lanes, lane)
            slot=route.recvslots[index];
            ordinal=0
            for term in eachindex(terms), c in eachindex(components), e in eachindex(energies)
                ordinal+=1
                target[1, e, c, term]+=route.recvvalues[(slot - 1) * route.width + ordinal]
            end
        end
    end
    return nothing
end

"""Dispatch to independently owned physical kernels after interpolation; no formulas live here."""
function evaluate_spectral_response(geometry, completion, cfg, ::Val{:linear_transport}, projector)
    value=linear_transport_response(
        geometry;
        projector,
        fermi_energies = cfg.fermi_energies,
        temperature = cfg.temperature,
        gamma_intra_ev = cfg.gamma_intra_ev,
        gamma_inter_ev = cfg.gamma_inter_ev,
        fs_kind = cfg.fs_kind,
        eta_fs_ev = cfg.eta_fs_ev,
    )
    return ComplexF64.(value)
end

"""Evaluate the optical module with its complete frequency axis."""
function evaluate_spectral_response(
    geometry,
    completion,
    cfg,
    ::Val{:linear_optical_response},
    projector,
)
    return linear_optical_response(
        geometry,
        cfg.photon_energies;
        projector,
        fermi_energy = cfg.fermi_energy,
        temperature = cfg.temperature,
        gamma_intra_ev = cfg.gamma_intra_ev,
        gamma_inter_ev = cfg.gamma_inter_ev,
        fs_kind = cfg.fs_kind,
        eta_fs_ev = cfg.eta_fs_ev,
    )
end

"""Evaluate the static axial-vector module, without a photon-frequency parameter."""
function evaluate_spectral_response(
    geometry,
    completion,
    cfg,
    ::Val{:orbital_magnetization},
    projector,
)
    value=orbital_magnetization_response(
        geometry,
        completion;
        projector,
        denominator_regularization = cfg.denominator_regularization,
        fermi_energies = cfg.fermi_energies,
        temperature = cfg.temperature,
    )
    return reshape(ComplexF64.(value), length(cfg.fermi_energies), 3, 1, 3)
end

"""Prepare first-order tasks with existing deterministic Fourier/sampling/MPI execution.

Each task owns its response accumulators. BZ lane ordering is independent of
thread/rank counts. K-slice points retain all requested optical frequencies.
"""
function prepare_spectral_response(
    cfg,
    ctx,
    specs;
    prepare_only = false,
    block_local_order = false,
    progress_owner = true,
    shared_sources = nothing,
    mixed_memory_limit_bytes = mixed_fourier_memory_limit(),
)
    spec=only(specs);
    slice=spec.calculation==:kslice
    adaptive = cfg.integration_algorithm isa HAdaptiveCubature
    adaptive_result = Ref{Any}(nothing)
    orbital=spec.quantity==:orbital_magnetization
    intrinsic=spec.quantity==:intrinsic_ahc
    optical=spec.quantity==:linear_optical_response
    loaded=shared_sources===nothing ? load_runtime_model_and_sources(ctx, cfg) : shared_sources
    model=loaded.model
    qualification=assess_response_qualification(loaded.manifest, ctx, cfg, specs)
    progress_response_qualification!(qualification)
    if orbital && cfg.orbital_input_semantics!=:defined_finite_model
        loaded.orbital!==nothing ||
            error("ORBITAL_MATERIAL_COMPLETION_REQUIRED: a qualified operator bundle is required")
    end
    orbital &&
        model isa NonorthogonalLocalizedModel &&
        loaded.orbital!==nothing &&
        throw(ArgumentError("NONORTHOGONAL_MATERIAL_COMPLETION_UNSUPPORTED"))
    comm=bundle_mpi_comm_world();
    rank=bundle_mpi_comm_rank(comm);
    ranks=bundle_mpi_comm_size(comm)
    workers=Threads.nthreads()
    diagnose = fourier_timing_enabled()
    execution_diagnostics = diagnose ? PreparedExecutionDiagnostics() : nothing
    point_phase_seconds = zeros(Float64, 4, workers)
    finish_phase_seconds = zeros(Float64, 2)
    # Only the isolated orthogonal static AHC Mixed consumer needs curl rather
    # than complete position jets. Direct/Auto and all other consumers stay full.
    curl_only =
        intrinsic && model isa TightBindingModel && normalized_fourier_backend(cfg) == :mixed
    plan=bundle_matrix_element_plan(specs, cfg; curvature_curl_only = curl_only)
    workspaces=[MatrixElementWorkspace(model, plan) for _ in 1:workers]
    for workspace in workspaces
        prepare_real_space!(workspace, model)
        diagnose && enable_fourier_timing!(workspace)
    end
    grid=slice ?
         first(
        make_kslice_grid(
            collect(cfg.k_mesh),
            [1, 2],
            collect(cfg.kslice_origin),
            collect(cfg.kslice_vector_1),
            collect(cfg.kslice_vector_2),
        ),
    ) : _integral_k_grid(cfg, model)
    points=length(grid)
    builder=slice ?
            (
        (
            nd,
            nf,
        )->mixed_fourier_kslice_grid(
            model,
            cfg.k_mesh,
            collect(cfg.kslice_origin),
            collect(cfg.kslice_vector_1),
            collect(cfg.kslice_vector_2);
            nkdiv = nd,
            nkfft = nf,
        )
    ) : ((nd, nf)->mixed_fourier_grid(model, cfg.k_mesh; nkdiv = nd, nkfft = nf))
    fourier=build_fourier_execution_plan(
        cfg,
        specs,
        model,
        first(workspaces),
        ranks,
        workers,
        builder;
        rank_memory_limit_bytes = mixed_memory_limit_bytes,
    )
    components=slice ? [Tuple(Int.(cfg.tensor_indices))] :
               orbital ? [(a,) for a in 1:3] : [(a, b) for a in 1:3 for b in 1:3]
    energies=optical ? cfg.photon_energies : copy(cfg.fermi_energies)
    terms=intrinsic ? (:total,) :
          orbital ? (:srocc, :cmocc, :total) : (:drude, :quantum_metric, :berry_curvature, :total)
    lanes=adaptive ? 1 : _deterministic_integral_lane_count(points)
    buffer_elements=(slice ? points : lanes)*length(energies)*length(components)*length(terms)
    16buffer_elements<=mixed_memory_limit_bytes || error(
        "SPECTRAL_RESPONSE_MEMORY_LIMIT: split the requested slice frequency axis across tasks",
    )
    buffers=[
        zeros(ComplexF64, slice ? points : 1, length(energies), length(components), length(terms))
        for _ in 1:(slice ? 1 : lanes)
    ]
    # Batch only complete original reduction lanes. Interpolation order is block
    # major inside a batch; owned scalar responses are replayed in canonical lane/k
    # order. Pending values and FFT buffers share the old per-workspace envelope.
    max_lane_points = cld(points, lanes)
    # Hall returns Float64 values; only this real-valued family may use real
    # pending storage. Complex optical/orbital routes retain their original type.
    pending_eltype = spec.quantity in (:intrinsic_ahc, :linear_transport) ? Float64 : ComplexF64
    one_lane_bytes = WorkspacePlanning.checked_array_bytes(
        pending_eltype,
        (length(energies), length(components), length(terms), max_lane_points),
    )
    local_lanes = _local_deterministic_integral_lanes(lanes, rank, ranks)
    batch_lane_capacity =
        min(length(local_lanes), div(div(3fourier.memory_limit_bytes, 4), one_lane_bytes))
    pending_points = max_lane_points * batch_lane_capacity
    lane_shape = (length(energies), length(components), length(terms), pending_points)
    pending_bytes = WorkspacePlanning.checked_array_bytes(pending_eltype, lane_shape)
    minimum_fft_bytes =
        fourier.grid === nothing ? 0 :
        MatrixElements.mixed_fourier_buffer_estimate(
            fourier.grid,
            first(workspaces),
            model;
            memory_limit_bytes = fourier.memory_limit_bytes - pending_bytes,
        ).estimated_bytes
    use_lane_blocks =
        block_local_order &&
        !slice &&
        !orbital &&
        !optical &&
        fourier.grid !== nothing &&
        batch_lane_capacity > 0 &&
        minimum_fft_bytes <= fourier.memory_limit_bytes - pending_bytes
    # A whole-block evaluator returns each real response to its original lane
    # owner before any sum. Different worker counts or budgets collectively keep
    # the existing route; no block partial sum replaces the physical-index order.
    route = nothing
    route_family = intrinsic && curl_only && ranks > 1
    if route_family
        local_route =
            workers == 1 && use_lane_blocks && model.position_r isa PackedCartesianOperator{1, 4} ?
            _spectral_block_route_plan(
                fourier.grid,
                points,
                length(energies)*length(components)*length(terms),
                rank,
                ranks,
                div(3fourier.memory_limit_bytes, 4),
            ) : nothing
        route_ok = local_route !== nothing
        if route_ok
            remaining = fourier.memory_limit_bytes-local_route.reserved_bytes
            route_ok =
                MatrixElements.mixed_fourier_buffer_estimate(
                    fourier.grid,
                    first(workspaces),
                    model;
                    memory_limit_bytes = remaining,
                ).estimated_bytes <= remaining
        end
        if bundle_mpi_all_true(route_ok, comm)
            route = local_route
            use_lane_blocks = false
        end
    end
    units = NTuple{3, Int}[]
    point_order = nothing
    point_slots = Dict{Int, Int}()
    batch_targets = Vector{Vector{Int}}()
    if route !== nothing
        for index in route.local_indices
            push!(units, (index, index, 1))
        end
        point_order = Dict(unit[1] => ordinal for (ordinal, unit) in enumerate(units))
    elseif use_lane_blocks
        block_points = mixed_block_access(fourier.grid, 0, 1).indices
        block_order = Dict(point => ordinal for (ordinal, point) in enumerate(block_points))
        for start in 1:batch_lane_capacity:length(local_lanes)
            batch = length(batch_targets) + 1
            targets = Int[]
            batch_units = NTuple{3, Int}[]
            for lane in local_lanes[start:min(start + batch_lane_capacity - 1, end)]
                for index in _deterministic_integral_lane_range(points, lanes, lane)
                    push!(targets, lane)
                    point_slots[index] = length(targets)
                    push!(batch_units, (index, index, batch))
                end
            end
            push!(batch_targets, targets)
            sort!(batch_units; by = unit -> block_order[unit[1]])
            append!(units, batch_units)
        end
        point_order = Dict(unit[1] => ordinal for (ordinal, unit) in enumerate(units))
    else
        for lane in local_lanes, index in _deterministic_integral_lane_range(points, lanes, lane)
            push!(units, (index, index, lane))
        end
    end
    pending = [
        Array{pending_eltype}(undef, use_lane_blocks ? lane_shape : (0, 0, 0, 0)) for _ in 1:workers
    ]
    pending_count = zeros(Int, workers)
    pending_lane = zeros(Int, workers)
    provider_limit =
        fourier.memory_limit_bytes -
        (route !== nothing ? route.reserved_bytes : use_lane_blocks ? pending_bytes : 0)
    if fourier.grid !== nothing
        prepare_mixed_worker_buffers!(
            workspaces,
            model,
            fourier.grid;
            memory_limit_bytes = provider_limit,
        )
    end
    traversal = Dict(
        "policy" =>
            route !== nothing ? "whole_block_evaluation_route_original_canonical_lanes" :
            use_lane_blocks ? "bounded_batch_block_evaluation_canonical_lane_sum" :
            "canonical_points",
        "whole_block_owner_route" => route !== nothing,
        "route_reserved_bytes" => route === nothing ? 0 : route.reserved_bytes,
        "route_send_bytes" => route === nothing ? 0 : sizeof(route.sendvalues),
        "route_receive_bytes" => route === nothing ? 0 : sizeof(route.recvvalues),
        "response_route_seconds" => 0.0,
        "canonical_lane_count" => lanes,
        "batch_lane_capacity" => use_lane_blocks ? batch_lane_capacity : 0,
        "batch_count" => length(batch_targets),
        "pending_bytes_per_worker" => use_lane_blocks ? pending_bytes : 0,
        "pending_value_type" => string(pending_eltype),
        "fft_limit_bytes_per_worker" => provider_limit,
        "worker_envelope_bytes" => fourier.memory_limit_bytes,
        "sums_preserve_original_point_order" => true,
    )
    kpoints=[zeros(3) for _ in 1:workers]
    completion=finite_model_orbital_completion(model.num_orbitals)
    family=Val(spec.quantity);
    projector=spec.method==:projector
    progress_system_summary!(model);
    progress_task_start!(spec)
    progress_fourier_backend!(fourier_execution_summary(cfg, fourier, workspaces))
    function point_value!(worker, point)
        workspace = workspaces[worker]
        phase_t0 = diagnose ? time_ns() : UInt64(0)
        data=intrinsic ? nothing : compute_kpoint!(workspace, model, point)
        diagnose && (point_phase_seconds[1, worker] += (time_ns() - phase_t0) * 1e-9)
        phase_t0 = diagnose ? time_ns() : UInt64(0)
        geometry = if intrinsic
            MatrixElements.prepare_intrinsic_hall_geometry!(workspace, model, point)
        else
            spectral_response_geometry(data; gap_tolerance = orbital ? 0.0 : cfg.spectral_gap_tolerance)
        end
        diagnose && (point_phase_seconds[2, worker] += (time_ns() - phase_t0) * 1e-9)
        if orbital && cfg.orbital_input_semantics==:defined_finite_model
            maximum(abs, geometry.curvature)<=1e-9 || error(
                "ORBITAL_FINITE_MODEL_NOT_FLAT: external geometry cannot be silently set to zero",
            )
        end
        point_completion=orbital && loaded.orbital!==nothing ?
                         orbital_completion(loaded.orbital, model, workspace) : completion
        phase_t0 = diagnose ? time_ns() : UInt64(0)
        value = if intrinsic
            berry=intrinsic_hall_fermi_sea(
                geometry,
                cfg.fermi_energies;
                method = projector ? :Projector : :Matrix,
                temperature = cfg.temperature,
            )
            reshape(
                (-Responses.RESPONSE_CHARGE_C^2/Responses.RESPONSE_HBAR_JS*1e-20) .* berry,
                length(cfg.fermi_energies),
                3,
                3,
                1,
            )
        else
            evaluate_spectral_response(geometry, point_completion, cfg, family, projector)
        end
        diagnose && (point_phase_seconds[3, worker] += (time_ns() - phase_t0) * 1e-9)
        all(isfinite, value) || error("Nonfinite spectral response at point $(Tuple(point))")
        return value
    end
    point_evaluators = [
        ResponsePointEvaluator(
            point_value!,
            worker,
            (
                shape = (length(energies), 3, orbital ? 1 : 3, length(terms)),
                prefactor = orbital ? :local_orbital_muB : :local_spectral_si_density,
                arbitrary_k = fourier.grid === nothing,
            ),
        ) for worker in 1:workers
    ]
    function consume_point!(worker, index, lane, value)
        phase_t0 = diagnose ? time_ns() : UInt64(0)
        if route !== nothing
            _spectral_route_record!(route, index, value, energies, components, terms)
        elseif use_lane_blocks
            targets = batch_targets[lane]
            if pending_count[worker] == 0
                pending_lane[worker] = lane
            end
            pending_lane[worker] == lane || error("SPECTRAL_PENDING_LANE_OWNERSHIP")
            ordinal = point_slots[index]
            for term in eachindex(terms),
                (c, component) in enumerate(components),
                e in eachindex(energies)

                pending[worker][e, c, term, ordinal] = value[e, component[1], component[2], term]
            end
            pending_count[worker] += 1
            if pending_count[worker] == length(targets)
                # Each canonical lane sees exactly its original ascending k adds.
                for point_ordinal in eachindex(targets)
                    target = buffers[targets[point_ordinal]]
                    for term in eachindex(terms),
                        c in eachindex(components),
                        e in eachindex(energies)

                        target[1, e, c, term] += pending[worker][e, c, term, point_ordinal]
                    end
                end
                pending_count[worker] = 0
            end
        else
            target=buffers[slice ? 1 : lane];
            row=slice ? index : 1
            for term in eachindex(terms),
                (c, component) in enumerate(components),
                e in eachindex(energies)

                a=component[1];
                b=orbital ? 1 : component[2]
                target[row, e, c, term]+=value[e, a, b, term]
            end
        end
        diagnose && (point_phase_seconds[4, worker] += (time_ns() - phase_t0) * 1e-9)
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
        domain = response_integration_domain(cfg)
        volume = abs(integration_cell_measure(cfg, model)) * 1e-30
        factor =
            orbital && cfg.integration_bounds !== nothing && integration_uses_reference_cell(cfg) ?
            abs(det(model.lattice)) / integration_cell_measure(cfg, model) :
            !orbital || cfg.integration_bounds !== nothing ? inv(volume) : 1.0
        function physical_units!(values)
            values .*= factor
            return values
        end
        evaluator = ResponseNodeEvaluator(
            point_evaluators[worker],
            domain,
            model;
            transform! = physical_units!,
        )
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
        all(iszero, pending_count) || error("SPECTRAL_PENDING_LANE_INCOMPLETE")
        if route !== nothing
            route_t0 = time_ns()
            _spectral_route_finish!(
                route,
                buffers,
                points,
                lanes,
                energies,
                components,
                terms,
                comm,
            )
            traversal["response_route_seconds"] = (time_ns()-route_t0)*1e-9
        end
        phase_t0 = diagnose ? time_ns() : UInt64(0)
        bundle_mpi_collective_call(; enabled = true, comm) do
            progress_localized_run_diagnostics!(workspaces, comm)
        end
        result=zeros(ComplexF64, size(first(buffers)))
        if adaptive
            if rank == 0
                values = adaptive_result[].value
                for term in eachindex(terms),
                    (c, component) in enumerate(components),
                    e in eachindex(energies)

                    b = orbital ? 1 : component[2]
                    result[1, e, c, term] = values[e, component[1], b, term]
                end
            end
        else
            for buffer in buffers
                reduced=bundle_mpi_reduce_sum(buffer, 0, comm)
                rank==0 && (result .+= reduced)
            end
        end
        diagnose && (finish_phase_seconds[1] = (time_ns() - phase_t0) * 1e-9)
        outputs=String[]
        if rank==0
            volume=abs(integration_cell_measure(cfg, model))*1e-30
            if !slice && !adaptive
                result ./= points
                if orbital &&
                   cfg.integration_bounds!==nothing &&
                   integration_uses_reference_cell(cfg)
                    result .*= abs(det(model.lattice))/integration_cell_measure(cfg, model)
                elseif !orbital || cfg.integration_bounds!==nothing
                    result ./= volume
                end
            end
            phase_t0 = diagnose ? time_ns() : UInt64(0)
            outputs=write_spectral_task_outputs(
                ctx,
                cfg,
                spec,
                grid,
                result,
                components,
                terms,
                volume;
                manifest = loaded.manifest,
                qualification,
                executed_points = adaptive ? adaptive_result[].evaluations : points,
            )
            adaptive && push!(
                outputs,
                write_response_integration_diagnostics(
                    ctx.run_dir,
                    adaptive_result[],
                    cfg.integration_algorithm,
                    cfg,
                ),
            )
            diagnose && (finish_phase_seconds[2] = (time_ns() - phase_t0) * 1e-9)
        end
        progress_task_done!(spec, outputs)
        if diagnose
            write_spectral_execution_diagnostics(
                ctx.run_dir,
                rank,
                points,
                workspaces,
                point_phase_seconds,
                finish_phase_seconds,
                execution_diagnostics,
                traversal,
            )
        end
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
    function cleanup!()
        release_mixed_worker_buffers!(workspaces; timing = diagnose)
        shared_sources===nothing && release_runtime_storage!(loaded)
        return nothing
    end
    prepared=PreparedResponseTask(
        adaptive ? [(1, 1, 1)] : units,
        adaptive ? execute_adaptive! : execute_point!,
        finish!,
        cleanup!,
        point_order,
        nothing,
        execution_diagnostics,
        point_evaluators,
    )
    prepare_only && return prepared
    try
        execute_prepared_tasks!([prepared]);
        return finish!()
    finally
        cleanup!()
    end
end

"""Write opt-in per-rank measurements without changing responses, ownership or reduction order.

Phase times overlap: matrix assembly includes pack/FFT/extraction; compilation is a
subset of the measured invocation. Allocation fields cover complete loop/finalization,
not separately sampled scalar kernels. Reports retain every worker's native counters.
"""
function write_spectral_execution_diagnostics(
    directory,
    rank,
    points,
    workspaces,
    point_seconds,
    finish_seconds,
    execution,
    traversal,
)
    workers = Dict{String, Any}[]
    for (index, workspace) in enumerate(workspaces)
        timing = fourier_timing_stats(workspace)
        mixed = timing.mixed
        row = Dict{String, Any}(
            "worker" => index,
            "matrix_wall_seconds" => point_seconds[1, index],
            "geometry_wall_seconds" => point_seconds[2, index],
            "mu_scan_wall_seconds" => point_seconds[3, index],
            "accumulation_wall_seconds" => point_seconds[4, index],
            "direct_calls" => timing.direct_calls,
            "direct_seconds" => timing.direct_seconds,
            "full_R_phase_calls" => timing.phase_calls,
            "full_R_phase_entries" => timing.phase_entries,
            "full_R_phase_seconds" => timing.phase_seconds,
        )
        if mixed !== nothing
            for key in propertynames(mixed)
                value = getproperty(mixed, key)
                value isa Real && (row["mixed_" * string(key)] = value)
            end
        end
        push!(workers, row)
    end
    shared = [
        Dict(
            "scope" => "aggregate_of_all_workers_in_same_shared_invocation",
            "coexecuted_tasks" => execution.coexecuted_tasks,
            "generations" => execution.generations,
            "diagonalizations" => execution.diagonalizations,
            "fourier_evaluations" => execution.fourier_evaluations,
            "fourier_hits" => execution.fourier_hits,
            "spectrum_hits" => execution.spectrum_hits,
            "matrix_seconds" => execution.matrix_seconds,
            "eigensystem_seconds" => execution.eigensystem_seconds,
        ),
    ]
    record = Dict{String, Any}(
        "schema" => "wanniernlqg.spectral-execution-diagnostic/1",
        "rank" => rank,
        "total_grid_points" => points,
        "workers" => workers,
        "traversal" => traversal,
        "shared_interpolation" => shared,
        "point_loop" => Dict(
            "wall_seconds" => execution.wall_seconds,
            "allocated_bytes" => execution.allocated_bytes,
            "gc_seconds" => execution.gc_seconds,
            "compile_seconds" => execution.compile_seconds,
            "recompile_seconds" => execution.recompile_seconds,
        ),
        "finish" => Dict("scope" => "separate_reduction_and_native_write_wall_only"),
        "reduction_wall_seconds" => finish_seconds[1],
        "native_write_wall_seconds" => finish_seconds[2],
        "scope" => "instrumented_diagnosis_not_uninstrumented_performance; nested_phases_not_additive",
    )
    return write_task_input_file(joinpath(directory, "performance_rank_$(rank).toml"), record)
end
