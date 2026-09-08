include(joinpath(@__DIR__, "..", "..", "ExampleSupport.jl"))
using .ExampleSupport
using .ExampleSupport.WannierNLQG

"""Build the ordinary path example; use three points per segment for a smoke run."""
function build_config(;
    output_root = nothing,
    kpoints_per_segment = [101, 101, 101, 101],
    progress_enabled = true,
)
    return TaskConfig(
        model = ModelInput(
            case_root = ExampleSupport.PACKAGE_ROOT,
            model_file = ExampleSupport.synthetic_model_file(),
            real_space_replica_policy = "auto",
            wsvec_file = ExampleSupport.synthetic_wsvec_file(),
            mp_grid = (2, 1, 1),
            wigner_seitz_tolerance = 1.0e-5,
            wigner_seitz_search_size = 3,
            wannier_center_convention = "Convention_II",
        ),
        sampling = KPath(
            nodes = [
                ("Γ", (0.0, 0.0, 0.0)),
                ("X", (0.5, 0.0, 0.0)),
                ("S", (0.5, 0.5, 0.0)),
                ("Y", (0.0, 0.5, 0.0)),
                ("Γ", (0.0, 0.0, 0.0)),
            ],
            kpoints_per_segment = kpoints_per_segment,
            spatial_dimension = 2,
        ),
        tasks = [
            TaskSpec(
                id = "band_structure",
                quantity = "Band",
                physics = BandParameters(fermi_energy = 0.0),
                numerics = BandNumerics(hermiticity_tolerance = 1.0e-10),
            ),
        ],
        execution = ExecutionOptions(fourier_backend = "direct"),
        output = OutputOptions(
            output_root = ExampleSupport.example_output_root("band_structure", output_root),
            system_name = "synthetic_demo",
            progress_enabled = progress_enabled,
        ),
    )
end

abspath(PROGRAM_FILE) == abspath(@__FILE__) && ExampleSupport.run_and_report(build_config())
