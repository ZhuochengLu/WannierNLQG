# The fresh response probe owns an independent singleton MPI lifecycle.
# No scientific implementation is replaced; failures propagate through finally.
using MPI
@assert !MPI.Initialized() && !MPI.Finalized()
@assert !any(
    key -> startswith(key, "OMPI_") || startswith(key, "PMIX_") || startswith(key, "PMI_"),
    keys(ENV),
)
probe = popfirst!(ARGS)
@assert dirname(realpath(probe)) == realpath(@__DIR__)
MPI.Init()
try
    @assert MPI.Comm_size(MPI.COMM_WORLD) == 1
    @assert MPI.Comm_rank(MPI.COMM_WORLD) == 0
    println("FRESH_RESPONSE_MPI_SINGLETON_INITIALIZED")
    include(probe)
finally
    MPI.Initialized() && !MPI.Finalized() && MPI.Finalize()
    @assert MPI.Finalized()
    println("FRESH_RESPONSE_MPI_FINALIZED")
end
