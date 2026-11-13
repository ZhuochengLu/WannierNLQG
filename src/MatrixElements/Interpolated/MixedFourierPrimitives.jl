"""Positive Bloch phase shared by the single- and two-momentum packers; preserve scalar evaluation order."""
@inline function mixed_bloch_phase(r1, r2, r3, point)
    return cis(2pi * (r1 * point[1] + r2 * point[2] + r3 * point[3]))
end

# Accumulate R blocks into FFT bins with positive Bloch phase and R-degeneracy weights; optionally gather compact source channels.
function mixed_pack_translations!(
    flattened,
    source_flat,
    residue_vectors,
    fft_shape,
    phase_vectors,
    degeneracies,
    phase_point,
    ::Nothing,
)
    for r_index in 1:size(phase_vectors, 2)
        i1 = mod(residue_vectors[1, r_index], fft_shape[1])
        i2 = mod(residue_vectors[2, r_index], fft_shape[2])
        i3 = mod(residue_vectors[3, r_index], fft_shape[3])
        linear = 1 + i1 + fft_shape[1] * (i2 + fft_shape[2] * i3)
        r1 = phase_vectors[1, r_index]
        r2 = phase_vectors[2, r_index]
        r3 = phase_vectors[3, r_index]
        factor = mixed_bloch_phase(r1, r2, r3, phase_point) / degeneracies[r_index]
        for value_index in axes(source_flat, 1)
            flattened[linear, value_index] += factor * source_flat[value_index, r_index]
        end
    end
    return flattened
end

# Accumulate R blocks into FFT bins with positive Bloch phase and R-degeneracy weights; optionally gather compact source channels.
function mixed_pack_translations!(
    flattened,
    source_flat,
    residue_vectors,
    fft_shape,
    phase_vectors,
    degeneracies,
    phase_point,
    source_indices::Vector{Int},
)
    for r_index in 1:size(phase_vectors, 2)
        i1 = mod(residue_vectors[1, r_index], fft_shape[1])
        i2 = mod(residue_vectors[2, r_index], fft_shape[2])
        i3 = mod(residue_vectors[3, r_index], fft_shape[3])
        linear = 1 + i1 + fft_shape[1] * (i2 + fft_shape[2] * i3)
        r1 = phase_vectors[1, r_index]
        r2 = phase_vectors[2, r_index]
        r3 = phase_vectors[3, r_index]
        factor = mixed_bloch_phase(r1, r2, r3, phase_point) / degeneracies[r_index]
        for value_index in eachindex(source_indices)
            flattened[linear, value_index] +=
                factor * source_flat[source_indices[value_index], r_index]
        end
    end
    return flattened
end
