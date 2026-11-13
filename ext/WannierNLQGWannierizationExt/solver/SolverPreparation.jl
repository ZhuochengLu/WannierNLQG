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
                "action" => "CONTINUE_STANDARD",
                "construction_policy" => "standard",
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
            summary["model_qualification"] = "COMPUTATION_READY"
        end
    end
    return nothing
end

# Retained private test hook forwards to the single preparation assessment.
const _construction_compatibility_quality_failure = construction_compatibility_quality_failure

# Resolve mode, authority and provenance before validating input dimensions.
function _prepare_solver_input_summary(state::NamedTuple)
    (;
        amn,
        compatibility_report,
        config,
        eig,
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
    # Source/evidence authentication belongs to the explicit development audit.
    # A normal solve does not recompute software/evidence content fingerprints.
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
    effective_compatibility_policy = config.input.compatibility_policy
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
        "algorithm_profile" => "auto",
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
        "smv_fletcher_reeves_two_stage_default_selection_reason" =>
            effective_algorithms.default_selection_reason,
        "smv_fletcher_reeves_two_stage_audit_status" => "NOT_CHECKED",
        "smv_fletcher_reeves_two_stage_audit_reason" => "EXPLICIT_DEVELOPMENT_AUDIT_ONLY",
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
            config.input.wannierization_mode == :ordinary ? "STANDARD" : "NOT_APPLICABLE",
        "covariance_qualification" =>
            apply_symmetry ? "HARD_GATE" :
            config.input.wannierization_mode == :ordinary ? "STANDARD" : "NOT_APPLICABLE",
        "source_code" => String(representation.source_code),
        "sewing_backend" =>
            get(representation.conventions, "sewing_backend", "coefficient_mapping"),
        "sewing_metric" =>
            get(representation.conventions, "sewing_metric", "pseudo_coefficient_linear_map"),
        "paw_sewing_thresholds" =>
            get(representation.conventions, "paw_sewing_thresholds", "NOT_APPLICABLE"),
        "wavefunction_gauge_backend" =>
            get(representation.conventions, "wavefunction_gauge_backend", "native_eigenstate"),
        "wavefunction_gauge_definition" =>
            get(representation.conventions, "wavefunction_gauge_definition", "NOT_APPLICABLE"),
        "block_partition_policy" =>
            get(representation.conventions, "block_partition_policy", "NOT_APPLICABLE"),
        "block_partition_policy_definition" => get(
            representation.conventions,
            "block_partition_policy_definition",
            "NOT_APPLICABLE",
        ),
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
        "target_subspace_contract_definition" => target_contract.contract_definition,
        "target_leakage_semantics" => target_contract.target_leakage_semantics,
        "target_leakage_formula_definition" =>
            target_contract.target_leakage_formula_definition,
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
        "controlled_symmetrization_quality_review_recommended" =>
            get(representation.conventions, "quality_review_recommended", "false"),
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
        "disentanglement_algorithm_requested" => String(effective_algorithms.disentanglement),
        "disentanglement_algorithm" => String(effective_algorithms.disentanglement),
        "subspace_gauge_policy" => String(config.solver.acceleration.subspace_gauge_policy),
        "initialization_backend" => string(typeof(config.solver.initialization_backend)),
        "multi_start_enabled" => string(config.solver.multi_start.enabled),
        "multi_start_count" => string(config.solver.multi_start.starts),
        "multi_start_index" => string(config.solver.multi_start.start_index),
        "hot_storage_backend" => String(config.solver.acceleration.hot_storage_backend),
        "requested_initializer" => String(config.solver.initialization),
        "localization_algorithm_requested" => String(effective_algorithms.localization),
        "localization_algorithm" => String(effective_algorithms.localization),
        "smv_fletcher_reeves_two_stage_protocol" =>
            effective_algorithms.localization == :smv_fletcher_reeves_two_stage ?
            "smv-fixed-point-plus-fletcher-reeves-two-stage-v4" : "NOT_APPLICABLE",
        "smv_fletcher_reeves_two_stage_lapack_backend" =>
            effective_algorithms.localization == :smv_fletcher_reeves_two_stage ?
            _recursive_localization_lapack_backend() : "NOT_APPLICABLE",
        "content_hash_authentication" => "NOT_PERFORMED",
        "smv_fletcher_reeves_two_stage_phase_backend" =>
            effective_algorithms.localization == :smv_fletcher_reeves_two_stage ?
            "PLATFORM_LIBM:" * _RECURSIVE_LOCALIZATION_SYSTEM_LIBM : "NOT_APPLICABLE",
        "localization_gradient_contract" => LOCALIZATION_GRADIENT_CONTRACT,
        "joint_update_contract" => JOINT_UPDATE_CONTRACT,
        "z_u_stage_semantics" => "disentanglement_localization_decoupled_v1",
        "disentanglement_limit_policy" =>
            String(config.solver.acceleration.disentanglement_limit_policy),
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
        "u_wolfe_c2" => string(config.solver.acceleration.u_wolfe_c2),
        "u_line_search_max_trials" =>
            string(config.solver.acceleration.u_line_search_max_trials),
        "u_recursive_localization_restart_interval" =>
            string(config.solver.acceleration.u_recursive_localization_restart_interval),
        "u_recursive_localization_trial_step" =>
            string(config.solver.acceleration.u_recursive_localization_trial_step),
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
        "quality_review_recommended" => "false",
        "ordinary_calculation_policy_version" => "1.0",
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
        "z_seal_class" => "IN_PROGRESS",
        "localization_convergence" =>
            (config.solver.stage_controls.num_iter > 0) ? "NOT_STARTED" : "NOT_APPLICABLE",
        "localization_qualification" =>
            (config.solver.stage_controls.num_iter > 0) ? "NOT_STARTED" : "NOT_APPLICABLE",
        "model_qualification" => "NOT_AVAILABLE",
        "random_seed" => string(config.solver.random_seed),
        "parallel" => String(config.solver.parallel),
        "u_localization_parallel_contract" =>
            config.solver.parallel == :mpi ?
            "CYCLIC_KPOINT_NEIGHBOR_EDGE_DENSE_OWNER_REDUCTION" : "LOCAL_CANONICAL_EDGE_ORDER",
        "u_localization_mpi_size" => string(u_localization_mpi_size),
        "convergence_tolerance" => string(config.solver.stage_controls.conv_tol),
        "convergence_window" => string(max(2, config.solver.stage_controls.conv_window)),
    )
    if !full_constraint_scope
        push!(
            diagnostics,
            WannierizationDiagnostic(
                :DIAGNOSTIC_SYMMETRY_ABLATION,
                :warning,
                "constraint-operation subgroup ablation is standard and cannot produce a standard or production-qualified TB";
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
    projection_basis = something(config.input.projection_basis)
    input_summary["content_hash_authentication"] = "NOT_PERFORMED"
    input_summary["projection_radial_transform_method"] =
        String(projection_basis.radial_transform.method)
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

        apply_symmetry,

        compatibility_report,
        config,
        diagnostics,
        effective_algorithms,
        effective_compatibility_policy,
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

        apply_symmetry,

        compatibility_report,
        config,
        diagnostics,
        effective_algorithms,
        effective_compatibility_policy,
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
        BitMatrix(hcat(frozen_masks...));
        content_authentication = false,
    )
    input_summary["disentanglement_outer_mask_definition"] =
        solver_qualification_scope.outer_mask_definition
    input_summary["disentanglement_frozen_mask_definition"] =
        solver_qualification_scope.frozen_mask_definition
    if target_subspace_authority
        for (key, observed) in (
            ("outer_mask_definition", solver_qualification_scope.outer_mask_definition),
            ("frozen_mask_definition", solver_qualification_scope.frozen_mask_definition),
        )
            recorded = get(representation.conventions, key, nothing)
            recorded == observed || return _failure_result(
                INVALID_INPUT,
                [
                    WannierizationDiagnostic(
                        :TARGET_SUBSPACE_CONTRACT_MISMATCH,
                        :error,
                        "solver window mask differs from the sealed target-subspace contract";
                        context = Dict(
                            "mask" => key,
                            "recorded_definition" => string(recorded),
                            "observed_definition" => string(observed),
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
    input_summary["constraint_operation_parent_indices"] = get(
        representation.conventions,
        "constraint_operation_parent_indices",
        join(eachindex(representation.operations), ','),
    )
    input_summary["representation_compatible"] =
        apply_symmetry ? string(compatibility.passed) : "NOT_APPLICABLE"
    compatibility_records = [
        effective_compatibility_policy != :strict &&
        _construction_compatibility_quality_failure(diagnostic) ?
        _construction_quality_diagnostic(diagnostic, "representation_compatibility") :
        diagnostic for diagnostic in compatibility.diagnostics
    ]
    append!(diagnostics, compatibility_records)
    structural_compatibility_failure = any(
        diagnostic ->
            diagnostic.severity == :error &&
            !_construction_compatibility_quality_failure(diagnostic),
        compatibility.diagnostics,
    )
    if !compatibility.passed &&
       (structural_compatibility_failure || effective_compatibility_policy == :strict)
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
    if (config.solver.stage_controls.num_iter > 0) && apply_symmetry
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
                    "qualification_record" =>
                        compatibility.qualification_record === nothing ? "NOT_AVAILABLE" :
                        "ACTUAL_DEFINITIONS_PRESENT",
                ),
            ),
        )
    end
    stencil = try
        effective_algorithms.disentanglement == :smv_fletcher_reeves_two_stage ?
        _recursive_localization_finite_difference_weights(
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
    input_summary["finite_difference_completeness_residual"] = string(stencil.completeness_residual)
    return (;
        amn,

        apply_symmetry,

        compatibility,
        config,

        diagnostics,
        effective_algorithms,
        effective_compatibility_policy,
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
# Preserve only a version actually present in the validated predecessor;
# an absent value stays absent and is never inferred here.
function _inherit_restart_initializer_version!(summary, restart_state, previous_summary)
    if restart_state !== nothing && haskey(previous_summary, "initializer_algorithm_version")
        summary["initializer_algorithm_version"] = previous_summary["initializer_algorithm_version"]
    end
    return summary
end

# Validate complete restart inputs and accepted-state identity before initializing frames.
function _validate_solver_restart(state::NamedTuple)
    (;
        amn,

        apply_symmetry,

        compatibility,
        config,

        diagnostics,
        effective_algorithms,
        effective_compatibility_policy,
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
    input_definition=try
        allow_owned_hr_operator_upgrade =
            restart_state !== nothing &&
            (
                uses_native_operator_generation(config.input) ||
                config.input.matrix_elements isa ExternalOverlapProjectionMatrices
            ) &&
            config.output.profile === :full &&
            restart_state.input_definition !== nothing &&
            !haskey(restart_state.input_definition.auxiliary_sources, "operator_profile_sources") &&
            haskey(representation.input_definitions, "operator_profile_sources") &&
            get(restart_input_summary, "operator_profile_preflight_profile", "") ==
            "hamiltonian_position" &&
            get(restart_input_summary, "operator_profile_preflight_status", "") == "NOT_APPLICABLE"
        definition=_restart_input_definition(
            config,
            representation,
            mmn,
            amn,
            effective_algorithms,
            apply_symmetry;
            require_expected = restart_state!==nothing,
            expected = restart_state===nothing ? nothing : restart_state.input_definition,
            allow_new_operator_profile_sources = allow_owned_hr_operator_upgrade,
        )
        restart_state===nothing || _validate_current_u_branch_history(restart_state.optimizer_state)
        definition
    catch exception
        exception isa ArgumentError || rethrow()
        message=sprint(showerror, exception)
        codes=(
            :RESTART_CONFIG_MISMATCH,
            :RESTART_PROJECTION_BASIS_MISMATCH,
            :RESTART_REPRESENTATION_MISMATCH,
            :RESTART_MMN_MISMATCH,
            :RESTART_AMN_MISMATCH,
            :RESTART_INPUT_DEFINITION_REQUIRED,
            :RESTART_U_BRANCH_DEFINITION_REQUIRED,
            :RESTART_U_BRANCH_AUDIT_MISMATCH,
        )
        selected=findfirst(code->occursin(String(code), message), codes)
        code=selected===nothing ? :RESTART_INPUT_DEFINITION_INVALID : codes[selected]
        context=Dict{String, String}()
        if code==:RESTART_CONFIG_MISMATCH && restart_state!==nothing
            stored_profile=get(restart_input_summary, "effective_algorithm_profile", "")
            current_profile=String(effective_algorithms.profile)
            if !isempty(stored_profile) && stored_profile!=current_profile
                code=:RESTART_EFFECTIVE_PROFILE_MISMATCH
                message="restart effective algorithm profile is incompatible with the explicit current configuration"
                context["stored_effective_algorithm_profile"]=stored_profile
                context["current_effective_algorithm_profile"]=current_profile
            end
        end
        return _failure_result(
            INVALID_INPUT,
            [WannierizationDiagnostic(code, :error, message; context)],
            input_summary,
        )
    end
    if restart_state !== nothing
        # The complete configuration and source definitions were compared above.
        # In-memory accepted states need no redundant digest identity proof.
        recorded_construction_policy = get(
            restart_input_summary,
            "construction_policy",
            String(config.input.construction_policy),
        )
        recorded_construction_policy == String(config.input.construction_policy) ||
            return _failure_result(
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
        _restart_stencils_compatible(something(restart_state.stencil), stencil) ||
            return _failure_result(
                INVALID_INPUT,
                [
                    WannierizationDiagnostic(
                        :RESTART_STENCIL_MISMATCH,
                        :error,
                        "restart full-3D stencil values do not match",
                    ),
                ],
                input_summary,
            )
        # Configuration, representation, basis, overlaps and initializer were
        # checked by complete definitions above. No content digest is required.
        (
            config.solver.stage_controls !== nothing ||
            restart_state.iteration < Base.Checked.checked_add(
                config.solver.stage_controls.dis_num_iter,
                config.solver.stage_controls.num_iter,
            )
        ) || return _failure_result(
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
    # A validated restart continues the same accepted initializer history.
    # Preserve its recorded version verbatim; missing values remain missing.
    _inherit_restart_initializer_version!(input_summary, restart_state, restart_input_summary)
    return (;
        input_definition,
        amn,

        apply_symmetry,

        compatibility,
        config,

        diagnostics,
        effective_algorithms,
        effective_compatibility_policy,
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
