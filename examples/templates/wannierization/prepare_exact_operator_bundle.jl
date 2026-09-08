using WannierNLQG
import WannierNLQG.Wannierization as W

"""Build an exact same-gauge operator-bundle configuration from sealed inputs."""
function build_config(input_root::AbstractString, output_root::AbstractString)
    return W.ExactWannierOperatorBundleConfig(
        tb_file = joinpath(input_root, "wannier90_tb.dat"),
        chk_file = joinpath(input_root, "wannier90.chk"),
        eig_file = joinpath(input_root, "wannier90.eig"),
        mmn_file = joinpath(input_root, "wannier90.mmn"),
        uiu_file = joinpath(input_root, "wannier90.uIu"),
        uiu_provenance_json = joinpath(input_root, "wannier90.uIu.provenance.json"),
        output_bundle_file = joinpath(output_root, "wannierNLQG_exact_operators.h5"),
        overwrite = false,
        support_tolerance = 1.0e-12,
        wigner_seitz_tolerance = 1.0e-5,
        wigner_seitz_search_size = 3,
    )
end

if abspath(PROGRAM_FILE) == @__FILE__
    input_root = get(ENV, "WANNIERNLQG_EXACT_BUNDLE_INPUT_ROOT", "")
    isempty(input_root) &&
        error("set WANNIERNLQG_EXACT_BUNDLE_INPUT_ROOT to one sealed gauge chain")
    output_root = normpath(
        get(
            ENV,
            "WANNIERNLQG_TEMPLATE_OUTPUT_ROOT",
            joinpath(tempdir(), "wanniernlqg-exact-operator-bundle"),
        ),
    )
    mkpath(output_root)
    result = W.prepare_exact_wannier_operator_bundle(build_config(input_root, output_root))
    result.passed || error("exact operator-bundle construction failed")
    println("bundle=$(result.operator_bundle_file)")
end
