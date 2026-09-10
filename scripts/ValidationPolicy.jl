module ValidationPolicy

export FAST_READINESS_SCRIPTS,
    FULL_NUMERICAL_SCRIPTS,
    FULL_READINESS_SCRIPTS,
    TEST_CONTRACT_SUPPORT_SCRIPTS,
    TEST_REACHABLE_SCRIPT_ENTRIES,
    test_contract_entries

const FAST_READINESS_SCRIPTS = (
    "check_structure_boundaries.jl",
    "check_progress_output.jl",
    "check_symmetrization_documentation.jl",
    "check_wannierization_documentation.jl",
    "check_release_whitelist.jl",
    "check_response_symmetry_catalog.jl",
    "check_version_consistency.jl",
    "check_user_guide_examples.jl",
    "check_documentation.jl",
    "audit_source_documentation.jl",
)

const FULL_READINESS_SCRIPTS = ("check_symmetrization_examples.jl",)

const FULL_NUMERICAL_SCRIPTS = ()

const TEST_REACHABLE_SCRIPT_ENTRIES = (
    "ArchitectureContracts.jl",
    "check_mpi_smoke.jl",
    "check_response_symmetry_mpi.jl",
    "plot_band_structure.jl",
    "plot_kslice.jl",
    "plot_response_integral.jl",
    "visualization",
)

const TEST_CONTRACT_SUPPORT_SCRIPTS = (
    "ValidationPolicy.jl",
    "EvidenceHashing.jl",
    "FormatterPaths.jl",
    "SourceDocumentationAudit.jl",
    "check_format.jl",
    "check_tag_ci_reuse.py",
    "run_tests.py",
    "ResponseSymmetryValidationCase.jl",
    "check_response_symmetry_mpi.jl",
)

function test_contract_entries()
    entries = String[
        "test",
        ".github",
        ".JuliaFormatter.toml",
        ".gitignore",
        "AGENTS.md",
        "API_BREAKING_CHANGES.md",
        "CHANGELOG.md",
        "CITATION.cff",
        "CODE_OF_CONDUCT.md",
        "CONTRIBUTING.md",
        "LICENSE",
        "README.md",
        "SECURITY.md",
        "SHA256SUMS",
        "SOURCE_MANIFEST.tsv",
        "THIRD_PARTY_NOTICE.md",
        "USER_GUIDE.md",
        "docs",
        "examples",
        "theory",
    ]
    append!(entries, joinpath.("scripts", TEST_CONTRACT_SUPPORT_SCRIPTS))
    append!(entries, joinpath.("scripts", FAST_READINESS_SCRIPTS))
    append!(entries, joinpath.("scripts", FULL_READINESS_SCRIPTS))
    append!(entries, joinpath.("scripts", FULL_NUMERICAL_SCRIPTS))
    append!(entries, joinpath.("scripts", TEST_REACHABLE_SCRIPT_ENTRIES))
    return sort!(unique!(entries))
end

end
