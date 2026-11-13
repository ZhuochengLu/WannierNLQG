@testset "SAWF zero optimization keeps physical initial observables" begin
    fixture = synthetic_wannierization_fixture()
    config = modified_wannierization_config(
        fixture.config;
        stage_controls = WANNIERIZATION.WannierizationStageControls(dis_num_iter = 0, num_iter = 0),
    )
    result = WANNIERIZATION._solve_symmetry_adapted_wannierization(
        config,
        fixture.representation,
        fixture.eig,
        fixture.mmn,
        fixture.plan,
    )
    @test result.status == WANNIERIZATION.COMPLETED_WITH_WARNINGS
    @test any(d -> d.code == :OPTIMIZATION_SKIPPED, result.diagnostics)
    @test isempty(result.history)
    @test result.input_summary["disentanglement_convergence"] == "SKIPPED_ZERO_STEPS"
    @test result.input_summary["localization_convergence"] == "SKIPPED_ZERO_STEPS"
    @test result.input_summary["disentanglement_steps"] == "0"
    @test result.input_summary["localization_steps"] == "0"
    reevaluated = WANNIERIZATION.evaluate_full_3d_wannier_spreads(
        result,
        fixture.representation,
        fixture.mmn,
        fixture.plan,
    )
    @test result.spreads_angstrom2 == reevaluated.spreads_angstrom2
    @test result.restart_state.spreads_angstrom2 == result.spreads_angstrom2
    @test result.restart_state.frames == result.v_matrix
end
