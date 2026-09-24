"""
Machine-readable execution, export, and production qualification for one wannierization task.

This is the single derived source of truth for the wannierization eligibility
surface. It replaces the former `qualified_z_seal`, `route_selection_eligible`,
`standard_tb_export_eligible`, and `accepted_state_tb_export_eligible` summary keys,
which were written at several independent sites and read at almost none, so the
persisted qualification could disagree with itself.

`execution_eligible` reports that the workflow reached a structurally valid accepted
boundary. `export_eligible` reports that the accepted-state TB structural gate allowed
export. `production_eligible` reports the strict scoped production contract.
`strictly_converged_z_seal` mirrors the retained `z_seal_class == "CONVERGED"`
Z-stability signal, which is the same evidence the deleted `qualified_z_seal` key
carried. Missing evidence is retained in `unverified_contracts`; an explicit
contradiction is retained in `conflicting_contracts` and prevents execution.
"""
struct WannierizationEligibility
    execution_eligible::Bool
    export_eligible::Bool
    production_eligible::Bool
    qualification_status::String
    quality_review_recommended::Bool
    strictly_converged_z_seal::Bool
    reasons::Vector{String}
    verified_contracts::Vector{String}
    unverified_contracts::Vector{String}
    conflicting_contracts::Vector{String}

    function WannierizationEligibility(
        execution_eligible::Bool,
        export_eligible::Bool,
        production_eligible::Bool,
        qualification_status::String,
        quality_review_recommended::Bool,
        strictly_converged_z_seal::Bool,
        reasons::Vector{String},
        verified_contracts::Vector{String},
        unverified_contracts::Vector{String},
        conflicting_contracts::Vector{String},
    )
        qualification_status in ("PASS", "DIAGNOSTIC_ONLY", "NOT_EVALUATED") || throw(
            ArgumentError(
                "invalid wannierization qualification status $(repr(qualification_status))",
            ),
        )
        execution_eligible &&
            !isempty(conflicting_contracts) &&
            throw(
                ArgumentError(
                    "an execution-eligible wannierization qualification cannot contain conflicts",
                ),
            )
        export_eligible &&
            !execution_eligible &&
            throw(
                ArgumentError(
                    "wannierization export eligibility requires an execution-eligible state",
                ),
            )
        production_eligible &&
            (!execution_eligible || qualification_status != "PASS") &&
            throw(
                ArgumentError(
                    "wannierization production eligibility requires an execution-eligible PASS",
                ),
            )
        return new(
            execution_eligible,
            export_eligible,
            production_eligible,
            qualification_status,
            quality_review_recommended,
            strictly_converged_z_seal,
            sort!(unique!(copy(reasons))),
            sort!(unique!(copy(verified_contracts))),
            sort!(unique!(copy(unverified_contracts))),
            sort!(unique!(copy(conflicting_contracts))),
        )
    end
end

# Return sorted unique strings so serial, threaded, and MPI metadata remain byte-stable.
_eligibility_strings(values) = sort!(unique!(String[string(value) for value in values]))

"""Construct one normalized wannierization eligibility block."""
function WannierizationEligibility(
    execution_eligible::Bool,
    export_eligible::Bool,
    production_eligible::Bool,
    qualification_status::AbstractString,
    quality_review_recommended::Bool,
    strictly_converged_z_seal::Bool,
    reasons,
    verified_contracts,
    unverified_contracts,
    conflicting_contracts,
)
    return WannierizationEligibility(
        execution_eligible,
        export_eligible,
        production_eligible,
        String(qualification_status),
        quality_review_recommended,
        strictly_converged_z_seal,
        _eligibility_strings(reasons),
        _eligibility_strings(verified_contracts),
        _eligibility_strings(unverified_contracts),
        _eligibility_strings(conflicting_contracts),
    )
end

"""Return the honest placeholder used for an accepted but still in-progress checkpoint."""
function not_evaluated_wannierization_eligibility(strictly_converged_z_seal::Bool = false)
    return WannierizationEligibility(
        false,
        false,
        false,
        "NOT_EVALUATED",
        true,
        strictly_converged_z_seal,
        ["PERIODIC_CHECKPOINT_IN_PROGRESS"],
        String[],
        ["ACCEPTED_STATE_STRUCTURAL_GATE"],
        String[],
    )
end

"""Summary keys of the persisted typed eligibility block."""
const WANNIERIZATION_ELIGIBILITY_SUMMARY_KEYS = (
    "wannierization_eligibility_execution_eligible",
    "wannierization_eligibility_export_eligible",
    "wannierization_eligibility_production_eligible",
    "wannierization_eligibility_qualification_status",
    "wannierization_eligibility_quality_review_recommended",
    "wannierization_eligibility_strictly_converged_z_seal",
    "wannierization_eligibility_reasons",
    "wannierization_eligibility_verified_contracts",
    "wannierization_eligibility_unverified_contracts",
    "wannierization_eligibility_conflicting_contracts",
)

# List-valued fields persist as one sorted, unique, `|`-separated string so the
# summary dictionary, the HDF5 attributes, and the scientific digest all agree.
_eligibility_list_encode(values) = join(_eligibility_strings(values), '|')

# Decode one persisted pipe-separated eligibility list back into plain strings.
# This mirrors _eligibility_list_encode for summary and HDF5 readback paths.
function _eligibility_list_decode(value)
    text = String(value)
    return isempty(text) ? String[] : String.(split(text, '|'))
end

# Read one persisted boolean eligibility field from a summary dictionary.
# Missing keys default to false so legacy summaries stay consumable.
_eligibility_bool(summary, key) = lowercase(string(get(summary, key, "false"))) == "true"

"""Serialize one typed eligibility block into stable summary strings."""
function wannierization_eligibility_summary(eligibility::WannierizationEligibility)
    return Dict{String, String}(
        "wannierization_eligibility_execution_eligible" => string(eligibility.execution_eligible),
        "wannierization_eligibility_export_eligible" => string(eligibility.export_eligible),
        "wannierization_eligibility_production_eligible" => string(eligibility.production_eligible),
        "wannierization_eligibility_qualification_status" => eligibility.qualification_status,
        "wannierization_eligibility_quality_review_recommended" =>
            string(eligibility.quality_review_recommended),
        "wannierization_eligibility_strictly_converged_z_seal" =>
            string(eligibility.strictly_converged_z_seal),
        "wannierization_eligibility_reasons" => _eligibility_list_encode(eligibility.reasons),
        "wannierization_eligibility_verified_contracts" =>
            _eligibility_list_encode(eligibility.verified_contracts),
        "wannierization_eligibility_unverified_contracts" =>
            _eligibility_list_encode(eligibility.unverified_contracts),
        "wannierization_eligibility_conflicting_contracts" =>
            _eligibility_list_encode(eligibility.conflicting_contracts),
    )
end

"""Rebuild one typed eligibility block from persisted summary strings."""
function wannierization_eligibility_from_summary(summary::AbstractDict)
    status =
        String(get(summary, "wannierization_eligibility_qualification_status", "NOT_EVALUATED"))
    status in ("PASS", "DIAGNOSTIC_ONLY", "NOT_EVALUATED") || (status = "NOT_EVALUATED")
    return WannierizationEligibility(
        _eligibility_bool(summary, "wannierization_eligibility_execution_eligible"),
        _eligibility_bool(summary, "wannierization_eligibility_export_eligible"),
        _eligibility_bool(summary, "wannierization_eligibility_production_eligible"),
        status,
        _eligibility_bool(summary, "wannierization_eligibility_quality_review_recommended"),
        _eligibility_bool(summary, "wannierization_eligibility_strictly_converged_z_seal"),
        _eligibility_list_decode(get(summary, "wannierization_eligibility_reasons", "")),
        _eligibility_list_decode(get(summary, "wannierization_eligibility_verified_contracts", "")),
        _eligibility_list_decode(
            get(summary, "wannierization_eligibility_unverified_contracts", ""),
        ),
        _eligibility_list_decode(
            get(summary, "wannierization_eligibility_conflicting_contracts", ""),
        ),
    )
end
