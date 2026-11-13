"""Read a declared regular VASP mesh or explicit reciprocal point list.

Shifts are returned in fractional reciprocal coordinates modulo grid steps.
A generating grid never supplies an order for externally generated matrices.
`allow_unspecified` only admits a valid scalar Automatic request without deriving
its mesh; native callers must supply independently validated explicit dimensions.
"""
function read_vasp_kpoint_mesh(filename::AbstractString; allow_unspecified::Bool = false)
    return with_scientific_source(filename; resolve_links = true) do path
        lines = [strip(first(split(line, r"[!#]"; limit = 2))) for line in readlines(path)]
        length(lines) >= 4 || throw(ArgumentError("KPOINTS requires at least four lines"))
        count = parse(Int, lines[2])
        mode = lowercase(strip(lines[3]))
        if count == 0
            if allow_unspecified && startswith(mode, "a")
                spacing = parse.(Float64, split(lines[4]))
                length(spacing) == 1 && isfinite(only(spacing)) && only(spacing) > 0 ||
                    throw(ArgumentError("invalid scalar Automatic KPOINTS request"))
                return (; dimensions = nothing, offset = nothing, points = nothing)
            end
            startswith(mode, "g") ||
                startswith(mode, "m") ||
                throw(
                    ArgumentError(
                        "KPOINTS requires explicit Gamma/Monkhorst-Pack divisions; use saved XML for automatic spacing",
                    ),
                )
            dimensions = Tuple(parse.(Int, split(lines[4])))
            length(dimensions) == 3 && all(>(0), dimensions) ||
                throw(ArgumentError("invalid KPOINTS divisions"))
            shifts =
                length(lines) >= 5 && !isempty(lines[5]) ? parse.(Float64, split(lines[5])) :
                zeros(3)
            length(shifts) == 3 && all(isfinite, shifts) ||
                throw(ArgumentError("invalid KPOINTS shifts"))
            offset = ntuple(
                i ->
                    (shifts[i] + (startswith(mode, "m") ? (1-dimensions[i])/2 : 0))/dimensions[i],
                3,
            )
            return (; dimensions, offset, points = nothing)
        end
        count > 0 && startswith(mode, "r") ||
            throw(ArgumentError("only reciprocal explicit KPOINTS are supported; no line mode"))
        length(lines) >= 3+count || throw(ArgumentError("truncated KPOINTS list"))
        points = Matrix{Float64}(undef, count, 3)
        for i in 1:count
            row = parse.(Float64, split(lines[3 + i]))
            length(row) in (3, 4) && all(isfinite, row) ||
                throw(ArgumentError("invalid explicit KPOINTS row"))
            points[i, :] .= row[1:3]
        end
        return (; dimensions = nothing, offset = nothing, points)
    end |> x -> x.value
end

"""Read VASP XML generating divisions and offset without reordering actual states.

With `allow_unspecified`, absent or unsupported generation metadata supplies no
mesh dimensions; any saved point list still has to match the actual state order.
Recognized regular declarations retain all value and offset checks.
"""
function read_vasp_xml_mesh(filename::AbstractString; allow_unspecified::Bool = false)
    xml = Base.require(Base.PkgId(Base.UUID("8f5d6c58-4d21-5cfd-889c-e3ad7ee6a615"), "EzXML"))
    return with_scientific_source(filename; resolve_links = true) do path
        Base.invokelatest(_read_vasp_xml_mesh, xml, path, allow_unspecified)
    end |> x -> x.value
end

# Decode only the labelled generation specification; Cartesian/generalized grids are rejected.
function _read_vasp_xml_mesh(xml, path, allow_unspecified)
    root = xml.root(xml.readxml(path))
    nodes = xml.findall("//kpoints/varray[@name='kpointlist']/v", root)
    points =
        isempty(nodes) ? nothing :
        reduce(vcat, [permutedims(parse.(Float64, split(xml.nodecontent(node)))) for node in nodes])
    points === nothing ||
        (size(points, 2)==3 && all(isfinite, points)) ||
        throw(ArgumentError("invalid VASP XML kpoint list"))
    generation = xml.findfirst("//kpoints/generation", root)
    if generation === nothing
        allow_unspecified ||
            throw(ArgumentError("VASP XML has no regular mesh generation declaration"))
        return (; dimensions = nothing, offset = nothing, points)
    end
    mode = haskey(generation, "param") ? lowercase(String(generation["param"])) : ""
    if !(mode in ("gamma", "monkhorst-pack"))
        allow_unspecified || throw(ArgumentError("unsupported VASP XML generating grid"))
        return (; dimensions = nothing, offset = nothing, points)
    end
    division = xml.findfirst("./v[@name='divisions']", generation)
    division === nothing && throw(ArgumentError("VASP XML has no generating divisions"))
    dimensions = Tuple(parse.(Int, split(xml.nodecontent(division))))
    length(dimensions) == 3 && all(>(0), dimensions) ||
        throw(ArgumentError("invalid VASP XML divisions"))
    shift = xml.findfirst("./v[@name='usershift']", generation)
    shifts = shift === nothing ? zeros(3) : parse.(Float64, split(xml.nodecontent(shift)))
    length(shifts) == 3 && all(isfinite, shifts) ||
        throw(ArgumentError("invalid VASP XML usershift"))
    offset = ntuple(
        i -> (shifts[i] + (mode == "monkhorst-pack" ? (1-dimensions[i])/2 : 0))/dimensions[i],
        3,
    )
    return (; dimensions, offset, points)
end

"""Read QE K_POINTS automatic/gamma/crystal without inventing missing wavefunctions.

Only the K_POINTS card is consumed; Cartesian point cards require the saved XML
and are deliberately rejected here to avoid guessing alat or cell provenance.
"""
function read_qe_input_mesh(filename::AbstractString)
    return with_scientific_source(filename; resolve_links = true) do path
        lines = [strip(first(split(line, '!'; limit = 2))) for line in readlines(path)]
        headers = findall(line -> occursin(r"(?i)^K_POINTS\b", line), lines)
        length(headers) == 1 ||
            throw(ArgumentError("QE input requires exactly one K_POINTS card"))
        index = only(headers)
        header = lowercase(replace(lines[index], r"[{}()]" => " "))
        tokens = split(header)
        length(tokens) == 2 ||
            throw(ArgumentError("QE K_POINTS requires an explicit supported coordinate mode"))
        mode = tokens[2]
        mode == "gamma" &&
            return (; dimensions = (1, 1, 1), offset = (0.0, 0.0, 0.0), points = zeros(1, 3))
        rows = filter(!isempty, lines[(index + 1):end])
        isempty(rows) && throw(ArgumentError("truncated QE K_POINTS card"))
        if mode == "automatic"
            values = parse.(Int, split(rows[1]))
            length(values) == 6 && all(>(0), values[1:3]) && all(x -> x in (0, 1), values[4:6]) ||
                throw(ArgumentError("invalid QE automatic grid"))
            dimensions = Tuple(values[1:3])
            offset = ntuple(i -> values[3 + i]/(2dimensions[i]), 3)
            return (; dimensions, offset, points = nothing)
        end
        mode == "crystal" ||
            throw(ArgumentError("QE point input supports crystal, automatic or gamma; no paths"))
        count = parse(Int, rows[1])
        count > 0 && length(rows) >= count+1 ||
            throw(ArgumentError("truncated QE crystal point list"))
        points = Matrix{Float64}(undef, count, 3)
        for i in 1:count
            values = parse.(Float64, split(rows[i + 1]))
            length(values) == 4 && all(isfinite, values) ||
                throw(ArgumentError("invalid QE crystal point"))
            points[i, :] .= values[1:3]
        end
        return (; dimensions = nothing, offset = nothing, points)
    end |> x -> x.value
end
