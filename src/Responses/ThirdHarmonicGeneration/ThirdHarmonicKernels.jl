"""
Evaluate both formalizations with G38 observable lowering and input permutation averaging.

Output axes are (energy,component,term,observable,formulation). Observable slots
are conductivity then susceptibility; formulation slots are unregrouped then
regrouped. Raw Fourier units include factor 8 through the kernels' i prefactors.
Charge, hbar, primitive-cell measure and k weights are applied exactly once by Runtime.
"""
function third_harmonic_response!(
    output,
    workspace::ThirdHarmonicWorkspace,
    data,
    energies,
    components;
    fermi_energy,
    temperature,
    policy,
    eta_correction,
    exact_occupations,
    formulation = :both,
)
    formulation in (:both, :unregrouped, :regrouped) ||
        throw(ArgumentError("unknown third-harmonic formulation"))
    fill!(output, 0)
    prepare_third_order_band_geometry!(workspace.geometry, data; regularization = policy.gap_width)
    bands=data.spectrum.energies
    harmonic_occupations!(
        workspace.occupations,
        workspace.geometry,
        bands,
        fermi_energy,
        temperature,
        exact_occupations,
    )
    prepare_third_order_combined_geometry!(
        workspace.geometry,
        data;
        regularization = policy.gap_width,
        eta_correction,
    )
    for (component_index, (phi, c, b, a)) in enumerate(components)
        permutations=((c, b, a), (c, a, b), (b, c, a), (b, a, c), (a, c, b), (a, b, c))
        for (energy_index, energy) in enumerate(energies), triple in permutations
            component=(phi, triple...)
            third_harmonic_vertices!(workspace, policy, energy, component, bands)
            formulation!=:regrouped &&
                third_harmonic_unregrouped!(workspace, policy, energy, component, bands)
            formulation!=:unregrouped &&
                third_harmonic_regrouped!(workspace, policy, energy, component, bands)
            for form in 1:2
                (form==1 && formulation==:regrouped || form==2 && formulation==:unregrouped) &&
                    continue
                for term in 1:4, degree in 0:3
                    coefficient=workspace.coefficients[term, degree + 1, form]/6
                    output[
                        energy_index,
                        component_index,
                        term,
                        1,
                        form,
                    ]+=coefficient*harmonic_low_pole(policy, energy, degree)
                    output[
                        energy_index,
                        component_index,
                        term,
                        2,
                        form,
                    ]+=coefficient*(im/3)*harmonic_low_pole(policy, energy, degree+1)
                end
            end
        end
    end
    return output
end
