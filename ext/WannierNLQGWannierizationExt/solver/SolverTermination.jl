# Assemble the retained terminal state after a stage limit or exhausted iteration budget.
function _assemble_solver_terminal_result(state::NamedTuple)
    (;
        apply_symmetry,
        centers,
        compatibility,
        config,
        retained_disentanglement_nonconverged,
        diagnostics,
        effective_compatibility_policy,
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
    zero_optimization =
        state.effective_controls.objectives !== nothing &&
        state.effective_controls.objectives.dis_num_iter == 0 &&
        state.effective_controls.objectives.num_iter == 0
    retained_converged =
        state.effective_controls.objectives !== nothing && state.optimizer_phase == :completed
    terminal_status =
        zero_optimization ? COMPLETED_WITH_WARNINGS :
        retained_converged ? (retained_disentanglement_nonconverged ? MAX_ITERATIONS : COMPLETED) :
        MAX_ITERATIONS
    zero_optimization && push!(
        diagnostics,
        WannierizationDiagnostic(
            :OPTIMIZATION_SKIPPED,
            :info,
            "both optimization stages explicitly skipped; initialized state retained",
        ),
    )
    (zero_optimization || retained_converged) || push!(
        diagnostics,
        WannierizationDiagnostic(
            :MAX_ITERATIONS_REACHED,
            :warning,
            apply_symmetry ?
            "SAWF iteration reached max_iterations without the requested convergence criterion" :
            "ordinary full-BZ Wannierization reached max_iterations without convergence";
            context = Dict(
                "max_iterations" => string(state.effective_controls.total_iteration_budget),
            ),
        ),
    )
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
        final_projector_diagnostic.code == :ANTIUNITARY_PROJECTOR_COVARIANCE_FAILED &&
            _construction_compatibility_quality_failure(final_projector_diagnostic) ?
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
    if retained_disentanglement_nonconverged
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
            terminal_retained_state = true,
        )
        accepted_state_tb_ready = terminal_qualification.qualified
        input_summary["localization_convergence"] =
            get(input_summary, "localization_convergence", "IN_PROGRESS") == "IN_PROGRESS" ?
            "MAX_ITERATIONS" : input_summary["localization_convergence"]
        push!(
            diagnostics,
            WannierizationDiagnostic(
                accepted_state_tb_ready ? :NONCONVERGED_DISENTANGLEMENT_ACCEPTED_STATE_TB_READY :
                :NONCONVERGED_DISENTANGLEMENT_RETAINED_STATE_INVALID,
                accepted_state_tb_ready ? :warning : :error,
                accepted_state_tb_ready ?
                "localization retained a finite invariant-valid terminal state after nonconverged disentanglement; standard TB export is allowed" :
                "terminal localization state failed the standard TB export gate";
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
        terminal_status,
        diagnostics,
        history,
        something(latest_restart_state).iteration,
        something(latest_restart_state).iteration;
        hard_gate_residuals = terminal_residuals,
    )
    v_matrix = _pack_matrix_field(frames)
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
        terminal_status,
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

        apply_symmetry,

        best_polar_centers,
        best_polar_frames,
        best_polar_objective,
        best_polar_spreads,
        centers,
        compatibility,
        config,

        convergence_values,
        retained_disentanglement_nonconverged,
        diagnostics,
        disentanglement_objective_history,
        effective_algorithms,
        effective_compatibility_policy,
        epoch,
        frames,
        frozen_indices,
        full_constraint_scope,
        gradient_fallback_active,
        gradient_steps,
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
        two_stage_complete,
        u_active_orbit_count,
        u_branch_signature,
        u_cg_iteration,
        u_cg_restart_count,
        u_generalized_gradient_rms,
        u_stability_count,
        u_steps,
        recursive_localization_omega_i,
        recursive_localization_overlaps,
        recursive_localization_unitaries,
        weights,
        z_previous,
        z_stability_count,
        z_steps,
    ) = state
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
        config.solver.acceleration.schedule == :two_stage ? two_stage_complete :
        z_stability_count >= state.effective_controls.accepted_disentanglement_window &&
        u_stability_count >= max(2, state.effective_controls.objectives.conv_window)
    if solver_converged
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
            final_projector_diagnostic.code == :ANTIUNITARY_PROJECTOR_COVARIANCE_FAILED &&
                _construction_compatibility_quality_failure(final_projector_diagnostic) ?
            _construction_quality_diagnostic(final_projector_diagnostic, "final_projector") :
            final_projector_diagnostic,
        )
        if final_projector_diagnostic !== nothing && !(
            final_projector_diagnostic.code == :ANTIUNITARY_PROJECTOR_COVARIANCE_FAILED &&
            _construction_compatibility_quality_failure(final_projector_diagnostic)
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
        v_matrix = _pack_matrix_field(frames)
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
            retained_disentanglement_nonconverged ?
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
                terminal_retained_state = true,
            ) : nothing
        accepted_state_tb_ready =
            diagnostic_qualification !== nothing && something(diagnostic_qualification).qualified
        if retained_disentanglement_nonconverged
            input_summary["localization_convergence"] =
                state.effective_controls.objectives.num_iter == 0 ? "SKIPPED_ZERO_STEPS" :
                "CONVERGED"
            input_summary["failure_class"] = "NUMERICAL_B"
            push!(
                diagnostics,
                WannierizationDiagnostic(
                    accepted_state_tb_ready ?
                    :NONCONVERGED_DISENTANGLEMENT_ACCEPTED_STATE_TB_READY :
                    :NONCONVERGED_DISENTANGLEMENT_RETAINED_STATE_INVALID,
                    accepted_state_tb_ready ? :warning : :error,
                    accepted_state_tb_ready ?
                    (
                        state.effective_controls.objectives.num_iter == 0 ?
                        "localization initialization completed without optimization from a structurally qualified but nonconverged disentanglement projector; standard TB export is allowed" :
                        "localization converged from a structurally qualified but nonconverged disentanglement projector; standard TB export is allowed"
                    ) :
                    "the nonconverged disentanglement trajectory did not retain an exportable accepted localization state";
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
        status = if retained_disentanglement_nonconverged
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
            effective_controls = state.effective_controls,
            actual_u_mix_ratio,
            actual_z_mix_ratio,

            apply_symmetry,

            best_polar_centers,
            best_polar_frames,
            best_polar_objective,
            best_polar_spreads,
            centers,
            compatibility,
            config,

            convergence_values,
            retained_disentanglement_nonconverged,
            diagnostics,
            disentanglement_objective_history,
            effective_algorithms,
            effective_compatibility_policy,
            epoch,
            frames,
            frozen_indices,
            full_constraint_scope,
            gradient_fallback_active,
            gradient_steps,
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
            two_stage_complete,
            u_active_orbit_count,
            u_branch_signature,
            u_cg_iteration,
            u_cg_restart_count,
            u_generalized_gradient_rms,
            u_stability_count,
            u_steps,
            recursive_localization_omega_i,
            recursive_localization_overlaps,
            recursive_localization_unitaries,
            weights,
            z_previous,
            z_stability_count,
            z_steps,
        ),
    )
end
