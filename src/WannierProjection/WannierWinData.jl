"""
Structure and projection data read from one Wannier90 `.win` file.

The `.win` file is the sole structural authority for symmetrization. K-point
rows are intentionally not stored: only `mp_grid` is retained for mesh
screening, and no SCF mesh is parsed or inferred.
"""
struct WannierWinData
    source_path::String
    num_wannier::Int
    num_bands::Union{Nothing, Int}
    spinors::Bool
    mp_grid::Union{Nothing, NTuple{3, Int}}
    lattice::Matrix{Float64}
    species::Vector{String}
    positions_fractional::Matrix{Float64}
    projection_lines::Vector{String}
end

# Parse one finite floating-point token with Fortran D exponents.
function parse_wannier_float(value::AbstractString, field::AbstractString)
    parsed = parse(Float64, replace(strip(value), 'D' => 'E', 'd' => 'e'))
    isfinite(parsed) || throw(ArgumentError("$(field) contains a non-finite value"))
    return parsed
end

# Return the unit conversion for a Wannier90 Cartesian block.
function _wannier_length_factor(unit::AbstractString)
    normalized = lowercase(strip(unit))
    normalized in ("", "ang", "angstrom", "angstroms", "a") && return 1.0
    normalized in ("bohr", "bohrs", "au", "a.u.") && return BOHR_TO_ANGSTROM
    throw(ArgumentError("unsupported Wannier90 length unit $(repr(unit))"))
end

# Collect named begin/end blocks and scalar parameters from a WIN file.
function _split_wannier_input(lines::Vector{String})
    parameters = Dict{String, String}()
    blocks = Dict{String, Vector{String}}()
    index = 1
    while index <= length(lines)
        line = strip_input_comment(lines[index])
        if isempty(line)
            index += 1
            continue
        end
        begin_match = match(r"(?i)^begin\s+([A-Za-z0-9_]+)\s*$", line)
        if begin_match !== nothing
            name = lowercase(begin_match.captures[1])
            haskey(blocks, name) && throw(ArgumentError("duplicate begin $(name) block"))
            contents = String[]
            index += 1
            found_end = false
            while index <= length(lines)
                block_line = strip_input_comment(lines[index])
                if occursin(Regex("(?i)^end\\s+$(name)\\s*\$"), block_line)
                    found_end = true
                    break
                end
                isempty(block_line) || push!(contents, block_line)
                index += 1
            end
            found_end || throw(ArgumentError("unterminated begin $(name) block"))
            blocks[name] = contents
        elseif occursin('=', line)
            key, value = split(line, '='; limit = 2)
            normalized_key = lowercase(strip(key))
            haskey(parameters, normalized_key) &&
                throw(ArgumentError("duplicate Wannier90 parameter $(normalized_key)"))
            parameters[normalized_key] = strip(value)
        end
        index += 1
    end
    return parameters, blocks
end

# Parse the row-lattice Cartesian unit-cell block in Angstrom.
function _parse_wannier_lattice(blocks::Dict{String, Vector{String}})
    haskey(blocks, "unit_cell_cart") ||
        throw(ArgumentError("WIN file must contain begin unit_cell_cart"))
    lines = blocks["unit_cell_cart"]
    factor = 1.0
    if !isempty(lines) && length(split(lines[1])) == 1
        token = lowercase(strip(lines[1]))
        if token in ("ang", "angstrom", "angstroms", "a", "bohr", "bohrs", "au", "a.u.")
            factor = _wannier_length_factor(token)
            lines = lines[2:end]
        end
    end
    length(lines) == 3 ||
        throw(ArgumentError("unit_cell_cart must contain exactly three lattice vectors"))
    lattice = zeros(Float64, 3, 3)
    for row in 1:3
        tokens = split(lines[row])
        length(tokens) == 3 ||
            throw(ArgumentError("unit_cell_cart row $(row) must contain three values"))
        lattice[row, :] .= factor .* parse_wannier_float.(tokens, "unit_cell_cart")
    end
    abs(det(lattice)) > 1.0e-12 || throw(ArgumentError("WIN lattice is singular"))
    return lattice
end

# Parse atoms_frac or atoms_cart using the WIN lattice as authority.
function _parse_wannier_atoms(blocks::Dict{String, Vector{String}}, lattice::Matrix{Float64})
    has_fractional = haskey(blocks, "atoms_frac")
    has_cartesian = haskey(blocks, "atoms_cart")
    has_fractional == has_cartesian &&
        throw(ArgumentError("WIN file must contain exactly one of atoms_frac or atoms_cart"))
    block_name = has_fractional ? "atoms_frac" : "atoms_cart"
    lines = copy(blocks[block_name])
    factor = 1.0
    if has_cartesian && !isempty(lines) && length(split(lines[1])) == 1
        factor = _wannier_length_factor(lines[1])
        lines = lines[2:end]
    end
    isempty(lines) && throw(ArgumentError("$(block_name) must contain at least one atom"))
    species = String[]
    coordinates = zeros(Float64, 3, length(lines))
    for (atom, line) in enumerate(lines)
        tokens = split(line)
        length(tokens) >= 4 ||
            throw(ArgumentError("$(block_name) atom $(atom) must contain a label and coordinates"))
        push!(species, String(tokens[1]))
        coordinates[:, atom] .= parse_wannier_float.(tokens[2:4], block_name)
    end
    positions = if has_fractional
        coordinates
    else
        (factor .* coordinates') * inv(lattice) |> transpose |> Matrix{Float64}
    end
    return species, mod.(positions, 1.0)
end

"""
Read structure, projection, spinor, and `mp_grid` data from a Wannier90 input.

The parser deliberately ignores `begin kpoints` contents and has no SCF-input
argument. It requires the structure and projection fields needed to construct a
closed Wannier representation and fails on ambiguous duplicate parameters.
"""
function read_wannier_win(filename::AbstractString)
    isfile(filename) || throw(ArgumentError("WIN file does not exist: $(filename)"))
    parameters, blocks = _split_wannier_input(readlines(filename))
    haskey(parameters, "num_wann") || throw(ArgumentError("WIN file must define num_wann"))
    num_wannier = parse(Int, parameters["num_wann"])
    num_wannier > 0 || throw(ArgumentError("num_wann must be positive"))
    num_bands = haskey(parameters, "num_bands") ? parse(Int, parameters["num_bands"]) : nothing
    num_bands === nothing ||
        num_bands >= num_wannier ||
        throw(ArgumentError("num_bands must not be smaller than num_wann"))
    spinors =
        haskey(parameters, "spinors") ?
        parse_input_boolean(parameters["spinors"], "spinors"; allow_yes_no = true) : false
    mp_grid = if haskey(parameters, "mp_grid")
        tokens = split(replace(parameters["mp_grid"], ',' => ' '))
        length(tokens) == 3 || throw(ArgumentError("mp_grid must contain three integers"))
        values = Tuple(parse.(Int, tokens))
        all(>(0), values) || throw(ArgumentError("mp_grid entries must be positive"))
        values
    else
        nothing
    end
    lattice = _parse_wannier_lattice(blocks)
    species, positions = _parse_wannier_atoms(blocks, lattice)
    projection_lines = get(blocks, "projections", String[])
    isempty(projection_lines) &&
        throw(ArgumentError("WIN file must contain at least one projection line"))
    return WannierWinData(
        abspath(filename),
        num_wannier,
        num_bands,
        spinors,
        mp_grid,
        lattice,
        species,
        positions,
        projection_lines,
    )
end

"""Construct the authoritative nonmagnetic structure stored in a WIN input."""
function crystal_structure(input::WannierWinData; magnetic_moments_cartesian = nothing)
    return CrystalStructure(
        input.lattice,
        input.species,
        input.positions_fractional;
        magnetic_moments_cartesian = magnetic_moments_cartesian,
    )
end
