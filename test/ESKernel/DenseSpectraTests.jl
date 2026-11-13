const DS = ESKernel.DenseSpectra

@testset "Hermitian spectra and metric invariants" begin
    h = ComplexF64[2 im; -im 2]
    original = copy(h)
    result = DS.hermitian_spectrum(h)
    @test result.values ≈ [1.0, 3.0]
    @test norm(h*result.vectors-result.vectors*Diagonal(result.values)) < 1e-13
    @test DS.hermitian_eigenvalues(h) == eigvals(Hermitian(h, :U))
    @test h == original
    @test DS.hermitian_defect(h) == 0.0

    # A deliberately inconsistent unused triangle must not change the selected one.
    upper = ComplexF64[2 im; 90 2]
    @test DS.hermitian_spectrum(upper; uplo = :U).values == result.values
    @test DS.hermitian_defect(upper) > 1

    # Two exactly repeated eigenvalues test an invariant subspace, not chosen vectors.
    s = Matrix(Diagonal(ComplexF64[1, 2, 4]))
    g = Matrix(Diagonal(ComplexF64[1, 2, 12]))
    saved_h, saved_s = copy(g), copy(s)
    answer = DS.generalized_hermitian_spectrum(g, s)
    @test answer.values ≈ [1.0, 1.0, 3.0]
    @test DS.generalized_eigen_residual(g, s, answer.values, answer.vectors, Val(:products)) < 1e-13
    @test DS.generalized_eigen_residual(g, s, answer.values, answer.vectors, Val(:operators)) <
          1e-13
    @test DS.metric_orthogonality(s, answer.vectors, Val(:maximum)) < 1e-13
    @test DS.metric_orthogonality(s, answer.vectors, Val(:frobenius)) < 1e-13
    selected = answer.vectors[:, 1:2]
    expected_projector = Matrix(Diagonal(ComplexF64[1, 1, 0]))
    @test selected*selected'*s ≈ expected_projector atol=1e-13
    @test g == saved_h && s == saved_s
    @test_throws PosDefException DS.generalized_hermitian_spectrum(
        g,
        Diagonal(ComplexF64[1, -1, 4]),
    )

    zero_h = zeros(ComplexF64, 2, 2)
    identity = Matrix{ComplexF64}(I, 2, 2)
    @test DS.generalized_eigen_residual(zero_h, identity, zeros(2), identity, Val(:operators)) ==
          0.0
    perturbed = copy(answer.vectors)
    # Scale a whole metric-normalized vector: a degenerate basis may have zero entries.
    perturbed[:, 1] .*= 2
    @test DS.metric_orthogonality(s, perturbed, Val(:maximum)) > 1
end
