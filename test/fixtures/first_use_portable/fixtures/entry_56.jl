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
    Main.FirstUsePortableSupport.input("arguments/fixture_23.jls"),
)
const NEW_OUTPUT=joinpath(dirname(Main.RECEIPT), "native_outputs")
@test !ispath(NEW_OUTPUT)
mkpath(NEW_OUTPUT)
positional=(joinpath(NEW_OUTPUT, "projection.h5"), FROZEN_INPUT.positional[2]);
keywords=(; FROZEN_INPUT.keyword...)
@test !any(
    Base.get_extension(WannierNLQG, n)!==nothing for n in (
        :WannierNLQGWannierizationExt,
        :WannierNLQGSymmetrizationExt,
        :WannierNLQGSymmetryFoundationExt,
        :WannierNLQGOperatorBundleExt,
    )
)
value=WannierNLQG.Wannierization.write_projection_representation_search_hdf5(
    positional...;
    keywords...,
)
@test isfile(value)
restored=WannierNLQG.Wannierization.read_projection_representation_search_hdf5(value)
@test restored.payload_sha256==FROZEN_INPUT.positional[2].payload_sha256
@test restored.complete && restored.total_solution_count>0
@test !isempty(restored.solutions) && any(s->any(x->x>0, s.coefficients), restored.solutions)
native=Main.FirstUseExpertProbe.numeric_summary(restored)
write(joinpath(dirname(Main.RECEIPT), "native_science.json"), JSON3.write(native))
