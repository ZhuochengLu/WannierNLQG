
# Screen a central eigensystem, prepare Wilson links, expand degenerate band windows and return current-kernel occupation weights.
function _wilson_prepare_current_kernel!(
    ws::WilsonLoopResponseWorkspace,
    kpoint::Vector{Float64},
    finite_difference_vectors::Matrix{Float64},
    wannier_centers_fractional::Matrix{Float64},
    cfg::EffectiveTaskConfig,
    model::AbstractResponseModel,
    num_orbitals::Int,
    spatial_dimension::Int,
    band_window_size::Int,
)
    central_data = ws.central_data
    compute_spectrum!(central_data.common, ws.scratch.matrix_elements, model, kpoint)
    band_start, band_end, has_bands = select_band_window(
        central_data.spectrum.energies,
        cfg.fermi_energy,
        band_window_size,
        num_orbitals,
    )
    screening_occupations =
        fermi_dirac(central_data.spectrum.energies, cfg.fermi_energy, cfg.temperature)
    has_window =
        has_bands && has_active_transition(
            central_data.spectrum.energies,
            screening_occupations,
            cfg.photon_energies,
            cfg.broadening,
            cfg.transition_window_factor,
            band_start,
            band_end,
        )
    has_window || return (false, nothing, 1, 0)

    _prepare_wilson_loop_response_cache!(
        ws,
        kpoint,
        finite_difference_vectors,
        wannier_centers_fractional,
        cfg,
        model,
        spatial_dimension,
    )
    band_start, band_end, has_bands = select_band_window(
        central_data.spectrum.energies,
        cfg.fermi_energy,
        band_window_size,
        num_orbitals,
    )
    has_bands || return (false, nothing, 1, 0)
    band_start, band_end = expand_band_window_for_groups(band_start, band_end, central_data)
    compute_wilson_loop_shift_current_from_cache!(
        ws.response_kernel,
        ws,
        band_start,
        band_end,
        cfg.finite_difference_step,
        spatial_dimension,
    )
    occupations = fermi_dirac(central_data.spectrum.energies, cfg.fermi_energy, cfg.temperature)
    occupation_differences =
        reshape(occupations, num_orbitals, 1) .- reshape(occupations, 1, num_orbitals)
    return (true, occupation_differences, band_start, band_end)
end

# Prepare Wilson current components using an existing active transition screen and its band window.
function _wilson_prepare_current_kernel_from_transition_screen!(
    ws::WilsonLoopResponseWorkspace,
    kpoint::Vector{Float64},
    transition_screen::TransitionScreenWorkspace,
    finite_difference_vectors::Matrix{Float64},
    wannier_centers_fractional::Matrix{Float64},
    cfg::EffectiveTaskConfig,
    model::AbstractResponseModel,
    spatial_dimension::Int,
    ;
    tensor_components = nothing,
)
    transition_screen.active || return (false, 1, 0)
    central_data = ws.central_data
    if tensor_components === nothing
        _prepare_wilson_loop_response_cache!(
            ws,
            kpoint,
            finite_difference_vectors,
            wannier_centers_fractional,
            cfg,
            model,
            spatial_dimension,
        )
    else
        axes = sort!(unique!(Int[component[1] for component in tensor_components]))
        _prepare_wilson_loop_response_cache!(
            ws,
            kpoint,
            finite_difference_vectors,
            wannier_centers_fractional,
            cfg,
            model,
            spatial_dimension,
            axes = axes,
        )
    end
    band_start = transition_screen.band_start
    band_end = transition_screen.band_end
    band_start, band_end = expand_band_window_for_groups(band_start, band_end, central_data)
    if tensor_components === nothing
        compute_wilson_loop_shift_current_from_cache!(
            ws.response_kernel,
            ws,
            band_start,
            band_end,
            cfg.finite_difference_step,
            spatial_dimension,
            active_pair_mask = transition_screen.active_pair_mask,
        )
    else
        fill!(ws.response_kernel, COMPLEX_ZERO)
        for component in tensor_components
            compute_wilson_loop_shift_current_from_cache!(
                ws.response_kernel,
                ws,
                band_start,
                band_end,
                cfg.finite_difference_step,
                spatial_dimension,
                active_pair_mask = transition_screen.active_pair_mask,
                tensor_indices = component,
            )
        end
    end
    return (true, band_start, band_end)
end

# Prepare Wilson transport at central/shifted points for the requested shift-vector band groups and axes.
function _wilson_prepare_shift_vector_kernel!(
    ws::WilsonLoopResponseWorkspace,
    kpoint::Vector{Float64},
    finite_difference_vectors::Matrix{Float64},
    wannier_centers_fractional::Matrix{Float64},
    cfg::EffectiveTaskConfig,
    model::AbstractResponseModel,
    band_selection::Tuple{Vector{Int}, Vector{Int}},
    spatial_dimension::Int,
)
    central_data = ws.central_data
    _prepare_wilson_loop_response_cache!(
        ws,
        kpoint,
        finite_difference_vectors,
        wannier_centers_fractional,
        cfg,
        model,
        spatial_dimension,
    )

    band_start, band_end = band_selection_window(band_selection)
    band_start, band_end = expand_band_window_for_groups(band_start, band_end, central_data)
    compute_wilson_loop_shift_vector_from_cache!(
        ws.shift_vector_response_kernel,
        ws,
        band_start,
        band_end,
        cfg.finite_difference_step,
        spatial_dimension,
    )
    return true
end

# Accumulate an active point's Wilson current spectrum in its deterministic lane with the configured response prefactor.
function _run_integral_wilson_loop_shift_current_family!(
    kpoint::Vector{Float64},
    transition_screen::TransitionScreenWorkspace,
    worker_id::Int,
    model::AbstractResponseModel,
    ws::WilsonLoopResponseWorkspace,
    finite_difference_vectors::Matrix{Float64},
    wannier_centers_fractional::Matrix{Float64},
    state,
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
    ok, band_start, band_end = _wilson_prepare_current_kernel_from_transition_screen!(
        ws,
        kpoint,
        transition_screen,
        finite_difference_vectors,
        wannier_centers_fractional,
        cfg,
        model,
        spatial_dimension,
        tensor_components = components,
    )
    if !ok
        Threads.atomic_add!(counter.skipped, 1)
        return false
    end
    prefactor =
        kpoint_weight * REDUCED_PLANCK_CONSTANT_EV_S * pi * (-ELEMENTARY_CHARGE_C)^3 /
        (2.0 * REDUCED_PLANCK_CONSTANT_J_S^2 * num_kpoints * cell_volume)
    target = integral_accumulator_target(state, worker_id, scratch_worker_id)
    if components === nothing
        accumulate_conventional_response!(
            target,
            ws.response_kernel,
            transition_screen.occupation_differences,
            transition_screen.delta,
            prefactor,
            band_start,
            band_end,
            spatial_dimension,
        )
    else
        for component in components, energy_index in axes(transition_screen.delta, 1)
            target[(energy_index, component...)...] += conventional_component_response(
                ws.response_kernel,
                transition_screen.occupation_differences,
                @view(transition_screen.delta[energy_index, :, :]),
                prefactor,
                component,
                band_start,
                band_end,
            )
        end
    end
    Threads.atomic_add!(counter.active, 1)
    return true
end

# Write a Wilson shift-vector component to one owned slice cell, retaining band-group selection and activity counters.
function _run_kslice_wilson_loop_shift_vector_family!(
    kpoint::Vector{Float64},
    u_index::Int,
    v_index::Int,
    worker_id::Int,
    model::AbstractResponseModel,
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
        axes = (tensor_indices[1],),
    )
    band_start, band_end = band_selection_window(band_selection)
    band_start, band_end = expand_band_window_for_groups(band_start, band_end, ws.central_data)
    compute_wilson_loop_shift_vector_from_cache!(
        ws.shift_vector_response_kernel,
        ws,
        band_start,
        band_end,
        cfg.finite_difference_step,
        spatial_dimension,
        tensor_indices = tensor_indices,
    )
    return _accumulate_kslice_wilson_loop_shift_vector_from_cache!(
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

# Accumulate kslice wilson loop shift vector from cache into caller-owned storage.
function _accumulate_kslice_wilson_loop_shift_vector_from_cache!(
    u_index::Int,
    v_index::Int,
    worker_id::Int,
    ws::WilsonLoopResponseWorkspace,
    state,
    band_selection::Tuple{Vector{Int}, Vector{Int}},
    tensor_indices::Vector{Int},
    counter::BundleFamilyCounter,
)
    state === nothing && return false
    state.worker_data[worker_id][u_index, v_index] =
        shift_vector_component(ws.shift_vector_response_kernel, band_selection, tensor_indices)
    Threads.atomic_add!(counter.active, 1)
    return true
end

# Write the screened Wilson current component to one owned slice cell using occupation/delta weights.
function _run_kslice_wilson_loop_shift_current_family!(
    kpoint::Vector{Float64},
    transition_screen::TransitionScreenWorkspace,
    u_index::Int,
    v_index::Int,
    worker_id::Int,
    model::AbstractResponseModel,
    ws::WilsonLoopResponseWorkspace,
    finite_difference_vectors::Matrix{Float64},
    wannier_centers_fractional::Matrix{Float64},
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
    _prepare_wilson_loop_response_cache!(
        ws,
        kpoint,
        finite_difference_vectors,
        wannier_centers_fractional,
        cfg,
        model,
        spatial_dimension,
        axes = component_plan.derivative_axes,
    )
    return _accumulate_kslice_wilson_loop_shift_current_from_cache!(
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

# Accumulate kslice wilson loop shift current from cache into caller-owned storage.
function _accumulate_kslice_wilson_loop_shift_current_from_cache!(
    u_index::Int,
    v_index::Int,
    worker_id::Int,
    ws::WilsonLoopResponseWorkspace,
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
    band_start = transition_screen.band_start
    band_end = transition_screen.band_end
    band_start, band_end = expand_band_window_for_groups(band_start, band_end, central_data)
    compute_wilson_loop_shift_current_from_cache!(
        ws.response_kernel,
        ws,
        band_start,
        band_end,
        cfg.finite_difference_step,
        spatial_dimension,
        active_pair_mask = transition_screen.active_pair_mask,
        tensor_indices = tensor_indices,
    )
    occupation_differences = transition_screen.occupation_differences
    delta = @view transition_screen.delta[1, :, :]
    prefactor =
        REDUCED_PLANCK_CONSTANT_EV_S * pi * (-ELEMENTARY_CHARGE_C)^3 /
        (2.0 * REDUCED_PLANCK_CONSTANT_J_S^2 * num_kpoints * cell_volume)
    state.worker_data[worker_id][u_index, v_index] = conventional_component_response(
        ws.response_kernel,
        occupation_differences,
        delta,
        prefactor,
        tensor_indices,
        band_start,
        band_end,
    )
    Threads.atomic_add!(counter.active, 1)
    return true
end
