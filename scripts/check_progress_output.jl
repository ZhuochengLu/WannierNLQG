using WannierNLQG
import WannierNLQG: run

const ROOT = normpath(joinpath(@__DIR__, ".."))
const FIXTURE_ROOT = joinpath(ROOT, "examples", "fixtures", "synthetic_runtime")
const MODEL_FILE = joinpath(FIXTURE_ROOT, "synthetic_tb.dat")
const OPERATOR_BUNDLE_FILE = joinpath(FIXTURE_ROOT, "synthetic_operators.h5")
const WSVEC_FILE = joinpath(FIXTURE_ROOT, "synthetic_wsvec.dat")

function assert_contains(path::AbstractString, needle::AbstractString)
    text = read(path, String)
    occursin(needle, text) || error("missing `$(needle)` in $(path)")
    return text
end

function assert_contains_text(text::AbstractString, needle::AbstractString, label::AbstractString)
    occursin(needle, text) || error("missing `$(needle)` in $(label)")
    return nothing
end

function metadata_has_key_value(text::AbstractString, key::AbstractString, value::AbstractString)
    for line in split(text, '\n')
        occursin("=", line) || continue
        parsed_key, parsed_value = split(line, "="; limit = 2)
        strip(parsed_key) == key && strip(parsed_value) == value && return true
    end
    return false
end

function run_capture_stdout(cfg)
    result_ref = Ref{Any}(nothing)
    stdout_path = tempname()
    try
        open(stdout_path, "w") do io
            redirect_stdout(io) do
                result_ref[] = run(cfg)
            end
        end
        return result_ref[], read(stdout_path, String)
    finally
        isfile(stdout_path) && rm(stdout_path; force = true)
    end
end

function assert_human_progress_text(text::AbstractString, label::AbstractString)
    for needle in (
        "WannierNLQG runtime report",
        "BANNER",
        "SYSTEM",
        "Reciprocal lattice vectors",
        "TASK BUNDLE",
        "NUMERICS",
        "Mesh",
        "Energy grid",
        "Smearing / screening",
        "Bands / tensor",
        "RUN CONTROLS",
        "K-LOOP",
        "progress",
        "OUTPUTS",
        "TIMING",
        "DONE",
    )
        assert_contains_text(text, needle, label)
    end
    !occursin("FAMILY COUNTS", text) ||
        error("human-readable progress should not contain FAMILY COUNTS in $(label)")
    occursin("| field", text) || error("TASK BUNDLE is not transposed in $(label)")
    occursin("| quantity", text) || error("TASK BUNDLE lacks a quantity row in $(label)")
    !occursin("| #  | quantity", text) ||
        error("TASK BUNDLE retained the retired task-per-row layout in $(label)")
    return nothing
end

function assert_serial_normal_kloop_text(text::AbstractString, label::AbstractString)
    !occursin("local       global", text) ||
        error("serial normal progress should not show local/global double columns in $(label)")
    occursin("done       progress", text) ||
        error("serial normal progress should use done/progress columns in $(label)")
    !occursin("K-slice geometry", text) ||
        error("Integral progress should not show K-slice geometry in $(label)")
    !occursin("kslice_origin", text) ||
        error("Integral progress should not show kslice_origin in $(label)")
    return nothing
end

function assert_progress_files(result, stdout_text::AbstractString)
    isfile(result.progress_out_path) || error("missing progress log: $(result.progress_out_path)")
    isfile(result.progress_jsonl_path) ||
        error("missing progress jsonl: $(result.progress_jsonl_path)")
    isfile(result.metadata_path) || error("missing metadata: $(result.metadata_path)")

    out_text = read(result.progress_out_path, String)
    assert_human_progress_text(stdout_text, "captured stdout")
    assert_human_progress_text(out_text, result.progress_out_path)

    jsonl = assert_contains(result.progress_jsonl_path, "\"event\":\"run_start\"")
    occursin("\"event\":\"system_summary\"", jsonl) ||
        error("missing system_summary event in $(result.progress_jsonl_path)")
    occursin("\"event\":\"kloop_progress\"", jsonl) ||
        error("missing kloop_progress event in $(result.progress_jsonl_path)")
    occursin("\"event\":\"run_done\"", jsonl) ||
        error("missing run_done event in $(result.progress_jsonl_path)")
    occursin("\"rate_k_per_second\"", jsonl) ||
        error("missing rate_k_per_second field in $(result.progress_jsonl_path)")
    occursin("\"stage_seconds\"", jsonl) ||
        error("missing stage_seconds field in $(result.progress_jsonl_path)")
    occursin("\"family_counts\"", jsonl) ||
        error("missing family_counts field in $(result.progress_jsonl_path)")
    for (lineno, line) in enumerate(readlines(result.progress_jsonl_path))
        startswith(line, "{") && endswith(line, "}") ||
            error("invalid JSONL-looking line $(lineno) in $(result.progress_jsonl_path): $(line)")
        occursin("\"event\":", line) ||
            error("missing event field on line $(lineno) in $(result.progress_jsonl_path)")
    end

    metadata = read(result.metadata_path, String)
    for needle in (
        "[Run]",
        "[Input]",
        "[Tasks]",
        "[Numerics]",
        "[PhotonEnergies]",
        "[Progress]",
        "[Outputs]",
        "photon_energies.values_eV",
        "progress_enabled",
    )
        occursin(needle, metadata) || error("metadata missing formatted section/key `$(needle)`")
    end
    expected_progress_out = relpath(result.progress_out_path, result.run_dir)
    expected_progress_jsonl = relpath(result.progress_jsonl_path, result.run_dir)
    metadata_has_key_value(metadata, "progress_out_path", expected_progress_out) ||
        error("metadata missing progress_out_path")
    metadata_has_key_value(metadata, "progress_jsonl_path", expected_progress_jsonl) ||
        error("metadata missing progress_jsonl_path")
    !occursin("photon_energies = [", metadata) ||
        error("metadata should not use single-line photon_energies = [...]")
    !occursin("family_counts", metadata) || error("metadata should not include human family_counts")
    return nothing
end

function base_config(
    output_root::AbstractString;
    system_name::String = "progress_check",
    progress_enabled::Bool = true,
    progress_verbosity::String = "normal",
    progress_percent_interval::Union{Nothing, Int} = 5,
)
    return WannierNLQG.Runtime.EffectiveTaskConfig(
        fourier_backend = "direct",
        tasks = [("SC", "Conventional", "Integral")],
        case_root = ROOT,
        model_file = MODEL_FILE,
        real_space_operator_bundle_file = OPERATOR_BUNDLE_FILE,
        output_root = String(output_root),
        system_name = system_name,
        k_mesh = (2, 2),
        photon_energies = collect(range(0.10, 0.80; length = 8)),
        fermi_energy = 0.0,
        temperature = 0.0,
        broadening = 0.060,
        broadening_type = "Gaussian",
        transition_window_factor = 5.0,
        denominator_regularization = 0.001,
        spatial_dimension = 2,
        band_window_size = 2,
        tensor_indices = (2, 2, 2),
        real_space_replica_policy = "minimum_distance",
        wsvec_file = WSVEC_FILE,
        mp_grid = (2, 1, 1),
        progress_enabled = progress_enabled,
        progress_percent_interval = progress_percent_interval,
        progress_verbosity = progress_verbosity,
    )
end

function check_percent_milestones()
    last_milestone = Threads.Atomic{Int}(0)
    emitted = Int[]
    for completed in 1:16
        WannierNLQG.Runtime.progress_percent_milestone_crossed!(
            last_milestone,
            completed,
            16,
            10,
        ) && push!(emitted, completed)
    end
    emitted == [2, 4, 5, 7, 8, 10, 12, 13, 15, 16] ||
        error("unexpected 10% milestone completions: $(emitted)")
    last_milestone[] == 100 || error("progress did not force the final 100% milestone")

    withenv("WANNIERNLQG_PROGRESS_PERCENT_INTERVAL" => "10") do
        cfg =
            base_config(mktempdir(); progress_enabled = false, progress_percent_interval = nothing)
        WannierNLQG.Runtime.effective_progress_percent_interval(cfg) == 10 ||
            error("new percentage environment cadence was not applied")
    end
    withenv(
        "WANNIERNLQG_PROGRESS_PERCENT_INTERVAL" => nothing,
        "WANNIERNLQG_PROGRESS_INTERVAL" => "1",
        "WANNIERNLQG_KSLICE_PROGRESS_INTERVAL" => "1",
    ) do
        cfg =
            base_config(mktempdir(); progress_enabled = false, progress_percent_interval = nothing)
        WannierNLQG.Runtime.effective_progress_percent_interval(cfg) == 5 ||
            error("retired k-point interval environments still affect response progress")
    end
    return nothing
end

function check_task_output_prefixing()
    prefixed =
        WannierNLQG.Runtime.progress_prefix_task_outputs("second", "sample_r.dat, sample_i.dat")
    prefixed == joinpath("second", "sample_r.dat") * ", " * joinpath("second", "sample_i.dat") ||
        error("TASK BUNDLE did not prefix every output path: $(prefixed)")
    return nothing
end

function check_ordered_symmetry_aggregation()
    summary(title, warning) = (
        status = "PASS",
        policy = "strict",
        kmesh_mode = "reduced",
        numerical_tensor_projection_applied = false,
        summary_file = "symmetry.json",
        human_summaries = [(title = title,)],
        symmetry_warning_count = isempty(warning) ? 0 : 1,
        symmetry_warnings = isempty(warning) ? String[] : [warning],
    )
    aggregate = WannierNLQG.Runtime.progress_aggregate_response_symmetry_summaries([
        (task_id = "first", summary = summary("Shift current", "")),
        (task_id = "second", summary = summary("Injection current", "diagnostic")),
    ])
    [item.title for item in aggregate.human_summaries] == ["TASK first — Shift current", "TASK second — Injection current"] ||
        error("per-task RESPONSE SYMMETRY ordering was not preserved")
    aggregate.symmetry_warnings == ["TASK second: diagnostic"] ||
        error("per-task RESPONSE SYMMETRY warnings lost their task identity")
    return nothing
end

function check_success_case(root::AbstractString)
    cfg = base_config(joinpath(root, "success"))
    result, stdout_text = run_capture_stdout(cfg)
    assert_progress_files(result, stdout_text)
    assert_serial_normal_kloop_text(stdout_text, "captured stdout")
    assert_serial_normal_kloop_text(
        read(result.progress_out_path, String),
        result.progress_out_path,
    )
    println("[progress-check] success out=$(result.progress_out_path)")
    println("[progress-check] success jsonl=$(result.progress_jsonl_path)")
    return nothing
end

function check_disabled_case(root::AbstractString)
    out_dir = joinpath(root, "disabled")
    cfg = base_config(out_dir; progress_enabled = false)
    result, stdout_text = run_capture_stdout(cfg)
    isempty(result.progress_out_path) ||
        error("progress_enabled = false should expose empty progress_out_path")
    isempty(result.progress_jsonl_path) ||
        error("progress_enabled = false should expose empty progress_jsonl_path")
    !isfile(joinpath(out_dir, "WannierNLQG.out")) ||
        error("progress_enabled = false wrote WannierNLQG.out")
    !isfile(joinpath(out_dir, "progress.jsonl")) ||
        error("progress_enabled = false wrote progress.jsonl")
    !occursin("K-LOOP", stdout_text) ||
        error("progress_enabled = false should suppress internal k-loop stdout")
    println("[progress-check] disabled ok")
    return nothing
end

function check_verbosity_cases(root::AbstractString)
    for verbosity in ("quiet", "normal", "diagnostic")
        cfg = base_config(joinpath(root, "verbosity_$(verbosity)"); progress_verbosity = verbosity)
        result, stdout_text = run_capture_stdout(cfg)
        assert_progress_files(result, stdout_text)
        println("[progress-check] verbosity=$(verbosity) ok")
    end
    return nothing
end

function check_failure_case(root::AbstractString)
    cfg = base_config(joinpath(root, "failure"); system_name = "bad/name")
    failed = false
    try
        run(cfg)
    catch
        failed = true
    end
    failed || error("expected bad system_name run to fail")

    failed_jsonl = joinpath(root, "failure", "progress.jsonl")
    isfile(failed_jsonl) || error("missing failed progress jsonl: $(failed_jsonl)")
    assert_contains(failed_jsonl, "\"event\":\"run_failed\"")
    println("[progress-check] failure jsonl=$(failed_jsonl)")
    return nothing
end

function main()
    root = mktempdir("/tmp"; prefix = "wanniernlqg-progress-check-", cleanup = false)
    check_percent_milestones()
    check_task_output_prefixing()
    check_ordered_symmetry_aggregation()
    check_success_case(root)
    check_disabled_case(root)
    check_verbosity_cases(root)
    check_failure_case(root)
    println("[progress-check] root=$(root)")
    println("[progress-check] ok")
end

main()
