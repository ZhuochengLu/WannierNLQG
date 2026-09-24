
using WannierNLQG, LinearAlgebra
BLAS.set_num_threads(1)
output, model, backend=ARGS
rates=SeparateRelaxation(gamma_intra_ev = 0.04, gamma_inter_ev = 0.05)
tasks=TaskSpec[]
for quantity in ("linear_transport", "linear_optical_response", "orbital_magnetization"),
    method in ("Conventional", "Projector")

    physics=quantity=="orbital_magnetization" ?
            OrbitalMagnetizationParameters(
        fermi_energies = Float64[-0.10, 0.13, 0.20],
        temperature = 300.0,
        input_semantics = :defined_finite_model,
    ) :
            quantity=="linear_transport" ?
            LinearTransportParameters(
        fermi_energies = Float64[-0.10, 0.13, 0.20],
        temperature = 300.0,
        relaxation = rates,
    ) :
            LinearOpticalResponseParameters(
        fermi_energy = 0.13,
        temperature = 300.0,
        relaxation = rates,
        photon_energies = [0.0, 0.2, 0.43],
    )
    push!(
        tasks,
        TaskSpec(
            id = quantity*"_"*lowercase(method),
            quantity = quantity,
            method = method,
            physics = physics,
        ),
    )
end
cfg=TaskConfig(
    model = ModelInput(model_file = model),
    sampling = BZMesh(k_mesh = (3, 3, 3)),
    execution = ExecutionOptions(
        fourier_backend = backend,
        NKFFT = backend=="Mixed" ? (3, 3, 3) : nothing,
    ),
    output = OutputOptions(output_root = output, progress_enabled = false),
    tasks = tasks,
)
WannierNLQG.run(cfg)
