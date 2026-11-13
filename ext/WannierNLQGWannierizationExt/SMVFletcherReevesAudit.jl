"""Reject the retired digest API; no content authentication is computed."""
function smv_fletcher_reeves_two_stage_audit_contract_sha256(
    thresholds::SMVFletcherReevesTwoStageAuditThresholds = SMVFletcherReevesTwoStageAuditThresholds(),
)
    validate_smv_fletcher_reeves_two_stage_audit_thresholds(thresholds)
    throw(
        ArgumentError("CONTENT_HASH_AUTHENTICATION_REMOVED: use actual scientific audit evidence"),
    )
end

"""Return the package-local optional SMV--FR audit path."""
_smv_fletcher_reeves_two_stage_default_audit_path() = normpath(
    joinpath(
        @__DIR__,
        "..",
        "..",
        "qualification",
        "wannierization",
        "smv_fletcher_reeves_two_stage_audit.json",
    ),
)

# JSON3 is an extension trigger and is used only when an explicit qualification
# manifest is audited.
function _smv_fletcher_reeves_two_stage_json_read(text::AbstractString)
    return JSON3.read(text, Dict{String, Any})
end

"""Audit one optional SMV--FR evidence manifest without controlling solver execution."""
function _smv_fletcher_reeves_two_stage_audit(
    manifest_path::Union{Nothing, AbstractString},
    thresholds::SMVFletcherReevesTwoStageAuditThresholds,
)
    path =
        manifest_path === nothing ? _smv_fletcher_reeves_two_stage_default_audit_path() :
        abspath(String(manifest_path))
    isfile(path) || return (
        passed = false,
        status = "AUDIT_MANIFEST_MISSING",
        reason = "optional audit manifest does not exist",
        manifest_path = path,
        content_authentication = "NOT_PERFORMED",
    )
    manifest = try
        _smv_fletcher_reeves_two_stage_json_read(read(path, String))
    catch error
        return (
            passed = false,
            status = "AUDIT_MANIFEST_INVALID",
            reason = sprint(showerror, error),
            manifest_path = path,
            content_authentication = "NOT_PERFORMED",
        )
    end
    # The retired format contains only digests of its oracle, parity evidence,
    # CR qualification and source. It has no actual reference data to compare.
    # Reading a declared PASS cannot restore those missing scientific records.
    return (
        passed = false,
        status = "AUDIT_COMPLETE_EVIDENCE_REQUIRED",
        reason = "digest-only audit manifests cannot establish source or scientific evidence equality; retain the original and supply an explicit independent audit with actual data",
        manifest_path = path,
        content_authentication = "NOT_PERFORMED",
    )
end

"""Return an optional SMV--FR audit without changing solver state or eligibility."""
function smv_fletcher_reeves_two_stage_audit(;
    manifest_path::Union{Nothing, AbstractString} = nothing,
    thresholds::SMVFletcherReevesTwoStageAuditThresholds = SMVFletcherReevesTwoStageAuditThresholds(),
)
    return _smv_fletcher_reeves_two_stage_audit(manifest_path, thresholds)
end
