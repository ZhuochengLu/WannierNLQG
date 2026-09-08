const WANNIERIZATION_EXTENSION_NAME = :WannierNLQGWannierizationExt
const WANNIERIZATION_EXTENSION_LOCK = ReentrantLock()

# Return the active SAWF extension without importing its trigger packages.
function _active_wannierization_extension()
    return Base.get_extension(parentmodule(@__MODULE__), WANNIERIZATION_EXTENSION_NAME)
end

# Import heavy dependencies in one deterministic activation order.
function _import_wannierization_extension_triggers!()
    Base.eval(@__MODULE__, :(import HDF5))
    Base.eval(@__MODULE__, :(import JSON3))
    Base.eval(@__MODULE__, :(import EzXML))
    return nothing
end

# Activate the SAWF extension once and report whether a world-age bridge is needed.
function _load_wannierization_extension!()
    extension = _active_wannierization_extension()
    extension === nothing || return extension, false
    lock(WANNIERIZATION_EXTENSION_LOCK)
    try
        extension = _active_wannierization_extension()
        if extension === nothing
            _import_wannierization_extension_triggers!()
            extension = _active_wannierization_extension()
            extension === nothing && error(
                "WannierNLQG Wannierization extension did not activate after loading " *
                "HDF5, JSON3, and EzXML",
            )
        end
        return extension, true
    finally
        unlock(WANNIERIZATION_EXTENSION_LOCK)
    end
end

# Forward one expert call across the extension activation world age.
function _call_wannierization_extension(function_name::Symbol, arguments...; keywords...)
    extension, _ = _load_wannierization_extension!()
    resolver = Base.invokelatest(getproperty, extension, :resolve_wannierization_entrypoint)
    implementation = Base.invokelatest(resolver, function_name)
    return Base.invokelatest(implementation, arguments...; keywords...)
end
