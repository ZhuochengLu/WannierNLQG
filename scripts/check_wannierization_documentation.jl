#!/usr/bin/env julia

using WannierNLQG

const ROOT = normpath(joinpath(@__DIR__, ".."))
const GUIDE = joinpath(ROOT, "docs", "WANNIERIZATION.md")
const EXAMPLE_DIRECTORY = joinpath(ROOT, "examples", "templates", "wannierization")
const EXAMPLE_FILES =
    ("generate_uiu_qe.jl", "generate_uiu_vasp.jl", "prepare_exact_operator_bundle.jl")
const CONFIG_MIGRATION = joinpath(ROOT, "docs", "WANNIERIZATION_CONFIG_MIGRATION.md")
const PUBLIC_MIGRATION = joinpath(ROOT, "docs", "MIGRATION_1.0.0.md")
const EXPECTED_WANNIERIZATION_FACADE = Set((
    :Wannierization,
    :SymmetryAdaptedWannierizationConfig,
    :WannierizationResult,
    :construct_symmetry_adapted_wannier_functions,
))

function documentation_check(condition::Bool, message::AbstractString)
    condition || error("Wannierization documentation gate failed: $(message)")
    return nothing
end

documentation_check(isfile(GUIDE), "missing WANNIERIZATION.md")
documentation_check(isfile(CONFIG_MIGRATION), "missing WANNIERIZATION_CONFIG_MIGRATION.md")
documentation_check(isfile(PUBLIC_MIGRATION), "missing MIGRATION_1.0.0.md")
text = read(GUIDE, String)
migration_text = read(CONFIG_MIGRATION, String)
public_migration_text = read(PUBLIC_MIGRATION, String)

documentation_check(
    occursin("checkpoint_hdf5 = \"checkpoint.wannierization.h5\"", public_migration_text),
    "public migration must use the canonical Wannierization checkpoint suffix",
)
documentation_check(
    !occursin("checkpoint_hdf5 = \"checkpoint.h5\"", public_migration_text),
    "public migration retains a rejected generic checkpoint suffix",
)
documentation_check(
    occursin("demo_wannierization_tb.dat.diagnostics.json", text),
    "guide omits the neutral Wannier90 diagnostic sidecar",
)

documentation_check(
    occursin("import WannierNLQG.Wannierization as W", text),
    "guide must demonstrate qualified expert access",
)
documentation_check(
    !occursin("using WannierNLQG.Wannierization", text),
    "guide retains the former broad import example",
)
for contract in (
    "symmetry_detection_backend_provenance",
    "WannierizationInternalSupport",
    "RepresentationPreparation",
    "ProjectionSearch",
    "PAWMatrixElements",
    "SolverCheckpoint",
    "OperatorExport",
    "WorkflowOrchestration",
    "WannierNLQG.wannierization_checkpoint/1.0",
    "Packed HDF5 1.0",
)
    documentation_check(occursin(contract, text), "guide omits $(contract)")
end

section = split(split(text, "## 4."; limit = 2)[2], "## 5."; limit = 2)[1]
config_groups = (
    (:input, WannierNLQG.Wannierization.WannierizationInputConfig),
    (:solver, WannierNLQG.Wannierization.WannierizationSolverConfig),
    (:checkpoint, WannierNLQG.Wannierization.WannierizationCheckpointConfig),
    (:runtime, WannierNLQG.Wannierization.WannierizationRuntimeConfig),
    (:output, WannierNLQG.Wannierization.WannierizationOutputConfig),
)
leaf_count = sum(length(fieldnames(group_type)) for (_, group_type) in config_groups)
for field in fieldnames(WannierNLQG.Wannierization.SymmetryAdaptedWannierizationConfig)
    row = "| `$(field)` |"
    documentation_check(
        count(line -> startswith(line, row), split(section, '\n')) == 1,
        "guide must list top-level group $(field) exactly once",
    )
end
for (group, group_type) in config_groups, field in fieldnames(group_type)
    row = "| `$(field)` |"
    documentation_check(
        count(line -> startswith(line, row), split(section, '\n')) == 1,
        "guide must list $(group).$(field) exactly once",
    )
    documentation_check(
        occursin("| `$(field)` | `$(group).$(field)` |", migration_text),
        "migration table omits $(field) -> $(group).$(field)",
    )
end
documentation_check(leaf_count == 73, "grouped configuration must contain 73 leaves")

documentation_check(
    Set(names(WannierNLQG.Wannierization; all = false, imported = false)) ==
    EXPECTED_WANNIERIZATION_FACADE,
    "Wannierization facade differs from the documented three-symbol contract",
)
documentation_check(isdir(EXAMPLE_DIRECTORY), "Wannierization template directory is missing")
for name in EXAMPLE_FILES
    path = joinpath(EXAMPLE_DIRECTORY, name)
    documentation_check(isfile(path), "Wannierization template $(name) is missing")
    example_text = read(path, String)
    documentation_check(
        occursin("import WannierNLQG.Wannierization as W", example_text),
        "template $(name) omits qualified expert access",
    )
end

readme = read(joinpath(ROOT, "README.md"), String)
documentation_check(occursin("docs/WANNIERIZATION.md", readme), "README omits the guide")
println("Wannierization documentation gate passed")
