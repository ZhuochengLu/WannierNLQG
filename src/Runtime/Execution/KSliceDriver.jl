# Load model sources, execute uniquely owned planar points with shared family workspaces, reduce slice buffers and write outputs.
function _run_kslice_bundle_fused!(
    cfg::EffectiveTaskConfig,
    ctx::RunContext,
    specs::Vector{NormalizedTaskSpec};
    prepare_only::Bool = false,
    progress_owner::Bool = true,
    shared_sources = nothing,
    mixed_memory_limit_bytes::Int = mixed_fourier_memory_limit(),
)
    cleanup_workspaces = MatrixElementWorkspace[]
    loaded_sources_ref = Ref{Any}(nothing)
    cleaned = Ref(false)
    function cleanup!()
        cleaned[] && return nothing
        cleaned[] = true
        for workspace in cleanup_workspaces
            disable_mixed_fourier!(workspace)
            disable_fourier_timing!(workspace)
        end
        if shared_sources === nothing && loaded_sources_ref[] !== nothing
            release_runtime_storage!(loaded_sources_ref[])
        end
        return nothing
    end
    try
        return _run_kslice_bundle_owned!(
            cfg,
            ctx,
            specs;
            prepare_only = prepare_only,
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
function _run_kslice_bundle_owned!(
    cfg::EffectiveTaskConfig,
    ctx::RunContext,
    specs::Vector{NormalizedTaskSpec};
    cleanup_workspaces,
    loaded_sources_ref,
    cleanup!,
    prepare_only::Bool = false,
    progress_owner::Bool = true,
    shared_sources = nothing,
    mixed_memory_limit_bytes::Int = mixed_fourier_memory_limit(),
)
    debug_lock = ReentrantLock()
    total_t0 = time()
    progress_percent_interval = effective_progress_percent_interval(cfg)
    slow_k_seconds =
        env_float(("WANNIERNLQG_KSLICE_SLOW_K_SECONDS", "WANNIERNLQG_SLOW_K_SECONDS"), 10.0)
    controls = _normalized_run_controls(cfg, specs)
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
    response_symmetry_plan = prepare_response_symmetry_execution_plan(cfg, ctx, specs, comm)
    calculated_response_components =
        _response_symmetry_calculated_components(specs, cfg.tensor_indices)
    response_symmetry_plan === nothing || progress_response_symmetry!(
        response_symmetry_metadata(
            response_symmetry_plan;
            calculated_components = calculated_response_components,
        ),
    )

    bundle_debug_log(
        debug_lock,
        "[setup] fused k-slice bundle start tasks=$([spec.label for spec in specs])",
    )
    bundle_debug_log(
        debug_lock,
        "[setup] execution_mode=fused_kloop MPI enabled=$(BUNDLE_MPI_CONTEXT.has_mpi) ranks=$(size) threads=$(Threads.nthreads())",
    )
    read_t0 = time()
    bundle_debug_log(debug_lock, "[read] start load_runtime_model_and_sources")
    loaded_sources =
        shared_sources === nothing ? load_runtime_model_and_sources(ctx, cfg) : shared_sources
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

    cell_volume = det(model.lattice)
    num_r_vectors = model.num_r_vectors
    num_orbitals = model.num_orbitals
    spatial_dimension = Int(cfg.spatial_dimension)
    k_mesh = Int[x for x in cfg.k_mesh]
    active_axes = validate_kslice_input(
        k_mesh,
        controls.kslice_origin,
        controls.kslice_vector_1,
        controls.kslice_vector_2,
        controls.tensor_indices,
        tensor_axis_limits(specs[1], spatial_dimension),
    )
    k_grid, num_u_points, num_v_points = make_kslice_grid(
        k_mesh,
        active_axes,
        controls.kslice_origin,
        controls.kslice_vector_1,
        controls.kslice_vector_2,
    )
    num_kpoints = length(k_grid)
    num_workers = Threads.nthreads()
    shared_matrix_plan = bundle_matrix_element_plan(specs, cfg, controls.tensor_indices)
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
            matrix_sources,
        ) for _ in 1:num_workers
    ]
    shared_matrix_workspaces = [batch.matrix_elements for batch in shared_matrix_batches]
    shared_central_data = [matrix_data!(batch, KPointOffset()) for batch in shared_matrix_batches]
    photon_shift_step = nonzero_photon_momentum(cfg.photon_momentum) ? 1 : 0
    shared_valence_data = [
        matrix_data!(batch, KPointOffset((0, 0, 0), -photon_shift_step)) for
        batch in shared_matrix_batches
    ]
    shared_conduction_data = [
        matrix_data!(batch, KPointOffset((0, 0, 0), photon_shift_step)) for
        batch in shared_matrix_batches
    ]
    has_berry_curvature = any(spec -> spec.quantity == :berry_curvature, specs)
    has_quantum_metric = any(spec -> spec.quantity == :quantum_metric, specs)
    has_bcd = any(spec -> spec.quantity == :berry_curvature_dipole, specs)
    has_qmd = any(spec -> spec.quantity == :quantum_metric_dipole, specs)
    has_bcq = any(spec -> spec.quantity == :berry_curvature_quadrupole, specs)
    has_qmq = any(spec -> spec.quantity == :quantum_metric_quadrupole, specs)
    has_qcs = any(spec -> spec.quantity == :quantum_christoffel_symbol, specs)
    berry_band_groups =
        has_berry_curvature ? normalize_berry_band_selection(cfg.band_selection, num_orbitals) :
        Vector{Int}[]
    quantum_metric_band_groups =
        has_quantum_metric ?
        normalize_quantum_metric_band_selection(cfg.band_selection, num_orbitals) : Vector{Int}[]
    bcd_band_groups =
        has_bcd ? validate_berry_curvature_dipole_band_selection(cfg.band_selection, num_orbitals) :
        Vector{Int}[]
    qmd_band_groups =
        has_qmd ? validate_quantum_metric_dipole_band_selection(cfg.band_selection, num_orbitals) :
        Vector{Int}[]
    bcq_band_groups =
        has_bcq ?
        validate_berry_curvature_quadrupole_band_selection(cfg.band_selection, num_orbitals) :
        Vector{Int}[]
    qmq_band_groups =
        has_qmq ?
        validate_quantum_metric_quadrupole_band_selection(cfg.band_selection, num_orbitals) :
        Vector{Int}[]
    qcs_band_groups =
        has_qcs ? validate_quantum_christoffel_band_selection(cfg.band_selection, num_orbitals) :
        Vector{Int}[]
    states = KSliceTaskAccumulator[]
    for spec in specs
        if spec.quantity == :berry_curvature
            for group in berry_band_groups
                push!(
                    states,
                    _make_kslice_state(
                        ctx,
                        spec,
                        num_u_points,
                        num_v_points,
                        num_workers;
                        band = band_group_output_label(group),
                        band_group = group,
                    ),
                )
            end
            if cfg.include_occupied_sum && (
                isempty(berry_band_groups) ||
                real_kslice_band_groups_include_sum(berry_band_groups)
            )
                push!(
                    states,
                    _make_kslice_state(
                        ctx,
                        spec,
                        num_u_points,
                        num_v_points,
                        num_workers;
                        band = :sum,
                    ),
                )
            end
        elseif spec.quantity == :quantum_metric
            for group in quantum_metric_band_groups
                push!(
                    states,
                    _make_kslice_state(
                        ctx,
                        spec,
                        num_u_points,
                        num_v_points,
                        num_workers;
                        band = band_group_output_label(group),
                        band_group = group,
                    ),
                )
            end
            if cfg.include_occupied_sum && (
                isempty(quantum_metric_band_groups) ||
                real_kslice_band_groups_include_sum(quantum_metric_band_groups)
            )
                push!(
                    states,
                    _make_kslice_state(
                        ctx,
                        spec,
                        num_u_points,
                        num_v_points,
                        num_workers;
                        band = :sum,
                    ),
                )
            end
        elseif spec.quantity == :berry_curvature_dipole
            for group in bcd_band_groups
                push!(
                    states,
                    _make_kslice_state(
                        ctx,
                        spec,
                        num_u_points,
                        num_v_points,
                        num_workers;
                        band = band_group_output_label(group),
                        band_group = group,
                    ),
                )
            end
        elseif spec.quantity == :quantum_metric_dipole
            for group in qmd_band_groups
                push!(
                    states,
                    _make_kslice_state(
                        ctx,
                        spec,
                        num_u_points,
                        num_v_points,
                        num_workers;
                        band = band_group_output_label(group),
                        band_group = group,
                    ),
                )
            end
        elseif spec.quantity == :berry_curvature_quadrupole
            for group in bcq_band_groups
                push!(
                    states,
                    _make_kslice_state(
                        ctx,
                        spec,
                        num_u_points,
                        num_v_points,
                        num_workers;
                        band = band_group_output_label(group),
                        band_group = group,
                    ),
                )
            end
        elseif spec.quantity == :quantum_metric_quadrupole
            for group in qmq_band_groups
                push!(
                    states,
                    _make_kslice_state(
                        ctx,
                        spec,
                        num_u_points,
                        num_v_points,
                        num_workers;
                        band = band_group_output_label(group),
                        band_group = group,
                    ),
                )
            end
        elseif spec.quantity == :quantum_christoffel_symbol
            for group in qcs_band_groups
                push!(
                    states,
                    _make_kslice_state(
                        ctx,
                        spec,
                        num_u_points,
                        num_v_points,
                        num_workers;
                        band = band_group_output_label(group),
                        band_group = group,
                    ),
                )
            end
        elseif is_interband_quantum_geometry_quantity(spec.quantity)
            push!(states, _make_kslice_state(ctx, spec, num_u_points, num_v_points, num_workers))
        else
            push!(states, _make_kslice_state(ctx, spec, num_u_points, num_v_points, num_workers))
        end
    end

    sc_conv_state = _find_state(states, :shift_current, :conventional)
    sc_proj_state = _find_state(states, :shift_current, :projector)
    sc_geo_state = _find_state(states, :shift_current, :geometric_loop)
    pdsc_state = _find_state(states, :photon_drag_shift_current, :geometric_loop)
    sc_wilson_state = _find_state(states, :shift_current, :wilson_loop)
    sv_geo_state = _find_state(states, :shift_vector, :geometric_loop)
    sv_wilson_state = _find_state(states, :shift_vector, :wilson_loop)
    conv_qhc_state = _find_state(states, :quantum_hermitian_connection, :conventional)
    hct_state = _find_state(states, :hermitian_curvature_tensor, :conventional)
    qhc_proj_state = _find_state(states, :quantum_hermitian_connection, :projector)
    qhc_geo_state = _find_state(states, :quantum_hermitian_connection, :geometric_loop)
    qhc_wilson_state = _find_state(states, :quantum_hermitian_connection, :wilson_loop)
    berry_curvature_states = _find_states(states, :berry_curvature, :conventional)
    quantum_metric_states = _find_states(states, :quantum_metric, :conventional)
    interband_berry_state = _find_state(states, :interband_berry_curvature, :conventional)
    interband_metric_state = _find_state(states, :interband_quantum_metric, :conventional)
    zeeman_interband_berry_state =
        _find_state(states, :zeeman_interband_berry_curvature, :conventional)
    zeeman_interband_metric_state =
        _find_state(states, :zeeman_interband_quantum_metric, :conventional)
    bcd_states = _find_states(states, :berry_curvature_dipole, :conventional)
    qmd_states = _find_states(states, :quantum_metric_dipole, :conventional)
    bcq_states = _find_states(states, :berry_curvature_quadrupole, :conventional)
    qmq_states = _find_states(states, :quantum_metric_quadrupole, :conventional)
    qcs_states = _find_states(states, :quantum_christoffel_symbol, :conventional)
    tpp_state = _find_state(states, :triple_phase_product, :conventional)
    ic_state = _find_state(states, :injection_current, :conventional)
    isc_state = _find_state(states, :injection_spin_current, :conventional)
    ssc_state = _find_state(states, :shift_spin_current, :conventional)
    pdic_state = _find_state(states, :photon_drag_injection_current, :conventional)

    need_conv_sc = sc_conv_state !== nothing
    need_conv_current =
        need_conv_sc || ic_state !== nothing || isc_state !== nothing || ssc_state !== nothing
    need_proj_sc = sc_proj_state !== nothing
    need_geo_q0 = sc_geo_state !== nothing
    need_geo_q = pdsc_state !== nothing
    need_wilson = sc_wilson_state !== nothing
    need_sv_geo = sv_geo_state !== nothing
    need_sv_wilson = sv_wilson_state !== nothing
    need_conv_qhc = conv_qhc_state !== nothing
    need_hct = hct_state !== nothing
    need_qhc_proj = qhc_proj_state !== nothing
    need_qhc_geo = qhc_geo_state !== nothing
    need_qhc_wilson = qhc_wilson_state !== nothing
    need_berry_curvature = !isempty(berry_curvature_states)
    need_quantum_metric = !isempty(quantum_metric_states)
    need_interband_geometry =
        interband_berry_state !== nothing || interband_metric_state !== nothing
    need_zeeman_interband_geometry =
        zeeman_interband_berry_state !== nothing || zeeman_interband_metric_state !== nothing
    need_bcd = !isempty(bcd_states)
    need_qmd = !isempty(qmd_states)
    need_bcq = !isempty(bcq_states)
    need_qmq = !isempty(qmq_states)
    need_qcs = !isempty(qcs_states)
    need_tpp = tpp_state !== nothing
    need_conventional_geometry =
        need_conv_qhc ||
        need_hct ||
        need_berry_curvature ||
        need_quantum_metric ||
        need_interband_geometry ||
        need_zeeman_interband_geometry ||
        need_bcd ||
        need_qmd ||
        need_bcq ||
        need_qmq ||
        need_qcs ||
        need_tpp
    need_projector_response = need_proj_sc || need_qhc_proj
    need_wilson_loop_response = need_wilson || need_sv_wilson || need_qhc_wilson
    need_pdic = pdic_state !== nothing
    need_transition_screen = need_conv_current || need_proj_sc || need_geo_q0 || need_wilson
    need_photon_drag_transition_screen = need_geo_q || need_pdic
    response_component_plan =
        need_projector_response || need_wilson_loop_response || need_geo_q0 || need_geo_q ?
        make_response_component_plan(controls.tensor_indices) : nothing

    cal_band_projector = _effective_window_band_count(cfg.band_window_size, num_orbitals)
    cal_band_geometric = _effective_window_band_count(cfg.band_window_size, num_orbitals)
    cal_band_wilson = _effective_window_band_count(cfg.band_window_size, num_orbitals)

    need_qhc_any = need_conv_qhc || need_qhc_proj || need_qhc_geo || need_qhc_wilson
    qhc_band_selection =
        need_qhc_any ? normalize_band_selection(cfg.band_selection) : (Int[], Int[])
    if need_qhc_any
        validate_band_selection(qhc_band_selection, num_orbitals)
    end
    projector_required_bands = falses(num_orbitals)
    if need_qhc_proj
        for group in qhc_band_selection
            for band in group
                projector_required_bands[band] = true
            end
        end
    end
    interband_band_selection =
        (need_interband_geometry || need_zeeman_interband_geometry) ?
        validate_interband_band_selection(cfg.band_selection, num_orbitals) : (Int[], Int[])
    hct_band_selection =
        need_hct ? validate_interband_band_selection(cfg.band_selection, num_orbitals) :
        (Int[], Int[])
    shift_vector_band_selection =
        (need_sv_geo || need_sv_wilson) ?
        validate_interband_band_selection(cfg.band_selection, num_orbitals) : (Int[], Int[])
    tpp_band_selection =
        need_tpp ? validate_triple_phase_product_band_selection(cfg.band_selection, num_orbitals) :
        (Int[], Int[], Int[])
    qhc_band_start, qhc_band_end =
        need_conv_qhc ? band_selection_window(qhc_band_selection) : (1, 0)
    conventional_model = model

    transition_screen_workspaces =
        need_transition_screen ?
        [
            make_transition_screen_workspace(
                num_orbitals,
                num_r_vectors,
                length(cfg.photon_energies),
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
                length(cfg.photon_energies),
                matrix_elements = shared_matrix_workspaces[worker_id],
                valence_data = shared_valence_data[worker_id],
                conduction_data = shared_conduction_data[worker_id],
            ) for worker_id in 1:num_workers
        ] : PhotonDragTransitionScreenWorkspace[]

    conv_sc_workspaces =
        need_conv_current ?
        [
            make_shift_current_conventional_workspace(
                num_orbitals,
                num_r_vectors,
                spatial_dimension,
                1,
                matrix_elements = shared_matrix_workspaces[worker_id],
                central_data = shared_central_data[worker_id],
            ) for worker_id in 1:num_workers
        ] : ShiftCurrentConventionalWorkspace[]
    conv_injection_qg =
        need_conv_current ?
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
        [
            make_shift_spin_current_conventional_workspace(
                num_orbitals,
                num_r_vectors,
                spatial_dimension,
                matrix_elements = shared_matrix_workspaces[worker_id],
                central_data = shared_central_data[worker_id],
            ) for worker_id in 1:num_workers
        ] : ShiftSpinCurrentConventionalWorkspace[]
    conv_geometry_workspaces =
        need_conventional_geometry ?
        [
            make_conventional_quantum_geometry_workspace(
                num_orbitals,
                num_r_vectors,
                spatial_dimension,
                1,
                matrix_elements = shared_matrix_workspaces[worker_id],
                central_data = shared_central_data[worker_id],
                matrix_batch = shared_matrix_batches[worker_id],
            ) for worker_id in 1:num_workers
        ] : ConventionalQuantumGeometryWorkspace[]
    projector_response_workspaces =
        need_projector_response ?
        [
            make_projector_response_workspace(
                num_orbitals,
                num_r_vectors,
                spatial_dimension,
                1,
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
                1,
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
                1,
                matrix_elements = shared_matrix_workspaces[worker_id],
                matrix_batch = shared_matrix_batches[worker_id],
                valence_central_common = shared_valence_data[worker_id],
                conduction_central_common = shared_conduction_data[worker_id],
            ) for worker_id in 1:num_workers
        ] : GeometricLoopResponseWorkspace[]
    sv_geo_workspaces =
        need_sv_geo ?
        [
            make_geometric_loop_response_workspace(
                num_orbitals,
                num_r_vectors,
                spatial_dimension,
                1,
                matrix_elements = shared_matrix_workspaces[worker_id],
                matrix_batch = shared_matrix_batches[worker_id],
                valence_central_common = shared_valence_data[worker_id],
                conduction_central_common = shared_conduction_data[worker_id],
            ) for worker_id in 1:num_workers
        ] : GeometricLoopResponseWorkspace[]
    geo_qhc_workspaces =
        need_qhc_geo ?
        [
            make_geometric_loop_response_workspace(
                num_orbitals,
                num_r_vectors,
                spatial_dimension,
                1,
                matrix_elements = shared_matrix_workspaces[worker_id],
                matrix_batch = shared_matrix_batches[worker_id],
                valence_central_common = shared_valence_data[worker_id],
                conduction_central_common = shared_conduction_data[worker_id],
            ) for worker_id in 1:num_workers
        ] : GeometricLoopResponseWorkspace[]
    wilson_loop_response_workspaces =
        need_wilson_loop_response ?
        [
            make_wilson_loop_response_workspace(
                num_orbitals,
                num_r_vectors,
                spatial_dimension,
                1,
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
                1,
                photon_energies = @view(cfg.photon_energies[1:1]),
                denominator_regularization = cfg.denominator_regularization,
                matrix_elements = shared_matrix_workspaces[worker_id],
                valence_data = shared_valence_data[worker_id],
                conduction_data = shared_conduction_data[worker_id],
            ) for worker_id in 1:num_workers
        ] : PhotonDragInjectionCurrentConventionalWorkspace[]

    p_d_projector =
        need_projector_response ? finite_difference_step_matrix(model, cfg.finite_difference_step) :
        zeros(Float64, 3, 3)
    p_d_geometry_derivative =
        (need_bcd || need_qmd || need_bcq || need_qmq || need_qcs) ?
        finite_difference_step_matrix(model, cfg.finite_difference_step) : zeros(Float64, 3, 3)
    p_c = cfg.finite_difference_step * Matrix{Float64}(I, 3, 3)
    p_d_geo = zeros(Float64, 3, 3)
    for i in 1:3
        p_d_geo[:, i] = reciprocal_cartesian_to_fractional(p_c[:, i], model.lattice)
    end
    wc_d_geo = zeros(Float64, 3, num_orbitals)
    if need_geo_q0 || need_geo_q || need_sv_geo || need_qhc_geo || need_wilson_loop_response
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
        if need_conv_current
            prepare_real_space!(conv_sc_workspaces[worker_id].scratch, model)
        end
        if need_conventional_geometry
            prepare_real_space!(conv_geometry_workspaces[worker_id].scratch, conventional_model)
        end
        if need_projector_response
            prepare_real_space!(projector_response_workspaces[worker_id].scratch, model)
        end
        if need_geo_q0
            prepare_real_space!(geo_q0_workspaces[worker_id].scratch, model)
        end
        if need_geo_q
            prepare_real_space!(geo_q_workspaces[worker_id].scratch, model)
        end
        if need_sv_geo
            prepare_real_space!(sv_geo_workspaces[worker_id].scratch, model)
        end
        if need_qhc_geo
            prepare_real_space!(geo_qhc_workspaces[worker_id].scratch, model)
        end
        if need_wilson_loop_response
            prepare_real_space!(wilson_loop_response_workspaces[worker_id].scratch, model)
        end
        if need_pdic
            prepare_real_space!(pdic_workspaces[worker_id].scratch, model)
        end
    end
    grid_builder =
        (nkdiv, nkfft) -> mixed_fourier_kslice_grid(
            model,
            k_mesh,
            controls.kslice_origin,
            controls.kslice_vector_1,
            controls.kslice_vector_2;
            nkdiv = nkdiv,
            nkfft = nkfft,
        )
    fourier_plan = build_fourier_execution_plan(
        cfg,
        specs,
        model,
        first(shared_matrix_workspaces),
        size,
        num_workers,
        grid_builder;
        rank_memory_limit_bytes = mixed_memory_limit_bytes,
    )
    mixed_grid = fourier_plan.grid
    per_workspace_memory_limit = fourier_plan.memory_limit_bytes
    local_k_indices =
        mixed_grid === nothing ? _local_k_indices(num_kpoints, rank, size) :
        mixed_fourier_local_k_indices(mixed_grid, rank, size)
    bundle_debug_log(
        debug_lock,
        "[fourier] backend=$(fourier_plan.backend) " *
        "factor_source=$(fourier_plan.factor_source) " *
        "estimated_memory=$(fourier_plan.estimated_memory_bytes) " *
        "per-rank limit=$(mixed_fourier_memory_limit()) " *
        "per-workspace share=$(per_workspace_memory_limit) " *
        "local_k_points=$(length(local_k_indices))",
    )
    if mixed_grid !== nothing
        for worker_id in 1:num_workers
            enable_mixed_fourier!(
                shared_matrix_workspaces[worker_id],
                model,
                mixed_grid;
                memory_limit_bytes = per_workspace_memory_limit,
            )
        end
    end
    initial_fourier_summary = fourier_execution_summary(cfg, fourier_plan, shared_matrix_workspaces)
    progress_fourier_backend!(initial_fourier_summary)
    bundle_debug_log(debug_lock, "[fourier] initialized summary=$(repr(initial_fourier_summary))")

    local_total_k = length(local_k_indices)
    finished_count = Threads.Atomic{Int}(0)
    last_progress_milestone = Threads.Atomic{Int}(0)
    active_count = Threads.Atomic{Int}(0)
    skipped_count = Threads.Atomic{Int}(0)
    kloop_t0 = time()
    progress_owner && bundle_debug_log(
        debug_lock,
        "[kloop] start local_k_points=$(local_total_k), total_work_items_global=$(num_kpoints), full_grid_k_points=$(num_kpoints), progress_percent_interval=$(progress_percent_interval), slow_k_seconds=$(slow_k_seconds)",
    )
    point_buffers = [zeros(Float64, 3) for _ in 1:num_workers]
    function execute_point!(worker_id::Int, idx::Int, lane_id::Int)
        kpoint = point_buffers[worker_id]
        k_t0 = time()
        active_any = false
        kpoint_index = local_k_indices[idx]
        kslice_kpoint!(kpoint, k_grid, kpoint_index)
        u_index, v_index = kslice_indices(k_grid, kpoint_index)
        mixed_grid === nothing || begin_mixed_kpoint!(
            shared_matrix_workspaces[worker_id],
            kpoint,
            (u_index - 1, v_index - 1, 0),
        )

        transition_screen =
            need_transition_screen ? transition_screen_workspaces[worker_id] : nothing
        if transition_screen !== nothing
            _prepare_transition_screen!(transition_screen, kpoint, cfg, model, num_orbitals)
        end
        photon_drag_transition_screen =
            need_photon_drag_transition_screen ?
            photon_drag_transition_screen_workspaces[worker_id] : nothing
        if photon_drag_transition_screen !== nothing
            _prepare_photon_drag_transition_screen!(
                photon_drag_transition_screen,
                kpoint,
                q_d_geo,
                cfg,
                model,
                num_orbitals,
            )
        end

        if need_conv_current
            active_any |= _run_kslice_conventional_current_family!(
                kpoint,
                transition_screen,
                u_index,
                v_index,
                worker_id,
                model,
                conv_sc_workspaces[worker_id],
                conv_injection_qg[worker_id],
                isc_state === nothing ? nothing : conv_spin_injection_qg[worker_id],
                ssc_state === nothing ? nothing : shift_spin_current_workspaces[worker_id],
                sc_conv_state,
                ic_state,
                isc_state,
                ssc_state,
                controls.tensor_indices,
                cfg,
                num_kpoints,
                cell_volume,
                num_orbitals,
                spatial_dimension,
                counters["conventional_q0_current"],
            )
        end
        if need_conventional_geometry
            compute_kpoint!(
                conv_geometry_workspaces[worker_id].data,
                conv_geometry_workspaces[worker_id].scratch,
                conventional_model,
                kpoint;
                denominator_regularization = cfg.denominator_regularization,
                spatial_dimension = spatial_dimension,
            )
            if need_conv_qhc
                active_any |= _accumulate_kslice_conventional_geometry_qhc_family!(
                    u_index,
                    v_index,
                    worker_id,
                    conv_geometry_workspaces[worker_id],
                    conv_qhc_state,
                    qhc_band_selection,
                    qhc_band_start,
                    qhc_band_end,
                    controls.tensor_indices,
                    cfg,
                    num_orbitals,
                    spatial_dimension,
                    counters["conventional_geometry_qhc"],
                )
            end
            if need_hct
                active_any |= _accumulate_kslice_conventional_hermitian_curvature_tensor_family!(
                    u_index,
                    v_index,
                    worker_id,
                    conv_geometry_workspaces[worker_id],
                    hct_state,
                    hct_band_selection,
                    controls.tensor_indices,
                    num_orbitals,
                    counters["conventional_hermitian_curvature_tensor"],
                )
            end
            if need_berry_curvature
                berry_occupations = fermi_dirac(
                    conv_geometry_workspaces[worker_id].data.spectrum.energies,
                    cfg.fermi_energy,
                    cfg.temperature,
                )
                active_any |= _accumulate_kslice_conventional_berry_curvature_family!(
                    u_index,
                    v_index,
                    worker_id,
                    conv_geometry_workspaces[worker_id],
                    berry_curvature_states,
                    controls.tensor_indices,
                    num_orbitals,
                    berry_occupations,
                    counters["conventional_berry_curvature"],
                )
            end
            if need_quantum_metric
                metric_occupations = fermi_dirac(
                    conv_geometry_workspaces[worker_id].data.spectrum.energies,
                    cfg.fermi_energy,
                    cfg.temperature,
                )
                active_any |= _accumulate_kslice_conventional_quantum_metric_family!(
                    u_index,
                    v_index,
                    worker_id,
                    conv_geometry_workspaces[worker_id],
                    quantum_metric_states,
                    controls.tensor_indices,
                    num_orbitals,
                    metric_occupations,
                    counters["conventional_quantum_metric"],
                )
            end
            if need_interband_geometry
                active_any |= _accumulate_kslice_conventional_interband_quantum_geometry_family!(
                    u_index,
                    v_index,
                    worker_id,
                    conv_geometry_workspaces[worker_id],
                    interband_berry_state,
                    interband_metric_state,
                    interband_band_selection,
                    controls.tensor_indices,
                    counters["conventional_interband_quantum_geometry"],
                )
            end
            if need_zeeman_interband_geometry
                active_any |=
                    _accumulate_kslice_conventional_zeeman_interband_quantum_geometry_family!(
                        u_index,
                        v_index,
                        worker_id,
                        conv_geometry_workspaces[worker_id],
                        zeeman_interband_berry_state,
                        zeeman_interband_metric_state,
                        interband_band_selection,
                        controls.tensor_indices,
                        counters["conventional_zeeman_interband_quantum_geometry"],
                    )
            end
            if need_tpp
                active_any |= _accumulate_kslice_conventional_triple_phase_product_family!(
                    u_index,
                    v_index,
                    worker_id,
                    conv_geometry_workspaces[worker_id],
                    tpp_state,
                    tpp_band_selection,
                    controls.tensor_indices,
                    counters["conventional_triple_phase_product"],
                )
            end
            if need_qcs
                for qcs_state in qcs_states
                    active_any |= _accumulate_kslice_conventional_quantum_christoffel_family!(
                        kpoint,
                        u_index,
                        v_index,
                        worker_id,
                        conv_geometry_workspaces[worker_id],
                        conventional_model,
                        p_d_geometry_derivative,
                        qcs_state,
                        qcs_state.band_group,
                        controls.tensor_indices,
                        cfg,
                        num_orbitals,
                        spatial_dimension,
                        counters["conventional_quantum_christoffel"],
                    )
                end
            end
            if need_qmd
                for qmd_state in qmd_states
                    active_any |= _accumulate_kslice_conventional_quantum_metric_dipole_family!(
                        kpoint,
                        u_index,
                        v_index,
                        worker_id,
                        conv_geometry_workspaces[worker_id],
                        conventional_model,
                        p_d_geometry_derivative,
                        qmd_state,
                        qmd_state.band_group,
                        controls.tensor_indices,
                        cfg,
                        num_orbitals,
                        spatial_dimension,
                        counters["conventional_quantum_metric_dipole"],
                    )
                end
            end
            if need_qmq
                for qmq_state in qmq_states
                    active_any |= _accumulate_kslice_conventional_quantum_metric_quadrupole_family!(
                        kpoint,
                        u_index,
                        v_index,
                        worker_id,
                        conv_geometry_workspaces[worker_id],
                        conventional_model,
                        p_d_geometry_derivative,
                        qmq_state,
                        qmq_state.band_group,
                        controls.tensor_indices,
                        cfg,
                        num_orbitals,
                        spatial_dimension,
                        counters["conventional_quantum_metric_quadrupole"],
                    )
                end
            end
            if need_bcd
                for bcd_state in bcd_states
                    active_any |= _accumulate_kslice_conventional_berry_curvature_dipole_family!(
                        kpoint,
                        u_index,
                        v_index,
                        worker_id,
                        conv_geometry_workspaces[worker_id],
                        conventional_model,
                        p_d_geometry_derivative,
                        bcd_state,
                        bcd_state.band_group,
                        controls.tensor_indices,
                        cfg,
                        num_orbitals,
                        spatial_dimension,
                        counters["conventional_berry_curvature_dipole"],
                    )
                end
            end
            if need_bcq
                for bcq_state in bcq_states
                    active_any |=
                        _accumulate_kslice_conventional_berry_curvature_quadrupole_family!(
                            kpoint,
                            u_index,
                            v_index,
                            worker_id,
                            conv_geometry_workspaces[worker_id],
                            conventional_model,
                            p_d_geometry_derivative,
                            bcq_state,
                            bcq_state.band_group,
                            controls.tensor_indices,
                            cfg,
                            num_orbitals,
                            spatial_dimension,
                            counters["conventional_berry_curvature_quadrupole"],
                        )
                end
            end
        end
        if need_projector_response
            projector_ws = projector_response_workspaces[worker_id]
            if need_qhc_proj || (transition_screen !== nothing && transition_screen.active)
                _prepare_projector_response_cache!(
                    projector_ws,
                    kpoint,
                    p_d_projector,
                    cfg,
                    model,
                    num_orbitals,
                    spatial_dimension,
                    axes = response_component_plan.projector_axes,
                    axis_pairs = response_component_plan.projector_axis_pairs,
                    active_bands = transition_screen === nothing ? nothing :
                                   transition_screen.active_bands,
                    required_bands = need_qhc_proj ? projector_required_bands : nothing,
                )
            end
            if need_proj_sc
                active_any |= _accumulate_kslice_projector_response_shift_current_from_cache!(
                    u_index,
                    v_index,
                    worker_id,
                    projector_ws,
                    transition_screen,
                    sc_proj_state,
                    controls.tensor_indices,
                    cfg,
                    num_kpoints,
                    cell_volume,
                    num_orbitals,
                    spatial_dimension,
                    cal_band_projector,
                    counters["projector_response_shift_current"],
                )
            end
            if need_qhc_proj
                active_any |= _accumulate_kslice_projector_response_qhc_from_cache!(
                    u_index,
                    v_index,
                    worker_id,
                    projector_ws,
                    qhc_proj_state,
                    qhc_band_selection,
                    controls.tensor_indices,
                    counters["projector_response_qhc"],
                )
            end
        end
        if need_geo_q0
            active_any |= _run_kslice_geometric_loop_shift_current_family!(
                kpoint,
                transition_screen,
                u_index,
                v_index,
                worker_id,
                model,
                geo_q0_workspaces[worker_id],
                q_d_zero,
                p_d_geo,
                wc_d_geo,
                sc_geo_state,
                controls.tensor_indices,
                cfg,
                num_kpoints,
                cell_volume,
                num_orbitals,
                spatial_dimension,
                cal_band_geometric,
                counters["geometric_loop_shift_current_q0"],
            )
        end
        if need_geo_q
            active_any |= _run_kslice_geometric_loop_shift_current_family!(
                kpoint,
                photon_drag_transition_screen,
                u_index,
                v_index,
                worker_id,
                model,
                geo_q_workspaces[worker_id],
                q_d_geo,
                p_d_geo,
                wc_d_geo,
                pdsc_state,
                controls.tensor_indices,
                cfg,
                num_kpoints,
                cell_volume,
                num_orbitals,
                spatial_dimension,
                cal_band_geometric,
                counters["geometric_loop_shift_current_q=$(cfg.photon_momentum)"],
            )
        end
        if need_sv_geo
            active_any |= _run_kslice_geometric_loop_shift_vector_family!(
                kpoint,
                u_index,
                v_index,
                worker_id,
                model,
                sv_geo_workspaces[worker_id],
                q_d_geo,
                p_d_geo,
                wc_d_geo,
                sv_geo_state,
                shift_vector_band_selection,
                controls.tensor_indices,
                cfg,
                num_orbitals,
                spatial_dimension,
                counters["geometric_loop_shift_vector_q=$(cfg.photon_momentum)"],
            )
        end
        if need_qhc_geo
            active_any |= _run_kslice_geometric_loop_qhc_family!(
                kpoint,
                u_index,
                v_index,
                worker_id,
                model,
                geo_qhc_workspaces[worker_id],
                q_d_geo,
                p_d_geo,
                wc_d_geo,
                qhc_geo_state,
                qhc_band_selection,
                controls.tensor_indices,
                cfg,
                num_orbitals,
                spatial_dimension,
                counters["geometric_loop_qhc_q=$(cfg.photon_momentum)"],
            )
        end
        if need_wilson_loop_response
            wilson_ws = wilson_loop_response_workspaces[worker_id]
            if need_qhc_wilson ||
               need_sv_wilson ||
               (transition_screen !== nothing && transition_screen.active)
                _prepare_wilson_loop_response_cache!(
                    wilson_ws,
                    kpoint,
                    p_d_geo,
                    wc_d_geo,
                    cfg,
                    model,
                    spatial_dimension,
                    axes = response_component_plan.derivative_axes,
                )
            end
            if need_qhc_wilson
                active_any |= _accumulate_kslice_wilson_loop_qhc_from_cache!(
                    u_index,
                    v_index,
                    worker_id,
                    wilson_ws,
                    qhc_wilson_state,
                    qhc_band_selection,
                    controls.tensor_indices,
                    cfg,
                    spatial_dimension,
                    counters["wilson_loop_response_qhc_q0"],
                )
            end
            if need_wilson
                active_any |= _accumulate_kslice_wilson_loop_shift_current_from_cache!(
                    u_index,
                    v_index,
                    worker_id,
                    wilson_ws,
                    transition_screen,
                    sc_wilson_state,
                    controls.tensor_indices,
                    cfg,
                    num_kpoints,
                    cell_volume,
                    num_orbitals,
                    spatial_dimension,
                    cal_band_wilson,
                    counters["wilson_loop_response_shift_current_q0"],
                )
            end
            if need_sv_wilson
                band_start, band_end = band_selection_window(shift_vector_band_selection)
                band_start, band_end =
                    expand_band_window_for_groups(band_start, band_end, wilson_ws.central_data)
                compute_wilson_loop_shift_vector_from_cache!(
                    wilson_ws.shift_vector_response_kernel,
                    wilson_ws,
                    band_start,
                    band_end,
                    cfg.finite_difference_step,
                    spatial_dimension,
                    tensor_indices = controls.tensor_indices,
                )
                active_any |= _accumulate_kslice_wilson_loop_shift_vector_from_cache!(
                    u_index,
                    v_index,
                    worker_id,
                    wilson_ws,
                    sv_wilson_state,
                    shift_vector_band_selection,
                    controls.tensor_indices,
                    counters["wilson_loop_response_shift_vector_q0"],
                )
            end
        end
        if need_pdic
            active_any |= _run_kslice_photon_drag_injection_current_family!(
                kpoint,
                photon_drag_transition_screen,
                u_index,
                v_index,
                worker_id,
                model,
                pdic_workspaces[worker_id],
                q_d_pdic,
                wc_d_pdic,
                pdic_state,
                controls.tensor_indices,
                cfg,
                num_kpoints,
                cell_volume,
                num_orbitals,
                spatial_dimension,
                counters["conventional_finite_q_photon_drag_injection"],
            )
        end

        if active_any
            Threads.atomic_add!(active_count, 1)
        else
            Threads.atomic_add!(skipped_count, 1)
        end
        completed = Threads.atomic_add!(finished_count, 1) + 1
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
                "[kloop] progress finished=$(completed)/$(local_total_k) total_work_items_global=$(num_kpoints) full_grid_k_points=$(num_kpoints) active=$(active_count[]) skipped=$(skipped_count[]) elapsed=$(format_seconds(time() - kloop_t0))s",
            )
        end
        return nothing
    end
    units = NTuple{3, Int}[
        (index, position, position) for (position, index) in enumerate(local_k_indices)
    ]
    function finish!()
        try
            if progress_owner
                local_progress_counts = Int[finished_count[], active_count[], skipped_count[]]
                global_progress_counts =
                    size > 1 ? bundle_mpi_reduce_sum(local_progress_counts, root, comm) :
                    local_progress_counts
                if rank == root
                    global_finished = global_progress_counts[1]
                    global_active = global_progress_counts[2]
                    global_skipped = global_progress_counts[3]
                    if size > 1
                        bundle_debug_log(
                            debug_lock,
                            "[kloop] progress finished=$(global_finished)/$(num_kpoints) local_finished=$(finished_count[])/$(local_total_k) total_work_items_global=$(num_kpoints) full_grid_k_points=$(num_kpoints) active=$(global_active) skipped=$(global_skipped) elapsed=$(format_seconds(time() - kloop_t0))s scope=global",
                        )
                    end
                    bundle_debug_log(
                        debug_lock,
                        "[kloop] end finished=$(global_finished)/$(num_kpoints) local_finished=$(finished_count[])/$(local_total_k) total_work_items_global=$(num_kpoints) full_grid_k_points=$(num_kpoints) active=$(global_active) skipped=$(global_skipped) elapsed=$(format_seconds(time() - kloop_t0))s scope=global",
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
            if fourier_timing_enabled()
                for workspace in shared_matrix_workspaces
                    disable_fourier_timing!(workspace)
                end
            end

            reduce_t0 = time()
            bundle_debug_log(debug_lock, "[reduce] start deterministic task reductions")
            _reduce_kslice_states!(states, root, rank, comm)
            bundle_debug_log(
                debug_lock,
                "[reduce] end deterministic task reductions elapsed=$(format_seconds(time() - reduce_t0))s",
            )

            outputs =
                rank == root ? _write_kslice_states!(cfg, ctx, states, debug_lock) :
                reduce(vcat, [state.outputs for state in states]; init = String[])
            fourier_summary = fourier_execution_summary(cfg, fourier_plan, shared_matrix_workspaces)
            if mixed_grid !== nothing
                for workspace in shared_matrix_workspaces
                    disable_mixed_fourier!(workspace)
                end
            end
            bundle_debug_log(
                debug_lock,
                "[done] fused k-slice bundle total elapsed=$(format_seconds(time() - total_t0))s",
            )
            result = FusedBundleRunResult(
                outputs,
                families,
                _family_counts(counters, families),
                fourier_summary,
                response_symmetry_plan === nothing ? NamedTuple() :
                response_symmetry_metadata(
                    response_symmetry_plan;
                    calculated_components = calculated_response_components,
                ),
                NamedTuple(),
                runtime_replica_summary(loaded_sources.replica_summary),
            )
            return result
        finally
            cleanup!()
        end
    end
    prepared = PreparedResponseTask(units, execute_point!, finish!, cleanup!)
    prepare_only && return prepared
    try
        execute_prepared_tasks!([prepared])
        return prepared.finish!()
    finally
        prepared.cleanup!()
    end
end
