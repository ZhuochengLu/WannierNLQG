#!/usr/bin/env julia

using WannierNLQG
using Test

const ROOT = normpath(joinpath(@__DIR__, ".."))
const GUIDE = joinpath(ROOT, "docs", "WANNIERIZATION.md")
const EXAMPLE_DIRECTORY = joinpath(ROOT, "examples", "templates", "wannierization")
const EXAMPLE_FILES =
    ("generate_uiu_qe.jl", "generate_uiu_vasp.jl", "prepare_full_uiu_operator_bundle.jl")
const CONFIG_MIGRATION = joinpath(ROOT, "docs", "WANNIERIZATION_CONFIG.md")
const PUBLIC_MIGRATION = joinpath(ROOT, "docs", "PUBLIC_API.md")
const EXPECTED_WANNIERIZATION_FACADE = Set((
    :Wannierization,
    :WannierizationConfig,
    :WannierizationResult,
    :construct_wannier_functions,
))

function documentation_check(condition::Bool, message::AbstractString)
    condition || error("Wannierization documentation gate failed: $(message)")
    return nothing
end

documentation_check(isfile(GUIDE), "missing WANNIERIZATION.md")
documentation_check(isfile(CONFIG_MIGRATION), "missing WANNIERIZATION_CONFIG.md")
documentation_check(isfile(PUBLIC_MIGRATION), "missing PUBLIC_API.md")
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
# The maintained guide documents normalized TOML, not the archived Julia group layout.
function check_normalized_wannierization_guide(text::AbstractString)
    for marker in (
        "Runtime.read_task_input",
        "Runtime.run_task_input",
        "relative to that file",
        "wannierization",
        "ordinary",
        "symmetry_adapted",
        "symmetrization",
        "mesh_screening",
        "[wannierization.*]",
        "[symmetrization.*]",
        "namespaces are rejected",
        "## Solver and accepted state",
        "## Operators, symmetry and migration",
        "operator_tasks",
        "mutually exclusive",
        "checkpoint",
        "recovery path",
    )
        documentation_check(occursin(marker, text), "normalized guide omits $(marker)")
    end
    defaults = WannierNLQG.Wannierization.WannierizationSolverConfig().stage_controls
    for name in (:dis_num_iter, :dis_conv_tol, :dis_conv_window, :num_iter, :conv_tol, :conv_window)
        pattern = Regex("(?<![A-Za-z_])" * string(name) * "\\s*=\\s*([0-9.eE+\\-]+)")
        found = match(pattern, text)
        documentation_check(found !== nothing, "guide omits solver default $(name)")
        documentation_check(
            parse(Float64, found.captures[1]) == getproperty(defaults, name),
            "guide solver default differs for $(name)",
        )
    end
    source = read(
        joinpath(ROOT, "ext", "WannierNLQGWannierizationExt", "hdf5", "FixedSubspace.jl"),
        String,
    )
    found = match(r"const WANNIERIZATION_CHECKPOINT_SCHEMA_VERSION\s*=\s*\"([^\"]+)\"", source)
    documentation_check(found !== nothing, "current checkpoint wire declaration is missing")
    documentation_check(
        occursin("The default embedded checkpoint wire is $(found.captures[1]).", text),
        "guide does not name the default embedded checkpoint wire",
    )
    referenced = match(
        r"const WANNIERIZATION_REFERENCED_CHECKPOINT_SCHEMA_VERSION\s*=\s*\"([^\"]+)\"",
        source,
    )
    documentation_check(referenced !== nothing, "referenced checkpoint wire declaration is missing")
    documentation_check(
        occursin(
            "wire $(referenced.captures[1]) and an explicitly bound retained source root",
            text,
        ),
        "guide does not name the referenced checkpoint wire and source-root requirement",
    )
    return true
end
check_normalized_wannierization_guide(text)

@testset "normalized guide rejects stale defaults and legacy-boundary omissions" begin
    @test check_normalized_wannierization_guide(text)
    for (old, new) in (
        ("dis_num_iter=200", "dis_num_iter=201"),
        ("namespaces are rejected", "namespaces are accepted"),
        (
            match(r"The default embedded checkpoint wire is [0-9.]+\.", text).match,
            "The default embedded checkpoint wire is unsupported.",
        ),
        (
            match(r"wire [0-9.]+ and an explicitly bound retained source root", text).match,
            "wire unsupported and an explicitly bound retained source root",
        ),
        ("## Solver and accepted state", "## Missing solver reference"),
    )
        @test count(old, text) == 1
        @test_throws ErrorException check_normalized_wannierization_guide(
            replace(text, old => new; count = 1),
        )
    end
end

# The internal typed compatibility layout is retained independently of TOML syntax.
config_groups = (
    (:input, WannierNLQG.Wannierization.WannierizationInputConfig),
    (:solver, WannierNLQG.Wannierization.WannierizationSolverConfig),
    (:checkpoint, WannierNLQG.Wannierization.WannierizationCheckpointConfig),
    (:runtime, WannierNLQG.Wannierization.WannierizationRuntimeConfig),
    (:output, WannierNLQG.Wannierization.WannierizationOutputConfig),
)
leaf_count = sum(length(fieldnames(group_type)) for (_, group_type) in config_groups)
documentation_check(
    leaf_count == 77 &&
        Set(fieldnames(WannierNLQG.Wannierization.WannierizationCheckpointConfig)) == Set((
            :restart_hdf5,
            :checkpoint_hdf5,
            :num_dump_cycles,
            :recovery,
            :storage,
            :reference_root,
        )),
    "grouped Julia compatibility configuration must contain the 77 declared leaves and checkpoint storage fields",
)

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
