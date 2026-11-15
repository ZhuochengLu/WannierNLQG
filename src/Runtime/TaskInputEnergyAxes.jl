"""Bound user-generated axes before allocation; explicit arrays retain their existing semantics."""
const TASK_INPUT_MAX_GENERATED_AXIS_POINTS = 1_000_000

"""Normalize static scalar/vector axes per layer; local axes replace the complete shared axis."""
function _task_input_static_fermi_axes(table, response, quantity, prefix)
    static =
        quantity in (:intrinsic_ahc, :linear_transport, :orbital_magnetization) ||
        quantity in BERRY_MULTIPOLE_QUANTITIES
    static || return table, response, nothing
    local_table, shared_table = copy(table), copy(response)
    local_scalar = haskey(local_table, "fermi_energy_ev")
    shared_scalar = haskey(shared_table, "fermi_energy_ev")
    for (layer, path) in ((local_table, prefix), (shared_table, "response"))
        haskey(layer, "fermi_energy_ev") &&
            haskey(layer, "fermi_energies_ev") &&
            throw(
                ArgumentError(
                    "$path supplies both scalar and vector Fermi energies; choose one axis.",
                ),
            )
        if haskey(layer, "fermi_energy_ev")
            layer["fermi_energies_ev"] = [layer["fermi_energy_ev"]]
            delete!(layer, "fermi_energy_ev")
        end
    end
    origin =
        local_scalar ? "$prefix.fermi_energy_ev" :
        !haskey(local_table, "fermi_energies_ev") && shared_scalar ? "response.fermi_energy_ev" :
        nothing
    return local_table, shared_table, origin
end

# Generate a Float64 range by index, with exact binary-rational count arithmetic and a bounded endpoint tolerance.
function _task_input_energy_range(lower, upper, step, count, path)
    for value in (lower, upper)
        value isa Real && !(value isa Bool) && isfinite(value) && isfinite(Float64(value)) ||
            throw(ArgumentError("$path endpoints must be finite representable real numbers"))
    end
    lo, hi = Float64(lower), Float64(upper)
    upper >= lower || throw(ArgumentError("$path maximum must be at least its minimum"))
    upper == lower ||
        hi > lo ||
        throw(ArgumentError("$path distinct endpoints collapse at Float64 resolution"))
    if count !== nothing
        count isa Integer &&
        !(count isa Bool) &&
        1 <= count <= TASK_INPUT_MAX_GENERATED_AXIS_POINTS || throw(
            ArgumentError(
                "$path point count must be an integer in 1:$(TASK_INPUT_MAX_GENERATED_AXIS_POINTS)",
            ),
        )
        (count == 1 ? lo == hi : hi > lo) || throw(
            ArgumentError(
                "$path one point requires equal endpoints; multiple points require distinct endpoints",
            ),
        )
        result = count == 1 ? [lo] : collect(range(lo, hi; length = Int(count)))
    else
        step isa Real &&
        !(step isa Bool) &&
        isfinite(step) &&
        step > 0 &&
        isfinite(Float64(step)) &&
        Float64(step) > 0 ||
            throw(ArgumentError("$path step must be finite, representable and positive"))
        delta = Float64(step)
        # Eight ulps at the endpoint scale, bounded to a billionth of one step:
        # tolerate endpoint roundoff, never append a shortened final interval.
        tolerance = min(8eps(max(abs(lo), abs(hi), abs(delta))), delta * 1e-9)
        ratio =
            (Rational{BigInt}(hi) - Rational{BigInt}(lo) + Rational{BigInt}(tolerance)) /
            Rational{BigInt}(delta)
        n = fld(numerator(ratio), denominator(ratio)) + 1
        1 <= n <= TASK_INPUT_MAX_GENERATED_AXIS_POINTS ||
            throw(ArgumentError("$path generated point count exceeds the allocation limit"))
        result = [lo + index * delta for index in 0:(Int(n) - 1)]
        for index in eachindex(result)
            if !isfinite(result[index])
                result[index] = Float64(Rational{BigInt}(lo) + (index-1)*Rational{BigInt}(delta))
            end
        end
        if last(result) > hi
            last(result) - hi <= tolerance || throw(ArgumentError("$path endpoint exceeds maximum"))
            result[end] = hi
        end
    end
    all(isfinite, result) && all(index -> result[index] > result[index - 1], 2:length(result)) ||
        throw(ArgumentError("$path range is not strictly increasing at Float64 resolution"))
    return result
end

# Normalize each complete local axis independently; never merge task and shared range fragments.
function _task_input_expand_axes!(table, prefix, records)
    table isa AbstractDict || throw(ArgumentError("$prefix must be a table"))
    for key in ("photon_energies_ev", "fermi_energies_ev")
        if haskey(table, key)
            values=table[key]
            values isa AbstractVector &&
            all(x->x isa Real && !(x isa Bool) && isfinite(x) && isfinite(Float64(x)), values) ||
                throw(ArgumentError("$prefix.$key requires finite representable real energies"))
        end
    end
    for key in ("fermi_energy_ev", "temperature_k")
        if haskey(table, key)
            value=table[key]
            value isa Real && !(value isa Bool) && isfinite(value) && isfinite(Float64(value)) ||
                throw(ArgumentError("$prefix.$key requires a finite representable real"))
            key == "temperature_k" &&
                value < 0 &&
                throw(ArgumentError("$prefix.temperature_k must be nonnegative"))
        end
    end
    for (stem, array_key) in
        (("photon_energy", "photon_energies_ev"), ("fermi_energy", "fermi_energies_ev"))
        fields = (stem * "_min_ev", stem * "_max_ev", stem * "_step_ev", stem * "_num_points")
        present = filter(key -> haskey(table, key), fields)
        isempty(present) && continue
        !haskey(table, array_key) &&
        haskey(table, fields[1]) &&
        haskey(table, fields[2]) &&
        xor(haskey(table, fields[3]), haskey(table, fields[4])) || throw(
            ArgumentError(
                "$prefix.$stem requires one complete min/max + step or point-count expression, without an explicit array",
            ),
        )
        values = _task_input_energy_range(
            table[fields[1]],
            table[fields[2]],
            get(table, fields[3], nothing),
            get(table, fields[4], nothing),
            "$prefix.$stem",
        )
        table[array_key] = values
        _task_input_record!(
            records,
            "$prefix.$array_key",
            values,
            "DERIVED",
            prefix,
            "Index-generated energy axis; original range fields remain USER provenance.";
            unit = "eV",
            category = "C",
        )
        records["$prefix.$array_key"]["axis_expanded"] = true
        for key in present
            delete!(table, key)
        end
    end
    return table
end
