const FERMI_ENERGY_AXIS_DOMAIN = "wanniernlqg.fermi-energy-axis/2.0"

"""Validate and defensively copy the canonical chemical-potential axis in eV."""
function validate_fermi_energies(values::Vector{Float64})
    isempty(values) && throw(ArgumentError("fermi_energies must not be empty."))
    all(isfinite, values) ||
        throw(ArgumentError("fermi_energies must contain only finite Float64 values (eV)."))
    all(index -> values[index] < values[index + 1], 1:(length(values) - 1)) ||
        throw(ArgumentError("fermi_energies must be strictly increasing without duplicates."))
    return copy(values)
end

"""Describe the complete validated μ axis by its ordered IEEE-754 values in eV.

This is an explicit physical definition, not a digest or authentication claim.
"""
function fermi_energy_axis_definition(values::Vector{Float64})
    axis = validate_fermi_energies(values)
    entries = [lowercase(string(reinterpret(UInt64, value); base = 16, pad = 16)) for value in axis]
    return FERMI_ENERGY_AXIS_DOMAIN * ":eV:" * string(length(axis)) * ":" * join(entries, ',')
end
