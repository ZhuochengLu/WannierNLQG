# Rebind only the four observed, frozen Runtime thread call sites.
# Global gensym prefixes vary between workload modes and cache builds. Local
# call-site suffixes, the KPath capture schema, and the wrapper/inner relation
# must agree; a changed call site fails closed and requires a new real trace.
# Types only are retained, never closure instances or external runtime handles.
function _first_use_resolve_runtime_thread_types()
    FIRST_USE_TRACE_COMPATIBLE ||
        error("Captured Runtime thread types require the Julia 1.11.2 trace version")
    runtime_names = names(Runtime; all = true)
    suffixes = (
        "#threadsfor_fun#576",
        "#threadsfor_fun#573#577",
        "#threadsfor_fun#809",
        "#threadsfor_fun#805#810",
    )
    bindings = map(suffixes) do suffix
        matches = filter(runtime_names) do name
            occursin(r"^#\d+#threadsfor_fun#", string(name)) && endswith(string(name), suffix)
        end
        length(matches) == 1 ||
            error("Precompile thread call-site identity is not unique: $(suffix), $(matches)")
        binding = getfield(Runtime, only(matches))
        binding isa Type && binding <: Function && parentmodule(binding) === Runtime ||
            error("Precompile thread binding has an invalid owner or type: $(suffix)")
        binding
    end
    outer = Base.unwrap_unionall(bindings[3])
    inner = Base.unwrap_unionall(bindings[4])
    captures = fieldnames(inner)
    length(captures) == 10 &&
    captures[1:9] == (
        :kernel,
        :plan,
        :model,
        :thread_errors,
        :local_residuals,
        :local_values,
        :workers,
        :worker_count,
        :local_indices,
    ) || error("Precompile KPath inner capture schema changed; recollect its real trace")
    occursin(r"^#\d+#range$", string(captures[10])) ||
        error("Precompile KPath range capture changed; recollect its real trace")
    length(inner.parameters) == 10 && length(outer.parameters) == 1 ||
        error("Precompile KPath type parameter layout changed; recollect its real trace")
    wrapper_captures = fieldnames(outer)
    length(wrapper_captures) == 1 &&
    startswith(string(nameof(inner)), string(only(wrapper_captures)) * "#") ||
        error("Precompile KPath wrapper no longer captures the observed inner function")
    return bindings
end

const FIRST_USE_RUNTIME_THREAD_TYPES =
    FIRST_USE_WORKLOAD_ENABLED && FIRST_USE_TRACE_COMPATIBLE ?
    _first_use_resolve_runtime_thread_types() : nothing

# The audit uses the same package-owned resolver with workloads disabled.
# Normal disabled-workload imports do not invoke this resolver.
function _first_use_runtime_thread_type(index::Integer)
    bindings = FIRST_USE_RUNTIME_THREAD_TYPES
    bindings === nothing && (bindings = _first_use_resolve_runtime_thread_types())
    return bindings[index]
end
