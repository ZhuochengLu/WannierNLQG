"""Ordered algebraic SHG contributions; each susceptibility/conductivity total is their sum."""
const SECOND_HARMONIC_TERMS = (
    "interband_derivative",
    "interband_velocity",
    "three_band",
    "transport_derivative",
    "transport_velocity",
    "berry_curvature_dipole",
    "semiclassical",
)

"""Eighteen Cartesian components with symmetric incident-field indices, in axis-major order."""
const SECOND_HARMONIC_COMPONENTS =
    [(a, b, c) for a in 1:3 for (b, c) in ((1, 1), (2, 2), (3, 3), (2, 3), (1, 3), (1, 2))]

"""Finite-width delta kernel in inverse eV; Gaussian uses exp(-x^2), not exp(-x^2/2)."""
@inline function second_harmonic_delta(energy, width, gaussian::Bool)
    x = energy / width
    return gaussian ? exp(-x * x) / (sqrt(pi) * width) : inv(pi * width * (1 + x * x))
end

"""Real principal-value regularization x/(x^2+eta^2), including a finite zero at x=0."""
@inline second_harmonic_principal(energy, width) = energy / (energy * energy + width * width)

"""Resonant energy kernel D(x)=PV(1/x)+i*pi*delta(x); width and x use eV."""
@inline second_harmonic_resonance(energy, width, gaussian) = complex(
    second_harmonic_principal(energy, width),
    pi * second_harmonic_delta(energy, width, gaussian),
)

"""Legacy temperature switch and stable Fermi occupation; no low-temperature replacement."""
@inline function second_harmonic_occupation(energy, fermi, temperature)
    temperature <= 1.0e-7 && return energy <= fermi ? 1.0 : 0.0
    x = (energy - fermi) / (8.617333262145e-5 * temperature)
    return x >= 0 ? exp(-x) / (1 + exp(-x)) : inv(1 + exp(x))
end

"""
Evaluate seven SHG contributions at one k point into (frequency,component,term,quantity).

Quantity 1 is susceptibility before e/(eps0*volume)*1e12; quantity 2 is
conductivity before e^2/(hbar*volume). Incident-field indices are symmetric.
Frequency-dependent contractions follow separate finite-width alpha/sigma kernels.
The three-band sum is contracted before the frequency loop without truncating bands.
"""
function second_harmonic_response!(
    output,
    data,
    frequencies,
    components;
    fermi_energy,
    temperature,
    broadening,
    low_frequency_broadening,
    gaussian,
    intermediate_regularization,
    eta_correction,
    degeneracy_threshold,
)
    fill!(output, 0)
    energies = data.spectrum.energies
    velocity = data.hamiltonian_derivatives
    eta = intermediate_regularization
    dipole, regular_dipole, derivative, bare = optical_position_vertices(data, eta, eta_correction)
    count = length(energies)
    occupations = [second_harmonic_occupation(e, fermi_energy, temperature) for e in energies]
    @inbounds for n in 1:count, m in 1:count
        n == m && continue
        occupation = occupations[n] - occupations[m]
        abs(occupation) < 1.0e-10 && continue
        difference = energies[m] - energies[n]
        abs(difference) < 1.0e-12 &&
            throw(ArgumentError("Occupied SHG pair has a singular energy denominator"))
        for (component, (a, b, c)) in enumerate(components)
            first = dipole[n, m, a] * (derivative[m, n, b, c] + derivative[m, n, c, b])
            second =
                derivative[n, m, a, b] * dipole[m, n, c] + derivative[n, m, a, c] * dipole[m, n, b]
            third =
                dipole[n, m, a] * (
                    dipole[m, n, b] * real(velocity[m, m, c] - velocity[n, n, c]) +
                    dipole[m, n, c] * real(velocity[m, m, b] - velocity[n, n, b])
                ) / difference
            fourth =
                derivative[n, m, b, a] * dipole[m, n, c] + derivative[n, m, c, a] * dipole[m, n, b]
            fifth =
                real(velocity[n, n, a] - velocity[m, m, a]) *
                (dipole[n, m, b] * dipole[m, n, c] + dipole[n, m, c] * dipole[m, n, b])
            triple_first = 0.0im
            triple_other = 0.0im
            for p in 1:count
                (p == n || p == m) && continue
                triple_first +=
                    dipole[n, m, a] *
                    (
                        regular_dipole[m, p, b] * regular_dipole[p, n, c] +
                        regular_dipole[m, p, c] * regular_dipole[p, n, b]
                    ) *
                    second_harmonic_principal(2energies[p] - energies[n] - energies[m], eta)
                triple_other +=
                    regular_dipole[m, p, a] *
                    (
                        regular_dipole[p, n, b] * dipole[n, m, c] +
                        regular_dipole[p, n, c] * dipole[n, m, b]
                    ) *
                    second_harmonic_principal(2energies[n] - energies[m] - energies[p], eta)
                triple_other +=
                    regular_dipole[p, n, a] *
                    (
                        dipole[n, m, b] * regular_dipole[m, p, c] +
                        dipole[n, m, c] * regular_dipole[m, p, b]
                    ) *
                    second_harmonic_principal(2energies[m] - energies[p] - energies[n], eta)
            end
            for (frequency, energy) in enumerate(frequencies)
                d1 = second_harmonic_resonance(difference - energy, broadening, gaussian)
                d2 = second_harmonic_resonance(difference - 2energy, broadening, gaussian)
                dn = second_harmonic_resonance(-difference - energy, broadening, gaussian)
                low = second_harmonic_principal(energy, low_frequency_broadening)
                factor = 0.5im * occupation
                output[frequency, component, 1, 1] +=
                    factor / difference * (2first * d2 + second * d1 + (first + second) * low)
                output[frequency, component, 2, 1] += factor / difference * third * (d1 - 4d2 - low)
                output[frequency, component, 3, 1] +=
                    0.5occupation * (2triple_first * d2 + triple_other * dn)
                output[frequency, component, 4, 1] -= factor / difference * 0.5fourth * (d1 + low)
                output[frequency, component, 5, 1] -= factor * 0.25fifth * d1 * low^2
                output[frequency, component, 1, 2] += occupation * (first * d2 + second * d1)
                output[frequency, component, 2, 2] += occupation * third * (d1 - 2d2)
                output[frequency, component, 3, 2] -=
                    im * occupation * difference * (triple_first * d2 - triple_other * dn)
                output[frequency, component, 4, 2] -= occupation * 0.5fourth * d1
                output[frequency, component, 5, 2] -= occupation * 0.25fifth * d1 * low
            end
        end
    end
    temperature <= 1.0e-7 && return output
    second_harmonic_one_band!(
        output,
        data,
        frequencies,
        components,
        bare;
        fermi_energy,
        temperature,
        low_frequency_broadening,
        gaussian,
        eta,
        degeneracy_threshold,
    )
    return output
end

"""
Add finite-temperature semiclassical and corrected BCD terms, retaining legacy Gaussian derivatives.

Curvature F_ac is the full curl of the Hamiltonian-gauge Berry connection:
rotated connection derivative plus both commutators with the unregularized
eigenvector derivative. Consequently F_aa=0 and the BCD aaa tensor is zero.
"""
function second_harmonic_one_band!(
    output,
    data,
    frequencies,
    components,
    bare;
    fermi_energy,
    temperature,
    low_frequency_broadening,
    gaussian,
    eta,
    degeneracy_threshold,
)
    energies = data.spectrum.energies
    velocity = data.hamiltonian_derivatives
    connection = data.internal_connection
    kt = 8.617333262145e-5 * temperature
    for n in eachindex(energies)
        offset = energies[n] - fermi_energy
        abs(offset) > 5kt && continue
        first_derivative = -exp(-0.5(offset / kt)^2) / (kt * sqrt(2pi))
        second_derivative = -offset / kt^2 * first_derivative
        isolated =
            (n == 1 || energies[n] - energies[n - 1] > degeneracy_threshold) &&
            (n == length(energies) || energies[n + 1] - energies[n] > degeneracy_threshold)
        curvature = zeros(Float64, 3, 3)
        for a in 1:3, b in 1:3
            a == b && continue
            value =
                data.internal_connection_derivatives[n, n, b, a] -
                data.internal_connection_derivatives[n, n, a, b]
            for p in eachindex(energies)
                value +=
                    connection[n, p, b] * bare[p, n, a] - bare[n, p, a] * connection[p, n, b] -
                    connection[n, p, a] * bare[p, n, b] + bare[n, p, b] * connection[p, n, a] -
                    im * (bare[n, p, a] * bare[p, n, b] - bare[n, p, b] * bare[p, n, a])
            end
            curvature[a, b] = real(value)
        end
        for (component, (a, b, c)) in enumerate(components)
            hessian = real(data.hamiltonian_second_derivatives[n, n, b, c])
            for p in eachindex(energies)
                p == n && continue
                hessian +=
                    2real(velocity[n, p, b] * velocity[p, n, c]) *
                    second_harmonic_principal(energies[n] - energies[p], eta)
            end
            semiclassical =
                second_derivative *
                real(velocity[n, n, a]) *
                real(velocity[n, n, b]) *
                real(velocity[n, n, c]) + first_derivative * real(velocity[n, n, a]) * hessian
            bcd =
                isolated ?
                first_derivative * (
                    real(velocity[n, n, b]) * curvature[a, c] +
                    real(velocity[n, n, c]) * curvature[a, b]
                ) : 0.0
            for (frequency, energy) in enumerate(frequencies)
                low = second_harmonic_principal(energy, low_frequency_broadening)
                kernel =
                    low - im * second_harmonic_delta(energy, low_frequency_broadening, gaussian)
                output[frequency, component, 6, 1] -= 0.25bcd * kernel * low
                output[frequency, component, 6, 2] += 0.5im * bcd * kernel
                output[frequency, component, 7, 1] -= 0.25im * semiclassical * kernel * low^2
                output[frequency, component, 7, 2] -= 0.5semiclassical * kernel * low
            end
        end
    end
    return output
end
