
const ORBITAL_MAGNETIZATION_TERMS = (:srocc, :cmocc, :total)

"""Independent occupied/unoccupied matrix-element traces F,G,K (document W7–W8)."""
function conventional_magnetization_traces(geometry, completion, occupied)
    count=length(geometry.energies)
    f=zeros(ComplexF64, 3, 3);
    g=similar(f);
    fill!(g, 0);
    k=similar(f);
    fill!(k, 0)
    for b in 1:3, a in 1:3, n in 1:occupied
        overlap=completion.derivative_overlap[n, n, a, b]
        weighted=completion.energy_overlap[n, n, a, b]
        for m in (occupied + 1):count
            left=geometry.connection[n, m, a]
            right=geometry.connection[m, n, b]
            overlap+=left*right
            weighted+=conj(completion.energy_connection[m, n, a])*right+left*completion.energy_connection[
                m,
                n,
                b,
            ]+left*geometry.energies[m]*right
        end
        f[a, b]+=overlap;
        g[a, b]+=weighted;
        k[a, b]+=geometry.energies[n]*overlap
    end
    return f, g, k
end

"""Independent orbital-frame traces from the prepared regularized tangent Z=-i*q*r_OM*p."""
function projector_magnetization_traces(geometry, completion, occupied)
    count=length(geometry.energies);
    u=geometry.eigenvectors
    p=u[:, 1:occupied]*u[:, 1:occupied]';
    h=u*Diagonal(geometry.energies)*u'
    z=Matrix{ComplexF64}[]
    for a in 1:3
        cross=zeros(ComplexF64, count, count)
        for n in 1:occupied, m in (occupied + 1):count
            cross[m, n]=-im * geometry.connection[m, n, a]
        end
        push!(z, u*cross*u')
    end
    f=zeros(ComplexF64, 3, 3);
    g=similar(f);
    k=similar(f)
    for b in 1:3, a in 1:3
        external_f=u*completion.derivative_overlap[:, :, a, b]*u'
        external_c=u*completion.energy_overlap[:, :, a, b]*u'
        ba=u*completion.energy_connection[:, :, a]*u'
        bb=u*completion.energy_connection[:, :, b]*u'
        overlap=z[a]'*z[b]+p*external_f*p
        weighted=z[a]'*h*z[b]+im*p*ba'*z[b]-im*z[a]'*bb*p+p*external_c*p
        f[a, b]=tr(overlap);
        g[a, b]=tr(weighted);
        k[a, b]=tr(h*overlap)
    end
    return f, g, k
end

"""Build occupied-subspace traces once for every spectral interval at one k point."""
function orbital_magnetization_kernel(
    geometry,
    completion;
    projector = false,
    denominator_regularization::Real = geometry isa NonorthogonalSpectralResponseGeometry ?
                                       geometry.denominator_regularization_ev : 0.001,
)
    if geometry isa NonorthogonalSpectralResponseGeometry
        projector && throw(ArgumentError("NONORTHOGONAL_PROJECTOR_RESPONSE_UNSUPPORTED"))
        maximum(abs, geometry.curvature)<=1e-9 ||
            throw(ArgumentError("ORBITAL_FINITE_MODEL_NOT_FLAT"))
        all(
            iszero,
            (
                completion.derivative_overlap,
                completion.energy_connection,
                completion.energy_overlap,
            ),
        ) || throw(ArgumentError("NONORTHOGONAL_MATERIAL_COMPLETION_UNSUPPORTED"))
    end

    geometry = MatrixElements.regularized_orbital_geometry(geometry, denominator_regularization)
    energy = geometry.energies
    boundaries = vcat(-Inf, [energy[first(block)] for block in geometry.blocks], Inf)
    traces = Tuple{Matrix{ComplexF64}, Matrix{ComplexF64}, Matrix{ComplexF64}}[]
    occupied = 0
    for interval in 1:(length(boundaries) - 1)
        push!(
            traces,
            projector ? projector_magnetization_traces(geometry, completion, occupied) :
            conventional_magnetization_traces(geometry, completion, occupied),
        )
        interval <= length(geometry.blocks) && (occupied = last(geometry.blocks[interval]))
    end
    return (; energy, boundaries, traces)
end

"""Modern vectorized orbital magnetic-moment integrand in μB, terms SRocc, CMocc, total.

Finite-temperature terms are analytic thermal convolutions of the zero-T
occupied-subspace decomposition. No smoothed density matrix is used as a projector.
"""
function orbital_magnetization_response(
    geometry,
    completion;
    projector = false,
    denominator_regularization::Real = geometry isa NonorthogonalSpectralResponseGeometry ?
                                       geometry.denominator_regularization_ev : 0.001,
    fermi_energies::Vector{Float64},
    temperature,
)
    axis = validate_fermi_energies(fermi_energies)
    result=zeros(Float64, length(axis), 3, 3)
    kernel =
        orbital_magnetization_kernel(geometry, completion; projector, denominator_regularization)
    energy = kernel.energy
    boundaries = kernel.boundaries
    factor=RESPONSE_CHARGE_C^2*1e-20/(2RESPONSE_HBAR_JS*RESPONSE_BOHR_MAGNETON)
    for (mu_index, fermi_energy) in enumerate(axis)
        for interval in 1:(length(boundaries) - 1)
            lower, upper=boundaries[interval], boundaries[interval + 1]
            if temperature==0
                # Half at a boundary averages complete left/right projectors.
                # No mu shift or fractional density matrix is used as a projector.
                weight=response_occupation(lower, fermi_energy, 0.0) -
                       response_occupation(upper, fermi_energy, 0.0)
                first_moment=fermi_energy*weight
            else
                fl=isinf(lower) ? 1.0 : response_occupation(lower, fermi_energy, temperature)
                fu=isinf(upper) ? 0.0 : response_occupation(upper, fermi_energy, temperature)
                lower_boundary=isinf(lower) ? fermi_energy :
                               lower*fl+response_thermal_weight(lower, fermi_energy, temperature)
                upper_boundary=isinf(upper) ? 0.0 :
                               upper*fu+response_thermal_weight(upper, fermi_energy, temperature)
                weight=fl-fu;
                first_moment=lower_boundary-upper_boundary
            end
            if weight!=0 || first_moment!=0
                f, g, k = kernel.traces[interval]
                for (cartesian, (a, b)) in enumerate(((2, 3), (3, 1), (1, 2)))
                    result[mu_index, cartesian, 1] +=
                        factor*imag((g[a, b]-k[a, b])-(g[b, a]-k[b, a]))*weight
                    result[
                        mu_index,
                        cartesian,
                        2,
                    ]+=2factor*imag((k[a, b]-k[b, a])*weight-(f[a, b]-f[b, a])*first_moment)
                end
            end
        end
        @views result[mu_index, :, 3].=result[mu_index, :, 1]+result[mu_index, :, 2]
    end
    return result
end

"""Reject unsupported orthogonal projector traces for a metric spectral payload."""
projector_magnetization_traces(::NonorthogonalSpectralResponseGeometry, completion, occupied) =
    throw(ArgumentError("NONORTHOGONAL_PROJECTOR_RESPONSE_UNSUPPORTED"))
