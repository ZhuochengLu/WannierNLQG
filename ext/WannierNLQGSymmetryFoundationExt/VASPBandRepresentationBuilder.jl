# The VASP adapter shares the same canonical construction path as QE SAWF input.
function _build_band_representation(
    native::NativeWavefunctionData,
    energies_ev::Matrix{Float64},
    operations::Vector{SymmetryOperation},
    degeneracy_tolerance_ev::Float64;
    symmetry_inventory = nothing,
    plane_wave_convention::Symbol = :canonical,
    diagnostic_outer_masks = nothing,
    diagnostic_frozen_masks = nothing,
    return_diagnostics::Bool = false,
)
    built = build_canonical_band_representation(
        native,
        energies_ev,
        operations,
        degeneracy_tolerance_ev;
        symmetry_inventory,
        plane_wave_convention,
        diagnostic_outer_masks,
        diagnostic_frozen_masks,
    )
    return return_diagnostics ? built : built.representation
end
