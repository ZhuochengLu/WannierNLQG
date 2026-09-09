using Random

if !isdefined(@__MODULE__, :RESPONSE_TEST_SUPPORT_LOADED)
    include(joinpath(@__DIR__, "ResponseTestSupport.jl"))
end

const EXACT_RESPONSES = WannierNLQG.Responses
exact_bitwise_equal(left, right) = reinterpret(UInt8, vec(left)) == reinterpret(UInt8, vec(right))

@testset "SC and SSC compact pair lists preserve dense results" begin
    dense_sc_workspace = make_synthetic_ssc_workspace()
    list_sc_workspace = make_synthetic_ssc_workspace()
    active_mask = falses(3, 3)
    active_mask[1, 2] = true
    active_mask[3, 1] = true
    active_nmajor = NTuple{2, Int}[(1, 2), (3, 1)]
    derivative_nmajor = NTuple{2, Int}[(1, 2), (2, 1), (1, 3), (3, 1)]

    dense_sc = zeros(ComplexF64, 3, 3, 2, 2, 2)
    list_sc = zeros(ComplexF64, 3, 3, 2, 2, 2)
    dense_derivative = zeros(ComplexF64, 3, 3, 2, 2)
    list_derivative = zeros(ComplexF64, 3, 3, 2, 2)
    EXACT_RESPONSES.compute_conventional_shift_current_kernel!(
        dense_sc,
        dense_derivative,
        dense_sc_workspace.data,
        1,
        3,
        3,
        2;
        active_pair_mask = active_mask,
    )
    EXACT_RESPONSES.compute_conventional_shift_current_kernel!(
        list_sc,
        list_derivative,
        list_sc_workspace.data,
        1,
        3,
        3,
        2;
        active_pairs_nmajor = active_nmajor,
        active_pair_count = length(active_nmajor),
        derivative_required_pairs_nmajor = derivative_nmajor,
        derivative_pair_count = length(derivative_nmajor),
    )
    @test exact_bitwise_equal(dense_derivative, list_derivative)
    @test exact_bitwise_equal(dense_sc, list_sc)

    dense_ssc_workspace = make_synthetic_ssc_workspace()
    list_ssc_workspace = make_synthetic_ssc_workspace()
    EXACT_RESPONSES.compute_shift_spin_current_vertices!(dense_ssc_workspace, 1.0e-3, 2)
    EXACT_RESPONSES.compute_shift_spin_current_vertices!(list_ssc_workspace, 1.0e-3, 2)
    EXACT_RESPONSES.compute_shift_spin_current_kernel!(
        dense_ssc_workspace,
        1,
        3,
        2;
        active_pair_mask = active_mask,
    )
    EXACT_RESPONSES.compute_shift_spin_current_kernel!(
        list_ssc_workspace,
        1,
        3,
        2;
        active_pairs_nmajor = active_nmajor,
        active_pair_count = length(active_nmajor),
    )
    @test exact_bitwise_equal(
        dense_ssc_workspace.response_kernel,
        list_ssc_workspace.response_kernel,
    )
end

@testset "SC and SSC list accumulators preserve pair order" begin
    Random.seed!(0xac71ee)
    count = 5
    dimension = 2
    num_frequencies = 7
    active_nmajor = NTuple{2, Int}[(1, 3), (2, 5), (4, 1)]
    active_mmajor = NTuple{2, Int}[(4, 1), (1, 3), (2, 5)]
    occupations = zeros(Float64, count, count)
    delta = zeros(Float64, num_frequencies, count, count)
    for (n, m) in active_nmajor
        occupations[n, m] = randn()
        delta[:, n, m] .= rand(num_frequencies)
    end
    sc_kernel = randn(ComplexF64, count, count, dimension, dimension, dimension)
    sc_dense = zeros(ComplexF64, num_frequencies, dimension, dimension, dimension)
    sc_list = zeros(ComplexF64, num_frequencies, dimension, dimension, dimension)
    EXACT_RESPONSES.accumulate_conventional_response!(
        sc_dense,
        sc_kernel,
        occupations,
        delta,
        0.37im,
        1,
        count,
        dimension,
    )
    EXACT_RESPONSES.accumulate_conventional_response!(
        sc_list,
        sc_kernel,
        occupations,
        delta,
        0.37im,
        1,
        count,
        dimension;
        active_pairs_mmajor = active_mmajor,
        active_pair_count = length(active_mmajor),
    )
    @test exact_bitwise_equal(sc_dense, sc_list)
    sc_component_dense = EXACT_RESPONSES.conventional_component_response(
        sc_kernel,
        occupations,
        @view(delta[1, :, :]),
        0.37im,
        [1, 1, 1],
        1,
        count,
    )
    sc_component_list = EXACT_RESPONSES.conventional_component_response(
        sc_kernel,
        occupations,
        @view(delta[1, :, :]),
        0.37im,
        [1, 1, 1],
        1,
        count;
        active_pairs_mmajor = active_mmajor,
        active_pair_count = length(active_mmajor),
    )
    @test reinterpret(UInt64, [sc_component_dense]) == reinterpret(UInt64, [sc_component_list])

    energy_differences = randn(count, count)
    ssc_kernel = randn(ComplexF64, count, count, dimension, 3, dimension, dimension)
    ssc_dense = zeros(ComplexF64, num_frequencies, dimension, 3, dimension, dimension)
    ssc_list = zeros(ComplexF64, num_frequencies, dimension, 3, dimension, dimension)
    EXACT_RESPONSES.accumulate_shift_spin_current_response!(
        ssc_dense,
        ssc_kernel,
        occupations,
        delta,
        energy_differences,
        1.0e-3,
        0.37im,
        1,
        count,
        dimension,
    )
    EXACT_RESPONSES.accumulate_shift_spin_current_response!(
        ssc_list,
        ssc_kernel,
        occupations,
        delta,
        energy_differences,
        1.0e-3,
        0.37im,
        1,
        count,
        dimension;
        active_pairs_nmajor = active_nmajor,
        active_pair_count = length(active_nmajor),
    )
    @test exact_bitwise_equal(ssc_dense, ssc_list)
    ssc_component_dense = EXACT_RESPONSES.shift_spin_current_component(
        ssc_kernel,
        occupations,
        @view(delta[1, :, :]),
        energy_differences,
        1.0e-3,
        0.37im,
        [1, 1, 1, 1],
        1,
        count,
    )
    ssc_component_list = EXACT_RESPONSES.shift_spin_current_component(
        ssc_kernel,
        occupations,
        @view(delta[1, :, :]),
        energy_differences,
        1.0e-3,
        0.37im,
        [1, 1, 1, 1],
        1,
        count;
        active_pairs_nmajor = active_nmajor,
        active_pair_count = length(active_nmajor),
    )
    @test reinterpret(UInt64, [ssc_component_dense]) == reinterpret(UInt64, [ssc_component_list])
end

@testset "large-frequency exact layout is bitwise" begin
    Random.seed!(0xf2e9ee)
    dimension = 2
    num_frequencies = 200

    sc_count = 32
    sc_occupations = randn(sc_count, sc_count)
    sc_delta = rand((0.0, 0.5, 1.0), num_frequencies, sc_count, sc_count)
    sc_kernel = randn(ComplexF64, sc_count, sc_count, dimension, dimension, dimension)
    sc_baseline = zeros(ComplexF64, num_frequencies, dimension, dimension, dimension)
    sc_candidate = zeros(ComplexF64, num_frequencies, dimension, dimension, dimension)
    sc_weights = zeros(Float64, num_frequencies)
    EXACT_RESPONSES.accumulate_conventional_response!(
        sc_baseline,
        sc_kernel,
        sc_occupations,
        sc_delta,
        0.37im,
        1,
        sc_count,
        dimension,
    )
    EXACT_RESPONSES.accumulate_conventional_response!(
        sc_candidate,
        sc_kernel,
        sc_occupations,
        sc_delta,
        0.37im,
        1,
        sc_count,
        dimension;
        frequency_weights = sc_weights,
    )
    @test exact_bitwise_equal(sc_baseline, sc_candidate)

    ssc_count = 16
    ssc_occupations = randn(ssc_count, ssc_count)
    ssc_delta = rand((0.0, 0.5, 1.0), num_frequencies, ssc_count, ssc_count)
    energy_differences = randn(ssc_count, ssc_count)
    ssc_kernel = randn(ComplexF64, ssc_count, ssc_count, dimension, 3, dimension, dimension)
    ssc_baseline = zeros(ComplexF64, num_frequencies, dimension, 3, dimension, dimension)
    ssc_candidate = zeros(ComplexF64, num_frequencies, dimension, 3, dimension, dimension)
    ssc_weights = zeros(Float64, num_frequencies)
    EXACT_RESPONSES.accumulate_shift_spin_current_response!(
        ssc_baseline,
        ssc_kernel,
        ssc_occupations,
        ssc_delta,
        energy_differences,
        1.0e-3,
        0.37im,
        1,
        ssc_count,
        dimension,
    )
    EXACT_RESPONSES.accumulate_shift_spin_current_response!(
        ssc_candidate,
        ssc_kernel,
        ssc_occupations,
        ssc_delta,
        energy_differences,
        1.0e-3,
        0.37im,
        1,
        ssc_count,
        dimension;
        frequency_weights = ssc_weights,
    )
    @test exact_bitwise_equal(ssc_baseline, ssc_candidate)
end
