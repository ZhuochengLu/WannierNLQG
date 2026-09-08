# Atomically publish a JSON object.
function _write_gauge_aware_json(filename::AbstractString, payload; overwrite::Bool)
    path = abspath(filename)
    ispath(path) && !overwrite && throw(ArgumentError("refusing to overwrite $(path)"))
    mkpath(dirname(path))
    temporary, io = mktemp(dirname(path); cleanup = false)
    completed = false
    try
        JSON3.pretty(io, payload)
        println(io)
        close(io)
        mv(temporary, path; force = true)
        completed = true
    finally
        isopen(io) && close(io)
        !completed && isfile(temporary) && rm(temporary; force = true)
    end
    return path
end

# Read the Convention-II home-cell centers serialized in one TB model.
function _gauge_aware_tb_centers(model::TightBindingModel)
    home = only(
        findall(index -> all(iszero, @view(model.r_vectors[:, index])), axes(model.r_vectors, 2)),
    )
    centers = zeros(Float64, model.num_orbitals, 3)
    for orbital in 1:model.num_orbitals, direction in 1:3
        centers[orbital, direction] = real(model.position_r[orbital, orbital, direction, home])
    end
    return centers
end

# Build the stable Hamiltonian/position inventory from a serialized TB readback.
function _gauge_aware_tb_operators(model::TightBindingModel)
    return Dict(
        REAL_SPACE_HAMILTONIAN =>
            RealSpaceOperator(HAMILTONIAN_SYMMETRY_SPEC, model.r_vectors, model.hamiltonian_r),
        REAL_SPACE_POSITION =>
            RealSpaceOperator(POSITION_SYMMETRY_SPEC, model.r_vectors, model.position_r),
    )
end

# Export and bit-exactly validate one paired TB/Packed-HDF5 model.
function _write_gauge_aware_operator_bundle(
    config::GaugeAwareSymmetrizationConfig,
    tb_file::AbstractString,
    bundle_file::AbstractString,
    raw_centers_cartesian::Matrix{Float64},
    center_policy::Symbol,
    replica_policy::Symbol,
    threshold_events::Vector{GaugeAwareThresholdEvent},
    source_hashes::Dict{String, String},
)
    tb_roundtrip = read_wannier_tb(tb_file)
    final_centers_cartesian = _gauge_aware_tb_centers(tb_roundtrip)
    inverse_lattice = inv(tb_roundtrip.lattice)
    raw_centers_fractional = raw_centers_cartesian * inverse_lattice
    final_centers_fractional = final_centers_cartesian * inverse_lattice
    failed_events = filter(event -> !event.passed, threshold_events)
    production_eligible = true
    geometry = Dict(
        "wannier_center_policy" => String(center_policy),
        "real_space_replica_policy" => String(replica_policy),
        "production_eligible" => production_eligible,
        "minimum_distance_materialized" => replica_policy == :minimum_distance,
        "mp_grid" => collect(read_wannier_chk(config.chk_file).mp_grid),
        "wannier_center_tolerance" => config.thresholds.raw_position_angstrom,
        "wigner_seitz_tolerance" => config.wigner_seitz_tolerance,
        "wigner_seitz_search_size" => config.wigner_seitz_search_size,
        "raw_wannier_centers_cartesian" => raw_centers_cartesian,
        "raw_wannier_centers_fractional" => raw_centers_fractional,
        "final_wannier_centers_cartesian" => final_centers_cartesian,
        "final_wannier_centers_fractional" => final_centers_fractional,
        "center_alignment_lattice_shifts" => zeros(Int, size(final_centers_cartesian)),
        "replica_mapping_sha256" =>
            bytes2hex(SHA.sha256(reinterpret(UInt8, vec(Int64.(tb_roundtrip.r_vectors))))),
    )
    status = isempty(failed_events) ? PASS : PASS_WITH_WARNINGS
    eligibility = Dict(
        "production_eligible" => production_eligible,
        "diagnostic_only" => false,
        "gauge_aware_status" => string(status),
        "threshold_policy" => String(config.threshold_policy),
        "thresholds_passed" => isempty(failed_events),
        "warning_count" => length(failed_events),
    )
    provenance = Dict(
        "wanniernlqg_version" => string(Base.pkgversion(WannierNLQG)),
        "source_tree_sha256" => _source_tree_sha256(),
        "julia_version" => string(VERSION),
        "paired_tb_path" => abspath(tb_file),
        "input_sha256" => source_hashes,
    )
    symmetry = Dict(
        "symmetrization_status" => "applied",
        "gauge_aware_status" => string(status),
        "gauge_policy" => String(config.gauge_policy),
        "threshold_policy" => String(config.threshold_policy),
        "actual_chk_wannier_sewing" => true,
        "polar_projection_applied" => false,
        "hidden_hermitianization_applied" => false,
    )
    diagnostics = Dict(
        "thresholds_passed" => isempty(failed_events),
        "warning_count" => length(failed_events),
        "threshold_events_json" =>
            JSON3.write(_gauge_aware_threshold_payload.(threshold_events)),
    )
    write_real_space_operator_bundle(
        bundle_file,
        tb_roundtrip.lattice,
        tb_roundtrip.r_degeneracies,
        _gauge_aware_tb_operators(tb_roundtrip);
        profile = :hamiltonian_position,
        overwrite = config.overwrite,
        paired_tb_sha256 = _sha256_file(tb_file),
        provenance,
        symmetry,
        geometry,
        diagnostics,
        eligibility,
    )
    loaded = read_real_space_operator_bundle(bundle_file)
    loaded.manifest.production_eligible ||
        throw(ArgumentError("Packed HDF5 production eligibility round-trip failed"))
    loaded.lattice == tb_roundtrip.lattice ||
        throw(ArgumentError("Packed HDF5 lattice differs from paired TB"))
    loaded.degeneracies == tb_roundtrip.r_degeneracies ||
        throw(ArgumentError("Packed HDF5 degeneracies differ from paired TB"))
    loaded.manifest.r_vectors == tb_roundtrip.r_vectors ||
        throw(ArgumentError("Packed HDF5 R support differs from paired TB"))
    loaded.operators[REAL_SPACE_HAMILTONIAN].data == tb_roundtrip.hamiltonian_r ||
        throw(ArgumentError("Packed HDF5 Hamiltonian differs from paired TB"))
    loaded.operators[REAL_SPACE_POSITION].data == tb_roundtrip.position_r ||
        throw(ArgumentError("Packed HDF5 position differs from paired TB"))
    return abspath(bundle_file)
end

# Persist per-operation/per-k closure evidence for audit and regression tests.
function _write_actual_sewing_analysis(
    config::GaugeAwareSymmetrizationConfig,
    actual,
    operations::Vector{SymmetryOperation},
)
    path = joinpath(config.output_root, "analysis", "actual_wannier_sewing.tsv")
    open(path, "w") do io
        println(
            io,
            "operation\tantiunitary\tsource_kpoint\ttarget_kpoint\tband_block\tfirst_band\tlast_band\tchk_semiunitarity_opnorm\tsubspace_closure_block_opnorm\tsubspace_closure_total_opnorm\tsewing_unitarity_opnorm",
        )
        for block in actual.block_residuals
            operation_index = block.operation
            source = block.source
            println(
                io,
                join(
                    (
                        operation_index,
                        block.antiunitary,
                        source,
                        block.target,
                        block.block_label,
                        block.first_band,
                        block.last_band,
                        actual.semiunitarity_residuals[source],
                        block.closure_opnorm,
                        actual.closure_residuals[operation_index, source],
                        actual.unitarity_residuals[operation_index, source],
                    ),
                    '\t',
                ),
            )
        end
    end
    return path
end

# Persist the deterministic representation-to-CHK k-point bijection and wraps.
function _write_gauge_aware_kpoint_permutation(
    config::GaugeAwareSymmetrizationConfig,
    representation::BandRepresentation,
    chk::WannierCHK,
    representation_to_chk::Vector{Int},
)
    path = joinpath(config.output_root, "analysis", "kpoint_permutation.tsv")
    open(path, "w") do io
        println(io, "representation_kpoint\tchk_kpoint\tshift_1\tshift_2\tshift_3")
        for representation_index in eachindex(representation_to_chk)
            chk_index = representation_to_chk[representation_index]
            difference =
                @view(representation.kpoints_fractional[representation_index, :]) .-
                @view(chk.kpt_red[chk_index, :])
            shift = round.(Int, difference)
            println(io, join((representation_index, chk_index, shift[1], shift[2], shift[3]), '\t'))
        end
    end
    return path
end

# Persist current status, measured gates, and structured threshold evidence.
function _publish_gauge_aware_status(
    config::GaugeAwareSymmetrizationConfig,
    status::GaugeAwareSymmetrizationStatus,
    artifacts::Dict{String, String},
    metrics::Dict{String, Float64},
    diagnostics::Vector{String},
    threshold_events::Vector{GaugeAwareThresholdEvent} = GaugeAwareThresholdEvent[],
)
    failed_events = filter(event -> !event.passed, threshold_events)
    thresholds_passed = isempty(failed_events)
    production_eligible = status in (PASS, PASS_WITH_WARNINGS)
    workflow_log = joinpath(config.output_root, "logs", "workflow.log")
    open(workflow_log, "w") do io
        timestamp = Dates.format(Dates.now(), "yyyy-mm-ddTHH:MM:" * "S" * "S")
        println(io, "timestamp=$(timestamp)")
        println(io, "status=$(status)")
        println(io, "threshold_policy=$(config.threshold_policy)")
        println(
            io,
            "materialization_variants=$(join(string.(config.materialization_variants), ','))",
        )
        println(io, "thresholds_passed=$(thresholds_passed)")
        println(io, "warning_count=$(length(failed_events))")
        for key in sort!(collect(keys(metrics)))
            println(io, "metric.$(key)=$(metrics[key])")
        end
        for diagnostic in diagnostics
            println(io, "diagnostic=$(diagnostic)")
        end
    end
    artifacts["workflow_log"] = workflow_log
    analysis = joinpath(config.output_root, "analysis")
    mkpath(analysis)
    threshold_tsv = joinpath(analysis, "threshold_events.tsv")
    open(threshold_tsv, "w") do io
        println(
            io,
            "stage\tmetric\tvalue\tthreshold\trelation\tpassed\toperation\tkpoint\tband_block\tcontext",
        )
        for event in threshold_events
            context = replace(event.context, '\t' => ' ', '\n' => ' ')
            println(
                io,
                join(
                    (
                        event.stage,
                        event.metric,
                        event.value,
                        event.threshold,
                        event.relation,
                        event.passed,
                        event.operation,
                        event.kpoint,
                        event.band_block,
                        context,
                    ),
                    '\t',
                ),
            )
        end
    end
    artifacts["threshold_events_tsv"] = threshold_tsv
    report_json = joinpath(analysis, "FINAL_VALIDATION.json")
    json_metrics = Dict{String, Any}(
        key => (isfinite(value) ? value : string(value)) for (key, value) in metrics
    )
    payload = Dict(
        "schema" => "WannierNLQG.gauge_aware_symmetrization",
        "schema_version" => "1.0",
        "status" => string(status),
        "production_eligible" => production_eligible,
        "threshold_policy" => String(config.threshold_policy),
        "materialization_variants" => String.(config.materialization_variants),
        "thresholds_passed" => thresholds_passed,
        "warning_count" => length(failed_events),
        "threshold_events" => _gauge_aware_threshold_payload.(threshold_events),
        "artifacts" => artifacts,
        "metrics" => json_metrics,
        "diagnostics" => diagnostics,
    )
    _write_gauge_aware_json(report_json, payload; overwrite = true)
    artifacts["validation_json"] = report_json
    report_markdown = joinpath(config.output_root, "REPORT.md")
    open(report_markdown, "w") do io
        println(io, "# \u73b0\u6709 TB gauge-aware \u5bf9\u79f0\u5316\u62a5\u544a")
        println(io)
        println(io, "- \u72b6\u6001: `$(status)`")
        println(io, "- \u751f\u4ea7\u53ef\u7528\u6807\u8bb0: `$(production_eligible)`")
        println(io, "- \u6570\u503c\u95e8\u7981\u5168\u90e8\u901a\u8fc7: `$(thresholds_passed)`")
        println(io, "- \u8d85\u9608\u503c\u8b66\u544a\u6570: `$(length(failed_events))`")
        println(io, "- \u9608\u503c\u7b56\u7565: `$(config.threshold_policy)`")
        println(io, "- \u65b9\u6cd5: actual CHK composite gauge; no SAWF/Wannierization/response")
        status == PASS_WITH_WARNINGS && println(
            io,
            "- \u8b66\u793a: \u672c\u4ea7\u7269\u6309\u6307\u5b9a\u7b56\u7565\u53ef\u7528\uff0c\u4f46\u5e76\u4e0d\u8868\u793a\u6240\u6709\u79d1\u5b66\u95e8\u7981\u901a\u8fc7\u3002",
        )
        println(io)
        println(io, "## \u95e8\u7981\u6307\u6807")
        println(io)
        for key in sort!(collect(keys(metrics)))
            println(io, "- `$(key)` = `$(metrics[key])`")
        end
        if !isempty(threshold_events)
            println(io)
            println(io, "## \u7ed3\u6784\u5316\u9608\u503c\u4e8b\u4ef6")
            println(io)
            println(
                io,
                "| \u9636\u6bb5 | \u6307\u6807 | \u5b9e\u9645\u503c | \u9608\u503c | \u901a\u8fc7 | \u4f4d\u7f6e |",
            )
            println(io, "|---|---|---:|---:|:---:|---|")
            for event in threshold_events
                location = "op=$(event.operation), k=$(event.kpoint), block=$(event.band_block)"
                println(
                    io,
                    "| `$(event.stage)` | `$(event.metric)` | `$(event.value)` | `$(event.threshold)` | `$(event.passed)` | $(location) |",
                )
            end
        end
        if !isempty(diagnostics)
            println(io)
            println(io, "## \u8bca\u65ad")
            println(io)
            for diagnostic in diagnostics
                println(io, "- $(diagnostic)")
            end
        end
    end
    artifacts["report_markdown"] = report_markdown
    artifact_manifest = joinpath(config.output_root, "manifests", "artifact_sha256.tsv")
    open(artifact_manifest, "w") do io
        println(io, "label\tsha256\tpath")
        for label in sort!(collect(keys(artifacts)))
            path = artifacts[label]
            isfile(path) || continue
            println(io, "$(label)\t$(_sha256_file(path))\t$(abspath(path))")
        end
    end
    artifacts["artifact_manifest"] = artifact_manifest
    return GaugeAwareSymmetrizationResult(
        status,
        abspath(config.output_root),
        copy(artifacts),
        copy(metrics),
        copy(diagnostics),
        copy(threshold_events),
    )
end

# Persist input identities before any scientific projection begins.
function _write_gauge_aware_input_manifest(
    config::GaugeAwareSymmetrizationConfig,
    files::Vector{Pair{String, String}},
)
    path = joinpath(config.output_root, "manifests", "input_sha256.tsv")
    mkpath(dirname(path))
    open(path, "w") do io
        println(io, "label\tsha256\tpath")
        for (label, filename) in files
            println(io, "$(label)\t$(_sha256_file(filename))\t$(abspath(filename))")
        end
    end
    return path
end

# Read only the MMN dimensions needed by the Hamiltonian-stage provenance gate.
function _read_gauge_aware_mmn_dimensions(filename::AbstractString)
    return open(filename, "r") do io
        eof(io) && throw(ArgumentError("MMN file is empty"))
        _ = readline(io)
        eof(io) && throw(ArgumentError("MMN dimension line is missing"))
        tokens = split(strip(readline(io)))
        length(tokens) >= 3 || throw(ArgumentError("MMN dimension line is malformed"))
        return (
            num_bands = parse(Int, tokens[1]),
            num_kpoints = parse(Int, tokens[2]),
            num_neighbors = parse(Int, tokens[3]),
        )
    end
end
