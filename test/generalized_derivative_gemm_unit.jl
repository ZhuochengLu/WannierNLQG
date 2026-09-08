using Random

const GEMM_RESPONSES = WannierNLQG.Responses

function fill_generalized_derivative_test_data!(data, rng)
    data.internal_connection .= randn(rng, ComplexF64, size(data.internal_connection))
    data.gauge_correction .= randn(rng, ComplexF64, size(data.gauge_correction))
    data.hamiltonian_derivatives .= randn(rng, ComplexF64, size(data.hamiltonian_derivatives))
    data.internal_connection_derivatives .=
        randn(rng, ComplexF64, size(data.internal_connection_derivatives))
    data.hamiltonian_second_derivatives .=
        randn(rng, ComplexF64, size(data.hamiltonian_second_derivatives))
    data.inverse_energy_differences .= randn(rng, size(data.inverse_energy_differences))
    data.berry_connection .= randn(rng, ComplexF64, size(data.berry_connection))
    return data
end

function copy_generalized_derivative_test_data!(target, source)
    for name in (
        :internal_connection,
        :gauge_correction,
        :hamiltonian_derivatives,
        :internal_connection_derivatives,
        :hamiltonian_second_derivatives,
        :inverse_energy_differences,
        :berry_connection,
    )
        getproperty(target, name) .= getproperty(source, name)
    end
    return target
end

function nonfinite_signature(values)
    return (
        nan = count(isnan, values),
        positive_inf = count(==(Inf), values),
        negative_inf = count(==(-Inf), values),
    )
end

function generalized_derivative_l2_relative(candidate, reference)
    reference_norm = norm(reference)
    return reference_norm == 0.0 ? norm(candidate - reference) :
           norm(candidate - reference) / reference_norm
end

@testset "generalized-position derivative scalar and GEMM oracle" begin
    cases = (
        (num_orbitals = 1, dimension = 2, band_start = 1, band_end = 1, density = :empty),
        (num_orbitals = 2, dimension = 3, band_start = 1, band_end = 2, density = :sparse),
        (num_orbitals = 16, dimension = 2, band_start = 1, band_end = 16, density = :sparse),
        (num_orbitals = 32, dimension = 3, band_start = 9, band_end = 24, density = :dense),
        (num_orbitals = 64, dimension = 2, band_start = 1, band_end = 64, density = :dense),
    )
    for case in cases
        @testset "N=$(case.num_orbitals) D=$(case.dimension) $(case.density)" begin
            N = case.num_orbitals
            scalar =
                GEMM_RESPONSES.make_shift_current_conventional_workspace(N, 1, case.dimension, 1)
            explicit_scalar =
                GEMM_RESPONSES.make_shift_current_conventional_workspace(N, 1, case.dimension, 1)
            gemm = GEMM_RESPONSES.make_shift_current_conventional_workspace(N, 1, case.dimension, 1)
            fill_generalized_derivative_test_data!(scalar.data, MersenneTwister(0x6d10 + N))
            copy_generalized_derivative_test_data!(explicit_scalar.data, scalar.data)
            copy_generalized_derivative_test_data!(gemm.data, scalar.data)

            candidate_pairs = NTuple{2, Int}[]
            if case.density === :sparse
                case.band_end > case.band_start &&
                    push!(candidate_pairs, (case.band_start, case.band_end))
            elseif case.density === :dense
                for n in case.band_start:case.band_end
                    for m in case.band_start:case.band_end
                        n == m || push!(candidate_pairs, (n, m))
                    end
                end
            end
            derivative_pairs = copy(candidate_pairs)
            for (n, m) in candidate_pairs
                (m, n) in derivative_pairs || push!(derivative_pairs, (m, n))
            end
            common_keywords = (
                active_pairs_nmajor = candidate_pairs,
                active_pair_count = length(candidate_pairs),
                derivative_required_pairs_nmajor = derivative_pairs,
                derivative_pair_count = length(derivative_pairs),
            )
            GEMM_RESPONSES.compute_conventional_shift_current_kernel!(
                scalar.response_kernel,
                scalar.generalized_position_derivative,
                scalar.data,
                case.band_start,
                case.band_end,
                N,
                case.dimension;
                common_keywords...,
            )
            GEMM_RESPONSES.compute_conventional_shift_current_kernel!(
                explicit_scalar.response_kernel,
                explicit_scalar.generalized_position_derivative,
                explicit_scalar.data,
                case.band_start,
                case.band_end,
                N,
                case.dimension;
                common_keywords...,
                _generalized_derivative_scratch = explicit_scalar.generalized_derivative_scratch,
                _generalized_derivative_strategy = :scalar,
            )
            forced_strategy =
                case.band_end - case.band_start + 1 == N ? :full_gemm : :rectangular_gemm
            GEMM_RESPONSES.compute_conventional_shift_current_kernel!(
                gemm.response_kernel,
                gemm.generalized_position_derivative,
                gemm.data,
                case.band_start,
                case.band_end,
                N,
                case.dimension;
                common_keywords...,
                _generalized_derivative_scratch = gemm.generalized_derivative_scratch,
                _generalized_derivative_strategy = forced_strategy,
            )

            @test reinterpret(UInt64, vec(scalar.generalized_position_derivative)) ==
                  reinterpret(UInt64, vec(explicit_scalar.generalized_position_derivative))
            @test reinterpret(UInt64, vec(scalar.response_kernel)) ==
                  reinterpret(UInt64, vec(explicit_scalar.response_kernel))
            @test isapprox(
                gemm.generalized_position_derivative,
                scalar.generalized_position_derivative;
                atol = 1.0e-10,
                rtol = 1.0e-8,
            )
            @test isapprox(
                gemm.response_kernel,
                scalar.response_kernel;
                atol = 1.0e-10,
                rtol = 1.0e-8,
            )
            @test generalized_derivative_l2_relative(
                gemm.generalized_position_derivative,
                scalar.generalized_position_derivative,
            ) <= 1.0e-9
            @test generalized_derivative_l2_relative(
                gemm.response_kernel,
                scalar.response_kernel,
            ) <= 1.0e-9
            @test nonfinite_signature(gemm.generalized_position_derivative) ==
                  nonfinite_signature(scalar.generalized_position_derivative)
            @test nonfinite_signature(gemm.response_kernel) ==
                  nonfinite_signature(scalar.response_kernel)
        end
    end
end

@testset "generalized-position derivative auto strategy" begin
    select_strategy = GEMM_RESPONSES._select_conventional_generalized_derivative_strategy
    @test select_strategy(64, 64, 64) === :scalar
    @test select_strategy(16, 16, 16 * 16) === :scalar
    @test select_strategy(64, 32, 32 * 32) === :rectangular_gemm
    @test select_strategy(64, 16, 16 * 16) === :scalar
    @test select_strategy(64, 32, floor(Int, 0.69 * 32 * 32)) === :scalar
    @test select_strategy(32, 32, 32 * 32) === :scalar
    @test select_strategy(64, 64, 64 * 64) === :full_gemm
    @test select_strategy(64, 64, 2; qhc = true) === :scalar
    @test select_strategy(128, 128, 64 * 64; qhc = true) === :scalar
end

@testset "Conventional QHC keeps small selections scalar and validates full GEMM" begin
    N = 64
    dimension = 3
    workspace = GEMM_RESPONSES.make_conventional_quantum_geometry_workspace(N, 1, dimension, 1)
    fill_generalized_derivative_test_data!(workspace.data, MersenneTwister(0x6d30))
    tensor_indices = [1, 2, 3]
    dense_selection = (collect(33:64), collect(1:32))
    gemm_scratch = GEMM_RESPONSES._ConventionalGeneralizedDerivativeScratch(N)
    scalar = GEMM_RESPONSES.conventional_quantum_hermitian_connection_component(
        workspace.data,
        dense_selection,
        tensor_indices,
        N,
    )
    gemm = GEMM_RESPONSES._conventional_quantum_hermitian_connection_component_gemm(
        workspace.data,
        gemm_scratch,
        dense_selection,
        tensor_indices,
        N,
    )
    @test isapprox(gemm, scalar; atol = 1.0e-10, rtol = 1.0e-8)
    @test abs(gemm - scalar) / max(abs(scalar), eps()) <= 1.0e-9
    @test nonfinite_signature([gemm]) == nonfinite_signature([scalar])

    small_selection = ([64], [1])
    default_scalar = GEMM_RESPONSES.conventional_quantum_hermitian_connection_component(
        workspace.data,
        small_selection,
        tensor_indices,
        N,
    )
    repeated_scalar = GEMM_RESPONSES.conventional_quantum_hermitian_connection_component(
        workspace.data,
        small_selection,
        tensor_indices,
        N,
    )
    @test reinterpret(UInt64, [repeated_scalar]) == reinterpret(UInt64, [default_scalar])
end
