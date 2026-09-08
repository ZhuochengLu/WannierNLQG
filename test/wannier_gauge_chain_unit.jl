using EzXML
using HDF5
using JSON3
using LinearAlgebra
using Random
using Spglib
using Test

const GAUGE_W = WannierNLQG.Wannierization
const GAUGE_S = WannierNLQG.Symmetrization
const GAUGE_IO = WannierNLQG.IO

function gauge_scope_representation_fixture()
    identity_rotation = Matrix{Int}(I, 3, 3)
    identity_cartesian = Matrix{Float64}(I, 3, 3)
    inversion_fractional = Diagonal([-1, 1, 1]) |> Matrix{Int}
    inversion_cartesian = Diagonal([-1.0, 1.0, 1.0]) |> Matrix{Float64}
    operations = [
        WannierNLQG.SymmetryFoundation.SymmetryOperation(
            identity_rotation,
            zeros(3),
            identity_cartesian,
            false,
        ),
        WannierNLQG.SymmetryFoundation.SymmetryOperation(
            inversion_fractional,
            zeros(3),
            inversion_cartesian,
            false,
        ),
        WannierNLQG.SymmetryFoundation.SymmetryOperation(
            identity_rotation,
            [0.0, 0.5, 0.0],
            identity_cartesian,
            true,
        ),
        WannierNLQG.SymmetryFoundation.SymmetryOperation(
            inversion_fractional,
            [0.0, 0.5, 0.0],
            inversion_cartesian,
            true,
        ),
    ]
    mapping = [1 2; 2 1; 1 2; 2 1]
    sewing = zeros(ComplexF64, 2, 2, 4, 2)
    for operation in 1:4, kpoint in 1:2
        sewing[:, :, operation, kpoint] .= Matrix{ComplexF64}(I, 2, 2)
    end
    return WannierNLQG.SymmetryFoundation.BandRepresentation(
        "1.4",
        :synthetic,
        true,
        Matrix{Float64}(I, 3, 3),
        2.0pi .* Matrix{Float64}(I, 3, 3),
        (2, 1, 1),
        [0.25 0.0 0.0; 0.75 0.0 0.0],
        [-1.0 -1.0; 1.0 1.0],
        operations,
        mapping,
        zeros(Int, 3, 4, 2),
        sewing,
        [1 1; 2 2],
        [1],
        [1, 1],
        [1, 2];
        conventions = Dict("magnetic_structure" => "true"),
        input_sha256 = Dict("fixture" => repeat("a", 64)),
    )
end

@testset "constraint operation scopes rebuild closed k-stars" begin
    extension =
        Base.get_extension(WannierNLQG, :WannierNLQGWannierizationExt).RepresentationPreparation
    @test extension !== nothing
    representation = gauge_scope_representation_fixture()
    full = extension._constraint_scoped_representation(representation, :full)
    @test full.representation === representation
    @test full.parent_sha256 == full.subgroup_sha256

    unitary = extension._constraint_scoped_representation(representation, :unitary)
    @test length(unitary.representation.operations) == 2
    @test all(!operation.antiunitary for operation in unitary.representation.operations)
    @test unitary.representation.irreducible_indices == [1]
    @test unitary.representation.full_to_irreducible == [1, 1]
    @test unitary.parent_operation_indices == [1, 2]
    @test unitary.subgroup_sha256 != unitary.parent_sha256

    identity = extension._constraint_scoped_representation(representation, :identity)
    @test length(identity.representation.operations) == 1
    @test identity.representation.irreducible_indices == [1, 2]
    @test identity.representation.full_to_irreducible == [1, 2]
    @test identity.representation.full_to_operation == [1, 1]

    frames = zeros(ComplexF64, 2, 1, 2)
    frames[1, 1, :] .= 1.0
    projectors = zeros(ComplexF64, 2, 2, 2)
    projectors[1, 1, :] .= 1.0
    fixed = GAUGE_W.WannierizationFixedSubspace(
        projectors,
        frames,
        representation.irreducible_indices,
        falses(2, 2);
        source_sha256 = Dict("qualified_z_seal" => "true", "z_seal_class" => "CONVERGED"),
    )
    identity_fixed = extension._constraint_scoped_fixed_subspace(
        fixed,
        identity.representation,
        identity.parent_sha256,
        identity.subgroup_sha256,
        :identity,
    )
    @test identity_fixed.projectors == fixed.projectors
    @test identity_fixed.frames == fixed.frames
    @test identity_fixed.irreducible_indices == [1, 2]
    @test identity_fixed.source_sha256["constraint_operation_scope_history_reset"] ==
          "LEGACY_CONSTRAINT_SCOPE_RESET"

    @test GAUGE_W.WannierizationAccelerationConfig().constraint_operation_scope == :full
    @test GAUGE_W.WannierizationAccelerationConfig() ==
          GAUGE_W.WannierizationAccelerationConfig(constraint_operation_scope = :full)
    @test GAUGE_W.WannierizationAccelerationConfig(constraint_operation_scope = :unitary).constraint_operation_scope ==
          :unitary
    @test_throws ArgumentError GAUGE_W._validate_wannierization_config(
        GAUGE_W.SymmetryAdaptedWannierizationConfig(
            input = GAUGE_W.WannierizationInputConfig(
                wannierization_mode = :ordinary,
                win_file = "x.win",
                eig_file = "x.eig",
                mmn_file = "x.mmn",
            ),
            solver = GAUGE_W.WannierizationSolverConfig(
                algorithm_profile = :custom,
                acceleration = GAUGE_W.WannierizationAccelerationConfig(
                    constraint_operation_scope = :identity,
                ),
            ),
            checkpoint = GAUGE_W.WannierizationCheckpointConfig(),
            runtime = GAUGE_W.WannierizationRuntimeConfig(),
            output = GAUGE_W.WannierizationOutputConfig(),
        ),
    )
end

@testset "non-full symmetry expansion preserves the sealed projector" begin
    subspaces = [ComplexF64[1 0; 0 1; 0 0], ComplexF64[1 0; 0 1; 0 0]]
    expanded = deepcopy(subspaces)
    epsilon = 1.6e-9
    expanded[2] = ComplexF64[1 0; 0 1; epsilon 0]
    expanded[2] = Matrix(qr(expanded[2]).Q[:, 1:2])
    @test GAUGE_W._maximum_projector_drift(
        expanded,
        [subspace * subspace' for subspace in subspaces],
    ) > 1.0e-12
    restored = GAUGE_W._restore_expanded_frames_to_subspaces(expanded, subspaces, 1.0e-10, 1.0e8)
    @test restored.success
    @test restored.minimum_singular_value > 1.0 - 1.0e-12
    @test restored.projector_drift <= 1.0e-14
    @test restored.frames[1] == subspaces[1]
end

@testset "projector and link metrics are k-local gauge invariant" begin
    rng = MersenneTwister(0x5a7529)
    frames = zeros(ComplexF64, 3, 2, 2)
    transformed = similar(frames)
    for kpoint in 1:2
        frame = Matrix(qr(randn(rng, ComplexF64, 3, 2)).Q[:, 1:2])
        gauge = Matrix(qr(randn(rng, ComplexF64, 2, 2)).Q)
        frames[:, :, kpoint] .= frame
        transformed[:, :, kpoint] .= frame * gauge
    end
    mmn_data = zeros(ComplexF64, 3, 3, 2, 2)
    for kpoint in 1:2, neighbor in 1:2
        mmn_data[:, :, neighbor, kpoint] .= Matrix{ComplexF64}(I, 3, 3)
    end
    mmn = GAUGE_IO.WannierMMN(3, 2, 2, mmn_data, [2 1; 1 2], zeros(Int, 3, 2, 2))
    first_links = GAUGE_W._wannier_gauge_link_diagnostics(frames, mmn, [0.5, 0.5])
    second_links = GAUGE_W._wannier_gauge_link_diagnostics(transformed, mmn, [0.5, 0.5])
    @test first_links.minimum_singular_values ≈ second_links.minimum_singular_values atol = 1.0e-12
    @test first_links.invariant_defects ≈ second_links.invariant_defects atol = 1.0e-12
    @test first_links.omega_i_contributions ≈ second_links.omega_i_contributions atol = 1.0e-12
    comparison = GAUGE_W._compare_wannier_projectors(
        frames,
        transformed;
        frozen_mask = BitMatrix([true true; false false; false false]),
    )
    @test maximum(comparison.projector_frobenius) <= 1.0e-12
    @test maximum(comparison.projector_spectral) <= 1.0e-12
    @test maximum(comparison.maximum_principal_angle_rad) <= 5.0e-8
    @test maximum(abs, comparison.band_weight_difference) <= 1.0e-12
end

@testset "synthetic Z U and Fourier defects remain distinguishable" begin
    extension = Base.get_extension(WannierNLQG, :WannierNLQGWannierizationExt).OperatorExport
    @test extension !== nothing
    identity3 = Matrix{ComplexF64}(I, 3, 3)
    mmn_data = zeros(ComplexF64, 3, 3, 2, 2)
    for kpoint in 1:2, neighbor in 1:2
        mmn_data[:, :, neighbor, kpoint] .= identity3
    end
    mmn = GAUGE_IO.WannierMMN(3, 2, 2, mmn_data, [2 1; 1 2], zeros(Int, 3, 2, 2))

    z_discontinuous = zeros(ComplexF64, 3, 2, 2)
    z_discontinuous[:, :, 1] .= ComplexF64[1 0; 0 1; 0 0]
    z_discontinuous[:, :, 2] .= ComplexF64[1 0; 0 0; 0 1]
    z_links = GAUGE_W._wannier_gauge_link_diagnostics(z_discontinuous, mmn, [0.5, 0.5])
    @test z_links.minimum_singular_value <= 1.0e-14
    @test z_links.maximum_invariant_defect >= 1.0 - 1.0e-14

    u_smooth = zeros(ComplexF64, 3, 2, 2)
    u_smooth[:, :, 1] .= ComplexF64[1 0; 0 1; 0 0]
    u_smooth[:, :, 2] .= u_smooth[:, :, 1]
    u_jumped = copy(u_smooth)
    u_jumped[:, :, 2] .= u_jumped[:, :, 2] * Diagonal(ComplexF64[1, -1])
    same_projector = GAUGE_W._compare_wannier_projectors(u_smooth, u_jumped)
    @test maximum(same_projector.projector_frobenius) <= 1.0e-14
    _, smooth_margin, _ = extension._gauge_chain_u_link_fields(u_smooth, mmn)
    _, jumped_margin, _ = extension._gauge_chain_u_link_fields(u_jumped, mmn)
    @test minimum(smooth_margin) >= pi - 1.0e-14
    @test minimum(jumped_margin) <= 1.0e-14

    values_r = reshape(ComplexF64[1.0, 0.2], 1, 1, 2)
    correct_r = [0 1; 0 0; 0 0]
    wrong_r = [0 2; 0 0; 0 0]
    kpoints = [0.0 0.0 0.0; 0.5 0.0 0.0]
    correct = extension._gauge_chain_forward_fourier(values_r, correct_r, kpoints)
    wrong = extension._gauge_chain_forward_fourier(values_r, wrong_r, kpoints)
    matrix_residual, spectral_residual = extension._gauge_chain_field_residuals(correct, wrong)
    @test matrix_residual >= 0.39
    @test spectral_residual >= 0.39
end

@testset "Z U Fourier causal rules fail closed" begin
    classify = GAUGE_W._classify_wannier_gauge_chain_cause
    @test classify(fourier_roundtrip_residual = 2.0e-10) == [:FOURIER_IMPLEMENTATION_HOLD]
    @test classify(
        fourier_roundtrip_residual = 1.0e-14,
        z_outlier_cell_match = true,
        cross_u_tail_improvement_fraction = 0.30,
        cross_u_frozen_max_improvement_fraction = 0.05,
    ) == [:Z_DOMINANT]
    @test classify(
        fourier_roundtrip_residual = 1.0e-14,
        rcg_tail_improvement_fraction = 0.30,
        rcg_frozen_max_improvement_fraction = 0.40,
    ) == [:U_DOMINANT]
    @test classify(
        fourier_roundtrip_residual = 1.0e-14,
        z_outlier_cell_match = true,
        cross_u_tail_improvement_fraction = 0.30,
        cross_u_frozen_max_improvement_fraction = 0.05,
        rcg_tail_improvement_fraction = 0.30,
        rcg_frozen_max_improvement_fraction = 0.40,
    ) == [:MIXED_Z_U]
    @test classify(fourier_roundtrip_residual = 1.0e-14, aliasing_reproduced = true) ==
          [:FOURIER_ALIASING]
    @test classify(
        fourier_roundtrip_residual = 1.0e-14,
        ablation_frozen_max_improvement_fraction = 0.60,
    ) == [:TYPE_IV_U_LIMIT]
end
