# Independent frozen029 binding oracle. Never imported by production.
module PreviousCheckpointBinding
import SHA
import WannierNLQG.Wannierization:
    WannierizationResult,
    WANNIERIZATION_ELIGIBILITY_SUMMARY_KEYS,
    wannierization_eligibility_summary,
    wannierization_eligibility_from_summary,
    not_evaluated_wannierization_eligibility
function _wannierization_checkpoint_sha256(result::WannierizationResult)
    buffer = IOBuffer()
    write(buffer, string(result.status), '\n')
    for values in (result.v_matrix, result.wannier_centers_cartesian, result.spreads_angstrom2)
        write(buffer, reinterpret(UInt8, Int64[ndims(values), size(values)...]))
        write(buffer, reinterpret(UInt8, vec(values)))
    end
    history_values = (
        Int[entry.iteration for entry in result.history],
        Float64[entry.spread_total for entry in result.history],
        Float64[entry.spread_standard_deviation for entry in result.history],
        Float64[entry.maximum_covariance_error for entry in result.history],
    )
    for values in history_values
        write(buffer, reinterpret(UInt8, Int64[length(values)]))
        write(buffer, reinterpret(UInt8, vec(values)))
    end
    for key in ("input_sha256", "restart_config_sha256", "representation_sha256")
        write(buffer, key, '\0', get(result.input_summary, key, ""), '\n')
    end
    return bytes2hex(SHA.sha256(take!(buffer)))
end

function _wannierization_checkpoint_sha256_v1_2(result::WannierizationResult)
    buffer = IOBuffer()
    write(buffer, _wannierization_checkpoint_sha256(result), '\n')
    for entry in result.history
        values = entry.diagnostics
        write(buffer, UInt8(values !== nothing))
        values === nothing && continue
        diagnostics = something(values)
        directional =
            diagnostics.omega_directional === nothing ? (NaN, NaN, NaN) :
            something(diagnostics.omega_directional)
        write(
            buffer,
            reinterpret(
                UInt8,
                collect((
                    directional...,
                    diagnostics.omega_total,
                    diagnostics.projector_residual,
                    diagnostics.z_residual,
                    diagnostics.u_residual,
                    diagnostics.wcc_step_maximum,
                    diagnostics.spread_step_maximum,
                    diagnostics.little_group_residual,
                    diagnostics.z_boundary_gap,
                    diagnostics.z_mix_ratio,
                    diagnostics.u_mix_ratio,
                ),),
            ),
        )
        write(
            buffer,
            reinterpret(
                UInt8,
                Int64[
                    diagnostics.u_inner_sweeps,
                    diagnostics.anderson_used,
                    diagnostics.anderson_fallback,
                    diagnostics.rejected_steps,
                ],
            ),
        )
    end
    if result.restart_state !== nothing
        state = something(result.restart_state)
        write(buffer, state.projection_basis_definition, '\n', state.amn_sha256, '\n')
        if state.stencil !== nothing
            stencil = something(state.stencil)
            for values in (
                stencil.vectors_cartesian,
                stencil.shell_ids,
                stencil.weights,
                stencil.target_moment,
            )
                write(buffer, reinterpret(UInt8, vec(values)))
            end
            write(buffer, stencil.digest, '\n')
        end
        optimizer = state.optimizer_state
        write(
            buffer,
            repr((
                optimizer.strategy,
                optimizer.z_mix_ratio,
                optimizer.u_mix_ratio,
                optimizer.improvement_streak,
                optimizer.rejected_steps,
                optimizer.residual_reference,
                optimizer.previous_merit,
            ),),
        )
        write(buffer, reinterpret(UInt8, vec(optimizer.anderson_z_history)))
        write(buffer, reinterpret(UInt8, vec(optimizer.anderson_residual_history)))
    end
    return bytes2hex(SHA.sha256(take!(buffer)))
end

function _wannierization_checkpoint_sha256_v1_3(result::WannierizationResult)
    buffer = IOBuffer()
    write(buffer, _wannierization_checkpoint_sha256_v1_2(result), '\n')
    if result.restart_state !== nothing
        optimizer = something(result.restart_state).optimizer_state
        write(
            buffer,
            repr((
                optimizer.phase,
                optimizer.z_stability_count,
                optimizer.u_stability_count,
                optimizer.z_steps,
                optimizer.u_steps,
                optimizer.epoch,
                optimizer.last_accepted_u_step_scale,
                optimizer.gradient_fallback_active,
                optimizer.gradient_steps,
                optimizer.best_polar_objective,
            )),
        )
        write(buffer, reinterpret(UInt8, vec(optimizer.best_polar_frames)))
        write(buffer, reinterpret(UInt8, vec(optimizer.best_polar_centers)))
        write(buffer, reinterpret(UInt8, vec(optimizer.best_polar_spreads)))
    end
    return bytes2hex(SHA.sha256(take!(buffer)))
end

function _wannierization_checkpoint_sha256_v2_1(result::WannierizationResult)
    buffer = IOBuffer()
    write(buffer, _wannierization_checkpoint_sha256_v1_3(result), '\n')
    terminal_keys = sort!([
        key for key in keys(result.input_summary) if startswith(key, "hard_gate_") || key in (
            "solver_status",
            "stopping_reason",
            "last_attempted_iteration",
            "last_accepted_iteration",
            "last_persisted_iteration",
            "has_accepted_state",
            "legacy_terminal_semantics",
            "convergence_metric_name",
            "convergence_metric",
        )
    ],)
    for key in terminal_keys
        write(buffer, key, '\0', result.input_summary[key], '\n')
    end
    return bytes2hex(SHA.sha256(take!(buffer)))
end

function _wannierization_checkpoint_sha256_v2_2(result::WannierizationResult)
    buffer = IOBuffer()
    write(buffer, _wannierization_checkpoint_sha256_v2_1(result), '\n')
    for key in (
        "initialization_status",
        "initializer_algorithm_version",
        "solver_convergence",
        "numerical_quality",
        "tb_export_status",
    )
        write(buffer, key, '\0', get(result.input_summary, key, "NOT_RECORDED"), '\n')
    end
    for entry in result.history
        diagnostics = entry.diagnostics
        diagnostics === nothing && continue
        values = something(diagnostics)
        write(
            buffer,
            reinterpret(
                UInt8,
                Float64[
                    values.projected_gradient_rms,
                    values.accepted_u_step_scale,
                    values.localization_backtracking_steps,
                ],
            ),
        )
    end
    report = result.initialization_report
    write(buffer, UInt8(report !== nothing))
    if report !== nothing
        evidence = something(report)
        write(
            buffer,
            String(evidence.algorithm),
            '\0',
            evidence.algorithm_version,
            '\0',
            String(evidence.status),
            '\n',
        )
        for diagnostic in evidence.kpoints
            write(
                buffer,
                reinterpret(
                    UInt8,
                    Int64[
                        diagnostic.kpoint,
                        diagnostic.full_amn_rank,
                        diagnostic.outer_amn_rank,
                        diagnostic.frozen_amn_rank,
                        diagnostic.projected_free_rank,
                        diagnostic.target_completion_count,
                        diagnostic.band_completion_count,
                    ],
                ),
            )
            for spectrum in (
                diagnostic.full_amn_singular_values,
                diagnostic.outer_amn_singular_values,
                diagnostic.frozen_amn_singular_values,
                diagnostic.projected_free_singular_values,
                diagnostic.alignment_singular_values,
            )
                write(buffer, reinterpret(UInt8, Int64[length(spectrum)]))
                write(buffer, reinterpret(UInt8, spectrum))
            end
            write(
                buffer,
                reinterpret(
                    UInt8,
                    Float64[
                        diagnostic.full_amn_rank_threshold,
                        diagnostic.outer_amn_rank_threshold,
                        diagnostic.frozen_amn_rank_threshold,
                        diagnostic.projected_free_rank_threshold,
                        diagnostic.alignment_condition,
                        diagnostic.isometry_before,
                        diagnostic.isometry_after,
                        diagnostic.frozen_residual_before,
                        diagnostic.frozen_residual_after,
                    ],
                ),
            )
        end
    end
    return bytes2hex(SHA.sha256(take!(buffer)))
end

function _wannierization_checkpoint_sha256_v2_3(result::WannierizationResult)
    buffer = IOBuffer()
    write(buffer, _wannierization_checkpoint_sha256_v2_2(result), '\n')
    if result.restart_state !== nothing
        optimizer = something(result.restart_state).optimizer_state
        for values in (
            optimizer.disentanglement_objective_history,
            optimizer.localization_objective_history,
            optimizer.localization_trial_step_scales,
            optimizer.localization_trial_objectives,
            optimizer.localization_trial_required_changes,
            optimizer.localization_trial_actual_changes,
        )
            write(buffer, reinterpret(UInt8, vec(values)))
        end
    end
    return bytes2hex(SHA.sha256(take!(buffer)))
end

function _wannierization_checkpoint_sha256_v2_4(result::WannierizationResult)
    buffer = IOBuffer()
    write(buffer, _wannierization_checkpoint_sha256_v2_3(result), '\n')
    if result.restart_state !== nothing
        state = something(result.restart_state)
        for values in (
            state.fixed_subspace_projectors,
            state.fixed_subspace_frames,
            state.localization_initial_frames,
            state.optimizer_state.localization_trial_directional_derivatives,
            state.optimizer_state.localization_projector_drift_history,
        )
            write(buffer, UInt8(values !== nothing))
            values === nothing || write(buffer, reinterpret(UInt8, vec(values)))
        end
        write(
            buffer,
            reinterpret(UInt8, Int64.(state.optimizer_state.localization_trial_iterations)),
        )
        write(buffer, reinterpret(UInt8, Int64.(state.optimizer_state.localization_trial_sweeps)))
        write(buffer, UInt8.(state.optimizer_state.localization_trial_accepted))
    end
    for entry in result.history
        entry.diagnostics === nothing && continue
        values = something(entry.diagnostics)
        write(
            buffer,
            reinterpret(
                UInt8,
                Float64[
                    values.localization_directional_derivative,
                    values.fixed_projector_drift,
                    values.localization_base_objective,
                    values.localization_required_change,
                    values.localization_actual_change,
                ],
            ),
        )
    end
    return bytes2hex(SHA.sha256(take!(buffer)))
end

function _wannierization_checkpoint_sha256_v2_5(result::WannierizationResult)
    buffer = IOBuffer()
    write(buffer, _wannierization_checkpoint_sha256_v2_4(result), '\n')
    write(buffer, result.tb_symmetry_qualification.payload_sha256)
    return bytes2hex(SHA.sha256(take!(buffer)))
end

function _wannierization_checkpoint_sha256_v2_6(result::WannierizationResult)
    buffer = IOBuffer()
    write(buffer, _wannierization_checkpoint_sha256_v2_5(result), '\n')
    if result.restart_state !== nothing
        optimizer = something(result.restart_state).optimizer_state
        for values in (optimizer.previous_u_gradient, optimizer.previous_u_direction)
            write(buffer, reinterpret(UInt8, Int64[ndims(values), size(values)...]))
            write(buffer, reinterpret(UInt8, vec(values)))
        end
        write(
            buffer,
            repr((
                optimizer.u_cg_iteration,
                optimizer.u_cg_restart_count,
                optimizer.last_cg_beta,
                optimizer.last_cg_restart_reason,
                optimizer.last_anderson_reason,
            )),
        )
    end
    for entry in result.history
        entry.diagnostics === nothing && continue
        values = something(entry.diagnostics)
        write(
            buffer,
            repr((
                values.anderson_reason,
                values.minimum_diagonal_phase_margin,
                values.minimum_phase_kpoint,
                values.minimum_phase_neighbor,
                values.minimum_phase_wannier,
                values.cg_beta,
                values.cg_restarted,
                values.cg_restart_reason,
                values.cg_descent_cosine,
                values.maximum_kstar_gradient_rms,
                values.maximum_kstar_gradient_index,
            )),
        )
    end
    return bytes2hex(SHA.sha256(take!(buffer)))
end

function _wannierization_checkpoint_sha256_v2_7(result::WannierizationResult)
    buffer = IOBuffer()
    write(buffer, _wannierization_checkpoint_sha256_v2_6(result), '\n')
    write(buffer, get(result.input_summary, "localization_gradient_contract", "NOT_RECORDED"), '\n')
    return bytes2hex(SHA.sha256(take!(buffer)))
end

function _wannierization_checkpoint_sha256_v2_8(result::WannierizationResult)
    buffer = IOBuffer()
    write(buffer, _wannierization_checkpoint_sha256_v2_7(result), '\n')
    for key in (
        "joint_update_contract",
        "disentanglement_limit_policy",
        "z_seal_class",
        "qualified_z_seal",
        "route_selection_eligible",
        "standard_tb_export_eligible",
    )
        write(buffer, key, '=', get(result.input_summary, key, "NOT_RECORDED"), '\n')
    end
    for entry in result.history
        entry.diagnostics === nothing && continue
        values = something(entry.diagnostics)
        write(
            buffer,
            repr((
                values.omega_i,
                values.delta_omega_i,
                values.z_stability_count,
                values.joint_z_backtracking_steps,
                values.joint_transport_minimum_singular_value,
                values.joint_transport_maximum_condition,
                values.joint_acceptance_reason,
            )),
        )
    end
    return bytes2hex(SHA.sha256(take!(buffer)))
end

function _wannierization_checkpoint_sha256_v2_9(result::WannierizationResult)
    buffer = IOBuffer()
    write(buffer, _wannierization_checkpoint_sha256_v2_8(result), '\n')
    for key in (
        "constraint_operation_scope",
        "constraint_operation_parent_representation_sha256",
        "constraint_operation_subgroup_sha256",
        "constraint_operation_parent_indices",
        "symmetry_ablation_classification",
        "z_link_minimum_singular_value",
        "z_link_maximum_invariant_defect",
        "z_link_top_one_percent_concentration",
        "z_link_worst_source_kpoint",
        "z_link_worst_neighbor",
        "z_link_worst_target_kpoint",
    )
        write(buffer, key, '=', get(result.input_summary, key, "NOT_RECORDED"), '\n')
    end
    return bytes2hex(SHA.sha256(take!(buffer)))
end

function _wannierization_checkpoint_sha256_v2_10(result::WannierizationResult)
    buffer = IOBuffer()
    write(buffer, _wannierization_checkpoint_sha256_v2_9(result), '\n')
    if result.restart_state !== nothing
        optimizer = something(result.restart_state).optimizer_state
        write(
            buffer,
            repr((
                optimizer.u_phase_contract,
                optimizer.u_active_orbit_sha256,
                optimizer.u_active_orbit_count,
                optimizer.u_generalized_gradient_rms,
                optimizer.u_lbfgs_rho_history,
                optimizer.u_lbfgs_restart_count,
                optimizer.last_u_optimizer_restart_reason,
            )),
        )
        for values in (optimizer.u_lbfgs_s_history, optimizer.u_lbfgs_y_history)
            write(buffer, reinterpret(UInt8, Int64[ndims(values), size(values)...]))
            write(buffer, reinterpret(UInt8, vec(values)))
        end
    end
    for key in (
        "u_phase_branch_tolerance",
        "u_branch_active_set_max_orbits",
        "u_lbfgs_history",
        "u_lbfgs_curvature_tolerance",
        "u_wolfe_c2",
        "u_line_search_max_trials",
    )
        write(buffer, key, '=', get(result.input_summary, key, "NOT_RECORDED"), '\n')
    end
    return bytes2hex(SHA.sha256(take!(buffer)))
end

function _wannierization_checkpoint_sha256_v2_11(result::WannierizationResult)
    buffer = IOBuffer()
    write(buffer, _wannierization_checkpoint_sha256_v2_10(result), '\n')
    for (key, default_value) in (
        ("sewing_backend", "coefficient_mapping"),
        ("sewing_metric", "pseudo_coefficient_linear_map"),
        ("paw_sewing_thresholds", "NOT_APPLICABLE"),
        ("strict_sewing_diagnostics_sha256", "NOT_RECORDED"),
    )
        write(buffer, key, '=', get(result.input_summary, key, default_value), '\n')
    end
    return bytes2hex(SHA.sha256(take!(buffer)))
end

function _wannierization_checkpoint_sha256_v2_12(result::WannierizationResult)
    buffer = IOBuffer()
    write(buffer, _wannierization_checkpoint_sha256_v2_11(result), '\n')
    for (key, default_value) in (
        ("wavefunction_gauge_backend", "native_eigenstate"),
        ("wavefunction_gauge_hdf5_sha256", "NOT_APPLICABLE"),
    )
        write(buffer, key, '=', get(result.input_summary, key, default_value), '\n')
    end
    return bytes2hex(SHA.sha256(take!(buffer)))
end

function _wannierization_checkpoint_sha256_v2_13(result::WannierizationResult)
    buffer = IOBuffer()
    write(buffer, _wannierization_checkpoint_sha256_v2_12(result), '\n')
    for (key, default_value) in (
        ("block_partition_policy", "NOT_APPLICABLE"),
        ("block_partition_policy_sha256", "NOT_APPLICABLE"),
    )
        write(buffer, key, '=', get(result.input_summary, key, default_value), '\n')
    end
    return bytes2hex(SHA.sha256(take!(buffer)))
end

function _wannierization_checkpoint_sha256_v2_16(result::WannierizationResult)
    buffer = IOBuffer()
    write(buffer, _wannierization_checkpoint_sha256_v2_13(result), '\n')
    for (key, default_value) in (
        ("authoritative_hamiltonian", "native_dft"),
        ("authoritative_hamiltonian_sha256", "LEGACY_NATIVE_DFT"),
        ("native_fidelity_status", "NOT_RECORDED"),
        ("symmetrized_hamiltonian_status", "NOT_APPLICABLE"),
        ("scoped_production_eligible", "false"),
        ("global_production_eligible", "false"),
    )
        write(buffer, key, '=', get(result.input_summary, key, default_value), '\n')
    end
    return bytes2hex(SHA.sha256(take!(buffer)))
end

function _wannierization_checkpoint_sha256_v2_17(result::WannierizationResult)
    buffer = IOBuffer()
    write(buffer, _wannierization_checkpoint_sha256_v2_16(result), '\n')
    for (key, default_value) in (
        ("energy_shift_qualification", "legacy_energy_shift_hard_gate"),
        ("maximum_energy_shift_audit_reference_ev", "NOT_APPLICABLE"),
        ("rms_energy_shift_audit_reference_ev", "NOT_APPLICABLE"),
        ("target_energy_shift_audit_status", "NOT_APPLICABLE"),
        ("symmetrized_parent_energy_shift_audit_status", "NOT_APPLICABLE"),
    )
        write(buffer, key, '=', get(result.input_summary, key, default_value), '\n')
    end
    return bytes2hex(SHA.sha256(take!(buffer)))
end

function _wannierization_checkpoint_sha256_v2_18(result::WannierizationResult)
    buffer = IOBuffer()
    write(buffer, _wannierization_checkpoint_sha256_v2_17(result), '\n')
    for (key, default_value) in (
        ("residual_gate_phase", "legacy_pre_symmetrization"),
        ("raw_preflight_diagnostic_status", "NOT_APPLICABLE"),
    )
        write(buffer, key, '=', get(result.input_summary, key, default_value), '\n')
    end
    return bytes2hex(SHA.sha256(take!(buffer)))
end

function _wannierization_checkpoint_sha256_v2_19(result::WannierizationResult)
    buffer = IOBuffer()
    write(buffer, _wannierization_checkpoint_sha256_v2_18(result), '\n')
    for (key, default_value) in (
        ("native_difference_qualification", "legacy_hard_gate"),
        ("native_difference_audit_status", "NOT_APPLICABLE"),
    )
        write(buffer, key, '=', get(result.input_summary, key, default_value), '\n')
    end
    return bytes2hex(SHA.sha256(take!(buffer)))
end

function _wannierization_checkpoint_sha256_v2_20(result::WannierizationResult)
    buffer = IOBuffer()
    write(buffer, _wannierization_checkpoint_sha256_v2_19(result), '\n')
    for (key, default_value) in (
        ("qualification_scope", "full_parent"),
        ("target_anchor", "NOT_APPLICABLE"),
        ("target_complement_completion", "NOT_APPLICABLE"),
        ("target_complement_max_element_ev", "NOT_APPLICABLE"),
        ("auxiliary_parent_qualification", "legacy_hard_gate"),
        ("symmetrized_target_subspace_status", "NOT_APPLICABLE"),
        ("auxiliary_parent_audit_status", "NOT_APPLICABLE"),
        ("target_scope_production_eligible", "false"),
    )
        write(buffer, key, '=', get(result.input_summary, key, default_value), '\n')
    end
    return bytes2hex(SHA.sha256(take!(buffer)))
end

function _wannierization_checkpoint_sha256_v2_21(result::WannierizationResult)
    buffer = IOBuffer()
    write(buffer, _wannierization_checkpoint_sha256_v2_20(result), '\n')
    for (key, default_value) in (
        ("z_u_stage_semantics", "disentanglement_localization_decoupled_v1"),
        ("disentanglement_algorithm", "smv_fixed_point"),
        ("subspace_gauge_policy", "legacy"),
        ("localization_algorithm", "steepest_descent"),
        ("initialization_backend", "AMNExactFrozenInitialization"),
        ("multi_start_enabled", "false"),
        ("multi_start_count", "1"),
        ("multi_start_index", "1"),
        ("hot_storage_backend", "legacy_vector"),
        ("hermitian_residual_rtol", "1.0e-12"),
        ("subspace_cluster_atol", "1.0e-12"),
        ("subspace_cluster_rtol", "1.0e-8"),
        ("frame_transport_atol", "1.0e-14"),
        ("frame_transport_rtol", "1.0e-12"),
        ("projectability_minimum_singular_value", "1.0e-8"),
        ("maximum_transport_condition", "1.0e10"),
        ("disentanglement_state_sha256", "NOT_SEALED"),
        ("disentanglement_outer_mask_sha256", "NOT_SEALED"),
        ("disentanglement_frozen_mask_sha256", "NOT_SEALED"),
        ("disentanglement_projector_residual", "NOT_SEALED"),
        ("disentanglement_state_converged", "false"),
    )
        write(buffer, key, '=', get(result.input_summary, key, default_value), '\n')
    end
    return bytes2hex(SHA.sha256(take!(buffer)))
end

function _wannierization_checkpoint_sha256_v2_22(result::WannierizationResult)
    buffer = IOBuffer()
    write(buffer, _wannierization_checkpoint_sha256_v2_21(result), '\n')
    for (key, default_value) in (
        ("algorithm_profile", "legacy"),
        ("effective_algorithm_profile", "legacy"),
        ("disentanglement_algorithm_requested", "legacy"),
        ("localization_algorithm_requested", "legacy"),
        ("recursive_localization_protocol", "NOT_APPLICABLE"),
    )
        write(buffer, key, '=', get(result.input_summary, key, default_value), '\n')
    end
    if result.restart_state !== nothing
        optimizer = something(result.restart_state).optimizer_state
        for values in
            (optimizer.recursive_localization_overlaps, optimizer.recursive_localization_unitaries)
            write(buffer, reinterpret(UInt8, Int64[ndims(values), size(values)...]))
            write(buffer, reinterpret(UInt8, vec(values)))
        end
        write(buffer, reinterpret(UInt8, [optimizer.recursive_localization_omega_i]))
    end
    return bytes2hex(SHA.sha256(take!(buffer)))
end

function _wannierization_checkpoint_sha256_v2_23(result::WannierizationResult)
    buffer = IOBuffer()
    write(buffer, _wannierization_checkpoint_sha256_v2_22(result), '\n')
    for (key, default_value) in (
        ("recursive_localization_algorithm_contract_version", "legacy"),
        ("recursive_localization_validation_standard_version", "legacy"),
        ("recursive_localization_validation_semantic", "legacy"),
        ("recursive_localization_accepted_step_combination_rule", "NOT_APPLICABLE"),
        ("recursive_localization_accepted_step_absolute_tolerance", "NOT_APPLICABLE"),
        ("recursive_localization_accepted_step_relative_tolerance", "NOT_APPLICABLE"),
        ("recursive_localization_validation_contract_sha256", "NOT_APPLICABLE"),
        ("recursive_localization_default_qualification_status", "NOT_QUALIFIED"),
        ("recursive_localization_default_qualification_manifest_sha256", "NOT_AVAILABLE"),
    )
        write(buffer, key, '=', get(result.input_summary, key, default_value), '\n')
    end
    return bytes2hex(SHA.sha256(take!(buffer)))
end

function _wannierization_checkpoint_sha256_v2_24(result::WannierizationResult)
    buffer = IOBuffer()
    write(buffer, _wannierization_checkpoint_sha256_v2_23(result), '\n')
    write(buffer, "checkpoint_schema_version=2.24\n")
    return bytes2hex(SHA.sha256(take!(buffer)))
end

function _wannierization_checkpoint_sha256_v2_25(result::WannierizationResult)
    buffer = IOBuffer()
    write(buffer, _wannierization_checkpoint_sha256_v2_24(result), '\n')
    for (key, default_value) in (
        ("requested_wannierization_mode", "MISSING"),
        ("effective_wannierization_mode", "MISSING"),
        ("representation_source", "MISSING"),
        ("symmetry_constraints_applied", "MISSING"),
        ("effective_algorithm_profile", "MISSING"),
        ("recursive_localization_algorithm_contract_version", "MISSING"),
    )
        write(buffer, key, '=', get(result.input_summary, key, default_value), '\n')
    end
    write(buffer, "checkpoint_schema_version=2.25\n")
    return bytes2hex(SHA.sha256(take!(buffer)))
end

function _wannierization_checkpoint_sha256_v2_26(result::WannierizationResult)
    buffer = IOBuffer()
    write(buffer, _wannierization_checkpoint_sha256_v2_24(result), '\n')
    for (key, default_value) in (
        ("requested_wannierization_mode", "MISSING"),
        ("effective_wannierization_mode", "MISSING"),
        ("representation_source", "MISSING"),
        ("symmetry_constraints_applied", "MISSING"),
        ("effective_algorithm_profile", "MISSING"),
        ("smv_fletcher_reeves_two_stage_algorithm_contract_version", "MISSING"),
        ("smv_fletcher_reeves_two_stage_default_selection_reason", "MISSING"),
    )
        write(buffer, key, '=', get(result.input_summary, key, default_value), '\n')
    end
    write(buffer, "checkpoint_schema_version=2.26\n")
    return bytes2hex(SHA.sha256(take!(buffer)))
end

function _wannierization_checkpoint_sha256_v2_27(result::WannierizationResult)
    buffer = IOBuffer()
    write(buffer, _wannierization_checkpoint_sha256_v2_26(result), '\n')
    for (key, default_value) in (
        ("authoritative_hamiltonian", "MISSING"),
        ("authoritative_hamiltonian_sha256", "MISSING"),
        ("qualification_scope", "MISSING"),
        ("target_authority", "MISSING"),
        ("parent_audit_policy", "MISSING"),
        ("disentanglement_outer_mask_sha256", "MISSING"),
        ("disentanglement_frozen_mask_sha256", "MISSING"),
        ("target_subspace_contract_sha256", "NOT_RECORDED"),
    )
        write(buffer, key, '=', get(result.input_summary, key, default_value), '\n')
    end
    write(buffer, "checkpoint_schema_version=2.27\n")
    return bytes2hex(SHA.sha256(take!(buffer)))
end

function _wannierization_checkpoint_sha256_v2_28(result::WannierizationResult)
    buffer = IOBuffer()
    write(buffer, _wannierization_checkpoint_sha256_v2_27(result), '\n')
    for (key, default_value) in (
        ("target_leakage_semantics", "MISSING"),
        ("target_leakage_formula_sha256", "MISSING"),
        ("target_leakage_threshold", "MISSING"),
    )
        write(buffer, key, '=', get(result.input_summary, key, default_value), '\n')
    end
    write(buffer, "checkpoint_schema_version=2.28\n")
    return bytes2hex(SHA.sha256(take!(buffer)))
end

function _wannierization_checkpoint_sha256_v1_1(result::WannierizationResult)
    buffer = IOBuffer()
    write(buffer, _wannierization_checkpoint_sha256_v2_28(result), '\n')
    write(buffer, "checkpoint_schema_version=1.1\n")
    if haskey(result.input_summary, "construction_policy_contract")
        for key in ("construction_policy_contract", "construction_policy", "quality_review_status")
            write(buffer, key, '\0', get(result.input_summary, key, "NOT_RECORDED"), '\n')
        end
        # Bind the original check outcome and continuation action, including all
        # context fields, so readback cannot silently erase a failed quality gate.
        for diagnostic in result.diagnostics
            write(buffer, repr((diagnostic.code, diagnostic.severity, diagnostic.message)), '\n')
            for key in sort!(collect(keys(diagnostic.context)))
                write(buffer, repr((key, diagnostic.context[key])), '\n')
            end
        end
    end
    return bytes2hex(SHA.sha256(take!(buffer)))
end

function _wannierization_checkpoint_sha256_v2_29(result::WannierizationResult)
    buffer = IOBuffer()
    write(buffer, _wannierization_checkpoint_sha256_v2_28(result), '\n')
    write(buffer, "checkpoint_schema_version=1.2\n")
    # Bind the persisted typed block through its single canonical serializer so
    # the digest, the summary dictionary, and the HDF5 attributes agree.  The
    # reconstructed block only supplies a default for a key the summary lacks.
    defaults = nothing
    for key in WANNIERIZATION_ELIGIBILITY_SUMMARY_KEYS
        if haskey(result.input_summary, key)
            write(buffer, key, '=', result.input_summary[key], '\n')
        else
            defaults === nothing &&
                (defaults = _wannierization_eligibility_defaults(result.input_summary))
            write(buffer, key, '=', defaults[key], '\n')
        end
    end
    if haskey(result.input_summary, "construction_policy_contract")
        for key in ("construction_policy_contract", "construction_policy", "quality_review_status")
            write(buffer, key, '\0', get(result.input_summary, key, "NOT_RECORDED"), '\n')
        end
        # Bind the original check outcome and continuation action, including all
        # context fields, so readback cannot silently erase a failed quality gate.
        for diagnostic in result.diagnostics
            write(buffer, repr((diagnostic.code, diagnostic.severity, diagnostic.message)), '\n')
            for key in sort!(collect(keys(diagnostic.context)))
                write(buffer, repr((key, diagnostic.context[key])), '\n')
            end
        end
    end
    return bytes2hex(SHA.sha256(take!(buffer)))
end
function _wannierization_eligibility_defaults(summary)
    try
        return wannierization_eligibility_summary(wannierization_eligibility_from_summary(summary))
    catch
        return wannierization_eligibility_summary(not_evaluated_wannierization_eligibility())
    end
end
end
