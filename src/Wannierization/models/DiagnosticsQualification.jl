# Hash the fully expanded target basis, including its local gauge and numbering.
function _projection_basis_sha256(basis::WannierProjection.WannierProjectionBasis)
    buffer = IOBuffer()
    write(buffer, reinterpret(UInt8, Int64[basis.num_wannier, Int(basis.spinor)]))
    write(
        buffer,
        repr(WannierProjection.projection_radial_transform_contract(basis.radial_transform)),
        '\n',
    )
    for block in basis.blocks
        write(buffer, block.selector, '\0', block.orbital_set, '\0')
        write(buffer, reinterpret(UInt8, vec(block.positions_fractional)))
        write(buffer, reinterpret(UInt8, Int64.(vec(block.indices))))
        write(buffer, reinterpret(UInt8, vec(block.local_bases)))
    end
    return bytes2hex(SHA.sha256(take!(buffer)))
end

# Store durable files without changing the numerical solver status.
Base.@kwdef struct WannierizationArtifacts
    # Record fixed sibling paths only after each artifact is durably published.
    checkpoint_hdf5::Union{Nothing, String} = nothing
    validated_checkpoint_hdf5::Union{Nothing, String} = nothing
    wannierization_log::Union{Nothing, String} = nothing
    packed_hdf5::Union{Nothing, String} = nothing
    wannier90_tb::Union{Nothing, String} = nothing
    tb_symmetry_json::Union{Nothing, String} = nothing
end

@doc """
Durable files emitted by one Wannierization workflow without changing solver status
semantics. Missing outputs remain `nothing` after typed failures or when the
corresponding format is disabled.
""" WannierizationArtifacts

"""One structured SAWF warning or failure with string-valued context."""
struct WannierizationDiagnostic
    code::Symbol
    severity::Symbol
    message::String
    context::Dict{String, String}

    function WannierizationDiagnostic(code, severity, message; context = Dict{String, String}())
        severity in (:info, :warning, :error) ||
            throw(ArgumentError("diagnostic severity must be :info, :warning, or :error"))
        return new(Symbol(code), Symbol(severity), String(message), Dict{String, String}(context))
    end
end

const TB_SYMMETRY_QUALIFICATION_SCHEMA = "WannierNLQG.tb_symmetry_qualification"
const TB_SYMMETRY_QUALIFICATION_SCHEMA_VERSION = "1.7"
const TB_TARGET_LEAKAGE_WEIGHT_SEMANTICS = "physical_paw_s_leakage_weight_v1"
const TB_TARGET_LEAKAGE_WEIGHT_FORMULAS =
    "W_state=max_i(R' S R)_ii;W_reconstruction=lambda_max(R' S R);" *
    "W_T_to_C=opnorm(B_CT,2)^2;W_C_to_T=opnorm(B_TC,2)^2;" *
    "rows=target;columns=source"
const TB_TARGET_LEAKAGE_WEIGHT_FORMULA_SHA256 =
    bytes2hex(SHA.sha256(codeunits(TB_TARGET_LEAKAGE_WEIGHT_FORMULAS)))
const TB_TARGET_LEAKAGE_MAXIMUM_THRESHOLD = 5.0e-6

"""One auditable scalar in the final exported-TB symmetry qualification."""
struct TBSymmetryMetric
    name::String
    value::Union{Nothing, Float64}
    threshold::Union{Nothing, Float64}
    status::String
    applicability::String
    reason::String
    convention::String

    function TBSymmetryMetric(name, value, threshold, status, applicability, reason, convention)
        name_value = String(name)
        isempty(name_value) && throw(ArgumentError("TB symmetry metric name must not be empty"))
        value_value = value === nothing ? nothing : Float64(value)
        threshold_value = threshold === nothing ? nothing : Float64(threshold)
        value_value === nothing ||
            isfinite(value_value) ||
            throw(ArgumentError("TB symmetry metric value must be finite when present"))
        threshold_value === nothing ||
            (isfinite(threshold_value) && threshold_value >= 0.0) ||
            throw(ArgumentError("TB symmetry metric threshold must be finite and nonnegative"))
        status_value = String(status)
        status_value in ("PASS", "FAIL", "NOT_APPLICABLE", "NOT_RUN") ||
            throw(ArgumentError("unsupported TB symmetry metric status $(status_value)"))
        applicability_value = String(applicability)
        applicability_value in ("APPLICABLE", "NOT_APPLICABLE") || throw(
            ArgumentError("unsupported TB symmetry metric applicability $(applicability_value)"),
        )
        return new(
            name_value,
            value_value,
            threshold_value,
            status_value,
            applicability_value,
            String(reason),
            String(convention),
        )
    end
end

# Hash typed scalar fields instead of serializer-dependent JSON or HDF5 byte layouts.
function tb_symmetry_payload_sha256(
    overall,
    reason,
    metrics;
    schema_version::AbstractString = TB_SYMMETRY_QUALIFICATION_SCHEMA_VERSION,
    authoritative_hamiltonian::AbstractString = "native_dft",
    authoritative_hamiltonian_sha256::AbstractString = "LEGACY_NATIVE_DFT",
    energy_shift_qualification::AbstractString = "legacy_energy_shift_hard_gate",
    maximum_energy_shift_audit_reference_ev::AbstractString = "NOT_APPLICABLE",
    rms_energy_shift_audit_reference_ev::AbstractString = "NOT_APPLICABLE",
    target_energy_shift_audit_status::AbstractString = "NOT_APPLICABLE",
    symmetrized_parent_energy_shift_audit_status::AbstractString = "NOT_APPLICABLE",
    residual_gate_phase::AbstractString = "legacy_pre_symmetrization",
    raw_preflight_diagnostic_status::AbstractString = "NOT_APPLICABLE",
    native_difference_qualification::AbstractString = "legacy_hard_gate",
    native_difference_audit_status::AbstractString = "NOT_APPLICABLE",
    qualification_scope::AbstractString = "full_parent",
    target_anchor::AbstractString = "NOT_APPLICABLE",
    target_complement_completion::AbstractString = "NOT_APPLICABLE",
    target_complement_max_element_ev::AbstractString = "NOT_APPLICABLE",
    auxiliary_parent_qualification::AbstractString = "legacy_hard_gate",
    symmetrized_target_subspace_status::AbstractString = "NOT_APPLICABLE",
    auxiliary_parent_audit_status::AbstractString = "NOT_APPLICABLE",
    target_scope_production_eligible::Bool = false,
    target_leakage_semantics::AbstractString = "NOT_APPLICABLE",
    target_leakage_formula_sha256::AbstractString = "NOT_RECORDED",
    target_leakage_threshold::Union{Nothing, Real} = nothing,
    scoped_production_eligible::Bool = false,
    global_production_eligible::Bool = false,
)
    authority_value =
        SymmetryFoundation.validate_authoritative_hamiltonian_key(authoritative_hamiltonian)
    buffer = IOBuffer()
    write(buffer, TB_SYMMETRY_QUALIFICATION_SCHEMA, '\0')
    write(buffer, String(schema_version), '\0')
    write(buffer, String(overall), '\0', String(reason), '\0')
    if schema_version in ("1.1", "1.2", "1.3", "1.4", "1.5", "1.6", "1.7")
        write(
            buffer,
            authority_value,
            '\0',
            String(authoritative_hamiltonian_sha256),
            '\0',
            scoped_production_eligible ? "true" : "false",
            '\0',
            global_production_eligible ? "true" : "false",
            '\0',
        )
    end
    if schema_version in ("1.2", "1.3", "1.4", "1.5", "1.6", "1.7")
        for value in (
            energy_shift_qualification,
            maximum_energy_shift_audit_reference_ev,
            rms_energy_shift_audit_reference_ev,
            target_energy_shift_audit_status,
            symmetrized_parent_energy_shift_audit_status,
        )
            write(buffer, String(value), '\0')
        end
    end
    if schema_version in ("1.3", "1.4", "1.5", "1.6", "1.7")
        write(buffer, String(residual_gate_phase), '\0')
        write(buffer, String(raw_preflight_diagnostic_status), '\0')
    end
    if schema_version in ("1.4", "1.5", "1.6", "1.7")
        write(buffer, String(native_difference_qualification), '\0')
        write(buffer, String(native_difference_audit_status), '\0')
    end
    if schema_version in ("1.5", "1.6", "1.7")
        for value in (
            qualification_scope,
            target_anchor,
            target_complement_completion,
            target_complement_max_element_ev,
            auxiliary_parent_qualification,
            symmetrized_target_subspace_status,
            auxiliary_parent_audit_status,
            target_scope_production_eligible ? "true" : "false",
        )
            write(buffer, String(value), '\0')
        end
    end
    if schema_version == "1.7"
        write(buffer, String(target_leakage_semantics), '\0')
        write(buffer, String(target_leakage_formula_sha256), '\0')
        write(buffer, UInt8(target_leakage_threshold !== nothing))
        target_leakage_threshold === nothing ||
            write(buffer, reinterpret(UInt8, [Float64(target_leakage_threshold)]))
    end
    for metric in sort!(TBSymmetryMetric[metrics...]; by = item -> item.name)
        for text in
            (metric.name, metric.status, metric.applicability, metric.reason, metric.convention)
            write(buffer, text, '\0')
        end
        for scalar in (metric.value, metric.threshold)
            write(buffer, UInt8(scalar !== nothing))
            scalar === nothing || write(buffer, reinterpret(UInt8, [something(scalar)]))
        end
    end
    return bytes2hex(SHA.sha256(take!(buffer)))
end

"""
Canonical qualification of the final exported and independently read-back TB.

`payload_sha256` binds the ordered scalar payload, independent of the JSON and
HDF5 container encodings. Solver convergence and representation diagnostics
remain separate contracts.
"""
struct TBSymmetryQualification
    schema_version::String
    overall::String
    reason::String
    metrics::Vector{TBSymmetryMetric}
    payload_sha256::String
    authoritative_hamiltonian::String
    authoritative_hamiltonian_sha256::String
    energy_shift_qualification::String
    maximum_energy_shift_audit_reference_ev::String
    rms_energy_shift_audit_reference_ev::String
    target_energy_shift_audit_status::String
    symmetrized_parent_energy_shift_audit_status::String
    residual_gate_phase::String
    raw_preflight_diagnostic_status::String
    native_difference_qualification::String
    native_difference_audit_status::String
    qualification_scope::String
    target_anchor::String
    target_complement_completion::String
    target_complement_max_element_ev::String
    auxiliary_parent_qualification::String
    symmetrized_target_subspace_status::String
    auxiliary_parent_audit_status::String
    target_scope_production_eligible::Bool
    target_leakage_semantics::String
    target_leakage_formula_sha256::String
    target_leakage_threshold::Union{Nothing, Float64}
    scoped_production_eligible::Bool
    global_production_eligible::Bool

    function TBSymmetryQualification(
        overall,
        reason,
        metrics;
        schema_version::AbstractString = TB_SYMMETRY_QUALIFICATION_SCHEMA_VERSION,
        payload_sha256::Union{Nothing, AbstractString} = nothing,
        authoritative_hamiltonian::AbstractString = "native_dft",
        authoritative_hamiltonian_sha256::AbstractString = "LEGACY_NATIVE_DFT",
        energy_shift_qualification::AbstractString = "legacy_energy_shift_hard_gate",
        maximum_energy_shift_audit_reference_ev::AbstractString = "NOT_APPLICABLE",
        rms_energy_shift_audit_reference_ev::AbstractString = "NOT_APPLICABLE",
        target_energy_shift_audit_status::AbstractString = "NOT_APPLICABLE",
        symmetrized_parent_energy_shift_audit_status::AbstractString = "NOT_APPLICABLE",
        residual_gate_phase::AbstractString = "legacy_pre_symmetrization",
        raw_preflight_diagnostic_status::AbstractString = "NOT_APPLICABLE",
        native_difference_qualification::AbstractString = "legacy_hard_gate",
        native_difference_audit_status::AbstractString = "NOT_APPLICABLE",
        qualification_scope::AbstractString = "full_parent",
        target_anchor::AbstractString = "NOT_APPLICABLE",
        target_complement_completion::AbstractString = "NOT_APPLICABLE",
        target_complement_max_element_ev::AbstractString = "NOT_APPLICABLE",
        auxiliary_parent_qualification::AbstractString = "legacy_hard_gate",
        symmetrized_target_subspace_status::AbstractString = "NOT_APPLICABLE",
        auxiliary_parent_audit_status::AbstractString = "NOT_APPLICABLE",
        target_scope_production_eligible::Bool = false,
        target_leakage_semantics::AbstractString = "NOT_APPLICABLE",
        target_leakage_formula_sha256::AbstractString = "NOT_RECORDED",
        target_leakage_threshold::Union{Nothing, Real} = nothing,
        scoped_production_eligible::Bool = false,
        global_production_eligible::Bool = false,
    )
        schema_value = String(schema_version)
        schema_value in (
            "1.0",
            "1.1",
            "1.2",
            "1.3",
            "1.4",
            "1.5",
            "1.6",
            TB_SYMMETRY_QUALIFICATION_SCHEMA_VERSION,
        ) || throw(ArgumentError("unsupported final TB symmetry schema version $(schema_value)"))
        overall_value = String(overall)
        overall_value in ("PASS", "FAIL", "INCOMPLETE", "NOT_RUN") ||
            throw(ArgumentError("unsupported final TB symmetry status $(overall_value)"))
        metric_values = TBSymmetryMetric[metrics...]
        names = getfield.(metric_values, :name)
        length(unique(names)) == length(names) ||
            throw(ArgumentError("final TB symmetry metric names must be unique"))
        sort!(metric_values; by = item -> item.name)
        global_production_eligible == false ||
            throw(ArgumentError("TB qualification cannot override native/global production status"))
        authority_value =
            SymmetryFoundation.validate_authoritative_hamiltonian_key(authoritative_hamiltonian)
        is_symmetrized_authority = authority_value == "symmetrized_dft_hamiltonian"
        schema_value in ("1.2", "1.3", "1.4", "1.5", "1.6", "1.7") &&
            is_symmetrized_authority &&
            energy_shift_qualification != "audit_only" &&
            throw(
                ArgumentError(
                    "HAMILTONIAN_REFERENCE_MISMATCH: TB qualification 1.2 requires audit-only symmetrized energy shifts",
                ),
            )
        schema_value in ("1.3", "1.4", "1.5", "1.6", "1.7") &&
            is_symmetrized_authority &&
            residual_gate_phase != "post_symmetrization" &&
            throw(
                ArgumentError(
                    "HAMILTONIAN_REFERENCE_MISMATCH: TB qualification 1.3 requires post-symmetrization residual gates",
                ),
            )
        schema_value in ("1.4", "1.5", "1.6", "1.7") &&
            is_symmetrized_authority &&
            native_difference_qualification != "audit_only" &&
            throw(
                ArgumentError(
                    "HAMILTONIAN_REFERENCE_MISMATCH: TB qualification 1.4 requires audit-only native differences",
                ),
            )
        target_leakage_threshold_value =
            target_leakage_threshold === nothing ? nothing : Float64(target_leakage_threshold)
        if qualification_scope == "target_subspace"
            schema_value == "1.6" && throw(
                ArgumentError(
                    "UNSUPPORTED_LEGACY_TARGET_LEAKAGE_SEMANTICS: schema-1.6 target TB qualification uses amplitude leakage gates",
                ),
            )
            schema_value == "1.7" || throw(
                ArgumentError(
                    "TARGET_SUBSPACE_CONTRACT_MISMATCH: target TB qualification requires schema 1.7",
                ),
            )
            target_leakage_semantics == TB_TARGET_LEAKAGE_WEIGHT_SEMANTICS || throw(
                ArgumentError(
                    "UNSUPPORTED_LEGACY_TARGET_LEAKAGE_SEMANTICS: target TB qualification does not declare PAW-S leakage weights",
                ),
            )
            target_leakage_formula_sha256 == TB_TARGET_LEAKAGE_WEIGHT_FORMULA_SHA256 || throw(
                ArgumentError(
                    "TARGET_SUBSPACE_CONTRACT_MISMATCH: target leakage formula SHA-256 is incompatible",
                ),
            )
            target_leakage_threshold_value !== nothing &&
            isfinite(something(target_leakage_threshold_value)) &&
            0.0 <= something(target_leakage_threshold_value) <= TB_TARGET_LEAKAGE_MAXIMUM_THRESHOLD ||
                throw(
                    ArgumentError(
                        "TARGET_SUBSPACE_CONTRACT_MISMATCH: target leakage threshold must not exceed 5e-6",
                    ),
                )
        end
        if is_symmetrized_authority
            schema_value == "1.7" || throw(
                ArgumentError(
                    "HAMILTONIAN_REFERENCE_MISMATCH: symmetrized DFT target TB qualification requires schema 1.7",
                ),
            )
            qualification_scope == "target_subspace" ||
                throw(ArgumentError("HAMILTONIAN_REFERENCE_MISMATCH: target TB scope differs"))
            target_anchor == "completed_symmetrized_target" ||
                throw(ArgumentError("HAMILTONIAN_REFERENCE_MISMATCH: target TB anchor differs"))
            auxiliary_parent_qualification == "audit_only" || throw(
                ArgumentError(
                    "HAMILTONIAN_REFERENCE_MISMATCH: target TB requires audit-only auxiliary parent",
                ),
            )
        end
        digest = tb_symmetry_payload_sha256(
            overall_value,
            reason,
            metric_values;
            schema_version = schema_value,
            authoritative_hamiltonian = authority_value,
            authoritative_hamiltonian_sha256,
            energy_shift_qualification,
            maximum_energy_shift_audit_reference_ev,
            rms_energy_shift_audit_reference_ev,
            target_energy_shift_audit_status,
            symmetrized_parent_energy_shift_audit_status,
            residual_gate_phase,
            raw_preflight_diagnostic_status,
            native_difference_qualification,
            native_difference_audit_status,
            qualification_scope,
            target_anchor,
            target_complement_completion,
            target_complement_max_element_ev,
            auxiliary_parent_qualification,
            symmetrized_target_subspace_status,
            auxiliary_parent_audit_status,
            target_scope_production_eligible,
            target_leakage_semantics,
            target_leakage_formula_sha256,
            target_leakage_threshold = target_leakage_threshold_value,
            scoped_production_eligible,
            global_production_eligible,
        )
        if payload_sha256 !== nothing
            String(payload_sha256) == digest ||
                throw(ArgumentError("final TB symmetry payload SHA-256 mismatch"))
        end
        return new(
            schema_value,
            overall_value,
            String(reason),
            metric_values,
            digest,
            authority_value,
            String(authoritative_hamiltonian_sha256),
            String(energy_shift_qualification),
            String(maximum_energy_shift_audit_reference_ev),
            String(rms_energy_shift_audit_reference_ev),
            String(target_energy_shift_audit_status),
            String(symmetrized_parent_energy_shift_audit_status),
            String(residual_gate_phase),
            String(raw_preflight_diagnostic_status),
            String(native_difference_qualification),
            String(native_difference_audit_status),
            String(qualification_scope),
            String(target_anchor),
            String(target_complement_completion),
            String(target_complement_max_element_ev),
            String(auxiliary_parent_qualification),
            String(symmetrized_target_subspace_status),
            String(auxiliary_parent_audit_status),
            target_scope_production_eligible,
            String(target_leakage_semantics),
            String(target_leakage_formula_sha256),
            target_leakage_threshold_value,
            scoped_production_eligible,
            false,
        )
    end
end

"""Construct an explicit no-TB qualification without inventing metric values."""
function _tb_symmetry_not_run(reason::AbstractString = "TB_NOT_AVAILABLE")
    return TBSymmetryQualification("NOT_RUN", reason, TBSymmetryMetric[])
end

"""
Closed product metadata for one ordered band-representation operation list.

`product_indices[g,h]` denotes `g o h` (first `h`, then `g`). Integer
translation differences satisfy `tau_g + W_g*tau_h = tau_{g o h} + L_g,h`.
`spinor_factors[g,h]` is the projective double-group sign in
`Q_g*Q_h^(*) = xi_g,h*Q_{g o h}`, where the second factor is conjugated when
`g` is antiunitary.
"""
struct RepresentationProductTable
    identity_index::Int
    theta_index::Union{Nothing, Int}
    canonical_keys::Vector{String}
    spin_actions::Array{ComplexF64, 3}
    product_indices::Matrix{Int}
    translation_differences::Array{Int, 3}
    spinor_factors::Matrix{Int}
end

"""
Structured result of native band/target representation compatibility checks.

Group-law residuals are stored in `(UU, UA, AU, AA)` order. `passed` covers
only the declared static representation contract; iterative SAWF convergence
and final selected-projector covariance remain separate numerical outcomes.
"""
struct RepresentationCompatibilityReport
    schema_version::String
    supported_contract::Bool
    passed::Bool
    tolerance::Float64
    product_table::RepresentationProductTable
    maximum_group_law_residuals::NTuple{4, Float64}
    band_group_law_residuals::NTuple{4, Float64}
    target_group_law_residuals::NTuple{4, Float64}
    band_group_law_worst_cases::NTuple{4, Dict{String, String}}
    target_group_law_worst_cases::NTuple{4, Dict{String, String}}
    maximum_reciprocal_shift_residual::Float64
    theta_squared_residual::Float64
    maximum_kramers_residual::Float64
    representation_sha256::String
    diagnostics::Vector{WannierizationDiagnostic}
    metadata_origin::Symbol
    gate_definition_status::RepresentationGateDefinitionStatus
    assessment_status::RepresentationAssessmentStatus
    maximum_required_block_unitarity_residual::Float64
    oracle_excess_group_law_residuals::Union{Nothing, NTuple{4, Float64}}
    qualification_sha256::Union{Nothing, String}
    validation_profile::Symbol
end

"""Prepared representation plus inventory, scoped diagnostics, and policy evidence."""
struct BandRepresentationPreparationResult
    status::Symbol
    representation::SymmetryFoundation.BandRepresentation
    inventory::Union{Nothing, SymmetryFoundation.MagneticSymmetryInventory}
    raw_diagnostics::Vector{SymmetryFoundation.RepresentationRawDiagnostic}
    qualification_scope::SymmetryFoundation.BandRepresentationQualificationScope
    compatibility_report::RepresentationCompatibilityReport
    requested_compatibility_policy::Symbol
    effective_compatibility_policy::Symbol
    symmetry_tolerance_status::Symbol
    output_hdf5::Union{Nothing, String}
    artifact_sha256::Union{Nothing, String}
    diagnostics::Vector{WannierizationDiagnostic}
end

# Construct four independent empty contexts for legacy reports.
_empty_group_law_worst_cases() = ntuple(_ -> Dict{String, String}(), 4)

# Preserve the schema-1.2 full constructor while schema 1.3 adds split diagnostics.
function RepresentationCompatibilityReport(
    schema_version,
    supported_contract,
    passed,
    tolerance,
    product_table,
    maximum_group_law_residuals,
    maximum_reciprocal_shift_residual,
    theta_squared_residual,
    maximum_kramers_residual,
    representation_sha256,
    diagnostics,
    metadata_origin,
    gate_definition_status,
    assessment_status,
    maximum_required_block_unitarity_residual,
    oracle_excess_group_law_residuals,
    qualification_sha256,
    validation_profile,
)
    residuals = Tuple(Float64.(collect(maximum_group_law_residuals)))
    return RepresentationCompatibilityReport(
        String(schema_version),
        Bool(supported_contract),
        Bool(passed),
        Float64(tolerance),
        product_table,
        residuals,
        residuals,
        (0.0, 0.0, 0.0, 0.0),
        _empty_group_law_worst_cases(),
        _empty_group_law_worst_cases(),
        Float64(maximum_reciprocal_shift_residual),
        Float64(theta_squared_residual),
        Float64(maximum_kramers_residual),
        String(representation_sha256),
        WannierizationDiagnostic[diagnostics...],
        Symbol(metadata_origin),
        gate_definition_status,
        assessment_status,
        Float64(maximum_required_block_unitarity_residual),
        oracle_excess_group_law_residuals,
        qualification_sha256,
        Symbol(validation_profile),
    )
end

# Preserve the schema-1.1 expert constructor while making its legacy semantics explicit.
function RepresentationCompatibilityReport(
    schema_version,
    supported_contract,
    passed,
    tolerance,
    product_table,
    maximum_group_law_residuals,
    maximum_reciprocal_shift_residual,
    theta_squared_residual,
    maximum_kramers_residual,
    representation_sha256,
    diagnostics,
    metadata_origin,
)
    assessment = passed ? REPRESENTATION_COMPATIBLE : REPRESENTATION_INCOMPATIBLE_ASSESSMENT
    return RepresentationCompatibilityReport(
        schema_version,
        supported_contract,
        passed,
        tolerance,
        product_table,
        maximum_group_law_residuals,
        maximum_reciprocal_shift_residual,
        theta_squared_residual,
        maximum_kramers_residual,
        representation_sha256,
        diagnostics,
        metadata_origin,
        GATE_VALID,
        assessment,
        NaN,
        nothing,
        nothing,
        :legacy_absolute,
    )
end

"""Deterministic convergence record for one joint Z/U iteration."""
struct WannierizationIteration
    iteration::Int
    spread_total::Float64
    spread_standard_deviation::Float64
    maximum_covariance_error::Float64
    diagnostics::Union{Nothing, WannierizationIterationDiagnostics}

    function WannierizationIteration(
        iteration,
        spread_total,
        spread_standard_deviation,
        covariance,
        diagnostics::Union{Nothing, WannierizationIterationDiagnostics} = nothing,
    )
        iteration > 0 || throw(ArgumentError("iteration must be positive"))
        values = Float64.((spread_total, spread_standard_deviation, covariance))
        all(isfinite, values) || throw(ArgumentError("iteration record contains non-finite values"))
        return new(Int(iteration), values[1], values[2], values[3], diagnostics)
    end
end
