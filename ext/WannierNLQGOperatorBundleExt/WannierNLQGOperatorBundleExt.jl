module WannierNLQGOperatorBundleExt

using Dates
using HDF5
using JSON3
using SHA
using WannierNLQG.Core
using WannierNLQG.IO
import WannierNLQG

const AXIS_ORDER = "wannier_left,wannier_right,cartesian...,R"
const LOGICAL_CONVENTION = "R-last"
const BLOCH_PHASE_CONVENTION = "R_only"
const FOURIER_CONVENTION = "X(k)=sum_R exp(i*2*pi*k.R)*X_stored(R)/degeneracy(R)"
const PAYLOAD_ELEMENT_FORMAT = "compound(r::IEEE_F64LE,i::IEEE_F64LE)"
const HOST_IS_LITTLE_ENDIAN = Base.ENDIAN_BOM == 0x04030201
const POST_EXPORT_VALIDATION_SCHEMA = "wanniernlqg.post-export-validation"
const POST_EXPORT_VALIDATION_SCHEMA_VERSION = "1.0"
const OPERATOR_QUALIFICATION_SCHEMA = "wanniernlqg.operator-qualification"
const OPERATOR_QUALIFICATION_SCHEMA_VERSION = "1.2"
const PAIR_WIGNER_SEITZ_TRANSFORM_ALGORITHM = "WannierNLQG.PairWignerSeitzSpinQToRTransform"
const PAIR_WIGNER_SEITZ_TRANSFORM_POLICY = "PAIR_DEPENDENT_MINIMUM_DISTANCE_UNIT_DEGENERACY"

# Seal downstream validation metadata without including timestamps or HDF5 layout details.
function _post_export_validation_digest(values)
    names = (
        "source_bundle_sha256",
        "band_validation_summary_sha256",
        "response_validation_summary_sha256",
        "final_tb_usability",
        "final_physics_qualification",
        "final_production_eligible",
    )
    buffer = IOBuffer()
    write(buffer, POST_EXPORT_VALIDATION_SCHEMA, '\n', POST_EXPORT_VALIDATION_SCHEMA_VERSION, '\n')
    for name in names
        value = haskey(values, name) ? values[name] : values[Symbol(name)]
        write(buffer, name, '\0', string(value), '\n')
    end
    return bytes2hex(SHA.sha256(take!(buffer)))
end

const CONSTRUCTION_EVIDENCE_SCHEMA = "wanniernlqg.construction-evidence"
const CONSTRUCTION_EVIDENCE_VERSION = "1.0"
const CONSTRUCTION_EVIDENCE_FIELDS = (
    "construction_policy",
    "construction_gate_records_json",
    "manual_review_required",
    "construction_quality_failed",
    "diagnostic_classification",
    "diagnostic_only",
    "production_eligible",
)

"""Validate original construction records and their independent continuation/qualification flags."""
function _validated_construction_evidence(values)
    String(_dictionary_entry(values, "schema")) == CONSTRUCTION_EVIDENCE_SCHEMA ||
        throw(ArgumentError("construction-evidence schema differs"))
    String(_dictionary_entry(values, "schema_version")) == CONSTRUCTION_EVIDENCE_VERSION ||
        throw(ArgumentError("construction-evidence version differs"))
    policy = String(_dictionary_entry(values, "construction_policy"))
    policy in ("strict", "diagnostic") || throw(ArgumentError("invalid construction policy"))
    records = try
        JSON3.read(String(_dictionary_entry(values, "construction_gate_records_json")))
    catch
        throw(ArgumentError("malformed construction gate records JSON"))
    end
    records isa AbstractVector || throw(ArgumentError("construction gate records must be an array"))
    failed = false
    for record in records
        record isa AbstractDict ||
            throw(ArgumentError("construction gate record must be an object"))
        all(name -> haskey(record, name), ("code", "severity", "message", "context")) ||
            throw(ArgumentError("construction gate record is incomplete"))
        all(name -> record[name] isa AbstractString, ("code", "severity", "message")) ||
            throw(ArgumentError("construction gate record strings are invalid"))
        record["context"] isa AbstractDict ||
            throw(ArgumentError("construction gate context must be an object"))
        record["severity"] in ("info", "warning", "error") ||
            throw(ArgumentError("construction gate severity is invalid"))
        failed |=
            record["severity"] == "error" || get(record["context"], "gate_result", "") == "FAIL"
    end
    for name in (
        "manual_review_required",
        "construction_quality_failed",
        "diagnostic_only",
        "production_eligible",
    )
        _dictionary_entry(values, name) isa Bool ||
            throw(ArgumentError("construction-evidence $(name) must be Boolean"))
    end
    quality_failed = _dictionary_entry(values, "construction_quality_failed")
    failed &&
        !quality_failed &&
        throw(ArgumentError("original construction FAIL evidence was cleared"))
    isempty(String(_dictionary_entry(values, "diagnostic_classification"))) &&
        throw(ArgumentError("construction diagnostic classification is empty"))
    if policy == "diagnostic" || quality_failed
        _dictionary_entry(values, "diagnostic_only") &&
        !_dictionary_entry(values, "production_eligible") &&
        _dictionary_entry(values, "manual_review_required") ||
            throw(ArgumentError("diagnostic construction qualification flags disagree"))
    end
    return values
end

"""Build an additive construction contract only when the writer receives construction evidence."""
function _construction_evidence_for_write(diagnostics, eligibility)
    supplied(values, name) = haskey(values, name) || haskey(values, Symbol(name))
    any(
        name -> supplied(diagnostics, name) || supplied(eligibility, name),
        ("construction_policy", "construction_gate_records_json"),
    ) || return nothing
    values = Dict{String, Any}(
        "schema" => CONSTRUCTION_EVIDENCE_SCHEMA,
        "schema_version" => CONSTRUCTION_EVIDENCE_VERSION,
    )
    for name in CONSTRUCTION_EVIDENCE_FIELDS
        value = _dictionary_entry(diagnostics, name)
        value == _dictionary_entry(eligibility, name) ||
            throw(ArgumentError("construction evidence diagnostics/eligibility mismatch: $(name)"))
        values[name] = value
    end
    return _validated_construction_evidence(values)
end

"""Validate the construction seal and every duplicate before any public Packed read returns."""
function _read_construction_evidence_digest(handle)
    root = attributes(handle)
    marked = haskey(root, "construction_evidence_sha256")
    grouped = haskey(handle, "construction_evidence")
    # Old files have no sub-contract and retain their exact historical scientific digest.
    !marked && !grouped && return nothing
    marked && grouped || throw(ArgumentError("construction-evidence seal or payload is missing"))
    group = handle["construction_evidence"]
    values = _read_metadata_tree(group; skip_payload_sha256 = true)
    _validated_construction_evidence(values)
    digest = String(read(root["construction_evidence_sha256"]))
    digest ==
    String(_required_attribute(group, "payload_sha256")) ==
    _operator_qualification_digest(values) ||
        throw(ArgumentError("construction-evidence SHA-256 mismatch"))
    for name in CONSTRUCTION_EVIDENCE_FIELDS
        _dictionary_entry(values, name) == _required_attribute(handle["diagnostics"], name) ||
            throw(ArgumentError("construction evidence diagnostics mismatch: $(name)"))
        name == "construction_gate_records_json" && continue
        _dictionary_entry(values, name) == _required_attribute(handle, name) ||
            throw(ArgumentError("construction evidence root flag mismatch: $(name)"))
    end
    return digest
end

# Enumerate Cartesian components in the stable packed index order; reject ranks above two.
function _component_tuples(rank::Int)
    rank == 0 && return [(Int8(0), Int8(0))]
    rank == 1 && return [(Int8(first), Int8(0)) for first in 1:3]
    rank == 2 && return [(Int8(first), Int8(second)) for first in 1:3 for second in 1:3]
    throw(ArgumentError("Packed HDF5 supports Cartesian ranks zero, one, and two"))
end

# Copy one logical Cartesian component into contiguous column-major payload storage.
function _component_values(operator::RealSpaceOperator, indices::NTuple{2, Int8})
    rank = operator.spec.cartesian_rank
    rank == 0 && return vec(Array(@view operator.data[:, :, :]))
    rank == 1 && return vec(Array(@view operator.data[:, :, Int(indices[1]), :]))
    rank == 2 && return vec(Array(@view operator.data[:, :, Int(indices[1]), Int(indices[2]), :]))
    error("unreachable operator rank $(rank)")
end

# Hash the exact little-endian ComplexF64 component bytes without numerical conversion.
function _component_digest(values::Vector{ComplexF64})
    HOST_IS_LITTLE_ENDIAN ||
        throw(ArgumentError("Packed HDF5 writer requires a little-endian host"))
    return bytes2hex(SHA.sha256(reinterpret(UInt8, values)))
end

# Require every operator to share the same integer real-space support before packing.
function _operator_bundle_r_vectors(operators::AbstractDict)
    isempty(operators) && throw(ArgumentError("operator bundle must not be empty"))
    first_operator = first(values(operators))
    first_operator isa RealSpaceOperator ||
        throw(ArgumentError("operator bundle values must be RealSpaceOperator objects"))
    r_vectors = first_operator.r_vectors
    for operator in values(operators)
        operator isa RealSpaceOperator ||
            throw(ArgumentError("operator bundle values must be RealSpaceOperator objects"))
        operator.r_vectors == r_vectors ||
            throw(ArgumentError("operator bundle members must share identical R support"))
    end
    return r_vectors
end

# Encode scalar metadata as attributes and structured values as ordered HDF5 children.
function _write_metadata_value(parent, name::String, value)
    if value === nothing
        subgroup = create_group(parent, name)
        attributes(subgroup)["wanniernlqg_metadata_kind"] = "nothing"
    elseif value isa AbstractDict || value isa NamedTuple
        subgroup = create_group(parent, name)
        for key in sort!(String.(collect(keys(value))))
            source_key = value isa NamedTuple ? Symbol(key) : key
            if value isa AbstractDict && !haskey(value, source_key)
                source_key = Symbol(key)
            end
            _write_metadata_value(subgroup, key, value[source_key])
        end
    elseif value isa AbstractArray && !(value isa AbstractVector{<:AbstractString})
        parent[name] = value
    elseif value isa Tuple
        parent[name] = collect(value)
    elseif value isa AbstractVector{<:AbstractString}
        attributes(parent)[name] = join(String.(value), ",")
    elseif value isa Symbol
        attributes(parent)[name] = String(value)
    elseif value isa AbstractString || value isa Number || value isa Bool
        attributes(parent)[name] = value
    else
        attributes(parent)[name] = string(value)
    end
    return nothing
end

# Create a metadata group in sorted key order, accepting String or Symbol keys.
function _write_metadata_group(handle, name::String, values)
    group = create_group(handle, name)
    for key in sort!(String.(collect(keys(values))))
        source_key = values isa NamedTuple ? Symbol(key) : key
        if values isa AbstractDict && !haskey(values, source_key)
            source_key = Symbol(key)
        end
        _write_metadata_value(group, key, values[source_key])
    end
    return group
end

# Append a deterministic typed representation of nested qualification metadata.
function _qualification_digest_value!(buffer::Base.IO, value)
    if value isa AbstractDict || value isa NamedTuple
        write(buffer, UInt8('D'))
        for key in sort!(String.(collect(keys(value))))
            source_key = value isa NamedTuple ? Symbol(key) : key
            value isa AbstractDict && !haskey(value, source_key) && (source_key = Symbol(key))
            _qualification_digest_value!(buffer, key)
            _qualification_digest_value!(buffer, value[source_key])
        end
    elseif value isa AbstractArray
        write(buffer, UInt8('A'), Int64(ndims(value)))
        for dimension in size(value)
            write(buffer, Int64(dimension))
        end
        for entry in value
            _qualification_digest_value!(buffer, entry)
        end
    elseif value isa Bool
        write(buffer, UInt8('B'), UInt8(value))
    elseif value isa Integer
        write(buffer, UInt8('I'), string(value), '\0')
    elseif value isa AbstractFloat
        write(buffer, UInt8('F'), bitstring(Float64(value)), '\0')
    elseif value isa Symbol || value isa AbstractString
        bytes = codeunits(String(value))
        write(buffer, UInt8('S'), Int64(length(bytes)), bytes)
    elseif value === nothing
        write(buffer, UInt8('N'))
    else
        throw(ArgumentError("unsupported operator-qualification value type $(typeof(value))"))
    end
    return nothing
end

# Seal the typed qualification tree using deterministic recursive key ordering.
function _operator_qualification_digest(qualification)
    buffer = IOBuffer()
    _qualification_digest_value!(buffer, qualification)
    return bytes2hex(SHA.sha256(take!(buffer)))
end

"""Return a mutable, deterministically String-keyed qualification tree."""
function _mutable_qualification_tree(value)
    if value isa AbstractDict || value isa NamedTuple
        return Dict{String, Any}(
            String(key) => _mutable_qualification_tree(entry) for (key, entry) in pairs(value)
        )
    elseif value isa AbstractArray
        return [_mutable_qualification_tree(entry) for entry in value]
    end
    return value
end

"""Read one mandatory String- or Symbol-keyed provenance entry."""
function _required_provenance_entry(provenance, name::String)
    provenance isa AbstractDict ||
        provenance isa NamedTuple ||
        throw(ArgumentError("SPIN_PAIR_WIGNER_SEITZ_CONTRACT_NOT_RECORDED: provenance is missing"))
    if provenance isa NamedTuple
        key = Symbol(name)
        haskey(provenance, key) && return provenance[key]
    else
        haskey(provenance, name) && return provenance[name]
        key = Symbol(name)
        haskey(provenance, key) && return provenance[key]
    end
    throw(ArgumentError("SPIN_PAIR_WIGNER_SEITZ_CONTRACT_NOT_RECORDED: $(name) is missing"))
end

"""Bind the hard-gated pair-dependent WS transform evidence into qualification."""
function _bind_pair_wigner_seitz_qualification(raw, provenance, profile::Symbol, inventory)
    qualification = _mutable_qualification_tree(
        raw === nothing ? _default_operator_qualification(profile, inventory) : raw,
    )
    required_spin = RealSpaceOperatorKind[
        kind for kind in (
            REAL_SPACE_SPIN,
            REAL_SPACE_SPIN_TIMES_HAMILTONIAN,
            REAL_SPACE_SPIN_TIMES_POSITION,
            REAL_SPACE_SPIN_TIMES_HAMILTONIAN_POSITION,
        ) if kind in inventory
    ]
    isempty(required_spin) && return qualification

    algorithm_version = String(
        _required_provenance_entry(provenance, "operator_profile_assembly_algorithm_version"),
    )
    isempty(strip(algorithm_version)) &&
        throw(ArgumentError("SPIN_PAIR_WIGNER_SEITZ_CONTRACT_INVALID: algorithm version is empty"))
    policy = String(_required_provenance_entry(provenance, "pair_wigner_seitz_roundtrip_policy"))
    policy == PAIR_WIGNER_SEITZ_TRANSFORM_POLICY ||
        throw(ArgumentError("SPIN_PAIR_WIGNER_SEITZ_CONTRACT_INVALID: transform policy differs"))
    tolerance =
        Float64(_required_provenance_entry(provenance, "pair_wigner_seitz_roundtrip_tolerance"))
    isfinite(tolerance) && tolerance > 0.0 ||
        throw(ArgumentError("SPIN_PAIR_WIGNER_SEITZ_CONTRACT_INVALID: tolerance must be positive"))
    raw_residuals = _required_provenance_entry(provenance, "pair_wigner_seitz_roundtrip_residuals")
    raw_residuals isa AbstractDict ||
        raw_residuals isa NamedTuple ||
        throw(ArgumentError("SPIN_PAIR_WIGNER_SEITZ_CONTRACT_INVALID: residual map is missing"))
    residuals = Dict{String, Float64}(
        String(key) => Float64(value) for (key, value) in pairs(raw_residuals)
    )
    required_names = real_space_operator_name.(required_spin)
    Set(keys(residuals)) == Set(required_names) ||
        throw(ArgumentError("SPIN_PAIR_WIGNER_SEITZ_CONTRACT_INVALID: residual inventory differs"))

    records = qualification["operators"]
    maximum_residual = -Inf
    worst_operator = first(required_names)
    for name in required_names
        residual = residuals[name]
        isfinite(residual) && residual >= 0.0 || throw(
            ArgumentError("SPIN_PAIR_WIGNER_SEITZ_CONTRACT_INVALID: $(name) residual is invalid"),
        )
        residual <= tolerance || throw(
            ArgumentError(
                "SPIN_PAIR_WIGNER_SEITZ_ROUNDTRIP_FAILED: " *
                "$(name) residual $(residual) exceeds $(tolerance)",
            ),
        )
        contract = Dict{String, Any}(
            "algorithm" => PAIR_WIGNER_SEITZ_TRANSFORM_ALGORITHM,
            "algorithm_version" => algorithm_version,
            "policy" => policy,
            "residual" => residual,
            "tolerance" => tolerance,
            "status" => "PASS",
        )
        record = records[name]
        record["pair_wigner_seitz_transform"] = contract
        digest_payload = Dict{String, Any}(
            String(key) => value for
            (key, value) in pairs(record) if String(key) != "payload_sha256"
        )
        record["payload_sha256"] = _operator_qualification_digest(digest_payload)
        if residual > maximum_residual
            maximum_residual = residual
            worst_operator = name
        end
    end
    spin = qualification["families"]["spin"]
    spin["pair_wigner_seitz_transform"] = Dict{String, Any}(
        "algorithm" => PAIR_WIGNER_SEITZ_TRANSFORM_ALGORITHM,
        "algorithm_version" => algorithm_version,
        "policy" => policy,
        "maximum_residual" => maximum_residual,
        "tolerance" => tolerance,
        "worst_operator" => worst_operator,
        "status" => "PASS",
    )
    return qualification
end

# Construct explicit unqualified records; missing spin or finite-band evidence never implies PASS.
function _default_operator_qualification(profile::Symbol, inventory)
    spin_kinds = RealSpaceOperatorKind[
        kind for kind in (
            REAL_SPACE_SPIN,
            REAL_SPACE_SPIN_TIMES_HAMILTONIAN,
            REAL_SPACE_SPIN_TIMES_POSITION,
            REAL_SPACE_SPIN_TIMES_HAMILTONIAN_POSITION,
        ) if kind in inventory
    ]
    records = Dict{String, Any}()
    for kind in inventory
        spin_kind = kind in spin_kinds
        record = Dict{String, Any}(
            "source_status" => "NOT_RECORDED",
            "gauge_status" => "NOT_RECORDED",
            "source_provenance_sha256" => "NOT_RECORDED",
            "source_artifact_sha256" => "NOT_RECORDED",
            "source_input_sha256" => Dict{String, String}(),
            "source_band_gauge" => "NOT_RECORDED",
            "target_band_gauge" => "NOT_RECORDED",
            "gauge_artifact_sha256" => "NOT_RECORDED",
            "band_gauge_rotation_sha256" => "NOT_RECORDED",
            "band_gauge_rotation_semantics" => "legacy_alias_of_band_frame_transform_sha256",
            "band_frame_transform_sha256" => "NOT_RECORDED",
            "band_frame_contract_sha256" => "NOT_RECORDED",
            "band_frame_contract" => Dict{String, Any}(
                "schema" => "NOT_RECORDED",
                "schema_version" => "NOT_RECORDED",
                "status" => "NOT_RECORDED",
                "legacy" => false,
                "source_band_gauge" => "NOT_RECORDED",
                "target_band_gauge" => "NOT_RECORDED",
                "transform_sha256" => "NOT_RECORDED",
                "contract_sha256" => "NOT_RECORDED",
                "gauge_artifact_sha256" => "NOT_RECORDED",
                "metric_kind" => "NOT_RECORDED",
                "physical_isometry_maximum" => NaN,
                "physical_isometry_tolerance" => NaN,
                "replay_maximum" => NaN,
                "replay_tolerance" => NaN,
                "euclidean_nonunitarity_maximum" => NaN,
                "minimum_singular_value" => NaN,
                "maximum_condition_number" => NaN,
                "legacy" => false,
            ),
            "authoritative_hamiltonian" => "NOT_APPLICABLE",
            "authoritative_hamiltonian_digest" => "NOT_APPLICABLE",
            "authoritative_hamiltonian_input_sha256" => Dict{String, String}(),
            "symmetry_projection" => "NOT_RECORDED",
            "covariance_before" => NaN,
            "covariance_after" => NaN,
            "covariance_tolerance" => NaN,
            "idempotence_residual" => NaN,
            "idempotence_tolerance" => NaN,
            "finite_band_galerkin_status" => profile == :full ? "FAIL" : "NOT_APPLICABLE",
            "finite_band_risk_audit" => Dict{String, Any}("status" => "NOT_RECORDED"),
            "qualification" => spin_kind ? "FAIL" : "NOT_RECORDED",
            "reason" => "QUALIFICATION_NOT_PROVIDED",
        )
        record["payload_sha256"] = _operator_qualification_digest(record)
        records[real_space_operator_name(kind)] = record
    end
    has_spin = !isempty(spin_kinds)
    return Dict{String, Any}(
        "schema" => OPERATOR_QUALIFICATION_SCHEMA,
        "schema_version" => OPERATOR_QUALIFICATION_SCHEMA_VERSION,
        "operators" => records,
        "families" => Dict(
            "spin" => Dict(
                "route" => has_spin ? "unqualified" : "not_applicable",
                "overall" => has_spin ? "FAIL" : "NOT_APPLICABLE",
                "reason" =>
                    has_spin ? "QUALIFICATION_NOT_PROVIDED" : "PROFILE_HAS_NO_SPIN_FAMILY",
                "production_eligible" => false,
            ),
            "finite_band_galerkin" => Dict(
                "route" => profile == :full ? "unqualified" : "not_applicable",
                "overall" => profile == :full ? "FAIL" : "NOT_APPLICABLE",
                "reason" =>
                    profile == :full ? "QUALIFICATION_NOT_PROVIDED" :
                    "PROFILE_HAS_NO_COMPLETE_FINITE_BAND_OPERATOR_FAMILY",
                "production_eligible" => false,
                "qualification_stage" => profile == :full ? "NOT_RECORDED" : "NOT_APPLICABLE",
                "actual_operator_error_status" =>
                    profile == :full ? "NOT_RECORDED" : "NOT_APPLICABLE",
                "nbands_convergence_status" =>
                    profile == :full ? "NOT_RECORDED" : "NOT_APPLICABLE",
            ),
        ),
    )
end

# Read a mandatory qualification field through either its String or Symbol key.
function _dictionary_entry(values, name::String)
    values isa NamedTuple && return values[Symbol(name)]
    haskey(values, name) && return values[name]
    haskey(values, Symbol(name)) && return values[Symbol(name)]
    throw(ArgumentError("operator qualification is missing $(name)"))
end

"""Normalize the physical-frame contract shared by public 1.0 and legacy 6.2/6.3."""
function _bundle_band_frame_contract(provenance, profile::Symbol)
    key =
        haskey(provenance, "band_frame_contract") ? "band_frame_contract" :
        haskey(provenance, :band_frame_contract) ? :band_frame_contract : nothing
    if key === nothing
        status = profile in (:hamiltonian_position_spin, :full) ? "NOT_RECORDED" : "NOT_APPLICABLE"
        return Dict{String, Any}(
            "schema" => status,
            "schema_version" => status,
            "status" => status,
            "legacy" => false,
            "source_band_gauge" => status,
            "target_band_gauge" => status,
            "transform_sha256" => status,
            "contract_sha256" => status,
            "gauge_artifact_sha256" => status,
            "metric_kind" => status,
            "physical_isometry_maximum" => NaN,
            "physical_isometry_tolerance" => NaN,
            "replay_maximum" => NaN,
            "replay_tolerance" => NaN,
            "euclidean_nonunitarity_maximum" => NaN,
            "minimum_singular_value" => NaN,
            "maximum_condition_number" => NaN,
        )
    end
    raw = provenance[something(key)]
    raw isa AbstractDict ||
        raw isa NamedTuple ||
        throw(ArgumentError("band_frame_contract must be a dictionary"))
    names = (
        "schema",
        "schema_version",
        "status",
        "legacy",
        "source_band_gauge",
        "target_band_gauge",
        "transform_sha256",
        "contract_sha256",
        "gauge_artifact_sha256",
        "metric_kind",
        "physical_isometry_maximum",
        "physical_isometry_tolerance",
        "replay_maximum",
        "replay_tolerance",
        "euclidean_nonunitarity_maximum",
        "minimum_singular_value",
        "maximum_condition_number",
    )
    values = Dict{String, Any}(name => _dictionary_entry(raw, name) for name in names)
    status = String(values["status"])
    status in ("PASS", "NOT_APPLICABLE") ||
        throw(ArgumentError("band-frame contract is not qualified"))
    if status == "PASS"
        for name in ("transform_sha256", "contract_sha256")
            occursin(r"^[0-9a-f]{64}$", String(values[name])) ||
                throw(ArgumentError("band-frame $(name) is not a lowercase SHA-256"))
        end
        physical = Float64(values["physical_isometry_maximum"])
        physical_tolerance = Float64(values["physical_isometry_tolerance"])
        replay = Float64(values["replay_maximum"])
        replay_tolerance = Float64(values["replay_tolerance"])
        all(isfinite, (physical, physical_tolerance, replay, replay_tolerance)) ||
            throw(ArgumentError("band-frame qualification residuals are not finite"))
        physical <= physical_tolerance ||
            throw(ArgumentError("BAND_FRAME_PHYSICAL_ISOMETRY_FAILED"))
        replay <= replay_tolerance || throw(ArgumentError("BAND_FRAME_REPLAY_FAILED"))
    end
    return values
end

# Check inventory, frame, pair-transform, and family evidence before accepting qualification metadata.
function _validated_operator_qualification(raw, profile::Symbol, inventory)
    qualification = raw === nothing ? _default_operator_qualification(profile, inventory) : raw
    qualification isa AbstractDict ||
        qualification isa NamedTuple ||
        throw(ArgumentError("operator_qualification must be a dictionary"))
    String(_dictionary_entry(qualification, "schema")) == OPERATOR_QUALIFICATION_SCHEMA ||
        throw(ArgumentError("operator qualification schema differs"))
    String(_dictionary_entry(qualification, "schema_version")) ==
    OPERATOR_QUALIFICATION_SCHEMA_VERSION ||
        throw(ArgumentError("operator qualification version differs"))
    operators = _dictionary_entry(qualification, "operators")
    families = _dictionary_entry(qualification, "families")
    spin = _dictionary_entry(families, "spin")
    overall = String(_dictionary_entry(spin, "overall"))
    overall in ("PASS", "FAIL", "NOT_APPLICABLE", "LEGACY_NOT_RECORDED") ||
        throw(ArgumentError("invalid spin-family qualification status"))
    eligible = Bool(_dictionary_entry(spin, "production_eligible"))
    eligible == (overall == "PASS") ||
        throw(ArgumentError("spin-family production eligibility disagrees with status"))
    finite_band = _dictionary_entry(families, "finite_band_galerkin")
    finite_band_overall = String(_dictionary_entry(finite_band, "overall"))
    finite_band_overall in
    ("PASS", "FAIL", "RISK_RECORDED_NOT_CONVERGED", "NOT_APPLICABLE", "LEGACY_NOT_RECORDED") ||
        throw(ArgumentError("invalid finite-band Galerkin qualification status"))
    finite_band_eligible = Bool(_dictionary_entry(finite_band, "production_eligible"))
    finite_band_eligible == (finite_band_overall == "PASS") ||
        throw(ArgumentError("finite-band Galerkin production eligibility disagrees with status"))
    if profile == :full
        finite_band_overall == "NOT_APPLICABLE" &&
            throw(ArgumentError("finite-band Galerkin qualification is required for full profile"))
    else
        finite_band_overall == "NOT_APPLICABLE" ||
            throw(ArgumentError("finite-band Galerkin qualification must be NOT_APPLICABLE"))
    end
    if finite_band_overall == "RISK_RECORDED_NOT_CONVERGED"
        String(_dictionary_entry(finite_band, "actual_operator_error_status")) ==
        "NOT_AVAILABLE_WITHOUT_COMPLEMENT_HAMILTONIAN_OR_NBANDS_REFERENCE" ||
            throw(ArgumentError("finite-band actual-operator-error status differs"))
        String(_dictionary_entry(finite_band, "nbands_convergence_status")) == "NOT_ESTABLISHED" ||
            throw(ArgumentError("finite-band NBANDS convergence status differs"))
        _dictionary_entry(finite_band, "final_projector_galerkin_audit")
        _dictionary_entry(finite_band, "finite_band_risk_audit")
        _dictionary_entry(finite_band, "galerkin_block_audit")
        _dictionary_entry(finite_band, "galerkin_cancellation_audit")
    end
    required_spin = RealSpaceOperatorKind[
        kind for kind in (
            REAL_SPACE_SPIN,
            REAL_SPACE_SPIN_TIMES_HAMILTONIAN,
            REAL_SPACE_SPIN_TIMES_POSITION,
            REAL_SPACE_SPIN_TIMES_HAMILTONIAN_POSITION,
        ) if kind in inventory
    ]
    expected_names = Set(real_space_operator_name.(inventory))
    actual_names = Set(String.(collect(keys(operators))))
    actual_names == expected_names ||
        throw(ArgumentError("operator qualification inventory differs from bundle inventory"))
    isempty(required_spin) &&
        overall != "NOT_APPLICABLE" &&
        throw(ArgumentError("spin-family qualification must be NOT_APPLICABLE without spin"))
    !isempty(required_spin) &&
        overall == "NOT_APPLICABLE" &&
        throw(ArgumentError("spin-family qualification is required for a spin profile"))
    statuses = String[]
    pair_wigner_seitz_residuals = Dict{String, Float64}()
    pair_wigner_seitz_algorithm_version = nothing
    pair_wigner_seitz_tolerance = nothing
    for kind in inventory
        name = real_space_operator_name(kind)
        record = _dictionary_entry(operators, name)
        status = String(_dictionary_entry(record, "qualification"))
        status in ("PASS", "FAIL", "NOT_RECORDED") ||
            throw(ArgumentError("invalid qualification for operator $(name)"))
        kind in required_spin && push!(statuses, status)
        String(_dictionary_entry(record, "finite_band_galerkin_status")) == finite_band_overall ||
            throw(
                ArgumentError("operator $(name) finite-band Galerkin status disagrees with family"),
            )
        _dictionary_entry(record, "finite_band_risk_audit")
        payload_sha256 = String(_dictionary_entry(record, "payload_sha256"))
        occursin(r"^[0-9a-f]{64}$", payload_sha256) ||
            throw(ArgumentError("operator $(name) qualification payload digest is invalid"))
        digest_payload = Dict{String, Any}(
            String(key) => value for
            (key, value) in pairs(record) if String(key) != "payload_sha256"
        )
        payload_sha256 == _operator_qualification_digest(digest_payload) ||
            throw(ArgumentError("operator $(name) qualification payload SHA-256 mismatch"))
        source_status = String(_dictionary_entry(record, "source_status"))
        gauge_status = String(_dictionary_entry(record, "gauge_status"))
        source_status in ("PASS", "NOT_RECORDED") ||
            throw(ArgumentError("invalid source qualification for operator $(name)"))
        gauge_status in ("PASS", "NOT_RECORDED") ||
            throw(ArgumentError("invalid gauge qualification for operator $(name)"))
        for field in (
            "source_provenance_sha256",
            "source_artifact_sha256",
            "source_band_gauge",
            "target_band_gauge",
            "gauge_artifact_sha256",
            "band_gauge_rotation_sha256",
            "band_gauge_rotation_semantics",
            "band_frame_transform_sha256",
            "band_frame_contract_sha256",
            "band_frame_contract",
            "authoritative_hamiltonian",
            "authoritative_hamiltonian_digest",
        )
            _dictionary_entry(record, field)
        end
        source_input_sha256 = _dictionary_entry(record, "source_input_sha256")
        authority_input_sha256 = _dictionary_entry(record, "authoritative_hamiltonian_input_sha256")
        source_input_sha256 isa AbstractDict ||
            throw(ArgumentError("operator $(name) source input hashes must be a dictionary"))
        authority_input_sha256 isa AbstractDict || throw(
            ArgumentError(
                "operator $(name) authoritative Hamiltonian input hashes must be a dictionary",
            ),
        )
        projection = String(_dictionary_entry(record, "symmetry_projection"))
        projection in ("APPLIED", "NOT_APPLICABLE", "UPSTREAM_QUALIFIED", "NOT_RECORDED") ||
            throw(ArgumentError("operator $(name) symmetry-projection status is invalid"))
        for field in (
            "covariance_before",
            "covariance_after",
            "covariance_tolerance",
            "idempotence_residual",
            "idempotence_tolerance",
        )
            _dictionary_entry(record, field) isa Real ||
                throw(ArgumentError("operator $(name) $(field) must be numeric"))
        end
        if kind in required_spin
            transform = _dictionary_entry(record, "pair_wigner_seitz_transform")
            String(_dictionary_entry(transform, "algorithm")) ==
            PAIR_WIGNER_SEITZ_TRANSFORM_ALGORITHM ||
                throw(ArgumentError("operator $(name) pair-WS transform algorithm differs"))
            algorithm_version = String(_dictionary_entry(transform, "algorithm_version"))
            isempty(strip(algorithm_version)) && throw(
                ArgumentError("operator $(name) pair-WS transform algorithm version is empty"),
            )
            String(_dictionary_entry(transform, "policy")) == PAIR_WIGNER_SEITZ_TRANSFORM_POLICY ||
                throw(ArgumentError("operator $(name) pair-WS transform policy differs"))
            residual = Float64(_dictionary_entry(transform, "residual"))
            tolerance = Float64(_dictionary_entry(transform, "tolerance"))
            all(isfinite, (residual, tolerance)) && residual >= 0.0 && tolerance > 0.0 ||
                throw(ArgumentError("operator $(name) pair-WS transform residual is invalid"))
            residual <= tolerance ||
                throw(ArgumentError("operator $(name) pair-WS transform roundtrip failed"))
            String(_dictionary_entry(transform, "status")) == "PASS" ||
                throw(ArgumentError("operator $(name) pair-WS transform is not qualified"))
            pair_wigner_seitz_algorithm_version === nothing ||
                something(pair_wigner_seitz_algorithm_version) == algorithm_version ||
                throw(ArgumentError("spin-family pair-WS transform algorithm versions differ"))
            pair_wigner_seitz_tolerance === nothing ||
                something(pair_wigner_seitz_tolerance) == tolerance ||
                throw(ArgumentError("spin-family pair-WS transform tolerances differ"))
            pair_wigner_seitz_algorithm_version = algorithm_version
            pair_wigner_seitz_tolerance = tolerance
            pair_wigner_seitz_residuals[name] = residual
        end
        isempty(String(_dictionary_entry(record, "reason"))) &&
            throw(ArgumentError("operator $(name) qualification reason is empty"))
        if source_status == "PASS"
            for field in ("source_provenance_sha256", "source_artifact_sha256")
                occursin(r"^[0-9a-f]{64}$", String(_dictionary_entry(record, field))) ||
                    throw(ArgumentError("operator $(name) $(field) must be a lowercase SHA-256"))
            end
            isempty(source_input_sha256) &&
                throw(ArgumentError("operator $(name) source input hashes must not be empty"))
            for (key, digest) in pairs(source_input_sha256)
                occursin(r"^[0-9a-f]{64}$", String(digest)) ||
                    throw(ArgumentError("operator $(name) source input hash $(key) is invalid"))
            end
            rotation_sha256 = String(_dictionary_entry(record, "band_gauge_rotation_sha256"))
            transform_sha256 = String(_dictionary_entry(record, "band_frame_transform_sha256"))
            contract_sha256 = String(_dictionary_entry(record, "band_frame_contract_sha256"))
            String(_dictionary_entry(record, "band_gauge_rotation_semantics")) ==
            "legacy_alias_of_band_frame_transform_sha256" || throw(
                ArgumentError("operator $(name) legacy band-gauge alias semantics are invalid"),
            )
            rotation_sha256 == transform_sha256 || throw(
                ArgumentError(
                    "operator $(name) legacy band-gauge alias differs from frame transform",
                ),
            )
            if kind in required_spin
                occursin(r"^[0-9a-f]{64}$", transform_sha256) || throw(
                    ArgumentError(
                        "operator $(name) band_frame_transform_sha256 must be a lowercase SHA-256",
                    ),
                )
                occursin(r"^[0-9a-f]{64}$", contract_sha256) || throw(
                    ArgumentError(
                        "operator $(name) band_frame_contract_sha256 must be a lowercase SHA-256",
                    ),
                )
            else
                transform_sha256 == "NOT_APPLICABLE" ||
                    occursin(r"^[0-9a-f]{64}$", transform_sha256) ||
                    throw(ArgumentError("operator $(name) band-frame transform seal is invalid"))
                contract_sha256 == "NOT_APPLICABLE" ||
                    occursin(r"^[0-9a-f]{64}$", contract_sha256) ||
                    throw(ArgumentError("operator $(name) band-frame contract seal is invalid"))
            end
            frame_contract = _dictionary_entry(record, "band_frame_contract")
            frame_contract isa AbstractDict ||
                frame_contract isa NamedTuple ||
                throw(ArgumentError("operator $(name) band-frame contract must be a dictionary"))
            for field in (
                "schema",
                "schema_version",
                "status",
                "legacy",
                "source_band_gauge",
                "target_band_gauge",
                "transform_sha256",
                "contract_sha256",
                "gauge_artifact_sha256",
                "metric_kind",
                "physical_isometry_maximum",
                "physical_isometry_tolerance",
                "replay_maximum",
                "replay_tolerance",
                "euclidean_nonunitarity_maximum",
                "minimum_singular_value",
                "maximum_condition_number",
            )
                _dictionary_entry(frame_contract, field)
            end
            String(_dictionary_entry(frame_contract, "transform_sha256")) == transform_sha256 ||
                throw(ArgumentError("operator $(name) nested frame-transform seal differs"))
            String(_dictionary_entry(frame_contract, "contract_sha256")) == contract_sha256 ||
                throw(ArgumentError("operator $(name) nested frame-contract seal differs"))
            if kind in required_spin
                String(_dictionary_entry(frame_contract, "status")) == "PASS" ||
                    throw(ArgumentError("operator $(name) band-frame contract is not qualified"))
                physical = Float64(_dictionary_entry(frame_contract, "physical_isometry_maximum"))
                physical_tolerance =
                    Float64(_dictionary_entry(frame_contract, "physical_isometry_tolerance"))
                replay = Float64(_dictionary_entry(frame_contract, "replay_maximum"))
                replay_tolerance = Float64(_dictionary_entry(frame_contract, "replay_tolerance"))
                physical <= physical_tolerance ||
                    throw(ArgumentError("operator $(name) physical-isometry contract failed"))
                replay <= replay_tolerance ||
                    throw(ArgumentError("operator $(name) frame-replay contract failed"))
            end
        end
        requires_hamiltonian = kind in (
            REAL_SPACE_HAMILTONIAN,
            REAL_SPACE_HAMILTONIAN_WEIGHTED_CONNECTION,
            REAL_SPACE_HAMILTONIAN_WEIGHTED_AXIAL_DERIVATIVE_OVERLAP,
            REAL_SPACE_SPIN_TIMES_HAMILTONIAN,
            REAL_SPACE_SPIN_TIMES_HAMILTONIAN_POSITION,
        )
        authority = String(_dictionary_entry(record, "authoritative_hamiltonian"))
        authority_digest = String(_dictionary_entry(record, "authoritative_hamiltonian_digest"))
        if requires_hamiltonian && source_status == "PASS"
            WannierNLQG.SymmetryFoundation.validate_authoritative_hamiltonian_key(authority)
            occursin(r"^[0-9a-f]{64}$", authority_digest) || throw(
                ArgumentError(
                    "operator $(name) authoritative Hamiltonian digest must be a SHA-256",
                ),
            )
            isempty(authority_input_sha256) && throw(
                ArgumentError(
                    "operator $(name) authoritative Hamiltonian input hashes must not be empty",
                ),
            )
            for (key, digest) in pairs(authority_input_sha256)
                occursin(r"^[0-9a-f]{64}$", String(digest)) || throw(
                    ArgumentError(
                        "operator $(name) authoritative Hamiltonian input hash $(key) is invalid",
                    ),
                )
            end
        elseif !requires_hamiltonian
            authority == "NOT_APPLICABLE" && authority_digest == "NOT_APPLICABLE" ||
                throw(ArgumentError("operator $(name) must not claim a Hamiltonian authority"))
        end
    end
    overall == "PASS" &&
        any(!=("PASS"), statuses) &&
        throw(ArgumentError("spin-family PASS disagrees with per-operator qualification"))
    if !isempty(required_spin)
        transform = _dictionary_entry(spin, "pair_wigner_seitz_transform")
        String(_dictionary_entry(transform, "algorithm")) ==
        PAIR_WIGNER_SEITZ_TRANSFORM_ALGORITHM ||
            throw(ArgumentError("spin-family pair-WS transform algorithm differs"))
        String(_dictionary_entry(transform, "algorithm_version")) ==
        something(pair_wigner_seitz_algorithm_version) ||
            throw(ArgumentError("spin-family pair-WS transform algorithm version differs"))
        String(_dictionary_entry(transform, "policy")) == PAIR_WIGNER_SEITZ_TRANSFORM_POLICY ||
            throw(ArgumentError("spin-family pair-WS transform policy differs"))
        maximum_residual = Float64(_dictionary_entry(transform, "maximum_residual"))
        tolerance = Float64(_dictionary_entry(transform, "tolerance"))
        maximum_residual == maximum(values(pair_wigner_seitz_residuals)) ||
            throw(ArgumentError("spin-family pair-WS maximum residual disagrees"))
        tolerance == something(pair_wigner_seitz_tolerance) ||
            throw(ArgumentError("spin-family pair-WS tolerance disagrees"))
        required_names = real_space_operator_name.(required_spin)
        expected_worst = first(required_names)
        for name in Iterators.drop(required_names, 1)
            pair_wigner_seitz_residuals[name] > pair_wigner_seitz_residuals[expected_worst] &&
                (expected_worst = name)
        end
        String(_dictionary_entry(transform, "worst_operator")) == expected_worst ||
            throw(ArgumentError("spin-family pair-WS worst operator disagrees"))
        String(_dictionary_entry(transform, "status")) == "PASS" ||
            throw(ArgumentError("spin-family pair-WS transform is not qualified"))
    end
    return qualification
end

"""Read nested qualification metadata, optionally omitting the root group seal."""
function _read_metadata_tree(object; skip_payload_sha256::Bool = false)
    metadata_attributes = HDF5.attributes(object)
    if haskey(metadata_attributes, "wanniernlqg_metadata_kind")
        String(read(metadata_attributes["wanniernlqg_metadata_kind"])) == "nothing" ||
            throw(ArgumentError("unsupported typed metadata node"))
        isempty(keys(object)) || throw(ArgumentError("typed nothing metadata node has children"))
        return nothing
    end
    values = Dict{String, Any}()
    for name in sort!(String.(collect(keys(metadata_attributes))))
        skip_payload_sha256 && name == "payload_sha256" && continue
        values[name] = read(metadata_attributes[name])
    end
    for name in sort!(String.(collect(keys(object))))
        child = object[name]
        values[name] = child isa HDF5.Group ? _read_metadata_tree(child) : read(child)
    end
    return values
end

# Bind numerical component hashes, geometry, provenance, and qualification to the recorded wire version.
function _scientific_content_digest(
    profile::Symbol,
    inventory,
    lattice::Matrix{Float64},
    r_vectors::Matrix{Int},
    degeneracies::Vector{Int},
    component_hashes::Vector{String},
    paired_tb_sha256,
    schema_version::AbstractString = OPERATOR_BUNDLE_SCHEMA_VERSION,
    geometry_content_sha256 = nothing,
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
    parent_audit_policy::AbstractString = "legacy_hard_gate",
    outer_mask_sha256::AbstractString = "NOT_RECORDED",
    frozen_mask_sha256::AbstractString = "NOT_RECORDED",
    target_subspace_contract_sha256::AbstractString = "NOT_RECORDED",
    target_leakage_semantics::AbstractString = "NOT_APPLICABLE",
    target_leakage_formula_sha256::AbstractString = "NOT_RECORDED",
    target_leakage_threshold::Union{Nothing, Real} = nothing,
    derivative_overlap_source::AbstractString = "legacy_unspecified",
    derivative_overlap_completeness::AbstractString = "legacy_unspecified",
    derivative_overlap_source_sha256::AbstractString = "not_provided",
    derivative_overlap_algorithm_version::AbstractString = "legacy_unspecified",
    target_authority::AbstractString = "NOT_APPLICABLE",
    operator_qualification_sha256::AbstractString = "LEGACY_NOT_RECORDED",
    band_frame_contract_sha256::AbstractString = "LEGACY_BAND_FRAME_CONTRACT_NOT_RECORDED",
    construction_evidence_sha256::Union{Nothing, AbstractString} = nothing,
)
    # Field gates follow the complete legacy layout; the digest retains the wire label.
    contract_version = schema_version == "1.0" ? "6.3" : schema_version
    buffer = IOBuffer()
    write(buffer, OPERATOR_BUNDLE_SCHEMA, '\n', String(schema_version), '\n')
    write(buffer, String(profile), '\n')
    write(buffer, join(real_space_operator_name.(inventory), ","), '\n')
    write(buffer, reinterpret(UInt8, vec(lattice)))
    write(buffer, reinterpret(UInt8, vec(Int64.(r_vectors))))
    write(buffer, reinterpret(UInt8, Int64.(degeneracies)))
    write(buffer, join(component_hashes, "\n"), '\n')
    write(buffer, paired_tb_sha256 === nothing ? "not_provided" : String(paired_tb_sha256))
    geometry_content_sha256 === nothing || write(buffer, '\n', String(geometry_content_sha256))
    if contract_version in
       ("5.3", "5.4", "5.5", "5.6", "5.7", "5.8", "5.9", "5.10", "6.0", "6.1", "6.2", "6.3")
        write(
            buffer,
            '\n',
            String(authoritative_hamiltonian),
            '\n',
            String(authoritative_hamiltonian_sha256),
        )
    end
    if contract_version in
       ("5.4", "5.5", "5.6", "5.7", "5.8", "5.9", "5.10", "6.0", "6.1", "6.2", "6.3")
        for value in (
            energy_shift_qualification,
            maximum_energy_shift_audit_reference_ev,
            rms_energy_shift_audit_reference_ev,
            target_energy_shift_audit_status,
            symmetrized_parent_energy_shift_audit_status,
        )
            write(buffer, '\n', String(value))
        end
    end
    if contract_version in ("5.5", "5.6", "5.7", "5.8", "5.9", "5.10", "6.0", "6.1", "6.2", "6.3")
        write(
            buffer,
            '\n',
            String(residual_gate_phase),
            '\n',
            String(raw_preflight_diagnostic_status),
        )
    end
    if contract_version in ("5.6", "5.7", "5.8", "5.9", "5.10", "6.0", "6.1", "6.2", "6.3")
        write(
            buffer,
            '\n',
            String(native_difference_qualification),
            '\n',
            String(native_difference_audit_status),
        )
    end
    if contract_version in ("5.7", "5.8", "5.9", "5.10", "6.0", "6.1", "6.2", "6.3")
        for value in (
            qualification_scope,
            target_anchor,
            target_complement_completion,
            target_complement_max_element_ev,
            auxiliary_parent_qualification,
            symmetrized_target_subspace_status,
            auxiliary_parent_audit_status,
            string(target_scope_production_eligible),
        )
            write(buffer, '\n', String(value))
        end
    end
    if contract_version in ("5.8", "5.9", "5.10", "6.0", "6.1", "6.2", "6.3")
        for value in (
            derivative_overlap_source,
            derivative_overlap_completeness,
            derivative_overlap_source_sha256,
            derivative_overlap_algorithm_version,
        )
            write(buffer, '\n', String(value))
        end
    end
    if contract_version in ("5.9", "5.10", "6.0", "6.1", "6.2", "6.3")
        for value in (
            parent_audit_policy,
            target_authority,
            outer_mask_sha256,
            frozen_mask_sha256,
            target_subspace_contract_sha256,
        )
            write(buffer, '\n', String(value))
        end
    end
    if contract_version in ("5.10", "6.0", "6.1", "6.2", "6.3")
        write(buffer, '\n', String(target_leakage_semantics))
        write(buffer, '\n', String(target_leakage_formula_sha256))
        write(buffer, UInt8(target_leakage_threshold !== nothing))
        target_leakage_threshold === nothing ||
            write(buffer, reinterpret(UInt8, [Float64(target_leakage_threshold)]))
    end
    contract_version in ("6.1", "6.2", "6.3") &&
        write(buffer, '\n', String(operator_qualification_sha256))
    contract_version in ("6.2", "6.3") && write(buffer, '\n', String(band_frame_contract_sha256))
    construction_evidence_sha256 === nothing || write(
        buffer,
        '\n',
        CONSTRUCTION_EVIDENCE_SCHEMA,
        '\n',
        CONSTRUCTION_EVIDENCE_VERSION,
        '\n',
        String(construction_evidence_sha256),
    )
    return bytes2hex(SHA.sha256(take!(buffer)))
end

# Read one String- or Symbol-keyed geometry entry.
function _geometry_entry(geometry, name::String)
    if geometry isa NamedTuple
        key = Symbol(name)
        haskey(geometry, key) || throw(ArgumentError("geometry is missing $(name)"))
        return geometry[key]
    end
    haskey(geometry, name) && return geometry[name]
    key = Symbol(name)
    haskey(geometry, key) && return geometry[key]
    throw(ArgumentError("geometry is missing $(name)"))
end

# Hash the scientific geometry contract recorded by Packed HDF5 v5.
function _geometry_content_digest(
    wannier_center_policy::Symbol,
    real_space_replica_policy::Symbol,
    production_eligible::Bool,
    minimum_distance_materialized::Bool,
    mp_grid::NTuple{3, Int},
    wannier_center_tolerance::Float64,
    wigner_seitz_tolerance::Float64,
    wigner_seitz_search_size::Int,
    raw_centers_cartesian::Matrix{Float64},
    raw_centers_fractional::Matrix{Float64},
    final_centers_cartesian::Matrix{Float64},
    final_centers_fractional::Matrix{Float64},
    alignment_lattice_shifts::Matrix{Int},
    replica_mapping_sha256::String,
)
    buffer = IOBuffer()
    write(buffer, String(wannier_center_policy), '\n', String(real_space_replica_policy), '\n')
    write(buffer, production_eligible ? "true\n" : "false\n")
    write(buffer, minimum_distance_materialized ? "true\n" : "false\n")
    write(buffer, reinterpret(UInt8, Int64[mp_grid...]))
    write(buffer, reinterpret(UInt8, [wannier_center_tolerance, wigner_seitz_tolerance]))
    write(buffer, reinterpret(UInt8, Int64[wigner_seitz_search_size]))
    write(buffer, reinterpret(UInt8, vec(raw_centers_cartesian)))
    write(buffer, reinterpret(UInt8, vec(raw_centers_fractional)))
    write(buffer, reinterpret(UInt8, vec(final_centers_cartesian)))
    write(buffer, reinterpret(UInt8, vec(final_centers_fractional)))
    write(buffer, reinterpret(UInt8, vec(Int64.(alignment_lattice_shifts))))
    write(buffer, replica_mapping_sha256)
    return bytes2hex(SHA.sha256(take!(buffer)))
end

# Validate and normalize the mandatory v5 geometry metadata.
function _validated_geometry_metadata(
    geometry,
    num_wannier::Int,
    lattice::Matrix{Float64},
    centers_cartesian::Matrix{Float64},
    centers_fractional::Matrix{Float64},
    degeneracies::Vector{Int},
)
    wannier_center_policy = Symbol(String(_geometry_entry(geometry, "wannier_center_policy")))
    real_space_replica_policy =
        Symbol(String(_geometry_entry(geometry, "real_space_replica_policy")))
    wannier_center_policy in (:symmetrize, :validate, :keep_input) ||
        throw(ArgumentError("geometry has invalid wannier_center_policy"))
    real_space_replica_policy in (:input, :minimum_distance) ||
        throw(ArgumentError("geometry has invalid real_space_replica_policy"))
    production_eligible = Bool(_geometry_entry(geometry, "production_eligible"))
    minimum_distance_materialized = Bool(_geometry_entry(geometry, "minimum_distance_materialized"))
    minimum_distance_materialized == (real_space_replica_policy == :minimum_distance) ||
        throw(ArgumentError("geometry Minimal Distance materialization flag disagrees with policy"))
    minimum_distance_materialized &&
        !all(==(1), degeneracies) &&
        throw(ArgumentError("Minimal Distance bundles must use unit degeneracies"))
    mp_grid_values = Int.(_geometry_entry(geometry, "mp_grid"))
    length(mp_grid_values) == 3 && all(>(0), mp_grid_values) ||
        throw(ArgumentError("geometry mp_grid must contain three positive integers"))
    mp_grid = Tuple(mp_grid_values)
    wannier_center_tolerance = Float64(_geometry_entry(geometry, "wannier_center_tolerance"))
    wigner_seitz_tolerance = Float64(_geometry_entry(geometry, "wigner_seitz_tolerance"))
    wigner_seitz_search_size = Int(_geometry_entry(geometry, "wigner_seitz_search_size"))
    isfinite(wannier_center_tolerance) && wannier_center_tolerance > 0.0 ||
        throw(ArgumentError("geometry wannier_center_tolerance must be positive"))
    isfinite(wigner_seitz_tolerance) && wigner_seitz_tolerance > 0.0 ||
        throw(ArgumentError("geometry wigner_seitz_tolerance must be positive"))
    wigner_seitz_search_size > 0 ||
        throw(ArgumentError("geometry wigner_seitz_search_size must be positive"))
    raw_centers_cartesian =
        Matrix{Float64}(_geometry_entry(geometry, "raw_wannier_centers_cartesian"))
    raw_centers_fractional =
        Matrix{Float64}(_geometry_entry(geometry, "raw_wannier_centers_fractional"))
    final_centers_cartesian =
        Matrix{Float64}(_geometry_entry(geometry, "final_wannier_centers_cartesian"))
    final_centers_fractional =
        Matrix{Float64}(_geometry_entry(geometry, "final_wannier_centers_fractional"))
    alignment_lattice_shifts =
        Matrix{Int}(_geometry_entry(geometry, "center_alignment_lattice_shifts"))
    for (label, values) in (
        ("raw Cartesian", raw_centers_cartesian),
        ("raw fractional", raw_centers_fractional),
        ("final Cartesian", final_centers_cartesian),
        ("final fractional", final_centers_fractional),
    )
        size(values) == (num_wannier, 3) ||
            throw(ArgumentError("geometry $(label) centers have invalid dimensions"))
        all(isfinite, values) || throw(ArgumentError("geometry $(label) centers are non-finite"))
    end
    size(alignment_lattice_shifts) == (num_wannier, 3) ||
        throw(ArgumentError("geometry center-alignment shifts have invalid dimensions"))
    final_centers_cartesian == centers_cartesian ||
        throw(ArgumentError("geometry final Cartesian centers disagree with position operator"))
    maximum(abs, final_centers_fractional .- centers_fractional; init = 0.0) <= 1.0e-12 ||
        throw(ArgumentError("geometry final fractional centers disagree with position operator"))
    maximum(abs, raw_centers_fractional * lattice .- raw_centers_cartesian; init = 0.0) <=
    1.0e-10 || throw(ArgumentError("geometry raw center coordinate systems disagree"))
    replica_mapping_sha256 = String(_geometry_entry(geometry, "replica_mapping_sha256"))
    length(replica_mapping_sha256) == 64 ||
        throw(ArgumentError("geometry replica_mapping_sha256 is invalid"))
    digest = _geometry_content_digest(
        wannier_center_policy,
        real_space_replica_policy,
        production_eligible,
        minimum_distance_materialized,
        mp_grid,
        wannier_center_tolerance,
        wigner_seitz_tolerance,
        wigner_seitz_search_size,
        raw_centers_cartesian,
        raw_centers_fractional,
        centers_cartesian,
        centers_fractional,
        alignment_lattice_shifts,
        replica_mapping_sha256,
    )
    return (
        wannier_center_policy,
        real_space_replica_policy,
        production_eligible,
        minimum_distance_materialized,
        mp_grid,
        raw_centers_cartesian,
        raw_centers_fractional,
        final_centers_cartesian,
        final_centers_fractional,
        geometry_content_sha256 = digest,
    )
end

# Extract real position diagonals in Angstrom from the unique home-cell block after degeneracy division.
function _bundle_wannier_centers(operators, r_vectors, degeneracies)
    position = get(operators, REAL_SPACE_POSITION, nothing)
    position === nothing && error("operator bundle requires a position operator")
    home_indices = findall(index -> all(iszero, @view(r_vectors[:, index])), axes(r_vectors, 2))
    length(home_indices) == 1 || error("operator bundle requires exactly one R=(0,0,0) block")
    home = only(home_indices)
    centers = zeros(Float64, size(position.data, 1), 3)
    @inbounds for orbital in axes(centers, 1), direction in 1:3
        value = position.data[orbital, orbital, direction, home] / degeneracies[home]
        isfinite(real(value)) && isfinite(imag(value)) ||
            error("operator-bundle Wannier centers contain non-finite values")
        abs(imag(value)) <= 1.0e-10 ||
            error("operator-bundle Wannier centers have a non-negligible imaginary part")
        centers[orbital, direction] = real(value)
    end
    return centers
end

# Describe the persisted physical units for Hamiltonian, position, spin, and derived operators.
function _unit_contract(kind::RealSpaceOperatorKind)
    kind == REAL_SPACE_HAMILTONIAN && return "eV"
    kind == REAL_SPACE_POSITION && return "Angstrom"
    kind == REAL_SPACE_SPIN && return "dimensionless Pauli-spin convention"
    return "WannierNLQG native operator convention"
end

# Validate the complete profile and provenance, then pack little-endian components with their integrity seals.
function write_real_space_operator_bundle(
    filename::AbstractString,
    lattice,
    degeneracies,
    operators::AbstractDict;
    profile::Symbol,
    overwrite::Bool = false,
    paired_tb_sha256 = nothing,
    provenance = Dict{String, Any}(),
    symmetry = Dict{String, Any}(),
    geometry,
    diagnostics = Dict{String, Any}(),
    eligibility = Dict{String, Any}(),
)
    path = abspath(filename)
    ispath(path) &&
        !overwrite &&
        throw(ArgumentError("refusing to overwrite operator bundle: $(path)"))
    HOST_IS_LITTLE_ENDIAN ||
        throw(ArgumentError("Packed HDF5 writer requires a little-endian host"))
    HDF5.enable_complex_support()

    lattice_matrix = Matrix{Float64}(lattice)
    size(lattice_matrix) == (3, 3) || throw(ArgumentError("lattice must have size (3, 3)"))
    all(isfinite, lattice_matrix) || throw(ArgumentError("lattice contains non-finite values"))
    inventory = validate_operator_profile(profile, keys(operators))
    r_vectors = _operator_bundle_r_vectors(operators)
    degeneracy_values = Int.(degeneracies)
    length(degeneracy_values) == size(r_vectors, 2) ||
        throw(ArgumentError("degeneracies do not match real-space support"))
    all(>(0), degeneracy_values) ||
        throw(ArgumentError("operator-bundle degeneracies must be positive"))
    num_wannier = size(first(values(operators)).data, 1)
    num_r_vectors = size(r_vectors, 2)
    centers = _bundle_wannier_centers(operators, r_vectors, degeneracy_values)
    centers_fractional = Matrix{Float64}(undef, num_wannier, 3)
    for orbital in 1:num_wannier
        centers_fractional[orbital, :] .=
            real_space_cartesian_to_fractional(@view(centers[orbital, :]), lattice_matrix)
    end
    center_digest = bytes2hex(SHA.sha256(reinterpret(UInt8, vec(centers))))
    normalized_geometry = _validated_geometry_metadata(
        geometry,
        num_wannier,
        lattice_matrix,
        centers,
        centers_fractional,
        degeneracy_values,
    )

    payload = ComplexF64[]
    entries = OperatorBundleIndexEntry[]
    for kind in inventory
        haskey(operators, kind) || error("validated inventory lost operator $(kind)")
        operator = operators[kind]
        operator.spec.kind == kind ||
            throw(ArgumentError("operator dictionary key and specification kind disagree"))
        size(operator.data, 1) == num_wannier ||
            throw(ArgumentError("operator Wannier dimensions disagree"))
        for component in _component_tuples(operator.spec.cartesian_rank)
            values = _component_values(operator, component)
            offset = UInt64(length(payload))
            append!(payload, values)
            push!(
                entries,
                OperatorBundleIndexEntry(
                    kind,
                    UInt8(operator.spec.cartesian_rank),
                    component,
                    offset,
                    UInt64(length(values)),
                    (num_wannier, num_wannier, num_r_vectors),
                    _component_digest(values),
                ),
            )
        end
    end
    isempty(payload) && throw(ArgumentError("operator bundle payload must not be empty"))
    component_hashes = getfield.(entries, :component_sha256)
    authoritative_hamiltonian = String(
        haskey(eligibility, "authoritative_hamiltonian") ?
        eligibility["authoritative_hamiltonian"] :
        haskey(eligibility, :authoritative_hamiltonian) ?
        eligibility[:authoritative_hamiltonian] : "native_dft",
    )
    authoritative_hamiltonian_sha256 = String(
        haskey(eligibility, "authoritative_hamiltonian_sha256") ?
        eligibility["authoritative_hamiltonian_sha256"] :
        haskey(eligibility, :authoritative_hamiltonian_sha256) ?
        eligibility[:authoritative_hamiltonian_sha256] : "LEGACY_NATIVE_DFT",
    )
    eligibility_string(name, default) = String(
        haskey(eligibility, name) ? eligibility[name] :
        haskey(eligibility, Symbol(name)) ? eligibility[Symbol(name)] : default,
    )
    eligibility_bool(name, default) = Bool(
        haskey(eligibility, name) ? eligibility[name] :
        haskey(eligibility, Symbol(name)) ? eligibility[Symbol(name)] : default,
    )
    function eligibility_optional_float(name)
        raw =
            haskey(eligibility, name) ? eligibility[name] :
            haskey(eligibility, Symbol(name)) ? eligibility[Symbol(name)] : nothing
        raw === nothing && return nothing
        raw isa Real && return Float64(raw)
        text = String(raw)
        text in ("", "NOT_APPLICABLE", "NOT_RECORDED") && return nothing
        value = tryparse(Float64, text)
        value === nothing &&
            throw(ArgumentError("invalid floating-point eligibility field $(name)"))
        return value
    end
    energy_shift_qualification =
        eligibility_string("energy_shift_qualification", "legacy_energy_shift_hard_gate")
    maximum_energy_shift_audit_reference_ev =
        eligibility_string("maximum_energy_shift_audit_reference_ev", "NOT_APPLICABLE")
    rms_energy_shift_audit_reference_ev =
        eligibility_string("rms_energy_shift_audit_reference_ev", "NOT_APPLICABLE")
    target_energy_shift_audit_status =
        eligibility_string("target_energy_shift_audit_status", "NOT_APPLICABLE")
    symmetrized_parent_energy_shift_audit_status =
        eligibility_string("symmetrized_parent_energy_shift_audit_status", "NOT_APPLICABLE")
    residual_gate_phase = eligibility_string("residual_gate_phase", "legacy_pre_symmetrization")
    raw_preflight_diagnostic_status =
        eligibility_string("raw_preflight_diagnostic_status", "NOT_APPLICABLE")
    native_difference_qualification =
        eligibility_string("native_difference_qualification", "legacy_hard_gate")
    native_difference_audit_status =
        eligibility_string("native_difference_audit_status", "NOT_APPLICABLE")
    qualification_scope = eligibility_string("qualification_scope", "full_parent")
    target_anchor = eligibility_string("target_anchor", "NOT_APPLICABLE")
    target_complement_completion =
        eligibility_string("target_complement_completion", "NOT_APPLICABLE")
    target_complement_max_element_ev =
        eligibility_string("target_complement_max_element_ev", "NOT_APPLICABLE")
    auxiliary_parent_qualification =
        eligibility_string("auxiliary_parent_qualification", "legacy_hard_gate")
    symmetrized_target_subspace_status =
        eligibility_string("symmetrized_target_subspace_status", "NOT_APPLICABLE")
    auxiliary_parent_audit_status =
        eligibility_string("auxiliary_parent_audit_status", "NOT_APPLICABLE")
    target_scope_production_eligible = eligibility_bool("target_scope_production_eligible", false)
    parent_audit_policy = eligibility_string("parent_audit_policy", "legacy_hard_gate")
    target_authority = eligibility_string("target_authority", "NOT_APPLICABLE")
    outer_mask_sha256 = eligibility_string("disentanglement_outer_mask_sha256", "NOT_RECORDED")
    frozen_mask_sha256 = eligibility_string("disentanglement_frozen_mask_sha256", "NOT_RECORDED")
    target_subspace_contract_sha256 =
        eligibility_string("target_subspace_contract_sha256", "NOT_RECORDED")
    target_leakage_semantics = eligibility_string("target_leakage_semantics", "NOT_APPLICABLE")
    target_leakage_formula_sha256 =
        eligibility_string("target_leakage_formula_sha256", "NOT_RECORDED")
    target_leakage_threshold = eligibility_optional_float("target_leakage_threshold")
    provenance_string(name, default) = String(
        haskey(provenance, name) ? provenance[name] :
        haskey(provenance, Symbol(name)) ? provenance[Symbol(name)] : default,
    )
    derivative_overlap_source = provenance_string(
        "derivative_overlap_source",
        profile in (:derivative, :full) ? "mmn_product" : "not_applicable",
    )
    derivative_overlap_completeness = provenance_string(
        "derivative_overlap_completeness",
        profile in (:derivative, :full) ? "finite_window_internal" : "not_applicable",
    )
    derivative_overlap_source_sha256 =
        provenance_string("derivative_overlap_source_sha256", "not_provided")
    derivative_overlap_algorithm_version = provenance_string(
        "derivative_overlap_algorithm_version",
        profile in (:derivative, :full) ? "mmn-product-v1" : "not_applicable",
    )
    derivative_overlap_completeness in
    ("not_applicable", "finite_window_internal", "full_hilbert_space") ||
        throw(ArgumentError("unsupported derivative_overlap_completeness metadata"))
    if derivative_overlap_completeness == "full_hilbert_space"
        derivative_overlap_source == "wannier90_uIu" || throw(
            ArgumentError(
                "full derivative overlap requires derivative_overlap_source=wannier90_uIu",
            ),
        )
        occursin(r"^[0-9a-f]{64}$", derivative_overlap_source_sha256) || throw(
            ArgumentError("full derivative overlap requires a lowercase hexadecimal uIu SHA-256"),
        )
        derivative_overlap_algorithm_version == FULL_DERIVATIVE_OVERLAP_ALGORITHM_VERSION || throw(
            ArgumentError(
                "full derivative overlap requires algorithm " *
                FULL_DERIVATIVE_OVERLAP_ALGORITHM_VERSION,
            ),
        )
    end
    if profile == :full
        required_digests = (
            "SPN_sha256",
            "uIu_sha256",
            "uHu_sha256",
            "sIu_sha256",
            "sHu_sha256",
            "uIu_provenance_sha256",
            "uHu_provenance_sha256",
            "sIu_provenance_sha256",
            "sHu_provenance_sha256",
        )
        for name in required_digests
            occursin(r"^[0-9a-f]{64}$", provenance_string(name, "")) || throw(
                ArgumentError(
                    "SCHEMA6_FULL_PROVENANCE_REQUIRED: $(name) must be a lowercase SHA-256",
                ),
            )
        end
        for name in (
            "uiu_generation_algorithm_version",
            "uHu_generation_algorithm_version",
            "sIu_generation_algorithm_version",
            "sHu_generation_algorithm_version",
        )
            isempty(strip(provenance_string(name, ""))) &&
                throw(ArgumentError("SCHEMA6_FULL_PROVENANCE_REQUIRED: $(name) is missing"))
        end
        provenance_string("authoritative_hamiltonian", "") == authoritative_hamiltonian || throw(
            ArgumentError(
                "HAMILTONIAN_REFERENCE_MISMATCH: full-profile provenance authority differs",
            ),
        )
        provenance_string("authoritative_hamiltonian_digest", "") ==
        authoritative_hamiltonian_sha256 || throw(
            ArgumentError("HAMILTONIAN_REFERENCE_MISMATCH: full-profile provenance digest differs"),
        )
        function required_hash_map(name)
            raw =
                haskey(provenance, name) ? provenance[name] :
                haskey(provenance, Symbol(name)) ? provenance[Symbol(name)] : nothing
            raw isa AbstractDict ||
                throw(ArgumentError("SCHEMA6_FULL_PROVENANCE_REQUIRED: $(name) must be a hash map"))
            isempty(raw) &&
                throw(ArgumentError("SCHEMA6_FULL_PROVENANCE_REQUIRED: $(name) must not be empty"))
            for (key, value) in pairs(raw)
                occursin(r"^[0-9a-f]{64}$", String(value)) || throw(
                    ArgumentError(
                        "SCHEMA6_FULL_PROVENANCE_REQUIRED: $(name).$(key) is not a SHA-256",
                    ),
                )
            end
            return raw
        end
        required_hash_map("uIu_input_sha256")
        required_hash_map("uHu_input_sha256")
        required_hash_map("sIu_input_sha256")
        required_hash_map("sHu_input_sha256")
        required_hash_map("authoritative_hamiltonian_input_sha256")
    end
    authoritative_hamiltonian =
        WannierNLQG.SymmetryFoundation.validate_authoritative_hamiltonian_key(
            authoritative_hamiltonian,
        )
    is_symmetrized_authority = authoritative_hamiltonian == "symmetrized_dft_hamiltonian"
    is_symmetrized_authority &&
        energy_shift_qualification != "audit_only" &&
        throw(
            ArgumentError(
                "HAMILTONIAN_REFERENCE_MISMATCH: schema-5.4 symmetrized bundle requires audit-only energy shifts",
            ),
        )
    is_symmetrized_authority &&
        residual_gate_phase != "post_symmetrization" &&
        throw(
            ArgumentError(
                "HAMILTONIAN_REFERENCE_MISMATCH: schema-5.5 symmetrized bundle requires post-symmetrization residual gates",
            ),
        )
    is_symmetrized_authority &&
        native_difference_qualification != "audit_only" &&
        throw(
            ArgumentError(
                "HAMILTONIAN_REFERENCE_MISMATCH: schema-5.6 symmetrized bundle requires audit-only native differences",
            ),
        )
    if qualification_scope == "target_subspace"
        parent_audit_policy == "audit_only" || throw(
            ArgumentError(
                "TARGET_SUBSPACE_CONTRACT_MISMATCH: target bundle requires audit-only parent policy",
            ),
        )
        target_authority == "outer_window" || throw(
            ArgumentError(
                "TARGET_SUBSPACE_CONTRACT_MISMATCH: target bundle authority must be outer_window",
            ),
        )
        for (name, digest) in (
            ("outer mask", outer_mask_sha256),
            ("frozen mask", frozen_mask_sha256),
            ("target-subspace contract", target_subspace_contract_sha256),
        )
            occursin(r"^[0-9a-f]{64}$", digest) ||
                throw(ArgumentError("TARGET_SUBSPACE_CONTRACT_MISMATCH: $(name) digest is invalid"))
        end
        target_leakage_semantics == WannierNLQG.Wannierization.TB_TARGET_LEAKAGE_WEIGHT_SEMANTICS ||
            throw(
                ArgumentError(
                    "UNSUPPORTED_LEGACY_TARGET_LEAKAGE_SEMANTICS: target bundle does not declare PAW-S leakage weights",
                ),
            )
        target_leakage_formula_sha256 ==
        WannierNLQG.Wannierization.TB_TARGET_LEAKAGE_WEIGHT_FORMULA_SHA256 || throw(
            ArgumentError(
                "TARGET_SUBSPACE_CONTRACT_MISMATCH: target leakage formula SHA-256 is incompatible",
            ),
        )
        target_leakage_threshold !== nothing &&
        isfinite(something(target_leakage_threshold)) &&
        0.0 <=
        something(target_leakage_threshold) <=
        WannierNLQG.Wannierization.TB_TARGET_LEAKAGE_MAXIMUM_THRESHOLD || throw(
            ArgumentError(
                "TARGET_SUBSPACE_CONTRACT_MISMATCH: target leakage threshold must not exceed 5e-6",
            ),
        )
    end
    if is_symmetrized_authority
        qualification_scope == "target_subspace" ||
            throw(ArgumentError("HAMILTONIAN_REFERENCE_MISMATCH: target bundle scope differs"))
        target_anchor == "completed_symmetrized_target" ||
            throw(ArgumentError("HAMILTONIAN_REFERENCE_MISMATCH: target bundle anchor differs"))
        auxiliary_parent_qualification == "audit_only" || throw(
            ArgumentError(
                "HAMILTONIAN_REFERENCE_MISMATCH: target bundle requires audit-only auxiliary parent",
            ),
        )
    end
    raw_qualification =
        haskey(provenance, "operator_qualification") ? provenance["operator_qualification"] :
        haskey(provenance, :operator_qualification) ? provenance[:operator_qualification] : nothing
    bound_qualification =
        _bind_pair_wigner_seitz_qualification(raw_qualification, provenance, profile, inventory)
    operator_qualification =
        _validated_operator_qualification(bound_qualification, profile, inventory)
    operator_qualification_sha256 = _operator_qualification_digest(operator_qualification)
    spin_family = _dictionary_entry(_dictionary_entry(operator_qualification, "families"), "spin")
    spin_family_qualification = String(_dictionary_entry(spin_family, "overall"))
    spin_family_qualification_reason = String(_dictionary_entry(spin_family, "reason"))
    spin_family_production_eligible = Bool(_dictionary_entry(spin_family, "production_eligible"))
    finite_band_family = _dictionary_entry(
        _dictionary_entry(operator_qualification, "families"),
        "finite_band_galerkin",
    )
    finite_band_galerkin_qualification = String(_dictionary_entry(finite_band_family, "overall"))
    finite_band_galerkin_qualification_reason =
        String(_dictionary_entry(finite_band_family, "reason"))
    finite_band_galerkin_production_eligible =
        Bool(_dictionary_entry(finite_band_family, "production_eligible"))
    band_frame_contract = _bundle_band_frame_contract(provenance, profile)
    band_frame_contract_sha256 = String(band_frame_contract["contract_sha256"])
    construction_evidence = _construction_evidence_for_write(diagnostics, eligibility)
    construction_evidence_sha256 =
        construction_evidence === nothing ? nothing :
        _operator_qualification_digest(construction_evidence)
    scientific_digest = _scientific_content_digest(
        profile,
        inventory,
        lattice_matrix,
        r_vectors,
        degeneracy_values,
        component_hashes,
        paired_tb_sha256,
        OPERATOR_BUNDLE_SCHEMA_VERSION,
        normalized_geometry.geometry_content_sha256,
        authoritative_hamiltonian,
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
        parent_audit_policy,
        outer_mask_sha256,
        frozen_mask_sha256,
        target_subspace_contract_sha256,
        target_leakage_semantics,
        target_leakage_formula_sha256,
        target_leakage_threshold,
        derivative_overlap_source,
        derivative_overlap_completeness,
        derivative_overlap_source_sha256,
        derivative_overlap_algorithm_version,
        target_authority,
        operator_qualification_sha256,
        band_frame_contract_sha256,
        construction_evidence_sha256,
    )

    mkpath(dirname(path))
    h5open(path, "w") do handle
        root_attributes = attributes(handle)
        root_attributes["schema"] = OPERATOR_BUNDLE_SCHEMA
        root_attributes["schema_version"] = OPERATOR_BUNDLE_SCHEMA_VERSION
        root_attributes["wanniernlqg_version"] = string(Base.pkgversion(WannierNLQG))
        root_attributes["generated_at_utc"] =
            Dates.format(now(UTC), dateformat"yyyy-mm-ddTHH:MM:SS.sssZ")
        root_attributes["operator_profile"] = String(profile)
        root_attributes["operator_count"] = length(inventory)
        root_attributes["operator_inventory"] = join(real_space_operator_name.(inventory), ",")
        root_attributes["available_matrix_capabilities"] =
            join(available_matrix_capabilities(inventory), ",")
        root_attributes["logical_convention"] = LOGICAL_CONVENTION
        root_attributes["wannier_gauge"] = "input Wannier gauge"
        root_attributes["bloch_phase_convention"] = BLOCH_PHASE_CONVENTION
        root_attributes["storage_wannier_center_convention"] = "Convention_II"
        root_attributes["wannier_center_source"] = "position_R0_diagonal"
        root_attributes["wannier_center_cartesian_sha256"] = center_digest
        root_attributes["wannier_center_policy"] = String(normalized_geometry.wannier_center_policy)
        root_attributes["real_space_replica_policy"] =
            String(normalized_geometry.real_space_replica_policy)
        overall_eligible = if haskey(eligibility, "production_eligible")
            Bool(eligibility["production_eligible"])
        elseif haskey(eligibility, :production_eligible)
            Bool(eligibility[:production_eligible])
        else
            normalized_geometry.production_eligible
        end
        overall_eligible == normalized_geometry.production_eligible || throw(
            ArgumentError("root and geometry production eligibility must use one explicit value"),
        )
        profile in (:hamiltonian_position_spin, :full) &&
            overall_eligible &&
            !spin_family_production_eligible &&
            throw(
                ArgumentError(
                    "SPIN_FAMILY_NOT_PRODUCTION_QUALIFIED: bundle cannot assert production eligibility",
                ),
            )
        profile == :full &&
            overall_eligible &&
            !finite_band_galerkin_production_eligible &&
            throw(
                ArgumentError(
                    "FINITE_BAND_GALERKIN_NOT_PRODUCTION_QUALIFIED: full bundle cannot assert production eligibility",
                ),
            )
        profile in (:hamiltonian_position_spin, :full) &&
            overall_eligible &&
            String(band_frame_contract["status"]) != "PASS" &&
            throw(
                ArgumentError(
                    "BAND_FRAME_CONTRACT_NOT_QUALIFIED: spin-bearing bundle cannot assert production eligibility",
                ),
            )
        root_attributes["production_eligible"] = overall_eligible
        scoped_production_eligible = if haskey(eligibility, "scoped_production_eligible")
            Bool(eligibility["scoped_production_eligible"])
        elseif haskey(eligibility, :scoped_production_eligible)
            Bool(eligibility[:scoped_production_eligible])
        else
            overall_eligible
        end
        global_production_eligible = if haskey(eligibility, "global_production_eligible")
            Bool(eligibility["global_production_eligible"])
        elseif haskey(eligibility, :global_production_eligible)
            Bool(eligibility[:global_production_eligible])
        else
            false
        end
        global_production_eligible == false || throw(
            ArgumentError("operator bundle cannot override native/global production qualification"),
        )
        root_attributes["authoritative_hamiltonian"] = authoritative_hamiltonian
        root_attributes["authoritative_hamiltonian_sha256"] = authoritative_hamiltonian_sha256
        root_attributes["energy_shift_qualification"] = energy_shift_qualification
        root_attributes["maximum_energy_shift_audit_reference_ev"] =
            maximum_energy_shift_audit_reference_ev
        root_attributes["rms_energy_shift_audit_reference_ev"] = rms_energy_shift_audit_reference_ev
        root_attributes["target_energy_shift_audit_status"] = target_energy_shift_audit_status
        root_attributes["symmetrized_parent_energy_shift_audit_status"] =
            symmetrized_parent_energy_shift_audit_status
        root_attributes["residual_gate_phase"] = residual_gate_phase
        root_attributes["raw_preflight_diagnostic_status"] = raw_preflight_diagnostic_status
        root_attributes["native_difference_qualification"] = native_difference_qualification
        root_attributes["native_difference_audit_status"] = native_difference_audit_status
        root_attributes["qualification_scope"] = qualification_scope
        root_attributes["target_anchor"] = target_anchor
        root_attributes["target_complement_completion"] = target_complement_completion
        root_attributes["target_complement_max_element_ev"] = target_complement_max_element_ev
        root_attributes["auxiliary_parent_qualification"] = auxiliary_parent_qualification
        root_attributes["symmetrized_target_subspace_status"] = symmetrized_target_subspace_status
        root_attributes["auxiliary_parent_audit_status"] = auxiliary_parent_audit_status
        root_attributes["target_scope_production_eligible"] = target_scope_production_eligible
        root_attributes["scoped_production_eligible"] = scoped_production_eligible
        root_attributes["global_production_eligible"] = false
        root_attributes["parent_audit_policy"] = parent_audit_policy
        root_attributes["target_authority"] = target_authority
        root_attributes["outer_mask_sha256"] = outer_mask_sha256
        root_attributes["frozen_mask_sha256"] = frozen_mask_sha256
        root_attributes["target_subspace_contract_sha256"] = target_subspace_contract_sha256
        root_attributes["target_leakage_semantics"] = target_leakage_semantics
        root_attributes["target_leakage_formula_sha256"] = target_leakage_formula_sha256
        root_attributes["target_leakage_threshold"] = something(target_leakage_threshold, NaN)
        root_attributes["target_leakage_threshold_present"] = target_leakage_threshold !== nothing
        root_attributes["derivative_overlap_source"] = derivative_overlap_source
        root_attributes["derivative_overlap_completeness"] = derivative_overlap_completeness
        root_attributes["derivative_overlap_source_sha256"] = derivative_overlap_source_sha256
        root_attributes["derivative_overlap_algorithm_version"] =
            derivative_overlap_algorithm_version
        root_attributes["operator_qualification_sha256"] = operator_qualification_sha256
        root_attributes["spin_family_qualification"] = spin_family_qualification
        root_attributes["spin_family_qualification_reason"] = spin_family_qualification_reason
        root_attributes["spin_family_production_eligible"] = spin_family_production_eligible
        root_attributes["finite_band_galerkin_qualification"] = finite_band_galerkin_qualification
        root_attributes["finite_band_galerkin_qualification_reason"] =
            finite_band_galerkin_qualification_reason
        root_attributes["finite_band_galerkin_production_eligible"] =
            finite_band_galerkin_production_eligible
        root_attributes["band_frame_contract_status"] = String(band_frame_contract["status"])
        root_attributes["band_frame_transform_sha256"] =
            String(band_frame_contract["transform_sha256"])
        root_attributes["band_frame_contract_sha256"] = band_frame_contract_sha256
        root_attributes["band_frame_metric_kind"] = String(band_frame_contract["metric_kind"])
        root_attributes["band_frame_physical_isometry_maximum"] =
            Float64(band_frame_contract["physical_isometry_maximum"])
        root_attributes["band_frame_physical_isometry_tolerance"] =
            Float64(band_frame_contract["physical_isometry_tolerance"])
        root_attributes["band_frame_replay_maximum"] =
            Float64(band_frame_contract["replay_maximum"])
        root_attributes["band_frame_replay_tolerance"] =
            Float64(band_frame_contract["replay_tolerance"])
        root_attributes["band_frame_euclidean_nonunitarity_maximum"] =
            Float64(band_frame_contract["euclidean_nonunitarity_maximum"])
        root_attributes["band_frame_minimum_singular_value"] =
            Float64(band_frame_contract["minimum_singular_value"])
        root_attributes["band_frame_maximum_condition_number"] =
            Float64(band_frame_contract["maximum_condition_number"])
        for (name, default) in (
            ("wannierization_status", ""),
            ("solver_status", ""),
            ("solver_convergence", ""),
            ("initialization_status", ""),
            ("initializer_algorithm_version", ""),
            ("numerical_quality", ""),
            ("tb_export_status", ""),
            ("converged", false),
            ("diagnostic_only", false),
            ("physics_qualification", ""),
            ("tb_usability", ""),
            ("stopping_reason", ""),
            ("iterations_completed", -1),
            ("last_attempted_iteration", -1),
            ("last_accepted_iteration", -1),
            ("last_persisted_iteration", -1),
            ("convergence_metric", NaN),
            ("convergence_tolerance", NaN),
            ("checkpoint_sha256", ""),
            ("input_sha256", ""),
            ("spread_metric", ""),
            ("amn_sha256", ""),
            ("projection_basis_sha256", ""),
            ("finite_difference_stencil_sha256", ""),
            ("optimizer_strategy", ""),
            ("projector_residual", NaN),
            ("z_residual", NaN),
            ("u_residual", NaN),
            ("solver_validation_ready", false),
            ("isometry_before_export", NaN),
            ("isometry_after_export", NaN),
            ("polar_repaired_for_export", false),
            ("frozen_residual", NaN),
            ("hamiltonian_hermiticity_residual", NaN),
            ("position_hermiticity_residual", NaN),
            ("roundtrip_tolerance", NaN),
        )
            value =
                haskey(eligibility, name) ? eligibility[name] :
                haskey(eligibility, Symbol(name)) ? eligibility[Symbol(name)] : default
            root_attributes[name] = value
        end
        root_attributes["minimum_distance_materialized"] =
            normalized_geometry.minimum_distance_materialized
        root_attributes["geometry_content_sha256"] = normalized_geometry.geometry_content_sha256
        root_attributes["fourier_convention"] = FOURIER_CONVENTION
        root_attributes["normalization_convention"] = "serialized values; divide by degeneracy once"
        root_attributes["payload_element_format"] = PAYLOAD_ELEMENT_FORMAT
        root_attributes["payload_byte_order"] = "little-endian"
        root_attributes["paired_tb_sha256"] =
            paired_tb_sha256 === nothing ? "" : String(paired_tb_sha256)
        root_attributes["scientific_content_sha256"] = scientific_digest
        root_attributes["symmetrization_status"] = if haskey(symmetry, "symmetrization_status")
            String(symmetry["symmetrization_status"])
        elseif haskey(symmetry, :symmetrization_status)
            String(symmetry[:symmetrization_status])
        else
            "not_provided"
        end

        model_group = create_group(handle, "model")
        model_group["num_orbitals"] = Int64(num_wannier)
        model_group["lattice"] = lattice_matrix
        model_group["r_vectors"] = Int64.(r_vectors)
        model_group["degeneracies"] = Int64.(degeneracy_values)
        model_group["wannier_centers_cartesian"] = centers
        model_group["wannier_centers_fractional"] = centers_fractional

        payload_group = create_group(handle, "payload")
        payload_group["complex128"] = payload

        index_group = create_group(handle, "index")
        index_group["operator_kind_id"] = UInt8[UInt8(entry.kind) for entry in entries]
        index_group["component_rank"] = UInt8[entry.component_rank for entry in entries]
        index_group["component_indices"] =
            reduce(hcat, Int8[entry.component_indices...] for entry in entries)
        index_group["offset_elements"] = UInt64[entry.offset_elements for entry in entries]
        index_group["length_elements"] = UInt64[entry.length_elements for entry in entries]
        index_group["logical_shape"] =
            reduce(hcat, UInt64[entry.logical_shape...] for entry in entries)
        index_group["component_sha256"] = component_hashes

        operators_group = create_group(handle, "operators")
        for kind in inventory
            operator = operators[kind]
            name = real_space_operator_name(kind)
            group = create_group(operators_group, name)
            group_attributes = attributes(group)
            group_attributes["canonical_name"] = name
            group_attributes["operator_kind_id"] = UInt8(kind)
            group_attributes["cartesian_rank"] = operator.spec.cartesian_rank
            group_attributes["axis_roles_order"] = AXIS_ORDER
            group_attributes["inversion_parity"] = operator.spec.inversion_parity
            group_attributes["time_reversal_parity"] = operator.spec.time_reversal_parity
            group_attributes["rotate_cartesian"] = operator.spec.rotate_cartesian
            group_attributes["wannier_gauge"] = "input Wannier gauge"
            group_attributes["wannier_center_convention"] = "Convention_II"
            group_attributes["center_source"] = "model/wannier_centers_cartesian"
            group_attributes["unit_contract"] = _unit_contract(kind)
            group_attributes["normalization_convention"] = "serialized values; divide by degeneracy once"
            group["index_entries"] =
                UInt64[index - 1 for (index, entry) in pairs(entries) if entry.kind == kind]
        end

        _write_metadata_group(handle, "symmetry", symmetry)
        _write_metadata_group(handle, "geometry", geometry)
        _write_metadata_group(handle, "diagnostics", diagnostics)
        if construction_evidence !== nothing
            construction_group =
                _write_metadata_group(handle, "construction_evidence", construction_evidence)
            attributes(construction_group)["payload_sha256"] = construction_evidence_sha256
            root_attributes["construction_evidence_sha256"] = construction_evidence_sha256
            for name in CONSTRUCTION_EVIDENCE_FIELDS
                name in
                ("construction_gate_records_json", "diagnostic_only", "production_eligible") &&
                    continue
                root_attributes[name] = construction_evidence[name]
            end
        end
        _write_metadata_group(handle, "provenance", provenance)
        qualification_group = _write_metadata_group(handle, "qualification", operator_qualification)
        attributes(qualification_group)["payload_sha256"] = operator_qualification_sha256
        create_group(handle, "tb_symmetry_qualification")
        compatibility_group = create_group(handle, "compatibility")
        attributes(compatibility_group)["legacy_cache_converter"] = "unsupported"
        attributes(compatibility_group)["minimum_reader_schema"] = "6.2"
        flush(handle)
        dataset = handle["payload/complex128"]
        HDF5.iscontiguous(dataset) || error("payload dataset is not contiguous")
        HDF5.ismmappable(dataset) || error("payload dataset is not mmap compatible")
    end
    return path
end

# Read a mandatory HDF5 attribute; report absent contract metadata as ArgumentError.
function _required_attribute(object, name::AbstractString)
    haskey(attributes(object), String(name)) ||
        throw(ArgumentError("operator bundle is missing attribute $(name)"))
    return read(attributes(object)[String(name)])
end

# Resolve the comma-separated canonical inventory and reject repeated operator kinds.
function _split_inventory(value)
    text = String(value)
    isempty(text) && return RealSpaceOperatorKind[]
    return operator_kind_from_storage_name.(split(text, ','))
end

# Read and validate the mandatory scientific geometry contract from schema v5.
function _read_v5_geometry(
    handle,
    num_wannier::Int,
    lattice,
    centers,
    centers_fractional,
    degeneracies,
)
    geometry = handle["geometry"]
    wannier_center_policy = Symbol(String(_required_attribute(geometry, "wannier_center_policy")))
    real_space_replica_policy =
        Symbol(String(_required_attribute(geometry, "real_space_replica_policy")))
    production_eligible = Bool(_required_attribute(geometry, "production_eligible"))
    minimum_distance_materialized =
        Bool(_required_attribute(geometry, "minimum_distance_materialized"))
    mp_grid_values = Int.(read(geometry["mp_grid"]))
    length(mp_grid_values) == 3 && all(>(0), mp_grid_values) ||
        throw(ArgumentError("operator bundle geometry mp_grid is invalid"))
    mp_grid = Tuple(mp_grid_values)
    wannier_center_tolerance = Float64(_required_attribute(geometry, "wannier_center_tolerance"))
    wigner_seitz_tolerance = Float64(_required_attribute(geometry, "wigner_seitz_tolerance"))
    wigner_seitz_search_size = Int(_required_attribute(geometry, "wigner_seitz_search_size"))
    raw_centers_cartesian = Matrix{Float64}(read(geometry["raw_wannier_centers_cartesian"]))
    raw_centers_fractional = Matrix{Float64}(read(geometry["raw_wannier_centers_fractional"]))
    final_geometry_cartesian = Matrix{Float64}(read(geometry["final_wannier_centers_cartesian"]))
    final_geometry_fractional = Matrix{Float64}(read(geometry["final_wannier_centers_fractional"]))
    alignment_lattice_shifts = Matrix{Int}(read(geometry["center_alignment_lattice_shifts"]))
    replica_mapping_sha256 = String(_required_attribute(geometry, "replica_mapping_sha256"))
    size(raw_centers_cartesian) == (num_wannier, 3) &&
    size(raw_centers_fractional) == (num_wannier, 3) ||
        throw(ArgumentError("operator bundle raw Wannier-center dimensions are invalid"))
    final_geometry_cartesian == centers ||
        throw(ArgumentError("operator bundle geometry and model Cartesian centers disagree"))
    maximum(abs, final_geometry_fractional .- centers_fractional; init = 0.0) <= 1.0e-12 ||
        throw(ArgumentError("operator bundle geometry and model fractional centers disagree"))
    minimum_distance_materialized == (real_space_replica_policy == :minimum_distance) ||
        throw(ArgumentError("operator bundle replica policy is inconsistent"))
    minimum_distance_materialized &&
        !all(==(1), degeneracies) &&
        throw(ArgumentError("Minimal Distance bundle degeneracies must all be one"))
    digest = _geometry_content_digest(
        wannier_center_policy,
        real_space_replica_policy,
        production_eligible,
        minimum_distance_materialized,
        mp_grid,
        wannier_center_tolerance,
        wigner_seitz_tolerance,
        wigner_seitz_search_size,
        raw_centers_cartesian,
        raw_centers_fractional,
        centers,
        centers_fractional,
        alignment_lattice_shifts,
        replica_mapping_sha256,
    )
    digest == String(_required_attribute(handle, "geometry_content_sha256")) ||
        throw(ArgumentError("operator bundle geometry-content SHA-256 mismatch"))
    String(_required_attribute(handle, "wannier_center_policy")) == String(wannier_center_policy) ||
        throw(ArgumentError("root and geometry Wannier-center policies disagree"))
    String(_required_attribute(handle, "real_space_replica_policy")) ==
    String(real_space_replica_policy) ||
        throw(ArgumentError("root and geometry replica policies disagree"))
    Bool(_required_attribute(handle, "production_eligible")) == production_eligible ||
        throw(ArgumentError("root and geometry production eligibility disagree"))
    Bool(_required_attribute(handle, "minimum_distance_materialized")) ==
    minimum_distance_materialized ||
        throw(ArgumentError("root and geometry Minimal Distance flags disagree"))
    return (
        raw_centers_cartesian,
        raw_centers_fractional,
        wannier_center_policy,
        real_space_replica_policy,
        production_eligible,
        minimum_distance_materialized,
        mp_grid,
        wigner_seitz_tolerance = wigner_seitz_tolerance,
        wigner_seitz_search_size = wigner_seitz_search_size,
        replica_mapping_sha256 = replica_mapping_sha256,
        geometry_content_sha256 = digest,
    )
end

# Decode stored-version metadata, verify scientific seals, and retain all legacy qualification restrictions.
function _manifest_from_handle(path::String, handle)
    String(_required_attribute(handle, "schema")) == OPERATOR_BUNDLE_SCHEMA ||
        throw(ArgumentError("unsupported operator-bundle schema"))
    schema_version = String(_required_attribute(handle, "schema_version"))
    # Field gates follow the complete legacy layout; the digest retains the wire label.
    contract_version = schema_version == "1.0" ? "6.3" : schema_version
    contract_version in (
        "3.0",
        "4.0",
        "5.0",
        "5.1",
        "5.2",
        "5.3",
        "5.4",
        "5.5",
        "5.6",
        "5.7",
        "5.8",
        "5.9",
        "5.10",
        "6.0",
        "6.1",
        "6.2",
        "6.3",
    ) || throw(
        ArgumentError("unsupported operator-bundle schema version; re-symmetrize original inputs"),
    )
    legacy_schema_diagnostic = startswith(contract_version, "5.")
    writer_version = String(_required_attribute(handle, "wanniernlqg_version"))
    writer_version in
    ("1.0.0", "1.0.1", "2.0.0", "2.0.0-wcc.20260804", "2.1.0", "2.3.0", "2.4.0") ||
        throw(ArgumentError("operator bundle was not written by a compatible WannierNLQG build"))
    isempty(String(_required_attribute(handle, "generated_at_utc"))) &&
        throw(ArgumentError("operator bundle generated_at_utc is empty"))
    String(_required_attribute(handle, "symmetrization_status")) in ("applied", "not_provided") ||
        throw(ArgumentError("invalid symmetrization_status"))
    required_groups = String[
        "model",
        "payload",
        "index",
        "operators",
        "symmetry",
        "diagnostics",
        "provenance",
        "compatibility",
    ]
    contract_version in (
        "5.0",
        "5.1",
        "5.2",
        "5.3",
        "5.4",
        "5.5",
        "5.6",
        "5.7",
        "5.8",
        "5.9",
        "5.10",
        "6.0",
        "6.1",
        "6.2",
        "6.3",
    ) && push!(required_groups, "geometry")
    contract_version in
    ("5.3", "5.4", "5.5", "5.6", "5.7", "5.8", "5.9", "5.10", "6.0", "6.1", "6.2", "6.3") &&
        push!(required_groups, "tb_symmetry_qualification")
    contract_version in ("6.1", "6.2", "6.3") && push!(required_groups, "qualification")
    for group in required_groups
        haskey(handle, group) || throw(ArgumentError("operator bundle is missing group $(group)"))
    end
    payload_dataset = handle["payload/complex128"]
    ndims(payload_dataset) == 1 || throw(ArgumentError("operator payload must be one-dimensional"))
    HDF5.iscontiguous(payload_dataset) ||
        throw(ArgumentError("operator payload must be contiguous and uncompressed"))
    HDF5.ismmappable(payload_dataset) ||
        throw(ArgumentError("operator payload dtype is not native-compatible ComplexF64"))
    String(_required_attribute(handle, "payload_element_format")) == PAYLOAD_ELEMENT_FORMAT ||
        throw(ArgumentError("operator payload element format is unsupported"))
    String(_required_attribute(handle, "payload_byte_order")) == "little-endian" ||
        throw(ArgumentError("operator payload byte order is unsupported"))

    profile = Symbol(String(_required_attribute(handle, "operator_profile")))
    inventory = _split_inventory(_required_attribute(handle, "operator_inventory"))
    inventory = validate_operator_profile(profile, inventory)
    if contract_version == "3.0" && profile in (:derivative, :full)
        throw(
            ArgumentError(
                "Packed HDF5 v3 derivative-family convention semantics are ambiguous; " *
                "rebuild the operator bundle with schema 5.0.",
            ),
        )
    end
    Int(_required_attribute(handle, "operator_count")) == length(inventory) ||
        throw(ArgumentError("operator_count disagrees with operator inventory"))
    String(_required_attribute(handle, "available_matrix_capabilities")) ==
    join(available_matrix_capabilities(inventory), ",") ||
        throw(ArgumentError("available matrix capabilities disagree with operator inventory"))
    expected_names = Set(real_space_operator_name.(inventory))
    Set(String.(collect(keys(handle["operators"])))) == expected_names ||
        throw(ArgumentError("operator groups disagree with operator inventory"))

    num_wannier = Int(read(handle["model/num_orbitals"]))
    lattice = Matrix{Float64}(read(handle["model/lattice"]))
    r_vectors = Matrix{Int}(read(handle["model/r_vectors"]))
    degeneracies = Vector{Int}(read(handle["model/degeneracies"]))
    num_wannier > 0 || throw(ArgumentError("num_orbitals must be positive"))
    size(lattice) == (3, 3) || throw(ArgumentError("invalid bundle lattice"))
    size(r_vectors, 1) == 3 || throw(ArgumentError("invalid bundle R vectors"))
    length(degeneracies) == size(r_vectors, 2) ||
        throw(ArgumentError("bundle degeneracies do not match R vectors"))
    all(>(0), degeneracies) || throw(ArgumentError("bundle degeneracies must be positive"))
    centers = nothing
    centers_fractional = nothing
    if contract_version in (
        "4.0",
        "5.0",
        "5.1",
        "5.2",
        "5.3",
        "5.4",
        "5.5",
        "5.6",
        "5.7",
        "5.8",
        "5.9",
        "5.10",
        "6.0",
        "6.1",
        "6.2",
        "6.3",
    )
        String(_required_attribute(handle, "storage_wannier_center_convention")) ==
        "Convention_II" || throw(ArgumentError("bundle storage convention must be Convention_II"))
        centers = Matrix{Float64}(read(handle["model/wannier_centers_cartesian"]))
        centers_fractional = Matrix{Float64}(read(handle["model/wannier_centers_fractional"]))
        size(centers) == (num_wannier, 3) ||
            throw(ArgumentError("invalid bundle Cartesian Wannier-center shape"))
        size(centers_fractional) == (num_wannier, 3) ||
            throw(ArgumentError("invalid bundle fractional Wannier-center shape"))
        all(isfinite, centers) && all(isfinite, centers_fractional) ||
            throw(ArgumentError("bundle Wannier centers contain non-finite values"))
        center_digest = bytes2hex(SHA.sha256(reinterpret(UInt8, vec(centers))))
        center_digest == String(_required_attribute(handle, "wannier_center_cartesian_sha256")) ||
            throw(ArgumentError("bundle Wannier-center SHA-256 mismatch"))
    end
    geometry =
        if contract_version in (
            "5.0",
            "5.1",
            "5.2",
            "5.3",
            "5.4",
            "5.5",
            "5.6",
            "5.7",
            "5.8",
            "5.9",
            "5.10",
            "6.0",
            "6.1",
            "6.2",
            "6.3",
        )
            _read_v5_geometry(
                handle,
                num_wannier,
                lattice,
                something(centers),
                something(centers_fractional),
                degeneracies,
            )
        else
            (
                raw_centers_cartesian = nothing,
                raw_centers_fractional = nothing,
                wannier_center_policy = :legacy,
                real_space_replica_policy = :legacy,
                production_eligible = true,
                minimum_distance_materialized = false,
                mp_grid = nothing,
                wigner_seitz_tolerance = nothing,
                wigner_seitz_search_size = nothing,
                replica_mapping_sha256 = nothing,
                geometry_content_sha256 = nothing,
            )
        end

    kind_ids = Vector{UInt8}(read(handle["index/operator_kind_id"]))
    ranks = Vector{UInt8}(read(handle["index/component_rank"]))
    component_indices = Matrix{Int8}(read(handle["index/component_indices"]))
    offsets = Vector{UInt64}(read(handle["index/offset_elements"]))
    lengths = Vector{UInt64}(read(handle["index/length_elements"]))
    logical_shapes = Matrix{UInt64}(read(handle["index/logical_shape"]))
    hashes = String.(read(handle["index/component_sha256"]))
    entry_count = length(kind_ids)
    all(length(values) == entry_count for values in (ranks, offsets, lengths, hashes)) ||
        throw(ArgumentError("operator index columns have different lengths"))
    size(component_indices) == (2, entry_count) ||
        throw(ArgumentError("component_indices must have size (2, entry_count)"))
    size(logical_shapes) == (3, entry_count) ||
        throw(ArgumentError("logical_shape must have size (3, entry_count)"))

    entries = OperatorBundleIndexEntry[]
    cursor = UInt64(0)
    expected_length = UInt64(num_wannier * num_wannier * size(r_vectors, 2))
    for index in 1:entry_count
        kind = try
            RealSpaceOperatorKind(kind_ids[index])
        catch
            throw(ArgumentError("operator index contains an unknown kind id"))
        end
        kind in inventory || throw(ArgumentError("operator index kind is absent from inventory"))
        offsets[index] == cursor ||
            throw(ArgumentError("operator payload contains a gap, overlap, or reordered offset"))
        lengths[index] == expected_length ||
            throw(ArgumentError("operator component length disagrees with model shape"))
        Tuple(Int.(logical_shapes[:, index])) == (num_wannier, num_wannier, size(r_vectors, 2)) ||
            throw(ArgumentError("operator logical shape disagrees with model"))
        length(hashes[index]) == 64 || throw(ArgumentError("invalid component SHA-256"))
        push!(
            entries,
            OperatorBundleIndexEntry(
                kind,
                ranks[index],
                (component_indices[1, index], component_indices[2, index]),
                offsets[index],
                lengths[index],
                (num_wannier, num_wannier, size(r_vectors, 2)),
                hashes[index],
            ),
        )
        cursor += lengths[index]
    end
    cursor == UInt64(length(payload_dataset)) ||
        throw(ArgumentError("operator payload has unindexed trailing elements"))

    for kind in inventory
        group = handle["operators/$(real_space_operator_name(kind))"]
        String(_required_attribute(group, "canonical_name")) == real_space_operator_name(kind) ||
            throw(ArgumentError("operator canonical name mismatch"))
        UInt8(_required_attribute(group, "operator_kind_id")) == UInt8(kind) ||
            throw(ArgumentError("operator kind id mismatch"))
        if contract_version in (
            "4.0",
            "5.0",
            "5.1",
            "5.2",
            "5.3",
            "5.4",
            "5.5",
            "5.6",
            "5.7",
            "5.8",
            "5.9",
            "5.10",
            "6.0",
            "6.1",
            "6.2",
            "6.3",
        )
            String(_required_attribute(group, "wannier_center_convention")) == "Convention_II" ||
                throw(ArgumentError("operator convention metadata must be Convention_II"))
        end
        rank = Int(_required_attribute(group, "cartesian_rank"))
        selected = [entry for entry in entries if entry.kind == kind]
        getfield.(selected, :component_indices) == _component_tuples(rank) ||
            throw(ArgumentError("operator components are incomplete or out of canonical order"))
        all(entry -> Int(entry.component_rank) == rank, selected) ||
            throw(ArgumentError("operator component rank mismatch"))
        UInt64.(read(group["index_entries"])) ==
        UInt64[index - 1 for (index, entry) in pairs(entries) if entry.kind == kind] ||
            throw(ArgumentError("operator group index references disagree with index table"))
    end

    paired_text = String(_required_attribute(handle, "paired_tb_sha256"))
    paired_digest = isempty(paired_text) ? nothing : paired_text
    paired_digest === nothing ||
        length(paired_digest) == 64 ||
        throw(ArgumentError("invalid paired TB SHA-256"))
    energy_shift_qualification =
        contract_version in
        ("5.4", "5.5", "5.6", "5.7", "5.8", "5.9", "5.10", "6.0", "6.1", "6.2", "6.3") ?
        String(_required_attribute(handle, "energy_shift_qualification")) :
        "legacy_energy_shift_hard_gate"
    maximum_energy_shift_audit_reference_ev =
        contract_version in
        ("5.4", "5.5", "5.6", "5.7", "5.8", "5.9", "5.10", "6.0", "6.1", "6.2", "6.3") ?
        String(_required_attribute(handle, "maximum_energy_shift_audit_reference_ev")) :
        "NOT_APPLICABLE"
    rms_energy_shift_audit_reference_ev =
        contract_version in
        ("5.4", "5.5", "5.6", "5.7", "5.8", "5.9", "5.10", "6.0", "6.1", "6.2", "6.3") ?
        String(_required_attribute(handle, "rms_energy_shift_audit_reference_ev")) :
        "NOT_APPLICABLE"
    target_energy_shift_audit_status =
        contract_version in
        ("5.4", "5.5", "5.6", "5.7", "5.8", "5.9", "5.10", "6.0", "6.1", "6.2", "6.3") ?
        String(_required_attribute(handle, "target_energy_shift_audit_status")) : "NOT_APPLICABLE"
    symmetrized_parent_energy_shift_audit_status =
        contract_version in
        ("5.4", "5.5", "5.6", "5.7", "5.8", "5.9", "5.10", "6.0", "6.1", "6.2", "6.3") ?
        String(_required_attribute(handle, "symmetrized_parent_energy_shift_audit_status")) :
        "NOT_APPLICABLE"
    residual_gate_phase =
        contract_version in
        ("5.5", "5.6", "5.7", "5.8", "5.9", "5.10", "6.0", "6.1", "6.2", "6.3") ?
        String(_required_attribute(handle, "residual_gate_phase")) : "legacy_pre_symmetrization"
    raw_preflight_diagnostic_status =
        contract_version in
        ("5.5", "5.6", "5.7", "5.8", "5.9", "5.10", "6.0", "6.1", "6.2", "6.3") ?
        String(_required_attribute(handle, "raw_preflight_diagnostic_status")) : "NOT_APPLICABLE"
    native_difference_qualification =
        contract_version in ("5.6", "5.7", "5.8", "5.9", "5.10", "6.0", "6.1", "6.2", "6.3") ?
        String(_required_attribute(handle, "native_difference_qualification")) : "legacy_hard_gate"
    native_difference_audit_status =
        contract_version in ("5.6", "5.7", "5.8", "5.9", "5.10", "6.0", "6.1", "6.2", "6.3") ?
        String(_required_attribute(handle, "native_difference_audit_status")) : "NOT_APPLICABLE"
    qualification_scope =
        contract_version in ("5.7", "5.8", "5.9", "5.10", "6.0", "6.1", "6.2", "6.3") ?
        String(_required_attribute(handle, "qualification_scope")) : "full_parent"
    target_anchor =
        contract_version in ("5.7", "5.8", "5.9", "5.10", "6.0", "6.1", "6.2", "6.3") ?
        String(_required_attribute(handle, "target_anchor")) : "NOT_APPLICABLE"
    target_complement_completion =
        contract_version in ("5.7", "5.8", "5.9", "5.10", "6.0", "6.1", "6.2", "6.3") ?
        String(_required_attribute(handle, "target_complement_completion")) : "NOT_APPLICABLE"
    target_complement_max_element_ev =
        contract_version in ("5.7", "5.8", "5.9", "5.10", "6.0", "6.1", "6.2", "6.3") ?
        String(_required_attribute(handle, "target_complement_max_element_ev")) : "NOT_APPLICABLE"
    auxiliary_parent_qualification =
        contract_version in ("5.7", "5.8", "5.9", "5.10", "6.0", "6.1", "6.2", "6.3") ?
        String(_required_attribute(handle, "auxiliary_parent_qualification")) : "legacy_hard_gate"
    symmetrized_target_subspace_status =
        contract_version in ("5.7", "5.8", "5.9", "5.10", "6.0", "6.1", "6.2", "6.3") ?
        String(_required_attribute(handle, "symmetrized_target_subspace_status")) : "NOT_APPLICABLE"
    auxiliary_parent_audit_status =
        contract_version in ("5.7", "5.8", "5.9", "5.10", "6.0", "6.1", "6.2", "6.3") ?
        String(_required_attribute(handle, "auxiliary_parent_audit_status")) : "NOT_APPLICABLE"
    target_scope_production_eligible =
        contract_version in ("5.7", "5.8", "5.9", "5.10", "6.0", "6.1", "6.2", "6.3") ?
        Bool(_required_attribute(handle, "target_scope_production_eligible")) : false
    parent_audit_policy =
        contract_version in ("5.9", "5.10", "6.0", "6.1", "6.2", "6.3") ?
        String(_required_attribute(handle, "parent_audit_policy")) : "legacy_hard_gate"
    target_authority =
        contract_version in ("5.9", "5.10", "6.0", "6.1", "6.2", "6.3") ?
        String(_required_attribute(handle, "target_authority")) : "NOT_APPLICABLE"
    outer_mask_sha256 =
        contract_version in ("5.9", "5.10", "6.0", "6.1", "6.2", "6.3") ?
        String(_required_attribute(handle, "outer_mask_sha256")) : "NOT_RECORDED"
    frozen_mask_sha256 =
        contract_version in ("5.9", "5.10", "6.0", "6.1", "6.2", "6.3") ?
        String(_required_attribute(handle, "frozen_mask_sha256")) : "NOT_RECORDED"
    target_subspace_contract_sha256 =
        contract_version in ("5.9", "5.10", "6.0", "6.1", "6.2", "6.3") ?
        String(_required_attribute(handle, "target_subspace_contract_sha256")) : "NOT_RECORDED"
    target_leakage_semantics =
        contract_version in ("5.10", "6.0", "6.1", "6.2", "6.3") ?
        String(_required_attribute(handle, "target_leakage_semantics")) :
        "LEGACY_AMPLITUDE_LEAKAGE_CONTRACT"
    target_leakage_formula_sha256 =
        contract_version in ("5.10", "6.0", "6.1", "6.2", "6.3") ?
        String(_required_attribute(handle, "target_leakage_formula_sha256")) : "NOT_RECORDED"
    target_leakage_threshold = if contract_version in ("5.10", "6.0", "6.1", "6.2", "6.3")
        Bool(_required_attribute(handle, "target_leakage_threshold_present")) ?
        Float64(_required_attribute(handle, "target_leakage_threshold")) : nothing
    else
        nothing
    end
    qualification_scope == "target_subspace" &&
        contract_version == "5.9" &&
        throw(
            ArgumentError(
                "UNSUPPORTED_LEGACY_TARGET_LEAKAGE_SEMANTICS: schema-5.9 target bundle uses amplitude leakage gates",
            ),
        )
    derivative_overlap_source =
        contract_version in ("5.8", "5.9", "5.10", "6.0", "6.1", "6.2", "6.3") ?
        String(_required_attribute(handle, "derivative_overlap_source")) : "legacy_unspecified"
    derivative_overlap_completeness =
        contract_version in ("5.8", "5.9", "5.10", "6.0", "6.1", "6.2", "6.3") ?
        String(_required_attribute(handle, "derivative_overlap_completeness")) :
        "legacy_unspecified"
    derivative_overlap_source_sha256_text =
        contract_version in ("5.8", "5.9", "5.10", "6.0", "6.1", "6.2", "6.3") ?
        String(_required_attribute(handle, "derivative_overlap_source_sha256")) : "not_provided"
    derivative_overlap_source_sha256 =
        derivative_overlap_source_sha256_text == "not_provided" ? nothing :
        derivative_overlap_source_sha256_text
    derivative_overlap_algorithm_version =
        contract_version in ("5.8", "5.9", "5.10", "6.0", "6.1", "6.2", "6.3") ?
        String(_required_attribute(handle, "derivative_overlap_algorithm_version")) :
        "legacy_unspecified"
    derivative_overlap_completeness in
    ("legacy_unspecified", "not_applicable", "finite_window_internal", "full_hilbert_space") ||
        throw(ArgumentError("invalid derivative-overlap completeness metadata"))
    derivative_overlap_source_sha256 === nothing ||
        length(something(derivative_overlap_source_sha256)) == 64 ||
        throw(ArgumentError("invalid derivative-overlap source SHA-256"))
    has_spin_family = REAL_SPACE_SPIN in inventory
    operator_qualification = Dict{String, Any}()
    operator_qualification_sha256 = "LEGACY_NOT_RECORDED"
    spin_family_qualification = has_spin_family ? "LEGACY_NOT_RECORDED" : "NOT_APPLICABLE"
    spin_family_qualification_reason =
        has_spin_family ? "SCHEMA_6_0_SPIN_QUALIFICATION_NOT_RECORDED" :
        "PROFILE_HAS_NO_SPIN_FAMILY"
    spin_family_production_eligible = false
    finite_band_galerkin_qualification = profile == :full ? "LEGACY_NOT_RECORDED" : "NOT_APPLICABLE"
    finite_band_galerkin_qualification_reason =
        profile == :full ? "LEGACY_GALERKIN_RISK_CONTRACT_NOT_RECORDED" :
        "PROFILE_HAS_NO_COMPLETE_FINITE_BAND_OPERATOR_FAMILY"
    finite_band_galerkin_production_eligible = false
    if contract_version in ("6.1", "6.2", "6.3")
        qualification_group = handle["qualification"]
        operator_qualification =
            _read_metadata_tree(qualification_group; skip_payload_sha256 = true)
        if contract_version == "6.3"
            operator_qualification = Dict{String, Any}(
                String(key) => value for (key, value) in pairs(
                    _validated_operator_qualification(operator_qualification, profile, inventory),
                )
            )
        end
        operator_qualification_sha256 =
            String(_required_attribute(handle, "operator_qualification_sha256"))
        operator_qualification_sha256 ==
        String(_required_attribute(qualification_group, "payload_sha256")) ||
            throw(ArgumentError("operator-qualification root and group digests disagree"))
        operator_qualification_sha256 == _operator_qualification_digest(operator_qualification) ||
            throw(ArgumentError("operator-qualification payload SHA-256 mismatch"))
        spin = _dictionary_entry(_dictionary_entry(operator_qualification, "families"), "spin")
        spin_family_qualification = String(_dictionary_entry(spin, "overall"))
        spin_family_qualification_reason = String(_dictionary_entry(spin, "reason"))
        spin_family_production_eligible = Bool(_dictionary_entry(spin, "production_eligible"))
        String(_required_attribute(handle, "spin_family_qualification")) ==
        spin_family_qualification ||
            throw(ArgumentError("spin-family root qualification disagrees with payload"))
        String(_required_attribute(handle, "spin_family_qualification_reason")) ==
        spin_family_qualification_reason ||
            throw(ArgumentError("spin-family root reason disagrees with payload"))
        Bool(_required_attribute(handle, "spin_family_production_eligible")) ==
        spin_family_production_eligible ||
            throw(ArgumentError("spin-family root eligibility disagrees with payload"))
        if contract_version == "6.3"
            finite_band = _dictionary_entry(
                _dictionary_entry(operator_qualification, "families"),
                "finite_band_galerkin",
            )
            finite_band_galerkin_qualification = String(_dictionary_entry(finite_band, "overall"))
            finite_band_galerkin_qualification_reason =
                String(_dictionary_entry(finite_band, "reason"))
            finite_band_galerkin_production_eligible =
                Bool(_dictionary_entry(finite_band, "production_eligible"))
            String(_required_attribute(handle, "finite_band_galerkin_qualification")) ==
            finite_band_galerkin_qualification || throw(
                ArgumentError("finite-band Galerkin root qualification disagrees with payload"),
            )
            String(_required_attribute(handle, "finite_band_galerkin_qualification_reason")) ==
            finite_band_galerkin_qualification_reason ||
                throw(ArgumentError("finite-band Galerkin root reason disagrees with payload"))
            Bool(_required_attribute(handle, "finite_band_galerkin_production_eligible")) ==
            finite_band_galerkin_production_eligible ||
                throw(ArgumentError("finite-band Galerkin root eligibility disagrees with payload"))
        end
    end
    legacy_nontrivial_frame = false
    if contract_version == "6.1" && has_spin_family
        records = _dictionary_entry(operator_qualification, "operators")
        for kind in (
            REAL_SPACE_SPIN,
            REAL_SPACE_SPIN_TIMES_HAMILTONIAN,
            REAL_SPACE_SPIN_TIMES_POSITION,
            REAL_SPACE_SPIN_TIMES_HAMILTONIAN_POSITION,
        )
            kind in inventory || continue
            record = _dictionary_entry(records, real_space_operator_name(kind))
            source_gauge = String(_dictionary_entry(record, "source_band_gauge"))
            target_gauge = String(_dictionary_entry(record, "target_band_gauge"))
            artifact = String(_dictionary_entry(record, "gauge_artifact_sha256"))
            legacy_nontrivial_frame |= source_gauge != target_gauge || artifact != "NOT_APPLICABLE"
        end
        if legacy_nontrivial_frame
            spin_family_qualification = "LEGACY_NOT_RECORDED"
            spin_family_qualification_reason = "LEGACY_BAND_FRAME_CONTRACT_NOT_RECORDED"
            spin_family_production_eligible = false
        end
    end
    current_frame_schema = contract_version in ("6.2", "6.3")
    band_frame_contract_status =
        current_frame_schema ? String(_required_attribute(handle, "band_frame_contract_status")) :
        legacy_nontrivial_frame ? "LEGACY_BAND_FRAME_CONTRACT_NOT_RECORDED" : "NOT_APPLICABLE"
    band_frame_transform_sha256 =
        current_frame_schema ? String(_required_attribute(handle, "band_frame_transform_sha256")) :
        legacy_nontrivial_frame ? "LEGACY_BAND_FRAME_CONTRACT_NOT_RECORDED" : "NOT_APPLICABLE"
    band_frame_contract_sha256 =
        current_frame_schema ? String(_required_attribute(handle, "band_frame_contract_sha256")) :
        legacy_nontrivial_frame ? "LEGACY_BAND_FRAME_CONTRACT_NOT_RECORDED" : "NOT_APPLICABLE"
    band_frame_metric_kind =
        current_frame_schema ? String(_required_attribute(handle, "band_frame_metric_kind")) :
        legacy_nontrivial_frame ? "LEGACY_BAND_FRAME_CONTRACT_NOT_RECORDED" : "NOT_APPLICABLE"
    function frame_optional_float(name)
        current_frame_schema || return nothing
        value = Float64(_required_attribute(handle, name))
        return isnan(value) ? nothing : value
    end
    band_frame_physical_isometry_maximum =
        frame_optional_float("band_frame_physical_isometry_maximum")
    band_frame_physical_isometry_tolerance =
        frame_optional_float("band_frame_physical_isometry_tolerance")
    band_frame_replay_maximum = frame_optional_float("band_frame_replay_maximum")
    band_frame_replay_tolerance = frame_optional_float("band_frame_replay_tolerance")
    band_frame_euclidean_nonunitarity_maximum =
        frame_optional_float("band_frame_euclidean_nonunitarity_maximum")
    band_frame_minimum_singular_value = frame_optional_float("band_frame_minimum_singular_value")
    band_frame_maximum_condition_number =
        frame_optional_float("band_frame_maximum_condition_number")
    if current_frame_schema && band_frame_contract_status == "PASS"
        occursin(r"^[0-9a-f]{64}$", band_frame_transform_sha256) ||
            throw(ArgumentError("invalid root band-frame transform SHA-256"))
        occursin(r"^[0-9a-f]{64}$", band_frame_contract_sha256) ||
            throw(ArgumentError("invalid root band-frame contract SHA-256"))
        something(band_frame_physical_isometry_maximum) <=
        something(band_frame_physical_isometry_tolerance) ||
            throw(ArgumentError("BAND_FRAME_PHYSICAL_ISOMETRY_FAILED"))
        something(band_frame_replay_maximum) <= something(band_frame_replay_tolerance) ||
            throw(ArgumentError("BAND_FRAME_REPLAY_FAILED"))
    end
    scientific_digest = String(_required_attribute(handle, "scientific_content_sha256"))
    length(scientific_digest) == 64 || throw(ArgumentError("invalid scientific-content SHA-256"))
    persisted_authority =
        contract_version in
        ("5.3", "5.4", "5.5", "5.6", "5.7", "5.8", "5.9", "5.10", "6.0", "6.1", "6.2", "6.3") ?
        String(_required_attribute(handle, "authoritative_hamiltonian")) : "native_dft"
    persisted_authority =
        WannierNLQG.SymmetryFoundation.validate_authoritative_hamiltonian_key(persisted_authority)
    construction_evidence_sha256 = _read_construction_evidence_digest(handle)
    expected_scientific_digest = _scientific_content_digest(
        profile,
        inventory,
        lattice,
        r_vectors,
        degeneracies,
        hashes,
        paired_digest,
        schema_version,
        geometry.geometry_content_sha256,
        persisted_authority,
        contract_version in
        ("5.3", "5.4", "5.5", "5.6", "5.7", "5.8", "5.9", "5.10", "6.0", "6.1", "6.2", "6.3") ?
        String(_required_attribute(handle, "authoritative_hamiltonian_sha256")) :
        "LEGACY_NATIVE_DFT",
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
        parent_audit_policy,
        outer_mask_sha256,
        frozen_mask_sha256,
        target_subspace_contract_sha256,
        target_leakage_semantics,
        target_leakage_formula_sha256,
        target_leakage_threshold,
        derivative_overlap_source,
        derivative_overlap_completeness,
        derivative_overlap_source_sha256_text,
        derivative_overlap_algorithm_version,
        target_authority,
        operator_qualification_sha256,
        band_frame_contract_sha256,
        construction_evidence_sha256,
    )
    scientific_digest == expected_scientific_digest ||
        throw(ArgumentError("scientific-content SHA-256 does not match indexed model content"))
    root_attributes = HDF5.attributes(handle)
    optional_string(name) =
        haskey(root_attributes, name) ? String(read(root_attributes[name])) : nothing
    optional_bool(name) =
        haskey(root_attributes, name) ? Bool(read(root_attributes[name])) : nothing
    optional_int(name) = haskey(root_attributes, name) ? Int(read(root_attributes[name])) : nothing
    optional_float(name) =
        haskey(root_attributes, name) ? Float64(read(root_attributes[name])) : nothing
    authoritative_hamiltonian =
        something(optional_string("authoritative_hamiltonian"), "native_dft")
    authoritative_hamiltonian =
        WannierNLQG.SymmetryFoundation.validate_authoritative_hamiltonian_key(
            authoritative_hamiltonian,
        )
    authoritative_hamiltonian_sha256 =
        something(optional_string("authoritative_hamiltonian_sha256"), "LEGACY_NATIVE_DFT")
    authoritative_hamiltonian == "symmetrized_dft_hamiltonian" &&
        contract_version in
        ("5.4", "5.5", "5.6", "5.7", "5.8", "5.9", "5.10", "6.0", "6.1", "6.2", "6.3") &&
        energy_shift_qualification != "audit_only" &&
        throw(
            ArgumentError(
                "HAMILTONIAN_REFERENCE_MISMATCH: schema-5.4 symmetrized bundle requires audit-only energy shifts",
            ),
        )
    authoritative_hamiltonian == "symmetrized_dft_hamiltonian" &&
        contract_version in
        ("5.5", "5.6", "5.7", "5.8", "5.9", "5.10", "6.0", "6.1", "6.2", "6.3") &&
        residual_gate_phase != "post_symmetrization" &&
        throw(
            ArgumentError(
                "HAMILTONIAN_REFERENCE_MISMATCH: schema-5.5 symmetrized bundle requires post-symmetrization residual gates",
            ),
        )
    authoritative_hamiltonian == "symmetrized_dft_hamiltonian" &&
        contract_version in ("5.6", "5.7", "5.8", "5.9", "5.10", "6.0", "6.1", "6.2", "6.3") &&
        native_difference_qualification != "audit_only" &&
        throw(
            ArgumentError(
                "HAMILTONIAN_REFERENCE_MISMATCH: schema-5.6 symmetrized bundle requires audit-only native differences",
            ),
        )
    if qualification_scope == "target_subspace"
        contract_version in ("5.10", "6.0", "6.1", "6.2", "6.3") || throw(
            ArgumentError(
                "TARGET_SUBSPACE_CONTRACT_MISMATCH: target-subspace bundle requires schema 5.10 or 6.x",
            ),
        )
        parent_audit_policy == "audit_only" || throw(
            ArgumentError(
                "TARGET_SUBSPACE_CONTRACT_MISMATCH: target bundle requires audit-only parent policy",
            ),
        )
        target_authority == "outer_window" || throw(
            ArgumentError(
                "TARGET_SUBSPACE_CONTRACT_MISMATCH: target bundle authority must be outer_window",
            ),
        )
        for (name, digest) in (
            ("outer mask", outer_mask_sha256),
            ("frozen mask", frozen_mask_sha256),
            ("target-subspace contract", target_subspace_contract_sha256),
        )
            occursin(r"^[0-9a-f]{64}$", digest) ||
                throw(ArgumentError("TARGET_SUBSPACE_CONTRACT_MISMATCH: $(name) digest is invalid"))
        end
        target_leakage_semantics == WannierNLQG.Wannierization.TB_TARGET_LEAKAGE_WEIGHT_SEMANTICS ||
            throw(
                ArgumentError(
                    "UNSUPPORTED_LEGACY_TARGET_LEAKAGE_SEMANTICS: target bundle does not declare PAW-S leakage weights",
                ),
            )
        target_leakage_formula_sha256 ==
        WannierNLQG.Wannierization.TB_TARGET_LEAKAGE_WEIGHT_FORMULA_SHA256 || throw(
            ArgumentError(
                "TARGET_SUBSPACE_CONTRACT_MISMATCH: target leakage formula SHA-256 is incompatible",
            ),
        )
        target_leakage_threshold !== nothing &&
        isfinite(something(target_leakage_threshold)) &&
        0.0 <=
        something(target_leakage_threshold) <=
        WannierNLQG.Wannierization.TB_TARGET_LEAKAGE_MAXIMUM_THRESHOLD || throw(
            ArgumentError(
                "TARGET_SUBSPACE_CONTRACT_MISMATCH: target leakage threshold must not exceed 5e-6",
            ),
        )
    end
    if authoritative_hamiltonian == "symmetrized_dft_hamiltonian"
        qualification_scope == "target_subspace" ||
            throw(ArgumentError("HAMILTONIAN_REFERENCE_MISMATCH: target bundle scope differs"))
        target_anchor == "completed_symmetrized_target" ||
            throw(ArgumentError("HAMILTONIAN_REFERENCE_MISMATCH: target bundle anchor differs"))
        auxiliary_parent_qualification == "audit_only" || throw(
            ArgumentError(
                "HAMILTONIAN_REFERENCE_MISMATCH: target bundle requires audit-only auxiliary parent",
            ),
        )
    end
    scoped_production_eligible =
        something(optional_bool("scoped_production_eligible"), geometry.production_eligible)
    global_production_eligible = something(optional_bool("global_production_eligible"), false)
    global_production_eligible == false ||
        throw(ArgumentError("operator bundle cannot assert global production eligibility"))
    wannierization_status = optional_string("wannierization_status")
    wannierization_status == "" && (wannierization_status = nothing)
    solver_status = optional_string("solver_status")
    solver_status == "" && (solver_status = nothing)
    solver_convergence = optional_string("solver_convergence")
    solver_convergence == "" && (solver_convergence = nothing)
    initialization_status = optional_string("initialization_status")
    initialization_status == "" && (initialization_status = nothing)
    initializer_algorithm_version = optional_string("initializer_algorithm_version")
    initializer_algorithm_version == "" && (initializer_algorithm_version = nothing)
    numerical_quality = optional_string("numerical_quality")
    numerical_quality == "" && (numerical_quality = nothing)
    tb_export_status = optional_string("tb_export_status")
    tb_export_status == "" && (tb_export_status = nothing)
    physics_qualification = optional_string("physics_qualification")
    physics_qualification == "" && (physics_qualification = nothing)
    tb_usability = optional_string("tb_usability")
    tb_usability == "" && (tb_usability = nothing)
    stopping_reason = optional_string("stopping_reason")
    stopping_reason == "" && (stopping_reason = nothing)
    iterations_completed = optional_int("iterations_completed")
    iterations_completed == -1 && (iterations_completed = nothing)
    last_attempted_iteration = optional_int("last_attempted_iteration")
    last_attempted_iteration == -1 && (last_attempted_iteration = nothing)
    last_accepted_iteration = optional_int("last_accepted_iteration")
    last_accepted_iteration == -1 && (last_accepted_iteration = nothing)
    last_persisted_iteration = optional_int("last_persisted_iteration")
    last_persisted_iteration == -1 && (last_persisted_iteration = nothing)
    convergence_metric = optional_float("convergence_metric")
    convergence_metric !== nothing && isnan(convergence_metric) && (convergence_metric = nothing)
    convergence_tolerance = optional_float("convergence_tolerance")
    convergence_tolerance !== nothing &&
        isnan(convergence_tolerance) &&
        (convergence_tolerance = nothing)
    checkpoint_sha256 = optional_string("checkpoint_sha256")
    checkpoint_sha256 == "" && (checkpoint_sha256 = nothing)
    input_sha256 = optional_string("input_sha256")
    input_sha256 == "" && (input_sha256 = nothing)
    spread_metric = optional_string("spread_metric")
    spread_metric == "" && (spread_metric = nothing)
    amn_sha256 = optional_string("amn_sha256")
    amn_sha256 == "" && (amn_sha256 = nothing)
    projection_basis_sha256 = optional_string("projection_basis_sha256")
    projection_basis_sha256 == "" && (projection_basis_sha256 = nothing)
    finite_difference_stencil_sha256 = optional_string("finite_difference_stencil_sha256")
    finite_difference_stencil_sha256 == "" && (finite_difference_stencil_sha256 = nothing)
    optimizer_strategy = optional_string("optimizer_strategy")
    optimizer_strategy == "" && (optimizer_strategy = nothing)
    projector_residual = optional_float("projector_residual")
    projector_residual !== nothing && isnan(projector_residual) && (projector_residual = nothing)
    z_residual = optional_float("z_residual")
    z_residual !== nothing && isnan(z_residual) && (z_residual = nothing)
    u_residual = optional_float("u_residual")
    u_residual !== nothing && isnan(u_residual) && (u_residual = nothing)
    solver_validation_ready = optional_bool("solver_validation_ready")
    isometry_before_export = optional_float("isometry_before_export")
    isometry_after_export = optional_float("isometry_after_export")
    polar_repaired_for_export = optional_bool("polar_repaired_for_export")
    frozen_residual = optional_float("frozen_residual")
    hamiltonian_hermiticity_residual = optional_float("hamiltonian_hermiticity_residual")
    position_hermiticity_residual = optional_float("position_hermiticity_residual")
    roundtrip_tolerance = optional_float("roundtrip_tolerance")
    isometry_before_export !== nothing &&
        isnan(isometry_before_export) &&
        (isometry_before_export = nothing)
    isometry_after_export !== nothing &&
        isnan(isometry_after_export) &&
        (isometry_after_export = nothing)
    frozen_residual !== nothing && isnan(frozen_residual) && (frozen_residual = nothing)
    hamiltonian_hermiticity_residual !== nothing &&
        isnan(hamiltonian_hermiticity_residual) &&
        (hamiltonian_hermiticity_residual = nothing)
    position_hermiticity_residual !== nothing &&
        isnan(position_hermiticity_residual) &&
        (position_hermiticity_residual = nothing)
    roundtrip_tolerance !== nothing && isnan(roundtrip_tolerance) && (roundtrip_tolerance = nothing)
    post_validation_present = haskey(handle, "post_export_validation")
    final_tb_usability = nothing
    final_physics_qualification = nothing
    final_production_eligible = nothing
    post_validation_source_sha256 = nothing
    post_validation_content_sha256 = nothing
    if post_validation_present
        validation = handle["post_export_validation"]
        validation_attributes = HDF5.attributes(validation)
        required_validation(name) =
            haskey(validation_attributes, name) ? read(validation_attributes[name]) :
            throw(ArgumentError("post-export validation is missing $(name)"))
        String(required_validation("schema")) == POST_EXPORT_VALIDATION_SCHEMA ||
            throw(ArgumentError("invalid post-export validation schema"))
        String(required_validation("schema_version")) == POST_EXPORT_VALIDATION_SCHEMA_VERSION ||
            throw(ArgumentError("unsupported post-export validation schema version"))
        post_validation_source_sha256 = String(required_validation("source_bundle_sha256"))
        length(post_validation_source_sha256) == 64 ||
            throw(ArgumentError("invalid post-export source bundle SHA-256"))
        band_digest = String(required_validation("band_validation_summary_sha256"))
        response_digest = String(required_validation("response_validation_summary_sha256"))
        length(band_digest) == 64 ||
            throw(ArgumentError("invalid post-export band summary SHA-256"))
        length(response_digest) == 64 ||
            throw(ArgumentError("invalid post-export response summary SHA-256"))
        final_tb_usability = String(required_validation("final_tb_usability"))
        final_physics_qualification = String(required_validation("final_physics_qualification"))
        final_production_eligible = Bool(required_validation("final_production_eligible"))
        post_validation_content_sha256 = String(required_validation("validation_content_sha256"))
        validation_values = Dict(
            "source_bundle_sha256" => post_validation_source_sha256,
            "band_validation_summary_sha256" => band_digest,
            "response_validation_summary_sha256" => response_digest,
            "final_tb_usability" => final_tb_usability,
            "final_physics_qualification" => final_physics_qualification,
            "final_production_eligible" => final_production_eligible,
        )
        post_validation_content_sha256 == _post_export_validation_digest(validation_values) ||
            throw(ArgumentError("post-export validation seal mismatch"))
    end
    spin_family_diagnostic = has_spin_family && !spin_family_production_eligible
    finite_band_galerkin_diagnostic = profile == :full && !finite_band_galerkin_production_eligible
    (legacy_schema_diagnostic || spin_family_diagnostic || finite_band_galerkin_diagnostic) &&
        (final_production_eligible = false)
    tb_symmetry_qualification_present = false
    tb_symmetry_qualification_overall = "NOT_RUN"
    tb_symmetry_qualification_reason =
        contract_version in ("5.3", "5.4", "6.3") ? "TB_QUALIFICATION_NOT_PROVIDED" :
        "LEGACY_SCHEMA_FIELD_ABSENT"
    tb_symmetry_qualification_sha256 = nothing
    if haskey(handle, "tb_symmetry_qualification")
        qualification_attributes = HDF5.attributes(handle["tb_symmetry_qualification"])
        if all(
            name -> haskey(qualification_attributes, name),
            ("overall", "reason", "payload_sha256"),
        )
            tb_symmetry_qualification_present = true
            tb_symmetry_qualification_overall = String(read(qualification_attributes["overall"]))
            tb_symmetry_qualification_overall in ("PASS", "FAIL", "INCOMPLETE", "NOT_RUN") ||
                throw(ArgumentError("invalid final TB symmetry qualification status"))
            tb_symmetry_qualification_reason = String(read(qualification_attributes["reason"]))
            tb_symmetry_qualification_sha256 =
                String(read(qualification_attributes["payload_sha256"]))
            length(something(tb_symmetry_qualification_sha256)) == 64 ||
                throw(ArgumentError("invalid final TB symmetry qualification SHA-256"))
        end
    end
    for (label, digest) in (
        ("checkpoint", checkpoint_sha256),
        ("input", input_sha256),
        ("AMN", amn_sha256),
        ("projection basis", projection_basis_sha256),
        ("finite-difference stencil", finite_difference_stencil_sha256),
    )
        digest === nothing ||
            length(digest) == 64 ||
            throw(ArgumentError("invalid $(label) SHA-256 metadata"))
    end
    return OperatorBundleManifest(
        path,
        profile,
        inventory,
        num_wannier,
        lattice,
        r_vectors,
        degeneracies,
        entries,
        Int(cursor),
        paired_digest,
        scientific_digest,
        schema_version,
        centers,
        centers_fractional,
        geometry.raw_centers_cartesian,
        geometry.raw_centers_fractional,
        geometry.wannier_center_policy,
        geometry.real_space_replica_policy,
        legacy_schema_diagnostic || spin_family_diagnostic || finite_band_galerkin_diagnostic ?
        false : geometry.production_eligible,
        geometry.minimum_distance_materialized,
        geometry.mp_grid,
        geometry.wigner_seitz_tolerance,
        geometry.wigner_seitz_search_size,
        geometry.replica_mapping_sha256,
        geometry.geometry_content_sha256,
        wannierization_status,
        solver_status,
        solver_convergence,
        initialization_status,
        initializer_algorithm_version,
        numerical_quality,
        tb_export_status,
        optional_bool("converged"),
        legacy_schema_diagnostic ||
        spin_family_diagnostic ||
        finite_band_galerkin_diagnostic ||
        something(optional_bool("diagnostic_only"), !geometry.production_eligible),
        physics_qualification,
        tb_usability,
        stopping_reason,
        iterations_completed,
        last_attempted_iteration,
        last_accepted_iteration,
        last_persisted_iteration,
        convergence_metric,
        convergence_tolerance,
        checkpoint_sha256,
        input_sha256,
        spread_metric,
        amn_sha256,
        projection_basis_sha256,
        finite_difference_stencil_sha256,
        optimizer_strategy,
        projector_residual,
        z_residual,
        u_residual,
        solver_validation_ready,
        isometry_before_export,
        isometry_after_export,
        polar_repaired_for_export,
        frozen_residual,
        hamiltonian_hermiticity_residual,
        position_hermiticity_residual,
        roundtrip_tolerance,
        post_validation_present,
        final_tb_usability,
        final_physics_qualification,
        final_production_eligible,
        post_validation_source_sha256,
        post_validation_content_sha256,
        tb_symmetry_qualification_present,
        tb_symmetry_qualification_overall,
        tb_symmetry_qualification_reason,
        tb_symmetry_qualification_sha256,
        authoritative_hamiltonian,
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
        legacy_schema_diagnostic || spin_family_diagnostic || finite_band_galerkin_diagnostic ?
        false : scoped_production_eligible,
        global_production_eligible,
        parent_audit_policy,
        target_authority,
        outer_mask_sha256,
        frozen_mask_sha256,
        target_subspace_contract_sha256,
        target_leakage_semantics,
        target_leakage_formula_sha256,
        target_leakage_threshold,
        derivative_overlap_source,
        derivative_overlap_completeness,
        derivative_overlap_source_sha256,
        derivative_overlap_algorithm_version,
        operator_qualification,
        operator_qualification_sha256,
        spin_family_qualification,
        spin_family_qualification_reason,
        spin_family_production_eligible,
        finite_band_galerkin_qualification,
        finite_band_galerkin_qualification_reason,
        finite_band_galerkin_production_eligible,
        band_frame_contract_status,
        band_frame_transform_sha256,
        band_frame_contract_sha256,
        band_frame_metric_kind,
        band_frame_physical_isometry_maximum,
        band_frame_physical_isometry_tolerance,
        band_frame_replay_maximum,
        band_frame_replay_tolerance,
        band_frame_euclidean_nonunitarity_maximum,
        band_frame_minimum_singular_value,
        band_frame_maximum_condition_number,
    )
end

# Validate the index and metadata seals without reading or hashing the full numerical payload.
function read_real_space_operator_bundle_manifest(filename::AbstractString)
    path = abspath(filename)
    isfile(path) || throw(ArgumentError("operator bundle does not exist: $(path)"))
    HOST_IS_LITTLE_ENDIAN ||
        throw(ArgumentError("Packed HDF5 bundle reader requires a little-endian host"))
    HDF5.enable_complex_support()
    return h5open(path, "r") do handle
        _manifest_from_handle(path, handle)
    end
end

# Return the validated manifest and full payload, using mmap when the dataset layout permits it.
function read_operator_bundle_payload(filename::AbstractString; prefer_mmap::Bool = true)
    path = abspath(filename)
    manifest = read_real_space_operator_bundle_manifest(path)
    HDF5.enable_complex_support()
    handle = h5open(path, "r")
    try
        dataset = handle["payload/complex128"]
        if prefer_mmap && HDF5.ismmappable(dataset)
            payload = HDF5.readmmap(dataset)
            close(handle)
            return (
                manifest = manifest,
                payload = payload,
                read_mode = :mmap,
                fallback_reason = nothing,
            )
        end
        payload = Vector{ComplexF64}(undef, manifest.payload_length)
        copyto!(payload, read(dataset))
        return (
            manifest = manifest,
            payload = payload,
            read_mode = :buffered,
            fallback_reason = prefer_mmap ? "payload is not mmap compatible" : "mmap disabled",
        )
    catch
        isopen(handle) && close(handle)
        rethrow()
    finally
        isopen(handle) && close(handle)
    end
end

# Normalize component demand while rejecting operator kinds absent from the validated inventory.
function _requested_component_set(requested_components, manifest::OperatorBundleManifest)
    requested = Dict{RealSpaceOperatorKind, Set{NTuple{2, Int8}}}()
    for (kind, components) in pairs(requested_components)
        kind isa RealSpaceOperatorKind ||
            throw(ArgumentError("operator demand keys must use RealSpaceOperatorKind"))
        kind in manifest.inventory || throw(
            ArgumentError(
                "required operator $(real_space_operator_name(kind)) is absent from bundle profile $(manifest.profile)",
            ),
        )
        requested[kind] = Set((Int8(component[1]), Int8(component[2])) for component in components)
    end
    return requested
end

# Hash the exact bytes of a mapped or buffered component without changing its logical values.
function _digest_abstract_component(values)
    return bytes2hex(SHA.sha256(reinterpret(UInt8, vec(values))))
end

# Load only demanded Cartesian components and verify each selected component against its stored hash.
function read_operator_bundle_components(
    filename::AbstractString,
    requested_components::AbstractDict;
    prefer_mmap::Bool = true,
)
    path = abspath(filename)
    manifest = read_real_space_operator_bundle_manifest(path)
    requested = _requested_component_set(requested_components, manifest)
    selected_entries = [
        entry for entry in manifest.entries if
        haskey(requested, entry.kind) && entry.component_indices in requested[entry.kind]
    ]
    for (kind, components) in requested
        found = Set(entry.component_indices for entry in selected_entries if entry.kind == kind)
        found == components || throw(
            ArgumentError(
                "required components for $(real_space_operator_name(kind)) are absent from the bundle",
            ),
        )
    end
    components = Dict{RealSpaceOperatorKind, Dict{NTuple{2, Int8}, AbstractArray{ComplexF64, 3}}}()
    HDF5.enable_complex_support()
    handle = h5open(path, "r")
    payload_owner = nothing
    read_mode = :buffered
    fallback_reason = prefer_mmap ? "payload is not mmap compatible" : "mmap disabled"
    try
        dataset = handle["payload/complex128"]
        if prefer_mmap && HDF5.ismmappable(dataset)
            payload_owner = HDF5.readmmap(dataset)
            read_mode = :mmap
            fallback_reason = nothing
        end
        for entry in selected_entries
            first = Int(entry.offset_elements) + 1
            last = first + Int(entry.length_elements) - 1
            values = if payload_owner === nothing
                Vector{ComplexF64}(dataset[first:last])
            else
                @view payload_owner[first:last]
            end
            _digest_abstract_component(values) == entry.component_sha256 || throw(
                ArgumentError(
                    "component SHA-256 mismatch for $(real_space_operator_name(entry.kind)) $(entry.component_indices)",
                ),
            )
            all(isfinite, values) || throw(
                ArgumentError(
                    "component contains non-finite values for $(real_space_operator_name(entry.kind)) $(entry.component_indices)",
                ),
            )
            logical = reshape(values, entry.logical_shape)
            kind_components = get!(
                () -> Dict{NTuple{2, Int8}, AbstractArray{ComplexF64, 3}}(),
                components,
                entry.kind,
            )
            kind_components[entry.component_indices] = logical
        end
    finally
        close(handle)
    end
    return (
        manifest = manifest,
        components = components,
        read_mode = read_mode,
        fallback_reason = fallback_reason,
        payload_owner = payload_owner,
    )
end

# Reconstruct the stored Cartesian rank, parity, and rotation rules for one operator.
function _operator_spec_from_handle(handle, kind::RealSpaceOperatorKind)
    group = handle["operators/$(real_space_operator_name(kind))"]
    return RealSpaceOperatorSymmetrySpec(
        kind,
        Int(_required_attribute(group, "cartesian_rank")),
        Int(_required_attribute(group, "inversion_parity")),
        Int(_required_attribute(group, "time_reversal_parity"));
        rotate_cartesian = Bool(_required_attribute(group, "rotate_cartesian")),
    )
end

# Fill one Cartesian slice of a reconstructed rank-zero, rank-one, or rank-two operator array.
function _assign_component!(data, rank::Int, component, values)
    rank == 0 && return (data[:, :, :] .= values)
    rank == 1 && return (data[:, :, Int(component[1]), :] .= values)
    rank == 2 && return (data[:, :, Int(component[1]), Int(component[2]), :] .= values)
    error("unreachable operator rank $(rank)")
end

# Reconstruct every logical operator, checking component hashes by default and rejecting nonfinite data.
function read_real_space_operator_bundle(filename::AbstractString; verify_digests::Bool = true)
    loaded = read_operator_bundle_payload(filename; prefer_mmap = true)
    manifest = loaded.manifest
    payload = loaded.payload
    operators = Dict{RealSpaceOperatorKind, RealSpaceOperator}()
    h5open(manifest.path, "r") do handle
        for kind in manifest.inventory
            spec = _operator_spec_from_handle(handle, kind)
            dimensions = (
                manifest.num_orbitals,
                manifest.num_orbitals,
                ntuple(_ -> 3, spec.cartesian_rank)...,
                size(manifest.r_vectors, 2),
            )
            data = zeros(ComplexF64, dimensions)
            for entry in manifest.entries
                entry.kind == kind || continue
                first = Int(entry.offset_elements) + 1
                last = first + Int(entry.length_elements) - 1
                values = reshape(@view(payload[first:last]), entry.logical_shape)
                verify_digests &&
                    _component_digest(Vector{ComplexF64}(@view(payload[first:last]))) !=
                    entry.component_sha256 &&
                    throw(
                        ArgumentError(
                            "component SHA-256 mismatch for $(real_space_operator_name(kind))",
                        ),
                    )
                _assign_component!(data, spec.cartesian_rank, entry.component_indices, values)
            end
            all(isfinite, data) || throw(
                ArgumentError(
                    "operator $(real_space_operator_name(kind)) contains non-finite values",
                ),
            )
            operators[kind] = RealSpaceOperator(spec, manifest.r_vectors, data)
        end
    end
    return (
        manifest = manifest,
        lattice = manifest.lattice,
        degeneracies = manifest.degeneracies,
        operators = operators,
        read_mode = loaded.read_mode,
        fallback_reason = loaded.fallback_reason,
    )
end

end
