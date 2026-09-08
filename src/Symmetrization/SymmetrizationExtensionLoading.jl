const SYMMETRIZATION_EXTENSION_NAME = :WannierNLQGSymmetrizationExt
const SYMMETRIZATION_EXTENSION_LOCK = ReentrantLock()

# Return the active package extension without importing any trigger package.
function _active_symmetrization_extension()
    return Base.get_extension(parentmodule(@__MODULE__), SYMMETRIZATION_EXTENSION_NAME)
end

# Import all extension triggers in the fixed activation order.
function _import_symmetrization_extension_triggers!()
    Base.eval(@__MODULE__, :(import HDF5))
    Base.eval(@__MODULE__, :(import JSON3))
    Base.eval(@__MODULE__, :(import EzXML))
    return nothing
end

# Activate the extension once and report whether this task needs a world-age bridge.
function _load_symmetrization_extension!()
    extension = _active_symmetrization_extension()
    extension === nothing || return extension, false
    lock(SYMMETRIZATION_EXTENSION_LOCK)
    try
        extension = _active_symmetrization_extension()
        if extension === nothing
            _import_symmetrization_extension_triggers!()
            extension = _active_symmetrization_extension()
            extension === nothing && error(
                "WannierNLQG symmetrization extension did not activate after loading " *
                "HDF5, JSON3, and EzXML",
            )
        end
        return extension, true
    finally
        unlock(SYMMETRIZATION_EXTENSION_LOCK)
    end
end

# Forward one expert call, bridging world age until the calling task reaches the extension world.
function _call_symmetrization_extension(function_name::Symbol, arguments...; keywords...)
    extension, _ = _load_symmetrization_extension!()
    implementation = Base.invokelatest(getproperty, extension, function_name)
    return Base.invokelatest(implementation, arguments...; keywords...)
end
