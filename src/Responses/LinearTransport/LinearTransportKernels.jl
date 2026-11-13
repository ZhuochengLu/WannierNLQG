
const LINEAR_TRANSPORT_TERMS = (:drude, :quantum_metric, :berry_curvature, :total)

"""Build every μ-independent dc transport contraction once for one k point."""
function linear_transport_kernel(geometry; projector = false)
    energy = geometry.energies
    drude = Tuple{Float64, Matrix{Float64}}[]
    if projector
        for block in geometry.blocks
            push!(
                drude,
                (
                    energy[first(block)],
                    Matrix{Float64}(MatrixElements.projector_block_velocity(geometry, block)),
                ),
            )
        end
    else
        for block in geometry.blocks, n in block
            weight = zeros(Float64, 3, 3)
            for m in block, b in 1:3, a in 1:3
                weight[a, b] += real(
                    geometry.covariant_hamiltonian[n, m, a] *
                    geometry.covariant_hamiltonian[m, n, b],
                )
            end
            push!(drude, (energy[n], weight))
        end
    end
    interband = Tuple{Float64, Float64, Float64, Matrix{ComplexF64}}[]
    for i in eachindex(geometry.blocks), j in (i + 1):length(geometry.blocks)
        left, right = geometry.blocks[i], geometry.blocks[j]
        push!(
            interband,
            (
                energy[first(left)],
                energy[first(right)],
                energy[first(right)] - energy[first(left)],
                Matrix{ComplexF64}(
                    projector ? projector_spectral_pair(geometry, left, right) :
                    conventional_spectral_pair(geometry, left, right),
                ),
            ),
        )
    end
    contact = Tuple{Float64, Matrix{Float64}}[]
    if projector
        for block in geometry.blocks
            push!(
                contact,
                (
                    energy[first(block)],
                    Matrix{Float64}(MatrixElements.projector_block_curvature(geometry, block)),
                ),
            )
        end
    else
        for n in eachindex(energy)
            curvature = zeros(Float64, 3, 3)
            for b in 1:3, a in 1:3
                curvature[a, b] = real(geometry.curvature[n, n, a, b])
            end
            push!(contact, (energy[n], curvature))
        end
    end
    return (; drude, interband, contact)
end

"""Strict vectorized dc point conductivity in S m², prior to BZ weights and cell volume.

The dimensions are μ, Cartesian, Cartesian, and the named term order
`drude, quantum_metric, berry_curvature, total`. The Berry-curvature channel
combines the ambient-curvature contact and interband Hall summands.
"""
function linear_transport_response(
    geometry;
    projector = false,
    fermi_energies::Vector{Float64},
    temperature,
    gamma_intra_ev,
    gamma_inter_ev,
    fs_kind = :none,
    eta_fs_ev = 0.0,
)
    return _linear_transport_response(
        geometry,
        Val(temperature == 0);
        projector,
        fermi_energies,
        temperature,
        gamma_intra_ev,
        gamma_inter_ev,
        fs_kind,
        eta_fs_ev,
    )
end

# Two bounded specializations: T=0 exact-zero arithmetic and the unchanged
# positive-temperature arithmetic. No physical threshold or band mask is added.
function _linear_transport_response(
    geometry,
    ::Val{SKIP_ZERO};
    projector = false,
    fermi_energies::Vector{Float64},
    temperature,
    gamma_intra_ev,
    gamma_inter_ev,
    fs_kind = :none,
    eta_fs_ev = 0.0,
) where {SKIP_ZERO}
    axis = validate_fermi_energies(fermi_energies)
    # Keep the four algebraic summands in their original accumulation order so
    # the unchanged total retains its established numerical baseline.
    summands = zeros(Float64, length(axis), 3, 3, 5)
    factor = RESPONSE_CHARGE_C^2 / RESPONSE_HBAR_JS * 1e-20
    kernel = linear_transport_kernel(geometry; projector)
    # Preserve invalid-data propagation: only finite q/gap/rate with a nonzero
    # original denominator can omit exact-zero multiplication/addition.
    eligible = if SKIP_ZERO
        [
            isfinite(gap) &&
                isfinite(gamma_inter_ev) &&
                !iszero(gap^2 + gamma_inter_ev^2) &&
                all(isfinite, q) for (_, _, gap, q) in kernel.interband
        ]
    else
        nothing
    end
    for (mu_index, fermi_energy) in enumerate(axis)
        for (energy, weight) in kernel.contact
            occupation = response_occupation(energy, fermi_energy, temperature)
            @views summands[mu_index, :, :, 1] .-= factor * occupation .* weight
        end
        for (energy, weight) in kernel.drude
            derivative =
                response_fermi_derivative(energy, fermi_energy, temperature, fs_kind, eta_fs_ev)
            @views summands[mu_index, :, :, 2] .+= factor * derivative .* weight ./ gamma_intra_ev
        end
        for (index, (left_energy, right_energy, gap, q)) in enumerate(kernel.interband)
            occupation =
                response_occupation(left_energy, fermi_energy, temperature) -
                response_occupation(right_energy, fermi_energy, temperature)
            if SKIP_ZERO && eligible[index] && iszero(occupation)
                continue
            end
            for b in 1:3, a in 1:3
                summands[mu_index, a, b, 3] +=
                    2factor * occupation * gap * gamma_inter_ev / (gap^2 + gamma_inter_ev^2) *
                    real(q[a, b])
                summands[mu_index, a, b, 4] +=
                    2factor * occupation * gap^2 / (gap^2 + gamma_inter_ev^2) * imag(q[a, b])
            end
        end
        @views summands[mu_index, :, :, 5] .=
            dropdims(sum(summands[mu_index, :, :, 1:4]; dims = 3); dims = 3)
    end
    result = zeros(Float64, length(axis), 3, 3, length(LINEAR_TRANSPORT_TERMS))
    @views result[:, :, :, 1] .= summands[:, :, :, 2]
    @views result[:, :, :, 2] .= summands[:, :, :, 3]
    @views result[:, :, :, 3] .= summands[:, :, :, 1] .+ summands[:, :, :, 4]
    @views result[:, :, :, 4] .= summands[:, :, :, 5]
    return result
end
