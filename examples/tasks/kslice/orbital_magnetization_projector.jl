include(joinpath(@__DIR__, "..", "..", "ExampleSupport.jl"))
using .ExampleSupport
using .ExampleSupport.WannierNLQG

# Explicit closed three-dimensional model; this does not qualify a material input.
const DEMONSTRATION_K_MESH = (24, 24)

"""Build this synthetic task; use a two-point mesh per sampled axis for a smoke run."""
function build_config(;
    k_mesh = DEMONSTRATION_K_MESH,
    output_root = nothing,
    progress_enabled = true,
)
    return TaskConfig(
        model = ModelInput(
            model_file = joinpath(
                ExampleSupport.PACKAGE_ROOT,
                "examples",
                "fixtures",
                "spectral_response",
                "closed_tb.dat",
            ),
        ),
        sampling = KSlice(
            k_mesh = k_mesh,
            spatial_dimension = 3,
            origin = (0.0, 0.0, 0.0),
            vector_1 = (1.0, 0.0, 0.0),
            vector_2 = (0.0, 1.0, 0.0),
        ),
        tasks = [
            TaskSpec(
                id = "kslice_orbital_magnetization_projector",
                quantity = "orbital_magnetization",
                method = "Projector",
                physics = OrbitalMagnetizationParameters(
                    fermi_energies = Float64[0.13],
                    temperature = 300.0,
                    input_semantics = :defined_finite_model,
                ),
                observable = KSliceSelection(component = TensorComponent(3), bands = AllBands()),
            ),
        ],
        execution = ExecutionOptions(fourier_backend = "direct"),
        output = OutputOptions(
            output_root = ExampleSupport.example_output_root(
                "kslice_orbital_magnetization_projector",
                output_root,
            ),
            system_name = "synthetic_demo",
            progress_enabled = progress_enabled,
        ),
    )
end

abspath(PROGRAM_FILE) == abspath(@__FILE__) && WannierNLQG.run(build_config())
