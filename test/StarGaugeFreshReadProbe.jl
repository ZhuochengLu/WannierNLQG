using HDF5
using WannierNLQG

length(ARGS) == 1 || error("usage: StarGaugeFreshReadProbe.jl GAUGE_HDF5")
extension = first(WannierNLQG.Wannierization._load_wannierization_extension!()).PAWMatrixElements
restored = Base.invokelatest(extension._read_star_covariant_paw_gauge_hdf5, abspath(only(ARGS)))
println(
    "STAR_GAUGE_FRESH_READ_DIGEST=" *
    Base.invokelatest(extension._star_payload_sha256, restored.payload),
)
