const SYMMETRY_FOUNDATION_EXTENSION_NAME = :WannierNLQGSymmetryFoundationExt
const SYMMETRY_FOUNDATION_EXTENSION_LOCK = ReentrantLock()
const SYMMETRY_FOUNDATION_SPGLIB_PKG_ID =
    Base.PkgId(Base.UUID("f761d5c5-86db-4880-b97f-9680a7cccfb5"), "Spglib")

"""Return the active symmetry-foundation extension, or `nothing` before activation."""
function _active_symmetry_foundation_extension()
    return Base.get_extension(parentmodule(@__MODULE__), SYMMETRY_FOUNDATION_EXTENSION_NAME)
end

"""Import the weak-dependency triggers that activate the shared extension."""
function _import_symmetry_foundation_extension_triggers!()
    Base.require(SYMMETRY_FOUNDATION_SPGLIB_PKG_ID)
    Base.eval(@__MODULE__, :(import HDF5))
    Base.eval(@__MODULE__, :(import JSON3))
    return nothing
end

"""Activate the shared extension once and report whether world-age bridging is needed."""
function _load_symmetry_foundation_extension!()
    extension = _active_symmetry_foundation_extension()
    extension === nothing || return extension, false
    lock(SYMMETRY_FOUNDATION_EXTENSION_LOCK)
    try
        extension = _active_symmetry_foundation_extension()
        if extension === nothing
            _import_symmetry_foundation_extension_triggers!()
            extension = _active_symmetry_foundation_extension()
            extension === nothing && error(
                "WannierNLQG symmetry-foundation extension did not activate after loading " *
                "Spglib, HDF5, and JSON3",
            )
        end
        return extension, true
    finally
        unlock(SYMMETRY_FOUNDATION_EXTENSION_LOCK)
    end
end

"""Call one extension entry through the minimal lazy-loading world-age bridge."""
function _call_symmetry_foundation_extension(function_name::Symbol, arguments...; keywords...)
    extension, _ = _load_symmetry_foundation_extension!()
    implementation = Base.invokelatest(getproperty, extension, function_name)
    return Base.invokelatest(implementation, arguments...; keywords...)
end
