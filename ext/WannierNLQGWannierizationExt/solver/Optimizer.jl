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

# Mix Z only after a previous iterate exists.  The first WannierBerri update
# stores the freshly constructed Z unchanged and therefore has no projector
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

# Pack Hermitian outer-block Z fields into deterministic real IBZ coordinates.
function _pack_hermitian_z(
    field::Vector{Matrix{ComplexF64}},
    outer_indices::Vector{Vector{Int}},
    irreducible_indices::Vector{Int},
)
    values = Float64[]
    for kpoint in irreducible_indices
        outer = outer_indices[kpoint]
        block = @view field[kpoint][outer, outer]
        for row in axes(block, 1)
            push!(values, real(block[row, row]))
            for column in (row + 1):size(block, 2)
                push!(values, real(block[row, column]), imag(block[row, column]))
            end
        end
    end
    return values
end

# Unpack deterministic real coordinates without modifying non-outer entries.
function _unpack_hermitian_z(
    values::AbstractVector{<:Real},
    template::Vector{Matrix{ComplexF64}},
    outer_indices::Vector{Vector{Int}},
    irreducible_indices::Vector{Int},
)
    field = deepcopy(template)
    offset = 1
    for kpoint in irreducible_indices
        outer = outer_indices[kpoint]
        block = zeros(ComplexF64, length(outer), length(outer))
        for row in axes(block, 1)
            block[row, row] = Float64(values[offset])
            offset += 1
            for column in (row + 1):size(block, 2)
                value = ComplexF64(values[offset], values[offset + 1])
                block[row, column] = value
                block[column, row] = conj(value)
                offset += 2
            end
        end
        field[kpoint][outer, outer] .= block
    end
    offset == length(values) + 1 || throw(DimensionMismatch("packed Z coordinate length disagrees"))
    return field
end

# Keep acceleration safeguard decisions pure so rollback and fallback policies
# can be exercised deterministically without perturbing a scientific iterate.
function _acceleration_trial_action(strategy::Symbol, attempt::Int, invariant_failure)
    invariant_failure === nothing && return :accept
    attempt == 1 && strategy != :fixed && return :retry_safe_linear
    return :typed_failure
end

# Shrink adaptive Z/U ratios within their independently configured safe bounds.
function _shrunken_acceleration_mixing(z_mix, u_mix, acceleration)
    return (
        clamp(z_mix * acceleration.adaptive_shrink, acceleration.adaptive_z_bounds...),
        clamp(u_mix * acceleration.adaptive_shrink, acceleration.adaptive_u_bounds...),
    )
end

# Adjust only the next adaptive step from the formal convergence metric; never reject an accepted state.
function _adaptive_next_mixing(
    z_mix,
    u_mix,
    improvement_streak,
    previous_convergence_metric,
    convergence_metric,
    acceleration,
)
    isfinite(previous_convergence_metric) && isfinite(convergence_metric) || return z_mix, u_mix, 0
    if convergence_metric <= acceleration.adaptive_improvement_ratio * previous_convergence_metric
        improvement_streak += 1
        if improvement_streak >= acceleration.adaptive_patience
            return (
                clamp(z_mix * acceleration.adaptive_growth, acceleration.adaptive_z_bounds...),
                clamp(u_mix * acceleration.adaptive_growth, acceleration.adaptive_u_bounds...),
                0,
            )
        end
        return z_mix, u_mix, improvement_streak
    elseif convergence_metric > acceleration.adaptive_reject_ratio * previous_convergence_metric
        next_z, next_u = _shrunken_acceleration_mixing(z_mix, u_mix, acceleration)
        return next_z, next_u, 0
    end
    return z_mix, u_mix, 0
end

# Decide whether Anderson may propose a trial and whether a near-gap event resets history.
function _anderson_trial_policy(
    strategy::Symbol,
    attempt::Int,
    iteration::Int,
    start_iteration::Int,
    has_previous_z::Bool,
    boundary_gap::Float64,
    tolerance::Float64,
)
    reset_history = strategy == :anderson_z && boundary_gap < 10tolerance
    allow =
        strategy == :anderson_z &&
        attempt == 1 &&
        iteration >= start_iteration &&
        has_previous_z &&
        !reset_history
    return allow, reset_history
end

# Build one Anderson combination with pivoted QR and explicit Tikhonov rows.
# Objective and structural acceptance are deliberately evaluated by the outer
# solver against the simultaneously constructed linear proposal.
function _anderson_z_proposal(
    z_raw::Vector{Matrix{ComplexF64}},
    z_previous::Vector{Matrix{ComplexF64}},
    linear_proposal::Vector{Matrix{ComplexF64}},
    outer_indices::Vector{Vector{Int}},
    irreducible_indices::Vector{Int},
    z_history::Matrix{Float64},
    residual_history::Matrix{Float64},
    acceleration::WannierizationAccelerationConfig,
)
    raw_vector = _pack_hermitian_z(z_raw, outer_indices, irreducible_indices)
    previous_vector = _pack_hermitian_z(z_previous, outer_indices, irreducible_indices)
    residual_vector = raw_vector - previous_vector
    history_z = isempty(z_history) ? reshape(raw_vector, :, 1) : hcat(z_history, raw_vector)
    history_residual =
        isempty(residual_history) ? reshape(residual_vector, :, 1) :
        hcat(residual_history, residual_vector)
    retained = max(1, size(history_z, 2) - acceleration.anderson_depth + 1):size(history_z, 2)
    history_z = history_z[:, retained]
    history_residual = history_residual[:, retained]
    size(history_z, 2) >= 2 || return (
        proposal = linear_proposal,
        z_history = history_z,
        residual_history = history_residual,
        available = false,
        reason = :HISTORY_INSUFFICIENT,
        coefficient_norm = NaN,
        linear_residual = NaN,
        proposal_residual = NaN,
    )

    count = size(history_z, 2)
    differences = history_residual[:, 1:(count - 1)] .- history_residual[:, count]
    regularization = sqrt(acceleration.anderson_regularization)
    system =
        regularization == 0.0 ? differences :
        vcat(differences, regularization .* Matrix{Float64}(I, count - 1, count - 1))
    right_hand_side =
        regularization == 0.0 ? -history_residual[:, count] :
        vcat(-history_residual[:, count], zeros(Float64, count - 1))
    coefficients_head = try
        qr(system, ColumnNorm()) \ right_hand_side
    catch
        return (
            proposal = linear_proposal,
            z_history = history_z,
            residual_history = history_residual,
            available = false,
            reason = :QR_SOLVE_FAILED,
            coefficient_norm = Inf,
            linear_residual = NaN,
            proposal_residual = NaN,
        )
    end
    coefficients = vcat(coefficients_head, 1.0 - sum(coefficients_head))
    coefficient_norm = norm(coefficients)
    if !all(isfinite, coefficients)
        return (
            proposal = linear_proposal,
            z_history = history_z,
            residual_history = history_residual,
            available = false,
            reason = :NONFINITE_COEFFICIENTS,
            coefficient_norm,
            linear_residual = NaN,
            proposal_residual = NaN,
        )
    elseif coefficient_norm > 10.0
        return (
            proposal = linear_proposal,
            z_history = history_z,
            residual_history = history_residual,
            available = false,
            reason = :COEFFICIENT_NORM_EXCEEDED,
            coefficient_norm,
            linear_residual = NaN,
            proposal_residual = NaN,
        )
    end
    proposal_vector = history_z * coefficients
    linear_vector = _pack_hermitian_z(linear_proposal, outer_indices, irreducible_indices)
    linear_residual = norm(raw_vector - linear_vector)
    proposal_residual = norm(raw_vector - proposal_vector)
    proposal =
        _unpack_hermitian_z(proposal_vector, linear_proposal, outer_indices, irreducible_indices)
    return (
        proposal,
        z_history = history_z,
        residual_history = history_residual,
        available = true,
        reason = :PROPOSAL_AVAILABLE,
        coefficient_norm,
        linear_residual,
        proposal_residual,
    )
end

"""Pure objective/projector/Z-residual decision used by the Anderson safeguard."""
function _objective_aware_anderson_decision(
    omega_linear::Float64,
    omega_anderson::Float64,
    projector_linear::Float64,
    projector_anderson::Float64,
    linear_z_residual::Float64,
    anderson_z_residual::Float64,
    acceleration::WannierizationAccelerationConfig,
)
    objective_tolerance = max(
        acceleration.disentanglement_objective_tolerance,
        64eps(Float64) * max(1.0, abs(omega_linear), abs(omega_anderson)),
    )
    residual_tolerance = max(
        acceleration.z_projector_tolerance,
        64eps(Float64) *
        max(1.0, projector_linear, projector_anderson, linear_z_residual, anderson_z_residual),
    )
    objective_improved = omega_anderson <= omega_linear - objective_tolerance
    projector_not_worse = projector_anderson <= projector_linear + residual_tolerance
    z_not_worse = anderson_z_residual <= linear_z_residual + residual_tolerance
    reason =
        !objective_improved ? :OBJECTIVE_NOT_IMPROVED :
        !projector_not_worse ? :PROJECTOR_RESIDUAL_WORSENED :
        !z_not_worse ? :Z_RESIDUAL_WORSENED : :OBJECTIVE_SAFEGUARD_ACCEPTED
    return (
        accepted = objective_improved && projector_not_worse && z_not_worse,
        reason,
        omega_linear,
        omega_anderson,
        projector_linear,
        projector_anderson,
    )
end

"""Apply the objective-aware Anderson safeguard against the same linear base."""
function _objective_aware_anderson_accepts(
    linear_candidate,
    anderson_candidate,
    current_frames::Vector{Matrix{ComplexF64}},
    mmn::WannierMMN,
    weights::Vector{Float64},
    linear_z_residual::Float64,
    anderson_z_residual::Float64,
    acceleration::WannierizationAccelerationConfig,
)
    linear_candidate.success || return (
        accepted = false,
        reason = :LINEAR_REFERENCE_FAILED,
        omega_linear = NaN,
        omega_anderson = NaN,
        projector_linear = NaN,
        projector_anderson = NaN,
    )
    anderson_candidate.success || return (
        accepted = false,
        reason = :STRUCTURAL_GATE_REJECTED,
        omega_linear = _gauge_invariant_spread(linear_candidate.frames, mmn, weights),
        omega_anderson = NaN,
        projector_linear = _maximum_projector_step(current_frames, linear_candidate.frames),
        projector_anderson = NaN,
    )
    return _objective_aware_anderson_decision(
        _gauge_invariant_spread(linear_candidate.frames, mmn, weights),
        _gauge_invariant_spread(anderson_candidate.frames, mmn, weights),
        _maximum_projector_step(current_frames, linear_candidate.frames),
        _maximum_projector_step(current_frames, anderson_candidate.frames),
        linear_z_residual,
        anderson_z_residual,
        acceleration,
    )
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
    packed_fields = [cat(field...; dims = 3) for field in history]
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

"""Riemannian L-BFGS two-loop direction for stored MV descent fields."""
function _riemannian_lbfgs_direction(
    descent::Vector{Matrix{ComplexF64}},
    s_history::Vector{Vector{Matrix{ComplexF64}}},
    y_history::Vector{Vector{Matrix{ComplexF64}}},
    rho_history::Vector{Float64},
    irreducible_indices::Vector{Int},
)
    length(s_history) == length(y_history) == length(rho_history) ||
        throw(DimensionMismatch("L-BFGS history lengths disagree"))
    isempty(s_history) && return deepcopy(descent)
    # Stored fields are descent fields D=-grad(f); conventional two-loop starts
    # from the objective gradient and returns -H*grad(f).
    q = [-value for value in descent]
    alpha = zeros(Float64, length(s_history))
    for index in reverse(eachindex(s_history))
        alpha[index] =
            rho_history[index] * _ibz_tangent_inner(s_history[index], q, irreducible_indices)
        for kpoint in eachindex(q)
            q[kpoint] .-= alpha[index] .* y_history[index][kpoint]
        end
    end
    last_s = last(s_history)
    last_y = last(y_history)
    yy = _ibz_tangent_inner(last_y, last_y, irreducible_indices)
    gamma = yy <= eps(Float64) ? 1.0 : _ibz_tangent_inner(last_s, last_y, irreducible_indices) / yy
    r = [gamma .* value for value in q]
    for index in eachindex(s_history)
        beta = rho_history[index] * _ibz_tangent_inner(y_history[index], r, irreducible_indices)
        for kpoint in eachindex(r)
            r[kpoint] .+= (alpha[index] - beta) .* s_history[index][kpoint]
        end
    end
    return [-value for value in r]
end

"""Digest the ordered branch-orbit inventory used by one accepted U state."""
function _u_branch_signature(digests::Vector{String})
    isempty(digests) && return bytes2hex(SHA.sha256("SMOOTH_CHART"))
    return bytes2hex(SHA.sha256(join(sort(digests), '\n')))
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

"""Wannier90-style parabolic trial after one finite line-search probe.

The derivative is evaluated at zero and `trial_objective` at `trial_step`.
An ill-conditioned or non-convex fit returns the deterministic geometric
fallback instead of turning a finite optimizer state into a structural HOLD.
"""
function _wannier90_parabolic_trial_scale(
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

"""Wannier90 4.0.1 `internal_optimal_step`, without added clamping/fallbacks."""
function _wannier90_reference_optimal_step(
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

"""Apply the exact Wannier90 4.0.1 anti-Hermitian exponential U update."""
function _wannier90_reference_unitary_step(
    old_unitary::Matrix{ComplexF64},
    search_direction::Matrix{ComplexF64},
    alpha::Float64,
    weight_total::Float64,
)
    isfinite(alpha) && isfinite(weight_total) && weight_total > 0.0 || return nothing
    size(search_direction, 1) == size(search_direction, 2) || return nothing
    scaled = (alpha / (4.0 * weight_total)) .* search_direction
    decomposition = _wannier90_reference_zheev(1.0im .* scaled)
    decomposition.success || return nothing
    phases = [
        _wannier90_reference_complex_exponential(ComplexF64(0.0, -value)) for
        value in decomposition.values
    ]
    rotated_vectors = similar(decomposition.vectors)
    for column in axes(rotated_vectors, 2), row in axes(rotated_vectors, 1)
        # gfortran-16 lowers this specific array assignment with the imaginary
        # lane as the fused multiplicand.  The algebraically identical generic
        # complex product changes U1 by a few ulps; the parabolic FR step then
        # amplifies that change.  This local scalar helper reproduces the
        # compiler operation order without importing any observer state or
        # external Wannier90 kernel.
        rotated_vectors[row, column] = _wannier90_reference_gfortran_phase_column_product(
            decomposition.vectors[row, column],
            phases[column],
        )
    end
    rotation = _wannier90_reference_zgemm(rotated_vectors, 'N', decomposition.vectors, 'C')
    trial = _wannier90_reference_zgemm(old_unitary, 'N', rotation, 'N')
    all(isfinite, trial) || return nothing
    return Matrix{ComplexF64}(trial)
end

"""Wannier90 4.0.1 Fletcher--Reeves state update in the full-k gauge."""
function _wannier90_reference_search_direction(
    gradient::Vector{Matrix{ComplexF64}},
    previous_gradient::Union{Nothing, Vector{Matrix{ComplexF64}}},
    previous_direction::Union{Nothing, Vector{Matrix{ComplexF64}}},
    cg_count::Int,
    restart_interval::Int,
    weight_total::Float64,
)
    weight_total > 0.0 && isfinite(weight_total) || throw(ArgumentError("invalid W90 weight total"))
    current_norm = _wannier90_reference_zdot(gradient, gradient)
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
        previous_norm =
            _wannier90_reference_zdot(something(previous_gradient), something(previous_gradient))
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
    derivative = -_wannier90_reference_zdot(gradient, direction) / (4.0 * weight_total)
    if derivative > 0.0
        if beta != 0.0
            direction = deepcopy(gradient)
            beta = 0.0
            next_count = 0
            restarted = true
            restart_reason = :UPHILL_CG_RESTART
            derivative = -_wannier90_reference_zdot(gradient, direction) / (4.0 * weight_total)
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

# Run one or more synchronized U-only sweeps for a fixed outer-iteration subspace.
function _localization_sweeps(
    config::SymmetryAdaptedWannierizationConfig,
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
    fixed_projectors::Union{Nothing, Vector{Matrix{ComplexF64}}} = nothing,
    previous_u_gradient::Union{Nothing, Vector{Matrix{ComplexF64}}} = nothing,
    previous_u_direction::Union{Nothing, Vector{Matrix{ComplexF64}}} = nothing,
    u_cg_iteration::Int = 0,
    u_cg_restart_count::Int = 0,
    u_lbfgs_s_history::Vector{Vector{Matrix{ComplexF64}}} = Vector{Vector{Matrix{ComplexF64}}}(),
    u_lbfgs_y_history::Vector{Vector{Matrix{ComplexF64}}} = Vector{Vector{Matrix{ComplexF64}}}(),
    u_lbfgs_rho_history::Vector{Float64} = Float64[],
    u_lbfgs_restart_count::Int = 0,
    u_branch_signature::String = "",
    wannier90_reference_overlaps::Union{Nothing, Array{ComplexF64, 4}} = nothing,
    wannier90_reference_omega_i::Union{Nothing, Float64} = nothing,
    wannier90_reference_unitaries::Union{Nothing, Vector{Matrix{ComplexF64}}} = nothing,
)
    Threads.atomic_add!(_LOCALIZATION_SWEEP_ENTRY_COUNT, 1)
    apply_symmetry = symmetry_constraints_applied(config, representation)
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
        wannier90_reference_unitaries = _mpi_root_canonical_optional_matrix_field(
            wannier90_reference_unitaries === nothing ? nothing :
            deepcopy(something(wannier90_reference_unitaries)),
            config.solver.parallel,
        )
        wannier90_reference_overlaps =
            _mpi_root_canonical_optional_array(wannier90_reference_overlaps, config.solver.parallel)
        u_cg_iteration = _mpi_root_canonical_scalar(u_cg_iteration, config.solver.parallel)
        u_cg_restart_count = _mpi_root_canonical_scalar(u_cg_restart_count, config.solver.parallel)
        wannier90_reference_omega_i =
            _mpi_root_canonical_optional_scalar(wannier90_reference_omega_i, config.solver.parallel)
    end
    directional = nothing
    maximum_u_step = 0.0
    completed_sweeps = 0
    accepted_step_scale = 0.0
    backtracking_steps = 0
    trial_objective = sum(initial_spreads)
    accepted_objective = trial_objective
    gradient_rms = Inf
    localization_spectra = [Float64[] for _ in eachindex(initial_frames)]
    localization_ranks = zeros(Int, length(initial_frames))
    localization_conditions = fill(NaN, length(initial_frames))
    raw_eigenphases = [Float64[] for _ in eachindex(initial_frames)]
    raw_geodesic_distances = fill(NaN, length(initial_frames))
    global_permutation = Int[]
    global_phases = Float64[]
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
    carried_lbfgs_s_history = deepcopy(u_lbfgs_s_history)
    carried_lbfgs_y_history = deepcopy(u_lbfgs_y_history)
    carried_lbfgs_rho_history = copy(u_lbfgs_rho_history)
    carried_lbfgs_restart_count = u_lbfgs_restart_count
    carried_branch_signature = u_branch_signature
    carried_active_orbit_count = 0
    accepted_u_optimizer_restart_reason = :NOT_APPLICABLE
    last_mv_evaluation::Union{Nothing, MVLocalizationEvaluation} = nothing
    accepted_cg_beta = NaN
    accepted_cg_restarted = false
    accepted_cg_restart_reason = :NOT_APPLICABLE
    accepted_cg_descent_cosine = NaN
    kstar_gradient_rms = Float64[]
    maximum_kstar_gradient_index = 0
    transport_minimum_singular_value = Inf
    transport_maximum_condition = 0.0
    transported_omega_i = NaN
    carried_reference_overlaps = wannier90_reference_overlaps
    reference_omega_i = wannier90_reference_omega_i
    carried_reference_unitaries =
        wannier90_reference_unitaries === nothing ? nothing :
        deepcopy(something(wannier90_reference_unitaries))

    for sweep in 1:config.solver.acceleration.u_inner_sweeps
        # Every U search starts from F0 = S * polar(S' * F_old). Recompute all
        # objective-dependent data at F0 before evaluating the gradient.
        base_frames = deepcopy(frames)
        if localization_algorithm == :smv_fletcher_reeves_two_stage
            # Wannier90 carries the last accepted U directly into the next
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
        # Wannier90 ordinary MLWF localization starts with `sheet = 0` and
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
            reference_omega_i = _wannier90_reference_invariant_spread(
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
                u_residual = 0.0,
                gradient_rms = Inf,
                projection_converged = true,
                projection_iterations = 0,
                projection_residual = 0.0,
                completed_sweeps = completed_sweeps,
                accepted_step_scale = 0.0,
                backtracking_steps = 0,
                trial_objective = trial_objective,
                accepted_objective = accepted_objective,
                localization_spectra = localization_spectra,
                localization_ranks = localization_ranks,
                localization_conditions = localization_conditions,
                raw_eigenphases = raw_eigenphases,
                aligned_eigenphases = deepcopy(raw_eigenphases),
                raw_geodesic_distances = raw_geodesic_distances,
                aligned_geodesic_distances = copy(raw_geodesic_distances),
                block_permutations = [copy(global_permutation) for _ in eachindex(frames)],
                block_phases = [copy(global_phases) for _ in eachindex(frames)],
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
                kstar_gradient_rms = Float64[],
                maximum_kstar_gradient_rms = NaN,
                maximum_kstar_gradient_index = 0,
                transport_minimum_singular_value = transport_minimum_singular_value,
                transport_maximum_condition = transport_maximum_condition,
                transported_omega_i = transported_omega_i,
                u_phase_contract = LOCALIZATION_GRADIENT_CONTRACT,
                u_active_orbit_sha256 = carried_branch_signature,
                u_active_orbit_count = 0,
                generalized_gradient_rms = Inf,
                u_lbfgs_s_history = carried_lbfgs_s_history,
                u_lbfgs_y_history = carried_lbfgs_y_history,
                u_lbfgs_rho_history = carried_lbfgs_rho_history,
                u_lbfgs_restart_count = carried_lbfgs_restart_count,
                u_optimizer_restart_reason = :NOT_APPLICABLE,
            )
        end

        evaluation_result = _evaluate_mv_localization(
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
            localization_algorithm == :smv_fletcher_reeves_two_stage ? reference_omega_i : nothing,
        )
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
        carried_active_orbit_count = length(mv_evaluation.active_orbit_digests)
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
        kstar_gradient_rms, maximum_kstar_gradient_index =
            _kstar_gradient_distribution(projected.full_gradients, representation)
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
        if gradient_rms <= config.solver.acceleration.u_gradient_norm_tolerance
            completed_sweeps = sweep
            maximum_u_step = 0.0
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
            accepted_cg_restarted = localization_algorithm in (
                :riemannian_cg,
                :smv_fletcher_reeves_two_stage,
                :symmetry_projected_smv_fletcher_reeves_two_stage,
            )
            accepted_cg_restart_reason = :GRADIENT_CONVERGED_ZERO_STEP
            accepted_cg_descent_cosine = 1.0
            carried_branch_signature = _u_branch_signature(mv_evaluation.active_orbit_digests)
            carried_active_orbit_count = length(mv_evaluation.active_orbit_digests)
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
        wannier90_derivative_at_zero = NaN
        wannier90_next_cg_count = carried_cg_iteration
        current_branch_signature = _u_branch_signature(mv_evaluation.active_orbit_digests)
        if localization_algorithm == :smv_fletcher_reeves_two_stage
            apply_symmetry && throw(
                ArgumentError(
                    "WANNIER90_REFERENCE_MODE_MISMATCH: the reference optimizer is ordinary no-symmetry only",
                ),
            )
            weight_total = _wannier90_reference_weight_total(weights)
            reference_direction = _wannier90_reference_search_direction(
                steepest_representative,
                carried_u_gradient,
                carried_u_direction,
                carried_cg_iteration,
                config.solver.acceleration.u_w90_restart_interval,
                weight_total,
            )
            reference_direction.success || return (
                success = false,
                code = :NONFINITE_LOCALIZATION_DIRECTION,
                message = "Wannier90-reference search direction is non-finite",
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
            wannier90_derivative_at_zero = reference_direction.derivative
            wannier90_next_cg_count = reference_direction.cg_count
            if config.solver.parallel == :mpi
                _mpi_root_canonical_matrix_field!(search_representative, config.solver.parallel)
                search_full = search_representative
                cg_beta = _mpi_root_canonical_scalar(cg_beta, config.solver.parallel)
                wannier90_derivative_at_zero =
                    _mpi_root_canonical_scalar(wannier90_derivative_at_zero, config.solver.parallel)
                wannier90_next_cg_count =
                    _mpi_root_canonical_scalar(wannier90_next_cg_count, config.solver.parallel)
                cg_restarted = _mpi_root_canonical_flag(cg_restarted, config.solver.parallel)
            end
            direction_norm_squared = _full_tangent_inner(search_full, search_full)
            cg_descent_cosine =
                direction_norm_squared <= eps(Float64) || projected.norm_squared <= eps(Float64) ?
                NaN :
                -_localization_directional_derivative(steepest_representative, search_full) /
                sqrt(projected.norm_squared * direction_norm_squared)
            cg_restarted && (carried_cg_restart_count += 1)
        elseif localization_algorithm in
               (:riemannian_cg, :symmetry_projected_smv_fletcher_reeves_two_stage)
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
                config.solver.acceleration.u_w90_restart_interval :
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
        elseif localization_algorithm == :riemannian_lbfgs
            cg_restart_reason = :NONE
            history_compatible =
                !isempty(carried_lbfgs_s_history) &&
                length(carried_lbfgs_s_history) ==
                length(carried_lbfgs_y_history) ==
                length(carried_lbfgs_rho_history) &&
                carried_branch_signature == current_branch_signature
            if history_compatible
                transported_s = [
                    apply_symmetry ?
                    _transport_ibz_tangent_field(value, irreducible, tangent_plans) :
                    [(entry - entry') ./ 2 for entry in value] for
                    value in carried_lbfgs_s_history
                ]
                transported_y = [
                    apply_symmetry ?
                    _transport_ibz_tangent_field(value, irreducible, tangent_plans) :
                    [(entry - entry') ./ 2 for entry in value] for
                    value in carried_lbfgs_y_history
                ]
                proposed = _riemannian_lbfgs_direction(
                    steepest_representative,
                    transported_s,
                    transported_y,
                    carried_lbfgs_rho_history,
                    irreducible,
                )
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
                direction_norm_squared = _full_tangent_inner(search_full, search_full)
                cg_descent_cosine =
                    direction_norm_squared <= eps(Float64) ||
                    projected.norm_squared <= eps(Float64) ? NaN :
                    -proposed_derivative / sqrt(projected.norm_squared * direction_norm_squared)
                if !isfinite(proposed_derivative) || proposed_derivative >= 0.0
                    cg_restarted = true
                    cg_restart_reason = :LBFGS_NON_DESCENT_DIRECTION
                elseif !isfinite(cg_descent_cosine) ||
                       cg_descent_cosine < config.solver.acceleration.u_cg_minimum_descent_cosine
                    cg_restarted = true
                    cg_restart_reason = :LBFGS_DESCENT_COSINE_TOO_SMALL
                end
            else
                cg_restarted = true
                cg_restart_reason =
                    isempty(carried_lbfgs_s_history) ? :LBFGS_EMPTY_HISTORY :
                    :LBFGS_BRANCH_CHART_CHANGED
            end
            if cg_restarted
                empty!(carried_lbfgs_s_history)
                empty!(carried_lbfgs_y_history)
                empty!(carried_lbfgs_rho_history)
                carried_lbfgs_restart_count += 1
                search_representative = steepest_representative
                search_full = projected.full_gradients
                accepted_u_optimizer_restart_reason = cg_restart_reason
                cg_descent_cosine = 1.0
            end
        end
        gradient_directional_derivative =
            _mv_generalized_directional_derivative(mv_evaluation, search_full)
        if config.solver.acceleration.u_acceptance in (:armijo, :strong_wolfe) &&
           (!isfinite(gradient_directional_derivative) || gradient_directional_derivative >= 0.0)
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
        polar_geodesics = Vector{Any}(undef, length(frames))
        fill!(polar_geodesics, nothing)
        maximum_gradient_rotation = 0.0
        maximum_steepest_rotation = 0.0
        maximum_polar_phase = 0.0
        polar_available =
            localization_algorithm == :polar_then_gradient &&
            sweep <= config.solver.acceleration.polar_warm_start_max_steps
        for kpoint in irreducible
            if localization_algorithm == :smv_fletcher_reeves_two_stage
                # This is the carried Wannier90 U itself.  A polar repair here
                # changes its last bits and therefore the next exponential
                # update and FR history.  Structural isometry is checked on the
                # physical frames before and after the accepted trial.
                old_unitaries[kpoint] =
                    carried_reference_unitaries === nothing ?
                    _wannier90_reference_zgemm(subspaces[kpoint], 'C', frames[kpoint], 'N') :
                    something(carried_reference_unitaries)[kpoint]
                maximum_gradient_rotation =
                    max(maximum_gradient_rotation, opnorm(search_representative[kpoint]))
                maximum_steepest_rotation =
                    max(maximum_steepest_rotation, opnorm(steepest_representative[kpoint]))
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
            polar_available || continue
            localization_sum = zeros(ComplexF64, size(old_polar.unitary))
            for neighbor in 1:mmn.num_neighbors
                target_kpoint = mmn.neighbors[neighbor, kpoint]
                displacement = _mesh_neighbor_displacement(representation, mmn, neighbor, kpoint)
                b_cartesian = transpose(representation.reciprocal_lattice) * displacement
                phases = cis.(centers * b_cartesian)
                localized_overlap =
                    subspaces[kpoint]' *
                    @view(mmn.data[:, :, neighbor, kpoint]) *
                    frames[target_kpoint]
                localized_overlap .*= transpose(phases)
                localization_sum .+= weights[neighbor] .* localized_overlap
            end
            polar = _localization_svd_polar(
                localization_sum,
                config.solver.numerical_thresholds.frame_transport_rtol,
                config.solver.numerical_thresholds.maximum_transport_condition,
            )
            localization_spectra[kpoint] = polar.singular_values
            localization_ranks[kpoint] = polar.rank
            localization_conditions[kpoint] = polar.condition
            if !polar.success
                polar_available = false
                continue
            end
            geodesic = _unitary_geodesic_plan(
                old_polar.unitary,
                polar.unitary,
                config.input.representation_tolerance,
            )
            if !geodesic.success
                polar_available = false
                continue
            end
            polar_geodesics[kpoint] = geodesic
            raw_eigenphases[kpoint] = geodesic.phases
            raw_geodesic_distances[kpoint] = geodesic.distance
            maximum_polar_phase = max(maximum_polar_phase, geodesic.maximum_phase)
        end

        function build_trial(mode::Symbol, scale::Float64)
            iszero(scale) && return deepcopy(frames)
            probe_frames = deepcopy(frames)
            for kpoint in irreducible
                old_u = something(old_unitaries[kpoint])
                trial_u = if mode == :polar
                    _unitary_geodesic_step(
                        old_u,
                        polar_geodesics[kpoint],
                        scale,
                        config.input.representation_tolerance,
                    )
                elseif mode == :smv_fletcher_reeves_two_stage
                    _wannier90_reference_unitary_step(
                        old_u,
                        search_representative[kpoint],
                        scale,
                        weight_total,
                    )
                else
                    tangent =
                        mode in (
                            :riemannian_cg,
                            :riemannian_lbfgs,
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

        function reference_rotations(scale::Float64)
            rotations = [
                Matrix{ComplexF64}(I, size(frames[kpoint], 2), size(frames[kpoint], 2)) for
                kpoint in eachindex(frames)
            ]
            for kpoint in irreducible
                rotation = _wannier90_reference_unitary_step(
                    Matrix{ComplexF64}(I, size(rotations[kpoint])...),
                    search_representative[kpoint],
                    scale,
                    weight_total,
                )
                rotation === nothing && return nothing
                rotations[kpoint] = rotation
            end
            return rotations
        end

        function reference_unitaries(scale::Float64)
            unitary_field = Vector{Matrix{ComplexF64}}(undef, length(frames))
            for kpoint in eachindex(frames)
                old_u = something(old_unitaries[kpoint])
                if kpoint in irreducible
                    trial_u = _wannier90_reference_unitary_step(
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

        polar_derivative = NaN
        if polar_available
            h = 1.0e-4
            derivative_h = (objective_at(:polar, h) - objective_at(:polar, -h)) / (2h)
            derivative_h2 = (objective_at(:polar, h / 2) - objective_at(:polar, -h / 2)) / h
            derivative_tolerance = max(1.0e-8, 1.0e-4 * max(1.0, abs(derivative_h2)))
            polar_available =
                isfinite(derivative_h) &&
                isfinite(derivative_h2) &&
                abs(derivative_h - derivative_h2) <= derivative_tolerance &&
                derivative_h2 < 0.0
            polar_derivative = derivative_h2
            polar_fallback_triggered |= !polar_available
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
                push!(attempted_directional_derivatives, wannier90_derivative_at_zero)
                trial_frames = build_trial(:smv_fletcher_reeves_two_stage, alpha)
                if trial_frames === nothing
                    push!(attempted_objectives, Inf)
                    push!(attempted_required_changes, NaN)
                    push!(attempted_actual_changes, Inf)
                    return (
                        success = false,
                        code = :LOCALIZATION_EXPONENTIAL_UPDATE_FAILED,
                        message = "Wannier90-reference exponential update failed",
                    )
                end
                rotations = reference_rotations(alpha)
                if rotations === nothing
                    push!(attempted_objectives, Inf)
                    push!(attempted_required_changes, NaN)
                    push!(attempted_actual_changes, Inf)
                    return (
                        success = false,
                        code = :LOCALIZATION_EXPONENTIAL_UPDATE_FAILED,
                        message = "Wannier90-reference link rotation failed",
                    )
                end
                trial_overlaps = _rotate_localized_overlap_state(
                    something(carried_reference_overlaps),
                    rotations,
                    mmn,
                )
                trial_unitaries = reference_unitaries(alpha)
                trial_unitaries === nothing && return (
                    success = false,
                    code = :LOCALIZATION_EXPONENTIAL_UPDATE_FAILED,
                    message = "Wannier90-reference U state update failed",
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
                    reference_omega_i,
                )
                trial_success =
                    _mpi_root_canonical_flag(trial_result.success, config.solver.parallel)
                if !trial_success
                    push!(attempted_objectives, Inf)
                    push!(attempted_required_changes, NaN)
                    push!(attempted_actual_changes, Inf)
                    return merge(
                        trial_result,
                        (message = "Wannier90-reference trial evaluation failed",),
                    )
                end
                trial_evaluation = trial_result.evaluation
                # Wannier90 feeds the independently recomputed total spread at
                # the trial point directly into `internal_optimal_step`.  Its
                # cancellation pattern is therefore part of the reference
                # algorithm; the compensated delta used by the other NLQG
                # optimizers would select a slightly different parabola.
                objective = trial_evaluation.objective
                objective = _mpi_root_canonical_scalar(objective, config.solver.parallel)
                actual_change = objective - old_objective
                push!(attempted_objectives, objective)
                push!(attempted_required_changes, wannier90_derivative_at_zero * alpha)
                push!(attempted_actual_changes, actual_change)
                all(isfinite, (objective, actual_change)) || return (
                    success = false,
                    code = :NONFINITE_LOCALIZATION_TRIAL,
                    message = "Wannier90-reference trial produced a non-finite objective",
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
                    message = "Wannier90-reference trial failed a structural invariant",
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
                    required_change = wannier90_derivative_at_zero * alpha,
                    actual_change,
                    directional_derivative = wannier90_derivative_at_zero,
                    fixed_projector_drift = trial_projector_drift,
                    mode = :smv_fletcher_reeves_two_stage,
                    evaluation = trial_evaluation,
                    branch_active_set_changed = false,
                    wannier90_reference_overlaps = trial_overlaps,
                    wannier90_reference_unitaries = trial_unitaries,
                )
            end

            first_trial = reference_candidate(config.solver.acceleration.u_w90_trial_step, 1)
            first_trial_success =
                _mpi_root_canonical_flag(first_trial.success, config.solver.parallel)
            if first_trial_success
                optimal = _wannier90_reference_optimal_step(
                    old_objective,
                    first_trial.objective,
                    wannier90_derivative_at_zero,
                    config.solver.acceleration.u_w90_trial_step,
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
                    attempted_accepted[end] = true
                    accepted_trial = first_trial
                else
                    last_failure = (:WANNIER90_PARABOLIC_STEP_NONFINITE, Inf)
                end
            else
                last_failure = (first_trial.code, Inf)
            end
        end
        modes =
            localization_algorithm == :smv_fletcher_reeves_two_stage ? () :
            polar_available ? (:polar, :gradient) :
            localization_algorithm in (
                :riemannian_cg,
                :riemannian_lbfgs,
                :smv_fletcher_reeves_two_stage,
                :symmetry_projected_smv_fletcher_reeves_two_stage,
            ) && !cg_restarted ? (localization_algorithm, :gradient) : (:gradient,)
        for mode in modes
            base_scale =
                mode == :polar ? u_mix_ratio :
                _is_fletcher_reeves_localization(mode) ?
                config.solver.acceleration.u_w90_trial_step :
                config.solver.acceleration.u_initial_step
            maximum_rotation =
                mode == :polar ? maximum_polar_phase :
                mode in (
                    :riemannian_cg,
                    :riemannian_lbfgs,
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
            w90_first_trial_objective = NaN
            w90_parabolic_scale = NaN
            for backtrack in 0:backtracking_limit
                step_scale = if _is_fletcher_reeves_localization(mode) && backtrack == 1
                    w90_parabolic_scale = _wannier90_parabolic_trial_scale(
                        old_objective,
                        gradient_directional_derivative,
                        base_scale,
                        w90_first_trial_objective,
                        config.solver.acceleration.u_backtracking_factor,
                    )
                    w90_parabolic_scale
                elseif _is_fletcher_reeves_localization(mode) &&
                       backtrack > 1 &&
                       isfinite(w90_parabolic_scale)
                    _backtracking_step_scale(
                        w90_parabolic_scale,
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
                    mode == :polar ? polar_derivative :
                    mode in (
                        :riemannian_cg,
                        :riemannian_lbfgs,
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
                        :riemannian_cg,
                        :riemannian_lbfgs,
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
                    tangent_plans,
                )
                if !trial_evaluation_result.success
                    push!(attempted_objectives, Inf)
                    push!(attempted_required_changes, required_change)
                    push!(attempted_actual_changes, Inf)
                    last_failure = (trial_evaluation_result.code, Inf)
                    if mode in (
                        :riemannian_cg,
                        :riemannian_lbfgs,
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
                    (w90_first_trial_objective = trial_objective)
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
                    :riemannian_cg,
                    :riemannian_lbfgs,
                    :smv_fletcher_reeves_two_stage,
                    :symmetry_projected_smv_fletcher_reeves_two_stage,
                ) && !isfinite(trial_objective)
                    last_failure = (:NONFINITE_LOCALIZATION_TRIAL, trial_objective)
                    cg_restarted = true
                    cg_restart_reason = :NONFINITE_TRIAL
                    break
                elseif mode in (
                    :riemannian_cg,
                    :riemannian_lbfgs,
                    :smv_fletcher_reeves_two_stage,
                    :symmetry_projected_smv_fletcher_reeves_two_stage,
                ) && invariant_failure !== nothing
                    last_failure = invariant_failure
                    cg_restarted = true
                    cg_restart_reason = :STRUCTURAL_GATE_REJECTED
                    break
                end
                trial_search_full =
                    mode == :polar ? nothing :
                    mode in (
                        :riemannian_cg,
                        :riemannian_lbfgs,
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
                    branch_active_set_changed = mv_evaluation.active_orbit_digests !=
                                                trial_evaluation.active_orbit_digests,
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
            mode == :polar && (polar_fallback_triggered = true)
            if mode in (
                :riemannian_cg,
                :riemannian_lbfgs,
                :smv_fletcher_reeves_two_stage,
                :symmetry_projected_smv_fletcher_reeves_two_stage,
            )
                if !cg_restarted
                    cg_restarted = true
                    cg_restart_reason = :LINE_SEARCH_RESTART
                end
                if mode == :riemannian_lbfgs
                    empty!(carried_lbfgs_s_history)
                    empty!(carried_lbfgs_y_history)
                    empty!(carried_lbfgs_rho_history)
                    carried_lbfgs_restart_count += 1
                    accepted_u_optimizer_restart_reason = :LINE_SEARCH_RESTART
                else
                    carried_cg_restart_count += 1
                end
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
            kstar_gradient_rms = kstar_gradient_rms,
            maximum_kstar_gradient_rms = maximum_kstar_gradient_index == 0 ? NaN :
                                         kstar_gradient_rms[maximum_kstar_gradient_index],
            maximum_kstar_gradient_index = maximum_kstar_gradient_index,
            frames = frames,
            centers = centers,
            spreads = spreads,
        )

        trial = something(accepted_trial)
        next_frames = trial.frames
        u_step = maximum(
            _frame_geodesic_distance(
                frames[kpoint],
                next_frames[kpoint],
                config.input.representation_tolerance,
            ) for kpoint in irreducible
        )
        global_permutation, global_phases =
            _global_permutation_phase_diagnostic(frames, next_frames)
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
            trial.mode == :polar ? :polar_then_gradient :
            trial.mode == :riemannian_cg ? :riemannian_cg :
            trial.mode == :symmetry_projected_smv_fletcher_reeves_two_stage ?
            :symmetry_projected_smv_fletcher_reeves_two_stage :
            trial.mode == :smv_fletcher_reeves_two_stage ? :smv_fletcher_reeves_two_stage :
            trial.mode == :riemannian_lbfgs ? :riemannian_lbfgs :
            apply_symmetry ? :symmetry_projected_gradient : :ordinary_full_bz_gradient
        if localization_algorithm == :smv_fletcher_reeves_two_stage
            carried_u_gradient = deepcopy(steepest_representative)
            if lowercase(strip(get(ENV, "WANNIERNLQG_W90_REFERENCE_DEBUG_GRADIENT", "0"))) in
               ("1", "true", "yes")
                println(
                    stderr,
                    "W90REF_CARRIED_GRADIENT_SHA256=" * _complex_field_sha256(carried_u_gradient),
                )
            end
            carried_u_direction = deepcopy(search_representative)
            carried_cg_iteration = wannier90_next_cg_count
            carried_branch_signature = "WANNIER90_REFERENCE_FULL_BZ"
            accepted_cg_beta = cg_beta
            accepted_cg_restarted = cg_restarted
            accepted_cg_restart_reason = cg_restart_reason
            accepted_cg_descent_cosine = cg_descent_cosine
            carried_reference_overlaps = trial.wannier90_reference_overlaps
            carried_reference_unitaries = trial.wannier90_reference_unitaries
        elseif localization_algorithm in
               (:riemannian_cg, :symmetry_projected_smv_fletcher_reeves_two_stage)
            branch_restart = trial.branch_active_set_changed
            if branch_restart
                cg_restarted = true
                cg_restart_reason = :PHASE_BRANCH_ACTIVE_SET_CHANGED
                carried_cg_restart_count += 1
            end
            if trial.mode in (:riemannian_cg, :symmetry_projected_smv_fletcher_reeves_two_stage) &&
               !branch_restart
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
        elseif localization_algorithm == :riemannian_lbfgs
            carried_u_gradient = nothing
            carried_u_direction = nothing
            carried_cg_iteration = 0
            accepted_cg_beta = NaN
            accepted_cg_restarted = cg_restarted
            accepted_cg_restart_reason = cg_restart_reason
            accepted_cg_descent_cosine = cg_descent_cosine
            if trial.branch_active_set_changed
                empty!(carried_lbfgs_s_history)
                empty!(carried_lbfgs_y_history)
                empty!(carried_lbfgs_rho_history)
                carried_lbfgs_restart_count += 1
                accepted_u_optimizer_restart_reason = :PHASE_BRANCH_ACTIVE_SET_CHANGED
            else
                s_field = [
                    zeros(ComplexF64, size(first(steepest_representative))) for
                    _ in eachindex(steepest_representative)
                ]
                displacement_success = true
                for kpoint in irreducible
                    new_polar = _localization_svd_polar(
                        subspaces[kpoint]' * next_frames[kpoint],
                        config.solver.numerical_thresholds.frame_transport_rtol,
                        config.solver.numerical_thresholds.maximum_transport_condition,
                    )
                    if !new_polar.success
                        displacement_success = false
                        break
                    end
                    displacement = _accepted_unitary_displacement(
                        something(old_unitaries[kpoint]),
                        new_polar.unitary,
                        config.input.representation_tolerance,
                    )
                    if !displacement.success
                        displacement_success = false
                        break
                    end
                    s_field[kpoint] .= displacement.tangent
                end
                if !displacement_success
                    empty!(carried_lbfgs_s_history)
                    empty!(carried_lbfgs_y_history)
                    empty!(carried_lbfgs_rho_history)
                    carried_lbfgs_restart_count += 1
                    accepted_u_optimizer_restart_reason = :LBFGS_TRANSPORT_BRANCH_REJECTED
                else
                    s_field =
                        apply_symmetry ?
                        _project_ibz_tangent_field(s_field, irreducible, tangent_plans) :
                        [(value - value') ./ 2 for value in s_field]
                    transported_old_descent =
                        apply_symmetry ?
                        _transport_ibz_tangent_field(
                            steepest_representative,
                            irreducible,
                            tangent_plans,
                        ) : [(value - value') ./ 2 for value in steepest_representative]
                    next_descent = trial.evaluation.representative_gradients
                    y_field = [
                        transported_old_descent[kpoint] - next_descent[kpoint] for
                        kpoint in eachindex(transported_old_descent)
                    ]
                    curvature = _ibz_tangent_inner(s_field, y_field, irreducible)
                    s_norm = sqrt(max(0.0, _ibz_tangent_inner(s_field, s_field, irreducible)))
                    y_norm = sqrt(max(0.0, _ibz_tangent_inner(y_field, y_field, irreducible)))
                    if isfinite(curvature) &&
                       curvature >
                       config.solver.acceleration.u_lbfgs_curvature_tolerance * s_norm * y_norm
                        push!(carried_lbfgs_s_history, s_field)
                        push!(carried_lbfgs_y_history, y_field)
                        push!(carried_lbfgs_rho_history, inv(curvature))
                        while length(carried_lbfgs_s_history) >
                              config.solver.acceleration.u_lbfgs_history
                            popfirst!(carried_lbfgs_s_history)
                            popfirst!(carried_lbfgs_y_history)
                            popfirst!(carried_lbfgs_rho_history)
                        end
                        accepted_u_optimizer_restart_reason = :NONE
                    else
                        empty!(carried_lbfgs_s_history)
                        empty!(carried_lbfgs_y_history)
                        empty!(carried_lbfgs_rho_history)
                        carried_lbfgs_restart_count += 1
                        accepted_u_optimizer_restart_reason = :LBFGS_CURVATURE_REJECTED
                    end
                end
            end
        else
            carried_u_gradient = nothing
            carried_u_direction = nothing
            carried_cg_iteration = 0
            accepted_cg_beta = NaN
            accepted_cg_restarted = false
            accepted_cg_restart_reason = :NOT_APPLICABLE
            accepted_cg_descent_cosine = NaN
            empty!(carried_lbfgs_s_history)
            empty!(carried_lbfgs_y_history)
            empty!(carried_lbfgs_rho_history)
        end
        carried_branch_signature = _u_branch_signature(trial.evaluation.active_orbit_digests)
        carried_active_orbit_count = length(trial.evaluation.active_orbit_digests)
        gradient_rms = trial.evaluation.gradient_rms
        kstar_gradient_rms, maximum_kstar_gradient_index =
            _kstar_gradient_distribution(trial.evaluation.full_gradients, representation)
        if gradient_rms <= config.solver.acceleration.u_gradient_norm_tolerance &&
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
            kstar_gradient_rms,
        )
            _mpi_root_canonical_array!(value, config.solver.parallel)
        end
        for value in (attempted_sweeps, attempted_accepted)
            _mpi_root_canonical_array!(value, config.solver.parallel)
        end
        maximum_u_step = _mpi_root_canonical_scalar(maximum_u_step, config.solver.parallel)
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
        localization_spectra = localization_spectra,
        localization_ranks = localization_ranks,
        localization_conditions = localization_conditions,
        raw_eigenphases = raw_eigenphases,
        aligned_eigenphases = deepcopy(raw_eigenphases),
        raw_geodesic_distances = raw_geodesic_distances,
        aligned_geodesic_distances = copy(raw_geodesic_distances),
        block_permutations = [copy(global_permutation) for _ in eachindex(frames)],
        block_phases = [copy(global_phases) for _ in eachindex(frames)],
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
        kstar_gradient_rms = kstar_gradient_rms,
        maximum_kstar_gradient_rms = maximum_kstar_gradient_index == 0 ? NaN :
                                     kstar_gradient_rms[maximum_kstar_gradient_index],
        maximum_kstar_gradient_index = maximum_kstar_gradient_index,
        transport_minimum_singular_value = transport_minimum_singular_value,
        transport_maximum_condition = transport_maximum_condition,
        transported_omega_i = transported_omega_i,
        u_phase_contract = LOCALIZATION_GRADIENT_CONTRACT,
        u_active_orbit_sha256 = carried_branch_signature,
        u_active_orbit_count = carried_active_orbit_count,
        generalized_gradient_rms = gradient_rms,
        u_lbfgs_s_history = carried_lbfgs_s_history,
        u_lbfgs_y_history = carried_lbfgs_y_history,
        u_lbfgs_rho_history = carried_lbfgs_rho_history,
        u_lbfgs_restart_count = carried_lbfgs_restart_count,
        u_optimizer_restart_reason = accepted_u_optimizer_restart_reason,
        wannier90_reference_overlaps = carried_reference_overlaps,
        wannier90_reference_omega_i = reference_omega_i,
        wannier90_reference_unitaries = carried_reference_unitaries,
    )
end
