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
    model::AbstractResponseModel,
    ws::ShiftCurrentConventionalWorkspace,
    injection_qg::Union{Nothing, Array{ComplexF64, 5}},
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
