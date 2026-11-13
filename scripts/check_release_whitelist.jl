#!/usr/bin/env julia

using JSON3

const ROOT = normpath(joinpath(@__DIR__, ".."))
const SOURCE_DISTRIBUTION =
    JSON3.read(read(joinpath(ROOT, "scripts", "source_distribution.json"), String))
const CLASSIFIED_PATHS =
    Set(String(path) for feature in values(SOURCE_DISTRIBUTION.features) for path in feature.paths)
const GENERATED_PATHS = Set(String.(SOURCE_DISTRIBUTION.generated))
const ALLOWED_TOP_LEVEL =
    Set(first(split(path, '/')) for path in union(CLASSIFIED_PATHS, GENERATED_PATHS))
const ALLOWED_SCRIPT_FILES =
    Set(path[9:end] for path in CLASSIFIED_PATHS if startswith(path, "scripts/"))

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
const LOCAL_HOME_PREFIX = homedir()
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

# Inspect raw bytes too: HDF5 can retain deleted private attributes outside its
# current logical metadata, and text-extension checks cannot see those remnants.
function contains_release_bytes(data::AbstractVector{UInt8}, needle::AbstractVector{UInt8})
    length(data) < length(needle) && return false
    for start in 1:(length(data) - length(needle) + 1)
        all(offset -> data[start + offset - 1] == needle[offset], eachindex(needle)) && return true
    end
    return false
end

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
    actual_files = Set(path for path in paths if isfile(joinpath(root, path)))
    expected_files = union(CLASSIFIED_PATHS, GENERATED_PATHS)
    actual_files == expected_files || error(
        "release payload whitelist differs: " *
        "missing=$(sort!(collect(setdiff(expected_files, actual_files)))) " *
        "extra=$(sort!(collect(setdiff(actual_files, expected_files))))",
    )
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
        contains_release_bytes(read(full_path), codeunits(LOCAL_HOME_PREFIX)) &&
            error("local absolute path bytes remain in release file: $(path)")
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
