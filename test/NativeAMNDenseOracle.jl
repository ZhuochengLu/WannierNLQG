# Frozen dense numerical oracle from v1.1.0; evaluated only in the test extension namespace.
function _dense_native_amn_test_oracle(
    native::NativeWavefunctionData,
    basis::WannierProjectionBasis,
)
    _require_native_physical_overlap(native, :generate_wannier_amn)
    nb = size(first(native.kpoints).coefficients, 1)
    nk = length(native.kpoints)
    amn = zeros(ComplexF64, nb, basis.num_wannier, nk)
    spin_components = native.spinor ? 2 : 1
    volume_normalization = inv(sqrt(abs(det(native.structure.lattice))))
    for (kpoint_index, point) in enumerate(native.kpoints)
        band_norms = [norm(@view point.coefficients[band, :, :]) for band in 1:nb]
        all(>(1.0e-14), band_norms) ||
            throw(ArgumentError("native wavefunction contains a zero-norm band"))
        trial_matrices = [
            zeros(ComplexF64, size(point.g_vectors, 1), basis.num_wannier) for
            _ in 1:spin_components
        ]
        for block in basis.blocks, center in axes(block.positions_fractional, 2)
            local_dimension = div(size(block.indices, 1), spin_components)
            for g_index in axes(point.g_vectors, 1)
                q_fractional = point.k_fractional .+ @view(point.g_vectors[g_index, :])
                q_cartesian = transpose(native.reciprocal_lattice) * q_fractional
                local_q = @view(block.local_bases[:, :, center]) * q_cartesian
                orbital_values = projection_orbital_values(
                    block,
                    local_q;
                    radial_transform = basis.radial_transform,
                )
                length(orbital_values) == local_dimension ||
                    throw(ArgumentError("projection orbital dimension is inconsistent"))
                phase =
                    cis(-2.0 * pi * dot(q_fractional, @view(block.positions_fractional[:, center])))
                for local_index in axes(block.indices, 1)
                    spin = spin_components == 1 ? 1 : mod(local_index - 1, 2) + 1
                    orbital = spin_components == 1 ? local_index : div(local_index - 1, 2) + 1
                    wannier = block.indices[local_index, center]
                    trial = volume_normalization * phase * orbital_values[orbital]
                    trial_matrices[spin][g_index, wannier] += trial
                end
            end
        end
        for spin in 1:spin_components
            normalized_conjugate = Matrix{ComplexF64}(undef, nb, size(point.g_vectors, 1))
            @inbounds for band in 1:nb, g_index in axes(point.g_vectors, 1)
                normalized_conjugate[band, g_index] =
                    conj(point.coefficients[band, g_index, spin]) / band_norms[band]
            end
            @views amn[:, :, kpoint_index] .+= normalized_conjugate * trial_matrices[spin]
        end
        for wannier in 1:basis.num_wannier
            norm_value = norm(@view amn[:, wannier, kpoint_index])
            norm_value > 1.0e-14 || throw(
                ArgumentError(
                    "native AMN projection $(wannier) vanished at k-point $(kpoint_index)",
                ),
            )
        end
    end
    return amn
end
