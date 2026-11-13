using MPI, JSON3, Test, Libdl
const MPI_LIBRARY_PATH = realpath(Libdl.dlpath(MPI.API.libmpi))
if haskey(ENV, "WANNIERNLQG_EXPECTED_MPI_LIBRARY")
    @test MPI_LIBRARY_PATH == realpath(ENV["WANNIERNLQG_EXPECTED_MPI_LIBRARY"])
end
println(stderr, "PARALLELOGRAM_MPI_LIBRARY path=$MPI_LIBRARY_PATH")
# This probe exercises the supported caller-managed MPI lifecycle. Initialize
# native MPI before loading optional package dependencies which can change its
# process environment. Automatic initialization after import is a separate gate.
const USE_MPI = get(ENV, "WANNIERNLQG_USE_MPI", "0") == "1"
USE_MPI && !MPI.Initialized() && MPI.Init()
using WannierNLQG
include(joinpath(@__DIR__, "ParallelogramRegionFixture.jl"))
const Fixture = ParallelogramRegionFixture
const RANK = USE_MPI ? MPI.Comm_rank(MPI.COMM_WORLD) : 0
const RANKS = USE_MPI ? MPI.Comm_size(MPI.COMM_WORLD) : 1
const DESTINATION = abspath(only(ARGS))
# No launcher or rank limit is hidden in this probe. The existing Full wrapper
# retains ranks1/2; the separately allocated targeted comparison may add ranks3.
include(joinpath(@__DIR__, "FullMPIRankProfile.jl"))
const ORIGINAL_CASES = ((2, 3), (9, 8))
const CASES = FullMPIRankProfile.is_air_profile() ? ((1, 1), ORIGINAL_CASES...) : ORIGINAL_CASES
payload = Dict{String, Any}()
observed = Dict{String, Any}()
owned = Dict{String, Any}()
preflight = Dict{String, Any}()
unknown = Dict{String, Any}()
for rule in (:midpoint, :left_endpoint), counts in CASES
    key = rule == :midpoint ? string(counts) : "left_endpoint:"*string(counts)
    label =
        rule == :midpoint ? "mesh$(counts[1])-$(counts[2])" :
        "left_endpoint-mesh$(counts[1])-$(counts[2])"
    empty!(Fixture.OBSERVED_CARTESIAN_POINTS)
    empty!(Fixture.OWNED_CARTESIAN_POINTS)
    empty!(Fixture.PREFLIGHT_CARTESIAN_POINTS)
    empty!(Fixture.UNKNOWN_CARTESIAN_POINTS)
    Fixture.RECORD_POINTS[] = true
    sampling = KRegion(;
        origin = (4.0, 0.2),
        vector_1 = (0.4, 0.08),
        vector_2 = (0.12, 0.36),
        k_mesh = counts,
    )
    result = WannierNLQG.run(
        Fixture.config(
            sampling,
            joinpath(DESTINATION, label);
            integration_algorithm = UniformIntegration(region_quadrature = rule),
        ),
    )
    if RANK == 0
        tables = Fixture.tensors(result)
        @test length(tables) == 4
        @test all(maximum(abs, table) > 0 for table in values(tables))
        payload[key] = Fixture.tensor_records(tables)
    end
    observed[key] = unique(Fixture.OBSERVED_CARTESIAN_POINTS)
    owned[key] = unique(Fixture.OWNED_CARTESIAN_POINTS)
    preflight[key] = unique(Fixture.PREFLIGHT_CARTESIAN_POINTS)
    unknown[key] = unique(Fixture.UNKNOWN_CARTESIAN_POINTS)
end
Fixture.RECORD_POINTS[] = false
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
        mpi_library_path = MPI_LIBRARY_PATH,
        mpi_library_version = MPI.Get_library_version(),
    )),
)
if RANK == 0
    write(joinpath(DESTINATION, "numerical.json"), JSON3.write(payload))
    println("PARALLELOGRAM_REGION_MPI_PROBE_PASS ranks=$RANKS")
end
USE_MPI && !MPI.Finalized() && MPI.Finalize()
