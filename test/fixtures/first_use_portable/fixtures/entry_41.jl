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
    Main.FirstUsePortableSupport.input("arguments/fixture_11.jls"),
)
const NEW_OUTPUT=joinpath(dirname(Main.RECEIPT), "native_outputs")
@test !ispath(NEW_OUTPUT)
mkpath(NEW_OUTPUT)
cfg=FROZEN_INPUT.positional[1]
fields=NamedTuple{fieldnames(typeof(cfg))}(Tuple(getfield(cfg, k) for k in fieldnames(typeof(cfg))))
new_cfg=typeof(cfg)(;
    merge(
        fields,
        (
            output_file = joinpath(NEW_OUTPUT, "fixture.uIu"),
            provenance_json = joinpath(NEW_OUTPUT, "uiu.json"),
        ),
    )...,
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
value=WannierNLQG.Wannierization.generate_wannier_uiu(positional...; keywords...)
@test value.passed && value.resumed_from_kpoint==0
blocks=Matrix{ComplexF64}[]
WannierNLQG.IO.foreach_wannier_uiu_block(new_cfg.output_file) do block, args...
    ;
    push!(blocks, copy(block));
end
@test !isempty(blocks) &&
      all(b->all(isfinite, b), blocks) &&
      maximum(maximum(abs, b) for b in blocks)>0
native=Main.FirstUseExpertProbe.numeric_summary(blocks)
write(joinpath(dirname(Main.RECEIPT), "native_science.json"), JSON3.write(native))
