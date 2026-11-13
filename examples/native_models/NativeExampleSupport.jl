using WannierNLQG
using LinearAlgebra

"""Build a small diagnostic shift-current task; no convergence is implied."""
function shift_config(model, sampling, output_root)
    return TaskConfig(
        model = model,
        sampling = sampling,
        tasks = [
            TaskSpec(
                id = "shift",
                quantity = "SC",
                method = "Conventional",
                physics = OpticalParameters(
                    photon_energies = [0.5, 1.0, 1.5, 2.0],
                    fermi_energy = 0.0,
                    temperature = 0.0,
                ),
                numerics = Numerics(broadening = 0.1),
                observable = FullTensor(),
            ),
        ],
        execution = ExecutionOptions(fourier_backend = "direct"),
        output = OutputOptions(
            output_root = output_root,
            progress_enabled = false,
            response_output_digits = 16,
        ),
    )
end
