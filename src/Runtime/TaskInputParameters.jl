# Cold text-input validation precedes overrides. Task applicability and coupled
# constraints remain in the effective configuration; in particular zero eta is
# valid here, and a nonpositive transition window may mean no screening.
function _task_input_explicit_numerics(table, path)
    _task_input_keys(table, string.(NUMERICS_PARAMETER_NAMES), path)
    for (key, value) in table
        valid = if key == "eta_correction"
            value isa Bool
        elseif key == "broadening_type"
            value isa AbstractString && value in ("Gaussian", "Lorentzian")
        elseif key in
               ("fs_kind", "prescription", "occupation_derivative_mode", "derivative_backend")
            choices =
                key == "fs_kind" ? ("gaussian", "lorentzian") :
                key == "prescription" ? ("distribution_broadening",) :
                key == "occupation_derivative_mode" ? ("fermi_dirac", "shg_gaussian") :
                ("analytic", "finite_difference")
            value isa AbstractString && value in choices
        else
            finite_real =
                value isa Real && !(value isa Bool) && isfinite(value) && isfinite(Float64(value))
            if !finite_real
                false
            elseif key == "band_window_size"
                isinteger(value) && typemin(Int) <= value <= typemax(Int) && (value == -1 || value > 0)
            elseif key in (
                "broadening",
                "low_frequency_broadening",
                "eta_fs_ev",
                "hermiticity_tolerance",
                "finite_difference_step",
            )
                value > 0
            elseif key in (
                "gap_tolerance",
                "degeneracy_threshold",
                "denominator_regularization",
                "intermediate_regularization",
            )
                value >= 0
            else
                true
            end
        end
        valid || throw(ArgumentError("$path.$key has an invalid explicit type or basic value."))
    end
    return nothing
end

# These are individual selector domains, not task-specific applicability checks.
function _task_input_explicit_selectors(table, path)
    for (key, choices) in (
        (
            "input_semantics",
            ("defined_finite_model", "projected_energy_overlap", "direct_energy_overlap"),
        ),
        ("projection", ("ordered", "symmetric", "antisymmetric")),
        ("formulation", ("unregrouped", "regrouped", "both")),
        ("output", ("total", "terms", "both")),
        ("response", ("conductivity", "susceptibility", "both")),
        ("integral_form", ("fermi_surface", "fermi_sea")),
    )
        haskey(table, key) || continue
        value = table[key]
        value isa AbstractString && value in choices ||
            throw(ArgumentError("$path.$key has an invalid explicit selector."))
    end
    return nothing
end

# Text names for explicit physical axes; numerical defaults remain constructor-owned.
const TASK_INPUT_SPECTRAL_FIELDS =
    (("fermi_energies_ev", :fermi_energies, "eV"), TASK_INPUT_PHYSICS_FIELDS[3])
const TASK_INPUT_EXTRA_KEYS = (
    "fermi_energies_ev",
    "relaxation",
    "input_semantics",
    "projection",
    "formulation",
    "output",
    "response",
    "include_external",
    "integral_form",
    "relaxation_time_fs",
)
const TASK_INPUT_MOMENTUM_KEYS = (
    "photon_momentum_A_inverse",
    "photon_momenta_A_inverse",
    "photon_momentum_enhancement",
    "photon_momentum_direction",
    "photon_momentum_table_file",
)

# Map a registered family to its existing public parameter group.
function _task_input_parameter_type(quantity)
    quantity in BERRY_MULTIPOLE_QUANTITIES && return BerryMultipoleParameters
    quantity == :band_structure && return BandParameters
    quantity == :intrinsic_ahc && return IntrinsicHallParameters
    quantity == :linear_transport && return LinearTransportParameters
    quantity == :linear_optical_response && return LinearOpticalResponseParameters
    quantity == :orbital_magnetization && return OrbitalMagnetizationParameters
    quantity == :second_harmonic_generation && return SHGParameters
    quantity == :third_harmonic_generation && return THGParameters
    quantity == :jerk_current && return JerkParameters
    quantity in (:photon_drag_shift_current, :photon_drag_injection_current) &&
        return FiniteQOpticalParameters
    quantity in OPTICAL_TASK_QUANTITIES && return OpticalParameters
    return GeometryParameters
end

# Select required physical axes without supplying occupation or relaxation guesses.
function _task_input_required_fields(quantity, observation, paired)
    quantity in BERRY_MULTIPOLE_QUANTITIES && return TASK_INPUT_SPECTRAL_FIELDS
    quantity == :band_structure && return (TASK_INPUT_PHYSICS_FIELDS[2],)
    quantity in (:intrinsic_ahc, :linear_transport, :orbital_magnetization) &&
        return TASK_INPUT_SPECTRAL_FIELDS
    quantity == :linear_optical_response && return TASK_INPUT_PHYSICS_FIELDS
    quantity in (:photon_drag_shift_current, :photon_drag_injection_current) &&
        return paired ? TASK_INPUT_PAIRED_Q_FIELDS : TASK_INPUT_FINITE_Q_FIELDS
    quantity in OPTICAL_TASK_QUANTITIES && return TASK_INPUT_PHYSICS_FIELDS
    return observation isa KSliceSelection && _occupied_sum_requested(observation.bands) ?
           TASK_INPUT_PHYSICS_FIELDS[2:3] : ()
end

# Validate text selectors before converting strings to typed symbolic choices.
_task_input_symbol(value, path) = Symbol(_task_input_string(value, path))

# Resolve mandatory structured parameters and optional constructor controls in the cold reader.
function _task_input_parameter_controls(
    table,
    response,
    quantity,
    physical,
    prefix,
    records,
    pending,
)
    parameter_type = _task_input_parameter_type(quantity)
    required =
        quantity in BERRY_MULTIPOLE_QUANTITIES ? ("relaxation_time_fs",) :
        quantity in (:linear_transport, :linear_optical_response) ? ("relaxation",) :
        quantity == :orbital_magnetization ? ("input_semantics",) : ()
    optional =
        quantity in EXTERNAL_METRIC_QUANTITIES ? (:include_external,) :
        quantity in BERRY_MULTIPOLE_QUANTITIES ? (:integral_form,) :
        quantity == :second_harmonic_generation ? (:output, :response) :
        quantity == :third_harmonic_generation ? (:formulation, :response, :output) :
        quantity == :jerk_current ? (:projection,) : ()
    allowed = (required..., string.(optional)...)
    for key in TASK_INPUT_EXTRA_KEYS
        key == "fermi_energies_ev" && continue
        haskey(table, key) &&
            !(key in allowed) &&
            throw(ArgumentError("$prefix.$key does not apply to this task."))
    end
    controls = Dict{Symbol, Any}()
    effective = Dict{String, Any}()
    for key in allowed
        path = "$prefix.$key"
        if !haskey(table, key) && !haskey(response, key)
            key in required && _task_input_missing!(pending, records, path)
            continue
        end
        value = get(table, key, get(response, key, nothing))
        origin = haskey(table, key) ? path : "response.$key"
        _task_input_record!(records, path, value, "USER", origin, "Typed task parameter.")
        resolved = if key == "include_external"
            value isa Bool || throw(ArgumentError("$path must be Boolean"))
            value
        elseif key == "relaxation"
            _task_input_keys(value, ("gamma_intra_ev", "gamma_inter_ev"), path)
            for gamma in ("gamma_intra_ev", "gamma_inter_ev")
                haskey(value, gamma) || throw(ArgumentError("$path.$gamma is required."))
                x = value[gamma]
                x isa Real && !(x isa Bool) && isfinite(x) && x > 0 && isfinite(Float64(x)) ||
                    throw(ArgumentError("$path.$gamma must be finite and positive (eV)."))
            end
            SeparateRelaxation(;
                gamma_intra_ev = Float64(value["gamma_intra_ev"]),
                gamma_inter_ev = Float64(value["gamma_inter_ev"]),
            )
        elseif key == "relaxation_time_fs"
            value isa Real &&
            !(value isa Bool) &&
            isfinite(value) &&
            value > 0 &&
            isfinite(Float64(value)) || throw(
                ArgumentError(
                    "$path must be finite and positive ($(key == "relaxation_time_fs" ? "fs" : "Angstrom")).",
                ),
            )
            Float64(value)
        else
            _task_input_symbol(value, path)
        end
        controls[Symbol(key)] = resolved
        effective[key] = deepcopy(value)
    end
    return parameter_type, controls, effective, all(key -> haskey(controls, Symbol(key)), required)
end

# Lower uniform or explicit adaptive controls through the existing integration API.
function _task_input_integration(value, records)
    path = "response.execution.integration_algorithm"
    value == "uniform" && return UniformIntegration(), "uniform"
    if value isa AbstractDict && get(value, "kind", "") == "uniform"
        _task_input_keys(value, ("kind", "region_quadrature"), path)
        rule = _task_input_symbol(
            get(value, "region_quadrature", "midpoint"),
            "$path.region_quadrature",
        )
        algorithm = UniformIntegration(; region_quadrature = rule)
        _task_input_record!(
            records,
            "$path.region_quadrature",
            String(rule),
            haskey(value, "region_quadrature") ? "USER" : "DEFAULT",
            "UniformIntegration.region_quadrature",
            "Explicit finite-region uniform quadrature.",
        )
        return algorithm, Dict("kind" => "uniform", "region_quadrature" => String(rule))
    end
    _task_input_keys(value, ("kind", "atol", "rtol", "max_evaluations", "initial_divisions"), path)
    get(value, "kind", "") == "h_adaptive_cubature" ||
        throw(ArgumentError("$path requires uniform or kind=h_adaptive_cubature."))
    controls = Dict{Symbol, Any}()
    for (key, item) in value
        key == "kind" && continue
        valid =
            key in ("atol", "rtol") ? item isa Real && !(item isa Bool) && isfinite(item) :
            item isa Integer && !(item isa Bool)
        valid || throw(ArgumentError("$path.$key has an invalid numeric type."))
        controls[Symbol(key)] = item
    end
    algorithm = HAdaptiveCubature(; controls...)
    effective = Dict{String, Any}("kind" => "h_adaptive_cubature")
    for key in fieldnames(HAdaptiveCubature)
        name = string(key)
        effective[name] = getfield(algorithm, key)
        _task_input_record!(
            records,
            "$path.$name",
            effective[name],
            haskey(value, name) ? "USER" : "DEFAULT",
            "HAdaptiveCubature.$name",
            "Existing adaptive constructor control.",
        )
    end
    return algorithm, effective
end

# Require one q-source and convert enhancement/table modes into the existing zipped path.
function _task_input_momentum_source(table, response, prefix, records)
    # A local q declaration replaces the entire shared mode, including its direction.
    selected = any(key -> haskey(table, key), TASK_INPUT_MOMENTUM_KEYS) ? table : response
    values = Dict{String, Any}(
        key => selected[key] for key in TASK_INPUT_MOMENTUM_KEYS if haskey(selected, key)
    )
    sources = filter(
        key -> haskey(values, key),
        (
            "photon_momentum_A_inverse",
            "photon_momenta_A_inverse",
            "photon_momentum_enhancement",
            "photon_momentum_table_file",
        ),
    )
    length(sources) <= 1 ||
        throw(ArgumentError("$prefix: the four photon momentum modes are mutually exclusive."))
    derived =
        !isempty(sources) &&
        only(sources) in ("photon_momentum_enhancement", "photon_momentum_table_file")
    haskey(values, "photon_momentum_direction") == derived || throw(
        ArgumentError(
            "$prefix: enhancement/table modes require an explicit direction; fixed/paired modes do not use it.",
        ),
    )
    if haskey(values, "photon_momentum_A_inverse")
        _task_input_tuple(
            values["photon_momentum_A_inverse"],
            "$prefix.photon_momentum_A_inverse";
            lengths = (3,),
        )
    elseif haskey(values, "photon_momenta_A_inverse")
        rows=values["photon_momenta_A_inverse"]
        rows isa AbstractVector && !isempty(rows) ||
            throw(ArgumentError("$prefix.photon_momenta_A_inverse requires nonempty rows"))
        foreach(q->_copy_photon_path_momentum(q), rows)
    end
    if derived
        direction = _task_input_tuple(
            values["photon_momentum_direction"],
            "$prefix.photon_momentum_direction";
            lengths = (3,),
        )
        all(isfinite, direction) && maximum(abs, direction) > 0 ||
            throw(ArgumentError("Photon momentum direction must be finite and nonzero."))
        if haskey(values, "photon_momentum_enhancement")
            value = values["photon_momentum_enhancement"]
            value isa Real &&
            !(value isa Bool) &&
            isfinite(value) &&
            value >= 0 &&
            isfinite(Float64(value)) ||
                throw(ArgumentError("Photon momentum enhancement must be finite and nonnegative."))
        else
            _task_input_string(
                values["photon_momentum_table_file"],
                "$prefix.photon_momentum_table_file",
            )
        end
    end
    for (key, value) in values
        _task_input_record!(
            records,
            "$prefix.$key",
            value,
            "USER",
            haskey(table, key) ? "$prefix.$key" : "response.$key",
            "Explicit photon momentum source.",
        )
    end
    return values, derived
end

# Evaluate exact CSV nodes or in-range linear interpolation while preserving query order.
function _task_input_table_magnitudes(record, energies)
    nodes = record.energies
    result = Float64[]
    for energy in energies
        first(nodes) <= energy <= last(nodes) || throw(
            ArgumentError(
                "photon energy $energy is outside the CSV range; extrapolation is forbidden.",
            ),
        )
        index = searchsortedfirst(nodes, energy)
        magnitude = if index <= length(nodes) && nodes[index] == energy
            record.magnitudes[index]
        else
            fraction = (energy - nodes[index - 1]) / (nodes[index] - nodes[index - 1])
            (1 - fraction) * record.magnitudes[index - 1] + fraction * record.magnitudes[index]
        end
        push!(result, magnitude)
    end
    return result
end

# Cold q-path construction shares FiniteQOpticalParameters with explicit paired inputs.
function _task_input_derived_momenta(values, energies, prefix, records, metadata, base_dir, tables)
    all(x -> isfinite(x) && x >= 0, energies) ||
        throw(ArgumentError("$prefix: enhancement/table energies must be nonnegative and finite."))
    direction = _task_input_tuple(
        values["photon_momentum_direction"],
        "$prefix.photon_momentum_direction";
        lengths = (3,),
    )
    scale = maximum(abs, direction)
    scale > 0 && isfinite(scale) ||
        throw(ArgumentError("Photon momentum direction must be nonzero and finite."))
    unit_direction = collect(direction) ./ scale
    unit_direction ./= norm(unit_direction)
    source = Dict{String, Any}("normalized_direction" => unit_direction)
    magnitudes = if haskey(values, "photon_momentum_enhancement")
        enhancement = values["photon_momentum_enhancement"]
        enhancement isa Real &&
        !(enhancement isa Bool) &&
        isfinite(enhancement) &&
        enhancement >= 0 ||
            throw(ArgumentError("Photon momentum enhancement must be finite and nonnegative."))
        source["mode"] = "enhancement"
        source["enhancement"] = enhancement
        source["hbar_c_ev_angstrom"] = 1973.269804
        Float64(enhancement) .* energies ./ 1973.269804
    else
        path = _task_input_string(
            values["photon_momentum_table_file"],
            "$prefix.photon_momentum_table_file",
        )
        absolute = isabspath(path) ? abspath(path) : abspath(joinpath(base_dir, path))
        record = get!(tables, absolute) do
            read_photon_momentum_table(absolute)
        end
        source["mode"] = "table"
        source["file"] = record.path
        source["identity"] = record.identity
        _task_input_table_magnitudes(record, energies)
    end
    all(isfinite, magnitudes) ||
        throw(ArgumentError("Photon momentum magnitude is not representable in Float64."))
    momenta = NTuple{3, Float64}[Tuple(magnitude .* unit_direction) for magnitude in magnitudes]
    source["energy_ev"] = copy(energies)
    source["photon_momenta_A_inverse"] = [collect(q) for q in momenta]
    get!(metadata, "photon_momentum_sources", Dict{String, Any}())[prefix] = source
    _task_input_record!(
        records,
        "$prefix.photon_momenta_A_inverse",
        [collect(q) for q in momenta],
        "DERIVED",
        "Explicit photon momentum source",
        "Zipped momentum rows in the original photon-energy order.";
        unit = "A^-1",
        category = "C",
        api = "photon_momenta",
    )
    return momenta
end
