module OrthogonalGeometryAnalyticUnit
using Test, LinearAlgebra, ForwardDiff, WannierNLQG
const C=WannierNLQG.Core
const M=WannierNLQG.MatrixElements
const R=WannierNLQG.Responses
const SX=ComplexF64[0 1; 1 0]
const SY=ComplexF64[0 -im; im 0]
const SZ=ComplexF64[1 0; 0 -1]
const COMPONENTS=((1, 2, 1), (1, 2, 2), (2, 3, 1), (1, 2, 1, 1), (1, 2, 1, 2), (2, 3, 2, 3))

dvector(
    k,
)=[sin(k[1])+0.13sin(k[3]), sin(k[2])+0.17cos(k[1]), 1.7+0.31cos(k[1])+0.23cos(k[2])+0.19sin(k[3])]
hamiltonian(k, p)=dvector(k)[1]*SX+dvector(k)[2]*SY+dvector(k)[3]*SZ
function position(k, p)
    cat(
        0.07sin(k[2])*SZ+0.09SX,
        0.05cos(k[1])*SY+0.04sin(k[3])*SX,
        0.03SZ+0.02cos(k[2])*SY;
        dims = 3,
    )
end

# Independent two-band closed-projector curvature. No donor recurrence, band
# eigenvector, matrix-workspace curvature or finite differences enter this oracle.
function closed_curvature(k, a, b, sign)
    d=dvector(k)
    jac=ForwardDiff.jacobian(dvector, k)
    radius=norm(d)
    geometric=-sign*dot(d, cross(jac[:, a], jac[:, b]))/(2radius^3)
    projector(
        x,
    )=(
        Matrix{ComplexF64}(
            I,
            2,
            2,
        )+sign*(dvector(x)[1]*SX+dvector(x)[2]*SY+dvector(x)[3]*SZ)/norm(dvector(x))
    )/2
    # Differentiate only raw smooth matrices, not an eigendecomposition.
    derivative=M.analytic_automatic_derivative(projector, k, 1)
    connection=position(k, nothing)
    connection_derivative=M.analytic_automatic_derivative(x->position(x, nothing), k, 1)
    return geometric+real(
        tr(
            derivative[
                :,
                :,
                a,
            ]*connection[
                :,
                :,
                b,
            ]-derivative[
                :,
                :,
                b,
            ]*connection[
                :,
                :,
                a,
            ]+projector(k) * (connection_derivative[:, :, b, a]-connection_derivative[:, :, a, b]),
        ),
    )
end

@testset "component derivative closure is complete and bounded" begin
    plan=M.OrthogonalGeometryDerivativePlan(COMPONENTS)
    @test plan.maximum_order==3
    @test (3, 0, 0) in plan.hamiltonian_orders
    @test (2, (2, 1, 0)) in plan.position_orders
    @test (3, (1, 0, 0)) in plan.position_orders
    @test length(unique(plan.hamiltonian_orders))==length(plan.hamiltonian_orders)
    @test length(unique(plan.position_orders))==length(plan.position_orders)
    @test all(order->sum(order)<=3, plan.hamiltonian_orders)
    @test_throws ArgumentError M.OrthogonalGeometryDerivativePlan(())
    @test_throws ArgumentError M.OrthogonalGeometryDerivativePlan(((1, 4, 1),))
    @test_throws ArgumentError M.geometry_derivative_order(1, 2, 3, 1)
end

@testset "raw analytic sources reject silent finite differences" begin
    input=AnalyticKInput(
        hamiltonian = hamiltonian,
        num_orbitals = 2,
        lattice = Matrix{Float64}(I, 3, 3),
        basis = :explicit,
        operators = (position = position,),
        periodic = false,
        derivative_method = :automatic,
    )
    @test M.geometry_hamiltonian_derivative_source(input, 3)==:automatic_raw_operator
    @test M.geometry_position_derivative_source(input, 3)==:automatic_raw_operator
    fd=AnalyticKInput(
        hamiltonian = hamiltonian,
        num_orbitals = 2,
        lattice = Matrix{Float64}(I, 3, 3),
        basis = :explicit,
        operators = (position = position,),
        periodic = false,
        derivative_method = :finite_difference,
    )
    @test_throws ArgumentError M.geometry_hamiltonian_derivative_source(fd, 1)
    @test_throws ArgumentError M.geometry_position_derivative_source(fd, 1)
    @test_throws ArgumentError AnalyticKInput(
        hamiltonian = hamiltonian,
        num_orbitals = 2,
        lattice = Matrix{Float64}(I, 3, 3),
        basis = :explicit,
        operators = NamedTuple(),
        periodic = false,
    )
end

@testset "six-partition BCD and BCQ versus nonzero-connection closed oracle" begin
    input=AnalyticKInput(
        hamiltonian = hamiltonian,
        num_orbitals = 2,
        lattice = Matrix{Float64}(I, 3, 3),
        basis = :explicit,
        operators = (position = position,),
        periodic = false,
        derivative_method = :automatic,
    )
    model=C.AnalyticKModel(input)
    request=M.MatrixElementRequest(
        M.BERRY_CONNECTION,
        M.WANNIER_CURVATURE;
        denominator_regularization = 0.0,
        spatial_dimension = 3,
    )
    matrix_plan=M.compile_matrix_plan(request; source_gauge_required = false)
    worker=M.MatrixElementWorkspace(model, matrix_plan)
    M.prepare_real_space!(worker, model)
    jets=M.OrthogonalGeometryJets(2, M.OrthogonalGeometryDerivativePlan(COMPONENTS))
    derivatives=M.OrthogonalBandDerivativeWorkspace(jets)
    k=[0.173, 0.287, 0.319]
    fractional=transpose(C.reciprocal_lattice(model.lattice))\k
    M.compute_kpoint!(worker, model, fractional)
    diagonalizations=worker.counts.diagonalizations
    M.prepare_orthogonal_geometry_jets!(jets, worker, model)
    @test_throws ArgumentError M.validate_orthogonal_band_derivatives(derivatives)
    M.prepare_orthogonal_band_derivatives!(derivatives, worker.data.spectrum; gap_tolerance = 1e-8)
    @test M.validate_orthogonal_band_derivatives(derivatives) === nothing
    @test worker.counts.diagonalizations==diagonalizations
    for band in 1:2
        sign=band==1 ? -1 : 1
        for component in COMPONENTS
            a, b=component[1:2]
            oracle=x->closed_curvature(x, a, b, sign)
            expected=length(component)==3 ? ForwardDiff.gradient(oracle, k)[component[3]] :
                     ForwardDiff.hessian(oracle, k)[component[3], component[4]]
            partitions=length(component)==3 ?
                       R.orthogonal_bcd_partition_matrices!(derivatives, component) :
                       R.orthogonal_bcq_partition_matrices!(derivatives, component)
            actual=R.orthogonal_geometry_partition_diagonal(partitions, band)
            @test isfinite(expected) && abs(expected)>1e-7
            @test actual.total ≈ expected atol=2e-10 rtol=2e-9
            @test sum(actual.partitions) ≈ expected atol=2e-10 rtol=2e-9
        end
    end
    # Repreparing raw jets invalidates all downstream recurrence caches, including
    # same source generation/same k, without an additional eigendecomposition.
    M.prepare_orthogonal_geometry_jets!(jets, worker, model)
    @test_throws ArgumentError M.validate_orthogonal_band_derivatives(derivatives)
    @test_throws ArgumentError R.orthogonal_bcd_partition_matrices!(derivatives, (1, 2, 1))
    @test_throws ArgumentError R.orthogonal_bcq_partition_matrices!(derivatives, (1, 2, 1, 1))
    @test_throws ArgumentError M.orthogonal_band_first_derivative!(derivatives, 1)
    @test_throws ArgumentError M.orthogonal_band_second_derivative!(derivatives, 1, 1)
    @test_throws ArgumentError M.orthogonal_band_third_derivative!(derivatives, 1, 1, 1)
end
end
