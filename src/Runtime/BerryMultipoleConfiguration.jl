"""Resolved BCD/BCQ DC options; physical lifetime and numerical widths stay separate."""
struct BerryMultipoleSettings{N}
    parameters::Responses.BerryMultipoleDCParameters
    components::Tuple{Vararg{NTuple{N, Int}}}
    local_derivative_order::Int
end

const BERRY_MULTIPOLE_QUANTITIES =
    (:berry_curvature_dipole_conductivity, :berry_curvature_quadrupole_conductivity)

"""Local geometry consumed by the selected integral expression, without substituting IBP forms."""
function berry_multipole_derivative_order(quantity::Symbol, integral_form::Symbol)
    quantity in BERRY_MULTIPOLE_QUANTITIES ||
        throw(ArgumentError("not a BCD/BCQ conductivity task"))
    integral_form in (:fermi_surface, :fermi_sea) ||
        throw(ArgumentError("unknown BCD/BCQ integral_form"))
    return quantity == :berry_curvature_dipole_conductivity ?
           (integral_form == :fermi_surface ? 0 : 1) : (integral_form == :fermi_surface ? 1 : 2)
end
