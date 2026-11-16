using Test
if !isdefined(@__MODULE__, :PanelGemmComparisonSupport)
    include(joinpath(@__DIR__, "PanelGemmComparisonSupport.jl"))
end

@testset "Componentwise cross-shape GEMM comparison rejects corrupted values" begin
    support = PanelGemmComparisonSupport
    @test support.floating_environment().round_to_nearest
    @test support.floating_environment().gradual_underflow
    @test_throws ArgumentError support._require_environment((;
        round_to_nearest = false,
        gradual_underflow = true,
    ),)
    @test_throws ArgumentError support._require_environment((;
        round_to_nearest = true,
        gradual_underflow = false,
    ),)

    # Exact integer arithmetic: (1+2i)(5-6i)+(3-4i)(7+8i)=70+0i.
    left = ComplexF64[1+2im 3-4im]
    right = reshape(ComplexF64[5 - 6im, 7 + 8im], 2, 1)
    reference = fill(ComplexF64(70, 0), 1, 1)
    compare(actual) = support.compare_link_panels(actual, reference, left, right, [1])
    @test compare(reference).accepted
    @test compare(fill(ComplexF64(nextfloat(70.0), eps(70.0)), 1, 1)).accepted
    @test !compare(fill(ComplexF64(70, 1e-6), 1, 1)).accepted
    @test !compare(-reference).accepted
    # Removing an intermediate contribution or changing a conjugation is not rounding.
    @test !compare(fill(left[1, 1] * right[1, 1], 1, 1)).accepted
    @test !compare(fill(sum(conj(left[1, k]) * right[k, 1] for k in 1:2), 1, 1)).accepted
    scales = support._component_scales(((left, right),), 1, 1)
    @test scales[1] >= 70 && scales[2] >= 68
    # Independent exact-rational check of the normal gamma part of the bound.
    u = BigInt(1) // (BigInt(1) << 53)
    gamma = 6u / (1 - 6u)
    parameters = support._roundoff_parameters(2, 1)
    @test Rational{BigInt}(support._allowed_error(scales[1], parameters)) >= 2gamma * 70
    @test parameters.rounds == 12 && parameters.m == 6
    near_zero = compare(fill(ComplexF64(70, eps(70.0)), 1, 1))
    @test near_zero.near_zero == 1
    @test near_zero.maximum_relative == 1
    @test near_zero.near_zero_absolute > 0

    # The bound follows the input scale, including cancellation near zero.
    small_left = left .* 2.0^-300
    small_reference = reference .* 2.0^-300
    @test support.compare_link_panels(small_reference, small_reference, small_left, right, [1]).accepted
    corrupted = copy(small_reference)
    corrupted[1, 1] += 1e-20im
    @test !support.compare_link_panels(corrupted, small_reference, small_left, right, [1]).accepted

    # Each vertex includes both original products, in the original order.
    velocity_left = reshape(ComplexF64[2 + 3im], 1, 1)
    velocity_right = reshape(ComplexF64[5 - 7im], 1, 1)
    overlap = reshape(ComplexF64[11 + 13im], 1, 1)
    vertex_reference = velocity_left * overlap + overlap * velocity_right
    @test support.compare_vertex_panels(
        vertex_reference,
        vertex_reference,
        velocity_left,
        velocity_right,
        overlap,
        [1],
    ).accepted
    @test !support.compare_vertex_panels(
        velocity_left * overlap,
        vertex_reference,
        velocity_left,
        velocity_right,
        overlap,
        [1],
    ).accepted
    @test !support.compare_vertex_panels(
        velocity_left * overlap - overlap * velocity_right,
        vertex_reference,
        velocity_left,
        velocity_right,
        overlap,
        [1],
    ).accepted
    vertex_scales =
        support._component_scales(((velocity_left, overlap), (overlap, velocity_right)), 1, 1)
    @test vertex_scales[1] >= 207 && vertex_scales[2] >= 201
    @test support._roundoff_parameters(1, 2).rounds == 16

    zero = zeros(ComplexF64, 1, 1)
    tiny = nextfloat(0.0)
    @test support.compare_link_panels(zero, zero, zero, zero, [1]).zero_scale == 2
    @test !support.compare_link_panels(fill(ComplexF64(tiny, 0), 1, 1), zero, zero, zero, [1]).accepted
    underflow_left = fill(ComplexF64(tiny, 0), 1, 1)
    half = fill(ComplexF64(0.5, 0), 1, 1)
    @test support._component_scales(((underflow_left, half),), 1, 1)[1] > 0
    @test support.compare_link_panels(zero, zero, underflow_left, half, [1]).accepted
    @test !support.compare_link_panels(
        fill(ComplexF64(1e-300, 0), 1, 1),
        zero,
        underflow_left,
        half,
        [1],
    ).accepted
    @test_throws ArgumentError support.compare_link_panels(
        fill(ComplexF64(Inf), 1, 1),
        zero,
        zero,
        zero,
        [1],
    )
    @test_throws ArgumentError support.compare_link_panels(
        zero,
        zero,
        fill(ComplexF64(NaN), 1, 1),
        zero,
        [1],
    )
    @test_throws ArgumentError support.compare_link_panels(
        zero,
        zero,
        fill(ComplexF64(floatmax(Float64)), 1, 1),
        fill(ComplexF64(2), 1, 1),
        [1],
    )
    @test_throws BoundsError support.compare_link_panels(zero, zero, zero, zero, [2])
    @test_throws DimensionMismatch support.compare_link_panels(zero, zero, left, zero, [1])

    # Choose the reference by the frozen branch, never by the observed residual.
    output = zeros(ComplexF64, 256, 256)
    first_factor = ones(ComplexF64, 256, 256)
    second_factor = copy(first_factor)
    @test support.link_panel_case(output, first_factor, second_factor, [2, 63])
    @test !support.link_panel_case(output, first_factor, second_factor, [2, 130])
    @test support.vertex_panel_case(output, first_factor, second_factor, second_factor, [2, 130])
    @test !support.link_panel_case(output, first_factor, second_factor, Int[])
    @test !support.link_panel_case(output, first_factor, second_factor, [63, 2])
    @test !support.link_panel_case(first_factor, first_factor, second_factor, [2])
    first_factor[1, 1] = Inf
    @test !support.vertex_panel_case(output, first_factor, second_factor, second_factor, [2])
end
