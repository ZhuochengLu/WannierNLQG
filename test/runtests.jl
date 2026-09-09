using Test
using JuliaFormatter
using WannierNLQG

# Python analysis helpers must not leave bytecode in the release tree while the
# release-whitelist gate runs.
ENV["PYTHONDONTWRITEBYTECODE"] = "1"

const ROOT = normpath(joinpath(@__DIR__, ".."))
const SCRIPT_DIR = joinpath(ROOT, "scripts")
const TEST_MODEL_FILE =
    joinpath(ROOT, "examples", "fixtures", "synthetic_runtime", "synthetic_tb.dat")

include(joinpath(SCRIPT_DIR, "ValidationPolicy.jl"))
include(joinpath(SCRIPT_DIR, "FormatterPaths.jl"))
include(joinpath(@__DIR__, "CITestPlan.jl"))
using .ValidationPolicy
import .CITestPlan

CITestPlan.validate_ci_test_plan()
const TEST_SELECTION = CITestPlan.resolve_test_selection()
const RUN_FAST_TESTS = TEST_SELECTION.mode == "fast"
const RUN_FULL_SHARD = TEST_SELECTION.mode == "full-shard"
const RUN_MPI_TESTS = TEST_SELECTION.mode == "mpi-only"
const MPI_EXECUTABLE = if RUN_MPI_TESTS
    @eval import MPI
    MPI.mpiexec()
else
    nothing
end

println(
    "[test-suite] mode=$(TEST_SELECTION.mode) " *
    "shard=$(something(TEST_SELECTION.shard, "none")) " *
    "fixture=examples/fixtures/synthetic_runtime",
)
println(
    "[test-suite:inventory] fast=$(RUN_FAST_TESTS ? length(CITestPlan.FAST_TEST_FILES) : 0) " *
    "full=$(RUN_FULL_SHARD ? length(CITestPlan.full_shard_files(something(TEST_SELECTION.shard))) : 0) " *
    "mpi=$(RUN_MPI_TESTS ? length(CITestPlan.MPI_GATE_NAMES) + length(CITestPlan.MPI_TEST_FILES) : 0)",
)

function script_cmd(script::AbstractString)
    project = script == "check_format.jl" ? joinpath(ROOT, "test") : ROOT
    return `$(Base.julia_cmd()) --project=$(project) $(joinpath(SCRIPT_DIR, script))`
end

function run_gate(name::AbstractString, command::Cmd; env = Pair{String, String}[])
    cmd = isempty(env) ? command : addenv(command, Dict(env))
    started_ns = time_ns()
    println("[gate:start] name=$(name)")
    flush(stdout)
    flush(stderr)
    process = Base.run(ignorestatus(cmd))
    elapsed_s = (time_ns() - started_ns) / 1.0e9
    if success(process)
        println("[gate:pass] name=$(name) elapsed_s=$(round(elapsed_s; digits = 3))")
    else
        println(
            stderr,
            "[gate:fail] name=$(name) exit_code=$(process.exitcode) " *
            "elapsed_s=$(round(elapsed_s; digits = 3))",
        )
    end
    flush(stdout)
    flush(stderr)
    return success(process)
end

script_succeeds(script::AbstractString; env = Pair{String, String}[]) =
    run_gate(script, script_cmd(script); env)

function format_succeeds()
    started_ns = time_ns()
    ok = all(
        path -> JuliaFormatter.format(path; overwrite = false, verbose = false),
        formatter_paths(),
    )
    elapsed_s = (time_ns() - started_ns) / 1.0e9
    status = ok ? "pass" : "fail"
    stream = ok ? stdout : stderr
    println(
        stream,
        "[gate:$(status)] name=JuliaFormatter elapsed_s=$(round(elapsed_s; digits = 3))",
    )
    return ok
end

function include_test_file(name::AbstractString)
    path = joinpath(@__DIR__, name)
    isfile(path) || error("registered test file is missing: $(path)")
    return include(path)
end

# Shared in-memory writers used by several Fast and Full units.
include_test_file("OperatorBundleTestSupport.jl")
include_test_file("WannierizationFixtureSupport.jl")

const PRE_SHARD_FAST_TEST_FILES = (
    "task_configuration_unit.jl",
    "release_smoke_unit.jl",
    "mpi_runtime_environment_unit.jl",
    "synthetic_runtime_fixture_unit.jl",
    "shared_interpolation_unit.jl",
    "per_task_execution_unit.jl",
    "shared_input_contract_unit.jl",
    "prepared_cleanup_unit.jl",
    "documented_examples_unit.jl",
    "architecture_unit.jl",
    "architecture_contracts_unit.jl",
    "api_snapshot_unit.jl",
    "operator_bundle_runtime_unit.jl",
    "packed_construction_evidence_unit.jl",
    "target_subspace_persistence_unit.jl",
    "band_public_schema_unit.jl",
    "band_public_downstream_unit.jl",
    "storage_schema_compatibility_unit.jl",
    "band_structure_unit.jl",
    "tb_detection_compatibility_boundary_unit.jl",
    "symmetrization_unit.jl",
    "wannierization_config_architecture_unit.jl",
    "representation_compatibility_unit.jl",
    "projection_representation_models_unit.jl",
    "projection_representation_group_algebra_unit.jl",
    "projection_representation_corepresentation_unit.jl",
    "projection_representation_intertwiner_unit.jl",
    "projection_representation_compatibility_unit.jl",
    "projection_representation_search_unit.jl",
    "projection_representation_materialization_unit.jl",
    "vasp_paw_matrix_elements_unit.jl",
    "qe_paw_matrix_elements_unit.jl",
    "wannier_operator_file_protocol_unit.jl",
    "independent_schema_versions_unit.jl",
    "wannier_uiu_generation_unit.jl",
    "wannier_hamiltonian_operator_generation_unit.jl",
    "target_scope_authority_unit.jl",
    "magnetic_wannierization_unit.jl",
    "gauge_aware_symmetrization_unit.jl",
    "wannier_center_replica_policy_unit.jl",
    "mdrs_runtime_unit.jl",
    "packed_spin_fourier_unit.jl",
    "task_registry_unit.jl",
    "berry_external_hct_unit.jl",
    "injection_spin_current_unit.jl",
    "shift_spin_current_unit.jl",
    "zeeman_interband_unit.jl",
    "mixed_fourier_unit.jl",
    "wannier_center_convention_unit.jl",
    "projector_covariant_full_unit.jl",
    "projector_registered_paths_unit.jl",
    "result_writer_precision_unit.jl",
    "fourier_execution_plan_unit.jl",
    "source_gauge_pruning_unit.jl",
    "transition_optimization_unit.jl",
    "evidence_hashing_unit.jl",
    "license_metadata_unit.jl",
    "release_whitelist_unit.jl",
    "response_symmetry_catalog_unit.jl",
    "source_documentation_audit_unit.jl",
)

const PRE_SHARD_FULL_ONLY_TEST_FILES = (
    "per_task_symmetry_unit.jl",
    "per_task_parallel_unit.jl",
    "documented_examples_full_unit.jl",
    "symmetrization_extension_lifecycle_unit.jl",
    "response_symmetry_group_reporting_unit.jl",
    "response_symmetry_unit.jl",
    "wannierization_unit.jl",
    "wannierization_construction_solver_unit.jl",
    "periodic_checkpoint_metadata_unit.jl",
    "solver_stage_lifecycle_unit.jl",
    "storage_schema_fresh_process_unit.jl",
    "paw_scdm_initialization_unit.jl",
    "wannier_gauge_chain_unit.jl",
    "projection_representation_persistence_unit.jl",
    "qe_paw_coefficient_sewing_unit.jl",
    "augmentation_aware_sewing_unit.jl",
    "diagnostic_augmentation_sewing_unit.jl",
    "star_covariant_paw_gauge_unit.jl",
    "diagnostic_symmetry_construction_unit.jl",
    "star_fixed_schema_unification_unit.jl",
    "generator_schema_migration_unit.jl",
    "vasp_paw_spn_unit.jl",
    "wannierization_frozen_initializer_unit.jl",
    "wannierization_diagnostic_export_unit.jl",
    "wannier_operator_profiles_unit.jl",
    "tb_symmetry_qualification_unit.jl",
    "photon_drag_blas_unit.jl",
    "frequency_contraction_prototype_unit.jl",
    "response_exact_optimization_unit.jl",
    "generalized_derivative_gemm_unit.jl",
    "wannierization_thread_determinism_unit.jl",
    "wannierization_fresh_process_unit.jl",
    "vasp_paw_thread_determinism_unit.jl",
    "qe_paw_coefficient_sewing_thread_determinism_unit.jl",
    "qe_paw_matrix_elements_thread_determinism_unit.jl",
    "wannier_hamiltonian_operator_thread_determinism_unit.jl",
    "augmentation_aware_sewing_thread_determinism_unit.jl",
    "star_covariant_paw_gauge_thread_determinism_unit.jl",
)

PRE_SHARD_FAST_TEST_FILES == CITestPlan.FAST_TEST_FILES ||
    error("Fast test plan no longer matches the frozen pre-sharding inventory.")
PRE_SHARD_FULL_ONLY_TEST_FILES == CITestPlan.FULL_ONLY_TEST_FILES ||
    error("Full-only test plan no longer matches the frozen pre-sharding inventory.")

if RUN_FAST_TESTS
    foreach(include_test_file, CITestPlan.FAST_TEST_FILES)
    foreach(include_test_file, CITestPlan.CI_CONTRACT_TEST_FILES)

    @testset "fast readiness gates" begin
        @test format_succeeds()
        serial_env = [
            "OMP_NUM_THREADS" => "1",
            "MKL_NUM_THREADS" => "1",
            "OPENBLAS_NUM_THREADS" => "1",
            "VECLIB_MAXIMUM_THREADS" => "1",
        ]
        for script in FAST_READINESS_SCRIPTS
            @testset "$(script)" begin
                @test script_succeeds(script; env = serial_env)
            end
        end
    end
end

if RUN_FULL_SHARD
    shard = something(TEST_SELECTION.shard)
    foreach(include_test_file, CITestPlan.full_shard_files(shard))
    foreach(include_test_file, CITestPlan.full_shard_auxiliary_files(shard))
    if shard == CITestPlan.FULL_VISUALIZATION_SHARD && isdir(joinpath(@__DIR__, "visualization"))
        include(joinpath(@__DIR__, "visualization", "runtests.jl"))
    end
    if shard == CITestPlan.FULL_NUMERICAL_SCRIPTS_SHARD
        @testset "full numerical scripts" begin
            serial_env = [
                "OMP_NUM_THREADS" => "1",
                "MKL_NUM_THREADS" => "1",
                "OPENBLAS_NUM_THREADS" => "1",
                "VECLIB_MAXIMUM_THREADS" => "1",
            ]
            for script in FULL_READINESS_SCRIPTS
                @test script_succeeds(script; env = serial_env)
            end
            for script in FULL_NUMERICAL_SCRIPTS
                @test script_succeeds(script)
            end
        end
    end
end

if RUN_MPI_TESTS
    mpi_env = [
        "WANNIERNLQG_USE_MPI" => "1",
        "JULIA_NUM_THREADS" => "1",
        "OMP_NUM_THREADS" => "1",
        "MKL_NUM_THREADS" => "1",
        "OPENBLAS_NUM_THREADS" => "1",
        "VECLIB_MAXIMUM_THREADS" => "1",
        # Each child is launched with --project=ROOT. Do not override its load
        # path with the separate test environment: mixed root/test MPI ABI
        # packages can pair an OpenMPI launcher with a PMI client.
    ]
    mpi_cmd =
        `$(MPI_EXECUTABLE) -n 2 $(Base.julia_cmd()) --startup-file=no --threads=1 --project=$(ROOT) $(joinpath(SCRIPT_DIR, "check_mpi_smoke.jl"))`
    @testset "two-rank MPI smoke" begin
        @test run_gate("two-rank MPI smoke", mpi_cmd; env = mpi_env)
    end

    response_script = joinpath(SCRIPT_DIR, "check_response_symmetry_mpi.jl")
    @testset "response symmetry MPI determinism" begin
        @test run_gate(
            "response symmetry MPI size 1",
            `$(Base.julia_cmd()) --startup-file=no --threads=1 --project=$(ROOT) $(response_script) 1`;
            env = mpi_env,
        )
        @test run_gate(
            "response symmetry MPI size 2",
            `$(MPI_EXECUTABLE) -n 2 $(Base.julia_cmd()) --startup-file=no --threads=1 --project=$(ROOT) $(response_script) 2`;
            env = mpi_env,
        )
    end

    foreach(include_test_file, CITestPlan.MPI_TEST_FILES)
end
