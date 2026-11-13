
# Skip inactive points or prepare Projector derivatives and the screened shift-current kernel, returning the valid band window.
function _projector_prepare_current_kernel!(
    ws::ProjectorResponseWorkspace,
    kpoint::Vector{Float64},
    transition_screen::TransitionScreenWorkspace,
    finite_difference_vectors::Matrix{Float64},
    cfg::EffectiveTaskConfig,
    model::AbstractResponseModel,
    num_orbitals::Int,
    spatial_dimension::Int,
    band_window_size::Int,
)
    central_data = ws.central_data
    transition_screen.active || return (false, 1, 0)

    _prepare_projector_response_cache!(
        ws,
        kpoint,
        finite_difference_vectors,
        cfg,
        model,
        num_orbitals,
        spatial_dimension,
        active_bands = transition_screen.active_bands,
    )

    band_start = transition_screen.band_start
    band_end = transition_screen.band_end
    compute_projector_response_shift_current_kernel!(
        ws.response_kernel,
        central_data,
        transition_screen.occupation_differences,
        band_start,
        band_end,
        num_orbitals,
        spatial_dimension,
        ws.kernel_tmp1,
        ws.kernel_tmp2,
        ws.kernel_tmp3,
        ws.kernel_tmp4,
        ws.kernel_tmp5,
        ws.kernel_tmp6,
        active_pair_mask = transition_screen.active_pair_mask,
    )
    return (true, band_start, band_end)
end

# Accumulate one point's Projector shift current into its integral lane, honoring selected symmetry components and activity counters.
function _run_integral_projector_response_shift_current_family!(
    kpoint::Vector{Float64},
    transition_screen::TransitionScreenWorkspace,
    worker_id::Int,
    model::AbstractResponseModel,
    ws::ProjectorResponseWorkspace,
    finite_difference_vectors::Matrix{Float64},
    state,
    tensor_indices::Vector{Int},
    cfg::EffectiveTaskConfig,
    num_kpoints::Int,
    cell_volume::Float64,
    num_orbitals::Int,
    spatial_dimension::Int,
    band_window_size::Int,
    counter::BundleFamilyCounter,
    ;
    kpoint_weight::Int = 1,
    scratch_worker_id::Int = worker_id,
)
    state === nothing && return false
    components = integral_symmetry_component_vectors(state)
    ok = false
    if components === nothing
        ok, _band_start, _band_end = _projector_prepare_current_kernel!(
            ws,
            kpoint,
            transition_screen,
            finite_difference_vectors,
            cfg,
            model,
            num_orbitals,
            spatial_dimension,
            band_window_size,
        )
    elseif transition_screen.active
        _prepare_projector_response_cache!(
            ws,
            kpoint,
            finite_difference_vectors,
            cfg,
            model,
            num_orbitals,
            spatial_dimension,
            active_bands = transition_screen.active_bands,
        )
        for component in components
            compute_projector_response_shift_current_kernel!(
                ws.response_kernel,
                ws.central_data,
                transition_screen.occupation_differences,
                transition_screen.band_start,
                transition_screen.band_end,
                num_orbitals,
                spatial_dimension,
                ws.kernel_tmp1,
                ws.kernel_tmp2,
                ws.kernel_tmp3,
                ws.kernel_tmp4,
                ws.kernel_tmp5,
                ws.kernel_tmp6,
                active_pair_mask = transition_screen.active_pair_mask,
                tensor_indices = component,
            )
        end
        ok = true
    end
    if !ok
        Threads.atomic_add!(counter.skipped, 1)
        return false
    end

    # Projector reduced-unit prefactor; response_kernel stores C_{mn}^{a;cb}-C_{nm}^{a;bc}.
    prefactor =
        kpoint_weight * 1.0im * pi * ELEMENTARY_CHARGE_C^2 /
        (2.0 * REDUCED_PLANCK_CONSTANT_J_S * num_kpoints * cell_volume)
    target = integral_accumulator_target(state, worker_id, scratch_worker_id)
    if components === nothing
        accumulate_projector_response_shift_current_response!(
            target,
            ws.response_kernel,
            reshape(transition_screen.occupation_differences, 1, num_orbitals, num_orbitals),
            transition_screen.delta,
            prefactor,
            num_orbitals,
            spatial_dimension,
        )
    else
        for component in components, energy_index in axes(transition_screen.delta, 1)
            target[(energy_index, component...)...] += projector_response_sck_component(
                ws.response_kernel,
                transition_screen.occupation_differences,
                @view(transition_screen.delta[energy_index, :, :]),
                prefactor,
                component,
                num_orbitals,
            )
        end
    end
    Threads.atomic_add!(counter.active, 1)
    return true
end

# Write the requested Projector shift-current component at one owned slice point after transition screening.
function _run_kslice_projector_response_shift_current_family!(
    kpoint::Vector{Float64},
    transition_screen::TransitionScreenWorkspace,
    u_index::Int,
    v_index::Int,
    worker_id::Int,
    model::AbstractResponseModel,
    ws::ProjectorResponseWorkspace,
    finite_difference_vectors::Matrix{Float64},
    state,
    tensor_indices::Vector{Int},
    cfg::EffectiveTaskConfig,
    num_kpoints::Int,
    cell_volume::Float64,
    num_orbitals::Int,
    spatial_dimension::Int,
    band_window_size::Int,
    counter::BundleFamilyCounter,
)
    state === nothing && return false
    if !transition_screen.active
        Threads.atomic_add!(counter.skipped, 1)
        return false
    end
    component_plan = make_response_component_plan(tensor_indices)
    _prepare_projector_response_cache!(
        ws,
        kpoint,
        finite_difference_vectors,
        cfg,
        model,
        num_orbitals,
        spatial_dimension,
        axes = component_plan.projector_axes,
        axis_pairs = component_plan.projector_axis_pairs,
        active_bands = transition_screen.active_bands,
    )
    return _accumulate_kslice_projector_response_shift_current_from_cache!(
        u_index,
        v_index,
        worker_id,
        ws,
        transition_screen,
        state,
        tensor_indices,
        cfg,
        num_kpoints,
        cell_volume,
        num_orbitals,
        spatial_dimension,
        band_window_size,
        counter,
    )
end

# Accumulate kslice projector response shift current from cache into caller-owned storage.
function _accumulate_kslice_projector_response_shift_current_from_cache!(
    u_index::Int,
    v_index::Int,
    worker_id::Int,
    ws::ProjectorResponseWorkspace,
    transition_screen::TransitionScreenWorkspace,
    state,
    tensor_indices::Vector{Int},
    cfg::EffectiveTaskConfig,
    num_kpoints::Int,
    cell_volume::Float64,
    num_orbitals::Int,
    spatial_dimension::Int,
    band_window_size::Int,
    counter::BundleFamilyCounter,
)
    state === nothing && return false
    if !transition_screen.active
        Threads.atomic_add!(counter.skipped, 1)
        return false
    end
    central_data = ws.central_data
    occupation_differences = transition_screen.occupation_differences
    band_start = transition_screen.band_start
    band_end = transition_screen.band_end
    compute_projector_response_shift_current_kernel!(
        ws.response_kernel,
        central_data,
        occupation_differences,
        band_start,
        band_end,
        num_orbitals,
        spatial_dimension,
        ws.kernel_tmp1,
        ws.kernel_tmp2,
        ws.kernel_tmp3,
        ws.kernel_tmp4,
        ws.kernel_tmp5,
        ws.kernel_tmp6,
        active_pair_mask = transition_screen.active_pair_mask,
        tensor_indices = tensor_indices,
    )

    delta = @view transition_screen.delta[1, :, :]
    prefactor =
        1.0im * pi * ELEMENTARY_CHARGE_C^2 /
        (2.0 * REDUCED_PLANCK_CONSTANT_J_S * num_kpoints * cell_volume)
    state.worker_data[worker_id][u_index, v_index] = projector_response_sck_component(
        ws.response_kernel,
        occupation_differences,
        delta,
        prefactor,
        tensor_indices,
        num_orbitals,
    )
    Threads.atomic_add!(counter.active, 1)
    return true
end
