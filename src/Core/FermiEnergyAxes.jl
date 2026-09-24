const FERMI_ENERGY_AXIS_DOMAIN = "wanniernlqg.fermi-energy-axis/1.0"

"""Validate and defensively copy the canonical chemical-potential axis in eV."""
function validate_fermi_energies(values::Vector{Float64})
    isempty(values) && throw(ArgumentError("fermi_energies must not be empty."))
    all(isfinite, values) ||
        throw(ArgumentError("fermi_energies must contain only finite Float64 values (eV)."))
    all(index -> values[index] < values[index + 1], 1:(length(values) - 1)) ||
        throw(ArgumentError("fermi_energies must be strictly increasing without duplicates."))
    return copy(values)
end

"""Hash a validated μ axis using its domain, length, and ordered IEEE-754 bit patterns."""
function fermi_energy_axis_sha256(values::Vector{Float64})
    axis = validate_fermi_energies(values)
    stream = IOBuffer()
    write(stream, FERMI_ENERGY_AXIS_DOMAIN, '\0', string(length(axis)), '\0')
    for value in axis
        write(stream, lowercase(string(reinterpret(UInt64, value); base = 16, pad = 16)), '\n')
    end
    return bytes2hex(SHA.sha256(take!(stream)))
end
