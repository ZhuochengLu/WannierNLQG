GC.enable(true) || error("FIRSTUSE_GC_WAS_DISABLED")
using JSON3, SHA
payload, entryid, output, expected, input_relative = ARGS
payload=abspath(payload);
output=abspath(output)
Base.include(Main, joinpath(payload, "FirstUsePortableSupport_v1.jl"))
FirstUsePortableSupport.configure!(payload, joinpath(output, "argument_outputs"))
for (key, value) in FirstUsePortableSupport.environment(entryid)
    ENV[key]=value
end
scene=only(
    filter(x->String(x.id)==entryid, FirstUsePortableSupport.context().manifest.expert_entries),
)
fixture=FirstUsePortableSupport.input(String(scene.fixture))
cd(payload)
empty!(ARGS)
if entryid=="write_band_representation_summary"
    append!(ARGS, [expected, output])
else
    append!(
        ARGS,
        [FirstUsePortableSupport.input(input_relative), joinpath(output, "receipt.json"), expected],
    )
end
const FIRSTUSE_CUSTOM_GC_CHECKS = Ref(0)
const FIRSTUSE_CUSTOM_TIMER_BACKENDS = Any[]
function firstuse_custom_timer_guard()
    GC.enable(true) || error("FIRSTUSE_GC_WAS_DISABLED_AT_CUSTOM_TIMER")
    FIRSTUSE_CUSTOM_GC_CHECKS[] += 1
    names = (
        :WannierNLQGWannierizationPrecompileExt,
        :WannierNLQGWannierizationExt,
        :WannierNLQGOperatorBundleExt,
        :WannierNLQGSymmetryFoundationExt,
        :WannierNLQGSymmetrizationExt,
    )
    root = isdefined(Main, :WannierNLQG) ? getproperty(Main, :WannierNLQG) : nothing
    push!(
        FIRSTUSE_CUSTOM_TIMER_BACKENDS,
        root === nothing ? nothing :
        Dict(String(name) => Base.get_extension(root, name) !== nothing for name in names),
    )
    return nothing
end
const FIRSTUSE_CUSTOM_INTERVALS = Dict{String, Any}()
const FIRSTUSE_CUSTOM_DIAGNOSTIC = get(ENV, "FIRSTUSE_COLLECT_INFERENCE", "") == "1"
if FIRSTUSE_CUSTOM_DIAGNOSTIC
    Base.include(Main, joinpath(@__DIR__, "NativeInferenceEvidence.jl"))
end
function firstuse_custom_diagnostic_macro(expression, label)
    trace = get(ENV, "FIRSTUSE_TRACE_PATH", "")
    isempty(trace) && error("CUSTOM_DIAGNOSTIC_TRACE_REQUIRED")
    directory = joinpath(output, label*"_inference")
    return quote
        let
            firstuse_custom_timer_guard()
            before = filesize($trace)
            Base.Core.Compiler.Timings.reset_timings()
            Base.Core.Compiler.__set_measure_typeinf(true)
            timed_value = try
                $expression
            finally
                Base.Core.Compiler.__set_measure_typeinf(false)
                Base.Core.Compiler.Timings.close_current_timer()
            end
            after = filesize($trace)
            NativeInferenceEvidence.persist($directory)
            FIRSTUSE_CUSTOM_INTERVALS[$label] =
                (before = before, after = after, directory = $directory)
            timed_value
        end
    end
end
function firstuse_custom_gc_instrument(expression)
    expression isa Expr || return expression
    expression.head in (:quote, :inert) && return expression
    if FIRSTUSE_CUSTOM_DIAGNOSTIC &&
       entryid != "authoritative_band_hamiltonian" &&
       expression.head == :(=) &&
       expression.args[1] in (:first_timed, :validation_stats, :writer_stats) &&
       expression.args[2] isa Expr &&
       expression.args[2].head == :macrocall &&
       expression.args[2].args[1] == Symbol("@timed")
        label =
            expression.args[1] == :first_timed ? "first" :
            expression.args[1] == :validation_stats ? "validation" : "writer"
        return Expr(
            :(=),
            expression.args[1],
            firstuse_custom_diagnostic_macro(expression.args[2], label),
        )
    end
    if expression.head == :macrocall && expression.args[1] == Symbol("@timed")
        return Expr(:block, :(firstuse_custom_timer_guard()), expression)
    end
    return Expr(expression.head, map(firstuse_custom_gc_instrument, expression.args)...)
end
Base.include(firstuse_custom_gc_instrument, Main, fixture)
custom_receipt = joinpath(output, "receipt.json")
custom_record = JSON3.read(read(custom_receipt, String), Dict{String, Any})
custom_record["gc_on"] = true
custom_record["gc_checked_at_every_timer"] = true
custom_record["gc_check_count"] = FIRSTUSE_CUSTOM_GC_CHECKS[]
custom_record["backend_state_at_every_timer"] = FIRSTUSE_CUSTOM_TIMER_BACKENDS
write(custom_receipt, JSON3.write(custom_record))

if FIRSTUSE_CUSTOM_DIAGNOSTIC
    custom_record["diagnostic_not_speed_sample"] = true
    custom_record["public_intervals"] = FIRSTUSE_CUSTOM_INTERVALS
    if entryid == "authoritative_band_hamiltonian"
        Main.Serialization.serialize(
            joinpath(output, "actual_all_inference_types.jls"),
            Main.actual_type_values,
        )
    end
    write(custom_receipt, JSON3.write(custom_record))
end
