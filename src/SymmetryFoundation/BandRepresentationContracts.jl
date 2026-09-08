const _NATIVE_DFT_HAMILTONIAN_KEY = "native_dft"
const _SYMMETRIZED_DFT_HAMILTONIAN_KEY = "symmetrized_dft_hamiltonian"
const _UNSUPPORTED_LEGACY_AUTHORITATIVE_HAMILTONIAN_KEYS =
    Set(["symmetrized_hamiltonian_candidate", "symmetrized_target_subspace_candidate"])

"""Validate and return one persisted Hamiltonian-authority identity."""
function validate_authoritative_hamiltonian_key(key::AbstractString)
    value = String(key)
    value in _UNSUPPORTED_LEGACY_AUTHORITATIVE_HAMILTONIAN_KEYS && throw(
        ArgumentError(
            "UNSUPPORTED_LEGACY_AUTHORITY: authoritative Hamiltonian $(value) is retired",
        ),
    )
    value in (_NATIVE_DFT_HAMILTONIAN_KEY, _SYMMETRIZED_DFT_HAMILTONIAN_KEY) ||
        throw(ArgumentError("unsupported authoritative Hamiltonian key $(value)"))
    return value
end

"""Return whether a band representation contains only the exact unitary identity."""
function is_identity_group_representation(representation::BandRepresentation)
    length(representation.operations) == 1 || return false
    operation = only(representation.operations)
    return !operation.antiunitary &&
           operation.rotation_fractional == Matrix{Int}(I, 3, 3) &&
           maximum(abs, operation.translation_fractional; init = 0.0) <= 1.0e-10
end

"""Validate the unified representation-mode contract required by public 1.0 and internal stages 1.15--1.17."""
function _validate_unified_representation_mode_contract(representation::BandRepresentation)
    representation.schema_version in ("1.0", "1.15", "1.16", "1.17") || return nothing
    conventions = representation.conventions
    for key in (
        "requested_wannierization_mode",
        "effective_wannierization_mode",
        "representation_source",
        "symmetry_constraints_applied",
    )
        haskey(conventions, key) || throw(
            ArgumentError(
                "schema-$(representation.schema_version) representation is missing $(key)",
            ),
        )
    end
    requested = Symbol(conventions["requested_wannierization_mode"])
    effective = Symbol(conventions["effective_wannierization_mode"])
    source = Symbol(conventions["representation_source"])
    constraints = conventions["symmetry_constraints_applied"]
    requested in (:auto, :ordinary, :symmetry_adapted) ||
        throw(ArgumentError("representation requested Wannierization mode is invalid"))
    effective in (:ordinary, :symmetry_adapted) ||
        throw(ArgumentError("representation effective Wannierization mode is invalid"))
    source in (:identity, :detected, :provided) ||
        throw(ArgumentError("representation source is invalid"))
    expected_effective = requested == :auto ? :symmetry_adapted : requested
    effective == expected_effective ||
        throw(ArgumentError("representation requested/effective mode contract is inconsistent"))
    identity_fast_path =
        effective == :symmetry_adapted &&
        constraints == "false" &&
        is_identity_group_representation(representation)
    constraints == string(effective == :symmetry_adapted) ||
        identity_fast_path ||
        throw(ArgumentError("representation symmetry-constraint flag contradicts effective mode"))
    if effective == :ordinary || identity_fast_path
        source in (:identity, :provided) ||
            throw(ArgumentError("identity representation source must be identity or provided"))
        is_identity_group_representation(representation) ||
            throw(ArgumentError("identity representation must contain only identity"))
        !only(representation.operations).antiunitary ||
            throw(ArgumentError("identity operation must be unitary"))
    end
    return nothing
end

"""One report-only mapped-sewing diagnostic in a declared qualification scope."""
struct RepresentationRawDiagnostic
    scope::Symbol
    operation_index::Int
    source_kpoint::Int
    target_kpoint::Int
    antiunitary::Bool
    source_band_count::Int
    target_band_count::Int
    required_rank::Int
    numerical_rank::Int
    rank_threshold::Float64
    minimum_singular_value::Float64
    maximum_singular_value::Float64
    condition_estimate::Float64
    left_unitarity_residual::Float64
    right_unitarity_residual::Float64
    status::Symbol

    function RepresentationRawDiagnostic(
        scope,
        operation_index,
        source_kpoint,
        target_kpoint,
        antiunitary,
        source_band_count,
        target_band_count,
        required_rank,
        numerical_rank,
        rank_threshold,
        minimum_singular_value,
        maximum_singular_value,
        condition_estimate,
        left_unitarity_residual,
        right_unitarity_residual,
        status,
    )
        scope_value = Symbol(scope)
        scope_value in (:full, :outer, :frozen, :outside) ||
            throw(ArgumentError("raw diagnostic scope must be :full, :outer, :frozen, or :outside"))
        integer_values = Int.((
            operation_index,
            source_kpoint,
            target_kpoint,
            source_band_count,
            target_band_count,
            required_rank,
            numerical_rank,
        ))
        all(>=(0), integer_values[4:end]) ||
            throw(ArgumentError("raw diagnostic band counts and ranks must be nonnegative"))
        all(>(0), integer_values[1:3]) ||
            throw(ArgumentError("raw diagnostic operation and k-point indices must be positive"))
        real_values = Float64.((
            rank_threshold,
            minimum_singular_value,
            maximum_singular_value,
            condition_estimate,
            left_unitarity_residual,
            right_unitarity_residual,
        ))
        all(value -> isfinite(value) || isinf(value), real_values) ||
            throw(ArgumentError("raw diagnostic contains NaN values"))
        return new(
            scope_value,
            integer_values[1],
            integer_values[2],
            integer_values[3],
            Bool(antiunitary),
            integer_values[4],
            integer_values[5],
            integer_values[6],
            integer_values[7],
            real_values[1],
            real_values[2],
            real_values[3],
            real_values[4],
            real_values[5],
            real_values[6],
            Symbol(status),
        )
    end
end

"""Return the qualification-mask identity including its matrix dimensions."""
function qualification_mask_sha256(mask::AbstractMatrix{Bool})
    buffer = IOBuffer()
    write(buffer, reinterpret(UInt8, Int64.(collect(size(mask)))))
    write(buffer, vec(UInt8.(mask)))
    return bytes2hex(SHA.sha256(take!(buffer)))
end

"""Outer/frozen qualification masks bound to deterministic SHA-256 identities."""
struct BandRepresentationQualificationScope
    outer_mask::BitMatrix
    frozen_mask::BitMatrix
    outer_mask_sha256::String
    frozen_mask_sha256::String
    diagnostic_status::Symbol

    function BandRepresentationQualificationScope(
        outer_mask,
        frozen_mask;
        outer_mask_sha256 = nothing,
        frozen_mask_sha256 = nothing,
        diagnostic_status = :AVAILABLE,
    )
        outer = BitMatrix(Bool.(outer_mask))
        frozen = BitMatrix(Bool.(frozen_mask))
        size(outer) == size(frozen) ||
            throw(ArgumentError("outer and frozen qualification masks must have identical size"))
        all((.!frozen) .| outer) ||
            throw(ArgumentError("frozen qualification mask must be contained in outer mask"))
        outer_digest =
            outer_mask_sha256 === nothing ? qualification_mask_sha256(outer) :
            String(outer_mask_sha256)
        frozen_digest =
            frozen_mask_sha256 === nothing ? qualification_mask_sha256(frozen) :
            String(frozen_mask_sha256)
        return new(outer, frozen, outer_digest, frozen_digest, Symbol(diagnostic_status))
    end
end
