"""Zero-temperature intrinsic Hall curvature before integration and prefactor.

Use each real band energy E<=mu, with no group mean or occupation threshold.
Only occupied/empty transitions use the true nonzero floating energy difference;
strictly equal energies have the same occupation. Geometry retains complete
physical velocity and ambient curvature. No finite-lifetime width is applied.
"""
function intrinsic_hall_fermi_sea(
    geometry,
    fermi_energies;
    method::Symbol = :Matrix,
    temperature::Real = 0.0,
    band_mask = nothing,
)
    isfinite(temperature) && iszero(temperature) ||
        throw(ArgumentError("INTRINSIC_HALL_REQUIRES_ZERO_TEMPERATURE"))
    mu = fermi_energies isa Real ? [Float64(fermi_energies)] : Float64.(fermi_energies)
    mu isa AbstractVector && !isempty(mu) && all(isfinite, mu) ||
        throw(ArgumentError("finite nonempty Fermi energy axis required"))
    method in (:Matrix, :Projector) ||
        throw(ArgumentError("intrinsic Hall method must be Matrix or Projector"))
    method === :Projector &&
        !geometry.orthonormal_basis &&
        throw(ArgumentError("NONORTHOGONAL_PROJECTOR_RESPONSE_UNSUPPORTED"))
    band_mask = complete_spectral_band_mask(geometry.energies, band_mask)
    result = zeros(Float64, length(mu), 3, 3)
    previous_occupied = -1
    curvature = zeros(Float64, 3, 3)
    for (i, value) in enumerate(mu)
        occupied = searchsortedlast(geometry.energies, value)
        if occupied != previous_occupied
            connection =
                MatrixElements.intrinsic_hall_position_between_occupations(geometry, occupied)
            curvature =
                method === :Matrix ?
                intrinsic_hall_matrix_curvature(geometry, occupied, connection; band_mask) :
                intrinsic_hall_projector_curvature(geometry, occupied, connection; band_mask)
            previous_occupied = occupied
        end
        result[i, :, :] = curvature
    end
    all(isfinite, result) || error("INTRINSIC_HALL_NONFINITE_RESPONSE")
    return result
end
