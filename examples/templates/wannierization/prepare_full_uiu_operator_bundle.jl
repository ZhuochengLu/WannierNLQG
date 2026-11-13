using WannierNLQG
import WannierNLQG.Wannierization as W

"""Build a full-uIu same-gauge operator-bundle configuration from sealed inputs."""
function build_config(input_root::AbstractString, output_root::AbstractString)
    return W.FullUIUDerivativeOperatorBundleConfig(
        tb_file = joinpath(input_root, "model_tb.dat"),
        chk_file = joinpath(input_root, "wannier.chk"),
        eig_file = joinpath(input_root, "wannier.eig"),
        mmn_file = joinpath(input_root, "wannier.mmn"),
        uiu_file = joinpath(input_root, "wannier.uIu"),
        uiu_provenance_json = joinpath(input_root, "wannier.uIu.provenance.json"),
        output_bundle_file = joinpath(output_root, "wannierNLQG_full_uiu_operators.h5"),
        overwrite = false,
        support_tolerance = 1.0e-12,
        wigner_seitz_tolerance = 1.0e-5,
        wigner_seitz_search_size = 3,
    )
end

if abspath(PROGRAM_FILE) == @__FILE__
    input_root = get(ENV, "WANNIERNLQG_FULL_UIU_BUNDLE_INPUT_ROOT", "")
    isempty(input_root) &&
        error("set WANNIERNLQG_FULL_UIU_BUNDLE_INPUT_ROOT to one sealed gauge chain")
    output_root = normpath(
        get(
            ENV,
            "WANNIERNLQG_TEMPLATE_OUTPUT_ROOT",
            joinpath(tempdir(), "wanniernlqg-full-uiu-operator-bundle"),
        ),
    )
    mkpath(output_root)
    result = W.prepare_full_uiu_derivative_operator_bundle(build_config(input_root, output_root))
    result.construction_readback_passed || error("full uIu bundle construction or readback failed")
    println("bundle=$(result.operator_bundle_file)")
end
