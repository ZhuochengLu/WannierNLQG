@testset "Solver stages retain accepted state across observer failure" begin
    fixture = synthetic_wannierization_fixture()
    @test_throws ArgumentError WANNIERIZATION.WannierizationAccelerationConfig(schedule = :joint)
    for schedule in (:two_stage,)
        acceleration = WANNIERIZATION.WannierizationAccelerationConfig(
            schedule = schedule,
            u_acceptance = :armijo,
            z_stability_window = 1,
            disentanglement_max_steps = 8,
            localization_max_steps = 8,
        )
        config = modified_wannierization_config(
            fixture.config;
            acceleration,
            stage_controls = WANNIERIZATION.WannierizationStageControls(
                dis_num_iter = 8,
                num_iter = 8,
                dis_conv_tol = 1e-10,
                dis_conv_window = 1,
                conv_tol = 1e-10,
                conv_window = 1,
            ),
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
        # Reject actual changed input definitions, never a retired hash field.
        original_definition = retained.input_definition
        @test original_definition !== nothing
        original_definition === nothing && error("accepted fixture lacks restart input definition")
        @test :input_definition in fieldnames(typeof(retained))
        @test :configuration in fieldnames(typeof(original_definition))
        for foreign_configuration in
            (repeat("0", 64), original_definition.configuration * "\nforeign_parameter=changed\n")
            D = typeof(original_definition)
            changed_definition = D(
                (
                    name === :configuration ? foreign_configuration :
                    getfield(original_definition, name) for name in fieldnames(D)
                )...,
            )
            T = typeof(retained)
            foreign = T(
                (
                    name === :input_definition ? changed_definition : getfield(retained, name)
                    for name in fieldnames(T)
                )...,
            )
            @test foreign.input_definition.configuration == foreign_configuration
            @test foreign.input_definition.configuration != original_definition.configuration
            @test retained.input_definition === original_definition
            rejected=solve(;
                restart = foreign.frames,
                restart_state = foreign,
                restart_history = copy(interrupted.history),
                restart_input_summary = interrupted.input_summary,
            )
            @test rejected.status==WANNIERIZATION.INVALID_INPUT
            @test any(d->d.code==:RESTART_CONFIG_MISMATCH, rejected.diagnostics)
            @test retained.frames==something(observed_frames[])
        end
    end
end
