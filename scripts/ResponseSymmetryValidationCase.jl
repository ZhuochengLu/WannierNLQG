#!/usr/bin/env julia

# Fresh-process response-symmetry validation case.  This script is deliberately
# accepts an explicit model and optional Packed operator bundle so validation
# remains independent of any material-data warehouse.

using WannierNLQG

length(ARGS) == 7 || error(
    "usage: ResponseSymmetryValidationCase.jl MODE TASKSET OUTPUT MODEL_OR_SEED ARTIFACT BACKEND MESH",
)

const MODE, TASKSET, OUTPUT_ROOT, MODEL_OR_SEED, ARTIFACT, BACKEND, MESH_TEXT = ARGS
const MESH_SIZE = parse(Int, MESH_TEXT)
const ENABLED = MODE == "on"
const POLICY = get(ENV, "WANNIERNLQG_RESPONSE_SYMMETRY_POLICY", "diagnostic")
MODE in ("off", "on") || error("MODE must be off or on")
TASKSET in ("nonspin", "legacy", "spin", "single") ||
    error("TASKSET must be nonspin, legacy, spin, or single")
BACKEND in ("direct", "mixed", "auto") || error("unsupported backend $(BACKEND)")

const TASKS = if TASKSET == "nonspin"
    [
        ("SC", "Conventional", "Integral"),
        ("SC", "Projector", "Integral"),
        ("SC", "Geometric_Loop", "Integral"),
        ("SC", "Wilson_Loop", "Integral"),
        ("IC", "Conventional", "Integral"),
    ]
elseif TASKSET == "spin"
    [("SSC", "Conventional", "Integral"), ("ISC", "Conventional", "Integral")]
elseif TASKSET == "legacy"
    [
        ("SC", "Conventional", "Integral"),
        ("SC", "Geometric_Loop", "Integral"),
        ("SC", "Wilson_Loop", "Integral"),
        ("IC", "Conventional", "Integral"),
    ]
else
    [("SC", "Conventional", "Integral")]
end

function common_keywords()
    mixed =
        BACKEND == "direct" ? (; NKdiv = nothing, NKFFT = nothing) :
        (; NKdiv = (2, 2), NKFFT = (max(1, MESH_SIZE ÷ 2), max(1, MESH_SIZE ÷ 2)))
    return (;
        tasks = TASKS,
        case_root = pwd(),
        output_root = abspath(OUTPUT_ROOT),
        system_name = "response_validation",
        k_mesh = (MESH_SIZE, MESH_SIZE),
        fourier_backend = BACKEND,
        mixed...,
        photon_energies = [0.25, 1.25],
        fermi_energy = 0.0,
        temperature = 0.0,
        broadening = 0.060,
        broadening_type = "Gaussian",
        transition_window_factor = 5.0,
        denominator_regularization = 0.001,
        spatial_dimension = 2,
        band_window_size = -1,
        tensor_indices = TASKSET == "spin" ? (2, 2, 2, 2) : (2, 2, 2),
        band_selection = ([3, 4], [1, 2]),
        photon_momentum = (0.0, 0.0, 0.0),
        finite_difference_step = 0.0001,
        wannier_center_convention = "Convention_II",
        degeneracy_threshold = 0.002,
        progress_enabled = true,
        progress_percent_interval = 1,
        progress_verbosity = "quiet",
    )
end

function build_config()
    input = (; model_file = abspath(MODEL_OR_SEED))
    exact_operator_input =
        haskey(ENV, "WANNIERNLQG_VALIDATION_PROJECTOR_BUNDLE") &&
        :real_space_operator_bundle_file in fieldnames(WannierNLQG.Runtime.EffectiveTaskConfig) ?
        (;
            real_space_operator_bundle_file = abspath(
                ENV["WANNIERNLQG_VALIDATION_PROJECTOR_BUNDLE"],
            ),
        ) : (;)
    if ENABLED
        return WannierNLQG.Runtime.EffectiveTaskConfig(;
            common_keywords()...,
            input...,
            exact_operator_input...,
            response_symmetry_file = abspath(ARTIFACT),
            response_symmetry_policy = POLICY,
        )
    end
    return WannierNLQG.Runtime.EffectiveTaskConfig(;
        common_keywords()...,
        input...,
        exact_operator_input...,
    )
end

result = WannierNLQG.run(build_config())
for path in sort(result.outputs)
    println("OUTPUT=" * abspath(path))
end
println("METADATA=" * abspath(result.metadata_path))
println("PROGRESS_JSONL=" * abspath(result.progress_jsonl_path))
