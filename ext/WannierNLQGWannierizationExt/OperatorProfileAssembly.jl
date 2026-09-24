const WANNIER_OPERATOR_PROFILE_ASSEMBLY_ALGORITHM_VERSION = "schema-6.3-pair-wigner-seitz-spin-galerkin-risk-audited-profile-v5-source-neighbor-order"
const PROFILE_PAIR_WIGNER_SEITZ_SUPPORT_TOLERANCE = 1.0e-12
const PROFILE_PAIR_WIGNER_SEITZ_ROUNDTRIP_TOLERANCE = 1.0e-8
const PROFILE_PAIR_WIGNER_SEITZ_TRANSFORM_ALGORITHM = "PAIR_DEPENDENT_WIGNER_SEITZ_Q_TO_R"
const PROFILE_PAIR_WIGNER_SEITZ_STORAGE_POLICY = "PAIR_DEPENDENT_MINIMUM_DISTANCE_UNIT_DEGENERACY"

const OPERATOR_QUALIFICATION_SCHEMA = "wanniernlqg.operator-qualification"
const OPERATOR_QUALIFICATION_SCHEMA_VERSION = "1.3"
const FINAL_SUBSPACE_PROJECTOR_DIGEST_QUANTIZATION = 1.0e-12
const FINAL_SUBSPACE_PROJECTOR_DIGEST_ALGORITHM = "P=V*V_dagger;Hermitian-average;round(real,imag)/1e-12-to-Int64;column-major;kpoint-order"

"""Resolve the operator selection declared by one Wannierization output configuration."""
_resolved_operator_selection(config) =
    IO.resolve_operator_selection(config.output.profile, config.output.operator_tasks)

# Return true when the resolved selection needs one upstream source artifact.
_operator_selection_needs_source(selection, source::Symbol) =
    source in IO.resolved_source_inventory(selection)

# Return true when the resolved inventory is exactly the complete finite-band family.
_operator_selection_is_complete_family(selection) =
    IO.resolved_operator_inventory(selection) == collect(IO.OPERATOR_PROFILE_INVENTORIES[:full])

# Return true when a generated operator artifact beyond SPN is required.
function _operator_selection_requires_generated_operators(selection)
    sources = IO.resolved_source_inventory(selection)
    return any(source -> source in sources, (:uiu, :uhu, :siu, :shu))
end

# Return true when the resolved selection needs a qualified-source delivery contract.
_operator_selection_requires_target_contract(selection) =
    _operator_selection_needs_source(selection, :operator_target_contract)

# Bind the resolved selection identity into one String-valued checkpoint summary.
function _record_operator_selection_summary!(summary::AbstractDict, selection)
    IO.operator_selection_mode(selection) == :tasks || return summary
    summary["operator_selection_mode"] = String(IO.operator_selection_mode(selection))
    summary["operator_requirement_registry_version"] =
        String(IO.operator_selection_registry_version(selection))
    summary["resolved_operator_inventory"] =
        join(real_space_operator_name.(IO.resolved_operator_inventory(selection)), ",")
    summary["resolved_source_inventory"] =
        join(String.(IO.resolved_source_inventory(selection)), ",")
    digest = IO.operator_selection_sha256(selection)
    digest === nothing || (summary["operator_selection_sha256"] = String(digest))
    return summary
end

# Build the explicit no-SPN attestation used by selections without a spin source.
function _not_applicable_spn_attestation()
    return (
        spn_sha256 = "NOT_APPLICABLE",
        provenance_sha256 = "NOT_APPLICABLE",
        source_band_gauge = "NOT_APPLICABLE",
        qualification_target_band_gauge = "NOT_APPLICABLE",
        gauge_artifact_sha256 = "NOT_APPLICABLE",
        input_sha256 = Dict{String, String}(),
    )
end

"""Return an explicit no-transform contract for final-Wannier-gauge operators."""
function _not_applicable_profile_frame_contract()
    return Dict{String, Any}(
        "schema" => "NOT_APPLICABLE",
        "schema_version" => "NOT_APPLICABLE",
        "status" => "NOT_APPLICABLE",
        "legacy" => false,
        "source_band_gauge" => "final_wannier_gauge",
        "target_band_gauge" => "final_wannier_gauge",
        "transform_sha256" => "NOT_APPLICABLE",
        "contract_sha256" => "NOT_APPLICABLE",
        "gauge_artifact_sha256" => "NOT_APPLICABLE",
        "metric_kind" => "NOT_APPLICABLE",
        "physical_isometry_maximum" => NaN,
        "physical_isometry_tolerance" => NaN,
        "replay_maximum" => NaN,
        "replay_tolerance" => NaN,
        "euclidean_nonunitarity_maximum" => NaN,
        "minimum_singular_value" => NaN,
        "maximum_condition_number" => NaN,
    )
end

const _PROFILE_COMMON_SOURCE_EXCLUSIONS = Set(("ORACLE_MMN",))

"""Normalize a String- or Symbol-keyed frame-contract summary."""
function _profile_frame_contract_dictionary(raw)
    raw isa AbstractDict ||
        raw isa NamedTuple ||
        throw(ArgumentError("OPERATOR_PROVENANCE_MISMATCH: band-frame contract is missing"))
    return Dict{String, Any}(String(key) => value for (key, value) in pairs(raw))
end

"""Append a deterministic typed representation of qualification metadata."""
function _profile_qualification_digest_value!(buffer::Base.IO, value)
    if value isa AbstractDict || value isa NamedTuple
        write(buffer, UInt8('D'))
        for key in sort!(String.(collect(keys(value))))
            source_key = value isa NamedTuple ? Symbol(key) : key
            value isa AbstractDict && !haskey(value, source_key) && (source_key = Symbol(key))
            _profile_qualification_digest_value!(buffer, key)
            _profile_qualification_digest_value!(buffer, value[source_key])
        end
    elseif value isa AbstractArray
        write(buffer, UInt8('A'), Int64(ndims(value)))
        foreach(dimension -> write(buffer, Int64(dimension)), size(value))
        foreach(entry -> _profile_qualification_digest_value!(buffer, entry), value)
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
        throw(ArgumentError("unsupported profile-qualification value type $(typeof(value))"))
    end
    return nothing
end

"""Digest one per-operator qualification record without its self-seal field."""
function _profile_qualification_record_sha256(record)
    payload = Dict{String, Any}(
        String(key) => value for (key, value) in pairs(record) if String(key) != "payload_sha256"
    )
    buffer = IOBuffer()
    _profile_qualification_digest_value!(buffer, payload)
    return bytes2hex(SHA.sha256(take!(buffer)))
end

"""Normalize one generator input-hash map for strict source-chain comparisons."""
function _profile_input_hashes(raw, label::AbstractString)
    raw isa AbstractDict ||
        raw isa JSON3.Object ||
        throw(ArgumentError("OPERATOR_PROVENANCE_MISMATCH: $(label) input hashes are missing"))
    hashes = Dict{String, String}(String(key) => String(value) for (key, value) in pairs(raw))
    isempty(hashes) &&
        throw(ArgumentError("OPERATOR_PROVENANCE_MISMATCH: $(label) input hashes are empty"))
    return hashes
end

"""Require every non-special reference source hash in a generated sidecar."""
function _validate_profile_common_source_hashes(reference, candidate, label::AbstractString)
    required = sort!(collect(setdiff(keys(reference), _PROFILE_COMMON_SOURCE_EXCLUSIONS)))
    isempty(required) && throw(
        ArgumentError("OPERATOR_PROVENANCE_MISMATCH: uIu has no common physical-source hashes"),
    )
    for key in required
        get(candidate, key, "MISSING") == reference[key] || throw(
            ArgumentError(
                "OPERATOR_PROVENANCE_MISMATCH: $(label) common source hash $(key) differs",
            ),
        )
    end
    return nothing
end

"""Bind a spin-H sidecar to the exact SPN artifact, provenance, and shared source."""
function _validate_profile_spn_source_hashes(
    candidate,
    spn_input_sha256,
    spn_sha256::AbstractString,
    spn_provenance_sha256::AbstractString,
    label::AbstractString,
)
    get(candidate, "SPN", "MISSING") == spn_sha256 ||
        throw(ArgumentError("OPERATOR_PROVENANCE_MISMATCH: $(label) SPN hash differs"))
    get(candidate, "SPN_PROVENANCE", "MISSING") == spn_provenance_sha256 ||
        throw(ArgumentError("OPERATOR_PROVENANCE_MISMATCH: $(label) SPN provenance hash differs"))
    required = sort!(collect(keys(spn_input_sha256)))
    isempty(required) && throw(
        ArgumentError("OPERATOR_PROVENANCE_MISMATCH: SPN provenance has no physical-source hashes"),
    )
    for key in required
        get(candidate, key, "MISSING") == spn_input_sha256[key] || throw(
            ArgumentError("OPERATOR_PROVENANCE_MISMATCH: $(label) SPN source hash $(key) differs"),
        )
    end
    return nothing
end

"""Return the maximum element difference for two identically supported operators."""
function _profile_operator_maximum_difference(left::RealSpaceOperator, right::RealSpaceOperator)
    left.r_vectors == right.r_vectors || return Inf
    size(left.data) == size(right.data) || return Inf
    return maximum(abs, left.data .- right.data; init = 0.0)
end

"""Convert nested JSON metadata to deterministic String-keyed dictionaries."""
function _profile_normalize_metadata(value)
    if value isa AbstractDict || value isa NamedTuple
        return Dict{String, Any}(
            String(key) => _profile_normalize_metadata(entry) for (key, entry) in pairs(value)
        )
    elseif value isa AbstractArray
        return [_profile_normalize_metadata(entry) for entry in value]
    end
    return value
end

"""Hash the final subspace projectors after documented gauge-invariant quantization."""
function _profile_final_subspace_projector_digest(chk)
    v_matrix = chk.v_matrix
    size(v_matrix) == (chk.num_bands, chk.num_orbitals, chk.num_kpts) ||
        throw(ArgumentError("FINAL_SUBSPACE_PROJECTOR_DIMENSION_MISMATCH"))
    all(isfinite, v_matrix) || throw(ArgumentError("FINAL_SUBSPACE_PROJECTOR_NONFINITE"))
    buffer = IOBuffer()
    write(
        buffer,
        "WannierNLQG.final_subspace_projector/1.0\n",
        FINAL_SUBSPACE_PROJECTOR_DIGEST_ALGORITHM,
        '\n',
    )
    write(buffer, reinterpret(UInt8, Int64[chk.num_bands, chk.num_orbitals, chk.num_kpts]))
    write(buffer, reinterpret(UInt8, [FINAL_SUBSPACE_PROJECTOR_DIGEST_QUANTIZATION]))
    identity_wannier = Matrix{ComplexF64}(I, chk.num_orbitals, chk.num_orbitals)
    isometry_maximum = 0.0
    for kpoint in 1:chk.num_kpts
        gauge = @view v_matrix[:, :, kpoint]
        gram = gauge' * gauge
        isometry_maximum = max(isometry_maximum, maximum(abs, gram .- identity_wannier; init = 0.0))
        projector = gauge * gauge'
        projector .= (projector .+ projector') ./ 2
        all(isfinite, projector) || throw(ArgumentError("FINAL_SUBSPACE_PROJECTOR_NONFINITE"))
        for value in projector
            real_quantized =
                round(Int64, real(value) / FINAL_SUBSPACE_PROJECTOR_DIGEST_QUANTIZATION)
            imaginary_quantized =
                round(Int64, imag(value) / FINAL_SUBSPACE_PROJECTOR_DIGEST_QUANTIZATION)
            write(buffer, reinterpret(UInt8, [real_quantized, imaginary_quantized]))
        end
    end
    isfinite(isometry_maximum) || throw(ArgumentError("FINAL_SUBSPACE_PROJECTOR_NONFINITE"))
    return (
        sha256 = bytes2hex(SHA.sha256(take!(buffer))),
        quantization = FINAL_SUBSPACE_PROJECTOR_DIGEST_QUANTIZATION,
        algorithm = FINAL_SUBSPACE_PROJECTOR_DIGEST_ALGORITHM,
        isometry_maximum,
    )
end

"""
Audit physical-overlap contraction in the actual final Wannier subspace.

For every directed MMN link this evaluates
`V_left'*(I-M*M')*V_left` and `V_right'*(I-M'*M)*V_right`.  It is a risk
audit, not an NBANDS-convergence error bound.
"""
function _profile_final_projector_leakage_audit(chk, mmn, diagnostic_reference::Real)
    reference = Float64(diagnostic_reference)
    isfinite(reference) && reference > 0.0 ||
        throw(ArgumentError("FINAL_PROJECTOR_DIAGNOSTIC_REFERENCE_INVALID"))
    size(chk.v_matrix) == (chk.num_bands, chk.num_orbitals, chk.num_kpts) ||
        throw(ArgumentError("FINAL_SUBSPACE_PROJECTOR_DIMENSION_MISMATCH"))
    mmn.num_bands == chk.num_bands && mmn.num_kpts == chk.num_kpts ||
        throw(ArgumentError("FINAL_PROJECTOR_MMN_TOPOLOGY_MISMATCH"))
    size(mmn.data) == (chk.num_bands, chk.num_bands, mmn.num_neighbors, chk.num_kpts) ||
        throw(ArgumentError("FINAL_PROJECTOR_MMN_DIMENSION_MISMATCH"))
    size(mmn.neighbors) == (mmn.num_neighbors, chk.num_kpts) ||
        throw(ArgumentError("FINAL_PROJECTOR_MMN_TOPOLOGY_MISMATCH"))
    all(isfinite, chk.v_matrix) && all(isfinite, mmn.data) ||
        throw(ArgumentError("FINAL_PROJECTOR_INPUT_NONFINITE"))
    projector = _profile_final_subspace_projector_digest(chk)
    leakage_values = Float64[]
    leakage_maximum = -Inf
    negative_defect_maximum = 0.0
    contraction_excess_maximum = 0.0
    worst_link = Dict{String, Any}()
    worst_endpoint = "NOT_RUN"
    for kpoint in 1:chk.num_kpts, neighbor in 1:mmn.num_neighbors
        target = mmn.neighbors[neighbor, kpoint]
        target in 1:chk.num_kpts ||
            throw(ArgumentError("FINAL_PROJECTOR_MMN_NEIGHBOR_INDEX_INVALID"))
        left = @view chk.v_matrix[:, :, kpoint]
        right = @view chk.v_matrix[:, :, target]
        overlap = @view mmn.data[:, :, neighbor, kpoint]
        transported_left = overlap' * left
        transported_right = overlap * right
        left_defect = left' * left - transported_left' * transported_left
        right_defect = right' * right - transported_right' * transported_right
        for (endpoint, defect) in (("left", left_defect), ("right", right_defect))
            defect .= (defect .+ defect') ./ 2
            all(isfinite, defect) || throw(ArgumentError("FINAL_PROJECTOR_LINK_NONFINITE"))
            eigenvalues = eigvals(Hermitian(defect))
            all(isfinite, eigenvalues) || throw(ArgumentError("FINAL_PROJECTOR_LINK_NONFINITE"))
            endpoint_leakage = max(0.0, maximum(eigenvalues; init = 0.0))
            endpoint_negative = max(0.0, -minimum(eigenvalues; init = 0.0))
            push!(leakage_values, endpoint_leakage)
            if endpoint_leakage > leakage_maximum
                leakage_maximum = endpoint_leakage
                worst_link = Dict(
                    "center_kpoint" => kpoint,
                    "neighbor_slot" => neighbor,
                    "target_kpoint" => target,
                )
                worst_endpoint = endpoint
            end
            negative_defect_maximum = max(negative_defect_maximum, endpoint_negative)
            contraction_excess_maximum = max(contraction_excess_maximum, endpoint_negative)
        end
    end
    isempty(leakage_values) && throw(ArgumentError("FINAL_PROJECTOR_MMN_TOPOLOGY_EMPTY"))
    sorted_values = sort(copy(leakage_values))
    percentile_index = clamp(ceil(Int, 0.95 * length(sorted_values)), 1, length(sorted_values))
    leakage_p95 = sorted_values[percentile_index]
    leakage_rms = sqrt(sum(abs2, leakage_values) / length(leakage_values))
    all(
        isfinite,
        (
            leakage_maximum,
            leakage_p95,
            leakage_rms,
            negative_defect_maximum,
            contraction_excess_maximum,
        ),
    ) || throw(ArgumentError("FINAL_PROJECTOR_AUDIT_NONFINITE"))
    return Dict{String, Any}(
        "schema" => "WannierNLQG.final_subspace_projector_galerkin_audit",
        "schema_version" => "1.0",
        "qualification_stage" => "FINAL_WANNIER_SUBSPACE_ASSEMBLY",
        "semantics" => "directed_link_endpoint_defects=V_left_dagger*(I-M*M_dagger)*V_left_and_V_right_dagger*(I-M_dagger*M)*V_right",
        "status" => "RECORDED",
        "final_subspace_dimension" => chk.num_orbitals,
        "parent_band_dimension" => chk.num_bands,
        "directed_link_count" => chk.num_kpts * mmn.num_neighbors,
        "endpoint_count" => length(leakage_values),
        "final_subspace_projector_sha256" => projector.sha256,
        "projector_digest_algorithm" => projector.algorithm,
        "projector_digest_quantization" => projector.quantization,
        "projector_isometry_maximum" => projector.isometry_maximum,
        "leakage_maximum" => leakage_maximum,
        "leakage_p95" => leakage_p95,
        "leakage_rms" => leakage_rms,
        "diagnostic_reference" => reference,
        "diagnostic_reference_status" =>
            leakage_maximum <= reference ? "WITHIN_REFERENCE" : "ABOVE_REFERENCE",
        "worst_link" => worst_link,
        "worst_endpoint" => worst_endpoint,
        "negative_defect_maximum" => negative_defect_maximum,
        "contraction_excess_maximum" => contraction_excess_maximum,
        "actual_operator_error_status" => "NOT_AVAILABLE_WITHOUT_COMPLEMENT_HAMILTONIAN_OR_NBANDS_REFERENCE",
        "nbands_convergence_status" => "NOT_ESTABLISHED",
    )
end

"""Align a projected unit-degeneracy operator to the final TB support."""
function _align_profile_operator_support(operator::RealSpaceOperator, model; tolerance::Float64)
    target = Dict(Tuple(model.r_vectors[:, index]) => index for index in axes(model.r_vectors, 2))
    source =
        Dict(Tuple(operator.r_vectors[:, index]) => index for index in axes(operator.r_vectors, 2))
    for (key, index) in source
        haskey(target, key) && continue
        maximum(abs, selectdim(operator.data, ndims(operator.data), index); init = 0.0) <=
        tolerance || throw(
            ArgumentError(
                "SPIN_FAMILY_R_SUPPORT_MISMATCH: projected operator generated nonzero R=$(key)",
            ),
        )
    end
    shape = ntuple(
        axis ->
            axis == ndims(operator.data) ? size(model.r_vectors, 2) : size(operator.data, axis),
        ndims(operator.data),
    )
    aligned = zeros(ComplexF64, shape)
    for (key, target_index) in target
        source_index = get(source, key, 0)
        source_index == 0 && continue
        selectdim(aligned, ndims(aligned), target_index) .=
            selectdim(operator.data, ndims(operator.data), source_index)
    end
    return RealSpaceOperator(operator.spec, model.r_vectors, aligned)
end

"""Build the schema-6.3 finite-band Galerkin family qualification."""
function _profile_finite_band_galerkin_family(
    complete_family::Bool,
    final_audit,
    source_risk_audit,
    final_combination_cancellation_audit,
)
    if !complete_family
        return Dict{String, Any}(
            "route" => "not_applicable",
            "overall" => "NOT_APPLICABLE",
            "reason" => "PROFILE_HAS_NO_COMPLETE_FINITE_BAND_OPERATOR_FAMILY",
            "production_eligible" => false,
            "qualification_stage" => "NOT_APPLICABLE",
            "actual_operator_error_status" => "NOT_APPLICABLE",
            "nbands_convergence_status" => "NOT_APPLICABLE",
        )
    end
    final_audit isa AbstractDict || throw(ArgumentError("FINAL_PROJECTOR_GALERKIN_AUDIT_REQUIRED"))
    source_risk_audit isa AbstractDict ||
        throw(ArgumentError("FINITE_BAND_SOURCE_RISK_AUDIT_REQUIRED"))
    final_combination_cancellation_audit isa AbstractDict ||
        throw(ArgumentError("FINITE_BAND_FINAL_CANCELLATION_AUDIT_REQUIRED"))
    Set(String.(collect(keys(source_risk_audit)))) == Set(("uHu", "sIu", "sHu")) ||
        throw(ArgumentError("FINITE_BAND_SOURCE_RISK_INVENTORY_MISMATCH"))
    normalized_sources = _profile_normalize_metadata(source_risk_audit)
    normalized_cancellation = _profile_normalize_metadata(final_combination_cancellation_audit)
    Set(String.(collect(keys(normalized_cancellation)))) == Set(("uHu", "sIu", "sHu")) ||
        throw(ArgumentError("FINITE_BAND_FINAL_CANCELLATION_INVENTORY_MISMATCH"))
    for operator in ("uHu", "sIu", "sHu")
        source = normalized_sources[operator]
        Bool(source["source_generation_qualified"]) ||
            throw(ArgumentError("FINITE_BAND_SOURCE_GENERATION_NOT_QUALIFIED: $(operator)"))
        Bool(source["artifact_published"]) ||
            throw(ArgumentError("FINITE_BAND_SOURCE_ARTIFACT_NOT_PUBLISHED: $(operator)"))
        String(source["qualification_stage"]) == "SOURCE_OPERATOR_GENERATION" ||
            throw(ArgumentError("FINITE_BAND_SOURCE_QUALIFICATION_STAGE_MISMATCH: $(operator)"))
        String(source["actual_operator_error_status"]) ==
        "NOT_AVAILABLE_WITHOUT_COMPLEMENT_HAMILTONIAN_OR_NBANDS_REFERENCE" ||
            throw(ArgumentError("FINITE_BAND_ACTUAL_ERROR_STATUS_MISMATCH: $(operator)"))
        String(source["nbands_convergence_status"]) == "NOT_ESTABLISHED" ||
            throw(ArgumentError("FINITE_BAND_NBANDS_STATUS_MISMATCH: $(operator)"))
        String(normalized_cancellation[operator]["status"]) == "RECORDED" ||
            throw(ArgumentError("FINITE_BAND_FINAL_CANCELLATION_AUDIT_NOT_RECORDED: $(operator)"))
    end
    audit = _profile_normalize_metadata(final_audit)
    String(audit["status"]) == "RECORDED" ||
        throw(ArgumentError("FINAL_PROJECTOR_GALERKIN_AUDIT_NOT_RECORDED"))
    return Dict{String, Any}(
        "route" => "full_profile_final_wannier_subspace",
        "overall" => "RISK_RECORDED_NOT_CONVERGED",
        "reason" => "NBANDS_CONVERGENCE_NOT_ESTABLISHED",
        "production_eligible" => false,
        "qualification_stage" => "FINAL_WANNIER_SUBSPACE_ASSEMBLY",
        "source_generation_qualified" => true,
        "artifact_published" => true,
        "actual_operator_error_status" => "NOT_AVAILABLE_WITHOUT_COMPLEMENT_HAMILTONIAN_OR_NBANDS_REFERENCE",
        "nbands_convergence_status" => "NOT_ESTABLISHED",
        "final_projector_galerkin_audit" => audit,
        "finite_band_risk_audit" => normalized_sources,
        "galerkin_block_audit" => Dict(
            operator => normalized_sources[operator]["galerkin_block_audit"] for
            operator in ("uHu", "sIu", "sHu")
        ),
        "galerkin_cancellation_audit" => normalized_cancellation,
        "source_cancellation_audit" => Dict(
            operator => normalized_sources[operator]["galerkin_cancellation_audit"] for
            operator in ("uHu", "sIu", "sHu")
        ),
    )
end

"""Qualify every profile operator and Reynolds-project the spin family when requested."""
function _qualify_spin_family!(
    operators,
    model,
    config::SymmetryAdaptedWannierizationConfig,
    symmetry_plan,
    spn_attestation,
    authority::AuthoritativeBandHamiltonian,
    ;
    final_projector_galerkin_audit = nothing,
    finite_band_source_risk_audit = nothing,
    final_combination_cancellation_audit = nothing,
    pair_wigner_seitz_roundtrip_residuals = nothing,
    delivery_roundtrip_residuals = nothing,
    operator_target_contract = nothing,
    source_neighbor_order_contract = nothing,
)
    standard_construction = config.input.construction_policy == :standard
    selection = _resolved_operator_selection(config)
    inventory = collect(IO.resolved_operator_inventory(selection))
    complete_family = _operator_selection_is_complete_family(selection)
    Set(keys(operators)) == Set(inventory) ||
        throw(ArgumentError("OPERATOR_QUALIFICATION_INVENTORY_MISMATCH"))
    spin_kinds = Set((
        REAL_SPACE_SPIN,
        REAL_SPACE_SPIN_TIMES_HAMILTONIAN,
        REAL_SPACE_SPIN_TIMES_POSITION,
        REAL_SPACE_SPIN_TIMES_HAMILTONIAN_POSITION,
    ))
    requested_spin = RealSpaceOperatorKind[kind for kind in inventory if kind in spin_kinds]
    pair_roundtrip =
        isempty(requested_spin) ? Dict{String, Float64}() :
        pair_wigner_seitz_roundtrip_residuals isa AbstractDict ?
        Dict{String, Float64}(
            String(key) => Float64(value) for
            (key, value) in pairs(pair_wigner_seitz_roundtrip_residuals)
        ) : throw(ArgumentError("SPIN_FAMILY_PAIR_WIGNER_SEITZ_AUDIT_REQUIRED"))
    expected_spin_names = Set(real_space_operator_name.(requested_spin))
    Set(keys(pair_roundtrip)) == expected_spin_names ||
        throw(ArgumentError("SPIN_FAMILY_PAIR_WIGNER_SEITZ_AUDIT_INVENTORY_MISMATCH"))
    for (name, residual) in pair_roundtrip
        isfinite(residual) ||
            throw(ArgumentError("SPIN_FAMILY_PAIR_WIGNER_SEITZ_ROUNDTRIP_NONFINITE: $(name)"))
        (
            config.input.construction_policy == :standard ||
            residual <= PROFILE_PAIR_WIGNER_SEITZ_ROUNDTRIP_TOLERANCE
        ) || throw(ArgumentError("SPIN_FAMILY_PAIR_WIGNER_SEITZ_ROUNDTRIP_FAILED: $(name)"))
    end
    delivery_roundtrip =
        delivery_roundtrip_residuals isa AbstractDict ?
        Dict{String, Float64}(
            String(key) => Float64(value) for (key, value) in pairs(delivery_roundtrip_residuals)
        ) : Dict{String, Float64}()
    target_contract_sha256 =
        operator_target_contract === nothing ? "LEGACY_NOT_RECORDED" :
        operator_target_contract.contract_sha256
    final_projector_sha256 =
        final_projector_galerkin_audit isa AbstractDict ?
        String(final_projector_galerkin_audit["final_subspace_projector_sha256"]) : "NOT_APPLICABLE"
    route =
        symmetry_plan === nothing ? "ordinary" :
        config.input.authoritative_hamiltonian isa NativeDFTHamiltonian ? "native_sawf" :
        "symmetrized_sawf"
    finite_band_family = _profile_finite_band_galerkin_family(
        _operator_selection_is_complete_family(selection),
        final_projector_galerkin_audit,
        finite_band_source_risk_audit,
        final_combination_cancellation_audit,
    )
    records = Dict{String, Any}()
    family_pass = true
    hamiltonian_kinds = Set((
        REAL_SPACE_HAMILTONIAN,
        REAL_SPACE_HAMILTONIAN_WEIGHTED_CONNECTION,
        REAL_SPACE_HAMILTONIAN_WEIGHTED_AXIAL_DERIVATIVE_OVERLAP,
        REAL_SPACE_SPIN_TIMES_HAMILTONIAN,
        REAL_SPACE_SPIN_TIMES_HAMILTONIAN_POSITION,
    ))
    authority_contract_sha256 =
        star_authoritative_hamiltonian_sha256(config.input.authoritative_hamiltonian)
    for kind in inventory
        serialized = operators[kind]
        is_spin = kind in spin_kinds
        requires_hamiltonian = kind in hamiltonian_kinds
        if !is_spin
            covariance_before = NaN
            covariance_after = NaN
            idempotence = NaN
            passed = true
            projection_status = symmetry_plan === nothing ? "NOT_APPLICABLE" : "UPSTREAM_QUALIFIED"
            reason = "UPSTREAM_PROFILE_ASSEMBLY_QUALIFIED"
        else
            unit_values =
                serialized.data ./ reshape(
                    model.r_degeneracies,
                    ntuple(
                        axis -> axis == ndims(serialized.data) ? length(model.r_degeneracies) : 1,
                        ndims(serialized.data),
                    ),
                )
            input = RealSpaceOperator(serialized.spec, serialized.r_vectors, unit_values)
            if symmetry_plan === nothing
                covariance_before = NaN
                covariance_after = NaN
                idempotence = NaN
                projected = input
                passed = true
                projection_status = "NOT_APPLICABLE"
                reason = "SOURCE_AND_GAUGE_QUALIFIED"
            else
                covariance_before = maximum_real_space_covariance_error(input, symmetry_plan)
                result = symmetrize_real_space_operator(input, symmetry_plan)
                projected = _align_profile_operator_support(
                    result.operator,
                    model;
                    tolerance = config.output.spin_family_covariance_tolerance,
                )
                covariance_after = maximum_real_space_covariance_error(projected, symmetry_plan)
                repeated_result = symmetrize_real_space_operator(projected, symmetry_plan)
                repeated = _align_profile_operator_support(
                    repeated_result.operator,
                    model;
                    tolerance = config.output.spin_family_idempotence_tolerance,
                )
                idempotence = _profile_operator_maximum_difference(projected, repeated)
                passed =
                    covariance_after <= config.output.spin_family_covariance_tolerance &&
                    idempotence <= config.output.spin_family_idempotence_tolerance
                projection_status = "APPLIED"
                reason = passed ? "QUALIFIED" : "NUMERICAL_SYMMETRY_QUALIFICATION_FAILED"
            end
            restored =
                projected.data .* reshape(
                    model.r_degeneracies,
                    ntuple(
                        axis -> axis == ndims(projected.data) ? length(model.r_degeneracies) : 1,
                        ndims(projected.data),
                    ),
                )
            operators[kind] = RealSpaceOperator(projected.spec, model.r_vectors, restored)
            family_pass &= passed
        end
        name = real_space_operator_name(kind)
        source =
            if hasproperty(spn_attestation, :operator_sources) &&
               haskey(spn_attestation.operator_sources, name)
                spn_attestation.operator_sources[name]
            elseif is_spin
                spn_attestation
            else
                payload_sha256 = _authoritative_array_sha256(serialized.data)
                (
                    provenance_sha256 = payload_sha256,
                    artifact_sha256 = payload_sha256,
                    source_band_gauge = "final_wannier_gauge",
                    target_band_gauge = "final_wannier_gauge",
                    gauge_artifact_sha256 = "NOT_APPLICABLE",
                    rotation_sha256 = "NOT_APPLICABLE",
                    frame_contract = _not_applicable_profile_frame_contract(),
                    input_sha256 = Dict("OPERATOR_PAYLOAD" => payload_sha256),
                    authoritative_hamiltonian = requires_hamiltonian ? authority.authority :
                                                "NOT_APPLICABLE",
                    authoritative_hamiltonian_digest = requires_hamiltonian ? authority.digest :
                                                       "NOT_APPLICABLE",
                    authoritative_hamiltonian_input_sha256 = requires_hamiltonian ?
                                                             copy(authority.input_sha256) :
                                                             Dict{String, String}(),
                )
            end
        authority_input_sha256 = Dict{String, String}(source.authoritative_hamiltonian_input_sha256)
        if requires_hamiltonian
            recorded_contract = get(
                authority_input_sha256,
                "AUTHORITATIVE_HAMILTONIAN_SHA256",
                authority_contract_sha256,
            )
            recorded_contract == authority_contract_sha256 || throw(
                ArgumentError(
                    "HAMILTONIAN_REFERENCE_MISMATCH: operator qualification authority contract differs from the configured authority",
                ),
            )
            authority_input_sha256["AUTHORITATIVE_HAMILTONIAN_SHA256"] = authority_contract_sha256
        end
        frame_contract = _profile_frame_contract_dictionary(source.frame_contract)
        generation_source_band_gauge = String(source.source_band_gauge)
        generation_target_band_gauge = String(source.target_band_gauge)
        delivery_target_band_gauge =
            (complete_family || IO.operator_selection_mode(selection) == :tasks) ?
            "final_wannier_gauge" : generation_target_band_gauge
        delivery_residual = is_spin ? pair_roundtrip[name] : get(delivery_roundtrip, name, 0.0)
        isfinite(delivery_residual) ||
            throw(ArgumentError("OPERATOR_DELIVERY_ROUNDTRIP_NONFINITE: $(name)"))
        complete_family &&
            delivery_residual > PROFILE_PAIR_WIGNER_SEITZ_ROUNDTRIP_TOLERANCE &&
            throw(ArgumentError("OPERATOR_DELIVERY_ROUNDTRIP_FAILED: $(name)"))
        delivery_payload_sha256 = _authoritative_array_sha256(operators[kind].data)
        delivery_transform_sha256 = bytes2hex(
            SHA.sha256(
                join(
                    (
                        String(source.rotation_sha256),
                        final_projector_sha256,
                        delivery_payload_sha256,
                        target_contract_sha256,
                        name,
                    ),
                    '\n',
                ),
            ),
        )
        source_risk =
            hasproperty(source, :finite_band_risk_audit) ?
            _profile_normalize_metadata(source.finite_band_risk_audit) :
            Dict{String, Any}("status" => "NOT_APPLICABLE")
        record = Dict{String, Any}(
            "source_status" => "PASS",
            "gauge_status" => "PASS",
            "source_provenance_sha256" => String(source.provenance_sha256),
            "source_artifact_sha256" => String(source.artifact_sha256),
            "source_band_gauge" => String(source.source_band_gauge),
            "target_band_gauge" => delivery_target_band_gauge,
            "generation_source_band_gauge" => generation_source_band_gauge,
            "generation_target_band_gauge" => generation_target_band_gauge,
            "delivery_target_band_gauge" => delivery_target_band_gauge,
            "delivery_transform_sha256" => delivery_transform_sha256,
            "delivery_payload_sha256" => delivery_payload_sha256,
            "delivery_roundtrip_residual" => delivery_residual,
            "delivery_roundtrip_tolerance" => PROFILE_PAIR_WIGNER_SEITZ_ROUNDTRIP_TOLERANCE,
            "delivery_roundtrip_status" =>
                delivery_residual <= PROFILE_PAIR_WIGNER_SEITZ_ROUNDTRIP_TOLERANCE ? "PASS" :
                "NUMERICAL_WARNING",
            "operator_target_contract_sha256" => target_contract_sha256,
            "gauge_artifact_sha256" => String(source.gauge_artifact_sha256),
            "band_gauge_rotation_sha256" => String(source.rotation_sha256),
            "band_gauge_rotation_semantics" => "legacy_alias_of_band_frame_transform_sha256",
            "band_frame_transform_sha256" => String(frame_contract["transform_sha256"]),
            "band_frame_contract_sha256" => String(frame_contract["contract_sha256"]),
            "band_frame_contract" => frame_contract,
            "source_input_sha256" => Dict{String, String}(source.input_sha256),
            "authoritative_hamiltonian" => String(source.authoritative_hamiltonian),
            "authoritative_hamiltonian_digest" =>
                String(source.authoritative_hamiltonian_digest),
            "authoritative_hamiltonian_input_sha256" => authority_input_sha256,
            "symmetry_projection" => projection_status,
            "covariance_before" => covariance_before,
            "covariance_after" => covariance_after,
            "covariance_tolerance" => config.output.spin_family_covariance_tolerance,
            "idempotence_residual" => idempotence,
            "idempotence_tolerance" => config.output.spin_family_idempotence_tolerance,
            "pair_wigner_seitz_transform_algorithm" =>
                is_spin ? PROFILE_PAIR_WIGNER_SEITZ_TRANSFORM_ALGORITHM : "NOT_APPLICABLE",
            "pair_wigner_seitz_storage_policy" =>
                is_spin ? PROFILE_PAIR_WIGNER_SEITZ_STORAGE_POLICY : "NOT_APPLICABLE",
            "pair_wigner_seitz_roundtrip_residual" => is_spin ? pair_roundtrip[name] : NaN,
            "pair_wigner_seitz_roundtrip_tolerance" =>
                is_spin ? PROFILE_PAIR_WIGNER_SEITZ_ROUNDTRIP_TOLERANCE : NaN,
            "pair_wigner_seitz_roundtrip_status" =>
                is_spin ?
                (
                    pair_roundtrip[name] <= PROFILE_PAIR_WIGNER_SEITZ_ROUNDTRIP_TOLERANCE ?
                    "PASS" : "NUMERICAL_WARNING"
                ) : "NOT_APPLICABLE",
            "finite_band_galerkin_status" => String(finite_band_family["overall"]),
            "finite_band_risk_audit" => source_risk,
            "qualification" => passed ? "PASS" : "FAIL",
            "reason" => reason,
        )
        if kind in (
            REAL_SPACE_DERIVATIVE_OVERLAP_TENSOR,
            REAL_SPACE_AXIAL_DERIVATIVE_OVERLAP,
            REAL_SPACE_SYMMETRIC_DERIVATIVE_OVERLAP,
            REAL_SPACE_HAMILTONIAN_WEIGHTED_AXIAL_DERIVATIVE_OVERLAP,
        )
            source_neighbor_order_contract === nothing && throw(
                ArgumentError(
                    "OPERATOR_NEIGHBOR_ORDER_CONTRACT_REQUIRED: streamed operator assembly",
                ),
            )
            evidence = Dict{String, Any}(
                "algorithm" => STREAMED_NEIGHBOR_ORDER_ALGORITHM,
                "source_to_internal_sha256" =>
                    source_neighbor_order_contract["source_to_internal_sha256"],
                "operator_kind" => name,
                "status" => "REBUILT_SOURCE_TO_INTERNAL",
            )
            for field in (
                "source_artifact_sha256",
                "source_input_sha256",
                "operator_target_contract_sha256",
                "delivery_payload_sha256",
            )
                evidence[field] = deepcopy(record[field])
            end
            data = operators[kind].data
            component_hashes =
                serialized.spec.cartesian_rank == 1 ?
                [_authoritative_array_sha256(@view(data[:, :, a, :])) for a in 1:3] :
                [_authoritative_array_sha256(@view(data[:, :, a, b, :])) for a in 1:3 for b in 1:3]
            evidence["delivery_component_sha256"] = join(component_hashes, ",")
            record["source_neighbor_order_contract"] = evidence
        end
        record["payload_sha256"] = _profile_qualification_record_sha256(record)
        records[name] = record
    end
    isempty(requested_spin) && (family_pass = false)
    pair_roundtrip_worst_operator =
        isempty(pair_roundtrip) ? "NOT_APPLICABLE" :
        first(sort!(collect(keys(pair_roundtrip)); by = name -> (-pair_roundtrip[name], name)))
    pair_roundtrip_maximum =
        isempty(pair_roundtrip) ? NaN : pair_roundtrip[pair_roundtrip_worst_operator]
    qualification = Dict{String, Any}(
        "schema" => OPERATOR_QUALIFICATION_SCHEMA,
        "schema_version" => OPERATOR_QUALIFICATION_SCHEMA_VERSION,
        "construction_policy" => String(config.input.construction_policy),
        "model_qualification" => standard_construction ? "STANDARD" : "PASS",
        "quality_review_recommended" => standard_construction,
        "production_eligible" => false,
        "operators" => records,
        "families" => Dict(
            "spin" => Dict(
                "route" => isempty(requested_spin) ? "not_applicable" : route,
                "overall" =>
                    isempty(requested_spin) ? "NOT_APPLICABLE" : family_pass ? "PASS" : "FAIL",
                "reason" =>
                    isempty(requested_spin) ? "PROFILE_HAS_NO_SPIN_FAMILY" :
                    family_pass ? "ALL_REQUIRED_OPERATORS_QUALIFIED" :
                    "NUMERICAL_SYMMETRY_QUALIFICATION_FAILED",
                "production_eligible" =>
                    !isempty(requested_spin) &&
                    family_pass &&
                    pair_roundtrip_maximum <= PROFILE_PAIR_WIGNER_SEITZ_ROUNDTRIP_TOLERANCE,
                "pair_wigner_seitz_transform_algorithm" =>
                    isempty(requested_spin) ? "NOT_APPLICABLE" :
                    PROFILE_PAIR_WIGNER_SEITZ_TRANSFORM_ALGORITHM,
                "pair_wigner_seitz_storage_policy" =>
                    isempty(requested_spin) ? "NOT_APPLICABLE" :
                    PROFILE_PAIR_WIGNER_SEITZ_STORAGE_POLICY,
                "pair_wigner_seitz_roundtrip_status" =>
                    isempty(requested_spin) ? "NOT_APPLICABLE" :
                    (
                        pair_roundtrip_maximum <= PROFILE_PAIR_WIGNER_SEITZ_ROUNDTRIP_TOLERANCE ? "PASS" :
                        "NUMERICAL_WARNING"
                    ),
                "pair_wigner_seitz_roundtrip_tolerance" =>
                    isempty(requested_spin) ? NaN : PROFILE_PAIR_WIGNER_SEITZ_ROUNDTRIP_TOLERANCE,
                "pair_wigner_seitz_roundtrip_maximum" => pair_roundtrip_maximum,
                "pair_wigner_seitz_roundtrip_worst_operator" => pair_roundtrip_worst_operator,
            ),
            "finite_band_galerkin" => finite_band_family,
        ),
    )
    source_neighbor_order_contract === nothing ||
        (qualification["source_neighbor_order_contract"] = deepcopy(source_neighbor_order_contract))
    return qualification
end

"""Resolve one mandatory profile input without accepting a missing artifact."""
function _required_profile_file(value, label::AbstractString)
    value === nothing && throw(ArgumentError("$(uppercase(label))_REQUIRED: $(label) is missing"))
    path = abspath(something(value))
    isfile(path) || throw(ArgumentError("$(label) does not exist: $(path)"))
    return path
end

# Map one generated-operator symbol to its upstream source-registry symbol.
const _PROFILE_OPERATOR_SOURCE_SYMBOLS =
    Dict(:uIu => :uiu, :uHu => :uhu, :sIu => :siu, :sHu => :shu)

# Return the configured input path for one generated operator artifact.
function _profile_operator_input_path(config::SymmetryAdaptedWannierizationConfig, operator::Symbol)
    operator === :uIu && return config.output.uiu_file
    operator === :uHu && return config.output.uhu_file
    operator === :sIu && return config.output.siu_file
    operator === :sHu && return config.output.shu_file
    throw(ArgumentError("UNSUPPORTED_PROFILE_OPERATOR: $(operator)"))
end

# Return the configuration label for one generated operator artifact.
function _profile_operator_input_label(operator::Symbol)
    operator === :uIu && return "uiu_file"
    operator === :uHu && return "uhu_file"
    operator === :sIu && return "siu_file"
    operator === :sHu && return "shu_file"
    throw(ArgumentError("UNSUPPORTED_PROFILE_OPERATOR: $(operator)"))
end

# Return the configured provenance-sidecar path for one generated operator artifact.
function _profile_operator_sidecar_path(
    config::SymmetryAdaptedWannierizationConfig,
    operator::Symbol,
)
    operator === :uIu && return config.output.uiu_provenance_json
    operator === :uHu && return config.output.uhu_provenance_json
    operator === :sIu && return config.output.siu_provenance_json
    operator === :sHu && return config.output.shu_provenance_json
    throw(ArgumentError("UNSUPPORTED_PROFILE_OPERATOR: $(operator)"))
end

# Return the configuration label for one generated operator provenance sidecar.
function _profile_operator_sidecar_label(operator::Symbol)
    operator === :uIu && return "uiu_provenance_json"
    operator === :uHu && return "uhu_provenance_json"
    operator === :sIu && return "siu_provenance_json"
    operator === :sHu && return "shu_provenance_json"
    throw(ArgumentError("UNSUPPORTED_PROFILE_OPERATOR: $(operator)"))
end

# Resolve only the generated-operator inputs demanded by one resolved source set.
function _profile_operator_paths(config::SymmetryAdaptedWannierizationConfig, source_set)
    requested = Symbol[
        operator for operator in (:uIu, :uHu, :sIu, :sHu) if
        _PROFILE_OPERATOR_SOURCE_SYMBOLS[operator] in source_set
    ]
    paths = Dict{Symbol, String}()
    sidecars = Dict{Symbol, String}()
    for operator in requested
        paths[operator] = _required_profile_file(
            _profile_operator_input_path(config, operator),
            _profile_operator_input_label(operator),
        )
        sidecars[operator] = _required_profile_file(
            _profile_operator_sidecar_path(config, operator),
            _profile_operator_sidecar_label(operator),
        )
    end
    return paths, sidecars
end

# Read one generated operator header without assuming a single operator family.
function _profile_operator_header(
    operator::Symbol,
    path::AbstractString,
    config::SymmetryAdaptedWannierizationConfig,
)
    formatted = config.output.operator_files_formatted
    operator === :uIu && return IO.read_wannier_uiu_header(path; formatted = formatted)
    operator === :uHu && return IO.read_wannier_uhu_header(path; formatted = formatted)
    operator === :sIu && return IO.read_wannier_siu_header(path; formatted = formatted)
    operator === :sHu && return IO.read_wannier_shu_header(path; formatted = formatted)
    throw(ArgumentError("UNSUPPORTED_PROFILE_OPERATOR: $(operator)"))
end

"""Validate one source-generator sidecar without treating leakage audits as error bounds."""
function _qualified_hamiltonian_operator_sidecar(
    path::AbstractString,
    operator::Symbol,
    output_file::AbstractString,
    authority::AuthoritativeBandHamiltonian,
    tolerance::Float64,
    gauge_contract,
    spn_provenance_sha256::AbstractString,
    uiu_input_sha256,
    spn_input_sha256,
    spn_sha256::AbstractString,
)
    payload = JSON3.read(read(path, String))
    String(payload.schema) == WANNIER_HAMILTONIAN_OPERATOR_GENERATION_SCHEMA ||
        throw(ArgumentError("OPERATOR_PROVENANCE_MISMATCH: $(operator) provenance schema differs"))
    String(payload.schema_version) in ("1.0", "1.1", "1.3") ||
        throw(ArgumentError("OPERATOR_PROVENANCE_MISMATCH: $(operator) provenance version differs"))
    Symbol(String(payload.operator)) == operator ||
        throw(ArgumentError("OPERATOR_PROVENANCE_MISMATCH: expected $(operator) provenance"))
    String(payload.qualification_stage) == "SOURCE_OPERATOR_GENERATION" || throw(
        ArgumentError("OPERATOR_PROVENANCE_MISMATCH: $(operator) qualification stage differs"),
    )
    Bool(payload.source_generation_qualified) && Bool(payload.passed) || throw(
        ArgumentError("SOURCE_OPERATOR_GENERATION_FAILED: $(operator) generator is not qualified"),
    )
    Bool(payload.artifact_published) && String(payload.status) == "PASS" || throw(
        ArgumentError("SOURCE_OPERATOR_ARTIFACT_NOT_PUBLISHED: $(operator) output is unavailable"),
    )
    diagnostic_reference = Float64(payload.diagnostic_reference)
    isfinite(diagnostic_reference) && diagnostic_reference > 0.0 || throw(
        ArgumentError("OPERATOR_PROVENANCE_MISMATCH: $(operator) diagnostic reference invalid"),
    )
    diagnostic_reference == tolerance || throw(
        ArgumentError("OPERATOR_PROVENANCE_MISMATCH: $(operator) diagnostic reference differs"),
    )
    diagnostic_reference_status = String(payload.diagnostic_reference_status)
    diagnostic_reference_status in ("WITHIN_REFERENCE", "ABOVE_REFERENCE") ||
        throw(ArgumentError("OPERATOR_PROVENANCE_MISMATCH: $(operator) diagnostic status invalid"))
    String(payload.diagnostic_reference_policy) ==
    "AUDIT_ONLY_NOT_AN_ACTUAL_OPERATOR_ERROR_BOUND" ||
        throw(ArgumentError("OPERATOR_PROVENANCE_MISMATCH: $(operator) diagnostic policy differs"))
    String(payload.actual_operator_error_status) ==
    "NOT_AVAILABLE_WITHOUT_COMPLEMENT_HAMILTONIAN_OR_NBANDS_REFERENCE" || throw(
        ArgumentError("OPERATOR_PROVENANCE_MISMATCH: $(operator) actual-error status differs"),
    )
    String(payload.nbands_convergence_status) == "NOT_ESTABLISHED" ||
        throw(ArgumentError("OPERATOR_PROVENANCE_MISMATCH: $(operator) NBANDS status differs"))
    String(payload.output_sha256) == sha256_file(output_file) ||
        throw(ArgumentError("OPERATOR_PROVENANCE_MISMATCH: $(operator) output hash differs"))
    String(payload.authoritative_hamiltonian_digest) == authority.digest ||
        throw(ArgumentError("HAMILTONIAN_REFERENCE_MISMATCH: $(operator) authority digest differs"))
    String(payload.authoritative_hamiltonian) == authority.authority ||
        throw(ArgumentError("HAMILTONIAN_REFERENCE_MISMATCH: $(operator) authority label differs"))
    String(payload.source_band_gauge) == gauge_contract.source_band_gauge ||
        throw(ArgumentError("OPERATOR_PROVENANCE_MISMATCH: $(operator) source gauge differs"))
    String(payload.target_band_gauge) == gauge_contract.target_band_gauge ||
        throw(ArgumentError("OPERATOR_PROVENANCE_MISMATCH: $(operator) target gauge differs"))
    String(payload.band_frame_transform_sha256) == gauge_contract.transform_sha256 ||
        throw(ArgumentError("OPERATOR_PROVENANCE_MISMATCH: $(operator) frame digest differs"))
    String(payload.band_frame_contract_sha256) == gauge_contract.contract_sha256 ||
        throw(ArgumentError("OPERATOR_PROVENANCE_MISMATCH: $(operator) frame contract differs"))
    String(payload.gauge_artifact_sha256) ==
    something(gauge_contract.gauge_artifact_sha256, "NOT_APPLICABLE") ||
        throw(ArgumentError("OPERATOR_PROVENANCE_MISMATCH: $(operator) gauge artifact differs"))
    expected_spn_digest =
        operator in (:sIu, :sHu) ? String(spn_provenance_sha256) : "NOT_APPLICABLE"
    String(payload.spn_provenance_sha256) == expected_spn_digest ||
        throw(ArgumentError("OPERATOR_PROVENANCE_MISMATCH: $(operator) SPN provenance differs"))
    input_sha256 = _profile_input_hashes(payload.input_sha256, String(operator))
    _validate_profile_common_source_hashes(uiu_input_sha256, input_sha256, String(operator))
    operator in (:sIu, :sHu) && _validate_profile_spn_source_hashes(
        input_sha256,
        spn_input_sha256,
        spn_sha256,
        spn_provenance_sha256,
        String(operator),
    )
    block_audit = _profile_normalize_metadata(payload.galerkin_block_audit)
    cancellation_audit = _profile_normalize_metadata(payload.galerkin_cancellation_audit)
    String(block_audit["status"]) == "RECORDED" ||
        throw(ArgumentError("OPERATOR_PROVENANCE_MISMATCH: $(operator) Galerkin audit missing"))
    Int(block_audit["block_count"]) > 0 || throw(
        ArgumentError("OPERATOR_PROVENANCE_MISMATCH: $(operator) Galerkin block count invalid"),
    )
    String(block_audit["norm_kind"]) == "frobenius" ||
        throw(ArgumentError("OPERATOR_PROVENANCE_MISMATCH: $(operator) Galerkin norm differs"))
    for field in (
        "maximum_frobenius_norm",
        "maximum_frobenius_product_bound",
        "minimum_block_to_bound_ratio",
    )
        value = Float64(block_audit[field])
        isfinite(value) && value >= 0.0 ||
            throw(ArgumentError("OPERATOR_PROVENANCE_MISMATCH: $(operator) $(field) invalid"))
    end
    String(cancellation_audit["status"]) == "NOT_AVAILABLE_BEFORE_FINAL_WANNIER_PROFILE_ASSEMBLY" ||
        throw(
            ArgumentError(
                "OPERATOR_PROVENANCE_MISMATCH: $(operator) cancellation deferral differs",
            ),
        )
    String(cancellation_audit["policy"]) == "DEFER_TO_FINITE_DIFFERENCE_PROFILE_CONTRACTION" ||
        throw(
            ArgumentError("OPERATOR_PROVENANCE_MISMATCH: $(operator) cancellation policy differs"),
        )
    for field in ("absolute_sum", "final_combination", "cancellation_ratio")
        cancellation_audit[field] === nothing || throw(
            ArgumentError(
                "OPERATOR_PROVENANCE_MISMATCH: $(operator) deferred $(field) must be null",
            ),
        )
    end
    risk_audit = Dict{String, Any}(
        "qualification_stage" => String(payload.qualification_stage),
        "source_generation_qualified" => Bool(payload.source_generation_qualified),
        "artifact_published" => Bool(payload.artifact_published),
        "diagnostic_reference" => diagnostic_reference,
        "diagnostic_reference_status" => diagnostic_reference_status,
        "diagnostic_reference_policy" => String(payload.diagnostic_reference_policy),
        "actual_operator_error_status" => String(payload.actual_operator_error_status),
        "nbands_convergence_status" => String(payload.nbands_convergence_status),
        "outer_probability_leakage_audit_maximum" =>
            Float64(payload.outer_probability_leakage_audit_maximum),
        "outer_probability_leakage_audit_status" =>
            String(payload.outer_probability_leakage_audit_status),
        "frozen_probability_leakage_audit_maximum" =>
            payload.frozen_probability_leakage_audit_maximum === nothing ? nothing :
            Float64(payload.frozen_probability_leakage_audit_maximum),
        "frozen_probability_leakage_audit_status" =>
            String(payload.frozen_probability_leakage_audit_status),
        "parent_mutual_containment_audit_maximum" =>
            Float64(payload.parent_mutual_containment_audit_maximum),
        "parent_mutual_containment_audit_status" =>
            String(payload.parent_mutual_containment_audit_status),
        "parent_overlap_contraction_excess_audit_maximum" =>
            Float64(payload.parent_overlap_contraction_excess_audit_maximum),
        "outer_overlap_contraction_excess_audit_maximum" =>
            Float64(payload.outer_overlap_contraction_excess_audit_maximum),
        "frozen_overlap_contraction_excess_audit_maximum" =>
            payload.frozen_overlap_contraction_excess_audit_maximum === nothing ? nothing :
            Float64(payload.frozen_overlap_contraction_excess_audit_maximum),
        "galerkin_block_audit" => block_audit,
        "galerkin_cancellation_audit" => cancellation_audit,
    )
    for (name, value) in pairs(risk_audit)
        endswith(name, "_maximum") &&
            value !== nothing &&
            (!isfinite(value) || value < 0.0) &&
            throw(ArgumentError("OPERATOR_PROVENANCE_MISMATCH: $(operator) $(name) invalid"))
    end
    return payload, risk_audit, input_sha256
end

"""Accept finite Standard uIu warnings without relabeling their numerical qualification."""
function _uiu_sidecar_quality_available(payload, construction_policy::Symbol)
    Bool(payload.passed) && Bool(payload.physical_overlap_available) && return true
    construction_policy == :standard || return false
    get(payload, :construction_policy, "") == "standard" &&
    get(payload, :status, "") == "EXPORTED_WITH_WARNING" &&
    !Bool(payload.passed) &&
    Bool(payload.physical_overlap_available) &&
    get(payload, :production_eligible, true) === false || return false
    "UIU_GENERATION_NUMERICAL_WARNING" in get(payload, :diagnostics, []) || return false
    fields = (
        :generalized_normalization_max_absolute,
        :radial_q_max_absolute,
        :diagonal_identity_max_absolute,
        :exchange_hermiticity_max_absolute,
    )
    all(
        name ->
            hasproperty(payload, name) &&
            getproperty(payload, name) isa Real &&
            isfinite(getproperty(payload, name)) &&
            getproperty(payload, name) >= 0,
        fields,
    ) || return false
    parity = get(payload, :mmn_parity, nothing)
    parity === nothing && return true
    get(parity, :finite, false) === true || return false
    return all(
        name ->
            hasproperty(parity, name) &&
            getproperty(parity, name) isa Real &&
            isfinite(getproperty(parity, name)) &&
            getproperty(parity, name) >= 0,
        (:max_absolute, :root_mean_square, :relative_l2),
    )
end

"""Validate a uIu sidecar and its same-source MMN oracle binding."""
function _qualified_uiu_sidecar(
    path::AbstractString,
    uiu_file::AbstractString,
    mmn_file::AbstractString,
    gauge_contract;
    construction_policy::Symbol = :strict,
)
    payload = JSON3.read(read(path, String))
    String(payload.schema) == WANNIER_UIU_GENERATION_SCHEMA || throw(
        ArgumentError("PROJECTOR_FULL_DERIVATIVE_OVERLAP_REQUIRED: uIu provenance schema differs"),
    )
    String(payload.schema_version) in ("1.0", "1.1", "1.2") || throw(
        ArgumentError("PROJECTOR_FULL_DERIVATIVE_OVERLAP_REQUIRED: uIu provenance version differs"),
    )
    _uiu_sidecar_quality_available(payload, construction_policy) ||
        throw(ArgumentError("PROJECTOR_FULL_DERIVATIVE_OVERLAP_REQUIRED: uIu qualification failed"))
    String(payload.output_sha256) == sha256_file(uiu_file) ||
        throw(ArgumentError("PROJECTOR_FULL_DERIVATIVE_OVERLAP_REQUIRED: uIu output hash differs"))
    hashes = Dict{String, String}(
        String(key) => String(value) for (key, value) in pairs(payload.input_sha256)
    )
    get(hashes, "ORACLE_MMN", "MISSING") == sha256_file(mmn_file) ||
        throw(ArgumentError("PROJECTOR_FULL_DERIVATIVE_OVERLAP_REQUIRED: uIu MMN oracle differs"))
    String(payload.source_band_gauge) == gauge_contract.source_band_gauge ||
        throw(ArgumentError("PROJECTOR_FULL_DERIVATIVE_OVERLAP_REQUIRED: uIu source gauge differs"))
    String(payload.target_band_gauge) == gauge_contract.target_band_gauge ||
        throw(ArgumentError("PROJECTOR_FULL_DERIVATIVE_OVERLAP_REQUIRED: uIu target gauge differs"))
    String(payload.band_frame_transform_sha256) == gauge_contract.transform_sha256 ||
        throw(ArgumentError("PROJECTOR_FULL_DERIVATIVE_OVERLAP_REQUIRED: uIu frame differs"))
    String(payload.band_frame_contract_sha256) == gauge_contract.contract_sha256 || throw(
        ArgumentError("PROJECTOR_FULL_DERIVATIVE_OVERLAP_REQUIRED: uIu frame contract differs"),
    )
    String(payload.gauge_artifact_sha256) ==
    something(gauge_contract.gauge_artifact_sha256, "NOT_APPLICABLE") ||
        throw(ArgumentError("PROJECTOR_FULL_DERIVATIVE_OVERLAP_REQUIRED: uIu artifact differs"))
    return payload
end

"""Validate and hash each physical MMN path once across its target roles."""
function _operator_mmn_file_identities(
    mmn::WannierMMN,
    oracle_path::AbstractString,
    solver_path::AbstractString;
    topology_reader = IO.read_wannier_mmn_topology,
    file_hasher = sha256_file,
)
    expected_dimensions = (mmn.num_bands, mmn.num_kpts, mmn.num_neighbors)
    identities = Dict{String, String}()
    for (role, path) in (("operator oracle", oracle_path), ("solver", solver_path))
        canonical_path = realpath(path)
        haskey(identities, canonical_path) && continue
        topology = topology_reader(canonical_path)
        (topology.num_bands, topology.num_kpts, topology.num_neighbors) == expected_dimensions ||
            throw(ArgumentError("OPERATOR_TARGET_CONTRACT_MISMATCH: $(role) MMN dimensions differ"))
        topology.neighbors == mmn.neighbors &&
        topology.reciprocal_shifts == mmn.reciprocal_shifts ||
            throw(ArgumentError("OPERATOR_TARGET_CONTRACT_MISMATCH: $(role) MMN topology differs"))
        identities[canonical_path] = file_hasher(canonical_path)
    end
    return identities
end

"""Derive the target scope from the same EIG and window contract used by the solver."""
function _operator_qualification_scope(config::SymmetryAdaptedWannierizationConfig, eig::WannierEIG)
    labels = canonical_band_block_labels(eig.data, config.input.degeneracy_tolerance_ev)
    outer_masks, frozen_masks = window_masks_from_energies(config, eig.data, labels)
    return BandRepresentationQualificationScope(
        BitMatrix(hcat(outer_masks...)),
        BitMatrix(hcat(frozen_masks...)),
    )
end

"""Create the one typed target shared by raw operators, solver MMN, and export."""
function _wannier_operator_target_contract(
    config::SymmetryAdaptedWannierizationConfig,
    eig::WannierEIG,
    mmn::WannierMMN,
    operator_oracle_mmn_file::AbstractString,
    solver_mmn_file::AbstractString,
)
    oracle_path = abspath(operator_oracle_mmn_file)
    solver_path = abspath(solver_mmn_file)
    isfile(oracle_path) ||
        throw(ArgumentError("OPERATOR_TARGET_CONTRACT_MISSING: operator oracle MMN $(oracle_path)"))
    isfile(solver_path) ||
        throw(ArgumentError("OPERATOR_TARGET_CONTRACT_MISSING: solver MMN $(solver_path)"))
    identities = _operator_mmn_file_identities(mmn, oracle_path, solver_path)
    gauge_contract, authority = with_generation_gauge_reuse() do
        gauge_contract = generation_band_gauge_contract(
            config.input.source,
            config.input.authoritative_hamiltonian,
            config.input.wavefunction_gauge_hdf5,
            mmn.num_bands,
            mmn.num_kpts,
            construction_policy = config.input.construction_policy,
        )
        authority = authoritative_band_hamiltonian(config, eig)
        (gauge_contract, authority)
    end
    size(authority.matrices_ev) == (mmn.num_bands, mmn.num_bands, mmn.num_kpts) ||
        throw(ArgumentError("OPERATOR_TARGET_CONTRACT_MISMATCH: Hamiltonian dimensions differ"))
    return WannierOperatorTargetContract(
        oracle_path,
        identities[realpath(oracle_path)],
        solver_path,
        identities[realpath(solver_path)],
        gauge_contract.source_band_gauge,
        gauge_contract.target_band_gauge,
        gauge_contract.transform_sha256,
        gauge_contract.contract_sha256,
        something(gauge_contract.gauge_artifact_sha256, "NOT_APPLICABLE"),
        authority.authority,
        authority.digest,
        mmn.num_bands,
        mmn.num_kpts,
        mmn.num_neighbors,
        qualification_scope = _operator_qualification_scope(config, eig),
        target_authority = "outer_window",
        parent_audit_policy = "audit_only",
    )
end

"""Revalidate a target against live artifacts and the realized solver objects."""
function _validate_wannier_operator_target_contract(
    config::SymmetryAdaptedWannierizationConfig,
    eig::WannierEIG,
    mmn::WannierMMN,
    target::WannierOperatorTargetContract,
)
    validate_operator_target_contract_files(target)
    expected = _wannier_operator_target_contract(
        config,
        eig,
        mmn,
        target.operator_oracle_mmn_file,
        target.solver_mmn_file,
    )
    expected.contract_sha256 == target.contract_sha256 ||
        throw(ArgumentError("OPERATOR_TARGET_CONTRACT_MISMATCH: live target contract differs"))
    return nothing
end

"""Require a generated sidecar to attest the exact workflow target contract."""
function _require_operator_target_contract_hash(input_sha256, label, target)
    get(input_sha256, "OPERATOR_TARGET_CONTRACT", "MISSING") == target.contract_sha256 ||
        throw(ArgumentError("OPERATOR_TARGET_CONTRACT_MISMATCH: $(label) sidecar target differs"))
    return nothing
end

"""Validate every static operator-source identity before entering the SAWF solver."""
function _preflight_wannierization_operator_profile(
    config::SymmetryAdaptedWannierizationConfig,
    eig::WannierEIG,
    mmn::WannierMMN,
    target_contract::Union{Nothing, WannierOperatorTargetContract} = nothing,
)
    selection = _resolved_operator_selection(config)
    source_set = Set{Symbol}(IO.resolved_source_inventory(selection))
    needs_spn = :spn in source_set
    needs_generated = _operator_selection_requires_generated_operators(selection)
    if !needs_spn && !needs_generated
        return Dict{String, String}(
            "status" => "NOT_APPLICABLE",
            "profile" => String(IO.resolved_operator_profile(selection)),
        )
    end
    gauge_contract = generation_band_gauge_contract(
        config.input.source,
        config.input.authoritative_hamiltonian,
        config.input.wavefunction_gauge_hdf5,
        mmn.num_bands,
        mmn.num_kpts,
        construction_policy = config.input.construction_policy,
    )
    authority = authoritative_band_hamiltonian(config, eig)
    summary = Dict{String, String}(
        "status" => "PASS",
        "profile" => String(IO.resolved_operator_profile(selection)),
        "band_frame_contract_sha256" => gauge_contract.contract_sha256,
        "authoritative_hamiltonian" => authority.authority,
        "authoritative_hamiltonian_digest" => authority.digest,
    )
    spn_attestation = nothing
    if needs_spn
        spn_file = _required_profile_file(config.output.spn_file, "spn_file")
        spn_provenance_file =
            _required_profile_file(config.output.spn_provenance_file, "spn_provenance_file")
        spn_attestation = read_and_validate_spn_provenance(
            spn_provenance_file,
            spn_file;
            expected_num_bands = mmn.num_bands,
            expected_num_kpoints = mmn.num_kpts,
            target_authority = config.input.authoritative_hamiltonian,
            gauge_artifact_sha256 = gauge_contract.gauge_artifact_sha256,
            band_frame_transform_sha256 = gauge_contract.transform_sha256,
            band_frame_contract_sha256 = gauge_contract.contract_sha256,
        )
        summary["spn_sha256"] = String(spn_attestation.spn_sha256)
        summary["spn_provenance_sha256"] = String(spn_attestation.provenance_sha256)
    end
    _record_operator_selection_summary!(summary, selection)
    needs_generated || return summary
    target_contract === nothing && throw(
        ArgumentError("OPERATOR_TARGET_CONTRACT_REQUIRED: qualified-source operator selection"),
    )
    target = something(target_contract)
    _validate_wannier_operator_target_contract(config, eig, mmn, target)
    summary["operator_oracle_mmn_file"] = target.operator_oracle_mmn_file
    summary["operator_oracle_mmn_sha256"] = target.operator_oracle_mmn_sha256
    summary["solver_mmn_file"] = target.solver_mmn_file
    summary["solver_mmn_sha256"] = target.solver_mmn_sha256
    summary["operator_target_contract_sha256"] = target.contract_sha256

    requested_operators = Symbol[
        operator for operator in (:uIu, :uHu, :sIu, :sHu) if
        _PROFILE_OPERATOR_SOURCE_SYMBOLS[operator] in source_set
    ]
    paths = Dict{Symbol, String}()
    sidecars = Dict{Symbol, String}()
    for operator in requested_operators
        paths[operator] = _required_profile_file(
            _profile_operator_input_path(config, operator),
            _profile_operator_input_label(operator),
        )
        sidecars[operator] = _required_profile_file(
            _profile_operator_sidecar_path(config, operator),
            _profile_operator_sidecar_label(operator),
        )
    end
    headers = Dict(
        operator => _profile_operator_header(operator, paths[operator], config) for
        operator in requested_operators
    )
    for (operator, header) in headers
        header.num_bands == mmn.num_bands &&
        header.num_kpts == mmn.num_kpts &&
        header.num_neighbors == mmn.num_neighbors || throw(
            ArgumentError("OPERATOR_PROFILE_PREFLIGHT_MISMATCH: $(operator) dimensions differ"),
        )
    end
    uiu_input_sha256 = nothing
    if :uIu in requested_operators
        uiu_provenance = _qualified_uiu_sidecar(
            sidecars[:uIu],
            paths[:uIu],
            target.operator_oracle_mmn_file,
            gauge_contract;
            construction_policy = config.input.construction_policy,
        )
        uiu_input_sha256 = _profile_input_hashes(uiu_provenance.input_sha256, "uIu")
        _require_operator_target_contract_hash(uiu_input_sha256, "uIu", target)
    end
    spn_input_sha256 =
        needs_spn ? _profile_input_hashes(spn_attestation.input_sha256, "SPN provenance") : nothing
    spn_provenance_sha256 = needs_spn ? spn_attestation.provenance_sha256 : "NOT_APPLICABLE"
    spn_artifact_sha256 = needs_spn ? spn_attestation.spn_sha256 : "NOT_APPLICABLE"
    common_reference = uiu_input_sha256 !== nothing ? uiu_input_sha256 : spn_input_sha256
    for operator in (:uHu, :sIu, :sHu)
        operator in requested_operators || continue
        common_reference === nothing && throw(
            ArgumentError(
                "OPERATOR_SOURCE_INPUT_REQUIRED: $(operator) sidecar has no common physical-source reference",
            ),
        )
        _, _, input_sha256 = _qualified_hamiltonian_operator_sidecar(
            sidecars[operator],
            operator,
            paths[operator],
            authority,
            config.output.operator_closure_tolerance,
            gauge_contract,
            spn_provenance_sha256,
            common_reference,
            spn_input_sha256,
            spn_artifact_sha256,
        )
        _require_operator_target_contract_hash(input_sha256, String(operator), target)
    end
    for operator in requested_operators
        label = lowercase(String(operator))
        summary["$(label)_sha256"] = sha256_file(paths[operator])
        summary["$(label)_provenance_sha256"] = sha256_file(sidecars[operator])
    end
    return summary
end

"""Reject operator or SPN artifacts changed after the pre-solver checkpoint snapshot."""
function _validate_operator_profile_preflight_snapshot(result, config)
    selection = _resolved_operator_selection(config)
    needs_spn = _operator_selection_needs_source(selection, :spn)
    needs_generated = _operator_selection_requires_generated_operators(selection)
    needs_spn || needs_generated || return nothing
    prefix = "operator_profile_preflight_"
    source_set = Set{Symbol}(IO.resolved_source_inventory(selection))
    artifacts = Dict{String, Tuple{String, String}}()
    for operator in (:uIu, :uHu, :sIu, :sHu)
        source = _PROFILE_OPERATOR_SOURCE_SYMBOLS[operator]
        source in source_set || continue
        artifacts[String(source)] = (
            _required_profile_file(
                _profile_operator_input_path(config, operator),
                _profile_operator_input_label(operator),
            ),
            _required_profile_file(
                _profile_operator_sidecar_path(config, operator),
                _profile_operator_sidecar_label(operator),
            ),
        )
    end
    for (label, (operator_file, sidecar_file)) in artifacts
        expected_operator = get(result.input_summary, prefix * label * "_sha256", "MISSING")
        expected_sidecar =
            get(result.input_summary, prefix * label * "_provenance_sha256", "MISSING")
        sha256_file(operator_file) == expected_operator ||
            throw(ArgumentError("OPERATOR_PROFILE_TOCTOU_MISMATCH: $(label) artifact changed"))
        sha256_file(sidecar_file) == expected_sidecar ||
            throw(ArgumentError("OPERATOR_PROFILE_TOCTOU_MISMATCH: $(label) sidecar changed"))
        payload = JSON3.read(read(sidecar_file, String))
        String(payload.output_sha256) == expected_operator || throw(
            ArgumentError(
                "OPERATOR_PROFILE_TOCTOU_MISMATCH: $(label) sidecar output binding differs",
            ),
        )
    end
    needs_spn || return nothing
    spn_file = _required_profile_file(config.output.spn_file, "spn_file")
    spn_provenance_file =
        _required_profile_file(config.output.spn_provenance_file, "spn_provenance_file")
    sha256_file(spn_file) == get(result.input_summary, prefix * "spn_sha256", "MISSING") ||
        throw(ArgumentError("OPERATOR_PROFILE_TOCTOU_MISMATCH: SPN artifact changed"))
    sha256_file(spn_provenance_file) ==
    get(result.input_summary, prefix * "spn_provenance_sha256", "MISSING") ||
        throw(ArgumentError("OPERATOR_PROFILE_TOCTOU_MISMATCH: SPN provenance changed"))
    return nothing
end

"""Build the pair Wigner-Seitz transform plan shared by profile operators."""
function _profile_transform_plan(chk, model)
    return WannierPairWignerSeitzTransformPlan(
        chk,
        model.r_vectors;
        wigner_seitz_tolerance = 1.0e-5,
        search_size = 3,
    )
end

"""Transform one profile operator from q space onto the qualified R support."""
function _profile_q_to_r(values_q, chk, plan, label)
    values_r =
        wannier_q_to_pair_wigner_seitz(values_q, chk, plan; support_tolerance = 1.0e-12, label)
    residual = unit_degeneracy_roundtrip_error(values_q, values_r, chk, plan)
    isfinite(residual) || throw(ArgumentError("OPERATOR_DELIVERY_ROUNDTRIP_NONFINITE: $(label)"))
    return values_r, residual
end

"""Transform one spin-family q operator with the profile's pair-dependent WS plan."""
function _profile_spin_q_to_r(values_q, chk, plan, label; construction_policy::Symbol = :strict)
    transform = PairWignerSeitzSpinQToRTransform(
        chk,
        plan,
        PROFILE_PAIR_WIGNER_SEITZ_SUPPORT_TOLERANCE,
        PROFILE_PAIR_WIGNER_SEITZ_ROUNDTRIP_TOLERANCE,
        construction_policy != :standard,
    )
    result = transform_pair_wigner_seitz_spin_q_to_r(transform, values_q, label)
    isfinite(result.diagnostics.max_roundtrip_error) ||
        throw(ArgumentError("FATAL_INTEGRITY: nonfinite spin WS roundtrip"))
    return result.real_space_values, result.diagnostics.max_roundtrip_error
end

"""Construct the MMN connection weighted by the authoritative Hamiltonian."""
function _authoritative_hamiltonian_weighted_connection_q(chk, mmn, stencil, centers, authority)
    output = zeros(ComplexF64, chk.num_orbitals, chk.num_orbitals, 3, chk.num_kpts)
    for kpoint in 1:chk.num_kpts, neighbor in eachindex(stencil.weights)
        source_neighbor = stencil.overlap_order[neighbor, kpoint]
        target = stencil.neighbors[neighbor, kpoint]
        weighted =
            (@view authority.matrices_ev[:, :, kpoint]) *
            (@view mmn.data[:, :, source_neighbor, kpoint])
        wannier =
            (@view chk.v_matrix[:, :, kpoint])' * weighted * (@view chk.v_matrix[:, :, target])
        displacement = @view stencil.displacement_cartesian[neighbor, :]
        apply_wannier_center_phases!(wannier, centers, zeros(3), displacement)
        for cartesian in 1:3
            @views output[:, :, cartesian, kpoint] .+=
                1.0im * stencil.weights[neighbor] * displacement[cartesian] .* wannier
        end
    end
    return output
end

"""Summarize cancellation after an actual finite-difference profile contraction."""
function _profile_final_combination_cancellation_audit(output, absolute_sums, label::AbstractString)
    size(output)[3:end] == size(absolute_sums) ||
        throw(ArgumentError("FINITE_DIFFERENCE_CANCELLATION_DIMENSION_MISMATCH"))
    absolute_values = Float64[]
    final_values = Float64[]
    ratios = Float64[]
    maximum_ratio = -Inf
    worst_context = Dict{String, Any}()
    for indices in CartesianIndices(absolute_sums)
        absolute_sum = Float64(absolute_sums[indices])
        final_norm = norm(view(output,:,:,(Tuple(indices)...)))
        all(isfinite, (absolute_sum, final_norm)) && absolute_sum >= 0.0 ||
            throw(ArgumentError("FINITE_DIFFERENCE_CANCELLATION_NONFINITE"))
        final_norm <= absolute_sum + 1024 * eps(Float64) * max(1.0, absolute_sum) ||
            throw(ArgumentError("FINITE_DIFFERENCE_ABSOLUTE_SUM_BOUND_FAILED"))
        ratio = absolute_sum == 0.0 ? 0.0 : clamp(1.0 - final_norm / absolute_sum, 0.0, 1.0)
        push!(absolute_values, absolute_sum)
        push!(final_values, final_norm)
        push!(ratios, ratio)
        if ratio > maximum_ratio
            maximum_ratio = ratio
            worst_context = Dict(
                "cartesian_first" => indices[1],
                "cartesian_second" => indices[2],
                "kpoint" => indices[3],
            )
        end
    end
    isempty(ratios) && throw(ArgumentError("FINITE_DIFFERENCE_CANCELLATION_EMPTY"))
    return Dict{String, Any}(
        "schema" => "WannierNLQG.final_profile_combination_cancellation_audit",
        "schema_version" => "1.0",
        "status" => "RECORDED",
        "operator" => String(label),
        "qualification_stage" => "FINAL_WANNIER_SUBSPACE_ASSEMBLY",
        "policy" => "AUDIT_ONLY_NOT_AN_ACTUAL_OPERATOR_ERROR_BOUND",
        "semantics" => "1_minus_frobenius_norm_of_final_combination_over_sum_of_frobenius_norms_of_actual_weighted_terms",
        "component_count" => length(ratios),
        "maximum_absolute_sum" => maximum(absolute_values),
        "rms_absolute_sum" => sqrt(sum(abs2, absolute_values) / length(absolute_values)),
        "maximum_final_combination_norm" => maximum(final_values),
        "rms_final_combination_norm" => sqrt(sum(abs2, final_values) / length(final_values)),
        "maximum_cancellation_ratio" => maximum_ratio,
        "rms_cancellation_ratio" => sqrt(sum(abs2, ratios) / length(ratios)),
        "worst_context" => worst_context,
    )
end

"""Construct the uHu-weighted second-derivative tensor in the Wannier gauge."""
function _authoritative_weighted_tensor_q(chk, stencil, centers, uhu_file; formatted::Bool)
    count = length(stencil.weights)
    source_to_internal = _validated_source_to_internal_neighbor_order(stencil, chk.num_kpts)
    output = zeros(ComplexF64, chk.num_orbitals, chk.num_orbitals, 3, 3, chk.num_kpts)
    absolute_sums = zeros(Float64, 3, 3, chk.num_kpts)
    IO.foreach_wannier_uhu_block(
        uhu_file;
        formatted,
        expected_num_bands = chk.num_bands,
        expected_num_kpts = chk.num_kpts,
        expected_num_neighbors = count,
    ) do direct, kpoint, source_second, source_first, _
        first = source_to_internal[source_first, kpoint]
        second = source_to_internal[source_second, kpoint]
        target_first = stencil.neighbors[first, kpoint]
        target_second = stencil.neighbors[second, kpoint]
        wannier =
            (@view chk.v_matrix[:, :, target_first])' *
            direct *
            (@view chk.v_matrix[:, :, target_second])
        first_vector = @view stencil.displacement_cartesian[first, :]
        second_vector = @view stencil.displacement_cartesian[second, :]
        apply_wannier_center_phases!(wannier, centers, first_vector, second_vector)
        weight = stencil.weights[first] * stencil.weights[second]
        for alpha in 1:3, beta in 1:3
            coefficient = weight * first_vector[alpha] * second_vector[beta]
            @views output[:, :, alpha, beta, kpoint] .+= coefficient .* wannier
            absolute_sums[alpha, beta, kpoint] += abs(coefficient) * norm(wannier)
        end
    end
    return (output, _profile_final_combination_cancellation_audit(output, absolute_sums, "uHu"))
end

"""Transform SPN and its authoritative Hamiltonian product to the Wannier gauge."""
function _spin_and_spin_hamiltonian_q(spn, chk, authority; needs_hamiltonian::Bool = true)
    spin = spn_to_wannier_gauge_q(spn, chk; hermitize = true)
    needs_hamiltonian || return spin, nothing
    spin_hamiltonian = zeros(ComplexF64, size(spin))
    for kpoint in 1:chk.num_kpts, axis in 1:3
        source = (@view spn.data[:, :, axis, kpoint]) * (@view authority.matrices_ev[:, :, kpoint])
        gauge = @view chk.v_matrix[:, :, kpoint]
        @views spin_hamiltonian[:, :, axis, kpoint] .= gauge' * source * gauge
    end
    return spin, spin_hamiltonian
end

"""Contract an sIu/sHu link file into a spin-position-like q-space tensor."""
function _spin_link_position_q(
    reader,
    path,
    chk,
    stencil,
    central_q;
    formatted::Bool,
    label::AbstractString,
)
    output = zeros(ComplexF64, chk.num_orbitals, chk.num_orbitals, 3, 3, chk.num_kpts)
    absolute_sums = zeros(Float64, 3, 3, chk.num_kpts)
    reader(
        path;
        formatted,
        expected_num_bands = chk.num_bands,
        expected_num_kpts = chk.num_kpts,
        expected_num_neighbors = length(stencil.weights),
    ) do direct, kpoint, source_neighbor, spin_axis, _
        stencil_neighbor = findfirst(
            index -> stencil.overlap_order[index, kpoint] == source_neighbor,
            eachindex(stencil.weights),
        )
        stencil_neighbor === nothing && throw(
            ArgumentError(
                "spin-link operator neighbor does not occur in the finite-difference stencil",
            ),
        )
        ib = something(stencil_neighbor)
        target = stencil.neighbors[ib, kpoint]
        wannier = (@view chk.v_matrix[:, :, kpoint])' * direct * (@view chk.v_matrix[:, :, target])
        wannier .-= @view central_q[:, :, spin_axis, kpoint]
        displacement = @view stencil.displacement_cartesian[ib, :]
        for cartesian in 1:3
            coefficient = 1.0im * stencil.weights[ib] * displacement[cartesian]
            @views output[:, :, cartesian, spin_axis, kpoint] .+= coefficient .* wannier
            absolute_sums[cartesian, spin_axis, kpoint] += abs(coefficient) * norm(wannier)
        end
    end
    return (output, _profile_final_combination_cancellation_audit(output, absolute_sums, label))
end

"""Return symmetry specifications for all eleven schema-6 profile operators."""
function _operator_profile_specs()
    specs = _exact_bundle_operator_specs()
    specs[REAL_SPACE_SPIN] = RealSpaceOperatorSymmetrySpec(REAL_SPACE_SPIN, 1, 1, -1)
    specs[REAL_SPACE_SPIN_TIMES_HAMILTONIAN] =
        RealSpaceOperatorSymmetrySpec(REAL_SPACE_SPIN_TIMES_HAMILTONIAN, 1, 1, -1)
    specs[REAL_SPACE_SPIN_TIMES_POSITION] =
        RealSpaceOperatorSymmetrySpec(REAL_SPACE_SPIN_TIMES_POSITION, 2, -1, -1)
    specs[REAL_SPACE_SPIN_TIMES_HAMILTONIAN_POSITION] =
        RealSpaceOperatorSymmetrySpec(REAL_SPACE_SPIN_TIMES_HAMILTONIAN_POSITION, 2, -1, -1)
    return specs
end

# Share the same real authority-contract hashes across all assembled inventories.
function _profile_authority_provenance(authority, config)
    return Dict{String, Any}(
        "authoritative_hamiltonian" => authority.authority,
        "authoritative_hamiltonian_digest" => authority.digest,
        "authoritative_hamiltonian_input_sha256" => merge(
            authority.input_sha256,
            Dict(
                "AUTHORITATIVE_HAMILTONIAN_SHA256" => star_authoritative_hamiltonian_sha256(
                    config.input.authoritative_hamiltonian,
                ),
            ),
        ),
    )
end

"""Assemble and provenance-bind the exact inventory for a final output profile."""
function _assemble_wannierization_operator_profile(
    model,
    prepared,
    mmn,
    config::SymmetryAdaptedWannierizationConfig,
    authority::AuthoritativeBandHamiltonian,
    operator_symmetry_plan = nothing;
    target_contract::Union{Nothing, WannierOperatorTargetContract} = nothing,
)
    operators = _tb_operators(model)
    selection = _resolved_operator_selection(config)
    needs_spn = _operator_selection_needs_source(selection, :spn)
    needs_generated = _operator_selection_requires_generated_operators(selection)
    requires_target_contract = _operator_selection_requires_target_contract(selection)
    if !needs_spn && !needs_generated
        qualification = _qualify_spin_family!(
            operators,
            model,
            config,
            operator_symmetry_plan,
            Dict{String, Any}(),
            authority,
        )
        return operators,
        merge(
            _profile_authority_provenance(authority, config),
            Dict{String, Any}("operator_qualification" => qualification),
        )
    end
    chk = something(prepared.wannier_chk)
    gauge_contract = generation_band_gauge_contract(
        config.input.source,
        config.input.authoritative_hamiltonian,
        config.input.wavefunction_gauge_hdf5,
        chk.num_bands,
        chk.num_kpts,
        construction_policy = config.input.construction_policy,
    )
    covariance_residual_value =
        native_hamiltonian_gauge_covariance_residual(authority, gauge_contract)
    if requires_target_contract
        target_contract === nothing && throw(
            ArgumentError("OPERATOR_TARGET_CONTRACT_REQUIRED: qualified-source operator selection"),
        )
        target = something(target_contract)
        validate_operator_target_contract_files(target)
        validate_operator_target_contract_frame(
            target,
            gauge_contract,
            authority.authority,
            chk.num_bands,
            chk.num_kpts,
            mmn.num_neighbors;
            authoritative_hamiltonian_digest = authority.digest,
        )
        target.solver_mmn_sha256 == sha256_file(target.solver_mmn_file) || throw(
            ArgumentError("OPERATOR_TARGET_CONTRACT_MISMATCH: solver MMN changed before export"),
        )
    end
    spn_attestation =
        needs_spn ?
        read_and_validate_spn_provenance(
            _required_profile_file(config.output.spn_provenance_file, "spn_provenance_file"),
            _required_profile_file(config.output.spn_file, "spn_file");
            expected_num_bands = chk.num_bands,
            expected_num_kpoints = chk.num_kpts,
            target_authority = config.input.authoritative_hamiltonian,
            gauge_artifact_sha256 = gauge_contract.gauge_artifact_sha256,
            band_frame_transform_sha256 = gauge_contract.transform_sha256,
            band_frame_contract_sha256 = gauge_contract.contract_sha256,
        ) : nothing
    return _assemble_wannierization_operator_profile_from_qualified_sources(
        model,
        prepared,
        mmn,
        config,
        authority,
        operator_symmetry_plan,
        gauge_contract,
        spn_attestation,
        covariance_residual_value,
        target_contract,
    )
end

"""
Assemble a spin-bearing profile from already validated gauge and SPN contracts.

The production facade above is the only public route into this seam: it first
verifies the sealed gauge artifact, the exact frame-transform digest, and schema-1.2
SPN provenance.  Keeping the numerical assembly here lets focused tests inject
equivalent normalized contracts without weakening the fail-closed facade.
"""
function _assemble_wannierization_operator_profile_from_qualified_sources(
    model,
    prepared,
    mmn,
    config::SymmetryAdaptedWannierizationConfig,
    authority::AuthoritativeBandHamiltonian,
    operator_symmetry_plan,
    gauge_contract,
    spn_attestation,
    native_hamiltonian_gauge_covariance_residual::Real,
    target_contract::Union{Nothing, WannierOperatorTargetContract} = nothing,
)
    operators = _tb_operators(model)
    chk = something(prepared.wannier_chk)
    selection = _resolved_operator_selection(config)
    source_set = Set{Symbol}(IO.resolved_source_inventory(selection))
    inventory = collect(IO.resolved_operator_inventory(selection))
    needs_spn = :spn in source_set
    needs_generated = _operator_selection_requires_generated_operators(selection)
    requires_target_contract = :operator_target_contract in source_set
    spn_attestation =
        needs_spn ?
        merge(
            spn_attestation,
            (
                rotation_sha256 = gauge_contract.transform_sha256,
                frame_contract = band_frame_contract_summary(gauge_contract),
                gauge_artifact_sha256 = something(
                    gauge_contract.gauge_artifact_sha256,
                    "NOT_APPLICABLE",
                ),
                target_band_gauge = gauge_contract.target_band_gauge,
                artifact_sha256 = spn_attestation.spn_sha256,
                authoritative_hamiltonian = "NOT_APPLICABLE",
                authoritative_hamiltonian_digest = "NOT_APPLICABLE",
                authoritative_hamiltonian_input_sha256 = Dict{String, String}(),
            ),
        ) : nothing
    plan = _profile_transform_plan(chk, model)
    specs = _operator_profile_specs()
    spin_q = nothing
    spin_hamiltonian_q = nothing
    spin_roundtrip = NaN
    if needs_spn
        spn_file = _required_profile_file(config.output.spn_file, "spn_file")
        spn_native = IO.read_wannier_spn(spn_file; formatted = config.output.spn_formatted)
        spn_native.num_bands == chk.num_bands && spn_native.num_kpts == chk.num_kpts ||
            throw(ArgumentError("SPN_PROVENANCE_MISMATCH: SPN topology differs from checkpoint"))
        spn_data = similar(spn_native.data)
        for kpoint in 1:chk.num_kpts, axis in 1:3
            @views spn_data[:, :, axis, kpoint] .= rotate_generation_single(
                spn_native.data[:, :, axis, kpoint],
                gauge_contract,
                kpoint,
            )
        end
        spn = IO.WannierSPN(spn_native.num_bands, spn_native.num_kpts, spn_data)
        spin_q, spin_hamiltonian_q = _spin_and_spin_hamiltonian_q(
            spn,
            chk,
            authority;
            needs_hamiltonian = REAL_SPACE_SPIN_TIMES_HAMILTONIAN in inventory ||
                                :shu in source_set,
        )
        spin_r, spin_roundtrip = _profile_spin_q_to_r(
            spin_q,
            chk,
            plan,
            "SPN";
            construction_policy = config.input.construction_policy,
        )
        operators[REAL_SPACE_SPIN] =
            RealSpaceOperator(specs[REAL_SPACE_SPIN], model.r_vectors, spin_r)
    end
    provenance = Dict{String, Any}(
        "operator_profile_assembly_algorithm_version" =>
            WANNIER_OPERATOR_PROFILE_ASSEMBLY_ALGORITHM_VERSION,
        "SPN_sha256" => needs_spn ? sha256_file(spn_file) : "NOT_APPLICABLE",
        "SPN_provenance_sha256" =>
            needs_spn ? String(spn_attestation.provenance_sha256) : "NOT_APPLICABLE",
        "SPN_source_band_gauge" =>
            needs_spn ? String(spn_attestation.source_band_gauge) : "NOT_APPLICABLE",
        "SPN_target_band_gauge" =>
            needs_spn ? String(spn_attestation.qualification_target_band_gauge) : "NOT_APPLICABLE",
        "SPN_band_frame_transform_sha256" => String(gauge_contract.transform_sha256),
        "SPN_band_frame_contract_sha256" => String(gauge_contract.contract_sha256),
        "SPN_band_gauge_rotation_sha256" => String(gauge_contract.transform_sha256),
        "SPN_band_gauge_rotation_semantics" => "legacy_alias_of_band_frame_transform_sha256",
        "SPN_gauge_artifact_sha256" =>
            needs_spn ? String(spn_attestation.gauge_artifact_sha256) : "NOT_APPLICABLE",
        "band_frame_contract" => band_frame_contract_summary(gauge_contract),
        "native_hamiltonian_gauge_covariance_residual_ev" =>
            native_hamiltonian_gauge_covariance_residual,
        "authoritative_hamiltonian" => authority.authority,
        "authoritative_hamiltonian_digest" => authority.digest,
        "pair_wigner_seitz_transform_algorithm" =>
            PROFILE_PAIR_WIGNER_SEITZ_TRANSFORM_ALGORITHM,
        "pair_wigner_seitz_roundtrip_policy" => PROFILE_PAIR_WIGNER_SEITZ_STORAGE_POLICY,
        "pair_wigner_seitz_roundtrip_tolerance" =>
            PROFILE_PAIR_WIGNER_SEITZ_ROUNDTRIP_TOLERANCE,
        "pair_wigner_seitz_roundtrip_residuals" =>
            needs_spn ? Dict{String, Any}("spin" => spin_roundtrip) : Dict{String, Any}(),
    )
    merge!(provenance, _profile_authority_provenance(authority, config))
    if !requires_target_contract && !needs_generated
        provenance["operator_qualification"] = _qualify_spin_family!(
            operators,
            model,
            config,
            operator_symmetry_plan,
            spn_attestation,
            authority;
            pair_wigner_seitz_roundtrip_residuals = provenance["pair_wigner_seitz_roundtrip_residuals"],
        )
        return operators, provenance
    end

    stencil = match_finite_difference_stencil_to_mmn(build_finite_difference_stencil(chk), chk, mmn)
    source_neighbor_order_contract =
        (:uiu in source_set || :uhu in source_set) ?
        _streamed_neighbor_order_contract(stencil, chk.num_kpts) : nothing
    centers = _tb_centers(model)
    paths, sidecars = _profile_operator_paths(config, source_set)
    complete_family = _operator_selection_is_complete_family(selection)
    requires_target_contract &&
        target_contract === nothing &&
        throw(
            ArgumentError("OPERATOR_TARGET_CONTRACT_REQUIRED: qualified-source operator selection"),
        )
    target = requires_target_contract ? something(target_contract) : nothing
    if requires_target_contract
        provenance["operator_target_contract_sha256"] = target.contract_sha256
        provenance["operator_oracle_mmn_sha256"] = target.operator_oracle_mmn_sha256
        provenance["solver_mmn_sha256"] = target.solver_mmn_sha256
    end
    uiu_provenance = nothing
    uiu_input_sha256 = nothing
    if :uiu in source_set
        uiu_provenance = _qualified_uiu_sidecar(
            sidecars[:uIu],
            paths[:uIu],
            target.operator_oracle_mmn_file,
            gauge_contract;
            construction_policy = config.input.construction_policy,
        )
        uiu_input_sha256 = _profile_input_hashes(uiu_provenance.input_sha256, "uIu")
        _require_operator_target_contract_hash(uiu_input_sha256, "uIu", target)
        provenance["uIu_input_sha256"] = copy(uiu_input_sha256)
        provenance["derivative_overlap_source"] = "wannier90_uIu"
        provenance["derivative_overlap_completeness"] = "full_hilbert_space"
        provenance["derivative_overlap_source_sha256"] = String(uiu_provenance.output_sha256)
        provenance["derivative_overlap_algorithm_version"] =
            IO.FULL_DERIVATIVE_OVERLAP_ALGORITHM_VERSION
    end
    spn_input_sha256 =
        needs_spn ? _profile_input_hashes(spn_attestation.input_sha256, "SPN provenance") : nothing
    common_reference = uiu_input_sha256 !== nothing ? uiu_input_sha256 : spn_input_sha256
    finite_band_source_risk_audit = Dict{String, Any}()
    hamiltonian_sidecars = Dict{Symbol, Any}()
    hamiltonian_input_sha256 = Dict{Symbol, Dict{String, String}}()
    for operator in (:uHu, :sIu, :sHu)
        _PROFILE_OPERATOR_SOURCE_SYMBOLS[operator] in source_set || continue
        common_reference === nothing && throw(
            ArgumentError(
                "OPERATOR_SOURCE_INPUT_REQUIRED: $(operator) sidecar has no common physical-source reference",
            ),
        )
        payload, risk_audit, input_sha256 = _qualified_hamiltonian_operator_sidecar(
            sidecars[operator],
            operator,
            paths[operator],
            authority,
            config.output.operator_closure_tolerance,
            gauge_contract,
            needs_spn ? String(spn_attestation.provenance_sha256) : "NOT_APPLICABLE",
            common_reference,
            spn_input_sha256,
            needs_spn ? String(spn_attestation.spn_sha256) : "NOT_APPLICABLE",
        )
        hamiltonian_sidecars[operator] = payload
        hamiltonian_input_sha256[operator] = input_sha256
        _require_operator_target_contract_hash(input_sha256, String(operator), target)
        finite_band_source_risk_audit[String(operator)] = risk_audit
        provenance["$(operator)_generation_algorithm_version"] = String(payload.algorithm_version)
        provenance["$(operator)_input_sha256"] = copy(input_sha256)
    end
    final_projector_galerkin_audit =
        complete_family ?
        _profile_final_projector_leakage_audit(chk, mmn, config.output.operator_closure_tolerance) :
        nothing

    full_derivative_r = nothing
    full_derivative_roundtrip = NaN
    axial_r = nothing
    symmetric_r = nothing
    if :uiu in source_set
        full_derivative_q = _construct_exact_full_derivative_overlap_tensor_q(
            chk,
            stencil,
            centers,
            paths[:uIu];
            formatted = config.output.operator_files_formatted,
        )
        full_derivative_r, full_derivative_roundtrip =
            _profile_q_to_r(full_derivative_q, chk, plan, "derivative_overlap_tensor")
        axial_r, symmetric_r = derive_axial_and_symmetric_derivative_overlaps(full_derivative_r)
    end
    weighted_connection_r = nothing
    weighted_connection_roundtrip = NaN
    if REAL_SPACE_HAMILTONIAN_WEIGHTED_CONNECTION in inventory
        weighted_connection_q =
            _authoritative_hamiltonian_weighted_connection_q(chk, mmn, stencil, centers, authority)
        weighted_connection_r, weighted_connection_roundtrip =
            _profile_q_to_r(weighted_connection_q, chk, plan, "hamiltonian_weighted_connection")
    end
    weighted_axial_r = nothing
    weighted_tensor_roundtrip = NaN
    uhu_cancellation_audit = nothing
    if :uhu in source_set
        weighted_tensor_q, uhu_cancellation_audit = _authoritative_weighted_tensor_q(
            chk,
            stencil,
            centers,
            paths[:uHu];
            formatted = config.output.operator_files_formatted,
        )
        weighted_tensor_r, weighted_tensor_roundtrip = _profile_q_to_r(
            weighted_tensor_q,
            chk,
            plan,
            "hamiltonian_weighted_derivative_overlap_tensor",
        )
        weighted_axial_r, _ = derive_axial_and_symmetric_derivative_overlaps(weighted_tensor_r)
        weighted_axial_r = hermitianize_real_space_pairs(weighted_axial_r, model.r_vectors)
    end
    spin_hamiltonian_r = nothing
    spin_hamiltonian_roundtrip = NaN
    if REAL_SPACE_SPIN_TIMES_HAMILTONIAN in inventory
        spin_hamiltonian_r, spin_hamiltonian_roundtrip = _profile_spin_q_to_r(
            spin_hamiltonian_q,
            chk,
            plan,
            "SPN-times-authoritative-H";
            construction_policy = config.input.construction_policy,
        )
    end
    spin_position_r = nothing
    spin_position_roundtrip = NaN
    siu_cancellation_audit = nothing
    if :siu in source_set
        spin_position_q, siu_cancellation_audit = _spin_link_position_q(
            IO.foreach_wannier_siu_block,
            paths[:sIu],
            chk,
            stencil,
            spin_q;
            formatted = config.output.operator_files_formatted,
            label = "sIu",
        )
        spin_position_r, spin_position_roundtrip = _profile_spin_q_to_r(
            spin_position_q,
            chk,
            plan,
            "sIu-spin-position";
            construction_policy = config.input.construction_policy,
        )
    end
    spin_hamiltonian_position_r = nothing
    spin_hamiltonian_position_roundtrip = NaN
    shu_cancellation_audit = nothing
    if :shu in source_set
        spin_hamiltonian_position_q, shu_cancellation_audit = _spin_link_position_q(
            IO.foreach_wannier_shu_block,
            paths[:sHu],
            chk,
            stencil,
            spin_hamiltonian_q;
            formatted = config.output.operator_files_formatted,
            label = "sHu",
        )
        spin_hamiltonian_position_r, spin_hamiltonian_position_roundtrip = _profile_spin_q_to_r(
            spin_hamiltonian_position_q,
            chk,
            plan,
            "sHu-spin-H-position";
            construction_policy = config.input.construction_policy,
        )
    end
    spin_roundtrip_by_source = Dict{Symbol, Any}(
        :spn => spin_hamiltonian_roundtrip,
        :siu => spin_position_roundtrip,
        :shu => spin_hamiltonian_position_roundtrip,
    )
    spin_roundtrip_names = Dict{Symbol, String}(
        :spn => "spin_times_hamiltonian",
        :siu => "spin_times_position",
        :shu => "spin_times_hamiltonian_position",
    )
    for source in (:spn, :siu, :shu)
        source in source_set || continue
        source == :spn && !(REAL_SPACE_SPIN_TIMES_HAMILTONIAN in inventory) && continue
        provenance["pair_wigner_seitz_roundtrip_residuals"][spin_roundtrip_names[source]] =
            spin_roundtrip_by_source[source]
    end
    resolved_operator_values = Dict{RealSpaceOperatorKind, Any}(
        REAL_SPACE_HAMILTONIAN_WEIGHTED_CONNECTION => weighted_connection_r,
        REAL_SPACE_HAMILTONIAN_WEIGHTED_AXIAL_DERIVATIVE_OVERLAP => weighted_axial_r,
        REAL_SPACE_DERIVATIVE_OVERLAP_TENSOR => full_derivative_r,
        REAL_SPACE_AXIAL_DERIVATIVE_OVERLAP => axial_r,
        REAL_SPACE_SYMMETRIC_DERIVATIVE_OVERLAP => symmetric_r,
        REAL_SPACE_SPIN_TIMES_HAMILTONIAN => spin_hamiltonian_r,
        REAL_SPACE_SPIN_TIMES_POSITION => spin_position_r,
        REAL_SPACE_SPIN_TIMES_HAMILTONIAN_POSITION => spin_hamiltonian_position_r,
    )
    for kind in inventory
        kind in (REAL_SPACE_HAMILTONIAN, REAL_SPACE_POSITION, REAL_SPACE_SPIN) && continue
        array = resolved_operator_values[kind]
        array === nothing && throw(
            ArgumentError(
                "OPERATOR_PROFILE_ASSEMBLY_INCOMPLETE: $(real_space_operator_name(kind))",
            ),
        )
        operators[kind] = RealSpaceOperator(specs[kind], model.r_vectors, array)
    end
    for (operator, path) in paths
        provenance["$(operator)_sha256"] = sha256_file(path)
        provenance["$(operator)_provenance_sha256"] = sha256_file(sidecars[operator])
    end
    provenance["finite_band_risk_audit"] = deepcopy(finite_band_source_risk_audit)
    provenance["final_projector_galerkin_audit"] = deepcopy(final_projector_galerkin_audit)
    provenance["finite_band_diagnostic_reference"] = config.output.operator_closure_tolerance
    provenance["finite_band_diagnostic_reference_policy"] = "AUDIT_ONLY_NOT_AN_ACTUAL_OPERATOR_ERROR_BOUND"
    provenance["finite_band_actual_operator_error_status"] = "NOT_AVAILABLE_WITHOUT_COMPLEMENT_HAMILTONIAN_OR_NBANDS_REFERENCE"
    provenance["finite_band_nbands_convergence_status"] = "NOT_ESTABLISHED"
    final_combination_cancellation_audit = Dict{String, Any}()
    :uhu in source_set && (final_combination_cancellation_audit["uHu"] = uhu_cancellation_audit)
    :siu in source_set && (final_combination_cancellation_audit["sIu"] = siu_cancellation_audit)
    :shu in source_set && (final_combination_cancellation_audit["sHu"] = shu_cancellation_audit)
    provenance["final_combination_cancellation_audit"] =
        deepcopy(final_combination_cancellation_audit)
    delivery_roundtrip_residuals = Dict{String, Float64}(
        real_space_operator_name(REAL_SPACE_HAMILTONIAN) => 0.0,
        real_space_operator_name(REAL_SPACE_POSITION) => 0.0,
    )
    REAL_SPACE_HAMILTONIAN_WEIGHTED_CONNECTION in inventory && (
        delivery_roundtrip_residuals[real_space_operator_name(
            REAL_SPACE_HAMILTONIAN_WEIGHTED_CONNECTION,
        )] = weighted_connection_roundtrip
    )
    :uiu in source_set && (
        delivery_roundtrip_residuals[real_space_operator_name(
            REAL_SPACE_DERIVATIVE_OVERLAP_TENSOR,
        )] = full_derivative_roundtrip
    )
    :uiu in source_set && (
        delivery_roundtrip_residuals[real_space_operator_name(
            REAL_SPACE_AXIAL_DERIVATIVE_OVERLAP,
        )] = full_derivative_roundtrip
    )
    :uiu in source_set && (
        delivery_roundtrip_residuals[real_space_operator_name(
            REAL_SPACE_SYMMETRIC_DERIVATIVE_OVERLAP,
        )] = full_derivative_roundtrip
    )
    :uhu in source_set && (
        delivery_roundtrip_residuals[real_space_operator_name(
            REAL_SPACE_HAMILTONIAN_WEIGHTED_AXIAL_DERIVATIVE_OVERLAP,
        )] = weighted_tensor_roundtrip
    )
    provenance["operator_delivery_roundtrip_residuals"] = deepcopy(delivery_roundtrip_residuals)
    if :uiu in source_set
        provenance["uiu_generation_algorithm_version"] = String(uiu_provenance.algorithm_version)
        provenance["uiu_generation_status"] = String(
            get(uiu_provenance, :status, Bool(uiu_provenance.passed) ? "PASS" : "FAILED_GATE"),
        )
        if !Bool(uiu_provenance.passed)
            provenance["uiu_generation_numerical_warning"] =
                Dict{String, Any}(String(key) => value for (key, value) in pairs(uiu_provenance))
        end
    end
    spn_source =
        needs_spn ?
        (
            provenance_sha256 = spn_attestation.provenance_sha256,
            artifact_sha256 = spn_attestation.spn_sha256,
            source_band_gauge = gauge_contract.source_band_gauge,
            target_band_gauge = gauge_contract.target_band_gauge,
            gauge_artifact_sha256 = something(
                gauge_contract.gauge_artifact_sha256,
                "NOT_APPLICABLE",
            ),
            rotation_sha256 = gauge_contract.transform_sha256,
            frame_contract = band_frame_contract_summary(gauge_contract),
            input_sha256 = spn_input_sha256,
            authoritative_hamiltonian = "NOT_APPLICABLE",
            authoritative_hamiltonian_digest = "NOT_APPLICABLE",
            authoritative_hamiltonian_input_sha256 = Dict{String, String}(),
        ) : nothing
    function sidecar_source(operator::Symbol, kind::RealSpaceOperatorKind)
        payload = hamiltonian_sidecars[operator]
        requires_hamiltonian = kind in (
            REAL_SPACE_HAMILTONIAN_WEIGHTED_AXIAL_DERIVATIVE_OVERLAP,
            REAL_SPACE_SPIN_TIMES_HAMILTONIAN,
            REAL_SPACE_SPIN_TIMES_HAMILTONIAN_POSITION,
        )
        return (
            provenance_sha256 = sha256_file(sidecars[operator]),
            artifact_sha256 = sha256_file(paths[operator]),
            source_band_gauge = String(payload.source_band_gauge),
            target_band_gauge = String(payload.target_band_gauge),
            gauge_artifact_sha256 = String(payload.gauge_artifact_sha256),
            rotation_sha256 = String(payload.band_frame_transform_sha256),
            frame_contract = Dict{String, Any}(
                String(key) => value for (key, value) in pairs(payload.band_frame_contract)
            ),
            input_sha256 = hamiltonian_input_sha256[operator],
            authoritative_hamiltonian = requires_hamiltonian ? authority.authority :
                                        "NOT_APPLICABLE",
            authoritative_hamiltonian_digest = requires_hamiltonian ? authority.digest :
                                               "NOT_APPLICABLE",
            authoritative_hamiltonian_input_sha256 = requires_hamiltonian ?
                                                     copy(authority.input_sha256) :
                                                     Dict{String, String}(),
            finite_band_risk_audit = finite_band_source_risk_audit[String(operator)],
        )
    end
    function uiu_source(kind::RealSpaceOperatorKind)
        return (
            provenance_sha256 = sha256_file(sidecars[:uIu]),
            artifact_sha256 = sha256_file(paths[:uIu]),
            source_band_gauge = String(uiu_provenance.source_band_gauge),
            target_band_gauge = String(uiu_provenance.target_band_gauge),
            gauge_artifact_sha256 = String(uiu_provenance.gauge_artifact_sha256),
            rotation_sha256 = String(uiu_provenance.band_frame_transform_sha256),
            frame_contract = Dict{String, Any}(
                String(key) => value for (key, value) in pairs(uiu_provenance.band_frame_contract)
            ),
            input_sha256 = uiu_input_sha256,
            authoritative_hamiltonian = "NOT_APPLICABLE",
            authoritative_hamiltonian_digest = "NOT_APPLICABLE",
            authoritative_hamiltonian_input_sha256 = Dict{String, String}(),
        )
    end
    spin_hamiltonian_source =
        needs_spn ?
        merge(
            spn_source,
            (
                authoritative_hamiltonian = authority.authority,
                authoritative_hamiltonian_digest = authority.digest,
                authoritative_hamiltonian_input_sha256 = copy(authority.input_sha256),
            ),
        ) : nothing
    function weighted_connection_source()
        return (
            provenance_sha256 = target.solver_mmn_sha256,
            artifact_sha256 = _authoritative_array_sha256(
                operators[REAL_SPACE_HAMILTONIAN_WEIGHTED_CONNECTION].data,
            ),
            source_band_gauge = gauge_contract.source_band_gauge,
            target_band_gauge = gauge_contract.target_band_gauge,
            gauge_artifact_sha256 = something(
                gauge_contract.gauge_artifact_sha256,
                "NOT_APPLICABLE",
            ),
            rotation_sha256 = gauge_contract.transform_sha256,
            frame_contract = band_frame_contract_summary(gauge_contract),
            input_sha256 = Dict(
                "MMN" => target.solver_mmn_sha256,
                "OPERATOR_TARGET_CONTRACT" => target.contract_sha256,
                "AUTHORITATIVE_HAMILTONIAN" => authority.digest,
            ),
            authoritative_hamiltonian = authority.authority,
            authoritative_hamiltonian_digest = authority.digest,
            authoritative_hamiltonian_input_sha256 = copy(authority.input_sha256),
        )
    end
    operator_sources = Dict{String, Any}()
    for kind in inventory
        kind in (REAL_SPACE_HAMILTONIAN, REAL_SPACE_POSITION) && continue
        name = real_space_operator_name(kind)
        if kind == REAL_SPACE_SPIN
            operator_sources[name] = spn_source
        elseif kind == REAL_SPACE_SPIN_TIMES_HAMILTONIAN
            operator_sources[name] = spin_hamiltonian_source
        elseif kind == REAL_SPACE_HAMILTONIAN_WEIGHTED_CONNECTION
            operator_sources[name] = weighted_connection_source()
        elseif kind == REAL_SPACE_HAMILTONIAN_WEIGHTED_AXIAL_DERIVATIVE_OVERLAP
            operator_sources[name] = sidecar_source(:uHu, kind)
        elseif kind in (
            REAL_SPACE_DERIVATIVE_OVERLAP_TENSOR,
            REAL_SPACE_AXIAL_DERIVATIVE_OVERLAP,
            REAL_SPACE_SYMMETRIC_DERIVATIVE_OVERLAP,
        )
            operator_sources[name] = uiu_source(kind)
        elseif kind == REAL_SPACE_SPIN_TIMES_POSITION
            operator_sources[name] = sidecar_source(:sIu, kind)
        elseif kind == REAL_SPACE_SPIN_TIMES_HAMILTONIAN_POSITION
            operator_sources[name] = sidecar_source(:sHu, kind)
        else
            throw(
                ArgumentError(
                    "OPERATOR_PROFILE_ASSEMBLY_UNSUPPORTED_OPERATOR: $(real_space_operator_name(kind))",
                ),
            )
        end
    end
    qualified_sources =
        needs_spn ? merge(spn_attestation, (; operator_sources)) : (; operator_sources)
    provenance["operator_qualification"] = _qualify_spin_family!(
        operators,
        model,
        config,
        operator_symmetry_plan,
        qualified_sources,
        authority;
        final_projector_galerkin_audit = final_projector_galerkin_audit,
        finite_band_source_risk_audit = complete_family ? finite_band_source_risk_audit : nothing,
        final_combination_cancellation_audit = complete_family ?
                                               final_combination_cancellation_audit : nothing,
        pair_wigner_seitz_roundtrip_residuals = provenance["pair_wigner_seitz_roundtrip_residuals"],
        delivery_roundtrip_residuals = delivery_roundtrip_residuals,
        operator_target_contract = target,
        source_neighbor_order_contract = source_neighbor_order_contract,
    )
    return operators, provenance
end
