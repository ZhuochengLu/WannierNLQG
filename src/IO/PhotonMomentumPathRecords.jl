"""
Write an explicitly zipped photon axis bound to one existing numerical tensor.

The tensor's historical columns are unchanged. Each record preserves original
row index, energy in eV and Cartesian momentum in A^-1, including signed zeros.
This record establishes the explicit axis and local publication lifetime only.
"""
function write_photon_momentum_path_record(
    response_path,
    photon_energies,
    photon_momenta;
    digits::Int = 7,
)
    length(photon_energies) == length(photon_momenta) && !isempty(photon_energies) ||
        throw(DimensionMismatch("paired photon axes must have equal nonzero lengths"))
    7 <= digits <= 17 || throw(ArgumentError("response output digits must lie in 7:17"))
    all(e -> e isa Real && !(e isa Bool) && isfinite(e) && isfinite(Float64(e)), photon_energies) &&
    all(
        q ->
            length(q) == 3 &&
            all(x -> x isa Real && !(x isa Bool) && isfinite(x) && isfinite(Float64(x)), q),
        photon_momenta,
    ) ||
        throw(ArgumentError("paired axes require finite real energies and Cartesian three-vectors"))
    path = response_path * ".photon_momentum_path.toml"
    isfile(path) && throw(ArgumentError("photon momentum path record already exists: $path"))
    response_state = scientific_file_state(response_path)
    document = Dict(
        "schema" => "wanniernlqg.photon-momentum-path/2.0",
        "pairing" => "zip",
        "energy_unit" => "eV",
        "momentum_unit" => "A^-1",
        "momentum_coordinates" => "Cartesian",
        "signed_zero_grouping" => "distinct exact isequal keys; original values retained",
        "response_file" => basename(response_path),
        "response_publication" => scientific_file_record(response_state),
        "response_output_digits" => digits,
        "rows" => [
            Dict(
                "row_index" => index,
                "photon_energy_ev" => Float64(photon_energies[index]),
                "photon_momentum_A_inverse" => collect(photon_momenta[index]),
            ) for index in eachindex(photon_energies)
        ],
    )
    open(path, "w") do file
        TOML.print(file, document; sorted = true)
    end
    isequal(response_state, scientific_file_state(response_path)) ||
        throw(ArgumentError("paired response changed during record publication"))
    return path
end

"""Read the current explicit axis and tensor once under its local publication record."""
function read_photon_momentum_path_record(path::AbstractString)
    document = read_task_input_file(path).document
    expected = Set([
        "schema",
        "pairing",
        "energy_unit",
        "momentum_unit",
        "momentum_coordinates",
        "signed_zero_grouping",
        "response_file",
        "response_publication",
        "response_output_digits",
        "rows",
    ])
    Set(keys(document)) == expected ||
        throw(ArgumentError("unknown or missing paired-axis record fields"))
    document["schema"] == "wanniernlqg.photon-momentum-path/2.0" &&
    document["pairing"] == "zip" &&
    document["energy_unit"] == "eV" &&
    document["momentum_unit"] == "A^-1" &&
    document["momentum_coordinates"] == "Cartesian" ||
        throw(ArgumentError("unsupported paired photon axis schema or units"))
    document["signed_zero_grouping"] == "distinct exact isequal keys; original values retained" ||
        throw(ArgumentError("unsupported signed-zero axis policy"))
    digits = document["response_output_digits"]
    digits isa Int && 7 <= digits <= 17 || throw(ArgumentError("invalid tensor precision"))
    number_format = Printf.Format("%.$(digits)e")
    name = document["response_file"]
    name isa String && basename(name) == name && name ∉ (".", "..") ||
        throw(ArgumentError("paired response locator must be a local basename"))
    response = joinpath(dirname(abspath(path)), name)
    rows = document["rows"]
    rows isa AbstractVector && !isempty(rows) || throw(ArgumentError("empty paired axis"))
    observed = with_scientific_source(
        response;
        expected_record = document["response_publication"],
    ) do filename
        [
            split(line) for
            line in eachline(filename) if !isempty(strip(line)) && !startswith(strip(line), '#')
        ]
    end
    numerical_rows = observed.value
    length(numerical_rows) == length(rows) ||
        throw(DimensionMismatch("paired axis/tensor row count mismatch"))
    for (index, row) in pairs(rows)
        Set(keys(row)) == Set(["row_index", "photon_energy_ev", "photon_momentum_A_inverse"]) ||
            throw(ArgumentError("unknown paired row fields"))
        row["row_index"] isa Int && row["row_index"] == index ||
            throw(ArgumentError("paired row indices must retain complete original order"))
        energy = row["photon_energy_ev"]
        energy isa Real && !(energy isa Bool) && isfinite(energy) ||
            throw(ArgumentError("nonfinite paired energy"))
        length(numerical_rows[index]) >= 2 && isequal(
            parse(Float64, numerical_rows[index][2]),
            parse(Float64, Printf.format(number_format, Float64(energy))),
        ) || throw(ArgumentError("paired original energy does not match its formatted tensor row"))
        q = row["photon_momentum_A_inverse"]
        q isa AbstractVector &&
        length(q) == 3 &&
        all(x -> x isa Real && !(x isa Bool) && isfinite(x), q) ||
            throw(ArgumentError("invalid paired Cartesian momentum"))
    end
    return document
end
