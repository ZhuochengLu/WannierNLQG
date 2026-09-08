module VisualizationLauncher

"""Launch the shared Python renderer without changing numerical result files."""
function launch_visualization(
    kind::AbstractString,
    args::Vector{String},
    entry_script::AbstractString,
)
    python_index = findfirst(==("--python"), args)
    python_request = "python3"
    forwarded = copy(args)
    if python_index !== nothing
        python_index < length(forwarded) || error("--python requires an executable")
        python_request = forwarded[python_index + 1]
        deleteat!(forwarded, python_index:(python_index + 1))
    end
    python = isabspath(python_request) ? python_request : something(Sys.which(python_request), "")
    isempty(python) && error("Python executable not found: $(python_request)")
    backend = joinpath(@__DIR__, "cli.py")
    isfile(backend) || error("visualization backend is missing: $(backend)")
    command = `$(python) $(backend) $(kind) --entry-script $(abspath(entry_script)) $(forwarded)`
    run(command)
    return 0
end

end
