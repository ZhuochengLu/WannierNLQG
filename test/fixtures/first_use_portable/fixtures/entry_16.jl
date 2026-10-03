using JSON3, SHA, Test, Serialization
length(ARGS)==3 || error("usage frozen_native_input_directory receipt expected_source")
const TARGET=:authoritative_band_hamiltonian
include(Main.FirstUsePortableSupport.input("fixtures/support_3.jl"))
import_start=time_ns();
import_timed=@timed Core.eval(Main, :(using WannierNLQG, LinearAlgebra, MPI));
import_wall=(time_ns()-import_start)/1e9
@test samefile(pkgdir(WannierNLQG), ARGS[3]);
@test !MPI.Initialized()
const W=WannierNLQG.Wannierization
input_file=abspath(ARGS[1])
@test bytes2hex(
    sha256(read(input_file)),
)=="1f9680ff177d3d683afe25c21bae4fbeaded2e803c17c1b20e412ede616551f1"
# Actual Root-owned config/EIG frozen from the unchanged valid fixture.
# Deserialize/configuration time is separate from the exported first call.
config_timed=@timed Main.FirstUsePortableSupport.deserialize_input(input_file)
const authority_config = config_timed.value.positional[1]
const native_eig = config_timed.value.positional[2]
@test isempty(config_timed.value.keyword)
@test authority_config isa W.SymmetryAdaptedWannierizationConfig
@test native_eig isa WannierNLQG.IO.WannierEIG
model_timed=(time = 0.0, compile_time = 0.0)
before=Dict(
    string(n)=>Base.get_extension(WannierNLQG, n)!==nothing for n in (
        :WannierNLQGWannierizationExt,
        :WannierNLQGWannierizationPrecompileExt,
        :WannierNLQGSymmetryFoundationExt,
    )
)
@test !before["WannierNLQGWannierizationExt"]
# Resolve the extension-exported callable only AFTER the public timer starts.
expr=quote
    let backend=first(W._load_wannierization_extension!())
        Base.invokelatest(
            getproperty(backend, :authoritative_band_hamiltonian),
            authority_config,
            native_eig,
        )
    end
end
trace=get(ENV, "FIRSTUSE_TRACE_PATH", "");
begin_bytes=isempty(trace) ? nothing : filesize(trace)
diagnose=get(ENV, "FIRSTUSE_COLLECT_INFERENCE", "")=="1"
if diagnose
    Base.Core.Compiler.Timings.reset_timings();
    Base.Core.Compiler.__set_measure_typeinf(true)
end
started=time_ns()
first_timed=try
    @timed Core.eval(Main, expr)
finally
    if diagnose
        Base.Core.Compiler.__set_measure_typeinf(false);
        Base.Core.Compiler.Timings.close_current_timer()
    end
end
first_wall=(time_ns()-started)/1e9;
end_bytes=isempty(trace) ? nothing : filesize(trace)
if diagnose
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
    write(joinpath(dirname(ARGS[2]), "inference_timings.json"), JSON3.write(inference_rows))
    write(
        joinpath(dirname(ARGS[2]), "inference_capture_inventory.json"),
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
            joinpath(dirname(ARGS[2]), "inference_full_observations_control.json"),
            JSON3.write(full_control_rows),
        )
    end
    Serialization.serialize(
        joinpath(dirname(ARGS[2]), "actual_unprintable_inference_types.jls"),
        unprintable_types,
    )
end
value=first_timed.value
@test size(value.matrices_ev)==(2, 2, 2)
@test all(isfinite, value.matrices_ev)
@test maximum(abs, value.matrices_ev)>0
summary=FirstUseExpertProbe.numeric_summary(value);
@test summary.all_finite
reference=JSON3.read(
    read(Main.FirstUsePortableSupport.input("assets/additional_38/receipt.json"), String),
).first_calls[1].return_summary
# Scientific arrays/scalars retain exact native SHA/payload. JSON spelling of
# a derived max_abs statistic (1 versus 1.0) is not scientific bit identity.
@test length(summary.leaves)==length(reference.leaves)
for (actual, expected) in zip(summary.leaves, reference.leaves)
    @test Set(string.(keys(actual)))==Set(string.(keys(expected)))
    for key in keys(actual)
        @test getproperty(actual, key)==expected[string(key)]
    end
end
@test !MPI.Initialized()
later=@timed Core.eval(Main, expr);
@test FirstUseExpertProbe.numeric_summary(later.value).leaves==summary.leaves
write(
    ARGS[2],
    JSON3.write((
        source = pkgdir(WannierNLQG),
        target = String(TARGET),
        argument_deserialize_time = config_timed.time,
        argument_deserialize_compile_seconds = config_timed.compile_time,
        model_read_scope = "already-frozen actual EIG data; no model reader in measured process",
        scope = "Actual extension-public native-authority call; required backend loading inside timer; frozen valid input, no preparatory expert call",
        gc_on = true,
        mpi_library = MPI.Get_library_version(),
        mpi_initialized = MPI.Initialized(),
        extension_before = before,
        import_wall_seconds = import_wall,
        import_compile_seconds = import_timed.compile_time,
        config_time = config_timed.time,
        config_compile_seconds = config_timed.compile_time,
        model_read_time = model_timed.time,
        model_read_compile_seconds = model_timed.compile_time,
        time = first_timed.time,
        first_wall_seconds = first_wall,
        compile_time = first_timed.compile_time,
        recompile_time = first_timed.recompile_time,
        gc_time = first_timed.gctime,
        allocated_bytes = first_timed.bytes,
        trace_bytes_before = begin_bytes,
        trace_bytes_after = end_bytes,
        return_summary = summary,
        later_time = later.time,
        later_compile_time = later.compile_time,
        native_reference_science_exact = true,
    )),
)
println(
    "NATIVE_AUTHORITY_COLD_ENTRY_PASS compile=",
    first_timed.compile_time,
    " diagnose=",
    diagnose,
)
