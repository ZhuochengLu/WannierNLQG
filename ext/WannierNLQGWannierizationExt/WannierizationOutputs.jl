# Resolve the neutral, fixed sibling output names from a requested checkpoint.
function _wannierization_output_paths(checkpoint::AbstractString)
    path = abspath(checkpoint)
    endswith(path, ".sawf.h5") && throw(
        ArgumentError(
            "checkpoint_hdf5 no longer accepts the legacy .sawf.h5 output suffix; " *
            "use .wannierization.h5",
        ),
    )
    endswith(path, ".wannierization.h5") ||
        throw(ArgumentError("checkpoint_hdf5 must end with .wannierization.h5"))
    stem = path[1:(end - length(".wannierization.h5"))]
    return (
        checkpoint = path,
        validated = stem * ".wannierization.validated.h5",
        log = stem * ".wannierization.out",
        packed = stem * ".wannierization-tb.h5",
        wannier90 = stem * "_wannierization_tb.dat",
        tb_symmetry_json = stem * ".wannierization-tb-symmetry.json",
    )
end

# Hash the package code and dependency lock that define one SAWF executable.
function _wannierization_source_sha256()
    root = normpath(joinpath(@__DIR__, "..", ".."))
    files = String[]
    for name in ("Project.toml", "Manifest.toml")
        path = joinpath(root, name)
        isfile(path) && push!(files, path)
    end
    for source_name in ("src", "ext")
        source_root = joinpath(root, source_name)
        for (directory, _, names) in walkdir(source_root), name in names
            path = joinpath(directory, name)
            isfile(path) && push!(files, path)
        end
    end
    sort!(files; by = path -> relpath(path, root))
    entries =
        ["$(replace(relpath(path, root), '\\' => '/'))\0$(sha256_file(path))" for path in files]
    return bytes2hex(SHA.sha256(codeunits(join(entries, '\n'))))
end

# Preserve the accepted Z/U stage boundary in every periodic checkpoint.  The
# observer snapshot is authoritative because it is emitted only after the
# solver has updated its stage state and qualification summary for that
# accepted iteration.  Terminal-only export gates remain fail closed.
function _periodic_stage_summary(snapshot)
    z_seal_class = String(snapshot.z_seal_class)
    qualified_z_seal = lowercase(string(snapshot.qualified_z_seal)) == "true"
    optimizer_phase = Symbol(snapshot.optimizer_phase)
    return Dict(
        "optimizer_phase" => String(optimizer_phase),
        "disentanglement_steps" => string(snapshot.z_steps),
        "localization_steps" => string(snapshot.u_steps),
        "disentanglement_convergence" => String(snapshot.disentanglement_convergence),
        "z_seal_class" => z_seal_class,
        "qualified_z_seal" => string(qualified_z_seal),
        "route_selection_eligible" => string(snapshot.route_selection_eligible),
        "localization_convergence" => String(snapshot.localization_convergence),
        "localization_qualification" => String(snapshot.localization_qualification),
        "model_qualification" => String(snapshot.model_qualification),
        # Every periodic checkpoint is an accepted but still in-progress state.
        # A formally sealed Z subspace does not make an unfinished U state a
        # production model.
        "diagnostic_only" => "true",
        "diagnostic_tb_export_eligible" => "false",
        "standard_tb_export_eligible" => "false",
        "global_production_eligible" => "false",
    )
end

# Create a checkpoint view of a complete iteration boundary.
function _periodic_result(
    snapshot,
    state,
    history,
    diagnostics,
    representation,
    config::SymmetryAdaptedWannierizationConfig,
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
        "manual_review_required" => string(config.input.construction_policy == :diagnostic),
        "manual_review_status" =>
            config.input.construction_policy == :diagnostic ? "REQUIRED" : "NOT_REQUESTED",
        "production_eligible" => "false",
        "requested_wannierization_mode" => String(config.input.wannierization_mode),
        "effective_wannierization_mode" => String(effective_wannierization_mode(config)),
        "representation_source" => String(representation_source(config)),
        "symmetry_constraints_applied" =>
            string(symmetry_constraints_applied(config, representation)),
        "algorithm_profile" => String(config.solver.algorithm_profile),
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
        "convergence_tolerance" => string(config.solver.convergence_tolerance),
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
        "representation_sha256" => state.representation_sha256,
        "restart_config_sha256" => state.config_sha256,
        "projection_basis_sha256" => state.projection_basis_sha256,
        "amn_sha256" => state.amn_sha256,
        "finite_difference_stencil_sha256" => something(state.stencil).digest,
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
        "target_subspace_contract_sha256",
        "target_leakage_semantics",
        "target_leakage_formula_sha256",
        "target_leakage_threshold",
        "wavefunction_gauge_backend",
        "wavefunction_gauge_hdf5_sha256",
    )
        haskey(representation.conventions, key) &&
            (input_summary[key] = representation.conventions[key])
    end
    for key in ("outer_mask_sha256", "frozen_mask_sha256")
        haskey(representation.conventions, key) &&
            (input_summary["disentanglement_" * key] = representation.conventions[key])
    end
    merge!(input_summary, _periodic_stage_summary(snapshot))
    merge!(input_summary, persisted_input_summary)
    any(d -> get(d.context, "gate_result", get(d.context, "result", "")) == "FAIL", diagnostics) &&
        (input_summary["construction_quality_failed"] = "true")
    config.input.construction_policy == :diagnostic &&
        (input_summary["model_qualification"] = "DIAGNOSTIC_ONLY")
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
function _write_tb_scope(io, summary)
    for key in (
        "qualification_scope",
        "target_anchor",
        "target_scope_production_eligible",
        "scoped_production_eligible",
        "global_production_eligible",
    )
        println(io, key, " = ", get(summary, key, "NOT_RECORDED"))
    end
end

# Render typed TB qualification metrics without changing their scientific status or precision.
function _write_tb_report(io, qualification)
    metrics = sort!(
        collect(qualification.metrics);
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
    for metric in metrics
        category, label, unit = get(_TB_REPORT_LABELS, metric.name, ("Other", metric.name, "?"))
        ratio = _metric_ratio(metric)
        ratio_text =
            ratio === nothing ? "N/A" : 0 < ratio < 0.001 ? "<0.001" : @sprintf("%.3f", ratio)
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
        metric.status == "PASS" ||
            isempty(metric.reason) ||
            println(io, "  reason: ", metric.reason)
    end
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

# Align one human-readable report field without changing its stored value.
function _write_report_field(io, name, value)
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
function _open_wannierization_log(
    path,
    config::SymmetryAdaptedWannierizationConfig,
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
    _write_report_field(io, "source_sha256", _wannierization_source_sha256())
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
    _write_report_field(io, "output_operator_profile", config.output.profile)
    _write_report_field(io, "parallel", config.solver.parallel)
    _write_report_field(io, "threads", Threads.nthreads())
    _write_report_field(
        io,
        "representation_compatible",
        symmetry_applied ? compatibility.passed : "NOT_APPLICABLE",
    )
    _write_report_field(io, "representation_sha256", compatibility.representation_sha256)
    input_entries = [
        "$(key)\0$(representation.input_sha256[key])" for
        key in sort!(collect(keys(representation.input_sha256)))
    ]
    _write_report_field(
        io,
        "input_sha256",
        bytes2hex(SHA.sha256(codeunits(join(input_entries, '\n')))),
    )
    _write_report_field(io, "restart_config_sha256", restart_config_sha256(config, representation))
    println(io, "\nInput files and integrity records:")
    for key in sort!(collect(keys(representation.input_sha256)))
        println(
            io,
            "  ",
            isabspath(key) ? _report_path(key, dirname(path)) : key,
            " sha256=",
            representation.input_sha256[key],
        )
    end
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
    _write_report_field(io, "maximum_total_steps", config.solver.max_iterations)
    _write_report_field(io, "progress_interval", config.runtime.progress_interval)
    _write_report_field(io, "checkpoint_interval", config.checkpoint.checkpoint_interval)
    _write_report_field(io, "convergence_window", config.solver.convergence_window)
    _write_report_field(io, "convergence_tolerance", config.solver.convergence_tolerance)
    _write_report_field(io, "z_mix_ratio", config.solver.z_mix_ratio)
    _write_report_field(io, "u_mix_ratio", config.solver.u_mix_ratio)
    _write_report_field(io, "u_inner_sweeps", config.solver.acceleration.u_inner_sweeps)
    _write_report_field(io, "optimizer_strategy", config.solver.acceleration.strategy)
    _write_report_field(io, "representation_tolerance", config.input.representation_tolerance)
    covariance_tolerance =
        !symmetry_constraints_applied(config, representation) ? "NOT_APPLICABLE" :
        string(projector_covariance_tolerance(config, compatibility))
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
function _write_wannierization_progress(
    io,
    snapshot,
    checkpoint_path,
    config::SymmetryAdaptedWannierizationConfig,
    representation = nothing,
)
    snapshot_value(name, default) =
        hasproperty(snapshot, name) ? getproperty(snapshot, name) : default
    symmetry_applied =
        representation === nothing ? symmetry_constraints_applied(config) :
        symmetry_constraints_applied(config, representation)
    println(io, "[ITERATION $(snapshot.iteration)]\n")
    _write_report_field(io, "stage", snapshot_value(:optimizer_phase, :NOT_RECORDED))
    _write_report_field(io, "accepted_iteration", snapshot.iteration)
    _write_report_field(io, "elapsed_seconds", snapshot.elapsed_seconds)
    println(io)
    _write_report_field(io, "total_spreading", "$(snapshot.spread_total) angstrom^2")
    _write_report_field(io, "convergence_metric", snapshot.convergence_metric)
    _write_report_field(io, "convergence_tolerance", config.solver.convergence_tolerance)
    println(
        io,
        "metric_to_tolerance_ratio = $(snapshot.convergence_metric / config.solver.convergence_tolerance)",
    )
    println(
        io,
        "projector_covariance_error = $(symmetry_applied ? string(snapshot.maximum_covariance_error) : "NOT_APPLICABLE")",
    )
    println(io, "little_group_iterations = $(snapshot.little_group_iterations)")
    println(io, "little_group_residual = $(snapshot.little_group_residual)")
    println(io, "projector_residual = $(snapshot_value(:projector_residual, NaN))")
    println(io, "z_residual = $(snapshot_value(:z_residual, NaN))")
    println(io, "u_residual = $(snapshot_value(:u_residual, NaN))")
    println(io, "normalized_residual_merit = $(snapshot_value(:normalized_residual_merit, NaN))")
    println(io, "actual_z_mix_ratio = $(snapshot_value(:z_mix_ratio, config.solver.z_mix_ratio))")
    println(io, "actual_u_mix_ratio = $(snapshot_value(:u_mix_ratio, config.solver.u_mix_ratio))")
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
    _write_spreading_table(io, snapshot.spreads)
    _write_report_field(io, "sum_of_state_spreadings", "$(sum(snapshot.spreads)) angstrom^2")
    _write_report_field(
        io,
        "total_minus_state_sum",
        "$(snapshot.spread_total - sum(snapshot.spreads)) angstrom^2",
    )
    flush(io)
    return nothing
end

# Return an observer that performs periodic atomic checkpoints before logging.
function _wannierization_observer(
    config::SymmetryAdaptedWannierizationConfig,
    representation,
    paths,
    io,
    persisted_input_summary::AbstractDict{String, String} = Dict{String, String}(),
)
    return function (snapshot, state, history, diagnostics)
        checkpoint_path = nothing
        if config.checkpoint.checkpoint_interval > 0 &&
           snapshot.iteration % config.checkpoint.checkpoint_interval == 0
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
                ),
            )
        end
        if config.runtime.progress_interval > 0 &&
           snapshot.iteration % config.runtime.progress_interval == 0
            _write_wannierization_progress(io, snapshot, checkpoint_path, config, representation)
        end
        return nothing
    end
end

# Write a file through a sibling temporary path and replace it only after close.
function _atomic_wannier_tb(filename, model; comment)
    path = abspath(filename)
    mkpath(dirname(path))
    temporary, io = mktemp(dirname(path); cleanup = false)
    close(io)
    completed = false
    try
        write_wannier_tb(temporary, model; comment, overwrite = true)
        mv(temporary, path; force = true)
        completed = true
    finally
        !completed && isfile(temporary) && rm(temporary; force = true)
    end
    return path
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

# Prepare one accepted state for diagnostic export without changing its Bloch
# subspace. Ordinary no-symmetry frames may receive a right polar repair;
# independently repaired magnetic SAWF frames are rejected because that could
# break target-gauge covariance.
function _prepare_wannierization_tb_state(result, config::SymmetryAdaptedWannierizationConfig)
    result.restart_state === nothing && return result, "NO_VALID_STATE", Inf, Inf, false
    all(isfinite, result.v_matrix) || return result, "NO_VALID_STATE", Inf, Inf, false
    restart = something(result.restart_state)
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
        fixed_projector_tolerance =
            get(result.input_summary, "effective_algorithm_profile", "") ==
            "smv_fletcher_reeves_two_stage" ? 1.0e-10 : 1.0e-12
        projector_drift <= fixed_projector_tolerance || throw(
            ArgumentError(
                "accepted frame changed the sealed localization projector: drift=$(projector_drift)",
            ),
        )
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
    repaired = false
    prepared = result
    isometry_after = isometry_before
    if isometry_before > 1.0e-8
        effective_wannierization_mode(config) == :ordinary ||
            throw(ArgumentError("legacy SAWF state requires an independent polar repair"))
        repaired_values = similar(result.v_matrix)
        for kpoint in axes(result.v_matrix, 3)
            retracted = orthonormalize_columns(
                @view(result.v_matrix[:, :, kpoint]),
                min(config.input.representation_tolerance, 1.0e-10),
            )
            retracted === nothing &&
                throw(ArgumentError("ordinary Wannier frame cannot be polar-retracted"))
            repaired_values[:, :, kpoint] .= something(retracted)
        end
        isometry_after = maximum(
            maximum(
                abs,
                @view(repaired_values[:, :, kpoint])' * @view(repaired_values[:, :, kpoint]) -
                identity;
                init = 0.0,
            ) for kpoint in axes(repaired_values, 3)
        )
        isometry_after <= 1.0e-8 ||
            throw(ArgumentError("ordinary Wannier frame polar repair failed"))
        source = something(result.wannier_chk)
        chk = IO.WannierCHK(
            size(repaired_values, 1),
            size(repaired_values, 2),
            size(repaired_values, 3),
            source.mp_grid,
            source.kpt_red,
            source.real_lattice,
            source.recip_lattice,
            result.wannier_centers_cartesian,
            repaired_values,
        )
        prepared = WannierizationResult(
            result.status,
            repaired_values,
            result.wannier_centers_cartesian,
            result.spreads_angstrom2,
            result.history,
            result.diagnostics,
            result.input_summary,
            chk,
            result.checkpoint_file,
            result.restart_state,
            result.artifacts,
            result.initialization_report,
        )
        repaired = true
    end
    frozen_residual =
        something(tryparse(Float64, get(result.input_summary, "hard_gate_frozen", "Inf")), Inf)
    numerical_quality = if !isfinite(isometry_after)
        "NO_VALID_STATE"
    elseif frozen_residual > 1.0e-4
        "INVALID_DIAGNOSTIC"
    elseif isometry_before > 1.0e-8 || frozen_residual > 1.0e-6
        "WARNING"
    else
        "PASS"
    end
    return prepared, numerical_quality, isometry_before, isometry_after, repaired
end

const _DIAGNOSTIC_LINE_SEARCH_CODES = (
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

# Qualify only the last accepted solver boundary.  A rejected line-search trial
# never enters result.v_matrix/restart_state, so this gate cannot publish it.
function _diagnostic_nonconverged_tb_export_gate(
    result,
    config::SymmetryAdaptedWannierizationConfig,
)
    schedule = get(result.input_summary, "optimizer_schedule", "")
    schedule == String(config.solver.acceleration.schedule) || return (
        allowed = false,
        classification = "STRUCTURAL_FAILURE_UNAVAILABLE",
        reason = "SOLVER_SCHEDULE_IDENTITY_MISMATCH",
        minimum_rank = 0,
        required_rank = size(result.v_matrix, 2),
        isometry_residual = Inf,
    )
    diagnostic_construction = config.input.construction_policy == :diagnostic
    classification = if diagnostic_construction
        "ACCEPTED_STATE_DIAGNOSTIC"
    elseif result.status == MAX_ITERATIONS && schedule in ("two_stage", "joint")
        "MAX_ITERATIONS_DIAGNOSTIC"
    elseif result.status == LOCALIZATION_FAILED &&
           schedule in ("two_stage", "joint") &&
           get(result.input_summary, "solver_convergence", "") == "LINE_SEARCH_EXHAUSTED"
        "LINE_SEARCH_FAILED_DIAGNOSTIC"
    else
        return (
            allowed = false,
            classification = "STRUCTURAL_FAILURE_UNAVAILABLE",
            reason = "STATUS_NOT_DIAGNOSTIC_EXPORTABLE",
            minimum_rank = 0,
            required_rank = 0,
            isometry_residual = Inf,
        )
    end
    result.restart_state !== nothing &&
    result.wannier_chk !== nothing &&
    get(result.input_summary, "has_accepted_state", "false") == "true" || return (
        allowed = false,
        classification = "STRUCTURAL_FAILURE_UNAVAILABLE",
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
        classification = "STRUCTURAL_FAILURE_UNAVAILABLE",
        reason = "ACCEPTED_STATE_CHECKPOINT_MISMATCH",
        minimum_rank = 0,
        required_rank = size(result.v_matrix, 2),
        isometry_residual = Inf,
    )
    wannierization_result_is_finite(result) || return (
        allowed = false,
        classification = "STRUCTURAL_FAILURE_UNAVAILABLE",
        reason = "NONFINITE_ACCEPTED_STATE",
        minimum_rank = 0,
        required_rank = size(result.v_matrix, 2),
        isometry_residual = Inf,
    )
    nb, nw, nk = size(result.v_matrix)
    nb >= nw > 0 && nk > 0 || return (
        allowed = false,
        classification = "STRUCTURAL_FAILURE_UNAVAILABLE",
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
        classification = "STRUCTURAL_FAILURE_UNAVAILABLE",
        reason = "RANK_DEFICIENT_ACCEPTED_FRAME",
        minimum_rank,
        required_rank = nw,
        isometry_residual,
    )
    isometry_residual <= config.input.representation_tolerance || return (
        allowed = false,
        classification = "STRUCTURAL_FAILURE_UNAVAILABLE",
        reason = "ACCEPTED_FRAME_ORTHOGONALITY_FAILED",
        minimum_rank,
        required_rank = nw,
        isometry_residual,
    )
    if restart.fixed_subspace_projectors !== nothing || restart.fixed_subspace_frames !== nothing
        restart.fixed_subspace_projectors !== nothing &&
        restart.fixed_subspace_frames !== nothing || return (
            allowed = false,
            classification = "STRUCTURAL_FAILURE_UNAVAILABLE",
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
        fixed_projector_drift <= fixed_projector_tolerance || return (
            allowed = false,
            classification = "STRUCTURAL_FAILURE_UNAVAILABLE",
            reason = "FIXED_SUBSPACE_PROJECTOR_DRIFT",
            minimum_rank,
            required_rank = nw,
            isometry_residual,
        )
    end
    frozen_residual = _summary_residual(result.input_summary, "hard_gate_frozen")
    frozen_residual <= config.input.representation_tolerance || return (
        allowed = false,
        classification = "STRUCTURAL_FAILURE_UNAVAILABLE",
        reason = "FROZEN_EMBEDDING_FAILED",
        minimum_rank,
        required_rank = nw,
        isometry_residual,
    )
    if !diagnostic_construction &&
       get(result.input_summary, "symmetry_constraints_applied", "true") == "true"
        get(result.input_summary, "representation_compatible", "false") == "true" || return (
            allowed = false,
            classification = "STRUCTURAL_FAILURE_UNAVAILABLE",
            reason = "REPRESENTATION_NOT_COMPATIBLE",
            minimum_rank,
            required_rank = nw,
            isometry_residual,
        )
        covariance_tolerance =
            _summary_residual(result.input_summary, "projector_covariance_tolerance")
        covariance_residual = _summary_residual(result.input_summary, "hard_gate_covariance")
        target_residual = _summary_residual(result.input_summary, "hard_gate_target_symmetry")
        isfinite(covariance_tolerance) &&
        covariance_residual <= covariance_tolerance &&
        target_residual <= covariance_tolerance || return (
            allowed = false,
            classification = "STRUCTURAL_FAILURE_UNAVAILABLE",
            reason = "SYMMETRY_INVARIANT_FAILED",
            minimum_rank,
            required_rank = nw,
            isometry_residual,
        )
    end
    error_codes =
        [diagnostic.code for diagnostic in result.diagnostics if diagnostic.severity == :error]
    # Numerical/quality failures of later trials do not invalidate a retained
    # accepted boundary. Identity/integrity failures still prevent consumption.
    integrity_failure = any(error_codes) do code
        name = String(code)
        any(
            token -> occursin(token, name),
            (
                "SHA256",
                "CHECKSUM",
                "IDENTITY_MISMATCH",
                "GAUGE_MISMATCH",
                "PROVENANCE",
                "RESTART_SEMANTICS",
                "CHECKPOINT",
                "REFERENCE_MISMATCH",
            ),
        )
    end
    errors_allowed =
        diagnostic_construction ? !integrity_failure :
        classification == "LINE_SEARCH_FAILED_DIAGNOSTIC" ?
        !isempty(error_codes) && all(code -> code in _DIAGNOSTIC_LINE_SEARCH_CODES, error_codes) :
        isempty(error_codes)
    errors_allowed || return (
        allowed = false,
        classification = "STRUCTURAL_FAILURE_UNAVAILABLE",
        reason = "NON_LINE_SEARCH_ERROR_DIAGNOSTIC_PRESENT",
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

"""Return whether a nonconverged result passes the diagnostic TB structural gate."""
function _diagnostic_nonconverged_tb_export_allowed(
    result,
    config::SymmetryAdaptedWannierizationConfig,
)
    return _diagnostic_nonconverged_tb_export_gate(result, config).allowed
end

# Construct a narrowly scoped pre-export view for an export-only retry after the
# schema-5.5 metadata-forwarding defect.  The persisted failed result remains
# immutable: only the single known TB_EXPORT_FAILED diagnostic is removed, and
# every accepted-state structural gate is re-evaluated before the caller may
# retry into a new output directory.
function _schema_5_5_tb_export_retry_view(result, config::SymmetryAdaptedWannierizationConfig)
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
    get(summary, "diagnostic_classification", "") == "STRUCTURAL_FAILURE_UNAVAILABLE" ||
        throw(ArgumentError("TB_EXPORT_RETRY_REJECTED: failure classification differs"))
    occursin(expected_message, get(summary, "diagnostic_export_gate_reason", "")) ||
        throw(ArgumentError("TB_EXPORT_RETRY_REJECTED: failure reason differs"))
    get(summary, "tb_export_status", "") == "NOT_EXPORTED" ||
        throw(ArgumentError("TB_EXPORT_RETRY_REJECTED: failed result already records an export"))
    retained = WannierizationDiagnostic[
        diagnostic for diagnostic in result.diagnostics if diagnostic !== failure
    ]
    summary["diagnostic_classification"] =
        result.status in (COMPLETED, COMPLETED_WITH_WARNINGS) ? "CONVERGED" :
        "MAX_ITERATIONS_DIAGNOSTIC"
    summary["diagnostic_export_gate_reason"] = "EXPORT_ONLY_SCHEMA_5_5_METADATA_RETRY"
    summary["tb_export_status"] = "NOT_EXPORTED"
    summary["numerical_quality"] = "PENDING_EXPORT_VALIDATION"
    retry_view =
        updated_wannierization_result(result; diagnostics = retained, input_summary = summary)
    gate = _diagnostic_nonconverged_tb_export_gate(retry_view, config)
    gate.allowed ||
        throw(ArgumentError("TB_EXPORT_RETRY_REJECTED: accepted-state gate failed: $(gate.reason)"))
    return retry_view
end

# Construct the only accepted export-retry view for the superseded generic
# spin q-to-R transform.  The persisted result is never mutated: the single
# historical failure must match its complete numeric fingerprint, after which
# every accepted-state structural gate is re-evaluated on the filtered view.
function _pair_wigner_seitz_spin_tb_export_retry_view(
    result,
    config::SymmetryAdaptedWannierizationConfig,
)
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
    get(summary, "diagnostic_classification", "") == "STRUCTURAL_FAILURE_UNAVAILABLE" ||
        throw(ArgumentError("TB_EXPORT_RETRY_REJECTED: failure classification differs"))
    get(summary, "diagnostic_export_gate_reason", "") == "TB_EXPORT_FAILED: $(failure.message)" ||
        throw(ArgumentError("TB_EXPORT_RETRY_REJECTED: failure reason differs"))
    get(summary, "tb_export_status", "") == "NOT_EXPORTED" ||
        throw(ArgumentError("TB_EXPORT_RETRY_REJECTED: failed result already records an export"))
    retained = WannierizationDiagnostic[
        diagnostic for diagnostic in result.diagnostics if diagnostic !== failure
    ]
    summary["diagnostic_classification"] =
        result.status in (COMPLETED, COMPLETED_WITH_WARNINGS) ? "CONVERGED" :
        "MAX_ITERATIONS_DIAGNOSTIC"
    summary["diagnostic_export_gate_reason"] = "EXPORT_ONLY_PAIR_WIGNER_SEITZ_SPIN_TRANSFORM_RETRY"
    summary["tb_export_status"] = "NOT_EXPORTED"
    summary["numerical_quality"] = "PENDING_EXPORT_VALIDATION"
    summary["export_retry_superseded_roundtrip_residual"] = string(something(residual))
    retry_view =
        updated_wannierization_result(result; diagnostics = retained, input_summary = summary)
    gate = _diagnostic_nonconverged_tb_export_gate(retry_view, config)
    gate.allowed ||
        throw(ArgumentError("TB_EXPORT_RETRY_REJECTED: accepted-state gate failed: $(gate.reason)"))
    return retry_view
end

# Bind human-review diagnostics to the exact text TB exported beside them.
function _write_construction_metadata_sidecar(path, packed, metadata)
    sidecar = path * ".diagnostics.json"
    payload = merge(
        metadata,
        Dict(
            "wannier90_tb_sha256" => bytes2hex(SHA.sha256(read(path))),
            "packed_scientific_content_sha256" =>
                IO.read_real_space_operator_bundle_manifest(packed).scientific_content_sha256,
        ),
    )
    temporary, io = mktemp(dirname(sidecar); cleanup = false)
    completed = false
    try
        JSON3.write(io, payload)
        close(io)
        parsed = JSON3.read(read(temporary, String))
        String(parsed.wannier90_tb_sha256) == payload["wannier90_tb_sha256"] ||
            error("diagnostic TB metadata sidecar failed readback")
        mv(temporary, sidecar; force = true)
        completed = true
    finally
        isopen(io) && close(io)
        !completed && isfile(temporary) && rm(temporary; force = true)
    end
    return sidecar
end

# Export one authoritative Packed HDF5 model through the formal TB reader.
function _export_wannierization_tb(
    result,
    eig,
    mmn,
    config::SymmetryAdaptedWannierizationConfig,
    paths,
    operator_symmetry_plan;
    operator_target_contract::Union{Nothing, WannierOperatorTargetContract} = nothing,
)
    converged = result.status in (COMPLETED, COMPLETED_WITH_WARNINGS)
    symmetry_applied = get(result.input_summary, "symmetry_constraints_applied", "true") == "true"
    diagnostic_gate = _diagnostic_nonconverged_tb_export_gate(result, config)
    diagnostic_nonconverged = diagnostic_gate.allowed
    (
        config.input.construction_policy == :diagnostic ? diagnostic_nonconverged :
        converged || diagnostic_nonconverged
    ) || throw(
        ArgumentError(
            "tight-binding export rejected status=$(result.status): $(diagnostic_gate.reason)",
        ),
    )
    wannierization_result_is_finite(result) ||
        throw(ArgumentError("tight-binding construction rejects non-finite SAWF arrays"))
    if config.output.profile == :full
        operator_target_contract === nothing &&
            throw(ArgumentError("OPERATOR_TARGET_CONTRACT_REQUIRED: full operator profile export"))
        recorded_contract = get(
            result.input_summary,
            "operator_profile_preflight_operator_target_contract_sha256",
            "MISSING",
        )
        recorded_contract == something(operator_target_contract).contract_sha256 || throw(
            ArgumentError(
                "OPERATOR_TARGET_CONTRACT_MISMATCH: terminal checkpoint does not bind the preflight target",
            ),
        )
        _validate_operator_profile_preflight_snapshot(result, config)
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
    model =
        build_wannier_tight_binding_model(prepared, band_hamiltonian, mmn; construction_diagnostics)
    all(isfinite, model.lattice) &&
    all(isfinite, model.hamiltonian_r) &&
    all(isfinite, model.position_r) || error("constructed TB contains non-finite arrays")
    hamiltonian_hermiticity = _real_space_hermiticity_error(model.hamiltonian_r, model.r_vectors)
    position_hermiticity = _real_space_hermiticity_error(model.position_r, model.r_vectors)
    hamiltonian_hermiticity <= 1.0e-8 ||
        error("constructed TB Hamiltonian violates R/-R Hermiticity")
    position_hermiticity <= 1.0e-8 || error("constructed TB position violates R/-R Hermiticity")
    hermiticity_warning = max(hamiltonian_hermiticity, position_hermiticity) > 1.0e-10
    hermiticity_warning && numerical_quality == "PASS" && (numerical_quality = "WARNING")
    keep_tb = config.output.write_wannier90_tb || :wannier90_tb in config.output.tb_output_formats
    exchange = if keep_tb
        paths.wannier90
    else
        temporary_exchange, temporary_io = mktemp(dirname(paths.packed); cleanup = false)
        close(temporary_io)
        temporary_exchange
    end
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
    diagnostic_classification =
        config.input.construction_policy == :diagnostic && quality_failed ?
        "DIAGNOSTIC_ONLY_QUALITY_FAILED" : converged ? "CONVERGED" : diagnostic_gate.classification
    comment =
        "Created by WannierNLQG $(mode_label); status=$(result.status); " *
        "classification=$(diagnostic_classification); converged=$(converged)"
    tb_path = _atomic_wannier_tb(exchange, model; comment)
    roundtrip = IO.read_wannier_tb(tb_path)
    maximum(abs, roundtrip.lattice - model.lattice; init = 0.0) <= 1.0e-12 ||
        error("written TB lattice failed round-trip validation")
    roundtrip.r_vectors == model.r_vectors ||
        error("written TB R vectors failed round-trip validation")
    roundtrip.r_degeneracies == model.r_degeneracies ||
        error("written TB degeneracies failed round-trip validation")
    maximum(abs, roundtrip.hamiltonian_r - model.hamiltonian_r; init = 0.0) <= 1.0e-12 ||
        error("written TB Hamiltonian failed round-trip validation")
    maximum(abs, roundtrip.position_r - model.position_r; init = 0.0) <= 1.0e-12 ||
        error("written TB position failed round-trip validation")
    centers = _tb_centers(roundtrip)
    center_delta_fractional =
        (centers - prepared.wannier_centers_cartesian) * inv(roundtrip.lattice)
    center_delta_fractional .-= round.(center_delta_fractional)
    maximum(abs, center_delta_fractional * roundtrip.lattice; init = 0.0) <= 1.0e-8 ||
        error("written TB Wannier centers failed modulo-lattice validation")
    fractional = centers * inv(roundtrip.lattice)
    export_status =
        converged && numerical_quality == "PASS" && !hermiticity_warning ? "EXPORTED" :
        "EXPORTED_WITH_WARNING"
    final_checkpoint_summary = merge(
        result.input_summary,
        Dict("numerical_quality" => numerical_quality, "tb_export_status" => export_status),
    )
    final_checkpoint_result =
        updated_wannierization_result(result; input_summary = final_checkpoint_summary)
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
    elseif numerical_quality == "INVALID_DIAGNOSTIC"
        "INVALID_FROZEN"
    elseif isometry_before > 1.0e-8
        "WARNING_ISOMETRY_REPAIRED"
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
        "replica_mapping_sha256" =>
            bytes2hex(SHA.sha256(reinterpret(UInt8, vec(roundtrip.r_vectors)))),
    )
    status_metadata = Dict(
        "operator_profile" => String(config.output.profile),
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
        "diagnostic_classification" => diagnostic_classification,
        "construction_policy" => String(config.input.construction_policy),
        "construction_gate_records_json" => construction_gate_records,
        "manual_review_required" => true,
        "construction_quality_failed" => quality_failed,
        "numerical_validity" => numerical_validity,
        "numerical_quality" => numerical_quality,
        "tb_export_status" => export_status,
        "authoritative_hamiltonian" => band_hamiltonian.authority,
        "authoritative_hamiltonian_sha256" => band_hamiltonian.digest,
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
        "disentanglement_outer_mask_sha256" =>
            get(result.input_summary, "disentanglement_outer_mask_sha256", "NOT_RECORDED"),
        "disentanglement_frozen_mask_sha256" =>
            get(result.input_summary, "disentanglement_frozen_mask_sha256", "NOT_RECORDED"),
        "target_subspace_contract_sha256" =>
            get(result.input_summary, "target_subspace_contract_sha256", "NOT_RECORDED"),
        "target_leakage_semantics" => get(
            result.input_summary,
            "target_leakage_semantics",
            "LEGACY_AMPLITUDE_LEAKAGE_CONTRACT",
        ),
        "target_leakage_formula_sha256" =>
            get(result.input_summary, "target_leakage_formula_sha256", "NOT_RECORDED"),
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
        "artifact_class" => converged ? "DIAGNOSTIC" : "NONCONVERGED_DIAGNOSTIC",
        "production_eligible" => production_eligible,
        "diagnostic_only" => !production_eligible,
        "physics_qualification" =>
            solver_eligible ? "PENDING_DOWNSTREAM_VALIDATION" : "PHYSICS_HOLD",
        "tb_usability" => "DIAGNOSTIC_MODEL_AVAILABLE",
        "solver_validation_ready" => solver_validation_ready,
        "stopping_reason" => checkpoint_stopping_reason(result),
        "iterations_completed" => isempty(result.history) ? 0 : last(result.history).iteration,
        "last_attempted_iteration" =>
            parse(Int, get(result.input_summary, "last_attempted_iteration", "-1")),
        "last_accepted_iteration" =>
            parse(Int, get(result.input_summary, "last_accepted_iteration", "-1")),
        "last_persisted_iteration" =>
            parse(Int, get(result.input_summary, "last_persisted_iteration", "-1")),
        "convergence_metric" =>
            isempty(result.history) ? "NOT_RUN" : last(result.history).spread_standard_deviation,
        "convergence_tolerance" => config.solver.convergence_tolerance,
        "checkpoint_sha256" => wannierization_checkpoint_sha256_v2_5(final_checkpoint_result),
        "input_sha256" => get(result.input_summary, "input_sha256", ""),
        "spread_metric" => get(result.input_summary, "spread_metric", ""),
        "amn_sha256" => get(result.input_summary, "amn_sha256", ""),
        "projection_basis_sha256" => get(result.input_summary, "projection_basis_sha256", ""),
        "finite_difference_stencil_sha256" =>
            get(result.input_summary, "finite_difference_stencil_sha256", ""),
        "optimizer_strategy" => get(result.input_summary, "optimizer_strategy", ""),
        "projector_residual" =>
            isempty(result.history) || last(result.history).diagnostics === nothing ? NaN :
            something(last(result.history).diagnostics).projector_residual,
        "z_residual" =>
            isempty(result.history) || last(result.history).diagnostics === nothing ? NaN :
            something(last(result.history).diagnostics).z_residual,
        "u_residual" =>
            isempty(result.history) || last(result.history).diagnostics === nothing ? NaN :
            something(last(result.history).diagnostics).u_residual,
        "isometry_before_export" => isometry_before,
        "isometry_after_export" => isometry_after,
        "polar_repaired_for_export" => polar_repaired,
        "frozen_residual" => something(hard_gate_frozen, Inf),
        "hamiltonian_hermiticity_residual" => hamiltonian_hermiticity,
        "position_hermiticity_residual" => position_hermiticity,
        "roundtrip_tolerance" => 1.0e-12,
        "hamiltonian_fourier_roundtrip_residual" =>
            construction_diagnostics["hamiltonian_fourier_roundtrip_residual"],
        "position_fourier_roundtrip_residual" =>
            construction_diagnostics["position_fourier_roundtrip_residual"],
        "fourier_roundtrip_gate_tolerance" =>
            construction_diagnostics["fourier_roundtrip_gate_tolerance"],
    )
    temporary, io = mktemp(dirname(paths.packed); cleanup = false)
    close(io)
    completed = false
    try
        profile_operators, profile_provenance = _assemble_wannierization_operator_profile(
            roundtrip,
            prepared,
            mmn,
            config,
            band_hamiltonian,
            operator_symmetry_plan,
            target_contract = operator_target_contract,
        )
        bundle_geometry = geometry
        bundle_status_metadata = status_metadata
        if config.output.profile in (:hamiltonian_position_spin, :full)
            qualification = profile_provenance["operator_qualification"]
            families = qualification["families"]
            spin_family = families["spin"]
            spin_status = String(spin_family["overall"])
            spin_reason = String(spin_family["reason"])
            if spin_status != "PASS"
                bundle_geometry = copy(geometry)
                bundle_geometry["production_eligible"] = false
                bundle_geometry["scoped_production_eligible"] = false
                bundle_status_metadata = copy(status_metadata)
                bundle_status_metadata["production_eligible"] = false
                bundle_status_metadata["scoped_production_eligible"] = false
                bundle_status_metadata["diagnostic_only"] = true
                bundle_status_metadata["physics_qualification"] = "PHYSICS_HOLD_SPIN_FAMILY"
                bundle_status_metadata["spin_family_qualification"] = spin_status
                bundle_status_metadata["spin_family_qualification_reason"] = spin_reason
            end
        end
        IO.write_real_space_operator_bundle(
            temporary,
            roundtrip.lattice,
            roundtrip.r_degeneracies,
            profile_operators;
            profile = config.output.profile,
            overwrite = true,
            paired_tb_sha256 = sha256_file(tb_path),
            provenance = merge(
                Dict(
                    "source" => "WannierNLQG Wannierization",
                    "effective_wannierization_mode" =>
                        String(effective_wannierization_mode(config)),
                    "authoritative_hamiltonian" => band_hamiltonian.authority,
                    "authoritative_hamiltonian_digest" => band_hamiltonian.digest,
                    "authoritative_hamiltonian_algorithm_version" =>
                        band_hamiltonian.algorithm_version,
                ),
                profile_provenance,
            ),
            geometry = bundle_geometry,
            diagnostics = bundle_status_metadata,
            eligibility = bundle_status_metadata,
        )
        loaded = IO.read_real_space_operator_bundle(temporary)
        loaded.lattice == roundtrip.lattice || error("Packed HDF5 lattice round-trip failed")
        loaded.degeneracies == roundtrip.r_degeneracies ||
            error("Packed HDF5 degeneracy round-trip failed")
        loaded.manifest.r_vectors == roundtrip.r_vectors ||
            error("Packed HDF5 R-vector round-trip failed")
        loaded.manifest.profile == config.output.profile ||
            error("Packed HDF5 operator profile round-trip failed")
        loaded.manifest.inventory ==
        collect(IO.OPERATOR_PROFILE_INVENTORIES[config.output.profile]) ||
            error("Packed HDF5 operator inventory round-trip failed")
        loaded.operators[Core.REAL_SPACE_HAMILTONIAN].data == roundtrip.hamiltonian_r ||
            error("Packed HDF5 Hamiltonian round-trip failed")
        loaded.operators[Core.REAL_SPACE_POSITION].data == roundtrip.position_r ||
            error("Packed HDF5 position round-trip failed")
        for (kind, operator) in profile_operators
            loaded.operators[kind].data == operator.data ||
                error("Packed HDF5 $(Core.real_space_operator_name(kind)) round-trip failed")
        end
        length(loaded.manifest.scientific_content_sha256) == 64 ||
            error("Packed HDF5 scientific digest is invalid")
        mv(temporary, paths.packed; force = true)
        completed = true
    finally
        !completed && isfile(temporary) && rm(temporary; force = true)
        !keep_tb && isfile(tb_path) && rm(tb_path; force = true)
    end
    IO.read_real_space_operator_bundle(paths.packed)
    text_metadata =
        keep_tb ?
        _write_construction_metadata_sidecar(
            paths.wannier90,
            paths.packed,
            Dict(
                "construction_policy" => String(config.input.construction_policy),
                "classification" => diagnostic_classification,
                "production_eligible" => false,
                "manual_review_required" => true,
                "solver_status" => string(result.status),
                "gate_records" => JSON3.read(construction_gate_records),
            ),
        ) : ""
    return paths.packed,
    keep_tb ? paths.wannier90 : nothing,
    Dict(
        "numerical_quality" => numerical_quality,
        "tb_export_status" => export_status,
        "export_isometry_before" => string(isometry_before),
        "export_isometry_after" => string(isometry_after),
        "export_polar_repaired" => string(polar_repaired),
        "tb_hamiltonian_hermiticity" => string(hamiltonian_hermiticity),
        "tb_position_hermiticity" => string(position_hermiticity),
        "tb_roundtrip_tolerance" => "1.0e-12",
        "tb_hamiltonian_fourier_roundtrip_residual" =>
            string(construction_diagnostics["hamiltonian_fourier_roundtrip_residual"]),
        "tb_position_fourier_roundtrip_residual" =>
            string(construction_diagnostics["position_fourier_roundtrip_residual"]),
        "tb_fourier_roundtrip_gate_tolerance" =>
            string(construction_diagnostics["fourier_roundtrip_gate_tolerance"]),
        "diagnostic_classification" => diagnostic_classification,
        "construction_policy" => String(config.input.construction_policy),
        "construction_gate_records_json" => construction_gate_records,
        "wannier90_diagnostic_metadata" => text_metadata,
        "manual_review_required" => "true",
        "construction_quality_failed" => string(quality_failed),
    )
end

# Atomically retain the latest fully eligible checkpoint.
function _atomic_checkpoint_copy(source, destination)
    temporary, io = mktemp(dirname(destination); cleanup = false)
    close(io)
    completed = false
    try
        cp(source, temporary; force = true)
        mv(temporary, destination; force = true)
        completed = true
    finally
        !completed && isfile(temporary) && rm(temporary; force = true)
    end
    return destination
end

# Bind one already validated packed TB to the exact terminal checkpoint without
# changing its scientific operator payload.  Both containers must already hold
# the same canonical final-TB qualification payload.
function _bind_packed_checkpoint_sha256!(packed_path, checkpoint_path)
    checkpoint_digest, checkpoint_qualification_digest = HDF5.h5open(checkpoint_path, "r") do handle
        root_attributes = HDF5.attributes(handle)
        haskey(root_attributes, "checkpoint_sha256") ||
            throw(ArgumentError("terminal checkpoint omits checkpoint_sha256"))
        qualification = read_tb_symmetry_qualification_group(handle)
        String(read(root_attributes["checkpoint_sha256"])), qualification.payload_sha256
    end
    length(checkpoint_digest) == 64 ||
        throw(ArgumentError("terminal checkpoint digest is not SHA-256"))
    HDF5.h5open(packed_path, "r+") do handle
        qualification = read_tb_symmetry_qualification_group(
            handle;
            missing_reason = "PACKED_TB_QUALIFICATION_FIELD_ABSENT",
        )
        qualification.payload_sha256 == checkpoint_qualification_digest || throw(
            ArgumentError(
                "packed TB and terminal checkpoint final-TB qualification payloads disagree",
            ),
        )
        root_attributes = HDF5.attributes(handle)
        haskey(root_attributes, "checkpoint_sha256") &&
            HDF5.delete_attribute(handle, "checkpoint_sha256")
        root_attributes["checkpoint_sha256"] = checkpoint_digest
        if haskey(handle, "diagnostics")
            diagnostics = handle["diagnostics"]
            diagnostic_attributes = HDF5.attributes(diagnostics)
            haskey(diagnostic_attributes, "checkpoint_sha256") &&
                HDF5.delete_attribute(diagnostics, "checkpoint_sha256")
            diagnostic_attributes["checkpoint_sha256"] = checkpoint_digest
        end
        HDF5.flush(handle)
    end
    return checkpoint_digest
end

# Append the terminal summary after every output decision is known.
function _write_wannierization_final(
    io,
    result,
    config::SymmetryAdaptedWannierizationConfig,
    artifacts;
    wall_time,
    allocated_bytes,
    gc_time,
    peak_rss_bytes = Sys.maxrss(),
)
    converged = result.status in (COMPLETED, COMPLETED_WITH_WARNINGS)
    production_eligible = wannierization_production_eligible(result)
    _write_report_section(io, "CONSTRUCTION GATE AND DIAGNOSTIC SUMMARY")
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
    diagnostic_groups = _diagnostic_groups(result.diagnostics)
    println(io, "\nIMPORTANT DIAGNOSTICS\n")
    _write_diagnostic_summary(io, diagnostic_groups)

    _write_report_section(io, "FINAL SPREADING")
    final_total =
        isempty(result.history) ? sum(result.spreads_angstrom2) : last(result.history).spread_total
    final_sum = sum(result.spreads_angstrom2)
    _write_report_field(
        io,
        "accepted_iteration",
        isempty(result.history) ? 0 : last(result.history).iteration,
    )
    _write_report_field(io, "final_total_spreading", "$(final_total) angstrom^2")
    _write_report_field(
        io,
        "final_mean_state_spreading",
        "$(isempty(result.spreads_angstrom2) ? 0.0 : final_sum / length(result.spreads_angstrom2)) angstrom^2",
    )
    _write_report_field(
        io,
        "final_minimum_state_spreading",
        isempty(result.spreads_angstrom2) ? "NOT_RUN" :
        "$(minimum(result.spreads_angstrom2)) angstrom^2",
    )
    _write_report_field(
        io,
        "final_maximum_state_spreading",
        isempty(result.spreads_angstrom2) ? "NOT_RUN" :
        "$(maximum(result.spreads_angstrom2)) angstrom^2",
    )
    _write_report_field(
        io,
        "final_convergence_metric",
        isempty(result.history) ? "NOT_RUN" : last(result.history).spread_standard_deviation,
    )
    _write_report_field(io, "convergence_tolerance", config.solver.convergence_tolerance)
    println(io)
    _write_spreading_table(
        io,
        result.spreads_angstrom2;
        heading = "Per-Wannier-state final spreading (angstrom^2)",
    )
    _write_report_field(io, "sum_of_final_state_spreadings", "$(final_sum) angstrom^2")
    _write_report_field(io, "total_minus_state_sum", "$(final_total - final_sum) angstrom^2")

    qualification = result.tb_symmetry_qualification
    show_tb_symmetry = something(
        config.output.final_tb_symmetry_report_enabled,
        effective_wannierization_mode(config) == :symmetry_adapted,
    )
    if show_tb_symmetry
        _write_report_section(
            io,
            production_eligible ? "FINAL TB SYMMETRY QUALIFICATION (production eligible model)" :
            "FINAL TB SYMMETRY QUALIFICATION (diagnostic model)",
        )
        _write_report_field(io, "overall", qualification.overall)
        _write_report_field(io, "reason", qualification.reason)
        _write_report_field(io, "payload_sha256", qualification.payload_sha256)
        qualification_source =
            qualification.overall == "NOT_RUN" ? "qualification_not_run" :
            qualification.reason == "QUALIFICATION_EVALUATION_FAILED" ?
            "final_exported_tb_qualification_evaluation_failed" :
            artifacts.packed_hdf5 === nothing ? "qualification_payload_without_exported_tb" :
            "final_exported_and_read_back_tb"
        _write_report_field(io, "source", qualification_source)
        _write_tb_scope(io, result.input_summary)
        _write_tb_report(io, qualification)
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
    println(io, "production_eligible = $(production_eligible)")
    println(io, "diagnostic_only = $(!production_eligible)")
    println(io, "tb_symmetry = $(qualification.overall)")
    println(
        io,
        "accepted_iteration = $(isempty(result.history) ? 0 : last(result.history).iteration)",
    )
    println(
        io,
        "convergence_metric = $(isempty(result.history) ? "NOT_RUN" : last(result.history).spread_standard_deviation)",
    )
    println(io, "convergence_tolerance = $(config.solver.convergence_tolerance)")
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
        :wannier90_tb,
        :tb_symmetry_json,
    )
        path = getproperty(artifacts, name)
        println(io, name, " = ", _report_path(path, root))
        if path !== nothing && isfile(path) && name != :wannierization_log
            println(io, "  sha256 = ", sha256_file(path), "  size_bytes = ", filesize(path))
        end
    end
    println(io, "construction_policy = $(config.input.construction_policy)")
    metadata = get(result.input_summary, "wannier90_diagnostic_metadata", "")
    println(
        io,
        "wannier90_diagnostic_metadata = ",
        _report_path(isempty(metadata) ? nothing : metadata, root),
    )
    if artifacts.wannierization_log !== nothing
        stem =
            endswith(artifacts.wannierization_log, ".out") ?
            artifacts.wannierization_log[1:(end - 4)] : artifacts.wannierization_log
        diagnostic_path = _write_diagnostic_records(stem * "-diagnostics.jsonl", result.diagnostics)
        println(io, "Full diagnostic records: ", _report_path(diagnostic_path, root))
        println(
            io,
            "sha256 = ",
            sha256_file(diagnostic_path),
            "  size_bytes = ",
            filesize(diagnostic_path),
        )
    end
    flush(io)
    return nothing
end
