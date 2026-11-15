module BerryGeometryBackendRuntimeUnit
using Test, LinearAlgebra, ForwardDiff, WannierNLQG
const C=WannierNLQG.Core
const M=WannierNLQG.MatrixElements
const R=WannierNLQG.Runtime
const F=Main.OrthogonalGeometryAnalyticUnit
function input_model(; bounds = nothing)
    AnalyticKInput(
        hamiltonian = F.hamiltonian,
        num_orbitals = 2,
        lattice = Matrix{Float64}(I, 3, 3),
        basis = :explicit,
        operators = (position = F.position,),
        periodic = false,
        derivative_method = :automatic,
        evaluation_bounds = bounds,
        source_file = joinpath(@__DIR__, "orthogonal_geometry_analytic_unit.jl"),
    )
end
function configuration(
    quantity;
    numerics = Numerics(),
    backend = "direct",
    bands = BandSelection(groups = [[1]]),
    bounds = nothing,
    mesh = (2, 2),
)
    TaskConfig(
        model = input_model(; bounds),
        sampling = KSlice(
            k_mesh = mesh,
            spatial_dimension = 3,
            origin = Tuple([0.173, 0.287, 0.319]/(2pi)),
            vector_1 = (0.002, 0.0, 0.0),
            vector_2 = (0.0, 0.002, 0.0),
        ),
        tasks = [
            TaskSpec(
                id = "geometry",
                quantity = quantity,
                method = "Conventional",
                physics = GeometryParameters(),
                numerics = numerics,
                observable = KSliceSelection(
                    component = quantity=="BCDK" ? TensorComponent(1, 2, 1) :
                                TensorComponent(1, 2, 1, 2),
                    bands = bands,
                ),
            ),
        ],
        execution = ExecutionOptions(fourier_backend = backend),
        output = OutputOptions(
            output_root = mktempdir(),
            progress_enabled = false,
            response_output_digits = 16,
        ),
    )
end
function first_value(result; mesh = (2, 2))
    file=only(filter(path->endswith(path, ".dat"), result.outputs))
    rows=[
        parse.(Float64, split(line)) for
        line in eachline(file) if !isempty(strip(line)) && !startswith(strip(line), "#")
    ]
    @test length(rows)==mesh[1] && all(row->length(row)==mesh[2], rows)
    return first(first(rows))
end
@testset "explicit analytic admission and unregularized FD defaults" begin
    @test_throws ArgumentError M.optical_momentum_basis(C.AnalyticKModel(input_model()))
    legacy=configuration("BCDK")
    task=only(legacy.tasks)
    effective=R.compile_task_config(legacy, task)
    @test effective.derivative_backend==:finite_difference
    @test !effective.derivative_backend_was_explicit
    @test effective.denominator_regularization==0.0
    @test effective.finite_difference_step==0.0001
    positive=configuration("BCDK"; numerics = Numerics(denominator_regularization = 0.001))
    positive_effective=R.compile_task_config(positive, only(positive.tasks))
    @test positive_effective.derivative_backend==:finite_difference
    @test positive_effective.denominator_regularization==0.001
    analytic=configuration("BCDK"; numerics = Numerics(derivative_backend = :analytic))
    task=only(analytic.tasks)
    effective=R.compile_task_config(analytic, task)
    @test effective.derivative_backend==:analytic
    @test effective.derivative_backend_was_explicit
    @test effective.denominator_regularization==0
    explicit_zero=configuration(
        "BCDK";
        numerics = Numerics(derivative_backend = :analytic, denominator_regularization = 0.0),
    )
    @test R.compile_task_config(explicit_zero, only(explicit_zero.tasks)).denominator_regularization==0
    summary=R.task_parameter_summary(analytic, task)
    @test summary.numerics.derivative_backend==:analytic
    @test !haskey(summary.numerics, :finite_difference_step)
    @test haskey(summary.numerics, :degeneracy_threshold)
    spec=only(R.normalize_task_specs(effective))
    @test R.fourier_task_offset_signatures(effective, spec)==Set([((0, 0, 0), 0)])
    @test R.bundle_matrix_element_plan(
        [spec],
        effective,
        collect(effective.tensor_indices),
    ).geometry_derivatives!==nothing
    for controls in (
        Numerics(derivative_backend = :auto),
        Numerics(derivative_backend = :analytic, finite_difference_step = 0.001),
        Numerics(derivative_backend = :analytic, denominator_regularization = 0.001),
    )
        bad=configuration("BCDK"; numerics = controls)
        @test_throws ArgumentError R.compile_task_config(bad, only(bad.tasks))
    end
    mixed=configuration(
        "BCDK";
        numerics = Numerics(derivative_backend = :analytic),
        backend = "mixed",
    )
    @test_throws ArgumentError R.compile_task_config(mixed, only(mixed.tasks))
end
@testset "actual public central-jet path, metadata and FD h convergence" begin
    k=[0.173, 0.287, 0.319]
    # A single actual k in a domain narrower than the retained FD default.
    # The source domain check would reject any legacy +/-h response stencil.
    narrow=configuration(
        "BCQK";
        numerics = Numerics(derivative_backend = :analytic),
        mesh = (1, 1),
        bounds = (Tuple(k .- 1e-9), Tuple(k .+ 1e-9)),
    )
    narrow_value=first_value(Base.invokelatest(WannierNLQG.run, narrow); mesh = (1, 1))
    @test narrow_value ≈ ForwardDiff.hessian(x->F.closed_curvature(x, 1, 2, -1), k)[1, 2] atol=2e-10 rtol=2e-9
    for quantity in ("BCDK", "BCQK")
        oracle=x->F.closed_curvature(x, 1, 2, -1)
        expected=quantity=="BCDK" ? ForwardDiff.gradient(oracle, k)[1] :
                 ForwardDiff.hessian(oracle, k)[1, 2]
        cfg=configuration(quantity; numerics = Numerics(derivative_backend = :analytic))
        result=Base.invokelatest(WannierNLQG.run, cfg)
        actual=first_value(result)
        @test actual ≈ expected atol=2e-10 rtol=2e-9
        metadata=read(joinpath(cfg.output.output_root, "geometry", "metadata.txt"), String)
        @test occursin("derivative_backend_requested", metadata)
        @test occursin("derivative_backend_effective", metadata)
        @test occursin("not applicable (analytic derivative backend)", metadata)
        @test occursin("analytic_geometry_minimum_gap_ev", metadata)
        errors=Float64[]
        for h in (0.004, 0.002, 0.001)
            fd=configuration(
                quantity;
                numerics = Numerics(
                    derivative_backend = :finite_difference,
                    finite_difference_step = h,
                    denominator_regularization = 1e-8,
                ),
            )
            value=first_value(Base.invokelatest(WannierNLQG.run, fd))
            push!(errors, abs(value-expected))
        end
        @test errors[2]<=0.35errors[1] || errors[2]<1e-8
        @test errors[3]<=0.35errors[2] || errors[3]<1e-8
    end
end
end
