# The selected input is immutable. Backend activation belongs to its timed call.
using JSON3
length(ARGS) == 2 || error("usage: expert_entry.jl entry_id output_dir")
const FIRSTUSE_ENTRY_ID = String(ARGS[1])
const FIRSTUSE_ENTRY_OUTPUT = abspath(ARGS[2])
const FIRSTUSE_SOURCE_ROOT = dirname(Base.active_project())
startswith(relpath(FIRSTUSE_ENTRY_OUTPUT, FIRSTUSE_SOURCE_ROOT), "..") ||
    error("expert output must be outside package")
const FIRSTUSE_ENTRY_REGISTRY = JSON3.read(read(joinpath(@__DIR__, "expert_paths.json"), String))
const FIRSTUSE_ENTRY = only(filter(x -> String(x.id)==FIRSTUSE_ENTRY_ID, FIRSTUSE_ENTRY_REGISTRY))
const FIRSTUSE_PAYLOAD_ROOT = abspath(
    get(
        ENV,
        "FIRSTUSE_PORTABLE_PAYLOAD_ROOT",
        joinpath(FIRSTUSE_SOURCE_ROOT, "test", "fixtures", "first_use_portable"),
    ),
)
ENV["FIRSTUSE_EXPECTED_PACKAGE_ROOT"] = FIRSTUSE_SOURCE_ROOT
ENV["FIRSTUSE_PORTABLE_PAYLOAD_ROOT"] = FIRSTUSE_PAYLOAD_ROOT
ENV["FIRSTUSE_PORTABLE_ENTRY_ID"] = FIRSTUSE_ENTRY_ID
ENV["FIRSTUSE_FIXTURE_SUPPORTS"] = join(String.(FIRSTUSE_ENTRY.supports), ",")
ENV["FIRSTUSE_FIXTURE_SUPPORT_ROOT"] = joinpath(FIRSTUSE_PAYLOAD_ROOT, "supports")
ENV["FIRSTUSE_FREEZE_READER_INPUT"] = "0"
const FIRSTUSE_TRACE_DIRECTORY = get(ENV, "WNLQG_TRACE_DIR", "")
if !isempty(FIRSTUSE_TRACE_DIRECTORY)
    ENV["FIRSTUSE_TRACE_PATH"] =
        joinpath(FIRSTUSE_TRACE_DIRECTORY, "rank_"*get(ENV, "OMPI_COMM_WORLD_RANK", "0")*".jl")
end
if FIRSTUSE_ENTRY.kind == "custom"
    FIRSTUSE_ENTRY.mpi_size == 1 || error("custom MPI fixture unavailable")
    empty!(ARGS)
    append!(
        ARGS,
        [
            FIRSTUSE_PAYLOAD_ROOT,
            FIRSTUSE_ENTRY_ID,
            FIRSTUSE_ENTRY_OUTPUT,
            FIRSTUSE_SOURCE_ROOT,
            hasproperty(FIRSTUSE_ENTRY, :input) ? String(FIRSTUSE_ENTRY.input) : "",
        ],
    )
    Base.include(Main, joinpath(@__DIR__, "expert_custom_probe.jl"))
else
    local_rank = 0
    if FIRSTUSE_ENTRY.mpi_size > 1
        Core.eval(Main, :(using MPI))
        mpi_initialization = @timed MPI.Init()
        local_rank = MPI.Comm_rank(MPI.COMM_WORLD)
        MPI.Comm_size(MPI.COMM_WORLD) == FIRSTUSE_ENTRY.mpi_size ||
            error("expert actual MPI size mismatch")
        ENV["LOCALIZATION_EXECUTION"] = "mpi"
        ENV["LOCALIZATION_RANK"] = string(local_rank)
        ENV["LOCALIZATION_COMMON_OUTPUT"] = joinpath(FIRSTUSE_ENTRY_OUTPUT, "fixture_output")
    end
    rank_output =
        FIRSTUSE_ENTRY.mpi_size > 1 ? joinpath(FIRSTUSE_ENTRY_OUTPUT, "rank_"*string(local_rank)) :
        FIRSTUSE_ENTRY_OUTPUT
    mkpath(rank_output)
    if FIRSTUSE_ENTRY.mpi_size > 1
        write(
            joinpath(rank_output, "initialization.json"),
            JSON3.write((
                rank = local_rank,
                size = FIRSTUSE_ENTRY.mpi_size,
                threads = Threads.nthreads(),
                mpi_library = MPI.Get_library_version(),
                initialization_time = mpi_initialization.time,
                initialization_compile = mpi_initialization.compile_time,
            )),
        )
    end
    trace_directory = get(ENV, "WNLQG_TRACE_DIR", "")
    isempty(trace_directory) ||
        (ENV["FIRSTUSE_TRACE_PATH"] = joinpath(trace_directory, "rank_"*string(local_rank)*".jl"))
    empty!(ARGS)
    append!(
        ARGS,
        [
            String(FIRSTUSE_ENTRY.public_target),
            joinpath(FIRSTUSE_PAYLOAD_ROOT, String(FIRSTUSE_ENTRY.fixture)),
            joinpath(rank_output, "receipt.json"),
        ],
    )
    Base.include(Main, joinpath(@__DIR__, "expert_probe.jl"))
    FIRSTUSE_ENTRY.mpi_size > 1 && MPI.Finalize()
end
