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
    config.input.construction_policy == :diagnostic &&
    config.solver.acceleration.schedule == :two_stage &&
    config.solver.localize &&
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
            wannier90_reference = state.effective_algorithms.disentanglement ==
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
        construction_policy = :diagnostic,
    )
    qualification.qualified || return failure
    diagnostics = WannierizationDiagnostic[state.diagnostics...]
    for diagnostic in failure.diagnostics
        diagnostic in diagnostics || push!(diagnostics, diagnostic)
    end
    push!(
        diagnostics,
        WannierizationDiagnostic(
            :DISENTANGLEMENT_FAILED_TRIAL_CONTINUED_DIAGNOSTIC,
            :warning,
            "failed Z trial retained the last accepted subspace for diagnostic U optimization";
            context = Dict(
                "stage" => "Z_to_U",
                "gate_result" => "FAIL",
                "action" => "CONTINUE_DIAGNOSTIC",
                "failed_status" => string(failure.status),
                "last_accepted_iteration" => string(retained.iteration),
            ),
        ),
    )
    input_summary = copy(state.input_summary)
    merge!(
        input_summary,
        Dict(
            "disentanglement_convergence" => "DIAGNOSTIC_NONCONVERGED",
            "z_seal_class" => "DIAGNOSTIC_NONCONVERGED",
            "qualified_z_seal" => "false",
            "route_selection_eligible" => "false",
            "standard_tb_export_eligible" => "false",
            "localization_qualification" => "DIAGNOSTIC_ONLY",
            "model_qualification" => "DIAGNOSTIC_ONLY/Z_NONCONVERGED",
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
            diagnostic_transition = true,
            projector_residual = 0.0,
            omega_i = _gauge_invariant_spread(frames, state.mmn, state.weights),
        ),
    )
    seal = _seal_solver_disentanglement_state(boundary)
    seal isa WannierizationResult && return seal
    next = merge(boundary, seal, (; diagnostic_disentanglement_nonconverged = true))
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
        construction_policy = :diagnostic,
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
        wannier90_reference_overlaps = next.wannier90_reference_overlaps === nothing ?
                                       zeros(ComplexF64, 0, 0, 0, 0) :
                                       next.wannier90_reference_overlaps,
        wannier90_reference_unitaries = next.wannier90_reference_unitaries === nothing ?
                                        zeros(ComplexF64, 0, 0, 0) :
                                        cat(next.wannier90_reference_unitaries...; dims = 3),
        wannier90_reference_omega_i = something(next.wannier90_reference_omega_i, NaN),
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
        retained.config_sha256,
        retained.representation_sha256,
        retained.stencil,
        retained.projection_basis_sha256,
        retained.amn_sha256,
        optimizer;
        fixed_subspace_projectors = next.sealed_subspace_projectors,
        fixed_subspace_frames = next.sealed_subspace_frames,
        localization_initial_frames = next.localization_initial_frames,
    )
    input_summary["optimizer_phase"] = "localization"
    return merge(next, (; latest_restart_state))
end

# Run one proposal and acceptance transaction before testing termination.
function _run_solver_iterations(state::NamedTuple)
    for iteration in state.start_iteration:state.config.solver.max_iterations
        proposal = _propose_solver_iteration(merge(state, (; iteration)))
        if proposal isa WannierizationResult
            continued = _continue_failed_disentanglement(state, proposal, iteration)
            continued isa WannierizationResult && return continued
            state = continued
            proposal = _propose_solver_iteration(merge(state, (; iteration)))
            proposal isa WannierizationResult && return proposal
        end
        accepted = _accept_solver_iteration(proposal)
        accepted isa WannierizationResult && return accepted
        decision = _finish_solver_iteration(accepted)
        decision isa WannierizationResult && return decision
        state = decision.state
        decision.stop && break
    end
    return state
end
