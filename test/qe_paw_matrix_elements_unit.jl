using HDF5
using LinearAlgebra
using Test

include(joinpath(@__DIR__, "QEPAWMatrixElementsTestSupport.jl"))
using .QEPAWMatrixElementsTestSupport

const QE_PAW_WANNIERIZATION = WannierNLQG.Wannierization
const QE_PAW_SYMMETRIZATION = WannierNLQG.Symmetrization
const QE_PAW_IO = WannierNLQG.IO

function qe_paw_source(save_directory::AbstractString)
    return WannierNLQG.SymmetryFoundation.QuantumEspressoWavefunctionSource(
        save_directory;
        include_time_reversal = false,
    )
end

@testset "native QE PAW/USPP public contracts" begin
    thresholds = QE_PAW_WANNIERIZATION.QEPAWParityThresholds()
    @test thresholds.generalized_norm_max_absolute == 5.0e-6
    @test thresholds.mmn_max_absolute == 1.0e-5
    @test thresholds.mmn_rms == 1.0e-7
    @test thresholds.mmn_relative_l2 == 1.0e-6
    @test thresholds.amn_max_principal_angle_rad == 1.0e-4
    @test thresholds.amn_projector_max_absolute == 1.0e-5
    @test_throws ArgumentError QE_PAW_WANNIERIZATION.QEPAWParityThresholds(mmn_rms = 0.0)
    native = QE_PAW_WANNIERIZATION.NativeQEPAWMatrices("fixture.nnkp"; artifact_dir = "artifacts")
    @test native.require_oracle
    @test native.thresholds == thresholds
    @test_throws ArgumentError QE_PAW_WANNIERIZATION.NativeQEPAWMatrices(
        "";
        artifact_dir = "artifacts",
    )
end

@testset "NNKP is the strict topology, band, and projection authority" begin
    mktempdir() do directory
        fixture = write_qe_paw_fixture(directory)
        nnkp = QE_PAW_IO.read_wannier_nnkp(fixture.nnkp_file)
        @test nnkp isa QE_PAW_IO.WannierNNKP
        @test nnkp.neighbors == ones(Int, 1, 1)
        @test nnkp.reciprocal_shifts == zeros(Int, 3, 1, 1)
        @test isempty(nnkp.excluded_bands)
        @test length(nnkp.projections) == 1
        @test !nnkp.spinor
        @test length(nnkp.source_sha256) == 64

        malformed = joinpath(directory, "malformed.nnkp")
        write(malformed, replace(read(fixture.nnkp_file, String), "1 1 0 0 0" => "1 2 0 0 0"))
        @test_throws ArgumentError QE_PAW_IO.read_wannier_nnkp(malformed)
    end
end
@testset "native QE NC construction and fail-closed oracle qualification" begin
    mktempdir() do directory
        fixture = write_qe_paw_fixture(directory)
        source = qe_paw_source(fixture.save_directory)
        diagnostic = QE_PAW_WANNIERIZATION.generate_qe_paw_matrix_elements(
            source,
            fixture.nnkp_file;
            artifact_dir = joinpath(directory, "diagnostic"),
            require_oracle = false,
        )
        @test diagnostic.passed
        @test diagnostic.physical_overlap_available
        @test diagnostic.generalized_norm_max_absolute == 0.0
        @test diagnostic.mmn.data == ones(ComplexF64, 1, 1, 1, 1)
        @test all(isfile, values(diagnostic.artifacts))
        @test QE_PAW_IO.read_wannier_mmn(diagnostic.artifacts["mmn"]).data == diagnostic.mmn.data
        @test QE_PAW_IO.read_wannier_amn(diagnostic.artifacts["amn"]).data == diagnostic.amn.data

        oracle = copy_qe_paw_oracles(diagnostic, joinpath(directory, "oracle"))
        provenance = write_qe_paw_oracle_provenance(dirname(oracle.mmn), diagnostic.input_sha256)
        qualified = QE_PAW_WANNIERIZATION.generate_qe_paw_matrix_elements(
            source,
            fixture.nnkp_file;
            artifact_dir = joinpath(directory, "qualified"),
            oracle_mmn_file = oracle.mmn,
            oracle_amn_file = oracle.amn,
        )
        @test qualified.passed
        @test qualified.physical_overlap_available
        @test qualified.mmn_parity.max_absolute == 0.0
        @test qualified.amn_parity.max_absolute == 0.0
        @test qualified.amn_max_principal_angle_rad <= 2.0e-8
        @test qualified.amn_projector_max_absolute <= 1.0e-12
        @test qualified.artifacts["oracle_provenance_hdf5"] == abspath(provenance)
        HDF5.h5open(qualified.artifacts["provenance_hdf5"], "r") do handle
            attributes = HDF5.attributes(handle)
            @test String(read(attributes["schema"])) == "WannierNLQG.qe_paw_matrix_elements"
            @test String(read(attributes["schema_version"])) == "1.0"
            @test Bool(read(attributes["passed"]))
            @test Bool(read(attributes["physical_overlap_available"]))
            @test haskey(handle, "thresholds")
            @test haskey(handle, "qualification")
            @test haskey(handle, "input_sha256")
            @test haskey(handle, "parity_metrics/mmn")
            @test haskey(handle, "parity_metrics/amn")
            @test String(
                read(HDF5.attributes(handle["qualification/mmn_max_absolute"])["status"]),
            ) == "PASS"
        end

        missing_provenance_oracle =
            copy_qe_paw_oracles(diagnostic, joinpath(directory, "missing-provenance-oracle"))
        missing_provenance = QE_PAW_WANNIERIZATION.generate_qe_paw_matrix_elements(
            source,
            fixture.nnkp_file;
            artifact_dir = joinpath(directory, "missing-provenance-result"),
            oracle_mmn_file = missing_provenance_oracle.mmn,
            oracle_amn_file = missing_provenance_oracle.amn,
        )
        @test !missing_provenance.passed
        @test !missing_provenance.physical_overlap_available
        @test any(contains("QE_ORACLE_INPUT_HASH_MISMATCH"), missing_provenance.diagnostics)

        missing_files = QE_PAW_WANNIERIZATION.generate_qe_paw_matrix_elements(
            source,
            fixture.nnkp_file;
            artifact_dir = joinpath(directory, "missing-files-result"),
            oracle_mmn_file = joinpath(directory, "does-not-exist.mmn"),
            oracle_amn_file = joinpath(directory, "does-not-exist.amn"),
        )
        @test !missing_files.passed
        @test !missing_files.physical_overlap_available
        @test missing_files.input_sha256["ORACLE_MMN"] == "MISSING"
        @test missing_files.input_sha256["ORACLE_AMN"] == "MISSING"
        @test any(contains("QE_ORACLE_MMN_MISSING"), missing_files.diagnostics)
        @test any(contains("QE_ORACLE_AMN_MISSING"), missing_files.diagnostics)

        mmn_only = QE_PAW_WANNIERIZATION.generate_qe_paw_matrix_elements(
            source,
            fixture.nnkp_file;
            artifact_dir = joinpath(directory, "mmn-only-result"),
            oracle_mmn_file = oracle.mmn,
            require_oracle = false,
        )
        @test mmn_only.passed
        @test mmn_only.mmn_parity.max_absolute == 0.0
        @test mmn_only.amn_parity === nothing

        corrupted = QE_PAW_IO.read_wannier_amn(oracle.amn)
        corrupted.data[1, 1, 1] += 1.0e-3
        QE_PAW_IO.write_wannier_amn(oracle.amn, corrupted; comment = "deliberately corrupted")
        corrupted_result = QE_PAW_WANNIERIZATION.generate_qe_paw_matrix_elements(
            source,
            fixture.nnkp_file;
            artifact_dir = joinpath(directory, "corrupted-result"),
            oracle_mmn_file = oracle.mmn,
            oracle_amn_file = oracle.amn,
        )
        @test !corrupted_result.passed
        @test !corrupted_result.physical_overlap_available
        @test corrupted_result.amn_parity.max_absolute >= 9.9e-4
        @test any(contains("QE_PAW_AMN_PARITY_FAILED"), corrupted_result.diagnostics)
    end
end

@testset "generated QE matrix-element qualification ladder" begin
    for lane in qe_paw_fixture_lanes()
        @testset "$(lane.label)" begin
            mktempdir() do directory
                fixture = write_qe_paw_fixture(
                    directory;
                    metric_kind = lane.metric_kind,
                    spinor = lane.spinor,
                    spinorbit = lane.spinorbit,
                )
                nnkp = QE_PAW_IO.read_wannier_nnkp(fixture.nnkp_file)
                @test nnkp.spinor == lane.spinor
                source = qe_paw_source(fixture.save_directory)
                diagnostic = QE_PAW_WANNIERIZATION.generate_qe_paw_matrix_elements(
                    source,
                    fixture.nnkp_file;
                    artifact_dir = joinpath(directory, "diagnostic"),
                    require_oracle = false,
                )
                @test diagnostic.passed
                @test diagnostic.physical_overlap_available
                @test diagnostic.generalized_norm_max_absolute == 0.0

                oracle = copy_qe_paw_oracles(diagnostic, joinpath(directory, "oracle"))
                write_qe_paw_oracle_provenance(dirname(oracle.mmn), diagnostic.input_sha256)
                qualified = QE_PAW_WANNIERIZATION.generate_qe_paw_matrix_elements(
                    source,
                    fixture.nnkp_file;
                    artifact_dir = joinpath(directory, "qualified"),
                    oracle_mmn_file = oracle.mmn,
                    oracle_amn_file = oracle.amn,
                )
                @test qualified.passed
                @test qualified.physical_overlap_available
                @test qualified.mmn_parity.max_absolute == 0.0
                @test qualified.mmn_parity.root_mean_square == 0.0
                @test qualified.mmn_parity.relative_l2 == 0.0
                @test qualified.amn_parity.max_absolute == 0.0
                @test qualified.amn_parity.root_mean_square == 0.0
                @test qualified.amn_parity.relative_l2 == 0.0
                @test qualified.amn_max_principal_angle_rad <= 2.0e-8
                @test qualified.amn_projector_max_absolute <= 1.0e-12
                @test QE_PAW_IO.read_wannier_mmn(qualified.artifacts["mmn"]).data ==
                      qualified.mmn.data
                @test QE_PAW_IO.read_wannier_amn(qualified.artifacts["amn"]).data ==
                      qualified.amn.data
                HDF5.h5open(qualified.artifacts["provenance_hdf5"], "r") do handle
                    @test Bool(read(HDF5.attributes(handle)["spinorbit"])) == lane.spinorbit
                    @test String(read(HDF5.attributes(handle)["qualification_status"])) == "PASS"
                end
            end
        end
    end
end

@testset "QE augmentation and SOC algebra kernels" begin
    extension = first(QE_PAW_WANNIERIZATION._load_wannierization_extension!()).PAWMatrixElements
    preparation =
        first(QE_PAW_WANNIERIZATION._load_wannierization_extension!()).RepresentationPreparation
    @test Base.invokelatest(extension._qe_upf_cubic_interpolation, index -> index^3, 0.015) ≈ 3.375 atol =
        1.0e-13 rtol = 0.0
    y00 = Base.invokelatest(extension._qe_real_spherical_harmonics, 0, zeros(1, 3))[1]
    @test y00 ≈ inv(sqrt(4.0 * pi)) atol = 1.0e-14 rtol = 0.0
    p_x_qe =
        Base.invokelatest(extension._qe_real_spherical_harmonics, 1, reshape([1.0, 0.0, 0.0], 1, 3))
    p_x_wannier90 = Base.invokelatest(
        extension._qe_wannier90_real_spherical_harmonics,
        1,
        reshape([1.0, 0.0, 0.0], 1, 3),
    )
    p_x_normalization = sqrt(3.0 / (4.0 * pi))
    @test p_x_qe[2, 1] ≈ -p_x_normalization atol = 1.0e-14 rtol = 0.0
    @test p_x_wannier90[2, 1] ≈ p_x_normalization atol = 1.0e-14 rtol = 0.0
    @test p_x_qe[2, 1] == -p_x_wannier90[2, 1]
    gaunt000 = Base.invokelatest(extension._qe_real_gaunt, 0, 1, 0, 1, 0, 1)
    @test gaunt000 ≈ inv(sqrt(4.0 * pi)) atol = 2.0e-13 rtol = 0.0

    expanded = Dict{NTuple{3, Int}, Vector{Float64}}()
    original = Dict((1, 1) => fill(9.0, 3))
    qfcoef = reshape([3.0], 1, 1, 1, 1)
    Base.invokelatest(
        preparation._qe_upf_apply_qfcoef!,
        expanded,
        original,
        [0.0, 0.5, 1.0],
        [0],
        qfcoef,
        [0.75],
    )
    @test expanded[(1, 1, 0)] == [0.0, 0.75, 9.0]

    p_channels = [Base.invokelatest(extension.QEProjectorChannel, 1, 1, row) for row in 1:3]
    radial_multipoles = Dict((1, 1, 0) => [0.0, 1.0, 0.0], (1, 1, 2) => [0.0, 0.25, 0.0])
    scalar_dataset = Base.invokelatest(
        extension.QEUPFData,
        "synthetic.UPF",
        "X",
        :ultrasoft,
        false,
        false,
        [0.0, 0.5, 1.0],
        [0.5, 0.5, 0.5],
        zeros(3, 1),
        [1],
        3,
        [NaN],
        zeros(1, 1),
        reshape([2.0 / 3.0], 1, 1),
        true,
        radial_multipoles,
        zeros(Float64, 0, 0, 0, 0),
        Float64[],
        3,
        3,
        1.0,
    )
    positive_b = Base.invokelatest(
        extension._qe_finite_b_scalar_matrix,
        scalar_dataset,
        p_channels,
        [0.13, -0.07, 0.05],
    )
    negative_b = Base.invokelatest(
        extension._qe_finite_b_scalar_matrix,
        scalar_dataset,
        p_channels,
        [-0.13, 0.07, -0.05],
    )
    @test negative_b ≈ positive_b' atol = 2.0e-13 rtol = 0.0
    scalar_spin = Base.invokelatest(
        extension._qe_spin_augmentation_matrix,
        positive_b,
        scalar_dataset,
        p_channels,
        2,
        false,
    )
    @test scalar_spin[:, :, 1, 1] == positive_b
    @test scalar_spin[:, :, 2, 2] == positive_b
    @test iszero(scalar_spin[:, :, 1, 2])

    soc_channels = [
        Base.invokelatest(extension.QEProjectorChannel, radial, 1, row) for radial in 1:2 for
        row in 1:3
    ]
    soc_dataset = Base.invokelatest(
        extension.QEUPFData,
        "synthetic-fr.UPF",
        "X",
        :paw,
        true,
        true,
        [0.0, 0.5, 1.0],
        [0.5, 0.5, 0.5],
        zeros(3, 2),
        [1, 1],
        3,
        [0.5, 1.5],
        zeros(2, 2),
        Matrix{Float64}(I, 2, 2),
        true,
        Dict{NTuple{3, Int}, Vector{Float64}}(),
        zeros(Float64, 0, 0, 0, 0),
        Float64[],
        3,
        3,
        1.0,
    )
    fcoef = Base.invokelatest(extension._qe_soc_fcoef, soc_dataset, soc_channels)
    projector = zeros(ComplexF64, 12, 12)
    for left in 1:6, right in 1:6, spin_left in 1:2, spin_right in 1:2
        projector[2 * (left - 1) + spin_left, 2 * (right - 1) + spin_right] =
            fcoef[left, right, spin_left, spin_right]
    end
    @test projector ≈ projector' atol = 2.0e-15 rtol = 0.0
    @test projector * projector ≈ projector atol = 3.0e-15 rtol = 0.0
    @test real(tr(projector)) ≈ 6.0 atol = 3.0e-15 rtol = 0.0
    transformed = Base.invokelatest(
        extension._qe_spin_augmentation_matrix,
        Matrix{ComplexF64}(I, 6, 6),
        soc_dataset,
        soc_channels,
        2,
        true,
    )
    transformed_matrix = zeros(ComplexF64, 12, 12)
    for left in 1:6, right in 1:6, spin_left in 1:2, spin_right in 1:2
        transformed_matrix[2 * (left - 1) + spin_left, 2 * (right - 1) + spin_right] =
            transformed[left, right, spin_left, spin_right]
    end
    @test transformed_matrix ≈ projector atol = 3.0e-15 rtol = 0.0

    for metric_kind in (:norm_conserving, :ultrasoft, :paw)
        mktempdir() do directory
            fixture = write_qe_paw_fixture(directory; metric_kind)
            dataset = Base.invokelatest(
                preparation._read_qe_upf_data,
                joinpath(fixture.save_directory, "X.UPF"),
            )
            @test dataset.metric_kind == metric_kind
            @test dataset.q_with_l
            @test dataset.beta_angular_momenta == [0]
            @test dataset.beta_integration_cutoff_index == 3
            if metric_kind == :norm_conserving
                @test isempty(dataset.q_radial_by_multipole)
            else
                @test haskey(dataset.q_radial_by_multipole, (1, 1, 0))
            end
            original = joinpath(fixture.save_directory, "X.UPF")
            duplicated_trailer = joinpath(directory, "X-duplicated-trailer.UPF")
            write(duplicated_trailer, read(original, String), "\n1.000000000000000e-1\n</UPF>\n")
            duplicate_dataset =
                @test_logs (:warn, r"QE_UPF_TRAILING_DUPLICATE_IGNORED") Base.invokelatest(
                    preparation._read_qe_upf_data,
                    duplicated_trailer,
                )
            @test duplicate_dataset.element == dataset.element
            @test duplicate_dataset.metric_kind == dataset.metric_kind
            @test duplicate_dataset.beta_radial == dataset.beta_radial

            unrecognized_trailer = joinpath(directory, "X-unrecognized-trailer.UPF")
            write(unrecognized_trailer, read(original, String), "\nnot-an-upf-trailer\n")
            @test_throws ArgumentError Base.invokelatest(
                preparation._read_qe_upf_data,
                unrecognized_trailer,
            )
        end
    end

    source_root = normpath(joinpath(@__DIR__, "..", "..", "SAWF", "wb_example", "QEfiles"))
    if isdir(joinpath(source_root, "GaAs.save"))
        ga_upf = only(
            filter(
                name -> startswith(lowercase(name), "ga") && endswith(lowercase(name), ".upf"),
                readdir(joinpath(source_root, "GaAs.save")),
            ),
        )
        dataset = Base.invokelatest(
            preparation._read_qe_upf_data,
            joinpath(source_root, "GaAs.save", ga_upf),
        )
        @test dataset.metric_kind == :paw
        @test dataset.augmentation_cutoff_index > 0
        @test dataset.beta_integration_cutoff_index == dataset.augmentation_cutoff_index
    end
end
