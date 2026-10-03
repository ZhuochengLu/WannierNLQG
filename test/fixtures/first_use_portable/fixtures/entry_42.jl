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
    Main.FirstUsePortableSupport.input("arguments/fixture_12.jls"),
)
const NEW_OUTPUT=joinpath(dirname(Main.RECEIPT), "native_outputs")
@test !ispath(NEW_OUTPUT)
mkpath(NEW_OUTPUT)
cfg=FROZEN_INPUT.positional[1]
fields=NamedTuple{fieldnames(typeof(cfg))}(Tuple(getfield(cfg, k) for k in fieldnames(typeof(cfg))))
new_cfg=typeof(cfg)(;
    merge(fields, (output_bundle_file = joinpath(NEW_OUTPUT, "synthetic-exact-bundle.h5"),))...,
)
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
value=WannierNLQG.Wannierization.prepare_exact_wannier_operator_bundle(positional...; keywords...)
@test value.passed
bundle=WannierNLQG.IO.read_real_space_operator_bundle(value.operator_bundle_file)
@test bundle.manifest.profile==:derivative &&
      bundle.manifest.derivative_overlap_completeness=="full_hilbert_space"
@test length(bundle.operators)==7
native=Main.FirstUseExpertProbe.numeric_summary(bundle.operators)
@test any(x->haskey(x, :max_abs) && x.max_abs>0, native.leaves)
write(joinpath(dirname(Main.RECEIPT), "native_science.json"), JSON3.write(native))
