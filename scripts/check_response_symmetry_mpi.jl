#!/usr/bin/env julia

using JSON3
using LinearAlgebra
using MPI
using SHA
using WannierNLQG
import WannierNLQG.Runtime: mpi_process_rank, mpi_process_size

length(ARGS) == 1 || error("usage: check_response_symmetry_mpi.jl EXPECTED_MPI_SIZE")
const EXPECTED_SIZE = parse(Int, only(ARGS))
const ROOT = abspath(normpath(joinpath(@__DIR__, "..")))
const FIXTURE_ROOT = joinpath(ROOT, "examples", "fixtures", "synthetic_runtime")
const MODEL_FILE = joinpath(FIXTURE_ROOT, "synthetic_tb.dat")
const OPERATOR_BUNDLE_FILE = joinpath(FIXTURE_ROOT, "synthetic_operators.h5")
const WSVEC_FILE = joinpath(FIXTURE_ROOT, "synthetic_wsvec.dat")
const TEST_OUTPUT_ROOT = normpath(get(ENV, "WANNIERNLQG_TEST_OUTPUT_ROOT", tempdir()))
const OUTROOT = joinpath(TEST_OUTPUT_ROOT, "response_symmetry_mpi_$(EXPECTED_SIZE)")
const ARTIFACT = joinpath(TEST_OUTPUT_ROOT, "response_symmetry_mpi_artifact.json")
const STRUCTURE_FILE = joinpath(TEST_OUTPUT_ROOT, "response_symmetry_mpi_class19.vasp")

MPI.Initialized() || MPI.Init()

sha256_file(path) =
    open(path, "r") do io
        bytes2hex(SHA.sha256(io))
    end
matrix_rows(matrix) =
    [[matrix[row, column] for column in axes(matrix, 2)] for row in axes(matrix, 1)]

# Extract the deterministic symmetry-report section, excluding MPI/timing metadata.
function response_symmetry_report_block(text::AbstractString)
    block_start = findfirst("RESPONSE SYMMETRY\n", text)
    block_start === nothing && error("human-readable report lacks RESPONSE SYMMETRY")
    block_end = findnext("\nDONE\n", text, last(block_start) + 1)
    block_end === nothing && error("human-readable report lacks DONE after RESPONSE SYMMETRY")
    return text[first(block_start):(first(block_end) - 1)]
end

# Full reports carry rank- and time-dependent metadata; validate their required
# structure while reserving byte-exact comparison for the deterministic block.
function validate_full_report_structure(text::AbstractString)
    for heading in
        ("BANNER", "TASK BUNDLE", "NUMERICS", "OUTPUTS", "TIMING", "RESPONSE SYMMETRY", "DONE")
        occursin(heading, text) || error("human-readable report lacks required $(heading) section")
    end
    return true
end

if mpi_process_rank() == 0
    mkpath(dirname(ARTIFACT))
    if EXPECTED_SIZE == 1
        # A generic orbit of orthorhombic 222 with axial +z moments resolves to
        # the Type-III class 19 operation set. The public display convention
        # chooses the equivalent-axis spelling 2'22', exercising a renamed class.
        open(STRUCTURE_FILE, "w") do io
            write(
                io,
                "WannierNLQG resolved class-19 MPI fixture\n" *
                "1.0\n" *
                "3.0 0.0 0.0\n" *
                "0.0 4.0 0.0\n" *
                "0.0 0.0 5.0\n" *
                "X\n" *
                "4\n" *
                "Direct\n" *
                "0.123 0.234 0.345\n" *
                "0.123 0.766 0.655\n" *
                "0.877 0.234 0.655\n" *
                "0.877 0.766 0.345\n",
            )
        end
        WannierNLQG.Symmetrization.write_response_symmetry_artifact(
            ARTIFACT;
            structure_file = STRUCTURE_FILE,
            structure_format = :poscar,
            model_file = OPERATOR_BUNDLE_FILE,
            magnetic_moments_cartesian = [0.0 0.0 0.0 0.0; 0.0 0.0 0.0 0.0; 1.0 1.0 1.0 1.0],
            include_time_reversal = true,
            integrand_covariance_status = "FAIL",
            covariance_max_relative_residual = 1.0e-2,
            overwrite = true,
        )
    else
        isfile(STRUCTURE_FILE) || error("serial response-symmetry structure oracle is missing")
        isfile(ARTIFACT) || error("serial response-symmetry artifact oracle is missing")
    end
end
MPI.Barrier(MPI.COMM_WORLD)

cfg = WannierNLQG.Runtime.EffectiveTaskConfig(
    tasks = [("SC", "Conventional", "Integral"), ("IC", "Conventional", "Integral")],
    case_root = ROOT,
    model_file = MODEL_FILE,
    real_space_operator_bundle_file = OPERATOR_BUNDLE_FILE,
    output_root = OUTROOT,
    system_name = "response_symmetry_mpi",
    k_mesh = (4, 4),
    fourier_backend = "direct",
    photon_energies = [0.25, 1.25],
    fermi_energy = 0.0,
    temperature = 0.0,
    broadening = 0.060,
    broadening_type = "Gaussian",
    transition_window_factor = 5.0,
    denominator_regularization = 0.001,
    spatial_dimension = 2,
    band_window_size = -1,
    tensor_indices = (2, 2, 2),
    band_selection = ([3, 4], [1, 2]),
    real_space_replica_policy = "minimum_distance",
    wsvec_file = WSVEC_FILE,
    mp_grid = (2, 1, 1),
    response_symmetry_file = ARTIFACT,
    response_symmetry_policy = "diagnostic",
    progress_enabled = true,
    progress_percent_interval = 1,
    progress_verbosity = "quiet",
)

result = WannierNLQG.run(cfg)
if mpi_process_rank() == 0
    mpi_process_size() == EXPECTED_SIZE ||
        error("expected MPI size $(EXPECTED_SIZE), got $(mpi_process_size())")
    all(isfile, result.outputs) || error("response symmetry MPI output is missing")
    summary = read(joinpath(OUTROOT, "response_symmetry_summary.json"), String)
    summary_payload = JSON3.read(summary, Dict{String, Any})
    classification = summary_payload["group_classification"]
    full_group = classification["full_magnetic_point_group"]
    Int(full_group["magnetic_point_group_number"]) == 19 ||
        error("response symmetry MPI fixture did not resolve magnetic point-group class 19")
    String(full_group["hermann_mauguin"]) == "2'22'" ||
        error("response symmetry MPI fixture did not use the canonical 2'22' display")
    length(String(full_group["operation_digest"])) == 64 ||
        error("response symmetry MPI fixture lacks its operation digest")
    String(full_group["operation_digest_contract"]) ==
    "wanniernlqg.magnetic-point-group-operations/1.0" ||
        error("response symmetry MPI fixture uses the wrong operation-digest contract")
    progress = read(result.progress_jsonl_path, String)
    occursin("\"mpi_size\":$(EXPECTED_SIZE)", progress) ||
        error("response symmetry MPI progress did not record mpi_size=$(EXPECTED_SIZE)")
    report = read(result.progress_out_path, String)
    validate_full_report_structure(report)
    progress_lines =
        filter(line -> occursin(r"^\s*\d+/\d+\s+\d+/\d+\s+\[", line), split(report, '\n'))
    if EXPECTED_SIZE > 1
        length(progress_lines) == 1 || error(
            "MPI progress must emit one exact final row, got $(length(progress_lines)): $(progress_lines)",
        )
        occursin(r"^\s*9/9\s+5/5\s+", only(progress_lines)) ||
            error("MPI final progress row is not exact global/root-rank completion")
        occursin("100.0%", only(progress_lines)) ||
            error("MPI final progress row did not force 100%")
        occursin("represented=16", only(progress_lines)) ||
            error("MPI final progress row did not report the full represented grid")
        occursin("represented full-grid weight=16", report) ||
            error("MPI final summary did not report the full represented grid")
        !occursin("~9/9", report) ||
            error("MPI final progress still labels an exact global total as estimated")
    end
    if EXPECTED_SIZE == 2
        serial_root = joinpath(TEST_OUTPUT_ROOT, "response_symmetry_mpi_1")
        serial_files =
            sort(filter(path -> endswith(path, ".dat"), readdir(serial_root; join = true)))
        parallel_files = sort(filter(path -> endswith(path, ".dat"), readdir(OUTROOT; join = true)))
        basename.(serial_files) == basename.(parallel_files) ||
            error("response symmetry MPI serial/parallel output inventories differ")
        isempty(serial_files) && error("response symmetry MPI serial oracle is missing")
        for (serial_file, parallel_file) in zip(serial_files, parallel_files)
            read(serial_file) == read(parallel_file) ||
                error("response symmetry MPI output is not byte-exact: $(basename(serial_file))")
        end
        serial_summary = joinpath(serial_root, "response_symmetry_summary.json")
        read(serial_summary) == read(joinpath(OUTROOT, "response_symmetry_summary.json")) ||
            error("response symmetry MPI machine-readable summary is not byte-exact")
        serial_report =
            response_symmetry_report_block(read(joinpath(serial_root, "WannierNLQG.out"), String))
        validate_full_report_structure(read(joinpath(serial_root, "WannierNLQG.out"), String))
        parallel_report = response_symmetry_report_block(report)
        serial_report == parallel_report ||
            error("response symmetry MPI human-readable report block is not byte-exact")
    end
    receipt_status =
        EXPECTED_SIZE == 2 ? "PASS_DATA_SUMMARY_RESPONSE_BLOCK_BYTE_EXACT_ROOT_ONLY" :
        "PASS_SERIAL_ORACLE_ROOT_ONLY"
    println(
        "response symmetry MPI size=$(EXPECTED_SIZE) passed " *
        "status=$(receipt_status) " *
        "data_summary_response_block_byte_exact=$(EXPECTED_SIZE == 2) " *
        "outputs=$(join(result.outputs, ','))",
    )
end
MPI.Barrier(MPI.COMM_WORLD)
MPI.Finalized() || MPI.Finalize()
