# Expose saved QE ordered XML points and generating metadata through the same mesh contract.
function _workflow_qe_xml_mesh(path)
    data=read_qe_geometry_metadata(path)
    points=isempty(data.kpoints_fractional) ? nothing : permutedims(data.kpoints_fractional)
    return (; dimensions = data.mesh_dimensions, offset = data.mesh_offset_fractional, points)
end

# Read one explicitly identified mesh format through IO, retaining its provenance path.
function _workflow_mesh_file(mesh, base_dir)
    haskey(mesh, "source_file") == haskey(mesh, "source_format") ||
        throw(ArgumentError("kmesh.source_file and source_format must be supplied together"))
    haskey(mesh, "source_file") || return nothing
    path = abspath(base_dir, _task_input_string(mesh["source_file"], "kmesh.source_file"))
    format = _task_input_string(mesh["source_format"], "kmesh.source_format")
    data =
        format == "vasp_kpoints" ? read_vasp_kpoint_mesh(path) :
        format == "vasp_xml" ? read_vasp_xml_mesh(path) :
        format == "qe_input" ? read_qe_input_mesh(path) :
        format == "qe_xml" ? _workflow_qe_xml_mesh(path) :
        throw(ArgumentError("unsupported kmesh.source_format"))
    return (; data..., path, format)
end

"""Validate every declared grid against actual ordered points, without sorting or symmetry expansion."""
function _workflow_validate_mesh_declaration(declaration, dimensions, points)
    declaration === nothing && return nothing
    declaration.dimensions === nothing ||
        declaration.dimensions == dimensions ||
        throw(ArgumentError("declared mesh dimensions conflict with the effective full grid"))
    if declaration.offset !== nothing
        for row in axes(points, 1), axis in 1:3
            scaled = (points[row, axis]-declaration.offset[axis])*dimensions[axis]
            abs(scaled-round(scaled)) <= 1e-8 ||
                throw(ArgumentError("declared mesh offset conflicts with actual k points"))
        end
    end
    declaration.points === nothing ||
        (
            size(declaration.points) == size(points) &&
            isapprox(declaration.points, points; atol = 1e-10, rtol = 0)
        ) ||
        throw(ArgumentError("declared point list differs from actual matrix/wavefunction order"))
    return nothing
end

# Resolve native grid declarations; actual point coordinates always belong to native wavefunctions.
function _workflow_native_mesh(document, source, metadata; base_dir)
    mesh = get(document, "kmesh", Dict())
    _task_input_keys(
        mesh,
        ("dimensions", "points_fractional", "source_file", "source_format"),
        "kmesh",
    )
    declared = _workflow_mesh_file(mesh, base_dir)
    is_qe = source isa SymmetryFoundation.QuantumEspressoWavefunctionSource
    native = if is_qe
        read_qe_mesh_declaration(joinpath(source.save_directory, "data-file-schema.xml"))
    else
        nothing
    end
    # Native VASP discovery is limited to conventional same-directory metadata.
    if !is_qe && declared === nothing
        directory = dirname(source.wavecar_file)
        xml_path, points_path = joinpath(directory, "vasprun.xml"), joinpath(directory, "KPOINTS")
        # Explicit dimensions and actual wavefunction points suffice when an
        # automatically discovered file contains no supported grid declaration.
        allow_unspecified = haskey(mesh, "dimensions")
        native =
            isfile(xml_path) ? read_vasp_xml_mesh(xml_path; allow_unspecified) :
            isfile(points_path) ? read_vasp_kpoint_mesh(points_path; allow_unspecified) : nothing
    end
    dimensions =
        haskey(mesh, "dimensions") ?
        _task_input_tuple(mesh["dimensions"], "kmesh.dimensions"; integers = true, lengths = (3,)) :
        declared !== nothing && declared.dimensions !== nothing ? declared.dimensions :
        native !== nothing ? native.dimensions : nothing
    dimensions === nothing && throw(
        ArgumentError(
            "Wannierization requires full grid dimensions from native metadata, kmesh.source_file, or explicit kmesh.dimensions",
        ),
    )
    points = metadata.kpoints_fractional
    _workflow_validate_mesh_declaration(native, dimensions, points)
    _workflow_validate_mesh_declaration(declared, dimensions, points)
    if haskey(mesh, "points_fractional")
        supplied = _mesh_input_rows(mesh["points_fractional"], "kmesh.points_fractional")
        size(supplied)==size(points) && isapprox(supplied, points; atol = 1e-10, rtol = 0) ||
            throw(ArgumentError("explicit kmesh must preserve native point order and coordinates"))
    end
    return dimensions, points
end
