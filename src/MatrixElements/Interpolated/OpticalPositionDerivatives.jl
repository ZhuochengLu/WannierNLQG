"""
Fill Hamiltonian-gauge optical vertices with one combined cutoff numerator.

D0/r0 and D_eta/r_eta have explicit roles. For each needed ordered pair, assemble
G=R+I0*(iN+K), where K includes the optional finite-eta correction exactly once.
R retains all finite raw-connection terms. Bare division is performed only by
I0; no small-gap skip removes R. Active pairs control outer G only, never the
complete intermediate-band sums. All storage is caller-owned, in eV/Angstrom;
no occupation, charge, volume or k-point factor is applied. An optional parts
consumer receives ordered off-diagonal R/Q/I0/d after the complete numerator is
assembled. derivative=nothing avoids materializing G.
"""
function optical_position_vertices!(
    bare,
    regular,
    dipole,
    regular_dipole,
    derivative,
    commutator_a,
    commutator_h,
    data,
    eta,
    eta_correction;
    active_pairs = nothing,
    consume_parts = nothing,
)
    energies = data.spectrum.energies
    connection = data.internal_connection
    velocity = data.hamiltonian_derivatives
    count = length(energies)
    eigenvector_corrections!(bare, energies, velocity, Val(:bare))
    eigenvector_corrections!(regular, energies, velocity, Val(:regularized), eta)
    position_vertices!(dipole, connection, bare)
    regular_dipole === nothing || position_vertices!(regular_dipole, connection, regular)
    derivative === nothing || fill!(derivative, 0)
    for a in 1:3, b in 1:3
        @views mul!(commutator_a, connection[:, :, a], regular[:, :, b])
        @views mul!(commutator_a, regular[:, :, b], connection[:, :, a], -1, 1)
        @views mul!(commutator_h, velocity[:, :, a], regular[:, :, b])
        @views mul!(commutator_h, regular[:, :, b], velocity[:, :, a], -1, 1)
        for m in 1:count, n in 1:count
            n == m && continue
            active_pairs !== nothing && !active_pairs[n, m] && continue
            difference = energies[m] - energies[n]
            sum_a =
                commutator_a[n, m] - (connection[n, n, a] - connection[m, m, a]) * regular[n, m, b]
            sum_h = commutator_h[n, m] - (velocity[n, n, a] - velocity[m, m, a]) * regular[n, m, b]
            finite =
                data.internal_connection_derivatives[n, m, a, b] +
                sum_a +
                (connection[n, n, a] - connection[m, m, a]) * bare[n, m, b] +
                (connection[n, n, b] - connection[m, m, b]) * bare[n, m, a] -
                im * connection[n, m, a] * (connection[n, n, b] - connection[m, m, b])
            numerator =
                im * (
                    data.hamiltonian_second_derivatives[n, m, a, b] +
                    sum_h +
                    bare[n, m, a] * real(velocity[n, n, b] - velocity[m, m, b]) +
                    bare[n, m, b] * real(velocity[n, n, a] - velocity[m, m, a])
                )
            if eta_correction
                for p in 1:count
                    (p == n || p == m) && continue
                    numerator +=
                        regularized_energy_weight(energies[p] - energies[m], eta) * (
                            connection[n, p, a] * velocity[p, m, b] -
                            (
                                velocity[n, p, a] +
                                im * (energies[n] - energies[p]) * connection[n, p, a]
                            ) * connection[p, m, b]
                        )
                    numerator -=
                        regularized_energy_weight(energies[n] - energies[p], eta) * (
                            velocity[n, p, b] * connection[p, m, a] -
                            connection[n, p, b] * (
                                velocity[p, m, a] +
                                im * (energies[p] - energies[m]) * connection[p, m, a]
                            )
                        )
                end
            end
            inverse = bare_energy_inverse(difference)
            if derivative !== nothing
                derivative[n, m, a, b] = iszero(inverse) ? finite : finite + inverse * numerator
            end
            consume_parts === nothing ||
                consume_parts(n, m, a, b, finite, numerator, inverse, difference)
        end
    end
    return nothing
end

"""
Construct bare/regularized optical dipoles and the literature Gcut for SHG.

This allocating expert entry uses the same output-first kernel as THG. Its tuple
is (r0, r_eta, Gcut, D0). Eta is finite positive; eta_correction selects only the
C numerator, never a second derivative prescription or normalization.
"""
function optical_position_vertices(data, eta, eta_correction; active_pairs = nothing)
    count = length(data.spectrum.energies)
    bare = zeros(ComplexF64, count, count, 3)
    regular = similar(bare)
    dipole = similar(bare)
    regular_dipole = similar(bare)
    derivative = zeros(ComplexF64, count, count, 3, 3)
    commutator_a = zeros(ComplexF64, count, count)
    commutator_h = similar(commutator_a)
    optical_position_vertices!(
        bare,
        regular,
        dipole,
        regular_dipole,
        derivative,
        commutator_a,
        commutator_h,
        data,
        eta,
        eta_correction;
        active_pairs,
    )
    return dipole, regular_dipole, derivative, bare
end

"""Return factor*Gcut from finite R, complete Q and the declared bare I0.

The caller supplies the signed factor for this ordered pair: d for DG, an
occupation difference for FG, or P_eta times a task weight for PG combinations.
Zero factors and zero I0 are handled before Q products. This is the literature
R/Q prescription, not a derivative of r_eta or an independent physical inverse.
"""
@inline function optical_derivative_combination(finite, numerator, inverse::Real, factor::Real)
    iszero(factor) && return zero(finite)
    return iszero(inverse) ? factor*finite : factor*finite+(factor*inverse)*numerator
end

"""Select the optional cutoff optical prescription without changing the legacy expert API.

Orthogonal source data already implement r0/r_eta/Gcut and forward unchanged.
Metric data require the separately requested OPTICAL_CUTOFF_VERTICES capability.
"""
cutoff_optical_position_vertices(data, eta, eta_correction; active_pairs = nothing) =
    optical_position_vertices(data, eta, eta_correction; active_pairs)
