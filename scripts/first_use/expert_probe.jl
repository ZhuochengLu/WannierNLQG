#!/usr/bin/env julia

"""Instrument the first syntactic expert call in an existing small test fixture.

Calls are evaluated after the timer starts, preventing Julia look-ahead compilation
from escaping the measured public-call interval. Fixture setup remains outside.
The chosen test must pass independently, and its first target call must succeed.
"""

GC.enable(true) || error("FIRSTUSE_GC_WAS_DISABLED")

using JSON3
using SHA
using Test
const IMPORT_STARTED_NS = time_ns()
const IMPORT_TIMED = @timed Core.eval(Main, :(using WannierNLQG))
const IMPORT_WALL_SECONDS = (time_ns()-IMPORT_STARTED_NS)/1e9

const PACKAGE_ROOT = pkgdir(WannierNLQG)
const EXPECTED_PACKAGE_ROOT = get(ENV, "FIRSTUSE_EXPECTED_PACKAGE_ROOT", "")
isempty(EXPECTED_PACKAGE_ROOT) ||
    samefile(PACKAGE_ROOT, EXPECTED_PACKAGE_ROOT) ||
    error("FIRSTUSE_LOADED_PACKAGE_MISMATCH: $(PACKAGE_ROOT) != $(EXPECTED_PACKAGE_ROOT)")

length(ARGS) == 3 || error("usage: probe_expert_call.jl target test_file receipt.json")
const TARGET = Symbol(ARGS[1])
const TEST_FILE = abspath(ARGS[2])
const RECEIPT = abspath(ARGS[3])
isfile(TEST_FILE) || error("missing expert fixture")
ispath(RECEIPT) && error("receipt already exists")
const PORTABLE_ROOT = abspath(ENV["FIRSTUSE_PORTABLE_PAYLOAD_ROOT"])
Base.include(Main, joinpath(PORTABLE_ROOT, "FirstUsePortableSupport_v1.jl"))
FirstUsePortableSupport.configure!(PORTABLE_ROOT, joinpath(dirname(RECEIPT), "argument_outputs"))
for (key, value) in FirstUsePortableSupport.environment(ENV["FIRSTUSE_PORTABLE_ENTRY_ID"])
    ENV[key] = value
end
cd(PORTABLE_ROOT)
const ROOT = PACKAGE_ROOT
const TEST_MODEL_FILE =
    joinpath(ROOT, "examples", "fixtures", "synthetic_runtime", "synthetic_tb.dat")
const REQUESTED_SUPPORTS = split(
    get(
        ENV,
        "FIRSTUSE_FIXTURE_SUPPORTS",
        "OperatorBundleTestSupport.jl,WannierizationFixtureSupport.jl,ResponseTestSupport.jl,DocumentedExampleTestSupport.jl",
    ),
    ',';
    keepempty = false,
)
const SUPPORT_STARTED_NS=time_ns()
for support in REQUESTED_SUPPORTS
    basename(support)==support || error("support name must be a basename")
    Base.include(
        Main,
        joinpath(get(ENV, "FIRSTUSE_FIXTURE_SUPPORT_ROOT", dirname(TEST_FILE)), support),
    )
end

const SUPPORT_WALL_SECONDS=(time_ns()-SUPPORT_STARTED_NS)/1e9
const FIXTURE_INCLUDE_STARTED_NS=Ref{UInt64}(0)

if get(ENV, "FIRSTUSE_COLLECT_INFERENCE", "") == "1"
    Base.include(Main, joinpath(@__DIR__, "NativeInferenceEvidence.jl"))
end

module FirstUseExpertProbe
using JSON3
using SHA
const target = Main.TARGET
const records = Any[]
const seen = Ref(false)

function collect_numeric!(leaves, value, path::String, depth::Int = 0)
    depth > 5 && return
    if value isa Number
        payload = isbitstype(typeof(value)) ? bytes2hex(reinterpret(UInt8, [value])) : string(value)
        push!(
            leaves,
            (
                path = path,
                type = string(typeof(value)),
                finite = isfinite(value),
                payload = payload,
            ),
        )
    elseif value isa AbstractArray{<:Number} && isbitstype(eltype(value))
        array = Array(value)
        push!(
            leaves,
            (
                path = path,
                type = string(typeof(value)),
                shape = collect(size(value)),
                finite = all(isfinite, array),
                max_abs = all(isfinite, array) ? maximum(abs, array; init = 0.0) : nothing,
                max_abs_nonfinite_repr = all(isfinite, array) ? nothing :
                                         string(maximum(abs, array; init = 0.0)),
                sha256 = bytes2hex(sha256(reinterpret(UInt8, vec(array)))),
            ),
        )
    elseif value isa AbstractArray
        length(value) <= 256 || error("NONNUMERIC_ARRAY_TOO_LARGE_FOR_EXPERT_PROBE")
        for (index, item) in pairs(value)
            collect_numeric!(leaves, item, path * "[" * string(index) * "]", depth + 1)
        end
    elseif value isa NamedTuple
        for (key, item) in pairs(value)
            collect_numeric!(leaves, item, path * "." * string(key), depth + 1)
        end
    elseif value isa AbstractDict
        for key in sort!(collect(keys(value)); by = string)
            collect_numeric!(leaves, value[key], path * "." * string(key), depth + 1)
        end
    elseif value isa Tuple
        for (index, item) in enumerate(value)
            collect_numeric!(leaves, item, path * "[$(index)]", depth + 1)
        end
    elseif startswith(string(parentmodule(typeof(value))), "WannierNLQG") &&
           isstructtype(typeof(value))
        for key in fieldnames(typeof(value))
            collect_numeric!(leaves, getfield(value, key), path * "." * string(key), depth + 1)
        end
    end
end

function numeric_summary(value)
    leaves = Any[]
    collect_numeric!(leaves, value, "result")
    return (
        type = string(typeof(value)),
        numeric_leaf_count = length(leaves),
        all_finite = all(leaf.finite for leaf in leaves),
        numeric_sha256 = bytes2hex(sha256(JSON3.write(leaves))),
        leaves = leaves,
    )
end

# Native writer verification occurs strictly after the measured public call.
# Dependencies are resolved only after the writer has loaded its own backend.
const WRITER_TARGETS = Set((
    :write_band_representation_hdf5,
    :write_band_representation_summary,
    :write_projection_representation_search_hdf5,
    :write_response_symmetry_artifact,
    :write_wannierization_checkpoint_hdf5,
    :write_wannierization_fixed_subspace_hdf5,
    :write_wannierization_u_convergence_diagnostics_hdf5,
))
function native_writer_readback(name, value)
    name in WRITER_TARGETS || return nothing
    value isa AbstractString && isfile(value) || error("WRITER_DID_NOT_PRODUCE_NATIVE_FILE")
    artifact = joinpath(dirname(Main.RECEIPT), "native_output" * splitext(value)[2])
    ispath(artifact) && error("native readback artifact exists")
    cp(value, artifact; force = false)
    artifact_sha256=bytes2hex(sha256(read(artifact)))
    if endswith(lowercase(value), ".json")
        payload = JSON3.read(read(value, String), Dict{String, Any})
        leaves=Any[];
        collect_numeric!(leaves, payload, "native")
        return (
            format = "json",
            artifact = artifact,
            artifact_sha256 = artifact_sha256,
            numeric_leaves = leaves,
            top_level_keys = sort!(collect(keys(payload))),
            raw_file_bytes = filesize(value),
        )
    end
    hdf5_modules = filter(m -> nameof(m) == :HDF5, Base.loaded_modules_array())
    length(hdf5_modules) == 1 || error("WRITER_HDF5_BACKEND_NOT_LOADED")
    hdf5=only(hdf5_modules)
    values=Dict{String, Any}()
    function read_attributes(object, prefix)
        attrs=getproperty(hdf5, :attributes)(object)
        for key in sort!(collect(keys(attrs)))
            values[prefix * "/@" * key]=read(attrs[key])
        end
    end
    function visit(group, prefix)
        read_attributes(group, prefix)
        for key in sort!(collect(keys(group)))
            object=group[key];
            path=prefix*"/"*key
            try
                if object isa getproperty(hdf5, :Group)
                    visit(object, path)
                else
                    values[path]=read(object)
                    read_attributes(object, path)
                end
            finally
                close(object)
            end
        end
    end
    reader = handle -> visit(handle, "")
    Base.invokelatest(getproperty(hdf5, :h5open), reader, value, "r")
    leaves=Any[]
    for path in sort!(collect(keys(values)))
        collect_numeric!(leaves, values[path], "native"*path)
    end
    isempty(values) && error("EMPTY_NATIVE_WRITER_FILE")
    return (
        format = "hdf5",
        artifact = artifact,
        artifact_sha256 = artifact_sha256,
        dataset_paths = sort!(collect(keys(values))),
        numeric_leaves = leaves,
        semantic_fields = Dict(k=>v for (k, v) in values if v isa AbstractString || v isa Symbol),
        raw_file_bytes = filesize(value),
    )
end

@noinline function intercept(name, callable, args...; kwargs...)
    # Every intercepted invocation uses eval: a direct-call repeat branch
    # would let inference see the target before first-call counters begin.
    repeated_call = Expr(
        :call,
        QuoteNode(callable),
        Expr(:parameters, Expr(:..., QuoteNode(kwargs))),
        Expr(:..., QuoteNode(args)),
    )
    if name !== target || seen[]
        return Core.eval(Main, repeated_call)
    end
    seen[] = true
    setup_before_target_seconds=(time_ns()-Main.FIXTURE_INCLUDE_STARTED_NS[])/1e9
    trace_file = get(ENV, "FIRSTUSE_TRACE_PATH", "")
    begin_bytes = !isempty(trace_file) && isfile(trace_file) ? filesize(trace_file) : nothing
    argument_types = string.(typeof.(args))
    keyword_names = string.(keys(kwargs))
    actual_gc_on = GC.enable(true)
    actual_gc_on || error("FIRSTUSE_GC_WAS_DISABLED_AT_TARGET")
    extension_state_before = Dict(
        string(name)=>Base.get_extension(Main.WannierNLQG, name)!==nothing for name in (
            :WannierNLQGOperatorBundleExt,
            :WannierNLQGSymmetryFoundationExt,
            :WannierNLQGSymmetrizationExt,
            :WannierNLQGWannierizationExt,
            :WannierNLQGWannierizationPrecompileExt,
        )
    )
    public_call = Expr(
        :call,
        QuoteNode(callable),
        Expr(:parameters, Expr(:..., QuoteNode(kwargs))),
        Expr(:..., QuoteNode(args)),
    )
    diagnostic = get(ENV, "FIRSTUSE_COLLECT_INFERENCE", "") == "1"
    if diagnostic
        Base.Core.Compiler.Timings.reset_timings()
        Base.Core.Compiler.__set_measure_typeinf(true)
    end
    timed = try
        @timed try
            (true, Core.eval(Main, public_call))
        catch err
            (false, err)
        end
    finally
        if diagnostic
            Base.Core.Compiler.__set_measure_typeinf(false)
            Base.Core.Compiler.Timings.close_current_timer()
        end
    end
    end_bytes = !isempty(trace_file) && isfile(trace_file) ? filesize(trace_file) : nothing
    if diagnostic
        Main.NativeInferenceEvidence.persist(joinpath(dirname(Main.RECEIPT), "first_inference"))
    end
    success, result = timed.value
    summary = success ? numeric_summary(result) : (error = sprint(showerror, result),)
    native_readback = success ? native_writer_readback(name, result) : nothing
    push!(
        records,
        (
            target = string(name),
            measurement_scope = "timed_eval_public_expert_without_direct_callee_branch",
            argument_types = argument_types,
            keyword_names = keyword_names,
            extension_state_before = extension_state_before,
            gc_on_at_target = actual_gc_on,
            explicitly_loaded_supports = Main.REQUESTED_SUPPORTS,
            fixture_setup_before_target_seconds = setup_before_target_seconds,
            success = success,
            time = timed.time,
            compile_time = timed.compile_time,
            recompile_time = timed.recompile_time,
            gc_time = timed.gctime,
            allocated_bytes = timed.bytes,
            return_summary = summary,
            native_readback = native_readback,
            semantic_return = success && isempty(summary.leaves) && !(name in WRITER_TARGETS) ?
                              sprint(show, result) : nothing,
            trace_bytes_before = begin_bytes,
            trace_bytes_after = end_bytes,
        ),
    )
    success || throw(result)
    return result
end
end

function callee_name(expression)
    expression isa Symbol && return expression
    if expression isa Expr && expression.head == :. && length(expression.args) == 2
        last = expression.args[2]
        return last isa QuoteNode ? last.value : last
    end
    return nothing
end

function instrument(expression)
    expression isa Expr || return expression
    expression.head in (:quote, :inert) && return expression
    if expression.head == :function
        return Expr(:function, expression.args[1], map(instrument, expression.args[2:end])...)
    end
    if expression.head == :call && callee_name(expression.args[1]) == TARGET
        args = map(instrument, expression.args)
        if length(args) >= 2 && args[2] isa Expr && args[2].head == :parameters
            return Expr(
                :call,
                :(Main.FirstUseExpertProbe.intercept),
                args[2],
                QuoteNode(TARGET),
                args[1],
                args[3:end]...,
            )
        end
        return Expr(:call, :(Main.FirstUseExpertProbe.intercept), QuoteNode(TARGET), args...)
    end
    return Expr(expression.head, map(instrument, expression.args)...)
end

start = time_ns()
failure = Ref{Union{Nothing, String}}(nothing)
try
    FIXTURE_INCLUDE_STARTED_NS[]=time_ns()
    Base.include(instrument, Main, TEST_FILE)
catch err
    failure[] = sprint(showerror, err, catch_backtrace())
end
record = (
    target = string(TARGET),
    test_file = TEST_FILE,
    package_root = PACKAGE_ROOT,
    expected_package_root = EXPECTED_PACKAGE_ROOT,
    gc_on = true,
    import_wall_seconds = IMPORT_WALL_SECONDS,
    import_compile_seconds = IMPORT_TIMED.compile_time,
    support_initialization_wall_seconds = SUPPORT_WALL_SECONDS,
    wall_seconds = (time_ns() - start) / 1.0e9,
    fixture_passed = failure[] === nothing,
    fixture_error = failure[],
    first_calls = FirstUseExpertProbe.records,
)
open(RECEIPT, "w") do io
    JSON3.pretty(io, record)
    println(io)
end
println(
    "EXPERT_PROBE_RESULT target=$(TARGET) calls=$(length(FirstUseExpertProbe.records)) passed=$(failure[] === nothing)",
)
failure[] === nothing &&
length(FirstUseExpertProbe.records) == 1 &&
FirstUseExpertProbe.records[1].success || exit(1)
