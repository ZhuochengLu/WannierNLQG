if !isdefined(Main, :BandPublicSchemaTestSupport)
    include(joinpath(@__DIR__, "BandPublicSchemaTestSupport.jl"))
end

using HDF5
using LinearAlgebra
using Test

include(joinpath(@__DIR__, "QECoefficientSewingTestSupport.jl"))
using .QECoefficientSewingTestSupport

const QE_SEWING_WANNIERIZATION = WannierNLQG.Wannierization
const QE_SEWING_SYMMETRIZATION = WannierNLQG.Symmetrization

# Build the one-orbital projection basis used by native-AMN boundary tests.
function qe_sewing_projection_basis()
    block = WannierNLQG.WannierProjection.WannierProjectionBlock(
        "X",
        "s",
        zeros(3, 1),
        reshape([1], 1, 1),
        reshape(Matrix{Float64}(I, 3, 3), 3, 3, 1),
        false,
    )
    return WannierNLQG.WannierProjection.WannierProjectionBasis([block], 1, false)
end

# Capture one thrown exception without weakening its concrete error contract.
function qe_sewing_captured_error(function_value)
    return try
        function_value()
        nothing
    catch exception
        exception
    end
end

# Build the identity-only representation carried by the one-k-point fixture.
function qe_sewing_identity_representation(extension, native)
    operation = WannierNLQG.SymmetryFoundation.SymmetryOperation(
        Matrix{Int}(I, 3, 3),
        zeros(3),
        Matrix{Float64}(I, 3, 3),
    )
    energies = reshape(copy(only(native.kpoints).energies_ev), 1, 1)
    representation = Base.invokelatest(
        extension._build_band_representation,
        native,
        energies,
        [operation],
        1.0e-8,
    )
    plan = WannierNLQG.SymmetryFoundation.WannierSymmetryPlan(
        [operation],
        ones(ComplexF64, 1, 1, 1),
        zeros(Int, 3, 1, 1),
    )
    report = QE_SEWING_WANNIERIZATION.validate_band_representation_compatibility(
        representation,
        plan;
        outer_mask = [trues(1)],
        frozen_mask = [trues(1)],
        tolerance = 1.0e-12,
    )
    return (; representation, report)
end

@testset "QE PAW/USPP coefficient-sewing purpose and provenance" begin
    QE_SEWING_WANNIERIZATION._load_wannierization_extension!()
    extension =
        Base.get_extension(WannierNLQG, :WannierNLQGWannierizationExt).RepresentationPreparation
    extension === nothing && error("Wannierization extension did not load")

    @test Base.invokelatest(
        extension._qe_metric_kind_label,
        Dict("C" => :ultrasoft, "A" => :norm_conserving, "B" => :paw),
    ) == "mixed:norm_conserving,paw,ultrasoft"

    basis = qe_sewing_projection_basis()
    for metric_kind in (:norm_conserving, :paw, :ultrasoft)
        mktempdir() do directory
            save_directory = write_qe_coefficient_sewing_fixture(directory, metric_kind)
            source = WannierNLQG.SymmetryFoundation.QuantumEspressoWavefunctionSource(
                save_directory;
                band_range = 1:1,
                include_time_reversal = false,
            )
            native = Base.invokelatest(
                extension._read_qe_wavefunctions,
                source;
                purpose = :band_representation,
            )
            nonidentity = metric_kind != :norm_conserving
            @test native.source_metadata["qe_reader_purpose"] == "band_representation"
            @test native.source_metadata["qe_metric_kind"] == string(metric_kind)
            @test native.source_metadata["coefficient_normalization"] ==
                  (nonidentity ? "euclidean_per_band_pseudo_gauge" : "euclidean_per_band")
            @test native.source_metadata["sewing_construction"] == "coefficient_mapping"
            @test native.source_metadata["physical_overlap_available"] == string(!nonidentity)
            @test native.source_metadata["augmentation_backend"] ==
                  (nonidentity ? "unavailable" : "not_required")
            @test native.source_metadata["qualification"] ==
                  (nonidentity ? "experimental" : "standard")
            @test sum(abs2, only(native.kpoints).coefficients) == 1.0

            built = qe_sewing_identity_representation(extension, native)
            @test built.report.passed
            @test built.representation.sewing_matrices == ones(ComplexF64, 1, 1, 1, 1)
            prepared = BandPublicSchemaTestSupport.prepare_public_band_fixture(
                built.representation;
                directory,
                projection_basis = basis,
            )
            output = joinpath(directory, "representation.h5")
            WannierNLQG.SymmetryFoundation.write_band_representation_hdf5(
                output,
                prepared.representation,
                prepared.compatibility_report,
            )
            restored = WannierNLQG.SymmetryFoundation.read_band_representation_hdf5(output)
            @test restored.conventions["qe_metric_kind"] == string(metric_kind)
            @test restored.conventions["physical_overlap_available"] == string(!nonidentity)
            @test restored.sewing_matrices == built.representation.sewing_matrices
            if metric_kind == :paw
                probe = joinpath(@__DIR__, "QECoefficientSewingFreshReadProbe.jl")
                command = addenv(
                    `$(Base.julia_cmd()) --startup-file=no --project=$(dirname(@__DIR__)) $(probe) $(output)`,
                    "OMP_NUM_THREADS" => "1",
                    "MKL_NUM_THREADS" => "1",
                    "OPENBLAS_NUM_THREADS" => "1",
                    "VECLIB_MAXIMUM_THREADS" => "1",
                )
                fresh_output = read(command, String)
                @test occursin(r"QE_PAW_FRESH_READ_DIGEST=[0-9a-f]{64}", fresh_output)
            end

            if nonidentity
                physical_error = qe_sewing_captured_error() do
                    Base.invokelatest(
                        extension._read_qe_wavefunctions,
                        source;
                        purpose = :physical_overlap,
                    )
                end
                @test physical_error isa ArgumentError
                @test occursin("QE_AUGMENTATION_METRIC_REQUIRED", sprint(showerror, physical_error))
                bypass_error = qe_sewing_captured_error() do
                    Base.invokelatest(extension._generate_amn, native, basis)
                end
                @test bypass_error isa ArgumentError
                @test occursin("operation=generate_wannier_amn", sprint(showerror, bypass_error))
                public_error = qe_sewing_captured_error() do
                    QE_SEWING_WANNIERIZATION.generate_wannier_amn(source, basis)
                end
                @test public_error isa ArgumentError
                @test occursin("QE_AUGMENTATION_METRIC_REQUIRED", sprint(showerror, public_error))
            else
                physical_native = Base.invokelatest(
                    extension._read_qe_wavefunctions,
                    source;
                    purpose = :physical_overlap,
                )
                @test physical_native.source_metadata["physical_overlap_available"] == "true"
                generated = QE_SEWING_WANNIERIZATION.generate_wannier_amn(source, basis)
                @test size(generated.data) == (1, 1, 1)
                @test all(isfinite, generated.data)
            end

            invalid_error = qe_sewing_captured_error() do
                Base.invokelatest(extension._read_qe_wavefunctions, source; purpose = :unsupported)
            end
            @test invalid_error isa ArgumentError
            @test occursin(
                "unsupported QE wavefunction reader purpose",
                sprint(showerror, invalid_error),
            )
        end
    end
end
