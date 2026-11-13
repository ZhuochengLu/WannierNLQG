
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
    blocks = spectral_subspace_blocks(energy; gap_tolerance)
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
    solve_subspace_position!(physical_connection, energy, vertex, blocks; gap_tolerance)
    return SpectralResponseGeometry(
        energy,
        ComplexF64.(eigenvectors),
        physical_connection,
        vertex,
        ComplexF64.(curvature),
        blocks,
    )
end

"""Borrow prepared regularized r_eta, complete V and curvature for one endpoint.

This adapter does not solve another position equation or regularize physical
transition denominators. Array aliases expire at the next workspace evaluation.
The OM response builds its own finite-width tangent from complete V.
The array-based expert constructor retains its independent exact spectral role.
"""
function spectral_response_geometry(data::KPointMatrixData; gap_tolerance = 1e-10)
    _has_capability(data.computed_mask, BERRY_CONNECTION) ||
        throw(ArgumentError("SPECTRAL_REGULARIZED_POSITION_NOT_COMPUTED"))
    _has_capability(data.computed_mask, WANNIER_CURVATURE) ||
        throw(ArgumentError("SPECTRAL_CURVATURE_NOT_COMPUTED"))
    isfinite(data.position_regularization_ev) && data.position_regularization_ev > 0 ||
        throw(ArgumentError("spectral position regularization must be finite and positive"))
    return SpectralResponseGeometry(
        data.spectrum.energies,
        data.spectrum.eigenvectors,
        data.position.berry_connection,
        physical_velocity_vertices(data),
        data.position.hamiltonian_curvature,
        spectral_subspace_blocks(data.spectrum.energies; gap_tolerance),
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
            value=-im * geometry.connection[m, n, a]
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

"""Metric scalar response geometry; its vectors are S-normalized, not Euclidean projectors.

This wrapper prevents accidental use of the orthogonal C*C' projector helpers.
Connection and velocity retain the same D_eta and physical-velocity contract.
"""
struct NonorthogonalSpectralResponseGeometry{G}
    base::G
    denominator_regularization_ev::Float64
end
"""Expose the scalar payload while preserving metric backend identity."""
function Base.getproperty(geometry::NonorthogonalSpectralResponseGeometry, name::Symbol)
    name in (:base, :denominator_regularization_ev) && return getfield(geometry, name)
    return getproperty(getfield(geometry, :base), name)
end
"""Read planned metric geometry without recomputing or overwriting A_eta."""
function spectral_response_geometry(
    data::KPointMatrixData{H, P};
    gap_tolerance = 1e-10,
) where {H, P <: NonorthogonalPositionMatrixData}
    isfinite(gap_tolerance) && gap_tolerance>=0 ||
        throw(ArgumentError("Invalid spectral reporting tolerance"))
    all(
        x->x!==nothing,
        (data.berry_connection, data.velocity_vertices, data.hamiltonian_curvature),
    ) || throw(
        ArgumentError(
            "metric spectral geometry requires planned A_eta, physical velocity and ambient curvature",
        ),
    )
    e=copy(data.spectrum.energies)
    # Equal-energy intervals only; a small nonzero gap is not rejected or averaged.
    blocks=spectral_subspace_blocks(e; gap_tolerance = 0.0)
    base=SpectralResponseGeometry(
        e,
        copy(data.spectrum.eigenvectors),
        copy(data.berry_connection),
        copy(data.velocity_vertices),
        copy(data.hamiltonian_curvature),
        blocks,
    )
    all(x->all(isfinite, x), (base.connection, base.covariant_hamiltonian, base.curvature)) ||
        throw(ArgumentError("nonfinite metric spectral geometry"))
    # Recover eta from the inverse-gap channel is impossible at a zero gap.
    # The planned parameter is attached to the position payload explicitly.
    return NonorthogonalSpectralResponseGeometry(base, data.position.denominator_regularization_ev)
end
"""Contract the prepared metric band connection without constructing orbital projectors.

The borrowed base already contains the S-normalized scalar-frame connection in Å.
Use its existing ordered block-pair contraction unchanged: no extra S factor,
Euclidean C*C' projector, energy averaging or denominator regularization is added.
"""
conventional_spectral_pair(geometry::NonorthogonalSpectralResponseGeometry, left, right) =
    conventional_spectral_pair(geometry.base, left, right)

"""Reject Euclidean projector pair contractions for metric-normalized vectors."""
projector_spectral_pair(::NonorthogonalSpectralResponseGeometry, left, right) =
    throw(ArgumentError("NONORTHOGONAL_PROJECTOR_RESPONSE_UNSUPPORTED"))
"""Reject Euclidean projector velocity contractions for metric-normalized vectors."""
projector_block_velocity(::NonorthogonalSpectralResponseGeometry, block) =
    throw(ArgumentError("NONORTHOGONAL_PROJECTOR_RESPONSE_UNSUPPORTED"))
"""Reject Euclidean projector curvature contractions for metric-normalized vectors."""
projector_block_curvature(::NonorthogonalSpectralResponseGeometry, block) =
    throw(ArgumentError("NONORTHOGONAL_PROJECTOR_RESPONSE_UNSUPPORTED"))
