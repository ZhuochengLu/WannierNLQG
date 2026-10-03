using JSON3
length(ARGS)==2 || error("usage cache_entry.jl cache_id collector_output")
const FIRSTUSE_CACHE_ROOT=dirname(Base.active_project())
const FIRSTUSE_CACHE_BASE=ENV["FIRSTUSE_CACHE_BASE_ID"]
const FIRSTUSE_CACHE_OUTPUT=abspath(ENV["FIRSTUSE_CACHE_OUTPUT_ROOT"])
ENV["FIRSTUSE_EXPECTED_PACKAGE_ROOT"]=FIRSTUSE_CACHE_ROOT
ENV["FIRSTUSE_PORTABLE_PAYLOAD_ROOT"]=joinpath(
    FIRSTUSE_CACHE_ROOT,
    "test",
    "fixtures",
    "first_use_portable",
)
ENV["FIRSTUSE_PORTABLE_ENTRY_ID"]=FIRSTUSE_CACHE_BASE
ENV["FIRSTUSE_FIXTURE_SUPPORTS"]=""
ENV["FIRSTUSE_FREEZE_READER_INPUT"]="0"
ENV["FIRSTUSE_TRACE_PATH"]=joinpath(ENV["WNLQG_TRACE_DIR"], "rank_0.jl")
empty!(ARGS)
append!(
    ARGS,
    [
        FIRSTUSE_CACHE_BASE,
        joinpath(@__DIR__, "expert_cache_scene.jl"),
        joinpath(FIRSTUSE_CACHE_OUTPUT, "receipt.json"),
    ],
)
Base.include(Main, joinpath(@__DIR__, "expert_probe.jl"))
