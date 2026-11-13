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

const CI_CONTRACT_TEST_FILES =
    ("ci_execution_contract_unit.jl", "scientific_repair_ci_contract_unit.jl")

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

# Additional focused regression files; the original inventories below remain fixed.
const SCIENTIFIC_REPAIR_FAST_TEST_FILES = (
    "intrinsic_hall_real_occupation_unit.jl",
    "response_consumers_unit.jl",
    "response_local_density_unit.jl",
    "response_adaptive_consumers_unit.jl",
    "third_order_normalization_input_unit.jl",
    "native_low_dimensional_unit.jl",
    "native_low_dimensional_third_order_unit.jl",
    "native_low_dimensional_capabilities_unit.jl",
    "geometry_options_unit.jl",
    "conventional_kslice_band_selection_unit.jl",
    "spin_velocity_degenerate_block_unit.jl",
    "wilson_response_groups_unit.jl",
    "cell_image_causal_shg_unit.jl",
)

const FAST_TEST_FILES = (
    "eskernel_unit.jl",
    "hdf5_attribute_backend_unit.jl",
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
    "automatic_band_path_unit.jl",
    "jc_zero_energy_unit.jl",
    "numerics_unit.jl",
    "third_order_unit.jl",
    "third_order_runtime_unit.jl",
    "release_smoke_unit.jl",
    "mpi_runtime_environment_unit.jl",
    "synthetic_runtime_fixture_unit.jl",
    "shared_interpolation_unit.jl",
    "per_task_execution_unit.jl",
    "paired_photon_momentum_unit.jl",
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
    "optical_momentum_overlap_unit.jl",
    SCIENTIFIC_REPAIR_FAST_TEST_FILES...,
)

# Retains the pre-sharding scientific inventory and explicitly adds third-order tests. This is the authoritative Full-only
# inventory; shards below may redistribute these entries but may not add, omit,
# or duplicate one.
const FULL_ONLY_TEST_FILES = (
    "finite_domain_runtime_unit.jl",
    "native_model_symmetry_unit.jl",
    "native_model_responses_unit.jl",
    "native_model_region_unit.jl",
    "parallelogram_region_unit.jl",
    "parallelepiped_region_unit.jl",
    "fermi_vector_contract_unit.jl",
    "linear_orbital_parallel_unit.jl",
    "third_order_parallel_unit.jl",
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
    "disk_bounded_gauge_unit.jl",
    "generator_schema_migration_unit.jl",
    "vasp_paw_spn_unit.jl",
    "wannierization_frozen_initializer_unit.jl",
    "wannierization_standard_export_unit.jl",
    "checkpoint_definition_unit.jl",
    "wannierization_restart_input_definition_unit.jl",
    "wannier_operator_profiles_unit.jl",
    "operator_task_selection_unit.jl",
    "tb_symmetry_qualification_unit.jl",
    "tb_status_contract_unit.jl",
    "ordinary_posthoc_tb_qualification_unit.jl",
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
            # Each lifecycle case already owns a fresh isolated Julia process.
            # Run these before the parent retains compiled public-example state.
            "symmetrization_extension_lifecycle_unit.jl",
            "linear_orbital_parallel_unit.jl",
            "third_order_parallel_unit.jl",
            "per_task_symmetry_unit.jl",
            "per_task_parallel_unit.jl",
            "documented_examples_full_unit.jl",
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
            "finite_domain_runtime_unit.jl",
            "native_model_symmetry_unit.jl",
            "native_model_responses_unit.jl",
            "native_model_region_unit.jl",
            "parallelogram_region_unit.jl",
            "parallelepiped_region_unit.jl",
            "fermi_vector_contract_unit.jl",
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
            "disk_bounded_gauge_unit.jl",
            "generator_schema_migration_unit.jl",
            "vasp_paw_spn_unit.jl",
            "wannierization_frozen_initializer_unit.jl",
            "wannierization_standard_export_unit.jl",
            "checkpoint_definition_unit.jl",
            "wannierization_restart_input_definition_unit.jl",
            "wannier_operator_profiles_unit.jl",
            "operator_task_selection_unit.jl",
            "tb_symmetry_qualification_unit.jl",
            "tb_status_contract_unit.jl",
            "ordinary_posthoc_tb_qualification_unit.jl",
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
    "linear_orbital_parallel_unit.jl",
    "third_order_parallel_unit.jl",
    "mdrs_runtime_mpi_unit.jl",
    "wannierization_raw_z_mpi_unit.jl",
    "wannierization_u_localization_mpi_unit.jl",
    "wannierization_workflow_mpi_unit.jl",
    "per_task_parallel_unit.jl",
    "band_structure_unit.jl",
    "nonorthogonal_adaptive_mpi_unit.jl",
    "parallelogram_region_mpi_unit.jl",
    "parallelepiped_region_mpi_unit.jl",
)

const MPI_BASELINE_ENTRIES = (
    MPI_GATE_NAMES...,
    "linear_orbital_parallel_unit.jl",
    "third_order_parallel_unit.jl",
    "mdrs_runtime_mpi_unit.jl",
    "wannierization_raw_z_mpi_unit.jl",
    "wannierization_u_localization_mpi_unit.jl",
    "wannierization_workflow_mpi_unit.jl",
    "per_task_parallel_unit.jl#mpi-only",
    "band_structure_unit.jl#mpi-only",
    "nonorthogonal_adaptive_mpi_unit.jl",
    "parallelogram_region_mpi_unit.jl",
    "parallelepiped_region_mpi_unit.jl",
)

# Candidate adds bounded preparation and ordinary post-hoc regression coverage.
# Additional integrated numerical helper coverage; both historical lists remain protected.
const INFRASTRUCTURE_FAST_TEST_FILES = ("eskernel_unit.jl", "hdf5_attribute_backend_unit.jl")
const FAST_BASELINE_SHA256 = "722528744692b54cac154387eae94e824c1320699f78b72a88718d6971ffe73a"
const BERRY_GEOMETRY_FAST_TEST_FILES = (
    "orthogonal_geometry_analytic_unit.jl",
    "berry_geometry_backend_runtime_unit.jl",
    "berry_multipole_dc_unit.jl",
    "berry_multipole_runtime_unit.jl",
    "berry_geometry_fourier_unit.jl",
    "berry_multipole_periodic_unit.jl",
    "berry_multipole_dirac_unit.jl",
    "berry_geometry_multiband_unit.jl",
)
const FAST_LIST_SHA256 = "1f1694029547f9c0517a64dccb34dbf687853682afb7edfbb0846f91865ce098"
const FULL_LIST_SHA256 = "7685ec2ff20431578889c113c5d253844c52c57bc8fc853adde7c3a00ea9372c"
const MPI_LIST_SHA256 = "653bfdbbd107f4db911aa8ccb4484ef9838799a9385912ba12d99b93ad26e005"
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
    Tuple(filter(name -> name in INFRASTRUCTURE_FAST_TEST_FILES, FAST_TEST_FILES)) ==
    INFRASTRUCTURE_FAST_TEST_FILES ||
        error("Integrated numerical infrastructure tests missing or reordered.")
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

    _list_digest(
        filter(
            name -> !(
                name in BERRY_GEOMETRY_FAST_TEST_FILES ||
                name in SCIENTIFIC_REPAIR_FAST_TEST_FILES ||
                name in INFRASTRUCTURE_FAST_TEST_FILES
            ),
            FAST_TEST_FILES,
        ),
    ) == FAST_BASELINE_SHA256 ||
        error("Existing Fast baseline coverage/order changed during BCD/BCQ extension.")
    _list_digest(
        filter(
            name -> !(
                name in SCIENTIFIC_REPAIR_FAST_TEST_FILES || name in INFRASTRUCTURE_FAST_TEST_FILES
            ),
            FAST_TEST_FILES,
        ),
    ) == FAST_LIST_SHA256 ||
        error("Fast test inventory differs from the declared frozen regression inventory.")
    _list_digest(FULL_ONLY_TEST_FILES) == FULL_LIST_SHA256 || error(
        "Full-only inventory differs from the ordinary-diagnostic and disk-bounded candidate baseline.",
    )
    _list_digest(MPI_BASELINE_ENTRIES) == MPI_LIST_SHA256 || error(
        "MPI-only inventory differs from the frozen adaptive nonorthogonal candidate baseline.",
    )
    _list_digest(FULL_MODE_SCOPED_BASELINE) == FULL_MODE_SCOPED_SHA256 ||
        error("Mode-scoped Full inventory differs from the pre-sharding baseline.")

    FULL_VISUALIZATION_SHARD in full_shard_names() ||
        error("Visualization suite is not assigned to a Full shard.")
    FULL_NUMERICAL_SCRIPTS_SHARD in full_shard_names() ||
        error("Full readiness/numerical scripts are not assigned to a Full shard.")
    Set(full_shard_auxiliary_files("scientific-contracts")) ==
    Set(("band_structure_unit.jl", "mpi_runtime_compiled_modules_full_unit.jl")) ||
        error("Mode-scoped Full tests are not assigned exactly once.")
    validate_scientific_repair_fast_coverage()
    return true
end

"""Require each newly declared regression to be in the ordinary Fast inventory once."""
function validate_scientific_repair_fast_coverage(files = FAST_TEST_FILES)
    for name in SCIENTIFIC_REPAIR_FAST_TEST_FILES
        count(==(name), files) == 1 ||
            error("Scientific repair regression missing or duplicated: $(name)")
    end
    return true
end

end
