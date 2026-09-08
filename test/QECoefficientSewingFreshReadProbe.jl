using SHA
using WannierNLQG

length(ARGS) == 1 || error("usage: QECoefficientSewingFreshReadProbe.jl REPRESENTATION_HDF5")
representation = WannierNLQG.SymmetryFoundation.read_band_representation_hdf5(abspath(only(ARGS)))
representation.conventions["qe_metric_kind"] == "paw" ||
    error("fresh read lost QE PAW metric provenance")
representation.conventions["physical_overlap_available"] == "false" ||
    error("fresh read changed the QE physical-overlap capability")

buffer = IOBuffer()
write(buffer, reinterpret(UInt8, vec(representation.sewing_matrices)))
for key in sort!(collect(keys(representation.conventions)))
    write(buffer, key, '\0', representation.conventions[key], '\n')
end
println("QE_PAW_FRESH_READ_DIGEST=" * bytes2hex(SHA.sha256(take!(buffer))))
