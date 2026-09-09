using JSON3

const CI_WORKFLOW = joinpath(ROOT, ".github", "workflows", "ci.yml")
const TAG_GATE_WORKFLOW = joinpath(ROOT, ".github", "workflows", "tag-release-gate.yml")
const TAG_GATE_SCRIPT = joinpath(ROOT, "scripts", "check_tag_ci_reuse.py")
const CI_TEST_SHA = repeat("a", 40)

function ci_fixture_run(; sha = CI_TEST_SHA, status = "completed", conclusion = "success")
    return Dict(
        "id" => 101,
        "head_sha" => sha,
        "head_branch" => "main",
        "event" => "push",
        "status" => status,
        "conclusion" => conclusion,
        "created_at" => "2026-09-09T00:00:00Z",
    )
end

function ci_fixture_jobs(; replacement = nothing, drop = nothing, extra = nothing)
    jobs = [
        Dict("name" => name, "status" => "completed", "conclusion" => "success") for
        name in CITestPlan.CI_REQUIRED_JOB_NAMES
    ]
    drop === nothing || filter!(job -> job["name"] != drop, jobs)
    if replacement !== nothing
        name, status, conclusion = replacement
        job = only(filter(job -> job["name"] == name, jobs))
        job["status"] = status
        job["conclusion"] = conclusion
    end
    extra === nothing ||
        push!(jobs, Dict("name" => extra, "status" => "completed", "conclusion" => "success"))
    return Dict("jobs" => jobs)
end

function tag_gate_succeeds(runs, jobs; sha = CI_TEST_SHA, current_run_id = 999)
    mktempdir() do directory
        runs_path = joinpath(directory, "runs.json")
        jobs_path = joinpath(directory, "jobs.json")
        write(runs_path, JSON3.write(Dict("workflow_runs" => runs)))
        write(jobs_path, JSON3.write(jobs))
        command =
            `python3 $(TAG_GATE_SCRIPT) --repository example/WannierNLQG --sha $(sha) --workflow ci.yml --current-run-id $(current_run_id) --runs-json $(runs_path) --jobs-json $(jobs_path)`
        return success(
            Base.run(pipeline(ignorestatus(command); stdout = devnull, stderr = devnull)),
        )
    end
end

@testset "CI mode parser is explicit and fail-closed" begin
    fast = CITestPlan.resolve_test_selection(Dict{String, String}())
    @test fast.mode == "fast"
    @test isnothing(fast.shard)

    full = CITestPlan.resolve_test_selection(
        Dict("WANNIERNLQG_TEST_MODE" => "full-shard", "WANNIERNLQG_TEST_SHARD" => "wannier-core"),
    )
    @test full.mode == "full-shard"
    @test full.shard == "wannier-core"

    mpi = CITestPlan.resolve_test_selection(Dict("WANNIERNLQG_TEST_MODE" => "mpi-only"))
    @test mpi.mode == "mpi-only"
    @test isnothing(mpi.shard)

    @test_throws ErrorException CITestPlan.resolve_test_selection(
        Dict("WANNIERNLQG_TEST_MODE" => "unknown"),
    )
    @test_throws ErrorException CITestPlan.resolve_test_selection(
        Dict("WANNIERNLQG_TEST_MODE" => "full-shard"),
    )
    @test_throws ErrorException CITestPlan.resolve_test_selection(
        Dict("WANNIERNLQG_TEST_MODE" => "full-shard", "WANNIERNLQG_TEST_SHARD" => "unknown"),
    )
    @test_throws ErrorException CITestPlan.resolve_test_selection(
        Dict("WANNIERNLQG_TEST_MODE" => "fast", "WANNIERNLQG_TEST_SHARD" => "wannier-core"),
    )
    @test_throws ErrorException CITestPlan.resolve_test_selection(
        Dict("WANNIERNLQG_TEST_MODE" => "mpi-only", "WANNIERNLQG_TEST_SHARD" => "wannier-core"),
    )
    @test_throws ErrorException CITestPlan.resolve_test_selection(
        Dict("WANNIERNLQG_TEST_LEVEL" => "full"),
    )
    @test_throws ErrorException CITestPlan.resolve_test_selection(
        Dict("WANNIERNLQG_TEST_MPI" => "1"),
    )
end

@testset "Full shards and MPI-only retain the frozen scientific inventories" begin
    @test CITestPlan.validate_ci_test_plan()
    shard_sets = [Set(CITestPlan.full_shard_files(name)) for name in CITestPlan.full_shard_names()]
    @test reduce(union, shard_sets) == Set(CITestPlan.FULL_ONLY_TEST_FILES)
    for left in eachindex(shard_sets), right in (left + 1):length(shard_sets)
        @test isempty(intersect(shard_sets[left], shard_sets[right]))
    end
    @test length(CITestPlan.MPI_GATE_NAMES) == 3
    @test length(CITestPlan.MPI_TEST_FILES) == 6
    @test intersect(Set(CITestPlan.MPI_TEST_FILES), Set(CITestPlan.FAST_TEST_FILES)) ==
          Set(["band_structure_unit.jl"])
    @test intersect(Set(CITestPlan.MPI_TEST_FILES), Set(CITestPlan.FULL_ONLY_TEST_FILES)) ==
          Set(["per_task_parallel_unit.jl"])
    @test Set(CITestPlan.full_shard_auxiliary_files("scientific-contracts")) ==
          Set(["band_structure_unit.jl", "mpi_runtime_compiled_modules_full_unit.jl"])
end

@testset "branch, PR, manual, and tag workflows have distinct contracts" begin
    ci = read(CI_WORKFLOW, String)
    tag = read(TAG_GATE_WORKFLOW, String)
    @test occursin("pull_request:", ci)
    @test occursin("workflow_dispatch:", ci)
    @test occursin("branches:", ci)
    @test !occursin("tags:", ci)
    @test occursin("cancel-in-progress: \${{ github.event_name != 'workflow_dispatch' }}", ci)
    @test occursin("WANNIERNLQG_TEST_MODE: fast", ci)
    @test occursin("WANNIERNLQG_TEST_MODE: full-shard", ci)
    @test occursin("WANNIERNLQG_TEST_MODE: mpi-only", ci)
    @test !occursin("WANNIERNLQG_TEST_LEVEL", ci)
    @test !occursin("WANNIERNLQG_TEST_MPI", ci)
    for shard in CITestPlan.full_shard_names()
        @test occursin("- $(shard)", ci)
    end

    @test occursin("tags:", tag)
    @test !occursin("pull_request:", tag)
    @test occursin("actions: read", tag)
    @test occursin("contents: read", tag)
    @test occursin("cancel-in-progress: false", tag)
    @test occursin("check_tag_ci_reuse.py", tag)
end

@testset "tag CI reuse accepts only an exact completed-success main run" begin
    valid_run = ci_fixture_run()
    valid_jobs = ci_fixture_jobs()
    @test tag_gate_succeeds([valid_run], valid_jobs)

    @test !tag_gate_succeeds([ci_fixture_run(; sha = repeat("b", 40))], valid_jobs)
    @test !tag_gate_succeeds(
        [ci_fixture_run(; status = "completed", conclusion = "cancelled")],
        valid_jobs,
    )
    @test !tag_gate_succeeds(
        [valid_run],
        ci_fixture_jobs(; replacement = ("mpi-only", "completed", "cancelled")),
    )
    @test !tag_gate_succeeds(
        [valid_run],
        ci_fixture_jobs(; replacement = ("mpi-only", "completed", "skipped")),
    )
    @test !tag_gate_succeeds(
        [valid_run],
        ci_fixture_jobs(; replacement = ("mpi-only", "completed", "neutral")),
    )
    @test !tag_gate_succeeds([valid_run], ci_fixture_jobs(; drop = "mpi-only"))
    @test !tag_gate_succeeds([valid_run], ci_fixture_jobs(; extra = "unexpected"))
    @test !tag_gate_succeeds([valid_run], valid_jobs; current_run_id = 101)
end
