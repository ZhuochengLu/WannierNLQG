# Only concrete scientific records are rendered; qualification management stays out of reports.
const MODEL_REPORT_SKIP_KEYS = Set((
    "iteration_observer",
    "production_eligible",
    "physics_qualification",
    "tb_usability",
    "model_qualification",
    "model_availability",
    "qualification",
    "overall",
    "payload_sha256",
))

# JSON has no nonfinite numbers; missing mathematical values remain null, never fabricated zeros.
function _model_report_value(value)
    value===nothing && return nothing
    value isa Bool && return value
    value isa Integer && return value
    value isa AbstractFloat &&
        return isnan(value) ? nothing : isinf(value) ? (value>0 ? "Infinity" : "-Infinity") : value
    value isa Complex && return Dict(
        "real"=>_model_report_value(real(value)),
        "imag"=>_model_report_value(imag(value)),
    )
    value isa Symbol && return String(value)
    value isa Enum && return string(value)
    value isa AbstractString && return _model_warning_text(value)
    value isa Function && return nothing
    value isa AbstractMatrix &&
        return [[_model_report_value(value[i, j]) for j in axes(value, 2)] for i in axes(value, 1)]
    value isa Union{AbstractArray, Tuple} && return [_model_report_value(v) for v in value]
    if value isa AbstractDict
        return Dict(
            string(k)=>_model_report_value(v) for (k, v) in value if _model_report_key(string(k))
        )
    end
    return Dict(
        String(k)=>_model_report_value(getfield(value, k)) for
        k in fieldnames(typeof(value)) if _model_report_key(String(k))
    )
end

# Exclude evidence identities and permission labels while retaining mathematical definitions.
function _model_report_key(key)
    key in MODEL_REPORT_SKIP_KEYS && return false
    any(
        token->occursin(token, key),
        (
            "_sha256",
            "publication_identity",
            "qualification",
            "eligibility",
            "_usability",
            "_classification",
            "gate_records",
            "production_eligible",
            "quality_review_",
            "content_authentication",
            "acceptance_json",
        ),
    ) && return false
    return true
end

# Preserve a concrete reason when available; never turn an old label into a passing result.
function _model_warning_text(text)
    value=String(text)
    for label in ("PHYSICS_HOLD", "DIAGNOSTIC_ONLY", "CONTROLLED_SYMMETRIZATION_HOLD")
        value=replace(value, label=>"a recorded scientific limitation")
    end
    return value
end

# Wrap rendered text at a fixed readable width without changing values in JSON.
function _model_write_text(io, text; indent = "  ", width = 104)
    line=indent
    room=width-textwidth(indent)
    room>=2 || throw(ArgumentError("report text width leaves no room after indentation"))
    for word in split(String(text))
        pieces=String[]
        chunk=IOBuffer()
        used=0
        for character in word
            character_width=textwidth(string(character))
            if used+character_width>room && position(chunk)>0
                push!(pieces, String(take!(chunk)))
                used=0
            end
            print(chunk, character)
            used+=character_width
        end
        push!(pieces, String(take!(chunk)))
        for piece in pieces
            if textwidth(line)+textwidth(piece)+(line==indent ? 0 : 1)>width
                println(io, line);
                line=indent
            end
            line *= (line==indent ? "" : " ")*piece
        end
    end
    line==indent || println(io, line)
end

# Keep parameter labels aligned; long values continue on the next indented line.
function _write_model_report_field(io, name, value)
    key=String(name)
    label="  "*rpad(key, 34)*" : "
    text=_report_value(value)
    if textwidth(key)>34
        _model_write_text(io, key*" :")
        _model_write_text(io, text; indent = "    ")
    elseif textwidth(label)+textwidth(text)<=104
        println(io, label, text)
    else
        println(io, rstrip(label));
        _model_write_text(io, text; indent = "    ")
    end
end

# Translate the recorded failed-metric reason for display; JSON retains the original code.
function _model_tb_display_reason(reason)
    startswith(reason, "FAILED_METRICS:") || return reason
    names=filter(!isempty, split(reason[(length("FAILED_METRICS:") + 1):end], ','))
    return "$(length(names)) symmetry checks exceed their limits; marked FAIL below."
end

# Summarize checks and repeated messages without mutating the complete structured report.
function _write_model_validation_summary(io, report, json_file)
    validation=report["validation"]
    checks=validation["checks"]
    counts=Dict{String, Int}()
    groups=Dict{Tuple{String, String}, Int}()
    for check in checks
        status=String(check["result"])
        counts[status]=get(counts, status, 0)+1
        status=="PASS" && continue
        key=(String(check["name"]), status)
        groups[key]=get(groups, key, 0)+1
    end
    order=filter(status->haskey(counts, status), ["PASS", "FAIL", "NOT_AVAILABLE"])
    append!(order, sort!(setdiff(collect(keys(counts)), order)))
    summary=isempty(order) ? "No checks recorded" :
            join(["$(counts[status]) $status" for status in order], "; ")
    _write_model_report_field(io, "checks", summary)
    for ((name, status), count) in sort!(collect(groups); by = first)
        _model_write_text(
            io,
            "$status ($count): "*replace(
                titlecase(replace(name, '_'=>' ')),
                "Paw"=>"PAW",
                "Tb"=>"TB",
            ),
        )
    end
    for (kind, key) in (("WARNING", "warnings"), ("ERROR", "errors"))
        items=validation[key]
        _write_model_report_field(io, key, length(items))
        messages=Dict{Tuple{String, String}, Int}()
        details=Dict{Tuple{String, String}, Vector{String}}()
        sequence=Tuple{String, String}[]
        for item in items
            group=(String(item["code"]), String(item["message"]))
            haskey(messages, group) || push!(sequence, group)
            messages[group]=get(messages, group, 0)+1
            context=get(item, "context", nothing)
            if context isa AbstractDict && haskey(context, "detail")
                detail=first(split(String(context["detail"]), '\n'))
                retained=get!(details, group, String[])
                detail in retained || push!(retained, detail)
            end
        end
        for group in sequence
            _, message=group
            _model_write_text(io, "$kind ($(messages[group])): "*message)
            for detail in get(details, group, String[])
                _model_write_text(io, "Cause: "*detail; indent = "    ")
            end
        end
    end
    _write_model_report_field(
        io,
        "details",
        json_file===nothing ? "No JSON file requested for this output stream." :
        basename(json_file)*" -> validation (full check values and message contexts)",
    )
    return nothing
end

# Build one end snapshot from existing solver state without reading matrices back from disk.
function _wannier_model_report(
    result,
    config;
    wall_time,
    allocated_bytes,
    gc_time,
    peak_rss_bytes,
    run_record = nothing,
)
    optimizer=result.restart_state===nothing ? nothing : result.restart_state.optimizer_state
    optimizer_history=Dict{String, Any}()
    if optimizer!==nothing
        for name in fieldnames(typeof(optimizer))
            key=String(name)
            if occursin("history", key) ||
               startswith(key, "localization_trial_") ||
               key in (
                   "z_steps",
                   "u_steps",
                   "z_stability_count",
                   "u_stability_count",
                   "last_cg_restart_reason",
                   "u_cg_restart_count",
               )
                optimizer_history[key]=_model_report_value(getfield(optimizer, name))
            end
        end
    end
    warnings=Dict{String, Any}[];
    errors=Dict{String, Any}[]
    for d in result.diagnostics
        d.severity in (:warning, :error) || continue
        record=Dict(
            "code"=>_model_warning_text(String(d.code)),
            "message"=>_model_warning_text(d.message),
            "context"=>_model_report_value(d.context),
        )
        push!(d.severity==:error ? errors : warnings, record)
    end
    if result.status==MAX_ITERATIONS && !any(w->occursin("MAX_ITER", w["code"]), warnings)
        push!(
            warnings,
            Dict(
                "code"=>"MAX_ITERATIONS_REACHED",
                "message"=>"The solver reached its accepted-step limit without convergence.",
            ),
        )
    end
    checks=Dict{String, Any}[]
    raw=get(result.input_summary, "construction_gate_records_json", "")
    if !isempty(raw)
        for record in JSON3.read(raw, Vector{Dict{String, Any}})
            context=get(record, "context", Dict{String, Any}())
            haskey(context, "value") && haskey(context, "threshold") || continue
            push!(
                checks,
                Dict(
                    "name"=>record["code"],
                    "value"=>context["value"],
                    "threshold"=>context["threshold"],
                    "result"=>get(context, "gate_result", "NOT_CHECKED"),
                ),
            )
        end
    end
    q=result.tb_symmetry_qualification
    requested=config.output.final_tb_symmetry_report_enabled===true
    tb=Dict{String, Any}(
        "requested"=>requested,
        "performed"=>requested && any(m->m.value!==nothing, q.metrics),
        "complete"=>requested &&
                    !isempty(q.metrics) &&
                    all(m->m.status in ("PASS", "FAIL"), q.metrics),
        "scope"=>q.qualification_scope,
        "operation_count"=>tryparse(
            Int,
            get(result.input_summary, "final_tb_checked_operation_count", ""),
        ),
        "reason"=>_model_warning_text(q.reason),
        "metrics"=>requested ? [_model_report_value(m) for m in q.metrics] : Any[],
    )
    final=Dict{String, Any}(
        "solver_status"=>string(result.status),
        "execution_succeeded"=>isempty(errors),
        "converged"=>result.status in (COMPLETED, COMPLETED_WITH_WARNINGS),
        "centers_cartesian_angstrom"=>_model_report_value(result.wannier_centers_cartesian),
        "spreads_angstrom2"=>_model_report_value(result.spreads_angstrom2),
        "accepted_iterations"=>length(result.history),
        "sum_spreads_angstrom2"=>sum(result.spreads_angstrom2),
        "mean_spread_angstrom2"=>isempty(result.spreads_angstrom2) ? nothing :
                                 sum(result.spreads_angstrom2)/length(result.spreads_angstrom2),
        "minimum_spread_angstrom2"=>isempty(result.spreads_angstrom2) ? nothing :
                                    minimum(result.spreads_angstrom2),
        "maximum_spread_angstrom2"=>isempty(result.spreads_angstrom2) ? nothing :
                                    maximum(result.spreads_angstrom2),
        "stopping_reason"=>checkpoint_stopping_reason(result),
    )
    if !isempty(result.history)
        last=result.history[end]
        final["omega_total_angstrom2"]=last.spread_total
        final["convergence_metric_angstrom2"]=last.spread_standard_deviation
        if last.diagnostics!==nothing
            final["omega_i_angstrom2"]=last.diagnostics.omega_i
            final["omega_tilde_angstrom2"]=last.spread_total-last.diagnostics.omega_i
        end
    end
    return Dict{String, Any}(
        "schema"=>"wanniernlqg.model-report",
        "schema_version"=>"1.0",
        "value_encoding"=>Dict(
            "missing"=>"null",
            "unbounded_limits"=>"Infinity or -Infinity strings",
            "complex"=>"real/imag objects",
        ),
        "software"=>Dict("name"=>"WannierNLQG", "version"=>string(Base.pkgversion(WannierNLQG))),
        "units"=>Dict("energy"=>"eV", "length"=>"Angstrom", "spread"=>"Angstrom^2", "time"=>"s"),
        "input"=>_model_report_value(result.input_summary),
        "solver_configuration"=>_model_report_value(config.solver),
        "input_record"=>_model_report_value(run_record),
        "history"=>_model_report_value(result.history),
        "optimizer_history"=>optimizer_history,
        "initialization"=>_model_report_value(result.initialization_report),
        "final"=>final,
        "timing"=>Dict(
            "workflow_try_seconds"=>wall_time,
            "gc_seconds_included"=>gc_time,
            "allocated_bytes"=>allocated_bytes,
            "process_peak_rss_bytes"=>peak_rss_bytes,
            "scope"=>"Preparation and solver try-block; terminal export/report excluded. RSS is process-wide.",
        ),
        "validation"=>Dict(
            "checks"=>checks,
            "warnings"=>warnings,
            "errors"=>errors,
            "tb_symmetry"=>tb,
        ),
    )
end

# Write the one structured report atomically after the human log is already flushed.
function _write_model_json(path, report)
    mkpath(dirname(path));
    temporary, io=mktemp(dirname(path))
    try
        JSON3.pretty(io, report);
        write(io, '\n');
        flush(io);
        close(io)
        IO.atomic_file_replace(temporary, path)
    finally
        isopen(io) && close(io)
        isfile(temporary) && rm(temporary)
    end
    return path
end

# Reuse the original log lifetime and input fields; no report-only matrix calculations occur here.
function _open_wannierization_log(
    path,
    config::WannierizationConfig,
    representation;
    compatibility,
    restart::Bool,
)
    mkpath(dirname(path));
    io=open(path, restart ? "a" : "w")
    println(
        io,
        repeat('=', 104),
        "\n WannierNLQG WANNIERIZATION\n",
        repeat('=', 104),
        "\n\n[INPUT]",
    )
    for (key, value) in (
        ("wanniernlqg_version", Base.pkgversion(WannierNLQG)),
        ("execution_mode", restart ? "restart" : "fresh"),
        ("mode", effective_wannierization_mode(config)),
        ("source_code", representation.source_code),
        ("symmetry_constraints_applied", symmetry_constraints_applied(config, representation)),
        ("input_symmetry_operations", length(representation.operations)),
        ("spinor", representation.spinor),
        ("kpoint_mesh", join(representation.mp_grid, " x ")),
        ("num_kpoints", size(representation.energies_ev, 2)),
        ("num_input_bands", size(representation.energies_ev, 1)),
        ("num_wannier", config.input.num_wannier),
        ("outer_window_ev", (config.input.outer_min_ev, config.input.outer_max_ev)),
        ("frozen_window_ev", (config.input.frozen_min_ev, config.input.frozen_max_ev)),
        ("energy_unit", "eV"),
        ("length_unit", "Angstrom"),
        ("spread_unit", "Angstrom^2"),
    )
        _write_model_report_field(io, key, value)
    end
    println(io, "\n[SOLVER CONFIGURATION]")
    for (key, value) in (
        ("initialization", config.solver.initialization),
        ("parallel", config.solver.parallel),
        ("random_seed", config.solver.random_seed),
        ("z_mix_ratio", config.solver.z_mix_ratio),
        ("u_mix_ratio", config.solver.u_mix_ratio),
    )
        _write_model_report_field(io, key, value)
    end
    for name in fieldnames(typeof(config.solver.stage_controls))
        _write_model_report_field(io, String(name), getfield(config.solver.stage_controls, name))
    end
    println(
        io,
        "\n[PROGRESS]\n  Iter and Step count accepted global/stage steps. Omega values use Angstrom^2.\n  First Z relative change has no preceding objective. Elapsed time is cumulative seconds.",
    )
    flush(io);
    return io
end

# Render only fields defined for the actual accepted stage; elapsed time comes from the existing snapshot.
function _write_wannierization_progress(
    io,
    snapshot,
    checkpoint_path,
    config::WannierizationConfig,
    representation = nothing;
    heading = nothing,
)
    stage=Symbol(snapshot.completed_stage)==:disentanglement ? :disentanglement : :localization
    step=stage==:disentanglement ? snapshot.z_steps : snapshot.u_steps
    if heading!==nothing
        println(io, "\n[", uppercase(String(stage)), "]")
        stage==:disentanglement ?
        @printf(
            io,
            "%8s %8s %20s %16s %12s\n",
            "Iter",
            "Step",
            "Omega_I (A^2)",
            "Z rel.change",
            "Elapsed (s)"
        ) :
        @printf(
            io,
            "%8s %8s %20s %20s %16s %12s\n",
            "Iter",
            "Step",
            "Omega_I (A^2)",
            "Omega (A^2)",
            "U conv.metric",
            "Elapsed (s)"
        )
    end
    if stage==:disentanglement
        delta=isfinite(snapshot.delta_omega_i) ? @sprintf("%.6e", snapshot.delta_omega_i) : "-"
        @printf(
            io,
            "%8d %8d %20.10e %16s %12.6f\n",
            snapshot.iteration,
            step,
            snapshot.omega_i,
            delta,
            snapshot.elapsed_seconds
        )
    else
        @printf(
            io,
            "%8d %8d %20.10e %20.10e %16.6e %12.6f\n",
            snapshot.iteration,
            step,
            snapshot.omega_i,
            snapshot.spread_total,
            snapshot.convergence_metric,
            snapshot.elapsed_seconds
        )
    end
    if config.runtime.detailed_progress
        for name in (
            :projector_residual,
            :z_residual,
            :u_residual,
            :projected_gradient_rms,
            :accepted_u_step_scale,
            :fixed_projector_drift,
        )
            hasproperty(snapshot, name) || continue
            value=getproperty(snapshot, name)
            value isa Real && isfinite(value) && _write_model_report_field(io, String(name), value)
        end
    end
    flush(io);
    return nothing
end

# Render the same final values/warnings which are serialized in the single model JSON.
function _write_wannierization_final(
    io,
    result,
    config::WannierizationConfig,
    artifacts;
    wall_time,
    allocated_bytes,
    gc_time,
    peak_rss_bytes = Sys.maxrss(),
    run_record = nothing,
)
    report=_wannier_model_report(
        result,
        config;
        wall_time,
        allocated_bytes,
        gc_time,
        peak_rss_bytes,
        run_record,
    )
    println(io, "\n[FINAL CENTERS AND SPREADS]")
    @printf(
        io,
        "%5s %20s %20s %20s %20s\n",
        "WF",
        "Center x (A)",
        "Center y (A)",
        "Center z (A)",
        "Spread (A^2)"
    )
    for orbital in eachindex(result.spreads_angstrom2)
        @printf(
            io,
            "%5d %20.12e %20.12e %20.12e %20.12e\n",
            orbital,
            result.wannier_centers_cartesian[orbital, 1],
            result.wannier_centers_cartesian[orbital, 2],
            result.wannier_centers_cartesian[orbital, 3],
            result.spreads_angstrom2[orbital]
        )
    end
    println(io, "\n[FINAL STATUS AND TIMING]")
    for (key, value) in sort!(collect(report["final"]); by = first)
        value isa Union{AbstractArray, AbstractDict} || _write_model_report_field(io, key, value)
    end
    for (key, value) in sort!(collect(report["timing"]); by = first)
        _write_model_report_field(io, key, value)
    end
    if config.output.final_tb_symmetry_report_enabled===true
        println(io, "\n[TB SYMMETRY]")
        tb=report["validation"]["tb_symmetry"]
        for key in ("performed", "complete", "scope", "reason")
            ;
            _write_model_report_field(
                io,
                key,
                key=="reason" ? _model_tb_display_reason(tb[key]) : tb[key],
            );
        end
        tb["operation_count"]===nothing ||
            _write_model_report_field(io, "operation_count", tb["operation_count"])
        _write_tb_report(io, result.tb_symmetry_qualification; compact = true)
    end
    println(io, "\n[VALIDATION]")
    json_file=artifacts.wannierization_log===nothing ? nothing :
              artifacts.wannierization_log[1:(end - 4)]*".json"
    _write_model_validation_summary(io, report, json_file)
    flush(io)
    artifacts.wannierization_log===nothing ||
        _write_model_json(artifacts.wannierization_log[1:(end - 4)]*".json", report)
    return nothing
end
