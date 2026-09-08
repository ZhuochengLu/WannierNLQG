const RESPONSE_SYMMETRY_SCHEMA = "wanniernlqg.response-symmetry/1.0"
const RESPONSE_SYMMETRY_ARCHIVED_FULL_SCHEMA = "wanniernlqg.response-symmetry/1.1"
const RESPONSE_SYMMETRY_LEGACY_SCHEMA = "wanniernlqg.response-symmetry/1.0"
const RESPONSE_SYMMETRY_READABLE_SCHEMAS =
    (RESPONSE_SYMMETRY_SCHEMA, RESPONSE_SYMMETRY_ARCHIVED_FULL_SCHEMA)
const RESPONSE_SYMMETRY_JSON3_PKG_ID =
    Base.PkgId(Base.UUID("0f8b85d8-7281-11e9-16c2-39a750bddbf1"), "JSON3")

"""One deduplicated point operation stored in a response-symmetry artifact."""
struct ResponseSymmetryOperation
    rotation_fractional::Matrix{Int}
    translation_fractional::Vector{Float64}
    rotation_cartesian::Matrix{Float64}
    antiunitary::Bool
end

"""Strict, small runtime view of readable response-symmetry artifact schemas."""
struct ResponseSymmetryArtifact
    source_path::String
    artifact_sha256::String
    model_sha256::String
    structure_sha256::String
    operations::Vector{ResponseSymmetryOperation}
    qualification_status::String
    covariance_max_relative_residual::Union{Nothing, Float64}
    covariance_tolerance::Float64
    payload::Dict{String, Any}
    schema::String
    sealed::Bool
    production_eligible::Bool
    diagnostic_only::Bool
    cartesian_rotation_policy::String
end

# Preserve the schema-1.0 in-memory constructor used by legacy tests and tools.
function ResponseSymmetryArtifact(
    source_path,
    artifact_sha256,
    model_sha256,
    structure_sha256,
    operations,
    qualification_status,
    covariance_max_relative_residual,
    covariance_tolerance,
    payload,
)
    return ResponseSymmetryArtifact(
        String(source_path),
        String(artifact_sha256),
        String(model_sha256),
        String(structure_sha256),
        ResponseSymmetryOperation[operations...],
        String(qualification_status),
        covariance_max_relative_residual === nothing ? nothing :
        Float64(covariance_max_relative_residual),
        Float64(covariance_tolerance),
        Dict{String, Any}(payload),
        RESPONSE_SYMMETRY_LEGACY_SCHEMA,
        false,
        false,
        true,
        "legacy_raw_unspecified",
    )
end

# Return one required object field with an artifact-specific error.
function _response_symmetry_required(
    mapping::AbstractDict,
    key::AbstractString,
    context::AbstractString,
)
    haskey(mapping, key) ||
        throw(ArgumentError("response symmetry artifact is missing $(context).$(key)"))
    return mapping[key]
end

# Require a JSON object at a named artifact field.
function _response_symmetry_mapping(value, context::AbstractString)
    value isa AbstractDict ||
        throw(ArgumentError("response symmetry artifact field $(context) must be an object"))
    return value
end

# Require and normalize a string artifact field.
function _response_symmetry_string(value, context::AbstractString; allow_empty::Bool = false)
    value isa AbstractString ||
        throw(ArgumentError("response symmetry artifact field $(context) must be a string"))
    result = String(value)
    !allow_empty &&
        isempty(strip(result)) &&
        throw(ArgumentError("response symmetry artifact field $(context) must not be empty"))
    return result
end

# Require a Boolean artifact field.
function _response_symmetry_bool(value, context::AbstractString)
    value isa Bool ||
        throw(ArgumentError("response symmetry artifact field $(context) must be Boolean"))
    return value
end

# Parse a typed three-by-three matrix from JSON rows.
function _response_symmetry_matrix(value, ::Type{T}, context::AbstractString) where {T}
    value isa AbstractVector && length(value) == 3 ||
        throw(ArgumentError("response symmetry artifact field $(context) must have three rows"))
    matrix = Matrix{T}(undef, 3, 3)
    for row in 1:3
        values = value[row]
        values isa AbstractVector && length(values) == 3 || throw(
            ArgumentError(
                "response symmetry artifact field $(context) row $(row) must have three values",
            ),
        )
        for column in 1:3
            matrix[row, column] = convert(T, values[column])
        end
    end
    return matrix
end

# Parse a typed three-vector from a JSON array.
function _response_symmetry_vector(value, ::Type{T}, context::AbstractString) where {T}
    value isa AbstractVector && length(value) == 3 ||
        throw(ArgumentError("response symmetry artifact field $(context) must have three values"))
    return T[convert(T, item) for item in value]
end

# Validate and normalize one SHA-256 provenance digest.
function _response_symmetry_sha256(value, context::AbstractString)
    digest = lowercase(_response_symmetry_string(value, context))
    occursin(r"^[0-9a-f]{64}$", digest) ||
        throw(ArgumentError("response symmetry artifact field $(context) must be a SHA-256 digest"))
    return digest
end

# Lazily load JSON3 only for an explicitly enabled symmetry run.
function _response_symmetry_json_read(text::AbstractString)
    json3 = Base.require(RESPONSE_SYMMETRY_JSON3_PKG_ID)
    reader = Base.invokelatest(getproperty, json3, :read)
    return Base.invokelatest(reader, text, Dict{String, Any})
end

# Recognize any complete-contract field before validation; partial current payloads
# must fail the current contract rather than falling back to diagnostic legacy parsing.
function _response_symmetry_has_current_fields(payload::AbstractDict)
    for (group, names) in (
        ("provenance", ("cartesian_rotation_policy",)),
        ("qualification", ("production_eligible", "seal", "gates", "external_claims")),
    )
        values = get(payload, group, nothing)
        values isa AbstractDict && any(name -> haskey(values, name), names) && return true
    end
    symmetry = get(payload, "symmetry", nothing)
    if symmetry isa AbstractDict
        checks = get(symmetry, "checks", nothing)
        checks isa AbstractDict &&
            any(
                name -> haskey(checks, name),
                ("space_group", "point_group", "cartesian_rotation", "tolerance_stability"),
            ) &&
            return true
        for key in ("point_group_operations", "space_group_operations")
            operations = get(symmetry, key, nothing)
            operations isa AbstractVector || continue
            any(
                operation ->
                    operation isa AbstractDict && any(
                        name -> haskey(operation, name),
                        (
                            "rotation_cartesian_raw",
                            "rotation_cartesian_effective",
                            "cartesian_rotation_use",
                        ),
                    ),
                operations,
            ) && return true
        end
    end
    return false
end

# Require writer-owned current structural and qualification records even for an
# unsealed public 1.0 artifact; their production truth values are evaluated downstream.
function _response_symmetry_require_current_records(payload::AbstractDict)
    symmetry = _response_symmetry_mapping(
        _response_symmetry_required(payload, "symmetry", "root"),
        "symmetry",
    )
    checks = _response_symmetry_mapping(
        _response_symmetry_required(symmetry, "checks", "symmetry"),
        "symmetry.checks",
    )
    for name in
        ("space_group", "point_group", "atom_mapping", "cartesian_rotation", "tolerance_stability")
        _response_symmetry_mapping(
            _response_symmetry_required(checks, name, "symmetry.checks"),
            "symmetry.checks.$(name)",
        )
    end
    qualification = _response_symmetry_mapping(
        _response_symmetry_required(payload, "qualification", "root"),
        "qualification",
    )
    gates = _response_symmetry_mapping(
        _response_symmetry_required(qualification, "gates", "qualification"),
        "qualification.gates",
    )
    for name in (
        "structure_magnetic_symmetry",
        "wannier90_gauge",
        "hamiltonian_covariance",
        "mmn_covariance",
        "integrand_covariance",
        "full_grid_consistency",
    )
        gate = _response_symmetry_mapping(
            _response_symmetry_required(gates, name, "qualification.gates"),
            "qualification.gates.$(name)",
        )
        _response_symmetry_string(
            _response_symmetry_required(gate, "status", "qualification.gates.$(name)"),
            "qualification.gates.$(name).status",
        )
    end
    return nothing
end

"""
Read and validate the format boundary of a response-symmetry artifact.

Public schema 1.0 and archived complete schema 1.1 preserve raw and effective
Cartesian rotations. Historical schema 1.0 without current-contract fields is
readable only as diagnostic data. Complete artifacts may be production eligible only when
all formal gates pass and the qualification seal is present. JSON3 is loaded
lazily only for this explicit artifact path.
"""
function read_response_symmetry_artifact(filename::AbstractString)
    source_path = abspath(filename)
    isfile(source_path) ||
        throw(ArgumentError("response symmetry artifact does not exist: $(source_path)"))
    payload = _response_symmetry_json_read(read(source_path, String))
    schema =
        _response_symmetry_string(_response_symmetry_required(payload, "schema", "root"), "schema")
    schema in RESPONSE_SYMMETRY_READABLE_SCHEMAS || throw(
        ArgumentError(
            "unsupported response symmetry schema $(repr(schema)); readable schemas are " *
            "$(join(repr.(RESPONSE_SYMMETRY_READABLE_SCHEMAS), ", "))",
        ),
    )
    legacy =
        schema == RESPONSE_SYMMETRY_LEGACY_SCHEMA && !_response_symmetry_has_current_fields(payload)
    !legacy &&
        schema == RESPONSE_SYMMETRY_SCHEMA &&
        _response_symmetry_require_current_records(payload)

    provenance = _response_symmetry_mapping(
        _response_symmetry_required(payload, "provenance", "root"),
        "provenance",
    )
    model = _response_symmetry_mapping(
        _response_symmetry_required(provenance, "model", "provenance"),
        "provenance.model",
    )
    structure = _response_symmetry_mapping(
        _response_symmetry_required(provenance, "structure", "provenance"),
        "provenance.structure",
    )
    model_sha256 = _response_symmetry_sha256(
        _response_symmetry_required(model, "sha256", "provenance.model"),
        "provenance.model.sha256",
    )
    structure_sha256 = _response_symmetry_sha256(
        _response_symmetry_required(structure, "sha256", "provenance.structure"),
        "provenance.structure.sha256",
    )
    cartesian_rotation_policy = if legacy
        "legacy_raw_unspecified"
    else
        _response_symmetry_string(
            _response_symmetry_required(provenance, "cartesian_rotation_policy", "provenance"),
            "provenance.cartesian_rotation_policy",
        )
    end
    !legacy &&
        !(cartesian_rotation_policy in ("group_invariant_metric", "raw_warn", "raw_error")) &&
        throw(ArgumentError("unsupported complete-contract Cartesian rotation policy"))

    symmetry = _response_symmetry_mapping(
        _response_symmetry_required(payload, "symmetry", "root"),
        "symmetry",
    )
    raw_operations = _response_symmetry_required(symmetry, "point_group_operations", "symmetry")
    raw_operations isa AbstractVector && !isempty(raw_operations) || throw(
        ArgumentError(
            "response symmetry artifact point_group_operations must be a non-empty array",
        ),
    )
    operations = ResponseSymmetryOperation[]
    for (index, raw_operation) in enumerate(raw_operations)
        operation = _response_symmetry_mapping(raw_operation, "point_group_operations[$(index)]")
        prefix = "symmetry.point_group_operations[$(index)]"
        rotation_fractional = _response_symmetry_matrix(
            _response_symmetry_required(operation, "rotation_fractional", prefix),
            Int,
            "$(prefix).rotation_fractional",
        )
        translation_fractional = _response_symmetry_vector(
            _response_symmetry_required(operation, "translation_fractional", prefix),
            Float64,
            "$(prefix).translation_fractional",
        )
        rotation_cartesian = _response_symmetry_matrix(
            _response_symmetry_required(operation, "rotation_cartesian", prefix),
            Float64,
            "$(prefix).rotation_cartesian",
        )
        antiunitary = _response_symmetry_bool(
            _response_symmetry_required(operation, "antiunitary", prefix),
            "$(prefix).antiunitary",
        )
        all(isfinite, translation_fractional) ||
            throw(ArgumentError("$(prefix).translation_fractional contains non-finite values"))
        all(isfinite, rotation_cartesian) ||
            throw(ArgumentError("$(prefix).rotation_cartesian contains non-finite values"))
        abs(round(Int, det(rotation_fractional))) == 1 ||
            throw(ArgumentError("$(prefix).rotation_fractional must be unimodular"))

        orthogonality_residual =
            maximum(abs, rotation_cartesian' * rotation_cartesian - Matrix{Float64}(I, 3, 3))
        if legacy
            if orthogonality_residual > 1.0e-8
                @warn "$(prefix).rotation_cartesian orthogonality residual " *
                      "$(orthogonality_residual) exceeds legacy warning threshold 1.0e-8"
            end
        else
            raw_cartesian = _response_symmetry_matrix(
                _response_symmetry_required(operation, "rotation_cartesian_raw", prefix),
                Float64,
                "$(prefix).rotation_cartesian_raw",
            )
            effective_cartesian = _response_symmetry_matrix(
                _response_symmetry_required(operation, "rotation_cartesian_effective", prefix),
                Float64,
                "$(prefix).rotation_cartesian_effective",
            )
            use_policy = _response_symmetry_string(
                _response_symmetry_required(operation, "cartesian_rotation_use", prefix),
                "$(prefix).cartesian_rotation_use",
            )
            use_policy == cartesian_rotation_policy ||
                throw(ArgumentError("$(prefix) Cartesian policy disagrees with provenance"))
            all(isfinite, raw_cartesian) && all(isfinite, effective_cartesian) ||
                throw(ArgumentError("$(prefix) raw/effective Cartesian matrices are non-finite"))
            selected_reference =
                cartesian_rotation_policy == "group_invariant_metric" ? effective_cartesian :
                raw_cartesian
            maximum(abs, rotation_cartesian - selected_reference) <= 1.0e-12 || throw(
                ArgumentError("$(prefix).rotation_cartesian does not match its selected matrix"),
            )
            effective_orthogonality =
                maximum(abs, effective_cartesian' * effective_cartesian - Matrix{Float64}(I, 3, 3))
            effective_orthogonality <= 1.0e-12 || throw(
                ArgumentError(
                    "$(prefix) effective Cartesian orthogonality residual " *
                    "$(effective_orthogonality) exceeds 1.0e-12",
                ),
            )
        end
        push!(
            operations,
            ResponseSymmetryOperation(
                rotation_fractional,
                mod.(translation_fractional, 1.0),
                rotation_cartesian,
                antiunitary,
            ),
        )
    end

    qualification = _response_symmetry_mapping(
        _response_symmetry_required(payload, "qualification", "root"),
        "qualification",
    )
    covariance = _response_symmetry_mapping(
        _response_symmetry_required(qualification, "integrand_covariance", "qualification"),
        "qualification.integrand_covariance",
    )
    qualification_status = uppercase(
        _response_symmetry_string(
            _response_symmetry_required(covariance, "status", "qualification.integrand_covariance"),
            "qualification.integrand_covariance.status",
        ),
    )
    allowed_covariance_statuses =
        legacy ? ("PASS", "FAIL", "NOT_RUN") :
        ("PASS", "FAIL", "NOT_RUN", "NOT_RUN_DOWNSTREAM_BLOCKED")
    qualification_status in allowed_covariance_statuses || throw(
        ArgumentError(
            "integrand covariance status $(qualification_status) is not valid for $(schema)",
        ),
    )
    raw_residual = get(covariance, "maximum_relative_residual", nothing)
    covariance_max_relative_residual = if raw_residual === nothing
        nothing
    else
        value = Float64(raw_residual)
        isfinite(value) && value >= 0.0 || throw(
            ArgumentError("integrand covariance residual must be finite and non-negative"),
        )
        value
    end
    covariance_tolerance = Float64(
        _response_symmetry_required(covariance, "tolerance", "qualification.integrand_covariance"),
    )
    isfinite(covariance_tolerance) && covariance_tolerance > 0.0 ||
        throw(ArgumentError("integrand covariance tolerance must be positive and finite"))

    sealed = false
    production_eligible = false
    if !legacy
        production_eligible = _response_symmetry_bool(
            _response_symmetry_required(qualification, "production_eligible", "qualification"),
            "qualification.production_eligible",
        )
        seal = _response_symmetry_mapping(
            _response_symmetry_required(qualification, "seal", "qualification"),
            "qualification.seal",
        )
        sealed = _response_symmetry_bool(
            _response_symmetry_required(seal, "sealed", "qualification.seal"),
            "qualification.seal.sealed",
        )
        seal_production = _response_symmetry_bool(
            _response_symmetry_required(seal, "production_eligible", "qualification.seal"),
            "qualification.seal.production_eligible",
        )
        seal_production == production_eligible ||
            throw(ArgumentError("qualification and seal production_eligible fields disagree"))
        if production_eligible
            sealed || throw(ArgumentError("production-eligible artifact is not sealed"))
            cartesian_rotation_policy == "group_invariant_metric" ||
                throw(ArgumentError("raw Cartesian policy cannot be production eligible"))
            qualification_status == "PASS" ||
                throw(ArgumentError("production artifact integrand covariance did not PASS"))
            covariance_max_relative_residual !== nothing ||
                throw(ArgumentError("production artifact integrand covariance has no residual"))
            covariance_max_relative_residual <= covariance_tolerance ||
                throw(ArgumentError("production artifact integrand covariance exceeds tolerance"))
            _response_symmetry_sha256(
                _response_symmetry_required(seal, "evidence_sha256", "qualification.seal"),
                "qualification.seal.evidence_sha256",
            )
            gates = _response_symmetry_mapping(
                _response_symmetry_required(qualification, "gates", "qualification"),
                "qualification.gates",
            )
            for gate_name in (
                "structure_magnetic_symmetry",
                "wannier90_gauge",
                "hamiltonian_covariance",
                "mmn_covariance",
                "integrand_covariance",
                "full_grid_consistency",
            )
                gate = _response_symmetry_mapping(
                    _response_symmetry_required(gates, gate_name, "qualification.gates"),
                    "qualification.gates.$(gate_name)",
                )
                status = uppercase(
                    _response_symmetry_string(
                        _response_symmetry_required(
                            gate,
                            "status",
                            "qualification.gates.$(gate_name)",
                        ),
                        "qualification.gates.$(gate_name).status",
                    ),
                )
                status == "PASS" || throw(
                    ArgumentError(
                        "production artifact gate $(gate_name) has status $(status), expected PASS",
                    ),
                )
            end
        end
    end

    artifact_sha256 = bytes2hex(SHA.sha256(read(source_path)))
    return ResponseSymmetryArtifact(
        source_path,
        artifact_sha256,
        model_sha256,
        structure_sha256,
        operations,
        qualification_status,
        covariance_max_relative_residual,
        covariance_tolerance,
        payload,
        schema,
        sealed,
        production_eligible,
        legacy || !production_eligible,
        cartesian_rotation_policy,
    )
end
