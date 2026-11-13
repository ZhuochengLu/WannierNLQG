"""Per-k D[mu,a,b,c], before the actual domain measure and SI conversion.

FS consumes curvature and Cartesian energy gradients; sea consumes local BCD.
Each explicit eigenstate contributes once. Unused inputs may be `nothing`;
missing consumed geometry is never replaced by zero.
"""
function berry_dipole_moments!(
    output::AbstractArray{Float64, 4},
    energies,
    fermi_energies,
    parameters::BerryMultipoleDCParameters;
    curvature = nothing,
    energy_gradient = nothing,
    dipole = nothing,
)
    n = length(energies)
    size(output) == (length(fermi_energies), 3, 3, 3) ||
        throw(DimensionMismatch("BCD moment shape"))
    if parameters.integral_form == :fermi_surface
        curvature !== nothing && energy_gradient !== nothing ||
            throw(ArgumentError("BCD FS requires curvature and energy gradient"))
        size(curvature) == (n, 3, 3) && size(energy_gradient) == (n, 3) ||
            throw(DimensionMismatch("BCD FS geometry shape"))
        all(isfinite, curvature) && all(isfinite, energy_gradient) ||
            throw(ArgumentError("nonfinite BCD FS geometry"))
    else
        dipole !== nothing || throw(ArgumentError("BCD sea requires local BCD"))
        size(dipole) == (n, 3, 3, 3) || throw(DimensionMismatch("local BCD shape"))
        all(isfinite, dipole) || throw(ArgumentError("nonfinite local BCD"))
    end
    fill!(output, 0)
    for band in eachindex(energies), mu in eachindex(fermi_energies)
        weight =
            parameters.integral_form == :fermi_surface ?
            berry_multipole_surface_weight(parameters, energies[band], fermi_energies[mu]) :
            berry_multipole_sea_weight(parameters, energies[band], fermi_energies[mu])
        for a in 1:3, b in 1:3, c in 1:3
            value =
                parameters.integral_form == :fermi_surface ?
                curvature[band, a, b] * energy_gradient[band, c] : dipole[band, a, b, c]
            output[mu, a, b, c] += weight * value
        end
    end
    all(isfinite, output) || throw(ArgumentError("nonfinite BCD moment integrand"))
    return output
end

"""Per-k Q[mu,a,b,c,d], using sea or the approved once-IBP FS expression."""
function berry_quadrupole_moments!(
    output::AbstractArray{Float64, 5},
    energies,
    fermi_energies,
    parameters::BerryMultipoleDCParameters;
    energy_gradient = nothing,
    dipole = nothing,
    quadrupole = nothing,
)
    n = length(energies)
    size(output) == (length(fermi_energies), 3, 3, 3, 3) ||
        throw(DimensionMismatch("BCQ moment shape"))
    if parameters.integral_form == :fermi_surface
        energy_gradient !== nothing && dipole !== nothing ||
            throw(ArgumentError("BCQ FS requires energy gradient and local BCD"))
        size(energy_gradient) == (n, 3) && size(dipole) == (n, 3, 3, 3) ||
            throw(DimensionMismatch("BCQ FS geometry shape"))
        all(isfinite, energy_gradient) && all(isfinite, dipole) ||
            throw(ArgumentError("nonfinite BCQ FS geometry"))
    else
        quadrupole !== nothing || throw(ArgumentError("BCQ sea requires local BCQ"))
        size(quadrupole) == (n, 3, 3, 3, 3) || throw(DimensionMismatch("local BCQ shape"))
        all(isfinite, quadrupole) || throw(ArgumentError("nonfinite local BCQ"))
    end
    fill!(output, 0)
    for band in eachindex(energies), mu in eachindex(fermi_energies)
        weight =
            parameters.integral_form == :fermi_surface ?
            berry_multipole_surface_weight(parameters, energies[band], fermi_energies[mu]) :
            berry_multipole_sea_weight(parameters, energies[band], fermi_energies[mu])
        for a in 1:3, b in 1:3, c in 1:3, d in 1:3
            value =
                parameters.integral_form == :fermi_surface ?
                berry_quadrupole_surface_estimator(
                    energy_gradient[band, c],
                    energy_gradient[band, d],
                    dipole[band, a, b, c],
                    dipole[band, a, b, d],
                ) : quadrupole[band, a, b, c, d]
            output[mu, a, b, c, d] += weight * value
        end
    end
    all(isfinite, output) || throw(ArgumentError("nonfinite BCQ moment integrand"))
    return output
end
