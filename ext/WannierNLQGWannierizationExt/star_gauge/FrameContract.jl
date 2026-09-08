const STAR_COVARIANT_PAW_GAUGE_SCHEMA = "WannierNLQG.star_covariant_paw_gauge"
# Public wire numbering retains the full physical-frame replay contract of 1.11.
const STAR_COVARIANT_PAW_GAUGE_SCHEMA_VERSION = "1.0"
const STAR_COVARIANT_PAW_GAUGE_CURRENT_CONTRACT_VERSION = "1.11"
const STAR_COVARIANT_PAW_GAUGE_SUPPORTED_SCHEMA_VERSIONS =
    ("1.0", "1.1", "1.2", "1.3", "1.4", "1.5", "1.6", "1.7", "1.8", "1.9", "1.10", "1.11")

# Distinguish the public 1.0 wire format from historical 1.0 using existing frame
# contract markers. Any modern marker selects the full contract before validation;
# a missing or invalid companion field must never trigger a historical fallback.
function _star_gauge_contract_version(
    schema_version::AbstractString,
    root_attributes,
    source_metadata,
    input_sha256,
)
    schema_version in STAR_COVARIANT_PAW_GAUGE_SUPPORTED_SCHEMA_VERSIONS ||
        throw(ArgumentError("unsupported wavefunction-gauge HDF5 schema version"))
    schema_version == "1.0" || return String(schema_version)
    modern_intent =
        any(key -> startswith(String(key), "band_frame_"), keys(root_attributes)) ||
        any(key -> startswith(String(key), "band_frame_"), keys(source_metadata)) ||
        any(key -> startswith(String(key), "BAND_FRAME_"), keys(input_sha256))
    return modern_intent ? STAR_COVARIANT_PAW_GAUGE_CURRENT_CONTRACT_VERSION : "1.0"
end

# Keep digest layout selection independent of the literal on-disk version prefix.
function _validate_star_wire_contract(schema_version, contract_version)
    schema_version in STAR_COVARIANT_PAW_GAUGE_SUPPORTED_SCHEMA_VERSIONS ||
        throw(ArgumentError("unsupported wavefunction-gauge HDF5 schema version"))
    valid =
        schema_version == "1.0" ?
        contract_version in ("1.0", STAR_COVARIANT_PAW_GAUGE_CURRENT_CONTRACT_VERSION) :
        contract_version == schema_version
    valid || throw(ArgumentError("wavefunction-gauge wire and field contract disagree"))
    return nothing
end

# Return the persisted QE PAW/USPP or norm-conserving metric identity.
_band_frame_metric_kind(metric::_QEStrictSewingMetric) = metric.metric_kind
# Return the persisted VASP PAW projector/Q0 metric identity.
_band_frame_metric_kind(::_VASPStrictSewingMetric) = "vasp_potcar_projector_q0"

# Parse one finite numeric field from persisted frame-contract metadata.
function _band_frame_float(metadata::AbstractDict{String, String}, key::String)
    haskey(metadata, key) ||
        throw(ArgumentError("PAW_GAUGE_ARTIFACT_TAMPERED: band-frame contract omits $(key)"))
    value = tryparse(Float64, metadata[key])
    value !== nothing && isfinite(something(value)) ||
        throw(ArgumentError("PAW_GAUGE_ARTIFACT_TAMPERED: invalid band-frame value $(key)"))
    return something(value)
end

"""Audit `T' * S_source * T = I` without modifying the supplied transforms."""
function _audit_band_frame_transforms(
    source_metrics::Vector{<:AbstractMatrix},
    transforms::Array{ComplexF64, 3},
)
    length(source_metrics) == size(transforms, 3) ||
        throw(ArgumentError("BAND_FRAME_TOPOLOGY_MISMATCH: metric and transform k-counts differ"))
    all(isfinite, transforms) ||
        throw(ArgumentError("BAND_FRAME_NONFINITE: transform contains NaN or Inf"))
    parent_count, target_count, _ = size(transforms)
    physical_isometry_maximum = 0.0
    euclidean_nonunitarity_maximum = 0.0
    minimum_singular_value = Inf
    maximum_condition_number = 0.0
    identity_target = Matrix{ComplexF64}(I, target_count, target_count)
    for kpoint in eachindex(source_metrics)
        source_metric = Matrix{ComplexF64}(source_metrics[kpoint])
        size(source_metric) == (parent_count, parent_count) ||
            throw(ArgumentError("BAND_FRAME_SOURCE_METRIC_DIMENSION_MISMATCH: kpoint=$(kpoint)"))
        all(isfinite, source_metric) ||
            throw(ArgumentError("BAND_FRAME_SOURCE_METRIC_NONFINITE: kpoint=$(kpoint)"))
        hermiticity_residual = opnorm(source_metric - source_metric')
        hermiticity_tolerance = 1.0e-10 * max(1.0, opnorm(source_metric))
        hermiticity_residual <= hermiticity_tolerance || throw(
            ArgumentError(
                "BAND_FRAME_SOURCE_METRIC_NONHERMITIAN: kpoint=$(kpoint) residual $(hermiticity_residual) exceeds $(hermiticity_tolerance)",
            ),
        )
        metric_eigenvalues = eigvals(Hermitian(0.5 .* (source_metric + source_metric')))
        minimum(metric_eigenvalues) > 1.0e-10 ||
            throw(ArgumentError("BAND_FRAME_SOURCE_METRIC_NOT_POSITIVE_DEFINITE: kpoint=$(kpoint)"))
        transform = @view transforms[:, :, kpoint]
        singular_values = svdvals(transform)
        isempty(singular_values) &&
            throw(ArgumentError("BAND_FRAME_RANK_FAILED: kpoint=$(kpoint) has empty rank"))
        local_minimum = minimum(singular_values)
        local_maximum = maximum(singular_values)
        isfinite(local_minimum) && local_minimum > 1.0e-10 || throw(
            ArgumentError(
                "BAND_FRAME_RANK_FAILED: kpoint=$(kpoint) minimum singular value $(local_minimum)",
            ),
        )
        minimum_singular_value = min(minimum_singular_value, local_minimum)
        maximum_condition_number = max(maximum_condition_number, local_maximum / local_minimum)
        physical_isometry_maximum = max(
            physical_isometry_maximum,
            opnorm(transform' * source_metric * transform - identity_target),
        )
        euclidean_nonunitarity_maximum =
            max(euclidean_nonunitarity_maximum, opnorm(transform' * transform - identity_target))
    end
    return (
        physical_isometry_maximum = physical_isometry_maximum,
        euclidean_nonunitarity_maximum = euclidean_nonunitarity_maximum,
        minimum_singular_value = minimum_singular_value,
        maximum_condition_number = maximum_condition_number,
    )
end

"""Independent native-versus-symmetrized parent-Hamiltonian audit arrays."""
struct _SymmetrizedDFTHamiltonianAuditPayload
    native_energies_ev::Matrix{Float64}
    symmetrized_energies_ev::Matrix{Float64}
    native_to_symmetrized_rotations::Array{ComplexF64, 3}
    representative_native_hamiltonians_ev::Array{ComplexF64, 3}
    representative_symmetrized_hamiltonians_ev::Array{ComplexF64, 3}
    representative_raw_transports::Array{ComplexF64, 4}
    target_principal_angles_rad::Matrix{Float64}
    target_projector_difference_operator::Vector{Float64}
    target_projector_difference_frobenius::Vector{Float64}
    native_to_symmetrized_band_assignment::Matrix{Int}
    target_energy_shifts_by_star_ev::Matrix{Float64}
    parent_energy_shifts_by_kpoint_ev::Matrix{Float64}
    target_anchor_sha256_by_star::Union{Nothing, Vector{String}}
    complement_bases::Union{Nothing, Array{ComplexF64, 3}}
    complement_rotations::Union{Nothing, Array{ComplexF64, 3}}
    target_complement_hamiltonians_ev::Union{Nothing, Array{ComplexF64, 3}}
    complement_hamiltonians_ev::Union{Nothing, Array{ComplexF64, 3}}
end

"""Internal, self-contained payload used while sealing one star-gauge artifact."""
struct _StarCovariantPAWPayload
    native::NativeWavefunctionData
    metric::_AbstractStrictSewingMetric
    operations::Vector{SymmetryOperation}
    kpoint_map::Matrix{Int}
    reciprocal_shifts::Array{Int, 3}
    representative_for_kpoint::Vector{Int}
    canonical_operation_for_kpoint::Vector{Int}
    star_representatives::Vector{Int}
    extra_bands_per_star::Vector{Int}
    rotations::Array{ComplexF64, 3}
    target_band_range::UnitRange{Int}
    parent_band_range::UnitRange{Int}
    maxima::Dict{String, Float64}
    maximum_contexts::Dict{String, String}
    input_sha256::Dict{String, String}
    source_metadata::Dict{String, String}
    qualification_scope::Union{Nothing, BandRepresentationQualificationScope}
    symmetrized_hamiltonian_audit::Union{Nothing, _SymmetrizedDFTHamiltonianAuditPayload}
    sealed_completed_frame_corrections::Union{Nothing, Array{ComplexF64, 3}}
end

"""
Return a payload view whose representative k-points come from the sealed
artifact.

Contract-1.11 frames and target-scoped symmetrized frames are replayed from the
local native source for all physical checks.  That replay is only tolerance-equivalent to the completed
frames written by the producer, whereas the logical payload digest binds the
representative coefficient arrays byte for byte.  This helper is therefore
used only to reconstruct the producer's digest view after the replay-versus-
sealed tolerance gate has passed.
"""
function _star_payload_with_sealed_representatives(
    payload::_StarCovariantPAWPayload,
    representative_points::AbstractDict{Int, PlaneWaveKPoint},
)
    points = copy(payload.native.kpoints)
    for representative in payload.star_representatives
        haskey(representative_points, representative) || throw(
            ArgumentError(
                "PAW_GAUGE_ARTIFACT_TAMPERED: sealed representative inventory is incomplete",
            ),
        )
        points[representative] = representative_points[representative]
    end
    native = NativeWavefunctionData(
        payload.native.source_code,
        payload.native.structure,
        payload.native.reciprocal_lattice,
        payload.native.mp_grid,
        payload.native.spinor,
        points,
        payload.native.input_sha256,
        payload.native.source_metadata,
    )
    return _StarCovariantPAWPayload(
        native,
        payload.metric,
        payload.operations,
        payload.kpoint_map,
        payload.reciprocal_shifts,
        payload.representative_for_kpoint,
        payload.canonical_operation_for_kpoint,
        payload.star_representatives,
        payload.extra_bands_per_star,
        payload.rotations,
        payload.target_band_range,
        payload.parent_band_range,
        payload.maxima,
        payload.maximum_contexts,
        payload.input_sha256,
        payload.source_metadata,
        payload.qualification_scope,
        payload.symmetrized_hamiltonian_audit,
        payload.sealed_completed_frame_corrections,
    )
end

# Preserve the schema-1.3/native construction surface; the new authority audit
# is absent unless a symmetrized Hamiltonian is explicitly selected.
function _StarCovariantPAWPayload(
    native,
    metric,
    operations,
    kpoint_map,
    reciprocal_shifts,
    star_representatives,
    star_of_kpoint,
    transport_operation,
    extra_bands_per_star,
    native_rotations,
    target_band_range,
    parent_band_range,
    maxima,
    maximum_contexts,
    input_sha256,
    source_metadata,
)
    return _StarCovariantPAWPayload(
        native,
        metric,
        operations,
        kpoint_map,
        reciprocal_shifts,
        star_representatives,
        star_of_kpoint,
        transport_operation,
        extra_bands_per_star,
        native_rotations,
        target_band_range,
        parent_band_range,
        maxima,
        maximum_contexts,
        input_sha256,
        source_metadata,
        nothing,
        nothing,
        nothing,
    )
end

# Clone a QE source while changing only its contiguous native band selection.
function _star_source_with_band_range(
    source::QuantumEspressoWavefunctionSource,
    band_range::Union{Nothing, UnitRange{Int}},
)
    return QuantumEspressoWavefunctionSource(
        source.save_directory;
        band_range,
        spin_channel = source.spin_channel,
        representation_cutoff_ev = source.representation_cutoff_ev,
        include_time_reversal = source.include_time_reversal,
        magnetic_moments_cartesian = source.magnetic_moments_cartesian,
    )
end

"""Encode an optional replay path as an absolute locator or the `NONE` sentinel."""
_star_replay_optional_path(path) = path === nothing ? "NONE" : abspath(something(path))

"""Encode a replay matrix with its dimensions and exact `Float64` bit patterns."""
function _star_replay_bits(values)
    values === nothing && return "NONE"
    array = Matrix{Float64}(values)
    bits = join((string(reinterpret(UInt64, value); base = 16, pad = 16) for value in array), ',')
    return "$(size(array, 1))x$(size(array, 2)):$(bits)"
end

"""Encode replay tuple values as exact `Float64` bit patterns."""
function _star_replay_tuple_bits(values)
    values === nothing && return "NONE"
    return join(
        (string(reinterpret(UInt64, Float64(value)); base = 16, pad = 16) for value in values),
        ',',
    )
end

# Store only a replay locator and constructor settings in the logical payload;
# the independently persisted input SHA-256 map remains the scientific identity.
function _star_source_replay_metadata(source::VASPWavefunctionSource)
    source.band_range === nothing &&
        throw(ArgumentError("PAW_GAUGE_SOURCE_REPLAY_REQUIRED: VASP replay requires a band range"))
    return Dict(
        "source_replay_schema" => "1.0",
        "source_replay_kind" => "vasp",
        "source_replay_path_policy" => "absolute_local_locator_hash_authority",
        "source_replay_poscar_file" => abspath(source.poscar_file),
        "source_replay_wavecar_file" => abspath(source.wavecar_file),
        "source_replay_potcar_file" => _star_replay_optional_path(source.potcar_file),
        "source_replay_incar_file" => _star_replay_optional_path(source.incar_file),
        "source_replay_outcar_file" => _star_replay_optional_path(source.outcar_file),
        "source_replay_spin_basis_saxis" => _star_replay_tuple_bits(source.spin_basis_saxis),
        "source_replay_band_start" => string(first(something(source.band_range))),
        "source_replay_band_stop" => string(last(something(source.band_range))),
        "source_replay_spin_channel" => string(source.spin_channel),
        "source_replay_spinor" => source.spinor === nothing ? "NONE" : string(source.spinor),
        "source_replay_representation_cutoff_ev" =>
            source.representation_cutoff_ev === nothing ? "NONE" :
            repr(source.representation_cutoff_ev),
        "source_replay_include_time_reversal" => string(source.include_time_reversal),
        "source_replay_magnetic_moments" => _star_replay_bits(source.magnetic_moments_cartesian),
    )
end

"""Serialize a QE source locator and constructor settings for deterministic replay."""
function _star_source_replay_metadata(source::QuantumEspressoWavefunctionSource)
    source.band_range === nothing &&
        throw(ArgumentError("PAW_GAUGE_SOURCE_REPLAY_REQUIRED: QE replay requires a band range"))
    return Dict(
        "source_replay_schema" => "1.0",
        "source_replay_kind" => "qe",
        "source_replay_path_policy" => "absolute_local_locator_hash_authority",
        "source_replay_save_directory" => abspath(source.save_directory),
        "source_replay_band_start" => string(first(something(source.band_range))),
        "source_replay_band_stop" => string(last(something(source.band_range))),
        "source_replay_spin_channel" => string(source.spin_channel),
        "source_replay_representation_cutoff_ev" =>
            source.representation_cutoff_ev === nothing ? "NONE" :
            repr(source.representation_cutoff_ev),
        "source_replay_include_time_reversal" => string(source.include_time_reversal),
        "source_replay_magnetic_moments" => _star_replay_bits(source.magnetic_moments_cartesian),
    )
end

"""Hash the source replay descriptor while excluding its stored digest field."""
function _star_source_replay_descriptor_sha256(metadata::AbstractDict{String, String})
    descriptor = Dict(
        key => value for (key, value) in metadata if
        startswith(key, "source_replay_") && key != "source_replay_descriptor_sha256"
    )
    return _star_block_partition_policy_sha256(descriptor)
end

"""Parse a strict replay Boolean or reject tampered metadata."""
function _star_parse_replay_bool(value::AbstractString, key::AbstractString)
    value == "true" && return true
    value == "false" && return false
    throw(ArgumentError("PAW_GAUGE_ARTIFACT_TAMPERED: invalid $(key)"))
end

"""Decode the `NONE` replay-path sentinel as `nothing`."""
_star_parse_replay_optional_path(value::AbstractString) = value == "NONE" ? nothing : value

"""Decode a dimensioned `Float64` bit payload or reject malformed replay metadata."""
function _star_parse_replay_bits(value::AbstractString, key::AbstractString)
    value == "NONE" && return nothing
    pieces = split(value, ':'; limit = 2)
    length(pieces) == 2 ||
        throw(ArgumentError("PAW_GAUGE_ARTIFACT_TAMPERED: invalid $(key) dimensions"))
    dimensions = split(pieces[1], 'x')
    length(dimensions) == 2 ||
        throw(ArgumentError("PAW_GAUGE_ARTIFACT_TAMPERED: invalid $(key) dimensions"))
    rows = tryparse(Int, dimensions[1])
    columns = tryparse(Int, dimensions[2])
    rows !== nothing && columns !== nothing && rows > 0 && columns > 0 ||
        throw(ArgumentError("PAW_GAUGE_ARTIFACT_TAMPERED: invalid $(key) dimensions"))
    encoded = split(pieces[2], ',')
    length(encoded) == something(rows) * something(columns) ||
        throw(ArgumentError("PAW_GAUGE_ARTIFACT_TAMPERED: invalid $(key) value count"))
    values = Float64[]
    for item in encoded
        bits = tryparse(UInt64, item; base = 16)
        bits === nothing &&
            throw(ArgumentError("PAW_GAUGE_ARTIFACT_TAMPERED: invalid $(key) value"))
        push!(values, reinterpret(Float64, something(bits)))
    end
    all(isfinite, values) ||
        throw(ArgumentError("PAW_GAUGE_ARTIFACT_TAMPERED: non-finite $(key) value"))
    return reshape(values, something(rows), something(columns))
end

"""Decode an exact three-component SAXIS tuple or reject malformed replay metadata."""
function _star_parse_replay_saxis(value::AbstractString)
    value == "NONE" && return nothing
    encoded = split(value, ',')
    length(encoded) == 3 ||
        throw(ArgumentError("PAW_GAUGE_ARTIFACT_TAMPERED: invalid source replay SAXIS"))
    values = map(encoded) do item
        bits = tryparse(UInt64, item; base = 16)
        bits === nothing &&
            throw(ArgumentError("PAW_GAUGE_ARTIFACT_TAMPERED: invalid source replay SAXIS"))
        reinterpret(Float64, something(bits))
    end
    all(isfinite, values) ||
        throw(ArgumentError("PAW_GAUGE_ARTIFACT_TAMPERED: non-finite source replay SAXIS"))
    return Tuple(values)
end

"""Validate replay metadata and reconstruct its full-cutoff VASP or QE source."""
function _star_source_from_replay_metadata(metadata::Dict{String, String})
    get(metadata, "source_replay_schema", "") == "1.0" ||
        throw(ArgumentError("PAW_GAUGE_SOURCE_REPLAY_REQUIRED: source descriptor is missing"))
    get(metadata, "source_replay_path_policy", "") == "absolute_local_locator_hash_authority" ||
        throw(ArgumentError("PAW_GAUGE_ARTIFACT_TAMPERED: unsupported source replay path policy"))
    get(metadata, "source_replay_descriptor_sha256", "") ==
    _star_source_replay_descriptor_sha256(metadata) ||
        throw(ArgumentError("PAW_GAUGE_ARTIFACT_TAMPERED: source replay descriptor digest differs"))
    first_band = tryparse(Int, get(metadata, "source_replay_band_start", ""))
    last_band = tryparse(Int, get(metadata, "source_replay_band_stop", ""))
    first_band !== nothing && last_band !== nothing && 0 < first_band <= last_band ||
        throw(ArgumentError("PAW_GAUGE_ARTIFACT_TAMPERED: invalid source replay band range"))
    band_range = something(first_band):something(last_band)
    cutoff = get(metadata, "source_replay_representation_cutoff_ev", "MISSING")
    cutoff == "NONE" ||
        throw(ArgumentError("PAW_SEWING_FULL_CUTOFF_REQUIRED: replay source is not full cutoff"))
    include_time_reversal = _star_parse_replay_bool(
        get(metadata, "source_replay_include_time_reversal", ""),
        "source replay time-reversal flag",
    )
    moments = _star_parse_replay_bits(
        get(metadata, "source_replay_magnetic_moments", "MISSING"),
        "source replay magnetic moments",
    )
    kind = get(metadata, "source_replay_kind", "")
    if kind == "vasp"
        spin_channel = tryparse(Int, get(metadata, "source_replay_spin_channel", ""))
        spin_channel !== nothing && spin_channel > 0 ||
            throw(ArgumentError("PAW_GAUGE_ARTIFACT_TAMPERED: invalid VASP replay spin channel"))
        spinor_value = get(metadata, "source_replay_spinor", "MISSING")
        spinor =
            spinor_value == "NONE" ? nothing :
            _star_parse_replay_bool(spinor_value, "VASP replay spinor flag")
        return VASPWavefunctionSource(
            get(metadata, "source_replay_poscar_file", ""),
            get(metadata, "source_replay_wavecar_file", "");
            potcar_file = _star_parse_replay_optional_path(
                get(metadata, "source_replay_potcar_file", "MISSING"),
            ),
            incar_file = _star_parse_replay_optional_path(
                get(metadata, "source_replay_incar_file", "MISSING"),
            ),
            outcar_file = _star_parse_replay_optional_path(
                get(metadata, "source_replay_outcar_file", "MISSING"),
            ),
            spin_basis_saxis = _star_parse_replay_saxis(
                get(metadata, "source_replay_spin_basis_saxis", "MISSING"),
            ),
            band_range,
            spin_channel = something(spin_channel),
            spinor,
            representation_cutoff_ev = nothing,
            include_time_reversal,
            magnetic_moments_cartesian = moments,
        )
    elseif kind == "qe"
        spin_channel = Symbol(get(metadata, "source_replay_spin_channel", ""))
        spin_channel in (:none, :up, :down) ||
            throw(ArgumentError("PAW_GAUGE_ARTIFACT_TAMPERED: invalid QE replay spin channel"))
        return QuantumEspressoWavefunctionSource(
            get(metadata, "source_replay_save_directory", "");
            band_range,
            spin_channel,
            representation_cutoff_ev = nothing,
            include_time_reversal,
            magnetic_moments_cartesian = moments,
        )
    end
    throw(ArgumentError("PAW_GAUGE_ARTIFACT_TAMPERED: unsupported source replay kind"))
end

# Clone a VASP source while changing only its contiguous native band selection.
function _star_source_with_band_range(
    source::VASPWavefunctionSource,
    band_range::Union{Nothing, UnitRange{Int}},
)
    return VASPWavefunctionSource(
        source.poscar_file,
        source.wavecar_file;
        potcar_file = source.potcar_file,
        incar_file = source.incar_file,
        outcar_file = source.outcar_file,
        spin_basis_saxis = source.spin_basis_saxis,
        band_range,
        spin_channel = source.spin_channel,
        spinor = source.spinor,
        representation_cutoff_ev = source.representation_cutoff_ev,
        include_time_reversal = source.include_time_reversal,
        magnetic_moments_cartesian = source.magnetic_moments_cartesian,
    )
end

# Apply one rectangular band-column rotation to row-stored coefficient/projector data.
function _star_rotate_rows(values::Array{ComplexF64, 3}, rotation::AbstractMatrix)
    output = zeros(ComplexF64, size(rotation, 2), size(values, 2), size(values, 3))
    for spin in axes(values, 3)
        output[:, :, spin] .= transpose(rotation) * @view(values[:, :, spin])
    end
    return output
end

# Audit whether every sealed per-k completed parent frame lies in the raw
# symmetry image of its representative.  This is a physical hard gate for the
# legacy full-parent contract, but only an audit for target-subspace authority:
# the independently completed local H_CC complement is not required to share
# the representative parent span.
function _star_sealed_completed_frame_corrections(
    native::NativeWavefunctionData,
    metric::_AbstractStrictSewingMetric,
    operations::Vector{SymmetryOperation},
    reciprocal_shifts::Array{Int, 3},
    representative_for_kpoint::Vector{Int},
    canonical_operation_for_kpoint::Vector{Int};
    reconstruction_threshold::Float64,
    enforce_threshold::Bool = true,
)
    isfinite(reconstruction_threshold) && reconstruction_threshold > 0.0 ||
        throw(ArgumentError("sealed-frame reconstruction threshold must be finite and positive"))
    nkpoints = length(native.kpoints)
    length(representative_for_kpoint) == nkpoints ||
        throw(ArgumentError("PAW_GAUGE_ARTIFACT_TAMPERED: representative map size differs"))
    length(canonical_operation_for_kpoint) == nkpoints ||
        throw(ArgumentError("PAW_GAUGE_ARTIFACT_TAMPERED: operation map size differs"))
    band_count = size(first(native.kpoints).coefficients, 1)
    corrections = zeros(ComplexF64, band_count, band_count, nkpoints)
    maximum_reconstruction = 0.0
    maximum_isometry = 0.0
    minimum_source_metric_singular_value = Inf
    worst_reconstruction = "NOT_RECORDED"
    worst_isometry = "NOT_RECORDED"
    for kpoint in eachindex(native.kpoints)
        representative = representative_for_kpoint[kpoint]
        representative in eachindex(native.kpoints) ||
            throw(ArgumentError("PAW_GAUGE_ARTIFACT_TAMPERED: invalid representative index"))
        if kpoint == representative
            corrections[:, :, kpoint] .= Matrix{ComplexF64}(I, band_count, band_count)
            continue
        end
        operation_index = canonical_operation_for_kpoint[kpoint]
        operation_index in eachindex(operations) ||
            throw(ArgumentError("PAW_GAUGE_ARTIFACT_TAMPERED: invalid canonical operation index"))
        representative_point = native.kpoints[representative]
        sealed_point = native.kpoints[kpoint]
        size(sealed_point.coefficients, 1) == band_count ||
            throw(ArgumentError("PAW_GAUGE_ARTIFACT_TAMPERED: completed frame rank differs"))
        template = PlaneWaveKPoint(
            sealed_point.k_fractional,
            sealed_point.g_vectors,
            zeros(ComplexF64, size(sealed_point.coefficients)),
            sealed_point.energies_ev;
            normalize_coefficients = false,
        )
        raw_coefficients = _strict_transform_plane_wave_coefficients(
            representative_point,
            template,
            operations[operation_index],
            @view(reciprocal_shifts[:, operation_index, representative]),
        )
        raw_projectors = _strict_transformed_projectors(metric, kpoint, raw_coefficients)
        sealed_projectors = metric.projectors[kpoint]
        raw_metric, _, _ = _strict_metric_overlap(
            metric,
            raw_coefficients,
            raw_coefficients,
            raw_projectors,
            raw_projectors,
        )
        cross_metric, _, _ = _strict_metric_overlap(
            metric,
            raw_coefficients,
            sealed_point.coefficients,
            raw_projectors,
            sealed_projectors,
        )
        all(isfinite, raw_metric) && all(isfinite, cross_metric) ||
            throw(ArgumentError("PAW_GAUGE_ARTIFACT_TAMPERED: non-finite sealed-frame metric"))
        minimum_singular_value = minimum(svdvals(raw_metric))
        minimum_source_metric_singular_value =
            min(minimum_source_metric_singular_value, minimum_singular_value)
        !enforce_threshold ||
            minimum_singular_value > 1.0e-10 ||
            throw(
                ArgumentError(
                    "PAW_GAUGE_ARTIFACT_TAMPERED: sealed-frame source metric is rank deficient",
                ),
            )
        correction =
            minimum_singular_value > 1.0e-10 ? raw_metric \ cross_metric :
            pinv(raw_metric; rtol = 1.0e-10) * cross_metric
        all(isfinite, correction) ||
            throw(ArgumentError("PAW_GAUGE_ARTIFACT_TAMPERED: non-finite sealed-frame correction"))
        corrections[:, :, kpoint] .= correction
        reconstructed_coefficients = _star_rotate_rows(raw_coefficients, correction)
        reconstructed_projectors = _star_rotate_rows(raw_projectors, correction)
        reconstruction = max(
            maximum(abs, reconstructed_coefficients - sealed_point.coefficients),
            maximum(abs, reconstructed_projectors - sealed_projectors),
        )
        sealed_metric, _, _ = _strict_metric_overlap(
            metric,
            sealed_point.coefficients,
            sealed_point.coefficients,
            sealed_projectors,
            sealed_projectors,
        )
        isometry = maximum(abs, correction' * raw_metric * correction - sealed_metric)
        if reconstruction > maximum_reconstruction
            maximum_reconstruction = reconstruction
            worst_reconstruction = "representative=$(representative),target=$(kpoint),operation=$(operation_index)"
        end
        if isometry > maximum_isometry
            maximum_isometry = isometry
            worst_isometry = "representative=$(representative),target=$(kpoint),operation=$(operation_index)"
        end
    end
    !enforce_threshold ||
        maximum_reconstruction <= reconstruction_threshold ||
        throw(
            ArgumentError(
                "PAW_GAUGE_ARTIFACT_ROUNDTRIP_HOLD: sealed-frame reconstruction " *
                "$(maximum_reconstruction) exceeds $(reconstruction_threshold); " *
                worst_reconstruction,
            ),
        )
    !enforce_threshold ||
        maximum_isometry <= reconstruction_threshold ||
        throw(
            ArgumentError(
                "PAW_GAUGE_ARTIFACT_ROUNDTRIP_HOLD: sealed-frame isometry " *
                "$(maximum_isometry) exceeds $(reconstruction_threshold); " *
                worst_isometry,
            ),
        )
    return (
        corrections = corrections,
        maximum_reconstruction = maximum_reconstruction,
        maximum_isometry = maximum_isometry,
        worst_reconstruction = worst_reconstruction,
        worst_isometry = worst_isometry,
        minimum_source_metric_singular_value = isfinite(minimum_source_metric_singular_value) ?
                                               minimum_source_metric_singular_value : 1.0,
    )
end

# Transform one sewing block under the frozen band-column gauge convention.
function _star_transform_sewing_gauge(
    sewing::AbstractMatrix{<:Complex},
    target_rotation::AbstractMatrix{<:Complex},
    source_rotation::AbstractMatrix{<:Complex},
    antiunitary::Bool,
)
    right = antiunitary ? conj(source_rotation) : source_rotation
    return target_rotation' * sewing * right
end

# Replace cached projectors after a PAW-S Lowdin rotation without changing the metric data.
function _star_metric_with_projectors(
    metric::_QEStrictSewingMetric,
    projectors::Vector{Array{ComplexF64, 3}},
)
    return _QEStrictSewingMetric(
        metric.upf_data,
        metric.plan,
        projectors,
        metric.projector_bases,
        metric.spinorbit,
        metric.finite_b_cache,
        metric.metric_kind,
    )
end

# Replay one completed parent frame from the exact local native source and the
# digest-bound per-k band rotations.  Unlike representative transport, this
# recipe remains complete when the audit-only local complement changes span.
function _star_replay_local_completed_frame(
    raw_native::NativeWavefunctionData,
    raw_metric::_AbstractStrictSewingMetric,
    rotations::Array{ComplexF64, 3},
    energies_ev::AbstractMatrix{<:Real};
    reference_native::Union{Nothing, NativeWavefunctionData} = nothing,
    reference_metric::Union{Nothing, _AbstractStrictSewingMetric} = nothing,
)
    nkpoints = length(raw_native.kpoints)
    parent_count = size(first(raw_native.kpoints).coefficients, 1)
    target_count = size(rotations, 2)
    size(rotations) == (parent_count, target_count, nkpoints) || throw(
        ArgumentError(
            "PAW_GAUGE_ARTIFACT_TAMPERED: local-source replay rotation dimensions differ",
        ),
    )
    size(energies_ev) == (target_count, nkpoints) ||
        throw(ArgumentError("PAW_GAUGE_ARTIFACT_TAMPERED: local-source replay energies differ"))
    all(isfinite, rotations) && all(isfinite, energies_ev) ||
        throw(ArgumentError("PAW_GAUGE_ARTIFACT_TAMPERED: local-source replay data are non-finite"))
    (reference_native === nothing) == (reference_metric === nothing) || throw(
        ArgumentError(
            "PAW_GAUGE_ARTIFACT_TAMPERED: replay wavefunction/metric references are incomplete",
        ),
    )
    reference_native === nothing ||
        length(something(reference_native).kpoints) == nkpoints ||
        throw(ArgumentError("PAW_GAUGE_ARTIFACT_TAMPERED: replay reference k-count differs"))

    points = PlaneWaveKPoint[]
    projectors = Array{ComplexF64, 3}[]
    maximum_coefficient_reconstruction = 0.0
    maximum_projector_reconstruction = 0.0
    worst_coefficient_reconstruction = "NOT_RECORDED"
    worst_projector_reconstruction = "NOT_RECORDED"
    for kpoint in eachindex(raw_native.kpoints)
        raw_point = raw_native.kpoints[kpoint]
        rotation = @view(rotations[:, :, kpoint])
        coefficients = _star_rotate_rows(raw_point.coefficients, rotation)
        completed_projectors = _star_rotate_rows(raw_metric.projectors[kpoint], rotation)
        point = PlaneWaveKPoint(
            raw_point.k_fractional,
            raw_point.g_vectors,
            coefficients,
            Vector{Float64}(@view(energies_ev[:, kpoint]));
            normalize_coefficients = false,
        )
        push!(points, point)
        push!(projectors, completed_projectors)
        if reference_native !== nothing
            reference_point = something(reference_native).kpoints[kpoint]
            reference_point.k_fractional == point.k_fractional || throw(
                ArgumentError("PAW_GAUGE_ARTIFACT_TAMPERED: replay k-point coordinates differ"),
            )
            reference_point.g_vectors == point.g_vectors ||
                throw(ArgumentError("PAW_GAUGE_ARTIFACT_TAMPERED: replay plane-wave basis differs"))
            coefficient_reconstruction = maximum(abs, coefficients - reference_point.coefficients)
            if coefficient_reconstruction > maximum_coefficient_reconstruction
                maximum_coefficient_reconstruction = coefficient_reconstruction
                worst_coefficient_reconstruction = "kpoint=$(kpoint)"
            end
            projector_reconstruction =
                maximum(abs, completed_projectors - something(reference_metric).projectors[kpoint])
            if projector_reconstruction > maximum_projector_reconstruction
                maximum_projector_reconstruction = projector_reconstruction
                worst_projector_reconstruction = "kpoint=$(kpoint)"
            end
        end
    end
    completed_metric = _star_metric_with_projectors(raw_metric, projectors)
    return (
        points = points,
        metric = completed_metric,
        maximum_coefficient_reconstruction = maximum_coefficient_reconstruction,
        maximum_projector_reconstruction = maximum_projector_reconstruction,
        worst_coefficient_reconstruction = worst_coefficient_reconstruction,
        worst_projector_reconstruction = worst_projector_reconstruction,
    )
end

"""Construct and hard-qualify one raw-source to completed-frame transform."""
function _build_band_frame_transform_contract(
    raw_native::NativeWavefunctionData,
    raw_metric::_AbstractStrictSewingMetric,
    completed_native::NativeWavefunctionData,
    completed_metric::_AbstractStrictSewingMetric,
    transforms::Array{ComplexF64, 3};
    source_band_gauge::AbstractString,
    target_band_gauge::AbstractString,
    source_identity_sha256::AbstractString,
    physical_isometry_tolerance::Float64,
    replay_tolerance::Float64,
    replay_evidence = nothing,
)
    nkpoints = length(raw_native.kpoints)
    parent_count = size(first(raw_native.kpoints).coefficients, 1)
    target_count = size(first(completed_native.kpoints).coefficients, 1)
    length(completed_native.kpoints) == nkpoints ||
        throw(ArgumentError("BAND_FRAME_TOPOLOGY_MISMATCH: source and target k-counts differ"))
    size(transforms) == (parent_count, target_count, nkpoints) || throw(
        ArgumentError(
            "BAND_FRAME_DIMENSION_MISMATCH: expected ($(parent_count), $(target_count), $(nkpoints)), got $(size(transforms))",
        ),
    )
    all(isfinite, transforms) ||
        throw(ArgumentError("BAND_FRAME_NONFINITE: transform contains NaN or Inf"))
    isfinite(physical_isometry_tolerance) && physical_isometry_tolerance > 0.0 ||
        throw(ArgumentError("band-frame physical-isometry tolerance must be positive and finite"))
    isfinite(replay_tolerance) && replay_tolerance > 0.0 ||
        throw(ArgumentError("band-frame replay tolerance must be positive and finite"))

    source_metrics = Matrix{ComplexF64}[]
    for kpoint in 1:nkpoints
        raw_point = raw_native.kpoints[kpoint]
        target_point = completed_native.kpoints[kpoint]
        maximum(abs, raw_point.k_fractional - target_point.k_fractional) <= 1.0e-10 || throw(
            ArgumentError("BAND_FRAME_TOPOLOGY_MISMATCH: kpoint=$(kpoint) coordinates differ"),
        )
        source_metric, _, _ = _strict_metric_overlap(
            raw_metric,
            raw_point.coefficients,
            raw_point.coefficients,
            raw_metric.projectors[kpoint],
            raw_metric.projectors[kpoint],
        )
        push!(source_metrics, source_metric)
    end
    audit = _audit_band_frame_transforms(source_metrics, transforms)
    physical_isometry_maximum = audit.physical_isometry_maximum
    euclidean_nonunitarity_maximum = audit.euclidean_nonunitarity_maximum
    minimum_singular_value = audit.minimum_singular_value
    maximum_condition_number = audit.maximum_condition_number
    physical_isometry_maximum <= physical_isometry_tolerance || throw(
        ArgumentError(
            "BAND_FRAME_PHYSICAL_ISOMETRY_FAILED: residual $(physical_isometry_maximum) exceeds $(physical_isometry_tolerance)",
        ),
    )

    evidence =
        replay_evidence === nothing ?
        _star_replay_local_completed_frame(
            raw_native,
            raw_metric,
            transforms,
            hcat((point.energies_ev for point in completed_native.kpoints)...);
            reference_native = completed_native,
            reference_metric = completed_metric,
        ) : replay_evidence
    replay_maximum = max(
        Float64(evidence.maximum_coefficient_reconstruction),
        Float64(evidence.maximum_projector_reconstruction),
    )
    isfinite(replay_maximum) && replay_maximum <= replay_tolerance || throw(
        ArgumentError(
            "BAND_FRAME_REPLAY_FAILED: residual $(replay_maximum) exceeds $(replay_tolerance)",
        ),
    )
    transform_sha256 = _star_array_sha256(transforms)
    metric_sha256 = _star_metric_sha256(raw_metric)
    metric_kind = _band_frame_metric_kind(raw_metric)
    contract_sha256 = band_frame_contract_sha256(
        source_band_gauge,
        target_band_gauge,
        transform_sha256,
        source_identity_sha256,
        metric_sha256,
        metric_kind,
        physical_isometry_maximum,
        physical_isometry_tolerance,
        replay_maximum,
        replay_tolerance,
        euclidean_nonunitarity_maximum,
        minimum_singular_value,
        maximum_condition_number,
    )
    return BandFrameTransformContract(
        String(source_band_gauge),
        String(target_band_gauge),
        copy(transforms),
        transform_sha256,
        contract_sha256,
        nothing,
        metric_kind,
        physical_isometry_maximum,
        physical_isometry_tolerance,
        replay_maximum,
        replay_tolerance,
        euclidean_nonunitarity_maximum,
        minimum_singular_value,
        maximum_condition_number,
        BAND_FRAME_TRANSFORM_CONTRACT_SCHEMA,
        BAND_FRAME_TRANSFORM_CONTRACT_SCHEMA_VERSION,
        "PASS",
        false,
    )
end

"""Restore persisted evidence and independently recheck its physical invariant."""
function _restore_band_frame_transform_contract(
    metadata::Dict{String, String},
    input_sha256::Dict{String, String},
    raw_native::NativeWavefunctionData,
    raw_metric::_AbstractStrictSewingMetric,
    completed_native::NativeWavefunctionData,
    completed_metric::_AbstractStrictSewingMetric,
    transforms::Array{ComplexF64, 3},
    gauge_artifact_sha256::String,
)
    get(metadata, "band_frame_contract_schema", "") == BAND_FRAME_TRANSFORM_CONTRACT_SCHEMA ||
        throw(ArgumentError("BAND_FRAME_CONTRACT_SCHEMA_MISMATCH"))
    get(metadata, "band_frame_contract_schema_version", "") ==
    BAND_FRAME_TRANSFORM_CONTRACT_SCHEMA_VERSION ||
        throw(ArgumentError("BAND_FRAME_CONTRACT_VERSION_MISMATCH"))
    get(metadata, "band_frame_contract_status", "") == "PASS" ||
        throw(ArgumentError("BAND_FRAME_CONTRACT_NOT_QUALIFIED"))
    transform_sha256 = _star_array_sha256(transforms)
    transform_sha256 == get(metadata, "band_frame_transform_sha256", "") ||
        throw(ArgumentError("BAND_FRAME_TRANSFORM_DIGEST_MISMATCH"))
    get(input_sha256, "BAND_FRAME_TRANSFORM_SHA256", "") == transform_sha256 ||
        throw(ArgumentError("BAND_FRAME_TRANSFORM_DIGEST_MISMATCH"))
    physical_maximum = _band_frame_float(metadata, "band_frame_physical_isometry_maximum")
    physical_tolerance = _band_frame_float(metadata, "band_frame_physical_isometry_tolerance")
    replay_maximum = _band_frame_float(metadata, "band_frame_replay_maximum")
    replay_tolerance = _band_frame_float(metadata, "band_frame_replay_tolerance")
    euclidean_maximum = _band_frame_float(metadata, "band_frame_euclidean_nonunitarity_maximum")
    minimum_singular_value = _band_frame_float(metadata, "band_frame_minimum_singular_value")
    maximum_condition_number = _band_frame_float(metadata, "band_frame_maximum_condition_number")
    source_identity_sha256 = get(metadata, "source_replay_resource_manifest_sha256", "")
    isempty(source_identity_sha256) &&
        throw(ArgumentError("BAND_FRAME_SOURCE_MISMATCH: source identity is not sealed"))
    expected_contract_sha256 = band_frame_contract_sha256(
        get(metadata, "band_frame_source_gauge", ""),
        get(metadata, "band_frame_target_gauge", ""),
        transform_sha256,
        source_identity_sha256,
        _star_metric_sha256(raw_metric),
        get(metadata, "band_frame_metric_kind", ""),
        physical_maximum,
        physical_tolerance,
        replay_maximum,
        replay_tolerance,
        euclidean_maximum,
        minimum_singular_value,
        maximum_condition_number,
    )
    recorded_contract_sha256 = get(metadata, "band_frame_contract_sha256", "")
    expected_contract_sha256 == recorded_contract_sha256 ||
        throw(ArgumentError("BAND_FRAME_CONTRACT_DIGEST_MISMATCH"))
    get(input_sha256, "BAND_FRAME_CONTRACT_SHA256", "") == recorded_contract_sha256 ||
        throw(ArgumentError("BAND_FRAME_CONTRACT_DIGEST_MISMATCH"))

    live = _build_band_frame_transform_contract(
        raw_native,
        raw_metric,
        completed_native,
        completed_metric,
        transforms;
        source_band_gauge = get(metadata, "band_frame_source_gauge", ""),
        target_band_gauge = get(metadata, "band_frame_target_gauge", ""),
        source_identity_sha256,
        physical_isometry_tolerance = physical_tolerance,
        replay_tolerance,
    )
    comparison_tolerance = max(1.0e-12, 1.0e-6 * physical_tolerance)
    abs(live.physical_isometry_maximum - physical_maximum) <= comparison_tolerance ||
        throw(ArgumentError("BAND_FRAME_PHYSICAL_ISOMETRY_EVIDENCE_MISMATCH"))
    abs(live.euclidean_nonunitarity_maximum - euclidean_maximum) <= comparison_tolerance ||
        throw(ArgumentError("BAND_FRAME_EUCLIDEAN_AUDIT_EVIDENCE_MISMATCH"))
    abs(live.minimum_singular_value - minimum_singular_value) <= comparison_tolerance ||
        throw(ArgumentError("BAND_FRAME_SINGULAR_VALUE_EVIDENCE_MISMATCH"))
    abs(live.maximum_condition_number - maximum_condition_number) <= comparison_tolerance ||
        throw(ArgumentError("BAND_FRAME_CONDITION_EVIDENCE_MISMATCH"))
    live.replay_maximum <= replay_maximum + max(1.0e-14, 1.0e-6 * replay_tolerance) ||
        throw(ArgumentError("BAND_FRAME_REPLAY_EVIDENCE_MISMATCH"))
    return BandFrameTransformContract(
        get(metadata, "band_frame_source_gauge", ""),
        get(metadata, "band_frame_target_gauge", ""),
        copy(transforms),
        transform_sha256,
        recorded_contract_sha256,
        gauge_artifact_sha256,
        get(metadata, "band_frame_metric_kind", ""),
        physical_maximum,
        physical_tolerance,
        replay_maximum,
        replay_tolerance,
        euclidean_maximum,
        minimum_singular_value,
        maximum_condition_number,
        BAND_FRAME_TRANSFORM_CONTRACT_SCHEMA,
        BAND_FRAME_TRANSFORM_CONTRACT_SCHEMA_VERSION,
        "PASS",
        false,
    )
end

# Evaluate PAW-S normalization only inside the ragged authoritative outer
# window.  Complement rows and columns remain a separately reported parent
# audit and cannot demote target-subspace qualification.
function _star_scoped_generalized_norm_from_metric(
    metric::_AbstractStrictSewingMetric,
    native::NativeWavefunctionData,
    outer_mask::AbstractMatrix{Bool},
)
    parent_count = size(first(native.kpoints).coefficients, 1)
    size(outer_mask) == (parent_count, length(native.kpoints)) ||
        throw(ArgumentError("TARGET_MASK_DIMENSION_HOLD: scoped PAW norm mask dimensions differ"))
    maximum_residual = 0.0
    worst = (kpoint = 0, target_band = 0, source_band = 0)
    for kpoint in eachindex(native.kpoints)
        indices = findall(@view(outer_mask[:, kpoint]))
        isempty(indices) &&
            throw(ArgumentError("TARGET_MASK_RANK_HOLD: scoped PAW norm target is empty"))
        point = native.kpoints[kpoint]
        coefficients = point.coefficients[indices, :, :]
        projectors = metric.projectors[kpoint][indices, :, :]
        overlap, _, _ =
            _strict_metric_overlap(metric, coefficients, coefficients, projectors, projectors)
        residual = abs.(overlap - I)
        index = argmax(residual)
        value = residual[index]
        if value > maximum_residual
            maximum_residual = value
            worst =
                (kpoint = kpoint, target_band = indices[index[1]], source_band = indices[index[2]])
        end
    end
    return maximum_residual, worst
end

# Replace cached VASP projectors after a PAW-S Lowdin rotation.
function _star_metric_with_projectors(
    metric::_VASPStrictSewingMetric,
    projectors::Vector{Array{ComplexF64, 3}},
)
    return _VASPStrictSewingMetric(metric.paw, projectors, metric.projector_bases)
end

"""
PAW-S orthogonalize every native parent frame by a symmetric Lowdin map.

The returned rotations obey `C_new = transpose(U) * C_native` and the same map
is applied to beta-projector overlaps. Energies and k-point order are unchanged.
"""
function _star_lowdin_native(
    native::NativeWavefunctionData,
    metric::_AbstractStrictSewingMetric,
    threshold::Float64,
    ;
    enforce_residual::Bool = true,
)
    points = PlaneWaveKPoint[]
    projectors = Array{ComplexF64, 3}[]
    rotations = Matrix{ComplexF64}[]
    hamiltonians = Matrix{ComplexF64}[]
    maximum_before = 0.0
    maximum_after = 0.0
    worst_context = "NOT_RECORDED"
    for kpoint in eachindex(native.kpoints)
        point = native.kpoints[kpoint]
        projector = metric.projectors[kpoint]
        overlap, _, _ = _strict_metric_overlap(
            metric,
            point.coefficients,
            point.coefficients,
            projector,
            projector,
        )
        hermitian = Hermitian(0.5 .* (overlap + overlap'))
        decomposition = eigen(hermitian)
        minimum(decomposition.values) > 1.0e-10 || throw(
            ArgumentError(
                "PAW_GAUGE_METRIC_RANK_HOLD: nonpositive PAW-S eigenvalue at k=$(kpoint)",
            ),
        )
        lowdin =
            decomposition.vectors *
            Diagonal(inv.(sqrt.(decomposition.values))) *
            decomposition.vectors'
        coefficients = _star_rotate_rows(point.coefficients, lowdin)
        rotated_projectors = _star_rotate_rows(projector, lowdin)
        normalized, _, _ = _strict_metric_overlap(
            metric,
            coefficients,
            coefficients,
            rotated_projectors,
            rotated_projectors,
        )
        before = maximum(abs, overlap - I)
        after = maximum(abs, normalized - I)
        if before > maximum_before
            maximum_before = before
            worst_context = "kpoint=$(kpoint)"
        end
        maximum_after = max(maximum_after, after)
        !enforce_residual ||
            after <= threshold ||
            throw(
                ArgumentError(
                    "PAW_GAUGE_NORM_HOLD: Lowdin PAW-S residual $(after) exceeds $(threshold); " *
                    "kpoint=$(kpoint)",
                ),
            )
        push!(
            points,
            PlaneWaveKPoint(
                point.k_fractional,
                point.g_vectors,
                coefficients,
                point.energies_ev;
                normalize_coefficients = false,
            ),
        )
        push!(projectors, rotated_projectors)
        push!(rotations, lowdin)
        push!(hamiltonians, lowdin' * Diagonal(point.energies_ev) * lowdin)
    end
    lowdin_native = NativeWavefunctionData(
        native.source_code,
        native.structure,
        native.reciprocal_lattice,
        native.mp_grid,
        native.spinor,
        points,
        native.input_sha256,
        merge(
            native.source_metadata,
            Dict(
                "wavefunction_gauge_preparation" => "paw_s_symmetric_lowdin",
                "coefficient_normalization" =>
                    get(native.source_metadata, "coefficient_normalization", "raw"),
            ),
        ),
    )
    return (
        native = lowdin_native,
        metric = _star_metric_with_projectors(metric, projectors),
        rotations,
        hamiltonians,
        maximum_before,
        maximum_after,
        worst_context,
    )
end
