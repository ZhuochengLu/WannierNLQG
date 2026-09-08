#!/usr/bin/env julia

using LinearAlgebra
using JSON3
using HDF5

length(ARGS) == 1 || error("usage: model_lattice_probe.jl MODEL.h5")
path = abspath(ARGS[1])
isfile(path) || error("packed model does not exist: $(path)")
payload = HDF5.h5open(path, "r") do handle
    root_attributes = HDF5.attributes(handle)
    for required in ("schema", "schema_version", "scientific_content_sha256")
        haskey(root_attributes, required) ||
            error("packed manifest is missing root attribute $(required)")
    end
    schema = String(read(root_attributes["schema"]))
    schema == "wanniernlqg.real-space-operators" ||
        error("unsupported packed model schema $(schema)")
    schema_version = String(read(root_attributes["schema_version"]))
    schema_version in (
        "1.0",
        "5.0",
        "5.1",
        "5.2",
        "5.3",
        "5.4",
        "5.5",
        "5.6",
        "5.7",
        "6.0",
        "6.1",
        "6.2",
        "6.3",
    ) || error("unsupported packed model schema_version $(schema_version)")
    scientific_content_sha256 =
        lowercase(String(read(root_attributes["scientific_content_sha256"])))
    length(scientific_content_sha256) == 64 &&
    all(character -> character in '0':'9' || character in 'a':'f', scientific_content_sha256) ||
        error("packed manifest scientific_content_sha256 is invalid")
    haskey(handle, "model/lattice") || error("packed model is missing /model/lattice")
    lattice = Matrix{Float64}(read(handle["model/lattice"]))
    return (; schema, schema_version, scientific_content_sha256, lattice)
end
schema = payload.schema
schema_version = payload.schema_version
scientific_content_sha256 = payload.scientific_content_sha256
lattice = payload.lattice
size(lattice) == (3, 3) || error("packed manifest lattice is not 3x3")
all(isfinite, lattice) || error("packed manifest lattice contains non-finite values")
abs(det(lattice)) > 1.0e-14 || error("packed manifest lattice is singular")
JSON3.write(
    stdout,
    Dict(
        "schema" => "wanniernlqg.visualization-model-lattice",
        "schema_version" => "1.0",
        "bundle_schema" => schema,
        "bundle_schema_version" => schema_version,
        "scientific_content_sha256" => scientific_content_sha256,
        "lattice_rows_angstrom" => [collect(row) for row in eachrow(lattice)],
    ),
)
println()
