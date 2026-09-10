using Dates
using Printf

"""
Mutable root-rank progress state: configuration, paths, timing counters, current task and a lock protecting text/JSONL emission.

The active instance owns report formatting and stage timing only; it does not own numerical accumulators.
"""
mutable struct ProgressContext
    enabled::Bool
    out_path::String
    jsonl_path::String
    start_time::Float64
    cfg::EffectiveTaskConfig
    specs::Vector{NormalizedTaskSpec}
    task_display_records::Vector{NamedTuple}
    current_task_label::String
    run_dir::String
    model_file::String
    model_sha256::String
    num_orbitals::Int
    system_name::String
    k_mesh::Union{NTuple{2, Int}, NTuple{3, Int}}
    photon_energies::Vector{Float64}
    mpi_size::Int
    execution_mode::String
    matrix_families::Vector{String}
    verbosity::Symbol
    stage_seconds::Dict{String, Float64}
    system_summary::Dict{String, Any}
    write_seconds::Float64
    header_written::Bool
    lock::ReentrantLock
end

const ACTIVE_PROGRESS = Ref{Any}(nothing)

"""
Normalize diagnostic/normal/quiet verbosity aliases; reject unknown selector text.
"""
function progress_verbosity_symbol(value::AbstractString)
    key = _canonical_key(value)
    if key in ("diagnostic", "debug", "detailed")
        return :diagnostic
    elseif key in ("normal", "standard")
        return :normal
    elseif key in ("quiet", "minimal")
        return :quiet
    end
    error("Invalid progress_verbosity=$(value); use \"diagnostic\", \"normal\", or \"quiet\".")
end

"""
Return the product of the two- or three-dimensional logical k-mesh counts.
"""
function progress_total_k(k_mesh::Union{NTuple{2, Int}, NTuple{3, Int}})
    return prod(k_mesh)
end

"""
Render mesh dimensions separated by ` x ` for the runtime report.
"""
function progress_k_mesh_label(k_mesh::Union{NTuple{2, Int}, NTuple{3, Int}})
    return join(k_mesh, " x ")
end

"""
Return the current UTC timestamp with millisecond precision and a trailing `Z`.
"""
function progress_timestamp()
    return Dates.format(Dates.now(Dates.UTC), "yyyy-mm-ddTHH:MM:SS.sss") * "Z"
end

"""
Format a nonnegative finite duration as hours:minutes:seconds, or `--:--:--` for invalid durations.
"""
function progress_hms(seconds::Real)
    if !isfinite(seconds) || seconds < 0
        return "--:--:--"
    end
    total = floor(Int, seconds)
    h = total ÷ 3600
    m = (total % 3600) ÷ 60
    s = total % 60
    return @sprintf("%02d:%02d:%02d", h, m, s)
end

"""
Format finite seconds to three decimals with an `s` suffix; display `n/a` for nonfinite values.
"""
function progress_compact_seconds(seconds::Real)
    return isfinite(seconds) ? @sprintf("%.3fs", seconds) : "n/a"
end

"""
Format a finite real value with six significant digits, or `n/a` for nonfinite values.
"""
function progress_format_number(value::Real)
    return isfinite(value) ? @sprintf("%.6g", value) : "n/a"
end

"""
Show run-local paths relatively and abbreviate external paths to their parent/basename with an external marker.
"""
function progress_display_path(ctx::ProgressContext, path::AbstractString)
    isempty(path) && return ""
    abs_path = abspath(path)
    abs_run_dir = abspath(ctx.run_dir)
    rel = try
        relpath(abs_path, abs_run_dir)
    catch
        String(path)
    end
    if isabspath(rel) || rel == ".." || startswith(rel, "../")
        return "<external>/" * basename(abs_path)
    end
    return isempty(rel) ? "." : rel
end

"""
Render a fixed-width ASCII progress bar from a percentage clamped to 0–100; nonfinite values count as zero.
"""
function progress_bar(percent::Real; width::Int = 24)
    clamped = isfinite(percent) ? clamp(percent, 0.0, 100.0) : 0.0
    filled = round(Int, width * clamped / 100.0)
    return "[" * repeat("#", filled) * repeat(".", width - filled) * "]"
end

"""
Truncate a string to the requested display width, adding an ellipsis when at least four characters fit.
"""
function progress_text_chunks(value::AbstractString, width::Int)
    chars = collect(value)
    isempty(chars) && return [""]
    return [
        String(chars[index:min(index + width - 1, length(chars))]) for
        index in 1:width:length(chars)
    ]
end

"""Truncate a human-readable value to a bounded display length."""
function progress_short_text(value::AbstractString, width::Int)
    text = String(value)
    length(text) <= width && return text
    width <= 3 && return first(text, width)
    return first(text, width - 3) * "..."
end

"""
Return wall-clock seconds since the progress context's recorded run start.
"""
function progress_elapsed(ctx::ProgressContext)
    return time() - ctx.start_time
end

"""
Escape backslash, double quote, newline, carriage return and tab for progress JSON string values.
"""
function progress_json_escape(value::AbstractString)
    escaped = replace(value, "\\" => "\\\\")
    escaped = replace(escaped, "\"" => "\\\"")
    escaped = replace(escaped, "\n" => "\\n")
    escaped = replace(escaped, "\r" => "\\r")
    escaped = replace(escaped, "\t" => "\\t")
    return escaped
end

"""
Serialize supported progress values to JSON text: nonfinite reals and nothing become null, collections recurse, and dictionary keys are sorted.

Symbols and fallback objects serialize as strings; this helper neither writes files nor mutates inputs.
"""
progress_json_value(value::Nothing) = "null"
"""
Serialize supported progress values to JSON text: nonfinite reals and nothing become null, collections recurse, and dictionary keys are sorted.

Symbols and fallback objects serialize as strings; this helper neither writes files nor mutates inputs.
"""
progress_json_value(value::Bool) = value ? "true" : "false"
"""
Serialize supported progress values to JSON text: nonfinite reals and nothing become null, collections recurse, and dictionary keys are sorted.

Symbols and fallback objects serialize as strings; this helper neither writes files nor mutates inputs.
"""
progress_json_value(value::Integer) = string(value)
"""
Serialize supported progress values to JSON text: nonfinite reals and nothing become null, collections recurse, and dictionary keys are sorted.

Symbols and fallback objects serialize as strings; this helper neither writes files nor mutates inputs.
"""
function progress_json_value(value::Real)
    return isfinite(value) ? string(value) : "null"
end
"""
Serialize supported progress values to JSON text: nonfinite reals and nothing become null, collections recurse, and dictionary keys are sorted.

Symbols and fallback objects serialize as strings; this helper neither writes files nor mutates inputs.
"""
progress_json_value(value::Symbol) = progress_json_value(string(value))
"""
Serialize supported progress values to JSON text: nonfinite reals and nothing become null, collections recurse, and dictionary keys are sorted.

Symbols and fallback objects serialize as strings; this helper neither writes files nor mutates inputs.
"""
progress_json_value(value::AbstractString) = "\"" * progress_json_escape(value) * "\""
"""
Serialize supported progress values to JSON text: nonfinite reals and nothing become null, collections recurse, and dictionary keys are sorted.

Symbols and fallback objects serialize as strings; this helper neither writes files nor mutates inputs.
"""
function progress_json_value(values::AbstractVector)
    return "[" * join(progress_json_value.(values), ",") * "]"
end
"""
Serialize supported progress values to JSON text: nonfinite reals and nothing become null, collections recurse, and dictionary keys are sorted.

Symbols and fallback objects serialize as strings; this helper neither writes files nor mutates inputs.
"""
function progress_json_value(values::Tuple)
    return progress_json_value(collect(values))
end
"""
Serialize supported progress values to JSON text: nonfinite reals and nothing become null, collections recurse, and dictionary keys are sorted.

Symbols and fallback objects serialize as strings; this helper neither writes files nor mutates inputs.
"""
function progress_json_value(value::NamedTuple)
    json_pairs = [
        "\"" * progress_json_escape(string(k)) * "\":" * progress_json_value(v) for
        (k, v) in zip(keys(value), values(value))
    ]
    return "{" * join(json_pairs, ",") * "}"
end
"""
Serialize supported progress values to JSON text: nonfinite reals and nothing become null, collections recurse, and dictionary keys are sorted.

Symbols and fallback objects serialize as strings; this helper neither writes files nor mutates inputs.
"""
function progress_json_value(value::AbstractDict)
    entries = collect(pairs(value))
    sort!(entries; by = entry -> string(entry.first))
    json_pairs = [
        "\"" * progress_json_escape(string(k)) * "\":" * progress_json_value(v) for
        (k, v) in entries
    ]
    return "{" * join(json_pairs, ",") * "}"
end
"""
Serialize supported progress values to JSON text: nonfinite reals and nothing become null, collections recurse, and dictionary keys are sorted.

Symbols and fallback objects serialize as strings; this helper neither writes files nor mutates inputs.
"""
progress_json_value(value) = progress_json_value(string(value))

"""
Append a timestamped event with elapsed seconds and supplied extra fields to the context's JSONL file.
"""
function progress_write_jsonl_event!(
    ctx::ProgressContext,
    event::AbstractString;
    extra = Pair{String, Any}[],
)
    pairs = Pair{String, Any}[
        "event" => String(event),
        "timestamp" => progress_timestamp(),
        "elapsed_seconds" => progress_elapsed(ctx),
        "task" => "task_bundle",
        "task_label" => ctx.current_task_label,
        "tasks" => [
            (id = record.id, label = record.spec.label) for record in ctx.task_display_records
        ],
        "calculation" => unique(
            string(record.spec.calculation) for record in ctx.task_display_records
        ),
        "execution_mode" => ctx.execution_mode,
        "matrix_families" => ctx.matrix_families,
        "rank" => 0,
        "mpi_size" => ctx.mpi_size,
    ]
    append!(pairs, extra)
    line =
        "{" *
        join(
            ["\"" * progress_json_escape(k) * "\":" * progress_json_value(v) for (k, v) in pairs],
            ",",
        ) *
        "}"
    open(ctx.jsonl_path, "a") do io
        println(io, line)
    end
    return nothing
end

"""
Append one newline-terminated report line to the context's text output file.
"""
function progress_append_text!(ctx::ProgressContext, line::AbstractString)
    open(ctx.out_path, "a") do io
        println(io, line)
    end
    return nothing
end

"""
Append a report line to disk, print it to stdout and flush stdout; return nothing.
"""
function progress_emit_text!(ctx::ProgressContext, line::AbstractString)
    progress_append_text!(ctx, line)
    println(line)
    flush(stdout)
    return nothing
end

"""
Emit report lines in order through the shared text-file/stdout writer.
"""
function progress_emit_lines!(ctx::ProgressContext, lines::Vector{String})
    for line in lines
        progress_emit_text!(ctx, line)
    end
    return nothing
end

"""
Describe the photon-energy range and count in eV, with explicit empty and singleton forms.
"""
function progress_photon_energy_summary(photon_energies::Vector{Float64})
    if isempty(photon_energies)
        return "(empty)"
    elseif length(photon_energies) == 1
        return @sprintf("%.6f eV  (1 point)", photon_energies[1])
    end
    return @sprintf(
        "%.6f -> %.6f eV  (%d points)",
        minimum(photon_energies),
        maximum(photon_energies),
        length(photon_energies)
    )
end

"""
Format one indented report key/value pair with a fixed minimum key width.
"""
function progress_kv_line(label::AbstractString, value)
    return @sprintf("    %-18s : %s", label, string(value))
end

"""Return whether a normalized task is dispatched by the dedicated band-spectrum executor."""
function progress_is_band_structure_task(spec::NormalizedTaskSpec)
    definition = task_definition(spec.quantity, spec.method, spec.calculation)
    definition === nothing && error("Missing TaskDefinition for $(spec.label).")
    return definition.executor == EXECUTOR_BAND_STRUCTURE
end

"""
Build report lines for effective band-path or response numerical controls without writing them.
"""
function progress_numerics_lines(ctx::ProgressContext)
    cfg = ctx.cfg
    if progress_is_band_structure_task(ctx.specs[1])
        point_count = sum(cfg.kpoints_per_segment) - length(cfg.kpoints_per_segment) + 1
        return String[
            "NUMERICS",
            "  K path",
            progress_kv_line("nodes", length(cfg.kpath_nodes)),
            progress_kv_line("segments", length(cfg.kpoints_per_segment)),
            progress_kv_line("total k-points", point_count),
            progress_kv_line("points/segment", cfg.kpoints_per_segment),
            progress_kv_line("E_ref", "$(cfg.fermi_energy) eV"),
            progress_kv_line("Hermiticity tol", cfg.band_hermiticity_tolerance),
            progress_kv_line("replica policy", cfg.real_space_replica_policy),
            progress_kv_line(
                "wsvec file",
                isnothing(cfg.wsvec_file) ? "not provided" :
                progress_display_path(ctx, cfg.wsvec_file),
            ),
            progress_kv_line("mp_grid", isnothing(cfg.mp_grid) ? "not provided" : cfg.mp_grid),
            "",
        ]
    end
    photon_energy_range =
        isempty(ctx.photon_energies) ? "(empty)" :
        @sprintf("%.6f -> %.6f eV", minimum(ctx.photon_energies), maximum(ctx.photon_energies),)
    lines = String[
        "NUMERICS",
        "  Mesh",
        progress_kv_line("k mesh", progress_k_mesh_label(ctx.k_mesh)),
        progress_kv_line("total k-points", progress_total_k(ctx.k_mesh)),
        progress_kv_line("dimension", cfg.spatial_dimension),
        progress_kv_line("replica policy", cfg.real_space_replica_policy),
        progress_kv_line(
            "wsvec file",
            isnothing(cfg.wsvec_file) ? "not provided" : progress_display_path(ctx, cfg.wsvec_file),
        ),
        progress_kv_line("mp_grid", isnothing(cfg.mp_grid) ? "not provided" : cfg.mp_grid),
        "",
        "  Energy grid",
        progress_kv_line("photon_energies range", photon_energy_range),
        progress_kv_line("photon_energies points", length(ctx.photon_energies)),
        progress_kv_line("fermi_energy", "$(cfg.fermi_energy) eV"),
        progress_kv_line("temperature", "$(cfg.temperature) K"),
        "",
        "  Smearing / screening",
        progress_kv_line("type", cfg.broadening_type),
        progress_kv_line("broadening", @sprintf("%.6g eV", cfg.broadening)),
        progress_kv_line(
            "denominator_regularization",
            @sprintf("%.6g eV", cfg.denominator_regularization)
        ),
        progress_kv_line("transition_window_factor", cfg.transition_window_factor),
        "",
        "  Bands / tensor",
        progress_kv_line(
            "band_window_size",
            cfg.band_window_size == -1 ? "all bands" : cfg.band_window_size,
        ),
        progress_kv_line("tensor_indices", cfg.tensor_indices),
        progress_kv_line(
            "band_selection",
            cfg.band_selection == -1 ? "all bands" : cfg.band_selection,
        ),
        "",
        "  Momentum / finite difference",
        progress_kv_line("photon_momentum", "$(cfg.photon_momentum) Ang^-1"),
        progress_kv_line("finite_difference_step", "$(cfg.finite_difference_step) Ang^-1"),
    ]
    if ctx.specs[1].calculation == :kslice
        append!(
            lines,
            String[
                "",
                "  K-slice geometry",
                progress_kv_line("origin", cfg.kslice_origin),
                progress_kv_line("vector_1", cfg.kslice_vector_1),
                progress_kv_line("vector_2", cfg.kslice_vector_2),
            ],
        )
    end
    if Symbol(_canonical_key(cfg.response_symmetry_kmesh_mode)) == :full &&
       !cfg.response_symmetry_report_enabled
        append!(lines, String["", progress_kv_line("response symmetry report", "DISABLED")])
    else
        append!(
            lines,
            String[
                "",
                "  Response symmetry",
                progress_kv_line(
                    "status",
                    cfg.response_symmetry_file === nothing ? "NOT_CONFIGURED" : "CONFIGURED",
                ),
                progress_kv_line("report_enabled", cfg.response_symmetry_report_enabled),
                progress_kv_line(
                    "artifact",
                    cfg.response_symmetry_file === nothing ? "NOT_CONFIGURED" :
                    cfg.response_symmetry_file,
                ),
                progress_kv_line("policy", cfg.response_symmetry_policy),
                progress_kv_line("kmesh_mode", cfg.response_symmetry_kmesh_mode),
            ],
        )
    end
    push!(lines, "")
    return lines
end

"""
List the expected task output basenames using validated band/subspace and real/imaginary naming rules.
"""
function progress_output_names(
    ctx::ProgressContext,
    spec::NormalizedTaskSpec,
    cfg::EffectiveTaskConfig = ctx.cfg,
)
    if spec.calculation == :kslice
        if is_band_resolved_real_kslice_quantity(spec.quantity)
            num_orbitals = ctx.num_orbitals
            groups =
                spec.quantity == :berry_curvature ?
                normalize_berry_band_selection(cfg.band_selection, num_orbitals) :
                normalize_quantum_metric_band_selection(cfg.band_selection, num_orbitals)
            outputs = String[
                result_filename(
                    ctx.system_name,
                    spec.quantity,
                    spec.method,
                    spec.calculation;
                    band = band_group_output_label(group),
                ) for group in groups
            ]
            if isempty(groups) || real_kslice_band_groups_include_sum(groups)
                push!(
                    outputs,
                    result_filename(
                        ctx.system_name,
                        spec.quantity,
                        spec.method,
                        spec.calculation;
                        band = :sum,
                    ),
                )
            end
            return join(outputs, ", ")
        elseif is_interband_quantum_geometry_quantity(spec.quantity)
            return result_filename(ctx.system_name, spec.quantity, spec.method, spec.calculation)
        elseif is_target_group_real_kslice_quantity(spec.quantity)
            num_orbitals = ctx.num_orbitals
            groups = if spec.quantity == :berry_curvature_dipole
                validate_berry_curvature_dipole_band_selection(cfg.band_selection, num_orbitals)
            elseif spec.quantity == :berry_curvature_quadrupole
                validate_berry_curvature_quadrupole_band_selection(cfg.band_selection, num_orbitals)
            elseif spec.quantity == :quantum_metric_dipole
                validate_quantum_metric_dipole_band_selection(cfg.band_selection, num_orbitals)
            elseif spec.quantity == :quantum_metric_quadrupole
                validate_quantum_metric_quadrupole_band_selection(cfg.band_selection, num_orbitals)
            else
                validate_quantum_christoffel_band_selection(cfg.band_selection, num_orbitals)
            end
            return join(
                (
                    result_filename(
                        ctx.system_name,
                        spec.quantity,
                        spec.method,
                        spec.calculation;
                        band = band_group_output_label(group),
                    ) for group in groups
                ),
                ", ",
            )
        end
        return join(
            (
                result_filename(
                    ctx.system_name,
                    spec.quantity,
                    spec.method,
                    spec.calculation;
                    part = :r,
                ),
                result_filename(
                    ctx.system_name,
                    spec.quantity,
                    spec.method,
                    spec.calculation;
                    part = :i,
                ),
            ),
            ", ",
        )
    end
    return result_filename(ctx.system_name, spec.quantity, spec.method, spec.calculation)
end

"""Prefix every comma-separated output basename with its public task directory."""
function progress_prefix_task_outputs(task_id::AbstractString, outputs::AbstractString)
    return join((joinpath(task_id, strip(output)) for output in split(outputs, ',')), ", ")
end

"""
Resolve a task's matrix-family label through its registry definition; reject missing definitions.
"""
function progress_spec_family_label(spec::NormalizedTaskSpec, cfg::EffectiveTaskConfig)
    definition = task_definition(spec.quantity, spec.method, spec.calculation)
    definition === nothing && error("Missing TaskDefinition for $(spec.label).")
    return matrix_family_label(definition, cfg)
end

"""
Return the reciprocal lattice used in the system report via the shared row-lattice conversion.
"""
function progress_reciprocal_lattice(lattice)
    return reciprocal_lattice(lattice)
end

"""
Format one labeled three-component lattice row with its explicit unit string.
"""
function progress_lattice_line(label::AbstractString, row, unit::AbstractString)
    return @sprintf("    %-2s  %12.6f  %12.6f  %12.6f  %s", label, row[1], row[2], row[3], unit)
end

"""
Build the ordered task table with quantity, method, calculation, matrix family and expected output columns.
"""
function progress_task_table_lines(ctx::ProgressContext)
    records = ctx.task_display_records
    isempty(records) && return String["TASK BUNDLE", "  (empty)", ""]
    row_labels = ("quantity", "method", "calculation", "matrix family", "output")
    row_values = [
        begin
            output = progress_output_names(ctx, record.spec, record.cfg)
            length(records) > 1 && (output = progress_prefix_task_outputs(record.id, output))
            String[
                canonical_quantity_name(record.spec.quantity),
                canonical_method_name(record.spec.method),
                canonical_calculation_name(record.spec.calculation),
                progress_spec_family_label(record.spec, record.cfg),
                output,
            ]
        end for record in records
    ]
    field_width = maximum(length, ("field", row_labels...))
    column_widths = [
        max(
            length(String(record.id)),
            maximum(length(row_values[index][row]) for row in eachindex(row_labels)),
        ) for (index, record) in pairs(records)
    ]
    column_widths = clamp.(column_widths, 8, 36)
    border =
        "  +" *
        repeat("-", field_width + 2) *
        "+" *
        join((repeat("-", width + 2) * "+" for width in column_widths))
    function table_rows(label::AbstractString, values)
        chunks = [
            progress_text_chunks(string(value), width) for
            (value, width) in zip(values, column_widths)
        ]
        return [
            "  | " *
            rpad(index == 1 ? label : "", field_width) *
            " | " *
            join(
                [
                    rpad(index <= length(parts) ? parts[index] : "", width) for
                    (parts, width) in zip(chunks, column_widths)
                ],
                " | ",
            ) *
            " |" for index in 1:maximum(length, chunks)
        ]
    end
    lines = String["TASK BUNDLE", border]
    append!(lines, table_rows("field", [record.id for record in records]))
    push!(lines, border)
    for (row, label) in pairs(row_labels)
        append!(lines, table_rows(label, [values[row] for values in row_values]))
    end
    push!(lines, border)
    push!(lines, "")
    return lines
end

"""
Build system-report lines from the recorded model hash, orbitals, R count and real/reciprocal lattice geometry.
"""
function progress_system_lines(ctx::ProgressContext)
    summary = ctx.system_summary
    lattice = summary["lattice_vectors_ang"]
    reciprocal = summary["reciprocal_lattice_vectors_inv_ang"]
    return String[
        "SYSTEM",
        @sprintf("  %-18s : %s", "Model file", progress_display_path(ctx, ctx.model_file)),
        @sprintf("  %-18s : %s...", "Model sha256", first(string(summary["model_sha256"]), 12)),
        @sprintf("  %-18s : %d", "Wannier orbitals", summary["num_orbitals"]),
        @sprintf("  %-18s : %d", "R points", summary["num_r_vectors"]),
        @sprintf(
            "  %-18s : %s Ang^3",
            "Cell volume",
            progress_format_number(summary["cell_volume_ang3"])
        ),
        "",
        "  Real-space lattice vectors (Ang)",
        progress_lattice_line("a1", lattice[1], "Ang"),
        progress_lattice_line("a2", lattice[2], "Ang"),
        progress_lattice_line("a3", lattice[3], "Ang"),
        "",
        "  Reciprocal lattice vectors (1/Ang)",
        progress_lattice_line("b1", reciprocal[1], "1/Ang"),
        progress_lattice_line("b2", reciprocal[2], "1/Ang"),
        progress_lattice_line("b3", reciprocal[3], "1/Ang"),
        "",
        "  Convention: row-lattice, R_cart = R_frac(row) * lattice; q_frac = lattice * q_cart / 2pi",
        "",
    ]
end

"""Resolve the response progress cadence in percent from explicit configuration or the new environment variable."""
function effective_progress_percent_interval(cfg::EffectiveTaskConfig)
    configured = cfg.progress_percent_interval
    interval =
        configured === nothing ? env_int("WANNIERNLQG_PROGRESS_PERCENT_INTERVAL", 5) : configured
    1 <= interval <= 100 || throw(
        ArgumentError(
            "Invalid progress percent interval=$(interval); use an integer from 1 through 100.",
        ),
    )
    return Int(interval)
end

"""
Return true once when completion first crosses a configured percentage milestone.

The atomic milestone makes concurrent workers monotone and duplicate-free. Completion always emits at 100%.
"""
function progress_percent_milestone_crossed!(
    last_milestone::Threads.Atomic{Int},
    completed::Integer,
    total::Integer,
    interval::Integer,
)
    total <= 0 && return false
    actual_percent = clamp(fld(100 * Int(completed), Int(total)), 0, 100)
    candidate = completed >= total ? 100 : fld(actual_percent, interval) * interval
    candidate <= 0 && return false
    while true
        previous = last_milestone[]
        candidate <= previous && return false
        Threads.atomic_cas!(last_milestone, previous, candidate) == previous && return true
    end
end

"""
Describe progress verbosity, percentage cadence and MPI/thread execution controls from the active context.
"""
function progress_run_control_lines(ctx::ProgressContext)
    cfg = ctx.cfg
    interval = effective_progress_percent_interval(cfg)
    return String[
        "RUN CONTROLS",
        @sprintf("  %-18s : %s", "progress enabled", "true"),
        @sprintf("  %-18s : %s", "verbosity", "$(ctx.verbosity)  (quiet | normal | diagnostic)"),
        @sprintf("  %-18s : every %d%%", "interval", interval),
        @sprintf(
            "  %-18s : %s",
            "timing",
            "stage timers; k-loop progress uses k-loop elapsed time"
        ),
        "",
    ]
end

"""
Truncate the text report, emit the banner/task/numerics/control header, and mark the header as written.
"""
function progress_write_header!(ctx::ProgressContext)
    cfg = ctx.cfg
    open(ctx.out_path, "w") do io
    end
    lines = String[
        repeat("=", 88),
        " WannierNLQG runtime report",
        repeat("=", 88),
        "BANNER",
        "  Started      : $(Dates.format(Dates.now(), "yyyy-mm-dd HH:MM:SS"))",
        "  Julia        : $(VERSION)",
        "  Parallel     : MPI ranks=$(ctx.mpi_size), Julia threads/rank=$(Threads.nthreads())",
        "  Execution    : $(ctx.execution_mode)",
        "  Output prefix: $(ctx.system_name)",
        "  Run directory: $(progress_display_path(ctx, ctx.run_dir))",
        "  Progress log : $(progress_display_path(ctx, ctx.out_path))",
        "  Progress JSON: $(progress_display_path(ctx, ctx.jsonl_path))",
        "",
    ]
    append!(lines, progress_system_lines(ctx))
    append!(lines, progress_task_table_lines(ctx))
    append!(lines, progress_numerics_lines(ctx))
    append!(lines, progress_run_control_lines(ctx))
    progress_emit_lines!(ctx, lines)
    ctx.header_written = true
    return nothing
end

"""
Record model dimensions and lattice geometry under the progress lock and emit the corresponding system event.

Return without side effects when no progress context is active.
"""
function progress_system_summary!(model)
    ctx = ACTIVE_PROGRESS[]
    ctx === nothing && return nothing
    Base.lock(ctx.lock)
    try
        lattice = model.lattice
        reciprocal = progress_reciprocal_lattice(lattice)
        cell_volume = abs(det(lattice))
        ctx.system_summary = Dict{String, Any}(
            "model_file" => ctx.model_file,
            "model_sha256" => ctx.model_sha256,
            "num_orbitals" => model.num_orbitals,
            "num_r_vectors" => model.num_r_vectors,
            "cell_volume_ang3" => cell_volume,
            "lattice_vectors_ang" => [Float64[lattice[i, j] for j in 1:3] for i in 1:3],
            "reciprocal_lattice_vectors_inv_ang" =>
                [Float64[reciprocal[i, j] for j in 1:3] for i in 1:3],
            "lattice_convention" => "row-lattice: R_cart = R_frac(row) * lattice; q_frac = lattice * q_cart / 2pi",
        )
        if !ctx.header_written
            progress_write_header!(ctx)
            progress_write_jsonl_event!(
                ctx,
                "system_summary";
                extra = ["system_summary" => ctx.system_summary],
            )
        end
    finally
        Base.unlock(ctx.lock)
    end
    return nothing
end

"""
Emit a timestamped notice to text/stdout and JSONL under the context lock; return false when progress is inactive.
"""
function progress_notice!(message::AbstractString)
    ctx = ACTIVE_PROGRESS[]
    ctx === nothing && return false
    Base.lock(ctx.lock)
    try
        line = "[$(progress_hms(progress_elapsed(ctx)))] NOTICE    $(message)"
        progress_emit_text!(ctx, line)
        progress_write_jsonl_event!(ctx, "notice"; extra = ["message" => String(message)])
    finally
        Base.unlock(ctx.lock)
    end
    return true
end

"""
Record the chosen Fourier backend, explicit factors and memory/decomposition summary under the progress lock.
"""
function progress_fourier_line(summary; grid = nothing, local_kpoints = nothing, lanes = nothing)
    getfieldvalue(key, default) =
        summary isa AbstractDict ? get(summary, string(key), default) :
        hasproperty(summary, key) ? getproperty(summary, key) : default
    backend = string(getfieldvalue(:backend, "unknown"))
    tasks = getfieldvalue(:task_signatures, String[])
    parts = String["FOURIER   " * backend]
    isempty(tasks) || push!(parts, "task=" * join(tasks, ","))
    isnothing(grid) || push!(parts, "grid=" * join(grid, "x"))
    isnothing(local_kpoints) || push!(parts, "local_kpoints=$(local_kpoints)")
    isnothing(lanes) || push!(parts, "lanes=$(lanes)")
    source = string(getfieldvalue(:factor_source, "not_applicable"))
    if startswith(source, "auto_fallback_")
        push!(parts, "fallback=" * replace(source, "auto_fallback_" => ""))
    elseif backend != "direct"
        push!(parts, "FFT workspace bytes=$(getfieldvalue(:estimated_memory_bytes, 0))")
    end
    return join(parts, " | ")
end

"""Emit one human plan line and preserve its complete structured Fourier audit event."""
function progress_fourier_backend!(
    summary::NamedTuple;
    grid = nothing,
    local_kpoints = nothing,
    lanes = nothing,
)
    ctx = ACTIVE_PROGRESS[]
    ctx === nothing && return nothing
    Base.lock(ctx.lock)
    try
        line =
            "[$(progress_hms(progress_elapsed(ctx)))] " *
            progress_fourier_line(summary; grid, local_kpoints, lanes)
        progress_emit_text!(ctx, line)
        extra = Pair{String, Any}[string(key) => getproperty(summary, key) for key in keys(summary)]
        append!(
            extra,
            ["display_grid" => grid, "local_kpoints" => local_kpoints, "reduction_lanes" => lanes],
        )
        progress_write_jsonl_event!(ctx, "fourier_backend"; extra)
    finally
        Base.unlock(ctx.lock)
    end
    return nothing
end

"""
Record the immutable response-symmetry execution contract before the k loop.
"""
function progress_response_symmetry!(summary::NamedTuple)
    ctx = ACTIVE_PROGRESS[]
    ctx === nothing && return nothing
    Base.lock(ctx.lock)
    try
        line =
            "[$(progress_hms(progress_elapsed(ctx)))] SYMMETRY  status=$(summary.status) " *
            "policy=$(summary.policy) representatives=$(summary.representative_kpoint_count)/$(summary.full_kpoint_count) " *
            "reduction_factor=$(@sprintf("%.6g", summary.reduction_factor))"
        progress_emit_text!(ctx, line)
        progress_emit_text!(ctx, "  artifact=$(summary.artifact_file)")
        progress_emit_text!(
            ctx,
            "  kmesh_mode=$(summary.kmesh_mode), numerical_tensor_projection_applied=$(summary.numerical_tensor_projection_applied)",
        )
        if summary.symmetry_warning_count > 0
            progress_emit_text!(
                ctx,
                "  warnings=$(summary.symmetry_warning_count) (DIAGNOSTIC_ONLY)",
            )
            for warning in summary.symmetry_warnings
                progress_emit_text!(ctx, "  WARNING: $(warning)")
            end
        end
        progress_write_jsonl_event!(
            ctx,
            "response_symmetry_plan";
            extra = [string(key) => getproperty(summary, key) for key in keys(summary)],
        )
    finally
        Base.unlock(ctx.lock)
    end
    return nothing
end

"""
Create root-rank progress state and initialize report/event files when enabled.

Non-root or disabled execution clears the active context; configuration and matrix-family labels are retained for later reporting.
"""
function progress_start!(
    cfg::EffectiveTaskConfig,
    ctx::RunContext,
    execution_mode::AbstractString = "fused_kloop",
    matrix_families::Vector{String} = String[],
    ;
    task_display_records = nothing,
)
    if !cfg.progress_enabled || !mpi_is_root_process()
        ACTIVE_PROGRESS[] = nothing
        return nothing
    end

    display_records = if task_display_records === nothing
        NamedTuple[(id = "task_$(index)", spec = spec, cfg = cfg) for (index, spec) in pairs(ctx.specs)]
    else
        NamedTuple[
            (id = String(record.id), spec = record.spec, cfg = record.cfg) for
            record in task_display_records
        ]
    end
    progress_ctx = ProgressContext(
        true,
        ctx.progress_out_path,
        ctx.progress_jsonl_path,
        time(),
        cfg,
        ctx.specs,
        display_records,
        "",
        ctx.run_dir,
        ctx.model_file,
        ctx.model_sha256,
        ctx.num_orbitals,
        ctx.system_name,
        cfg.k_mesh,
        Float64[x for x in cfg.photon_energies],
        mpi_process_size(),
        String(execution_mode),
        String[x for x in matrix_families],
        progress_verbosity_symbol(cfg.progress_verbosity),
        Dict{String, Float64}(),
        Dict{String, Any}(),
        0.0,
        false,
        ReentrantLock(),
    )
    ACTIVE_PROGRESS[] = progress_ctx
    open(progress_ctx.out_path, "w") do io
    end
    open(progress_ctx.jsonl_path, "w") do io
    end
    band_calculation = progress_is_band_structure_task(ctx.specs[1])
    total_k_global =
        band_calculation ? sum(cfg.kpoints_per_segment) - length(cfg.kpoints_per_segment) + 1 :
        progress_total_k(cfg.k_mesh)
    progress_write_jsonl_event!(
        progress_ctx,
        "run_start";
        extra = [
            "run_dir" => ctx.run_dir,
            "model_file" => ctx.model_file,
            "system_name" => ctx.system_name,
            "k_mesh" => band_calculation ? nothing : collect(cfg.k_mesh),
            "kpath_nodes" => band_calculation ? cfg.kpath_nodes : nothing,
            "kpoints_per_segment" => band_calculation ? cfg.kpoints_per_segment : nothing,
            "photon_energies" => cfg.photon_energies,
            "photon_energy_summary" => Dict(
                "min" => isempty(cfg.photon_energies) ? nothing : minimum(cfg.photon_energies),
                "max" => isempty(cfg.photon_energies) ? nothing : maximum(cfg.photon_energies),
                "count" => length(cfg.photon_energies),
            ),
            "total_k_global" => total_k_global,
            "progress_out_path" => ctx.progress_out_path,
            "progress_jsonl_path" => ctx.progress_jsonl_path,
            "screen_output" => true,
        ],
    )
    return nothing
end

"""
Set the active task label and emit its start notification under the progress lock.
"""
function progress_task_start!(spec::NormalizedTaskSpec)
    ctx = ACTIVE_PROGRESS[]
    ctx === nothing && return nothing
    Base.lock(ctx.lock)
    try
        ctx.current_task_label = spec.label
        progress_emit_text!(
            ctx,
            "[$(progress_hms(progress_elapsed(ctx)))] TASK      start $(spec.label)",
        )
        progress_write_jsonl_event!(
            ctx,
            "task_start";
            extra = [
                "quantity" => string(spec.quantity),
                "method" => string(spec.method),
                "calculation" => string(spec.calculation),
            ],
        )
    finally
        Base.unlock(ctx.lock)
    end
    return nothing
end

"""
Record task completion and its output paths under the progress lock; no-op without active progress.
"""
function progress_task_done!(spec::NormalizedTaskSpec, outputs::Vector{String})
    ctx = ACTIVE_PROGRESS[]
    ctx === nothing && return nothing
    Base.lock(ctx.lock)
    try
        ctx.current_task_label = spec.label
        progress_emit_text!(
            ctx,
            "[$(progress_hms(progress_elapsed(ctx)))] TASK      done $(spec.label)",
        )
        progress_write_jsonl_event!(ctx, "task_done"; extra = ["outputs" => outputs])
    finally
        Base.unlock(ctx.lock)
    end
    return nothing
end

"""
Release the active progress context reference without deleting its report files.
"""
function progress_clear!()
    ACTIVE_PROGRESS[] = nothing
    return nothing
end

"""
Convert a leading bracketed debug stage to its report label, using INFO when no stage is present.
"""
function progress_stage_from_message(message::AbstractString)
    matched = match(r"^\[([^\]]+)\]", message)
    matched === nothing && return "INFO"
    stage = lowercase(matched.captures[1])
    stage == "kloop" && return "K-LOOP"
    return uppercase(replace(stage, "_" => " "))
end

"""
Return the lowercase leading bracketed stage key, or `info` for untagged messages.
"""
function progress_stage_key(message::AbstractString)
    matched = match(r"^\[([^\]]+)\]", message)
    matched === nothing && return "info"
    return lowercase(matched.captures[1])
end

"""
Remove one leading bracketed stage prefix and following whitespace from a debug message.
"""
function progress_message_body(message::AbstractString)
    return replace(String(message), r"^\[[^\]]+\]\s*" => "")
end

"""
Parse the first regex capture as Int, returning nothing for a missing match or failed parse.
"""
function progress_int_capture(pattern::Regex, message::AbstractString)
    matched = match(pattern, message)
    matched === nothing && return nothing
    return tryparse(Int, matched.captures[1])
end

"""
Parse the first regex capture as Float64, returning nothing for a missing match or failed parse.
"""
function progress_float_capture(pattern::Regex, message::AbstractString)
    matched = match(pattern, message)
    matched === nothing && return nothing
    return tryparse(Float64, matched.captures[1])
end

"""
Return the first regex capture as text, or nothing when the pattern does not match.
"""
function progress_string_capture(pattern::Regex, message::AbstractString)
    matched = match(pattern, message)
    matched === nothing && return nothing
    return matched.captures[1]
end

"""
Format a k-loop progress message with completed counts, rate/ETA, elapsed time and active/skipped totals.

Preserve rank-local counts and explicitly marked estimated global counts; return nothing when completion fields are absent.
"""
function progress_kloop_text(ctx::ProgressContext, message::AbstractString)
    matched = match(r"finished=(\d+)/(\d+)", message)
    matched === nothing && return nothing
    completed = parse(Int, matched.captures[1])
    total_local = parse(Int, matched.captures[2])
    local_finished = match(r"local_finished=(\d+)/(\d+)", message)
    local_finished_text =
        local_finished === nothing ? "$(completed)/$(total_local)" :
        "$(local_finished.captures[1])/$(local_finished.captures[2])"
    active = progress_int_capture(r"active=(\d+)", message)
    skipped = progress_int_capture(r"skipped=(\d+)", message)
    represented_weight = progress_int_capture(r"represented_weight=(\d+)", message)
    elapsed = progress_float_capture(r"elapsed=([0-9.]+)s", message)
    elapsed_value = isnothing(elapsed) ? NaN : elapsed
    global_scope = occursin(r"\bscope=global\b", message)
    total_work_items = something(
        progress_int_capture(r"total_work_items_global=(\d+)", message),
        progress_total_k(ctx.k_mesh),
    )
    estimated_global =
        global_scope ? min(total_work_items, completed) :
        ctx.mpi_size > 1 ? min(total_work_items, completed * max(ctx.mpi_size, 1)) : completed
    active_text = isnothing(active) ? "-" : string(active)
    skipped_text = isnothing(skipped) ? "-" : string(skipped)

    if ctx.verbosity == :diagnostic
        estimated_time_remaining =
            (isfinite(elapsed_value) && completed > 0) ?
            elapsed_value / completed * max(total_local - completed, 0) : NaN
        rate = (isfinite(elapsed_value) && elapsed_value > 0) ? completed / elapsed_value : NaN
        percent = total_local > 0 ? 100.0 * completed / total_local : 100.0
        rate_text = isfinite(rate) ? @sprintf("%.2f points/s", rate) : "n/a"
        line = @sprintf(
            "  %-11s %-12s %-26s %6.1f%%  %10s  %8s  %8s  %8s  %8s",
            global_scope ? local_finished_text : "$(completed)/$(total_local)",
            ctx.mpi_size > 1 && !global_scope ? "~$(estimated_global)/$(total_work_items)" :
            "$(estimated_global)/$(total_work_items)",
            progress_bar(percent),
            percent,
            rate_text,
            progress_hms(estimated_time_remaining),
            progress_hms(elapsed_value),
            active_text,
            skipped_text,
        )
        return isnothing(represented_weight) ? line : line * "  represented=$(represented_weight)"
    end

    percent = total_work_items > 0 ? 100.0 * estimated_global / total_work_items : 100.0
    rate = (isfinite(elapsed_value) && elapsed_value > 0) ? estimated_global / elapsed_value : NaN
    estimated_time_remaining =
        (isfinite(elapsed_value) && estimated_global > 0) ?
        elapsed_value / estimated_global * max(total_work_items - estimated_global, 0) : NaN
    rate_text = isfinite(rate) ? @sprintf("%.2f points/s", rate) : "n/a"
    if ctx.mpi_size > 1
        line = @sprintf(
            "  %-10s %-10s %-26s %6.1f%%  %9s  %8s  %8s  %7s  %7s",
            global_scope ? "$(estimated_global)/$(total_work_items)" :
            "~$(estimated_global)/$(total_work_items)",
            global_scope ? local_finished_text : "$(completed)/$(total_local)",
            progress_bar(percent),
            percent,
            rate_text,
            progress_hms(estimated_time_remaining),
            progress_hms(elapsed_value),
            active_text,
            skipped_text,
        )
        return isnothing(represented_weight) ? line : line * "  represented=$(represented_weight)"
    end
    line = @sprintf(
        "  %-10s %-26s %6.1f%%  %9s  %8s  %8s  %7s  %7s",
        "$(estimated_global)/$(total_work_items)",
        progress_bar(percent),
        percent,
        rate_text,
        progress_hms(estimated_time_remaining),
        progress_hms(elapsed_value),
        active_text,
        skipped_text,
    )
    return isnothing(represented_weight) ? line : line * "  represented=$(represented_weight)"
end

"""
Format the k-loop start block with local/global mesh counts, interval and timing policy for the current verbosity.
"""
function progress_kloop_start_text(ctx::ProgressContext, message::AbstractString)
    local_total = progress_int_capture(r"local_k_points=(\d+)", message)
    interval = progress_int_capture(r"progress_percent_interval=(\d+)", message)
    total_work_items = something(
        progress_int_capture(r"total_work_items_global=(\d+)", message),
        progress_total_k(ctx.k_mesh),
    )
    full_grid_k_points = something(
        progress_int_capture(r"full_grid_k_points=(\d+)", message),
        progress_total_k(ctx.k_mesh),
    )
    slow_k = progress_float_capture(r"slow_k_seconds=([0-9.]+)", message)
    local_text = isnothing(local_total) ? "unknown" : string(local_total)
    interval_text = isnothing(interval) ? "unknown" : string(interval)
    slow_text = isnothing(slow_k) ? "unknown" : progress_compact_seconds(slow_k)
    if ctx.verbosity == :diagnostic
        return join(
            String[
                "K-LOOP",
                "  local/global work     : $(local_text) / $(total_work_items)",
                "  full-grid k-points    : $(full_grid_k_points)",
                "  progress update       : every $(interval_text)%",
                "  slow-k threshold      : $(slow_text)",
                "",
                "  local       global       progress                     percent        rate       ETA   elapsed    active   skipped",
            ],
            "\n",
        )
    end
    lines = String[
        "K-LOOP",
        "  total work items     : $(total_work_items)",
        "  full-grid k-points  : $(full_grid_k_points)",
        "  MPI ranks            : $(ctx.mpi_size)",
        "  update cadence       : every $(interval_text)%",
        "  slow-k warning       : $(slow_text)",
    ]
    if ctx.mpi_size > 1
        push!(lines, "  k-points/rank       : $(local_text)")
        push!(lines, "")
        push!(
            lines,
            "  global     local/rank progress                     percent     rate      ETA     elapsed   active  skipped",
        )
    else
        push!(lines, "")
        push!(
            lines,
            "  done       progress                     percent     rate      ETA     elapsed   active  skipped",
        )
    end
    return join(lines, "\n")
end

"""
Format final local completion, active/skipped totals and loop time, labeling global estimates under MPI.
"""
function progress_kloop_end_text(ctx::ProgressContext, message::AbstractString)
    finished = match(r"finished=(\d+)/(\d+)", message)
    finished_text =
        finished === nothing ? "unknown" : "$(finished.captures[1])/$(finished.captures[2])"
    active = progress_int_capture(r"active=(\d+)", message)
    skipped = progress_int_capture(r"skipped=(\d+)", message)
    elapsed = progress_float_capture(r"elapsed=([0-9.]+)s", message)
    active_text = isnothing(active) ? "-" : string(active)
    skipped_text = isnothing(skipped) ? "-" : string(skipped)
    elapsed_text = isnothing(elapsed) ? "n/a" : progress_compact_seconds(elapsed)
    represented_weight = progress_int_capture(r"represented_weight=(\d+)", message)
    represented_text =
        isnothing(represented_weight) ? "" : ", represented full-grid weight=$(represented_weight)"
    global_scope = occursin(r"\bscope=global\b", message)
    if ctx.verbosity == :diagnostic || finished === nothing
        scope_text = global_scope ? "global representatives" : "local representatives"
        return "  completed $(finished_text) $(scope_text)$(represented_text); active=$(active_text), skipped=$(skipped_text), k-loop elapsed=$(elapsed_text)"
    end
    local_done = parse(Int, finished.captures[1])
    local_total = parse(Int, finished.captures[2])
    total_work_items = something(
        progress_int_capture(r"total_work_items_global=(\d+)", message),
        progress_total_k(ctx.k_mesh),
    )
    estimated_global =
        global_scope ? min(total_work_items, local_done) :
        ctx.mpi_size > 1 ? min(total_work_items, local_done * max(ctx.mpi_size, 1)) : local_done
    done_text =
        global_scope ? "$(estimated_global)/$(total_work_items) global work items" :
        ctx.mpi_size > 1 ?
        "~$(estimated_global)/$(total_work_items) global work items; local/rank=$(local_done)/$(local_total)" :
        "$(estimated_global)/$(total_work_items) work items"
    return "  completed $(done_text)$(represented_text); active=$(active_text), skipped=$(skipped_text), k-loop elapsed=$(elapsed_text)"
end

"""
Translate debug messages into elapsed-time/stage report lines, dispatching k-loop start/progress/end formats specially.
"""
function progress_text_line(ctx::ProgressContext, message::AbstractString, rank::Integer)
    stage = rpad(progress_stage_from_message(message), 9)
    if startswith(message, "[kloop] start")
        return progress_kloop_start_text(ctx, message)
    elseif startswith(message, "[kloop] end")
        return progress_kloop_end_text(ctx, message)
    end
    if startswith(message, "[kloop] progress")
        text = progress_kloop_text(ctx, message)
        isnothing(text) || return text
    elseif startswith(message, "[reduce] end")
        elapsed_value = progress_float_capture(r"elapsed=([0-9.]+)s", message)
        return (
            "REDUCE" *
            "\n" *
            "  deterministic task reductions completed in $(isnothing(elapsed_value) ? "n/a" : progress_compact_seconds(elapsed_value))"
        )
    elseif startswith(message, "[write] end")
        output_path = progress_string_capture(r"output_path=(.*?)(?: elapsed=[0-9.]+s)?$", message)
        elapsed_value = progress_float_capture(r"elapsed=([0-9.]+)s", message)
        output_text =
            isnothing(output_path) ? "result file" : progress_display_path(ctx, output_path)
        elapsed_text = isnothing(elapsed_value) ? "n/a" : progress_compact_seconds(elapsed_value)
        return ("WRITE" * "\n" * "  wrote $(output_text) in $(elapsed_text)")
    end
    elapsed = progress_hms(progress_elapsed(ctx))
    body = progress_message_body(message)
    if rank != 0
        body = "[rank $(rank)] " * body
    end
    return "[$(elapsed)] $(stage) $(body)"
end

"""
Store a parsed duration under its stage name; ignore an absent duration.
"""
function progress_store_stage_seconds!(ctx::ProgressContext, stage::AbstractString, seconds)
    isnothing(seconds) && return nothing
    ctx.stage_seconds[String(stage)] =
        stage in ("read", "reduce") ? get(ctx.stage_seconds, String(stage), 0.0) + seconds : seconds
    return nothing
end

"""
Decode recognized debug messages into an event name and structured fields, updating stage timing when present.

Preserve the raw message and return a nothing event for unrecognized messages.
"""
function progress_debug_event(ctx::ProgressContext, message::AbstractString)
    extra = Pair{String, Any}["raw_message" => String(message)]
    lower = lowercase(String(message))
    stage = progress_stage_key(message)

    if startswith(message, "[kloop] start")
        local_total = progress_int_capture(r"local_k_points=(\d+)", message)
        total_work_items = progress_int_capture(r"total_work_items_global=(\d+)", message)
        full_grid_k_points = progress_int_capture(r"full_grid_k_points=(\d+)", message)
        percent_interval = progress_int_capture(r"progress_percent_interval=(\d+)", message)
        push!(extra, "stage" => "kloop")
        isnothing(local_total) || push!(extra, "total_k_local" => local_total)
        push!(
            extra,
            "total_work_items_global" => something(total_work_items, progress_total_k(ctx.k_mesh)),
        )
        push!(
            extra,
            "full_grid_k_points" => something(full_grid_k_points, progress_total_k(ctx.k_mesh)),
        )
        isnothing(percent_interval) || push!(extra, "progress_percent_interval" => percent_interval)
        return "kloop_start", extra
    elseif startswith(message, "[kloop] progress")
        matched = match(r"finished=(\d+)/(\d+)", message)
        if matched !== nothing
            completed = parse(Int, matched.captures[1])
            total_local = parse(Int, matched.captures[2])
            total_work_items = something(
                progress_int_capture(r"total_work_items_global=(\d+)", message),
                progress_total_k(ctx.k_mesh),
            )
            elapsed = progress_float_capture(r"elapsed=([0-9.]+)s", message)
            global_scope = occursin(r"\bscope=global\b", message)
            completed_global =
                global_scope ? min(total_work_items, completed) :
                ctx.mpi_size > 1 ? min(total_work_items, completed * max(ctx.mpi_size, 1)) :
                completed
            estimated_time_remaining =
                (!isnothing(elapsed) && completed > 0) ?
                elapsed / completed * max(total_local - completed, 0) : nothing
            rate = isnothing(elapsed) ? nothing : elapsed > 0 ? completed / elapsed : 0.0
            if global_scope
                push!(extra, "completed_k_global" => completed)
                push!(extra, "total_k_global" => total_local)
                local_finished = match(r"local_finished=(\d+)/(\d+)", message)
                if local_finished !== nothing
                    push!(extra, "completed_k_root_rank" => parse(Int, local_finished.captures[1]))
                    push!(extra, "total_k_root_rank" => parse(Int, local_finished.captures[2]))
                end
            else
                push!(extra, "completed_k_local" => completed)
                push!(extra, "total_k_local" => total_local)
            end
            push!(extra, "estimated_completed_k_global" => completed_global)
            global_scope && push!(extra, "completion_scope" => "global")
            push!(extra, "total_work_items_global" => total_work_items)
            push!(
                extra,
                "percent_complete" =>
                    (total_work_items > 0 ? 100.0 * completed_global / total_work_items : 100.0),
            )
            isnothing(estimated_time_remaining) ||
                push!(extra, "eta_seconds" => estimated_time_remaining)
            isnothing(rate) || push!(extra, "rate_k_per_second" => rate)
        end
        represented_weight = progress_int_capture(r"represented_weight=(\d+)", message)
        isnothing(represented_weight) || push!(
            extra,
            (
                occursin(r"\bscope=global\b", message) ? "represented_full_grid_weight_global" :
                "represented_full_grid_weight_local"
            ) => represented_weight,
        )
        active = progress_int_capture(r"active=(\d+)", message)
        skipped = progress_int_capture(r"skipped=(\d+)", message)
        isnothing(active) || push!(extra, "active" => active)
        isnothing(skipped) || push!(extra, "skipped" => skipped)
        return "kloop_progress", extra
    elseif startswith(message, "[kloop] slow")
        kpoint_index = progress_int_capture(r"kpoint_index=(\d+)", message)
        total_seconds = progress_float_capture(r"total=([0-9.]+)s", message)
        isnothing(kpoint_index) || push!(extra, "kpoint_index" => kpoint_index)
        isnothing(total_seconds) || push!(extra, "kpoint_seconds" => total_seconds)
        return "slow_k", extra
    elseif startswith(message, "[write]")
        output_path = progress_string_capture(r"output_path=(.*?)(?: elapsed=[0-9.]+s)?$", message)
        elapsed = progress_float_capture(r"elapsed=([0-9.]+)s", message)
        push!(extra, "stage" => "write")
        push!(extra, "status" => occursin(" end", lower) ? "end" : "start")
        isnothing(output_path) || push!(extra, "output_path" => output_path)
        if !isnothing(elapsed)
            push!(extra, "stage_seconds" => elapsed)
            if occursin(" end", lower)
                ctx.write_seconds += elapsed
                ctx.stage_seconds["write"] = ctx.write_seconds
            end
        end
        return "write_output", extra
    elseif occursin(" start", lower)
        push!(extra, "stage" => stage)
        return "stage_start", extra
    elseif occursin(" end", lower) || startswith(message, "[done]")
        elapsed = progress_float_capture(r"elapsed=([0-9.]+)s", message)
        progress_store_stage_seconds!(ctx, stage, elapsed)
        push!(extra, "stage" => stage)
        isnothing(elapsed) || push!(extra, "stage_seconds" => elapsed)
        return "stage_end", extra
    end
    return nothing, extra
end

"""
Apply header readiness and diagnostic/normal/quiet filtering to a debug message without changing event records.
"""
function progress_should_record_text(ctx::ProgressContext, message::AbstractString, event)
    ctx.header_written || return false
    ctx.verbosity == :diagnostic && return true
    if ctx.verbosity == :quiet
        return startswith(message, "[kloop] start") ||
               event == "kloop_progress" ||
               startswith(message, "[kloop] end")
    end
    startswith(message, "[fourier]") && return false
    startswith(message, "[degeneracy]") && return false
    startswith(message, "[kloop] slow") && return false
    startswith(message, "[setup]") && return false
    startswith(message, "[read]") && return false
    startswith(message, "[reduce] start") && return false
    startswith(message, "[write] start") && return false
    startswith(message, "[done]") && return false
    return true
end

"""
Record root-rank debug messages in text and JSONL according to verbosity under the context lock.

Return false for inactive/disabled contexts or non-root ranks.
"""
function progress_record_debug_message!(message::AbstractString, rank::Integer)
    ctx = ACTIVE_PROGRESS[]
    (ctx === nothing || !ctx.enabled || rank != 0) && return false
    Base.lock(ctx.lock)
    try
        event, extra = progress_debug_event(ctx, message)
        if progress_should_record_text(ctx, message, event)
            progress_emit_text!(ctx, progress_text_line(ctx, message, rank))
        end
        isnothing(event) || progress_write_jsonl_event!(ctx, event; extra = extra)
    finally
        Base.unlock(ctx.lock)
    end
    return true
end

"""
Build a report table from recorded stage durations, keeping bundle and k-loop timers distinct.
"""
function progress_timing_lines(ctx::ProgressContext)
    stage_labels = Dict(
        "read" => "model read",
        "kloop" => "k-loop",
        "reduce" => "deterministic reduce",
        "write" => "write outputs",
        "done" => "last task bundle",
    )
    lines = String[
        "TIMING",
        "  +----------------------+------------+",
        "  | stage                | seconds    |",
        "  +----------------------+------------+",
    ]
    for stage in ("read", "kloop", "reduce", "write", "done")
        if haskey(ctx.stage_seconds, stage)
            push!(
                lines,
                @sprintf(
                    "  | %-20s | %10s |",
                    stage_labels[stage],
                    progress_compact_seconds(ctx.stage_seconds[stage]),
                ),
            )
        end
    end
    push!(
        lines,
        @sprintf(
            "  | %-20s | %10s |",
            "wall total",
            progress_compact_seconds(progress_elapsed(ctx))
        )
    )
    push!(lines, "  +----------------------+------------+")
    push!(lines, "")
    return lines
end

"""Return `(task_id, summary)` from a Pair, two-tuple, or named record."""
function progress_response_symmetry_record(record)
    if record isa Pair
        return String(record.first), record.second
    elseif record isa Tuple && length(record) == 2
        return String(record[1]), record[2]
    elseif record isa NamedTuple && hasproperty(record, :task_id) && hasproperty(record, :summary)
        return String(record.task_id), record.summary
    end
    throw(ArgumentError("Invalid response symmetry record $(repr(record))."))
end

"""Read a string-keyed group-report field without imposing a concrete mapping type."""
function progress_group_report_field(mapping, key::AbstractString, default = nothing)
    mapping isa AbstractDict || return default
    return haskey(mapping, key) ? mapping[key] : default
end

"""Return full/active machine identities, excluding display and input-basis fields."""
function progress_group_identity_signature(summary)
    classification =
        hasproperty(summary, :group_classification) ? summary.group_classification :
        progress_group_report_field(summary, "group_classification", Dict())
    active =
        hasproperty(summary, :active_constraint_group) ? summary.active_constraint_group :
        progress_group_report_field(summary, "active_constraint_group", Dict())
    full = progress_group_report_field(classification, "full_magnetic_point_group", Dict())
    required = ("magnetic_point_group_number", "operation_digest")
    all(key -> progress_group_report_field(full, key) !== nothing, required) || return nothing
    all(key -> progress_group_report_field(active, key) !== nothing, required) || return nothing
    return (
        (
            role = "full_magnetic_point_group",
            magnetic_point_group_number = progress_group_report_field(
                full,
                "magnetic_point_group_number",
            ),
            operation_digest = progress_group_report_field(full, "operation_digest"),
        ),
        (
            role = "active_constraint_group",
            magnetic_point_group_number = progress_group_report_field(
                active,
                "magnetic_point_group_number",
            ),
            operation_digest = progress_group_report_field(active, "operation_digest"),
        ),
    )
end

"""Return the full/active exact basis payloads used only to detect multi-basis bundles."""
function progress_group_basis_signature(summary)
    classification =
        hasproperty(summary, :group_classification) ? summary.group_classification :
        progress_group_report_field(summary, "group_classification", Dict())
    active =
        hasproperty(summary, :active_constraint_group) ? summary.active_constraint_group :
        progress_group_report_field(summary, "active_constraint_group", Dict())
    full = progress_group_report_field(classification, "full_magnetic_point_group", Dict())
    return progress_json_value((
        progress_group_report_field(full, "basis_transform_to_input"),
        progress_group_report_field(active, "basis_transform_to_input"),
    ))
end

"""Replace basis-dependent aggregate fields by an explicit multi-input-bases status."""
function progress_mark_multiple_input_bases(classification, active)
    merged_classification = deepcopy(classification)
    merged_active = deepcopy(active)
    merged_classification["status"] = "MULTIPLE_INPUT_BASES"
    merged_active["status"] = "MULTIPLE_INPUT_BASES"
    full = progress_group_report_field(
        merged_classification,
        "full_magnetic_point_group",
        Dict{String, Any}(),
    )
    full["basis_transform_to_input"] = Dict("status" => "MULTIPLE_INPUT_BASES")
    merged_classification["full_magnetic_point_group"] = full
    merged_active["basis_transform_to_input"] = Dict("status" => "MULTIPLE_INPUT_BASES")
    return merged_classification, merged_active
end

"""Combine ordered per-task symmetry reports for the existing complete human renderer."""
function progress_aggregate_response_symmetry_summaries(records)
    task_records = Tuple{String, Any}[]
    for record in records
        task_id, summary = progress_response_symmetry_record(record)
        isempty(keys(summary)) || push!(task_records, (task_id, summary))
    end
    isempty(task_records) && return NamedTuple()
    human_summaries = NamedTuple[]
    warnings = String[]
    for (task_id, summary) in task_records
        for human_summary in summary.human_summaries
            push!(
                human_summaries,
                merge(human_summary, (; title = "TASK $(task_id) — $(human_summary.title)")),
            )
        end
        append!(warnings, ["TASK $(task_id): $(warning)" for warning in summary.symmetry_warnings])
    end
    distinct(field) = unique(string(getproperty(summary, field)) for (_, summary) in task_records)
    joined(field) = join(distinct(field), ", ")
    first_summary = first(task_records)[2]
    function group_value(summary, field)
        if hasproperty(summary, field)
            return getproperty(summary, field)
        elseif summary isa AbstractDict && haskey(summary, field)
            return summary[field]
        elseif summary isa AbstractDict && haskey(summary, string(field))
            return summary[string(field)]
        end
        return field == :point_group_generators ?
               Dict("status" => "UNRESOLVED", "generators" => Any[]) :
               Dict("status" => "UNRESOLVED")
    end
    identity_signatures =
        [progress_group_identity_signature(summary) for (_, summary) in task_records]
    common_group_identity = if all(signature -> signature !== nothing, identity_signatures)
        all(signature == first(identity_signatures) for signature in identity_signatures)
    else
        reference = progress_json_value((
            group_value(first_summary, :group_classification),
            group_value(first_summary, :active_constraint_group),
        ))
        all(
            progress_json_value((
                group_value(summary, :group_classification),
                group_value(summary, :active_constraint_group),
            )) == reference for (_, summary) in task_records
        )
    end
    multiple_input_bases =
        common_group_identity &&
        !all(
            progress_group_basis_signature(summary) ==
            progress_group_basis_signature(first_summary) for (_, summary) in task_records
        )
    if !common_group_identity
        push!(
            warnings,
            "TASK bundle contains distinct response-symmetry groups; group classification remains per-task in machine-readable summaries",
        )
    elseif multiple_input_bases
        push!(
            warnings,
            "TASK bundle contains one response-symmetry identity in multiple input bases; basis-dependent group details remain per-task in machine-readable summaries",
        )
    end
    aggregate_classification = group_value(first_summary, :group_classification)
    aggregate_active = group_value(first_summary, :active_constraint_group)
    if multiple_input_bases
        aggregate_classification, aggregate_active =
            progress_mark_multiple_input_bases(aggregate_classification, aggregate_active)
    end
    return (
        status = joined(:status),
        policy = joined(:policy),
        kmesh_mode = joined(:kmesh_mode),
        numerical_tensor_projection_applied = any(
            summary.numerical_tensor_projection_applied for (_, summary) in task_records
        ),
        summary_file = join(
            ["$(task_id): $(summary.summary_file)" for (task_id, summary) in task_records],
            ", ",
        ),
        human_summaries = human_summaries,
        symmetry_warning_count = length(warnings),
        symmetry_warnings = warnings,
        group_classification = common_group_identity ? aggregate_classification :
                               Dict("status" => "MULTIPLE_TASK_GROUPS"),
        active_constraint_group = common_group_identity ? aggregate_active :
                                  Dict("status" => "MULTIPLE_TASK_GROUPS"),
        point_group_generators = !common_group_identity ?
                                 Dict("status" => "MULTIPLE_TASK_GROUPS", "generators" => Any[]) :
                                 multiple_input_bases ?
                                 Dict("status" => "MULTIPLE_INPUT_BASES", "generators" => Any[]) :
                                 group_value(first_summary, :point_group_generators),
    )
end

"""Format one exact rational basis transform for the deterministic human report."""
function progress_group_basis_text(group)
    basis = get(group, "basis_transform_to_input", Dict())
    get(basis, "status", nothing) == "MULTIPLE_INPUT_BASES" && return "MULTIPLE_INPUT_BASES"
    rows = get(basis, "numerator_rows", Any[])
    denominator = get(basis, "denominator", nothing)
    length(rows) == 3 && denominator isa Integer || return "NOT_RECORDED"
    matrix_text = join(["[" * join(string.(row), " ") * "]" for row in rows], "; ")
    prefix = denominator == 1 ? "" : "1/$(denominator) * "
    return "$(prefix)$(matrix_text); v_input=B*v_canonical"
end

"""
Emit final outputs, metadata path, family/backend/symmetry summaries and timing records under the progress lock.

This reporting step does not change the numerical run's qualification or recompute results.
"""
function progress_run_done!(
    outputs::Vector{String},
    metadata_path::String;
    family_counts = NamedTuple[],
    fourier_summary = NamedTuple(),
    response_symmetry_summary = NamedTuple(),
    response_symmetry_summaries = NamedTuple[],
    band_summary = NamedTuple(),
    replica_summary = NamedTuple(),
)
    ctx = ACTIVE_PROGRESS[]
    ctx === nothing && return nothing
    effective_response_symmetry_summary =
        isempty(response_symmetry_summaries) ? response_symmetry_summary :
        progress_aggregate_response_symmetry_summaries(response_symmetry_summaries)
    Base.lock(ctx.lock)
    try
        progress_emit_text!(ctx, "")
        progress_emit_text!(ctx, "OUTPUTS")
        progress_emit_text!(ctx, "  +---------------+--------------------------------------+")
        progress_emit_text!(ctx, "  | kind          | path                                 |")
        progress_emit_text!(ctx, "  +---------------+--------------------------------------+")
        rows =
            Pair{String, String}["result $(idx)" => output for (idx, output) in enumerate(outputs)]
        isempty(metadata_path) || push!(rows, "metadata" => metadata_path)
        append!(rows, ["progress log" => ctx.out_path, "progress json" => ctx.jsonl_path])
        for (label, path) in rows
            for (index, chunk) in
                enumerate(progress_text_chunks(progress_display_path(ctx, path), 36))
                progress_emit_text!(
                    ctx,
                    "  | " * rpad(index == 1 ? label : "", 13) * " | " * rpad(chunk, 36) * " |",
                )
            end
        end
        progress_emit_text!(ctx, "  +---------------+--------------------------------------+")
        progress_emit_text!(ctx, "")
        progress_emit_lines!(ctx, progress_timing_lines(ctx))
        if !isempty(keys(replica_summary))
            progress_emit_text!(ctx, "REPLICA")
            progress_emit_text!(
                ctx,
                "  policy=$(replica_summary.requested_policy) -> $(replica_summary.effective_policy), source=$(replica_summary.source)",
            )
            progress_emit_text!(
                ctx,
                "  R=$(replica_summary.input_num_r_vectors) -> $(replica_summary.effective_num_r_vectors), materialized=$(replica_summary.input_minimum_distance_materialized) -> $(replica_summary.output_minimum_distance_materialized)",
            )
            progress_emit_text!(
                ctx,
                "  mp_grid=$(replica_summary.mp_grid), tolerance=$(replica_summary.wigner_seitz_tolerance), search_size=$(replica_summary.wigner_seitz_search_size), transformed=$(replica_summary.replica_transformed_this_run)",
            )
            progress_emit_text!(ctx, "  mapping sha256=$(replica_summary.mapping_sha256)")
            progress_emit_text!(
                ctx,
                "  mapping scheme=$(replica_summary.mapping_digest_scheme), wsvec=$(isnothing(replica_summary.wsvec_file) ? "not provided" : progress_display_path(ctx, replica_summary.wsvec_file)), wsvec sha256=$(replica_summary.wsvec_sha256)",
            )
            progress_emit_text!(
                ctx,
                "  normalization scalar=$(replica_summary.scalar_degeneracy_applied), pair=$(replica_summary.pair_degeneracy_applied)",
            )
            progress_emit_text!(ctx, "")
        end
        if !isempty(keys(effective_response_symmetry_summary))
            progress_emit_text!(ctx, "RESPONSE SYMMETRY")
            progress_emit_text!(ctx, "")
            progress_emit_text!(ctx, "  OVERVIEW")
            progress_emit_text!(
                ctx,
                progress_kv_line("status", effective_response_symmetry_summary.status),
            )
            progress_emit_text!(
                ctx,
                progress_kv_line("policy", effective_response_symmetry_summary.policy),
            )
            progress_emit_text!(
                ctx,
                progress_kv_line("k-mesh mode", effective_response_symmetry_summary.kmesh_mode),
            )
            progress_emit_text!(
                ctx,
                progress_kv_line(
                    "numerical tensor projection",
                    effective_response_symmetry_summary.numerical_tensor_projection_applied,
                ),
            )
            progress_emit_text!(
                ctx,
                progress_kv_line(
                    "machine-readable",
                    effective_response_symmetry_summary.summary_file,
                ),
            )
            classification = effective_response_symmetry_summary.group_classification
            active_group = effective_response_symmetry_summary.active_constraint_group
            progress_emit_text!(ctx, "")
            progress_emit_text!(ctx, "  GROUP CLASSIFICATION")
            if get(classification, "status", nothing) in ("UNRESOLVED", "MULTIPLE_TASK_GROUPS")
                progress_emit_text!(
                    ctx,
                    progress_kv_line("status", get(classification, "status", "UNRESOLVED")),
                )
            else
                structural = get(classification, "structural_space_group", Dict())
                structural_point = get(classification, "structural_point_group", Dict())
                magnetic = get(classification, "magnetic_space_group", Dict())
                full_magnetic_point = get(classification, "full_magnetic_point_group", Dict())
                progress_emit_text!(
                    ctx,
                    progress_kv_line(
                        "space group",
                        "$(get(structural, "hermann_mauguin", "UNRESOLVED")) " *
                        "(#$(get(structural, "international_number", "?")); " *
                        "Hall $(get(structural, "hall_symbol", "?")), " *
                        "hall=$(get(structural, "hall_number", "?")), " *
                        "setting=$(get(structural, "setting", "?")))",
                    ),
                )
                progress_emit_text!(
                    ctx,
                    progress_kv_line(
                        "ordinary point group",
                        get(structural_point, "hermann_mauguin", "UNRESOLVED"),
                    ),
                )
                progress_emit_text!(
                    ctx,
                    progress_kv_line(
                        "magnetic space group",
                        "$(get(magnetic, "type", "UNRESOLVED")); " *
                        "UNI=$(get(magnetic, "uni_number", "NOT_RECORDED")); " *
                        "BNS=$(get(magnetic, "bns_number", "NOT_RECORDED")); " *
                        "OG=$(get(magnetic, "og_number", "NOT_RECORDED"))",
                    ),
                )
                progress_emit_text!(
                    ctx,
                    progress_kv_line(
                        "full magnetic point group H-M (display)",
                        get(full_magnetic_point, "hermann_mauguin", "UNRESOLVED"),
                    ),
                )
                progress_emit_text!(
                    ctx,
                    progress_kv_line(
                        "active constraint group H-M (display)",
                        get(active_group, "hermann_mauguin", "UNRESOLVED"),
                    ),
                )
                for (label, group) in (
                    ("full magnetic point group", full_magnetic_point),
                    ("active constraint group", active_group),
                )
                    progress_emit_text!(
                        ctx,
                        progress_kv_line(
                            "$(label) identity",
                            "class=$(get(group, "magnetic_point_group_number", "?")); " *
                            "operation digest=$(get(group, "operation_digest", "NOT_RECORDED")); " *
                            "contract=$(get(group, "operation_digest_contract", "NOT_RECORDED"))",
                        ),
                    )
                    progress_emit_text!(
                        ctx,
                        progress_kv_line(
                            "$(label) display convention",
                            "$(get(group, "symbol_convention", "NOT_RECORDED")); " *
                            "equivalent axis notation=$(get(group, "equivalent_axis_notation", "NOT_RECORDED"))",
                        ),
                    )
                    progress_emit_text!(
                        ctx,
                        progress_kv_line(
                            "$(label) basis transform to input",
                            progress_group_basis_text(group),
                        ),
                    )
                end
                progress_emit_text!(
                    ctx,
                    progress_kv_line(
                        "time reversal included",
                        get(active_group, "include_time_reversal", "NOT_RECORDED"),
                    ),
                )
                progress_emit_text!(
                    ctx,
                    progress_kv_line(
                        "active operations",
                        "order=$(get(active_group, "group_order", "?")), " *
                        "unitary=$(get(active_group, "unitary_operation_count", "?")), " *
                        "antiunitary=$(get(active_group, "antiunitary_operation_count", "?"))",
                    ),
                )
                progress_emit_text!(
                    ctx,
                    progress_kv_line(
                        "detector",
                        "artifact Spglib $(get(active_group, "spglib_version", "NOT_RECORDED")); " *
                        "classifier $(get(active_group, "classifier_spglib_version", "NOT_RECORDED")); " *
                        "symprec=$(get(active_group, "symprec_angstrom", "?")) Angstrom; " *
                        "Seitz tolerance=$(get(active_group, "seitz_translation_tolerance_fractional", "?")) fractional; " *
                        "stability=$(get(active_group, "tolerance_stability", "UNRESOLVED"))",
                    ),
                )
            end
            generator_report = effective_response_symmetry_summary.point_group_generators
            progress_emit_text!(ctx, "")
            progress_emit_text!(ctx, "  POINT-GROUP GENERATORS")
            if get(generator_report, "closure_verified", false) !== true
                progress_emit_text!(
                    ctx,
                    progress_kv_line("status", get(generator_report, "status", "UNRESOLVED")),
                )
            else
                progress_emit_text!(
                    ctx,
                    "    canonical-order greedy irredundant set; not claimed globally minimum",
                )
                for generator in get(generator_report, "generators", Any[])
                    rows = get(generator, "rotation_fractional", Any[])
                    matrix_text = join(["[" * join(string.(row), " ") * "]" for row in rows], "; ")
                    progress_emit_text!(
                        ctx,
                        "    #$(get(generator, "sequence", "?")) " *
                        "$(get(generator, "kind", "?")) " *
                        "$(get(generator, "operation_symbol", "?")) " *
                        "W=$(matrix_text) source=$(get(generator, "source_operation_index", "?"))",
                    )
                end
                progress_emit_text!(
                    ctx,
                    "    closure=PASS reconstructed_order=$(get(generator_report, "reconstructed_group_order", "?"))",
                )
            end
            for summary in effective_response_symmetry_summary.human_summaries
                progress_emit_text!(ctx, "")
                progress_emit_text!(ctx, "  $(summary.title)")
                progress_emit_text!(ctx, "")
                progress_emit_text!(ctx, "    CONVENTION")
                progress_emit_text!(
                    ctx,
                    "      component order: output/current axes first; optical field indices (b,c) last",
                )
                progress_emit_text!(
                    ctx,
                    "      time reversal: $(summary.time_reversal.description)",
                )
                progress_emit_text!(ctx, "")
                progress_emit_text!(ctx, "    CARTESIAN COMPONENTS")
                progress_emit_text!(
                    ctx,
                    @sprintf("      %-18s %-18s %-18s", "Component", "Real part", "Imaginary part"),
                )
                for component in summary.real_imaginary_components
                    progress_emit_text!(
                        ctx,
                        @sprintf(
                            "      %-18s %-18s %-18s",
                            component.component,
                            uppercase(string(component.real_part)),
                            uppercase(string(component.imaginary_part)),
                        ),
                    )
                end
                progress_emit_text!(ctx, "")
                progress_emit_text!(ctx, "    SYMMETRY RELATIONS")
                progress_emit_text!(ctx, "")
                progress_emit_text!(ctx, "      Real part")
                if isempty(summary.real_symmetry_relations)
                    progress_emit_text!(ctx, "        (none)")
                else
                    for relation in summary.real_symmetry_relations
                        progress_emit_text!(ctx, "        $(relation)")
                    end
                end
                progress_emit_text!(ctx, "")
                progress_emit_text!(ctx, "      Imaginary part")
                if isempty(summary.imaginary_symmetry_relations)
                    progress_emit_text!(ctx, "        (none)")
                else
                    for relation in summary.imaginary_symmetry_relations
                        progress_emit_text!(ctx, "        $(relation)")
                    end
                end
                if summary.calculated_component !== nothing
                    progress_emit_text!(ctx, "")
                    progress_emit_text!(ctx, "    CALCULATED COMPONENT")
                    calculated = summary.calculated_component
                    if hasproperty(calculated, :status)
                        progress_emit_text!(
                            ctx,
                            "  " * progress_kv_line("component", calculated.component),
                        )
                        progress_emit_text!(
                            ctx,
                            "  " * progress_kv_line("status", calculated.status),
                        )
                    else
                        progress_emit_text!(
                            ctx,
                            "  " * progress_kv_line("component", calculated.component),
                        )
                        progress_emit_text!(
                            ctx,
                            "  " *
                            progress_kv_line("Real part", uppercase(string(calculated.real_part))),
                        )
                        progress_emit_text!(
                            ctx,
                            "  " * progress_kv_line(
                                "Imaginary part",
                                uppercase(string(calculated.imaginary_part)),
                            ),
                        )
                    end
                end
                progress_emit_text!(ctx, "")
                progress_emit_text!(ctx, "    QUALIFICATION")
                progress_emit_text!(ctx, "  " * progress_kv_line("status", summary.qualification))
                progress_emit_text!(
                    ctx,
                    "  " * progress_kv_line("note", summary.qualification_note),
                )
            end
            if effective_response_symmetry_summary.symmetry_warning_count > 0
                progress_emit_text!(ctx, "")
                progress_emit_text!(ctx, "  WARNINGS")
                for warning in effective_response_symmetry_summary.symmetry_warnings
                    progress_emit_text!(ctx, "    $(warning)")
                end
            end
            progress_emit_text!(ctx, "")
        end
        if !isempty(keys(band_summary))
            progress_emit_text!(ctx, "BAND")
            progress_emit_text!(
                ctx,
                "  k-points=$(band_summary.total_kpoints), max Hermiticity residual=$(band_summary.maximum_hermiticity_residual)",
            )
            progress_emit_text!(
                ctx,
                "  replica=$(band_summary.requested_replica_policy) -> $(band_summary.effective_replica_policy), qualification=$(band_summary.qualification)",
            )
            progress_emit_text!(ctx, "")
        end
        progress_emit_text!(ctx, "DONE")
        progress_emit_text!(ctx, "  elapsed      : $(progress_hms(progress_elapsed(ctx)))")
        progress_write_jsonl_event!(
            ctx,
            "run_done";
            extra = [
                "outputs" => outputs,
                "metadata_path" => metadata_path,
                "progress_out_path" => ctx.out_path,
                "progress_jsonl_path" => ctx.jsonl_path,
                "stage_seconds" => copy(ctx.stage_seconds),
                "family_counts" => family_counts,
                "fourier_summary" => fourier_summary,
                "response_symmetry_summary" => response_symmetry_summary,
                "response_symmetry_summaries" => response_symmetry_summaries,
                "band_summary" => band_summary,
                "replica_summary" => replica_summary,
                "system_summary" => ctx.system_summary,
            ],
        )
    finally
        Base.unlock(ctx.lock)
    end
    return nothing
end

"""
Format an exception and append a FAILED text line plus `run_failed` JSONL event; no-op without active progress.
"""
function progress_run_failed!(err)
    ctx = ACTIVE_PROGRESS[]
    ctx === nothing && return nothing
    message = sprint(showerror, err)
    Base.lock(ctx.lock)
    try
        progress_emit_text!(ctx, "[$(progress_hms(progress_elapsed(ctx)))] FAILED   $(message)")
        progress_write_jsonl_event!(ctx, "run_failed"; extra = ["error_message" => message])
    finally
        Base.unlock(ctx.lock)
    end
    return nothing
end
