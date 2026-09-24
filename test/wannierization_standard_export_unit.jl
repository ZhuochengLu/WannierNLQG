isdefined(@__MODULE__, :standard_export_fixture) ||
    include(joinpath(@__DIR__, "WannierStandardExportTestSupport.jl"))

@testset "checkpoint 1.1 initialization diagnostics, authority, and tamper binding" begin
    fixture = standard_export_fixture()
    parent_extension = first(EXPORT_WANNIERIZATION._load_wannierization_extension!())
    support = parent_extension.WannierizationInternalSupport
    solver = parent_extension.SolverCheckpoint
    mktempdir() do directory
        checkpoint = joinpath(directory, "diagnostic.wannierization.h5")
        EXPORT_WANNIERIZATION.write_wannierization_checkpoint_hdf5(checkpoint, fixture.result)
        restored = EXPORT_WANNIERIZATION.read_wannierization_checkpoint_hdf5(checkpoint)
        @test restored.initialization_report !== nothing
        @test restored.initialization_report.algorithm_version == "nosym_exact_frozen_rowspace_v2"
        @test only(restored.initialization_report.kpoints).alignment_condition == 1.0
        @test only(restored.history).diagnostics.projected_gradient_rms == 2.0e-4
        @test only(restored.history).diagnostics.accepted_u_step_scale == 0.25
        @test only(restored.history).diagnostics.localization_backtracking_steps == 3
        HDF5.h5open(checkpoint, "r") do handle
            @test String(read(HDF5.attributes(handle)["schema_version"])) == "1.2"
            @test String(read(HDF5.attributes(handle)["wavefunction_gauge_backend"])) ==
                  "native_eigenstate"
            @test String(read(HDF5.attributes(handle)["wavefunction_gauge_hdf5_sha256"])) ==
                  "NOT_APPLICABLE"
            @test String(read(HDF5.attributes(handle)["authoritative_hamiltonian"])) == "native_dft"
            @test !Bool(read(HDF5.attributes(handle)["global_production_eligible"]))
            @test String(read(HDF5.attributes(handle)["joint_update_contract"])) ==
                  "type_iv_block_gauss_seidel_v1"
            @test haskey(handle, "initialization/singular_values")
        end

        symmetrized_summary = Dict{String, String}(fixture.result.input_summary)
        symmetrized_summary["authoritative_hamiltonian"] = "symmetrized_dft_hamiltonian"
        symmetrized_summary["authoritative_hamiltonian_sha256"] = repeat("a", 64)
        symmetrized_summary["native_fidelity_status"] = "NATIVE_DFT_FIDELITY_HOLD"
        symmetrized_summary["symmetrized_hamiltonian_status"] = "SYMMETRIZED_DFT_HAMILTONIAN_PASS"
        symmetrized_summary["scoped_production_eligible"] = "true"
        symmetrized_summary["global_production_eligible"] = "false"
        symmetrized_summary["energy_shift_qualification"] = "audit_only"
        symmetrized_summary["maximum_energy_shift_audit_reference_ev"] = "5.0e-6"
        symmetrized_summary["rms_energy_shift_audit_reference_ev"] = "1.0e-6"
        symmetrized_summary["target_energy_shift_audit_status"] = "WITHIN_AUDIT_REFERENCE"
        symmetrized_summary["symmetrized_parent_energy_shift_audit_status"] = "WITHIN_AUDIT_REFERENCE"
        symmetrized_summary["residual_gate_phase"] = "post_symmetrization"
        symmetrized_summary["raw_preflight_diagnostic_status"] = "RAW_PREFLIGHT_DIAGNOSTIC_EXCEEDED"
        symmetrized_summary["native_difference_qualification"] = "audit_only"
        symmetrized_summary["native_difference_audit_status"] = "AUDIT_REFERENCE_EXCEEDED"
        symmetrized_summary["qualification_scope"] = "target_subspace"
        symmetrized_summary["target_authority"] = "outer_window"
        symmetrized_summary["parent_audit_policy"] = "audit_only"
        symmetrized_summary["disentanglement_outer_mask_sha256"] = repeat("1", 64)
        symmetrized_summary["disentanglement_frozen_mask_sha256"] = repeat("2", 64)
        symmetrized_summary["target_subspace_contract_sha256"] = repeat("3", 64)
        symmetrized_summary["target_leakage_semantics"] =
            EXPORT_WANNIERIZATION.TB_TARGET_LEAKAGE_WEIGHT_SEMANTICS
        symmetrized_summary["target_leakage_formula_sha256"] =
            EXPORT_WANNIERIZATION.TB_TARGET_LEAKAGE_WEIGHT_FORMULA_SHA256
        symmetrized_summary["target_leakage_threshold"] = "5.0e-6"
        symmetrized_summary["target_anchor"] = "completed_symmetrized_target"
        symmetrized_summary["target_complement_completion"] = "frozen_target_complement"
        symmetrized_summary["target_complement_max_element_ev"] = "5.0e-6"
        symmetrized_summary["auxiliary_parent_qualification"] = "audit_only"
        symmetrized_summary["symmetrized_target_subspace_status"] = "SYMMETRIZED_DFT_HAMILTONIAN_PASS"
        symmetrized_summary["auxiliary_parent_audit_status"] = "AUXILIARY_PARENT_AUDIT_EXCEEDED"
        symmetrized_summary["target_scope_production_eligible"] = "true"
        symmetrized_result = Base.invokelatest(
            support.updated_wannierization_result,
            fixture.result;
            input_summary = symmetrized_summary,
        )
        symmetrized_checkpoint = joinpath(directory, "symmetrized-hamiltonian.wannierization.h5")
        EXPORT_WANNIERIZATION.write_wannierization_checkpoint_hdf5(
            symmetrized_checkpoint,
            symmetrized_result,
        )
        symmetrized_restored =
            EXPORT_WANNIERIZATION.read_wannierization_checkpoint_hdf5(symmetrized_checkpoint)
        @test symmetrized_restored.input_summary["authoritative_hamiltonian"] ==
              "symmetrized_dft_hamiltonian"
        @test symmetrized_restored.input_summary["native_fidelity_status"] ==
              "NATIVE_DFT_FIDELITY_HOLD"
        @test symmetrized_restored.input_summary["global_production_eligible"] == "false"
        @test symmetrized_restored.input_summary["native_difference_qualification"] == "audit_only"
        @test symmetrized_restored.input_summary["qualification_scope"] == "target_subspace"
        @test symmetrized_restored.input_summary["target_anchor"] == "completed_symmetrized_target"
        @test symmetrized_restored.input_summary["auxiliary_parent_qualification"] == "audit_only"
        @test symmetrized_restored.input_summary["target_scope_production_eligible"] == "true"
        @test symmetrized_restored.input_summary["target_leakage_semantics"] ==
              EXPORT_WANNIERIZATION.TB_TARGET_LEAKAGE_WEIGHT_SEMANTICS
        @test symmetrized_restored.input_summary["target_leakage_threshold"] == "5.0e-6"
        target_tampered = joinpath(directory, "symmetrized-target-tampered.wannierization.h5")
        cp(symmetrized_checkpoint, target_tampered)
        HDF5.h5open(target_tampered, "r+") do handle
            HDF5.delete_attribute(handle, "qualification_scope")
            HDF5.attributes(handle)["qualification_scope"] = "full_parent"
        end
        @test_throws ArgumentError EXPORT_WANNIERIZATION.read_wannierization_checkpoint_hdf5(
            target_tampered,
        )
        symmetrized_tampered =
            joinpath(directory, "symmetrized-hamiltonian-tampered.wannierization.h5")
        cp(symmetrized_checkpoint, symmetrized_tampered)
        HDF5.h5open(symmetrized_tampered, "r+") do handle
            HDF5.delete_attribute(handle, "authoritative_hamiltonian")
            HDF5.attributes(handle)["authoritative_hamiltonian"] = "native_dft"
        end
        @test_throws ArgumentError EXPORT_WANNIERIZATION.read_wannierization_checkpoint_hdf5(
            symmetrized_tampered,
        )

        tampered = joinpath(directory, "tampered.wannierization.h5")
        cp(checkpoint, tampered)
        HDF5.h5open(tampered, "r+") do handle
            values = read(handle["initialization/residuals"])
            values[1, 1] = 2.0
            handle["initialization/residuals"][:, :] = values
        end
        @test_throws ArgumentError EXPORT_WANNIERIZATION.read_wannierization_checkpoint_hdf5(
            tampered,
        )
    end
end

@testset "failed TB rejection and converged state classification" begin
    fixture = standard_export_fixture()
    extension = first(EXPORT_WANNIERIZATION._load_wannierization_extension!()).OperatorExport
    line_search_summary = Dict{String, String}()
    Base.invokelatest(
        EXPORT_WANNIERIZATION._record_terminal_state!,
        line_search_summary,
        EXPORT_WANNIERIZATION.SINGULAR_LOCALIZATION,
        [
            EXPORT_WANNIERIZATION.WannierizationDiagnostic(
                :SPREAD_GRADIENT_LINE_SEARCH_FAILED,
                :error,
                "synthetic Armijo exhaustion",
            ),
        ],
        EXPORT_WANNIERIZATION.WannierizationIteration[],
        1,
        0,
    )
    @test line_search_summary["solver_convergence"] == "LINE_SEARCH_EXHAUSTED"

    prepared, quality, before, after, repaired = Base.invokelatest(
        extension._prepare_wannierization_tb_state,
        fixture.result,
        fixture.config,
    )
    @test prepared === fixture.result
    @test quality == "NUMERICAL_WARNING"
    @test before == 0.0
    @test after == 0.0
    @test !repaired

    scaled_values = copy(fixture.result.v_matrix)
    scaled_values .*= 1.0 + 1.0e-6
    source_chk = something(fixture.result.wannier_chk)
    scaled_chk = EXPORT_IO.WannierCHK(
        2,
        1,
        2,
        source_chk.mp_grid,
        source_chk.kpt_red,
        source_chk.real_lattice,
        source_chk.recip_lattice,
        fixture.result.wannier_centers_cartesian,
        scaled_values,
    )
    scaled_result = EXPORT_WANNIERIZATION.WannierizationResult(
        fixture.result.status,
        scaled_values,
        fixture.result.wannier_centers_cartesian,
        fixture.result.spreads_angstrom2,
        fixture.result.history,
        fixture.result.diagnostics,
        merge(fixture.result.input_summary, Dict("hard_gate_frozen" => "0.0")),
        scaled_chk,
        nothing,
        fixture.result.restart_state,
        fixture.result.artifacts,
        fixture.result.initialization_report,
    )
    _, scaled_quality, scaled_before, scaled_after, scaled_repaired =
        Base.invokelatest(extension._prepare_wannierization_tb_state, scaled_result, fixture.config)
    @test scaled_quality == "NUMERICAL_WARNING"
    @test scaled_before > 1.0e-8
    @test scaled_after == scaled_before
    @test !scaled_repaired

    symmetry_config = EXPORT_WANNIERIZATION._replace_wannierization_config(
        fixture.config;
        input = (
            wannierization_mode = :symmetry_adapted,
            band_representation = fixture.representation,
        ),
    )
    symmetry_prepared = Base.invokelatest(
        extension._prepare_wannierization_tb_state,
        scaled_result,
        symmetry_config,
    )
    @test first(symmetry_prepared) === scaled_result
    @test !Base.invokelatest(
        extension._accepted_state_tb_export_gate,
        scaled_result,
        fixture.config,
    ).allowed # checkpoint is deliberately unscaled

    mktempdir() do directory
        output_config = EXPORT_WANNIERIZATION._replace_wannierization_config(
            fixture.config;
            checkpoint = (checkpoint_hdf5 = joinpath(directory, "diagnostic.wannierization.h5"),),
            output = (write_wannier90_tb = true, tb_output_formats = (:packed_hdf5, :wannier90_tb)),
        )
        paths = Base.invokelatest(
            extension._wannierization_output_paths,
            output_config.checkpoint.checkpoint_hdf5,
        )
        export_error = try
            Base.invokelatest(
                extension._export_wannierization_tb,
                fixture.result,
                fixture.eig,
                fixture.mmn,
                output_config,
                paths,
                nothing,
            )
            nothing
        catch exception
            exception
        end
        @test export_error === nothing
        @test isfile(paths.packed)
        @test isfile(paths.wannier90)
        bundle = EXPORT_IO.read_real_space_operator_bundle(paths.packed)
        @test bundle.manifest.profile == :hamiltonian_position
        @test all(isfinite, bundle.operators[WannierNLQG.Core.REAL_SPACE_HAMILTONIAN].data)
    end
end

@testset "structurally qualified MAX and line-search standard TB export" begin
    fixture = standard_export_fixture()
    extension = first(EXPORT_WANNIERIZATION._load_wannierization_extension!()).OperatorExport
    eligible_summary = merge(
        fixture.result.input_summary,
        Dict(
            "hard_gate_frozen" => "0.0",
            "optimizer_schedule" => "two_stage",
            "solver_convergence" => "MAX_ITERATIONS",
            "model_availability" => "AVAILABLE_WITH_QUALITY_WARNINGS",
        ),
    )
    max_result = EXPORT_WANNIERIZATION.WannierizationResult(
        EXPORT_WANNIERIZATION.MAX_ITERATIONS,
        fixture.result.v_matrix,
        fixture.result.wannier_centers_cartesian,
        fixture.result.spreads_angstrom2,
        fixture.result.history,
        [
            EXPORT_WANNIERIZATION.WannierizationDiagnostic(
                :MAX_ITERATIONS_REACHED,
                :warning,
                "synthetic nonconvergence",
            ),
        ],
        eligible_summary,
        fixture.result.wannier_chk,
        nothing,
        fixture.result.restart_state,
        EXPORT_WANNIERIZATION.WannierizationArtifacts(),
        fixture.result.initialization_report,
    )
    max_gate =
        Base.invokelatest(extension._accepted_state_tb_export_gate, max_result, fixture.config)
    @test max_gate.allowed
    @test max_gate.classification == "AVAILABLE_WITH_QUALITY_WARNINGS"
    @test max_gate.minimum_rank == max_gate.required_rank == 1

    line_summary = merge(
        eligible_summary,
        Dict(
            "solver_convergence" => "LINE_SEARCH_EXHAUSTED",
            "stopping_reason" => "SPREAD_GRADIENT_LINE_SEARCH_FAILED",
            "model_availability" => "AVAILABLE_WITH_QUALITY_WARNINGS",
        ),
    )
    line_result = EXPORT_WANNIERIZATION.WannierizationResult(
        EXPORT_WANNIERIZATION.LOCALIZATION_FAILED,
        fixture.result.v_matrix,
        fixture.result.wannier_centers_cartesian,
        fixture.result.spreads_angstrom2,
        fixture.result.history,
        [
            EXPORT_WANNIERIZATION.WannierizationDiagnostic(
                :SPREAD_GRADIENT_LINE_SEARCH_FAILED,
                :error,
                "synthetic rejected trial; retained F0 is unchanged",
            ),
        ],
        line_summary,
        fixture.result.wannier_chk,
        nothing,
        fixture.result.restart_state,
        EXPORT_WANNIERIZATION.WannierizationArtifacts(),
        fixture.result.initialization_report,
    )
    line_gate =
        Base.invokelatest(extension._accepted_state_tb_export_gate, line_result, fixture.config)
    @test line_gate.allowed
    @test line_gate.classification == "AVAILABLE_WITH_QUALITY_WARNINGS"
    @test line_result.v_matrix == something(line_result.restart_state).frames

    mktempdir() do directory
        output_config = EXPORT_WANNIERIZATION._replace_wannierization_config(
            fixture.config;
            checkpoint = (checkpoint_hdf5 = joinpath(directory, "line-search.wannierization.h5"),),
            output = (write_wannier90_tb = true, tb_output_formats = (:packed_hdf5, :wannier90_tb)),
        )
        paths = Base.invokelatest(
            extension._wannierization_output_paths,
            output_config.checkpoint.checkpoint_hdf5,
        )
        packed, exchange, metadata = Base.invokelatest(
            extension._export_wannierization_tb,
            line_result,
            fixture.eig,
            fixture.mmn,
            output_config,
            paths,
            nothing,
        )
        @test isfile(packed)
        @test isfile(exchange)
        @test metadata["model_availability"] == "AVAILABLE_WITH_QUALITY_WARNINGS"
        manifest = EXPORT_IO.read_real_space_operator_bundle_manifest(packed)
        @test !something(manifest.production_eligible, true)

        symmetrized_summary = merge(
            line_result.input_summary,
            Dict(
                "authoritative_hamiltonian" => "symmetrized_dft_hamiltonian",
                "authoritative_hamiltonian_sha256" => repeat("a", 64),
                "energy_shift_qualification" => "audit_only",
                "residual_gate_phase" => "post_symmetrization",
                "raw_preflight_diagnostic_status" => "RAW_PREFLIGHT_DIAGNOSTIC_EXCEEDED",
                "native_difference_qualification" => "audit_only",
                "native_difference_audit_status" => "AUDIT_REFERENCE_EXCEEDED",
                "qualification_scope" => "target_subspace",
                "target_authority" => "outer_window",
                "parent_audit_policy" => "audit_only",
                "disentanglement_outer_mask_sha256" => repeat("1", 64),
                "disentanglement_frozen_mask_sha256" => repeat("2", 64),
                "target_subspace_contract_sha256" => repeat("3", 64),
                "target_leakage_semantics" =>
                    EXPORT_WANNIERIZATION.TB_TARGET_LEAKAGE_WEIGHT_SEMANTICS,
                "target_leakage_formula_sha256" =>
                    EXPORT_WANNIERIZATION.TB_TARGET_LEAKAGE_WEIGHT_FORMULA_SHA256,
                "target_leakage_threshold" => "5.0e-6",
                "target_anchor" => "completed_symmetrized_target",
                "target_complement_completion" => "frozen_target_orthogonal_complement",
                "target_complement_max_element_ev" => "1.0e-12",
                "auxiliary_parent_qualification" => "audit_only",
                "symmetrized_target_subspace_status" => "SYMMETRIZED_DFT_HAMILTONIAN_PASS",
                "auxiliary_parent_audit_status" => "AUDIT_REFERENCE_EXCEEDED",
                "target_scope_production_eligible" => "true",
            ),
        )
        symmetrized_result = EXPORT_WANNIERIZATION.WannierizationResult(
            line_result.status,
            line_result.v_matrix,
            line_result.wannier_centers_cartesian,
            line_result.spreads_angstrom2,
            line_result.history,
            line_result.diagnostics,
            symmetrized_summary,
            line_result.wannier_chk,
            line_result.checkpoint_file,
            line_result.restart_state,
            line_result.artifacts,
            line_result.initialization_report,
        )
        symmetrized_config = EXPORT_WANNIERIZATION._replace_wannierization_config(
            fixture.config;
            checkpoint = (
                checkpoint_hdf5 = joinpath(directory, "symmetrized-line-search.wannierization.h5"),
            ),
            output = (write_wannier90_tb = true, tb_output_formats = (:packed_hdf5, :wannier90_tb)),
        )
        symmetrized_paths = Base.invokelatest(
            extension._wannierization_output_paths,
            symmetrized_config.checkpoint.checkpoint_hdf5,
        )
        mismatch = try
            Base.invokelatest(
                extension._export_wannierization_tb,
                symmetrized_result,
                fixture.eig,
                fixture.mmn,
                symmetrized_config,
                symmetrized_paths,
                nothing,
            )
            nothing
        catch exception
            exception
        end
        @test mismatch isa ArgumentError
        @test occursin("HAMILTONIAN_REFERENCE_MISMATCH", sprint(showerror, mismatch))
        @test !isfile(symmetrized_paths.packed)

        unavailable = Base.invokelatest(
            extension._tb_symmetry_unavailable,
            "TB_EXPORT_FAILED",
            1.0e-10;
            input_summary = symmetrized_summary,
        )
        @test unavailable.schema_version == "1.7"
        @test unavailable.overall == "NOT_RUN"
        @test unavailable.authoritative_hamiltonian == "symmetrized_dft_hamiltonian"
        @test unavailable.qualification_scope == "target_subspace"
        @test unavailable.residual_gate_phase == "post_symmetrization"
        @test unavailable.native_difference_qualification == "audit_only"
        @test unavailable.target_leakage_semantics ==
              EXPORT_WANNIERIZATION.TB_TARGET_LEAKAGE_WEIGHT_SEMANTICS
        @test unavailable.target_leakage_threshold == 5.0e-6

        failed_retry_summary = merge(
            symmetrized_summary,
            Dict(
                "model_availability" => "UNAVAILABLE",
                "accepted_state_export_gate_reason" =>
                    "TB_EXPORT_FAILED: ArgumentError: HAMILTONIAN_REFERENCE_MISMATCH: " *
                    "schema-5.5 symmetrized bundle requires post-symmetrization residual gates",
                "tb_export_status" => "NOT_EXPORTED",
            ),
        )
        retry_failure = EXPORT_WANNIERIZATION.WannierizationDiagnostic(
            :TB_EXPORT_FAILED,
            :error,
            "ArgumentError: HAMILTONIAN_REFERENCE_MISMATCH: schema-5.5 " *
            "symmetrized bundle requires post-symmetrization residual gates",
        )
        failed_retry_result = EXPORT_WANNIERIZATION.WannierizationResult(
            EXPORT_WANNIERIZATION.MAX_ITERATIONS,
            max_result.v_matrix,
            max_result.wannier_centers_cartesian,
            max_result.spreads_angstrom2,
            max_result.history,
            [max_result.diagnostics..., retry_failure],
            failed_retry_summary,
            max_result.wannier_chk,
            max_result.checkpoint_file,
            max_result.restart_state,
            max_result.artifacts,
            max_result.initialization_report,
        )
        retry_view = Base.invokelatest(
            extension._schema_5_5_tb_export_retry_view,
            failed_retry_result,
            symmetrized_config,
        )
        @test retry_view.status == EXPORT_WANNIERIZATION.MAX_ITERATIONS
        @test all(diagnostic -> diagnostic.severity != :error, retry_view.diagnostics)
        @test retry_view.input_summary["model_availability"] == "AVAILABLE_WITH_QUALITY_WARNINGS"
        @test Base.invokelatest(
            extension._accepted_state_tb_export_gate,
            retry_view,
            symmetrized_config,
        ).allowed

        foreign_retry = EXPORT_WANNIERIZATION.WannierizationResult(
            failed_retry_result.status,
            failed_retry_result.v_matrix,
            failed_retry_result.wannier_centers_cartesian,
            failed_retry_result.spreads_angstrom2,
            failed_retry_result.history,
            [
                max_result.diagnostics...,
                EXPORT_WANNIERIZATION.WannierizationDiagnostic(
                    :TB_EXPORT_FAILED,
                    :error,
                    "unrelated export failure",
                ),
            ],
            failed_retry_result.input_summary,
            failed_retry_result.wannier_chk,
            failed_retry_result.checkpoint_file,
            failed_retry_result.restart_state,
            failed_retry_result.artifacts,
            failed_retry_result.initialization_report,
        )
        @test_throws ArgumentError Base.invokelatest(
            extension._schema_5_5_tb_export_retry_view,
            foreign_retry,
            symmetrized_config,
        )

        pair_ws_message = "SPN q->R->q round-trip error 0.0008986654508570481 exceeds atol=1.0e-8."
        pair_ws_summary = merge(
            symmetrized_summary,
            Dict(
                "model_availability" => "UNAVAILABLE",
                "accepted_state_export_gate_reason" => "TB_EXPORT_FAILED: $(pair_ws_message)",
                "tb_export_status" => "NOT_EXPORTED",
            ),
        )
        pair_ws_failure = EXPORT_WANNIERIZATION.WannierizationDiagnostic(
            :TB_EXPORT_FAILED,
            :error,
            pair_ws_message,
        )
        pair_ws_failed_result = EXPORT_WANNIERIZATION.WannierizationResult(
            EXPORT_WANNIERIZATION.MAX_ITERATIONS,
            max_result.v_matrix,
            max_result.wannier_centers_cartesian,
            max_result.spreads_angstrom2,
            max_result.history,
            [max_result.diagnostics..., pair_ws_failure],
            pair_ws_summary,
            max_result.wannier_chk,
            max_result.checkpoint_file,
            max_result.restart_state,
            max_result.artifacts,
            max_result.initialization_report,
        )
        pair_ws_retry_view = Base.invokelatest(
            extension._pair_wigner_seitz_spin_tb_export_retry_view,
            pair_ws_failed_result,
            symmetrized_config,
        )
        @test pair_ws_retry_view.status == EXPORT_WANNIERIZATION.MAX_ITERATIONS
        @test all(diagnostic -> diagnostic.severity != :error, pair_ws_retry_view.diagnostics)
        @test pair_ws_retry_view.input_summary["accepted_state_export_gate_reason"] ==
              "EXPORT_ONLY_PAIR_WIGNER_SEITZ_SPIN_TRANSFORM_RETRY"
        @test parse(
            Float64,
            pair_ws_retry_view.input_summary["export_retry_superseded_roundtrip_residual"],
        ) == 0.0008986654508570481
        @test Base.invokelatest(
            extension._accepted_state_tb_export_gate,
            pair_ws_retry_view,
            symmetrized_config,
        ).allowed
        tampered_pair_ws = EXPORT_WANNIERIZATION.WannierizationResult(
            pair_ws_failed_result.status,
            pair_ws_failed_result.v_matrix,
            pair_ws_failed_result.wannier_centers_cartesian,
            pair_ws_failed_result.spreads_angstrom2,
            pair_ws_failed_result.history,
            [
                max_result.diagnostics...,
                EXPORT_WANNIERIZATION.WannierizationDiagnostic(
                    :TB_EXPORT_FAILED,
                    :error,
                    "sIu q->R->q round-trip error 0.0008986654508570481 exceeds atol=1.0e-8.",
                ),
            ],
            pair_ws_failed_result.input_summary,
            pair_ws_failed_result.wannier_chk,
            pair_ws_failed_result.checkpoint_file,
            pair_ws_failed_result.restart_state,
            pair_ws_failed_result.artifacts,
            pair_ws_failed_result.initialization_report,
        )
        @test_throws ArgumentError Base.invokelatest(
            extension._pair_wigner_seitz_spin_tb_export_retry_view,
            tampered_pair_ws,
            symmetrized_config,
        )
    end

    frozen_failure =
        Base.invokelatest(extension._accepted_state_tb_export_gate, fixture.result, fixture.config)
    @test frozen_failure.allowed
    @test frozen_failure.classification in ("AVAILABLE", "AVAILABLE_WITH_QUALITY_WARNINGS")
    @test frozen_failure.reason == "STRUCTURAL_GATE_PASS"

    foreign_error = EXPORT_WANNIERIZATION.WannierizationResult(
        EXPORT_WANNIERIZATION.LOCALIZATION_FAILED,
        line_result.v_matrix,
        line_result.wannier_centers_cartesian,
        line_result.spreads_angstrom2,
        line_result.history,
        [
            EXPORT_WANNIERIZATION.WannierizationDiagnostic(
                :FROZEN_MASK_IDENTITY_MISMATCH,
                :error,
                "synthetic structural failure",
            ),
        ],
        line_result.input_summary,
        line_result.wannier_chk,
        nothing,
        line_result.restart_state,
        line_result.artifacts,
        line_result.initialization_report,
    )
    foreign_gate =
        Base.invokelatest(extension._accepted_state_tb_export_gate, foreign_error, fixture.config)
    @test !foreign_gate.allowed
    @test foreign_gate.reason == "HARD_ERROR_PRESENT"
end

@testset "scoped restart initializer mismatch" begin
    fixture = standard_export_fixture()
    extension = first(EXPORT_WANNIERIZATION._load_wannierization_extension!()).WorkflowOrchestration
    restart_config = EXPORT_WANNIERIZATION._replace_wannierization_config(
        fixture.config;
        input = (amn_file = nothing,),
        solver = (initialization = :restart,),
        checkpoint = (restart_hdf5 = "legacy.wannierization.h5",),
    )
    legacy_result = EXPORT_WANNIERIZATION.WannierizationResult(
        fixture.result.status,
        fixture.result.v_matrix,
        fixture.result.wannier_centers_cartesian,
        fixture.result.spreads_angstrom2,
        fixture.result.history,
        fixture.result.diagnostics,
        merge(
            fixture.result.input_summary,
            Dict("initializer_algorithm_version" => "NOT_RECORDED"),
        ),
        fixture.result.wannier_chk,
        nothing,
        fixture.result.restart_state,
        fixture.result.artifacts,
    )
    error = try
        Base.invokelatest(
            extension._validate_restart_initializer_algorithm,
            restart_config,
            [BitVector([true, false]), BitVector([true, false])],
            legacy_result,
        )
        nothing
    catch exception
        exception
    end
    @test error isa ArgumentError
    @test occursin("RESTART_INITIALIZER_ALGORITHM_MISMATCH", sprint(showerror, error))
    @test Base.invokelatest(
        extension._validate_restart_initializer_algorithm,
        restart_config,
        [falses(2), falses(2)],
        legacy_result,
    ) === nothing

    acceleration_names = fieldnames(typeof(restart_config.solver.acceleration))
    acceleration_values = NamedTuple{acceleration_names}(
        Tuple(getfield(restart_config.solver.acceleration, name) for name in acceleration_names),
    )
    reference_acceleration = EXPORT_WANNIERIZATION.WannierizationAccelerationConfig(;
        merge(
            acceleration_values,
            (
                disentanglement_algorithm = :smv_fletcher_reeves_two_stage,
                localization_algorithm = :smv_fletcher_reeves_two_stage,
            ),
        )...,
    )
    reference_config = EXPORT_WANNIERIZATION._replace_wannierization_config(
        fixture.config;
        input = (amn_file = nothing,),
        solver = (
            initialization = :restart,
            acceleration = reference_acceleration,
            initialization_backend = EXPORT_WANNIERIZATION.AMNExactFrozenInitialization(),
        ),
        checkpoint = (restart_hdf5 = "w90-reference.wannierization.h5",),
    )
    reference_result = EXPORT_WANNIERIZATION.WannierizationResult(
        fixture.result.status,
        fixture.result.v_matrix,
        fixture.result.wannier_centers_cartesian,
        fixture.result.spreads_angstrom2,
        fixture.result.history,
        fixture.result.diagnostics,
        merge(
            fixture.result.input_summary,
            Dict("initializer_algorithm_version" => "wannier90-4.0.1-dis_project-dis_proj_froz-v1"),
        ),
        fixture.result.wannier_chk,
        nothing,
        fixture.result.restart_state,
        fixture.result.artifacts,
    )
    @test Base.invokelatest(
        extension._validate_restart_initializer_algorithm,
        reference_config,
        [BitVector([true, false]), BitVector([true, false])],
        reference_result,
    ) === nothing
    @test_throws ArgumentError Base.invokelatest(
        extension._validate_restart_initializer_algorithm,
        restart_config,
        [BitVector([true, false]), BitVector([true, false])],
        reference_result,
    )
end

@testset "restart checkpoint identity is checked before native preparation" begin
    fixture = standard_export_fixture()
    parent = first(EXPORT_WANNIERIZATION._load_wannierization_extension!())
    workflow = parent.WorkflowOrchestration
    restart_config = EXPORT_WANNIERIZATION._replace_wannierization_config(
        fixture.config;
        solver = (initialization = :restart,),
        checkpoint = (restart_hdf5 = "accepted-checkpoint.h5",),
    )
    valid = parent.WannierizationInternalSupport.updated_wannierization_result(
        fixture.result;
        input_summary = merge(
            fixture.result.input_summary,
            Dict(
                "restart_eligible" => "true",
                "construction_policy" => String(fixture.config.input.construction_policy),
            ),
        ),
    )
    reads = Ref(0)
    reader = path -> begin
        @test path == "accepted-checkpoint.h5"
        reads[] += 1
        valid
    end
    @test workflow._read_workflow_restart(restart_config; reader) === valid
    @test reads[] == 1
    @test workflow._read_workflow_restart(
        fixture.config;
        reader = path -> error("fresh construction must not read restart"),
    ) === nothing
    wrong_policy = parent.WannierizationInternalSupport.updated_wannierization_result(
        valid;
        input_summary = merge(valid.input_summary, Dict("construction_policy" => "incompatible")),
    )
    @test_throws ArgumentError workflow._read_workflow_restart(
        restart_config;
        reader = path -> wrong_policy,
    )
    read_only = parent.WannierizationInternalSupport.updated_wannierization_result(
        valid;
        input_summary = merge(valid.input_summary, Dict("restart_eligible" => "false")),
    )
    @test_throws ArgumentError workflow._read_workflow_restart(
        restart_config;
        reader = path -> read_only,
    )
end

@testset "accepted completed QE matrices bypass the main resolver generator" begin
    fixture = standard_export_fixture()
    parent = first(EXPORT_WANNIERIZATION._load_wannierization_extension!())
    workflow = parent.WorkflowOrchestration
    mktempdir() do directory
        hashfile(path) = bytes2hex(open(SHA.sha256, path))
        eig = joinpath(directory, "source.eig")
        win = joinpath(directory, "source.win")
        nnkp = joinpath(directory, "source.nnkp")
        gauge = joinpath(directory, "accepted.gauge")
        representation = joinpath(directory, "representation.h5")
        EXPORT_IO.write_wannier_eig(eig, fixture.eig)
        write(win, "accepted WIN input fixture")
        write(nnkp, "accepted topology identity fixture")
        write(gauge, "accepted gauge identity fixture")
        mmn_file = joinpath(directory, "STANDARD_symmetry_completed_qe_paw.mmn")
        amn_file = joinpath(directory, "STANDARD_symmetry_completed_qe_paw.amn")
        provenance = joinpath(directory, "STANDARD_symmetry_completed_qe_paw.provenance.h5")
        EXPORT_IO.write_wannier_mmn(mmn_file, fixture.mmn)
        amn = zeros(ComplexF64, 2, 1, 2)
        amn[1, 1, :] .= 1
        EXPORT_IO.write_wannier_amn(amn_file, EXPORT_IO.WannierAMN(2, 2, 1, amn))
        hashes = Dict("EIG" => hashfile(eig), "WIN" => hashfile(win))
        HDF5.h5open(representation, "w") do handle
            attrs = HDF5.attributes(HDF5.create_group(handle, "input_sha256"))
            for (key, value) in hashes
                attrs[key] = value
            end
        end
        hashes["MMN"] = hashfile(mmn_file)
        input_digest = bytes2hex(
            SHA.sha256(
                join(
                    [string(key, Char(0), hashes[key]) for key in sort!(collect(keys(hashes)))],
                    Char(10),
                ),
            ),
        )
        HDF5.h5open(provenance, "w") do handle
            attrs = HDF5.attributes(handle)
            attrs["passed"] = true
            attrs["qualification_mode"] = "standard"
            attrs["gauge_hdf5_sha256"] = hashfile(gauge)
            attrs["nnkp_sha256"] = hashfile(nnkp)
        end
        configured = EXPORT_WANNIERIZATION.SymmetryCompletedQEPAWMatrices(
            nnkp,
            gauge;
            artifact_dir = directory,
        )
        config = EXPORT_WANNIERIZATION._replace_wannierization_config(
            fixture.config;
            input = (
                matrix_elements = configured,
                eig_file = eig,
                win_file = win,
                band_representation_hdf5 = representation,
                construction_policy = :standard,
            ),
            solver = (initialization = :restart,),
            checkpoint = (restart_hdf5 = joinpath(directory, "not-reread.h5"),),
        )
        summary = merge(
            fixture.result.input_summary,
            Dict(
                "projection_basis_sha256" =>
                    EXPORT_WANNIERIZATION._projection_basis_sha256(fixture.basis),
                "authoritative_hamiltonian_sha256" =>
                    parent.PAWMatrixElements.star_authoritative_hamiltonian_sha256(
                        config.input.authoritative_hamiltonian,
                    ),
                "input_sha256" => input_digest,
                "amn_sha256" => hashfile(amn_file),
                "matrix_element_gauge_sha256" => hashfile(gauge),
                "num_bands" => "2",
                "num_kpoints" => "2",
            ),
        )
        accepted = parent.WannierizationInternalSupport.updated_wannierization_result(
            fixture.result;
            input_summary = summary,
        )
        resolved = workflow._resolve_wannier_matrix_elements(
            config,
            fixture.basis;
            accepted_result = accepted,
            generator = (args...) -> error("MATRIX_REGENERATION_FORBIDDEN"),
        )
        @test resolved.mmn.data == fixture.mmn.data
        @test resolved.amn == amn
        @test resolved.raw_amn_file == amn_file
        @test resolved.gauge_sha256 == hashfile(gauge)
        @test resolved.gauge_provenance_file == provenance
        @test !isfile(config.checkpoint.restart_hdf5)
        for execution in (
            EXPORT_WANNIERIZATION.WavefunctionPreparationExecutionConfig(mode = :dense_reference),
            EXPORT_WANNIERIZATION.WavefunctionPreparationExecutionConfig(resume = false),
        )
            forced = EXPORT_WANNIERIZATION._replace_wannierization_config(
                config;
                input = (preparation_execution = execution,),
            )
            @test workflow._resolve_wannier_matrix_elements(
                forced,
                fixture.basis;
                accepted_result = accepted,
                generator = (args...) -> :explicit_recompute,
            ) === :explicit_recompute
        end

        write(amn_file, read(amn_file, String) * "\n")
        @test_throws ArgumentError workflow._resolve_wannier_matrix_elements(
            config,
            fixture.basis;
            accepted_result = accepted,
            generator = (args...) -> error("MATRIX_REGENERATION_FORBIDDEN"),
        )
    end
end

@testset "derived eligibility, primary failure reason, and wire 1.2 roundtrip" begin
    fixture = standard_export_fixture()
    parent = first(EXPORT_WANNIERIZATION._load_wannierization_extension!())
    workflow = parent.WorkflowOrchestration
    export_ops = parent.OperatorExport
    solver = parent.SolverCheckpoint

    rebuild(summary, status, diagnostics) = EXPORT_WANNIERIZATION.WannierizationResult(
        status,
        fixture.result.v_matrix,
        fixture.result.wannier_centers_cartesian,
        fixture.result.spreads_angstrom2,
        fixture.result.history,
        diagnostics,
        summary,
        fixture.result.wannier_chk,
        nothing,
        fixture.result.restart_state,
        EXPORT_WANNIERIZATION.WannierizationArtifacts(),
        fixture.result.initialization_report,
    )

    eligible_summary = merge(
        fixture.result.input_summary,
        Dict(
            "hard_gate_frozen" => "0.0",
            "optimizer_schedule" => "two_stage",
            "solver_convergence" => "MAX_ITERATIONS",
            "model_availability" => "AVAILABLE_WITH_QUALITY_WARNINGS",
        ),
    )
    max_result = rebuild(
        eligible_summary,
        EXPORT_WANNIERIZATION.MAX_ITERATIONS,
        [
            EXPORT_WANNIERIZATION.WannierizationDiagnostic(
                :MAX_ITERATIONS_REACHED,
                :warning,
                "synthetic nonconvergence",
            ),
        ],
    )

    # A: terminal status (MAX_ITERATIONS) no longer blocks export; the derived
    # typed block records execution/export eligible but production ineligible.
    eligibility =
        Base.invokelatest(workflow._wannierization_eligibility, max_result, fixture.config)
    @test eligibility.execution_eligible
    @test eligibility.export_eligible
    @test !eligibility.production_eligible
    @test eligibility.qualification_status == "DIAGNOSTIC_ONLY"
    @test eligibility.quality_review_recommended
    @test !eligibility.strictly_converged_z_seal
    @test eligibility.reasons == String[]
    @test eligibility.verified_contracts ==
          ["ACCEPTED_STATE_STRUCTURAL_GATE", "ACCEPTED_STATE_TB_EXPORT_GATE"]
    @test eligibility.unverified_contracts ==
          ["SCOPED_PRODUCTION_CONTRACT", "Z_STABILITY_CONVERGED"]
    @test eligibility.conflicting_contracts == String[]
    roundtripped = EXPORT_WANNIERIZATION.wannierization_eligibility_from_summary(
        EXPORT_WANNIERIZATION.wannierization_eligibility_summary(eligibility),
    )
    for field in fieldnames(EXPORT_WANNIERIZATION.WannierizationEligibility)
        @test getfield(roundtripped, field) == getfield(eligibility, field)
    end

    # The gate reports a missing schedule as SOLVER_NOT_REACHED, not an identity
    # mismatch; only a present-but-different schedule is a genuine mismatch.
    nosched_summary = filter(pair -> pair.first != "optimizer_schedule", eligible_summary)
    nosched = rebuild(
        nosched_summary,
        EXPORT_WANNIERIZATION.MAX_ITERATIONS,
        [
            EXPORT_WANNIERIZATION.WannierizationDiagnostic(
                :MAX_ITERATIONS_REACHED,
                :warning,
                "synthetic nonconvergence",
            ),
        ],
    )
    nosched_gate =
        Base.invokelatest(export_ops._accepted_state_tb_export_gate, nosched, fixture.config)
    @test !nosched_gate.allowed
    @test nosched_gate.reason == "SOLVER_NOT_REACHED"
    @test nosched_gate.classification == "UNAVAILABLE"
    @test Base.invokelatest(workflow._primary_terminal_failure_reason, nosched) === nothing

    different_schedule = rebuild(
        merge(eligible_summary, Dict("optimizer_schedule" => "joint")),
        EXPORT_WANNIERIZATION.MAX_ITERATIONS,
        [
            EXPORT_WANNIERIZATION.WannierizationDiagnostic(
                :MAX_ITERATIONS_REACHED,
                :warning,
                "synthetic nonconvergence",
            ),
        ],
    )
    different_gate = Base.invokelatest(
        export_ops._accepted_state_tb_export_gate,
        different_schedule,
        fixture.config,
    )
    @test !different_gate.allowed
    @test different_gate.reason == "SOLVER_SCHEDULE_IDENTITY_MISMATCH"

    # The primary terminal failure reason survives a secondary gate evaluation.
    io_result = rebuild(
        eligible_summary,
        EXPORT_WANNIERIZATION.IO_FAILURE,
        [EXPORT_WANNIERIZATION.WannierizationDiagnostic(:IO_FAILURE, :error, "boom")],
    )
    @test Base.invokelatest(workflow._primary_terminal_failure_reason, io_result) == "IO_FAILURE"
    invalid_result = rebuild(
        eligible_summary,
        EXPORT_WANNIERIZATION.INVALID_INPUT,
        [
            EXPORT_WANNIERIZATION.WannierizationDiagnostic(
                :EIG_DIMENSION_MISMATCH,
                :error,
                "bad dimensions",
            ),
        ],
    )
    @test Base.invokelatest(workflow._primary_terminal_failure_reason, invalid_result) ==
          "EIG_DIMENSION_MISMATCH"

    mktempdir() do directory
        checkpoint = joinpath(directory, "wire-1.2.wannierization.h5")
        persisted = Base.invokelatest(
            parent.WannierizationInternalSupport.updated_wannierization_result,
            max_result;
            input_summary = merge(
                max_result.input_summary,
                EXPORT_WANNIERIZATION.wannierization_eligibility_summary(eligibility),
            ),
        )
        EXPORT_WANNIERIZATION.write_wannierization_checkpoint_hdf5(checkpoint, persisted)
        restored = EXPORT_WANNIERIZATION.read_wannierization_checkpoint_hdf5(checkpoint)
        @test restored.input_summary["checkpoint_schema_version"] == "1.2"
        @test restored.input_summary["restart_eligible"] == "true"
        for key in EXPORT_WANNIERIZATION.WANNIERIZATION_ELIGIBILITY_SUMMARY_KEYS
            @test restored.input_summary[key] ==
                  EXPORT_WANNIERIZATION.wannierization_eligibility_summary(eligibility)[key]
        end
        HDF5.h5open(checkpoint, "r") do handle
            attributes = HDF5.attributes(handle)
            @test String(read(attributes["schema_version"])) == "1.2"
            @test !haskey(attributes, "qualified_z_seal")
            for key in EXPORT_WANNIERIZATION.WANNIERIZATION_ELIGIBILITY_SUMMARY_KEYS
                @test String(read(attributes[key])) == restored.input_summary[key]
            end
            @test String(read(attributes["checkpoint_sha256"])) ==
                  Base.invokelatest(solver._wannierization_checkpoint_sha256_v2_29, restored)
        end
    end
end

@testset "wire 1.1 checkpoints remain readable after the 1.2 wire upgrade" begin
    fixture_root = joinpath(@__DIR__, "fixtures", "schema_compatibility")
    legacy = joinpath(fixture_root, "checkpoint_1_1.h5")
    @test isfile(legacy)
    restored = EXPORT_WANNIERIZATION.read_wannierization_checkpoint_hdf5(legacy)
    @test restored.input_summary["checkpoint_schema_version"] == "1.1"
    @test restored.input_summary["restart_eligible"] == "true"
    @test restored.status == EXPORT_WANNIERIZATION.MAX_ITERATIONS
    # Wire 1.1 predates the typed block; the reader must not fabricate it.
    @test !haskey(restored.input_summary, "wannierization_eligibility_execution_eligible")
    HDF5.h5open(legacy, "r") do handle
        attributes = HDF5.attributes(handle)
        @test String(read(attributes["schema_version"])) == "1.1"
        @test haskey(attributes, "qualified_z_seal")
        @test !haskey(attributes, "wannierization_eligibility_execution_eligible")
    end
    # Relabeling the same numerical payload as 1.2 must fail the digest binding.
    mktempdir() do directory
        relabeled = joinpath(directory, "relabeled-1.2.wannierization.h5")
        cp(legacy, relabeled)
        HDF5.h5open(relabeled, "r+") do handle
            HDF5.delete_attribute(handle, "schema_version")
            HDF5.attributes(handle)["schema_version"] = "1.2"
        end
        @test_throws ArgumentError EXPORT_WANNIERIZATION.read_wannierization_checkpoint_hdf5(
            relabeled,
        )
    end
end
