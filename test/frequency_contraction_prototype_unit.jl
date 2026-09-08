using Test
using Random
using LinearAlgebra
using WannierNLQG

const FREQUENCY_RESPONSES = WannierNLQG.Responses

function frequency_nonfinite_signature(values)
    components = reinterpret(Float64, vec(values))
    return (
        nan = count(isnan, components),
        positive_inf = count(==(Inf), components),
        negative_inf = count(==(-Inf), components),
    )
end

function frequency_l2_relative(candidate, reference)
    reference_norm = norm(reference)
    return reference_norm == 0.0 ? norm(candidate - reference) :
           norm(candidate - reference) / reference_norm
end

function run_frequency_prototype!(
    output,
    kernel,
    occupation_differences,
    delta,
    prefactor,
    band_start,
    band_end,
    scratch,
    strategy,
    pair_order,
    pair_weights,
    frequency_weights,
)
    return FREQUENCY_RESPONSES._accumulate_frequency_contraction_prototype!(
        output,
        kernel,
        occupation_differences,
        delta,
        prefactor,
        band_start,
        band_end,
        band_start,
        band_end,
        scratch,
        strategy = strategy,
        pair_order = pair_order,
        pair_weights = pair_weights,
        frequency_weights = frequency_weights,
    )
end

@testset "full Integral frequency-contraction prototypes" begin
    workload_cases = (
        (name = :sc, tensor_count = 27, pair_order = :mmajor, pair = false, frequency = false),
        (name = :ic, tensor_count = 27, pair_order = :nmajor, pair = false, frequency = false),
        (name = :isc, tensor_count = 81, pair_order = :nmajor, pair = false, frequency = false),
        (name = :ssc, tensor_count = 81, pair_order = :nmajor, pair = true, frequency = false),
        (name = :pdic, tensor_count = 27, pair_order = :nmajor, pair = false, frequency = true),
    )
    for num_orbitals in (4, 16)
        for frequency_count in (1, 20, 200)
            for workload in workload_cases
                rng =
                    MersenneTwister(0x8d10 + num_orbitals + frequency_count + workload.tensor_count)
                band_start = num_orbitals == 4 ? 1 : 5
                band_end = num_orbitals == 4 ? 4 : 12
                occupation_differences = randn(rng, num_orbitals, num_orbitals)
                delta = randn(rng, frequency_count, num_orbitals, num_orbitals)
                kernel = randn(rng, ComplexF64, num_orbitals, num_orbitals, workload.tensor_count)
                pair_weights = workload.pair ? rand(rng, num_orbitals, num_orbitals) : nothing
                frequency_weights = workload.frequency ? rand(rng, frequency_count) : nothing
                initial_output = randn(rng, ComplexF64, frequency_count, workload.tensor_count)
                oracle = copy(initial_output)
                FREQUENCY_RESPONSES._accumulate_frequency_contraction_scalar_oracle!(
                    oracle,
                    kernel,
                    occupation_differences,
                    delta,
                    0.37 - 0.19im,
                    band_start,
                    band_end,
                    band_start,
                    band_end,
                    pair_order = workload.pair_order,
                    pair_weights = pair_weights,
                    frequency_weights = frequency_weights,
                )
                for strategy in FREQUENCY_RESPONSES._FREQUENCY_CONTRACTION_STRATEGIES
                    candidate = copy(initial_output)
                    scratch = FREQUENCY_RESPONSES._FrequencyContractionScratch(
                        frequency_count,
                        workload.tensor_count,
                        pair_block = 32,
                    )
                    run_frequency_prototype!(
                        candidate,
                        kernel,
                        occupation_differences,
                        delta,
                        0.37 - 0.19im,
                        band_start,
                        band_end,
                        scratch,
                        strategy,
                        workload.pair_order,
                        pair_weights,
                        frequency_weights,
                    )
                    @test isapprox(candidate, oracle; atol = 1.0e-10, rtol = 1.0e-8)
                    @test frequency_l2_relative(candidate, oracle) <= 1.0e-9
                    @test frequency_nonfinite_signature(candidate) ==
                          frequency_nonfinite_signature(oracle)
                end
            end
        end
    end
end

@testset "frequency-contraction scalar default remains exact" begin
    rng = MersenneTwister(0x8d40)
    num_orbitals = 8
    frequency_count = 20
    spatial_dimension = 2
    occupation_differences = randn(rng, num_orbitals, num_orbitals)
    delta = randn(rng, frequency_count, num_orbitals, num_orbitals)
    response_kernel = randn(
        rng,
        ComplexF64,
        num_orbitals,
        num_orbitals,
        spatial_dimension,
        spatial_dimension,
        spatial_dimension,
    )
    initial_output = randn(
        rng,
        ComplexF64,
        frequency_count,
        spatial_dimension,
        spatial_dimension,
        spatial_dimension,
    )
    default_output = copy(initial_output)
    oracle_output = copy(initial_output)
    FREQUENCY_RESPONSES.accumulate_injection_current_response!(
        default_output,
        response_kernel,
        occupation_differences,
        delta,
        0.31,
        1,
        num_orbitals,
        spatial_dimension,
    )
    FREQUENCY_RESPONSES._accumulate_frequency_contraction_scalar_oracle!(
        oracle_output,
        response_kernel,
        occupation_differences,
        delta,
        0.31,
        1,
        num_orbitals,
        1,
        num_orbitals,
        pair_order = :nmajor,
    )
    @test reinterpret(UInt64, vec(default_output)) == reinterpret(UInt64, vec(oracle_output))
end

@testset "full Integral production frequency auto" begin
    rng = MersenneTwister(0x8d60)
    num_orbitals = 16
    frequency_count = 200
    spatial_dimension = 2
    occupation_differences = randn(rng, num_orbitals, num_orbitals)
    delta = randn(rng, frequency_count, num_orbitals, num_orbitals)

    scratch_27 = FREQUENCY_RESPONSES._FrequencyContractionScratch(
        frequency_count,
        spatial_dimension^3,
        pair_block = 64,
    )
    scratch_81 = FREQUENCY_RESPONSES._FrequencyContractionScratch(
        frequency_count,
        3 * spatial_dimension^3,
        pair_block = 64,
    )
    @test FREQUENCY_RESPONSES._select_frequency_contraction_strategy(
        frequency_count,
        num_orbitals^2,
        nothing,
        scratch_27,
    ) === :split_real_gemm
    @test FREQUENCY_RESPONSES._select_frequency_contraction_strategy(
        20,
        num_orbitals^2,
        nothing,
        scratch_27,
    ) === :scalar
    @test FREQUENCY_RESPONSES._select_frequency_contraction_strategy(
        frequency_count,
        num_orbitals^2,
        NTuple{2, Int}[(1, 2)],
        scratch_27,
    ) === :scalar

    kernel_3 = randn(
        rng,
        ComplexF64,
        num_orbitals,
        num_orbitals,
        spatial_dimension,
        spatial_dimension,
        spatial_dimension,
    )
    kernel_4 = randn(
        rng,
        ComplexF64,
        num_orbitals,
        num_orbitals,
        spatial_dimension,
        3,
        spatial_dimension,
        spatial_dimension,
    )
    for workload in (:sc, :ic, :isc, :ssc, :pdic)
        is_spin = workload in (:isc, :ssc)
        shape =
            is_spin ?
            (frequency_count, spatial_dimension, 3, spatial_dimension, spatial_dimension) :
            (frequency_count, spatial_dimension, spatial_dimension, spatial_dimension)
        initial = randn(rng, ComplexF64, shape)
        scalar = copy(initial)
        candidate = copy(initial)
        if workload === :sc
            FREQUENCY_RESPONSES.accumulate_conventional_response!(
                scalar,
                kernel_3,
                occupation_differences,
                delta,
                0.23,
                1,
                num_orbitals,
                spatial_dimension,
            )
            FREQUENCY_RESPONSES.accumulate_conventional_response!(
                candidate,
                kernel_3,
                occupation_differences,
                delta,
                0.23,
                1,
                num_orbitals,
                spatial_dimension,
                _frequency_contraction_scratch = scratch_27,
            )
        elseif workload === :ic
            FREQUENCY_RESPONSES.accumulate_injection_current_response!(
                scalar,
                kernel_3,
                occupation_differences,
                delta,
                0.23,
                1,
                num_orbitals,
                spatial_dimension,
            )
            FREQUENCY_RESPONSES.accumulate_injection_current_response!(
                candidate,
                kernel_3,
                occupation_differences,
                delta,
                0.23,
                1,
                num_orbitals,
                spatial_dimension,
                _frequency_contraction_scratch = scratch_27,
            )
        elseif workload === :isc
            FREQUENCY_RESPONSES.accumulate_injection_spin_current_response!(
                scalar,
                kernel_4,
                occupation_differences,
                delta,
                0.23,
                1,
                num_orbitals,
                spatial_dimension,
            )
            FREQUENCY_RESPONSES.accumulate_injection_spin_current_response!(
                candidate,
                kernel_4,
                occupation_differences,
                delta,
                0.23,
                1,
                num_orbitals,
                spatial_dimension,
                _frequency_contraction_scratch = scratch_81,
            )
        elseif workload === :ssc
            energy_differences = randn(rng, num_orbitals, num_orbitals)
            pair_weights = zeros(Float64, num_orbitals, num_orbitals)
            FREQUENCY_RESPONSES.accumulate_shift_spin_current_response!(
                scalar,
                kernel_4,
                occupation_differences,
                delta,
                energy_differences,
                0.017,
                0.0 + 0.23im,
                1,
                num_orbitals,
                spatial_dimension,
            )
            FREQUENCY_RESPONSES.accumulate_shift_spin_current_response!(
                candidate,
                kernel_4,
                occupation_differences,
                delta,
                energy_differences,
                0.017,
                0.0 + 0.23im,
                1,
                num_orbitals,
                spatial_dimension,
                frequency_pair_weights = pair_weights,
                _frequency_contraction_scratch = scratch_81,
            )
        else
            denominator_weights = rand(rng, frequency_count)
            FREQUENCY_RESPONSES.accumulate_photon_drag_injection_current_response!(
                scalar,
                kernel_3,
                occupation_differences,
                delta,
                denominator_weights,
                0.23,
                1,
                num_orbitals,
                1,
                num_orbitals,
                spatial_dimension,
            )
            FREQUENCY_RESPONSES.accumulate_photon_drag_injection_current_response!(
                candidate,
                kernel_3,
                occupation_differences,
                delta,
                denominator_weights,
                0.23,
                1,
                num_orbitals,
                1,
                num_orbitals,
                spatial_dimension,
                _frequency_contraction_scratch = scratch_27,
            )
        end
        @test isapprox(candidate, scalar; atol = 1.0e-10, rtol = 1.0e-8)
        @test frequency_l2_relative(candidate, scalar) <= 1.0e-9
        @test frequency_nonfinite_signature(candidate) == frequency_nonfinite_signature(scalar)
    end
end
