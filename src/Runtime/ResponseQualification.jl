# Read optional qualification fields without converting missing evidence into a PASS.
function _response_qualification_entry(values, name::String, default = nothing)
    values isa AbstractDict || values isa NamedTuple || return default
    values isa NamedTuple &&
        hasproperty(values, Symbol(name)) &&
        return getproperty(values, Symbol(name))
    haskey(values, name) && return values[name]
    haskey(values, Symbol(name)) && return values[Symbol(name)]
    return default
end

"""Return true only for a concrete lowercase SHA-256 contract value."""
_response_qualification_sha256(value) =
    value isa AbstractString && occursin(r"^[0-9a-f]{64}$", String(value))

"""Distinguish concrete recorded evidence from legacy and missing sentinels."""
function _response_qualification_recorded(value)
    value === nothing && return false
    text = String(value)
    return !isempty(text) &&
           text ∉ ("NOT_RECORDED", "NOT_APPLICABLE", "LEGACY_NOT_RECORDED") &&
           !startswith(text, "LEGACY_")
end

# Preserve the writer-owned aggregate state and the specific gates useful to downstream audits.
function _input_qualification_summary(manifest, input_mode::Symbol)
    manifest === nothing && return Dict{String, Any}(
        "input_mode" => string(input_mode),
        "bundle_present" => false,
        "production_eligible" => false,
        "quality_review_recommended" => true,
        "qualification_status" => "NOT_RECORDED",
    )
    construction_policy = _response_qualification_entry(
        manifest.operator_qualification,
        "construction_policy",
        "NOT_RECORDED",
    )
    return Dict{String, Any}(
        "input_mode" => string(input_mode),
        "bundle_present" => true,
        "schema_version" => manifest.schema_version,
        "profile" => string(manifest.profile),
        "operator_selection_mode" => manifest.operator_selection_mode,
        "resolved_operator_inventory" => join(real_space_operator_name.(manifest.inventory), ","),
        "resolved_source_inventory" => manifest.resolved_source_inventory,
        "derived_operator_capabilities" =>
            join(String.(derived_operator_capabilities(manifest.inventory)), ","),
        "scientific_content_sha256" => manifest.scientific_content_sha256,
        "production_eligible" => manifest.production_eligible,
        "quality_review_recommended" => manifest.quality_review_recommended,
        "construction_policy" => string(construction_policy),
        "wannierization_status" => something(manifest.wannierization_status, "NOT_RECORDED"),
        "solver_convergence" => something(manifest.solver_convergence, "NOT_RECORDED"),
        "numerical_quality" => something(manifest.numerical_quality, "NOT_RECORDED"),
        "tb_export_status" => something(manifest.tb_export_status, "NOT_RECORDED"),
        "physics_qualification" => something(manifest.physics_qualification, "NOT_RECORDED"),
        "final_physics_qualification" =>
            something(manifest.final_physics_qualification, "NOT_RECORDED"),
        "final_production_eligible" => something(manifest.final_production_eligible, false),
        "tb_symmetry_qualification" => manifest.tb_symmetry_qualification_overall,
        "spin_family_qualification" => manifest.spin_family_qualification,
        "spin_family_production_eligible" => manifest.spin_family_production_eligible,
        "finite_band_galerkin_qualification" => manifest.finite_band_galerkin_qualification,
        "finite_band_galerkin_production_eligible" =>
            manifest.finite_band_galerkin_production_eligible,
        "band_frame_contract_status" => manifest.band_frame_contract_status,
        "band_frame_contract_sha256" => manifest.band_frame_contract_sha256,
    )
end

# Compare only identities declared to be common; distinct per-operator source files are expected.
function _generic_operator_contract_assessment(manifest, demand::OperatorDemandPlan)
    verified = String[]
    unverified = String[]
    conflicts = String[]
    reasons = String[]
    qualification = manifest.operator_qualification
    operators = _response_qualification_entry(qualification, "operators", Dict{String, Any}())
    target_gauges = String[]
    for kind in demand.required_operators
        name = real_space_operator_name(kind)
        record = _response_qualification_entry(operators, name, nothing)
        if record === nothing
            push!(unverified, "operator.$(name).qualification")
            push!(reasons, "OPERATOR_QUALIFICATION_NOT_RECORDED")
            continue
        end
        status = String(_response_qualification_entry(record, "qualification", "NOT_RECORDED"))
        source_status =
            String(_response_qualification_entry(record, "source_status", "NOT_RECORDED"))
        gauge_status = String(_response_qualification_entry(record, "gauge_status", "NOT_RECORDED"))
        if status == "PASS"
            push!(verified, "operator.$(name).qualification")
        else
            push!(unverified, "operator.$(name).qualification")
            push!(reasons, "OPERATOR_QUALIFICATION_NOT_PASS")
        end
        if source_status == "PASS"
            push!(verified, "operator.$(name).source")
        else
            push!(unverified, "operator.$(name).source")
            push!(reasons, "OPERATOR_SOURCE_UNVERIFIED")
        end
        if gauge_status == "PASS"
            push!(verified, "operator.$(name).gauge")
        else
            push!(unverified, "operator.$(name).gauge")
            push!(reasons, "OPERATOR_GAUGE_UNVERIFIED")
        end

        target_gauge = _response_qualification_entry(record, "target_band_gauge", nothing)
        _response_qualification_recorded(target_gauge) && push!(target_gauges, String(target_gauge))
        transform = _response_qualification_entry(record, "band_frame_transform_sha256", nothing)
        contract = _response_qualification_entry(record, "band_frame_contract_sha256", nothing)
        authority =
            _response_qualification_entry(record, "authoritative_hamiltonian_digest", nothing)
        _response_qualification_sha256(manifest.band_frame_transform_sha256) &&
            _response_qualification_sha256(transform) &&
            manifest.band_frame_transform_sha256 != String(transform) &&
            push!(conflicts, "operator.$(name).band_frame_transform_sha256")
        _response_qualification_sha256(manifest.band_frame_contract_sha256) &&
            _response_qualification_sha256(contract) &&
            manifest.band_frame_contract_sha256 != String(contract) &&
            push!(conflicts, "operator.$(name).band_frame_contract_sha256")
        _response_qualification_sha256(manifest.authoritative_hamiltonian_sha256) &&
            _response_qualification_sha256(authority) &&
            manifest.authoritative_hamiltonian_sha256 != String(authority) &&
            push!(conflicts, "operator.$(name).authoritative_hamiltonian_sha256")
    end
    length(unique(target_gauges)) > 1 && push!(conflicts, "operators.common_target_band_gauge")
    isempty(conflicts) &&
        !isempty(target_gauges) &&
        push!(verified, "operators.common_target_band_gauge")
    return (;
        verified_contracts = verified,
        unverified_contracts = unverified,
        conflicting_contracts = conflicts,
        reasons,
    )
end

# Finalize the common missing-versus-conflict decision in one place for every driver.
function _finalize_response_qualification(
    input_production_eligible::Bool,
    input_quality_review_recommended::Bool,
    verified,
    unverified,
    conflicts,
    reasons,
    input,
)
    verified = _qualification_strings(verified)
    unverified = _qualification_strings(unverified)
    conflicts = _qualification_strings(conflicts)
    reasons = _qualification_strings(reasons)
    if !isempty(conflicts)
        push!(reasons, "CONFLICTING_CONTRACTS")
        result = ResponseQualificationResult(
            false,
            "DIAGNOSTIC_ONLY",
            false,
            true,
            reasons,
            verified,
            unverified,
            conflicts,
            input,
        )
        throw(ResponseQualificationError("RESPONSE_QUALIFICATION_CONFLICT", result))
    end
    production_eligible = input_production_eligible && isempty(unverified)
    status = production_eligible ? "PASS" : "DIAGNOSTIC_ONLY"
    return ResponseQualificationResult(
        true,
        status,
        production_eligible,
        !production_eligible || input_quality_review_recommended,
        reasons,
        verified,
        unverified,
        String[],
        input,
    )
end

"""
Evaluate task-specific response qualification after structural bundle validation and before
the numerical loop. Missing evidence degrades qualification; explicit common-contract
contradictions raise `RESPONSE_QUALIFICATION_CONFLICT`.
"""
function assess_response_qualification(
    manifest,
    ctx::RunContext,
    cfg::EffectiveTaskConfig,
    specs::Vector{NormalizedTaskSpec};
    response_symmetry_plan = nothing,
)
    verified = String["input.structure", "input.required_operators", "input.required_components"]
    unverified = String[]
    conflicts = String[]
    reasons = String[]
    input = _input_qualification_summary(manifest, ctx.model_input_mode)

    if manifest === nothing
        push!(unverified, "input.bundle_qualification")
        push!(reasons, "LEGACY_INPUT_QUALIFICATION_NOT_RECORDED")
    else
        generic = _generic_operator_contract_assessment(manifest, ctx.operator_demand)
        append!(verified, generic.verified_contracts)
        append!(unverified, generic.unverified_contracts)
        append!(conflicts, generic.conflicting_contracts)
        append!(reasons, generic.reasons)
        if manifest.production_eligible
            push!(verified, "input.bundle_production_eligibility")
        else
            push!(unverified, "input.bundle_production_eligibility")
            push!(reasons, "INPUT_BUNDLE_NOT_PRODUCTION_ELIGIBLE")
        end
        manifest.quality_review_recommended && push!(reasons, "INPUT_QUALITY_REVIEW_RECOMMENDED")
        construction_policy = String(
            _response_qualification_entry(
                manifest.operator_qualification,
                "construction_policy",
                "NOT_RECORDED",
            ),
        )
        if construction_policy == "standard"
            push!(unverified, "input.construction_policy")
            push!(reasons, "STANDARD_CONSTRUCTION_POLICY_DIAGNOSTIC")
        end
        if REAL_SPACE_SPIN in ctx.operator_demand.required_operators
            if manifest.spin_family_production_eligible
                push!(verified, "input.spin_family")
            else
                push!(unverified, "input.spin_family")
                push!(reasons, "SPIN_FAMILY_NOT_PRODUCTION_QUALIFIED")
            end
        end
        if canonical_operator_inventory(manifest.inventory) ==
           collect(OPERATOR_PROFILE_INVENTORIES[:full])
            if manifest.finite_band_galerkin_production_eligible
                push!(verified, "input.finite_band_galerkin")
            else
                push!(unverified, "input.finite_band_galerkin")
                push!(reasons, "FINITE_BAND_GALERKIN_NOT_PRODUCTION_QUALIFIED")
            end
        end
        if any(spec -> spec.quantity == :orbital_magnetization, specs) &&
           cfg.orbital_input_semantics != :defined_finite_model
            orbital = validate_orbital_sources(
                manifest,
                cfg.orbital_input_semantics,
                cfg.fermi_energies,
                cfg.temperature,
            )
            append!(verified, orbital.verified_contracts)
            append!(unverified, orbital.unverified_contracts)
            append!(conflicts, orbital.conflicting_contracts)
            append!(reasons, orbital.reasons)
        end
    end

    if response_symmetry_plan !== nothing
        if response_symmetry_plan.status == :PASS
            push!(verified, "response_symmetry.qualification")
        else
            push!(unverified, "response_symmetry.qualification")
            push!(reasons, "RESPONSE_SYMMETRY_QUALIFICATION_DIAGNOSTIC")
        end
    end

    return _finalize_response_qualification(
        manifest !== nothing && manifest.production_eligible,
        manifest === nothing || manifest.quality_review_recommended,
        verified,
        unverified,
        conflicts,
        reasons,
        input,
    )
end

"""Return a stable NamedTuple for metadata and structured progress output."""
function response_qualification_summary(result::ResponseQualificationResult)
    return (
        execution_eligible = result.execution_eligible,
        qualification_status = result.qualification_status,
        production_eligible = result.production_eligible,
        quality_review_recommended = result.quality_review_recommended,
        reasons = result.reasons,
        verified_contracts = result.verified_contracts,
        unverified_contracts = result.unverified_contracts,
        conflicting_contracts = result.conflicting_contracts,
        input_qualification = result.input_qualification,
    )
end
