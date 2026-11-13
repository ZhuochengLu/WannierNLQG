module WannierNLQGWannierizationPrecompileExt

# Five-trigger workload definitions. Cross-sibling execution is explicit in the
# external image capture after activation; package precompilation defines only methods.
using WannierNLQG, MPI, HDF5, JSON3, EzXML, Spglib, LinearAlgebra
include("RepresentativeWannierWorkflowWorkload.jl")
include("RepresentativeSymmetrizationWorkloads.jl")
include("RepresentativePAWAuditWorkload.jl")

end
