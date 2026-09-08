const FORMAT_ROOT = normpath(joinpath(@__DIR__, ".."))

function formatter_paths()
    paths = String[
        joinpath(FORMAT_ROOT, "src"),
        joinpath(FORMAT_ROOT, "ext"),
        joinpath(FORMAT_ROOT, "scripts"),
        joinpath(FORMAT_ROOT, "test"),
        joinpath(FORMAT_ROOT, "examples"),
    ]
    return filter(ispath, paths)
end
