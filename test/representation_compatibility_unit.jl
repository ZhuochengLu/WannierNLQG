using HDF5
using LinearAlgebra
using Test

isdefined(@__MODULE__, :BandPublicSchemaTestSupport) || include("BandPublicSchemaTestSupport.jl")

const REPRESENTATION_WANNIERIZATION = WannierNLQG.Wannierization
const REPRESENTATION_SYMMETRIZATION = WannierNLQG.Symmetrization

function time_reversal_representation_fixture(; trim::Bool = false, corrupt_second::Bool = false)
    identity_operation = WannierNLQG.SymmetryFoundation.SymmetryOperation(
        Matrix{Int}(I, 3, 3),
        zeros(3),
        Matrix{Float64}(I, 3, 3),
    )
    theta_operation = WannierNLQG.SymmetryFoundation.SymmetryOperation(
        Matrix{Int}(I, 3, 3),
        zeros(3),
        Matrix{Float64}(I, 3, 3),
        true,
    )
    kpoints = trim ? zeros(1, 3) : [0.25 0.0 0.0; 0.75 0.0 0.0]
    num_kpoints = size(kpoints, 1)
    kpoint_map = trim ? ones(Int, 2, 1) : [1 2; 2 1]
    shifts = zeros(Int, 3, 2, num_kpoints)
    trim || (shifts[1, 2, :] .= -1)
    theta = ComplexF64[0 1; -1 0]
    sewing = zeros(ComplexF64, 2, 2, 2, num_kpoints)
    for kpoint in 1:num_kpoints
        sewing[:, :, 1, kpoint] .= Matrix{ComplexF64}(I, 2, 2)
        sewing[:, :, 2, kpoint] .= theta
    end
    corrupt_second && num_kpoints == 2 && (sewing[:, :, 2, 2] .*= -1)
    representation = WannierNLQG.SymmetryFoundation.BandRepresentation(
        "1.1",
        :synthetic,
        true,
        Matrix{Float64}(I, 3, 3),
        2.0pi .* Matrix{Float64}(I, 3, 3),
        trim ? (1, 1, 1) : (2, 1, 1),
        kpoints,
        zeros(2, num_kpoints),
        [identity_operation, theta_operation],
        kpoint_map,
        shifts,
        sewing,
        ones(Int, 2, num_kpoints),
        [1],
        ones(Int, num_kpoints),
        trim ? [1] : [1, 2];
        conventions = Dict(
            "sewing" => "rows target bands, columns source bands",
            "antiunitary_gauge_transform" => "B'=U_target'*B*conj(U_source)",
        ),
        input_sha256 = Dict("fixture" => repeat("1", 64)),
    )
    shuffled_operations = [theta_operation, identity_operation]
    target_matrices = zeros(ComplexF64, 2, 2, 2)
    target_matrices[:, :, 1] .= theta
    target_matrices[:, :, 2] .= Matrix{ComplexF64}(I, 2, 2)
    plan = WannierNLQG.SymmetryFoundation.WannierSymmetryPlan(
        shuffled_operations,
        target_matrices,
        zeros(Int, 3, 2, 2),
    )
    return (; representation, plan, identity_operation, theta_operation)
end

@testset "public VASP SAXIS configuration contract" begin
    mktempdir() do directory
        incar = joinpath(directory, "INCAR")
        open(incar, "w") do io
            write(io, "LNONCOLLINEAR = .TRUE.\nSAXIS = 1 0 0 ! non-z test\n")
        end
        source = WannierNLQG.SymmetryFoundation.VASPWavefunctionSource(
            "POSCAR",
            "WAVECAR";
            incar_file = incar,
            spinor = true,
        )
        @test source.incar_file == incar
        @test source.spinor
        config = WannierNLQG.SymmetryFoundation.VASPBandRepresentationConfig(
            poscar_file = "POSCAR",
            wavecar_file = "WAVECAR",
            incar_file = incar,
            spin_basis_saxis = (1.0, 0.0, 0.0),
            eig_file = "wannier90.eig",
            output_hdf5_file = "representation.h5",
        )
        @test config.incar_file == incar
        @test config.spin_basis_saxis == (1.0, 0.0, 0.0)
        missing = WannierNLQG.SymmetryFoundation.VASPWavefunctionSource(
            "POSCAR",
            "WAVECAR";
            incar_file = joinpath(directory, "missing.INCAR"),
            spinor = true,
        )
        @test missing.incar_file == joinpath(directory, "missing.INCAR")
    end
end

@testset "QE generalized-overlap augmentation contract" begin
    WannierNLQG.Wannierization._load_wannierization_extension!()
    extension = Base.get_extension(WannierNLQG, :WannierNLQGWannierizationExt)
    extension === nothing && error("Wannierization extension did not load")
    preparation = extension.RepresentationPreparation
    coefficients = ComplexF64[sqrt(0.75) 0; 0 sqrt(0.75)]
    beta = ComplexF64[1 0; 0 1]
    augmentation = ComplexF64[0.25 0; 0 0.25]
    overlap = Base.invokelatest(
        preparation._qe_generalized_overlap,
        coefficients,
        coefficients,
        beta,
        beta,
        augmentation,
    )
    @test maximum(abs, overlap - Matrix{ComplexF64}(I, 2, 2)) ≤ 1.0e-14
    overlap_without_augmentation = coefficients * coefficients'
    @test maximum(abs, overlap_without_augmentation - Matrix{ComplexF64}(I, 2, 2)) > 1.0e-2

    mktempdir() do directory
        paw = joinpath(directory, "PAW.UPF")
        nc = joinpath(directory, "NC.UPF")
        open(paw, "w") do io
            write(io, "<UPF><PP_HEADER element=\"Ni\" is_paw=\"true\"/></UPF>")
        end
        open(nc, "w") do io
            write(io, "<UPF><PP_HEADER element=\"Fe\" is_paw=\"false\"/></UPF>")
        end
        @test Base.invokelatest(preparation._qe_upf_metric_kind, paw) == :paw
        @test Base.invokelatest(preparation._qe_upf_metric_kind, nc) == :norm_conserving
    end
end

function with_representation_source(representation, source_code::Symbol)
    return WannierNLQG.SymmetryFoundation.BandRepresentation(
        representation.schema_version,
        source_code,
        representation.spinor,
        representation.real_lattice,
        representation.reciprocal_lattice,
        representation.mp_grid,
        representation.kpoints_fractional,
        representation.energies_ev,
        representation.operations,
        representation.kpoint_map,
        representation.reciprocal_shifts,
        representation.sewing_matrices,
        representation.band_block_labels,
        representation.irreducible_indices,
        representation.full_to_irreducible,
        representation.full_to_operation;
        conventions = representation.conventions,
        input_sha256 = representation.input_sha256,
    )
end

function nonsymmorphic_representation_fixture()
    identity_operation = WannierNLQG.SymmetryFoundation.SymmetryOperation(
        Matrix{Int}(I, 3, 3),
        zeros(3),
        Matrix{Float64}(I, 3, 3),
    )
    half_translation = WannierNLQG.SymmetryFoundation.SymmetryOperation(
        Matrix{Int}(I, 3, 3),
        [0.5, 0.0, 0.0],
        Matrix{Float64}(I, 3, 3),
    )
    kpoint = 0.25
    sewing = ones(ComplexF64, 1, 1, 2, 1)
    sewing[1, 1, 2, 1] = cis(-pi * kpoint)
    return WannierNLQG.SymmetryFoundation.BandRepresentation(
        "1.1",
        :synthetic,
        false,
        Matrix{Float64}(I, 3, 3),
        2.0pi .* Matrix{Float64}(I, 3, 3),
        (1, 1, 1),
        reshape([kpoint, 0.0, 0.0], 1, 3),
        zeros(1, 1),
        [identity_operation, half_translation],
        ones(Int, 2, 1),
        zeros(Int, 3, 2, 1),
        sewing,
        ones(Int, 1, 1),
        [1],
        [1],
        [1];
        conventions = Dict("sewing" => "rows target bands, columns source bands"),
        input_sha256 = Dict("fixture" => repeat("2", 64)),
    )
end

function write_legacy_v10_representation(filename::AbstractString, representation)
    HDF5.h5open(filename, "w") do handle
        root_attributes = HDF5.attributes(handle)
        root_attributes["schema"] = "WannierNLQG.band_representation"
        root_attributes["schema_version"] = "1.0"
        root_attributes["source_code"] = String(representation.source_code)
        root_attributes["spinor"] = representation.spinor
        geometry = HDF5.create_group(handle, "geometry")
        geometry["real_lattice"] = representation.real_lattice
        geometry["reciprocal_lattice"] = representation.reciprocal_lattice
        geometry["mp_grid"] = collect(representation.mp_grid)
        geometry["kpoints_fractional"] = representation.kpoints_fractional
        bands = HDF5.create_group(handle, "bands")
        bands["energies_ev"] = representation.energies_ev
        bands["block_labels"] = representation.band_block_labels
        operations = HDF5.create_group(handle, "operations")
        operation_count = length(representation.operations)
        fractional = zeros(Int, 3, 3, operation_count)
        translations = zeros(Float64, 3, operation_count)
        cartesian = zeros(Float64, 3, 3, operation_count)
        antiunitary = zeros(UInt8, operation_count)
        for operation_index in 1:operation_count
            operation = representation.operations[operation_index]
            fractional[:, :, operation_index] .= operation.rotation_fractional
            translations[:, operation_index] .= operation.translation_fractional
            cartesian[:, :, operation_index] .= operation.rotation_cartesian
            antiunitary[operation_index] = operation.antiunitary
        end
        operations["rotation_fractional"] = fractional
        operations["translation_fractional"] = translations
        operations["rotation_cartesian"] = cartesian
        operations["antiunitary"] = antiunitary
        action = HDF5.create_group(handle, "action")
        action["kpoint_map"] = representation.kpoint_map
        action["reciprocal_shifts"] = representation.reciprocal_shifts
        action["sewing_matrices"] = representation.sewing_matrices
        stars = HDF5.create_group(handle, "stars")
        stars["irreducible_indices"] = representation.irreducible_indices
        stars["full_to_irreducible"] = representation.full_to_irreducible
        stars["full_to_operation"] = representation.full_to_operation
        conventions = HDF5.create_group(handle, "conventions")
        for (key, value) in representation.conventions
            HDF5.attributes(conventions)[key] = value
        end
        hashes = HDF5.create_group(handle, "input_sha256")
        for (key, value) in representation.input_sha256
            HDF5.attributes(hashes)[key] = value
        end
    end
    return filename
end

@testset "Representation group law, time reversal, and Kramers closure" begin
    fixture = time_reversal_representation_fixture()
    report = REPRESENTATION_WANNIERIZATION.validate_band_representation_compatibility(
        fixture.representation,
        fixture.plan;
        outer_mask = [trues(2), trues(2)],
        frozen_mask = [trues(2), trues(2)],
        tolerance = 1.0e-12,
    )
    @test report.schema_version == "1.3"
    @test report.maximum_group_law_residuals ==
          max.(report.band_group_law_residuals, report.target_group_law_residuals)
    @test length(report.band_group_law_worst_cases) == 4
    @test length(report.target_group_law_worst_cases) == 4
    @test report.supported_contract
    @test report.passed
    @test report.gate_definition_status == REPRESENTATION_WANNIERIZATION.GATE_VALID
    @test report.assessment_status == REPRESENTATION_WANNIERIZATION.REPRESENTATION_COMPATIBLE
    @test report.product_table.theta_index == 2
    @test report.product_table.spinor_factors[2, 2] == -1
    @test maximum(report.maximum_group_law_residuals) <= 1.0e-12
    @test report.theta_squared_residual <= 1.0e-12
    @test isempty(report.diagnostics)

    trim_fixture = time_reversal_representation_fixture(; trim = true)
    trim_report = REPRESENTATION_WANNIERIZATION.validate_band_representation_compatibility(
        trim_fixture.representation,
        trim_fixture.plan;
        outer_mask = [trues(2)],
        frozen_mask = [trues(2)],
        tolerance = 1.0e-12,
    )
    @test trim_report.passed
    @test trim_report.maximum_kramers_residual <= 1.0e-12
    odd_selected_report = REPRESENTATION_WANNIERIZATION.validate_band_representation_compatibility(
        trim_fixture.representation,
        trim_fixture.plan;
        outer_mask = [trues(2)],
        frozen_mask = [trues(2)],
        selected_projectors = [reshape(ComplexF64[1, 0], 2, 1)],
        tolerance = 1.0e-12,
    )
    @test !odd_selected_report.passed
    @test any(
        diagnostic -> diagnostic.code == :KRAMERS_BLOCK_NOT_CLOSED,
        odd_selected_report.diagnostics,
    )

    corrupted = time_reversal_representation_fixture(; corrupt_second = true)
    corrupted_report = REPRESENTATION_WANNIERIZATION.validate_band_representation_compatibility(
        corrupted.representation,
        corrupted.plan;
        outer_mask = [trues(2), trues(2)],
        frozen_mask = [trues(2), trues(2)],
        tolerance = 1.0e-12,
    )
    @test !corrupted_report.passed
    @test any(
        diagnostic -> diagnostic.code in
        (:ANTIUNITARY_GROUP_LAW_FAILED, :THETA_SQUARED_FAILED, :KRAMERS_BLOCK_NOT_CLOSED),
        corrupted_report.diagnostics,
    )

    nonsymmorphic = nonsymmorphic_representation_fixture()
    nonsymmorphic_report = REPRESENTATION_WANNIERIZATION.validate_band_representation_compatibility(
        nonsymmorphic;
        outer_mask = [trues(1)],
        tolerance = 1.0e-12,
    )
    @test nonsymmorphic_report.passed
    @test nonsymmorphic_report.product_table.translation_differences[:, 2, 2] == [1, 0, 0]
    @test maximum(nonsymmorphic_report.maximum_group_law_residuals) <= 1.0e-12

    bad_action = deepcopy(fixture.representation)
    bad_action.reciprocal_shifts[1, 2, 1] = 0
    bad_action_report = REPRESENTATION_WANNIERIZATION.validate_band_representation_compatibility(
        bad_action;
        outer_mask = [trues(2), trues(2)],
        tolerance = 1.0e-12,
    )
    @test !bad_action_report.passed
    @test any(
        diagnostic -> diagnostic.code == :RECIPROCAL_ACTION_INCONSISTENT,
        bad_action_report.diagnostics,
    )

    missing_identity = WannierNLQG.SymmetryFoundation.BandRepresentation(
        "1.1",
        :synthetic,
        true,
        fixture.representation.real_lattice,
        fixture.representation.reciprocal_lattice,
        fixture.representation.mp_grid,
        fixture.representation.kpoints_fractional,
        fixture.representation.energies_ev,
        [fixture.theta_operation],
        reshape([2, 1], 1, 2),
        reshape([-1, 0, 0, -1, 0, 0], 3, 1, 2),
        reshape(fixture.representation.sewing_matrices[:, :, 2, :], 2, 2, 1, 2),
        fixture.representation.band_block_labels,
        [1],
        [1, 1],
        [1, 1],
    )
    missing_identity_report =
        REPRESENTATION_WANNIERIZATION.validate_band_representation_compatibility(
            missing_identity;
            outer_mask = [trues(2), trues(2)],
            tolerance = 1.0e-12,
        )
    @test !missing_identity_report.passed
    @test any(
        diagnostic -> diagnostic.code == :OPERATION_GROUP_NOT_CLOSED,
        missing_identity_report.diagnostics,
    )

    empirical = with_representation_source(fixture.representation, :vasp)
    internally_qualified = REPRESENTATION_WANNIERIZATION.validate_band_representation_compatibility(
        empirical,
        fixture.plan;
        outer_mask = [trues(2), trues(2)],
        tolerance = 1.0e-12,
    )
    @test internally_qualified.passed
    @test internally_qualified.gate_definition_status == REPRESENTATION_WANNIERIZATION.GATE_VALID
    @test internally_qualified.assessment_status ==
          REPRESENTATION_WANNIERIZATION.REPRESENTATION_COMPATIBLE
    @test any(
        diagnostic ->
            diagnostic.code == :ORACLE_REFERENCE_UNAVAILABLE && diagnostic.severity == :info,
        internally_qualified.diagnostics,
    )
    corrupted_empirical = with_representation_source(
        time_reversal_representation_fixture(; corrupt_second = true).representation,
        :vasp,
    )
    vacuous_budget = REPRESENTATION_WANNIERIZATION.validate_band_representation_compatibility(
        corrupted_empirical,
        fixture.plan;
        outer_mask = [trues(2), trues(2)],
        tolerance = 1.0e-12,
    )
    @test !vacuous_budget.passed
    @test any(
        diagnostic -> diagnostic.code == :EMPIRICAL_COVARIANCE_BUDGET_VACUOUS,
        vacuous_budget.diagnostics,
    )
    qualified = REPRESENTATION_WANNIERIZATION.validate_band_representation_compatibility(
        empirical,
        fixture.plan;
        outer_mask = [trues(2), trues(2)],
        tolerance = 1.0e-12,
        oracle_excess_group_law_residuals = zeros(4),
        qualification_sha256 = repeat("a", 64),
    )
    @test qualified.passed
    @test qualified.assessment_status == REPRESENTATION_WANNIERIZATION.REPRESENTATION_COMPATIBLE
    reference_difference = REPRESENTATION_WANNIERIZATION.validate_band_representation_compatibility(
        empirical,
        fixture.plan;
        outer_mask = [trues(2), trues(2)],
        tolerance = 1.0e-12,
        oracle_excess_group_law_residuals = fill(1.0e-6, 4),
        qualification_sha256 = repeat("b", 64),
    )
    @test reference_difference.passed
    @test any(
        diagnostic ->
            diagnostic.code == :ORACLE_REFERENCE_DIFFERENCE && diagnostic.severity == :warning,
        reference_difference.diagnostics,
    )
end

@testset "Sewing operation matching and exact block alignment" begin
    fixture = time_reversal_representation_fixture()
    matching = REPRESENTATION_WANNIERIZATION._match_symmetry_operations(
        fixture.representation.operations,
        reverse(fixture.representation.operations);
        spinor = true,
        tolerance = 1.0e-12,
    )
    @test matching.candidate_to_reference == [2, 1]
    @test matching.spin_lift_factors == [1, 1]
    @test isempty(matching.diagnostics)

    blocks = REPRESENTATION_WANNIERIZATION._common_degeneracy_blocks([1, 1, 2, 3], [1, 2, 2, 3])
    @test blocks == [1:3, 4:4]
    phase_alignment = REPRESENTATION_WANNIERIZATION._block_alignment_unitary(
        reshape([cis(0.3)], 1, 1);
        tolerance = 1.0e-12,
    )
    @test phase_alignment.passed
    @test phase_alignment.phase_only
    rotation = ComplexF64[0 1; -1 0]
    unitary_alignment =
        REPRESENTATION_WANNIERIZATION._block_alignment_unitary(rotation; tolerance = 1.0e-12)
    @test unitary_alignment.passed
    @test unitary_alignment.unitary ≈ rotation atol = 1.0e-12 rtol = 0.0
    rank_deficient = REPRESENTATION_WANNIERIZATION._block_alignment_unitary(
        ComplexF64[1 0; 0 0];
        tolerance = 1.0e-12,
    )
    @test !rank_deficient.passed

    reference_coefficients = ComplexF64[1 0 0; 0 1 0]
    nonorthogonal_same_subspace = ComplexF64[1 1.0e-4 0; 0 1 0]
    stable_self = REPRESENTATION_WANNIERIZATION._stable_subspace_alignment(
        nonorthogonal_same_subspace,
        nonorthogonal_same_subspace;
        tolerance = 64eps(Float64),
    )
    @test stable_self.passed
    @test stable_self.principal_angle_distance <= 64eps(Float64)
    @test stable_self.projector_matrix_max_abs <= 64eps(Float64)
    stable_equal = REPRESENTATION_WANNIERIZATION._stable_subspace_alignment(
        nonorthogonal_same_subspace,
        reference_coefficients;
        tolerance = 64eps(Float64),
    )
    @test stable_equal.passed
    angle = 2.0e-4
    rotated_subspace = ComplexF64[1 0 0; 0 cos(angle) sin(angle)]
    known_angle = REPRESENTATION_WANNIERIZATION._stable_subspace_alignment(
        rotated_subspace,
        reference_coefficients;
        tolerance = 1.0e-3,
    )
    @test known_angle.principal_angle_distance ≈ sin(angle) atol = 1.0e-14 rtol = 1.0e-10
    @test_throws ArgumentError REPRESENTATION_WANNIERIZATION._stable_subspace_alignment(
        ComplexF64[1 0 0; 1 0 0],
        reference_coefficients,
    )

    common_residual = 8.0e-6 .* Matrix{ComplexF64}(I, 2, 2)
    paired_residual = REPRESENTATION_WANNIERIZATION._paired_matrix_residual_metrics(
        common_residual,
        copy(common_residual),
    )
    @test paired_residual.candidate_absolute == 8.0e-6
    @test paired_residual.reference_absolute == 8.0e-6
    @test paired_residual.paired_excess == 0.0

    raw_f32 = reshape(ComplexF32[3 + 4im, 0, 1 - 2im, 2 + 0im], 2, 2, 1)
    normalized = WannierNLQG.SymmetryFoundation.normalize_plane_wave_coefficients(raw_f32)
    @test eltype(normalized) == ComplexF64
    @test all(
        band -> isapprox(norm(@view(normalized[band, :, :])), 1.0; atol = eps(Float64), rtol = 0.0),
        axes(normalized, 1),
    )

    sewing = ComplexF64[1 2im; 3 4]
    target_gauge = ComplexF64[0 1; -1 0]
    source_gauge = Diagonal(cis.([0.2, -0.4])) |> Matrix
    transformed = REPRESENTATION_WANNIERIZATION._gauge_transform_sewing(
        sewing,
        target_gauge,
        source_gauge;
        antiunitary = true,
    )
    @test transformed ≈ target_gauge' * sewing * conj(source_gauge)
    @test !(transformed ≈ target_gauge' * sewing * source_gauge)
end

@testset "Band-representation public HDF5 schema 1.0 contracts" begin
    mktempdir() do directory
        raw_fixture = time_reversal_representation_fixture()
        prepared = BandPublicSchemaTestSupport.prepare_public_band_fixture(
            raw_fixture.representation;
            directory = joinpath(directory, "prepare"),
            projection_basis = BandPublicSchemaTestSupport.single_site_s_basis(spinor = true),
        )
        fixture = merge(raw_fixture, (; representation = prepared.representation))
        report = REPRESENTATION_WANNIERIZATION.validate_band_representation_compatibility(
            fixture.representation,
            fixture.plan;
            outer_mask = [trues(2), trues(2)],
            frozen_mask = [trues(2), trues(2)],
            tolerance = 1.0e-12,
        )
        filename = joinpath(directory, "representation.h5")
        output = WannierNLQG.SymmetryFoundation.write_band_representation_hdf5(
            filename,
            fixture.representation,
            report,
        )
        @test output == abspath(filename)
        HDF5.h5open(filename, "r") do handle
            @test read(HDF5.attributes(handle)["schema_version"]) == "1.0"
            @test length(String(read(HDF5.attributes(handle)["preparation_digest"]))) == 64
            @test all(
                name -> haskey(handle, name),
                ("inventory", "qualification_scope", "raw_diagnostics", "compatibility_policy"),
            )
            @test haskey(handle, "wavefunction_gauge")
            @test read(
                HDF5.attributes(handle["wavefunction_gauge"])["wavefunction_gauge_backend"],
            ) == "native_eigenstate"
            @test haskey(handle, "compatibility/band_group_law_residual")
            @test haskey(handle, "compatibility/target_group_law_residual")
            @test haskey(handle, "compatibility/worst_cases/band/UU")
            @test haskey(handle, "compatibility/worst_cases/target/AA")
            @test read(HDF5.attributes(handle["action/kpoint_map"])["axis_order"]) ==
                  "kpoint,operation"
            @test read(HDF5.attributes(handle["action/sewing_matrices"])["axis_order"]) ==
                  "kpoint,operation,target_band,source_band"
            @test read(HDF5.attributes(handle["compatibility"])["status"]) == "COMPATIBLE"
            @test read(HDF5.attributes(handle["compatibility"])["gate_definition_status"]) ==
                  "GATE_VALID"
        end
        restored = WannierNLQG.SymmetryFoundation.read_band_representation_hdf5(filename)
        @test restored.schema_version == "1.0"
        @test restored.kpoints_fractional == fixture.representation.kpoints_fractional
        @test restored.sewing_matrices == fixture.representation.sewing_matrices
        @test REPRESENTATION_WANNIERIZATION._representation_static_sha256(restored) ==
              report.representation_sha256

        second = joinpath(directory, "representation-second.h5")
        WannierNLQG.SymmetryFoundation.write_band_representation_hdf5(second, restored, report)
        second_restored = WannierNLQG.SymmetryFoundation.read_band_representation_hdf5(second)
        @test second_restored.sewing_matrices == restored.sewing_matrices
        @test REPRESENTATION_WANNIERIZATION._representation_static_sha256(second_restored) ==
              REPRESENTATION_WANNIERIZATION._representation_static_sha256(restored)

        legacy = joinpath(directory, "legacy-v1.0.h5")
        write_legacy_v10_representation(legacy, fixture.representation)
        @test_throws ArgumentError WannierNLQG.SymmetryFoundation.read_band_representation_hdf5(
            legacy,
        )

        legacy_v11 = joinpath(directory, "legacy-v1.1.h5")
        cp(filename, legacy_v11)
        HDF5.h5open(legacy_v11, "r+") do handle
            write(HDF5.attributes(handle)["schema_version"], "1.1")
        end
        @test_throws ArgumentError WannierNLQG.SymmetryFoundation.read_band_representation_hdf5(
            legacy_v11,
        )
        extension = first(WannierNLQG.SymmetryFoundation._load_symmetry_foundation_extension!())
        @test_throws ArgumentError Base.invokelatest(
            extension._read_band_representation_qualification_hdf5,
            legacy_v11,
        )

        incompatible_report = REPRESENTATION_WANNIERIZATION.RepresentationCompatibilityReport(
            report.schema_version,
            report.supported_contract,
            false,
            report.tolerance,
            report.product_table,
            report.maximum_group_law_residuals,
            report.maximum_reciprocal_shift_residual,
            report.theta_squared_residual,
            report.maximum_kramers_residual,
            report.representation_sha256,
            [
                REPRESENTATION_WANNIERIZATION.WannierizationDiagnostic(
                    :THETA_SQUARED_FAILED,
                    :error,
                    "synthetic failure",
                ),
            ],
            :computed,
        )
        incompatible = WannierNLQG.SymmetryFoundation.write_band_representation_hdf5(
            joinpath(directory, "failed.h5"),
            fixture.representation,
            incompatible_report,
        )
        @test endswith(incompatible, ".incompatible.h5")
        @test isfile(incompatible)

        empirical = with_representation_source(fixture.representation, :vasp)
        qualified = REPRESENTATION_WANNIERIZATION.validate_band_representation_compatibility(
            empirical,
            fixture.plan;
            outer_mask = [trues(2), trues(2)],
            tolerance = 1.0e-12,
            oracle_excess_group_law_residuals = zeros(4),
            qualification_sha256 = repeat("b", 64),
        )
        qualified_file = WannierNLQG.SymmetryFoundation.write_band_representation_hdf5(
            joinpath(directory, "qualified.h5"),
            empirical,
            qualified,
        )
        qualification = Base.invokelatest(
            extension._read_band_representation_qualification_hdf5,
            qualified_file,
        )
        @test qualification.qualification_sha256 == repeat("b", 64)
        @test qualification.oracle_excess_group_law_residuals == (0.0, 0.0, 0.0, 0.0)

        tampered = joinpath(directory, "tampered.h5")
        cp(filename, tampered)
        HDF5.h5open(tampered, "r+") do handle
            handle["products/product_index"][1, 1] = 2
        end
        @test_throws ArgumentError WannierNLQG.SymmetryFoundation.read_band_representation_hdf5(
            tampered,
        )

        bad_axes = joinpath(directory, "bad-axes.h5")
        cp(filename, bad_axes)
        HDF5.h5open(bad_axes, "r+") do handle
            write(
                HDF5.attributes(handle["action/sewing_matrices"])["axis_order"],
                "kpoint,operation,source_band,target_band",
            )
        end
        @test_throws ArgumentError WannierNLQG.SymmetryFoundation.read_band_representation_hdf5(
            bad_axes,
        )

        bad_gate = joinpath(directory, "bad-gate.h5")
        cp(filename, bad_gate)
        HDF5.h5open(bad_gate, "r+") do handle
            write(
                HDF5.attributes(handle["compatibility"])["gate_definition_status"],
                "GATE_DEFINITION_INVALID",
            )
        end
        @test_throws ArgumentError WannierNLQG.SymmetryFoundation.read_band_representation_hdf5(
            bad_gate,
        )

        future = joinpath(directory, "future.h5")
        cp(filename, future)
        HDF5.h5open(future, "r+") do handle
            write(HDF5.attributes(handle)["schema_version"], "2.0")
        end
        @test_throws ArgumentError WannierNLQG.SymmetryFoundation.read_band_representation_hdf5(
            future,
        )
    end
end
