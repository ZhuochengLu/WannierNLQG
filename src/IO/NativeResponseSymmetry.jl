const NATIVE_RESPONSE_SYMMETRY_SCHEMA = "wanniernlqg.point-orbital-response-symmetry/2.0"

"""Owned declared operations and observed files; model equality requires actual bytes."""
struct NativeResponseSymmetryArtifact
    source_path::String
    source_state::NamedTuple
    definition_path::String
    definition_state::NamedTuple
    operations::Vector{PointOrbitalSymmetryOperation}
    definition_version::Int
end

# Existing five-argument construction describes the historical definition encoding.
NativeResponseSymmetryArtifact(
    source_path,
    source_state,
    definition_path,
    definition_state,
    operations,
) = NativeResponseSymmetryArtifact(
    source_path,
    source_state,
    definition_path,
    definition_state,
    operations,
    1,
)

"""Persist complete model data separately from bounded JSON operation metadata.

Every publication owns a fresh definition file. Replacing a declaration retains
older definitions and failed writes; no content-addressed name or hash is used.
The adjacent definition is data only and is never evaluated or deserialized.
"""
function write_native_symmetry_artifact(path, input, operations)
    absolute = abspath(path)
    records = [
        Dict(
            "rotation_fractional" => [collect(row) for row in eachrow(op.rotation_fractional)],
            "translation_fractional" => op.translation_fractional,
            "antiunitary" => op.antiunitary,
            "representation_real" =>
                [collect(row) for row in eachrow(real.(op.representation))],
            "representation_imag" =>
                [collect(row) for row in eachrow(imag.(op.representation))],
        ) for op in operations
    ]
    definition_path, stream = mktemp(dirname(absolute); cleanup = false)
    try
        write_native_model_definition(stream, input)
    finally
        close(stream)
    end
    state = scientific_file_state(definition_path)
    payload = Dict(
        "schema" => NATIVE_RESPONSE_SYMMETRY_SCHEMA,
        "model_definition" => Dict(
            "schema" => "wanniernlqg.native-model-definition/2",
            "file" => basename(definition_path),
            "bytes" => state.bytes,
        ),
        "basis" => "fixed_orthogonal_point_orbitals",
        "operations" => records,
        "qualification" =>
            Dict("grid_covariance" => "NOT_EVALUATED", "production_eligible" => false),
    )
    json3 = Base.require(RESPONSE_SYMMETRY_JSON3_PKG_ID)
    encoded = Base.invokelatest(getproperty(json3, :write), payload)
    open(absolute, "w") do output
        write(output, encoded)
    end
    isequal(scientific_file_state(definition_path), state) ||
        throw(ArgumentError("NATIVE_SYMMETRY_DEFINITION_CHANGED_DURING_PUBLICATION"))
    return String(path)
end

"""Read one local declaration; old checksum schemas require their archived reader."""
function read_native_response_symmetry(path)
    observed = read_scientific_source(path)
    payload = _response_symmetry_json_read(String(observed.bytes))
    payload["schema"] == NATIVE_RESPONSE_SYMMETRY_SCHEMA ||
        throw(ArgumentError("NATIVE_SYMMETRY_LEGACY_OR_UNKNOWN_SCHEMA_UNSUPPORTED"))
    Set(keys(payload)) ==
    Set(["schema", "model_definition", "basis", "operations", "qualification"]) ||
        throw(ArgumentError("native symmetry fields do not match schema"))
    payload["basis"] == "fixed_orthogonal_point_orbitals" ||
        throw(ArgumentError("invalid symmetry basis"))
    definition = payload["model_definition"]
    Set(keys(definition)) == Set(["schema", "file", "bytes"]) && definition["schema"] in
    ("wanniernlqg.native-model-definition/1", "wanniernlqg.native-model-definition/2") ||
        throw(ArgumentError("native complete definition schema required"))
    filename = definition["file"]
    filename isa AbstractString &&
    !isempty(filename) &&
    basename(filename) == filename &&
    !(filename in (".", "..")) &&
    !occursin('\\', filename) ||
        throw(ArgumentError("native definition must be an adjacent regular file"))
    definition_path = joinpath(dirname(observed.state.path), filename)
    state = scientific_file_state(definition_path)
    definition["bytes"] isa Integer &&
    !(definition["bytes"] isa Bool) &&
    definition["bytes"] == state.bytes > 0 ||
        throw(ArgumentError("NATIVE_SYMMETRY_DEFINITION_LENGTH_MISMATCH"))
    definition_version = definition["schema"] == "wanniernlqg.native-model-definition/1" ? 1 : 2
    prefixes =
        definition_version == 1 ?
        (
            "wanniernlqg-native-model-v2\n",
            "wanniernlqg-nonorthogonal-localized-effective-spin-convention-v3\n",
        ) :
        (
            "wanniernlqg-native-model-v3-stable-types\n",
            "wanniernlqg-native-axis-aligned-lowD-v1\n",
            "wanniernlqg-nonorthogonal-localized-effective-spin-convention-v4-stable-types\n",
        )
    header = open(io -> read(io, min(state.bytes, 128)), definition_path)
    any(
        prefix ->
            length(header) >= ncodeunits(prefix) &&
            header[1:ncodeunits(prefix)] == codeunits(prefix),
        prefixes,
    ) || throw(
        ArgumentError(
            "NATIVE_SYMMETRY_DEFINITION_ENCODING_HEADER_MISMATCH: do not relabel legacy definitions",
        ),
    )
    matrix(rows) = reduce(vcat, permutedims.(rows))
    operations = PointOrbitalSymmetryOperation[
        PointOrbitalSymmetryOperation(
            rotation_fractional = matrix(row["rotation_fractional"]),
            translation_fractional = row["translation_fractional"],
            antiunitary = row["antiunitary"],
            representation = complex.(
                matrix(row["representation_real"]),
                matrix(row["representation_imag"]),
            ),
        ) for row in payload["operations"]
    ]
    isempty(operations) && throw(ArgumentError("empty symmetry group"))
    artifact = NativeResponseSymmetryArtifact(
        observed.state.path,
        observed.state,
        definition_path,
        state,
        operations,
        definition_version,
    )
    validate_native_response_symmetry_source(artifact)
    return artifact
end

"""Reject file replacement or modification after the operation declaration was adopted."""
function validate_native_response_symmetry_source(artifact::NativeResponseSymmetryArtifact)
    isequal(scientific_file_state(artifact.source_path), artifact.source_state) &&
    isequal(scientific_file_state(artifact.definition_path), artifact.definition_state) ||
        throw(ArgumentError("NATIVE_SYMMETRY_SOURCE_CHANGED_AFTER_ADOPTION"))
    return nothing
end

"""Compare complete declared and adopted model definitions in bounded sequential chunks.

The original source state and live model owner are checked before and after.
A file observation is a lifetime condition, never the equality oracle.
"""
function validate_native_response_symmetry_model(
    artifact::NativeResponseSymmetryArtifact,
    input::AbstractNativeModelInput,
)
    validate_native_response_symmetry_source(artifact)
    generation = scientific_data_generation(input)
    definition =
        native_model_definition_stream(input; definition_version = artifact.definition_version)
    success = false
    try
        definition.byte_count == artifact.definition_state.bytes ||
            throw(_native_symmetry_definition_mismatch(artifact, "length"))
        open(artifact.definition_path, "r") do reference
            remaining = definition.byte_count
            while remaining > 0
                count = min(65536, remaining)
                actual = read(definition, count)
                expected = read(reference, count)
                length(actual) == length(expected) == count && actual == expected ||
                    throw(_native_symmetry_definition_mismatch(artifact, "bytes"))
                remaining -= count
            end
            eof(reference) && eof(definition) ||
                throw(_native_symmetry_definition_mismatch(artifact, "trailing data"))
        end
        scientific_data_generation(input) == generation ||
            throw(ArgumentError("NATIVE_SYMMETRY_MODEL_OWNER_CHANGED"))
        validate_native_response_symmetry_source(artifact)
        success = true
    finally
        close(definition; retain = !success)
    end
    return nothing
end

# Legacy bytes are never normalized or relabeled. A mismatch remains a rejection.
function _native_symmetry_definition_mismatch(artifact, part)
    message = "NATIVE_SYMMETRY_MODEL_DEFINITION_MISMATCH: " * part
    artifact.definition_version == 1 && (
        message *= "; legacy encoding or model data differs; explicitly republish from the authoritative model and operations, never relabel the file"
    )
    return ArgumentError(message)
end
