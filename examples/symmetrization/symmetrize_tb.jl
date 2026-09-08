using WannierNLQG
using WannierNLQG.Symmetrization

include(joinpath(@__DIR__, "SymmetrizationExampleSupport.jl"))
using .SymmetrizationExampleSupport

output_root = example_output_root("tb_only")
config = SymmetrizationConfig(
    win_file = example_input(".win"),
    tb_file = example_input("_tb.dat"),
    output_tb_file = joinpath(output_root, "synthetic_sym_tb.dat"),
    output_real_space_operator_bundle_file = joinpath(output_root, "wannierNLQG_tb.h5"),
    report_json_file = joinpath(output_root, "symmetrization.json"),
    include_time_reversal = true,
    symmetry_tolerance = 1.0e-5,
    projection_tolerance = 1.0e-7,
    representation_tolerance = 1.0e-7,
    operation_indices = nothing,
    magnetic = nothing,
    cutoff = nothing,
    covariance_tolerance = 1.0e-8,
    idempotence_tolerance = 1.0e-9,
    check_idempotence = true,
    overwrite = true,
)

result = symmetrize_wannier_operators(config)
example_summary("tb_only", result)
