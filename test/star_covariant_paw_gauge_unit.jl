using HDF5
using JSON3
using LinearAlgebra
using SHA
using Test

isdefined(Main, :QEPAWMatrixElementsTestSupport) ||
    include(joinpath(@__DIR__, "QEPAWMatrixElementsTestSupport.jl"))
using .QEPAWMatrixElementsTestSupport

const STAR_GAUGE_W = WannierNLQG.Wannierization
const STAR_GAUGE_S = WannierNLQG.Symmetrization
const STAR_GAUGE_EXTENSION = first(STAR_GAUGE_W._load_wannierization_extension!()).PAWMatrixElements
const STAR_GAUGE_SUPPORT =
    first(STAR_GAUGE_W._load_wannierization_extension!()).WannierizationInternalSupport
const STAR_GAUGE_OPERATOR_EXPORT =
    first(STAR_GAUGE_W._load_wannierization_extension!()).OperatorExport

star_gauge_test_file_sha256(path::AbstractString) =
    open(path, "r") do io
        bytes2hex(SHA.sha256(io))
    end

function star_gauge_target_contract(
    source;
    num_wannier::Int = 1,
    nkpoints::Int = 1,
    scoped_paw_thresholds::STAR_GAUGE_W.PAWGaugeThresholds = STAR_GAUGE_W.PAWGaugeThresholds(),
)
    band_count = length(something(source.band_range))
    scope = WannierNLQG.SymmetryFoundation.BandRepresentationQualificationScope(
        trues(band_count, nkpoints),
        trues(band_count, nkpoints),
    )
    return STAR_GAUGE_W.TargetSubspaceQualificationContract(
        scope;
        outer_min_ev = -18.0,
        outer_max_ev = 3.5,
        frozen_min_ev = -18.0,
        frozen_max_ev = 0.5,
        num_wannier,
        scoped_paw_thresholds,
    )
end

@testset "physical-metric band-frame transform contract" begin
    source_metric = ComplexF64[1.0 + 2.0e-6 2.0e-7im; -2.0e-7im 1.0 - 7.0e-7]
    decomposition = eigen(Hermitian(source_metric))
    transform =
        decomposition.vectors * Diagonal(inv.(sqrt.(decomposition.values))) * decomposition.vectors'
    transforms = reshape(copy(transform), 2, 2, 1)
    frozen = copy(transforms)
    audit = Base.invokelatest(
        STAR_GAUGE_EXTENSION._audit_band_frame_transforms,
        [source_metric],
        transforms,
    )
    @test audit.physical_isometry_maximum <= 1.0e-12
    @test audit.euclidean_nonunitarity_maximum > 1.0e-8
    @test audit.minimum_singular_value > 0.0
    @test audit.maximum_condition_number >= 1.0
    @test transforms == frozen # the formal contract never polar-normalizes T

    operator = ComplexF64[1.0 2.0im; -2.0im 3.0]
    other_metric = ComplexF64[1.0 - 1.1e-6 3.0e-7; 3.0e-7 1.0 + 8.0e-7]
    other_decomposition = eigen(Hermitian(other_metric))
    other_transform =
        other_decomposition.vectors *
        Diagonal(inv.(sqrt.(other_decomposition.values))) *
        other_decomposition.vectors'
    @test Base.invokelatest(
        STAR_GAUGE_EXTENSION._rotate_single_point_operator,
        operator,
        transform,
    ) ≈ transform' * operator * transform
    @test Base.invokelatest(
        STAR_GAUGE_EXTENSION._rotate_link_operator,
        operator,
        transform,
        other_transform,
    ) ≈ transform' * operator * other_transform
    @test Base.invokelatest(
        STAR_GAUGE_EXTENSION._rotate_double_endpoint_operator,
        operator,
        transform,
        other_transform,
    ) ≈ transform' * operator * other_transform

    singular = zeros(ComplexF64, 2, 2, 1)
    singular[1, 1, 1] = 1.0
    @test_throws ArgumentError Base.invokelatest(
        STAR_GAUGE_EXTENSION._audit_band_frame_transforms,
        [source_metric],
        singular,
    )
    nonfinite = copy(transforms)
    nonfinite[1, 1, 1] = ComplexF64(NaN)
    @test_throws ArgumentError Base.invokelatest(
        STAR_GAUGE_EXTENSION._audit_band_frame_transforms,
        [source_metric],
        nonfinite,
    )
    @test_throws ArgumentError Base.invokelatest(
        STAR_GAUGE_EXTENSION._audit_band_frame_transforms,
        [ComplexF64[1.0 0.0; 0.0 0.0]],
        transforms,
    )
    @test_throws ArgumentError Base.invokelatest(
        STAR_GAUGE_EXTENSION._audit_band_frame_transforms,
        [ComplexF64[1.0 0.0; 0.0 -1.0]],
        transforms,
    )
    @test_throws ArgumentError Base.invokelatest(
        STAR_GAUGE_EXTENSION._audit_band_frame_transforms,
        [ComplexF64[1.0 1.0e-4; 0.0 1.0]],
        transforms,
    )

    identity = Base.invokelatest(STAR_GAUGE_EXTENSION._identity_band_frame_contract, 2, 1)
    summary = Base.invokelatest(STAR_GAUGE_SUPPORT.band_frame_contract_summary, identity)
    @test identity.rotations === nothing
    @test identity.rotation_sha256 == identity.transform_sha256
    @test summary.schema == "WannierNLQG.band_frame_transform_contract"
    @test summary.status == "PASS"
end

@testset "star-covariant PAW gauge expert contract" begin
    buffer = STAR_GAUGE_W.ClosureDrivenBandBuffer()
    thresholds = STAR_GAUGE_W.PAWGaugeThresholds()
    @test buffer.cluster_tolerance_ev == 5.0e-3
    @test buffer.hard_energy_cap_ev == 0.10
    @test buffer.max_extra_bands == 8
    @test thresholds.hamiltonian_covariance_ev == 1.0e-7
    @test thresholds.maximum_energy_shift_ev == 1.0e-6
    @test thresholds.rms_energy_shift_ev == 3.0e-7
    symmetrized_authority = STAR_GAUGE_W.SymmetrizedDFTHamiltonian()
    @test symmetrized_authority.maximum_energy_shift_audit_reference_ev == 5.0e-6
    @test symmetrized_authority.rms_energy_shift_audit_reference_ev == 1.0e-6
    @test symmetrized_authority.residual_gate_phase == :post_symmetrization
    @test symmetrized_authority.native_difference_qualification == :audit_only
    @test symmetrized_authority.qualification_scope == :target_subspace
    @test symmetrized_authority.target_anchor == :completed_symmetrized_target
    @test symmetrized_authority.auxiliary_parent_qualification == :audit_only
    @test symmetrized_authority.completion.target_complement_max_element_ev == 5.0e-6
    @test_throws ArgumentError STAR_GAUGE_W.FrozenTargetComplementCompletion(
        target_complement_max_element_ev = 0.0,
    )
    @test_throws ArgumentError STAR_GAUGE_W.SymmetrizedDFTHamiltonian(
        residual_gate_phase = :pre_symmetrization,
    )
    @test_throws ArgumentError STAR_GAUGE_W.SymmetrizedDFTHamiltonian(
        native_difference_qualification = :hard_gate,
    )
    @test_throws ArgumentError STAR_GAUGE_W.SymmetrizedDFTHamiltonian(
        maximum_energy_shift_audit_reference_ev = 0.0,
    )
    @test_throws ArgumentError STAR_GAUGE_W.SymmetrizedDFTHamiltonian(
        rms_energy_shift_audit_reference_ev = Inf,
    )
    @test_throws ArgumentError STAR_GAUGE_W.ClosureDrivenBandBuffer(max_extra_bands = -1)
    @test_throws ArgumentError STAR_GAUGE_W.PAWGaugeThresholds(group_law = 0.0)
    fixed = STAR_GAUGE_W.FixedGapPAWBlockPartition()
    adaptive = STAR_GAUGE_W.AdaptiveEvidencePAWBlockPartition()
    weighted = STAR_GAUGE_W.HamiltonianWeightedPAWBlockPartition()
    @test fixed.max_gap_ev == thresholds.block_merge_max_gap_ev
    @test adaptive.soft_gap_ev == 0.020
    @test adaptive.hard_edge_gap_ev == 0.100
    @test adaptive.hard_component_span_ev == 0.100
    @test adaptive.max_component_bands == 12
    @test adaptive.max_search_states == 512
    @test weighted.near_gap_ev == 0.020
    @test weighted.hard_component_span_ev == 0.100
    @test weighted.max_component_bands == 12
    @test weighted.residual_thresholds.pair_ev == 5.0e-6
    @test weighted.residual_thresholds.operator_ev == 5.0e-6
    @test weighted.residual_thresholds.source_column_l2_ev == 5.0e-6
    @test weighted.residual_thresholds.normalized_frobenius_ev == 5.0e-6
    @test weighted.cancellation_thresholds.bigfloat_precision_bits == 256
    @test weighted.pre_gauge_cumulative_mode == :diagnostic
    @test STAR_GAUGE_W.StarCovariantPAWGauge().hamiltonian_correction isa
          STAR_GAUGE_W.NoDiscreteHamiltonianCorrection
    correction = STAR_GAUGE_W.FarBandCovarianceCorrection()
    @test correction.qualification_mode == :strict
    @test correction.thresholds.far_rotation_operator == 5.0e-4
    @test correction.thresholds.hamiltonian_correction_operator_ev == 1.0e-5
    @test_throws ArgumentError STAR_GAUGE_W.StarCovariantPAWGauge(
        hamiltonian_correction = correction,
    )
    controlled = STAR_GAUGE_W.StarCovariantPAWGauge(
        block_partition_policy = weighted,
        hamiltonian_correction = correction,
    )
    @test controlled.hamiltonian_correction === correction
    raw_precontrol_gate = STAR_GAUGE_EXTENSION._star_raw_target_precontrol_gate
    for metric in (
        "raw_target_reconstruction_leakage_weight",
        "raw_target_state_leakage_weight",
        "raw_target_to_complement_leakage_weight",
        "raw_complement_to_target_leakage_weight",
        "raw_target_left_unitarity",
        "raw_target_right_unitarity",
        "raw_frozen_left_unitarity",
        "raw_frozen_right_unitarity",
        "raw_target_normalized_polar_correction",
    )
        @test Base.invokelatest(
            raw_precontrol_gate,
            STAR_GAUGE_W.SymmetrizedDFTHamiltonian(),
            correction,
            metric,
            nextfloat(5.0e-6),
            5.0e-6,
        ) == :CONTROLLED_PRE_SYMMETRIZATION_AUDIT
    end
    @test Base.invokelatest(
        raw_precontrol_gate,
        STAR_GAUGE_W.SymmetrizedDFTHamiltonian(),
        correction,
        "raw_target_reconstruction_leakage_weight",
        1.0e-7,
        5.0e-6,
    ) == :PASS
    @test_throws ArgumentError Base.invokelatest(
        raw_precontrol_gate,
        STAR_GAUGE_W.NativeDFTHamiltonian(),
        correction,
        "raw_target_reconstruction_leakage_weight",
        nextfloat(5.0e-6),
        5.0e-6,
    )
    @test_throws ArgumentError Base.invokelatest(
        raw_precontrol_gate,
        STAR_GAUGE_W.SymmetrizedDFTHamiltonian(),
        STAR_GAUGE_W.NoDiscreteHamiltonianCorrection(),
        "raw_target_reconstruction_leakage_weight",
        nextfloat(5.0e-6),
        5.0e-6,
    )
    @test_throws ArgumentError Base.invokelatest(
        raw_precontrol_gate,
        STAR_GAUGE_W.SymmetrizedDFTHamiltonian(),
        correction,
        "raw_target_to_complement_leakage_weight",
        Inf,
        5.0e-6,
    )
    @test STAR_GAUGE_W.FarBandCovarianceCorrection(qualification_mode = :diagnostic_only).qualification_mode ==
          :diagnostic_only
    @test_throws ArgumentError STAR_GAUGE_W.PAWHamiltonianResidualThresholds(pair_ev = 0.0)
    @test_throws ArgumentError STAR_GAUGE_W.PAWCancellationStabilityThresholds(
        bigfloat_precision_bits = 64,
    )
    @test STAR_GAUGE_W.StarCovariantPAWGauge().block_partition_policy isa
          STAR_GAUGE_W.FixedGapPAWBlockPartition
    @test STAR_GAUGE_W.StarCovariantPAWGauge(block_partition_policy = adaptive).block_partition_policy ===
          adaptive
    @test_throws ArgumentError STAR_GAUGE_W.StarCovariantPAWGauge(
        thresholds = STAR_GAUGE_W.PAWGaugeThresholds(block_merge_max_gap_ev = 0.05),
        block_partition_policy = adaptive,
    )

    preparation = STAR_GAUGE_W.BandRepresentationPreparationConfig(
        construction_policy = :strict,
        source = WannierNLQG.SymmetryFoundation.QuantumEspressoWavefunctionSource(
            "fixture.save";
            band_range = 1:1,
        ),
        win_file = "fixture.win",
        eig_file = "fixture.eig",
    )
    @test preparation.wavefunction_gauge_backend isa STAR_GAUGE_W.NativeEigenstateGauge
    @test preparation.wavefunction_gauge_hdf5 === nothing
    @test preparation.authoritative_hamiltonian isa STAR_GAUGE_W.NativeDFTHamiltonian
    mismatched = STAR_GAUGE_W.BandRepresentationPreparationConfig(
        construction_policy = :strict,
        source = preparation.source,
        sewing_backend = STAR_GAUGE_W.CoefficientMappingSewing(),
        wavefunction_gauge_backend = STAR_GAUGE_W.StarCovariantPAWGauge(),
        wavefunction_gauge_hdf5 = "fixture.h5",
        win_file = "fixture.win",
        eig_file = "fixture.eig",
    )
    @test_throws ArgumentError STAR_GAUGE_W._validate_band_representation_preparation_config(
        mismatched,
    )
    symmetrized = STAR_GAUGE_W.BandRepresentationPreparationConfig(
        construction_policy = :strict,
        source = preparation.source,
        sewing_backend = STAR_GAUGE_W.AugmentationAwareSewing(),
        wavefunction_gauge_backend = controlled,
        authoritative_hamiltonian = STAR_GAUGE_W.SymmetrizedDFTHamiltonian(),
        wavefunction_gauge_hdf5 = "fixture.h5",
        win_file = "fixture.win",
        eig_file = "fixture.eig",
    )
    @test STAR_GAUGE_W._validate_band_representation_preparation_config(symmetrized) === nothing
    invalid_authority = STAR_GAUGE_W.BandRepresentationPreparationConfig(
        construction_policy = :strict,
        source = preparation.source,
        sewing_backend = STAR_GAUGE_W.AugmentationAwareSewing(),
        wavefunction_gauge_backend = STAR_GAUGE_W.StarCovariantPAWGauge(
            block_partition_policy = weighted,
        ),
        authoritative_hamiltonian = STAR_GAUGE_W.SymmetrizedDFTHamiltonian(),
        wavefunction_gauge_hdf5 = "fixture.h5",
        win_file = "fixture.win",
        eig_file = "fixture.eig",
    )
    @test_throws ArgumentError STAR_GAUGE_W._validate_band_representation_preparation_config(
        invalid_authority,
    )
    selected_config = STAR_GAUGE_W.SymmetryCovariantWavefunctionPreparationConfig(
        construction_policy = :strict,
        source = preparation.source,
        output_hdf5 = "selected.h5",
        target_band_count = 1,
        selected_star_indices = [1, 8, 19, 36],
    )
    @test STAR_GAUGE_W._validate_symmetry_covariant_wavefunction_preparation_config(
        selected_config,
    ) === nothing
    @test_throws ArgumentError STAR_GAUGE_W._validate_symmetry_covariant_wavefunction_preparation_config(
        STAR_GAUGE_W.SymmetryCovariantWavefunctionPreparationConfig(
            construction_policy = :strict,
            source = preparation.source,
            output_hdf5 = "ambiguous-selected.h5",
            target_band_count = 1,
            maximum_star_count = 1,
            selected_star_indices = [1],
        ),
    )
    @test_throws ArgumentError STAR_GAUGE_W._validate_symmetry_covariant_wavefunction_preparation_config(
        STAR_GAUGE_W.SymmetryCovariantWavefunctionPreparationConfig(
            construction_policy = :strict,
            source = preparation.source,
            output_hdf5 = "unsorted-selected.h5",
            target_band_count = 1,
            selected_star_indices = [8, 1],
        ),
    )
    scoped_thresholds = STAR_GAUGE_W.PAWGaugeThresholds(wfc_rotation_reconstruction = 1.0e-8)
    scoped_gauge = STAR_GAUGE_W.StarCovariantPAWGauge(
        thresholds = scoped_thresholds,
        block_partition_policy = weighted,
        hamiltonian_correction = correction,
    )
    scoped_contract =
        star_gauge_target_contract(preparation.source; scoped_paw_thresholds = scoped_thresholds)
    scoped_config = STAR_GAUGE_W.SymmetryCovariantWavefunctionPreparationConfig(
        construction_policy = :strict,
        source = preparation.source,
        wavefunction_gauge_backend = scoped_gauge,
        authoritative_hamiltonian = STAR_GAUGE_W.SymmetrizedDFTHamiltonian(),
        target_subspace_contract = scoped_contract,
        output_hdf5 = "scoped-thresholds.h5",
        target_band_count = 1,
    )
    @test STAR_GAUGE_W._validate_symmetry_covariant_wavefunction_preparation_config(
        scoped_config,
    ) === nothing
    @test_throws ArgumentError STAR_GAUGE_W._validate_symmetry_covariant_wavefunction_preparation_config(
        STAR_GAUGE_W.SymmetryCovariantWavefunctionPreparationConfig(
            construction_policy = :strict,
            source = preparation.source,
            wavefunction_gauge_backend = controlled,
            authoritative_hamiltonian = STAR_GAUGE_W.SymmetrizedDFTHamiltonian(),
            target_subspace_contract = scoped_contract,
            output_hdf5 = "mismatched-scoped-thresholds.h5",
            target_band_count = 1,
        ),
    )
    leakage_thresholds = STAR_GAUGE_W.PAWGaugeThresholds(target_leakage_weight = 4.0e-6)
    leakage_contract =
        star_gauge_target_contract(preparation.source; scoped_paw_thresholds = leakage_thresholds)
    @test_throws ArgumentError STAR_GAUGE_W._validate_symmetry_covariant_wavefunction_preparation_config(
        STAR_GAUGE_W.SymmetryCovariantWavefunctionPreparationConfig(
            construction_policy = :strict,
            source = preparation.source,
            wavefunction_gauge_backend = STAR_GAUGE_W.StarCovariantPAWGauge(
                thresholds = leakage_thresholds,
                block_partition_policy = weighted,
                hamiltonian_correction = correction,
            ),
            authoritative_hamiltonian = STAR_GAUGE_W.SymmetrizedDFTHamiltonian(),
            target_subspace_contract = leakage_contract,
            output_hdf5 = "mismatched-sewing-leakage-threshold.h5",
            target_band_count = 1,
        ),
    )
end

@testset "ragged target authority and formal Reynolds field" begin
    extension =
        first(STAR_GAUGE_W._load_wannierization_extension!()).PAWMatrixElements.PAWMatrixElements
    outer = BitMatrix([
        true true
        true true
        false false
        false false
    ])
    frozen = BitMatrix([
        true true
        false false
        false false
        false false
    ])
    contract = STAR_GAUGE_W.TargetSubspaceQualificationContract(
        WannierNLQG.SymmetryFoundation.BandRepresentationQualificationScope(outer, frozen);
        outer_min_ev = -18.0,
        outer_max_ev = 3.5,
        frozen_min_ev = -18.0,
        frozen_max_ev = 0.5,
        num_wannier = 1,
    )
    indices = Base.invokelatest(extension._star_target_indices_by_kpoint, contract, [1, 2], 1:4)
    @test indices == Dict(1 => [1, 2], 2 => [1, 2])

    mismatched_outer = copy(outer)
    mismatched_outer[2, 2] = false
    mismatched_contract = STAR_GAUGE_W.TargetSubspaceQualificationContract(
        WannierNLQG.SymmetryFoundation.BandRepresentationQualificationScope(
            mismatched_outer,
            frozen,
        );
        outer_min_ev = -18.0,
        outer_max_ev = 3.5,
        frozen_min_ev = -18.0,
        frozen_max_ev = 0.5,
        num_wannier = 1,
    )
    @test_throws ArgumentError Base.invokelatest(
        extension._star_target_indices_by_kpoint,
        mismatched_contract,
        [1, 2],
        1:4,
    )

    identity_operation = WannierNLQG.SymmetryFoundation.SymmetryOperation(
        Matrix{Int}(I, 3, 3),
        zeros(3),
        Matrix{Float64}(I, 3, 3),
        false,
    )
    swap_operation = WannierNLQG.SymmetryFoundation.SymmetryOperation(
        Matrix{Int}(I, 3, 3),
        zeros(3),
        Matrix{Float64}(I, 3, 3),
        false,
    )
    operations = [identity_operation, swap_operation]
    kpoint_map = [1 2; 2 1]
    swap = ComplexF64[0 1; 1 0]
    actions = Dict(
        (1, 1) => Matrix{ComplexF64}(I, 2, 2),
        (2, 1) => Matrix{ComplexF64}(I, 2, 2),
        (1, 2) => swap,
        (2, 2) => swap,
    )
    native_field =
        Dict(1 => ComplexF64[0.0 0.03im; -0.03im 1.0], 2 => ComplexF64[1.01 -0.02im; 0.02im -0.01])
    projected, iterations, residual, _ = Base.invokelatest(
        extension._star_formal_target_reynolds_field,
        native_field,
        actions,
        operations,
        kpoint_map,
        1.0e-12,
    )
    @test iterations > 0
    @test residual <= 1.0e-12
    @test maximum(abs, projected[2] * swap - swap * projected[1]) <= 1.0e-12

    antiunitary_swap = WannierNLQG.SymmetryFoundation.SymmetryOperation(
        Matrix{Int}(I, 3, 3),
        zeros(3),
        Matrix{Float64}(I, 3, 3),
        true,
    )
    antiunitary_operations = [identity_operation, antiunitary_swap]
    antiunitary_action = ComplexF64[0 1; -1 0]
    antiunitary_actions =
        merge(actions, Dict((1, 2) => antiunitary_action, (2, 2) => antiunitary_action))
    antiunitary_native =
        Dict(1 => ComplexF64[0.0 0.04im; -0.04im 1.0], 2 => ComplexF64[1.02 0.01im; -0.01im -0.02])
    antiunitary_projected, _, antiunitary_residual, _ = Base.invokelatest(
        extension._star_formal_target_reynolds_field,
        antiunitary_native,
        antiunitary_actions,
        antiunitary_operations,
        kpoint_map,
        1.0e-12,
    )
    @test antiunitary_residual <= 1.0e-12
    @test maximum(
        abs,
        antiunitary_projected[2] * antiunitary_action -
        antiunitary_action * conj(antiunitary_projected[1]),
    ) <= 1.0e-12
end

@testset "formal target group/corepresentation projection" begin
    extension =
        first(STAR_GAUGE_W._load_wannierization_extension!()).PAWMatrixElements.PAWMatrixElements
    lattice = Matrix{Float64}(I, 3, 3)
    structure = WannierNLQG.SymmetryFoundation.CrystalStructure(lattice, ["X"], zeros(3, 1))

    rotations = [diagm([1, 1, 1]), diagm([-1, -1, 1]), diagm([-1, 1, 1]), diagm([1, -1, 1])]
    gamma_operations = WannierNLQG.SymmetryFoundation.SymmetryOperation[]
    for antiunitary in (false, true), rotation in rotations
        push!(
            gamma_operations,
            WannierNLQG.SymmetryFoundation.SymmetryOperation(
                rotation,
                zeros(3),
                Float64.(rotation),
                antiunitary,
            ),
        )
    end
    gamma_table = STAR_GAUGE_W._build_representation_product_table(
        gamma_operations,
        true;
        tolerance = 1.0e-12,
    )
    gamma_dimension = 42
    gamma_point = Base.invokelatest(
        WannierNLQG.SymmetryFoundation.PlaneWaveKPoint,
        zeros(3),
        zeros(Int, 1, 3),
        ones(ComplexF64, gamma_dimension, 1, 2),
        zeros(gamma_dimension);
        normalize_coefficients = false,
    )
    gamma_native = Base.invokelatest(
        WannierNLQG.SymmetryFoundation.NativeWavefunctionData,
        :fixture,
        structure,
        2pi .* lattice,
        (1, 1, 1),
        true,
        [gamma_point],
        Dict{String, String}(),
    )
    gamma_kpoint_map = ones(Int, length(gamma_operations), 1)
    gamma_reciprocal_shifts = zeros(Int, 3, length(gamma_operations), 1)
    gamma_raw_actions = Dict{Tuple{Int, Int}, Matrix{ComplexF64}}()
    for operation_index in eachindex(gamma_operations)
        exact = kron(
            Matrix{ComplexF64}(I, gamma_dimension ÷ 2, gamma_dimension ÷ 2),
            gamma_table.spin_actions[:, :, operation_index],
        )
        perturbation = Diagonal(cis.(1.0e-8 .* operation_index .* collect(1:gamma_dimension)))
        gamma_raw_actions[(1, operation_index)] = exact * perturbation
    end
    gamma_formal = Base.invokelatest(
        extension._star_project_formal_target_actions,
        gamma_raw_actions,
        gamma_native,
        [1],
        gamma_operations,
        gamma_kpoint_map;
        raw_group_tolerance = 2.0e-5,
        formal_tolerance = 1.0e-12,
        correction_tolerance = 5.0e-6,
    )
    @test gamma_formal.initial.maximum > 1.0e-12
    @test gamma_formal.initial.maximum <= 2.0e-5
    @test gamma_formal.residual.maximum <= 1.0e-12
    @test gamma_formal.residual.corepresentation <= 1.0e-12
    @test gamma_formal.residual.theta_squared <= 1.0e-12
    @test gamma_formal.residual.kramers <= 1.0e-12
    @test gamma_formal.correction <= 5.0e-6
    @test gamma_formal.iterations <= 16
    @test size(gamma_formal.actions[(1, 1)]) == (42, 42)

    gamma_analytic = Base.invokelatest(
        extension._star_validate_formal_target_actions_analytic,
        gamma_formal.actions,
        gamma_native,
        [1],
        gamma_operations,
        gamma_kpoint_map,
        gamma_reciprocal_shifts,
        1.0e-10,
    )
    @test gamma_analytic.maximum_group_law <= 1.0e-10
    @test gamma_analytic.reciprocal_shift <= 1.0e-10
    @test gamma_analytic.theta_squared <= 1.0e-10
    @test gamma_analytic.kramers <= 1.0e-10
    @test gamma_analytic.required_block_unitarity <= 1.0e-10
    @test occursin(r"^[0-9a-f]{64}$", gamma_analytic.representation_sha256)

    dense = reshape(
        ComplexF64.(sin.(collect(1:(gamma_dimension ^ 2)))),
        gamma_dimension,
        gamma_dimension,
    )
    gamma_native_field = Dict(
        1 => Matrix(
            Hermitian(
                Diagonal(collect(range(-2.0, 2.0; length = gamma_dimension))) .+
                1.0e-3 .* (dense + dense'),
            ),
        ),
    )
    gamma_reynolds = Base.invokelatest(
        extension._star_formal_target_reynolds_projection,
        gamma_native_field,
        gamma_formal.actions,
        gamma_operations,
        gamma_kpoint_map,
        1.0e-10,
    )
    @test gamma_reynolds.covariance_residual_ev <= 1.0e-10
    @test gamma_reynolds.idempotence_ev <= 1.0e-10

    identity_rotation = Matrix{Int}(I, 3, 3)
    glide_rotation = diagm([1, -1, 1])
    glide_operations = [
        WannierNLQG.SymmetryFoundation.SymmetryOperation(
            identity_rotation,
            zeros(3),
            Float64.(identity_rotation),
            false,
        ),
        WannierNLQG.SymmetryFoundation.SymmetryOperation(
            glide_rotation,
            [0.5, 0.0, 0.0],
            Float64.(glide_rotation),
            false,
        ),
    ]
    glide_kpoints = ([0.25, 0.25, 0.0], [0.25, -0.25, 0.0])
    glide_points = [
        Base.invokelatest(
            WannierNLQG.SymmetryFoundation.PlaneWaveKPoint,
            kpoint,
            zeros(Int, 1, 3),
            ones(ComplexF64, 2, 1, 1),
            zeros(2);
            normalize_coefficients = false,
        ) for kpoint in glide_kpoints
    ]
    glide_native = Base.invokelatest(
        WannierNLQG.SymmetryFoundation.NativeWavefunctionData,
        :fixture,
        structure,
        2pi .* lattice,
        (2, 1, 1),
        false,
        glide_points,
        Dict{String, String}(),
    )
    glide_kpoint_map = [1 2; 2 1]
    glide_reciprocal_shifts = zeros(Int, 3, 2, 2)
    glide_phase = cis(-pi / 4)
    glide_exact_actions = Dict(
        (1, 1) => Matrix{ComplexF64}(I, 2, 2),
        (2, 1) => Matrix{ComplexF64}(I, 2, 2),
        (1, 2) => glide_phase .* Matrix{ComplexF64}(I, 2, 2),
        (2, 2) => glide_phase .* Matrix{ComplexF64}(I, 2, 2),
    )
    glide_raw_actions = Dict(
        key => value * Diagonal(cis.(1.0e-8 .* (key[1] + 2key[2]) .* (1:2))) for
        (key, value) in glide_exact_actions
    )
    glide_formal = Base.invokelatest(
        extension._star_project_formal_target_actions,
        glide_raw_actions,
        glide_native,
        [1, 2],
        glide_operations,
        glide_kpoint_map;
        raw_group_tolerance = 2.0e-5,
        formal_tolerance = 1.0e-12,
        correction_tolerance = 5.0e-6,
    )
    @test glide_formal.initial.maximum > 1.0e-12
    @test glide_formal.residual.maximum <= 1.0e-12
    @test glide_formal.correction <= 5.0e-6
    glide_analytic = Base.invokelatest(
        extension._star_validate_formal_target_actions_analytic,
        glide_formal.actions,
        glide_native,
        [1, 2],
        glide_operations,
        glide_kpoint_map,
        glide_reciprocal_shifts,
        1.0e-10,
    )
    @test glide_analytic.maximum_group_law <= 1.0e-10
    @test glide_analytic.reciprocal_shift <= 1.0e-10
    glide_reynolds = Base.invokelatest(
        extension._star_formal_target_reynolds_projection,
        Dict(1 => ComplexF64[0.0 0.02im; -0.02im 1.0], 2 => ComplexF64[1.1 0.03; 0.03 -0.1]),
        glide_formal.actions,
        glide_operations,
        glide_kpoint_map,
        1.0e-10,
    )
    @test glide_reynolds.covariance_residual_ev <= 1.0e-10
    @test glide_reynolds.idempotence_ev <= 1.0e-10

    grossly_inconsistent = Dict(key => copy(value) for (key, value) in gamma_raw_actions)
    grossly_inconsistent[(1, 2)] *= cis(1.0e-3)
    raw_group_error = try
        Base.invokelatest(
            extension._star_project_formal_target_actions,
            grossly_inconsistent,
            gamma_native,
            [1],
            gamma_operations,
            gamma_kpoint_map;
            raw_group_tolerance = 2.0e-5,
            formal_tolerance = 1.0e-12,
            correction_tolerance = 5.0e-6,
        )
        nothing
    catch error
        error
    end
    @test raw_group_error isa ArgumentError
    @test occursin("FORMAL_TARGET_RAW_GROUP_LAW_HOLD", sprint(showerror, raw_group_error))
    correction_error = try
        Base.invokelatest(
            extension._star_project_formal_target_actions,
            gamma_raw_actions,
            gamma_native,
            [1],
            gamma_operations,
            gamma_kpoint_map;
            raw_group_tolerance = 2.0e-5,
            formal_tolerance = 1.0e-12,
            correction_tolerance = 1.0e-14,
        )
        nothing
    catch error
        error
    end
    @test correction_error isa ArgumentError
    @test occursin("FORMAL_TARGET_ACTION_CORRECTION_HOLD", sprint(showerror, correction_error))
    @test Base.invokelatest(extension._star_root_cause, raw_group_error) ==
          :FORMAL_TARGET_RAW_GROUP_LAW_HOLD
    @test Base.invokelatest(extension._star_root_cause, correction_error) ==
          :FORMAL_TARGET_ACTION_CORRECTION_HOLD
end

@testset "Hamiltonian covariance source-target argument order" begin
    extension =
        first(STAR_GAUGE_W._load_wannierization_extension!()).PAWMatrixElements.PAWMatrixElements
    sewing = ComplexF64[0 1; 1 0]
    source = ComplexF64[0 0; 0 2]
    target = ComplexF64[1 0; 0 4]
    metrics = Base.invokelatest(
        extension._star_hamiltonian_residual_metrics,
        sewing,
        source,
        target,
        false,
    )
    expected = target * sewing - sewing * source
    reversed = source * sewing - sewing * target
    @test metrics.residual == expected
    @test metrics.residual != reversed
end

@testset "frozen target and complement-only completion oracle" begin
    extension =
        first(STAR_GAUGE_W._load_wannierization_extension!()).PAWMatrixElements.PAWMatrixElements
    target_values = [0.0, 1.0e-3]
    target_vectors = Matrix{ComplexF64}(I, 4, 4)[:, 1:2]
    hamiltonian = ComplexF64[
        0.0 0.0 0.0 0.0
        0.0 1.0e-3 0.0 0.0
        0.0 0.0 0.2 1.0e-4im
        0.0 0.0 -1.0e-4im 0.3
    ]
    identity_operation = WannierNLQG.SymmetryFoundation.SymmetryOperation(
        Matrix{Int}(I, 3, 3),
        zeros(3),
        Matrix{Float64}(I, 3, 3),
        false,
    )
    context = (
        workspace = 1:4,
        target_indices = 1:2,
        hamiltonian_average = hamiltonian,
        star_index = 1,
        representative = 1,
        gauge = STAR_GAUGE_W.StarCovariantPAWGauge(),
        selected_raw = [Matrix{ComplexF64}(I, 4, 4)],
        transports = [(target_kpoint = 1,)],
        operations = [identity_operation],
    )
    authority = STAR_GAUGE_W.SymmetrizedDFTHamiltonian()
    completion = Base.invokelatest(
        extension._star_frozen_target_complement_eigenpair,
        target_values,
        target_vectors,
        context,
        authority,
    )
    @test completion.vectors[:, 1:2] == target_vectors
    @test completion.values[1:2] == target_values
    @test completion.maxima["target_anchor_wfc_maximum_drift"] == 0.0
    @test completion.maxima["target_anchor_energy_maximum_drift_ev"] == 0.0
    @test completion.maxima["target_complement_maximum_element_ev"] == 0.0
    @test maximum(abs, completion.vectors' * completion.vectors - I) <= 1.0e-12
    @test maximum(
        abs,
        hamiltonian * completion.vectors[:, 3:4] -
        completion.vectors[:, 3:4] * Diagonal(completion.values[3:4]),
    ) <= 1.0e-12

    coupled = copy(hamiltonian)
    coupled[1, 3] = coupled[3, 1] = 5.1e-6
    coupled_context = merge(context, (hamiltonian_average = coupled,))
    @test_throws ArgumentError Base.invokelatest(
        extension._star_frozen_target_complement_eigenpair,
        target_values,
        target_vectors,
        coupled_context,
        authority,
    )
end

@testset "symmetrized target eigenpair ignores parent partitions" begin
    extension =
        first(STAR_GAUGE_W._load_wannierization_extension!()).PAWMatrixElements.PAWMatrixElements
    target_indices = [1, 2, 3, 4]
    hamiltonian = Matrix{ComplexF64}(Diagonal([0.0, 2.0e-3, 0.2, 0.3, 0.7, 0.9]))
    hamiltonian[2, 3] = hamiltonian[3, 2] = 2.0e-4
    split_blocks = [[1, 2, 5], [3, 4, 6]]
    merged_blocks = [[1, 2, 3, 4], [5, 6]]
    split = Base.invokelatest(
        extension._star_symmetrized_target_eigenpair,
        hamiltonian,
        target_indices,
        split_blocks,
        5.0e-3,
    )
    merged = Base.invokelatest(
        extension._star_symmetrized_target_eigenpair,
        hamiltonian,
        target_indices,
        merged_blocks,
        5.0e-3,
    )
    for result in (split, merged)
        @test result.maxima["authoritative_target_eigensolver_residual_ev"] <= 1.0e-12
        @test maximum(
            abs,
            hamiltonian * result.vectors - result.vectors * Diagonal(result.values),
        ) <= 1.0e-12
        @test maximum(abs, result.vectors' * result.vectors - I) <= 1.0e-12
    end
    @test split.values ≈ merged.values atol = 1.0e-14 rtol = 0.0
    @test split.vectors * split.vectors' ≈ merged.vectors * merged.vectors' atol = 1.0e-14 rtol =
        0.0
    @test split.maxima["legacy_parent_partition_target_offblock_maximum_element_ev"] ≈ 2.0e-4
    @test split.maxima["legacy_parent_partition_target_offblock_operator_ev"] > 5.0e-6
    @test merged.maxima["legacy_parent_partition_target_offblock_operator_ev"] == 0.0

    legacy_values = zeros(Float64, 6)
    legacy_vectors = zeros(ComplexF64, 6, 6)
    for block in split_blocks
        decomposition = eigen(Hermitian(hamiltonian[block, block]))
        legacy_values[block] .= decomposition.values
        legacy_vectors[block, block] .= decomposition.vectors
    end
    @test maximum(abs, hamiltonian * legacy_vectors - legacy_vectors * Diagonal(legacy_values)) >
          5.0e-6

    mixing = ComplexF64[cos(0.37) -sin(0.37); sin(0.37) cos(0.37)]
    near_hamiltonian = zeros(ComplexF64, 4, 4)
    near_hamiltonian[1:2, 1:2] .= mixing * Diagonal([0.0, 1.0e-4]) * mixing'
    near_hamiltonian[3, 3] = 0.4
    near_hamiltonian[4, 4] = 0.6
    near = Base.invokelatest(
        extension._star_symmetrized_target_eigenpair,
        near_hamiltonian,
        [1, 2],
        [[1, 2], [3, 4]],
        5.0e-3,
    )
    @test near.maxima["authoritative_target_eigensolver_residual_ev"] <= 1.0e-12
    legacy_decomposition = eigen(Hermitian(near_hamiltonian[1:2, 1:2]))
    legacy_near_vectors = zeros(ComplexF64, 4, 2)
    legacy_near_vectors[1:2, :] .= legacy_decomposition.vectors
    legacy_near_values = Vector{Float64}(legacy_decomposition.values)
    Base.invokelatest(
        extension._star_canonicalize_eigenvectors!,
        legacy_near_vectors,
        legacy_near_values,
        5.0e-3,
    )
    @test maximum(
        abs,
        near_hamiltonian * legacy_near_vectors - legacy_near_vectors * Diagonal(legacy_near_values),
    ) > 5.0e-6

    degenerate_hamiltonian = Matrix{ComplexF64}(Diagonal([0.0, 0.0, 0.2, 0.2]))
    unitary = ComplexF64[0 1 0 0; 1 0 0 0; 0 0 0 1; 0 0 1 0]
    antiunitary = ComplexF64[0 -1 0 0; 1 0 0 0; 0 0 0 -1; 0 0 1 0]
    @test Base.invokelatest(
        extension._star_target_hamiltonian_pushforward,
        unitary,
        degenerate_hamiltonian,
        false,
    ) == degenerate_hamiltonian
    @test Base.invokelatest(
        extension._star_target_hamiltonian_pushforward,
        antiunitary,
        degenerate_hamiltonian,
        true,
    ) == degenerate_hamiltonian

    source_target = ComplexF64[
        1 0
        0 1
        0 0
        0 0
    ]
    source_values = [0.0, 4.0e-4]
    formal_antiunitary = ComplexF64[0 -1; 1 0]
    target_local = Base.invokelatest(
        extension._star_target_hamiltonian_pushforward,
        formal_antiunitary,
        Matrix{ComplexF64}(Diagonal(source_values)),
        true,
    )
    target_hamiltonian = zeros(ComplexF64, 4, 4)
    target_hamiltonian[2:3, 2:3] .= target_local
    target_hamiltonian[1, 1] = 0.8
    target_hamiltonian[4, 4] = 1.2
    transported = Base.invokelatest(
        extension._star_transport_symmetrized_target_eigenpair,
        source_target,
        [1, 2],
        [2, 3],
        formal_antiunitary,
        true,
        target_hamiltonian,
        source_values,
    )
    @test transported.residual_ev <= 1.0e-12
    @test transported.isometry <= 1.0e-12
    @test maximum(
        abs,
        target_hamiltonian * transported.vectors -
        transported.vectors * Diagonal(transported.values),
    ) <= 1.0e-12

    raw_parent_action = ComplexF64[
        0 0 -1 0
        sqrt(1 - 1.0e-6) 0 0 -1.0e-3
        0 1 0 0
        1.0e-3 0 0 sqrt(1 - 1.0e-6)
    ]
    raw_transported = raw_parent_action * conj(source_target)
    @test maximum(
        abs,
        target_hamiltonian * raw_transported - raw_transported * Diagonal(source_values),
    ) > 5.0e-6
    @test maximum(abs, raw_transported[[1, 4], :]) > 5.0e-6

    identity_operation = WannierNLQG.SymmetryFoundation.SymmetryOperation(
        Matrix{Int}(I, 3, 3),
        zeros(3),
        Matrix{Float64}(I, 3, 3),
        false,
    )
    target_context = (
        workspace = 1:4,
        target_indices = [2, 3],
        hamiltonian_average = target_hamiltonian,
        star_index = 2,
        representative = 14,
        gauge = STAR_GAUGE_W.StarCovariantPAWGauge(),
        selected_raw = [Matrix{ComplexF64}(I, 4, 4)],
        transports = [(target_kpoint = 14,)],
        operations = [identity_operation],
    )
    target_completion = Base.invokelatest(
        extension._star_frozen_target_complement_eigenpair,
        transported.values,
        transported.vectors,
        target_context,
        STAR_GAUGE_W.SymmetrizedDFTHamiltonian();
        fix_complement_kramers = false,
    )
    @test target_completion.vectors[:, [2, 3]] == transported.vectors
    @test target_completion.maxima["target_anchor_wfc_maximum_drift"] == 0.0
    @test target_completion.maxima["target_complement_maximum_element_ev"] <= 1.0e-12
    @test maximum(abs, target_completion.vectors' * target_completion.vectors - I) <= 1.0e-12

    shifted_complement_hamiltonian = copy(target_hamiltonian)
    shifted_complement_hamiltonian[1, 1] = 1.7
    shifted_complement_hamiltonian[4, 4] = 2.3
    shifted_complement_hamiltonian[1, 4] = 0.15
    shifted_complement_hamiltonian[4, 1] = 0.15
    shifted_target_context = merge(
        target_context,
        (hamiltonian_average = shifted_complement_hamiltonian, representative = 15),
    )
    shifted_target_completion = Base.invokelatest(
        extension._star_frozen_target_complement_eigenpair,
        transported.values,
        transported.vectors,
        shifted_target_context,
        STAR_GAUGE_W.SymmetrizedDFTHamiltonian();
        fix_complement_kramers = false,
    )
    @test shifted_target_completion.values[[2, 3]] == target_completion.values[[2, 3]]
    @test shifted_target_completion.values[[1, 4]] != target_completion.values[[1, 4]]
    @test shifted_target_completion.maxima["target_anchor_wfc_maximum_drift"] == 0.0
    @test shifted_target_completion.maxima["target_complement_maximum_element_ev"] <= 1.0e-12

    frame_structure = WannierNLQG.SymmetryFoundation.CrystalStructure(
        Matrix{Float64}(I, 3, 3),
        ["X"],
        zeros(3, 1),
    )
    frame_g_vectors = Int[0 0 0; 1 0 0; 0 1 0; 0 0 1]
    identity_coefficients = reshape(Matrix{ComplexF64}(I, 4, 4), 4, 4, 1)
    raw_representative_frame = Base.invokelatest(
        WannierNLQG.SymmetryFoundation.PlaneWaveKPoint,
        zeros(3),
        frame_g_vectors,
        identity_coefficients,
        target_completion.values;
        normalize_coefficients = false,
    )
    raw_target_frame = Base.invokelatest(
        WannierNLQG.SymmetryFoundation.PlaneWaveKPoint,
        zeros(3),
        frame_g_vectors,
        identity_coefficients,
        shifted_target_completion.values;
        normalize_coefficients = false,
    )
    frame_native = Base.invokelatest(
        WannierNLQG.SymmetryFoundation.NativeWavefunctionData,
        :vasp,
        frame_structure,
        2.0pi .* Matrix{Float64}(I, 3, 3),
        (2, 1, 1),
        false,
        [raw_representative_frame, raw_target_frame],
        Dict("fixture" => repeat("4", 64)),
        Dict("coefficient_normalization" => "vasp_raw"),
    )
    frame_paw = Base.invokelatest(
        extension.VASPPawSystem,
        Dict{String, extension.VASPPawDataset}(),
        String[],
        extension.VASPPawAtomLayout[],
        1,
        zeros(1, 1),
        1.0,
    )
    raw_projectors =
        [reshape(ComplexF64[1, 2, 3, 4], 4, 1, 1), reshape(ComplexF64[4, 3, 2, 1], 4, 1, 1)]
    frame_metric = Base.invokelatest(
        extension._VASPStrictSewingMetric,
        frame_paw,
        raw_projectors,
        [zeros(ComplexF64, 1, 4), zeros(ComplexF64, 1, 4)],
    )
    frame_rotations = cat(target_completion.vectors, shifted_target_completion.vectors; dims = 3)
    frame_energies = hcat(target_completion.values, shifted_target_completion.values)
    completed_frame = Base.invokelatest(
        extension._star_replay_local_completed_frame,
        frame_native,
        frame_metric,
        frame_rotations,
        frame_energies,
    )
    expected_representative_coefficients = Base.invokelatest(
        extension._star_rotate_rows,
        identity_coefficients,
        target_completion.vectors,
    )
    expected_target_coefficients = Base.invokelatest(
        extension._star_rotate_rows,
        identity_coefficients,
        shifted_target_completion.vectors,
    )
    @test completed_frame.points[1].coefficients ≈ expected_representative_coefficients atol =
        1.0e-12 rtol = 0.0
    @test completed_frame.points[2].coefficients ≈ expected_target_coefficients atol = 1.0e-12 rtol =
        0.0
    @test completed_frame.points[2].energies_ev == shifted_target_completion.values
    @test completed_frame.metric.projectors[1] ≈ Base.invokelatest(
        extension._star_rotate_rows,
        raw_projectors[1],
        target_completion.vectors,
    ) atol = 1.0e-12 rtol = 0.0
    replay_roundtrip = Base.invokelatest(
        extension._star_replay_local_completed_frame,
        frame_native,
        frame_metric,
        frame_rotations,
        frame_energies;
        reference_native = Base.invokelatest(
            WannierNLQG.SymmetryFoundation.NativeWavefunctionData,
            frame_native.source_code,
            frame_native.structure,
            frame_native.reciprocal_lattice,
            frame_native.mp_grid,
            frame_native.spinor,
            completed_frame.points,
            frame_native.input_sha256,
            frame_native.source_metadata,
        ),
        reference_metric = completed_frame.metric,
    )
    @test replay_roundtrip.maximum_coefficient_reconstruction == 0.0
    @test replay_roundtrip.maximum_projector_reconstruction == 0.0

    @test_throws ArgumentError Base.invokelatest(
        extension._star_replay_local_completed_frame,
        frame_native,
        frame_metric,
        zeros(ComplexF64, 3, 3, 2),
        frame_energies,
    )
    nonfinite_rotations = copy(frame_rotations)
    nonfinite_rotations[1] = ComplexF64(NaN, 0.0)
    @test_throws ArgumentError Base.invokelatest(
        extension._star_replay_local_completed_frame,
        frame_native,
        frame_metric,
        nonfinite_rotations,
        frame_energies,
    )
    nonfinite_energies = copy(frame_energies)
    nonfinite_energies[1] = NaN
    @test_throws ArgumentError Base.invokelatest(
        extension._star_replay_local_completed_frame,
        frame_native,
        frame_metric,
        frame_rotations,
        nonfinite_energies,
    )

    @test_throws ArgumentError Base.invokelatest(
        extension._star_transport_symmetrized_target_eigenpair,
        source_target,
        [1, 2],
        [2],
        formal_antiunitary,
        true,
        target_hamiltonian,
        source_values,
    )
    @test_throws ArgumentError Base.invokelatest(
        extension._star_symmetrized_target_eigenpair,
        hamiltonian,
        target_indices,
        [[1, 2, 3], [3, 4, 5, 6]],
        5.0e-3,
    )
end

@testset "symmetrized energy shifts are audit-only partition evidence" begin
    extension =
        first(STAR_GAUGE_W._load_wannierization_extension!()).PAWMatrixElements.PAWMatrixElements
    thresholds = STAR_GAUGE_W.PAWGaugeThresholds()
    maxima = Dict{String, Float64}(
        "wfc_rotation_reconstruction" => 0.0,
        "target_reconstruction_leakage_weight" => 0.0,
        "target_state_leakage_weight" => 0.0,
        "target_to_complement_leakage_weight" => 0.0,
        "complement_to_target_leakage_weight" => 0.0,
        "completed_paw_s_norm" => 0.0,
        "raw_unitarity" => 0.0,
        "normalized_polar_correction" => 0.0,
        "alternative_path_residual" => 0.0,
        "kramers_pair_residual" => 0.0,
        "hamiltonian_covariance_after_ev" => 0.0,
        "hamiltonian_covariance_after_operator_ev" => 0.0,
        "hamiltonian_covariance_after_source_column_l2_ev" => 0.0,
        "hamiltonian_covariance_after_normalized_frobenius_ev" => 0.0,
        "projected_eigen_residual_ev" => 0.0,
        "nondegenerate_block_leakage" => 0.0,
        "target_complement_maximum_element_ev" => 0.0,
        "target_anchor_wfc_maximum_drift" => 0.0,
        "target_anchor_energy_maximum_drift_ev" => 0.0,
        "target_anchor_rotation_maximum_drift" => 0.0,
        "maximum_energy_shift_ev" => 8.0e-6,
        "rms_energy_shift_ev" => 2.0e-6,
    )
    solution = (maxima = maxima, maximum_contexts = Dict{String, String}())
    symmetrized_violations = Base.invokelatest(
        extension._star_partition_candidate_violations,
        solution,
        thresholds,
        STAR_GAUGE_W.FixedGapPAWBlockPartition(),
        STAR_GAUGE_W.SymmetrizedDFTHamiltonian(),
    )
    native_violations = Base.invokelatest(
        extension._star_partition_candidate_violations,
        solution,
        thresholds,
        STAR_GAUGE_W.FixedGapPAWBlockPartition(),
        STAR_GAUGE_W.NativeDFTHamiltonian(),
    )
    @test isempty(symmetrized_violations)
    @test Set(getfield.(native_violations, :name)) ==
          Set(("maximum_energy_shift_ev", "rms_energy_shift_ev"))

    formal_failure = merge(
        maxima,
        Dict("projected_eigen_residual_ev" => 1.25 * thresholds.projected_eigen_residual_ev),
    )
    formal_violations = Base.invokelatest(
        extension._star_partition_candidate_violations,
        (maxima = formal_failure, maximum_contexts = Dict{String, String}()),
        thresholds,
        STAR_GAUGE_W.FixedGapPAWBlockPartition(),
        STAR_GAUGE_W.SymmetrizedDFTHamiltonian(),
    )
    @test only(formal_violations).name == "projected_eigen_residual_ev"
    @test only(formal_violations).ratio ≈ 1.25

    raw_maxima = Dict{String, Float64}(
        "raw_preflight_diagnostic_exceeded" => 0.0,
        "raw_preflight_diagnostic_maximum_ratio" => 0.0,
    )
    raw_contexts = Dict{String, String}()
    @test Base.invokelatest(
        extension._star_record_raw_preflight_diagnostic!,
        raw_maxima,
        raw_contexts,
        "s_reconstruction",
        8.0e-6,
        5.0e-6,
        "star=8",
    ) === nothing
    @test raw_maxima["raw_preflight_diagnostic_exceeded"] == 1.0
    @test raw_maxima["raw_preflight_diagnostic_maximum_ratio"] ≈ 1.6
    @test raw_maxima["pre_symmetrization_s_reconstruction"] == 8.0e-6
    @test occursin("s_reconstruction", raw_contexts["raw_preflight_diagnostic_maximum_ratio"])
    @test_throws ArgumentError Base.invokelatest(
        extension._star_record_raw_preflight_diagnostic!,
        raw_maxima,
        raw_contexts,
        "nonfinite",
        Inf,
        5.0e-6,
        "star=1",
    )
    @test Base.invokelatest(
        extension._star_post_symmetrization_failure_code,
        "wfc_rotation_reconstruction",
    ) == "POST_SYMMETRIZATION_RECONSTRUCTION_HOLD"
    @test Base.invokelatest(
        extension._star_post_symmetrization_failure_code,
        "hamiltonian_covariance_after_operator_ev",
    ) == "HAMILTONIAN_COVARIANCE_HOLD"
    @test Base.invokelatest(
        extension._star_post_symmetrization_failure_code,
        "controlled_hamiltonian_correction_operator_ev",
    ) == "CONTROLLED_SYMMETRIZATION_HOLD"

    controlled_solution = (
        maxima = Dict(
            "controlled_far_rotation_operator" => 7.5e-4,
            "controlled_far_rotation_normalized_frobenius" => 3.0e-4,
            "controlled_hamiltonian_correction_operator_ev" => 1.2e-5,
            "controlled_hamiltonian_correction_normalized_frobenius_ev" => 6.0e-6,
        ),
        maximum_contexts = Dict{String, String}(),
    )
    symmetrized_controlled_violations = NamedTuple[]
    Base.invokelatest(
        extension._star_controlled_native_difference_evidence!,
        symmetrized_controlled_violations,
        controlled_solution,
        STAR_GAUGE_W.ControlledHamiltonianSymmetryThresholds(),
        STAR_GAUGE_W.SymmetrizedDFTHamiltonian(),
        "artificial-over-reference",
    )
    @test isempty(symmetrized_controlled_violations)
    @test controlled_solution.maxima["native_difference_audit_reference_exceeded"] == 1.0
    @test controlled_solution.maxima["native_difference_audit_maximum_ratio"] ≈ 1.5
    native_controlled_violations = NamedTuple[]
    Base.invokelatest(
        extension._star_controlled_native_difference_evidence!,
        native_controlled_violations,
        controlled_solution,
        STAR_GAUGE_W.ControlledHamiltonianSymmetryThresholds(),
        STAR_GAUGE_W.NativeDFTHamiltonian(),
        "artificial-over-reference",
    )
    @test length(native_controlled_violations) == 4
end

@testset "controlled discrete Hamiltonian symmetry restoration oracle" begin
    extension =
        first(STAR_GAUGE_W._load_wannierization_extension!()).PAWMatrixElements.PAWMatrixElements
    @test extension !== nothing
    native_hamiltonian = Matrix(Diagonal([0.0, 1.0e-3, 0.2, 0.3]))
    reynolds_hamiltonian = copy(native_hamiltonian)
    reynolds_hamiltonian[1, 3] = 1.0e-6
    reynolds_hamiltonian[3, 1] = 1.0e-6
    context = (
        workspace = 1:4,
        lowdin = (hamiltonians = [native_hamiltonian],),
        representative = 1,
        hamiltonian_average = reynolds_hamiltonian,
        star_index = 1,
    )
    result = Base.invokelatest(
        extension._star_controlled_symmetrization_eigenpair,
        [[1, 2], [3], [4]],
        context,
        STAR_GAUGE_W.FarBandCovarianceCorrection(),
    )
    @test result.maxima["controlled_hamiltonian_correction_operator_ev"] ≈ 1.0e-6
    @test result.maxima["controlled_far_rotation_operator"] ≈ 5.0e-6 atol = 1.0e-14
    @test result.maxima["controlled_sylvester_offblock_residual_operator_ev"] <= 1.0e-12
    @test maximum(abs, result.vectors' * result.vectors - I) <= 1.0e-12
end

@testset "columnar PAW block audit is diagnostic-only" begin
    extension =
        first(STAR_GAUGE_W._load_wannierization_extension!()).PAWMatrixElements.PAWMatrixElements
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
        hdf5 = joinpath(directory, "audit.h5")
        csv = joinpath(directory, "audit.csv")
        json = joinpath(directory, "audit.json")
        result = STAR_GAUGE_W.audit_paw_block_partitions(
            STAR_GAUGE_W.PAWBlockPartitionAuditConfig(
                source = source,
                output_hdf5 = hdf5,
                output_csv = csv,
                output_json = json,
                target_band_count = 1,
                kpoint_indices = [1],
            ),
        )
        @test result.status == :DIAGNOSTIC_ONLY
        @test result.violation_count == 0
        @test isfile(hdf5) && isfile(csv) && isfile(json)
        HDF5.h5open(hdf5, "r") do handle
            @test String(read(HDF5.attributes(handle)["schema_version"])) == "1.0"
            @test read(HDF5.attributes(handle)["production_eligible"]) == false
            @test length(read(handle["evidence/paw"])) == 0
            @test length(read(handle["fixed_gap_scan/cap_ev"])) == 6
        end
        payload = JSON3.read(read(json, String), Dict{String, Any})
        @test payload["fixed_gap_physics_metrics_status"] ==
              "PARTITION_GRAPH_AND_NATIVE_PREGAUGE_ONLY"
    end
end

@testset "Hamiltonian-weighted near/far PAW block classification" begin
    STAR_GAUGE_W._load_wannierization_extension!()
    extension = Base.get_extension(WannierNLQG, :WannierNLQGWannierizationExt).PAWMatrixElements
    buffer = STAR_GAUGE_W.ClosureDrivenBandBuffer(cluster_tolerance_ev = 1.0e-3)
    thresholds = STAR_GAUGE_W.PAWGaugeThresholds()
    policy = STAR_GAUGE_W.HamiltonianWeightedPAWBlockPartition()

    near = Matrix{ComplexF64}(I, 3, 3)
    near[1, 2] = 1.0e-5
    near[1, 3] = 6.7e-6
    decision = Base.invokelatest(
        extension._star_block_partition_decision,
        [near],
        [0.0, 0.015, 0.288],
        buffer,
        thresholds,
        policy,
    )
    @test decision.blocks == [[1, 2], [3]]
    @test decision.policy_key == "hamiltonian_weighted_far_band"
    @test decision.far_residual_count == 1
    @test decision.tolerated_far_residual_count == 1
    @test decision.maximum_pair_hamiltonian_residual_ev ≈ 0.288 * 6.7e-6

    small_coupling_large_energy = Matrix{ComplexF64}(I, 2, 2)
    small_coupling_large_energy[1, 2] = 1.0e-6
    pair_error = try
        Base.invokelatest(
            extension._star_block_partition_decision,
            [small_coupling_large_energy],
            [0.0, 10.0],
            buffer,
            thresholds,
            policy,
        )
        nothing
    catch error
        error
    end
    @test pair_error isa ArgumentError
    @test occursin("FAR_BAND_PAIR_RESIDUAL_HOLD", sprint(showerror, pair_error))

    cumulative = Matrix{ComplexF64}(I, 3, 3)
    cumulative[1, 3] = 2.0e-6
    cumulative[2, 3] = 4.0e-6
    cumulative_decision = Base.invokelatest(
        extension._star_block_partition_decision,
        [cumulative],
        [0.0, 1.0, 2.0],
        buffer,
        thresholds,
        policy,
    )
    @test cumulative_decision.pre_gauge_far_cumulative_status ==
          :DIAGNOSTIC_EXCEEDED_CONTINUE_TO_POST_GAUGE
    @test any(
        name -> occursin(name, cumulative_decision.pre_gauge_far_cumulative_worst_context),
        ("operator_ev", "source_column_l2_ev", "normalized_frobenius_ev"),
    )
    fail_stop_policy =
        STAR_GAUGE_W.HamiltonianWeightedPAWBlockPartition(pre_gauge_cumulative_mode = :fail_stop)
    cumulative_error = try
        Base.invokelatest(
            extension._star_block_partition_decision,
            [cumulative],
            [0.0, 1.0, 2.0],
            buffer,
            thresholds,
            fail_stop_policy,
        )
        nothing
    catch error
        error
    end
    @test cumulative_error isa ArgumentError
    @test occursin("FAR_BAND_CUMULATIVE_RESIDUAL_HOLD", sprint(showerror, cumulative_error))

    dimension = 8
    permutation = zeros(ComplexF64, dimension, dimension)
    energies = collect(0.0:(dimension - 1))
    for source in 1:dimension
        target = mod1(source + 1, dimension)
        gap = abs(energies[target] - energies[source])
        permutation[target, source] = 4.0e-6 / gap
    end
    metrics = Base.invokelatest(
        extension._star_hamiltonian_residual_metrics,
        permutation,
        Diagonal(energies),
        Diagonal(energies),
        false,
    )
    @test metrics.maximum_element_ev ≈ 4.0e-6
    @test metrics.operator_ev ≈ 4.0e-6
    @test metrics.maximum_source_column_l2_ev ≈ 4.0e-6
    @test metrics.normalized_frobenius_ev ≈ 4.0e-6
    @test metrics.frobenius_ev ≈ 4.0e-6 * sqrt(dimension)

    source_h = ComplexF64[1 im; -im 2]
    target_h = ComplexF64[3 0.2im; -0.2im 4]
    sewing = ComplexF64[0.7 0.1im; -0.2im 0.6]
    anti_metrics = Base.invokelatest(
        extension._star_hamiltonian_residual_metrics,
        sewing,
        source_h,
        target_h,
        true,
    )
    @test anti_metrics.residual ≈ target_h * sewing - sewing * conj(source_h)
end

@testset "input-symmetry audit is identity-bound and fail-closed" begin
    extension =
        first(STAR_GAUGE_W._load_wannierization_extension!()).PAWMatrixElements.PAWMatrixElements
    mktempdir() do directory
        component_payloads = Dict(
            "smooth_density" => Dict(
                "schema" => "fixture.smooth-density-audit",
                "schema_version" => "1.0",
                "status" => "PASS",
                "operation_count" => 32,
                "maximum_relative_residual" => 2.0e-14,
            ),
            "paw_onsite" => Dict(
                "schema" => "fixture.paw-onsite-audit",
                "schema_version" => "1.0",
                "status" => "PASS",
                "operation_count" => 32,
                "maximum_component_relative_residual" => 3.0e-14,
            ),
        )
        residual_fields = Dict(
            "smooth_density" => "maximum_relative_residual",
            "paw_onsite" => "maximum_component_relative_residual",
        )
        records = Dict{String, Any}[]
        for kind in ("smooth_density", "paw_onsite")
            path = joinpath(directory, "$(kind).json")
            write(path, JSON3.write(component_payloads[kind]))
            push!(
                records,
                Dict(
                    "kind" => kind,
                    "path" => basename(path),
                    "sha256" => star_gauge_test_file_sha256(path),
                    "schema" => component_payloads[kind]["schema"],
                    "residual_field" => residual_fields[kind],
                    "maximum_residual" => component_payloads[kind][residual_fields[kind]],
                ),
            )
        end
        source_hashes =
            Dict("data-file-schema.xml" => repeat("1", 64), "wfc1.hdf5" => repeat("2", 64))
        manifest = Dict(
            "schema" => "wanniernlqg.input-symmetry-audit-manifest",
            "schema_version" => "1.0",
            "status" => "PASS",
            "operation_count" => 32,
            "maximum_residual" => 3.0e-14,
            "qualification_threshold" => 5.0e-6,
            "source_input_sha256" =>
                Base.invokelatest(extension._star_input_identity_sha256, source_hashes),
            "component_audits" => records,
        )
        manifest_path = joinpath(directory, "input-audit-manifest.json")
        write(manifest_path, JSON3.write(manifest))
        config = STAR_GAUGE_W.SymmetryCovariantWavefunctionPreparationConfig(
            construction_policy = :strict,
            source = WannierNLQG.SymmetryFoundation.QuantumEspressoWavefunctionSource(
                "fixture.save";
                band_range = 1:1,
            ),
            output_hdf5 = joinpath(directory, "gauge.h5"),
            input_symmetry_audit_json = manifest_path,
        )
        hashes = Base.invokelatest(extension._star_input_audit_hash, config, source_hashes, 32)
        @test hashes["INPUT_SYMMETRY_AUDIT_JSON"] == star_gauge_test_file_sha256(manifest_path)
        @test Set(keys(hashes)) == Set((
            "INPUT_SYMMETRY_AUDIT_JSON",
            "INPUT_SYMMETRY_SOURCE_SHA256",
            "INPUT_SYMMETRY_COMPONENT:smooth_density",
            "INPUT_SYMMETRY_COMPONENT:paw_onsite",
        ))

        wrong_source = copy(source_hashes)
        wrong_source["wfc1.hdf5"] = repeat("3", 64)
        @test_throws ArgumentError Base.invokelatest(
            extension._star_input_audit_hash,
            config,
            wrong_source,
            32,
        )
        @test_throws ArgumentError Base.invokelatest(
            extension._star_input_audit_hash,
            config,
            source_hashes,
            31,
        )
    end
end

@testset "artificial VASP shared gauge capsule readback" begin
    extension =
        first(STAR_GAUGE_W._load_wannierization_extension!()).PAWMatrixElements.PAWMatrixElements
    structure = WannierNLQG.SymmetryFoundation.CrystalStructure(
        Matrix{Float64}(I, 3, 3),
        ["X"],
        zeros(3, 1),
    )
    point = Base.invokelatest(
        WannierNLQG.SymmetryFoundation.PlaneWaveKPoint,
        zeros(3),
        reshape([0, 0, 0], 1, 3),
        reshape(ComplexF64[1.0], 1, 1, 1),
        [0.0];
        normalize_coefficients = false,
    )
    native = Base.invokelatest(
        WannierNLQG.SymmetryFoundation.NativeWavefunctionData,
        :vasp,
        structure,
        2.0pi .* Matrix{Float64}(I, 3, 3),
        (1, 1, 1),
        false,
        [point],
        Dict("fixture" => repeat("1", 64)),
        Dict("coefficient_normalization" => "vasp_raw"),
    )
    paw = Base.invokelatest(
        extension.VASPPawSystem,
        Dict{String, extension.VASPPawDataset}(),
        String[],
        extension.VASPPawAtomLayout[],
        1,
        zeros(1, 1),
        1.0,
    )
    metric = Base.invokelatest(
        extension._VASPStrictSewingMetric,
        paw,
        [zeros(ComplexF64, 1, 1, 1)],
        [zeros(ComplexF64, 1, 1)],
    )
    identity = WannierNLQG.SymmetryFoundation.SymmetryOperation(
        Matrix{Int}(I, 3, 3),
        zeros(3),
        Matrix{Float64}(I, 3, 3),
    )
    payload = Base.invokelatest(
        extension._StarCovariantPAWPayload,
        native,
        metric,
        [identity],
        ones(Int, 1, 1),
        zeros(Int, 3, 1, 1),
        [1],
        [1],
        [1],
        [0],
        reshape(ComplexF64[1.0], 1, 1, 1),
        1:1,
        1:1,
        Dict("completed_paw_s_norm" => 0.0),
        Dict("completed_paw_s_norm" => "fixture"),
        native.input_sha256,
        native.source_metadata,
    )
    mktempdir() do directory
        filename = joinpath(directory, "vasp-star-gauge.h5")
        Base.invokelatest(
            extension._write_star_covariant_paw_gauge_hdf5,
            filename,
            payload;
            status = :PASS,
            root_cause = :GAUGE_COVARIANCE_PRIMARY_CAUSE_SUPPORTED,
            schema_version = "1.10",
        )
        restored = Base.invokelatest(extension._read_star_covariant_paw_gauge_hdf5, filename)
        @test restored.payload.native.source_code == :vasp
        @test restored.payload.metric isa extension._VASPStrictSewingMetric
        @test Base.invokelatest(
            extension._star_payload_sha256,
            restored.payload;
            schema_version = "1.10",
        ) == Base.invokelatest(extension._star_payload_sha256, payload; schema_version = "1.10")
    end
end

@testset "two-sided closure buffer and block partition" begin
    STAR_GAUGE_W._load_wannierization_extension!()
    extension = Base.get_extension(WannierNLQG, :WannierNLQGWannierizationExt).PAWMatrixElements
    raw = Matrix{ComplexF64}(I, 4, 4)
    raw[1, 2] = 1.0e-3
    raw[2, 1] = -1.0e-3
    workspace, leakage = Base.invokelatest(
        extension._star_select_buffer,
        [raw],
        [-0.02, 0.0, 0.01, 0.03],
        2:3,
        STAR_GAUGE_W.ClosureDrivenBandBuffer(max_extra_bands = 1),
        5.0e-6,
    )
    @test workspace == 1:3
    @test leakage == 0.0

    open_raw = copy(raw)
    open_raw[4, 3] = 2.0e-3
    error_value = try
        Base.invokelatest(
            extension._star_select_buffer,
            [open_raw],
            [-0.02, 0.0, 0.01, 0.03],
            2:3,
            STAR_GAUGE_W.ClosureDrivenBandBuffer(max_extra_bands = 1),
            5.0e-6,
        )
        nothing
    catch error
        error
    end
    @test error_value isa ArgumentError
    @test occursin("FINITE_BUFFER_HOLD", sprint(showerror, error_value))

    distant = Matrix{ComplexF64}(I, 2, 2)
    distant[1, 2] = 1.0e-3
    larger_distant = copy(distant)
    larger_distant[1, 2] = 2.0e-3
    block_error = try
        Base.invokelatest(
            extension._star_merged_blocks,
            [distant, larger_distant],
            [0.0, 0.03],
            STAR_GAUGE_W.ClosureDrivenBandBuffer(),
            STAR_GAUGE_W.PAWGaugeThresholds(),
        )
        nothing
    catch error
        error
    end
    @test block_error isa ArgumentError
    block_message = sprint(showerror, block_error)
    @test occursin("BLOCK_PARTITION_HOLD", block_message)
    @test occursin("coupling=0.002", block_message)
    @test occursin("transport=2", block_message)
    target_matched = Base.invokelatest(
        extension._star_merged_blocks,
        [distant],
        [0.0, 0.03],
        STAR_GAUGE_W.ClosureDrivenBandBuffer(),
        STAR_GAUGE_W.PAWGaugeThresholds(),
        [[0.03, 0.0]],
    )
    @test target_matched == [[1, 2]]

    adaptive_raw = Matrix{ComplexF64}(I, 4, 4)
    adaptive_raw[1, 2] = 1.1e-5
    adaptive_raw[2, 3] = 9.0e-6
    adaptive_decision = Base.invokelatest(
        extension._star_block_partition_decision,
        [adaptive_raw],
        [0.0, 0.04, 0.08, 0.20],
        STAR_GAUGE_W.ClosureDrivenBandBuffer(),
        STAR_GAUGE_W.PAWGaugeThresholds(),
        STAR_GAUGE_W.AdaptiveEvidencePAWBlockPartition(),
    )
    @test adaptive_decision.blocks == [[1, 2, 3], [4]]
    @test adaptive_decision.maximum_block_bands == 3
    @test adaptive_decision.maximum_block_span_ev == 0.08
    @test adaptive_decision.evidence_orbit_count == 2

    candidates, truncated = Base.invokelatest(
        extension._star_adaptive_partition_candidates,
        [adaptive_raw],
        [0.0, 0.04, 0.08, 0.20],
        STAR_GAUGE_W.ClosureDrivenBandBuffer(),
        STAR_GAUGE_W.PAWGaugeThresholds(),
        STAR_GAUGE_W.AdaptiveEvidencePAWBlockPartition(),
    )
    @test !truncated
    @test length(candidates) == 4
    @test candidates[1].blocks == [[1], [2], [3], [4]]
    @test candidates[2].blocks == [[1, 2], [3], [4]]
    @test candidates[3].blocks == [[1], [2, 3], [4]]
    @test candidates[4].blocks == [[1, 2, 3], [4]]
    @test getfield.(candidates, :search_states) == collect(1:4)

    mandatory_raw = Matrix{ComplexF64}(I, 3, 3)
    mandatory_raw[1, 2] = 8.0e-6
    mandatory_raw[2, 3] = 7.0e-6
    mandatory_candidates, _ = Base.invokelatest(
        extension._star_adaptive_partition_candidates,
        [mandatory_raw],
        [0.0, 0.020, 0.060],
        STAR_GAUGE_W.ClosureDrivenBandBuffer(cluster_tolerance_ev = 1.0e-3),
        STAR_GAUGE_W.PAWGaugeThresholds(),
        STAR_GAUGE_W.AdaptiveEvidencePAWBlockPartition(),
    )
    @test first(mandatory_candidates).blocks == [[1, 2], [3]]

    remote_raw = Matrix{ComplexF64}(I, 2, 2)
    remote_raw[1, 2] = 1.0e-5
    remote_error = try
        Base.invokelatest(
            extension._star_block_partition_decision,
            [remote_raw],
            [0.0, 0.101],
            STAR_GAUGE_W.ClosureDrivenBandBuffer(),
            STAR_GAUGE_W.PAWGaugeThresholds(),
            STAR_GAUGE_W.AdaptiveEvidencePAWBlockPartition(),
        )
        nothing
    catch error
        error
    end
    @test remote_error isa ArgumentError
    @test occursin("BLOCK_PARTITION_HARD_LIMIT_HOLD", sprint(showerror, remote_error))

    dense_raw = Matrix{ComplexF64}(I, 13, 13)
    for band in 1:12
        dense_raw[band, band + 1] = 1.0e-5
    end
    dense_error = try
        Base.invokelatest(
            extension._star_block_partition_decision,
            [dense_raw],
            collect(range(0.0, 0.096; length = 13)),
            STAR_GAUGE_W.ClosureDrivenBandBuffer(cluster_tolerance_ev = 1.0e-3),
            STAR_GAUGE_W.PAWGaugeThresholds(),
            STAR_GAUGE_W.AdaptiveEvidencePAWBlockPartition(),
        )
        nothing
    catch error
        error
    end
    @test dense_error isa ArgumentError
    @test occursin("component bands=13", sprint(showerror, dense_error))

    search_error = try
        Base.invokelatest(
            extension._star_block_partition_decision,
            [adaptive_raw],
            [0.0, 0.04, 0.08, 0.20],
            STAR_GAUGE_W.ClosureDrivenBandBuffer(),
            STAR_GAUGE_W.PAWGaugeThresholds(),
            STAR_GAUGE_W.AdaptiveEvidencePAWBlockPartition(max_search_states = 2),
        )
        nothing
    catch error
        error
    end
    @test search_error isa ArgumentError
    @test occursin("BLOCK_PARTITION_SEARCH_HOLD", sprint(showerror, search_error))

    bounded_candidates, bounded_truncated = Base.invokelatest(
        extension._star_adaptive_partition_candidates,
        [adaptive_raw],
        [0.0, 0.04, 0.08, 0.20],
        STAR_GAUGE_W.ClosureDrivenBandBuffer(),
        STAR_GAUGE_W.PAWGaugeThresholds(),
        STAR_GAUGE_W.AdaptiveEvidencePAWBlockPartition(max_search_states = 2),
    )
    @test length(bounded_candidates) == 2
    @test bounded_truncated
end

@testset "WFC EIG MMN AMN gauge propagation conventions" begin
    extension =
        first(STAR_GAUGE_W._load_wannierization_extension!()).PAWMatrixElements.PAWMatrixElements
    source_rotation = ComplexF64[1 0; 0 cis(0.37)]
    target_rotation = ComplexF64[0 1; 1 0]
    sewing = ComplexF64[1 2im; -3im 4]
    unitary = Base.invokelatest(
        extension._star_transform_sewing_gauge,
        sewing,
        target_rotation,
        source_rotation,
        false,
    )
    antiunitary = Base.invokelatest(
        extension._star_transform_sewing_gauge,
        sewing,
        target_rotation,
        source_rotation,
        true,
    )
    @test unitary == target_rotation' * sewing * source_rotation
    @test antiunitary == target_rotation' * sewing * conj(source_rotation)

    hamiltonian = ComplexF64[1 im; -im 2]
    reynolds = Base.invokelatest(
        extension._star_reynolds_hamiltonian,
        [Matrix{ComplexF64}(I, 2, 2), Matrix{ComplexF64}(I, 2, 2)],
        [hamiltonian, hamiltonian],
        [false, true],
    )
    @test reynolds == 0.5 .* (hamiltonian + conj(hamiltonian))

    kramers = ComplexF64[0 -1; 1 0]
    pair_basis, pair_residual =
        Base.invokelatest(extension._star_kramers_pair_basis, kramers, 2.0e-5)
    @test pair_residual <= 2.0e-5
    @test pair_basis' * pair_basis ≈ Matrix{ComplexF64}(I, 2, 2) atol = 1.0e-14
    @test pair_basis' * kramers * conj(pair_basis) ≈ kramers atol = 1.0e-14

    rotations = zeros(ComplexF64, 2, 1, 2)
    rotations[:, 1, 1] .= ComplexF64[1, 0]
    rotations[:, 1, 2] .= ComplexF64[inv(sqrt(2)), im * inv(sqrt(2))]
    parent_amn = WannierNLQG.IO.WannierAMN(2, 2, 1, reshape(ComplexF64[1, 2, 3, 4], 2, 1, 2))
    rotated_amn = Base.invokelatest(extension._star_rotate_parent_amn, parent_amn, rotations)
    for kpoint in 1:2
        @test rotated_amn.data[:, :, kpoint] ≈
              rotations[:, :, kpoint]' * parent_amn.data[:, :, kpoint]
    end

    parent_mmn_data = reshape(ComplexF64[1, 2, 3, 4, 5, 6, 7, 8], 2, 2, 1, 2)
    parent_mmn = WannierNLQG.IO.WannierMMN(
        2,
        2,
        1,
        parent_mmn_data,
        reshape([2, 1], 1, 2),
        zeros(Int, 3, 1, 2),
    )
    rotated_mmn = Base.invokelatest(extension._star_rotate_parent_mmn, parent_mmn, rotations)
    for kpoint in 1:2
        neighbor = parent_mmn.neighbors[1, kpoint]
        expected =
            rotations[:, :, kpoint]' * parent_mmn.data[:, :, 1, kpoint] * rotations[:, :, neighbor]
        @test rotated_mmn.data[:, :, 1, kpoint] ≈ expected
    end
end

@testset "NC star-gauge capsule, readback, tamper stop, and matrix parity" begin
    extension =
        first(STAR_GAUGE_W._load_wannierization_extension!()).PAWMatrixElements.PAWMatrixElements
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
        gauge_hdf5 = joinpath(directory, "star_gauge.h5")
        result = STAR_GAUGE_W.prepare_symmetry_covariant_wavefunctions(
            STAR_GAUGE_W.SymmetryCovariantWavefunctionPreparationConfig(
                construction_policy = :strict,
                source = source,
                wavefunction_gauge_backend = STAR_GAUGE_W.StarCovariantPAWGauge(
                    buffer_policy = STAR_GAUGE_W.ClosureDrivenBandBuffer(max_extra_bands = 0),
                ),
                output_hdf5 = gauge_hdf5,
                target_band_count = 1,
            ),
        )
        @test result.status == :PASS
        @test result.root_cause == :GAUGE_COVARIANCE_PRIMARY_CAUSE_SUPPORTED
        @test isfile(gauge_hdf5)
        @test isfile(splitext(gauge_hdf5)[1] * ".eig")
        restored = Base.invokelatest(extension._read_star_covariant_paw_gauge_hdf5, gauge_hdf5)
        HDF5.h5open(gauge_hdf5, "r") do handle
            @test String(read(HDF5.attributes(handle)["schema_version"])) == "1.0"
            @test String(read(HDF5.attributes(handle)["block_partition_policy"])) == "fixed_gap"
            @test String(read(HDF5.attributes(handle)["band_frame_contract_status"])) == "PASS"
        end
        @test restored.band_frame_contract !== nothing
        @test something(restored.band_frame_contract).status == "PASS"
        @test something(restored.band_frame_contract).physical_isometry_maximum <=
              something(restored.band_frame_contract).physical_isometry_tolerance
        @test something(restored.band_frame_contract).replay_maximum <=
              something(restored.band_frame_contract).replay_tolerance
        @test restored.payload.target_band_range == 1:1
        @test restored.payload.parent_band_range == 1:1
        @test restored.payload.native.kpoints[1].coefficients ==
              restored.payload.native.kpoints[1].coefficients

        tampered_frame_evidence = joinpath(directory, "tampered-band-frame-evidence.h5")
        cp(gauge_hdf5, tampered_frame_evidence)
        HDF5.h5open(tampered_frame_evidence, "r+") do handle
            attributes = HDF5.attributes(handle)
            HDF5.delete_attribute(handle, "band_frame_replay_maximum")
            attributes["band_frame_replay_maximum"] = "9.0e-9"
        end
        @test_throws ArgumentError Base.invokelatest(
            extension._read_star_covariant_paw_gauge_hdf5,
            tampered_frame_evidence,
        )

        weighted_hdf5 = joinpath(directory, "weighted_star_gauge.h5")
        weighted_progress = joinpath(directory, "weighted_star_progress.jsonl")
        weighted_result = STAR_GAUGE_W.prepare_symmetry_covariant_wavefunctions(
            STAR_GAUGE_W.SymmetryCovariantWavefunctionPreparationConfig(
                construction_policy = :strict,
                source = source,
                wavefunction_gauge_backend = STAR_GAUGE_W.StarCovariantPAWGauge(
                    buffer_policy = STAR_GAUGE_W.ClosureDrivenBandBuffer(max_extra_bands = 0),
                    block_partition_policy = STAR_GAUGE_W.HamiltonianWeightedPAWBlockPartition(),
                ),
                output_hdf5 = weighted_hdf5,
                target_band_count = 1,
                preflight_diagnostics_jsonl = weighted_progress,
            ),
        )
        @test weighted_result.status == :PASS
        weighted_restored =
            Base.invokelatest(extension._read_star_covariant_paw_gauge_hdf5, weighted_hdf5)
        @test weighted_restored.payload.source_metadata["block_partition_policy"] ==
              "hamiltonian_weighted_far_band"
        progress_records = [
            JSON3.read(line, Dict{String, Any}) for
            line in readlines(weighted_progress) if !isempty(strip(line))
        ]
        @test length(progress_records) == 2
        star_record =
            only(filter(record -> record["stage"] == "POST_GAUGE_STAR_PASS", progress_records))
        full_record = only(
            filter(
                record -> record["stage"] == "FULL_STRICT_REPRESENTATION_PASS",
                progress_records,
            ),
        )
        @test star_record["status"] == "PASS"
        @test star_record["pre_gauge_far_cumulative_status"] == "PASS"
        @test haskey(star_record, "post_gauge_maxima")
        @test haskey(star_record["post_gauge_maxima"], "star1_strict_raw_group_law")
        @test haskey(star_record["post_gauge_maxima"], "star1_strict_raw_cocycle")
        @test full_record["status"] == "PASS"
        HDF5.h5open(weighted_hdf5, "r") do handle
            @test String(read(HDF5.attributes(handle)["schema_version"])) == "1.0"
            @test String(read(HDF5.attributes(handle)["block_partition_policy"])) ==
                  "hamiltonian_weighted_far_band"
        end
        tampered_block_policy = joinpath(directory, "tampered-block-policy.h5")
        cp(weighted_hdf5, tampered_block_policy)
        HDF5.h5open(tampered_block_policy, "r+") do handle
            attributes = HDF5.attributes(handle)
            HDF5.delete_attribute(handle, "block_partition_policy")
            attributes["block_partition_policy"] = "fixed_gap"
        end
        @test_throws ArgumentError Base.invokelatest(
            extension._read_star_covariant_paw_gauge_hdf5,
            tampered_block_policy,
        )

        symmetrized_hdf5 = joinpath(directory, "symmetrized_dft_hamiltonian.h5")
        symmetrized_gauge_backend = STAR_GAUGE_W.StarCovariantPAWGauge(
            buffer_policy = STAR_GAUGE_W.ClosureDrivenBandBuffer(max_extra_bands = 0),
            block_partition_policy = STAR_GAUGE_W.HamiltonianWeightedPAWBlockPartition(),
            hamiltonian_correction = STAR_GAUGE_W.FarBandCovarianceCorrection(),
        )
        symmetrized_result = STAR_GAUGE_W.prepare_symmetry_covariant_wavefunctions(
            STAR_GAUGE_W.SymmetryCovariantWavefunctionPreparationConfig(
                construction_policy = :strict,
                source = source,
                wavefunction_gauge_backend = symmetrized_gauge_backend,
                authoritative_hamiltonian = STAR_GAUGE_W.SymmetrizedDFTHamiltonian(),
                target_subspace_contract = star_gauge_target_contract(source),
                output_hdf5 = symmetrized_hdf5,
                target_band_count = 1,
            ),
        )
        @test symmetrized_result.status == :PASS
        @test symmetrized_result.root_cause == :SYMMETRIZED_DFT_HAMILTONIAN_PASS
        @test symmetrized_result.authoritative_hamiltonian == "symmetrized_dft_hamiltonian"
        @test symmetrized_result.scoped_production_eligible
        @test !symmetrized_result.global_production_eligible
        @test symmetrized_result.symmetrized_hamiltonian_status == :SYMMETRIZED_DFT_HAMILTONIAN_PASS
        @test symmetrized_result.symmetrized_target_subspace_status ==
              :SYMMETRIZED_DFT_HAMILTONIAN_PASS
        @test haskey(symmetrized_result.maxima, "pre_symmetrization_raw_group_law")
        @test haskey(symmetrized_result.maxima, "pre_symmetrization_raw_cocycle")
        @test haskey(symmetrized_result.maxima, "pre_symmetrization_pseudo_component_maximum")
        symmetrized_auto_restored =
            Base.invokelatest(extension._read_star_covariant_paw_gauge_hdf5, symmetrized_hdf5)
        symmetrized_restored = Base.invokelatest(
            extension._read_star_covariant_paw_gauge_hdf5,
            symmetrized_hdf5;
            source,
        )
        @test Base.invokelatest(
            extension._star_payload_sha256,
            symmetrized_auto_restored.payload,
        ) == Base.invokelatest(extension._star_payload_sha256, symmetrized_restored.payload)
        @test symmetrized_restored.payload.symmetrized_hamiltonian_audit !== nothing
        @test symmetrized_restored.payload.sealed_completed_frame_corrections === nothing
        HDF5.h5open(symmetrized_hdf5, "r") do handle
            attributes = HDF5.attributes(handle)
            @test String(read(attributes["schema_version"])) == "1.0"
            @test String(read(attributes["authoritative_hamiltonian"])) ==
                  "symmetrized_dft_hamiltonian"
            @test String(read(attributes["energy_shift_qualification"])) == "audit_only"
            @test String(read(attributes["residual_gate_phase"])) == "post_symmetrization"
            @test String(read(attributes["native_difference_qualification"])) == "audit_only"
            @test String(read(attributes["raw_preflight_diagnostic_status"])) in
                  ("WITHIN_DIAGNOSTIC_REFERENCE", "RAW_PREFLIGHT_DIAGNOSTIC_EXCEEDED")
            @test parse(
                Float64,
                String(read(attributes["maximum_energy_shift_audit_reference_ev"])),
            ) == 5.0e-6
            @test parse(Float64, String(read(attributes["rms_energy_shift_audit_reference_ev"]))) ==
                  1.0e-6
            @test Bool(read(attributes["scoped_production_eligible"]))
            @test !Bool(read(attributes["global_production_eligible"]))
            @test haskey(handle, "symmetrized_hamiltonian_audit")
            audit = handle["symmetrized_hamiltonian_audit"]
            @test haskey(audit, "target_energy_shifts_by_star_ev")
            @test haskey(audit, "parent_energy_shifts_by_kpoint_ev")
        end

        symmetrized_matrix_result = STAR_GAUGE_W.generate_symmetry_completed_qe_paw_matrix_elements(
            source,
            symmetrized_hdf5,
            fixture.nnkp_file;
            artifact_dir = joinpath(directory, "symmetrized-matrices"),
        )
        @test symmetrized_matrix_result.passed
        @test symmetrized_matrix_result.mmn_parity.max_absolute <= 1.0e-12
        @test symmetrized_matrix_result.amn_parity.max_absolute <= 1.0e-12

        projection_block = WannierNLQG.WannierProjection.WannierProjectionBlock(
            "X",
            "s",
            zeros(3, 1),
            reshape([1], 1, 1),
            reshape(Matrix{Float64}(I, 3, 3), 3, 3, 1),
            false,
        )
        projection_basis =
            WannierNLQG.WannierProjection.WannierProjectionBasis([projection_block], 1, false)
        win_file = joinpath(directory, "symmetrized.win")
        write(win_file, "num_wann = 1\n")

        # Hamiltonian values and qualification scope are orthogonal contracts:
        # NativeDFTHamiltonian remains unchanged, but an explicit outer-window
        # contract makes the parent a non-gating audit and must survive the
        # complete gauge -> representation boundary.
        native_target_hdf5 = joinpath(directory, "native_dft_target_contract.h5")
        native_target_backend = STAR_GAUGE_W.StarCovariantPAWGauge(
            buffer_policy = STAR_GAUGE_W.ClosureDrivenBandBuffer(max_extra_bands = 0),
        )
        native_target_result = STAR_GAUGE_W.prepare_symmetry_covariant_wavefunctions(
            STAR_GAUGE_W.SymmetryCovariantWavefunctionPreparationConfig(
                construction_policy = :strict,
                source = source,
                wavefunction_gauge_backend = native_target_backend,
                authoritative_hamiltonian = STAR_GAUGE_W.NativeDFTHamiltonian(),
                target_subspace_contract = star_gauge_target_contract(source),
                output_hdf5 = native_target_hdf5,
                target_band_count = 1,
            ),
        )
        @test native_target_result.status == :PASS
        @test native_target_result.authoritative_hamiltonian == "native_dft"
        @test native_target_result.target_scope_production_eligible
        @test native_target_result.scoped_production_eligible
        @test !native_target_result.global_production_eligible
        native_target_representation_hdf5 = joinpath(directory, "native-target-representation.h5")
        native_target_prepared = STAR_GAUGE_W.prepare_band_representation(
            STAR_GAUGE_W.BandRepresentationPreparationConfig(
                construction_policy = :strict,
                wannierization_mode = :symmetry_adapted,
                source = source,
                sewing_backend = STAR_GAUGE_W.AugmentationAwareSewing(),
                wavefunction_gauge_backend = native_target_backend,
                authoritative_hamiltonian = STAR_GAUGE_W.NativeDFTHamiltonian(),
                wavefunction_gauge_hdf5 = native_target_hdf5,
                win_file = win_file,
                eig_file = splitext(native_target_hdf5)[1] * ".eig",
                projection_basis = projection_basis,
                output_hdf5 = native_target_representation_hdf5,
                outer_min_ev = -18.0,
                outer_max_ev = 3.5,
                frozen_min_ev = -18.0,
                frozen_max_ev = 0.5,
                num_wannier = 1,
                compatibility_policy = :off,
            ),
        )
        native_target_representation = native_target_prepared.representation
        @test native_target_representation.schema_version == "1.0"
        @test native_target_representation.conventions["authoritative_hamiltonian"] == "native_dft"
        @test native_target_representation.conventions["qualification_scope"] == "target_subspace"
        @test native_target_representation.conventions["target_authority"] == "outer_window"
        @test native_target_representation.conventions["parent_audit_policy"] == "audit_only"
        @test occursin(
            r"^[0-9a-f]{64}$",
            native_target_representation.conventions["target_subspace_contract_sha256"],
        )
        @test Base.invokelatest(
            STAR_GAUGE_W._representation_target_subspace_contract,
            native_target_representation,
        ).active
        native_target_matrices = STAR_GAUGE_W.generate_symmetry_completed_qe_paw_matrix_elements(
            source,
            native_target_hdf5,
            fixture.nnkp_file;
            artifact_dir = joinpath(directory, "native-target-matrices"),
        )
        @test native_target_matrices.passed
        @test any(==("parent_qualification=audit_only"), native_target_matrices.diagnostics)
        @test any(
            ==("parent_matrix_identity=native_completed_direct_vs_full_parent_rotation"),
            native_target_matrices.diagnostics,
        )
        HDF5.h5open(native_target_matrices.artifacts["provenance_hdf5"], "r") do handle
            attributes = HDF5.attributes(handle)
            @test String(read(attributes["qualification_scope"])) == "target_subspace"
            @test String(read(attributes["parent_qualification"])) == "audit_only"
            @test haskey(attributes, "parent_generalized_norm_max_absolute")
            @test haskey(handle["direct_vs_rotation"], "parent_mmn")
            @test haskey(handle["direct_vs_rotation"], "parent_amn")
        end
        native_target_solver_result = STAR_GAUGE_W.construct_symmetry_adapted_wannier_functions(
            STAR_GAUGE_W.SymmetryAdaptedWannierizationConfig(
                input = STAR_GAUGE_W.WannierizationInputConfig(
                    construction_policy = :strict,
                    wannierization_mode = :symmetry_adapted,
                    source = source,
                    sewing_backend = STAR_GAUGE_W.AugmentationAwareSewing(),
                    wavefunction_gauge_backend = native_target_backend,
                    authoritative_hamiltonian = STAR_GAUGE_W.NativeDFTHamiltonian(),
                    wavefunction_gauge_hdf5 = native_target_hdf5,
                    win_file = win_file,
                    eig_file = splitext(native_target_hdf5)[1] * ".eig",
                    mmn_file = native_target_matrices.artifacts["mmn"],
                    amn_file = native_target_matrices.artifacts["amn"],
                    matrix_elements = STAR_GAUGE_W.ExternalWannier90Matrices(
                        native_target_matrices.artifacts["mmn"],
                        native_target_matrices.artifacts["amn"],
                    ),
                    projection_basis = projection_basis,
                    band_representation_hdf5 = native_target_representation_hdf5,
                    outer_min_ev = -18.0,
                    outer_max_ev = 3.5,
                    frozen_min_ev = -18.0,
                    frozen_max_ev = 0.5,
                    num_wannier = 1,
                    compatibility_policy = :off,
                ),
                solver = STAR_GAUGE_W.WannierizationSolverConfig(
                    acceleration = STAR_GAUGE_W.WannierizationAccelerationConfig(
                        disentanglement_max_steps = 1,
                        localization_max_steps = 1,
                    ),
                    max_iterations = 2,
                    localize = false,
                ),
                checkpoint = STAR_GAUGE_W.WannierizationCheckpointConfig(),
                runtime = STAR_GAUGE_W.WannierizationRuntimeConfig(),
                output = STAR_GAUGE_W.WannierizationOutputConfig(tb_output_formats = ()),
            ),
        )
        native_target_summary = native_target_solver_result.input_summary
        @test native_target_summary["authoritative_hamiltonian"] == "native_dft"
        @test native_target_summary["qualification_scope"] == "target_subspace"
        @test native_target_summary["target_authority"] == "outer_window"
        @test native_target_summary["parent_audit_policy"] == "audit_only"
        @test native_target_summary["target_subspace_contract_sha256"] ==
              native_target_representation.conventions["target_subspace_contract_sha256"]
        @test native_target_summary["disentanglement_outer_mask_sha256"] ==
              native_target_prepared.qualification_scope.outer_mask_sha256
        @test native_target_summary["disentanglement_frozen_mask_sha256"] ==
              native_target_prepared.qualification_scope.frozen_mask_sha256
        @test native_target_summary["auxiliary_parent_qualification"] == "audit_only"
        @test native_target_summary["global_production_eligible"] == "false"

        symmetrized_representation_hdf5 = joinpath(directory, "symmetrized-representation.h5")
        symmetrized_prepared = STAR_GAUGE_W.prepare_band_representation(
            STAR_GAUGE_W.BandRepresentationPreparationConfig(
                construction_policy = :strict,
                wannierization_mode = :symmetry_adapted,
                source = source,
                sewing_backend = STAR_GAUGE_W.AugmentationAwareSewing(),
                wavefunction_gauge_backend = symmetrized_gauge_backend,
                authoritative_hamiltonian = STAR_GAUGE_W.SymmetrizedDFTHamiltonian(),
                wavefunction_gauge_hdf5 = symmetrized_hdf5,
                win_file = win_file,
                eig_file = splitext(symmetrized_hdf5)[1] * ".eig",
                projection_basis = projection_basis,
                output_hdf5 = symmetrized_representation_hdf5,
                outer_min_ev = -18.0,
                outer_max_ev = 3.5,
                frozen_min_ev = -18.0,
                frozen_max_ev = 0.5,
                num_wannier = 1,
                compatibility_policy = :off,
            ),
        )
        @test symmetrized_prepared.representation.schema_version == "1.0"
        @test symmetrized_prepared.representation.conventions["authoritative_hamiltonian"] ==
              "symmetrized_dft_hamiltonian"
        HDF5.h5open(symmetrized_representation_hdf5, "r") do handle
            attributes = HDF5.attributes(handle)
            @test String(read(attributes["schema_version"])) == "1.0"
            gauge_attributes = HDF5.attributes(handle["wavefunction_gauge"])
            @test String(read(gauge_attributes["authoritative_hamiltonian"])) ==
                  "symmetrized_dft_hamiltonian"
            @test String(read(gauge_attributes["global_production_eligible"])) == "false"
            @test String(read(gauge_attributes["residual_gate_phase"])) == "post_symmetrization"
            @test String(read(gauge_attributes["native_difference_qualification"])) == "audit_only"
        end
        fresh_probe = joinpath(@__DIR__, "SymmetrizedDFTHamiltonianFreshReadProbe.jl")
        fresh_output = read(
            `$(Base.julia_cmd()) --startup-file=no --project=$(dirname(@__DIR__)) $(fresh_probe) $(symmetrized_hdf5) $(symmetrized_representation_hdf5) $(fixture.save_directory)`,
            String,
        )
        fresh_auto_output = read(
            `$(Base.julia_cmd()) --startup-file=no --project=$(dirname(@__DIR__)) $(fresh_probe) $(symmetrized_hdf5) $(symmetrized_representation_hdf5)`,
            String,
        )
        @test occursin(r"SYMMETRIZED_DFT_HAMILTONIAN_FRESH_READ_DIGEST=[0-9a-f]{64}", fresh_output)
        symmetrized_payload_sha256 =
            Base.invokelatest(extension._star_payload_sha256, symmetrized_restored.payload)
        @test occursin(
            "SYMMETRIZED_DFT_HAMILTONIAN_FRESH_READ_PAYLOAD_SHA256=$(symmetrized_payload_sha256)",
            fresh_output,
        )
        @test occursin(
            "SYMMETRIZED_DFT_HAMILTONIAN_FRESH_READ_PAYLOAD_SHA256=$(symmetrized_payload_sha256)",
            fresh_auto_output,
        )

        target_hdf5 = joinpath(directory, "symmetrized_dft_hamiltonian_target_contract.h5")
        target_authority = STAR_GAUGE_W.SymmetrizedDFTHamiltonian()
        target_result = STAR_GAUGE_W.prepare_symmetry_covariant_wavefunctions(
            STAR_GAUGE_W.SymmetryCovariantWavefunctionPreparationConfig(
                construction_policy = :strict,
                source = source,
                wavefunction_gauge_backend = symmetrized_gauge_backend,
                authoritative_hamiltonian = target_authority,
                target_subspace_contract = star_gauge_target_contract(source),
                output_hdf5 = target_hdf5,
                target_band_count = 1,
            ),
        )
        @test target_result.status == :PASS
        @test target_result.root_cause == :SYMMETRIZED_DFT_HAMILTONIAN_PASS
        @test target_result.symmetrized_target_subspace_status == :SYMMETRIZED_DFT_HAMILTONIAN_PASS
        @test target_result.target_scope_production_eligible
        @test !target_result.global_production_eligible
        @test target_result.maxima["target_anchor_wfc_maximum_drift"] == 0.0
        @test target_result.maxima["target_anchor_energy_maximum_drift_ev"] == 0.0
        @test target_result.maxima["target_complement_maximum_element_ev"] == 0.0
        target_auto_restored =
            Base.invokelatest(extension._read_star_covariant_paw_gauge_hdf5, target_hdf5)
        target_restored =
            Base.invokelatest(extension._read_star_covariant_paw_gauge_hdf5, target_hdf5; source)
        @test Base.invokelatest(extension._star_payload_sha256, target_auto_restored.payload) ==
              Base.invokelatest(extension._star_payload_sha256, target_restored.payload)
        generation_contract = Base.invokelatest(
            extension._generation_band_gauge_contract,
            source,
            target_authority,
            target_hdf5,
            size(target_restored.payload.rotations, 1),
            size(target_restored.payload.rotations, 3),
        )
        @test generation_contract.rotations == target_restored.payload.rotations
        @test generation_contract.transform_sha256 ==
              Base.invokelatest(extension._star_array_sha256, target_restored.payload.rotations)
        @test generation_contract.transform_sha256 ==
              something(target_restored.band_frame_contract).transform_sha256
        authority_contract = Base.invokelatest(
            extension._generation_band_gauge_contract,
            source,
            target_authority,
            symmetrized_hdf5,
            size(symmetrized_restored.payload.rotations, 1),
            size(symmetrized_restored.payload.rotations, 3),
        )
        authority_inputs = Dict{String, String}(
            "NATIVE_TO_SYMMETRIZED_ROTATIONS" => Base.invokelatest(
                STAR_GAUGE_OPERATOR_EXPORT._authoritative_array_sha256,
                something(symmetrized_restored.payload.symmetrized_hamiltonian_audit).native_to_symmetrized_rotations,
            ),
        )
        bound_contract = Base.invokelatest(
            STAR_GAUGE_OPERATOR_EXPORT._bind_authority_band_frame!,
            authority_inputs,
            symmetrized_restored,
        )
        @test bound_contract.contract_sha256 == authority_contract.contract_sha256
        @test authority_inputs["BAND_FRAME_TRANSFORM"] == authority_contract.transform_sha256
        @test authority_inputs["BAND_FRAME_CONTRACT"] == authority_contract.contract_sha256
        @test authority_inputs["NATIVE_TO_SYMMETRIZED_ROTATIONS"] !=
              authority_contract.transform_sha256
        authority_matrices = reshape(ComplexF64[0.0], 1, 1, 1)
        authority_digest = Base.invokelatest(
            STAR_GAUGE_OPERATOR_EXPORT._authoritative_band_hamiltonian_digest,
            authority_matrices,
            "symmetrized_dft_hamiltonian",
            authority_inputs,
        )
        generation_authority = Base.invokelatest(
            STAR_GAUGE_OPERATOR_EXPORT.AuthoritativeBandHamiltonian,
            authority_matrices,
            "symmetrized_dft_hamiltonian",
            authority_digest,
            authority_inputs,
            STAR_GAUGE_OPERATOR_EXPORT.AUTHORITATIVE_BAND_HAMILTONIAN_ALGORITHM_VERSION,
            authority_contract.gauge_artifact_sha256,
            true,
        )
        @test isnothing(
            Base.invokelatest(
                STAR_GAUGE_OPERATOR_EXPORT._validate_hamiltonian_authority_frame_binding,
                generation_authority,
                authority_contract,
            ),
        )

        # The sealed representative is a byte-exact serialization authority, while the
        # physical payload remains the tolerance-qualified local-source replay.
        replay_payload = target_restored.payload
        representative = only(replay_payload.star_representatives)
        replay_point = replay_payload.native.kpoints[representative]
        sealed_coefficients = copy(replay_point.coefficients)
        coefficient_index =
            findfirst(value -> isfinite(real(value)) && !iszero(real(value)), sealed_coefficients)
        @test coefficient_index !== nothing
        coefficient_index = something(coefficient_index)
        coefficient = sealed_coefficients[coefficient_index]
        sealed_coefficients[coefficient_index] =
            ComplexF64(nextfloat(real(coefficient)), imag(coefficient))
        sealed_point = Base.invokelatest(
            WannierNLQG.SymmetryFoundation.PlaneWaveKPoint,
            replay_point.k_fractional,
            replay_point.g_vectors,
            sealed_coefficients,
            replay_point.energies_ev;
            normalize_coefficients = false,
        )
        sealed_representatives = Dict(
            index =>
                index == representative ? sealed_point : replay_payload.native.kpoints[index]
            for index in replay_payload.star_representatives
        )
        sealed_payload = Base.invokelatest(
            extension._star_payload_with_sealed_representatives,
            replay_payload,
            sealed_representatives,
        )
        sealed_delta = maximum(abs, sealed_point.coefficients - replay_point.coefficients)
        reconstruction_threshold = Base.invokelatest(
            extension._star_scoped_paw_threshold,
            replay_payload.source_metadata,
            :wfc_rotation_reconstruction,
        )
        @test 0.0 < sealed_delta <= reconstruction_threshold

        ulp_sealed_hdf5 = joinpath(directory, "target-representative-one-ulp-sealed.h5")
        Base.invokelatest(
            extension._write_star_covariant_paw_gauge_hdf5,
            ulp_sealed_hdf5,
            sealed_payload;
            status = :PASS,
            root_cause = :SYMMETRIZED_DFT_HAMILTONIAN_PASS,
            diagnostics = ["one-ULP sealed representative regression"],
        )
        sealed_payload_sha256 = Base.invokelatest(extension._star_payload_sha256, sealed_payload)
        HDF5.h5open(ulp_sealed_hdf5, "r") do handle
            @test String(read(HDF5.attributes(handle)["payload_sha256"])) == sealed_payload_sha256
        end
        ulp_sealed_restored = Base.invokelatest(
            extension._read_star_covariant_paw_gauge_hdf5,
            ulp_sealed_hdf5;
            source,
        )
        @test ulp_sealed_restored.payload.native.kpoints[representative].coefficients ==
              replay_point.coefficients
        @test ulp_sealed_restored.payload.native.kpoints[representative].coefficients !=
              sealed_point.coefficients

        ulp_tampered_hdf5 = joinpath(directory, "target-representative-one-ulp-tampered.h5")
        cp(ulp_sealed_hdf5, ulp_tampered_hdf5)
        representative_name = "kpoint_$(lpad(string(representative), 6, '0'))"
        HDF5.h5open(ulp_tampered_hdf5, "r+") do handle
            dataset = handle["representative_frames/$(representative_name)/coefficients"]
            values = ComplexF64.(read(dataset))
            value = values[coefficient_index]
            values[coefficient_index] = ComplexF64(nextfloat(real(value)), imag(value))
            write(dataset, values)
            @test String(read(HDF5.attributes(handle)["payload_sha256"])) == sealed_payload_sha256
        end
        tamper_error = try
            Base.invokelatest(extension._read_star_covariant_paw_gauge_hdf5, ulp_tampered_hdf5; source)
            nothing
        catch error
            error
        end
        @test tamper_error isa ArgumentError
        @test occursin(
            "PAW_GAUGE_ARTIFACT_TAMPERED: logical payload digest differs",
            sprint(showerror, tamper_error),
        )

        @test target_restored.payload.symmetrized_hamiltonian_audit !== nothing
        @test target_restored.payload.sealed_completed_frame_corrections === nothing
        @test something(target_restored.payload.symmetrized_hamiltonian_audit).target_anchor_sha256_by_star !==
              nothing
        HDF5.h5open(target_hdf5, "r") do handle
            attributes = HDF5.attributes(handle)
            @test String(read(attributes["schema_version"])) == "1.0"
            @test String(read(attributes["authoritative_hamiltonian"])) ==
                  "symmetrized_dft_hamiltonian"
            @test String(read(attributes["qualification_scope"])) == "target_subspace"
            @test String(read(attributes["target_anchor"])) == "completed_symmetrized_target"
            @test String(read(attributes["auxiliary_parent_qualification"])) == "audit_only"
            @test String(read(attributes["symmetrized_target_subspace_status"])) ==
                  "SYMMETRIZED_DFT_HAMILTONIAN_PASS"
            @test Bool(read(attributes["target_scope_production_eligible"]))
            @test String(read(attributes["nonrepresentative_frame_storage"])) ==
                  "local_native_source_plus_completed_rotation"
            @test !haskey(handle, "sealed_completed_frame_corrections")
            @test haskey(handle["symmetrized_hamiltonian_audit"], "complement_rotations")
            @test haskey(
                handle["symmetrized_hamiltonian_audit"],
                "target_complement_hamiltonians_ev",
            )
        end
        missing_root_scope = joinpath(directory, "missing-root-qualification-scope.h5")
        cp(target_hdf5, missing_root_scope)
        HDF5.h5open(missing_root_scope, "r+") do handle
            HDF5.delete_attribute(handle, "qualification_scope")
        end
        @test_throws ArgumentError Base.invokelatest(
            extension._read_star_covariant_paw_gauge_hdf5,
            missing_root_scope;
            source,
        )
        tampered_root_scope = joinpath(directory, "tampered-root-qualification-scope.h5")
        cp(target_hdf5, tampered_root_scope)
        HDF5.h5open(tampered_root_scope, "r+") do handle
            HDF5.delete_attribute(handle, "qualification_scope")
            HDF5.attributes(handle)["qualification_scope"] = "parent_full_audit"
        end
        @test_throws ArgumentError Base.invokelatest(
            extension._read_star_covariant_paw_gauge_hdf5,
            tampered_root_scope;
            source,
        )
        tampered_root_authority = joinpath(directory, "tampered-root-authority.h5")
        cp(target_hdf5, tampered_root_authority)
        HDF5.h5open(tampered_root_authority, "r+") do handle
            HDF5.delete_attribute(handle, "authoritative_hamiltonian")
            HDF5.attributes(handle)["authoritative_hamiltonian"] = "native_dft"
        end
        @test_throws ArgumentError Base.invokelatest(
            extension._read_star_covariant_paw_gauge_hdf5,
            tampered_root_authority;
            source,
        )
        legacy_weight_schema = joinpath(directory, "legacy-target-leakage-schema.h5")
        cp(target_hdf5, legacy_weight_schema)
        HDF5.h5open(legacy_weight_schema, "r+") do handle
            HDF5.delete_attribute(handle, "schema_version")
            HDF5.attributes(handle)["schema_version"] = "1.9"
        end
        legacy_weight_error = try
            Base.invokelatest(
                extension._read_star_covariant_paw_gauge_hdf5,
                legacy_weight_schema;
                source,
            )
            nothing
        catch exception
            sprint(showerror, exception)
        end
        @test occursin(
            "UNSUPPORTED_LEGACY_TARGET_LEAKAGE_SEMANTICS",
            something(legacy_weight_error, ""),
        )
        missing_descriptor = joinpath(directory, "missing-source-replay-descriptor.h5")
        cp(target_hdf5, missing_descriptor)
        HDF5.h5open(missing_descriptor, "r+") do handle
            HDF5.delete_attribute(handle["source_metadata"], "source_replay_schema")
        end
        @test_throws ArgumentError Base.invokelatest(
            extension._read_star_covariant_paw_gauge_hdf5,
            missing_descriptor,
        )
        tampered_descriptor = joinpath(directory, "tampered-source-replay-descriptor.h5")
        cp(target_hdf5, tampered_descriptor)
        HDF5.h5open(tampered_descriptor, "r+") do handle
            metadata = HDF5.attributes(handle["source_metadata"])
            HDF5.delete_attribute(handle["source_metadata"], "source_replay_kind")
            metadata["source_replay_kind"] = "unsupported"
        end
        @test_throws ArgumentError Base.invokelatest(
            extension._read_star_covariant_paw_gauge_hdf5,
            tampered_descriptor,
        )
        missing_source_path = joinpath(directory, "missing-source-replay-path.h5")
        cp(target_hdf5, missing_source_path)
        HDF5.h5open(missing_source_path, "r+") do handle
            HDF5.delete_attribute(handle["source_metadata"], "source_replay_save_directory")
        end
        @test_throws ArgumentError Base.invokelatest(
            extension._read_star_covariant_paw_gauge_hdf5,
            missing_source_path,
        )
        alternate_save_directory = joinpath(directory, "alternate-source.save")
        cp(fixture.save_directory, alternate_save_directory)
        tampered_source_path = joinpath(directory, "tampered-source-replay-path.h5")
        cp(target_hdf5, tampered_source_path)
        HDF5.h5open(tampered_source_path, "r+") do handle
            metadata = HDF5.attributes(handle["source_metadata"])
            HDF5.delete_attribute(handle["source_metadata"], "source_replay_save_directory")
            metadata["source_replay_save_directory"] = alternate_save_directory
        end
        @test_throws ArgumentError Base.invokelatest(
            extension._read_star_covariant_paw_gauge_hdf5,
            tampered_source_path,
        )
        missing_source_hash = joinpath(directory, "missing-source-replay-hash.h5")
        cp(target_hdf5, missing_source_hash)
        HDF5.h5open(missing_source_hash, "r+") do handle
            HDF5.delete_attribute(handle["input_sha256"], "data-file-schema.xml")
        end
        @test_throws ArgumentError Base.invokelatest(
            extension._read_star_covariant_paw_gauge_hdf5,
            missing_source_hash,
        )
        tampered_rotation = joinpath(directory, "tampered-completed-rotation.h5")
        cp(target_hdf5, tampered_rotation)
        HDF5.h5open(tampered_rotation, "r+") do handle
            dataset = handle["native_to_completed_rotations"]
            values = read(dataset)
            values[1] += 1.0e-4
            write(dataset, values)
        end
        @test_throws ArgumentError Base.invokelatest(
            extension._read_star_covariant_paw_gauge_hdf5,
            tampered_rotation;
            source,
        )
        nonfinite_rotation = joinpath(directory, "nonfinite-completed-rotation.h5")
        cp(target_hdf5, nonfinite_rotation)
        HDF5.h5open(nonfinite_rotation, "r+") do handle
            dataset = handle["native_to_completed_rotations"]
            values = read(dataset)
            values[1] = ComplexF64(NaN, 0.0)
            write(dataset, values)
        end
        @test_throws ArgumentError Base.invokelatest(
            extension._read_star_covariant_paw_gauge_hdf5,
            nonfinite_rotation;
            source,
        )
        wrong_rotation_shape = joinpath(directory, "wrong-shape-completed-rotation.h5")
        cp(target_hdf5, wrong_rotation_shape)
        HDF5.h5open(wrong_rotation_shape, "r+") do handle
            values = read(handle["native_to_completed_rotations"])
            HDF5.delete_object(handle, "native_to_completed_rotations")
            handle["native_to_completed_rotations"] =
                cat(values, zeros(ComplexF64, 1, size(values, 2), size(values, 3)); dims = 1)
        end
        @test_throws ArgumentError Base.invokelatest(
            extension._read_star_covariant_paw_gauge_hdf5,
            wrong_rotation_shape;
            source,
        )
        tampered_hash = joinpath(directory, "tampered-source-hash.h5")
        cp(target_hdf5, tampered_hash)
        HDF5.h5open(tampered_hash, "r+") do handle
            hashes = HDF5.attributes(handle["input_sha256"])
            HDF5.delete_attribute(handle["input_sha256"], "data-file-schema.xml")
            hashes["data-file-schema.xml"] = repeat("0", 64)
        end
        @test_throws ArgumentError Base.invokelatest(
            extension._read_star_covariant_paw_gauge_hdf5,
            tampered_hash;
            source,
        )
        wrong_band_source = WannierNLQG.SymmetryFoundation.QuantumEspressoWavefunctionSource(
            fixture.save_directory;
            band_range = 2:2,
            include_time_reversal = false,
        )
        @test_throws ArgumentError Base.invokelatest(
            extension._read_star_covariant_paw_gauge_hdf5,
            target_hdf5;
            source = wrong_band_source,
        )
        tampered_save_directory = joinpath(directory, "tampered-source.save")
        cp(fixture.save_directory, tampered_save_directory)
        open(joinpath(tampered_save_directory, "data-file-schema.xml"), "a") do io
            write(io, "\n<!-- provenance tamper -->\n")
        end
        tampered_source = WannierNLQG.SymmetryFoundation.QuantumEspressoWavefunctionSource(
            tampered_save_directory;
            band_range = 1:1,
            include_time_reversal = false,
        )
        @test_throws ArgumentError Base.invokelatest(
            extension._read_star_covariant_paw_gauge_hdf5,
            target_hdf5;
            source = tampered_source,
        )
        target_matrix_result = STAR_GAUGE_W.generate_symmetry_completed_qe_paw_matrix_elements(
            source,
            target_hdf5,
            fixture.nnkp_file;
            artifact_dir = joinpath(directory, "target-matrices"),
        )
        @test target_matrix_result.passed
        HDF5.h5open(target_matrix_result.artifacts["provenance_hdf5"], "r") do handle
            parity = handle["direct_vs_rotation"]
            @test haskey(parity, "parent_mmn")
            @test haskey(parity, "parent_amn")
            @test haskey(HDF5.attributes(handle), "parent_generalized_norm_max_absolute")
            diagnostics = String.(read(handle["diagnostics"]))
            @test any(
                ==("parent_matrix_identity=completed_parent_direct_vs_rotation_TT_TC_CT_CC"),
                diagnostics,
            )
        end
        target_representation_hdf5 = joinpath(directory, "target-representation.h5")
        target_prepared = STAR_GAUGE_W.prepare_band_representation(
            STAR_GAUGE_W.BandRepresentationPreparationConfig(
                construction_policy = :strict,
                wannierization_mode = :symmetry_adapted,
                source = source,
                sewing_backend = STAR_GAUGE_W.AugmentationAwareSewing(),
                wavefunction_gauge_backend = symmetrized_gauge_backend,
                authoritative_hamiltonian = target_authority,
                wavefunction_gauge_hdf5 = target_hdf5,
                win_file = win_file,
                eig_file = splitext(target_hdf5)[1] * ".eig",
                projection_basis = projection_basis,
                output_hdf5 = target_representation_hdf5,
                outer_min_ev = -18.0,
                outer_max_ev = 3.5,
                frozen_min_ev = -18.0,
                frozen_max_ev = 0.5,
                num_wannier = 1,
                compatibility_policy = :off,
            ),
        )
        @test target_prepared.representation.schema_version == "1.0"
        @test target_prepared.representation.conventions["qualification_scope"] == "target_subspace"
        HDF5.h5open(target_representation_hdf5, "r") do handle
            @test String(read(HDF5.attributes(handle)["schema_version"])) == "1.0"
        end
        target_provided_solver_config = STAR_GAUGE_W.SymmetryAdaptedWannierizationConfig(
            input = STAR_GAUGE_W.WannierizationInputConfig(
                construction_policy = :strict,
                wannierization_mode = :symmetry_adapted,
                sewing_backend = STAR_GAUGE_W.AugmentationAwareSewing(),
                wavefunction_gauge_backend = symmetrized_gauge_backend,
                authoritative_hamiltonian = target_authority,
                wavefunction_gauge_hdf5 = target_hdf5,
                win_file = win_file,
                eig_file = splitext(target_hdf5)[1] * ".eig",
                mmn_file = target_matrix_result.artifacts["mmn"],
                amn_file = target_matrix_result.artifacts["amn"],
                matrix_elements = STAR_GAUGE_W.ExternalWannier90Matrices(
                    target_matrix_result.artifacts["mmn"],
                    target_matrix_result.artifacts["amn"],
                ),
                projection_basis = projection_basis,
                band_representation_hdf5 = target_representation_hdf5,
                outer_min_ev = -18.0,
                outer_max_ev = 3.5,
                frozen_min_ev = -18.0,
                frozen_max_ev = 0.5,
                num_wannier = 1,
                compatibility_policy = :off,
            ),
            solver = STAR_GAUGE_W.WannierizationSolverConfig(localize = false),
            checkpoint = STAR_GAUGE_W.WannierizationCheckpointConfig(),
            runtime = STAR_GAUGE_W.WannierizationRuntimeConfig(),
            output = STAR_GAUGE_W.WannierizationOutputConfig(),
        )
        @test isnothing(STAR_GAUGE_W._validate_wannierization_config(target_provided_solver_config))
        target_provided_preparation = STAR_GAUGE_W.prepare_band_representation(
            STAR_GAUGE_W.BandRepresentationPreparationConfig(
                construction_policy = :strict,
                wannierization_mode = :symmetry_adapted,
                sewing_backend = STAR_GAUGE_W.AugmentationAwareSewing(),
                wavefunction_gauge_backend = symmetrized_gauge_backend,
                authoritative_hamiltonian = target_authority,
                wavefunction_gauge_hdf5 = target_hdf5,
                win_file = win_file,
                eig_file = splitext(target_hdf5)[1] * ".eig",
                projection_basis = projection_basis,
                band_representation_hdf5 = target_representation_hdf5,
                outer_min_ev = -18.0,
                outer_max_ev = 3.5,
                frozen_min_ev = -18.0,
                frozen_max_ev = 0.5,
                num_wannier = 1,
                compatibility_policy = :off,
            ),
        )
        @test target_provided_preparation.representation.schema_version == "1.0"
        target_fresh_output = read(
            `$(Base.julia_cmd()) --startup-file=no --project=$(dirname(@__DIR__)) $(fresh_probe) $(target_hdf5) $(target_representation_hdf5) $(fixture.save_directory)`,
            String,
        )
        target_fresh_auto_output = read(
            `$(Base.julia_cmd()) --startup-file=no --project=$(dirname(@__DIR__)) $(fresh_probe) $(target_hdf5) $(target_representation_hdf5)`,
            String,
        )
        @test occursin(
            r"SYMMETRIZED_DFT_HAMILTONIAN_FRESH_READ_DIGEST=[0-9a-f]{64}",
            target_fresh_output,
        )
        target_payload_sha256 =
            Base.invokelatest(extension._star_payload_sha256, target_restored.payload)
        @test occursin(
            "SYMMETRIZED_DFT_HAMILTONIAN_FRESH_READ_PAYLOAD_SHA256=$(target_payload_sha256)",
            target_fresh_output,
        )
        @test occursin(
            "SYMMETRIZED_DFT_HAMILTONIAN_FRESH_READ_PAYLOAD_SHA256=$(target_payload_sha256)",
            target_fresh_auto_output,
        )
        mismatched_authority = STAR_GAUGE_W.SymmetrizedDFTHamiltonian(
            maximum_energy_shift_audit_reference_ev = 6.0e-6,
            rms_energy_shift_audit_reference_ev = 1.0e-6,
        )
        @test_throws ArgumentError STAR_GAUGE_W.prepare_band_representation(
            STAR_GAUGE_W.BandRepresentationPreparationConfig(
                construction_policy = :strict,
                wannierization_mode = :symmetry_adapted,
                source = source,
                sewing_backend = STAR_GAUGE_W.AugmentationAwareSewing(),
                wavefunction_gauge_backend = symmetrized_gauge_backend,
                authoritative_hamiltonian = mismatched_authority,
                wavefunction_gauge_hdf5 = symmetrized_hdf5,
                win_file = win_file,
                eig_file = splitext(symmetrized_hdf5)[1] * ".eig",
                projection_basis = projection_basis,
                output_hdf5 = joinpath(directory, "mismatched-audit-reference.h5"),
                outer_min_ev = -18.0,
                outer_max_ev = 3.5,
                frozen_min_ev = -18.0,
                frozen_max_ev = 0.5,
                num_wannier = 1,
                compatibility_policy = :off,
            ),
        )

        tampered_audit = joinpath(directory, "tampered-audit-reference.h5")
        cp(symmetrized_hdf5, tampered_audit)
        HDF5.h5open(tampered_audit, "r+") do handle
            attributes = HDF5.attributes(handle)
            HDF5.delete_attribute(handle, "maximum_energy_shift_audit_reference_ev")
            attributes["maximum_energy_shift_audit_reference_ev"] = "6.0e-6"
        end
        @test_throws ArgumentError Base.invokelatest(
            extension._read_star_covariant_paw_gauge_hdf5,
            tampered_audit;
            source,
        )
        tampered_gate_phase = joinpath(directory, "tampered-gate-phase.h5")
        cp(symmetrized_hdf5, tampered_gate_phase)
        HDF5.h5open(tampered_gate_phase, "r+") do handle
            attributes = HDF5.attributes(handle)
            HDF5.delete_attribute(handle, "residual_gate_phase")
            attributes["residual_gate_phase"] = "pre_symmetrization"
        end
        @test_throws ArgumentError Base.invokelatest(
            extension._read_star_covariant_paw_gauge_hdf5,
            tampered_gate_phase;
            source,
        )
        tampered_native_difference = joinpath(directory, "tampered-native-difference.h5")
        cp(symmetrized_hdf5, tampered_native_difference)
        HDF5.h5open(tampered_native_difference, "r+") do handle
            attributes = HDF5.attributes(handle)
            HDF5.delete_attribute(handle, "native_difference_qualification")
            attributes["native_difference_qualification"] = "hard_gate"
        end
        @test_throws ArgumentError Base.invokelatest(
            extension._read_star_covariant_paw_gauge_hdf5,
            tampered_native_difference;
            source,
        )

        matrix_result = STAR_GAUGE_W.generate_symmetry_completed_qe_paw_matrix_elements(
            source,
            gauge_hdf5,
            fixture.nnkp_file;
            artifact_dir = joinpath(directory, "matrices"),
        )
        @test matrix_result.passed
        @test matrix_result.mmn_parity.max_absolute <= 1.0e-12
        @test matrix_result.amn_parity.max_absolute <= 1.0e-12

        diagnostic_gauge = joinpath(directory, "diagnostic-only-gauge.h5")
        Base.invokelatest(
            extension._write_star_covariant_paw_gauge_hdf5,
            diagnostic_gauge,
            restored.payload;
            status = :DIAGNOSTIC_ONLY,
            root_cause = :CONTROLLED_SYMMETRIZATION_HOLD,
            diagnostics = ["synthetic diagnostic-only qualification test"],
        )
        @test_throws ArgumentError Base.invokelatest(
            extension._read_star_covariant_paw_gauge_hdf5,
            diagnostic_gauge,
        )
        diagnostic_restored = Base.invokelatest(
            extension._read_star_covariant_paw_gauge_hdf5,
            diagnostic_gauge;
            require_pass = false,
        )
        @test diagnostic_restored.status == :DIAGNOSTIC_ONLY
        @test_throws ArgumentError STAR_GAUGE_W.generate_symmetry_completed_qe_paw_matrix_elements(
            source,
            diagnostic_gauge,
            fixture.nnkp_file;
            artifact_dir = joinpath(directory, "diagnostic-matrices-strict-rejected"),
        )
        diagnostic_matrix_result = STAR_GAUGE_W.generate_symmetry_completed_qe_paw_matrix_elements(
            source,
            diagnostic_gauge,
            fixture.nnkp_file;
            artifact_dir = joinpath(directory, "diagnostic-matrices"),
            qualification_mode = :diagnostic_only,
        )
        @test diagnostic_matrix_result.passed
        @test occursin("DIAGNOSTIC_ONLY", basename(diagnostic_matrix_result.artifacts["mmn"]))
        HDF5.h5open(diagnostic_matrix_result.artifacts["provenance_hdf5"], "r") do handle
            attributes = HDF5.attributes(handle)
            @test Bool(read(attributes["diagnostic_only"]))
            @test !Bool(read(attributes["production_eligible"]))
        end

        tampered = joinpath(directory, "tampered.h5")
        cp(gauge_hdf5, tampered)
        HDF5.h5open(tampered, "r+") do handle
            dataset = handle["representative_frames/kpoint_000001/coefficients"]
            values = read(dataset)
            values[1] += 1.0e-4
            write(dataset, values)
        end
        @test_throws ArgumentError Base.invokelatest(
            extension._read_star_covariant_paw_gauge_hdf5,
            tampered,
        )
    end
end
