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
    Main.FirstUsePortableSupport.input("arguments/fixture_9.jls"),
)
const NEW_OUTPUT=joinpath(dirname(Main.RECEIPT), "native_outputs")
@test !ispath(NEW_OUTPUT)
mkpath(NEW_OUTPUT)
positional=FROZEN_INPUT.positional
keywords=(; FROZEN_INPUT.keyword...)
@test !any(
    Base.get_extension(WannierNLQG, n)!==nothing for n in (
        :WannierNLQGWannierizationExt,
        :WannierNLQGSymmetrizationExt,
        :WannierNLQGSymmetryFoundationExt,
        :WannierNLQGOperatorBundleExt,
    )
)
value=WannierNLQG.Wannierization.generate_wannier_amn(positional...; keywords...)
@test all(isfinite, value.data) && maximum(abs, value.data)>0
f=joinpath(NEW_OUTPUT, "actual.amn")
WannierNLQG.IO.write_wannier_amn(f, value)
@test isequal(WannierNLQG.IO.read_wannier_amn(f).data, value.data)
native=Main.FirstUseExpertProbe.numeric_summary(value)
write(joinpath(dirname(Main.RECEIPT), "native_science.json"), JSON3.write(native))
