using WannierNLQG
import WannierNLQG.Wannierization as W

"""Build a bounded-memory QE uIu configuration, optionally sealed to one full workflow."""
function build_config(
    input_root::AbstractString,
    output_root::AbstractString;
    target_contract::Union{Nothing, W.WannierOperatorTargetContract} = nothing,
)
    source = QuantumEspressoWavefunctionSource(
        joinpath(input_root, "prefix.save");
        band_range = nothing,
        spin_channel = :none,
        representation_cutoff_ev = nothing,
    )
    return W.WannierUIUGenerationConfig(
        source = source,
        topology_file = joinpath(input_root, "wannier90.nnkp"),
        oracle_mmn_file = target_contract === nothing ? joinpath(input_root, "wannier90.mmn") :
                          target_contract.operator_oracle_mmn_file,
        authoritative_mmn_file = target_contract === nothing ? nothing :
                                 target_contract.operator_oracle_mmn_file,
        target_contract = target_contract,
        output_file = joinpath(output_root, "wannier90.uIu"),
        scratch_directory = joinpath(output_root, "scratch"),
        provenance_json = joinpath(output_root, "wannier90.uIu.provenance.json"),
        resume = true,
        overwrite = false,
        require_mmn_oracle = true,
        max_cached_wavefunction_kpoints = 8,
    )
end

if abspath(PROGRAM_FILE) == @__FILE__
    input_root = get(ENV, "WANNIERNLQG_UIU_QE_INPUT_ROOT", "")
    isempty(input_root) &&
        error("set WANNIERNLQG_UIU_QE_INPUT_ROOT to the QE/Wannier90 input directory")
    output_root = normpath(
        get(ENV, "WANNIERNLQG_TEMPLATE_OUTPUT_ROOT", joinpath(tempdir(), "wanniernlqg-uiu-qe")),
    )
    mkpath(output_root)
    result = W.generate_wannier_uiu(build_config(input_root, output_root))
    provenance = result.artifacts["provenance_json"]
    result.passed || error("uIu qualification failed; inspect $(provenance)")
    println("uIu=$(result.artifacts["uiu"])")
end
