"""Read only the saved QE generating mesh, without interpreting actual k coordinates.

Native wavefunction readers already own the ordered fractional points. This
reader therefore needs neither atomic_structure nor alat; missing generation
metadata returns an unspecified declaration rather than inventing dimensions.
"""
function read_qe_mesh_declaration(filename::AbstractString)
    xml = Base.require(Base.PkgId(Base.UUID("8f5d6c58-4d21-5cfd-889c-e3ad7ee6a615"), "EzXML"))
    observed = with_scientific_source(filename; resolve_links = true) do path
        Base.invokelatest(_read_qe_mesh_declaration, xml, path)
    end
    return observed.value
end

# Parse the saved document inside the XML backend's current method world.
function _read_qe_mesh_declaration(xml, filename)
    return _qe_mesh_declaration(xml, xml.root(xml.readxml(filename)))
end

# Share the exact generating-grid protocol between native-mesh and full-geometry readers.
function _qe_mesh_declaration(xml, root)
    mp = xml.findfirst(
        "./*[local-name()='input']/*[local-name()='k_points_IBZ']/*[local-name()='monkhorst_pack']",
        root,
    )
    dimensions = nothing
    offset = nothing
    if mp !== nothing
        dimensions = ntuple(i -> parse(Int, mp["nk$i"]), 3)
        shifts = ntuple(i -> parse(Int, mp["k$i"]), 3)
        all(>(0), dimensions) && all(x -> x in (0, 1), shifts) ||
            throw(ArgumentError("invalid QE Monkhorst-Pack specification"))
        offset = ntuple(i -> shifts[i] / (2dimensions[i]), 3)
    end
    return (; dimensions, offset, points = nothing)
end

"""Read QE XML geometry and saved k metadata, without UPF or wavefunction access.

Atomic labels and k-point order are retained. Labels are not asserted to be
chemical elements; authoritative pseudopotential mapping belongs to the physical
reader. Loading the already-declared XML library does not install dependencies.
"""
function read_qe_geometry_metadata(filename::AbstractString)
    xml = Base.require(Base.PkgId(Base.UUID("8f5d6c58-4d21-5cfd-889c-e3ad7ee6a615"), "EzXML"))
    observed = with_scientific_source(filename; resolve_links = true) do path
        Base.invokelatest(_read_qe_geometry_metadata, xml, path)
    end
    return observed.value
end

# Read required QE XML cell, atom and species values through the supplied XML backend.
function _read_qe_geometry_metadata(xml, filename)
    document = xml.readxml(filename)
    root = xml.root(document)
    function require_node(node, query)
        found = xml.findfirst(query, node)
        found === nothing && throw(ArgumentError("QE XML missing $query"))
        return found
    end
    function numbers(node, count)
        values = parse.(Float64, split(strip(xml.nodecontent(node))))
        length(values) == count && all(isfinite, values) ||
            throw(ArgumentError("QE XML requires $count finite values"))
        return values
    end
    # Output is the actual final structure; input is a fallback for metadata-only saves.
    structure = xml.findfirst("./*[local-name()='output']/*[local-name()='atomic_structure']", root)
    structure === nothing && (
        structure =
            require_node(root, "./*[local-name()='input']/*[local-name()='atomic_structure']")
    )
    cell = require_node(structure, "./*[local-name()='cell']")
    lattice_bohr = reduce(
        vcat,
        [permutedims(numbers(require_node(cell, "./*[local-name()='a$i']"), 3)) for i in 1:3],
    )
    all(isfinite, lattice_bohr) && abs(det(lattice_bohr)) > eps(Float64) ||
        throw(ArgumentError("QE XML cell must be finite and nonsingular"))
    atoms = xml.findall("./*[local-name()='atomic_positions']/*[local-name()='atom']", structure)
    isempty(atoms) && throw(ArgumentError("QE XML contains no atoms"))
    labels = [strip(String(atom["name"])) for atom in atoms]
    all(!isempty, labels) || throw(ArgumentError("QE XML contains an empty atomic label"))
    cartesian_bohr = hcat([numbers(atom, 3) for atom in atoms]...)
    positions = transpose(lattice_bohr) \ cartesian_bohr
    points = xml.findall(
        "./*[local-name()='output']/*[local-name()='band_structure']/*[local-name()='ks_energies']/*[local-name()='k_point']",
        root,
    )
    fractional = zeros(Float64, 3, 0)
    if !isempty(points)
        haskey(structure, "alat") ||
            throw(ArgumentError("QE XML actual k points require atomic_structure alat"))
        alat = parse(Float64, structure["alat"])
        isfinite(alat) && alat > 0 || throw(ArgumentError("invalid QE alat"))
        # QE schema coordinates are Cartesian in 2π/alat; no periodic reordering.
        fractional = lattice_bohr * hcat([numbers(point, 3) for point in points]...) / alat
    end
    mesh = _qe_mesh_declaration(xml, root)
    dimensions, offset = mesh.dimensions, mesh.offset
    function spin_flag(name)
        node = xml.findfirst(
            "./*[local-name()='output']/*[local-name()='band_structure']/*[local-name()='$name']",
            root,
        )
        node === nothing && return nothing
        text = lowercase(strip(xml.nodecontent(node)))
        text in ("true", "false") || throw(ArgumentError("invalid QE spin flag $name"))
        return text == "true"
    end
    return (
        lattice_angstrom = lattice_bohr .* 0.529177210903,
        atomic_labels = labels,
        positions_fractional = positions,
        kpoints_fractional = fractional,
        original_kpoint_indices = collect(eachindex(points)),
        mesh_dimensions = dimensions,
        mesh_offset_fractional = offset,
        collinear_spin = spin_flag("lsda"),
        noncollinear_spin = spin_flag("noncolin"),
        spinorbit = spin_flag("spinorbit"),
        loaded_files = [abspath(filename)],
        physical_metric_loaded = false,
        wavefunctions_loaded = false,
        chemical_elements_resolved = false,
    )
end
