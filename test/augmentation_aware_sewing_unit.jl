if !isdefined(Main, :BandPublicSchemaTestSupport)
    include(joinpath(@__DIR__, "BandPublicSchemaTestSupport.jl"))
end

using HDF5
using LinearAlgebra
using Test

isdefined(Main, :QEPAWMatrixElementsTestSupport) ||
    include(joinpath(@__DIR__, "QEPAWMatrixElementsTestSupport.jl"))
using .QEPAWMatrixElementsTestSupport

const STRICT_SEWING_W = WannierNLQG.Wannierization
const STRICT_SEWING_F = WannierNLQG.SymmetryFoundation

# Minimal one-channel POTCAR fixture shared only by strict sewing unit tests.
function strict_sewing_potcar_block(element::AbstractString; q0::Float64 = 0.0)
    reciprocal = join(fill("0.1", 100), " ")
    return join(
        [
            "PAW_PBE $(element) 01Jan2000",
            "2.0 tail",
            "Non local Part",
            "0 0 0",
            "Reciprocal Space Part",
            reciprocal,
            "Real Space Part",
            "0.1 0.1 0.1",
            "PAW radial sets",
            "augmentation charges (non sperical)",
            string(q0),
            "uccopancies in atom",
            "grid",
            "0.1 0.2 0.4",
            "aepotential",
            "pseudo wavefunction",
            "0.10 0.20 0.30",
            "ae wavefunction",
            "0.12 0.22 0.32",
            "End of Dataset",
        ],
        '\n',
    ) * "\n"
end

# Build one identity operation without invoking magnetic-symmetry detection.
strict_sewing_identity() = WannierNLQG.SymmetryFoundation.SymmetryOperation(
    Matrix{Int}(I, 3, 3),
    zeros(3),
    Matrix{Float64}(I, 3, 3),
)

@testset "augmentation-aware sewing expert API and frozen thresholds" begin
    thresholds = STRICT_SEWING_W.PAWSewingThresholds()
    @test thresholds.generalized_norm == 5.0e-6
    @test thresholds.normalized_polar_correction == 5.0e-6
    @test thresholds.group_law == 2.0e-5
    @test_throws ArgumentError STRICT_SEWING_W.PAWSewingThresholds(raw_unitarity = 0.0)
    @test STRICT_SEWING_W.CoefficientMappingSewing() isa STRICT_SEWING_W.AbstractBandSewingBackend
    @test STRICT_SEWING_W.AugmentationAwareSewing().thresholds == thresholds

    cutoff_source = WannierNLQG.SymmetryFoundation.QuantumEspressoWavefunctionSource(
        "fixture.save";
        representation_cutoff_ev = 10.0,
    )
    config = STRICT_SEWING_W.BandRepresentationPreparationConfig(
        source = cutoff_source,
        sewing_backend = STRICT_SEWING_W.AugmentationAwareSewing(),
        win_file = "x.win",
        eig_file = "x.eig",
    )
    error_value = try
        STRICT_SEWING_W._validate_band_representation_preparation_config(config)
        nothing
    catch exception
        exception
    end
    @test error_value isa ArgumentError
    @test occursin("PAW_SEWING_FULL_CUTOFF_REQUIRED", sprint(showerror, error_value))

    input = STRICT_SEWING_W.WannierizationInputConfig(
        wannierization_mode = :ordinary,
        win_file = "x.win",
        eig_file = "x.eig",
        mmn_file = "x.mmn",
        projection_basis = WannierNLQG.WannierProjection.WannierProjectionBasis(
            [
                WannierNLQG.WannierProjection.ProjectionSpec(
                    selector = "X",
                    orbital_sets = "s",
                    positions = zeros(3, 1),
                ),
            ];
            num_wannier = 1,
        ),
    )
    legacy_restart = STRICT_SEWING_W.SymmetryAdaptedWannierizationConfig(
        input = input,
        solver = STRICT_SEWING_W.WannierizationSolverConfig(algorithm_profile = :custom),
    )
    strict_restart = STRICT_SEWING_W._replace_wannierization_config(
        legacy_restart;
        input = (sewing_backend = STRICT_SEWING_W.AugmentationAwareSewing(),),
    )
    @test STRICT_SEWING_W._restart_config_sha256(legacy_restart) !=
          STRICT_SEWING_W._restart_config_sha256(strict_restart)
    @test STRICT_SEWING_W._restart_config_sha256_pre_v2_11(strict_restart) === nothing
end

@testset "nonzero Q oracle, NC reduction, and energy-block gauge covariance" begin
    STRICT_SEWING_W._load_wannierization_extension!()
    extension = Base.get_extension(WannierNLQG, :WannierNLQGWannierizationExt).PAWMatrixElements
    coefficient = reshape(ComplexF64[sqrt(0.8)], 1, 1, 1)
    projector = reshape(ComplexF64[sqrt(0.4)], 1, 1, 1)
    pseudo = Base.invokelatest(extension._strict_pseudo_overlap, coefficient, coefficient)
    augmentation = Base.invokelatest(
        extension._strict_scalar_q0_overlap,
        projector,
        projector,
        reshape([0.5], 1, 1),
    )
    @test pseudo[1, 1] ≈ 0.8 atol = 2.0e-15 rtol = 0.0
    @test augmentation[1, 1] ≈ 0.2 atol = 2.0e-15 rtol = 0.0
    @test pseudo + augmentation ≈ ones(ComplexF64, 1, 1) atol = 3.0e-15 rtol = 0.0
    @test Base.invokelatest(
        extension._strict_scalar_q0_overlap,
        projector,
        projector,
        zeros(1, 1),
    ) == zeros(ComplexF64, 1, 1)

    cancelling_paw = Base.invokelatest(
        extension.VASPPawSystem,
        Dict{String, extension.VASPPawDataset}(),
        String[],
        extension.VASPPawAtomLayout[],
        1,
        reshape([-0.99999329], 1, 1),
        1.0,
    )
    cancelling_metric = Base.invokelatest(
        extension._VASPStrictSewingMetric,
        cancelling_paw,
        [ones(ComplexF64, 1, 1, 1)],
        [ones(ComplexF64, 1, 1)],
    )
    stability = Base.invokelatest(
        extension._strict_metric_overlap_element_stability,
        cancelling_metric,
        ones(ComplexF64, 1, 1, 1),
        ones(ComplexF64, 1, 1, 1),
        ones(ComplexF64, 1, 1, 1),
        ones(ComplexF64, 1, 1, 1),
        1,
        1;
        precision_bits = 256,
    )
    @test stability.reference_total ≈ 6.71e-6 atol = 1.0e-15 rtol = 0.0
    @test stability.cancellation_condition > 1.0e5
    @test stability.production_absolute_difference <= 5.0e-10
    @test stability.reverse_absolute_difference <= 5.0e-10
    @test stability.compensated_absolute_difference <= 5.0e-10

    base = reshape(Matrix{ComplexF64}(I, 2, 2), 2, 2, 1)
    target_gauge = ComplexF64[0 1; 1 0]
    source_gauge = ComplexF64[1 0; 0 cis(0.37)]
    target = similar(base)
    source = similar(base)
    target[:, :, 1] .= target_gauge * @view(base[:, :, 1])
    source[:, :, 1] .= source_gauge * @view(base[:, :, 1])
    covariant = Base.invokelatest(extension._strict_pseudo_overlap, target, source)
    @test covariant ≈ conj(target_gauge) * transpose(source_gauge) atol = 1.0e-14 rtol = 0.0
end

@testset "Gram-aware PAW reconstruction and target-basis covariance" begin
    extension = first(STRICT_SEWING_W._load_wannierization_extension!()).PAWMatrixElements
    paw = Base.invokelatest(
        extension.VASPPawSystem,
        Dict{String, extension.VASPPawDataset}(),
        String[],
        extension.VASPPawAtomLayout[],
        1,
        zeros(1, 1),
        1.0,
    )

    target = zeros(ComplexF64, 2, 2, 1)
    target[:, :, 1] .= ComplexF64[1.0 0.0; 0.2 sqrt(0.96)]
    target_projectors = zeros(ComplexF64, 2, 1, 1)
    metric = Base.invokelatest(
        extension._VASPStrictSewingMetric,
        paw,
        [target_projectors],
        [zeros(ComplexF64, 1, 2)],
    )
    closed_map = ComplexF64[1.0 0.3im; -0.2 0.8]
    closed = similar(target)
    closed[:, :, 1] .= transpose(closed_map) * @view(target[:, :, 1])
    closed_projectors = zeros(ComplexF64, 2, 1, 1)
    closed_raw, _, _ = Base.invokelatest(
        extension._strict_metric_overlap,
        metric,
        target,
        closed,
        target_projectors,
        closed_projectors,
    )
    qualified = Base.invokelatest(
        extension._strict_reconstruction_diagnostics,
        metric,
        target,
        closed,
        target_projectors,
        closed_projectors,
        closed_raw,
    )
    raw_direct = Base.invokelatest(
        extension._strict_raw_direct_reconstruction_diagnostics,
        metric,
        target,
        closed,
        target_projectors,
        closed_projectors,
        closed_raw,
    )
    @test qualified.reconstruction_leakage_weight <= 4.0e-28
    @test qualified.state_leakage_weight <= 4.0e-28
    @test raw_direct.reconstruction_leakage_amplitude_audit > 1.0e-2

    singular_target = zeros(ComplexF64, 2, 2, 1)
    singular_target[:, 1, 1] .= 1.0
    singular_raw, _, _ = Base.invokelatest(
        extension._strict_metric_overlap,
        metric,
        singular_target,
        singular_target,
        target_projectors,
        target_projectors,
    )
    rank_error = try
        Base.invokelatest(
            extension._strict_reconstruction_diagnostics,
            metric,
            singular_target,
            singular_target,
            target_projectors,
            target_projectors,
            singular_raw,
        )
        nothing
    catch exception
        exception
    end
    @test rank_error isa ArgumentError
    @test occursin("PAW_SEWING_TARGET_GRAM_RANK_FAILED", sprint(showerror, rank_error))

    leaky_target = zeros(ComplexF64, 1, 2, 1)
    leaky_target[1, 1, 1] = 1.0
    leakage_amplitude = 1.0e-4
    leaky_transformed = zeros(ComplexF64, 1, 2, 1)
    leaky_transformed[1, :, 1] .= [sqrt(1.0 - leakage_amplitude^2), leakage_amplitude]
    one_projector = zeros(ComplexF64, 1, 1, 1)
    leaky_raw, _, _ = Base.invokelatest(
        extension._strict_metric_overlap,
        metric,
        leaky_target,
        leaky_transformed,
        one_projector,
        one_projector,
    )
    leaky = Base.invokelatest(
        extension._strict_reconstruction_diagnostics,
        metric,
        leaky_target,
        leaky_transformed,
        one_projector,
        one_projector,
        leaky_raw,
    )
    @test leaky.reconstruction_leakage_weight ≈ leakage_amplitude^2 atol = 4.0e-16 rtol = 0.0
    @test leaky.state_leakage_weight ≈ leakage_amplitude^2 atol = 4.0e-16 rtol = 0.0
    @test isnothing(
        Base.invokelatest(
            extension._strict_sewing_gate,
            "target_reconstruction_leakage_weight",
            leaky.reconstruction_leakage_weight,
            5.0e-6,
        ),
    )
    @test_throws ArgumentError Base.invokelatest(
        extension._strict_sewing_gate,
        "target_reconstruction_leakage_weight",
        nextfloat(5.0e-6),
        5.0e-6,
    )

    covariant_target = zeros(ComplexF64, 2, 3, 1)
    covariant_target[:, :, 1] .= ComplexF64[1.0 0.2 0.0; 0.1 1.0 0.0]
    covariant_transformed = zeros(ComplexF64, 2, 3, 1)
    covariant_transformed[:, :, 1] .= transpose(closed_map) * @view(covariant_target[:, :, 1])
    covariant_transformed[:, 3, 1] .+= ComplexF64[2.0e-4, -1.0e-4im]
    covariant_projectors = zeros(ComplexF64, 2, 1, 1)
    covariant_raw, _, _ = Base.invokelatest(
        extension._strict_metric_overlap,
        metric,
        covariant_target,
        covariant_transformed,
        covariant_projectors,
        covariant_projectors,
    )
    covariant_residual = Base.invokelatest(
        extension._strict_reconstruction_diagnostics,
        metric,
        covariant_target,
        covariant_transformed,
        covariant_projectors,
        covariant_projectors,
        covariant_raw,
    )
    target_gauge = ComplexF64[1.0 0.2im; 0.1 1.0]
    gauged_target = similar(covariant_target)
    gauged_target[:, :, 1] .= target_gauge * @view(covariant_target[:, :, 1])
    gauged_raw, _, _ = Base.invokelatest(
        extension._strict_metric_overlap,
        metric,
        gauged_target,
        covariant_transformed,
        covariant_projectors,
        covariant_projectors,
    )
    gauged_residual = Base.invokelatest(
        extension._strict_reconstruction_diagnostics,
        metric,
        gauged_target,
        covariant_transformed,
        covariant_projectors,
        covariant_projectors,
        gauged_raw,
    )
    @test gauged_residual.reconstruction_leakage_weight ≈
          covariant_residual.reconstruction_leakage_weight atol = 2.0e-13 rtol = 0.0
    @test gauged_residual.state_leakage_weight ≈ covariant_residual.state_leakage_weight atol =
        2.0e-13 rtol = 0.0

    source_gauge = ComplexF64[0.0 cis(0.31); cis(-0.27) 0.0]
    both_gauged_transformed = similar(covariant_transformed)
    both_gauged_transformed[:, :, 1] .= source_gauge * @view(covariant_transformed[:, :, 1])
    both_gauged_raw, _, _ = Base.invokelatest(
        extension._strict_metric_overlap,
        metric,
        gauged_target,
        both_gauged_transformed,
        covariant_projectors,
        covariant_projectors,
    )
    both_gauged_residual = Base.invokelatest(
        extension._strict_reconstruction_diagnostics,
        metric,
        gauged_target,
        both_gauged_transformed,
        covariant_projectors,
        covariant_projectors,
        both_gauged_raw,
    )
    @test both_gauged_residual.reconstruction_leakage_weight ≈
          covariant_residual.reconstruction_leakage_weight atol = 2.0e-13 rtol = 0.0
    @test both_gauged_residual.state_leakage_weight ≈ covariant_residual.state_leakage_weight atol =
        2.0e-13 rtol = 0.0
end

@testset "rotation, fractional translation, and Theta squared" begin
    extension = first(STRICT_SEWING_W._load_wannierization_extension!()).PAWMatrixElements
    point = Base.invokelatest(
        WannierNLQG.SymmetryFoundation.PlaneWaveKPoint,
        [0.5, 0.0, 0.0],
        reshape([0, 0, 0], 1, 3),
        reshape(ComplexF64[1.0], 1, 1, 1),
        [0.0];
        normalize_coefficients = false,
    )
    translated_operation = WannierNLQG.SymmetryFoundation.SymmetryOperation(
        Matrix{Int}(I, 3, 3),
        [0.5, 0.0, 0.0],
        Matrix{Float64}(I, 3, 3),
    )
    translated = Base.invokelatest(
        extension._strict_transform_plane_wave_coefficients,
        point,
        point,
        translated_operation,
        zeros(Int, 3),
    )
    @test translated[1] ≈ cis(-0.5pi) atol = 1.0e-14 rtol = 0.0

    rotation = [0 -1 0; 1 0 0; 0 0 1]
    rotating_point = Base.invokelatest(
        WannierNLQG.SymmetryFoundation.PlaneWaveKPoint,
        zeros(3),
        [1 0 0; 0 1 0; -1 0 0; 0 -1 0],
        reshape(ComplexF64[1, 2, 3, 4], 1, 4, 1),
        [0.0];
        normalize_coefficients = false,
    )
    rotated = Base.invokelatest(
        extension._strict_transform_plane_wave_coefficients,
        rotating_point,
        rotating_point,
        WannierNLQG.SymmetryFoundation.SymmetryOperation(rotation, zeros(3), Float64.(rotation)),
        zeros(Int, 3),
    )
    @test sort(vec(abs.(rotated))) == [1.0, 2.0, 3.0, 4.0]

    theta_point = Base.invokelatest(
        WannierNLQG.SymmetryFoundation.PlaneWaveKPoint,
        zeros(3),
        reshape([0, 0, 0], 1, 3),
        reshape(ComplexF64[1.0, 2.0im], 1, 1, 2),
        [0.0];
        normalize_coefficients = false,
    )
    theta = WannierNLQG.SymmetryFoundation.SymmetryOperation(
        Matrix{Int}(I, 3, 3),
        zeros(3),
        Matrix{Float64}(I, 3, 3),
        true,
    )
    once = Base.invokelatest(
        extension._strict_transform_plane_wave_coefficients,
        theta_point,
        theta_point,
        theta,
        zeros(Int, 3),
    )
    once_point = Base.invokelatest(
        WannierNLQG.SymmetryFoundation.PlaneWaveKPoint,
        zeros(3),
        reshape([0, 0, 0], 1, 3),
        once,
        [0.0];
        normalize_coefficients = false,
    )
    twice = Base.invokelatest(
        extension._strict_transform_plane_wave_coefficients,
        once_point,
        theta_point,
        theta,
        zeros(Int, 3),
    )
    @test twice ≈ -theta_point.coefficients atol = 1.0e-14 rtol = 0.0
end

@testset "atom permutation through target-basis projector recomputation" begin
    extension = first(STRICT_SEWING_W._load_wannierization_extension!()).PAWMatrixElements
    mktempdir() do directory
        potcar = joinpath(directory, "POTCAR")
        write(potcar, strict_sewing_potcar_block("X"))
        lattice = 100.0 .* Matrix{Float64}(I, 3, 3)
        structure = WannierNLQG.SymmetryFoundation.CrystalStructure(
            lattice,
            ["X", "X"],
            [0.0 0.5; 0.0 0.0; 0.0 0.0],
        )
        point = Base.invokelatest(
            WannierNLQG.SymmetryFoundation.PlaneWaveKPoint,
            zeros(3),
            reshape([1, 0, 0], 1, 3),
            reshape(ComplexF64[1.0], 1, 1, 1),
            [0.0];
            normalize_coefficients = false,
        )
        native = Base.invokelatest(
            WannierNLQG.SymmetryFoundation.NativeWavefunctionData,
            :vasp,
            structure,
            (2.0pi / 100.0) .* Matrix{Float64}(I, 3, 3),
            (1, 1, 1),
            false,
            [point],
            Dict("fixture" => repeat("0", 64)),
            Dict("coefficient_normalization" => "vasp_raw"),
        )
        source = WannierNLQG.SymmetryFoundation.VASPWavefunctionSource(
            "POSCAR",
            "WAVECAR";
            potcar_file = potcar,
            include_time_reversal = false,
        )
        metric, _, _ = Base.invokelatest(extension._strict_sewing_metric, source, native)
        translation = WannierNLQG.SymmetryFoundation.SymmetryOperation(
            Matrix{Int}(I, 3, 3),
            [0.5, 0.0, 0.0],
            Matrix{Float64}(I, 3, 3),
        )
        transformed = Base.invokelatest(
            extension._strict_transform_plane_wave_coefficients,
            point,
            point,
            translation,
            zeros(Int, 3),
        )
        transformed_projectors =
            Base.invokelatest(extension._strict_transformed_projectors, metric, 1, transformed)
        original_projectors = metric.projectors[1]
        @test norm(original_projectors) > 0.0
        @test transformed_projectors[:, 1, :] ≈ original_projectors[:, 2, :] atol = 1.0e-12
        @test transformed_projectors[:, 2, :] ≈ original_projectors[:, 1, :] atol = 1.0e-12
    end
end

@testset "antiunitary fractional translation and atom permutation" begin
    extension = first(STRICT_SEWING_W._load_wannierization_extension!()).PAWMatrixElements
    mktempdir() do directory
        potcar = joinpath(directory, "POTCAR")
        write(potcar, strict_sewing_potcar_block("X"))
        lattice = 100.0 .* Matrix{Float64}(I, 3, 3)
        structure = WannierNLQG.SymmetryFoundation.CrystalStructure(
            lattice,
            ["X", "X"],
            [0.0 0.5; 0.0 0.0; 0.0 0.0],
        )
        point = Base.invokelatest(
            WannierNLQG.SymmetryFoundation.PlaneWaveKPoint,
            zeros(3),
            [1 0 0; -1 0 0],
            reshape(ComplexF64[1.0, -1.0], 1, 2, 1),
            [0.0];
            normalize_coefficients = false,
        )
        native = Base.invokelatest(
            WannierNLQG.SymmetryFoundation.NativeWavefunctionData,
            :vasp,
            structure,
            (2.0pi / 100.0) .* Matrix{Float64}(I, 3, 3),
            (1, 1, 1),
            false,
            [point],
            Dict("fixture" => repeat("0", 64)),
            Dict("coefficient_normalization" => "vasp_raw"),
        )
        source = WannierNLQG.SymmetryFoundation.VASPWavefunctionSource(
            "POSCAR",
            "WAVECAR";
            potcar_file = potcar,
            include_time_reversal = true,
        )
        metric, _, _ = Base.invokelatest(extension._strict_sewing_metric, source, native)
        antiunitary_translation = WannierNLQG.SymmetryFoundation.SymmetryOperation(
            Matrix{Int}(I, 3, 3),
            [0.5, 0.0, 0.0],
            Matrix{Float64}(I, 3, 3),
            true,
        )
        transformed = Base.invokelatest(
            extension._strict_transform_plane_wave_coefficients,
            point,
            point,
            antiunitary_translation,
            zeros(Int, 3),
        )
        @test transformed ≈ point.coefficients atol = 1.0e-14 rtol = 0.0
        transformed_projectors =
            Base.invokelatest(extension._strict_transformed_projectors, metric, 1, transformed)
        original_projectors = metric.projectors[1]
        @test transformed_projectors[:, 1, :] ≈ conj.(original_projectors[:, 2, :]) atol = 1.0e-12 rtol =
            0.0
        @test transformed_projectors[:, 2, :] ≈ conj.(original_projectors[:, 1, :]) atol = 1.0e-12 rtol =
            0.0
        raw, _, _ = Base.invokelatest(
            extension._strict_metric_overlap,
            metric,
            point.coefficients,
            transformed,
            original_projectors,
            transformed_projectors,
        )
        reconstruction = Base.invokelatest(
            extension._strict_reconstruction_diagnostics,
            metric,
            point.coefficients,
            transformed,
            original_projectors,
            transformed_projectors,
            raw,
        )
        @test reconstruction.reconstruction_leakage_weight <= 4.0e-24
    end
end

@testset "QE PAW/USPP/NC strict dispatch and public schema-1.0 native-gauge readback" begin
    extension = first(STRICT_SEWING_W._load_wannierization_extension!()).PAWMatrixElements
    preparation = first(STRICT_SEWING_W._load_wannierization_extension!()).RepresentationPreparation
    workflow = first(STRICT_SEWING_W._load_wannierization_extension!()).WorkflowOrchestration
    identity = strict_sewing_identity()
    for metric_kind in (:norm_conserving, :ultrasoft, :paw)
        mktempdir() do directory
            fixture = write_qe_paw_fixture(directory; metric_kind)
            source = WannierNLQG.SymmetryFoundation.QuantumEspressoWavefunctionSource(
                fixture.save_directory;
                include_time_reversal = false,
            )
            raw_native = Base.invokelatest(extension._read_augmentation_aware_native_source, source)
            energies = reshape(copy(only(raw_native.kpoints).energies_ev), 1, 1)
            strict = Base.invokelatest(
                preparation._build_band_representation,
                raw_native,
                energies,
                [identity],
                1.0e-8;
                source,
                sewing_backend = STRICT_SEWING_W.AugmentationAwareSewing(),
                return_diagnostics = true,
            )
            @test strict.representation.schema_version == "1.5"
            @test strict.representation.sewing_matrices ≈ ones(ComplexF64, 1, 1, 1, 1)
            @test strict.representation.conventions["qe_metric_kind"] == string(metric_kind)
            @test strict.representation.conventions["physical_overlap_available"] == "true"
            @test strict.representation.conventions["sewing_backend"] == "augmentation_aware_paw_q0"
            @test strict.representation.conventions["reconstruction_coefficient_map"] ==
                  "positive_definite_target_gram_solve"
            @test strict.representation.conventions["raw_direct_reconstruction_qualification"] ==
                  "AUDIT_ONLY_NO_HARD_GATE"
            @test haskey(
                strict.representation.conventions,
                "strict_audit_raw_direct_reconstruction_leakage_amplitude_maximum",
            )
            @test haskey(
                strict.representation.conventions,
                "strict_audit_target_raw_direct_reconstruction_leakage_amplitude_maximum",
            )
            @test parse(
                Float64,
                split(strict.representation.conventions["raw_cocycle_phase_UU_UA_AU_AA"], ',')[1],
            ) <= 1.0e-14
            @test strict.representation.conventions["raw_little_group_spectrum_record_count"] == "0"
            @test length(strict.representation.conventions["raw_little_group_spectrum_sha256"]) ==
                  64
            @test occursin(
                "operation = 1",
                strict.representation.conventions["strict_reconstruction_leakage_amplitude_audit_worst_context"],
            )
            @test occursin(
                "source_kpoint = 1",
                strict.representation.conventions["strict_state_leakage_amplitude_audit_worst_context"],
            )

            prepared = BandPublicSchemaTestSupport.prepare_public_band_fixture(
                strict.representation;
                directory,
                projection_basis = BandPublicSchemaTestSupport.single_site_s_basis(),
                sewing_backend = STRICT_SEWING_W.AugmentationAwareSewing(),
            )
            output = joinpath(directory, "strict-representation.h5")
            WannierNLQG.SymmetryFoundation.write_band_representation_hdf5(
                output,
                prepared.representation,
            )
            restored = WannierNLQG.SymmetryFoundation.read_band_representation_hdf5(output)
            @test restored.schema_version == "1.0"
            @test get(restored.conventions, "wavefunction_gauge_backend", "native_eigenstate") ==
                  "native_eigenstate"
            HDF5.h5open(output, "r") do handle
                @test String(read(HDF5.attributes(handle)["schema_version"])) == "1.0"
                @test haskey(handle, "sewing_backend")
                @test haskey(handle, "wavefunction_gauge")
            end
            tampered = joinpath(directory, "strict-representation-tampered.h5")
            cp(output, tampered)
            HDF5.h5open(tampered, "r+") do handle
                backend = handle["sewing_backend"]
                values = HDF5.attributes(backend)
                HDF5.delete_attribute(backend, "sewing_backend")
                values["sewing_backend"] = "coefficient_mapping"
            end
            @test_throws ArgumentError WannierNLQG.SymmetryFoundation.read_band_representation_hdf5(
                tampered,
            )
            if metric_kind == :paw
                probe = joinpath(@__DIR__, "AugmentationAwareSewingFreshReadProbe.jl")
                command =
                    `$(Base.julia_cmd()) --startup-file=no --project=$(dirname(@__DIR__)) $(probe) $(output)`
                fresh = read(command, String)
                @test occursin(r"AUGMENTATION_AWARE_FRESH_READ_DIGEST=[0-9a-f]{64}", fresh)
            end
            @test_throws ArgumentError Base.invokelatest(
                workflow._validate_sewing_backend_identity,
                STRICT_SEWING_W.CoefficientMappingSewing(),
                strict.representation,
            )
        end
    end
end

@testset "raw little-group spectrum and antiunitary cocycle fingerprint" begin
    extension = first(STRICT_SEWING_W._load_wannierization_extension!()).PAWMatrixElements
    identity = strict_sewing_identity()
    theta = WannierNLQG.SymmetryFoundation.SymmetryOperation(
        Matrix{Int}(I, 3, 3),
        zeros(3),
        Matrix{Float64}(I, 3, 3),
        true,
    )
    sewing = zeros(ComplexF64, 2, 2, 2, 1)
    sewing[:, :, 1, 1] .= Matrix{ComplexF64}(I, 2, 2)
    sewing[:, :, 2, 1] .= ComplexF64[0 1; -1 0]
    representation = WannierNLQG.SymmetryFoundation.BandRepresentation(
        "1.5",
        :qe,
        true,
        Matrix{Float64}(I, 3, 3),
        2.0pi .* Matrix{Float64}(I, 3, 3),
        (1, 1, 1),
        zeros(1, 3),
        zeros(2, 1),
        [identity, theta],
        ones(Int, 2, 1),
        zeros(Int, 3, 2, 1),
        sewing,
        ones(Int, 2, 1),
        [1],
        [1],
        [1];
        conventions = Dict("sewing_backend" => "augmentation_aware_paw_q0"),
    )
    product_table = STRICT_SEWING_W._build_representation_product_table(
        representation.operations,
        representation.spinor;
        tolerance = 1.0e-12,
    )
    records = Base.invokelatest(
        extension._strict_little_group_spectrum_records,
        representation,
        product_table,
    )
    @test length(records) == 1
    @test occursin("kind=antiunitary_square", only(records))
    @test occursin("-1.00000000000000000e+00", only(records))
    projective, cocycle, _ = Base.invokelatest(
        extension._strict_raw_projective_diagnostics,
        representation,
        product_table,
    )
    @test maximum(projective) <= 1.0e-14
    @test maximum(cocycle) <= 1.0e-14
end

@testset "VASP PAW strict dispatch" begin
    extension = first(STRICT_SEWING_W._load_wannierization_extension!()).PAWMatrixElements
    preparation = first(STRICT_SEWING_W._load_wannierization_extension!()).RepresentationPreparation
    mktempdir() do directory
        potcar = joinpath(directory, "POTCAR")
        write(potcar, strict_sewing_potcar_block("X"))
        structure = WannierNLQG.SymmetryFoundation.CrystalStructure(
            Matrix{Float64}(I, 3, 3),
            ["X"],
            zeros(3, 1),
        )
        point = Base.invokelatest(
            WannierNLQG.SymmetryFoundation.PlaneWaveKPoint,
            zeros(3),
            reshape([0, 0, 0], 1, 3),
            reshape(ComplexF64[1.0], 1, 1, 1),
            [0.0];
            normalize_coefficients = false,
        )
        native = Base.invokelatest(
            WannierNLQG.SymmetryFoundation.NativeWavefunctionData,
            :vasp,
            structure,
            2.0pi .* Matrix{Float64}(I, 3, 3),
            (1, 1, 1),
            false,
            [point],
            Dict("fixture" => repeat("0", 64)),
            Dict("coefficient_normalization" => "vasp_raw"),
        )
        source = WannierNLQG.SymmetryFoundation.VASPWavefunctionSource(
            "POSCAR",
            "WAVECAR";
            potcar_file = potcar,
            include_time_reversal = false,
        )
        built = Base.invokelatest(
            preparation._build_band_representation,
            native,
            reshape([0.0], 1, 1),
            [strict_sewing_identity()],
            1.0e-8;
            source,
            sewing_backend = STRICT_SEWING_W.AugmentationAwareSewing(),
        )
        @test built.conventions["augmentation_backend"] == "native_vasp_potcar_projector_q0"
        @test built.sewing_matrices ≈ ones(ComplexF64, 1, 1, 1, 1)
    end
end

@testset "legacy array identity and strict fail-stop" begin
    extension = first(STRICT_SEWING_W._load_wannierization_extension!()).PAWMatrixElements
    preparation = first(STRICT_SEWING_W._load_wannierization_extension!()).RepresentationPreparation
    mktempdir() do directory
        fixture = write_qe_paw_fixture(directory; metric_kind = :paw)
        source = WannierNLQG.SymmetryFoundation.QuantumEspressoWavefunctionSource(
            fixture.save_directory;
            include_time_reversal = false,
        )
        native = Base.invokelatest(
            preparation._read_qe_wavefunctions,
            source;
            purpose = :band_representation,
        )
        energies = reshape(copy(only(native.kpoints).energies_ev), 1, 1)
        canonical = STRICT_SEWING_F.build_canonical_band_representation(
            native,
            energies,
            [strict_sewing_identity()],
            1.0e-8,
        )
        wrapped = Base.invokelatest(
            preparation._build_band_representation,
            native,
            energies,
            [strict_sewing_identity()],
            1.0e-8;
            sewing_backend = STRICT_SEWING_W.CoefficientMappingSewing(),
        )
        @test isequal(wrapped.sewing_matrices, canonical.representation.sewing_matrices)
    end
    gate_error = try
        Base.invokelatest(
            extension._strict_sewing_gate,
            "target_state_leakage_weight",
            1.0e-3,
            5.0e-6;
            context = "operation=17,source_kpoint=66",
        )
        nothing
    catch exception
        exception
    end
    @test gate_error isa ArgumentError
    @test occursin("PAW_SEWING_HOLD", sprint(showerror, gate_error))
    @test occursin("operation=17,source_kpoint=66", sprint(showerror, gate_error))

    for residual in (0.0, 2.524757246869761e-15, 2.0e-5)
        @test isnothing(
            Base.invokelatest(
                extension._strict_reciprocal_shift_cocycle_gate,
                residual,
                2.0e-5;
                context = "synthetic target scope",
            ),
        )
    end
    cocycle_error = try
        Base.invokelatest(
            extension._strict_reciprocal_shift_cocycle_gate,
            2.1e-5,
            2.0e-5;
            root_cause = "PRE_SYMMETRIZATION_STRUCTURAL_HOLD",
            context = "synthetic target scope",
        )
        nothing
    catch exception
        exception
    end
    @test cocycle_error isa ArgumentError
    @test occursin("PRE_SYMMETRIZATION_STRUCTURAL_HOLD", sprint(showerror, cocycle_error))
    @test occursin("2.0e-5", sprint(showerror, cocycle_error))
    @test_throws ArgumentError Base.invokelatest(
        extension._strict_reciprocal_shift_cocycle_gate,
        NaN,
        2.0e-5,
    )

    source_point = Base.invokelatest(
        WannierNLQG.SymmetryFoundation.PlaneWaveKPoint,
        zeros(3),
        reshape([0, 0, 0], 1, 3),
        reshape(ComplexF64[1.0], 1, 1, 1),
        [0.0];
        normalize_coefficients = false,
    )
    missing_target = Base.invokelatest(
        WannierNLQG.SymmetryFoundation.PlaneWaveKPoint,
        zeros(3),
        reshape([1, 0, 0], 1, 3),
        reshape(ComplexF64[1.0], 1, 1, 1),
        [0.0];
        normalize_coefficients = false,
    )
    mapping_error = try
        Base.invokelatest(
            extension._strict_transform_plane_wave_coefficients,
            source_point,
            missing_target,
            strict_sewing_identity(),
            zeros(Int, 3),
        )
        nothing
    catch exception
        exception
    end
    @test mapping_error isa ArgumentError
    @test occursin("PAW_SEWING_PLANE_WAVE_MAPPING_INCOMPLETE", sprint(showerror, mapping_error))
end

@testset "ragged target-subspace authority and parent audit separation" begin
    extension = first(STRICT_SEWING_W._load_wannierization_extension!()).PAWMatrixElements
    energies = [-10.0 -10.0; 10.0 10.2]
    outer_masks = [BitVector([true, false]), BitVector([true, false])]
    frozen_masks = [BitVector([true, false]), BitVector([true, false])]
    mapping = reshape([2, 1], 1, 2)
    contract = Base.invokelatest(
        extension._strict_validate_target_subspace_contract,
        outer_masks,
        frozen_masks,
        energies,
        mapping,
        1.0e-2,
    )
    @test contract.target_energy_residual == 0.0
    @test contract.parent_energy_residual ≈ 0.2
    @test contract.parent_energy_status == :AUDIT_EXCEEDED

    raw = ComplexF64[1.0 2.0e-6; 3.0e-6 1.0]
    leakage = Base.invokelatest(
        extension._strict_bidirectional_target_complement_leakage,
        raw,
        outer_masks[1],
        outer_masks[1],
    )
    @test leakage.target_to_complement_leakage_weight ≈ 9.0e-12
    @test leakage.complement_to_target_leakage_weight ≈ 4.0e-12
    @test leakage.maximum_leakage_weight ≈ 9.0e-12
    ges_amplitude = 9.043588962582448e-4
    @test ges_amplitude^2 ≈ 8.178650132414307e-7
    @test ges_amplitude^2 * 1.0e6 ≈ 0.8178650132414307
    @test isnothing(
        Base.invokelatest(
            extension._strict_sewing_gate,
            "target_state_leakage_weight",
            ges_amplitude^2,
            5.0e-6,
        ),
    )
    boundary = sqrt(5.0e-6)
    directed_boundary = copy(raw)
    directed_boundary[2, 1] = boundary
    boundary_leakage = Base.invokelatest(
        extension._strict_bidirectional_target_complement_leakage,
        directed_boundary,
        outer_masks[1],
        outer_masks[1],
    )
    @test boundary_leakage.target_to_complement_leakage_weight ≈ 5.0e-6 rtol = 2eps()
    @test isnothing(
        Base.invokelatest(
            extension._strict_sewing_gate,
            "target_to_complement_leakage_weight",
            5.0e-6,
            5.0e-6,
        ),
    )
    full_rank = Base.invokelatest(
        extension._strict_required_square_block_diagnostics,
        raw,
        [1],
        [1],
        :outer,
    )
    @test full_rank.required_rank == full_rank.numerical_rank == 1
    @test_throws ArgumentError Base.invokelatest(
        extension._strict_required_square_block_diagnostics,
        zeros(ComplexF64, 2, 2),
        [1],
        [1],
        :outer,
    )
    @test_throws ArgumentError Base.invokelatest(
        extension._strict_sewing_gate,
        "maximum_bidirectional_leakage_weight",
        5.1e-6,
        5.0e-6,
    )

    rank_error = try
        Base.invokelatest(
            extension._strict_validate_target_subspace_contract,
            [BitVector([true, false]), BitVector([true, true])],
            [falses(2), falses(2)],
            energies,
            mapping,
            1.0e-2,
        )
        nothing
    catch exception
        exception
    end
    @test rank_error isa ArgumentError
    @test occursin("TARGET_SUBSPACE_NOT_CLOSED", sprint(showerror, rank_error))

    frozen_error = try
        Base.invokelatest(
            extension._strict_validate_target_subspace_contract,
            outer_masks,
            [BitVector([false, true]), BitVector([false, true])],
            energies,
            mapping,
            1.0e-2,
        )
        nothing
    catch exception
        exception
    end
    @test frozen_error isa ArgumentError
    @test occursin("FROZEN_NOT_CONTAINED", sprint(showerror, frozen_error))
end

@testset "VASP PAW star-gauge completion shape and formatted roundtrip" begin
    extension = first(STRICT_SEWING_W._load_wannierization_extension!()).PAWMatrixElements
    workflow = first(STRICT_SEWING_W._load_wannierization_extension!()).WorkflowOrchestration
    rotations = zeros(ComplexF64, 2, 2, 2)
    rotations[:, :, 1] .= Matrix{ComplexF64}(I, 2, 2)
    rotations[:, :, 2] .= ComplexF64[0 1; -1 0]
    validated = Base.invokelatest(workflow._validate_square_star_gauge_rotations, rotations, 2, 2)
    @test validated == rotations
    @test_throws ArgumentError Base.invokelatest(
        workflow._validate_square_star_gauge_rotations,
        zeros(ComplexF64, 2, 1, 2),
        2,
        2,
    )

    amn = WannierNLQG.IO.WannierAMN(2, 2, 1, reshape(ComplexF64[1, 2, 3, 4], 2, 1, 2))
    mmn_data = zeros(ComplexF64, 2, 2, 1, 2)
    mmn_data[:, :, 1, 1] .= ComplexF64[1 2im; -2im 3]
    mmn_data[:, :, 1, 2] .= ComplexF64[4 1; 1 5]
    mmn = WannierNLQG.IO.WannierMMN(2, 2, 1, mmn_data, reshape([2, 1], 1, 2), zeros(Int, 3, 1, 2))
    rotated_amn = Base.invokelatest(extension._star_rotate_parent_amn, amn, rotations)
    rotated_mmn = Base.invokelatest(extension._star_rotate_parent_mmn, mmn, rotations)
    @test rotated_amn.data[:, :, 2] ≈ rotations[:, :, 2]' * amn.data[:, :, 2]
    @test rotated_mmn.data[:, :, 1, 1] ≈
          rotations[:, :, 1]' * mmn.data[:, :, 1, 1] * rotations[:, :, 2]
    mktempdir() do directory
        amn_file =
            WannierNLQG.IO.write_wannier_amn(joinpath(directory, "completed.amn"), rotated_amn)
        mmn_file =
            WannierNLQG.IO.write_wannier_mmn(joinpath(directory, "completed.mmn"), rotated_mmn)
        @test WannierNLQG.IO.read_wannier_amn(amn_file).data ≈ rotated_amn.data atol = 5.0e-15
        @test WannierNLQG.IO.read_wannier_mmn(mmn_file).data ≈ rotated_mmn.data atol = 5.0e-15
    end
end
