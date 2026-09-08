const QE_CARD_NAMES = Set([
    "ATOMIC_SPECIES",
    "ATOMIC_POSITIONS",
    "ATOMIC_FORCES",
    "K_POINTS",
    "ADDITIONAL_K_POINTS",
    "CELL_PARAMETERS",
    "CONSTRAINTS",
    "OCCUPATIONS",
    "HUBBARD",
    "SOLVENTS",
    "CLIMBING_IMAGES",
])

# Normalize a three-vector and reject an implicit or singular axis.
function _normalized_magnetic_axis(value, field::AbstractString)
    axis = Vector{Float64}(value)
    length(axis) == 3 || throw(ArgumentError("$(field) must contain three values"))
    norm_value = norm(axis)
    isfinite(norm_value) && norm_value > 0.0 ||
        throw(ArgumentError("$(field) must have nonzero finite length"))
    return axis ./ norm_value
end

# Parse indexed values such as starting_magnetization(2)=0.5 from QE text.
function _qe_indexed_values(text::String, field::AbstractString)
    values = Dict{Int, Float64}()
    expression = Regex("(?i)\\b$(field)\\s*\\(\\s*(\\d+)\\s*\\)\\s*=\\s*" * "([-+0-9.eEdD]+)")
    for matched in eachmatch(expression, text)
        index = parse(Int, matched.captures[1])
        values[index] = parse_wannier_float(matched.captures[2], field)
    end
    return values
end

# Read a scalar QE namelist field without interpreting K_POINTS or other cards.
function _qe_scalar_value(text::String, field::AbstractString)
    matched = match(Regex("(?i)\\b$(field)\\s*=\\s*([^,\\n/]+)"), text)
    return matched === nothing ? nothing : strip(matched.captures[1])
end

# Locate a QE card and return its nonempty payload lines up to the next card or namelist.
function _qe_card_lines(lines::Vector{String}, card::AbstractString)
    start =
        findfirst(line -> startswith(uppercase(strip_input_comment(line)), uppercase(card)), lines)
    start === nothing && return String[], ""
    header = strip_input_comment(lines[start])
    payload = String[]
    for index in (start + 1):length(lines)
        line = strip_input_comment(lines[index])
        isempty(line) && continue
        first_token = uppercase(first(split(line)))
        if startswith(line, "&") || line == "/" || first_token in QE_CARD_NAMES
            break
        end
        push!(payload, line)
    end
    return payload, header
end

# Match source atoms to WIN atoms by species and periodic position.
function _match_magnetic_atoms(
    source_species::Vector{String},
    source_positions::Matrix{Float64},
    input::WannierWinData;
    tolerance::Float64,
)
    length(source_species) == length(input.species) ||
        throw(ArgumentError("magnetic input atom count does not match WIN"))
    permutation = zeros(Int, length(input.species))
    used = falses(length(source_species))
    for target in eachindex(input.species)
        matches = Int[]
        for source in eachindex(source_species)
            used[source] && continue
            source_species[source] == input.species[target] || continue
            delta = source_positions[:, source] .- input.positions_fractional[:, target]
            residual = delta .- round.(delta)
            maximum(abs, residual) <= tolerance && push!(matches, source)
        end
        length(matches) == 1 ||
            throw(ArgumentError("magnetic input does not uniquely map WIN atom $(target)"))
        permutation[target] = only(matches)
        used[only(matches)] = true
    end
    return permutation
end

"""
Read Cartesian atomic magnetic moments from a QE input without reading `K_POINTS`.

The WIN structure remains authoritative. QE `ATOMIC_POSITIONS` is used only to
establish a unique species/position mapping. Collinear scalar moments require an
explicit `collinear_axis_cartesian`; noncollinear moments use QE `angle1/angle2` in
degrees. No self-consistent k mesh is parsed, generated, or returned.
"""
function read_qe_magnetic_moments(
    filename::AbstractString,
    input::WannierWinData;
    collinear_axis_cartesian = nothing,
    tolerance::Float64 = 1.0e-7,
)
    isfile(filename) || throw(ArgumentError("QE input does not exist: $(filename)"))
    lines = readlines(filename)
    text = join(strip_input_comment.(lines), "\n")
    species_lines, _ = _qe_card_lines(lines, "ATOMIC_SPECIES")
    atom_lines, atom_header = _qe_card_lines(lines, "ATOMIC_POSITIONS")
    isempty(species_lines) && throw(ArgumentError("QE input must contain ATOMIC_SPECIES"))
    isempty(atom_lines) && throw(ArgumentError("QE input must contain ATOMIC_POSITIONS"))
    type_labels = [String(first(split(line))) for line in species_lines]
    atom_species = String[]
    coordinates = zeros(Float64, 3, length(atom_lines))
    for (atom, line) in enumerate(atom_lines)
        tokens = split(line)
        length(tokens) >= 4 || throw(ArgumentError("malformed QE ATOMIC_POSITIONS row"))
        push!(atom_species, String(tokens[1]))
        coordinates[:, atom] .= parse_wannier_float.(tokens[2:4], "ATOMIC_POSITIONS")
    end
    option_match = match(r"\{([^}]+)\}", atom_header)
    option = option_match === nothing ? "alat" : lowercase(strip(option_match.captures[1]))
    positions_fractional = if option in ("crystal", "crystal_sg")
        mod.(coordinates, 1.0)
    elseif option in ("angstrom", "ang")
        mod.(transpose(coordinates) * inv(input.lattice) |> transpose, 1.0)
    elseif option == "bohr"
        mod.(transpose(BOHR_TO_ANGSTROM .* coordinates) * inv(input.lattice) |> transpose, 1.0)
    else
        lattice_a = _qe_scalar_value(text, "A")
        lattice_a === nothing &&
            throw(ArgumentError("QE ATOMIC_POSITIONS alat requires an explicit A value"))
        scale = parse_wannier_float(lattice_a, "A")
        mod.(transpose(scale .* coordinates) * inv(input.lattice) |> transpose, 1.0)
    end
    permutation =
        _match_magnetic_atoms(atom_species, positions_fractional, input; tolerance = tolerance)
    magnitudes = _qe_indexed_values(text, "starting_magnetization")
    polar_angles = _qe_indexed_values(text, "angle1")
    azimuth_angles = _qe_indexed_values(text, "angle2")
    noncollinear_value = _qe_scalar_value(text, "noncolin")
    noncollinear =
        noncollinear_value === nothing ? false : parse_input_boolean(noncollinear_value, "noncolin")
    moments_source = zeros(Float64, 3, length(atom_species))
    for atom in eachindex(atom_species)
        type_index = findfirst(==(atom_species[atom]), type_labels)
        type_index === nothing && throw(
            ArgumentError("QE atom label $(atom_species[atom]) is absent from ATOMIC_SPECIES"),
        )
        magnitude = get(magnitudes, type_index, 0.0)
        if noncollinear
            polar = deg2rad(get(polar_angles, type_index, 0.0))
            azimuth = deg2rad(get(azimuth_angles, type_index, 0.0))
            moments_source[:, atom] .=
                magnitude .* [sin(polar) * cos(azimuth), sin(polar) * sin(azimuth), cos(polar)]
        else
            collinear_axis_cartesian === nothing &&
                throw(ArgumentError("QE collinear moments require collinear_axis_cartesian"))
            moments_source[:, atom] .=
                magnitude .*
                _normalized_magnetic_axis(collinear_axis_cartesian, "collinear_axis_cartesian")
        end
    end
    return moments_source[:, permutation]
end

# Parse case-insensitive active assignments from a VASP INCAR file.
function _read_vasp_incar_assignments(filename::AbstractString)
    isfile(filename) || throw(ArgumentError("VASP INCAR does not exist: $(filename)"))
    fields = Dict{String, String}()
    for line in eachline(filename)
        clean = strip_input_comment(line)
        isempty(clean) && continue
        for assignment in split(clean, ';')
            occursin('=', assignment) || continue
            key, value = split(assignment, '='; limit = 2)
            normalized_key = uppercase(strip(key))
            isempty(normalized_key) && continue
            fields[normalized_key] = strip(value)
        end
    end
    return fields
end

# Expand VASP repeat notation such as `4*0.5` into scalar values.
function _expand_vasp_values(value::AbstractString, field::AbstractString = "MAGMOM")
    result = Float64[]
    for token in split(replace(value, ',' => ' '))
        if occursin('*', token)
            count_text, scalar_text = split(token, '*'; limit = 2)
            isempty(strip(count_text)) && throw(ArgumentError("$(field) repeat count is missing"))
            isempty(strip(scalar_text)) &&
                throw(ArgumentError("$(field) repeated value is missing"))
            count = try
                parse(Int, strip(count_text))
            catch
                throw(ArgumentError("$(field) repeat count must be an integer"))
            end
            count > 0 || throw(ArgumentError("$(field) repeat count must be positive"))
            append!(result, fill(parse_wannier_float(scalar_text, field), count))
        else
            push!(result, parse_wannier_float(token, field))
        end
    end
    isempty(result) && throw(ArgumentError("$(field) must contain at least one numeric value"))
    return result
end

# Construct the VASP spin-coordinate row basis determined by SAXIS.
function _vasp_spin_basis(saxis)
    spin_axis = _normalized_magnetic_axis(saxis, "SAXIS")
    theta = acos(clamp(spin_axis[3], -1.0, 1.0))
    phi = atan(spin_axis[2], spin_axis[1])
    first_axis = [cos(theta) * cos(phi), cos(theta) * sin(phi), -sin(theta)]
    second_axis = [-sin(phi), cos(phi), 0.0]
    return hcat(first_axis, second_axis, spin_axis)
end

"""
Parse VASP INCAR magnetic metadata for a structure with a fixed atom count.

The returned `moments_cartesian` are the expanded initial `MAGMOM` values in
POSCAR atom order. They are not self-consistent local moments. For
noncollinear/SOC input the VASP spin-coordinate triples are rotated into the
fixed Cartesian basis defined by `SAXIS`; collinear scalars require an explicit
Cartesian magnetization axis.
"""
function _read_vasp_incar_magnetic_state(
    filename::AbstractString,
    atom_count::Integer;
    collinear_axis_cartesian = nothing,
)
    atom_count > 0 || throw(ArgumentError("POSCAR atom count must be positive"))
    fields = _read_vasp_incar_assignments(filename)
    haskey(fields, "MAGMOM") || throw(ArgumentError("VASP INCAR must define MAGMOM"))
    noncollinear = parse_input_boolean(get(fields, "LNONCOLLINEAR", ".FALSE."), "LNONCOLLINEAR")
    spin_orbit = parse_input_boolean(get(fields, "LSORBIT", ".FALSE."), "LSORBIT")
    values = _expand_vasp_values(fields["MAGMOM"], "MAGMOM")
    saxis_input = if haskey(fields, "SAXIS")
        _expand_vasp_values(fields["SAXIS"], "SAXIS")
    else
        [0.0, 0.0, 1.0]
    end
    length(saxis_input) == 3 || throw(ArgumentError("SAXIS must contain three values"))
    saxis_normalized = _normalized_magnetic_axis(saxis_input, "SAXIS")
    axis = nothing
    moments = if noncollinear || spin_orbit
        length(values) == 3atom_count || throw(
            ArgumentError(
                "noncollinear or SOC VASP MAGMOM must contain 3*num_atoms values; " *
                "expanded $(length(values)) values for $(atom_count) POSCAR atoms",
            ),
        )
        _vasp_spin_basis(saxis_input) * reshape(values, 3, atom_count)
    else
        length(values) == atom_count || throw(
            ArgumentError(
                "collinear VASP MAGMOM count does not match POSCAR atoms; " *
                "expanded $(length(values)) values for $(atom_count) atoms",
            ),
        )
        collinear_axis_cartesian === nothing &&
            throw(ArgumentError("VASP collinear moments require collinear_axis_cartesian"))
        axis = _normalized_magnetic_axis(collinear_axis_cartesian, "collinear_axis_cartesian")
        axis * transpose(values)
    end
    all(isfinite, moments) || throw(ArgumentError("expanded VASP MAGMOM is non-finite"))
    return (
        moments_cartesian = moments,
        expanded_magmoms = values,
        lnoncollinear = noncollinear,
        lsorbit = spin_orbit,
        saxis_input = Float64.(saxis_input),
        saxis_normalized = saxis_normalized,
        collinear_axis_cartesian = axis,
        interpretation = "initial_magmoms_not_scf_local_moments",
    )
end

# Require two independently supplied Cartesian moment matrices to agree.
function _validate_vasp_cartesian_moment_agreement(
    explicit,
    incar::AbstractMatrix{<:Real};
    tolerance::Float64 = 1.0e-8,
)
    explicit_moments = Matrix{Float64}(explicit)
    size(explicit_moments) == size(incar) || throw(
        ArgumentError(
            "MAGNETIC_MOMENT_SOURCE_CONFLICT: explicit magnetic_moments_cartesian " *
            "shape disagrees with POSCAR/INCAR MAGMOM",
        ),
    )
    all(isfinite, explicit_moments) ||
        throw(ArgumentError("magnetic_moments_cartesian contains non-finite values"))
    isapprox(explicit_moments, incar; atol = tolerance, rtol = tolerance) || throw(
        ArgumentError(
            "MAGNETIC_MOMENT_SOURCE_CONFLICT: explicit magnetic_moments_cartesian " *
            "disagrees with INCAR MAGMOM after Cartesian conversion",
        ),
    )
    return explicit_moments
end

"""
Read VASP `MAGMOM` values in WIN atom order and return Cartesian moments.

`LNONCOLLINEAR` or `LSORBIT` selects triples in the SAXIS spin basis; scalar
collinear input requires `collinear_axis_cartesian`. INCAR contains no coordinates,
so the atom count and the explicitly documented WIN ordering are the complete
mapping contract.
"""
function read_vasp_magnetic_moments(
    filename::AbstractString,
    input::WannierWinData;
    collinear_axis_cartesian = nothing,
)
    return _read_vasp_incar_magnetic_state(
        filename,
        length(input.species);
        collinear_axis_cartesian,
    ).moments_cartesian
end

"""Validate an explicit `3 x num_atoms` Cartesian moment matrix."""
function read_config_magnetic_moments(value, input::WannierWinData)
    moments = Matrix{Float64}(value)
    size(moments) == (3, length(input.species)) ||
        throw(ArgumentError("moments_cartesian must have size (3, num_atoms)"))
    all(isfinite, moments) || throw(ArgumentError("moments_cartesian contains non-finite values"))
    return moments
end
