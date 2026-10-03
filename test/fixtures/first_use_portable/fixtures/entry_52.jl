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
    Main.FirstUsePortableSupport.input("arguments/fixture_21.jls"),
)
@test !any(
    Base.get_extension(WannierNLQG, n)!==nothing for n in (
        :WannierNLQGWannierizationExt,
        :WannierNLQGSymmetrizationExt,
        :WannierNLQGSymmetryFoundationExt,
        :WannierNLQGOperatorBundleExt,
    )
)
value = WannierNLQG.Wannierization.smv_fletcher_reeves_two_stage_audit(
    FROZEN_INPUT.positional...;
    FROZEN_INPUT.keyword...,
)
@test value.passed
@test value.status == WannierNLQG.Wannierization.SMV_FLETCHER_REEVES_TWO_STAGE_AUDIT_PASS_STATUS
@test value.manifest_sha256 == bytes2hex(SHA.sha256(read(FROZEN_INPUT.keyword[:manifest_path])))
write(
    joinpath(dirname(Main.RECEIPT), "actual_return.json"),
    JSON3.write(Main.FirstUseExpertProbe.numeric_summary(value)),
)
