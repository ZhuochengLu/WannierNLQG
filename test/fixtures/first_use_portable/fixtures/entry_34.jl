using Test, SHA, JSON3
const COLD_HAM_W=WannierNLQG.Wannierization
const COLD_HAM_IO=WannierNLQG.IO
const INPUT_DIRECTORY=ENV["FIRSTUSE_HAM_NATIVE_DIRECTORY"]
const INPUT_IDENTITIES=ENV["FIRSTUSE_HAM_NATIVE_IDENTITIES"]
function check_frozen_source()
    for (file, expected) in JSON3.read(read(INPUT_IDENTITIES, String), Dict{String, String})
        bytes2hex(sha256(read(Main.FirstUsePortableSupport.input(file))))==expected ||
            error("FROZEN_HAMILTONIAN_INPUT_CHANGED")
    end
end
check_frozen_source()
Base.get_extension(WannierNLQG, :WannierNLQGWannierizationExt)===nothing ||
    error("BACKEND_PREACTIVATED_BEFORE_HAMILTONIAN_FIXTURE")
output_dir=joinpath(dirname(Main.RECEIPT), "actual_operator_output")
ispath(output_dir) && error("operator output exists")
mkpath(output_dir)
# Same immutable, real three-kpoint QE/PAW/SpinOrbit inputs. The preparation
# cache is allocated by the package under the fresh output directory, not here.
source=WannierNLQG.SymmetryFoundation.QuantumEspressoWavefunctionSource(
    joinpath(INPUT_DIRECTORY, "fixture.save");
    include_time_reversal = false,
)
eig_file=joinpath(output_dir, "fixture.eig")
COLD_HAM_IO.write_wannier_eig(
    eig_file,
    COLD_HAM_IO.WannierEIG(1, 3, reshape([1.0, 2.0, 3.0], 1, 3)),
)
config=COLD_HAM_W.WannierHamiltonianOperatorGenerationConfig(
    source = source,
    topology_file = joinpath(INPUT_DIRECTORY, "fixture.nnkp"),
    eig_file = eig_file,
    output_file = joinpath(output_dir, "fixture.sHu"),
    spn_file = joinpath(INPUT_DIRECTORY, "qe-native.spn"),
    spn_provenance_file = joinpath(INPUT_DIRECTORY, "qe-native.spn.json"),
    max_cached_wavefunction_kpoints = 2,
)
Base.get_extension(WannierNLQG, :WannierNLQGWannierizationExt)===nothing ||
    error("CONFIG_PREACTIVATED_HAMILTONIAN_BACKEND")
result=COLD_HAM_W.generate_wannier_shu(config)
@test result.passed && result.artifact_published
@test isfile(result.output_file) && isfile(result.provenance_json)
blocks=Any[]
COLD_HAM_IO.foreach_wannier_shu_block(result.output_file) do block, _, _, _, _
    push!(
        blocks,
        (
            shape = size(block),
            finite = all(isfinite, block),
            max_abs = maximum(abs, block; init = 0.0),
            payload_hex = bytes2hex(reinterpret(UInt8, vec(Array(block)))),
        ),
    )
end
@test length(blocks)==9
@test all(x->x.finite, blocks)
@test maximum(x.max_abs for x in blocks)>0
check_frozen_source()
write(joinpath(dirname(Main.RECEIPT), "native_operator_blocks.json"), JSON3.write(blocks))
println("TRUE_COLD_NATIVE_shu_WITH_NONZERO_OUTPUT_PASS")
