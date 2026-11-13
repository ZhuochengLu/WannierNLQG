const SYMMETRY_FOUNDATION_EXTENSION_NAME = :WannierNLQGSymmetryFoundationExt
const SYMMETRY_FOUNDATION_EXTENSION_LOCK = ReentrantLock()
const SYMMETRY_FOUNDATION_SPGLIB_PKG_ID =
    Base.PkgId(Base.UUID("f761d5c5-86db-4880-b97f-9680a7cccfb5"), "Spglib")

"""Resolve the existing geometry dependency only for a requested structural band path.

Use Julia's normal package/depot resolver and import lock. This does not install
dependencies, change versions, or substitute a geometry implementation.
"""
function _load_band_geometry!()
    package = Base.PkgId(Base.UUID("23470ee3-d0df-4052-8b1a-8cbd6363e7f0"), "Brillouin")
    Base.locate_package(package) === nothing && throw(
        ArgumentError(
            "Automatic structural band paths require the locked Brillouin geometry " *
            "dependency and its Qhull artifact in the selected depot. Complete " *
            "dependency readiness before requesting geometry; no installation was attempted.",
        ),
    )
    return Base.require(package)
end

"""Return the active symmetry-foundation extension, or `nothing` before activation."""
function _active_symmetry_foundation_extension()
    return Base.get_extension(parentmodule(@__MODULE__), SYMMETRY_FOUNDATION_EXTENSION_NAME)
end

"""Import the weak-dependency triggers that activate the shared extension."""
function _import_symmetry_foundation_extension_triggers!()
    Base.require(SYMMETRY_FOUNDATION_SPGLIB_PKG_ID)
    # The declared UUIDs use the same dependency/cache resolver in both modes.
    # No consumer in this facade relies on imported dependency bindings.
    Base.require(Base.PkgId(Base.UUID("f67ccb44-e63f-5c2f-98bd-6dc0ccc4ba2f"), "HDF5"))
    Base.require(Base.PkgId(Base.UUID("0f8b85d8-7281-11e9-16c2-39a750bddbf1"), "JSON3"))
    return nothing
end

"""Activate the shared extension once and report whether world-age bridging is needed."""
function _load_symmetry_foundation_extension!()
    lock(SYMMETRY_FOUNDATION_EXTENSION_LOCK)
    try
        extension = _active_symmetry_foundation_extension()
        extension === nothing || return extension, false
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
