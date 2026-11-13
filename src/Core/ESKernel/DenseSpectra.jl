module DenseSpectra

using LinearAlgebra

export hermitian_spectrum, hermitian_eigenvalues, generalized_hermitian_spectrum
export generalized_eigen_residual, metric_orthogonality, hermitian_defect

"""Return the standard LAPACK eigensystem using the explicitly selected triangle.

Inputs are not overwritten. No phase fixing, degeneracy grouping, clipping,
normalization or physical acceptance threshold is imposed by this operation.
The caller validates its raw operator representation before selecting a triangle.
"""
function hermitian_spectrum(matrix::AbstractMatrix; uplo::Symbol = :U)
    eigen(Hermitian(matrix, uplo))
end

"""Return only Hermitian eigenvalues; do not allocate or compute eigenvectors.

This preserves metric-only callers which inspect positivity or conditioning
before a separate generalized solve. No spectrum regularization is performed.
"""
function hermitian_eigenvalues(matrix::AbstractMatrix; uplo::Symbol = :U)
    eigvals(Hermitian(matrix, uplo))
end

"""Solve H C = S C Diagonal(E) using the supplied Hermitian triangles.

The native generalized Hermitian solver requires positive-definite S. H and S
are not overwritten; native failures propagate. Spin blocks, phase choices,
raw-operator checks and any scientific qualification remain caller responsibilities.
"""
function generalized_hermitian_spectrum(
    hamiltonian::AbstractMatrix,
    overlap::AbstractMatrix;
    uplo::Symbol = :U,
)
    eigen(Hermitian(hamiltonian, uplo), Hermitian(overlap, uplo))
end

"""Return max(abs, A - A†) without repairing or mutating the raw matrix."""
function hermitian_defect(matrix::AbstractMatrix)
    maximum(abs, matrix - adjoint(matrix))
end

"""Return the product-norm generalized residual used by the dense LO caller.

The denominator is max(eps(Float64), norm(H*C), norm(S*C*Diagonal(E))).
The original product association and normalization are retained. This is a
diagnostic value only, with no convergence decision, metric repair or k weight.
"""
function generalized_eigen_residual(h, s, values, c, ::Val{:products})
    norm(h*c-s*c*Diagonal(values))/max(eps(Float64), norm(h*c), norm(s*c*Diagonal(values)))
end

"""Return the operator-norm generalized residual used by the WN caller.

The denominator is (norm(H)+norm(S)*maximum(abs,E))*norm(C). A zero
denominator returns zero for a zero numerator and Inf otherwise. All matrix
products preserve the original order; no phase or band transformation is made.
"""
function generalized_eigen_residual(h, s, values, c, ::Val{:operators})
    scale = (norm(h) + norm(s) * maximum(abs, values)) * norm(c)
    numerator = norm(h * c - s * c * Diagonal(values))
    iszero(scale) ? (iszero(numerator) ? 0.0 : Inf) : numerator / scale
end

"""Return the maximum metric defect in the dense ComplexF64 coefficient basis.

This retains the LO expression C† S C - Matrix(I), without changing C or S.
The caller supplies all normalization conventions and acceptance thresholds.
"""
function metric_orthogonality(s, c, ::Val{:maximum})
    maximum(abs, adjoint(c)*s*c-Matrix{ComplexF64}(I, size(c, 2), size(c, 2)))
end

"""Return the Frobenius norm of C† S C-I in the supplied coefficient basis.

This retains the WN expression and does not insert weights or renormalize C.
It does not assert validity of the supplied metric or physical operator.
"""
function metric_orthogonality(s, c, ::Val{:frobenius})
    norm(c' * s * c - I)
end

end
