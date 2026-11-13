"""Fill response groups by adjacent energy gaps without changing scientific arrays.

For sorted energies in eV, consecutive gaps strictly below the supplied response
threshold form one connected group. Numerically equal neighbours also remain
together at zero threshold. Each member receives the complete bounds and inverse
size. Response groups may span more than the threshold; exact spectral blocks
and their independent reconstruction gap guard retain their separate contract.
Validation precedes all writes; return the caller-owned data without allocation.
"""
function _mark_response_degeneracy_groups!(data, degeneracy_threshold::Float64)
    isfinite(degeneracy_threshold) && degeneracy_threshold >= 0.0 ||
        throw(ArgumentError("Response degeneracy threshold must be finite and nonnegative"))
    energies = data.spectrum.energies
    isempty(energies) && throw(ArgumentError("Empty spectrum"))
    issorted(energies) && all(isfinite, energies) || throw(ArgumentError("Invalid spectrum"))
    numerical_equality = 32eps(Float64) * max(1.0, maximum(abs, energies))
    first_band = 1
    while first_band <= data.num_orbitals
        last_band = first_band
        while last_band < data.num_orbitals
            gap = energies[last_band + 1] - energies[last_band]
            (gap < degeneracy_threshold || gap <= numerical_equality) || break
            last_band += 1
        end
        weight = 1.0 / (last_band - first_band + 1)
        for band in first_band:last_band
            data.degeneracy_weights[band] = weight
            data.degeneracy_group_starts[band] = first_band
            data.degeneracy_group_stops[band] = last_band
        end
        first_band = last_band + 1
    end
    return data
end
