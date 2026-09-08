include(joinpath(SCRIPT_DIR, "EvidenceHashing.jl"))
import .EvidenceHashing
include(joinpath(SCRIPT_DIR, "SourceDocumentationAudit.jl"))
import .SourceDocumentationAudit

function evidence_fixture(root)
    files = Dict(
        "src/Runtime.jl" => "runtime\n",
        "ext/ExampleExt.jl" => "extension\n",
        "Project.toml" => "name = \"Fixture\"\n",
        "Manifest.toml" => "julia_version = \"1.10\"\n",
        "test/runtests.jl" => "using Test\n",
        "scripts/ValidationPolicy.jl" => "# shared policy\n",
        "scripts/FormatterPaths.jl" => "# formatter\n",
        "scripts/SourceDocumentationAudit.jl" => "# documentation audit\n",
        "scripts/check_format.jl" => "# format gate\n",
        "scripts/check_structure_boundaries.jl" => "# test gate\n",
        "scripts/check_documentation.jl" => "# documentation gate\n",
        "scripts/render_report.py" => "# campaign-only report tool\n",
        "docs/DEVELOPMENT.md" => "development contract\n",
        "examples/example.jl" => "# example\n",
        "AGENTS.md" => "repository rules\n",
        "README.md" => "readme\n",
        "USER_GUIDE.md" => "guide\n",
    )
    for (relative, contents) in files
        path = joinpath(root, relative)
        mkpath(dirname(path))
        write(path, contents)
    end
    return root
end

@testset "documentation audit recognizes kwdef type headers" begin
    mktempdir() do directory
        documented = joinpath(directory, "Documented.jl")
        write(
            documented,
            """
            \"\"\"
            A documented keyword-default configuration.
            \"\"\"
            Base.@kwdef struct DocumentedConfig
                value::Int = 1
            end
            """,
        )
        audit = SourceDocumentationAudit.audit_source_documentation(directory)
        @test isempty(audit.parse_failures)
        @test isempty(audit.orphan_docstrings)
        @test length(audit.declarations) == 1
        @test only(audit.declarations).name == "DocumentedConfig"
        @test only(audit.declarations).documented
    end
end

function inventory_classes(payload, relative)
    record = only(filter(item -> item["path"] == relative, payload["file_inventory"]))
    return Set(record["classes"])
end

@testset "test-contract reachable script closure" begin
    entries = Set(ValidationPolicy.test_contract_entries())
    for script in ValidationPolicy.FULL_READINESS_SCRIPTS
        @test joinpath("scripts", script) in entries
    end
    for entry in ValidationPolicy.TEST_REACHABLE_SCRIPT_ENTRIES
        @test joinpath("scripts", entry) in entries
    end
    @test !(
        joinpath("scripts", "check_symmetrization_examples.jl") in
        joinpath.("scripts", ValidationPolicy.FAST_READINESS_SCRIPTS)
    )
end

@testset "dependency-aware engineering evidence" begin
    mktempdir() do directory
        evidence_fixture(directory)
        baseline = EvidenceHashing.evidence_hash_classes(directory)
        repeated = EvidenceHashing.evidence_hash_classes(directory)
        @test baseline["schema_version"] == "2.1"
        @test baseline["evidence_summary_sha256"] == repeated["evidence_summary_sha256"]
        mkdir(joinpath(directory, ".git"))
        write(joinpath(directory, ".git", "config"), "checkout-local administration")
        checkout = EvidenceHashing.evidence_hash_classes(directory)
        @test checkout["evidence_summary_sha256"] == baseline["evidence_summary_sha256"]
        rm(joinpath(directory, ".git"); recursive = true)
        write(joinpath(directory, ".git"), "gitdir: ../worktree-administration\n")
        worktree = EvidenceHashing.evidence_hash_classes(directory)
        @test worktree["evidence_summary_sha256"] == baseline["evidence_summary_sha256"]
        rm(joinpath(directory, ".git"))
        @test inventory_classes(baseline, "src/Runtime.jl") == Set(["runtime_source"])
        @test inventory_classes(baseline, "test/runtests.jl") == Set(["test_contract"])
        @test inventory_classes(baseline, "scripts/check_structure_boundaries.jl") ==
              Set(["campaign_tools", "test_contract"])
        @test inventory_classes(baseline, "scripts/render_report.py") == Set(["campaign_tools"])

        cache = joinpath(directory, "scripts", "__pycache__", "render_report.cpython-311.pyc")
        mkpath(dirname(cache))
        write(cache, "generated cache must not alter the frozen code identity\n")
        cache_update = EvidenceHashing.evidence_hash_classes(directory)
        @test cache_update["evidence_summary_sha256"] == baseline["evidence_summary_sha256"]
        @test all(
            record -> record["path"] != relpath(cache, directory),
            cache_update["file_inventory"],
        )

        write(joinpath(directory, "scripts", "render_report.py"), "# corrected report tool\n")
        campaign_update = EvidenceHashing.evidence_hash_classes(directory)
        campaign_decision = EvidenceHashing.evidence_reuse_decision(baseline, campaign_update)
        @test campaign_decision["mode"] == "REUSE_WITH_FOCUSED_CHECKS"
        @test campaign_decision["changes"]["closed"]
        @test only(campaign_decision["changes"]["files"])["path"] == "scripts/render_report.py"

        new_tool = joinpath(directory, "scripts", "new_report.py")
        write(new_tool, "# new report tool\n")
        with_added_tool = EvidenceHashing.evidence_hash_classes(directory)
        added = EvidenceHashing.evidence_change_set(campaign_update, with_added_tool)
        @test only(added["files"])["status"] == "ADDED"
        rm(new_tool)
        after_delete = EvidenceHashing.evidence_hash_classes(directory)
        deleted = EvidenceHashing.evidence_change_set(with_added_tool, after_delete)
        @test only(deleted["files"])["status"] == "DELETED"

        write(joinpath(directory, "src", "Runtime.jl"), "runtime changed\n")
        runtime_update = EvidenceHashing.evidence_hash_classes(directory)
        runtime_decision = EvidenceHashing.evidence_reuse_decision(campaign_update, runtime_update)
        @test runtime_decision["mode"] == "RUN_FULL_ONCE"
        @test !runtime_decision["runtime_source_unchanged"]
    end

    mktempdir() do directory
        evidence_fixture(directory)
        baseline = EvidenceHashing.evidence_hash_classes(directory)
        gate = joinpath(directory, "scripts", "check_structure_boundaries.jl")
        write(gate, "# changed test gate\n")
        gate_update = EvidenceHashing.evidence_hash_classes(directory)
        decision = EvidenceHashing.evidence_reuse_decision(baseline, gate_update)
        @test decision["mode"] == "RUN_FULL_ONCE"
        @test !decision["test_contract_unchanged"]
        @test EvidenceHashing.evidence_reuse_decision(
            baseline,
            baseline;
            manifest_sealed = false,
        )["mode"] == "RUN_FULL_ONCE"
    end

    mktempdir() do directory
        evidence_fixture(directory)
        baseline = EvidenceHashing.evidence_hash_classes(directory)
        write(joinpath(directory, "UNCLASSIFIED.txt"), "must fail closed\n")
        unclassified = EvidenceHashing.evidence_hash_classes(directory)
        @test unclassified["unclassified_files"] == ["UNCLASSIFIED.txt"]
        @test EvidenceHashing.evidence_reuse_decision(baseline, unclassified)["mode"] ==
              "RUN_FULL_ONCE"
    end

    legacy = Dict(
        "schema_version" => "1.0",
        "runtime_source" => Dict("sha256" => repeat("a", 64)),
        "test_contract" => Dict("sha256" => repeat("b", 64)),
        "campaign_tools" => Dict("sha256" => repeat("c", 64)),
    )
    normalized = EvidenceHashing.normalized_hash_classes(legacy)
    @test normalized["runtime_source_sha256"] == repeat("a", 64)
    @test !EvidenceHashing.evidence_change_set(legacy, legacy)["closed"]
end
