using EzXML
using HDF5
using JSON3
using LinearAlgebra
using Spglib
using Test
using WannierNLQG

const TARGET_PERSISTENCE_WANNIERIZATION = WannierNLQG.Wannierization
const TARGET_PERSISTENCE_SYMMETRIZATION = WannierNLQG.Symmetrization
const TARGET_PERSISTENCE_IO = WannierNLQG.IO
const TARGET_PERSISTENCE_CORE = WannierNLQG.Core
const TARGET_PERSISTENCE_EXTENSION =
    first(TARGET_PERSISTENCE_WANNIERIZATION._load_wannierization_extension!()).PAWMatrixElements

# Construct a complete public identity representation with the current target contract.
function target_persistence_representation(; authority::String = "native_dft")
    operation = WannierNLQG.SymmetryFoundation.SymmetryOperation(
        Matrix{Int}(I, 3, 3),
        zeros(3),
        Matrix{Float64}(I, 3, 3),
    )
    return WannierNLQG.SymmetryFoundation.BandRepresentation(
        "1.0",
        :synthetic,
        false,
        Matrix{Float64}(I, 3, 3),
        2.0pi .* Matrix{Float64}(I, 3, 3),
        (1, 1, 1),
        zeros(1, 3),
        reshape([-1.0], 1, 1),
        [operation],
        ones(Int, 1, 1),
        zeros(Int, 3, 1, 1),
        ones(ComplexF64, 1, 1, 1, 1),
        ones(Int, 1, 1),
        [1],
        [1],
        [1];
        conventions = Dict(
            "fourier" => "H(k)=sum_R exp(+2pi*i*k.R) H(R)",
            "authoritative_hamiltonian" => authority,
            "authoritative_hamiltonian_sha256" => repeat("1", 64),
            "qualification_scope" => "target_subspace",
            "target_authority" => "outer_window",
            "parent_audit_policy" => "audit_only",
            "target_subspace_contract_sha256" => repeat("c", 64),
            "target_leakage_semantics" =>
                TARGET_PERSISTENCE_EXTENSION.TARGET_LEAKAGE_WEIGHT_SEMANTICS,
            "target_leakage_formula_sha256" =>
                TARGET_PERSISTENCE_EXTENSION.TARGET_LEAKAGE_WEIGHT_FORMULA_SHA256,
            "target_leakage_threshold" => "5.0e-6",
            "auxiliary_parent_qualification" => "audit_only",
            "requested_wannierization_mode" => "symmetry_adapted",
            "effective_wannierization_mode" => "symmetry_adapted",
            "representation_source" => "provided",
            "symmetry_constraints_applied" => "false",
        ),
        input_sha256 = Dict("fixture" => repeat("0", 64)),
    )
end

# Provide the minimum auditable geometry contract for a one-orbital R=0 bundle.
function target_persistence_geometry()
    centers = zeros(1, 3)
    return Dict(
        "wannier_center_policy" => "symmetrize",
        "real_space_replica_policy" => "input",
        "production_eligible" => false,
        "minimum_distance_materialized" => false,
        "mp_grid" => [1, 1, 1],
        "wannier_center_tolerance" => 1.0e-8,
        "wigner_seitz_tolerance" => 1.0e-5,
        "wigner_seitz_search_size" => 3,
        "raw_wannier_centers_cartesian" => centers,
        "raw_wannier_centers_fractional" => centers,
        "final_wannier_centers_cartesian" => centers,
        "final_wannier_centers_fractional" => centers,
        "center_alignment_lattice_shifts" => zeros(Int, 1, 3),
        "replica_mapping_sha256" => repeat("0", 64),
    )
end

# Build a minimal one-k-point state to exercise the schema-2.28 checkpoint boundary.
function target_persistence_solver_fixture()
    representation = target_persistence_representation()
    block = WannierNLQG.WannierProjection.WannierProjectionBlock(
        "X",
        "s",
        zeros(3, 1),
        reshape([1], 1, 1),
        reshape(Matrix{Float64}(I, 3, 3), 3, 3, 1),
        false,
    )
    basis = WannierNLQG.WannierProjection.WannierProjectionBasis([block], 1, false)
    plan = WannierNLQG.SymmetryFoundation.WannierSymmetryPlan(
        representation.operations,
        ones(ComplexF64, 1, 1, 1),
        zeros(Int, 3, 1, 1),
    )
    eig = TARGET_PERSISTENCE_IO.WannierEIG(1, 1, reshape([-1.0], 1, 1))
    reciprocal_shifts = zeros(Int, 3, 6, 1)
    reciprocal_shifts[:, :, 1] .= [1 -1 0 0 0 0; 0 0 1 -1 0 0; 0 0 0 0 1 -1]
    mmn = TARGET_PERSISTENCE_IO.WannierMMN(
        1,
        1,
        6,
        ones(ComplexF64, 1, 1, 6, 1),
        ones(Int, 6, 1),
        reciprocal_shifts,
    )
    config = TARGET_PERSISTENCE_WANNIERIZATION.SymmetryAdaptedWannierizationConfig(
        input = TARGET_PERSISTENCE_WANNIERIZATION.WannierizationInputConfig(
            wannierization_mode = :symmetry_adapted,
            win_file = "synthetic.win",
            eig_file = "synthetic.eig",
            mmn_file = "synthetic.mmn",
            projection_basis = basis,
            band_representation = representation,
            num_wannier = 1,
            outer_min_ev = -2.0,
            outer_max_ev = 0.0,
            frozen_min_ev = -2.0,
            frozen_max_ev = 0.0,
        ),
        solver = TARGET_PERSISTENCE_WANNIERIZATION.WannierizationSolverConfig(
            initialization = :random,
            localize = false,
            algorithm_profile = :custom,
            max_iterations = 2,
            convergence_tolerance = 1.0e-10,
            convergence_window = 1,
            random_seed = 0x1234,
        ),
        checkpoint = TARGET_PERSISTENCE_WANNIERIZATION.WannierizationCheckpointConfig(),
        runtime = TARGET_PERSISTENCE_WANNIERIZATION.WannierizationRuntimeConfig(),
        output = TARGET_PERSISTENCE_WANNIERIZATION.WannierizationOutputConfig(),
    )
    return (; representation, plan, eig, mmn, config)
end

@testset "Target-subspace persistence schemas and tamper rejection" begin
    parent_extension = first(TARGET_PERSISTENCE_WANNIERIZATION._load_wannierization_extension!())
    solver = parent_extension.SolverCheckpoint
    support = parent_extension.WannierizationInternalSupport
    @test solver.WANNIERIZATION_CHECKPOINT_SCHEMA_VERSION == "1.0"
    @test WannierNLQG.SymmetryFoundation.band_representation_schema_version() == "1.0"
    @test TARGET_PERSISTENCE_IO.OPERATOR_BUNDLE_SCHEMA_VERSION == "1.0"
    @test TARGET_PERSISTENCE_WANNIERIZATION.TB_SYMMETRY_QUALIFICATION_SCHEMA_VERSION == "1.7"

    mktempdir() do directory
        representation = target_persistence_representation()
        representation_file = joinpath(directory, "target-representation.h5")
        WannierNLQG.SymmetryFoundation.write_band_representation_hdf5(
            representation_file,
            representation,
        )
        restored = WannierNLQG.SymmetryFoundation.read_band_representation_hdf5(representation_file)
        @test restored.schema_version == "1.0"
        @test restored.conventions["authoritative_hamiltonian"] == "native_dft"
        @test restored.conventions["qualification_scope"] == "target_subspace"
        @test restored.conventions["target_subspace_contract_sha256"] == repeat("c", 64)
        @test restored.conventions["target_leakage_semantics"] ==
              TARGET_PERSISTENCE_EXTENSION.TARGET_LEAKAGE_WEIGHT_SEMANTICS
        @test restored.conventions["target_leakage_formula_sha256"] ==
              TARGET_PERSISTENCE_EXTENSION.TARGET_LEAKAGE_WEIGHT_FORMULA_SHA256
        @test parse(Float64, restored.conventions["target_leakage_threshold"]) == 5.0e-6

        symmetrized_representation =
            target_persistence_representation(authority = "symmetrized_dft_hamiltonian")
        symmetrized_representation_file =
            joinpath(directory, "symmetrized-target-representation.h5")
        WannierNLQG.SymmetryFoundation.write_band_representation_hdf5(
            symmetrized_representation_file,
            symmetrized_representation,
        )
        restored_symmetrized = WannierNLQG.SymmetryFoundation.read_band_representation_hdf5(
            symmetrized_representation_file,
        )
        @test restored_symmetrized.conventions["authoritative_hamiltonian"] ==
              "symmetrized_dft_hamiltonian"
        @test restored_symmetrized.conventions["target_subspace_contract_sha256"] == repeat("c", 64)
        metadata = Base.invokelatest(
            WannierNLQG.SymmetryFoundation.read_band_representation_preparation_hdf5,
            representation_file,
            restored,
        )
        @test length(metadata.qualification_scope.outer_mask_sha256) == 64
        @test length(metadata.qualification_scope.frozen_mask_sha256) == 64

        tampered_representation = joinpath(directory, "target-representation-tampered.h5")
        cp(representation_file, tampered_representation)
        HDF5.h5open(tampered_representation, "r+") do handle
            scope = handle["qualification_scope"]
            HDF5.delete_attribute(scope, "outer_mask_sha256")
            HDF5.attributes(scope)["outer_mask_sha256"] = repeat("f", 64)
        end
        @test_throws ArgumentError WannierNLQG.SymmetryFoundation.read_band_representation_hdf5(
            tampered_representation,
        )

        legacy_weight_representation = joinpath(directory, "legacy-weight-target-representation.h5")
        cp(representation_file, legacy_weight_representation)
        HDF5.h5open(legacy_weight_representation, "r+") do handle
            HDF5.delete_attribute(handle, "schema_version")
            HDF5.attributes(handle)["schema_version"] = "1.16"
        end
        legacy_weight_representation_error = try
            WannierNLQG.SymmetryFoundation.read_band_representation_hdf5(legacy_weight_representation)
            nothing
        catch exception
            sprint(showerror, exception)
        end
        @test occursin(
            "unsupported band-representation schema",
            something(legacy_weight_representation_error, ""),
        )

        tampered_formula_representation =
            joinpath(directory, "target-representation-formula-tampered.h5")
        cp(representation_file, tampered_formula_representation)
        HDF5.h5open(tampered_formula_representation, "r+") do handle
            conventions = handle["conventions"]
            HDF5.delete_attribute(conventions, "target_leakage_formula_sha256")
            HDF5.attributes(conventions)["target_leakage_formula_sha256"] = repeat("d", 64)
        end
        @test_throws ArgumentError WannierNLQG.SymmetryFoundation.read_band_representation_hdf5(
            tampered_formula_representation,
        )

        legacy_representation = joinpath(directory, "legacy-authority-representation.h5")
        cp(representation_file, legacy_representation)
        HDF5.h5open(legacy_representation, "r+") do handle
            attributes = HDF5.attributes(handle["conventions"])
            HDF5.delete_attribute(handle["conventions"], "authoritative_hamiltonian")
            attributes["authoritative_hamiltonian"] = "symmetrized_target_subspace_candidate"
        end
        legacy_error = try
            WannierNLQG.SymmetryFoundation.read_band_representation_hdf5(legacy_representation)
            nothing
        catch exception
            sprint(showerror, exception)
        end
        @test occursin("UNSUPPORTED_LEGACY_AUTHORITY", something(legacy_error, ""))

        solver_fixture = target_persistence_solver_fixture()
        solver_result = TARGET_PERSISTENCE_WANNIERIZATION._solve_symmetry_adapted_wannierization(
            solver_fixture.config,
            solver_fixture.representation,
            solver_fixture.eig,
            solver_fixture.mmn,
            solver_fixture.plan,
        )
        checkpoint_summary = Dict{String, String}(solver_result.input_summary)
        checkpoint_summary["construction_policy"] = "diagnostic"
        push!(
            solver_result.diagnostics,
            TARGET_PERSISTENCE_WANNIERIZATION.WannierizationDiagnostic(
                :SYNTHETIC_QUALITY_GATE,
                :warning,
                "Retained original quality failure";
                context = Dict(
                    "gate_result" => "FAIL",
                    "action" => "CONTINUE_DIAGNOSTIC",
                    "stage" => "preparation",
                    "value" => "6.81e-8",
                    "threshold" => "1.0e-10",
                ),
            ),
        )
        checkpoint_summary["authoritative_hamiltonian"] = "native_dft"
        checkpoint_summary["authoritative_hamiltonian_sha256"] = repeat("1", 64)
        checkpoint_summary["qualification_scope"] = "target_subspace"
        checkpoint_summary["target_authority"] = "outer_window"
        checkpoint_summary["parent_audit_policy"] = "audit_only"
        checkpoint_summary["disentanglement_outer_mask_sha256"] = repeat("a", 64)
        checkpoint_summary["disentanglement_frozen_mask_sha256"] = repeat("b", 64)
        checkpoint_summary["target_subspace_contract_sha256"] = repeat("c", 64)
        checkpoint_result = TARGET_PERSISTENCE_WANNIERIZATION.WannierizationResult(
            solver_result.status,
            solver_result.v_matrix,
            solver_result.wannier_centers_cartesian,
            solver_result.spreads_angstrom2,
            solver_result.history,
            solver_result.diagnostics,
            checkpoint_summary,
            solver_result.wannier_chk,
            nothing,
            solver_result.restart_state,
            solver_result.artifacts,
        )
        checkpoint_file = joinpath(directory, "target-checkpoint.h5")
        TARGET_PERSISTENCE_WANNIERIZATION.write_wannierization_checkpoint_hdf5(
            checkpoint_file,
            checkpoint_result,
        )
        restored_checkpoint =
            TARGET_PERSISTENCE_WANNIERIZATION.read_wannierization_checkpoint_hdf5(checkpoint_file)
        @test restored_checkpoint.input_summary["checkpoint_schema_version"] == "1.0"
        @test restored_checkpoint.input_summary["construction_policy"] == "diagnostic"
        @test restored_checkpoint.input_summary["construction_policy_contract"] ==
              "diagnostic_construction_v1"
        @test restored_checkpoint.input_summary["manual_review_status"] == "REQUIRED"
        @test last(restored_checkpoint.diagnostics).context["gate_result"] == "FAIL"
        @test last(restored_checkpoint.diagnostics).context["action"] == "CONTINUE_DIAGNOSTIC"
        HDF5.h5open(checkpoint_file, "r") do handle
            @test !read(HDF5.attributes(handle)["production_eligible"])
        end
        for (label, key, value) in (
            ("policy", "construction_policy", "strict"),
            ("review", "manual_review_status", "APPROVED"),
        )
            tampered = joinpath(directory, "construction-$(label)-tampered.h5")
            cp(checkpoint_file, tampered)
            HDF5.h5open(tampered, "r+") do handle
                group = handle["input_summary"]
                HDF5.delete_attribute(group, key)
                HDF5.attributes(group)[key] = value
            end
            @test_throws ArgumentError TARGET_PERSISTENCE_WANNIERIZATION.read_wannierization_checkpoint_hdf5(
                tampered,
            )
        end
        stripped = joinpath(directory, "construction-contract-stripped.h5")
        cp(checkpoint_file, stripped)
        HDF5.h5open(stripped, "r+") do handle
            group = handle["input_summary"]
            for key in
                ("construction_policy_contract", "construction_policy", "manual_review_status")
                HDF5.delete_attribute(group, key)
            end
        end
        @test_throws ArgumentError TARGET_PERSISTENCE_WANNIERIZATION.read_wannierization_checkpoint_hdf5(
            stripped,
        )
        tampered = joinpath(directory, "construction-diagnostic-tampered.h5")
        cp(checkpoint_file, tampered)
        HDF5.h5open(tampered, "r+") do handle
            group = handle["diagnostics"]
            key = last(sort!(String.(collect(keys(group)))))
            HDF5.delete_attribute(group[key], "gate_result")
            HDF5.attributes(group[key])["gate_result"] = "PASS"
        end
        @test_throws ArgumentError TARGET_PERSISTENCE_WANNIERIZATION.read_wannierization_checkpoint_hdf5(
            tampered,
        )
        @test restored_checkpoint.input_summary["authoritative_hamiltonian"] == "native_dft"
        @test restored_checkpoint.input_summary["qualification_scope"] == "target_subspace"
        @test restored_checkpoint.input_summary["disentanglement_outer_mask_sha256"] ==
              repeat("a", 64)
        @test restored_checkpoint.input_summary["disentanglement_frozen_mask_sha256"] ==
              repeat("b", 64)
        @test restored_checkpoint.input_summary["target_subspace_contract_sha256"] ==
              repeat("c", 64)
        @test restored_checkpoint.input_summary["target_leakage_semantics"] ==
              TARGET_PERSISTENCE_EXTENSION.TARGET_LEAKAGE_WEIGHT_SEMANTICS
        @test restored_checkpoint.input_summary["target_leakage_formula_sha256"] ==
              TARGET_PERSISTENCE_EXTENSION.TARGET_LEAKAGE_WEIGHT_FORMULA_SHA256
        @test parse(Float64, restored_checkpoint.input_summary["target_leakage_threshold"]) ==
              5.0e-6

        symmetrized_checkpoint_summary = copy(checkpoint_summary)
        symmetrized_checkpoint_summary["authoritative_hamiltonian"] = "symmetrized_dft_hamiltonian"
        symmetrized_checkpoint_summary["auxiliary_parent_qualification"] = "audit_only"
        symmetrized_checkpoint_result = TARGET_PERSISTENCE_WANNIERIZATION.WannierizationResult(
            solver_result.status,
            solver_result.v_matrix,
            solver_result.wannier_centers_cartesian,
            solver_result.spreads_angstrom2,
            solver_result.history,
            solver_result.diagnostics,
            symmetrized_checkpoint_summary,
            solver_result.wannier_chk,
            nothing,
            solver_result.restart_state,
            solver_result.artifacts,
        )
        symmetrized_checkpoint_file = joinpath(directory, "symmetrized-target-checkpoint.h5")
        TARGET_PERSISTENCE_WANNIERIZATION.write_wannierization_checkpoint_hdf5(
            symmetrized_checkpoint_file,
            symmetrized_checkpoint_result,
        )
        restored_symmetrized_checkpoint =
            TARGET_PERSISTENCE_WANNIERIZATION.read_wannierization_checkpoint_hdf5(
                symmetrized_checkpoint_file,
            )
        @test restored_symmetrized_checkpoint.input_summary["authoritative_hamiltonian"] ==
              "symmetrized_dft_hamiltonian"
        @test restored_symmetrized_checkpoint.input_summary["target_authority"] == "outer_window"

        tampered_checkpoint = joinpath(directory, "target-checkpoint-tampered.h5")
        cp(checkpoint_file, tampered_checkpoint)
        HDF5.h5open(tampered_checkpoint, "r+") do handle
            HDF5.delete_attribute(handle, "target_subspace_contract_sha256")
            HDF5.attributes(handle)["target_subspace_contract_sha256"] = repeat("d", 64)
        end
        @test_throws ArgumentError TARGET_PERSISTENCE_WANNIERIZATION.read_wannierization_checkpoint_hdf5(
            tampered_checkpoint,
        )

        tampered_leakage_semantics = joinpath(directory, "target-checkpoint-semantics-tampered.h5")
        cp(checkpoint_file, tampered_leakage_semantics)
        HDF5.h5open(tampered_leakage_semantics, "r+") do handle
            HDF5.delete_attribute(handle, "target_leakage_semantics")
            HDF5.attributes(handle)["target_leakage_semantics"] = "legacy_amplitude"
        end
        @test_throws ArgumentError TARGET_PERSISTENCE_WANNIERIZATION.read_wannierization_checkpoint_hdf5(
            tampered_leakage_semantics,
        )

        legacy_weight_checkpoint = joinpath(directory, "legacy-weight-target-checkpoint.h5")
        cp(checkpoint_file, legacy_weight_checkpoint)
        HDF5.h5open(legacy_weight_checkpoint, "r+") do handle
            HDF5.delete_attribute(handle, "schema_version")
            HDF5.attributes(handle)["schema_version"] = "2.27"
        end
        legacy_weight_checkpoint_error = try
            TARGET_PERSISTENCE_WANNIERIZATION.read_wannierization_checkpoint_hdf5(
                legacy_weight_checkpoint,
            )
            nothing
        catch exception
            sprint(showerror, exception)
        end
        @test occursin(
            "UNSUPPORTED_LEGACY_TARGET_LEAKAGE_SEMANTICS",
            something(legacy_weight_checkpoint_error, ""),
        )

        legacy_checkpoint = joinpath(directory, "legacy-authority-checkpoint.h5")
        cp(checkpoint_file, legacy_checkpoint)
        HDF5.h5open(legacy_checkpoint, "r+") do handle
            input_group = handle["input_summary"]
            HDF5.delete_attribute(input_group, "authoritative_hamiltonian")
            HDF5.attributes(input_group)["authoritative_hamiltonian"] = "symmetrized_target_subspace_candidate"
        end
        legacy_checkpoint_error = try
            TARGET_PERSISTENCE_WANNIERIZATION.read_wannierization_checkpoint_hdf5(legacy_checkpoint)
            nothing
        catch exception
            sprint(showerror, exception)
        end
        @test occursin("UNSUPPORTED_LEGACY_AUTHORITY", something(legacy_checkpoint_error, ""))

        qualification = TARGET_PERSISTENCE_WANNIERIZATION.TBSymmetryQualification(
            "NOT_RUN",
            "SYNTHETIC_TARGET_PERSISTENCE",
            TARGET_PERSISTENCE_WANNIERIZATION.TBSymmetryMetric[];
            authoritative_hamiltonian = "native_dft",
            authoritative_hamiltonian_sha256 = repeat("1", 64),
        )
        qualification_file = joinpath(directory, "tb-qualification.h5")
        HDF5.h5open(qualification_file, "w") do handle
            Base.invokelatest(support.write_tb_symmetry_qualification_group, handle, qualification)
        end
        restored_qualification = HDF5.h5open(qualification_file, "r") do handle
            Base.invokelatest(support.read_tb_symmetry_qualification_group, handle)
        end
        @test restored_qualification.schema_version == "1.7"
        @test restored_qualification.payload_sha256 == qualification.payload_sha256

        legacy_qualification = joinpath(directory, "legacy-authority-tb-qualification.h5")
        cp(qualification_file, legacy_qualification)
        HDF5.h5open(legacy_qualification, "r+") do handle
            group = handle["tb_symmetry_qualification"]
            HDF5.delete_attribute(group, "authoritative_hamiltonian")
            HDF5.attributes(group)["authoritative_hamiltonian"] = "symmetrized_hamiltonian_candidate"
        end
        legacy_qualification_error = HDF5.h5open(legacy_qualification, "r") do handle
            try
                Base.invokelatest(support.read_tb_symmetry_qualification_group, handle)
                nothing
            catch exception
                sprint(showerror, exception)
            end
        end
        @test occursin("UNSUPPORTED_LEGACY_AUTHORITY", something(legacy_qualification_error, ""))

        r_vectors = zeros(Int, 3, 1)
        operators = Dict(
            TARGET_PERSISTENCE_CORE.REAL_SPACE_HAMILTONIAN =>
                TARGET_PERSISTENCE_CORE.RealSpaceOperator(
                    TARGET_PERSISTENCE_CORE.RealSpaceOperatorSymmetrySpec(
                        TARGET_PERSISTENCE_CORE.REAL_SPACE_HAMILTONIAN,
                        0,
                        1,
                        1,
                    ),
                    r_vectors,
                    zeros(ComplexF64, 1, 1, 1),
                ),
            TARGET_PERSISTENCE_CORE.REAL_SPACE_POSITION =>
                TARGET_PERSISTENCE_CORE.RealSpaceOperator(
                    TARGET_PERSISTENCE_CORE.RealSpaceOperatorSymmetrySpec(
                        TARGET_PERSISTENCE_CORE.REAL_SPACE_POSITION,
                        1,
                        -1,
                        1,
                    ),
                    r_vectors,
                    zeros(ComplexF64, 1, 1, 3, 1),
                ),
        )
        outer_digest = repeat("a", 64)
        frozen_digest = repeat("b", 64)
        target_eligibility = Dict(
            "authoritative_hamiltonian" => "native_dft",
            "authoritative_hamiltonian_sha256" => repeat("1", 64),
            "qualification_scope" => "target_subspace",
            "target_authority" => "outer_window",
            "parent_audit_policy" => "audit_only",
            "disentanglement_outer_mask_sha256" => outer_digest,
            "disentanglement_frozen_mask_sha256" => frozen_digest,
            "target_subspace_contract_sha256" => repeat("c", 64),
            "target_leakage_semantics" =>
                TARGET_PERSISTENCE_EXTENSION.TARGET_LEAKAGE_WEIGHT_SEMANTICS,
            "target_leakage_formula_sha256" =>
                TARGET_PERSISTENCE_EXTENSION.TARGET_LEAKAGE_WEIGHT_FORMULA_SHA256,
            "target_leakage_threshold" => "5.0e-6",
            "global_production_eligible" => false,
        )
        bundle_file = joinpath(directory, "target-operators.h5")
        TARGET_PERSISTENCE_IO.write_real_space_operator_bundle(
            bundle_file,
            Matrix{Float64}(I, 3, 3),
            [1],
            operators;
            profile = :hamiltonian_position,
            geometry = target_persistence_geometry(),
            eligibility = target_eligibility,
        )
        manifest = TARGET_PERSISTENCE_IO.read_real_space_operator_bundle_manifest(bundle_file)
        @test manifest.schema_version == "1.0"
        @test manifest.parent_audit_policy == "audit_only"
        @test manifest.target_authority == "outer_window"
        @test manifest.outer_mask_sha256 == outer_digest
        @test manifest.frozen_mask_sha256 == frozen_digest

        symmetrized_bundle_file = joinpath(directory, "symmetrized-target-operators.h5")
        symmetrized_eligibility = merge(
            target_eligibility,
            Dict(
                "authoritative_hamiltonian" => "symmetrized_dft_hamiltonian",
                "energy_shift_qualification" => "audit_only",
                "residual_gate_phase" => "post_symmetrization",
                "native_difference_qualification" => "audit_only",
                "target_anchor" => "completed_symmetrized_target",
                "auxiliary_parent_qualification" => "audit_only",
            ),
        )
        TARGET_PERSISTENCE_IO.write_real_space_operator_bundle(
            symmetrized_bundle_file,
            Matrix{Float64}(I, 3, 3),
            [1],
            operators;
            profile = :hamiltonian_position,
            geometry = target_persistence_geometry(),
            eligibility = symmetrized_eligibility,
        )
        symmetrized_manifest =
            TARGET_PERSISTENCE_IO.read_real_space_operator_bundle_manifest(symmetrized_bundle_file)
        @test symmetrized_manifest.authoritative_hamiltonian == "symmetrized_dft_hamiltonian"
        @test symmetrized_manifest.target_authority == "outer_window"
        @test symmetrized_manifest.target_subspace_contract_sha256 == repeat("c", 64)

        tampered_bundle = joinpath(directory, "target-operators-tampered.h5")
        cp(bundle_file, tampered_bundle)
        HDF5.h5open(tampered_bundle, "r+") do handle
            HDF5.delete_attribute(handle, "outer_mask_sha256")
            HDF5.attributes(handle)["outer_mask_sha256"] = repeat("d", 64)
        end
        @test_throws ArgumentError TARGET_PERSISTENCE_IO.read_real_space_operator_bundle_manifest(
            tampered_bundle,
        )

        legacy_bundle = joinpath(directory, "legacy-authority-operators.h5")
        cp(bundle_file, legacy_bundle)
        HDF5.h5open(legacy_bundle, "r+") do handle
            HDF5.delete_attribute(handle, "authoritative_hamiltonian")
            HDF5.attributes(handle)["authoritative_hamiltonian"] = "symmetrized_hamiltonian_candidate"
        end
        legacy_bundle_error = try
            TARGET_PERSISTENCE_IO.read_real_space_operator_bundle_manifest(legacy_bundle)
            nothing
        catch exception
            sprint(showerror, exception)
        end
        @test occursin("UNSUPPORTED_LEGACY_AUTHORITY", something(legacy_bundle_error, ""))
    end
end
