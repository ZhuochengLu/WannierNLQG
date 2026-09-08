const TB_POSITION_COVARIANCE_THRESHOLD = 1.0e-5
const TB_WCC_ORBIT_THRESHOLD_ANGSTROM = 1.0e-5
const TB_HAMILTONIAN_HERMITICITY_THRESHOLD_EV = 1.0e-10
const TB_POSITION_HERMITICITY_THRESHOLD_ANGSTROM = 1.0e-10
const TB_KSTAR_THRESHOLD_EV = 1.0e-8
const TB_HAMILTONIAN_IDEMPOTENCE_THRESHOLD_EV = 1.0e-10
const TB_POSITION_IDEMPOTENCE_THRESHOLD_ANGSTROM = 1.0e-9

const TB_SYMMETRY_REQUIRED_METRICS = (
    "hamiltonian_covariance_relative_max",
    "centerless_position_covariance_relative_max",
    "wcc_symmetry_orbit_residual_angstrom",
    "hamiltonian_hermiticity_max_ev",
    "position_hermiticity_max_angstrom",
    "kstar_spectral_residual_ev",
    "hamiltonian_projection_idempotence_max_ev",
    "centerless_position_projection_idempotence_max_angstrom",
)

# Construct one evaluated scalar against a threshold frozen before this run.
function _tb_symmetry_metric(name, value, threshold, convention)
    passed = Float64(value) <= Float64(threshold)
    return TBSymmetryMetric(
        name,
        value,
        threshold,
        passed ? "PASS" : "FAIL",
        "APPLICABLE",
        passed ? "WITHIN_PREDECLARED_THRESHOLD" : "EXCEEDS_PREDECLARED_THRESHOLD",
        convention,
    )
end

# Retain a required but unavailable scalar without manufacturing a value.
function _tb_symmetry_unavailable_metric(name, threshold, reason, convention; not_run = false)
    return TBSymmetryMetric(
        name,
        nothing,
        threshold,
        not_run ? "NOT_RUN" : "NOT_APPLICABLE",
        "NOT_APPLICABLE",
        reason,
        convention,
    )
end

# Preserve the authority/scope provenance even when no final TB exists.  These
# fields remain audit metadata only; NOT_RUN never becomes production eligible.
function _tb_symmetry_unavailable_metadata(input_summary)
    threshold = tryparse(Float64, get(input_summary, "target_leakage_threshold", "NOT_RECORDED"))
    return (
        authoritative_hamiltonian = get(input_summary, "authoritative_hamiltonian", "native_dft"),
        authoritative_hamiltonian_sha256 = get(
            input_summary,
            "authoritative_hamiltonian_sha256",
            "LEGACY_NATIVE_DFT",
        ),
        energy_shift_qualification = get(
            input_summary,
            "energy_shift_qualification",
            "legacy_energy_shift_hard_gate",
        ),
        maximum_energy_shift_audit_reference_ev = get(
            input_summary,
            "maximum_energy_shift_audit_reference_ev",
            "NOT_APPLICABLE",
        ),
        rms_energy_shift_audit_reference_ev = get(
            input_summary,
            "rms_energy_shift_audit_reference_ev",
            "NOT_APPLICABLE",
        ),
        target_energy_shift_audit_status = get(
            input_summary,
            "target_energy_shift_audit_status",
            "NOT_APPLICABLE",
        ),
        symmetrized_parent_energy_shift_audit_status = get(
            input_summary,
            "symmetrized_parent_energy_shift_audit_status",
            "NOT_APPLICABLE",
        ),
        residual_gate_phase = get(
            input_summary,
            "residual_gate_phase",
            "legacy_pre_symmetrization",
        ),
        raw_preflight_diagnostic_status = get(
            input_summary,
            "raw_preflight_diagnostic_status",
            "NOT_APPLICABLE",
        ),
        native_difference_qualification = get(
            input_summary,
            "native_difference_qualification",
            "legacy_hard_gate",
        ),
        native_difference_audit_status = get(
            input_summary,
            "native_difference_audit_status",
            "NOT_APPLICABLE",
        ),
        qualification_scope = get(input_summary, "qualification_scope", "full_parent"),
        target_anchor = get(input_summary, "target_anchor", "NOT_APPLICABLE"),
        target_complement_completion = get(
            input_summary,
            "target_complement_completion",
            "NOT_APPLICABLE",
        ),
        target_complement_max_element_ev = get(
            input_summary,
            "target_complement_max_element_ev",
            "NOT_APPLICABLE",
        ),
        auxiliary_parent_qualification = get(
            input_summary,
            "auxiliary_parent_qualification",
            "legacy_hard_gate",
        ),
        symmetrized_target_subspace_status = get(
            input_summary,
            "symmetrized_target_subspace_status",
            "NOT_APPLICABLE",
        ),
        auxiliary_parent_audit_status = get(
            input_summary,
            "auxiliary_parent_audit_status",
            "NOT_APPLICABLE",
        ),
        target_scope_production_eligible = false,
        target_leakage_semantics = get(input_summary, "target_leakage_semantics", "NOT_APPLICABLE"),
        target_leakage_formula_sha256 = get(
            input_summary,
            "target_leakage_formula_sha256",
            "NOT_RECORDED",
        ),
        target_leakage_threshold = threshold,
        scoped_production_eligible = false,
        global_production_eligible = false,
    )
end

# Build the complete metric inventory for a run where no final TB exists.
function _tb_symmetry_unavailable(
    reason::AbstractString,
    hamiltonian_covariance_threshold;
    input_summary = Dict{String, String}(),
)
    thresholds = (
        hamiltonian_covariance_threshold,
        TB_POSITION_COVARIANCE_THRESHOLD,
        TB_WCC_ORBIT_THRESHOLD_ANGSTROM,
        TB_HAMILTONIAN_HERMITICITY_THRESHOLD_EV,
        TB_POSITION_HERMITICITY_THRESHOLD_ANGSTROM,
        TB_KSTAR_THRESHOLD_EV,
        TB_HAMILTONIAN_IDEMPOTENCE_THRESHOLD_EV,
        TB_POSITION_IDEMPOTENCE_THRESHOLD_ANGSTROM,
    )
    conventions = (
        "relative max of the normalized real-space Hamiltonian covariance residual",
        "relative max after removing delta_mn delta_R0 tau_n from normalized position",
        "minimum-image Cartesian residual of every supported Wannier-center orbit",
        "max_R norm(H(R)-H(-R)^dagger) in the normalized TB convention",
        "max_R,alpha norm(r_alpha(R)-r_alpha(-R)^dagger) after TB normalization",
        "maximum sorted-eigenvalue residual over the complete representation k-star",
        "max absolute difference P(P(H))-P(H) on union real-space support",
        "max absolute difference P(P(r_tilde))-P(r_tilde) on union support",
    )
    metrics = TBSymmetryMetric[
        _tb_symmetry_unavailable_metric(name, threshold, reason, convention; not_run = true) for
        (name, threshold, convention) in zip(TB_SYMMETRY_REQUIRED_METRICS, thresholds, conventions)
    ]
    return TBSymmetryQualification(
        "NOT_RUN",
        reason,
        metrics;
        _tb_symmetry_unavailable_metadata(input_summary)...,
    )
end

# Preserve a final TB while hard-blocking production after an evaluation failure.
function _tb_symmetry_incomplete(
    reason::AbstractString,
    hamiltonian_covariance_threshold;
    input_summary = Dict{String, String}(),
)
    unavailable = _tb_symmetry_unavailable(reason, hamiltonian_covariance_threshold; input_summary)
    metrics = TBSymmetryMetric[
        TBSymmetryMetric(
            metric.name,
            nothing,
            metric.threshold,
            "NOT_APPLICABLE",
            "NOT_APPLICABLE",
            reason,
            metric.convention,
        ) for metric in unavailable.metrics
    ]
    return TBSymmetryQualification(
        "INCOMPLETE",
        reason,
        metrics;
        _tb_symmetry_unavailable_metadata(input_summary)...,
    )
end

# Convert one qualification to the shared JSON/HDF5 logical payload.
function _tb_symmetry_payload(qualification::TBSymmetryQualification)
    metrics = Dict{String, Any}()
    for metric in qualification.metrics
        metrics[metric.name] = Dict(
            "value" => metric.value,
            "threshold" => metric.threshold,
            "status" => metric.status,
            "applicability" => metric.applicability,
            "reason" => metric.reason,
            "convention" => metric.convention,
        )
    end
    return Dict(
        "schema" => TB_SYMMETRY_QUALIFICATION_SCHEMA,
        "schema_version" => qualification.schema_version,
        "overall" => qualification.overall,
        "reason" => qualification.reason,
        "metrics" => metrics,
        "payload_sha256" => qualification.payload_sha256,
        "digest_convention" =>
            qualification.schema_version == "1.7" ? "typed-scalar-records-v2" :
            "typed-scalar-records-v1",
        "authoritative_hamiltonian" => qualification.authoritative_hamiltonian,
        "authoritative_hamiltonian_sha256" => qualification.authoritative_hamiltonian_sha256,
        "energy_shift_qualification" => qualification.energy_shift_qualification,
        "maximum_energy_shift_audit_reference_ev" =>
            qualification.maximum_energy_shift_audit_reference_ev,
        "rms_energy_shift_audit_reference_ev" => qualification.rms_energy_shift_audit_reference_ev,
        "target_energy_shift_audit_status" => qualification.target_energy_shift_audit_status,
        "symmetrized_parent_energy_shift_audit_status" =>
            qualification.symmetrized_parent_energy_shift_audit_status,
        "residual_gate_phase" => qualification.residual_gate_phase,
        "raw_preflight_diagnostic_status" => qualification.raw_preflight_diagnostic_status,
        "native_difference_qualification" => qualification.native_difference_qualification,
        "native_difference_audit_status" => qualification.native_difference_audit_status,
        "qualification_scope" => qualification.qualification_scope,
        "target_anchor" => qualification.target_anchor,
        "target_complement_completion" => qualification.target_complement_completion,
        "target_complement_max_element_ev" => qualification.target_complement_max_element_ev,
        "auxiliary_parent_qualification" => qualification.auxiliary_parent_qualification,
        "symmetrized_target_subspace_status" => qualification.symmetrized_target_subspace_status,
        "auxiliary_parent_audit_status" => qualification.auxiliary_parent_audit_status,
        "target_scope_production_eligible" => qualification.target_scope_production_eligible,
        "target_leakage_semantics" => qualification.target_leakage_semantics,
        "target_leakage_formula_sha256" => qualification.target_leakage_formula_sha256,
        "target_leakage_threshold" => qualification.target_leakage_threshold,
        "scoped_production_eligible" => qualification.scoped_production_eligible,
        "global_production_eligible" => qualification.global_production_eligible,
    )
end

# Persist the typed payload below an HDF5 root without serializer-dependent hashing.
function write_tb_symmetry_qualification_group(parent, qualification::TBSymmetryQualification)
    group = if haskey(parent, "tb_symmetry_qualification")
        parent["tb_symmetry_qualification"]
    else
        HDF5.create_group(parent, "tb_symmetry_qualification")
    end
    isempty(keys(group)) ||
        throw(ArgumentError("tb_symmetry_qualification group is already populated"))
    attributes = HDF5.attributes(group)
    isempty(keys(attributes)) ||
        throw(ArgumentError("tb_symmetry_qualification attributes are already populated"))
    attributes["schema"] = TB_SYMMETRY_QUALIFICATION_SCHEMA
    attributes["schema_version"] = qualification.schema_version
    attributes["overall"] = qualification.overall
    attributes["reason"] = qualification.reason
    attributes["payload_sha256"] = qualification.payload_sha256
    attributes["digest_convention"] =
        qualification.schema_version == "1.7" ? "typed-scalar-records-v2" :
        "typed-scalar-records-v1"
    attributes["authoritative_hamiltonian"] = qualification.authoritative_hamiltonian
    attributes["authoritative_hamiltonian_sha256"] = qualification.authoritative_hamiltonian_sha256
    attributes["energy_shift_qualification"] = qualification.energy_shift_qualification
    attributes["maximum_energy_shift_audit_reference_ev"] =
        qualification.maximum_energy_shift_audit_reference_ev
    attributes["rms_energy_shift_audit_reference_ev"] =
        qualification.rms_energy_shift_audit_reference_ev
    attributes["target_energy_shift_audit_status"] = qualification.target_energy_shift_audit_status
    attributes["symmetrized_parent_energy_shift_audit_status"] =
        qualification.symmetrized_parent_energy_shift_audit_status
    attributes["residual_gate_phase"] = qualification.residual_gate_phase
    attributes["raw_preflight_diagnostic_status"] = qualification.raw_preflight_diagnostic_status
    attributes["native_difference_qualification"] = qualification.native_difference_qualification
    attributes["native_difference_audit_status"] = qualification.native_difference_audit_status
    attributes["qualification_scope"] = qualification.qualification_scope
    attributes["target_anchor"] = qualification.target_anchor
    attributes["target_complement_completion"] = qualification.target_complement_completion
    attributes["target_complement_max_element_ev"] = qualification.target_complement_max_element_ev
    attributes["auxiliary_parent_qualification"] = qualification.auxiliary_parent_qualification
    attributes["symmetrized_target_subspace_status"] =
        qualification.symmetrized_target_subspace_status
    attributes["auxiliary_parent_audit_status"] = qualification.auxiliary_parent_audit_status
    attributes["target_scope_production_eligible"] = qualification.target_scope_production_eligible
    attributes["target_leakage_semantics"] = qualification.target_leakage_semantics
    attributes["target_leakage_formula_sha256"] = qualification.target_leakage_formula_sha256
    attributes["target_leakage_threshold"] = something(qualification.target_leakage_threshold, NaN)
    attributes["target_leakage_threshold_present"] =
        qualification.target_leakage_threshold !== nothing
    attributes["scoped_production_eligible"] = qualification.scoped_production_eligible
    attributes["global_production_eligible"] = false
    metrics = HDF5.create_group(group, "metrics")
    for metric in qualification.metrics
        item = HDF5.create_group(metrics, metric.name)
        item_attributes = HDF5.attributes(item)
        item_attributes["value"] = something(metric.value, NaN)
        item_attributes["value_present"] = metric.value !== nothing
        item_attributes["threshold"] = something(metric.threshold, NaN)
        item_attributes["threshold_present"] = metric.threshold !== nothing
        item_attributes["status"] = metric.status
        item_attributes["applicability"] = metric.applicability
        item_attributes["reason"] = metric.reason
        item_attributes["convention"] = metric.convention
    end
    return group
end

# Read and digest-validate one HDF5 payload, preserving legacy-file readability.
function read_tb_symmetry_qualification_group(parent; missing_reason = "LEGACY_SCHEMA_FIELD_ABSENT")
    haskey(parent, "tb_symmetry_qualification") || return tb_symmetry_not_run(missing_reason)
    group = parent["tb_symmetry_qualification"]
    attributes = HDF5.attributes(group)
    required = ("schema", "schema_version", "overall", "reason", "payload_sha256")
    all(name -> haskey(attributes, name), required) || return tb_symmetry_not_run(missing_reason)
    String(read(attributes["schema"])) == TB_SYMMETRY_QUALIFICATION_SCHEMA ||
        throw(ArgumentError("unsupported final TB symmetry qualification schema"))
    version = String(read(attributes["schema_version"]))
    version in
    ("1.0", "1.1", "1.2", "1.3", "1.4", "1.5", "1.6", TB_SYMMETRY_QUALIFICATION_SCHEMA_VERSION) ||
        throw(ArgumentError("unsupported final TB symmetry qualification schema version"))
    haskey(group, "metrics") ||
        throw(ArgumentError("final TB symmetry qualification omits metrics"))
    metrics = TBSymmetryMetric[]
    for name in sort!(String.(collect(keys(group["metrics"]))))
        item_attributes = HDF5.attributes(group["metrics/$(name)"])
        required_item = (
            "value",
            "value_present",
            "threshold",
            "threshold_present",
            "status",
            "applicability",
            "reason",
            "convention",
        )
        all(field -> haskey(item_attributes, field), required_item) ||
            throw(ArgumentError("final TB symmetry metric $(name) is incomplete"))
        value =
            Bool(read(item_attributes["value_present"])) ? Float64(read(item_attributes["value"])) :
            nothing
        threshold =
            Bool(read(item_attributes["threshold_present"])) ?
            Float64(read(item_attributes["threshold"])) : nothing
        push!(
            metrics,
            TBSymmetryMetric(
                name,
                value,
                threshold,
                String(read(item_attributes["status"])),
                String(read(item_attributes["applicability"])),
                String(read(item_attributes["reason"])),
                String(read(item_attributes["convention"])),
            ),
        )
    end
    overall = String(read(attributes["overall"]))
    reason = String(read(attributes["reason"]))
    stored_digest = String(read(attributes["payload_sha256"]))
    if version == "1.0"
        legacy_digest = tb_symmetry_payload_sha256(overall, reason, metrics; schema_version = "1.0")
        stored_digest == legacy_digest ||
            throw(ArgumentError("final TB symmetry payload SHA-256 mismatch"))
        return TBSymmetryQualification(overall, reason, metrics; schema_version = version)
    end
    authority = String(required_attribute(group, "authoritative_hamiltonian"))
    validate_persisted_authority_key(authority)
    authority_sha = String(required_attribute(group, "authoritative_hamiltonian_sha256"))
    scoped = Bool(required_attribute(group, "scoped_production_eligible"))
    Bool(required_attribute(group, "global_production_eligible")) == false ||
        throw(ArgumentError("TB qualification cannot assert global production eligibility"))
    energy_shift_qualification =
        version in ("1.2", "1.3", "1.4", "1.5", "1.6", "1.7") ?
        String(required_attribute(group, "energy_shift_qualification")) :
        "legacy_energy_shift_hard_gate"
    maximum_energy_shift_audit_reference_ev =
        version in ("1.2", "1.3", "1.4", "1.5", "1.6", "1.7") ?
        String(required_attribute(group, "maximum_energy_shift_audit_reference_ev")) :
        "NOT_APPLICABLE"
    rms_energy_shift_audit_reference_ev =
        version in ("1.2", "1.3", "1.4", "1.5", "1.6", "1.7") ?
        String(required_attribute(group, "rms_energy_shift_audit_reference_ev")) : "NOT_APPLICABLE"
    target_energy_shift_audit_status =
        version in ("1.2", "1.3", "1.4", "1.5", "1.6", "1.7") ?
        String(required_attribute(group, "target_energy_shift_audit_status")) : "NOT_APPLICABLE"
    symmetrized_parent_energy_shift_audit_status =
        version in ("1.2", "1.3", "1.4", "1.5", "1.6", "1.7") ?
        String(required_attribute(group, "symmetrized_parent_energy_shift_audit_status")) :
        "NOT_APPLICABLE"
    residual_gate_phase =
        version in ("1.3", "1.4", "1.5", "1.6", "1.7") ?
        String(required_attribute(group, "residual_gate_phase")) : "legacy_pre_symmetrization"
    raw_preflight_diagnostic_status =
        version in ("1.3", "1.4", "1.5", "1.6", "1.7") ?
        String(required_attribute(group, "raw_preflight_diagnostic_status")) : "NOT_APPLICABLE"
    native_difference_qualification =
        version in ("1.4", "1.5", "1.6", "1.7") ?
        String(required_attribute(group, "native_difference_qualification")) : "legacy_hard_gate"
    native_difference_audit_status =
        version in ("1.4", "1.5", "1.6", "1.7") ?
        String(required_attribute(group, "native_difference_audit_status")) : "NOT_APPLICABLE"
    qualification_scope =
        version in ("1.5", "1.6", "1.7") ?
        String(required_attribute(group, "qualification_scope")) : "full_parent"
    target_anchor =
        version in ("1.5", "1.6", "1.7") ? String(required_attribute(group, "target_anchor")) :
        "NOT_APPLICABLE"
    target_complement_completion =
        version in ("1.5", "1.6", "1.7") ?
        String(required_attribute(group, "target_complement_completion")) : "NOT_APPLICABLE"
    target_complement_max_element_ev =
        version in ("1.5", "1.6", "1.7") ?
        String(required_attribute(group, "target_complement_max_element_ev")) : "NOT_APPLICABLE"
    auxiliary_parent_qualification =
        version in ("1.5", "1.6", "1.7") ?
        String(required_attribute(group, "auxiliary_parent_qualification")) : "legacy_hard_gate"
    symmetrized_target_subspace_status =
        version in ("1.5", "1.6", "1.7") ?
        String(required_attribute(group, "symmetrized_target_subspace_status")) : "NOT_APPLICABLE"
    auxiliary_parent_audit_status =
        version in ("1.5", "1.6", "1.7") ?
        String(required_attribute(group, "auxiliary_parent_audit_status")) : "NOT_APPLICABLE"
    target_scope_production_eligible =
        version in ("1.5", "1.6", "1.7") ?
        Bool(required_attribute(group, "target_scope_production_eligible")) : false
    target_leakage_semantics =
        version == "1.7" ? String(required_attribute(group, "target_leakage_semantics")) :
        "LEGACY_AMPLITUDE_LEAKAGE_CONTRACT"
    target_leakage_formula_sha256 =
        version == "1.7" ? String(required_attribute(group, "target_leakage_formula_sha256")) :
        "NOT_RECORDED"
    target_leakage_threshold = if version == "1.7"
        Bool(required_attribute(group, "target_leakage_threshold_present")) ?
        Float64(required_attribute(group, "target_leakage_threshold")) : nothing
    else
        nothing
    end
    return TBSymmetryQualification(
        overall,
        reason,
        metrics;
        schema_version = version,
        payload_sha256 = stored_digest,
        authoritative_hamiltonian = authority,
        authoritative_hamiltonian_sha256 = authority_sha,
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
        target_leakage_threshold,
        scoped_production_eligible = scoped,
        global_production_eligible = false,
    )
end

# Atomically publish the canonical JSON sidecar.
function _write_tb_symmetry_json(filename, qualification::TBSymmetryQualification)
    path = abspath(filename)
    mkpath(dirname(path))
    temporary, io = mktemp(dirname(path); cleanup = false)
    completed = false
    try
        JSON3.write(io, _tb_symmetry_payload(qualification))
        write(io, '\n')
        close(io)
        mv(temporary, path; force = true)
        completed = true
    finally
        isopen(io) && close(io)
        !completed && isfile(temporary) && rm(temporary; force = true)
    end
    return path
end

# Divide serialized Wannier90 TB values by real-space degeneracy exactly once.
function _normalized_tb_operator(operator, degeneracies)
    values = copy(operator.data)
    length(degeneracies) == size(values, ndims(values)) ||
        throw(DimensionMismatch("TB degeneracy count disagrees with operator support"))
    for r_index in eachindex(degeneracies)
        selectdim(values, ndims(values), r_index) ./= degeneracies[r_index]
    end
    return Core.RealSpaceOperator(operator.spec, operator.r_vectors, values)
end

# Remove the affine WCC term from normalized Convention-II position data.
function _centerless_tb_position(position)
    home = findall(
        index -> all(iszero, @view(position.r_vectors[:, index])),
        axes(position.r_vectors, 2),
    )
    length(home) == 1 ||
        throw(ArgumentError("position operator must contain exactly one R=0 block"))
    home_index = only(home)
    values = copy(position.data)
    centers = zeros(Float64, size(values, 1), 3)
    for orbital in axes(values, 1), direction in 1:3
        center = values[orbital, orbital, direction, home_index]
        abs(imag(center)) <= 1.0e-10 ||
            throw(ArgumentError("Wannier center has a non-negligible imaginary part"))
        centers[orbital, direction] = real(center)
        values[orbital, orbital, direction, home_index] -= center
    end
    return Core.RealSpaceOperator(position.spec, position.r_vectors, values), centers
end

# Return the residual and explicit count of missing -R partners.
function _qualification_hermiticity_error(operator)
    indices =
        Dict(Tuple(operator.r_vectors[:, index]) => index for index in axes(operator.r_vectors, 2))
    maximum_error = 0.0
    missing_partners = 0
    for index in axes(operator.r_vectors, 2)
        partner = get(indices, Tuple(-operator.r_vectors[:, index]), 0)
        if partner == 0
            missing_partners += 1
            continue
        end
        if operator.spec.cartesian_rank == 0
            maximum_error = max(
                maximum_error,
                maximum(
                    abs,
                    @view(operator.data[:, :, index]) - @view(operator.data[:, :, partner])';
                    init = 0.0,
                ),
            )
        else
            for direction in 1:3
                maximum_error = max(
                    maximum_error,
                    maximum(
                        abs,
                        @view(operator.data[:, :, direction, index]) -
                        @view(operator.data[:, :, direction, partner])';
                        init = 0.0,
                    ),
                )
            end
        end
    end
    return maximum_error, missing_partners
end

# Fail Hermiticity on either numerical mismatch or incomplete R/-R support.
function _qualification_hermiticity_metric(name, operator, threshold, convention)
    value, missing_partners = _qualification_hermiticity_error(operator)
    missing_partners == 0 && return _tb_symmetry_metric(name, value, threshold, convention)
    return TBSymmetryMetric(
        name,
        value,
        threshold,
        "FAIL",
        "APPLICABLE",
        "MISSING_R_MINUS_R_PARTNERS:$(missing_partners)",
        convention,
    )
end

# Compare two operators on the exact union of their real-space support.
function _qualification_operator_difference(left, right)
    left_indices =
        Dict(Tuple(left.r_vectors[:, index]) => index for index in axes(left.r_vectors, 2))
    right_indices =
        Dict(Tuple(right.r_vectors[:, index]) => index for index in axes(right.r_vectors, 2))
    zero_block = zeros(ComplexF64, Base.front(size(left.data)))
    maximum_difference = 0.0
    for vector in union(keys(left_indices), keys(right_indices))
        left_index = get(left_indices, vector, 0)
        right_index = get(right_indices, vector, 0)
        left_block =
            left_index == 0 ? zero_block : selectdim(left.data, ndims(left.data), left_index)
        right_block =
            right_index == 0 ? zero_block : selectdim(right.data, ndims(right.data), right_index)
        maximum_difference =
            max(maximum_difference, maximum(abs, left_block .- right_block; init = 0.0))
    end
    return maximum_difference
end

# Measure idempotence of the established group projector, not input covariance.
function _qualification_projection_idempotence(operator, plan)
    projected = SymmetryFoundation.symmetrize_real_space_operator(operator, plan).operator
    repeated = SymmetryFoundation.symmetrize_real_space_operator(projected, plan).operator
    return _qualification_operator_difference(projected, repeated)
end

# Require an operation beyond the identity-only qualification placeholder.
function _nontrivial_wannier_symmetry_plan(plan)
    identity_rotation = Matrix{Int}(I, 3, 3)
    identity_representation = Matrix{ComplexF64}(
        I,
        size(plan.representation_matrices, 1),
        size(plan.representation_matrices, 2),
    )
    for operation_index in plan.operation_indices
        operation = plan.operations[operation_index]
        operation.antiunitary && return true
        operation.rotation_fractional != identity_rotation && return true
        maximum(abs, operation.translation_fractional; init = 0.0) > plan.tolerance && return true
        maximum(
            abs,
            @view(plan.representation_matrices[:, :, operation_index]) - identity_representation;
            init = 0.0,
        ) > plan.tolerance && return true
        maximum(abs, @view(plan.wannier_shifts[:, :, operation_index]); init = 0) > 0 && return true
    end
    return false
end

# Evaluate minimum-image WCC mapping for every supported representation entry.
function _qualification_wcc_residual(centers, lattice, plan)
    fractional = centers * inv(lattice)
    residual = 0.0
    support_count = 0
    for operation_index in plan.operation_indices
        operation = plan.operations[operation_index]
        representation = @view plan.representation_matrices[:, :, operation_index]
        for source in axes(representation, 2), target in axes(representation, 1)
            abs(representation[target, source]) > plan.tolerance || continue
            mapped =
                operation.rotation_fractional * vec(fractional[source, :]) .+
                operation.translation_fractional
            delta = mapped .- vec(fractional[target, :])
            delta .-= round.(delta)
            residual = max(residual, norm(transpose(delta) * lattice))
            support_count += 1
        end
    end
    support_count > 0 || throw(ArgumentError("symmetry plan has no supported WCC mapping"))
    return residual
end

# Interpolate final-TB eigenvalues and compare every mapped k point.
function _qualification_kstar_residual(hamiltonian, degeneracies, representation)
    nk = size(representation.kpoints_fractional, 1)
    size(representation.kpoint_map, 2) == nk ||
        throw(DimensionMismatch("representation k-point map is incomplete"))
    spectra = zeros(Float64, size(hamiltonian.data, 1), nk)
    for kpoint in 1:nk
        matrix = zeros(ComplexF64, size(hamiltonian.data, 1), size(hamiltonian.data, 2))
        for r_index in axes(hamiltonian.r_vectors, 2)
            phase = cis(
                2.0pi * dot(
                    @view(representation.kpoints_fractional[kpoint, :]),
                    @view(hamiltonian.r_vectors[:, r_index]),
                ),
            )
            @views matrix .+= phase .* hamiltonian.data[:, :, r_index]
        end
        spectra[:, kpoint] .= eigvals(Hermitian(0.5 .* (matrix + matrix')))
    end
    residual = 0.0
    for operation in axes(representation.kpoint_map, 1), kpoint in 1:nk
        mapped = representation.kpoint_map[operation, kpoint]
        1 <= mapped <= nk || throw(ArgumentError("representation k-point map is out of range"))
        residual = max(
            residual,
            maximum(abs, @view(spectra[:, kpoint]) - @view(spectra[:, mapped]); init = 0.0),
        )
    end
    return residual
end

# Derive the fixed overall status without allowing partial passes to mask failures.
function _final_tb_symmetry_overall(metrics)
    failed = sort!([metric.name for metric in metrics if metric.status == "FAIL"])
    isempty(failed) || return "FAIL", "FAILED_METRICS:" * join(failed, ",")
    incomplete = sort!([metric.name for metric in metrics if metric.status != "PASS"])
    isempty(incomplete) || return "INCOMPLETE", "MISSING_REQUIRED_METRICS:" * join(incomplete, ",")
    return "PASS", "ALL_REQUIRED_FINAL_TB_SYMMETRY_METRICS_PASS"
end

"""Resolve separately bound materialized-data, authority-contract, and gauge digests."""
function _tb_authority_identity(manifest)
    data_digest = manifest.authoritative_hamiltonian_sha256
    qualification = manifest.operator_qualification
    qualification isa AbstractDict ||
        return (; data_digest, contract_digest = data_digest, gauge_digest = nothing)
    operators = get(qualification, "operators", nothing)
    operators isa AbstractDict ||
        return (; data_digest, contract_digest = data_digest, gauge_digest = nothing)
    record = get(operators, "hamiltonian", nothing)
    record isa AbstractDict ||
        return (; data_digest, contract_digest = data_digest, gauge_digest = nothing)
    String(get(record, "qualification", "NOT_RECORDED")) == "NOT_RECORDED" &&
        return (; data_digest, contract_digest = data_digest, gauge_digest = nothing)

    String(get(record, "authoritative_hamiltonian", "NOT_RECORDED")) ==
    manifest.authoritative_hamiltonian || throw(
        ArgumentError(
            "HAMILTONIAN_REFERENCE_MISMATCH: TB root and Hamiltonian qualification authorities differ",
        ),
    )
    String(get(record, "authoritative_hamiltonian_digest", "NOT_RECORDED")) == data_digest || throw(
        ArgumentError(
            "HAMILTONIAN_REFERENCE_MISMATCH: TB root and Hamiltonian qualification data digests differ",
        ),
    )
    input_hashes = get(record, "authoritative_hamiltonian_input_sha256", nothing)
    input_hashes isa AbstractDict || throw(
        ArgumentError(
            "HAMILTONIAN_REFERENCE_MISMATCH: Hamiltonian qualification input digests are missing",
        ),
    )
    contract_digest = String(get(input_hashes, "AUTHORITATIVE_HAMILTONIAN_SHA256", ""))
    occursin(r"^[0-9a-f]{64}$", contract_digest) || throw(
        ArgumentError(
            "HAMILTONIAN_REFERENCE_MISMATCH: Hamiltonian authority contract digest is missing or invalid",
        ),
    )
    raw_gauge_digest = get(input_hashes, "WAVEFUNCTION_GAUGE_HDF5", nothing)
    gauge_digest = raw_gauge_digest === nothing ? nothing : String(raw_gauge_digest)
    gauge_digest === nothing ||
        occursin(r"^[0-9a-f]{64}$", gauge_digest) ||
        throw(
            ArgumentError(
                "HAMILTONIAN_REFERENCE_MISMATCH: Hamiltonian gauge-artifact digest is invalid",
            ),
        )
    return (; data_digest, contract_digest, gauge_digest)
end

"""Qualify one final Packed-HDF5 SAWF TB and optionally seal HDF5/JSON payloads."""
function qualify_exported_wannierization_tb(
    packed_hdf5::AbstractString,
    representation::Union{Nothing, BandRepresentation},
    plan::Union{Nothing, WannierSymmetryPlan};
    hamiltonian_covariance_threshold::Union{Nothing, Real},
    position_covariance_threshold::Real = TB_POSITION_COVARIANCE_THRESHOLD,
    wcc_threshold_angstrom::Real = TB_WCC_ORBIT_THRESHOLD_ANGSTROM,
    hamiltonian_hermiticity_threshold_ev::Real = TB_HAMILTONIAN_HERMITICITY_THRESHOLD_EV,
    position_hermiticity_threshold_angstrom::Real = TB_POSITION_HERMITICITY_THRESHOLD_ANGSTROM,
    kstar_threshold_ev::Real = TB_KSTAR_THRESHOLD_EV,
    hamiltonian_idempotence_threshold_ev::Real = TB_HAMILTONIAN_IDEMPOTENCE_THRESHOLD_EV,
    position_idempotence_threshold_angstrom::Real = TB_POSITION_IDEMPOTENCE_THRESHOLD_ANGSTROM,
    json_file::Union{Nothing, AbstractString} = nothing,
    persist_hdf5::Bool = true,
)
    thresholds = Float64[
        value for value in (
            position_covariance_threshold,
            wcc_threshold_angstrom,
            hamiltonian_hermiticity_threshold_ev,
            position_hermiticity_threshold_angstrom,
            kstar_threshold_ev,
            hamiltonian_idempotence_threshold_ev,
            position_idempotence_threshold_angstrom,
        )
    ]
    all(value -> isfinite(value) && value >= 0.0, thresholds) ||
        throw(ArgumentError("final TB symmetry thresholds must be finite and nonnegative"))
    h_threshold =
        hamiltonian_covariance_threshold === nothing ? nothing :
        Float64(hamiltonian_covariance_threshold)
    h_threshold === nothing ||
        (isfinite(h_threshold) && h_threshold >= 0.0) ||
        throw(ArgumentError("Hamiltonian covariance threshold must be finite and nonnegative"))
    if !isfile(packed_hdf5)
        qualification = _tb_symmetry_unavailable("TB_NOT_AVAILABLE", h_threshold)
        json_file === nothing || _write_tb_symmetry_json(json_file, qualification)
        return qualification
    end

    loaded = IO.read_real_space_operator_bundle(packed_hdf5)
    authority = loaded.manifest.authoritative_hamiltonian
    authority_sha = loaded.manifest.authoritative_hamiltonian_sha256
    authority_identity = _tb_authority_identity(loaded.manifest)
    if representation !== nothing
        get(representation.conventions, "authoritative_hamiltonian", "native_dft") == authority ||
            throw(
                ArgumentError(
                    "HAMILTONIAN_REFERENCE_MISMATCH: TB and representation authorities differ",
                ),
            )
        get(representation.conventions, "authoritative_hamiltonian_sha256", "LEGACY_NATIVE_DFT") ==
        authority_identity.contract_digest || throw(
            ArgumentError(
                "HAMILTONIAN_REFERENCE_MISMATCH: TB and representation authority contract digests differ",
            ),
        )
        if authority_identity.gauge_digest !== nothing
            get(representation.conventions, "wavefunction_gauge_hdf5_sha256", "NOT_RECORDED") ==
            something(authority_identity.gauge_digest) || throw(
                ArgumentError(
                    "HAMILTONIAN_REFERENCE_MISMATCH: TB and representation gauge-artifact digests differ",
                ),
            )
        end
        if loaded.manifest.qualification_scope == "target_subspace"
            for (key, bundle_value) in (
                ("target_leakage_semantics", loaded.manifest.target_leakage_semantics),
                ("target_leakage_formula_sha256", loaded.manifest.target_leakage_formula_sha256),
            )
                get(representation.conventions, key, "NOT_RECORDED") == bundle_value || throw(
                    ArgumentError(
                        "TARGET_SUBSPACE_CONTRACT_MISMATCH: TB and representation $(key) differ",
                    ),
                )
            end
            representation_threshold = tryparse(
                Float64,
                get(representation.conventions, "target_leakage_threshold", "NOT_RECORDED"),
            )
            representation_threshold == loaded.manifest.target_leakage_threshold || throw(
                ArgumentError(
                    "TARGET_SUBSPACE_CONTRACT_MISMATCH: TB and representation target_leakage_threshold differ",
                ),
            )
        end
    end
    operators = loaded.operators
    metrics = TBSymmetryMetric[]
    hamiltonian =
        haskey(operators, Core.REAL_SPACE_HAMILTONIAN) ?
        _normalized_tb_operator(operators[Core.REAL_SPACE_HAMILTONIAN], loaded.degeneracies) :
        nothing
    position =
        haskey(operators, Core.REAL_SPACE_POSITION) ?
        _normalized_tb_operator(operators[Core.REAL_SPACE_POSITION], loaded.degeneracies) : nothing
    centerless_position = nothing
    centers = nothing
    if position !== nothing
        centerless_position, centers = _centerless_tb_position(position)
    end
    nontrivial_plan = plan !== nothing && _nontrivial_wannier_symmetry_plan(plan)

    h_covariance_convention = "relative maximum_real_space_covariance_error on H(R)/degeneracy"
    if hamiltonian === nothing
        push!(
            metrics,
            _tb_symmetry_unavailable_metric(
                TB_SYMMETRY_REQUIRED_METRICS[1],
                h_threshold,
                "HAMILTONIAN_NOT_AVAILABLE",
                h_covariance_convention,
            ),
        )
    elseif plan === nothing
        push!(
            metrics,
            _tb_symmetry_unavailable_metric(
                TB_SYMMETRY_REQUIRED_METRICS[1],
                h_threshold,
                "WANNIER_SYMMETRY_PLAN_NOT_AVAILABLE",
                h_covariance_convention,
            ),
        )
    elseif !nontrivial_plan
        push!(
            metrics,
            _tb_symmetry_unavailable_metric(
                TB_SYMMETRY_REQUIRED_METRICS[1],
                h_threshold,
                "NONTRIVIAL_SYMMETRY_PLAN_NOT_AVAILABLE",
                h_covariance_convention,
            ),
        )
    elseif h_threshold === nothing
        push!(
            metrics,
            _tb_symmetry_unavailable_metric(
                TB_SYMMETRY_REQUIRED_METRICS[1],
                nothing,
                "HAMILTONIAN_COVARIANCE_THRESHOLD_UNDECLARED",
                h_covariance_convention,
            ),
        )
    else
        absolute = SymmetryFoundation.maximum_real_space_covariance_error(hamiltonian, plan)
        relative = absolute / max(maximum(abs, hamiltonian.data; init = 0.0), eps(Float64))
        push!(
            metrics,
            _tb_symmetry_metric(
                TB_SYMMETRY_REQUIRED_METRICS[1],
                relative,
                h_threshold,
                h_covariance_convention,
            ),
        )
    end

    position_covariance_convention = "r_tilde_mn,alpha(R)=r_mn,alpha(R)-delta_mn delta_R0 tau_n,alpha; normalized by degeneracy"
    if centerless_position === nothing
        push!(
            metrics,
            _tb_symmetry_unavailable_metric(
                TB_SYMMETRY_REQUIRED_METRICS[2],
                position_covariance_threshold,
                "POSITION_NOT_AVAILABLE",
                position_covariance_convention,
            ),
        )
    elseif !nontrivial_plan
        push!(
            metrics,
            _tb_symmetry_unavailable_metric(
                TB_SYMMETRY_REQUIRED_METRICS[2],
                position_covariance_threshold,
                plan === nothing ? "WANNIER_SYMMETRY_PLAN_NOT_AVAILABLE" :
                "NONTRIVIAL_SYMMETRY_PLAN_NOT_AVAILABLE",
                position_covariance_convention,
            ),
        )
    else
        absolute = SymmetryFoundation.maximum_real_space_covariance_error(centerless_position, plan)
        relative = absolute / max(maximum(abs, centerless_position.data; init = 0.0), eps(Float64))
        push!(
            metrics,
            _tb_symmetry_metric(
                TB_SYMMETRY_REQUIRED_METRICS[2],
                relative,
                position_covariance_threshold,
                position_covariance_convention,
            ),
        )
    end

    wcc_convention = "fractional q'=Wq+tau, supported Wannier representation entries, minimum-image Cartesian norm"
    if centers === nothing
        push!(
            metrics,
            _tb_symmetry_unavailable_metric(
                TB_SYMMETRY_REQUIRED_METRICS[3],
                wcc_threshold_angstrom,
                "WANNIER_CENTERS_NOT_AVAILABLE",
                wcc_convention,
            ),
        )
    elseif !nontrivial_plan
        push!(
            metrics,
            _tb_symmetry_unavailable_metric(
                TB_SYMMETRY_REQUIRED_METRICS[3],
                wcc_threshold_angstrom,
                plan === nothing ? "WANNIER_SYMMETRY_PLAN_NOT_AVAILABLE" :
                "NONTRIVIAL_SYMMETRY_PLAN_NOT_AVAILABLE",
                wcc_convention,
            ),
        )
    else
        push!(
            metrics,
            _tb_symmetry_metric(
                TB_SYMMETRY_REQUIRED_METRICS[3],
                _qualification_wcc_residual(centers, loaded.lattice, plan),
                wcc_threshold_angstrom,
                wcc_convention,
            ),
        )
    end

    h_hermiticity_convention = "max_R |H(R)-H(-R)^dagger| after degeneracy normalization"
    push!(
        metrics,
        hamiltonian === nothing ?
        _tb_symmetry_unavailable_metric(
            TB_SYMMETRY_REQUIRED_METRICS[4],
            hamiltonian_hermiticity_threshold_ev,
            "HAMILTONIAN_NOT_AVAILABLE",
            h_hermiticity_convention,
        ) :
        _qualification_hermiticity_metric(
            TB_SYMMETRY_REQUIRED_METRICS[4],
            hamiltonian,
            hamiltonian_hermiticity_threshold_ev,
            h_hermiticity_convention,
        ),
    )
    position_hermiticity_convention = "max_R,alpha |r_alpha(R)-r_alpha(-R)^dagger| after degeneracy normalization"
    push!(
        metrics,
        position === nothing ?
        _tb_symmetry_unavailable_metric(
            TB_SYMMETRY_REQUIRED_METRICS[5],
            position_hermiticity_threshold_angstrom,
            "POSITION_NOT_AVAILABLE",
            position_hermiticity_convention,
        ) :
        _qualification_hermiticity_metric(
            TB_SYMMETRY_REQUIRED_METRICS[5],
            position,
            position_hermiticity_threshold_angstrom,
            position_hermiticity_convention,
        ),
    )

    kstar_convention = "sorted eigenvalues of final normalized TB H(k) on representation kpoint_map"
    if hamiltonian === nothing
        push!(
            metrics,
            _tb_symmetry_unavailable_metric(
                TB_SYMMETRY_REQUIRED_METRICS[6],
                kstar_threshold_ev,
                "HAMILTONIAN_NOT_AVAILABLE",
                kstar_convention,
            ),
        )
    elseif representation === nothing
        push!(
            metrics,
            _tb_symmetry_unavailable_metric(
                TB_SYMMETRY_REQUIRED_METRICS[6],
                kstar_threshold_ev,
                "BAND_REPRESENTATION_NOT_AVAILABLE",
                kstar_convention,
            ),
        )
    else
        push!(
            metrics,
            _tb_symmetry_metric(
                TB_SYMMETRY_REQUIRED_METRICS[6],
                _qualification_kstar_residual(hamiltonian, loaded.degeneracies, representation),
                kstar_threshold_ev,
                kstar_convention,
            ),
        )
    end

    h_idempotence_convention = "maximum union-support absolute difference P(P(H))-P(H)"
    if hamiltonian === nothing || !nontrivial_plan
        reason =
            hamiltonian === nothing ? "HAMILTONIAN_NOT_AVAILABLE" :
            plan === nothing ? "WANNIER_SYMMETRY_PLAN_NOT_AVAILABLE" :
            "NONTRIVIAL_SYMMETRY_PLAN_NOT_AVAILABLE"
        push!(
            metrics,
            _tb_symmetry_unavailable_metric(
                TB_SYMMETRY_REQUIRED_METRICS[7],
                hamiltonian_idempotence_threshold_ev,
                reason,
                h_idempotence_convention,
            ),
        )
    else
        push!(
            metrics,
            _tb_symmetry_metric(
                TB_SYMMETRY_REQUIRED_METRICS[7],
                _qualification_projection_idempotence(hamiltonian, plan),
                hamiltonian_idempotence_threshold_ev,
                h_idempotence_convention,
            ),
        )
    end

    position_idempotence_convention = "maximum union-support absolute difference P(P(r_tilde))-P(r_tilde)"
    if centerless_position === nothing || !nontrivial_plan
        reason =
            centerless_position === nothing ? "POSITION_NOT_AVAILABLE" :
            plan === nothing ? "WANNIER_SYMMETRY_PLAN_NOT_AVAILABLE" :
            "NONTRIVIAL_SYMMETRY_PLAN_NOT_AVAILABLE"
        push!(
            metrics,
            _tb_symmetry_unavailable_metric(
                TB_SYMMETRY_REQUIRED_METRICS[8],
                position_idempotence_threshold_angstrom,
                reason,
                position_idempotence_convention,
            ),
        )
    else
        push!(
            metrics,
            _tb_symmetry_metric(
                TB_SYMMETRY_REQUIRED_METRICS[8],
                _qualification_projection_idempotence(centerless_position, plan),
                position_idempotence_threshold_angstrom,
                position_idempotence_convention,
            ),
        )
    end

    overall, reason = _final_tb_symmetry_overall(metrics)
    qualification = TBSymmetryQualification(
        overall,
        reason,
        metrics;
        authoritative_hamiltonian = authority,
        authoritative_hamiltonian_sha256 = authority_sha,
        energy_shift_qualification = loaded.manifest.energy_shift_qualification,
        maximum_energy_shift_audit_reference_ev = loaded.manifest.maximum_energy_shift_audit_reference_ev,
        rms_energy_shift_audit_reference_ev = loaded.manifest.rms_energy_shift_audit_reference_ev,
        target_energy_shift_audit_status = loaded.manifest.target_energy_shift_audit_status,
        symmetrized_parent_energy_shift_audit_status = loaded.manifest.symmetrized_parent_energy_shift_audit_status,
        residual_gate_phase = loaded.manifest.residual_gate_phase,
        raw_preflight_diagnostic_status = loaded.manifest.raw_preflight_diagnostic_status,
        native_difference_qualification = loaded.manifest.native_difference_qualification,
        native_difference_audit_status = loaded.manifest.native_difference_audit_status,
        qualification_scope = loaded.manifest.qualification_scope,
        target_anchor = loaded.manifest.target_anchor,
        target_complement_completion = loaded.manifest.target_complement_completion,
        target_complement_max_element_ev = loaded.manifest.target_complement_max_element_ev,
        auxiliary_parent_qualification = loaded.manifest.auxiliary_parent_qualification,
        symmetrized_target_subspace_status = loaded.manifest.symmetrized_target_subspace_status,
        auxiliary_parent_audit_status = loaded.manifest.auxiliary_parent_audit_status,
        target_scope_production_eligible = overall == "PASS" &&
                                           loaded.manifest.target_scope_production_eligible,
        target_leakage_semantics = loaded.manifest.target_leakage_semantics,
        target_leakage_formula_sha256 = loaded.manifest.target_leakage_formula_sha256,
        target_leakage_threshold = loaded.manifest.target_leakage_threshold,
        scoped_production_eligible = overall == "PASS" &&
                                     loaded.manifest.scoped_production_eligible,
        global_production_eligible = false,
    )
    if persist_hdf5
        HDF5.h5open(packed_hdf5, "r+") do handle
            write_tb_symmetry_qualification_group(handle, qualification)
        end
    end
    json_file === nothing || _write_tb_symmetry_json(json_file, qualification)
    return qualification
end
