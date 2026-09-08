using WannierNLQG
using WannierNLQG.Symmetrization

include(joinpath(@__DIR__, "SymmetrizationExampleSupport.jl"))
using .SymmetrizationExampleSupport

output_root = example_output_root("spin_only")
config = SymmetrizationConfig(
    win_file = example_input(".win"),
    tb_file = example_input("_tb.dat"),
    chk_file = example_input(".chk"),
    spn_file = example_input(".spn"),
    output_tb_file = joinpath(output_root, "synthetic_sym_tb.dat"),
    output_real_space_operator_bundle_file = joinpath(output_root, "wannierNLQG_tb.h5"),
    report_json_file = joinpath(output_root, "symmetrization.json"),
    include_time_reversal = true,
    check_roundtrip = true,
    roundtrip_tolerance = 1.0e-8,
    covariance_tolerance = 1.0e-8,
    idempotence_tolerance = 1.0e-9,
    check_idempotence = true,
    overwrite = true,
)

result = symmetrize_wannier_operators(config)
example_summary("spin_only", result)
