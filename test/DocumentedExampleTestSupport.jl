const DOCUMENTED_EXAMPLE_ROOT = joinpath(ROOT, "examples", "tasks")

function load_documented_example(path::AbstractString, index::Int)
    example_module = Module(Symbol("SelfContainedDocumentedExample", index))
    Core.eval(example_module, :(include(path::AbstractString) = Base.include(@__MODULE__, path)))
    Base.include(example_module, path)
    isdefined(example_module, :build_config) || error("$(path) does not define build_config")
    return example_module
end

const DOCUMENTED_EXAMPLE_TEST_SUPPORT_LOADED = true

"""Identify the three explicitly three-dimensional closed-model example families."""
function documented_example_is_spectral(path)
    return any(
        startswith(basename(path), name) for
        name in ("linear_transport_", "linear_optical_response_", "orbital_magnetization_")
    )
end

"""Choose a two-point smoke mesh on each axis supported by the example."""
function documented_example_smoke_mesh(path)
    return documented_example_is_spectral(path) && occursin("/integral/", path) ? (2, 2, 2) : (2, 2)
end
