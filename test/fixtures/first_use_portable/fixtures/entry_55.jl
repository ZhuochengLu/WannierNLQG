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
    Main.FirstUsePortableSupport.input("arguments/fixture_22.jls"),
)
const NEW_OUTPUT=joinpath(dirname(Main.RECEIPT), "native_outputs")
@test !ispath(NEW_OUTPUT)
mkpath(NEW_OUTPUT)
cfg=FROZEN_INPUT.positional[1]
fields=NamedTuple{fieldnames(typeof(cfg))}(Tuple(getfield(cfg, k) for k in fieldnames(typeof(cfg))))
new_cfg=typeof(cfg)(;
    merge(fields, (output_hdf5 = joinpath(NEW_OUTPUT, "diagnostic-sewing.h5"),))...,
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
value=WannierNLQG.Wannierization.prepare_band_representation(positional...; keywords...)
@test isfile(something(value.output_hdf5))
@test all(isfinite, value.representation.sewing_matrices) &&
      maximum(abs, value.representation.sewing_matrices)>0
@test any(
    d->d.code==:PAW_SEWING_QUALITY_CHECK && get(d.context, "gate_result", "")=="FAIL",
    value.diagnostics,
)
restored=WannierNLQG.SymmetryFoundation.read_band_representation_hdf5(value.output_hdf5)
@test isequal(restored.sewing_matrices, value.representation.sewing_matrices)
@test restored.conventions["paw_sewing_gate_records_json"]==value.representation.conventions["paw_sewing_gate_records_json"]
native=Main.FirstUseExpertProbe.numeric_summary(restored)
write(joinpath(dirname(Main.RECEIPT), "native_science.json"), JSON3.write(native))
