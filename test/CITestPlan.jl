module CITestPlan

using SHA

export FAST_TEST_FILES,
    CI_CONTRACT_TEST_FILES,
    CI_REQUIRED_JOB_NAMES,
    FULL_ONLY_TEST_FILES,
    FULL_TEST_SHARDS,
    FULL_VISUALIZATION_SHARD,
    FULL_NUMERICAL_SCRIPTS_SHARD,
    MPI_GATE_NAMES,
    MPI_TEST_FILES,
    TEST_MODES,
    TestSelection,
    full_shard_files,
    full_shard_auxiliary_files,
    full_shard_names,
    resolve_test_selection,
    validate_ci_test_plan

const TEST_MODES = ("fast", "full-shard", "mpi-only")

const CI_CONTRACT_TEST_FILES = ("ci_execution_contract_unit.jl",)

const CI_REQUIRED_JOB_NAMES = (
    "fast (ubuntu-latest, Julia 1.10)",
    "fast (ubuntu-latest, Julia current)",
    "fast (macos-latest, Julia 1.10)",
    "fast (macos-latest, Julia current)",
    "full-shard (interfaces-and-symmetry)",
    "full-shard (wannier-core)",
    "full-shard (scientific-contracts)",
    "full-shard (thread-determinism)",
    "full-shard (star-gauge-thread)",
    "mpi-only",
    "ci-required",
)

const FAST_TEST_FILES = (
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

# Frozen from the pre-sharding v1.0.0 runner. This is the authoritative Full-only
# inventory; shards below may redistribute these entries but may not add, omit,
# or duplicate one.
const FULL_ONLY_TEST_FILES = (
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

const FULL_TEST_SHARDS = (
    (
        "interfaces-and-symmetry",
        (
            "per_task_symmetry_unit.jl",
            "per_task_parallel_unit.jl",
            "documented_examples_full_unit.jl",
            "symmetrization_extension_lifecycle_unit.jl",
            "response_symmetry_group_reporting_unit.jl",
            "response_symmetry_unit.jl",
        ),
    ),
    (
        "wannier-core",
        (
            "wannierization_unit.jl",
            "wannierization_construction_solver_unit.jl",
            "periodic_checkpoint_metadata_unit.jl",
        ),
    ),
    (
        "scientific-contracts",
        (
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
        ),
    ),
    (
        "thread-determinism",
        (
            "wannierization_thread_determinism_unit.jl",
            "wannierization_fresh_process_unit.jl",
            "vasp_paw_thread_determinism_unit.jl",
            "qe_paw_coefficient_sewing_thread_determinism_unit.jl",
            "qe_paw_matrix_elements_thread_determinism_unit.jl",
            "wannier_hamiltonian_operator_thread_determinism_unit.jl",
            "augmentation_aware_sewing_thread_determinism_unit.jl",
        ),
    ),
    ("star-gauge-thread", ("star_covariant_paw_gauge_thread_determinism_unit.jl",)),
)

const FULL_VISUALIZATION_SHARD = "scientific-contracts"
const FULL_NUMERICAL_SCRIPTS_SHARD = "scientific-contracts"

# These two drivers preserve Full-only test sections that were formerly hidden
# inside Fast files behind RUN_FULL_TESTS. Their mode branches do not execute the
# ordinary Fast sections.
const FULL_AUXILIARY_TESTS = ((
    "scientific-contracts",
    ("band_structure_unit.jl", "mpi_runtime_compiled_modules_full_unit.jl"),
),)
const FULL_MODE_SCOPED_BASELINE = (
    "band_structure_unit.jl#full-shard",
    "mpi_runtime_environment_unit.jl#compiled-modules-disabled",
)

const MPI_GATE_NAMES =
    ("two-rank MPI smoke", "response symmetry MPI size 1", "response symmetry MPI size 2")

const MPI_TEST_FILES = (
    "mdrs_runtime_mpi_unit.jl",
    "wannierization_raw_z_mpi_unit.jl",
    "wannierization_u_localization_mpi_unit.jl",
    "wannierization_workflow_mpi_unit.jl",
    "per_task_parallel_unit.jl",
    "band_structure_unit.jl",
)

const MPI_BASELINE_ENTRIES = (
    MPI_GATE_NAMES...,
    "mdrs_runtime_mpi_unit.jl",
    "wannierization_raw_z_mpi_unit.jl",
    "wannierization_u_localization_mpi_unit.jl",
    "wannierization_workflow_mpi_unit.jl",
    "per_task_parallel_unit.jl#mpi-only",
    "band_structure_unit.jl#mpi-only",
)

const FAST_LIST_SHA256 = "f8256aca1487c61473430efecbe1e572022d0a9179cb78e81f0d08777bfd41e5"
const FULL_LIST_SHA256 = "4565dd47d952c8ce4cb385d77447cb788d7798172d60a1e704b7b14d1ae98aa1"
const MPI_LIST_SHA256 = "4cfe73e43406ac956b5f77cd055bc9d0420c8df042db2986fb13a8a4b48801f1"
const FULL_MODE_SCOPED_SHA256 = "233ed635f1334414a9c39ce6f8c45379550f3ca81037ea5cd7ed48eb4e2ee62c"

struct TestSelection
    mode::String
    shard::Union{Nothing, String}
end

function _choice(env, name::AbstractString, default::AbstractString, allowed)
    value = strip(get(env, name, default))
    value in allowed ||
        error("Invalid $(name)=$(repr(value)); expected one of $(join(repr.(allowed), ", ")).")
    return value
end

function resolve_test_selection(env = ENV)
    for retired in ("WANNIERNLQG_TEST_LEVEL", "WANNIERNLQG_TEST_MPI")
        haskey(env, retired) &&
            error("$(retired) is retired; use WANNIERNLQG_TEST_MODE and WANNIERNLQG_TEST_SHARD.")
    end

    mode = _choice(env, "WANNIERNLQG_TEST_MODE", "fast", TEST_MODES)
    has_shard = haskey(env, "WANNIERNLQG_TEST_SHARD")
    if mode == "full-shard"
        has_shard || error("WANNIERNLQG_TEST_MODE=full-shard requires WANNIERNLQG_TEST_SHARD.")
        shard = _choice(env, "WANNIERNLQG_TEST_SHARD", "", full_shard_names())
        return TestSelection(mode, shard)
    end
    has_shard && error("WANNIERNLQG_TEST_SHARD is valid only in full-shard mode.")
    return TestSelection(mode, nothing)
end

full_shard_names() = Tuple(first(entry) for entry in FULL_TEST_SHARDS)

function full_shard_files(name::AbstractString)
    for (shard, files) in FULL_TEST_SHARDS
        shard == name && return files
    end
    error("Unknown Full shard $(repr(name)); expected one of $(join(full_shard_names(), ", ")).")
end

function full_shard_auxiliary_files(name::AbstractString)
    for (shard, files) in FULL_AUXILIARY_TESTS
        shard == name && return files
    end
    name in full_shard_names() || error(
        "Unknown Full shard $(repr(name)); expected one of $(join(full_shard_names(), ", ")).",
    )
    return ()
end

_list_digest(entries) = bytes2hex(sha256(join(entries, '\n') * "\n"))

function validate_ci_test_plan()
    length(unique(FAST_TEST_FILES)) == length(FAST_TEST_FILES) ||
        error("Fast test inventory contains duplicates.")
    isempty(intersect(Set(FAST_TEST_FILES), Set(CI_CONTRACT_TEST_FILES))) ||
        error("CI contract tests overlap the frozen scientific Fast inventory.")
    length(unique(FULL_ONLY_TEST_FILES)) == length(FULL_ONLY_TEST_FILES) ||
        error("Full-only test inventory contains duplicates.")
    length(unique(MPI_TEST_FILES)) == length(MPI_TEST_FILES) ||
        error("MPI test inventory contains duplicates.")
    length(unique(full_shard_names())) == length(FULL_TEST_SHARDS) ||
        error("Full shard names are not unique.")

    flattened = reduce(vcat, [collect(files) for (_, files) in FULL_TEST_SHARDS])
    length(flattened) == length(unique(flattened)) || error("Full shard intersection is not empty.")
    Set(flattened) == Set(FULL_ONLY_TEST_FILES) ||
        error("Full shard union differs from the frozen Full-only inventory.")

    _list_digest(FAST_TEST_FILES) == FAST_LIST_SHA256 ||
        error("Fast test inventory differs from the pre-sharding baseline.")
    _list_digest(FULL_ONLY_TEST_FILES) == FULL_LIST_SHA256 ||
        error("Full-only inventory differs from the pre-sharding baseline.")
    _list_digest(MPI_BASELINE_ENTRIES) == MPI_LIST_SHA256 ||
        error("MPI-only inventory differs from the pre-optimization baseline.")
    _list_digest(FULL_MODE_SCOPED_BASELINE) == FULL_MODE_SCOPED_SHA256 ||
        error("Mode-scoped Full inventory differs from the pre-sharding baseline.")

    FULL_VISUALIZATION_SHARD in full_shard_names() ||
        error("Visualization suite is not assigned to a Full shard.")
    FULL_NUMERICAL_SCRIPTS_SHARD in full_shard_names() ||
        error("Full readiness/numerical scripts are not assigned to a Full shard.")
    Set(full_shard_auxiliary_files("scientific-contracts")) ==
    Set(("band_structure_unit.jl", "mpi_runtime_compiled_modules_full_unit.jl")) ||
        error("Mode-scoped Full tests are not assigned exactly once.")
    return true
end

end
