"""Validate an optional state mask against the existing exact spectral blocks.

The mask selects an output contribution, not a replacement occupied space.
Numerical equality uses `spectral_subspace_blocks(...; gap_tolerance=0)` without
changing energies or occupations. Return `nothing` for the complete model so
its original contraction and summation order remain unchanged. The mask is read
only; the caller retains ownership.
"""
function complete_spectral_band_mask(energies, band_mask)
    band_mask === nothing && return nothing
    band_mask isa AbstractVector{Bool} && length(band_mask) == length(energies) ||
        throw(ArgumentError("A state mask must contain one Bool per model band."))
    all(band_mask) && return nothing
    for block in MatrixElements.spectral_subspace_blocks(energies; gap_tolerance = 0.0)
        selected = count(@view band_mask[block])
        0 < selected < length(block) && throw(
            ArgumentError(
                "Selected band group cuts spectral block $(collect(block)); select the complete block.",
            ),
        )
    end
    return band_mask
end

"""Return the selected part of a fixed physical occupied projector.

`vectors` is the admitted orthonormal eigenframe. Only its selected occupied
columns form the returned projector; the original occupied projector, its
complement and its derivatives are not reconstructed from the selected group.
For an omitted/full mask, return the original projector without recomputation.
"""
function occupied_group_projector(vectors, occupied, band_mask, projector)
    band_mask === nothing && return projector
    selected = Int[n for n in 1:occupied if band_mask[n]]
    frame = @view vectors[:, selected]
    return frame * frame'
end
