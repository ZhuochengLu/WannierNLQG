# G24: a single II/III row after canonical pure-frequency cancellation.
function third_harmonic_partition_row!(coeff, policy, energy, numerator, u, xi, d, tau, h)
    pd, _=harmonic_gap_inverse(policy, d)
    ph, _=harmonic_gap_inverse(policy, h)
    gx, _=harmonic_resolvent(policy, energy, d, xi)
    gt, _=harmonic_resolvent(policy, energy, h, tau)
    coeff[1, 1]+=-im*numerator*((xi/u)*pd*gx*gt-(tau/u)*pd*ph*gt)
    coeff[2, 2]+=-im*numerator*pd*ph/u
    return nothing
end

"""
Independent regular/pole formulation, G21--G25 and theory 0.19--0.38.

EEE sector I uses a masked commutator; II/III are direct cubic loops. The remaining
Io/Id/J/DI sectors are evaluated directly, never recovered as a total residual.
Coefficients use Fourier raw units and conductivity pole classification.
"""
function third_harmonic_regrouped!(workspace, policy, energy, component, energies)
    phi, c, b, a=component
    geometry=workspace.geometry;
    occupation=workspace.occupations
    t=geometry.ratios;
    finite=geometry.finite_literature_derivatives
    numerator=geometry.literature_derivative_numerators
    factors=workspace.gap_factors;
    v=geometry.velocities
    count=length(energies)
    y, dy, bmat, c0, c1, z, j, w0, w1, dw0, dw1, comm0, comm1, tmp=workspace.matrices
    coeff=@view workspace.coefficients[:, :, 2];
    fill!(coeff, 0)
    @views harmonic_commutator!(comm0, t[:, :, c], c0)
    coeff[1, 1]=-im*harmonic_contract(w0, comm0)
    # II: external current diagonal, with three independent band labels.
    for n in 1:count, l in 1:count, p in 1:count
        vn=v[n, n, phi]
        d1=energies[p]-energies[n];
        d2=energies[l]-energies[p]
        h1=energies[l]-energies[n];
        h2=energies[n]-energies[l]
        fpn=occupation.values[n]-occupation.values[p]
        flp=occupation.values[p]-occupation.values[l]
        fpl=-flp;
        fnp=-fpn
        third_harmonic_partition_row!(
            coeff,
            policy,
            energy,
            vn*t[n, l, c]*t[l, p, b]*t[p, n, a]*fpn,
            3,
            1,
            d1,
            2,
            h1,
        )
        third_harmonic_partition_row!(
            coeff,
            policy,
            energy,
            -vn*t[n, l, c]*t[l, p, a]*flp*t[p, n, b],
            3,
            1,
            d2,
            2,
            h1,
        )
        third_harmonic_partition_row!(
            coeff,
            policy,
            energy,
            -vn*t[n, p, b]*t[p, l, a]*fpl*t[l, n, c],
            3,
            1,
            -d2,
            2,
            h2,
        )
        third_harmonic_partition_row!(
            coeff,
            policy,
            energy,
            vn*t[n, p, a]*fnp*t[p, l, b]*t[l, n, c],
            3,
            1,
            -d1,
            2,
            h2,
        )
    end
    # III: middle population denominator, external current off diagonal.
    for n in 1:count, m in 1:count, p in 1:count
        m==n && continue
        d=energies[m]-energies[n]
        vn=v[n, m, phi]
        fpn=occupation.values[n]-occupation.values[p]
        fnp=-fpn
        fpm=occupation.values[m]-occupation.values[p]
        fmp=-fpm
        third_harmonic_partition_row!(
            coeff,
            policy,
            energy,
            vn*t[m, n, c]*t[n, p, b]*t[p, n, a]*fpn,
            2,
            3,
            d,
            1,
            energies[p]-energies[n],
        )
        third_harmonic_partition_row!(
            coeff,
            policy,
            energy,
            -vn*t[m, n, c]*t[n, p, a]*fnp*t[p, n, b],
            2,
            3,
            d,
            1,
            energies[n]-energies[p],
        )
        third_harmonic_partition_row!(
            coeff,
            policy,
            energy,
            -vn*t[m, p, b]*t[p, m, a]*fpm*t[m, n, c],
            2,
            3,
            d,
            1,
            energies[p]-energies[m],
        )
        third_harmonic_partition_row!(
            coeff,
            policy,
            energy,
            vn*t[m, p, a]*fmp*t[p, m, b]*t[m, n, c],
            2,
            3,
            d,
            1,
            energies[m]-energies[p],
        )
    end
    # IoR/IoL, with all three labels distinct.
    for n in 1:count, m in 1:count, l in 1:count
        (m==n || m==l || n==l) && continue
        gap=energies[m]-energies[n]
        g2, _=harmonic_resolvent(policy, energy, gap, 2)
        h1=dw0[m, n]*g2*(t[m, l, b]*y[l, n]-y[m, l]*t[l, n, b])
        h2=-w0[m, n]*(t[m, l, c]*z[l, n]-z[m, l]*t[l, n, c])
        coeff[1, 1]+=-im*(h1+h2)
        m1=-v[n, m, phi]*t[m, l, c]*t[l, n, b]*(occupation.first[n, a]-occupation.first[l, a])
        m2=v[n, m, phi]*t[m, l, b]*t[l, n, c]*(occupation.first[l, a]-occupation.first[m, a])
        third_harmonic_partition_row!(
            coeff,
            policy,
            energy,
            m1,
            1,
            3,
            gap,
            2,
            energies[l]-energies[n],
        )
        third_harmonic_partition_row!(
            coeff,
            policy,
            energy,
            m2,
            1,
            3,
            gap,
            2,
            energies[m]-energies[l],
        )
    end
    # IdR/IdL/IdC and JR/JL/JC: two-band formulas with endpoint gaps cancelled first.
    for n in 1:count, m in 1:count
        m==n && continue
        d=energies[m]-energies[n]
        pd=factors.static_gap_principal[m, n]
        dpd=factors.static_gap_derivative[m, n]
        g1, dg1=harmonic_resolvent(policy, energy, d, 1)
        gm1, dgm1=harmonic_resolvent(policy, energy, -d, 1)
        g2, _=harmonic_resolvent(policy, energy, d, 2)
        gm2, _=harmonic_resolvent(policy, energy, -d, 2)
        g3, dg3=harmonic_resolvent(policy, energy, d, 3)
        f=occupation.values[n]-occupation.values[m]
        fa=occupation.first[n, a]-occupation.first[m, a]
        fb=occupation.first[n, b]-occupation.first[m, b]
        fab=occupation.second[n, a, b]-occupation.second[m, a, b]
        db=geometry.gradients[m, b]-geometry.gradients[n, b]
        dc=geometry.gradients[m, c]-geometry.gradients[n, c]
        velocity=v[n, n, phi];
        curvature=geometry.hessians[n, phi, c]
        aplus=t[m, n, a]*f*pd
        aminus=-t[n, m, a]*f*pd
        fpd=iszero(f) ? 0.0 : f*pd
        forward_pg=optical_derivative_combination(
            finite[m, n, a, b],
            numerator[m, n, a, b],
            factors.bare_position_inverse[m, n],
            fpd,
        )
        reverse_pg=optical_derivative_combination(
            finite[n, m, a, b],
            numerator[n, m, a, b],
            factors.bare_position_inverse[n, m],
            fpd,
        )
        daplus=im*forward_pg+t[m, n, a]*fb*pd+t[m, n, a]*f*dpd*db
        daminus=-im*reverse_pg-t[n, m, a]*fb*pd-t[n, m, a]*f*dpd*db
        dpplus=daplus*g1+aplus*dg1*db
        dpminus=daminus*gm1-aminus*dgm1*db
        pa=t[n, m, b]*t[m, n, a];
        pb=t[n, m, a]*t[m, n, b]
        pc=t[n, m, c]*t[m, n, b];
        pb2=t[n, m, b]*t[m, n, c]
        r1=curvature*f*pd^2*(pa*g1+pb*gm1)/6
        r2=-velocity*(t[n, m, c]*g2*dpplus+dpminus*t[m, n, c]*gm2)/3
        r3=2velocity*pd*(t[n, m, c]*g2*daplus-daminus*t[m, n, c]*gm2)/3
        r4=-4velocity*fa*pd^2*(pc*g2+pb2*gm2)/3
        l1=-curvature*f*pd^2*(pa+pb)/6
        l2=velocity*pd*(-t[n, m, c]*daplus+daminus*t[m, n, c])/3
        l3=2velocity*fa*pd^2*(pc+pb2)/3
        quadratic=-curvature*f*pd*(pa-pb)/6+velocity*fa*pd*(pc-pb2)/3
        coeff[1, 1]+=-im*(r1+r2+r3+r4)
        coeff[2, 2]+=-im*(l1+l2+l3)
        coeff[3, 3]+=-im*quadratic
        # Preserve signed P and task weight before the complete R/Q numerator.
        fapd=iszero(fa) ? 0.0 : fa*pd
        derivative_ratio_weight=-im*optical_derivative_combination(
            finite[n, m, phi, c],
            numerator[n, m, phi, c],
            factors.bare_position_inverse[n, m],
            fapd,
        )
        derivative_ratio_resolvent_weight=derivative_ratio_weight*g3-t[n, m, phi]*dg3*dc*pd*fa
        first=dw0[m, n]*g2*dy[m, n]
        second=2dw0[m, n]*g2*t[m, n, b]*pd*fa-3derivative_ratio_resolvent_weight*t[m, n, b]
        third=4.5t[n, m, phi]*t[m, n, c]*pd*fab*g3
        coeff[1, 1]+=im*(first+second+third)
        coeff[2, 2]+=im*(derivative_ratio_weight*t[m, n, b]-1.5t[n, m, phi]*t[m, n, c]*pd*fab)
        coeff[3, 3]+=-0.5im*t[n, m, phi]*t[m, n, c]*fab
    end
    for n in 1:count
        coeff[4, 4]+=-im*geometry.hessians[n, phi, c]*occupation.second[n, a, b]/6
    end
    return workspace
end
