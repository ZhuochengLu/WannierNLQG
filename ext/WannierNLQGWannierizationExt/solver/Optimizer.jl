# Compatibility wrapper retained for focused legacy tests. It now uses the
# same branch-safe SVD-polar geodesic as the production path.
function _mix_unitaries(
    old_unitary::Matrix{ComplexF64},
    new_unitary::Matrix{ComplexF64},
    ratio::Float64,
    tolerance::Float64,
)
    geodesic = _unitary_geodesic_plan(old_unitary, new_unitary, tolerance)
    geodesic.success || return nothing
    return _unitary_geodesic_step(old_unitary, geodesic, ratio, tolerance)
end

# Mix Z only after a previous iterate exists. The first update stores the
# freshly constructed Z unchanged and therefore has no projector
# contribution from the initialization frame.
function _mix_z_fields(
    raw::Vector{Matrix{ComplexF64}},
    previous::Union{Nothing, Vector{Matrix{ComplexF64}}},
    ratio::Float64,
)
    previous === nothing && return deepcopy(raw)
    length(raw) == length(previous) || throw(DimensionMismatch("Z field lengths differ"))
    return [ratio .* raw[kpoint] .+ (1.0 - ratio) .* previous[kpoint] for kpoint in eachindex(raw)]
end

"""Real Frobenius inner product on the deterministic IBZ tangent inventory."""
function _ibz_tangent_inner(
    left::Vector{Matrix{ComplexF64}},
    right::Vector{Matrix{ComplexF64}},
    irreducible_indices::Vector{Int},
)
    return sum(real(dot(left[kpoint], right[kpoint])) for kpoint in irreducible_indices)
end

"""Project one carried search field back to the target real-linear tangent."""
function _project_ibz_tangent_field(
    field::Vector{Matrix{ComplexF64}},
    irreducible_indices::Vector{Int},
    tangent_plans::Vector{Union{Nothing, TargetSymmetryTangentPlan}},
)
    projected = deepcopy(field)
    for kpoint in irreducible_indices
        tangent_plan = tangent_plans[kpoint]
        tangent_plan === nothing && error("missing target symmetry tangent plan")
        value = (projected[kpoint] - projected[kpoint]') ./ 2
        value = _project_target_symmetry_tangent(something(tangent_plan), value)
        projected[kpoint] = (value - value') ./ 2
    end
    return projected
end

"""Vector-transport a right-trivialized IBZ field by tangent reprojection.

The polar retraction changes the unitary base point while the solver stores
directions in the right-trivialized Lie algebra. Reprojection is therefore the
deterministic vector transport used by RCG; it also reimposes the magnetic
real-linear little-group constraints after every accepted step.
"""
function _transport_ibz_tangent_field(
    field::Vector{Matrix{ComplexF64}},
    irreducible_indices::Vector{Int},
    tangent_plans::Vector{Union{Nothing, TargetSymmetryTangentPlan}},
)
    return _project_ibz_tangent_field(field, irreducible_indices, tangent_plans)
end

"""Pack deterministic tangent-history fields as `(n,n,nk,m)`."""
function _pack_u_tangent_history(history::Vector{Vector{Matrix{ComplexF64}}})
    isempty(history) && return zeros(ComplexF64, 0, 0, 0, 0)
    packed_fields = [_pack_matrix_field(field) for field in history]
    return cat(packed_fields...; dims = 4)
end

"""Unpack `(n,n,nk,m)` checkpoint history into right-trivialized fields."""
function _unpack_u_tangent_history(values::Array{ComplexF64, 4})
    isempty(values) && return Vector{Vector{Matrix{ComplexF64}}}()
    return [
        [Matrix{ComplexF64}(@view values[:, :, kpoint, item]) for kpoint in axes(values, 3)] for
        item in axes(values, 4)
    ]
end

"""Encode the complete sorted orbit inventory with byte lengths, never a digest."""
function _u_branch_definition(definitions::Vector{String})
    stream=IOBuffer()
    print(stream, "u-branch-input/1\n", length(definitions), '\n')
    for definition in sort(definitions)
        print(stream, ncodeunits(definition), ':')
        write(stream, definition)
    end
    return String(take!(stream))
end

"""Validate the complete discrete branch inventory without a content digest."""
function _validate_u_branch_definition(definition::String)
    isempty(definition) && return nothing
    definition=="u-branch-input/1\nREFERENCE\n" && return nothing
    source=IOBuffer(definition)
    readline(source)=="u-branch-input/1" ||
        throw(ArgumentError("CURRENT_U_BRANCH_DEFINITION_REQUIRED"))
    count=parse(Int, readline(source));
    count>=0 || throw(ArgumentError("INVALID_U_BRANCH_DEFINITION"))
    for _ in 1:count
        length_text=readuntil(source, UInt8(':'))
        bytes=parse(Int, String(length_text));
        bytes>=0 || throw(ArgumentError("INVALID_U_BRANCH_DEFINITION"))
        value=read(source, bytes)
        length(value)==bytes || throw(ArgumentError("INCOMPLETE_U_BRANCH_DEFINITION"))
    end
    eof(source) || throw(ArgumentError("U_BRANCH_DEFINITION_EXTENT_MISMATCH"))
    return nothing
end

"""Return per-star RMS of a full-mesh tangent for load-imbalance diagnostics."""
function _kstar_gradient_distribution(
    full_field::Vector{Matrix{ComplexF64}},
    representation::BandRepresentation,
)
    star_count = length(representation.irreducible_indices)
    sums = zeros(Float64, star_count)
    counts = zeros(Int, star_count)
    dimension = size(first(full_field), 1)
    for kpoint in eachindex(full_field)
        star = representation.full_to_irreducible[kpoint]
        sums[star] += sum(abs2, full_field[kpoint])
        counts[star] += 1
    end
    values = [
        counts[star] == 0 ? NaN : sqrt(sums[star] / (counts[star] * dimension^2)) for
        star in 1:star_count
    ]
    finite_indices = findall(isfinite, values)
    maximum_index = isempty(finite_indices) ? 0 : finite_indices[argmax(values[finite_indices])]
    return values, maximum_index
end

"""Wannier-style parabolic trial after one finite line-search probe.

The derivative is evaluated at zero and `trial_objective` at `trial_step`.
An ill-conditioned or non-convex fit returns the deterministic geometric
fallback instead of turning a finite optimizer state into a structural HOLD.
"""
function _parabolic_localization_trial_scale(
    base_objective::Float64,
    directional_derivative::Float64,
    trial_step::Float64,
    trial_objective::Float64,
    fallback_factor::Float64,
)
    fallback = trial_step * fallback_factor
    all(
        isfinite,
        (base_objective, directional_derivative, trial_step, trial_objective, fallback_factor),
    ) || return fallback
    trial_step > 0.0 && 0.0 < fallback_factor < 1.0 || return fallback
    curvature_denominator =
        2.0 * (trial_objective - base_objective - directional_derivative * trial_step)
    curvature_denominator > eps(Float64) * max(1.0, abs(base_objective)) || return fallback
    fitted = -directional_derivative * trial_step^2 / curvature_denominator
    isfinite(fitted) && fitted > 0.0 || return fallback
    return clamp(fitted, fallback, 0.95 * trial_step)
end

"""Wannier 4.0.1 `internal_optimal_step`, without added clamping/fallbacks."""
function _recursive_localization_optimal_step(
    base_objective::Float64,
    trial_objective::Float64,
    derivative_at_zero::Float64,
    trial_step::Float64,
)
    all(isfinite, (base_objective, trial_objective, derivative_at_zero, trial_step)) ||
        return (success = false, alpha = NaN, predicted_objective = NaN, quadratic = false)
    trial_step > 0.0 ||
        return (success = false, alpha = NaN, predicted_objective = NaN, quadratic = false)
    factor = trial_objective - base_objective
    if abs(factor) > floatmin(Float64)
        factor = inv(factor)
        shift = 1.0
    else
        factor = 1.0e6
        shift = factor * trial_objective - factor * base_objective
    end
    linear = factor * derivative_at_zero
    quadratic = shift - linear * trial_step
    denominator = factor * base_objective
    stable = !iszero(denominator) && abs(quadratic / denominator) > eps(Float64)
    if stable
        alpha = -0.5 * linear / quadratic * trial_step^2
        predicted = base_objective - 0.25 * linear^2 / (factor * quadratic) * trial_step^2
        if isfinite(alpha) && isfinite(predicted) && derivative_at_zero * alpha <= 0.0
            return (success = true, alpha, predicted_objective = predicted, quadratic = true)
        end
    end
    return (
        success = true,
        alpha = trial_step,
        predicted_objective = trial_objective,
        quadratic = false,
    )
end

"""Apply the exact Wannier 4.0.1 anti-Hermitian exponential U update."""
function _recursive_localization_unitary_step_data(
    old_unitary::Matrix{ComplexF64},
    search_direction::Matrix{ComplexF64},
    alpha::Float64,
    weight_total::Float64,
)
    isfinite(alpha) && isfinite(weight_total) && weight_total > 0.0 || return nothing
    size(search_direction, 1) == size(search_direction, 2) || return nothing
    scaled = (alpha / (4.0 * weight_total)) .* search_direction
    decomposition = _recursive_localization_zheev(1.0im .* scaled)
    decomposition.success || return nothing
    phases = [
        _recursive_localization_complex_exponential(ComplexF64(0.0, -value)) for
        value in decomposition.values
    ]
    rotated_vectors = similar(decomposition.vectors)
    for column in axes(rotated_vectors, 2), row in axes(rotated_vectors, 1)
        # gfortran-16 lowers this specific array assignment with the imaginary
        # lane as the fused multiplicand.  The algebraically identical generic
        # complex product changes U1 by a few ulps; the parabolic FR step then
        # amplifies that change.  This local scalar helper reproduces the
        # compiler operation order without importing any observer state or
        # external Wannier kernel.
        rotated_vectors[row, column] = _recursive_localization_ordered_phase_column_product(
            decomposition.vectors[row, column],
            phases[column],
        )
    end
    rotation = _recursive_localization_zgemm(rotated_vectors, 'N', decomposition.vectors, 'C')
    trial = _recursive_localization_zgemm(old_unitary, 'N', rotation, 'N')
    all(isfinite, trial) || return nothing
    return (unitary = Matrix{ComplexF64}(trial), rotation = rotation)
end

"""Retain the original one-result reference step contract."""
function _recursive_localization_unitary_step(
    old_unitary::Matrix{ComplexF64},
    search_direction::Matrix{ComplexF64},
    alpha::Float64,
    weight_total::Float64,
)
    step = _recursive_localization_unitary_step_data(
        old_unitary,
        search_direction,
        alpha,
        weight_total,
    )
    return step === nothing ? nothing : step.unitary
end

"""Wannier 4.0.1 Fletcher--Reeves state update in the full-k gauge."""
function _recursive_localization_search_direction(
    gradient::Vector{Matrix{ComplexF64}},
    previous_gradient::Union{Nothing, Vector{Matrix{ComplexF64}}},
    previous_direction::Union{Nothing, Vector{Matrix{ComplexF64}}},
    cg_count::Int,
    restart_interval::Int,
    weight_total::Float64;
    dot_workspace::Union{Nothing, ReferenceDotWorkspace} = nothing,
)
    weight_total > 0.0 && isfinite(weight_total) ||
        throw(ArgumentError("invalid localization weight total"))
    current_norm = _recursive_localization_zdot(gradient, gradient, dot_workspace)
    isfinite(current_norm) || return (
        success = false,
        direction = deepcopy(gradient),
        beta = NaN,
        cg_count,
        restarted = true,
        restart_reason = :NONFINITE_BETA,
        derivative = NaN,
    )
    history_available =
        previous_gradient !== nothing &&
        previous_direction !== nothing &&
        length(something(previous_gradient)) == length(gradient) &&
        length(something(previous_direction)) == length(gradient)
    restarted = !history_available || cg_count >= restart_interval
    restart_reason =
        !history_available ? :EMPTY_HISTORY :
        cg_count >= restart_interval ? :PERIODIC_RESTART : :NONE
    beta = 0.0
    next_count = 0
    direction = deepcopy(gradient)
    if !restarted
        previous_norm = _recursive_localization_zdot(
            something(previous_gradient),
            something(previous_gradient),
            dot_workspace,
        )
        if previous_norm > eps(Float64) && isfinite(previous_norm)
            beta = current_norm / previous_norm
            if beta > 3.0 || !isfinite(beta)
                beta = 0.0
                restarted = true
                restart_reason = :BETA_CAP_RESTART
            else
                next_count = cg_count + 1
                for kpoint in eachindex(direction)
                    direction[kpoint] .+= beta .* something(previous_direction)[kpoint]
                end
            end
        else
            restarted = true
            restart_reason = :DEGENERATE_PREVIOUS_GRADIENT
        end
    end
    derivative =
        -_recursive_localization_zdot(gradient, direction, dot_workspace) / (4.0 * weight_total)
    if derivative > 0.0
        if beta != 0.0
            direction = deepcopy(gradient)
            beta = 0.0
            next_count = 0
            restarted = true
            restart_reason = :UPHILL_CG_RESTART
            derivative =
                -_recursive_localization_zdot(gradient, direction, dot_workspace) /
                (4.0 * weight_total)
        end
        if derivative > 0.0
            direction = [-value for value in direction]
            derivative = -derivative
            restarted = true
            restart_reason = :UPHILL_DIRECTION_REVERSED
        end
    end
    return (
        success = isfinite(derivative),
        direction,
        beta,
        cg_count = next_count,
        restarted,
        restart_reason,
        derivative,
    )
end

# Ephemeral, solve-owned accepted evaluation; never serialized or shared with observers.
mutable struct AcceptedReferenceEvaluationWorkspace
    definition::Union{Nothing, NamedTuple}
    evaluation::Union{Nothing, MVLocalizationEvaluation}
    hits::Int
    misses::Int
    published::Bool
end
# Initialize an unpublished empty accepted-evaluation slot with separate hit and miss counters.
AcceptedReferenceEvaluationWorkspace() =
    AcceptedReferenceEvaluationWorkspace(nothing, nothing, 0, 0, false)

# Capture the numerical inputs that must match before a saved accepted evaluation may be reused.
function _reference_evaluation_definition(
    config,
    representation,
    mmn,
    weights,
    frames,
    phase_centers,
    overlaps,
    omega_i,
    geometry,
)
    _prepare_localization_geometry!(geometry, representation, mmn)
    return (
        frames = frames,
        phase_centers = phase_centers,
        overlaps = overlaps,
        omega_i = omega_i,
        weights = weights,
        geometry = geometry.definition,
        representation_tolerance = config.input.representation_tolerance,
        phase_tolerance = config.solver.acceleration.u_phase_branch_tolerance,
    )
end

# Transfer a matching published evaluation out of its slot and detach the workspace ownership.
function _take_reference_evaluation!(workspace::AcceptedReferenceEvaluationWorkspace, definition)
    if workspace.published &&
       workspace.evaluation !== nothing &&
       isequal(workspace.definition, definition)
        workspace.hits += 1
        # Save owns a deep copy. Detach it before transferring its unique ownership.
        value = something(workspace.evaluation)
        _discard_reference_evaluation!(workspace)
        return (success = true, code = :OK, evaluation = value)
    end
    workspace.misses += 1
    _discard_reference_evaluation!(workspace)
    return nothing
end

# Drop both the saved evaluation and its matching input definition and clear publication state.
function _discard_reference_evaluation!(workspace::AcceptedReferenceEvaluationWorkspace)
    workspace.evaluation = nothing
    workspace.definition = nothing
    workspace.published = false
    return nothing
end

# Mark a populated saved evaluation as available to the next accepted-reference consumer.
function _publish_reference_evaluation!(workspace::AcceptedReferenceEvaluationWorkspace)
    workspace.published = workspace.evaluation !== nothing
    return nothing
end

# Keep independent copies of the input definition and evaluation until publication or discard.
function _save_reference_evaluation!(
    workspace::AcceptedReferenceEvaluationWorkspace,
    definition,
    evaluation::MVLocalizationEvaluation,
)
    workspace.definition = deepcopy(definition)
    workspace.evaluation = deepcopy(evaluation)
    workspace.published = false
    return nothing
end

# Run one or more synchronized U-only sweeps for a fixed outer-iteration subspace.
function _localization_sweeps(
    config::WannierizationConfig,
    representation::BandRepresentation,
    mmn::WannierMMN,
    plan::WannierSymmetryPlan,
    weights::Vector{Float64},
    included_bands::Vector{BitVector},
    frozen_indices::Vector{Vector{Int}},
    subspaces::Vector{Matrix{ComplexF64}},
    initial_frames::Vector{Matrix{ComplexF64}},
    initial_centers::Matrix{Float64},
    initial_spreads::Vector{Float64},
    u_mix_ratio::Float64,
    projector_covariance_tolerance::Float64,
    tangent_plans::Vector{Union{Nothing, TargetSymmetryTangentPlan}},
    localize::Bool,
    localization_algorithm::Symbol,
    ;
    geometry::Union{Nothing, LocalizationGeometryWorkspace} = nothing,
    dot_workspace::Union{Nothing, ReferenceDotWorkspace} = nothing,
    accepted_evaluation::Union{Nothing, AcceptedReferenceEvaluationWorkspace} = nothing,
    fixed_projectors::Union{Nothing, Vector{Matrix{ComplexF64}}} = nothing,
    previous_u_gradient::Union{Nothing, Vector{Matrix{ComplexF64}}} = nothing,
    previous_u_direction::Union{Nothing, Vector{Matrix{ComplexF64}}} = nothing,
    u_cg_iteration::Int = 0,
    u_cg_restart_count::Int = 0,
    u_branch_signature::String = "",
    recursive_localization_overlaps::Union{Nothing, Array{ComplexF64, 4}} = nothing,
    recursive_localization_omega_i::Union{Nothing, Float64} = nothing,
    recursive_localization_unitaries::Union{Nothing, Vector{Matrix{ComplexF64}}} = nothing,
)
    Threads.atomic_add!(_LOCALIZATION_SWEEP_ENTRY_COUNT, 1)
    apply_symmetry = symmetry_constraints_applied(config, representation)
    measure_frame_distance = !(
        localization_algorithm == :smv_fletcher_reeves_two_stage &&
        !apply_symmetry &&
        config.solver.acceleration.u_inner_sweeps == 1
    )
    irreducible = representation.irreducible_indices
    frames = deepcopy(initial_frames)
    centers = copy(initial_centers)
    spreads = copy(initial_spreads)
    if localization_algorithm == :smv_fletcher_reeves_two_stage && config.solver.parallel == :mpi
        # The reference optimizer makes scalar accept/restart decisions on
        # every rank.  Last-bit LAPACK gauge differences in any carried field
        # can therefore send ranks into different line-search branches before
        # the next edge Allreduce.  Define rank zero as the arithmetic
        # authority at every localization-call boundary, including restarts;
        # the distributed edge contractions themselves remain uniquely owned
        # and are reduced in the canonical serial edge inventory.
        subspaces = deepcopy(subspaces)
        _mpi_root_canonical_matrix_field!(subspaces, config.solver.parallel)
        _mpi_root_canonical_matrix_field!(frames, config.solver.parallel)
        _mpi_root_canonical_array!(centers, config.solver.parallel)
        _mpi_root_canonical_array!(spreads, config.solver.parallel)
        fixed_projectors = _mpi_root_canonical_optional_matrix_field(
            fixed_projectors === nothing ? nothing : deepcopy(something(fixed_projectors)),
            config.solver.parallel,
        )
        previous_u_gradient = _mpi_root_canonical_optional_matrix_field(
            previous_u_gradient === nothing ? nothing : deepcopy(something(previous_u_gradient)),
            config.solver.parallel,
        )
        previous_u_direction = _mpi_root_canonical_optional_matrix_field(
            previous_u_direction === nothing ? nothing : deepcopy(something(previous_u_direction)),
            config.solver.parallel,
        )
        recursive_localization_unitaries = _mpi_root_canonical_optional_matrix_field(
            recursive_localization_unitaries === nothing ? nothing :
            deepcopy(something(recursive_localization_unitaries)),
            config.solver.parallel,
        )
        recursive_localization_overlaps = _mpi_root_canonical_optional_array(
            recursive_localization_overlaps,
            config.solver.parallel,
        )
        u_cg_iteration = _mpi_root_canonical_scalar(u_cg_iteration, config.solver.parallel)
        u_cg_restart_count = _mpi_root_canonical_scalar(u_cg_restart_count, config.solver.parallel)
        recursive_localization_omega_i = _mpi_root_canonical_optional_scalar(
            recursive_localization_omega_i,
            config.solver.parallel,
        )
    end
    directional = nothing
    maximum_u_step = measure_frame_distance ? 0.0 : nothing
    completed_sweeps = 0
    accepted_step_scale = 0.0
    backtracking_steps = 0
    trial_objective = sum(initial_spreads)
    accepted_objective = trial_objective
    gradient_rms = Inf
    polar_fallback_triggered = false
    active_algorithm = localization_algorithm
    attempted_step_scales = Float64[]
    attempted_objectives = Float64[]
    attempted_required_changes = Float64[]
    attempted_actual_changes = Float64[]
    attempted_directional_derivatives = Float64[]
    attempted_sweeps = Int[]
    attempted_accepted = Bool[]
    base_objective = sum(initial_spreads)
    trial_zero_objective = base_objective
    trial_zero_frame_residual = 0.0
    directional_derivative = NaN
    fixed_projector_drift = fixed_projectors === nothing ? NaN : 0.0
    accepted_required_change = NaN
    accepted_actual_change = NaN
    minimum_diagonal_phase_margin = Inf
    minimum_phase_kpoint = 0
    minimum_phase_neighbor = 0
    minimum_phase_wannier = 0
    minimum_phase_value = NaN
    branch_safe_backtracking_triggered = false
    carried_u_gradient = previous_u_gradient
    carried_u_direction = previous_u_direction
    carried_cg_iteration = u_cg_iteration
    carried_cg_restart_count = u_cg_restart_count
    carried_branch_signature = u_branch_signature
    carried_active_orbit_count = 0
    accepted_u_optimizer_restart_reason = :NOT_APPLICABLE
    last_mv_evaluation::Union{Nothing, MVLocalizationEvaluation} = nothing
    accepted_cg_beta = NaN
    accepted_cg_restarted = false
    accepted_cg_restart_reason = :NOT_APPLICABLE
    accepted_cg_descent_cosine = NaN
    transport_minimum_singular_value = Inf
    transport_maximum_condition = 0.0
    transported_omega_i = NaN
    carried_reference_overlaps = recursive_localization_overlaps
    reference_omega_i = recursive_localization_omega_i
    carried_reference_unitaries =
        recursive_localization_unitaries === nothing ? nothing :
        deepcopy(something(recursive_localization_unitaries))

    for sweep in 1:config.solver.acceleration.u_inner_sweeps
        # Every U search starts from F0 = S * polar(S' * F_old). Recompute all
        # objective-dependent data at F0 before evaluating the gradient.
        base_frames = deepcopy(frames)
        if localization_algorithm == :smv_fletcher_reeves_two_stage
            # Wannier carries the last accepted U directly into the next
            # localization iteration.  Re-projecting that frame through
            # S*polar(S'*F) is physically equivalent but introduces a small
            # per-iteration roundoff rotation that compounds in FR history.
            # The sealed-projector gate below remains authoritative.
            transport_minimum_singular_value = min(transport_minimum_singular_value, 1.0)
            transport_maximum_condition = max(transport_maximum_condition, 1.0)
        else
            for kpoint in irreducible
                alignment = _localization_svd_polar(
                    subspaces[kpoint]' * frames[kpoint],
                    config.solver.numerical_thresholds.frame_transport_rtol,
                    config.solver.numerical_thresholds.maximum_transport_condition,
                )
                alignment.success || return merge(
                    alignment,
                    (
                        message = "F0 alignment is rank deficient or ill conditioned",
                        kpoint = kpoint,
                        sweep = sweep,
                        frames = frames,
                        centers = centers,
                        spreads = spreads,
                    ),
                )
                transport_minimum_singular_value =
                    min(transport_minimum_singular_value, minimum(alignment.singular_values))
                transport_maximum_condition = max(transport_maximum_condition, alignment.condition)
                base_frames[kpoint] = subspaces[kpoint] * alignment.unitary
            end
        end
        base_frames =
            apply_symmetry ? _expand_ibz_frames(base_frames, representation, plan) : base_frames
        if apply_symmetry && config.solver.acceleration.constraint_operation_scope != :full
            restored = _restore_expanded_frames_to_subspaces(
                base_frames,
                subspaces,
                config.input.representation_tolerance,
                config.solver.acceleration.localization_max_condition,
            )
            restored.success || return merge(
                restored,
                (
                    message = "non-full constraint expansion could not be restored to the sealed subspace",
                    sweep = sweep,
                    centers = centers,
                    spreads = spreads,
                ),
            )
            base_frames = restored.frames
        end
        # Wannier ordinary MLWF localization starts with `sheet = 0` and
        # recomputes centers from the principal phases at every iteration.
        # Carrying the Z-stage center image into this branch leaves the spread
        # invariant but changes `ln_tmp`, `rave`, and therefore `wann_domega`.
        # Symmetry-adapted and expert routes retain the centered/Clarke chart.
        phase_reference_centers =
            localization_algorithm == :smv_fletcher_reeves_two_stage ? zeros(size(centers)) :
            copy(centers)
        if localization_algorithm == :smv_fletcher_reeves_two_stage &&
           carried_reference_overlaps === nothing
            carried_reference_overlaps =
                _localized_overlap_state(base_frames, mmn, config.solver.parallel)
        end
        if localization_algorithm == :smv_fletcher_reeves_two_stage && reference_omega_i === nothing
            reference_omega_i = _recursive_localization_invariant_spread(
                something(carried_reference_overlaps),
                weights,
            )
        end
        base_centers, base_spreads, base_directional = _solver_centers_spreads_and_directions(
            config,
            base_frames,
            phase_reference_centers,
            representation,
            mmn,
            weights,
            plan,
            localization_algorithm == :smv_fletcher_reeves_two_stage ?
            carried_reference_overlaps : nothing,
        )
        transported_omega_i = _gauge_invariant_spread(base_frames, mmn, weights)
        base_invariant_failure = _candidate_invariant_failure(
            base_frames,
            base_centers,
            base_spreads,
            frozen_indices,
            representation,
            plan,
            config.input.representation_tolerance,
            projector_covariance_tolerance,
            apply_symmetry;
            construction_policy = config.input.construction_policy,
        )
        base_invariant_failure === nothing || return (
            success = false,
            code = first(base_invariant_failure),
            message = "aligned localization base point F0 failed an invariant gate",
            kpoint = 0,
            sweep = sweep,
            singular_values = Float64[],
            rank = 0,
            condition = Inf,
            invariant_residual = last(base_invariant_failure),
            frames = base_frames,
            centers = base_centers,
            spreads = base_spreads,
        )
        if fixed_projectors !== nothing
            base_projector_drift =
                _maximum_projector_drift(base_frames, something(fixed_projectors))
            fixed_projector_drift = max(fixed_projector_drift, base_projector_drift)
            projector_drift_tolerance =
                _fixed_subspace_projector_drift_tolerance(localization_algorithm)
            base_projector_drift <= projector_drift_tolerance || return (
                success = false,
                code = :FIXED_SUBSPACE_PROJECTOR_DRIFT,
                message = "aligned localization base point changed the sealed projector",
                kpoint = 0,
                sweep = sweep,
                singular_values = Float64[],
                rank = 0,
                condition = Inf,
                fixed_projector_drift = base_projector_drift,
                frames = base_frames,
                centers = base_centers,
                spreads = base_spreads,
            )
        end
        frames = base_frames
        centers = base_centers
        spreads = base_spreads
        directional = base_directional
        base_objective = sum(spreads)
        if !localize
            # Disentanglement owns P/Z only.  The polar alignment above merely
            # transports a deterministic basis for the newly selected P and has
            # already passed every structural invariant.  Re-projecting that
            # basis onto the target frame here would perform an implicit U update
            # before the immutable two-stage boundary.
            completed_sweeps = sweep
            accepted_objective = sum(spreads)
            trial_objective = accepted_objective
            return (
                success = true,
                code = :OK,
                frames = frames,
                centers = centers,
                spreads = spreads,
                directional = directional,
                u_residual = measure_frame_distance ? 0.0 : nothing,
                gradient_rms = Inf,
                projection_converged = true,
                projection_iterations = 0,
                projection_residual = 0.0,
                completed_sweeps = completed_sweeps,
                accepted_step_scale = 0.0,
                backtracking_steps = 0,
                trial_objective = trial_objective,
                accepted_objective = accepted_objective,
                maximum_kstar_gradient_rms = NaN,
                maximum_kstar_gradient_index = -1,
                polar_fallback_triggered = false,
                active_localization_algorithm = localization_algorithm,
                base_objective = base_objective,
                trial_zero_objective = base_objective,
                trial_zero_frame_residual = 0.0,
                attempted_step_scales = Float64[],
                attempted_objectives = Float64[],
                attempted_required_changes = Float64[],
                attempted_actual_changes = Float64[],
                attempted_directional_derivatives = Float64[],
                attempted_sweeps = Int[],
                attempted_accepted = Bool[],
                directional_derivative = NaN,
                fixed_projector_drift = fixed_projector_drift,
                accepted_required_change = NaN,
                accepted_actual_change = NaN,
                minimum_diagonal_phase_margin = Inf,
                minimum_phase_kpoint = 0,
                minimum_phase_neighbor = 0,
                minimum_phase_wannier = 0,
                minimum_phase_value = NaN,
                branch_safe_backtracking_triggered = false,
                previous_u_gradient = carried_u_gradient,
                previous_u_direction = carried_u_direction,
                u_cg_iteration = carried_cg_iteration,
                u_cg_restart_count = carried_cg_restart_count,
                cg_beta = NaN,
                cg_restarted = false,
                cg_restart_reason = :NOT_APPLICABLE,
                cg_descent_cosine = NaN,
                transport_minimum_singular_value = transport_minimum_singular_value,
                transport_maximum_condition = transport_maximum_condition,
                transported_omega_i = transported_omega_i,
                u_phase_contract = LOCALIZATION_GRADIENT_CONTRACT,
                u_active_orbit_definition = carried_branch_signature,
                u_active_orbit_count = 0,
                generalized_gradient_rms = Inf,
                u_optimizer_restart_reason = :NOT_APPLICABLE,
            )
        end

        reuse_reference =
            accepted_evaluation !== nothing &&
            geometry !== nothing &&
            localization_algorithm == :smv_fletcher_reeves_two_stage &&
            !apply_symmetry &&
            (config.solver.parallel != :mpi || MPI.Comm_size(MPI.COMM_WORLD) == 1) &&
            lowercase(strip(get(ENV, "WANNIERNLQG_LOCALIZATION_DEBUG_GRADIENT", "0"))) ∉
            ("1", "true", "yes")
        definition =
            reuse_reference ?
            _reference_evaluation_definition(
                config,
                representation,
                mmn,
                weights,
                frames,
                phase_reference_centers,
                carried_reference_overlaps,
                reference_omega_i,
                geometry,
            ) : nothing
        cached =
            reuse_reference ? _take_reference_evaluation!(accepted_evaluation, definition) : nothing
        evaluation_result =
            cached === nothing ?
            _evaluate_mv_localization(
                config,
                frames,
                phase_reference_centers,
                representation,
                mmn,
                weights,
                plan,
                tangent_plans,
                localization_algorithm == :smv_fletcher_reeves_two_stage ?
                carried_reference_overlaps : nothing,
                localization_algorithm == :smv_fletcher_reeves_two_stage ? reference_omega_i :
                nothing;
                geometry = geometry,
            ) : cached
        evaluation_result.success || return (
            success = false,
            code = evaluation_result.code,
            message = "MV localization evaluation failed its centered phase contract",
            kpoint = hasproperty(evaluation_result, :kpoint) ? evaluation_result.kpoint : 0,
            sweep = sweep,
            singular_values = hasproperty(evaluation_result, :minimum_diagonal_overlap) ?
                              [evaluation_result.minimum_diagonal_overlap] : Float64[],
            rank = 0,
            condition = Inf,
        )
        mv_evaluation = evaluation_result.evaluation
        last_mv_evaluation = mv_evaluation
        carried_active_orbit_count = length(mv_evaluation.active_orbit_definitions)
        centers = mv_evaluation.centers
        spreads = mv_evaluation.spreads
        directional = mv_evaluation.directional
        base_objective = mv_evaluation.objective
        gradient_result = (gradients = mv_evaluation.raw_gradients,)
        projected = (
            representative_gradients = mv_evaluation.representative_gradients,
            full_gradients = mv_evaluation.full_gradients,
            norm_squared = mv_evaluation.gradient_norm_squared,
            rms = mv_evaluation.gradient_rms,
        )
        gradient_rms = projected.rms
        if localization_algorithm == :smv_fletcher_reeves_two_stage &&
           config.solver.parallel == :mpi
            _mpi_root_canonical_array!(centers, config.solver.parallel)
            _mpi_root_canonical_array!(spreads, config.solver.parallel)
            if directional isa Tuple
                directional = ntuple(
                    index ->
                        _mpi_root_canonical_scalar(directional[index], config.solver.parallel),
                    length(directional),
                )
            elseif directional !== nothing
                _mpi_root_canonical_array!(directional, config.solver.parallel)
            end
            base_objective = _mpi_root_canonical_scalar(base_objective, config.solver.parallel)
            gradient_rms = _mpi_root_canonical_scalar(gradient_rms, config.solver.parallel)
        end
        phase_context = (
            margin = mv_evaluation.minimum_phase_margin,
            kpoint = mv_evaluation.minimum_phase_kpoint,
            neighbor = mv_evaluation.minimum_phase_neighbor,
            wannier = mv_evaluation.minimum_phase_wannier,
            phase = mv_evaluation.minimum_phase_value,
        )
        sweep_phase_margin = phase_context.margin
        if sweep_phase_margin < minimum_diagonal_phase_margin
            minimum_diagonal_phase_margin = sweep_phase_margin
            minimum_phase_kpoint = phase_context.kpoint
            minimum_phase_neighbor = phase_context.neighbor
            minimum_phase_wannier = phase_context.wannier
            minimum_phase_value = phase_context.phase
        end
        # The ordinary two-stage algorithm continues its direction and parabolic
        # trial at small gradients; only its previous-norm CG denominator is guarded.
        # Convergence belongs to the explicit spread-window policy in SolverAcceptance.
        # Retain the stationary shortcut for the other localization algorithms.
        if localization_algorithm != :smv_fletcher_reeves_two_stage &&
           gradient_rms <= config.solver.acceleration.u_gradient_norm_tolerance
            completed_sweeps = sweep
            maximum_u_step = measure_frame_distance ? 0.0 : nothing
            accepted_step_scale = 0.0
            trial_objective = base_objective
            accepted_objective = base_objective
            directional_derivative = 0.0
            accepted_required_change = 0.0
            accepted_actual_change = 0.0
            carried_u_gradient = nothing
            carried_u_direction = nothing
            carried_cg_iteration = 0
            accepted_cg_beta = 0.0
            accepted_cg_restarted = localization_algorithm in
            (:smv_fletcher_reeves_two_stage, :symmetry_projected_smv_fletcher_reeves_two_stage)
            accepted_cg_restart_reason = :GRADIENT_CONVERGED_ZERO_STEP
            accepted_cg_descent_cosine = 1.0
            carried_branch_signature = _u_branch_definition(mv_evaluation.active_orbit_definitions)
            carried_active_orbit_count = length(mv_evaluation.active_orbit_definitions)
            if !isempty(mv_evaluation.active_links)
                accepted_u_optimizer_restart_reason = :U_BRANCH_STATIONARY
            end
            break
        end

        steepest_representative = projected.representative_gradients
        search_representative = steepest_representative
        search_full = projected.full_gradients
        cg_beta = 0.0
        cg_restarted = false
        cg_restart_reason = :NOT_APPLICABLE
        cg_descent_cosine = NaN
        trial_derivative_at_zero = NaN
        next_conjugate_gradient_count = carried_cg_iteration
        current_branch_signature = _u_branch_definition(mv_evaluation.active_orbit_definitions)
        if localization_algorithm == :smv_fletcher_reeves_two_stage
            apply_symmetry && throw(
                ArgumentError(
                    "RECURSIVE_LOCALIZATION_MODE_MISMATCH: the reference optimizer is ordinary no-symmetry only",
                ),
            )
            weight_total = _recursive_localization_weight_total(weights)
            reference_direction = _recursive_localization_search_direction(
                steepest_representative,
                carried_u_gradient,
                carried_u_direction,
                carried_cg_iteration,
                config.solver.acceleration.u_recursive_localization_restart_interval,
                weight_total;
                dot_workspace = dot_workspace,
            )
            reference_direction.success || return (
                success = false,
                code = :NONFINITE_LOCALIZATION_DIRECTION,
                message = "Wannier-reference search direction is non-finite",
                kpoint = 0,
                sweep,
                singular_values = Float64[],
                rank = 0,
                condition = Inf,
                frames,
                centers,
                spreads,
            )
            search_representative = reference_direction.direction
            search_full = search_representative
            cg_beta = reference_direction.beta
            cg_restarted = reference_direction.restarted
            cg_restart_reason = reference_direction.restart_reason
            trial_derivative_at_zero = reference_direction.derivative
            next_conjugate_gradient_count = reference_direction.cg_count
            if config.solver.parallel == :mpi
                _mpi_root_canonical_matrix_field!(search_representative, config.solver.parallel)
                search_full = search_representative
                cg_beta = _mpi_root_canonical_scalar(cg_beta, config.solver.parallel)
                trial_derivative_at_zero =
                    _mpi_root_canonical_scalar(trial_derivative_at_zero, config.solver.parallel)
                next_conjugate_gradient_count = _mpi_root_canonical_scalar(
                    next_conjugate_gradient_count,
                    config.solver.parallel,
                )
                cg_restarted = _mpi_root_canonical_flag(cg_restarted, config.solver.parallel)
            end
            direction_norm_squared = _full_tangent_inner(search_full, search_full)
            cg_descent_cosine =
                direction_norm_squared <= eps(Float64) || projected.norm_squared <= eps(Float64) ?
                NaN :
                -_localization_directional_derivative(steepest_representative, search_full) /
                sqrt(projected.norm_squared * direction_norm_squared)
            cg_restarted && (carried_cg_restart_count += 1)
        elseif localization_algorithm == :symmetry_projected_smv_fletcher_reeves_two_stage
            cg_restart_reason = :NONE
            history_compatible =
                carried_u_gradient !== nothing &&
                carried_u_direction !== nothing &&
                length(something(carried_u_gradient)) == length(frames) &&
                length(something(carried_u_direction)) == length(frames) &&
                carried_cg_iteration > 0 &&
                carried_branch_signature == current_branch_signature
            restart_interval =
                _is_symmetry_projected_smv_fr(localization_algorithm) ?
                config.solver.acceleration.u_recursive_localization_restart_interval :
                config.solver.acceleration.u_cg_restart_interval
            periodic_restart = history_compatible && carried_cg_iteration % restart_interval == 0
            if !history_compatible
                cg_restarted = true
                cg_restart_reason = :EMPTY_HISTORY
            elseif periodic_restart
                cg_restarted = true
                cg_restart_reason = :PERIODIC_RESTART
            else
                previous_gradient = if apply_symmetry
                    _transport_ibz_tangent_field(
                        something(carried_u_gradient),
                        irreducible,
                        tangent_plans,
                    )
                else
                    [(value - value') ./ 2 for value in something(carried_u_gradient)]
                end
                previous_direction = if apply_symmetry
                    _transport_ibz_tangent_field(
                        something(carried_u_direction),
                        irreducible,
                        tangent_plans,
                    )
                else
                    [(value - value') ./ 2 for value in something(carried_u_direction)]
                end
                denominator = _ibz_tangent_inner(previous_gradient, previous_gradient, irreducible)
                numerator = if _is_symmetry_projected_smv_fr(localization_algorithm)
                    _ibz_tangent_inner(steepest_representative, steepest_representative, irreducible)
                else
                    _ibz_tangent_inner(
                        steepest_representative,
                        [
                            steepest_representative[kpoint] - previous_gradient[kpoint] for
                            kpoint in eachindex(steepest_representative)
                        ],
                        irreducible,
                    )
                end
                if !isfinite(denominator) || denominator <= eps(Float64)
                    cg_restarted = true
                    cg_restart_reason = :DEGENERATE_PREVIOUS_GRADIENT
                elseif !isfinite(numerator)
                    cg_restarted = true
                    cg_restart_reason = :NONFINITE_BETA
                else
                    cg_beta = if _is_symmetry_projected_smv_fr(localization_algorithm)
                        numerator / denominator
                    else
                        min(config.solver.acceleration.u_cg_beta_cap, max(0.0, numerator / denominator))
                    end
                    proposed = [
                        steepest_representative[kpoint] + cg_beta * previous_direction[kpoint]
                        for kpoint in eachindex(steepest_representative)
                    ]
                    search_representative =
                        apply_symmetry ?
                        _project_ibz_tangent_field(proposed, irreducible, tangent_plans) :
                        [(value - value') ./ 2 for value in proposed]
                    search_full =
                        apply_symmetry ?
                        _expand_ibz_target_tangents(search_representative, representation, plan) :
                        search_representative
                    proposed_derivative =
                        _mv_generalized_directional_derivative(mv_evaluation, search_full)
                    direction_norm_squared = sum(sum(abs2, value) for value in search_full)
                    cg_descent_cosine =
                        direction_norm_squared <= eps(Float64) ||
                        projected.norm_squared <= eps(Float64) ? NaN :
                        -proposed_derivative / sqrt(projected.norm_squared * direction_norm_squared)
                    if !isfinite(proposed_derivative) || proposed_derivative >= 0.0
                        cg_restarted = true
                        cg_restart_reason = :NON_DESCENT_DIRECTION
                    elseif !isfinite(cg_descent_cosine) ||
                           cg_descent_cosine <
                           config.solver.acceleration.u_cg_minimum_descent_cosine
                        cg_restarted = true
                        cg_restart_reason = :DESCENT_COSINE_TOO_SMALL
                    end
                end
            end
            if cg_restarted
                search_representative = steepest_representative
                search_full = projected.full_gradients
                cg_beta = 0.0
                carried_cg_restart_count += 1
                steepest_norm = sum(sum(abs2, value) for value in search_full)
                cg_descent_cosine = steepest_norm <= eps(Float64) ? NaN : 1.0
            end
        end
        gradient_directional_derivative =
            _mv_generalized_directional_derivative(mv_evaluation, search_full)
        # A truly zero two-stage search direction takes an identity trial, as its
        # parabolic search does. This is exact zero, not a small-gradient cutoff.
        reference_zero_direction =
            localization_algorithm == :smv_fletcher_reeves_two_stage &&
            iszero(gradient_directional_derivative)
        if config.solver.acceleration.u_acceptance in (:armijo, :strong_wolfe) && (
            !isfinite(gradient_directional_derivative) ||
            (gradient_directional_derivative >= 0.0 && !reference_zero_direction)
        )
            return (
                success = false,
                code = isfinite(gradient_directional_derivative) ?
                       :NON_DESCENT_LOCALIZATION_DIRECTION : :NONFINITE_LOCALIZATION_DIRECTION,
                message = "branch-aware localization requires a finite strictly descending direction",
                kpoint = 0,
                sweep = sweep,
                singular_values = Float64[],
                rank = 0,
                condition = Inf,
                directional_derivative = gradient_directional_derivative,
                gradient_rms = gradient_rms,
                frames = frames,
                centers = centers,
                spreads = spreads,
                cg_beta = cg_beta,
                cg_restarted = cg_restarted,
                cg_restart_reason = cg_restart_reason,
                cg_descent_cosine = cg_descent_cosine,
            )
        end

        old_unitaries = Vector{Union{Nothing, Matrix{ComplexF64}}}(undef, length(frames))
        fill!(old_unitaries, nothing)
        maximum_gradient_rotation = 0.0
        maximum_steepest_rotation = 0.0
        for kpoint in irreducible
            if localization_algorithm == :smv_fletcher_reeves_two_stage
                # This is the carried Wannier U itself.  A polar repair here
                # changes its last bits and therefore the next exponential
                # update and FR history.  Structural isometry is checked on the
                # physical frames before and after the accepted trial.
                old_unitaries[kpoint] =
                    carried_reference_unitaries === nothing ?
                    _recursive_localization_zgemm(subspaces[kpoint], 'C', frames[kpoint], 'N') :
                    something(carried_reference_unitaries)[kpoint]
                # The ordinary reference route uses its own parabolic trial.
                # Its modes tuple below is empty, so these rotation bounds are
                # not consumed. Retain the bounds for every non-reference route.
                # Direction finiteness remains checked before entering this loop.
                continue
            end
            old_polar = _localization_svd_polar(
                subspaces[kpoint]' * frames[kpoint],
                config.solver.numerical_thresholds.frame_transport_rtol,
                config.solver.numerical_thresholds.maximum_transport_condition,
            )
            old_polar.success || return merge(
                old_polar,
                (
                    message = "carried U matrix failed its rank/condition gate",
                    kpoint = kpoint,
                    sweep = sweep,
                ),
            )
            old_unitaries[kpoint] = old_polar.unitary
            maximum_gradient_rotation =
                max(maximum_gradient_rotation, opnorm(search_representative[kpoint]))
            maximum_steepest_rotation =
                max(maximum_steepest_rotation, opnorm(steepest_representative[kpoint]))
        end

        function build_trial(mode::Symbol, scale::Float64, reference_steps = nothing)
            iszero(scale) && return deepcopy(frames)
            probe_frames = deepcopy(frames)
            for kpoint in irreducible
                old_u = something(old_unitaries[kpoint])
                trial_u = if mode == :smv_fletcher_reeves_two_stage
                    step = _recursive_localization_unitary_step_data(
                        old_u,
                        search_representative[kpoint],
                        scale,
                        weight_total,
                    )
                    if step !== nothing && reference_steps !== nothing
                        reference_steps[kpoint] = step
                    end
                    step === nothing ? nothing : step.unitary
                else
                    tangent =
                        mode in (
                            :smv_fletcher_reeves_two_stage,
                            :symmetry_projected_smv_fletcher_reeves_two_stage,
                        ) ? search_representative[kpoint] : steepest_representative[kpoint]
                    retraction = _polar_retracted_tangent_step(
                        old_u,
                        tangent,
                        scale,
                        config.solver.numerical_thresholds.frame_transport_rtol,
                        config.solver.numerical_thresholds.maximum_transport_condition,
                    )
                    retraction.success ? retraction.unitary : nothing
                end
                trial_u === nothing && return nothing
                probe_frames[kpoint] = subspaces[kpoint] * trial_u
            end
            expanded =
                apply_symmetry ? _expand_ibz_frames(probe_frames, representation, plan) :
                probe_frames
            if apply_symmetry && config.solver.acceleration.constraint_operation_scope != :full
                restored = _restore_expanded_frames_to_subspaces(
                    expanded,
                    subspaces,
                    config.input.representation_tolerance,
                    config.solver.acceleration.localization_max_condition,
                )
                restored.success || return nothing
                return restored.frames
            end
            return expanded
        end

        function reference_rotations(scale::Float64, reference_steps)
            rotations = [
                Matrix{ComplexF64}(I, size(frames[kpoint], 2), size(frames[kpoint], 2)) for
                kpoint in eachindex(frames)
            ]
            for kpoint in irreducible
                identity_unitary = Matrix{ComplexF64}(I, size(rotations[kpoint])...)
                rotation = if haskey(reference_steps, kpoint)
                    # Retain I * rotation ZGEMM, including its rounding/signed zero.
                    value = _recursive_localization_zgemm(
                        identity_unitary,
                        'N',
                        reference_steps[kpoint].rotation,
                        'N',
                    )
                    all(isfinite, value) ? Matrix{ComplexF64}(value) : nothing
                else
                    _recursive_localization_unitary_step(
                        identity_unitary,
                        search_representative[kpoint],
                        scale,
                        weight_total,
                    )
                end
                rotation === nothing && return nothing
                rotations[kpoint] = rotation
            end
            return rotations
        end

        function reference_unitaries(scale::Float64, reference_steps)
            unitary_field = Vector{Matrix{ComplexF64}}(undef, length(frames))
            for kpoint in eachindex(frames)
                old_u = something(old_unitaries[kpoint])
                if kpoint in irreducible
                    trial_u =
                        haskey(reference_steps, kpoint) ? reference_steps[kpoint].unitary :
                        _recursive_localization_unitary_step(
                            old_u,
                            search_representative[kpoint],
                            scale,
                            weight_total,
                        )
                    trial_u === nothing && return nothing
                    unitary_field[kpoint] = trial_u
                else
                    unitary_field[kpoint] = copy(old_u)
                end
            end
            return unitary_field
        end

        function objective_at(mode::Symbol, scale::Float64)
            trial_frames = build_trial(mode, scale)
            trial_frames === nothing && return NaN
            _, trial_spreads, _ = _mv_centered_full_mesh_centers_spreads_and_directions(
                trial_frames,
                phase_reference_centers,
                representation,
                mmn,
                weights,
                plan,
            )
            return sum(trial_spreads)
        end

        trial_zero_frames =
            localization_algorithm == :smv_fletcher_reeves_two_stage ? deepcopy(frames) :
            build_trial(:gradient, 0.0)
        trial_zero_frame_residual =
            trial_zero_frames === nothing ? Inf :
            maximum(
                norm(trial_zero_frames[kpoint] - frames[kpoint]) for kpoint in eachindex(frames)
            )
        trial_zero_objective =
            localization_algorithm == :smv_fletcher_reeves_two_stage ? base_objective :
            objective_at(:gradient, 0.0)
        basepoint_tolerance = max(
            config.solver.acceleration.u_objective_tolerance,
            128eps(Float64) * max(1.0, abs(base_objective)),
        )
        if !isfinite(trial_zero_objective) ||
           trial_zero_frame_residual > basepoint_tolerance ||
           abs(trial_zero_objective - base_objective) > basepoint_tolerance
            return (
                success = false,
                code = :LOCALIZATION_BASEPOINT_MISMATCH,
                message = "trial(0) does not reproduce the aligned localization base point F0",
                kpoint = 0,
                sweep = sweep,
                singular_values = Float64[],
                rank = 0,
                condition = Inf,
                frames = frames,
                centers = centers,
                spreads = spreads,
                base_objective = base_objective,
                trial_zero_objective = trial_zero_objective,
                trial_zero_frame_residual = trial_zero_frame_residual,
            )
        end

        accepted_trial = nothing
        fr_best_finite_descent = nothing
        last_failure = nothing
        steepest_directional_derivative =
            _mv_generalized_directional_derivative(mv_evaluation, projected.full_gradients)
        old_objective = base_objective
        objective_tolerance = 64eps(Float64) * max(1.0, abs(old_objective))
        if localization_algorithm == :smv_fletcher_reeves_two_stage
            function reference_candidate(alpha::Float64, trial_index::Int)
                push!(attempted_step_scales, alpha)
                push!(attempted_sweeps, sweep)
                push!(attempted_accepted, false)
                push!(attempted_directional_derivatives, trial_derivative_at_zero)
                # Exactly one alpha/direction/weight/frame trial owns this store.
                # A rejected trial, new alpha, direction or sweep cannot reuse it.
                reference_steps = Dict{
                    Int,
                    NamedTuple{
                        (:unitary, :rotation),
                        Tuple{Matrix{ComplexF64}, Matrix{ComplexF64}},
                    },
                }()
                trial_frames = build_trial(:smv_fletcher_reeves_two_stage, alpha, reference_steps)
                if trial_frames === nothing
                    push!(attempted_objectives, Inf)
                    push!(attempted_required_changes, NaN)
                    push!(attempted_actual_changes, Inf)
                    return (
                        success = false,
                        code = :LOCALIZATION_EXPONENTIAL_UPDATE_FAILED,
                        message = "Wannier-reference exponential update failed",
                    )
                end
                rotations = reference_rotations(alpha, reference_steps)
                if rotations === nothing
                    push!(attempted_objectives, Inf)
                    push!(attempted_required_changes, NaN)
                    push!(attempted_actual_changes, Inf)
                    return (
                        success = false,
                        code = :LOCALIZATION_EXPONENTIAL_UPDATE_FAILED,
                        message = "Wannier-reference link rotation failed",
                    )
                end
                trial_overlaps = _rotate_localized_overlap_state(
                    something(carried_reference_overlaps),
                    rotations,
                    mmn,
                )
                trial_unitaries = reference_unitaries(alpha, reference_steps)
                trial_unitaries === nothing && return (
                    success = false,
                    code = :LOCALIZATION_EXPONENTIAL_UPDATE_FAILED,
                    message = "Wannier-reference U state update failed",
                )
                trial_result = _evaluate_mv_localization(
                    config,
                    trial_frames,
                    phase_reference_centers,
                    representation,
                    mmn,
                    weights,
                    plan,
                    tangent_plans,
                    trial_overlaps,
                    reference_omega_i;
                    geometry = geometry,
                    defer_reference_gradient = reuse_reference && trial_index == 1,
                )
                trial_success =
                    _mpi_root_canonical_flag(trial_result.success, config.solver.parallel)
                if !trial_success
                    push!(attempted_objectives, Inf)
                    push!(attempted_required_changes, NaN)
                    push!(attempted_actual_changes, Inf)
                    return merge(
                        trial_result,
                        (message = "Wannier-reference trial evaluation failed",),
                    )
                end
                trial_evaluation = trial_result.evaluation
                # Wannier feeds the independently recomputed total spread at
                # the trial point directly into `internal_optimal_step`.  Its
                # cancellation pattern is therefore part of the reference
                # algorithm; the compensated delta used by the other NLQG
                # optimizers would select a slightly different parabola.
                objective = trial_evaluation.objective
                objective = _mpi_root_canonical_scalar(objective, config.solver.parallel)
                actual_change = objective - old_objective
                push!(attempted_objectives, objective)
                push!(attempted_required_changes, trial_derivative_at_zero * alpha)
                push!(attempted_actual_changes, actual_change)
                all(isfinite, (objective, actual_change)) || return (
                    success = false,
                    code = :NONFINITE_LOCALIZATION_TRIAL,
                    message = "Wannier-reference trial produced a non-finite objective",
                )
                invariant_failure = _candidate_invariant_failure(
                    trial_frames,
                    trial_evaluation.centers,
                    trial_evaluation.spreads,
                    frozen_indices,
                    representation,
                    plan,
                    config.input.representation_tolerance,
                    projector_covariance_tolerance,
                    apply_symmetry;
                    construction_policy = config.input.construction_policy,
                )
                trial_projector_drift =
                    fixed_projectors === nothing ? NaN :
                    _maximum_projector_drift(trial_frames, something(fixed_projectors))
                if fixed_projectors !== nothing
                    fixed_projector_drift = max(fixed_projector_drift, trial_projector_drift)
                    projector_drift_tolerance =
                        _fixed_subspace_projector_drift_tolerance(localization_algorithm)
                    trial_projector_drift <= projector_drift_tolerance || (
                        invariant_failure =
                            (:FIXED_SUBSPACE_PROJECTOR_DRIFT, trial_projector_drift)
                    )
                end
                invariant_failure === nothing || return (
                    success = false,
                    code = first(invariant_failure),
                    message = "Wannier-reference trial failed a structural invariant",
                    invariant_residual = last(invariant_failure),
                )
                return (
                    success = true,
                    frames = trial_frames,
                    centers = trial_evaluation.centers,
                    spreads = trial_evaluation.spreads,
                    directional = trial_evaluation.directional,
                    step_scale = alpha,
                    backtracking_steps = trial_index - 1,
                    objective,
                    required_change = trial_derivative_at_zero * alpha,
                    actual_change,
                    directional_derivative = trial_derivative_at_zero,
                    fixed_projector_drift = trial_projector_drift,
                    mode = :smv_fletcher_reeves_two_stage,
                    evaluation = trial_evaluation,
                    branch_active_set_changed = false,
                    recursive_localization_overlaps = trial_overlaps,
                    recursive_localization_unitaries = trial_unitaries,
                )
            end

            first_trial = reference_candidate(
                config.solver.acceleration.u_recursive_localization_trial_step,
                1,
            )
            first_trial_success =
                _mpi_root_canonical_flag(first_trial.success, config.solver.parallel)
            if first_trial_success
                optimal = _recursive_localization_optimal_step(
                    old_objective,
                    first_trial.objective,
                    trial_derivative_at_zero,
                    config.solver.acceleration.u_recursive_localization_trial_step,
                )
                optimal_success = _mpi_root_canonical_flag(optimal.success, config.solver.parallel)
                optimal_quadratic =
                    _mpi_root_canonical_flag(optimal.quadratic, config.solver.parallel)
                optimal_alpha = _mpi_root_canonical_scalar(optimal.alpha, config.solver.parallel)
                if optimal_success && optimal_quadratic
                    optimal_trial = reference_candidate(optimal_alpha, 2)
                    optimal_trial_success =
                        _mpi_root_canonical_flag(optimal_trial.success, config.solver.parallel)
                    if optimal_trial_success
                        attempted_accepted[end] = true
                        accepted_trial = optimal_trial
                    else
                        last_failure = (optimal_trial.code, Inf)
                    end
                elseif optimal_success
                    # Complete only this selected trial's independently owned data.
                    completed_first =
                        hasproperty(first_trial.evaluation, :finish_gradient) ?
                        first_trial.evaluation.finish_gradient() :
                        (success = true, evaluation = first_trial.evaluation)
                    completed_success =
                        _mpi_root_canonical_flag(completed_first.success, config.solver.parallel)
                    if completed_success
                        attempted_accepted[end] = true
                        accepted_trial =
                            merge(first_trial, (evaluation = completed_first.evaluation,))
                    else
                        last_failure = (completed_first.code, Inf)
                    end
                else
                    last_failure = (:LOCALIZATION_PARABOLIC_STEP_NONFINITE, Inf)
                end
            else
                last_failure = (first_trial.code, Inf)
            end
        end
        modes =
            localization_algorithm == :smv_fletcher_reeves_two_stage ? () :
            localization_algorithm in
            (:smv_fletcher_reeves_two_stage, :symmetry_projected_smv_fletcher_reeves_two_stage) &&
            !cg_restarted ? (localization_algorithm, :gradient) : (:gradient,)
        for mode in modes
            base_scale =
                _is_fletcher_reeves_localization(mode) ?
                config.solver.acceleration.u_recursive_localization_trial_step :
                config.solver.acceleration.u_initial_step
            maximum_rotation =
                mode in (
                    :smv_fletcher_reeves_two_stage,
                    :symmetry_projected_smv_fletcher_reeves_two_stage,
                ) ? maximum_gradient_rotation : maximum_steepest_rotation
            if isfinite(config.solver.acceleration.u_max_geodesic_step) && maximum_rotation > 0.0
                base_scale = min(
                    base_scale,
                    prevfloat(config.solver.acceleration.u_max_geodesic_step) / maximum_rotation,
                )
            end
            backtracking_limit = _localization_backtracking_limit(config.solver.acceleration, mode)
            recursive_localization_first_trial_objective = NaN
            recursive_localization_parabolic_scale = NaN
            for backtrack in 0:backtracking_limit
                step_scale = if _is_fletcher_reeves_localization(mode) && backtrack == 1
                    recursive_localization_parabolic_scale =
                        _parabolic_localization_trial_scale(
                            old_objective,
                            gradient_directional_derivative,
                            base_scale,
                            recursive_localization_first_trial_objective,
                            config.solver.acceleration.u_backtracking_factor,
                        )
                    recursive_localization_parabolic_scale
                elseif _is_fletcher_reeves_localization(mode) &&
                       backtrack > 1 &&
                       isfinite(recursive_localization_parabolic_scale)
                    _backtracking_step_scale(
                        recursive_localization_parabolic_scale,
                        config.solver.acceleration.u_backtracking_factor,
                        backtrack - 1,
                    )
                else
                    _backtracking_step_scale(
                        base_scale,
                        config.solver.acceleration.u_backtracking_factor,
                        backtrack,
                    )
                end
                push!(attempted_step_scales, step_scale)
                push!(attempted_sweeps, sweep)
                push!(attempted_accepted, false)
                trial_directional_derivative =
                    mode in (
                        :smv_fletcher_reeves_two_stage,
                        :symmetry_projected_smv_fletcher_reeves_two_stage,
                    ) ? gradient_directional_derivative : steepest_directional_derivative
                push!(attempted_directional_derivatives, trial_directional_derivative)
                required_change =
                    config.solver.acceleration.u_acceptance in (:armijo, :strong_wolfe) ?
                    config.solver.acceleration.u_armijo_c1 *
                    step_scale *
                    trial_directional_derivative :
                    config.solver.acceleration.u_acceptance == :monotone ? 0.0 : Inf
                trial_frames = build_trial(mode, step_scale)
                if trial_frames === nothing
                    push!(attempted_objectives, Inf)
                    push!(attempted_required_changes, required_change)
                    push!(attempted_actual_changes, Inf)
                    last_failure = (:LOCALIZATION_RETRACTION_FAILED, Inf)
                    if mode in (
                        :smv_fletcher_reeves_two_stage,
                        :symmetry_projected_smv_fletcher_reeves_two_stage,
                    )
                        cg_restarted = true
                        cg_restart_reason = :RETRACTION_REJECTED
                        break
                    end
                    continue
                end
                trial_evaluation_result = _evaluate_mv_localization(
                    config,
                    trial_frames,
                    phase_reference_centers,
                    representation,
                    mmn,
                    weights,
                    plan,
                    tangent_plans;
                    geometry = geometry,
                )
                if !trial_evaluation_result.success
                    push!(attempted_objectives, Inf)
                    push!(attempted_required_changes, required_change)
                    push!(attempted_actual_changes, Inf)
                    last_failure = (trial_evaluation_result.code, Inf)
                    if mode in (
                        :smv_fletcher_reeves_two_stage,
                        :symmetry_projected_smv_fletcher_reeves_two_stage,
                    )
                        cg_restarted = true
                        cg_restart_reason = :TRIAL_EVALUATION_REJECTED
                        break
                    end
                    continue
                end
                trial_evaluation = trial_evaluation_result.evaluation
                trial_centers = trial_evaluation.centers
                trial_spreads = trial_evaluation.spreads
                trial_directional = trial_evaluation.directional
                stable_actual_change = _mv_centered_objective_change(
                    mv_evaluation,
                    trial_evaluation,
                    phase_reference_centers,
                    weights,
                )
                trial_objective = old_objective + stable_actual_change
                _is_fletcher_reeves_localization(mode) &&
                    backtrack == 0 &&
                    (recursive_localization_first_trial_objective = trial_objective)
                push!(attempted_objectives, trial_objective)
                invariant_failure = _candidate_invariant_failure(
                    trial_frames,
                    trial_centers,
                    trial_spreads,
                    frozen_indices,
                    representation,
                    plan,
                    config.input.representation_tolerance,
                    projector_covariance_tolerance,
                    apply_symmetry;
                    construction_policy = config.input.construction_policy,
                )
                trial_projector_drift =
                    fixed_projectors === nothing ? NaN :
                    _maximum_projector_drift(trial_frames, something(fixed_projectors))
                if fixed_projectors !== nothing
                    fixed_projector_drift = max(fixed_projector_drift, trial_projector_drift)
                    trial_projector_drift <=
                    _fixed_subspace_projector_drift_tolerance(localization_algorithm) || (
                        invariant_failure =
                            (:FIXED_SUBSPACE_PROJECTOR_DRIFT, trial_projector_drift)
                    )
                end
                actual_change = stable_actual_change
                push!(attempted_required_changes, required_change)
                push!(attempted_actual_changes, actual_change)
                if mode in (
                    :smv_fletcher_reeves_two_stage,
                    :symmetry_projected_smv_fletcher_reeves_two_stage,
                ) && !isfinite(trial_objective)
                    last_failure = (:NONFINITE_LOCALIZATION_TRIAL, trial_objective)
                    cg_restarted = true
                    cg_restart_reason = :NONFINITE_TRIAL
                    break
                elseif mode in (
                    :smv_fletcher_reeves_two_stage,
                    :symmetry_projected_smv_fletcher_reeves_two_stage,
                ) && invariant_failure !== nothing
                    last_failure = invariant_failure
                    cg_restarted = true
                    cg_restart_reason = :STRUCTURAL_GATE_REJECTED
                    break
                end
                trial_search_full =
                    mode in (
                        :smv_fletcher_reeves_two_stage,
                        :symmetry_projected_smv_fletcher_reeves_two_stage,
                    ) ? search_full : projected.full_gradients
                trial_curve_velocity =
                    trial_search_full === nothing ? nothing :
                    [
                        _polar_retraction_curve_velocity(value, step_scale) for
                        value in something(trial_search_full)
                    ]
                wolfe_trial_derivative =
                    trial_curve_velocity === nothing ? NaN :
                    _mv_generalized_directional_derivative(
                        trial_evaluation,
                        something(trial_curve_velocity),
                    )
                trial_branch_active =
                    !isempty(mv_evaluation.active_links) || !isempty(trial_evaluation.active_links)
                objective_ok = _localization_objective_accepts(
                    localization_algorithm,
                    config.solver.acceleration.u_acceptance,
                    old_objective,
                    trial_objective,
                    objective_tolerance,
                    step_scale,
                    trial_directional_derivative,
                    config.solver.acceleration.u_armijo_c1,
                    trial_directional_derivative = wolfe_trial_derivative,
                    wolfe_c2 = config.solver.acceleration.u_wolfe_c2,
                    branch_active = trial_branch_active,
                )
                trial_candidate = (
                    frames = trial_frames,
                    centers = trial_centers,
                    spreads = trial_spreads,
                    directional = trial_directional,
                    step_scale = step_scale,
                    backtracking_steps = backtrack,
                    objective = trial_objective,
                    required_change = required_change,
                    actual_change = actual_change,
                    directional_derivative = trial_directional_derivative,
                    fixed_projector_drift = trial_projector_drift,
                    mode = mode,
                    evaluation = trial_evaluation,
                    branch_active_set_changed = mv_evaluation.active_orbit_definitions !=
                                                trial_evaluation.active_orbit_definitions,
                )
                fr_best_finite_descent = _best_fletcher_reeves_finite_descent(
                    fr_best_finite_descent,
                    trial_candidate,
                    localization_algorithm,
                    invariant_failure,
                    old_objective,
                )
                if invariant_failure === nothing && objective_ok
                    attempted_accepted[end] = true
                    accepted_trial = trial_candidate
                    break
                end
                last_failure =
                    invariant_failure === nothing ?
                    (:LOCALIZATION_ACCEPTANCE_REJECTED, actual_change) : invariant_failure
            end
            accepted_trial !== nothing && break
            if mode in
               (:smv_fletcher_reeves_two_stage, :symmetry_projected_smv_fletcher_reeves_two_stage)
                if !cg_restarted
                    cg_restarted = true
                    cg_restart_reason = :LINE_SEARCH_RESTART
                end
                carried_cg_restart_count += 1
            end
        end
        if accepted_trial === nothing && fr_best_finite_descent !== nothing
            fallback_trial = something(fr_best_finite_descent)
            accepted_trial = fallback_trial
            cg_restart_reason =
                fallback_trial.mode == :gradient ? :STEEPEST_DESCENT_STRONG_WOLFE_FALLBACK :
                :PARABOLIC_FIT_FINITE_DESCENT_FALLBACK
            attempted_accepted[argmin(attempted_objectives)] = true
        end
        numerical_stagnation =
            accepted_trial === nothing &&
            !isempty(attempted_step_scales) &&
            abs(last(attempted_step_scales) * gradient_directional_derivative) <=
            64eps(Float64) * max(1.0, abs(base_objective)) &&
            gradient_rms > config.solver.acceleration.u_gradient_norm_tolerance
        accepted_trial === nothing && return (
            success = false,
            code = numerical_stagnation ? :U_NUMERICAL_STAGNATION :
                   :SPREAD_GRADIENT_LINE_SEARCH_FAILED,
            message = numerical_stagnation ?
                      "predicted U decrease fell below floating-point resolution before generalized-gradient convergence" :
                      "localization search exhausted $(config.solver.acceleration.u_acceptance) trials",
            kpoint = 0,
            sweep = sweep,
            singular_values = Float64[],
            rank = 0,
            condition = Inf,
            acceptance_failure = last_failure,
            backtracking_steps = isempty(attempted_step_scales) ? 0 :
                                 length(attempted_step_scales) - 1,
            attempted_step_scales = attempted_step_scales,
            attempted_objectives = attempted_objectives,
            attempted_required_changes = attempted_required_changes,
            attempted_actual_changes = attempted_actual_changes,
            attempted_directional_derivatives = attempted_directional_derivatives,
            attempted_sweeps = attempted_sweeps,
            attempted_accepted = attempted_accepted,
            old_objective = old_objective,
            base_objective = base_objective,
            trial_zero_objective = trial_zero_objective,
            trial_zero_frame_residual = trial_zero_frame_residual,
            gradient_rms = gradient_rms,
            directional_derivative = gradient_directional_derivative,
            fixed_projector_drift = fixed_projector_drift,
            minimum_diagonal_phase_margin = minimum_diagonal_phase_margin,
            minimum_phase_kpoint = minimum_phase_kpoint,
            minimum_phase_neighbor = minimum_phase_neighbor,
            minimum_phase_wannier = minimum_phase_wannier,
            minimum_phase_value = minimum_phase_value,
            branch_safe_backtracking_triggered = branch_safe_backtracking_triggered,
            cg_beta = cg_beta,
            cg_restarted = cg_restarted,
            cg_restart_reason = cg_restart_reason,
            cg_descent_cosine = cg_descent_cosine,
            frames = frames,
            centers = centers,
            spreads = spreads,
        )

        trial = something(accepted_trial)
        next_frames = trial.frames
        # Only multi-sweep or non-ordinary routes consume the distance for stopping.
        u_step =
            measure_frame_distance ?
            maximum(
                _frame_geodesic_distance(
                    frames[kpoint],
                    next_frames[kpoint],
                    config.input.representation_tolerance,
                ) for kpoint in irreducible
            ) : nothing
        frames = next_frames
        centers = trial.centers
        spreads = trial.spreads
        directional = trial.directional
        maximum_u_step = u_step
        completed_sweeps = sweep
        accepted_step_scale = trial.step_scale
        backtracking_steps += trial.backtracking_steps
        accepted_objective = trial.objective
        directional_derivative = trial.directional_derivative
        accepted_required_change = trial.required_change
        accepted_actual_change = trial.actual_change
        active_algorithm =
            trial.mode == :symmetry_projected_smv_fletcher_reeves_two_stage ?
            :symmetry_projected_smv_fletcher_reeves_two_stage :
            trial.mode == :smv_fletcher_reeves_two_stage ? :smv_fletcher_reeves_two_stage :
            apply_symmetry ? :symmetry_projected_gradient : :ordinary_full_bz_gradient
        if localization_algorithm == :smv_fletcher_reeves_two_stage
            carried_u_gradient = deepcopy(steepest_representative)
            if lowercase(strip(get(ENV, "WANNIERNLQG_LOCALIZATION_DEBUG_GRADIENT", "0"))) in
               ("1", "true", "yes")
                println(
                    stderr,
                    "LOCALIZATION_CARRIED_GRADIENT_KCOUNT=" * string(length(carried_u_gradient)),
                )
            end
            carried_u_direction = deepcopy(search_representative)
            carried_cg_iteration = next_conjugate_gradient_count
            carried_branch_signature = "u-branch-input/1\nREFERENCE\n"
            accepted_cg_beta = cg_beta
            accepted_cg_restarted = cg_restarted
            accepted_cg_restart_reason = cg_restart_reason
            accepted_cg_descent_cosine = cg_descent_cosine
            carried_reference_overlaps = trial.recursive_localization_overlaps
            carried_reference_unitaries = trial.recursive_localization_unitaries
        elseif localization_algorithm == :symmetry_projected_smv_fletcher_reeves_two_stage
            branch_restart = trial.branch_active_set_changed
            if branch_restart
                cg_restarted = true
                cg_restart_reason = :PHASE_BRANCH_ACTIVE_SET_CHANGED
                carried_cg_restart_count += 1
            end
            if trial.mode == :symmetry_projected_smv_fletcher_reeves_two_stage && !branch_restart
                carried_u_gradient = deepcopy(steepest_representative)
                carried_u_direction = deepcopy(search_representative)
                carried_cg_iteration += 1
            else
                if !cg_restarted
                    cg_restarted = true
                    cg_restart_reason = :PROJECTED_GRADIENT_RESTART
                    carried_cg_restart_count += 1
                end
                carried_u_gradient = deepcopy(steepest_representative)
                carried_u_direction = deepcopy(steepest_representative)
                carried_cg_iteration = 1
                cg_beta = 0.0
                cg_descent_cosine = 1.0
            end
            accepted_cg_beta = cg_beta
            accepted_cg_restarted = cg_restarted
            accepted_cg_restart_reason = cg_restart_reason
            accepted_cg_descent_cosine = cg_descent_cosine
        else
            carried_u_gradient = nothing
            carried_u_direction = nothing
            carried_cg_iteration = 0
            accepted_cg_beta = NaN
            accepted_cg_restarted = false
            accepted_cg_restart_reason = :NOT_APPLICABLE
            accepted_cg_descent_cosine = NaN
        end
        carried_branch_signature = _u_branch_definition(trial.evaluation.active_orbit_definitions)
        carried_active_orbit_count = length(trial.evaluation.active_orbit_definitions)
        gradient_rms = trial.evaluation.gradient_rms
        if reuse_reference
            accepted_definition = _reference_evaluation_definition(
                config,
                representation,
                mmn,
                weights,
                frames,
                phase_reference_centers,
                carried_reference_overlaps,
                reference_omega_i,
                geometry,
            )
            _save_reference_evaluation!(accepted_evaluation, accepted_definition, trial.evaluation)
        end
        if measure_frame_distance &&
           gradient_rms <= config.solver.acceleration.u_gradient_norm_tolerance &&
           u_step <= config.solver.acceleration.u_inner_tolerance
            break
        end
    end
    if localization_algorithm == :smv_fletcher_reeves_two_stage && config.solver.parallel == :mpi
        _mpi_root_canonical_matrix_field!(frames, config.solver.parallel)
        _mpi_root_canonical_array!(centers, config.solver.parallel)
        _mpi_root_canonical_array!(spreads, config.solver.parallel)
        if directional isa Tuple
            directional = ntuple(
                index -> _mpi_root_canonical_scalar(directional[index], config.solver.parallel),
                length(directional),
            )
        elseif directional !== nothing
            _mpi_root_canonical_array!(directional, config.solver.parallel)
        end
        carried_u_gradient =
            _mpi_root_canonical_optional_matrix_field(carried_u_gradient, config.solver.parallel)
        carried_u_direction =
            _mpi_root_canonical_optional_matrix_field(carried_u_direction, config.solver.parallel)
        carried_reference_overlaps =
            _mpi_root_canonical_optional_array(carried_reference_overlaps, config.solver.parallel)
        carried_reference_unitaries = _mpi_root_canonical_optional_matrix_field(
            carried_reference_unitaries,
            config.solver.parallel,
        )
        for value in (
            attempted_step_scales,
            attempted_objectives,
            attempted_required_changes,
            attempted_actual_changes,
            attempted_directional_derivatives,
        )
            _mpi_root_canonical_array!(value, config.solver.parallel)
        end
        for value in (attempted_sweeps, attempted_accepted)
            _mpi_root_canonical_array!(value, config.solver.parallel)
        end
        maximum_u_step = _mpi_root_canonical_optional_scalar(maximum_u_step, config.solver.parallel)
        gradient_rms = _mpi_root_canonical_scalar(gradient_rms, config.solver.parallel)
        accepted_step_scale =
            _mpi_root_canonical_scalar(accepted_step_scale, config.solver.parallel)
        trial_objective = _mpi_root_canonical_scalar(trial_objective, config.solver.parallel)
        accepted_objective = _mpi_root_canonical_scalar(accepted_objective, config.solver.parallel)
        base_objective = _mpi_root_canonical_scalar(base_objective, config.solver.parallel)
        trial_zero_objective =
            _mpi_root_canonical_scalar(trial_zero_objective, config.solver.parallel)
        trial_zero_frame_residual =
            _mpi_root_canonical_scalar(trial_zero_frame_residual, config.solver.parallel)
        directional_derivative =
            _mpi_root_canonical_scalar(directional_derivative, config.solver.parallel)
        fixed_projector_drift =
            _mpi_root_canonical_scalar(fixed_projector_drift, config.solver.parallel)
        accepted_required_change =
            _mpi_root_canonical_scalar(accepted_required_change, config.solver.parallel)
        accepted_actual_change =
            _mpi_root_canonical_scalar(accepted_actual_change, config.solver.parallel)
        accepted_cg_beta = _mpi_root_canonical_scalar(accepted_cg_beta, config.solver.parallel)
        accepted_cg_descent_cosine =
            _mpi_root_canonical_scalar(accepted_cg_descent_cosine, config.solver.parallel)
        transport_minimum_singular_value =
            _mpi_root_canonical_scalar(transport_minimum_singular_value, config.solver.parallel)
        transport_maximum_condition =
            _mpi_root_canonical_scalar(transport_maximum_condition, config.solver.parallel)
        transported_omega_i =
            _mpi_root_canonical_scalar(transported_omega_i, config.solver.parallel)
        reference_omega_i =
            _mpi_root_canonical_optional_scalar(reference_omega_i, config.solver.parallel)
    end
    return (
        success = true,
        code = :OK,
        frames = frames,
        centers = centers,
        spreads = spreads,
        directional = directional,
        u_residual = maximum_u_step,
        gradient_rms = gradient_rms,
        projection_converged = true,
        projection_iterations = 0,
        projection_residual = 0.0,
        completed_sweeps = completed_sweeps,
        accepted_step_scale = accepted_step_scale,
        backtracking_steps = backtracking_steps,
        trial_objective = trial_objective,
        accepted_objective = accepted_objective,
        maximum_kstar_gradient_rms = NaN,
        maximum_kstar_gradient_index = -1,
        polar_fallback_triggered = polar_fallback_triggered,
        active_localization_algorithm = active_algorithm,
        base_objective = base_objective,
        trial_zero_objective = trial_zero_objective,
        trial_zero_frame_residual = trial_zero_frame_residual,
        attempted_step_scales = attempted_step_scales,
        attempted_objectives = attempted_objectives,
        attempted_required_changes = attempted_required_changes,
        attempted_actual_changes = attempted_actual_changes,
        attempted_directional_derivatives = attempted_directional_derivatives,
        attempted_sweeps = attempted_sweeps,
        attempted_accepted = attempted_accepted,
        directional_derivative = directional_derivative,
        fixed_projector_drift = fixed_projector_drift,
        accepted_required_change = accepted_required_change,
        accepted_actual_change = accepted_actual_change,
        minimum_diagonal_phase_margin = minimum_diagonal_phase_margin,
        minimum_phase_kpoint = minimum_phase_kpoint,
        minimum_phase_neighbor = minimum_phase_neighbor,
        minimum_phase_wannier = minimum_phase_wannier,
        minimum_phase_value = minimum_phase_value,
        branch_safe_backtracking_triggered = branch_safe_backtracking_triggered,
        previous_u_gradient = carried_u_gradient,
        previous_u_direction = carried_u_direction,
        u_cg_iteration = carried_cg_iteration,
        u_cg_restart_count = carried_cg_restart_count,
        cg_beta = accepted_cg_beta,
        cg_restarted = accepted_cg_restarted,
        cg_restart_reason = accepted_cg_restart_reason,
        cg_descent_cosine = accepted_cg_descent_cosine,
        transport_minimum_singular_value = transport_minimum_singular_value,
        transport_maximum_condition = transport_maximum_condition,
        transported_omega_i = transported_omega_i,
        u_phase_contract = LOCALIZATION_GRADIENT_CONTRACT,
        u_active_orbit_definition = carried_branch_signature,
        u_active_orbit_count = carried_active_orbit_count,
        generalized_gradient_rms = gradient_rms,
        u_optimizer_restart_reason = accepted_u_optimizer_restart_reason,
        recursive_localization_overlaps = carried_reference_overlaps,
        recursive_localization_omega_i = reference_omega_i,
        recursive_localization_unitaries = carried_reference_unitaries,
    )
end
