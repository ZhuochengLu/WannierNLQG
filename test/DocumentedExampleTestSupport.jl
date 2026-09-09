const DOCUMENTED_EXAMPLE_ROOT = joinpath(ROOT, "examples", "tasks")

function load_documented_example(path::AbstractString, index::Int)
    example_module = Module(Symbol("SelfContainedDocumentedExample", index))
    Core.eval(example_module, :(include(path::AbstractString) = Base.include(@__MODULE__, path)))
    Base.include(example_module, path)
    isdefined(example_module, :build_config) || error("$(path) does not define build_config")
    return example_module
end

const DOCUMENTED_EXAMPLE_TEST_SUPPORT_LOADED = true
