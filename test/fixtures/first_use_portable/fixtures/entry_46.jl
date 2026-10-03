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
    Main.FirstUsePortableSupport.input("arguments/fixture_15.jls"),
)
const NEW_OUTPUT=joinpath(dirname(Main.RECEIPT), "native_outputs")
@test !ispath(NEW_OUTPUT)
mkpath(NEW_OUTPUT)
cfg=FROZEN_INPUT.positional[1]
fields=NamedTuple{fieldnames(typeof(cfg))}(Tuple(getfield(cfg, k) for k in fieldnames(typeof(cfg))))
new_cfg=typeof(cfg)(; merge(fields, (output_root = joinpath(NEW_OUTPUT, "output"),))...)
positional=(new_cfg,);
keywords=(; FROZEN_INPUT.keyword...)
@test !any(
    Base.get_extension(WannierNLQG, n)!==nothing for n in (
        :WannierNLQGWannierizationExt,
        :WannierNLQGSymmetrizationExt,
        :WannierNLQGSymmetryFoundationExt,
        :WannierNLQGOperatorBundleExt,
    )
)
value=WannierNLQG.Symmetrization.symmetrize_existing_wannier_model(positional...; keywords...)
@test value.status==WannierNLQG.Symmetrization.HOLD_POSITION_PENDING
@test isfile(value.artifacts["c00_hr"])
hr=WannierNLQG.IO.read_wannier_hr(value.artifacts["c00_hr"])
native=Main.FirstUseExpertProbe.numeric_summary(hr)
@test native.all_finite && any(x->haskey(x, :max_abs) && x.max_abs>0, native.leaves)
write(joinpath(dirname(Main.RECEIPT), "native_science.json"), JSON3.write(native))
