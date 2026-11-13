# Test-only, uncontracted A4 reference: Hipolito et al., PRB 98, 205420 (2018),
# Appendix A4a-d. Explicit band sums retain all four labels in the eee sector.
# Inputs are independently qualified endpoint geometry and occupation derivatives;
# no production THG intermediate, commutator or response kernel is called.
# The declared finite-width rule and the bare-position cutoff are numerical inputs,
# not an assertion of exact causal-resolvent or regrouping identities.
module ThirdHarmonicLiteralReference

# Coefficients of a formal pure-frequency inverse, evaluated only after collection.
constant(value) = ComplexF64[value, 0, 0, 0]
pole(value, degree) = ComplexF64[index == degree+1 ? value : 0 for index in 1:4]
function product(first, second)
    result = zeros(ComplexF64, 4)
    for left in 0:3, right in 0:(3 - left)
        result[left + right + 1] += first[left + 1] * second[right + 1]
    end
    return result
end

function frequency(energy, gap, harmonic, width, gaussian)
    offset = gap-harmonic*energy
    denominator = offset^2+width^2
    delta = gaussian ? exp(-(offset/width)^2)/(sqrt(pi)*width) : width/(pi*denominator)
    derivative = gaussian ? -2offset*delta/width^2 : -2offset*width/(pi*denominator^2)
    return complex(-offset/denominator, -pi*delta),
    complex((offset^2-width^2)/denominator^2, -pi*derivative)
end

function coefficients(geometry, occupations, energies, energy, component, width, gaussian)
    phi, c, b, a = component
    count = length(energies)
    # t=v/(E_bra-E_ket) away from the cutoff; near it the declared input is i*r0.
    t = im .* geometry.dipoles
    for n in 1:count, axis in 1:3
        t[n, n, axis] = 0
    end
    dt = im .* geometry.dipole_derivatives
    for n in 1:count, axis in 1:3, derivative_axis in 1:3
        dt[n, n, axis, derivative_axis] = 0
    end
    v = geometry.velocities
    dv = geometry.velocity_derivatives
    f = occupations.values
    fa = occupations.first[:, a]
    fb = occupations.first[:, b]
    fab = occupations.second[:, a, b]
    resolvent(j, m, n) = frequency(energy, energies[m]-energies[n], j, width, gaussian)
    # Diagonal-band denominators give a formal pure pole, including integer factors.
    spectral(j, m, n) = m==n ? pole(1/j, 1) : constant(first(resolvent(j, m, n)))
    current(m, n) = v[n, m, phi] .* spectral(3, m, n)
    function current_derivative(m, n)
        m==n && return pole(dv[n, n, phi, c]/3, 1)
        value, derivative = resolvent(3, m, n)
        return constant(
            dv[n, m, phi, c]*value +
            v[n, m, phi]*(geometry.gradients[m, c]-geometry.gradients[n, c])*derivative,
        )
    end
    drive(m, n) = t[m, n, a]*(f[n]-f[m])*first(resolvent(1, m, n))
    function drive_derivative(m, n)
        value, derivative = resolvent(1, m, n)
        return (dt[m, n, a, b]*(f[n]-f[m])+t[m, n, a]*(fb[n]-fb[m]))*value +
               t[m, n, a]*(f[n]-f[m])*(geometry.gradients[m, b]-geometry.gradients[n, b])*derivative
    end
    result=zeros(ComplexF64, 4, 4)
    # A4a, fully uncontracted ordered band sums (no matrix multiplication).
    for m in 1:count, n in 1:count, l in 1:count, p in 1:count
        first_chain = t[m, l, c]*(t[l, p, b]*drive(p, n)-drive(l, p)*t[p, n, b])
        second_chain = (t[m, p, b]*drive(p, l)-drive(m, p)*t[p, l, b])*t[l, n, c]
        result[1, :] .+=
            -im .* (
                first_chain .* product(current(m, n), spectral(2, l, n)) -
                second_chain .* product(current(m, n), spectral(2, m, l))
            )
    end
    # A4b, covariant derivatives act on their declared ordered factors.
    for m in 1:count, n in 1:count, l in 1:count
        inner=t[m, l, b]*drive(l, n)-drive(m, l)*t[l, n, b]
        result[2, :] .+= -im*inner .* product(current_derivative(m, n), spectral(2, m, n))
        right=t[m, l, c]*drive_derivative(l, n)
        left=drive_derivative(m, l)*t[l, n, c]
        result[2, :] .+=
            im .* (
                right .* product(current(m, n), spectral(2, l, n)) -
                left .* product(current(m, n), spectral(2, m, l))
            )
        right=t[m, l, c]*t[l, n, b]*(fa[n]-fa[l])
        left=t[m, l, b]*(fa[l]-fa[m])*t[l, n, c]
        result[2, :] .+=
            im .* product(
                pole(1, 1),
                right .* product(current(m, n), spectral(2, l, n)) -
                left .* product(current(m, n), spectral(2, m, l)),
            )
    end
    # A4c, the external current is off diagonal in all three summands.
    for m in 1:count, n in 1:count
        m==n && continue
        g2=first(resolvent(2, m, n))
        result[3, :] .+= im*g2*drive_derivative(m, n) .* current_derivative(m, n)
        result[3, :] .+=
            im*g2*t[m, n, b]*(fa[n]-fa[m]) .* product(current_derivative(m, n), pole(1, 1))
        result[3, :] .+= (-im/2)*t[m, n, c]*(fab[n]-fab[m]) .* product(current(m, n), pole(1, 2))
    end
    # A4d also follows independently from the scalar-band Boltzmann expansion.
    result[4, 4] = -im*sum(geometry.hessians[n, phi, c]*fab[n] for n in 1:count)/6
    return result
end

# The explicit distribution-broadening low-pole recipe is evaluated after collection.
function lower(coefficients, energy, width, gaussian)
    principal=energy/(energy^2+width^2)
    delta=gaussian ? exp(-(energy/width)^2)/(sqrt(pi)*width) : width/(pi*(energy^2+width^2))
    low(degree)=degree==0 ? 1+0im : complex(principal, -delta)*principal^(degree-1)
    conductivity=[sum(coefficients[term, degree + 1]*low(degree) for degree in 0:3) for term in 1:4]
    susceptibility=[
        sum(coefficients[term, degree + 1]*(im/3)*low(degree+1) for degree in 0:3) for term in 1:4
    ]
    return hcat(conductivity, susceptibility)
end
end
