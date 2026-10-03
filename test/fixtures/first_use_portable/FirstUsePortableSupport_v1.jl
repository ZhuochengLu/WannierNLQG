module FirstUsePortableSupport
using JSON3, SHA, Serialization
include(joinpath(@__DIR__, "PortableFixturePayload_v1.jl"))
using .PortableFixturePayload
using .PortableFixturePayload: safe_relative

const CONTEXT = Ref{Any}(nothing)

"""Validate the entire fixture payload before any public target is measured."""
function configure!(root::AbstractString, output::AbstractString)
    CONTEXT[] === nothing || error("FIXTURE_CONTEXT_ALREADY_CONFIGURED")
    payload = abspath(root)
    destination = abspath(output)
    ispath(destination) && error("FIXTURE_OUTPUT_MUST_BE_FRESH")
    manifest = verify_payload(payload)
    arguments =
        Dict(safe_relative(payload, String(x.file)) => String(x.id) for x in manifest.arguments)
    # This alias is a declared byte-identical copy of argument fixture_27.
    band_alias = safe_relative(payload, "public_band/prepared_representation.jls")
    band_record = only(filter(x -> String(x.id) == "fixture_27", manifest.arguments))
    bytes2hex(open(sha256, band_alias)) == band_record.sha256 ||
        error("FIXTURE_BAND_ALIAS_SHA_MISMATCH")
    arguments[band_alias] = "fixture_27"
    CONTEXT[] = (root = payload, output = destination, manifest = manifest, arguments = arguments)
    return nothing
end

function context()
    CONTEXT[] === nothing && error("FIXTURE_CONTEXT_MISSING")
    CONTEXT[]
end

function input(relative::AbstractString)
    target = safe_relative(context().root, relative)
    ispath(target) || error("FIXTURE_INPUT_MISSING")
    return target
end

function deserialize_input(path::AbstractString)
    c = context()
    actual = abspath(path)
    haskey(c.arguments, actual) || error("FIXTURE_ARGUMENT_NOT_DECLARED")
    return load_arguments(c.root, c.arguments[actual], c.output)
end

"""Resolve only declared transport paths and preserved scalar bindings."""
function environment(entry_id::AbstractString)
    row = only(filter(x -> String(x.id) == entry_id, context().manifest.expert_entries))
    result = Dict{String, String}()
    for (key, value) in pairs(row.environment)
        result[String(key)] = value isa AbstractString ? String(value) : input(String(value.input))
    end
    return result
end
end
