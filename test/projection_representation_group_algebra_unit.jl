using LinearAlgebra
using Test

const PROJECTION_GROUP_WANNIERIZATION = WannierNLQG.Wannierization
const PROJECTION_GROUP_SYMMETRIZATION = WannierNLQG.Symmetrization
const PROJECTION_GROUP_IMPLEMENTATION =
    first(PROJECTION_GROUP_WANNIERIZATION._load_wannierization_extension!()).ProjectionSearch

# Construct a one-point representation inventory for little-group algebra tests.
function projection_group_representation(operations; kpoint = [0.0, 0.0, 0.0], spinor::Bool = false)
    operation_count = length(operations)
    kpoint_values = Float64.(kpoint)
    reciprocal_shifts = zeros(Int, 3, operation_count, 1)
    for (operation_index, operation) in enumerate(operations)
        sign = operation.antiunitary ? -1.0 : 1.0
        shift =
            sign .* (transpose(inv(operation.rotation_fractional)) * kpoint_values) .- kpoint_values
        reciprocal_shifts[:, operation_index, 1] .= round.(Int, shift)
    end
    return WannierNLQG.SymmetryFoundation.BandRepresentation(
        "1.1",
        :projection_group_test,
        spinor,
        Matrix{Float64}(I, 3, 3),
        2.0pi .* Matrix{Float64}(I, 3, 3),
        (1, 1, 1),
        reshape(kpoint_values, 1, 3),
        zeros(1, 1),
        operations,
        ones(Int, operation_count, 1),
        reciprocal_shifts,
        ones(ComplexF64, 1, 1, operation_count, 1),
        ones(Int, 1, 1),
        [1],
        [1],
        [1];
        input_sha256 = Dict("fixture" => repeat("a", 64)),
    )
end

# Create one operation while allowing crystallographic non-Cartesian integer matrices.
function projection_group_operation(rotation; translation = zeros(3), antiunitary = false)
    return WannierNLQG.SymmetryFoundation.SymmetryOperation(
        Matrix{Int}(rotation),
        Float64.(translation),
        Matrix{Float64}(I, 3, 3),
        antiunitary;
        check_cartesian_orthogonality = false,
    )
end

@testset "C1 and Ci regular-action completeness" begin
    identity_rotation = Matrix{Int}(I, 3, 3)
    inversion = -identity_rotation
    c1_representation =
        projection_group_representation([projection_group_operation(identity_rotation)])
    c1_algebra = PROJECTION_GROUP_IMPLEMENTATION._build_little_group_algebra(c1_representation, 1)
    c1_irreps = PROJECTION_GROUP_IMPLEMENTATION._enumerate_projective_irreps(c1_algebra)
    @test c1_irreps.complete
    @test getfield.(c1_irreps.irreps, :dimension) == [1]

    ci_representation =
        projection_group_representation(projection_group_operation.([identity_rotation, inversion]))
    ci_algebra = PROJECTION_GROUP_IMPLEMENTATION._build_little_group_algebra(ci_representation, 1)
    ci_irreps = PROJECTION_GROUP_IMPLEMENTATION._enumerate_projective_irreps(ci_algebra)
    @test ci_irreps.complete
    @test getfield.(ci_irreps.irreps, :dimension) == [1, 1]
end

@testset "Projection little-group closure and deterministic projective irreps" begin
    identity_rotation = Matrix{Int}(I, 3, 3)
    c2z = Diagonal([-1, -1, 1]) |> Matrix
    mirror_x = Diagonal([-1, 1, 1]) |> Matrix
    mirror_y = Diagonal([1, -1, 1]) |> Matrix
    c2v = projection_group_operation.([identity_rotation, c2z, mirror_x, mirror_y])
    representation = projection_group_representation(c2v)
    algebra = PROJECTION_GROUP_IMPLEMENTATION._build_little_group_algebra(representation, 1)
    @test algebra.complete
    @test algebra.identity_position == 1
    @test isempty(algebra.antiunitary_positions)
    @test algebra.maximum_cocycle_residual <= 1.0e-12

    enumeration = PROJECTION_GROUP_IMPLEMENTATION._enumerate_projective_irreps(algebra)
    @test enumeration.complete
    @test getfield.(enumeration.irreps, :dimension) == fill(1, 4)
    @test getfield.(enumeration.irreps, :multiplicity_in_regular) == fill(1, 4)
    @test enumeration.dimension_sum_of_squares == 4
    limited = PROJECTION_GROUP_IMPLEMENTATION._enumerate_projective_irreps(
        algebra;
        max_regular_dimension = 2,
    )
    @test !limited.complete
    @test limited.uncertain
end

@testset "C3v two-dimensional irrep is recovered from the regular action" begin
    identity_rotation = Matrix{Int}(I, 3, 3)
    rotation = [0 -1 0; 1 -1 0; 0 0 1]
    mirror = [0 1 0; 1 0 0; 0 0 1]
    rotations = [
        identity_rotation,
        rotation,
        rotation * rotation,
        mirror,
        mirror * rotation,
        mirror * rotation * rotation,
    ]
    operations = projection_group_operation.(rotations)
    representation = projection_group_representation(operations)
    algebra = PROJECTION_GROUP_IMPLEMENTATION._build_little_group_algebra(representation, 1)
    @test algebra.complete
    enumeration = PROJECTION_GROUP_IMPLEMENTATION._enumerate_projective_irreps(algebra)
    @test enumeration.complete
    @test sort(getfield.(enumeration.irreps, :dimension)) == [1, 1, 2]
    @test sort(getfield.(enumeration.irreps, :multiplicity_in_regular)) == [1, 1, 2]
    @test enumeration.dimension_sum_of_squares == 6
end

@testset "Spin and screw factor systems produce projective C2 characters" begin
    identity_rotation = Matrix{Int}(I, 3, 3)
    c2z = Diagonal([-1, -1, 1]) |> Matrix

    physical_c2z = WannierNLQG.SymmetryFoundation.SymmetryOperation(c2z, zeros(3), Float64.(c2z))
    spinor_representation = projection_group_representation(
        [projection_group_operation(identity_rotation), physical_c2z];
        spinor = true,
    )
    spinor_algebra =
        PROJECTION_GROUP_IMPLEMENTATION._build_little_group_algebra(spinor_representation, 1)
    spinor_irreps = PROJECTION_GROUP_IMPLEMENTATION._enumerate_projective_irreps(spinor_algebra)
    @test spinor_algebra.factor_system[2, 2] ≈ -1.0 + 0.0im atol = 1.0e-12
    @test spinor_irreps.complete
    @test all(
        character -> abs(real(character)) <= 1.0e-12 && abs(abs(imag(character)) - 1.0) <= 1.0e-12,
        [irrep.characters[2] for irrep in spinor_irreps.irreps],
    )

    screw_operations = [
        projection_group_operation(identity_rotation),
        projection_group_operation(c2z; translation = [0.0, 0.0, 0.5]),
    ]
    screw_representation =
        projection_group_representation(screw_operations; kpoint = [0.0, 0.0, 0.5])
    screw_algebra =
        PROJECTION_GROUP_IMPLEMENTATION._build_little_group_algebra(screw_representation, 1)
    screw_irreps = PROJECTION_GROUP_IMPLEMENTATION._enumerate_projective_irreps(screw_algebra)
    @test screw_algebra.factor_system[2, 2] ≈ -1.0 + 0.0im atol = 1.0e-12
    @test screw_irreps.complete
    @test all(
        character -> abs(real(character)) <= 1.0e-12 && abs(abs(imag(character)) - 1.0) <= 1.0e-12,
        [irrep.characters[2] for irrep in screw_irreps.irreps],
    )
end

@testset "Nonsymmorphic antiunitary square enters the cocycle exactly" begin
    identity_rotation = Matrix{Int}(I, 3, 3)
    operations = [
        projection_group_operation(identity_rotation),
        projection_group_operation(
            identity_rotation;
            translation = [0.5, 0.0, 0.0],
            antiunitary = true,
        ),
    ]
    representation = projection_group_representation(operations; kpoint = [0.5, 0.0, 0.0])
    algebra = PROJECTION_GROUP_IMPLEMENTATION._build_little_group_algebra(representation, 1)
    @test algebra.complete
    @test algebra.factor_system[2, 2] ≈ -1.0 + 0.0im atol = 1.0e-12
    @test algebra.product_positions[2, 2] == algebra.identity_position

    representation.reciprocal_shifts[1, 2, 1] = 0
    inconsistent = PROJECTION_GROUP_IMPLEMENTATION._build_little_group_algebra(representation, 1)
    @test !inconsistent.complete
    @test inconsistent.uncertain
    @test any(contains("reciprocal shift"), inconsistent.diagnostics)
end
