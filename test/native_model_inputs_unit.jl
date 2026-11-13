module NativeModelInputTests
using WannierNLQG, LinearAlgebra, Test
import JSON3
const C=WannierNLQG.Core
const M=WannierNLQG.MatrixElements

@testset "Owned model captures and explicit invalidation" begin
    captured = ComplexF64[0.4 0.2; 0.2 -0.4]
    callback = let values = captured
        (k, parameters) -> values
    end
    original_parameters = (coefficient = [1.0],)
    owned = AnalyticKInput(
        hamiltonian = callback,
        num_orbitals = 2,
        lattice = Matrix{Float64}(I, 3, 3),
        basis = :fixed_orthonormal,
        parameters = original_parameters,
        source_file = @__FILE__,
    )
    generation = C.scientific_data_generation(owned)
    expected = copy(captured)
    captured[1, 1] = 9.0
    original_parameters.coefficient[1] = 7.0
    @test owned.hamiltonian(zeros(3), owned.parameters) == expected
    @test owned.parameters.coefficient == [1.0]
    @test C.scientific_data_generation(owned) == generation
    replacement = AnalyticKInput(
        hamiltonian = callback,
        num_orbitals = 2,
        lattice = Matrix{Float64}(I, 3, 3),
        basis = :fixed_orthonormal,
        parameters = original_parameters,
        source_file = @__FILE__,
    )
    @test C.scientific_data_generation(replacement) != generation
    model = C.AnalyticKModel(owned)
    plan = M.compile_matrix_plan(M.MatrixElementRequest(M.SPECTRUM; spatial_dimension = 2))
    workspace = M.prepare_real_space!(M.MatrixElementWorkspace(model, plan), model)
    M.compute_kpoint!(workspace, model, [0.125, 0.0, 0.0])
    C.invalidate_scientific_data!(owned)
    @test_throws ArgumentError C.scientific_data_generation(owned)
    @test_throws ArgumentError WannierNLQG.IO.write_native_model_definition(IOBuffer(), owned)
    @test_throws ArgumentError M.compute_kpoint!(workspace, model, [0.125, 0.0, 0.0])
    @test_throws ArgumentError M.prepare_real_space!(workspace, model)
    @test !isempty(C.scientific_data_generation(replacement))
end

@testset "Native runtime admission follows the owned input lifetime" begin
    R = WannierNLQG.Runtime
    mktempdir() do directory
        source = joinpath(directory, "declared-model-source")
        write(source, "accepted source observation")
        coefficients = ComplexF64[0.4 0.2; 0.2 -0.4]
        callback = let values = coefficients
            (k, parameters) -> values
        end
        make_input() = AnalyticKInput(
            hamiltonian = callback,
            num_orbitals = 2,
            lattice = Matrix{Float64}(I, 3, 3),
            basis = :fixed_orthonormal,
            source_file = source,
        )
        task = TaskSpec(
            id = "admission",
            quantity = "SC",
            method = "Conventional",
            physics = OpticalParameters(
                photon_energies = [0.2],
                fermi_energy = 0.0,
                temperature = 0.0,
            ),
            numerics = Numerics(broadening = 0.04),
            observable = FullTensor(),
        )
        make_public_config(input, output; tasks = [task], progress_enabled = false) = TaskConfig(
            model = input,
            sampling = BZMesh(k_mesh = (1, 1), spatial_dimension = 2),
            tasks = tasks,
            execution = ExecutionOptions(fourier_backend = "direct"),
            output = OutputOptions(
                output_root = output,
                system_name = "admitted",
                progress_enabled = progress_enabled,
            ),
        )
        make_config(input, output) = only(R.compile_task_configs(make_public_config(input, output)))
        input = make_input()
        cfg = make_config(input, joinpath(directory, "first"))
        ctx = R.prepare_run_context(cfg, R.validate_config(cfg))
        adopted = cfg.native_model_input
        @test R._native_input_owner(adopted) !== R._native_input_owner(input)
        @test ctx.native_admission.model_generation == C.scientific_data_generation(adopted)
        @test R._validate_native_input_admission(adopted, ctx.native_admission) === nothing
        @test_throws ArgumentError R._validate_native_input_admission(input, ctx.native_admission)
        @test R.load_native_runtime_sources(ctx, cfg).model.input === adopted
        @test_throws ArgumentError R._validate_native_input_admission(adopted, nothing)
        same_ctx = R.prepare_run_context(cfg, R.validate_config(cfg))
        @test same_ctx.native_admission == ctx.native_admission
        @test R.context_with_demand([ctx, same_ctx], ctx.operator_demand).native_admission ==
              ctx.native_admission
        replacement = make_input()
        other_cfg = make_config(replacement, joinpath(directory, "replacement"))
        other_ctx = R.prepare_run_context(other_cfg, R.validate_config(other_cfg))
        @test other_ctx.model_identity != ctx.model_identity
        @test other_ctx.native_admission != ctx.native_admission
        @test_throws ArgumentError R.load_native_runtime_sources(ctx, other_cfg)
        copied_cfg = make_config(deepcopy(input), joinpath(directory, "copied-owner"))
        @test_throws ArgumentError R.load_native_runtime_sources(ctx, copied_cfg)
        @test_throws ArgumentError R.context_with_demand([ctx, other_ctx], ctx.operator_demand)
        second_task = TaskSpec(
            id = "second",
            quantity = "IC",
            method = "Conventional",
            physics = task.physics,
            numerics = task.numerics,
            observable = FullTensor(),
        )
        shared = R.compile_task_configs(
            make_public_config(input, joinpath(directory, "shared"); tasks = [task, second_task]),
        )
        shared_contexts = [R.prepare_run_context(item, R.validate_config(item)) for item in shared]
        @test shared_contexts[1].native_admission == shared_contexts[2].native_admission
        @test R.context_with_demand(shared_contexts, R.combined_operator_demand(shared_contexts)).native_admission ==
              shared_contexts[1].native_admission
        progress_cfg = only(
            R.compile_task_configs(
                make_public_config(input, joinpath(directory, "progress"); progress_enabled = true),
            ),
        )
        progress_ctx = R.prepare_run_context(progress_cfg, R.validate_config(progress_cfg))
        @test progress_ctx.model_identity ==
              C.scientific_data_generation(progress_cfg.native_model_input)
        try
            R.progress_start!(progress_cfg, progress_ctx)
            @test R.ACTIVE_PROGRESS[].model_identity == progress_ctx.model_identity
            R.progress_system_summary!(
                R.load_native_runtime_sources(progress_ctx, progress_cfg).model,
            )
        finally
            R.progress_clear!()
        end
        events = [JSON3.read(line) for line in eachline(progress_ctx.progress_jsonl_path)]
        summary = only(filter(event -> event.event == "system_summary", events)).system_summary
        @test summary.model_identity == progress_ctx.model_identity
        @test !haskey(summary, :model_sha256)
        @test R.ACTIVE_PROGRESS[] === nothing
        write(source, "changed source observation")
        @test_throws ArgumentError R.load_native_runtime_sources(ctx, cfg)
        write(source, "accepted source observation")
        @test_throws ArgumentError R.load_native_runtime_sources(ctx, cfg)
        C.invalidate_scientific_data!(adopted)
        @test_throws ArgumentError R.load_native_runtime_sources(ctx, cfg)
        @test !isempty(C.scientific_data_generation(input))
    end
end

lat=Matrix{Float64}(I, 3, 3)
rv=[0 1 -1; 0 0 0; 0 0 0]
h=zeros(ComplexF64, 2, 2, 3);
h[:, :, 1]=[0.4 1.0; 1.0 -0.4];
h[:, :, 2]=[0.0 0.0; 0.7 0.0];
h[:, :, 3]=h[:, :, 2]'
tau=[0.0 0.3; 0.0 0.0; 0.0 0.0]
input=RealSpaceTBInput(
    lattice = lat,
    r_vectors = rv,
    hamiltonian_r = h,
    orbital_positions = tau,
    position_model = :point_orbitals,
)
fun(k, p)=[0.4 1+0.7*exp(-im*k[1]); 1+0.7*exp(im*k[1]) -0.4]
a=AnalyticKInput(
    hamiltonian = fun,
    num_orbitals = 2,
    lattice = lat,
    orbital_positions = tau,
    source_file = @__FILE__
)
@testset "Analytic derivatives" begin
    k=[0.7, 0.2, 0.1]
    for order in 1:3
        d=M.analytic_hamiltonian_derivative(a, k, order)
        @test d[1, 2, ntuple(_ -> 1, order)...] ≈ 0.7*(-im)^order*exp(-im*k[1]) atol=1e-11 rtol=1e-9
    end
end
@testset "Matrix parity" begin
    for convention in (C.CONVENTION_I, C.CONVENTION_II)
        plan=M.compile_matrix_plan(
            M.MatrixElementRequest(
                M.HAMILTONIAN_SECOND_DERIVATIVES,
                M.BERRY_CONNECTION,
                M.VELOCITY_VERTICES;
                spatial_dimension = 2,
            );
            wannier_center_convention = convention,
        )
        w1=M.MatrixElementWorkspace(input.model, plan);
        w2=M.MatrixElementWorkspace(C.AnalyticKModel(a), plan)
        M.prepare_real_space!(w1, input.model);
        M.prepare_real_space!(w2, C.AnalyticKModel(a))
        M.compute_kpoint!(w1, input.model, [0.13, 0.2, 0.0]);
        M.compute_kpoint!(w2, C.AnalyticKModel(a), [0.13, 0.2, 0.0])
        @test w1.data.spectrum.energies ≈ w2.data.spectrum.energies atol=1e-11 rtol=1e-9
        @test w1.data.hamiltonian.derivatives ≈ w2.data.hamiltonian.derivatives atol=1e-11 rtol=1e-9
        @test w1.data.hamiltonian.second_derivatives ≈ w2.data.hamiltonian.second_derivatives atol=1e-11 rtol=1e-9
        @test w1.data.position.berry_connection ≈ w2.data.position.berry_connection atol=1e-11 rtol=1e-9
    end
end

@testset "Invalid native declarations" begin
    @test_throws ArgumentError RealSpaceTBInput(
        lattice = lat,
        r_vectors = rv[:, 1:2],
        hamiltonian_r = h[:, :, 1:2],
        orbital_positions = tau,
        position_model = :point_orbitals,
    )
    @test_throws ArgumentError RealSpaceTBInput(lattice = lat, r_vectors = rv, hamiltonian_r = h)
    @test_throws ArgumentError AnalyticKInput(
        hamiltonian = fun,
        num_orbitals = 2,
        lattice = lat,
        orbital_positions = zeros(3, 2),
        derivative_method = :silent_fallback,
    )
    invalid=AnalyticKInput(
        hamiltonian = (k, p)->[1.0 1.0; 0.0 2.0],
        num_orbitals = 2,
        lattice = lat,
        orbital_positions = zeros(3, 2),
    )
    @test_throws ArgumentError M.analytic_hamiltonian(invalid, [0.0, 0.0, 0.0])
    nonfinite=AnalyticKInput(
        hamiltonian = (k, p)->[NaN 0.0; 0.0 2.0],
        num_orbitals = 2,
        lattice = lat,
        orbital_positions = zeros(3, 2),
    )
    @test_throws ArgumentError M.analytic_hamiltonian(nonfinite, [0.0, 0.0, 0.0])
    bounded=AnalyticKInput(
        hamiltonian = fun,
        num_orbitals = 2,
        lattice = lat,
        orbital_positions = zeros(3, 2),
        periodic = false,
        evaluation_bounds = ((-1.0, -1.0, -1.0), (1.0, 1.0, 1.0)),
    )
    @test_throws DomainError M.analytic_hamiltonian(bounded, [2.0, 0.0, 0.0])
    explicit=AnalyticKInput(
        hamiltonian = fun,
        num_orbitals = 2,
        lattice = lat,
        orbital_positions = zeros(3, 2),
        derivative_method = :explicit,
    )
    @test_throws ArgumentError M.analytic_hamiltonian_derivative(explicit, [0.2, 0.0, 0.0], 1)
    fd=AnalyticKInput(
        hamiltonian = fun,
        num_orbitals = 2,
        lattice = lat,
        orbital_positions = zeros(3, 2),
        derivative_method = :finite_difference,
    )
    @test M.analytic_hamiltonian_derivative(fd, [0.2, 0.0, 0.0], 1) ≈
          M.analytic_hamiltonian_derivative(a, [0.2, 0.0, 0.0], 1) atol=1e-8 rtol=1e-7
    @test_throws ArgumentError KRegion(lower = (0.0,), upper = (0.0,), k_mesh = (2,))
end

@testset "Massive Dirac analytic curvature" begin
    dirac(k, p)=[p k[1]-im*k[2]; k[1]+im*k[2] -p]
    input=AnalyticKInput(
        hamiltonian = dirac,
        num_orbitals = 2,
        lattice = lat,
        orbital_positions = zeros(3, 2),
        periodic = false,
        parameters = 0.7,
    )
    plan=M.compile_matrix_plan(
        M.MatrixElementRequest(
            M.BERRY_CONNECTION,
            M.WANNIER_CURVATURE;
            spatial_dimension = 2,
            denominator_regularization = 0.0,
        ),
    )
    model=C.AnalyticKModel(input);
    workspace=M.MatrixElementWorkspace(model, plan)
    M.prepare_real_space!(workspace, model)
    for k in ([0.2, 0.3, 0.0], [-0.4, 0.1, 0.0])
        fractional=C.reciprocal_cartesian_to_fractional(k, lat)
        M.compute_kpoint!(workspace, model, fractional)
        value=WannierNLQG.Responses.berry_curvature_component(workspace.data, 1, [1, 2], 2)
        expected=0.7/(2*(k[1]^2+k[2]^2+0.7^2)^1.5)
        @test value ≈ expected atol=1e-11 rtol=1e-9
    end
end

@testset "Fixed point-orbital contract" begin
    spin=zeros(ComplexF64, 2, 2, 3)
    spin[:, :, 1]=[0 1; 1 0]
    @test_throws ArgumentError AnalyticKInput(
        hamiltonian = fun,
        num_orbitals = 2,
        lattice = lat,
        orbital_positions = tau,
        operators = (spin = spin,),
    )
    @test_throws ArgumentError AnalyticKInput(
        hamiltonian = fun,
        num_orbitals = 2,
        lattice = lat,
        orbital_positions = tau,
        operators = (spin = (k, p)->spin,),
    )
    @test_throws UndefKeywordError AnalyticKInput(
        hamiltonian = fun,
        num_orbitals = 2,
        lattice = lat,
    )
    @test_throws ArgumentError AnalyticKInput(
        hamiltonian = fun,
        num_orbitals = 2,
        lattice = lat,
        orbital_positions = tau,
        basis = :explicit,
    )
    @test_throws ArgumentError RealSpaceTBInput(
        lattice = lat,
        r_vectors = rv,
        hamiltonian_r = h,
        orbital_positions = tau,
        position_model = :explicit,
        position_r = input.model.position_r,
    )
    for key in (:position, :overlap, :derivative_overlap, :spin_r, :spin_hamiltonian)
        @test_throws ArgumentError AnalyticKInput(
            hamiltonian = fun,
            num_orbitals = 2,
            lattice = lat,
            orbital_positions = tau,
            operators = NamedTuple{(key,)}((zeros(2, 2),)),
        )
    end
    local_input=AnalyticKInput(
        hamiltonian = fun,
        num_orbitals = 2,
        lattice = lat,
        orbital_positions = zeros(3, 2),
        operators = (spin = spin,),
    )
    @test local_input.operators.spin==spin
end

@testset "Derivative execution evidence" begin
    records=M.make_analytic_derivative_diagnostics()
    k=[0.2, 0.0, 0.0]
    M.analytic_hamiltonian_derivative(a, k, 1; diagnostics = records)
    merged=M.merge_analytic_derivative_diagnostics(records)
    @test merged[1].source=="FORWARDDIFF"
    @test !haskey(merged, 2) && !haskey(merged, 3)
    fd=AnalyticKInput(
        hamiltonian = fun,
        num_orbitals = 2,
        lattice = lat,
        orbital_positions = tau,
        derivative_method = :finite_difference,
    )
    M.analytic_hamiltonian_derivative(fd, k, 2; diagnostics = records)
    merged=M.merge_analytic_derivative_diagnostics(records)
    @test merged[2].source=="FINITE_DIFFERENCE" && merged[2].passed
    @test merged[2].step==fd.finite_difference_step
    @test merged[2].fine_error>=0
    @test M.merge_analytic_derivative_diagnostics(reverse(records))==merged
end

@testset "Mixed derivative sources and explicit failures" begin
    k=[0.2, 0.1, 0.0]
    first_derivative(k, p)=M.analytic_automatic_derivative(x->fun(x, p), k, 1)
    unused_third(k, p)=error("unused third derivative was evaluated")
    mixed=AnalyticKInput(
        hamiltonian = fun,
        num_orbitals = 2,
        lattice = lat,
        orbital_positions = tau,
        derivatives = (first_derivative, nothing, unused_third),
    )
    M.validate_analytic_model(mixed; max_order = 1)
    records=M.make_analytic_derivative_diagnostics()
    for order in 1:2
        M.analytic_hamiltonian_derivative(mixed, k, order; diagnostics = records)
    end
    merged=M.merge_analytic_derivative_diagnostics(records)
    @test merged[1].source=="EXPLICIT" && merged[2].source=="FORWARDDIFF"
    @test !haskey(merged, 3)
    oscillatory(k, p)=[sin(17k[1]) 1; 1 -sin(17k[1])]
    unstable=AnalyticKInput(
        hamiltonian = oscillatory,
        num_orbitals = 2,
        lattice = lat,
        orbital_positions = tau,
        periodic = false,
        derivative_method = :finite_difference,
        finite_difference_step = 0.2,
    )
    failed=M.make_analytic_derivative_diagnostics()
    @test_throws ArgumentError M.analytic_hamiltonian_derivative(
        unstable,
        k,
        1;
        diagnostics = failed,
    )
    failure=M.merge_analytic_derivative_diagnostics(failed)
    @test !failure[1].passed && failure[1].fine_error>0
end

@testset "Fixed-orbital spatial and antiunitary representations" begin
    centers=[0.2 0.8; 0.0 0.0; 0.0 0.0]
    constant(k, p)=ComplexF64[0 1; 1 0]
    model=AnalyticKInput(
        hamiltonian = constant,
        num_orbitals = 2,
        lattice = lat,
        orbital_positions = centers,
    )
    identity=PointOrbitalSymmetryOperation(
        rotation_fractional = Matrix{Int}(I, 3, 3),
        representation = Matrix{ComplexF64}(I, 2, 2),
    )
    inversion=PointOrbitalSymmetryOperation(
        rotation_fractional = -Matrix{Int}(I, 3, 3),
        representation = ComplexF64[0 1; 1 0],
    )
    geometry=M.point_orbital_symmetry_geometry(model, inversion)
    k=[0.31, 0.0, 0.0]
    @test M.point_orbital_sewing(inversion, geometry, k) ≈ exp(-im*k[1])*ComplexF64[0 1; 1 0]
    @test M.validate_point_orbital_covariance(
        model,
        [identity, inversion],
        [k];
        max_order = 2,
    ).status=="PASS"
    broken=PointOrbitalSymmetryOperation(
        rotation_fractional = -Matrix{Int}(I, 3, 3),
        representation = Matrix{ComplexF64}(I, 2, 2),
    )
    @test_throws ArgumentError M.validate_point_orbital_group(model, [identity, broken])
    @test_throws ArgumentError M.validate_point_orbital_covariance(a, [identity, inversion], [k])
end

@testset "Analytic centers preserve basis-specific required-keyword semantics" begin
    lattice = Matrix{Float64}(I, 3, 3)
    hamiltonian = (k, parameters) -> ComplexF64[0 0; 0 1]
    missing_centers = try
        AnalyticKInput(; hamiltonian, num_orbitals = 2, lattice)
        nothing
    catch exception
        exception
    end
    @test missing_centers isa UndefKeywordError
    @test missing_centers.var === :orbital_positions
    @test_throws ArgumentError AnalyticKInput(;
        hamiltonian,
        num_orbitals = 2,
        lattice,
        orbital_positions = nothing,
    )
    fixed = AnalyticKInput(;
        hamiltonian,
        num_orbitals = 2,
        lattice,
        basis = :fixed_orthonormal,
        source_file = @__FILE__
    )
    explicit = AnalyticKInput(;
        hamiltonian,
        num_orbitals = 2,
        lattice,
        basis = :fixed_orthonormal,
        orbital_positions = nothing,
        source_file = @__FILE__,
    )
    @test fixed.orbital_positions === nothing
    @test explicit.orbital_positions === nothing
    fixed_definition = IOBuffer()
    explicit_definition = IOBuffer()
    WannierNLQG.IO.write_native_model_definition(fixed_definition, fixed)
    WannierNLQG.IO.write_native_model_definition(explicit_definition, explicit)
    @test take!(fixed_definition) == take!(explicit_definition)
end
# Include the stream contract in the normal native-input test path.
include("native_model_definition_unit.jl")

end
