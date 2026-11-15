"""File-replayable preparation request resolved through the existing workflow constructors."""
struct WorkflowInputResolution
    config::Union{Wannierization.WannierizationConfig, Symmetrization.SymmetrizationConfig}
    original::Dict{String, Any}
    effective::Dict{String, Any}
    provenance::Dict{String, Dict{String, Any}}
    pending::Vector{String}
    summaries::Vector{Any}
    metadata::Dict{String, Any}
end

# Only these existing polymorphic constructors are available through text; no type lookup or eval.
const WORKFLOW_INPUT_KINDS = Dict(
    "coefficient_mapping" => Wannierization.CoefficientMappingSewing,
    "augmentation_aware_paw_q0" => Wannierization.AugmentationAwareSewing,
    "native_eigenstate" => Wannierization.NativeEigenstateGauge,
    "star_covariant_paw" => Wannierization.StarCovariantPAWGauge,
    "native_dft" => Wannierization.NativeDFTHamiltonian,
    "symmetrized_dft" => Wannierization.SymmetrizedDFTHamiltonian,
    "amn_exact_frozen" => Wannierization.AMNExactFrozenInitialization,
    "paw_scdm" => Wannierization.PAWSCDMInitialization,
    "projectability_disentanglement" =>
        Wannierization.ProjectabilityDisentanglementInitialization,
    "fixed_gap" => Wannierization.FixedGapPAWBlockPartition,
    "adaptive_evidence" => Wannierization.AdaptiveEvidencePAWBlockPartition,
    "hamiltonian_weighted" => Wannierization.HamiltonianWeightedPAWBlockPartition,
    "none" => Wannierization.NoDiscreteHamiltonianCorrection,
    "far_band_covariance" => Wannierization.FarBandCovarianceCorrection,
)

# Resolve file and directory leaves against the TOML, including nested source/backend options.
_workflow_path_field(key) =
    endswith(key, "_file") ||
    endswith(key, "_hdf5") ||
    endswith(key, "_json") ||
    endswith(key, "_directory") ||
    endswith(key, "_dir") ||
    key in ("file", "output_root")

# Reject omitted-value strings and invalid numeric/container types before invoking constructors.
function _workflow_input_value(T, value, path, base_dir)
    value isa AbstractString &&
        value == "nothing" &&
        throw(ArgumentError("$path: omit optional fields instead of the string nothing"))
    alternatives = filter(t -> t !== Nothing, Base.uniontypes(T))
    length(alternatives) == 1 && (T = only(alternatives))
    key = last(split(path, '.'))
    if T === String
        text = _task_input_string(value, path)
        return _workflow_path_field(key) ? abspath(base_dir, text) : text
    elseif T === Symbol
        return _task_input_symbol(value, path)
    elseif T === Bool
        value isa Bool || throw(ArgumentError("$path must be Boolean"))
        return value
    elseif T <: Integer
        value isa Integer && !(value isa Bool) || throw(ArgumentError("$path must be an integer"))
        return try
            convert(T, value)
        catch
            ;
            throw(ArgumentError("$path integer is outside $T"))
        end
    elseif T <: AbstractFloat
        value isa Real && !(value isa Bool) && isfinite(value) && isfinite(T(value)) ||
            throw(ArgumentError("$path must be a finite representable real"))
        return T(value)
    elseif T <: UnitRange{Int}
        # This is the existing source's contiguous band_range, not a new response band syntax.
        values = _task_input_tuple(value, path; integers = true, lengths = (2,))
        values[2] >= values[1] || throw(ArgumentError("$path band_range is reversed"))
        return values[1]:values[2]
    elseif T <: AbstractMatrix
        value isa AbstractVector && !isempty(value) ||
            throw(ArgumentError("$path requires matrix rows"))
        rows = [_task_input_tuple(row, path; lengths = (3,)) for row in value]
        # Direct axial moments are N x 3 in text, 3 x N in the existing API, in WIN atom order (mu_B).
        return convert(T, hcat(collect.(rows)...))
    elseif T <: AbstractVector
        value isa AbstractVector || throw(ArgumentError("$path requires an array"))
        key == "provenance_scripts" &&
            return [abspath(base_dir, _task_input_string(item, path)) for item in value]
        return T([_workflow_input_value(eltype(T), item, path, base_dir) for item in value])
    elseif T <: Tuple
        value isa AbstractVector || throw(ArgumentError("$path requires an array"))
        converted = Tuple(
            _workflow_input_value(fieldtype(T, index), item, path, base_dir) for
            (index, item) in enumerate(value)
        )
        return try
            convert(T, converted)
        catch
            ;
            throw(ArgumentError("$path has an invalid tuple shape"))
        end
    elseif value isa AbstractDict
        if isabstracttype(T)
            kind = get(value, "kind", nothing)
            kind isa String && haskey(WORKFLOW_INPUT_KINDS, kind) ||
                throw(ArgumentError("$path requires a supported explicit kind"))
            constructor = WORKFLOW_INPUT_KINDS[kind]
            constructor <: T || throw(ArgumentError("$path kind=$kind does not construct $T"))
            return _workflow_input_struct(
                constructor,
                Dict(k=>v for (k, v) in value if k != "kind"),
                path,
                base_dir,
            )
        end
        return _workflow_input_struct(T, value, path, base_dir)
    end
    throw(
        ArgumentError(
            "$path is not a serializable field of $T; use the Julia API for in-memory objects/callbacks",
        ),
    )
end

# Field names and defaults belong to the existing constructor; only explicit leaves are passed.
function _workflow_input_struct(T, table, path, base_dir; excluded = ())
    T === Wannierization.WannierizationSolverConfig &&
        (excluded = (excluded..., "acceleration", "smv_fletcher_reeves_two_stage_audit_manifest"))
    _task_input_keys(table, setdiff(string.(fieldnames(T)), collect(excluded)), path)
    arguments = Dict{Symbol, Any}()
    for (key, value) in table
        field = Symbol(key)
        arguments[field] = _workflow_input_value(fieldtype(T, field), value, "$path.$key", base_dir)
    end
    try
        return T(; arguments...)
    catch error
        error isa UndefKeywordError && throw(ArgumentError("$path requires $(error.var)"))
        rethrow()
    end
end

# VASP/QE positional entry fields are explicit mappings to their real constructors.
function _workflow_input_source(table, path, base_dir)
    kind = get(table, "kind", nothing)
    T, required =
        kind == "vasp" ?
        (SymmetryFoundation.VASPWavefunctionSource, ("poscar_file", "wavecar_file")) :
        kind == "qe" ? (SymmetryFoundation.QuantumEspressoWavefunctionSource, ("save_directory",)) :
        throw(ArgumentError("$path.kind must be vasp or qe"))
    _task_input_keys(table, ("kind", string.(fieldnames(T))...), path)
    all(key -> haskey(table, key), required) ||
        throw(ArgumentError("$path requires $(join(required, ", "))"))
    kwargs = Dict(
        Symbol(
            key,
        )=>_workflow_input_value(fieldtype(T, Symbol(key)), value, "$path.$key", base_dir) for
        (key, value) in table if key != "kind" && !(key in required)
    )
    args = [abspath(base_dir, _task_input_string(table[key], "$path.$key")) for key in required]
    return T(args...; kwargs...)
end

# Matrix-element providers remain explicit; a source kind never selects PAW/USPP implicitly.
function _workflow_input_matrices(table, path, base_dir)
    kind = get(table, "kind", nothing)
    T, required =
        kind == "external_overlap_projection" ?
        (Wannierization.ExternalOverlapProjectionMatrices, ("mmn_file", "amn_file")) :
        kind == "native_vasp_paw" ? (Wannierization.NativeVASPPAWMatrices, ("topology_mmn_file",)) :
        kind == "native_qe_paw" ? (Wannierization.NativeQEPAWMatrices, ("nnkp_file",)) :
        kind == "symmetry_completed_qe_paw" ?
        (Wannierization.SymmetryCompletedQEPAWMatrices, ("nnkp_file", "gauge_hdf5")) :
        throw(ArgumentError("$path.kind requires an existing explicit matrix-element provider"))
    _task_input_keys(table, ("kind", string.(fieldnames(T))...), path)
    all(key -> haskey(table, key), required) ||
        throw(ArgumentError("$path requires $(join(required, ", "))"))
    kwargs = Dict(
        Symbol(
            key,
        )=>_workflow_input_value(fieldtype(T, Symbol(key)), value, "$path.$key", base_dir) for
        (key, value) in table if key != "kind" && !(key in required)
    )
    args = [abspath(base_dir, _task_input_string(table[key], "$path.$key")) for key in required]
    return T(args...; kwargs...)
end

# OperatorTask really has only quantity and method; use parallel columns, not another array-of-tables syntax.
function _workflow_input_operator_tasks(table)
    _task_input_keys(table, ("quantity", "method"), "wannierization.output.operator_tasks")
    quantities = get(table, "quantity", nothing)
    quantities isa AbstractVector && !isempty(quantities) ||
        throw(ArgumentError("operator_tasks.quantity requires a nonempty array"))
    methods = get(table, "method", fill("all", length(quantities)))
    methods isa AbstractVector && length(methods) == length(quantities) ||
        throw(ArgumentError("operator_tasks columns differ in length"))
    return Tuple(
        OperatorTask(
            quantity = _task_input_symbol(q, "operator_tasks.quantity"),
            method = _task_input_symbol(m, "operator_tasks.method"),
        ) for (q, m) in zip(quantities, methods)
    )
end

# Convert one Wannierization document without reading wavefunction payloads or running a solver.
"""Resolve a workflow through cold constructors; check/explain never invokes a solve, projection or MPI."""
function resolve_workflow_input(
    document;
    base_dir = pwd(),
    input_path = "",
    input_identity = "",
    check_paths = true,
    kwargs...,
)
    workflow=get(document, "workflow", nothing)
    workflow == "mesh_screening" && return resolve_mesh_screening_input(
        document;
        base_dir,
        input_path,
        input_identity,
        check_paths,
    )
    for legacy in ("wannierization", "symmetrization")
        haskey(document, legacy) && throw(
            ArgumentError(
                "Legacy [$legacy.*] TOML has been removed. Convert explicitly to normalized input; no fields were ignored.",
            ),
        )
    end
    workflow == "wannierization" && return resolve_normalized_wannier_input(
        document;
        base_dir,
        input_path,
        input_identity,
        check_paths,
    )
    workflow == "symmetrization" && return resolve_normalized_projection_input(
        document;
        base_dir,
        input_path,
        input_identity,
        check_paths,
    )
    throw(ArgumentError("unsupported workflow=$workflow"))
end

# Persist stable absolute path leaves; original document/provenance remains unchanged.
function _workflow_absolute_paths!(table, base_dir)
    for (key, value) in table
        if value isa AbstractDict
            _workflow_absolute_paths!(value, base_dir)
        elseif value isa String && _workflow_path_field(key)
            table[key]=abspath(base_dir, value)
        elseif key == "provenance_scripts"
            table[key]=[abspath(base_dir, _task_input_string(path, key)) for path in value]
        end
    end
    return table
end

"""Run exactly the explicitly selected existing workflow and retain its original terminal qualification."""
function run_task_input(
    input::WorkflowInputResolution;
    record_directory::Union{Nothing, AbstractString} = nothing,
)
    write_records=record_directory!==nothing
    input.config isa Wannierization.WannierizationConfig ||
        write_records ||
        throw(ArgumentError("this workflow requires an explicit record_directory"))
    run_record=Dict(
        "input_file"=>get(input.metadata, "input_path", ""),
        "effective"=>input.effective,
        "explicit_keys"=>sort!([
            key for (key, value) in input.provenance if get(value, "source", "")=="USER"
        ]),
    )
    mpi = Wannierization.MPI
    deferred_root =
        input.config isa Wannierization.WannierizationConfig &&
        input.config.solver.parallel == :mpi &&
        !mpi.Initialized()
    root = !mpi.Initialized() || (!mpi.Finalized() && mpi.Comm_rank(mpi.COMM_WORLD) == 0)
    write_records &&
        !deferred_root &&
        root &&
        write_task_input_resolution(input, record_directory; actual_state = "PREPARED")
    started = time_ns()
    result=try
        if input.config isa Wannierization.WannierizationConfig
            _with_workflow_native_scratch(input) do config
                run_wannier_application(config; run_record)
            end
        elseif input.config isa Symmetrization.SymmetrizationConfig
            Symmetrization.symmetrize_wannier_operators(input.config)
        else
            throw(ArgumentError("unsupported workflow configuration"))
        end
    catch error
        report_root =
            mpi.Initialized() && !mpi.Finalized() ? mpi.Comm_rank(mpi.COMM_WORLD) == 0 :
            (!deferred_root && root)
        if report_root && write_records
            actual =
                Dict("error"=>sprint(showerror, error), "wall_seconds"=>(time_ns()-started)/1e9)
            write_task_input_resolution(input, record_directory; actual_state = "FAILED", actual)
            write_task_input_file(
                joinpath(record_directory, "run_provenance.toml"),
                Dict("input"=>input.metadata, "actual"=>actual),
            )
        end
        rethrow()
    end
    report_root =
        mpi.Initialized() && !mpi.Finalized() ? mpi.Comm_rank(mpi.COMM_WORLD) == 0 :
        (!deferred_root && root)
    if report_root && write_records
        actual = Dict(
            "qualification"=>"EXISTING_WORKFLOW_RESULT_NOT_UPGRADED",
            "workflow_result_type"=>string(typeof(result)),
            "workflow_status"=>hasproperty(result, :status) ? string(result.status) :
                               "RESULT_RETURNED_NO_STATUS_ENUM",
            "wall_seconds"=>(time_ns()-started)/1e9,
            "julia_version"=>string(VERSION),
            "julia_threads"=>Threads.nthreads(),
        )
        write_task_input_resolution(input, record_directory; actual_state = "COMPLETED", actual)
        write_task_input_file(
            joinpath(record_directory, "run_provenance.toml"),
            Dict("input"=>input.metadata, "actual"=>actual),
        )
    end
    return result
end

# Persist constructor-resolved serializable leaves; omit Nothing and constructor-only infinite sentinels.
function _workflow_input_effective_value(value)
    value === nothing && return nothing
    value isa AbstractFloat && !isfinite(value) && return nothing
    value isa Symbol && return String(value)
    value isa Union{AbstractString, Real, Bool} && return value
    value isa UnitRange && return [first(value), last(value)]
    value isa AbstractMatrix && return [collect(row) for row in eachcol(value)]
    value isa Union{AbstractVector, Tuple} &&
        return [_workflow_input_effective_value(item) for item in value]
    result=Dict{String, Any}()
    if value isa SymmetryFoundation.VASPWavefunctionSource
        result["kind"]="vasp"
    elseif value isa SymmetryFoundation.QuantumEspressoWavefunctionSource
        result["kind"]="qe"
    elseif value isa Wannierization.AbstractWannierMatrixElementSource
        names=Dict(
            Wannierization.ExternalOverlapProjectionMatrices=>"external_overlap_projection",
            Wannierization.NativeVASPPAWMatrices=>"native_vasp_paw",
            Wannierization.NativeQEPAWMatrices=>"native_qe_paw",
            Wannierization.SymmetryCompletedQEPAWMatrices=>"symmetry_completed_qe_paw",
        )
        result["kind"]=names[typeof(value)]
    else
        for (kind, T) in WORKFLOW_INPUT_KINDS
            if value isa T
                result["kind"]=kind
                break
            end
        end
    end
    for field in fieldnames(typeof(value))
        value isa Wannierization.WannierizationSolverConfig &&
            field in (:acceleration, :smv_fletcher_reeves_two_stage_audit_manifest) &&
            continue
        item=_workflow_input_effective_value(getfield(value, field))
        item === nothing || (result[string(field)]=item)
    end
    return result
end

# Record serializable constructor defaults separately from original USER expressions.
function _workflow_input_default_records!(records, table, path = "")
    for (key, value) in table
        child=isempty(path) ? key : "$path.$key"
        if value isa AbstractDict
            _workflow_input_default_records!(records, value, child)
        else
            _task_input_record!(
                records,
                child,
                value,
                "DEFAULT",
                "Existing workflow constructor",
                "Resolved serializable constructor value; explicit leaves override this origin.",
            )
        end
    end
    return records
end

# Check declared file existence without opening wavefunction matrices or running numerical preparation.
function _workflow_input_require_file(path, label)
    path === nothing && return nothing
    isfile(path) || throw(ArgumentError("$label input file does not exist: $path"))
    return nothing
end

# Native matrix providers own generated MMN/AMN; do not demand those legacy output placeholders as inputs.
function _workflow_input_check_paths(config::Wannierization.WannierizationConfig)
    input=config.input
    generated_paths=Wannierization.validate_native_operator_artifact_paths(config)
    for key in (:win_file, :eig_file, :band_representation_hdf5, :wavefunction_gauge_hdf5)
        if key == :eig_file && Wannierization.uses_generated_native_eigenvalues(input)
            Wannierization.generated_native_eigenvalue_path(input)
        else
            _workflow_input_require_file(getfield(input, key), "wannierization.input.$key")
        end
    end
    if input.matrix_elements === nothing ||
       input.matrix_elements isa Wannierization.ExternalOverlapProjectionMatrices
        for key in (:mmn_file, :amn_file)
            _workflow_input_require_file(getfield(input, key), "wannierization.input.$key")
        end
    end
    for object in (input.source, input.matrix_elements)
        object === nothing && continue
        for key in fieldnames(typeof(object))
            value=getfield(object, key)
            if key == :save_directory
                isdir(value) || throw(ArgumentError("source.save_directory does not exist: $value"))
            elseif endswith(string(key), "_file") || key == :gauge_hdf5
                _workflow_input_require_file(value, "wannierization.$key")
            end
        end
    end
    for (object, keys) in (
        (config.checkpoint, (:restart_hdf5,)),
        (config.solver, (:paw_scdm_input_hdf5,)),
        (
            config.output,
            (
                :spn_file,
                :spn_provenance_file,
                :uiu_file,
                :uhu_file,
                :siu_file,
                :shu_file,
                :uiu_provenance_json,
                :uhu_provenance_json,
                :siu_provenance_json,
                :shu_provenance_json,
            ),
        ),
    )
        for key in keys
            object === config.output && haskey(generated_paths, key) && continue
            _workflow_input_require_file(getfield(object, key), "wannierization.$key")
        end
    end
    return nothing
end

# Structural atom order is authoritative for direct Cartesian magnetic moments.
function _workflow_input_check_paths(config::Symmetrization.SymmetrizationConfig)
    for key in (:win_file, :tb_file, :chk_file, :eig_file, :mmn_file, :spn_file)
        _workflow_input_require_file(getfield(config, key), "symmetrization.input.$key")
    end
    if config.magnetic !== nothing
        _workflow_input_require_file(config.magnetic.file, "symmetrization.magnetic.file")
        moments=config.magnetic.moments_cartesian
        if moments !== nothing
            input=read_wannier_win(config.win_file)
            size(moments, 2)==length(input.species) || throw(
                ArgumentError(
                    "direct moments must have one row per WIN atom in WIN order (Cartesian mu_B)",
                ),
            )
        end
    end
    return nothing
end
