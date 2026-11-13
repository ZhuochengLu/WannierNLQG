# Environment/tool diagnostic only. Never imports WannierNLQG or computes responses.
using MPI, Libdl, TOML
length(ARGS)==1 || error("usage: OUTPUT_DIRECTORY")
const DESTINATION=abspath(only(ARGS))
mkpath(DESTINATION)
const LIBRARY=realpath(Libdl.dlpath(MPI.API.libmpi))
LIBRARY==realpath(ENV["WANNIERNLQG_EXPECTED_MPI_LIBRARY"]) || error("unexpected MPI library")
# Only this task's MPI location/namespace keys; never serialize the environment,
# credentials, PMIx security material or unrelated user settings.
const OBSERVED_KEYS=(
    "OPAL_PREFIX",
    "PMIX_INSTALL_PREFIX",
    "OMPI_COMM_WORLD_RANK",
    "OMPI_COMM_WORLD_SIZE",
    "PMIX_NAMESPACE",
    "PMIX_RANK",
)
function record(name, extra)
    value=merge(
        Dict{String, Any}(
            "scope"=>"MPI_STARTUP_TOOL_ONLY_NO_WANNIERNLQG_SCIENCE",
            "mpi_library_path"=>LIBRARY,
            "mpi_library_version"=>MPI.Get_library_version(),
            "MPI_initialized"=>MPI.Initialized(),
            "MPI_finalized"=>MPI.Finalized(),
            "MPI_location_and_namespace"=>Dict(k=>ENV[k] for k in OBSERVED_KEYS if haskey(ENV, k)),
        ),
        extra,
    )
    temporary=joinpath(DESTINATION, name*".tmp")
    open(io->TOML.print(io, value), temporary, "w")
    mv(temporary, joinpath(DESTINATION, name*".toml"))
end
record("before_init", Dict{String, Any}())
println(stderr, "NATIVE_MPI_STARTUP_BEFORE_INIT path=$LIBRARY")
MPI.Initialized() && error("unexpected prior initialization")
MPI.Init()
const RANK=MPI.Comm_rank(MPI.COMM_WORLD)
const RANKS=MPI.Comm_size(MPI.COMM_WORLD)
RANK==0 && RANKS==1 || error("diagnostic is exactly MPI1")
const REDUCTION=MPI.Allreduce(Int32(7), +, MPI.COMM_WORLD)
REDUCTION==7 || error("unexpected one-rank reduction")
MPI.Barrier(MPI.COMM_WORLD)
record("after_collective", Dict("rank"=>RANK, "ranks"=>RANKS, "reduction"=>Int(REDUCTION)))
MPI.Finalize()
record("after_finalize", Dict("rank"=>RANK, "ranks"=>RANKS, "reduction"=>Int(REDUCTION)))
println("NATIVE_MPI_STARTUP_TOOL_COMPLETE ranks=1")
