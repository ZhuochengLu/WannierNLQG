module FullMPIRankProfile
using JSON3
const PROFILE_FILE =
    joinpath(dirname(dirname(@__DIR__)), "scripts/test_support/full_rank_profiles.json")
const DEFINITIONS = JSON3.read(read(PROFILE_FILE, String))
DEFINITIONS.schema == "wanniernlqg.full-mpi-profiles/1" || error("unsupported MPI rank profile")
function selected_profile()
    name = get(ENV, "WANNIERNLQG_TEST_MPI_PROFILE", "legacy16")
    haskey(DEFINITIONS.profiles, name) || error("unsupported Full MPI rank profile: " * name)
    return DEFINITIONS.profiles[name]
end
wannierization_ranks() = Tuple(Int.(selected_profile().rank_plan.wannierization))
adaptive_ranks() = Tuple(Int.(selected_profile().rank_plan.adaptive))
native_definition_ranks() = Tuple(Int.(selected_profile().rank_plan.native_definition))
checkpoint_definition_ranks() = Tuple(Int.(selected_profile().rank_plan.checkpoint_definition))
is_air_profile() = get(ENV, "WANNIERNLQG_TEST_MPI_PROFILE", "legacy16") == "air3"
affine_ranks() = is_air_profile() ? (1, 2, 3) : (1, 2)
u_fixture_variants() = is_air_profile() ? ("original", "empty-owner-1d") : ("original",)
end
