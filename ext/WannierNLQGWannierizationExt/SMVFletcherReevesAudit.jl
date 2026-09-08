"""Return the scientific digest of the frozen Wannier90-reference parity contract."""
function smv_fletcher_reeves_two_stage_audit_contract_sha256(
    thresholds::SMVFletcherReevesTwoStageAuditThresholds = SMVFletcherReevesTwoStageAuditThresholds(),
)
    validate_smv_fletcher_reeves_two_stage_audit_thresholds(thresholds)
    buffer = IOBuffer()
    for entry in (
        ("standard_version", thresholds.standard_version),
        ("semantic", thresholds.semantic),
        ("accepted_step_combination_rule", thresholds.accepted_step_combination_rule),
        ("accepted_step_absolute_tolerance", repr(thresholds.accepted_step_absolute_tolerance)),
        ("accepted_step_relative_tolerance", repr(thresholds.accepted_step_relative_tolerance)),
        (
            "omega_i_absolute_tolerance_angstrom2",
            repr(thresholds.omega_i_absolute_tolerance_angstrom2),
        ),
        ("projector_operator_tolerance", repr(thresholds.projector_operator_tolerance)),
        (
            "maximum_principal_angle_tolerance_rad",
            repr(thresholds.maximum_principal_angle_tolerance_rad),
        ),
        (
            "z_to_u_initial_spread_absolute_tolerance_angstrom2",
            repr(thresholds.z_to_u_initial_spread_absolute_tolerance_angstrom2),
        ),
        ("u_nonstep_relative_tolerance", repr(thresholds.u_nonstep_relative_tolerance)),
    )
        write(buffer, entry[1], '=', entry[2], '\n')
    end
    return bytes2hex(SHA.sha256(take!(buffer)))
end

"""Digest the mechanically split solver as the original ordered source stream."""
function _symmetry_adapted_solver_source_sha256()
    buffer = IOBuffer()
    for filename in (
        "LinearAlgebra.jl",
        "SymmetryFrames.jl",
        "Initialization.jl",
        "Localization.jl",
        "Optimizer.jl",
        "RestartWorkflow.jl",
    )
        write(buffer, read(joinpath(@__DIR__, "solver", filename)))
    end
    return bytes2hex(SHA.sha256(take!(buffer)))
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
        manifest_sha256 = "NOT_AVAILABLE",
    )
    manifest_sha256 = sha256_file(path)
    manifest = try
        _smv_fletcher_reeves_two_stage_json_read(read(path, String))
    catch error
        return (
            passed = false,
            status = "AUDIT_MANIFEST_INVALID",
            reason = sprint(showerror, error),
            manifest_path = path,
            manifest_sha256,
        )
    end
    required = (
        "schema",
        "schema_version",
        "status",
        "passed",
        "algorithm_contract_version",
        "parity_standard_version",
        "parity_semantic",
        "accepted_step_combination_rule",
        "accepted_step_absolute_tolerance",
        "accepted_step_relative_tolerance",
        "parity_contract_sha256",
        "solver_source_sha256",
        "models_source_sha256",
        "oracle_sha256",
        "parity_evidence_sha256",
        "cr_qualification_sha256",
    )
    missing = filter(key -> !haskey(manifest, key), required)
    isempty(missing) || return (
        passed = false,
        status = "AUDIT_MANIFEST_INVALID",
        reason = "missing fields: $(join(missing, ','))",
        manifest_path = path,
        manifest_sha256,
    )
    expected_contract = smv_fletcher_reeves_two_stage_audit_contract_sha256(thresholds)
    models_path = @__FILE__
    checks = (
        String(manifest["schema"]) == SMV_FLETCHER_REEVES_TWO_STAGE_AUDIT_SCHEMA,
        String(manifest["schema_version"]) == SMV_FLETCHER_REEVES_TWO_STAGE_AUDIT_SCHEMA_VERSION,
        String(manifest["status"]) == SMV_FLETCHER_REEVES_TWO_STAGE_AUDIT_PASS_STATUS,
        manifest["passed"] === true,
        String(manifest["algorithm_contract_version"]) ==
        SMV_FLETCHER_REEVES_TWO_STAGE_ALGORITHM_CONTRACT_VERSION,
        String(manifest["parity_standard_version"]) == thresholds.standard_version,
        String(manifest["parity_semantic"]) == thresholds.semantic,
        String(manifest["accepted_step_combination_rule"]) ==
        thresholds.accepted_step_combination_rule,
        Float64(manifest["accepted_step_absolute_tolerance"]) ==
        thresholds.accepted_step_absolute_tolerance,
        Float64(manifest["accepted_step_relative_tolerance"]) ==
        thresholds.accepted_step_relative_tolerance,
        String(manifest["parity_contract_sha256"]) == expected_contract,
        String(manifest["solver_source_sha256"]) == _symmetry_adapted_solver_source_sha256(),
        String(manifest["models_source_sha256"]) == sha256_file(models_path),
        all(
            key -> occursin(r"^[0-9a-f]{64}$", String(manifest[key])),
            ("oracle_sha256", "parity_evidence_sha256", "cr_qualification_sha256"),
        ),
    )
    all(checks) || return (
        passed = false,
        status = "AUDIT_DIGEST_MISMATCH",
        reason = "audit manifest contract or source digest mismatch",
        manifest_path = path,
        manifest_sha256,
    )
    return (
        passed = true,
        status = SMV_FLETCHER_REEVES_TWO_STAGE_AUDIT_PASS_STATUS,
        reason = "all frozen oracle-audit identities match",
        manifest_path = path,
        manifest_sha256,
    )
end

"""Return an optional SMV--FR audit without changing solver state or eligibility."""
function smv_fletcher_reeves_two_stage_audit(;
    manifest_path::Union{Nothing, AbstractString} = nothing,
    thresholds::SMVFletcherReevesTwoStageAuditThresholds = SMVFletcherReevesTwoStageAuditThresholds(),
)
    return _smv_fletcher_reeves_two_stage_audit(manifest_path, thresholds)
end
