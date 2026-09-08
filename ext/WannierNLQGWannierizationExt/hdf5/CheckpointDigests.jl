# Record the language-neutral axis contract on every multidimensional dataset.
function _write_axis_order(dataset, axis_order::AbstractString)
    HDF5.attributes(dataset)["axis_order"] = String(axis_order)
    return dataset
end

# Reject contradictory v1.1 axis metadata before interpreting scientific arrays.
function _require_axis_order(dataset, expected::AbstractString)
    actual = String(required_attribute(dataset, "axis_order"))
    actual == expected ||
        throw(ArgumentError("HDF5 axis_order $(actual) disagrees with required $(expected)"))
    return nothing
end

# Validate the schema-1.17/2.28 target-subspace authority and leakage-weight policy.
function _validate_persisted_target_subspace_contract(
    summary::AbstractDict;
    require_mask_digests::Bool = true,
)
    authority =
        validate_persisted_authority_key(get(summary, "authoritative_hamiltonian", "native_dft"))
    get(summary, "qualification_scope", "") == "target_subspace" || throw(
        ArgumentError(
            "TARGET_SUBSPACE_CONTRACT_MISMATCH: qualification_scope must be target_subspace",
        ),
    )
    get(summary, "target_authority", "") == "outer_window" || throw(
        ArgumentError("TARGET_SUBSPACE_CONTRACT_MISMATCH: target_authority must be outer_window"),
    )
    get(summary, "parent_audit_policy", "") == "audit_only" || throw(
        ArgumentError("TARGET_SUBSPACE_CONTRACT_MISMATCH: parent_audit_policy must be audit_only"),
    )
    if require_mask_digests
        for key in ("disentanglement_outer_mask_sha256", "disentanglement_frozen_mask_sha256")
            digest = get(summary, key, "")
            occursin(r"^[0-9a-f]{64}$", digest) || throw(
                ArgumentError("TARGET_SUBSPACE_CONTRACT_MISMATCH: $(key) is not a SHA-256 digest"),
            )
        end
    end
    contract_sha256 = get(summary, "target_subspace_contract_sha256", "")
    occursin(r"^[0-9a-f]{64}$", contract_sha256) || throw(
        ArgumentError(
            "TARGET_SUBSPACE_CONTRACT_MISMATCH: target_subspace_contract_sha256 is invalid",
        ),
    )
    get(summary, "target_leakage_semantics", "") == TARGET_LEAKAGE_WEIGHT_SEMANTICS || throw(
        ArgumentError(
            "UNSUPPORTED_LEGACY_TARGET_LEAKAGE_SEMANTICS: target summary lacks PAW-S weight semantics",
        ),
    )
    get(summary, "target_leakage_formula_sha256", "") == TARGET_LEAKAGE_WEIGHT_FORMULA_SHA256 ||
        throw(
            ArgumentError(
                "TARGET_SUBSPACE_CONTRACT_MISMATCH: target leakage formula digest differs",
            ),
        )
    threshold = tryparse(Float64, get(summary, "target_leakage_threshold", ""))
    threshold !== nothing && isfinite(something(threshold)) && something(threshold) > 0.0 || throw(
        ArgumentError(
            "TARGET_SUBSPACE_CONTRACT_MISMATCH: target leakage weight threshold is invalid",
        ),
    )
    authority == "symmetrized_dft_hamiltonian" &&
        get(summary, "auxiliary_parent_qualification", "") != "audit_only" &&
        throw(
            ArgumentError(
                "TARGET_SUBSPACE_CONTRACT_MISMATCH: symmetrized authority requires audit-only auxiliary parent",
            ),
        )
    return authority
end

# Map one serialized status name back to the closed enum.
function _wannierization_status(name::AbstractString)
    statuses = Dict(
        "IN_PROGRESS_CHECKPOINT" => IN_PROGRESS_CHECKPOINT,
        "COMPLETED" => COMPLETED,
        "COMPLETED_WITH_WARNINGS" => COMPLETED_WITH_WARNINGS,
        "MAX_ITERATIONS" => MAX_ITERATIONS,
        "REPRESENTATION_INCOMPATIBLE" => REPRESENTATION_INCOMPATIBLE,
        "REPRESENTATION_VALIDATION_UNDETERMINED" => REPRESENTATION_VALIDATION_UNDETERMINED,
        "SINGULAR_LOCALIZATION" => SINGULAR_LOCALIZATION,
        "LOCALIZATION_FAILED" => LOCALIZATION_FAILED,
        "INVALID_INPUT" => INVALID_INPUT,
        "IO_FAILURE" => IO_FAILURE,
    )
    haskey(statuses, String(name)) || throw(ArgumentError("unknown WannierizationStatus $(name)"))
    return statuses[String(name)]
end

# Return the stable stopping reason stored independently of the typed status.
function _checkpoint_stopping_reason(result::WannierizationResult)
    haskey(result.input_summary, "stopping_reason") &&
        return result.input_summary["stopping_reason"]
    isempty(result.diagnostics) && return string(result.status)
    return String(last(result.diagnostics).code)
end

# Hash the stable scientific checkpoint state without self-referential file metadata.
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

# Extend the legacy scientific digest with full-3D and optimizer continuation state.
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
        write(buffer, state.projection_basis_sha256, '\n', state.amn_sha256, '\n')
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

# Historical schema-1.3 digest retained only for read verification of legacy checkpoints.
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

# Bind schema-2.1 terminal counters and hard-gate evidence to the scientific state.
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

# Bind schema-2.2 initialization evidence, orthogonal outcome axes, and the
# additional localization-step history to the scientific state.
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

# Bind the separated two-stage objective and line-search histories.
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

# Bind the immutable two-stage S/P boundary and the retraction-consistent
# directional-derivative/projector-drift evidence.
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

# Schema 2.5 binds the exact final exported-TB qualification payload.
function _wannierization_checkpoint_sha256_v2_5(result::WannierizationResult)
    buffer = IOBuffer()
    write(buffer, _wannierization_checkpoint_sha256_v2_4(result), '\n')
    write(buffer, result.tb_symmetry_qualification.payload_sha256)
    return bytes2hex(SHA.sha256(take!(buffer)))
end

# Schema 2.6 binds accepted CG transport state and typed optimizer diagnostics.
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

# Schema 2.7 binds the MV localization-gradient phase convention explicitly.
function _wannierization_checkpoint_sha256_v2_7(result::WannierizationResult)
    buffer = IOBuffer()
    write(buffer, _wannierization_checkpoint_sha256_v2_6(result), '\n')
    write(buffer, get(result.input_summary, "localization_gradient_contract", "NOT_RECORDED"), '\n')
    return bytes2hex(SHA.sha256(take!(buffer)))
end

# Schema 2.8 binds the qualified-Z seal and the transactional Type-IV joint
# update evidence. Older checkpoints remain readable but cannot acquire these
# qualifications by interpretation alone.
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

# Schema 2.9 binds the effective operation subgroup and its parent
# representation. Local Z/link metrics are diagnostic observations rather than
# convergence gates, but are sealed whenever present.
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

# Schema 2.10 binds the centered-residual phase chart, active Type-IV branch
# orbit, generalized gradient, and accepted RCG/L-BFGS continuation state.
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

# Schema 2.11 binds the selected band-sewing backend and strict PAW diagnostics.
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

# Schema 2.12 additionally binds the wavefunction-gauge backend and capsule identity.
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

# Schema 2.14 additionally binds the Hamiltonian-weighted PAW block and audit identity.
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

# Schema 2.16 binds the Hamiltonian authority and its independent qualification.
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

# Schema 2.17 additionally binds the nonblocking symmetrized energy-shift audit contract.
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

# Schema 2.18 additionally binds the residual-gate phase and raw diagnostic status.
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

# Schema 2.19 additionally binds the nonblocking native-difference audit contract.
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

# Schema 2.20 binds the target-subspace authority and auxiliary-parent audit contract.
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

# Schema 2.21 binds the decoupled Z/U state machine and all numerical contracts
# that replaced the former overloaded representation tolerance.
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

# Schema 2.22 binds algorithm-profile resolution and the immutable W90-4.0.1
# protocol identity. Legacy-FR checkpoints remain readable but cannot satisfy
# this continuation contract.
function _wannierization_checkpoint_sha256_v2_22(result::WannierizationResult)
    buffer = IOBuffer()
    write(buffer, _wannierization_checkpoint_sha256_v2_21(result), '\n')
    for (key, default_value) in (
        ("algorithm_profile", "legacy"),
        ("effective_algorithm_profile", "legacy"),
        ("disentanglement_algorithm_requested", "legacy"),
        ("localization_algorithm_requested", "legacy"),
        ("wannier90_reference_protocol", "NOT_APPLICABLE"),
    )
        write(buffer, key, '=', get(result.input_summary, key, default_value), '\n')
    end
    if result.restart_state !== nothing
        optimizer = something(result.restart_state).optimizer_state
        for values in
            (optimizer.wannier90_reference_overlaps, optimizer.wannier90_reference_unitaries)
            write(buffer, reinterpret(UInt8, Int64[ndims(values), size(values)...]))
            write(buffer, reinterpret(UInt8, vec(values)))
        end
        write(buffer, reinterpret(UInt8, [optimizer.wannier90_reference_omega_i]))
    end
    return bytes2hex(SHA.sha256(take!(buffer)))
end

# Schema 2.23 introduced a digest-bound frozen numerical-parity qualification.
# Schema 2.24 retains those fields while removing observer-state injection and
# binding the v2 algorithm contract.
function _wannierization_checkpoint_sha256_v2_23(result::WannierizationResult)
    buffer = IOBuffer()
    write(buffer, _wannierization_checkpoint_sha256_v2_22(result), '\n')
    for (key, default_value) in (
        ("wannier90_reference_algorithm_contract_version", "legacy"),
        ("wannier90_reference_parity_standard_version", "legacy"),
        ("wannier90_reference_parity_semantic", "legacy"),
        ("wannier90_reference_accepted_step_combination_rule", "NOT_APPLICABLE"),
        ("wannier90_reference_accepted_step_absolute_tolerance", "NOT_APPLICABLE"),
        ("wannier90_reference_accepted_step_relative_tolerance", "NOT_APPLICABLE"),
        ("wannier90_reference_parity_contract_sha256", "NOT_APPLICABLE"),
        ("wannier90_reference_default_qualification_status", "NOT_QUALIFIED"),
        ("wannier90_reference_default_qualification_manifest_sha256", "NOT_AVAILABLE"),
    )
        write(buffer, key, '=', get(result.input_summary, key, default_value), '\n')
    end
    return bytes2hex(SHA.sha256(take!(buffer)))
end

# Schema 2.24 removes every observer-state injection path and binds the v2
# pure-Julia algorithm contract. Schema 2.23 stays readable but is not restartable.
function _wannierization_checkpoint_sha256_v2_24(result::WannierizationResult)
    buffer = IOBuffer()
    write(buffer, _wannierization_checkpoint_sha256_v2_23(result), '\n')
    write(buffer, "checkpoint_schema_version=2.24\n")
    return bytes2hex(SHA.sha256(take!(buffer)))
end

# Schema 2.25 removes the public symmetry_mode axis and binds the unified mode,
# inferred representation source, and renamed SMV/FR two-stage algorithm.
function _wannierization_checkpoint_sha256_v2_25(result::WannierizationResult)
    buffer = IOBuffer()
    write(buffer, _wannierization_checkpoint_sha256_v2_24(result), '\n')
    for (key, default_value) in (
        ("requested_wannierization_mode", "MISSING"),
        ("effective_wannierization_mode", "MISSING"),
        ("representation_source", "MISSING"),
        ("symmetry_constraints_applied", "MISSING"),
        ("effective_algorithm_profile", "MISSING"),
        ("wannier90_reference_algorithm_contract_version", "MISSING"),
    )
        write(buffer, key, '=', get(result.input_summary, key, default_value), '\n')
    end
    write(buffer, "checkpoint_schema_version=2.25\n")
    return bytes2hex(SHA.sha256(take!(buffer)))
end

# Schema 2.26 makes ordinary `:auto` select the mathematical SMV--FR two-stage
# profile unconditionally. Optional oracle-audit metadata is deliberately not
# part of this scientific restart digest.
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

# Schema 2.27 binds the outer-window authority, parent audit policy, and target masks.
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

# Schema 2.28 binds the target leakage-weight semantics, formula, and threshold.
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

# Public 1.0 seals the unchanged complete 2.28 state with its own wire identity.
function _wannierization_checkpoint_sha256_v1_0(result::WannierizationResult)
    buffer = IOBuffer()
    write(buffer, _wannierization_checkpoint_sha256_v2_28(result), '\n')
    write(buffer, "checkpoint_schema_version=1.0\n")
    if haskey(result.input_summary, "construction_policy_contract")
        for key in ("construction_policy_contract", "construction_policy", "manual_review_status")
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

# Reject non-finite numerical states before downstream TB publication.
function _wannierization_result_is_finite(result::WannierizationResult)
    return all(isfinite, result.v_matrix) &&
           all(isfinite, result.wannier_centers_cartesian) &&
           all(isfinite, result.spreads_angstrom2) &&
           all(
               entry -> all(
                   isfinite,
                   (
                       entry.spread_total,
                       entry.spread_standard_deviation,
                       entry.maximum_covariance_error,
                   ),
               ),
               result.history,
           )
end

# Production eligibility is intentionally limited to the production solver
# contract and the downstream band gate. Response calculations are outside the
# band-representation/SAWF qualification scope.
function _wannierization_production_eligible(result::WannierizationResult)
    packed = result.artifacts.packed_hdf5
    representation_status = get(result.input_summary, "representation_compatible", "false")
    return get(result.input_summary, "construction_policy", "strict") == "strict" &&
           result.status in (COMPLETED, COMPLETED_WITH_WARNINGS) &&
           get(result.input_summary, "controlled_symmetrization_diagnostic_only", "false") !=
           "true" &&
           get(result.input_summary, "controlled_symmetrization_production_eligible", "true") ==
           "true" &&
           get(result.input_summary, "optimizer_schedule", "") in ("two_stage", "joint") &&
           get(result.input_summary, "u_acceptance", "") == "armijo" &&
           get(result.input_summary, "z_seal_class", "") == "CONVERGED" &&
           get(result.input_summary, "qualified_z_seal", "false") == "true" &&
           get(result.input_summary, "standard_tb_export_eligible", "false") == "true" &&
           representation_status in ("true", "NOT_APPLICABLE") &&
           get(result.input_summary, "physics_qualification", "") == "QUALIFIED" &&
           get(result.input_summary, "band_validation_pass", "false") == "true" &&
           result.tb_symmetry_qualification.overall == "PASS" &&
           _wannierization_result_is_finite(result) &&
           all(diagnostic -> diagnostic.severity != :error, result.diagnostics) &&
           packed !== nothing &&
           isfile(packed)
end

# This flag is deliberately scoped to the selected finite-parent Hamiltonian.
# No SAWF artifact from this workflow can erase a native-DFT fidelity HOLD.
function _wannierization_scoped_production_eligible(result::WannierizationResult)
    authority = validate_persisted_authority_key(
        get(result.input_summary, "authoritative_hamiltonian", "native_dft"),
    )
    authority == "symmetrized_dft_hamiltonian" || return _wannierization_production_eligible(result)
    return (
        _wannierization_production_eligible(result) &&
        get(result.input_summary, "target_scope_production_eligible", "false") == "true" &&
        get(result.input_summary, "symmetrized_dft_hamiltonian_status", "") ==
        "SYMMETRIZED_DFT_HAMILTONIAN_PASS"
    )
end

# Materialize the persisted counter before hashing and atomically writing a checkpoint.
function _checkpoint_persisted_result(result::WannierizationResult)
    summary = Dict{String, String}(result.input_summary)
    summary["construction_policy"] = get(summary, "construction_policy", "strict")
    summary["construction_policy"] in ("strict", "diagnostic") ||
        throw(ArgumentError("CONSTRUCTION_POLICY_INVALID: unsupported persisted policy"))
    summary["construction_policy_contract"] = "diagnostic_construction_v1"
    summary["manual_review_status"] = get(
        summary,
        "manual_review_status",
        summary["construction_policy"] == "diagnostic" ? "REQUIRED" : "NOT_REQUESTED",
    )
    summary["algorithm_profile"] = get(summary, "algorithm_profile", "legacy")
    summary["effective_algorithm_profile"] = get(summary, "effective_algorithm_profile", "legacy")
    summary["smv_fletcher_reeves_two_stage_algorithm_contract_version"] = get(
        summary,
        "smv_fletcher_reeves_two_stage_algorithm_contract_version",
        summary["effective_algorithm_profile"] == "smv_fletcher_reeves_two_stage" ?
        SMV_FLETCHER_REEVES_TWO_STAGE_ALGORITHM_CONTRACT_VERSION : "NOT_APPLICABLE",
    )
    summary["smv_fletcher_reeves_two_stage_default_selection_reason"] = get(
        summary,
        "smv_fletcher_reeves_two_stage_default_selection_reason",
        get(summary, "algorithm_profile", "legacy") == "auto" &&
        get(summary, "effective_wannierization_mode", "") == "ordinary" ?
        "UNCONDITIONAL_ORDINARY_DEFAULT" : "NOT_APPLICABLE",
    )
    summary["smv_fletcher_reeves_two_stage_protocol"] =
        get(summary, "smv_fletcher_reeves_two_stage_protocol", "NOT_APPLICABLE")
    summary["localization_gradient_contract"] = LOCALIZATION_GRADIENT_CONTRACT
    summary["joint_update_contract"] = JOINT_UPDATE_CONTRACT
    summary["disentanglement_limit_policy"] =
        get(summary, "disentanglement_limit_policy", "diagnostic_continue")
    summary["z_seal_class"] = get(summary, "z_seal_class", "NOT_APPLICABLE")
    summary["qualified_z_seal"] = get(summary, "qualified_z_seal", "false")
    summary["route_selection_eligible"] = get(summary, "route_selection_eligible", "false")
    summary["standard_tb_export_eligible"] = get(summary, "standard_tb_export_eligible", "false")
    summary["authoritative_hamiltonian"] = get(summary, "authoritative_hamiltonian", "native_dft")
    summary["authoritative_hamiltonian_sha256"] =
        get(summary, "authoritative_hamiltonian_sha256", "LEGACY_NATIVE_DFT")
    summary["qualification_scope"] = get(summary, "qualification_scope", "full_parent")
    summary["parent_audit_policy"] = get(summary, "parent_audit_policy", "legacy_hard_gate")
    summary["target_authority"] = get(summary, "target_authority", "NOT_APPLICABLE")
    summary["disentanglement_outer_mask_sha256"] =
        get(summary, "disentanglement_outer_mask_sha256", "NOT_SEALED")
    summary["disentanglement_frozen_mask_sha256"] =
        get(summary, "disentanglement_frozen_mask_sha256", "NOT_SEALED")
    summary["target_subspace_contract_sha256"] =
        get(summary, "target_subspace_contract_sha256", "NOT_RECORDED")
    if summary["qualification_scope"] != "target_subspace"
        summary["target_leakage_semantics"] =
            get(summary, "target_leakage_semantics", "NOT_APPLICABLE")
        summary["target_leakage_formula_sha256"] =
            get(summary, "target_leakage_formula_sha256", "NOT_RECORDED")
        summary["target_leakage_threshold"] =
            get(summary, "target_leakage_threshold", "NOT_APPLICABLE")
    end
    summary["constraint_operation_scope"] = get(summary, "constraint_operation_scope", "full")
    summary["constraint_operation_scope_history_reset"] = get(
        summary,
        "constraint_operation_scope_history_reset",
        summary["constraint_operation_scope"] == "full" ? "NOT_APPLICABLE" :
        "LEGACY_CONSTRAINT_SCOPE_RESET",
    )
    summary["constraint_operation_parent_representation_sha256"] = get(
        summary,
        "constraint_operation_parent_representation_sha256",
        get(summary, "representation_sha256", ""),
    )
    summary["constraint_operation_subgroup_sha256"] = get(
        summary,
        "constraint_operation_subgroup_sha256",
        get(summary, "representation_sha256", ""),
    )
    summary["constraint_operation_parent_indices"] =
        get(summary, "constraint_operation_parent_indices", "NOT_RECORDED")
    summary["symmetry_ablation_classification"] = get(
        summary,
        "symmetry_ablation_classification",
        summary["constraint_operation_scope"] == "full" ? "NOT_APPLICABLE" :
        "DIAGNOSTIC_SYMMETRY_ABLATION",
    )
    accepted = result.restart_state === nothing ? -1 : result.restart_state.iteration
    summary["last_accepted_iteration"] = get(summary, "last_accepted_iteration", string(accepted))
    summary["last_persisted_iteration"] = string(accepted)
    summary["last_attempted_iteration"] =
        get(summary, "last_attempted_iteration", summary["last_accepted_iteration"])
    summary["has_accepted_state"] = string(accepted >= 0)
    summary["legacy_terminal_semantics"] = get(summary, "legacy_terminal_semantics", "false")
    summary["solver_status"] = get(summary, "solver_status", string(result.status))
    summary["stopping_reason"] =
        get(summary, "stopping_reason", _checkpoint_stopping_reason(result))
    summary["convergence_metric_name"] =
        get(summary, "convergence_metric_name", "center_spread_window_std_max")
    summary["convergence_metric"] = get(
        summary,
        "convergence_metric",
        isempty(result.history) ? "Inf" : string(last(result.history).spread_standard_deviation),
    )
    restart = result.restart_state
    v_matrix = restart === nothing ? result.v_matrix : restart.frames
    centers = restart === nothing ? result.wannier_centers_cartesian : restart.centers_cartesian
    spreads = restart === nothing ? result.spreads_angstrom2 : restart.spreads_angstrom2
    chk = if restart === nothing || result.wannier_chk === nothing
        result.wannier_chk
    else
        source = something(result.wannier_chk)
        WannierCHK(
            size(v_matrix, 1),
            size(v_matrix, 2),
            size(v_matrix, 3),
            source.mp_grid,
            source.kpt_red,
            source.real_lattice,
            source.recip_lattice,
            centers,
            v_matrix,
        )
    end
    return WannierizationResult(
        result.status,
        v_matrix,
        centers,
        spreads,
        result.history,
        result.diagnostics,
        summary,
        chk,
        result.checkpoint_file,
        result.restart_state,
        result.artifacts,
        result.initialization_report,
        result.tb_symmetry_qualification,
    )
end
