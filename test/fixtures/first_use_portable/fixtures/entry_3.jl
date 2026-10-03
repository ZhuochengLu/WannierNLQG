#!/usr/bin/env julia
# This miniature solver fixture mirrors the construction in
# test/WannierizationFreshProcessProbe.jl. Keep both paths numerically checked
# when changing the fixture; this runner separates import, preparation and solve.
# The probe instruments only the selected public call; setup stays outside @timed.
import_started = time_ns()
import_timed = @timed Core.eval(Main, :(using LinearAlgebra, WannierNLQG, JSON3, SHA))
import_wall = (time_ns() - import_started) / 1.0e9
const W = WannierNLQG.Wannierization
const IOW = WannierNLQG.IO
fixture_started = time_ns()
input_root = Main.FirstUsePortableSupport.input("assets/frozen_solver")
root = joinpath(dirname(Main.RECEIPT), "fixture_output")
ispath(root) && error("fixture output exists")
mkpath(root)
win_file = joinpath(input_root, "synthetic.win")
eig_file = joinpath(input_root, "synthetic.eig")
mmn_file = joinpath(input_root, "synthetic.mmn")
representation_file = joinpath(input_root, "synthetic.band-representation.h5")
checkpoint_file = joinpath(root, "synthetic.wannierization.h5")
for row in JSON3.read(read(joinpath(input_root, "identity.json"), String)).files
    bytes2hex(SHA.sha256(read(joinpath(input_root, String(row.file)))))==row.sha256 ||
        error("frozen input changed")
end
block = WannierNLQG.WannierProjection.WannierProjectionBlock(
    "X",
    "s",
    zeros(3, 1),
    reshape([1], 1, 1),
    reshape(Matrix{Float64}(I, 3, 3), 3, 3, 1),
    false,
)
basis = WannierNLQG.WannierProjection.WannierProjectionBasis([block], 1, false)
fixture_before_prepare = (time_ns()-fixture_started)/1e9
prepare_wall=0.0
prepare_timed=(compile_time = 0.0,)

acceleration = W.WannierizationAccelerationConfig(
    schedule = :two_stage,
    u_acceptance = :armijo,
    z_stability_window = 1,
    disentanglement_objective_tolerance = 1.0e-8,
    z_projector_tolerance = 1.0e-8,
)
solve_started = time_ns()
first_timed = @timed W.construct_symmetry_adapted_wannier_functions(
    W.SymmetryAdaptedWannierizationConfig(
        input = W.WannierizationInputConfig(
            construction_policy = :strict,
            wannierization_mode = :symmetry_adapted,
            win_file = win_file,
            eig_file = eig_file,
            mmn_file = mmn_file,
            projection_basis = basis,
            band_representation_hdf5 = representation_file,
            outer_min_ev = -2.0,
            outer_max_ev = 2.0,
            frozen_min_ev = -2.0,
            frozen_max_ev = -0.5,
            num_wannier = 1,
            compatibility_policy = :strict,
        ),
        solver = W.WannierizationSolverConfig(
            # This probe freezes the historical synthetic trajectory so it tests
            # persistence and TB readback independently of production :auto
            # profile selection.
            algorithm_profile = :custom,
            initialization = :random,
            localize = false,
            acceleration = acceleration,
            max_iterations = 8,
            convergence_tolerance = 1.0e-8,
            convergence_window = 1,
            random_seed = 0x1234,
        ),
        checkpoint = W.WannierizationCheckpointConfig(
            checkpoint_hdf5 = checkpoint_file,
            checkpoint_interval = 0,
        ),
        runtime = W.WannierizationRuntimeConfig(progress_interval = 0),
        output = W.WannierizationOutputConfig(
            tb_output_formats = (:packed_hdf5, :wannier90_tb),
            write_wannier90_tb = true,
        ),
    ),
)
solve_wall = (time_ns() - solve_started) / 1.0e9
result = first_timed.value
result.status in (W.COMPLETED, W.COMPLETED_WITH_WARNINGS) ||
    error("solver failed: $(result.status)")
readback_started = time_ns()
readback_timed = @timed W.read_wannierization_checkpoint_hdf5(checkpoint_file)
readback_wall = (time_ns() - readback_started) / 1.0e9
restored = readback_timed.value
isequal(restored.v_matrix, result.v_matrix) || error("V checkpoint mismatch")
record = (
    status = string(result.status),
    import_wall = import_wall,
    import_compile_time = import_timed.compile_time,
    fixture_before_prepare_wall = fixture_before_prepare,
    prepare_wall = prepare_wall,
    prepare_compile_time = prepare_timed.compile_time,
    solve_wall = solve_wall,
    solver_time = first_timed.time,
    solver_compile_time = first_timed.compile_time,
    solver_recompile_time = first_timed.recompile_time,
    solver_gc_time = first_timed.gctime,
    solver_allocated_bytes = first_timed.bytes,
    readback_wall = readback_wall,
    readback_compile_time = readback_timed.compile_time,
    readback_recompile_time = readback_timed.recompile_time,
    v_shape = size(result.v_matrix),
    v_real_bits = [bitstring(real(x)) for x in result.v_matrix],
    v_imag_bits = [bitstring(imag(x)) for x in result.v_matrix],
    checkpoint = checkpoint_file,
)
write(joinpath(root, "result.json"), JSON3.write(record))
println("EXPERT_WANNIER_PROBE_OK compile=$(first_timed.compile_time)")
