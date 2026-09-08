using WannierNLQG

loaded(name::AbstractString) = any(package -> package.name == name, keys(Base.loaded_modules))

mode = only(ARGS[1:1])
if mode == "off"
    loaded("JSON3") && error("ordinary package entry unexpectedly loaded JSON3")
    loaded("Spglib") && error("ordinary package entry unexpectedly loaded Spglib")
    println("mode=off json3=false spglib=false")
elseif mode == "enabled"
    length(ARGS) in (4, 5) ||
        error("enabled probe expects artifact, model, output directory, and optional policy")
    artifact, model, output = ARGS[2:4]
    policy = length(ARGS) == 5 ? ARGS[5] : "strict"
    config = WannierNLQG.Runtime.EffectiveTaskConfig(
        tasks = [("SC", "Conventional", "Integral")],
        k_mesh = (1, 1, 1),
        fourier_backend = "direct",
        photon_energies = [0.1],
        spatial_dimension = 3,
        model_file = model,
        case_root = pwd(),
        output_root = output,
        system_name = "probe",
        response_symmetry_file = artifact,
        response_symmetry_policy = policy,
        progress_enabled = false,
    )
    result = WannierNLQG.run(config)
    all(isfile, result.outputs) || error("enabled response-symmetry probe produced no output")
    loaded("JSON3") || error("enabled response-symmetry runtime did not load JSON3")
    loaded("Spglib") || error("enabled response-symmetry group classification did not load Spglib")
    println("mode=enabled json3=true spglib=true")
else
    error("unknown response-symmetry probe mode $(repr(mode))")
end
