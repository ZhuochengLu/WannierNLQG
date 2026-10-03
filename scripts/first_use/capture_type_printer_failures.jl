# Prepare original printer-failure evidence from captured MethodInstance Types.
# Explicit arguments make the tool independent of checkout and evidence location.
using Test
candidate, capture, inference, scope, observation, output = ARGS
include(joinpath(candidate, "scripts", "first_use", "audit_signatures.jl"))
ispath(output) && error("printer-failure output must be fresh")
@test !MPI.Initialized()
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
original = Serialization.deserialize(capture)
frames = JSON3.read(read(inference, String))
@test length(original) == length(frames)
required = Set(String.(JSON3.read(read(scope, String))))
selected = Dict{String, Any}()
failures = Any[]
all_failures = Any[]
for (ordinal, value) in enumerate(original)
    printed = String(frames[ordinal].signature)
    if value isa Pair
        @test first(value) == printed
        value = last(value)
    end
    occursin("topology.num_kpts::", printed) || continue
    err = try
        evaluated_type(Main, printed)
        nothing
    catch error
        sprint(showerror, error)
    end
    err === nothing && continue
    startswith(err, "TypeError: in Type, in parameter") || error("UNEXPECTED_PRINT_FAILURE: " * err)
    item = (
        signature = printed,
        error = err,
        observations = [observation],
        actual_frame_ordinal = ordinal,
    )
    push!(all_failures, item)
    printed in required || continue
    @test value isa Type && sprint(show, value; context = :module => Base.Core) == printed
    haskey(selected, printed) && @test selected[printed] === value
    if !haskey(selected, printed)
        selected[printed] = value
        push!(failures, item)
    end
end
@test Set(keys(selected)) == required
@test !MPI.Initialized()
mkdir(output)
write(joinpath(output, "all_original_print_failures.json"), JSON3.write(all_failures))
write(joinpath(output, "original_parse_failures.json"), JSON3.write(failures))
write(joinpath(output, "required_printed_keys.json"), JSON3.write(sort!(collect(required))))
write(
    joinpath(output, "identity.json"),
    JSON3.write((
        source_src_ext_sha256 = source_digest(ROOT),
        original_capture_sha256 = digest(read(capture)),
        original_inference_sha256 = digest(read(inference)),
        scope_sha256 = digest(read(scope)),
        runner_sha256 = digest(read(@__FILE__)),
        actual_failed_types = length(selected),
        actual_frame_ordinals_preserved = true,
        checkpoint = false,
    )),
)
println("ORIGINAL_ACTUAL_PRINTER_FAILURE_SCOPE_PASS ", length(selected))
