using WannierNLQG

# A closed synthetic model is used explicitly; no material completion is inferred.
model = joinpath(@__DIR__, "fixtures", "spectral_response", "closed_tb.dat")
output = isempty(ARGS) ? joinpath(mktempdir(), "responses") : abspath(only(ARGS))
rates = SeparateRelaxation(gamma_intra_ev = 0.04, gamma_inter_ev = 0.05)
tasks = TaskSpec[]
for method in ("Conventional", "Projector")
    push!(
        tasks,
        TaskSpec(
            id = "transport_"*lowercase(method),
            quantity = "linear_transport",
            method = method,
            physics = LinearTransportParameters(
                fermi_energies = Float64[0.13],
                temperature = 300.0,
                relaxation = rates,
            ),
        ),
    )
    push!(
        tasks,
        TaskSpec(
            id = "optical_"*lowercase(method),
            quantity = "linear_optical_response",
            method = method,
            physics = LinearOpticalResponseParameters(
                photon_energies = [0.0, 0.2, 0.43],
                fermi_energy = 0.13,
                temperature = 300.0,
                relaxation = rates,
            ),
        ),
    )
    push!(
        tasks,
        TaskSpec(
            id = "magnetization_"*lowercase(method),
            quantity = "orbital_magnetization",
            method = method,
            physics = OrbitalMagnetizationParameters(
                fermi_energies = Float64[0.13],
                temperature = 300.0,
                input_semantics = :defined_finite_model,
            ),
        ),
    )
end
config = TaskConfig(
    model = ModelInput(model_file = model),
    sampling = BZMesh(k_mesh = (5, 5, 5)),
    execution = ExecutionOptions(fourier_backend = "Direct"),
    output = OutputOptions(output_root = output),
    tasks = tasks,
)
result = WannierNLQG.run(config)
println(
    "qualification=$(result.qualification.qualification_status) " *
    "production_eligible=$(result.qualification.production_eligible)",
)
