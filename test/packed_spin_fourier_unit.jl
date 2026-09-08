using LinearAlgebra

const PACKED_SPIN_IO = WannierNLQG.IO
const PACKED_SPIN_ME = WannierNLQG.MatrixElements
const PACKED_SPIN_CORE = WannierNLQG.Core

function packed_spin_test_model(num_orbitals, num_r_vectors)
    return PACKED_SPIN_CORE.TightBindingModel(
        Matrix{Float64}(I, 3, 3),
        num_orbitals,
        num_r_vectors,
        ones(Int, num_r_vectors),
        [0 1; 0 0; 0 0],
        zeros(ComplexF64, num_orbitals, num_orbitals, num_r_vectors),
        zeros(ComplexF64, num_orbitals, num_orbitals, 3, num_r_vectors),
    )
end

function packed_spin_values(num_orbitals, rank)
    shape = (num_orbitals, num_orbitals, ntuple(_ -> 3, rank)..., 2)
    values = Array{ComplexF64}(undef, shape)
    for index in CartesianIndices(values)
        values[index] = ComplexF64(sum(Tuple(index)), prod(Tuple(index))) / 32
    end
    return values
end

@testset "Packed spin-family Fourier matches materialized arrays" begin
    num_orbitals = 4
    model = packed_spin_test_model(num_orbitals, 2)
    factors = ComplexF64[1.0 + 0.0im, 0.25 - 0.5im]
    plan = PACKED_SPIN_ME.MatrixElementPlan(UInt64(0), UInt64(0), 2, 0.0, 0.0)

    rank_one = packed_spin_values(num_orbitals, 1)
    rank_one_components =
        Dict((Int8(axis), Int8(0)) => copy(@view(rank_one[:, :, axis, :])) for axis in 1:3)
    packed_rank_one = PACKED_SPIN_IO.PackedCartesianOperator(
        1,
        rank_one_components,
        (num_orbitals, num_orbitals, 2),
    )
    rank_one_array_result = zeros(ComplexF64, num_orbitals, num_orbitals, 3)
    rank_one_packed_result = similar(rank_one_array_result)
    PACKED_SPIN_ME._fourier_operator!(
        rank_one_array_result,
        rank_one,
        model,
        factors,
        plan,
        PACKED_SPIN_ME.SPIN_TIMES_HAMILTONIAN,
    )
    PACKED_SPIN_ME._fourier_operator!(
        rank_one_packed_result,
        packed_rank_one,
        model,
        factors,
        plan,
        PACKED_SPIN_ME.SPIN_TIMES_HAMILTONIAN,
    )
    rank_one_error = rank_one_packed_result .- rank_one_array_result
    @test maximum(abs, rank_one_error; init = 0.0) == 0.0
    @test count(value -> !isfinite(value), rank_one_packed_result) == 0

    rank_two = packed_spin_values(num_orbitals, 2)
    rank_two_components = Dict(
        (Int8(first_axis), Int8(second_axis)) =>
            copy(@view(rank_two[:, :, first_axis, second_axis, :])) for first_axis in 1:3 for
        second_axis in 1:3
    )
    packed_rank_two = PACKED_SPIN_IO.PackedCartesianOperator(
        2,
        rank_two_components,
        (num_orbitals, num_orbitals, 2),
    )
    for kind in (PACKED_SPIN_ME.SPIN_TIMES_POSITION, PACKED_SPIN_ME.SPIN_TIMES_HAMILTONIAN_POSITION)
        array_result = zeros(ComplexF64, num_orbitals, num_orbitals, 6)
        packed_result = similar(array_result)
        PACKED_SPIN_ME._fourier_operator!(array_result, rank_two, model, factors, plan, kind)
        PACKED_SPIN_ME._fourier_operator!(
            packed_result,
            packed_rank_two,
            model,
            factors,
            plan,
            kind,
        )
        error = packed_result .- array_result
        @test maximum(abs, error; init = 0.0) == 0.0
        @test count(value -> !isfinite(value), packed_result) == 0
    end
end
