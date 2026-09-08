include(joinpath(@__DIR__, "..", "..", "ExampleSupport.jl"))
using .ExampleSupport
using .ExampleSupport.WannierNLQG

# Synthetic interface example; the preset mesh is not a convergence recommendation.
const DEMONSTRATION_K_MESH = (200, 200)

"""Build the ordinary example; override `k_mesh = (2, 2)` for an explicit smoke run."""
function build_config(;
    k_mesh = DEMONSTRATION_K_MESH,
    output_root = nothing,
    progress_enabled = true,
)
    return TaskConfig(
        model = ModelInput(
            case_root = ExampleSupport.PACKAGE_ROOT,
            model_file = ExampleSupport.synthetic_model_file(),
            real_space_operator_bundle_file = ExampleSupport.synthetic_operator_bundle_file(),
            real_space_replica_policy = "minimum_distance",
            wsvec_file = ExampleSupport.synthetic_wsvec_file(),
            mp_grid = (2, 1, 1),
            wannier_center_convention = "Convention_II",
        ),
        sampling = KSlice(
            k_mesh = k_mesh,
            spatial_dimension = 2,
            origin = (0.0, 0.0, 0.0),
            vector_1 = (1.0, 0.0, 0.0),
            vector_2 = (0.0, 1.0, 0.0),
        ),
        tasks = [
            TaskSpec(
                id = "kslice_shift_spin_current_conventional",
                quantity = "SSCK",
                method = "Conventional",
                physics = OpticalParameters(
                    photon_energies = Float64[1.0],
                    fermi_energy = 0.0,
                    temperature = 0.0,
                ),
                numerics = OpticalNumerics(
                    broadening = 0.060,
                    broadening_type = "Gaussian",
                    transition_window_factor = 5.0,
                    denominator_regularization = 0.001,
                    degeneracy_threshold = 0.002,
                    band_window_size = -1,
                ),
                observable = KSliceSelection(
                    component = TensorComponent(2, 2, 2, 2),
                    bands = Transition(conduction = [3, 4], valence = [1, 2]),
                ),
            ),
        ],
        execution = ExecutionOptions(fourier_backend = "direct"),
        output = OutputOptions(
            output_root = ExampleSupport.example_output_root(
                "kslice_shift_spin_current_conventional",
                output_root,
            ),
            system_name = "synthetic_demo",
            progress_enabled = progress_enabled,
            progress_percent_interval = 5,
        ),
    )
end

abspath(PROGRAM_FILE) == abspath(@__FILE__) && ExampleSupport.run_and_report(build_config())
