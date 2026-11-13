# Test-only exact Pkg.test command/environment observation. No MPI ranks are launched.
import JSON3
function capture_mpi_admission(command::Cmd, extra_env, filename::AbstractString)
    effective = addenv(command, Dict(extra_env))
    argv = collect(effective)
    environment =
        effective.env === nothing ? Dict(ENV) :
        Dict{String, String}(
            String(parts[1]) => String(parts[2]) for
            parts in (split(item, "="; limit = 2) for item in effective.env)
        )
    root = abspath(get(ENV, "WANNIERNLQG_TEST_OUTPUT_ROOT", ""))
    isempty(get(ENV, "WANNIERNLQG_TEST_OUTPUT_ROOT", "")) &&
        error("MPI admission capture requires an explicit test output root")
    output = abspath(filename)
    relative = relpath(output, root)
    (relative == ".." || startswith(relative, "../") || isabspath(relative)) &&
        error("MPI admission capture must remain inside its test output root")
    ispath(output) && error("MPI admission capture output must be fresh")
    prefixes =
        ("SLURM_", "PBS_", "LSB_", "PMI_", "PMIX_MCA_", "OMPI_MCA_", "PRTE_MCA_", "DYLD_", "LD_")
    keys = Set((
        "HOME",
        "OPAL_PREFIX",
        "PRTE_PREFIX",
        "PMIX_PREFIX",
        "OMPI_PREFIX",
        "PMIX_SERVER_URI",
        "PMIX_SERVER_URI2",
        "PMIX_SERVER_URI21",
        "PMIX_SERVER_URI3",
        "PMIX_SERVER_URI4",
        "PMIX_NAMESPACE",
        "JULIA_PROJECT",
        "JULIA_LOAD_PATH",
        "JULIA_DEPOT_PATH",
    ))
    selected = Dict(
        key => value for (key, value) in environment if
        key in keys || any(startswith(key, prefix) for prefix in prefixes)
    )
    launcher = realpath(first(argv))
    ancestors = String[]
    current = dirname(launcher)
    while true
        push!(ancestors, current)
        parent = dirname(current)
        parent == current && break
        current = parent
    end
    cellar = findfirst(path -> basename(path) == "Cellar", ancestors)
    etc =
        cellar === nothing ? joinpath(dirname(dirname(launcher)), "etc") :
        joinpath(dirname(ancestors[cellar]), "etc")
    home = get(environment, "HOME", "")
    paths = vcat(
        [joinpath(home, "." * name, "mca-params.conf") for name in ("openmpi", "prte", "pmix")],
        [joinpath(etc, name * "-mca-params.conf") for name in ("openmpi", "prte", "pmix")],
    )
    defaults = map(paths) do path
        if !ispath(path)
            (; path, exists = false, active_lines = 0, read_error = nothing)
        else
            try
                count = sum(
                    line -> !isempty(strip(line)) && !startswith(strip(line), "#"),
                    readlines(path),
                )
                (; path, exists = true, active_lines = count, read_error = nothing)
            catch error
                (;
                    path,
                    exists = true,
                    active_lines = nothing,
                    read_error = sprint(showerror, error),
                )
            end
        end
    end
    mkpath(dirname(output))
    # Pkg removes this temporary project after test exit. Preserve its actual
    # dependency/preferences context before recording a replayable command.
    sandbox_source = dirname(Base.active_project())
    replay_directory = joinpath(root, "pkg-sandbox-replay")
    ispath(replay_directory) && error("MPI replay project must be fresh")
    mkpath(replay_directory)
    for name in ("Project.toml", "Manifest.toml", "JuliaLocalPreferences.toml")
        source = joinpath(sandbox_source, name)
        isfile(source) || error("MPI replay requires actual sandbox file: $name")
        cp(source, joinpath(replay_directory, name); force = false)
    end
    record = (;
        schema = "wanniernlqg.mpi-admission-capture/1",
        argv,
        replay_directory,
        replay_files = ["Project.toml", "Manifest.toml", "JuliaLocalPreferences.toml"],
        resolved_launcher = launcher,
        selected_environment = selected,
        parameter_defaults = defaults,
        pid = getpid(),
        scientific_execution = false,
        active_project = Base.active_project(),
        loaded_project_path = Base.pkgdir(WannierNLQG),
    )
    write(output, JSON3.write(record))
    return nothing
end
