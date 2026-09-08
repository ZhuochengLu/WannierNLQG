using LinearAlgebra
using Test

const WCRP_CORE = WannierNLQG.Core
const WCRP_SYM = WannierNLQG.Symmetrization

# Build a scalar two-center projection basis for affine branch tests.
function two_center_projection_basis()
    positions = [0.25 0.75; 0.0 0.0; 0.0 0.0]
    indices = reshape([1, 2], 1, 2)
    local_bases = repeat(reshape(Matrix{Float64}(I, 3, 3), 3, 3, 1), 1, 1, 2)
    block = WannierNLQG.WannierProjection.WannierProjectionBlock(
        "X",
        "s",
        positions,
        indices,
        local_bases,
        false,
    )
    return WannierNLQG.WannierProjection.WannierProjectionBasis([block], 2, false)
end

# Build identity and inversion with the fixed cross-cell center branches.
function two_center_inversion_plan()
    identity = WannierNLQG.SymmetryFoundation.SymmetryOperation(
        Matrix{Int}(I, 3, 3),
        zeros(3),
        Matrix{Float64}(I, 3, 3),
        false,
    )
    inversion = WannierNLQG.SymmetryFoundation.SymmetryOperation(
        -Matrix{Int}(I, 3, 3),
        zeros(3),
        -Matrix{Float64}(I, 3, 3),
        false,
    )
    representations = zeros(ComplexF64, 2, 2, 2)
    representations[:, :, 1] .= Matrix{ComplexF64}(I, 2, 2)
    representations[:, :, 2] .= ComplexF64[0 1; 1 0]
    shifts = zeros(Int, 3, 2, 2)
    shifts[1, :, 2] .= -1
    return WannierNLQG.SymmetryFoundation.WannierSymmetryPlan(
        [identity, inversion],
        representations,
        shifts,
    )
end

# Fourier sum one scalar R-last operator at a fractional k point.
function scalar_fourier(operator::WCRP_SYM.RealSpaceOperator, kpoint)
    value = 0.0 + 0.0im
    for r_index in axes(operator.r_vectors, 2)
        value +=
            cis(2.0pi * dot(kpoint, @view(operator.r_vectors[:, r_index]))) *
            operator.data[1, 1, r_index]
    end
    return value
end

# Independently materialize the one-orbital nearest-replica Fourier oracle.
function scalar_minimum_distance_oracle(operator, lattice, mp_grid, kpoint; tolerance = 1.0e-12)
    value = 0.0 + 0.0im
    for source_index in axes(operator.r_vectors, 2)
        residue = ntuple(
            direction -> mod(operator.r_vectors[direction, source_index], mp_grid[direction]),
            3,
        )
        candidates = NTuple{3, Int}[]
        distances = Float64[]
        for first_shift in -2:2, second_shift in -2:2, third_shift in -2:2
            candidate = (
                residue[1] + first_shift * mp_grid[1],
                residue[2] + second_shift * mp_grid[2],
                residue[3] + third_shift * mp_grid[3],
            )
            push!(candidates, candidate)
            push!(distances, norm(collect(candidate)' * lattice))
        end
        minimum_distance = minimum(distances)
        images = sort([
            candidates[index] for index in eachindex(candidates) if
            abs(distances[index] - minimum_distance) <= tolerance
        ])
        weight = inv(length(images))
        for image in images
            value +=
                weight *
                cis(2.0pi * dot(kpoint, collect(image))) *
                operator.data[1, 1, source_index]
        end
    end
    return value
end

@testset "affine Wannier-center lifecycle policies" begin
    extension = symmetrization_extension()
    lattice = Matrix{Float64}(I, 3, 3)
    basis = two_center_projection_basis()
    plan = two_center_inversion_plan()
    raw = [0.24 0.0 0.0; 0.74 0.0 0.0]

    symmetrized =
        extension._resolve_wannier_center_geometry(raw, lattice, basis, plan, :symmetrize, 1.0e-12)
    @test symmetrized.final_fractional ≈ [0.25 0.0 0.0; 0.75 0.0 0.0] atol = 1.0e-15
    @test maximum(symmetrized.final_operation_residuals) <= 1.0e-15
    @test symmetrized.idempotence_error <= 1.0e-15
    @test symmetrized.production_eligible
    @test_throws ArgumentError extension._resolve_wannier_center_geometry(
        raw,
        lattice,
        basis,
        plan,
        :validate,
        1.0e-12,
    )

    validated = extension._resolve_wannier_center_geometry(
        symmetrized.final_cartesian,
        lattice,
        basis,
        plan,
        :validate,
        1.0e-12,
    )
    @test validated.final_cartesian == symmetrized.final_cartesian
    @test validated.production_eligible

    kept =
        extension._resolve_wannier_center_geometry(raw, lattice, basis, plan, :keep_input, 1.0e-12)
    @test kept.final_cartesian == raw
    @test !kept.production_eligible
    @test maximum(kept.final_operation_residuals) > 1.0e-3

    branched_raw = [1.24 0.0 0.0; -0.26 0.0 0.0]
    branched = extension._resolve_wannier_center_geometry(
        branched_raw,
        lattice,
        basis,
        plan,
        :symmetrize,
        1.0e-12,
    )
    @test branched.alignment_lattice_shifts == [1 0 0; -1 0 0]
    @test branched.final_fractional ≈ symmetrized.final_fractional atol = 1.0e-15
    @test branched.maximum_displacement_cartesian ≈ symmetrized.maximum_displacement_cartesian atol =
        1.0e-15
    validated_branched = extension._resolve_wannier_center_geometry(
        [1.25 0.0 0.0; -0.25 0.0 0.0],
        lattice,
        basis,
        plan,
        :validate,
        1.0e-12,
    )
    @test validated_branched.final_fractional ≈ symmetrized.final_fractional atol = 1.0e-15
    @test maximum(validated_branched.aligned_operation_residuals) <= 1.0e-15
    @test validated_branched.maximum_displacement_cartesian == 0.0
    @test_throws ArgumentError extension._resolve_wannier_center_geometry(
        raw,
        lattice,
        basis,
        plan,
        :unsupported,
        1.0e-12,
    )
end

@testset "non-diagonal orbital mixing in Wannier-center projection" begin
    extension = symmetrization_extension()
    positions = reshape([0.25, 0.0, 0.0], 3, 1)
    local_bases = reshape(Matrix{Float64}(I, 3, 3), 3, 3, 1)
    block = WannierNLQG.WannierProjection.WannierProjectionBlock(
        "X",
        "p2",
        positions,
        reshape([1, 2], 2, 1),
        local_bases,
        false,
    )
    basis = WannierNLQG.WannierProjection.WannierProjectionBasis([block], 2, false)
    operation = WannierNLQG.SymmetryFoundation.SymmetryOperation(
        Matrix{Int}(I, 3, 3),
        zeros(3),
        Matrix{Float64}(I, 3, 3),
        false,
    )
    representation = reshape(ComplexF64[1 1; 1 -1] ./ sqrt(2), 2, 2, 1)
    plan = WannierNLQG.SymmetryFoundation.WannierSymmetryPlan(
        [operation],
        representation,
        zeros(Int, 3, 2, 1),
    )
    geometry = extension._resolve_wannier_center_geometry(
        [0.2 0.0 0.0; 0.3 0.0 0.0],
        Matrix{Float64}(I, 3, 3),
        basis,
        plan,
        :symmetrize,
        1.0e-12,
    )
    @test geometry.final_fractional ≈ [0.25 0.0 0.0; 0.25 0.0 0.0] atol = 1.0e-15
    @test geometry.idempotence_error <= 1.0e-15
end

@testset "Minimal Distance ties, Fourier equivalence, and off-grid oracle" begin
    expected_summary = Dict("minimum" => 1.0, "median" => 2.5, "p95" => 4.0, "maximum" => 4.0)
    @test WannierNLQG.MatrixElements.real_space_link_length_summary([3.0, 1.0, 4.0, 2.0]) ==
          expected_summary
    spec = WCRP_SYM.RealSpaceOperatorSymmetrySpec(WCRP_SYM.REAL_SPACE_HAMILTONIAN, 0, 1, 1)
    r_vectors = [0 1; 0 0; 0 0]
    operator = WCRP_SYM.RealSpaceOperator(spec, r_vectors, reshape(ComplexF64[2.0, 4.0], 1, 1, 2))
    operators = Dict(WCRP_SYM.REAL_SPACE_HAMILTONIAN => operator)
    lattice = Matrix{Float64}(I, 3, 3)
    centers = zeros(1, 3)
    result = WannierNLQG.MatrixElements.apply_real_space_replica_policy(
        operators,
        [1, 1],
        lattice,
        (2, 1, 1),
        centers,
        :minimum_distance;
        tolerance = 1.0e-12,
        search_size = 2,
    )
    @test result.mapping_sha256 ==
          "09eaee299936eddc09cb25c292cc6ed92ba0731a847154350a83054f05ba9e42"
    materialized = result.operators[WCRP_SYM.REAL_SPACE_HAMILTONIAN]
    @test Set(
        Tuple(materialized.r_vectors[:, index]) for index in axes(materialized.r_vectors, 2)
    ) == Set([(-1, 0, 0), (0, 0, 0), (1, 0, 0)])
    @test all(==(1), result.degeneracies)
    @test result.tied_assignment_count == 1
    @test result.changed_pair_count == 1
    @test result.changed_assignment_count == 1

    for kpoint in ([0.0, 0.0, 0.0], [0.5, 0.0, 0.0])
        @test scalar_fourier(operator, kpoint) ≈ scalar_fourier(materialized, kpoint) atol = 1.0e-14
    end
    for kpoint in ([0.137, 0.0, 0.0], [0.381, 0.0, 0.0])
        oracle = scalar_minimum_distance_oracle(operator, lattice, (2, 1, 1), kpoint)
        @test scalar_fourier(materialized, kpoint) ≈ oracle atol = 1.0e-14
    end

    input_result = WannierNLQG.MatrixElements.apply_real_space_replica_policy(
        operators,
        [1, 1],
        lattice,
        (2, 1, 1),
        centers,
        :input;
        tolerance = 1.0e-12,
        search_size = 2,
    )
    @test input_result.operators[WCRP_SYM.REAL_SPACE_HAMILTONIAN].data == operator.data
    @test input_result.degeneracies == [1, 1]
    @test_throws ArgumentError WannierNLQG.MatrixElements.apply_real_space_replica_policy(
        operators,
        [1, 1],
        lattice,
        (2, 1, 1),
        centers,
        :unsupported;
        tolerance = 1.0e-12,
        search_size = 2,
    )

    nonorthogonal_lattice = [1.0 0.0 0.0; 0.45 1.2 0.0; 0.2 0.1 1.4]
    images = WannierNLQG.MatrixElements.nearest_wigner_seitz_images(
        (1, 1, 0),
        [0.21, -0.17, 0.0],
        nonorthogonal_lattice,
        (3, 2, 1);
        tolerance = 1.0e-12,
        search_size = 3,
    )
    selected_distance =
        norm((collect(first(images)) .+ [0.21, -0.17, 0.0])' * nonorthogonal_lattice)
    brute_force_distance = minimum(
        norm(
            ([1 + 3first_shift, 1 + 2second_shift, third_shift] .+ [0.21, -0.17, 0.0])' *
            nonorthogonal_lattice,
        ) for first_shift in -3:3, second_shift in -3:3, third_shift in -3:3
    )
    @test selected_distance ≈ brute_force_distance atol = 1.0e-12
end

@testset "diagnostic geometry survives Packed HDF5 schema 6" begin
    extension = symmetrization_extension()
    lattice = Matrix{Float64}(I, 3, 3)
    r_vectors = zeros(Int, 3, 1)
    hamiltonian = WCRP_SYM.RealSpaceOperator(
        WCRP_SYM.RealSpaceOperatorSymmetrySpec(WCRP_SYM.REAL_SPACE_HAMILTONIAN, 0, 1, 1),
        r_vectors,
        reshape(ComplexF64[1.0], 1, 1, 1),
    )
    position_values = zeros(ComplexF64, 1, 1, 3, 1)
    position_values[1, 1, 1, 1] = 0.25
    position = WCRP_SYM.RealSpaceOperator(
        WCRP_SYM.RealSpaceOperatorSymmetrySpec(WCRP_SYM.REAL_SPACE_POSITION, 1, -1, 1),
        r_vectors,
        position_values,
    )
    operators = Dict(
        WCRP_SYM.REAL_SPACE_HAMILTONIAN => hamiltonian,
        WCRP_SYM.REAL_SPACE_POSITION => position,
    )
    geometry = test_operator_bundle_geometry(lattice, [1], operators)
    geometry["wannier_center_policy"] = "keep_input"
    geometry["production_eligible"] = false
    mktempdir() do directory
        path = joinpath(directory, "diagnostic.h5")
        extension.write_real_space_operator_bundle(
            path,
            lattice,
            [1],
            operators;
            profile = :hamiltonian_position,
            geometry,
        )
        manifest = WannierNLQG.IO.read_real_space_operator_bundle_manifest(path)
        @test manifest.schema_version == WannierNLQG.IO.OPERATOR_BUNDLE_SCHEMA_VERSION
        @test manifest.wannier_center_policy == :keep_input
        @test !manifest.production_eligible
        @test !manifest.minimum_distance_materialized
        @test manifest.geometry_content_sha256 !== nothing
    end
end
