using WannierNLQG
using WannierNLQG.Symmetrization

include(joinpath(@__DIR__, "SymmetrizationExampleSupport.jl"))
using .SymmetrizationExampleSupport

output_root = example_output_root("combined")
config = SymmetrizationConfig(
    win_file = example_input(".win"),
    tb_file = example_input("_tb.dat"),
    chk_file = example_input(".chk"),
    eig_file = example_input(".eig"),
    mmn_file = example_input(".mmn"),
    spn_file = example_input(".spn"),
    output_tb_file = joinpath(output_root, "synthetic_sym_tb.dat"),
    output_real_space_operator_bundle_file = joinpath(output_root, "wannierNLQG_tb.h5"),
    report_json_file = joinpath(output_root, "symmetrization.json"),
    include_time_reversal = true,
    support_tolerance = 1.0e-12,
    wigner_seitz_tolerance = 1.0e-5,
    wigner_seitz_search_size = 3,
    check_roundtrip = true,
    roundtrip_tolerance = 1.0e-8,
    covariance_tolerance = 1.0e-8,
    idempotence_tolerance = 1.0e-9,
    check_idempotence = true,
    overwrite = true,
)

failure = try
    symmetrize_wannier_operators(config)
catch error
    error
end
failure isa ArgumentError || throw(failure)
occursin("LEGACY_FULL_PROFILE_REMOVED", sprint(showerror, failure)) || throw(failure)
println(
    "EXAMPLE_MIGRATION_REQUIRED name=combined " *
    "use=Wannierization_profile_full reason=LEGACY_FULL_PROFILE_REMOVED",
)
