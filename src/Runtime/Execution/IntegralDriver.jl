# Load model sources, allocate shared worker workspaces, execute deterministic integral lanes, reduce and write the task bundle.
function _run_integral_bundle_fused!(
    cfg::EffectiveTaskConfig,
    ctx::RunContext,
    specs::Vector{NormalizedTaskSpec},
    controls::NormalizedRunControls;
    prepare_only::Bool = false,
    block_local_order::Bool = false,
    progress_owner::Bool = true,
    shared_sources = nothing,
    mixed_memory_limit_bytes::Int = mixed_fourier_memory_limit(),
)
    if any(spec -> spec.quantity in BERRY_MULTIPOLE_QUANTITIES, specs)
        return prepare_berry_multipole(
            cfg,
            ctx,
            specs;
            prepare_only,
            progress_owner,
            shared_sources,
            mixed_memory_limit_bytes,
        )
    end
    if any(spec->spec.quantity in SPECTRAL_RESPONSE_QUANTITIES, specs)
        return prepare_spectral_response(
            cfg,
            ctx,
            specs;
            prepare_only,
            block_local_order,
            progress_owner,
            shared_sources,
            mixed_memory_limit_bytes,
        )
    end
    if any(spec -> spec.quantity in (:jerk_current, :third_harmonic_generation), specs)
        return prepare_third_order(
            cfg,
            ctx,
            specs;
            prepare_only,
            progress_owner,
            shared_sources,
            mixed_memory_limit_bytes,
        )
    end
    if any(spec -> spec.quantity == :second_harmonic_generation, specs)
        return prepare_second_harmonic(
            cfg,
            ctx,
            specs;
            prepare_only,
            progress_owner,
            shared_sources,
            mixed_memory_limit_bytes,
        )
    end
    cleanup_workspaces = MatrixElementWorkspace[]
    loaded_sources_ref = Ref{Any}(nothing)
    cleaned = Ref(false)
    function cleanup!()
        cleaned[] && return nothing
        cleaned[] = true
        release_mixed_worker_buffers!(cleanup_workspaces; timing = true)
        if shared_sources === nothing && loaded_sources_ref[] !== nothing
            release_runtime_storage!(loaded_sources_ref[])
        end
        return nothing
    end
    try
        return _run_integral_bundle_owned!(
            cfg,
            ctx,
            specs,
            controls;
            prepare_only = prepare_only,
            block_local_order = block_local_order,
            progress_owner = progress_owner,
            shared_sources = shared_sources,
            mixed_memory_limit_bytes = mixed_memory_limit_bytes,
            cleanup_workspaces = cleanup_workspaces,
            loaded_sources_ref = loaded_sources_ref,
            cleanup! = cleanup!,
        )
    catch
        cleanup!()
        rethrow()
    end
end

# Prepare private task state under the caller's idempotent resource cleanup boundary.
function _run_integral_bundle_owned!(
    cfg::EffectiveTaskConfig,
    ctx::RunContext,
    specs::Vector{NormalizedTaskSpec},
    controls::NormalizedRunControls;
    cleanup_workspaces,
    loaded_sources_ref,
    cleanup!,
    prepare_only::Bool = false,
    block_local_order::Bool = false,
    progress_owner::Bool = true,
    shared_sources = nothing,
    mixed_memory_limit_bytes::Int = mixed_fourier_memory_limit(),
)
    adaptive = cfg.integration_algorithm isa HAdaptiveCubature
    adaptive_result = Ref{Any}(nothing)
    debug_lock = ReentrantLock()
    total_t0 = time()
    progress_percent_interval = effective_progress_percent_interval(cfg)
    slow_k_seconds = env_float("WANNIERNLQG_SLOW_K_SECONDS", 10.0)
    families = bundle_matrix_families(specs, cfg)
    counters = _family_counter_map(families)

    if nonzero_photon_momentum(cfg.photon_momentum) && any(
        spec -> spec.quantity == :shift_current && spec.method in (:geometric_loop, :wilson_loop),
        specs,
    )
        runtime_notice(
            "photon_momentum=$(cfg.photon_momentum) is ignored for ordinary Shift_Current Geometric_Loop/Wilson_Loop fused tasks.",
        )
    end

    bundle_mpi_initialize()
    comm = bundle_mpi_comm_world()
    rank = bundle_mpi_comm_rank(comm)
    size = bundle_mpi_comm_size(comm)
    root = 0

    bundle_debug_log(
        debug_lock,
        "[setup] fused integral bundle start tasks=$([spec.label for spec in specs])",
    )
    bundle_debug_log(
        debug_lock,
        "[setup] execution_mode=fused_kloop MPI enabled=$(BUNDLE_MPI_CONTEXT.has_mpi) ranks=$(size) threads=$(Threads.nthreads())",
    )
    read_t0 = time()
    bundle_debug_log(debug_lock, "[read] start load_runtime_model_and_sources")
    loaded_sources =
        shared_sources === nothing ? load_runtime_model_and_sources(ctx, cfg) : shared_sources
    cfg.photon_momentum_path !== nothing &&
        shared_sources === nothing &&
        (loaded_sources = freeze_paired_runtime_sources(loaded_sources))
    loaded_sources_ref[] = loaded_sources
    model = loaded_sources.model
    spin_real_space = loaded_sources.spin
    spin_velocity_real_space = loaded_sources.spin_velocity
    derivative_overlap_real_space = loaded_sources.derivative_overlap
    spin_velocity_real_space === nothing || GC.gc(true)
    bundle_debug_log(
        debug_lock,
        "[read] end load_runtime_model_and_sources mode=$(loaded_sources.read_mode) elapsed=$(format_seconds(time() - read_t0))s",
    )
    progress_system_summary!(model)
    response_symmetry_plan =
        cfg.integration_bounds===nothing && !adaptive ?
        prepare_response_symmetry_execution_plan(cfg, ctx, specs, comm) : nothing
    response_symmetry_plan === nothing ||
        progress_response_symmetry!(response_symmetry_metadata(response_symmetry_plan))
    qualification = assess_response_qualification(
        loaded_sources.manifest,
        ctx,
        cfg,
        specs;
        response_symmetry_plan,
    )
    progress_response_qualification!(qualification)
    numerical_response_symmetry_plan =
        response_symmetry_plan === nothing || response_symmetry_plan.explanation_only ? nothing :
        response_symmetry_plan

    cell_volume = integration_cell_measure(cfg, model)
    num_r_vectors = model.num_r_vectors
    num_orbitals = model.num_orbitals
    spatial_dimension = Int(cfg.spatial_dimension)
    num_kpoints = prod(cfg.k_mesh)
    num_evaluation_kpoints =
        numerical_response_symmetry_plan === nothing ? num_kpoints :
        length(numerical_response_symmetry_plan.representatives)
    num_photon_energies = length(cfg.photon_energies)
    num_workers = Threads.nthreads()
    default_thread_ids = Threads.threadpooltids(:default)
    length(default_thread_ids) == num_workers ||
        error("default thread-pool size changed while preparing integral workspaces")
    worker_index_by_thread_id = zeros(Int, maximum(default_thread_ids))
    for (worker_index, thread_id) in pairs(default_thread_ids)
        worker_index_by_thread_id[thread_id] = worker_index
    end
    block_local_requested =
        block_local_order &&
        cfg.integration_bounds === nothing &&
        cfg.fourier_backend == "mixed" &&
        cfg.NKdiv !== nothing &&
        cfg.NKFFT !== nothing &&
        numerical_response_symmetry_plan === nothing &&
        length(specs) == 1 &&
        only(specs).quantity == :shift_current &&
        only(specs).method == :conventional &&
        !nonzero_photon_momentum(cfg.photon_momentum)
    num_reduction_lanes =
        adaptive ? 1 :
        _deterministic_integral_lane_count(
            block_local_requested ? prod(cfg.NKdiv) : num_evaluation_kpoints,
        )
    shared_matrix_plan = bundle_matrix_element_plan(specs, cfg)
    matrix_sources = MatrixElementSources(
        spin = spin_velocity_real_space === nothing ? spin_real_space : nothing,
        spin_velocity = spin_velocity_real_space,
        derivative_overlap = derivative_overlap_real_space,
    )
    shared_matrix_batches = [
        KPointBatchWorkspace(
            model,
            shared_matrix_plan,
            KPointOffset[KPointOffset()],
            matrix_sources;
            spectral_gap_tolerance = cfg.spectral_gap_tolerance,
        ) for _ in 1:num_workers
    ]
    shared_matrix_workspaces = [batch.matrix_elements for batch in shared_matrix_batches]
    shared_central_data = [matrix_data!(batch, KPointOffset()) for batch in shared_matrix_batches]
    photon_shift_step =
        nonzero_photon_momentum(cfg.photon_momentum) || cfg.photon_momentum_path !== nothing ? 1 : 0

    k_grid = _integral_k_grid(cfg, model)
    states = [
        _make_integral_state(
            cfg,
            ctx,
            spec,
            num_reduction_lanes;
            response_symmetry_plan = numerical_response_symmetry_plan,
            num_scratch_workers = num_workers,
        ) for spec in specs
    ]

    point_elements =
        foldl(Base.checked_add, (length(state.local_data) for state in states); init = 0)
    # Check ordinary point scratch for size overflow. The Mixed limit bounds
    # Fourier caches, not Direct response scratch; process/RSS guards still apply.
    WorkspacePlanning.checked_array_bytes(ComplexF64, (2num_workers, point_elements))
    point_states = [response_point_state(state, num_workers) for state in states]
    sc_conv_state = _find_integral_point_state(point_states, :shift_current, :conventional, Val(4))
    ic_state = _find_integral_point_state(point_states, :injection_current, :conventional, Val(4))
    isc_state =
        _find_integral_point_state(point_states, :injection_spin_current, :conventional, Val(5))
    ssc_state = _find_integral_point_state(point_states, :shift_spin_current, :conventional, Val(5))
    sc_proj_state = _find_integral_point_state(point_states, :shift_current, :projector, Val(4))
    sc_geo_state = _find_integral_point_state(point_states, :shift_current, :geometric_loop, Val(4))
    pdsc_state = _find_integral_point_state(
        point_states,
        :photon_drag_shift_current,
        :geometric_loop,
        Val(4),
    )
    sc_wilson_state = _find_integral_point_state(point_states, :shift_current, :wilson_loop, Val(4))
    pdic_state = _find_integral_point_state(
        point_states,
        :photon_drag_injection_current,
        :conventional,
        Val(4),
    )

    need_conv =
        sc_conv_state !== nothing ||
        ic_state !== nothing ||
        isc_state !== nothing ||
        ssc_state !== nothing
    need_proj = sc_proj_state !== nothing
    need_geo_q0 = sc_geo_state !== nothing
    need_geo_q = pdsc_state !== nothing
    need_wilson = sc_wilson_state !== nothing
    need_pdic = pdic_state !== nothing
    need_transition_screen = need_conv || need_proj || need_geo_q0 || need_wilson
    need_photon_drag_transition_screen = need_geo_q || need_pdic
    paired_blocks =
        cfg.photon_momentum_path === nothing ? nothing :
        make_paired_photon_momentum_blocks(cfg, model, pdsc_state, pdic_state)
    if paired_blocks !== nothing
        all(
            spec -> spec.quantity in (:photon_drag_shift_current, :photon_drag_injection_current),
            specs,
        ) || error("paired photon momenta only apply to the declared photon-drag families")
        num_photon_energies = maximum(block -> length(block.config.photon_energies), paired_blocks)
    end
    paired_geometric_counter =
        need_geo_q && paired_blocks !== nothing ?
        counters["geometric_loop_shift_current_paired_q"] : nothing
    paired_injection_counter =
        need_pdic && paired_blocks !== nothing ?
        counters["conventional_finite_q_photon_drag_injection"] : nothing

    cal_band_projector = _effective_window_band_count(cfg.band_window_size, num_orbitals)
    cal_band_geometric = _effective_window_band_count(cfg.band_window_size, num_orbitals)
    cal_band_wilson = _effective_window_band_count(cfg.band_window_size, num_orbitals)

    transition_screen_workspaces =
        need_transition_screen ?
        [
            make_transition_screen_workspace(
                num_orbitals,
                num_r_vectors,
                num_photon_energies,
                matrix_elements = shared_matrix_workspaces[worker_id],
                central_data = shared_central_data[worker_id],
            ) for worker_id in 1:num_workers
        ] : TransitionScreenWorkspace[]
    photon_drag_transition_screen_workspaces =
        need_photon_drag_transition_screen ?
        [
            make_photon_drag_transition_screen_workspace(
                num_orbitals,
                num_r_vectors,
                num_photon_energies,
                matrix_elements = shared_matrix_workspaces[worker_id],
                valence_data = matrix_data!(
                    shared_matrix_batches[worker_id],
                    KPointOffset((0, 0, 0), -photon_shift_step),
                ),
                conduction_data = matrix_data!(
                    shared_matrix_batches[worker_id],
                    KPointOffset((0, 0, 0), photon_shift_step),
                ),
            ) for worker_id in 1:num_workers
        ] : PhotonDragTransitionScreenWorkspace[]
    conv_workspaces =
        need_conv ?
        _make_conventional_current_worker_workspaces(
            num_workers,
            num_orbitals,
            num_r_vectors,
            spatial_dimension,
            num_photon_energies,
            shared_matrix_workspaces,
            shared_central_data;
            shift_current_required = sc_conv_state !== nothing || isc_state === nothing,
            frequency_contraction_required = true,
        ) : ShiftCurrentConventionalWorkspace[]
    conv_injection_qg =
        ic_state !== nothing ?
        [
            zeros(
                ComplexF64,
                num_orbitals,
                num_orbitals,
                spatial_dimension,
                spatial_dimension,
                spatial_dimension,
            ) for _ in 1:num_workers
        ] : Array{ComplexF64, 5}[]
    conv_spin_injection_qg =
        isc_state !== nothing ?
        [
            zeros(
                ComplexF64,
                num_orbitals,
                num_orbitals,
                spatial_dimension,
                3,
                spatial_dimension,
                spatial_dimension,
            ) for _ in 1:num_workers
        ] : Array{ComplexF64, 6}[]
    shift_spin_current_workspaces =
        ssc_state !== nothing ?
        _make_conventional_shift_spin_worker_workspaces(
            num_workers,
            num_orbitals,
            num_r_vectors,
            spatial_dimension,
            num_photon_energies,
            shared_matrix_workspaces,
            shared_central_data;
            frequency_contraction_required = true,
        ) : ShiftSpinCurrentConventionalWorkspace[]
    projector_response_workspaces =
        need_proj ?
        [
            make_projector_response_workspace(
                num_orbitals,
                num_r_vectors,
                spatial_dimension,
                num_photon_energies,
                matrix_elements = shared_matrix_workspaces[worker_id],
                matrix_batch = shared_matrix_batches[worker_id],
                central_common = shared_central_data[worker_id],
            ) for worker_id in 1:num_workers
        ] : ProjectorResponseWorkspace[]
    geo_q0_workspaces =
        need_geo_q0 ?
        [
            make_geometric_loop_response_workspace(
                num_orbitals,
                num_r_vectors,
                spatial_dimension,
                num_photon_energies,
                matrix_elements = shared_matrix_workspaces[worker_id],
                matrix_batch = shared_matrix_batches[worker_id],
                valence_central_common = shared_central_data[worker_id],
                conduction_central_common = shared_central_data[worker_id],
            ) for worker_id in 1:num_workers
        ] : GeometricLoopResponseWorkspace[]
    geo_q_workspaces =
        need_geo_q ?
        [
            make_geometric_loop_response_workspace(
                num_orbitals,
                num_r_vectors,
                spatial_dimension,
                num_photon_energies,
                matrix_elements = shared_matrix_workspaces[worker_id],
                matrix_batch = shared_matrix_batches[worker_id],
                valence_central_common = photon_drag_transition_screen_workspaces[worker_id].valence_data,
                conduction_central_common = photon_drag_transition_screen_workspaces[worker_id].conduction_data,
            ) for worker_id in 1:num_workers
        ] : GeometricLoopResponseWorkspace[]
    wilson_loop_response_workspaces =
        need_wilson ?
        [
            make_wilson_loop_response_workspace(
                num_orbitals,
                num_r_vectors,
                spatial_dimension,
                num_photon_energies,
                matrix_elements = shared_matrix_workspaces[worker_id],
                matrix_batch = shared_matrix_batches[worker_id],
                central_common = shared_central_data[worker_id],
            ) for worker_id in 1:num_workers
        ] : WilsonLoopResponseWorkspace[]
    pdic_workspaces =
        need_pdic ?
        [
            make_photon_drag_injection_current_conventional_workspace(
                num_orbitals,
                num_r_vectors,
                spatial_dimension,
                num_photon_energies,
                photon_energies = paired_blocks === nothing ? cfg.photon_energies : nothing,
                denominator_regularization = cfg.denominator_regularization,
                matrix_elements = shared_matrix_workspaces[worker_id],
                valence_data = photon_drag_transition_screen_workspaces[worker_id].valence_data,
                conduction_data = photon_drag_transition_screen_workspaces[worker_id].conduction_data,
            ) for worker_id in 1:num_workers
        ] : PhotonDragInjectionCurrentConventionalWorkspace[]

    p_d_projector =
        need_proj ? finite_difference_step_matrix(model, cfg.finite_difference_step) :
        zeros(Float64, 3, 3)
    p_c = cfg.finite_difference_step * Matrix{Float64}(I, 3, 3)
    p_d_geo = zeros(Float64, 3, 3)
    for i in 1:3
        p_d_geo[:, i] = reciprocal_cartesian_to_fractional(p_c[:, i], model.lattice)
    end
    wc_d_geo = zeros(Float64, 3, num_orbitals)
    if need_geo_q0 || need_geo_q || need_wilson
        wc_c = extract_wannier_centers(model)
        for i in 1:num_orbitals
            wc_d_geo[:, i] = real_space_cartesian_to_fractional(wc_c[:, i], model.lattice)
        end
    end
    q_d_zero = reciprocal_cartesian_to_fractional(Float64[0.0, 0.0, 0.0], model.lattice)
    q_d_geo = reciprocal_cartesian_to_fractional(controls.photon_momentum, model.lattice)

    wc_d_pdic = zeros(Float64, 3, num_orbitals)
    q_d_pdic = reciprocal_cartesian_to_fractional(controls.photon_momentum, model.lattice)
    if need_pdic
        wc_c = extract_wannier_centers(model)
        for n in 1:num_orbitals
            wc_d_pdic[:, n] .= real_space_cartesian_to_fractional(wc_c[:, n], model.lattice)
        end
    end

    for worker_id in 1:num_workers
        push!(cleanup_workspaces, shared_matrix_workspaces[worker_id])
        prepare_real_space!(shared_matrix_workspaces[worker_id], model)
        fourier_timing_enabled() && enable_fourier_timing!(shared_matrix_workspaces[worker_id])
        if need_conv
            prepare_real_space!(conv_workspaces[worker_id].scratch, model)
        end
        if need_proj
            prepare_real_space!(projector_response_workspaces[worker_id].scratch, model)
        end
        if need_geo_q0
            prepare_real_space!(geo_q0_workspaces[worker_id].scratch, model)
        end
        if need_geo_q
            prepare_real_space!(geo_q_workspaces[worker_id].scratch, model)
        end
        if need_wilson
            prepare_real_space!(wilson_loop_response_workspaces[worker_id].scratch, model)
        end
        if need_pdic
            prepare_real_space!(pdic_workspaces[worker_id].scratch, model)
        end
    end
    grid_builder =
        (nkdiv, nkfft) -> mixed_fourier_grid(model, cfg.k_mesh; nkdiv = nkdiv, nkfft = nkfft)
    fourier_plan = if numerical_response_symmetry_plan === nothing
        build_fourier_execution_plan(
            cfg,
            specs,
            model,
            first(shared_matrix_workspaces),
            size,
            num_workers,
            grid_builder;
            rank_memory_limit_bytes = mixed_memory_limit_bytes,
        )
    else
        build_fourier_execution_plan(
            cfg,
            specs,
            model,
            first(shared_matrix_workspaces),
            size,
            num_workers,
            grid_builder;
            rank_memory_limit_bytes = mixed_memory_limit_bytes,
            evaluation_kpoint_indices = numerical_response_symmetry_plan.representatives,
            response_component_workload = response_symmetry_component_workload(
                numerical_response_symmetry_plan,
                specs,
                num_photon_energies,
            ),
        )
    end
    mixed_grid = fourier_plan.grid
    # Restrict this experimental traversal to the tested single-task, full-mesh SC path.
    use_block_order = block_local_requested && mixed_grid !== nothing
    block_access = use_block_order ? mixed_block_access(mixed_grid, 0, 1) : nothing
    block_indices = block_access === nothing ? nothing : block_access.indices
    point_order =
        block_indices === nothing ? nothing :
        Dict{Int, Int}(point => ordinal for (ordinal, point) in enumerate(block_indices))
    per_workspace_memory_limit = fourier_plan.memory_limit_bytes
    # Whole-block boundaries avoid recomputing the same FFT on different ranks.
    function point_lane_indices(lane_id)
        if block_indices === nothing
            return _deterministic_integral_lane_range(
                num_evaluation_kpoints,
                num_reduction_lanes,
                lane_id,
            )
        end
        block_points = block_access.points_per_block
        return [
            index for block in lane_id:num_reduction_lanes:block_access.block_count for
            index in ((block - 1) * block_points + 1):(block * block_points)
        ]
    end
    local_lane_ids = _local_deterministic_integral_lanes(num_reduction_lanes, rank, size)
    local_total_k = sum(length(point_lane_indices(lane_id)) for lane_id in local_lane_ids; init = 0)
    bundle_debug_log(
        debug_lock,
        "[fourier] backend=$(fourier_plan.backend) " *
        "factor_source=$(fourier_plan.factor_source) " *
        "estimated_memory=$(fourier_plan.estimated_memory_bytes) " *
        "per-rank limit=$(mixed_fourier_memory_limit()) " *
        "per-workspace share=$(per_workspace_memory_limit) " *
        "local_k_points=$(local_total_k) reduction_lanes=$(num_reduction_lanes) local_lanes=$(length(local_lane_ids))",
    )
    if mixed_grid !== nothing
        prepare_mixed_worker_buffers!(
            shared_matrix_workspaces,
            model,
            mixed_grid;
            memory_limit_bytes = per_workspace_memory_limit,
            completed_block_reuse = use_block_order,
        )
    end
    initial_fourier_summary = fourier_execution_summary(cfg, fourier_plan, shared_matrix_workspaces)
    progress_fourier_backend!(
        initial_fourier_summary;
        grid = cfg.k_mesh,
        local_kpoints = local_total_k,
        lanes = num_reduction_lanes,
    )
    bundle_debug_log(debug_lock, "[fourier] initialized summary=$(repr(initial_fourier_summary))")

    finished_count = Threads.Atomic{Int}(0)
    represented_weight = Threads.Atomic{Int}(0)
    last_progress_milestone = Threads.Atomic{Int}(0)
    active_count = Threads.Atomic{Int}(0)
    skipped_count = Threads.Atomic{Int}(0)
    kloop_t0 = time()
    progress_owner && bundle_debug_log(
        debug_lock,
        "[kloop] start local_k_points=$(local_total_k), total_work_items_global=$(num_evaluation_kpoints), full_grid_k_points=$(num_kpoints), progress_percent_interval=$(progress_percent_interval), slow_k_seconds=$(slow_k_seconds)",
    )
    point_buffers = [zeros(Float64, 3) for _ in 1:num_workers]
    paired_point_seconds = zeros(Float64, num_workers)
    point_values = [zeros(ComplexF64, point_elements) for _ in 1:num_workers]
    point_active = fill(false, num_workers)
    function point_value!(worker_id, kpoint)
        for state in point_states
            fill!(state.worker_data[worker_id], 0)
        end
        lane_id = worker_id
        kpoint_weight = 1
        active_any = false
        transition_screen =
            need_transition_screen ? transition_screen_workspaces[worker_id] : nothing
        photon_drag_transition_screen =
            need_photon_drag_transition_screen ?
            photon_drag_transition_screen_workspaces[worker_id] : nothing
        if need_transition_screen
            _prepare_transition_screen!(transition_screen, kpoint, cfg, model, num_orbitals)
        end
        if need_photon_drag_transition_screen && paired_blocks === nothing
            _prepare_photon_drag_transition_screen!(
                photon_drag_transition_screen,
                kpoint,
                q_d_geo,
                cfg,
                model,
                num_orbitals,
            )
        end

        if need_conv
            active_any |= _run_integral_conventional_current_family!(
                kpoint,
                transition_screen,
                lane_id,
                model,
                conv_workspaces[worker_id],
                ic_state === nothing ? nothing : conv_injection_qg[worker_id],
                isc_state === nothing ? nothing : conv_spin_injection_qg[worker_id],
                ssc_state === nothing ? nothing : shift_spin_current_workspaces[worker_id],
                sc_conv_state,
                ic_state,
                isc_state,
                ssc_state,
                cfg,
                1,
                cell_volume,
                num_orbitals,
                spatial_dimension,
                counters["conventional_q0_current"],
                kpoint_weight = kpoint_weight,
                scratch_worker_id = worker_id,
            )
        end
        if need_proj
            active_any |= _run_integral_projector_response_shift_current_family!(
                kpoint,
                transition_screen,
                lane_id,
                model,
                projector_response_workspaces[worker_id],
                p_d_projector,
                sc_proj_state,
                controls.tensor_indices,
                cfg,
                1,
                cell_volume,
                num_orbitals,
                spatial_dimension,
                cal_band_projector,
                counters["projector_response_shift_current"],
                kpoint_weight = kpoint_weight,
                scratch_worker_id = worker_id,
            )
        end
        if need_geo_q0
            active_any |= _run_integral_geometric_loop_shift_current_family!(
                kpoint,
                lane_id,
                model,
                geo_q0_workspaces[worker_id],
                q_d_zero,
                p_d_geo,
                wc_d_geo,
                sc_geo_state,
                controls.tensor_indices,
                cfg,
                1,
                cell_volume,
                num_orbitals,
                spatial_dimension,
                cal_band_geometric,
                counters["geometric_loop_shift_current_q0"],
                kpoint_weight = kpoint_weight,
                scratch_worker_id = worker_id,
                transition_screen = transition_screen,
            )
        end
        if need_geo_q && paired_blocks === nothing
            active_any |= _run_integral_geometric_loop_shift_current_family!(
                kpoint,
                lane_id,
                model,
                geo_q_workspaces[worker_id],
                q_d_geo,
                p_d_geo,
                wc_d_geo,
                pdsc_state,
                controls.tensor_indices,
                cfg,
                1,
                cell_volume,
                num_orbitals,
                spatial_dimension,
                cal_band_geometric,
                counters["geometric_loop_shift_current_q=$(cfg.photon_momentum)"],
                photon_drag_transition_screen = photon_drag_transition_screen,
            )
        end
        if need_wilson
            active_any |= _run_integral_wilson_loop_shift_current_family!(
                kpoint,
                transition_screen,
                lane_id,
                model,
                wilson_loop_response_workspaces[worker_id],
                p_d_geo,
                wc_d_geo,
                sc_wilson_state,
                cfg,
                1,
                cell_volume,
                num_orbitals,
                spatial_dimension,
                cal_band_wilson,
                counters["wilson_loop_response_shift_current_q0"],
                kpoint_weight = kpoint_weight,
                scratch_worker_id = worker_id,
            )
        end
        if need_pdic && paired_blocks === nothing
            active_any |= _run_integral_photon_drag_injection_current_family!(
                kpoint,
                photon_drag_transition_screen,
                lane_id,
                model,
                pdic_workspaces[worker_id],
                q_d_pdic,
                wc_d_pdic,
                pdic_state,
                controls.tensor_indices,
                cfg,
                1,
                cell_volume,
                num_orbitals,
                spatial_dimension,
                counters["conventional_finite_q_photon_drag_injection"],
            )
        end

        if paired_blocks !== nothing
            paired_start = time_ns()
            active_any |= execute_paired_photon_momentum_point!(
                paired_blocks,
                kpoint,
                photon_drag_transition_screen,
                lane_id,
                model,
                need_geo_q ? geo_q_workspaces[worker_id] : nothing,
                need_pdic ? pdic_workspaces[worker_id] : nothing,
                p_d_geo,
                need_geo_q ? wc_d_geo : wc_d_pdic,
                controls.tensor_indices,
                1,
                cell_volume,
                num_orbitals,
                spatial_dimension,
                cal_band_geometric,
                paired_geometric_counter,
                paired_injection_counter,
            )
            paired_point_seconds[worker_id] += (time_ns() - paired_start) / 1.0e9
        end

        values = point_values[worker_id]
        offset = 0
        for state in point_states
            source = state.worker_data[worker_id]
            for index in eachindex(source)
                values[offset + index] = source[index]
            end
            offset += length(source)
        end
        point_active[worker_id] = active_any
        return values
    end
    point_evaluators = [
        ResponsePointEvaluator(
            point_value!,
            worker,
            (
                shape = (point_elements,),
                prefactor = :physical_current_density_without_quadrature_weights,
                arbitrary_k = mixed_grid === nothing && paired_blocks === nothing,
                channels = [(state.spec.quantity, Base.size(state.local_data)) for state in states],
            ),
        ) for worker in 1:num_workers
    ]
    point_started = zeros(Float64, num_workers)
    function locate_point!(point, grid, evaluation_index)
        index =
            numerical_response_symmetry_plan === nothing ? evaluation_index :
            numerical_response_symmetry_plan.representatives[evaluation_index]
        integral_kpoint!(point, grid, index)
        return nothing
    end
    function request_point!(worker_id, point, evaluation_index)
        point_started[worker_id] = time()
        mixed_grid === nothing || begin_mixed_kpoint!(shared_matrix_workspaces[worker_id], point)
        return nothing
    end
    function consume_point!(worker_id, evaluation_index, lane_id, values)
        k_t0 = point_started[worker_id]
        kpoint_index =
            numerical_response_symmetry_plan === nothing ? evaluation_index :
            numerical_response_symmetry_plan.representatives[evaluation_index]
        kpoint_weight =
            numerical_response_symmetry_plan === nothing ? 1 :
            numerical_response_symmetry_plan.multiplicities[evaluation_index]
        scale = kpoint_weight / num_kpoints
        offset = 0
        for state in states
            target = integral_accumulator_target(state, lane_id, worker_id)
            if state.tensor_symmetry_plan === nothing
                for index in eachindex(target)
                    target[index] += scale * values[offset + index]
                end
            else
                for index in eachindex(target)
                    target[index] = scale * values[offset + index]
                end
            end
            offset += length(target)
        end
        numerical_response_symmetry_plan === nothing ||
            accumulate_integral_symmetry_coefficients!(states, lane_id, worker_id)
        active_any = point_active[worker_id]
        if active_any
            Threads.atomic_add!(active_count, 1)
        else
            Threads.atomic_add!(skipped_count, 1)
        end
        completed = Threads.atomic_add!(finished_count, 1) + 1
        represented = Threads.atomic_add!(represented_weight, kpoint_weight) + kpoint_weight
        k_total = time() - k_t0
        if k_total > slow_k_seconds
            bundle_debug_log(
                debug_lock,
                "[kloop] slow k point kpoint_index=$(kpoint_index) worker=$(worker_id) total=$(format_seconds(k_total))s",
            )
        end
        if progress_owner &&
           size == 1 &&
           progress_percent_milestone_crossed!(
               last_progress_milestone,
               completed,
               local_total_k,
               progress_percent_interval,
           )
            bundle_debug_log(
                debug_lock,
                "[kloop] progress finished=$(completed)/$(local_total_k) total_work_items_global=$(num_evaluation_kpoints) full_grid_k_points=$(num_kpoints) representatives=$(completed)/$(local_total_k) represented_weight=$(represented) active=$(active_count[]) skipped=$(skipped_count[]) elapsed=$(format_seconds(time() - kloop_t0))s",
            )
        end
        return nothing
    end
    execute_point! = ResponseGridConsumer(
        point_evaluators,
        k_grid,
        point_buffers,
        locate_point!,
        request_point!,
        consume_point!,
    )
    units = NTuple{3, Int}[]
    for lane_id in local_lane_ids
        for ordinal in point_lane_indices(lane_id)
            evaluation_index = block_indices === nothing ? ordinal : block_indices[ordinal]
            index =
                numerical_response_symmetry_plan === nothing ? evaluation_index :
                numerical_response_symmetry_plan.representatives[evaluation_index]
            push!(units, (index, evaluation_index, lane_id))
        end
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
        if rank == root
            finished_count[] = adaptive_result[].evaluations
            represented_weight[] = adaptive_result[].evaluations
        end
        return nothing
    end
    function finish!()
        try
            bundle_mpi_collective_call(; enabled = true, comm) do
                progress_localized_run_diagnostics!(shared_matrix_workspaces, comm)
            end
            bundle_mpi_collective_call(; enabled = true, comm) do
                if progress_owner
                    local_progress_counts =
                        Int[finished_count[], represented_weight[], active_count[], skipped_count[]]
                    global_progress_counts =
                        size > 1 ? bundle_mpi_reduce_sum(local_progress_counts, root, comm) :
                        local_progress_counts
                    if rank == root
                        global_finished = global_progress_counts[1]
                        global_represented = global_progress_counts[2]
                        global_active = global_progress_counts[3]
                        global_skipped = global_progress_counts[4]
                        if size > 1
                            bundle_debug_log(
                                debug_lock,
                                "[kloop] progress finished=$(global_finished)/$(num_evaluation_kpoints) local_finished=$(finished_count[])/$(local_total_k) total_work_items_global=$(num_evaluation_kpoints) full_grid_k_points=$(num_kpoints) representatives=$(global_finished)/$(num_evaluation_kpoints) represented_weight=$(global_represented) active=$(global_active) skipped=$(global_skipped) elapsed=$(format_seconds(time() - kloop_t0))s scope=global",
                            )
                        end
                        bundle_debug_log(
                            debug_lock,
                            "[kloop] end finished=$(global_finished)/$(num_evaluation_kpoints) local_finished=$(finished_count[])/$(local_total_k) total_work_items_global=$(num_evaluation_kpoints) full_grid_k_points=$(num_kpoints) representatives=$(global_finished)/$(num_evaluation_kpoints) represented_weight=$(global_represented) active=$(global_active) skipped=$(global_skipped) elapsed=$(format_seconds(time() - kloop_t0))s scope=global",
                        )
                    end
                end
                for worker_id in 1:num_workers
                    write_fourier_timing(
                        ctx.run_dir,
                        rank * num_workers + worker_id - 1,
                        time() - kloop_t0,
                        shared_matrix_workspaces[worker_id],
                        fourier_plan,
                    )
                end
                if mixed_grid !== nothing
                    for worker_id in 1:num_workers
                        stats = mixed_fourier_stats(shared_matrix_workspaces[worker_id])
                        bundle_debug_log(
                            debug_lock,
                            "[fourier] worker=$(worker_id) stats=$(repr(stats))",
                        )
                    end
                end

                bundle_debug_log(debug_lock, "[reduce] start deterministic task reductions")
            end
            reduce_t0 = time()
            if adaptive
                if rank == root
                    offset = 0
                    for state in states
                        for index in eachindex(state.global_data)
                            state.global_data[index] = adaptive_result[].value[offset + index]
                        end
                        offset += length(state.global_data)
                    end
                end
            else
                _reduce_integral_states!(states, root, rank, comm)
            end
            reduction_seconds = time() - reduce_t0
            bundle_mpi_collective_call(; enabled = true, comm) do
                bundle_debug_log(
                    debug_lock,
                    "[reduce] end deterministic task reductions elapsed=$(format_seconds(time() - reduce_t0))s",
                )
            end

            write_start = time()
            write_outputs! = function ()
                outputs = _write_integral_states!(cfg, ctx, states, debug_lock)
                adaptive && push!(
                    outputs,
                    write_response_integration_diagnostics(
                        ctx.run_dir,
                        adaptive_result[],
                        cfg.integration_algorithm,
                        cfg,
                    ),
                )
                return outputs
            end
            root_outputs =
                size == 1 ? write_outputs!() : bundle_mpi_root_call(write_outputs!; root, comm)
            outputs =
                rank == root ? root_outputs :
                reduce(vcat, [state.outputs for state in states]; init = String[])
            writing_seconds = time() - write_start
            fourier_summary = fourier_execution_summary(cfg, fourier_plan, shared_matrix_workspaces)
            if adaptive
                fourier_summary = merge(
                    fourier_summary,
                    (
                        reason = "arbitrary adaptive nodes",
                        integration = integration_algorithm_summary(cfg.integration_algorithm),
                        executed_response_evaluations = adaptive_result[].evaluations,
                    ),
                )
            end
            if paired_blocks !== nothing
                fourier_summary = merge(
                    fourier_summary,
                    (;
                        paired_path_rows = length(cfg.photon_energies),
                        paired_path_exact_groups = length(cfg.photon_momentum_path.groups),
                        paired_path_frequency_blocks = length(paired_blocks),
                        paired_path_frequency_capacity = num_photon_energies,
                        paired_path_initialization_seconds = kloop_t0 - total_t0,
                        paired_path_worker_point_seconds = sum(paired_point_seconds),
                        paired_path_reduction_seconds = reduction_seconds,
                        paired_path_write_seconds = writing_seconds,
                        paired_path_timing_scope = "rank-local wall spans; worker point sum includes screening and response; matrix/eigen spans in sharing.worker_statistics; not pure compute or cold",
                    ),
                )
            end
            if mixed_grid !== nothing
                release_mixed_worker_buffers!(shared_matrix_workspaces)
            end
            if fourier_timing_enabled()
                for workspace in shared_matrix_workspaces
                    disable_fourier_timing!(workspace)
                end
            end
            bundle_debug_log(
                debug_lock,
                "[done] fused integral bundle total elapsed=$(format_seconds(time() - total_t0))s",
            )
            response_symmetry_summary =
                response_symmetry_plan === nothing ? NamedTuple() :
                response_symmetry_metadata(response_symmetry_plan)
            legacy_adaptive_current =
                adaptive &&
                length(specs) == 1 &&
                only(specs).quantity in (:shift_current, :injection_current) &&
                only(specs).method == :conventional
            result = FusedBundleRunResult(
                outputs,
                legacy_adaptive_current ?
                ["adaptive_conventional_" * String(only(specs).quantity)] : families,
                legacy_adaptive_current ? NamedTuple[] : _family_counts(counters, families),
                fourier_summary,
                response_symmetry_summary,
                NamedTuple(),
                runtime_replica_summary(loaded_sources.replica_summary),
                qualification,
                runtime_model_geometry(model),
            )
            return result
        finally
            cleanup!()
        end
    end
    prepared = PreparedResponseTask(
        adaptive ? [(1, 1, 1)] : units,
        adaptive ? execute_adaptive! : execute_point!,
        finish!,
        cleanup!,
        point_order,
        paired_blocks === nothing ? nothing : paired_photon_interpolation_limits(),
        nothing,
        point_evaluators,
    )
    prepare_only && return prepared
    try
        execute_prepared_tasks!([prepared])
        return prepared.finish!()
    finally
        prepared.cleanup!()
    end
end
