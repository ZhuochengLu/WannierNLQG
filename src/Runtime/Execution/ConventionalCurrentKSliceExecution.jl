# Share one screened matrix point across requested conventional charge/spin current tasks and write their owned slice cells.
function _run_kslice_conventional_current_family!(
    kpoint::Vector{Float64},
    transition_screen::TransitionScreenWorkspace,
    u_index::Int,
    v_index::Int,
    worker_id::Int,
    model::AbstractResponseModel,
    ws::ShiftCurrentConventionalWorkspace,
    injection_qg::Union{Nothing, Array{ComplexF64, 5}},
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

    pair_selection = transition_screen
    selected = (;
        active_pair_count = transition_screen.active_pairs_nmajor_length,
        derivative_pair_count = transition_screen.derivative_required_pairs_nmajor_length,
    )
    if selected.active_pair_count == 0
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
    # Selected external transitions always use explicit stable pair lists.
    # Intermediate-state sums and the shared screen remain untouched.
    active_pairs_nmajor = pair_selection.active_pairs_nmajor
    active_pairs_mmajor = pair_selection.active_pairs_mmajor
    derivative_required_pairs_nmajor = pair_selection.derivative_required_pairs_nmajor
    if sc_state !== nothing
        compute_conventional_shift_current_kernel!(
            ws.response_kernel,
            ws.generalized_position_derivative,
            data,
            band_start,
            band_end,
            num_orbitals,
            spatial_dimension,
            active_pair_mask = pair_selection.active_pair_mask,
            active_pairs_nmajor = active_pairs_nmajor,
            active_pair_count = selected.active_pair_count,
            derivative_required_pairs_nmajor = derivative_required_pairs_nmajor,
            derivative_pair_count = selected.derivative_pair_count,
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
            active_pair_count = selected.active_pair_count,
        )
    end
    if ic_state !== nothing
        compute_injection_current_kernel!(
            injection_qg,
            data,
            band_start,
            band_end,
            spatial_dimension,
            active_pair_mask = pair_selection.active_pair_mask,
            active_pairs_nmajor = active_pairs_nmajor,
            active_pair_count = selected.active_pair_count,
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
            active_pair_count = selected.active_pair_count,
        )
    end
    if isc_state !== nothing
        # Pauli-normalized ordered-field rate; conjugate ordering, tau, and hbar/2 are external.
        # After multiplication by -|e|, the identity channel has the same prefactor as IC.
        prefactor =
            pi * ELEMENTARY_CHARGE_C^2 / (REDUCED_PLANCK_CONSTANT_J_S^2 * num_kpoints * cell_volume)
        isc_state.worker_data[worker_id][u_index, v_index] = injection_spin_current_component(
            data,
            occupation_differences,
            delta,
            prefactor,
            tensor_indices,
            band_start,
            band_end,
            active_pair_mask = pair_selection.active_pair_mask,
            active_pairs_nmajor = active_pairs_nmajor,
            active_pair_count = selected.active_pair_count,
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
            active_pair_mask = pair_selection.active_pair_mask,
            active_pairs_nmajor = active_pairs_nmajor,
            active_pair_count = selected.active_pair_count,
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
            active_pair_count = selected.active_pair_count,
        )
    end
    Threads.atomic_add!(counter.active, 1)
    return true
end
