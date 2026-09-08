using HDF5
using LinearAlgebra
using Test
using WannierNLQG

isdefined(Main, :QEPAWMatrixElementsTestSupport) ||
    include(joinpath(@__DIR__, "QEPAWMatrixElementsTestSupport.jl"))
using .QEPAWMatrixElementsTestSupport: write_qe_paw_fixture

const TARGET_SCOPE_W = WannierNLQG.Wannierization
const TARGET_SCOPE_EXTENSION = first(TARGET_SCOPE_W._load_wannierization_extension!())
const TARGET_SCOPE_PAW = TARGET_SCOPE_EXTENSION.PAWMatrixElements
const TARGET_SCOPE_WORKFLOW = TARGET_SCOPE_EXTENSION.WorkflowOrchestration

function target_scope_solution(; overrides = Dict{String, Float64}())
    maxima = Dict{String, Float64}(
        "hamiltonian_covariance_after_ev" => 0.0,
        "hamiltonian_covariance_after_operator_ev" => 0.0,
        "hamiltonian_covariance_after_source_column_l2_ev" => 0.0,
        "hamiltonian_covariance_after_normalized_frobenius_ev" => 0.0,
        "projected_eigen_residual_ev" => 0.0,
        "target_reconstruction_leakage_weight" => 0.0,
        "target_state_leakage_weight" => 0.0,
        "target_to_complement_leakage_weight" => 0.0,
        "complement_to_target_leakage_weight" => 0.0,
        "raw_unitarity" => 0.0,
        "normalized_polar_correction" => 0.0,
        "star1_strict_raw_group_law" => 0.0,
        "star1_strict_raw_cocycle" => 0.0,
    )
    merge!(maxima, overrides)
    return (maxima = maxima, maximum_contexts = Dict{String, String}())
end

function target_scope_violations(; overrides = Dict{String, Float64}())
    return Base.invokelatest(
        TARGET_SCOPE_PAW._star_partition_candidate_violations,
        target_scope_solution(; overrides),
        TARGET_SCOPE_W.PAWGaugeThresholds(),
        TARGET_SCOPE_W.FixedGapPAWBlockPartition(),
        TARGET_SCOPE_W.NativeDFTHamiltonian(),
        true,
    )
end

function one_band_target_contract()
    scope = WannierNLQG.SymmetryFoundation.BandRepresentationQualificationScope(
        trues(1, 1),
        trues(1, 1),
    )
    return TARGET_SCOPE_W.TargetSubspaceQualificationContract(
        scope;
        outer_min_ev = -18.0,
        outer_max_ev = 3.5,
        frozen_min_ev = -18.0,
        frozen_max_ev = 0.5,
        num_wannier = 1,
    )
end

function target_scope_identity_representation(scope, contract)
    operation = WannierNLQG.SymmetryFoundation.SymmetryOperation(
        Matrix{Int}(I, 3, 3),
        zeros(3),
        Matrix{Float64}(I, 3, 3),
    )
    return WannierNLQG.SymmetryFoundation.BandRepresentation(
        "1.17",
        :synthetic,
        false,
        Matrix{Float64}(I, 3, 3),
        2.0pi .* Matrix{Float64}(I, 3, 3),
        (1, 1, 1),
        zeros(1, 3),
        reshape([-2.0, 1.0], 2, 1),
        [operation],
        ones(Int, 1, 1),
        zeros(Int, 3, 1, 1),
        reshape(Matrix{ComplexF64}(I, 2, 2), 2, 2, 1, 1),
        reshape([1, 2], 2, 1),
        [1],
        [1],
        [1];
        conventions = Dict(
            "qualification_scope" => "target_subspace",
            "outer_mask_sha256" => scope.outer_mask_sha256,
            "frozen_mask_sha256" => scope.frozen_mask_sha256,
            "target_subspace_contract_sha256" => contract.contract_sha256,
            "target_leakage_semantics" => TARGET_SCOPE_PAW.TARGET_LEAKAGE_WEIGHT_SEMANTICS,
            "target_leakage_formula_sha256" =>
                TARGET_SCOPE_PAW.TARGET_LEAKAGE_WEIGHT_FORMULA_SHA256,
            "target_leakage_threshold" =>
                repr(contract.scoped_paw_thresholds.target_leakage_weight),
        ),
        input_sha256 = Dict("TARGET_SUBSPACE_CONTRACT_SHA256" => contract.contract_sha256),
    )
end

@testset "target scope preserves the fixed parent rotation shape" begin
    rotations = zeros(ComplexF64, 4, 4, 3)
    rotations[:, :, 1] .= Matrix{ComplexF64}(I, 4, 4)
    rotations[:, :, 2] .= Matrix{ComplexF64}(I, 4, 4)[:, [2, 1, 4, 3]]
    rotations[:, :, 3] .= Diagonal(ComplexF64[1.0, -1.0, im, -im])

    parent_amn_data = ComplexF64.(reshape(1:24, 4, 2, 3))
    parent_amn = WannierNLQG.IO.WannierAMN(4, 3, 2, parent_amn_data)
    rotated_amn = Base.invokelatest(TARGET_SCOPE_PAW._star_rotate_parent_amn, parent_amn, rotations)
    @test rotated_amn.num_bands == 4
    @test size(rotated_amn.data) == (4, 2, 3)
    for kpoint in 1:3
        @test rotated_amn.data[:, :, kpoint] ==
              rotations[:, :, kpoint]' * parent_amn.data[:, :, kpoint]
    end

    parent_mmn_data = ComplexF64.(reshape(1:48, 4, 4, 1, 3))
    parent_mmn = WannierNLQG.IO.WannierMMN(
        4,
        3,
        1,
        parent_mmn_data,
        reshape([1, 3, 2], 1, 3),
        zeros(Int, 3, 1, 3),
    )
    rotated_mmn = Base.invokelatest(TARGET_SCOPE_PAW._star_rotate_parent_mmn, parent_mmn, rotations)
    @test rotated_mmn.num_bands == 4
    @test size(rotated_mmn.data) == (4, 4, 1, 3)
    for kpoint in 1:3
        target_kpoint = parent_mmn.neighbors[1, kpoint]
        @test rotated_mmn.data[:, :, 1, kpoint] ==
              rotations[:, :, kpoint]' *
              parent_mmn.data[:, :, 1, kpoint] *
              rotations[:, :, target_kpoint]
    end
end

@testset "outer-window authority isolates the complete-parent energy audit" begin
    outer_masks = [
        BitVector([true, true, false, false]),
        BitVector([true, true, true, false]),
        BitVector([true, true, true, false]),
    ]
    frozen_masks = [BitVector([true, false, false, false]) for _ in 1:3]
    parent_tail_mismatch_ev = 0.101241806629
    energies_ev = [
        -2.0 -2.0 -2.0
        -1.0 -1.0 -1.0
        1.0 0.0 0.0
        2.0 2.0 2.0 + parent_tail_mismatch_ev
    ]
    mapping = reshape([1, 3, 2], 1, 3)
    audit = Base.invokelatest(
        TARGET_SCOPE_PAW._strict_validate_target_subspace_contract,
        outer_masks,
        frozen_masks,
        energies_ev,
        mapping,
        5.0e-3,
    )
    @test audit.target_energy_residual == 0.0
    @test audit.frozen_energy_residual == 0.0
    @test audit.parent_energy_residual ≈ parent_tail_mismatch_ev atol = 1.0e-14
    @test audit.parent_energy_status == :AUDIT_EXCEEDED
end

@testset "gauge and representation share one immutable target contract digest" begin
    scope = WannierNLQG.SymmetryFoundation.BandRepresentationQualificationScope(
        BitMatrix(reshape([true, false], 2, 1)),
        BitMatrix(reshape([true, false], 2, 1)),
    )
    contract = TARGET_SCOPE_W.TargetSubspaceQualificationContract(
        scope;
        outer_min_ev = -18.0,
        outer_max_ev = 3.5,
        frozen_min_ev = -18.0,
        frozen_max_ev = 0.5,
        num_wannier = 1,
    )
    @test Base.invokelatest(TARGET_SCOPE_PAW._star_target_subspace_contract_sha256, contract) ==
          contract.contract_sha256
    representation = target_scope_identity_representation(scope, contract)
    config = TARGET_SCOPE_W.BandRepresentationPreparationConfig(
        wannierization_mode = :symmetry_adapted,
        source = WannierNLQG.SymmetryFoundation.QuantumEspressoWavefunctionSource(
            "fixture.save";
            band_range = 1:2,
        ),
        win_file = "fixture.win",
        eig_file = "fixture.eig",
        num_wannier = 1,
        outer_min_ev = -18.0,
        outer_max_ev = 3.5,
        frozen_min_ev = -18.0,
        frozen_max_ev = 0.5,
    )
    rebound = Base.invokelatest(
        TARGET_SCOPE_WORKFLOW._representation_with_target_subspace_contract,
        representation,
        config,
        scope,
    )
    @test rebound.conventions["target_subspace_contract_sha256"] == contract.contract_sha256

    changed_scope = WannierNLQG.SymmetryFoundation.BandRepresentationQualificationScope(
        trues(2, 1),
        BitMatrix(reshape([true, false], 2, 1)),
    )
    @test_throws ArgumentError Base.invokelatest(
        TARGET_SCOPE_WORKFLOW._representation_with_target_subspace_contract,
        representation,
        config,
        changed_scope,
    )

    changed_threshold_contract = TARGET_SCOPE_W.TargetSubspaceQualificationContract(
        scope;
        outer_min_ev = -18.0,
        outer_max_ev = 3.5,
        frozen_min_ev = -18.0,
        frozen_max_ev = 0.5,
        num_wannier = 1,
        scoped_paw_thresholds = TARGET_SCOPE_W.PAWGaugeThresholds(paw_s_norm = 4.0e-6),
    )
    changed_threshold_representation =
        target_scope_identity_representation(scope, changed_threshold_contract)
    @test_throws ArgumentError Base.invokelatest(
        TARGET_SCOPE_WORKFLOW._representation_with_target_subspace_contract,
        changed_threshold_representation,
        config,
        scope,
    )
end

@testset "target PAW block gates are bidirectional and parent defects are audit-only" begin
    thresholds = TARGET_SCOPE_W.PAWGaugeThresholds()
    target_mask = BitVector([true, true, false, false])
    identity_parent = Matrix{ComplexF64}(I, 4, 4)

    target_to_complement = copy(identity_parent)
    target_to_complement[3, 1] = sqrt(thresholds.target_leakage_weight) * (1.0 + 1.0e-8)
    leakage = Base.invokelatest(
        TARGET_SCOPE_PAW._strict_bidirectional_target_complement_leakage,
        target_to_complement,
        target_mask,
        target_mask,
    )
    @test leakage.target_to_complement_leakage_weight > thresholds.target_leakage_weight
    @test leakage.complement_to_target_leakage_weight == 0.0
    @test_throws ArgumentError Base.invokelatest(
        TARGET_SCOPE_PAW._strict_sewing_gate,
        "raw_target_to_complement_leakage_weight",
        leakage.target_to_complement_leakage_weight,
        thresholds.target_leakage_weight,
    )

    complement_to_target = copy(identity_parent)
    complement_to_target[1, 3] = sqrt(thresholds.target_leakage_weight) * (1.0 + 1.0e-8)
    leakage = Base.invokelatest(
        TARGET_SCOPE_PAW._strict_bidirectional_target_complement_leakage,
        complement_to_target,
        target_mask,
        target_mask,
    )
    @test leakage.complement_to_target_leakage_weight > thresholds.target_leakage_weight
    @test leakage.target_to_complement_leakage_weight == 0.0
    @test_throws ArgumentError Base.invokelatest(
        TARGET_SCOPE_PAW._strict_sewing_gate,
        "raw_complement_to_target_leakage_weight",
        leakage.complement_to_target_leakage_weight,
        thresholds.target_leakage_weight,
    )

    nonisometric = copy(identity_parent)
    nonisometric[1, 2] = 4.0 * thresholds.raw_unitarity
    block = Base.invokelatest(
        TARGET_SCOPE_PAW._strict_required_square_block_diagnostics,
        nonisometric,
        [1, 2],
        [1, 2],
        :outer,
    )
    @test block.required_rank == block.numerical_rank == 2
    @test block.left_unitarity_residual > thresholds.raw_unitarity
    @test block.right_unitarity_residual > thresholds.raw_unitarity
    for (name, value) in (
        ("raw_target_left_unitarity", block.left_unitarity_residual),
        ("raw_target_right_unitarity", block.right_unitarity_residual),
    )
        @test_throws ArgumentError Base.invokelatest(
            TARGET_SCOPE_PAW._strict_sewing_gate,
            name,
            value,
            thresholds.raw_unitarity,
        )
    end

    target_block = Matrix(@view nonisometric[1:2, 1:2])
    decomposition = svd(target_block)
    polar_correction = norm(decomposition.U * decomposition.Vt - target_block) / sqrt(2)
    @test polar_correction > thresholds.normalized_polar_correction
    @test_throws ArgumentError Base.invokelatest(
        TARGET_SCOPE_PAW._strict_sewing_gate,
        "raw_target_normalized_polar_correction",
        polar_correction,
        thresholds.normalized_polar_correction,
    )

    for (name, threshold) in (
        ("star1_strict_raw_group_law", thresholds.group_law),
        ("star1_strict_raw_cocycle", thresholds.cocycle),
    )
        violations = target_scope_violations(overrides = Dict(name => 1.25 * threshold))
        @test getfield.(violations, :name) == [name]
    end

    parent_only_defects = Dict(
        "wfc_rotation_reconstruction" => 100.0 * thresholds.wfc_rotation_reconstruction,
        "completed_paw_s_norm" => 100.0 * thresholds.paw_s_norm,
        "alternative_path_residual" => 100.0 * thresholds.path_independence,
        "kramers_pair_residual" => 100.0 * thresholds.path_independence,
        "maximum_energy_shift_ev" => 0.101241806629,
        "rms_energy_shift_ev" => 0.101241806629,
        "nondegenerate_block_leakage" => 100.0 * thresholds.nondegenerate_block_leakage,
    )
    @test isempty(target_scope_violations(; overrides = parent_only_defects))
    full_parent_solution = target_scope_solution(; overrides = parent_only_defects)
    full_parent_violations = Base.invokelatest(
        TARGET_SCOPE_PAW._star_partition_candidate_violations,
        full_parent_solution,
        thresholds,
        TARGET_SCOPE_W.FixedGapPAWBlockPartition(),
        TARGET_SCOPE_W.NativeDFTHamiltonian(),
        false,
    )
    @test Set(getfield.(full_parent_violations, :name)) == Set(keys(parent_only_defects))
end

@testset "target Hamiltonian covariance and projected eigen residual remain hard" begin
    thresholds = TARGET_SCOPE_W.PAWGaugeThresholds()
    sewing = Matrix{ComplexF64}(I, 2, 2)
    source_hamiltonian = ComplexF64[-2.0 0.0; 0.0 -1.0]
    target_hamiltonian = copy(source_hamiltonian)
    # The normalized Frobenius metric divides this one-column defect by sqrt(2).
    # A factor of two therefore exercises all four covariance gates independently.
    target_hamiltonian[2, 2] += 2.0 * thresholds.hamiltonian_covariance_ev
    covariance = Base.invokelatest(
        TARGET_SCOPE_PAW._star_hamiltonian_residual_metrics,
        sewing,
        source_hamiltonian,
        target_hamiltonian,
        false,
    )
    @test covariance.maximum_element_ev > thresholds.hamiltonian_covariance_ev
    @test covariance.operator_ev > thresholds.hamiltonian_covariance_ev

    for (name, value) in (
        ("hamiltonian_covariance_after_ev", covariance.maximum_element_ev),
        ("hamiltonian_covariance_after_operator_ev", covariance.operator_ev),
        (
            "hamiltonian_covariance_after_source_column_l2_ev",
            covariance.maximum_source_column_l2_ev,
        ),
        (
            "hamiltonian_covariance_after_normalized_frobenius_ev",
            covariance.normalized_frobenius_ev,
        ),
    )
        violations = target_scope_violations(overrides = Dict(name => value))
        @test getfield.(violations, :name) == [name]
    end

    projected_residual = 1.25 * thresholds.projected_eigen_residual_ev
    hamiltonian = Diagonal(ComplexF64[-2.0, -1.0])
    eigenvectors = Matrix{ComplexF64}(I, 2, 2)
    reported_eigenvalues = [-2.0, -1.0 + projected_residual]
    measured_residual =
        maximum(abs, hamiltonian * eigenvectors - eigenvectors * Diagonal(reported_eigenvalues))
    @test measured_residual ≈ projected_residual
    violations = target_scope_violations(
        overrides = Dict("projected_eigen_residual_ev" => measured_residual),
    )
    @test getfield.(violations, :name) == ["projected_eigen_residual_ev"]
end

@testset "QE completed scope follows payload scope without a Sym audit" begin
    mktempdir() do directory
        fixture = write_qe_paw_fixture(
            directory;
            metric_kind = :norm_conserving,
            spinor = false,
            spinorbit = false,
        )
        source = WannierNLQG.SymmetryFoundation.QuantumEspressoWavefunctionSource(
            fixture.save_directory;
            band_range = 1:1,
            include_time_reversal = false,
        )
        gauge_hdf5 = joinpath(directory, "native-target-gauge.h5")
        backend = TARGET_SCOPE_W.StarCovariantPAWGauge(
            buffer_policy = TARGET_SCOPE_W.ClosureDrivenBandBuffer(max_extra_bands = 0),
        )
        result = TARGET_SCOPE_W.prepare_symmetry_covariant_wavefunctions(
            TARGET_SCOPE_W.SymmetryCovariantWavefunctionPreparationConfig(
                construction_policy = :strict,
                source = source,
                wavefunction_gauge_backend = backend,
                authoritative_hamiltonian = TARGET_SCOPE_W.NativeDFTHamiltonian(),
                target_subspace_contract = one_band_target_contract(),
                output_hdf5 = gauge_hdf5,
                target_band_count = 1,
            ),
        )
        @test result.status == :PASS
        @test result.authoritative_hamiltonian == "native_dft"
        @test result.target_scope_production_eligible

        restored =
            Base.invokelatest(TARGET_SCOPE_PAW._read_star_covariant_paw_gauge_hdf5, gauge_hdf5)
        @test restored.payload.qualification_scope !== nothing
        @test restored.payload.symmetrized_hamiltonian_audit === nothing
        @test restored.payload.source_metadata["qualification_scope"] == "target_subspace"
        @test restored.payload.source_metadata["authoritative_hamiltonian"] == "native_dft"

        matrices = TARGET_SCOPE_W.generate_symmetry_completed_qe_paw_matrix_elements(
            source,
            gauge_hdf5,
            fixture.nnkp_file;
            artifact_dir = joinpath(directory, "native-target-matrices"),
        )
        @test matrices.passed
        @test any(==("parent_qualification=audit_only"), matrices.diagnostics)
        HDF5.h5open(matrices.artifacts["provenance_hdf5"], "r") do handle
            attributes = HDF5.attributes(handle)
            @test String(read(attributes["qualification_scope"])) == "target_subspace"
            @test String(read(attributes["parent_qualification"])) == "audit_only"
            @test !haskey(handle, "symmetrized_hamiltonian_audit")
        end
    end
end
