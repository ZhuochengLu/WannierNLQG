# Share one screened matrix point across requested conventional charge/spin current tasks and write their owned slice cells.
function _run_kslice_conventional_current_family!(
    kpoint::Vector{Float64},
    transition_screen::TransitionScreenWorkspace,
    u_index::Int,
    v_index::Int,
    worker_id::Int,
    model::TightBindingModel,
    ws::ShiftCurrentConventionalWorkspace,
    injection_qg::Array{ComplexF64, 5},
    spin_injection_qg,
    shift_spin_ws,
    sc_state,
    ic_state,
    isc_state,
    ssc_state,
    tensor_indices::Vector{Int},
    cfg::EffectiveTaskConfig,
    num_kpoints::Int,
    cell_volume::Float64,
    num_orbitals::Int,
    spatial_dimension::Int,
    counter::BundleFamilyCounter,
)
    sc_state === nothing &&
        ic_state === nothing &&
        isc_state === nothing &&
        ssc_state === nothing &&
        return false
    scratch = ws.scratch
    data = ws.data
    if !transition_screen.active
        Threads.atomic_add!(counter.skipped, 1)
        return false
    end

    compute_kpoint!(
        data,
        scratch,
        model,
        kpoint;
        denominator_regularization = cfg.denominator_regularization,
        spatial_dimension = spatial_dimension,
    )
    band_start = transition_screen.band_start
    band_end = transition_screen.band_end
    occupation_differences = transition_screen.occupation_differences
    delta = @view transition_screen.delta[1, :, :]
    use_active_pair_list = transition_screen.use_active_pair_list
    active_pairs_nmajor = use_active_pair_list ? transition_screen.active_pairs_nmajor : nothing
    active_pairs_mmajor = use_active_pair_list ? transition_screen.active_pairs_mmajor : nothing
    derivative_required_pairs_nmajor =
        use_active_pair_list ? transition_screen.derivative_required_pairs_nmajor : nothing
    if sc_state !== nothing
        compute_conventional_shift_current_kernel!(
            ws.response_kernel,
            ws.generalized_position_derivative,
            data,
            band_start,
            band_end,
            num_orbitals,
            spatial_dimension,
            active_pair_mask = transition_screen.active_pair_mask,
            active_pairs_nmajor = active_pairs_nmajor,
            active_pair_count = transition_screen.active_pairs_nmajor_length,
            derivative_required_pairs_nmajor = derivative_required_pairs_nmajor,
            derivative_pair_count = transition_screen.derivative_required_pairs_nmajor_length,
            tensor_indices = tensor_indices,
            _generalized_derivative_scratch = ws.generalized_derivative_scratch,
        )
        prefactor =
            REDUCED_PLANCK_CONSTANT_EV_S * pi * (-ELEMENTARY_CHARGE_C)^3 /
            (2.0 * REDUCED_PLANCK_CONSTANT_J_S^2 * num_kpoints * cell_volume)
        sc_state.worker_data[worker_id][u_index, v_index] = conventional_component_response(
            ws.response_kernel,
            occupation_differences,
            delta,
            prefactor,
            tensor_indices,
            band_start,
            band_end,
            active_pairs_mmajor = active_pairs_mmajor,
            active_pair_count = transition_screen.active_pairs_mmajor_length,
        )
    end
    if ic_state !== nothing
        compute_injection_current_kernel!(
            injection_qg,
            data,
            band_start,
            band_end,
            spatial_dimension,
            active_pair_mask = transition_screen.active_pair_mask,
            active_pairs_nmajor = active_pairs_nmajor,
            active_pair_count = transition_screen.active_pairs_nmajor_length,
            tensor_indices = tensor_indices,
        )
        # One ordered-field injection rate; the conjugate-order factor 2 and tau are external.
        prefactor =
            -pi * ELEMENTARY_CHARGE_C^3 /
            (REDUCED_PLANCK_CONSTANT_J_S^2 * num_kpoints * cell_volume)
        ic_state.worker_data[worker_id][u_index, v_index] = injection_current_component(
            injection_qg,
            occupation_differences,
            delta,
            prefactor,
            tensor_indices,
            band_start,
            band_end,
            active_pairs_nmajor = active_pairs_nmajor,
            active_pair_count = transition_screen.active_pairs_nmajor_length,
        )
    end
    if isc_state !== nothing
        compute_injection_spin_current_kernel!(
            spin_injection_qg,
            data,
            band_start,
            band_end,
            spatial_dimension,
            active_pair_mask = transition_screen.active_pair_mask,
            active_pairs_nmajor = active_pairs_nmajor,
            active_pair_count = transition_screen.active_pairs_nmajor_length,
            tensor_indices = tensor_indices,
        )
        # Pauli-normalized ordered-field rate; conjugate ordering, tau, and hbar/2 are external.
        # After multiplication by -|e|, the identity channel has the same prefactor as IC.
        prefactor =
            pi * ELEMENTARY_CHARGE_C^2 / (REDUCED_PLANCK_CONSTANT_J_S^2 * num_kpoints * cell_volume)
        isc_state.worker_data[worker_id][u_index, v_index] = injection_spin_current_component(
            spin_injection_qg,
            occupation_differences,
            delta,
            prefactor,
            tensor_indices,
            band_start,
            band_end,
            active_pairs_nmajor = active_pairs_nmajor,
            active_pair_count = transition_screen.active_pairs_nmajor_length,
        )
    end
    if ssc_state !== nothing
        compute_shift_spin_current_vertices!(
            shift_spin_ws,
            cfg.denominator_regularization,
            spatial_dimension,
            tensor_indices = tensor_indices,
        )
        compute_shift_spin_current_kernel!(
            shift_spin_ws,
            band_start,
            band_end,
            spatial_dimension;
            active_pair_mask = transition_screen.active_pair_mask,
            active_pairs_nmajor = active_pairs_nmajor,
            active_pair_count = transition_screen.active_pairs_nmajor_length,
            tensor_indices = tensor_indices,
        )
        # Pauli-normalized (+omega,-omega) ordered-field response; hbar/2 is external.
        # For S=I, multiplying by -|e| gives the same (a,b,c) SC component only in the
        # nondegenerate resonant eta -> 0 limit.
        prefactor =
            1.0im * REDUCED_PLANCK_CONSTANT_EV_S * pi * ELEMENTARY_CHARGE_C^2 /
            (2.0 * REDUCED_PLANCK_CONSTANT_J_S^2 * num_kpoints * cell_volume)
        ssc_state.worker_data[worker_id][u_index, v_index] = shift_spin_current_component(
            shift_spin_ws.response_kernel,
            occupation_differences,
            delta,
            data.energy_differences,
            cfg.denominator_regularization,
            prefactor,
            tensor_indices,
            band_start,
            band_end,
            active_pairs_nmajor = active_pairs_nmajor,
            active_pair_count = transition_screen.active_pairs_nmajor_length,
        )
    end
    Threads.atomic_add!(counter.active, 1)
    return true
end

# Compute conventional quantum-Hermitian connection data for the selected groups/axes and store one worker-owned slice value.
function _run_kslice_conventional_geometry_qhc_family!(
    kpoint::Vector{Float64},
    u_index::Int,
    v_index::Int,
    worker_id::Int,
    conventional_model::TightBindingModel,
    ws::ConventionalQuantumGeometryWorkspace,
    state,
    band_selection::Tuple{Vector{Int}, Vector{Int}},
    band_start::Int,
    band_end::Int,
    tensor_indices::Vector{Int},
    cfg::EffectiveTaskConfig,
    num_orbitals::Int,
    spatial_dimension::Int,
    counter::BundleFamilyCounter,
)
    state === nothing && return false
    compute_kpoint!(
        ws.data,
        ws.scratch,
        conventional_model,
        kpoint;
        denominator_regularization = cfg.denominator_regularization,
        spatial_dimension = spatial_dimension,
    )
    return _accumulate_kslice_conventional_geometry_qhc_family!(
        u_index,
        v_index,
        worker_id,
        ws,
        state,
        band_selection,
        band_start,
        band_end,
        tensor_indices,
        cfg,
        num_orbitals,
        spatial_dimension,
        counter,
    )
end

# Accumulate kslice conventional geometry qhc family into caller-owned storage.
function _accumulate_kslice_conventional_geometry_qhc_family!(
    u_index::Int,
    v_index::Int,
    worker_id::Int,
    ws::ConventionalQuantumGeometryWorkspace,
    state,
    band_selection::Tuple{Vector{Int}, Vector{Int}},
    band_start::Int,
    band_end::Int,
    tensor_indices::Vector{Int},
    cfg::EffectiveTaskConfig,
    num_orbitals::Int,
    spatial_dimension::Int,
    counter::BundleFamilyCounter,
)
    state === nothing && return false
    state.worker_data[worker_id][u_index, v_index] =
        conventional_quantum_hermitian_connection_component(
            ws.data,
            band_selection,
            tensor_indices,
            num_orbitals,
        )
    Threads.atomic_add!(counter.active, 1)
    return true
end

# Accumulate kslice conventional hermitian curvature tensor family into caller-owned storage.
function _accumulate_kslice_conventional_hermitian_curvature_tensor_family!(
    u_index::Int,
    v_index::Int,
    worker_id::Int,
    ws::ConventionalQuantumGeometryWorkspace,
    state,
    band_selection::Tuple{Vector{Int}, Vector{Int}},
    tensor_indices::Vector{Int},
    num_orbitals::Int,
    counter::BundleFamilyCounter,
)
    state === nothing && return false
    state.worker_data[worker_id][u_index, v_index] =
        hermitian_curvature_tensor_component(ws.data, band_selection, tensor_indices, num_orbitals)
    Threads.atomic_add!(counter.active, 1)
    return true
end

# Accumulate kslice conventional berry curvature family into caller-owned storage.
function _accumulate_kslice_conventional_berry_curvature_family!(
    u_index::Int,
    v_index::Int,
    worker_id::Int,
    ws::ConventionalQuantumGeometryWorkspace,
    states::Vector{KSliceTaskAccumulator},
    tensor_indices::Vector{Int},
    num_orbitals::Int,
    occupations::AbstractVector{<:Real},
    counter::BundleFamilyCounter,
)
    isempty(states) && return false
    for state in states
        band = state.band_label
        if band === :sum
            state.worker_data[worker_id][u_index, v_index] = berry_curvature_occupied_sum_component(
                ws.data,
                tensor_indices,
                num_orbitals,
                occupations,
            )
        elseif state.band_group !== nothing
            state.worker_data[worker_id][u_index, v_index] = berry_curvature_group_sum_component(
                ws.data,
                state.band_group,
                tensor_indices,
                num_orbitals,
            )
        else
            error("Internal error: Berry_Curvature K-slice state is missing a valid band label.")
        end
    end
    Threads.atomic_add!(counter.active, 1)
    return true
end

# Accumulate kslice conventional quantum metric family into caller-owned storage.
function _accumulate_kslice_conventional_quantum_metric_family!(
    u_index::Int,
    v_index::Int,
    worker_id::Int,
    ws::ConventionalQuantumGeometryWorkspace,
    states::Vector{KSliceTaskAccumulator},
    tensor_indices::Vector{Int},
    num_orbitals::Int,
    occupations::AbstractVector{<:Real},
    counter::BundleFamilyCounter,
)
    isempty(states) && return false
    for state in states
        band = state.band_label
        if band === :sum
            state.worker_data[worker_id][u_index, v_index] = quantum_metric_band_sum_component(
                ws.data,
                tensor_indices,
                num_orbitals,
                occupations,
            )
        elseif state.band_group !== nothing
            state.worker_data[worker_id][u_index, v_index] = quantum_metric_group_sum_component(
                ws.data,
                state.band_group,
                tensor_indices,
                num_orbitals,
            )
        else
            error("Internal error: Quantum_Metric K-slice state is missing a valid band label.")
        end
    end
    Threads.atomic_add!(counter.active, 1)
    return true
end

# Accumulate kslice conventional interband quantum geometry family into caller-owned storage.
function _accumulate_kslice_conventional_interband_quantum_geometry_family!(
    u_index::Int,
    v_index::Int,
    worker_id::Int,
    ws::ConventionalQuantumGeometryWorkspace,
    berry_state,
    metric_state,
    band_selection::Tuple{Vector{Int}, Vector{Int}},
    tensor_indices::Vector{Int},
    counter::BundleFamilyCounter,
)
    berry_state === nothing && metric_state === nothing && return false
    if berry_state !== nothing
        berry_state.worker_data[worker_id][u_index, v_index] =
            interband_berry_curvature_component(ws.data, band_selection, tensor_indices)
    end
    if metric_state !== nothing
        metric_state.worker_data[worker_id][u_index, v_index] =
            interband_quantum_metric_component(ws.data, band_selection, tensor_indices)
    end
    Threads.atomic_add!(counter.active, 1)
    return true
end

# Accumulate kslice conventional zeeman interband quantum geometry family into caller-owned storage.
function _accumulate_kslice_conventional_zeeman_interband_quantum_geometry_family!(
    u_index::Int,
    v_index::Int,
    worker_id::Int,
    ws::ConventionalQuantumGeometryWorkspace,
    berry_state,
    metric_state,
    band_selection::Tuple{Vector{Int}, Vector{Int}},
    tensor_indices::Vector{Int},
    counter::BundleFamilyCounter,
)
    berry_state === nothing && metric_state === nothing && return false
    components =
        zeeman_interband_quantum_geometry_components(ws.data, band_selection, tensor_indices)
    if berry_state !== nothing
        berry_state.worker_data[worker_id][u_index, v_index] = components.berry_curvature
    end
    if metric_state !== nothing
        metric_state.worker_data[worker_id][u_index, v_index] = components.quantum_metric
    end
    Threads.atomic_add!(counter.active, 1)
    return true
end

# Accumulate kslice conventional quantum christoffel family into caller-owned storage.
function _accumulate_kslice_conventional_quantum_christoffel_family!(
    kpoint::Vector{Float64},
    u_index::Int,
    v_index::Int,
    worker_id::Int,
    ws::ConventionalQuantumGeometryWorkspace,
    conventional_model::TightBindingModel,
    finite_difference_vectors::Matrix{Float64},
    state,
    band_group::Vector{Int},
    tensor_indices::Vector{Int},
    cfg::EffectiveTaskConfig,
    num_orbitals::Int,
    spatial_dimension::Int,
    counter::BundleFamilyCounter,
)
    state === nothing && return false
    state.worker_data[worker_id][u_index, v_index] = quantum_christoffel_symbol_component!(
        ws,
        conventional_model,
        kpoint,
        finite_difference_vectors,
        band_group,
        tensor_indices,
        cfg.finite_difference_step,
        cfg.denominator_regularization,
        num_orbitals,
        spatial_dimension,
    )
    Threads.atomic_add!(counter.active, 1)
    return true
end

# Accumulate kslice conventional quantum metric dipole family into caller-owned storage.
function _accumulate_kslice_conventional_quantum_metric_dipole_family!(
    kpoint::Vector{Float64},
    u_index::Int,
    v_index::Int,
    worker_id::Int,
    ws::ConventionalQuantumGeometryWorkspace,
    conventional_model::TightBindingModel,
    finite_difference_vectors::Matrix{Float64},
    state,
    band_group::Vector{Int},
    tensor_indices::Vector{Int},
    cfg::EffectiveTaskConfig,
    num_orbitals::Int,
    spatial_dimension::Int,
    counter::BundleFamilyCounter,
)
    state === nothing && return false
    state.worker_data[worker_id][u_index, v_index] = quantum_metric_dipole_component!(
        ws,
        conventional_model,
        kpoint,
        finite_difference_vectors,
        band_group,
        tensor_indices,
        cfg.finite_difference_step,
        cfg.denominator_regularization,
        num_orbitals,
        spatial_dimension,
    )
    Threads.atomic_add!(counter.active, 1)
    return true
end

# Accumulate kslice conventional berry curvature dipole family into caller-owned storage.
function _accumulate_kslice_conventional_berry_curvature_dipole_family!(
    kpoint::Vector{Float64},
    u_index::Int,
    v_index::Int,
    worker_id::Int,
    ws::ConventionalQuantumGeometryWorkspace,
    conventional_model::TightBindingModel,
    finite_difference_vectors::Matrix{Float64},
    state,
    band_group::Vector{Int},
    tensor_indices::Vector{Int},
    cfg::EffectiveTaskConfig,
    num_orbitals::Int,
    spatial_dimension::Int,
    counter::BundleFamilyCounter,
)
    state === nothing && return false
    state.worker_data[worker_id][u_index, v_index] = berry_curvature_dipole_component!(
        ws,
        conventional_model,
        kpoint,
        finite_difference_vectors,
        band_group,
        tensor_indices,
        cfg.finite_difference_step,
        cfg.denominator_regularization,
        num_orbitals,
        spatial_dimension,
    )
    Threads.atomic_add!(counter.active, 1)
    return true
end

# Accumulate kslice conventional quantum metric quadrupole family into caller-owned storage.
function _accumulate_kslice_conventional_quantum_metric_quadrupole_family!(
    kpoint::Vector{Float64},
    u_index::Int,
    v_index::Int,
    worker_id::Int,
    ws::ConventionalQuantumGeometryWorkspace,
    conventional_model::TightBindingModel,
    finite_difference_vectors::Matrix{Float64},
    state,
    band_group::Vector{Int},
    tensor_indices::Vector{Int},
    cfg::EffectiveTaskConfig,
    num_orbitals::Int,
    spatial_dimension::Int,
    counter::BundleFamilyCounter,
)
    state === nothing && return false
    state.worker_data[worker_id][u_index, v_index] = quantum_metric_quadrupole_component!(
        ws,
        conventional_model,
        kpoint,
        finite_difference_vectors,
        band_group,
        tensor_indices,
        cfg.finite_difference_step,
        cfg.denominator_regularization,
        num_orbitals,
        spatial_dimension,
    )
    Threads.atomic_add!(counter.active, 1)
    return true
end

# Accumulate kslice conventional berry curvature quadrupole family into caller-owned storage.
function _accumulate_kslice_conventional_berry_curvature_quadrupole_family!(
    kpoint::Vector{Float64},
    u_index::Int,
    v_index::Int,
    worker_id::Int,
    ws::ConventionalQuantumGeometryWorkspace,
    conventional_model::TightBindingModel,
    finite_difference_vectors::Matrix{Float64},
    state,
    band_group::Vector{Int},
    tensor_indices::Vector{Int},
    cfg::EffectiveTaskConfig,
    num_orbitals::Int,
    spatial_dimension::Int,
    counter::BundleFamilyCounter,
)
    state === nothing && return false
    state.worker_data[worker_id][u_index, v_index] = berry_curvature_quadrupole_component!(
        ws,
        conventional_model,
        kpoint,
        finite_difference_vectors,
        band_group,
        tensor_indices,
        cfg.finite_difference_step,
        cfg.denominator_regularization,
        num_orbitals,
        spatial_dimension,
    )
    Threads.atomic_add!(counter.active, 1)
    return true
end

# Accumulate kslice conventional triple phase product family into caller-owned storage.
function _accumulate_kslice_conventional_triple_phase_product_family!(
    u_index::Int,
    v_index::Int,
    worker_id::Int,
    ws::ConventionalQuantumGeometryWorkspace,
    state,
    band_selection::Tuple{Vector{Int}, Vector{Int}, Vector{Int}},
    tensor_indices::Vector{Int},
    counter::BundleFamilyCounter,
)
    state === nothing && return false
    state.worker_data[worker_id][u_index, v_index] =
        triple_phase_product_component(ws.data, band_selection, tensor_indices)
    Threads.atomic_add!(counter.active, 1)
    return true
end

# Prepare projector derivative/trace data and write the selected quantum-Hermitian connection component at one slice point.
function _run_kslice_projector_response_qhc_family!(
    kpoint::Vector{Float64},
    u_index::Int,
    v_index::Int,
    worker_id::Int,
    model::TightBindingModel,
    ws::ProjectorResponseWorkspace,
    finite_difference_vectors::Matrix{Float64},
    state,
    band_selection::Tuple{Vector{Int}, Vector{Int}},
    tensor_indices::Vector{Int},
    cfg::EffectiveTaskConfig,
    num_orbitals::Int,
    spatial_dimension::Int,
    counter::BundleFamilyCounter,
)
    state === nothing && return false
    _prepare_projector_response_cache!(
        ws,
        kpoint,
        finite_difference_vectors,
        wannier_centers_fractional,
        cfg,
        model,
        num_orbitals,
        spatial_dimension,
    )
    return _accumulate_kslice_projector_response_qhc_from_cache!(
        u_index,
        v_index,
        worker_id,
        ws,
        state,
        band_selection,
        tensor_indices,
        counter,
    )
end

# Accumulate kslice projector response qhc from cache into caller-owned storage.
function _accumulate_kslice_projector_response_qhc_from_cache!(
    u_index::Int,
    v_index::Int,
    worker_id::Int,
    ws::ProjectorResponseWorkspace,
    state,
    band_selection::Tuple{Vector{Int}, Vector{Int}},
    tensor_indices::Vector{Int},
    counter::BundleFamilyCounter,
)
    state === nothing && return false
    compute_projector_quantum_hermitian_connection_from_cache!(
        ws.qhc_response_kernel,
        ws.central_data,
        band_selection,
        tensor_indices,
        ws.kernel_tmp1,
        ws.kernel_tmp2,
        ws.kernel_tmp3,
        ws.kernel_tmp4,
        ws.kernel_tmp5,
        ws.kernel_tmp6,
    )
    state.worker_data[worker_id][u_index, v_index] = quantum_hermitian_connection_component(
        ws.qhc_response_kernel,
        band_selection,
        tensor_indices,
    )
    Threads.atomic_add!(counter.active, 1)
    return true
end

# Prepare native-frame finite-loop links and write the selected quantum-Hermitian connection component at one slice point.
function _run_kslice_geometric_loop_qhc_family!(
    kpoint::Vector{Float64},
    u_index::Int,
    v_index::Int,
    worker_id::Int,
    model::TightBindingModel,
    ws::GeometricLoopResponseWorkspace,
    photon_momentum_fractional::Vector{Float64},
    finite_difference_vectors::Matrix{Float64},
    wannier_centers_fractional::Matrix{Float64},
    state,
    band_selection::Tuple{Vector{Int}, Vector{Int}},
    tensor_indices::Vector{Int},
    cfg::EffectiveTaskConfig,
    num_orbitals::Int,
    spatial_dimension::Int,
    counter::BundleFamilyCounter,
)
    state === nothing && return false
    compute_geometric_loop_quantum_hermitian_connection_kernel!(
        ws,
        kpoint,
        photon_momentum_fractional,
        finite_difference_vectors,
        wannier_centers_fractional,
        cfg.denominator_regularization,
        cfg.finite_difference_step,
        spatial_dimension,
        model,
        band_selection,
        cfg.degeneracy_threshold,
        tensor_indices = tensor_indices,
    )
    state.worker_data[worker_id][u_index, v_index] =
        quantum_hermitian_connection_component(ws.response_kernel, band_selection, tensor_indices)
    Threads.atomic_add!(counter.active, 1)
    return true
end

# Prepare Wilson transported derivatives and write the selected quantum-Hermitian connection component at one slice point.
function _run_kslice_wilson_loop_qhc_family!(
    kpoint::Vector{Float64},
    u_index::Int,
    v_index::Int,
    worker_id::Int,
    model::TightBindingModel,
    ws::WilsonLoopResponseWorkspace,
    finite_difference_vectors::Matrix{Float64},
    wannier_centers_fractional::Matrix{Float64},
    state,
    band_selection::Tuple{Vector{Int}, Vector{Int}},
    tensor_indices::Vector{Int},
    cfg::EffectiveTaskConfig,
    spatial_dimension::Int,
    counter::BundleFamilyCounter,
)
    state === nothing && return false
    _prepare_wilson_loop_response_cache!(
        ws,
        kpoint,
        finite_difference_vectors,
        wannier_centers_fractional,
        cfg,
        model,
        spatial_dimension,
    )
    return _accumulate_kslice_wilson_loop_qhc_from_cache!(
        u_index,
        v_index,
        worker_id,
        ws,
        state,
        band_selection,
        tensor_indices,
        cfg,
        spatial_dimension,
        counter,
    )
end

# Accumulate kslice wilson loop qhc from cache into caller-owned storage.
function _accumulate_kslice_wilson_loop_qhc_from_cache!(
    u_index::Int,
    v_index::Int,
    worker_id::Int,
    ws::WilsonLoopResponseWorkspace,
    state,
    band_selection::Tuple{Vector{Int}, Vector{Int}},
    tensor_indices::Vector{Int},
    cfg::EffectiveTaskConfig,
    spatial_dimension::Int,
    counter::BundleFamilyCounter,
)
    state === nothing && return false
    compute_wilson_loop_quantum_hermitian_connection_from_cache!(
        ws.qhc_response_kernel,
        ws,
        band_selection,
        cfg.finite_difference_step,
        spatial_dimension,
        tensor_indices = tensor_indices,
    )
    state.worker_data[worker_id][u_index, v_index] = quantum_hermitian_connection_component(
        ws.qhc_response_kernel,
        band_selection,
        tensor_indices,
    )
    Threads.atomic_add!(counter.active, 1)
    return true
end
