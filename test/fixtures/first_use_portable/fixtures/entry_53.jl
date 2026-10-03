using WannierNLQG, LinearAlgebra, JSON3, Test, SHA
const SF=WannierNLQG.SymmetryFoundation
const S=WannierNLQG.Symmetrization
identity=SF.SymmetryOperation(Matrix{Int}(I, 3, 3), zeros(3), Matrix{Float64}(I, 3, 3), false)
theta=SF.SymmetryOperation(Matrix{Int}(I, 3, 3), zeros(3), Matrix{Float64}(I, 3, 3), true)
plan=SF.WannierSymmetryPlan([identity, theta], ones(ComplexF64, 1, 1, 2), zeros(Int, 3, 1, 2))
@test Base.get_extension(WannierNLQG, :WannierNLQGSymmetryFoundationExt)===nothing
operator=S.RealSpaceOperator(
    S.RealSpaceOperatorSymmetrySpec(S.REAL_SPACE_HAMILTONIAN, 0, 1, 1),
    zeros(Int, 3, 1),
    reshape(ComplexF64[2 + 3im], 1, 1, 1),
)
covariance_residual=SF.maximum_real_space_covariance_error(operator, plan)
@test isfinite(covariance_residual) && covariance_residual==6
@test operator.data[1, 1, 1]==2+3im
