using LinearAlgebra
using Test
using TOML

const PROJECTION_COMPATIBILITY_WANNIERIZATION = WannierNLQG.Wannierization
const PROJECTION_COMPATIBILITY_SYMMETRIZATION = WannierNLQG.Symmetrization
const PROJECTION_COMPATIBILITY_IMPLEMENTATION =
    first(PROJECTION_COMPATIBILITY_WANNIERIZATION._load_wannierization_extension!()).ProjectionSearch

# Create one crystallographic operation for compatibility characterization.
function projection_compatibility_operation(rotation; translation = zeros(3), antiunitary = false)
    return WannierNLQG.SymmetryFoundation.SymmetryOperation(
        Matrix{Int}(rotation),
        Float64.(translation),
        Matrix{Float64}(I, 3, 3),
        antiunitary;
        check_cartesian_orthogonality = false,
    )
end

# Construct a one-point representation with explicitly supplied sewing actions.
function projection_compatibility_representation(
    operations;
    kpoint = [0.0, 0.0, 0.0],
    spinor::Bool = false,
    band_dimension::Int = 1,
    actions = nothing,
    conventions = Dict{String, String}(),
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
    action_values = if actions === nothing
        [Matrix{ComplexF64}(I, band_dimension, band_dimension) for _ in operations]
    else
        Matrix{ComplexF64}.(actions)
    end
    length(action_values) == operation_count ||
        throw(ArgumentError("action inventory has incompatible length"))
    for operation_index in eachindex(operations)
        sewing[:, :, operation_index, 1] .= action_values[operation_index]
    end
    return WannierNLQG.SymmetryFoundation.BandRepresentation(
        "1.1",
        :projection_compatibility_test,
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
        conventions,
        input_sha256 = Dict("fixture" => repeat("c", 64)),
    )
end

# Build the unitary little-group and canonical projective irreps at the only k point.
function projection_compatibility_irreps(representation)
    algebra = PROJECTION_COMPATIBILITY_IMPLEMENTATION._build_little_group_algebra(
        representation,
        1;
        tolerance = PROJECTION_COMPATIBILITY_IMPLEMENTATION.PROJECTION_COMPATIBILITY_LITTLE_GROUP_TOLERANCE,
    )
    irreps = PROJECTION_COMPATIBILITY_IMPLEMENTATION._enumerate_projective_irreps(
        algebra;
        tolerance = PROJECTION_COMPATIBILITY_IMPLEMENTATION.PROJECTION_COMPATIBILITY_LITTLE_GROUP_TOLERANCE,
    )
    return (; algebra, irreps)
end

@testset "Pinned compatibility profile and scope" begin
    implementation = PROJECTION_COMPATIBILITY_IMPLEMENTATION
    @test implementation.PROJECTION_COMPATIBILITY_UPSTREAM_PACKAGE == "WannierBerri"
    @test implementation.PROJECTION_COMPATIBILITY_UPSTREAM_VERSION == "1.7.0"
    @test implementation.PROJECTION_COMPATIBILITY_UPSTREAM_COMMIT ==
          "50265d5d1cef184f8377f87ed691c8d9a2f6cdbf"
    @test implementation.PROJECTION_COMPATIBILITY_UPSTREAM_SOURCE_SHA256 ==
          "8552e056b568860c4c7dbd868e997fe4e9e6fb4a0349b182665aee2c8330d5c2"
    @test implementation.PROJECTION_COMPATIBILITY_CHARACTER_TOLERANCE == 1.0e-3
    @test implementation.PROJECTION_COMPATIBILITY_CHARACTER_RELATIVE_TOLERANCE == 1.0e-5
    @test implementation.PROJECTION_COMPATIBILITY_CHARACTER_ROUND_DIGITS == 3
    @test implementation.PROJECTION_COMPATIBILITY_LITTLE_GROUP_TOLERANCE == 1.0e-5

    identity_rotation = Matrix{Int}(I, 3, 3)
    identity_operation = projection_compatibility_operation(identity_rotation)
    native = projection_compatibility_representation([identity_operation])
    @test implementation._projection_representation_spinless_unitary_scope(native)
    native_info = implementation._projection_representation_compatibility_info(native)
    @test native_info.parity_eligible
    @test native_info.scope == :spinless_unitary
    @test native_info.upstream_version == "1.7.0"

    spinor = projection_compatibility_representation([identity_operation]; spinor = true)
    @test !implementation._projection_representation_spinless_unitary_scope(spinor)
    @test implementation._projection_representation_compatibility_info(spinor).scope ==
          :generalized_symmetry

    time_reversal = projection_compatibility_operation(identity_rotation; antiunitary = true)
    semilinear = projection_compatibility_representation([time_reversal])
    @test !implementation._projection_representation_spinless_unitary_scope(semilinear)
    @test !implementation._projection_representation_compatibility_info(semilinear).parity_eligible

    magnetic = projection_compatibility_representation(
        [identity_operation];
        conventions = Dict("magnetic_structure" => "true"),
    )
    @test !implementation._projection_representation_spinless_unitary_scope(magnetic)
    magnetic_info = implementation._projection_representation_compatibility_info(magnetic)
    @test !magnetic_info.parity_eligible
    @test magnetic_info.scope == :generalized_symmetry
end

@testset "Character reducer boundary rules" begin
    identity_rotation = Matrix{Int}(I, 3, 3)
    representation = projection_compatibility_representation([
        projection_compatibility_operation(identity_rotation),
    ],)
    (; irreps) = projection_compatibility_irreps(representation)
    implementation = PROJECTION_COMPATIBILITY_IMPLEMENTATION

    band_below = implementation._projection_compatibility_reduce_characters(
        ComplexF64[0.9994],
        irreps;
        source = :band_subspace,
    )
    @test band_below.complete
    @test band_below.multiplicities == [1]
    band_above = implementation._projection_compatibility_reduce_characters(
        ComplexF64[1.0006],
        irreps;
        source = :band_subspace,
    )
    @test band_above.complete
    @test band_above.multiplicities == [2]

    candidate_inside = implementation._projection_compatibility_reduce_characters(
        ComplexF64[1.0009 + 0.0009im],
        irreps;
        source = :candidate,
    )
    @test candidate_inside.complete
    @test candidate_inside.multiplicities == [1]
    candidate_real_outside = implementation._projection_compatibility_reduce_characters(
        ComplexF64[1.0011],
        irreps;
        source = :candidate,
    )
    @test !candidate_real_outside.complete
    @test candidate_real_outside.uncertain
    candidate_imaginary_outside = implementation._projection_compatibility_reduce_characters(
        ComplexF64[1.0 + 0.0011im],
        irreps;
        source = :candidate,
    )
    @test !candidate_imaginary_outside.complete
    high_multiplicity_inside = implementation._projection_compatibility_reduce_characters(
        ComplexF64[100.0015],
        irreps;
        source = :candidate,
    )
    @test high_multiplicity_inside.complete
    @test high_multiplicity_inside.multiplicities == [100]
    high_multiplicity_outside = implementation._projection_compatibility_reduce_characters(
        ComplexF64[100.0021],
        irreps;
        source = :candidate,
    )
    @test !high_multiplicity_outside.complete
    @test_throws ArgumentError implementation._projection_compatibility_reduce_characters(
        ComplexF64[1.0],
        irreps;
        source = :unknown,
    )
end

@testset "C1, Ci, and C2v compatible action decomposition" begin
    identity_rotation = Matrix{Int}(I, 3, 3)
    inversion = -identity_rotation
    c2z = Diagonal([-1, -1, 1]) |> Matrix
    mirror_x = Diagonal([-1, 1, 1]) |> Matrix
    mirror_y = Diagonal([1, -1, 1]) |> Matrix
    cases = (
        ([identity_rotation], [Matrix{ComplexF64}(I, 2, 2)], [2]),
        ([identity_rotation, inversion], fill(Matrix{ComplexF64}(I, 2, 2), 2), [0, 2]),
        (
            [identity_rotation, c2z, mirror_x, mirror_y],
            fill(ones(ComplexF64, 1, 1), 4),
            [0, 0, 0, 1],
        ),
    )
    for (rotations, actions, expected_sorted) in cases
        operations = projection_compatibility_operation.(rotations)
        representation = projection_compatibility_representation(
            operations;
            band_dimension = size(first(actions), 1),
            actions,
        )
        (; algebra, irreps) = projection_compatibility_irreps(representation)
        decomposition =
            PROJECTION_COMPATIBILITY_IMPLEMENTATION._projection_compatibility_decompose_actions(
                algebra,
                actions,
                irreps;
                source = :candidate,
            )
        @test decomposition.complete
        @test !decomposition.uncertain
        @test sort(decomposition.multiplicities) == expected_sorted
        @test all(==(:unitary), decomposition.wigner_types)
    end
end

@testset "Nonsymmorphic projective character and band-mask gate" begin
    identity_rotation = Matrix{Int}(I, 3, 3)
    c2z = Diagonal([-1, -1, 1]) |> Matrix
    operations = [
        projection_compatibility_operation(identity_rotation),
        projection_compatibility_operation(c2z; translation = [0.0, 0.0, 0.5]),
    ]
    actions = [ones(ComplexF64, 1, 1), fill(0.0 + 1.0im, 1, 1)]
    representation =
        projection_compatibility_representation(operations; kpoint = [0.0, 0.0, 0.5], actions)
    (; algebra, irreps) = projection_compatibility_irreps(representation)
    @test algebra.factor_system[2, 2] ≈ -1.0 + 0.0im atol = 1.0e-12
    decomposition =
        PROJECTION_COMPATIBILITY_IMPLEMENTATION._projection_compatibility_decompose_actions(
            algebra,
            actions,
            irreps;
            source = :candidate,
        )
    @test decomposition.complete
    @test sort(decomposition.multiplicities) == [0, 1]

    identity_operations = [projection_compatibility_operation(identity_rotation)]
    leaking_action = ComplexF64[0 1; 1 0]
    leaking = projection_compatibility_representation(
        identity_operations;
        band_dimension = 2,
        actions = [leaking_action],
    )
    leaking_data = projection_compatibility_irreps(leaking)
    leaking_decomposition =
        PROJECTION_COMPATIBILITY_IMPLEMENTATION._projection_compatibility_decompose_band_subspace(
            leaking,
            leaking_data.algebra,
            [true, false],
            leaking_data.irreps,
        )
    @test !leaking_decomposition.complete
    @test leaking_decomposition.uncertain
    @test any(contains("not little-group invariant"), leaking_decomposition.diagnostics)

    empty_frozen =
        PROJECTION_COMPATIBILITY_IMPLEMENTATION._projection_compatibility_empty_decomposition(
            irreps,
        )
    @test empty_frozen.complete
    @test all(iszero, empty_frozen.multiplicities)
end

@testset "Synthetic coefficient oracle metadata" begin
    fixture = TOML.parsefile(
        joinpath(
            @__DIR__,
            "fixtures",
            "projection_representation_compatibility",
            "synthetic_coefficient_oracle.toml",
        ),
    )
    @test fixture["schema"] == "WannierNLQG.projection_representation_compatibility_oracle"
    @test fixture["schema_version"] == "1.0"
    @test fixture["upstream_package"] == "WannierBerri"
    @test fixture["upstream_version"] == "1.7.0"
    @test fixture["upstream_commit"] == "50265d5d1cef184f8377f87ed691c8d9a2f6cdbf"
    @test fixture["upstream_source_sha256"] ==
          "8552e056b568860c4c7dbd868e997fe4e9e6fb4a0349b182665aee2c8330d5c2"
    @test fixture["character_tolerance"] == 1.0e-3
    @test fixture["character_relative_tolerance"] == 1.0e-5
    @test fixture["character_round_digits"] == 3
    @test fixture["little_group_tolerance"] == 1.0e-5
    @test getindex.(fixture["case"], "id") ==
          ["c1_exact_dimension", "ci_even_odd", "c2v_two_channels", "screw_boundary_channels"]
    @test all(!isempty(case["coefficient_sets"]) for case in fixture["case"])
end
