
"""Serialize a response table without choosing physical prefactors or backgrounds.

Coordinates and explicitly labelled values are already normalized by the response
layer. Static tables do not acquire a synthetic optical axis.
"""
function write_spectral_response_table(
    path,
    coordinates,
    coordinate_labels,
    values,
    labels;
    units,
    digits = 14,
    headers = Pair{String, String}[],
)
    mkpath(dirname(path))
    open(path, "w") do stream
        for (key, value) in headers
            println(stream, "# ", key, "=", value)
        end
        println(stream, "# units=", units)
        println(
            stream,
            "# ",
            join(
                vcat(
                    coordinate_labels,
                    [label*suffix for label in labels for suffix in ("_real", "_imag")],
                ),
                " ",
            ),
        )
        format=Printf.Format("%."*string(digits)*"e")
        for row in axes(values, 1)
            numbers=collect(coordinates[row, :])
            for column in axes(values, 2)
                value=values[row, column]
                push!(numbers, real(value));
                push!(numbers, imag(value))
            end
            println(stream, join((Printf.format(format, x) for x in numbers), " "))
        end
    end
    return path
end

const _RELEASE_TREE_SHA256 = Ref{Union{Nothing, String}}(nothing)

"""Verify the release manifest and hash sorted `relative_path + NUL + file_bytes`."""
function release_tree_sha256()
    cached = _RELEASE_TREE_SHA256[]
    cached === nothing || return cached
    root = normpath(joinpath(@__DIR__, "..", ".."))
    manifest_path = joinpath(root, "SOURCE_MANIFEST.tsv")
    isfile(manifest_path) || error("RELEASE_SOURCE_MANIFEST_MISSING")
    rows = split(chomp(read(manifest_path, String)), '\n')
    !isempty(rows) && first(rows) == "type\tbytes\tsha256\tpath" ||
        error("RELEASE_SOURCE_MANIFEST_INVALID")
    entries = Tuple{String, Int, String}[]
    for row in rows[2:end]
        fields = split(row, '\t'; limit = 4)
        length(fields) == 4 && fields[1] == "file" || error("RELEASE_SOURCE_MANIFEST_INVALID")
        push!(entries, (fields[4], parse(Int, fields[2]), fields[3]))
    end
    paths = first.(entries)
    paths == sort(paths) && length(paths) == length(unique(paths)) ||
        error("RELEASE_SOURCE_MANIFEST_ORDER_INVALID")
    actual = String[]
    for (directory, directories, files) in walkdir(root)
        filter!(name -> name != ".git" && name != "__pycache__", directories)
        for file in files
            relative = replace(relpath(joinpath(directory, file), root), '\\' => '/')
            relative in ("SOURCE_MANIFEST.tsv", "SHA256SUMS") && continue
            (endswith(file, ".pyc") || endswith(file, ".pyo")) && continue
            push!(actual, relative)
        end
    end
    sort!(actual) == paths || error("RELEASE_SOURCE_MANIFEST_INVENTORY_MISMATCH")
    stream = IOBuffer()
    for (relative, bytes, digest) in entries
        path = joinpath(root, relative)
        isfile(path) || error("RELEASE_SOURCE_FILE_MISSING: $relative")
        data = read(path)
        length(data) == bytes || error("RELEASE_SOURCE_SIZE_MISMATCH: $relative")
        bytes2hex(sha256(data)) == digest || error("RELEASE_SOURCE_SHA256_MISMATCH: $relative")
        write(stream, relative, '\0', data)
    end
    value = bytes2hex(sha256(take!(stream)))
    _RELEASE_TREE_SHA256[] = value
    return value
end

"""Retain a normalized task's complete ordered header definition without hashing.

The representation is compared as data, never parsed as executable Julia. Model
and operator provenance fields retain their separate admission contracts.
"""
function spectral_task_definition(headers)
    entries = Tuple(Pair{String, String}(String(key), String(value)) for (key, value) in headers)
    return "wanniernlqg.spectral-task-definition/1:" * repr(entries)
end

# Decode the existing physical axis definition without evaluating code. The
# decimal coordinate column may be a lower-precision display of this exact axis.
function _recorded_vector_axis(definition, count)
    prefix = FERMI_ENERGY_AXIS_DOMAIN * ":eV:"
    startswith(definition, prefix) || error("VECTOR_RESPONSE_AXIS_DEFINITION_MISMATCH")
    fields = split(definition[(length(prefix) + 1):end], ':'; limit = 2)
    length(fields) == 2 && tryparse(Int, fields[1]) == count ||
        error("VECTOR_RESPONSE_AXIS_DEFINITION_MISMATCH")
    tokens = split(fields[2], ',')
    length(tokens) == count && all(occursin(r"^[0-9a-f]{16}$", token) for token in tokens) ||
        error("VECTOR_RESPONSE_AXIS_DEFINITION_MISMATCH")
    axis = validate_fermi_energies([
        reinterpret(Float64, parse(UInt64, token; base = 16)) for token in tokens
    ])
    fermi_energy_axis_definition(axis) == definition ||
        error("VECTOR_RESPONSE_AXIS_DEFINITION_MISMATCH")
    return axis
end

# Scientific notation never rounds a finite nonzero Float64 to displayed zero.
# This is the decimal representation's uncertainty, not a physical tolerance.
function _decimal_rounding_bound(token, value, digits)
    iszero(value) && return 0.0
    exponent = parse(Int, last(split(lowercase(token), 'e')))
    return 0.5 * 10.0^(exponent - digits)
end

"""Read one vector response term and validate its local table contract."""
function _read_vector_table(path, schema, quantity, term, labels, unit)
    isfile(path) || error("VECTOR_RESPONSE_FILE_MISSING: $(basename(path))")
    headers = Dict{String, String}()
    columns = String[]
    rows = Vector{Vector{Float64}}()
    lexemes = Vector{Vector{String}}()
    for line in eachline(path)
        stripped = strip(line)
        isempty(stripped) && continue
        if startswith(stripped, "# ")
            body = stripped[3:end]
            if occursin('=', body)
                key, value = split(body, '='; limit = 2)
                headers[key] = value
            elseif occursin("_real", body)
                columns = split(body)
            end
        elseif !startswith(stripped, "#")
            tokens = String.(split(stripped))
            push!(lexemes, tokens)
            push!(rows, parse.(Float64, tokens))
        end
    end
    get(headers, "schema", "") in (schema isa AbstractString ? (schema,) : schema) ||
        error("VECTOR_RESPONSE_SCHEMA_MISMATCH")
    get(headers, "quantity", "") == quantity || error("VECTOR_RESPONSE_QUANTITY_MISMATCH")
    get(headers, "term", "") == term || error("VECTOR_RESPONSE_TERM_MISMATCH")
    get(headers, "units", "") == unit || error("VECTOR_RESPONSE_UNIT_MISMATCH")
    expected_columns =
        vcat(["mu_eV"], [label * suffix for label in labels for suffix in ("_real", "_imag")])
    columns == expected_columns || error("VECTOR_RESPONSE_COLUMNS_MISMATCH")
    isempty(rows) && error("VECTOR_RESPONSE_EMPTY")
    all(length(row) == length(expected_columns) for row in rows) ||
        error("VECTOR_RESPONSE_SHAPE_MISMATCH")
    table = reduce(vcat, permutedims.(rows))
    all(isfinite, table) || error("VECTOR_RESPONSE_NONFINITE")
    serialized_axis = table[:, 1]
    bounds = zeros(Float64, size(table))
    validated = if haskey(headers, "response_output_digits")
        digits = tryparse(Int, headers["response_output_digits"])
        digits !== nothing && 7 <= digits <= 17 || error("VECTOR_RESPONSE_PRECISION_INVALID")
        format = Printf.Format("%." * string(digits) * "e")
        exact_axis =
            _recorded_vector_axis(get(headers, "fermi_energies_definition", ""), size(table, 1))
        for row in axes(table, 1), column in axes(table, 2)
            expected = column == 1 ? exact_axis[row] : table[row, column]
            Printf.format(format, expected) == lexemes[row][column] || error(
                column == 1 ? "VECTOR_RESPONSE_AXIS_DEFINITION_MISMATCH" :
                "VECTOR_RESPONSE_PRECISION_FORMAT_MISMATCH",
            )
            bounds[row, column] =
                _decimal_rounding_bound(lexemes[row][column], table[row, column], digits)
        end
        exact_axis
    else
        # Files without the new declaration retain the exact legacy checks.
        axis = validate_fermi_energies(Vector{Float64}(serialized_axis))
        get(headers, "fermi_energies_definition", "") == fermi_energy_axis_definition(axis) ||
            error("VECTOR_RESPONSE_AXIS_DEFINITION_MISMATCH")
        axis
    end
    values = zeros(ComplexF64, length(validated), length(labels))
    rounding_bounds = similar(values)
    for column in eachindex(labels)
        values[:, column] .= table[:, 2column] .+ im .* table[:, 2column + 1]
        rounding_bounds[:, column] .= bounds[:, 2column] .+ im .* bounds[:, 2column + 1]
    end
    return (; headers, axis = validated, serialized_axis, values, rounding_bounds)
end

"""Validate shared identity and execution metadata across vector response terms."""
function _validate_vector_result_common(results, directory)
    first_result = first(values(results))
    source_identity_key = "producer_package_version"
    common = (
        "schema",
        "method",
        "temperature_K",
        "fermi_energies_count",
        "fermi_energies_definition",
        "task_definition",
        source_identity_key,
        "model_identity",
        "input_identity",
        "gamma_intra_ev",
        "gamma_inter_ev",
        "fs_kind",
        "eta_fs_ev",
        "mpi_size",
        "julia_threads_per_rank",
        "qualification_status",
        "input_semantics",
        "operator_inventory",
        "operator_model_schema",
        "content_authentication",
    )
    has_groups = any(haskey(result.headers, "groups") for result in values(results))
    has_precision =
        any(haskey(result.headers, "response_output_digits") for result in values(results))
    has_precision && (common = (common..., "response_output_digits"))
    if has_groups
        get(first_result.headers, "quantity", "") in ("intrinsic_ahc", "orbital_magnetization") ||
            error("VECTOR_RESPONSE_GROUP_QUANTITY_UNSUPPORTED")
        groups = try
            TOML.parse("groups = " * get(first_result.headers, "groups", ""))["groups"]
        catch
            error("VECTOR_RESPONSE_GROUP_HEADER_INVALID")
        end
        groups isa AbstractVector && length(groups) == 1 && only(groups) isa AbstractVector ||
            error("VECTOR_RESPONSE_GROUP_HEADER_INVALID")
        group = only(groups)
        !isempty(group) &&
        all(i -> i isa Integer && !(i isa Bool) && i > 0, group) &&
        length(unique(group)) == length(group) || error("VECTOR_RESPONSE_GROUP_HEADER_INVALID")
        common = (common..., "groups")
    end
    for result in values(results)
        result.axis == first_result.axis || error("VECTOR_RESPONSE_AXIS_MISMATCH")
        for key in common
            get(result.headers, key, "") == get(first_result.headers, key, "") ||
                error("VECTOR_RESPONSE_IDENTITY_MISMATCH: $key")
        end
    end
    # Producer metadata is descriptive. Compare the actual file group's axis,
    # normalized task definition and decomposition without scanning this package.
    parse(Int, get(first_result.headers, "fermi_energies_count", "-1")) ==
    length(first_result.axis) || error("VECTOR_RESPONSE_AXIS_COUNT_MISMATCH")
    get(first_result.headers, "method", "") in ("conventional", "projector") ||
        error("VECTOR_RESPONSE_METHOD_INVALID")
    temperature = tryparse(Float64, get(first_result.headers, "temperature_K", ""))
    temperature !== nothing && isfinite(temperature) && temperature >= 0 ||
        error("VECTOR_RESPONSE_TEMPERATURE_INVALID")
    for key in ("mpi_size", "julia_threads_per_rank")
        value = tryparse(Int, get(first_result.headers, key, ""))
        value !== nothing && value > 0 || error("VECTOR_RESPONSE_EXECUTION_SHAPE_INVALID: $key")
    end
    for key in ("model_identity", "input_identity")
        identity = get(first_result.headers, key, "")
        # Descriptive source references may be paths or owned-data labels. They
        # are not proof of input equality and never trigger file-content scans.
        !isempty(strip(identity)) && !any(c -> c in ('\0', '\n', '\r'), identity) ||
            error("VECTOR_RESPONSE_SOURCE_REFERENCE_INVALID: $key")
    end
    get(first_result.headers, "content_authentication", "") == "NOT_PERFORMED" ||
        error("VECTOR_RESPONSE_CONTENT_AUTHENTICATION_INVALID")
    get(first_result.headers, "operator_model_schema", "") in
    (OPERATOR_BUNDLE_SCHEMA_VERSION, "NOT_APPLICABLE_DEFINED_FINITE_MODEL") ||
        error("VECTOR_RESPONSE_OPERATOR_MODEL_SCHEMA_INVALID")
    isempty(strip(get(first_result.headers, source_identity_key, ""))) &&
        error("VECTOR_RESPONSE_PRODUCER_VERSION_MISSING")
    # Runtime writes this identity in its semantic field order. Rebuild that order explicitly.
    ordered_keys = [
        "schema",
        "quantity",
        "method",
        "temperature_K",
        "fermi_energies_count",
        "fermi_energies_definition",
        source_identity_key,
        "model_identity",
        "input_identity",
        "gamma_intra_ev",
        "gamma_inter_ev",
        "fs_kind",
        "eta_fs_ev",
        "mpi_size",
        "julia_threads_per_rank",
        "qualification_status",
        "input_semantics",
        "operator_inventory",
        "operator_model_schema",
        "content_authentication",
    ]
    orbital_keys = (
        "orbital_geometry_prescription",
        "denominator_regularization_ev",
        "zero_temperature_boundary",
    )
    has_precision && push!(ordered_keys, "response_output_digits")
    has_groups && push!(ordered_keys, "groups")
    if any(haskey(result.headers, key) for result in values(results) for key in orbital_keys)
        get(first_result.headers, "quantity", "") == "orbital_magnetization" ||
            error("ORBITAL_RESPONSE_IDENTITY_WRONG_QUANTITY")
        all(haskey(first_result.headers, key) for key in orbital_keys) ||
            error("ORBITAL_RESPONSE_IDENTITY_FIELD_MISSING")
        for result in values(results), key in orbital_keys
            get(result.headers, key, "") == first_result.headers[key] ||
                error("VECTOR_RESPONSE_IDENTITY_MISMATCH: $key")
        end
        first_result.headers["orbital_geometry_prescription"] ==
        "complete-V-regularized-Sylvester/1" || error("ORBITAL_RESPONSE_PRESCRIPTION_INVALID")
        first_result.headers["zero_temperature_boundary"] ==
        "symmetric-complete-subspace-response-average" || error("ORBITAL_RESPONSE_BOUNDARY_INVALID")
        eta = tryparse(Float64, first_result.headers["denominator_regularization_ev"])
        eta !== nothing && isfinite(eta) && eta > 0 ||
            error("ORBITAL_RESPONSE_REGULARIZATION_INVALID")
        append!(ordered_keys, orbital_keys)
    end
    all(haskey(first_result.headers, key) for key in ordered_keys) ||
        error("VECTOR_RESPONSE_IDENTITY_FIELD_MISSING")
    expected_definition =
        spectral_task_definition([key => first_result.headers[key] for key in ordered_keys])
    expected_definition == get(first_result.headers, "task_definition", "") ||
        error("VECTOR_RESPONSE_TASK_DEFINITION_MISMATCH")
    metadata = joinpath(directory, "spectral_response_metadata.txt")
    isfile(metadata) || error("VECTOR_RESPONSE_METADATA_MISSING")
    fragments = [key * " = " * repr(get(first_result.headers, key, "")) for key in common]
    present = _spectral_metadata_contains_fragments(metadata, fragments)
    for (key, found) in zip(common, present)
        found || error("VECTOR_RESPONSE_METADATA_MISMATCH: $key")
    end
    return first_result
end

"""Check the same physical decomposition after accounting for declared decimal rounding only."""
function _serialized_decomposition_consistent(results, components; atol, rtol)
    total = results[:total].values
    reference = reduce(+, (results[term].values for term in components))
    all(haskey(result.headers, "response_output_digits") for result in values(results)) ||
        return isapprox(total, reference; atol, rtol)
    bounds =
        results[:total].rounding_bounds +
        reduce(+, (results[term].rounding_bounds for term in components))
    difference = total - reference
    excess = complex.(
        max.(abs.(real.(difference)) .- real.(bounds), 0.0),
        max.(abs.(imag.(difference)) .- imag.(bounds), 0.0),
    )
    return norm(excess) <= max(atol, rtol * max(norm(total), norm(reference)))
end

# Preserve exact substring validation while bounding memory by the requested
# scalar fragments and one input chunk. Large descriptive definitions stay in
# the original file; ordinary readback need not materialize their repr strings.
function _spectral_metadata_contains_fragments(path, fragments; chunk_bytes::Int = 65536)
    chunk_bytes > 0 || throw(ArgumentError("positive metadata chunk size required"))
    needles = String[fragment for fragment in fragments]
    found = BitVector(isempty.(needles))
    retained = max(0, maximum(ncodeunits, needles; init = 0) - 1)
    tail = UInt8[]
    open(path, "r") do stream
        while !all(found) && !eof(stream)
            bytes = vcat(tail, read(stream, chunk_bytes))
            text = String(copy(bytes))
            for index in eachindex(needles)
                found[index] || (found[index] = occursin(needles[index], text))
            end
            count = min(retained, length(bytes))
            tail = count == 0 ? UInt8[] : bytes[(end - count + 1):end]
        end
    end
    return found
end

# Require unique registered operator names containing all orbital-material inputs.
function _validate_orbital_material_inventory(inventory)
    length(unique(inventory)) == length(inventory) ||
        error("ORBITAL_MATERIAL_OPERATOR_INVENTORY_DUPLICATE")
    canonical = Set(real_space_operator_name.(REAL_SPACE_OPERATOR_REGISTRY))
    all(name -> name in canonical, inventory) ||
        error("ORBITAL_MATERIAL_OPERATOR_INVENTORY_UNKNOWN")
    required = Set((
        "hamiltonian",
        "position",
        "hamiltonian_weighted_connection",
        "derivative_overlap_tensor",
        "hamiltonian_weighted_axial_derivative_overlap",
    ))
    issubset(required, Set(inventory)) || error("ORBITAL_MATERIAL_FIVE_OPERATOR_INVENTORY_REQUIRED")
    return nothing
end

"""Strictly read and validate one vectorized Linear Transport result directory."""
function read_linear_transport_result(directory::AbstractString)
    terms = (:drude, :quantum_metric, :berry_curvature, :total)
    present = Set(
        filter(
            name -> startswith(name, "linear_transport_") && endswith(name, ".dat"),
            readdir(directory),
        ),
    )
    expected = Set("linear_transport_$(term).dat" for term in terms)
    present == expected || error("LINEAR_TRANSPORT_FILE_SET_MISMATCH")
    labels = [string(a, b) for a in "xyz" for b in "xyz"]
    results = Dict(
        term => _read_vector_table(
            joinpath(directory, "linear_transport_$(term).dat"),
            "wanniernlqg.linear-transport-vector/6.0",
            "linear_transport",
            string(term),
            labels,
            "S/m",
        ) for term in terms
    )
    first_result = _validate_vector_result_common(results, directory)
    tensors = Dict(term => zeros(ComplexF64, length(first_result.axis), 3, 3) for term in terms)
    for term in terms, a in 1:3, b in 1:3
        tensors[term][:, a, b] .= results[term].values[:, 3(a - 1) + b]
    end
    consistent =
        if all(haskey(result.headers, "response_output_digits") for result in values(results))
            _serialized_decomposition_consistent(
                results,
                (:drude, :quantum_metric, :berry_curvature);
                atol = 1e-8,
                rtol = 2e-12,
            )
        else
            isapprox(
                tensors[:total],
                tensors[:drude] + tensors[:quantum_metric] + tensors[:berry_curvature];
                atol = 1e-8,
                rtol = 2e-12,
            )
        end
    consistent || error("LINEAR_TRANSPORT_DECOMPOSITION_MISMATCH")
    return (; fermi_energies = first_result.axis, tensors, metadata = first_result.headers)
end

"""Strictly read and validate one vectorized Orbital Magnetization result directory."""
function read_orbital_magnetization_result(directory::AbstractString)
    terms = (:srocc, :cmocc, :total)
    labels = string.(collect("xyz"))
    results = Dict(
        term => _read_vector_table(
            joinpath(directory, "orbital_magnetization_$(term).dat"),
            "wanniernlqg.orbital-magnetization-vector/5.0",
            "orbital_magnetization",
            string(term),
            labels,
            "muB/cell",
        ) for term in terms
    )
    first_result = _validate_vector_result_common(results, directory)
    semantics = get(first_result.headers, "input_semantics", "")
    semantics in ("defined_finite_model", "projected_energy_overlap", "direct_energy_overlap") ||
        error("ORBITAL_INPUT_SEMANTICS_INVALID")
    inventory = split(get(first_result.headers, "operator_inventory", ""), ',')
    model_schema = get(first_result.headers, "operator_model_schema", "")
    if semantics == "defined_finite_model"
        inventory == ["NOT_APPLICABLE_DEFINED_FINITE_MODEL"] ||
            error("ORBITAL_FINITE_MODEL_INVENTORY_CONFLICT")
        model_schema == "NOT_APPLICABLE_DEFINED_FINITE_MODEL" ||
            error("ORBITAL_FINITE_MODEL_SCHEMA_CONFLICT")
    else
        _validate_orbital_material_inventory(inventory)
        # Input admission already validates actual operators and their mathematical
        # definitions. Result readback validates this recorded model schema and
        # inventory; it does not revive retired source/target certificates.
        model_schema == OPERATOR_BUNDLE_SCHEMA_VERSION ||
            error("ORBITAL_MATERIAL_MODEL_SCHEMA_REQUIRED")
    end
    vectors = Dict(term => results[term].values for term in terms)
    _serialized_decomposition_consistent(results, (:srocc, :cmocc); atol = 1e-20, rtol = 2e-12) ||
        error("ORBITAL_MAGNETIZATION_DECOMPOSITION_MISMATCH")
    return (; fermi_energies = first_result.axis, vectors, metadata = first_result.headers)
end

"""Write explicit scalar/list provenance supplied by Runtime, without deriving physical metadata."""
function write_spectral_response_metadata(path, entries)
    open(path, "w") do stream
        for (key, value) in pairs(entries)
            println(stream, key, " = ", repr(value))
        end
    end
    return path
end

"""Hash the loaded package source paths and bytes in a deterministic, path-independent order."""
function spectral_response_source_digest()
    root=normpath(joinpath(@__DIR__, "..", ".."))
    paths=String[]
    for directory in ("src", "ext"),
        (folder, _, files) in walkdir(joinpath(root, directory)),
        file in files

        endswith(file, ".jl") && push!(paths, relpath(joinpath(folder, file), root))
    end
    stream=IOBuffer()
    for relative in sort!(paths)
        write(stream, relative, '\0', bytes2hex(sha256(read(joinpath(root, relative)))), '\n')
    end
    return bytes2hex(sha256(take!(stream)))
end
