"""
Resolve the explicit structure and actual k-point portion of a Wannier TOML.

The point rows are the matrix-file order, not a request to generate or sort a
grid. The owned geometry constructor validates completeness and uniqueness.
Native metadata adapters must supply the same contract before solver dispatch.
This helper performs no WIN, wavefunction, or matrix-file I/O.
"""
function _workflow_explicit_wannier_geometry(structure_table, kmesh_table; base_dir = pwd())
    structure = _mesh_input_structure(structure_table)
    _task_input_keys(
        kmesh_table,
        ("dimensions", "points_fractional", "source_file", "source_format"),
        "kmesh",
    )
    declared = _workflow_mesh_file(kmesh_table, base_dir)
    dimensions =
        haskey(kmesh_table, "dimensions") ?
        _task_input_tuple(
            kmesh_table["dimensions"],
            "kmesh.dimensions";
            integers = true,
            lengths = (3,),
        ) : declared === nothing ? nothing : declared.dimensions
    points =
        haskey(kmesh_table, "points_fractional") ?
        _mesh_input_rows(kmesh_table["points_fractional"], "kmesh.points_fractional") :
        declared === nothing ? nothing : declared.points
    dimensions !== nothing && points !== nothing || throw(
        ArgumentError(
            "external matrices require full grid dimensions and actual points in matrix-file order; a generating declaration alone supplies no order",
        ),
    )
    _workflow_validate_mesh_declaration(declared, dimensions, points)
    return Wannierization.WannierizationGeometry(structure, dimensions, points)
end

# One explicit external-basic source. Route selection and native source adapters
# stay outside this constructor; no file-existence fallback is permitted here.
function _workflow_external_wannier_input(
    structure_table,
    kmesh_table,
    basis_table,
    matrices_table,
    windows_table;
    base_dir = pwd(),
)
    geometry = _workflow_explicit_wannier_geometry(structure_table, kmesh_table; base_dir)
    basis = _workflow_wannier_basis(geometry, basis_table)
    _task_input_keys(matrices_table, ("eig_file", "mmn_file", "amn_file", "provider"), "matrices")
    all(key->haskey(matrices_table, key), ("eig_file", "mmn_file")) || throw(
        ArgumentError(
            "explicit matrices require EIG and MMN path fields; AMN depends on initialization",
        ),
    )
    paths=Dict(
        Symbol(key)=>abspath(base_dir, _task_input_string(value, "matrices.$key")) for
        (key, value) in matrices_table if key!="provider"
    )
    window_keys = ("outer_min_ev", "outer_max_ev", "frozen_min_ev", "frozen_max_ev")
    _task_input_keys(windows_table, window_keys, "windows")
    windows = Dict(
        Symbol(
            key,
        )=>_workflow_input_value(
            fieldtype(Wannierization.WannierizationInputConfig, Symbol(key)),
            value,
            "windows.$key",
            base_dir,
        ) for (key, value) in windows_table
    )
    return Wannierization.WannierizationInputConfig(;
        wannierization_mode = :ordinary,
        geometry,
        projection_basis = basis,
        num_wannier = basis.num_wannier,
        paths...,
        windows...,
    )
end

# Validate explicit projection lines, spinor choice and orbital count before constructing the normalized basis.
function _workflow_wannier_basis(geometry, basis_table)
    _task_input_keys(basis_table, ("projections", "spinor", "num_wannier"), "basis")
    lines = get(basis_table, "projections", nothing)
    lines isa AbstractVector && !isempty(lines) && all(x -> x isa AbstractString, lines) ||
        throw(ArgumentError("basis.projections requires a nonempty string array"))
    spinor = get(basis_table, "spinor", false)
    spinor isa Bool || throw(ArgumentError("basis.spinor must be Boolean"))
    count = get(basis_table, "num_wannier", nothing)
    count === nothing ||
        (count isa Integer && !(count isa Bool) && count > 0) ||
        throw(ArgumentError("basis.num_wannier must be a positive integer"))
    return WannierProjection.build_wannier_projection_basis(
        String.(lines);
        structure = geometry.structure,
        spinor,
        num_wannier = count,
    )
end
