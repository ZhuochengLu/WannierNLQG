
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

"""Read one vector response term and validate its local table contract."""
function _read_vector_table(path, schema, quantity, term, labels, unit)
    isfile(path) || error("VECTOR_RESPONSE_FILE_MISSING: $(basename(path))")
    headers = Dict{String, String}()
    columns = String[]
    rows = Vector{Vector{Float64}}()
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
            push!(rows, parse.(Float64, split(stripped)))
        end
    end
    get(headers, "schema", "") == schema || error("VECTOR_RESPONSE_SCHEMA_MISMATCH")
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
    axis = table[:, 1]
    validated = validate_fermi_energies(Vector{Float64}(axis))
    get(headers, "fermi_energies_sha256", "") == fermi_energy_axis_sha256(validated) ||
        error("VECTOR_RESPONSE_AXIS_SHA256_MISMATCH")
    values = zeros(ComplexF64, length(axis), length(labels))
    for column in eachindex(labels)
        values[:, column] .= table[:, 2column] .+ im .* table[:, 2column + 1]
    end
    return (; headers, axis = validated, values)
end

"""Validate shared identity and execution metadata across vector response terms."""
function _validate_vector_result_common(results, directory)
    first_result = first(values(results))
    common = (
        "method",
        "temperature_K",
        "fermi_energies_count",
        "fermi_energies_sha256",
        "task_sha256",
        "release_tree_sha256",
        "model_sha256",
        "input_identity_sha256",
        "gamma_intra_ev",
        "gamma_inter_ev",
        "fs_kind",
        "eta_fs_ev",
        "mpi_size",
        "julia_threads_per_rank",
        "qualification_status",
        "input_semantics",
        "operator_inventory",
        "target_contract_sha256",
        "authoritative_hamiltonian_sha256",
        "band_frame_contract_sha256",
        "operator_selection_sha256",
    )
    for result in values(results)
        result.axis == first_result.axis || error("VECTOR_RESPONSE_AXIS_MISMATCH")
        for key in common
            get(result.headers, key, "") == get(first_result.headers, key, "") ||
                error("VECTOR_RESPONSE_IDENTITY_MISMATCH: $key")
        end
    end
    get(first_result.headers, "release_tree_sha256", "") == release_tree_sha256() ||
        error("VECTOR_RESPONSE_RELEASE_TREE_SHA256_MISMATCH")
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
    for key in (
        "fermi_energies_sha256",
        "task_sha256",
        "release_tree_sha256",
        "model_sha256",
        "input_identity_sha256",
    )
        occursin(r"^[0-9a-f]{64}$", get(first_result.headers, key, "")) ||
            error("VECTOR_RESPONSE_SHA256_INVALID: $key")
    end
    # Runtime writes this identity in its semantic field order. Rebuild that order explicitly.
    ordered_keys = [
        "schema",
        "quantity",
        "method",
        "temperature_K",
        "fermi_energies_count",
        "fermi_energies_sha256",
        "release_tree_sha256",
        "model_sha256",
        "input_identity_sha256",
        "gamma_intra_ev",
        "gamma_inter_ev",
        "fs_kind",
        "eta_fs_ev",
        "mpi_size",
        "julia_threads_per_rank",
        "qualification_status",
        "input_semantics",
        "operator_inventory",
        "target_contract_sha256",
        "authoritative_hamiltonian_sha256",
        "band_frame_contract_sha256",
        "operator_selection_sha256",
    ]
    identity = IOBuffer()
    for key in ordered_keys
        haskey(first_result.headers, key) || error("VECTOR_RESPONSE_IDENTITY_FIELD_MISSING: $key")
        write(identity, key, '=', first_result.headers[key], '\0')
    end
    bytes2hex(sha256(take!(identity))) == get(first_result.headers, "task_sha256", "") ||
        error("VECTOR_RESPONSE_TASK_SHA256_MISMATCH")
    metadata = joinpath(directory, "spectral_response_metadata.txt")
    isfile(metadata) || error("VECTOR_RESPONSE_METADATA_MISSING")
    text = read(metadata, String)
    for key in common
        value = get(first_result.headers, key, "")
        occursin(key * " = " * repr(value), text) ||
            error("VECTOR_RESPONSE_METADATA_MISMATCH: $key")
    end
    return first_result
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
            "wanniernlqg.linear-transport-vector/2.0",
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
    isapprox(
        tensors[:total],
        tensors[:drude] + tensors[:quantum_metric] + tensors[:berry_curvature];
        atol = 1e-8,
        rtol = 2e-12,
    ) || error("LINEAR_TRANSPORT_DECOMPOSITION_MISMATCH")
    return (; fermi_energies = first_result.axis, tensors, metadata = first_result.headers)
end

"""Strictly read and validate one vectorized Orbital Magnetization result directory."""
function read_orbital_magnetization_result(directory::AbstractString)
    terms = (:srocc, :cmocc, :total)
    labels = string.(collect("xyz"))
    results = Dict(
        term => _read_vector_table(
            joinpath(directory, "orbital_magnetization_$(term).dat"),
            "wanniernlqg.orbital-magnetization-vector/1.0",
            "orbital_magnetization",
            string(term),
            labels,
            "muB/cell",
        ) for term in terms
    )
    first_result = _validate_vector_result_common(results, directory)
    semantics = get(first_result.headers, "input_semantics", "")
    inventory = split(get(first_result.headers, "operator_inventory", ""), ',')
    target = get(first_result.headers, "target_contract_sha256", "")
    if semantics == "defined_finite_model"
        inventory == ["NOT_APPLICABLE_DEFINED_FINITE_MODEL"] ||
            error("ORBITAL_FINITE_MODEL_INVENTORY_CONFLICT")
        target == "NOT_APPLICABLE_DEFINED_FINITE_MODEL" ||
            error("ORBITAL_FINITE_MODEL_TARGET_CONTRACT_CONFLICT")
    else
        required = Set((
            "hamiltonian",
            "position",
            "hamiltonian_weighted_connection",
            "derivative_overlap_tensor",
            "hamiltonian_weighted_axial_derivative_overlap",
        ))
        Set(inventory) == required || error("ORBITAL_MATERIAL_FIVE_OPERATOR_INVENTORY_REQUIRED")
        occursin(r"^[0-9a-f]{64}$", target) || error("ORBITAL_MATERIAL_TARGET_CONTRACT_REQUIRED")
        for key in (
            "authoritative_hamiltonian_sha256",
            "band_frame_contract_sha256",
            "operator_selection_sha256",
        )
            occursin(r"^[0-9a-f]{64}$", get(first_result.headers, key, "")) ||
                error("ORBITAL_MATERIAL_PROVENANCE_REQUIRED: $key")
        end
    end
    vectors = Dict(term => results[term].values for term in terms)
    isapprox(vectors[:total], vectors[:srocc] + vectors[:cmocc]; atol = 1e-20, rtol = 2e-12) ||
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
