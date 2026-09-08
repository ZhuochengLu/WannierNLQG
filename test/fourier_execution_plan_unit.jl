using Test
using LinearAlgebra

const FEP_RUNTIME = WannierNLQG.Runtime
const FEP_MATRIX = WannierNLQG.MatrixElements

function execution_plan_fixture(backend::String; nkdiv = nothing, nkfft = nothing)
    cfg = WannierNLQG.Runtime.EffectiveTaskConfig(
        tasks = [("SC", "Projector", "Integral")],
        k_mesh = (8, 8),
        fourier_backend = backend,
        NKdiv = nkdiv,
        NKFFT = nkfft,
        photon_energies = [0.2],
        spatial_dimension = 2,
        tensor_indices = (1, 1, 1),
    )
    specs = FEP_RUNTIME.validate_config(cfg)
    model = WannierNLQG.Core.TightBindingModel(
        Matrix{Float64}(I, 3, 3),
        2,
        3,
        ones(Int, 3),
        Int[-1 0 1; 0 0 0; 0 0 0],
        zeros(ComplexF64, 2, 2, 3),
        zeros(ComplexF64, 2, 2, 3, 3),
    )
    matrix_plan = FEP_RUNTIME.bundle_matrix_element_plan(specs, cfg)
    workspace = FEP_MATRIX.MatrixElementWorkspace(model, matrix_plan)
    builder =
        (requested_nkdiv, requested_nkfft) -> FEP_MATRIX.mixed_fourier_grid(
            model,
            cfg.k_mesh;
            nkdiv = requested_nkdiv,
            nkfft = requested_nkfft,
        )
    return cfg, specs, model, workspace, builder
end

@testset "Explicit Fourier execution plan" begin
    cfg, specs, model, workspace, builder = execution_plan_fixture("direct")
    direct = FEP_RUNTIME.build_fourier_execution_plan(cfg, specs, model, workspace, 2, 1, builder)
    @test direct isa FEP_RUNTIME.FourierExecutionPlan
    @test direct.backend == :direct
    @test direct.grid === nothing
    @test direct.estimated_memory_bytes == 0
    @test FEP_RUNTIME.build_fourier_execution_plan(
        cfg,
        specs,
        model,
        workspace,
        2,
        1,
        builder;
        rank_memory_limit_bytes = 0,
    ).backend == :direct

    cfg, specs, model, workspace, builder = execution_plan_fixture("auto")
    automatic_direct =
        FEP_RUNTIME.build_fourier_execution_plan(cfg, specs, model, workspace, 2, 1, builder)
    @test automatic_direct.backend == :direct
    @test automatic_direct.factor_source == :auto_direct_no_factors

    cfg, specs, model, workspace, builder = execution_plan_fixture("auto"; nkfft = (4, 4))
    automatic_mixed =
        FEP_RUNTIME.build_fourier_execution_plan(cfg, specs, model, workspace, 2, 1, builder)
    @test automatic_mixed.backend == :mixed
    @test automatic_mixed.factor_source == :auto_inferred_nkdiv

    cfg, specs, model, workspace, builder = execution_plan_fixture("mixed"; nkfft = (4, 4))
    mixed = FEP_RUNTIME.build_fourier_execution_plan(cfg, specs, model, workspace, 2, 1, builder)
    @test mixed.backend == :mixed
    @test mixed.grid.nkdiv == (2, 2, 1)
    @test mixed.grid.nkfft == (4, 4, 1)
    @test mixed.factor_source == :inferred_nkdiv
    @test mixed.estimated_memory_bytes > 0
    @test !isempty(mixed.union_offset_signatures)
    @test !isempty(mixed.union_group_offset_counts)
    @test sum(mixed.blocks_per_rank) == prod(mixed.grid.nkdiv)

    # Concurrent task budgets must not silently alter a task's Auto backend.
    for selected_backend in ("mixed", "auto")
        shared_cfg, shared_specs, shared_model, shared_workspace, shared_builder =
            execution_plan_fixture(selected_backend; nkfft = (4, 4))
        original = FEP_RUNTIME.build_fourier_execution_plan(
            shared_cfg,
            shared_specs,
            shared_model,
            shared_workspace,
            1,
            1,
            shared_builder,
        )
        @test original.backend == :mixed
        @test_throws ErrorException FEP_RUNTIME.build_fourier_execution_plan(
            shared_cfg,
            shared_specs,
            shared_model,
            shared_workspace,
            1,
            1,
            shared_builder;
            rank_memory_limit_bytes = original.estimated_memory_bytes - 1,
        )
        constrained = FEP_RUNTIME.build_fourier_execution_plan(
            shared_cfg,
            shared_specs,
            shared_model,
            shared_workspace,
            1,
            1,
            shared_builder;
            rank_memory_limit_bytes = original.estimated_memory_bytes,
        )
        @test constrained.backend == original.backend
        @test constrained.memory_limit_bytes == original.estimated_memory_bytes
    end

    symmetry_mixed = FEP_RUNTIME.build_fourier_execution_plan(
        cfg,
        specs,
        model,
        workspace,
        2,
        1,
        builder;
        evaluation_kpoint_indices = [1, 3, 17],
        response_component_workload = 8,
    )
    @test symmetry_mixed.backend == :mixed
    @test symmetry_mixed.symmetry_workload_enabled
    @test symmetry_mixed.evaluation_kpoint_count == 3
    @test symmetry_mixed.response_component_workload == 8
    @test symmetry_mixed.auto_direct_cost_estimate > 0
    @test symmetry_mixed.auto_mixed_cost_estimate > 0

    auto_cfg, auto_specs, auto_model, auto_workspace, auto_builder =
        execution_plan_fixture("auto"; nkfft = (4, 4))
    symmetry_auto = FEP_RUNTIME.build_fourier_execution_plan(
        auto_cfg,
        auto_specs,
        auto_model,
        auto_workspace,
        2,
        1,
        auto_builder;
        evaluation_kpoint_indices = [1],
        response_component_workload = 8,
    )
    @test symmetry_auto.backend == :direct
    @test symmetry_auto.factor_source == :auto_fallback_symmetry_workload_cost
    @test symmetry_auto.auto_mixed_cost_estimate >= symmetry_auto.auto_direct_cost_estimate

    memory_name = "WANNIERNLQG_MIXED_MEMORY_LIMIT_BYTES"
    saved = get(ENV, memory_name, nothing)
    try
        ENV[memory_name] = "1"
        @test_throws ErrorException FEP_RUNTIME.build_fourier_execution_plan(
            cfg,
            specs,
            model,
            workspace,
            1,
            1,
            builder,
        )
        auto_cfg, auto_specs, auto_model, auto_workspace, auto_builder =
            execution_plan_fixture("auto"; nkfft = (4, 4))
        automatic_fallback = FEP_RUNTIME.build_fourier_execution_plan(
            auto_cfg,
            auto_specs,
            auto_model,
            auto_workspace,
            1,
            1,
            auto_builder,
        )
        @test automatic_fallback.backend == :direct
        @test automatic_fallback.factor_source == :auto_fallback_memory
    finally
        saved === nothing ? delete!(ENV, memory_name) : (ENV[memory_name] = saved)
    end
end
