# Preserve the failed quality measurement independently of the decision to continue.
function _construction_quality_diagnostic(diagnostic::WannierizationDiagnostic, stage::String)
    return WannierizationDiagnostic(
        diagnostic.code,
        diagnostic.severity,
        diagnostic.message;
        context = merge(
            diagnostic.context,
            Dict(
                "stage" => stage,
                "gate_result" => "FAIL",
                "action" => "CONTINUE_DIAGNOSTIC",
                "construction_policy" => "diagnostic",
            ),
        ),
    )
end

# Keep symmetry residual failures auditable at initialization and accepted boundaries.
function _record_construction_symmetry_quality!(
    diagnostics,
    summary,
    frames,
    frozen_indices,
    representation,
    plan,
    config,
    covariance_tolerance,
    stage;
    residuals = nothing,
)
    config.input.construction_policy == :diagnostic || return nothing
    residuals =
        residuals === nothing ?
        _candidate_invariant_residuals(frames, frozen_indices, representation) : residuals
    target = _maximum_target_frame_symmetry_error(frames, representation, plan)
    for (code, value) in (
        (:SOLVER_TRIAL_COVARIANCE_FAILED, residuals.covariance),
        (:SOLVER_TRIAL_TARGET_SYMMETRY_FAILED, target),
    )
        if value > covariance_tolerance
            push!(
                diagnostics,
                _construction_quality_diagnostic(
                    WannierizationDiagnostic(
                        code,
                        :error,
                        "accepted state exceeds the symmetry quality threshold";
                        context = Dict(
                            "value" => string(value),
                            "threshold" => string(covariance_tolerance),
                        ),
                    ),
                    stage,
                ),
            )
            summary["construction_quality_failed"] = "true"
            summary["model_qualification"] = "DIAGNOSTIC_ONLY"
        end
    end
    return nothing
end

const _CONSTRUCTION_COMPATIBILITY_QUALITY_CODES = (
    :REQUIRED_BLOCK_UNITARITY_FAILED,
    :ANTIUNITARY_GROUP_LAW_FAILED,
    :TARGET_REPRESENTATION_GROUP_LAW_FAILED,
    :THETA_SQUARED_FAILED,
    :ANTIUNITARY_PROJECTOR_COVARIANCE_FAILED,
    :EMPIRICAL_COVARIANCE_BUDGET_VACUOUS,
)

# Closure residuals are quality failures only when the discrete rank contracts
# hold. Odd Kramers rank and mismatched mask ranks remain construction failures.
function _construction_compatibility_quality_failure(diagnostic::WannierizationDiagnostic)
    diagnostic.code in _CONSTRUCTION_COMPATIBILITY_QUALITY_CODES && return true
    diagnostic.code in (:KRAMERS_BLOCK_NOT_CLOSED, :COREPRESENTATION_BLOCK_NOT_CLOSED) ||
        return false
    source_rank = tryparse(Int, get(diagnostic.context, "source_rank", ""))
    target_rank = tryparse(Int, get(diagnostic.context, "target_rank", ""))
    residual = tryparse(Float64, get(diagnostic.context, "maximum_error", ""))
    source_rank !== nothing &&
    source_rank == target_rank &&
    residual !== nothing &&
    isfinite(residual) || return false
    if diagnostic.code == :KRAMERS_BLOCK_NOT_CLOSED &&
       get(diagnostic.context, "source_kpoint", "") == get(diagnostic.context, "target_kpoint", "")
        iseven(source_rank) || return false
    end
    return true
end

# Resolve mode, authority and provenance before validating input dimensions.
function _prepare_solver_input_summary(state::NamedTuple)
    (;
        amn,
        compatibility_report,
        config,
        eig,
        fixed_subspace,
        initialization_amn_sha256,
        mmn,
        observer,
        paw_scdm_input,
        plan,
        representation,
        restart,
        restart_history,
        restart_input_summary,
        restart_state,
    ) = state
    diagnostics = WannierizationDiagnostic[]
    spectrum_audit = HermitianSpectrumAudit()
    apply_symmetry = symmetry_constraints_applied(config, representation)
    effective_algorithms = effective_wannierization_algorithms(config, representation)
    smv_fr_audit = _smv_fletcher_reeves_two_stage_audit(
        config.solver.smv_fletcher_reeves_two_stage_audit_manifest,
        config.solver.smv_fletcher_reeves_two_stage_audit_thresholds,
    )
    full_constraint_scope = config.solver.acceleration.constraint_operation_scope == :full
    representation_magnetic =
        lowercase(get(representation.conventions, "magnetic_structure", "false")) == "true"
    representation_antiunitary =
        any(operation.antiunitary for operation in representation.operations)
    # A current wire number only removes legacy uncertainty after the full field contract passes.
    representation_current_public =
        representation.schema_version == "1.0" && all(
            key -> haskey(representation.conventions, key),
            (
                "requested_wannierization_mode",
                "effective_wannierization_mode",
                "representation_source",
                "symmetry_constraints_applied",
            ),
        )
    if representation_current_public
        validate_public_band_representation_contract(representation)
    end
    representation_legacy_uncertain = !(
        representation_current_public || representation.schema_version in (
            "1.4",
            "1.5",
            "1.6",
            "1.7",
            "1.8",
            "1.9",
            "1.10",
            "1.11",
            "1.12",
            "1.13",
            "1.14",
            "1.15",
            "1.16",
            "1.17",
        )
    )
    effective_compatibility_policy =
        config.input.construction_policy == :diagnostic ? config.input.compatibility_policy :
        representation_magnetic || representation_antiunitary || representation_legacy_uncertain ?
        :strict : config.input.compatibility_policy
    u_localization_mpi_size = if config.solver.parallel == :mpi
        MPI.Initialized() || MPI.Init()
        MPI.Comm_size(MPI.COMM_WORLD)
    else
        1
    end
    authoritative_hamiltonian = validate_authoritative_hamiltonian_key(
        get(representation.conventions, "authoritative_hamiltonian", "native_dft"),
    )
    symmetrized_authority = authoritative_hamiltonian == "symmetrized_dft_hamiltonian"
    target_contract = _representation_target_subspace_contract(representation)
    target_subspace_authority = target_contract.active
    input_summary = Dict(
        "requested_wannierization_mode" => String(config.input.wannierization_mode),
        "effective_wannierization_mode" => String(effective_wannierization_mode(config)),
        "representation_source" => String(representation_source(config)),
        "symmetry_constraints_applied" => string(apply_symmetry),
        "algorithm_profile" => String(config.solver.algorithm_profile),
        "effective_algorithm_profile" => String(effective_algorithms.profile),
        "symmetry_projected_smv_fr_contract" =>
            _is_symmetry_projected_smv_fr(effective_algorithms.disentanglement) ||
            _is_symmetry_projected_smv_fr(effective_algorithms.localization) ?
            SYMMETRY_PROJECTED_SMV_FR_CONTRACT : "NOT_APPLICABLE",
        "identity_group_exact_ordinary_fast_path" => string(
            effective_algorithms.profile == :symmetry_projected_smv_fletcher_reeves_two_stage && !apply_symmetry,
        ),
        "smv_fletcher_reeves_two_stage_algorithm_contract_version" =>
            SMV_FLETCHER_REEVES_TWO_STAGE_ALGORITHM_CONTRACT_VERSION,
        "smv_fletcher_reeves_two_stage_audit_standard_version" =>
            config.solver.smv_fletcher_reeves_two_stage_audit_thresholds.standard_version,
        "smv_fletcher_reeves_two_stage_audit_semantic" =>
            config.solver.smv_fletcher_reeves_two_stage_audit_thresholds.semantic,
        "smv_fletcher_reeves_two_stage_audit_accepted_step_combination_rule" =>
            config.solver.smv_fletcher_reeves_two_stage_audit_thresholds.accepted_step_combination_rule,
        "smv_fletcher_reeves_two_stage_audit_accepted_step_absolute_tolerance" => string(
            config.solver.smv_fletcher_reeves_two_stage_audit_thresholds.accepted_step_absolute_tolerance,
        ),
        "smv_fletcher_reeves_two_stage_audit_accepted_step_relative_tolerance" => string(
            config.solver.smv_fletcher_reeves_two_stage_audit_thresholds.accepted_step_relative_tolerance,
        ),
        "smv_fletcher_reeves_two_stage_audit_contract_sha256" =>
            smv_fletcher_reeves_two_stage_audit_contract_sha256(
                config.solver.smv_fletcher_reeves_two_stage_audit_thresholds,
            ),
        "smv_fletcher_reeves_two_stage_default_selection_reason" =>
            effective_algorithms.default_selection_reason,
        "smv_fletcher_reeves_two_stage_audit_status" => smv_fr_audit.status,
        "smv_fletcher_reeves_two_stage_audit_reason" => smv_fr_audit.reason,
        "smv_fletcher_reeves_two_stage_audit_manifest_sha256" => smv_fr_audit.manifest_sha256,
        "symmetry_constraints_applied" => string(apply_symmetry),
        "effective_symmetry_operation_count" =>
            string(apply_symmetry ? length(representation.operations) : 1),
        "effective_antiunitary_operation_count" => string(
            apply_symmetry ?
            count(operation -> operation.antiunitary, representation.operations) : 0,
        ),
        "requested_symmetrize_z" => string(config.solver.symmetrize_z),
        "effective_symmetrize_z" => string(apply_symmetry && config.solver.symmetrize_z),
        "disentanglement_z_reduction" =>
            apply_symmetry ? "FULL_STAR_PULLBACK_AVERAGE" : "FULL_BZ_IDENTITY",
        "representation_compatibility_applicability" =>
            apply_symmetry ? "APPLICABLE" : "NOT_APPLICABLE",
        "target_multiplicity_applicability" => apply_symmetry ? "APPLICABLE" : "NOT_APPLICABLE",
        "covariance_applicability" =>
            apply_symmetry ? "APPLICABLE" :
            config.input.wannierization_mode == :ordinary ? "DIAGNOSTIC_ONLY" : "NOT_APPLICABLE",
        "covariance_qualification" =>
            apply_symmetry ? "HARD_GATE" :
            config.input.wannierization_mode == :ordinary ? "DIAGNOSTIC_ONLY" : "NOT_APPLICABLE",
        "source_code" => String(representation.source_code),
        "sewing_backend" =>
            get(representation.conventions, "sewing_backend", "coefficient_mapping"),
        "sewing_metric" =>
            get(representation.conventions, "sewing_metric", "pseudo_coefficient_linear_map"),
        "paw_sewing_thresholds" =>
            get(representation.conventions, "paw_sewing_thresholds", "NOT_APPLICABLE"),
        "strict_sewing_diagnostics_sha256" => _strict_sewing_diagnostics_sha256(representation),
        "wavefunction_gauge_backend" =>
            get(representation.conventions, "wavefunction_gauge_backend", "native_eigenstate"),
        "wavefunction_gauge_hdf5_sha256" =>
            get(representation.conventions, "wavefunction_gauge_hdf5_sha256", "NOT_APPLICABLE"),
        "block_partition_policy" =>
            get(representation.conventions, "block_partition_policy", "NOT_APPLICABLE"),
        "block_partition_policy_sha256" =>
            get(representation.input_sha256, "BLOCK_PARTITION_POLICY_SHA256", "NOT_APPLICABLE"),
        "discrete_hamiltonian_correction" =>
            get(representation.conventions, "discrete_hamiltonian_correction", "none"),
        "authoritative_hamiltonian" => authoritative_hamiltonian,
        "authoritative_hamiltonian_sha256" => get(
            representation.conventions,
            "authoritative_hamiltonian_sha256",
            "LEGACY_NATIVE_DFT",
        ),
        "native_fidelity_status" =>
            get(representation.conventions, "native_fidelity_status", "NOT_RECORDED"),
        "symmetrized_hamiltonian_status" =>
            get(representation.conventions, "symmetrized_hamiltonian_status", "NOT_APPLICABLE"),
        "energy_shift_qualification" => get(
            representation.conventions,
            "energy_shift_qualification",
            target_subspace_authority ? "audit_only" : "legacy_energy_shift_hard_gate",
        ),
        "maximum_energy_shift_audit_reference_ev" => get(
            representation.conventions,
            "maximum_energy_shift_audit_reference_ev",
            "NOT_APPLICABLE",
        ),
        "rms_energy_shift_audit_reference_ev" => get(
            representation.conventions,
            "rms_energy_shift_audit_reference_ev",
            "NOT_APPLICABLE",
        ),
        "target_energy_shift_audit_status" => get(
            representation.conventions,
            "target_energy_shift_audit_status",
            "NOT_APPLICABLE",
        ),
        "symmetrized_parent_energy_shift_audit_status" => get(
            representation.conventions,
            "symmetrized_parent_energy_shift_audit_status",
            "NOT_APPLICABLE",
        ),
        # Schema 2.28 keeps the Hamiltonian authority, target scope, and leakage-weight
        # contract carried by the
        # representation.  Older representation writers did not always emit
        # every derived gate-order field, so authority-specific defaults are
        # supplied here without changing the native/legacy defaults.
        "residual_gate_phase" => get(
            representation.conventions,
            "residual_gate_phase",
            symmetrized_authority ? "post_symmetrization" :
            target_subspace_authority ? "target_subspace" : "legacy_pre_symmetrization",
        ),
        "raw_preflight_diagnostic_status" => get(
            representation.conventions,
            "raw_preflight_diagnostic_status",
            "NOT_APPLICABLE",
        ),
        "native_difference_qualification" => get(
            representation.conventions,
            "native_difference_qualification",
            target_subspace_authority ? "audit_only" : "legacy_hard_gate",
        ),
        "native_difference_audit_status" =>
            get(representation.conventions, "native_difference_audit_status", "NOT_APPLICABLE"),
        "qualification_scope" => get(
            representation.conventions,
            "qualification_scope",
            target_subspace_authority ? "target_subspace" : "full_parent",
        ),
        "target_authority" => target_contract.target_authority,
        "parent_audit_policy" => target_contract.parent_audit_policy,
        "target_subspace_contract_sha256" => target_contract.contract_sha256,
        "target_leakage_semantics" => target_contract.target_leakage_semantics,
        "target_leakage_formula_sha256" => target_contract.target_leakage_formula_sha256,
        "target_leakage_threshold" => target_contract.target_leakage_threshold,
        "target_anchor" => get(
            representation.conventions,
            "target_anchor",
            symmetrized_authority && target_subspace_authority ?
            "completed_symmetrized_target" : "NOT_APPLICABLE",
        ),
        "target_complement_completion" =>
            get(representation.conventions, "target_complement_completion", "NOT_APPLICABLE"),
        "target_complement_max_element_ev" => get(
            representation.conventions,
            "target_complement_max_element_ev",
            "NOT_APPLICABLE",
        ),
        "auxiliary_parent_qualification" => get(
            representation.conventions,
            "auxiliary_parent_qualification",
            target_subspace_authority ? "audit_only" : "legacy_hard_gate",
        ),
        "symmetrized_target_subspace_status" => get(
            representation.conventions,
            "symmetrized_target_subspace_status",
            "NOT_APPLICABLE",
        ),
        "auxiliary_parent_audit_status" =>
            get(representation.conventions, "auxiliary_parent_audit_status", "NOT_APPLICABLE"),
        "target_scope_production_eligible" =>
            get(representation.conventions, "target_scope_production_eligible", "false"),
        "scoped_production_eligible" =>
            get(representation.conventions, "scoped_production_eligible", "false"),
        "global_production_eligible" => "false",
        "controlled_symmetrization_qualification_mode" => get(
            representation.conventions,
            "controlled_symmetrization_qualification_mode",
            "not_applicable",
        ),
        "controlled_symmetrization_diagnostic_only" =>
            get(representation.conventions, "diagnostic_only", "false"),
        "controlled_symmetrization_production_eligible" =>
            get(representation.conventions, "production_eligible", "true"),
        "schema_version" => representation.schema_version,
        "num_bands" => string(size(representation.energies_ev, 1)),
        "num_kpoints" => string(size(representation.energies_ev, 2)),
        "spinor" => string(representation.spinor),
        "z_mix_ratio" => string(config.solver.z_mix_ratio),
        "u_mix_ratio" => string(config.solver.u_mix_ratio),
        "optimizer_strategy" => String(config.solver.acceleration.strategy),
        "optimizer_schedule" => String(config.solver.acceleration.schedule),
        "subspace_selection" =>
            effective_algorithms.disentanglement ==
            :symmetry_projected_smv_fletcher_reeves_two_stage ?
            "FULL_BZ_SMV_COREPRESENTATION_CONTINUITY_STAR_COMPLETION" :
            "MAXIMUM_EIGENSPACE_BOUNDARY_CLUSTER_PROCRUSTES",
        "disentanglement_algorithm_requested" =>
            String(config.solver.acceleration.disentanglement_algorithm),
        "disentanglement_algorithm" => String(effective_algorithms.disentanglement),
        "subspace_gauge_policy" => String(config.solver.acceleration.subspace_gauge_policy),
        "initialization_backend" => string(typeof(config.solver.initialization_backend)),
        "multi_start_enabled" => string(config.solver.multi_start.enabled),
        "multi_start_count" => string(config.solver.multi_start.starts),
        "multi_start_index" => string(config.solver.multi_start.start_index),
        "hot_storage_backend" => String(config.solver.acceleration.hot_storage_backend),
        "requested_initializer" => String(config.solver.initialization),
        "localization_algorithm_requested" =>
            String(config.solver.acceleration.localization_algorithm),
        "localization_algorithm" => String(effective_algorithms.localization),
        "smv_fletcher_reeves_two_stage_protocol" =>
            effective_algorithms.localization == :smv_fletcher_reeves_two_stage ?
            "smv-fixed-point-plus-fletcher-reeves-two-stage-v4" : "NOT_APPLICABLE",
        "smv_fletcher_reeves_two_stage_lapack_backend" =>
            effective_algorithms.localization == :smv_fletcher_reeves_two_stage ?
            _wannier90_reference_lapack_backend() : "NOT_APPLICABLE",
        "smv_fletcher_reeves_two_stage_lapack_sha256" =>
            effective_algorithms.localization == :smv_fletcher_reeves_two_stage ?
            _wannier90_reference_lapack_sha256() : "NOT_APPLICABLE",
        "smv_fletcher_reeves_two_stage_phase_backend" =>
            effective_algorithms.localization == :smv_fletcher_reeves_two_stage ?
            "PLATFORM_LIBM:" * _WANNIER90_REFERENCE_SYSTEM_LIBM : "NOT_APPLICABLE",
        "localization_gradient_contract" => LOCALIZATION_GRADIENT_CONTRACT,
        "joint_update_contract" => JOINT_UPDATE_CONTRACT,
        "z_u_stage_semantics" => "disentanglement_localization_decoupled_v1",
        "disentanglement_limit_policy" =>
            String(config.solver.acceleration.disentanglement_limit_policy),
        "joint_z_backtracking_factor" =>
            string(config.solver.acceleration.joint_z_backtracking_factor),
        "joint_z_backtracking_max_steps" =>
            string(config.solver.acceleration.joint_z_backtracking_max_steps),
        "constraint_operation_scope" =>
            String(config.solver.acceleration.constraint_operation_scope),
        "constraint_operation_scope_history_reset" =>
            config.solver.acceleration.constraint_operation_scope == :full ? "NOT_APPLICABLE" :
            "LEGACY_CONSTRAINT_SCOPE_RESET",
        "symmetry_ablation_classification" =>
            config.solver.acceleration.constraint_operation_scope == :full ? "NOT_APPLICABLE" :
            "DIAGNOSTIC_SYMMETRY_ABLATION",
        "u_acceptance" => String(config.solver.acceleration.u_acceptance),
        "u_phase_branch_tolerance" =>
            string(config.solver.acceleration.u_phase_branch_tolerance),
        "u_branch_active_set_max_orbits" =>
            string(config.solver.acceleration.u_branch_active_set_max_orbits),
        "u_lbfgs_history" => string(config.solver.acceleration.u_lbfgs_history),
        "u_lbfgs_curvature_tolerance" =>
            string(config.solver.acceleration.u_lbfgs_curvature_tolerance),
        "u_wolfe_c2" => string(config.solver.acceleration.u_wolfe_c2),
        "u_line_search_max_trials" =>
            string(config.solver.acceleration.u_line_search_max_trials),
        "u_w90_restart_interval" => string(config.solver.acceleration.u_w90_restart_interval),
        "u_w90_trial_step" => string(config.solver.acceleration.u_w90_trial_step),
        "hermitian_residual_rtol" =>
            string(config.solver.numerical_thresholds.hermitian_residual_rtol),
        "subspace_cluster_atol" =>
            string(config.solver.numerical_thresholds.subspace_cluster_atol),
        "subspace_cluster_rtol" =>
            string(config.solver.numerical_thresholds.subspace_cluster_rtol),
        "frame_transport_atol" =>
            string(config.solver.numerical_thresholds.frame_transport_atol),
        "frame_transport_rtol" =>
            string(config.solver.numerical_thresholds.frame_transport_rtol),
        "projectability_minimum_singular_value" =>
            string(config.solver.numerical_thresholds.projectability_minimum_singular_value),
        "maximum_transport_condition" =>
            string(config.solver.numerical_thresholds.maximum_transport_condition),
        "construction_policy" => String(config.input.construction_policy),
        "manual_review_required" => "true",
        "compatibility_policy_requested" => String(config.input.compatibility_policy),
        "compatibility_policy_effective" => String(effective_compatibility_policy),
        "symmetry_tolerance" => string(config.input.symmetry_tolerance),
        "symmetry_tolerance_status" =>
            representation_source(config) == :detected ? "APPLIED" : "NOT_APPLICABLE",
        "u_gradient_norm_tolerance" =>
            string(config.solver.acceleration.u_gradient_norm_tolerance),
        "u_inner_sweeps" => string(config.solver.acceleration.u_inner_sweeps),
        "u_cg_restart_interval" => string(config.solver.acceleration.u_cg_restart_interval),
        "u_cg_beta_cap" => string(config.solver.acceleration.u_cg_beta_cap),
        "u_cg_minimum_descent_cosine" =>
            string(config.solver.acceleration.u_cg_minimum_descent_cosine),
        "anderson_safeguard" => "OBJECTIVE_PROJECTOR_Z_RESIDUAL",
        "phase_branch_backtracking_extension" => "DISABLED_REPLACED_BY_TYPE_IV_CLARKE_ACTIVE_SET",
        "phase_branch_backtracking_extension_count" => "0",
        "minimum_localization_diagonal_phase_margin" => "NOT_APPLICABLE",
        "disentanglement_convergence" => "IN_PROGRESS",
        "z_seal_class" =>
            config.solver.acceleration.schedule == :fixed_subspace ? "NOT_APPLICABLE" :
            "IN_PROGRESS",
        "qualified_z_seal" => "false",
        "route_selection_eligible" => "false",
        "localization_convergence" => config.solver.localize ? "NOT_STARTED" : "NOT_APPLICABLE",
        "localization_qualification" =>
            config.solver.localize ? "NOT_STARTED" : "NOT_APPLICABLE",
        "model_qualification" => "NOT_AVAILABLE",
        "diagnostic_tb_export_eligible" => "false",
        "standard_tb_export_eligible" => "false",
        "random_seed" => string(config.solver.random_seed),
        "parallel" => String(config.solver.parallel),
        "u_localization_parallel_contract" =>
            config.solver.parallel == :mpi ?
            "CYCLIC_KPOINT_NEIGHBOR_EDGE_DENSE_OWNER_REDUCTION" : "LOCAL_CANONICAL_EDGE_ORDER",
        "u_localization_mpi_size" => string(u_localization_mpi_size),
        "convergence_tolerance" => string(config.solver.convergence_tolerance),
        "convergence_window" => string(config.solver.convergence_window),
    )
    if !full_constraint_scope
        push!(
            diagnostics,
            WannierizationDiagnostic(
                :DIAGNOSTIC_SYMMETRY_ABLATION,
                :warning,
                "constraint-operation subgroup ablation is diagnostic-only and cannot produce a standard or production-qualified TB";
                context = Dict(
                    "constraint_operation_scope" =>
                        String(config.solver.acceleration.constraint_operation_scope),
                    "effective_operation_count" => string(length(representation.operations)),
                    "effective_antiunitary_operation_count" => string(
                        count(operation -> operation.antiunitary, representation.operations),
                    ),
                ),
            ),
        )
    end
    _record_hermitian_spectrum_audit!(input_summary, spectrum_audit)
    input_entries = [
        "$(key)\0$(representation.input_sha256[key])" for
        key in sort!(collect(keys(representation.input_sha256)))
    ]
    input_summary["input_sha256"] = bytes2hex(SHA.sha256(codeunits(join(input_entries, '\n'))))
    projection_basis = something(config.input.projection_basis)
    radial_contract = projection_radial_transform_contract(projection_basis.radial_transform)
    basis_sha256 = projection_basis_sha256(projection_basis)
    amn_sha256 = if !isempty(initialization_amn_sha256)
        String(initialization_amn_sha256)
    elseif amn === nothing
        restart_state === nothing ? "" : restart_state.amn_sha256
    else
        buffer = IOBuffer()
        write(buffer, reinterpret(UInt8, Int64[ndims(amn), size(amn)...]))
        write(buffer, reinterpret(UInt8, vec(amn)))
        bytes2hex(SHA.sha256(take!(buffer)))
    end
    input_summary["projection_basis_sha256"] = basis_sha256
    input_summary["projection_radial_transform_method"] =
        String(projection_basis.radial_transform.method)
    input_summary["projection_radial_transform_digest"] =
        bytes2hex(SHA.sha256(codeunits(repr(radial_contract))))
    input_summary["amn_sha256"] = amn_sha256
    nb, nk = size(representation.energies_ev)
    eig.num_bands == nb && eig.num_kpts == nk || return _failure_result(
        INVALID_INPUT,
        [
            WannierizationDiagnostic(
                :EIG_DIMENSION_MISMATCH,
                :error,
                "EIG dimensions do not match the band representation",
            ),
        ],
        input_summary,
    )
    mmn.num_bands == nb && mmn.num_kpts == nk || return _failure_result(
        INVALID_INPUT,
        [
            WannierizationDiagnostic(
                :MMN_DIMENSION_MISMATCH,
                :error,
                "MMN dimensions do not match the band representation",
            ),
        ],
        input_summary,
    )
    length(plan.operations) == length(representation.operations) || return _failure_result(
        INVALID_INPUT,
        [
            WannierizationDiagnostic(
                :OPERATION_COUNT_MISMATCH,
                :error,
                "band and Wannier representations use different operation counts",
            ),
        ],
        input_summary,
    )
    return (;
        amn,
        amn_sha256,
        apply_symmetry,
        basis_sha256,
        compatibility_report,
        config,
        diagnostics,
        effective_algorithms,
        effective_compatibility_policy,
        fixed_subspace,
        full_constraint_scope,
        input_summary,
        mmn,
        nb,
        nk,
        observer,
        paw_scdm_input,
        plan,
        representation,
        restart,
        restart_history,
        restart_input_summary,
        restart_state,
        spectrum_audit,
        target_subspace_authority,
    )
end

# Qualify band windows and representation, then build the finite-difference stencil.
function _qualify_solver_inputs(state::NamedTuple)
    (;
        amn,
        amn_sha256,
        apply_symmetry,
        basis_sha256,
        compatibility_report,
        config,
        diagnostics,
        effective_algorithms,
        effective_compatibility_policy,
        fixed_subspace,
        full_constraint_scope,
        input_summary,
        mmn,
        nb,
        nk,
        observer,
        paw_scdm_input,
        plan,
        representation,
        restart,
        restart_history,
        restart_input_summary,
        restart_state,
        spectrum_audit,
        target_subspace_authority,
    ) = state
    num_wannier = configured_num_wannier(config)
    outer_indices = Vector{Vector{Int}}(undef, nk)
    frozen_indices = Vector{Vector{Int}}(undef, nk)
    for kpoint in 1:nk
        outer_indices[kpoint] = complete_window_indices(
            @view(representation.energies_ev[:, kpoint]),
            @view(representation.band_block_labels[:, kpoint]),
            config.input.outer_min_ev,
            config.input.outer_max_ev,
        )
        frozen_indices[kpoint] = _frozen_indices(config, representation, kpoint)
        if length(outer_indices[kpoint]) < num_wannier
            push!(
                diagnostics,
                WannierizationDiagnostic(
                    :OUTER_WINDOW_TOO_SMALL,
                    :error,
                    "outer window has fewer complete block states than num_wannier";
                    context = Dict(
                        "kpoint" => string(kpoint),
                        "count" => string(length(outer_indices[kpoint])),
                    ),
                ),
            )
            return _failure_result(INVALID_INPUT, diagnostics, input_summary)
        end
        if length(frozen_indices[kpoint]) > num_wannier ||
           !all(index -> index in outer_indices[kpoint], frozen_indices[kpoint])
            push!(
                diagnostics,
                WannierizationDiagnostic(
                    :FROZEN_SUBSPACE_INVALID,
                    :error,
                    "frozen complete blocks are not contained in the target outer subspace";
                    context = Dict("kpoint" => string(kpoint)),
                ),
            )
            return _failure_result(INVALID_INPUT, diagnostics, input_summary)
        end
    end
    outer_masks = [BitVector([band in outer_indices[kpoint] for band in 1:nb]) for kpoint in 1:nk]
    frozen_masks = [BitVector([band in frozen_indices[kpoint] for band in 1:nb]) for kpoint in 1:nk]
    solver_qualification_scope = BandRepresentationQualificationScope(
        BitMatrix(hcat(outer_masks...)),
        BitMatrix(hcat(frozen_masks...)),
    )
    input_summary["disentanglement_outer_mask_sha256"] =
        solver_qualification_scope.outer_mask_sha256
    input_summary["disentanglement_frozen_mask_sha256"] =
        solver_qualification_scope.frozen_mask_sha256
    if target_subspace_authority
        for (key, observed) in (
            ("outer_mask_sha256", solver_qualification_scope.outer_mask_sha256),
            ("frozen_mask_sha256", solver_qualification_scope.frozen_mask_sha256),
        )
            recorded = get(representation.conventions, key, observed)
            recorded == observed || return _failure_result(
                INVALID_INPUT,
                [
                    WannierizationDiagnostic(
                        :TARGET_SUBSPACE_CONTRACT_MISMATCH,
                        :error,
                        "solver window mask differs from the sealed target-subspace contract";
                        context = Dict(
                            "mask" => key,
                            "recorded_sha256" => recorded,
                            "observed_sha256" => observed,
                        ),
                    ),
                ],
                input_summary,
            )
        end
    end
    compatibility = if compatibility_report === nothing
        validate_band_representation_compatibility(
            representation,
            plan;
            outer_mask = outer_masks,
            frozen_mask = frozen_masks,
            tolerance = config.input.representation_tolerance,
        )
    else
        compatibility_report
    end
    input_summary["representation_sha256"] = compatibility.representation_sha256
    input_summary["constraint_operation_parent_representation_sha256"] = get(
        representation.conventions,
        "constraint_operation_parent_representation_sha256",
        compatibility.representation_sha256,
    )
    input_summary["constraint_operation_subgroup_sha256"] = get(
        representation.conventions,
        "constraint_operation_subgroup_sha256",
        compatibility.representation_sha256,
    )
    input_summary["constraint_operation_parent_indices"] = get(
        representation.conventions,
        "constraint_operation_parent_indices",
        join(eachindex(representation.operations), ','),
    )
    input_summary["representation_compatible"] =
        apply_symmetry ? string(compatibility.passed) : "NOT_APPLICABLE"
    config_sha256 = _restart_config_sha256(config, representation)
    input_summary["restart_config_sha256"] = config_sha256
    diagnostic_construction = config.input.construction_policy == :diagnostic
    compatibility_records =
        diagnostic_construction ?
        [
            _construction_compatibility_quality_failure(diagnostic) ?
            _construction_quality_diagnostic(diagnostic, "representation_compatibility") :
            diagnostic for diagnostic in compatibility.diagnostics
        ] :
        apply_symmetry ?
        representation_diagnostics_for_policy(
            compatibility.diagnostics,
            effective_compatibility_policy,
        ) : compatibility.diagnostics
    append!(diagnostics, compatibility_records)
    structural_compatibility_failure = any(
        diagnostic ->
            diagnostic.severity == :error &&
            !_construction_compatibility_quality_failure(diagnostic),
        compatibility.diagnostics,
    )
    if !compatibility.passed && (
        diagnostic_construction ? structural_compatibility_failure :
        effective_compatibility_policy == :strict
    )
        input_summary["failure_class"] = "REPRESENTATION_A"
        return _failure_result(REPRESENTATION_INCOMPATIBLE, diagnostics, input_summary)
    elseif !compatibility.passed
        push!(
            diagnostics,
            WannierizationDiagnostic(
                :REPRESENTATION_POLICY_CONTINUATION,
                :warning,
                "report-only representation incompatibility did not stop the non-strict run";
                context = Dict("policy" => String(effective_compatibility_policy)),
            ),
        )
    end
    projector_covariance_tolerance =
        apply_symmetry ? _projector_covariance_tolerance(config, compatibility) : Inf
    input_summary["projector_covariance_tolerance"] =
        apply_symmetry ? string(projector_covariance_tolerance) : "NOT_APPLICABLE"
    input_summary["raw_sewing_empirical_floor"] =
        apply_symmetry && compatibility.validation_profile == :empirical ?
        string(maximum(compatibility.maximum_group_law_residuals)) : "NOT_APPLICABLE"
    input_summary["final_tb_hamiltonian_covariance_threshold"] =
        string(config.input.representation_tolerance)
    input_summary["final_tb_hamiltonian_covariance_threshold_contract"] = "FORMAL_REPRESENTATION_TOLERANCE"
    tangent_plans = Vector{Union{Nothing, TargetSymmetryTangentPlan}}(undef, nk)
    fill!(tangent_plans, nothing)
    if config.solver.localize && apply_symmetry
        tangent_plans = try
            _build_target_symmetry_tangent_plans(
                representation,
                plan;
                construction_policy = config.input.construction_policy,
                tolerance = config.input.representation_tolerance,
            )
        catch exception
            push!(
                diagnostics,
                WannierizationDiagnostic(
                    :TARGET_SYMMETRY_TANGENT_CONSTRUCTION_FAILED,
                    :error,
                    sprint(showerror, exception),
                ),
            )
            return _failure_result(REPRESENTATION_INCOMPATIBLE, diagnostics, input_summary)
        end
    end
    for tangent in tangent_plans
        tangent === nothing && continue
        if tangent.maximum_basis_residual > 64 * config.input.representation_tolerance
            push!(
                diagnostics,
                _construction_quality_diagnostic(
                    WannierizationDiagnostic(
                        :TARGET_SYMMETRY_TANGENT_RESIDUAL_FAILED,
                        :error,
                        "target tangent exceeds the residual quality threshold";
                        context = Dict(
                            "value" => string(tangent.maximum_basis_residual),
                            "threshold" => string(64 * config.input.representation_tolerance),
                        ),
                    ),
                    "target_tangent",
                ),
            )
            input_summary["construction_quality_failed"] = "true"
        end
    end
    if apply_symmetry && projector_covariance_tolerance > config.input.representation_tolerance
        push!(
            diagnostics,
            representation_diagnostic(
                :EMPIRICAL_PROJECTOR_COVARIANCE_BUDGET,
                :info,
                "selected-projector covariance uses the qualified finite-cutoff group-law floor";
                context = Dict(
                    "representation_tolerance" => config.input.representation_tolerance,
                    "projector_covariance_tolerance" => projector_covariance_tolerance,
                    "qualification_sha256" => something(compatibility.qualification_sha256, ""),
                ),
            ),
        )
    end
    stencil = try
        effective_algorithms.disentanglement == :smv_fletcher_reeves_two_stage ?
        _wannier90_reference_finite_difference_weights(
            representation,
            mmn;
            construction_policy = config.input.construction_policy,
        ) :
        _finite_difference_weights(
            representation,
            mmn;
            construction_policy = config.input.construction_policy,
        )
    catch exception
        push!(
            diagnostics,
            WannierizationDiagnostic(
                :MMN_STENCIL_INCOMPLETE_3D,
                :error,
                sprint(showerror, exception),
            ),
        )
        return _failure_result(INVALID_INPUT, diagnostics, input_summary)
    end
    if stencil.completeness_residual > 1.0e-10
        push!(
            diagnostics,
            _construction_quality_diagnostic(
                WannierizationDiagnostic(
                    :MMN_STENCIL_COMPLETENESS_FAILED,
                    :error,
                    "finite-difference completeness exceeds the quality threshold";
                    context = Dict(
                        "value" => string(stencil.completeness_residual),
                        "threshold" => "1.0e-10",
                    ),
                ),
                "finite_difference",
            ),
        )
        input_summary["construction_quality_failed"] = "true"
    end
    weights = stencil.weights
    input_summary["spread_metric"] = "full_3d"
    input_summary["finite_difference_stencil_sha256"] = stencil.digest
    input_summary["finite_difference_completeness_residual"] = string(stencil.completeness_residual)
    return (;
        amn,
        amn_sha256,
        apply_symmetry,
        basis_sha256,
        compatibility,
        config,
        config_sha256,
        diagnostics,
        effective_algorithms,
        effective_compatibility_policy,
        fixed_subspace,
        frozen_indices,
        frozen_masks,
        full_constraint_scope,
        input_summary,
        mmn,
        nb,
        nk,
        num_wannier,
        observer,
        outer_indices,
        outer_masks,
        paw_scdm_input,
        plan,
        projector_covariance_tolerance,
        representation,
        restart,
        restart_history,
        restart_input_summary,
        restart_state,
        spectrum_audit,
        stencil,
        tangent_plans,
        weights,
    )
end

# Validate continuation controls and persisted provenance without changing accepted state.
function _validate_solver_restart(state::NamedTuple)
    (;
        amn,
        amn_sha256,
        apply_symmetry,
        basis_sha256,
        compatibility,
        config,
        config_sha256,
        diagnostics,
        effective_algorithms,
        effective_compatibility_policy,
        fixed_subspace,
        frozen_indices,
        frozen_masks,
        full_constraint_scope,
        input_summary,
        mmn,
        nb,
        nk,
        num_wannier,
        observer,
        outer_indices,
        outer_masks,
        paw_scdm_input,
        plan,
        projector_covariance_tolerance,
        representation,
        restart,
        restart_history,
        restart_input_summary,
        restart_state,
        spectrum_audit,
        stencil,
        tangent_plans,
        weights,
    ) = state
    if restart_state !== nothing
        get(restart_input_summary, "construction_policy", "strict") ==
        String(config.input.construction_policy) || return _failure_result(
            INVALID_INPUT,
            [
                WannierizationDiagnostic(
                    :RESTART_CONSTRUCTION_POLICY_MISMATCH,
                    :error,
                    "checkpoint construction policy differs; missing historical policy means strict",
                ),
            ],
            input_summary,
        )
        restart_state.stencil !== nothing || return _failure_result(
            INVALID_INPUT,
            [
                WannierizationDiagnostic(
                    :RESTART_SEMANTICS_INCOMPATIBLE,
                    :error,
                    "strict continuation requires a checkpoint with the complete sealed two-stage S/P boundary",
                ),
            ],
            input_summary,
        )
        restart_contract = WannierizationRestartContract(config)
        pre_v2_12_config_sha256 = restart_contract.legacy_sha256.pre_v2_12
        pre_v2_11_config_sha256 = restart_contract.legacy_sha256.pre_v2_11
        pre_v2_10_config_sha256 = restart_contract.legacy_sha256.pre_v2_10
        pre_v2_9_config_sha256 = restart_contract.legacy_sha256.pre_v2_9
        pre_v2_8_config_sha256 = restart_contract.legacy_sha256.pre_v2_8
        pre_v2_7_config_sha256 = restart_contract.legacy_sha256.pre_v2_7
        pre_v2_6_config_sha256 = restart_contract.legacy_sha256.pre_v2_6
        config_matches =
            restart_state.config_sha256 == config_sha256 ||
            (
                pre_v2_12_config_sha256 !== nothing &&
                restart_state.config_sha256 == pre_v2_12_config_sha256
            ) ||
            (
                pre_v2_11_config_sha256 !== nothing &&
                restart_state.config_sha256 == pre_v2_11_config_sha256
            ) ||
            (
                pre_v2_10_config_sha256 !== nothing &&
                restart_state.config_sha256 == pre_v2_10_config_sha256
            ) ||
            (
                pre_v2_9_config_sha256 !== nothing &&
                restart_state.config_sha256 == pre_v2_9_config_sha256
            ) ||
            (
                pre_v2_8_config_sha256 !== nothing &&
                restart_state.config_sha256 == pre_v2_8_config_sha256
            ) ||
            (
                pre_v2_7_config_sha256 !== nothing &&
                restart_state.config_sha256 == pre_v2_7_config_sha256
            ) ||
            (
                pre_v2_6_config_sha256 !== nothing &&
                restart_state.config_sha256 == pre_v2_6_config_sha256
            )
        if !config_matches
            stored_profile = get(restart_input_summary, "effective_algorithm_profile", "")
            current_profile = String(effective_algorithms.profile)
            profile_mismatch = !isempty(stored_profile) && stored_profile != current_profile
            return _failure_result(
                INVALID_INPUT,
                [
                    WannierizationDiagnostic(
                        profile_mismatch ? :RESTART_EFFECTIVE_PROFILE_MISMATCH :
                        :RESTART_CONFIG_MISMATCH,
                        :error,
                        profile_mismatch ?
                        "restart effective algorithm profile is incompatible with the explicit current configuration" :
                        "restart numerical controls do not match";
                        context = Dict(
                            "stored_effective_algorithm_profile" =>
                                isempty(stored_profile) ? "NOT_RECORDED" : stored_profile,
                            "current_effective_algorithm_profile" => current_profile,
                        ),
                    ),
                ],
                input_summary,
            )
        end
        if pre_v2_11_config_sha256 !== nothing &&
           restart_state.config_sha256 == pre_v2_11_config_sha256
            input_summary["restart_config_compatibility"] = "PRE_V2_11_IMPLICIT_COEFFICIENT_MAPPING"
            push!(
                diagnostics,
                WannierizationDiagnostic(
                    :RESTART_CONFIG_PRE_V2_11_COMPATIBILITY,
                    :info,
                    "schema-2.10 restart matched the explicit coefficient-mapping backend";
                    context = Dict(
                        "stored_config_sha256" => restart_state.config_sha256,
                        "current_config_sha256" => config_sha256,
                    ),
                ),
            )
        elseif pre_v2_10_config_sha256 !== nothing &&
               restart_state.config_sha256 == pre_v2_10_config_sha256
            input_summary["restart_config_compatibility"] = "PRE_V2_10_U_PHASE_CHART_RESET"
            push!(
                diagnostics,
                WannierizationDiagnostic(
                    :RESTART_CONFIG_PRE_V2_10_COMPATIBILITY,
                    :info,
                    "schema-2.9 restart retained its accepted physical state and reset U optimizer history for the centered-residual phase chart";
                    context = Dict(
                        "stored_config_sha256" => restart_state.config_sha256,
                        "current_config_sha256" => config_sha256,
                    ),
                ),
            )
        elseif pre_v2_9_config_sha256 !== nothing &&
               restart_state.config_sha256 == pre_v2_9_config_sha256
            input_summary["restart_config_compatibility"] = "PRE_V2_9_FULL_SCOPE_DEFAULT"
            push!(
                diagnostics,
                WannierizationDiagnostic(
                    :RESTART_CONFIG_PRE_V2_9_COMPATIBILITY,
                    :info,
                    "schema-2.8 restart matched the unchanged full-group constraint scope";
                    context = Dict(
                        "stored_config_sha256" => restart_state.config_sha256,
                        "current_config_sha256" => config_sha256,
                        "constraint_operation_scope" => "full",
                    ),
                ),
            )
        elseif pre_v2_8_config_sha256 !== nothing &&
               restart_state.config_sha256 == pre_v2_8_config_sha256
            input_summary["restart_config_compatibility"] = "PRE_V2_8_JOINT_UPDATE_CONTRACT_RESET"
            push!(
                diagnostics,
                WannierizationDiagnostic(
                    :LEGACY_JOINT_UPDATE_CONTRACT_RESET,
                    :info,
                    "pre-2.8 restart config matched after resetting moving-subspace optimizer history";
                    context = Dict(
                        "stored_config_sha256" => restart_state.config_sha256,
                        "current_config_sha256" => config_sha256,
                    ),
                ),
            )
        elseif pre_v2_7_config_sha256 !== nothing &&
               restart_state.config_sha256 == pre_v2_7_config_sha256
            input_summary["restart_config_compatibility"] = "PRE_V2_7_LOCALIZATION_GRADIENT_CONTRACT_RESET"
            push!(
                diagnostics,
                WannierizationDiagnostic(
                    :RESTART_CONFIG_PRE_V2_7_COMPATIBILITY,
                    :info,
                    "pre-2.7 restart config matched after explicit localization-gradient history reset";
                    context = Dict(
                        "stored_config_sha256" => restart_state.config_sha256,
                        "current_config_sha256" => config_sha256,
                    ),
                ),
            )
        elseif restart_state.config_sha256 != config_sha256
            input_summary["restart_config_compatibility"] = "PRE_V2_6_DEFAULT_RCG_CONTROLS_AND_PRE_V2_7_GRADIENT_RESET"
            push!(
                diagnostics,
                WannierizationDiagnostic(
                    :RESTART_CONFIG_PRE_V2_6_COMPATIBILITY,
                    :info,
                    "pre-2.6 restart config matched after explicit default-RCG projection and localization-gradient history reset";
                    context = Dict(
                        "stored_config_sha256" => restart_state.config_sha256,
                        "current_config_sha256" => config_sha256,
                    ),
                ),
            )
        end
        restart_state.representation_sha256 == compatibility.representation_sha256 ||
            return _failure_result(
                INVALID_INPUT,
                [
                    WannierizationDiagnostic(
                        :RESTART_REPRESENTATION_MISMATCH,
                        :error,
                        "restart representation digest does not match",
                    ),
                ],
                input_summary,
            )
        _restart_stencils_compatible(something(restart_state.stencil), stencil) ||
            return _failure_result(
                INVALID_INPUT,
                [
                    WannierizationDiagnostic(
                        :RESTART_STENCIL_MISMATCH,
                        :error,
                        "restart full-3D stencil digest does not match",
                    ),
                ],
                input_summary,
            )
        if something(restart_state.stencil).digest != stencil.digest
            input_summary["restart_stencil_compatibility"] = "CROSS_PLATFORM_ROUNDOFF_EQUIVALENT"
            push!(
                diagnostics,
                WannierizationDiagnostic(
                    :RESTART_STENCIL_CROSS_PLATFORM_COMPATIBILITY,
                    :info,
                    "restart stencil differs only by tightly bounded platform roundoff";
                    context = Dict(
                        "stored_stencil_sha256" => something(restart_state.stencil).digest,
                        "current_stencil_sha256" => stencil.digest,
                    ),
                ),
            )
        end
        restart_state.projection_basis_sha256 == basis_sha256 || return _failure_result(
            INVALID_INPUT,
            [
                WannierizationDiagnostic(
                    :RESTART_PROJECTION_BASIS_MISMATCH,
                    :error,
                    "restart expanded projection-basis digest does not match",
                ),
            ],
            input_summary,
        )
        restart_state.amn_sha256 == amn_sha256 || return _failure_result(
            INVALID_INPUT,
            [
                WannierizationDiagnostic(
                    :RESTART_AMN_MISMATCH,
                    :error,
                    "restart AMN digest does not match",
                ),
            ],
            input_summary,
        )
        restart_state.iteration < config.solver.max_iterations || return _failure_result(
            INVALID_INPUT,
            [
                WannierizationDiagnostic(
                    :RESTART_ITERATION_LIMIT,
                    :error,
                    "max_iterations must exceed the checkpoint iteration",
                ),
            ],
            input_summary,
        )
    end
    return (;
        amn,
        amn_sha256,
        apply_symmetry,
        basis_sha256,
        compatibility,
        config,
        config_sha256,
        diagnostics,
        effective_algorithms,
        effective_compatibility_policy,
        fixed_subspace,
        frozen_indices,
        frozen_masks,
        full_constraint_scope,
        input_summary,
        mmn,
        nb,
        nk,
        num_wannier,
        observer,
        outer_indices,
        outer_masks,
        paw_scdm_input,
        plan,
        projector_covariance_tolerance,
        representation,
        restart,
        restart_history,
        restart_state,
        spectrum_audit,
        stencil,
        tangent_plans,
        weights,
    )
end
