using HDF5
using EzXML
using LinearAlgebra
using Test

const MAGNETIC_FOUNDATION = WannierNLQG.SymmetryFoundation
const MAGNETIC_WANNIERIZATION_API = WannierNLQG.Wannierization
const MAGNETIC_EXTENSION = first(WannierNLQG.Wannierization._load_wannierization_extension!())
const MAGNETIC_WANNIERIZATION = MAGNETIC_EXTENSION.SolverCheckpoint
const MAGNETIC_REPRESENTATION = MAGNETIC_EXTENSION.RepresentationPreparation
const MAGNETIC_WANNIER_IO = WannierNLQG.IO

# Construct a Gamma-only exact (co)representation from the shared spin actions.
function magnetic_gamma_fixture(inventory; corrupt_operation::Union{Nothing, Int} = nothing)
    operations = inventory.operations
    num_operations = length(operations)
    sewing = zeros(ComplexF64, 2, 2, num_operations, 1)
    target_matrices = zeros(ComplexF64, 2, 2, num_operations)
    for operation_index in eachindex(operations)
        action = MAGNETIC_FOUNDATION.spin_action_matrix(operations[operation_index], true)
        sewing[:, :, operation_index, 1] .= action
        target_matrices[:, :, operation_index] .= action
    end
    corrupt_operation === nothing || (sewing[1, 1, something(corrupt_operation), 1] += 0.25)
    representation = WannierNLQG.SymmetryFoundation.BandRepresentation(
        "1.2",
        :synthetic,
        true,
        Matrix{Float64}(I, 3, 3),
        2.0pi .* Matrix{Float64}(I, 3, 3),
        (1, 1, 1),
        zeros(1, 3),
        zeros(2, 1),
        operations,
        ones(Int, num_operations, 1),
        zeros(Int, 3, num_operations, 1),
        sewing,
        ones(Int, 2, 1),
        [1],
        [1],
        [1];
        conventions = Dict("msg_type" => string(inventory.msg_type)),
        input_sha256 = Dict("fixture" => repeat("a", 64)),
    )
    plan = WannierNLQG.SymmetryFoundation.WannierSymmetryPlan(
        operations,
        target_matrices,
        zeros(Int, 3, 2, num_operations),
    )
    return (; representation, plan)
end

@testset "Type-IV multiple phase-cut orbits and active-set cap" begin
    identity_operation = WannierNLQG.SymmetryFoundation.SymmetryOperation(
        Matrix{Int}(I, 3, 3),
        zeros(3),
        Matrix{Float64}(I, 3, 3),
    )
    antiunitary_half_translation = WannierNLQG.SymmetryFoundation.SymmetryOperation(
        Matrix{Int}(I, 3, 3),
        [0.5, 0.0, 0.0],
        Matrix{Float64}(I, 3, 3),
        true,
    )
    operations = [identity_operation, antiunitary_half_translation]
    sewing = zeros(ComplexF64, 4, 4, 2, 2)
    sewing[:, :, 1, 1] .= Matrix{ComplexF64}(I, 4, 4)
    sewing[:, :, 1, 2] .= Matrix{ComplexF64}(I, 4, 4)
    sewing[:, :, 2, 1] .= Matrix{ComplexF64}(I, 4, 4)
    sewing[:, :, 2, 2] .= -1.0im .* Matrix{ComplexF64}(I, 4, 4)
    reciprocal_shifts = zeros(Int, 3, 2, 2)
    reciprocal_shifts[1, 2, :] .= -1
    representation = WannierNLQG.SymmetryFoundation.BandRepresentation(
        "1.4",
        :synthetic,
        false,
        Matrix{Float64}(I, 3, 3),
        2.0pi .* Matrix{Float64}(I, 3, 3),
        (2, 1, 1),
        [0.25 0.0 0.0; 0.75 0.0 0.0],
        zeros(4, 2),
        operations,
        [1 2; 2 1],
        reciprocal_shifts,
        sewing,
        [1 1; 2 2; 3 3; 4 4],
        [1],
        [1, 1],
        [1, 2];
        conventions = Dict("msg_type" => "4"),
        input_sha256 = Dict("fixture" => repeat("5", 64)),
    )
    target = zeros(ComplexF64, 4, 4, 2)
    target[:, :, 1] .= Matrix{ComplexF64}(I, 4, 4)
    target[:, :, 2] .= ComplexF64[
        0 1 0 0
        1 0 0 0
        0 0 0 1
        0 0 1 0
    ]
    plan =
        WannierNLQG.SymmetryFoundation.WannierSymmetryPlan(operations, target, zeros(Int, 3, 4, 2))
    mmn_data = zeros(ComplexF64, 4, 4, 6, 2)
    for kpoint in 1:2, neighbor in 1:6
        mmn_data[:, :, neighbor, kpoint] .= Matrix{ComplexF64}(I, 4, 4)
    end
    mmn_data[:, :, 1, 1] .= Diagonal(ComplexF64[-1.0, 1.0, 1.0, 1.0])
    mmn_data[:, :, 2, 1] .= Diagonal(ComplexF64[1.0, 1.0, -1.0, 1.0])
    neighbors = [2 1; 2 1; 1 2; 1 2; 1 2; 1 2]
    mmn_shifts = zeros(Int, 3, 6, 2)
    mmn_shifts[1, 2, 1] = -1
    mmn_shifts[1, 1, 2] = 1
    mmn_shifts[2, 3, :] .= 1
    mmn_shifts[2, 4, :] .= -1
    mmn_shifts[3, 5, :] .= 1
    mmn_shifts[3, 6, :] .= -1
    mmn = MAGNETIC_WANNIER_IO.WannierMMN(4, 2, 6, mmn_data, neighbors, mmn_shifts)
    weights = MAGNETIC_WANNIERIZATION._finite_difference_weights(representation, mmn).weights
    tangent_plans = MAGNETIC_WANNIERIZATION._build_target_symmetry_tangent_plans(
        representation,
        plan;
        tolerance = 1.0e-10,
    )
    config = MAGNETIC_WANNIERIZATION_API.SymmetryAdaptedWannierizationConfig(
        input = MAGNETIC_WANNIERIZATION_API.WannierizationInputConfig(
            wannierization_mode = :symmetry_adapted,
            win_file = "unused.win",
            eig_file = "unused.eig",
            mmn_file = "unused.mmn",
            band_representation = representation,
            num_wannier = 4,
        ),
        solver = MAGNETIC_WANNIERIZATION_API.WannierizationSolverConfig(
            acceleration = MAGNETIC_WANNIERIZATION_API.WannierizationAccelerationConfig(
                u_phase_branch_tolerance = 1.0e-6,
                u_branch_active_set_max_orbits = 4,
            ),
        ),
        checkpoint = MAGNETIC_WANNIERIZATION_API.WannierizationCheckpointConfig(),
        runtime = MAGNETIC_WANNIERIZATION_API.WannierizationRuntimeConfig(),
        output = MAGNETIC_WANNIERIZATION_API.WannierizationOutputConfig(),
    )
    frames = [Matrix{ComplexF64}(I, 4, 4), Matrix{ComplexF64}(I, 4, 4)]
    result = MAGNETIC_WANNIERIZATION._evaluate_mv_localization(
        config,
        frames,
        zeros(4, 3),
        representation,
        mmn,
        weights,
        plan,
        tangent_plans,
    )
    @test result.success
    @test length(result.evaluation.active_links) >= 2
    @test length(result.evaluation.active_orbit_digests) == 2
    stable_members = [
        MAGNETIC_WANNIERIZATION.MVPhaseBranchLink(2, 3, 1, -pi + 1.0e-8, 1.0e-8, 2pi),
        MAGNETIC_WANNIERIZATION.MVPhaseBranchLink(1, 4, 2, pi - 2.0e-8, 2.0e-8, -2pi),
    ]
    varied_fields_same_identity = [
        MAGNETIC_WANNIERIZATION.MVPhaseBranchLink(1, 4, 2, pi - 7.0e-7, 7.0e-7, -4pi),
        MAGNETIC_WANNIERIZATION.MVPhaseBranchLink(2, 3, 1, -pi + 4.0e-7, 4.0e-7, 6pi),
    ]
    changed_side = copy(varied_fields_same_identity)
    changed_side[1] = MAGNETIC_WANNIERIZATION.MVPhaseBranchLink(
        changed_side[1].kpoint,
        changed_side[1].neighbor,
        changed_side[1].wannier,
        changed_side[1].phase,
        changed_side[1].margin,
        4pi,
    )
    stable_digest = MAGNETIC_WANNIERIZATION._mv_branch_orbit_digest(stable_members)
    @test stable_digest ==
          MAGNETIC_WANNIERIZATION._mv_branch_orbit_digest(varied_fields_same_identity)
    @test stable_digest != MAGNETIC_WANNIERIZATION._mv_branch_orbit_digest(changed_side)
    @test MAGNETIC_WANNIERIZATION._u_branch_signature(["b", "a"]) ==
          MAGNETIC_WANNIERIZATION._u_branch_signature(["a", "b"])
    target_at_k1 = MAGNETIC_WANNIERIZATION.target_representation(plan, representation, 2, 1)
    for jump in result.evaluation.branch_jump_full
        @test jump[2] ≈ target_at_k1 * conj(jump[1]) * target_at_k1' atol = 1.0e-12 rtol = 0.0
    end

    capped_config = MAGNETIC_WANNIERIZATION_API.SymmetryAdaptedWannierizationConfig(
        input = MAGNETIC_WANNIERIZATION_API.WannierizationInputConfig(
            wannierization_mode = :symmetry_adapted,
            win_file = "unused.win",
            eig_file = "unused.eig",
            mmn_file = "unused.mmn",
            band_representation = representation,
            num_wannier = 4,
        ),
        solver = MAGNETIC_WANNIERIZATION_API.WannierizationSolverConfig(
            acceleration = MAGNETIC_WANNIERIZATION_API.WannierizationAccelerationConfig(
                u_phase_branch_tolerance = 1.0e-6,
                u_branch_active_set_max_orbits = 1,
            ),
        ),
        checkpoint = MAGNETIC_WANNIERIZATION_API.WannierizationCheckpointConfig(),
        runtime = MAGNETIC_WANNIERIZATION_API.WannierizationRuntimeConfig(),
        output = MAGNETIC_WANNIERIZATION_API.WannierizationOutputConfig(),
    )
    capped = MAGNETIC_WANNIERIZATION._evaluate_mv_localization(
        capped_config,
        frames,
        zeros(4, 3),
        representation,
        mmn,
        weights,
        plan,
        tangent_plans,
    )
    @test !capped.success
    @test capped.code == :U_BRANCH_ACTIVE_SET_LIMIT
    @test capped.active_orbit_count == 2
end

# Two identical Type-III spinor corepresentations provide one exact frozen
# copy and one target/free complement copy.
function magnetic_double_gamma_fixture(inventory)
    operations = inventory.operations
    num_operations = length(operations)
    sewing = zeros(ComplexF64, 4, 4, num_operations, 1)
    target_matrices = zeros(ComplexF64, 4, 4, num_operations)
    for operation_index in eachindex(operations)
        action = MAGNETIC_FOUNDATION.spin_action_matrix(operations[operation_index], true)
        doubled = zeros(ComplexF64, 4, 4)
        doubled[1:2, 1:2] .= action
        doubled[3:4, 3:4] .= action
        sewing[:, :, operation_index, 1] .= doubled
        target_matrices[:, :, operation_index] .= doubled
    end
    representation = WannierNLQG.SymmetryFoundation.BandRepresentation(
        "1.3",
        :synthetic,
        true,
        Matrix{Float64}(I, 3, 3),
        2.0pi .* Matrix{Float64}(I, 3, 3),
        (1, 1, 1),
        zeros(1, 3),
        zeros(4, 1),
        operations,
        ones(Int, num_operations, 1),
        zeros(Int, 3, num_operations, 1),
        sewing,
        ones(Int, 4, 1),
        [1],
        [1],
        [1];
        conventions = Dict("msg_type" => string(inventory.msg_type)),
        input_sha256 = Dict("fixture" => repeat("c", 64)),
    )
    plan = WannierNLQG.SymmetryFoundation.WannierSymmetryPlan(
        operations,
        target_matrices,
        zeros(Int, 3, 4, num_operations),
    )
    return (; representation, plan)
end

# Construct the minimal Type-IV half-translation algebra on k=(1/4,3/4).
function type4_half_translation_fixture(; omit_half_translation_phase::Bool = false)
    identity_operation = WannierNLQG.SymmetryFoundation.SymmetryOperation(
        Matrix{Int}(I, 3, 3),
        zeros(3),
        Matrix{Float64}(I, 3, 3),
    )
    antiunitary_half_translation = WannierNLQG.SymmetryFoundation.SymmetryOperation(
        Matrix{Int}(I, 3, 3),
        [0.5, 0.0, 0.0],
        Matrix{Float64}(I, 3, 3),
        true,
    )
    sewing = ones(ComplexF64, 1, 1, 2, 2)
    if !omit_half_translation_phase
        sewing[1, 1, 2, 1] = 1.0
        sewing[1, 1, 2, 2] = -im
    end
    reciprocal_shifts = zeros(Int, 3, 2, 2)
    reciprocal_shifts[1, 2, :] .= -1
    return WannierNLQG.SymmetryFoundation.BandRepresentation(
        "1.2",
        :synthetic,
        false,
        Matrix{Float64}(I, 3, 3),
        2.0pi .* Matrix{Float64}(I, 3, 3),
        (2, 1, 1),
        [0.25 0.0 0.0; 0.75 0.0 0.0],
        zeros(1, 2),
        [identity_operation, antiunitary_half_translation],
        [1 2; 2 1],
        reciprocal_shifts,
        sewing,
        ones(Int, 1, 2),
        [1],
        [1, 1],
        [1, 2];
        input_sha256 = Dict("fixture" => repeat("b", 64)),
    )
end

@testset "Type-I--IV magnetic symmetry classification" begin
    triclinic = WannierNLQG.SymmetryFoundation.CrystalStructure(
        [1.0 0.0 0.0; 0.2 1.3 0.0; 0.1 0.3 1.7],
        ["X"],
        zeros(3, 1);
        magnetic_moments_cartesian = reshape([0.31, 0.47, 0.83], 3, 1),
    )
    type1 = WannierNLQG.SymmetryFoundation.detect_magnetic_symmetry_inventory(triclinic)
    @test type1.msg_type == 1
    @test type1.antiunitary_operation_count == 0

    gaas = WannierNLQG.SymmetryFoundation.CrystalStructure(
        5.65 / 2 .* [0.0 1 1; 1 0 1; 1 1 0],
        ["Ga", "As"],
        [0.0 0.25; 0.0 0.25; 0.0 0.25],
    )
    type2 = WannierNLQG.SymmetryFoundation.detect_magnetic_symmetry_inventory(gaas)
    @test type2.msg_type == 2
    @test type2.unitary_operation_count == type2.antiunitary_operation_count

    fe = WannierNLQG.SymmetryFoundation.CrystalStructure(
        2.87 / 2 .* [-1.0 1 1; 1 -1 1; 1 1 -1],
        ["Fe"],
        zeros(3, 1);
        magnetic_moments_cartesian = reshape([0.0, 0.0, 1.0], 3, 1),
    )
    type3 = WannierNLQG.SymmetryFoundation.detect_magnetic_symmetry_inventory(fe)
    @test type3.msg_type == 3
    @test type3.uni_number == 1197
    @test length(type3.operations) == 16
    @test type3.antiunitary_operation_count == 8

    nio = WannierNLQG.SymmetryFoundation.CrystalStructure(
        4.2 .* [1.0 0.5 0.5; 0.5 1 0.5; 0.5 0.5 1],
        ["Ni", "Ni", "O", "O"],
        [0.0 0.5 0.25 0.75; 0.0 0.5 0.25 0.75; 0.0 0.5 0.25 0.75];
        magnetic_moments_cartesian = [0.0 0 0 0; 0 0 0 0; 1 -1 0 0],
    )
    type4 = WannierNLQG.SymmetryFoundation.detect_magnetic_symmetry_inventory(nio)
    @test type4.msg_type == 4
    @test type4.uni_number == 97
    @test length(type4.operations) == 8
    @test type4.antiunitary_operation_count == 4
end

@testset "Fe magnetic projection contract preserves individual d orbitals" begin
    structure = WannierNLQG.SymmetryFoundation.CrystalStructure(
        2.87 / 2 .* [-1.0 1 1; 1 -1 1; 1 1 -1],
        ["Fe"],
        zeros(3, 1),
    )
    parsed = WannierNLQG.WannierProjection.parse_projection_line("Fe: sp3d2;dxy;dxz;dyz")
    @test parsed[2] == ["sp3d2", "t2g_dxy_first"]
    basis = WannierNLQG.WannierProjection.WannierProjectionBasis(
        [WannierNLQG.WannierProjection.ProjectionSpec(selector = "Fe", orbital_sets = parsed[2])];
        structure,
        spinor = true,
        num_wannier = 18,
    )
    @test basis.num_wannier == 18
    @test [block.orbital_set for block in basis.blocks] == ["sp3d2", "t2g_dxy_first"]
end

@testset "General magnetic corepresentation and negative controls" begin
    fe = WannierNLQG.SymmetryFoundation.CrystalStructure(
        2.87 / 2 .* [-1.0 1 1; 1 -1 1; 1 1 -1],
        ["Fe"],
        zeros(3, 1);
        magnetic_moments_cartesian = reshape([0.0, 0.0, 1.0], 3, 1),
    )
    inventory = WannierNLQG.SymmetryFoundation.detect_magnetic_symmetry_inventory(fe)
    fixture = magnetic_gamma_fixture(inventory)
    report = MAGNETIC_WANNIERIZATION.validate_band_representation_compatibility(
        fixture.representation,
        fixture.plan;
        outer_mask = [trues(2)],
        frozen_mask = [trues(2)],
        tolerance = 1.0e-10,
    )
    @test report.supported_contract
    @test report.passed
    @test maximum(report.maximum_group_law_residuals) <= 1.0e-10

    antiunitary_index = findfirst(operation -> operation.antiunitary, inventory.operations)
    missing_antiunitary = deleteat!(copy(inventory.operations), antiunitary_index)
    missing_error = try
        MAGNETIC_REPRESENTATION._build_representation_product_table(
            missing_antiunitary,
            true;
            tolerance = 1.0e-10,
        )
        nothing
    catch exception
        exception
    end
    @test missing_error isa ArgumentError
    @test occursin("operation product", sprint(showerror, missing_error))

    corrupted = magnetic_gamma_fixture(inventory; corrupt_operation = antiunitary_index)
    corrupted_report = MAGNETIC_WANNIERIZATION.validate_band_representation_compatibility(
        corrupted.representation,
        corrupted.plan;
        outer_mask = [trues(2)],
        tolerance = 1.0e-10,
    )
    @test !corrupted_report.passed
    @test any(
        diagnostic ->
            diagnostic.code in (:ANTIUNITARY_GROUP_LAW_FAILED, :REQUIRED_BLOCK_UNITARITY_FAILED),
        corrupted_report.diagnostics,
    )

    complex_antiunitary_index = argmax([
        operation.antiunitary ?
        maximum(
            abs,
            MAGNETIC_FOUNDATION.spin_action_matrix(operation, true) .-
            conj(MAGNETIC_FOUNDATION.spin_action_matrix(operation, true)),
        ) : -1.0 for operation in inventory.operations
    ])
    wrong_conjugation = magnetic_gamma_fixture(inventory)
    wrong_conjugation.representation.sewing_matrices[:, :, complex_antiunitary_index, 1] .=
        conj.(wrong_conjugation.representation.sewing_matrices[:, :, complex_antiunitary_index, 1])
    wrong_conjugation_report = MAGNETIC_WANNIERIZATION.validate_band_representation_compatibility(
        wrong_conjugation.representation,
        wrong_conjugation.plan;
        outer_mask = [trues(2)],
        tolerance = 1.0e-10,
    )
    @test !wrong_conjugation_report.passed
    @test any(
        diagnostic -> diagnostic.code == :ANTIUNITARY_GROUP_LAW_FAILED,
        wrong_conjugation_report.diagnostics,
    )

    wrong_double_group_sign = magnetic_gamma_fixture(inventory)
    wrong_double_group_sign.representation.sewing_matrices[:, :, antiunitary_index, 1] .*= -1
    wrong_double_group_sign_report =
        MAGNETIC_WANNIERIZATION.validate_band_representation_compatibility(
            wrong_double_group_sign.representation,
            wrong_double_group_sign.plan;
            outer_mask = [trues(2)],
            tolerance = 1.0e-10,
        )
    @test !wrong_double_group_sign_report.passed
    @test any(
        diagnostic -> diagnostic.code == :ANTIUNITARY_GROUP_LAW_FAILED,
        wrong_double_group_sign_report.diagnostics,
    )

    type4 = type4_half_translation_fixture()
    type4_report = MAGNETIC_WANNIERIZATION.validate_band_representation_compatibility(
        type4;
        outer_mask = [trues(1), trues(1)],
        tolerance = 1.0e-10,
    )
    @test type4_report.passed
    truncated = MAGNETIC_WANNIERIZATION.validate_band_representation_compatibility(
        type4;
        outer_mask = [trues(1), trues(1)],
        frozen_mask = [trues(1), falses(1)],
        tolerance = 1.0e-10,
    )
    @test !truncated.passed
    @test any(
        diagnostic -> diagnostic.code == :COREPRESENTATION_BLOCK_NOT_CLOSED,
        truncated.diagnostics,
    )
    missing_phase = type4_half_translation_fixture(; omit_half_translation_phase = true)
    missing_phase_report = MAGNETIC_WANNIERIZATION.validate_band_representation_compatibility(
        missing_phase;
        outer_mask = [trues(1), trues(1)],
        tolerance = 1.0e-10,
    )
    @test !missing_phase_report.passed
    @test any(
        diagnostic -> diagnostic.code == :ANTIUNITARY_GROUP_LAW_FAILED,
        missing_phase_report.diagnostics,
    )

    identity_operation = WannierNLQG.SymmetryFoundation.SymmetryOperation(
        Matrix{Int}(I, 3, 3),
        zeros(3),
        Matrix{Float64}(I, 3, 3),
    )
    inversion_operation = WannierNLQG.SymmetryFoundation.SymmetryOperation(
        -Matrix{Int}(I, 3, 3),
        zeros(3),
        -Matrix{Float64}(I, 3, 3),
    )
    multiplicity_sewing = zeros(ComplexF64, 2, 2, 2, 1)
    multiplicity_sewing[:, :, 1, 1] .= Matrix{ComplexF64}(I, 2, 2)
    multiplicity_sewing[:, :, 2, 1] .= Diagonal(ComplexF64[1.0, -1.0])
    multiplicity_representation = WannierNLQG.SymmetryFoundation.BandRepresentation(
        "1.2",
        :synthetic,
        false,
        Matrix{Float64}(I, 3, 3),
        2.0pi .* Matrix{Float64}(I, 3, 3),
        (1, 1, 1),
        zeros(1, 3),
        zeros(2, 1),
        [identity_operation, inversion_operation],
        ones(Int, 2, 1),
        zeros(Int, 3, 2, 1),
        multiplicity_sewing,
        ones(Int, 2, 1),
        [1],
        [1],
        [1];
        input_sha256 = Dict("fixture" => repeat("c", 64)),
    )
    trivial_target = repeat(ones(ComplexF64, 2, 2), 1, 1, 2)
    trivial_target[:, :, 1] .= Matrix{ComplexF64}(I, 2, 2)
    trivial_target[:, :, 2] .= Matrix{ComplexF64}(I, 2, 2)
    multiplicity_plan = WannierNLQG.SymmetryFoundation.WannierSymmetryPlan(
        [identity_operation, inversion_operation],
        trivial_target,
        zeros(Int, 3, 2, 2),
    )
    multiplicity_report = MAGNETIC_WANNIERIZATION.validate_band_representation_compatibility(
        multiplicity_representation,
        multiplicity_plan;
        outer_mask = [trues(2)],
        tolerance = 1.0e-10,
    )
    @test !multiplicity_report.passed
    @test any(
        diagnostic -> diagnostic.code == :TARGET_COREPRESENTATION_MULTIPLICITY_MISMATCH,
        multiplicity_report.diagnostics,
    )
end

@testset "Type-III constrained frozen corepresentation initializer" begin
    structure = WannierNLQG.SymmetryFoundation.CrystalStructure(
        2.87 / 2 .* [-1.0 1 1; 1 -1 1; 1 1 -1],
        ["Fe"],
        zeros(3, 1);
        magnetic_moments_cartesian = reshape([0.0, 0.0, 1.0], 3, 1),
    )
    inventory = WannierNLQG.SymmetryFoundation.detect_magnetic_symmetry_inventory(structure)
    fixture = magnetic_double_gamma_fixture(inventory)
    exact_amn = reshape(Matrix{ComplexF64}(I, 4, 4), 4, 4, 1)
    frames, diagnostics, invariants = MAGNETIC_WANNIERIZATION._constrained_frozen_initial_frames(
        fixture.representation,
        fixture.plan,
        [collect(1:4)],
        [[1, 2]],
        exact_amn,
    )
    @test length(diagnostics) == 1
    @test diagnostics[1].frozen_rank == 2
    @test diagnostics[1].free_rank == 2
    @test invariants.isometry_residual <= 1.0e-10
    @test invariants.frozen_projector_residual <= 1.0e-10
    @test invariants.covariance_residual <= 1.0e-3
    @test frames[1] * frames[1]' ≈ Matrix{ComplexF64}(I, 4, 4) atol = 1.0e-10 rtol = 0.0

    changed_amn = copy(exact_amn)
    changed_amn[1, 3, 1] = 0.125
    changed_amn[3, 1, 1] = -0.075im
    changed_frames, _, _ = MAGNETIC_WANNIERIZATION._constrained_frozen_initial_frames(
        fixture.representation,
        fixture.plan,
        [collect(1:4)],
        [[1, 2]],
        changed_amn,
    )
    @test norm(changed_frames[1] - frames[1]) > 1.0e-8

    rank_error = try
        MAGNETIC_WANNIERIZATION._constrained_frozen_initial_frames(
            fixture.representation,
            fixture.plan,
            [collect(1:4)],
            [[1, 2]],
            zeros(ComplexF64, 4, 4, 1),
        )
        nothing
    catch exception
        exception
    end
    @test rank_error isa MAGNETIC_WANNIERIZATION.FrozenCorepresentationInitializationError
    @test rank_error.code == :FROZEN_TARGET_COREPRESENTATION_MISMATCH
    @test haskey(rank_error.context, "singular_values")

    rotation = Matrix(qr(reshape(ComplexF64.(1:16), 4, 4)).Q)
    updated_frames = [frames[1] * rotation]
    @test updated_frames[1]' * updated_frames[1] ≈ Matrix{ComplexF64}(I, 4, 4) atol = 1.0e-10 rtol =
        0.0
    @test updated_frames[1] * updated_frames[1]' ≈ Matrix{ComplexF64}(I, 4, 4) atol = 1.0e-10 rtol =
        0.0

    single_target = WannierNLQG.SymmetryFoundation.WannierSymmetryPlan(
        fixture.plan.operations,
        fixture.plan.representation_matrices[1:2, 1:2, :],
        fixture.plan.wannier_shifts[:, 1:2, :],
    )
    truncated_error = try
        MAGNETIC_WANNIERIZATION._constrained_frozen_initial_frames(
            fixture.representation,
            single_target,
            [collect(1:4)],
            [[1, 2, 3]],
            exact_amn[:, 1:2, :],
        )
        nothing
    catch exception
        exception
    end
    @test truncated_error isa MAGNETIC_WANNIERIZATION.FrozenCorepresentationInitializationError
    @test truncated_error.code == :FROZEN_TARGET_COREPRESENTATION_MISMATCH

    free_error = try
        MAGNETIC_WANNIERIZATION._constrained_frozen_initial_frames(
            fixture.representation,
            fixture.plan,
            [[1, 2, 3]],
            [[1, 2]],
            exact_amn,
        )
        nothing
    catch exception
        exception
    end
    @test free_error isa MAGNETIC_WANNIERIZATION.FrozenCorepresentationInitializationError
    @test free_error.code == :FROZEN_FREE_COMPLEMENT_RANK_DEFICIENT

    metrics = MAGNETIC_WANNIERIZATION._amn_target_qualification_metrics(
        fixture.representation,
        fixture.plan,
        exact_amn,
        [collect(1:4)],
        [[1, 2]],
    )
    @test metrics.passed
    @test metrics.amn_unitary_covariance_residual <= 1.0e-10
    @test metrics.amn_antiunitary_covariance_residual <= 1.0e-10

    wrong_amn = copy(exact_amn)
    wrong_amn[1, 2, 1] = 0.25
    wrong_metrics = MAGNETIC_WANNIERIZATION._amn_target_qualification_metrics(
        fixture.representation,
        fixture.plan,
        wrong_amn,
        [collect(1:4)],
        [[1, 2]],
    )
    @test !wrong_metrics.passed
    @test wrong_metrics.failure == "AMN_TARGET_COVARIANCE_FAILED"
end

@testset "QE atomic-type labels use UPF chemical elements" begin
    extension = Base.get_extension(WannierNLQG, :WannierNLQGWannierizationExt)
    extension === nothing && WannierNLQG.Wannierization._load_wannierization_extension!()
    extension = Base.get_extension(WannierNLQG, :WannierNLQGWannierizationExt)
    mktempdir() do directory
        write(joinpath(directory, "Ni.upf"), "<UPF><PP_HEADER element=\"Ni\"/></UPF>")
        xml = EzXML.parsexml(
            "<input><atomic_species><species name=\"Ni1\"><pseudo_file>Ni.upf</pseudo_file></species>" *
            "<species name=\"Ni2\"><pseudo_file>Ni.upf</pseudo_file></species></atomic_species></input>",
        )
        mapping, files = Base.invokelatest(
            MAGNETIC_REPRESENTATION._qe_atomic_type_elements,
            EzXML.root(xml),
            directory,
        )
        @test mapping == Dict("Ni1" => "Ni", "Ni2" => "Ni")
        @test all(isfile, values(files))
        write(joinpath(directory, "Co.upf"), "<UPF><PP_HEADER element=\"Co\"/></UPF>")
        conflicting_xml = EzXML.parsexml(
            "<input><atomic_species><species name=\"Ni1\"><pseudo_file>Co.upf</pseudo_file>" *
            "</species></atomic_species></input>",
        )
        conflict = try
            Base.invokelatest(
                MAGNETIC_REPRESENTATION._qe_atomic_type_elements,
                EzXML.root(conflicting_xml),
                directory,
            )
            nothing
        catch exception
            exception
        end
        @test conflict isa ArgumentError
        @test occursin("conflicts with UPF PP_HEADER element", sprint(showerror, conflict))
        write(joinpath(directory, "bad.upf"), "<UPF><PP_HEADER/></UPF>")
        @test_throws ArgumentError Base.invokelatest(
            MAGNETIC_REPRESENTATION._qe_upf_element,
            joinpath(directory, "bad.upf"),
        )

        wavefunction = joinpath(directory, "wfc1.hdf5")
        HDF5.h5open(wavefunction, "w") do handle
            root_attributes = HDF5.attributes(handle)
            root_attributes["igwx"] = 2
            root_attributes["nbnd"] = 1
            root_attributes["npol"] = 2
            root_attributes["xk"] = zeros(3)
            root_attributes["scale_factor"] = 1.0
            handle["MillerIndices"] = [0 1; 0 0; 0 0]
            miller_attributes = HDF5.attributes(handle["MillerIndices"])
            miller_attributes["bg1"] = [1.0, 0.0, 0.0]
            miller_attributes["bg2"] = [0.0, 1.0, 0.0]
            miller_attributes["bg3"] = [0.0, 0.0, 1.0]
            handle["evc"] = reshape([1.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0], 8, 1)
        end
        point = Base.invokelatest(
            MAGNETIC_REPRESENTATION._read_qe_hdf5_kpoint,
            wavefunction,
            1:1,
            [0.5],
            2,
            1.0e6,
            2.0pi .* Matrix{Float64}(I, 3, 3),
            true,
        )
        @test size(point.coefficients) == (1, 2, 2)
        @test point.energies_ev == [0.5]
        @test sum(abs2, point.coefficients) == 1.0
    end
end

@testset "single collinear channel cannot represent antiunitary exchange" begin
    lattice = Matrix{Float64}(I, 3, 3)
    structure = WannierNLQG.SymmetryFoundation.CrystalStructure(lattice, ["Fe"], zeros(3, 1))
    point = WannierNLQG.SymmetryFoundation.PlaneWaveKPoint(
        zeros(3),
        zeros(Int, 1, 3),
        ones(ComplexF64, 1, 1, 1),
        [0.0],
    )
    native = WannierNLQG.SymmetryFoundation.NativeWavefunctionData(
        :qe,
        structure,
        2pi .* lattice,
        (1, 1, 1),
        false,
        [point],
        Dict("fixture" => repeat("d", 64)),
        Dict("spin_mode" => "collinear_single_channel", "spin_channel" => "up"),
    )
    identity_operation =
        WannierNLQG.SymmetryFoundation.SymmetryOperation(Matrix{Int}(I, 3, 3), zeros(3), lattice)
    time_reversal = WannierNLQG.SymmetryFoundation.SymmetryOperation(
        Matrix{Int}(I, 3, 3),
        zeros(3),
        lattice,
        true,
    )
    error = try
        Base.invokelatest(
            MAGNETIC_FOUNDATION.validate_canonical_antiunitary_channel,
            native,
            [identity_operation, time_reversal],
        )
        nothing
    catch exception
        exception
    end
    @test error isa ArgumentError
    @test occursin("ANTIUNITARY_CHANNEL_MIXING_UNSUPPORTED", sprint(showerror, error))
    @test isnothing(
        Base.invokelatest(
            MAGNETIC_FOUNDATION.validate_canonical_antiunitary_channel,
            native,
            [identity_operation],
        ),
    )
end

@testset "Type-III symmetry tangent without frozen-Wannier locking" begin
    fe = WannierNLQG.SymmetryFoundation.CrystalStructure(
        2.87 / 2 .* [-1.0 1 1; 1 -1 1; 1 1 -1],
        ["Fe"],
        zeros(3, 1);
        magnetic_moments_cartesian = reshape([0.0, 0.0, 1.0], 3, 1),
    )
    inventory = WannierNLQG.SymmetryFoundation.detect_magnetic_symmetry_inventory(fe)
    fixture = magnetic_double_gamma_fixture(inventory)
    plans = MAGNETIC_WANNIERIZATION._build_target_symmetry_tangent_plans(
        fixture.representation,
        fixture.plan,
        tolerance = 1.0e-10,
    )
    tangent_plan = something(plans[1])
    @test tangent_plan.maximum_basis_residual <= 64.0e-10
    probe = reshape(ComplexF64.(1:16) .+ 1.0im .* ComplexF64.(16:-1:1), 4, 4)
    projected = MAGNETIC_WANNIERIZATION._project_target_symmetry_tangent(tangent_plan, probe)
    for (operation_index, operation) in enumerate(inventory.operations)
        target = fixture.plan.representation_matrices[:, :, operation_index]
        residual =
            operation.antiunitary ? target * conj(projected) - projected * target :
            target * projected - projected * target
        @test maximum(abs, residual) <= 1.0e-9
    end
    mixing = ComplexF64[0 0 1 0; 0 0 0 1; -1 0 0 0; 0 -1 0 0]
    tangent = MAGNETIC_WANNIERIZATION._project_target_symmetry_tangent(tangent_plan, mixing)
    tangent = (tangent - tangent') / 2
    @test maximum(abs, tangent + tangent') <= 1.0e-10
    @test maximum(abs, tangent[1:2, 3:4]) > 1.0e-6
    @test maximum(
        abs,
        MAGNETIC_WANNIERIZATION._project_target_symmetry_tangent(tangent_plan, tangent) - tangent,
    ) <= 1.0e-9
    transported = MAGNETIC_WANNIERIZATION._transport_ibz_tangent_field(
        [projected + 0.7tangent],
        [1],
        Union{Nothing, MAGNETIC_WANNIERIZATION.TargetSymmetryTangentPlan}[tangent_plan],
    )[1]
    @test maximum(abs, transported + transported') <= 1.0e-10
    for (operation_index, operation) in enumerate(inventory.operations)
        target = fixture.plan.representation_matrices[:, :, operation_index]
        residual =
            operation.antiunitary ? target * conj(transported) - transported * target :
            target * transported - transported * target
        @test maximum(abs, residual) <= 1.0e-9
    end
    @test maximum(
        abs,
        MAGNETIC_WANNIERIZATION._project_target_symmetry_tangent(tangent_plan, transported) -
        transported,
    ) <= 1.0e-9
    @test MAGNETIC_WANNIERIZATION._transport_ibz_tangent_field(
        [transported],
        [1],
        Union{Nothing, MAGNETIC_WANNIERIZATION.TargetSymmetryTangentPlan}[tangent_plan],
    )[1] ≈ transported atol = 1.0e-10
end

@testset "Type-IV real-linear MV gradient finite difference" begin
    identity_operation = WannierNLQG.SymmetryFoundation.SymmetryOperation(
        Matrix{Int}(I, 3, 3),
        zeros(3),
        Matrix{Float64}(I, 3, 3),
    )
    antiunitary_half_translation = WannierNLQG.SymmetryFoundation.SymmetryOperation(
        Matrix{Int}(I, 3, 3),
        [0.5, 0.0, 0.0],
        Matrix{Float64}(I, 3, 3),
        true,
    )
    operations = [identity_operation, antiunitary_half_translation]
    sewing = zeros(ComplexF64, 2, 2, 2, 2)
    sewing[:, :, 1, 1] .= Matrix{ComplexF64}(I, 2, 2)
    sewing[:, :, 1, 2] .= Matrix{ComplexF64}(I, 2, 2)
    sewing[:, :, 2, 1] .= Matrix{ComplexF64}(I, 2, 2)
    sewing[:, :, 2, 2] .= -1.0im .* Matrix{ComplexF64}(I, 2, 2)
    reciprocal_shifts = zeros(Int, 3, 2, 2)
    reciprocal_shifts[1, 2, :] .= -1
    representation = WannierNLQG.SymmetryFoundation.BandRepresentation(
        "1.4",
        :synthetic,
        false,
        Matrix{Float64}(I, 3, 3),
        2.0pi .* Matrix{Float64}(I, 3, 3),
        (2, 1, 1),
        [0.25 0.0 0.0; 0.75 0.0 0.0],
        zeros(2, 2),
        operations,
        [1 2; 2 1],
        reciprocal_shifts,
        sewing,
        [1 1; 2 2],
        [1],
        [1, 1],
        [1, 2];
        conventions = Dict("msg_type" => "4"),
        input_sha256 = Dict("fixture" => repeat("4", 64)),
    )
    target = zeros(ComplexF64, 2, 2, 2)
    target[:, :, 1] .= Matrix{ComplexF64}(I, 2, 2)
    target[:, :, 2] .= ComplexF64[0 1; 1 0]
    target_shifts = zeros(Int, 3, 2, 2)
    target_shifts[1, 2, 2] = 1
    plan = WannierNLQG.SymmetryFoundation.WannierSymmetryPlan(operations, target, target_shifts)
    mmn_data = zeros(ComplexF64, 2, 2, 6, 2)
    for kpoint in 1:2, neighbor in 1:6
        mmn_data[:, :, neighbor, kpoint] .= Matrix{ComplexF64}(I, 2, 2)
    end
    neighbors = [2 1; 2 1; 1 2; 1 2; 1 2; 1 2]
    mmn_shifts = zeros(Int, 3, 6, 2)
    mmn_shifts[1, 2, 1] = -1
    mmn_shifts[1, 1, 2] = 1
    mmn_shifts[2, 3, :] .= 1
    mmn_shifts[2, 4, :] .= -1
    mmn_shifts[3, 5, :] .= 1
    mmn_shifts[3, 6, :] .= -1
    mmn = MAGNETIC_WANNIER_IO.WannierMMN(2, 2, 6, mmn_data, neighbors, mmn_shifts)
    angle_value = 0.31
    frame_1 = Matrix{ComplexF64}(I, 2, 2)
    frame_2 = ComplexF64[
        cos(angle_value) sin(angle_value)
        -sin(angle_value) cos(angle_value)
    ]
    frames = [frame_1, frame_2]
    weights = MAGNETIC_WANNIERIZATION._finite_difference_weights(representation, mmn).weights
    centers, _, _ = MAGNETIC_WANNIERIZATION._evaluate_full_mesh_centers_spreads_and_directions(
        frames,
        zeros(2, 3),
        representation,
        mmn,
        weights,
    )
    raw = MAGNETIC_WANNIERIZATION._mv_spread_gradient(
        frames,
        centers,
        representation,
        mmn,
        weights,
        1.0e-10,
    )
    @test raw.success
    tangent_plans = MAGNETIC_WANNIERIZATION._build_target_symmetry_tangent_plans(
        representation,
        plan;
        tolerance = 1.0e-10,
    )
    target_at_k1 = MAGNETIC_WANNIERIZATION.target_representation(plan, representation, 2, 1)
    evaluation_config = MAGNETIC_WANNIERIZATION_API.SymmetryAdaptedWannierizationConfig(
        input = MAGNETIC_WANNIERIZATION_API.WannierizationInputConfig(
            wannierization_mode = :symmetry_adapted,
            win_file = "unused.win",
            eig_file = "unused.eig",
            mmn_file = "unused.mmn",
            band_representation = representation,
            num_wannier = 2,
        ),
        solver = MAGNETIC_WANNIERIZATION_API.WannierizationSolverConfig(
            acceleration = MAGNETIC_WANNIERIZATION_API.WannierizationAccelerationConfig(
                u_phase_branch_tolerance = 1.0e-8,
            ),
        ),
        checkpoint = MAGNETIC_WANNIERIZATION_API.WannierizationCheckpointConfig(),
        runtime = MAGNETIC_WANNIERIZATION_API.WannierizationRuntimeConfig(),
        output = MAGNETIC_WANNIERIZATION_API.WannierizationOutputConfig(),
    )
    evaluation_result = MAGNETIC_WANNIERIZATION._evaluate_mv_localization(
        evaluation_config,
        frames,
        centers,
        representation,
        mmn,
        weights,
        plan,
        tangent_plans,
    )
    @test evaluation_result.success
    evaluation = evaluation_result.evaluation
    @test isempty(evaluation.active_links)
    @test evaluation.gradient_rms > 0.0
    @test evaluation.full_gradients[2] ≈
          target_at_k1 * conj(evaluation.full_gradients[1]) * target_at_k1' atol = 1.0e-12 rtol =
        0.0
    chart_objective = function (step)
        trial_frames = [
            frames[kpoint] * exp(step .* evaluation.full_gradients[kpoint]) for
            kpoint in eachindex(frames)
        ]
        trial_result = MAGNETIC_WANNIERIZATION._evaluate_mv_localization(
            evaluation_config,
            trial_frames,
            centers,
            representation,
            mmn,
            weights,
            plan,
            tangent_plans,
        )
        @test trial_result.success
        return trial_result.evaluation.objective
    end
    chart_analytic = MAGNETIC_WANNIERIZATION._mv_generalized_directional_derivative(
        evaluation,
        evaluation.full_gradients,
    )
    for step in (1.0e-6, 3.0e-7, 1.0e-7)
        chart_fd =
            (
                -chart_objective(2step) + 8chart_objective(step) - 8chart_objective(-step) +
                chart_objective(-2step)
            ) / (12step)
        @test abs(chart_fd - chart_analytic) <=
              1.0e-8 + 1.0e-5 * max(abs(chart_fd), abs(chart_analytic))
    end

    # Put one diagonal link exactly on the principal-phase cut.  Its projected
    # jump must expand as one Type-IV real-linear orbit, and the minimum-norm
    # Clarke field must either provide a measurable one-sided descent or be
    # stationary.  A second cut link exercises the multi-orbit inventory.
    cut_reference =
        MAGNETIC_WANNIERIZATION._symmetrize_wannier_property(centers, representation, plan)
    cut_data = copy(mmn.data)
    cut_target = mmn.neighbors[1, 1]
    cut_displacement =
        MAGNETIC_WANNIERIZATION._mesh_neighbor_displacement(representation, mmn, 1, 1)
    cut_b = transpose(representation.reciprocal_lattice) * cut_displacement
    cut_phases = [-pi + 2.0e-8, 0.0] .- cut_reference * cut_b
    cut_overlap = Diagonal(cis.(cut_phases))
    cut_data[:, :, 1, 1] .= frames[1] * cut_overlap * frames[cut_target]'
    cut_reverse_neighbor = only(
        neighbor for
        neighbor in 1:mmn.num_neighbors if mmn.neighbors[neighbor, cut_target] == 1 &&
        norm(
            MAGNETIC_WANNIERIZATION._mesh_neighbor_displacement(
                representation,
                mmn,
                neighbor,
                cut_target,
            ) + cut_displacement,
        ) <= 1.0e-12
    )
    cut_data[:, :, cut_reverse_neighbor, cut_target] .=
        frames[cut_target] * cut_overlap' * frames[1]'
    cut_mmn = MAGNETIC_WANNIER_IO.WannierMMN(
        mmn.num_bands,
        mmn.num_kpts,
        mmn.num_neighbors,
        cut_data,
        copy(mmn.neighbors),
        copy(mmn.reciprocal_shifts),
    )
    cut_weights =
        MAGNETIC_WANNIERIZATION._finite_difference_weights(representation, cut_mmn).weights
    cut_config = MAGNETIC_WANNIERIZATION_API.SymmetryAdaptedWannierizationConfig(
        input = MAGNETIC_WANNIERIZATION_API.WannierizationInputConfig(
            wannierization_mode = :symmetry_adapted,
            win_file = "unused.win",
            eig_file = "unused.eig",
            mmn_file = "unused.mmn",
            band_representation = representation,
            num_wannier = 2,
        ),
        solver = MAGNETIC_WANNIERIZATION_API.WannierizationSolverConfig(
            acceleration = MAGNETIC_WANNIERIZATION_API.WannierizationAccelerationConfig(
                u_phase_branch_tolerance = 1.0e-6,
            ),
        ),
        checkpoint = MAGNETIC_WANNIERIZATION_API.WannierizationCheckpointConfig(),
        runtime = MAGNETIC_WANNIERIZATION_API.WannierizationRuntimeConfig(),
        output = MAGNETIC_WANNIERIZATION_API.WannierizationOutputConfig(),
    )
    cut_result = MAGNETIC_WANNIERIZATION._evaluate_mv_localization(
        cut_config,
        frames,
        cut_reference,
        representation,
        cut_mmn,
        cut_weights,
        plan,
        tangent_plans,
    )
    @test cut_result.success
    cut_evaluation = cut_result.evaluation
    @test !isempty(cut_evaluation.active_links)
    @test !isempty(cut_evaluation.active_orbit_digests)
    for jump in cut_evaluation.branch_jump_full
        @test jump[2] ≈ target_at_k1 * conj(jump[1]) * target_at_k1' atol = 1.0e-12 rtol = 0.0
    end
    cut_directional = MAGNETIC_WANNIERIZATION._mv_generalized_directional_derivative(
        cut_evaluation,
        cut_evaluation.full_gradients,
    )
    @test cut_directional <= 1.0e-12
    cut_trial_evaluation = function (step)
        trial_frames = [
            frames[kpoint] * exp(step .* cut_evaluation.full_gradients[kpoint]) for
            kpoint in eachindex(frames)
        ]
        trial_result = MAGNETIC_WANNIERIZATION._evaluate_mv_localization(
            cut_config,
            trial_frames,
            cut_reference,
            representation,
            cut_mmn,
            cut_weights,
            plan,
            tangent_plans,
        )
        @test trial_result.success
        return trial_result.evaluation
    end
    cut_objective = step -> cut_trial_evaluation(step).objective
    cut_interval = MAGNETIC_WANNIERIZATION._mv_generalized_directional_derivative_interval(
        cut_evaluation,
        cut_evaluation.full_gradients,
    )
    cut_zero = cut_objective(0.0)
    @test cut_zero ≈ cut_evaluation.objective atol = 1.0e-12 rtol = 0.0
    for step in (1.0e-9, 3.0e-10, 1.0e-10)
        trial_evaluation = cut_trial_evaluation(step)
        stable_change = MAGNETIC_WANNIERIZATION._mv_centered_objective_change(
            cut_evaluation,
            trial_evaluation,
            cut_reference,
            cut_weights,
        )
        @test stable_change ≈ trial_evaluation.objective - cut_zero atol = 1.0e-12 rtol = 0.0
        one_sided = stable_change / step
        @test cut_interval.lower <= one_sided + 5.0e-6
        @test one_sided <= cut_interval.upper + 5.0e-6
        @test one_sided <= 1.0e-7 || cut_evaluation.gradient_rms <= 1.0e-9
    end

    multiple_cut_data = copy(cut_data)
    second_target = mmn.neighbors[2, 1]
    second_displacement =
        MAGNETIC_WANNIERIZATION._mesh_neighbor_displacement(representation, mmn, 2, 1)
    second_b = transpose(representation.reciprocal_lattice) * second_displacement
    second_phases = [0.0, -pi + 3.0e-8] .- cut_reference * second_b
    second_overlap = Diagonal(cis.(second_phases))
    multiple_cut_data[:, :, 2, 1] .= frames[1] * second_overlap * frames[second_target]'
    second_reverse_neighbor = only(
        neighbor for
        neighbor in 1:mmn.num_neighbors if mmn.neighbors[neighbor, second_target] == 1 &&
        norm(
            MAGNETIC_WANNIERIZATION._mesh_neighbor_displacement(
                representation,
                mmn,
                neighbor,
                second_target,
            ) + second_displacement,
        ) <= 1.0e-12
    )
    multiple_cut_data[:, :, second_reverse_neighbor, second_target] .=
        frames[second_target] * second_overlap' * frames[1]'
    multiple_cut_mmn = MAGNETIC_WANNIER_IO.WannierMMN(
        mmn.num_bands,
        mmn.num_kpts,
        mmn.num_neighbors,
        multiple_cut_data,
        copy(mmn.neighbors),
        copy(mmn.reciprocal_shifts),
    )
    multiple_result = MAGNETIC_WANNIERIZATION._evaluate_mv_localization(
        cut_config,
        frames,
        cut_reference,
        representation,
        multiple_cut_mmn,
        cut_weights,
        plan,
        tangent_plans,
    )
    @test multiple_result.success
    @test length(multiple_result.evaluation.active_links) >= 2
    @test length(multiple_result.evaluation.active_orbit_digests) >= 1

    # Finite-cutoff sewing can put only a non-IBZ star member inside the phase
    # layer. The legacy IBZ objective then selects a different principal chart
    # from the full-mesh gradient. The unified evaluator must retain a
    # measurable one-sided descent on its own full-mesh centered objective.
    off_star_data = copy(mmn.data)
    desired_overlap = Diagonal(ComplexF64[cis(-pi + 2.0e-8), 1.0])
    off_star_data[:, :, 1, 2] .= frames[2] * desired_overlap * frames[1]'
    off_star_mmn = MAGNETIC_WANNIER_IO.WannierMMN(
        mmn.num_bands,
        mmn.num_kpts,
        mmn.num_neighbors,
        off_star_data,
        copy(mmn.neighbors),
        copy(mmn.reciprocal_shifts),
    )
    off_star_weights =
        MAGNETIC_WANNIERIZATION._finite_difference_weights(representation, off_star_mmn).weights
    off_star_result = MAGNETIC_WANNIERIZATION._evaluate_mv_localization(
        cut_config,
        frames,
        zeros(2, 3),
        representation,
        off_star_mmn,
        off_star_weights,
        plan,
        tangent_plans,
    )
    @test off_star_result.success
    off_star = off_star_result.evaluation
    @test any(link -> link.kpoint == 2, off_star.active_links)
    _, legacy_spreads, _ = MAGNETIC_WANNIERIZATION._centers_spreads_and_directions(
        frames,
        zeros(2, 3),
        representation,
        off_star_mmn,
        off_star_weights,
        plan,
    )
    @test abs(sum(legacy_spreads) - off_star.objective) > 1.0e-10
    off_star_directional = MAGNETIC_WANNIERIZATION._mv_generalized_directional_derivative(
        off_star,
        off_star.full_gradients,
    )
    @test off_star_directional < 0.0
    off_star_changes = Float64[]
    for step in (1.0, 0.5, 0.25, 0.125, 0.0625, 0.03125, 0.015625, 0.0078125)
        trial_frames = [
            frames[kpoint] * exp(step .* off_star.full_gradients[kpoint]) for
            kpoint in eachindex(frames)
        ]
        trial_result = MAGNETIC_WANNIERIZATION._evaluate_mv_localization(
            cut_config,
            trial_frames,
            zeros(2, 3),
            representation,
            off_star_mmn,
            off_star_weights,
            plan,
            tangent_plans,
        )
        @test trial_result.success
        push!(off_star_changes, trial_result.evaluation.objective - off_star.objective)
    end
    @test minimum(off_star_changes) < -1.0e-12
    projected = MAGNETIC_WANNIERIZATION._symmetry_projected_spread_gradient(
        raw.gradients,
        representation,
        plan,
        tangent_plans,
    )
    @test projected.norm_squared > 1.0e-12
    @test projected.full_gradients[2] ≈
          target_at_k1 * conj(projected.full_gradients[1]) * target_at_k1' atol = 1.0e-12 rtol = 0.0
    objective =
        trial_frames -> sum(
            MAGNETIC_WANNIERIZATION._evaluate_full_mesh_centers_spreads_and_directions(
                trial_frames,
                centers,
                representation,
                mmn,
                weights,
            )[2],
        )
    trial =
        step -> [
            frames[kpoint] * exp(step .* projected.full_gradients[kpoint]) for
            kpoint in eachindex(frames)
        ]
    base_objective = objective(frames)
    @test objective(trial(0.0)) == base_objective
    minimum_margin = MAGNETIC_WANNIERIZATION._minimum_diagonal_phase_margin(frames, mmn)
    @test minimum_margin > 0.1
    analytic = MAGNETIC_WANNIERIZATION._localization_directional_derivative(
        raw.gradients,
        projected.full_gradients,
    )
    for step in (1.0e-6, 3.0e-7, 1.0e-7)
        finite_difference =
            (
                objective(trial(-2step)) - 8objective(trial(-step)) + 8objective(trial(step)) -
                objective(trial(2step))
            ) / (12step)
        tolerance = 1.0e-8 + 1.0e-5 * max(abs(analytic), abs(finite_difference))
        @test abs(analytic - finite_difference) <= tolerance
    end
end
