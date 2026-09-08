using HDF5
using LinearAlgebra
using Test

const EXPORT_WANNIERIZATION = WannierNLQG.Wannierization
const EXPORT_SYMMETRIZATION = WannierNLQG.Symmetrization
const EXPORT_IO = WannierNLQG.IO

function diagnostic_export_fixture(; mmn_override = nothing)
    operation = WannierNLQG.SymmetryFoundation.SymmetryOperation(
        Matrix{Int}(I, 3, 3),
        zeros(3),
        Matrix{Float64}(I, 3, 3),
    )
    energies = [-1.0 -1.0; 1.0 1.0]
    representation = WannierNLQG.SymmetryFoundation.BandRepresentation(
        "1.0",
        :synthetic,
        false,
        Matrix{Float64}(I, 3, 3),
        2.0pi .* Matrix{Float64}(I, 3, 3),
        (2, 1, 1),
        [0.0 0.0 0.0; 0.5 0.0 0.0],
        energies,
        [operation],
        reshape([1, 2], 1, 2),
        zeros(Int, 3, 1, 2),
        reshape(repeat(Matrix{ComplexF64}(I, 2, 2), 1, 1, 2), 2, 2, 1, 2),
        [1 1; 2 2],
        [1, 2],
        [1, 2],
        [1, 1];
        input_sha256 = Dict("fixture" => repeat("b", 64)),
    )
    block = WannierNLQG.WannierProjection.WannierProjectionBlock(
        "X",
        "s",
        zeros(3, 1),
        reshape([1], 1, 1),
        reshape(Matrix{Float64}(I, 3, 3), 3, 3, 1),
        false,
    )
    basis = WannierNLQG.WannierProjection.WannierProjectionBasis([block], 1, false)
    eig = EXPORT_IO.WannierEIG(2, 2, copy(energies))
    mmn_data = zeros(ComplexF64, 2, 2, 6, 2)
    for kpoint in 1:2, neighbor in 1:6
        mmn_data[:, :, neighbor, kpoint] .= Matrix{ComplexF64}(I, 2, 2)
    end
    neighbors = [2 1; 2 1; 1 2; 1 2; 1 2; 1 2]
    shifts = zeros(Int, 3, 6, 2)
    shifts[1, 2, 1] = -1
    shifts[1, 1, 2] = 1
    shifts[2, 3, :] .= 1
    shifts[2, 4, :] .= -1
    shifts[3, 5, :] .= 1
    shifts[3, 6, :] .= -1
    mmn =
        mmn_override === nothing ? EXPORT_IO.WannierMMN(2, 2, 6, mmn_data, neighbors, shifts) :
        mmn_override
    config = EXPORT_WANNIERIZATION.SymmetryAdaptedWannierizationConfig(
        input = EXPORT_WANNIERIZATION.WannierizationInputConfig(
            construction_policy = :strict,
            wannierization_mode = :ordinary,
            win_file = "synthetic.win",
            eig_file = "synthetic.eig",
            mmn_file = "synthetic.mmn",
            projection_basis = basis,
            num_wannier = 1,
            frozen_states = [(1, 1), (2, 1)],
        ),
        solver = EXPORT_WANNIERIZATION.WannierizationSolverConfig(
            algorithm_profile = :custom,
            initialization = :amn,
        ),
        checkpoint = EXPORT_WANNIERIZATION.WannierizationCheckpointConfig(),
        runtime = EXPORT_WANNIERIZATION.WannierizationRuntimeConfig(),
        output = EXPORT_WANNIERIZATION.WannierizationOutputConfig(
            write_wannier90_tb = true,
            tb_output_formats = (:packed_hdf5, :wannier90_tb),
        ),
    )
    frames = zeros(ComplexF64, 2, 1, 2)
    frames[1, 1, :] .= 1.0
    centers = zeros(Float64, 1, 3)
    spreads = [1.0]
    stencil = EXPORT_WANNIERIZATION._finite_difference_weights(representation, mmn)
    config_sha = EXPORT_WANNIERIZATION._restart_config_sha256(config)
    representation_sha = repeat("c", 64)
    basis_sha = EXPORT_WANNIERIZATION._projection_basis_sha256(basis)
    amn_sha = repeat("d", 64)
    restart_state = EXPORT_WANNIERIZATION.WannierizationRestartState(
        1,
        frames,
        nothing,
        centers,
        spreads,
        reshape([0.0, 0.0, 0.0, 1.0], 4, 1),
        trues(2, 2),
        0.0,
        config_sha,
        representation_sha,
        stencil,
        basis_sha,
        amn_sha,
        EXPORT_WANNIERIZATION.WannierizationOptimizerState(:fixed, 0.5, 1.0),
    )
    chk = EXPORT_IO.WannierCHK(
        2,
        1,
        2,
        representation.mp_grid,
        representation.kpoints_fractional,
        representation.real_lattice,
        representation.reciprocal_lattice,
        centers,
        frames,
    )
    iteration_diagnostics = EXPORT_WANNIERIZATION.WannierizationIterationDiagnostics(
        nothing,
        1.0,
        0.0,
        0.0,
        0.0,
        0.0,
        0.0,
        0.0,
        1.0,
        0.5,
        1.0,
        1,
        false,
        false,
        0,
        2.0e-4,
        0.25,
        3,
    )
    history =
        [EXPORT_WANNIERIZATION.WannierizationIteration(1, 1.0, 1.0e-4, 0.0, iteration_diagnostics)]
    diagnostic = EXPORT_WANNIERIZATION.WannierInitializationKPointDiagnostic(
        1,
        [1.0],
        [1.0],
        [1.0],
        Float64[],
        [1.0],
        1,
        1,
        1,
        0,
        0,
        0,
        1.0e-8,
        1.0e-8,
        1.0e-8,
        0.0,
        1.0,
        0.0,
        0.0,
        0.0,
        0.0,
    )
    report = EXPORT_WANNIERIZATION.WannierInitializationReport(
        :amn_full_bz_exact_frozen_embedding,
        "nosym_exact_frozen_rowspace_v2",
        :COMPLETED,
        [diagnostic],
    )
    summary = Dict(
        "requested_wannierization_mode" => "ordinary",
        "effective_wannierization_mode" => "ordinary",
        "representation_source" => "identity",
        "symmetry_constraints_applied" => "false",
        "effective_algorithm_profile" => "custom",
        "effective_symmetry_operation_count" => "1",
        "effective_antiunitary_operation_count" => "0",
        "requested_initializer" => "amn",
        "effective_initializer" => "amn_full_bz_exact_frozen_embedding",
        "initializer_algorithm_version" => "nosym_exact_frozen_rowspace_v2",
        "initialization_status" => "COMPLETED",
        "solver_status" => "MAX_ITERATIONS",
        "solver_convergence" => "MAX_ITERATIONS",
        "stopping_reason" => "MAX_ITERATIONS_REACHED",
        "last_attempted_iteration" => "1",
        "last_accepted_iteration" => "1",
        "last_persisted_iteration" => "1",
        "has_accepted_state" => "true",
        "legacy_terminal_semantics" => "false",
        "convergence_metric_name" => "center_spread_window_std_max",
        "convergence_metric" => "1.0e-4",
        "convergence_tolerance" => "1.0e-9",
        "hard_gate_isometry" => "0.0",
        "hard_gate_frozen" => "0.01",
        "hard_gate_covariance" => "0.0",
        "input_sha256" => repeat("e", 64),
        "authoritative_hamiltonian" => "native_dft",
        "authoritative_hamiltonian_sha256" => "LEGACY_NATIVE_DFT",
        "qualification_scope" => "full_parent",
        "target_authority" => "NOT_APPLICABLE",
        "parent_audit_policy" => "legacy_hard_gate",
        "disentanglement_outer_mask_sha256" => "NOT_SEALED",
        "disentanglement_frozen_mask_sha256" => "NOT_SEALED",
        "target_subspace_contract_sha256" => "NOT_RECORDED",
        "restart_config_sha256" => config_sha,
        "representation_sha256" => representation_sha,
        "projection_basis_sha256" => basis_sha,
        "amn_sha256" => amn_sha,
        "finite_difference_stencil_sha256" => stencil.digest,
        "spread_metric" => "full_3d",
        "optimizer_strategy" => "fixed",
        "optimizer_schedule" => "two_stage",
        "localization_steps" => "1",
        "projector_covariance_tolerance" => "NOT_APPLICABLE",
        "numerical_quality" => "INVALID_DIAGNOSTIC",
        "tb_export_status" => "NOT_EXPORTED",
    )
    result = EXPORT_WANNIERIZATION.WannierizationResult(
        EXPORT_WANNIERIZATION.MAX_ITERATIONS,
        frames,
        centers,
        spreads,
        history,
        EXPORT_WANNIERIZATION.WannierizationDiagnostic[],
        summary,
        chk,
        nothing,
        restart_state,
        EXPORT_WANNIERIZATION.WannierizationArtifacts(),
        report,
    )
    return (; representation, basis, eig, mmn, config, result)
end

@testset "checkpoint 2.28 initialization diagnostics, authority, and tamper binding" begin
    fixture = diagnostic_export_fixture()
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
            @test String(read(HDF5.attributes(handle)["schema_version"])) == "1.0"
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

        persisted = Base.invokelatest(solver._checkpoint_persisted_result, fixture.result)
        legacy_summary = Dict{String, String}(persisted.input_summary)
        legacy_summary["localization_gradient_contract"] = "mv_q_unwrapped_center_v1"
        legacy_persisted = Base.invokelatest(
            support.updated_wannierization_result,
            persisted;
            input_summary = legacy_summary,
        )
        legacy_digest =
            Base.invokelatest(solver._wannierization_checkpoint_sha256_v2_7, legacy_persisted)
        legacy27 = joinpath(directory, "legacy-2.7-diagnostic-z.wannierization.h5")
        cp(checkpoint, legacy27)
        HDF5.h5open(legacy27, "r+") do handle
            attributes = HDF5.attributes(handle)
            HDF5.delete_attribute(handle, "schema_version")
            attributes["schema_version"] = "2.7"
            HDF5.delete_attribute(handle, "localization_gradient_contract")
            attributes["localization_gradient_contract"] = "mv_q_unwrapped_center_v1"
            summary_attributes = HDF5.attributes(handle["input_summary"])
            HDF5.delete_attribute(handle["input_summary"], "localization_gradient_contract")
            summary_attributes["localization_gradient_contract"] = "mv_q_unwrapped_center_v1"
            HDF5.delete_attribute(handle, "checkpoint_sha256")
            attributes["checkpoint_sha256"] = legacy_digest
        end
        legacy_restored = EXPORT_WANNIERIZATION.read_wannierization_checkpoint_hdf5(legacy27)
        @test legacy_restored.input_summary["z_seal_class"] == "DIAGNOSTIC_NONCONVERGED"
        @test legacy_restored.input_summary["qualified_z_seal"] == "false"
        @test any(
            diagnostic -> diagnostic.code == :LEGACY_DIAGNOSTIC_Z_SEAL_NOT_PROMOTED,
            legacy_restored.diagnostics,
        )

        legacy27_joint = joinpath(directory, "legacy-2.7-joint.wannierization.h5")
        cp(legacy27, legacy27_joint)
        HDF5.h5open(legacy27_joint, "r+") do handle
            summary = handle["input_summary"]
            attributes = HDF5.attributes(summary)
            HDF5.delete_attribute(summary, "optimizer_schedule")
            attributes["optimizer_schedule"] = "joint"
        end
        legacy_joint = EXPORT_WANNIERIZATION.read_wannierization_checkpoint_hdf5(legacy27_joint)
        @test legacy_joint.input_summary["optimizer_history_compatibility"] ==
              "LEGACY_JOINT_UPDATE_CONTRACT_RESET"
        @test isempty(legacy_joint.restart_state.optimizer_state.anderson_z_history)
        @test isempty(legacy_joint.restart_state.optimizer_state.previous_u_gradient)
        @test legacy_joint.restart_state.optimizer_state.z_stability_count == 0
        @test legacy_joint.restart_state.optimizer_state.u_stability_count == 0

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

        # A genuine 2.1 payload has no typed initialization group in its
        # scientific contract and maps the new axes to explicit unknown values.
        legacy = joinpath(directory, "legacy-2.1.wannierization.h5")
        cp(checkpoint, legacy)
        legacy_result = EXPORT_WANNIERIZATION.WannierizationResult(
            fixture.result.status,
            fixture.result.v_matrix,
            fixture.result.wannier_centers_cartesian,
            fixture.result.spreads_angstrom2,
            fixture.result.history,
            fixture.result.diagnostics,
            filter(
                pair ->
                    first(pair) ∉ (
                        "initialization_status",
                        "initializer_algorithm_version",
                        "solver_convergence",
                        "numerical_quality",
                        "tb_export_status",
                    ),
                fixture.result.input_summary,
            ),
            fixture.result.wannier_chk,
            fixture.result.checkpoint_file,
            fixture.result.restart_state,
            fixture.result.artifacts,
        )
        legacy_digest =
            Base.invokelatest(solver._wannierization_checkpoint_sha256_v2_1, legacy_result)
        HDF5.h5open(legacy, "r+") do handle
            HDF5.delete_attribute(handle, "schema_version")
            HDF5.attributes(handle)["schema_version"] = "2.1"
            HDF5.delete_attribute(handle, "checkpoint_sha256")
            HDF5.attributes(handle)["checkpoint_sha256"] = legacy_digest
            summary = handle["input_summary"]
            legacy_integers = read(handle["history/iteration_diagnostic_integers"])
            legacy_integers[3, :] .= 1
            handle["history/iteration_diagnostic_integers"][:, :] = legacy_integers
            for key in (
                "initialization_status",
                "initializer_algorithm_version",
                "solver_convergence",
                "numerical_quality",
                "tb_export_status",
            )
                haskey(HDF5.attributes(summary), key) && HDF5.delete_attribute(summary, key)
            end
        end
        legacy_restored = EXPORT_WANNIERIZATION.read_wannierization_checkpoint_hdf5(legacy)
        @test legacy_restored.initialization_report === nothing
        @test legacy_restored.input_summary["initialization_status"] == "UNKNOWN"
        @test legacy_restored.input_summary["initializer_algorithm_version"] == "NOT_RECORDED"
    end
end

@testset "failed TB rejection and converged state classification" begin
    fixture = diagnostic_export_fixture()
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
    @test quality == "INVALID_DIAGNOSTIC"
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
    @test scaled_quality == "WARNING"
    @test scaled_before > 1.0e-8
    @test scaled_after <= 1.0e-8
    @test scaled_repaired

    symmetry_config = EXPORT_WANNIERIZATION._replace_wannierization_config(
        fixture.config;
        input = (
            wannierization_mode = :symmetry_adapted,
            band_representation = fixture.representation,
        ),
    )
    @test_throws ArgumentError Base.invokelatest(
        extension._prepare_wannierization_tb_state,
        scaled_result,
        symmetry_config,
    )

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
        @test export_error isa ArgumentError
        @test occursin("FROZEN_EMBEDDING_FAILED", sprint(showerror, export_error))
        @test !isfile(paths.packed)
        @test !isfile(paths.wannier90)
    end
end

@testset "structurally qualified MAX and line-search diagnostic TB export" begin
    fixture = diagnostic_export_fixture()
    extension = first(EXPORT_WANNIERIZATION._load_wannierization_extension!()).OperatorExport
    eligible_summary = merge(
        fixture.result.input_summary,
        Dict(
            "hard_gate_frozen" => "0.0",
            "optimizer_schedule" => "two_stage",
            "solver_convergence" => "MAX_ITERATIONS",
            "diagnostic_classification" => "MAX_ITERATIONS_DIAGNOSTIC",
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
    max_gate = Base.invokelatest(
        extension._diagnostic_nonconverged_tb_export_gate,
        max_result,
        fixture.config,
    )
    @test max_gate.allowed
    @test max_gate.classification == "MAX_ITERATIONS_DIAGNOSTIC"
    @test max_gate.minimum_rank == max_gate.required_rank == 1

    line_summary = merge(
        eligible_summary,
        Dict(
            "solver_convergence" => "LINE_SEARCH_EXHAUSTED",
            "stopping_reason" => "SPREAD_GRADIENT_LINE_SEARCH_FAILED",
            "diagnostic_classification" => "LINE_SEARCH_FAILED_DIAGNOSTIC",
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
    line_gate = Base.invokelatest(
        extension._diagnostic_nonconverged_tb_export_gate,
        line_result,
        fixture.config,
    )
    @test line_gate.allowed
    @test line_gate.classification == "LINE_SEARCH_FAILED_DIAGNOSTIC"
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
        @test metadata["diagnostic_classification"] == "LINE_SEARCH_FAILED_DIAGNOSTIC"
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
                "diagnostic_classification" => "STRUCTURAL_FAILURE_UNAVAILABLE",
                "diagnostic_export_gate_reason" =>
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
        @test retry_view.input_summary["diagnostic_classification"] == "MAX_ITERATIONS_DIAGNOSTIC"
        @test Base.invokelatest(
            extension._diagnostic_nonconverged_tb_export_gate,
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
                "diagnostic_classification" => "STRUCTURAL_FAILURE_UNAVAILABLE",
                "diagnostic_export_gate_reason" => "TB_EXPORT_FAILED: $(pair_ws_message)",
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
        @test pair_ws_retry_view.input_summary["diagnostic_export_gate_reason"] ==
              "EXPORT_ONLY_PAIR_WIGNER_SEITZ_SPIN_TRANSFORM_RETRY"
        @test parse(
            Float64,
            pair_ws_retry_view.input_summary["export_retry_superseded_roundtrip_residual"],
        ) == 0.0008986654508570481
        @test Base.invokelatest(
            extension._diagnostic_nonconverged_tb_export_gate,
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

    frozen_failure = Base.invokelatest(
        extension._diagnostic_nonconverged_tb_export_gate,
        fixture.result,
        fixture.config,
    )
    @test !frozen_failure.allowed
    @test frozen_failure.classification == "STRUCTURAL_FAILURE_UNAVAILABLE"
    @test frozen_failure.reason == "FROZEN_EMBEDDING_FAILED"

    foreign_error = EXPORT_WANNIERIZATION.WannierizationResult(
        EXPORT_WANNIERIZATION.LOCALIZATION_FAILED,
        line_result.v_matrix,
        line_result.wannier_centers_cartesian,
        line_result.spreads_angstrom2,
        line_result.history,
        [
            EXPORT_WANNIERIZATION.WannierizationDiagnostic(
                :SOLVER_TRIAL_FROZEN_PROJECTOR_FAILED,
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
    foreign_gate = Base.invokelatest(
        extension._diagnostic_nonconverged_tb_export_gate,
        foreign_error,
        fixture.config,
    )
    @test !foreign_gate.allowed
    @test foreign_gate.reason == "NON_LINE_SEARCH_ERROR_DIAGNOSTIC_PRESENT"
end

@testset "scoped restart initializer mismatch" begin
    fixture = diagnostic_export_fixture()
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
