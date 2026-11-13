module BerryGeometryFourierUnit
using Test, LinearAlgebra, ForwardDiff, WannierNLQG
const F=Main.OrthogonalGeometryAnalyticUnit
const C=WannierNLQG.Core
const M=WannierNLQG.MatrixElements
const R=WannierNLQG.Responses
const COMPONENTS=F.COMPONENTS

# Independent finite Fourier coefficients for the closed raw H/A functions.
# No DFT re-sampling, fitted coefficients or copied response derivative enter.
function model(lattice; rotation = Matrix{ComplexF64}(I, 2, 2))
    vectors=[0 1 -1 0 0 0 0; 0 0 0 1 -1 0 0; 0 0 0 0 0 1 -1]
    h=zeros(ComplexF64, 2, 2, 7);
    a=zeros(ComplexF64, 2, 2, 3, 7)
    h[:, :, 1]=1.7 * F.SZ
    sine=(F.SX, F.SY, 0.13 * F.SX+0.19 * F.SZ)
    cosine=(0.17 * F.SY+0.31 * F.SZ, 0.23 * F.SZ, zeros(ComplexF64, 2, 2))
    a[:, :, 1, 1]=0.09 * F.SX;
    a[:, :, 3, 1]=0.03 * F.SZ
    a[:, :, 1, 4]=0.07 * F.SZ/(2im);
    a[:, :, 1, 5]=-0.07 * F.SZ/(2im)
    a[:, :, 2, 2]=0.025 * F.SY;
    a[:, :, 2, 3]=0.025 * F.SY
    a[:, :, 2, 6]=0.04 * F.SX/(2im);
    a[:, :, 2, 7]=-0.04 * F.SX/(2im)
    a[:, :, 3, 4]=0.01 * F.SY;
    a[:, :, 3, 5]=0.01 * F.SY
    for axis in 1:3
        h[:, :, 2axis]=cosine[axis]/2+sine[axis]/(2im)
        h[:, :, 2axis + 1]=cosine[axis]/2-sine[axis]/(2im)
    end
    position=similar(a)
    for r in 1:7, axis in 1:3
        position[:, :, axis, r]=sum(lattice[j, axis]*a[:, :, j, r] for j in 1:3)
        position[:, :, axis, r]=rotation'*position[:, :, axis, r]*rotation
    end
    for r in 1:7
        h[:, :, r]=rotation'*h[:, :, r]*rotation
    end
    C.TightBindingModel(lattice, 2, 7, ones(Int, 7), vectors, h, position)
end

function local_values(model, k, convention; phases = false, gap_tolerance = 1e-8)
    request=M.MatrixElementRequest(
        M.BERRY_CONNECTION,
        M.WANNIER_CURVATURE;
        denominator_regularization = 0.0,
        spatial_dimension = 3,
    )
    plan=M.compile_matrix_plan(
        request;
        source_gauge_required = false,
        wannier_center_convention = convention,
    )
    worker=M.MatrixElementWorkspace(model, plan);
    M.prepare_real_space!(worker, model)
    fractional=transpose(C.reciprocal_lattice(model.lattice))\k
    M.compute_kpoint!(worker, model, fractional)
    if phases
        worker.data.spectrum.eigenvectors .*= reshape(exp.(im .* [0.37, -0.83]), 1, 2)
        # KPointSpectrum owns both matrices; transform_to_hamiltonian_gauge!
        # consumes the stored adjoint rather than constructing a new one.
        worker.data.spectrum.eigenvectors_adjoint .= worker.data.spectrum.eigenvectors'
        @test worker.data.spectrum.eigenvectors_adjoint*worker.data.spectrum.eigenvectors ≈
              Matrix{ComplexF64}(I, 2, 2)
    end
    jets=M.OrthogonalGeometryJets(2, M.OrthogonalGeometryDerivativePlan(COMPONENTS))
    derivatives=M.OrthogonalBandDerivativeWorkspace(jets)
    M.prepare_orthogonal_geometry_jets!(jets, worker, model)
    M.prepare_orthogonal_band_derivatives!(derivatives, worker.data.spectrum; gap_tolerance)
    output=zeros(2, length(COMPONENTS))
    for (channel, component) in enumerate(COMPONENTS)
        partitions=length(component)==3 ?
                   R.orthogonal_bcd_partition_matrices!(derivatives, component) :
                   R.orthogonal_bcq_partition_matrices!(derivatives, component)
        for band in 1:2
            output[band, channel]=R.orthogonal_geometry_partition_diagonal(partitions, band).total
        end
    end
    output
end

@testset "exact TB Fourier, skew Cartesian axes, centers, U1 and spinor basis covariance" begin
    k=[0.173, 0.287, 0.319]
    rotation=exp(im * 0.31 * F.SX)*exp(im * 0.27 * F.SY)
    for lattice in (Matrix{Float64}(I, 3, 3), [1.2 0.2 0.1; 0.0 1.4 0.3; 0.1 0.05 1.1])
        expected=zeros(2, length(COMPONENTS))
        for band in 1:2, (channel, component) in enumerate(COMPONENTS)
            a, b=component[1:2];
            sign=band==1 ? -1 : 1
            curvature=x->sum(
                lattice[i, a]*lattice[j, b]*F.closed_curvature(lattice*x, i, j, sign) for
                i in 1:3, j in 1:3
            )
            expected[
                band,
                channel,
            ]=length(component)==3 ? ForwardDiff.gradient(curvature, k)[component[3]] :
              ForwardDiff.hessian(curvature, k)[component[3], component[4]]
        end
        for convention in (C.CONVENTION_II, C.CONVENTION_I)
            actual=local_values(model(lattice), k, convention)
            @test actual ≈ expected atol=3e-10 rtol=3e-9
            @test local_values(model(lattice), k, convention; phases = true) ≈ expected atol=3e-10 rtol=3e-9
            # This is a full two-component complex spinor basis rotation; each
            # explicit eigenstate remains counted once, with no scalar factor 2.
            @test local_values(model(lattice; rotation), k, convention) ≈ expected atol=3e-10 rtol=3e-9
        end
    end
end

@testset "spectral domain rejects small gaps and invalid threshold" begin
    @test_throws ArgumentError M.geometry_isolated_spectrum_minimum_gap([0.0, 1e-5], 0.002)
    @test_throws ArgumentError M.geometry_isolated_spectrum_minimum_gap([0.0, 0.0], 0.0)
    @test_throws ArgumentError M.geometry_isolated_spectrum_minimum_gap([0.0, NaN], 0.002)
    @test_throws ArgumentError M.geometry_isolated_spectrum_minimum_gap([0.0, 1.0], -1.0)
    tiny=model(Matrix{Float64}(I, 3, 3));
    tiny.hamiltonian_r .*= 1e-5
    @test_throws ArgumentError local_values(
        tiny,
        [0.173, 0.287, 0.319],
        C.CONVENTION_II;
        gap_tolerance = 0.002,
    )
end
end
