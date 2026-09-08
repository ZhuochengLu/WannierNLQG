using Test
using LinearAlgebra
using Spglib
import WannierNLQG.SymmetryFoundation: magnetic_point_group_operation_identity

module ResponseSymmetryCatalogValidationFixture

include(joinpath(@__DIR__, "..", "scripts", "check_response_symmetry_catalog.jl"))

end

@testset "operation identity is order and basis invariant and rejects tampering" begin
    rotations, _, antiunitary = Spglib.get_magnetic_symmetry_from_database(101)
    identity = Matrix{Int}(I, 3, 3)
    baseline = magnetic_point_group_operation_identity(rotations, antiunitary, 6, "222", identity)
    permutation = [3, 1, 4, 2]
    shuffled = magnetic_point_group_operation_identity(
        rotations[permutation],
        antiunitary[permutation],
        6,
        "222",
        identity,
    )
    @test shuffled == baseline
    reversed = magnetic_point_group_operation_identity(
        reverse(rotations),
        reverse(antiunitary),
        6,
        "222",
        identity,
    )
    @test reversed == baseline

    basis = [0 1 0; 1 0 0; 0 0 1]
    transformed = [Int.(basis * Matrix{Int}(rotation) * basis) for rotation in rotations]
    covariant = magnetic_point_group_operation_identity(transformed, antiunitary, 6, "222", basis)
    @test covariant.magnetic_point_group_number == baseline.magnetic_point_group_number
    @test covariant.operation_digest == baseline.operation_digest
    @test covariant.operation_digest_contract == baseline.operation_digest_contract
    @test covariant.basis_transform_to_input.definition ==
          "v_input = B * v_canonical; W_input = B * W_canonical * inv(B)"
    @test covariant.basis_transform_to_input.shape == [3, 3]
    @test covariant.basis_transform_to_input.denominator > 0

    tampered = copy(antiunitary)
    tampered[1] = !tampered[1]
    @test_throws ErrorException magnetic_point_group_operation_identity(
        rotations,
        tampered,
        6,
        "222",
        identity,
    )
end

@testset "Spglib-only response-symmetry catalog release checker" begin
    checker = ResponseSymmetryCatalogValidationFixture
    result = checker.check_response_symmetry_catalog(; replay = false)
    @test result.uni_count == 1651
    @test result.magnetic_point_group_count == 122
    @test result.operation_digest_count == 122
    @test result.display_catalog_sha256 ==
          "4ac72113a12da0557105b3d0689d30e623c3ce6b0bcba52dc2c1cb355946290e"
    @test checker._catalog_check_spglib_identity_negative_tests()

    tampered_source = merge(
        checker.EXPECTED_RESPONSE_SYMMETRY_CATALOG,
        (generated_source_sha256 = repeat("0", 64),),
    )
    @test_throws ErrorException checker.check_response_symmetry_catalog(
        expected = tampered_source,
        replay = false,
    )
    tampered_spglib_contract = merge(
        checker.EXPECTED_RESPONSE_SYMMETRY_CATALOG,
        (generation_contract = "wanniernlqg.spglib-magnetic-point-group-catalog/0.0",),
    )
    @test_throws ErrorException checker.check_response_symmetry_catalog(
        expected = tampered_spglib_contract,
        replay = false,
    )
    artifact_variants = checker.EXPECTED_RESPONSE_SYMMETRY_CATALOG.spglib_artifact_variants
    tampered_spglib_identity = merge(
        checker.EXPECTED_RESPONSE_SYMMETRY_CATALOG,
        (
            spglib_artifact_variants = [
                merge(first(artifact_variants), (artifact_tree = repeat("1", 40),)),
                artifact_variants[2:end]...,
            ],
        ),
    )
    @test_throws ErrorException checker.check_response_symmetry_catalog(
        expected = tampered_spglib_identity,
        replay = false,
    )
    tampered_spglib_library = merge(
        checker.EXPECTED_RESPONSE_SYMMETRY_CATALOG,
        (
            spglib_artifact_variants = [
                merge(first(artifact_variants), (library_sha256 = repeat("2", 64),)),
                artifact_variants[2:end]...,
            ],
        ),
    )
    @test_throws ErrorException checker.check_response_symmetry_catalog(
        expected = tampered_spglib_library,
        replay = false,
    )
    missing_spglib_platform = merge(
        checker.EXPECTED_RESPONSE_SYMMETRY_CATALOG,
        (spglib_artifact_variants = artifact_variants[2:end],),
    )
    @test_throws ErrorException checker.check_response_symmetry_catalog(
        expected = missing_spglib_platform,
        replay = false,
    )
    tampered_spec =
        merge(checker.EXPECTED_RESPONSE_SYMMETRY_CATALOG, (specification_sha256 = repeat("f", 64),))
    @test_throws ErrorException checker.check_response_symmetry_catalog(
        expected = tampered_spec,
        replay = false,
    )
end
