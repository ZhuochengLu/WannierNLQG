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
    Main.FirstUsePortableSupport.input("arguments/fixture_14.jls"),
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
value=WannierNLQG.Symmetrization.screen_wannier_mesh(positional...; keywords...)
@test value.original_mp_grid==(2, 2, 2)
@test value.selected_operation_count>0
@test all(x->x>0, value.recommended_grid)
native=Main.FirstUseExpertProbe.numeric_summary(value)
write(joinpath(dirname(Main.RECEIPT), "native_science.json"), JSON3.write(native))
