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
    authoritative_hamiltonian_definition = artifact.authoritative_hamiltonian_definition,
    source_identity = artifact.source_identity,
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
        artifact.source_gauge_reference,
        artifact.strict_representation_reference,
        authoritative_hamiltonian,
        authoritative_hamiltonian_definition,
        artifact.gauge_frame_definition,
        source_identity,
        artifact.content_authentication,
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
        Base.invokelatest(extension._paw_scdm_source_identity, incomplete_payload)
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
        Base.invokelatest(extension._paw_scdm_source_identity, empty_payload)
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
        Base.invokelatest(extension._paw_scdm_source_identity, malformed_q_payload)
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
    authority_definition = Base.invokelatest(
        extension._star_authoritative_hamiltonian_definition,
        PAW_SCDM_W.NativeDFTHamiltonian(),
    )
    # This is an algebra/codec fixture, not a source-qualified PAW producer.
    source_identity = Dict(
        "fixture_scope" => "synthetic_algebra_codec",
        "sampling_contract" => "pseudo_coordinate_columns_after_paw_s_lowdin_whitening",
        "authoritative_hamiltonian" => "native_dft",
        "authoritative_hamiltonian_definition" => authority_definition,
    )
    source_gauge_reference = WannierNLQG.IO.scientific_input_definition_bytes() do stream
        WannierNLQG.IO.write_native_definition_value(stream, (frames, projectors_field, kpoints))
    end
    representation_reference = WannierNLQG.IO.scientific_input_definition_bytes() do stream
        WannierNLQG.IO.write_native_definition_value(stream, (kpoints, (2, 1, 1), false))
    end
    gauge_frame = Base.invokelatest(extension._identity_band_frame_contract, 2, 2)
    artifact = PAW_SCDM_W.PAWSCDMInputArtifact(
        "2.0",
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
        source_gauge_reference,
        representation_reference,
        "native_dft",
        authority_definition,
        gauge_frame.contract_definition,
        source_identity,
        "NOT_PERFORMED",
    )
    mktempdir() do directory
        filename = joinpath(directory, "paw-scdm.h5")
        Base.invokelatest(extension._paw_scdm_write, filename, artifact)
        restored = PAW_SCDM_W.read_paw_scdm_input_artifact(filename)
        @test restored.content_authentication == artifact.content_authentication
        @test restored.frames == artifact.frames
        @test restored.projectors == artifact.projectors

        HDF5.h5open(filename, "r+") do handle
            values = read(handle["frames"])
            values[1] = ComplexF64(NaN)
            write(handle["frames"], values)
        end
        error_value = try
            PAW_SCDM_W.read_paw_scdm_input_artifact(filename)
            nothing
        catch exception
            exception
        end
        @test error_value isa ArgumentError
        @test occursin("nonfinite SCDM payload", sprint(showerror, error_value))
    end

    fixture = synthetic_wannierization_fixture()
    # This local algebra fixture declares its actual selected authority, not a digest.
    fixture.representation.conventions["authoritative_hamiltonian"] = "native_dft"
    fixture.representation.conventions["authoritative_hamiltonian_sha256"] = authority_definition
    config = modified_wannierization_config(
        fixture.config;
        initialization_backend = PAW_SCDM_W.PAWSCDMInitialization(),
        paw_scdm_input_hdf5 = "synthetic-paw-scdm.h5",
        # The explicit PAW backend supplies the SCDM seed; random is a conflicting selector.
        initialization = :amn,
    )
    result = PAW_SCDM_W._solve_symmetry_adapted_wannierization(
        config,
        fixture.representation,
        fixture.eig,
        fixture.mmn,
        fixture.plan;
        paw_scdm_input = artifact,
    )
    @test PAW_SCDM_W._validate_wannierization_config(config) === nothing
    @test result.status != PAW_SCDM_W.INVALID_INPUT
    @test result.input_summary["paw_scdm_input_precondition"] == "PASS"
    @test result.input_summary["paw_scdm_minimum_rank"] == "1"
    @test parse(Float64, result.input_summary["initializer_frozen_projector_residual"]) <= 1.0e-12

    ordinary_config = modified_wannierization_config(
        config;
        wannierization_mode = :ordinary,
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
    @test ordinary_result.input_summary["covariance_qualification"] == "STANDARD"
    @test ordinary_result.input_summary["symmetry_constraints_applied"] == "false"

    # PAW-only high-level execution must not invent/read an unused AMN source.
    @test_throws ArgumentError PAW_SCDM_W._validate_wannierization_config(
        modified_wannierization_config(fixture.config; initialization = :amn),
    )
    if !isdefined(@__MODULE__, :tiny_wannier_workflow)
        include(
            joinpath(
                @__DIR__,
                "..",
                "ext",
                "WannierNLQGWannierizationExt",
                "PrecompileSupport",
                "TinyWannierWorkflowInputs.jl",
            ),
        )
    end
    mktempdir() do directory
        inputs = Base.invokelatest(tiny_wannier_workflow, directory)
        write(
            inputs.solve.input.win_file,
            """
num_wann = 1
mp_grid = 2 1 1
begin unit_cell_cart
angstrom
1.0 0.0 0.0
0.0 1.0 0.0
0.0 0.0 1.0
end unit_cell_cart
begin kpoints
0.0 0.0 0.0
0.5 0.0 0.0
end kpoints
""",
        )
        scdm_file = joinpath(directory, "seed.scdm.h5")
        Base.invokelatest(extension._paw_scdm_write, scdm_file, artifact)
        high_config = modified_wannierization_config(
            ordinary_config;
            win_file = inputs.solve.input.win_file,
            eig_file = inputs.eig,
            mmn_file = inputs.mmn,
            paw_scdm_input_hdf5 = scdm_file,
            checkpoint_hdf5 = joinpath(directory, "paw.wannierization.h5"),
            model_file = joinpath(directory, "paw.model.h5"),
            num_print_cycles = 0,
        )
        @test high_config.input.amn_file === nothing
        @test high_config.input.source === nothing
        solved = PAW_SCDM_W.construct_wannier_functions(high_config)
        accepted = solved.status in
        (PAW_SCDM_W.COMPLETED, PAW_SCDM_W.COMPLETED_WITH_WARNINGS, PAW_SCDM_W.MAX_ITERATIONS)
        @test accepted
        accepted || error("PAW-only public workflow failed: $(solved.diagnostics)")
        @test solved.input_summary["paw_scdm_input_precondition"] == "PASS"
        @test solved.input_summary["localization_reference"] == "initializer_fallback"
        @test !isfile(joinpath(directory, "tiny.amn"))
    end

    for definition_key in ("AUTHORITATIVE_HAMILTONIAN_SHA256", "authoritative_hamiltonian_sha256")
        @test Base.invokelatest(
            extension._paw_scdm_authority_definition,
            Dict(definition_key => authority_definition),
            definition_key,
        ) == authority_definition
        for values in
            (Dict{String, String}(), Dict(definition_key => ""), Dict(definition_key => "MISSING"))
            @test_throws ArgumentError Base.invokelatest(
                extension._paw_scdm_authority_definition,
                values,
                definition_key,
            )
        end
    end
    different_definition = Base.invokelatest(
        extension._star_authoritative_hamiltonian_definition,
        PAW_SCDM_W.SymmetrizedDFTHamiltonian(),
    )
    for variant in (:missing, :empty, :sentinel, :different, :old_key_only)
        changed_identity = copy(artifact.source_identity)
        if variant in (:missing, :old_key_only)
            delete!(changed_identity, "authoritative_hamiltonian_definition")
            variant == :old_key_only &&
                (changed_identity["authoritative_hamiltonian_sha256"] = authority_definition)
        else
            changed_identity["authoritative_hamiltonian_definition"] =
                variant == :empty ? "" : variant == :sentinel ? "MISSING" : different_definition
        end
        rejected = PAW_SCDM_W._solve_symmetry_adapted_wannierization(
            ordinary_config,
            fixture.representation,
            fixture.eig,
            fixture.mmn,
            fixture.plan;
            paw_scdm_input = copied_paw_scdm_artifact(artifact; source_identity = changed_identity),
        )
        @test rejected.status == PAW_SCDM_W.INVALID_INPUT
        @test any(
            diagnostic ->
                diagnostic.code == :SCDM_INPUT_PRECONDITION &&
                occursin("source authority definition provenance differs", diagnostic.message),
            rejected.diagnostics,
        )
    end

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
        authoritative_hamiltonian_definition = different_definition,
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

@testset "PAW-SCDM normalized FFT samples and band/spin scratch reuse" begin
    PAW_SCDM_W._load_wannierization_extension!()
    extension = Base.get_extension(WannierNLQG, :WannierNLQGWannierizationExt).PAWMatrixElements
    fft = extension.FFTW
    g_vectors = [0 0 0; -1 0 0; 0 1 -1; 1 -2 1; 1 1 0]
    lowdin = ComplexF64[1 0.1im 0; -0.1im 0.8 0.05; 0 0.05 1.2]
    for spin_count in (1, 2), grid in ((3, 5, 3), (5, 5, 5))
        coefficients = [
            ComplexF64((band + 2grow + spin) / 23, (2band - grow + 3spin) / 29) for
            band in 1:3, grow in 1:5, spin in 1:spin_count
        ]
        point = Base.invokelatest(
            WannierNLQG.SymmetryFoundation.PlaneWaveKPoint,
            zeros(3),
            g_vectors,
            coefficients,
            [-1.0, 0.0, 1.0];
            normalize_coefficients = false,
        )
        original_coefficients = copy(point.coefficients)
        original_g_vectors = copy(point.g_vectors)
        original_lowdin = copy(lowdin)
        actual = Base.invokelatest(extension._paw_scdm_anchor_samples, point, lowdin, grid)
        # Retain the old allocation/ifft algorithm as the exact regression oracle.
        rotated = zeros(ComplexF64, size(coefficients))
        for spin in 1:spin_count
            rotated[:, :, spin] .= transpose(lowdin) * coefficients[:, :, spin]
        end
        old_samples = zeros(ComplexF64, 3, prod(grid) * spin_count)
        dft_samples = similar(old_samples)
        for spin in 1:spin_count, band in 1:3
            old_buffer = zeros(ComplexF64, grid)
            for grow in 1:5
                index = ntuple(axis -> mod(g_vectors[grow, axis], grid[axis]) + 1, 3)
                old_buffer[index...] = rotated[band, grow, spin]
            end
            values = Base.invokelatest(fft.ifft, old_buffer)
            offset = (spin - 1) * prod(grid)
            old_samples[band, (offset + 1):(offset + prod(grid))] .= vec(values)
            # Independent positive-exponent, volume-normalized inverse DFT.
            for (linear, index) in enumerate(CartesianIndices(grid))
                value = zero(ComplexF64)
                for grow in 1:5
                    phase =
                        sum(g_vectors[grow, axis] * (index[axis] - 1) / grid[axis] for axis in 1:3)
                    value += rotated[band, grow, spin] * cis(2pi * phase)
                end
                dft_samples[band, offset + linear] = value / prod(grid)
            end
        end
        @test size(actual) == (3, prod(grid) * spin_count)
        @test all(isfinite, actual)
        @test !all(iszero, actual)
        @test isequal(actual, old_samples)
        @test actual ≈ dft_samples atol = 2e-14 rtol = 2e-14
        @test isequal(point.coefficients, original_coefficients)
        @test isequal(point.g_vectors, original_g_vectors)
        @test isequal(lowdin, original_lowdin)
    end
end
