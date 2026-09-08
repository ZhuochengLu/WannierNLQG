#!/usr/bin/env julia

using SHA
using TOML
using WannierNLQG

const ROOT = normpath(joinpath(@__DIR__, ".."))
const EXPECTED_VERSION = v"1.0.0"
const GPL2_ONLY_SPDX_IDENTIFIER = "GPL-2.0-only"
const GPL2_ONLY_LICENSE_SHA256 = "aaf135472f81c5b4a0dca9367e5bb5e9750032b5bebe5442b36e4c0a47430df3"
const GPL2_ONLY_METADATA_MARKERS = (
    ("CITATION.cff", "license: GPL-2.0-only"),
    ("README.md", "[GNU General Public License version 2 only (`GPL-2.0-only`)](LICENSE)"),
    ("CONTRIBUTING.md", "GNU General Public License version 2 only (`GPL-2.0-only`)"),
    ("THIRD_PARTY_NOTICE.md", "GPL-2.0-only"),
    (
        "THIRD_PARTY_NOTICE.md",
        "remain under their respective licenses; their source code is not vendored here",
    ),
)
const RESPONSE_SUMMARY_SCHEMA_DOCUMENTATION_PATH = "docs/STORAGE_SCHEMAS.md"
const RESPONSE_SUMMARY_SCHEMA_DOCUMENTATION_LABEL = "Response-symmetry runtime summary JSON"
const RESPONSE_SUMMARY_SCHEMA_DOCUMENTATION_MARKER = "| $(RESPONSE_SUMMARY_SCHEMA_DOCUMENTATION_LABEL) | `/1.0` |"

function check_license_metadata(root::AbstractString)
    license_path = joinpath(root, "LICENSE")
    isfile(license_path) || error("required release file is missing: LICENSE")
    license_sha256 = bytes2hex(sha256(read(license_path)))
    license_sha256 == GPL2_ONLY_LICENSE_SHA256 || error(
        "LICENSE is not the canonical SPDX $(GPL2_ONLY_SPDX_IDENTIFIER) text: " *
        "sha256=$(license_sha256)",
    )

    metadata_sources = Dict{String, String}()
    for (relative_path, marker) in GPL2_ONLY_METADATA_MARKERS
        source = get!(metadata_sources, relative_path) do
            path = joinpath(root, relative_path)
            isfile(path) || error("required release file is missing: $(relative_path)")
            read(path, String)
        end
        normalized_source = join(split(source), " ")
        occursin(marker, normalized_source) || error(
            "$(GPL2_ONLY_SPDX_IDENTIFIER) metadata marker is missing from " *
            "$(relative_path): $(marker)",
        )
    end

    for (relative_path, source) in metadata_sources
        for stale_marker in ("license: MIT", "[MIT License]", "GPL-2.0-or-later")
            occursin(stale_marker, source) && error(
                "stale or conflicting license marker remains in $(relative_path): " *
                "$(stale_marker)",
            )
        end
    end
    return true
end

check_license_metadata(ROOT)

function check_response_summary_schema_documentation(root::AbstractString)
    relative_path = RESPONSE_SUMMARY_SCHEMA_DOCUMENTATION_PATH
    path = joinpath(root, relative_path)
    isfile(path) || error("required schema inventory is missing: $(relative_path)")
    matching_rows =
        filter(line -> occursin(RESPONSE_SUMMARY_SCHEMA_DOCUMENTATION_LABEL, line), readlines(path))
    length(matching_rows) == 1 || error(
        "$(relative_path) must contain exactly one " *
        "$(RESPONSE_SUMMARY_SCHEMA_DOCUMENTATION_LABEL) row",
    )
    occursin(RESPONSE_SUMMARY_SCHEMA_DOCUMENTATION_MARKER, only(matching_rows)) ||
        error("response-symmetry runtime summary documentation is not /1.0 in $(relative_path)")
    return true
end

check_response_summary_schema_documentation(ROOT)

project = TOML.parsefile(joinpath(ROOT, "Project.toml"))
VersionNumber(project["version"]) == EXPECTED_VERSION ||
    error("Project.toml version is not $(EXPECTED_VERSION)")
Base.pkgversion(WannierNLQG) == EXPECTED_VERSION ||
    error("loaded package version is not $(EXPECTED_VERSION)")

for relative_path in (
    "README.md",
    "USER_GUIDE.md",
    "CHANGELOG.md",
    "docs/RELEASE_NOTES.md",
    "docs/MIGRATION_1.0.0.md",
    "docs/RELEASING.md",
)
    occursin("1.0.0", read(joinpath(ROOT, relative_path), String)) ||
        error("current release identity is missing from $(relative_path)")
end

for relative_path in (
    "LICENSE",
    "CITATION.cff",
    "CHANGELOG.md",
    "API_BREAKING_CHANGES.md",
    "SECURITY.md",
    "CONTRIBUTING.md",
    "CODE_OF_CONDUCT.md",
    "THIRD_PARTY_NOTICE.md",
    "SOURCE_MANIFEST.tsv",
    "SHA256SUMS",
    ".github/workflows/ci.yml",
)
    path = joinpath(ROOT, relative_path)
    isfile(path) && filesize(path) > 0 ||
        error("required release file is missing: $(relative_path)")
end

# Independent file identifiers are checked separately from retained logical contracts.
# Band uses its existing schema name, a single accepted wire version, and no
# historical migration. Its behavioral regression remains a required suite entry.
const INDEPENDENT_SCHEMA_CONSTANTS = (
    ("src/IO/RealSpaceOperatorBundles.jl", "OPERATOR_BUNDLE_SCHEMA_VERSION"),
    (
        "ext/WannierNLQGSymmetryFoundationExt/BandRepresentationPersistence.jl",
        "BAND_REPRESENTATION_SCHEMA_VERSION",
    ),
    (
        "ext/WannierNLQGWannierizationExt/hdf5/FixedSubspace.jl",
        "WANNIERIZATION_CHECKPOINT_SCHEMA_VERSION",
    ),
    (
        "ext/WannierNLQGWannierizationExt/hdf5/FixedSubspace.jl",
        "WANNIERIZATION_FIXED_SUBSPACE_SCHEMA_VERSION",
    ),
    (
        "ext/WannierNLQGWannierizationExt/hdf5/FixedSubspace.jl",
        "WANNIERIZATION_U_CONVERGENCE_DIAGNOSTICS_SCHEMA_VERSION",
    ),
    (
        "ext/WannierNLQGWannierizationExt/star_gauge/FrameContract.jl",
        "STAR_COVARIANT_PAW_GAUGE_SCHEMA_VERSION",
    ),
    (
        "ext/WannierNLQGWannierizationExt/ProjectionRepresentationSearchHDF5.jl",
        "PROJECTION_REPRESENTATION_SEARCH_SCHEMA_VERSION",
    ),
    (
        "ext/WannierNLQGWannierizationExt/VASPPawMatrixElements.jl",
        "VASP_PAW_MATRIX_ELEMENT_SCHEMA_VERSION",
    ),
    (
        "ext/WannierNLQGWannierizationExt/VASPPawSpinMatrixElements.jl",
        "VASP_PAW_SPN_SCHEMA_VERSION",
    ),
    ("ext/WannierNLQGWannierizationExt/QEPAWSpinMatrixElements.jl", "QE_PAW_SPN_SCHEMA_VERSION"),
    (
        "ext/WannierNLQGWannierizationExt/QEPAWMatrixElements.jl",
        "QE_PAW_MATRIX_ELEMENT_SCHEMA_VERSION",
    ),
    (
        "ext/WannierNLQGWannierizationExt/QEPAWMatrixElements.jl",
        "QE_PAW_ORACLE_PROVENANCE_SCHEMA_VERSION",
    ),
    (
        "ext/WannierNLQGWannierizationExt/SymmetryCompletedQEPAWMatrixElements.jl",
        "SYMMETRY_COMPLETED_QE_PAW_SCHEMA_VERSION",
    ),
    ("ext/WannierNLQGWannierizationExt/PAWSCDMInitialization.jl", "PAW_SCDM_INPUT_SCHEMA_VERSION"),
    (
        "ext/WannierNLQGWannierizationExt/PAWBlockPartitionAudit.jl",
        "PAW_BLOCK_PARTITION_AUDIT_SCHEMA_VERSION",
    ),
    (
        "ext/WannierNLQGWannierizationExt/WannierUIUGeneration.jl",
        "WANNIER_UIU_GENERATION_SCHEMA_VERSION",
    ),
    (
        "ext/WannierNLQGWannierizationExt/WannierHamiltonianOperatorGeneration.jl",
        "WANNIER_HAMILTONIAN_OPERATOR_GENERATION_SCHEMA_VERSION",
    ),
    (
        "ext/WannierNLQGWannierizationExt/WannierGaugeChainDiagnostics.jl",
        "WANNIER_GAUGE_CHAIN_DIAGNOSTIC_SCHEMA_VERSION",
    ),
)
for (relative_path, name) in INDEPENDENT_SCHEMA_CONSTANTS
    source = read(joinpath(ROOT, relative_path), String)
    occursin(name * " = \"1.0\"", source) ||
        error("independent storage schema is not 1.0: $(name) in $(relative_path)")
end

# Parse literal Band header declarations so spacing changes do not weaken or break
# the version gate. Reader behavior and shared-header use are tested separately.
band_source = read(
    joinpath(ROOT, "ext", "WannierNLQGSymmetryFoundationExt", "BandRepresentationPersistence.jl"),
    String,
)
band_declarations = Dict{Symbol, Any}()
for statement in Meta.parseall(band_source).args
    if statement isa Expr && statement.head == :const
        assignment = only(statement.args)
        if assignment isa Expr && assignment.head == :(=) && assignment.args[1] isa Symbol
            band_declarations[assignment.args[1]] = assignment.args[2]
        end
    end
end
get(band_declarations, :BAND_REPRESENTATION_SCHEMA, nothing) == "WannierNLQG.band_representation" ||
    error("Band storage schema name changed")
readable_band_versions =
    get(band_declarations, :BAND_REPRESENTATION_READABLE_SCHEMA_VERSIONS, nothing)
readable_band_versions isa Expr &&
readable_band_versions.head == :tuple &&
readable_band_versions.args == ["1.0"] || error("Band readers must accept only wire schema 1.0")
isfile(joinpath(ROOT, "test", "band_public_schema_unit.jl")) &&
occursin("\"band_public_schema_unit.jl\"", read(joinpath(ROOT, "test", "runtests.jl"), String)) ||
    error("Band public-schema rejection regression is missing or unregistered")

# URI-style file identifiers and literal writer fields have no version constant.
const INDEPENDENT_SCHEMA_MARKERS = (
    (
        "ext/WannierNLQGSymmetrizationExt/ResponseSymmetryArtifactWriter.jl",
        "RESPONSE_SYMMETRY_ARTIFACT_SCHEMA = \"wanniernlqg.response-symmetry/1.0\"",
    ),
    (
        "src/Runtime/ResponseSymmetryRuntime.jl",
        "\"schema\" => \"wanniernlqg.response-symmetry-summary/1.0\"",
    ),
    (
        "ext/WannierNLQGSymmetrizationExt/ResponseSymmetryQualification.jl",
        "RESPONSE_W90_QUALIFICATION_SCHEMA = \"wanniernlqg.response-symmetry-qualification/1.0\"",
    ),
    (
        "ext/WannierNLQGSymmetrizationExt/components/persistence/OperatorPersistence.jl",
        "\"schema_version\" => \"1.0\"",
    ),
    (
        "ext/WannierNLQGSymmetrizationExt/components/persistence/GaugeAwarePersistence.jl",
        "\"schema_version\" => \"1.0\"",
    ),
    (
        "ext/WannierNLQGSymmetryFoundationExt/BandRepresentationPersistence.jl",
        "\"schema_version\" => \"1.0\"",
    ),
    (
        "ext/WannierNLQGWannierizationExt/BandRepresentationBuilder.jl",
        "attributes[\"schema_version\"] = \"1.0\"",
    ),
    (
        "ext/WannierNLQGWannierizationExt/WannierizationWorkflow.jl",
        "attributes[\"schema_version\"] = \"1.0\"",
    ),
    ("src/Runtime/Execution/KPathDriver.jl", "schema_version = \"1.0\""),
    ("scripts/visualization/model_lattice_probe.jl", "\"schema_version\" => \"1.0\""),
    ("scripts/visualization/common.py", "\"schema_version\": \"1.0\""),
)
for (relative_path, marker) in INDEPENDENT_SCHEMA_MARKERS
    occursin(marker, read(joinpath(ROOT, relative_path), String)) ||
        error("independent storage schema marker changed in $(relative_path): $(marker)")
end

# These are evidence/qualification domains, not independent writer versions.
const RETAINED_INTERNAL_SCHEMA_MARKERS = (
    (
        "ext/WannierNLQGWannierizationExt/OperatorProfileAssembly.jl",
        "OPERATOR_QUALIFICATION_SCHEMA_VERSION = \"1.2\"",
    ),
    (
        "src/Wannierization/models/DiagnosticsQualification.jl",
        "TB_SYMMETRY_QUALIFICATION_SCHEMA_VERSION = \"1.7\"",
    ),
    ("scripts/EvidenceHashing.jl", "EVIDENCE_HASH_SCHEMA_VERSION = \"2.1\""),
    (
        "ext/WannierNLQGWannierizationExt/ProjectionRepresentationSearchHDF5.jl",
        "WannierNLQG.projection_search_hdf5_mirror/2.1",
    ),
    (
        "ext/WannierNLQGOperatorBundleExt/WannierNLQGOperatorBundleExt.jl",
        "[\"minimum_reader_schema\"] = \"6.2\"",
    ),
)
for (relative_path, marker) in RETAINED_INTERNAL_SCHEMA_MARKERS
    occursin(marker, read(joinpath(ROOT, relative_path), String)) ||
        error("retained internal schema identity changed in $(relative_path): $(marker)")
end
isfile(joinpath(ROOT, "docs", "STORAGE_SCHEMAS.md")) ||
    error("independent/internal storage schema inventory is missing")

bundle_extension = read(
    joinpath(ROOT, "ext", "WannierNLQGOperatorBundleExt", "WannierNLQGOperatorBundleExt.jl"),
    String,
)
occursin("string(Base.pkgversion(WannierNLQG))", bundle_extension) ||
    error("Packed writer software provenance is not bound to package version")
for identity in ("1.0.0", "2.4.0", "2.3.0", "2.1.0", "2.0.0")
    occursin(identity, bundle_extension) ||
        error("Packed reader compatibility identity is missing: $(identity)")
end

superseded_version = join(("3", "0", "0"), '.')
for (directory, directories, files) in walkdir(ROOT)
    filter!(name -> name != ".git", directories)
    for name in files
        path = joinpath(directory, name)
        lowercase(splitext(path)[2]) in (".jl", ".md", ".toml", ".cff", ".yml", ".yaml") || continue
        occursin(superseded_version, read(path, String)) && error(
            "superseded public version $(superseded_version) remains in $(relpath(path, ROOT))",
        )
    end
end

println(
    "version consistency passed: software=1.0.0 independent_storage=1.0 internal_contracts=preserved " *
    "internal_predecessor=2.4.0",
)
