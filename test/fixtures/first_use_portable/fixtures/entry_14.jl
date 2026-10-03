using Test
using LinearAlgebra
# Valid nonempty storage-contract input. These are declared synthetic diagnostic
# values, not claimed to be measured solver physics or a simulated solver result.
# The writer must persist every supplied field, a nonzero isometric complex frame,
# and per-kpoint arrays. No public writer is called while constructing the input.
const UW = WannierNLQG.Wannierization
numeric_names = (
    :spread_total,
    :trial_objective,
    :accepted_objective,
    :accepted_u_step_scale,
    :localization_backtracking_steps,
    :directional_derivative,
    :fixed_projector_drift,
    :base_objective,
    :accepted_required_change,
    :accepted_actual_change,
    :projector_residual,
    :maximum_covariance_error,
    :isometry_residual,
    :frozen_projector_residual,
    :z_recheck_drift,
    :one_step_geodesic_distance,
    :two_step_geodesic_distance,
    :aligned_one_step_geodesic_distance,
    :minimum_diagonal_phase_margin,
    :minimum_phase_kpoint,
    :minimum_phase_neighbor,
    :minimum_phase_wannier,
    :minimum_phase_value,
    :cg_beta,
    :cg_descent_cosine,
    :u_cg_iteration,
    :u_cg_restart_count,
    :maximum_kstar_gradient_rms,
    :maximum_kstar_gradient_index,
)
scalars = NamedTuple{numeric_names}(ntuple(i -> Float64(i)/100, length(numeric_names)))
record = merge(
    scalars,
    (
        iteration = 1,
        optimizer_phase = :localization,
        anderson_reason = :NOT_USED,
        cg_restarted = false,
        cg_restart_reason = :NOT_RESTARTED,
        branch_safe_backtracking_triggered = false,
        kstar_gradient_rms = [0.2],
        raw_spreads = [1.25],
        block_sorted_spreads = [1.25],
        gauge_aligned_spreads = [1.25],
        localization_spectra = Any[[1.0]],
        localization_ranks = [1],
        localization_conditions = [1.0],
        raw_eigenphases = Any[[0.1]],
        aligned_eigenphases = Any[[0.05]],
        raw_geodesic_distances = [0.1],
        aligned_geodesic_distances = [0.05],
        block_permutations = Any[[1]],
        block_phases = Any[[0.2]],
        one_step_geodesic_distances = [0.1],
        two_step_geodesic_distances = [0.15],
        aligned_one_step_geodesic_distances = [0.05],
    ),
)
records = NamedTuple[record]
frame = reshape(ComplexF64[inv(sqrt(2.0)), im * inv(sqrt(2.0))], 2, 1, 1)
@test isapprox(sum(abs2, frame), 1.0; atol = 1e-15)
frames=Array{ComplexF64, 3}[frame]
output=joinpath(dirname(Main.RECEIPT), "u-convergence-nonempty.h5")
actual=UW.write_wannierization_u_convergence_diagnostics_hdf5(
    output,
    records,
    frames,
    [1];
    metadata = Dict("fixture_kind"=>"synthetic_nonempty_storage_contract"),
)
@test actual==output
# The backend was loaded by the real first public writer call, not by the setup.
hdf5=only(filter(m -> nameof(m)==:HDF5, Base.loaded_modules_array()))
readback = function (handle)
    @test read(getproperty(hdf5, :attributes)(handle)["record_count"])==1
    @test read(getproperty(hdf5, :attributes)(handle)["ibz_kpoint_count"])==1
    @test read(handle["iterations/000001/ibz_frames"])==frame
    @test read(handle["iterations/000001/raw_spreads"])==[1.25]
    @test read(handle["iterations/000001/per_kpoint/000001/localization_singular_values"])==[1.0]
    @test read(handle["iterations/000001/per_kpoint/000001/block_permutation"])==[1]
    attrs=getproperty(hdf5, :attributes)(handle["iterations/000001"])
    for key in numeric_names
        @test read(attrs[String(key)])==getproperty(record, key)
    end
    @test all(isfinite, read(handle["iterations/000001/ibz_frames"]))
end
Base.invokelatest(getproperty(hdf5, :h5open), readback, output, "r")
