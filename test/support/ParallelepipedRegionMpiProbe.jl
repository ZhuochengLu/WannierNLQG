using MPI, JSON3, Test, Libdl
const MPI_LIBRARY_PATH = realpath(Libdl.dlpath(MPI.API.libmpi))
if haskey(ENV, "WANNIERNLQG_EXPECTED_MPI_LIBRARY")
    @test MPI_LIBRARY_PATH == realpath(ENV["WANNIERNLQG_EXPECTED_MPI_LIBRARY"])
end
println(stderr, "PARALLELEPIPED_MPI_LIBRARY path=$MPI_LIBRARY_PATH")
# This probe exercises the supported caller-managed MPI lifecycle. Initialize
# native MPI before loading optional package dependencies which can change its
# process environment. Automatic initialization after import is a separate gate.
const USE_MPI = get(ENV, "WANNIERNLQG_USE_MPI", "0") == "1"
USE_MPI && !MPI.Initialized() && MPI.Init()
using WannierNLQG
include(joinpath(@__DIR__, "ParallelepipedRegionFixture.jl"))
const Fixture = ParallelepipedRegionFixture
const RANK = USE_MPI ? MPI.Comm_rank(MPI.COMM_WORLD) : 0
const RANKS = USE_MPI ? MPI.Comm_size(MPI.COMM_WORLD) : 1
const DESTINATION = abspath(only(ARGS))
# No launcher or rank limit is hidden in this probe. The existing Full wrapper
# retains ranks1/2; the separately allocated targeted comparison may add ranks3.
include(joinpath(@__DIR__, "FullMPIRankProfile.jl"))
const ORIGINAL_CASES = ((2, 3, 2), (5, 4, 4))
const CASES = FullMPIRankProfile.is_air_profile() ? ((1, 1, 1), ORIGINAL_CASES...) : ORIGINAL_CASES
payload = Dict{String, Any}()
observed = Dict{String, Any}()
owned = Dict{String, Any}()
preflight = Dict{String, Any}()
unknown = Dict{String, Any}()
for counts in CASES
    empty!(Fixture.Shared.OBSERVED_CARTESIAN_POINTS)
    empty!(Fixture.Shared.OWNED_CARTESIAN_POINTS)
    empty!(Fixture.Shared.PREFLIGHT_CARTESIAN_POINTS)
    empty!(Fixture.Shared.UNKNOWN_CARTESIAN_POINTS)
    Fixture.Shared.RECORD_POINTS[] = true
    sampling = KRegion(;
        origin = (4.0, 0.2, 0.1),
        vector_1 = (0.4, 0.08, 0.02),
        vector_2 = (0.12, 0.36, -0.01),
        vector_3 = (0.03, 0.02, 0.2),
        k_mesh = counts,
    )
    result =
        WannierNLQG.run(Fixture.config(sampling, joinpath(DESTINATION, "mesh$(join(counts, '-'))")))
    if RANK == 0
        tables = Fixture.tensors(result)
        @test length(tables) == 4
        @test all(maximum(abs, table) > 0 for table in values(tables))
        payload[string(counts)] = Fixture.tensor_records(tables)
    end
    observed[string(counts)] = unique(Fixture.Shared.OBSERVED_CARTESIAN_POINTS)
    owned[string(counts)] = unique(Fixture.Shared.OWNED_CARTESIAN_POINTS)
    preflight[string(counts)] = unique(Fixture.Shared.PREFLIGHT_CARTESIAN_POINTS)
    unknown[string(counts)] = unique(Fixture.Shared.UNKNOWN_CARTESIAN_POINTS)
end
Fixture.Shared.RECORD_POINTS[] = false
write(
    joinpath(DESTINATION, "rank-$RANK.json"),
    JSON3.write((;
        rank = RANK,
        ranks = RANKS,
        observed_cartesian_points = observed,
        owned_cartesian_points = owned,
        preflight_cartesian_points = preflight,
        unknown_cartesian_points = unknown,
        source_root = realpath(dirname(dirname(pathof(WannierNLQG)))),
        lifecycle = USE_MPI ? "caller managed before package import" :
                    "serial; MPI not initialized",
        mpi_library_path = MPI_LIBRARY_PATH,
        mpi_library_version = MPI.Get_library_version(),
    )),
)
if RANK == 0
    write(joinpath(DESTINATION, "numerical.json"), JSON3.write(payload))
    println("PARALLELEPIPED_REGION_MPI_PROBE_PASS ranks=$RANKS")
end
USE_MPI && !MPI.Finalized() && MPI.Finalize()
