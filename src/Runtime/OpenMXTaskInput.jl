# File-backed text adapter. Binary parsing and physical admission remain in IO.
const _OPENMX_TEXT_KEYS = (
    "source",
    "model_file",
    "format_version",
    "byte_order",
    "position_source",
    "operator_scope",
    "unit_convention",
    "magnetic_state",
    "spin_orbit_coupling",
    "wannier_center_convention",
    "max_file_bytes",
    "max_model_bytes",
)

# Parse explicit OpenMX source settings and record required missing fields without allowing a model override.
function _task_input_openmx(table, records, pending, base_dir; model = nothing)
    model === nothing || throw(ArgumentError("A Julia model cannot override source=openmx."))
    _task_input_keys(table, _OPENMX_TEXT_KEYS, "model")
    required = ("model_file", "format_version", "byte_order")
    effective = Dict{String, Any}(table)
    for key in required
        haskey(table, key) || _task_input_missing!(pending, records, "model.$key")
    end
    all(key -> haskey(table, key), required) || return nothing, effective
    path = abspath(base_dir, _task_input_string(table["model_file"], "model.model_file"))
    isfile(path) || throw(ArgumentError("OpenMX model.model_file does not exist: $path"))
    kwargs = Dict{Symbol, Any}()
    symbolic =
        ("byte_order", "position_source", "operator_scope", "unit_convention", "magnetic_state")
    for (key, value) in table
        key in ("source", "model_file") && continue
        if key in symbolic
            kwargs[Symbol(key)] = Symbol(_task_input_string(value, "model.$key"))
        elseif key == "spin_orbit_coupling"
            value isa Bool || throw(ArgumentError("model.spin_orbit_coupling must be Boolean."))
            kwargs[Symbol(key)] = value
        elseif key in ("max_file_bytes", "max_model_bytes")
            value isa Integer && !(value isa Bool) && value > 0 ||
                throw(ArgumentError("model.$key must be a positive integer."))
            kwargs[Symbol(key)] = value
        else
            kwargs[Symbol(key)] = _task_input_string(value, "model.$key")
        end
    end
    input = read_openmx_localized_input(path; kwargs...)
    effective["model_file"] = path
    # Read defaults back from the canonical reader's actual provenance.
    p = input.parameters
    for (key, value) in (
        "format_version" => p.format_version,
        "byte_order" => string(p.byte_order),
        "position_source" => string(p.position_origin),
        "unit_convention" => string(p.unit_convention),
        "magnetic_state" => string(p.magnetic_state),
        "spin_orbit_coupling" => p.spin_orbit_coupling,
        "wannier_center_convention" => p.wannier_center_convention,
        "operator_scope" =>
            (p.position_operator_admitted ? "hamiltonian_overlap_position" : "hamiltonian_overlap"),
    )
        effective[key] = value
    end
    for (key, value) in effective
        key == "source" && continue
        _task_input_record!(
            records,
            "model.$key",
            value,
            haskey(table, key) ? "USER" : "DERIVED",
            "OpenMX file reader",
            "Resolved existing reader contract; no point-orbital or missing-position fallback.",
        )
    end
    return input, effective
end
