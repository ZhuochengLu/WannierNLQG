"""
Construct unregularized dipoles and generalized derivatives for SHG in Hamiltonian gauge.

The endpoint denominators are unbroadened; intermediate commutators use eta.
The optional finite-eta correction is Eq. (19), PRB 103, 247101. All arrays use
ordered (n,m,position_axis,derivative_axis) indices and Angstrom/eV units.
No charge, volume, occupation or k-point normalization is applied.
"""
function optical_position_vertices(data, eta, eta_correction)
    energies = data.spectrum.energies
    connection = data.internal_connection
    velocity = data.hamiltonian_derivatives
    count = length(energies)
    bare = zeros(ComplexF64, count, count, 3)
    regular = similar(bare)
    dipole = similar(bare)
    derivative = zeros(ComplexF64, count, count, 3, 3)
    for m in 1:count, n in 1:count, a in 1:3
        difference = energies[m] - energies[n]
        bare[n, m, a] = abs(difference) < 1.0e-7 ? 0 : velocity[n, m, a] / difference
        regular[n, m, a] = velocity[n, m, a] * (difference / (difference^2 + eta^2))
        dipole[n, m, a] = connection[n, m, a] + im * bare[n, m, a]
    end
    for a in 1:3, b in 1:3
        commutator_a =
            connection[:, :, a] * regular[:, :, b] - regular[:, :, b] * connection[:, :, a]
        commutator_h = velocity[:, :, a] * regular[:, :, b] - regular[:, :, b] * velocity[:, :, a]
        for m in 1:count, n in 1:count
            n == m && continue
            difference = energies[m] - energies[n]
            abs(difference) < 1.0e-12 && continue
            sum_a =
                commutator_a[n, m] - (connection[n, n, a] - connection[m, m, a]) * regular[n, m, b]
            sum_h = commutator_h[n, m] - (velocity[n, n, a] - velocity[m, m, a]) * regular[n, m, b]
            value =
                data.internal_connection_derivatives[n, m, a, b] +
                sum_a +
                (connection[n, n, a] - connection[m, m, a]) * bare[n, m, b] +
                (connection[n, n, b] - connection[m, m, b]) * bare[n, m, a] -
                im * connection[n, m, a] * (connection[n, n, b] - connection[m, m, b]) +
                im / difference * (
                    data.hamiltonian_second_derivatives[n, m, a, b] +
                    sum_h +
                    bare[n, m, a] * (real(velocity[n, n, b]) - real(velocity[m, m, b])) +
                    bare[n, m, b] * (real(velocity[n, n, a]) - real(velocity[m, m, a]))
                )
            if eta_correction
                for p in 1:count
                    (p == n || p == m) && continue
                    value +=
                        eta^2 / ((energies[p] - energies[m])^2 + eta^2) / difference * (
                            connection[n, p, a] * velocity[p, m, b] -
                            (
                                velocity[n, p, a] +
                                im * (energies[n] - energies[p]) * connection[n, p, a]
                            ) * connection[p, m, b]
                        )
                    value -=
                        eta^2 / ((energies[n] - energies[p])^2 + eta^2) / difference * (
                            velocity[n, p, b] * connection[p, m, a] -
                            connection[n, p, b] * (
                                velocity[p, m, a] +
                                im * (energies[p] - energies[m]) * connection[p, m, a]
                            )
                        )
                end
            end
            derivative[n, m, a, b] = value
        end
    end
    return dipole, connection + im * regular, derivative, bare
end
