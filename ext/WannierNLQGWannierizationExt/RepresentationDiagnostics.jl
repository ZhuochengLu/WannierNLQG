const REPRESENTATION_DIAGNOSTIC_CODES = Set{Symbol}([
    :OPERATION_ORACLE_MISMATCH,
    :KPOINT_ACTION_ORACLE_MISMATCH,
    :RECIPROCAL_SHIFT_ORACLE_MISMATCH,
    :SPIN_ROTATION_ORACLE_MISMATCH,
    :SEWING_BLOCK_ALIGNMENT_FAILED,
    :SEWING_ORACLE_MISMATCH,
    :OPERATION_GROUP_NOT_CLOSED,
    :RECIPROCAL_ACTION_INCONSISTENT,
    :SPIN_DOUBLE_GROUP_INCONSISTENT,
    :ANTIUNITARY_GROUP_LAW_FAILED,
    :THETA_SQUARED_FAILED,
    :KRAMERS_BLOCK_NOT_CLOSED,
    :COREPRESENTATION_BLOCK_NOT_CLOSED,
    :TARGET_COREPRESENTATION_MULTIPLICITY_MISMATCH,
    :TARGET_REPRESENTATION_GROUP_LAW_FAILED,
    :ANTIUNITARY_PROJECTOR_COVARIANCE_FAILED,
    :REPRESENTATION_COMPATIBILITY_UNAVAILABLE,
    :GATE_DEFINITION_INVALID,
    :REPRESENTATION_STATUS_UNDETERMINED,
    :GVECTOR_ORACLE_MISMATCH,
    :COEFFICIENT_NORMALIZATION_MISMATCH,
    :GROUP_LAW_ORACLE_EXCESS,
    :ORACLE_REFERENCE_UNAVAILABLE,
    :ORACLE_REFERENCE_DIFFERENCE,
    :REQUIRED_BLOCK_UNITARITY_FAILED,
    :SEWING_BLOCK_RANK_DEFICIENT,
    :EMPIRICAL_PROJECTOR_COVARIANCE_BUDGET,
    :EMPIRICAL_COVARIANCE_BUDGET_VACUOUS,
])

const GROUP_LAW_COMBINATION_LABELS = ("UU", "UA", "AU", "AA")

# Construct only registered representation diagnostics with normalized context.
function _representation_diagnostic(
    code::Symbol,
    severity::Symbol,
    message::AbstractString;
    context = Dict{String, String}(),
)
    code in REPRESENTATION_DIAGNOSTIC_CODES ||
        throw(ArgumentError("unregistered representation diagnostic code $(code)"))
    normalized = Dict{String, String}(string(key) => string(value) for (key, value) in context)
    return WannierizationDiagnostic(code, severity, message; context = normalized)
end

# Apply the configured fail/warn policy without changing the measured report.
function _representation_diagnostics_for_policy(
    diagnostics::Vector{WannierizationDiagnostic},
    policy::Symbol,
)
    policy in (:strict, :warn, :off) ||
        throw(ArgumentError("unknown compatibility policy $(policy)"))
    policy == :off && return WannierizationDiagnostic[]
    policy == :strict && return copy(diagnostics)
    return [
        WannierizationDiagnostic(
            diagnostic.code,
            diagnostic.severity == :error ? :warning : diagnostic.severity,
            diagnostic.message;
            context = diagnostic.context,
        ) for diagnostic in diagnostics
    ]
end

# Return true when a compatibility result contains at least one hard failure.
_has_representation_error(diagnostics::Vector{WannierizationDiagnostic}) =
    any(diagnostic -> diagnostic.severity == :error, diagnostics)

# Map operation antiunitarity to the stable (UU, UA, AU, AA) residual slot.
function _group_law_combination_index(left_antiunitary::Bool, right_antiunitary::Bool)
    return left_antiunitary ? (right_antiunitary ? 4 : 3) : (right_antiunitary ? 2 : 1)
end

const _CONSTRUCTION_COMPATIBILITY_QUALITY_CODES = (
    :REQUIRED_BLOCK_UNITARITY_FAILED,
    :ANTIUNITARY_GROUP_LAW_FAILED,
    :TARGET_REPRESENTATION_GROUP_LAW_FAILED,
    :THETA_SQUARED_FAILED,
    :ANTIUNITARY_PROJECTOR_COVARIANCE_FAILED,
    :EMPIRICAL_COVARIANCE_BUDGET_VACUOUS,
)

# Closure residuals are quality failures only when the discrete rank contracts
# hold. Odd Kramers rank and mismatched mask ranks remain construction failures.
function construction_compatibility_quality_failure(diagnostic::WannierizationDiagnostic)
    if diagnostic.code in _CONSTRUCTION_COMPATIBILITY_QUALITY_CODES
        # A shared code may also identify a discrete inventory/rank failure.
        # Only an explicit finite numerical residual can be a quality warning.
        residual_key =
            diagnostic.code == :EMPIRICAL_COVARIANCE_BUDGET_VACUOUS ? "maximum_group_law_residual" :
            "maximum_error"
        threshold_key =
            diagnostic.code == :EMPIRICAL_COVARIANCE_BUDGET_VACUOUS ? "strict_upper_bound" :
            "tolerance"
        residual = tryparse(Float64, get(diagnostic.context, residual_key, ""))
        threshold = tryparse(Float64, get(diagnostic.context, threshold_key, ""))
        return residual !== nothing &&
               threshold !== nothing &&
               isfinite(residual) &&
               residual >= 0 &&
               isfinite(threshold) &&
               threshold > 0
    end
    diagnostic.code in (:KRAMERS_BLOCK_NOT_CLOSED, :COREPRESENTATION_BLOCK_NOT_CLOSED) ||
        return false
    source_rank = tryparse(Int, get(diagnostic.context, "source_rank", ""))
    target_rank = tryparse(Int, get(diagnostic.context, "target_rank", ""))
    residual = tryparse(Float64, get(diagnostic.context, "maximum_error", ""))
    source_rank !== nothing &&
    source_rank == target_rank &&
    residual !== nothing &&
    isfinite(residual) || return false
    if diagnostic.code == :KRAMERS_BLOCK_NOT_CLOSED &&
       get(diagnostic.context, "source_kpoint", "") == get(diagnostic.context, "target_kpoint", "")
        iseven(source_rank) || return false
    end
    return true
end
