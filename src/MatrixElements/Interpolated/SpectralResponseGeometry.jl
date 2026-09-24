
"""Geometry for first-order response, with energies in eV and Cartesian connection in Å.

Blocks contain only numerically equal eigenvalues. Close but distinct eigenvalues are
never averaged. Covariant Hamiltonian derivatives include the physical connection.
"""
struct SpectralResponseGeometry
    energies::Vector{Float64}
    eigenvectors::Matrix{ComplexF64}
    connection::Array{ComplexF64, 3}
    covariant_hamiltonian::Array{ComplexF64, 3}
    curvature::Array{ComplexF64, 4}
    blocks::Vector{UnitRange{Int}}
end

"""Construct block-resolved geometry without regularizing physical transition denominators."""
function spectral_response_geometry(
    energies,
    eigenvectors,
    hamiltonian_derivatives,
    connection,
    curvature;
    gap_tolerance = 1e-10,
)
    energy = Float64.(energies)
    issorted(energy) || throw(ArgumentError("Spectrum must be sorted"))
    all(isfinite, energy) || throw(ArgumentError("Nonfinite spectrum"))
    count = length(energy)
    blocks = UnitRange{Int}[]
    start = 1
    exact = 32eps(Float64) * max(1.0, maximum(abs, energy))
    for n in 2:count
        gap = energy[n] - energy[n - 1]
        if gap > exact
            gap > gap_tolerance || error("SPECTRAL_CROSS_BLOCK_GAP_UNRESOLVED: gap=$gap eV")
            push!(blocks, start:(n - 1))
            start = n
        end
    end
    push!(blocks, start:count)
    for a in 1:3
        maximum(abs, hamiltonian_derivatives[:, :, a]-hamiltonian_derivatives[:, :, a]')<=1e-8 ||
            error("SPECTRAL_HAMILTONIAN_DERIVATIVE_NOT_HERMITIAN")
        maximum(abs, connection[:, :, a]-connection[:, :, a]')<=1e-8 ||
            error("SPECTRAL_POSITION_NOT_HERMITIAN")
    end
    vertex = ComplexF64.(hamiltonian_derivatives)
    physical_connection = ComplexF64.(connection)
    for a in 1:3, m in 1:count, n in 1:count
        vertex[n, m, a] += im * (energy[n]-energy[m]) * connection[n, m, a]
    end
    # Only cross-block position entries are needed; block interiors stay in the
    # velocity vertex, including possible non-scalar velocities at a crossing.
    for left in blocks, right in blocks
        left == right && continue
        for a in 1:3, m in right, n in left
            physical_connection[n, m, a] = -im * vertex[n, m, a] / (energy[n]-energy[m])
        end
    end
    return SpectralResponseGeometry(
        energy,
        ComplexF64.(eigenvectors),
        physical_connection,
        vertex,
        ComplexF64.(curvature),
        blocks,
    )
end

"""Read unregularized first-order capabilities from the interpolation payload."""
function spectral_response_geometry(data::KPointMatrixData; gap_tolerance = 1e-10)
    return spectral_response_geometry(
        data.spectrum.energies,
        data.spectrum.eigenvectors,
        data.hamiltonian.derivatives,
        data.position.internal_connection,
        data.position.hamiltonian_curvature;
        gap_tolerance,
    )
end

"""Matrix-element Q for a pair of complete spectral blocks, in Å²."""
function conventional_spectral_pair(geometry::SpectralResponseGeometry, left, right)
    result=zeros(ComplexF64, 3, 3)
    for b in 1:3, a in 1:3, m in right, n in left
        result[a, b]+=geometry.connection[n, m, a]*geometry.connection[m, n, b]
    end
    return result
end

"""Independent projector derivative contraction Tr[P(DaP)Q(DbP)] in the orbital frame."""
function projector_spectral_pair(geometry::SpectralResponseGeometry, left, right)
    u=geometry.eigenvectors
    p=u[:, left]*u[:, left]'
    q=u[:, right]*u[:, right]'
    derivatives=Matrix{ComplexF64}[]
    for a in 1:3
        derivative=zeros(ComplexF64, length(geometry.energies), length(geometry.energies))
        for m in eachindex(geometry.energies), n in left
            m in left && continue
            value=geometry.covariant_hamiltonian[
                m,
                n,
                a,
            ]/(geometry.energies[n]-geometry.energies[m])
            derivative[m, n]=value
            derivative[n, m]=conj(value)
        end
        push!(derivatives, u*derivative*u')
    end
    return ComplexF64[tr(p*derivatives[a]*q*derivatives[b]) for a in 1:3, b in 1:3]
end

"""External completion in the same Hamiltonian frame as the response geometry.

F and C carry two Cartesian indices; B one. Zeros are valid only for an
explicitly defined complete finite model, never a missing material operator.
"""
struct OrbitalCompletion
    derivative_overlap::Array{ComplexF64, 4}
    energy_connection::Array{ComplexF64, 3}
    energy_overlap::Array{ComplexF64, 4}
end

"""Allocate zero external completion for a declared complete finite model."""
function finite_model_orbital_completion(count::Integer)
    return OrbitalCompletion(
        zeros(ComplexF64, count, count, 3, 3),
        zeros(ComplexF64, count, count, 3),
        zeros(ComplexF64, count, count, 3, 3),
    )
end

"""Contract a complete spectral block velocity tensor in its orbital projector frame."""
function projector_block_velocity(geometry::SpectralResponseGeometry, block)
    u=geometry.eigenvectors
    p=u[:, block]*u[:, block]'
    velocities=[u*geometry.covariant_hamiltonian[:, :, a]*u' for a in 1:3]
    return [real(tr(p*velocities[a]*p*velocities[b])) for a in 1:3, b in 1:3]
end

"""Trace the ambient curvature against one whole orbital-frame spectral projector."""
function projector_block_curvature(geometry::SpectralResponseGeometry, block)
    u=geometry.eigenvectors
    p=u[:, block]*u[:, block]'
    return [real(tr(p*u*geometry.curvature[:, :, a, b]*u')) for a in 1:3, b in 1:3]
end
