include("OpenMXTaskInput.jl")
const TASK_INPUT_SCHEMA_VERSION = "1.0"

"""A parsed request, its existing public configuration, and separately recorded value origins."""
struct TaskInputResolution
    config::Union{Nothing, TaskConfig}
    original::Dict{String, Any}
    effective::Dict{String, Any}
    provenance::Dict{String, Dict{String, Any}}
    pending::Vector{String}
    summaries::Vector{Any}
    metadata::Dict{String, Any}
end

const TASK_INPUT_PHYSICS_FIELDS = (
    ("photon_energies_ev", :photon_energies, "eV"),
    ("fermi_energy_ev", :fermi_energy, "eV"),
    ("temperature_k", :temperature, "K"),
)
const TASK_INPUT_FINITE_Q_FIELDS =
    (TASK_INPUT_PHYSICS_FIELDS..., ("photon_momentum_A_inverse", :photon_momentum, "A^-1"))
const TASK_INPUT_PAIRED_Q_FIELDS =
    (TASK_INPUT_PHYSICS_FIELDS..., ("photon_momenta_A_inverse", :photon_momenta, "A^-1"))
include("TaskInputParameters.jl")
include("TaskInputEnergyAxes.jl")

const TASK_INPUT_PATH_FIELDS = (
    :model_file,
    :real_space_operator_bundle_file,
    :wsvec_file,
    :spin_file,
    :checkpoint_file,
    :response_symmetry_file,
    :output_root,
)

const TASK_INPUT_TASK_VALUE_KEYS = (
    "kind",
    "method",
    "observable",
    "numerics",
    first.(TASK_INPUT_PHYSICS_FIELDS)...,
    "fermi_energies_ev",
    TASK_INPUT_MOMENTUM_KEYS...,
    TASK_INPUT_EXTRA_KEYS...,
)

# Normalize only the scientific task text boundary. Dict insertion/TOML source
# order never controls execution; the returned rows are private owned copies.
function _task_input_named_task_rows(response)
    response isa AbstractDict || throw(ArgumentError("response must be a TOML table"))
    raw = get(response, "tasks", Dict{String, Any}())
    raw isa AbstractDict || throw(ArgumentError("response.tasks must use named task tables."))
    ids = String[]
    for key in keys(raw)
        key isa AbstractString || throw(ArgumentError("response.tasks names must be strings"))
        push!(ids, _validate_task_id(key))
    end
    length(unique(lowercase.(ids))) == length(ids) ||
        throw(ArgumentError("response.tasks IDs must be unique ignoring case"))
    sort!(ids) # ASCII IDs: deterministic lexicographic order, independent of locale.
    rows = Dict{String, Any}[]
    for id in ids
        table = raw[id]
        table isa AbstractDict || throw(ArgumentError("response.tasks.$id must be a named table"))
        haskey(table, "id") && throw(
            ArgumentError(
                "response.tasks.$id.id is forbidden: the table name is the unique task ID",
            ),
        )
        row = Dict{String, Any}(string(k) => deepcopy(value) for (k, value) in table)
        row["id"] = id # Internal TaskSpec adapter only; never accepted/emitted in TOML.
        push!(rows, row)
    end
    return rows
end

# Reject unknown fields before resolving a table into the public configuration.
function _task_input_keys(table, allowed, location)
    table isa AbstractDict || throw(ArgumentError("$location must be a TOML table."))
    unknown = setdiff(collect(keys(table)), collect(allowed))
    (location == "response" || startswith(location, "response.tasks.")) &&
        reject_removed_third_order_measure_keys(unknown, location)
    isempty(unknown) ||
        throw(ArgumentError("$location: unknown keys $(join(sort!(string.(unknown)), ", "))."))
    return table
end

# An omitted optional section resolves to an empty table, without inventing values.
_task_input_table(table, key) = get(table, key, Dict{String, Any}())

# Record explicit leaves and reject nonfinite input before applying defaults.
function _task_input_user_leaves!(records, value, path = "")
    if value isa AbstractDict
        for (key, item) in value
            child = isempty(path) ? string(key) : "$path.$key"
            _task_input_user_leaves!(records, item, child)
        end
    elseif value isa AbstractVector && all(x -> x isa AbstractDict, value) && !isempty(value)
        for (index, item) in enumerate(value)
            _task_input_user_leaves!(records, item, "$path.$index")
        end
    else
        values = value isa AbstractVector ? value : (value,)
        any(x -> x isa AbstractFloat && !isfinite(x), values) &&
            throw(ArgumentError("$path contains a nonfinite value."))
        category =
            occursin(".numerics.", path) ? "B" :
            startswith(path, "model.") ||
            occursin(".sampling.", path) ||
            any(key -> endswith(path, ".$key"), first.(TASK_INPUT_FINITE_Q_FIELDS)) ? "C" : "A"
        _task_input_record!(records, path, value, "USER", path, "Explicit parsed input."; category)
    end
    return records
end

# Preserve the previous origin when a later resolution overrides a recorded value.
function _task_input_record!(
    records,
    path,
    value,
    source,
    origin,
    reason;
    state = "RESOLVED",
    unit = "",
    category = "A",
    api = "",
)
    record = Dict{String, Any}(
        "source" => source,
        "state" => state,
        "origin" => origin,
        "reason" => reason,
        "unit" => unit,
        "category" => category,
        "api" => api,
    )
    value === nothing || (record["value"] = deepcopy(value))
    if haskey(records, path)
        record["overrides"] = deepcopy(records[path])
    end
    records[path] = record
    return value
end

# Mark a required physical input as pending instead of supplying a numerical default.
function _task_input_missing!(pending, records, path; source = "USER", reason = "Required input.")
    push!(pending, path)
    return _task_input_record!(
        records,
        path,
        nothing,
        source,
        path,
        reason;
        state = "PENDING",
        category = "C",
    )
end

# Require a nonblank text field while preserving its original spelling.
function _task_input_string(value, path)
    value isa AbstractString || throw(ArgumentError("$path must be a string."))
    isempty(strip(value)) && throw(ArgumentError("$path must not be empty."))
    return String(value)
end

# Validate finite coordinates or positive mesh counts before public tuple construction.
function _task_input_tuple(value, path; integers = false, lengths = (1, 2, 3))
    value isa AbstractVector && length(value) in lengths ||
        throw(ArgumentError("$path must be an array of length $(join(lengths, "/"))."))
    if integers
        all(x -> x isa Integer && !(x isa Bool) && x > 0, value) ||
            throw(ArgumentError("$path requires positive integers."))
        return Tuple(Int.(value))
    end
    all(x -> x isa Real && !(x isa Bool) && isfinite(x), value) ||
        throw(ArgumentError("$path requires finite real values."))
    return Tuple(Float64.(value))
end

# Constructor defaults are obtained from the current API object, never copied
# into a second numerical-default table.
function _task_input_options(
    table,
    defaults,
    location,
    records,
    base_dir;
    aliases = Dict{String, Symbol}(),
    excluded = (),
)
    names = setdiff(collect(fieldnames(typeof(defaults))), collect(excluded))
    mapping = Dict(string(name) => name for name in names)
    for (key, field) in aliases
        delete!(mapping, string(field))
        mapping[key] = field
    end
    _task_input_keys(table, keys(mapping), location)
    values = Dict{Symbol, Any}()
    effective = Dict{String, Any}()
    for (key, field) in mapping
        explicit = haskey(table, key)
        value = explicit ? deepcopy(table[key]) : deepcopy(getfield(defaults, field))
        path = "$location.$key"
        if value !== nothing
            field_type = fieldtype(typeof(defaults), field)
            if field in (:NKdiv, :NKFFT, :mp_grid)
                value = _task_input_tuple(
                    collect(value),
                    path;
                    integers = true,
                    lengths = field == :mp_grid ? (3,) : (1, 2, 3),
                )
            elseif !(value isa field_type)
                field_type == Float64 && value isa Real && !(value isa Bool) ?
                (value = Float64(value)) : throw(ArgumentError("$path requires $field_type."))
            end
            value isa AbstractFloat &&
                !isfinite(value) &&
                throw(ArgumentError("$path must be finite."))
            if field in TASK_INPUT_PATH_FIELDS && value isa AbstractString && !isempty(value)
                value = abspath(base_dir, value)
            end
            effective[key] = value
        end
        _task_input_record!(
            records,
            path,
            value,
            explicit ? "USER" : "DEFAULT",
            explicit ? path : "$(typeof(defaults)).$field",
            explicit ? "Explicit input; relative paths resolve against the input directory." :
            "Current public constructor default.",
            api = "$(typeof(defaults)).$field",
        )
        values[field] = value
    end
    return values, effective
end

# Require upstream origin/unit; an omitted state is RESOLVED and PENDING stays unresolved.
function _task_input_inherited(inherited, key, unit, records, pending, path)
    if !haskey(inherited, key)
        return _task_input_missing!(pending, records, path)
    end
    entry = inherited[key]
    _task_input_keys(entry, ("value", "origin", "unit", "state"), "inherited.$key")
    origin = _task_input_string(get(entry, "origin", ""), "inherited.$key.origin")
    get(entry, "unit", "") == unit ||
        throw(ArgumentError("inherited.$key must explicitly declare unit $unit."))
    state = get(entry, "state", "RESOLVED")
    state in ("RESOLVED", "PENDING") || throw(ArgumentError("Invalid inherited state."))
    value = get(entry, "value", nothing)
    if state == "PENDING" || value === nothing
        push!(pending, path)
        return _task_input_record!(
            records,
            path,
            nothing,
            "INHERITED",
            origin,
            "Waiting for accepted upstream value.";
            state = "PENDING",
            unit,
            category = "C",
        )
    end
    return _task_input_record!(
        records,
        path,
        value,
        "INHERITED",
        origin,
        "Trusted caller-supplied upstream metadata.";
        unit,
        category = "C",
    )
end

# Resolve task overrides, shared response values and inherited physical inputs in order.
function _task_input_physics(task, response, inherited, keys, prefix, records, pending)
    values = Dict{Symbol, Any}()
    effective = Dict{String, Any}()
    for (key, api, unit) in keys
        path = "$prefix.$key"
        axis_origin = haskey(task, key) ? path : "response.$key"
        expanded_axis =
            haskey(records, axis_origin) && get(records[axis_origin], "axis_expanded", false)
        value = if haskey(task, key)
            if haskey(response, key)
                _task_input_record!(
                    records,
                    path,
                    response[key],
                    "USER",
                    "response.$key",
                    "Shared response value overridden for this task.";
                    unit,
                    category = "C",
                )
            end
            _task_input_record!(
                records,
                path,
                task[key],
                "USER",
                path,
                "Task override on a frozen model; occupation changes are not a new SCF.";
                unit,
                category = "C",
                api = string(api),
            )
        elseif haskey(response, key)
            _task_input_record!(
                records,
                path,
                response[key],
                "USER",
                "response.$key",
                "Explicit shared response value.";
                unit,
                category = "C",
                api = string(api),
            )
        else
            _task_input_inherited(inherited, key, unit, records, pending, path)
        end
        if value !== nothing
            if api in (:photon_energies, :fermi_energies)
                value isa AbstractVector &&
                all(x -> x isa Real && !(x isa Bool) && isfinite(x), value) ||
                    throw(ArgumentError("$path requires an array of finite energies in eV."))
                value = Float64.(value)
                all(isfinite, value) || throw(ArgumentError("$path must remain finite in Float64."))
            elseif api == :photon_momentum
                value = _task_input_tuple(value, path; lengths = (3,))
                all(isfinite, value) ||
                    throw(ArgumentError("$path must be representable in Float64."))
            elseif api == :photon_momenta
                value isa AbstractVector && !isempty(value) || throw(
                    ArgumentError("$path requires a nonempty array of Cartesian three-vectors"),
                )
                value = NTuple{3, Float64}[_copy_photon_path_momentum(q) for q in value]
            else
                value isa Real && !(value isa Bool) && isfinite(value) ||
                    throw(ArgumentError("$path requires a finite real value in $unit."))
                value = Float64(value)
                isfinite(value) || throw(ArgumentError("$path must remain finite in Float64."))
            end
            values[api] = value
            effective[key] = api == :photon_momentum ? collect(value) : value
            origin = haskey(task, key) ? path : "response.$key"
            if expanded_axis
                records[path]["source"] = "DERIVED"
                records[path]["origin"] = origin
                records[path]["axis_expanded"] = true
            end
            records[path]["resolved_value"] = deepcopy(value)
        end
    end
    return values, effective
end

# Build existing public sampling types from explicit geometry and mesh counts.
function _task_input_sampling(table, records, pending; base_dir = pwd(), model = nothing)
    get(table, "kind", "") == "k_path" &&
        return _task_input_band_sampling(table, records, pending, base_dir, model)
    _task_input_keys(
        table,
        (
            "kind",
            "k_mesh",
            "spatial_dimension",
            "origin",
            "vector_1",
            "vector_2",
            "vector_3",
            "lower",
            "upper",
        ),
        "response.sampling",
    )
    if haskey(table, "kind")
        _task_input_string(table["kind"], "response.sampling.kind") in
        ("bz_mesh", "k_slice", "k_region") ||
            throw(ArgumentError("Unknown response sampling kind."))
    end
    if haskey(table, "spatial_dimension")
        dimension = table["spatial_dimension"]
        dimension isa Integer && !(dimension isa Bool) && dimension in 1:3 ||
            throw(ArgumentError("response.sampling.spatial_dimension must be 1, 2 or 3."))
    end
    haskey(table, "k_mesh") &&
        _task_input_tuple(table["k_mesh"], "response.sampling.k_mesh"; integers = true)
    required = ("kind", "k_mesh", "spatial_dimension")
    for key in required
        haskey(table, key) || _task_input_missing!(pending, records, "response.sampling.$key")
    end
    all(key -> haskey(table, key), required) || return nothing, deepcopy(table)
    kind = _task_input_string(table["kind"], "response.sampling.kind")
    dimension = table["spatial_dimension"]
    dimension isa Integer && !(dimension isa Bool) && dimension in 1:3 ||
        throw(ArgumentError("response.sampling.spatial_dimension must be 1, 2 or 3."))
    mesh = _task_input_tuple(table["k_mesh"], "response.sampling.k_mesh"; integers = true)
    if kind == "bz_mesh"
        extras =
            intersect(keys(table), ("origin", "vector_1", "vector_2", "vector_3", "lower", "upper"))
        isempty(extras) ||
            throw(ArgumentError("BZMesh does not accept region bounds or slice vectors."))
        sampling = BZMesh(; k_mesh = mesh, spatial_dimension = dimension)
    elseif kind == "k_slice"
        isempty(intersect(keys(table), ("lower", "upper", "vector_3"))) ||
            throw(ArgumentError("KSlice does not accept Cartesian region bounds."))
        for key in ("origin", "vector_1", "vector_2")
            haskey(table, key) || _task_input_missing!(pending, records, "response.sampling.$key")
        end
        all(key -> haskey(table, key), ("origin", "vector_1", "vector_2")) ||
            return nothing, deepcopy(table)
        length(mesh) == 2 || throw(ArgumentError("KSlice requires two mesh counts."))
        sampling = KSlice(;
            k_mesh = mesh,
            spatial_dimension = dimension,
            origin = _task_input_tuple(table["origin"], "slice origin"; lengths = (2, 3)),
            vector_1 = _task_input_tuple(table["vector_1"], "slice vector_1"; lengths = (2, 3)),
            vector_2 = _task_input_tuple(table["vector_2"], "slice vector_2"; lengths = (2, 3)),
        )
    elseif kind == "k_region"
        affine = any(key -> haskey(table, key), ("origin", "vector_1", "vector_2", "vector_3"))
        geometry_keys =
            affine ?
            (
                dimension == 3 ? ("origin", "vector_1", "vector_2", "vector_3") :
                ("origin", "vector_1", "vector_2")
            ) : ("lower", "upper")
        affine &&
            any(key -> haskey(table, key), ("lower", "upper")) &&
            throw(ArgumentError("KRegion requires either box bounds or affine vectors."))
        for key in geometry_keys
            haskey(table, key) || _task_input_missing!(pending, records, "response.sampling.$key")
        end
        all(key -> haskey(table, key), geometry_keys) || return nothing, deepcopy(table)
        if affine
            dimension in (2, 3) ||
                throw(ArgumentError("affine integration dimension must be two or three"))
            haskey(table, "vector_3") &&
                dimension != 3 &&
                throw(ArgumentError("vector_3 requires physical integration dimension three"))
            sampling = KRegion(;
                origin = _task_input_tuple(table["origin"], "region origin"; lengths = (2, 3)),
                vector_1 = _task_input_tuple(
                    table["vector_1"],
                    "region vector_1";
                    lengths = (2, 3),
                ),
                vector_2 = _task_input_tuple(
                    table["vector_2"],
                    "region vector_2";
                    lengths = (2, 3),
                ),
                vector_3 = dimension == 3 ?
                           _task_input_tuple(table["vector_3"], "region vector_3"; lengths = (3,)) : nothing,
                k_mesh = mesh,
            )
        else
            length(mesh) == dimension || throw(DimensionMismatch("box mesh and physical dimension"))
            sampling = KRegion(;
                lower = _task_input_tuple(table["lower"], "region lower"; lengths = (dimension,)),
                upper = _task_input_tuple(table["upper"], "region upper"; lengths = (dimension,)),
                k_mesh = mesh,
            )
        end
    else
        throw(ArgumentError("Text sampling supports bz_mesh, k_slice and k_region."))
    end
    for (key, value) in table
        _task_input_record!(
            records,
            "response.sampling.$key",
            value,
            "USER",
            "response.sampling.$key",
            "Explicit physical sampling geometry.";
            category = "C",
            unit = sampling isa KRegion &&
                   key in ("origin", "vector_1", "vector_2", "vector_3", "lower", "upper") ?
                   "A^-1" : "",
        )
    end
    if sampling isa KRegion
        area =
            sampling.affine_region === nothing ?
            prod(sampling.upper[a] - sampling.lower[a] for a in 1:sampling.spatial_dimension) :
            sampling.affine_region.measure
        dimension = sampling.spatial_dimension
        for (key, value, unit) in (
            (
                "geometry",
                sampling.affine_region === nothing ? "Cartesian box" :
                sampling.spatial_dimension == 2 ? "Cartesian parallelogram" :
                "Cartesian parallelepiped",
                "",
            ),
            ("coordinates", "Cartesian; unfolded", "A^-1"),
            ("grid", "uniform midpoint; no duplicated boundary", ""),
            ("nsamples", prod(sampling.k_mesh), ""),
            ("domain_measure", area, "A^-$dimension"),
            ("point_weight", area/prod(sampling.k_mesh), "A^-$dimension"),
        )
            _task_input_record!(
                records,
                "response.sampling.$key",
                value,
                "DERIVED",
                "KRegion geometry",
                "Derived from the declared geometry and mesh; not an extra input.";
                unit,
                category = "C",
            )
        end
    end
    return sampling, deepcopy(table)
end

# Map the text selector to the existing public tensor and band-selection types.
function _task_input_observable(table, sampling, quantity = nothing)
    sampling isa Union{BZMesh, KRegion} && begin
        kind = get(table, "kind", "full_tensor")
        if kind == "tensor_components"
            _task_input_keys(table, ("kind", "components"), "observable")
            components = get(table, "components", [])
            components isa AbstractVector ||
                throw(ArgumentError("observable.components must be an array."))
            definition =
                quantity === nothing ? nothing : task_definition(quantity, :conventional, :integral)
            rank = definition === nothing ? 4 : Int(definition.tensor_rank)
            return TensorComponents([
                _task_input_tuple(c, "observable.components"; integers = true, lengths = (rank,)) for c in components
            ])
        end
        kind == "full_tensor" || throw(
            ArgumentError("Integral observable requires full_tensor or tensor_components."),
        )
        _task_input_keys(table, ("kind",), "observable")
        return FullTensor()
    end
    _task_input_keys(
        table,
        (
            "kind",
            "component",
            "bands",
            "groups",
            "include_occupied_sum",
            "conduction",
            "valence",
            "first",
            "second",
            "third",
        ),
        "observable",
    )
    kind = get(table, "kind", "")
    haskey(table, "component") || throw(ArgumentError("KSlice requires observable.component."))
    component = TensorComponent(
        _task_input_tuple(
            table["component"],
            "observable.component";
            integers = true,
            lengths = (1, 2, 3, 4),
        )...,
    )
    for key in ("bands", "conduction", "valence", "first", "second", "third")
        haskey(table, key) || continue
        value = table[key]
        value isa AbstractVector && all(x -> x isa Integer && !(x isa Bool) && x > 0, value) ||
            throw(ArgumentError("observable.$key requires positive integer band indices."))
    end
    if haskey(table, "groups")
        groups = table["groups"]
        groups isa AbstractVector && all(
            group ->
                group isa AbstractVector &&
                all(x -> x isa Integer && !(x isa Bool) && x > 0, group),
            groups,
        ) || throw(ArgumentError("observable.groups requires arrays of positive integer bands."))
    end
    haskey(table, "include_occupied_sum") &&
        !(table["include_occupied_sum"] isa Bool) &&
        throw(ArgumentError("observable.include_occupied_sum must be Bool."))
    selection = if kind == "band_targets"
        BandTargets(
            get(table, "bands", Int[]);
            include_occupied_sum = get(table, "include_occupied_sum", false),
        )
    elseif kind == "subspace"
        Subspace(get(table, "bands", Int[]))
    elseif kind == "subspaces"
        Subspaces(get(table, "groups", []))
    elseif kind == "occupied_bands"
        OccupiedBands()
    elseif kind == "all_bands"
        AllBands(; include_occupied_sum = get(table, "include_occupied_sum", false))
    elseif kind == "transition"
        Transition(;
            conduction = get(table, "conduction", Int[]),
            valence = get(table, "valence", Int[]),
        )
    elseif kind == "interband_groups"
        InterbandGroups(; first = get(table, "first", Int[]), second = get(table, "second", Int[]))
    elseif kind == "triple_groups"
        TripleGroups(;
            first = get(table, "first", Int[]),
            second = get(table, "second", Int[]),
            third = get(table, "third", Int[]),
        )
    else
        throw(ArgumentError("Unsupported text band observation $kind."))
    end
    allowed =
        kind == "band_targets" ? ("kind", "component", "bands", "include_occupied_sum") :
        kind == "subspace" ? ("kind", "component", "bands") :
        kind == "subspaces" ? ("kind", "component", "groups") :
        kind == "all_bands" ? ("kind", "component", "include_occupied_sum") :
        kind == "transition" ? ("kind", "component", "conduction", "valence") :
        kind == "interband_groups" ? ("kind", "component", "first", "second") :
        kind == "triple_groups" ? ("kind", "component", "first", "second", "third") :
        ("kind", "component")
    _task_input_keys(table, allowed, "observable.$kind")
    return KSliceSelection(; component, bands = selection)
end

"""Resolve TOML values through existing constructors and registry; perform no integration or MPI init.

The caller may supply an existing native model with source=julia. Trusted
inherited physical metadata must carry value, origin, unit and resolution state.
Julia callbacks are intentionally not advertised as file-replayable models.
"""
function resolve_task_input(
    document::AbstractDict;
    base_dir::AbstractString = pwd(),
    model::Union{Nothing, AbstractNativeModelInput} = nothing,
    inherited::AbstractDict = Dict{String, Any}(),
    input_path = "",
    input_identity = "",
    check_paths::Bool = true,
)
    for legacy in ("wannierization", "symmetrization")
        haskey(document, legacy) && throw(
            ArgumentError(
                "Legacy [$legacy.*] TOML has been removed. Use the explicit migration tool and normalized input.",
            ),
        )
    end
    haskey(document, "workflow") &&
        return resolve_workflow_input(document; base_dir, input_path, input_identity, check_paths)
    original = Dict{String, Any}(string(k) => deepcopy(v) for (k, v) in document)
    _task_input_keys(original, ("model", "response", "output"), "input")
    records = Dict{String, Dict{String, Any}}()
    _task_input_user_leaves!(records, original)
    pending = String[]
    metadata = Dict{String, Any}(
        "schema_version" => TASK_INPUT_SCHEMA_VERSION,
        "provenance_schema" => "wanniernlqg.task-input-provenance/3.0",
        "package_version" => string(Base.pkgversion(parentmodule(@__MODULE__))),
        "input_path" => input_path,
        "input_identity" => isempty(input_identity) ? "OWNED_PARSED_DOCUMENT" : input_identity,
        "input_identity_kind" =>
            isempty(input_identity) ? "OWNED_PARSED_DOCUMENT" : "OBSERVED_FILE_STATE",
        "validation_scope" => "CONFIGURATION_AND_DECLARED_MODEL_METADATA",
        "scientific_qualification" => "NOT_ESTABLISHED",
        "source_identity" => "NOT_AUDITED_BY_ORDINARY_INPUT_READER",
    )
    response = deepcopy(_task_input_table(original, "response"))
    task_tables = _task_input_named_task_rows(response)
    task_ids = String[row["id"] for row in task_tables]
    metadata["task_ids_in_execution_order"] = copy(task_ids)
    metadata["task_ordering_rule"] = "ASCII_ID_LEXICOGRAPHIC"

    _task_input_expand_axes!(response, "response", records)
    _task_input_explicit_numerics(_task_input_table(response, "numerics"), "response.numerics")
    _task_input_explicit_selectors(response, "response")
    _task_input_momentum_source(response, Dict{String, Any}(), "response", records)
    momentum_tables = Dict{String, Any}()
    # A local q group does not hide a malformed shared CSV source; pair it only with actual task energies later.
    if check_paths && haskey(response, "photon_momentum_table_file")
        path = abspath(base_dir, response["photon_momentum_table_file"])
        momentum_tables[path] = read_photon_momentum_table(path)
    end
    for (index, row) in enumerate(task_tables)
        row isa AbstractDict || throw(ArgumentError("response.tasks requires tables"))
        _task_input_expand_axes!(row, "response.tasks.$(task_ids[index])", records)
        prefix = "response.tasks.$(task_ids[index])"
        _task_input_explicit_numerics(_task_input_table(row, "numerics"), "$prefix.numerics")
        _task_input_explicit_selectors(row, prefix)
    end
    physics_keys =
        (first.(TASK_INPUT_PHYSICS_FIELDS)..., "fermi_energies_ev", TASK_INPUT_MOMENTUM_KEYS...)
    _task_input_keys(
        response,
        (
            "tasks",
            "sampling",
            "execution",
            "numerics",
            "energy_zero",
            physics_keys...,
            TASK_INPUT_EXTRA_KEYS...,
        ),
        "response",
    )
    energy_zero = if haskey(response, "energy_zero")
        _task_input_record!(
            records,
            "response.energy_zero",
            _task_input_string(response["energy_zero"], "response.energy_zero"),
            "USER",
            "response.energy_zero",
            "Explicit energy reference of this frozen model.";
            category = "C",
            unit = "eV reference",
        )
    else
        nothing
    end
    energy_zero === nothing || _task_input_string(energy_zero, "response.energy_zero")
    execution_table = _task_input_table(response, "execution")
    _task_input_keys(
        execution_table,
        (
            "fourier_backend",
            "integration_algorithm",
            "nkdiv",
            "nkfft",
            "response_symmetry_file",
            "response_symmetry_policy",
            "response_symmetry_kmesh_mode",
            "response_symmetry_report_enabled",
        ),
        "response.execution",
    )
    backend_explicit = haskey(execution_table, "fourier_backend")
    backend = get(execution_table, "fourier_backend", "auto")
    _task_input_string(backend, "response.execution.fourier_backend")
    _task_input_record!(
        records,
        "response.execution.fourier_backend",
        backend,
        backend_explicit ? "USER" : "DEFAULT",
        "response.execution.fourier_backend",
        backend_explicit ? "Explicit backend request." : "Default automatic backend request.",
    )
    rows = task_tables
    direct_only =
        !isempty(rows) && all(
            row ->
                row isa AbstractDict &&
                haskey(row, "kind") &&
                normalize_quantity(row["kind"]) == :band_structure,
            rows,
        )
    paired_request = any(
        key -> haskey(response, key) || any(row -> haskey(row, key), rows),
        ("photon_momenta_A_inverse", "photon_momentum_enhancement", "photon_momentum_table_file"),
    )
    if Symbol(_canonical_key(backend)) == :auto && (direct_only || paired_request)
        backend = "direct"
        _task_input_record!(
            records,
            "response.execution.fourier_backend",
            backend,
            "DERIVED",
            "Registered execution capability",
            "This path currently has only Direct evaluation; automatic selection resolves to Direct.",
        )
    end
    # The placeholder is used solely to read unrelated constructor defaults; no
    # placeholder backend enters a resolved TaskConfig.
    execution_defaults = ExecutionOptions(; fourier_backend = something(backend, "direct"))
    execution_values, execution_effective = _task_input_options(
        Dict(
            k => v for
            (k, v) in execution_table if !(k in ("integration_algorithm", "fourier_backend"))
        ),
        execution_defaults,
        "response.execution",
        records,
        abspath(base_dir);
        aliases = Dict("nkdiv" => :NKdiv, "nkfft" => :NKFFT),
        excluded = (:integration_algorithm, :fourier_backend),
    )
    integration_value = get(execution_table, "integration_algorithm", "uniform")
    integration, integration_effective = _task_input_integration(integration_value, records)
    _task_input_record!(
        records,
        "response.execution.integration_algorithm",
        integration_effective,
        haskey(execution_table, "integration_algorithm") ? "USER" : "DEFAULT",
        "ExecutionOptions.integration_algorithm",
        "Existing integration constructor.",
    )
    execution_effective["integration_algorithm"] = integration_effective
    execution = ExecutionOptions(;
        fourier_backend = backend,
        integration_algorithm = integration,
        execution_values...,
    )
    if backend !== nothing
        execution_effective["fourier_backend"] = backend
        _task_input_record!(
            records,
            "response.execution.fourier_backend",
            backend,
            get(records["response.execution.fourier_backend"], "source", "USER"),
            "response.execution.fourier_backend",
            "Resolved existing backend selection.",
        )
    end
    if backend !== nothing && Symbol(_canonical_key(backend)) == :auto
        _task_input_record!(
            records,
            "response.execution.fourier_backend",
            backend,
            backend_explicit ? "USER" : "DEFAULT",
            "response.execution.fourier_backend",
            "Actual backend depends on loaded model and execution layout.";
            state = "PENDING",
        )
        metadata["runtime_pending"] = ["response.execution.fourier_backend"]
    end
    output_values, output_effective = _task_input_options(
        _task_input_table(original, "output"),
        OutputOptions(),
        "output",
        records,
        abspath(base_dir),
    )
    output = OutputOptions(; output_values...)
    model_table = _task_input_table(original, "model")
    source = get(model_table, "source", nothing)
    _task_input_keys(
        model_table,
        source == "openmx" ? _OPENMX_TEXT_KEYS :
        ("source", "identity", string.(fieldnames(ModelInput))...),
        "model",
    )
    source = get(model_table, "source", nothing)
    source === nothing && _task_input_missing!(pending, records, "model.source")
    model_effective = Dict{String, Any}()
    model_input = nothing
    if source == "wannier"
        model === nothing || throw(ArgumentError("A Julia model cannot override source=wannier."))
        model_values, model_effective = _task_input_options(
            Dict(k => v for (k, v) in model_table if k != "source"),
            ModelInput(),
            "model",
            records,
            abspath(base_dir),
        )
        root = get(model_values, :case_root, "")
        root = isempty(root) ? abspath(base_dir) : abspath(base_dir, root)
        model_values[:case_root] = root
        model_effective["case_root"] = root
        _task_input_record!(
            records,
            "model.case_root",
            root,
            haskey(model_table, "case_root") ? "USER" : "DERIVED",
            "input directory",
            "Text relative paths resolve against the input file directory.",
        )
        if !isempty(model_values[:seedname])
            model_values[:seedname] = abspath(base_dir, model_values[:seedname])
            model_effective["seedname"] = model_values[:seedname]
        end
        model_input = ModelInput(; model_values...)
        if isempty(model_input.model_file) &&
           isempty(model_input.seedname) &&
           (
               model_input.real_space_operator_bundle_file === nothing ||
               isempty(model_input.real_space_operator_bundle_file)
           )
            _task_input_missing!(
                pending,
                records,
                "model.model_file",
                reason = "Supply model_file, seedname or real_space_operator_bundle_file.",
            )
        end
        metadata["model_replay"] = "FILE_INPUT"
    elseif source == "openmx"
        model_input, model_effective =
            _task_input_openmx(model_table, records, pending, abspath(base_dir); model)
        metadata["model_replay"] = "FILE_INPUT"
        metadata["native_file_loader"] = "read_openmx_localized_input"
    elseif source == "julia"
        _task_input_keys(model_table, ("source", "identity"), "model")
        haskey(model_table, "identity") || _task_input_missing!(pending, records, "model.identity")
        if haskey(model_table, "identity")
            identity = _task_input_string(model_table["identity"], "model.identity")
            _task_input_record!(
                records,
                "model.identity",
                identity,
                "USER",
                "model.identity",
                "Caller-declared Julia model entry identity; no file replay.";
                category = "C",
            )
        end
        model === nothing && _task_input_missing!(
            pending,
            records,
            "model.payload";
            source = "INHERITED",
            reason = "Caller must supply an existing AbstractNativeModelInput.",
        )
        model_input = model
        model_effective = deepcopy(model_table)
        metadata["model_replay"] = "REQUIRES_JULIA_MODEL_ENTRY_NOT_FILE_REPLAYABLE"
        if native_physical_dimension(model) < 3
            d = native_physical_dimension(model)
            metadata["native_physical_geometry"] = Dict(
                "physical_dimension" => d,
                "origin" => "DERIVED_FROM_PHYSICAL_MODEL_INPUT",
                "auxiliary_length_angstrom" => 1.0,
                "orientation" => "standard Cartesian axes; no auxiliary sampling or periodicity",
                "coefficient_normalization" => "completed three-dimensional reference cell",
            )
        end
        if model isa NonorthogonalLocalizedInput
            diagnostics = model.model.representation_diagnostics
            metadata["native_representation"] = Dict(
                "reporting_warning" => diagnostics.exceeds_reporting_tolerance,
                "raw_file_modified" => diagnostics.raw_file_modified,
                "raw" => diagnostics.raw,
                "effective" => diagnostics.effective,
                "adjustment" => diagnostics.adjustment,
                "scheme" => diagnostics.scheme,
            )
        end
    elseif source !== nothing
        throw(
            ArgumentError(
                "Independent text model source must be wannier, openmx or julia; no SCF execution is performed.",
            ),
        )
    end
    source === nothing || begin
        model_effective["source"] = source
        _task_input_record!(
            records,
            "model.source",
            source,
            "USER",
            "model.source",
            "Explicit model provider.";
            category = "C",
        )
    end
    if !haskey(_task_input_table(original, "output"), "system_name") && model_input !== nothing
        actual_source = if source == "openmx"
            get(model_effective, "model_file", "")
        elseif source == "wannier"
            bundle = model_input.real_space_operator_bundle_file
            bundle !== nothing && !isempty(bundle) ? bundle :
            !isempty(model_input.model_file) ? model_input.model_file : model_input.seedname
        else
            get(model_table, "identity", "")
        end
        stem = splitext(basename(actual_source))[1]
        stem = replace(stem, r"_tb$" => "", r"[^\p{L}\p{N}_.-]" => "_")
        if !isempty(stem) && !(stem in (".", ".."))
            output_values[:system_name] = stem
            output_effective["system_name"] = stem
            output = OutputOptions(; output_values...)
            _task_input_record!(
                records,
                "output.system_name",
                stem,
                "DERIVED",
                "Actual model source",
                "Output prefix derived from the declared computational model source.",
            )
        end
    end
    sampling_table = _task_input_table(response, "sampling")
    task_rows = task_tables
    if !haskey(sampling_table, "kind") &&
       !isempty(task_rows) &&
       all(
           table ->
               table isa AbstractDict &&
               haskey(table, "kind") &&
               normalize_quantity(table["kind"]) == :band_structure,
           task_rows,
       )
        sampling_table = merge(Dict{String, Any}(sampling_table), Dict("kind" => "k_path"))
    end
    if !haskey(sampling_table, "kind") &&
       !isempty(task_rows) &&
       isempty(
           intersect(
               keys(sampling_table),
               (
                   "origin",
                   "vector_1",
                   "vector_2",
                   "lower",
                   "upper",
                   "nodes",
                   "structure",
                   "structure_file",
               ),
           ),
       ) &&
       all(task_rows) do row
           row isa AbstractDict && haskey(row, "kind") || return false
           quantity = normalize_quantity(row["kind"])
           label = quantity_short_label_definition(row["kind"])
           label === nothing || calculation_symbol(label.calculation) == :integral || return false
           return any(
               definition ->
                   quantity_symbol(definition.quantity) == quantity &&
                   calculation_symbol(definition.calculation) == :integral,
               TASK_DEFINITIONS,
           )
       end
        sampling_table = merge(Dict{String, Any}(sampling_table), Dict("kind" => "bz_mesh"))
    end
    if get(sampling_table, "kind", "") == "k_slice"
        dimension = get(sampling_table, "spatial_dimension", 3)
        dimension isa Integer && !(dimension isa Bool) && dimension in 1:3 ||
            throw(ArgumentError("response.sampling.spatial_dimension must be 1, 2 or 3."))
        for row in task_rows
            component = get(get(row, "observable", Dict()), "component", [])
            if component isa AbstractVector &&
               all(axis -> axis isa Integer && !(axis isa Bool), component)
                dimension = max(dimension, maximum(component; init = 1))
            end
        end
        sampling_table =
            merge(Dict{String, Any}(sampling_table), Dict("spatial_dimension" => dimension))
    end
    sampling, sampling_effective =
        _task_input_sampling(sampling_table, records, pending; base_dir, model = model_input)
    declared_sampling = _task_input_table(response, "sampling")
    for key in ("kind", "spatial_dimension")
        if haskey(sampling_effective, key) && !haskey(declared_sampling, key)
            _task_input_record!(
                records,
                "response.sampling.$key",
                sampling_effective[key],
                "DEFAULT",
                "Registered task sampling capability",
                "Default sampling control; physical mesh and geometry remain explicit.",
            )
        elseif haskey(sampling_effective, key) &&
               haskey(declared_sampling, key) &&
               sampling_effective[key] != declared_sampling[key]
            _task_input_record!(
                records,
                "response.sampling.$key",
                sampling_effective[key],
                "DERIVED",
                "Selected tensor component",
                "Selected component determines the required Cartesian axis bounds.",
            )
        end
    end
    sampling isa KPath && (metadata["band_path_provenance"] = deepcopy(sampling.provenance))
    # task_tables was validated before axis expansion or model loading.
    isempty(task_tables) && _task_input_missing!(pending, records, "response.tasks")
    if any(key -> haskey(response, key), TASK_INPUT_MOMENTUM_KEYS)
        any(
            table ->
                table isa AbstractDict &&
                haskey(table, "kind") &&
                normalize_quantity(table["kind"]) in (
                    :photon_drag_shift_current,
                    :photon_drag_injection_current,
                    :shift_vector,
                    :quantum_hermitian_connection,
                ),
            task_tables,
        ) || throw(ArgumentError("shared photon momentum requires an applicable finite-q task"))
    end
    shared_numerics = _task_input_table(response, "numerics")
    shared_momentum_used = false
    applicable_shared = Set{String}()
    tasks = TaskSpec[]
    task_effective = Any[]
    for (index, table) in enumerate(task_tables)
        prefix = "response.tasks.$(task_ids[index])"
        _task_input_keys(table, ("id", TASK_INPUT_TASK_VALUE_KEYS...), prefix)
        for key in ("id", "kind")
            haskey(table, key) || throw(ArgumentError("$prefix.$key is required."))
            _task_input_string(table[key], "$prefix.$key")
        end
        quantity = normalize_quantity(table["kind"])
        if quantity == :intrinsic_ahc && haskey(table, "fermi_energy_ev")
            haskey(table, "fermi_energies_ev") &&
                throw(ArgumentError("$prefix supplies both scalar and vector Fermi energies"))
            table["fermi_energies_ev"]=[table["fermi_energy_ev"]]
            delete!(table, "fermi_energy_ev")
            _task_input_record!(
                records,
                "$prefix.fermi_energies_ev",
                table["fermi_energies_ev"],
                "DERIVED",
                "$prefix.fermi_energy_ev",
                "Static AHC single-energy axis.",
            )
        end
        method = get(table, "method", nothing)
        if method !== nothing
            _task_input_string(method, "$prefix.method")
            normalize_method(method)
        end
        if sampling !== nothing
            calculation = _sampling_calculation(sampling)
            validate_quantity_short_label_calculation(table["kind"], quantity, calculation)
            selected = if method === nothing
                task_definition(quantity, :conventional, calculation) === nothing ?
                infer_single_supported_method(quantity, calculation) : :conventional
            else
                normalize_method(method)
            end
            if method === nothing
                method = canonical_method_name(selected)
                _task_input_record!(
                    records,
                    "$prefix.method",
                    method,
                    "DEFAULT",
                    "TaskRegistry",
                    "Registered Conventional method, or the unique supported method.",
                )
            end
            task_definition(quantity, selected, calculation) === nothing &&
                select_task(quantity, selected, calculation)
        end
        observation_table = _task_input_table(table, "observable")
        observation = if quantity == :band_structure
            isempty(observation_table) ||
                throw(ArgumentError("Band tasks do not accept response observables"))
            nothing
        else
            sampling === nothing ? nothing :
            _task_input_observable(observation_table, sampling, quantity)
        end
        finite_q = quantity in (:photon_drag_shift_current, :photon_drag_injection_current)
        geometric_q_capable =
            _task_input_parameter_type(quantity) == GeometryParameters &&
            method !== nothing &&
            normalize_method(method) == :geometric_loop &&
            quantity == :shift_vector
        momentum_response = finite_q || geometric_q_capable ? response : Dict{String, Any}()
        momentum_values, derived_q =
            _task_input_momentum_source(table, momentum_response, prefix, records)
        shared_momentum_used |= !isempty(momentum_values) && (finite_q || geometric_q_capable)
        paired_q = haskey(momentum_values, "photon_momenta_A_inverse") || derived_q
        fixed_q = haskey(momentum_values, "photon_momentum_A_inverse")
        if !finite_q && (paired_q || haskey(table, "photon_momentum_direction"))
            throw(
                ArgumentError(
                    "$prefix: paired/enhancement/table momentum applies only to photon-drag tasks.",
                ),
            )
        end
        physical_keys = _task_input_required_fields(quantity, observation, paired_q)
        geometry_q =
            _task_input_parameter_type(quantity) == GeometryParameters &&
            fixed_q &&
            geometric_q_capable &&
            quantity == :shift_vector
        geometry_q && (physical_keys = (physical_keys..., TASK_INPUT_FINITE_Q_FIELDS[end]))
        # Reject irrelevant physical axes instead of silently dropping them.
        allowed_physics = (
            first.(physical_keys)...,
            (
                derived_q ?
                (
                    "photon_momentum_enhancement",
                    "photon_momentum_direction",
                    "photon_momentum_table_file",
                ) : ()
            )...,
        )
        union!(applicable_shared, first.(physical_keys))
        resolution_fields = derived_q ? TASK_INPUT_PHYSICS_FIELDS : physical_keys
        for key in physics_keys
            haskey(table, key) &&
                !(key in allowed_physics) &&
                throw(ArgumentError("$prefix.$key is not used by this observation."))
        end
        physical, physical_effective = _task_input_physics(
            table,
            response,
            inherited,
            resolution_fields,
            prefix,
            records,
            pending,
        )
        if derived_q && haskey(physical, :photon_energies)
            physical[:photon_momenta] = _task_input_derived_momenta(
                momentum_values,
                physical[:photon_energies],
                prefix,
                records,
                metadata,
                base_dir,
                momentum_tables,
            )
            physical_effective["photon_momenta_A_inverse"] =
                [collect(q) for q in physical[:photon_momenta]]
        end
        parameter_type, controls, control_effective, controls_ready =
            _task_input_parameter_controls(
                table,
                response,
                quantity,
                physical,
                prefix,
                records,
                pending,
            )
        union!(applicable_shared, keys(control_effective))
        # Validate applicable shared controls even when the local task overrides them.
        _, _, shared_control_effective, _ = _task_input_parameter_controls(
            Dict{String, Any}(),
            response,
            quantity,
            physical,
            prefix,
            Dict{String, Dict{String, Any}}(),
            String[],
        )
        union!(applicable_shared, keys(shared_control_effective))
        numerical_table = _task_input_table(table, "numerics")
        numerical = merge(shared_numerics, numerical_table)
        numerics = Numerics(;
            (
                Symbol(k) => (
                    k in (
                        "fs_kind",
                        "prescription",
                        "occupation_derivative_mode",
                        "derivative_backend",
                    ) ? _task_input_symbol(v, "$prefix.numerics.$k") : v
                ) for (k, v) in numerical
            )...,
        )
        # Validate explicit numerical controls even if another required physical axis is pending.
        resolved_numerical_values(
            (;
                id = table["id"],
                numerics,
                physics = (; integral_form = get(controls, :integral_form, :fermi_surface)),
            ),
            quantity;
            nonorthogonal = model_input isa NonorthogonalLocalizedInput,
        )
        effective_task = Dict{String, Any}(
            "id" => table["id"],
            "kind" => table["kind"],
            "numerics" => deepcopy(numerical),
            "observable" => deepcopy(observation_table),
        )
        method === nothing || (effective_task["method"] = method)
        merge!(effective_task, physical_effective, control_effective)
        push!(task_effective, effective_task)
        if length(physical) == length(physical_keys) && controls_ready && sampling !== nothing
            physics = parameter_type(; physical..., controls...)
            for key in fieldnames(parameter_type)
                name = string(key)
                name in string.(keys(controls)) && continue
                name in TASK_INPUT_EXTRA_KEYS || continue
                name == "include_external" && !(quantity in EXTERNAL_METRIC_QUANTITIES) && continue
                value = getfield(physics, key)
                value === nothing && continue
                effective_task[name] = task_input_toml_value(value)
                _task_input_record!(
                    records,
                    "$prefix.$name",
                    effective_task[name],
                    "DEFAULT",
                    string(parameter_type),
                    "Current typed parameter constructor default.",
                )
            end
            push!(
                tasks,
                TaskSpec(;
                    id = table["id"],
                    quantity = table["kind"],
                    method,
                    physics,
                    numerics,
                    observable = observation,
                ),
            )
        end
    end
    any(key -> haskey(response, key), TASK_INPUT_MOMENTUM_KEYS) &&
        !shared_momentum_used &&
        throw(ArgumentError("Shared photon momentum is not consumed by a legal finite-q task."))
    for key in (first.(TASK_INPUT_PHYSICS_FIELDS)..., TASK_INPUT_EXTRA_KEYS...)
        haskey(response, key) &&
            !(key in applicable_shared) &&
            throw(
                ArgumentError(
                    "response.$key has no applicable task consumer; use a task-local field for its supported task family.",
                ),
            )
    end
    effective_response = Dict{String, Any}(
        "sampling" => sampling_effective,
        "execution" => execution_effective,
        "tasks" => Dict{String, Any}(
            task_ids[index] => row for (index, row) in enumerate(task_effective)
        ),
    )
    for row in task_effective
        delete!(row, "id")
    end
    energy_zero === nothing || (effective_response["energy_zero"] = energy_zero)
    effective = Dict{String, Any}(
        "model" => model_effective,
        "response" => effective_response,
        "output" => output_effective,
    )
    config = nothing
    summaries = Any[]
    if isempty(pending) && model_input !== nothing && execution !== nothing
        config = TaskConfig(; model = model_input, sampling, tasks, execution, output)
        compiled = compile_task_configs(config) # existing capability/legality checks
        if config.model isa ModelInput
            parent_output = dirname(first(compiled).output_root)
            output_effective["output_root"] = parent_output
            _task_input_record!(
                records,
                "output.output_root",
                parent_output,
                "DERIVED",
                "compile_task_config.output_root",
                "Existing output path resolver; per-task ID appended.",
            )
        end
        for (index, task) in enumerate(config.tasks)
            summary = task_parameter_summary(config, task)
            push!(summaries, summary)
            task_effective[index]["kind"] = summary.quantity
            task_effective[index]["method"] = summary.method
            if normalize_quantity(summary.quantity) in ZERO_REGULARIZATION_GEOMETRY_QUANTITIES
                metadata["task_$(task.id)_geometry_identity"] = bytes2hex(
                    sha256(
                        repr((
                            "geometry-options/1",
                            summary.quantity,
                            summary.method,
                            summary.physics,
                            summary.numerics,
                            summary.observable,
                        )),
                    ),
                )
            end
            if hasproperty(summary.physics, :include_external)
                task_effective[index]["include_external"] = summary.physics.include_external
                explicit_external =
                    haskey(task_tables[index], "include_external") ||
                    haskey(response, "include_external")
                _task_input_record!(
                    records,
                    "response.tasks.$(task_ids[index]).include_external",
                    summary.physics.include_external,
                    explicit_external ? "USER" : "DEFAULT",
                    haskey(task_tables[index], "include_external") ?
                    "response.tasks.$(task_ids[index]).include_external" :
                    haskey(response, "include_external") ? "response.include_external" :
                    "GeometryParameters.include_external",
                    "false computes only retained-space internal geometry",
                )
            end
            # Replay uses public Numerics names, not private spectral executor fields/placeholders.
            effective_numerics =
                normalize_quantity(summary.quantity) in SPECTRAL_RESPONSE_QUANTITIES ?
                resolved_numerical_values(
                    task,
                    normalize_quantity(summary.quantity);
                    nonorthogonal = config.model isa NonorthogonalLocalizedInput,
                ) : summary.numerics
            for (name, value) in pairs(effective_numerics)
                key = string(name)
                value === nothing || (task_effective[index]["numerics"][key] = value)
                explicit =
                    haskey(task_tables[index], "numerics") &&
                    haskey(task_tables[index]["numerics"], key)
                shared = haskey(shared_numerics, key)
                _task_input_record!(
                    records,
                    "response.tasks.$(task_ids[index]).numerics.$key",
                    value,
                    explicit || shared ? "USER" : "DEFAULT",
                    explicit ? "response.tasks.$(task_ids[index]).numerics.$key" :
                    shared ? "response.numerics.$key" : "task_parameter_summary",
                    explicit || shared ? "Explicit applicable numerical control." :
                    "Current quantity/method/model-aware numerical resolver.";
                    category = "B",
                )
            end
            _task_input_record!(
                records,
                "response.tasks.$(task_ids[index]).method",
                summary.method,
                haskey(task_tables[index], "method") ? "USER" : "DEFAULT",
                "Runtime task registry",
                "Existing public method selection.",
            )
            demands = operator_demand_plan(normalize_task_specs(compiled[index]), compiled[index])
            metadata["task_$(task.id)_required_operators"] = string.(demands.required_operators)
            if config.model isa AbstractNativeModelInput
                validate_native_full_geometry_inputs(
                    config.model,
                    normalize_task_specs(compiled[index]);
                    include_external = compiled[index].include_external,
                )
            end
            if config.model isa NonorthogonalLocalizedInput
                # This existing guard checks H/S/r availability without evaluating
                # callbacks, assembling matrices or starting a numerical driver.
                native_matrix_sources(config.model, demands)
                metadata["native_operator_availability"] = "EXISTING_SOURCE_GUARD_VALIDATED"
            end
        end
        if check_paths && config.model isa ModelInput
            first_cfg = first(compiled)
            bundle = config.model.real_space_operator_bundle_file
            path = bundle === nothing || isempty(bundle) ? first_cfg.model_file : bundle
            isfile(path) || throw(ArgumentError("Model input does not exist: $path"))
            if bundle === nothing || isempty(bundle)
                for cfg in compiled
                    demand = operator_demand_plan(normalize_task_specs(cfg), cfg)
                    demand.requires_full_projector_geometry && throw(
                        ArgumentError(
                            "FULL_DERIVATIVE_OVERLAP_REQUIRED: this task requires a qualified Packed HDF5 bundle from a full .uIu source.",
                        ),
                    )
                end
                metadata["num_orbitals"] = read_wannier_tb_num_orbitals(path)
                metadata["model_capability_validation"] = "HEADER_CHECKED_FULL_OPERATOR_CLOSURE_CHECKED_BY_EXISTING_RUN"
            else
                manifest = read_real_space_operator_bundle_manifest(path)
                metadata["num_orbitals"] = manifest.num_orbitals
                metadata["operator_inventory"] = string.(manifest.inventory)
                for cfg in compiled
                    demand = operator_demand_plan(normalize_task_specs(cfg), cfg)
                    validate_operator_demand(manifest, demand)
                end
                metadata["model_capability_validation"] = "DECLARED_INVENTORY_VALIDATED"
            end
        else
            metadata["model_capability_validation"] = "EXISTING_CONFIG_VALIDATORS;FULL_OPERATOR_PAYLOAD_CHECK_AT_RUN"
        end
    end
    unique!(pending)
    metadata["status"] = isempty(pending) ? "CONFIG_VALIDATED" : "PENDING_REQUIRED_INPUT"
    return TaskInputResolution(config, original, effective, records, pending, summaries, metadata)
end

"""Identify only the lazy-cache need; the canonical resolver still validates input."""
function _task_input_uses_automatic_band_path(document)
    response = get(document, "response", nothing)
    response isa AbstractDict || return false
    sampling = get(response, "sampling", nothing)
    sampling isa AbstractDict || return false
    haskey(sampling, "nodes") && return false
    (haskey(sampling, "structure") || haskey(sampling, "structure_file")) || return false
    tasks = _task_input_named_task_rows(response)
    isempty(tasks) && return false
    for task in tasks
        task isa AbstractDict || return false
        kind = get(task, "kind", nothing)
        kind isa AbstractString || return false
        quantity = try
            normalize_quantity(kind)
        catch error
            error isa ArgumentError || rethrow()
            return false
        end
        quantity == :band_structure || return false
    end
    return true
end

"""Read one strict TOML request; all relative file paths use its directory."""
function read_task_input(path::AbstractString; kwargs...)
    input = read_task_input_file(path)
    _task_input_uses_automatic_band_path(input.document) && activate_symmetry_foundation_backend!()
    # Resolution can activate a weak-dependency image. Defer inference of its
    # subtree until the automatic Band image is available, with no API prewarm.
    return Base.invokelatest(
        resolve_task_input,
        input.document;
        base_dir = dirname(input.path),
        input_path = input.path,
        input_identity = input.identity,
        kwargs...,
    )
end

"""Render resolved values and their parse-boundary origins without running a calculation."""
function explain_task_input(input; verbose::Bool = false)
    stream = IOBuffer()
    println(stream, "Input status: ", input.metadata["status"])
    println(
        stream,
        "Model capabilities: ",
        get(input.metadata, "model_capability_validation", "PENDING"),
    )
    println(stream, "Scientific qualification: NOT_ESTABLISHED")
    for path in sort!(collect(keys(input.provenance)))
        record = input.provenance[path]
        value = get(record, "value", nothing)
        display_value =
            value === nothing ?
            (
                record["state"] == "PENDING" ? "<required or runtime pending>" :
                "<unset optional value>"
            ) : repr(value)
        println(
            stream,
            path,
            " = ",
            display_value,
            "  [",
            record["source"],
            "/",
            record["state"],
            "] ",
            record["unit"],
        )
        println(stream, "  ", record["reason"])
        if verbose
            println(
                stream,
                "  origin: ",
                record["origin"],
                "; API: ",
                record["api"],
                "; class: ",
                record["category"],
                "; value type: ",
                value === nothing ? "absent" : string(typeof(value)),
            )
            println(
                stream,
                "  Legality/range and task applicability use existing public validators.",
            )
        end
    end
    if !isempty(input.pending)
        println(stream, "Required before run: ", join(input.pending, ", "))
    end
    if !isempty(get(input.metadata, "runtime_pending", []))
        println(
            stream,
            "Pending runtime decisions: ",
            join(input.metadata["runtime_pending"], ", "),
        )
    end
    if haskey(input.metadata, "effective_replay_limitation")
        println(stream, "Effective file replay: ", input.metadata["effective_replay_limitation"])
    end
    if get(input.metadata, "model_replay", "") == "REQUIRES_JULIA_MODEL_ENTRY_NOT_FILE_REPLAYABLE"
        println(stream, "Replay requires the declared Julia model entry and its supplied payload.")
    end
    return String(take!(stream))
end

"""Write an intentionally incomplete physical template, with no fabricated occupation or energy axis."""
function write_task_input_template(
    path::AbstractString;
    workflow::AbstractString = "response",
    mode = nothing,
)
    workflow == "response" || return write_workflow_input_template(path, workflow, mode)
    mode === nothing || throw(ArgumentError("response templates do not accept workflow mode"))
    return write_task_input_text(
        path,
        """# WannierNLQG input schema $(TASK_INPUT_SCHEMA_VERSION).
# Fill every physical placeholder before run. check reports missing values.

[model]
source = "wannier"
# model_file = "path/to/model_tb.dat"  # relative to this file; lattice/position in Å

[response]
# fermi_energy_ev = <finite real energy in eV>
# temperature_k = <finite nonnegative temperature in K>
# photon_energies_ev = [<photon energy in eV>, ...]

[response.sampling]
kind = "bz_mesh"
# k_mesh = [<positive integer>, <positive integer>, <positive integer>]
# spatial_dimension = <1, 2 or 3 physical Cartesian axes>

[response.execution]
fourier_backend = "direct"  # explicit implementation selection, not a physical default
# Numerical defaults are obtained from the current task/method/model resolver.

[response.tasks.shift]
kind = "shift_current"
method = "Conventional"  # legality checked against the existing task registry

[output]
# output_root = "results"
""",
    )
end

"""Save machine origins and the human explanation; only resolved file inputs get effective_config."""
function write_task_input_resolution(
    input,
    directory::AbstractString;
    actual_state::AbstractString = "NOT_RUN",
    actual::AbstractDict = Dict{String, Any}(),
)
    root = abspath(directory)
    complete = isempty(input.pending) && isempty(get(input.metadata, "runtime_pending", []))
    replayable =
        get(input.metadata, "model_replay", "") == "FILE_INPUT" &&
        get(input.metadata, "effective_file_replayable", true)
    if !(complete && replayable) && isfile(joinpath(root, "effective_config.toml"))
        throw(
            ArgumentError(
                "Unresolved records require a fresh directory; preserving the existing effective_config.toml.",
            ),
        )
    end
    resolution = Dict{String, Any}(
        "metadata" => merge(input.metadata, Dict("actual_state" => actual_state)),
        "parameters" => input.provenance,
        "pending" => input.pending,
        "actual" => actual,
    )
    write_task_input_file(joinpath(root, "config_resolution.toml"), resolution)
    write_task_input_text(joinpath(root, "config_explanation.md"), explain_task_input(input))
    if complete && replayable
        write_task_input_file(joinpath(root, "effective_config.toml"), input.effective)
    end
    return root
end

# Resolve only from completed runtime records. The original request and its
# parse-boundary provenance stay unchanged; a new result records the derivation.
function _task_input_complete_runtime(input::TaskInputResolution, result::RunResult)
    isempty(get(input.metadata, "runtime_pending", [])) &&
        return input, Dict{String, Any}("status" => "NOT_REQUESTED")
    actual = Dict{String, Any}("status" => "PENDING_ACTUAL_RUNTIME_EVIDENCE")
    executions = Any[]
    try
        length(result.task_ids) == length(result.task_results) == length(input.config.tasks) ||
            throw(ArgumentError("Runtime task identity inventory differs from the input."))
        result.task_ids == [task.id for task in input.config.tasks] || throw(ArgumentError("Runtime task IDs differ from the input."))
        for (id, task_result) in zip(result.task_ids, result.task_results)
            record = _read_task_input_fourier_record(task_result.metadata_path)
            record.requested_backend == "auto" || throw(
                ArgumentError("Actual runtime request differs from the pending auto backend."),
            )
            push!(
                executions,
                Dict{String, Any}(
                    "id" => id,
                    "backend" => record.backend,
                    "nkdiv" => record.nkdiv,
                    "nkfft" => record.nkfft,
                    "factor_source" => record.factor_source,
                    "metadata_path" => record.path,
                    "metadata_identity" => record.identity,
                ),
            )
        end
    catch exception
        exception isa ArgumentError ||
            exception isa SystemError ||
            exception isa IOError ||
            rethrow()
        actual["reason"] = sprint(showerror, exception)
        return input, actual # numerical completion is not erased by missing readback
    end
    metadata = deepcopy(input.metadata)
    provenance = deepcopy(input.provenance)
    effective = deepcopy(input.effective)
    metadata["runtime_pending"] = String[]
    metadata["realized_execution_by_task"] = executions
    common = all(
        item -> all(key -> item[key] == first(executions)[key], ("backend", "nkdiv", "nkfft")),
        executions,
    )
    metadata["effective_file_replayable"] = common
    actual["status"] = "ACTUAL_RUNTIME_RESOLVED"
    actual["tasks"] = executions
    for (index, item) in enumerate(executions)
        _task_input_record!(
            provenance,
            "response.tasks.$(item["id"]).actual_execution.fourier_backend",
            item["backend"],
            "DERIVED",
            item["metadata_path"] * "#Fourier.effective_backend",
            "Read from the completed public run; metadata SHA recorded separately.",
        )
    end
    if common
        item = first(executions)
        execution = effective["response"]["execution"]
        execution["fourier_backend"] = item["backend"]
        for (key, value) in (
            ("fourier_backend", item["backend"]),
            ("nkdiv", item["nkdiv"]),
            ("nkfft", item["nkfft"]),
        )
            value === nothing ? delete!(execution, key) : (execution[key] = value)
            _task_input_record!(
                provenance,
                "response.execution.$key",
                value,
                "DERIVED",
                item["metadata_path"] * "#Fourier",
                "Actual runtime decision shared by every task; original request retained in overrides.",
            )
        end
    else
        metadata["effective_replay_limitation"] = "Per-task runtime choices cannot be represented by one shared execution table."
    end
    return TaskInputResolution(
        input.config,
        input.original,
        effective,
        provenance,
        input.pending,
        input.summaries,
        metadata,
    ),
    actual
end

"""Execute the existing public run and preserve actual warnings, failures, and declared output identities."""
function run_task_input(input::TaskInputResolution; record_directory::AbstractString)
    isempty(input.pending) && input.config !== nothing ||
        throw(ArgumentError("Required input is pending: $(join(input.pending, ", "))."))
    # Ordinary runtime owns initialization/finalization and collective error handling.
    # The frontend only writes records on the existing root identity.
    root = mpi_is_root_process()
    root && write_task_input_resolution(input, record_directory; actual_state = "PREPARED")
    started = time_ns()
    result = try
        run(input.config)
    catch exception
        if root
            actual = Dict{String, Any}(
                "wall_seconds" => (time_ns() - started) / 1.0e9,
                "error" => sprint(showerror, exception),
            )
            write_task_input_resolution(input, record_directory; actual_state = "FAILED", actual)
            write_task_input_file(
                joinpath(record_directory, "run_provenance.toml"),
                Dict("input" => input.metadata, "actual" => actual),
            )
        end
        rethrow()
    end
    if root
        completed_input, runtime_execution = _task_input_complete_runtime(input, result)
        qualification = result.qualification
        actual = Dict{String, Any}(
            "wall_seconds" => (time_ns() - started) / 1.0e9,
            "julia_version" => string(VERSION),
            "package_version" => string(Base.pkgversion(parentmodule(@__MODULE__))),
            "julia_threads" => Threads.nthreads(),
            "qualification_status" => qualification.qualification_status,
            "execution_eligible" => qualification.execution_eligible,
            "production_eligible" => qualification.production_eligible,
            "quality_review_recommended" => qualification.quality_review_recommended,
            "warnings" => qualification.reasons,
            "model_reporting_diagnostics" =>
                get(input.metadata, "native_representation", Dict{String, Any}()),
            "unverified_contracts" => qualification.unverified_contracts,
            "output_files" => [
                Dict("path" => path, "identity" => scientific_file_identity(path)) for
                path in result.outputs if isfile(path)
            ],
            "runtime_metadata_path" => result.metadata_path,
            "MPI_layout_provenance" => "existing runtime metadata",
            "runtime_execution" => runtime_execution,
        )
        write_task_input_resolution(
            completed_input,
            record_directory;
            actual_state = "COMPLETED",
            actual,
        )
        write_task_input_file(
            joinpath(record_directory, "run_provenance.toml"),
            Dict("input" => completed_input.metadata, "actual" => actual),
        )
    end
    return result
end
