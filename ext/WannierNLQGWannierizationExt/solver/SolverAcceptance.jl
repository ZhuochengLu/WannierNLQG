# Shared Z-to-U seal used for converged, budget-limited and failed-trial handoffs.
# The caller supplies the last accepted frame; rejected trial arrays never enter here.
function _seal_solver_disentanglement_state(state::NamedTuple)
    (;
        frames,
        centers,
        spreads,
        sealed_subspace_frames,
        sealed_subspace_projectors,
        localization_initial_frames,
        wannier90_reference_unitaries,
        wannier90_reference_overlaps,
        wannier90_reference_omega_i,
        optimizer_phase,
        u_stability_count,
        previous_u_gradient,
        previous_u_direction,
        u_cg_iteration,
        last_cg_beta,
        last_cg_restart_reason,
        convergence_values,
        two_stage_complete,
        config,
        effective_algorithms,
        representation,
        outer_indices,
        diagnostics,
        input_summary,
        history,
        latest_restart_state,
        iteration,
        initialization_report,
        included_bands,
        frozen_indices,
        z_previous,
        omega_i,
        projector_residual,
        disentanglement_objective_history,
        diagnostic_transition,
        localization_reference_frames,
        plan,
        apply_symmetry,
        mmn,
        weights,
    ) = state
    sealed_subspace_frames = deepcopy(frames)
    if effective_algorithms.disentanglement == :smv_fletcher_reeves_two_stage
        energy_gauge = _wannier90_reference_post_smv_hamiltonian_gauge(
            something(sealed_subspace_frames),
            representation.energies_ev,
            outer_indices,
        )
        if !energy_gauge.success
            push!(
                diagnostics,
                WannierizationDiagnostic(
                    energy_gauge.code,
                    :error,
                    "Wannier90-reference post-SMV Hamiltonian gauge failed";
                    context = Dict(
                        "kpoint" => string(energy_gauge.kpoint),
                        "maximum_projector_drift" => string(energy_gauge.maximum_projector_drift),
                        "maximum_projected_eigen_residual_ev" =>
                            string(energy_gauge.maximum_eigen_residual_ev),
                    ),
                ),
            )
            return _failure_result(
                LOCALIZATION_FAILED,
                diagnostics,
                input_summary;
                frames,
                centers,
                spreads,
                history,
                restart_state = latest_restart_state,
                representation,
                last_attempted_iteration = iteration,
                initialization_report,
            )
        end
        sealed_subspace_frames = energy_gauge.frames
        frames = deepcopy(something(sealed_subspace_frames))
        input_summary["wannier90_reference_post_smv_hamiltonian_gauge"] = "APPLIED"
        input_summary["wannier90_reference_post_smv_projector_drift"] =
            string(energy_gauge.maximum_projector_drift)
        input_summary["wannier90_reference_post_smv_projected_eigen_residual_ev"] =
            string(energy_gauge.maximum_eigen_residual_ev)
    end
    if effective_algorithms.localization == :smv_fletcher_reeves_two_stage
        _mpi_root_canonical_matrix_field!(something(sealed_subspace_frames), config.solver.parallel)
        frames = deepcopy(something(sealed_subspace_frames))
    end
    sealed_subspace_projectors = [frame * frame' for frame in frames]
    outer_mask = BitMatrix(reduce(hcat, included_bands))
    frozen_mask = falses(size(outer_mask))
    for kpoint in axes(frozen_mask, 2)
        frozen_mask[frozen_indices[kpoint], kpoint] .= true
    end
    disentanglement_state = DisentanglementState(
        cat(sealed_subspace_projectors...; dims = 3),
        cat(sealed_subspace_frames...; dims = 3),
        cat(something(z_previous)...; dims = 3),
        omega_i,
        outer_mask,
        frozen_mask,
        projector_residual,
        copy(disentanglement_objective_history),
        !diagnostic_transition,
    )
    input_summary["fixed_subspace_stage_boundary_iteration"] = string(iteration)
    input_summary["fixed_subspace_stage_boundary_projector_drift"] = "0.0"
    input_summary["fixed_subspace_stage_boundary_spread_angstrom2"] = string(sum(spreads))
    input_summary["fixed_subspace_projector_sha256"] =
        _complex_field_sha256(something(sealed_subspace_projectors))
    input_summary["fixed_subspace_frame_sha256"] =
        _complex_field_sha256(something(sealed_subspace_frames))
    input_summary["disentanglement_state_sha256"] =
        _disentanglement_state_sha256(disentanglement_state)
    input_summary["disentanglement_outer_mask_sha256"] =
        qualification_mask_sha256(disentanglement_state.outer_mask)
    input_summary["disentanglement_frozen_mask_sha256"] =
        qualification_mask_sha256(disentanglement_state.frozen_mask)
    input_summary["disentanglement_projector_residual"] =
        string(disentanglement_state.projector_residual)
    input_summary["disentanglement_state_converged"] = string(disentanglement_state.converged)
    if config.solver.localize
        aligned = _projected_reference_alignment(
            something(sealed_subspace_frames),
            localization_reference_frames,
            representation,
            plan,
            config.solver.numerical_thresholds.frame_transport_rtol,
            config.solver.numerical_thresholds.maximum_transport_condition,
            config.solver.numerical_thresholds.projectability_minimum_singular_value,
            apply_symmetry,
            config.solver.acceleration.constraint_operation_scope != :full,
            effective_algorithms.localization == :smv_fletcher_reeves_two_stage,
            outer_indices,
        )
        if !aligned.success
            push!(
                diagnostics,
                WannierizationDiagnostic(
                    :SINGULAR_LOCALIZATION_ALIGNMENT,
                    :error,
                    "projected AMN alignment is rank deficient";
                    context = Dict("kpoint" => string(aligned.kpoint)),
                ),
            )
            return _failure_result(
                SINGULAR_LOCALIZATION,
                diagnostics,
                input_summary;
                frames,
                centers,
                spreads,
                history,
                restart_state = latest_restart_state,
                representation,
                last_attempted_iteration = iteration,
                initialization_report,
            )
        end
        frames = aligned.frames
        if config.solver.multi_start.enabled && config.solver.multi_start.start_index > 1
            perturbed = _deterministic_sealed_subspace_perturbation(
                frames,
                config.solver.random_seed,
                config.solver.multi_start.start_index,
            )
            frames =
                apply_symmetry ? _expand_ibz_frames(perturbed, representation, plan) : perturbed
            input_summary["multi_start_perturbation"] = "DETERMINISTIC_SEALED_SUBSPACE_GAUGE"
            input_summary["multi_start_perturbation_index"] =
                string(config.solver.multi_start.start_index)
            input_summary["multi_start_perturbation_projector_drift"] =
                string(_maximum_projector_step(aligned.frames, frames))
        else
            input_summary["multi_start_perturbation"] = "ORIGINAL_AMN"
        end
        if effective_algorithms.localization == :smv_fletcher_reeves_two_stage &&
           wannier90_reference_unitaries === nothing
            wannier90_reference_unitaries =
                config.solver.multi_start.enabled && config.solver.multi_start.start_index > 1 ?
                [
                    _wannier90_reference_zgemm(
                        something(sealed_subspace_frames)[kpoint],
                        'C',
                        frames[kpoint],
                        'N',
                    ) for kpoint in eachindex(frames)
                ] : deepcopy(aligned.unitaries)
        end
        if effective_algorithms.localization == :smv_fletcher_reeves_two_stage
            # A stage-boundary checkpoint is a valid U restart,
            # even before the first localization step.  Seal the
            # recursive Wannier90 M/U state now; otherwise the
            # durable observer sees only the unitary half of the
            # state and correctly rejects the checkpoint as
            # incomplete.  This contraction is collective in
            # MPI mode and therefore also keeps every rank at
            # the same Z-to-U control-flow boundary.
            wannier90_reference_overlaps = _wannier90_reference_initial_slim_overlap_state(
                something(sealed_subspace_frames),
                something(wannier90_reference_unitaries),
                outer_indices,
                mmn,
                config.solver.parallel,
            )
            wannier90_reference_omega_i = _wannier90_reference_invariant_spread(
                something(wannier90_reference_overlaps),
                weights,
            )
        end
        localization_initial_frames = deepcopy(frames)
        input_summary["localization_initial_frame_sha256"] =
            _complex_field_sha256(something(localization_initial_frames))
        input_summary["raw_amn_alignment_minimum_singular_value"] =
            string(aligned.minimum_singular_value)
        input_summary["raw_amn_alignment_maximum_condition"] = string(aligned.maximum_condition)
        input_summary["raw_amn_alignment_projector_drift"] = string(aligned.projector_drift)
        input_summary["raw_amn_alignment_completion_count"] = string(sum(aligned.completion_counts))
        input_summary["raw_amn_alignment_rank_minimum"] =
            string(minimum(aligned.ranks[representation.irreducible_indices]))
        phase_reference_centers =
            effective_algorithms.localization == :smv_fletcher_reeves_two_stage ?
            zeros(size(centers)) : centers
        centers, spreads, _ = _solver_centers_spreads_and_directions(
            config,
            frames,
            phase_reference_centers,
            representation,
            mmn,
            weights,
            plan,
            effective_algorithms.localization == :smv_fletcher_reeves_two_stage ?
            wannier90_reference_overlaps : nothing,
        )
        input_summary["localization_stage_initial_spread_angstrom2"] = string(sum(spreads))
        optimizer_phase = :localization
        u_stability_count = 0
        previous_u_gradient = nothing
        previous_u_direction = nothing
        u_cg_iteration = 0
        last_cg_beta = NaN
        last_cg_restart_reason = :STAGE_BOUNDARY_RESET
        convergence_values = [vcat(vec(centers), spreads)]
        input_summary["localization_convergence"] = "IN_PROGRESS"
    else
        optimizer_phase = :completed
        two_stage_complete = true
    end
    return (;
        frames,
        centers,
        spreads,
        sealed_subspace_frames,
        sealed_subspace_projectors,
        localization_initial_frames,
        wannier90_reference_unitaries,
        wannier90_reference_overlaps,
        wannier90_reference_omega_i,
        optimizer_phase,
        u_stability_count,
        previous_u_gradient,
        previous_u_direction,
        u_cg_iteration,
        last_cg_beta,
        last_cg_restart_reason,
        convergence_values,
        two_stage_complete,
    )
end

# Commit the accepted candidate, update convergence histories and persist the observer state.
function _accept_solver_iteration(state::NamedTuple)
    (;
        accepted,
        accepted_anderson_context,
        accepted_anderson_fallback,
        accepted_anderson_reason,
        accepted_anderson_used,
        accepted_joint_reason,
        accepted_joint_transport_maximum_condition,
        accepted_joint_transport_minimum_singular_value,
        accepted_joint_z_backtracking_steps,
        accepted_merit,
        accepted_reference,
        accepted_residual_history,
        accepted_z,
        accepted_z_history,
        actual_u_mix_ratio,
        actual_z_mix_ratio,
        amn_sha256,
        apply_symmetry,
        basis_sha256,
        best_polar_centers,
        best_polar_frames,
        best_polar_objective,
        best_polar_spreads,
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
        irreducible,
        iteration,
        iteration_phase,
        joint_mode,
        last_accepted_u_step_scale,
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
        prior_elapsed,
        projector_covariance_tolerance,
        proposal_z_mix_ratio,
        rejected_steps,
        representation,
        sealed_subspace_frames,
        sealed_subspace_projectors,
        spectrum_audit,
        stage_stop_reason,
        start_iteration,
        started_ns,
        stencil,
        tangent_plans,
        trajectory_previous_frames,
        trajectory_two_step_frames,
        two_stage_complete,
        u_stability_count,
        u_steps,
        wannier90_reference_omega_i,
        wannier90_reference_overlaps,
        wannier90_reference_unitaries,
        weights,
        z_residual,
        z_stability_count,
        z_steps,
    ) = state
    accepted === nothing && error("internal acceleration acceptance state was not set")
    result = something(accepted)
    joint_mode && (actual_z_mix_ratio = proposal_z_mix_ratio)
    if result.raw_amn_alignment_applied
        localization_initial_frames = deepcopy(something(result.localization_initial_frames))
        input_summary["localization_initial_frame_sha256"] =
            _complex_field_sha256(something(localization_initial_frames))
        input_summary["raw_amn_alignment_minimum_singular_value"] =
            string(result.raw_amn_alignment_minimum_singular_value)
        input_summary["raw_amn_alignment_maximum_condition"] =
            string(result.raw_amn_alignment_maximum_condition)
        input_summary["raw_amn_alignment_projector_drift"] =
            string(result.raw_amn_alignment_projector_drift)
    end
    apply_symmetry &&
        !result.projection_converged &&
        push!(
            diagnostics,
            WannierizationDiagnostic(
                :LITTLE_GROUP_PROJECTION_NOT_CONVERGED,
                :warning,
                "symmetry projection reached its iteration limit";
                context = Dict(
                    "iteration" => string(iteration),
                    "projection_iterations" => string(result.projection_iterations),
                ),
            ),
        )
    accepted_anderson_fallback && push!(
        diagnostics,
        WannierizationDiagnostic(
            :ANDERSON_SAFEGUARD_FALLBACK,
            :info,
            "Anderson-Z proposal was skipped or rejected by its safeguard";
            context = merge(
                Dict(
                    "iteration" => string(iteration),
                    "reason" => String(accepted_anderson_reason),
                ),
                accepted_anderson_context,
            ),
        ),
    )
    accepted_anderson_used && push!(
        diagnostics,
        WannierizationDiagnostic(
            :ANDERSON_OBJECTIVE_SAFEGUARD_ACCEPTED,
            :info,
            "Anderson-Z proposal passed objective, projector, and Z-residual safeguards";
            context = merge(
                Dict(
                    "iteration" => string(iteration),
                    "reason" => String(accepted_anderson_reason),
                ),
                accepted_anderson_context,
            ),
        ),
    )
    frames = result.frames
    centers = result.centers
    spreads = result.spreads

    z_previous = something(accepted_z)
    previous_u_gradient = joint_mode ? nothing : result.previous_u_gradient
    previous_u_direction = joint_mode ? nothing : result.previous_u_direction
    u_cg_iteration = joint_mode ? 0 : result.u_cg_iteration
    u_cg_restart_count = result.u_cg_restart_count
    u_lbfgs_s_history = joint_mode ? Vector{Vector{Matrix{ComplexF64}}}() : result.u_lbfgs_s_history
    u_lbfgs_y_history = joint_mode ? Vector{Vector{Matrix{ComplexF64}}}() : result.u_lbfgs_y_history
    u_lbfgs_rho_history = joint_mode ? Float64[] : result.u_lbfgs_rho_history
    u_lbfgs_restart_count = result.u_lbfgs_restart_count
    u_branch_signature = joint_mode ? "" : result.u_active_orbit_sha256
    u_active_orbit_count = joint_mode ? 0 : result.u_active_orbit_count
    u_generalized_gradient_rms = result.generalized_gradient_rms
    last_u_optimizer_restart_reason = result.u_optimizer_restart_reason
    # A Z-only candidate owns only the disentanglement projector.  It must
    # not erase the sealed Wannier90 U-stage recursive M/U oracle that was
    # loaded before the two-stage run.  Rebuilding M from the completed Z
    # frame is physically equivalent, but changes its last bits and then
    # changes the Fletcher--Reeves/parabolic trajectory.  A localization
    # result, in contrast, owns and replaces the recursively updated state.
    if hasproperty(result, :wannier90_reference_overlaps)
        wannier90_reference_overlaps = result.wannier90_reference_overlaps
    elseif iteration_phase != :disentanglement
        wannier90_reference_overlaps = nothing
    end
    if hasproperty(result, :wannier90_reference_omega_i)
        wannier90_reference_omega_i = result.wannier90_reference_omega_i
    elseif iteration_phase != :disentanglement
        wannier90_reference_omega_i = nothing
    end
    if hasproperty(result, :wannier90_reference_unitaries)
        wannier90_reference_unitaries = result.wannier90_reference_unitaries
    elseif iteration_phase != :disentanglement
        wannier90_reference_unitaries = nothing
    end
    last_cg_beta = result.cg_beta
    last_cg_restart_reason =
        joint_mode &&
        effective_algorithms.localization in (:riemannian_cg, :smv_fletcher_reeves_two_stage) ?
        :JOINT_SUBSPACE_RESET : result.cg_restart_reason
    last_anderson_reason = accepted_anderson_reason
    spread_total = result.spread_total
    spread_std = result.spread_std
    covariance_error = result.covariance_error
    previous_convergence_metric = isempty(history) ? NaN : last(history).spread_standard_deviation
    push!(convergence_values, vcat(vec(centers), spreads))
    directional = result.directional
    directional_available =
        directional !== nothing && abs(sum(something(directional)) - spread_total) <= 1.0e-10
    directional_available || push!(
        diagnostics,
        WannierizationDiagnostic(
            :DIRECTIONAL_SPREAD_UNAVAILABLE,
            :info,
            "directional spread decomposition does not reconstruct the full-3D total";
            context = Dict(
                "iteration" => string(iteration),
                "total" => string(spread_total),
                "directional_sum" =>
                    directional === nothing ? "unavailable" : string(sum(something(directional))),
            ),
        ),
    )
    previous_total_spreads = [entry.spread_total for entry in history]
    push!(previous_total_spreads, spread_total)
    total_spread_window =
        previous_total_spreads[max(1, end - config.solver.convergence_window + 1):end]
    total_spread_window_std = _population_standard_deviation(total_spread_window)
    omega_i = _gauge_invariant_spread(frames, mmn, weights)
    omega_i_delta = if isempty(disentanglement_objective_history)
        Inf
    elseif _is_smv_fletcher_reeves_disentanglement(effective_algorithms.disentanglement)
        previous = last(disentanglement_objective_history)
        abs(previous) <= eps(Float64) ? Inf : omega_i / previous - 1.0
    else
        abs(omega_i - last(disentanglement_objective_history))
    end
    z_iteration =
        config.solver.acceleration.schedule == :joint ||
        (config.solver.acceleration.schedule == :two_stage && iteration_phase == :disentanglement)
    if z_iteration
        z_iteration_stable = if _is_symmetry_projected_smv_fr(effective_algorithms.disentanglement)
            abs(omega_i_delta) <=
            min(1.0e-10, config.solver.acceleration.disentanglement_objective_tolerance) &&
                result.projector_residual <=
                min(1.0e-10, config.solver.acceleration.z_projector_tolerance)
        elseif effective_algorithms.disentanglement == :smv_fletcher_reeves_two_stage
            abs(omega_i_delta) <= config.solver.acceleration.disentanglement_objective_tolerance
        else
            omega_i_delta <= config.solver.acceleration.disentanglement_objective_tolerance &&
                result.projector_residual <= config.solver.acceleration.z_projector_tolerance
        end
        if z_iteration_stable
            z_stability_count += 1
        else
            z_stability_count = 0
        end
        push!(disentanglement_objective_history, omega_i)
    end
    if config.solver.acceleration.schedule == :joint
        if length(total_spread_window) == config.solver.convergence_window &&
           result.gradient_rms <= config.solver.acceleration.u_gradient_norm_tolerance &&
           result.u_residual <= config.solver.acceleration.u_inner_tolerance &&
           total_spread_window_std <= config.solver.convergence_tolerance
            u_stability_count += 1
        else
            u_stability_count = 0
        end
        joint_z_converged = z_stability_count >= config.solver.acceleration.z_stability_window
        input_summary["z_seal_class"] = joint_z_converged ? "CONVERGED" : "IN_PROGRESS"
        input_summary["qualified_z_seal"] = string(joint_z_converged)
        input_summary["disentanglement_convergence"] =
            joint_z_converged ? "CONVERGED" : "IN_PROGRESS"
        input_summary["localization_convergence"] =
            u_stability_count >= config.solver.convergence_window ? "CONVERGED" : "IN_PROGRESS"
    end
    iteration_diagnostics = WannierizationIterationDiagnostics(
        directional_available ? something(directional) : nothing,
        spread_total,
        result.projector_residual,
        z_residual,
        result.u_residual,
        result.wcc_step,
        result.spread_step,
        result.projection_residual,
        result.z_boundary_gap,
        actual_z_mix_ratio,
        actual_u_mix_ratio,
        result.completed_sweeps,
        accepted_anderson_used,
        accepted_anderson_fallback,
        rejected_steps,
        result.gradient_rms,
        result.accepted_step_scale,
        result.backtracking_steps,
        result.directional_derivative,
        result.fixed_projector_drift,
        result.base_objective,
        result.accepted_required_change,
        result.accepted_actual_change,
        accepted_anderson_reason,
        result.minimum_diagonal_phase_margin,
        result.minimum_phase_kpoint,
        result.minimum_phase_neighbor,
        result.minimum_phase_wannier,
        result.cg_beta,
        result.cg_restarted,
        result.cg_restart_reason,
        result.cg_descent_cosine,
        result.maximum_kstar_gradient_rms,
        result.maximum_kstar_gradient_index,
        omega_i,
        omega_i_delta,
        z_stability_count,
        accepted_joint_z_backtracking_steps,
        accepted_joint_transport_minimum_singular_value,
        accepted_joint_transport_maximum_condition,
        accepted_joint_reason,
    )
    push!(
        history,
        WannierizationIteration(
            iteration,
            spread_total,
            spread_std,
            covariance_error,
            iteration_diagnostics,
        ),
    )
    if fixed_mode
        if length(total_spread_window) == config.solver.convergence_window &&
           result.gradient_rms <= config.solver.acceleration.u_gradient_norm_tolerance &&
           result.u_residual <= config.solver.acceleration.u_inner_tolerance &&
           total_spread_window_std <= config.solver.convergence_tolerance
            fixed_stability_count += 1
        else
            fixed_stability_count = 0
        end
        fixed_complete = fixed_stability_count >= config.solver.convergence_window
        if result.gradient_rms <= config.solver.acceleration.u_gradient_norm_tolerance &&
           result.u_residual <= config.solver.acceleration.u_inner_tolerance &&
           total_spread_window_std > config.solver.convergence_tolerance
            fixed_stationary_count += 1
        else
            fixed_stationary_count = 0
        end
        fixed_stationary = fixed_stationary_count >= config.solver.convergence_window
    end
    z_recheck_drift = NaN
    localization_iteration =
        config.solver.acceleration.schedule in (:joint, :fixed_subspace) ||
        iteration_phase == :localization
    if localization_iteration
        if hasproperty(result, :minimum_diagonal_phase_margin)
            minimum_localization_diagonal_phase_margin = min(
                minimum_localization_diagonal_phase_margin,
                result.minimum_diagonal_phase_margin,
            )
            input_summary["minimum_localization_diagonal_phase_margin"] =
                string(minimum_localization_diagonal_phase_margin)
        end
        if hasproperty(result, :branch_safe_backtracking_triggered) &&
           result.branch_safe_backtracking_triggered
            phase_branch_backtracking_extension_count += 1
            input_summary["phase_branch_backtracking_extension_count"] =
                string(phase_branch_backtracking_extension_count)
            phase_branch_backtracking_extension_count == 1 && push!(
                diagnostics,
                WannierizationDiagnostic(
                    :PHASE_BRANCH_BACKTRACKING_EXTENDED,
                    :info,
                    "Armijo continued below the configured backtracking budget near a principal-log branch cut";
                    context = Dict(
                        "iteration" => string(iteration),
                        "configured_backtracking_max_steps" =>
                            string(config.solver.acceleration.u_backtracking_max_steps),
                        "accepted_backtracking_steps" => string(result.backtracking_steps),
                        "minimum_diagonal_phase_margin" =>
                            string(result.minimum_diagonal_phase_margin),
                    ),
                ),
            )
        end
        push!(localization_objective_history, result.accepted_objective)
        append!(localization_trial_step_scales, result.attempted_step_scales)
        append!(localization_trial_objectives, result.attempted_objectives)
        append!(localization_trial_required_changes, result.attempted_required_changes)
        append!(localization_trial_actual_changes, result.attempted_actual_changes)
        append!(
            localization_trial_directional_derivatives,
            result.attempted_directional_derivatives,
        )
        attempted_count = length(result.attempted_step_scales)
        append!(localization_trial_iterations, fill(iteration, attempted_count))
        append!(localization_trial_sweeps, result.attempted_sweeps)
        append!(localization_trial_accepted, result.attempted_accepted)
        push!(localization_projector_drift_history, result.fixed_projector_drift)
        u_steps += result.completed_sweeps
        gradient_steps += result.completed_sweeps
        last_accepted_u_step_scale = result.accepted_step_scale
    end
    if config.solver.acceleration.schedule == :two_stage
        if iteration_phase == :disentanglement
            z_steps += 1
            z_stage_converged = z_stability_count >= config.solver.acceleration.z_stability_window
            z_stage_limit_reached = z_steps >= config.solver.acceleration.disentanglement_max_steps
            diagnostic_transition = false
            transition_to_localization = z_stage_converged
            if !z_stage_converged && z_stage_limit_reached
                if config.solver.acceleration.disentanglement_limit_policy == :strict_hold
                    input_summary["disentanglement_convergence"] = "DIAGNOSTIC_NONCONVERGED"
                    input_summary["z_seal_class"] = "DIAGNOSTIC_NONCONVERGED"
                    input_summary["qualified_z_seal"] = "false"
                    input_summary["route_selection_eligible"] = "false"
                    input_summary["standard_tb_export_eligible"] = "false"
                    input_summary["localization_convergence"] = "NOT_RUN"
                    input_summary["localization_qualification"] = "NOT_RUN"
                    stage_stop_reason = :DISENTANGLEMENT_MAX_STEPS_STRICT_HOLD
                else
                    qualification = _qualify_nonconverged_disentanglement_state(
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
                    if qualification.qualified
                        diagnostic_transition = true
                        transition_to_localization = true
                        diagnostic_disentanglement_nonconverged = true
                        input_summary["disentanglement_convergence"] = "DIAGNOSTIC_NONCONVERGED"
                        input_summary["z_seal_class"] = "DIAGNOSTIC_NONCONVERGED"
                        input_summary["qualified_z_seal"] = "false"
                        input_summary["route_selection_eligible"] = "false"
                        input_summary["standard_tb_export_eligible"] = "false"
                        input_summary["localization_qualification"] = "DIAGNOSTIC_ONLY"
                        input_summary["model_qualification"] = "DIAGNOSTIC_ONLY/Z_NONCONVERGED"
                        input_summary["z_continuation_corepresentation_residual"] =
                            string(qualification.corepresentation_residual)
                        input_summary["z_continuation_kstar_expansion_residual"] =
                            string(qualification.kstar_expansion_residual)
                        input_summary["z_continuation_target_symmetry_residual"] =
                            string(qualification.target_symmetry_residual)
                        push!(
                            diagnostics,
                            WannierizationDiagnostic(
                                :DISENTANGLEMENT_MAX_STEPS_CONTINUED_DIAGNOSTIC,
                                :warning,
                                "disentanglement reached its step limit; the finite, full-rank, invariant-valid projector is retained for diagnostic localization without a qualified Z seal";
                                context = Dict(
                                    "steps" => string(z_steps),
                                    "omega_i" => string(omega_i),
                                    "delta_omega_i" => string(omega_i_delta),
                                    "z_field_finite" => string(qualification.z_finite),
                                    "required_frame_rank" => string(qualification.required_rank),
                                    "minimum_frame_rank" => string(qualification.minimum_rank),
                                    "minimum_frame_singular_value" =>
                                        string(qualification.minimum_singular_value),
                                    "isometry_residual" => string(qualification.isometry_residual),
                                    "frozen_residual" => string(qualification.frozen_residual),
                                    "covariance_residual" =>
                                        string(qualification.covariance_residual),
                                    "target_symmetry_residual" =>
                                        string(qualification.target_symmetry_residual),
                                    "kstar_expansion_residual" =>
                                        string(qualification.kstar_expansion_residual),
                                    "corepresentation_residual" =>
                                        string(qualification.corepresentation_residual),
                                ),
                            ),
                        )
                    else
                        push!(
                            diagnostics,
                            WannierizationDiagnostic(
                                qualification.failure_code,
                                :error,
                                "nonconverged disentanglement state failed the structural continuation gate";
                                context = Dict(
                                    "steps" => string(z_steps),
                                    "z_field_finite" => string(qualification.z_finite),
                                    "required_frame_rank" => string(qualification.required_rank),
                                    "minimum_frame_rank" => string(qualification.minimum_rank),
                                    "minimum_frame_singular_value" =>
                                        string(qualification.minimum_singular_value),
                                    "isometry_residual" => string(qualification.isometry_residual),
                                    "frozen_residual" => string(qualification.frozen_residual),
                                    "covariance_residual" =>
                                        string(qualification.covariance_residual),
                                ),
                            ),
                        )
                        input_summary["disentanglement_convergence"] = "DIAGNOSTIC_NONCONVERGED_STRUCTURAL_GATE_FAILED"
                        input_summary["z_seal_class"] = "DIAGNOSTIC_NONCONVERGED"
                        input_summary["qualified_z_seal"] = "false"
                        input_summary["route_selection_eligible"] = "false"
                        input_summary["standard_tb_export_eligible"] = "false"
                        input_summary["localization_convergence"] = "NOT_RUN"
                        input_summary["localization_qualification"] = "NOT_RUN"
                        input_summary["model_qualification"] = "NOT_RUN/Z_STRUCTURAL_GATE_FAILED"
                        stage_stop_reason = :DISENTANGLEMENT_STRUCTURAL_QUALIFICATION_FAILED
                    end
                end
            end
            if transition_to_localization
                seal = _seal_solver_disentanglement_state((;
                    frames,
                    centers,
                    spreads,
                    sealed_subspace_frames,
                    sealed_subspace_projectors,
                    localization_initial_frames,
                    wannier90_reference_unitaries,
                    wannier90_reference_overlaps,
                    wannier90_reference_omega_i,
                    optimizer_phase,
                    u_stability_count,
                    previous_u_gradient,
                    previous_u_direction,
                    u_cg_iteration,
                    last_cg_beta,
                    last_cg_restart_reason,
                    convergence_values,
                    two_stage_complete,
                    config,
                    effective_algorithms,
                    representation,
                    outer_indices,
                    diagnostics,
                    input_summary,
                    history,
                    latest_restart_state,
                    iteration,
                    initialization_report,
                    included_bands,
                    frozen_indices,
                    z_previous,
                    omega_i,
                    disentanglement_objective_history,
                    diagnostic_transition,
                    localization_reference_frames,
                    plan,
                    apply_symmetry,
                    mmn,
                    weights,
                    projector_residual = result.projector_residual,
                ))
                seal isa WannierizationResult && return seal
                (;
                    frames,
                    centers,
                    spreads,
                    sealed_subspace_frames,
                    sealed_subspace_projectors,
                    localization_initial_frames,
                    wannier90_reference_unitaries,
                    wannier90_reference_overlaps,
                    wannier90_reference_omega_i,
                    optimizer_phase,
                    u_stability_count,
                    previous_u_gradient,
                    previous_u_direction,
                    u_cg_iteration,
                    last_cg_beta,
                    last_cg_restart_reason,
                    convergence_values,
                    two_stage_complete,
                ) = seal
                if !diagnostic_transition
                    input_summary["disentanglement_convergence"] = "CONVERGED"
                    input_summary["z_seal_class"] = "CONVERGED"
                    input_summary["qualified_z_seal"] = "true"
                    input_summary["route_selection_eligible"] = string(full_constraint_scope)
                    input_summary["localization_qualification"] =
                        config.solver.localize ? "FORMAL_CANDIDATE" : "NOT_APPLICABLE"
                    input_summary["model_qualification"] = "FORMAL_CANDIDATE"
                    push!(
                        diagnostics,
                        WannierizationDiagnostic(
                            :DISENTANGLEMENT_COMPLETED,
                            :info,
                            "Omega_I and projector-drift stability gates passed";
                            context = Dict(
                                "steps" => string(z_steps),
                                "omega_i" => string(omega_i),
                                "delta_omega_i" => string(omega_i_delta),
                            ),
                        ),
                    )
                end
            end
        elseif iteration_phase == :localization
            if length(total_spread_window) == config.solver.convergence_window &&
               result.gradient_rms <= config.solver.acceleration.u_gradient_norm_tolerance &&
               result.u_residual <= config.solver.acceleration.u_inner_tolerance &&
               total_spread_window_std <= config.solver.convergence_tolerance
                u_stability_count += 1
            else
                u_stability_count = 0
            end
            two_stage_complete = u_stability_count >= config.solver.convergence_window
            if two_stage_complete
                optimizer_phase = :completed
                input_summary["localization_convergence"] = "CONVERGED"
                qualified_z = get(input_summary, "qualified_z_seal", "false") == "true"
                input_summary["localization_qualification"] =
                    qualified_z ? "FORMAL_CANDIDATE" : "DIAGNOSTIC_ONLY"
                input_summary["model_qualification"] =
                    qualified_z ? "FORMAL_CANDIDATE" : "DIAGNOSTIC_ONLY/Z_NONCONVERGED"
                input_summary["standard_tb_export_eligible"] =
                    string(full_constraint_scope && qualified_z)
            end
            !two_stage_complete &&
                u_steps >= config.solver.acceleration.localization_max_steps &&
                begin
                    input_summary["localization_convergence"] = "MAX_ITERATIONS"
                    stage_stop_reason = :LOCALIZATION_MAX_STEPS
                end
        end
    elseif config.solver.acceleration.schedule == :joint
        z_steps += 1
        joint_z_converged = z_stability_count >= config.solver.acceleration.z_stability_window
        joint_converged = joint_z_converged && u_stability_count >= config.solver.convergence_window
        input_summary["route_selection_eligible"] =
            string(full_constraint_scope && joint_z_converged)
        input_summary["standard_tb_export_eligible"] =
            string(full_constraint_scope && joint_converged)
    end
    if config.solver.acceleration.strategy == :adaptive
        actual_z_mix_ratio, actual_u_mix_ratio, improvement_streak = _adaptive_next_mixing(
            actual_z_mix_ratio,
            actual_u_mix_ratio,
            improvement_streak,
            previous_convergence_metric,
            spread_std,
            config.solver.acceleration,
        )
    end
    residual_reference = accepted_reference
    previous_merit = accepted_merit
    anderson_z_history = accepted_z_history
    anderson_residual_history = accepted_residual_history
    one_step_geodesic_distances = fill(NaN, length(irreducible))
    two_step_geodesic_distances = fill(NaN, length(irreducible))
    aligned_one_step_geodesic_distances = fill(NaN, length(irreducible))
    if trajectory_previous_frames !== nothing
        previous_frames = something(trajectory_previous_frames)
        for (local_index, kpoint) in enumerate(irreducible)
            one_step_geodesic_distances[local_index] = _frame_geodesic_distance(
                previous_frames[kpoint],
                frames[kpoint],
                config.input.representation_tolerance,
            )
            aligned_one_step_geodesic_distances[local_index] =
                one_step_geodesic_distances[local_index]
            if trajectory_two_step_frames !== nothing
                two_frames = something(trajectory_two_step_frames)
                two_step_geodesic_distances[local_index] = _frame_geodesic_distance(
                    two_frames[kpoint],
                    frames[kpoint],
                    config.input.representation_tolerance,
                )
            end
        end
    end
    one_step_geodesic_distance =
        all(isfinite, one_step_geodesic_distances) ? maximum(one_step_geodesic_distances) : NaN
    two_step_geodesic_distance =
        all(isfinite, two_step_geodesic_distances) ? maximum(two_step_geodesic_distances) : NaN
    aligned_one_step_geodesic_distance =
        all(isfinite, aligned_one_step_geodesic_distances) ?
        maximum(aligned_one_step_geodesic_distances) : NaN
    accepted_invariants = _candidate_invariant_residuals(frames, frozen_indices, representation)
    apply_symmetry && _record_construction_symmetry_quality!(
        diagnostics,
        input_summary,
        frames,
        frozen_indices,
        representation,
        plan,
        config,
        projector_covariance_tolerance,
        "accepted_iteration_$(iteration)";
        residuals = accepted_invariants,
    )
    elapsed_seconds = prior_elapsed + (time_ns() - started_ns) / 1.0e9
    optimizer_state = WannierizationOptimizerState(
        config.solver.acceleration.strategy,
        actual_z_mix_ratio,
        actual_u_mix_ratio,
        improvement_streak,
        rejected_steps,
        residual_reference,
        previous_merit,
        anderson_z_history,
        anderson_residual_history,
        optimizer_phase,
        z_stability_count,
        u_stability_count,
        z_steps,
        u_steps,
        epoch,
        last_accepted_u_step_scale,
        gradient_fallback_active,
        gradient_steps,
        cat(best_polar_frames...; dims = 3),
        best_polar_centers,
        best_polar_spreads,
        best_polar_objective,
        disentanglement_objective_history,
        localization_objective_history,
        localization_trial_step_scales,
        localization_trial_objectives,
        localization_trial_required_changes,
        localization_trial_actual_changes,
        localization_trial_directional_derivatives,
        localization_projector_drift_history,
        localization_trial_iterations,
        localization_trial_sweeps,
        localization_trial_accepted,
        previous_u_gradient === nothing ? zeros(ComplexF64, 0, 0, 0) :
        cat(something(previous_u_gradient)...; dims = 3),
        previous_u_direction === nothing ? zeros(ComplexF64, 0, 0, 0) :
        cat(something(previous_u_direction)...; dims = 3),
        u_cg_iteration,
        u_cg_restart_count,
        last_cg_beta,
        last_cg_restart_reason,
        last_anderson_reason,
        LOCALIZATION_GRADIENT_CONTRACT,
        u_branch_signature,
        u_active_orbit_count,
        u_generalized_gradient_rms,
        _pack_u_tangent_history(u_lbfgs_s_history),
        _pack_u_tangent_history(u_lbfgs_y_history),
        u_lbfgs_rho_history,
        u_lbfgs_restart_count,
        last_u_optimizer_restart_reason,
        wannier90_reference_overlaps === nothing ? zeros(ComplexF64, 0, 0, 0, 0) :
        something(wannier90_reference_overlaps),
        wannier90_reference_unitaries === nothing ? zeros(ComplexF64, 0, 0, 0) :
        cat(something(wannier90_reference_unitaries)...; dims = 3),
        something(wannier90_reference_omega_i, NaN),
    )
    latest_restart_state = _restart_state(
        iteration,
        frames,
        z_previous,
        centers,
        spreads,
        convergence_values[max(1, end - config.solver.convergence_window + 1):end],
        included_bands,
        elapsed_seconds,
        config_sha256,
        compatibility.representation_sha256,
        stencil,
        basis_sha256,
        amn_sha256,
        optimizer_state,
        fixed_subspace_projectors = sealed_subspace_projectors,
        fixed_subspace_frames = sealed_subspace_frames,
        localization_initial_frames = localization_initial_frames,
    )
    input_summary["optimizer_phase"] = String(optimizer_phase)
    input_summary["disentanglement_steps"] = string(z_steps)
    input_summary["localization_steps"] = string(u_steps)
    input_summary["u_active_orbit_sha256"] = u_branch_signature
    input_summary["u_active_orbit_count"] = string(u_active_orbit_count)
    input_summary["u_generalized_gradient_rms"] = string(u_generalized_gradient_rms)
    input_summary["u_lbfgs_restart_count"] = string(u_lbfgs_restart_count)
    input_summary["last_u_optimizer_restart_reason"] = String(last_u_optimizer_restart_reason)
    input_summary["disentanglement_objective_count"] =
        string(length(disentanglement_objective_history))
    input_summary["localization_objective_count"] = string(length(localization_objective_history))
    input_summary["last_omega_i"] =
        isempty(disentanglement_objective_history) ? "NOT_APPLICABLE" :
        string(last(disentanglement_objective_history))
    input_summary["last_localization_objective"] =
        isempty(localization_objective_history) ? "NOT_APPLICABLE" :
        string(last(localization_objective_history))
    input_summary["last_anderson_reason"] = String(last_anderson_reason)
    input_summary["last_cg_beta"] = string(last_cg_beta)
    input_summary["last_cg_restart_reason"] = String(last_cg_restart_reason)
    input_summary["u_cg_iteration"] = string(u_cg_iteration)
    input_summary["u_cg_restart_count"] = string(u_cg_restart_count)
    observer_error = ""
    if observer !== nothing
        try
            observer(
                (
                    iteration = iteration,
                    spread_total = spread_total,
                    convergence_metric = spread_std,
                    maximum_covariance_error = covariance_error,
                    little_group_iterations = result.projection_iterations,
                    little_group_residual = result.projection_residual,
                    projector_residual = result.projector_residual,
                    z_residual = z_residual,
                    u_residual = result.u_residual,
                    normalized_residual_merit = accepted_merit,
                    z_mix_ratio = iteration_diagnostics.z_mix_ratio,
                    u_mix_ratio = iteration_diagnostics.u_mix_ratio,
                    u_inner_sweeps = iteration_diagnostics.u_inner_sweeps,
                    anderson_used = iteration_diagnostics.anderson_used,
                    anderson_fallback = iteration_diagnostics.anderson_fallback,
                    anderson_reason = iteration_diagnostics.anderson_reason,
                    rejected_steps = iteration_diagnostics.rejected_steps,
                    optimizer_phase = optimizer_phase,
                    stage = optimizer_phase,
                    completed_stage = iteration_phase,
                    omega_i = omega_i,
                    delta_omega_i = omega_i_delta,
                    z_stability_count = z_stability_count,
                    u_stability_count = u_stability_count,
                    disentanglement_convergence = input_summary["disentanglement_convergence"],
                    z_seal_class = input_summary["z_seal_class"],
                    qualified_z_seal = input_summary["qualified_z_seal"],
                    route_selection_eligible = input_summary["route_selection_eligible"],
                    localization_convergence = input_summary["localization_convergence"],
                    localization_qualification = input_summary["localization_qualification"],
                    model_qualification = input_summary["model_qualification"],
                    z_steps = z_steps,
                    u_steps = u_steps,
                    gradient_steps = gradient_steps,
                    gradient_fallback_active = gradient_fallback_active,
                    projected_gradient_rms = result.gradient_rms,
                    total_spread_window_standard_deviation = total_spread_window_std,
                    fixed_stability_count = fixed_stability_count,
                    epoch = epoch,
                    accepted_u_step_scale = result.accepted_step_scale,
                    localization_backtracking_steps = result.backtracking_steps,
                    trial_objective = result.trial_objective,
                    accepted_objective = result.accepted_objective,
                    base_objective = result.base_objective,
                    trial_zero_objective = result.trial_zero_objective,
                    trial_zero_frame_residual = result.trial_zero_frame_residual,
                    attempted_step_scales = result.attempted_step_scales,
                    attempted_objectives = result.attempted_objectives,
                    attempted_required_changes = result.attempted_required_changes,
                    attempted_actual_changes = result.attempted_actual_changes,
                    attempted_directional_derivatives = result.attempted_directional_derivatives,
                    directional_derivative = result.directional_derivative,
                    fixed_projector_drift = result.fixed_projector_drift,
                    accepted_required_change = result.accepted_required_change,
                    accepted_actual_change = result.accepted_actual_change,
                    minimum_diagonal_phase_margin = result.minimum_diagonal_phase_margin,
                    minimum_phase_kpoint = result.minimum_phase_kpoint,
                    minimum_phase_neighbor = result.minimum_phase_neighbor,
                    minimum_phase_wannier = result.minimum_phase_wannier,
                    minimum_phase_value = result.minimum_phase_value,
                    branch_safe_backtracking_triggered = result.branch_safe_backtracking_triggered,
                    u_active_orbit_sha256 = u_branch_signature,
                    u_active_orbit_count = u_active_orbit_count,
                    u_generalized_gradient_rms = u_generalized_gradient_rms,
                    cg_beta = result.cg_beta,
                    cg_restarted = result.cg_restarted,
                    cg_restart_reason = result.cg_restart_reason,
                    cg_descent_cosine = result.cg_descent_cosine,
                    u_cg_iteration = result.u_cg_iteration,
                    u_cg_restart_count = result.u_cg_restart_count,
                    u_lbfgs_restart_count = u_lbfgs_restart_count,
                    last_u_optimizer_restart_reason = last_u_optimizer_restart_reason,
                    kstar_gradient_rms = result.kstar_gradient_rms,
                    maximum_kstar_gradient_rms = result.maximum_kstar_gradient_rms,
                    maximum_kstar_gradient_index = result.maximum_kstar_gradient_index,
                    joint_z_backtracking_steps = accepted_joint_z_backtracking_steps,
                    joint_transport_minimum_singular_value = accepted_joint_transport_minimum_singular_value,
                    joint_transport_maximum_condition = accepted_joint_transport_maximum_condition,
                    joint_acceptance_reason = accepted_joint_reason,
                    localization_spectra = result.localization_spectra,
                    localization_ranks = result.localization_ranks,
                    localization_conditions = result.localization_conditions,
                    raw_eigenphases = result.raw_eigenphases,
                    aligned_eigenphases = result.aligned_eigenphases,
                    raw_geodesic_distances = result.raw_geodesic_distances,
                    aligned_geodesic_distances = result.aligned_geodesic_distances,
                    block_permutations = result.block_permutations,
                    block_phases = result.block_phases,
                    z_recheck_drift = z_recheck_drift,
                    one_step_geodesic_distances = one_step_geodesic_distances,
                    two_step_geodesic_distances = two_step_geodesic_distances,
                    aligned_one_step_geodesic_distances = aligned_one_step_geodesic_distances,
                    one_step_geodesic_distance = one_step_geodesic_distance,
                    two_step_geodesic_distance = two_step_geodesic_distance,
                    aligned_one_step_geodesic_distance = aligned_one_step_geodesic_distance,
                    isometry_residual = accepted_invariants.isometry,
                    frozen_projector_residual = accepted_invariants.frozen,
                    elapsed_seconds = elapsed_seconds,
                    centers = centers,
                    spreads = spreads,
                ),
                latest_restart_state,
                history,
                diagnostics,
            )
        catch exception
            observer_error = sprint(showerror, exception, catch_backtrace())
        end
    end
    if config.solver.parallel == :mpi
        observer_succeeded = _mpi_all_ranks_success(isempty(observer_error), config.solver.parallel)
        if !observer_succeeded
            observer_error = _mpi_root_canonical_string(observer_error, config.solver.parallel)
        end
    end
    if !isempty(observer_error)
        push!(
            diagnostics,
            WannierizationDiagnostic(
                :ITERATION_OBSERVER_PERSISTENCE_FAILED,
                :error,
                "the authoritative iteration observer failed before the next collective solver step";
                context = Dict("iteration" => string(iteration), "detail" => observer_error),
            ),
        )
        return _failure_result(
            IO_FAILURE,
            diagnostics,
            input_summary;
            frames,
            centers,
            spreads,
            history,
            restart_state = latest_restart_state,
            representation,
            last_attempted_iteration = iteration,
            hard_gate_residuals = accepted_invariants,
            initialization_report,
        )
    end
    trajectory_two_step_frames = trajectory_previous_frames
    trajectory_previous_frames = deepcopy(frames)
    return (;
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
    )
end
