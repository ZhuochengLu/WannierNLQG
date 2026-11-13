using MPI, Libdl, JSON3, Test
const MPI_LIBRARY_PATH = realpath(Libdl.dlpath(MPI.API.libmpi))
if haskey(ENV, "WANNIERNLQG_EXPECTED_MPI_LIBRARY")
    @test MPI_LIBRARY_PATH == realpath(ENV["WANNIERNLQG_EXPECTED_MPI_LIBRARY"])
end
println(stderr, "KREGION_MPI_LIBRARY path=$MPI_LIBRARY_PATH")
using WannierNLQG
length(ARGS) == 4 || error("usage: KRegionQualificationProbe SOURCE_ROOT FIXTURE serial|box OUTPUT")
const SOURCE_ROOT, FIXTURE_PATH, MODE, DESTINATION = ARGS
write(
    joinpath(DESTINATION, "MPI_binding.json"),
    JSON3.write((;
        mpi_library_path = MPI_LIBRARY_PATH,
        mpi_library_version = MPI.Get_library_version(),
    )),
)
@test realpath(dirname(dirname(pathof(WannierNLQG)))) == realpath(SOURCE_ROOT)
@test MODE in ("serial", "box")
if MODE == "serial"
    ENV["WANNIERNLQG_KREGION_EVIDENCE_DIR"] = DESTINATION
    include(joinpath(SOURCE_ROOT, "test", "parallelogram_region_unit.jl"))
    @test all(
        isfile(joinpath(DESTINATION, name*".json")) for
        name in ("geometry", "polynomial", "toml", "responses")
    )
else
    # The same frozen polynomial callback is loaded into the original070 package.
    # Only its original Cartesian box API is called; the callback file is pinned.
    include(FIXTURE_PATH)
    sampling = KRegion(; lower = (4.0, 0.2), upper = (4.4, 0.56), k_mesh = (4, 4))
    result = WannierNLQG.run(
        ParallelogramRegionFixture.config(sampling, joinpath(DESTINATION, "rectangle")),
    )
    tables = ParallelogramRegionFixture.tensors(result)
    @test length(tables) == 4
    @test all(maximum(abs, table) > 0 for table in values(tables))
    write(
        joinpath(DESTINATION, "box.json"),
        JSON3.write((;
            source_root = realpath(SOURCE_ROOT),
            tables = ParallelogramRegionFixture.tensor_records(tables),
        )),
    )
end
println("KREGION_QUALIFICATION_PROBE_COMPLETE mode=$MODE")
