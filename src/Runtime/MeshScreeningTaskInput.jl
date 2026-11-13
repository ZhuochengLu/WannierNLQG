"""Explicit diagonal mesh screening configuration; never owns wavefunctions."""
Base.@kwdef struct MeshScreeningTaskConfig
    structure::Union{Nothing, CrystalStructure} = nothing
    poscar_file::Union{Nothing, String} = nothing
    qe_metadata::Union{Nothing, NamedTuple} = nothing
    qe_source_state::Union{Nothing, NamedTuple} = nothing
    vasp_metadata::Union{Nothing, NamedTuple} = nothing
    vasp_source_state::Union{Nothing, NamedTuple} = nothing
    mesh::SymmetryFoundation.DiagonalKMesh
    dimension::Int = 3
    density_target::Float64 = 55.0
    search_radius::Int = 10
    include_time_reversal::Bool = true
    symmetry_tolerance::Float64 = 1.0e-5
    mesh_tolerance::Float64 = 1.0e-9
    operation_indices::Tuple{Vararg{Int}} = ()
    report_json_file::String
    overwrite::Bool = false
end

"""Resolved standalone mesh request, with the ordinary CLI's explanation fields."""
struct MeshScreeningInputResolution
    config::MeshScreeningTaskConfig
    original::Dict{String, Any}
    effective::Dict{String, Any}
    provenance::Dict{String, Dict{String, Any}}
    pending::Vector{String}
    summaries::Vector{Any}
    metadata::Dict{String, Any}
end

# Require a row-oriented matrix at the input boundary, preserving row order.
function _mesh_input_rows(value, path)
    value isa AbstractVector && !isempty(value) ||
        throw(ArgumentError("$path requires matrix rows"))
    rows = [_task_input_tuple(row, path; lengths = (3,)) for row in value]
    return reduce(vcat, [permutedims(collect(row)) for row in rows])
end

# Parse explicit structure without reading a WIN or a native wavefunction file.
function _mesh_input_structure(table)
    _task_input_keys(
        table,
        ("lattice_angstrom", "species", "positions_fractional", "magnetic_moments_cartesian"),
        "structure",
    )
    all(key -> haskey(table, key), ("lattice_angstrom", "species", "positions_fractional")) ||
        throw(
            ArgumentError("structure requires lattice_angstrom, species and positions_fractional"),
        )
    species = table["species"]
    species isa AbstractVector && all(x -> x isa AbstractString && !isempty(strip(x)), species) ||
        throw(ArgumentError("structure.species requires nonempty atomic labels"))
    lattice = _mesh_input_rows(table["lattice_angstrom"], "structure.lattice_angstrom")
    positions =
        transpose(_mesh_input_rows(table["positions_fractional"], "structure.positions_fractional"))
    moments =
        haskey(table, "magnetic_moments_cartesian") ?
        transpose(
            _mesh_input_rows(
                table["magnetic_moments_cartesian"],
                "structure.magnetic_moments_cartesian",
            ),
        ) : nothing
    return CrystalStructure(lattice, species, positions; magnetic_moments_cartesian = moments)
end

"""Resolve the standalone screening TOML without symmetry detection or wavefunction I/O."""
function resolve_mesh_screening_input(
    document;
    base_dir = pwd(),
    input_path = "",
    input_identity = "",
    check_paths = true,
)
    _task_input_keys(
        document,
        (
            "workflow",
            "source",
            "structure",
            "kmesh",
            "symmetry",
            "mesh_screening",
            "validation",
            "output",
        ),
        "input",
    )
    source = get(document, "source", Dict())
    _task_input_keys(source, ("kind", "poscar_file", "outcar_file", "save_directory"), "source")
    source_kind = isempty(source) ? nothing : get(source, "kind", nothing)
    source_kind in (nothing, "vasp", "qe") || throw(ArgumentError("source.kind must be qe or vasp"))
    poscar = nothing
    qe = nothing
    qe_state = nothing
    vasp = nothing
    vasp_state = nothing
    if !isempty(source)
        if source_kind == "vasp"
            haskey(source, "poscar_file") && !haskey(source, "save_directory") ||
                throw(ArgumentError("VASP source requires only poscar_file"))
            poscar =
                abspath(base_dir, _task_input_string(source["poscar_file"], "source.poscar_file"))
            check_paths && !isfile(poscar) && throw(ArgumentError("POSCAR does not exist: $poscar"))
            if haskey(source, "outcar_file")
                outcar = abspath(
                    base_dir,
                    _task_input_string(source["outcar_file"], "source.outcar_file"),
                )
                vasp_state = scientific_file_state(outcar)
                vasp = read_vasp_geometry_metadata(outcar)
                validate_scientific_source_state(vasp_state)
            end
        elseif source_kind == "qe"
            haskey(source, "save_directory") &&
            !haskey(source, "poscar_file") &&
            !haskey(source, "outcar_file") ||
                throw(ArgumentError("QE source requires only save_directory"))
            directory = abspath(
                base_dir,
                _task_input_string(source["save_directory"], "source.save_directory"),
            )
            xml_file = joinpath(directory, "data-file-schema.xml")
            qe_state = scientific_file_state(xml_file)
            qe = read_qe_geometry_metadata(xml_file)
            validate_scientific_source_state(qe_state)
        else
            throw(ArgumentError("nonempty source requires kind"))
        end
    end
    structure =
        haskey(document, "structure") ? _mesh_input_structure(document["structure"]) : nothing
    kmesh = get(document, "kmesh", Dict())
    _task_input_keys(kmesh, ("dimensions", "offset_fractional", "offset_grid_steps"), "kmesh")
    if !haskey(kmesh, "dimensions")
        isempty(kmesh) || throw(ArgumentError("kmesh offsets require dimensions"))
        qe !== nothing && qe.mesh_dimensions !== nothing || throw(
            ArgumentError(
                "explicit full-grid dimensions are required; do not infer a grid from irreducible points",
            ),
        )
        kmesh = Dict(
            "dimensions"=>collect(qe.mesh_dimensions),
            "offset_fractional"=>collect(qe.mesh_offset_fractional),
        )
    end
    sizes =
        _task_input_tuple(kmesh["dimensions"], "kmesh.dimensions"; integers = true, lengths = (3,))
    haskey(kmesh, "offset_fractional") &&
        haskey(kmesh, "offset_grid_steps") &&
        throw(ArgumentError("kmesh offset_fractional and offset_grid_steps are mutually exclusive"))
    offset = if haskey(kmesh, "offset_grid_steps")
        steps = _task_input_tuple(kmesh["offset_grid_steps"], "kmesh.offset_grid_steps"; lengths = (3,))
        ntuple(axis -> steps[axis] / sizes[axis], 3)
    else
        _task_input_tuple(
            get(kmesh, "offset_fractional", [0.0, 0.0, 0.0]),
            "kmesh.offset_fractional";
            lengths = (3,),
        )
    end
    mesh = SymmetryFoundation.DiagonalKMesh(sizes, offset)
    if qe !== nothing && qe.mesh_dimensions !== nothing
        mesh.dimensions == qe.mesh_dimensions ||
            throw(ArgumentError("explicit kmesh and QE grid dimensions disagree"))
        shifts = [
            (mesh.offset_fractional[i] - qe.mesh_offset_fractional[i]) * mesh.dimensions[i] for
            i in 1:3
        ]
        maximum(abs, shifts .- round.(shifts)) <= 1.0e-9 ||
            throw(ArgumentError("explicit kmesh and QE grid offsets disagree"))
    end
    screen = get(document, "mesh_screening", Dict())
    symmetry = get(document, "symmetry", Dict())
    validation = get(document, "validation", Dict())
    output = get(document, "output", Dict())
    _task_input_keys(screen, ("dimension", "density_target", "search_radius"), "mesh_screening")
    _task_input_keys(
        symmetry,
        ("include_time_reversal", "symmetry_tolerance", "operation_indices"),
        "symmetry",
    )
    _task_input_keys(validation, ("mesh_tolerance",), "validation")
    _task_input_keys(output, ("report_json_file", "overwrite"), "output")
    haskey(output, "report_json_file") ||
        throw(ArgumentError("output.report_json_file is required"))
    path =
        abspath(base_dir, _task_input_string(output["report_json_file"], "output.report_json_file"))
    values = Dict{Symbol, Any}()
    for (name, table) in (
        ("mesh_screening", screen),
        ("symmetry", symmetry),
        ("validation", validation),
        ("output", output),
    )
        for (key, value) in table
            key == "report_json_file" && continue
            if key == "operation_indices"
                value isa AbstractVector &&
                all(x -> x isa Integer && !(x isa Bool) && x > 0, value) ||
                    throw(ArgumentError("symmetry.operation_indices requires positive integers"))
                length(unique(value)) == length(value) ||
                    throw(ArgumentError("operation_indices contains duplicates"))
                values[:operation_indices] = Tuple(Int.(value))
            else
                values[Symbol(key)] = _workflow_input_value(
                    fieldtype(MeshScreeningTaskConfig, Symbol(key)),
                    value,
                    "$name.$key",
                    base_dir,
                )
            end
        end
    end
    config = MeshScreeningTaskConfig(;
        structure,
        poscar_file = poscar,
        qe_metadata = qe,
        qe_source_state = qe_state,
        vasp_metadata = vasp,
        vasp_source_state = vasp_state,
        mesh,
        report_json_file = path,
        values...,
    )
    if qe !== nothing && (qe.collinear_spin === true || qe.noncollinear_spin === true)
        structure !== nothing && structure.magnetic_moments_cartesian !== nothing || throw(
            ArgumentError(
                "spin-polarized QE screening currently requires explicit structure magnetic moments; automatic magnetic metadata adapter is pending",
            ),
        )
    end
    if vasp !== nothing &&
       (vasp.spin_channels != 1 || vasp.noncollinear_spin !== false || vasp.spinorbit !== false)
        structure !== nothing && structure.magnetic_moments_cartesian !== nothing || throw(
            ArgumentError(
                "VASP magnetic or unspecified spin metadata requires explicit structure magnetic moments; OUTCAR flags do not define them",
            ),
        )
    end
    config.dimension in (2, 3) || throw(ArgumentError("dimension must be 2 or 3"))
    config.density_target > 0 &&
    config.search_radius >= 0 &&
    config.symmetry_tolerance > 0 &&
    0 < config.mesh_tolerance < 0.5 ||
        throw(ArgumentError("invalid mesh density, search radius or tolerance"))
    demand = plan_wannier_workflow_data(
        :mesh_screening;
        source_kind = source_kind === nothing ? nothing : Symbol(source_kind),
        explicit_structure = structure !== nothing,
        explicit_kmesh = true,
    )
    effective = deepcopy(Dict{String, Any}(document))
    effective["kmesh"] = Dict("dimensions"=>collect(sizes), "offset_fractional"=>collect(offset))
    poscar === nothing || (effective["source"] = Dict("kind"=>"vasp", "poscar_file"=>poscar))
    vasp === nothing || (effective["source"]["outcar_file"] = vasp_state.path)
    qe === nothing ||
        (effective["source"] = Dict("kind"=>"qe", "save_directory"=>dirname(qe_state.path)))
    for (group, keys) in (
        ("mesh_screening", ("dimension", "density_target", "search_radius")),
        ("symmetry", ("include_time_reversal", "symmetry_tolerance", "operation_indices")),
        ("validation", ("mesh_tolerance",)),
        ("output", ("report_json_file", "overwrite")),
    )
        effective[group] = Dict(
            key=>_workflow_input_effective_value(getproperty(config, Symbol(key))) for key in keys
        )
    end
    records = Dict{String, Dict{String, Any}}()
    _workflow_input_default_records!(records, effective)
    _task_input_user_leaves!(records, document)
    metadata = Dict{String, Any}(
        "status"=>"CONFIG_VALIDATED",
        "workflow"=>"mesh_screening",
        "model_replay"=>"FILE_INPUT",
        "effective_file_replayable"=>true,
        "input_path"=>input_path,
        "input_identity"=>input_identity,
        "scientific_qualification"=>"NOT_ESTABLISHED",
        "model_capability_validation"=>"MATHEMATICAL_GRID_ONLY; NO_WAVEFUNCTIONS",
        "data_requirements"=>Dict(
            "structure"=>demand.structure,
            "kmesh"=>demand.kmesh,
            "wavefunction_coefficients"=>demand.wavefunction_coefficients,
            "physical_metric"=>demand.physical_metric,
        ),
    )
    return MeshScreeningInputResolution(
        config,
        deepcopy(Dict{String, Any}(document)),
        effective,
        records,
        String[],
        Any[],
        metadata,
    )
end

# Preserve atom order and reject conflicting explicit/native structure metadata.
function _mesh_screening_structure(config::MeshScreeningTaskConfig)
    config.poscar_file === nothing &&
        config.qe_metadata === nothing &&
        return something(config.structure)
    native = if config.qe_metadata !== nothing
        data = config.qe_metadata
        CrystalStructure(data.lattice_angstrom, data.atomic_labels, data.positions_fractional)
    else
        SymmetryFoundation.read_poscar_structure(config.poscar_file)
    end
    if config.structure !== nothing
        explicit = config.structure
        explicit.species == native.species ||
            throw(ArgumentError("explicit structure and source atom labels/order disagree"))
        isapprox(explicit.lattice, native.lattice; atol = config.symmetry_tolerance, rtol = 0) ||
            throw(ArgumentError("explicit lattice and source disagree"))
        difference = explicit.positions_fractional - native.positions_fractional
        maximum(abs, difference .- round.(difference)) <= config.symmetry_tolerance ||
            throw(ArgumentError("explicit atom positions and source disagree"))
        return explicit
    end
    return native
end

"""Run standalone mathematical mesh screening through the existing CLI protocol."""
function run_task_input(input::MeshScreeningInputResolution; record_directory::AbstractString)
    config = input.config
    !config.overwrite &&
        ispath(config.report_json_file) &&
        throw(ArgumentError("refusing to overwrite mesh report"))
    write_task_input_resolution(input, record_directory; actual_state = "PREPARED")
    try
        config.qe_source_state === nothing ||
            validate_scientific_source_state(config.qe_source_state)
        config.vasp_source_state === nothing ||
            validate_scientific_source_state(config.vasp_source_state)
        structure = _mesh_screening_structure(config)
        saved_points = config.qe_metadata === nothing ? config.vasp_metadata : config.qe_metadata
        actual_points =
            saved_points === nothing ? nothing :
            SymmetryFoundation.classify_diagonal_mesh_points(
                config.mesh,
                saved_points.kpoints_fractional;
                tolerance = config.mesh_tolerance,
            )
        operations = SymmetryFoundation.detect_tb_compatibility_symmetry_operations(
            structure;
            include_time_reversal = config.include_time_reversal,
            symmetry_tolerance = config.symmetry_tolerance,
        )
        indices =
            isempty(config.operation_indices) ? collect(eachindex(operations)) :
            collect(config.operation_indices)
        all(index -> index <= length(operations), indices) ||
            throw(ArgumentError("operation index exceeds detected inventory"))
        selected = operations[indices]
        result = SymmetryFoundation.recommend_diagonal_mesh(
            structure,
            config.mesh,
            selected;
            dimension = config.dimension,
            density_target = config.density_target,
            search_radius = config.search_radius,
            tolerance = config.mesh_tolerance,
        )
        report = Dict{String, Any}(
            "scope"=>"MATHEMATICAL_GRID_SCREENING_NOT_WAVEFUNCTION_COMPLETION",
            "grid_provenance"=>actual_points !== nothing && actual_points.complete ?
                               "ACTUAL_COMPLETE_POINT_SET" :
                               "CONSTRUCTED_FROM_EXPLICIT_DIAGONAL_SPECIFICATION",
            "actual_point_inventory"=>actual_points === nothing ? Dict("available"=>false) :
                                      Dict(
                "available"=>true,
                "complete"=>actual_points.complete,
                "actual_count"=>actual_points.actual_count,
                "grid_count"=>actual_points.grid_count,
                "slots_in_original_order"=>actual_points.slots_in_original_order,
            ),
            "loaded_geometry_files"=>config.qe_metadata === nothing ?
                                     vcat(
                config.poscar_file === nothing ? String[] : [config.poscar_file],
                config.vasp_metadata === nothing ? String[] : config.vasp_metadata.loaded_files,
            ) : config.qe_metadata.loaded_files,
            "wavefunctions_loaded"=>false,
            "physical_metric_loaded"=>false,
            "original_dimensions"=>collect(config.mesh.dimensions),
            "original_offset_fractional"=>collect(config.mesh.offset_fractional),
            "original_closed"=>result.original_closed,
            "recommended_dimensions"=>collect(result.recommended.dimensions),
            "recommended_offset_fractional"=>collect(result.recommended.offset_fractional),
            "grid_step_offset"=>collect(result.grid_step_offset),
            "density_products"=>collect(result.density_products),
            "density_target"=>config.density_target,
            "density_metric"=>"lattice_row_length_angstrom_times_mesh_size_not_convergence",
            "search_lower"=>collect(result.search_lower),
            "search_upper"=>collect(result.search_upper),
            "operation_indices"=>indices,
            "operations"=>[
                Dict(
                    "rotation_fractional"=>collect.(eachrow(op.rotation_fractional)),
                    "antiunitary"=>op.antiunitary,
                ) for op in selected
            ],
            "original_checks"=>result.original_checks,
            "original_enumeration"=>result.original_enumeration,
            "recommended_enumeration"=>result.recommended_enumeration,
        )
        config.qe_source_state === nothing ||
            validate_scientific_source_state(config.qe_source_state)
        write_task_input_json(config.report_json_file, report)
        write_task_input_resolution(
            input,
            record_directory;
            actual_state = "COMPLETED",
            actual = Dict(
                "qualification"=>"MATHEMATICAL_GRID_ONLY",
                "report_json_file"=>config.report_json_file,
            ),
        )
        return report
    catch error
        write_task_input_resolution(
            input,
            record_directory;
            actual_state = "FAILED",
            actual = Dict("error"=>sprint(showerror, error)),
        )
        rethrow()
    end
end
