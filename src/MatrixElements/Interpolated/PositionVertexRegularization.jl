"""Bare inverse energy gap in eV^-1, with zero strictly below 1e-7 eV.

The equality belongs to the inverse branch. This numerical rule applies to
declared bare position vertices, not to independent metric/projector derivatives
or broadened frequency denominators. Test before division, including at zero.
"""
@inline bare_energy_inverse(difference::Real) =
    abs(difference) < 1.0e-7 ? zero(difference) : inv(difference)

"""Return d/(d^2+eta^2) for the regularized position role, in inverse eV.

The ordinary positive finite squared denominator keeps its original arithmetic.
Only squared underflow/overflow uses a scaled evaluation; eta is never floored,
replaced or interpreted as bare mode. Entrances validate finite positive eta.
This helper applies no bare I0 cutoff or independent projector prescription.
"""
@inline function regularized_energy_inverse(difference::Real, eta::Real)
    denominator=difference^2+eta^2
    if isfinite(denominator) && !iszero(denominator)
        return difference/denominator
    end
    if !(isfinite(difference) && isfinite(eta) && eta>0)
        return difference/denominator
    end
    scale=max(abs(difference), eta)
    scaled_difference=difference/scale
    scaled_width=eta/scale
    return (scaled_difference/(scaled_difference^2+scaled_width^2))/scale
end

"""Return eta^2/(d^2+eta^2), the dimensionless finite-eta C weight.

Retain ordinary arithmetic and scale only squared underflow/overflow. The same
finite positive eta must already be validated; there is no replacement width,
new cutoff or change to the complete C numerator or its single application.
"""
@inline function regularized_energy_weight(difference::Real, eta::Real)
    width_squared=eta^2
    denominator=difference^2+width_squared
    if isfinite(denominator) && !iszero(denominator) && !iszero(width_squared)
        return width_squared/denominator
    end
    if !(isfinite(difference) && isfinite(eta) && eta>0)
        return width_squared/denominator
    end
    scale=max(abs(difference), eta)
    scaled_difference=difference/scale
    scaled_width=eta/scale
    return scaled_width^2/(scaled_difference^2+scaled_width^2)
end

"""Fill bare D_nm=h_nm/(E_m-E_n) using the declared cutoff, in Angstrom.

Only energies and Hamiltonian derivatives are required. The caller owns storage;
no position, occupation, frame conversion or physical normalization is implied.
"""
function eigenvector_corrections!(output, energies, derivatives, ::Val{:bare})
    for axis in axes(output, 3), m in eachindex(energies), n in eachindex(energies)
        inverse = bare_energy_inverse(energies[m] - energies[n])
        output[n, m, axis] = iszero(inverse) ? 0 : derivatives[n, m, axis] * inverse
    end
    return output
end

"""Fill D_eta=h*(E_m-E_n)/((E_m-E_n)^2+eta^2), with finite positive eta in eV.

This is the regularized eigenvector correction, not the physical velocity.
Diagonal/equal-energy corrections vanish; the associated r still retains raw A.
"""
function eigenvector_corrections!(output, energies, derivatives, ::Val{:regularized}, eta)
    isfinite(eta) && eta > 0 ||
        throw(ArgumentError("position regularization must be finite and positive"))
    for axis in axes(output, 3), m in eachindex(energies), n in eachindex(energies)
        difference = energies[m] - energies[n]
        output[n, m, axis] = derivatives[n, m, axis] * regularized_energy_inverse(difference, eta)
    end
    return output
end

"""Fill r=A+iD in caller-owned storage, preserving raw A including its diagonal.

All operands must already use the same band ordering and source/working frame.
The selected D determines the explicit bare or regularized role; no derivative
prescription, occupation or charge/volume factor is added here.
"""
function position_vertices!(output, connection, correction)
    @. output = connection + im * correction
    return output
end

"""Fill complete physical V_nm=h_nm+i(E_n-E_m)A_nm in eV Angstrom.

The diagonal Hamiltonian derivative is retained. Operands and output must share
one endpoint's frame and ordered band indices. Cross-endpoint overlaps and the
factor 1/2 in a finite-q vertex belong to the response contraction, not here.
"""
function physical_velocity_vertices!(output, energies, derivatives, connection)
    for axis in axes(output, 3), m in eachindex(energies), n in eachindex(energies)
        output[n, m, axis] =
            derivatives[n, m, axis] + im * (energies[n] - energies[m]) * connection[n, m, axis]
    end
    return output
end
