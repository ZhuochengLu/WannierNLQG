"""
Map a registered method to the stable result suffix `conv`, `proj`, `geo` or `wilson`; reject unsupported methods.
"""
function result_method_suffix(method::Symbol)
    method_value = method_id(method)
    return method_value == METHOD_CONVENTIONAL ? "conv" :
           method_value == METHOD_PROJECTOR ? "proj" :
           method_value == METHOD_GEOMETRIC_LOOP ? "geo" :
           method_value == METHOD_WILSON_LOOP ? "wilson" :
           error("No result filename suffix for method=$(method).")
end

"""
Resolve the observable filename suffix through the first supported registry method for the quantity/calculation pair.
"""
function result_observable_suffix(quantity::Symbol, calculation::Symbol)
    methods = supported_methods(quantity, calculation)
    if !isempty(methods)
        definition = task_definition(quantity, first(methods), calculation)
        definition !== nothing && return definition.observable_suffix
    end
    error("No result filename observable for quantity=$(quantity), calculation=$(calculation).")
end

"""
Build the stable numerical-output basename for a registered task and optional part/band label.

Reject real/imaginary parts or band labels incompatible with the calculation; this helper never creates files.
"""
function result_filename(
    system_name::AbstractString,
    quantity::Symbol,
    method::Symbol,
    calculation::Symbol;
    part::Union{Nothing, Symbol} = nothing,
    band::Union{Nothing, Int, Symbol, AbstractString} = nothing,
)
    observable = result_observable_suffix(quantity, calculation)
    method_suffix = result_method_suffix(method)

    definition = task_definition(quantity, method, calculation)
    if definition !== nothing && definition.output_policy == OUTPUT_BAND_STRUCTURE
        isnothing(part) || error("Band result filenames do not accept part=$(part).")
        isnothing(band) || error("Band result filenames do not accept band=$(band).")
        return "$(system_name)_bands.dat"
    elseif calculation == :integral
        if !isnothing(part)
            error("Integral result filenames do not accept part=$(part).")
        end
        if !isnothing(band)
            error("Integral result filenames do not accept band=$(band).")
        end
        return "$(system_name)_$(observable)_$(method_suffix).dat"
    elseif calculation == :kslice
        if is_band_resolved_real_kslice_quantity(quantity)
            if !isnothing(part)
                error(
                    "$(canonical_quantity_name(quantity)) K-slice result filenames are real-only and do not accept part=$(part).",
                )
            end
            if band === :sum
                return "$(system_name)_$(observable)_sum_$(method_suffix).dat"
            elseif band isa Symbol
                error(
                    "Unsupported $(canonical_quantity_name(quantity)) K-slice band label=$(band).",
                )
            end
            band_label = isnothing(band) ? "band" : string(band)
            return "$(system_name)_$(observable)_$(band_label)_$(method_suffix).dat"
        elseif is_target_group_real_kslice_quantity(quantity)
            if !isnothing(part)
                error(
                    "$(canonical_quantity_name(quantity)) K-slice result filenames are real-only and do not accept part=$(part).",
                )
            elseif band isa Symbol
                error(
                    "Unsupported $(canonical_quantity_name(quantity)) K-slice target-group label=$(band).",
                )
            end
            if isnothing(band)
                return "$(system_name)_$(observable)_$(method_suffix).dat"
            end
            return "$(system_name)_$(observable)_$(band)_$(method_suffix).dat"
        elseif is_interband_quantum_geometry_quantity(quantity)
            if !isnothing(part)
                error(
                    "$(canonical_quantity_name(quantity)) K-slice result filenames are real-only and do not accept part=$(part).",
                )
            elseif !isnothing(band)
                error(
                    "$(canonical_quantity_name(quantity)) K-slice result filenames do not accept band=$(band).",
                )
            end
            return "$(system_name)_$(observable)_$(method_suffix).dat"
        end
        if part != :r && part != :i
            error("K-slice result filenames require part=:r or part=:i, got part=$(part).")
        elseif !isnothing(band)
            error("Only real-only band-resolved K-slice result filenames accept band=$(band).")
        end
        return "$(system_name)_$(observable)_$(part)_$(method_suffix).dat"
    end
    error("No result filename rule for calculation=$(calculation).")
end
