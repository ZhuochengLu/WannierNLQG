module WilsonResponseGroupsTests

using Test, LinearAlgebra, WannierNLQG
const C = WannierNLQG.Core
const ME = WannierNLQG.MatrixElements
const RESP = WannierNLQG.Responses

function factor_model(channels::Int; splitting = 0.0, avoided = 0.0)
    lattice=Matrix(Diagonal([4.0, 4.0, 20.0]));
    R=Int[0 0 0; -1 0 1; 0 0 0]
    n=2channels;
    H=zeros(ComplexF64, n, n, 3);
    r=zeros(ComplexF64, n, n, 3, 3)
    for s in 0:(channels - 1)
        a=2s+1;
        b=a+1
        H[a:(a + 1), a:(a + 1), 2].=ComplexF64[0.4 1.1; 1.1 -0.4]
        H[a, b, 3]=0.8;
        H[b, a, 1]=0.8
        r[b, b, 2, 2]=1.2
        if channels==2
            for i in a:b
                H[i, i, 3]+=(s==0 ? 1 : -1)*splitting/(2im)
                H[i, i, 1]-=(s==0 ? 1 : -1)*splitting/(2im)
            end
        end
    end
    if channels==2
        for j in 1:2
            ;
            H[j, j + 2, 2]=avoided;
            H[j + 2, j, 2]=avoided;
        end
    end
    return C.TightBindingModel(lattice, n, 3, ones(Int, 3), R, H, r)
end
function kernel(model, k, h, convention; grouped = true)
    centers=ME.extract_wannier_centers(model);
    frac=hcat(
        [
            C.real_space_cartesian_to_fractional(centers[:, i], model.lattice) for
            i in 1:model.num_orbitals
        ]...,
    )
    req=ME.MatrixElementRequest(ME.BERRY_CONNECTION; spatial_dimension = 2)
    matrix=ME.MatrixElementWorkspace(
        model,
        ME.compile_matrix_plan(req; wannier_center_convention = convention),
    )
    w=RESP.make_wilson_loop_response_workspace(
        model.num_orbitals,
        model.num_r_vectors,
        2,
        1;
        matrix_elements = matrix,
    )
    ME.prepare_real_space!(w.scratch.matrix_elements, model)
    RESP.prepare_wilson_loop_response_cache!(
        w,
        k,
        C.finite_difference_step_matrix(model, h)[:, 1:2],
        frac,
        model,
        2;
        denominator_regularization = 0.001,
        degeneracy_threshold = 0.002,
        axes = Int[2],
    )
    if !grouped
        ME.mark_degenerate_groups!(w.central_data, 0.002)
        w.transported_derivative_axis=0;
        fill!(w.transported_derivative_valid, false)
    end
    RESP.compute_wilson_loop_shift_current_from_cache!(
        w.response_kernel,
        w,
        1,
        model.num_orbitals,
        h,
        2;
        tensor_indices = Int[2, 2, 2],
    )
    nv=model.num_orbitals÷2
    return sum(w.response_kernel[1:nv, (nv + 1):end, 2, 2, 2]), copy(w.response_kernel), w
end
function group_checks()
    p=ME.compile_matrix_plan(ME.MatrixElementRequest(ME.BERRY_CONNECTION; spatial_dimension = 2))
    d=ME.GeometricLoopMatrixData(ME.KPointMatrixData(4, 0, p));
    e=d.spectrum.energies
    e.=[0.0, 0.0015, 0.003, 1.0];
    before=copy(e);
    ids=(d.degeneracy_weights, d.degeneracy_group_starts, d.degeneracy_group_stops)
    ME.mark_wilson_response_groups!(d, 0.002)
    @test d.degeneracy_group_starts==[1, 1, 1, 4];
    @test d.degeneracy_weights==[1/3, 1/3, 1/3, 1.0]
    @test e==before && d.common.spectral_gap_tolerance==1e-10
    @test all(
        ids[i]===getfield(
            d,
            (:degeneracy_weights, :degeneracy_group_starts, :degeneracy_group_stops)[i],
        ) for i in 1:3
    )
    e.=[0.0, 0.002, 0.004, 1.0];
    ME.mark_wilson_response_groups!(d, 0.002);
    @test d.degeneracy_group_starts==[1, 2, 3, 4]
    e.=[0.0, 0.0, 1.0, 1.0];
    ME.mark_wilson_response_groups!(d, 0.0);
    @test d.degeneracy_group_starts==[1, 1, 3, 3]
    snapshot=copy(d.degeneracy_group_starts)
    for tol in [-1.0, NaN, Inf]
        ;
        @test_throws ArgumentError ME.mark_wilson_response_groups!(d, tol);
        @test d.degeneracy_group_starts==snapshot;
    end
    e.=[1.0, 0.0, 2.0, 3.0];
    @test_throws ArgumentError ME.mark_wilson_response_groups!(d, 0.002);
    @test d.degeneracy_group_starts==snapshot
    e.=[0.0, NaN, 2.0, 3.0];
    @test_throws ArgumentError ME.mark_wilson_response_groups!(d, 0.002);
    @test d.degeneracy_group_starts==snapshot
    e.=[0.0, 0.0015, 0.003, 1.0];
    ME.mark_wilson_response_groups!(d, 0.002)
    bytes=@allocated ME.mark_wilson_response_groups!(d, 0.002);
    @test bytes==0
    return Dict(
        "allocated_bytes"=>bytes,
        "legacy_adjacent_rule"=>true,
        "exact_guard_unchanged"=>true,
        "invalid_arguments_no_state_mutation"=>true,
    )
end

@testset "Wilson response groups preserve the supplied contract" begin
    details = group_checks()
    @test details["allocated_bytes"] == 0
    base = factor_model(1)
    for model in (factor_model(2), factor_model(2; splitting = 5e-4, avoided = 5e-7))
        for convention in (C.CONVENTION_I, C.CONVENTION_II), ky in (0.5, 0.173), h in (1e-4, 5e-5)
            a, _, _ = kernel(base, [0.0, ky, 0.0], h, convention)
            b, _, _ = kernel(model, [0.0, ky, 0.0], h, convention)
            @test isapprox(b, 2a; atol = 1e-6, rtol = 1e-4)
        end
    end
    a, ka, _ = kernel(base, [0.0, 0.173, 0.0], 1e-4, C.CONVENTION_II)
    b, kb, _ = kernel(base, [0.0, 0.173, 0.0], 1e-4, C.CONVENTION_II; grouped = false)
    @test ka == kb
    @test a == b
end

# Reuse the two production state types and all four public response markers.
function response_group_states()
    plan =
        ME.compile_matrix_plan(ME.MatrixElementRequest(ME.BERRY_CONNECTION; spatial_dimension = 2))
    return (
        (ME.ProjectorMatrixData(ME.KPointMatrixData(4, 0, plan), 2), ME.mark_degenerate_groups!),
        (ME.GeometricLoopMatrixData(ME.KPointMatrixData(4, 0, plan)), ME.mark_degenerate_groups!),
        (
            ME.GeometricLoopMatrixData(ME.KPointMatrixData(4, 0, plan)),
            ME.mark_geometric_response_groups!,
        ),
        (
            ME.GeometricLoopMatrixData(ME.KPointMatrixData(4, 0, plan)),
            ME.mark_wilson_response_groups!,
        ),
    )
end

@testset "All response markers use adjacent chains and preserve the spectral guard" begin
    for (data, mark!) in response_group_states()
        e = data.spectrum.energies
        e .= [0.0, 0.0015, 0.003, 1.0]
        original = copy(e)
        mark!(data, 0.001)
        @test data.degeneracy_group_starts == [1, 2, 3, 4]
        mark!(data, 0.002)
        @test data.degeneracy_group_starts == [1, 1, 1, 4]
        @test data.degeneracy_group_stops == [3, 3, 3, 4]
        @test data.degeneracy_weights == [1/3, 1/3, 1/3, 1.0]
        if data isa ME.GeometricLoopMatrixData
            @test RESP.expand_band_window_for_groups(2, 2, data) == (1, 3)
        else
            # Projector closes its active mask using these complete bounds.
            @test (data.degeneracy_group_starts[2], data.degeneracy_group_stops[2]) == (1, 3)
        end
        @test e == original
        @test data.common.spectral_gap_tolerance == 1e-10
        e .= [0.0, 0.0625, 0.125, 1.0]
        mark!(data, 0.0625)
        @test data.degeneracy_group_starts == [1, 2, 3, 4]
        mark!(data, nextfloat(0.0625))
        @test data.degeneracy_group_starts == [1, 1, 1, 4]
        mark!(data, prevfloat(0.0625))
        @test data.degeneracy_group_starts == [1, 2, 3, 4]
        e .= [0.0, 0.0, 1.0, 1.0]
        mark!(data, 0.0)
        @test data.degeneracy_group_starts == [1, 1, 3, 3]
        e .= [0.0, eps(Float64), 0.5, 1.0]
        mark!(data, 0.0)
        @test data.degeneracy_group_starts == [1, 1, 3, 4]
        # The response chain cannot suppress an unresolved reconstruction gap.
        e .= [0.0, 1e-12, 1.0, 2.0]
        if mark! === ME.mark_degenerate_groups!
            before_guard = (
                copy(data.degeneracy_group_starts),
                copy(data.degeneracy_group_stops),
                copy(data.degeneracy_weights),
            )
            @test_throws ErrorException mark!(data, 0.002)
            @test data.degeneracy_group_starts == before_guard[1]
            @test data.degeneracy_group_stops == before_guard[2]
            @test data.degeneracy_weights == before_guard[3]
        else
            mark!(data, 0.002)
            @test data.degeneracy_group_starts == [1, 1, 3, 4]
        end
        @test_throws ErrorException ME.spectral_subspace_blocks(e)
        e .= original
        mark!(data, 0.002)
        snapshot = (
            copy(data.degeneracy_group_starts),
            copy(data.degeneracy_group_stops),
            copy(data.degeneracy_weights),
        )
        for bad in (-1.0, Inf, NaN)
            @test_throws ArgumentError mark!(data, bad)
            @test data.degeneracy_group_starts == snapshot[1]
            @test data.degeneracy_group_stops == snapshot[2]
            @test data.degeneracy_weights == snapshot[3]
        end
        e .= [1.0, 0.0, 2.0, 3.0]
        @test_throws ArgumentError mark!(data, 0.002)
        @test data.degeneracy_group_starts == snapshot[1]
        e .= [0.0, NaN, 2.0, 3.0]
        @test_throws ArgumentError mark!(data, 0.002)
        @test data.degeneracy_group_starts == snapshot[1]
        e .= original
        mark!(data, 0.002)
        if mark! !== ME.mark_degenerate_groups!
            # These response-only markers were allocation-free before this change.
            @test (@allocated mark!(data, 0.002)) == 0
        end
    end
end

@testset "Composite projector finite differences satisfy independent identities" begin
    plan = ME.compile_matrix_plan(ME.MatrixElementRequest(ME.SPECTRUM; spatial_dimension = 2))
    central = ME.ProjectorMatrixData(ME.KPointMatrixData(4, 0, plan), 2)
    plus = ME.ProjectorMatrixData(ME.KPointMatrixData(4, 0, plan), 2)
    minus = ME.ProjectorMatrixData(ME.KPointMatrixData(4, 0, plan), 2)
    central.spectrum.energies .= [0.0, 0.0015, 0.003, 1.0]
    central.spectrum.eigenvectors .= Matrix{ComplexF64}(I, 4, 4)
    ME.projector_reference_projectors!(central, Int64(4), 0.002)
    p = Matrix(Diagonal(ComplexF64[1, 1, 1, 0]))
    @test central.projectors[1, :, :] == p
    @test central.projectors[2, :, :] == p
    @test central.projectors[3, :, :] == p
    @test p*p == p
    @test central.projectors[1, :, :] + central.projectors[4, :, :] == Matrix{ComplexF64}(I, 4, 4)
    generator =
        ComplexF64[0 0.02 0.01im 0.1; 0.02 0 0.03 0.07im; -0.01im 0.03 0 0.08; 0.1 -0.07im 0.08 0]
    dp = -im*(generator*p-p*generator)
    d2p = -(generator*(generator*p-p*generator)-(generator*p-p*generator)*generator)
    fill!(central.effective_connection, 0)
    fill!(central.effective_connection_derivatives, 0)
    for h in (1e-4, 5e-5)
        plus.spectrum.eigenvectors .= exp(-im*h*generator)
        minus.spectrum.eigenvectors .= exp(im*h*generator)
        for data in (plus, minus)
            ME.projector_projectors!(
                data,
                Int64(4),
                central.degeneracy_weights,
                central.degeneracy_group_starts,
                central.degeneracy_group_stops,
            )
        end
        ME.projector_diff_projectors!(
            central,
            plus.projectors,
            minus.projectors,
            h,
            Int64(4),
            Int64(1),
        )
        actual = central.projector_derivatives[1, :, :, 1]
        second = central.projector_second_derivatives[1, :, :, 1, 1]
        @test actual ≈ dp atol=2e-9 rtol=2e-9
        @test second ≈ d2p atol=3e-7 rtol=3e-7
        @test p*actual+actual*p ≈ actual atol=2e-9 rtol=2e-9
        @test p*second+second*p+2actual*actual ≈ second atol=3e-7 rtol=3e-7
    end
end

end # module WilsonResponseGroupsTests
