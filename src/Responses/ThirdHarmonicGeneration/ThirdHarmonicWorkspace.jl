# Four observable groups, in the declared conductivity-based classification.
const THIRD_HARMONIC_UNREGROUPED_TERMS=("eee", "iee_group", "iie_group", "iii")
const THIRD_HARMONIC_REGROUPED_TERMS=("regular", "linear_pole", "quadratic_pole", "cubic_pole")
const THIRD_HARMONIC_COMPONENTS=[
    (phi, c, b, a) for phi in 1:3 for (c, b, a) in (
        (1, 1, 1),
        (2, 2, 2),
        (3, 3, 3),
        (1, 1, 2),
        (1, 1, 3),
        (1, 2, 2),
        (2, 2, 3),
        (1, 3, 3),
        (2, 3, 3),
        (1, 2, 3),
    )
]

"""One bounded scalar-gap cache per THG worker.

Bare position inverses use E_ket-E_bra; independent static resolvent factors use
E_bra-E_ket. The key is the ordered energy vector and actual static matrix width.
No occupation, frame-dependent matrix or global mutable cache is stored here.
"""
mutable struct HarmonicGapFactors
    energies::Vector{Float64}
    width::Float64
    bare_position_inverse::Matrix{Float64}
    static_gap_principal::Matrix{Float64}
    static_gap_derivative::Matrix{Float64}
end
"""Allocate worker-private gap factors with invalid energy and width keys, requiring refill before reuse."""
HarmonicGapFactors(
    count::Integer,
)=HarmonicGapFactors(
    fill(NaN, count),
    NaN,
    zeros(count, count),
    zeros(count, count),
    zeros(count, count),
)

"""Refill gap factors when energies or policy width change; invalidate the width before writing so failed refills cannot reuse a stale key."""
function _harmonic_gap_factors!(cache::HarmonicGapFactors, policy, energies)
    length(energies)==length(cache.energies) || throw(DimensionMismatch("THG worker band axis"))
    cache.width==policy.gap_width && cache.energies==energies && return cache
    cache.width=NaN # A failed refill must not leave the old key on partial arrays.
    for ket in eachindex(energies), bra in eachindex(energies)
        difference=energies[ket]-energies[bra]
        cache.bare_position_inverse[bra, ket]=bare_energy_inverse(difference)
        cache.static_gap_principal[bra, ket], cache.static_gap_derivative[bra, ket] =
            harmonic_gap_inverse(policy, -difference)
    end
    cache.energies .= energies
    cache.width=policy.gap_width
    return cache
end

"""O(N_b^2) worker scratch for the two independent THG formulations."""
struct ThirdHarmonicWorkspace{G}
    geometry::G
    occupations::HarmonicOccupationWorkspace
    matrices::NTuple{14, Matrix{ComplexF64}}
    gap_factors::HarmonicGapFactors
    coefficients::Array{ComplexF64, 3}
end

# Fixed scratch size independent of mesh and frequency counts.
"""Allocate combined THG geometry, occupations, fourteen scratch matrices, gap factors and fixed-size coefficients once per worker."""
ThirdHarmonicWorkspace(
    count::Integer,
)=ThirdHarmonicWorkspace(
    ThirdOrderGeometry(count, Val(:combined)),
    HarmonicOccupationWorkspace(count),
    ntuple(_->zeros(ComplexF64, count, count), 14),
    HarmonicGapFactors(count),
    zeros(ComplexF64, 4, 4, 2),
)

# Nonconjugating contraction; unlike dot it preserves the physical band order.
function harmonic_contract(first, second)
    result=0.0+0im
    for index in eachindex(first, second)
        result+=first[index]*second[index]
    end
    return result
end

# Output-first commutator with disjoint scratch and inputs.
function harmonic_commutator!(output, first, second)
    mul!(output, first, second)
    mul!(output, second, first, -1, 1)
    return output
end

# Prepare G12--G15 for an ordered input triple; diagonal poles remain separate.
function third_harmonic_vertices!(workspace, policy, energy, component, energies)
    phi, c, b, a=component
    geometry=workspace.geometry;
    occupation=workspace.occupations
    count=length(occupation.values)
    t=geometry.ratios;
    finite=geometry.finite_literature_derivatives
    numerator=geometry.literature_derivative_numerators
    factors=_harmonic_gap_factors!(workspace.gap_factors, policy, energies)
    v=geometry.velocities;
    dv=geometry.velocity_derivatives
    y, dy, bmat, c0, c1, z, j, w0, w1, dw0, dw1, comm0, comm1, tmp=workspace.matrices
    for n in 1:count, m in 1:count
        gap=energies[m]-energies[n]
        f=occupation.values[n]-occupation.values[m]
        fb=occupation.first[n, b]-occupation.first[m, b]
        fa=occupation.first[n, a]-occupation.first[m, a]
        g1, dg1=harmonic_resolvent(policy, energy, gap, 1)
        g2, _=harmonic_resolvent(policy, energy, gap, 2)
        g3, dg3=harmonic_resolvent(policy, energy, gap, 3)
        y[m, n]=t[m, n, a]*f*g1
        dy[
            m,
            n,
        ]=(
            im*optical_derivative_combination(
                finite[m, n, a, b],
                numerator[m, n, a, b],
                factors.bare_position_inverse[m, n],
                f,
            )+t[m, n, a]*fb
        )*g1+t[m, n, a]*f*(geometry.gradients[m, b]-geometry.gradients[n, b])*dg1
        z[m, n]=g2*dy[m, n]
        j[m, n]=g2*t[m, n, b]*fa
        w0[m, n]=m==n ? 0 : v[n, m, phi]*g3
        w1[m, n]=m==n ? v[n, m, phi]/3 : 0
        dw0[
            m,
            n,
        ]=m==n ? 0 :
          dv[n, m, phi, c]*g3+v[n, m, phi]*(geometry.gradients[m, c]-geometry.gradients[n, c])*dg3
        dw1[m, n]=m==n ? dv[n, m, phi, c]/3 : 0
    end
    @views harmonic_commutator!(bmat, t[:, :, b], y)
    for n in 1:count, m in 1:count
        g2, _=harmonic_resolvent(policy, energy, energies[m]-energies[n], 2)
        c0[m, n]=m==n ? 0 : g2*bmat[m, n]
        c1[m, n]=m==n ? bmat[m, n]/2 : 0
    end
    return workspace
end
