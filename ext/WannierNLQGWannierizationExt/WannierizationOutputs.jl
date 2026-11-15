# Resolve the neutral, fixed sibling output names from a requested checkpoint.
function _wannierization_output_paths(config::WannierizationConfig)
    checkpoint=config.checkpoint.checkpoint_hdf5
    model=config.output.model_file
    model===nothing && checkpoint===nothing && return nothing
    if model===nothing
        endswith(checkpoint, ".wannierization.h5") ||
            throw(ArgumentError("checkpoint must end with .wannierization.h5"))
        model=checkpoint[1:(end - length(".wannierization.h5"))]*".h5"
    end
    model=abspath(model);
    endswith(model, ".h5") || throw(ArgumentError("output.model_file must end with .h5"))
    stem=model[1:(end - 3)]
    return (
        checkpoint = checkpoint,
        validated = nothing,
        log = stem*".out",
        packed = model,
        wannier = stem*"_tb.dat",
        tb_symmetry_json = nothing,
        report = stem*".json",
    )
end

# Keep the explicit checkpoint API while giving its sibling model the current filenames.
function _wannierization_output_paths(checkpoint::AbstractString)
    endswith(checkpoint, ".wannierization.h5") ||
        throw(ArgumentError("checkpoint must end with .wannierization.h5"))
    stem=abspath(checkpoint)[1:(end - length(".wannierization.h5"))]
    return (
        checkpoint = abspath(checkpoint),
        validated = nothing,
        log = stem*".out",
        packed = stem*".h5",
        wannier = stem*"_tb.dat",
        tb_symmetry_json = nothing,
        report = stem*".json",
    )
end

# Preserve the accepted Z/U stage boundary in every periodic checkpoint.  The
# observer snapshot is authoritative because it is emitted only after the
# solver has updated its stage state and qualification summary for that
# accepted iteration.  Terminal-only export gates remain fail closed.
function _periodic_stage_summary(snapshot)
    z_seal_class = String(snapshot.z_seal_class)
    optimizer_phase = Symbol(snapshot.optimizer_phase)
    summary = Dict{String, String}(
        "optimizer_phase" => String(optimizer_phase),
        "disentanglement_steps" => string(snapshot.z_steps),
        "localization_steps" => string(snapshot.u_steps),
        "disentanglement_convergence" => String(snapshot.disentanglement_convergence),
        "z_seal_class" => z_seal_class,
        "localization_convergence" => String(snapshot.localization_convergence),
        "localization_qualification" => String(snapshot.localization_qualification),
        "model_qualification" => String(snapshot.model_qualification),
        # Every periodic checkpoint is an accepted but still in-progress state.
        # A formally sealed Z subspace does not make an unfinished U state a
        # production model.
        "quality_review_recommended" => "true",
        "global_production_eligible" => "false",
    )
    # The accepted solver state already knows the initializer version.  Carry
    # that provenance into periodic checkpoints so a valid frozen-rowspace
    # restart can pass the same fail-closed check as a terminal checkpoint.
    # Callers that construct a periodic snapshot directly may predate this
    # provenance field.  Keep their checkpoint unqualified for restart rather
    # than rejecting the checkpoint construction itself.
    initializer_version =
        hasproperty(snapshot, :initializer_algorithm_version) ?
        String(snapshot.initializer_algorithm_version) : "NOT_RECORDED"
    initializer_version == "NOT_RECORDED" ||
        (summary["initializer_algorithm_version"] = initializer_version)
    # A periodic boundary has an accepted state but no terminal structural gate
    # yet, so publish the honest not-evaluated typed block.  The only evidence
    # available from the snapshot is the Z-stability seal.
    merge!(
        summary,
        wannierization_eligibility_summary(
            not_evaluated_wannierization_eligibility(z_seal_class == "CONVERGED"),
        ),
    )
    return summary
end

# Create a checkpoint view of a complete iteration boundary.
function _periodic_result(
    snapshot,
    state,
    history,
    diagnostics,
    representation,
    config::WannierizationConfig,
    persisted_input_summary::AbstractDict{String, String} = Dict{String, String}(),
)
    nb, nw, nk = size(state.frames)
    effective_algorithms = effective_wannierization_algorithms(config, representation)
    symmetry_projected_smv_fr =
        is_symmetry_projected_smv_fr(effective_algorithms.disentanglement) ||
        is_symmetry_projected_smv_fr(effective_algorithms.localization)
    chk = IO.WannierCHK(
        nb,
        nw,
        nk,
        representation.mp_grid,
        representation.kpoints_fractional,
        representation.real_lattice,
        representation.reciprocal_lattice,
        state.centers_cartesian,
        state.frames,
    )
    input_summary = Dict(
        "construction_policy" => String(config.input.construction_policy),
        "ordinary_calculation_policy_version" => "1.0",
        "quality_review_recommended" => "false",
        "quality_review_status" => "NO_REPORTED_WARNING",
        "requested_wannierization_mode" => String(config.input.wannierization_mode),
        "effective_wannierization_mode" => String(effective_wannierization_mode(config)),
        "representation_source" => String(representation_source(config)),
        "symmetry_constraints_applied" =>
            string(symmetry_constraints_applied(config, representation)),
        "algorithm_profile" => "auto",
        "effective_algorithm_profile" => String(effective_algorithms.profile),
        "symmetry_projected_smv_fr_contract" =>
            symmetry_projected_smv_fr ? SYMMETRY_PROJECTED_SMV_FR_CONTRACT : "NOT_APPLICABLE",
        "smv_fletcher_reeves_two_stage_algorithm_contract_version" =>
            SMV_FLETCHER_REEVES_TWO_STAGE_ALGORITHM_CONTRACT_VERSION,
        "smv_fletcher_reeves_two_stage_default_selection_reason" =>
            effective_algorithms.default_selection_reason,
        "smv_fletcher_reeves_two_stage_protocol" =>
            effective_algorithms.localization == :smv_fletcher_reeves_two_stage ?
            "smv-fixed-point-plus-fletcher-reeves-two-stage-v4" : "NOT_APPLICABLE",
        "disentanglement_algorithm" => String(effective_algorithms.disentanglement),
        "localization_algorithm" => String(effective_algorithms.localization),
        "z_u_stage_semantics" => "disentanglement_localization_decoupled_v1",
        "disentanglement_limit_policy" =>
            String(config.solver.acceleration.disentanglement_limit_policy),
        "covariance_applicability" =>
            symmetry_constraints_applied(config, representation) ? "APPLICABLE" : "NOT_APPLICABLE",
        "convergence_tolerance" => string(config.solver.stage_controls.conv_tol),
        "solver_status" => string(IN_PROGRESS_CHECKPOINT),
        "stopping_reason" => "PERIODIC_CHECKPOINT",
        "last_attempted_iteration" => string(state.iteration),
        "last_accepted_iteration" => string(state.iteration),
        "last_persisted_iteration" => string(state.iteration),
        "has_accepted_state" => "true",
        "legacy_terminal_semantics" => "false",
        "convergence_metric_name" => "center_spread_window_std_max",
        "convergence_metric" =>
            isempty(history) ? "Inf" : string(last(history).spread_standard_deviation),
        "spread_metric" => "full_3d",
    )
    # Preserve authority and scope already validated on the consumed representation.
    for key in (
        "authoritative_hamiltonian",
        "authoritative_hamiltonian_sha256",
        "qualification_scope",
        "target_authority",
        "parent_audit_policy",
        "auxiliary_parent_qualification",
        "target_subspace_contract_definition",
        "target_leakage_semantics",
        "target_leakage_formula_definition",
        "target_leakage_threshold",
        "wavefunction_gauge_backend",
        "wavefunction_gauge_hdf5_sha256",
    )
        haskey(representation.conventions, key) &&
            (input_summary[key] = representation.conventions[key])
    end
    for key in ("outer_mask_definition", "frozen_mask_definition")
        haskey(representation.conventions, key) &&
            (input_summary["disentanglement_" * key] = representation.conventions[key])
    end
    merge!(input_summary, _periodic_stage_summary(snapshot))
    merge!(input_summary, persisted_input_summary)
    any(d -> get(d.context, "gate_result", get(d.context, "result", "")) == "FAIL", diagnostics) &&
        (input_summary["construction_quality_failed"] = "true")
    input_summary["model_qualification"] = "COMPUTATION_READY"
    quality_failed = get(input_summary, "construction_quality_failed", "false") == "true"
    input_summary["quality_review_recommended"] = string(quality_failed)
    input_summary["quality_review_status"] = quality_failed ? "RECOMMENDED" : "NO_REPORTED_WARNING"
    return WannierizationResult(
        IN_PROGRESS_CHECKPOINT,
        state.frames,
        state.centers_cartesian,
        state.spreads_angstrom2,
        WannierizationIteration[history...],
        WannierizationDiagnostic[diagnostics...],
        input_summary,
        chk,
        nothing,
        state,
        WannierizationArtifacts(),
    )
end

# Keep the standalone Wannierization report readable without importing Runtime policy.
const _WANNIERIZATION_REPORT_RULE = repeat("=", 96)

# Render absent report values explicitly instead of silently printing `nothing`.
_report_value(value) = value === nothing ? "NOT_AVAILABLE" : string(value)

# Display paths only; never change the paths used by readers or checkpoint writers.
function _report_path(path, root)
    path === nothing && return "NOT_WRITTEN"
    isempty(string(path)) && return "NOT_WRITTEN"
    relative = relpath(abspath(path), abspath(root))
    return relative == ".." || startswith(relative, "../") ? "<external>/$(basename(path))" :
           replace(relative, '\\' => '/')
end

# Publish every original diagnostic atomically as one JSON record per line.
function _write_diagnostic_records(path, diagnostics)
    temporary, stream = mktemp(dirname(path); cleanup = false)
    try
        for (index, diagnostic) in enumerate(diagnostics)
            JSON3.write(
                stream,
                (
                    record = index,
                    severity = String(diagnostic.severity),
                    code = String(diagnostic.code),
                    message = diagnostic.message,
                    context = diagnostic.context,
                ),
            )
            println(stream)
        end
        close(stream)
        mv(temporary, path; force = true)
    finally
        isopen(stream) && close(stream)
        isfile(temporary) && rm(temporary; force = true)
    end
    return path
end

# Group presentation records by severity and code without modifying their audit payloads.
function _diagnostic_groups(diagnostics)
    groups = Dict{Tuple{Symbol, Symbol}, Vector{WannierizationDiagnostic}}()
    for diagnostic in diagnostics
        push!(
            get!(groups, (diagnostic.severity, diagnostic.code), WannierizationDiagnostic[]),
            diagnostic,
        )
    end
    return sort!(
        collect(groups);
        by = entry ->
            (findfirst(==(first(entry)[1]), (:error, :warning, :info)), String(first(entry)[2])),
    )
end

# Summarize repeated INFO records while retaining warning messages and failed gates.
function _write_diagnostic_summary(io, groups)
    for ((severity, code), records) in groups
        iterations = sort!(
            unique([
                n for d in records for
                n in (tryparse(Int, get(d.context, "iteration", "")),) if n !== nothing
            ]),
        )
        span = isempty(iterations) ? "" : ", iterations=$(first(iterations))-$(last(iterations))"
        println(io, uppercase(String(severity)), "  ", code, "  count=", length(records), span)
        important =
            severity != :info ||
            any(d -> get(d.context, "gate_result", get(d.context, "result", "")) == "FAIL", records)
        selected = important ? records : records[1:1]
        for message in unique([d.message for d in selected])
            println(io, "  ", message)
        end
        for d in records
            get(d.context, "gate_result", get(d.context, "result", "")) == "FAIL" || continue
            println(
                io,
                "  gate_result=FAIL",
                haskey(d.context, "iteration") ? " iteration=$(d.context["iteration"])" : "",
            )
        end
    end
end

const _TB_REPORT_LABELS = Dict(
    "hamiltonian_covariance_relative_max" => ("Hamiltonian", "Covariance", "1"),
    "hamiltonian_hermiticity_max_ev" => ("Hamiltonian", "Hermiticity", "eV"),
    "hamiltonian_projection_idempotence_max_ev" =>
        ("Hamiltonian", "Projection idempotence", "eV"),
    "centerless_position_covariance_relative_max" => ("Position", "Centerless covariance", "1"),
    "position_hermiticity_max_angstrom" => ("Position", "Hermiticity", "Å"),
    "centerless_position_projection_idempotence_max_angstrom" =>
        ("Position", "Projection idempotence", "Å"),
    "kstar_spectral_residual_ev" => ("Spectral", "k-star residual", "eV"),
    "wcc_symmetry_orbit_residual_angstrom" => ("Centers", "WCC orbit residual", "Å"),
)
# Limit human-readable values to three significant digits; preserve absent measurements.
_report_number(value) = value === nothing ? "N/A" : @sprintf("%.2e", value)
# Compute display ratios only when a finite positive limit is available.
_metric_ratio(metric) =
    metric.value === nothing || metric.threshold === nothing || metric.threshold == 0 ? nothing :
    metric.value / metric.threshold
# Report recorded qualification boundaries without inferring full-space eligibility.
function _write_tb_scope(io, summary; omit_unavailable::Bool = false)
    for key in (
        "qualification_scope",
        "target_anchor",
        "target_scope_production_eligible",
        "scoped_production_eligible",
        "global_production_eligible",
    )
        value = get(summary, key, "NOT_RECORDED")
        omit_unavailable && value in ("NOT_APPLICABLE", "NOT_RECORDED", "NOT_RUN") && continue
        println(io, key, " = ", value)
    end
end

# Render typed TB qualification metrics without changing their scientific status or precision.
function _write_tb_report(io, qualification; measured_only::Bool = false, compact::Bool = false)
    metrics = sort!(
        [
            metric for metric in qualification.metrics if
            !measured_only || (metric.value !== nothing && isfinite(metric.value))
        ];
        by = m -> begin
            category, label, _ = get(_TB_REPORT_LABELS, m.name, ("Other", m.name, "?"))
            (
                something(
                    findfirst(
                        ==(category),
                        ("Hamiltonian", "Position", "Spectral", "Centers", "Other"),
                    ),
                    5,
                ),
                label,
            )
        end,
    )
    if !compact
        println(
            io,
            "Result: $(qualification.overall) ($(count(m -> m.status == "PASS", metrics))/$(length(metrics)) checks PASS)",
        )
        ratios = [(something(_metric_ratio(m)), m) for m in metrics if _metric_ratio(m) !== nothing]
        if !isempty(ratios)
            ratio, metric = last(sort!(ratios; by = first))
            println(
                io,
                "Largest value/limit: ",
                @sprintf("%.3g", ratio),
                " [",
                get(_TB_REPORT_LABELS, metric.name, ("Other", metric.name, "?"))[2],
                "]",
            )
        end
        println(
            io,
            "Note: symmetry PASS does not imply Wannierization convergence or production eligibility.",
        )
    end
    if compact
        @printf(
            io,
            "%-12s %-24s %12s %12s %-4s %s\n",
            "Category",
            "Check",
            "Value",
            "Limit",
            "Unit",
            "Status"
        )
    else
        @printf(
            io,
            "%-12s %-24s %-9s %-9s %-4s %-7s %s\n",
            "Category",
            "Check",
            "Value",
            "Limit",
            "Unit",
            "Ratio",
            "Status"
        )
    end
    for metric in metrics
        category, label, unit = get(_TB_REPORT_LABELS, metric.name, ("Other", metric.name, "?"))
        ratio = _metric_ratio(metric)
        ratio_text =
            ratio === nothing ? "N/A" : 0 < ratio < 0.001 ? "<0.001" : @sprintf("%.3f", ratio)
        if compact
            characters = collect(label)
            label_lines = [
                String(characters[i:min(i + 23, length(characters))]) for
                i in 1:24:length(characters)
            ]
            @printf(
                io,
                "%-12s %-24s %12s %12s %-4s %s\n",
                category,
                first(label_lines),
                _report_number(metric.value),
                _report_number(metric.threshold),
                unit,
                metric.status
            )
            for continuation in label_lines[2:end]
                @printf(io, "%-12s %-24s\n", "", continuation)
            end
        else
            @printf(
                io,
                "%-12s %-24s %-9s %-9s %-4s %-7s %s\n",
                category,
                label,
                _report_number(metric.value),
                _report_number(metric.threshold),
                unit,
                ratio_text,
                metric.status
            )
        end
        compact ||
            metric.status == "PASS" ||
            isempty(metric.reason) ||
            println(io, "  reason: ", metric.reason)
    end
    if !compact
        println(io, "\nDefinitions:")
        for (index, metric) in enumerate(metrics)
            println(
                io,
                "[$index] ",
                get(_TB_REPORT_LABELS, metric.name, ("Other", metric.name, "?"))[2],
            )
            line = "  "
            for word in split(metric.convention)
                if length(line) + length(word) > 92
                    println(io, line)
                    line = "  "
                end
                line *= word * " "
            end
            println(io, rstrip(line))
        end
    end
end

# Align one human-readable report field without changing its stored value.
function _write_report_field(io, name, value)
    field = lowercase(String(name))
    (occursin("sha256", field) || occursin("digest", field)) && return nothing
    @printf(io, "%-31s = %s\n", String(name), _report_value(value))
    return nothing
end

# Open a visually separated report section.
function _write_report_section(io, title)
    println(io, "\n", _WANNIERIZATION_REPORT_RULE)
    println(io, " ", title)
    println(io, _WANNIERIZATION_REPORT_RULE, "\n")
    return nothing
end

# Arrange per-state spreadings in up to four column-major display columns.
function _write_spreading_table(io, spreads; heading = "Per-Wannier-state spreading (angstrom^2)")
    println(io, heading, "\n")
    columns = min(4, max(length(spreads), 1))
    rows = cld(length(spreads), columns)
    println(io, join(fill(" WF       Spreading", columns), " |"))
    println(io, join(fill("--------------------", columns), "+"))
    for row in 1:rows
        cells = String[]
        for column in 1:columns
            index = row + (column - 1) * rows
            index <= length(spreads) &&
                push!(cells, @sprintf("%02d   %14.10f", index, spreads[index]))
        end
        println(io, join(cells, " | "))
    end
    return nothing
end

# Write the human-readable run header without importing Runtime progress policy.
function _legacy_open_wannierization_log(
    path,
    config::WannierizationConfig,
    representation;
    compatibility,
    restart::Bool,
)
    mkpath(dirname(path))
    io = open(path, restart ? "a" : "w")
    restart && println(io, "\n[WANNIERIZATION RESTART]")
    println(io, _WANNIERIZATION_REPORT_RULE)
    println(io, " WannierNLQG WANNIERIZATION — HUMAN-READABLE OUTPUT")
    println(io, _WANNIERIZATION_REPORT_RULE, "\n\n[INPUT]\n")
    _write_report_field(io, "generated_at_utc", now(UTC))
    _write_report_field(io, "wanniernlqg_version", Base.pkgversion(WannierNLQG))
    _write_report_field(io, "source_code", representation.source_code)
    _write_report_field(io, "execution_mode", restart ? "restart" : "fresh")
    _write_report_field(io, "requested_wannierization_mode", config.input.wannierization_mode)
    _write_report_field(io, "effective_wannierization_mode", effective_wannierization_mode(config))
    _write_report_field(io, "construction_policy", config.input.construction_policy)
    _write_report_field(io, "representation_source", representation_source(config))
    symmetry_applied = symmetry_constraints_applied(config, representation)
    _write_report_field(io, "symmetry_constraints_applied", symmetry_applied)
    _write_report_field(io, "requested_symmetrize_z", config.solver.symmetrize_z)
    _write_report_field(
        io,
        "effective_symmetrize_z",
        symmetry_applied && config.solver.symmetrize_z,
    )
    _write_report_field(io, "spinor", representation.spinor)
    _write_report_field(
        io,
        "include_time_reversal",
        any(operation -> operation.antiunitary, representation.operations),
    )
    _write_report_field(io, "symmetry_operations", length(representation.operations))
    _write_report_field(io, "kpoint_mesh", join(representation.mp_grid, " x "))
    _write_report_field(io, "num_kpoints", size(representation.energies_ev, 2))
    _write_report_field(io, "num_input_bands", size(representation.energies_ev, 1))
    _write_report_field(io, "num_wannier", config.input.num_wannier)
    _write_report_field(
        io,
        "outer_window_eV",
        "[$(config.input.outer_min_ev), $(config.input.outer_max_ev)]",
    )
    _write_report_field(
        io,
        "frozen_window_eV",
        "[$(config.input.frozen_min_ev), $(config.input.frozen_max_ev)]",
    )
    _write_report_field(io, "spread_definition", "full_3d")
    _write_report_field(io, "spread_unit", "angstrom^2")
    # Report the resolved selection label so a task-derived run never renders `nothing`.
    _write_report_field(
        io,
        "output_operator_profile",
        IO.resolved_operator_profile(_resolved_operator_selection(config)),
    )
    _write_report_field(io, "parallel", config.solver.parallel)
    _write_report_field(io, "threads", Threads.nthreads())
    if symmetry_applied
        _write_report_field(io, "representation_compatible", compatibility.passed)
    elseif isfinite(compatibility.maximum_required_block_unitarity_residual)
        _write_report_field(
            io,
            "identity_sewing_unitarity_residual",
            compatibility.maximum_required_block_unitarity_residual,
        )
        _write_report_field(io, "sewing_diagnostic_scope", "IDENTITY_BOOKKEEPING_ONLY")
    end
    _write_report_field(io, "content_hash_authentication", "NOT_PERFORMED")
    println(io, "\n[SOLVER CONFIGURATION]\n")
    _write_report_field(io, "optimization_schedule", config.solver.acceleration.schedule)
    _write_report_field(
        io,
        "disentanglement_max_steps",
        config.solver.acceleration.disentanglement_max_steps,
    )
    _write_report_field(
        io,
        "localization_max_steps",
        config.solver.acceleration.localization_max_steps,
    )
    _write_report_field(
        io,
        "maximum_total_steps",
        Base.Checked.checked_add(
            config.solver.stage_controls.dis_num_iter,
            config.solver.stage_controls.num_iter,
        ),
    )
    _write_report_field(io, "progress_interval", config.runtime.num_print_cycles)
    _write_report_field(io, "checkpoint_interval", config.checkpoint.num_dump_cycles)
    _write_report_field(io, "convergence_window", max(2, config.solver.stage_controls.conv_window))
    _write_report_field(io, "convergence_tolerance", config.solver.stage_controls.conv_tol)
    _write_report_field(io, "z_mix_ratio", config.solver.z_mix_ratio)
    _write_report_field(io, "u_mix_ratio", config.solver.u_mix_ratio)
    _write_report_field(
        io,
        "u_mix_ratio_role",
        "legacy_restart_identity_only; not an update factor",
    )
    _write_report_field(io, "u_inner_sweeps", config.solver.acceleration.u_inner_sweeps)
    _write_report_field(io, "optimizer_strategy", config.solver.acceleration.strategy)
    _write_report_field(io, "representation_tolerance", config.input.representation_tolerance)
    covariance_tolerance =
        !symmetry_constraints_applied(config, representation) ? "NOT_APPLICABLE" :
        string(projector_covariance_tolerance(config, compatibility))
    symmetry_applied &&
        _write_report_field(io, "projector_covariance_tolerance", covariance_tolerance)
    _write_report_field(
        io,
        "target_center_matching_tolerance",
        config.input.target_center_matching_tolerance,
    )
    _write_report_field(io, "random_seed", config.solver.random_seed)
    _write_report_section(io, "PROGRESS")
    flush(io)
    return io
end

# Emit one complete periodic state after its checkpoint is durable.
function _legacy_write_wannierization_progress(
    io,
    snapshot,
    checkpoint_path,
    config::WannierizationConfig,
    representation = nothing,
    ;
    heading::Union{Nothing, AbstractString} = nothing,
)
    snapshot_value(name, default) =
        hasproperty(snapshot, name) ? getproperty(snapshot, name) : default
    symmetry_applied =
        representation === nothing ? symmetry_constraints_applied(config) :
        symmetry_constraints_applied(config, representation)
    optimizer_phase = Symbol(snapshot_value(:optimizer_phase, :NOT_RECORDED))
    completed_stage = Symbol(snapshot_value(:completed_stage, optimizer_phase))
    report_stage = completed_stage == :disentanglement ? :disentanglement : optimizer_phase
    println(io, heading === nothing ? "[ITERATION $(snapshot.iteration)]\n" : "[$(heading)]\n")
    _write_report_field(io, "stage", report_stage)
    _write_report_field(io, "accepted_iteration", snapshot.iteration)
    _write_report_field(io, "elapsed_seconds", snapshot.elapsed_seconds)
    println(io)
    if report_stage == :disentanglement && config.solver.acceleration.schedule == :two_stage
        omega_i = snapshot_value(:omega_i, NaN)
        delta_omega_i = snapshot_value(:delta_omega_i, NaN)
        fractional_delta =
            representation === nothing ?
            effective_wannierization_algorithms(config).disentanglement ==
            :smv_fletcher_reeves_two_stage :
            effective_wannierization_algorithms(config, representation).disentanglement ==
            :smv_fletcher_reeves_two_stage
        delta_definition = fractional_delta ? "fractional_change" : "absolute_change"
        tolerance = config.solver.acceleration.disentanglement_objective_tolerance
        _write_report_field(io, "omega_i", "$(omega_i) angstrom^2")
        _write_report_field(io, "delta_omega_i", delta_omega_i)
        _write_report_field(io, "delta_omega_i_definition", delta_definition)
        _write_report_field(io, "disentanglement_tolerance", tolerance)
        _write_report_field(io, "z_stability_count", snapshot_value(:z_stability_count, 0))
        _write_report_field(io, "z_stability_window", config.solver.acceleration.z_stability_window)
        _write_report_field(
            io,
            "metric_to_tolerance_ratio",
            tolerance > 0 && isfinite(delta_omega_i) ? abs(delta_omega_i) / tolerance :
            "NOT_AVAILABLE",
        )
        _write_report_field(io, "total_spreading", "NOT_EVALUATED")
        _write_report_field(io, "per_wannier_state_spreading", "NOT_EVALUATED")
    else
        omega_i = snapshot_value(:omega_i, NaN)
        if report_stage == :localization
            _write_report_field(io, "omega_i", "$(omega_i) angstrom^2")
            _write_report_field(io, "omega_tilde", "$(snapshot.spread_total - omega_i) angstrom^2")
            _write_report_field(io, "u_stability_count", snapshot_value(:u_stability_count, 0))
            _write_report_field(
                io,
                "u_stability_window",
                max(2, config.solver.stage_controls.conv_window),
            )
        end
        _write_report_field(io, "total_spreading", "$(snapshot.spread_total) angstrom^2")
        _write_report_field(io, "convergence_metric", snapshot.convergence_metric)
        _write_report_field(io, "convergence_tolerance", config.solver.stage_controls.conv_tol)
        _write_report_field(
            io,
            "metric_to_tolerance_ratio",
            config.solver.stage_controls.conv_tol > 0 ?
            snapshot.convergence_metric / config.solver.stage_controls.conv_tol : "NOT_AVAILABLE",
        )
    end
    if symmetry_applied
        println(io, "projector_covariance_error = $(snapshot.maximum_covariance_error)")
        println(io, "little_group_iterations = $(snapshot.little_group_iterations)")
        println(io, "little_group_residual = $(snapshot.little_group_residual)")
    end
    println(io, "projector_residual = $(snapshot_value(:projector_residual, NaN))")
    println(io, "z_residual = $(snapshot_value(:z_residual, NaN))")
    hasproperty(snapshot, :u_residual) && println(io, "u_residual = $(snapshot.u_residual)")
    println(io, "normalized_residual_merit = $(snapshot_value(:normalized_residual_merit, NaN))")
    println(io, "actual_z_mix_ratio = $(snapshot_value(:z_mix_ratio, config.solver.z_mix_ratio))")
    println(io, "actual_u_mix_ratio = $(snapshot_value(:u_mix_ratio, config.solver.u_mix_ratio))")
    println(io, "actual_u_mix_ratio_is_update_factor = false")
    println(
        io,
        "u_inner_sweeps = $(snapshot_value(:u_inner_sweeps, config.solver.acceleration.u_inner_sweeps))",
    )
    println(io, "anderson_used = $(snapshot_value(:anderson_used, false))")
    println(io, "anderson_fallback = $(snapshot_value(:anderson_fallback, false))")
    println(io, "rejected_steps = $(snapshot_value(:rejected_steps, 0))")
    println(io, "projected_gradient_rms = $(snapshot_value(:projected_gradient_rms, NaN))")
    println(io, "accepted_u_step_scale = $(snapshot_value(:accepted_u_step_scale, NaN))")
    println(
        io,
        "localization_backtracking_steps = $(snapshot_value(:localization_backtracking_steps, 0))",
    )
    println(io, "elapsed_seconds = $(snapshot.elapsed_seconds)")
    checkpoint_path === nothing ||
        println(io, "checkpoint = $(_report_path(checkpoint_path, dirname(checkpoint_path)))")
    println(io)
    if !(report_stage == :disentanglement && config.solver.acceleration.schedule == :two_stage)
        _write_spreading_table(io, snapshot.spreads)
        _write_report_field(io, "sum_of_state_spreadings", "$(sum(snapshot.spreads)) angstrom^2")
        _write_report_field(
            io,
            "total_minus_state_sum",
            "$(snapshot.spread_total - sum(snapshot.spreads)) angstrom^2",
        )
    end
    flush(io)
    return nothing
end

# Return an observer that performs periodic atomic checkpoints before logging.
function _wannierization_observer(
    config::WannierizationConfig,
    representation,
    paths,
    io,
    persisted_input_summary::AbstractDict{String, String} = Dict{String, String}(),
)
    last_stage=Ref(:none)
    return function (snapshot, state, history, diagnostics)
        checkpoint_path = nothing
        stage_boundary =
            hasproperty(snapshot, :completed_stage) &&
            hasproperty(snapshot, :optimizer_phase) &&
            Symbol(snapshot.completed_stage) == :disentanglement &&
            Symbol(snapshot.optimizer_phase) == :localization
        accepted_step =
            config.solver.stage_controls === nothing ? snapshot.iteration :
            Symbol(snapshot.completed_stage) == :disentanglement ? snapshot.z_steps :
            snapshot.u_steps
        if paths.checkpoint!==nothing && (
            (config.solver.stage_controls !== nothing && stage_boundary) || (
                config.checkpoint.num_dump_cycles > 0 &&
                accepted_step > 0 &&
                accepted_step % config.checkpoint.num_dump_cycles == 0
            )
        )
            checkpoint_path = write_wannierization_checkpoint_hdf5(
                paths.checkpoint,
                _periodic_result(
                    snapshot,
                    state,
                    history,
                    diagnostics,
                    representation,
                    config,
                    persisted_input_summary,
                );
                reference_root = config.checkpoint.reference_root,
            )
        end
        stage_boundary =
            hasproperty(snapshot, :completed_stage) &&
            hasproperty(snapshot, :optimizer_phase) &&
            Symbol(snapshot.completed_stage) == :disentanglement &&
            Symbol(snapshot.optimizer_phase) == :localization
        stage=Symbol(snapshot.completed_stage)==:disentanglement ? :disentanglement : :localization
        if config.runtime.num_print_cycles>0 &&
           accepted_step>0 &&
           accepted_step%config.runtime.num_print_cycles==0
            heading=last_stage[]==stage ? nothing : String(stage)
            _write_wannierization_progress(
                io,
                snapshot,
                checkpoint_path,
                config,
                representation;
                heading,
            )
            last_stage[]=stage
        end
        return nothing
    end
end

# Write a file through a sibling temporary path and replace it only after close.
function _atomic_wannier_tb(
    filename,
    model;
    comment,
    byte_sink = nothing,
    return_receipt::Bool = false,
)
    path = abspath(filename)
    mkpath(dirname(path))
    temporary, io = mktemp(dirname(path); cleanup = false)
    close(io)
    completed = false
    local receipt
    try
        receipt = write_wannier_tb(
            temporary,
            model;
            comment,
            overwrite = true,
            byte_sink,
            return_receipt = true,
        )
        IO.atomic_file_replace(temporary, path)
        completed = true
    finally
        !completed && isfile(temporary) && rm(temporary; force = true)
    end
    return return_receipt ? (; path, bytes = receipt.bytes) : path
end

# Build the exact Hamiltonian/position inventory expected by Packed HDF5 v5.
function _tb_operators(model)
    return Dict(
        Core.REAL_SPACE_HAMILTONIAN => Core.RealSpaceOperator(
            Core.RealSpaceOperatorSymmetrySpec(Core.REAL_SPACE_HAMILTONIAN, 0, 1, 1),
            model.r_vectors,
            model.hamiltonian_r,
        ),
        Core.REAL_SPACE_POSITION => Core.RealSpaceOperator(
            Core.RealSpaceOperatorSymmetrySpec(Core.REAL_SPACE_POSITION, 1, -1, 1),
            model.r_vectors,
            model.position_r,
        ),
    )
end

# Derive the Convention-II centers serialized in the position home cell.
function _tb_centers(model)
    home =
        only(findall(index -> all(iszero, @view(model.r_vectors[:, index])), 1:model.num_r_vectors))
    centers = zeros(Float64, model.num_orbitals, 3)
    for wf in 1:model.num_orbitals, direction in 1:3
        centers[wf, direction] = real(model.position_r[wf, wf, direction, home])
    end
    return centers
end

# Validate R/-R adjoint closure for one R-last matrix or Cartesian matrix field.
function _real_space_hermiticity_error(values, r_vectors)
    index = Dict(Tuple(r_vectors[:, position]) => position for position in axes(r_vectors, 2))
    length(index) == size(r_vectors, 2) || error("TB R-vector support contains duplicates")
    maximum_error = 0.0
    for position in axes(r_vectors, 2)
        partner = get(index, Tuple(-r_vectors[:, position]), nothing)
        partner === nothing && error("TB R-vector support is not closed under R -> -R")
        if ndims(values) == 3
            maximum_error = max(
                maximum_error,
                maximum(abs, @view(values[:, :, position]) - @view(values[:, :, partner])'),
            )
        else
            for direction in axes(values, 3)
                maximum_error = max(
                    maximum_error,
                    maximum(
                        abs,
                        @view(values[:, :, direction, position]) -
                        @view(values[:, :, direction, partner])',
                    ),
                )
            end
        end
    end
    return maximum_error
end

# Export the exact retained accepted state. Finite residuals are measurements;
# ordinary export does not apply a second polar repair or change its subspace.
function _prepare_wannierization_tb_state(result, config::WannierizationConfig)
    result.restart_state === nothing && return result, "NO_VALID_STATE", Inf, Inf, false
    all(isfinite, result.v_matrix) || return result, "NO_VALID_STATE", Inf, Inf, false
    restart = something(result.restart_state)
    projector_drift = 0.0
    if restart.fixed_subspace_projectors !== nothing || restart.fixed_subspace_frames !== nothing
        restart.fixed_subspace_projectors !== nothing &&
        restart.fixed_subspace_frames !== nothing ||
            throw(ArgumentError("sealed fixed-subspace checkpoint state is incomplete"))
        size(something(restart.fixed_subspace_projectors), 3) == size(result.v_matrix, 3) ||
            throw(ArgumentError("sealed fixed-subspace mesh disagrees with the accepted frame"))
        projector_drift = maximum(
            norm(
                @view(result.v_matrix[:, :, kpoint]) * @view(result.v_matrix[:, :, kpoint])' -
                @view(something(restart.fixed_subspace_projectors)[:, :, kpoint]),
            ) for kpoint in axes(result.v_matrix, 3)
        )
        isfinite(projector_drift) ||
            throw(ArgumentError("FATAL_INTEGRITY: nonfinite fixed projector drift"))
    end
    num_wannier = size(result.v_matrix, 2)
    identity = Matrix{ComplexF64}(I, num_wannier, num_wannier)
    isometry_before = maximum(
        maximum(
            abs,
            @view(result.v_matrix[:, :, kpoint])' * @view(result.v_matrix[:, :, kpoint]) - identity;
            init = 0.0,
        ) for kpoint in axes(result.v_matrix, 3)
    )
    frozen = _summary_residual(result.input_summary, "hard_gate_frozen")
    isfinite(isometry_before) && isfinite(frozen) ||
        throw(ArgumentError("FATAL_INTEGRITY: nonfinite accepted-state residual"))
    quality =
        max(isometry_before, frozen, projector_drift) > config.input.representation_tolerance ?
        "NUMERICAL_WARNING" : "PASS"
    return result, quality, isometry_before, isometry_before, false
end

const _STANDARD_LINE_SEARCH_CODES = (
    :SPREAD_INCREASE_BACKTRACKING_EXHAUSTED,
    :SPREAD_GRADIENT_LINE_SEARCH_FAILED,
    :LOCALIZATION_BACKTRACKING_EXHAUSTED,
    :LOCALIZATION_LINE_SEARCH_EXHAUSTED,
    :NON_DESCENT_LOCALIZATION_DIRECTION,
    :NONFINITE_LOCALIZATION_DIRECTION,
)

"""Read one finite-gate residual from a string-valued solver summary."""
function _summary_residual(summary, key)
    value = tryparse(Float64, get(summary, key, ""))
    return value === nothing ? Inf : something(value)
end

# Recognize measured construction-quality failures, not names containing error keywords.
function _standard_construction_quality_error(diagnostic::WannierizationDiagnostic)
    context = diagnostic.context
    code = diagnostic.code
    key =
        if code in (
            :MMN_STENCIL_COMPLETENESS_FAILED,
            :TARGET_SYMMETRY_TANGENT_RESIDUAL_FAILED,
            :SOLVER_TRIAL_COVARIANCE_FAILED,
            :SOLVER_TRIAL_TARGET_SYMMETRY_FAILED,
        )
            "value"
        elseif code == :EMPIRICAL_COVARIANCE_BUDGET_VACUOUS
            "maximum_group_law_residual"
        elseif code in (
            :REQUIRED_BLOCK_UNITARITY_FAILED,
            :ANTIUNITARY_GROUP_LAW_FAILED,
            :TARGET_REPRESENTATION_GROUP_LAW_FAILED,
            :THETA_SQUARED_FAILED,
            :ANTIUNITARY_PROJECTOR_COVARIANCE_FAILED,
            :KRAMERS_BLOCK_NOT_CLOSED,
            :COREPRESENTATION_BLOCK_NOT_CLOSED,
        )
            "maximum_error"
        else
            return false
        end
    residual = tryparse(Float64, get(context, key, ""))
    residual !== nothing && isfinite(residual) && residual >= 0.0 || return false
    # Non-finite numeric context never qualifies as a finite quality warning.
    for key in ("threshold", "tolerance", "strict_upper_bound")
        haskey(context, key) || continue
        number = tryparse(Float64, context[key])
        number !== nothing && isfinite(number) || return false
    end
    if code in (:KRAMERS_BLOCK_NOT_CLOSED, :COREPRESENTATION_BLOCK_NOT_CLOSED)
        source_rank = tryparse(Int, get(context, "source_rank", ""))
        target_rank = tryparse(Int, get(context, "target_rank", ""))
        source_rank !== nothing && source_rank >= 0 && source_rank == target_rank || return false
        if code == :KRAMERS_BLOCK_NOT_CLOSED &&
           get(context, "source_kpoint", "") == get(context, "target_kpoint", "")
            iseven(source_rank) || return false
        end
    end
    return true
end

# Qualify only the last accepted solver boundary.  A rejected line-search trial
# never enters result.v_matrix/restart_state, so this gate cannot publish it.
function _accepted_state_tb_export_gate(result, config::WannierizationConfig)
    any(
        d -> get(d.context, "compatibility_admission", "") == "REJECTED_STRICT",
        result.diagnostics,
    ) && return (
        allowed = false,
        classification = "UNAVAILABLE",
        reason = "STRICT_COMPATIBILITY_ADMISSION_REJECTED",
        minimum_rank = 0,
        required_rank = size(result.v_matrix, 2),
        isometry_residual = Inf,
    )
    result.status in (IO_FAILURE, INVALID_INPUT) && return (
        allowed = false,
        classification = "UNAVAILABLE",
        reason = "HARD_TERMINAL_FAILURE: $(result.status)",
        minimum_rank = 0,
        required_rank = size(result.v_matrix, 2),
        isometry_residual = Inf,
    )
    schedule = get(result.input_summary, "optimizer_schedule", "")
    schedule == String(config.solver.acceleration.schedule) || return (
        allowed = false,
        classification = "UNAVAILABLE",
        # An absent schedule means the solver never reached the preparation
        # boundary that stamps it; only a present-but-different schedule is a
        # genuine identity mismatch.
        reason = isempty(schedule) ? "SOLVER_NOT_REACHED" : "SOLVER_SCHEDULE_IDENTITY_MISMATCH",
        minimum_rank = 0,
        required_rank = size(result.v_matrix, 2),
        isometry_residual = Inf,
    )
    validate_ordinary_construction_policy(config.input.construction_policy)
    classification =
        result.status == COMPLETED &&
        get(result.input_summary, "construction_quality_failed", "false") != "true" &&
        !any(diagnostic -> diagnostic.severity == :warning, result.diagnostics) ? "AVAILABLE" :
        "AVAILABLE_WITH_QUALITY_WARNINGS"
    result.restart_state !== nothing &&
    result.wannier_chk !== nothing &&
    get(result.input_summary, "has_accepted_state", "false") == "true" || return (
        allowed = false,
        classification = "UNAVAILABLE",
        reason = "NO_VALID_ACCEPTED_STATE",
        minimum_rank = 0,
        required_rank = size(result.v_matrix, 2),
        isometry_residual = Inf,
    )
    restart = something(result.restart_state)
    chk = something(result.wannier_chk)
    accepted_iteration = tryparse(Int, get(result.input_summary, "last_accepted_iteration", ""))
    accepted_iteration !== nothing &&
    something(accepted_iteration) == restart.iteration &&
    restart.frames == result.v_matrix &&
    restart.centers_cartesian == result.wannier_centers_cartesian &&
    restart.spreads_angstrom2 == result.spreads_angstrom2 &&
    chk.v_matrix == result.v_matrix &&
    chk.wannier_centers_cart == result.wannier_centers_cartesian || return (
        allowed = false,
        classification = "UNAVAILABLE",
        reason = "ACCEPTED_STATE_CHECKPOINT_MISMATCH",
        minimum_rank = 0,
        required_rank = size(result.v_matrix, 2),
        isometry_residual = Inf,
    )
    wannierization_result_is_finite(result) || return (
        allowed = false,
        classification = "UNAVAILABLE",
        reason = "NONFINITE_ACCEPTED_STATE",
        minimum_rank = 0,
        required_rank = size(result.v_matrix, 2),
        isometry_residual = Inf,
    )
    nb, nw, nk = size(result.v_matrix)
    nb >= nw > 0 && nk > 0 || return (
        allowed = false,
        classification = "UNAVAILABLE",
        reason = "INVALID_ACCEPTED_STATE_DIMENSIONS",
        minimum_rank = 0,
        required_rank = nw,
        isometry_residual = Inf,
    )
    minimum_rank = nw
    isometry_residual = 0.0
    for kpoint in 1:nk
        frame = @view result.v_matrix[:, :, kpoint]
        singular_values = svdvals(frame)
        threshold = max(
            config.input.representation_tolerance,
            eps(Float64) * max(size(frame)...) * maximum(singular_values; init = 0.0),
        )
        minimum_rank = min(minimum_rank, count(value -> value > threshold, singular_values))
        isometry_residual = max(
            isometry_residual,
            maximum(abs, frame' * frame - Matrix{ComplexF64}(I, nw, nw); init = 0.0),
        )
    end
    minimum_rank == nw || return (
        allowed = false,
        classification = "UNAVAILABLE",
        reason = "RANK_DEFICIENT_ACCEPTED_FRAME",
        minimum_rank,
        required_rank = nw,
        isometry_residual,
    )
    isfinite(isometry_residual) || return (
        allowed = false,
        classification = "UNAVAILABLE",
        reason = "ACCEPTED_FRAME_ORTHOGONALITY_FAILED",
        minimum_rank,
        required_rank = nw,
        isometry_residual,
    )
    if restart.fixed_subspace_projectors !== nothing || restart.fixed_subspace_frames !== nothing
        restart.fixed_subspace_projectors !== nothing &&
        restart.fixed_subspace_frames !== nothing || return (
            allowed = false,
            classification = "UNAVAILABLE",
            reason = "INCOMPLETE_FIXED_SUBSPACE_STATE",
            minimum_rank,
            required_rank = nw,
            isometry_residual,
        )
        fixed_projector_drift = maximum(
            norm(
                @view(result.v_matrix[:, :, kpoint]) * @view(result.v_matrix[:, :, kpoint])' -
                @view(something(restart.fixed_subspace_projectors)[:, :, kpoint]),
            ) for kpoint in 1:nk
        )
        fixed_projector_tolerance =
            get(result.input_summary, "effective_algorithm_profile", "") ==
            "smv_fletcher_reeves_two_stage" ? 1.0e-10 : 1.0e-12
        isfinite(fixed_projector_drift) || return (
            allowed = false,
            classification = "UNAVAILABLE",
            reason = "FIXED_SUBSPACE_PROJECTOR_DRIFT",
            minimum_rank,
            required_rank = nw,
            isometry_residual,
        )
    end
    frozen_residual = _summary_residual(result.input_summary, "hard_gate_frozen")
    isfinite(frozen_residual) || return (
        allowed = false,
        classification = "UNAVAILABLE",
        reason = "FROZEN_EMBEDDING_FAILED",
        minimum_rank,
        required_rank = nw,
        isometry_residual,
    )
    for key in ("hard_gate_isometry", "hard_gate_covariance", "hard_gate_target_symmetry")
        haskey(result.input_summary, key) || continue
        key == "hard_gate_target_symmetry" &&
            get(result.input_summary, "symmetry_constraints_applied", "true") != "true" &&
            continue
        isfinite(_summary_residual(result.input_summary, key)) || return (
            allowed = false,
            classification = "UNAVAILABLE",
            reason = "NONFINITE_REQUIRED_RESIDUAL: $(key)",
            minimum_rank,
            required_rank = nw,
            isometry_residual,
        )
    end
    # Only explicit, known later-trial stops and finite measured quality may
    # coexist with an independently verified legal accepted state. Unknown
    # errors remain blocking, including future diagnostic codes.
    blocking_errors = [
        diagnostic.code for
        diagnostic in result.diagnostics if diagnostic.severity == :error && !(
            diagnostic.code in _STANDARD_LINE_SEARCH_CODES ||
            _standard_construction_quality_error(diagnostic)
        )
    ]
    errors_allowed = isempty(blocking_errors)
    errors_allowed || return (
        allowed = false,
        classification = "UNAVAILABLE",
        reason = "HARD_ERROR_PRESENT: " * join(string.(blocking_errors), ", "),
        minimum_rank,
        required_rank = nw,
        isometry_residual,
    )
    return (
        allowed = true,
        classification,
        reason = "STRUCTURAL_GATE_PASS",
        minimum_rank,
        required_rank = nw,
        isometry_residual,
    )
end

"""Return whether a result passes the accepted-state TB structural gate."""
function _accepted_state_tb_export_allowed(result, config::WannierizationConfig)
    return _accepted_state_tb_export_gate(result, config).allowed
end

# Construct a narrowly scoped pre-export view for an export-only retry after the
# schema-5.5 metadata-forwarding defect.  The persisted failed result remains
# immutable: only the single known TB_EXPORT_FAILED diagnostic is removed, and
# every accepted-state structural gate is re-evaluated before the caller may
# retry into a new output directory.
function _schema_5_5_tb_export_retry_view(result, config::WannierizationConfig)
    result.status in (COMPLETED, COMPLETED_WITH_WARNINGS, MAX_ITERATIONS) ||
        throw(ArgumentError("TB_EXPORT_RETRY_REJECTED: solver status is not exportable"))
    errors = [diagnostic for diagnostic in result.diagnostics if diagnostic.severity == :error]
    length(errors) == 1 || throw(
        ArgumentError("TB_EXPORT_RETRY_REJECTED: expected exactly one failed-export diagnostic"),
    )
    failure = only(errors)
    failure.code == :TB_EXPORT_FAILED ||
        throw(ArgumentError("TB_EXPORT_RETRY_REJECTED: the only error is not TB_EXPORT_FAILED"))
    expected_message =
        "HAMILTONIAN_REFERENCE_MISMATCH: schema-5.5 symmetrized bundle requires " *
        "post-symmetrization residual gates"
    occursin(expected_message, failure.message) ||
        throw(ArgumentError("TB_EXPORT_RETRY_REJECTED: failed-export fingerprint differs"))
    summary = Dict{String, String}(result.input_summary)
    get(summary, "model_availability", "") == "UNAVAILABLE" ||
        throw(ArgumentError("TB_EXPORT_RETRY_REJECTED: failure classification differs"))
    occursin(expected_message, get(summary, "accepted_state_export_gate_reason", "")) ||
        throw(ArgumentError("TB_EXPORT_RETRY_REJECTED: failure reason differs"))
    get(summary, "tb_export_status", "") == "NOT_EXPORTED" ||
        throw(ArgumentError("TB_EXPORT_RETRY_REJECTED: failed result already records an export"))
    retained = WannierizationDiagnostic[
        diagnostic for diagnostic in result.diagnostics if diagnostic !== failure
    ]
    summary["model_availability"] =
        result.status in (COMPLETED, COMPLETED_WITH_WARNINGS) ? "AVAILABLE" :
        "AVAILABLE_WITH_QUALITY_WARNINGS"
    summary["accepted_state_export_gate_reason"] = "EXPORT_ONLY_SCHEMA_5_5_METADATA_RETRY"
    summary["tb_export_status"] = "NOT_EXPORTED"
    summary["numerical_quality"] = "PENDING_EXPORT_VALIDATION"
    retry_view =
        updated_wannierization_result(result; diagnostics = retained, input_summary = summary)
    gate = _accepted_state_tb_export_gate(retry_view, config)
    gate.allowed ||
        throw(ArgumentError("TB_EXPORT_RETRY_REJECTED: accepted-state gate failed: $(gate.reason)"))
    return retry_view
end

# Construct the only accepted export-retry view for the superseded generic
# spin q-to-R transform.  The persisted result is never mutated: the single
# historical failure must match its complete numeric fingerprint, after which
# every accepted-state structural gate is re-evaluated on the filtered view.
function _pair_wigner_seitz_spin_tb_export_retry_view(result, config::WannierizationConfig)
    result.status in (COMPLETED, COMPLETED_WITH_WARNINGS, MAX_ITERATIONS) ||
        throw(ArgumentError("TB_EXPORT_RETRY_REJECTED: solver status is not exportable"))
    errors = [diagnostic for diagnostic in result.diagnostics if diagnostic.severity == :error]
    length(errors) == 1 || throw(
        ArgumentError("TB_EXPORT_RETRY_REJECTED: expected exactly one failed-export diagnostic"),
    )
    failure = only(errors)
    failure.code == :TB_EXPORT_FAILED ||
        throw(ArgumentError("TB_EXPORT_RETRY_REJECTED: the only error is not TB_EXPORT_FAILED"))
    fingerprint = match(
        r"^SPN q->R->q round-trip error ([0-9eE+.-]+) exceeds atol=1\.0e-8\.$",
        failure.message,
    )
    fingerprint === nothing &&
        throw(ArgumentError("TB_EXPORT_RETRY_REJECTED: failed-export fingerprint differs"))
    residual = tryparse(Float64, only(fingerprint.captures))
    residual !== nothing &&
    isfinite(something(residual)) &&
    something(residual) > PROFILE_PAIR_WIGNER_SEITZ_ROUNDTRIP_TOLERANCE ||
        throw(ArgumentError("TB_EXPORT_RETRY_REJECTED: failed-export residual is invalid"))
    summary = Dict{String, String}(result.input_summary)
    get(summary, "model_availability", "") == "UNAVAILABLE" ||
        throw(ArgumentError("TB_EXPORT_RETRY_REJECTED: failure classification differs"))
    get(summary, "accepted_state_export_gate_reason", "") ==
    "TB_EXPORT_FAILED: $(failure.message)" ||
        throw(ArgumentError("TB_EXPORT_RETRY_REJECTED: failure reason differs"))
    get(summary, "tb_export_status", "") == "NOT_EXPORTED" ||
        throw(ArgumentError("TB_EXPORT_RETRY_REJECTED: failed result already records an export"))
    retained = WannierizationDiagnostic[
        diagnostic for diagnostic in result.diagnostics if diagnostic !== failure
    ]
    summary["model_availability"] =
        result.status in (COMPLETED, COMPLETED_WITH_WARNINGS) ? "CONVERGED" :
        "AVAILABLE_WITH_QUALITY_WARNINGS"
    summary["accepted_state_export_gate_reason"] = "EXPORT_ONLY_PAIR_WIGNER_SEITZ_SPIN_TRANSFORM_RETRY"
    summary["tb_export_status"] = "NOT_EXPORTED"
    summary["numerical_quality"] = "PENDING_EXPORT_VALIDATION"
    summary["export_retry_superseded_roundtrip_residual"] = string(something(residual))
    retry_view =
        updated_wannierization_result(result; diagnostics = retained, input_summary = summary)
    gate = _accepted_state_tb_export_gate(retry_view, config)
    gate.allowed ||
        throw(ArgumentError("TB_EXPORT_RETRY_REJECTED: accepted-state gate failed: $(gate.reason)"))
    return retry_view
end

# Record construction diagnostics and the packed publication identity.
function _write_construction_metadata_sidecar(path, publication_identity, metadata)
    sidecar = path * ".quality.json"
    payload = merge(metadata, Dict("packed_publication_identity" => publication_identity))
    temporary, io = mktemp(dirname(sidecar); cleanup = false)
    completed = false
    try
        checked = IO.ScientificCheckpointWriteStream(io, 0)
        JSON3.write(checked, payload)
        close(io)
        IO.atomic_file_replace(temporary, sidecar)
        completed = true
    finally
        isopen(io) && close(io)
        !completed && isfile(temporary) && rm(temporary; force = true)
    end
    return sidecar
end

# Numerical thresholds qualify quality; they are not Standard integrity gates.
function _export_numerical_check!(records, policy, code, value, threshold)
    isfinite(value) || throw(ArgumentError("FATAL_INTEGRITY: $(code) is nonfinite"))
    failed = value > threshold
    push!(
        records,
        Dict{String, Any}(
            "code" => code,
            "severity" => failed ? "warning" : "info",
            "message" => failed ? "NUMERICAL_WARNING" : "WITHIN_REFERENCE_THRESHOLD",
            "context" => Dict(
                "value" => value,
                "threshold" => threshold,
                "gate_result" => failed ? "FAIL" : "PASS",
                "classification" => failed ? "NUMERICAL_WARNING" : "PASS",
            ),
        ),
    )
    validate_ordinary_construction_policy(policy)
    return failed
end

# Inspect only declared numerical audit pairs; provenance/identity errors are never demoted.
function _profile_export_numerical_checks!(records, policy, metadata, prefix = "FULL")
    metadata isa AbstractDict || return false
    warning = false
    for (value_key, tolerance_key) in (
        ("exchange_hermiticity_max_absolute_ev", "exchange_hermiticity_tolerance_ev"),
        ("pair_wigner_seitz_roundtrip_residual", "pair_wigner_seitz_roundtrip_tolerance"),
    )
        if haskey(metadata, value_key) && haskey(metadata, tolerance_key)
            value, tolerance = metadata[value_key], metadata[tolerance_key]
            # Explicit non-applicability uses null/NaN in the existing profile schema.
            applicable =
                value_key == "exchange_hermiticity_max_absolute_ev" ? value !== nothing :
                get(metadata, "pair_wigner_seitz_roundtrip_status", "NOT_APPLICABLE") !=
                "NOT_APPLICABLE"
            if applicable
                warning |= _export_numerical_check!(
                    records,
                    policy,
                    prefix * ":" * value_key,
                    value,
                    tolerance,
                )
            end
        end
    end
    for (key, value) in metadata
        value isa AbstractDict || continue
        warning |=
            _profile_export_numerical_checks!(records, policy, value, prefix * ":" * String(key))
    end
    return warning
end

# Export one authoritative Packed HDF5 model and optionally transfer its owned operators.
function _export_wannierization_tb(
    result,
    eig,
    mmn,
    config::WannierizationConfig,
    paths,
    operator_symmetry_plan;
    operator_target_contract::Union{Nothing, WannierOperatorTargetContract} = nothing,
    return_operators::Bool = false,
    resolved_profile_sources = nothing,
)
    converged = result.status in (COMPLETED, COMPLETED_WITH_WARNINGS)
    symmetry_applied = get(result.input_summary, "symmetry_constraints_applied", "true") == "true"
    accepted_state_gate = _accepted_state_tb_export_gate(result, config)
    accepted_state_exportable = accepted_state_gate.allowed
    accepted_state_exportable || throw(
        ArgumentError(
            "FATAL_INTEGRITY: tight-binding export rejected status=$(result.status): $(accepted_state_gate.reason)",
        ),
    )
    wannierization_result_is_finite(result) ||
        throw(ArgumentError("tight-binding construction rejects non-finite SAWF arrays"))
    # Resolve the mutually exclusive selection once; every downstream gate below is
    # driven by the resolved inventory/source closure, not by the raw profile label.
    operator_selection = _resolved_operator_selection(config)
    if _operator_selection_requires_target_contract(operator_selection)
        operator_target_contract === nothing && throw(
            ArgumentError(
                "OPERATOR_TARGET_CONTRACT_REQUIRED: qualified-source operator selection export",
            ),
        )
        recorded_contract = get(
            result.input_summary,
            "operator_profile_preflight_operator_target_contract_definition",
            "MISSING",
        )
        recorded_contract == something(operator_target_contract).definition || throw(
            ArgumentError(
                "OPERATOR_TARGET_CONTRACT_MISMATCH: terminal checkpoint does not bind the preflight target",
            ),
        )
        _validate_operator_profile_preflight_snapshot(
            result,
            config;
            resolved_sources = resolved_profile_sources,
        )
    end
    prepared, numerical_quality, isometry_before, isometry_after, polar_repaired =
        _prepare_wannierization_tb_state(result, config)
    numerical_quality == "NO_VALID_STATE" &&
        throw(ArgumentError("tight-binding construction has no finite accepted state"))
    construction_diagnostics = Dict{String, Any}()
    band_hamiltonian = authoritative_band_hamiltonian(config, eig)
    declared_authority = get(result.input_summary, "authoritative_hamiltonian", "")
    isempty(declared_authority) ||
        declared_authority == band_hamiltonian.authority ||
        throw(
            ArgumentError(
                "HAMILTONIAN_REFERENCE_MISMATCH: result declares $(declared_authority) but export data authority is $(band_hamiltonian.authority)",
            ),
        )
    model = build_wannier_tight_binding_model(
        prepared,
        band_hamiltonian,
        mmn;
        construction_diagnostics,
        construction_policy = config.input.construction_policy,
    )
    all(isfinite, model.lattice) &&
    all(isfinite, model.hamiltonian_r) &&
    all(isfinite, model.position_r) || error("constructed TB contains non-finite arrays")
    hamiltonian_hermiticity = _real_space_hermiticity_error(model.hamiltonian_r, model.r_vectors)
    position_hermiticity = _real_space_hermiticity_error(model.position_r, model.r_vectors)
    export_checks = Dict{String, Any}[]
    policy = config.input.construction_policy
    numerical_warning = false
    begin
        for diagnostic in result.diagnostics
            _standard_construction_quality_error(diagnostic) || continue
            numerical_warning = true
            push!(
                export_checks,
                Dict(
                    "code" => String(diagnostic.code),
                    "severity" => "warning",
                    "message" => "NUMERICAL_WARNING",
                    "context" => merge(
                        copy(diagnostic.context),
                        Dict("classification" => "NUMERICAL_WARNING"),
                    ),
                ),
            )
        end
        numerical_warning |= _export_numerical_check!(
            export_checks,
            policy,
            "ACCEPTED_FRAME_ISOMETRY",
            isometry_before,
            config.input.representation_tolerance,
        )
        numerical_warning |= _export_numerical_check!(
            export_checks,
            policy,
            "FROZEN_EMBEDDING",
            _summary_residual(result.input_summary, "hard_gate_frozen"),
            config.input.representation_tolerance,
        )
        restart = something(result.restart_state)
        if restart.fixed_subspace_projectors !== nothing
            drift = maximum(
                norm(
                    @view(result.v_matrix[:, :, k]) * @view(result.v_matrix[:, :, k])' -
                    @view(something(restart.fixed_subspace_projectors)[:, :, k])
                ) for k in axes(result.v_matrix, 3)
            )
            threshold =
                get(result.input_summary, "effective_algorithm_profile", "") ==
                "smv_fletcher_reeves_two_stage" ? 1.0e-10 : 1.0e-12
            numerical_warning |= _export_numerical_check!(
                export_checks,
                policy,
                "FIXED_SUBSPACE_PROJECTOR_DRIFT",
                drift,
                threshold,
            )
        end
        if !converged
            numerical_warning = true
            push!(
                export_checks,
                Dict(
                    "code" => "SOLVER_NOT_CONVERGED",
                    "severity" => "warning",
                    "message" => "NUMERICAL_WARNING",
                    "context" => Dict(
                        "status" => string(result.status),
                        "convergence_tolerance" => config.solver.stage_controls.conv_tol,
                    ),
                ),
            )
        end
    end
    for (code, value, threshold) in (
        ("HAMILTONIAN_HERMITICITY", hamiltonian_hermiticity, 1.0e-10),
        ("POSITION_HERMITICITY", position_hermiticity, 1.0e-10),
        (
            "HAMILTONIAN_FOURIER_ROUNDTRIP",
            construction_diagnostics["hamiltonian_fourier_roundtrip_residual"],
            1.0e-10,
        ),
        (
            "POSITION_FOURIER_ROUNDTRIP",
            construction_diagnostics["position_fourier_roundtrip_residual"],
            1.0e-10,
        ),
    )
        numerical_warning |= _export_numerical_check!(export_checks, policy, code, value, threshold)
    end
    hermiticity_warning = max(hamiltonian_hermiticity, position_hermiticity) > 1.0e-10
    (numerical_warning || hermiticity_warning) && (numerical_quality = "NUMERICAL_WARNING")
    keep_tb = config.output.write_model_tb || :model_tb in config.output.tb_output_formats
    isfile(paths.packed) && throw(
        ArgumentError(
            "FATAL_INTEGRITY: export requires a new attempt; existing Packed TB is immutable",
        ),
    )
    keep_tb &&
        isfile(paths.wannier) &&
        throw(
            ArgumentError(
                "FATAL_INTEGRITY: export requires a new attempt; existing text TB is immutable",
            ),
        )
    exchange, exchange_io = mktemp(dirname(paths.packed); cleanup = false)
    close(exchange_io)
    mode_label =
        effective_wannierization_mode(config) == :ordinary ? "ordinary full-BZ MLWF" : "SAWF"
    quality_failed =
        any(
            diagnostic ->
                diagnostic.severity == :error ||
                get(diagnostic.context, "gate_result", "") == "FAIL",
            result.diagnostics,
        ) || get(result.input_summary, "construction_quality_failed", "false") == "true"
    construction_gate_records = String(
        JSON3.write([
            Dict(
                "code" => String(diagnostic.code),
                "severity" => String(diagnostic.severity),
                "message" => diagnostic.message,
                "context" => diagnostic.context,
            ) for diagnostic in result.diagnostics
        ]),
    )
    model_availability =
        quality_failed || !converged ? "AVAILABLE_WITH_QUALITY_WARNINGS" : "AVAILABLE"
    comment =
        "Created by WannierNLQG $(mode_label); status=$(result.status); " *
        "classification=$(model_availability); converged=$(converged)"
    tb_path = exchange
    packed_publication_identity = nothing
    # Packed output consumes the original in-memory result, never a text round trip.
    export_model = model
    centers = _tb_centers(export_model)
    center_delta_fractional =
        (centers - prepared.wannier_centers_cartesian) * inv(export_model.lattice)
    center_delta_fractional .-= round.(center_delta_fractional)
    numerical_warning |= _export_numerical_check!(
        export_checks,
        policy,
        "WANNIER_CENTER_CONSISTENCY",
        maximum(abs, center_delta_fractional * export_model.lattice; init = 0.0),
        1.0e-8,
    )
    numerical_warning && (numerical_quality = "NUMERICAL_WARNING")
    quality_failed |= numerical_warning || numerical_quality != "PASS"
    model_availability =
        quality_failed || !converged ? "AVAILABLE_WITH_QUALITY_WARNINGS" : "AVAILABLE"
    existing_records = JSON3.read(construction_gate_records, Vector{Dict{String, Any}})
    append!(existing_records, export_checks)
    construction_gate_records = String(JSON3.write(existing_records))
    fractional = centers * inv(export_model.lattice)
    export_status =
        converged && numerical_quality == "PASS" && !hermiticity_warning ? "EXPORTED" :
        "EXPORTED_WITH_WARNING"
    # The solver state machine only advances restart_state after every finite,
    # isometry, frozen-containment, covariance, and target-symmetry gate passes.
    # Numerical termination diagnostics therefore do not invalidate the retained
    # accepted boundary for downstream diagnostic validation.
    solver_validation_ready =
        result.restart_state !== nothing &&
        get(result.input_summary, "has_accepted_state", "false") == "true" &&
        (
            !symmetry_applied ||
            get(result.input_summary, "representation_compatible", "false") == "true"
        ) &&
        wannierization_result_is_finite(result)
    solver_eligible =
        converged &&
        solver_validation_ready &&
        all(diagnostic -> diagnostic.severity != :error, result.diagnostics)
    production_eligible = false
    hard_gate_frozen = tryparse(Float64, get(result.input_summary, "hard_gate_frozen", "Inf"))
    numerical_validity = if numerical_quality == "NO_VALID_STATE"
        "NO_VALID_STATE"
    elseif numerical_quality == "INVALID_ACCEPTED_STATE"
        "INVALID_FROZEN"
    elseif isometry_before > 1.0e-8
        polar_repaired ? "WARNING_ISOMETRY_REPAIRED" : "WARNING_ISOMETRY"
    elseif something(hard_gate_frozen, Inf) > 1.0e-6
        "WARNING_FROZEN"
    else
        "VALID"
    end
    geometry = Dict(
        "wannier_center_policy" => "validate",
        "real_space_replica_policy" => "minimum_distance",
        "production_eligible" => production_eligible,
        "authoritative_hamiltonian" =>
            get(result.input_summary, "authoritative_hamiltonian", "native_dft"),
        "authoritative_hamiltonian_sha256" =>
            get(result.input_summary, "authoritative_hamiltonian_sha256", "LEGACY_NATIVE_DFT"),
        "scoped_production_eligible" =>
            production_eligible &&
            get(result.input_summary, "scoped_production_eligible", "false") == "true",
        "global_production_eligible" => false,
        "minimum_distance_materialized" => true,
        "mp_grid" => collect(something(result.wannier_chk).mp_grid),
        "wannier_center_tolerance" => 1.0e-8,
        "wigner_seitz_tolerance" => 1.0e-5,
        "wigner_seitz_search_size" => 3,
        "raw_wannier_centers_cartesian" => centers,
        "raw_wannier_centers_fractional" => fractional,
        "final_wannier_centers_cartesian" => centers,
        "final_wannier_centers_fractional" => fractional,
        "center_alignment_lattice_shifts" => zeros(Int, size(centers)),
        # The actual R vectors are in this same bundle. This is a location label,
        # not a content fingerprint or an assertion of external authentication.
        "replica_mapping_reference" => "embedded-materialized-r-vectors/no-content-authentication",
    )
    status_metadata = Dict(
        "operator_profile" => String(IO.resolved_operator_profile(operator_selection)),
        "requested_wannierization_mode" => String(config.input.wannierization_mode),
        "effective_wannierization_mode" => String(effective_wannierization_mode(config)),
        "representation_source" => String(representation_source(config)),
        "symmetry_constraints_applied" => symmetry_applied,
        "covariance_applicability" => symmetry_applied ? "APPLICABLE" : "NOT_APPLICABLE",
        "effective_symmetry_operation_count" =>
            parse(Int, get(result.input_summary, "effective_symmetry_operation_count", "0")),
        "effective_antiunitary_operation_count" =>
            parse(Int, get(result.input_summary, "effective_antiunitary_operation_count", "0")),
        "requested_initializer" => get(
            result.input_summary,
            "requested_initializer",
            String(config.solver.initialization),
        ),
        "effective_initializer" => get(
            result.input_summary,
            "effective_initializer",
            String(config.solver.initialization),
        ),
        "initializer_algorithm_version" =>
            get(result.input_summary, "initializer_algorithm_version", "NOT_RECORDED"),
        "initialization_status" =>
            get(result.input_summary, "initialization_status", "UNKNOWN"),
        "wannierization_status" => string(result.status),
        "solver_status" => get(result.input_summary, "solver_status", string(result.status)),
        "solver_convergence" => get(
            result.input_summary,
            "solver_convergence",
            converged ? "CONVERGED" : "UNKNOWN",
        ),
        "converged" => converged,
        "convergence_class" => converged ? "CONVERGED" : "NONCONVERGED",
        "model_availability" => model_availability,
        "construction_policy" => String(config.input.construction_policy),
        "construction_gate_records_json" => construction_gate_records,
        "quality_review_recommended" => quality_failed || numerical_warning || !converged,
        "construction_quality_failed" => quality_failed,
        "numerical_validity" => numerical_validity,
        "numerical_quality" => numerical_quality,
        "tb_export_status" => export_status,
        "authoritative_hamiltonian" => band_hamiltonian.authority,
        "scoped_production_eligible" =>
            production_eligible &&
            get(result.input_summary, "scoped_production_eligible", "false") == "true",
        "global_production_eligible" => false,
        "energy_shift_qualification" => get(
            result.input_summary,
            "energy_shift_qualification",
            "legacy_energy_shift_hard_gate",
        ),
        "maximum_energy_shift_audit_reference_ev" => get(
            result.input_summary,
            "maximum_energy_shift_audit_reference_ev",
            "NOT_APPLICABLE",
        ),
        "rms_energy_shift_audit_reference_ev" =>
            get(result.input_summary, "rms_energy_shift_audit_reference_ev", "NOT_APPLICABLE"),
        "target_energy_shift_audit_status" =>
            get(result.input_summary, "target_energy_shift_audit_status", "NOT_APPLICABLE"),
        "symmetrized_parent_energy_shift_audit_status" => get(
            result.input_summary,
            "symmetrized_parent_energy_shift_audit_status",
            "NOT_APPLICABLE",
        ),
        "residual_gate_phase" =>
            get(result.input_summary, "residual_gate_phase", "legacy_pre_symmetrization"),
        "raw_preflight_diagnostic_status" => get(
            result.input_summary,
            "raw_preflight_diagnostic_status",
            "NOT_AVAILABLE_LEGACY_SCHEMA",
        ),
        "native_difference_qualification" =>
            get(result.input_summary, "native_difference_qualification", "legacy_hard_gate"),
        "native_difference_audit_status" =>
            get(result.input_summary, "native_difference_audit_status", "NOT_APPLICABLE"),
        "qualification_scope" =>
            get(result.input_summary, "qualification_scope", "full_parent"),
        "target_authority" => get(result.input_summary, "target_authority", "NOT_APPLICABLE"),
        "parent_audit_policy" =>
            get(result.input_summary, "parent_audit_policy", "legacy_hard_gate"),
        "disentanglement_outer_mask_definition" =>
            get(result.input_summary, "disentanglement_outer_mask_definition", "NOT_RECORDED"),
        "disentanglement_frozen_mask_definition" =>
            get(result.input_summary, "disentanglement_frozen_mask_definition", "NOT_RECORDED"),
        "target_subspace_contract_definition" =>
            get(result.input_summary, "target_subspace_contract_definition", "NOT_RECORDED"),
        "target_leakage_semantics" => get(
            result.input_summary,
            "target_leakage_semantics",
            "LEGACY_AMPLITUDE_LEAKAGE_CONTRACT",
        ),
        "target_leakage_formula_definition" =>
            get(result.input_summary, "target_leakage_formula_definition", "NOT_RECORDED"),
        "target_leakage_threshold" =>
            get(result.input_summary, "target_leakage_threshold", "NOT_RECORDED"),
        "target_anchor" => get(result.input_summary, "target_anchor", "NOT_APPLICABLE"),
        "target_complement_completion" =>
            get(result.input_summary, "target_complement_completion", "NOT_APPLICABLE"),
        "target_complement_max_element_ev" =>
            get(result.input_summary, "target_complement_max_element_ev", "NOT_APPLICABLE"),
        "auxiliary_parent_qualification" =>
            get(result.input_summary, "auxiliary_parent_qualification", "legacy_hard_gate"),
        "symmetrized_target_subspace_status" =>
            get(result.input_summary, "symmetrized_target_subspace_status", "NOT_APPLICABLE"),
        "auxiliary_parent_audit_status" =>
            get(result.input_summary, "auxiliary_parent_audit_status", "NOT_APPLICABLE"),
        "target_scope_production_eligible" =>
            get(result.input_summary, "target_scope_production_eligible", "false") == "true",
        "artifact_class" => converged ? "STANDARD" : "NONCONVERGED_STANDARD",
        "production_eligible" => production_eligible,
        "quality_review_recommended" => quality_failed || !converged,
        "physics_qualification" => "NOT_ESTABLISHED_BY_SINGLE_CALCULATION",
        "tb_usability" =>
            model_availability == "AVAILABLE" ? "MODEL_AVAILABLE" :
            "MODEL_AVAILABLE_WITH_QUALITY_WARNINGS",
        "solver_validation_ready" => solver_validation_ready,
        "stopping_reason" => checkpoint_stopping_reason(result),
        "iterations_completed" => isempty(result.history) ? 0 : last(result.history).iteration,
        "last_attempted_iteration" =>
            parse(Int, get(result.input_summary, "last_attempted_iteration", "-1")),
        "last_accepted_iteration" =>
            parse(Int, get(result.input_summary, "last_accepted_iteration", "-1")),
        "last_persisted_iteration" =>
            parse(Int, get(result.input_summary, "last_persisted_iteration", "-1")),
        # HDF operator manifests use NaN for an unmeasured optional numeric
        # scalar; the human status remains SKIPPED_ZERO_STEPS/NOT_RUN.
        "convergence_metric" =>
            isempty(result.history) ? NaN : last(result.history).spread_standard_deviation,
        "convergence_tolerance" => config.solver.stage_controls.conv_tol,
        "checkpoint_publication_identity" => "",
        "input_sha256" => get(result.input_summary, "input_sha256", ""),
        "spread_metric" => get(result.input_summary, "spread_metric", ""),
        "amn_sha256" => get(result.input_summary, "amn_sha256", ""),
        "projection_basis_definition" =>
            get(result.input_summary, "projection_basis_definition", ""),
        "finite_difference_stencil_sha256" =>
            get(result.input_summary, "finite_difference_stencil_sha256", ""),
        "optimizer_strategy" => get(result.input_summary, "optimizer_strategy", ""),
        "projector_residual" =>
            isempty(result.history) || last(result.history).diagnostics === nothing ? NaN :
            something(last(result.history).diagnostics).projector_residual,
        "z_residual" =>
            isempty(result.history) || last(result.history).diagnostics === nothing ? NaN :
            something(last(result.history).diagnostics).z_residual,
        (
            isempty(result.history) ||
            last(result.history).diagnostics === nothing ||
            !hasproperty(something(last(result.history).diagnostics), :u_residual) ?
            Pair{String, Any}[] :
            ["u_residual" => something(last(result.history).diagnostics).u_residual]
        )...,
        "isometry_before_export" => isometry_before,
        "isometry_after_export" => isometry_after,
        "polar_repaired_for_export" => polar_repaired,
        "frozen_residual" => something(hard_gate_frozen, Inf),
        "hamiltonian_hermiticity_residual" => hamiltonian_hermiticity,
        "position_hermiticity_residual" => position_hermiticity,
        "export_readback_validation" => "NOT_PERFORMED",
        "hamiltonian_fourier_roundtrip_residual" =>
            construction_diagnostics["hamiltonian_fourier_roundtrip_residual"],
        "position_fourier_roundtrip_residual" =>
            construction_diagnostics["position_fourier_roundtrip_residual"],
        "fourier_roundtrip_gate_tolerance" =>
            construction_diagnostics["fourier_roundtrip_gate_tolerance"],
    )
    ordinary_report = _ordinary_accepted_state_report(result, config)
    merge!(status_metadata, ordinary_report)
    temporary, io = mktemp(dirname(paths.packed); cleanup = false)
    close(io)
    completed = false
    local profile_operators
    try
        profile_operators, profile_provenance = _assemble_wannierization_operator_profile(
            export_model,
            prepared,
            mmn,
            config,
            band_hamiltonian,
            operator_symmetry_plan,
            target_contract = operator_target_contract,
        )
        if _profile_export_numerical_checks!(export_checks, policy, profile_provenance)
            numerical_quality = "NUMERICAL_WARNING"
            export_status = "EXPORTED_WITH_WARNING"
            quality_failed = true
            model_availability = "AVAILABLE_WITH_QUALITY_WARNINGS"
            status_metadata["numerical_quality"] = numerical_quality
            status_metadata["tb_export_status"] = export_status
            status_metadata["model_availability"] = model_availability
            status_metadata["construction_quality_failed"] = true
            status_metadata["physics_qualification"] = "NOT_ESTABLISHED_BY_SINGLE_CALCULATION"
        end
        # Include Full audits once, after assembly, in both persisted and returned records.
        construction_gate_records = String(
            JSON3.write(
                vcat(
                    [
                        Dict(
                            "code" => String(d.code),
                            "severity" => String(d.severity),
                            "message" => d.message,
                            "context" => d.context,
                        ) for d in result.diagnostics
                    ],
                    export_checks,
                ),
            ),
        )
        status_metadata["construction_gate_records_json"] = construction_gate_records
        bundle_geometry = geometry
        bundle_status_metadata = status_metadata
        if Core.REAL_SPACE_SPIN in IO.resolved_operator_inventory(operator_selection)
            qualification = profile_provenance["operator_qualification"]
            families = qualification["families"]
            spin_family = families["spin"]
            spin_status = String(spin_family["overall"])
            spin_reason = String(spin_family["reason"])
            if get(spin_family, "pair_wigner_seitz_roundtrip_status", "NOT_APPLICABLE") ==
               "NUMERICAL_WARNING" ||
               get(profile_provenance, "uiu_generation_status", "PASS") == "EXPORTED_WITH_WARNING"
                numerical_quality = "NUMERICAL_WARNING"
                export_status = "EXPORTED_WITH_WARNING"
                quality_failed = true
                model_availability = "AVAILABLE_WITH_QUALITY_WARNINGS"
                status_metadata["numerical_quality"] = numerical_quality
                status_metadata["tb_export_status"] = export_status
                status_metadata["model_availability"] = model_availability
                status_metadata["construction_quality_failed"] = true
                status_metadata["physics_qualification"] = "NOT_ESTABLISHED_BY_SINGLE_CALCULATION"
            end
            if spin_status != "PASS"
                bundle_geometry = copy(geometry)
                bundle_geometry["production_eligible"] = false
                bundle_geometry["scoped_production_eligible"] = false
                bundle_status_metadata = copy(status_metadata)
                bundle_status_metadata["production_eligible"] = false
                bundle_status_metadata["scoped_production_eligible"] = false
                bundle_status_metadata["quality_review_recommended"] = true
                bundle_status_metadata["physics_qualification"] = "NOT_ESTABLISHED_BY_SINGLE_CALCULATION"
                bundle_status_metadata["spin_family_qualification"] = spin_status
                bundle_status_metadata["spin_family_qualification_reason"] = spin_reason
            end
        end
        receipt = IO.write_real_space_operator_bundle(
            temporary,
            export_model.lattice,
            export_model.r_degeneracies,
            profile_operators;
            overwrite = true,
            content_authentication = false,
            return_receipt = true,
            provenance = merge(
                Dict(
                    "source" => "WannierNLQG Wannierization",
                    "effective_wannierization_mode" =>
                        String(effective_wannierization_mode(config)),
                    "authoritative_hamiltonian" => band_hamiltonian.authority,
                    "authoritative_hamiltonian_definition" => band_hamiltonian.definition,
                    "authoritative_hamiltonian_algorithm_version" =>
                        band_hamiltonian.algorithm_version,
                    "authoritative_hamiltonian_input_definitions" =>
                        copy(band_hamiltonian.input_definitions),
                    "authoritative_hamiltonian_policy_definition" =>
                        star_authoritative_hamiltonian_definition(
                            config.input.authoritative_hamiltonian,
                        ),
                ),
                profile_provenance,
            ),
            geometry = bundle_geometry,
            eligibility = bundle_status_metadata,
        )
        packed_publication_identity = receipt.publication_identity
        if receipt.numerical_quality == "NUMERICAL_WARNING"
            numerical_quality = "NUMERICAL_WARNING"
            export_status = "EXPORTED_WITH_WARNING"
            quality_failed = true
            model_availability = "AVAILABLE_WITH_QUALITY_WARNINGS"
            for metadata in (status_metadata, bundle_status_metadata)
                merge!(
                    metadata,
                    Dict(
                        "numerical_quality"=>numerical_quality,
                        "tb_export_status"=>export_status,
                        "construction_quality_failed"=>true,
                        "model_availability"=>model_availability,
                        "production_eligible"=>false,
                        "physics_qualification"=>"NOT_ESTABLISHED_BY_SINGLE_CALCULATION",
                    ),
                )
            end
        end
        keep_tb && _atomic_wannier_tb(tb_path, model; comment)
        # Writer close/commit succeeded; retain atomic final publication, without payload readback.
        keep_tb && mv(tb_path, paths.wannier; force = policy != :standard)
        policy==:standard &&
            ispath(paths.packed) &&
            error("refusing to overwrite an existing successful Packed output")
        IO.atomic_file_replace(temporary, paths.packed)
        isfile(temporary*".commit.toml") && rm(temporary*".commit.toml")
        completed = true
    finally
        # Failed temporary payloads remain evidence, never recognized as published outputs.
        completed && !keep_tb && isfile(tb_path) && rm(tb_path; force = true)
    end
    text_metadata = ""
    exported = (
        paths.packed,
        keep_tb ? paths.wannier : nothing,
        Dict(
            "numerical_quality" => numerical_quality,
            "tb_export_status" => export_status,
            "export_isometry_before" => string(isometry_before),
            "export_isometry_after" => string(isometry_after),
            "export_polar_repaired" => string(polar_repaired),
            "tb_hamiltonian_hermiticity" => string(hamiltonian_hermiticity),
            "tb_position_hermiticity" => string(position_hermiticity),
            "export_readback_validation" => "NOT_PERFORMED",
            "tb_hamiltonian_fourier_roundtrip_residual" =>
                string(construction_diagnostics["hamiltonian_fourier_roundtrip_residual"]),
            "tb_position_fourier_roundtrip_residual" =>
                string(construction_diagnostics["position_fourier_roundtrip_residual"]),
            "tb_fourier_roundtrip_gate_tolerance" =>
                string(construction_diagnostics["fourier_roundtrip_gate_tolerance"]),
            "model_availability" => model_availability,
            "construction_policy" => String(config.input.construction_policy),
            "construction_gate_records_json" => construction_gate_records,
            "wannierization_quality_metadata" => text_metadata,
            "quality_review_recommended" =>
                string(quality_failed || numerical_warning || !converged),
            "construction_quality_failed" => string(quality_failed),
            ordinary_report...,
        ),
    )
    return return_operators ? (exported..., profile_operators) : exported
end

# Atomically retain the latest fully eligible checkpoint.
function _atomic_checkpoint_copy(source, destination)
    temporary, io = mktemp(dirname(destination); cleanup = false)
    close(io)
    completed = false
    try
        observed=IO.with_scientific_source(realpath(source)) do filename
            published=read_checkpoint_publication(filename)
            cp(filename, temporary; force = true)
            published
        end
        published=observed.value
        filesize(temporary)==observed.state.bytes || error("IncompleteAcceptedCheckpointCopy")
        schema,
        version,
        identity=HDF5.h5open(temporary, "r") do handle
            attributes=HDF5.attributes(handle)
            (
                String(read(attributes["schema"])),
                String(read(attributes["schema_version"])),
                String(required_attribute(handle, "publication_identity")),
            )
        end
        identity==published.identity || error("AcceptedCheckpointCopyPublicationMismatch")
        IO.atomic_file_replace(temporary, destination)
        IO.write_scientific_file_publication(
            destination;
            artifact_schema = schema,
            artifact_version = version,
            publication_identity = identity,
        )
        completed = true
    finally
        !completed && isfile(temporary) && rm(temporary; force = true)
    end
    return destination
end

# Bind one already validated packed TB to the exact terminal checkpoint without
# changing its scientific operator payload.  Both containers must already hold
# the same canonical final-TB qualification payload.
function _bind_packed_checkpoint_publication!(packed_path, checkpoint_path)
    packed_publication=IO.read_real_space_operator_bundle_manifest(packed_path).publication_identity
    published = read_checkpoint_publication(checkpoint_path)
    identity = published.identity
    HDF5.h5open(packed_path, "r+") do handle
        qualification = read_tb_symmetry_qualification_group(
            handle;
            missing_reason = "PACKED_TB_QUALIFICATION_FIELD_ABSENT",
        )
        same_tb_symmetry_qualification(qualification, published.qualification) || throw(
            ArgumentError(
                "packed TB and terminal checkpoint final-TB qualification payloads disagree",
            ),
        )
        root_attributes = HDF5.attributes(handle)
        # Retire an obsolete reference, never write a generation into a SHA field.
        haskey(root_attributes, "checkpoint_sha256") &&
            HDF5.delete_attribute(handle, "checkpoint_sha256")
        haskey(root_attributes, "checkpoint_publication_identity") &&
            HDF5.delete_attribute(handle, "checkpoint_publication_identity")
        root_attributes["checkpoint_publication_identity"] = identity
        if haskey(handle, "diagnostics")
            diagnostics = handle["diagnostics"]
            attributes = HDF5.attributes(diagnostics)
            haskey(attributes, "checkpoint_sha256") &&
                HDF5.delete_attribute(diagnostics, "checkpoint_sha256")
            haskey(attributes, "checkpoint_publication_identity") &&
                HDF5.delete_attribute(diagnostics, "checkpoint_publication_identity")
            attributes["checkpoint_publication_identity"] = identity
        end
        HDF5.flush(handle)
    end
    IO.write_scientific_file_publication(
        packed_path;
        artifact_schema = IO.OPERATOR_BUNDLE_SCHEMA,
        artifact_version = IO.OPERATOR_BUNDLE_SCHEMA_VERSION,
        publication_identity = packed_publication,
    )
    return identity
end

# Recompute diagnostics from an accepted frame, including export-only legacy checkpoints.
# No physical sewing information is inferred from identity bookkeeping or WIN target actions.
function _ordinary_accepted_state_report(result, config; representation = nothing)
    effective_wannierization_mode(config) == :ordinary || return Dict{String, String}()
    isempty(result.v_matrix) && return Dict(
        "ordinary_accepted_frame_diagnostic_status" => "NOT_RUN",
        "ordinary_accepted_frame_diagnostic_reason" => "accepted V matrix is unavailable",
        "ordinary_physical_band_sewing_status" => "NOT_RUN",
        "ordinary_physical_band_sewing_reason" => "nontrivial physical band sewing overlaps are unavailable",
    )
    isometry = 0.0
    idempotence = 0.0
    for kpoint in axes(result.v_matrix, 3)
        frame = @view result.v_matrix[:, :, kpoint]
        isometry = max(isometry, maximum(abs, frame' * frame - I; init = 0.0))
        projector = frame * frame'
        idempotence = max(idempotence, maximum(abs, projector * projector - projector; init = 0.0))
    end
    all(isfinite, (isometry, idempotence)) || throw(
        ArgumentError("ordinary accepted-frame report contains nonfinite scientific residuals"),
    )
    report = Dict(
        "ordinary_accepted_frame_isometry_residual" => string(isometry),
        "ordinary_accepted_projector_idempotence_residual" => string(idempotence),
        "ordinary_accepted_frame_diagnostic_source" => "ACCEPTED_V_MATRIX_RECOMPUTED",
        "ordinary_accepted_frame_diagnostic_status" => "MEASURED",
        "ordinary_physical_band_sewing_status" => "NOT_RUN",
        "ordinary_physical_band_sewing_reason" => "nontrivial physical band sewing overlaps are unavailable; accepted frames and WIN target actions do not determine band-representation covariance",
    )
    if representation !== nothing &&
       get(representation.conventions, "sewing_role", "") == "identity_only_no_symmetry"
        residual = 0.0
        for kpoint in axes(representation.sewing_matrices, 4)
            sewing = @view representation.sewing_matrices[:, :, 1, kpoint]
            residual = max(residual, maximum(abs, sewing' * sewing - I; init = 0.0))
        end
        isfinite(residual) || throw(ArgumentError("ordinary identity sewing report is nonfinite"))
        report["ordinary_identity_sewing_unitarity_residual"] = string(residual)
        report["ordinary_identity_sewing_measurement_scope"] = "IDENTITY_BOOKKEEPING_ONLY"
    end
    return report
end

# Append the terminal summary after every output decision is known.
function _legacy_write_wannierization_final(
    io,
    result,
    config::WannierizationConfig,
    artifacts;
    wall_time,
    allocated_bytes,
    gc_time,
    peak_rss_bytes = Sys.maxrss(),
)
    converged = result.status in (COMPLETED, COMPLETED_WITH_WARNINGS)
    production_eligible = wannierization_production_eligible(result)
    _write_report_section(io, "CONSTRUCTION GATE AND QUALITY SUMMARY")
    if effective_wannierization_mode(config) != :ordinary
        println(io, "[SOLVER PROJECTOR COVARIANCE]\n")
        println(
            io,
            "applicability = $(get(result.input_summary, "covariance_applicability", "UNKNOWN"))",
        )
        println(
            io,
            "maximum_covariance_error = $(isempty(result.history) ? "NOT_RUN" : string(last(result.history).maximum_covariance_error))",
        )
        println(
            io,
            "threshold = $(get(result.input_summary, "projector_covariance_tolerance", "NOT_RECORDED"))",
        )
        println(io, "source = solver_iteration_history")
        println(io, "\n[REPRESENTATION AND GROUP-LAW DIAGNOSTICS]\n")
        for key in (
            "representation_compatible",
            "representation_assessment_status",
            "gate_definition_status",
            "maximum_group_law_residual",
            "maximum_kramers_residual",
            "representation_sha256",
        )
            println(io, "$(key) = $(get(result.input_summary, key, "NOT_RECORDED"))")
        end
        println(io, "source = band_representation_preflight")
    end
    if effective_wannierization_mode(config) == :ordinary
        report = merge(result.input_summary, _ordinary_accepted_state_report(result, config))
        if report["ordinary_accepted_frame_diagnostic_status"] == "MEASURED"
            println(io, "[ACCEPTED FRAME DIAGNOSTICS]\n")
        end
        for key in (
            "ordinary_accepted_frame_isometry_residual",
            "ordinary_accepted_projector_idempotence_residual",
            "ordinary_accepted_frame_diagnostic_source",
            "ordinary_accepted_frame_diagnostic_status",
            "ordinary_identity_sewing_unitarity_residual",
            "ordinary_identity_sewing_measurement_scope",
        )
            report["ordinary_accepted_frame_diagnostic_status"] == "MEASURED" || continue
            haskey(report, key) && _write_report_field(io, key, report[key])
        end
    end
    diagnostic_groups = _diagnostic_groups(result.diagnostics)
    println(io, "\nIMPORTANT QUALITY RECORDS\n")
    _write_diagnostic_summary(io, diagnostic_groups)

    _write_report_section(io, "FINAL SPREADING")
    final_total =
        isempty(result.history) ? sum(result.spreads_angstrom2) : last(result.history).spread_total
    final_sum = sum(result.spreads_angstrom2)
    localization_steps =
        something(tryparse(Int, get(result.input_summary, "localization_steps", "0")), 0)
    localization_evaluated =
        config.solver.acceleration.schedule != :two_stage || localization_steps > 0
    _write_report_field(
        io,
        "accepted_iteration",
        isempty(result.history) ? 0 : last(result.history).iteration,
    )
    _write_report_field(
        io,
        "final_total_spreading",
        localization_evaluated ? "$(final_total) angstrom^2" : "NOT_RUN",
    )
    _write_report_field(
        io,
        "final_mean_state_spreading",
        localization_evaluated ?
        "$(isempty(result.spreads_angstrom2) ? 0.0 : final_sum / length(result.spreads_angstrom2)) angstrom^2" :
        "NOT_RUN",
    )
    _write_report_field(
        io,
        "final_minimum_state_spreading",
        !localization_evaluated || isempty(result.spreads_angstrom2) ? "NOT_RUN" :
        "$(minimum(result.spreads_angstrom2)) angstrom^2",
    )
    _write_report_field(
        io,
        "final_maximum_state_spreading",
        !localization_evaluated || isempty(result.spreads_angstrom2) ? "NOT_RUN" :
        "$(maximum(result.spreads_angstrom2)) angstrom^2",
    )
    _write_report_field(
        io,
        "final_convergence_metric",
        !localization_evaluated || isempty(result.history) ? "NOT_RUN" :
        last(result.history).spread_standard_deviation,
    )
    _write_report_field(io, "convergence_tolerance", config.solver.stage_controls.conv_tol)
    println(io)
    if localization_evaluated
        _write_spreading_table(
            io,
            result.spreads_angstrom2;
            heading = "Per-Wannier-state final spreading (angstrom^2)",
        )
        _write_report_field(io, "sum_of_final_state_spreadings", "$(final_sum) angstrom^2")
        _write_report_field(io, "total_minus_state_sum", "$(final_total - final_sum) angstrom^2")
    else
        _write_report_field(io, "per_wannier_state_spreading", "NOT_EVALUATED")
        _write_report_field(io, "sum_of_final_state_spreadings", "NOT_RUN")
        _write_report_field(io, "total_minus_state_sum", "NOT_RUN")
    end

    qualification = result.tb_symmetry_qualification
    show_tb_symmetry = something(
        config.output.final_tb_symmetry_report_enabled,
        effective_wannierization_mode(config) == :symmetry_adapted,
    )
    if show_tb_symmetry
        _write_report_section(io, "FINAL TB SYMMETRY MEASUREMENTS")
        _write_report_field(io, "overall", qualification.overall)
        _write_report_field(io, "reason", qualification.reason)
        _write_report_field(io, "content_authentication", "NOT_PERFORMED")
        qualification_source =
            qualification.overall == "NOT_RUN" ? "qualification_not_run" :
            qualification.reason == "QUALIFICATION_EVALUATION_FAILED" ?
            "final_exported_tb_qualification_evaluation_failed" :
            artifacts.packed_hdf5 === nothing ? "qualification_payload_without_exported_tb" :
            "final_exported_and_read_back_tb"
        _write_report_field(io, "source", qualification_source)
        _write_tb_scope(
            io,
            result.input_summary;
            omit_unavailable = effective_wannierization_mode(config) == :ordinary,
        )
        _write_tb_report(
            io,
            qualification;
            measured_only = effective_wannierization_mode(config) == :ordinary,
        )
    end

    _write_report_section(io, "FINAL STATUS")
    println(io, "status = $(result.status)")
    println(
        io,
        "requested_wannierization_mode = $(get(result.input_summary, "requested_wannierization_mode", string(config.input.wannierization_mode)))",
    )
    println(
        io,
        "effective_wannierization_mode = $(get(() -> string(effective_wannierization_mode(config)), result.input_summary, "effective_wannierization_mode"))",
    )
    println(
        io,
        "representation_source = $(get(() -> string(representation_source(config)), result.input_summary, "representation_source"))",
    )
    println(
        io,
        "symmetry_constraints_applied = $(get(result.input_summary, "symmetry_constraints_applied", "NOT_RECORDED"))",
    )
    println(io, "stopping_reason = $(checkpoint_stopping_reason(result))")
    println(io, "converged = $(converged)")
    quality_failed = get(result.input_summary, "construction_quality_failed", "false") == "true"
    model_availability = get(
        result.input_summary,
        "model_availability",
        get(result.input_summary, "tb_export_status", "NOT_EXPORTED") == "NOT_EXPORTED" ?
        "UNAVAILABLE" :
        quality_failed || !converged ? "AVAILABLE_WITH_QUALITY_WARNINGS" : "AVAILABLE",
    )
    println(io, "model_availability = $(model_availability)")
    println(io, "measured_quality_warning = $(quality_failed)")
    println(io, "tb_symmetry = $(qualification.overall)")
    println(
        io,
        "accepted_iteration = $(isempty(result.history) ? 0 : last(result.history).iteration)",
    )
    println(
        io,
        "convergence_metric = $(isempty(result.history) ? "NOT_RUN" : last(result.history).spread_standard_deviation)",
    )
    println(io, "convergence_tolerance = $(config.solver.stage_controls.conv_tol)")
    println(io, "wall_time_seconds = $(wall_time)")
    println(io, "allocated_bytes = $(allocated_bytes)")
    println(io, "gc_time_seconds = $(gc_time)")
    println(io, "peak_rss_bytes = $(peak_rss_bytes)")
    root =
        artifacts.wannierization_log === nothing ? pwd() :
        dirname(abspath(artifacts.wannierization_log))
    println(io, "artifacts_root = .")
    for name in (
        :checkpoint_hdf5,
        :validated_checkpoint_hdf5,
        :wannierization_log,
        :packed_hdf5,
        :model_tb,
        :tb_symmetry_json,
    )
        path = getproperty(artifacts, name)
        println(io, name, " = ", _report_path(path, root))
        if path !== nothing && isfile(path) && name != :wannierization_log
            println(io, "  size_bytes = ", filesize(path))
        end
    end
    println(io, "construction_policy = $(config.input.construction_policy)")
    metadata = get(result.input_summary, "wannierization_quality_metadata", "")
    println(
        io,
        "wannierization_quality_metadata = ",
        _report_path(isempty(metadata) ? nothing : metadata, root),
    )
    if artifacts.wannierization_log !== nothing
        stem =
            endswith(artifacts.wannierization_log, ".out") ?
            artifacts.wannierization_log[1:(end - 4)] : artifacts.wannierization_log
        diagnostic_path = _write_diagnostic_records(stem * "-diagnostics.jsonl", result.diagnostics)
        println(io, "Full diagnostic records: ", _report_path(diagnostic_path, root))
        println(io, "size_bytes = ", filesize(diagnostic_path))
    end
    flush(io)
    return nothing
end
