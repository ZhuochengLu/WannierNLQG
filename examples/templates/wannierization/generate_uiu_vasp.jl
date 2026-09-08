using WannierNLQG
import WannierNLQG.Wannierization as W

"""Build a same-run VASP PAW uIu configuration without modifying DFT inputs."""
function build_config(input_root::AbstractString, output_root::AbstractString)
    source = VASPWavefunctionSource(
        joinpath(input_root, "POSCAR"),
        joinpath(input_root, "WAVECAR");
        potcar_file = joinpath(input_root, "POTCAR"),
        incar_file = joinpath(input_root, "INCAR"),
        outcar_file = joinpath(input_root, "OUTCAR"),
        band_range = nothing,
        spin_channel = 1,
        representation_cutoff_ev = nothing,
    )
    return W.WannierUIUGenerationConfig(
        source = source,
        topology_file = joinpath(input_root, "wannier90.mmn"),
        oracle_mmn_file = joinpath(input_root, "wannier90.mmn"),
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
    input_root = get(ENV, "WANNIERNLQG_UIU_VASP_INPUT_ROOT", "")
    isempty(input_root) &&
        error("set WANNIERNLQG_UIU_VASP_INPUT_ROOT to the same-run VASP directory")
    output_root = normpath(
        get(ENV, "WANNIERNLQG_TEMPLATE_OUTPUT_ROOT", joinpath(tempdir(), "wanniernlqg-uiu-vasp")),
    )
    mkpath(output_root)
    result = W.generate_wannier_uiu(build_config(input_root, output_root))
    provenance = result.artifacts["provenance_json"]
    result.passed || error("uIu qualification failed; inspect $(provenance)")
    println("uIu=$(result.artifacts["uiu"])")
end
