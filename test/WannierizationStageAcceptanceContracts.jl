@testset "Current two-stage acceptance and retired schedule rejection" begin
    fixture = synthetic_wannierization_fixture()
    fixture = merge(
        fixture,
        (
            config = modified_wannierization_config(
                fixture.config;
                frozen_min_ev = Inf,
                frozen_max_ev = -Inf,
            ),
        ),
    )
    legacy_schedule_error = try
        WANNIERIZATION.WannierizationAccelerationConfig(schedule = :nested)
        nothing
    catch exception
        exception
    end
    @test legacy_schedule_error isa ArgumentError
    @test occursin("REMOVED_SOLVER_SCHEDULE", sprint(showerror, legacy_schedule_error))
    legacy_parameter_error = try
        WANNIERIZATION.WannierizationAccelerationConfig(nested_z_max_steps = 8)
        nothing
    catch exception
        exception
    end
    @test legacy_parameter_error isa ArgumentError
    @test occursin("UNSUPPORTED_LEGACY_SCHEDULE", sprint(showerror, legacy_parameter_error))
    legacy_gradient_error = try
        WANNIERIZATION.WannierizationAccelerationConfig(gradient_max_steps = 2)
        nothing
    catch exception
        exception
    end
    @test legacy_gradient_error isa ArgumentError
    @test occursin("UNSUPPORTED_LEGACY_SOLVER_KEYWORD", sprint(showerror, legacy_gradient_error))

    matrix_status = Dict{Tuple{Symbol, Symbol}, WANNIERIZATION.WannierizationStatus}()
    matrix_results = Dict{Tuple{Symbol, Symbol}, WANNIERIZATION.WannierizationResult}()
    for schedule in (:two_stage,), u_acceptance in (:armijo, :monotone, :invariant_only)
        phases = Symbol[]
        basepoint_residuals = Float64[]
        basepoint_frame_residuals = Float64[]
        acceleration = WANNIERIZATION.WannierizationAccelerationConfig(
            schedule = schedule,
            u_acceptance = u_acceptance,
            z_projector_tolerance = 1.0e-8,
            z_stability_window = 1,
            disentanglement_objective_tolerance = 1.0e-8,
            disentanglement_max_steps = 8,
            localization_max_steps = 8,
            u_inner_tolerance = 1.0e-8,
            u_gradient_norm_tolerance = 1.0e-8,
        )
        config = modified_wannierization_config(
            fixture.config;
            acceleration,
            stage_controls = WANNIERIZATION.WannierizationStageControls(
                dis_num_iter = 8,
                num_iter = 8,
                dis_conv_tol = 1.0e-8,
                dis_conv_window = 1,
                conv_tol = 1.0e-8,
                conv_window = 1,
            ),
            u_mix_ratio = 1.0,
        )
        result = WANNIERIZATION._solve_symmetry_adapted_wannierization(
            config,
            fixture.representation,
            fixture.eig,
            fixture.mmn,
            fixture.plan;
            observer = function (summary, _, _, _)
                push!(phases, summary.optimizer_phase)
                if isfinite(summary.base_objective) && isfinite(summary.trial_zero_objective)
                    push!(
                        basepoint_residuals,
                        abs(summary.trial_zero_objective - summary.base_objective),
                    )
                end
                push!(basepoint_frame_residuals, summary.trial_zero_frame_residual)
            end,
        )
        matrix_status[(schedule, u_acceptance)] = result.status
        matrix_results[(schedule, u_acceptance)] = result
        @test result.status in (
            WANNIERIZATION.COMPLETED,
            WANNIERIZATION.COMPLETED_WITH_WARNINGS,
            WANNIERIZATION.MAX_ITERATIONS,
        )
        @test result.restart_state !== nothing
        @test result.input_summary["optimizer_schedule"] == String(schedule)
        @test result.input_summary["u_acceptance"] == String(u_acceptance)
        @test schedule == :joint ? (:joint in phases) : (:localization in phases)
        @test !isempty(result.restart_state.optimizer_state.disentanglement_objective_history)
        @test schedule == :joint || result.restart_state.optimizer_state.z_steps > 0
        optimizer = result.restart_state.optimizer_state
        @test length(optimizer.localization_trial_step_scales) ==
              length(optimizer.localization_trial_objectives) ==
              length(optimizer.localization_trial_required_changes) ==
              length(optimizer.localization_trial_actual_changes) ==
              length(optimizer.localization_trial_directional_derivatives) ==
              length(optimizer.localization_trial_iterations) ==
              length(optimizer.localization_trial_sweeps) ==
              length(optimizer.localization_trial_accepted)
        @test all(>(0), optimizer.localization_trial_iterations)
        @test all(>(0), optimizer.localization_trial_sweeps)
        @test any(optimizer.localization_trial_accepted)
        if u_acceptance == :armijo
            for index in eachindex(optimizer.localization_trial_accepted)
                optimizer.localization_trial_accepted[index] || continue
                required = optimizer.localization_trial_required_changes[index]
                actual = optimizer.localization_trial_actual_changes[index]
                derivative = optimizer.localization_trial_directional_derivatives[index]
                tolerance = 1.0e-12 + 1.0e-10 * max(abs(required), abs(actual), 1.0)
                @test derivative < 0.0
                @test actual <= required + tolerance
            end
        end
        @test length(optimizer.localization_projector_drift_history) ==
              length(optimizer.localization_objective_history)
        if schedule == :two_stage
            @test length(optimizer.disentanglement_objective_history) == optimizer.z_steps
            @test result.restart_state.fixed_subspace_projectors !== nothing
            @test result.restart_state.fixed_subspace_frames !== nothing
            sealed_projectors = something(result.restart_state.fixed_subspace_projectors)
            @test maximum(
                norm(
                    @view(result.v_matrix[:, :, kpoint]) * @view(result.v_matrix[:, :, kpoint])' -
                    @view(sealed_projectors[:, :, kpoint]),
                ) for kpoint in axes(result.v_matrix, 3)
            ) <= 1.0e-12
            @test isempty(optimizer.localization_projector_drift_history) ||
                  maximum(optimizer.localization_projector_drift_history) <= 1.0e-12
        end
        @test !isempty(basepoint_residuals)
        @test maximum(basepoint_residuals) <= 128eps(Float64)
        @test !isempty(basepoint_frame_residuals)
        @test maximum(basepoint_frame_residuals) == 0.0
    end
    @test length(matrix_status) == 3
    @test_throws ArgumentError WANNIERIZATION.WannierizationAccelerationConfig(schedule = :joint)
    @test_throws ArgumentError WANNIERIZATION.WannierizationAccelerationConfig(
        localization_algorithm = :symmetry_projected_gradient,
    )

    diagnostic_limit = WANNIERIZATION._solve_symmetry_adapted_wannierization(
        modified_wannierization_config(
            fixture.config;
            stage_controls = WANNIERIZATION.WannierizationStageControls(
                dis_num_iter = 1,
                num_iter = 2,
                dis_conv_tol = 0.0,
                dis_conv_window = 20,
                conv_tol = 1.0e-10,
                conv_window = 20,
            ),
            acceleration = WANNIERIZATION.WannierizationAccelerationConfig(
                schedule = :two_stage,
                disentanglement_max_steps = 1,
                disentanglement_objective_tolerance = 0.0,
                z_projector_tolerance = 1.0e-30,
                localization_max_steps = 2,
                disentanglement_limit_policy = :standard_continue,
            ),
        ),
        fixture.representation,
        fixture.eig,
        fixture.mmn,
        fixture.plan,
    )
    @test diagnostic_limit.input_summary["z_seal_class"] == "NONCONVERGED_RETAINED"
    @test diagnostic_limit.restart_state.fixed_subspace_projectors !== nothing
    @test !haskey(diagnostic_limit.input_summary, "disentanglement_state_sha256")
    @test diagnostic_limit.input_summary["disentanglement_outer_mask_definition"] ==
          WannierNLQG.SymmetryFoundation.qualification_mask_definition(
        diagnostic_limit.restart_state.included_bands,
    )
    frozen_indices = [
        WANNIERIZATION_IMPLEMENTATION.SolverCheckpoint._frozen_indices(
            fixture.config,
            fixture.representation,
            k,
        ) for k in axes(fixture.eig.data, 2)
    ]
    frozen_mask = BitMatrix(
        hcat(
            (
                BitVector([band in indices for band in axes(fixture.eig.data, 1)]) for
                indices in frozen_indices
            )...,
        ),
    )
    @test diagnostic_limit.input_summary["disentanglement_frozen_mask_definition"] ==
          WannierNLQG.SymmetryFoundation.qualification_mask_definition(frozen_mask)
    @test diagnostic_limit.input_summary["disentanglement_state_converged"] == "false"
    @test diagnostic_limit.input_summary["localization_qualification"] == "STANDARD"
    # Availability labels are not a scientific credential. Check the retained
    # finite numerical state and explicit nonconvergence warning instead.
    @test all(
        projector -> all(isfinite, projector),
        diagnostic_limit.restart_state.fixed_subspace_projectors,
    )
    @test diagnostic_limit.restart_state.optimizer_state.u_steps > 0
    @test any(
        diagnostic -> diagnostic.code == :DISENTANGLEMENT_MAX_STEPS_CONTINUED_STANDARD,
        diagnostic_limit.diagnostics,
    )

    rank_deficient_continuation = WANNIERIZATION._qualify_nonconverged_disentanglement_state(
        [zeros(ComplexF64, 2, 1), zeros(ComplexF64, 2, 1)],
        [Matrix{ComplexF64}(I, 2, 2), Matrix{ComplexF64}(I, 2, 2)],
        zeros(1, 3),
        zeros(1),
        [[1], [1]],
        fixture.representation,
        fixture.plan,
        1.0e-10,
        1.0e-8,
        true,
    )
    @test !rank_deficient_continuation.qualified
    @test rank_deficient_continuation.failure_code == :RANK_DEFICIENT_DISENTANGLEMENT_PROJECTOR

    strict_limit = WANNIERIZATION._solve_symmetry_adapted_wannierization(
        modified_wannierization_config(
            fixture.config;
            stage_controls = WANNIERIZATION.WannierizationStageControls(
                dis_num_iter = 1,
                num_iter = 2,
                dis_conv_tol = 0.0,
                dis_conv_window = 20,
                conv_tol = 1.0e-10,
                conv_window = 20,
            ),
            acceleration = WANNIERIZATION.WannierizationAccelerationConfig(
                schedule = :two_stage,
                disentanglement_max_steps = 1,
                disentanglement_objective_tolerance = 0.0,
                z_projector_tolerance = 1.0e-30,
                localization_max_steps = 2,
                disentanglement_limit_policy = :strict_hold,
            ),
        ),
        fixture.representation,
        fixture.eig,
        fixture.mmn,
        fixture.plan,
    )
    @test strict_limit.input_summary["z_seal_class"] == "NONCONVERGED_RETAINED"
    @test strict_limit.input_summary["localization_qualification"] == "NOT_RUN"
    @test strict_limit.restart_state.fixed_subspace_projectors === nothing
    @test strict_limit.restart_state.optimizer_state.phase == :disentanglement
    @test any(
        diagnostic -> diagnostic.code == :DISENTANGLEMENT_MAX_STEPS_STRICT_HOLD,
        strict_limit.diagnostics,
    )

    # Plan removes independent joint/gradient/RCG/LBFGS and fixed_subspace
    # workflows. Internal fixed-Z projectors are asserted above for current U.
    @test_throws ArgumentError WANNIERIZATION.WannierizationAccelerationConfig(
        schedule = :fixed_subspace,
    )
    @test !isdefined(WANNIERIZATION, :write_wannierization_fixed_subspace_hdf5)
    @test !isdefined(WANNIERIZATION, :read_wannierization_fixed_subspace_hdf5)
    for algorithm in (:riemannian_cg, :riemannian_lbfgs, :symmetry_projected_gradient)
        @test_throws ArgumentError WANNIERIZATION.WannierizationAccelerationConfig(
            localization_algorithm = algorithm,
        )
    end

    phases = Symbol[]
    acceleration = WANNIERIZATION.WannierizationAccelerationConfig(
        schedule = :two_stage,
        u_acceptance = :armijo,
        z_projector_tolerance = 1.0e-8,
        z_stability_window = 1,
        disentanglement_objective_tolerance = 1.0e-8,
        disentanglement_max_steps = 8,
        localization_max_steps = 20,
        u_inner_tolerance = 1.0e-8,
        u_gradient_norm_tolerance = 1.0e-8,
    )
    config = modified_wannierization_config(
        fixture.config;
        acceleration,
        stage_controls = WANNIERIZATION.WannierizationStageControls(
            dis_num_iter = 8,
            num_iter = 20,
            dis_conv_tol = 1.0e-8,
            dis_conv_window = 1,
            conv_tol = 1.0e-8,
            conv_window = 1,
        ),
        u_mix_ratio = 1.0,
    )
    result = WANNIERIZATION._solve_symmetry_adapted_wannierization(
        config,
        fixture.representation,
        fixture.eig,
        fixture.mmn,
        fixture.plan;
        observer = (summary, _, _, _) -> push!(phases, summary.optimizer_phase),
    )
    @test :localization in phases
    @test result.restart_state !== nothing
    @test result.restart_state.optimizer_state.z_steps > 0
    @test !isempty(result.restart_state.optimizer_state.disentanglement_objective_history)
    @test !isempty(result.restart_state.optimizer_state.localization_objective_history)
    @test result.status in (
        WANNIERIZATION.COMPLETED,
        WANNIERIZATION.COMPLETED_WITH_WARNINGS,
        WANNIERIZATION.MAX_ITERATIONS,
    )

    continuation_config = modified_wannierization_config(
        config;
        stage_controls = WANNIERIZATION.WannierizationStageControls(
            dis_num_iter = 6,
            num_iter = 20,
            dis_conv_tol = 1.0e-8,
            dis_conv_window = 20,
            conv_tol = 1.0e-8,
            conv_window = 20,
        ),
    )
    uninterrupted = WANNIERIZATION._solve_symmetry_adapted_wannierization(
        continuation_config,
        fixture.representation,
        fixture.eig,
        fixture.mmn,
        fixture.plan,
    )
    partial = WANNIERIZATION._solve_symmetry_adapted_wannierization(
        modified_wannierization_config(
            continuation_config;
            stage_controls = WANNIERIZATION.WannierizationStageControls(
                dis_num_iter = 3,
                num_iter = 20,
                dis_conv_tol = 1.0e-8,
                dis_conv_window = 20,
                conv_tol = 1.0e-8,
                conv_window = 20,
            ),
        ),
        fixture.representation,
        fixture.eig,
        fixture.mmn,
        fixture.plan,
    )
    resumed = WANNIERIZATION._solve_symmetry_adapted_wannierization(
        continuation_config,
        fixture.representation,
        fixture.eig,
        fixture.mmn,
        fixture.plan;
        restart = partial.v_matrix,
        restart_state = partial.restart_state,
        restart_history = partial.history,
        restart_input_summary = partial.input_summary,
    )
    @test resumed.v_matrix == uninterrupted.v_matrix
    @test resumed.wannier_centers_cartesian == uninterrupted.wannier_centers_cartesian
    @test resumed.spreads_angstrom2 == uninterrupted.spreads_angstrom2
    @test resumed.restart_state.optimizer_state.phase ==
          uninterrupted.restart_state.optimizer_state.phase
    @test resumed.restart_state.optimizer_state.z_steps ==
          uninterrupted.restart_state.optimizer_state.z_steps
    @test resumed.restart_state.optimizer_state.u_steps ==
          uninterrupted.restart_state.optimizer_state.u_steps
end
