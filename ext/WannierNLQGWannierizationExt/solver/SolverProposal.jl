# Evaluate safeguarded Z/U proposals without committing a rejected trial.
function _propose_solver_iteration(state::NamedTuple)
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
    ) = state
    iteration_phase = optimizer_phase
    irreducible = representation.irreducible_indices
    freeze_z =
        fixed_mode ||
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
            wannier90_reference = effective_algorithms.disentanglement ==
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
    accepted_z_history = anderson_z_history
    accepted_residual_history = anderson_residual_history
    accepted_anderson_used = false
    accepted_anderson_fallback = false
    accepted_anderson_reason = :NOT_APPLICABLE
    accepted_anderson_context = Dict{String, String}()
    accepted_joint_z_backtracking_steps = 0
    accepted_joint_transport_minimum_singular_value = NaN
    accepted_joint_transport_maximum_condition = NaN
    accepted_joint_reason = :NOT_APPLICABLE
    joint_mode = config.solver.acceleration.schedule == :joint && !freeze_z
    joint_base_omega_i = joint_mode ? _gauge_invariant_spread(frames, mmn, weights) : NaN
    proposal_z_mix_ratio = actual_z_mix_ratio
    maximum_attempts =
        joint_mode ? config.solver.acceleration.joint_z_backtracking_max_steps + 1 : 2
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
            config.solver.localize && (
                config.solver.acceleration.schedule in (:joint, :fixed_subspace) ||
                optimizer_phase == :localization
            ),
            effective_algorithms.localization,
            fixed_stage_subspaces = freeze_z ? sealed_subspace_frames : nothing,
            fixed_stage_projectors = freeze_z ? sealed_subspace_projectors : nothing,
            # A moving joint subspace is transported from the previous
            # accepted frame by F0 = S*polar(S'*F_old) inside
            # `_localization_sweeps`. Re-aligning it to raw AMN here would
            # discard the accepted gauge and can make the first joint step
            # rank deficient.
            localization_reference_frames = nothing,
            spectrum_audit = spectrum_audit,
            iteration = iteration,
            # RCG history is a tangent in a fixed subspace. Joint changes
            # that subspace transactionally, so cross-subspace history is
            # deliberately cleared until vector transport is qualified.
            previous_u_gradient = joint_mode ? nothing : previous_u_gradient,
            previous_u_direction = joint_mode ? nothing : previous_u_direction,
            u_cg_iteration = joint_mode ? 0 : u_cg_iteration,
            u_cg_restart_count = u_cg_restart_count,
            u_lbfgs_s_history = joint_mode ? Vector{Vector{Matrix{ComplexF64}}}() :
                                u_lbfgs_s_history,
            u_lbfgs_y_history = joint_mode ? Vector{Vector{Matrix{ComplexF64}}}() :
                                u_lbfgs_y_history,
            u_lbfgs_rho_history = joint_mode ? Float64[] : u_lbfgs_rho_history,
            u_lbfgs_restart_count = u_lbfgs_restart_count,
            u_branch_signature = joint_mode ? "" : u_branch_signature,
            wannier90_reference_overlaps = joint_mode ? nothing : wannier90_reference_overlaps,
            wannier90_reference_omega_i = joint_mode ? nothing : wannier90_reference_omega_i,
            wannier90_reference_unitaries = joint_mode ? nothing : wannier90_reference_unitaries,
        )
    for attempt in 1:maximum_attempts
        linear_z =
            freeze_z ? deepcopy(something(z_previous)) :
            _mix_z_fields(z_raw, z_previous, proposal_z_mix_ratio)
        linear_z =
            !freeze_z && apply_symmetry && config.solver.symmetrize_z ?
            _symmetrize_hermitian_field(linear_z, representation) : linear_z
        # The boundary gap exists solely to safeguard Anderson-Z.  It is
        # not part of fixed/adaptive U acceptance and must not repeatedly
        # diagonalize an unchanged Z field during two-stage localization.
        z_boundary_gap =
            !freeze_z && config.solver.acceleration.strategy == :anderson_z ?
            _minimum_z_boundary_gap(
                linear_z,
                outer_indices,
                irreducible,
                num_wannier;
                tolerance = config.solver.numerical_thresholds.hermitian_residual_rtol,
                audit = spectrum_audit,
            ) : NaN
        trial_z = linear_z
        trial_z_history = anderson_z_history
        trial_residual_history = anderson_residual_history
        anderson_used = false
        anderson_fallback = false
        anderson_reason =
            config.solver.acceleration.strategy == :anderson_z ? :BEFORE_START : :NOT_APPLICABLE
        anderson_context = Dict{String, String}()
        proposal_evidence = nothing
        allow_anderson, reset_anderson_history = _anderson_trial_policy(
            config.solver.acceleration.strategy,
            attempt,
            iteration,
            config.solver.acceleration.anderson_start_iteration,
            z_previous !== nothing,
            z_boundary_gap,
            config.input.representation_tolerance,
        )
        if freeze_z
            allow_anderson = false
            reset_anderson_history = false
            anderson_reason = :FROZEN_SUBSPACE
        elseif attempt > 1 && config.solver.acceleration.strategy == :anderson_z
            anderson_reason = :SAFE_LINEAR_RETRY
        end
        if reset_anderson_history
            trial_z_history = zeros(Float64, 0, 0)
            trial_residual_history = zeros(Float64, 0, 0)
            anderson_fallback = true
            anderson_reason = :BOUNDARY_GAP_RESET
        elseif allow_anderson
            proposal_evidence = _anderson_z_proposal(
                z_raw,
                something(z_previous),
                linear_z,
                outer_indices,
                irreducible,
                anderson_z_history,
                anderson_residual_history,
                config.solver.acceleration,
            )
            trial_z_history = proposal_evidence.z_history
            trial_residual_history = proposal_evidence.residual_history
            anderson_reason = proposal_evidence.reason
            anderson_fallback = !proposal_evidence.available
            trial_z = proposal_evidence.proposal
            trial_z =
                apply_symmetry && config.solver.symmetrize_z ?
                _symmetrize_hermitian_field(trial_z, representation) : trial_z
            anderson_context["coefficient_norm"] = string(proposal_evidence.coefficient_norm)
            anderson_context["linear_z_residual"] = string(proposal_evidence.linear_residual)
            anderson_context["anderson_z_residual"] = string(proposal_evidence.proposal_residual)
        end
        candidate = evaluate_z_candidate(trial_z)
        if candidate.success &&
           effective_algorithms.disentanglement == :grassmann_trust_region &&
           iteration_phase == :disentanglement &&
           !freeze_z
            trust_step = _grassmann_trust_region_step(
                frames,
                candidate.subspaces,
                grassmann_trust_radius,
                outer_indices,
                frozen_indices,
                num_wannier,
                representation,
                plan,
                config,
            )
            trust_step.success || return _failure_result(
                LOCALIZATION_FAILED,
                [
                    WannierizationDiagnostic(
                        trust_step.code,
                        :error,
                        "Grassmann trust-region retraction failed";
                        context = Dict("iteration" => string(iteration)),
                    ),
                ],
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
            base_omega = _gauge_invariant_spread(frames, mmn, weights)
            proposal_omega = _gauge_invariant_spread(candidate.subspaces, mmn, weights)
            trial_omega = _gauge_invariant_spread(trust_step.frames, mmn, weights)
            predicted_decrease =
                max(eps(Float64), trust_step.alpha * max(0.0, base_omega - proposal_omega))
            actual_decrease = base_omega - trial_omega
            trust_ratio = actual_decrease / predicted_decrease
            projector_change = _maximum_projector_step(frames, trust_step.frames)
            push!(grassmann_predicted_decrease_history, predicted_decrease)
            push!(grassmann_actual_decrease_history, actual_decrease)
            push!(grassmann_ratio_history, trust_ratio)
            push!(grassmann_radius_history, grassmann_trust_radius)
            push!(grassmann_gradient_history, trust_step.maximum_angle)
            push!(grassmann_projector_change_history, projector_change)
            for (name, values) in (
                ("grassmann_predicted_decrease_history", grassmann_predicted_decrease_history),
                ("grassmann_actual_decrease_history", grassmann_actual_decrease_history),
                ("grassmann_acceptance_ratio_history", grassmann_ratio_history),
                ("grassmann_trust_radius_history", grassmann_radius_history),
                ("grassmann_gradient_history", grassmann_gradient_history),
                ("grassmann_projector_change_history", grassmann_projector_change_history),
            )
                input_summary[name] = join(string.(values), ",")
            end
            accepted_trust =
                isfinite(trust_ratio) &&
                actual_decrease >= 0.0 &&
                trust_ratio >= config.solver.acceleration.trust_acceptance_threshold
            if trust_ratio < config.solver.acceleration.trust_shrink_threshold
                grassmann_trust_radius *= 0.25
            elseif trust_ratio > config.solver.acceleration.trust_expand_threshold &&
                   trust_step.alpha < 1.0
                grassmann_trust_radius = min(
                    config.solver.acceleration.trust_radius_maximum,
                    2.0 * grassmann_trust_radius,
                )
            end
            accepted_frames = accepted_trust ? trust_step.frames : frames
            trust_candidate = _disentanglement_candidate(
                config,
                representation,
                mmn,
                plan,
                weights,
                frozen_indices,
                accepted_frames,
                centers,
                spreads,
                projector_covariance_tolerance,
            )
            candidate = merge(
                trust_candidate,
                (
                    subspaces = accepted_frames,
                    raw_amn_alignment_applied = false,
                    raw_amn_alignment_minimum_singular_value = NaN,
                    raw_amn_alignment_maximum_condition = NaN,
                    raw_amn_alignment_projector_drift = NaN,
                    raw_amn_alignment_completion_count = 0,
                    localization_initial_frames = nothing,
                ),
            )
            input_summary["grassmann_trust_last_acceptance"] =
                accepted_trust ? "ACCEPTED" : "REJECTED"
            input_summary["grassmann_trust_last_ratio"] = string(trust_ratio)
            input_summary["grassmann_trust_current_radius"] = string(grassmann_trust_radius)
        end
        if proposal_evidence !== nothing && proposal_evidence.available
            linear_candidate = evaluate_z_candidate(linear_z)
            safeguard = _objective_aware_anderson_accepts(
                linear_candidate,
                candidate,
                frames,
                mmn,
                weights,
                proposal_evidence.linear_residual,
                proposal_evidence.proposal_residual,
                config.solver.acceleration,
            )
            for (name, value) in (
                ("omega_linear", safeguard.omega_linear),
                ("omega_anderson", safeguard.omega_anderson),
                ("projector_linear", safeguard.projector_linear),
                ("projector_anderson", safeguard.projector_anderson),
            )
                anderson_context[name] = string(value)
            end
            if safeguard.accepted
                anderson_used = true
                anderson_fallback = false
                anderson_reason = safeguard.reason
            else
                candidate = linear_candidate
                trial_z = linear_z
                anderson_used = false
                anderson_fallback = true
                anderson_reason = safeguard.reason
            end
        end
        _record_hermitian_spectrum_audit!(input_summary, spectrum_audit)
        if !candidate.success
            if joint_mode && attempt < maximum_attempts
                rejected_steps += 1
                proposal_z_mix_ratio *= config.solver.acceleration.joint_z_backtracking_factor
                continue
            end
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
                accepted_boundary.config_sha256,
                accepted_boundary.representation_sha256,
                accepted_boundary.stencil,
                accepted_boundary.projection_basis_sha256,
                accepted_boundary.amn_sha256,
                failure_optimizer,
                accepted_boundary.fixed_subspace_projectors === nothing ? nothing :
                copy(something(accepted_boundary.fixed_subspace_projectors)),
                accepted_boundary.fixed_subspace_frames === nothing ? nothing :
                copy(something(accepted_boundary.fixed_subspace_frames)),
                accepted_boundary.localization_initial_frames === nothing ? nothing :
                copy(something(accepted_boundary.localization_initial_frames)),
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
        recent = candidate_convergence[max(1, end - config.solver.convergence_window + 1):end]
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
                isfinite(residual_reference[index]) &&
                abs(residual_reference[index]) > eps(Float64) ? residual_reference[index] :
                abs(residuals[index]) > eps(Float64) ? abs(residuals[index]) : NaN,
            4,
        )
        merit = maximum(
            isfinite(trial_reference[index]) ?
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
        candidate_omega_i = _gauge_invariant_spread(candidate_frames, mmn, weights)
        omega_i_tolerance = max(
            config.solver.acceleration.disentanglement_objective_tolerance,
            64 * eps(Float64) * max(abs(joint_base_omega_i), abs(candidate_omega_i), 1.0),
        )
        joint_gauge_invariance_residual =
            joint_mode ? abs(candidate_omega_i - candidate.transported_omega_i) : 0.0
        joint_objective_failure =
            if joint_mode && candidate_omega_i > joint_base_omega_i + omega_i_tolerance
                (:JOINT_Z_OBJECTIVE_INCREASED, candidate_omega_i - joint_base_omega_i)
            elseif joint_mode && joint_gauge_invariance_residual > omega_i_tolerance
                (:JOINT_U_CHANGED_OMEGA_I, joint_gauge_invariance_residual)
            else
                nothing
            end
        joint_failure = invariant_failure === nothing ? joint_objective_failure : invariant_failure
        if joint_mode && joint_failure !== nothing && attempt < maximum_attempts
            rejected_steps += 1
            proposal_z_mix_ratio *= config.solver.acceleration.joint_z_backtracking_factor
            continue
        end
        action =
            _acceleration_trial_action(config.solver.acceleration.strategy, attempt, joint_failure)
        if action == :retry_safe_linear
            rejected_steps += 1
            actual_z_mix_ratio, actual_u_mix_ratio = _shrunken_acceleration_mixing(
                actual_z_mix_ratio,
                actual_u_mix_ratio,
                config.solver.acceleration,
            )
            anderson_z_history =
                invariant_failure === nothing ? anderson_z_history : zeros(Float64, 0, 0)
            anderson_residual_history =
                invariant_failure === nothing ? anderson_residual_history : zeros(Float64, 0, 0)
            continue
        elseif action == :typed_failure
            code, residual = something(joint_failure)
            push!(
                diagnostics,
                WannierizationDiagnostic(
                    code,
                    :error,
                    joint_mode ?
                    "transactional joint step violated a hard invariant or Omega_I safeguard after Z backtracking" :
                    config.solver.acceleration.strategy == :fixed ?
                    "fixed step violated a hard solver invariant" :
                    "accelerated step violated a hard invariant after one rollback";
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
                z_boundary_gap = z_boundary_gap,
            ),
        )
        accepted_z = trial_z
        accepted_merit = merit
        accepted_reference = trial_reference
        accepted_z_history = trial_z_history
        accepted_residual_history = trial_residual_history
        accepted_anderson_used = anderson_used
        accepted_anderson_fallback = anderson_fallback
        accepted_anderson_reason = anderson_reason
        accepted_anderson_context = anderson_context
        accepted_joint_z_backtracking_steps = joint_mode ? attempt - 1 : 0
        accepted_joint_transport_minimum_singular_value = candidate.transport_minimum_singular_value
        accepted_joint_transport_maximum_condition = candidate.transport_maximum_condition
        accepted_joint_reason =
            joint_mode ? (attempt == 1 ? :JOINT_ACCEPTED : :JOINT_ACCEPTED_AFTER_Z_BACKTRACKING) :
            :NOT_APPLICABLE
        break
    end
    return (;
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
    )
end
