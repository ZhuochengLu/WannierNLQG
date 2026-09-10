using HDF5
using JSON3
using LinearAlgebra
using Test

const TBQ_W = WannierNLQG.Wannierization
const TBQ_S = WannierNLQG.Symmetrization
const TBQ_IO = WannierNLQG.IO
const TBQ_C = WannierNLQG.Core

function tbq_geometry(lattice, position)
    centers = zeros(Float64, size(position.data, 1), 3)
    return Dict(
        "wannier_center_policy" => "symmetrize",
        "real_space_replica_policy" => "input",
        "production_eligible" => true,
        "minimum_distance_materialized" => false,
        "mp_grid" => [2, 1, 1],
        "wannier_center_tolerance" => 1.0e-8,
        "wigner_seitz_tolerance" => 1.0e-5,
        "wigner_seitz_search_size" => 3,
        "raw_wannier_centers_cartesian" => centers,
        "raw_wannier_centers_fractional" => centers * inv(lattice),
        "final_wannier_centers_cartesian" => centers,
        "final_wannier_centers_fractional" => centers * inv(lattice),
        "center_alignment_lattice_shifts" => zeros(Int, size(centers)),
        "replica_mapping_sha256" => repeat("0", 64),
    )
end

function tbq_fixture(
    directory;
    antiunitary = false,
    break_hopping = false,
    break_position = false,
    symmetrized = false,
    target_subspace = false,
    distinct_authority_digests = false,
)
    lattice = Matrix{Float64}(I, 3, 3)
    r_vectors = [-1 0 1; 0 0 0; 0 0 0]
    degeneracies = ones(Int, 3)
    hamiltonian_values = reshape(ComplexF64[0.2, 1.0, break_hopping ? 0.3 : 0.2], 1, 1, 3)
    position_values = zeros(ComplexF64, 1, 1, 3, 3)
    if break_position
        position_values[1, 1, 1, 1] = 0.1
        position_values[1, 1, 1, 3] = 0.1
    end
    hamiltonian = TBQ_C.RealSpaceOperator(
        TBQ_C.RealSpaceOperatorSymmetrySpec(TBQ_C.REAL_SPACE_HAMILTONIAN, 0, 1, 1),
        r_vectors,
        hamiltonian_values,
    )
    position = TBQ_C.RealSpaceOperator(
        TBQ_C.RealSpaceOperatorSymmetrySpec(TBQ_C.REAL_SPACE_POSITION, 1, -1, 1),
        r_vectors,
        position_values,
    )
    operation = WannierNLQG.SymmetryFoundation.SymmetryOperation(
        antiunitary ? Matrix{Int}(I, 3, 3) : -Matrix{Int}(I, 3, 3),
        zeros(3),
        antiunitary ? Matrix{Float64}(I, 3, 3) : -Matrix{Float64}(I, 3, 3),
        antiunitary,
    )
    identity_operation = WannierNLQG.SymmetryFoundation.SymmetryOperation(
        Matrix{Int}(I, 3, 3),
        zeros(3),
        Matrix{Float64}(I, 3, 3),
    )
    operations = [identity_operation, operation]
    plan = WannierNLQG.SymmetryFoundation.WannierSymmetryPlan(
        operations,
        ones(ComplexF64, 1, 1, 2),
        zeros(Int, 3, 1, 2),
    )
    symmetrized = symmetrized || target_subspace
    target_scope = target_subspace || symmetrized
    authority = target_scope ? "symmetrized_dft_hamiltonian" : "native_dft"
    authority_data_sha = target_scope ? repeat("a", 64) : "LEGACY_NATIVE_DFT"
    authority_contract_sha = distinct_authority_digests ? repeat("b", 64) : authority_data_sha
    gauge_artifact_sha = distinct_authority_digests ? repeat("c", 64) : "NOT_APPLICABLE"
    representation = WannierNLQG.SymmetryFoundation.BandRepresentation(
        target_scope ? "1.17" : "1.0",
        :synthetic,
        false,
        lattice,
        2.0pi .* lattice,
        (2, 1, 1),
        [0.0 0.0 0.0; 0.5 0.0 0.0],
        reshape([1.4, 0.6], 1, 2),
        operations,
        [1 2; 1 2],
        zeros(Int, 3, 2, 2),
        ones(ComplexF64, 1, 1, 2, 2),
        ones(Int, 1, 2),
        [1, 2],
        [1, 2],
        [1, 1],
        conventions = Dict(
            "authoritative_hamiltonian" => authority,
            "authoritative_hamiltonian_sha256" => authority_contract_sha,
            "wavefunction_gauge_hdf5_sha256" => gauge_artifact_sha,
            "scoped_production_eligible" => string(target_scope),
            "global_production_eligible" => "false",
            "energy_shift_qualification" =>
                target_scope ? "audit_only" : "legacy_energy_shift_hard_gate",
            "maximum_energy_shift_audit_reference_ev" =>
                target_scope ? "5.0e-6" : "NOT_APPLICABLE",
            "rms_energy_shift_audit_reference_ev" => target_scope ? "1.0e-6" : "NOT_APPLICABLE",
            "target_energy_shift_audit_status" =>
                target_scope ? "WITHIN_AUDIT_REFERENCE" : "NOT_APPLICABLE",
            "symmetrized_parent_energy_shift_audit_status" =>
                target_scope ? "WITHIN_AUDIT_REFERENCE" : "NOT_APPLICABLE",
            "residual_gate_phase" =>
                target_scope ? "post_symmetrization" : "legacy_pre_symmetrization",
            "raw_preflight_diagnostic_status" =>
                target_scope ? "RAW_PREFLIGHT_DIAGNOSTIC_EXCEEDED" : "NOT_APPLICABLE",
            "native_difference_qualification" =>
                target_scope ? "audit_only" : "legacy_hard_gate",
            "native_difference_audit_status" =>
                target_scope ? "AUDIT_REFERENCE_EXCEEDED" : "NOT_APPLICABLE",
            "qualification_scope" => target_scope ? "target_subspace" : "full_parent",
            "target_authority" => target_scope ? "outer_window" : "NOT_APPLICABLE",
            "parent_audit_policy" => target_scope ? "audit_only" : "legacy_hard_gate",
            "target_subspace_contract_sha256" =>
                target_scope ? repeat("c", 64) : "NOT_APPLICABLE",
            "target_leakage_semantics" =>
                target_scope ? TBQ_W.TB_TARGET_LEAKAGE_WEIGHT_SEMANTICS : "NOT_APPLICABLE",
            "target_leakage_formula_sha256" =>
                target_scope ? TBQ_W.TB_TARGET_LEAKAGE_WEIGHT_FORMULA_SHA256 : "NOT_RECORDED",
            "target_leakage_threshold" => target_scope ? "5.0e-6" : "NOT_RECORDED",
            "requested_wannierization_mode" => "symmetry_adapted",
            "effective_wannierization_mode" => "symmetry_adapted",
            "representation_source" => "provided",
            "symmetry_constraints_applied" => "true",
            "target_anchor" => target_scope ? "completed_symmetrized_target" : "NOT_APPLICABLE",
            "target_complement_completion" =>
                target_scope ? "frozen_target_complement" : "NOT_APPLICABLE",
            "target_complement_max_element_ev" => target_scope ? "5.0e-6" : "NOT_APPLICABLE",
            "auxiliary_parent_qualification" =>
                target_scope ? "audit_only" : "legacy_hard_gate",
            "symmetrized_target_subspace_status" =>
                target_scope ? "SYMMETRIZED_TARGET_SUBSPACE_PASS" : "NOT_APPLICABLE",
            "auxiliary_parent_audit_status" =>
                target_scope ? "AUXILIARY_PARENT_AUDIT_EXCEEDED" : "NOT_APPLICABLE",
            "target_scope_production_eligible" => string(target_scope),
        ),
    )
    bundle = joinpath(
        directory,
        "tbq-$(antiunitary)-$(break_hopping)-$(break_position)-$(authority).wannierization-tb.h5",
    )
    provenance = Dict{String, Any}()
    if distinct_authority_digests
        operator_extension = Base.get_extension(WannierNLQG, :WannierNLQGOperatorBundleExt)
        operator_extension === nothing && error("operator-bundle extension is unavailable")
        qualification = Base.invokelatest(
            getfield(operator_extension, :_default_operator_qualification),
            :hamiltonian_position,
            [TBQ_C.REAL_SPACE_HAMILTONIAN, TBQ_C.REAL_SPACE_POSITION],
        )
        record = qualification["operators"]["hamiltonian"]
        record["authoritative_hamiltonian"] = authority
        record["authoritative_hamiltonian_digest"] = authority_data_sha
        record["authoritative_hamiltonian_input_sha256"] = Dict(
            "AUTHORITATIVE_HAMILTONIAN_SHA256" => authority_contract_sha,
            "WAVEFUNCTION_GAUGE_HDF5" => gauge_artifact_sha,
        )
        record["qualification"] = "PASS"
        record["reason"] = "SYNTHETIC_AUTHORITY_BINDING_PASS"
        digest_payload = Dict{String, Any}(
            String(key) => value for
            (key, value) in pairs(record) if String(key) != "payload_sha256"
        )
        record["payload_sha256"] = Base.invokelatest(
            getfield(operator_extension, :_operator_qualification_digest),
            digest_payload,
        )
        provenance["operator_qualification"] = qualification
    end
    TBQ_IO.write_real_space_operator_bundle(
        bundle,
        lattice,
        degeneracies,
        Dict(TBQ_C.REAL_SPACE_HAMILTONIAN => hamiltonian, TBQ_C.REAL_SPACE_POSITION => position);
        profile = :hamiltonian_position,
        overwrite = true,
        provenance,
        geometry = tbq_geometry(lattice, position),
        eligibility = Dict(
            "production_eligible" => true,
            "authoritative_hamiltonian" => authority,
            "authoritative_hamiltonian_sha256" => authority_data_sha,
            "scoped_production_eligible" => target_scope,
            "global_production_eligible" => false,
            "energy_shift_qualification" =>
                target_scope ? "audit_only" : "legacy_energy_shift_hard_gate",
            "maximum_energy_shift_audit_reference_ev" => target_scope ? "5.0e-6" : "NOT_APPLICABLE",
            "rms_energy_shift_audit_reference_ev" => target_scope ? "1.0e-6" : "NOT_APPLICABLE",
            "target_energy_shift_audit_status" =>
                target_scope ? "WITHIN_AUDIT_REFERENCE" : "NOT_APPLICABLE",
            "symmetrized_parent_energy_shift_audit_status" =>
                target_scope ? "WITHIN_AUDIT_REFERENCE" : "NOT_APPLICABLE",
            "residual_gate_phase" =>
                target_scope ? "post_symmetrization" : "legacy_pre_symmetrization",
            "raw_preflight_diagnostic_status" =>
                target_scope ? "RAW_PREFLIGHT_DIAGNOSTIC_EXCEEDED" : "NOT_APPLICABLE",
            "native_difference_qualification" => target_scope ? "audit_only" : "legacy_hard_gate",
            "native_difference_audit_status" =>
                target_scope ? "AUDIT_REFERENCE_EXCEEDED" : "NOT_APPLICABLE",
            "qualification_scope" => target_scope ? "target_subspace" : "full_parent",
            "target_authority" => target_scope ? "outer_window" : "NOT_APPLICABLE",
            "parent_audit_policy" => target_scope ? "audit_only" : "legacy_hard_gate",
            "disentanglement_outer_mask_sha256" => target_scope ? repeat("d", 64) : "NOT_RECORDED",
            "disentanglement_frozen_mask_sha256" => target_scope ? repeat("e", 64) : "NOT_RECORDED",
            "target_subspace_contract_sha256" => target_scope ? repeat("c", 64) : "NOT_RECORDED",
            "target_leakage_semantics" =>
                target_scope ? TBQ_W.TB_TARGET_LEAKAGE_WEIGHT_SEMANTICS : "NOT_APPLICABLE",
            "target_leakage_formula_sha256" =>
                target_scope ? TBQ_W.TB_TARGET_LEAKAGE_WEIGHT_FORMULA_SHA256 : "NOT_RECORDED",
            "target_leakage_threshold" => target_scope ? 5.0e-6 : "NOT_RECORDED",
            "target_anchor" => target_scope ? "completed_symmetrized_target" : "NOT_APPLICABLE",
            "target_complement_completion" =>
                target_scope ? "frozen_target_complement" : "NOT_APPLICABLE",
            "target_complement_max_element_ev" => target_scope ? "5.0e-6" : "NOT_APPLICABLE",
            "auxiliary_parent_qualification" => target_scope ? "audit_only" : "legacy_hard_gate",
            "symmetrized_target_subspace_status" =>
                target_scope ? "SYMMETRIZED_TARGET_SUBSPACE_PASS" : "NOT_APPLICABLE",
            "auxiliary_parent_audit_status" =>
                target_scope ? "AUXILIARY_PARENT_AUDIT_EXCEEDED" : "NOT_APPLICABLE",
            "target_scope_production_eligible" => target_scope,
        ),
    )
    return (; bundle, representation, plan)
end

function tbq_result(status, qualification, bundle)
    summary = Dict(
        "requested_wannierization_mode" => "symmetry_adapted",
        "effective_wannierization_mode" => "symmetry_adapted",
        "representation_source" => "provided",
        "symmetry_constraints_applied" => "true",
        "effective_algorithm_profile" => "symmetry_projected_default",
        "optimizer_schedule" => "two_stage",
        "u_acceptance" => "armijo",
        "representation_compatible" => "true",
        "physics_qualification" => "QUALIFIED",
        "band_validation_pass" => "true",
        "z_seal_class" => "CONVERGED",
        "qualified_z_seal" => "true",
        "standard_tb_export_eligible" => "true",
        "convergence_tolerance" => "1.0e-9",
        "tb_symmetry_qualification" => qualification.overall,
        "authoritative_hamiltonian" => "native_dft",
        "authoritative_hamiltonian_sha256" => "LEGACY_NATIVE_DFT",
        "qualification_scope" => "full_parent",
        "target_authority" => "NOT_APPLICABLE",
        "parent_audit_policy" => "legacy_hard_gate",
        "target_subspace_contract_sha256" => "NOT_APPLICABLE",
    )
    return TBQ_W.WannierizationResult(
        status,
        ones(ComplexF64, 1, 1, 1),
        zeros(Float64, 1, 3),
        [0.0],
        TBQ_W.WannierizationIteration[],
        TBQ_W.WannierizationDiagnostic[],
        summary,
        nothing,
        nothing,
        nothing,
        TBQ_W.WannierizationArtifacts(packed_hdf5 = bundle),
        nothing,
        qualification,
    )
end

@testset "final exported TB symmetry qualification" begin
    parent_extension = first(TBQ_W._load_wannierization_extension!())
    support = parent_extension.WannierizationInternalSupport
    solver = parent_extension.SolverCheckpoint
    operator_export = parent_extension.OperatorExport
    mktempdir() do directory
        exact = tbq_fixture(directory)
        json_file = joinpath(directory, "exact.wannierization-tb-symmetry.json")
        qualification = TBQ_W.qualify_exported_wannierization_tb(
            exact.bundle,
            exact.representation,
            exact.plan;
            hamiltonian_covariance_threshold = 1.0e-10,
            json_file,
        )
        @test qualification.overall == "PASS"
        @test qualification.schema_version == "1.7"
        @test all(metric -> metric.status == "PASS", qualification.metrics)
        @test length(qualification.payload_sha256) == 64
        exact_manifest = TBQ_IO.read_real_space_operator_bundle_manifest(exact.bundle)
        @test exact_manifest.schema_version == TBQ_IO.OPERATOR_BUNDLE_SCHEMA_VERSION
        @test exact_manifest.tb_symmetry_qualification_present
        @test exact_manifest.tb_symmetry_qualification_overall == "PASS"
        @test exact_manifest.tb_symmetry_qualification_sha256 == qualification.payload_sha256
        packed_qualification = HDF5.h5open(exact.bundle, "r") do handle
            Base.invokelatest(support.read_tb_symmetry_qualification_group, handle)
        end
        @test packed_qualification.payload_sha256 == qualification.payload_sha256
        @test packed_qualification.schema_version == "1.7"
        json_payload = JSON3.read(read(json_file, String))
        @test String(json_payload.payload_sha256) == qualification.payload_sha256
        @test String(json_payload.overall) == "PASS"

        target = tbq_fixture(directory; target_subspace = true)
        target_qualification = TBQ_W.qualify_exported_wannierization_tb(
            target.bundle,
            target.representation,
            target.plan;
            hamiltonian_covariance_threshold = 1.0e-10,
        )
        @test target_qualification.overall == "PASS"
        @test target_qualification.schema_version == "1.7"
        @test target_qualification.authoritative_hamiltonian == "symmetrized_dft_hamiltonian"
        @test target_qualification.qualification_scope == "target_subspace"
        @test target_qualification.target_anchor == "completed_symmetrized_target"
        @test target_qualification.auxiliary_parent_qualification == "audit_only"
        @test target_qualification.target_scope_production_eligible
        @test target_qualification.target_leakage_semantics ==
              TBQ_W.TB_TARGET_LEAKAGE_WEIGHT_SEMANTICS
        @test target_qualification.target_leakage_formula_sha256 ==
              TBQ_W.TB_TARGET_LEAKAGE_WEIGHT_FORMULA_SHA256
        @test target_qualification.target_leakage_threshold == 5.0e-6
        target_manifest = TBQ_IO.read_real_space_operator_bundle_manifest(target.bundle)
        @test target_manifest.schema_version == TBQ_IO.OPERATOR_BUNDLE_SCHEMA_VERSION
        @test target_manifest.qualification_scope == "target_subspace"
        @test target_manifest.target_scope_production_eligible
        @test target_manifest.target_leakage_semantics == TBQ_W.TB_TARGET_LEAKAGE_WEIGHT_SEMANTICS
        @test target_manifest.target_leakage_formula_sha256 ==
              TBQ_W.TB_TARGET_LEAKAGE_WEIGHT_FORMULA_SHA256
        @test target_manifest.target_leakage_threshold == 5.0e-6
        legacy_target_bundle = joinpath(directory, "legacy-target-5.9.wannierization-tb.h5")
        cp(target.bundle, legacy_target_bundle)
        HDF5.h5open(legacy_target_bundle, "r+") do handle
            HDF5.delete_attribute(handle, "schema_version")
            HDF5.attributes(handle)["schema_version"] = "5.9"
        end
        legacy_bundle_error = try
            TBQ_IO.read_real_space_operator_bundle_manifest(legacy_target_bundle)
            nothing
        catch exception
            sprint(showerror, exception)
        end
        @test occursin(
            "UNSUPPORTED_LEGACY_TARGET_LEAKAGE_SEMANTICS",
            something(legacy_bundle_error, ""),
        )
        tampered_target_bundle =
            joinpath(directory, "tampered-target-threshold.wannierization-tb.h5")
        cp(target.bundle, tampered_target_bundle)
        HDF5.h5open(tampered_target_bundle, "r+") do handle
            HDF5.delete_attribute(handle, "target_leakage_threshold")
            HDF5.attributes(handle)["target_leakage_threshold"] = 4.0e-6
        end
        @test_throws ArgumentError TBQ_IO.read_real_space_operator_bundle_manifest(
            tampered_target_bundle,
        )
        packed_target_qualification = HDF5.h5open(target.bundle, "r") do handle
            Base.invokelatest(support.read_tb_symmetry_qualification_group, handle)
        end
        @test packed_target_qualification.payload_sha256 == target_qualification.payload_sha256
        @test packed_target_qualification.target_leakage_semantics ==
              TBQ_W.TB_TARGET_LEAKAGE_WEIGHT_SEMANTICS
        @test packed_target_qualification.target_leakage_formula_sha256 ==
              TBQ_W.TB_TARGET_LEAKAGE_WEIGHT_FORMULA_SHA256
        @test packed_target_qualification.target_leakage_threshold == 5.0e-6
        target.representation.conventions["target_leakage_threshold"] = "4.0e-6"
        @test_throws ArgumentError TBQ_W.qualify_exported_wannierization_tb(
            target.bundle,
            target.representation,
            target.plan;
            hamiltonian_covariance_threshold = 1.0e-10,
            persist_hdf5 = false,
        )
        target.representation.conventions["target_leakage_threshold"] = "5.0e-6"

        distinct = tbq_fixture(directory; target_subspace = true, distinct_authority_digests = true)
        distinct_qualification = TBQ_W.qualify_exported_wannierization_tb(
            distinct.bundle,
            distinct.representation,
            distinct.plan;
            hamiltonian_covariance_threshold = 1.0e-10,
            persist_hdf5 = false,
        )
        @test distinct_qualification.overall == "PASS"
        @test distinct_qualification.authoritative_hamiltonian_sha256 == repeat("a", 64)
        distinct.representation.conventions["authoritative_hamiltonian_sha256"] = repeat("d", 64)
        @test_throws ArgumentError TBQ_W.qualify_exported_wannierization_tb(
            distinct.bundle,
            distinct.representation,
            distinct.plan;
            hamiltonian_covariance_threshold = 1.0e-10,
            persist_hdf5 = false,
        )
        distinct.representation.conventions["authoritative_hamiltonian_sha256"] = repeat("b", 64)
        distinct.representation.conventions["wavefunction_gauge_hdf5_sha256"] = repeat("d", 64)
        @test_throws ArgumentError TBQ_W.qualify_exported_wannierization_tb(
            distinct.bundle,
            distinct.representation,
            distinct.plan;
            hamiltonian_covariance_threshold = 1.0e-10,
            persist_hdf5 = false,
        )

        target_digest_fixture = TBQ_W.TBSymmetryQualification(
            "NOT_RUN",
            "TARGET_DIGEST_FIXTURE",
            TBQ_W.TBSymmetryMetric[];
            qualification_scope = "target_subspace",
            target_leakage_semantics = TBQ_W.TB_TARGET_LEAKAGE_WEIGHT_SEMANTICS,
            target_leakage_formula_sha256 = TBQ_W.TB_TARGET_LEAKAGE_WEIGHT_FORMULA_SHA256,
            target_leakage_threshold = 5.0e-6,
        )
        changed_target_threshold = TBQ_W.TBSymmetryQualification(
            "NOT_RUN",
            "TARGET_DIGEST_FIXTURE",
            TBQ_W.TBSymmetryMetric[];
            qualification_scope = "target_subspace",
            target_leakage_semantics = TBQ_W.TB_TARGET_LEAKAGE_WEIGHT_SEMANTICS,
            target_leakage_formula_sha256 = TBQ_W.TB_TARGET_LEAKAGE_WEIGHT_FORMULA_SHA256,
            target_leakage_threshold = 4.0e-6,
        )
        @test changed_target_threshold.payload_sha256 != target_digest_fixture.payload_sha256
        @test_throws ArgumentError TBQ_W.TBSymmetryQualification(
            "NOT_RUN",
            "TARGET_DIGEST_FIXTURE",
            TBQ_W.TBSymmetryMetric[];
            payload_sha256 = target_digest_fixture.payload_sha256,
            qualification_scope = "target_subspace",
            target_leakage_semantics = TBQ_W.TB_TARGET_LEAKAGE_WEIGHT_SEMANTICS,
            target_leakage_formula_sha256 = TBQ_W.TB_TARGET_LEAKAGE_WEIGHT_FORMULA_SHA256,
            target_leakage_threshold = 4.0e-6,
        )

        legacy_full_parent = TBQ_W.TBSymmetryQualification(
            "NOT_RUN",
            "LEGACY_FULL_PARENT_AUDIT",
            TBQ_W.TBSymmetryMetric[];
            schema_version = "1.6",
        )
        legacy_tbq_file = joinpath(directory, "legacy-full-parent-tbq.h5")
        HDF5.h5open(legacy_tbq_file, "w") do handle
            Base.invokelatest(
                support.write_tb_symmetry_qualification_group,
                handle,
                legacy_full_parent,
            )
        end
        legacy_full_parent_readback = HDF5.h5open(legacy_tbq_file, "r") do handle
            Base.invokelatest(support.read_tb_symmetry_qualification_group, handle)
        end
        @test legacy_full_parent_readback.schema_version == "1.6"
        @test legacy_full_parent_readback.qualification_scope == "full_parent"
        HDF5.h5open(legacy_tbq_file, "r+") do handle
            group = handle["tb_symmetry_qualification"]
            HDF5.delete_attribute(group, "qualification_scope")
            HDF5.attributes(group)["qualification_scope"] = "target_subspace"
        end
        legacy_target_error = try
            HDF5.h5open(legacy_tbq_file, "r") do handle
                Base.invokelatest(support.read_tb_symmetry_qualification_group, handle)
            end
            nothing
        catch exception
            sprint(showerror, exception)
        end
        @test occursin(
            "UNSUPPORTED_LEGACY_TARGET_LEAKAGE_SEMANTICS",
            something(legacy_target_error, ""),
        )
        @test_throws ArgumentError TBQ_W.TBSymmetryQualification(
            "PASS",
            "CROSS_AUTHORITY_REUSE_MUST_STOP",
            TBQ_W.TBSymmetryMetric[];
            schema_version = "1.4",
            authoritative_hamiltonian = "symmetrized_target_subspace_candidate",
            authoritative_hamiltonian_sha256 = repeat("a", 64),
            energy_shift_qualification = "audit_only",
            residual_gate_phase = "post_symmetrization",
            native_difference_qualification = "audit_only",
            qualification_scope = "target_subspace",
            target_anchor = "completed_symmetrized_target",
            auxiliary_parent_qualification = "audit_only",
        )

        legacy_error = try
            TBQ_W.TBSymmetryQualification(
                "PASS",
                "LEGACY_AUTHORITY_MUST_STOP",
                TBQ_W.TBSymmetryMetric[];
                schema_version = "1.1",
                authoritative_hamiltonian = "symmetrized_hamiltonian_candidate",
                authoritative_hamiltonian_sha256 = repeat("b", 64),
                scoped_production_eligible = true,
            )
            nothing
        catch exception
            sprint(showerror, exception)
        end
        @test occursin("UNSUPPORTED_LEGACY_AUTHORITY", something(legacy_error, ""))

        symmetrized = tbq_fixture(directory; symmetrized = true)
        symmetrized_qualification = TBQ_W.qualify_exported_wannierization_tb(
            symmetrized.bundle,
            symmetrized.representation,
            symmetrized.plan;
            hamiltonian_covariance_threshold = 1.0e-10,
        )
        @test symmetrized_qualification.overall == "PASS"
        @test symmetrized_qualification.authoritative_hamiltonian == "symmetrized_dft_hamiltonian"
        @test symmetrized_qualification.scoped_production_eligible
        @test !symmetrized_qualification.global_production_eligible
        @test symmetrized_qualification.energy_shift_qualification == "audit_only"
        @test_throws ArgumentError TBQ_W.qualify_exported_wannierization_tb(
            symmetrized.bundle,
            exact.representation,
            symmetrized.plan;
            hamiltonian_covariance_threshold = 1.0e-10,
            persist_hdf5 = false,
        )

        antiunitary = tbq_fixture(directory; antiunitary = true)
        antiunitary_qualification = TBQ_W.qualify_exported_wannierization_tb(
            antiunitary.bundle,
            antiunitary.representation,
            antiunitary.plan;
            hamiltonian_covariance_threshold = 1.0e-10,
        )
        @test antiunitary_qualification.overall == "PASS"

        broken_hopping = tbq_fixture(directory; break_hopping = true)
        hopping_qualification = TBQ_W.qualify_exported_wannierization_tb(
            broken_hopping.bundle,
            broken_hopping.representation,
            broken_hopping.plan;
            hamiltonian_covariance_threshold = 1.0e-10,
        )
        hopping_metrics = Dict(metric.name => metric for metric in hopping_qualification.metrics)
        @test hopping_qualification.overall == "FAIL"
        @test hopping_metrics["hamiltonian_covariance_relative_max"].status == "FAIL"

        broken_position = tbq_fixture(directory; break_position = true)
        position_qualification = TBQ_W.qualify_exported_wannierization_tb(
            broken_position.bundle,
            broken_position.representation,
            broken_position.plan;
            hamiltonian_covariance_threshold = 1.0e-10,
        )
        position_metrics = Dict(metric.name => metric for metric in position_qualification.metrics)
        @test position_qualification.overall == "FAIL"
        @test position_metrics["centerless_position_covariance_relative_max"].status == "FAIL"

        missing_representation = tbq_fixture(directory; antiunitary = true)
        incomplete = TBQ_W.qualify_exported_wannierization_tb(
            missing_representation.bundle,
            nothing,
            missing_representation.plan;
            hamiltonian_covariance_threshold = 1.0e-10,
            persist_hdf5 = false,
        )
        @test incomplete.overall == "INCOMPLETE"
        incomplete_metrics = Dict(metric.name => metric for metric in incomplete.metrics)
        @test incomplete_metrics["kstar_spectral_residual_ev"].status == "NOT_APPLICABLE"
        @test incomplete_metrics["kstar_spectral_residual_ev"].reason ==
              "BAND_REPRESENTATION_NOT_AVAILABLE"

        missing_plan = TBQ_W.qualify_exported_wannierization_tb(
            missing_representation.bundle,
            missing_representation.representation,
            nothing;
            hamiltonian_covariance_threshold = 1.0e-10,
            persist_hdf5 = false,
        )
        @test missing_plan.overall == "INCOMPLETE"
        @test any(
            metric -> metric.reason == "WANNIER_SYMMETRY_PLAN_NOT_AVAILABLE",
            missing_plan.metrics,
        )

        no_tb = TBQ_W.qualify_exported_wannierization_tb(
            joinpath(directory, "absent.h5"),
            nothing,
            nothing;
            hamiltonian_covariance_threshold = 1.0e-10,
        )
        @test no_tb.overall == "NOT_RUN"
        @test no_tb.reason == "TB_NOT_AVAILABLE"
        @test all(metric -> metric.status == "NOT_RUN", no_tb.metrics)

        diagnostic = tbq_result(TBQ_W.MAX_ITERATIONS, qualification, exact.bundle)
        @test diagnostic.tb_symmetry_qualification.overall == "PASS"
        @test !Base.invokelatest(solver._wannierization_production_eligible, diagnostic)
        converged = tbq_result(TBQ_W.COMPLETED, qualification, exact.bundle)
        @test Base.invokelatest(solver._wannierization_production_eligible, converged)
        unqualified = tbq_result(
            TBQ_W.COMPLETED,
            Base.invokelatest(
                operator_export._tb_symmetry_unavailable,
                "TB_NOT_AVAILABLE",
                1.0e-10,
            ),
            exact.bundle,
        )
        @test !Base.invokelatest(solver._wannierization_production_eligible, unqualified)

        checkpoint = joinpath(directory, "exact.wannierization.h5")
        TBQ_W.write_wannierization_checkpoint_hdf5(checkpoint, converged)
        restored = TBQ_W.read_wannierization_checkpoint_hdf5(checkpoint)
        @test restored.tb_symmetry_qualification.payload_sha256 == qualification.payload_sha256
        checkpoint_digest = Base.invokelatest(
            operator_export._bind_packed_checkpoint_sha256!,
            exact.bundle,
            checkpoint,
        )
        exact_manifest = TBQ_IO.read_real_space_operator_bundle_manifest(exact.bundle)
        @test exact_manifest.checkpoint_sha256 == checkpoint_digest
        HDF5.h5open(checkpoint, "r") do handle
            @test String(read(HDF5.attributes(handle)["schema_version"])) == "1.0"
            @test String(read(HDF5.attributes(handle)["checkpoint_sha256"])) == checkpoint_digest
            @test String(
                read(HDF5.attributes(handle["tb_symmetry_qualification"])["payload_sha256"]),
            ) == qualification.payload_sha256
        end
        HDF5.h5open(exact.bundle, "r") do handle
            @test String(read(HDF5.attributes(handle)["checkpoint_sha256"])) == checkpoint_digest
            @test String(read(HDF5.attributes(handle["diagnostics"])["checkpoint_sha256"])) ==
                  checkpoint_digest
        end

        legacy = joinpath(directory, "legacy-2.4.wannierization.h5")
        cp(checkpoint, legacy)
        persisted_converged = Base.invokelatest(solver._checkpoint_persisted_result, converged)
        legacy_digest =
            Base.invokelatest(solver._wannierization_checkpoint_sha256_v2_4, persisted_converged)
        HDF5.h5open(legacy, "r+") do handle
            HDF5.delete_attribute(handle, "schema_version")
            HDF5.attributes(handle)["schema_version"] = "2.4"
            HDF5.delete_attribute(handle, "checkpoint_sha256")
            HDF5.attributes(handle)["checkpoint_sha256"] = legacy_digest
        end
        legacy_restored = TBQ_W.read_wannierization_checkpoint_hdf5(legacy)
        @test legacy_restored.tb_symmetry_qualification.overall == "NOT_RUN"
        @test legacy_restored.tb_symmetry_qualification.reason == "LEGACY_SCHEMA_FIELD_ABSENT"

        log_buffer = IOBuffer()
        config = TBQ_W.SymmetryAdaptedWannierizationConfig(
            input = TBQ_W.WannierizationInputConfig(
                wannierization_mode = :symmetry_adapted,
                band_representation = exact.representation,
                win_file = "synthetic.win",
                eig_file = "synthetic.eig",
                mmn_file = "synthetic.mmn",
                num_wannier = 1,
            ),
            solver = TBQ_W.WannierizationSolverConfig(),
            checkpoint = TBQ_W.WannierizationCheckpointConfig(),
            runtime = TBQ_W.WannierizationRuntimeConfig(),
            output = TBQ_W.WannierizationOutputConfig(),
        )
        Base.invokelatest(
            operator_export._write_wannierization_final,
            log_buffer,
            diagnostic,
            config,
            diagnostic.artifacts;
            wall_time = 0.0,
            allocated_bytes = 0,
            gc_time = 0.0,
        )
        log_text = String(take!(log_buffer))
        @test occursin("[SOLVER PROJECTOR COVARIANCE]", log_text)
        @test occursin("[REPRESENTATION AND GROUP-LAW DIAGNOSTICS]", log_text)
        @test occursin("FINAL TB SYMMETRY QUALIFICATION (diagnostic model)", log_text)
        @test occursin(qualification.payload_sha256, log_text)
    end
end
