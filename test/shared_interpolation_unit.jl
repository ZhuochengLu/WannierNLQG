# Compare cached and uncached capability buffers recursively, including private source gauge.
function shared_interpolation_arrays_equal(left, right)
    typeof(left) === typeof(right) || return false
    left === nothing && return true
    left isa AbstractArray && return isequal(left, right)
    left isa Number && return isequal(left, right)
    return all(
        shared_interpolation_arrays_equal(getfield(left, field), getfield(right, field)) for
        field in fieldnames(typeof(left))
    )
end

@testset "task-local raw interpolation sharing" begin
    matrix_elements = WannierNLQG.MatrixElements
    model = WannierNLQG.IO.read_wannier_tb(
        joinpath(@__DIR__, "..", "examples", "fixtures", "synthetic_runtime", "synthetic_tb.dat"),
    )
    request_kinds = (
        matrix_elements.VELOCITY_VERTICES,
        matrix_elements.INTERNAL_CONNECTION_DERIVATIVES,
        matrix_elements.HAMILTONIAN_SECOND_DERIVATIVES,
    )
    make_plan(eta) = matrix_elements.compile_matrix_plan(
        matrix_elements.MatrixElementRequest(
            request_kinds...;
            spatial_dimension = 2,
            denominator_regularization = eta,
            degeneracy_threshold = eta,
        ),
    )
    make_workspace(eta) = matrix_elements.prepare_real_space!(
        matrix_elements.MatrixElementWorkspace(model, make_plan(eta)),
        model,
    )
    point = [0.125, 0.25, 0.0]
    expected = [make_workspace(eta) for eta in (0.001, 0.03)]
    for workspace in expected
        matrix_elements.compute_kpoint!(workspace, model, point)
    end
    actual = [make_workspace(eta) for eta in (0.001, 0.03)]
    cache = matrix_elements.SharedInterpolationCache()
    matrix_elements.begin_shared_interpolation!(cache)
    matrix_elements.with_shared_interpolation(cache) do
        for workspace in actual
            matrix_elements.compute_kpoint!(workspace, model, point)
        end
    end
    for (reference, workspace) in zip(expected, actual)
        for field in (:spectrum, :hamiltonian, :position, :fourier_factors)
            @test shared_interpolation_arrays_equal(
                getfield(reference.data, field),
                getfield(workspace.data, field),
            )
        end
    end
    stats = matrix_elements.shared_interpolation_stats(cache)
    @test stats.diagonalizations == 1
    @test stats.spectrum_hits == 1
    @test stats.fourier_evaluations == 5
    @test stats.fourier_hits == 4
    @test actual[2].counts.diagonalizations == 0
    @test actual[1].data.spectrum !== actual[2].data.spectrum
    @test actual[1].data.position !== actual[2].data.position
    original = actual[2].data.spectrum.energies[1]
    actual[1].data.spectrum.energies[1] += 1.0
    @test actual[2].data.spectrum.energies[1] == original

    shifted = make_workspace(0.001)
    matrix_elements.with_shared_interpolation(cache) do
        matrix_elements.compute_kpoint!(shifted, model, point .+ [0.001, 0.0, 0.0])
    end
    @test matrix_elements.shared_interpolation_stats(cache).diagonalizations == 2
    periodic_image = make_workspace(0.001)
    matrix_elements.with_shared_interpolation(cache) do
        matrix_elements.compute_kpoint!(periodic_image, model, point .+ [1.0, 0.0, 0.0])
    end
    @test matrix_elements.shared_interpolation_stats(cache).diagonalizations == 3
    matrix_elements.begin_shared_interpolation!(cache)
    @test matrix_elements.shared_interpolation_stats(cache).entries == 0
    @test matrix_elements.shared_interpolation_stats(cache).generations == 2
    @test matrix_elements._shared_interpolation_cache() === nothing
    @test_throws ErrorException matrix_elements.with_shared_interpolation(cache) do
        error("intentional binding failure")
    end
    @test matrix_elements._shared_interpolation_cache() === nothing

    grid, _ = matrix_elements.mixed_fourier_grid(model, (2, 2); nkdiv = (1, 1), nkfft = (2, 2))
    mixed_point = [0.0, 0.0, 0.0]
    mixed_workspaces = [make_workspace(eta) for eta in (0.001, 0.03, 0.03)]
    try
        for workspace in mixed_workspaces
            matrix_elements.enable_mixed_fourier!(workspace, model, grid)
            matrix_elements.begin_mixed_kpoint!(workspace, mixed_point)
        end
        matrix_elements.compute_kpoint!(mixed_workspaces[3], model, mixed_point)
        matrix_elements.begin_shared_interpolation!(cache)
        before = matrix_elements.shared_interpolation_stats(cache)
        matrix_elements.with_shared_interpolation(cache) do
            matrix_elements.compute_kpoint!(mixed_workspaces[1], model, mixed_point)
            matrix_elements.compute_kpoint!(mixed_workspaces[2], model, mixed_point)
            direct = make_workspace(0.03)
            matrix_elements.compute_kpoint!(direct, model, mixed_point)
        end
        after = matrix_elements.shared_interpolation_stats(cache)
        @test after.diagonalizations - before.diagonalizations == 2
        @test after.spectrum_hits - before.spectrum_hits == 1
        @test after.fourier_hits - before.fourier_hits == 4
        for field in (:spectrum, :hamiltonian, :position, :fourier_factors)
            @test shared_interpolation_arrays_equal(
                getfield(mixed_workspaces[3].data, field),
                getfield(mixed_workspaces[2].data, field),
            )
        end
    finally
        foreach(matrix_elements.disable_mixed_fourier!, mixed_workspaces)
    end
    for mixed in (false, true)
        counter_only = matrix_elements.SharedInterpolationCache(reuse = false)
        matrix_elements.begin_shared_interpolation!(counter_only)
        isolated = [make_workspace(eta) for eta in (0.001, 0.03)]
        try
            if mixed
                for workspace in isolated
                    matrix_elements.enable_mixed_fourier!(workspace, model, grid)
                    matrix_elements.begin_mixed_kpoint!(workspace, mixed_point)
                end
            end
            matrix_elements.with_shared_interpolation(counter_only) do
                for workspace in isolated
                    matrix_elements.compute_kpoint!(workspace, model, mixed ? mixed_point : point)
                end
            end
            counts = matrix_elements.shared_interpolation_stats(counter_only)
            @test !counts.reuse_enabled
            @test counts.diagonalizations == 2
            @test counts.fourier_evaluations == 10
            @test counts.entries == counts.peak_entries == 0
            @test counts.spectrum_hits == counts.fourier_hits == 0
            reference = mixed ? mixed_workspaces[3] : expected[2]
            for field in (:spectrum, :hamiltonian, :position, :fourier_factors)
                @test shared_interpolation_arrays_equal(
                    getfield(reference.data, field),
                    getfield(isolated[2].data, field),
                )
            end
        finally
            foreach(matrix_elements.disable_mixed_fourier!, isolated)
        end
    end
end

@testset "spin primitive sharing preserves task-local Hermitization" begin
    matrix_elements = WannierNLQG.MatrixElements
    model = WannierNLQG.IO.read_wannier_tb(
        joinpath(@__DIR__, "..", "examples", "fixtures", "synthetic_runtime", "synthetic_tb.dat"),
    )
    count = model.num_orbitals
    vectors = model.num_r_vectors
    values(dims...) = reshape(ComplexF64[sin(i) + im * cos(i / 3) for i in 1:prod(dims)], dims...)
    spin = matrix_elements.SpinRealSpaceData(values(count, count, 3, vectors))
    velocity = matrix_elements.SpinVelocityRealSpaceData(
        spin,
        values(count, count, 3, vectors),
        values(count, count, 3, 3, vectors),
        values(count, count, 3, 3, vectors),
        matrix_elements.SpinVelocityRealSpaceDiagnostics(0.0, 0.0, 0.0, 0.0),
    )
    sources = matrix_elements.MatrixElementSources(spin_velocity = velocity)
    make_workspace(kind) = matrix_elements.prepare_real_space!(
        matrix_elements.MatrixElementWorkspace(
            model,
            matrix_elements.compile_matrix_plan(
                matrix_elements.MatrixElementRequest(kind; spatial_dimension = 3),
            ),
            sources,
        ),
        model,
    )
    kinds = (matrix_elements.SPIN, matrix_elements.SPIN_VELOCITY)
    point = [0.125, 0.25, 0.0]
    for mixed in (false, true)
        expected = [make_workspace(kind) for kind in kinds]
        actual = [make_workspace(kind) for kind in kinds]
        grid, _ = matrix_elements.mixed_fourier_grid(
            model,
            (2, 2, 1);
            nkdiv = (1, 1, 1),
            nkfft = (2, 2, 1),
        )
        try
            if mixed
                for workspace in (expected..., actual...)
                    matrix_elements.enable_mixed_fourier!(workspace, model, grid)
                    matrix_elements.begin_mixed_kpoint!(workspace, zeros(3), (0, 0, 0))
                end
            end
            for workspace in expected
                matrix_elements.compute_kpoint!(workspace, model, point)
            end
            cache = matrix_elements.SharedInterpolationCache()
            matrix_elements.begin_shared_interpolation!(cache)
            matrix_elements.with_shared_interpolation(cache) do
                for workspace in actual
                    matrix_elements.compute_kpoint!(workspace, model, point)
                end
            end
            for (reference, workspace) in zip(expected, actual)
                for field in (:spectrum, :hamiltonian, :position, :spin, :spin_velocity)
                    @test shared_interpolation_arrays_equal(
                        getfield(reference.data, field),
                        getfield(workspace.data, field),
                    )
                end
            end
            stats = matrix_elements.shared_interpolation_stats(cache)
            @test stats.diagonalizations == 1
            @test stats.spectrum_hits == 1
            @test stats.fourier_hits >= 1
        finally
            foreach(matrix_elements.disable_mixed_fourier!, (expected..., actual...))
        end
    end
end
