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
    Main.FirstUsePortableSupport.input("arguments/fixture_7.jls"),
)
const NEW_OUTPUT=joinpath(dirname(Main.RECEIPT), "native_outputs")
@test !ispath(NEW_OUTPUT)
mkpath(NEW_OUTPUT)
positional=FROZEN_INPUT.positional
keywords=merge((; FROZEN_INPUT.keyword...), (artifact_dir = joinpath(NEW_OUTPUT, "matrices"),))
@test !any(
    Base.get_extension(WannierNLQG, n)!==nothing for n in (
        :WannierNLQGWannierizationExt,
        :WannierNLQGSymmetrizationExt,
        :WannierNLQGSymmetryFoundationExt,
        :WannierNLQGOperatorBundleExt,
    )
)
value=WannierNLQG.Wannierization.generate_qe_paw_matrix_elements(positional...; keywords...)
@test value.passed && value.physical_overlap_available
@test maximum(abs, value.mmn.data)>0 && maximum(abs, value.amn.data)>0
@test isequal(WannierNLQG.IO.read_wannier_mmn(value.artifacts["mmn"]).data, value.mmn.data)
@test isequal(WannierNLQG.IO.read_wannier_amn(value.artifacts["amn"]).data, value.amn.data)
native=Main.FirstUseExpertProbe.numeric_summary((mmn = value.mmn, amn = value.amn))
write(joinpath(dirname(Main.RECEIPT), "native_science.json"), JSON3.write(native))
