"""Share at most one strictly restored gauge payload while building compact contracts."""
function _with_generation_gauge_reuse(f::F) where {F}
    context = (owner = current_task(), slot = Ref{Any}(nothing))
    try
        task_local_storage(f, :wannier_generation_gauge_reuse, context)
    finally
        context.slot[] = nothing
    end
end

"""Read actual gauge inputs without digest-only reuse; retain scientific validation."""
function _read_generation_gauge(
    path::AbstractString;
    construction_policy,
    source,
    reader = _read_star_covariant_paw_gauge_hdf5,
)
    # A previous digest-only memo cannot establish equality of current input.
    # Re-read the actual gauge and retain the reader's scientific validation.
    observed = IO.with_scientific_source(path; resolve_links = true) do filename
        reader(filename; construction_policy, source)
    end
    return observed.value
end

"""Encode an identity transform with the same byte contract as a sealed frame map."""
function _identity_band_transform_definition(num_bands::Int, num_kpts::Int)
    num_bands > 0 && num_kpts > 0 || throw(ArgumentError("band-gauge dimensions must be positive"))
    transforms = zeros(ComplexF64, num_bands, num_bands, num_kpts)
    for kpoint in 1:num_kpts
        for band in 1:num_bands
            transforms[band, band, kpoint] = 1.0
        end
    end
    return band_frame_transform_definition(transforms)
end

"""Return the identity-frame contract used by ordinary native DFT."""
function _identity_band_frame_contract(
    num_bands::Int,
    num_kpts::Int;
    metric_kind::AbstractString = "not_applicable_native_identity",
)
    transform_definition = _identity_band_transform_definition(num_bands, num_kpts)
    contract_definition = band_frame_contract_definition(
        NATIVE_DFT_BAND_GAUGE,
        NATIVE_DFT_BAND_GAUGE,
        transform_definition,
        metric_kind,
        0.0,
        0.0,
        0.0,
        0.0,
        0.0,
        1.0,
        1.0,
    )
    return BandFrameTransformContract(
        NATIVE_DFT_BAND_GAUGE,
        NATIVE_DFT_BAND_GAUGE,
        nothing,
        transform_definition,
        contract_definition,
        nothing,
        String(metric_kind),
        0.0,
        0.0,
        0.0,
        0.0,
        0.0,
        1.0,
        1.0,
        BAND_FRAME_TRANSFORM_CONTRACT_SCHEMA,
        BAND_FRAME_TRANSFORM_CONTRACT_SCHEMA_VERSION,
        "PASS",
        false,
    )
end

"""Apply `T_k† O_k T_k` to a one-k-point operator."""
function _transform_single_point_operator(operator, left_transform)
    size(operator, 1) == size(operator, 2) == size(left_transform, 1) == size(left_transform, 2) ||
        throw(ArgumentError("single-point band-gauge dimensions differ"))
    return left_transform' * operator * left_transform
end

"""Apply `T_k† O_{k,k+b} T_{k+b}` to a link operator."""
function _transform_link_operator(operator, left_transform, right_transform)
    size(operator, 1) == size(left_transform, 1) == size(left_transform, 2) ||
        throw(ArgumentError("link left band-gauge dimensions differ"))
    size(operator, 2) == size(right_transform, 1) == size(right_transform, 2) ||
        throw(ArgumentError("link right band-gauge dimensions differ"))
    return left_transform' * operator * right_transform
end

"""Apply the endpoint frame transforms to a neighbor-neighbor operator."""
_transform_double_endpoint_operator(operator, first_transform, second_transform) =
    _transform_link_operator(operator, first_transform, second_transform)

"""Resolve an implicit full native band range only for a sealed full-space gauge.

The native operator source remains unchanged. Explicit selections retain their
identity and are checked by the established gauge reader.
"""
function _generation_gauge_source(source, gauge_hdf5)
    gauge_hdf5 === nothing && return source
    source isa Union{QuantumEspressoWavefunctionSource, VASPWavefunctionSource} || return source
    source.band_range === nothing || return source
    band_range = HDF5.h5open(gauge_hdf5, "r") do handle
        attributes = HDF5.attributes(handle)
        target =
            Int(read(attributes["target_band_start"])):Int(read(attributes["target_band_stop"]))
        parent =
            Int(read(attributes["parent_band_start"])):Int(read(attributes["parent_band_stop"]))
        target == parent && first(target) == 1 && !isempty(target) || throw(
            ArgumentError(
                "WAVEFUNCTION_GAUGE_ARTIFACT_MISMATCH: implicit full source cannot select a gauge subset",
            ),
        )
        target
    end
    return _star_source_with_band_range(source, band_range)
end

"""Reuse only a sealed compact frame contract, never a full restored gauge payload."""
function _generation_band_gauge_contract(
    source,
    authority,
    gauge_hdf5,
    num_bands::Int,
    num_kpts::Int;
    construction_policy::Symbol = :standard,
)
    source = _generation_gauge_source(source, gauge_hdf5)
    # A digest-only cached frame cannot certify current physical input.
    return _build_generation_band_gauge_contract(
        source,
        authority,
        gauge_hdf5,
        num_bands,
        num_kpts;
        construction_policy,
    )
end

"""Resolve and verify the exact band-gauge transformation requested by a generator."""
function _build_generation_band_gauge_contract(
    source,
    authority,
    gauge_hdf5,
    num_bands::Int,
    num_kpts::Int;
    construction_policy::Symbol = :standard,
)
    validate_ordinary_construction_policy(construction_policy)
    if authority isa NativeDFTHamiltonian && gauge_hdf5 === nothing
        return _identity_band_frame_contract(num_bands, num_kpts)
    elseif authority isa NativeDFTHamiltonian || authority isa SymmetrizedDFTHamiltonian
        gauge_hdf5 === nothing && throw(
            ArgumentError(
                "SYMMETRIZED_HAMILTONIAN_ARTIFACT_REQUIRED: wavefunction_gauge_hdf5 is missing",
            ),
        )
        path = abspath(something(gauge_hdf5))
        restored = _read_generation_gauge(path; construction_policy, source)
        _validate_star_gauge_source_identity(source, restored.payload)
        artifact_authority = get(restored.payload.source_metadata, "authoritative_hamiltonian", "")
        requested_authority = authoritative_hamiltonian_key(authority)
        artifact_authority == requested_authority || throw(
            ArgumentError(
                "HAMILTONIAN_REFERENCE_MISMATCH: gauge artifact authority $(artifact_authority) differs from $(requested_authority)",
            ),
        )
        target_band_gauge = if authority isa SymmetrizedDFTHamiltonian
            audit = restored.payload.symmetrized_hamiltonian_audit
            audit === nothing && throw(
                ArgumentError(
                    "SYMMETRIZED_HAMILTONIAN_DATA_REQUIRED: gauge artifact has no Reynolds-projected audit payload",
                ),
            )
            SYMMETRIZED_DFT_BAND_GAUGE
        else
            SAWF_COMPLETED_NATIVE_DFT_BAND_GAUGE
        end
        # The formal frame transform is the value-bound raw-source to completed-frame
        # map stored as `native_to_completed_rotations`.  The similarly shaped array in
        # the symmetrized-Hamiltonian audit is independent Hamiltonian evidence and must
        # not replace the frame transform merely because the requested authority is
        # symmetrized.
        transforms = copy(restored.payload.rotations)
        size(transforms) == (num_bands, num_bands, num_kpts) || throw(
            ArgumentError(
                "BAND_FRAME_DIMENSION_MISMATCH: expected ($(num_bands), $(num_bands), $(num_kpts)), got $(size(transforms))",
            ),
        )
        all(isfinite, transforms) ||
            throw(ArgumentError("BAND_FRAME_NONFINITE: transform contains NaN or Inf"))
        transform_definition = band_frame_transform_definition(transforms)
        restored.band_frame_contract === nothing && throw(
            ArgumentError(
                "BAND_FRAME_EXPLICIT_MIGRATION_REQUIRED: actual current frame contract is missing",
            ),
        )
        sealed = something(restored.band_frame_contract)
        sealed.transform_definition == transform_definition ||
            throw(ArgumentError("BAND_FRAME_TRANSFORM_VALUES_MISMATCH"))
        sealed.source_band_gauge == NATIVE_DFT_BAND_GAUGE ||
            throw(ArgumentError("BAND_FRAME_SOURCE_MISMATCH: source gauge differs"))
        sealed.target_band_gauge == target_band_gauge ||
            throw(ArgumentError("BAND_FRAME_TARGET_MISMATCH: target gauge differs"))
        sealed.legacy && throw(ArgumentError("BAND_FRAME_COMPLETE_DATA_REQUIRED"))
        return BandFrameTransformContract(
            sealed.source_band_gauge,
            sealed.target_band_gauge,
            transforms,
            sealed.transform_definition,
            sealed.contract_definition,
            sealed.gauge_definition,
            sealed.metric_kind,
            sealed.physical_isometry_maximum,
            sealed.physical_isometry_tolerance,
            sealed.replay_maximum,
            sealed.replay_tolerance,
            sealed.euclidean_nonunitarity_maximum,
            sealed.minimum_singular_value,
            sealed.maximum_condition_number,
            sealed.schema,
            sealed.schema_version,
            sealed.status,
            sealed.legacy,
        )
    end
    throw(ArgumentError("unsupported authoritative Hamiltonian backend"))
end

"""Return the exact-congruence construction residual for native authority.

A completed PAW frame is not an eigenstate gauge and need not leave diagonal
EIG matrices invariant.  Its target-frame Hamiltonian is defined by `T' H T`,
so the construction residual is identically zero once the frame contract has
passed.
"""
function _native_hamiltonian_gauge_covariance_residual(authority, gauge_contract)
    gauge_contract.legacy &&
        gauge_contract.transforms !== nothing &&
        throw(ArgumentError("BAND_FRAME_COMPLETE_DATA_REQUIRED"))
    return 0.0
end

"""Return the frame transform at one k-point, or an allocation-free identity marker."""
_generation_transform(contract, kpoint::Int) =
    contract.transforms === nothing ? nothing : @view(contract.transforms[:, :, kpoint])

"""Transform one generated link into the target frame, preserving native values exactly."""
function _transform_generation_link(operator, contract, left::Int, right::Int)
    contract.transforms === nothing && return Matrix{ComplexF64}(operator)
    return _transform_link_operator(
        operator,
        _generation_transform(contract, left),
        _generation_transform(contract, right),
    )
end

"""Transform one generated single-k operator into the target band frame."""
function _transform_generation_single(operator, contract, kpoint::Int)
    contract.transforms === nothing && return Matrix{ComplexF64}(operator)
    return _transform_single_point_operator(operator, _generation_transform(contract, kpoint))
end

"""Persist only references needed by later SPN source and payload consumers."""
function _write_spn_complete_references(group, native, artifacts)
    native.source_definition === nothing && throw(ArgumentError("SPN_SOURCE_REFERENCE_REQUIRED"))
    HDF5.attributes(group)["content_authentication"]="NOT_PERFORMED"
    write_scientific_input_reference_hdf5(
        group,
        "native_source_reference",
        native.source_definition,
    )
    if haskey(artifacts, "spn")
        reference=IO.scientific_source_collection_definition(Dict("SPN"=>artifacts["spn"]))
        write_scientific_input_reference_hdf5(group, "spn_reference", reference)
    end
    return nothing
end

"""Read complete reference bytes without claiming digest authentication."""
function _read_spn_complete_references(group)
    haskey(HDF5.attributes(group), "content_authentication") &&
    String(read(HDF5.attributes(group)["content_authentication"]))=="NOT_PERFORMED" ||
        throw(ArgumentError("SPN_EXPLICIT_MIGRATION_REQUIRED"))
    haskey(group, "native_source_reference") ||
        throw(ArgumentError("SPN_SOURCE_REFERENCE_REQUIRED"))
    return (
        source_reference = read_scientific_input_reference_hdf5(group, "native_source_reference"),
        spn_reference = haskey(group, "spn_reference") ?
                        read_scientific_input_reference_hdf5(group, "spn_reference") : nothing,
    )
end

"""Check a later SPN consumer against complete published bytes."""
function _validate_spn_reference(record, path)
    record.spn_reference === nothing && throw(ArgumentError("SPN_COMPLETE_REFERENCE_REQUIRED"))
    IO.validate_scientific_source_collection(Dict("SPN"=>String(path)), record.spn_reference)
    return nothing
end

"""Check concrete SPN residuals; no persisted pass/fail label authorizes data."""
function _validate_spn_residual_data(values, thresholds, oracle, require_oracle; radial = false)
    keys =
        radial ?
        (
            "radial_q_max_absolute",
            "generalized_norm_max_absolute",
            "hermiticity_max_absolute",
            "diagonal_imaginary_max_absolute",
        ) :
        (
            "generalized_norm_max_absolute",
            "hermiticity_max_absolute",
            "diagonal_imaginary_max_absolute",
        )
    for key in keys
        haskey(values, key) && haskey(thresholds, key) ||
            throw(ArgumentError("SPN_RESIDUAL_DATA_MISSING: $(key)"))
        value, limit = Float64(values[key]), Float64(thresholds[key])
        isfinite(value) && value >= 0 && isfinite(limit) && limit >= 0 ||
            throw(ArgumentError("SPN_RESIDUAL_DATA_INVALID: $(key)"))
        value <= limit || throw(ArgumentError("SPN_RESIDUAL_EXCEEDED: $(key)"))
    end
    require_oracle && oracle === nothing && throw(ArgumentError("SPN_REQUIRED_ORACLE_DATA_MISSING"))
    if oracle !== nothing
        get(oracle, "finite", false) === true || throw(ArgumentError("SPN_ORACLE_NONFINITE"))
        for (key, threshold) in (
            ("max_absolute", "oracle_max_absolute"),
            ("root_mean_square", "oracle_rms"),
            ("relative_l2", "oracle_relative_l2"),
        )
            haskey(oracle, key) && haskey(thresholds, threshold) ||
                throw(ArgumentError("SPN_ORACLE_DATA_MISSING: $(key)"))
            value, limit = Float64(oracle[key]), Float64(thresholds[threshold])
            isfinite(value) && value >= 0 && isfinite(limit) && limit >= 0 ||
                throw(ArgumentError("SPN_ORACLE_DATA_INVALID: $(key)"))
            value <= limit || throw(ArgumentError("SPN_ORACLE_RESIDUAL_EXCEEDED: $(key)"))
        end
    end
    return nothing
end

"""Read, seal-check, and normalize a QE PAW-SPN provenance JSON sidecar."""
function read_qe_paw_spn_provenance(filename::AbstractString; verify_spn::Bool = true)
    path = abspath(filename)
    isfile(path) || throw(ArgumentError("QE PAW-SPN provenance file does not exist"))
    payload = JSON3.read(read(path, String), Dict{String, Any})
    String(get(payload, "schema", "")) == QE_PAW_SPN_SCHEMA ||
        throw(ArgumentError("QE_PAW_SPN_PROVENANCE_SCHEMA_MISMATCH"))
    schema_version = String(get(payload, "schema_version", ""))
    schema_version == QE_PAW_SPN_SCHEMA_VERSION ||
        throw(ArgumentError("QE_PAW_SPN_PROVENANCE_VERSION_MISMATCH"))
    any(
        haskey(payload, key) for
        key in ("band_gauge_rotation_sha256", "band_gauge_rotation_semantics")
    ) && throw(ArgumentError("QE_PAW_SPN_LEGACY_ROTATION_FIELDS_REQUIRE_MIGRATION"))
    required = (
        "source_code",
        "require_oracle",
        "thresholds",
        "source_band_gauge",
        "target_band_gauge",
        "band_frame_transform_definition",
        "band_frame_contract_definition",
        "band_frame_contract",
        "num_bands",
        "num_kpoints",
        "physical_metric",
        "spinor",
        "kpoints_fractional",
        "artifacts",
        "input_definitions",
        "references_hdf5",
        "content_authentication",
    )
    all(haskey(payload, key) for key in required) ||
        throw(ArgumentError("QE_PAW_SPN_PROVENANCE_INCOMPLETE"))
    payload["require_oracle"] isa Bool || throw(ArgumentError("SPN_ORACLE_POLICY_INVALID"))
    _validate_spn_residual_data(
        payload,
        payload["thresholds"],
        get(payload, "oracle_parity", nothing),
        payload["require_oracle"],
    )
    artifacts = Dict{String, String}(
        String(key) => String(value) for (key, value) in pairs(payload["artifacts"])
    )
    input_sha256 = Dict{String, String}(
        String(key) => String(value) for (key, value) in pairs(payload["input_definitions"])
    )
    kpoints =
        reduce(vcat, transpose(Float64.(collect(row))) for row in payload["kpoints_fractional"])
    String(payload["content_authentication"])=="NOT_PERFORMED" ||
        throw(ArgumentError("QE_PAW_SPN_EXPLICIT_MIGRATION_REQUIRED"))
    references=HDF5.h5open(String(payload["references_hdf5"]), "r") do handle
        _read_spn_complete_references(handle)
    end
    if verify_spn
        haskey(artifacts, "spn") || throw(ArgumentError("QE_PAW_SPN_OUTPUT_MISSING"))
        _validate_spn_reference(references, artifacts["spn"])
    end
    return (
        schema = String(payload["schema"]),
        schema_version = String(payload["schema_version"]),
        source_code = Symbol(String(payload["source_code"])),
        source_band_gauge = String(payload["source_band_gauge"]),
        target_band_gauge = String(payload["target_band_gauge"]),
        transform_definition = String(payload["band_frame_transform_definition"]),
        contract_definition = String(payload["band_frame_contract_definition"]),
        frame_contract = Dict{String, Any}(
            String(key) => value for (key, value) in pairs(payload["band_frame_contract"])
        ),
        num_bands = Int(payload["num_bands"]),
        num_kpoints = Int(payload["num_kpoints"]),
        num_kpts = Int(payload["num_kpoints"]),
        physical_metric = String(payload["physical_metric"]),
        spinor = Bool(payload["spinor"]),
        kpoints_fractional = kpoints,
        content_authentication = "NOT_PERFORMED",
        source_reference = references.source_reference,
        spn_reference = references.spn_reference,
        input_sha256,
        artifacts,
        diagnostics = String.(payload["diagnostics"]),
    )
end

"""Read either formal SPN provenance representation into one strict contract."""
function _read_spn_provenance(filename::AbstractString; verify_spn::Bool = true)
    suffix = lowercase(splitext(filename)[2])
    return suffix in (".h5", ".hdf5") ? read_vasp_paw_spn_provenance(filename; verify_spn) :
           read_qe_paw_spn_provenance(filename; verify_spn)
end

"""Reuse one compact SPN attestation within a coordinator-owned workflow only."""
function _with_spn_provenance_reuse(f::F) where {F}
    existing = get(task_local_storage(), :wannier_spn_provenance_reuse, nothing)
    existing !== nothing && existing.owner === current_task() && return f()
    context = (owner = current_task(), slot = Ref{Any}(nothing))
    try
        task_local_storage(f, :wannier_spn_provenance_reuse, context)
    finally
        context.slot[] = nothing
    end
end

"""Capture file replacement and in-place changes after a content-verified read."""
function _spn_validation_file_identity(path)
    information = stat(path)
    return (
        information.device,
        information.inode,
        information.size,
        information.mtime,
        information.ctime,
    )
end

"""Validate actual SPN inputs afresh when no complete owned cache definition is available."""
function _read_and_validate_spn_provenance(
    provenance_path::AbstractString,
    spn_path::AbstractString;
    reader = _read_and_validate_spn_provenance_uncached,
    kwargs...,
)
    # No reuse based only on stat tuples or historical content digests. The
    # uncached reader retains its provenance and SPN scientific validations.
    observed = IO.with_scientific_source(provenance_path; resolve_links = true) do provenance
        nested = IO.with_scientific_source(spn_path; resolve_links = true) do spin
            reader(provenance, spin; kwargs...)
        end
        nested.value
    end
    return observed.value
end

"""
Validate a formal schema-1.2 SPN provenance artifact for bundle assembly.

The SPN itself is required to be in the native DFT eigenstate gauge.  For a
symmetrized target, the returned qualification target and artifact digest bind
the separate, mandatory native-to-symmetrized rotation step.
"""
function _read_and_validate_spn_provenance_uncached(
    provenance_path::AbstractString,
    spn_path::AbstractString;
    expected_num_bands::Int,
    expected_num_kpoints::Int,
    target_authority,
    gauge_definition::Union{Nothing, AbstractString} = nothing,
    band_frame_transform_definition::Union{Nothing, AbstractString} = nothing,
    band_frame_contract_definition::Union{Nothing, AbstractString} = nothing,
)
    record = _read_spn_provenance(provenance_path; verify_spn = true)
    record.contract_definition != "LEGACY_BAND_FRAME_CONTRACT_NOT_RECORDED" || throw(
        ArgumentError(
            "LEGACY_BAND_FRAME_CONTRACT_NOT_RECORDED: complete SPN frame contract is required",
        ),
    )
    record.spinor || throw(ArgumentError("SPN_PROVENANCE_SPINOR_REQUIRED"))
    record.num_bands == expected_num_bands && record.num_kpoints == expected_num_kpoints ||
        throw(ArgumentError("SPN_PROVENANCE_DIMENSION_MISMATCH"))
    record.source_band_gauge == NATIVE_DFT_BAND_GAUGE &&
    record.target_band_gauge == NATIVE_DFT_BAND_GAUGE ||
        throw(ArgumentError("SPN_PROVENANCE_NATIVE_GAUGE_REQUIRED"))
    _validate_spn_reference(record, spn_path)
    native_identity = _identity_band_frame_contract(expected_num_bands, expected_num_kpoints)
    record.transform_definition == native_identity.transform_definition ||
        throw(ArgumentError("SPN_PROVENANCE_IDENTITY_TRANSFORM_VALUES_MISMATCH"))
    record.contract_definition == native_identity.contract_definition ||
        throw(ArgumentError("SPN_PROVENANCE_IDENTITY_FRAME_CONTRACT_DIGEST_MISMATCH"))
    String(get(record.frame_contract, "transform_definition", "")) == record.transform_definition ||
        throw(ArgumentError("SPN_PROVENANCE_FRAME_TRANSFORM_VALUES_MISMATCH"))
    String(get(record.frame_contract, "contract_definition", "")) == record.contract_definition ||
        throw(ArgumentError("SPN_PROVENANCE_FRAME_CONTRACT_DIGEST_MISMATCH"))
    authority =
        target_authority isa AbstractAuthoritativeHamiltonian ?
        authoritative_hamiltonian_key(target_authority) :
        validate_authoritative_hamiltonian_key(String(target_authority))
    artifact_digest = if gauge_definition === nothing
        authority == authoritative_hamiltonian_key(NativeDFTHamiltonian()) ||
            throw(ArgumentError("SPN_PROVENANCE_GAUGE_ARTIFACT_REQUIRED"))
        "NOT_APPLICABLE"
    else
        digest = String(something(gauge_definition))
        startswith(digest, "band-frame-contract-values/2:") ||
            throw(ArgumentError("SPN_PROVENANCE_GAUGE_DEFINITION_REQUIRED"))
        digest
    end
    qualification_target = if authority == authoritative_hamiltonian_key(NativeDFTHamiltonian())
        artifact_digest == "NOT_APPLICABLE" ? NATIVE_DFT_BAND_GAUGE :
        SAWF_COMPLETED_NATIVE_DFT_BAND_GAUGE
    else
        SYMMETRIZED_DFT_BAND_GAUGE
    end
    requested_transform_definition = band_frame_transform_definition
    qualification_transform = if artifact_digest == "NOT_APPLICABLE"
        requested_transform_definition === nothing ||
            String(requested_transform_definition) == native_identity.transform_definition ||
            throw(ArgumentError("SPN_PROVENANCE_IDENTITY_TRANSFORM_VALUES_MISMATCH"))
        native_identity.transform_definition
    else
        requested_transform_definition === nothing &&
            throw(ArgumentError("SPN_PROVENANCE_BAND_FRAME_TRANSFORM_REQUIRED"))
        digest = String(something(requested_transform_definition))
        startswith(digest, "band-frame-transform-values/2:") ||
            throw(ArgumentError("SPN_PROVENANCE_BAND_FRAME_VALUES_REQUIRED"))
        digest
    end
    qualification_contract = if artifact_digest == "NOT_APPLICABLE"
        band_frame_contract_definition === nothing ||
            String(band_frame_contract_definition) == native_identity.contract_definition ||
            throw(ArgumentError("SPN_PROVENANCE_IDENTITY_FRAME_CONTRACT_DIGEST_MISMATCH"))
        native_identity.contract_definition
    else
        band_frame_contract_definition === nothing &&
            throw(ArgumentError("SPN_PROVENANCE_BAND_FRAME_CONTRACT_REQUIRED"))
        digest = String(something(band_frame_contract_definition))
        startswith(digest, "band-frame-contract-values/2:") ||
            throw(ArgumentError("SPN_PROVENANCE_BAND_FRAME_VALUES_REQUIRED"))
        digest
    end
    return merge(
        record,
        (
            content_authentication = "NOT_PERFORMED",
            qualification_target_band_gauge = qualification_target,
            qualification_transform_definition = qualification_transform,
            qualification_contract_definition = qualification_contract,
            gauge_definition = artifact_digest,
        ),
    )
end

"""Validate common SPN source hashes and source-specific topology provenance."""
function _validate_generation_spn_input_sha256(record, state_input_sha256)
    for (key, digest) in state_input_sha256
        key == "TOPOLOGY" && continue
        get(record.input_sha256, key, "MISSING") == digest ||
            throw(ArgumentError("SPN_PROVENANCE_INPUT_DIGEST_MISMATCH: $(key)"))
    end
    topology_digest = get(state_input_sha256, "TOPOLOGY", nothing)
    topology_digest === nothing && return nothing
    recorded_topology = get(record.input_sha256, "TOPOLOGY", nothing)
    if recorded_topology === nothing
        record.source_code == :vasp ||
            throw(ArgumentError("SPN_PROVENANCE_INPUT_DIGEST_MISMATCH: TOPOLOGY"))
    elseif recorded_topology != topology_digest
        throw(ArgumentError("SPN_PROVENANCE_INPUT_DIGEST_MISMATCH: TOPOLOGY"))
    end
    return nothing
end

"""Validate that one native-gauge SPN belongs to the exact generator source."""
function _validate_generation_spn_provenance(record, spn_path, state)
    record.contract_definition != "LEGACY_BAND_FRAME_CONTRACT_NOT_RECORDED" || throw(
        ArgumentError(
            "LEGACY_BAND_FRAME_CONTRACT_NOT_RECORDED: complete SPN frame contract is required",
        ),
    )
    record.source_code == state.native.source_code ||
        throw(ArgumentError("SPN_PROVENANCE_SOURCE_CODE_MISMATCH"))
    record.source_band_gauge == NATIVE_DFT_BAND_GAUGE &&
    record.target_band_gauge == NATIVE_DFT_BAND_GAUGE ||
        throw(ArgumentError("SPN_PROVENANCE_NATIVE_GAUGE_REQUIRED"))
    record.num_bands == state.topology.num_bands && record.num_kpoints == state.topology.num_kpts ||
        throw(ArgumentError("SPN_PROVENANCE_DIMENSION_MISMATCH"))
    record.spinor || throw(ArgumentError("SPN_PROVENANCE_SPINOR_REQUIRED"))
    _validate_spn_reference(record, spn_path)
    size(record.kpoints_fractional) == (state.topology.num_kpts, 3) ||
        throw(ArgumentError("SPN_PROVENANCE_KPOINT_DIMENSION_MISMATCH"))
    for kpoint in 1:state.topology.num_kpts
        delta =
            _uiu_kpoint_fractional(state.native, kpoint) .-
            @view(record.kpoints_fractional[kpoint, :])
        delta .-= round.(delta)
        maximum(abs, delta) <= 1.0e-8 ||
            throw(ArgumentError("SPN_PROVENANCE_KPOINT_ORDER_MISMATCH: kpoint=$(kpoint)"))
    end
    state.native.source_definition === nothing &&
        throw(ArgumentError("SPN_SOURCE_REFERENCE_REQUIRED"))
    IO.validate_scientific_input_definitions_equal(
        state.native.source_definition,
        record.source_reference;
        mismatch_error = "SPN_PROVENANCE_SOURCE_VALUES_MISMATCH",
    )
    _validate_generation_spn_input_sha256(record, state.input_sha256)
    return nothing
end
