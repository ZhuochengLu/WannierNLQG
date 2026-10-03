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
    Main.FirstUsePortableSupport.input("arguments/fixture_6.jls"),
)
const NEW_OUTPUT=joinpath(dirname(Main.RECEIPT), "native_outputs")
@test !ispath(NEW_OUTPUT)
mkpath(NEW_OUTPUT)
cfg=FROZEN_INPUT.positional[1]
fields=NamedTuple{fieldnames(typeof(cfg))}(Tuple(getfield(cfg, k) for k in fieldnames(typeof(cfg))))
new_cfg=typeof(cfg)(; merge(fields, (output_hdf5 = joinpath(NEW_OUTPUT, "gauge.h5"),))...)
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
value=WannierNLQG.Wannierization.prepare_symmetry_covariant_wavefunctions(
    positional...;
    keywords...,
)
@test value.status in (:PASS, :STANDARD)
@test isfile(something(value.output_hdf5))
native=Main.FirstUseExpertProbe.native_writer_readback(
    :write_band_representation_hdf5,
    value.output_hdf5,
)
@test !isempty(native.numeric_leaves)
write(joinpath(dirname(Main.RECEIPT), "native_science.json"), JSON3.write(native))
