
const LINEAR_OPTICAL_TERMS = (:drude, :quantum_metric, :berry_curvature, :total)

"""Complex optical point conductivity in S m² with shape (energy,a,b,term).

Both resonant and antiresonant poles are retained. Physical linewidths are in eV;
the derivative of the occupation is in inverse eV, distinct from either linewidth.
"""
function linear_optical_response(
    geometry,
    photon_energies;
    projector = false,
    fermi_energy,
    temperature,
    gamma_intra_ev,
    gamma_inter_ev,
    fs_kind = :none,
    eta_fs_ev = 0.0,
)
    # Preserve the established four-summand total before combining the two
    # Hall-related summands into one externally visible response mechanism.
    summands=zeros(ComplexF64, length(photon_energies), 3, 3, 5)
    energy=geometry.energies
    factor=RESPONSE_CHARGE_C^2/RESPONSE_HBAR_JS*1e-20
    if projector
        for block in geometry.blocks
            derivative=response_fermi_derivative(
                energy[first(block)],
                fermi_energy,
                temperature,
                fs_kind,
                eta_fs_ev,
            )
            velocity=MatrixElements.projector_block_velocity(geometry, block)
            for (index, photon) in enumerate(photon_energies)
                summands[index, :, :, 1] .+=
                    factor*derivative .* velocity ./ (gamma_intra_ev-im*photon)
            end
        end
    else
        for block in geometry.blocks, n in block, m in block, b in 1:3, a in 1:3
            derivative=response_fermi_derivative(
                energy[n],
                fermi_energy,
                temperature,
                fs_kind,
                eta_fs_ev,
            )
            weight=factor*derivative*real(
                geometry.covariant_hamiltonian[n, m, a]*geometry.covariant_hamiltonian[m, n, b],
            )
            for (index, photon) in enumerate(photon_energies)
                summands[index, a, b, 1]+=weight/(gamma_intra_ev-im*photon)
            end
        end
    end
    for i in eachindex(geometry.blocks), j in (i + 1):length(geometry.blocks)
        left, right=geometry.blocks[i], geometry.blocks[j]
        gap=energy[first(right)]-energy[first(left)]
        occupation=response_occupation(
            energy[first(left)],
            fermi_energy,
            temperature,
        )-response_occupation(energy[first(right)], fermi_energy, temperature)
        q=projector ? projector_spectral_pair(geometry, left, right) :
          conventional_spectral_pair(geometry, left, right)
        for (index, photon) in enumerate(photon_energies), b in 1:3, a in 1:3
            z=photon+im*gamma_inter_ev
            summands[index, a, b, 2]+=-2im*factor*occupation*gap*z/(gap^2-z^2)*real(q[a, b])
            summands[index, a, b, 3]+=2factor*occupation*gap^2/(gap^2-z^2)*imag(q[a, b])
        end
    end
    if projector
        for block in geometry.blocks
            occupation=response_occupation(energy[first(block)], fermi_energy, temperature)
            curvature=MatrixElements.projector_block_curvature(geometry, block)
            for index in eachindex(photon_energies)
                summands[index, :, :, 4] .-= factor*occupation .* curvature
            end
        end
    else
        for n in eachindex(energy), b in 1:3, a in 1:3
            value=-factor*response_occupation(energy[n], fermi_energy, temperature)*real(
                geometry.curvature[n, n, a, b],
            )
            summands[:, a, b, 4].+=value
        end
    end
    summands[:, :, :, 5].=dropdims(sum(summands[:, :, :, 1:4]; dims = 4); dims = 4)
    result=zeros(ComplexF64, length(photon_energies), 3, 3, length(LINEAR_OPTICAL_TERMS))
    result[:, :, :, 1].=summands[:, :, :, 1]
    result[:, :, :, 2].=summands[:, :, :, 2]
    result[:, :, :, 3].=summands[:, :, :, 3] .+ summands[:, :, :, 4]
    result[:, :, :, 4].=summands[:, :, :, 5]
    return result
end

"""Convert positive-frequency conductivity to increments; background only follows full BZ integration."""
function model_dielectric_response(conductivity, photon_energies; integrated::Bool)
    valid=findall(>(0), photon_energies)
    increments=copy(conductivity[valid, :, :, :])
    for (row, index) in enumerate(valid)
        increments[row, :, :, :].*=im/(RESPONSE_EPSILON0*photon_energies[index]/RESPONSE_HBAR_EVS)
    end
    total=copy(increments[:, :, :, end])
    if integrated
        for row in eachindex(valid), a in 1:3
            total[row, a, a]+=1
        end
    end
    return (;
        indices = valid,
        increments,
        total,
        undefined_zero_frequency = findall(iszero, photon_energies),
    )
end
