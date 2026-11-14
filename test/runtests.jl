using Test

const TEST_SUITE_STARTED_NS = time_ns()
using JuliaFormatter
using WannierNLQG

# Establish native BLAS state in this actual test process, including cached loads.
import LinearAlgebra
const TEST_BLAS_THREADS_BEFORE = LinearAlgebra.BLAS.get_num_threads()
LinearAlgebra.BLAS.set_num_threads(1)

# Record only declared runtime fields and reject an unexpected BLAS thread state.
function record_test_linear_algebra_state(context)
    blas_threads = LinearAlgebra.BLAS.get_num_threads()
    blas_threads == 1 || error("Package tests require one native BLAS thread")
    println(
        "WANNIERNLQG_TEST_LINEAR_ALGEBRA ",
        (;
            context,
            initial_blas_threads = TEST_BLAS_THREADS_BEFORE,
            blas_threads,
            blas_config = string(LinearAlgebra.BLAS.get_config()),
            julia_version = string(VERSION),
            kernel = string(Sys.KERNEL),
            architecture = string(Sys.ARCH),
            julia_threads = Threads.nthreads(),
        ),
    )
    return nothing
end
record_test_linear_algebra_state("suite-start")

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
include(joinpath(@__DIR__, "ReadinessGateRunner.jl"))
const READINESS_JOBS = ReadinessGateRunner.readiness_jobs()
using .ValidationPolicy
import .CITestPlan

CITestPlan.validate_ci_test_plan()
const TEST_SELECTION = CITestPlan.resolve_test_selection()
const RUN_FAST_TESTS = TEST_SELECTION.mode == "fast"
const RUN_FULL_SHARD = TEST_SELECTION.mode == "full-shard"
const RUN_MPI_TESTS = TEST_SELECTION.mode == "mpi-only"
const MPI_APPLICATION = get(ENV, "WANNIERNLQG_MPI_APPLICATION", "")
isempty(MPI_APPLICATION) ||
    (
        MPI_APPLICATION == "nonorthogonal-adaptive" &&
        RUN_MPI_TESTS &&
        get(ENV, "WANNIERNLQG_TEST_MPI_PROFILE", "") == "bounded11"
    ) ||
    error("unsupported or misplaced MPI application selection")
const TEST_COMPLETION_MODE = isempty(MPI_APPLICATION) ? TEST_SELECTION.mode : "mpi-application"
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
    println("[gate:start] name=JuliaFormatter")
    flush(stdout)
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
    name == "photon_drag_blas_unit.jl" &&
        record_test_linear_algebra_state("before-photon-drag-strict-panels")
    started_ns = time_ns()
    println("[test-file:start] name=$(name)")
    flush(stdout)
    try
        result = include(path)
        elapsed_s = (time_ns() - started_ns) / 1.0e9
        println("[test-file:complete] name=$(name) elapsed_s=$(round(elapsed_s; digits = 3))")
        flush(stdout)
        return result
    catch
        elapsed_s = (time_ns() - started_ns) / 1.0e9
        println(stderr, "[test-file:fail] name=$(name) elapsed_s=$(round(elapsed_s; digits = 3))")
        flush(stderr)
        rethrow()
    end
end

# Shared in-memory writers used by several Fast and Full units.
include_test_file("OperatorBundleTestSupport.jl")
include_test_file("WannierizationFixtureSupport.jl")
include_test_file("ResponseTestSupport.jl")
include_test_file("DocumentedExampleTestSupport.jl")

const PRE_SHARD_FAST_TEST_FILES = (
    "orthogonal_geometry_analytic_unit.jl",
    "berry_geometry_backend_runtime_unit.jl",
    "berry_multipole_dc_unit.jl",
    "berry_multipole_runtime_unit.jl",
    "berry_geometry_fourier_unit.jl",
    "berry_multipole_periodic_unit.jl",
    "berry_multipole_dirac_unit.jl",
    "berry_geometry_multiband_unit.jl",
    "task_configuration_unit.jl",
    "task_input_unit.jl",
    "task_input_energy_axes_unit.jl",
    "task_input_overrides_unit.jl",
    "workflow_task_input_unit.jl",
    "scientific_publication_unit.jl",
    "jc_zero_energy_unit.jl",
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
    "projection_character_reduction_unit.jl",
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
    "mixed_position_component_pack_unit.jl",
    "spectral_block_route_unit.jl",
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
    "wannierization_standard_export_unit.jl",
    "checkpoint_definition_unit.jl",
    "wannier_operator_profiles_unit.jl",
    "tb_symmetry_qualification_unit.jl",
    "tb_status_contract_unit.jl",
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

# Preserve the pre-sharding ordered baseline independently of the new automatic
# Band regression. The authoritative Fast list/digest also fixes its exact order.
count(==("automatic_band_path_unit.jl"), CITestPlan.FAST_TEST_FILES) == 1 ||
    error("Fast test plan must include the automatic Band regression exactly once.")
count(==("optical_momentum_overlap_unit.jl"), CITestPlan.FAST_TEST_FILES) == 1 ||
    error("Fast test plan must include the optical overlap regression exactly once.")

(
    "response_integration_unit.jl",
    "ordinary_calculation_policy_unit.jl",
    "ordinary_io_call_boundary_unit.jl",
    "nonorthogonal_localized_unit.jl",
    "nonorthogonal_io_runtime_unit.jl",
    "nonorthogonal_spin_convention_unit.jl",
    "nonorthogonal_spin_charge_unit.jl",
    "native_model_inputs_unit.jl",
    "preparation_storage_unit.jl",
    "second_harmonic_unit.jl",
    "linear_orbital_response_unit.jl",
    "subspace_geometry_completion_unit.jl",
    "linear_orbital_runtime_unit.jl",
    PRE_SHARD_FAST_TEST_FILES...,
) == filter(
    name -> !(
        name in (
            "eskernel_unit.jl",
            "hdf5_attribute_backend_unit.jl",
            "numerics_unit.jl",
            "third_order_unit.jl",
            "third_order_runtime_unit.jl",
            "automatic_band_path_unit.jl",
            "paired_photon_momentum_unit.jl",
            "optical_momentum_overlap_unit.jl",
            CITestPlan.SCIENTIFIC_REPAIR_FAST_TEST_FILES...,
        )
    ),
    CITestPlan.FAST_TEST_FILES,
) || error(
    "Fast test plan must retain the frozen inventory and add SHG and bounded preparation contracts.",
)
(
    "wannierization_restart_input_definition_unit.jl" in CITestPlan.FULL_ONLY_TEST_FILES &&
    "ordinary_posthoc_tb_qualification_unit.jl" in CITestPlan.FULL_ONLY_TEST_FILES &&
    "disk_bounded_gauge_unit.jl" in CITestPlan.FULL_ONLY_TEST_FILES &&
    "parallelogram_region_unit.jl" in CITestPlan.FULL_ONLY_TEST_FILES &&
    "parallelepiped_region_unit.jl" in CITestPlan.FULL_ONLY_TEST_FILES &&
    filter(
        name -> !(
            name in (
                "wannierization_restart_input_definition_unit.jl",
                "native_model_symmetry_unit.jl",
                "native_model_responses_unit.jl",
                "native_model_region_unit.jl",
                "parallelogram_region_unit.jl",
                "parallelepiped_region_unit.jl",
                "finite_domain_runtime_unit.jl",
                "ordinary_posthoc_tb_qualification_unit.jl",
                "disk_bounded_gauge_unit.jl",
                "fermi_vector_contract_unit.jl",
                "linear_orbital_parallel_unit.jl",
                "third_order_parallel_unit.jl",
                "operator_task_selection_unit.jl",
            )
        ),
        CITestPlan.FULL_ONLY_TEST_FILES,
    ) == PRE_SHARD_FULL_ONLY_TEST_FILES
) || error(
    "Full-only test plan must preserve the frozen inventory and add vector response, parallel response, operator-task, ordinary post-hoc, and disk-bounded gauge contracts.",
)

if RUN_FAST_TESTS
    foreach(include_test_file, CITestPlan.FAST_TEST_FILES)
    foreach(include_test_file, CITestPlan.CI_CONTRACT_TEST_FILES)

    @testset "fast readiness gates" begin
        @test format_succeeds()
        entries = [(script, script_cmd(script)) for script in FAST_READINESS_SCRIPTS]
        output_root = get(ENV, "WANNIERNLQG_TEST_OUTPUT_ROOT", "")
        isempty(output_root) && (output_root = mktempdir())
        records =
            ReadinessGateRunner.run_readiness_gates(entries; jobs = READINESS_JOBS, output_root)
        for record in records
            if record.exit_code != 0
                println("[gate:failure-log] name=$(record.name) log=$(record.log_path)")
                print(read(record.log_path, String))
                flush(stdout)
            end
            @testset "$(record.name)" begin
                @test record.exit_code == 0
            end
        end
    end
end

if RUN_FULL_SHARD
    shard = something(TEST_SELECTION.shard)
    foreach(include_test_file, CITestPlan.full_shard_files(shard))
    foreach(include_test_file, CITestPlan.full_shard_auxiliary_files(shard))
    if shard == CITestPlan.FULL_VISUALIZATION_SHARD && isdir(joinpath(@__DIR__, "visualization"))
        include_test_file(joinpath("visualization", "runtests.jl"))
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

if RUN_MPI_TESTS && isempty(MPI_APPLICATION)
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
    capture_output = get(ENV, "WANNIERNLQG_MPI_ADMISSION_CAPTURE", "")
    if !isempty(capture_output)
        include(joinpath(@__DIR__, "MPIAdmissionCapture.jl"))
        capture_mpi_admission(mpi_cmd, mpi_env, capture_output)
        println("MPI_ADMISSION_CAPTURE_ONLY_NO_MPI_COMPUTATION")
        # This is a preflight receipt, never a smoke or Full completion marker.
        exit(78) # expected preflight-only terminal; cannot make a Full selection PASS
    end
    @testset "two-rank MPI smoke" begin
        @test run_gate("two-rank MPI smoke", mpi_cmd; env = mpi_env)
    end

    response_script = joinpath(SCRIPT_DIR, "check_response_symmetry_mpi.jl")
    @testset "response symmetry MPI determinism" begin
        # One caller-owned local fixture survives both child processes. Numerical
        # outputs stay in the declared suite output root; source guards stay strict.
        mktempdir() do fixture_root
            fixture_env = [mpi_env; "WANNIERNLQG_RESPONSE_MPI_FIXTURE_ROOT" => fixture_root]
            @test run_gate(
                "response symmetry MPI size 1",
                `$(Base.julia_cmd()) --startup-file=no --threads=1 --project=$(ROOT) $(response_script) 1`;
                env = fixture_env,
            )
            @test run_gate(
                "response symmetry MPI size 2",
                `$(MPI_EXECUTABLE) -n 2 $(Base.julia_cmd()) --startup-file=no --threads=1 --project=$(ROOT) $(response_script) 2`;
                env = fixture_env,
            )
        end
    end

    foreach(include_test_file, CITestPlan.MPI_TEST_FILES)
end

if !isempty(MPI_APPLICATION)
    include_test_file("nonorthogonal_adaptive_mpi_unit.jl")
    println("[mpi-application:complete] application=$(MPI_APPLICATION)")
    flush(stdout)
end

println(
    "[test-suite:complete] mode=$(TEST_COMPLETION_MODE) " *
    "shard=$(something(TEST_SELECTION.shard, "none")) " *
    "elapsed_s=$(round((time_ns() - TEST_SUITE_STARTED_NS) / 1.0e9; digits = 3))",
)
flush(stdout)
