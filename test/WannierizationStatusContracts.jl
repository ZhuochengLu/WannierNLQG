@testset "Wannierization solver statuses and covariance" begin
    fixture = synthetic_wannierization_fixture()
    analytic_report = WANNIERIZATION.validate_band_representation_compatibility(
        fixture.representation,
        fixture.plan;
        tolerance = fixture.config.input.representation_tolerance,
    )
    # Algebra-only empirical tolerance fixture: retain the actual representation
    # binding; no invented digest or qualification record is supplied.
    empirical_values = (
        maximum_group_law_residuals = (1.0e-5, 2.0e-5, 1.5e-5, 1.25e-5),
        band_group_law_residuals = (1.0e-5, 2.0e-5, 1.5e-5, 1.25e-5),
        metadata_origin = :irrep_paired_oracle,
        oracle_excess_group_law_residuals = (0.0, 0.0, 0.0, 0.0),
        qualification_record = nothing,
        validation_profile = :empirical,
    )
    empirical_report = WANNIERIZATION.RepresentationCompatibilityReport(
        (
            haskey(empirical_values, name) ? getproperty(empirical_values, name) :
            getfield(analytic_report, name) for name in fieldnames(typeof(analytic_report))
        )...,
    )
    @test empirical_report.representation_definition == analytic_report.representation_definition
    @test !hasproperty(empirical_report, :representation_sha256)
    @test WANNIERIZATION._projector_covariance_tolerance(fixture.config, analytic_report) ==
          fixture.config.input.representation_tolerance
    @test WANNIERIZATION._projector_covariance_tolerance(fixture.config, empirical_report) == 2.0e-5
    declared_budget_config =
        modified_wannierization_config(fixture.config; empirical_covariance_budget = 1.0e-3)
    @test WANNIERIZATION._projector_covariance_tolerance(
        declared_budget_config,
        empirical_report,
    ) == 1.0e-3
    workflow_extension = Base.get_extension(WannierNLQG, :WannierNLQGWannierizationExt)
    @test workflow_extension !== nothing
    @test Base.invokelatest(
        workflow_extension.WorkflowOrchestration._final_tb_hamiltonian_covariance_threshold,
        declared_budget_config,
    ) == fixture.config.input.representation_tolerance
    nonlocalizing_config = modified_wannierization_config(
        fixture.config;
        stage_controls = WANNIERIZATION.WannierizationStageControls(
            dis_num_iter = 8,
            num_iter = 0,
            dis_conv_tol = 1e-8,
            dis_conv_window = 1,
        ),
    )
    result = WANNIERIZATION._solve_symmetry_adapted_wannierization(
        nonlocalizing_config,
        fixture.representation,
        fixture.eig,
        fixture.mmn,
        fixture.plan,
    )
    @test result.status == WANNIERIZATION.COMPLETED
    @test result.wannier_chk !== nothing
    # Fully frozen target: the current Plan skips Z rather than manufacturing accepted steps.
    @test isempty(result.history)
    @test result.input_summary["disentanglement_convergence"] == "NOT_APPLICABLE"
    @test result.input_summary["localization_convergence"] == "SKIPPED_ZERO_STEPS"
    @test result.restart_state.optimizer_state.phase == :completed
    @test maximum(abs, result.v_matrix[:, :, 1]' * result.v_matrix[:, :, 1] - I) <= 1.0e-14
    frames = [Matrix(@view(result.v_matrix[:, :, kpoint])) for kpoint in 1:2]
    @test WANNIERIZATION._maximum_projector_covariance_error(frames, fixture.representation) <=
          1.0e-14
    reevaluated = WANNIERIZATION.evaluate_full_3d_wannier_spreads(
        result,
        fixture.representation,
        fixture.mmn,
        fixture.plan,
    )
    @test reevaluated.spreads_angstrom2 == result.spreads_angstrom2
    @test abs(sum(reevaluated.omega_directional) - reevaluated.omega_total) <= 1.0e-10
    shifted_center_images = copy(result.wannier_centers_cartesian)
    shifted_center_images[1, :] .+= fixture.representation.real_lattice[1, :]
    shifted_reevaluation = WANNIERIZATION.evaluate_full_3d_wannier_spreads(
        result.v_matrix,
        shifted_center_images,
        fixture.representation,
        fixture.mmn,
        fixture.plan,
    )
    @test shifted_reevaluation.spreads_angstrom2 == reevaluated.spreads_angstrom2
    @test shifted_reevaluation.omega_directional == reevaluated.omega_directional
    @test shifted_reevaluation.centers_cartesian[1, :] ≈ shifted_center_images[1, :] atol = 1.0e-14 rtol =
        0.0

    singular_fixture = synthetic_wannierization_fixture(; mmn_scale = 0.0)
    singular = WANNIERIZATION._solve_symmetry_adapted_wannierization(
        modified_wannierization_config(
            singular_fixture.config;
            frozen_min_ev = Inf,
            frozen_max_ev = -Inf,
        ),
        singular_fixture.representation,
        singular_fixture.eig,
        singular_fixture.mmn,
        singular_fixture.plan,
    )
    @test singular.status == WANNIERIZATION.SINGULAR_LOCALIZATION
    @test singular.restart_state !== nothing
    @test singular.restart_state.iteration > 0
    @test singular.restart_state.z_previous !== nothing
    @test singular.restart_state.optimizer_state.phase == :localization
    @test all(isfinite, singular.v_matrix)
    @test any(
        diagnostic -> diagnostic.code == :SPREAD_GRADIENT_DIAGONAL_OVERLAP_SINGULAR,
        singular.diagnostics,
    )

    incompatible_representation = deepcopy(fixture.representation)
    incompatible_representation.sewing_matrices[1, 1, 1, 1] = 0.0
    for policy in (:off, :warn, :strict)
        policy_config =
            modified_wannierization_config(fixture.config; compatibility_policy = policy)
        incompatible = WANNIERIZATION._solve_symmetry_adapted_wannierization(
            policy_config,
            incompatible_representation,
            fixture.eig,
            fixture.mmn,
            fixture.plan,
        )
        @test incompatible.status == WANNIERIZATION.REPRESENTATION_INCOMPATIBLE
        @test isempty(incompatible.history)
        @test incompatible.input_summary["failure_class"] == "REPRESENTATION_A"
        @test any(
            diagnostic -> diagnostic.code == :REQUIRED_BLOCK_UNITARITY_FAILED,
            incompatible.diagnostics,
        )
        rank_failure = only(
            filter(
                diagnostic -> diagnostic.code == :SEWING_BLOCK_RANK_DEFICIENT,
                incompatible.diagnostics,
            ),
        )
        @test rank_failure.severity == :error
        @test parse(Int, rank_failure.context["numerical_rank"]) == 1
        @test parse(Int, rank_failure.context["required_rank"]) == 2
        @test parse(Float64, rank_failure.context["minimum_singular_value"]) == 0.0
        @test parse(Float64, rank_failure.context["rank_threshold"]) > 0.0
        @test !haskey(rank_failure.context, "action")
    end

    # A full-rank finite nonunitarity defect is reportable for ordinary policies;
    # an independently requested strict compatibility policy still rejects it.
    finite_representation = deepcopy(fixture.representation)
    finite_representation.sewing_matrices[1, 1, 1, 1] = 1.01
    for policy in (:off, :warn, :strict)
        policy_config =
            modified_wannierization_config(fixture.config; compatibility_policy = policy)
        outcome = WANNIERIZATION._solve_symmetry_adapted_wannierization(
            policy_config,
            finite_representation,
            fixture.eig,
            fixture.mmn,
            fixture.plan,
        )
        @test !any(d -> d.code == :SEWING_BLOCK_RANK_DEFICIENT, outcome.diagnostics)
        @test any(d -> d.code == :REQUIRED_BLOCK_UNITARITY_FAILED, outcome.diagnostics)
        if policy == :strict
            @test outcome.status == WANNIERIZATION.REPRESENTATION_INCOMPATIBLE
            @test isempty(outcome.history)
            @test !any(
                d -> get(d.context, "action", "") == "CONTINUE_STANDARD",
                outcome.diagnostics,
            )
        else
            @test outcome.status != WANNIERIZATION.REPRESENTATION_INCOMPATIBLE
            @test all(isfinite, outcome.v_matrix)
            @test any(d -> d.code == :REPRESENTATION_POLICY_CONTINUATION, outcome.diagnostics)
        end
    end

    for invalid_value in (ComplexF64(NaN), ComplexF64(Inf))
        nonfinite_representation = deepcopy(fixture.representation)
        nonfinite_representation.sewing_matrices[1, 1, 1, 1] = invalid_value
        @test_throws ArgumentError WANNIERIZATION.validate_band_representation_compatibility(
            nonfinite_representation,
            fixture.plan,
        )
    end

    wrong_mmn = WANNIER_IO.WannierMMN(
        1,
        2,
        1,
        ones(ComplexF64, 1, 1, 1, 2),
        ones(Int, 1, 2),
        zeros(Int, 3, 1, 2),
    )
    invalid = WANNIERIZATION._solve_symmetry_adapted_wannierization(
        fixture.config,
        fixture.representation,
        fixture.eig,
        wrong_mmn,
        fixture.plan,
    )
    @test invalid.status == WANNIERIZATION.INVALID_INPUT
    @test only(invalid.diagnostics).code == :MMN_DIMENSION_MISMATCH
end

include(joinpath(@__DIR__, "WannierizationZeroObservableContracts.jl"))
