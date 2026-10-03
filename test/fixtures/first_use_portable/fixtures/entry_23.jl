using WannierNLQG, Serialization, SHA, JSON3, Test
const W=WannierNLQG.Wannierization
root=joinpath(dirname(Main.RECEIPT), "fixture_output")
@test !ispath(root)
mkpath(root)
input_file=Main.FirstUsePortableSupport.input("arguments/fixture_4.jls")
@test bytes2hex(
    sha256(read(input_file)),
)=="682634d6ed17f12815771650b45b859b2d8b048286eabce0768875c4e9b97a88"
actual = Main.FirstUsePortableSupport.deserialize_input(input_file)
@test Base.get_extension(WannierNLQG, :WannierNLQGWannierizationExt)===nothing
packed, representation, plan=actual.positional
@test plan isa WannierNLQG.SymmetryFoundation.WannierSymmetryPlan
@test actual.keyword[:persist_hdf5]===false
original_sha=bytes2hex(sha256(read(packed)))
local_bundle=joinpath(root, "actual.wannierization-tb.h5")
cp(packed, local_bundle; force = false)
@test Base.get_extension(WannierNLQG, :WannierNLQGWannierizationExt)===nothing
result=W.qualify_exported_wannierization_tb(local_bundle, representation, plan; actual.keyword...)
@test length(result.metrics)==8
@test !result.global_production_eligible
@test bytes2hex(sha256(read(local_bundle)))==original_sha
@test bytes2hex(sha256(read(packed)))==original_sha
loaded=WannierNLQG.IO.read_real_space_operator_bundle(local_bundle)
h=loaded.operators[WannierNLQG.Core.REAL_SPACE_HAMILTONIAN].data
@test all(isfinite, h) && maximum(abs, h)>0
native=Main.FirstUseExpertProbe.native_writer_readback(
    :write_band_representation_hdf5,
    local_bundle,
)
write(joinpath(dirname(Main.RECEIPT), "native_qualified_tb_hdf5.json"), JSON3.write(native))
write(joinpath(root, "actual.qualification.json"), JSON3.write(result))
