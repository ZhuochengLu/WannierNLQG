"""Typed terminal state for one SAWF construction attempt."""
@enum WannierizationStatus::UInt8 begin
    IN_PROGRESS_CHECKPOINT
    COMPLETED
    COMPLETED_WITH_WARNINGS
    MAX_ITERATIONS
    REPRESENTATION_INCOMPATIBLE
    REPRESENTATION_VALIDATION_UNDETERMINED
    SINGULAR_LOCALIZATION
    INVALID_INPUT
    IO_FAILURE
    LOCALIZATION_FAILED
end

"""Whether the validation rule itself is usable for the supplied evidence."""
@enum RepresentationGateDefinitionStatus::UInt8 begin
    GATE_NOT_EVALUATED
    GATE_VALID
    GATE_DEFINITION_INVALID
end

"""Scientific assessment after separating gate validity from representation quality."""
@enum RepresentationAssessmentStatus::UInt8 begin
    REPRESENTATION_UNDETERMINED
    REPRESENTATION_COMPATIBLE
    REPRESENTATION_INCOMPATIBLE_ASSESSMENT
end

"""Expert marker for a native Bloch-band sewing construction backend."""
abstract type AbstractBandSewingBackend end

"""Preserve the legacy plane-wave coefficient-map/right-inverse sewing route."""
struct CoefficientMappingSewing <: AbstractBandSewingBackend end

"""
Fail-closed numerical thresholds for augmentation-aware PAW/USPP sewing.

The target-leakage gate is a dimensionless PAW-S probability weight.  State,
reconstruction, and the two directed target/complement weights share the
single `target_leakage_weight` limit.  Other residuals retain their declared
amplitude semantics.  Operation group-law and cocycle gates default to `2e-5`.
"""
struct PAWSewingThresholds
    generalized_norm::Float64
    reconstruction::Float64
    state_leakage_amplitude::Float64
    target_leakage_weight::Float64
    nondegenerate_block_leakage::Float64
    raw_unitarity::Float64
    normalized_polar_correction::Float64
    group_law::Float64
    cocycle::Float64

    function PAWSewingThresholds(;
        generalized_norm::Real = 5.0e-6,
        reconstruction::Real = 5.0e-6,
        state_leakage_amplitude::Real = 5.0e-6,
        target_leakage_weight::Real = 5.0e-6,
        nondegenerate_block_leakage::Real = 5.0e-6,
        raw_unitarity::Real = 5.0e-6,
        normalized_polar_correction::Real = 5.0e-6,
        group_law::Real = 2.0e-5,
        cocycle::Real = 2.0e-5,
    )
        values = Float64[
            generalized_norm,
            reconstruction,
            state_leakage_amplitude,
            target_leakage_weight,
            nondegenerate_block_leakage,
            raw_unitarity,
            normalized_polar_correction,
            group_law,
            cocycle,
        ]
        all(value -> isfinite(value) && value > 0.0, values) ||
            throw(ArgumentError("PAW sewing thresholds must be positive and finite"))
        return new(values...)
    end
end

"""Use the native PAW/USPP `C†C + P†Q₀P` sewing matrix element."""
struct AugmentationAwareSewing <: AbstractBandSewingBackend
    thresholds::PAWSewingThresholds

    function AugmentationAwareSewing(; thresholds::PAWSewingThresholds = PAWSewingThresholds())
        return new(thresholds)
    end
end

"""Return the stable persisted identity of an expert sewing backend."""
_band_sewing_backend_key(::CoefficientMappingSewing) = "coefficient_mapping"
"""Return the persisted identity of the strict PAW q=0 sewing backend."""
_band_sewing_backend_key(::AugmentationAwareSewing) = "augmentation_aware_paw_q0"

"""Expert marker for the native-Bloch wavefunction gauge supplied to band sewing."""
abstract type AbstractWavefunctionGaugeBackend end

"""Keep the independently diagonalized native eigenstate gauge unchanged."""
struct NativeEigenstateGauge <: AbstractWavefunctionGaugeBackend end

"""
Bound a closure-driven enlargement of the native band workspace.

Complete adjacent energy clusters are admitted only while they remain inside
`hard_energy_cap_ev` and the total number of additional native bands does not
exceed `max_extra_bands`. The retained SAWF band dimension is unchanged.
"""
struct ClosureDrivenBandBuffer
    cluster_tolerance_ev::Float64
    hard_energy_cap_ev::Float64
    max_extra_bands::Int

    function ClosureDrivenBandBuffer(;
        cluster_tolerance_ev::Real = 5.0e-3,
        hard_energy_cap_ev::Real = 0.10,
        max_extra_bands::Integer = 8,
    )
        cluster = Float64(cluster_tolerance_ev)
        cap = Float64(hard_energy_cap_ev)
        extra = Int(max_extra_bands)
        isfinite(cluster) && cluster > 0.0 ||
            throw(ArgumentError("cluster_tolerance_ev must be positive and finite"))
        isfinite(cap) && cap > 0.0 ||
            throw(ArgumentError("hard_energy_cap_ev must be positive and finite"))
        extra >= 0 || throw(ArgumentError("max_extra_bands must be nonnegative"))
        return new(cluster, cap, extra)
    end
end

"""Expert policy controlling how physical PAW sewing evidence joins energy clusters."""
abstract type AbstractPAWBlockPartitionPolicy end

"""Preserve the legacy rule that joins only above-threshold couplings within one gap."""
struct FixedGapPAWBlockPartition <: AbstractPAWBlockPartitionPolicy
    max_gap_ev::Float64

    function FixedGapPAWBlockPartition(; max_gap_ev::Real = 2.0e-2)
        gap = Float64(max_gap_ev)
        isfinite(gap) && gap > 0.0 || throw(ArgumentError("max_gap_ev must be positive and finite"))
        return new(gap)
    end
end

"""
Bound an evidence-driven PAW block closure without admitting remote band cascades.

Every above-threshold edge is treated as physical evidence.  Edges beyond
`hard_edge_gap_ev`, components wider than `hard_component_span_ev`, and components
larger than `max_component_bands` fail closed.  `max_search_states` bounds the
deterministic partition search and is persisted for audit even when the mandatory
evidence closure has a unique minimal state.
"""
struct AdaptiveEvidencePAWBlockPartition <: AbstractPAWBlockPartitionPolicy
    soft_gap_ev::Float64
    hard_edge_gap_ev::Float64
    hard_component_span_ev::Float64
    max_component_bands::Int
    max_search_states::Int

    function AdaptiveEvidencePAWBlockPartition(;
        soft_gap_ev::Real = 2.0e-2,
        hard_edge_gap_ev::Real = 1.0e-1,
        hard_component_span_ev::Real = 1.0e-1,
        max_component_bands::Integer = 12,
        max_search_states::Integer = 512,
    )
        soft = Float64(soft_gap_ev)
        hard_edge = Float64(hard_edge_gap_ev)
        hard_span = Float64(hard_component_span_ev)
        maximum_bands = Int(max_component_bands)
        maximum_states = Int(max_search_states)
        all(value -> isfinite(value) && value > 0.0, (soft, hard_edge, hard_span)) ||
            throw(ArgumentError("PAW block-partition energy bounds must be positive and finite"))
        soft <= hard_edge || throw(ArgumentError("soft_gap_ev must not exceed hard_edge_gap_ev"))
        hard_span <= hard_edge ||
            throw(ArgumentError("hard_component_span_ev must not exceed hard_edge_gap_ev"))
        maximum_bands > 0 || throw(ArgumentError("max_component_bands must be positive"))
        maximum_states > 0 || throw(ArgumentError("max_search_states must be positive"))
        return new(soft, hard_edge, hard_span, maximum_bands, maximum_states)
    end
end

"""Energy-scale gates for cross-block PAW Hamiltonian residuals."""
struct PAWHamiltonianResidualThresholds
    pair_ev::Float64
    operator_ev::Float64
    source_column_l2_ev::Float64
    normalized_frobenius_ev::Float64

    function PAWHamiltonianResidualThresholds(;
        pair_ev::Real = 5.0e-6,
        operator_ev::Real = 5.0e-6,
        source_column_l2_ev::Real = 5.0e-6,
        normalized_frobenius_ev::Real = 5.0e-6,
    )
        values = Float64[pair_ev, operator_ev, source_column_l2_ev, normalized_frobenius_ev]
        all(value -> isfinite(value) && value > 0.0, values) ||
            throw(ArgumentError("PAW Hamiltonian-residual thresholds must be positive and finite"))
        return new(values...)
    end
end

"""Numerical-reference gates for cancellation-sensitive pseudo plus PAW sums."""
struct PAWCancellationStabilityThresholds
    accumulation_absolute::Float64
    inverse_absolute::Float64
    orbit_absolute::Float64
    bigfloat_precision_bits::Int

    function PAWCancellationStabilityThresholds(;
        accumulation_absolute::Real = 5.0e-10,
        inverse_absolute::Real = 5.0e-10,
        orbit_absolute::Real = 5.0e-10,
        bigfloat_precision_bits::Integer = 256,
    )
        values = Float64[accumulation_absolute, inverse_absolute, orbit_absolute]
        all(value -> isfinite(value) && value > 0.0, values) || throw(
            ArgumentError("PAW cancellation-stability thresholds must be positive and finite"),
        )
        precision = Int(bigfloat_precision_bits)
        precision >= 128 || throw(ArgumentError("bigfloat_precision_bits must be at least 128"))
        return new(values..., precision)
    end
end

"""
Merge only near-degenerate PAW evidence and qualify remote mixing by `Delta E * |B|`.

The absolute coupling tolerance remains owned by `PAWGaugeThresholds`. Remote
entries never become merge edges. Their pair residual remains fail-closed. The
dimension-stable cumulative residuals retain the thresholds in
`residual_thresholds`, but may be diagnostic before gauge construction; the
unmasked post-gauge covariance always remains strict.
"""
struct HamiltonianWeightedPAWBlockPartition <: AbstractPAWBlockPartitionPolicy
    near_gap_ev::Float64
    hard_component_span_ev::Float64
    max_component_bands::Int
    residual_thresholds::PAWHamiltonianResidualThresholds
    cancellation_thresholds::PAWCancellationStabilityThresholds
    pre_gauge_cumulative_mode::Symbol

    function HamiltonianWeightedPAWBlockPartition(;
        near_gap_ev::Real = 2.0e-2,
        hard_component_span_ev::Real = 1.0e-1,
        max_component_bands::Integer = 12,
        residual_thresholds::PAWHamiltonianResidualThresholds = PAWHamiltonianResidualThresholds(),
        cancellation_thresholds::PAWCancellationStabilityThresholds = PAWCancellationStabilityThresholds(),
        pre_gauge_cumulative_mode::Symbol = :diagnostic,
    )
        near_gap = Float64(near_gap_ev)
        hard_span = Float64(hard_component_span_ev)
        maximum_bands = Int(max_component_bands)
        isfinite(near_gap) && near_gap > 0.0 ||
            throw(ArgumentError("near_gap_ev must be positive and finite"))
        isfinite(hard_span) && hard_span >= near_gap || throw(
            ArgumentError("hard_component_span_ev must be finite and not smaller than near_gap_ev"),
        )
        maximum_bands > 0 || throw(ArgumentError("max_component_bands must be positive"))
        pre_gauge_cumulative_mode in (:diagnostic, :fail_stop) ||
            throw(ArgumentError("pre_gauge_cumulative_mode must be :diagnostic or :fail_stop"))
        return new(
            near_gap,
            hard_span,
            maximum_bands,
            residual_thresholds,
            cancellation_thresholds,
            pre_gauge_cumulative_mode,
        )
    end
end

"""Return the stable persisted key of one PAW energy-block policy."""
_paw_block_partition_policy_key(::FixedGapPAWBlockPartition) = "fixed_gap"

"""Return the stable persisted key of the adaptive PAW energy-block policy."""
_paw_block_partition_policy_key(::AdaptiveEvidencePAWBlockPartition) = "adaptive_evidence"

"""Return the persisted identity of the Hamiltonian-weighted PAW block policy."""
_paw_block_partition_policy_key(
    ::HamiltonianWeightedPAWBlockPartition,
) = "hamiltonian_weighted_far_band"

"""Select the Hamiltonian whose eigenpairs and symmetry gates are authoritative downstream."""
abstract type AbstractAuthoritativeHamiltonian end

"""Keep the original independently diagonalized DFT Hamiltonian authoritative."""
struct NativeDFTHamiltonian <: AbstractAuthoritativeHamiltonian end

"""Expert policy that freezes the completed target frame and completes only its complement."""
struct FrozenTargetComplementCompletion
    target_complement_max_element_ev::Float64

    function FrozenTargetComplementCompletion(; target_complement_max_element_ev::Real = 5.0e-6)
        threshold = Float64(target_complement_max_element_ev)
        isfinite(threshold) && threshold > 0.0 ||
            throw(ArgumentError("target_complement_max_element_ev must be positive and finite"))
        return new(threshold)
    end
end

"""
Use the symmetrized DFT Hamiltonian only as authority for the target subspace.

The completed target states are immutable anchors.  The remaining parent states
are auxiliary and may be rediagonalized only inside their PAW-S orthogonal
complement. Native fidelity, energy shifts, and complete-parent quality remain
audit-only; formal residual gates are evaluated after target symmetrization.
"""
struct SymmetrizedDFTHamiltonian <: AbstractAuthoritativeHamiltonian
    completion::FrozenTargetComplementCompletion
    qualification_scope::Symbol
    target_anchor::Symbol
    auxiliary_parent_qualification::Symbol
    maximum_energy_shift_audit_reference_ev::Float64
    rms_energy_shift_audit_reference_ev::Float64
    residual_gate_phase::Symbol
    native_difference_qualification::Symbol

    function SymmetrizedDFTHamiltonian(;
        completion::FrozenTargetComplementCompletion = FrozenTargetComplementCompletion(),
        qualification_scope::Symbol = :target_subspace,
        target_anchor::Symbol = :completed_symmetrized_target,
        auxiliary_parent_qualification::Symbol = :audit_only,
        maximum_energy_shift_audit_reference_ev::Real = 5.0e-6,
        rms_energy_shift_audit_reference_ev::Real = 1.0e-6,
        residual_gate_phase::Symbol = :post_symmetrization,
        native_difference_qualification::Symbol = :audit_only,
    )
        qualification_scope == :target_subspace || throw(
            ArgumentError("SymmetrizedDFTHamiltonian qualification_scope must be :target_subspace"),
        )
        target_anchor == :completed_symmetrized_target || throw(
            ArgumentError(
                "SymmetrizedDFTHamiltonian target_anchor must be :completed_symmetrized_target",
            ),
        )
        auxiliary_parent_qualification == :audit_only || throw(
            ArgumentError(
                "SymmetrizedDFTHamiltonian auxiliary_parent_qualification must be :audit_only",
            ),
        )
        references =
            Float64[maximum_energy_shift_audit_reference_ev, rms_energy_shift_audit_reference_ev]
        all(value -> isfinite(value) && value > 0.0, references) || throw(
            ArgumentError(
                "symmetrized-DFT-Hamiltonian energy-shift audit references must be positive and finite",
            ),
        )
        residual_gate_phase == :post_symmetrization || throw(
            ArgumentError(
                "SymmetrizedDFTHamiltonian residual_gate_phase must be :post_symmetrization",
            ),
        )
        native_difference_qualification == :audit_only || throw(
            ArgumentError(
                "SymmetrizedDFTHamiltonian native_difference_qualification must be :audit_only",
            ),
        )
        return new(
            completion,
            qualification_scope,
            target_anchor,
            auxiliary_parent_qualification,
            references...,
            residual_gate_phase,
            native_difference_qualification,
        )
    end
end

"""Return the stable persisted identity of the authoritative Hamiltonian."""
authoritative_hamiltonian_key(::NativeDFTHamiltonian) =
    SymmetryFoundation.validate_authoritative_hamiltonian_key("native_dft")

"""Return the persisted identity of target-scoped symmetrized DFT authority."""
authoritative_hamiltonian_key(::SymmetrizedDFTHamiltonian) =
    SymmetryFoundation.validate_authoritative_hamiltonian_key("symmetrized_dft_hamiltonian")

"""Return whether an authority uses a Reynolds-projected Hamiltonian."""
_is_symmetrized_authority(authority::AbstractAuthoritativeHamiltonian) =
    authority isa SymmetrizedDFTHamiltonian

"""Expert policy for an explicit modification of the discrete parent Hamiltonian."""
abstract type AbstractDiscreteHamiltonianCorrection end

"""Keep the PAW-S-orthogonal native discrete Hamiltonian unchanged."""
struct NoDiscreteHamiltonianCorrection <: AbstractDiscreteHamiltonianCorrection end

"""
Frozen gates for controlled restoration of discrete Hamiltonian covariance.

The wavefunction gates apply only to the far-block near-identity rotation.  A
possibly large unitary rotation within a near-degenerate block remains a gauge
choice and is reported separately.  Hamiltonian gates are in eV.
"""
struct ControlledHamiltonianSymmetryThresholds
    far_rotation_operator::Float64
    far_rotation_normalized_frobenius::Float64
    hamiltonian_correction_operator_ev::Float64
    hamiltonian_correction_normalized_frobenius_ev::Float64

    function ControlledHamiltonianSymmetryThresholds(;
        far_rotation_operator::Real = 5.0e-4,
        far_rotation_normalized_frobenius::Real = 2.0e-4,
        hamiltonian_correction_operator_ev::Real = 1.0e-5,
        hamiltonian_correction_normalized_frobenius_ev::Real = 5.0e-6,
    )
        values = Float64[
            far_rotation_operator,
            far_rotation_normalized_frobenius,
            hamiltonian_correction_operator_ev,
            hamiltonian_correction_normalized_frobenius_ev,
        ]
        all(value -> isfinite(value) && value > 0.0, values) || throw(
            ArgumentError("controlled Hamiltonian-symmetry thresholds must be positive and finite"),
        )
        return new(values...)
    end
end

"""
Restore far-band covariance by a controlled change of the discrete Hamiltonian.

This backend is deliberately not described as a gauge-only operation.  It
Reynolds-projects the full PAW-S-orthogonal parent Hamiltonian, solves the
far-block Sylvester equation for a near-identity unitary, and records the
Hamiltonian, energy, and wavefunction changes.  `qualification_mode=:strict`
is production-capable only when every physical gate passes;
`:diagnostic_only` permanently taints all downstream artifacts.
"""
struct FarBandCovarianceCorrection <: AbstractDiscreteHamiltonianCorrection
    thresholds::ControlledHamiltonianSymmetryThresholds
    qualification_mode::Symbol

    function FarBandCovarianceCorrection(;
        thresholds::ControlledHamiltonianSymmetryThresholds = ControlledHamiltonianSymmetryThresholds(),
        qualification_mode::Symbol = :strict,
    )
        qualification_mode in (:strict, :diagnostic_only) ||
            throw(ArgumentError("qualification_mode must be :strict or :diagnostic_only"))
        return new(thresholds, qualification_mode)
    end
end

"""Return the persisted identity of one discrete-Hamiltonian correction policy."""
_discrete_hamiltonian_correction_key(::NoDiscreteHamiltonianCorrection) = "none"
"""Return the persisted identity of controlled far-band covariance restoration."""
_discrete_hamiltonian_correction_key(
    ::FarBandCovarianceCorrection,
) = "far_band_covariance_correction"

"""
Frozen numerical gates for a star-covariant PAW wavefunction preparation.

The target-leakage gate is a dimensionless PAW-S probability weight shared by
the state, reconstruction, and two directed target/complement quantities.
Other dimensionless gates retain their declared amplitude or matrix-residual
semantics. Hamiltonian and energy gates are in eV.
"""
struct PAWGaugeThresholds
    paw_s_norm::Float64
    wfc_rotation_reconstruction::Float64
    final_s_reconstruction::Float64
    state_leakage_amplitude::Float64
    target_leakage_weight::Float64
    nondegenerate_block_leakage::Float64
    raw_unitarity::Float64
    normalized_polar_correction::Float64
    group_law::Float64
    cocycle::Float64
    path_independence::Float64
    hamiltonian_covariance_ev::Float64
    projected_eigen_residual_ev::Float64
    maximum_energy_shift_ev::Float64
    rms_energy_shift_ev::Float64
    block_merge_max_gap_ev::Float64

    function PAWGaugeThresholds(;
        paw_s_norm::Real = 5.0e-6,
        wfc_rotation_reconstruction::Real = 5.0e-6,
        final_s_reconstruction::Real = 5.0e-6,
        state_leakage_amplitude::Real = 5.0e-6,
        target_leakage_weight::Real = 5.0e-6,
        nondegenerate_block_leakage::Real = 5.0e-6,
        raw_unitarity::Real = 5.0e-6,
        normalized_polar_correction::Real = 5.0e-6,
        group_law::Real = 2.0e-5,
        cocycle::Real = 2.0e-5,
        path_independence::Real = 2.0e-5,
        hamiltonian_covariance_ev::Real = 1.0e-7,
        projected_eigen_residual_ev::Real = 5.0e-6,
        maximum_energy_shift_ev::Real = 1.0e-6,
        rms_energy_shift_ev::Real = 3.0e-7,
        block_merge_max_gap_ev::Real = 2.0e-2,
    )
        values = Float64[
            paw_s_norm,
            wfc_rotation_reconstruction,
            final_s_reconstruction,
            state_leakage_amplitude,
            target_leakage_weight,
            nondegenerate_block_leakage,
            raw_unitarity,
            normalized_polar_correction,
            group_law,
            cocycle,
            path_independence,
            hamiltonian_covariance_ev,
            projected_eigen_residual_ev,
            maximum_energy_shift_ev,
            rms_energy_shift_ev,
            block_merge_max_gap_ev,
        ]
        all(value -> isfinite(value) && value > 0.0, values) ||
            throw(ArgumentError("PAW gauge thresholds must be positive and finite"))
        return new(values...)
    end
end

"""
Persisted qualification contract for an outer-window-authoritative target subspace.

The complete parent remains available for completion and audit, but its physical
residuals do not override the scoped qualification. `qualification_scope` owns
the ragged outer/frozen masks and their deterministic SHA-256 identities.
"""
struct TargetSubspaceQualificationContract
    qualification_scope::SymmetryFoundation.BandRepresentationQualificationScope
    outer_min_ev::Float64
    outer_max_ev::Float64
    frozen_min_ev::Float64
    frozen_max_ev::Float64
    num_wannier::Int
    authority::Symbol
    parent_audit_policy::Symbol
    scoped_paw_thresholds::PAWGaugeThresholds
    target_anchor_maximum_drift_ev::Float64
    target_complement_maximum_element_ev::Float64
    contract_sha256::String

    function TargetSubspaceQualificationContract(
        qualification_scope::SymmetryFoundation.BandRepresentationQualificationScope;
        outer_min_ev::Real,
        outer_max_ev::Real,
        frozen_min_ev::Real,
        frozen_max_ev::Real,
        num_wannier::Integer,
        authority::Symbol = :outer_window,
        parent_audit_policy::Symbol = :audit_only,
        scoped_paw_thresholds::PAWGaugeThresholds = PAWGaugeThresholds(
            hamiltonian_covariance_ev = 1.0e-7,
            projected_eigen_residual_ev = 5.0e-6,
        ),
        target_anchor_maximum_drift_ev::Real = 0.0,
        target_complement_maximum_element_ev::Real = 5.0e-6,
    )
        bounds = Float64[outer_min_ev, outer_max_ev, frozen_min_ev, frozen_max_ev]
        all(isfinite, bounds) ||
            throw(ArgumentError("target-subspace energy bounds must be finite"))
        bounds[1] < bounds[2] ||
            throw(ArgumentError("target-subspace outer_min_ev must be smaller than outer_max_ev"))
        bounds[1] <= bounds[3] <= bounds[4] <= bounds[2] ||
            throw(ArgumentError("target-subspace frozen window must be contained in outer window"))
        nwann = Int(num_wannier)
        nwann > 0 || throw(ArgumentError("target-subspace num_wannier must be positive"))
        outer_mask = qualification_scope.outer_mask
        frozen_mask = qualification_scope.frozen_mask
        !isempty(outer_mask) && size(outer_mask, 1) > 0 && size(outer_mask, 2) > 0 ||
            throw(ArgumentError("target-subspace qualification masks must be nonempty"))
        all(vec(sum(outer_mask; dims = 1)) .>= nwann) || throw(
            ArgumentError(
                "target-subspace outer rank must be at least num_wannier at every k point",
            ),
        )
        all((.!frozen_mask) .| outer_mask) ||
            throw(ArgumentError("target-subspace frozen mask must be contained in outer mask"))
        SymmetryFoundation.qualification_mask_sha256(outer_mask) ==
        qualification_scope.outer_mask_sha256 ||
            throw(ArgumentError("target-subspace outer mask SHA-256 mismatch"))
        SymmetryFoundation.qualification_mask_sha256(frozen_mask) ==
        qualification_scope.frozen_mask_sha256 ||
            throw(ArgumentError("target-subspace frozen mask SHA-256 mismatch"))
        authority == :outer_window ||
            throw(ArgumentError("target-subspace authority must be :outer_window"))
        parent_audit_policy == :audit_only ||
            throw(ArgumentError("target-subspace parent_audit_policy must be :audit_only"))
        anchor_threshold = Float64(target_anchor_maximum_drift_ev)
        isfinite(anchor_threshold) && anchor_threshold >= 0.0 ||
            throw(ArgumentError("target_anchor_maximum_drift_ev must be finite and nonnegative"))
        complement_threshold = Float64(target_complement_maximum_element_ev)
        isfinite(complement_threshold) && complement_threshold > 0.0 ||
            throw(ArgumentError("target_complement_maximum_element_ev must be positive and finite"))
        contract_sha256 = _target_subspace_qualification_contract_sha256(
            qualification_scope,
            bounds,
            nwann,
            authority,
            parent_audit_policy,
            scoped_paw_thresholds,
            anchor_threshold,
            complement_threshold,
        )
        return new(
            qualification_scope,
            bounds...,
            nwann,
            authority,
            parent_audit_policy,
            scoped_paw_thresholds,
            anchor_threshold,
            complement_threshold,
            contract_sha256,
        )
    end
end

# Hash the typed target contract independently of serializer or container layout.
function _target_subspace_qualification_contract_sha256(
    qualification_scope,
    bounds,
    num_wannier,
    authority,
    parent_audit_policy,
    scoped_paw_thresholds,
    target_anchor_maximum_drift_ev,
    target_complement_maximum_element_ev,
)
    buffer = IOBuffer()
    write(buffer, "WannierNLQG.target_subspace_qualification_contract/2.0", '\0')
    write(buffer, "physical_paw_s_leakage_weight_v1", '\0')
    write(
        buffer,
        "W_state=max_i(R' S R)_ii;W_reconstruction=lambda_max(R' S R);" *
        "W_T_to_C=opnorm(B_CT,2)^2;W_C_to_T=opnorm(B_TC,2)^2;" *
        "rows=target;columns=source",
        '\0',
    )
    write(buffer, qualification_scope.outer_mask_sha256, '\0')
    write(buffer, qualification_scope.frozen_mask_sha256, '\0')
    for value in bounds
        write(buffer, reinterpret(UInt8, [Float64(value)]))
    end
    write(buffer, reinterpret(UInt8, [Int64(num_wannier)]))
    write(buffer, String(authority), '\0', String(parent_audit_policy), '\0')
    for name in fieldnames(PAWGaugeThresholds)
        write(buffer, String(name), '\0')
        write(buffer, reinterpret(UInt8, [getfield(scoped_paw_thresholds, name)]))
    end
    write(buffer, reinterpret(UInt8, [Float64(target_anchor_maximum_drift_ev)]))
    write(buffer, reinterpret(UInt8, [Float64(target_complement_maximum_element_ev)]))
    return bytes2hex(SHA.sha256(take!(buffer)))
end

"""Construct a PAW-S-orthogonal, symmetry-transported k-star gauge."""
struct StarCovariantPAWGauge <: AbstractWavefunctionGaugeBackend
    buffer_policy::ClosureDrivenBandBuffer
    thresholds::PAWGaugeThresholds
    block_partition_policy::AbstractPAWBlockPartitionPolicy
    hamiltonian_correction::AbstractDiscreteHamiltonianCorrection

    function StarCovariantPAWGauge(;
        buffer_policy::ClosureDrivenBandBuffer = ClosureDrivenBandBuffer(),
        thresholds::PAWGaugeThresholds = PAWGaugeThresholds(),
        block_partition_policy::AbstractPAWBlockPartitionPolicy = FixedGapPAWBlockPartition(
            max_gap_ev = thresholds.block_merge_max_gap_ev,
        ),
        hamiltonian_correction::AbstractDiscreteHamiltonianCorrection = NoDiscreteHamiltonianCorrection(),
    )
        if block_partition_policy isa AdaptiveEvidencePAWBlockPartition &&
           thresholds.block_merge_max_gap_ev != 2.0e-2
            throw(
                ArgumentError(
                    "adaptive PAW block partition cannot be combined with a nondefault " *
                    "PAWGaugeThresholds.block_merge_max_gap_ev",
                ),
            )
        end
        if hamiltonian_correction isa FarBandCovarianceCorrection
            block_partition_policy isa HamiltonianWeightedPAWBlockPartition || throw(
                ArgumentError(
                    "FarBandCovarianceCorrection requires HamiltonianWeightedPAWBlockPartition",
                ),
            )
        end
        return new(buffer_policy, thresholds, block_partition_policy, hamiltonian_correction)
    end
end

"""Return the stable persisted identity of one wavefunction-gauge backend."""
_wavefunction_gauge_backend_key(::NativeEigenstateGauge) = "native_eigenstate"
"""Return the persisted identity of the PAW k-star covariant gauge backend."""
_wavefunction_gauge_backend_key(::StarCovariantPAWGauge) = "star_covariant_paw"

"""Configuration for the restartable symmetry-covariant wavefunction stage."""
Base.@kwdef struct SymmetryCovariantWavefunctionPreparationConfig
    construction_policy::Symbol = :diagnostic
    source::SymmetryFoundation.AbstractWavefunctionSource
    sewing_backend::AbstractBandSewingBackend = AugmentationAwareSewing()
    wavefunction_gauge_backend::AbstractWavefunctionGaugeBackend = StarCovariantPAWGauge()
    authoritative_hamiltonian::AbstractAuthoritativeHamiltonian = NativeDFTHamiltonian()
    target_subspace_contract::Union{Nothing, TargetSubspaceQualificationContract} = nothing
    output_hdf5::String
    symmetry_tolerance::Float64 = 1.0e-5
    target_band_count::Int = 0
    input_symmetry_audit_json::Union{Nothing, String} = nothing
    preflight_diagnostics_jsonl::Union{Nothing, String} = nothing
    maximum_star_count::Union{Nothing, Int} = nothing
    selected_star_indices::Union{Nothing, Vector{Int}} = nothing
end

"""Auditable outcome of one standalone symmetry-covariant wavefunction stage."""
struct SymmetryCovariantWavefunctionPreparationResult
    status::Symbol
    root_cause::Symbol
    output_hdf5::Union{Nothing, String}
    artifact_sha256::Union{Nothing, String}
    target_band_range::UnitRange{Int}
    parent_band_range::UnitRange{Int}
    star_representatives::Vector{Int}
    extra_bands_per_star::Vector{Int}
    maxima::Dict{String, Float64}
    maximum_contexts::Dict{String, String}
    input_sha256::Dict{String, String}
    diagnostics::Vector{String}
    native_fidelity_status::Symbol
    symmetrized_hamiltonian_status::Symbol
    symmetrized_target_subspace_status::Symbol
    auxiliary_parent_audit_status::Symbol
    authoritative_hamiltonian::String
    scoped_production_eligible::Bool
    target_scope_production_eligible::Bool
    global_production_eligible::Bool
    native_fidelity_metrics::Dict{String, Float64}
    symmetrized_hamiltonian_metrics::Dict{String, Float64}
end

"""Configuration for a read-only, nonqualifying PAW block-partition audit."""
Base.@kwdef struct PAWBlockPartitionAuditConfig
    source::SymmetryFoundation.AbstractWavefunctionSource
    output_hdf5::String
    output_csv::String
    output_json::String
    target_band_count::Int = 0
    symmetry_tolerance::Float64 = 1.0e-5
    input_symmetry_audit_json::Union{Nothing, String} = nothing
    kpoint_indices::Union{Nothing, Vector{Int}} = nothing
    fixed_gap_scan_ev::Vector{Float64} = [0.020, 0.030, 0.040, 0.050, 0.075, 0.100]
    block_partition_policy::AbstractPAWBlockPartitionPolicy = FixedGapPAWBlockPartition()
end

"""Summary of a persisted diagnostic-only PAW block-partition audit."""
struct PAWBlockPartitionAuditResult
    status::Symbol
    root_cause::Symbol
    output_hdf5::String
    output_csv::String
    output_json::String
    violation_count::Int
    maximum_gap_ev::Float64
    maximum_coupling::Float64
    pattern_classification::Symbol
    input_sha256::Dict{String, String}
    diagnostics::Vector{String}
    far_residual_count::Int
    tolerated_far_residual_count::Int
    maximum_pair_hamiltonian_residual_ev::Float64
    maximum_far_operator_residual_ev::Float64
    maximum_far_source_column_l2_residual_ev::Float64
    maximum_far_normalized_frobenius_residual_ev::Float64
    maximum_far_frobenius_residual_ev::Float64
    maximum_cancellation_condition::Float64
end

"""Read-only configuration for preparing a qualified band representation."""
Base.@kwdef struct BandRepresentationPreparationConfig
    construction_policy::Symbol = :diagnostic
    # Select representation source, qualification windows, and compatibility policy.
    wannierization_mode::Symbol = :auto
    source::Union{Nothing, SymmetryFoundation.AbstractWavefunctionSource} = nothing
    sewing_backend::AbstractBandSewingBackend = CoefficientMappingSewing()
    wavefunction_gauge_backend::AbstractWavefunctionGaugeBackend = NativeEigenstateGauge()
    authoritative_hamiltonian::AbstractAuthoritativeHamiltonian = NativeDFTHamiltonian()
    wavefunction_gauge_hdf5::Union{Nothing, String} = nothing
    win_file::String
    eig_file::String
    projection_basis::Union{Nothing, WannierProjection.WannierProjectionBasis} = nothing
    band_representation::Union{Nothing, SymmetryFoundation.BandRepresentation} = nothing
    band_representation_hdf5::Union{Nothing, String} = nothing
    output_hdf5::Union{Nothing, String} = nothing
    outer_min_ev::Float64 = -Inf
    outer_max_ev::Float64 = Inf
    frozen_min_ev::Float64 = Inf
    frozen_max_ev::Float64 = -Inf
    frozen_states::Vector{Tuple{Int, Int}} = Tuple{Int, Int}[]
    num_wannier::Int = 0
    symmetry_tolerance::Float64 = 1.0e-5
    degeneracy_tolerance_ev::Float64 = 0.01
    representation_tolerance::Float64 = 1.0e-8
    target_center_matching_tolerance::Float64 = 1.0e-8
    compatibility_policy::Symbol = :warn
end

"""Complete three-dimensional MMN finite-difference stencil used by SAWF."""
struct WannierizationFiniteDifferenceStencil
    vectors_cartesian::Matrix{Float64}
    shell_ids::Vector{Int}
    weights::Vector{Float64}
    target_moment::Matrix{Float64}
    completeness_residual::Float64
    digest::String

    function WannierizationFiniteDifferenceStencil(
        vectors_cartesian,
        shell_ids,
        weights,
        target_moment,
        completeness_residual,
        digest,
    )
        vectors = Matrix{Float64}(vectors_cartesian)
        shells = Int.(shell_ids)
        weight_values = Float64.(weights)
        target = Matrix{Float64}(target_moment)
        size(vectors, 2) == 3 ||
            throw(ArgumentError("stencil vectors must have size (num_neighbors, 3)"))
        length(shells) == size(vectors, 1) == length(weight_values) ||
            throw(ArgumentError("stencil vector, shell, and weight counts disagree"))
        size(target) == (3, 3) || throw(ArgumentError("stencil target must have size (3, 3)"))
        residual = Float64(completeness_residual)
        all(isfinite, vectors) &&
        all(isfinite, weight_values) &&
        all(isfinite, target) &&
        isfinite(residual) || throw(ArgumentError("stencil contains non-finite values"))
        return new(vectors, shells, weight_values, target, residual, String(digest))
    end
end

"""Gauge-invariant local MMN-link diagnostics for one selected subspace."""
struct WannierGaugeLinkDiagnostics
    minimum_singular_values::Matrix{Float64}
    invariant_defects::Matrix{Float64}
    omega_i_contributions::Matrix{Float64}
    minimum_singular_value::Float64
    maximum_invariant_defect::Float64
    top_one_percent_concentration::Float64
    omega_i::Float64
    worst_source_kpoint::Int
    worst_neighbor::Int
    worst_target_kpoint::Int
end

"""Gauge-invariant projector comparison between two full-BZ frame fields."""
struct WannierProjectorComparison
    projector_frobenius::Vector{Float64}
    projector_spectral::Vector{Float64}
    maximum_principal_angle_rad::Vector{Float64}
    minimum_cross_singular_value::Vector{Float64}
    band_weight_difference::Matrix{Float64}
    frozen_projector_frobenius::Vector{Float64}
    free_projector_frobenius::Vector{Float64}
end

"""
Expert-only, read-only gauge-chain diagnostic configuration.

The routine verifies checkpoint, EIG, MMN, representation, and optional W90
CHK identity before comparing projectors, links, direct Hamiltonians, replica
policies, and finite-mesh Fourier reconstruction. It never changes a solver
state or grants production qualification.
"""
Base.@kwdef struct WannierGaugeChainDiagnosticConfig
    wannierization_checkpoint_hdf5::String
    eig_file::String
    mmn_file::String
    band_representation_hdf5::String
    output_json::String
    output_hdf5::String
    reference_chk_file::Union{Nothing, String} = nothing
    mp_grid_tb_file::Union{Nothing, String} = nothing
    minimum_distance_tb_file::Union{Nothing, String} = nothing
    frozen_min_ev::Float64 = Inf
    frozen_max_ev::Float64 = -Inf
    tail_radius_angstrom::Float64 = 14.4
    roundtrip_tolerance::Float64 = 1.0e-10
end

"""Versioned artifact paths and scalar status from a gauge-chain diagnosis."""
struct WannierGaugeChainDiagnosticResult
    status::Symbol
    output_json::String
    output_hdf5::String
    summary::Dict{String, String}
    diagnostics::Vector{String}
end

"""Independent numerical thresholds for spectra, subspace gauges, and projectability."""
Base.@kwdef struct WannierizationNumericalThresholds
    hermitian_residual_rtol::Float64 = 1.0e-12
    subspace_cluster_atol::Float64 = 1.0e-12
    subspace_cluster_rtol::Float64 = 1.0e-8
    frame_transport_atol::Float64 = 1.0e-14
    frame_transport_rtol::Float64 = 1.0e-12
    projectability_minimum_singular_value::Float64 = 1.0e-8
    maximum_transport_condition::Float64 = 1.0e10
end

"""
Frozen audit thresholds for the two-stage SMV disentanglement and
Fletcher--Reeves localization path. The external reference implementation is
documented separately and never controls whether the solver may run.
"""
Base.@kwdef struct SMVFletcherReevesTwoStageAuditThresholds
    standard_version::String = "smv-fletcher-reeves-two-stage-float64-frozen-tolerance-v1"
    semantic::String = "SMV_FLETCHER_REEVES_TWO_STAGE_ORACLE_PARITY_WITH_FROZEN_TOLERANCE"
    accepted_step_combination_rule::String = "abs_diff <= abs_tol + rel_tol * max(abs(reference), abs(candidate))"
    accepted_step_absolute_tolerance::Float64 = 5.0e-12
    accepted_step_relative_tolerance::Float64 = 5.0e-8
    omega_i_absolute_tolerance_angstrom2::Float64 = 5.0e-8
    projector_operator_tolerance::Float64 = 1.0e-8
    maximum_principal_angle_tolerance_rad::Float64 = 1.0e-8
    z_to_u_initial_spread_absolute_tolerance_angstrom2::Float64 = 5.0e-7
    u_nonstep_relative_tolerance::Float64 = 1.0e-8
end

const SMV_FLETCHER_REEVES_TWO_STAGE_AUDIT_SCHEMA = "wanniernlqg.smv-fletcher-reeves-two-stage-audit"
const SMV_FLETCHER_REEVES_TWO_STAGE_AUDIT_SCHEMA_VERSION = "1.0"
const SMV_FLETCHER_REEVES_TWO_STAGE_AUDIT_PASS_STATUS = "SMV_FLETCHER_REEVES_TWO_STAGE_AUDIT_PASS"
const SMV_FLETCHER_REEVES_TWO_STAGE_ALGORITHM_CONTRACT_VERSION = "ordinary-smv-fletcher-reeves-two-stage-default-v4"

"""Expert initialization policy for the selected Bloch subspace."""
abstract type AbstractWannierInitializationBackend end

"""Use the frozen-window-completed AMN row space without changing its projector."""
struct AMNExactFrozenInitialization <: AbstractWannierInitializationBackend end

"""Use a PAW-S SCDM initializer when native wavefunctions and PAW provenance are complete."""
struct PAWSCDMInitialization <: AbstractWannierInitializationBackend end

"""
Self-contained, digest-bound PAW-S SCDM seed consumed by the Z-only stage.

`frames` and `projectors` use the current band basis.  The selected real-space
coordinates are chosen from PAW-S-whitened completed wavefunctions; the
physical metric, native WFC, cutoff, k-map, spinor, atom/projector plan, Q, and
authority identities remain bound through `source_identity` and
`payload_sha256`.  MMN/AMN data are never used to reconstruct this payload.
"""
struct PAWSCDMInputArtifact
    schema_version::String
    frames::Array{ComplexF64, 3}
    projectors::Array{ComplexF64, 3}
    selected_grid_indices::Matrix{Int}
    sampling_grid::NTuple{3, Int}
    singular_values::Matrix{Float64}
    ranks::Vector{Int}
    conditions::Vector{Float64}
    generalized_norm_residuals::Vector{Float64}
    paw_s_orthogonality_residuals::Vector{Float64}
    euclidean_orthogonality_residuals::Vector{Float64}
    kpoints_fractional::Matrix{Float64}
    mp_grid::NTuple{3, Int}
    spinor::Bool
    source_gauge_sha256::String
    strict_representation_sha256::String
    authoritative_hamiltonian::String
    authoritative_hamiltonian_sha256::String
    metric_sha256::String
    source_identity::Dict{String, String}
    payload_sha256::String
end

"""Use projectability disentanglement after an orthonormal-projector Gram audit."""
struct ProjectabilityDisentanglementInitialization <: AbstractWannierInitializationBackend end

"""Expert-only deterministic multi-start controls; disabled by default."""
struct WannierizationMultiStartConfig
    enabled::Bool
    starts::Int
    start_index::Int

    function WannierizationMultiStartConfig(;
        enabled::Bool = false,
        starts::Integer = 4,
        start_index::Integer = 1,
    )
        starts > 0 || throw(ArgumentError("multi-start count must be positive"))
        1 <= start_index <= starts || throw(ArgumentError("multi-start index must lie in 1:starts"))
        return new(enabled, Int(starts), Int(start_index))
    end
end

"""Sealed Z-stage state, independent of localization gauge and U history."""
struct DisentanglementState
    projectors::Array{ComplexF64, 3}
    frames::Array{ComplexF64, 3}
    z_field::Array{ComplexF64, 3}
    omega_i::Float64
    outer_mask::BitMatrix
    frozen_mask::BitMatrix
    projector_residual::Float64
    objective_history::Vector{Float64}
    converged::Bool
end

# Store the single effective stage schedule and localization line-search controls.
struct WannierizationAccelerationConfig
    # Select fixed, adaptive, or safeguarded Anderson-Z iteration controls.
    strategy::Symbol
    schedule::Symbol
    localization_algorithm::Symbol
    u_acceptance::Symbol
    u_initial_step::Float64
    u_armijo_c1::Float64
    u_backtracking_factor::Float64
    u_backtracking_max_steps::Int
    u_objective_tolerance::Float64
    u_max_geodesic_step::Float64
    u_gradient_norm_tolerance::Float64
    localization_max_steps::Int
    disentanglement_max_steps::Int
    disentanglement_objective_tolerance::Float64
    z_projector_tolerance::Float64
    z_stability_window::Int
    localization_max_condition::Float64
    polar_warm_start_max_steps::Int
    u_inner_sweeps::Int
    u_inner_tolerance::Float64
    adaptive_z_bounds::Tuple{Float64, Float64}
    adaptive_u_bounds::Tuple{Float64, Float64}
    adaptive_growth::Float64
    adaptive_shrink::Float64
    adaptive_improvement_ratio::Float64
    adaptive_reject_ratio::Float64
    adaptive_patience::Int
    anderson_depth::Int
    anderson_start_iteration::Int
    anderson_regularization::Float64
    u_cg_restart_interval::Int
    u_cg_beta_cap::Float64
    u_cg_minimum_descent_cosine::Float64
    # Schema-2.8 expert controls are append-only to preserve legacy restart
    # struct representations and their scientific digests.
    disentanglement_limit_policy::Symbol
    joint_z_backtracking_factor::Float64
    joint_z_backtracking_max_steps::Int
    # Schema-2.9 selects the operation subgroup used by the U/Z constraints.
    # The full magnetic group remains the default and is bitwise unchanged.
    constraint_operation_scope::Symbol
    # Schema-2.10 expert controls for a chart-consistent MV U optimizer.
    u_phase_branch_tolerance::Float64
    u_branch_active_set_max_orbits::Int
    u_lbfgs_history::Int
    u_lbfgs_curvature_tolerance::Float64
    u_wolfe_c2::Float64
    u_line_search_max_trials::Int
    # Schema-2.21 expert controls. The established SMV-Z and U defaults remain
    # unchanged; every alternative is an explicit opt-in.
    disentanglement_algorithm::Symbol
    subspace_gauge_policy::Symbol
    u_w90_restart_interval::Int
    u_w90_trial_step::Float64
    trust_radius_initial::Float64
    trust_radius_maximum::Float64
    trust_acceptance_threshold::Float64
    trust_shrink_threshold::Float64
    trust_expand_threshold::Float64
    hot_storage_backend::Symbol
end

const _WANNIERIZATION_ACCELERATION_DEFAULTS = (
    strategy = :fixed,
    schedule = :two_stage,
    localization_algorithm = :symmetry_projected_gradient,
    u_acceptance = :armijo,
    u_initial_step = 1.0,
    u_armijo_c1 = 1.0e-4,
    u_backtracking_factor = 0.5,
    u_backtracking_max_steps = 12,
    u_objective_tolerance = 1.0e-12,
    u_max_geodesic_step = Inf,
    u_gradient_norm_tolerance = 1.0e-9,
    localization_max_steps = 500,
    disentanglement_max_steps = 250,
    disentanglement_objective_tolerance = 1.0e-10,
    z_projector_tolerance = 1.0e-10,
    z_stability_window = 3,
    disentanglement_limit_policy = :diagnostic_continue,
    joint_z_backtracking_factor = 0.5,
    joint_z_backtracking_max_steps = 12,
    constraint_operation_scope = :full,
    u_phase_branch_tolerance = 1.0e-6,
    u_branch_active_set_max_orbits = 64,
    u_lbfgs_history = 8,
    u_lbfgs_curvature_tolerance = 1.0e-12,
    u_wolfe_c2 = 0.9,
    u_line_search_max_trials = 24,
    localization_max_condition = 1.0e10,
    polar_warm_start_max_steps = 20,
    u_inner_sweeps = 1,
    u_inner_tolerance = 1.0e-10,
    adaptive_z_bounds = (0.2, 0.95),
    adaptive_u_bounds = (0.1, 1.0),
    adaptive_growth = 1.15,
    adaptive_shrink = 0.5,
    adaptive_improvement_ratio = 0.90,
    adaptive_reject_ratio = 1.05,
    adaptive_patience = 3,
    anderson_depth = 5,
    anderson_start_iteration = 6,
    anderson_regularization = 1.0e-12,
    u_cg_restart_interval = 20,
    u_cg_beta_cap = 10.0,
    u_cg_minimum_descent_cosine = 1.0e-3,
    disentanglement_algorithm = :smv_fixed_point,
    subspace_gauge_policy = :boundary_cluster_procrustes,
    u_w90_restart_interval = 5,
    u_w90_trial_step = 2.0,
    trust_radius_initial = 0.25,
    trust_radius_maximum = 1.0,
    trust_acceptance_threshold = 0.1,
    trust_shrink_threshold = 0.25,
    trust_expand_threshold = 0.75,
    hot_storage_backend = :legacy_vector,
)

"""
Normalize and validate public solver controls while rejecting removed legacy keys.
"""
function WannierizationAccelerationConfig(; kwargs...)
    supplied = Dict{Symbol, Any}(kwargs)
    if get(supplied, :schedule, nothing) == :nested ||
       any(startswith(String(key), "nested_") for key in keys(supplied))
        throw(
            ArgumentError(
                "UNSUPPORTED_LEGACY_SCHEDULE: :nested and nested_* controls were removed; use schedule=:two_stage",
            ),
        )
    end
    legacy_gradient = filter(key -> startswith(String(key), "gradient_"), collect(keys(supplied)))
    isempty(legacy_gradient) || throw(
        ArgumentError(
            "UNSUPPORTED_LEGACY_SOLVER_KEYWORD: $(join(sort!(String.(legacy_gradient)), ',')); " *
            "use the canonical u_* localization controls",
        ),
    )
    allowed = Set(fieldnames(WannierizationAccelerationConfig))
    unknown = sort!(String.(filter(key -> !(key in allowed), collect(keys(supplied)))))
    isempty(unknown) || throw(
        ArgumentError("unknown WannierizationAccelerationConfig keyword(s): $(join(unknown, ','))"),
    )
    values = merge(_WANNIERIZATION_ACCELERATION_DEFAULTS, (; kwargs...))
    return WannierizationAccelerationConfig(
        Symbol(values.strategy),
        Symbol(values.schedule),
        Symbol(values.localization_algorithm),
        Symbol(values.u_acceptance),
        Float64(values.u_initial_step),
        Float64(values.u_armijo_c1),
        Float64(values.u_backtracking_factor),
        Int(values.u_backtracking_max_steps),
        Float64(values.u_objective_tolerance),
        Float64(values.u_max_geodesic_step),
        Float64(values.u_gradient_norm_tolerance),
        Int(values.localization_max_steps),
        Int(values.disentanglement_max_steps),
        Float64(values.disentanglement_objective_tolerance),
        Float64(values.z_projector_tolerance),
        Int(values.z_stability_window),
        Float64(values.localization_max_condition),
        Int(values.polar_warm_start_max_steps),
        Int(values.u_inner_sweeps),
        Float64(values.u_inner_tolerance),
        Tuple(Float64.(values.adaptive_z_bounds)),
        Tuple(Float64.(values.adaptive_u_bounds)),
        Float64(values.adaptive_growth),
        Float64(values.adaptive_shrink),
        Float64(values.adaptive_improvement_ratio),
        Float64(values.adaptive_reject_ratio),
        Int(values.adaptive_patience),
        Int(values.anderson_depth),
        Int(values.anderson_start_iteration),
        Float64(values.anderson_regularization),
        Int(values.u_cg_restart_interval),
        Float64(values.u_cg_beta_cap),
        Float64(values.u_cg_minimum_descent_cosine),
        Symbol(values.disentanglement_limit_policy),
        Float64(values.joint_z_backtracking_factor),
        Int(values.joint_z_backtracking_max_steps),
        Symbol(values.constraint_operation_scope),
        Float64(values.u_phase_branch_tolerance),
        Int(values.u_branch_active_set_max_orbits),
        Int(values.u_lbfgs_history),
        Float64(values.u_lbfgs_curvature_tolerance),
        Float64(values.u_wolfe_c2),
        Int(values.u_line_search_max_trials),
        Symbol(values.disentanglement_algorithm),
        Symbol(values.subspace_gauge_policy),
        Int(values.u_w90_restart_interval),
        Float64(values.u_w90_trial_step),
        Float64(values.trust_radius_initial),
        Float64(values.trust_radius_maximum),
        Float64(values.trust_acceptance_threshold),
        Float64(values.trust_shrink_threshold),
        Float64(values.trust_expand_threshold),
        Symbol(values.hot_storage_backend),
    )
end

@doc """
Opt-in controls for fixed, adaptive, or safeguarded Anderson-Z updates and the
localization algorithms. Frozen bands constrain only the selected Bloch
subspace; the U-localization tangent contains no target-space frozen block.
`:symmetry_projected_gradient` is the formal default. `:polar_then_gradient`
is a bounded diagnostic warm start and cannot remain a polar-only optimizer.
`:riemannian_cg` is an expert-only Polak--Ribiere+ search on the same
symmetry-reduced real-linear tangent, with polar retraction and fail-closed
restart to the default projected steepest descent.
`:riemannian_lbfgs` is an expert-only limited-memory search on that tangent.
Both accelerated algorithms use strong-Wolfe trials in smooth charts and
generalized Armijo trials when a Type-IV phase-cut orbit is active.
`constraint_operation_scope=:full` applies the complete unitary and
antiunitary operation set. The expert-only `:unitary` and `:identity` scopes
are causal ablations: they rebuild the corresponding k-star partition and are
always diagnostic-only, never production-qualified.
""" WannierizationAccelerationConfig
