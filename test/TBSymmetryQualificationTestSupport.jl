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
        "replica_mapping_reference" => repeat("0", 64),
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
            "target_leakage_formula_definition" =>
                target_scope ? TBQ_W.TB_TARGET_LEAKAGE_WEIGHT_FORMULA_DEFINITION : "NOT_RECORDED",
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
    # Bind actual authority policy/scope semantics, not evidence identities.
    provenance=Dict{String, Any}(
        "authoritative_hamiltonian"=>authority,
        "authoritative_hamiltonian_policy_definition"=>authority_contract_sha,
    )
    representation.conventions["target_leakage_formula_definition"]=TBQ_W.TB_TARGET_LEAKAGE_WEIGHT_FORMULA_DEFINITION
    TBQ_IO.write_real_space_operator_bundle(
        bundle,
        lattice,
        degeneracies,
        Dict(TBQ_C.REAL_SPACE_HAMILTONIAN => hamiltonian, TBQ_C.REAL_SPACE_POSITION => position);
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
            "target_leakage_formula_definition" =>
                target_scope ? TBQ_W.TB_TARGET_LEAKAGE_WEIGHT_FORMULA_DEFINITION : "NOT_RECORDED",
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
        "wannierization_eligibility_strictly_converged_z_seal" => "true",
        "wannierization_eligibility_export_eligible" => "true",
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
