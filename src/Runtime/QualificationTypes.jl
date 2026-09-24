"""
Machine-readable execution and production qualification for one completed response task.

`execution_eligible` reports whether the structural and mathematical input contract was
accepted. `qualification_status` is `PASS` or `DIAGNOSTIC_ONLY` for a completed run;
`NOT_EVALUATED` is reserved for the legacy positional `RunResult` constructor. Missing
evidence is retained in `unverified_contracts`; an explicit contradiction is retained in
`conflicting_contracts` and prevents execution.
"""
struct ResponseQualificationResult
    execution_eligible::Bool
    qualification_status::String
    production_eligible::Bool
    quality_review_recommended::Bool
    reasons::Vector{String}
    verified_contracts::Vector{String}
    unverified_contracts::Vector{String}
    conflicting_contracts::Vector{String}
    input_qualification::Dict{String, Any}

    function ResponseQualificationResult(
        execution_eligible::Bool,
        qualification_status::String,
        production_eligible::Bool,
        quality_review_recommended::Bool,
        reasons::Vector{String},
        verified_contracts::Vector{String},
        unverified_contracts::Vector{String},
        conflicting_contracts::Vector{String},
        input_qualification::Dict{String, Any},
    )
        qualification_status in ("PASS", "DIAGNOSTIC_ONLY", "NOT_EVALUATED") || throw(
            ArgumentError("invalid response qualification status $(repr(qualification_status))"),
        )
        execution_eligible &&
            !isempty(conflicting_contracts) &&
            throw(ArgumentError("an execution-eligible qualification cannot contain conflicts"))
        production_eligible &&
            (!execution_eligible || qualification_status != "PASS") &&
            throw(ArgumentError("production eligibility requires an execution-eligible PASS"))
        return new(
            execution_eligible,
            qualification_status,
            production_eligible,
            quality_review_recommended,
            sort!(unique!(copy(reasons))),
            sort!(unique!(copy(verified_contracts))),
            sort!(unique!(copy(unverified_contracts))),
            sort!(unique!(copy(conflicting_contracts))),
            copy(input_qualification),
        )
    end
end

# Return sorted unique strings so serial, threaded, and MPI metadata remain byte-stable.
_qualification_strings(values) = sort!(unique!(String[string(value) for value in values]))

"""Construct one normalized response qualification result."""
function ResponseQualificationResult(
    execution_eligible::Bool,
    qualification_status::AbstractString,
    production_eligible::Bool,
    quality_review_recommended::Bool,
    reasons,
    verified_contracts,
    unverified_contracts,
    conflicting_contracts,
    input_qualification::AbstractDict,
)
    status = String(qualification_status)
    status in ("PASS", "DIAGNOSTIC_ONLY", "NOT_EVALUATED") ||
        throw(ArgumentError("invalid response qualification status $(repr(status))"))
    conflicts = _qualification_strings(conflicting_contracts)
    execution_eligible &&
        !isempty(conflicts) &&
        throw(ArgumentError("an execution-eligible qualification cannot contain conflicts"))
    production_eligible &&
        (!execution_eligible || status != "PASS") &&
        throw(ArgumentError("production eligibility requires an execution-eligible PASS"))
    return ResponseQualificationResult(
        execution_eligible,
        status,
        production_eligible,
        quality_review_recommended,
        _qualification_strings(reasons),
        _qualification_strings(verified_contracts),
        _qualification_strings(unverified_contracts),
        conflicts,
        Dict{String, Any}(String(key) => value for (key, value) in pairs(input_qualification)),
    )
end

"""Return the honest placeholder used only by the backward-compatible RunResult constructor."""
function not_evaluated_response_qualification()
    return ResponseQualificationResult(
        false,
        "NOT_EVALUATED",
        false,
        true,
        ["LEGACY_CONSTRUCTOR_NO_QUALIFICATION"],
        String[],
        ["RESPONSE_QUALIFICATION_NOT_EVALUATED"],
        String[],
        Dict{String, Any}("input_mode" => "NOT_EVALUATED"),
    )
end

"""Conservatively combine child task qualifications for a multi-task RunResult."""
function aggregate_response_qualifications(results::AbstractVector{ResponseQualificationResult})
    isempty(results) && return not_evaluated_response_qualification()
    execution_eligible = all(result -> result.execution_eligible, results)
    production_eligible = all(result -> result.production_eligible, results)
    qualification_status =
        execution_eligible && all(result -> result.qualification_status == "PASS", results) ?
        "PASS" : "DIAGNOSTIC_ONLY"
    return ResponseQualificationResult(
        execution_eligible,
        qualification_status,
        production_eligible,
        any(result -> result.quality_review_recommended, results) || !production_eligible,
        reduce(vcat, (result.reasons for result in results); init = String[]),
        reduce(vcat, (result.verified_contracts for result in results); init = String[]),
        reduce(vcat, (result.unverified_contracts for result in results); init = String[]),
        reduce(vcat, (result.conflicting_contracts for result in results); init = String[]),
        Dict{String, Any}(
            "input_mode" => "MULTI_TASK_AGGREGATE",
            "task_count" => length(results),
            "task_qualification_statuses" => [result.qualification_status for result in results],
            "task_production_eligible" => [result.production_eligible for result in results],
        ),
    )
end

"""Internal hard-stop exception carrying the conflicting qualification result."""
struct ResponseQualificationError <: Exception
    code::String
    qualification::ResponseQualificationResult
end

"""Render the stable error code and machine-readable qualification reason lists."""
function Base.showerror(io::Base.IO, err::ResponseQualificationError)
    print(
        io,
        err.code,
        ": conflicting_contracts=",
        join(err.qualification.conflicting_contracts, ","),
        "; reasons=",
        join(err.qualification.reasons, ","),
    )
end
