using Test
include(Main.FirstUsePortableSupport.input("fixtures/support_2.jl"))

fixture = time_reversal_representation_fixture()
@test maximum(abs, fixture.representation.sewing_matrices) > 0
actual = WannierNLQG.Wannierization.validate_band_representation_compatibility(
    fixture.representation,
    fixture.plan;
    outer_mask = [trues(2), trues(2)],
    frozen_mask = [trues(2), trues(2)],
    tolerance = 1.0e-12,
)
@test actual.supported_contract
@test actual.passed
@test actual.assessment_status == WannierNLQG.Wannierization.REPRESENTATION_COMPATIBLE
@test all(isfinite, actual.maximum_group_law_residuals)
println("REPRESENTATION_COMPATIBILITY_VALID ", actual.assessment_status)
