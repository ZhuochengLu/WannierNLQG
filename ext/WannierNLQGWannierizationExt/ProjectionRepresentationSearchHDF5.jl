const PROJECTION_REPRESENTATION_SEARCH_SCHEMA = "WannierNLQG.projection_representation_search"
const PROJECTION_REPRESENTATION_SEARCH_SCHEMA_VERSION = "4.0"
const _PROJECTION_REPRESENTATION_SEARCH_MIRROR_SCHEMA = "WannierNLQG.projection_search_hdf5_mirror/3.0"

# Encode one dense array without depending on JSON's multidimensional layout.
_projection_json_array(values) =
    (dimensions = Int.(collect(size(values))), values = vec(collect(values)))

# Encode one projection declaration in canonical field order.
function _projection_spec_payload(spec::ProjectionSpec)
    return (
        selector = spec.selector,
        orbital_sets = copy(spec.orbital_sets),
        positions_fractional = _projection_json_array(something(spec.positions_fractional)),
        local_bases = _projection_json_array(spec.local_bases),
    )
end

# Encode one explicit candidate in canonical field order.
function _projection_candidate_payload(candidate::ProjectionCandidateSpec)
    return (
        id = candidate.id,
        min_multiplicity = candidate.min_multiplicity,
        max_multiplicity = candidate.max_multiplicity,
        fixed_multiplicity = something(candidate.fixed_multiplicity, -1),
        specs = [_projection_spec_payload(spec) for spec in candidate.specs],
    )
end

# Encode the physical character-reduction algorithm profile in canonical field order.
function _projection_character_reduction_payload(info::ProjectionRepresentationAlgorithmInfo)
    return (
        algorithm_name = info.algorithm_name,
        algorithm_version = info.algorithm_version,
        algorithm_contract_sha256 = info.algorithm_contract_sha256,
        implementation_sha256 = info.implementation_sha256,
        canonical_reduction_eligible = info.canonical_reduction_eligible,
        scope = String(info.scope),
        character_tolerance = info.character_tolerance,
        character_round_digits = info.character_round_digits,
        little_group_tolerance = info.little_group_tolerance,
    )
end

# Encode one IBZ signature in canonical field order.
function _projection_signature_payload(signature::ProjectionRepresentationSignature)
    return (
        kpoint_index = signature.kpoint_index,
        labels = copy(signature.labels),
        dimensions = copy(signature.dimensions),
        wigner_types = String.(signature.wigner_types),
        frozen_lower = copy(signature.frozen_lower),
        outer_upper = copy(signature.outer_upper),
    )
end

# Encode one retained solution without relying on dictionary iteration order.
function _projection_solution_payload(solution::ProjectionRepresentationSolution)
    residual_names = sort!(collect(keys(solution.embedding_residuals)))
    return (
        candidate_ids = copy(solution.candidate_ids),
        coefficients = copy(solution.coefficients),
        total_dimension = solution.total_dimension,
        nonzero_candidate_types = solution.nonzero_candidate_types,
        total_block_multiplicity = solution.total_block_multiplicity,
        signature_multiplicities = copy.(solution.signature_multiplicities),
        validation_status = String(Symbol(solution.validation_status)),
        embedding_residuals = [
            (name = name, value = solution.embedding_residuals[name]) for name in residual_names
        ],
    )
end

# Build the path-independent logical payload shared by JSON and HDF5.
function _projection_search_payload(result::ProjectionRepresentationSearchResult)
    return (
        status = String(Symbol(result.status)),
        complete = result.complete,
        representation_definition = result.representation_definition,
        contract_definition = result.contract_definition,
        algorithm = _projection_character_reduction_payload(result.algorithm_info),
        spinor = result.spinor,
        num_wannier = result.num_wannier,
        outer_mask_definition = result.outer_mask_definition,
        frozen_mask_definition = result.frozen_mask_definition,
        candidates = [_projection_candidate_payload(candidate) for candidate in result.candidates],
        radial_transform = (
            method = String(result.radial_transform.method),
            gauss_laguerre_order = result.radial_transform.gauss_laguerre_order,
        ),
        visited_nodes = result.visited_nodes,
        total_solution_count = result.total_solution_count,
        truncated = result.truncated,
        signatures = [_projection_signature_payload(value) for value in result.signatures],
        solutions = [_projection_solution_payload(value) for value in result.solutions],
        diagnostics = copy(result.diagnostics),
    )
end

# Serialize the canonical logical payload with deterministic object field order.
_projection_search_payload_json(result) = String(JSON3.write(_projection_search_payload(result)))

# Write the algorithm profile into a canonical typed mirror definition.
function _projection_search_write_algorithm(io, info)
    for value in (
        info.algorithm_name,
        info.algorithm_version,
        info.algorithm_contract_sha256,
        info.implementation_sha256,
    )
        _projection_search_write_string(io, value)
    end
    write(io, UInt8(info.canonical_reduction_eligible))
    _projection_search_write_string(io, info.scope)
    write(
        io,
        Float64(info.character_tolerance),
        Int64(info.character_round_digits),
        Float64(info.little_group_tolerance),
    )
    return nothing
end

# Write one solution's validation fields into a canonical typed mirror definition.
function _projection_search_write_validation(io, solution)
    _projection_search_write_string(io, Symbol(solution.validation_status))
    residual_names = sort!(collect(keys(solution.embedding_residuals)))
    write(io, Int64(length(residual_names)))
    for name in residual_names
        _projection_search_write_string(io, name)
        write(io, Float64(solution.embedding_residuals[name]))
    end
    return nothing
end

# Bind the redundant typed HDF5 views to compare actual values with the JSON capsule.
function _projection_search_mirror_definition(result::ProjectionRepresentationSearchResult)
    io = IOBuffer()
    _projection_search_write_string(io, _PROJECTION_REPRESENTATION_SEARCH_MIRROR_SCHEMA)
    _projection_search_write_algorithm(io, result.algorithm_info)
    write(io, Int64(length(result.signatures)))
    for signature in result.signatures
        write(io, Int64(signature.kpoint_index))
        write(io, Int64(length(signature.labels)))
        foreach(value -> _projection_search_write_string(io, value), signature.labels)
        write(io, Int64(length(signature.wigner_types)))
        foreach(value -> _projection_search_write_string(io, value), signature.wigner_types)
        _projection_search_write_array(io, signature.dimensions)
        _projection_search_write_array(io, signature.frozen_lower)
        _projection_search_write_array(io, signature.outer_upper)
    end
    write(io, Int64(length(result.solutions)))
    for solution in result.solutions
        _projection_search_write_array(io, solution.coefficients)
        write(io, Int64(length(solution.signature_multiplicities)))
        foreach(
            values -> _projection_search_write_array(io, values),
            solution.signature_multiplicities,
        )
        _projection_search_write_validation(io, solution)
    end
    return take!(io)
end

# Write the physical character-reduction algorithm profile as a typed HDF5 view.
function _write_projection_search_algorithm(handle, info)
    group = HDF5.create_group(handle, "algorithm")
    attributes = HDF5.attributes(group)
    attributes["algorithm_name"] = info.algorithm_name
    attributes["algorithm_version"] = info.algorithm_version
    attributes["algorithm_contract_sha256"] = info.algorithm_contract_sha256
    attributes["implementation_sha256"] = info.implementation_sha256
    attributes["canonical_reduction_eligible"] = info.canonical_reduction_eligible
    attributes["scope"] = String(info.scope)
    attributes["character_tolerance"] = info.character_tolerance
    attributes["character_round_digits"] = info.character_round_digits
    attributes["little_group_tolerance"] = info.little_group_tolerance
    return nothing
end

# Write redundant typed HDF5 views for direct scientific inspection.
function _write_projection_search_mirror(handle, result)
    _write_projection_search_algorithm(handle, result.algorithm_info)
    signature_group = HDF5.create_group(handle, "signatures")
    for (index, signature) in enumerate(result.signatures)
        group = HDF5.create_group(signature_group, lpad(string(index), 6, '0'))
        HDF5.attributes(group)["kpoint_index"] = signature.kpoint_index
        group["dimensions"] = signature.dimensions
        group["frozen_lower"] = signature.frozen_lower
        group["outer_upper"] = signature.outer_upper
        HDF5.attributes(group)["labels_json"] = String(JSON3.write(signature.labels))
        HDF5.attributes(group)["wigner_types_json"] =
            String(JSON3.write(String.(signature.wigner_types)))
    end
    solution_group = HDF5.create_group(handle, "solutions")
    for (index, solution) in enumerate(result.solutions)
        group = HDF5.create_group(solution_group, lpad(string(index), 6, '0'))
        group["coefficients"] = solution.coefficients
        attributes = HDF5.attributes(group)
        attributes["validation_status"] = String(Symbol(solution.validation_status))
        signature_values = HDF5.create_group(group, "signature_multiplicities")
        for (signature_index, values) in enumerate(solution.signature_multiplicities)
            signature_values[lpad(string(signature_index), 6, '0')] = values
        end
        residual_names = sort!(collect(keys(solution.embedding_residuals)))
        attributes["embedding_residual_names_json"] = String(JSON3.write(residual_names))
        group["embedding_residual_values"] =
            Float64[solution.embedding_residuals[name] for name in residual_names]
    end
    return nothing
end

# Read the algorithm profile from the typed HDF5 view.
function _projection_search_read_algorithm(handle)
    attributes = HDF5.attributes(handle["algorithm"])
    return ProjectionRepresentationAlgorithmInfo(
        String(read(attributes["algorithm_name"])),
        String(read(attributes["algorithm_version"])),
        String(read(attributes["algorithm_contract_sha256"])),
        String(read(attributes["implementation_sha256"])),
        Bool(read(attributes["canonical_reduction_eligible"])),
        Symbol(String(read(attributes["scope"]))),
        Float64(read(attributes["character_tolerance"])),
        Int(read(attributes["character_round_digits"])),
        Float64(read(attributes["little_group_tolerance"])),
    )
end

# Recompute the redundant-view definition from an open HDF5 artifact.
function _projection_search_mirror_definition(handle)
    io = IOBuffer()
    _projection_search_write_string(io, _PROJECTION_REPRESENTATION_SEARCH_MIRROR_SCHEMA)
    _projection_search_write_algorithm(io, _projection_search_read_algorithm(handle))
    signatures = handle["signatures"]
    signature_names = sort!(String.(collect(keys(signatures))))
    write(io, Int64(length(signature_names)))
    for name in signature_names
        group = signatures[name]
        write(io, Int64(read(HDF5.attributes(group)["kpoint_index"])))
        labels = String.(collect(JSON3.read(String(read(HDF5.attributes(group)["labels_json"])))))
        write(io, Int64(length(labels)))
        foreach(value -> _projection_search_write_string(io, value), labels)
        wigner_types =
            String.(collect(JSON3.read(String(read(HDF5.attributes(group)["wigner_types_json"])))))
        write(io, Int64(length(wigner_types)))
        foreach(value -> _projection_search_write_string(io, value), wigner_types)
        _projection_search_write_array(io, Int.(read(group["dimensions"])))
        _projection_search_write_array(io, Int.(read(group["frozen_lower"])))
        _projection_search_write_array(io, Int.(read(group["outer_upper"])))
    end
    solutions = handle["solutions"]
    solution_names = sort!(String.(collect(keys(solutions))))
    write(io, Int64(length(solution_names)))
    for name in solution_names
        group = solutions[name]
        _projection_search_write_array(io, Int.(read(group["coefficients"])))
        signature_values = group["signature_multiplicities"]
        signature_names = sort!(String.(collect(keys(signature_values))))
        write(io, Int64(length(signature_names)))
        for signature_name in signature_names
            _projection_search_write_array(io, Int.(read(signature_values[signature_name])))
        end
        attributes = HDF5.attributes(group)
        _projection_search_write_string(io, String(read(attributes["validation_status"])))
        residual_names =
            String.(collect(JSON3.read(String(read(attributes["embedding_residual_names_json"])))))
        residual_values = Float64.(read(group["embedding_residual_values"]))
        length(residual_names) == length(residual_values) ||
            throw(ArgumentError("typed validation residual names and values disagree"))
        write(io, Int64(length(residual_names)))
        for (residual_name, residual_value) in zip(residual_names, residual_values)
            _projection_search_write_string(io, residual_name)
            write(io, residual_value)
        end
    end
    return take!(io)
end

# Verify that persisted algorithm metadata is the declared algorithm profile.
function _validate_projection_search_algorithm(result)
    info = result.algorithm_info
    fixed_fields_match =
        info.algorithm_name == PROJECTION_REDUCTION_ALGORITHM_NAME &&
        info.algorithm_version == PROJECTION_REDUCTION_ALGORITHM_VERSION &&
        info.algorithm_contract_sha256 == PROJECTION_REDUCTION_CONTRACT_SHA256 &&
        info.implementation_sha256 == PROJECTION_REDUCTION_IMPLEMENTATION_SHA256 &&
        info.character_tolerance == PROJECTION_REDUCTION_CHARACTER_TOLERANCE &&
        info.character_round_digits == PROJECTION_REDUCTION_CHARACTER_ROUND_DIGITS &&
        info.little_group_tolerance == PROJECTION_REDUCTION_LITTLE_GROUP_TOLERANCE
    fixed_fields_match ||
        throw(ArgumentError("projection search algorithm profile is not the pinned profile"))
    info.canonical_reduction_eligible == (info.scope == :spinless_unitary) ||
        throw(ArgumentError("projection search algorithm scope is inconsistent"))
    result.spinor &&
        info.canonical_reduction_eligible &&
        throw(ArgumentError("a spinor result cannot claim spinless-unitary parity"))
    return nothing
end

# Verify cross-field invariants that a valid digest alone does not express.
function _validate_projection_search_result(result)
    _validate_projection_search_algorithm(result)
    result.visited_nodes >= 0 || throw(ArgumentError("visited_nodes must be nonnegative"))
    result.total_solution_count >= length(result.solutions) ||
        throw(ArgumentError("total solution count is smaller than retained solutions"))
    result.truncated == (result.total_solution_count > length(result.solutions)) ||
        throw(ArgumentError("projection search truncation flag is inconsistent"))
    result.complete ==
    (result.status in (PROJECTION_SEARCH_COMPLETE, PROJECTION_SEARCH_NO_SOLUTION)) ||
        throw(ArgumentError("projection search status and completeness disagree"))
    if result.status == PROJECTION_SEARCH_COMPLETE
        !isempty(result.solutions) ||
            throw(ArgumentError("complete projection search must retain at least one solution"))
    elseif result.status == PROJECTION_SEARCH_NO_SOLUTION
        result.total_solution_count == 0 && isempty(result.solutions) ||
            throw(ArgumentError("no-solution projection search contains solutions"))
    end
    candidate_ids = getfield.(result.candidates, :id)
    candidate_dimensions = Int[
        build_wannier_projection_basis(
            candidate.specs;
            spinor = result.spinor,
            radial_transform = result.radial_transform,
        ).num_wannier for candidate in result.candidates
    ]
    all(solution -> solution.candidate_ids == candidate_ids, result.solutions) ||
        throw(ArgumentError("persisted solution candidate inventory mismatch"))
    all(
        solution ->
            length(solution.coefficients) == length(candidate_ids) &&
            all(>=(0), solution.coefficients),
        result.solutions,
    ) || throw(ArgumentError("persisted solution coefficient inventory is invalid"))
    for solution in result.solutions
        solution.total_dimension ==
        dot(candidate_dimensions, solution.coefficients) ==
        result.num_wannier ||
            throw(ArgumentError("persisted solution dimension disagrees with its coefficients"))
        solution.nonzero_candidate_types == count(!iszero, solution.coefficients) ||
            throw(ArgumentError("persisted solution nonzero candidate count is inconsistent"))
        solution.total_block_multiplicity == sum(solution.coefficients) ||
            throw(ArgumentError("persisted solution block multiplicity is inconsistent"))
        length(solution.signature_multiplicities) == length(result.signatures) ||
            throw(ArgumentError("persisted solution signature inventory is inconsistent"))
        all(
            length(values) == length(signature.labels) && all(>=(0), values) for
            (values, signature) in zip(solution.signature_multiplicities, result.signatures)
        ) || throw(ArgumentError("persisted solution signature multiplicities are invalid"))
        all(value -> isfinite(value) && value >= 0.0, values(solution.embedding_residuals)) ||
            throw(ArgumentError("persisted solution validation residuals are invalid"))
    end
    return result
end

"""Atomically persist one complete canonical search result in wire format 3.0."""
function write_projection_representation_search_hdf5(
    filename::AbstractString,
    result::ProjectionRepresentationSearchResult,
)
    _validate_projection_search_result(result)
    canonical_json = _projection_search_payload_json(result)
    return atomic_hdf5_write(filename) do temporary
        HDF5.h5open(temporary, "w") do handle
            attributes = HDF5.attributes(handle)
            attributes["schema"] = PROJECTION_REPRESENTATION_SEARCH_SCHEMA
            attributes["schema_version"] = PROJECTION_REPRESENTATION_SEARCH_SCHEMA_VERSION
            attributes["content_authentication"] = "NOT_PERFORMED"
            handle["canonical_payload_json"] = canonical_json
            _write_projection_search_mirror(handle, result)
        end
    end
end

# Decode a flattened JSON dense-array record.
function _projection_decode_json_array(record, ::Type{T}) where {T}
    dimensions = Tuple(Int.(collect(record.dimensions)))
    values = T.(collect(record.values))
    prod(dimensions) == length(values) ||
        throw(ArgumentError("canonical JSON dense-array dimensions disagree"))
    return reshape(values, dimensions)
end

# Decode one canonical projection candidate.
function _projection_decode_candidate(record)
    specs = ProjectionSpec[]
    for spec_record in record.specs
        positions = _projection_decode_json_array(spec_record.positions_fractional, Float64)
        local_bases = _projection_decode_json_array(spec_record.local_bases, Float64)
        push!(
            specs,
            ProjectionSpec(
                selector = String(spec_record.selector),
                orbital_sets = String.(collect(spec_record.orbital_sets)),
                positions = positions,
                local_bases = local_bases,
            ),
        )
    end
    fixed = Int(record.fixed_multiplicity)
    return ProjectionCandidateSpec(
        id = String(record.id),
        specs = specs,
        min_multiplicity = Int(record.min_multiplicity),
        max_multiplicity = Int(record.max_multiplicity),
        fixed_multiplicity = fixed < 0 ? nothing : fixed,
    )
end

# Decode the physical character-reduction algorithm profile.
function _projection_decode_algorithm(record)
    return ProjectionRepresentationAlgorithmInfo(
        String(record.algorithm_name),
        String(record.algorithm_version),
        String(record.algorithm_contract_sha256),
        String(record.implementation_sha256),
        Bool(record.canonical_reduction_eligible),
        Symbol(String(record.scope)),
        Float64(record.character_tolerance),
        Int(record.character_round_digits),
        Float64(record.little_group_tolerance),
    )
end

# Decode one canonical IBZ signature.
function _projection_decode_signature(record)
    return ProjectionRepresentationSignature(
        Int(record.kpoint_index),
        String.(collect(record.labels)),
        Int.(collect(record.dimensions)),
        Symbol.(String.(collect(record.wigner_types))),
        Int.(collect(record.frozen_lower)),
        Int.(collect(record.outer_upper)),
    )
end

# Convert one validation label back into the closed enum.
function _projection_decode_validation_status(value)
    label = String(value)
    mapping = Dict(
        "PROJECTION_VALIDATION_NOT_RUN" => PROJECTION_VALIDATION_NOT_RUN,
        "PROJECTION_VALIDATION_PASSED" => PROJECTION_VALIDATION_PASSED,
        "PROJECTION_VALIDATION_FAILED" => PROJECTION_VALIDATION_FAILED,
        "PROJECTION_VALIDATION_NUMERICAL_UNCERTAIN" =>
            PROJECTION_VALIDATION_NUMERICAL_UNCERTAIN,
    )
    haskey(mapping, label) || throw(ArgumentError("unknown projection validation status $(label)"))
    return mapping[label]
end

# Decode one canonical retained solution.
function _projection_decode_solution(record)
    residuals = Dict{String, Float64}(
        String(entry.name) => Float64(entry.value) for entry in record.embedding_residuals
    )
    return ProjectionRepresentationSolution(
        String.(collect(record.candidate_ids)),
        Int.(collect(record.coefficients)),
        Int(record.total_dimension),
        Int(record.nonzero_candidate_types),
        Int(record.total_block_multiplicity),
        [Int.(collect(values)) for values in record.signature_multiplicities],
        _projection_decode_validation_status(record.validation_status),
        residuals,
    )
end

# Convert one search label back into the closed enum.
function _projection_decode_status(value)
    label = String(value)
    mapping = Dict(
        "PROJECTION_SEARCH_COMPLETE" => PROJECTION_SEARCH_COMPLETE,
        "PROJECTION_SEARCH_NO_SOLUTION" => PROJECTION_SEARCH_NO_SOLUTION,
        "PROJECTION_SEARCH_LIMIT_REACHED" => PROJECTION_SEARCH_LIMIT_REACHED,
        "PROJECTION_SEARCH_INVALID_INPUT" => PROJECTION_SEARCH_INVALID_INPUT,
        "PROJECTION_SEARCH_NUMERICAL_UNCERTAIN" => PROJECTION_SEARCH_NUMERICAL_UNCERTAIN,
    )
    haskey(mapping, label) || throw(ArgumentError("unknown projection search status $(label)"))
    return mapping[label]
end

# Reconstruct the typed result from one verified canonical JSON capsule.
function _projection_decode_result(payload)
    radial = ProjectionRadialTransformConfig(
        method = Symbol(String(payload.radial_transform.method)),
        gauss_laguerre_order = Int(payload.radial_transform.gauss_laguerre_order),
    )
    return ProjectionRepresentationSearchResult(
        _projection_decode_status(payload.status),
        Bool(payload.complete),
        String(payload.representation_definition),
        String(payload.contract_definition),
        _projection_decode_algorithm(payload.algorithm),
        Bool(payload.spinor),
        Int(payload.num_wannier),
        String(payload.outer_mask_definition),
        String(payload.frozen_mask_definition),
        [_projection_decode_candidate(value) for value in payload.candidates],
        radial,
        Int(payload.visited_nodes),
        Int(payload.total_solution_count),
        Bool(payload.truncated),
        [_projection_decode_signature(value) for value in payload.signatures],
        [_projection_decode_solution(value) for value in payload.solutions],
        String.(collect(payload.diagnostics)),
    )
end

"""Read and fully verify a complete canonical search artifact in wire format 3.0 (without content authentication)."""
function read_projection_representation_search_hdf5(filename::AbstractString)
    return HDF5.h5open(filename, "r") do handle
        attributes = HDF5.attributes(handle)
        schema = String(read(attributes["schema"]))
        version = String(read(attributes["schema_version"]))
        schema == PROJECTION_REPRESENTATION_SEARCH_SCHEMA || throw(
            ArgumentError(
                "projection search HDF5 schema is $(schema), expected $(PROJECTION_REPRESENTATION_SEARCH_SCHEMA)",
            ),
        )
        version == PROJECTION_REPRESENTATION_SEARCH_SCHEMA_VERSION || throw(
            ArgumentError(
                "unsupported projection search schema version: $(version); expected $(PROJECTION_REPRESENTATION_SEARCH_SCHEMA_VERSION)",
            ),
        )
        String(read(attributes["content_authentication"])) == "NOT_PERFORMED" ||
            throw(ArgumentError("unsupported projection search authentication contract"))
        canonical_json = String(read(handle["canonical_payload_json"]))
        payload = JSON3.read(canonical_json)
        result = _projection_decode_result(payload)
        _projection_search_payload_json(result) == canonical_json ||
            throw(ArgumentError("projection search canonical payload is not normalized"))
        # Compare actual redundant values; no checksum authenticates either view.
        _projection_search_mirror_definition(handle) ==
        _projection_search_mirror_definition(result) ||
            throw(ArgumentError("projection search HDF5 typed view differs from canonical values"))
        typed_algorithm = _projection_search_read_algorithm(handle)
        typed_algorithm == result.algorithm_info ||
            throw(ArgumentError("projection search typed algorithm view is inconsistent"))
        return _validate_projection_search_result(result)
    end
end

# Publish a deterministic, path-independent JSON summary by atomic replacement.
function _write_projection_representation_search_json(
    filename::AbstractString,
    result::ProjectionRepresentationSearchResult,
)
    _validate_projection_search_result(result)
    summary = (
        schema = PROJECTION_REPRESENTATION_SEARCH_SCHEMA,
        schema_version = PROJECTION_REPRESENTATION_SEARCH_SCHEMA_VERSION,
        content_authentication = "NOT_PERFORMED",
        result = _projection_search_payload(result),
    )
    content = String(JSON3.write(summary))
    path = abspath(filename)
    mkpath(dirname(path))
    temporary, io = mktemp(dirname(path); cleanup = false)
    completed = false
    try
        write(io, content)
        close(io)
        mv(temporary, path; force = true)
        completed = true
    finally
        isopen(io) && close(io)
        !completed && isfile(temporary) && rm(temporary; force = true)
    end
    return path
end
