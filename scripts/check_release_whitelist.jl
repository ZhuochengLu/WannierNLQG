#!/usr/bin/env julia

const ROOT = normpath(joinpath(@__DIR__, ".."))
const ALLOWED_TOP_LEVEL = Set([
    ".JuliaFormatter.toml",
    ".github",
    ".gitignore",
    "API_BREAKING_CHANGES.md",
    "AGENTS.md",
    "CHANGELOG.md",
    "CITATION.cff",
    "catalog-generation-receipt.json",
    "CODE_OF_CONDUCT.md",
    "CONTRIBUTING.md",
    "LICENSE",
    "Manifest.toml",
    "Project.toml",
    "README.md",
    "SECURITY.md",
    "SHA256SUMS",
    "SOURCE_MANIFEST.tsv",
    "THIRD_PARTY_NOTICE.md",
    "USER_GUIDE.md",
    "docs",
    "examples",
    "ext",
    "scripts",
    "src",
    "test",
    "theory",
])
const ALLOWED_SCRIPT_FILES = Set([
    "ArchitectureContracts.jl",
    "EvidenceHashing.jl",
    "FormatterPaths.jl",
    "ResponseSymmetryValidationCase.jl",
    "SourceDocumentationAudit.jl",
    "ValidationPolicy.jl",
    "audit_source_documentation.jl",
    "check_documentation.jl",
    "check_format.jl",
    "check_mpi_smoke.jl",
    "check_progress_output.jl",
    "check_release_whitelist.jl",
    "check_response_symmetry_catalog.jl",
    "check_response_symmetry_mpi.jl",
    "check_structure_boundaries.jl",
    "check_symmetrization_documentation.jl",
    "check_symmetrization_examples.jl",
    "check_user_guide_examples.jl",
    "check_version_consistency.jl",
    "check_wannierization_documentation.jl",
    "format.jl",
    "generate_response_symmetry_catalog.jl",
    "generate_vasp_paw_spn.jl",
    "plot_band_structure.jl",
    "plot_kslice.jl",
    "plot_response_integral.jl",
    "write_release_manifest.jl",
    "visualization/Launcher.jl",
    "visualization/__init__.py",
    "visualization/backend.py",
    "visualization/band_adapters.py",
    "visualization/band_comparison.py",
    "visualization/cli.py",
    "visualization/common.py",
    "visualization/check_environment.py",
    "visualization/kslice_parser.py",
    "visualization/model_lattice_probe.jl",
    "visualization/response_parser.py",
    "visualization/requirements.txt",
    "visualization/style.py",
    "visualization/vasp_native.py",
])
const FORBIDDEN_RELEASE_PATHS = Set([
    "validation",
    "docs/LOW_NOISE_PERFORMANCE_CAMPAIGN.md",
    "docs/DEEP_CLEANUP_PLAN.md",
    "scripts/run_symmetrization_low_noise_campaign.jl",
    "scripts/benchmark_symmetrization_cold_loading.jl",
    "scripts/check_symmetrization_extension_parity.jl",
    "examples/symmetrization/outputs",
])
const FORBIDDEN_CANDIDATE_PATTERN =
    r"wannierNLQG-(?:release|v[0-9][^/[:space:]]*)-candidate(?:-[0-9_]+)?"
const LOCAL_HOME_PREFIX = join(("", "Users", "luzhuocheng"), '/')
const DEV_EVIDENCE_TOP_LEVEL =
    Set(["BASELINE_PROVENANCE.md", "change_impact.toml", "provenance", "reports"])

# Git administrative data is outside the release payload. A symlink is never
# exempt, and a nested .git remains visible to the ordinary release checks.
function root_git_metadata(root::AbstractString, path::AbstractString)
    return normpath(path) == normpath(joinpath(root, ".git")) &&
           !islink(path) &&
           (isfile(path) || isdir(path))
end

function release_paths(root::AbstractString = ROOT)
    paths = String[]
    for (directory, directories, files) in walkdir(root)
        filter!(name -> !root_git_metadata(root, joinpath(directory, name)), directories)
        filter!(name -> !root_git_metadata(root, joinpath(directory, name)), files)
        sort!(directories)
        sort!(files)
        for name in directories
            push!(paths, replace(relpath(joinpath(directory, name), root), '\\' => '/'))
        end
        for name in files
            push!(paths, replace(relpath(joinpath(directory, name), root), '\\' => '/'))
        end
    end
    return sort!(paths)
end

function script_files(root::AbstractString = ROOT)
    scripts_root = joinpath(root, "scripts")
    files = String[]
    for (directory, directories, names) in walkdir(scripts_root)
        sort!(directories)
        for name in sort!(names)
            path = joinpath(directory, name)
            isfile(path) || continue
            push!(files, replace(relpath(path, scripts_root), '\\' => '/'))
        end
    end
    return Set(files)
end

function script_inventory_difference(actual)
    actual_set = Set(String.(actual))
    return (
        missing = sort!(collect(setdiff(ALLOWED_SCRIPT_FILES, actual_set))),
        extra = sort!(collect(setdiff(actual_set, ALLOWED_SCRIPT_FILES))),
    )
end

const TEXT_EXTENSIONS = Set([
    "",
    ".cff",
    ".jl",
    ".jo",
    ".json",
    ".md",
    ".py",
    ".sh",
    ".toml",
    ".tsv",
    ".txt",
    ".yml",
    ".yaml",
])
const SECRET_PATTERNS = (
    r"ghp_[A-Za-z0-9]{20,}",
    r"github_pat_[A-Za-z0-9_]{20,}",
    r"AKIA[0-9A-Z]{16}",
    r"-----BEGIN [A-Z ]*PRIVATE KEY-----",
)

function check_release_whitelist(root::AbstractString = ROOT)
    project_text = read(joinpath(root, "Project.toml"), String)
    is_dev_candidate = occursin(r"^version\s*=\s*\"[^\"]+-DEV\"$"m, project_text)
    allowed_top_level =
        is_dev_candidate ? union(ALLOWED_TOP_LEVEL, DEV_EVIDENCE_TOP_LEVEL) : ALLOWED_TOP_LEVEL
    top_level =
        Set(name for name in readdir(root) if !root_git_metadata(root, joinpath(root, name)))
    top_level == allowed_top_level || error(
        "release top-level whitelist differs: missing=$(sort!(collect(setdiff(allowed_top_level, top_level)))) " *
        "extra=$(sort!(collect(setdiff(top_level, allowed_top_level))))",
    )

    script_difference = script_inventory_difference(script_files(root))
    isempty(script_difference.missing) && isempty(script_difference.extra) || error(
        "release scripts whitelist differs: missing=$(script_difference.missing) " *
        "extra=$(script_difference.extra)",
    )

    paths = release_paths(root)
    if is_dev_candidate
        paths = filter(paths) do path
            all(
                evidence -> path != evidence && !startswith(path, evidence * "/"),
                DEV_EVIDENCE_TOP_LEVEL,
            )
        end
    end
    for forbidden in FORBIDDEN_RELEASE_PATHS
        forbidden in paths && error("candidate-only release path remains: $(forbidden)")
    end
    for path in paths
        basename(path) == ".DS_Store" && error(".DS_Store remains in release tree: $(path)")
        occursin(FORBIDDEN_CANDIDATE_PATTERN, path) &&
            error("candidate directory name remains in release path: $(path)")
        (endswith(path, ".tmp") || endswith(path, ".bak") || endswith(path, ".log")) &&
            error("temporary/generated file remains in release tree: $(path)")
    end

    symlinks = filter(path -> islink(joinpath(root, path)), paths)
    isempty(symlinks) || error("symbolic links are not allowed in the release tree: $(symlinks)")

    oversized = filter(paths) do path
        full_path = joinpath(root, path)
        isfile(full_path) && filesize(full_path) > 5 * 1024 * 1024
    end
    isempty(oversized) || error("release files larger than 5 MiB require review: $(oversized)")

    for path in paths
        full_path = joinpath(root, path)
        isfile(full_path) || continue
        lowercase(splitext(path)[2]) in TEXT_EXTENSIONS || continue
        text = read(full_path, String)
        occursin(LOCAL_HOME_PREFIX, text) &&
            error("local absolute path remains in release file: $(path)")
        occursin(FORBIDDEN_CANDIDATE_PATTERN, text) &&
            error("candidate directory name remains in release file: $(path)")
        for pattern in SECRET_PATTERNS
            occursin(pattern, text) &&
                error("credential-like text remains in release file: $(path)")
        end
    end

    println(
        "release whitelist gate passed: $(length(paths)) source paths" *
        (is_dev_candidate ? " (DEV evidence trees excluded)" : ""),
    )
    return true
end

if abspath(PROGRAM_FILE) == @__FILE__
    check_release_whitelist()
end
