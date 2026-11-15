@testset "Wannierization retained internal optimizer controls" begin
    fixture = synthetic_wannierization_fixture()
    @test_throws ArgumentError WANNIERIZATION._validate_wannierization_config(
        modified_wannierization_config(
            fixture.config;
            acceleration = WANNIERIZATION.WannierizationAccelerationConfig(strategy = :unknown),
        ),
    )
    safeguard = WANNIERIZATION.WannierizationAccelerationConfig()
    @test safeguard.disentanglement_limit_policy == :standard_continue
    @test !hasfield(WANNIERIZATION.WannierizationAccelerationConfig, :joint_z_backtracking_factor)
    @test_throws ArgumentError WANNIERIZATION.WannierizationAccelerationConfig(
        joint_z_backtracking_factor = 0.5,
    )
    @test !hasfield(
        WANNIERIZATION.WannierizationAccelerationConfig,
        :joint_z_backtracking_max_steps,
    )
    @test_throws ArgumentError WANNIERIZATION.WannierizationAccelerationConfig(
        joint_z_backtracking_max_steps = 12,
    )
    @test safeguard.u_phase_branch_tolerance == 1.0e-6
    @test safeguard.u_branch_active_set_max_orbits == 64
    @test !hasfield(WANNIERIZATION.WannierizationAccelerationConfig, :u_lbfgs_history)
    @test_throws ArgumentError WANNIERIZATION.WannierizationAccelerationConfig(u_lbfgs_history = 8)
    @test !hasfield(WANNIERIZATION.WannierizationAccelerationConfig, :u_lbfgs_curvature_tolerance)
    @test_throws ArgumentError WANNIERIZATION.WannierizationAccelerationConfig(
        u_lbfgs_curvature_tolerance = 1.0e-12,
    )
    @test safeguard.u_wolfe_c2 == 0.9
    @test safeguard.u_line_search_max_trials == 24
    @test !hasfield(WANNIERIZATION.WannierizationAccelerationConfig, :disentanglement_algorithm)
    @test_throws ArgumentError WANNIERIZATION.WannierizationAccelerationConfig(
        disentanglement_algorithm = :smv_fixed_point,
    )
    @test safeguard.subspace_gauge_policy == :boundary_cluster_procrustes
    @test safeguard.u_recursive_localization_restart_interval == 5
    @test safeguard.u_recursive_localization_trial_step == 2.0
    @test !hasfield(WANNIERIZATION.WannierizationAccelerationConfig, :trust_radius_initial)
    @test_throws ArgumentError WANNIERIZATION.WannierizationAccelerationConfig(
        trust_radius_initial = 0.25,
    )
    @test !hasfield(WANNIERIZATION.WannierizationAccelerationConfig, :trust_radius_maximum)
    @test_throws ArgumentError WANNIERIZATION.WannierizationAccelerationConfig(
        trust_radius_maximum = 1.0,
    )
    @test safeguard.hot_storage_backend == :legacy_vector
    @test WANNIERIZATION.WannierizationMultiStartConfig().start_index == 1
    @test WANNIERIZATION.WannierizationMultiStartConfig(
        enabled = true,
        starts = 4,
        start_index = 4,
    ).start_index == 4
    @test_throws ArgumentError WANNIERIZATION.WannierizationMultiStartConfig(
        enabled = true,
        starts = 4,
        start_index = 5,
    )
    @test_throws ArgumentError WANNIERIZATION._validate_wannierization_config(
        modified_wannierization_config(
            fixture.config;
            initialization_backend = WANNIERIZATION.PAWSCDMInitialization(),
        ),
    )
    projectability_config = modified_wannierization_config(
        fixture.config;
        amn_file = "synthetic.amn",
        initialization_backend = WANNIERIZATION.ProjectabilityDisentanglementInitialization(),
    )
    WANNIERIZATION._validate_wannierization_config(projectability_config)
    bad_projectability_amn = fill(ComplexF64(0.5), 2, 1, 2)
    bad_projectability_result = WANNIERIZATION._solve_symmetry_adapted_wannierization(
        projectability_config,
        fixture.representation,
        fixture.eig,
        fixture.mmn,
        fixture.plan;
        amn = bad_projectability_amn,
    )
    @test bad_projectability_result.status == WANNIERIZATION.INVALID_INPUT
    @test any(
        diagnostic -> diagnostic.code == :PROJECTABILITY_GRAM_PRECONDITION_FAILED,
        bad_projectability_result.diagnostics,
    )
    good_projectability_amn = zeros(ComplexF64, 2, 1, 2)
    good_projectability_amn[1, 1, :] .= 1.0
    good_projectability_result = WANNIERIZATION._solve_symmetry_adapted_wannierization(
        projectability_config,
        fixture.representation,
        fixture.eig,
        fixture.mmn,
        fixture.plan;
        amn = good_projectability_amn,
    )
    @test get(
        good_projectability_result.input_summary,
        "projectability_trial_projector_gram_residual",
        "missing",
    ) == "0.0"
    @test WANNIERIZATION._localization_backtracking_limit(safeguard, :gradient) == 23
    @test WANNIERIZATION._localization_backtracking_limit(safeguard, :polar) == 23
    @test WANNIERIZATION._localization_backtracking_limit(
        WANNIERIZATION.WannierizationAccelerationConfig(
            u_acceptance = :armijo,
            u_backtracking_max_steps = 0,
            u_line_search_max_trials = 5,
        ),
        :gradient,
    ) == 4
    @test WANNIERIZATION._localization_backtracking_limit(
        WANNIERIZATION.WannierizationAccelerationConfig(
            u_acceptance = :monotone,
            u_backtracking_max_steps = 7,
            u_line_search_max_trials = 5,
        ),
        :gradient,
    ) == 7
    @test_throws ArgumentError WANNIERIZATION.WannierizationAccelerationConfig(
        localization_algorithm = :riemannian_lbfgs,
        u_acceptance = :strong_wolfe,
    )
    reference_step = WANNIERIZATION._recursive_localization_optimal_step(10.0, 9.0, -2.0, 2.0)
    @test reference_step.success
    @test reference_step.quadratic
    @test reference_step.alpha == 4 / 3
    unstable_step = WANNIERIZATION._recursive_localization_optimal_step(0.0, -1.0, -2.0, 2.0)
    @test unstable_step.success
    @test !unstable_step.quadratic
    @test unstable_step.alpha == 2.0
    generator = ComplexF64[0 1; -1 0]
    reference_unitary = WANNIERIZATION._recursive_localization_unitary_step(
        Matrix{ComplexF64}(I, 2, 2),
        generator,
        2.0,
        3.0,
    )
    @test reference_unitary' * reference_unitary ≈ Matrix{ComplexF64}(I, 2, 2) atol = 1.0e-14
    first_reference_direction = WANNIERIZATION._recursive_localization_search_direction(
        [generator],
        nothing,
        nothing,
        0,
        5,
        3.0,
    )
    @test first_reference_direction.success
    @test first_reference_direction.beta == 0.0
    @test first_reference_direction.cg_count == 0
    full_rank_amn = ComplexF64[2 0; 0 0.5]
    full_rank_polar = WANNIERIZATION._sealed_amn_polar(full_rank_amn, 1.0e-8, 1.0e10)
    @test full_rank_polar.success
    @test full_rank_polar.rank == 2
    @test full_rank_polar.completion_count == 0
    @test full_rank_polar.unitary ≈ Matrix{ComplexF64}(I, 2, 2) atol = 1.0e-14
    rank_deficient_amn = ComplexF64[1 0; 0 1.0e-12]
    completed_once = WANNIERIZATION._sealed_amn_polar(rank_deficient_amn, 1.0e-8, 1.0e10)
    completed_twice = WANNIERIZATION._sealed_amn_polar(rank_deficient_amn, 1.0e-8, 1.0e10)
    @test completed_once.success
    @test completed_once.rank == 1
    @test completed_once.completion_count == 1
    @test completed_once.unitary == completed_twice.unitary
    @test completed_once.unitary' * completed_once.unitary ≈ Matrix{ComplexF64}(I, 2, 2) atol =
        1.0e-14
    reference_rank_deficient = WANNIERIZATION._recursive_localization_amn_polar(rank_deficient_amn)
    @test reference_rank_deficient.success
    @test reference_rank_deficient.rank == 2
    @test reference_rank_deficient.completion_count == 0
    @test reference_rank_deficient.singular_values == [1.0, 1.0e-12]
    @test reference_rank_deficient.unitary ≈ Matrix{ComplexF64}(I, 2, 2) atol = 1.0e-14
    @test reference_rank_deficient.unitary' * reference_rank_deficient.unitary ≈
          Matrix{ComplexF64}(I, 2, 2) atol = 1.0e-14
    @test !WANNIERIZATION._recursive_localization_amn_polar(zeros(ComplexF64, 2, 3)).success
    packed_spectrum = WANNIERIZATION._recursive_localization_zhpevx(ComplexF64[1 2+1im; 2-1im 3])
    @test packed_spectrum.success
    @test packed_spectrum.values ≈ [-0.449489742783178, 4.449489742783178] atol = 1.0e-14
    @test ComplexF64[1 2+1im; 2-1im 3] * packed_spectrum.vectors ≈
          packed_spectrum.vectors * Diagonal(packed_spectrum.values) atol = 2.0e-14
    reference_subspace = WANNIERIZATION._recursive_localization_maximum_subspace_result(
        ComplexF64[4 0 0; 0 1 0; 0 0 3],
        [1, 2, 3],
        [2],
        2,
    )
    @test reference_subspace.success
    @test reference_subspace.backend == :packed_selected_eigensolve
    @test reference_subspace.frame == ComplexF64[0 1; 1 0; 0 0]
    solver_root = joinpath(
        dirname(dirname(pathof(WannierNLQG))),
        "ext",
        "WannierNLQGWannierizationExt",
        "solver",
    )
    solver_source = join(
        read(joinpath(solver_root, filename), String) for filename in (
            "LinearAlgebra.jl",
            "SymmetryFrames.jl",
            "Initialization.jl",
            "Localization.jl",
            "Optimizer.jl",
            "RestartWorkflow.jl",
        )
    )
    models_root = joinpath(dirname(pathof(WannierNLQG)), "Wannierization", "models")
    models_source = join(
        read(joinpath(models_root, filename), String) for filename in (
            "ConfigurationsContracts.jl",
            "OptimizerStates.jl",
            "DiagnosticsQualification.jl",
            "ResultsArtifacts.jl",
        )
    )
    @test !occursin("WANNIERNLQG_LOCALIZATION_GRADIENT_KERNEL", solver_source)
    @test !occursin("_recursive_localization_external_", solver_source)
    @test !occursin("recursive_localization_localization_frames_bin", models_source)
    @test !occursin("recursive_localization_initial_frames_bin", models_source)
    phase_probe = ComplexF64(-0.713, 0.419)
    platform_phase = ccall(
        (
            :atan2,
            WANNIERIZATION_IMPLEMENTATION.SolverCheckpoint._RECURSIVE_LOCALIZATION_SYSTEM_LIBM,
        ),
        Cdouble,
        (Cdouble, Cdouble),
        imag(phase_probe),
        real(phase_probe),
    )
    @test WANNIERIZATION._recursive_localization_phase(phase_probe) === platform_phase
    complex_exponential_probe = WANNIERIZATION._recursive_localization_complex_exponential(
        ComplexF64(0.0, 0.821883981306476),
    )
    @test reinterpret(UInt64, real(complex_exponential_probe)) == 0x3fe5c976473dc00c
    @test reinterpret(UInt64, imag(complex_exponential_probe)) == 0x3fe77010ab45086b
    real_dominant_column_value =
        Base.inferencebarrier(ComplexF64(0.9843349227773451, 1.4100220563663763e-11))
    conjugate_product_probe =
        WANNIERIZATION._recursive_localization_ordered_column_conjugate_product(
            real_dominant_column_value,
            real_dominant_column_value,
        )
    @test reinterpret(UInt64, real(conjugate_product_probe)) == 0x3fef015a88a80889
    @test reinterpret(UInt64, imag(conjugate_product_probe)) == 0xba480d93b207bc8a
    phase_column_value = ComplexF64(-0.00041618483987089066, 0.0007580881748940868)
    phase_column_phase = WANNIERIZATION._recursive_localization_complex_exponential(
        ComplexF64(0.0, 1.6788638613347698e-7),
    )
    phase_column_probe = WANNIERIZATION._recursive_localization_ordered_phase_column_product(
        phase_column_value,
        phase_column_phase,
    )
    @test reinterpret(UInt64, real(phase_column_probe)) == 0xbf3b466cd2ae0fa9
    expected_phase_column_imaginary_bits =
        Sys.ARCH === :aarch64 ? UInt64(0x3f48d74dcf2ce3c1) : UInt64(0x3f48d74dcf2ce3c0)
    @test reinterpret(UInt64, imag(phase_column_probe)) == expected_phase_column_imaginary_bits
    magnitude_squared_probe =
        WANNIERIZATION._recursive_localization_ordered_magnitude_squared(real_dominant_column_value)
    @test reinterpret(UInt64, magnitude_squared_probe) == 0x3fef015a88a80889
    scalar_magnitude_probe =
        WANNIERIZATION._recursive_localization_ordered_scalar_magnitude_squared(
            ComplexF64(5.976494614502479e-6, 2.2378355787923001e-7),
        )
    @test reinterpret(UInt64, scalar_magnitude_probe) == 0x3dc3a9fa704742c7
    objective_center_probe = WANNIERIZATION._recursive_localization_objective_center_accumulate(
        Base.inferencebarrier(0.9277112815446888),
        Base.inferencebarrier(1.257800476663593),
        Base.inferencebarrier(-0.7279437274706391),
        Base.inferencebarrier(-0.5025316007125938),
    )
    gradient_center_probe = WANNIERIZATION._recursive_localization_gradient_center_accumulate(
        Base.inferencebarrier(0.9277112815446888),
        Base.inferencebarrier(-0.7279437274706391),
        Base.inferencebarrier(1.257800476663593 * -0.5025316007125938),
    )
    @test reinterpret(UInt64, objective_center_probe) == 0x3ff634909b004b1d
    @test reinterpret(UInt64, gradient_center_probe) == 0x3ff634909b004b1e
    @test objective_center_probe != gradient_center_probe
    omega_d_probe = WANNIERIZATION._recursive_localization_omega_d_accumulate(
        Base.inferencebarrier(-0.21766510678354617),
        Base.inferencebarrier(0.4922456865251828),
        Base.inferencebarrier(0.9809798121241488),
    )
    @test reinterpret(UInt64, omega_d_probe) == 0x3fd062da1ccb1045
    division_real_dominant_probe = WANNIERIZATION._recursive_localization_ordered_column_division(
        real_dominant_column_value,
        real_dominant_column_value,
    )
    @test reinterpret(UInt64, real(division_real_dominant_probe)) == 0x3ff0000000000000
    @test reinterpret(UInt64, imag(division_real_dominant_probe)) == 0x39fc95e2bb3b185d
    division_imaginary_dominant_probe =
        WANNIERIZATION._recursive_localization_ordered_column_division(
            ComplexF64(3.225987418061329e-6, -3.6406254051401294e-6),
            ComplexF64(0.08821054908604604, 0.6064330003313873),
        )
    @test reinterpret(UInt64, real(division_imaginary_dominant_probe)) == 0xbed57adb093f77da
    @test reinterpret(UInt64, imag(division_imaginary_dominant_probe)) == 0xbed96fbdb822ce94
    for acceleration in (
        WANNIERIZATION.WannierizationAccelerationConfig(disentanglement_limit_policy = :invalid),
        WANNIERIZATION.WannierizationAccelerationConfig(u_phase_branch_tolerance = 0.0),
        WANNIERIZATION.WannierizationAccelerationConfig(u_branch_active_set_max_orbits = 0),
        WANNIERIZATION.WannierizationAccelerationConfig(u_wolfe_c2 = 1.0),
        WANNIERIZATION.WannierizationAccelerationConfig(u_line_search_max_trials = 0),
        WANNIERIZATION.WannierizationAccelerationConfig(subspace_gauge_policy = :invalid),
        WANNIERIZATION.WannierizationAccelerationConfig(
            u_recursive_localization_restart_interval = 0,
        ),
        WANNIERIZATION.WannierizationAccelerationConfig(u_recursive_localization_trial_step = 0.0),
        WANNIERIZATION.WannierizationAccelerationConfig(hot_storage_backend = :invalid),
    )
        @test_throws ArgumentError WANNIERIZATION._validate_wannierization_config(
            modified_wannierization_config(fixture.config; acceleration),
        )
    end
    for strategy in (:adaptive, :anderson_z)
        @test_throws ArgumentError WANNIERIZATION._validate_wannierization_config(
            modified_wannierization_config(
                fixture.config;
                acceleration = WANNIERIZATION.WannierizationAccelerationConfig(; strategy),
            ),
        )
    end
    broken_frames = [reshape(ComplexF64[2.0, 0.0], 2, 1) for _ in 1:2]
    fixed_failure = WANNIERIZATION._candidate_invariant_failure(
        broken_frames,
        zeros(1, 3),
        zeros(1),
        [Int[], Int[]],
        fixture.representation,
        fixture.plan,
        1.0e-10,
        1.0e-3,
    )
    @test first(fixed_failure) == :SOLVER_TRIAL_ISOMETRY_FAILED
    for helper in (
        :_acceleration_trial_action,
        :_shrunken_acceleration_mixing,
        :_adaptive_next_mixing,
        :_anderson_trial_policy,
        :_anderson_z_proposal,
        :_objective_aware_anderson_decision,
    )
        @test !isdefined(WANNIERIZATION, helper)
    end
    @test safeguard.u_cg_restart_interval == 20
    @test safeguard.u_cg_beta_cap == 10.0
    @test safeguard.u_cg_minimum_descent_cosine == 1.0e-3

    boundary_field = [Matrix(Diagonal(ComplexF64[3.0, 2.0, 1.0]))]
    @test WANNIERIZATION._minimum_z_boundary_gap(boundary_field, [[1, 2, 3]], [1], 2) ≈ 1.0 atol =
        1.0e-14

    fixed_multi = modified_wannierization_config(
        fixture.config;
        # Keep genuine Z freedom: the Plan skips fully frozen targets.
        frozen_min_ev = Inf,
        frozen_max_ev = -Inf,
        stage_controls = WANNIERIZATION.WannierizationStageControls(
            dis_num_iter = 5,
            num_iter = 0,
            dis_conv_tol = 1.0e-10,
            dis_conv_window = 20,
            conv_tol = 1.0e-10,
            conv_window = 20,
        ),
        acceleration = WANNIERIZATION.WannierizationAccelerationConfig(
            strategy = :fixed,
            schedule = :two_stage,
            u_inner_sweeps = 2,
        ),
    )
    multi_result = WANNIERIZATION._solve_symmetry_adapted_wannierization(
        fixed_multi,
        fixture.representation,
        fixture.eig,
        fixture.mmn,
        fixture.plan,
    )
    @test multi_result.status == WANNIERIZATION.MAX_ITERATIONS
    @test all(entry -> entry.diagnostics.u_inner_sweeps <= 2, multi_result.history)
    @test all(entry -> isnan(entry.diagnostics.z_boundary_gap), multi_result.history)
    multi_start_selection = WANNIERIZATION._select_wannierization_multistart(
        [multi_result, multi_result];
        long_range_tails = [2.0, 1.0],
        elapsed_seconds = [1.0, 2.0],
    )
    @test multi_start_selection.winner_index == 2
    @test !multi_start_selection.held_out_bands_used
    perturbed_a = WANNIERIZATION._deterministic_sealed_subspace_perturbation(
        [Matrix{ComplexF64}(I, 2, 2)],
        UInt64(0x1234),
        2,
    )
    perturbed_b = WANNIERIZATION._deterministic_sealed_subspace_perturbation(
        [Matrix{ComplexF64}(I, 2, 2)],
        UInt64(0x1234),
        2,
    )
    @test perturbed_a == perturbed_b
    @test perturbed_a[1]' * perturbed_a[1] ≈ Matrix{ComplexF64}(I, 2, 2) atol = 1.0e-14
    @test WANNIERIZATION._maximum_projector_step([Matrix{ComplexF64}(I, 2, 2)], perturbed_a) <=
          1.0e-14
    @test WANNIERIZATION._fixed_subspace_projector_drift_tolerance(:riemannian_cg) == 1.0e-12
    @test WANNIERIZATION._fixed_subspace_projector_drift_tolerance(
        :smv_fletcher_reeves_two_stage,
    ) == 1.0e-10
    @test 1.2533349271546236e-12 <=
          WANNIERIZATION._fixed_subspace_projector_drift_tolerance(:smv_fletcher_reeves_two_stage)
    @test 1.2533349271546236e-12 >
          WANNIERIZATION._fixed_subspace_projector_drift_tolerance(:riemannian_cg)

    @test_throws ArgumentError WANNIERIZATION.WannierizationAccelerationConfig(
        disentanglement_algorithm = :grassmann_trust_region,
    )
    @test_throws ArgumentError WANNIERIZATION.WannierizationAccelerationConfig(schedule = :joint)
    for keyword in (:adaptive_patience, :anderson_start_iteration, :anderson_depth)
        @test_throws ArgumentError WANNIERIZATION.WannierizationAccelerationConfig(; keyword => 2)
    end
end

@testset "Wannierization exact restart state" begin
    fixture = synthetic_wannierization_fixture()
    config = WANNIERIZATION._replace_wannierization_config(
        fixture.config;
        input = (frozen_min_ev = Inf, frozen_max_ev = -Inf),
        solver = (
            stage_controls = WANNIERIZATION.WannierizationStageControls(
                dis_num_iter = 2,
                num_iter = 0,
                dis_conv_tol = 1.0e-10,
                dis_conv_window = 1,
                conv_tol = 1.0e-10,
                conv_window = 1,
            ),
        ),
    )
    uninterrupted = WANNIERIZATION._solve_symmetry_adapted_wannierization(
        config,
        fixture.representation,
        fixture.eig,
        fixture.mmn,
        fixture.plan,
    )
    saved_state = Ref{Union{Nothing, WANNIERIZATION.WannierizationRestartState}}(nothing)
    saved_history = Ref(WANNIERIZATION.WannierizationIteration[])
    observer = function (_, state, history, _)
        saved_state[] = state
        saved_history[] = copy(history)
        throw(InterruptException())
    end
    interrupted = WANNIERIZATION._solve_symmetry_adapted_wannierization(
        config,
        fixture.representation,
        fixture.eig,
        fixture.mmn,
        fixture.plan;
        observer,
    )
    @test interrupted.status == WANNIERIZATION.IO_FAILURE
    @test any(
        diagnostic -> diagnostic.code == :ITERATION_OBSERVER_PERSISTENCE_FAILED,
        interrupted.diagnostics,
    )
    resumed = WANNIERIZATION._solve_symmetry_adapted_wannierization(
        config,
        fixture.representation,
        fixture.eig,
        fixture.mmn,
        fixture.plan;
        restart = something(saved_state[]).frames,
        restart_state = something(saved_state[]),
        restart_history = saved_history[],
        restart_input_summary = interrupted.input_summary,
    )
    @test resumed.v_matrix == uninterrupted.v_matrix
    @test resumed.wannier_centers_cartesian == uninterrupted.wannier_centers_cartesian
    @test resumed.spreads_angstrom2 == uninterrupted.spreads_angstrom2
    @test getfield.(resumed.history, :spread_total) ==
          getfield.(uninterrupted.history, :spread_total)
end
