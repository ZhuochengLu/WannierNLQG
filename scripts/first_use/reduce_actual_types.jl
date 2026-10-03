# Lossless projection of original MethodInstance Types; never infer a Type from
# similar text. All original Types and frames remain external and unchanged.
include(joinpath(@__DIR__, "audit_signatures.jl"))
for symbol in names(Base.Core; all = true, imported = false)
    isdefined(Base.Core, symbol) && !isdefined(Main, symbol) || continue
    value = getfield(Base.Core, symbol)
    try
        Core.eval(Main, Expr(:(=), symbol, QuoteNode(value)))
    catch
        continue
    end
    @test getfield(Main, symbol) === value
end
length(ARGS)==4 || error(
    "usage: reduce_actual_types.jl capture.jls inference.json required_keys.json fresh_output_dir",
)
capture, inference, requested, output = abspath.(ARGS)
ispath(output) && error("reduction output must be fresh")
values=Serialization.deserialize(capture)
frames=JSON3.read(read(inference, String))
length(values)==length(frames) || error("ACTUAL_TYPE_FRAME_COUNT_MISMATCH")
keys_payload=JSON3.read(read(requested, String))
required=Set(
    String.(keys_payload isa AbstractVector ? keys_payload : keys_payload.required_printed_keys),
)
isempty(required) && error("ACTUAL_TYPE_SCOPE_EMPTY")
result=Dict{String, Any}()
for (ordinal, value) in enumerate(values)
    printed=String(frames[ordinal].signature)
    if value isa Pair
        first(value)==printed || error("ACTUAL_TYPE_FRAME_ORDER_MISMATCH")
        value=last(value)
    end
    printed in required || continue
    value isa Type || error("ACTUAL_INFERENCE_NOT_TYPE")
    sprint(show, value; context = :module=>Base.Core)==printed ||
        error("ACTUAL_TYPE_PRINT_IDENTITY_MISMATCH")
    haskey(result, printed) &&
        result[printed]!==value &&
        error("ACTUAL_TYPE_DUPLICATE_IDENTITY_CHANGED")
    result[printed]=value
end
Set(keys(result))==required || error("ACTUAL_TYPE_REQUIRED_SCOPE_MISSING")
mkpath(output)
selected=Pair{String, Any}[key=>result[key] for key in sort!(collect(required))]
file=joinpath(output, "actual_types.jls")
Serialization.serialize(file, selected)
restored=Serialization.deserialize(file)
@test length(restored)==length(selected)
@test all(a==first(b) && result[a]===last(b) for (a, b) in zip(sort!(collect(required)), restored))
sha(path)=bytes2hex(open(sha256, path))
write(
    joinpath(output, "identity.json"),
    JSON3.write((
        original_capture_sha256 = sha(capture),
        original_inference_sha256 = sha(inference),
        required_scope_sha256 = sha(requested),
        reduced_sha256 = sha(file),
        actual_types = length(selected),
        source_julia = string(VERSION),
        lossless_exact_identity = true,
        reduction_runner_sha256 = sha(@__FILE__),
        source_src_ext_sha256 = source_digest(ROOT),
        manifest_sha256 = sha(joinpath(ROOT, "Manifest.toml")),
        source_attribution_not_speed = true,
    )),
)
println("ACTUAL_TYPES_LOSSLESS_PROJECTION_PASS ", length(selected))
