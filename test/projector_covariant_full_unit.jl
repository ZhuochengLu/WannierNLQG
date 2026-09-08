using LinearAlgebra
using Random
using Test

const PCF_MATRIX = WannierNLQG.MatrixElements
const PCF_RESPONSES = WannierNLQG.Responses
const PCF_IO = WannierNLQG.IO
const PCF_CORE = WannierNLQG.Core

pcf_commutator(a, b) = a * b - b * a
pcf_anticommutator(a, b) = a * b + b * a

function pcf_hermitian(rng, count)
    value = randn(rng, ComplexF64, count, count)
    return 0.5 .* (value .+ value')
end

function pcf_current_hessian(p, dmu, dbeta, d2, amu, abeta)
    return d2 - 1.0im .* pcf_commutator(amu, dbeta) - 1.0im .* pcf_commutator(abeta, dmu) +
           amu * p * abeta +
           abeta * p * amu - p * amu * abeta - amu * abeta * p
end

function pcf_covariant_hessian(p, dmu, dbeta, d2, amu, abeta, damubeta, dbetaamu)
    quadratic = amu * abeta + abeta * amu
    return d2 - 1.0im .* pcf_commutator(amu, dbeta) - 1.0im .* pcf_commutator(abeta, dmu) -
           0.5im .* pcf_commutator(damubeta + dbetaamu, p) +
           amu * p * abeta +
           abeta * p * amu - 0.5 .* pcf_anticommutator(quadratic, p)
end

@testset "Projector symmetric covariant Hessian algebra" begin
    rng = MersenneTwister(0x20260825)
    count = 5
    p = pcf_hermitian(rng, count)
    dmu = pcf_hermitian(rng, count)
    dbeta = pcf_hermitian(rng, count)
    d2 = pcf_hermitian(rng, count)
    amu = pcf_hermitian(rng, count)
    abeta = pcf_hermitian(rng, count)
    damubeta = pcf_hermitian(rng, count)
    dbetaamu = pcf_hermitian(rng, count)
    current = pcf_current_hessian(p, dmu, dbeta, d2, amu, abeta)
    covariant = pcf_covariant_hessian(p, dmu, dbeta, d2, amu, abeta, damubeta, dbetaamu)
    defect =
        -0.5im .* pcf_commutator(damubeta + dbetaamu, p) +
        0.5 .* pcf_anticommutator(pcf_commutator(amu, abeta), p)
    scale = max(norm(covariant), 1.0)
    @test norm(covariant - current - defect) / scale <= 1.0e-13
    @test norm(covariant - covariant') / scale <= 1.0e-13
    @test norm(current - current' + pcf_anticommutator(pcf_commutator(amu, abeta), p)) /
          max(norm(current), 1.0) <= 1.0e-13
end

@testset "Full Hilbert-space Projector oracle" begin
    rng = MersenneTwister(0xFF20260825)
    full_count = 7
    wannier_count = 4
    e0 = Matrix{ComplexF64}(I, full_count, full_count)[:, 1:wannier_count]
    raw_x_mu = randn(rng, ComplexF64, full_count, full_count)
    raw_x_beta = randn(rng, ComplexF64, full_count, full_count)
    x_mu = 0.5 .* (raw_x_mu .- raw_x_mu')
    x_beta = 0.5 .* (raw_x_beta .- raw_x_beta')
    e_mu = x_mu * e0
    e_beta = x_beta * e0
    e_mubeta = 0.5 .* (x_mu * x_beta + x_beta * x_mu) * e0
    q_w = Matrix{ComplexF64}(I, full_count, full_count) - e0 * e0'
    a_mu = 1.0im .* (e0' * e_mu)
    a_beta = 1.0im .* (e0' * e_beta)
    da_beta_mu = 1.0im .* (e_mu' * e_beta + e0' * e_mubeta)
    da_mu_beta = 1.0im .* (e_beta' * e_mu + e0' * e_mubeta)
    g_mu_beta = e_mu' * q_w * e_beta
    g_beta_mu = e_beta' * q_w * e_mu

    p_a = Diagonal(ComplexF64[1, 1, 0, 0])
    p_b = Diagonal(ComplexF64[0, 0, 1, 1])
    full_p_a = e0 * p_a * e0'
    full_p_b = e0 * p_b * e0'
    full_p_a_mu = e_mu * p_a * e0' + e0 * p_a * e_mu'
    full_p_b_beta = e_beta * p_b * e0' + e0 * p_b * e_beta'
    full_p_b_mubeta =
        e_mubeta * p_b * e0' + e_mu * p_b * e_beta' + e_beta * p_b * e_mu' + e0 * p_b * e_mubeta'
    projected_second = e0' * full_p_b_mubeta * e0
    d_mu_p_a = -1.0im .* pcf_commutator(a_mu, p_a)
    d_beta_p_b = -1.0im .* pcf_commutator(a_beta, p_b)
    hessian = pcf_covariant_hessian(
        p_b,
        zeros(ComplexF64, wannier_count, wannier_count),
        zeros(ComplexF64, wannier_count, wannier_count),
        zeros(ComplexF64, wannier_count, wannier_count),
        a_mu,
        a_beta,
        da_beta_mu,
        da_mu_beta,
    )
    complete_second = hessian - pcf_anticommutator(0.5 .* (g_mu_beta + g_beta_mu), p_b)
    @test projected_second ≈ complete_second rtol = 1.0e-11 atol = 1.0e-12
    projected_product = e0' * (full_p_a_mu * full_p_b_beta) * e0
    completed_product = d_mu_p_a * d_beta_p_b + p_a * g_mu_beta * p_b
    @test projected_product ≈ completed_product rtol = 1.0e-11 atol = 1.0e-12
    @test norm(full_p_a * full_p_b) <= 1.0e-13
end

@testset "Production Projector Hessian and response closure" begin
    rng = MersenneTwister(0xC20260825)
    count = 3
    request = PCF_MATRIX.MatrixElementRequest(PCF_MATRIX.SPECTRUM; spatial_dimension = 2)
    plan = PCF_MATRIX.compile_matrix_plan(request)
    common = PCF_MATRIX.KPointMatrixData(count, 0, plan)
    data = PCF_MATRIX.ProjectorMatrixData(common, 2)
    p = Diagonal(ComplexF64[1, 0, 0])
    data.projectors[1, :, :] .= p
    for axis in 1:2
        data.effective_connection[:, :, axis] .= pcf_hermitian(rng, count)
    end
    for first in 1:2, second in 1:2
        data.effective_connection_derivatives[:, :, first, second] .= pcf_hermitian(rng, count)
    end
    g12 = randn(rng, ComplexF64, count, count)
    data.external_geometry[:, :, 1, 2] .= g12
    data.external_geometry[:, :, 2, 1] .= g12'
    data.external_geometry[:, :, 1, 1] .= pcf_hermitian(rng, count)
    data.external_geometry[:, :, 2, 2] .= pcf_hermitian(rng, count)
    shifted = repeat(reshape(Matrix(p), 1, count, count, 1), 1, 1, 1, 2)
    pure = zeros(ComplexF64, 1, count, count, 2)
    second_forward = reshape(Matrix(p), 1, count, count)
    second_backward = reshape(Matrix(p), 1, count, count)
    PCF_MATRIX.projector_second_diff_projectors!(
        data,
        shifted,
        shifted,
        second_forward,
        second_backward,
        1.0e-4,
        1,
        1,
        2,
        pure,
    )
    expected =
        pcf_covariant_hessian(
            p,
            zeros(ComplexF64, count, count),
            zeros(ComplexF64, count, count),
            zeros(ComplexF64, count, count),
            data.effective_connection[:, :, 1],
            data.effective_connection[:, :, 2],
            data.effective_connection_derivatives[:, :, 2, 1],
            data.effective_connection_derivatives[:, :, 1, 2],
        ) - pcf_anticommutator(
            0.5 .* (data.external_geometry[:, :, 1, 2] + data.external_geometry[:, :, 2, 1]),
            p,
        )
    @test data.projector_second_derivatives[1, :, :, 1, 2] ≈ expected rtol = 1.0e-11 atol = 1.0e-12

    data.projectors[2, :, :] .= Diagonal(ComplexF64[0, 1, 0])
    data.projector_derivatives .= randn(rng, ComplexF64, size(data.projector_derivatives))
    data.projector_second_derivatives .=
        randn(rng, ComplexF64, size(data.projector_second_derivatives))
    temporaries = [zeros(ComplexF64, count, count) for _ in 1:3]
    result = PCF_RESPONSES.projector_qhc_trace_c_cvabc!(temporaries..., data, 1, 2, 1, 2, 1)
    p_b = @view data.projectors[1, :, :]
    p_a = @view data.projectors[2, :, :]
    d_alpha_p_a = @view data.projector_derivatives[2, :, :, 2]
    manual = tr(
        p_b *
        d_alpha_p_a *
        p_a *
        (
            data.projector_second_derivatives[1, :, :, 1, 1] +
            data.projector_derivatives[2, :, :, 1] * data.projector_derivatives[1, :, :, 1] +
            p_a * data.external_geometry[:, :, 1, 1] * p_b
        ),
    )
    @test result ≈ manual rtol = 1.0e-12 atol = 1.0e-12
end

@testset "Full Projector Convention I/II trace covariance" begin
    model, _centers = wcc_synthetic_model()
    rng = MersenneTwister(0xC0A20260825)
    derivative_overlap_r = zeros(ComplexF64, 2, 2, 3, 3, model.num_r_vectors)
    home = only(
        findall(index -> all(iszero, @view(model.r_vectors[:, index])), axes(model.r_vectors, 2)),
    )
    for first in 1:3
        derivative_overlap_r[:, :, first, first, home] .= pcf_hermitian(rng, 2)
        for second in (first + 1):3
            values = randn(rng, ComplexF64, 2, 2)
            derivative_overlap_r[:, :, first, second, home] .= values
            derivative_overlap_r[:, :, second, first, home] .= values'
        end
    end
    sources = PCF_MATRIX.MatrixElementSources(
        derivative_overlap = PCF_MATRIX.DerivativeOverlapRealSpaceData(derivative_overlap_r),
    )
    request = PCF_MATRIX.MatrixElementRequest(
        PCF_MATRIX.WANNIER_POSITION,
        PCF_MATRIX.INTERNAL_CONNECTION_DERIVATIVES;
        spatial_dimension = 2,
    )
    kpoint = [0.173, 0.281, 0.0]
    step = 1.0e-2
    finite_difference_vectors = zeros(3, 2)
    for axis in 1:2
        displacement = zeros(3)
        displacement[axis] = step
        finite_difference_vectors[:, axis] .=
            PCF_CORE.reciprocal_cartesian_to_fractional(displacement, model.lattice)
    end

    caches = map((PCF_CORE.CONVENTION_I, PCF_CORE.CONVENTION_II)) do convention
        plan = PCF_MATRIX.compile_matrix_plan(request; wannier_center_convention = convention)
        matrix_workspace = PCF_MATRIX.MatrixElementWorkspace(model, plan, sources)
        cache = PCF_RESPONSES.make_projector_response_workspace(
            model.num_orbitals,
            model.num_r_vectors,
            2,
            1;
            matrix_elements = matrix_workspace,
        )
        PCF_MATRIX.prepare_real_space!(cache.scratch, model)
        PCF_RESPONSES.prepare_projector_response_cache!(
            cache,
            kpoint,
            finite_difference_vectors,
            model,
            model.num_orbitals,
            2;
            denominator_regularization = 1.0e-3,
            degeneracy_threshold = 1.0e-8,
            finite_difference_step = step,
        )
        cache
    end

    function trace_terms(data)
        band_a, band_b = 2, 1
        mu, alpha, beta = 1, 2, 1
        p_a = @view data.projectors[band_a, :, :]
        p_b = @view data.projectors[band_b, :, :]
        d_alpha_p_a = @view data.projector_derivatives[band_a, :, :, alpha]
        second = tr(
            p_b *
            d_alpha_p_a *
            p_a *
            @view(data.projector_second_derivatives[band_b, :, :, mu, beta]),
        )
        product = tr(
            p_b *
            d_alpha_p_a *
            p_a *
            (
                @view(data.projector_derivatives[band_a, :, :, mu]) *
                @view(data.projector_derivatives[band_b, :, :, beta]) +
                p_a * @view(data.external_geometry[:, :, mu, beta]) * p_b
            ),
        )
        temporaries = [zeros(ComplexF64, model.num_orbitals, model.num_orbitals) for _ in 1:3]
        full = PCF_RESPONSES.projector_qhc_trace_c_cvabc!(
            temporaries...,
            data,
            band_b,
            band_a,
            mu,
            alpha,
            beta,
        )
        return (; second, product, full)
    end

    convention_i = trace_terms(caches[1].central_data)
    convention_ii = trace_terms(caches[2].central_data)
    phases = [
        cis(2pi * dot(kpoint, @view(caches[1].scratch.wannier_centers_fractional[:, orbital])))
        for orbital in 1:model.num_orbitals
    ]
    transform(matrix) = Diagonal(conj.(phases)) * matrix * Diagonal(phases)
    covariant_residual(left, right) =
        norm(left - transform(right)) / max(norm(left), norm(right), 1.0)
    data_i = caches[1].central_data
    data_ii = caches[2].central_data
    @test covariant_residual(data_i.projectors[1, :, :], data_ii.projectors[1, :, :]) <= 1.0e-10
    @test covariant_residual(
        data_i.projector_derivatives[1, :, :, 1],
        data_ii.projector_derivatives[1, :, :, 1],
    ) <= 1.0e-10
    @test covariant_residual(
        data_i.projector_second_derivatives[1, :, :, 1, 1],
        data_ii.projector_second_derivatives[1, :, :, 1, 1],
    ) <= 1.0e-10
    @test covariant_residual(
        data_i.effective_connection[:, :, 1],
        data_ii.effective_connection[:, :, 1],
    ) <= 1.0e-10
    @test covariant_residual(
        data_i.effective_connection_derivatives[:, :, 1, 1],
        data_ii.effective_connection_derivatives[:, :, 1, 1],
    ) <= 1.0e-10
    @test covariant_residual(
        data_i.external_geometry[:, :, 1, 1],
        data_ii.external_geometry[:, :, 1, 1],
    ) <= 1.0e-10
    for name in propertynames(convention_i)
        first = getproperty(convention_i, name)
        second = getproperty(convention_ii, name)
        @test abs(first - second) / max(abs(first), abs(second), 1.0) <= 1.0e-10
    end
end

function pcf_write_fortran_record(io, values)
    bytes =
        values isa AbstractString ? Vector{UInt8}(codeunits(values)) :
        Vector{UInt8}(reinterpret(UInt8, vec(values)))
    marker = Int32(length(bytes))
    write(io, marker)
    write(io, bytes)
    write(io, marker)
end

@testset "Wannier90 uIu streaming reader" begin
    mktempdir() do directory
        path = joinpath(directory, "fixture.uIu")
        blocks = Dict{Tuple{Int, Int, Int}, Matrix{ComplexF64}}()
        open(path, "w") do io
            pcf_write_fortran_record(io, "uIu fixture")
            pcf_write_fortran_record(io, Int32[2, 2, 2])
            for ik in 1:2, nn2 in 1:2, nn1 in 1:2
                block = reshape(ComplexF64.(1:4) .+ (100ik + 10nn2 + nn1) .* (1.0 + 0.5im), 2, 2)
                blocks[(ik, nn2, nn1)] = Matrix(transpose(block))
                pcf_write_fortran_record(io, block)
            end
        end
        seen = Set{Tuple{Int, Int, Int}}()
        header = PCF_IO.foreach_wannier_uiu_block(path) do block, ik, nn2, nn1, callback_header
            @test callback_header.num_bands == 2
            @test block == blocks[(ik, nn2, nn1)]
            push!(seen, (ik, nn2, nn1))
        end
        @test header.num_kpts == 2
        @test header.num_neighbors == 2
        @test length(seen) == 8
        @test_throws ArgumentError PCF_IO.foreach_wannier_uiu_block(
            (_args...) -> nothing,
            path;
            expected_num_neighbors = 3,
        )
    end
end
