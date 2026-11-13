# Real public in-memory projection covers the observed rank-zero/rank-one
# covariance callbacks and broadcast trees in their defining core cache owner.
# Two Wannier functions, one R block, identity and spinless time reversal need
# no optional backend, native-file output, random input, or symmetry detector.
@setup_workload let
    identity_int = Matrix{Int}(LinearAlgebra.I, 3, 3)
    identity_cart = Matrix{Float64}(LinearAlgebra.I, 3, 3)
    operations = [
        SymmetryFoundation.SymmetryOperation(identity_int, zeros(3), identity_cart),
        SymmetryFoundation.SymmetryOperation(identity_int, zeros(3), identity_cart, true),
    ]
    representations = repeat(reshape(Matrix{ComplexF64}(LinearAlgebra.I, 2, 2), 2, 2, 1), 1, 1, 2)
    plan = SymmetryFoundation.WannierSymmetryPlan(operations, representations, zeros(Int, 3, 2, 2))
    context = SymmetryFoundation.RealSpaceProjectionContext(plan)
    hamiltonian = ComplexF64[1.0 0.2+0.1im; 0.2-0.1im 2.0]
    position = reshape(ComplexF64.(1:12) ./ 20, 2, 2, 3, 1)
    operators = (
        Core.RealSpaceOperator(
            Core.RealSpaceOperatorSymmetrySpec(Core.REAL_SPACE_HAMILTONIAN, 0, 1, 1),
            zeros(Int, 3, 1),
            reshape(hamiltonian, 2, 2, 1),
        ),
        Core.RealSpaceOperator(
            Core.RealSpaceOperatorSymmetrySpec(Core.REAL_SPACE_POSITION, 1, -1, 1),
            zeros(Int, 3, 1),
            position,
        ),
    )
    @compile_workload begin
        _first_use_require_serial()
        for operator in operators
            @assert isfinite(
                SymmetryFoundation.maximum_real_space_covariance_error(operator, context),
            )
            result = SymmetryFoundation.symmetrize_real_space_operator(operator, context)
            @assert all(isfinite, result.operator.data)
            @assert SymmetryFoundation.maximum_real_space_covariance_error(
                result.operator,
                context,
            ) <= 1e-12
        end
        @assert !MPI.Initialized()
        @assert Runtime.ACTIVE_PROGRESS[] === nothing
    end
end
