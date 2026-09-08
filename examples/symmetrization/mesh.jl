using WannierNLQG
using WannierNLQG.Symmetrization

include(joinpath(@__DIR__, "SymmetrizationExampleSupport.jl"))
using .SymmetrizationExampleSupport

config = MeshScreenConfig(
    win_file = example_input(".win"),
    include_time_reversal = true,
    symmetry_tolerance = 1.0e-5,
    operation_indices = nothing,
    dimension = 3,
    density_target = 55.0,
    search_radius = 10,
)

result = screen_wannier_mesh(config)
println(
    "EXAMPLE_PASS name=mesh original=$(result.original_mp_grid) " *
    "recommended=$(result.recommended_grid) operations=$(result.selected_operation_count)",
)
