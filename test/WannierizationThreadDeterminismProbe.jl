using LinearAlgebra
using SHA
using WannierNLQG

const W = WannierNLQG.Wannierization
const S = WannierNLQG.Symmetrization
const IOW = WannierNLQG.IO

identity_operation = WannierNLQG.SymmetryFoundation.SymmetryOperation(
    Matrix{Int}(I, 3, 3),
    zeros(3),
    Matrix{Float64}(I, 3, 3),
)
energies = [-1.0 -1.0; 1.0 1.0]
representation = WannierNLQG.SymmetryFoundation.BandRepresentation(
    "1.4",
    :synthetic,
    false,
    Matrix{Float64}(I, 3, 3),
    2.0pi .* Matrix{Float64}(I, 3, 3),
    (2, 1, 1),
    [0.0 0.0 0.0; 0.5 0.0 0.0],
    energies,
    [identity_operation],
    reshape([1, 2], 1, 2),
    zeros(Int, 3, 1, 2),
    reshape(repeat(Matrix{ComplexF64}(I, 2, 2), 1, 1, 2), 2, 2, 1, 2),
    [1 1; 2 2],
    [1, 2],
    [1, 2],
    [1, 1];
    conventions = Dict("magnetic_structure" => "false"),
    input_sha256 = Dict("fixture" => repeat("0", 64)),
)
block = WannierNLQG.WannierProjection.WannierProjectionBlock(
    "X",
    "s",
    zeros(3, 1),
    reshape([1], 1, 1),
    reshape(Matrix{Float64}(I, 3, 3), 3, 3, 1),
    false,
)
basis = WannierNLQG.WannierProjection.WannierProjectionBasis([block], 1, false)
plan = WannierNLQG.SymmetryFoundation.WannierSymmetryPlan(
    [identity_operation],
    ones(ComplexF64, 1, 1, 1),
    zeros(Int, 3, 1, 1),
)
eig = IOW.WannierEIG(2, 2, copy(energies))
mmn_data = zeros(ComplexF64, 2, 2, 6, 2)
for kpoint in 1:2, neighbor in 1:6
    mmn_data[:, :, neighbor, kpoint] .= Matrix{ComplexF64}(I, 2, 2)
end
neighbors = [2 1; 2 1; 1 2; 1 2; 1 2; 1 2]
shifts = zeros(Int, 3, 6, 2)
shifts[1, 2, 1] = -1
shifts[1, 1, 2] = 1
shifts[2, 3, :] .= 1
shifts[2, 4, :] .= -1
shifts[3, 5, :] .= 1
shifts[3, 6, :] .= -1
mmn = IOW.WannierMMN(2, 2, 6, mmn_data, neighbors, shifts)
acceleration = W.WannierizationAccelerationConfig(
    schedule = :two_stage,
    u_acceptance = :armijo,
    z_stability_window = 1,
    disentanglement_objective_tolerance = 1.0e-8,
    z_projector_tolerance = 1.0e-8,
    u_gradient_norm_tolerance = 1.0e-8,
    u_inner_tolerance = 1.0e-8,
)
config = W.SymmetryAdaptedWannierizationConfig(
    input = W.WannierizationInputConfig(
        wannierization_mode = :symmetry_adapted,
        win_file = "synthetic.win",
        eig_file = "synthetic.eig",
        mmn_file = "synthetic.mmn",
        projection_basis = basis,
        band_representation = representation,
        num_wannier = 1,
        outer_min_ev = -2.0,
        outer_max_ev = 2.0,
        frozen_min_ev = -2.0,
        frozen_max_ev = -0.5,
    ),
    solver = W.WannierizationSolverConfig(
        initialization = :random,
        acceleration = acceleration,
        parallel = :threads,
        max_iterations = 8,
        convergence_tolerance = 1.0e-8,
        convergence_window = 1,
        random_seed = 0x1234,
    ),
    checkpoint = W.WannierizationCheckpointConfig(),
    runtime = W.WannierizationRuntimeConfig(),
    output = W.WannierizationOutputConfig(),
)
result = W._solve_symmetry_adapted_wannierization(config, representation, eig, mmn, plan)
result.status in (W.COMPLETED, W.COMPLETED_WITH_WARNINGS, W.MAX_ITERATIONS) ||
    error("unexpected deterministic-probe status $(result.status)")
optimizer = something(result.restart_state).optimizer_state
buffer = IOBuffer()
write(buffer, string(result.status), '\n')
for values in (
    result.v_matrix,
    result.wannier_centers_cartesian,
    result.spreads_angstrom2,
    getfield.(result.history, :spread_total),
    getfield.(result.history, :spread_standard_deviation),
    optimizer.disentanglement_objective_history,
    optimizer.localization_objective_history,
    optimizer.localization_trial_step_scales,
    optimizer.localization_trial_objectives,
    optimizer.localization_trial_required_changes,
    optimizer.localization_trial_actual_changes,
    optimizer.localization_trial_directional_derivatives,
    optimizer.localization_projector_drift_history,
    optimizer.localization_trial_iterations,
    optimizer.localization_trial_sweeps,
    optimizer.localization_trial_accepted,
)
    array = Array(values)
    write(buffer, reinterpret(UInt8, Int64[ndims(array), size(array)...]))
    write(buffer, reinterpret(UInt8, vec(array)))
end
# Exercise the completed public band contract alongside the identical internal target contract.
extension = first(W._load_wannierization_extension!())
workflow = extension.WorkflowOrchestration
mode_representation =
    Base.invokelatest(workflow._representation_with_mode_contract, representation, config)
scope = WannierNLQG.SymmetryFoundation.BandRepresentationQualificationScope(
    trues(2, 2),
    BitMatrix([true true; false false]),
)
internal_target = Base.invokelatest(
    workflow._representation_with_target_subspace_contract,
    mode_representation,
    config,
    scope,
)
public_completion_available = isdefined(workflow, :_completed_public_band_representation)
public_target =
    public_completion_available ?
    Base.invokelatest(workflow._completed_public_band_representation, internal_target) :
    internal_target
internal_target.schema_version == "1.17" || error("internal target contract changed")
public_target.schema_version == (public_completion_available ? "1.0" : "1.17") ||
    error("completed band contract has an unexpected wire identity")
internal_config =
    W._replace_wannierization_config(config; input = (band_representation = internal_target,))
public_config =
    W._replace_wannierization_config(config; input = (band_representation = public_target,))
internal_result =
    W._solve_symmetry_adapted_wannierization(internal_config, internal_target, eig, mmn, plan)
public_result =
    W._solve_symmetry_adapted_wannierization(public_config, public_target, eig, mmn, plan)
internal_result.status == public_result.status || error("public schema changed solver status")
internal_result.history == public_result.history || error("public schema changed solver history")
write(buffer, string(public_result.status), '\n')
for field in (:v_matrix, :wannier_centers_cartesian, :spreads_angstrom2)
    values = getfield(public_result, field)
    values == getfield(internal_result, field) || error("public schema changed $(field)")
    array = Array(values)
    write(buffer, reinterpret(UInt8, Int64[ndims(array), size(array)...]))
    write(buffer, reinterpret(UInt8, vec(array)))
end
for field in (:spread_total, :spread_standard_deviation)
    write(buffer, reinterpret(UInt8, getfield.(public_result.history, field)))
end
println("WANNIERIZATION_THREAD_DIGEST=" * bytes2hex(SHA.sha256(take!(buffer))))
