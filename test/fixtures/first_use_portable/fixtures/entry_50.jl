# Actual original fixture arguments, frozen in a separate preparation process.
# No eager backend activation, no private solver; all required loading stays in public-call timer.
using Serialization, SHA, Test
const BACKENDS_BEFORE = Dict(
    string(n)=>Base.get_extension(WannierNLQG, n)!==nothing for n in (
        :WannierNLQGWannierizationExt,
        :WannierNLQGSymmetrizationExt,
        :WannierNLQGSymmetryFoundationExt,
        :WannierNLQGOperatorBundleExt,
    )
)
@test !any(values(BACKENDS_BEFORE))
const FROZEN_INPUT = Main.FirstUsePortableSupport.deserialize_input(
    Main.FirstUsePortableSupport.input("arguments/fixture_19.jls"),
)
@test !any(
    Base.get_extension(WannierNLQG, n)!==nothing for n in (
        :WannierNLQGWannierizationExt,
        :WannierNLQGSymmetrizationExt,
        :WannierNLQGSymmetryFoundationExt,
        :WannierNLQGOperatorBundleExt,
    )
)
value = WannierNLQG.Symmetrization.qualify_response_symmetry_wannier90(
    FROZEN_INPUT.positional...;
    FROZEN_INPUT.keyword...,
)
@test value["dimensions"]["status"] == "PASS"
@test value["num_operations"] >= 1
@test value["overall_status"] in ("PASS", "PHYSICS_HOLD")
write(
    joinpath(dirname(Main.RECEIPT), "actual_return.json"),
    JSON3.write(Main.FirstUseExpertProbe.numeric_summary(value)),
)
