# Accumulate only the raw tensor components touched by the invariant basis.
function _accumulate_selected_conventional_shift_current!(
    target,
    components,
    ws,
    data,
    transition_screen,
    prefactor,
    band_start,
    band_end,
    num_orbitals,
    spatial_dimension,
)
    active_pairs_nmajor =
        transition_screen.use_active_pair_list ? transition_screen.active_pairs_nmajor : nothing
    active_pairs_mmajor =
        transition_screen.use_active_pair_list ? transition_screen.active_pairs_mmajor : nothing
    derivative_pairs =
        transition_screen.use_active_pair_list ?
        transition_screen.derivative_required_pairs_nmajor : nothing
    for component in components
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
            derivative_required_pairs_nmajor = derivative_pairs,
            derivative_pair_count = transition_screen.derivative_required_pairs_nmajor_length,
            tensor_indices = component,
            _generalized_derivative_scratch = ws.generalized_derivative_scratch,
        )
        for energy_index in axes(transition_screen.delta, 1)
            target[(energy_index, component...)...] += conventional_component_response(
                ws.response_kernel,
                transition_screen.occupation_differences,
                @view(transition_screen.delta[energy_index, :, :]),
                prefactor,
                component,
                band_start,
                band_end,
                active_pairs_mmajor = active_pairs_mmajor,
                active_pair_count = transition_screen.active_pairs_mmajor_length,
            )
        end
    end
    return target
end

# Accumulate selected raw injection-current tensor components.
function _accumulate_selected_injection_current!(
    target,
    components,
    response_kernel,
    data,
    transition_screen,
    prefactor,
    band_start,
    band_end,
    spatial_dimension,
)
    active_pairs =
        transition_screen.use_active_pair_list ? transition_screen.active_pairs_nmajor : nothing
    for component in components
        compute_injection_current_kernel!(
            response_kernel,
            data,
            band_start,
            band_end,
            spatial_dimension,
            active_pair_mask = transition_screen.active_pair_mask,
            active_pairs_nmajor = active_pairs,
            active_pair_count = transition_screen.active_pairs_nmajor_length,
            tensor_indices = component,
        )
        for energy_index in axes(transition_screen.delta, 1)
            target[(energy_index, component...)...] += injection_current_component(
                response_kernel,
                transition_screen.occupation_differences,
                @view(transition_screen.delta[energy_index, :, :]),
                prefactor,
                component,
                band_start,
                band_end,
                active_pairs_nmajor = active_pairs,
                active_pair_count = transition_screen.active_pairs_nmajor_length,
            )
        end
    end
    return target
end

# Accumulate selected raw injection-spin-current tensor components.
function _accumulate_selected_injection_spin_current!(
    target,
    components,
    response_kernel,
    data,
    transition_screen,
    prefactor,
    band_start,
    band_end,
    spatial_dimension,
)
    active_pairs =
        transition_screen.use_active_pair_list ? transition_screen.active_pairs_nmajor : nothing
    for component in components
        compute_injection_spin_current_kernel!(
            response_kernel,
            data,
            band_start,
            band_end,
            spatial_dimension,
            active_pair_mask = transition_screen.active_pair_mask,
            active_pairs_nmajor = active_pairs,
            active_pair_count = transition_screen.active_pairs_nmajor_length,
            tensor_indices = component,
        )
        for energy_index in axes(transition_screen.delta, 1)
            target[(energy_index, component...)...] += injection_spin_current_component(
                response_kernel,
                transition_screen.occupation_differences,
                @view(transition_screen.delta[energy_index, :, :]),
                prefactor,
                component,
                band_start,
                band_end,
                active_pairs_nmajor = active_pairs,
                active_pair_count = transition_screen.active_pairs_nmajor_length,
            )
        end
    end
    return target
end

# Accumulate selected raw shift-spin-current tensor components.
function _accumulate_selected_shift_spin_current!(
    target,
    components,
    ws,
    data,
    transition_screen,
    cfg,
    prefactor,
    band_start,
    band_end,
    spatial_dimension,
)
    active_pairs =
        transition_screen.use_active_pair_list ? transition_screen.active_pairs_nmajor : nothing
    for component in components
        compute_shift_spin_current_vertices!(
            ws,
            cfg.denominator_regularization,
            spatial_dimension,
            tensor_indices = component,
        )
        compute_shift_spin_current_kernel!(
            ws,
            band_start,
            band_end,
            spatial_dimension;
            active_pair_mask = transition_screen.active_pair_mask,
            active_pairs_nmajor = active_pairs,
            active_pair_count = transition_screen.active_pairs_nmajor_length,
            tensor_indices = component,
        )
        for energy_index in axes(transition_screen.delta, 1)
            target[(energy_index, component...)...] += shift_spin_current_component(
                ws.response_kernel,
                transition_screen.occupation_differences,
                @view(transition_screen.delta[energy_index, :, :]),
                data.energy_differences,
                cfg.denominator_regularization,
                prefactor,
                component,
                band_start,
                band_end,
                active_pairs_nmajor = active_pairs,
                active_pair_count = transition_screen.active_pairs_nmajor_length,
            )
        end
    end
    return target
end

# Evaluate active conventional charge/spin current tasks at one point and accumulate into their assigned deterministic lane buffers.
function _run_integral_conventional_current_family!(
    kpoint::Vector{Float64},
    transition_screen::TransitionScreenWorkspace,
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
    cfg::EffectiveTaskConfig,
    num_kpoints::Int,
    cell_volume::Float64,
    num_orbitals::Int,
    spatial_dimension::Int,
    counter::BundleFamilyCounter,
    ;
    kpoint_weight::Int = 1,
    scratch_worker_id::Int = worker_id,
)
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
    delta = transition_screen.delta
    use_active_pair_list = transition_screen.use_active_pair_list
    active_pairs_nmajor = use_active_pair_list ? transition_screen.active_pairs_nmajor : nothing
    active_pairs_mmajor = use_active_pair_list ? transition_screen.active_pairs_mmajor : nothing
    derivative_required_pairs_nmajor =
        use_active_pair_list ? transition_screen.derivative_required_pairs_nmajor : nothing

    if sc_state !== nothing
        # Length-gauge formula prefactor with e_el=-|ELEMENTARY_CHARGE_C| and eV delta conversion.
        prefactor =
            kpoint_weight * REDUCED_PLANCK_CONSTANT_EV_S * pi * (-ELEMENTARY_CHARGE_C)^3 /
            (2.0 * REDUCED_PLANCK_CONSTANT_J_S^2 * num_kpoints * cell_volume)
        target = integral_accumulator_target(sc_state, worker_id, scratch_worker_id)
        components = integral_symmetry_component_vectors(sc_state)
        if components === nothing
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
                _generalized_derivative_scratch = ws.generalized_derivative_scratch,
            )
            accumulate_conventional_response!(
                target,
                ws.response_kernel,
                occupation_differences,
                delta,
                prefactor,
                band_start,
                band_end,
                spatial_dimension,
                active_pairs_mmajor = active_pairs_mmajor,
                active_pair_count = transition_screen.active_pairs_mmajor_length,
                frequency_weights = ws.frequency_weights,
                _frequency_contraction_scratch = ws.frequency_contraction_scratch,
            )
        else
            _accumulate_selected_conventional_shift_current!(
                target,
                components,
                ws,
                data,
                transition_screen,
                prefactor,
                band_start,
                band_end,
                num_orbitals,
                spatial_dimension,
            )
        end
    end

    if ic_state !== nothing
        # One ordered-field injection rate; the conjugate-order factor 2 and tau are external.
        prefactor =
            kpoint_weight * -pi * ELEMENTARY_CHARGE_C^3 /
            (REDUCED_PLANCK_CONSTANT_J_S^2 * num_kpoints * cell_volume)
        target = integral_accumulator_target(ic_state, worker_id, scratch_worker_id)
        components = integral_symmetry_component_vectors(ic_state)
        if components === nothing
            compute_injection_current_kernel!(
                injection_qg,
                data,
                band_start,
                band_end,
                spatial_dimension,
                active_pair_mask = transition_screen.active_pair_mask,
                active_pairs_nmajor = active_pairs_nmajor,
                active_pair_count = transition_screen.active_pairs_nmajor_length,
            )
            accumulate_injection_current_response!(
                target,
                injection_qg,
                occupation_differences,
                delta,
                prefactor,
                band_start,
                band_end,
                spatial_dimension,
                active_pairs_nmajor = active_pairs_nmajor,
                active_pair_count = transition_screen.active_pairs_nmajor_length,
                frequency_weight_scratch = ws.frequency_weights,
                _frequency_contraction_scratch = ws.frequency_contraction_scratch,
            )
        else
            _accumulate_selected_injection_current!(
                target,
                components,
                injection_qg,
                data,
                transition_screen,
                prefactor,
                band_start,
                band_end,
                spatial_dimension,
            )
        end
    end

    if isc_state !== nothing
        # Pauli-normalized ordered-field rate; conjugate ordering, tau, and hbar/2 are external.
        # After multiplication by -|e|, the identity channel has the same prefactor as IC.
        prefactor =
            kpoint_weight * pi * ELEMENTARY_CHARGE_C^2 /
            (REDUCED_PLANCK_CONSTANT_J_S^2 * num_kpoints * cell_volume)
        target = integral_accumulator_target(isc_state, worker_id, scratch_worker_id)
        components = integral_symmetry_component_vectors(isc_state)
        if components === nothing
            compute_injection_spin_current_kernel!(
                spin_injection_qg,
                data,
                band_start,
                band_end,
                spatial_dimension,
                active_pair_mask = transition_screen.active_pair_mask,
                active_pairs_nmajor = active_pairs_nmajor,
                active_pair_count = transition_screen.active_pairs_nmajor_length,
            )
            accumulate_injection_spin_current_response!(
                target,
                spin_injection_qg,
                occupation_differences,
                delta,
                prefactor,
                band_start,
                band_end,
                spatial_dimension,
                active_pairs_nmajor = active_pairs_nmajor,
                active_pair_count = transition_screen.active_pairs_nmajor_length,
                frequency_weight_scratch = ws.frequency_weights,
                _frequency_contraction_scratch = ws.spin_frequency_contraction_scratch,
            )
        else
            _accumulate_selected_injection_spin_current!(
                target,
                components,
                spin_injection_qg,
                data,
                transition_screen,
                prefactor,
                band_start,
                band_end,
                spatial_dimension,
            )
        end
    end

    if ssc_state !== nothing
        # Pauli-normalized (+omega,-omega) ordered-field response; hbar/2 is external.
        # For S=I, multiplying by -|e| gives the same (a,b,c) SC component only in the
        # nondegenerate resonant eta -> 0 limit.
        prefactor =
            kpoint_weight * 1.0im * REDUCED_PLANCK_CONSTANT_EV_S * pi * ELEMENTARY_CHARGE_C^2 /
            (2.0 * REDUCED_PLANCK_CONSTANT_J_S^2 * num_kpoints * cell_volume)
        target = integral_accumulator_target(ssc_state, worker_id, scratch_worker_id)
        components = integral_symmetry_component_vectors(ssc_state)
        if components === nothing
            compute_shift_spin_current_vertices!(
                shift_spin_ws,
                cfg.denominator_regularization,
                spatial_dimension,
            )
            compute_shift_spin_current_kernel!(
                shift_spin_ws,
                band_start,
                band_end,
                spatial_dimension;
                active_pair_mask = transition_screen.active_pair_mask,
                active_pairs_nmajor = active_pairs_nmajor,
                active_pair_count = transition_screen.active_pairs_nmajor_length,
            )
            accumulate_shift_spin_current_response!(
                target,
                shift_spin_ws.response_kernel,
                occupation_differences,
                delta,
                data.energy_differences,
                cfg.denominator_regularization,
                prefactor,
                band_start,
                band_end,
                spatial_dimension,
                active_pairs_nmajor = active_pairs_nmajor,
                active_pair_count = transition_screen.active_pairs_nmajor_length,
                frequency_weights = shift_spin_ws.frequency_weights,
                frequency_pair_weights = shift_spin_ws.frequency_pair_weights,
                _frequency_contraction_scratch = shift_spin_ws.frequency_contraction_scratch,
            )
        else
            _accumulate_selected_shift_spin_current!(
                target,
                components,
                shift_spin_ws,
                data,
                transition_screen,
                cfg,
                prefactor,
                band_start,
                band_end,
                spatial_dimension,
            )
        end
    end

    Threads.atomic_add!(counter.active, 1)
    return true
end

# Skip inactive points or prepare Projector derivatives and the screened shift-current kernel, returning the valid band window.
function _projector_prepare_current_kernel!(
    ws::ProjectorResponseWorkspace,
    kpoint::Vector{Float64},
    transition_screen::TransitionScreenWorkspace,
    finite_difference_vectors::Matrix{Float64},
    cfg::EffectiveTaskConfig,
    model::TightBindingModel,
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
    model::TightBindingModel,
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
    model::TightBindingModel,
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

# Build both k±q/2 spectra, screen occupations/energies, and prepare geometric-loop current links and insertions when active.
function _geometric_loop_prepare_current_kernel!(
    ws::GeometricLoopResponseWorkspace,
    kpoint::Vector{Float64},
    photon_momentum_fractional::Vector{Float64},
    finite_difference_vectors::Matrix{Float64},
    wannier_centers_fractional::Matrix{Float64},
    cfg::EffectiveTaskConfig,
    model::TightBindingModel,
    num_orbitals::Int,
    spatial_dimension::Int,
    band_window_size::Int,
)
    scratch = ws.scratch
    valence_central_data = ws.valence_central_data
    conduction_central_data = ws.conduction_central_data
    kv_0P = kpoint - 0.5 * photon_momentum_fractional
    kc_0P = kpoint + 0.5 * photon_momentum_fractional
    compute_spectrum!(valence_central_data.common, scratch.matrix_elements, model, kv_0P)
    compute_spectrum!(conduction_central_data.common, scratch.matrix_elements, model, kc_0P)

    conduction_occupations =
        fermi_dirac(conduction_central_data.spectrum.energies, cfg.fermi_energy, cfg.temperature)
    valence_occupations =
        fermi_dirac(valence_central_data.spectrum.energies, cfg.fermi_energy, cfg.temperature)
    # Shift_Current convention: rows are valence n, columns are conduction m.
    occupation_differences =
        reshape(valence_occupations, num_orbitals, 1) .-
        reshape(conduction_occupations, 1, num_orbitals)
    dE =
        reshape(conduction_central_data.spectrum.energies, 1, num_orbitals) .-
        reshape(valence_central_data.spectrum.energies, num_orbitals, 1)
    photon_energies = Float64[x for x in cfg.photon_energies]
    df3 = reshape(occupation_differences, 1, num_orbitals, num_orbitals)
    delta_arg_screen =
        reshape(dE, 1, num_orbitals, num_orbitals) .-
        reshape(photon_energies, length(photon_energies), 1, 1)
    has_window = any(
        (abs.(df3) .> 1e-10) .&
        (abs.(delta_arg_screen) .< cfg.transition_window_factor * cfg.broadening),
    )
    has_window || return (false, occupation_differences, dE)

    compute_kpoint!(
        valence_central_data,
        scratch,
        model,
        kv_0P;
        denominator_regularization = cfg.denominator_regularization,
        spatial_dimension = spatial_dimension,
    )
    compute_kpoint!(
        conduction_central_data,
        scratch,
        model,
        kc_0P;
        denominator_regularization = cfg.denominator_regularization,
        spatial_dimension = spatial_dimension,
    )
    mark_degenerate_groups!(valence_central_data, cfg.degeneracy_threshold)
    mark_degenerate_groups!(conduction_central_data, cfg.degeneracy_threshold)

    energies_relative_to_fermi = valence_central_data.spectrum.energies .- cfg.fermi_energy
    valence_fermi_index = searchsortedlast(energies_relative_to_fermi, 0.0)
    if valence_fermi_index < 1 || valence_fermi_index >= num_orbitals
        return (false, occupation_differences, dE)
    end
    band_start = max(1, valence_fermi_index - band_window_size + 1)
    band_end = min(num_orbitals, valence_fermi_index + band_window_size)
    band_start, band_end = expand_band_window_for_groups(
        band_start,
        band_end,
        valence_central_data,
        conduction_central_data,
    )

    compute_geometric_loop_shift_current_kernel!(
        ws,
        kpoint,
        photon_momentum_fractional,
        finite_difference_vectors,
        wannier_centers_fractional,
        cfg.denominator_regularization,
        cfg.finite_difference_step,
        spatial_dimension,
        model,
        band_start,
        band_end,
    )
    return (true, occupation_differences, dE)
end

# Reuse a central transition screen, expand degenerate band windows and prepare selected geometric-loop current components.
function _geometric_loop_prepare_current_kernel_from_transition_screen!(
    ws::GeometricLoopResponseWorkspace,
    kpoint::Vector{Float64},
    transition_screen::TransitionScreenWorkspace,
    photon_momentum_fractional::Vector{Float64},
    finite_difference_vectors::Matrix{Float64},
    wannier_centers_fractional::Matrix{Float64},
    cfg::EffectiveTaskConfig,
    model::TightBindingModel,
    num_orbitals::Int,
    spatial_dimension::Int,
    ;
    tensor_indices::Union{Nothing, AbstractVector{<:Integer}} = nothing,
    tensor_components = nothing,
)
    tensor_indices !== nothing &&
        tensor_components !== nothing &&
        error("provide tensor_indices or tensor_components, not both")
    transition_screen.active || return (false, 1, 0)
    scratch = ws.scratch
    valence_central_data = ws.valence_central_data
    conduction_central_data = ws.conduction_central_data
    kv_0P = kpoint - 0.5 * photon_momentum_fractional
    kc_0P = kpoint + 0.5 * photon_momentum_fractional

    compute_kpoint!(
        valence_central_data,
        scratch,
        model,
        kv_0P;
        denominator_regularization = cfg.denominator_regularization,
        spatial_dimension = spatial_dimension,
    )
    compute_kpoint!(
        conduction_central_data,
        scratch,
        model,
        kc_0P;
        denominator_regularization = cfg.denominator_regularization,
        spatial_dimension = spatial_dimension,
    )
    mark_degenerate_groups!(valence_central_data, cfg.degeneracy_threshold)
    mark_degenerate_groups!(conduction_central_data, cfg.degeneracy_threshold)

    band_start = transition_screen.band_start
    band_end = transition_screen.band_end
    band_start, band_end = expand_band_window_for_groups(
        band_start,
        band_end,
        valence_central_data,
        conduction_central_data,
    )

    if tensor_components === nothing
        compute_geometric_loop_shift_current_kernel!(
            ws,
            kpoint,
            photon_momentum_fractional,
            finite_difference_vectors,
            wannier_centers_fractional,
            cfg.denominator_regularization,
            cfg.finite_difference_step,
            spatial_dimension,
            model,
            band_start,
            band_end,
            active_pair_mask = transition_screen.active_pair_mask,
            tensor_indices = tensor_indices,
        )
    else
        fill!(ws.response_kernel, COMPLEX_ZERO)
        for component in tensor_components
            compute_geometric_loop_shift_current_kernel!(
                ws,
                kpoint,
                photon_momentum_fractional,
                finite_difference_vectors,
                wannier_centers_fractional,
                cfg.denominator_regularization,
                cfg.finite_difference_step,
                spatial_dimension,
                model,
                band_start,
                band_end,
                active_pair_mask = transition_screen.active_pair_mask,
                tensor_indices = component,
            )
        end
    end
    return (true, band_start, band_end)
end

# Reuse cross-momentum screening and band windows while preparing finite-q geometric-loop current links and insertions.
function _geometric_loop_prepare_current_kernel_from_photon_drag_transition_screen!(
    ws::GeometricLoopResponseWorkspace,
    kpoint::Vector{Float64},
    photon_drag_screen::PhotonDragTransitionScreenWorkspace,
    photon_momentum_fractional::Vector{Float64},
    finite_difference_vectors::Matrix{Float64},
    wannier_centers_fractional::Matrix{Float64},
    cfg::EffectiveTaskConfig,
    model::TightBindingModel,
    num_orbitals::Int,
    spatial_dimension::Int,
    band_window_size::Int,
    ;
    tensor_indices::Union{Nothing, AbstractVector{<:Integer}} = nothing,
)
    photon_drag_screen.active || return (false, 1, 0)
    scratch = ws.scratch
    valence_central_data = ws.valence_central_data
    conduction_central_data = ws.conduction_central_data

    compute_kpoint!(
        valence_central_data,
        scratch,
        model,
        photon_drag_screen.valence_kpoint;
        denominator_regularization = cfg.denominator_regularization,
        spatial_dimension = spatial_dimension,
    )
    compute_kpoint!(
        conduction_central_data,
        scratch,
        model,
        photon_drag_screen.conduction_kpoint;
        denominator_regularization = cfg.denominator_regularization,
        spatial_dimension = spatial_dimension,
    )
    mark_degenerate_groups!(valence_central_data, cfg.degeneracy_threshold)
    mark_degenerate_groups!(conduction_central_data, cfg.degeneracy_threshold)

    energies_relative_to_fermi = valence_central_data.spectrum.energies .- cfg.fermi_energy
    valence_fermi_index = searchsortedlast(energies_relative_to_fermi, 0.0)
    if valence_fermi_index < 1 || valence_fermi_index >= num_orbitals
        return (false, 1, 0)
    end
    band_start = max(1, valence_fermi_index - band_window_size + 1)
    band_end = min(num_orbitals, valence_fermi_index + band_window_size)
    band_start, band_end = expand_band_window_for_groups(
        band_start,
        band_end,
        valence_central_data,
        conduction_central_data,
    )

    Responses.compute_geometric_loop_photon_drag_shift_current_kernel!(
        ws,
        kpoint,
        photon_momentum_fractional,
        finite_difference_vectors,
        wannier_centers_fractional,
        cfg.denominator_regularization,
        cfg.finite_difference_step,
        spatial_dimension,
        model,
        band_start,
        band_end,
        active_pair_mask = photon_drag_screen.active_pair_mask,
        tensor_indices = tensor_indices,
    )
    return (true, band_start, band_end)
end

# Accumulate the active geometric-loop current spectrum into the point's assigned lane with frequency-denominator and integration factors.
function _run_integral_geometric_loop_shift_current_family!(
    kpoint::Vector{Float64},
    worker_id::Int,
    model::TightBindingModel,
    ws::GeometricLoopResponseWorkspace,
    photon_momentum_fractional::Vector{Float64},
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
    ;
    kpoint_weight::Int = 1,
    scratch_worker_id::Int = worker_id,
    transition_screen = nothing,
    photon_drag_transition_screen = nothing,
)
    state === nothing && return false
    components = integral_symmetry_component_vectors(state)
    ok = false
    occupation_differences = nothing
    delta = nothing
    if transition_screen !== nothing
        ok, _band_start, _band_end = _geometric_loop_prepare_current_kernel_from_transition_screen!(
            ws,
            kpoint,
            transition_screen,
            photon_momentum_fractional,
            finite_difference_vectors,
            wannier_centers_fractional,
            cfg,
            model,
            num_orbitals,
            spatial_dimension,
            tensor_components = components,
        )
        occupation_differences = transition_screen.occupation_differences
        delta = transition_screen.delta
    elseif photon_drag_transition_screen !== nothing
        ok, _band_start, _band_end =
            _geometric_loop_prepare_current_kernel_from_photon_drag_transition_screen!(
                ws,
                kpoint,
                photon_drag_transition_screen,
                photon_momentum_fractional,
                finite_difference_vectors,
                wannier_centers_fractional,
                cfg,
                model,
                num_orbitals,
                spatial_dimension,
                band_window_size,
            )
        occupation_differences = photon_drag_transition_screen.occupation_differences
        delta = photon_drag_transition_screen.delta
    else
        local dE
        ok, occupation_differences, dE = _geometric_loop_prepare_current_kernel!(
            ws,
            kpoint,
            photon_momentum_fractional,
            finite_difference_vectors,
            wannier_centers_fractional,
            cfg,
            model,
            num_orbitals,
            spatial_dimension,
            band_window_size,
        )
        if ok
            num_photon_energies = length(cfg.photon_energies)
            photon_energies = Float64[x for x in cfg.photon_energies]
            delta_arg =
                reshape(dE, 1, num_orbitals, num_orbitals) .-
                reshape(photon_energies, num_photon_energies, 1, 1)
            delta = _smearing(delta_arg, cfg.broadening_type, cfg.broadening)
        end
    end
    if !ok
        Threads.atomic_add!(counter.skipped, 1)
        return false
    end
    photon_energies = Float64[x for x in cfg.photon_energies]
    frequency_denominator_weights =
        real((photon_energies .+ 1.0im * cfg.denominator_regularization) .^ (-1)) .^ 2
    # Velocity-gauge reduced prefactor.  The two velocity vertices use
    # v_H=i*dE_eV*r_H, so the corresponding hbar_eV_seconds conversion is
    # already absorbed into the matrix elements.
    prefactor =
        kpoint_weight * pi * ELEMENTARY_CHARGE_C /
        (REDUCED_PLANCK_CONSTANT_EV_S * num_kpoints * cell_volume)
    target = integral_accumulator_target(state, worker_id, scratch_worker_id)
    if components === nothing
        accumulate_geometric_loop_shift_current_response!(
            target,
            ws.response_kernel,
            reshape(occupation_differences, 1, num_orbitals, num_orbitals),
            delta,
            frequency_denominator_weights,
            prefactor,
            num_orbitals,
            spatial_dimension,
        )
    else
        for component in components, energy_index in axes(delta, 1)
            target[(energy_index, component...)...] += geometric_loop_sck_component(
                ws.response_kernel,
                occupation_differences,
                @view(delta[energy_index, :, :]),
                frequency_denominator_weights[energy_index],
                prefactor,
                component,
                num_orbitals,
            )
        end
    end
    Threads.atomic_add!(counter.active, 1)
    return true
end

# Write one screened geometric-loop current component to the worker's owned slice cell and update family counters.
function _run_kslice_geometric_loop_shift_current_family!(
    kpoint::Vector{Float64},
    transition_screen,
    u_index::Int,
    v_index::Int,
    worker_id::Int,
    model::TightBindingModel,
    ws::GeometricLoopResponseWorkspace,
    photon_momentum_fractional::Vector{Float64},
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
    ok = false
    if transition_screen isa TransitionScreenWorkspace
        ok, _, _ = _geometric_loop_prepare_current_kernel_from_transition_screen!(
            ws,
            kpoint,
            transition_screen,
            photon_momentum_fractional,
            finite_difference_vectors,
            wannier_centers_fractional,
            cfg,
            model,
            num_orbitals,
            spatial_dimension,
            tensor_indices = tensor_indices,
        )
    else
        ok, _, _ = _geometric_loop_prepare_current_kernel_from_photon_drag_transition_screen!(
            ws,
            kpoint,
            transition_screen,
            photon_momentum_fractional,
            finite_difference_vectors,
            wannier_centers_fractional,
            cfg,
            model,
            num_orbitals,
            spatial_dimension,
            band_window_size,
            tensor_indices = tensor_indices,
        )
    end
    if !ok
        Threads.atomic_add!(counter.skipped, 1)
        return false
    end
    occupation_differences = transition_screen.occupation_differences
    delta = @view transition_screen.delta[1, :, :]
    frequency_denominator_weight =
        real((first(cfg.photon_energies) + 1.0im * cfg.denominator_regularization)^(-1))^2
    prefactor =
        pi * ELEMENTARY_CHARGE_C / (REDUCED_PLANCK_CONSTANT_EV_S * num_kpoints * cell_volume)
    state.worker_data[worker_id][u_index, v_index] = geometric_loop_sck_component(
        ws.response_kernel,
        occupation_differences,
        delta,
        frequency_denominator_weight,
        prefactor,
        tensor_indices,
        num_orbitals,
    )
    Threads.atomic_add!(counter.active, 1)
    return true
end

# Prepare the finite-loop cache and requested band-group shift-vector component without current-response frequency contraction.
function _geometric_loop_prepare_shift_vector_kernel!(
    ws::GeometricLoopResponseWorkspace,
    kpoint::Vector{Float64},
    photon_momentum_fractional::Vector{Float64},
    finite_difference_vectors::Matrix{Float64},
    wannier_centers_fractional::Matrix{Float64},
    cfg::EffectiveTaskConfig,
    model::TightBindingModel,
    band_selection::Tuple{Vector{Int}, Vector{Int}},
    num_orbitals::Int,
    spatial_dimension::Int,
    ;
    tensor_indices::Union{Nothing, AbstractVector{<:Integer}} = nothing,
)
    scratch = ws.scratch
    valence_central_data = ws.valence_central_data
    conduction_central_data = ws.conduction_central_data
    kv_0P = kpoint - 0.5 * photon_momentum_fractional
    kc_0P = kpoint + 0.5 * photon_momentum_fractional
    compute_spectrum!(valence_central_data.common, scratch.matrix_elements, model, kv_0P)
    compute_spectrum!(conduction_central_data.common, scratch.matrix_elements, model, kc_0P)
    compute_kpoint!(
        valence_central_data,
        scratch,
        model,
        kv_0P;
        denominator_regularization = cfg.denominator_regularization,
        spatial_dimension = spatial_dimension,
    )
    compute_kpoint!(
        conduction_central_data,
        scratch,
        model,
        kc_0P;
        denominator_regularization = cfg.denominator_regularization,
        spatial_dimension = spatial_dimension,
    )
    mark_degenerate_groups!(valence_central_data, cfg.degeneracy_threshold)
    mark_degenerate_groups!(conduction_central_data, cfg.degeneracy_threshold)

    band_start, band_end = band_selection_window(band_selection)
    band_start, band_end = expand_band_window_for_groups(
        band_start,
        band_end,
        valence_central_data,
        conduction_central_data,
    )
    compute_geometric_loop_shift_vector_kernel!(
        ws,
        kpoint,
        photon_momentum_fractional,
        finite_difference_vectors,
        wannier_centers_fractional,
        cfg.denominator_regularization,
        cfg.finite_difference_step,
        spatial_dimension,
        model,
        band_start,
        band_end,
        tensor_indices = tensor_indices,
    )
    return true
end

# Evaluate the requested geometric-loop shift vector at one slice point and write its worker-local cell.
function _run_kslice_geometric_loop_shift_vector_family!(
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
    _geometric_loop_prepare_shift_vector_kernel!(
        ws,
        kpoint,
        photon_momentum_fractional,
        finite_difference_vectors,
        wannier_centers_fractional,
        cfg,
        model,
        band_selection,
        num_orbitals,
        spatial_dimension,
        tensor_indices = tensor_indices,
    )
    state.worker_data[worker_id][u_index, v_index] =
        shift_vector_component(ws.response_kernel, band_selection, tensor_indices)
    Threads.atomic_add!(counter.active, 1)
    return true
end

# Screen a central eigensystem, prepare Wilson links, expand degenerate band windows and return current-kernel occupation weights.
function _wilson_prepare_current_kernel!(
    ws::WilsonLoopResponseWorkspace,
    kpoint::Vector{Float64},
    finite_difference_vectors::Matrix{Float64},
    wannier_centers_fractional::Matrix{Float64},
    cfg::EffectiveTaskConfig,
    model::TightBindingModel,
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
    model::TightBindingModel,
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
    model::TightBindingModel,
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
    model::TightBindingModel,
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
    model::TightBindingModel,
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

# Build separate momentum-leg spectra and screened occupations before constructing finite-q injection overlaps and vertices.
function _photon_drag_injection_prepare_kernel!(
    ws::PhotonDragInjectionCurrentConventionalWorkspace,
    kpoint::Vector{Float64},
    photon_momentum_fractional::Vector{Float64},
    wannier_centers_fractional::Matrix{Float64},
    cfg::EffectiveTaskConfig,
    model::TightBindingModel,
    num_orbitals::Int,
    spatial_dimension::Int,
)
    valence_kpoint = kpoint .- 0.5 .* photon_momentum_fractional
    conduction_kpoint = kpoint .+ 0.5 .* photon_momentum_fractional
    compute_spectrum!(ws.valence_data, ws.scratch, model, valence_kpoint)
    compute_spectrum!(ws.conduction_data, ws.scratch, model, conduction_kpoint)
    valence_band_start, valence_band_end, conduction_band_start, conduction_band_end, has_bands =
        photon_drag_band_windows(
            ws.valence_data.spectrum.energies,
            ws.conduction_data.spectrum.energies,
            cfg.fermi_energy,
            cfg.band_window_size,
            num_orbitals,
        )
    valence_screening_occupations =
        fermi_dirac(ws.valence_data.spectrum.energies, cfg.fermi_energy, cfg.temperature)
    conduction_screening_occupations =
        fermi_dirac(ws.conduction_data.spectrum.energies, cfg.fermi_energy, cfg.temperature)
    has_window =
        has_bands && photon_drag_has_active_transition(
            ws.valence_data.spectrum.energies,
            ws.conduction_data.spectrum.energies,
            valence_screening_occupations,
            conduction_screening_occupations,
            cfg.photon_energies,
            cfg.broadening,
            cfg.transition_window_factor,
            valence_band_start,
            valence_band_end,
            conduction_band_start,
            conduction_band_end,
        )
    has_window || return (false, valence_kpoint, conduction_kpoint, 1, 0, 1, 0)

    compute_kpoint!(
        ws.valence_data,
        ws.scratch,
        model,
        valence_kpoint;
        denominator_regularization = cfg.denominator_regularization,
        spatial_dimension = spatial_dimension,
    )
    compute_kpoint!(
        ws.conduction_data,
        ws.scratch,
        model,
        conduction_kpoint;
        denominator_regularization = cfg.denominator_regularization,
        spatial_dimension = spatial_dimension,
    )
    valence_band_start, valence_band_end, conduction_band_start, conduction_band_end, has_bands =
        photon_drag_band_windows(
            ws.valence_data.spectrum.energies,
            ws.conduction_data.spectrum.energies,
            cfg.fermi_energy,
            cfg.band_window_size,
            num_orbitals,
        )
    has_bands || return (false, valence_kpoint, conduction_kpoint, 1, 0, 1, 0)
    compute_photon_drag_injection_current_kernel!(
        ws.response_kernel,
        ws.forward_velocity_vertex,
        ws.backward_velocity_vertex,
        ws.overlap_1,
        ws.overlap_2,
        ws.valence_data,
        ws.conduction_data,
        valence_kpoint,
        conduction_kpoint,
        wannier_centers_fractional,
        ws.explicit_center_phase_enabled,
        valence_band_start,
        valence_band_end,
        conduction_band_start,
        conduction_band_end,
        num_orbitals,
        spatial_dimension,
    )
    return (
        true,
        valence_kpoint,
        conduction_kpoint,
        valence_band_start,
        valence_band_end,
        conduction_band_start,
        conduction_band_end,
    )
end

# Reuse the finite-q transition screen to prepare injection overlaps/vertices and its compact ordered-pair kernel.
function _photon_drag_injection_prepare_kernel_from_transition_screen!(
    ws::PhotonDragInjectionCurrentConventionalWorkspace,
    photon_drag_screen::PhotonDragTransitionScreenWorkspace,
    wannier_centers_fractional::Matrix{Float64},
    cfg::EffectiveTaskConfig,
    model::TightBindingModel,
    num_orbitals::Int,
    spatial_dimension::Int,
    ;
    tensor_indices::Union{Nothing, AbstractVector{<:Integer}} = nothing,
)
    photon_drag_screen.active || return (false, 1, 0, 1, 0)

    compute_kpoint!(
        ws.valence_data,
        ws.scratch,
        model,
        photon_drag_screen.valence_kpoint;
        denominator_regularization = cfg.denominator_regularization,
        spatial_dimension = spatial_dimension,
    )
    compute_kpoint!(
        ws.conduction_data,
        ws.scratch,
        model,
        photon_drag_screen.conduction_kpoint;
        denominator_regularization = cfg.denominator_regularization,
        spatial_dimension = spatial_dimension,
    )
    valence_band_start = photon_drag_screen.valence_band_start
    valence_band_end = photon_drag_screen.valence_band_end
    conduction_band_start = photon_drag_screen.conduction_band_start
    conduction_band_end = photon_drag_screen.conduction_band_end
    photon_drag_screen.has_bands || return (false, 1, 0, 1, 0)
    active_pairs_nmajor =
        photon_drag_screen.use_active_pair_list ? photon_drag_screen.active_pairs_nmajor : nothing
    compute_photon_drag_injection_current_kernel!(
        ws.response_kernel,
        ws.forward_velocity_vertex,
        ws.backward_velocity_vertex,
        ws.overlap_1,
        ws.overlap_2,
        ws.valence_data,
        ws.conduction_data,
        photon_drag_screen.valence_kpoint,
        photon_drag_screen.conduction_kpoint,
        wannier_centers_fractional,
        ws.explicit_center_phase_enabled,
        valence_band_start,
        valence_band_end,
        conduction_band_start,
        conduction_band_end,
        num_orbitals,
        spatial_dimension,
        active_pair_mask = photon_drag_screen.active_pair_mask,
        active_pairs_nmajor = active_pairs_nmajor,
        active_pair_count = photon_drag_screen.active_pairs_nmajor_length,
        tensor_indices = tensor_indices,
        _matrix_scratch_1 = ws.matrix_scratch_1,
        _matrix_scratch_2 = ws.matrix_scratch_2,
    )
    return (true, valence_band_start, valence_band_end, conduction_band_start, conduction_band_end)
end

# Accumulate finite-q injection kernels into the assigned integral lane, preserving separate valence/conduction windows and pair order.
function _run_integral_photon_drag_injection_current_family!(
    kpoint::Vector{Float64},
    photon_drag_transition_screen::PhotonDragTransitionScreenWorkspace,
    worker_id::Int,
    model::TightBindingModel,
    ws::PhotonDragInjectionCurrentConventionalWorkspace,
    photon_momentum_fractional::Vector{Float64},
    wannier_centers_fractional::Matrix{Float64},
    state,
    tensor_indices::Vector{Int},
    cfg::EffectiveTaskConfig,
    num_kpoints::Int,
    cell_volume::Float64,
    num_orbitals::Int,
    spatial_dimension::Int,
    counter::BundleFamilyCounter,
)
    state === nothing && return false
    ok, valence_band_start, valence_band_end, conduction_band_start, conduction_band_end =
        _photon_drag_injection_prepare_kernel_from_transition_screen!(
            ws,
            photon_drag_transition_screen,
            wannier_centers_fractional,
            cfg,
            model,
            num_orbitals,
            spatial_dimension,
        )
    if !ok
        Threads.atomic_add!(counter.skipped, 1)
        return false
    end
    # One ordered-field injection rate; the conjugate-order factor 2 and tau are external.
    prefactor =
        -pi * ELEMENTARY_CHARGE_C / (REDUCED_PLANCK_CONSTANT_EV_S^2 * num_kpoints * cell_volume)
    accumulate_photon_drag_injection_current_response!(
        state.worker_data[worker_id],
        ws.response_kernel,
        photon_drag_transition_screen.occupation_differences,
        photon_drag_transition_screen.delta,
        ws.frequency_denominator_weights,
        prefactor,
        valence_band_start,
        valence_band_end,
        conduction_band_start,
        conduction_band_end,
        spatial_dimension,
        active_pairs_nmajor = photon_drag_transition_screen.use_active_pair_list ?
                              photon_drag_transition_screen.active_pairs_nmajor : nothing,
        active_pair_count = photon_drag_transition_screen.active_pairs_nmajor_length,
        frequency_weight_scratch = ws.frequency_weight_scratch,
        _frequency_contraction_scratch = ws.frequency_contraction_scratch,
    )
    Threads.atomic_add!(counter.active, 1)
    return true
end

# Write the selected finite-q injection component at one owned slice point after cross-leg screening.
function _run_kslice_photon_drag_injection_current_family!(
    kpoint::Vector{Float64},
    photon_drag_transition_screen::PhotonDragTransitionScreenWorkspace,
    u_index::Int,
    v_index::Int,
    worker_id::Int,
    model::TightBindingModel,
    ws::PhotonDragInjectionCurrentConventionalWorkspace,
    photon_momentum_fractional::Vector{Float64},
    wannier_centers_fractional::Matrix{Float64},
    state,
    tensor_indices::Vector{Int},
    cfg::EffectiveTaskConfig,
    num_kpoints::Int,
    cell_volume::Float64,
    num_orbitals::Int,
    spatial_dimension::Int,
    counter::BundleFamilyCounter,
)
    state === nothing && return false
    ok, valence_band_start, valence_band_end, conduction_band_start, conduction_band_end =
        _photon_drag_injection_prepare_kernel_from_transition_screen!(
            ws,
            photon_drag_transition_screen,
            wannier_centers_fractional,
            cfg,
            model,
            num_orbitals,
            spatial_dimension,
            tensor_indices = tensor_indices,
        )
    if !ok
        Threads.atomic_add!(counter.skipped, 1)
        return false
    end
    occupation_differences = photon_drag_transition_screen.occupation_differences
    delta = @view photon_drag_transition_screen.delta[1, :, :]
    frequency_denominator_weight = first(ws.frequency_denominator_weights)
    # One ordered-field injection rate; the conjugate-order factor 2 and tau are external.
    prefactor =
        -pi * ELEMENTARY_CHARGE_C / (REDUCED_PLANCK_CONSTANT_EV_S^2 * num_kpoints * cell_volume)
    state.worker_data[worker_id][u_index, v_index] = photon_drag_injection_current_component(
        ws.response_kernel,
        occupation_differences,
        delta,
        frequency_denominator_weight,
        prefactor,
        tensor_indices,
        valence_band_start,
        valence_band_end,
        conduction_band_start,
        conduction_band_end,
        active_pairs_nmajor = photon_drag_transition_screen.use_active_pair_list ?
                              photon_drag_transition_screen.active_pairs_nmajor : nothing,
        active_pair_count = photon_drag_transition_screen.active_pairs_nmajor_length,
    )
    Threads.atomic_add!(counter.active, 1)
    return true
end
