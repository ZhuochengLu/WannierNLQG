"""Partition a full endpoint spectrum and certify boundaries used by injection traces.

Reuse the shared full-spectrum exact partition and its anchored numerical-equality
scale. An unresolved cross-block boundary is rejected if either complete block
has active external support. Inactive blocks remain in all intermediate sums;
this response-specific check grants no inverse-gap or projector-solve capability.
"""
function _photon_drag_injection_active_spectral_blocks(energies, gap_tolerance, active_bands)
    isfinite(gap_tolerance) && gap_tolerance >= 0 ||
        throw(ArgumentError("Invalid spectral gap tolerance"))
    blocks = MatrixElements.spectral_subspace_blocks(energies; gap_tolerance = 0.0)
    for boundary in 2:length(blocks)
        left, right = blocks[boundary - 1], blocks[boundary]
        adjacent_gap = energies[first(right)] - energies[last(left)]
        if adjacent_gap <= gap_tolerance &&
           (any(view(active_bands, left)) || any(view(active_bands, right)))
            error("SPECTRAL_CROSS_BLOCK_GAP_UNRESOLVED: gap=$(adjacent_gap) eV")
        end
    end
    return blocks
end

"""Complete injection kernels with traces over exact spectral subspaces.

Singleton blocks retain the original ordered pair kernel. A nontrivial block
stores its complete trace divided by the number of valence/conduction pairs;
external occupation, resonance and transition-gap weights are summed per pair.
All intermediate sums cover the full finite model. With no active mask, retain
strict full-spectrum gap checks. With a Boolean mask, retain the identical full
exact partition and reject every unresolved boundary touching either active
external block; only boundaries between two inactive external blocks are unused.
Numerically split levels are never averaged into a spectral block.
"""
function complete_photon_drag_injection_degenerate_blocks!(
    response_kernel,
    forward_vertex,
    backward_vertex,
    overlap_1,
    overlap_2,
    valence_data,
    conduction_data,
    valence_velocity,
    conduction_velocity,
    num_orbitals::Int,
    spatial_dimension::Int;
    active_pair_mask = nothing,
    tensor_indices = nothing,
)
    if active_pair_mask === nothing
        valence_blocks = MatrixElements.spectral_subspace_blocks(
            valence_data.spectrum.energies;
            gap_tolerance = valence_data.spectral_gap_tolerance,
        )
        conduction_blocks = MatrixElements.spectral_subspace_blocks(
            conduction_data.spectrum.energies;
            gap_tolerance = conduction_data.spectral_gap_tolerance,
        )
    else
        active_pair_mask isa AbstractMatrix{Bool} ||
            throw(ArgumentError("Photon-drag active pair mask must be a Boolean matrix"))
        axes(active_pair_mask) == (Base.OneTo(num_orbitals), Base.OneTo(num_orbitals)) &&
        length(valence_data.spectrum.energies) ==
        length(conduction_data.spectrum.energies) ==
        num_orbitals || throw(DimensionMismatch("Photon-drag active pair mask/spectrum axes"))
        active_valence = vec(any(active_pair_mask; dims = 2))
        active_conduction = vec(any(active_pair_mask; dims = 1))
        valence_blocks = _photon_drag_injection_active_spectral_blocks(
            valence_data.spectrum.energies,
            valence_data.spectral_gap_tolerance,
            active_valence,
        )
        conduction_blocks = _photon_drag_injection_active_spectral_blocks(
            conduction_data.spectrum.energies,
            conduction_data.spectral_gap_tolerance,
            active_conduction,
        )
    end
    all(length(block)==1 for block in valence_blocks) &&
        all(length(block)==1 for block in conduction_blocks) &&
        return response_kernel
    directions =
        tensor_indices === nothing ? (1:spatial_dimension) :
        unique((tensor_indices[2], tensor_indices[3]))
    components =
        tensor_indices === nothing ?
        Iterators.product(1:spatial_dimension, 1:spatial_dimension, 1:spatial_dimension) :
        (Tuple(tensor_indices),)
    for valence in valence_blocks, conduction in conduction_blocks
        length(valence)==length(conduction)==1 && continue
        active_pair_mask !== nothing &&
            !any(active_pair_mask[n, m] for n in valence for m in conduction) &&
            continue
        # A block trace needs every optical entry, even when an individual pair's
        # external weight vanishes. Retain the original scalar summation order.
        for n in valence, m in conduction, direction in directions
            forward = COMPLEX_ZERO
            backward = COMPLEX_ZERO
            for intermediate in 1:num_orbitals
                forward +=
                    valence_velocity[n, intermediate, direction]*overlap_1[intermediate, m] +
                    overlap_1[n, intermediate]*conduction_velocity[intermediate, m, direction]
                backward +=
                    conduction_velocity[m, intermediate, direction]*overlap_2[intermediate, n] +
                    overlap_2[m, intermediate]*valence_velocity[intermediate, n, direction]
            end
            forward_vertex[n, m, direction] = 0.5forward
            backward_vertex[m, n, direction] = 0.5backward
        end
        for (a, b, c) in components
            conduction_trace = COMPLEX_ZERO
            valence_trace = COMPLEX_ZERO
            for m1 in conduction, m2 in conduction, n in valence
                conduction_trace +=
                    conduction_data.source_gauge_hamiltonian_derivatives[m1, m2, a] *
                    backward_vertex[m2, n, b] *
                    forward_vertex[n, m1, c]
            end
            for n1 in valence, n2 in valence, m in conduction
                valence_trace +=
                    valence_data.source_gauge_hamiltonian_derivatives[n1, n2, a] *
                    forward_vertex[n2, m, c] *
                    backward_vertex[m, n1, b]
            end
            value = (conduction_trace-valence_trace)/(length(valence)*length(conduction))
            for n in valence, m in conduction
                active_pair_mask !== nothing && !active_pair_mask[n, m] && continue
                response_kernel[n, m, a, b, c] = value
            end
        end
    end
    return response_kernel
end
