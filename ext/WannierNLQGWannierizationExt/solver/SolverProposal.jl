# Evaluate safeguarded Z/U proposals without committing a rejected trial.
function _propose_solver_iteration(
    state::NamedTuple;
    geometry::Union{Nothing, LocalizationGeometryWorkspace} = nothing,
    dot_workspace::Union{Nothing, ReferenceDotWorkspace} = nothing,
    accepted_evaluation::Union{Nothing, AcceptedReferenceEvaluationWorkspace} = nothing,
)
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
    ) = state
    iteration_phase = optimizer_phase
    irreducible = representation.irreducible_indices
    freeze_z =
        (config.solver.acceleration.schedule == :two_stage && optimizer_phase == :localization)
    z_raw = if freeze_z
        deepcopy(something(z_previous))
    else
        full_field = _raw_z_field(
            representation,
            mmn,
            weights,
            outer_indices,
            frames,
            config.solver.parallel;
            full_bz = apply_symmetry,
            storage_backend = config.solver.acceleration.hot_storage_backend,
            recursive_localization = effective_algorithms.disentanglement ==
                                     :smv_fletcher_reeves_two_stage,
        )
        apply_symmetry ? _reduce_full_star_hermitian_field(full_field, representation) : full_field
    end
    z_residual =
        freeze_z ? 0.0 :
        z_previous === nothing ? maximum(norm, z_raw) :
        maximum(norm(z_raw[k] - z_previous[k]) for k in irreducible)
    accepted = nothing
    accepted_z = nothing
    accepted_merit = NaN
    accepted_reference = residual_reference
    accepted_anderson_used = false
    accepted_anderson_fallback = false
    accepted_anderson_reason = :NOT_APPLICABLE
    accepted_anderson_context = Dict{String, String}()
    accepted_joint_z_backtracking_steps = 0
    accepted_joint_transport_minimum_singular_value = NaN
    accepted_joint_transport_maximum_condition = NaN
    accepted_joint_reason = :NOT_APPLICABLE
    proposal_z_mix_ratio = actual_z_mix_ratio
    maximum_attempts = 2
    evaluate_z_candidate =
        proposed_z -> _outer_iteration_candidate(
            config,
            representation,
            mmn,
            plan,
            weights,
            included_bands,
            outer_indices,
            frozen_indices,
            num_wannier,
            proposed_z,
            frames,
            centers,
            spreads,
            actual_u_mix_ratio,
            projector_covariance_tolerance,
            tangent_plans,
            (state.effective_controls.objectives.num_iter > 0) &&
            (optimizer_phase == :localization),
            effective_algorithms.localization,
            geometry = geometry,
            dot_workspace = dot_workspace,
            accepted_evaluation = accepted_evaluation,
            fixed_stage_subspaces = freeze_z ? sealed_subspace_frames : nothing,
            fixed_stage_projectors = freeze_z ? sealed_subspace_projectors : nothing,
            # Preserve the accepted fixed-stage gauge and transport protections.
            localization_reference_frames = nothing,
            spectrum_audit = spectrum_audit,
            iteration = iteration,
            # Carry the FR history within its accepted fixed subspace.
            previous_u_gradient = previous_u_gradient,
            previous_u_direction = previous_u_direction,
            u_cg_iteration = u_cg_iteration,
            u_cg_restart_count = u_cg_restart_count,
            u_branch_signature = u_branch_signature,
            recursive_localization_overlaps = recursive_localization_overlaps,
            recursive_localization_omega_i = recursive_localization_omega_i,
            recursive_localization_unitaries = recursive_localization_unitaries,
        )
    for attempt in 1:maximum_attempts
        linear_z =
            freeze_z ? deepcopy(something(z_previous)) :
            _mix_z_fields(z_raw, z_previous, proposal_z_mix_ratio)
        linear_z =
            !freeze_z && apply_symmetry && config.solver.symmetrize_z ?
            _symmetrize_hermitian_field(linear_z, representation) : linear_z
        trial_z = linear_z
        anderson_used = false
        anderson_fallback = false
        anderson_reason = freeze_z ? :FROZEN_SUBSPACE : :NOT_APPLICABLE
        anderson_context = Dict{String, String}()
        candidate = evaluate_z_candidate(trial_z)
        _record_hermitian_spectrum_audit!(input_summary, spectrum_audit)
        if !candidate.success
            context = Dict("iteration" => string(iteration))
            for field in (
                :kpoint,
                :sweep,
                :rank,
                :condition,
                :invariant_residual,
                :source_representative,
                :completion_count,
                :completion_singular_values,
                :completion_condition,
                :maximum_condition,
                :candidate_count,
                :maximum_combinations,
                :maximum_local_isometry_residual,
                :maximum_local_projector_drift,
                :maximum_local_residual_representative,
                :maximum_local_retained_rank,
                :maximum_local_missing_rank,
                :worst_selected_isometry_residual,
                :worst_active_gram_residual,
                :worst_remaining_projector_idempotence_residual,
                :worst_remaining_active_annihilation_residual,
                :worst_completion_isometry_residual,
                :worst_completion_containment_residual,
                :worst_completion_cross_residual,
                :worst_target_complement_basis_isometry_residual,
                :target_unitarity_residual,
                :sewing_isometry_residual,
                :singular_values,
                :backtracking_steps,
                :attempted_step_scales,
                :attempted_objectives,
                :attempted_required_changes,
                :attempted_actual_changes,
                :attempted_directional_derivatives,
                :directional_derivative,
                :fixed_projector_drift,
                :spectral_backend,
                :spectral_gap,
                :old_objective,
                :base_objective,
                :trial_zero_objective,
                :trial_zero_frame_residual,
                :minimum_diagonal_phase_margin,
                :minimum_phase_kpoint,
                :minimum_phase_neighbor,
                :minimum_phase_wannier,
                :minimum_phase_value,
                :branch_safe_backtracking_triggered,
                :cg_beta,
                :cg_restarted,
                :cg_restart_reason,
                :cg_descent_cosine,
                :kstar_gradient_rms,
                :maximum_kstar_gradient_rms,
                :maximum_kstar_gradient_index,
                :raw_eigenphases,
                :aligned_eigenphases,
                :acceptance_failure,
            )
                hasproperty(candidate, field) || continue
                value = getproperty(candidate, field)
                context[String(field)] =
                    value isa AbstractVector ? join(string.(value), ",") : string(value)
            end
            push!(
                diagnostics,
                WannierizationDiagnostic(candidate.code, :error, candidate.message; context),
            )
            if hasproperty(candidate, :minimum_diagonal_phase_margin)
                minimum_localization_diagonal_phase_margin = min(
                    minimum_localization_diagonal_phase_margin,
                    candidate.minimum_diagonal_phase_margin,
                )
                input_summary["minimum_localization_diagonal_phase_margin"] =
                    string(minimum_localization_diagonal_phase_margin)
            end
            rank_failure =
                candidate.code == :SUBSPACE_SELECTION_FAILED ||
                occursin("SINGULAR", String(candidate.code)) ||
                occursin("RANK_DEFICIENT", String(candidate.code))
            status = rank_failure ? SINGULAR_LOCALIZATION : LOCALIZATION_FAILED
            # A failed Z/U proposal never becomes an accepted checkpoint
            # boundary.  In particular, joint must discard both its trial
            # Z and the derived F0; two-stage must likewise retain the
            # previous committed frame.  Trial objectives remain durable
            # diagnostics in the optimizer state below.
            accepted_boundary = something(latest_restart_state)
            retained_frames = _restart_matrix_field(accepted_boundary.frames)
            retained_centers = copy(accepted_boundary.centers_cartesian)
            retained_spreads = copy(accepted_boundary.spreads_angstrom2)
            hasproperty(candidate, :attempted_step_scales) &&
                append!(localization_trial_step_scales, candidate.attempted_step_scales)
            hasproperty(candidate, :attempted_objectives) &&
                append!(localization_trial_objectives, candidate.attempted_objectives)
            hasproperty(candidate, :attempted_required_changes) &&
                append!(localization_trial_required_changes, candidate.attempted_required_changes)
            hasproperty(candidate, :attempted_actual_changes) &&
                append!(localization_trial_actual_changes, candidate.attempted_actual_changes)
            hasproperty(candidate, :attempted_directional_derivatives) && append!(
                localization_trial_directional_derivatives,
                candidate.attempted_directional_derivatives,
            )
            attempted_count =
                hasproperty(candidate, :attempted_step_scales) ?
                length(candidate.attempted_step_scales) : 0
            append!(localization_trial_iterations, fill(iteration, attempted_count))
            append!(
                localization_trial_sweeps,
                hasproperty(candidate, :attempted_sweeps) ? candidate.attempted_sweeps :
                fill(0, attempted_count),
            )
            append!(
                localization_trial_accepted,
                hasproperty(candidate, :attempted_accepted) ? candidate.attempted_accepted :
                falses(attempted_count),
            )
            hasproperty(candidate, :fixed_projector_drift) &&
                push!(localization_projector_drift_history, candidate.fixed_projector_drift)
            failure_optimizer = WannierizationOptimizerState(
                config.solver.acceleration.strategy,
                actual_z_mix_ratio,
                actual_u_mix_ratio,
                improvement_streak,
                rejected_steps,
                residual_reference,
                previous_merit,
                optimizer_phase,
                z_stability_count,
                u_stability_count,
                z_steps,
                u_steps,
                epoch,
                last_accepted_u_step_scale,
                gradient_fallback_active,
                gradient_steps,
                _pack_matrix_field(best_polar_frames),
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
                _pack_matrix_field(something(previous_u_gradient)),
                previous_u_direction === nothing ? zeros(ComplexF64, 0, 0, 0) :
                _pack_matrix_field(something(previous_u_direction)),
                u_cg_iteration,
                u_cg_restart_count,
                last_cg_beta,
                last_cg_restart_reason,
                last_anderson_reason,
                LOCALIZATION_GRADIENT_CONTRACT,
                u_active_orbit_count,
                u_generalized_gradient_rms,
                last_u_optimizer_restart_reason,
                recursive_localization_overlaps === nothing ? zeros(ComplexF64, 0, 0, 0, 0) :
                something(recursive_localization_overlaps),
                recursive_localization_unitaries === nothing ? zeros(ComplexF64, 0, 0, 0) :
                _pack_matrix_field(something(recursive_localization_unitaries)),
                something(recursive_localization_omega_i, NaN),
                u_branch_signature,
            )
            failure_restart = WannierizationRestartState(
                accepted_boundary.iteration,
                copy(accepted_boundary.frames),
                accepted_boundary.z_previous === nothing ? nothing :
                copy(something(accepted_boundary.z_previous)),
                retained_centers,
                retained_spreads,
                copy(accepted_boundary.convergence_values),
                copy(accepted_boundary.included_bands),
                prior_elapsed + (time_ns() - started_ns) / 1.0e9,
                accepted_boundary.stencil,
                failure_optimizer,
                accepted_boundary.fixed_subspace_projectors === nothing ? nothing :
                copy(something(accepted_boundary.fixed_subspace_projectors)),
                accepted_boundary.fixed_subspace_frames === nothing ? nothing :
                copy(something(accepted_boundary.fixed_subspace_frames)),
                accepted_boundary.localization_initial_frames === nothing ? nothing :
                copy(something(accepted_boundary.localization_initial_frames)),
                accepted_boundary.input_definition,
            )
            return _failure_result(
                status,
                diagnostics,
                input_summary;
                frames = retained_frames,
                centers = retained_centers,
                spreads = retained_spreads,
                history,
                restart_state = failure_restart,
                representation,
                last_attempted_iteration = iteration,
                hard_gate_residuals = _accepted_state_structural_residuals(
                    retained_frames,
                    frozen_indices,
                    representation,
                    plan,
                    apply_symmetry,
                ),
                initialization_report,
            )
        end
        candidate_frames = candidate.frames
        candidate_centers = candidate.centers
        candidate_spreads = candidate.spreads
        spread_total = sum(candidate_spreads)
        candidate_value = vcat(vec(candidate_centers), candidate_spreads)
        candidate_convergence = vcat(convergence_values, [candidate_value])
        recent = candidate_convergence[max(
            1,
            end - max(2, state.effective_controls.objectives.conv_window) + 1,
        ):end]
        spread_std = maximum(
            _population_standard_deviation([value[index] for value in recent]) for
            index in eachindex(last(recent))
        )
        covariance_error =
            apply_symmetry ? _maximum_projector_covariance_error(candidate_frames, representation) :
            0.0
        projector_residual = _maximum_projector_step(frames, candidate_frames)
        wcc_step = _maximum_wcc_step(centers, candidate_centers, representation.real_lattice)
        spread_step = maximum(abs, candidate_spreads - spreads)
        residuals = (projector_residual, z_residual, candidate.u_residual, spread_std)
        trial_reference = ntuple(
            index ->
                residuals[index] === nothing ? nothing :
                residual_reference[index] !== nothing &&
                isfinite(residual_reference[index]) &&
                abs(residual_reference[index]) > eps(Float64) ? residual_reference[index] :
                abs(residuals[index]) > eps(Float64) ? abs(residuals[index]) : NaN,
            4,
        )
        merit = maximum(
            trial_reference[index] !== nothing && isfinite(trial_reference[index]) ?
            abs(residuals[index]) / abs(trial_reference[index]) : 0.0 for index in 1:4
        )
        invariant_failure = _candidate_invariant_failure(
            candidate_frames,
            candidate_centers,
            candidate_spreads,
            frozen_indices,
            representation,
            plan,
            config.input.representation_tolerance,
            projector_covariance_tolerance,
            apply_symmetry;
            construction_policy = config.input.construction_policy,
        )
        joint_failure = invariant_failure
        if joint_failure !== nothing
            code, residual = something(joint_failure)
            push!(
                diagnostics,
                WannierizationDiagnostic(
                    code,
                    :error,
                    "fixed step violated a hard solver invariant";
                    context = Dict(
                        "iteration" => string(iteration),
                        "residual" => string(residual),
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
                hard_gate_residuals = _candidate_invariant_residuals(
                    frames,
                    frozen_indices,
                    representation,
                ),
                initialization_report,
            )
        end
        accepted = merge(
            candidate,
            (
                spread_total = spread_total,
                spread_std = spread_std,
                covariance_error = covariance_error,
                projector_residual = projector_residual,
                wcc_step = wcc_step,
                spread_step = spread_step,
                z_boundary_gap = NaN,
            ),
        )
        accepted_z = trial_z
        accepted_merit = merit
        accepted_reference = trial_reference
        accepted_anderson_used = anderson_used
        accepted_anderson_fallback = anderson_fallback
        accepted_anderson_reason = anderson_reason
        accepted_anderson_context = anderson_context
        accepted_joint_z_backtracking_steps = 0
        accepted_joint_transport_minimum_singular_value = candidate.transport_minimum_singular_value
        accepted_joint_transport_maximum_condition = candidate.transport_maximum_condition
        accepted_joint_reason = :NOT_APPLICABLE
        break
    end
    return (;
        effective_controls = state.effective_controls,
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
        accepted_z,
        actual_u_mix_ratio,
        actual_z_mix_ratio,

        apply_symmetry,

        best_polar_centers,
        best_polar_frames,
        best_polar_objective,
        best_polar_spreads,
        compatibility,
        config,

        convergence_values,
        retained_disentanglement_nonconverged,
        diagnostics,
        disentanglement_objective_history,
        effective_algorithms,
        effective_compatibility_policy,
        epoch,
        frozen_indices,
        full_constraint_scope,
        gradient_fallback_active,
        gradient_steps,
        history,
        improvement_streak,
        included_bands,
        initialization_report,
        input_summary,
        irreducible,
        iteration,
        iteration_phase,
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
        two_stage_complete,
        u_stability_count,
        u_steps,
        recursive_localization_omega_i,
        recursive_localization_overlaps,
        recursive_localization_unitaries,
        weights,
        z_residual,
        z_stability_count,
        z_steps,
    )
end
