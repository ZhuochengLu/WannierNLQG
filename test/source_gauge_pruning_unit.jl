using Random

const SOURCE_GAUGE_ME = WannierNLQG.MatrixElements
const SOURCE_GAUGE_RUNTIME = WannierNLQG.Runtime

function source_gauge_test_config(tasks; photon_momentum = (0.0, 0.0, 0.0))
    return WannierNLQG.Runtime.EffectiveTaskConfig(
        fourier_backend = "direct",
        tasks = tasks,
        photon_momentum = photon_momentum,
        photon_energies = [0.2],
        k_mesh = (2, 2),
        spatial_dimension = 2,
        tensor_indices = (1, 1, 1),
    )
end

function source_gauge_bundle_plan(tasks; photon_momentum = (0.0, 0.0, 0.0))
    cfg = source_gauge_test_config(tasks; photon_momentum)
    specs = SOURCE_GAUGE_RUNTIME.normalize_task_specs(cfg)
    return SOURCE_GAUGE_RUNTIME.bundle_matrix_element_plan(specs, cfg)
end

function bitwise_equal(left, right)
    return reinterpret(UInt64, vec(left)) == reinterpret(UInt64, vec(right))
end

@testset "source-gauge requirement follows real bundle consumers" begin
    pure_conventional = source_gauge_bundle_plan([
        ("SC", "Conventional", "Integral"),
        ("IC", "Conventional", "Integral"),
    ])
    @test !pure_conventional.source_gauge_required

    pdic = source_gauge_bundle_plan(
        [("PDIC", "Conventional", "Integral")];
        photon_momentum = (0.01, 0.0, 0.0),
    )
    @test pdic.source_gauge_required

    geometric = source_gauge_bundle_plan([("SC", "Geometric_Loop", "Integral")])
    @test geometric.source_gauge_required

    wilson = source_gauge_bundle_plan([("SC", "Wilson_Loop", "Integral")])
    @test wilson.source_gauge_required

    mixed = source_gauge_bundle_plan([
        ("SC", "Conventional", "Integral"),
        ("SC", "Geometric_Loop", "Integral"),
    ])
    @test mixed.source_gauge_required

    execution_source =
        read(joinpath(ROOT, "src", "Runtime", "Setup", "FourierExecutionPlan.jl"), String)
    @test occursin("fourier_task_offset_graph(cfg, spec, union_plan)", execution_source)
end

@testset "source-gauge pruning keeps arrays and public matrices exact" begin
    Random.seed!(0x50a7ce)
    num_orbitals = 3
    num_r_vectors = 5
    model = WannierNLQG.Core.TightBindingModel(
        Matrix{Float64}(I, 3, 3),
        num_orbitals,
        num_r_vectors,
        ones(Int, num_r_vectors),
        rand(-2:2, 3, num_r_vectors),
        randn(ComplexF64, num_orbitals, num_orbitals, num_r_vectors),
        randn(ComplexF64, num_orbitals, num_orbitals, 3, num_r_vectors),
    )
    request = SOURCE_GAUGE_ME.MatrixElementRequest(
        SOURCE_GAUGE_ME.VELOCITY_VERTICES;
        spatial_dimension = 2,
    )
    retained_plan = SOURCE_GAUGE_ME.compile_matrix_plan(request)
    pruned_plan = SOURCE_GAUGE_ME.compile_matrix_plan(request; source_gauge_required = false)
    @test retained_plan.source_gauge_required
    @test !pruned_plan.source_gauge_required

    retained = SOURCE_GAUGE_ME.MatrixElementWorkspace(model, retained_plan)
    pruned = SOURCE_GAUGE_ME.MatrixElementWorkspace(model, pruned_plan)
    SOURCE_GAUGE_ME.prepare_real_space!(retained, model)
    SOURCE_GAUGE_ME.prepare_real_space!(pruned, model)

    sentinel = ComplexF64(7.0, 11.0)
    for workspace in (retained, pruned)
        fill!(workspace.data.hamiltonian.source_gauge_derivatives, sentinel)
        fill!(workspace.data.position.source_gauge_berry_connection, sentinel)
        fill!(workspace.data.position.source_gauge_velocity_vertices, sentinel)
    end
    kpoint = [0.137, -0.219, 0.071]
    SOURCE_GAUGE_ME.compute_kpoint!(retained, model, kpoint)
    SOURCE_GAUGE_ME.compute_kpoint!(pruned, model, kpoint)

    @test !pruned.plan.source_gauge_required
    @test all(==(sentinel), pruned.data.hamiltonian.source_gauge_derivatives)
    @test all(==(sentinel), pruned.data.position.source_gauge_berry_connection)
    @test all(==(sentinel), pruned.data.position.source_gauge_velocity_vertices)
    @test !all(==(sentinel), retained.data.hamiltonian.source_gauge_derivatives)
    @test !all(==(sentinel), retained.data.position.source_gauge_berry_connection)
    @test !all(==(sentinel), retained.data.position.source_gauge_velocity_vertices)

    @test bitwise_equal(retained.data.hamiltonian.derivatives, pruned.data.hamiltonian.derivatives)
    @test bitwise_equal(
        retained.data.position.berry_connection,
        pruned.data.position.berry_connection,
    )
    @test bitwise_equal(
        retained.data.position.velocity_vertices,
        pruned.data.position.velocity_vertices,
    )
end
