#!/usr/bin/env julia

const ROOT = normpath(joinpath(@__DIR__, ".."))
const TEST_WANNIER_CENTER_CONVENTION = get(ENV, "WANNIERNLQG_TEST_WCC", "Convention_II")
const FIXTURE_ROOT = joinpath(ROOT, "examples", "fixtures", "synthetic_runtime")
const MODEL_FILE = joinpath(FIXTURE_ROOT, "synthetic_tb.dat")
const OPERATOR_BUNDLE_FILE = joinpath(FIXTURE_ROOT, "synthetic_operators.h5")
const WSVEC_FILE = joinpath(FIXTURE_ROOT, "synthetic_wsvec.dat")
const OUTROOT = joinpath(
    normpath(get(ENV, "WANNIERNLQG_TEST_OUTPUT_ROOT", tempdir())),
    "wanniernlqg_mpi_smoke_$(lowercase(TEST_WANNIER_CENTER_CONVENTION))",
)

using WannierNLQG
import WannierNLQG: run
import WannierNLQG.Runtime: mpi_process_rank

cfg = WannierNLQG.Runtime.EffectiveTaskConfig(
    tasks = [("SC", "Conventional", "Integral"), ("IC", "Conventional", "Integral")],
    case_root = ROOT,
    model_file = MODEL_FILE,
    real_space_operator_bundle_file = OPERATOR_BUNDLE_FILE,
    k_mesh = (2, 2),
    # Use two explicit coarse blocks so this smoke exercises MPI block distribution.
    fourier_backend = "mixed",
    NKdiv = (2, 1),
    NKFFT = (1, 2),
    photon_energies = [2.0],
    fermi_energy = 0.0,
    temperature = 0.0,
    broadening = 0.060,
    broadening_type = "Gaussian",
    transition_window_factor = 1.0e9,
    denominator_regularization = 0.001,
    spatial_dimension = 2,
    band_window_size = 2,
    tensor_indices = (2, 2, 2),
    band_selection = ([3, 4], [1, 2]),
    photon_momentum = (0.005, 0.0, 0.0),
    finite_difference_step = 0.005,
    wannier_center_convention = TEST_WANNIER_CENTER_CONVENTION,
    degeneracy_threshold = 1.0e-2,
    real_space_replica_policy = "minimum_distance",
    wsvec_file = WSVEC_FILE,
    mp_grid = (2, 1, 1),
    output_root = OUTROOT,
    system_name = "mpi_smoke",
)

result = run(cfg)

if mpi_process_rank() == 0
    for path in result.outputs
        isfile(path) || error("missing MPI smoke output $(path)")
    end
    isfile(result.metadata_path) || error("missing MPI smoke metadata")
    isfile(result.progress_out_path) || error("missing MPI smoke progress log")
    progress = read(result.progress_jsonl_path, String)
    occursin("\"mpi_size\":2", progress) ||
        error("MPI smoke did not record mpi_size=2 in $(result.progress_jsonl_path)")
    occursin("\"total_k_local\":2", progress) ||
        error("MPI smoke did not split the four k-points across two ranks")
    println("mpi smoke checks passed outputs=$(join(result.outputs, ","))")
end
