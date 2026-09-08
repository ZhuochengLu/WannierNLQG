"""Digest an identity rotation with the same byte contract as a sealed gauge rotation."""
function _identity_band_rotation_sha256(num_bands::Int, num_kpts::Int)
    num_bands > 0 && num_kpts > 0 || throw(ArgumentError("band-gauge dimensions must be positive"))
    rotations = zeros(ComplexF64, num_bands, num_bands, num_kpts)
    for kpoint in 1:num_kpts
        for band in 1:num_bands
            rotations[band, band, kpoint] = 1.0
        end
    end
    return _star_array_sha256(rotations)
end

"""Return the exact identity-frame contract used by ordinary native DFT."""
function _identity_band_frame_contract(
    num_bands::Int,
    num_kpts::Int;
    metric_kind::AbstractString = "not_applicable_native_identity",
)
    transform_sha256 = _identity_band_rotation_sha256(num_bands, num_kpts)
    contract_sha256 = band_frame_contract_sha256(
        NATIVE_DFT_BAND_GAUGE,
        NATIVE_DFT_BAND_GAUGE,
        transform_sha256,
        "RUNTIME_IDENTITY",
        "IDENTITY",
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
        transform_sha256,
        contract_sha256,
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

"""Apply `U_k† O_k U_k` to a one-k-point operator."""
function _rotate_single_point_operator(operator, left_rotation)
    size(operator, 1) == size(operator, 2) == size(left_rotation, 1) == size(left_rotation, 2) ||
        throw(ArgumentError("single-point band-gauge dimensions differ"))
    return left_rotation' * operator * left_rotation
end

"""Apply `U_k† O_{k,k+b} U_{k+b}` to a link operator."""
function _rotate_link_operator(operator, left_rotation, right_rotation)
    size(operator, 1) == size(left_rotation, 1) == size(left_rotation, 2) ||
        throw(ArgumentError("link left band-gauge dimensions differ"))
    size(operator, 2) == size(right_rotation, 1) == size(right_rotation, 2) ||
        throw(ArgumentError("link right band-gauge dimensions differ"))
    return left_rotation' * operator * right_rotation
end

"""Apply the endpoint rotations to a neighbor-neighbor operator."""
_rotate_double_endpoint_operator(operator, first_rotation, second_rotation) =
    _rotate_link_operator(operator, first_rotation, second_rotation)

"""Resolve and verify the exact band-gauge transformation requested by a generator."""
function _generation_band_gauge_contract(
    source,
    authority,
    gauge_hdf5,
    num_bands::Int,
    num_kpts::Int;
    construction_policy::Symbol = :strict,
)
    construction_policy in (:strict, :diagnostic) ||
        throw(ArgumentError("construction_policy must be :strict or :diagnostic"))
    if authority isa NativeDFTHamiltonian && gauge_hdf5 === nothing
        return _identity_band_frame_contract(num_bands, num_kpts)
    elseif authority isa NativeDFTHamiltonian || authority isa SymmetrizedDFTHamiltonian
        gauge_hdf5 === nothing && throw(
            ArgumentError(
                "SYMMETRIZED_HAMILTONIAN_ARTIFACT_REQUIRED: wavefunction_gauge_hdf5 is missing",
            ),
        )
        path = abspath(something(gauge_hdf5))
        restored = _read_star_covariant_paw_gauge_hdf5(path; construction_policy, source)
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
        # The formal frame transform is the digest-bound raw-source to completed-frame
        # map stored as `native_to_completed_rotations`.  The similarly shaped array in
        # the symmetrized-Hamiltonian audit is independent Hamiltonian evidence and must
        # not replace the frame transform merely because the requested authority is
        # symmetrized.
        rotations = copy(restored.payload.rotations)
        size(rotations) == (num_bands, num_bands, num_kpts) || throw(
            ArgumentError(
                "BAND_FRAME_DIMENSION_MISMATCH: expected ($(num_bands), $(num_bands), $(num_kpts)), got $(size(rotations))",
            ),
        )
        all(isfinite, rotations) ||
            throw(ArgumentError("BAND_FRAME_NONFINITE: transform contains NaN or Inf"))
        transform_sha256 = _star_array_sha256(rotations)
        if restored.band_frame_contract === nothing
            identity_transform = true
            identity_matrix = Matrix{ComplexF64}(I, num_bands, num_bands)
            for kpoint in 1:num_kpts
                identity_transform &= (@view(rotations[:, :, kpoint])) == identity_matrix
            end
            identity_transform || throw(
                ArgumentError(
                    "LEGACY_BAND_FRAME_CONTRACT_NOT_RECORDED: schema-$(restored.schema_version) nonidentity transform is diagnostic-only",
                ),
            )
            identity = _identity_band_frame_contract(num_bands, num_kpts)
            return BandFrameTransformContract(
                identity.source_band_gauge,
                target_band_gauge,
                nothing,
                identity.transform_sha256,
                identity.contract_sha256,
                sha256_file(path),
                identity.metric_kind,
                identity.physical_isometry_maximum,
                identity.physical_isometry_tolerance,
                identity.replay_maximum,
                identity.replay_tolerance,
                identity.euclidean_nonunitarity_maximum,
                identity.minimum_singular_value,
                identity.maximum_condition_number,
                identity.schema,
                identity.schema_version,
                "LEGACY_IDENTITY_ONLY",
                true,
            )
        end
        restored.band_frame_contract === nothing && throw(
            ArgumentError("BAND_FRAME_CONTRACT_REQUIRED: schema-1.11 artifact has no contract"),
        )
        sealed = something(restored.band_frame_contract)
        sealed.transform_sha256 == transform_sha256 ||
            throw(ArgumentError("BAND_FRAME_TRANSFORM_DIGEST_MISMATCH"))
        sealed.source_band_gauge == NATIVE_DFT_BAND_GAUGE ||
            throw(ArgumentError("BAND_FRAME_SOURCE_MISMATCH: source gauge differs"))
        sealed.target_band_gauge == target_band_gauge ||
            throw(ArgumentError("BAND_FRAME_TARGET_MISMATCH: target gauge differs"))
        sealed.status == "PASS" || throw(ArgumentError("BAND_FRAME_CONTRACT_NOT_QUALIFIED"))
        return BandFrameTransformContract(
            sealed.source_band_gauge,
            sealed.target_band_gauge,
            rotations,
            sealed.transform_sha256,
            sealed.contract_sha256,
            sealed.gauge_artifact_sha256,
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
    gauge_contract.status in ("PASS", "LEGACY_IDENTITY_ONLY") ||
        throw(ArgumentError("BAND_FRAME_CONTRACT_NOT_QUALIFIED"))
    return 0.0
end

"""Return the rotation at one k-point, or an allocation-free identity marker."""
_generation_rotation(contract, kpoint::Int) =
    contract.rotations === nothing ? nothing : @view(contract.rotations[:, :, kpoint])

"""Rotate one generated link into the target gauge, preserving native values exactly."""
function _rotate_generation_link(operator, contract, left::Int, right::Int)
    contract.rotations === nothing && return Matrix{ComplexF64}(operator)
    return _rotate_link_operator(
        operator,
        _generation_rotation(contract, left),
        _generation_rotation(contract, right),
    )
end

"""Rotate one generated single-k operator into the target band gauge."""
function _rotate_generation_single(operator, contract, kpoint::Int)
    contract.rotations === nothing && return Matrix{ComplexF64}(operator)
    return _rotate_single_point_operator(operator, _generation_rotation(contract, kpoint))
end

"""Stable digest over the formal SPN provenance identity shared by JSON and HDF5."""
function _spn_provenance_contract_sha256(
    schema,
    schema_version,
    source_code,
    passed,
    source_band_gauge,
    target_band_gauge,
    transform_sha256,
    frame_contract_sha256,
    num_bands,
    num_kpts,
    physical_metric,
    spinor,
    spn_sha256,
    input_sha256,
    kpoints_fractional,
)
    io = IOBuffer()
    for value in (
        schema,
        schema_version,
        source_code,
        passed,
        source_band_gauge,
        target_band_gauge,
        transform_sha256,
        frame_contract_sha256,
        num_bands,
        num_kpts,
        physical_metric,
        spinor,
        spn_sha256,
    )
        write(io, string(value), '\0')
    end
    for key in sort!(String.(collect(keys(input_sha256))))
        write(io, key, '=', String(input_sha256[key]), '\0')
    end
    values = Matrix{Float64}(kpoints_fractional)
    write(io, reinterpret(UInt8, vec(values)))
    return bytes2hex(SHA.sha256(take!(io)))
end

# Exact schema-1.1 digest retained for diagnostic readback only.
function _spn_provenance_contract_sha256(
    schema,
    schema_version,
    source_code,
    passed,
    source_band_gauge,
    target_band_gauge,
    rotation_sha256,
    num_bands,
    num_kpts,
    physical_metric,
    spinor,
    spn_sha256,
    input_sha256,
    kpoints_fractional,
)
    io = IOBuffer()
    for value in (
        schema,
        schema_version,
        source_code,
        passed,
        source_band_gauge,
        target_band_gauge,
        rotation_sha256,
        num_bands,
        num_kpts,
        physical_metric,
        spinor,
        spn_sha256,
    )
        write(io, string(value), '\0')
    end
    for key in sort!(String.(collect(keys(input_sha256))))
        write(io, key, '=', String(input_sha256[key]), '\0')
    end
    values = Matrix{Float64}(kpoints_fractional)
    write(io, reinterpret(UInt8, vec(values)))
    return bytes2hex(SHA.sha256(take!(io)))
end

"""Append one JSON-compatible value to an order-independent logical digest."""
function _spn_json_digest_value!(io::Base.IO, value)
    if value isa AbstractDict || value isa JSON3.Object
        write(io, "dictionary\0")
        entries = sort!(collect(pairs(value)); by = pair -> String(first(pair)))
        for (key, entry) in entries
            write(io, String(key), '\0')
            _spn_json_digest_value!(io, entry)
        end
    elseif value isa AbstractArray || value isa JSON3.Array || value isa Tuple
        write(io, "array\0", string(length(value)), '\0')
        for entry in value
            _spn_json_digest_value!(io, entry)
        end
    elseif value === nothing
        write(io, "nothing\0")
    elseif value isa Bool
        write(io, value ? "bool:true\0" : "bool:false\0")
    elseif value isa Integer
        write(io, "integer:", string(value), '\0')
    elseif value isa AbstractFloat
        write(io, "float:", repr(Float64(value)), '\0')
    elseif value isa AbstractString || value isa Symbol
        write(io, "string:", String(value), '\0')
    else
        throw(ArgumentError("unsupported SPN JSON provenance value $(typeof(value))"))
    end
    return nothing
end

"""Digest every QE JSON provenance field except the digest field itself."""
function _qe_spn_payload_sha256(payload)
    filtered = Dict{String, Any}(
        String(key) => value for (key, value) in pairs(payload) if String(key) != "payload_sha256"
    )
    normalized = JSON3.read(JSON3.write(filtered), Dict{String, Any})
    io = IOBuffer()
    entries = sort!(collect(pairs(normalized)); by = pair -> String(first(pair)))
    for (key, value) in entries
        write(io, String(key), '\0')
        _spn_json_digest_value!(io, value)
    end
    return bytes2hex(SHA.sha256(take!(io)))
end

"""Read, seal-check, and normalize a QE PAW-SPN provenance JSON sidecar."""
function read_qe_paw_spn_provenance(filename::AbstractString; verify_spn::Bool = true)
    path = abspath(filename)
    isfile(path) || throw(ArgumentError("QE PAW-SPN provenance file does not exist"))
    payload = JSON3.read(read(path, String), Dict{String, Any})
    String(get(payload, "schema", "")) == QE_PAW_SPN_SCHEMA ||
        throw(ArgumentError("QE_PAW_SPN_PROVENANCE_SCHEMA_MISMATCH"))
    schema_version = String(get(payload, "schema_version", ""))
    schema_version in ("1.0", "1.1", "1.2") ||
        throw(ArgumentError("QE_PAW_SPN_PROVENANCE_VERSION_MISMATCH"))
    contract_version = schema_version == "1.0" ? "1.2" : schema_version
    required =
        contract_version == "1.2" ?
        (
            "source_code",
            "passed",
            "source_band_gauge",
            "target_band_gauge",
            "band_frame_transform_sha256",
            "band_frame_contract_sha256",
            "band_frame_contract",
            "band_gauge_rotation_sha256",
            "num_bands",
            "num_kpoints",
            "physical_metric",
            "spinor",
            "kpoints_fractional",
            "artifacts",
            "input_sha256",
            "payload_sha256",
            "contract_sha256",
        ) :
        (
            "source_code",
            "passed",
            "source_band_gauge",
            "target_band_gauge",
            "band_gauge_rotation_sha256",
            "num_bands",
            "num_kpoints",
            "physical_metric",
            "spinor",
            "kpoints_fractional",
            "artifacts",
            "input_sha256",
            "payload_sha256",
            "contract_sha256",
        )
    all(haskey(payload, key) for key in required) ||
        throw(ArgumentError("QE_PAW_SPN_PROVENANCE_INCOMPLETE"))
    artifacts = Dict{String, String}(
        String(key) => String(value) for (key, value) in pairs(payload["artifacts"])
    )
    input_sha256 = Dict{String, String}(
        String(key) => String(value) for (key, value) in pairs(payload["input_sha256"])
    )
    kpoints =
        reduce(vcat, transpose(Float64.(collect(row))) for row in payload["kpoints_fractional"])
    spn_hash = get(artifacts, "spn_sha256", "NOT_PUBLISHED")
    provenance_contract_sha256 = if contract_version == "1.2"
        _spn_provenance_contract_sha256(
            payload["schema"],
            payload["schema_version"],
            payload["source_code"],
            payload["passed"],
            payload["source_band_gauge"],
            payload["target_band_gauge"],
            payload["band_frame_transform_sha256"],
            payload["band_frame_contract_sha256"],
            payload["num_bands"],
            payload["num_kpoints"],
            payload["physical_metric"],
            payload["spinor"],
            spn_hash,
            input_sha256,
            kpoints,
        )
    else
        _spn_provenance_contract_sha256(
            payload["schema"],
            payload["schema_version"],
            payload["source_code"],
            payload["passed"],
            payload["source_band_gauge"],
            payload["target_band_gauge"],
            payload["band_gauge_rotation_sha256"],
            payload["num_bands"],
            payload["num_kpoints"],
            payload["physical_metric"],
            payload["spinor"],
            spn_hash,
            input_sha256,
            kpoints,
        )
    end
    String(payload["contract_sha256"]) == provenance_contract_sha256 ||
        throw(ArgumentError("QE_PAW_SPN_PROVENANCE_CONTRACT_DIGEST_MISMATCH"))
    payload_sha256 = _qe_spn_payload_sha256(payload)
    String(payload["payload_sha256"]) == payload_sha256 ||
        throw(ArgumentError("QE_PAW_SPN_PROVENANCE_DIGEST_MISMATCH"))
    if verify_spn
        haskey(artifacts, "spn") && haskey(artifacts, "spn_sha256") ||
            throw(ArgumentError("QE_PAW_SPN_PROVENANCE_ARTIFACT_MISSING"))
        isfile(artifacts["spn"]) || throw(ArgumentError("QE_PAW_SPN_OUTPUT_MISSING"))
        sha256_file(artifacts["spn"]) == artifacts["spn_sha256"] ||
            throw(ArgumentError("QE_PAW_SPN_OUTPUT_DIGEST_MISMATCH"))
    end
    return (
        schema = String(payload["schema"]),
        schema_version = String(payload["schema_version"]),
        source_code = Symbol(String(payload["source_code"])),
        passed = Bool(payload["passed"]),
        source_band_gauge = String(payload["source_band_gauge"]),
        target_band_gauge = String(payload["target_band_gauge"]),
        transform_sha256 = contract_version == "1.2" ?
                           String(payload["band_frame_transform_sha256"]) :
                           String(payload["band_gauge_rotation_sha256"]),
        contract_sha256 = contract_version == "1.2" ?
                          String(payload["band_frame_contract_sha256"]) :
                          "LEGACY_BAND_FRAME_CONTRACT_NOT_RECORDED",
        frame_contract = contract_version == "1.2" ?
                         Dict{String, Any}(
            String(key) => value for (key, value) in pairs(payload["band_frame_contract"])
        ) : Dict{String, Any}("status" => "LEGACY_BAND_FRAME_CONTRACT_NOT_RECORDED"),
        rotation_sha256 = String(payload["band_gauge_rotation_sha256"]),
        num_bands = Int(payload["num_bands"]),
        num_kpoints = Int(payload["num_kpoints"]),
        num_kpts = Int(payload["num_kpoints"]),
        physical_metric = String(payload["physical_metric"]),
        spinor = Bool(payload["spinor"]),
        kpoints_fractional = kpoints,
        payload_sha256,
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

"""
Validate a formal schema-1.2 SPN provenance artifact for bundle assembly.

The SPN itself is required to be in the native DFT eigenstate gauge.  For a
symmetrized target, the returned qualification target and artifact digest bind
the separate, mandatory native-to-symmetrized rotation step.
"""
function _read_and_validate_spn_provenance(
    provenance_path::AbstractString,
    spn_path::AbstractString;
    expected_num_bands::Int,
    expected_num_kpoints::Int,
    target_authority,
    gauge_artifact_sha256::Union{Nothing, AbstractString} = nothing,
    band_gauge_rotation_sha256::Union{Nothing, AbstractString} = nothing,
    band_frame_transform_sha256::Union{Nothing, AbstractString} = nothing,
    band_frame_contract_sha256::Union{Nothing, AbstractString} = nothing,
)
    record = _read_spn_provenance(provenance_path; verify_spn = true)
    (
        record.schema_version == "1.2" || (
            record.schema_version == "1.0" &&
            record.contract_sha256 != "LEGACY_BAND_FRAME_CONTRACT_NOT_RECORDED"
        )
    ) || throw(ArgumentError("LEGACY_BAND_FRAME_CONTRACT_NOT_RECORDED: SPN schema-1.2 is required"))
    record.passed || throw(ArgumentError("SPN_PROVENANCE_NOT_QUALIFIED"))
    record.spinor || throw(ArgumentError("SPN_PROVENANCE_SPINOR_REQUIRED"))
    record.num_bands == expected_num_bands && record.num_kpoints == expected_num_kpoints ||
        throw(ArgumentError("SPN_PROVENANCE_DIMENSION_MISMATCH"))
    record.source_band_gauge == NATIVE_DFT_BAND_GAUGE &&
    record.target_band_gauge == NATIVE_DFT_BAND_GAUGE ||
        throw(ArgumentError("SPN_PROVENANCE_NATIVE_GAUGE_REQUIRED"))
    get(record.artifacts, "spn_sha256", "") == sha256_file(spn_path) ||
        throw(ArgumentError("SPN_PROVENANCE_OUTPUT_DIGEST_MISMATCH"))
    native_identity = _identity_band_frame_contract(expected_num_bands, expected_num_kpoints)
    record.transform_sha256 == native_identity.transform_sha256 ||
        throw(ArgumentError("SPN_PROVENANCE_IDENTITY_TRANSFORM_DIGEST_MISMATCH"))
    record.contract_sha256 == native_identity.contract_sha256 ||
        throw(ArgumentError("SPN_PROVENANCE_IDENTITY_FRAME_CONTRACT_DIGEST_MISMATCH"))
    String(get(record.frame_contract, "status", "")) == "PASS" ||
        throw(ArgumentError("SPN_PROVENANCE_FRAME_CONTRACT_NOT_QUALIFIED"))
    String(get(record.frame_contract, "transform_sha256", "")) == record.transform_sha256 ||
        throw(ArgumentError("SPN_PROVENANCE_FRAME_TRANSFORM_DIGEST_MISMATCH"))
    String(get(record.frame_contract, "contract_sha256", "")) == record.contract_sha256 ||
        throw(ArgumentError("SPN_PROVENANCE_FRAME_CONTRACT_DIGEST_MISMATCH"))
    authority =
        target_authority isa AbstractAuthoritativeHamiltonian ?
        authoritative_hamiltonian_key(target_authority) :
        validate_authoritative_hamiltonian_key(String(target_authority))
    artifact_digest = if gauge_artifact_sha256 === nothing
        authority == authoritative_hamiltonian_key(NativeDFTHamiltonian()) ||
            throw(ArgumentError("SPN_PROVENANCE_GAUGE_ARTIFACT_REQUIRED"))
        "NOT_APPLICABLE"
    else
        digest = String(something(gauge_artifact_sha256))
        occursin(r"^[0-9a-f]{64}$", digest) ||
            throw(ArgumentError("SPN_PROVENANCE_GAUGE_ARTIFACT_DIGEST_INVALID"))
        digest
    end
    qualification_target = if authority == authoritative_hamiltonian_key(NativeDFTHamiltonian())
        artifact_digest == "NOT_APPLICABLE" ? NATIVE_DFT_BAND_GAUGE :
        SAWF_COMPLETED_NATIVE_DFT_BAND_GAUGE
    else
        SYMMETRIZED_DFT_BAND_GAUGE
    end
    requested_transform_sha256 =
        band_frame_transform_sha256 === nothing ? band_gauge_rotation_sha256 :
        band_frame_transform_sha256
    qualification_transform = if artifact_digest == "NOT_APPLICABLE"
        requested_transform_sha256 === nothing ||
            String(requested_transform_sha256) == native_identity.transform_sha256 ||
            throw(ArgumentError("SPN_PROVENANCE_IDENTITY_TRANSFORM_DIGEST_MISMATCH"))
        native_identity.transform_sha256
    else
        requested_transform_sha256 === nothing &&
            throw(ArgumentError("SPN_PROVENANCE_BAND_FRAME_TRANSFORM_REQUIRED"))
        digest = String(something(requested_transform_sha256))
        occursin(r"^[0-9a-f]{64}$", digest) ||
            throw(ArgumentError("SPN_PROVENANCE_BAND_FRAME_TRANSFORM_DIGEST_INVALID"))
        digest
    end
    qualification_contract = if artifact_digest == "NOT_APPLICABLE"
        band_frame_contract_sha256 === nothing ||
            String(band_frame_contract_sha256) == native_identity.contract_sha256 ||
            throw(ArgumentError("SPN_PROVENANCE_IDENTITY_FRAME_CONTRACT_DIGEST_MISMATCH"))
        native_identity.contract_sha256
    else
        band_frame_contract_sha256 === nothing &&
            throw(ArgumentError("SPN_PROVENANCE_BAND_FRAME_CONTRACT_REQUIRED"))
        digest = String(something(band_frame_contract_sha256))
        occursin(r"^[0-9a-f]{64}$", digest) ||
            throw(ArgumentError("SPN_PROVENANCE_BAND_FRAME_CONTRACT_DIGEST_INVALID"))
        digest
    end
    return merge(
        record,
        (
            status = "PASS",
            spn_sha256 = record.artifacts["spn_sha256"],
            provenance_sha256 = sha256_file(provenance_path),
            qualification_target_band_gauge = qualification_target,
            qualification_transform_sha256 = qualification_transform,
            qualification_contract_sha256 = qualification_contract,
            qualification_rotation_sha256 = qualification_transform,
            gauge_artifact_sha256 = artifact_digest,
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
    (
        record.schema_version == "1.2" || (
            record.schema_version == "1.0" &&
            record.contract_sha256 != "LEGACY_BAND_FRAME_CONTRACT_NOT_RECORDED"
        )
    ) || throw(ArgumentError("LEGACY_BAND_FRAME_CONTRACT_NOT_RECORDED: SPN schema-1.2 is required"))
    record.passed || throw(ArgumentError("SPN_PROVENANCE_NOT_QUALIFIED"))
    record.source_code == state.native.source_code ||
        throw(ArgumentError("SPN_PROVENANCE_SOURCE_CODE_MISMATCH"))
    record.source_band_gauge == NATIVE_DFT_BAND_GAUGE &&
    record.target_band_gauge == NATIVE_DFT_BAND_GAUGE ||
        throw(ArgumentError("SPN_PROVENANCE_NATIVE_GAUGE_REQUIRED"))
    record.num_bands == state.topology.num_bands && record.num_kpoints == state.topology.num_kpts ||
        throw(ArgumentError("SPN_PROVENANCE_DIMENSION_MISMATCH"))
    record.spinor || throw(ArgumentError("SPN_PROVENANCE_SPINOR_REQUIRED"))
    get(record.artifacts, "spn_sha256", "") == sha256_file(spn_path) ||
        throw(ArgumentError("SPN_PROVENANCE_OUTPUT_DIGEST_MISMATCH"))
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
    _validate_generation_spn_input_sha256(record, state.input_sha256)
    return nothing
end
