#!/usr/bin/env julia

using HDF5
using JSON3

length(ARGS) == 1 || error("usage: verify_experts.jl expert_campaign_dir")
root = abspath(first(ARGS))
isdir(root) || error("missing expert campaign")

function science_datasets(path)
    result = Dict{String, Any}()
    h5open(path, "r") do file
        function visit(group, prefix = "")
            for name in keys(group)
                object = group[name]
                label = prefix * "/" * name
                if object isa HDF5.Group
                    visit(object, label)
                else
                    result[label] = read(object)
                end
            end
        end
        visit(file)
    end
    return result
end

function science_record(case, directory)
    record = JSON3.read(read(joinpath(directory, "result.json"), String), Dict{String, Any})
    if case == "wannier"
        return Dict(
            key => record[key] for key in ("status", "v_shape", "v_real_bits", "v_imag_bits")
        )
    end
    audit = JSON3.read(read(joinpath(directory, "audit.json"), String), Dict{String, Any})
    # The fixture HDF5 file records its own byte identity. That provenance
    # changes across independent writes; its physical datasets are compared
    # below, while every other audit diagnostic must match exactly.
    pop!(audit, "input_sha256")
    return Dict(
        "record" => Dict(
            key => record[key] for key in (
                "status",
                "violation_count",
                "fixed_gap_physics_metrics_status",
                "block_partition_policy",
            )
        ),
        "audit" => audit,
        "csv" => read(joinpath(directory, "audit.csv")),
        "hdf5" => science_datasets(joinpath(directory, "audit.h5")),
    )
end

summary = Dict{String, Any}()
for (case, metrics) in (
    ("wannier", ("prepare_compile_time", "solver_compile_time", "readback_compile_time")),
    ("paw_fixed", ("audit_compile_time",)),
    ("paw_weighted", ("audit_compile_time",)),
)
    samples = Dict{String, Any}[]
    science = Any[]
    for (ordinal, arm) in enumerate("ABBA")
        attempt = joinpath(root, case, "$(ordinal)_$(arm)")
        output = joinpath(attempt, "output")
        receipt = JSON3.read(read(joinpath(attempt, "attempt.json"), String), Dict{String, Any})
        receipt["exit_code"] == 0 || error("failed attempt: $(attempt)")
        record = JSON3.read(read(joinpath(output, "result.json"), String), Dict{String, Any})
        observed = Dict(key => Float64(record[key]) for key in metrics)
        all(isfinite, values(observed)) || error("nonfinite compilation: $(attempt)")
        if arm == 'B'
            all(value <= 0.5 for value in values(observed)) ||
                error("expert compilation exceeds 0.5 s: $(attempt)")
        end
        push!(
            samples,
            Dict(
                "arm" => string(arm),
                "ordinal" => ordinal,
                "compile_seconds" => observed,
                "process_wall_seconds" => receipt["process_wall_seconds"],
                "max_tree_rss_kib" => receipt["max_tree_rss_kib"],
            ),
        )
        push!(science, science_record(case, output))
    end
    all(isequal(item, first(science)) for item in science) ||
        error("expert scientific results differ: $(case)")
    summary[case] =
        Dict("samples" => samples, "science_exact" => true, "metrics" => collect(metrics))
end
write(joinpath(root, "summary.json"), JSON3.write(summary))
println("expert first-use and scientific equality passed for three workflows")
