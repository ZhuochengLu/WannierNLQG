#!/usr/bin/env julia

using WannierNLQG

const ROOT = normpath(joinpath(@__DIR__, ".."))
const GUIDE = joinpath(ROOT, "docs", "SYMMETRIZATION.md")
const PUBLIC_OPERATOR_DOCUMENTS = (GUIDE, joinpath(ROOT, "docs", "RELEASE_NOTES.md"))
const LEGACY_OPERATOR_ABBREVIATIONS = r"\b(H|AA|BB|CC|FF|OO|GG)\b"
const EXAMPLE_ROOT = joinpath(ROOT, "examples", "symmetrization")

function documentation_check(condition::Bool, message::AbstractString)
    condition || error("symmetrization documentation gate failed: $(message)")
    return nothing
end

documentation_check(isfile(GUIDE), "missing SYMMETRIZATION.md")
text = read(GUIDE, String)
for contract in (
    "HDF5 + JSON3 + EzXML",
    "detect_tb_compatibility_symmetry_operations",
    "symmetry_detection_backend_provenance",
)
    documentation_check(occursin(contract, text), "guide omits boundary contract $(contract)")
end
documentation_check(
    !occursin("Spglib`, `HDF5`, and `JSON3", text),
    "guide retains the obsolete Symmetrization trigger set",
)

for (config_type, start_heading, stop_heading) in (
    (
        WannierNLQG.Symmetrization.MagneticMomentConfig,
        "### 2.1 MagneticMomentConfig",
        "### 2.2 MeshScreenConfig",
    ),
    (
        WannierNLQG.Symmetrization.MeshScreenConfig,
        "### 2.2 MeshScreenConfig",
        "### 2.3 SymmetrizationConfig",
    ),
    (WannierNLQG.Symmetrization.SymmetrizationConfig, "### 2.3 SymmetrizationConfig", "## 3."),
)
    section = split(split(text, start_heading; limit = 2)[2], stop_heading; limit = 2)[1]
    for field in fieldnames(config_type)
        row = "| $(field) |"
        count_in_tables = count(line -> startswith(line, row), split(section, '\n'))
        documentation_check(
            count_in_tables == 1,
            "guide contains field $(field) $(count_in_tables) times in tables",
        )
    end
end

for document in PUBLIC_OPERATOR_DOCUMENTS
    matched = match(LEGACY_OPERATOR_ABBREVIATIONS, read(document, String))
    documentation_check(
        matched === nothing,
        "$(basename(document)) uses a legacy operator abbreviation",
    )
end

for (directory, _, files) in walkdir(EXAMPLE_ROOT), file in files
    endswith(file, ".jl") || continue
    path = joinpath(directory, file)
    source = read(path, String)
    documentation_check(
        !occursin(r"inputs[/\\]seed(?:_tb\.dat|\.(?:win|chk|eig|mmn|spn))", source),
        "$(relpath(path, ROOT)) references a missing seed fixture",
    )
end

readme = read(joinpath(ROOT, "README.md"), String)
documentation_check(occursin("docs/SYMMETRIZATION.md", readme), "README omits the guide")
println("symmetrization documentation gate passed")
