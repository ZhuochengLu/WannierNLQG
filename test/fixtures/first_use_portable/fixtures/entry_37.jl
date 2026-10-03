# Cold public call on exact arguments from the original valid fixture.
# Only destinations change; no target/backend activation before timer.
using Serialization, SHA, Test
@test !any(
    Base.get_extension(WannierNLQG, n)!==nothing for n in (
        :WannierNLQGWannierizationExt,
        :WannierNLQGSymmetrizationExt,
        :WannierNLQGSymmetryFoundationExt,
        :WannierNLQGOperatorBundleExt,
    )
)
const FROZEN_INPUT=Main.FirstUsePortableSupport.deserialize_input(
    Main.FirstUsePortableSupport.input("arguments/fixture_8.jls"),
)
const NEW_OUTPUT=joinpath(dirname(Main.RECEIPT), "native_outputs")
@test !ispath(NEW_OUTPUT)
mkpath(NEW_OUTPUT)
positional=FROZEN_INPUT.positional
keywords=merge(
    (; FROZEN_INPUT.keyword...),
    (
        output_spn_file = joinpath(NEW_OUTPUT, "qe.spn"),
        provenance_json = joinpath(NEW_OUTPUT, "qe_spn.json"),
    ),
)
@test !any(
    Base.get_extension(WannierNLQG, n)!==nothing for n in (
        :WannierNLQGWannierizationExt,
        :WannierNLQGSymmetrizationExt,
        :WannierNLQGSymmetryFoundationExt,
        :WannierNLQGOperatorBundleExt,
    )
)
value=WannierNLQG.Wannierization.generate_qe_paw_spn(positional...; keywords...)
@test value.passed
native=Main.FirstUseExpertProbe.numeric_summary(
    WannierNLQG.IO.read_wannier_spn(keywords.output_spn_file),
)
@test native.all_finite
@test any(x->haskey(x, :max_abs) && x.max_abs>0, native.leaves)
write(joinpath(dirname(Main.RECEIPT), "native_science.json"), JSON3.write(native))
