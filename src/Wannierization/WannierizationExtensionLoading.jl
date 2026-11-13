const WANNIERIZATION_EXTENSION_NAME = :WannierNLQGWannierizationExt
const WANNIERIZATION_EXTENSION_LOCK = ReentrantLock()

# Return the active SAWF extension without importing its trigger packages.
function _active_wannierization_extension()
    return Base.get_extension(parentmodule(@__MODULE__), WANNIERIZATION_EXTENSION_NAME)
end

# Load declared triggers in one deterministic order, without runtime eval or
# mutating the parent module's bindings during package image generation.
function _import_wannierization_extension_triggers!()
    Base.require(Base.PkgId(Base.UUID("f67ccb44-e63f-5c2f-98bd-6dc0ccc4ba2f"), "HDF5"))
    Base.require(WANNIERIZATION_JSON3_PKG_ID)
    Base.require(Base.PkgId(Base.UUID("8f5d6c58-4d21-5cfd-889c-e3ad7ee6a615"), "EzXML"))
    return nothing
end

# Activate the SAWF extension once and report whether a world-age bridge is needed.
function _load_wannierization_extension!()
    lock(WANNIERIZATION_EXTENSION_LOCK)
    try
        extension = _active_wannierization_extension()
        extension === nothing || return extension, false
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
