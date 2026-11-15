"""Jerk's complete ordered Cartesian components; optical input slots are not averaged."""
const JERK_CURRENT_COMPONENTS=[(a, b, c, d) for a in 1:3 for b in 1:3 for c in 1:3 for d in 1:3]

"""
Accumulate the positive-energy acceleration channel, theory 9.20, in raw eV/Angstrom units.

Output axes are (energy,component). The optical product is r_nm^b r_mn^c,
with b:+omega, c:-omega and d:0. The Hessian always uses all retained model bands;
band windows affect only absorption pairs. No lifetime or conjugate-order factor
is inserted. The gap regularization is shared by dipoles and Hessians.
An optional external selection restricts only source m and target n; all geometry
and virtual-state contributions are still prepared from the full model.
"""
function jerk_current_response!(
    output,
    geometry::Union{ThirdOrderGeometry, JerkCurrentGeometry},
    occupations,
    data,
    energies,
    components;
    fermi_energy,
    temperature,
    broadening,
    gaussian,
    regularization,
    transition_window_factor,
    band_window_size,
    projection = :ordered,
    external_selection = nothing,
    band_window = nothing,
)
    fill!(output, 0)
    prepare_jerk_current_geometry!(geometry, data; regularization)
    bands=data.spectrum.energies
    fermi_dirac!(occupations, bands, fermi_energy, temperature)
    lo,
    hi=band_window === nothing ?
       select_band_window(bands, fermi_energy, band_window_size, length(bands)) : band_window
    for m in lo:hi, n in lo:hi
        external_selection === nothing ||
            (external_selection.valence_mask[m] && external_selection.conduction_mask[n]) ||
            continue
        gap=bands[n]-bands[m]
        gap>0 || continue
        occupation=occupations[m]-occupations[n]
        for (energy_index, energy) in enumerate(energies)
            transition_window_factor>0 &&
                abs(gap-energy)>transition_window_factor*broadening &&
                continue
            weight=occupation*second_harmonic_delta(gap-energy, broadening, gaussian)
            for (component_index, (a, b, c, d)) in enumerate(components)
                optical=geometry.dipoles[n, m, b]*geometry.dipoles[m, n, c]
                if projection!=:ordered
                    reverse=geometry.dipoles[n, m, c]*geometry.dipoles[m, n, b]
                    optical=projection==:symmetric ? (optical+reverse)/2 : (optical-reverse)/2
                end
                output[
                    energy_index,
                    component_index,
                ]+=weight*optical*(geometry.hessians[n, a, d]-geometry.hessians[m, a, d])
            end
        end
    end
    return output
end
