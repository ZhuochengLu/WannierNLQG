# Return normalized Gaussian or Lorentzian delta weights in inverse-energy units; reject other broadening selectors.
function _smearing(delta_arg, broadening_type::String, broadening::Float64)
    if broadening_type == "Gaussian"
        return gaussian_broadening(delta_arg, broadening)
    elseif broadening_type == "Lorentzian"
        return lorentzian_broadening(delta_arg, broadening)
    end
    error("Unknown smearing type: $broadening_type")
end

# Fill caller-owned delta weights with normalized Gaussian/cutoff or Lorentzian values, rejecting unknown selectors.
function _smearing!(output, delta_arg, broadening_type::String, broadening::Float64)
    if broadening_type == "Gaussian"
        cutoff = broadening * sqrt(200.0)
        scale = 1.0 / (sqrt(pi) * broadening)
        @inbounds for idx in eachindex(output, delta_arg)
            x = delta_arg[idx]
            output[idx] = abs(x) < cutoff ? scale * exp(-(x / broadening)^2) : 0.0
        end
    elseif broadening_type == "Lorentzian"
        @inbounds for idx in eachindex(output, delta_arg)
            x = delta_arg[idx]
            output[idx] = (broadening / pi) / (x^2 + broadening^2)
        end
    else
        error("Unknown smearing type: $broadening_type")
    end
    return output
end

# Refresh occupations, delta weights and active transition masks for the central spectrum before recording stable pair lists.
function _fill_transition_screen!(
    screen::TransitionScreenWorkspace,
    energies::AbstractVector{<:Real},
    photon_energies::AbstractVector{<:Real},
    broadening_type::String,
    broadening::Float64,
    transition_window_factor::Float64,
)
    fill!(screen.active_pair_mask, false)
    fill!(screen.active_bands, false)
    gaussian = broadening_type == "Gaussian"
    lorentzian = broadening_type == "Lorentzian"
    gaussian || lorentzian || error("Unknown smearing type: $broadening_type")
    cutoff = broadening * sqrt(200.0)
    gaussian_scale = gaussian ? 1.0 / (sqrt(pi) * broadening) : 0.0
    transition_threshold = transition_window_factor * broadening
    screen.active = false

    num_orbitals = length(energies)
    @inbounds for n in 1:num_orbitals
        for m in 1:num_orbitals
            occupation_difference = screen.occupations[n] - screen.occupations[m]
            screen.occupation_differences[n, m] = occupation_difference
            transition_energy = energies[m] - energies[n]
            occupation_active = screen.has_bands && abs(occupation_difference) > 1.0e-10
            in_band_window =
                screen.band_start <= n <= screen.band_end &&
                screen.band_start <= m <= screen.band_end
            pair_active = occupation_active && lorentzian
            if occupation_active && in_band_window && transition_threshold <= 0
                screen.active = true
            end
            for energy_index in eachindex(photon_energies)
                delta_arg = transition_energy - photon_energies[energy_index]
                if gaussian
                    inside_cutoff = abs(delta_arg) < cutoff
                    screen.delta[energy_index, n, m] =
                        inside_cutoff ? gaussian_scale * exp(-(delta_arg / broadening)^2) : 0.0
                    pair_active |= occupation_active && inside_cutoff
                else
                    screen.delta[energy_index, n, m] =
                        (broadening / pi) / (delta_arg^2 + broadening^2)
                end
                if occupation_active &&
                   in_band_window &&
                   transition_threshold > 0 &&
                   abs(delta_arg) < transition_threshold
                    screen.active = true
                end
            end
            screen.active_pair_mask[n, m] = pair_active
        end
    end
    _record_active_transition_pairs!(screen)
    return screen
end

# Rebuild pair activity from nonzero frequency weights and occupation differences, then refresh ordered lists and valid lengths.
function _update_active_transition_pairs!(screen::TransitionScreenWorkspace)
    fill!(screen.active_pair_mask, false)
    fill!(screen.active_bands, false)
    screen.active_pairs_mmajor_length = 0
    screen.active_pairs_nmajor_length = 0
    screen.derivative_required_pairs_nmajor_length = 0
    screen.eligible_pair_count = 0
    screen.use_active_pair_list = false
    screen.has_bands || return screen
    @inbounds for m in axes(screen.active_pair_mask, 2)
        for n in axes(screen.active_pair_mask, 1)
            abs(screen.occupation_differences[n, m]) <= 1.0e-10 && continue
            active = false
            for energy_index in axes(screen.delta, 1)
                if screen.delta[energy_index, n, m] != 0.0
                    active = true
                    break
                end
            end
            active || continue
            screen.active_pair_mask[n, m] = true
        end
    end
    _record_active_transition_pairs!(screen)
    return screen
end

# Pack active pairs in stable n-major/m-major orders, update band masks and bound valid list prefixes for subsequent kernels.
function _record_active_transition_pairs!(screen::TransitionScreenWorkspace)
    fill!(screen.active_bands, false)
    screen.active_pairs_mmajor_length = 0
    screen.active_pairs_nmajor_length = 0
    screen.derivative_required_pairs_nmajor_length = 0
    screen.eligible_pair_count = 0
    screen.use_active_pair_list = false
    screen.has_bands || return screen

    @inbounds for n in screen.band_start:screen.band_end
        for m in screen.band_start:screen.band_end
            if abs(screen.occupation_differences[n, m]) > 1.0e-10
                screen.eligible_pair_count += 1
            end
            if screen.active_pair_mask[n, m]
                screen.active_pairs_nmajor_length += 1
                screen.active_pairs_nmajor[screen.active_pairs_nmajor_length] = (n, m)
                screen.active_bands[n] = true
                screen.active_bands[m] = true
            end
            if screen.active_pair_mask[n, m] || screen.active_pair_mask[m, n]
                screen.derivative_required_pairs_nmajor_length += 1
                screen.derivative_required_pairs_nmajor[screen.derivative_required_pairs_nmajor_length] =
                    (n, m)
            end
        end
    end
    @inbounds for m in screen.band_start:screen.band_end
        for n in screen.band_start:screen.band_end
            screen.active_pair_mask[n, m] || continue
            screen.active_pairs_mmajor_length += 1
            screen.active_pairs_mmajor[screen.active_pairs_mmajor_length] = (n, m)
        end
    end
    screen.use_active_pair_list = 2 * screen.active_pairs_nmajor_length < screen.eligible_pair_count
    return screen
end

# Evaluate a central spectrum, select its band window and refresh Fermi occupations, delta weights and ordered active-pair lists.
function _prepare_transition_screen!(
    screen::TransitionScreenWorkspace,
    kpoint::Vector{Float64},
    cfg::EffectiveTaskConfig,
    model::TightBindingModel,
    num_orbitals::Int,
)
    compute_spectrum!(screen.data, screen.matrix_elements, model, kpoint)
    energies = screen.data.spectrum.energies
    screen.band_start, screen.band_end, screen.has_bands =
        select_band_window(energies, cfg.fermi_energy, cfg.band_window_size, num_orbitals)
    fermi_dirac!(screen.occupations, energies, cfg.fermi_energy, cfg.temperature)
    _fill_transition_screen!(
        screen,
        energies,
        cfg.photon_energies,
        cfg.broadening_type,
        cfg.broadening,
        cfg.transition_window_factor,
    )
    return screen
end

# Rebuild pair activity from nonzero frequency weights and occupation differences, then refresh ordered lists and valid lengths.
function _update_active_transition_pairs!(screen::PhotonDragTransitionScreenWorkspace)
    fill!(screen.active_pair_mask, false)
    fill!(screen.active_valence_bands, false)
    fill!(screen.active_conduction_bands, false)
    screen.active_pairs_mmajor_length = 0
    screen.active_pairs_nmajor_length = 0
    screen.eligible_pair_count = 0
    screen.use_active_pair_list = false
    screen.has_bands || return screen
    @inbounds for m in axes(screen.active_pair_mask, 2)
        for n in axes(screen.active_pair_mask, 1)
            abs(screen.occupation_differences[n, m]) <= 1.0e-10 && continue
            active = false
            for energy_index in axes(screen.delta, 1)
                if screen.delta[energy_index, n, m] != 0.0
                    active = true
                    break
                end
            end
            active || continue
            screen.active_pair_mask[n, m] = true
        end
    end
    _record_active_transition_pairs!(screen)
    return screen
end

# Pack active pairs in stable n-major/m-major orders, update band masks and bound valid list prefixes for subsequent kernels.
function _record_active_transition_pairs!(screen::PhotonDragTransitionScreenWorkspace)
    fill!(screen.active_valence_bands, false)
    fill!(screen.active_conduction_bands, false)
    screen.active_pairs_mmajor_length = 0
    screen.active_pairs_nmajor_length = 0
    screen.eligible_pair_count = 0
    screen.use_active_pair_list = false
    screen.has_bands || return screen

    @inbounds for n in screen.valence_band_start:screen.valence_band_end
        for m in screen.conduction_band_start:screen.conduction_band_end
            if abs(screen.occupation_differences[n, m]) > 1.0e-10
                screen.eligible_pair_count += 1
            end
            screen.active_pair_mask[n, m] || continue
            screen.active_pairs_nmajor_length += 1
            screen.active_pairs_nmajor[screen.active_pairs_nmajor_length] = (n, m)
            screen.active_valence_bands[n] = true
            screen.active_conduction_bands[m] = true
        end
    end
    @inbounds for m in screen.conduction_band_start:screen.conduction_band_end
        for n in screen.valence_band_start:screen.valence_band_end
            screen.active_pair_mask[n, m] || continue
            screen.active_pairs_mmajor_length += 1
            screen.active_pairs_mmajor[screen.active_pairs_mmajor_length] = (n, m)
        end
    end
    screen.use_active_pair_list = 2 * screen.active_pairs_nmajor_length < screen.eligible_pair_count
    return screen
end

# Refresh cross-leg occupation/transition-energy/delta arrays and stable active-pair lists for finite-q injection screening.
function _fill_photon_drag_transition_screen!(
    screen::PhotonDragTransitionScreenWorkspace,
    valence_energies::AbstractVector{<:Real},
    conduction_energies::AbstractVector{<:Real},
    photon_energies::AbstractVector{<:Real},
    broadening_type::String,
    broadening::Float64,
    transition_window_factor::Float64,
)
    fill!(screen.active_pair_mask, false)
    fill!(screen.active_valence_bands, false)
    fill!(screen.active_conduction_bands, false)
    gaussian = broadening_type == "Gaussian"
    lorentzian = broadening_type == "Lorentzian"
    gaussian || lorentzian || error("Unknown smearing type: $broadening_type")
    cutoff = broadening * sqrt(200.0)
    gaussian_scale = gaussian ? 1.0 / (sqrt(pi) * broadening) : 0.0
    transition_threshold = transition_window_factor * broadening
    screen.active = false

    num_orbitals = length(valence_energies)
    @inbounds for n in 1:num_orbitals
        for m in 1:num_orbitals
            occupation_difference = screen.valence_occupations[n] - screen.conduction_occupations[m]
            screen.occupation_differences[n, m] = occupation_difference
            transition_energy = conduction_energies[m] - valence_energies[n]
            screen.transition_energies[n, m] = transition_energy
            occupation_active = screen.has_bands && abs(occupation_difference) > 1.0e-10
            in_band_window =
                screen.valence_band_start <= n <= screen.valence_band_end &&
                screen.conduction_band_start <= m <= screen.conduction_band_end
            pair_active = occupation_active && lorentzian
            if occupation_active && in_band_window && transition_threshold <= 0
                screen.active = true
            end
            for energy_index in eachindex(photon_energies)
                delta_arg = transition_energy - photon_energies[energy_index]
                if gaussian
                    inside_cutoff = abs(delta_arg) < cutoff
                    screen.delta[energy_index, n, m] =
                        inside_cutoff ? gaussian_scale * exp(-(delta_arg / broadening)^2) : 0.0
                    pair_active |= occupation_active && inside_cutoff
                else
                    screen.delta[energy_index, n, m] =
                        (broadening / pi) / (delta_arg^2 + broadening^2)
                end
                if occupation_active &&
                   in_band_window &&
                   transition_threshold > 0 &&
                   abs(delta_arg) < transition_threshold
                    screen.active = true
                end
            end
            screen.active_pair_mask[n, m] = pair_active
        end
    end
    _record_active_transition_pairs!(screen)
    return screen
end

# Evaluate both momentum legs, select their separate windows and refresh finite-q occupations and active-pair screening.
function _prepare_photon_drag_transition_screen!(
    screen::PhotonDragTransitionScreenWorkspace,
    kpoint::Vector{Float64},
    photon_momentum_fractional::Vector{Float64},
    cfg::EffectiveTaskConfig,
    model::TightBindingModel,
    num_orbitals::Int,
)
    @inbounds for a in 1:3
        half_q = 0.5 * photon_momentum_fractional[a]
        screen.valence_kpoint[a] = kpoint[a] - half_q
        screen.conduction_kpoint[a] = kpoint[a] + half_q
    end
    compute_spectrum!(screen.valence_data, screen.matrix_elements, model, screen.valence_kpoint)
    compute_spectrum!(
        screen.conduction_data,
        screen.matrix_elements,
        model,
        screen.conduction_kpoint,
    )
    valence_energies = screen.valence_data.spectrum.energies
    conduction_energies = screen.conduction_data.spectrum.energies
    screen.valence_band_start,
    screen.valence_band_end,
    screen.conduction_band_start,
    screen.conduction_band_end,
    screen.has_bands = photon_drag_band_windows(
        valence_energies,
        conduction_energies,
        cfg.fermi_energy,
        cfg.band_window_size,
        num_orbitals,
    )
    fermi_dirac!(screen.valence_occupations, valence_energies, cfg.fermi_energy, cfg.temperature)
    fermi_dirac!(
        screen.conduction_occupations,
        conduction_energies,
        cfg.fermi_energy,
        cfg.temperature,
    )
    _fill_photon_drag_transition_screen!(
        screen,
        valence_energies,
        conduction_energies,
        cfg.photon_energies,
        cfg.broadening_type,
        cfg.broadening,
        cfg.transition_window_factor,
    )
    return screen
end
