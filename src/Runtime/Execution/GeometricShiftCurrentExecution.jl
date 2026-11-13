
# Build both k±q/2 spectra, screen occupations/energies, and prepare geometric-loop current links and insertions when active.
function _geometric_loop_prepare_current_kernel!(
    ws::GeometricLoopResponseWorkspace,
    kpoint::Vector{Float64},
    photon_momentum_fractional::Vector{Float64},
    finite_difference_vectors::Matrix{Float64},
    wannier_centers_fractional::Matrix{Float64},
    cfg::EffectiveTaskConfig,
    model::AbstractResponseModel,
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
    mark_geometric_response_groups!(valence_central_data, cfg.degeneracy_threshold)
    mark_geometric_response_groups!(conduction_central_data, cfg.degeneracy_threshold)

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
    model::AbstractResponseModel,
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
    mark_geometric_response_groups!(valence_central_data, cfg.degeneracy_threshold)
    mark_geometric_response_groups!(conduction_central_data, cfg.degeneracy_threshold)

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
    model::AbstractResponseModel,
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

    if MatrixElements.supports_active_velocity_insertions(
        model,
        wannier_centers_fractional,
        spatial_dimension,
    )
        compute_spectrum!(
            valence_central_data.common,
            scratch.matrix_elements,
            model,
            photon_drag_screen.valence_kpoint,
        )
        compute_spectrum!(
            conduction_central_data.common,
            scratch.matrix_elements,
            model,
            photon_drag_screen.conduction_kpoint,
        )
    else
        compute_kpoint!(
            valence_central_data,
            scratch,
            model,
            photon_drag_screen.valence_kpoint;
            denominator_regularization = cfg.denominator_regularization,
            spatial_dimension = scratch.matrix_elements.plan.spatial_dimension,
        )
        compute_kpoint!(
            conduction_central_data,
            scratch,
            model,
            photon_drag_screen.conduction_kpoint;
            denominator_regularization = cfg.denominator_regularization,
            spatial_dimension = scratch.matrix_elements.plan.spatial_dimension,
        )
    end
    mark_geometric_response_groups!(valence_central_data, cfg.degeneracy_threshold)
    mark_geometric_response_groups!(conduction_central_data, cfg.degeneracy_threshold)

    band_start, band_end = 1, num_orbitals

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
        use_full_velocity_vertices = true,
        optical_q_cartesian = cfg.photon_momentum,
    )
    return (true, band_start, band_end)
end

# Accumulate the active geometric-loop current spectrum into the point's assigned lane with frequency-denominator and integration factors.
function _run_integral_geometric_loop_shift_current_family!(
    kpoint::Vector{Float64},
    worker_id::Int,
    model::AbstractResponseModel,
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
    photon_drag_delta = nothing,
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
        occupation_differences = photon_drag_transition_screen.weighted_occupation_differences
        delta =
            photon_drag_delta === nothing ? photon_drag_transition_screen.delta : photon_drag_delta
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
        photon_drag_transition_screen === nothing ?
        real((photon_energies .+ 1.0im * cfg.denominator_regularization) .^ (-1)) .^ 2 :
        ones(Float64, length(photon_energies))
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
    model::AbstractResponseModel,
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
    occupation_differences =
        transition_screen isa PhotonDragTransitionScreenWorkspace ?
        transition_screen.weighted_occupation_differences : transition_screen.occupation_differences
    delta = @view transition_screen.delta[1, :, :]
    frequency_denominator_weight =
        transition_screen isa PhotonDragTransitionScreenWorkspace ? 1.0 :
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
    model::AbstractResponseModel,
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
    mark_geometric_response_groups!(valence_central_data, cfg.degeneracy_threshold)
    mark_geometric_response_groups!(conduction_central_data, cfg.degeneracy_threshold)

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
    model::AbstractResponseModel,
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
