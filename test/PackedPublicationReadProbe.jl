using WannierNLQG, HDF5, Serialization
import MPI
source, bundle, result=ARGS
@assert realpath(Base.pkgdir(WannierNLQG))==realpath(source)
@assert Threads.nthreads()==1 && !MPI.Initialized()
loaded=WannierNLQG.IO.read_real_space_operator_bundle(bundle)
record=(;
    source_root = realpath(source),
    threads = Threads.nthreads(),
    mpi_initialized = MPI.Initialized(),
    publication_identity = loaded.manifest.publication_identity,
    lattice = loaded.lattice,
    degeneracies = loaded.degeneracies,
    operators = Dict(
        UInt8(kind)=>(; r_vectors = operator.r_vectors, data = operator.data) for
        (kind, operator) in loaded.operators
    ),
)
open(result, "w") do stream
    serialize(stream, record)
end
println("PACKED_FRESH_CURRENT_READ_COMPLETE threads=1 mpi=false")
