# A loop decision owns a concrete accepted-state record; array fields retain their
# original ownership and are never copied merely to cross a stage boundary.
struct SolverIterationDecision{S <: NamedTuple}
    stop::Bool
    state::S
end

# A failed Z trial may still leave a computable accepted subspace. Reuse the
# normal stage seal and keep both the failed trial and continuation decision.
function _continue_failed_disentanglement(
    state::NamedTuple,
    failure::WannierizationResult,
    iteration::Int,
)
    config = state.config
    validate_ordinary_construction_policy(config.input.construction_policy)
    config.solver.acceleration.schedule == :two_stage &&
    (state.effective_controls.objectives.num_iter > 0) &&
    state.optimizer_phase == :disentanglement &&
    state.latest_restart_state !== nothing || return failure
    retained = something(state.latest_restart_state)
    # Identity failures cannot be converted into a numerical continuation.
    any(failure.diagnostics) do diagnostic
        any(
            token -> occursin(token, String(diagnostic.code)),
            ("SHA256", "CHECKPOINT", "RESTART", "IDENTITY", "PROVENANCE", "REFERENCE_MISMATCH"),
        )
    end && return failure
    frames = _restart_matrix_field(retained.frames)
    centers = copy(retained.centers_cartesian)
    spreads = copy(retained.spreads_angstrom2)
    z_previous = state.z_previous
    if z_previous === nothing
        full_field = _raw_z_field(
            state.representation,
            state.mmn,
            state.weights,
            state.outer_indices,
            frames,
            config.solver.parallel;
            full_bz = state.apply_symmetry,
            storage_backend = config.solver.acceleration.hot_storage_backend,
            recursive_localization = state.effective_algorithms.disentanglement ==
                                     :smv_fletcher_reeves_two_stage,
        )
        z_previous =
            state.apply_symmetry ?
            _reduce_full_star_hermitian_field(full_field, state.representation) : full_field
    end
    qualification = _qualify_nonconverged_disentanglement_state(
        frames,
        z_previous,
        centers,
        spreads,
        state.frozen_indices,
        state.representation,
        state.plan,
        config.input.representation_tolerance,
        state.projector_covariance_tolerance,
        state.apply_symmetry;
        construction_policy = :standard,
    )
    qualification.qualified || return failure
    diagnostics = WannierizationDiagnostic[state.diagnostics...]
    for diagnostic in failure.diagnostics
        diagnostic in diagnostics || push!(diagnostics, diagnostic)
    end
    push!(
        diagnostics,
        WannierizationDiagnostic(
            :DISENTANGLEMENT_FAILED_TRIAL_CONTINUED_STANDARD,
            :warning,
            "failed Z trial retained the last accepted subspace for diagnostic U optimization";
            context = Dict(
                "stage" => "Z_to_U",
                "gate_result" => "FAIL",
                "action" => "CONTINUE_STANDARD",
                "failed_status" => string(failure.status),
                "last_accepted_iteration" => string(retained.iteration),
            ),
        ),
    )
    input_summary = copy(state.input_summary)
    merge!(
        input_summary,
        Dict(
            "disentanglement_convergence" => "NONCONVERGED_RETAINED",
            "z_seal_class" => "NONCONVERGED_RETAINED",
            "localization_qualification" => "STANDARD",
            "model_qualification" => "AVAILABLE_WITH_QUALITY_WARNINGS",
            "construction_quality_failed" => "true",
        ),
    )
    boundary = merge(
        state,
        (;
            frames,
            centers,
            spreads,
            z_previous,
            diagnostics,
            input_summary,
            iteration,
            standard_transition = true,
            projector_residual = 0.0,
            omega_i = _gauge_invariant_spread(frames, state.mmn, state.weights),
        ),
    )
    seal = _seal_solver_disentanglement_state(boundary)
    seal isa WannierizationResult && return seal
    next = merge(boundary, seal, (; retained_disentanglement_nonconverged = true))
    invariant_failure = _candidate_invariant_failure(
        next.frames,
        next.centers,
        next.spreads,
        next.frozen_indices,
        next.representation,
        next.plan,
        config.input.representation_tolerance,
        next.projector_covariance_tolerance,
        next.apply_symmetry;
        construction_policy = :standard,
    )
    invariant_failure === nothing || return failure
    # Persist the sealed boundary before a U trial can fail. This is a gauge
    # transition of the accepted state and does not increment accepted Z steps.
    replacements = (;
        phase = :localization,
        u_stability_count = 0,
        previous_u_gradient = zeros(ComplexF64, 0, 0, 0),
        previous_u_direction = zeros(ComplexF64, 0, 0, 0),
        u_cg_iteration = 0,
        last_cg_beta = NaN,
        last_cg_restart_reason = :STAGE_BOUNDARY_RESET,
        recursive_localization_overlaps = next.recursive_localization_overlaps === nothing ?
                                          zeros(ComplexF64, 0, 0, 0, 0) :
                                          next.recursive_localization_overlaps,
        recursive_localization_unitaries = next.recursive_localization_unitaries === nothing ?
                                           zeros(ComplexF64, 0, 0, 0) :
                                           _pack_matrix_field(
            next.recursive_localization_unitaries,
        ),
        recursive_localization_omega_i = something(next.recursive_localization_omega_i, NaN),
    )
    old_optimizer = retained.optimizer_state
    optimizer = WannierizationOptimizerState(
        (
            haskey(replacements, name) ? getproperty(replacements, name) :
            getfield(old_optimizer, name) for name in fieldnames(WannierizationOptimizerState)
        )...,
    )
    latest_restart_state = _restart_state(
        retained.iteration,
        next.frames,
        z_previous,
        next.centers,
        next.spreads,
        next.convergence_values,
        next.included_bands,
        retained.elapsed_seconds,
        retained.stencil,
        optimizer;
        fixed_subspace_projectors = next.sealed_subspace_projectors,
        fixed_subspace_frames = next.sealed_subspace_frames,
        localization_initial_frames = next.localization_initial_frames,
        input_definition = retained.input_definition,
    )
    input_summary["optimizer_phase"] = "localization"
    return merge(next, (; latest_restart_state))
end

# Seal an initialized subspace without manufacturing an accepted Z iteration.
function _skip_initial_disentanglement(state::NamedTuple, reason::String)
    z_previous = state.z_previous
    if z_previous === nothing
        field = _raw_z_field(
            state.representation,
            state.mmn,
            state.weights,
            state.outer_indices,
            state.frames,
            state.config.solver.parallel;
            full_bz = state.apply_symmetry,
            storage_backend = state.config.solver.acceleration.hot_storage_backend,
            recursive_localization = state.effective_algorithms.disentanglement ==
                                     :smv_fletcher_reeves_two_stage,
        )
        z_previous =
            state.apply_symmetry ? _reduce_full_star_hermitian_field(field, state.representation) :
            field
    end
    boundary = merge(
        state,
        (;
            z_previous,
            iteration = state.start_iteration-1,
            omega_i = _gauge_invariant_spread(state.frames, state.mmn, state.weights),
            projector_residual = 0.0,
            standard_transition = true,
        ),
    )
    seal = _seal_solver_disentanglement_state(boundary)
    seal isa WannierizationResult && return seal
    next = merge(boundary, seal)
    next.input_summary["disentanglement_convergence"] = reason
    next.input_summary["z_seal_class"] = reason
    next.input_summary["disentanglement_state_converged"] = "false"
    retained = something(state.latest_restart_state)
    replacements = (;
        phase = next.optimizer_phase,
        u_stability_count = 0,
        recursive_localization_overlaps = next.recursive_localization_overlaps === nothing ?
                                          zeros(ComplexF64, 0, 0, 0, 0) :
                                          next.recursive_localization_overlaps,
        recursive_localization_unitaries = next.recursive_localization_unitaries === nothing ?
                                           zeros(ComplexF64, 0, 0, 0) :
                                           _pack_matrix_field(
            next.recursive_localization_unitaries,
        ),
        recursive_localization_omega_i = something(next.recursive_localization_omega_i, NaN),
    )
    old = retained.optimizer_state
    optimizer = WannierizationOptimizerState(
        (
            haskey(replacements, name) ? getproperty(replacements, name) : getfield(old, name)
            for name in fieldnames(WannierizationOptimizerState)
        )...,
    )
    latest_restart_state = _restart_state(
        retained.iteration,
        next.frames,
        z_previous,
        next.centers,
        next.spreads,
        next.convergence_values,
        next.included_bands,
        retained.elapsed_seconds,
        retained.stencil,
        optimizer;
        fixed_subspace_projectors = next.sealed_subspace_projectors,
        fixed_subspace_frames = next.sealed_subspace_frames,
        localization_initial_frames = next.localization_initial_frames,
        input_definition = retained.input_definition,
    )
    return merge(next, (; latest_restart_state))
end

# Run one proposal and acceptance transaction before testing termination.
function _run_solver_iterations(state::NamedTuple)
    geometry = LocalizationGeometryWorkspace()
    dot_workspace = ReferenceDotWorkspace()
    accepted_evaluation = AcceptedReferenceEvaluationWorkspace()
    controls = state.effective_controls.objectives
    if controls !== nothing
        state.input_summary["disentanglement_steps"] = string(state.z_steps)
        state.input_summary["localization_steps"] = string(state.u_steps)
        if controls.dis_num_iter == 0 && controls.num_iter == 0
            state.input_summary["disentanglement_convergence"] = "SKIPPED_ZERO_STEPS"
            state.input_summary["localization_convergence"] = "SKIPPED_ZERO_STEPS"
            return state
        end
        no_free_z = all(
            k ->
                length(state.outer_indices[k]) == state.num_wannier ||
                length(state.frozen_indices[k]) == state.num_wannier,
            eachindex(state.outer_indices),
        )
        if state.optimizer_phase == :disentanglement && (controls.dis_num_iter == 0 || no_free_z)
            state = _skip_initial_disentanglement(
                state,
                no_free_z ? "NOT_APPLICABLE" : "SKIPPED_ZERO_STEPS",
            )
            state isa WannierizationResult && return state
        end
        controls.num_iter == 0 &&
            (state.input_summary["localization_convergence"] = "SKIPPED_ZERO_STEPS")
    end
    for iteration in state.start_iteration:state.effective_controls.total_iteration_budget
        controls !== nothing && state.optimizer_phase == :completed && break
        controls !== nothing &&
            state.optimizer_phase == :localization &&
            state.u_steps >= controls.num_iter &&
            break
        proposal = _propose_solver_iteration(
            merge(state, (; iteration));
            geometry,
            dot_workspace,
            accepted_evaluation,
        )
        if proposal isa WannierizationResult
            _discard_reference_evaluation!(accepted_evaluation)
            continued = _continue_failed_disentanglement(state, proposal, iteration)
            continued isa WannierizationResult && return continued
            state = continued
            proposal = _propose_solver_iteration(
                merge(state, (; iteration));
                geometry,
                dot_workspace,
                accepted_evaluation,
            )
            proposal isa WannierizationResult && return proposal
        end
        accepted = _accept_solver_iteration(proposal)
        if accepted isa WannierizationResult
            _discard_reference_evaluation!(accepted_evaluation)
            return accepted
        end
        decision = _finish_solver_iteration(accepted)
        if decision isa WannierizationResult
            _discard_reference_evaluation!(accepted_evaluation)
            return decision
        end
        state = decision.state
        if decision.stop || state.optimizer_phase != :localization
            _discard_reference_evaluation!(accepted_evaluation)
        else
            _publish_reference_evaluation!(accepted_evaluation)
        end
        decision.stop && break
    end
    return state
end
