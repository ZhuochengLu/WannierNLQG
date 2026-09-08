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
