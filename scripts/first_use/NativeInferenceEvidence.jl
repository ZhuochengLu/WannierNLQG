module NativeInferenceEvidence
using JSON3, Serialization
# Persist only AFTER the public timer and inference recording are closed.
function persist(directory::String)
    ispath(directory) && error("inference evidence directory exists")
    mkpath(directory)
    # Post-call collection only. Actual Type identity, never string similarity,
    # defines a duplicate. Counter aggregation preserves every timing observation.
    inference_rows=Any[]
    unprintable_types=Pair{String, Any}[]
    by_actual_type=IdDict{Any, Int}()
    actual_type_values=Any[]
    printed_methods=IdDict{Any, String}()
    full_control = get(ENV, "FIRSTUSE_INFERENCE_DEDUP_CONTROL", "") == "1"
    full_control_rows=Any[]
    raw_observation_count=Ref(0)
    summed_exclusive_seconds=Ref(0.0)
    function visit_inference(t, depth)
        mi=t.mi_info.mi
        raw_observation_count[]+=1
        summed_exclusive_seconds[]+=t.time/1e9
        key=mi.specTypes
        method=get!(printed_methods, mi.def) do
            string(mi.def)
        end
        if haskey(by_actual_type, key)
            row=inference_rows[by_actual_type[key]]
            row["observation_count"]+=1
            row["exclusive_seconds"]+=t.time/1e9
            row["depth_min"]=min(row["depth_min"], depth)
            method in row["methods"] || push!(row["methods"], method)
        else
            printed=sprint(show, key; context = :module=>Base.Core)
            by_actual_type[key]=length(inference_rows)+1
            push!(actual_type_values, key)
            push!(
                inference_rows,
                Dict(
                    "signature"=>printed,
                    "method"=>method,
                    "exclusive_seconds"=>t.time/1e9,
                    "depth"=>depth,
                    "depth_min"=>depth,
                    "observation_count"=>1,
                    "methods"=>[method],
                ),
            )
            occursin("::", printed) && push!(unprintable_types, printed=>key)
        end
        if full_control
            group=by_actual_type[key]
            actual_type_values[group]===key || error("CONTROL_ACTUAL_TYPE_IDENTITY_MISMATCH")
            # Lossless dictionary encoding: same immutable Type object and same
            # show context, retaining every observation without repeating show.
            push!(
                full_control_rows,
                (
                    signature = inference_rows[group]["signature"],
                    actual_type_group = group,
                    method = method,
                    exclusive_seconds = t.time/1e9,
                    depth = depth,
                ),
            )
        end
        foreach(child->visit_inference(child, depth+1), t.children)
    end
    foreach(t->visit_inference(t, 0), Base.Core.Compiler.Timings._timings)
    @assert sum(row["observation_count"] for row in inference_rows)==raw_observation_count[]
    write(joinpath(directory, "inference_timings.json"), JSON3.write(inference_rows))
    write(
        joinpath(directory, "inference_capture_inventory.json"),
        JSON3.write((
            raw_observations = raw_observation_count[],
            unique_actual_types = length(by_actual_type),
            summed_exclusive_seconds = summed_exclusive_seconds[],
            rule = "IdDict keyed by actual MethodInstance.specTypes identity; no signatures or observations excluded",
            scope = "post-public-call diagnostic serialization only; not a timing sample",
        )),
    )
    if full_control
        length(full_control_rows)==raw_observation_count[] || error("CONTROL_OBSERVATION_LOSS")
        group_counts=zeros(Int, length(inference_rows))
        group_methods=[Set{String}() for _ in inference_rows]
        for observation in full_control_rows
            i=observation.actual_type_group
            observation.signature==inference_rows[i]["signature"] ||
                error("CONTROL_SIGNATURE_MISMATCH")
            group_counts[i]+=1
            push!(group_methods[i], observation.method)
        end
        for (i, row) in enumerate(inference_rows)
            group_counts[i]==row["observation_count"] || error("CONTROL_GROUP_COUNT_MISMATCH")
            group_methods[i]==Set(row["methods"]) || error("CONTROL_METHOD_LOSS")
        end
        write(
            joinpath(directory, "inference_full_observations_control.json"),
            JSON3.write(full_control_rows),
        )
    end
    Serialization.serialize(
        joinpath(directory, "actual_unprintable_inference_types.jls"),
        unprintable_types,
    )
    Serialization.serialize(
        joinpath(directory, "actual_all_inference_types.jls"),
        actual_type_values,
    )
    return nothing
end
end
