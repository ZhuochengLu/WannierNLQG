
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
    progress_owner = true,
    shared_sources = nothing,
    mixed_memory_limit_bytes = mixed_fourier_memory_limit(),
)
    spec=only(specs);
    slice=spec.calculation==:kslice
    orbital=spec.quantity==:orbital_magnetization
    optical=spec.quantity==:linear_optical_response
    loaded=shared_sources===nothing ? load_runtime_model_and_sources(ctx, cfg) : shared_sources
    model=loaded.model
    qualification=assess_response_qualification(loaded.manifest, ctx, cfg, specs)
    progress_response_qualification!(qualification)
    if orbital && cfg.orbital_input_semantics!=:defined_finite_model
        loaded.orbital!==nothing ||
            error("ORBITAL_MATERIAL_COMPLETION_REQUIRED: a qualified operator bundle is required")
    end
    comm=bundle_mpi_comm_world();
    rank=bundle_mpi_comm_rank(comm);
    ranks=bundle_mpi_comm_size(comm)
    workers=Threads.nthreads()
    plan=bundle_matrix_element_plan(specs, cfg)
    workspaces=[MatrixElementWorkspace(model, plan) for _ in 1:workers]
    for workspace in workspaces
        prepare_real_space!(workspace, model)
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
    ) : _integral_k_grid(cfg.k_mesh)
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
    if fourier.grid!==nothing
        for workspace in workspaces
            enable_mixed_fourier!(
                workspace,
                model,
                fourier.grid;
                memory_limit_bytes = fourier.memory_limit_bytes,
            )
        end
    end
    components=slice ? [Tuple(Int.(cfg.tensor_indices))] :
               orbital ? [(a,) for a in 1:3] : [(a, b) for a in 1:3 for b in 1:3]
    energies=optical ? cfg.photon_energies : copy(cfg.fermi_energies)
    terms=orbital ? (:srocc, :cmocc, :total) : (:drude, :quantum_metric, :berry_curvature, :total)
    lanes=_deterministic_integral_lane_count(points)
    buffer_elements=(slice ? points : lanes)*length(energies)*length(components)*length(terms)
    16buffer_elements<=mixed_memory_limit_bytes || error(
        "SPECTRAL_RESPONSE_MEMORY_LIMIT: split the requested slice frequency axis across tasks",
    )
    buffers=[
        zeros(ComplexF64, slice ? points : 1, length(energies), length(components), length(terms))
        for _ in 1:(slice ? 1 : lanes)
    ]
    kpoints=[zeros(3) for _ in 1:workers]
    completion=finite_model_orbital_completion(model.num_orbitals)
    family=Val(spec.quantity);
    projector=spec.method==:projector
    progress_system_summary!(model);
    progress_task_start!(spec)
    progress_fourier_backend!(fourier_execution_summary(cfg, fourier, workspaces))
    function execute_point!(worker, index, lane)
        point=kpoints[worker]
        slice ? kslice_kpoint!(point, grid, index) : integral_kpoint!(point, grid, index)
        workspace=workspaces[worker]
        if fourier.grid!==nothing
            if slice
                i, j=kslice_indices(grid, index)
                begin_mixed_kpoint!(workspace, point, (i-1, j-1, 0))
            else
                begin_mixed_kpoint!(workspace, point)
            end
        end
        data=compute_kpoint!(workspace, model, point)
        geometry=spectral_response_geometry(data; gap_tolerance = cfg.spectral_gap_tolerance)
        if orbital && cfg.orbital_input_semantics==:defined_finite_model
            maximum(abs, geometry.curvature)<=1e-9 || error(
                "ORBITAL_FINITE_MODEL_NOT_FLAT: external geometry cannot be silently set to zero",
            )
        end
        point_completion=orbital && loaded.orbital!==nothing ?
                         orbital_completion(loaded.orbital, model, workspace) : completion
        value=evaluate_spectral_response(geometry, point_completion, cfg, family, projector)
        all(isfinite, value) || error("Nonfinite spectral response at point $index")
        target=buffers[slice ? 1 : lane];
        row=slice ? index : 1
        for term in eachindex(terms),
            (c, component) in enumerate(components),
            e in eachindex(energies)

            a=component[1];
            b=orbital ? 1 : component[2]
            target[row, e, c, term]+=value[e, a, b, term]
        end
        return nothing
    end
    function finish!()
        result=zeros(ComplexF64, size(first(buffers)))
        for buffer in buffers
            reduced=bundle_mpi_reduce_sum(buffer, 0, comm)
            rank==0 && (result .+= reduced)
        end
        outputs=String[]
        if rank==0
            volume=abs(det(model.lattice))*1e-30
            if !slice
                result ./= points
                !orbital && (result ./= volume)
            end
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
        )
    end
    function cleanup!()
        for workspace in workspaces
            disable_mixed_fourier!(workspace)
        end
        shared_sources===nothing && release_runtime_storage!(loaded)
        return nothing
    end
    units=NTuple{3, Int}[
        (index, index, lane) for lane in _local_deterministic_integral_lanes(lanes, rank, ranks) for
        index in _deterministic_integral_lane_range(points, lanes, lane)
    ]
    prepared=PreparedResponseTask(units, execute_point!, finish!, cleanup!)
    prepare_only && return prepared
    try
        execute_prepared_tasks!([prepared]);
        return finish!()
    finally
        cleanup!()
    end
end
