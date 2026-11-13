"""
Explicit, nondefault equal-rate Lorentz SHG research policy for a gapped T=0 model.

`width` is the positive energy damping Γ (eV) in both perturbative resolvents,
not a fitted T1/T2 relation. `occupied_count` specifies one complete insulating
subspace; the same count and chemical potential must hold at every sampled k.
This policy does not modify the compatibility SHG kernel, default or term labels.
"""
struct SameRateLorentzSHGPolicy
    width::Float64
    fermi_energy::Float64
    occupied_count::Int
    function SameRateLorentzSHGPolicy(width::Real, fermi_energy::Real, occupied_count::Integer)
        isfinite(width) && width > 0 ||
            throw(ArgumentError("SHG research Γ must be positive and finite."))
        isfinite(fermi_energy) ||
            throw(ArgumentError("SHG research chemical potential must be finite."))
        occupied_count > 0 ||
            throw(ArgumentError("SHG research requires a nonempty insulating subspace."))
        new(Float64(width), Float64(fermi_energy), Int(occupied_count))
    end
end

"""First divided difference of a locally constant insulating occupation projector."""
@inline function _insulating_projector_divided_first(energies, occupied, n, m)
    occupied[n] == occupied[m] && return 0.0
    return (Int(occupied[n]) - Int(occupied[m])) / (energies[n] - energies[m])
end

"""
Second projector divided difference without a denominator inside an equal-occupation block.

If all three occupations agree it vanishes. Otherwise the unique minority node
has two cross-gap denominators, including repeated majority energies safely.
"""
@inline function _insulating_projector_divided_second(energies, occupied, n, p, m)
    fn, fp, fm = occupied[n], occupied[p], occupied[m]
    fn == fp == fm && return 0.0
    i, j, k = fn != fp && fn != fm ? (n, p, m) : fp != fn && fp != fm ? (p, n, m) : (m, n, p)
    return (Int(occupied[i]) - Int(occupied[j])) /
           ((energies[i] - energies[j]) * (energies[i] - energies[k]))
end

"""Own the physical H covariant derivatives and insulating projector derivatives at one k."""
struct SameRateLorentzSHGGeometry
    energies::Vector{Float64}
    velocity::Array{ComplexF64, 3}
    projector_first::Array{ComplexF64, 3}
    projector_second::Array{ComplexF64, 4}
end

"""
Construct ∇H, ∇²H, ∇F and ∇²F from raw rotated Wannier tensors.

The convention is ∇O=∂O-i[A,O], so [r,O]=i∇O. No eigenvector derivative,
within-block inverse, static η, or Gaussian substitution enters this research
path. Cartesian lengths follow the model. It currently accepts orthogonal
matrix data and the explicitly declared gapped zero-temperature occupation.
"""
function same_rate_lorentz_shg_geometry(data, policy::SameRateLorentzSHGPolicy)
    data.position isa NonorthogonalPositionMatrixData &&
        throw(ArgumentError("Equal-rate SHG research does not qualify nonorthogonal models."))
    energies = copy(data.spectrum.energies)
    count = length(energies)
    0 < policy.occupied_count < count ||
        throw(ArgumentError("Occupied SHG subspace must leave empty states."))
    all(isfinite, energies) && issorted(energies) || throw(ArgumentError("Invalid SHG spectrum."))
    occupied = energies .< policy.fermi_energy
    any(==(policy.fermi_energy), energies) &&
        throw(ArgumentError("Chemical potential touches an SHG band."))
    sum(occupied) == policy.occupied_count ||
        throw(ArgumentError("SHG insulating occupation changed at this k."))
    h = data.hamiltonian_derivatives
    hh = data.hamiltonian_second_derivatives
    connection = data.internal_connection
    connection_derivative = data.internal_connection_derivatives
    size(h) == (count, count, 3) &&
    size(hh) == (count, count, 3, 3) &&
    size(connection) == (count, count, 3) &&
    size(connection_derivative) == (count, count, 3, 3) || throw(
        ArgumentError("SHG research requires complete three-dimensional raw derivative tensors."),
    )
    all(isfinite, h) &&
    all(isfinite, hh) &&
    all(isfinite, connection) &&
    all(isfinite, connection_derivative) || throw(ArgumentError("Nonfinite SHG geometry."))
    energy_matrix = Matrix(Diagonal(energies))
    velocity = zeros(ComplexF64, count, count, 3)
    second = zeros(ComplexF64, count, count, 3, 3)
    for a in 1:3
        aa = @view connection[:, :, a]
        velocity[:, :, a] .= @view(h[:, :, a]) .- im .* (aa*energy_matrix-energy_matrix*aa)
    end
    for b in 1:3, c in 1:3
        ab = @view connection[:, :, b];
        ac = @view connection[:, :, c]
        hb = @view h[:, :, b];
        hc = @view h[:, :, c]
        dab = @view connection_derivative[:, :, b, c]
        commutator = ab*energy_matrix-energy_matrix*ab
        second[:, :, b, c] .=
            @view(hh[:, :, b, c]) .- im .* (dab*energy_matrix-energy_matrix*dab) .-
            im .* (ab*hc-hc*ab) .- im .* (ac*hb-hb*ac) .- (ac*commutator-commutator*ac)
    end
    first_projector = zeros(ComplexF64, count, count, 3)
    second_projector = zeros(ComplexF64, count, count, 3, 3)
    for n in 1:count, m in 1:count
        first = _insulating_projector_divided_first(energies, occupied, n, m)
        for b in 1:3
            first_projector[n, m, b] = first*velocity[n, m, b]
            for c in 1:3
                value = first*second[n, m, b, c]
                for p in 1:count
                    divided = _insulating_projector_divided_second(energies, occupied, n, p, m)
                    value +=
                        divided*(
                            velocity[n, p, b]*velocity[p, m, c] +
                            velocity[n, p, c]*velocity[p, m, b]
                        )
                end
                second_projector[n, m, b, c] = value
            end
        end
    end
    return SameRateLorentzSHGGeometry(energies, velocity, first_projector, second_projector)
end

"""
Evaluate explicit equal-rate Lorentz SHG research totals, with complete intermediate states.

Output axes are `(frequency, component, quantity)` with quantities
`(relaxation_polarization, hamiltonian_current, polarization_current)`.
These are reduced positive-unit-charge quantities; a physical electron consumer
must apply its explicit q³/eV/volume prefactors. No legacy seven-term decomposition
is claimed. For E(t)∝exp(-iωt), J_H=(Γ-2iω)P and J_P=-2iωP in energy units.
The polarization is inferred under this declared scalar relaxation model; it is
not a separate periodic position trace or an independently qualified metal formula.
"""
function same_rate_lorentz_shg_response!(
    output,
    geometry::SameRateLorentzSHGGeometry,
    frequencies,
    components,
    policy::SameRateLorentzSHGPolicy,
)
    size(output) == (length(frequencies), length(components), 3) ||
        throw(ArgumentError("Equal-rate SHG research output requires three explicit quantities."))
    all(isfinite, frequencies) || throw(ArgumentError("Nonfinite SHG frequency."))
    all(x -> length(x)==3 && all(a -> a in 1:3, x), components) ||
        throw(ArgumentError("SHG components must be Cartesian triples."))
    fill!(output, 0)
    energies = geometry.energies
    count = length(energies)
    rho_first = zeros(ComplexF64, count, count, 3)
    inverse_first = zeros(ComplexF64, count, count)
    inverse_second = similar(inverse_first)
    derivative = similar(inverse_first)
    rho_second = similar(inverse_first)
    for (frequency, energy) in enumerate(frequencies)
        for n in 1:count, m in 1:count
            difference = energies[n]-energies[m]
            inverse_first[n, m] = inv(energy+im*policy.width-difference)
            inverse_second[n, m] = inv(2energy+im*policy.width-difference)
            for c in 1:3
                rho_first[n, m, c] = im*inverse_first[n, m]*geometry.projector_first[n, m, c]
            end
        end
        for (component, (a, b, c)) in enumerate(components)
            fill!(rho_second, 0)
            for (first_axis, second_axis) in ((b, c), (c, b))
                v = @view geometry.velocity[:, :, first_axis]
                r = @view rho_first[:, :, second_axis]
                derivative .= v*r-r*v
                for n in 1:count, m in 1:count
                    covariant_derivative =
                        inverse_first[
                            n,
                            m,
                        ]*(
                            im*geometry.projector_second[
                                n,
                                m,
                                second_axis,
                                first_axis,
                            ]+derivative[n, m]
                        )
                    rho_second[n, m] += 0.5im*inverse_second[n, m]*covariant_derivative
                end
            end
            current = zero(ComplexF64)
            for n in 1:count, m in 1:count
                current += geometry.velocity[n, m, a]*rho_second[m, n]
            end
            polarization = current/(policy.width-2im*energy)
            output[frequency, component, 1] = polarization
            output[frequency, component, 2] = current
            output[frequency, component, 3] = -2im*energy*polarization
        end
    end
    return output
end
