# CLI implementation owned by Runtime so actual workload compilation can persist.
# Preserves original command parsing, printed output, errors and return codes.
function task_input_cli(arguments)
    help =
        "Usage: julia --project=PACKAGE scripts/wanniernlqg.jl " *
        "check|explain|init|run INPUT.toml [--verbose] [--records DIRECTORY]"
    isempty(arguments) && throw(ArgumentError(help))
    first(arguments) in ("-h", "--help") && (println(help); return 0)
    length(arguments) >= 2 || throw(ArgumentError(help))
    action, path = arguments[1:2]
    options = arguments[3:end]
    verbose = false
    records = nothing
    workflow = "response"
    workflow_mode = nothing
    index = 1
    while index <= length(options)
        if options[index] == "--verbose"
            verbose && throw(ArgumentError("Repeated --verbose."))
            verbose = true
        elseif options[index] in ("--workflow", "--workflow-mode")
            key = options[index]
            action == "init" || throw(ArgumentError("$key is only available for init"))
            index += 1
            index <= length(options) || throw(ArgumentError("$key requires a value"))
            key == "--workflow" ? (workflow=options[index]) : (workflow_mode=options[index])
        elseif options[index] == "--records"
            records === nothing || throw(ArgumentError("Repeated --records."))
            index += 1
            index <= length(options) || throw(ArgumentError("--records requires a directory."))
            records = options[index]
        else
            throw(ArgumentError("Unknown CLI option $(options[index])."))
        end
        index += 1
    end
    if action == "init"
        ispath(path) && throw(ArgumentError("init refuses to overwrite an existing path."))
        write_task_input_template(path; workflow, mode = workflow_mode)
        println("Created template: ", abspath(path))
        return 0
    end
    action in ("check", "explain", "run") || throw(ArgumentError(help))
    input = read_task_input(path)
    if action == "run"
        records===nothing &&
            !(
                input isa WorkflowInputResolution &&
                input.config isa Wannierization.WannierizationConfig
            ) &&
            throw(ArgumentError("this task requires --records DIRECTORY"))
        result = run_task_input(input; record_directory = records)
        if hasproperty(result, :diagnostics) && any(d->d.severity==:error, result.diagnostics)
            throw(
                ErrorException(
                    "workflow reported errors; see the scientific output and JSON validation records",
                ),
            )
        end
        if result isa RunResult
            println("Completed existing public run: ", result.run_dir)
        else
            println("Completed existing public workflow: ", typeof(result))
        end
    elseif action == "explain"
        print(explain_task_input(input; verbose))
        records === nothing || write_task_input_resolution(input, records)
    else
        println(input.metadata["status"])
        isempty(input.pending) || println("Pending: ", join(input.pending, ", "))
        records === nothing || write_task_input_resolution(input, records)
        return isempty(input.pending) ? 0 : 2
    end
    return 0
end
