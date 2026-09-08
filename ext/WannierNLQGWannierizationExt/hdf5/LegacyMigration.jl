# Preserve the accepted physical state from a legacy checkpoint while removing
# every optimizer quantity that depends on the pre-2.7 MV phase convention.
function _reset_legacy_localization_gradient_history(
    result::WannierizationResult,
    source_schema::AbstractString,
)
    result.restart_state === nothing && return result
    state = something(result.restart_state)
    legacy = state.optimizer_state
    optimizer = WannierizationOptimizerState(
        legacy.strategy,
        legacy.z_mix_ratio,
        legacy.u_mix_ratio,
        legacy.improvement_streak,
        legacy.rejected_steps,
        legacy.residual_reference,
        legacy.previous_merit,
        legacy.anderson_z_history,
        legacy.anderson_residual_history,
        legacy.phase,
        legacy.z_stability_count,
        0,
        legacy.z_steps,
        legacy.u_steps,
        legacy.epoch,
        1.0,
        false,
        0,
        copy(state.frames),
        copy(state.centers_cartesian),
        copy(state.spreads_angstrom2),
        sum(state.spreads_angstrom2),
        legacy.disentanglement_objective_history,
        legacy.localization_objective_history,
        legacy.localization_trial_step_scales,
        legacy.localization_trial_objectives,
        legacy.localization_trial_required_changes,
        legacy.localization_trial_actual_changes,
        legacy.localization_trial_directional_derivatives,
        legacy.localization_projector_drift_history,
        legacy.localization_trial_iterations,
        legacy.localization_trial_sweeps,
        legacy.localization_trial_accepted,
        zeros(ComplexF64, 0, 0, 0),
        zeros(ComplexF64, 0, 0, 0),
        0,
        0,
        NaN,
        :LEGACY_U_PHASE_CHART_RESET,
        legacy.last_anderson_reason,
        LOCALIZATION_GRADIENT_CONTRACT,
        "",
        0,
        NaN,
        zeros(ComplexF64, 0, 0, 0, 0),
        zeros(ComplexF64, 0, 0, 0, 0),
        Float64[],
        0,
        :LEGACY_U_PHASE_CHART_RESET,
    )
    restart_state = WannierizationRestartState(
        state.iteration,
        state.frames,
        state.z_previous,
        state.centers_cartesian,
        state.spreads_angstrom2,
        state.convergence_values,
        state.included_bands,
        state.elapsed_seconds,
        state.config_sha256,
        state.representation_sha256,
        state.stencil,
        state.projection_basis_sha256,
        state.amn_sha256,
        optimizer,
        state.fixed_subspace_projectors,
        state.fixed_subspace_frames,
        state.localization_initial_frames,
    )
    summary = Dict{String, String}(result.input_summary)
    summary["checkpoint_localization_gradient_contract"] = "LEGACY_PRE_V2_7_UNSPECIFIED"
    summary["localization_gradient_contract"] = LOCALIZATION_GRADIENT_CONTRACT
    summary["optimizer_history_compatibility"] = "LEGACY_U_PHASE_CHART_RESET"
    summary["restart_continuation_semantics"] = "STATE_PRESERVED_OPTIMIZER_HISTORY_RESET_NOT_BITWISE"
    diagnostics = WannierizationDiagnostic[result.diagnostics...]
    push!(
        diagnostics,
        WannierizationDiagnostic(
            :LEGACY_U_PHASE_CHART_RESET,
            :info,
            "legacy checkpoint accepted state retained; U gradient, search direction, RCG/L-BFGS history, and phase-chart state were reset";
            context = Dict(
                "source_schema" => String(source_schema),
                "resume_policy" => "PROJECTED_STEEPEST_DESCENT",
                "strict_continuation" => "false",
            ),
        ),
    )
    return WannierizationResult(
        result.status,
        result.v_matrix,
        result.wannier_centers_cartesian,
        result.spreads_angstrom2,
        result.history,
        diagnostics,
        summary,
        result.wannier_chk,
        result.checkpoint_file,
        restart_state,
        result.artifacts,
        result.initialization_report,
        result.tb_symmetry_qualification,
    )
end

# Schema 2.7 predates the transactional joint update and explicit Z-seal
# classification. Preserve accepted physical arrays, but never carry a moving-
# subspace optimizer history across the contract boundary or promote a
# diagnostic two-stage boundary into a qualified seal.
function _reset_legacy_joint_update_history(result::WannierizationResult)
    summary = Dict{String, String}(result.input_summary)
    diagnostics = WannierizationDiagnostic[result.diagnostics...]
    schedule = get(summary, "optimizer_schedule", "")
    restart_state = result.restart_state
    if schedule == "joint" && restart_state !== nothing
        state = something(restart_state)
        legacy = state.optimizer_state
        optimizer = WannierizationOptimizerState(
            legacy.strategy,
            legacy.z_mix_ratio,
            legacy.u_mix_ratio,
            0,
            legacy.rejected_steps,
            (NaN, NaN, NaN, NaN),
            NaN,
            zeros(Float64, 0, 0),
            zeros(Float64, 0, 0),
            legacy.phase,
            0,
            0,
            legacy.z_steps,
            legacy.u_steps,
            legacy.epoch,
            1.0,
            false,
            0,
            copy(state.frames),
            copy(state.centers_cartesian),
            copy(state.spreads_angstrom2),
            sum(state.spreads_angstrom2),
            legacy.disentanglement_objective_history,
            legacy.localization_objective_history,
            legacy.localization_trial_step_scales,
            legacy.localization_trial_objectives,
            legacy.localization_trial_required_changes,
            legacy.localization_trial_actual_changes,
            legacy.localization_trial_directional_derivatives,
            legacy.localization_projector_drift_history,
            legacy.localization_trial_iterations,
            legacy.localization_trial_sweeps,
            legacy.localization_trial_accepted,
            zeros(ComplexF64, 0, 0, 0),
            zeros(ComplexF64, 0, 0, 0),
            0,
            0,
            NaN,
            :LEGACY_JOINT_UPDATE_CONTRACT_RESET,
            :LEGACY_JOINT_UPDATE_CONTRACT_RESET,
            LOCALIZATION_GRADIENT_CONTRACT,
            "",
            0,
            NaN,
            zeros(ComplexF64, 0, 0, 0, 0),
            zeros(ComplexF64, 0, 0, 0, 0),
            Float64[],
            0,
            :LEGACY_JOINT_UPDATE_CONTRACT_RESET,
        )
        restart_state = WannierizationRestartState(
            state.iteration,
            state.frames,
            state.z_previous,
            state.centers_cartesian,
            state.spreads_angstrom2,
            state.convergence_values,
            state.included_bands,
            state.elapsed_seconds,
            state.config_sha256,
            state.representation_sha256,
            state.stencil,
            state.projection_basis_sha256,
            state.amn_sha256,
            optimizer,
            state.fixed_subspace_projectors,
            state.fixed_subspace_frames,
            state.localization_initial_frames,
        )
        summary["optimizer_history_compatibility"] = "LEGACY_JOINT_UPDATE_CONTRACT_RESET"
        summary["restart_continuation_semantics"] = "STATE_PRESERVED_JOINT_HISTORY_RESET_NOT_BITWISE"
        summary["disentanglement_convergence"] = "IN_PROGRESS"
        summary["z_seal_class"] = "IN_PROGRESS"
        summary["qualified_z_seal"] = "false"
        summary["route_selection_eligible"] = "false"
        summary["standard_tb_export_eligible"] = "false"
        push!(
            diagnostics,
            WannierizationDiagnostic(
                :LEGACY_JOINT_UPDATE_CONTRACT_RESET,
                :info,
                "schema-2.7 accepted state retained; Anderson, joint convergence, and CG histories were reset for the transactional Type-IV update contract";
                context = Dict("source_schema" => "2.7", "strict_continuation" => "false"),
            ),
        )
    else
        legacy_z_converged = get(summary, "disentanglement_convergence", "") == "CONVERGED"
        summary["z_seal_class"] = legacy_z_converged ? "CONVERGED" : "DIAGNOSTIC_NONCONVERGED"
        summary["qualified_z_seal"] = string(legacy_z_converged)
        summary["route_selection_eligible"] = string(legacy_z_converged)
        summary["standard_tb_export_eligible"] = "false"
        legacy_z_converged || push!(
            diagnostics,
            WannierizationDiagnostic(
                :LEGACY_DIAGNOSTIC_Z_SEAL_NOT_PROMOTED,
                :info,
                "schema-2.7 diagnostic two-stage boundary remains nonqualified under schema 2.8";
                context = Dict("source_schema" => "2.7"),
            ),
        )
    end
    summary["joint_update_contract"] = JOINT_UPDATE_CONTRACT
    summary["checkpoint_joint_update_contract"] = "LEGACY_PRE_V2_8_UNSPECIFIED"
    return WannierizationResult(
        result.status,
        result.v_matrix,
        result.wannier_centers_cartesian,
        result.spreads_angstrom2,
        result.history,
        diagnostics,
        summary,
        result.wannier_chk,
        result.checkpoint_file,
        restart_state,
        result.artifacts,
        result.initialization_report,
        result.tb_symmetry_qualification,
    )
end
