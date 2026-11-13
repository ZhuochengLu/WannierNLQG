using MPI, Libdl, JSON3, Test
const MPI_LIBRARY_PATH=realpath(Libdl.dlpath(MPI.API.libmpi))
@test MPI_LIBRARY_PATH==realpath(ENV["WANNIERNLQG_EXPECTED_MPI_LIBRARY"])
using WannierNLQG
length(ARGS)==4 || error("usage: SOURCE_ROOT FIXTURE_ROOT serial|box OUTPUT")
const SOURCE_ROOT, FIXTURE_ROOT, MODE, DESTINATION=ARGS
@test realpath(dirname(dirname(pathof(WannierNLQG))))==realpath(SOURCE_ROOT)
@test MODE in ("serial", "box")
write(
    joinpath(DESTINATION, "MPI_binding.json"),
    JSON3.write((;
        mpi_library_path = MPI_LIBRARY_PATH,
        mpi_library_version = MPI.Get_library_version(),
    )),
)
if MODE=="serial"
    ENV["WANNIERNLQG_KREGION_EVIDENCE_DIR"]=DESTINATION
    include(joinpath(SOURCE_ROOT, "test", "parallelogram_region_unit.jl"))
    include(joinpath(SOURCE_ROOT, "test", "parallelepiped_region_unit.jl"))
    @test all(
        isfile(joinpath(DESTINATION, n*".json")) for n in (
            "geometry",
            "polynomial",
            "toml",
            "responses",
            "volume_geometry",
            "volume_polynomial",
            "volume_toml",
            "volume_responses",
        )
    )
else
    # Original070 executes only its old box API. Exact same pinned callbacks.
    include(joinpath(FIXTURE_ROOT, "test", "support", "ParallelogramRegionFixture.jl"))
    include(joinpath(FIXTURE_ROOT, "test", "support", "ParallelepipedRegionFixture.jl"))
    for (fixture, label, lower, upper, mesh) in (
        (ParallelogramRegionFixture, "box", (4.0, 0.2), (4.4, 0.56), (4, 4)),
        (ParallelepipedRegionFixture, "volume_box", (4.0, 0.2, 0.1), (4.4, 0.56, 0.3), (2, 2, 2)),
    )
        result=WannierNLQG.run(
            fixture.config(KRegion(; lower, upper, k_mesh = mesh), joinpath(DESTINATION, label)),
        )
        tables=fixture.tensors(result)
        @test length(tables)==4 && all(maximum(abs, t)>0 for t in values(tables))
        fixture.retain_result(label, result)
        write(
            joinpath(DESTINATION, label*".json"),
            JSON3.write((;
                source_root = realpath(SOURCE_ROOT),
                tables = fixture.tensor_records(tables),
            )),
        )
    end
end
println("AFFINE_REGION_QUALIFICATION_PROBE_COMPLETE mode=$MODE")
