module BerryGeometryMultibandUnit
using Test, LinearAlgebra, WannierNLQG
const F=Main.OrthogonalGeometryAnalyticUnit
const G=Main.BerryGeometryBackendRuntimeUnit
function hamiltonian(k, p)
    h=zeros(promote_type(ComplexF64, eltype(k)), 3, 3)
    h[1:2, 1:2]=F.hamiltonian(k, nothing)
    h[3, 3]=5+0.2cos(k[1])
    h[1, 3]=0.3sin(k[1])+im*0.2cos(k[2]);
    h[3, 1]=conj(h[1, 3])
    h[2, 3]=0.2cos(k[3])+im*0.1sin(k[2]);
    h[3, 2]=conj(h[2, 3])
    h
end
function position(k, p)
    a=zeros(promote_type(ComplexF64, eltype(k)), 3, 3, 3)
    a[1:2, 1:2, :]=F.position(k, nothing)
    for axis in 1:3
        a[1, 3, axis]=0.02sin(k[axis])+im*0.01cos(k[axis]);
        a[3, 1, axis]=conj(a[1, 3, axis])
        a[2, 3, axis]=0.03cos(k[axis]);
        a[3, 2, axis]=a[2, 3, axis]
    end
    a
end
function configuration(quantity, numerics)
    input=AnalyticKInput(;
        hamiltonian,
        num_orbitals = 3,
        lattice = Matrix{Float64}(I, 3, 3),
        basis = :explicit,
        operators = (; position),
        periodic = false,
        derivative_method = :automatic,
        source_file = @__FILE__
    )
    TaskConfig(
        model = input,
        sampling = KSlice(
            k_mesh = (1, 1),
            spatial_dimension = 3,
            origin = Tuple([0.173, 0.287, 0.319]/(2pi)),
            vector_1 = (0.01, 0.0, 0.0),
            vector_2 = (0.0, 0.01, 0.0),
        ),
        tasks = [
            TaskSpec(
                id = "three_band",
                quantity = quantity,
                method = "Conventional",
                physics = GeometryParameters(),
                numerics = numerics,
                observable = KSliceSelection(
                    component = quantity=="BCDK" ? TensorComponent(1, 2, 1) :
                                TensorComponent(1, 2, 1, 2),
                    bands = Subspace([1]),
                ),
            ),
        ],
        execution = ExecutionOptions(fourier_backend = "direct"),
        output = OutputOptions(
            output_root = mktempdir(),
            progress_enabled = false,
            response_output_digits = 16,
        ),
    )
end
@testset "coupled three-band full intermediate sums versus retained FD h ladder" begin
    for quantity in ("BCDK", "BCQK")
        analytic=configuration(quantity, Numerics(derivative_backend = :analytic))
        value=G.first_value(Base.invokelatest(WannierNLQG.run, analytic); mesh = (1, 1))
        @test abs(value)>1e-6
        errors=Float64[]
        for step in (0.004, 0.002, 0.001)
            fd=configuration(
                quantity,
                Numerics(
                    derivative_backend = :finite_difference,
                    finite_difference_step = step,
                    denominator_regularization = 1e-8,
                ),
            )
            trial=G.first_value(Base.invokelatest(WannierNLQG.run, fd); mesh = (1, 1))
            push!(errors, abs(trial-value))
        end
        @test errors[2]<0.35errors[1] || errors[2]<1e-7
        @test errors[3]<0.35errors[2] || errors[3]<1e-7
        @test errors[3]<(quantity=="BCDK" ? 1e-6 : 1e-5)
    end
end
end
