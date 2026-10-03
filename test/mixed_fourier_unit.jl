using Test
using LinearAlgebra

const MF_MATRIX = WannierNLQG.MatrixElements
const MF_RUNTIME = WannierNLQG.Runtime

@testset "Explicit Fourier public configuration" begin
    @test_throws UndefKeywordError WannierNLQG.Runtime.EffectiveTaskConfig()

    direct_cfg = WannierNLQG.Runtime.EffectiveTaskConfig(fourier_backend = "direct")
    @test direct_cfg.fourier_backend == "direct"
    @test direct_cfg.NKdiv === nothing
    @test direct_cfg.NKFFT === nothing
    @test length(MF_RUNTIME.validate_config(direct_cfg)) == 1

    r_grid = Int[-6 6 0; -5 5 0; 0 0 0]
    @test_throws ErrorException MF_MATRIX.resolve_mixed_fourier_factors((100, 100, 1), r_grid)

    nkdiv, nkfft, source =
        MF_MATRIX.resolve_mixed_fourier_factors((200, 200, 1), r_grid; nkfft = (20, 20, 1))
    @test nkdiv == (10, 10, 1)
    @test nkfft == (20, 20, 1)
    @test source == :inferred_nkdiv

    nkdiv, nkfft, source =
        MF_MATRIX.resolve_mixed_fourier_factors((200, 200, 1), r_grid; nkdiv = (10, 10, 1))
    @test nkdiv == (10, 10, 1)
    @test nkfft == (20, 20, 1)
    @test source == :inferred_nkfft

    nkdiv, nkfft, source = MF_MATRIX.resolve_mixed_fourier_factors(
        (8, 8, 1),
        r_grid;
        nkdiv = (8, 8, 1),
        nkfft = (1, 1, 1),
    )
    @test (nkdiv, nkfft, source) == ((8, 8, 1), (1, 1, 1), :explicit)

    @test_throws ErrorException MF_MATRIX.resolve_mixed_fourier_factors(
        (100, 100, 1),
        r_grid;
        nkdiv = (4, 4, 1),
        nkfft = (20, 20, 1),
    )

    explicit_cfg = WannierNLQG.Runtime.EffectiveTaskConfig(
        k_mesh = (100, 100),
        fourier_backend = "mixed",
        NKdiv = (5, 5),
        NKFFT = (20, 20),
    )
    @test length(MF_RUNTIME.validate_config(explicit_cfg)) == 1
    @test length(
        MF_RUNTIME.validate_config(
            WannierNLQG.Runtime.EffectiveTaskConfig(
                k_mesh = (100, 100),
                fourier_backend = "mixed",
                NKFFT = (20, 20),
            ),
        ),
    ) == 1
    @test_throws ErrorException MF_RUNTIME.validate_config(
        WannierNLQG.Runtime.EffectiveTaskConfig(k_mesh = (100, 100), fourier_backend = "mixed"),
    )
    @test_throws ErrorException MF_RUNTIME.validate_config(
        WannierNLQG.Runtime.EffectiveTaskConfig(
            k_mesh = (100, 100),
            fourier_backend = "mixed",
            NKdiv = (4, 4),
            NKFFT = (20, 20),
        ),
    )
    auto_cfg =
        WannierNLQG.Runtime.EffectiveTaskConfig(k_mesh = (100, 100), fourier_backend = "auto")
    @test length(MF_RUNTIME.validate_config(auto_cfg)) == 1
    auto_mixed_cfg = WannierNLQG.Runtime.EffectiveTaskConfig(
        k_mesh = (100, 100),
        fourier_backend = "auto",
        NKFFT = (20, 20),
    )
    @test length(MF_RUNTIME.validate_config(auto_mixed_cfg)) == 1
    @test_throws ErrorException MF_RUNTIME.validate_config(
        WannierNLQG.Runtime.EffectiveTaskConfig(
            k_mesh = (100, 100),
            fourier_backend = "direct",
            NKdiv = (5, 5),
        ),
    )

    model = WannierNLQG.Core.TightBindingModel(
        Matrix{Float64}(I, 3, 3),
        2,
        3,
        ones(Int, 3),
        Int[-1 0 1; 0 0 0; 0 0 0],
        zeros(ComplexF64, 2, 2, 3),
        zeros(ComplexF64, 2, 2, 3, 3),
    )
    request = MF_MATRIX.MatrixElementRequest(
        MF_MATRIX.HAMILTONIAN_SECOND_DERIVATIVES;
        spatial_dimension = 2,
    )
    workspace = MF_MATRIX.MatrixElementWorkspace(model, MF_MATRIX.compile_matrix_plan(request))
    MF_MATRIX.prepare_real_space!(workspace, model)
    grid, reason =
        MF_MATRIX.mixed_fourier_grid(model, (8, 8, 1); nkdiv = (1, 1, 1), nkfft = (8, 8, 1))
    @test isempty(reason)
    @test_throws ErrorException MF_MATRIX.enable_mixed_fourier!(
        workspace,
        model,
        grid;
        memory_limit_bytes = 128,
    )

    legacy_name = "WANNIERNLQG_FOURIER_BACKEND"
    saved = get(ENV, legacy_name, nothing)
    try
        ENV[legacy_name] = "direct"
        error_text = try
            MF_RUNTIME.validate_config(
                WannierNLQG.Runtime.EffectiveTaskConfig(fourier_backend = "direct"),
            )
            ""
        catch err
            sprint(showerror, err)
        end
        @test occursin("Legacy Mixed-FFT environment configuration", error_text)
    finally
        saved === nothing ? delete!(ENV, legacy_name) : (ENV[legacy_name] = saved)
    end
end

@testset "Mixed-FFT interleaved block LRU" begin
    model = WannierNLQG.IO.read_wannier_tb(
        joinpath(@__DIR__, "..", "examples", "fixtures", "synthetic_runtime", "synthetic_tb.dat"),
    )
    request = MF_MATRIX.MatrixElementRequest(
        MF_MATRIX.VELOCITY_VERTICES,
        MF_MATRIX.INTERNAL_CONNECTION_DERIVATIVES,
        MF_MATRIX.HAMILTONIAN_SECOND_DERIVATIVES;
        spatial_dimension = 2,
    )
    plan = MF_MATRIX.compile_matrix_plan(request)
    grid, reason =
        MF_MATRIX.mixed_fourier_grid(model, (8, 8, 1); nkdiv = (2, 2, 1), nkfft = (4, 4, 1))
    @test isempty(reason)
    groups = MF_MATRIX.MixedFourierLayout(plan).groups
    @test length(groups) > 1
    block_bytes = sum(MF_MATRIX._mixed_entry_bytes(grid, model, plan, group) for group in groups)
    limit = 2 * block_bytes
    workspace = MF_MATRIX.prepare_real_space!(MF_MATRIX.MatrixElementWorkspace(model, plan), model)
    MF_MATRIX.enable_mixed_fourier!(workspace, model, grid; memory_limit_bytes = limit)
    points = ([0.0, 0.0, 0.0], [0.125, 0.0, 0.0], [0.0, 0.125, 0.0])
    try
        for point in (points[1], points[2])
            MF_MATRIX.begin_mixed_kpoint!(workspace, point)
            MF_MATRIX.compute_kpoint!(workspace, model, point)
        end
        first_pass = MF_MATRIX.mixed_fourier_stats(workspace)
        @test first_pass.fft_calls == 2 * length(groups)
        @test first_pass.cache_hits == 0
        @test first_pass.allocated_bytes == limit

        MF_MATRIX.begin_mixed_kpoint!(workspace, points[1])
        MF_MATRIX.compute_kpoint!(workspace, model, points[1])
        repeated = MF_MATRIX.mixed_fourier_stats(workspace)
        @test repeated.fft_calls == first_pass.fft_calls
        @test repeated.cache_hits == length(groups)

        MF_MATRIX.begin_mixed_kpoint!(workspace, points[3])
        MF_MATRIX.compute_kpoint!(workspace, model, points[3])
        evicted = MF_MATRIX.mixed_fourier_stats(workspace)
        @test evicted.evictions == length(groups)
        @test evicted.fft_calls == 3 * length(groups)
        @test evicted.allocated_bytes <= limit
        @test evicted.cache_entries == 2 * length(groups)

        MF_MATRIX.begin_mixed_kpoint!(workspace, points[2])
        MF_MATRIX.compute_kpoint!(workspace, model, points[2])
        revisited = MF_MATRIX.mixed_fourier_stats(workspace)
        @test revisited.fft_calls == 4 * length(groups)
        @test revisited.evictions == 2 * length(groups)
    finally
        MF_MATRIX.disable_mixed_fourier!(workspace)
    end

    offset_workspace =
        MF_MATRIX.prepare_real_space!(MF_MATRIX.MatrixElementWorkspace(model, plan), model)
    MF_MATRIX.enable_mixed_fourier!(
        offset_workspace,
        model,
        grid;
        memory_limit_bytes = 3 * block_bytes,
    )
    try
        destination = zeros(ComplexF64, model.num_orbitals, model.num_orbitals)
        for point in (points[1], points[2], points[1])
            MF_MATRIX.begin_mixed_kpoint!(offset_workspace, point)
            shifted = point .+ [0.01, 0.0, 0.0]
            @test MF_MATRIX._mixed_copy!(destination, offset_workspace, model, :H, shifted)
        end
        offset_stats = MF_MATRIX.mixed_fourier_stats(offset_workspace)
        @test offset_stats.offset_count == 1
        @test offset_stats.fft_calls == 2
        @test offset_stats.cache_hits == 1
    finally
        MF_MATRIX.disable_mixed_fourier!(offset_workspace)
    end
end

@testset "Recycled FFT buffers discard stale output before repacking" begin
    model=WannierNLQG.IO.read_wannier_tb(
        joinpath(@__DIR__, "..", "examples", "fixtures", "synthetic_runtime", "synthetic_tb.dat"),
    )
    me=WannierNLQG.MatrixElements
    plan=me.compile_matrix_plan(me.MatrixElementRequest(me.SPECTRUM; spatial_dimension = 2))
    grid, reason=me.mixed_fourier_grid(model, (8, 8, 1); nkdiv = (2, 2, 1), nkfft = (4, 4, 1))
    ws=me.prepare_real_space!(me.MatrixElementWorkspace(model, plan), model)
    provider=me.enable_mixed_fourier!(
        ws,
        model,
        grid;
        memory_limit_bytes = maximum(
            me._mixed_entry_bytes(grid, model, plan, g) for g in me.MixedFourierLayout(plan).groups
        ),
    )
    try
        for (point, delta) in (
            ([0.0, 0.0, 0.0], [0.0, 0.0, 0.0]),
            ([0.125, 0.0, 0.0], [0.01, 0.0, 0.0]),
            ([0.0, 0.125, 0.0], [0.0, 0.0, 0.0]),
        )
            for entry in values(provider.store.entries)
                fill!(entry.buffer, ComplexF64(NaN, NaN))
            end
            me.begin_mixed_kpoint!(ws, point)
            target=zeros(ComplexF64, model.num_orbitals, model.num_orbitals)
            @test me._mixed_copy!(target, ws, model, :H, point+delta)
            fresh=me.prepare_real_space!(me.MatrixElementWorkspace(model, plan), model)
            me.enable_mixed_fourier!(fresh, model, grid)
            try
                me.begin_mixed_kpoint!(fresh, point);
                expected=similar(target)
                @test me._mixed_copy!(expected, fresh, model, :H, point+delta)
                @test target == expected
                @test all(isfinite, target)
            finally
                me.disable_mixed_fourier!(fresh)
            end
        end
    finally
        me.disable_mixed_fourier!(ws)
    end
end

@testset "Completed-block reuse preserves values within a large cache" begin
    me=WannierNLQG.MatrixElements
    model=WannierNLQG.IO.read_wannier_tb(
        joinpath(@__DIR__, "..", "examples", "fixtures", "synthetic_runtime", "synthetic_tb.dat"),
    )
    plan=me.compile_matrix_plan(me.MatrixElementRequest(me.SPECTRUM; spatial_dimension = 2))
    grid, _=me.mixed_fourier_grid(model, (8, 8, 1); nkdiv = (2, 2, 1), nkfft = (4, 4, 1))
    normal=me.prepare_real_space!(me.MatrixElementWorkspace(model, plan), model)
    stream=me.prepare_real_space!(me.MatrixElementWorkspace(model, plan), model)
    pnormal=me.enable_mixed_fourier!(normal, model, grid)
    pstream=me.enable_mixed_fourier!(stream, model, grid)
    me.reuse_completed_mixed_blocks!(stream)
    try
        for index in me.mixed_fourier_local_k_indices(grid, 0, 1)
            i=index-1;
            point=[mod(i, 8)/8, mod(div(i, 8), 8)/8, 0.0]
            a=zeros(ComplexF64, model.num_orbitals, model.num_orbitals);
            b=similar(a)
            me.begin_mixed_kpoint!(normal, point);
            me.begin_mixed_kpoint!(stream, point)
            @test me._mixed_copy!(a, normal, model, :H, point)
            @test me._mixed_copy!(b, stream, model, :H, point)
            @test a==b
        end
        @test pnormal.store.fft_calls==pstream.store.fft_calls==4
        @test length(pnormal.store.entries)==4
        @test length(pstream.store.entries)==1
        @test pstream.store.evictions==3
        @test pnormal.store.allocated_bytes==4*pstream.store.allocated_bytes
        # A revisit after recycling must recompute, never expose stale storage.
        for ws in (normal, stream)
            me.begin_mixed_kpoint!(ws, zeros(3))
        end
        a=zeros(ComplexF64, model.num_orbitals, model.num_orbitals)
        b=similar(a)
        @test me._mixed_copy!(a, normal, model, :H, zeros(3))
        @test me._mixed_copy!(b, stream, model, :H, zeros(3))
        @test a == b
        @test pstream.store.fft_calls == 5

    finally
        me.disable_mixed_fourier!(normal);
        me.disable_mixed_fourier!(stream)
    end
end
