@testset "Symmetry-free full-BZ Wannierization contracts" begin
    fixture = synthetic_wannierization_fixture()
    no_symmetry_config = modified_wannierization_config(
        fixture.config;
        wannierization_mode = :ordinary,
        band_representation = nothing,
        initialization = :random,
        symmetrize_z = true,
    )
    @test WANNIERIZATION._validate_wannierization_config(no_symmetry_config) === nothing
    explicit_ordinary_config =
        modified_wannierization_config(no_symmetry_config; wannierization_mode = :ordinary)
    @test WANNIERIZATION._validate_wannierization_config(explicit_ordinary_config) === nothing
    @test WANNIERIZATION._effective_wannierization_mode(explicit_ordinary_config) == :ordinary
    @test !WANNIERIZATION._symmetry_constraints_applied(explicit_ordinary_config)
    @test WANNIERIZATION._restart_config_repr(explicit_ordinary_config) ==
          WANNIERIZATION._restart_config_repr(no_symmetry_config)
    @test_throws ArgumentError WANNIERIZATION._validate_wannierization_config(
        modified_wannierization_config(fixture.config; wannierization_mode = :ordinary),
    )
    @test_throws ArgumentError WANNIERIZATION._validate_wannierization_config(
        modified_wannierization_config(no_symmetry_config; wannierization_mode = :symmetry_adapted),
    )
    augmentation_ordinary_config = modified_wannierization_config(
        explicit_ordinary_config;
        sewing_backend = WANNIERIZATION.AugmentationAwareSewing(),
    )
    @test WANNIERIZATION._validate_wannierization_config(augmentation_ordinary_config) === nothing
    @test WANNIERIZATION._validate_wannierization_config(
        modified_wannierization_config(
            no_symmetry_config;
            band_representation_hdf5 = "identity.schema-1.4.h5",
        ),
    ) === nothing
    @test_throws UndefKeywordError WANNIERIZATION.WannierizationConfig(
        symmetry_mode = :none,
        win_file = "x.win",
        eig_file = "x.eig",
        mmn_file = "x.mmn",
    )
    @test_throws ArgumentError WANNIERIZATION._validate_wannierization_config(
        modified_wannierization_config(
            no_symmetry_config;
            wannierization_mode = :ordinary_no_symmetry,
        ),
    )
    @test_throws ArgumentError WANNIERIZATION.WannierizationAccelerationConfig(
        disentanglement_algorithm = :recursive_localization,
        localization_algorithm = :recursive_localization,
    )
    @test_throws ArgumentError WANNIERIZATION._validate_wannierization_config(
        modified_wannierization_config(
            no_symmetry_config;
            band_representation = fixture.representation,
        ),
    )
    @test_throws ArgumentError WANNIERIZATION._validate_wannierization_config(
        modified_wannierization_config(
            fixture.config;
            wannierization_mode = :symmetry_adapted,
            band_representation = nothing,
        ),
    )
    @test_throws ArgumentError WANNIERIZATION._validate_wannierization_config(
        modified_wannierization_config(
            fixture.config;
            wannierization_mode = :symmetry_adapted,
            band_representation = nothing,
        ),
    )

    extension, _ = WANNIERIZATION._load_wannierization_extension!()
    mktempdir() do directory
        win_file = joinpath(directory, "full-bz.win")
        write(
            win_file,
            """
            mp_grid = 2 1 1
            begin unit_cell_cart
            bohr
            2.0d0 0.0 0.0
            0.0 2.0d0 0.0
            0.0 0.0 2.0d0
            end unit_cell_cart
            begin kpoints
            0.0 0.0 0.0
            0.5 0.0 0.0
            end kpoints
            """,
        )
        mesh = extension.SolverCheckpoint._read_wannierization_win_mesh(win_file)
        @test mesh.mp_grid == (2, 1, 1)
        @test mesh.kpoints_fractional == [0.0 0.0 0.0; 0.5 0.0 0.0]
        @test mesh.lattice ≈ 2.0 * 0.529177210903 .* Matrix{Float64}(I, 3, 3)

        identity_config = modified_wannierization_config(no_symmetry_config; win_file)
        identity_representation = extension.SolverCheckpoint._identity_band_representation(
            identity_config,
            fixture.basis,
            fixture.eig,
        )
        @test length(identity_representation.operations) == 1
        @test !only(identity_representation.operations).antiunitary
        @test identity_representation.irreducible_indices == [1, 2]
        @test identity_representation.full_to_irreducible == [1, 2]
        @test identity_representation.kpoint_map == reshape([1, 2], 1, 2)
        @test all(iszero, identity_representation.reciprocal_shifts)
        @test identity_representation.band_block_labels == [1 1; 2 2]
        @test all(
            kpoint ->
                identity_representation.sewing_matrices[:, :, 1, kpoint] ≈
                Matrix{ComplexF64}(I, 2, 2),
            1:2,
        )
        augmentation_identity_representation =
            extension.SolverCheckpoint._identity_band_representation(
                modified_wannierization_config(
                    identity_config;
                    wannierization_mode = :ordinary,
                    sewing_backend = WANNIERIZATION.AugmentationAwareSewing(),
                ),
                fixture.basis,
                fixture.eig,
            )
        @test augmentation_identity_representation.conventions["sewing_backend"] ==
              "augmentation_aware_paw_q0"
        @test augmentation_identity_representation.conventions["sewing_role"] ==
              "identity_only_no_symmetry"
        @test augmentation_identity_representation.conventions["augmentation_metric_role"] ==
              "ordinary_wannierization_input_metric"

        exact_frozen_config = modified_wannierization_config(
            identity_config;
            initialization = :amn,
            amn_file = "seed.amn",
            frozen_states = [(1, 1), (2, 1)],
        )
        frozen = [
            WANNIERIZATION._frozen_indices(exact_frozen_config, identity_representation, k) for
            k in 1:2
        ]
        @test frozen == [[1], [1]]

        first_amn = zeros(ComplexF64, 2, 1, 2)
        first_amn[1, 1, :] .= 1.0
        second_amn = copy(first_amn)
        second_amn[1, 1, 2] = 1.0im
        first_frames, first_diagnostics, first_invariants, first_report =
            WANNIERIZATION._initial_frames_with_diagnostics(
                exact_frozen_config,
                identity_representation,
                [[1, 2], [1, 2]],
                frozen,
                1,
                first_amn,
                nothing,
            )
        second_frames, _, _, second_report = WANNIERIZATION._initial_frames_with_diagnostics(
            exact_frozen_config,
            identity_representation,
            [[1, 2], [1, 2]],
            frozen,
            1,
            second_amn,
            nothing,
        )
        @test length(first_diagnostics) == 2
        @test first_invariants.maximum_isometry <= 1.0e-8
        @test first_report.algorithm == :recursive_localization_amn_frozen_projection
        @test first_report.algorithm_version == "wannier-4.0.1-dis_project-dis_proj_froz-v1"
        @test second_report.algorithm_version == first_report.algorithm_version
        # A phase-only change of a fully frozen one-dimensional AMN row does
        # not alter the exact frozen projector or its canonical frame.
        @test first_frames == second_frames
        @test all(frame -> frame * frame' ≈ ComplexF64[1 0; 0 0], first_frames)

        contract = extension.SolverCheckpoint._no_symmetry_compatibility_contract(
            identity_representation,
            1.0e-8,
        )
        @test contract.passed
        @test contract.metadata_origin == :not_applicable
        @test only(contract.diagnostics).code == :SYMMETRY_CONSTRAINTS_DISABLED
        @test WANNIERIZATION._restart_config_repr(identity_config) !=
              WANNIERIZATION._restart_config_repr(fixture.config)
        # Old digest reconstruction is not a normal continuation capability.
        for name in (:_restart_config_sha256_pre_v2_6, :_restart_config_sha256_pre_v2_7)
            @test !isdefined(WANNIERIZATION, name)
        end
        provided_tolerance_changed =
            modified_wannierization_config(fixture.config; symmetry_tolerance = 2.0e-5)
        @test WANNIERIZATION._restart_config_repr(provided_tolerance_changed) ==
              WANNIERIZATION._restart_config_repr(fixture.config)
        no_symmetry_tolerance_changed =
            modified_wannierization_config(identity_config; symmetry_tolerance = 2.0e-5)
        @test WANNIERIZATION._restart_config_repr(no_symmetry_tolerance_changed) ==
              WANNIERIZATION._restart_config_repr(identity_config)
        detected_config = modified_wannierization_config(
            fixture.config;
            wannierization_mode = :symmetry_adapted,
            source = WannierNLQG.SymmetryFoundation.VASPWavefunctionSource("POSCAR", "WAVECAR"),
            band_representation = nothing,
            symmetry_tolerance = 1.0e-5,
        )
        detected_tolerance_changed =
            modified_wannierization_config(detected_config; symmetry_tolerance = 2.0e-5)
        @test WANNIERIZATION._restart_config_repr(detected_tolerance_changed) !=
              WANNIERIZATION._restart_config_repr(detected_config)

        solver_config = modified_wannierization_config(
            no_symmetry_config;
            frozen_states = [(1, 1), (2, 1)],
            stage_controls = WANNIERIZATION.WannierizationStageControls(
                dis_num_iter = 3,
                num_iter = 0,
                dis_conv_tol = 1.0e-10,
                dis_conv_window = 10,
                conv_tol = 1.0e-10,
                conv_window = 10,
            ),
        )
        identity_plan = extension.SolverCheckpoint._identity_wannier_plan(
            1,
            only(fixture.representation.operations),
        )
        solver_contract = extension.SolverCheckpoint._no_symmetry_compatibility_contract(
            fixture.representation,
            1.0e-8,
        )
        localization_entries_before = WANNIERIZATION._localization_sweep_entry_count()
        no_symmetry_result = WANNIERIZATION._solve_symmetry_adapted_wannierization(
            solver_config,
            fixture.representation,
            fixture.eig,
            fixture.mmn,
            identity_plan;
            compatibility_report = solver_contract,
        )
        @test WANNIERIZATION._localization_sweep_entry_count() == localization_entries_before
        # Plan section5: a fully frozen target has no Z freedom; U is explicitly zero.
        @test no_symmetry_result.status == WANNIERIZATION.COMPLETED
        @test no_symmetry_result.input_summary["disentanglement_convergence"] == "NOT_APPLICABLE"
        @test no_symmetry_result.input_summary["localization_convergence"] == "SKIPPED_ZERO_STEPS"
        @test no_symmetry_result.restart_state.optimizer_state.z_steps == 0
        @test no_symmetry_result.restart_state.optimizer_state.u_steps == 0
        @test no_symmetry_result.input_summary["requested_wannierization_mode"] == "ordinary"
        @test no_symmetry_result.input_summary["effective_wannierization_mode"] == "ordinary"
        @test no_symmetry_result.input_summary["representation_source"] == "identity"
        @test no_symmetry_result.input_summary["symmetry_constraints_applied"] == "false"
        @test no_symmetry_result.input_summary["effective_symmetry_operation_count"] == "1"
        @test no_symmetry_result.input_summary["effective_antiunitary_operation_count"] == "0"
        @test no_symmetry_result.input_summary["effective_symmetrize_z"] == "false"
        @test no_symmetry_result.input_summary["covariance_applicability"] == "STANDARD"
        @test parse(Float64, no_symmetry_result.input_summary["hard_gate_frozen"]) <= 1.0e-10
        @test all(entry -> iszero(entry.maximum_covariance_error), no_symmetry_result.history)

        # The fixed SMV/FR solver is represented by current grouped controls.
        # Rebuilding the immutable groups must preserve the exact numerical path;
        # removed selector rejection is checked in the primitive contracts.
        ordinary_auto_solver = solver_config
        explicit_smv_fr_solver = WANNIERIZATION._replace_wannierization_config(
            solver_config;
            solver = (stage_controls = solver_config.solver.stage_controls,),
        )
        ordinary_auto_result = WANNIERIZATION._solve_symmetry_adapted_wannierization(
            ordinary_auto_solver,
            fixture.representation,
            fixture.eig,
            fixture.mmn,
            identity_plan;
            compatibility_report = solver_contract,
        )
        explicit_smv_fr_result = WANNIERIZATION._solve_symmetry_adapted_wannierization(
            explicit_smv_fr_solver,
            fixture.representation,
            fixture.eig,
            fixture.mmn,
            identity_plan;
            compatibility_report = solver_contract,
        )
        @test ordinary_auto_result.v_matrix == explicit_smv_fr_result.v_matrix
        @test ordinary_auto_result.spreads_angstrom2 == explicit_smv_fr_result.spreads_angstrom2
        @test ordinary_auto_result.history == explicit_smv_fr_result.history
        @test ordinary_auto_result.input_summary["effective_algorithm_profile"] ==
              "smv_fletcher_reeves_two_stage"
        @test ordinary_auto_result.input_summary["smv_fletcher_reeves_two_stage_default_selection_reason"] ==
              "UNCONDITIONAL_ORDINARY_DEFAULT"
        @test ordinary_auto_result.input_summary["smv_fletcher_reeves_two_stage_audit_status"] ==
              "NOT_CHECKED"

        # A schema-1.15 identity group selected through the symmetry route
        # keeps the new profile provenance while executing the ordinary exact
        # SMV--FR arithmetic.  The two routes must remain value-for-value
        # identical through the solver and TB construction boundaries.
        identity_ordinary_solver = modified_wannierization_config(
            ordinary_auto_solver;
            initialization = :amn,
            amn_file = "identity-seed.amn",
            stage_controls = WANNIERIZATION.WannierizationStageControls(
                dis_num_iter = 8,
                num_iter = 0,
                dis_conv_tol = 1.0e-10,
                dis_conv_window = 1,
                conv_tol = 1.0e-10,
                conv_window = 1,
            ),
        )
        symmetry_identity_seed = modified_wannierization_config(
            fixture.config;
            win_file,
            band_representation = identity_representation,
            frozen_states = [(1, 1), (2, 1)],
            initialization = :amn,
            amn_file = "identity-seed.amn",
            stage_controls = WANNIERIZATION.WannierizationStageControls(
                dis_num_iter = 8,
                num_iter = 0,
                dis_conv_tol = 1.0e-10,
                dis_conv_window = 1,
                conv_tol = 1.0e-10,
                conv_window = 1,
            ),
        )
        symmetry_identity_representation = Base.invokelatest(
            extension.WorkflowOrchestration._representation_with_mode_contract,
            identity_representation,
            symmetry_identity_seed,
        )
        symmetry_identity_config = modified_wannierization_config(
            symmetry_identity_seed;
            band_representation = symmetry_identity_representation,
        )
        identity_algorithms =
            WANNIERIZATION._effective_wannierization_algorithms(symmetry_identity_config)
        @test identity_algorithms.profile == :symmetry_projected_smv_fletcher_reeves_two_stage
        @test identity_algorithms.disentanglement == :smv_fletcher_reeves_two_stage
        @test identity_algorithms.localization == :smv_fletcher_reeves_two_stage
        @test identity_algorithms.default_selection_reason ==
              "IDENTITY_GROUP_EXACT_ORDINARY_FAST_PATH"
        @test !WANNIERIZATION._symmetry_constraints_applied(symmetry_identity_config)
        @test symmetry_identity_representation.conventions["symmetry_constraints_applied"] ==
              "false"
        @test WANNIERIZATION._validate_wannierization_config(symmetry_identity_config) === nothing
        symmetry_identity_hdf5_config = modified_wannierization_config(
            symmetry_identity_config;
            band_representation = nothing,
            band_representation_hdf5 = "synthetic-identity-representation.h5",
        )
        hdf5_identity_algorithms = WANNIERIZATION._effective_wannierization_algorithms(
            symmetry_identity_hdf5_config,
            symmetry_identity_representation,
        )
        @test hdf5_identity_algorithms == identity_algorithms
        @test !WANNIERIZATION._symmetry_constraints_applied(
            symmetry_identity_hdf5_config,
            symmetry_identity_representation,
        )
        # The current restart API receives effective algorithms and the actual
        # applied-symmetry flag, not the old digest API's representation argument.
        @test WANNIERIZATION._restart_config_repr(
            symmetry_identity_hdf5_config,
            hdf5_identity_algorithms,
            WANNIERIZATION._symmetry_constraints_applied(
                symmetry_identity_hdf5_config,
                symmetry_identity_representation,
            ),
        ) == WANNIERIZATION._restart_config_repr(
            symmetry_identity_config,
            identity_algorithms,
            WANNIERIZATION._symmetry_constraints_applied(
                symmetry_identity_config,
                symmetry_identity_representation,
            ),
        )
        ordinary_identity_result = WANNIERIZATION._solve_symmetry_adapted_wannierization(
            identity_ordinary_solver,
            symmetry_identity_representation,
            fixture.eig,
            fixture.mmn,
            identity_plan;
            amn = first_amn,
            compatibility_report = solver_contract,
        )
        symmetry_identity_result = WANNIERIZATION._solve_symmetry_adapted_wannierization(
            symmetry_identity_config,
            symmetry_identity_representation,
            fixture.eig,
            fixture.mmn,
            identity_plan;
            amn = first_amn,
            compatibility_report = solver_contract,
        )
        symmetry_identity_hdf5_result = WANNIERIZATION._solve_symmetry_adapted_wannierization(
            symmetry_identity_hdf5_config,
            symmetry_identity_representation,
            fixture.eig,
            fixture.mmn,
            identity_plan;
            amn = first_amn,
            compatibility_report = solver_contract,
        )
        @test ordinary_identity_result.wannier_chk !== nothing
        @test ordinary_identity_result.restart_state !== nothing
        @test symmetry_identity_result.wannier_chk !== nothing
        @test symmetry_identity_result.restart_state !== nothing
        @test symmetry_identity_hdf5_result.wannier_chk !== nothing
        @test symmetry_identity_hdf5_result.restart_state !== nothing
        @test symmetry_identity_result.status == ordinary_identity_result.status
        @test symmetry_identity_result.v_matrix == ordinary_identity_result.v_matrix
        @test symmetry_identity_result.wannier_centers_cartesian ==
              ordinary_identity_result.wannier_centers_cartesian
        @test symmetry_identity_result.spreads_angstrom2 ==
              ordinary_identity_result.spreads_angstrom2
        @test symmetry_identity_result.history == ordinary_identity_result.history
        @test symmetry_identity_hdf5_result.v_matrix == ordinary_identity_result.v_matrix
        @test symmetry_identity_hdf5_result.spreads_angstrom2 ==
              ordinary_identity_result.spreads_angstrom2
        @test symmetry_identity_hdf5_result.history == ordinary_identity_result.history
        @test symmetry_identity_result.input_summary["identity_group_exact_ordinary_fast_path"] ==
              "true"
        @test symmetry_identity_result.input_summary["symmetry_projected_smv_fr_contract"] ==
              "NOT_APPLICABLE"
        ordinary_identity_tb = WANNIERIZATION.build_wannier_tight_binding_model(
            ordinary_identity_result,
            fixture.eig,
            fixture.mmn,
        )
        symmetry_identity_tb = WANNIERIZATION.build_wannier_tight_binding_model(
            symmetry_identity_result,
            fixture.eig,
            fixture.mmn,
        )
        @test symmetry_identity_tb.r_vectors == ordinary_identity_tb.r_vectors
        @test symmetry_identity_tb.r_degeneracies == ordinary_identity_tb.r_degeneracies
        @test maximum(
            abs,
            symmetry_identity_tb.hamiltonian_r - ordinary_identity_tb.hamiltonian_r;
            init = 0.0,
        ) == 0.0
        @test maximum(
            abs,
            symmetry_identity_tb.position_r - ordinary_identity_tb.position_r;
            init = 0.0,
        ) == 0.0
        mktempdir() do audit_directory
            invalid_manifest = joinpath(audit_directory, "invalid-audit.json")
            write(invalid_manifest, "{not-json")
            invalid_audit_config = modified_wannierization_config(
                ordinary_auto_solver;
                smv_fletcher_reeves_two_stage_audit_manifest = invalid_manifest,
            )
            invalid_audit_result = WANNIERIZATION._solve_symmetry_adapted_wannierization(
                invalid_audit_config,
                fixture.representation,
                fixture.eig,
                fixture.mmn,
                identity_plan;
                compatibility_report = solver_contract,
            )
            @test invalid_audit_result.v_matrix == ordinary_auto_result.v_matrix
            @test invalid_audit_result.spreads_angstrom2 == ordinary_auto_result.spreads_angstrom2
            @test invalid_audit_result.history == ordinary_auto_result.history
            @test invalid_audit_result.input_summary["smv_fletcher_reeves_two_stage_audit_status"] ==
                  "NOT_CHECKED"
        end

        # Both routes retain finite covariance defects; the symmetry route records
        # the original failed measurement at its accepted boundary.
        fixture.representation.sewing_matrices[:, :, 1, 1] .= ComplexF64[0 1; 1 0]
        trial_frames = [ComplexF64[1; 0;;], ComplexF64[1; 0;;]]
        ordinary_candidate = WANNIERIZATION._disentanglement_candidate(
            modified_wannierization_config(explicit_ordinary_config; band_representation = nothing),
            fixture.representation,
            fixture.mmn,
            identity_plan,
            fill(1.0 / 6.0, 6),
            [Int[], Int[]],
            trial_frames,
            zeros(1, 3),
            zeros(1),
            1.0e-12,
        )
        @test ordinary_candidate.success
        symmetry_candidate = WANNIERIZATION._disentanglement_candidate(
            fixture.config,
            fixture.representation,
            fixture.mmn,
            fixture.plan,
            fill(1.0 / 6.0, 6),
            [Int[], Int[]],
            trial_frames,
            zeros(1, 3),
            zeros(1),
            1.0e-12,
        )
        @test symmetry_candidate.success
        @test symmetry_candidate.code == :OK
        @test symmetry_candidate.frames == trial_frames
        symmetry_residuals = WANNIERIZATION._candidate_invariant_residuals(
            symmetry_candidate.frames,
            [Int[], Int[]],
            fixture.representation,
        )
        @test isfinite(symmetry_residuals.covariance) && symmetry_residuals.covariance > 1.0e-12
        symmetry_diagnostics = WANNIERIZATION.WannierizationDiagnostic[]
        symmetry_summary = Dict{String, String}()
        WANNIERIZATION_IMPLEMENTATION.SolverCheckpoint._record_construction_symmetry_quality!(
            symmetry_diagnostics,
            symmetry_summary,
            symmetry_candidate.frames,
            [Int[], Int[]],
            fixture.representation,
            fixture.plan,
            fixture.config,
            1.0e-12,
            "test_accepted_boundary";
            residuals = symmetry_residuals,
        )
        covariance_failure = only(
            filter(
                diagnostic -> diagnostic.code == :SOLVER_TRIAL_COVARIANCE_FAILED,
                symmetry_diagnostics,
            ),
        )
        @test covariance_failure.severity == :error
        @test covariance_failure.context["gate_result"] == "FAIL"
        @test covariance_failure.context["action"] == "CONTINUE_STANDARD"
        @test parse(Float64, covariance_failure.context["value"]) == symmetry_residuals.covariance
        @test parse(Float64, covariance_failure.context["threshold"]) == 1.0e-12
        @test symmetry_summary["construction_quality_failed"] == "true"
        @test symmetry_summary["model_qualification"] == "COMPUTATION_READY"
        fixture.representation.sewing_matrices[:, :, 1, 1] .= Matrix{ComplexF64}(I, 2, 2)

        cross_mode_config = modified_wannierization_config(
            fixture.config;
            initialization = :restart,
            restart_hdf5 = "cross-mode.wannierization.h5",
            stage_controls = WANNIERIZATION.WannierizationStageControls(
                dis_num_iter = 4,
                num_iter = 8,
                dis_conv_tol = 1.0e-10,
                dis_conv_window = 1,
                conv_tol = 1.0e-10,
                conv_window = 1,
            ),
        )
        cross_mode_result = WANNIERIZATION._solve_symmetry_adapted_wannierization(
            cross_mode_config,
            fixture.representation,
            fixture.eig,
            fixture.mmn,
            fixture.plan;
            restart = no_symmetry_result.v_matrix,
            restart_state = no_symmetry_result.restart_state,
            restart_history = no_symmetry_result.history,
            restart_input_summary = no_symmetry_result.input_summary,
        )
        @test cross_mode_result.status == WANNIERIZATION.INVALID_INPUT
        @test any(
            diagnostic -> diagnostic.code == :RESTART_EFFECTIVE_PROFILE_MISMATCH,
            cross_mode_result.diagnostics,
        )
    end
end

@testset "Ordinary zero-U projected AMN gauge" begin
    fixture = synthetic_wannierization_fixture()
    extension = WANNIERIZATION_IMPLEMENTATION
    plan = extension.SolverCheckpoint._identity_wannier_plan(
        1,
        only(fixture.representation.operations),
    )
    compatibility = extension.SolverCheckpoint._no_symmetry_compatibility_contract(
        fixture.representation,
        1.0e-8,
    )
    amn = reshape(ComplexF64[0.6 + 0.2im, 0.8 - 0.1im, 0.3 - 0.5im, 0.7 + 0.4im], 2, 1, 2)
    original_amn = copy(amn)
    config = modified_wannierization_config(
        fixture.config;
        wannierization_mode = :ordinary,
        band_representation = nothing,
        initialization = :amn,
        amn_file = "synthetic.amn",
        frozen_min_ev = Inf,
        frozen_max_ev = -Inf,
        acceleration = WANNIERIZATION.WannierizationAccelerationConfig(
            disentanglement_max_steps = 3,
            localization_max_steps = 0,
            z_stability_window = 20,
        ),
        stage_controls = WANNIERIZATION.WannierizationStageControls(
            dis_num_iter = 3,
            num_iter = 0,
            dis_conv_tol = 1.0e-10,
            dis_conv_window = 20,
            conv_tol = 1.0e-10,
            conv_window = 20,
        ),
    )
    before = WANNIERIZATION._localization_sweep_entry_count()
    result = WANNIERIZATION._solve_symmetry_adapted_wannierization(
        config,
        fixture.representation,
        fixture.eig,
        fixture.mmn,
        plan;
        amn,
        compatibility_report = compatibility,
    )
    @test result.status == WANNIERIZATION.MAX_ITERATIONS
    @test result.restart_state.optimizer_state.z_steps == 3
    @test result.restart_state.optimizer_state.u_steps == 0
    @test WANNIERIZATION._localization_sweep_entry_count() == before
    @test result.input_summary["localization_convergence"] == "SKIPPED_ZERO_STEPS"
    @test result.input_summary["localization_initial_gauge"] == "PROJECTED_AMN"
    @test amn == original_amn
    for kpoint in 1:2
        frame = result.v_matrix[:, :, kpoint]
        # Independent internal_find_u algebra: Q†A must be Hermitian positive
        # after the polar alignment.  A retains its original singular values.
        cross = frame' * amn[:, :, kpoint]
        @test cross ≈ cross' atol = 1.0e-12
        @test minimum(eigvals(Hermitian(cross))) > 0
        @test frame' * frame ≈ Matrix{ComplexF64}(I, 1, 1) atol = 1.0e-12
        sealed = result.restart_state.fixed_subspace_frames[:, :, kpoint]
        decomposition = svd(sealed' * amn[:, :, kpoint])
        @test frame ≈ sealed * (decomposition.U * decomposition.Vt) atol = 1.0e-12
        @test frame * frame' ≈ sealed * sealed' atol = 1.0e-12
    end
    resumed = WANNIERIZATION._solve_symmetry_adapted_wannierization(
        config,
        fixture.representation,
        fixture.eig,
        fixture.mmn,
        plan;
        amn,
        compatibility_report = compatibility,
        restart = result.v_matrix,
        restart_state = result.restart_state,
        restart_history = result.history,
        restart_input_summary = result.input_summary,
    )
    @test resumed.v_matrix == result.v_matrix
    @test resumed.wannier_centers_cartesian == result.wannier_centers_cartesian
    @test resumed.spreads_angstrom2 == result.spreads_angstrom2
    @test resumed.history == result.history
    frozen_config = modified_wannierization_config(
        config;
        outer_max_ev = -0.5,
        frozen_min_ev = -2.0,
        frozen_max_ev = -0.5,
    )
    frozen_result = WANNIERIZATION._solve_symmetry_adapted_wannierization(
        frozen_config,
        fixture.representation,
        fixture.eig,
        fixture.mmn,
        plan;
        amn,
        compatibility_report = compatibility,
    )
    @test frozen_result.restart_state.optimizer_state.z_steps == 0
    @test frozen_result.restart_state.optimizer_state.u_steps == 0
    @test frozen_result.input_summary["localization_initial_gauge"] == "PROJECTED_AMN"
    for kpoint in 1:2
        frame = frozen_result.v_matrix[:, :, kpoint]
        @test frame * frame' ≈ ComplexF64[1 0; 0 0] atol = 1.0e-12
        @test frame[1] ≈ amn[1, 1, kpoint] / abs(amn[1, 1, kpoint]) atol = 1.0e-12
    end
    bad_amn = copy(amn)
    bad_amn[1] = NaN
    rejected = WANNIERIZATION._solve_symmetry_adapted_wannierization(
        config,
        fixture.representation,
        fixture.eig,
        fixture.mmn,
        plan;
        amn = bad_amn,
        compatibility_report = compatibility,
    )
    @test !(rejected.status in (WANNIERIZATION.COMPLETED, WANNIERIZATION.COMPLETED_WITH_WARNINGS))
    @test any(d -> d.severity == :error, rejected.diagnostics)
end

@testset "Wannierization output intervals do not alter numerics" begin
    fixture = synthetic_wannierization_fixture()
    default_result = WANNIERIZATION._solve_symmetry_adapted_wannierization(
        fixture.config,
        fixture.representation,
        fixture.eig,
        fixture.mmn,
        fixture.plan,
    )
    observed_summaries = Any[]
    interval_result = WANNIERIZATION._solve_symmetry_adapted_wannierization(
        modified_wannierization_config(fixture.config; num_print_cycles = 50, num_dump_cycles = 50),
        fixture.representation,
        fixture.eig,
        fixture.mmn,
        fixture.plan;
        observer = (summary, _state, _history, _diagnostics) ->
            push!(observed_summaries, summary),
    )
    @test interval_result.v_matrix == default_result.v_matrix
    @test interval_result.wannier_centers_cartesian == default_result.wannier_centers_cartesian
    @test interval_result.spreads_angstrom2 == default_result.spreads_angstrom2
    @test interval_result.history == default_result.history
    @test length(observed_summaries) == length(interval_result.history)
    @test all(
        summary -> all(
            name -> hasproperty(summary, name),
            (
                :disentanglement_convergence,
                :z_seal_class,
                :localization_convergence,
                :localization_qualification,
                :model_qualification,
            ),
        ),
        observed_summaries,
    )
    @test all(entry -> entry.diagnostics !== nothing, default_result.history)
    @test all(
        entry ->
            entry.diagnostics.omega_directional === nothing ||
            abs(sum(entry.diagnostics.omega_directional) - entry.spread_total) <= 1.0e-10,
        default_result.history,
    )
end
