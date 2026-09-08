using LinearAlgebra
using Random
using Test
using WannierNLQG

const BERRY_MATRIX_ELEMENTS = WannierNLQG.MatrixElements
const BERRY_RESPONSES = WannierNLQG.Responses

function synthetic_curvature_data(num_orbitals::Int = 4)
    plan = BERRY_MATRIX_ELEMENTS.compile_matrix_plan(
        BERRY_MATRIX_ELEMENTS.MatrixElementRequest(
            BERRY_MATRIX_ELEMENTS.BERRY_CONNECTION,
            BERRY_MATRIX_ELEMENTS.WANNIER_CURVATURE;
            spatial_dimension = 2,
        ),
    )
    return BERRY_MATRIX_ELEMENTS.KPointMatrixData(num_orbitals, 0, plan)
end

function random_unitary(rng::AbstractRNG, count::Int)
    matrix = randn(rng, ComplexF64, count, count)
    return Matrix(qr(matrix).Q)
end

@testset "Wannier external curvature and occupied Berry sum" begin
    rng = MersenneTwister(20260711)
    data = synthetic_curvature_data()
    for direction in 1:2
        matrix = randn(rng, ComplexF64, 4, 4)
        data.berry_connection[:, :, direction] .= matrix + matrix'
    end
    external = randn(rng, ComplexF64, 4, 4)
    external = external + external'
    data.hamiltonian_curvature[:, :, 1, 2] .= external
    data.hamiltonian_curvature[:, :, 2, 1] .= -external

    for band in 1:4
        expected = real(external[band, band])
        for other_band in 1:4
            other_band == band && continue
            expected += real(
                1.0im * (
                    data.berry_connection[band, other_band, 1] *
                    data.berry_connection[other_band, band, 2] -
                    data.berry_connection[band, other_band, 2] *
                    data.berry_connection[other_band, band, 1]
                ),
            )
        end
        actual = BERRY_RESPONSES.berry_curvature_component(data, band, Int[1, 2], 4)
        @test actual ≈ ComplexF64(expected, 0.0) rtol = 1.0e-10 atol = 1.0e-12
    end

    occupations = [1.0, 0.7, 0.2, 0.0]
    weighted = sum(
        occupations[band] * BERRY_RESPONSES.berry_curvature_component(data, band, Int[1, 2], 4)
        for band in 1:4
    )
    occupied =
        BERRY_RESPONSES.berry_curvature_occupied_sum_component(data, Int[1, 2], 4, occupations)
    @test occupied ≈ weighted rtol = 1.0e-10 atol = 1.0e-12

    @test data.hamiltonian_curvature[:, :, 1, 2] ≈ data.hamiltonian_curvature[:, :, 1, 2]'
    @test data.hamiltonian_curvature[:, :, 1, 2] ≈ -data.hamiltonian_curvature[:, :, 2, 1]
end

@testset "Wannier curl and commutator algebra" begin
    rng = MersenneTwister(12072026)
    connection_x = randn(rng, ComplexF64, 3, 3)
    connection_y = randn(rng, ComplexF64, 3, 3)
    connection_x = connection_x + connection_x'
    connection_y = connection_y + connection_y'
    derivative_x_y = randn(rng, ComplexF64, 3, 3)
    derivative_y_x = randn(rng, ComplexF64, 3, 3)
    curl = derivative_x_y - derivative_y_x
    commutator = -1.0im * (connection_x * connection_y - connection_y * connection_x)
    full_xy = curl + commutator
    full_yx = -curl - commutator
    @test full_xy ≈ -full_yx rtol = 1.0e-10 atol = 1.0e-12
    @test commutator ≈ commutator' rtol = 1.0e-10 atol = 1.0e-12

    radius = [0.31, -0.27]
    position = randn(rng, ComplexF64, 3, 3, 2)
    fourier_derivative = zeros(ComplexF64, 3, 3, 2, 2)
    for beta in 1:2, alpha in 1:2
        fourier_derivative[:, :, beta, alpha] .= 1.0im * radius[alpha] .* position[:, :, beta]
    end
    expected_curl = 1.0im * radius[1] .* position[:, :, 2] .- 1.0im * radius[2] .* position[:, :, 1]
    @test fourier_derivative[:, :, 2, 1] - fourier_derivative[:, :, 1, 2] ≈ expected_curl rtol =
        1.0e-10 atol = 1.0e-12
end

@testset "Hermitian curvature tensor covariance" begin
    rng = MersenneTwister(7112026)
    data = synthetic_curvature_data()
    for direction in 1:2
        matrix = randn(rng, ComplexF64, 4, 4)
        data.berry_connection[:, :, direction] .= matrix + matrix'
    end
    external = randn(rng, ComplexF64, 4, 4)
    external = external + external'
    data.hamiltonian_curvature[:, :, 1, 2] .= external
    data.hamiltonian_curvature[:, :, 2, 1] .= -external
    groups = (Int[3, 4], Int[1, 2])
    indices = Int[2, 2, 1, 2]
    original = BERRY_RESPONSES.hermitian_curvature_tensor_component(data, groups, indices, 4)
    swapped = BERRY_RESPONSES.hermitian_curvature_tensor_component(data, groups, Int[2, 2, 2, 1], 4)
    @test original ≈ -swapped rtol = 1.0e-10 atol = 1.0e-12

    transform = zeros(ComplexF64, 4, 4)
    transform[1:2, 1:2] .= random_unitary(rng, 2)
    transform[3:4, 3:4] .= random_unitary(rng, 2)
    rotated = synthetic_curvature_data()
    for direction in 1:2
        rotated.berry_connection[:, :, direction] .=
            transform' * data.berry_connection[:, :, direction] * transform
    end
    for first_direction in 1:2, second_direction in 1:2
        rotated.hamiltonian_curvature[:, :, first_direction, second_direction] .=
            transform' *
            data.hamiltonian_curvature[:, :, first_direction, second_direction] *
            transform
    end
    rotated_value =
        BERRY_RESPONSES.hermitian_curvature_tensor_component(rotated, groups, indices, 4)
    @test rotated_value ≈ original rtol = 1.0e-10 atol = 1.0e-12

    single_groups = (Int[3], Int[1])
    single = BERRY_RESPONSES.hermitian_curvature_tensor_component(data, single_groups, indices, 4)
    f_final = BERRY_RESPONSES.berry_curvature_block_element(data, 3, 3, Int[3], (1, 2), 4)
    f_initial = BERRY_RESPONSES.berry_curvature_block_element(data, 1, 1, Int[1], (1, 2), 4)
    expected_single =
        -1.0im *
        data.berry_connection[1, 3, 2] *
        data.berry_connection[3, 1, 2] *
        (f_final - f_initial)
    @test single ≈ expected_single rtol = 1.0e-10 atol = 1.0e-12

    internal_only = deepcopy(data.hamiltonian_curvature)
    fill!(data.hamiltonian_curvature, 0.0)
    hct_internal = BERRY_RESPONSES.hermitian_curvature_tensor_component(data, groups, indices, 4)
    data.hamiltonian_curvature .= internal_only
    hct_full = BERRY_RESPONSES.hermitian_curvature_tensor_component(data, groups, indices, 4)
    external_delta = hct_full - hct_internal
    explicit_external = 0.0 + 0.0im
    final_group, initial_group = groups
    for initial_row in initial_group, final_row in final_group
        transported = 0.0 + 0.0im
        for final_column in final_group
            transported +=
                internal_only[final_row, final_column, 1, 2] *
                data.berry_connection[final_column, initial_row, 2]
        end
        for initial_column in initial_group
            transported -=
                data.berry_connection[final_row, initial_column, 2] *
                internal_only[initial_column, initial_row, 1, 2]
        end
        explicit_external += data.berry_connection[initial_row, final_row, 2] * transported
    end
    explicit_external *= -1.0im
    @test external_delta ≈ explicit_external rtol = 1.0e-10 atol = 1.0e-12
end
