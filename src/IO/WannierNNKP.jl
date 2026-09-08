"""One ordered Wannier90 trial projection exactly as serialized in `.nnkp`."""
struct WannierNNKPProjection
    center_fractional::NTuple{3, Float64}
    angular_code::Int
    angular_index::Int
    radial_index::Int
    z_axis_cartesian::NTuple{3, Float64}
    x_axis_cartesian::NTuple{3, Float64}
    radial_scale::Float64
    spin_eigenvalue::Union{Nothing, Int}
    spin_axis_cartesian::Union{Nothing, NTuple{3, Float64}}
end

"""
    WannierNNKP

Strict, immutable view of the Wannier90 preprocessing contract. The `.nnkp`
file is authoritative for k-point order, neighbour topology, reciprocal
shifts, excluded bands, ordered trial projections, and (when present) spin
quantization axes. Lattice vectors use row-vector storage.
"""
struct WannierNNKP
    real_lattice::Matrix{Float64}
    reciprocal_lattice::Matrix{Float64}
    kpoints_fractional::Matrix{Float64}
    neighbors::Matrix{Int}
    reciprocal_shifts::Array{Int, 3}
    excluded_bands::Vector{Int}
    projections::Vector{WannierNNKPProjection}
    spinor::Bool
    source_sha256::String

    function WannierNNKP(
        real_lattice,
        reciprocal_lattice,
        kpoints_fractional,
        neighbors,
        reciprocal_shifts,
        excluded_bands,
        projections,
        spinor,
        source_sha256,
    )
        real = Matrix{Float64}(real_lattice)
        reciprocal = Matrix{Float64}(reciprocal_lattice)
        kpoints = Matrix{Float64}(kpoints_fractional)
        neighbour_values = Matrix{Int}(neighbors)
        shifts = Array{Int, 3}(reciprocal_shifts)
        excluded = sort!(unique(Int.(excluded_bands)))
        projection_values = WannierNNKPProjection[projections...]
        size(real) == (3, 3) || throw(ArgumentError("NNKP real lattice must be 3 x 3"))
        size(reciprocal) == (3, 3) || throw(ArgumentError("NNKP reciprocal lattice must be 3 x 3"))
        size(kpoints, 2) == 3 && size(kpoints, 1) > 0 ||
            throw(ArgumentError("NNKP k-points must have size (num_kpoints, 3)"))
        size(neighbour_values, 2) == size(kpoints, 1) && size(neighbour_values, 1) > 0 ||
            throw(ArgumentError("NNKP neighbour topology dimensions disagree"))
        size(shifts) == (3, size(neighbour_values, 1), size(neighbour_values, 2)) ||
            throw(ArgumentError("NNKP reciprocal-shift dimensions disagree"))
        all(index -> 1 <= index <= size(kpoints, 1), neighbour_values) ||
            throw(ArgumentError("NNKP contains an out-of-range neighbour index"))
        all(>(0), excluded) || throw(ArgumentError("NNKP excluded bands must be positive"))
        isempty(projection_values) && throw(ArgumentError("NNKP contains no trial projections"))
        digest = lowercase(String(source_sha256))
        length(digest) == 64 &&
        all(character -> isdigit(character) || character in 'a':'f', digest) ||
            throw(ArgumentError("NNKP source SHA-256 is malformed"))
        all(isfinite, real) && all(isfinite, reciprocal) && all(isfinite, kpoints) ||
            throw(ArgumentError("NNKP contains non-finite lattice or k-point values"))
        isapprox(real * transpose(reciprocal), 2.0pi * I; atol = 2.0e-6, rtol = 0.0) ||
            throw(ArgumentError("NNKP real and reciprocal lattices are inconsistent"))
        Bool(spinor) == all(item -> item.spin_eigenvalue !== nothing, projection_values) ||
            throw(ArgumentError("NNKP spinor flag disagrees with projection records"))
        return new(
            real,
            reciprocal,
            kpoints,
            neighbour_values,
            shifts,
            excluded,
            projection_values,
            Bool(spinor),
            digest,
        )
    end
end

# Return unique, case-insensitive begin/end sections without interpreting payload rows.
function _nnkp_sections(lines::Vector{String})
    sections = Dict{String, Vector{String}}()
    active = nothing
    rows = String[]
    for (line_number, line) in enumerate(lines)
        stripped = strip(line)
        tokens = split(lowercase(stripped))
        if length(tokens) == 2 && first(tokens) == "begin"
            active === nothing ||
                throw(ArgumentError("NNKP begins a nested section at line $(line_number)"))
            name = tokens[2]
            haskey(sections, name) &&
                throw(ArgumentError("NNKP section $(name) appears more than once"))
            active = name
            empty!(rows)
        elseif length(tokens) == 2 && first(tokens) == "end"
            active === nothing &&
                throw(ArgumentError("NNKP ends an inactive section at line $(line_number)"))
            tokens[2] == active || throw(
                ArgumentError(
                    "NNKP section $(active) is closed as $(tokens[2]) at line $(line_number)",
                ),
            )
            sections[something(active)] = copy(rows)
            active = nothing
            empty!(rows)
        elseif active !== nothing && !isempty(stripped)
            push!(rows, stripped)
        end
    end
    active === nothing || throw(ArgumentError("NNKP section $(active) is not closed"))
    return sections
end

# Parse one exact-length floating-point row with Fortran exponent support.
function _nnkp_float_row(row::AbstractString, count::Int, label::AbstractString)
    tokens = split(strip(row))
    length(tokens) == count ||
        throw(ArgumentError("NNKP $(label) row has $(length(tokens)) values; expected $(count)"))
    values = parse.(Float64, replace.(tokens, 'D' => 'E', 'd' => 'e'))
    all(isfinite, values) || throw(ArgumentError("NNKP $(label) row contains NaN or Inf"))
    return values
end

# Parse one strict 3 x 3 row-vector lattice section.
function _nnkp_lattice(rows::Vector{String}, label::AbstractString)
    length(rows) == 3 || throw(ArgumentError("NNKP $(label) section must contain three rows"))
    return reduce(vcat, transpose(_nnkp_float_row(row, 3, label)) for row in rows)
end

# Validate and normalize one axis without changing its declared direction.
function _nnkp_axis(values, label::AbstractString)
    vector = Float64.(values)
    length(vector) == 3 && all(isfinite, vector) && norm(vector) > 1.0e-12 ||
        throw(ArgumentError("NNKP $(label) must be a finite nonzero three-vector"))
    return Tuple(vector ./ norm(vector))
end

# Return the number of angular rows associated with a Wannier90 angular code.
function _nnkp_angular_dimension(code::Int)
    code >= 0 && code <= 3 && return 2 * code + 1
    dimensions = Dict(-1 => 2, -2 => 3, -3 => 4, -4 => 5, -5 => 6)
    haskey(dimensions, code) ||
        throw(ArgumentError("NNKP projection angular code $(code) is unsupported"))
    return dimensions[code]
end

# Parse ordered scalar or spinor projection rows.
function _nnkp_projections(rows::Vector{String}, spinor::Bool)
    isempty(rows) && throw(ArgumentError("NNKP projection section is empty"))
    count = parse(Int, only(split(rows[1])))
    count > 0 || throw(ArgumentError("NNKP projection count must be positive"))
    stride = spinor ? 3 : 2
    length(rows) == 1 + stride * count ||
        throw(ArgumentError("NNKP projection section row count is inconsistent"))
    projections = WannierNNKPProjection[]
    for projection_index in 1:count
        offset = 2 + stride * (projection_index - 1)
        first_row = split(rows[offset])
        length(first_row) == 6 ||
            throw(ArgumentError("NNKP projection $(projection_index) header is malformed"))
        center = parse.(Float64, replace.(first_row[1:3], 'D' => 'E', 'd' => 'e'))
        angular_code, angular_index, radial_index = parse.(Int, first_row[4:6])
        1 <= angular_index <= _nnkp_angular_dimension(angular_code) || throw(
            ArgumentError("NNKP projection $(projection_index) angular index is out of range"),
        )
        radial_index in 1:3 ||
            throw(ArgumentError("NNKP projection radial index must be one, two, or three"))
        axes_row = _nnkp_float_row(rows[offset + 1], 7, "projection axes")
        z_axis = _nnkp_axis(axes_row[1:3], "projection z axis")
        x_axis = _nnkp_axis(axes_row[4:6], "projection x axis")
        abs(dot(z_axis, x_axis)) <= 1.0e-8 ||
            throw(ArgumentError("NNKP projection x and z axes are not orthogonal"))
        radial_scale = axes_row[7]
        radial_scale > 0.0 || throw(ArgumentError("NNKP radial scale must be positive"))
        spin_eigenvalue = nothing
        spin_axis = nothing
        if spinor
            spin_row = split(rows[offset + 2])
            length(spin_row) == 4 ||
                throw(ArgumentError("NNKP spinor projection $(projection_index) is malformed"))
            spin_eigenvalue = parse(Int, spin_row[1])
            spin_eigenvalue in (-1, 1) ||
                throw(ArgumentError("NNKP spin eigenvalue must be -1 or +1"))
            spin_axis = _nnkp_axis(
                parse.(Float64, replace.(spin_row[2:4], 'D' => 'E', 'd' => 'e')),
                "spin quantization axis",
            )
        end
        push!(
            projections,
            WannierNNKPProjection(
                Tuple(center),
                angular_code,
                angular_index,
                radial_index,
                z_axis,
                x_axis,
                radial_scale,
                spin_eigenvalue,
                spin_axis,
            ),
        )
    end
    return projections
end

"""
    read_wannier_nnkp(filename) -> WannierNNKP

Read and strictly validate the complete Wannier90 preprocessing contract. No
MMN or AMN values are consulted, and no missing section is inferred from a WIN
file or a DFT source.
"""
function read_wannier_nnkp(filename::AbstractString)::WannierNNKP
    isfile(filename) || throw(ArgumentError("NNKP file does not exist: $(filename)"))
    lines = readlines(filename)
    sections = _nnkp_sections(lines)
    for name in ("real_lattice", "recip_lattice", "kpoints", "nnkpts", "exclude_bands")
        haskey(sections, name) || throw(ArgumentError("NNKP omits required section $(name)"))
    end
    has_scalar = haskey(sections, "projections")
    has_spinor = haskey(sections, "spinor_projections")
    xor(has_scalar, has_spinor) || throw(
        ArgumentError("NNKP must contain exactly one projections or spinor_projections section"),
    )
    real_lattice = _nnkp_lattice(sections["real_lattice"], "real_lattice")
    reciprocal_lattice = _nnkp_lattice(sections["recip_lattice"], "recip_lattice")

    kpoint_rows = sections["kpoints"]
    isempty(kpoint_rows) && throw(ArgumentError("NNKP kpoints section is empty"))
    num_kpoints = parse(Int, only(split(kpoint_rows[1])))
    num_kpoints > 0 || throw(ArgumentError("NNKP k-point count must be positive"))
    length(kpoint_rows) == num_kpoints + 1 ||
        throw(ArgumentError("NNKP k-point row count is inconsistent"))
    kpoints = reduce(
        vcat,
        transpose(_nnkp_float_row(kpoint_rows[index + 1], 3, "kpoint")) for index in 1:num_kpoints
    )

    topology_rows = sections["nnkpts"]
    isempty(topology_rows) && throw(ArgumentError("NNKP nnkpts section is empty"))
    num_neighbors = parse(Int, only(split(topology_rows[1])))
    num_neighbors > 0 || throw(ArgumentError("NNKP neighbour count must be positive"))
    length(topology_rows) == 1 + num_kpoints * num_neighbors ||
        throw(ArgumentError("NNKP nnkpts row count is inconsistent"))
    neighbors = Matrix{Int}(undef, num_neighbors, num_kpoints)
    shifts = Array{Int, 3}(undef, 3, num_neighbors, num_kpoints)
    for kpoint in 1:num_kpoints, neighbor_index in 1:num_neighbors
        row = split(topology_rows[1 + (kpoint - 1) * num_neighbors + neighbor_index])
        length(row) == 5 || throw(ArgumentError("NNKP neighbour row is malformed"))
        values = parse.(Int, row)
        values[1] == kpoint ||
            throw(ArgumentError("NNKP neighbour rows do not follow authoritative k-point order"))
        1 <= values[2] <= num_kpoints ||
            throw(ArgumentError("NNKP contains an out-of-range neighbour index"))
        neighbors[neighbor_index, kpoint] = values[2]
        shifts[:, neighbor_index, kpoint] .= values[3:5]
    end

    excluded_rows = sections["exclude_bands"]
    isempty(excluded_rows) && throw(ArgumentError("NNKP exclude_bands section is empty"))
    excluded_count = parse(Int, only(split(excluded_rows[1])))
    excluded_count >= 0 || throw(ArgumentError("NNKP excluded-band count must be nonnegative"))
    length(excluded_rows) == excluded_count + 1 ||
        throw(ArgumentError("NNKP excluded-band row count is inconsistent"))
    excluded = Int[]
    for row in excluded_rows[2:end]
        tokens = split(row)
        length(tokens) == 1 || throw(ArgumentError("NNKP excluded-band row is malformed"))
        push!(excluded, parse(Int, only(tokens)))
    end
    length(unique(excluded)) == length(excluded) ||
        throw(ArgumentError("NNKP contains duplicate excluded bands"))

    spinor = has_spinor
    projections = _nnkp_projections(sections[spinor ? "spinor_projections" : "projections"], spinor)
    digest = open(filename, "r") do io
        bytes2hex(SHA.sha256(io))
    end
    return WannierNNKP(
        real_lattice,
        reciprocal_lattice,
        kpoints,
        neighbors,
        shifts,
        excluded,
        projections,
        spinor,
        digest,
    )
end
