using HDF5
using LinearAlgebra
using Test

const PAW_SCDM_W = WannierNLQG.Wannierization

function copied_paw_scdm_artifact(
    artifact;
    frames = artifact.frames,
    projectors = artifact.projectors,
    kpoints_fractional = artifact.kpoints_fractional,
    mp_grid = artifact.mp_grid,
    spinor = artifact.spinor,
    authoritative_hamiltonian = artifact.authoritative_hamiltonian,
    authoritative_hamiltonian_sha256 = artifact.authoritative_hamiltonian_sha256,
)
    return PAW_SCDM_W.PAWSCDMInputArtifact(
        artifact.schema_version,
        frames,
        projectors,
        artifact.selected_grid_indices,
        artifact.sampling_grid,
        artifact.singular_values,
        artifact.ranks,
        artifact.conditions,
        artifact.generalized_norm_residuals,
        artifact.paw_s_orthogonality_residuals,
        artifact.euclidean_orthogonality_residuals,
        kpoints_fractional,
        mp_grid,
        spinor,
        artifact.source_gauge_sha256,
        artifact.strict_representation_sha256,
        authoritative_hamiltonian,
        authoritative_hamiltonian_sha256,
        artifact.metric_sha256,
        artifact.source_identity,
        artifact.payload_sha256,
    )
end

@testset "PAW-S SCDM metric, artifact, and solver bridge" begin
    PAW_SCDM_W._load_wannierization_extension!()
    extension = Base.get_extension(WannierNLQG, :WannierNLQGWannierizationExt).PAWMatrixElements
    @test extension !== nothing

    # A nonzero-Q oracle must alter the physical overlap used by Lowdin.  The
    # NC oracle reduces exactly to the pseudo coefficient metric.
    coefficients = zeros(ComplexF64, 2, 2, 1)
    coefficients[1, 1, 1] = sqrt(0.8)
    coefficients[2, 2, 1] = 1.0
    point = Base.invokelatest(
        WannierNLQG.SymmetryFoundation.PlaneWaveKPoint,
        zeros(3),
        [0 0 0; 1 0 0],
        coefficients,
        [-1.0, 1.0];
        normalize_coefficients = false,
    )
    projectors = zeros(ComplexF64, 2, 1, 1)
    projectors[1, 1, 1] = 1.0
    paw = Base.invokelatest(
        extension.VASPPawSystem,
        Dict{String, extension.VASPPawDataset}(),
        String[],
        extension.VASPPawAtomLayout[],
        1,
        reshape([0.2], 1, 1),
        1.0,
    )
    metric = Base.invokelatest(
        extension._VASPStrictSewingMetric,
        paw,
        [projectors],
        [zeros(ComplexF64, 1, 2)],
    )
    overlap, lowdin = Base.invokelatest(extension._paw_scdm_lowdin, metric, 1, point)
    @test overlap ≈ Matrix{ComplexF64}(I, 2, 2) atol = 2.0e-15 rtol = 0.0
    @test lowdin ≈ Matrix{ComplexF64}(I, 2, 2) atol = 2.0e-15 rtol = 0.0

    nc_paw = Base.invokelatest(
        extension.VASPPawSystem,
        Dict{String, extension.VASPPawDataset}(),
        String[],
        extension.VASPPawAtomLayout[],
        1,
        zeros(1, 1),
        1.0,
    )
    nc_metric = Base.invokelatest(
        extension._VASPStrictSewingMetric,
        nc_paw,
        [zeros(ComplexF64, 2, 1, 1)],
        [zeros(ComplexF64, 1, 2)],
    )
    nc_coefficients = zeros(ComplexF64, 2, 2, 1)
    nc_coefficients[1, 1, 1] = 1.0
    nc_coefficients[2, 2, 1] = 1.0
    nc_point = Base.invokelatest(
        WannierNLQG.SymmetryFoundation.PlaneWaveKPoint,
        zeros(3),
        [0 0 0; 1 0 0],
        nc_coefficients,
        [-1.0, 1.0];
        normalize_coefficients = false,
    )
    nc_overlap, nc_lowdin = Base.invokelatest(extension._paw_scdm_lowdin, nc_metric, 1, nc_point)
    @test nc_overlap == Matrix{ComplexF64}(I, 2, 2)
    @test nc_lowdin == Matrix{ComplexF64}(I, 2, 2)

    incomplete_native = (
        source_metadata = Dict("coefficient_normalization" => "vasp_normalized"),
        source_code = :vasp,
        kpoints = [point],
        spinor = false,
    )
    incomplete_payload = (
        native = incomplete_native,
        metric = metric,
        input_sha256 = Dict{String, String}(),
        source_metadata = Dict{String, String}(),
    )
    cutoff_error = try
        Base.invokelatest(
            extension._paw_scdm_source_identity,
            incomplete_payload,
            repeat("a", 64),
            repeat("b", 64),
        )
        nothing
    catch exception
        exception
    end
    @test cutoff_error isa ArgumentError
    @test occursin("full-cutoff raw coefficients", sprint(showerror, cutoff_error))

    empty_paw = Base.invokelatest(
        extension.VASPPawSystem,
        Dict{String, extension.VASPPawDataset}(),
        String[],
        extension.VASPPawAtomLayout[],
        0,
        zeros(0, 0),
        1.0,
    )
    empty_metric = Base.invokelatest(
        extension._VASPStrictSewingMetric,
        empty_paw,
        [zeros(ComplexF64, 2, 0, 1)],
        [zeros(ComplexF64, 0, 2)],
    )
    empty_payload = (
        native = merge(
            incomplete_native,
            (source_metadata = Dict("coefficient_normalization" => "vasp_raw"),),
        ),
        metric = empty_metric,
        input_sha256 = Dict{String, String}(),
        source_metadata = Dict{String, String}(),
    )
    projector_error = try
        Base.invokelatest(
            extension._paw_scdm_source_identity,
            empty_payload,
            repeat("a", 64),
            repeat("b", 64),
        )
        nothing
    catch exception
        exception
    end
    @test projector_error isa ArgumentError
    @test occursin("projector plan is empty", sprint(showerror, projector_error))

    malformed_q_paw = Base.invokelatest(
        extension.VASPPawSystem,
        Dict{String, extension.VASPPawDataset}(),
        String[],
        extension.VASPPawAtomLayout[],
        1,
        zeros(0, 0),
        1.0,
    )
    malformed_q_metric = Base.invokelatest(
        extension._VASPStrictSewingMetric,
        malformed_q_paw,
        [zeros(ComplexF64, 2, 1, 1)],
        [zeros(ComplexF64, 1, 2)],
    )
    malformed_q_payload = merge(empty_payload, (metric = malformed_q_metric,))
    q_error = try
        Base.invokelatest(
            extension._paw_scdm_source_identity,
            malformed_q_payload,
            repeat("a", 64),
            repeat("b", 64),
        )
        nothing
    catch exception
        exception
    end
    @test q_error isa ArgumentError
    @test occursin("Q dimensions differ", sprint(showerror, q_error))

    transported = ComplexF64[1.0+1.0e-9 0.0; 0.0 1.0-2.0e-9; 0.0 1.0e-10]
    repaired = PAW_SCDM_W._repair_expanded_frozen_frame(transported, [1, 2, 3], [1], 1.0e-10)
    @test repaired !== nothing
    repaired_frame = something(repaired)
    @test maximum(abs, repaired_frame' * repaired_frame - I) <= 2.0e-15
    @test norm(repaired_frame * conj.(@view(repaired_frame[1, :])) - ComplexF64[1, 0, 0]) <= 2.0e-15
    @test PAW_SCDM_W._repair_expanded_frozen_frame(transported, [1, 2, 3], [1], 1.0e-10) ==
          repaired_frame

    frames = reshape(ComplexF64[1, 0, 1, 0], 2, 1, 2)
    projectors_field = zeros(ComplexF64, 2, 2, 2)
    projectors_field[1, 1, :] .= 1.0
    selected = reshape([1, 1, 1, 1], 4, 1)
    singular_values = ones(1, 2)
    ranks = ones(Int, 2)
    conditions = ones(2)
    residuals = zeros(2)
    kpoints = [0.0 0.0 0.0; 0.5 0.0 0.0]
    source_identity = Dict(
        "metric_kind" => "paw",
        "metric_sha256" => repeat("d", 64),
        "source_gauge_sha256" => repeat("a", 64),
        "strict_representation_sha256" => repeat("b", 64),
        "authoritative_hamiltonian" => "native_dft",
        "authoritative_hamiltonian_sha256" => "LEGACY_NATIVE_DFT",
        "augmentation_source" => "parsed_upf_or_potcar_q0_not_mmn_amn",
        "sampling_contract" => "pseudo_coordinate_columns_after_paw_s_lowdin_whitening",
    )
    digest = Base.invokelatest(
        extension._paw_scdm_payload_sha256,
        frames,
        projectors_field,
        selected,
        (1, 1, 1),
        singular_values,
        ranks,
        conditions,
        residuals,
        residuals,
        residuals,
        kpoints,
        (2, 1, 1),
        false,
        repeat("a", 64),
        repeat("b", 64),
        "native_dft",
        "LEGACY_NATIVE_DFT",
        repeat("d", 64),
        source_identity,
    )
    artifact = PAW_SCDM_W.PAWSCDMInputArtifact(
        "1.0",
        frames,
        projectors_field,
        selected,
        (1, 1, 1),
        singular_values,
        ranks,
        conditions,
        residuals,
        residuals,
        residuals,
        kpoints,
        (2, 1, 1),
        false,
        repeat("a", 64),
        repeat("b", 64),
        "native_dft",
        "LEGACY_NATIVE_DFT",
        repeat("d", 64),
        source_identity,
        digest,
    )
    mktempdir() do directory
        filename = joinpath(directory, "paw-scdm.h5")
        Base.invokelatest(extension._paw_scdm_write, filename, artifact)
        restored = PAW_SCDM_W.read_paw_scdm_input_artifact(filename)
        @test restored.payload_sha256 == artifact.payload_sha256
        @test restored.frames == artifact.frames
        @test restored.projectors == artifact.projectors

        HDF5.h5open(filename, "r+") do handle
            values = read(handle["frames"])
            values[1] += 1.0e-3
            write(handle["frames"], values)
        end
        error_value = try
            PAW_SCDM_W.read_paw_scdm_input_artifact(filename)
            nothing
        catch exception
            exception
        end
        @test error_value isa ArgumentError
        @test occursin("payload digest differs", sprint(showerror, error_value))
    end

    fixture = synthetic_wannierization_fixture()
    config = modified_wannierization_config(
        fixture.config;
        initialization_backend = PAW_SCDM_W.PAWSCDMInitialization(),
        paw_scdm_input_hdf5 = "synthetic-paw-scdm.h5",
        initialization = :random,
    )
    result = PAW_SCDM_W._solve_symmetry_adapted_wannierization(
        config,
        fixture.representation,
        fixture.eig,
        fixture.mmn,
        fixture.plan;
        paw_scdm_input = artifact,
    )
    @test result.status != PAW_SCDM_W.INVALID_INPUT
    @test result.input_summary["paw_scdm_input_precondition"] == "PASS"
    @test result.input_summary["paw_scdm_minimum_rank"] == "1"
    @test parse(Float64, result.input_summary["initializer_frozen_projector_residual"]) <= 1.0e-12

    ordinary_config = modified_wannierization_config(
        config;
        wannierization_mode = :ordinary,
        algorithm_profile = :custom,
        band_representation = nothing,
        sewing_backend = PAW_SCDM_W.AugmentationAwareSewing(),
        wavefunction_gauge_backend = PAW_SCDM_W.NativeEigenstateGauge(),
        authoritative_hamiltonian = PAW_SCDM_W.NativeDFTHamiltonian(),
    )
    @test PAW_SCDM_W._validate_wannierization_config(ordinary_config) === nothing
    ordinary_result = PAW_SCDM_W._solve_symmetry_adapted_wannierization(
        ordinary_config,
        fixture.representation,
        fixture.eig,
        fixture.mmn,
        fixture.plan;
        paw_scdm_input = artifact,
    )
    @test ordinary_result.status != PAW_SCDM_W.INVALID_INPUT
    @test ordinary_result.input_summary["paw_scdm_authority_usage"] == "input_provenance_only"
    @test ordinary_result.input_summary["covariance_qualification"] == "DIAGNOSTIC_ONLY"
    @test ordinary_result.input_summary["symmetry_constraints_applied"] == "false"

    bad_spinor = copied_paw_scdm_artifact(artifact; spinor = true)
    spinor_result = PAW_SCDM_W._solve_symmetry_adapted_wannierization(
        config,
        fixture.representation,
        fixture.eig,
        fixture.mmn,
        fixture.plan;
        paw_scdm_input = bad_spinor,
    )
    @test spinor_result.status == PAW_SCDM_W.INVALID_INPUT

    bad_kpoints = copied_paw_scdm_artifact(
        artifact;
        kpoints_fractional = artifact.kpoints_fractional .+ 1.0e-4,
    )
    kpoint_result = PAW_SCDM_W._solve_symmetry_adapted_wannierization(
        config,
        fixture.representation,
        fixture.eig,
        fixture.mmn,
        fixture.plan;
        paw_scdm_input = bad_kpoints,
    )
    @test kpoint_result.status == PAW_SCDM_W.INVALID_INPUT

    bad_authority = copied_paw_scdm_artifact(
        artifact;
        authoritative_hamiltonian = "symmetrized_dft_hamiltonian",
        authoritative_hamiltonian_sha256 = repeat("f", 64),
    )
    authority_result = PAW_SCDM_W._solve_symmetry_adapted_wannierization(
        config,
        fixture.representation,
        fixture.eig,
        fixture.mmn,
        fixture.plan;
        paw_scdm_input = bad_authority,
    )
    @test authority_result.status == PAW_SCDM_W.INVALID_INPUT

    bad_projectors = copy(artifact.projectors)
    bad_projectors[1, 1, 1] += 1.0e-3
    projector_result = PAW_SCDM_W._solve_symmetry_adapted_wannierization(
        config,
        fixture.representation,
        fixture.eig,
        fixture.mmn,
        fixture.plan;
        paw_scdm_input = copied_paw_scdm_artifact(artifact; projectors = bad_projectors),
    )
    @test projector_result.status == PAW_SCDM_W.INVALID_INPUT

    @test fixture.config.solver.paw_scdm_input_hdf5 === nothing
    @test_throws ArgumentError PAW_SCDM_W._validate_wannierization_config(
        modified_wannierization_config(
            fixture.config;
            initialization_backend = PAW_SCDM_W.PAWSCDMInitialization(),
        ),
    )
    @test_throws ArgumentError PAW_SCDM_W._validate_wannierization_config(
        modified_wannierization_config(fixture.config; paw_scdm_input_hdf5 = "unexpected.h5"),
    )
    mktempdir() do directory
        @test_throws ArgumentError PAW_SCDM_W.prepare_paw_scdm_input_artifact(
            joinpath(directory, "missing-gauge.h5"),
            joinpath(directory, "missing-representation.h5"),
            joinpath(directory, "output.h5");
            num_wannier = 1,
        )
    end
end
