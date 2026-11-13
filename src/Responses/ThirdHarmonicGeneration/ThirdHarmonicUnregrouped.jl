"""
Evaluate A4/G16--G20 by commutator contraction, O(N_b^3), without four-band tensors.

Returns the four unregrouped groups as coefficients indexed by pure pole degree
0:3. All prefactors are Fourier raw units (e=hbar=1); no SI/volume factor is applied.
"""
function third_harmonic_unregrouped!(workspace, policy, energy, component, energies)
    phi, c, b, a=component
    geometry=workspace.geometry;
    occupation=workspace.occupations
    t=geometry.ratios
    y, dy, bmat, c0, c1, z, j, w0, w1, dw0, dw1, comm0, comm1, tmp=workspace.matrices
    coeff=@view workspace.coefficients[:, :, 1]
    fill!(coeff, 0)
    @views harmonic_commutator!(comm0, t[:, :, c], c0)
    @views harmonic_commutator!(comm1, t[:, :, c], c1)
    coeff[1, 1]=-im*harmonic_contract(w0, comm0)
    coeff[1, 2]=-im*(harmonic_contract(w1, comm0)+harmonic_contract(w0, comm1))
    coeff[1, 3]=-im*harmonic_contract(w1, comm1)
    coeff[2, 1]=-im*harmonic_contract(dw0, c0)
    coeff[2, 2]=-im*(harmonic_contract(dw1, c0)+harmonic_contract(dw0, c1))
    coeff[2, 3]=-im*harmonic_contract(dw1, c1)
    @views harmonic_commutator!(tmp, t[:, :, c], z)
    coeff[2, 1]+=im*harmonic_contract(w0, tmp)
    coeff[2, 2]+=im*harmonic_contract(w1, tmp)
    @views harmonic_commutator!(tmp, t[:, :, c], j)
    coeff[2, 2]+=im*harmonic_contract(w0, tmp)
    coeff[2, 3]+=im*harmonic_contract(w1, tmp)
    for n in eachindex(energies), m in eachindex(energies)
        m==n && continue
        g2, _=harmonic_resolvent(policy, energy, energies[m]-energies[n], 2)
        fa=occupation.first[n, a]-occupation.first[m, a]
        fab=occupation.second[n, a, b]-occupation.second[m, a, b]
        coeff[3, 1]+=im*dw0[m, n]*g2*dy[m, n]
        coeff[3, 2]+=im*dw0[m, n]*g2*t[m, n, b]*fa
        coeff[3, 3]+=-im*w0[m, n]*t[m, n, c]*fab/2
    end
    for n in eachindex(energies)
        coeff[4, 4]+=-im*geometry.hessians[n, phi, c]*occupation.second[n, a, b]/6
    end
    return workspace
end
