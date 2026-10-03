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
    Main.FirstUsePortableSupport.input("arguments/fixture_13.jls"),
)
const NEW_OUTPUT=joinpath(dirname(Main.RECEIPT), "native_outputs")
@test !ispath(NEW_OUTPUT)
mkpath(NEW_OUTPUT)
positional=(
    FROZEN_INPUT.positional[1],
    FROZEN_INPUT.positional[2],
    joinpath(NEW_OUTPUT, "paw_scdm.h5"),
);
keywords=(; FROZEN_INPUT.keyword...)
@test !any(
    Base.get_extension(WannierNLQG, n)!==nothing for n in (
        :WannierNLQGWannierizationExt,
        :WannierNLQGSymmetrizationExt,
        :WannierNLQGSymmetryFoundationExt,
        :WannierNLQGOperatorBundleExt,
    )
)
value=WannierNLQG.Wannierization.prepare_paw_scdm_input_artifact(positional...; keywords...)
restored=WannierNLQG.Wannierization.read_paw_scdm_input_artifact(positional[3])
@test maximum(abs, restored.frames)>0 &&
      all(isfinite, restored.frames) &&
      all(isfinite, restored.singular_values)
native=Main.FirstUseExpertProbe.numeric_summary(restored)
write(joinpath(dirname(Main.RECEIPT), "native_science.json"), JSON3.write(native))
