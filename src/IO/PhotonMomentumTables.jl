"""Read an explicit energy/momentum-magnitude CSV within one observed file lifetime.

Columns are energy_ev (eV) and q_A_inverse (inverse Angstrom). Nodes must be
finite, nonnegative and strictly increasing in energy. No expression evaluation,
extrapolation, sorting, duplicate removal or scientific qualification is performed.
"""
function read_photon_momentum_table(path::AbstractString)
    source = read_scientific_source(path)
    lines = split(chomp(String(source.bytes)), '\n')
    !isempty(lines) && strip(lines[1]) == "energy_ev,q_A_inverse" ||
        throw(ArgumentError("photon momentum CSV requires header energy_ev,q_A_inverse."))
    energies = Float64[]
    magnitudes = Float64[]
    for (index, line) in enumerate(lines[2:end])
        columns = split(strip(line), ',')
        length(columns) == 2 || throw(ArgumentError("CSV row $(index + 1) requires two columns."))
        values = tryparse.(Float64, strip.(columns))
        all(x -> x !== nothing && isfinite(x) && x >= 0, values) ||
            throw(ArgumentError("CSV row $(index + 1) requires finite nonnegative real values."))
        energy, magnitude = Float64.(values)
        isempty(energies) ||
            energy > last(energies) ||
            throw(ArgumentError("CSV energies must be strictly increasing without duplicates."))
        push!(energies, energy)
        push!(magnitudes, magnitude)
    end
    isempty(energies) && throw(ArgumentError("photon momentum CSV requires at least one data row."))
    return (;
        energies,
        magnitudes,
        path = source.state.path,
        identity = scientific_file_identity(source.state),
    )
end
