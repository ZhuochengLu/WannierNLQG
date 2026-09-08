const NATIVE_DFT_BAND_GAUGE = "native_dft_eigenstate"
const SAWF_COMPLETED_NATIVE_DFT_BAND_GAUGE = "sawf_completed_native_dft"
const SYMMETRIZED_DFT_BAND_GAUGE = "symmetrized_dft_hamiltonian"

const BAND_FRAME_TRANSFORM_CONTRACT_SCHEMA = "WannierNLQG.band_frame_transform_contract"
const BAND_FRAME_TRANSFORM_CONTRACT_SCHEMA_VERSION = "1.0"

"""
Digest-bound qualification of a physical-metric band-frame transform.

`transforms[:, :, k]` maps raw source-band columns to the sealed target frame.
It is generally not Euclidean-unitary after PAW/USPP Lowdin normalization. Its
formal invariant is `T' * S_source * T = I`; the Euclidean residual is retained
only as an audit quantity.
"""
struct BandFrameTransformContract
    source_band_gauge::String
    target_band_gauge::String
    transforms::Union{Nothing, Array{ComplexF64, 3}}
    transform_sha256::String
    contract_sha256::String
    gauge_artifact_sha256::Union{Nothing, String}
    metric_kind::String
    physical_isometry_maximum::Float64
    physical_isometry_tolerance::Float64
    replay_maximum::Float64
    replay_tolerance::Float64
    euclidean_nonunitarity_maximum::Float64
    minimum_singular_value::Float64
    maximum_condition_number::Float64
    schema::String
    schema_version::String
    status::String
    legacy::Bool
end

# Compatibility aliases while schema-1.1 operator sidecars migrate from the
# historical (and physically misleading) `band_gauge_rotation` terminology.
function Base.getproperty(contract::BandFrameTransformContract, name::Symbol)
    name === :rotations && return getfield(contract, :transforms)
    name === :rotation_sha256 && return getfield(contract, :transform_sha256)
    return getfield(contract, name)
end

"""Expose the frame fields together with the two diagnostic legacy aliases."""
function Base.propertynames(::BandFrameTransformContract, private::Bool = false)
    names = fieldnames(BandFrameTransformContract)
    return private ? (names..., :rotations, :rotation_sha256) :
           (names..., :rotations, :rotation_sha256)
end

"""Digest the complete physical frame qualification contract."""
function band_frame_contract_sha256(
    source_band_gauge::AbstractString,
    target_band_gauge::AbstractString,
    transform_sha256::AbstractString,
    source_identity_sha256::AbstractString,
    metric_sha256::AbstractString,
    metric_kind::AbstractString,
    physical_isometry_maximum::Float64,
    physical_isometry_tolerance::Float64,
    replay_maximum::Float64,
    replay_tolerance::Float64,
    euclidean_nonunitarity_maximum::Float64,
    minimum_singular_value::Float64,
    maximum_condition_number::Float64,
)
    buffer = IOBuffer()
    for value in (
        BAND_FRAME_TRANSFORM_CONTRACT_SCHEMA,
        BAND_FRAME_TRANSFORM_CONTRACT_SCHEMA_VERSION,
        source_band_gauge,
        target_band_gauge,
        transform_sha256,
        source_identity_sha256,
        metric_sha256,
        metric_kind,
        repr(physical_isometry_maximum),
        repr(physical_isometry_tolerance),
        repr(replay_maximum),
        repr(replay_tolerance),
        repr(euclidean_nonunitarity_maximum),
        repr(minimum_singular_value),
        repr(maximum_condition_number),
        "PASS",
    )
        write(buffer, value, '\0')
    end
    return bytes2hex(SHA.sha256(take!(buffer)))
end

"""Convert a qualified frame contract to its digest-bound string metadata."""
function band_frame_contract_metadata(contract::BandFrameTransformContract)
    return Dict(
        "band_frame_contract_schema" => contract.schema,
        "band_frame_contract_schema_version" => contract.schema_version,
        "band_frame_contract_status" => contract.status,
        "band_frame_source_gauge" => contract.source_band_gauge,
        "band_frame_target_gauge" => contract.target_band_gauge,
        "band_frame_transform_sha256" => contract.transform_sha256,
        "band_frame_contract_sha256" => contract.contract_sha256,
        "band_frame_metric_kind" => contract.metric_kind,
        "band_frame_physical_isometry_maximum" => repr(contract.physical_isometry_maximum),
        "band_frame_physical_isometry_tolerance" => repr(contract.physical_isometry_tolerance),
        "band_frame_replay_maximum" => repr(contract.replay_maximum),
        "band_frame_replay_tolerance" => repr(contract.replay_tolerance),
        "band_frame_euclidean_nonunitarity_maximum" =>
            repr(contract.euclidean_nonunitarity_maximum),
        "band_frame_minimum_singular_value" => repr(contract.minimum_singular_value),
        "band_frame_maximum_condition_number" => repr(contract.maximum_condition_number),
    )
end

"""Return a JSON/HDF5-compatible frame-contract summary."""
function band_frame_contract_summary(contract::BandFrameTransformContract)
    return (
        schema = contract.schema,
        schema_version = contract.schema_version,
        status = contract.status,
        legacy = contract.legacy,
        source_band_gauge = contract.source_band_gauge,
        target_band_gauge = contract.target_band_gauge,
        transform_sha256 = contract.transform_sha256,
        contract_sha256 = contract.contract_sha256,
        gauge_artifact_sha256 = something(contract.gauge_artifact_sha256, "NOT_APPLICABLE"),
        metric_kind = contract.metric_kind,
        physical_isometry_maximum = contract.physical_isometry_maximum,
        physical_isometry_tolerance = contract.physical_isometry_tolerance,
        replay_maximum = contract.replay_maximum,
        replay_tolerance = contract.replay_tolerance,
        euclidean_nonunitarity_maximum = contract.euclidean_nonunitarity_maximum,
        minimum_singular_value = contract.minimum_singular_value,
        maximum_condition_number = contract.maximum_condition_number,
    )
end

"""Write a frame-contract summary as HDF5 attributes."""
function write_band_frame_contract_attributes!(group, contract::BandFrameTransformContract)
    attributes = HDF5.attributes(group)
    for (key, value) in pairs(band_frame_contract_summary(contract))
        attributes[String(key)] = value
    end
    return group
end
