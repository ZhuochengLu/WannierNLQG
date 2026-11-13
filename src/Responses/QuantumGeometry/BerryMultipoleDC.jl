"""Thermodynamic parameters for the BCD/BCQ DC Hall moments.

FS width, temperature and physical relaxation time are independent. This value
contains no integration region, backend, eigenframe, occupation array or IO.
"""
struct BerryMultipoleDCParameters
    integral_form::Symbol
    relaxation_time_fs::Float64
    temperature_k::Float64
    eta_fs_ev::Union{Nothing, Float64}

    function BerryMultipoleDCParameters(;
        integral_form::Symbol = :fermi_surface,
        relaxation_time_fs::Real,
        temperature_k::Real,
        fs_kind::Symbol = :gaussian,
        eta_fs_ev::Union{Nothing, Real} = nothing,
    )
        relaxation_time_fs isa Bool &&
            throw(ArgumentError("relaxation_time_fs must be a physical lifetime"))
        temperature_k isa Bool &&
            throw(ArgumentError("temperature_k must be a physical temperature"))
        integral_form in (:fermi_surface, :fermi_sea) ||
            throw(ArgumentError("integral_form must be fermi_surface or fermi_sea"))
        isfinite(relaxation_time_fs) && relaxation_time_fs > 0 ||
            throw(ArgumentError("relaxation_time_fs must be finite and positive"))
        isfinite(temperature_k) && temperature_k >= 0 ||
            throw(ArgumentError("temperature_k must be finite and nonnegative"))
        tau = Float64(relaxation_time_fs)
        temperature = Float64(temperature_k)
        isfinite(tau) &&
        tau > 0 &&
        isfinite(temperature) &&
        (temperature_k == 0 || temperature > 0) || throw(
            ArgumentError("lifetime/temperature is not representable by the numerical backend"),
        )
        fs_kind == :gaussian || throw(ArgumentError("BCD/BCQ FS supports gaussian only"))
        if integral_form == :fermi_surface && temperature_k == 0
            eta_fs_ev !== nothing && isfinite(eta_fs_ev) && eta_fs_ev > 0 || throw(
                ArgumentError(
                    "zero-temperature Fermi surface requires explicit positive eta_fs_ev",
                ),
            )
        elseif eta_fs_ev !== nothing
            throw(ArgumentError("eta_fs_ev is applicable only to zero-temperature Fermi surface"))
        end
        width = eta_fs_ev === nothing ? nothing : Float64(eta_fs_ev)
        width === nothing ||
            (isfinite(width) && width > 0) ||
            throw(ArgumentError("eta_fs_ev is not representable by the numerical backend"))
        return new(integral_form, tau, temperature, width)
    end
end

"""Per-state Fermi-sea multiplier, with the existing strict T=0 occupation."""
function berry_multipole_sea_weight(parameters::BerryMultipoleDCParameters, energy::Real, mu::Real)
    parameters.integral_form == :fermi_sea || throw(ArgumentError("Fermi-sea parameters required"))
    isfinite(energy) && isfinite(mu) ||
        throw(ArgumentError("nonfinite energy or chemical potential"))
    return response_occupation(energy, mu, parameters.temperature_k)
end

"""Minus f'(E), in eV^-1; no legacy cutoff, value floor or zero-T suppression."""
function berry_multipole_surface_weight(
    parameters::BerryMultipoleDCParameters,
    energy::Real,
    mu::Real,
)
    parameters.integral_form == :fermi_surface ||
        throw(ArgumentError("Fermi-surface parameters required"))
    isfinite(energy) && isfinite(mu) ||
        throw(ArgumentError("nonfinite energy or chemical potential"))
    eta = parameters.eta_fs_ev === nothing ? 0.0 : parameters.eta_fs_ev
    return response_fermi_derivative(energy, mu, parameters.temperature_k, :gaussian, eta)
end

"""Once-integrated-by-parts BCQ estimator, before minus f' and BZ measure.

Energy gradients are eV Angstrom and local BCD is Angstrom^3. Both terms
are retained (including coincident axes); no second-IBP expression is substituted.
"""
@inline berry_quadrupole_surface_estimator(
    energy_gradient_c::Real,
    energy_gradient_d::Real,
    dipole_c::Real,
    dipole_d::Real,
) = 0.5 * (energy_gradient_c * dipole_d + energy_gradient_d * dipole_c)

"""Convert integrated D[ab;c] to sigma[bc;a] in SI, with e positive.

Input moments use Angstrom^(3-d), including the actual d-dimensional (2pi)^-d
integration measure. Output is A/V^2 for d=3 or A m/V^2 for d=2. The plus sign
follows the approved Boltzmann recurrence and the negative linear-Hall anchor.
"""
function berry_dipole_dc_conductivity(
    moment::AbstractArray{<:Real, 3},
    parameters::BerryMultipoleDCParameters;
    spatial_dimension::Integer,
)
    spatial_dimension in (2, 3) || throw(ArgumentError("BCD DC supports sheet 2D or bulk 3D"))
    size(moment) == (3, 3, 3) ||
        throw(DimensionMismatch("BCD moment must have Cartesian axes (a,b,c)"))
    all(isfinite, moment) || throw(ArgumentError("nonfinite BCD moment"))
    tau = parameters.relaxation_time_fs * 1e-15
    prefactor =
        RESPONSE_CHARGE_C^3 * tau / (2 * RESPONSE_HBAR_JS^2) * (1e-10)^(3 - spatial_dimension)
    conductivity = zeros(Float64, 3, 3, 3)
    for a in 1:3, b in 1:3, c in 1:3
        conductivity[b, c, a] = prefactor * (moment[a, b, c] + moment[a, c, b])
    end
    all(isfinite, conductivity) || throw(ArgumentError("nonfinite BCD DC conductivity"))
    return conductivity
end

"""Convert integrated Q[ab;cd] to sigma[bcd;a] in SI.

Input moments use Angstrom^(4-d). Output is A m/V^3 for bulk 3D or A m^2/V^3
for sheet 2D. Field symmetrization is the explicit three-term average; tau^2
is a physical DC lifetime, unrelated to spectral or Fermi-surface broadening.
"""
function berry_quadrupole_dc_conductivity(
    moment::AbstractArray{<:Real, 4},
    parameters::BerryMultipoleDCParameters;
    spatial_dimension::Integer,
)
    spatial_dimension in (2, 3) || throw(ArgumentError("BCQ DC supports sheet 2D or bulk 3D"))
    size(moment) == (3, 3, 3, 3) ||
        throw(DimensionMismatch("BCQ moment must have Cartesian axes (a,b,c,d)"))
    all(isfinite, moment) || throw(ArgumentError("nonfinite BCQ moment"))
    tau = parameters.relaxation_time_fs * 1e-15
    prefactor =
        -RESPONSE_CHARGE_C^4 * tau^2 / (3 * RESPONSE_HBAR_JS^3) * (1e-10)^(4 - spatial_dimension)
    conductivity = zeros(Float64, 3, 3, 3, 3)
    for a in 1:3, b in 1:3, c in 1:3, d in 1:3
        conductivity[b, c, d, a] =
            prefactor * (moment[a, b, c, d] + moment[a, c, b, d] + moment[a, d, b, c])
    end
    all(isfinite, conductivity) || throw(ArgumentError("nonfinite BCQ DC conductivity"))
    return conductivity
end
