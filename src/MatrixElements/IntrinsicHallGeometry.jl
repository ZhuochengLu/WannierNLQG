"""Owned unbroadened geometry for the zero-temperature intrinsic Hall response.

Energies are eV; complete physical velocity is eV Angstrom and ambient curvature
is Angstrom². No position ratios or occupation groups are prepared here.
"""
struct IntrinsicHallGeometry
    energies::Vector{Float64}
    velocity::Array{ComplexF64, 3}
    ambient_curvature::Array{ComplexF64, 4}
    eigenvectors::Matrix{ComplexF64}
    orthonormal_basis::Bool
end

"""Retain full velocity and ambient curvature without a small-gap spectral guard."""
function intrinsic_hall_geometry(energies, vectors, velocity, curvature; orthonormal_basis::Bool)
    energy = Vector{Float64}(energies)
    n = length(energy)
    n > 0 && issorted(energy) || throw(ArgumentError("invalid intrinsic Hall spectrum"))
    size(vectors) == (n, n) || throw(DimensionMismatch("full eigenframe required"))
    size(velocity) == (n, n, 3) || throw(DimensionMismatch("complete Cartesian velocity required"))
    size(curvature) == (n, n, 3, 3) ||
        throw(DimensionMismatch("complete ambient curvature required"))
    all(x -> all(isfinite, x), (energy, vectors, velocity, curvature)) ||
        throw(ArgumentError("nonfinite intrinsic Hall geometry"))
    return IntrinsicHallGeometry(
        energy,
        Array{ComplexF64, 3}(velocity),
        Array{ComplexF64, 4}(curvature),
        Matrix{ComplexF64}(vectors),
        orthonormal_basis,
    )
end

"""Prepare an orthogonal full-Wannier intrinsic geometry from admitted operators.

`position` is the orbital-frame connection, not a band Berry connection.
`curvature` is the orbital-frame F_ab, including derivative and commutator terms.
The caller retains responsibility for source admission and spectrum validation.
"""
function orthogonal_intrinsic_hall_geometry(
    energies,
    vectors,
    hamiltonian_derivatives,
    position,
    curvature,
)
    n = length(energies)
    size(hamiltonian_derivatives) == size(position) == (n, n, 3) ||
        throw(DimensionMismatch("H derivative / position shape"))
    size(curvature) == (n, n, 3, 3) || throw(DimensionMismatch("ambient curvature shape"))
    velocity = zeros(ComplexF64, n, n, 3)
    band_curvature = zeros(ComplexF64, n, n, 3, 3)
    for a in 1:3
        h = vectors' * hamiltonian_derivatives[:, :, a] * vectors
        connection = vectors' * position[:, :, a] * vectors
        for m in 1:n, l in 1:n
            velocity[l, m, a] = h[l, m] + im * (energies[l] - energies[m]) * connection[l, m]
        end
        for b in 1:3
            band_curvature[:, :, a, b] = vectors' * curvature[:, :, a, b] * vectors
        end
    end
    return intrinsic_hall_geometry(
        energies,
        vectors,
        velocity,
        band_curvature,
        ;
        orthonormal_basis = true,
    )
end

"""Prepare nonorthogonal Matrix geometry without the finite-eta scalar tangent.

The admitted matrices use the existing localized r convention: B_a=r_a+i*S_a.
C†SC=I is established by the existing generalized eigensolver/admission path.
V_nm=(C†H_a C)_nm-E_m(C†S_a C)_nm+i(E_n-E_m)(C†B_a C)_nm.
The existing metric-curvature implementation supplies C†F_lower C. No overlap
clipping, point-orbital substitution, or new operator projection occurs here.
"""
function nonorthogonal_intrinsic_hall_geometry(matrices, spectrum)
    energies, vectors = spectrum.energies, spectrum.eigenvectors
    n = length(energies)
    matrices.position === nothing && throw(ArgumentError("INTRINSIC_HALL_POSITION_REQUIRED"))
    velocity = zeros(ComplexF64, n, n, 3)
    for a in 1:3
        h = vectors' * matrices.hamiltonian_derivatives[:, :, a] * vectors
        s = vectors' * matrices.overlap_derivatives[:, :, a] * vectors
        connection =
            vectors' *
            (matrices.position[:, :, a] + im * matrices.overlap_derivatives[:, :, a]) *
            vectors
        for m in 1:n, l in 1:n
            velocity[l, m, a] =
                h[l, m] - energies[m] * s[l, m] +
                im * (energies[l] - energies[m]) * connection[l, m]
        end
    end
    curvature = _nonorthogonal_ambient_curvature(matrices, vectors)
    return intrinsic_hall_geometry(
        energies,
        vectors,
        velocity,
        curvature.band,
        ;
        orthonormal_basis = false,
    )
end

"""Bare position only between opposite occupations, with no small-gap cutoff.

A direct velocity/gap division precedes multiplication by -i. This avoids an
unnecessary overflow of 1/gap when the final ratio is representable. Exact equal
levels cannot straddle this real-energy occupation boundary. Nonfinite gaps or
ratios are reported, never converted into an omitted pair.
"""
function intrinsic_hall_position_between_occupations(geometry, occupied::Integer)
    energy, velocity = geometry.energies, geometry.velocity
    n = length(energy)
    0 <= occupied <= n || throw(ArgumentError("invalid intrinsic Hall occupation count"))
    position = zeros(ComplexF64, n, n, 3)
    for l in 1:occupied, m in (occupied + 1):n
        for (left, right) in ((l, m), (m, l))
            gap = energy[left] - energy[right]
            isfinite(gap) || error("INTRINSIC_HALL_NONFINITE_ENERGY_DIFFERENCE: bands $left,$right")
            iszero(gap) && error("INTRINSIC_HALL_EQUAL_LEVEL_OCCUPATION_SPLIT")
            for a in 1:3
                value = -im * (velocity[left, right, a] / gap)
                isfinite(value) ||
                    error("INTRINSIC_HALL_NONFINITE_POSITION_RATIO: bands $left,$right axis $a")
                position[left, right, a] = value
            end
        end
    end
    return position
end
