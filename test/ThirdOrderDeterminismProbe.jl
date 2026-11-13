using WannierNLQG, LinearAlgebra
BLAS.set_num_threads(1)
output, backend=ARGS
root=dirname(@__DIR__)
model=ModelInput(
    model_file = joinpath(root, "examples/fixtures/synthetic_runtime/synthetic_tb.dat"),
)
tasks=[
    TaskSpec(
        id = "jc",
        quantity = "JC",
        physics = JerkParameters(
            photon_energies = [0.73, 1.1],
            fermi_energy = 0.0,
            temperature = 300.0,
        ),
        observable = TensorComponents(TensorComponent(1, 1, 2, 1), TensorComponent(3, 2, 1, 3)),
    ),
    TaskSpec(
        id = "thg",
        quantity = "THG",
        physics = THGParameters(
            photon_energies = [0.03, 0.73],
            fermi_energy = 0.0,
            temperature = 300.0,
            formulation = :both,
        ),
        observable = TensorComponents(TensorComponent(1, 1, 2, 1), TensorComponent(3, 2, 1, 3)),
    ),
    TaskSpec(
        id = "ic",
        quantity = "IC",
        physics = OpticalParameters(
            photon_energies = [0.73],
            fermi_energy = 0.0,
            temperature = 300.0,
        ),
    ),
]
WannierNLQG.run(
    TaskConfig(
        model = model,
        sampling = BZMesh(k_mesh = (3, 3, 3), spatial_dimension = 3),
        tasks = tasks,
        execution = ExecutionOptions(
            fourier_backend = backend,
            NKFFT = backend=="Mixed" ? (3, 3, 3) : nothing,
        ),
        output = OutputOptions(output_root = output, progress_enabled = false),
    ),
)
