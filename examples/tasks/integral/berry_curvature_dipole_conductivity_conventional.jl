include(joinpath(@__DIR__, "..", "..", "ExampleSupport.jl"))
using .ExampleSupport
using .ExampleSupport.WannierNLQG

# Closed synthetic model, not a material or convergence qualification.
const DEMONSTRATION_K_MESH = (8, 8, 8)
function build_config(;
    k_mesh = DEMONSTRATION_K_MESH,
    output_root = nothing,
    progress_enabled = true,
)
    TaskConfig(
        model = ModelInput(
            model_file = joinpath(
                ExampleSupport.PACKAGE_ROOT,
                "examples",
                "fixtures",
                "spectral_response",
                "closed_tb.dat",
            ),
        ),
        sampling = BZMesh(k_mesh = k_mesh, spatial_dimension = 3),
        tasks = [
            TaskSpec(
                id = "berry_curvature_dipole_conductivity",
                quantity = "berry_curvature_dipole_conductivity",
                method = "Conventional",
                physics = BerryMultipoleParameters(
                    fermi_energies = [0.13],
                    temperature = 300.0,
                    relaxation_time_fs = 7.0,
                    integral_form = :fermi_surface,
                ),
                observable = FullTensor(),
            ),
        ],
        execution = ExecutionOptions(fourier_backend = "direct"),
        output = OutputOptions(
            output_root = ExampleSupport.example_output_root(
                "berry_curvature_dipole_conductivity",
                output_root,
            ),
            system_name = "synthetic_demo",
            progress_enabled = progress_enabled,
        ),
    )
end
abspath(PROGRAM_FILE) == abspath(@__FILE__) && WannierNLQG.run(build_config())
