# Normalize independent stage settings through their single typed authority.
function _workflow_stage_solver(table; base_dir = pwd())
    stage_keys = string.(fieldnames(Wannierization.WannierizationStageControls))
    solver_keys = setdiff(
        string.(fieldnames(Wannierization.WannierizationSolverConfig)),
        ["stage_controls", "acceleration", "smv_fletcher_reeves_two_stage_audit_manifest"],
    )
    _task_input_keys(table, (solver_keys..., stage_keys...), "solver")
    initialization =
        _task_input_symbol(get(table, "initialization", "amn"), "solver.initialization")
    initialization in (:amn, :random, :restart) ||
        throw(ArgumentError("solver.initialization must be amn, random or restart"))
    controls = Wannierization.WannierizationStageControls(;
        (Symbol(k)=>v for (k, v) in table if k in stage_keys)...,
    )
    extra = Dict{Symbol, Any}(
        Symbol(
            k,
        )=>_workflow_input_value(
            fieldtype(Wannierization.WannierizationSolverConfig, Symbol(k)),
            v,
            "solver.$k",
            base_dir,
        ) for (k, v) in table if !(k in stage_keys) && k != "initialization"
    )
    return Wannierization.WannierizationSolverConfig(;
        initialization,
        stage_controls = controls,
        extra...,
    )
end

"""Resolve the normalized external-basic ordinary TOML into the real solver.

This path never synthesizes WIN files or mixes external matrices with native
operators. Native routes use source-bound owned topology and native EIG/MMN/AMN
generation through the existing QE or VASP qualification backend.
"""
function resolve_normalized_wannier_input(
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
            "input",
            "source",
            "structure",
            "kmesh",
            "basis",
            "matrices",
            "symmetry",
            "windows",
            "solver",
            "checkpoint",
            "validation",
            "output",
        ),
        "input",
    )
    mode = _task_input_symbol(get(document, "mode", "ordinary"), "mode")
    output = get(document, "output", Dict())
    _task_input_keys(
        output,
        (
            string.(fieldnames(Wannierization.WannierizationOutputConfig))...,
            "checkpoint_hdf5",
            "num_print_cycles",
            "detailed_progress",
            "num_dump_cycles",
            "native_matrix_directory",
        ),
        "output",
    )
    haskey(output, "operator_tasks") &&
        haskey(output, "profile") &&
        throw(ArgumentError("output.profile and operator_tasks are mutually exclusive"))
    tasks =
        haskey(output, "operator_tasks") ?
        _workflow_input_operator_tasks(output["operator_tasks"]) : nothing
    profile =
        haskey(output, "profile") ? _task_input_symbol(output["profile"], "output.profile") :
        nothing
    source = get(document, "source", Dict())
    source_kind =
        isempty(source) ? nothing : _task_input_symbol(get(source, "kind", ""), "source.kind")
    explicit_matrices = haskey(document, "matrices")
    demand =
        explicit_matrices ? (; matrix_route = :external_basic) :
        plan_wannier_workflow_data(
            :wannierization;
            mode,
            source_kind,
            explicit_structure = haskey(document, "structure"),
            explicit_kmesh = haskey(document, "kmesh"),
            external_matrices = false,
            profile,
            operator_tasks = tasks,
        )
    mode == :ordinary &&
        !isempty(get(document, "symmetry", Dict())) &&
        throw(ArgumentError("ordinary route does not consume symmetry operations"))
    isempty(get(document, "validation", Dict())) ||
        throw(ArgumentError("validation overrides are not implemented on this normalized route"))
    input = if demand.matrix_route == :external_basic
        _workflow_external_wannier_input(
            get(document, "structure", Dict()),
            get(document, "kmesh", Dict()),
            get(document, "basis", Dict()),
            document["matrices"],
            get(document, "windows", Dict());
            base_dir,
        )
    else
        mode in (:ordinary, :symmetry_adapted) && source_kind in (:qe, :vasp) || throw(
            ArgumentError(
                "native Wannier entry requires ordinary or symmetry_adapted QE/VASP source",
            ),
        )
        haskey(document, "matrices") &&
            throw(ArgumentError("native route forbids external matrix inputs"))
        target = abspath(
            base_dir,
            _task_input_string(get(output, "model_file", "model.h5"), "output.model_file"),
        )
        native_source = _workflow_native_symmetry_source(document, source, mode)
        native = _workflow_input_source(native_source, "source", base_dir)
        artifact_dir =
            haskey(output, "native_matrix_directory") ?
            abspath(
                base_dir,
                _task_input_string(
                    output["native_matrix_directory"],
                    "output.native_matrix_directory",
                ),
            ) : target*".native"
        _workflow_native_wannier_input(document, native; base_dir, artifact_dir, mode)
    end
    advanced = get(document, "input", Dict())
    excluded_input = [
        "wannierization_mode",
        "source",
        "matrix_elements",
        "geometry",
        "projection_basis",
        "band_representation",
        "win_file",
        "eig_file",
        "mmn_file",
        "amn_file",
        "num_wannier",
        "outer_min_ev",
        "outer_max_ev",
        "frozen_min_ev",
        "frozen_max_ev",
    ]
    _task_input_keys(
        advanced,
        setdiff(string.(fieldnames(Wannierization.WannierizationInputConfig)), excluded_input),
        "input",
    )
    replacements = Dict{Symbol, Any}(
        Symbol(
            k,
        )=>_workflow_input_value(
            fieldtype(Wannierization.WannierizationInputConfig, Symbol(k)),
            v,
            "input.$k",
            base_dir,
        ) for (k, v) in advanced
    )
    replacements[:wannierization_mode] = mode
    if explicit_matrices && !isempty(source)
        replacements[:source] = _workflow_input_source(source, "source", base_dir)
    end
    if explicit_matrices && haskey(document["matrices"], "provider")
        replacements[:matrix_elements] = _workflow_input_matrices(
            document["matrices"]["provider"],
            "matrices.provider",
            base_dir,
        )
    end
    if mode == :symmetry_adapted
        for (key, value) in (
            ("symmetry_tolerance", _workflow_native_symmetry_tolerance(document, mode)),
            ("operation_indices", _workflow_native_operation_indices(document, mode)),
        )
            haskey(advanced, key) &&
                haskey(get(document, "symmetry", Dict()), key) &&
                throw(ArgumentError("input.$key and symmetry.$key are duplicate definitions"))
            haskey(advanced, key) || (replacements[Symbol(key)] = value)
        end
    end
    input = Wannierization.replace_wannierization_input(input, (; replacements...))
    solver = _workflow_stage_solver(get(document, "solver", Dict()); base_dir)
    checkpoint = get(document, "checkpoint", Dict())
    _task_input_keys(
        checkpoint,
        ("restart_hdf5", "recovery", "storage", "reference_root"),
        "checkpoint",
    )
    storage = _task_input_symbol(get(checkpoint, "storage", "embedded"), "checkpoint.storage")
    storage in (:embedded, :referenced) ||
        throw(ArgumentError("checkpoint.storage must be embedded or referenced"))
    reference_root =
        haskey(checkpoint, "reference_root") ?
        abspath(
            base_dir,
            _task_input_string(checkpoint["reference_root"], "checkpoint.reference_root"),
        ) : nothing
    (storage == :referenced) == (reference_root !== nothing) ||
        throw(ArgumentError("checkpoint.reference_root is required only for referenced storage"))
    recovery = _task_input_symbol(get(checkpoint, "recovery", "continue"), "checkpoint.recovery")
    recovery in (:continue, :export) ||
        throw(ArgumentError("checkpoint.recovery must be continue or export"))
    recovery == :export &&
        (
            solver.initialization != :restart ||
            solver.stage_controls.dis_num_iter != 0 ||
            solver.stage_controls.num_iter != 0
        ) &&
        throw(ArgumentError("export recovery requires restart and both stage limits zero"))
    restart =
        haskey(checkpoint, "restart_hdf5") ?
        abspath(
            base_dir,
            _task_input_string(checkpoint["restart_hdf5"], "checkpoint.restart_hdf5"),
        ) : nothing
    (solver.initialization == :restart) == (restart !== nothing) || throw(
        ArgumentError(
            "restart initialization and checkpoint.restart_hdf5 must be supplied together",
        ),
    )
    path =
        haskey(output, "checkpoint_hdf5") ?
        abspath(base_dir, _task_input_string(output["checkpoint_hdf5"], "output.checkpoint_hdf5")) :
        nothing
    path===nothing ||
        endswith(path, ".wannierization.h5") ||
        throw(ArgumentError("output.checkpoint_hdf5 must end with .wannierization.h5"))
    model_file=abspath(
        base_dir,
        _task_input_string(get(output, "model_file", "model.h5"), "output.model_file"),
    )
    endswith(model_file, ".h5") || throw(ArgumentError("output.model_file must end with .h5"))
    final_symmetry=get(output, "final_tb_symmetry_report_enabled", false)
    final_symmetry isa Bool ||
        throw(ArgumentError("output.final_tb_symmetry_report_enabled must be Boolean"))
    print_cycles = get(output, "num_print_cycles", 1)
    detailed_progress = get(output, "detailed_progress", false)
    detailed_progress isa Bool || throw(ArgumentError("output.detailed_progress must be Boolean"))
    dump_cycles = get(output, "num_dump_cycles", 100)
    all(x -> x isa Integer && !(x isa Bool) && x >= 0, (print_cycles, dump_cycles)) ||
        throw(ArgumentError("output cycles must be nonnegative integers"))
    final_symmetry = get(output, "final_tb_symmetry_report_enabled", false)
    final_symmetry isa Bool ||
        throw(ArgumentError("output.final_tb_symmetry_report_enabled must be Boolean"))
    output_special =
        Set(["model_file", "profile", "operator_tasks", "final_tb_symmetry_report_enabled"])
    output_values = Dict{Symbol, Any}(
        Symbol(
            k,
        )=>_workflow_input_value(
            fieldtype(Wannierization.WannierizationOutputConfig, Symbol(k)),
            v,
            "output.$k",
            base_dir,
        ) for (k, v) in output if
        k in string.(fieldnames(Wannierization.WannierizationOutputConfig)) &&
        !(k in output_special)
    )
    resolved_profile = tasks === nothing ? something(profile, :hamiltonian_position) : nothing
    resolved_tasks = tasks === nothing ? () : tasks
    generated_paths =
        Wannierization.native_operator_artifact_paths(input, resolved_profile, resolved_tasks)
    config = Wannierization.WannierizationConfig(;
        input,
        solver,
        checkpoint = Wannierization.WannierizationCheckpointConfig(
            restart_hdf5 = restart,
            checkpoint_hdf5 = path,
            num_dump_cycles = dump_cycles,
            recovery = recovery,
            storage = storage,
            reference_root = reference_root,
        ),
        runtime = Wannierization.WannierizationRuntimeConfig(;
            num_print_cycles = print_cycles,
            detailed_progress,
        ),
        output = Wannierization.WannierizationOutputConfig(;
            model_file,
            profile = resolved_profile,
            operator_tasks = resolved_tasks,
            merge(Dict{Symbol, Any}(pairs(generated_paths)), output_values)...,
            final_tb_symmetry_report_enabled = final_symmetry,
        ),
    )
    Wannierization.validate_text_input_config(config)
    check_paths && _workflow_input_check_paths(config)
    effective = deepcopy(Dict{String, Any}(document))
    effective["mode"] = String(mode)
    effective["kmesh"] = Dict{String, Any}(
        "dimensions"=>collect(input.geometry.mp_grid),
        "points_fractional"=>[collect(row) for row in eachrow(input.geometry.kpoints_fractional)],
    )

    original_mesh = get(document, "kmesh", Dict())
    if haskey(original_mesh, "source_file")
        effective["kmesh"]["source_file"] = abspath(base_dir, original_mesh["source_file"])
        effective["kmesh"]["source_format"] = original_mesh["source_format"]
    elseif demand.matrix_route != :external_basic &&
           source_kind == :vasp &&
           !haskey(original_mesh, "dimensions")
        native_directory = dirname(input.source.wavecar_file)
        for (filename, format) in (("vasprun.xml", "vasp_xml"), ("KPOINTS", "vasp_kpoints"))
            discovered=joinpath(native_directory, filename)
            if isfile(discovered)
                effective["kmesh"]["source_file"]=discovered
                effective["kmesh"]["source_format"]=format
                break
            end
        end
    end
    effective["solver"] = Dict{String, Any}(
        "initialization"=>String(solver.initialization),
        (
            String(k)=>getfield(solver.stage_controls, k) for
            k in fieldnames(typeof(solver.stage_controls))
        )...,
    )
    if demand.matrix_route == :external_basic
        effective["matrices"] = Dict{String, Any}(
            String(k)=>getfield(input, k) for
            k in (:eig_file, :mmn_file, :amn_file) if getfield(input, k)!==nothing
        )
    else
        effective["source"] = Dict{String, Any}(source)
        path_fields =
            source_kind == :qe ? (:save_directory,) :
            (:poscar_file, :wavecar_file, :potcar_file, :incar_file, :outcar_file)
        for field in path_fields
            value = getfield(input.source, field)
            value === nothing || (effective["source"][String(field)] = value)
        end
    end
    effective["output"] = merge(
        Dict{String, Any}(output),
        Dict(
            "model_file"=>model_file,
            "final_tb_symmetry_report_enabled"=>final_symmetry,
            "num_print_cycles"=>print_cycles,
            "detailed_progress"=>detailed_progress,
            "num_dump_cycles"=>dump_cycles,
        ),
    )
    path===nothing || (effective["output"]["checkpoint_hdf5"]=path)
    if demand.matrix_route == :native &&
       (haskey(output, "native_matrix_directory") || path!==nothing || restart!==nothing)
        effective["output"]["native_matrix_directory"] = input.matrix_elements.artifact_dir
    elseif haskey(output, "native_matrix_directory")
        throw(ArgumentError("external matrices do not use output.native_matrix_directory"))
    end
    if restart !== nothing || storage == :referenced
        effective["checkpoint"] =
            Dict{String, Any}("recovery"=>String(recovery), "storage"=>String(storage))
        restart === nothing || (effective["checkpoint"]["restart_hdf5"] = restart)
        reference_root === nothing || (effective["checkpoint"]["reference_root"] = reference_root)
    end
    effective["input"] = Dict{String, Any}()
    for name in setdiff(string.(fieldnames(typeof(input))), excluded_input)
        value = _workflow_input_effective_value(getfield(input, Symbol(name)))
        value === nothing || (effective["input"][name] = value)
    end
    solver_effective = _workflow_input_effective_value(solver)
    delete!(solver_effective, "stage_controls")
    merge!(effective["solver"], solver_effective)
    output_effective = _workflow_input_effective_value(config.output)
    delete!(output_effective, "operator_tasks")
    merge!(effective["output"], output_effective)
    explicit_matrices &&
        haskey(document["matrices"], "provider") &&
        (effective["matrices"]["provider"] = _workflow_input_effective_value(input.matrix_elements))
    input.source === nothing ||
        (effective["source"] = _workflow_input_effective_value(input.source))
    records=Dict{String, Dict{String, Any}}()
    _workflow_input_default_records!(records, effective)
    _task_input_user_leaves!(records, document)
    metadata=Dict{String, Any}(
        "status"=>"CONFIG_VALIDATED",
        "workflow"=>"wannierization",
        "input_path"=>input_path,
        "input_identity"=>input_identity,
        "effective_file_replayable"=>true,
        "model_replay"=>"FILE_INPUT",
        "matrix_route"=>String(demand.matrix_route),
        "transient_native_artifacts"=>demand.matrix_route==:native &&
                                      !haskey(output, "native_matrix_directory") &&
                                      path===nothing &&
                                      restart===nothing,
        "scientific_qualification"=>"NOT_ESTABLISHED",
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
