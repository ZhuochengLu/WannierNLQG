using SHA
using WannierNLQG

length(ARGS) == 1 || error("usage: AugmentationAwareSewingFreshReadProbe.jl REPRESENTATION")
representation = WannierNLQG.SymmetryFoundation.read_band_representation_hdf5(abspath(only(ARGS)))
representation.schema_version == "1.0" || error("fresh read lost public schema 1.0")
representation.conventions["sewing_backend"] == "augmentation_aware_paw_q0" ||
    error("fresh read lost strict sewing provenance")
get(representation.conventions, "wavefunction_gauge_backend", "native_eigenstate") ==
"native_eigenstate" || error("fresh read lost native wavefunction-gauge provenance")
buffer = IOBuffer()
write(buffer, reinterpret(UInt8, vec(representation.sewing_matrices)))
for key in sort!(collect(keys(representation.conventions)))
    write(buffer, key, '\0', representation.conventions[key], '\n')
end
println("AUGMENTATION_AWARE_FRESH_READ_DIGEST=" * bytes2hex(SHA.sha256(take!(buffer))))
