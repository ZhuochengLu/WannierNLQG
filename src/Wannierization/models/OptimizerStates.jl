"""Per-outer-iteration residuals and accepted acceleration controls."""
struct WannierizationIterationDiagnostics
    omega_directional::Union{Nothing, NTuple{3, Float64}}
    omega_total::Float64
    projector_residual::Float64
    z_residual::Float64
    u_residual::Float64
    wcc_step_maximum::Float64
    spread_step_maximum::Float64
    little_group_residual::Float64
    z_boundary_gap::Float64
    z_mix_ratio::Float64
    u_mix_ratio::Float64
    u_inner_sweeps::Int
    anderson_used::Bool
    anderson_fallback::Bool
    rejected_steps::Int
    projected_gradient_rms::Float64
    accepted_u_step_scale::Float64
    localization_backtracking_steps::Int
    localization_directional_derivative::Float64
    fixed_projector_drift::Float64
    localization_base_objective::Float64
    localization_required_change::Float64
    localization_actual_change::Float64
    anderson_reason::Symbol
    minimum_diagonal_phase_margin::Float64
    minimum_phase_kpoint::Int
    minimum_phase_neighbor::Int
    minimum_phase_wannier::Int
    cg_beta::Float64
    cg_restarted::Bool
    cg_restart_reason::Symbol
    cg_descent_cosine::Float64
    maximum_kstar_gradient_rms::Float64
    maximum_kstar_gradient_index::Int
    omega_i::Float64
    delta_omega_i::Float64
    z_stability_count::Int
    joint_z_backtracking_steps::Int
    joint_transport_minimum_singular_value::Float64
    joint_transport_maximum_condition::Float64
    joint_acceptance_reason::Symbol
end

# Preserve the schema-2.6/2.7 iteration constructor. Schema 2.8 appends the
# qualified-Z and transactional-joint evidence without reinterpreting history.
function WannierizationIterationDiagnostics(
    omega_directional,
    omega_total,
    projector_residual,
    z_residual,
    u_residual,
    wcc_step_maximum,
    spread_step_maximum,
    little_group_residual,
    z_boundary_gap,
    z_mix_ratio,
    u_mix_ratio,
    u_inner_sweeps,
    anderson_used,
    anderson_fallback,
    rejected_steps,
    projected_gradient_rms,
    accepted_u_step_scale,
    localization_backtracking_steps,
    localization_directional_derivative,
    fixed_projector_drift,
    localization_base_objective,
    localization_required_change,
    localization_actual_change,
    anderson_reason,
    minimum_diagonal_phase_margin,
    minimum_phase_kpoint,
    minimum_phase_neighbor,
    minimum_phase_wannier,
    cg_beta,
    cg_restarted,
    cg_restart_reason,
    cg_descent_cosine,
    maximum_kstar_gradient_rms,
    maximum_kstar_gradient_index,
)
    return WannierizationIterationDiagnostics(
        omega_directional,
        Float64(omega_total),
        Float64(projector_residual),
        Float64(z_residual),
        Float64(u_residual),
        Float64(wcc_step_maximum),
        Float64(spread_step_maximum),
        Float64(little_group_residual),
        Float64(z_boundary_gap),
        Float64(z_mix_ratio),
        Float64(u_mix_ratio),
        Int(u_inner_sweeps),
        Bool(anderson_used),
        Bool(anderson_fallback),
        Int(rejected_steps),
        Float64(projected_gradient_rms),
        Float64(accepted_u_step_scale),
        Int(localization_backtracking_steps),
        Float64(localization_directional_derivative),
        Float64(fixed_projector_drift),
        Float64(localization_base_objective),
        Float64(localization_required_change),
        Float64(localization_actual_change),
        Symbol(anderson_reason),
        Float64(minimum_diagonal_phase_margin),
        Int(minimum_phase_kpoint),
        Int(minimum_phase_neighbor),
        Int(minimum_phase_wannier),
        Float64(cg_beta),
        Bool(cg_restarted),
        Symbol(cg_restart_reason),
        Float64(cg_descent_cosine),
        Float64(maximum_kstar_gradient_rms),
        Int(maximum_kstar_gradient_index),
        NaN,
        NaN,
        0,
        0,
        NaN,
        NaN,
        :NOT_RECORDED,
    )
end

# Preserve the schema-2.4/2.5 iteration constructor. Schema 2.6 appends typed
# Anderson/CG and principal-log/k-star diagnostics without reinterpreting old
# checkpoint values.
function WannierizationIterationDiagnostics(
    omega_directional,
    omega_total,
    projector_residual,
    z_residual,
    u_residual,
    wcc_step_maximum,
    spread_step_maximum,
    little_group_residual,
    z_boundary_gap,
    z_mix_ratio,
    u_mix_ratio,
    u_inner_sweeps,
    anderson_used,
    anderson_fallback,
    rejected_steps,
    projected_gradient_rms,
    accepted_u_step_scale,
    localization_backtracking_steps,
    localization_directional_derivative,
    fixed_projector_drift,
    localization_base_objective,
    localization_required_change,
    localization_actual_change,
)
    return WannierizationIterationDiagnostics(
        omega_directional,
        Float64(omega_total),
        Float64(projector_residual),
        Float64(z_residual),
        Float64(u_residual),
        Float64(wcc_step_maximum),
        Float64(spread_step_maximum),
        Float64(little_group_residual),
        Float64(z_boundary_gap),
        Float64(z_mix_ratio),
        Float64(u_mix_ratio),
        Int(u_inner_sweeps),
        Bool(anderson_used),
        Bool(anderson_fallback),
        Int(rejected_steps),
        Float64(projected_gradient_rms),
        Float64(accepted_u_step_scale),
        Int(localization_backtracking_steps),
        Float64(localization_directional_derivative),
        Float64(fixed_projector_drift),
        Float64(localization_base_objective),
        Float64(localization_required_change),
        Float64(localization_actual_change),
        :NOT_RECORDED,
        NaN,
        0,
        0,
        0,
        NaN,
        false,
        :NOT_RECORDED,
        NaN,
        NaN,
        0,
    )
end

# Preserve the schema-2.2/2.3 constructor while schema 2.4 adds the fixed-stage
# and retraction-consistent line-search evidence.
function WannierizationIterationDiagnostics(
    omega_directional,
    omega_total,
    projector_residual,
    z_residual,
    u_residual,
    wcc_step_maximum,
    spread_step_maximum,
    little_group_residual,
    z_boundary_gap,
    z_mix_ratio,
    u_mix_ratio,
    u_inner_sweeps,
    anderson_used,
    anderson_fallback,
    rejected_steps,
    projected_gradient_rms,
    accepted_u_step_scale,
    localization_backtracking_steps,
)
    return WannierizationIterationDiagnostics(
        omega_directional,
        Float64(omega_total),
        Float64(projector_residual),
        Float64(z_residual),
        Float64(u_residual),
        Float64(wcc_step_maximum),
        Float64(spread_step_maximum),
        Float64(little_group_residual),
        Float64(z_boundary_gap),
        Float64(z_mix_ratio),
        Float64(u_mix_ratio),
        Int(u_inner_sweeps),
        Bool(anderson_used),
        Bool(anderson_fallback),
        Int(rejected_steps),
        Float64(projected_gradient_rms),
        Float64(accepted_u_step_scale),
        Int(localization_backtracking_steps),
        NaN,
        NaN,
        NaN,
        NaN,
        NaN,
        :NOT_RECORDED,
        NaN,
        0,
        0,
        0,
        NaN,
        false,
        :NOT_RECORDED,
        NaN,
        NaN,
        0,
    )
end

# Preserve the schema-2.1 constructor while schema 2.2 adds localization history.
function WannierizationIterationDiagnostics(
    omega_directional,
    omega_total,
    projector_residual,
    z_residual,
    u_residual,
    wcc_step_maximum,
    spread_step_maximum,
    little_group_residual,
    z_boundary_gap,
    z_mix_ratio,
    u_mix_ratio,
    u_inner_sweeps,
    anderson_used,
    anderson_fallback,
    rejected_steps,
)
    return WannierizationIterationDiagnostics(
        omega_directional,
        Float64(omega_total),
        Float64(projector_residual),
        Float64(z_residual),
        Float64(u_residual),
        Float64(wcc_step_maximum),
        Float64(spread_step_maximum),
        Float64(little_group_residual),
        Float64(z_boundary_gap),
        Float64(z_mix_ratio),
        Float64(u_mix_ratio),
        Int(u_inner_sweeps),
        Bool(anderson_used),
        Bool(anderson_fallback),
        Int(rejected_steps),
        NaN,
        NaN,
        0,
    )
end

"""Per-k evidence for construction of an exact-frozen AMN initial frame."""
struct WannierInitializationKPointDiagnostic
    kpoint::Int
    full_amn_singular_values::Vector{Float64}
    outer_amn_singular_values::Vector{Float64}
    frozen_amn_singular_values::Vector{Float64}
    projected_free_singular_values::Vector{Float64}
    alignment_singular_values::Vector{Float64}
    full_amn_rank::Int
    outer_amn_rank::Int
    frozen_amn_rank::Int
    projected_free_rank::Int
    target_completion_count::Int
    band_completion_count::Int
    full_amn_rank_threshold::Float64
    outer_amn_rank_threshold::Float64
    frozen_amn_rank_threshold::Float64
    projected_free_rank_threshold::Float64
    alignment_condition::Float64
    isometry_before::Float64
    isometry_after::Float64
    frozen_residual_before::Float64
    frozen_residual_after::Float64
end

"""Complete initialization contract and per-k diagnostic payload."""
struct WannierInitializationReport
    algorithm::Symbol
    algorithm_version::String
    status::Symbol
    kpoints::Vector{WannierInitializationKPointDiagnostic}
end

"""Optimizer-only state required for bitwise-equivalent strict continuation."""
struct WannierizationOptimizerState
    strategy::Symbol
    z_mix_ratio::Float64
    u_mix_ratio::Float64
    improvement_streak::Int
    rejected_steps::Int
    residual_reference::NTuple{4, Float64}
    previous_merit::Float64
    anderson_z_history::Matrix{Float64}
    anderson_residual_history::Matrix{Float64}
    phase::Symbol
    z_stability_count::Int
    u_stability_count::Int
    z_steps::Int
    u_steps::Int
    epoch::Int
    last_accepted_u_step_scale::Float64
    gradient_fallback_active::Bool
    gradient_steps::Int
    best_polar_frames::Array{ComplexF64, 3}
    best_polar_centers::Matrix{Float64}
    best_polar_spreads::Vector{Float64}
    best_polar_objective::Float64
    disentanglement_objective_history::Vector{Float64}
    localization_objective_history::Vector{Float64}
    localization_trial_step_scales::Vector{Float64}
    localization_trial_objectives::Vector{Float64}
    localization_trial_required_changes::Vector{Float64}
    localization_trial_actual_changes::Vector{Float64}
    localization_trial_directional_derivatives::Vector{Float64}
    localization_projector_drift_history::Vector{Float64}
    localization_trial_iterations::Vector{Int}
    localization_trial_sweeps::Vector{Int}
    localization_trial_accepted::Vector{Bool}
    previous_u_gradient::Array{ComplexF64, 3}
    previous_u_direction::Array{ComplexF64, 3}
    u_cg_iteration::Int
    u_cg_restart_count::Int
    last_cg_beta::Float64
    last_cg_restart_reason::Symbol
    last_anderson_reason::Symbol
    # Schema-2.10 chart and limited-memory state. Accepted physical frames and
    # Z/projector data remain independent from this resettable U-only history.
    u_phase_contract::String
    u_active_orbit_sha256::String
    u_active_orbit_count::Int
    u_generalized_gradient_rms::Float64
    u_lbfgs_s_history::Array{ComplexF64, 4}
    u_lbfgs_y_history::Array{ComplexF64, 4}
    u_lbfgs_rho_history::Vector{Float64}
    u_lbfgs_restart_count::Int
    last_u_optimizer_restart_reason::Symbol
    # Schema-2.22 exact Wannier90 recursive state. Empty arrays mean that the
    # state belongs to a non-reference or legacy trajectory.
    wannier90_reference_overlaps::Array{ComplexF64, 4}
    wannier90_reference_unitaries::Array{ComplexF64, 3}
    wannier90_reference_omega_i::Float64
end

# Preserve all pre-reference-state constructors and legacy readers. New exact
# trajectories use the native 52-field constructor below.
function WannierizationOptimizerState(arguments::Vararg{Any, 49})
    return WannierizationOptimizerState(
        arguments...,
        zeros(ComplexF64, 0, 0, 0, 0),
        zeros(ComplexF64, 0, 0, 0),
        NaN,
    )
end

# Preserve the schema-2.6--2.9 full optimizer constructor. Loading one of those
# states never invents chart-compatible U history; the HDF5 compatibility layer
# subsequently records and enforces the explicit schema-2.10 reset contract.
function WannierizationOptimizerState(
    strategy,
    z_mix_ratio,
    u_mix_ratio,
    improvement_streak,
    rejected_steps,
    residual_reference,
    previous_merit,
    anderson_z_history,
    anderson_residual_history,
    phase,
    z_stability_count,
    u_stability_count,
    z_steps,
    u_steps,
    epoch,
    last_accepted_u_step_scale,
    gradient_fallback_active,
    gradient_steps,
    best_polar_frames,
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
    previous_u_gradient,
    previous_u_direction,
    u_cg_iteration,
    u_cg_restart_count,
    last_cg_beta,
    last_cg_restart_reason,
    last_anderson_reason,
)
    return WannierizationOptimizerState(
        Symbol(strategy),
        Float64(z_mix_ratio),
        Float64(u_mix_ratio),
        Int(improvement_streak),
        Int(rejected_steps),
        Tuple(Float64.(collect(residual_reference))),
        Float64(previous_merit),
        Matrix{Float64}(anderson_z_history),
        Matrix{Float64}(anderson_residual_history),
        Symbol(phase),
        Int(z_stability_count),
        Int(u_stability_count),
        Int(z_steps),
        Int(u_steps),
        Int(epoch),
        Float64(last_accepted_u_step_scale),
        Bool(gradient_fallback_active),
        Int(gradient_steps),
        Array{ComplexF64, 3}(best_polar_frames),
        Matrix{Float64}(best_polar_centers),
        Vector{Float64}(best_polar_spreads),
        Float64(best_polar_objective),
        Float64.(disentanglement_objective_history),
        Float64.(localization_objective_history),
        Float64.(localization_trial_step_scales),
        Float64.(localization_trial_objectives),
        Float64.(localization_trial_required_changes),
        Float64.(localization_trial_actual_changes),
        Float64.(localization_trial_directional_derivatives),
        Float64.(localization_projector_drift_history),
        Int.(localization_trial_iterations),
        Int.(localization_trial_sweeps),
        Bool.(localization_trial_accepted),
        Array{ComplexF64, 3}(previous_u_gradient),
        Array{ComplexF64, 3}(previous_u_direction),
        Int(u_cg_iteration),
        Int(u_cg_restart_count),
        Float64(last_cg_beta),
        Symbol(last_cg_restart_reason),
        Symbol(last_anderson_reason),
        "mv_centered_residual_unwrapped_delta_v2",
        "",
        0,
        NaN,
        zeros(ComplexF64, 0, 0, 0, 0),
        zeros(ComplexF64, 0, 0, 0, 0),
        Float64[],
        0,
        :EMPTY_HISTORY,
    )
end

# Preserve the schema-2.4/2.5 optimizer constructor while schema 2.6 adds
# accepted Riemannian-CG state and a typed Anderson safeguard reason.
function WannierizationOptimizerState(
    strategy,
    z_mix_ratio,
    u_mix_ratio,
    improvement_streak,
    rejected_steps,
    residual_reference,
    previous_merit,
    anderson_z_history,
    anderson_residual_history,
    phase,
    z_stability_count,
    u_stability_count,
    z_steps,
    u_steps,
    epoch,
    last_accepted_u_step_scale,
    gradient_fallback_active,
    gradient_steps,
    best_polar_frames,
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
)
    return WannierizationOptimizerState(
        Symbol(strategy),
        Float64(z_mix_ratio),
        Float64(u_mix_ratio),
        Int(improvement_streak),
        Int(rejected_steps),
        Tuple(Float64.(collect(residual_reference))),
        Float64(previous_merit),
        Matrix{Float64}(anderson_z_history),
        Matrix{Float64}(anderson_residual_history),
        Symbol(phase),
        Int(z_stability_count),
        Int(u_stability_count),
        Int(z_steps),
        Int(u_steps),
        Int(epoch),
        Float64(last_accepted_u_step_scale),
        Bool(gradient_fallback_active),
        Int(gradient_steps),
        Array{ComplexF64, 3}(best_polar_frames),
        Matrix{Float64}(best_polar_centers),
        Vector{Float64}(best_polar_spreads),
        Float64(best_polar_objective),
        Float64.(disentanglement_objective_history),
        Float64.(localization_objective_history),
        Float64.(localization_trial_step_scales),
        Float64.(localization_trial_objectives),
        Float64.(localization_trial_required_changes),
        Float64.(localization_trial_actual_changes),
        Float64.(localization_trial_directional_derivatives),
        Float64.(localization_projector_drift_history),
        Int.(localization_trial_iterations),
        Int.(localization_trial_sweeps),
        Bool.(localization_trial_accepted),
        zeros(ComplexF64, 0, 0, 0),
        zeros(ComplexF64, 0, 0, 0),
        0,
        0,
        NaN,
        :EMPTY_HISTORY,
        :NOT_STARTED,
    )
end

# Preserve the schema-2.3 constructor while schema 2.4 adds explicit
# retraction-direction and sealed-projector histories.
function WannierizationOptimizerState(
    strategy,
    z_mix_ratio,
    u_mix_ratio,
    improvement_streak,
    rejected_steps,
    residual_reference,
    previous_merit,
    anderson_z_history,
    anderson_residual_history,
    phase,
    z_stability_count,
    u_stability_count,
    z_steps,
    u_steps,
    epoch,
    last_accepted_u_step_scale,
    gradient_fallback_active,
    gradient_steps,
    best_polar_frames,
    best_polar_centers,
    best_polar_spreads,
    best_polar_objective,
    disentanglement_objective_history,
    localization_objective_history,
    localization_trial_step_scales,
    localization_trial_objectives,
    localization_trial_required_changes,
    localization_trial_actual_changes,
)
    return WannierizationOptimizerState(
        Symbol(strategy),
        Float64(z_mix_ratio),
        Float64(u_mix_ratio),
        Int(improvement_streak),
        Int(rejected_steps),
        Tuple(Float64.(collect(residual_reference))),
        Float64(previous_merit),
        Matrix{Float64}(anderson_z_history),
        Matrix{Float64}(anderson_residual_history),
        Symbol(phase),
        Int(z_stability_count),
        Int(u_stability_count),
        Int(z_steps),
        Int(u_steps),
        Int(epoch),
        Float64(last_accepted_u_step_scale),
        Bool(gradient_fallback_active),
        Int(gradient_steps),
        Array{ComplexF64, 3}(best_polar_frames),
        Matrix{Float64}(best_polar_centers),
        Vector{Float64}(best_polar_spreads),
        Float64(best_polar_objective),
        Float64.(disentanglement_objective_history),
        Float64.(localization_objective_history),
        Float64.(localization_trial_step_scales),
        Float64.(localization_trial_objectives),
        Float64.(localization_trial_required_changes),
        Float64.(localization_trial_actual_changes),
        Float64[],
        Float64[],
        Int[],
        Int[],
        Bool[],
        zeros(ComplexF64, 0, 0, 0),
        zeros(ComplexF64, 0, 0, 0),
        0,
        0,
        NaN,
        :EMPTY_HISTORY,
        :NOT_STARTED,
    )
end

# Upgrade schema-2.2 optimizer states without inventing stage histories.
function WannierizationOptimizerState(
    strategy,
    z_mix_ratio,
    u_mix_ratio,
    improvement_streak,
    rejected_steps,
    residual_reference,
    previous_merit,
    anderson_z_history,
    anderson_residual_history,
    phase,
    z_stability_count,
    u_stability_count,
    z_steps,
    u_steps,
    epoch,
    last_accepted_u_step_scale,
    gradient_fallback_active,
    gradient_steps,
    best_polar_frames,
    best_polar_centers,
    best_polar_spreads,
    best_polar_objective,
)
    return WannierizationOptimizerState(
        Symbol(strategy),
        Float64(z_mix_ratio),
        Float64(u_mix_ratio),
        Int(improvement_streak),
        Int(rejected_steps),
        Tuple(Float64.(collect(residual_reference))),
        Float64(previous_merit),
        Matrix{Float64}(anderson_z_history),
        Matrix{Float64}(anderson_residual_history),
        Symbol(phase),
        Int(z_stability_count),
        Int(u_stability_count),
        Int(z_steps),
        Int(u_steps),
        Int(epoch),
        Float64(last_accepted_u_step_scale),
        Bool(gradient_fallback_active),
        Int(gradient_steps),
        Array{ComplexF64, 3}(best_polar_frames),
        Matrix{Float64}(best_polar_centers),
        Vector{Float64}(best_polar_spreads),
        Float64(best_polar_objective),
        Float64[],
        Float64[],
        Float64[],
        Float64[],
        Float64[],
        Float64[],
        Float64[],
        Float64[],
        Int[],
        Int[],
        Bool[],
        zeros(ComplexF64, 0, 0, 0),
        zeros(ComplexF64, 0, 0, 0),
        0,
        0,
        NaN,
        :EMPTY_HISTORY,
        :NOT_STARTED,
    )
end

"""Construct empty deterministic optimizer history for one declared strategy."""
function WannierizationOptimizerState(strategy, z_mix_ratio, u_mix_ratio)
    return WannierizationOptimizerState(
        Symbol(strategy),
        Float64(z_mix_ratio),
        Float64(u_mix_ratio),
        0,
        0,
        (NaN, NaN, NaN, NaN),
        NaN,
        zeros(Float64, 0, 0),
        zeros(Float64, 0, 0),
        :joint,
        0,
        0,
        0,
        0,
        1,
        1.0,
        false,
        0,
        zeros(ComplexF64, 0, 0, 0),
        zeros(Float64, 0, 3),
        Float64[],
        Inf,
    )
end

# Preserve the schema-1.2 optimizer constructor.  A legacy state is always a
# joint trajectory; it is never silently promoted to a strict nested restart.
function WannierizationOptimizerState(
    strategy,
    z_mix_ratio,
    u_mix_ratio,
    improvement_streak,
    rejected_steps,
    residual_reference,
    previous_merit,
    anderson_z_history,
    anderson_residual_history,
)
    return WannierizationOptimizerState(
        Symbol(strategy),
        Float64(z_mix_ratio),
        Float64(u_mix_ratio),
        Int(improvement_streak),
        Int(rejected_steps),
        Tuple(Float64.(collect(residual_reference))),
        Float64(previous_merit),
        Matrix{Float64}(anderson_z_history),
        Matrix{Float64}(anderson_residual_history),
        :joint,
        0,
        0,
        0,
        0,
        1,
        1.0,
        false,
        0,
        zeros(ComplexF64, 0, 0, 0),
        zeros(Float64, 0, 3),
        Float64[],
        Inf,
    )
end

"""Complete iterative state required to resume at the next joint Z/U iteration."""
struct WannierizationRestartState
    iteration::Int
    frames::Array{ComplexF64, 3}
    z_previous::Union{Nothing, Array{ComplexF64, 3}}
    centers_cartesian::Matrix{Float64}
    spreads_angstrom2::Vector{Float64}
    convergence_values::Matrix{Float64}
    included_bands::BitMatrix
    elapsed_seconds::Float64
    config_sha256::String
    representation_sha256::String
    stencil::Union{Nothing, WannierizationFiniteDifferenceStencil}
    projection_basis_sha256::String
    amn_sha256::String
    optimizer_state::WannierizationOptimizerState
    fixed_subspace_projectors::Union{Nothing, Array{ComplexF64, 3}}
    fixed_subspace_frames::Union{Nothing, Array{ComplexF64, 3}}
    localization_initial_frames::Union{Nothing, Array{ComplexF64, 3}}
end

# Preserve the schema-2.0--2.3 in-memory constructor. Such states contain no
# sealed two-stage boundary and therefore cannot be resumed under schema 2.4.
function WannierizationRestartState(
    iteration,
    frames,
    z_previous,
    centers_cartesian,
    spreads_angstrom2,
    convergence_values,
    included_bands,
    elapsed_seconds,
    config_sha256,
    representation_sha256,
    stencil,
    projection_basis_sha256,
    amn_sha256,
    optimizer_state,
)
    return WannierizationRestartState(
        Int(iteration),
        Array{ComplexF64, 3}(frames),
        z_previous === nothing ? nothing : Array{ComplexF64, 3}(z_previous),
        Matrix{Float64}(centers_cartesian),
        Float64.(spreads_angstrom2),
        Matrix{Float64}(convergence_values),
        BitMatrix(included_bands),
        Float64(elapsed_seconds),
        String(config_sha256),
        String(representation_sha256),
        stencil,
        String(projection_basis_sha256),
        String(amn_sha256),
        optimizer_state,
        nothing,
        nothing,
        nothing,
    )
end

"""Sealed fixed Bloch subspace and deterministic initial frame for U-only SAWF."""
struct WannierizationFixedSubspace
    projectors::Array{ComplexF64, 3}
    frames::Array{ComplexF64, 3}
    irreducible_indices::Vector{Int}
    frozen_mask::BitMatrix
    source_sha256::Dict{String, String}
    invariant_residuals::Dict{String, Float64}

    function WannierizationFixedSubspace(
        projectors,
        frames,
        irreducible_indices,
        frozen_mask;
        source_sha256 = Dict{String, String}(),
        invariant_residuals = Dict{String, Float64}(),
    )
        projector_values = Array{ComplexF64, 3}(projectors)
        frame_values = Array{ComplexF64, 3}(frames)
        size(projector_values, 1) == size(projector_values, 2) ||
            throw(DimensionMismatch("fixed-subspace projectors must be square"))
        size(projector_values, 1) == size(frame_values, 1) ||
            throw(DimensionMismatch("fixed-subspace projector/frame band dimensions disagree"))
        size(projector_values, 3) == size(frame_values, 3) ||
            throw(DimensionMismatch("fixed-subspace projector/frame meshes disagree"))
        mask = BitMatrix(frozen_mask)
        size(mask) == (size(frame_values, 1), size(frame_values, 3)) ||
            throw(DimensionMismatch("fixed-subspace frozen mask dimensions disagree"))
        ibz = Int.(irreducible_indices)
        all(index -> 1 <= index <= size(frame_values, 3), ibz) ||
            throw(ArgumentError("fixed-subspace IBZ index is out of range"))
        return new(
            projector_values,
            frame_values,
            ibz,
            mask,
            Dict{String, String}(source_sha256),
            Dict{String, Float64}(invariant_residuals),
        )
    end
end

# Preserve the schema-1.1 in-memory constructor for terminal compatibility only.
function WannierizationRestartState(
    iteration,
    frames,
    z_previous,
    centers_cartesian,
    spreads_angstrom2,
    convergence_values,
    included_bands,
    elapsed_seconds,
    config_sha256,
    representation_sha256,
)
    return WannierizationRestartState(
        Int(iteration),
        Array{ComplexF64, 3}(frames),
        z_previous === nothing ? nothing : Array{ComplexF64, 3}(z_previous),
        Matrix{Float64}(centers_cartesian),
        Float64.(spreads_angstrom2),
        Matrix{Float64}(convergence_values),
        BitMatrix(included_bands),
        Float64(elapsed_seconds),
        String(config_sha256),
        String(representation_sha256),
        nothing,
        "",
        "",
        WannierizationOptimizerState(:fixed, 0.5, 1.0),
        nothing,
        nothing,
        nothing,
    )
end
