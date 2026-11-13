# Run only in the compiler writer; never initialize MPI or inject native handles.
using WannierNLQG, MPI, HDF5, TOML, SHA
@assert ccall(:jl_generating_output, Cint, ()) == 1
@assert realpath(Base.pkgdir(WannierNLQG)) == realpath(ENV["WN_IMAGE_SOURCE"])
@assert bytes2hex(sha256(read(joinpath(Base.pkgdir(WannierNLQG), "SOURCE_MANIFEST.tsv")))) ==
        ENV["WN_IMAGE_SOURCE_MANIFEST"]
@assert MPI.API.libmpi_handle == C_NULL
open(
    io -> TOML.print(
        io,
        Dict(
            "generating_output"=>true,
            "mpi_handle_null"=>true,
            "source_manifest_sha256"=>ENV["WN_IMAGE_SOURCE_MANIFEST"],
        ),
    ),
    joinpath(ENV["WN_IMAGE_ARTIFACT_DIRECTORY"], "writer.toml"),
    "w",
)
