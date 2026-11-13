using Test, LinearAlgebra
function scalar_spinor_theta_fixture(spinor, theta)
    sf=WannierNLQG.SymmetryFoundation
    nb=size(theta, 1);
    I3=Matrix{Float64}(I, 3, 3)
    ops=[
        sf.SymmetryOperation(Matrix{Int}(I, 3, 3), zeros(3), I3),
        sf.SymmetryOperation(Matrix{Int}(I, 3, 3), zeros(3), I3, true),
    ]
    sewing=zeros(ComplexF64, nb, nb, 2, 1)
    sewing[:, :, 1, 1].=Matrix{ComplexF64}(I, nb, nb);
    sewing[:, :, 2, 1].=theta
    return sf.BandRepresentation(
        "1.1",
        :synthetic,
        spinor,
        I3,
        2pi*I3,
        (1, 1, 1),
        zeros(1, 3),
        zeros(nb, 1),
        ops,
        ones(Int, 2, 1),
        zeros(Int, 3, 2, 1),
        sewing,
        ones(Int, nb, 1),
        [1],
        [1],
        [1],
    )
end
@testset "Scalar Theta squared plus one and spinor Kramers closure" begin
    validate=WannierNLQG.Wannierization.validate_band_representation_compatibility
    scalar=scalar_spinor_theta_fixture(false, ones(ComplexF64, 1, 1))
    report=validate(
        scalar;
        outer_mask = [trues(1)],
        frozen_mask = [trues(1)],
        selected_projectors = [ones(ComplexF64, 1, 1)],
        tolerance = 1e-12,
    )
    @test report.passed
    @test report.theta_squared_residual <= 1e-12
    spinor=scalar_spinor_theta_fixture(true, ComplexF64[0 1; -1 0])
    @test validate(spinor; outer_mask = [trues(2)], frozen_mask = [trues(2)], tolerance = 1e-12).passed
    odd=validate(
        spinor;
        outer_mask = [trues(2)],
        selected_projectors = [reshape(ComplexF64[1, 0], 2, 1)],
        tolerance = 1e-12,
    )
    @test !odd.passed
    @test any(d->d.code==:KRAMERS_BLOCK_NOT_CLOSED, odd.diagnostics)
    odd_mask=validate(spinor; outer_mask = [BitVector([true, false])], tolerance = 1e-12)
    @test !odd_mask.passed
    @test any(d->d.code==:KRAMERS_BLOCK_NOT_CLOSED, odd_mask.diagnostics)
    swapping=scalar_spinor_theta_fixture(false, ComplexF64[0 1; 1 0])
    badmask=validate(swapping; outer_mask = [BitVector([true, false])], tolerance = 1e-12)
    @test !badmask.passed
    @test any(d->d.code==:KRAMERS_BLOCK_NOT_CLOSED, badmask.diagnostics)
    badprojector=validate(
        swapping;
        outer_mask = [trues(2)],
        selected_projectors = [reshape(ComplexF64[1, 0], 2, 1)],
        tolerance = 1e-12,
    )
    @test !badprojector.passed
    @test any(d->d.code==:ANTIUNITARY_PROJECTOR_COVARIANCE_FAILED, badprojector.diagnostics)
end
