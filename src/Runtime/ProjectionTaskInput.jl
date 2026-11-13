"""Resolve owned-geometry projection input without synthesizing a WIN file.

This entry consumes a Wannier TB's actual H/r inventory. Packed input is checked against its actual inventory; unsupported inventories
are refused before projection rather than being reduced silently to H/r.
"""
function resolve_normalized_projection_input(
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
            "mode",
            "source",
            "structure",
            "kmesh",
            "basis",
            "model",
            "magnetic",
            "symmetry",
            "validation",
            "output",
        ),
        "input",
    )
    get(document, "mode", "projection") == "projection" ||
        throw(ArgumentError("symmetrization supports only projection mode"))
    geometry = _projection_source_geometry(document, base_dir)
    structure = geometry.structure
    mesh = get(document, "kmesh", Dict())
    _task_input_keys(mesh, ("dimensions",), "kmesh")
    if !haskey(mesh, "dimensions")
        geometry.dimensions === nothing &&
            throw(ArgumentError("projection requires the model generation grid dimensions"))
        mesh = Dict("dimensions"=>collect(geometry.dimensions))
    end
    dimensions =
        _task_input_tuple(mesh["dimensions"], "kmesh.dimensions"; integers = true, lengths = (3,))
    all(>(0), dimensions) || throw(ArgumentError("projection grid dimensions must be positive"))
    geometry.dimensions === nothing ||
        geometry.dimensions == dimensions ||
        throw(ArgumentError("explicit generation grid differs from native metadata"))
    basis = _workflow_wannier_basis((; structure), get(document, "basis", Dict()))
    geometry.spinor === nothing ||
        basis.spinor == geometry.spinor ||
        throw(ArgumentError("basis spinor convention differs from native metadata"))
    model = get(document, "model", Dict())
    _task_input_keys(
        model,
        (
            "tb_file",
            "packed_file",
            "chk_file",
            "eig_file",
            "mmn_file",
            "spn_file",
            "wannier_center_policy",
            "real_space_replica_policy",
            "wigner_seitz_tolerance",
            "wigner_seitz_search_size",
            "wannier_center_tolerance",
            "cutoff",
        ),
        "model",
    )
    haskey(model, "tb_file") != haskey(model, "packed_file") ||
        throw(ArgumentError("projection requires exactly one model.tb_file or model.packed_file"))
    model_key = haskey(model, "tb_file") ? "tb_file" : "packed_file"
    model_path = abspath(base_dir, _task_input_string(model[model_key], "model.$model_key"))
    check_paths && !isfile(model_path) && throw(ArgumentError("model.$model_key does not exist"))
    output = get(document, "output", Dict())
    _task_input_keys(output, ("tb_file", "packed_file", "report_json_file", "overwrite"), "output")
    all(k->haskey(output, k), ("tb_file", "packed_file")) ||
        throw(ArgumentError("projection output requires tb_file and packed_file"))
    values = Dict{Symbol, Any}(
        :structure=>structure,
        :projection_basis=>basis,
        :mp_grid=>dimensions,
        :geometry_source_states=>geometry.states,
        (model_key=="tb_file" ? :tb_file : :input_operator_bundle_file)=>model_path,
        :output_tb_file=>abspath(base_dir, _task_input_string(output["tb_file"], "output.tb_file")),
        :output_real_space_operator_bundle_file=>abspath(
            base_dir,
            _task_input_string(output["packed_file"], "output.packed_file"),
        ),
    )
    haskey(output, "report_json_file") && (
        values[:report_json_file]=abspath(
            base_dir,
            _task_input_string(output["report_json_file"], "output.report_json_file"),
        )
    )
    for name in (
        "chk_file",
        "eig_file",
        "mmn_file",
        "spn_file",
        "wannier_center_policy",
        "real_space_replica_policy",
        "wigner_seitz_tolerance",
        "wigner_seitz_search_size",
        "wannier_center_tolerance",
        "cutoff",
    )
        haskey(model, name) && (
            values[Symbol(
                name,
            )]=_workflow_input_value(
                fieldtype(Symmetrization.SymmetrizationConfig, Symbol(name)),
                model[name],
                "model.$name",
                base_dir,
            )
        )
    end
    if haskey(output, "overwrite")
        values[:overwrite] =
            _workflow_input_value(Bool, output["overwrite"], "output.overwrite", base_dir)
    end
    for (group, allowed) in (
        ("symmetry", ("include_time_reversal", "symmetry_tolerance", "operation_indices")),
        (
            "validation",
            (
                "projection_tolerance",
                "representation_tolerance",
                "support_tolerance",
                "roundtrip_tolerance",
                "covariance_tolerance",
                "idempotence_tolerance",
                "check_roundtrip",
                "check_idempotence",
            ),
        ),
    )
        table=get(document, group, Dict());
        _task_input_keys(table, allowed, group)
        for (key, value) in table
            values[Symbol(
                key,
            )]=_workflow_input_value(
                fieldtype(Symmetrization.SymmetrizationConfig, Symbol(key)),
                value,
                "$group.$key",
                base_dir,
            )
        end
    end
    config=Symmetrization.SymmetrizationConfig(; values...)
    Symmetrization.validate_text_input_config(config)
    effective=deepcopy(Dict{String, Any}(document));
    effective["mode"]="projection"
    isempty(geometry.source) || (effective["source"]=geometry.source)
    effective["kmesh"]=Dict("dimensions"=>collect(dimensions))
    effective["model"]=merge(
        Dict{String, Any}(model),
        Dict(
            model_key=>model_path,
            "wannier_center_policy"=>String(config.wannier_center_policy),
            "real_space_replica_policy"=>String(config.real_space_replica_policy),
        ),
    )
    effective["output"]=Dict{String, Any}(
        "tb_file"=>config.output_tb_file,
        "packed_file"=>config.output_real_space_operator_bundle_file,
    )
    config.report_json_file===nothing ||
        (effective["output"]["report_json_file"]=config.report_json_file)
    effective["output"]["overwrite"] = config.overwrite
    for name in (
        "chk_file",
        "eig_file",
        "mmn_file",
        "spn_file",
        "wigner_seitz_tolerance",
        "wigner_seitz_search_size",
        "wannier_center_tolerance",
        "cutoff",
    )
        value = _workflow_input_effective_value(getfield(config, Symbol(name)))
        value === nothing || (effective["model"][name] = value)
    end
    _workflow_absolute_paths!(effective, base_dir)
    records=Dict{String, Dict{String, Any}}();
    _workflow_input_default_records!(records, effective);
    _task_input_user_leaves!(records, document)
    metadata=Dict{String, Any}(
        "status"=>"CONFIG_VALIDATED",
        "workflow"=>"symmetrization",
        "input_path"=>input_path,
        "input_identity"=>input_identity,
        "effective_file_replayable"=>true,
        "model_replay"=>"FILE_INPUT",
        "input_operator_inventory"=>(
            model_key=="tb_file" ? ["hamiltonian", "position"] : "CHECKED_AT_EXECUTION"
        ),
        "scientific_qualification"=>"NOT_ESTABLISHED",
        "geometry_files"=>[state.path for state in geometry.states],
        "magnetic_moments_origin"=>"EXPLICIT_OR_ABSENT_NOT_INFERRED",
    )
    return WorkflowInputResolution(
        config,
        deepcopy(Dict{String, Any}(document)),
        effective,
        records,
        String[],
        Any[],
        metadata,
    )
end

# Geometry-only native reads use the existing XML/POSCAR/OUTCAR ports. They do
# not open wavefunctions or pseudopotentials and do not invent atomic moments.
function _projection_source_geometry(document, base_dir)
    source = get(document, "source", Dict())
    explicit =
        haskey(document, "structure") ? _mesh_input_structure(document["structure"]) : nothing
    if isempty(source)
        owned, magnetic_states =
            _projection_magnetic_structure(document, something(explicit), base_dir)
        return (
            structure = owned,
            dimensions = nothing,
            spinor = nothing,
            states = magnetic_states,
            source = Dict{String, Any}(),
        )
    end
    _task_input_keys(source, ("kind", "save_directory", "poscar_file", "outcar_file"), "source")
    kind=get(source, "kind", nothing)
    states=NamedTuple[]
    resolved=Dict{String, Any}("kind"=>kind)
    dimensions=nothing;
    spinor=nothing;
    magnetic=false
    function observed_path(key)
        haskey(source, key) || throw(ArgumentError("source.$key is required"))
        path=abspath(base_dir, _task_input_string(source[key], "source.$key"))
        push!(states, scientific_file_state(path));
        resolved[key]=path
        return path
    end
    native = if kind=="qe"
        !haskey(source, "poscar_file") && !haskey(source, "outcar_file") ||
            throw(ArgumentError("QE and VASP geometry sources cannot be mixed"))
        haskey(source, "save_directory") || throw(ArgumentError("QE requires save_directory"))
        directory=abspath(
            base_dir,
            _task_input_string(source["save_directory"], "source.save_directory"),
        )
        xml=joinpath(directory, "data-file-schema.xml")
        push!(states, scientific_file_state(xml));
        resolved["save_directory"]=directory
        data=read_qe_geometry_metadata(xml)
        dimensions=data.mesh_dimensions;
        spinor=data.noncollinear_spin
        magnetic=data.collinear_spin===true || data.noncollinear_spin===true
        CrystalStructure(data.lattice_angstrom, data.atomic_labels, data.positions_fractional)
    elseif kind=="vasp"
        !haskey(source, "save_directory") ||
            throw(ArgumentError("VASP and QE geometry sources cannot be mixed"))
        structure=SymmetryFoundation.read_poscar_structure(observed_path("poscar_file"))
        if haskey(source, "outcar_file")
            data=read_vasp_geometry_metadata(observed_path("outcar_file"))
            spinor=data.noncollinear_spin
            magnetic=data.spin_channels==2 || data.noncollinear_spin===true
        end
        structure
    else
        throw(ArgumentError("projection source.kind must be qe or vasp"))
    end
    if explicit !== nothing
        explicit.species==native.species &&
        size(explicit.positions_fractional)==size(native.positions_fractional) ||
            throw(ArgumentError("explicit/native atom order or labels disagree"))
        isapprox(explicit.lattice, native.lattice; atol = 1e-10, rtol = 0) && isapprox(
            explicit.positions_fractional,
            native.positions_fractional;
            atol = 1e-10,
            rtol = 0,
        ) || throw(
            ArgumentError("explicit/native geometry disagrees; no atom reordering is performed"),
        )
    end
    structure=explicit===nothing ? native : explicit
    structure, magnetic_states = _projection_magnetic_structure(document, structure, base_dir)
    append!(states, magnetic_states)
    magnetic &&
        structure.magnetic_moments_cartesian===nothing &&
        throw(
            ArgumentError(
                "magnetic native metadata requires explicit Cartesian atomic moments; spin flags are not atomic moments",
            ),
        )
    foreach(validate_scientific_source_state, states)
    return (; structure, dimensions, spinor, states, source = resolved)
end

# Resolve the existing explicit magnetic provider into owned geometry; never infer moments.
function _projection_magnetic_structure(document, structure, base_dir)
    haskey(document, "magnetic") || return structure, NamedTuple[]
    structure.magnetic_moments_cartesian === nothing || throw(
        ArgumentError("structure magnetic moments and magnetic provider are mutually exclusive"),
    )
    magnetic = _workflow_input_struct(
        Symmetrization.MagneticMomentConfig,
        document["magnetic"],
        "magnetic",
        base_dir,
    )
    states = magnetic.file === nothing ? NamedTuple[] : [scientific_file_state(magnetic.file)]
    moments = Symmetrization.projection_magnetic_moments(magnetic, structure)
    foreach(validate_scientific_source_state, states)
    owned = CrystalStructure(
        structure.lattice,
        structure.species,
        structure.positions_fractional;
        magnetic_moments_cartesian = moments,
    )
    return owned, states
end
