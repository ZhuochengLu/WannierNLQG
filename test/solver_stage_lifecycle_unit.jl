@testset "Solver stages retain accepted state across observer failure" begin
    fixture = synthetic_wannierization_fixture()
    for schedule in (:joint, :two_stage)
        acceleration = WANNIERIZATION.WannierizationAccelerationConfig(
            schedule = schedule,
            localization_algorithm = :symmetry_projected_gradient,
            u_acceptance = :armijo,
            z_stability_window = 1,
            disentanglement_max_steps = 8,
            localization_max_steps = 8,
        )
        config = modified_wannierization_config(
            fixture.config;
            algorithm_profile = :custom,
            acceleration,
            max_iterations = 8,
        )
        solve(; keywords...) = WANNIERIZATION._solve_symmetry_adapted_wannierization(
            config,
            fixture.representation,
            fixture.eig,
            fixture.mmn,
            fixture.plan;
            keywords...,
        )
        uninterrupted = solve()
        observed_frames = Ref{Union{Nothing, Array{ComplexF64, 3}}}(nothing)
        interrupted = solve(;
            observer = (_, state, _, _) -> begin
                observed_frames[] = copy(state.frames)
                error("synthetic accepted-state persistence failure")
            end,
        )
        @test interrupted.status == WANNIERIZATION.IO_FAILURE
        @test interrupted.restart_state !== nothing
        @test something(interrupted.restart_state).iteration == 1
        @test length(interrupted.history) == 1
        @test interrupted.v_matrix == something(observed_frames[])
        @test all(isfinite, interrupted.v_matrix)
        @test any(
            diagnostic -> diagnostic.code == :ITERATION_OBSERVER_PERSISTENCE_FAILED,
            interrupted.diagnostics,
        )
        retained = deepcopy(something(interrupted.restart_state))
        resumed = solve(;
            restart = retained.frames,
            restart_state = retained,
            restart_history = copy(interrupted.history),
            restart_input_summary = interrupted.input_summary,
        )
        @test resumed.status == uninterrupted.status
        @test resumed.v_matrix == uninterrupted.v_matrix
        @test resumed.wannier_centers_cartesian == uninterrupted.wannier_centers_cartesian
        @test resumed.spreads_angstrom2 == uninterrupted.spreads_angstrom2
        @test getfield.(resumed.history, :spread_total) ==
              getfield.(uninterrupted.history, :spread_total)
        @test getfield.(resumed.history, :spread_standard_deviation) ==
              getfield.(uninterrupted.history, :spread_standard_deviation)
        @test retained.frames == something(observed_frames[])
    end
end
