"""Physical eigenframe derivatives from the current operator jet and spectrum.

The D/D2/D3 recurrences retain the research implementation's symmetric D2
normalization/connection diagonal correction and complete intermediate-band sums.
No eigenproblem, Fourier provider, finite difference, regularizer or k-plane mask
is introduced. The workspace is worker-local, invalidated on every preparation.
The diagonal gauge is D_a[n,n]=i*A_a[n,n]; derivative contractions must not expose
these gauge-dependent matrices as observables.
"""
mutable struct OrthogonalBandDerivativeWorkspace
    jets::OrthogonalGeometryJets
    energies::Vector{Float64}
    num_orbitals::Int
    first::Array{ComplexF64, 3}
    second::Array{ComplexF64, 4}
    third::Array{ComplexF64, 5}
    energy_gradient::Matrix{Float64}
    energy_hessian::Array{Float64, 3}
    first_ready::BitVector
    second_ready::BitMatrix
    third_ready::BitArray{3}
    energy_gradient_ready::BitVector
    energy_hessian_ready::BitMatrix
    scratch_left::Matrix{ComplexF64}
    prepared::Bool
    jet_generation::UInt64
    minimum_gap_observed_ev::Float64
    preparations::Int
end

# Allocate band-energy and eigenframe derivative arrays sized to the supplied orthogonal geometry jets.
function OrthogonalBandDerivativeWorkspace(jets::OrthogonalGeometryJets)
    n=size(jets.raw, 1)
    return OrthogonalBandDerivativeWorkspace(
        jets,
        zeros(n),
        n,
        zeros(ComplexF64, n, n, 3),
        zeros(ComplexF64, n, n, 3, 3),
        zeros(ComplexF64, n, n, 3, 3, 3),
        zeros(n, 3),
        zeros(n, 3, 3),
        falses(3),
        falses(3, 3),
        falses(3, 3, 3),
        falses(3),
        falses(3, 3),
        zeros(ComplexF64, n, n),
        false,
        0,
        Inf,
        0,
    )
end

# Reject band derivatives whose preparation state or recorded jet generation is stale.
@inline function _check_orthogonal_band_derivatives(workspace::OrthogonalBandDerivativeWorkspace)
    workspace.prepared &&
    workspace.jets.prepared &&
    workspace.jet_generation == workspace.jets.generation ||
        throw(ArgumentError("orthogonal band derivative workspace is unprepared or stale"))
    return nothing
end

"""Check every pair actually needed by the smooth full-eigenframe recurrence."""
function geometry_isolated_spectrum_minimum_gap(energies, tolerance::Real)
    isfinite(tolerance) && tolerance >= 0 ||
        throw(ArgumentError("invalid spectral isolation threshold"))
    !isempty(energies) && all(isfinite, energies) ||
        throw(ArgumentError("empty/nonfinite geometry spectrum"))
    minimum_gap = Inf
    for m in eachindex(energies), l in firstindex(energies):(m - 1)
        gap = abs(energies[m] - energies[l])
        gap > tolerance || throw(
            ArgumentError(
                "GEOMETRY_SINGLE_BAND_SPECTRUM_NOT_ISOLATED: bands=($l,$m), gap_ev=$gap, threshold_ev=$tolerance",
            ),
        )
        minimum_gap = min(minimum_gap, gap)
    end
    return minimum_gap
end

"""Reset physical recurrences after the shared worker has prepared new jets.

This dense donor recurrence presently requires a smooth full eigenframe. An
unresolved degenerate complementary block is an explicit domain error, never a
zero inverse gap. This internal restriction is not a claim of complete isolated-
selected-band support; the Runtime admission must account for it before enabling
this implementation on such a spectrum.
"""
function prepare_orthogonal_band_derivatives!(
    workspace::OrthogonalBandDerivativeWorkspace,
    spectrum::KPointSpectrum;
    gap_tolerance::Real,
)
    workspace.prepared = false
    isfinite(gap_tolerance) && gap_tolerance>=0 ||
        throw(ArgumentError("invalid spectral isolation threshold"))
    workspace.jets.prepared || throw(ArgumentError("raw geometry jets must be prepared first"))
    n=workspace.num_orbitals
    length(spectrum.energies)==n || throw(DimensionMismatch("geometry spectrum length"))
    for ready in (
        workspace.first_ready,
        workspace.second_ready,
        workspace.third_ready,
        workspace.energy_gradient_ready,
        workspace.energy_hessian_ready,
    )
        fill!(ready, false)
    end
    all(isfinite, spectrum.energies) || throw(ArgumentError("nonfinite geometry spectrum"))
    minimum_gap = geometry_isolated_spectrum_minimum_gap(spectrum.energies, gap_tolerance)
    copyto!(workspace.energies, spectrum.energies)
    workspace.jet_generation = workspace.jets.generation
    workspace.minimum_gap_observed_ev = min(workspace.minimum_gap_observed_ev, minimum_gap)
    workspace.preparations += 1
    workspace.prepared = true
    return workspace
end

"""Return `D_alpha = U^dagger partial_alpha U` in the strict orthogonal branch."""
function orthogonal_band_first_derivative!(workspace::OrthogonalBandDerivativeWorkspace, alpha::Int)
    _check_orthogonal_band_derivatives(workspace)
    1 <= alpha <= 3 || throw(ArgumentError("direction must be 1, 2, or 3"))
    target = @view workspace.first[:, :, alpha]
    workspace.first_ready[alpha] && return target
    dH = geometry_hamiltonian_channel(workspace.jets, geometry_derivative_order(alpha))
    Abar = geometry_position_channel(workspace.jets, alpha, (0, 0, 0))
    @inbounds for m in 1:workspace.num_orbitals, n in 1:workspace.num_orbitals
        if n == m
            target[n, m] = im * Abar[n, m]
        else
            delta = workspace.energies[m] - workspace.energies[n]
            target[n, m] = dH[n, m] * inv(delta)
        end
    end
    workspace.first_ready[alpha] = true
    return target
end

# Cache the first energy derivative in one Cartesian direction.
function orthogonal_band_energy_gradient!(workspace::OrthogonalBandDerivativeWorkspace, alpha::Int)
    _check_orthogonal_band_derivatives(workspace)
    target = @view workspace.energy_gradient[:, alpha]
    workspace.energy_gradient_ready[alpha] && return target
    dH = geometry_hamiltonian_channel(workspace.jets, geometry_derivative_order(alpha))
    @inbounds for band in 1:workspace.num_orbitals
        target[band] = real(dH[band, band])
    end
    workspace.energy_gradient_ready[alpha] = true
    return target
end

"""Return the cached Cartesian energy derivative for a prepared analytic workspace."""
function orthogonal_band_energy_derivative!(
    workspace::OrthogonalBandDerivativeWorkspace,
    direction::Int,
)
    workspace.jets.prepared || throw(ArgumentError("analytic workspace must be prepared first"))
    return orthogonal_band_energy_gradient!(workspace, direction)
end

# Cache the second energy derivative for one ordered Cartesian pair.
function orthogonal_band_energy_hessian!(
    workspace::OrthogonalBandDerivativeWorkspace,
    alpha::Int,
    beta::Int,
)
    _check_orthogonal_band_derivatives(workspace)
    target = @view workspace.energy_hessian[:, alpha, beta]
    workspace.energy_hessian_ready[alpha, beta] && return target
    dHalpha = geometry_hamiltonian_channel(workspace.jets, geometry_derivative_order(alpha))
    dHbeta = geometry_hamiltonian_channel(workspace.jets, geometry_derivative_order(beta))
    dHalphabeta =
        geometry_hamiltonian_channel(workspace.jets, geometry_derivative_order(alpha, beta))
    Dalpha = orthogonal_band_first_derivative!(workspace, alpha)
    Dbeta = orthogonal_band_first_derivative!(workspace, beta)
    dEalpha = orthogonal_band_energy_gradient!(workspace, alpha)
    dEbeta = orthogonal_band_energy_gradient!(workspace, beta)
    @inbounds for n in 1:workspace.num_orbitals
        value = dHalphabeta[n, n]
        for middle in 1:workspace.num_orbitals
            value += dHalpha[n, middle] * Dbeta[middle, n]
            value += dHbeta[n, middle] * Dalpha[middle, n]
        end
        value -= Dalpha[n, n] * dEbeta[n] + Dbeta[n, n] * dEalpha[n]
        target[n] = real(value)
    end
    workspace.energy_hessian_ready[alpha, beta] = true
    return target
end

"""
Return `D_alpha_beta = U^dagger partial_alpha partial_beta U`.

The diagonal is the symmetric covariant connection jet. Its real part follows from
differentiating `U^dagger U = I` twice, while its imaginary part retains the Berry
connection and is averaged under `alpha <-> beta`.
"""
function orthogonal_band_second_derivative!(
    workspace::OrthogonalBandDerivativeWorkspace,
    alpha::Int,
    beta::Int,
)
    _check_orthogonal_band_derivatives(workspace)
    target = @view workspace.second[:, :, alpha, beta]
    workspace.second_ready[alpha, beta] && return target
    dHalpha = geometry_hamiltonian_channel(workspace.jets, geometry_derivative_order(alpha))
    dHbeta = geometry_hamiltonian_channel(workspace.jets, geometry_derivative_order(beta))
    dHalphabeta =
        geometry_hamiltonian_channel(workspace.jets, geometry_derivative_order(alpha, beta))
    Dalpha = orthogonal_band_first_derivative!(workspace, alpha)
    Dbeta = orthogonal_band_first_derivative!(workspace, beta)
    dEalpha = orthogonal_band_energy_gradient!(workspace, alpha)
    dEbeta = orthogonal_band_energy_gradient!(workspace, beta)
    Aalpha = geometry_position_channel(workspace.jets, alpha, (0, 0, 0))
    Abeta = geometry_position_channel(workspace.jets, beta, (0, 0, 0))
    dAalphabeta = geometry_position_channel(workspace.jets, alpha, geometry_derivative_order(beta))
    dAbetaalpha = geometry_position_channel(workspace.jets, beta, geometry_derivative_order(alpha))
    mul!(target, dHalpha, Dbeta)
    mul!(workspace.scratch_left, dHbeta, Dalpha)
    target .+= workspace.scratch_left
    @inbounds for m in 1:workspace.num_orbitals, n in 1:workspace.num_orbitals
        if n != m
            delta = workspace.energies[m] - workspace.energies[n]
            numerator = dHalphabeta[n, m] + target[n, m]
            numerator -= dEalpha[m] * Dbeta[n, m] + dEbeta[m] * Dalpha[n, m]
            target[n, m] = numerator * inv(delta)
        else
            commutator_alphabeta = zero(ComplexF64)
            commutator_betaalpha = zero(ComplexF64)
            for middle in 1:workspace.num_orbitals
                commutator_alphabeta += Dbeta[n, middle] * Aalpha[middle, n]
                commutator_alphabeta -= Aalpha[n, middle] * Dbeta[middle, n]
                commutator_betaalpha += Dalpha[n, middle] * Abeta[middle, n]
                commutator_betaalpha -= Abeta[n, middle] * Dalpha[middle, n]
            end
            dd_symmetric = zero(ComplexF64)
            for middle in 1:workspace.num_orbitals
                dd_symmetric += Dbeta[n, middle] * Dalpha[middle, n]
                dd_symmetric += Dalpha[n, middle] * Dbeta[middle, n]
            end
            connection_jet =
                0.5 * real(
                    dAalphabeta[n, n] - commutator_alphabeta + dAbetaalpha[n, n] -
                    commutator_betaalpha,
                )
            target[n, n] = 0.5 * real(dd_symmetric) + im * connection_jet
        end
    end
    workspace.second_ready[alpha, beta] = true
    return target
end

"""Return `D_alpha_beta_gamma = U^dagger partial_alpha partial_beta partial_gamma U`."""
function orthogonal_band_third_derivative!(
    workspace::OrthogonalBandDerivativeWorkspace,
    alpha::Int,
    beta::Int,
    gamma::Int,
)
    _check_orthogonal_band_derivatives(workspace)
    target = @view workspace.third[:, :, alpha, beta, gamma]
    workspace.third_ready[alpha, beta, gamma] && return target
    dHalpha = geometry_hamiltonian_channel(workspace.jets, geometry_derivative_order(alpha))
    dHbeta = geometry_hamiltonian_channel(workspace.jets, geometry_derivative_order(beta))
    dHgamma = geometry_hamiltonian_channel(workspace.jets, geometry_derivative_order(gamma))
    dHalphabeta =
        geometry_hamiltonian_channel(workspace.jets, geometry_derivative_order(alpha, beta))
    dHbetagamma =
        geometry_hamiltonian_channel(workspace.jets, geometry_derivative_order(beta, gamma))
    dHgammaalpha =
        geometry_hamiltonian_channel(workspace.jets, geometry_derivative_order(gamma, alpha))
    dHalphabetagamma =
        geometry_hamiltonian_channel(workspace.jets, geometry_derivative_order(alpha, beta, gamma))
    Dalpha = orthogonal_band_first_derivative!(workspace, alpha)
    Dbeta = orthogonal_band_first_derivative!(workspace, beta)
    Dgamma = orthogonal_band_first_derivative!(workspace, gamma)
    Dalphabeta = orthogonal_band_second_derivative!(workspace, alpha, beta)
    Dgammaalpha = orthogonal_band_second_derivative!(workspace, gamma, alpha)
    Dbetagamma = orthogonal_band_second_derivative!(workspace, beta, gamma)
    dEalpha = orthogonal_band_energy_gradient!(workspace, alpha)
    dEbeta = orthogonal_band_energy_gradient!(workspace, beta)
    dEgamma = orthogonal_band_energy_gradient!(workspace, gamma)
    dEalphabeta = orthogonal_band_energy_hessian!(workspace, alpha, beta)
    dEbetagamma = orthogonal_band_energy_hessian!(workspace, beta, gamma)
    dEgammaalpha = orthogonal_band_energy_hessian!(workspace, gamma, alpha)

    fill!(target, 0)
    for (left, right) in (
        (dHalphabeta, Dgamma),
        (dHbetagamma, Dalpha),
        (dHgammaalpha, Dbeta),
        (dHalpha, Dbetagamma),
        (dHbeta, Dgammaalpha),
        (dHgamma, Dalphabeta),
    )
        mul!(workspace.scratch_left, left, right)
        target .+= workspace.scratch_left
    end
    @inbounds for m in 1:workspace.num_orbitals, n in 1:workspace.num_orbitals
        if n != m
            numerator = dHalphabetagamma[n, m] + target[n, m]
            numerator -=
                Dalpha[n, m] * dEbetagamma[m] +
                Dbeta[n, m] * dEgammaalpha[m] +
                Dgamma[n, m] * dEalphabeta[m]
            numerator -=
                Dalphabeta[n, m] * dEgamma[m] +
                Dbetagamma[n, m] * dEalpha[m] +
                Dgammaalpha[n, m] * dEbeta[m]
            delta = workspace.energies[m] - workspace.energies[n]
            target[n, m] = numerator * inv(delta)
        else
            target[n, n] = 0
        end
    end
    workspace.third_ready[alpha, beta, gamma] = true
    return target
end
