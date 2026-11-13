
# Reuse the finite-q transition screen to prepare injection overlaps/vertices and its compact ordered-pair kernel.
function _photon_drag_injection_prepare_kernel_from_transition_screen!(
    ws::PhotonDragInjectionCurrentConventionalWorkspace,
    photon_drag_screen::PhotonDragTransitionScreenWorkspace,
    wannier_centers_fractional::Matrix{Float64},
    cfg::EffectiveTaskConfig,
    model::AbstractResponseModel,
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
        spatial_dimension = ws.scratch.plan.spatial_dimension,
    )
    compute_kpoint!(
        ws.conduction_data,
        ws.scratch,
        model,
        photon_drag_screen.conduction_kpoint;
        denominator_regularization = cfg.denominator_regularization,
        spatial_dimension = ws.scratch.plan.spatial_dimension,
    )
    valence_band_start = photon_drag_screen.valence_band_start
    valence_band_end = photon_drag_screen.valence_band_end
    conduction_band_start = photon_drag_screen.conduction_band_start
    conduction_band_end = photon_drag_screen.conduction_band_end
    photon_drag_screen.has_bands || return (false, 1, 0, 1, 0)
    active_pairs_nmajor =
        photon_drag_screen.use_active_pair_list ? photon_drag_screen.active_pairs_nmajor : nothing
    # Finite-q optical vertices use complete endpoint V. The common provider
    # retains intraband h_nn and the raw-A commutator in the actual source frame.
    valence_velocity_vertices =
        MatrixElements.physical_velocity_vertices(ws.valence_data; source_gauge = true)
    conduction_velocity_vertices =
        MatrixElements.physical_velocity_vertices(ws.conduction_data; source_gauge = true)
    optical_links_prepared = any(!iszero, cfg.photon_momentum)
    if optical_links_prepared
        compute_kpoint!(
            ws.optical_center_data,
            ws.scratch,
            model,
            (photon_drag_screen.valence_kpoint + photon_drag_screen.conduction_kpoint)/2;
            denominator_regularization = cfg.denominator_regularization,
            spatial_dimension = ws.scratch.plan.spatial_dimension,
        )
        for (output, left, right, momentum) in (
            (ws.overlap_1, ws.valence_data, ws.conduction_data, .-cfg.photon_momentum),
            (ws.overlap_2, ws.conduction_data, ws.valence_data, cfg.photon_momentum),
        )
            MatrixElements.compute_optical_momentum_overlap!(
                output,
                left,
                right,
                ws.optical_center_data,
                model,
                ws.scratch.plan,
                wannier_centers_fractional,
                momentum,
                ws.matrix_scratch_1,
                ws.matrix_scratch_2,
            )
        end
    end
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
        _optical_overlaps_prepared = optical_links_prepared,
        _matrix_scratch_1 = ws.matrix_scratch_1,
        _matrix_scratch_2 = ws.matrix_scratch_2,
        valence_velocity_vertices = valence_velocity_vertices,
        conduction_velocity_vertices = conduction_velocity_vertices,
    )
    complete_photon_drag_injection_degenerate_blocks!(
        ws.response_kernel,
        ws.forward_velocity_vertex,
        ws.backward_velocity_vertex,
        ws.overlap_1,
        ws.overlap_2,
        ws.valence_data,
        ws.conduction_data,
        valence_velocity_vertices,
        conduction_velocity_vertices,
        num_orbitals,
        spatial_dimension;
        active_pair_mask = photon_drag_screen.active_pair_mask,
        tensor_indices,
    )
    return (true, valence_band_start, valence_band_end, conduction_band_start, conduction_band_end)
end

# Accumulate finite-q injection kernels into the assigned integral lane, preserving separate valence/conduction windows and pair order.
function _run_integral_photon_drag_injection_current_family!(
    kpoint::Vector{Float64},
    photon_drag_transition_screen::PhotonDragTransitionScreenWorkspace,
    worker_id::Int,
    model::AbstractResponseModel,
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
    counter::BundleFamilyCounter;
    delta = photon_drag_transition_screen.delta,
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
        photon_drag_transition_screen.weighted_occupation_differences,
        delta,
        ws.frequency_contraction_weights,
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
    model::AbstractResponseModel,
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
    occupation_differences = photon_drag_transition_screen.weighted_occupation_differences
    delta = @view photon_drag_transition_screen.delta[1, :, :]
    frequency_denominator_weight = first(ws.frequency_contraction_weights)
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
