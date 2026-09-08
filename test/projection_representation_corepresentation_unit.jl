using LinearAlgebra
using Test

const PROJECTION_COREP_WANNIERIZATION = WannierNLQG.Wannierization
const PROJECTION_COREP_SYMMETRIZATION = WannierNLQG.Symmetrization
const PROJECTION_COREP_IMPLEMENTATION =
    first(PROJECTION_COREP_WANNIERIZATION._load_wannierization_extension!()).ProjectionSearch

# Construct a one-point representation inventory for Wigner classification tests.
function projection_corep_representation(
    operations;
    kpoint = [0.0, 0.0, 0.0],
    spinor::Bool = false,
    band_dimension::Int = 1,
)
    operation_count = length(operations)
    kpoint_values = Float64.(kpoint)
    reciprocal_shifts = zeros(Int, 3, operation_count, 1)
    for (operation_index, operation) in enumerate(operations)
        sign = operation.antiunitary ? -1.0 : 1.0
        shift =
            sign .* (transpose(inv(operation.rotation_fractional)) * kpoint_values) .- kpoint_values
        reciprocal_shifts[:, operation_index, 1] .= round.(Int, shift)
    end
    sewing = zeros(ComplexF64, band_dimension, band_dimension, operation_count, 1)
    for operation_index in 1:operation_count
        sewing[:, :, operation_index, 1] .= Matrix{ComplexF64}(I, band_dimension, band_dimension)
    end
    return WannierNLQG.SymmetryFoundation.BandRepresentation(
        "1.1",
        :projection_corep_test,
        spinor,
        Matrix{Float64}(I, 3, 3),
        2.0pi .* Matrix{Float64}(I, 3, 3),
        (1, 1, 1),
        reshape(kpoint_values, 1, 3),
        zeros(band_dimension, 1),
        operations,
        ones(Int, operation_count, 1),
        reciprocal_shifts,
        sewing,
        ones(Int, band_dimension, 1),
        [1],
        [1],
        [1];
        input_sha256 = Dict("fixture" => repeat("b", 64)),
    )
end

# Create one orthogonal diagonal operation for magnetic-group fixtures.
function projection_corep_operation(rotation; translation = zeros(3), antiunitary = false)
    return WannierNLQG.SymmetryFoundation.SymmetryOperation(
        Matrix{Int}(rotation),
        Float64.(translation),
        Matrix{Float64}(I, 3, 3),
        antiunitary;
        check_cartesian_orthogonality = false,
    )
end

# Run the complete algebra-to-corepresentation classification chain.
function projection_corep_enumeration(representation)
    algebra = PROJECTION_COREP_IMPLEMENTATION._build_little_group_algebra(representation, 1)
    irreps = PROJECTION_COREP_IMPLEMENTATION._enumerate_projective_irreps(algebra)
    coreps = PROJECTION_COREP_IMPLEMENTATION._enumerate_magnetic_corepresentations(algebra, irreps)
    return (; algebra, irreps, coreps)
end

@testset "Type-I and Type-III Wigner inventories" begin
    identity_rotation = Matrix{Int}(I, 3, 3)
    c2z = Diagonal([-1, -1, 1]) |> Matrix
    type_i = projection_corep_representation(projection_corep_operation.([identity_rotation, c2z]))
    type_i_result = projection_corep_enumeration(type_i)
    @test type_i_result.coreps.complete
    @test getfield.(type_i_result.coreps.corepresentations, :wigner_type) == fill(:unitary, 2)

    mirror_x = Diagonal([-1, 1, 1]) |> Matrix
    mirror_y = Diagonal([1, -1, 1]) |> Matrix
    type_iii_operations = [
        projection_corep_operation(identity_rotation),
        projection_corep_operation(c2z),
        projection_corep_operation(mirror_x; antiunitary = true),
        projection_corep_operation(mirror_y; antiunitary = true),
    ]
    type_iii = projection_corep_representation(type_iii_operations)
    type_iii_result = projection_corep_enumeration(type_iii)
    @test type_iii_result.coreps.complete
    @test getfield.(type_iii_result.coreps.corepresentations, :wigner_type) == fill(:a, 2)
end

@testset "Complex-conjugate C3 irreps form one Wigner type-c corepresentation" begin
    identity_rotation = Matrix{Int}(I, 3, 3)
    rotation = [0 -1 0; 1 -1 0; 0 0 1]
    rotations = [identity_rotation, rotation, rotation * rotation]
    operations = vcat(
        projection_corep_operation.(rotations),
        [projection_corep_operation(value; antiunitary = true) for value in rotations],
    )
    representation = projection_corep_representation(operations)
    result = projection_corep_enumeration(representation)
    @test result.coreps.complete
    @test sort(getfield.(result.coreps.corepresentations, :wigner_type)) == [:a, :c]
    @test sort(getfield.(result.coreps.corepresentations, :dimension)) == [1, 2]
    type_c = only(filter(corep -> corep.wigner_type == :c, result.coreps.corepresentations))
    @test count(>(0), type_c.constituent_multiplicities) == 2
end

@testset "Type-II spinful time reversal is Wigner type b" begin
    identity_rotation = Matrix{Int}(I, 3, 3)
    operations = [
        projection_corep_operation(identity_rotation),
        projection_corep_operation(identity_rotation; antiunitary = true),
    ]
    representation = projection_corep_representation(operations; spinor = true, band_dimension = 2)
    result = projection_corep_enumeration(representation)
    @test result.algebra.factor_system[2, 2] ≈ -1.0 + 0.0im atol = 1.0e-12
    @test result.coreps.complete
    @test length(result.coreps.corepresentations) == 1
    @test only(result.coreps.corepresentations).wigner_type == :b
    @test only(result.coreps.corepresentations).dimension == 2

    time_reversal = ComplexF64[0 1; -1 0]
    decomposition = PROJECTION_COREP_IMPLEMENTATION._decompose_representation_actions(
        result.algebra,
        [Matrix{ComplexF64}(I, 2, 2), time_reversal],
        result.irreps,
        result.coreps,
    )
    @test decomposition.complete
    @test decomposition.multiplicities == [1]
    @test decomposition.wigner_types == [:b]

    representation.sewing_matrices[:, :, 2, 1] .= time_reversal
    band_decomposition = PROJECTION_COREP_IMPLEMENTATION._decompose_band_subspace(
        representation,
        result.algebra,
        trues(2),
        result.irreps,
        result.coreps,
    )
    @test band_decomposition.complete
    @test band_decomposition.multiplicities == [1]
end

@testset "Type-IV half translation produces boundary Kramers doubling" begin
    identity_rotation = Matrix{Int}(I, 3, 3)
    operations = [
        projection_corep_operation(identity_rotation),
        projection_corep_operation(
            identity_rotation;
            translation = [0.5, 0.0, 0.0],
            antiunitary = true,
        ),
    ]
    representation =
        projection_corep_representation(operations; kpoint = [0.5, 0.0, 0.0], band_dimension = 2)
    result = projection_corep_enumeration(representation)
    @test result.coreps.complete
    @test only(result.coreps.corepresentations).wigner_type == :b
    @test only(result.coreps.corepresentations).wigner_indicator ≈ -1.0 atol = 1.0e-12
end

@testset "Band-mask leakage fails closed before character decomposition" begin
    identity_rotation = Matrix{Int}(I, 3, 3)
    c2z = Diagonal([-1, -1, 1]) |> Matrix
    representation = projection_corep_representation(
        projection_corep_operation.([identity_rotation, c2z]);
        band_dimension = 2,
    )
    representation.sewing_matrices[:, :, 2, 1] .= ComplexF64[0 1; 1 0]
    result = projection_corep_enumeration(representation)
    decomposition = PROJECTION_COREP_IMPLEMENTATION._decompose_band_subspace(
        representation,
        result.algebra,
        [true, false],
        result.irreps,
        result.coreps,
    )
    @test !decomposition.complete
    @test decomposition.uncertain
    @test any(contains("not little-group invariant"), decomposition.diagnostics)
end
