# Assemble the retained terminal state after a stage limit or exhausted iteration budget.
function _assemble_solver_terminal_result(state::NamedTuple)
    (;
        apply_symmetry,
        centers,
        compatibility,
        config,
        diagnostic_disentanglement_nonconverged,
        diagnostics,
        effective_compatibility_policy,
        fixed_stationary,
        frames,
        frozen_indices,
        full_constraint_scope,
        history,
        initialization_report,
        input_summary,
        latest_restart_state,
        nb,
        nk,
        num_wannier,
        plan,
        projector_covariance_tolerance,
        representation,
        spreads,
        u_steps,
        z_previous,
        z_stability_count,
        z_steps,
    ) = state
    fixed_stationary || push!(
        diagnostics,
        WannierizationDiagnostic(
            :MAX_ITERATIONS_REACHED,
            :warning,
            apply_symmetry ?
            "SAWF iteration reached max_iterations without the requested convergence criterion" :
            "ordinary full-BZ Wannierization reached max_iterations without convergence";
            context = Dict("max_iterations" => string(config.solver.max_iterations)),
        ),
    )
    if config.solver.acceleration.schedule == :joint &&
       z_stability_count < config.solver.acceleration.z_stability_window
        input_summary["disentanglement_convergence"] = "DIAGNOSTIC_NONCONVERGED"
        input_summary["z_seal_class"] = "DIAGNOSTIC_NONCONVERGED"
        input_summary["qualified_z_seal"] = "false"
        input_summary["route_selection_eligible"] = "false"
        input_summary["standard_tb_export_eligible"] = "false"
        push!(
            diagnostics,
            WannierizationDiagnostic(
                :JOINT_Z_NONCONVERGED_DIAGNOSTIC,
                :warning,
                "joint iteration retained a structurally valid diagnostic state without a qualified Z seal";
                context = Dict(
                    "z_steps" => string(z_steps),
                    "z_stability_count" => string(z_stability_count),
                    "required_stability_count" =>
                        string(config.solver.acceleration.z_stability_window),
                ),
            ),
        )
    elseif config.solver.acceleration.schedule == :joint
        input_summary["disentanglement_convergence"] = "CONVERGED"
        input_summary["z_seal_class"] = "CONVERGED"
        input_summary["qualified_z_seal"] = "true"
        input_summary["route_selection_eligible"] = string(full_constraint_scope)
    end
    final_projector_diagnostic =
        apply_symmetry ?
        _selected_projector_compatibility_diagnostic(
            frames,
            representation,
            projector_covariance_tolerance,
            effective_compatibility_policy,
            "final",
            compatibility.product_table.theta_index,
        ) : nothing
    final_projector_diagnostic === nothing || push!(
        diagnostics,
        config.input.construction_policy == :diagnostic &&
            final_projector_diagnostic.code == :ANTIUNITARY_PROJECTOR_COVARIANCE_FAILED ?
        _construction_quality_diagnostic(final_projector_diagnostic, "final_projector") :
        final_projector_diagnostic,
    )
    input_summary["failure_class"] = final_projector_diagnostic === nothing ? "NUMERICAL_B" : "BOTH"
    terminal_residuals = _candidate_invariant_residuals(frames, frozen_indices, representation)
    terminal_residuals = merge(
        terminal_residuals,
        (
            target_symmetry = apply_symmetry ?
                              _maximum_target_frame_symmetry_error(frames, representation, plan) : NaN,
        ),
    )
    if diagnostic_disentanglement_nonconverged
        terminal_qualification = _qualify_nonconverged_disentanglement_state(
            frames,
            z_previous,
            centers,
            spreads,
            frozen_indices,
            representation,
            plan,
            config.input.representation_tolerance,
            projector_covariance_tolerance,
            apply_symmetry;
            construction_policy = config.input.construction_policy,
        )
        diagnostic_tb_ready =
            terminal_qualification.qualified &&
            (
                config.input.construction_policy == :diagnostic ||
                final_projector_diagnostic === nothing
            ) &&
            (config.input.construction_policy == :diagnostic || u_steps > 0)
        input_summary["localization_convergence"] =
            get(input_summary, "localization_convergence", "IN_PROGRESS") == "IN_PROGRESS" ?
            "MAX_ITERATIONS" : input_summary["localization_convergence"]
        input_summary["diagnostic_tb_export_eligible"] = string(diagnostic_tb_ready)
        push!(
            diagnostics,
            WannierizationDiagnostic(
                diagnostic_tb_ready ? :NONCONVERGED_DISENTANGLEMENT_DIAGNOSTIC_TB_READY :
                :NONCONVERGED_DISENTANGLEMENT_DIAGNOSTIC_TB_REJECTED,
                diagnostic_tb_ready ? :warning : :error,
                diagnostic_tb_ready ?
                "localization retained a finite invariant-valid terminal state after nonconverged disentanglement; diagnostic TB export is allowed" :
                "terminal localization state failed the diagnostic TB export gate";
                context = Dict(
                    "localization_steps" => string(u_steps),
                    "structural_gate_pass" => string(terminal_qualification.qualified),
                    "final_projector_gate_pass" => string(final_projector_diagnostic === nothing),
                ),
            ),
        )
    end
    _record_terminal_state!(
        input_summary,
        MAX_ITERATIONS,
        diagnostics,
        history,
        something(latest_restart_state).iteration,
        something(latest_restart_state).iteration;
        hard_gate_residuals = terminal_residuals,
    )
    v_matrix = cat(frames...; dims = 3)
    chk = WannierCHK(
        nb,
        num_wannier,
        nk,
        representation.mp_grid,
        representation.kpoints_fractional,
        representation.real_lattice,
        representation.reciprocal_lattice,
        centers,
        v_matrix,
    )
    return WannierizationResult(
        MAX_ITERATIONS,
        v_matrix,
        centers,
        spreads,
        history,
        diagnostics,
        input_summary,
        chk,
        nothing,
        latest_restart_state,
        WannierizationArtifacts(),
        initialization_report,
    )
end

# Decide whether the accepted state terminates or continues the explicit iteration loop.
function _finish_solver_iteration(state::NamedTuple)
    (;
        actual_u_mix_ratio,
        actual_z_mix_ratio,
        amn_sha256,
        anderson_residual_history,
        anderson_z_history,
        apply_symmetry,
        basis_sha256,
        best_polar_centers,
        best_polar_frames,
        best_polar_objective,
        best_polar_spreads,
        centers,
        compatibility,
        config,
        config_sha256,
        convergence_values,
        diagnostic_disentanglement_nonconverged,
        diagnostics,
        disentanglement_objective_history,
        effective_algorithms,
        effective_compatibility_policy,
        epoch,
        fixed_complete,
        fixed_mode,
        fixed_source_qualified,
        fixed_stability_count,
        fixed_stationary,
        fixed_stationary_count,
        frames,
        frozen_indices,
        full_constraint_scope,
        gradient_fallback_active,
        gradient_steps,
        grassmann_actual_decrease_history,
        grassmann_gradient_history,
        grassmann_predicted_decrease_history,
        grassmann_projector_change_history,
        grassmann_radius_history,
        grassmann_ratio_history,
        grassmann_trust_radius,
        history,
        improvement_streak,
        included_bands,
        initialization_report,
        input_summary,
        iteration,
        last_accepted_u_step_scale,
        last_anderson_reason,
        last_cg_beta,
        last_cg_restart_reason,
        last_u_optimizer_restart_reason,
        latest_restart_state,
        localization_initial_frames,
        localization_objective_history,
        localization_projector_drift_history,
        localization_reference_frames,
        localization_trial_accepted,
        localization_trial_actual_changes,
        localization_trial_directional_derivatives,
        localization_trial_iterations,
        localization_trial_objectives,
        localization_trial_required_changes,
        localization_trial_step_scales,
        localization_trial_sweeps,
        minimum_localization_diagonal_phase_margin,
        mmn,
        nb,
        nk,
        num_wannier,
        observer,
        optimizer_phase,
        outer_indices,
        phase_branch_backtracking_extension_count,
        plan,
        previous_merit,
        previous_u_direction,
        previous_u_gradient,
        prior_elapsed,
        projector_covariance_tolerance,
        rejected_steps,
        representation,
        residual_reference,
        result,
        sealed_subspace_frames,
        sealed_subspace_projectors,
        spectrum_audit,
        spreads,
        stage_stop_reason,
        start_iteration,
        started_ns,
        stencil,
        tangent_plans,
        total_spread_window_std,
        trajectory_previous_frames,
        trajectory_two_step_frames,
        two_stage_complete,
        u_active_orbit_count,
        u_branch_signature,
        u_cg_iteration,
        u_cg_restart_count,
        u_generalized_gradient_rms,
        u_lbfgs_restart_count,
        u_lbfgs_rho_history,
        u_lbfgs_s_history,
        u_lbfgs_y_history,
        u_stability_count,
        u_steps,
        wannier90_reference_omega_i,
        wannier90_reference_overlaps,
        wannier90_reference_unitaries,
        weights,
        z_previous,
        z_stability_count,
        z_steps,
    ) = state
    if fixed_stationary
        push!(
            diagnostics,
            WannierizationDiagnostic(
                :SYMMETRY_PROJECTED_STATIONARY,
                :warning,
                "projected gradient is stationary but the spread window has not converged";
                context = Dict(
                    "gradient_rms" => string(result.gradient_rms),
                    "u_residual" => string(result.u_residual),
                    "spread_window_standard_deviation" => string(total_spread_window_std),
                ),
            ),
        )
        return SolverIterationDecision(true, state)
    end
    stage_stop_reason === nothing || begin
        push!(
            diagnostics,
            WannierizationDiagnostic(
                something(stage_stop_reason),
                :warning,
                "solver stage reached its configured step limit";
                context = Dict(
                    "phase" => string(optimizer_phase),
                    "disentanglement_steps" => string(z_steps),
                    "localization_steps" => string(u_steps),
                ),
            ),
        )
        return SolverIterationDecision(true, state)
    end
    solver_converged =
        fixed_mode ? fixed_complete :
        config.solver.acceleration.schedule == :two_stage ? two_stage_complete :
        z_stability_count >= config.solver.acceleration.z_stability_window &&
        u_stability_count >= config.solver.convergence_window
    if solver_converged
        if fixed_mode
            input_summary["localization_convergence"] = "CONVERGED"
            input_summary["standard_tb_export_eligible"] =
                string(fixed_source_qualified && full_constraint_scope)
        end
        final_projector_diagnostic =
            apply_symmetry ?
            _selected_projector_compatibility_diagnostic(
                frames,
                representation,
                projector_covariance_tolerance,
                effective_compatibility_policy,
                "final",
                compatibility.product_table.theta_index,
            ) : nothing
        final_projector_diagnostic === nothing || push!(
            diagnostics,
            config.input.construction_policy == :diagnostic &&
                final_projector_diagnostic.code == :ANTIUNITARY_PROJECTOR_COVARIANCE_FAILED ?
            _construction_quality_diagnostic(final_projector_diagnostic, "final_projector") :
            final_projector_diagnostic,
        )
        if final_projector_diagnostic !== nothing && !(
            config.input.construction_policy == :diagnostic &&
            final_projector_diagnostic.code == :ANTIUNITARY_PROJECTOR_COVARIANCE_FAILED
        )
            return _failure_result(
                REPRESENTATION_INCOMPATIBLE,
                diagnostics,
                merge(input_summary, Dict("failure_class" => "REPRESENTATION_A"));
                frames,
                centers,
                spreads,
                history,
                restart_state = latest_restart_state,
                representation,
                last_attempted_iteration = iteration,
                hard_gate_residuals = _candidate_invariant_residuals(
                    frames,
                    frozen_indices,
                    representation,
                ),
                initialization_report,
            )
        end
        v_matrix = cat(frames...; dims = 3)
        chk = WannierCHK(
            nb,
            num_wannier,
            nk,
            representation.mp_grid,
            representation.kpoints_fractional,
            representation.real_lattice,
            representation.reciprocal_lattice,
            centers,
            v_matrix,
        )
        diagnostic_qualification =
            diagnostic_disentanglement_nonconverged ?
            _qualify_nonconverged_disentanglement_state(
                frames,
                z_previous,
                centers,
                spreads,
                frozen_indices,
                representation,
                plan,
                config.input.representation_tolerance,
                projector_covariance_tolerance,
                apply_symmetry;
                construction_policy = config.input.construction_policy,
            ) : nothing
        diagnostic_tb_ready =
            diagnostic_qualification !== nothing &&
            something(diagnostic_qualification).qualified &&
            (config.input.construction_policy == :diagnostic || u_steps > 0)
        if diagnostic_disentanglement_nonconverged
            input_summary["localization_convergence"] = "CONVERGED"
            input_summary["diagnostic_tb_export_eligible"] = string(diagnostic_tb_ready)
            input_summary["failure_class"] = "NUMERICAL_B"
            push!(
                diagnostics,
                WannierizationDiagnostic(
                    diagnostic_tb_ready ? :NONCONVERGED_DISENTANGLEMENT_DIAGNOSTIC_TB_READY :
                    :NONCONVERGED_DISENTANGLEMENT_DIAGNOSTIC_TB_REJECTED,
                    diagnostic_tb_ready ? :warning : :error,
                    diagnostic_tb_ready ?
                    "localization converged from a structurally qualified but nonconverged disentanglement projector; diagnostic TB export is allowed" :
                    "the nonconverged disentanglement trajectory did not retain an exportable diagnostic localization state";
                    context = Dict(
                        "localization_steps" => string(u_steps),
                        "structural_gate_pass" => string(
                            diagnostic_qualification !== nothing &&
                            something(diagnostic_qualification).qualified,
                        ),
                    ),
                ),
            )
        end
        status = if diagnostic_disentanglement_nonconverged
            MAX_ITERATIONS
        elseif any(diagnostic -> diagnostic.severity == :warning, diagnostics)
            COMPLETED_WITH_WARNINGS
        else
            COMPLETED
        end
        terminal_residuals = _candidate_invariant_residuals(frames, frozen_indices, representation)
        terminal_residuals = merge(
            terminal_residuals,
            (
                target_symmetry = apply_symmetry ?
                                  _maximum_target_frame_symmetry_error(
                    frames,
                    representation,
                    plan,
                ) : NaN,
            ),
        )
        _record_terminal_state!(
            input_summary,
            status,
            diagnostics,
            history,
            iteration,
            something(latest_restart_state).iteration;
            hard_gate_residuals = terminal_residuals,
        )
        return WannierizationResult(
            status,
            v_matrix,
            centers,
            spreads,
            history,
            diagnostics,
            input_summary,
            chk,
            nothing,
            latest_restart_state,
            WannierizationArtifacts(),
            initialization_report,
        )
    end
    return SolverIterationDecision(
        false,
        (;
            actual_u_mix_ratio,
            actual_z_mix_ratio,
            amn_sha256,
            anderson_residual_history,
            anderson_z_history,
            apply_symmetry,
            basis_sha256,
            best_polar_centers,
            best_polar_frames,
            best_polar_objective,
            best_polar_spreads,
            centers,
            compatibility,
            config,
            config_sha256,
            convergence_values,
            diagnostic_disentanglement_nonconverged,
            diagnostics,
            disentanglement_objective_history,
            effective_algorithms,
            effective_compatibility_policy,
            epoch,
            fixed_complete,
            fixed_mode,
            fixed_source_qualified,
            fixed_stability_count,
            fixed_stationary,
            fixed_stationary_count,
            frames,
            frozen_indices,
            full_constraint_scope,
            gradient_fallback_active,
            gradient_steps,
            grassmann_actual_decrease_history,
            grassmann_gradient_history,
            grassmann_predicted_decrease_history,
            grassmann_projector_change_history,
            grassmann_radius_history,
            grassmann_ratio_history,
            grassmann_trust_radius,
            history,
            improvement_streak,
            included_bands,
            initialization_report,
            input_summary,
            last_accepted_u_step_scale,
            last_anderson_reason,
            last_cg_beta,
            last_cg_restart_reason,
            last_u_optimizer_restart_reason,
            latest_restart_state,
            localization_initial_frames,
            localization_objective_history,
            localization_projector_drift_history,
            localization_reference_frames,
            localization_trial_accepted,
            localization_trial_actual_changes,
            localization_trial_directional_derivatives,
            localization_trial_iterations,
            localization_trial_objectives,
            localization_trial_required_changes,
            localization_trial_step_scales,
            localization_trial_sweeps,
            minimum_localization_diagonal_phase_margin,
            mmn,
            nb,
            nk,
            num_wannier,
            observer,
            optimizer_phase,
            outer_indices,
            phase_branch_backtracking_extension_count,
            plan,
            previous_merit,
            previous_u_direction,
            previous_u_gradient,
            prior_elapsed,
            projector_covariance_tolerance,
            rejected_steps,
            representation,
            residual_reference,
            sealed_subspace_frames,
            sealed_subspace_projectors,
            spectrum_audit,
            spreads,
            stage_stop_reason,
            start_iteration,
            started_ns,
            stencil,
            tangent_plans,
            trajectory_previous_frames,
            trajectory_two_step_frames,
            two_stage_complete,
            u_active_orbit_count,
            u_branch_signature,
            u_cg_iteration,
            u_cg_restart_count,
            u_generalized_gradient_rms,
            u_lbfgs_restart_count,
            u_lbfgs_rho_history,
            u_lbfgs_s_history,
            u_lbfgs_y_history,
            u_stability_count,
            u_steps,
            wannier90_reference_omega_i,
            wannier90_reference_overlaps,
            wannier90_reference_unitaries,
            weights,
            z_previous,
            z_stability_count,
            z_steps,
        ),
    )
end
