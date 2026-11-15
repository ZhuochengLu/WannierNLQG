isdefined(@__MODULE__, :InternalSolverFixture) ||
    include(joinpath(@__DIR__, "support", "InternalSolverFixture.jl"))
using Test
@testset "Independent fixed-subspace entry removed" begin
    w=WannierNLQG.Wannierization
    @test !hasfield(w.WannierizationCheckpointConfig, :fixed_subspace_hdf5)
    @test !isdefined(w, :read_wannierization_fixed_subspace_hdf5)
    @test !isdefined(w, :write_wannierization_fixed_subspace_hdf5)
    @test !isdefined(w, :_fixed_subspace_initial_frames)
    @test !hasfield(w.WannierizationSolverConfig, :algorithm_profile)
    @test !hasfield(w.WannierizationAccelerationConfig, :localization_algorithm)
    @test !hasfield(w.WannierizationAccelerationConfig, :disentanglement_algorithm)
    @test_throws MethodError InternalSolverFixture.solver_config(algorithm_profile = :custom)
    @test_throws ArgumentError w.WannierizationAccelerationConfig(
        localization_algorithm = :riemannian_lbfgs,
    )
    @test hasfield(w.WannierizationRestartState, :fixed_subspace_projectors)
    @test hasfield(w.WannierizationRestartState, :fixed_subspace_frames)
    @test_throws MethodError w.WannierizationCheckpointConfig(fixed_subspace_hdf5 = "obsolete.h5")
end

@testset "Removed exclusive optimizer implementations" begin
    ext, _ = WannierNLQG.Wannierization._load_wannierization_extension!()
    solver = ext.SolverCheckpoint
    for name in (
        :_anderson_trial_policy,
        :_anderson_z_proposal,
        :_objective_aware_anderson_decision,
        :_riemannian_lbfgs_direction,
        :_grassmann_trust_region_step,
        :_adaptive_next_mixing,
    )
        @test !isdefined(solver, name)
    end
end
