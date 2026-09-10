if !isdefined(@__MODULE__, :WANNIERIZATION_FIXTURE_SUPPORT_LOADED)
    include(joinpath(@__DIR__, "WannierizationFixtureSupport.jl"))
end

@testset "Validated Hermitian spectrum and deterministic subspace selection" begin
    matrix = ComplexF64[
        6.0 0.1im 0.0 0.0 0.0 0.0
        -0.1im 5.0 0.2 0.0 0.0 0.0
        0.0 0.2 4.0 0.1im 0.0 0.0
        0.0 0.0 -0.1im 3.0 0.2 0.0
        0.0 0.0 0.0 0.2 2.0 0.1im
        0.0 0.0 0.0 0.0 -0.1im 1.0
    ]
    outer_indices = collect(1:6)

    audit = WANNIERIZATION_IMPLEMENTATION.SolverCheckpoint.HermitianSpectrumAudit()
    spectrum = WANNIERIZATION._validated_hermitian_spectrum(
        matrix;
        tolerance = 1.0e-10,
        context = "synthetic_hermitian_spectrum",
        audit,
    )
    @test spectrum.success
    @test spectrum.backend == :hermitian_eigen
    @test length(spectrum.values) == 6
    @test spectrum.residual <= 1.0e-8
    @test spectrum.orthogonality <= 1.0e-8

    fallback_audit = WANNIERIZATION_IMPLEMENTATION.SolverCheckpoint.HermitianSpectrumAudit()
    fallback = WANNIERIZATION._validated_hermitian_spectrum(
        matrix;
        tolerance = 1.0e-10,
        context = "synthetic_hermitian_spectrum:forced_fallback",
        audit = fallback_audit,
        force_fallback = true,
    )
    @test fallback.success
    @test fallback.backend == :complex_schur
    @test fallback_audit.fallback_count == 1
    @test sort(fallback.values) ≈ sort(spectrum.values) atol = 1.0e-10 rtol = 1.0e-10

    selection = WANNIERIZATION._maximum_subspace_result(
        matrix,
        outer_indices,
        Int[],
        4,
        1.0e-10;
        audit,
        context = "synthetic_hermitian_spectrum:selection",
    )
    @test selection.success
    @test selection.code == :OK
    @test size(something(selection.frame)) == (6, 4)
    @test something(selection.frame)' * something(selection.frame) ≈ Matrix{ComplexF64}(I, 4, 4) atol =
        1.0e-10 rtol = 0.0

    # A nondegenerate boundary must always select the strict largest-eigenvalue
    # subspace. A reference frame cannot pull lower-eigenvalue directions into Z.
    tracked_z = Matrix(Diagonal(ComplexF64[0.0, 0.0, 1.0, 2.0, 6.0, 5.0]))
    tracked_reference = zeros(ComplexF64, 6, 4)
    tracked_reference[1, 1] = 1.0
    tracked_reference[2, 2] = 1.0
    tracked_reference[3, 3] = 1.0
    tracked_reference[4, 4] = 1.0
    untracked = WANNIERIZATION._maximum_subspace_result(tracked_z, collect(1:6), [1, 2], 4, 1.0e-10)
    @test untracked.success
    @test rank(something(untracked.frame)' * tracked_reference; atol = 1.0e-10) == 2
    tracked = WANNIERIZATION._maximum_subspace_result(
        tracked_z,
        collect(1:6),
        [1, 2],
        4,
        1.0e-10;
        reference_frame = tracked_reference,
        maximum_reference_condition = 1.0e8,
    )
    @test tracked.success
    @test tracked.selection_method == :maximum_eigenspace
    @test something(tracked.frame) * something(tracked.frame)' ≈
          something(untracked.frame) * something(untracked.frame)' atol = 1.0e-12 rtol = 0.0

    bad_reference = copy(tracked_reference)
    bad_reference[:, 4] .= bad_reference[:, 3]
    bad_tracking = WANNIERIZATION._maximum_subspace_result(
        tracked_z,
        collect(1:6),
        [1, 2],
        4,
        1.0e-10;
        reference_frame = bad_reference,
    )
    @test bad_tracking.success
    @test bad_tracking.selection_method == :maximum_eigenspace

    # Only an actual boundary cluster may use the old frame to fix gauge.
    clustered_z = Matrix(Diagonal(ComplexF64[0.0, 0.0, 6.0, 5.0, 5.0 + 1.0e-10, 1.0]))
    clustered_reference = zeros(ComplexF64, 6, 4)
    clustered_reference[1, 1] = 1.0
    clustered_reference[2, 2] = 1.0
    clustered_reference[3, 3] = 1.0
    clustered_reference[5, 4] = 1.0
    clustered = WANNIERIZATION._maximum_subspace_result(
        clustered_z,
        collect(1:6),
        [1, 2],
        4,
        1.0e-3;
        reference_frame = clustered_reference,
        numerical_thresholds = WANNIERIZATION.WannierizationNumericalThresholds(
            subspace_cluster_atol = 1.0e-12,
            subspace_cluster_rtol = 1.0e-8,
        ),
    )
    @test clustered.success
    @test clustered.selection_method == :boundary_cluster_procrustes
    @test clustered.boundary_cluster_size == 2
    @test norm(
        something(clustered.frame) * something(clustered.frame)' -
        clustered_reference * clustered_reference',
    ) <= 1.0e-10
    clustered_loose_representation = WANNIERIZATION._maximum_subspace_result(
        clustered_z,
        collect(1:6),
        [1, 2],
        4,
        1.0e-2;
        reference_frame = clustered_reference,
        numerical_thresholds = WANNIERIZATION.WannierizationNumericalThresholds(),
    )
    clustered_tight_representation = WANNIERIZATION._maximum_subspace_result(
        clustered_z,
        collect(1:6),
        [1, 2],
        4,
        1.0e-12;
        reference_frame = clustered_reference,
        numerical_thresholds = WANNIERIZATION.WannierizationNumericalThresholds(),
    )
    @test clustered_loose_representation.success
    @test clustered_tight_representation.success
    @test something(clustered_loose_representation.frame) *
          something(clustered_loose_representation.frame)' ≈
          something(clustered_tight_representation.frame) *
          something(clustered_tight_representation.frame)' atol = 1.0e-12 rtol = 0.0

    rank_deficient =
        WANNIERIZATION._orthonormalize_columns_result(ComplexF64[1.0 0.0; 0.0 0.0], 1.0e-10)
    @test !rank_deficient.success
    @test rank_deficient.code == :SUBSPACE_RANK_DEFICIENT

    nonfinite = WANNIERIZATION._validated_hermitian_spectrum(
        ComplexF64[NaN 0.0; 0.0 1.0];
        tolerance = 1.0e-10,
    )
    @test !nonfinite.success
    @test nonfinite.code == :HERMITIAN_SPECTRAL_DECOMPOSITION_FAILED
    @test nonfinite.primary_failure == :NONFINITE_INPUT

    invalid_residual = WANNIERIZATION._validate_hermitian_eigensystem(
        ComplexF64[1.0 0.0; 0.0 2.0],
        [0.0, 0.0],
        Matrix{ComplexF64}(I, 2, 2);
        tolerance = 1.0e-12,
    )
    @test !invalid_residual.success
    @test invalid_residual.reason == :RESIDUAL_GATE_FAILED
end

@testset "Wannier90-reference DGESVD backend" begin
    matrix = Float64[4 0; 0 3; 0 0]
    decomposition =
        WANNIERIZATION_IMPLEMENTATION.SolverCheckpoint._wannier90_reference_dgesvd(matrix)
    @test decomposition !== nothing
    if decomposition !== nothing
        reconstructed =
            decomposition.left[:, 1:2] *
            Diagonal(decomposition.singular_values) *
            decomposition.right_adjoint
        @test reconstructed ≈ matrix atol = 1.0e-12 rtol = 0.0
    end
end

@testset "Wannier AMN public formatted I/O" begin
    values = reshape(
        ComplexF64[
            0.12345678901234566 + 0.25im,
            -0.75 + 0.33333333333333331im,
            1.25 - 2.5im,
            -3.75 + 4.125im,
        ],
        2,
        1,
        2,
    )
    amn = WANNIER_IO.WannierAMN(2, 2, 1, values)
    mktempdir() do directory
        path = joinpath(directory, "synthetic.amn")
        @test WANNIER_IO.write_wannier_amn(path, amn) == abspath(path)
        restored = WANNIER_IO.read_wannier_amn(path)
        @test restored.num_bands == 2
        @test restored.num_kpts == 2
        @test restored.num_wannier == 1
        @test restored.data == values
        rows = readlines(path)
        push!(rows, rows[3])
        duplicate = joinpath(directory, "duplicate.amn")
        open(duplicate, "w") do io
            for row in rows
                println(io, row)
            end
        end
        @test_throws ArgumentError WANNIER_IO.read_wannier_amn(duplicate)
    end
end

@testset "Wannierization configuration and deterministic primitives" begin
    fixture = synthetic_wannierization_fixture()
    @test WANNIERIZATION._validate_wannierization_config(fixture.config) === nothing
    @test WANNIERIZATION._validate_wannierization_config(
        modified_wannierization_config(fixture.config; parallel = :mpi),
    ) === nothing
    @test fixture.config.runtime.progress_interval == 10
    @test fixture.config.checkpoint.checkpoint_interval == 10
    @test fixture.config.input.target_center_matching_tolerance == 1.0e-8
    @test fixture.config.output.tb_output_formats == (:packed_hdf5,)
    @test fixture.config.solver.acceleration == WANNIERIZATION.WannierizationAccelerationConfig()
    no_symmetry_auto = modified_wannierization_config(
        fixture.config;
        wannierization_mode = :ordinary,
        band_representation = nothing,
        band_representation_hdf5 = "identity.schema-1.4.h5",
        algorithm_profile = :auto,
    )
    ordinary_default = WANNIERIZATION._effective_wannierization_algorithms(no_symmetry_auto)
    @test ordinary_default.profile == :smv_fletcher_reeves_two_stage
    @test ordinary_default.disentanglement == :smv_fletcher_reeves_two_stage
    @test ordinary_default.localization == :smv_fletcher_reeves_two_stage
    @test ordinary_default.default_selection_reason == "UNCONDITIONAL_ORDINARY_DEFAULT"
    @test WANNIERIZATION._validate_wannierization_config(no_symmetry_auto) === nothing
    thresholds = WANNIERIZATION.SMVFletcherReevesTwoStageAuditThresholds()
    @test thresholds.accepted_step_absolute_tolerance == 5.0e-12
    @test thresholds.accepted_step_relative_tolerance == 5.0e-8
    @test thresholds.accepted_step_combination_rule ==
          "abs_diff <= abs_tol + rel_tol * max(abs(reference), abs(candidate))"
    @test thresholds.semantic == "SMV_FLETCHER_REEVES_TWO_STAGE_ORACLE_PARITY_WITH_FROZEN_TOLERANCE"
    @test occursin(
        r"^[0-9a-f]{64}$",
        WANNIERIZATION.smv_fletcher_reeves_two_stage_audit_contract_sha256(thresholds),
    )
    missing_audit = WANNIERIZATION.smv_fletcher_reeves_two_stage_audit(
        manifest_path = "definitely-missing-smv-fr-audit.json",
        thresholds = thresholds,
    )
    @test !missing_audit.passed
    @test missing_audit.status == "AUDIT_MANIFEST_MISSING"
    mktempdir() do directory
        manifest_path = joinpath(directory, "smv_fr_audit.json")
        manifest = Dict{String, Any}(
            "schema" => WANNIERIZATION.SMV_FLETCHER_REEVES_TWO_STAGE_AUDIT_SCHEMA,
            "schema_version" =>
                WANNIERIZATION.SMV_FLETCHER_REEVES_TWO_STAGE_AUDIT_SCHEMA_VERSION,
            "status" => WANNIERIZATION.SMV_FLETCHER_REEVES_TWO_STAGE_AUDIT_PASS_STATUS,
            "passed" => true,
            "algorithm_contract_version" =>
                WANNIERIZATION.SMV_FLETCHER_REEVES_TWO_STAGE_ALGORITHM_CONTRACT_VERSION,
            "parity_standard_version" => thresholds.standard_version,
            "parity_semantic" => thresholds.semantic,
            "accepted_step_combination_rule" => thresholds.accepted_step_combination_rule,
            "accepted_step_absolute_tolerance" => thresholds.accepted_step_absolute_tolerance,
            "accepted_step_relative_tolerance" => thresholds.accepted_step_relative_tolerance,
            "parity_contract_sha256" =>
                WANNIERIZATION.smv_fletcher_reeves_two_stage_audit_contract_sha256(thresholds),
            "solver_source_sha256" =>
                WANNIERIZATION_IMPLEMENTATION.SolverCheckpoint._symmetry_adapted_solver_source_sha256(),
            "models_source_sha256" => WANNIERIZATION._sha256_file(
                joinpath(
                    dirname(dirname(pathof(WannierNLQG))),
                    "ext",
                    "WannierNLQGWannierizationExt",
                    "SMVFletcherReevesAudit.jl",
                ),
            ),
            "oracle_sha256" => repeat("a", 64),
            "parity_evidence_sha256" => repeat("b", 64),
            "cr_qualification_sha256" => repeat("c", 64),
        )
        open(manifest_path, "w") do io
            JSON3.pretty(io, manifest)
            write(io, '\n')
        end
        audited = modified_wannierization_config(
            no_symmetry_auto;
            smv_fletcher_reeves_two_stage_audit_manifest = manifest_path,
        )
        audited_algorithms = WANNIERIZATION._effective_wannierization_algorithms(audited)
        @test audited_algorithms == ordinary_default
        @test WANNIERIZATION._validate_wannierization_config(audited) === nothing
        audit = WANNIERIZATION.smv_fletcher_reeves_two_stage_audit(
            manifest_path = manifest_path,
            thresholds = thresholds,
        )
        @test audit.passed
        @test audit.status == "SMV_FLETCHER_REEVES_TWO_STAGE_AUDIT_PASS"
        @test WANNIERIZATION._restart_config_repr(audited) ==
              WANNIERIZATION._restart_config_repr(no_symmetry_auto)
        manifest["accepted_step_relative_tolerance"] = 1.0e-8
        open(manifest_path, "w") do io
            JSON3.pretty(io, manifest)
            write(io, '\n')
        end
        mismatched = WANNIERIZATION.smv_fletcher_reeves_two_stage_audit(
            manifest_path = manifest_path,
            thresholds = thresholds,
        )
        @test !mismatched.passed
        @test mismatched.status == "AUDIT_DIGEST_MISMATCH"
        @test WANNIERIZATION._validate_wannierization_config(audited) === nothing
        @test WANNIERIZATION._effective_wannierization_algorithms(audited) == ordinary_default
        open(manifest_path, "w") do io
            write(io, "{not-json")
        end
        invalid = WANNIERIZATION.smv_fletcher_reeves_two_stage_audit(
            manifest_path = manifest_path,
            thresholds = thresholds,
        )
        @test !invalid.passed
        @test invalid.status == "AUDIT_MANIFEST_INVALID"
        @test WANNIERIZATION._validate_wannierization_config(audited) === nothing
    end
    explicit_reference = modified_wannierization_config(
        no_symmetry_auto;
        algorithm_profile = :custom,
        acceleration = WANNIERIZATION.WannierizationAccelerationConfig(
            disentanglement_algorithm = :smv_fletcher_reeves_two_stage,
            localization_algorithm = :smv_fletcher_reeves_two_stage,
        ),
    )
    reference_algorithms = WANNIERIZATION._effective_wannierization_algorithms(explicit_reference)
    @test reference_algorithms.disentanglement == :smv_fletcher_reeves_two_stage
    @test reference_algorithms.localization == :smv_fletcher_reeves_two_stage
    @test reference_algorithms.profile == :custom
    @test WANNIERIZATION._validate_wannierization_config(explicit_reference) === nothing
    symmetry_auto = WANNIERIZATION._effective_wannierization_algorithms(fixture.config)
    @test symmetry_auto.profile == :symmetry_projected_smv_fletcher_reeves_two_stage
    @test symmetry_auto.disentanglement == :symmetry_projected_smv_fletcher_reeves_two_stage
    @test symmetry_auto.localization == :symmetry_projected_smv_fletcher_reeves_two_stage
    @test symmetry_auto.default_selection_reason == "UNCONDITIONAL_SYMMETRY_PROJECTED_DEFAULT"
    @test WANNIERIZATION._validate_wannierization_config(fixture.config) === nothing
    removed_legacy = modified_wannierization_config(
        no_symmetry_auto;
        algorithm_profile = :custom,
        acceleration = WANNIERIZATION.WannierizationAccelerationConfig(
            localization_algorithm = :wannier90_fletcher_reeves,
        ),
    )
    legacy_error = try
        WANNIERIZATION._validate_wannierization_config(removed_legacy)
        nothing
    catch error
        error
    end
    @test legacy_error isa ArgumentError
    @test occursin("REMOVED_LEGACY_LOCALIZATION_ALGORITHM", sprint(showerror, legacy_error))
    stencil = WANNIERIZATION._finite_difference_weights(fixture.representation, fixture.mmn)
    @test stencil.target_moment == Matrix{Float64}(I, 3, 3)
    @test stencil.completeness_residual <= 1.0e-10
    @test rank(stencil.vectors_cartesian) == 3
    incomplete_mmn = WANNIER_IO.WannierMMN(
        2,
        2,
        2,
        fixture.mmn.data[:, :, 1:2, :],
        fixture.mmn.neighbors[1:2, :],
        fixture.mmn.reciprocal_shifts[:, 1:2, :],
    )
    @test_throws ArgumentError WANNIERIZATION._finite_difference_weights(
        fixture.representation,
        incomplete_mmn,
    )
    identity_operation = fixture.representation.operations[1]
    nonorthogonal_reciprocal = [1.0 0.0 0.0; -0.5 sqrt(3.0) / 2 0.0; 0.0 0.0 2.0]
    nonorthogonal_representation = WannierNLQG.SymmetryFoundation.BandRepresentation(
        "1.0",
        :synthetic,
        false,
        Matrix{Float64}(I, 3, 3),
        nonorthogonal_reciprocal,
        (1, 1, 1),
        zeros(1, 3),
        zeros(1, 1),
        [identity_operation],
        ones(Int, 1, 1),
        zeros(Int, 3, 1, 1),
        ones(ComplexF64, 1, 1, 1, 1),
        ones(Int, 1, 1),
        [1],
        [1],
        [1],
    )
    shifts = [
        1 -1 0 0 1 -1 0 0
        0 0 1 -1 1 -1 0 0
        0 0 0 0 0 0 1 -1
    ]
    nonorthogonal_mmn = WANNIER_IO.WannierMMN(
        1,
        1,
        8,
        ones(ComplexF64, 1, 1, 8, 1),
        ones(Int, 8, 1),
        reshape(shifts, 3, 8, 1),
    )
    nonorthogonal_stencil =
        WANNIERIZATION._finite_difference_weights(nonorthogonal_representation, nonorthogonal_mmn)
    moment = zeros(3, 3)
    for neighbor in 1:8
        vector = @view nonorthogonal_stencil.vectors_cartesian[neighbor, :]
        moment .+= nonorthogonal_stencil.weights[neighbor] .* vector * vector'
    end
    @test moment ≈ Matrix{Float64}(I, 3, 3) atol = 1.0e-10 rtol = 0.0
    @test WANNIERIZATION._validate_wannierization_config(
        modified_wannierization_config(
            fixture.config;
            progress_interval = 0,
            checkpoint_interval = 0,
            tb_output_formats = (),
        ),
    ) === nothing
    @test_throws ArgumentError WANNIERIZATION._validate_wannierization_config(
        modified_wannierization_config(fixture.config; progress_interval = -1),
    )
    @test_throws ArgumentError WANNIERIZATION._validate_wannierization_config(
        modified_wannierization_config(fixture.config; checkpoint_interval = -1),
    )
    @test_throws ArgumentError WANNIERIZATION._validate_wannierization_config(
        modified_wannierization_config(fixture.config; target_center_matching_tolerance = 0.0),
    )
    for invalid_tolerance in (0.0, -1.0e-5, NaN, Inf)
        @test_throws ArgumentError WANNIERIZATION._validate_wannierization_config(
            modified_wannierization_config(fixture.config; symmetry_tolerance = invalid_tolerance),
        )
    end
    @test_throws ArgumentError WANNIERIZATION._validate_wannierization_config(
        modified_wannierization_config(fixture.config; tb_output_formats = (:npz,)),
    )
    @test_throws ArgumentError WANNIERIZATION.SymmetryAdaptedWannierizationConfig(
        input = WANNIERIZATION.WannierizationInputConfig(
            wannierization_mode = :symmetry_adapted,
            win_file = "x",
            eig_file = "x",
            mmn_file = "x",
            band_representation = fixture.representation,
            projection_basis = fixture.basis,
            num_wannier = 1,
        ),
        solver = WANNIERIZATION.WannierizationSolverConfig(z_mix_ratio = 1.1),
        checkpoint = WANNIERIZATION.WannierizationCheckpointConfig(),
        runtime = WANNIERIZATION.WannierizationRuntimeConfig(),
        output = WANNIERIZATION.WannierizationOutputConfig(),
    ) |> WANNIERIZATION._validate_wannierization_config
    @test_throws ArgumentError WANNIERIZATION.SymmetryAdaptedWannierizationConfig(
        input = WANNIERIZATION.WannierizationInputConfig(
            wannierization_mode = :symmetry_adapted,
            win_file = "x",
            eig_file = "x",
            mmn_file = "x",
            band_representation = fixture.representation,
            projection_basis = fixture.basis,
            num_wannier = 1,
        ),
        solver = WANNIERIZATION.WannierizationSolverConfig(),
        checkpoint = WANNIERIZATION.WannierizationCheckpointConfig(),
        runtime = WANNIERIZATION.WannierizationRuntimeConfig(),
        output = WANNIERIZATION.WannierizationOutputConfig(
            tb_output_formats = (:packed_hdf5, :packed_hdf5),
        ),
    ) |> WANNIERIZATION._validate_wannierization_config

    @test WANNIERIZATION._complete_window_indices([-1.0, 0.0, 2.0], [1, 1, 2], -0.5, 0.5) == [1, 2]
    @test WANNIERIZATION._is_complete_outer_space([[1, 2], [1, 2]], 2, 2)
    @test !WANNIERIZATION._is_complete_outer_space([[1], [1]], 2, 2)
    @test !WANNIERIZATION._is_complete_outer_space([[1, 2], [1, 2]], 2, 1)
    old_unitary = Matrix{ComplexF64}(I, 2, 2)
    new_unitary = Diagonal(cis.([0.4, -0.8])) |> Matrix
    mixed = WANNIERIZATION._mix_unitaries(old_unitary, new_unitary, 0.25, 1.0e-12)
    @test mixed !== nothing
    @test mixed ≈ Diagonal(cis.([0.1, -0.2])) atol = 1.0e-12 rtol = 0.0

    raw_z = [ComplexF64[2 0; 0 1]]
    previous_z = [ComplexF64[0 0; 0 4]]
    @test WANNIERIZATION._mix_z_fields(raw_z, nothing, 0.25) == raw_z
    @test WANNIERIZATION._mix_z_fields(raw_z, previous_z, 0.25)[1] == ComplexF64[0.5 0; 0 3.25]

    antiunitary_operation = WannierNLQG.SymmetryFoundation.SymmetryOperation(
        Matrix{Int}(I, 3, 3),
        zeros(3),
        Matrix{Float64}(I, 3, 3),
        true,
    )
    sewing = ComplexF64[1 im; im 1] ./ sqrt(2)
    z_matrix = ComplexF64[2 1+2im; 1-2im 4]
    @test WANNIERIZATION._rotate_hermitian_field_entry(antiunitary_operation, sewing, z_matrix) ≈
          conj(sewing' * z_matrix * sewing)

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
    star_sewing = zeros(ComplexF64, 2, 2, 2, 2)
    for kpoint in 1:2
        star_sewing[:, :, 1, kpoint] .= Matrix{ComplexF64}(I, 2, 2)
    end
    band_swap = ComplexF64[0 1; 1 0]
    star_sewing[:, :, 2, 1] .= band_swap
    star_sewing[:, :, 2, 2] .= band_swap
    star_representation = WannierNLQG.SymmetryFoundation.BandRepresentation(
        "1.4",
        :synthetic,
        false,
        Matrix{Float64}(I, 3, 3),
        2.0pi .* Matrix{Float64}(I, 3, 3),
        (2, 1, 1),
        [0.25 0.0 0.0; 0.75 0.0 0.0],
        [-1.0 -1.0; 1.0 1.0],
        [identity_operation, inversion_operation],
        [1 2; 2 1],
        zeros(Int, 3, 2, 2),
        star_sewing,
        [1 1; 2 2],
        [1],
        [1, 1],
        [1, 2],
    )
    full_star_field = [ComplexF64[5 0; 0 1], ComplexF64[10 0; 0 0]]
    reduced_star_field =
        WANNIERIZATION._reduce_full_star_hermitian_field(full_star_field, star_representation)
    @test reduced_star_field[1] ≈ ComplexF64[2.5 0; 0 5.5]
    @test iszero(reduced_star_field[2])
    representative_only =
        WANNIERIZATION._maximum_subspace(full_star_field[1], [1, 2], Int[], 1, 1.0e-12)
    star_reduced =
        WANNIERIZATION._maximum_subspace(reduced_star_field[1], [1, 2], Int[], 1, 1.0e-12)
    @test abs2(representative_only[1, 1]) > 1.0 - 1.0e-12
    @test abs2(star_reduced[2, 1]) > 1.0 - 1.0e-12

    star_mmn_data = zeros(ComplexF64, 2, 2, 1, 2)
    for kpoint in 1:2
        star_mmn_data[:, :, 1, kpoint] .= Matrix{ComplexF64}(I, 2, 2)
    end
    star_mmn =
        WANNIER_IO.WannierMMN(2, 2, 1, star_mmn_data, reshape([2, 1], 1, 2), zeros(Int, 3, 1, 2))
    star_frames = [reshape(ComplexF64[1, 0], 2, 1), reshape(ComplexF64[0, 1], 2, 1)]
    star_plan = WannierNLQG.SymmetryFoundation.WannierSymmetryPlan(
        [identity_operation, inversion_operation],
        ones(ComplexF64, 1, 1, 2),
        zeros(Int, 3, 1, 2),
    )
    rotated_representative = reshape(ComplexF64[cos(0.2), sin(0.2)], 2, 1)
    stale_selected_subspaces = [rotated_representative, copy(star_frames[2])]
    completed_selected_subspaces = WANNIERIZATION._complete_selected_subspace_star(
        stale_selected_subspaces,
        star_representation,
        star_plan,
        true,
    )
    @test completed_selected_subspaces[1] == rotated_representative
    @test completed_selected_subspaces[2] ≈ band_swap * rotated_representative atol = 1.0e-14 rtol =
        0.0
    transport = WANNIERIZATION._localization_svd_polar(
        completed_selected_subspaces[1]' * star_frames[1],
        1.0e-10,
        1.0e8,
    )
    @test transport.success
    transported_frames = deepcopy(completed_selected_subspaces)
    transported_frames[1] = completed_selected_subspaces[1] * transport.unitary
    transported_frames =
        WANNIERIZATION._expand_ibz_frames(transported_frames, star_representation, star_plan)
    completed_projectors = [frame * frame' for frame in completed_selected_subspaces]
    stale_projectors = [frame * frame' for frame in stale_selected_subspaces]
    @test WANNIERIZATION._maximum_projector_drift(transported_frames, completed_projectors) <=
          1.0e-14
    @test WANNIERIZATION._maximum_projector_drift(transported_frames, stale_projectors) > 1.0e-3
    direct_completion_polar, direct_completion_spectrum, direct_completion_condition =
        WANNIERIZATION._rank_gated_svd_polar_columns(
            ComplexF64[1 0; 0 1.0e-8; 0 0];
            minimum_singular_value = 1.0e-12,
            maximum_condition = 1.0e10,
        )
    @test direct_completion_polar !== nothing
    @test direct_completion_spectrum ≈ [1.0, 1.0e-8] atol = 1.0e-16 rtol = 1.0e-12
    @test direct_completion_condition ≈ 1.0e8 atol = 1.0e-6 rtol = 1.0e-12
    @test something(direct_completion_polar)' * something(direct_completion_polar) ≈
          Matrix{ComplexF64}(I, 2, 2) atol = 1.0e-14 rtol = 0.0
    rejected_completion_polar, _, rejected_completion_condition =
        WANNIERIZATION._rank_gated_svd_polar_columns(
            ComplexF64[1 0; 0 1.0e-8; 0 0];
            minimum_singular_value = 1.0e-12,
            maximum_condition = 1.0e6,
        )
    @test rejected_completion_polar === nothing
    @test rejected_completion_condition > 1.0e6
    tracked_transport = WANNIERIZATION._transport_selected_subspace_corepresentation(
        stale_selected_subspaces,
        star_frames,
        star_representation,
        star_plan,
        1.0e-12,
        1.0e8,
        1.0e-12,
    )
    @test tracked_transport.success
    @test tracked_transport.frames ≈ transported_frames atol = 1.0e-14 rtol = 0.0
    @test tracked_transport.projector_drift <= 1.0e-14
    @test tracked_transport.maximum_local_isometry_residual <= 1.0e-14
    @test tracked_transport.maximum_local_projector_drift <= 1.0e-14
    @test tracked_transport.target_unitarity_residual <= 1.0e-14
    @test tracked_transport.sewing_isometry_residual <= 1.0e-14

    # A selected projector can remain exactly symmetry invariant while an
    # arbitrary degenerate eigensolver gauge violates the target frame by 2.
    # The Cr AMN first-step regression had precisely this signature.  Strict
    # polar transport must recover the accepted corepresentation without
    # moving that projector; a projector carrying the wrong irrep inventory
    # must instead fail closed at the overlap-rank gate.
    little_group_sewing = zeros(ComplexF64, 4, 4, 2, 1)
    little_group_sewing[:, :, 1, 1] .= Matrix{ComplexF64}(I, 4, 4)
    little_group_sewing[:, :, 2, 1] .= Diagonal(ComplexF64[1, -1, 1, -1])
    little_group_representation = WannierNLQG.SymmetryFoundation.BandRepresentation(
        "1.15",
        :synthetic,
        false,
        Matrix{Float64}(I, 3, 3),
        2.0pi .* Matrix{Float64}(I, 3, 3),
        (1, 1, 1),
        zeros(1, 3),
        zeros(4, 1),
        [identity_operation, inversion_operation],
        reshape([1, 1], 2, 1),
        zeros(Int, 3, 2, 1),
        little_group_sewing,
        reshape(collect(1:4), 4, 1),
        [1],
        [1],
        [1],
    )
    little_group_target = zeros(ComplexF64, 2, 2, 2)
    little_group_target[:, :, 1] .= Matrix{ComplexF64}(I, 2, 2)
    little_group_target[:, :, 2] .= Diagonal(ComplexF64[1, -1])
    little_group_plan = WannierNLQG.SymmetryFoundation.WannierSymmetryPlan(
        [identity_operation, inversion_operation],
        little_group_target,
        zeros(Int, 3, 2, 2),
    )
    accepted_corepresentation = [ComplexF64[1 0; 0 1; 0 0; 0 0]]
    gauge_swapped_subspace = [accepted_corepresentation[1] * ComplexF64[0 1; 1 0]]
    @test WANNIERIZATION._maximum_projector_covariance_error(
        gauge_swapped_subspace,
        little_group_representation,
    ) <= 1.0e-14
    @test WANNIERIZATION._maximum_target_frame_symmetry_error(
        gauge_swapped_subspace,
        little_group_representation,
        little_group_plan,
    ) == 2.0
    corepresentation_transport = WANNIERIZATION._transport_selected_subspace_corepresentation(
        gauge_swapped_subspace,
        accepted_corepresentation,
        little_group_representation,
        little_group_plan,
        1.0e-12,
        1.0e8,
        1.0e-12,
    )
    @test corepresentation_transport.success
    @test corepresentation_transport.frames ≈ accepted_corepresentation atol = 1.0e-14 rtol = 0.0
    @test corepresentation_transport.projector_drift <= 1.0e-14
    @test corepresentation_transport.target_symmetry <= 1.0e-14
    representation_changing_z = Matrix{ComplexF64}(Diagonal([4.0, 2.0, 3.0, 1.0]))
    plain_representation_changing_selection = WANNIERIZATION._maximum_subspace_result(
        representation_changing_z,
        collect(1:4),
        Int[],
        2,
        1.0e-12;
        reference_frame = accepted_corepresentation[1],
    )
    @test plain_representation_changing_selection.success
    @test plain_representation_changing_selection.frame *
          plain_representation_changing_selection.frame' ≈ Diagonal(ComplexF64[1, 0, 1, 0]) atol =
        1.0e-14 rtol = 0.0
    constrained_representation_selection =
        WANNIERIZATION._corepresentation_aware_maximum_subspace_result(
            plain_representation_changing_selection,
            collect(1:4),
            Int[],
            2,
            accepted_corepresentation[1],
            little_group_representation,
            little_group_plan,
            1,
            [1, 2],
            1.0e-12,
            1.0e8,
        )
    @test constrained_representation_selection.success
    @test constrained_representation_selection.selection_method ==
          :corepresentation_constrained_eigenspace
    @test constrained_representation_selection.combination_count == 2
    @test constrained_representation_selection.selected_eigenvector_indices == [1, 3]
    @test constrained_representation_selection.frame * constrained_representation_selection.frame' ≈
          Diagonal(ComplexF64[1, 1, 0, 0]) atol = 1.0e-14 rtol = 0.0
    @test WANNIERIZATION._maximum_target_frame_symmetry_error(
        [constrained_representation_selection.frame],
        little_group_representation,
        little_group_plan,
    ) <= 1.0e-14
    orthogonal_equivalent_subspace = [ComplexF64[0 0; 0 0; 1 0; 0 1]]
    completed_corepresentation_transport =
        WANNIERIZATION._transport_selected_subspace_corepresentation(
            orthogonal_equivalent_subspace,
            accepted_corepresentation,
            little_group_representation,
            little_group_plan,
            1.0e-12,
            1.0e8,
            1.0e-12,
        )
    @test completed_corepresentation_transport.success
    @test completed_corepresentation_transport.completion_count == 2
    @test completed_corepresentation_transport.minimum_singular_value == 0.0
    @test completed_corepresentation_transport.projector_drift <= 1.0e-14
    @test completed_corepresentation_transport.maximum_local_isometry_residual <= 1.0e-14
    @test completed_corepresentation_transport.maximum_local_projector_drift <= 1.0e-14
    @test completed_corepresentation_transport.target_symmetry <= 1.0e-14
    @test completed_corepresentation_transport.frames[1] *
          completed_corepresentation_transport.frames[1]' ≈
          orthogonal_equivalent_subspace[1] * orthogonal_equivalent_subspace[1]' atol = 1.0e-14 rtol =
        0.0
    trivial_sewing = reshape(Matrix{ComplexF64}(I, 4, 4), 4, 4, 1, 1)
    trivial_representation = WannierNLQG.SymmetryFoundation.BandRepresentation(
        "1.15",
        :synthetic,
        false,
        Matrix{Float64}(I, 3, 3),
        2.0pi .* Matrix{Float64}(I, 3, 3),
        (1, 1, 1),
        zeros(1, 3),
        zeros(4, 1),
        [identity_operation],
        reshape([1], 1, 1),
        zeros(Int, 3, 1, 1),
        trivial_sewing,
        reshape(collect(1:4), 4, 1),
        [1],
        [1],
        [1],
    )
    trivial_plan = WannierNLQG.SymmetryFoundation.WannierSymmetryPlan(
        [identity_operation],
        reshape(Matrix{ComplexF64}(I, 2, 2), 2, 2, 1),
        zeros(Int, 3, 2, 1),
    )
    mixed_selected_subspace =
        [ComplexF64[inv(sqrt(2)) inv(sqrt(2)); 0 0; inv(sqrt(2)) -inv(sqrt(2)); 0 0]]
    partial_corepresentation_transport =
        WANNIERIZATION._transport_selected_subspace_corepresentation(
            mixed_selected_subspace,
            accepted_corepresentation,
            trivial_representation,
            trivial_plan,
            1.0e-12,
            1.0e8,
            1.0e-12,
        )
    @test partial_corepresentation_transport.success
    @test partial_corepresentation_transport.completion_count == 1
    @test partial_corepresentation_transport.projector_drift <= 1.0e-14
    @test partial_corepresentation_transport.maximum_local_isometry_residual <= 1.0e-14
    @test partial_corepresentation_transport.maximum_local_projector_drift <= 1.0e-14
    @test partial_corepresentation_transport.frames[1] *
          partial_corepresentation_transport.frames[1]' ≈
          mixed_selected_subspace[1] * mixed_selected_subspace[1]' atol = 1.0e-14 rtol = 0.0
    wrong_irrep_subspace = [ComplexF64[1 0; 0 0; 0 1; 0 0]]
    rejected_corepresentation_transport =
        WANNIERIZATION._transport_selected_subspace_corepresentation(
            wrong_irrep_subspace,
            accepted_corepresentation,
            little_group_representation,
            little_group_plan,
            1.0e-12,
            1.0e8,
            1.0e-12,
        )
    @test !rejected_corepresentation_transport.success
    @test rejected_corepresentation_transport.code == :SUBSPACE_COREPRESENTATION_MISMATCH
    @test rejected_corepresentation_transport.kpoint == 1
    representative_z = WANNIERIZATION._raw_z_field(
        star_representation,
        star_mmn,
        [1.0],
        [[1, 2], [1, 2]],
        star_frames,
        :serial,
    )
    full_z = WANNIERIZATION._raw_z_field(
        star_representation,
        star_mmn,
        [1.0],
        [[1, 2], [1, 2]],
        star_frames,
        :serial;
        full_bz = true,
    )
    contiguous_z = WANNIERIZATION._raw_z_field(
        star_representation,
        star_mmn,
        [1.0],
        [[1, 2], [1, 2]],
        star_frames,
        :serial;
        full_bz = true,
        storage_backend = :contiguous,
    )
    @test iszero(representative_z[2])
    @test !iszero(full_z[2])
    @test maximum(maximum(abs, contiguous_z[kpoint] - full_z[kpoint]) for kpoint in 1:2) <= 1.0e-12

    outer = [[1, 2], [1, 2]]
    frozen = [[1], [1]]
    raw_amn = zeros(ComplexF64, 2, 1, 2)
    raw_amn[1, 1, :] .= 1.0
    raw_amn[2, 1, :] .= 0.25
    type3_reference = WANNIERIZATION._raw_amn_localization_reference(
        raw_amn,
        fixture.representation,
        fixture.plan,
        true,
        outer,
        frozen,
    )
    @test type3_reference.success
    @test type3_reference.algorithm == :type3_symmetry_compatible_raw_amn_projection
    @test maximum(
        WANNIERIZATION._candidate_invariant_residuals(
            type3_reference.frames,
            frozen,
            fixture.representation,
        ),
    ) <= 1.0e-12
    ordinary_reference = WANNIERIZATION._raw_amn_localization_reference(
        raw_amn,
        fixture.representation,
        fixture.plan,
        false,
        outer,
        frozen,
    )
    @test ordinary_reference.success
    @test ordinary_reference.algorithm == :raw_amn
    @test ordinary_reference.frames == [Matrix(@view(raw_amn[:, :, k])) for k in 1:2]

    first_frames = WANNIERIZATION._initial_frames(
        fixture.config,
        fixture.representation,
        outer,
        frozen,
        1,
        nothing,
        nothing,
    )
    second_frames = WANNIERIZATION._initial_frames(
        fixture.config,
        fixture.representation,
        outer,
        frozen,
        1,
        nothing,
        nothing,
    )
    @test first_frames == second_frames
    @test all(frame -> frame' * frame ≈ ones(ComplexF64, 1, 1), first_frames)
end

@testset "Symmetry-free full-BZ Wannierization contracts" begin
    fixture = synthetic_wannierization_fixture()
    no_symmetry_config = modified_wannierization_config(
        fixture.config;
        wannierization_mode = :ordinary,
        algorithm_profile = :custom,
        band_representation = nothing,
        initialization = :random,
        symmetrize_z = true,
    )
    @test WANNIERIZATION._validate_wannierization_config(no_symmetry_config) === nothing
    explicit_ordinary_config =
        modified_wannierization_config(no_symmetry_config; wannierization_mode = :ordinary)
    @test WANNIERIZATION._validate_wannierization_config(explicit_ordinary_config) === nothing
    @test WANNIERIZATION._effective_wannierization_mode(explicit_ordinary_config) == :ordinary
    @test !WANNIERIZATION._symmetry_constraints_applied(explicit_ordinary_config)
    @test WANNIERIZATION._restart_config_sha256(explicit_ordinary_config) ==
          WANNIERIZATION._restart_config_sha256(no_symmetry_config)
    @test_throws ArgumentError WANNIERIZATION._validate_wannierization_config(
        modified_wannierization_config(fixture.config; wannierization_mode = :ordinary),
    )
    @test_throws ArgumentError WANNIERIZATION._validate_wannierization_config(
        modified_wannierization_config(no_symmetry_config; wannierization_mode = :symmetry_adapted),
    )
    augmentation_ordinary_config = modified_wannierization_config(
        explicit_ordinary_config;
        sewing_backend = WANNIERIZATION.AugmentationAwareSewing(),
    )
    @test WANNIERIZATION._validate_wannierization_config(augmentation_ordinary_config) === nothing
    @test WANNIERIZATION._validate_wannierization_config(
        modified_wannierization_config(
            no_symmetry_config;
            band_representation_hdf5 = "identity.schema-1.4.h5",
        ),
    ) === nothing
    @test_throws UndefKeywordError WANNIERIZATION.SymmetryAdaptedWannierizationConfig(
        symmetry_mode = :none,
        win_file = "x.win",
        eig_file = "x.eig",
        mmn_file = "x.mmn",
    )
    @test_throws ArgumentError WANNIERIZATION._validate_wannierization_config(
        modified_wannierization_config(
            no_symmetry_config;
            wannierization_mode = :ordinary_no_symmetry,
        ),
    )
    removed_algorithm_tag = modified_wannierization_config(
        no_symmetry_config;
        acceleration = WANNIERIZATION.WannierizationAccelerationConfig(
            disentanglement_algorithm = :wannier90_reference,
            localization_algorithm = :wannier90_reference,
        ),
    )
    @test_throws ArgumentError WANNIERIZATION._validate_wannierization_config(removed_algorithm_tag)
    @test_throws ArgumentError WANNIERIZATION._validate_wannierization_config(
        modified_wannierization_config(
            no_symmetry_config;
            band_representation = fixture.representation,
        ),
    )
    @test_throws ArgumentError WANNIERIZATION._validate_wannierization_config(
        modified_wannierization_config(
            fixture.config;
            wannierization_mode = :symmetry_adapted,
            band_representation = nothing,
        ),
    )
    @test_throws ArgumentError WANNIERIZATION._validate_wannierization_config(
        modified_wannierization_config(
            fixture.config;
            wannierization_mode = :symmetry_adapted,
            band_representation = nothing,
        ),
    )

    extension, _ = WANNIERIZATION._load_wannierization_extension!()
    mktempdir() do directory
        win_file = joinpath(directory, "full-bz.win")
        write(
            win_file,
            """
            mp_grid = 2 1 1
            begin unit_cell_cart
            bohr
            2.0d0 0.0 0.0
            0.0 2.0d0 0.0
            0.0 0.0 2.0d0
            end unit_cell_cart
            begin kpoints
            0.0 0.0 0.0
            0.5 0.0 0.0
            end kpoints
            """,
        )
        mesh = extension.SolverCheckpoint._read_wannierization_win_mesh(win_file)
        @test mesh.mp_grid == (2, 1, 1)
        @test mesh.kpoints_fractional == [0.0 0.0 0.0; 0.5 0.0 0.0]
        @test mesh.lattice ≈ 2.0 * 0.529177210903 .* Matrix{Float64}(I, 3, 3)

        identity_config = modified_wannierization_config(no_symmetry_config; win_file)
        identity_representation = extension.SolverCheckpoint._identity_band_representation(
            identity_config,
            fixture.basis,
            fixture.eig,
        )
        @test length(identity_representation.operations) == 1
        @test !only(identity_representation.operations).antiunitary
        @test identity_representation.irreducible_indices == [1, 2]
        @test identity_representation.full_to_irreducible == [1, 2]
        @test identity_representation.kpoint_map == reshape([1, 2], 1, 2)
        @test all(iszero, identity_representation.reciprocal_shifts)
        @test identity_representation.band_block_labels == [1 1; 2 2]
        @test all(
            kpoint ->
                identity_representation.sewing_matrices[:, :, 1, kpoint] ≈
                Matrix{ComplexF64}(I, 2, 2),
            1:2,
        )
        augmentation_identity_representation =
            extension.SolverCheckpoint._identity_band_representation(
                modified_wannierization_config(
                    identity_config;
                    wannierization_mode = :ordinary,
                    sewing_backend = WANNIERIZATION.AugmentationAwareSewing(),
                ),
                fixture.basis,
                fixture.eig,
            )
        @test augmentation_identity_representation.conventions["sewing_backend"] ==
              "augmentation_aware_paw_q0"
        @test augmentation_identity_representation.conventions["sewing_role"] ==
              "identity_only_no_symmetry"
        @test augmentation_identity_representation.conventions["augmentation_metric_role"] ==
              "ordinary_wannierization_input_metric"

        exact_frozen_config = modified_wannierization_config(
            identity_config;
            initialization = :amn,
            amn_file = "seed.amn",
            frozen_states = [(1, 1), (2, 1)],
        )
        frozen = [
            WANNIERIZATION._frozen_indices(exact_frozen_config, identity_representation, k) for
            k in 1:2
        ]
        @test frozen == [[1], [1]]

        first_amn = zeros(ComplexF64, 2, 1, 2)
        first_amn[1, 1, :] .= 1.0
        second_amn = copy(first_amn)
        second_amn[1, 1, 2] = 1.0im
        first_frames, first_diagnostics, first_invariants, first_report =
            WANNIERIZATION._initial_frames_with_diagnostics(
                exact_frozen_config,
                identity_representation,
                [[1, 2], [1, 2]],
                frozen,
                1,
                first_amn,
                nothing,
            )
        second_frames, _, _, second_report = WANNIERIZATION._initial_frames_with_diagnostics(
            exact_frozen_config,
            identity_representation,
            [[1, 2], [1, 2]],
            frozen,
            1,
            second_amn,
            nothing,
        )
        @test length(first_diagnostics) == 2
        @test first_invariants.maximum_isometry <= 1.0e-8
        @test first_report.algorithm == :amn_full_bz_exact_frozen_embedding
        @test first_report.algorithm_version == "nosym_exact_frozen_rowspace_v2"
        @test second_report.algorithm_version == first_report.algorithm_version
        # A phase-only change of a fully frozen one-dimensional AMN row does
        # not alter the exact frozen projector or its canonical frame.
        @test first_frames == second_frames
        @test all(frame -> frame * frame' ≈ ComplexF64[1 0; 0 0], first_frames)

        contract = extension.SolverCheckpoint._no_symmetry_compatibility_contract(
            identity_representation,
            1.0e-8,
        )
        @test contract.passed
        @test contract.metadata_origin == :not_applicable
        @test only(contract.diagnostics).code == :SYMMETRY_CONSTRAINTS_DISABLED
        @test WANNIERIZATION._restart_config_sha256(identity_config) !=
              WANNIERIZATION._restart_config_sha256(fixture.config)
        legacy_digest_config = WANNIERIZATION.SymmetryAdaptedWannierizationConfig(
            input = WANNIERIZATION.WannierizationInputConfig(
                construction_policy = :strict,
                wannierization_mode = :ordinary,
                win_file = "a",
                eig_file = "b",
                mmn_file = "c",
            ),
            solver = WANNIERIZATION.WannierizationSolverConfig(algorithm_profile = :custom),
            checkpoint = WANNIERIZATION.WannierizationCheckpointConfig(),
            runtime = WANNIERIZATION.WannierizationRuntimeConfig(),
            output = WANNIERIZATION.WannierizationOutputConfig(),
        )
        @test length(WANNIERIZATION._restart_config_sha256_pre_v2_6(legacy_digest_config)) == 64
        @test WANNIERIZATION._restart_config_sha256_pre_v2_7(legacy_digest_config) !=
              WANNIERIZATION._restart_config_sha256(legacy_digest_config)
        @test WANNIERIZATION._restart_config_sha256_pre_v2_6(
            modified_wannierization_config(
                legacy_digest_config;
                acceleration = WANNIERIZATION.WannierizationAccelerationConfig(
                    localization_algorithm = :riemannian_cg,
                ),
            ),
        ) === nothing
        provided_tolerance_changed =
            modified_wannierization_config(fixture.config; symmetry_tolerance = 2.0e-5)
        @test WANNIERIZATION._restart_config_sha256(provided_tolerance_changed) ==
              WANNIERIZATION._restart_config_sha256(fixture.config)
        no_symmetry_tolerance_changed =
            modified_wannierization_config(identity_config; symmetry_tolerance = 2.0e-5)
        @test WANNIERIZATION._restart_config_sha256(no_symmetry_tolerance_changed) ==
              WANNIERIZATION._restart_config_sha256(identity_config)
        detected_config = modified_wannierization_config(
            fixture.config;
            wannierization_mode = :symmetry_adapted,
            source = WannierNLQG.SymmetryFoundation.VASPWavefunctionSource("POSCAR", "WAVECAR"),
            band_representation = nothing,
            symmetry_tolerance = 1.0e-5,
        )
        detected_tolerance_changed =
            modified_wannierization_config(detected_config; symmetry_tolerance = 2.0e-5)
        @test WANNIERIZATION._restart_config_sha256(detected_tolerance_changed) !=
              WANNIERIZATION._restart_config_sha256(detected_config)

        solver_config = modified_wannierization_config(
            no_symmetry_config;
            frozen_states = [(1, 1), (2, 1)],
            max_iterations = 3,
            convergence_window = 10,
            localize = false,
        )
        identity_plan = extension.SolverCheckpoint._identity_wannier_plan(
            1,
            only(fixture.representation.operations),
        )
        solver_contract = extension.SolverCheckpoint._no_symmetry_compatibility_contract(
            fixture.representation,
            1.0e-8,
        )
        localization_entries_before = WANNIERIZATION._localization_sweep_entry_count()
        no_symmetry_result = WANNIERIZATION._solve_symmetry_adapted_wannierization(
            solver_config,
            fixture.representation,
            fixture.eig,
            fixture.mmn,
            identity_plan;
            compatibility_report = solver_contract,
        )
        @test WANNIERIZATION._localization_sweep_entry_count() == localization_entries_before
        @test no_symmetry_result.status == WANNIERIZATION.MAX_ITERATIONS
        @test no_symmetry_result.input_summary["requested_wannierization_mode"] == "ordinary"
        @test no_symmetry_result.input_summary["effective_wannierization_mode"] == "ordinary"
        @test no_symmetry_result.input_summary["representation_source"] == "identity"
        @test no_symmetry_result.input_summary["symmetry_constraints_applied"] == "false"
        @test no_symmetry_result.input_summary["effective_symmetry_operation_count"] == "1"
        @test no_symmetry_result.input_summary["effective_antiunitary_operation_count"] == "0"
        @test no_symmetry_result.input_summary["effective_symmetrize_z"] == "false"
        @test no_symmetry_result.input_summary["covariance_applicability"] == "DIAGNOSTIC_ONLY"
        @test parse(Float64, no_symmetry_result.input_summary["hard_gate_frozen"]) <= 1.0e-10
        @test all(entry -> iszero(entry.maximum_covariance_error), no_symmetry_result.history)

        # Ordinary :auto and an explicit custom SMV--FR selection execute the
        # same numerical path. Optional audit provenance, including malformed
        # input, cannot perturb the arrays or accepted iteration history.
        ordinary_auto_solver =
            modified_wannierization_config(solver_config; algorithm_profile = :auto)
        explicit_smv_fr_solver = modified_wannierization_config(
            solver_config;
            algorithm_profile = :custom,
            acceleration = WANNIERIZATION.WannierizationAccelerationConfig(
                disentanglement_algorithm = :smv_fletcher_reeves_two_stage,
                localization_algorithm = :smv_fletcher_reeves_two_stage,
            ),
        )
        ordinary_auto_result = WANNIERIZATION._solve_symmetry_adapted_wannierization(
            ordinary_auto_solver,
            fixture.representation,
            fixture.eig,
            fixture.mmn,
            identity_plan;
            compatibility_report = solver_contract,
        )
        explicit_smv_fr_result = WANNIERIZATION._solve_symmetry_adapted_wannierization(
            explicit_smv_fr_solver,
            fixture.representation,
            fixture.eig,
            fixture.mmn,
            identity_plan;
            compatibility_report = solver_contract,
        )
        @test ordinary_auto_result.v_matrix == explicit_smv_fr_result.v_matrix
        @test ordinary_auto_result.spreads_angstrom2 == explicit_smv_fr_result.spreads_angstrom2
        @test ordinary_auto_result.history == explicit_smv_fr_result.history
        @test ordinary_auto_result.input_summary["effective_algorithm_profile"] ==
              "smv_fletcher_reeves_two_stage"
        @test ordinary_auto_result.input_summary["smv_fletcher_reeves_two_stage_default_selection_reason"] ==
              "UNCONDITIONAL_ORDINARY_DEFAULT"
        @test ordinary_auto_result.input_summary["smv_fletcher_reeves_two_stage_audit_status"] ==
              "AUDIT_MANIFEST_MISSING"

        # A schema-1.15 identity group selected through the symmetry route
        # keeps the new profile provenance while executing the ordinary exact
        # SMV--FR arithmetic.  The two routes must remain value-for-value
        # identical through the solver and TB construction boundaries.
        identity_ordinary_solver = modified_wannierization_config(
            ordinary_auto_solver;
            initialization = :amn,
            amn_file = "identity-seed.amn",
            max_iterations = 8,
            convergence_window = 1,
        )
        symmetry_identity_seed = modified_wannierization_config(
            fixture.config;
            win_file,
            band_representation = identity_representation,
            frozen_states = [(1, 1), (2, 1)],
            initialization = :amn,
            amn_file = "identity-seed.amn",
            max_iterations = 8,
            convergence_window = 1,
            localize = false,
            algorithm_profile = :auto,
        )
        symmetry_identity_representation = Base.invokelatest(
            extension.WorkflowOrchestration._representation_with_mode_contract,
            identity_representation,
            symmetry_identity_seed,
        )
        symmetry_identity_config = modified_wannierization_config(
            symmetry_identity_seed;
            band_representation = symmetry_identity_representation,
        )
        identity_algorithms =
            WANNIERIZATION._effective_wannierization_algorithms(symmetry_identity_config)
        @test identity_algorithms.profile == :symmetry_projected_smv_fletcher_reeves_two_stage
        @test identity_algorithms.disentanglement == :smv_fletcher_reeves_two_stage
        @test identity_algorithms.localization == :smv_fletcher_reeves_two_stage
        @test identity_algorithms.default_selection_reason ==
              "IDENTITY_GROUP_EXACT_ORDINARY_FAST_PATH"
        @test !WANNIERIZATION._symmetry_constraints_applied(symmetry_identity_config)
        @test symmetry_identity_representation.conventions["symmetry_constraints_applied"] ==
              "false"
        @test WANNIERIZATION._validate_wannierization_config(symmetry_identity_config) === nothing
        symmetry_identity_hdf5_config = modified_wannierization_config(
            symmetry_identity_config;
            band_representation = nothing,
            band_representation_hdf5 = "synthetic-identity-representation.h5",
        )
        hdf5_identity_algorithms = WANNIERIZATION._effective_wannierization_algorithms(
            symmetry_identity_hdf5_config,
            symmetry_identity_representation,
        )
        @test hdf5_identity_algorithms == identity_algorithms
        @test !WANNIERIZATION._symmetry_constraints_applied(
            symmetry_identity_hdf5_config,
            symmetry_identity_representation,
        )
        @test WANNIERIZATION._restart_config_sha256(
            symmetry_identity_hdf5_config,
            symmetry_identity_representation,
        ) == WANNIERIZATION._restart_config_sha256(
            symmetry_identity_config,
            symmetry_identity_representation,
        )
        ordinary_identity_result = WANNIERIZATION._solve_symmetry_adapted_wannierization(
            identity_ordinary_solver,
            symmetry_identity_representation,
            fixture.eig,
            fixture.mmn,
            identity_plan;
            amn = first_amn,
            compatibility_report = solver_contract,
        )
        symmetry_identity_result = WANNIERIZATION._solve_symmetry_adapted_wannierization(
            symmetry_identity_config,
            symmetry_identity_representation,
            fixture.eig,
            fixture.mmn,
            identity_plan;
            amn = first_amn,
            compatibility_report = solver_contract,
        )
        symmetry_identity_hdf5_result = WANNIERIZATION._solve_symmetry_adapted_wannierization(
            symmetry_identity_hdf5_config,
            symmetry_identity_representation,
            fixture.eig,
            fixture.mmn,
            identity_plan;
            amn = first_amn,
            compatibility_report = solver_contract,
        )
        @test ordinary_identity_result.wannier_chk !== nothing
        @test ordinary_identity_result.restart_state !== nothing
        @test symmetry_identity_result.wannier_chk !== nothing
        @test symmetry_identity_result.restart_state !== nothing
        @test symmetry_identity_hdf5_result.wannier_chk !== nothing
        @test symmetry_identity_hdf5_result.restart_state !== nothing
        @test symmetry_identity_result.status == ordinary_identity_result.status
        @test symmetry_identity_result.v_matrix == ordinary_identity_result.v_matrix
        @test symmetry_identity_result.wannier_centers_cartesian ==
              ordinary_identity_result.wannier_centers_cartesian
        @test symmetry_identity_result.spreads_angstrom2 ==
              ordinary_identity_result.spreads_angstrom2
        @test symmetry_identity_result.history == ordinary_identity_result.history
        @test symmetry_identity_hdf5_result.v_matrix == ordinary_identity_result.v_matrix
        @test symmetry_identity_hdf5_result.spreads_angstrom2 ==
              ordinary_identity_result.spreads_angstrom2
        @test symmetry_identity_hdf5_result.history == ordinary_identity_result.history
        @test symmetry_identity_result.input_summary["identity_group_exact_ordinary_fast_path"] ==
              "true"
        @test symmetry_identity_result.input_summary["symmetry_projected_smv_fr_contract"] ==
              "NOT_APPLICABLE"
        ordinary_identity_tb = WANNIERIZATION.build_wannier_tight_binding_model(
            ordinary_identity_result,
            fixture.eig,
            fixture.mmn,
        )
        symmetry_identity_tb = WANNIERIZATION.build_wannier_tight_binding_model(
            symmetry_identity_result,
            fixture.eig,
            fixture.mmn,
        )
        @test symmetry_identity_tb.r_vectors == ordinary_identity_tb.r_vectors
        @test symmetry_identity_tb.r_degeneracies == ordinary_identity_tb.r_degeneracies
        @test maximum(
            abs,
            symmetry_identity_tb.hamiltonian_r - ordinary_identity_tb.hamiltonian_r;
            init = 0.0,
        ) == 0.0
        @test maximum(
            abs,
            symmetry_identity_tb.position_r - ordinary_identity_tb.position_r;
            init = 0.0,
        ) == 0.0
        mktempdir() do audit_directory
            invalid_manifest = joinpath(audit_directory, "invalid-audit.json")
            write(invalid_manifest, "{not-json")
            invalid_audit_config = modified_wannierization_config(
                ordinary_auto_solver;
                smv_fletcher_reeves_two_stage_audit_manifest = invalid_manifest,
            )
            invalid_audit_result = WANNIERIZATION._solve_symmetry_adapted_wannierization(
                invalid_audit_config,
                fixture.representation,
                fixture.eig,
                fixture.mmn,
                identity_plan;
                compatibility_report = solver_contract,
            )
            @test invalid_audit_result.v_matrix == ordinary_auto_result.v_matrix
            @test invalid_audit_result.spreads_angstrom2 == ordinary_auto_result.spreads_angstrom2
            @test invalid_audit_result.history == ordinary_auto_result.history
            @test invalid_audit_result.input_summary["smv_fletcher_reeves_two_stage_audit_status"] ==
                  "AUDIT_MANIFEST_INVALID"
        end

        # A deliberately covariance-incompatible representation must remain a
        # diagnostic only under the explicit ordinary route, while the same
        # candidate is rejected by the symmetry-adapted route.
        fixture.representation.sewing_matrices[:, :, 1, 1] .= ComplexF64[0 1; 1 0]
        trial_frames = [ComplexF64[1; 0;;], ComplexF64[1; 0;;]]
        ordinary_candidate = WANNIERIZATION._disentanglement_candidate(
            modified_wannierization_config(explicit_ordinary_config; band_representation = nothing),
            fixture.representation,
            fixture.mmn,
            identity_plan,
            fill(1.0 / 6.0, 6),
            [Int[], Int[]],
            trial_frames,
            zeros(1, 3),
            zeros(1),
            1.0e-12,
        )
        @test ordinary_candidate.success
        symmetry_candidate = WANNIERIZATION._disentanglement_candidate(
            fixture.config,
            fixture.representation,
            fixture.mmn,
            fixture.plan,
            fill(1.0 / 6.0, 6),
            [Int[], Int[]],
            trial_frames,
            zeros(1, 3),
            zeros(1),
            1.0e-12,
        )
        @test !symmetry_candidate.success
        @test symmetry_candidate.code == :SOLVER_TRIAL_COVARIANCE_FAILED
        fixture.representation.sewing_matrices[:, :, 1, 1] .= Matrix{ComplexF64}(I, 2, 2)

        cross_mode_config = modified_wannierization_config(
            fixture.config;
            initialization = :restart,
            restart_hdf5 = "cross-mode.wannierization.h5",
            max_iterations = 4,
        )
        cross_mode_result = WANNIERIZATION._solve_symmetry_adapted_wannierization(
            cross_mode_config,
            fixture.representation,
            fixture.eig,
            fixture.mmn,
            fixture.plan;
            restart = no_symmetry_result.v_matrix,
            restart_state = no_symmetry_result.restart_state,
            restart_history = no_symmetry_result.history,
            restart_input_summary = no_symmetry_result.input_summary,
        )
        @test cross_mode_result.status == WANNIERIZATION.INVALID_INPUT
        @test any(
            diagnostic -> diagnostic.code == :RESTART_EFFECTIVE_PROFILE_MISMATCH,
            cross_mode_result.diagnostics,
        )
    end
end

@testset "Wannierization output intervals do not alter numerics" begin
    fixture = synthetic_wannierization_fixture()
    default_result = WANNIERIZATION._solve_symmetry_adapted_wannierization(
        fixture.config,
        fixture.representation,
        fixture.eig,
        fixture.mmn,
        fixture.plan,
    )
    observed_summaries = Any[]
    interval_result = WANNIERIZATION._solve_symmetry_adapted_wannierization(
        modified_wannierization_config(
            fixture.config;
            progress_interval = 50,
            checkpoint_interval = 50,
        ),
        fixture.representation,
        fixture.eig,
        fixture.mmn,
        fixture.plan;
        observer = (summary, _state, _history, _diagnostics) ->
            push!(observed_summaries, summary),
    )
    @test interval_result.v_matrix == default_result.v_matrix
    @test interval_result.wannier_centers_cartesian == default_result.wannier_centers_cartesian
    @test interval_result.spreads_angstrom2 == default_result.spreads_angstrom2
    @test interval_result.history == default_result.history
    @test length(observed_summaries) == length(interval_result.history)
    @test all(
        summary -> all(
            name -> hasproperty(summary, name),
            (
                :disentanglement_convergence,
                :z_seal_class,
                :qualified_z_seal,
                :route_selection_eligible,
                :localization_convergence,
                :localization_qualification,
                :model_qualification,
            ),
        ),
        observed_summaries,
    )
    @test all(entry -> entry.diagnostics !== nothing, default_result.history)
    @test all(
        entry ->
            entry.diagnostics.omega_directional === nothing ||
            abs(sum(entry.diagnostics.omega_directional) - entry.spread_total) <= 1.0e-10,
        default_result.history,
    )
end

@testset "Wannierization opt-in acceleration controls" begin
    fixture = synthetic_wannierization_fixture()
    @test_throws ArgumentError WANNIERIZATION._validate_wannierization_config(
        modified_wannierization_config(
            fixture.config;
            acceleration = WANNIERIZATION.WannierizationAccelerationConfig(strategy = :unknown),
        ),
    )
    safeguard = WANNIERIZATION.WannierizationAccelerationConfig()
    @test safeguard.disentanglement_limit_policy == :diagnostic_continue
    @test safeguard.joint_z_backtracking_factor == 0.5
    @test safeguard.joint_z_backtracking_max_steps == 12
    @test safeguard.u_phase_branch_tolerance == 1.0e-6
    @test safeguard.u_branch_active_set_max_orbits == 64
    @test safeguard.u_lbfgs_history == 8
    @test safeguard.u_lbfgs_curvature_tolerance == 1.0e-12
    @test safeguard.u_wolfe_c2 == 0.9
    @test safeguard.u_line_search_max_trials == 24
    @test safeguard.disentanglement_algorithm == :smv_fixed_point
    @test safeguard.subspace_gauge_policy == :boundary_cluster_procrustes
    @test safeguard.u_w90_restart_interval == 5
    @test safeguard.u_w90_trial_step == 2.0
    @test safeguard.trust_radius_initial == 0.25
    @test safeguard.trust_radius_maximum == 1.0
    @test safeguard.hot_storage_backend == :legacy_vector
    @test WANNIERIZATION.WannierizationMultiStartConfig().start_index == 1
    @test WANNIERIZATION.WannierizationMultiStartConfig(
        enabled = true,
        starts = 4,
        start_index = 4,
    ).start_index == 4
    @test_throws ArgumentError WANNIERIZATION.WannierizationMultiStartConfig(
        enabled = true,
        starts = 4,
        start_index = 5,
    )
    @test_throws ArgumentError WANNIERIZATION._validate_wannierization_config(
        modified_wannierization_config(
            fixture.config;
            initialization_backend = WANNIERIZATION.PAWSCDMInitialization(),
        ),
    )
    projectability_config = modified_wannierization_config(
        fixture.config;
        amn_file = "synthetic.amn",
        initialization_backend = WANNIERIZATION.ProjectabilityDisentanglementInitialization(),
    )
    WANNIERIZATION._validate_wannierization_config(projectability_config)
    bad_projectability_amn = fill(ComplexF64(0.5), 2, 1, 2)
    bad_projectability_result = WANNIERIZATION._solve_symmetry_adapted_wannierization(
        projectability_config,
        fixture.representation,
        fixture.eig,
        fixture.mmn,
        fixture.plan;
        amn = bad_projectability_amn,
    )
    @test bad_projectability_result.status == WANNIERIZATION.INVALID_INPUT
    @test any(
        diagnostic -> diagnostic.code == :PROJECTABILITY_GRAM_PRECONDITION_FAILED,
        bad_projectability_result.diagnostics,
    )
    good_projectability_amn = zeros(ComplexF64, 2, 1, 2)
    good_projectability_amn[1, 1, :] .= 1.0
    good_projectability_result = WANNIERIZATION._solve_symmetry_adapted_wannierization(
        projectability_config,
        fixture.representation,
        fixture.eig,
        fixture.mmn,
        fixture.plan;
        amn = good_projectability_amn,
    )
    @test get(
        good_projectability_result.input_summary,
        "projectability_trial_projector_gram_residual",
        "missing",
    ) == "0.0"
    @test WANNIERIZATION._localization_backtracking_limit(safeguard, :gradient) == 23
    @test WANNIERIZATION._localization_backtracking_limit(safeguard, :polar) == 12
    @test WANNIERIZATION._localization_backtracking_limit(
        WANNIERIZATION.WannierizationAccelerationConfig(
            u_acceptance = :armijo,
            u_backtracking_max_steps = 0,
            u_line_search_max_trials = 5,
        ),
        :gradient,
    ) == 4
    @test WANNIERIZATION._localization_backtracking_limit(
        WANNIERIZATION.WannierizationAccelerationConfig(
            u_acceptance = :monotone,
            u_backtracking_max_steps = 7,
            u_line_search_max_trials = 5,
        ),
        :gradient,
    ) == 7
    @test WANNIERIZATION.WannierizationAccelerationConfig(
        localization_algorithm = :riemannian_lbfgs,
        u_acceptance = :strong_wolfe,
    ).localization_algorithm == :riemannian_lbfgs
    reference_step = WANNIERIZATION._wannier90_reference_optimal_step(10.0, 9.0, -2.0, 2.0)
    @test reference_step.success
    @test reference_step.quadratic
    @test reference_step.alpha == 4 / 3
    unstable_step = WANNIERIZATION._wannier90_reference_optimal_step(0.0, -1.0, -2.0, 2.0)
    @test unstable_step.success
    @test !unstable_step.quadratic
    @test unstable_step.alpha == 2.0
    generator = ComplexF64[0 1; -1 0]
    reference_unitary = WANNIERIZATION._wannier90_reference_unitary_step(
        Matrix{ComplexF64}(I, 2, 2),
        generator,
        2.0,
        3.0,
    )
    @test reference_unitary' * reference_unitary ≈ Matrix{ComplexF64}(I, 2, 2) atol = 1.0e-14
    first_reference_direction = WANNIERIZATION._wannier90_reference_search_direction(
        [generator],
        nothing,
        nothing,
        0,
        5,
        3.0,
    )
    @test first_reference_direction.success
    @test first_reference_direction.beta == 0.0
    @test first_reference_direction.cg_count == 0
    full_rank_amn = ComplexF64[2 0; 0 0.5]
    full_rank_polar = WANNIERIZATION._sealed_amn_polar(full_rank_amn, 1.0e-8, 1.0e10)
    @test full_rank_polar.success
    @test full_rank_polar.rank == 2
    @test full_rank_polar.completion_count == 0
    @test full_rank_polar.unitary ≈ Matrix{ComplexF64}(I, 2, 2) atol = 1.0e-14
    rank_deficient_amn = ComplexF64[1 0; 0 1.0e-12]
    completed_once = WANNIERIZATION._sealed_amn_polar(rank_deficient_amn, 1.0e-8, 1.0e10)
    completed_twice = WANNIERIZATION._sealed_amn_polar(rank_deficient_amn, 1.0e-8, 1.0e10)
    @test completed_once.success
    @test completed_once.rank == 1
    @test completed_once.completion_count == 1
    @test completed_once.unitary == completed_twice.unitary
    @test completed_once.unitary' * completed_once.unitary ≈ Matrix{ComplexF64}(I, 2, 2) atol =
        1.0e-14
    reference_rank_deficient = WANNIERIZATION._wannier90_reference_amn_polar(rank_deficient_amn)
    @test reference_rank_deficient.success
    @test reference_rank_deficient.rank == 2
    @test reference_rank_deficient.completion_count == 0
    @test reference_rank_deficient.singular_values == [1.0, 1.0e-12]
    @test reference_rank_deficient.unitary ≈ Matrix{ComplexF64}(I, 2, 2) atol = 1.0e-14
    @test reference_rank_deficient.unitary' * reference_rank_deficient.unitary ≈
          Matrix{ComplexF64}(I, 2, 2) atol = 1.0e-14
    @test !WANNIERIZATION._wannier90_reference_amn_polar(zeros(ComplexF64, 2, 3)).success
    packed_spectrum = WANNIERIZATION._wannier90_reference_zhpevx(ComplexF64[1 2+1im; 2-1im 3])
    @test packed_spectrum.success
    @test packed_spectrum.values ≈ [-0.449489742783178, 4.449489742783178] atol = 1.0e-14
    @test ComplexF64[1 2+1im; 2-1im 3] * packed_spectrum.vectors ≈
          packed_spectrum.vectors * Diagonal(packed_spectrum.values) atol = 2.0e-14
    reference_subspace = WANNIERIZATION._wannier90_reference_maximum_subspace_result(
        ComplexF64[4 0 0; 0 1 0; 0 0 3],
        [1, 2, 3],
        [2],
        2,
    )
    @test reference_subspace.success
    @test reference_subspace.backend == :wannier90_zhpevx
    @test reference_subspace.frame == ComplexF64[0 1; 1 0; 0 0]
    solver_root = joinpath(
        dirname(dirname(pathof(WannierNLQG))),
        "ext",
        "WannierNLQGWannierizationExt",
        "solver",
    )
    solver_source = join(
        read(joinpath(solver_root, filename), String) for filename in (
            "LinearAlgebra.jl",
            "SymmetryFrames.jl",
            "Initialization.jl",
            "Localization.jl",
            "Optimizer.jl",
            "RestartWorkflow.jl",
        )
    )
    models_root = joinpath(dirname(pathof(WannierNLQG)), "Wannierization", "models")
    models_source = join(
        read(joinpath(models_root, filename), String) for filename in (
            "ConfigurationsContracts.jl",
            "OptimizerStates.jl",
            "DiagnosticsQualification.jl",
            "ResultsArtifacts.jl",
        )
    )
    @test !occursin("WANNIERNLQG_W90_REFERENCE_GRADIENT_KERNEL", solver_source)
    @test !occursin("_wannier90_reference_external_", solver_source)
    @test !occursin("wannier90_reference_localization_frames_bin", models_source)
    @test !occursin("wannier90_reference_initial_frames_bin", models_source)
    phase_probe = ComplexF64(-0.713, 0.419)
    platform_phase = ccall(
        (:atan2, WANNIERIZATION_IMPLEMENTATION.SolverCheckpoint._WANNIER90_REFERENCE_SYSTEM_LIBM),
        Cdouble,
        (Cdouble, Cdouble),
        imag(phase_probe),
        real(phase_probe),
    )
    @test WANNIERIZATION._wannier90_reference_phase(phase_probe) === platform_phase
    complex_exponential_probe =
        WANNIERIZATION._wannier90_reference_complex_exponential(ComplexF64(0.0, 0.821883981306476))
    @test reinterpret(UInt64, real(complex_exponential_probe)) == 0x3fe5c976473dc00c
    @test reinterpret(UInt64, imag(complex_exponential_probe)) == 0x3fe77010ab45086b
    real_dominant_column_value =
        Base.inferencebarrier(ComplexF64(0.9843349227773451, 1.4100220563663763e-11))
    conjugate_product_probe = WANNIERIZATION._wannier90_reference_gfortran_column_conjugate_product(
        real_dominant_column_value,
        real_dominant_column_value,
    )
    @test reinterpret(UInt64, real(conjugate_product_probe)) == 0x3fef015a88a80889
    @test reinterpret(UInt64, imag(conjugate_product_probe)) == 0xba480d93b207bc8a
    phase_column_value = ComplexF64(-0.00041618483987089066, 0.0007580881748940868)
    phase_column_phase = WANNIERIZATION._wannier90_reference_complex_exponential(
        ComplexF64(0.0, 1.6788638613347698e-7),
    )
    phase_column_probe = WANNIERIZATION._wannier90_reference_gfortran_phase_column_product(
        phase_column_value,
        phase_column_phase,
    )
    @test reinterpret(UInt64, real(phase_column_probe)) == 0xbf3b466cd2ae0fa9
    expected_phase_column_imaginary_bits =
        Sys.ARCH === :aarch64 ? UInt64(0x3f48d74dcf2ce3c1) : UInt64(0x3f48d74dcf2ce3c0)
    @test reinterpret(UInt64, imag(phase_column_probe)) == expected_phase_column_imaginary_bits
    magnitude_squared_probe =
        WANNIERIZATION._wannier90_reference_gfortran_magnitude_squared(real_dominant_column_value)
    @test reinterpret(UInt64, magnitude_squared_probe) == 0x3fef015a88a80889
    scalar_magnitude_probe = WANNIERIZATION._wannier90_reference_gfortran_scalar_magnitude_squared(
        ComplexF64(5.976494614502479e-6, 2.2378355787923001e-7),
    )
    @test reinterpret(UInt64, scalar_magnitude_probe) == 0x3dc3a9fa704742c7
    objective_center_probe = WANNIERIZATION._wannier90_reference_objective_center_accumulate(
        Base.inferencebarrier(0.9277112815446888),
        Base.inferencebarrier(1.257800476663593),
        Base.inferencebarrier(-0.7279437274706391),
        Base.inferencebarrier(-0.5025316007125938),
    )
    gradient_center_probe = WANNIERIZATION._wannier90_reference_gradient_center_accumulate(
        Base.inferencebarrier(0.9277112815446888),
        Base.inferencebarrier(-0.7279437274706391),
        Base.inferencebarrier(1.257800476663593 * -0.5025316007125938),
    )
    @test reinterpret(UInt64, objective_center_probe) == 0x3ff634909b004b1d
    @test reinterpret(UInt64, gradient_center_probe) == 0x3ff634909b004b1e
    @test objective_center_probe != gradient_center_probe
    omega_d_probe = WANNIERIZATION._wannier90_reference_omega_d_accumulate(
        Base.inferencebarrier(-0.21766510678354617),
        Base.inferencebarrier(0.4922456865251828),
        Base.inferencebarrier(0.9809798121241488),
    )
    @test reinterpret(UInt64, omega_d_probe) == 0x3fd062da1ccb1045
    division_real_dominant_probe = WANNIERIZATION._wannier90_reference_gfortran_column_division(
        real_dominant_column_value,
        real_dominant_column_value,
    )
    @test reinterpret(UInt64, real(division_real_dominant_probe)) == 0x3ff0000000000000
    @test reinterpret(UInt64, imag(division_real_dominant_probe)) == 0x39fc95e2bb3b185d
    division_imaginary_dominant_probe =
        WANNIERIZATION._wannier90_reference_gfortran_column_division(
            ComplexF64(3.225987418061329e-6, -3.6406254051401294e-6),
            ComplexF64(0.08821054908604604, 0.6064330003313873),
        )
    @test reinterpret(UInt64, real(division_imaginary_dominant_probe)) == 0xbed57adb093f77da
    @test reinterpret(UInt64, imag(division_imaginary_dominant_probe)) == 0xbed96fbdb822ce94
    for acceleration in (
        WANNIERIZATION.WannierizationAccelerationConfig(disentanglement_limit_policy = :invalid),
        WANNIERIZATION.WannierizationAccelerationConfig(joint_z_backtracking_factor = 1.0),
        WANNIERIZATION.WannierizationAccelerationConfig(joint_z_backtracking_max_steps = -1),
        WANNIERIZATION.WannierizationAccelerationConfig(u_phase_branch_tolerance = 0.0),
        WANNIERIZATION.WannierizationAccelerationConfig(u_branch_active_set_max_orbits = 0),
        WANNIERIZATION.WannierizationAccelerationConfig(u_lbfgs_history = 0),
        WANNIERIZATION.WannierizationAccelerationConfig(u_lbfgs_curvature_tolerance = 0.0),
        WANNIERIZATION.WannierizationAccelerationConfig(u_wolfe_c2 = 1.0),
        WANNIERIZATION.WannierizationAccelerationConfig(u_line_search_max_trials = 0),
        WANNIERIZATION.WannierizationAccelerationConfig(disentanglement_algorithm = :invalid),
        WANNIERIZATION.WannierizationAccelerationConfig(subspace_gauge_policy = :invalid),
        WANNIERIZATION.WannierizationAccelerationConfig(u_w90_restart_interval = 0),
        WANNIERIZATION.WannierizationAccelerationConfig(u_w90_trial_step = 0.0),
        WANNIERIZATION.WannierizationAccelerationConfig(trust_radius_initial = 2.0),
        WANNIERIZATION.WannierizationAccelerationConfig(hot_storage_backend = :invalid),
    )
        @test_throws ArgumentError WANNIERIZATION._validate_wannierization_config(
            modified_wannierization_config(fixture.config; acceleration),
        )
    end
    @test WANNIERIZATION._acceleration_trial_action(:adaptive, 1, nothing) == :accept
    @test WANNIERIZATION._acceleration_trial_action(
        :anderson_z,
        1,
        (:NONFINITE_SOLVER_TRIAL, Inf),
    ) == :retry_safe_linear
    @test WANNIERIZATION._acceleration_trial_action(:adaptive, 2, nothing) == :accept
    @test WANNIERIZATION._acceleration_trial_action(
        :adaptive,
        2,
        (:SOLVER_TRIAL_ISOMETRY_FAILED, 1.0e-6),
    ) == :typed_failure
    @test WANNIERIZATION._acceleration_trial_action(
        :fixed,
        1,
        (:SOLVER_TRIAL_ISOMETRY_FAILED, 1.0e-6),
    ) == :typed_failure
    broken_frames = [reshape(ComplexF64[2.0, 0.0], 2, 1) for _ in 1:2]
    fixed_failure = WANNIERIZATION._candidate_invariant_failure(
        broken_frames,
        zeros(1, 3),
        zeros(1),
        [Int[], Int[]],
        fixture.representation,
        fixture.plan,
        1.0e-10,
        1.0e-3,
    )
    @test first(fixed_failure) == :SOLVER_TRIAL_ISOMETRY_FAILED
    @test WANNIERIZATION._acceleration_trial_action(:fixed, 1, fixed_failure) == :typed_failure
    @test WANNIERIZATION._shrunken_acceleration_mixing(0.5, 1.0, safeguard) == (0.25, 0.5)
    @test WANNIERIZATION._adaptive_next_mixing(0.5, 1.0, 2, 1.0, 0.8, safeguard) == (0.575, 1.0, 0)
    @test WANNIERIZATION._adaptive_next_mixing(0.5, 1.0, 0, 1.0, 1.1, safeguard) == (0.25, 0.5, 0)
    @test WANNIERIZATION._adaptive_next_mixing(0.5, 1.0, 1, 1.0, 1.02, safeguard) == (0.5, 1.0, 0)
    @test WANNIERIZATION._adaptive_next_mixing(0.5, 1.0, 2, NaN, 0.8, safeguard) == (0.5, 1.0, 0)
    @test WANNIERIZATION._anderson_trial_policy(:anderson_z, 1, 6, 6, true, 5.0e-10, 1.0e-10) ==
          (false, true)
    @test WANNIERIZATION._anderson_trial_policy(:anderson_z, 1, 6, 6, true, 2.0e-9, 1.0e-10) ==
          (true, false)

    scalar_field(value) = [reshape(ComplexF64[value], 1, 1)]
    accepted_proposal = WANNIERIZATION._anderson_z_proposal(
        scalar_field(2.0),
        scalar_field(1.0),
        scalar_field(1.5),
        [[1]],
        [1],
        reshape([0.0], 1, 1),
        reshape([6.0], 1, 1),
        WANNIERIZATION.WannierizationAccelerationConfig(
            strategy = :anderson_z,
            anderson_regularization = 0.0,
        ),
    )
    @test accepted_proposal.available
    @test accepted_proposal.reason == :PROPOSAL_AVAILABLE
    @test accepted_proposal.proposal[1][1, 1] ≈ 2.4 atol = 1.0e-14
    rejected_proposal = WANNIERIZATION._anderson_z_proposal(
        scalar_field(2.0),
        scalar_field(1.0),
        scalar_field(1.5),
        [[1]],
        [1],
        reshape([0.0], 1, 1),
        reshape([1.0 + 1.0e-12], 1, 1),
        WANNIERIZATION.WannierizationAccelerationConfig(
            strategy = :anderson_z,
            anderson_regularization = 0.0,
        ),
    )
    @test !rejected_proposal.available
    @test rejected_proposal.reason == :COEFFICIENT_NORM_EXCEEDED
    @test rejected_proposal.proposal == scalar_field(1.5)

    rcg_controls =
        WANNIERIZATION.WannierizationAccelerationConfig(localization_algorithm = :riemannian_cg)
    @test rcg_controls.u_cg_restart_interval == 20
    @test rcg_controls.u_cg_beta_cap == 10.0
    @test rcg_controls.u_cg_minimum_descent_cosine == 1.0e-3
    accepted_safeguard = WANNIERIZATION._objective_aware_anderson_decision(
        2.0,
        1.9,
        0.2,
        0.2,
        0.3,
        0.3,
        rcg_controls,
    )
    @test accepted_safeguard.accepted
    @test accepted_safeguard.reason == :OBJECTIVE_SAFEGUARD_ACCEPTED
    @test WANNIERIZATION._objective_aware_anderson_decision(
        2.0,
        2.0,
        0.2,
        0.2,
        0.3,
        0.3,
        rcg_controls,
    ).reason == :OBJECTIVE_NOT_IMPROVED
    @test WANNIERIZATION._objective_aware_anderson_decision(
        2.0,
        1.9,
        0.2,
        0.3,
        0.3,
        0.3,
        rcg_controls,
    ).reason == :PROJECTOR_RESIDUAL_WORSENED
    @test WANNIERIZATION._objective_aware_anderson_decision(
        2.0,
        1.9,
        0.2,
        0.2,
        0.3,
        0.4,
        rcg_controls,
    ).reason == :Z_RESIDUAL_WORSENED

    boundary_field = [Matrix(Diagonal(ComplexF64[3.0, 2.0, 1.0]))]
    @test WANNIERIZATION._minimum_z_boundary_gap(boundary_field, [[1, 2, 3]], [1], 2) ≈ 1.0 atol =
        1.0e-14

    fixed_multi = modified_wannierization_config(
        fixture.config;
        max_iterations = 5,
        convergence_window = 20,
        localize = false,
        acceleration = WANNIERIZATION.WannierizationAccelerationConfig(
            strategy = :fixed,
            schedule = :joint,
            u_inner_sweeps = 2,
        ),
    )
    multi_result = WANNIERIZATION._solve_symmetry_adapted_wannierization(
        fixed_multi,
        fixture.representation,
        fixture.eig,
        fixture.mmn,
        fixture.plan,
    )
    @test multi_result.status == WANNIERIZATION.MAX_ITERATIONS
    @test all(entry -> entry.diagnostics.u_inner_sweeps <= 2, multi_result.history)
    @test all(entry -> isnan(entry.diagnostics.z_boundary_gap), multi_result.history)
    multi_start_selection = WANNIERIZATION._select_wannierization_multistart(
        [multi_result, multi_result];
        long_range_tails = [2.0, 1.0],
        elapsed_seconds = [1.0, 2.0],
    )
    @test multi_start_selection.winner_index == 2
    @test !multi_start_selection.held_out_bands_used
    perturbed_a = WANNIERIZATION._deterministic_sealed_subspace_perturbation(
        [Matrix{ComplexF64}(I, 2, 2)],
        UInt64(0x1234),
        2,
    )
    perturbed_b = WANNIERIZATION._deterministic_sealed_subspace_perturbation(
        [Matrix{ComplexF64}(I, 2, 2)],
        UInt64(0x1234),
        2,
    )
    @test perturbed_a == perturbed_b
    @test perturbed_a[1]' * perturbed_a[1] ≈ Matrix{ComplexF64}(I, 2, 2) atol = 1.0e-14
    @test WANNIERIZATION._maximum_projector_step([Matrix{ComplexF64}(I, 2, 2)], perturbed_a) <=
          1.0e-14
    @test WANNIERIZATION._fixed_subspace_projector_drift_tolerance(:riemannian_cg) == 1.0e-12
    @test WANNIERIZATION._fixed_subspace_projector_drift_tolerance(
        :smv_fletcher_reeves_two_stage,
    ) == 1.0e-10
    @test 1.2533349271546236e-12 <=
          WANNIERIZATION._fixed_subspace_projector_drift_tolerance(:smv_fletcher_reeves_two_stage)
    @test 1.2533349271546236e-12 >
          WANNIERIZATION._fixed_subspace_projector_drift_tolerance(:riemannian_cg)

    trust_region = modified_wannierization_config(
        fixture.config;
        algorithm_profile = :custom,
        max_iterations = 4,
        convergence_window = 20,
        localize = false,
        acceleration = WANNIERIZATION.WannierizationAccelerationConfig(
            strategy = :fixed,
            schedule = :two_stage,
            disentanglement_algorithm = :grassmann_trust_region,
            z_stability_window = 20,
        ),
    )
    trust_result = WANNIERIZATION._solve_symmetry_adapted_wannierization(
        trust_region,
        fixture.representation,
        fixture.eig,
        fixture.mmn,
        fixture.plan,
    )
    @test trust_result.status == WANNIERIZATION.MAX_ITERATIONS
    @test haskey(trust_result.input_summary, "grassmann_trust_radius_history")
    @test haskey(trust_result.input_summary, "grassmann_acceptance_ratio_history")
    @test all(
        isfinite,
        parse.(
            Float64,
            split(trust_result.input_summary["grassmann_projector_change_history"], ','),
        ),
    )

    adaptive = modified_wannierization_config(
        fixture.config;
        max_iterations = 6,
        convergence_window = 20,
        localize = false,
        acceleration = WANNIERIZATION.WannierizationAccelerationConfig(
            strategy = :adaptive,
            schedule = :joint,
            adaptive_patience = 2,
        ),
    )
    adaptive_merits = Float64[]
    adaptive_result = WANNIERIZATION._solve_symmetry_adapted_wannierization(
        adaptive,
        fixture.representation,
        fixture.eig,
        fixture.mmn,
        fixture.plan;
        observer = (snapshot, _, _, _) ->
            push!(adaptive_merits, snapshot.normalized_residual_merit),
    )
    @test adaptive_result.status == WANNIERIZATION.MAX_ITERATIONS
    @test all(entry -> entry.diagnostics !== nothing, adaptive_result.history)
    @test length(adaptive_result.history) == 6
    @test length(adaptive_merits) == 6
    @test all(isfinite, adaptive_merits)
    @test all(entry -> entry.diagnostics.rejected_steps == 0, adaptive_result.history)
    @test all(entry -> isnan(entry.diagnostics.z_boundary_gap), adaptive_result.history)
    @test adaptive_result.restart_state.optimizer_state.strategy == :adaptive
    @test adaptive_result.input_summary["standard_tb_export_eligible"] == "false"
    @test adaptive_result.restart_state.optimizer_state.u_stability_count == 0
    @test all(
        entry -> entry.diagnostics.joint_acceptance_reason in
        (:JOINT_ACCEPTED, :JOINT_ACCEPTED_AFTER_Z_BACKTRACKING),
        adaptive_result.history,
    )
    @test all(
        entry -> entry.diagnostics.joint_transport_minimum_singular_value > 0.0,
        adaptive_result.history,
    )
    @test !haskey(adaptive_result.input_summary, "raw_amn_alignment_minimum_singular_value")
    @test !haskey(adaptive_result.input_summary, "localization_initial_frame_sha256")

    anderson = modified_wannierization_config(
        fixture.config;
        max_iterations = 6,
        convergence_window = 20,
        localize = false,
        acceleration = WANNIERIZATION.WannierizationAccelerationConfig(
            strategy = :anderson_z,
            schedule = :joint,
            anderson_start_iteration = 2,
            anderson_depth = 3,
        ),
    )
    anderson_result = WANNIERIZATION._solve_symmetry_adapted_wannierization(
        anderson,
        fixture.representation,
        fixture.eig,
        fixture.mmn,
        fixture.plan,
    )
    @test anderson_result.status == WANNIERIZATION.MAX_ITERATIONS
    @test anderson_result.restart_state.optimizer_state.strategy == :anderson_z
    @test size(anderson_result.restart_state.optimizer_state.anderson_z_history, 2) <= 3
    @test any(
        entry -> entry.diagnostics.anderson_used || entry.diagnostics.anderson_fallback,
        anderson_result.history,
    )

    for strategy in (:adaptive, :anderson_z)
        acceleration = WANNIERIZATION.WannierizationAccelerationConfig(
            strategy = strategy,
            schedule = :joint,
            anderson_start_iteration = 2,
            anderson_depth = 3,
        )
        config = modified_wannierization_config(
            fixture.config;
            max_iterations = 6,
            convergence_window = 20,
            localize = false,
            acceleration,
        )
        uninterrupted = WANNIERIZATION._solve_symmetry_adapted_wannierization(
            config,
            fixture.representation,
            fixture.eig,
            fixture.mmn,
            fixture.plan,
        )
        saved_state = Ref{Union{Nothing, WANNIERIZATION.WannierizationRestartState}}(nothing)
        saved_history = Ref(WANNIERIZATION.WannierizationIteration[])
        observer = function (snapshot, state, history, _)
            snapshot.iteration == 3 || return nothing
            saved_state[] = state
            saved_history[] = copy(history)
            throw(InterruptException())
        end
        interrupted = WANNIERIZATION._solve_symmetry_adapted_wannierization(
            config,
            fixture.representation,
            fixture.eig,
            fixture.mmn,
            fixture.plan;
            observer,
        )
        @test interrupted.status == WANNIERIZATION.IO_FAILURE
        @test any(
            diagnostic -> diagnostic.code == :ITERATION_OBSERVER_PERSISTENCE_FAILED,
            interrupted.diagnostics,
        )
        resumed = WANNIERIZATION._solve_symmetry_adapted_wannierization(
            config,
            fixture.representation,
            fixture.eig,
            fixture.mmn,
            fixture.plan;
            restart = something(saved_state[]).frames,
            restart_state = something(saved_state[]),
            restart_history = saved_history[],
        )
        @test resumed.v_matrix == uninterrupted.v_matrix
        @test resumed.wannier_centers_cartesian == uninterrupted.wannier_centers_cartesian
        @test resumed.spreads_angstrom2 == uninterrupted.spreads_angstrom2
        @test resumed.history == uninterrupted.history
    end
end

@testset "Wannierization exact restart state" begin
    fixture = synthetic_wannierization_fixture()
    config = WANNIERIZATION._replace_wannierization_config(
        fixture.config;
        solver = (max_iterations = 2, localize = false),
    )
    uninterrupted = WANNIERIZATION._solve_symmetry_adapted_wannierization(
        config,
        fixture.representation,
        fixture.eig,
        fixture.mmn,
        fixture.plan,
    )
    saved_state = Ref{Union{Nothing, WANNIERIZATION.WannierizationRestartState}}(nothing)
    saved_history = Ref(WANNIERIZATION.WannierizationIteration[])
    observer = function (_, state, history, _)
        saved_state[] = state
        saved_history[] = copy(history)
        throw(InterruptException())
    end
    interrupted = WANNIERIZATION._solve_symmetry_adapted_wannierization(
        config,
        fixture.representation,
        fixture.eig,
        fixture.mmn,
        fixture.plan;
        observer,
    )
    @test interrupted.status == WANNIERIZATION.IO_FAILURE
    @test any(
        diagnostic -> diagnostic.code == :ITERATION_OBSERVER_PERSISTENCE_FAILED,
        interrupted.diagnostics,
    )
    resumed = WANNIERIZATION._solve_symmetry_adapted_wannierization(
        config,
        fixture.representation,
        fixture.eig,
        fixture.mmn,
        fixture.plan;
        restart = something(saved_state[]).frames,
        restart_state = something(saved_state[]),
        restart_history = saved_history[],
    )
    @test resumed.v_matrix == uninterrupted.v_matrix
    @test resumed.wannier_centers_cartesian == uninterrupted.wannier_centers_cartesian
    @test resumed.spreads_angstrom2 == uninterrupted.spreads_angstrom2
    @test getfield.(resumed.history, :spread_total) ==
          getfield.(uninterrupted.history, :spread_total)
end

@testset "Two-stage and joint U-acceptance state machines" begin
    fixture = synthetic_wannierization_fixture()
    legacy_schedule_error = try
        WANNIERIZATION.WannierizationAccelerationConfig(schedule = :nested)
        nothing
    catch exception
        exception
    end
    @test legacy_schedule_error isa ArgumentError
    @test occursin("UNSUPPORTED_LEGACY_SCHEDULE", sprint(showerror, legacy_schedule_error))
    legacy_parameter_error = try
        WANNIERIZATION.WannierizationAccelerationConfig(nested_z_max_steps = 8)
        nothing
    catch exception
        exception
    end
    @test legacy_parameter_error isa ArgumentError
    @test occursin("UNSUPPORTED_LEGACY_SCHEDULE", sprint(showerror, legacy_parameter_error))
    legacy_gradient_error = try
        WANNIERIZATION.WannierizationAccelerationConfig(gradient_max_steps = 2)
        nothing
    catch exception
        exception
    end
    @test legacy_gradient_error isa ArgumentError
    @test occursin("UNSUPPORTED_LEGACY_SOLVER_KEYWORD", sprint(showerror, legacy_gradient_error))

    matrix_status = Dict{Tuple{Symbol, Symbol}, WANNIERIZATION.WannierizationStatus}()
    matrix_results = Dict{Tuple{Symbol, Symbol}, WANNIERIZATION.WannierizationResult}()
    for schedule in (:two_stage, :joint), u_acceptance in (:armijo, :monotone, :invariant_only)
        phases = Symbol[]
        basepoint_residuals = Float64[]
        basepoint_frame_residuals = Float64[]
        acceleration = WANNIERIZATION.WannierizationAccelerationConfig(
            schedule = schedule,
            localization_algorithm = :symmetry_projected_gradient,
            u_acceptance = u_acceptance,
            z_projector_tolerance = 1.0e-8,
            z_stability_window = 1,
            disentanglement_objective_tolerance = 1.0e-8,
            disentanglement_max_steps = 8,
            localization_max_steps = 8,
            u_inner_tolerance = 1.0e-8,
            u_gradient_norm_tolerance = 1.0e-8,
        )
        config = modified_wannierization_config(
            fixture.config;
            algorithm_profile = :custom,
            acceleration,
            max_iterations = 8,
            convergence_tolerance = 1.0e-8,
            convergence_window = 1,
            u_mix_ratio = 1.0,
        )
        result = WANNIERIZATION._solve_symmetry_adapted_wannierization(
            config,
            fixture.representation,
            fixture.eig,
            fixture.mmn,
            fixture.plan;
            observer = function (summary, _, _, _)
                push!(phases, summary.optimizer_phase)
                if isfinite(summary.base_objective) && isfinite(summary.trial_zero_objective)
                    push!(
                        basepoint_residuals,
                        abs(summary.trial_zero_objective - summary.base_objective),
                    )
                end
                push!(basepoint_frame_residuals, summary.trial_zero_frame_residual)
            end,
        )
        matrix_status[(schedule, u_acceptance)] = result.status
        matrix_results[(schedule, u_acceptance)] = result
        @test result.status in (
            WANNIERIZATION.COMPLETED,
            WANNIERIZATION.COMPLETED_WITH_WARNINGS,
            WANNIERIZATION.MAX_ITERATIONS,
        )
        @test result.restart_state !== nothing
        @test result.input_summary["optimizer_schedule"] == String(schedule)
        @test result.input_summary["u_acceptance"] == String(u_acceptance)
        @test schedule == :joint ? (:joint in phases) : (:localization in phases)
        @test !isempty(result.restart_state.optimizer_state.disentanglement_objective_history)
        @test schedule == :joint || result.restart_state.optimizer_state.z_steps > 0
        optimizer = result.restart_state.optimizer_state
        @test length(optimizer.localization_trial_step_scales) ==
              length(optimizer.localization_trial_objectives) ==
              length(optimizer.localization_trial_required_changes) ==
              length(optimizer.localization_trial_actual_changes) ==
              length(optimizer.localization_trial_directional_derivatives) ==
              length(optimizer.localization_trial_iterations) ==
              length(optimizer.localization_trial_sweeps) ==
              length(optimizer.localization_trial_accepted)
        @test all(>(0), optimizer.localization_trial_iterations)
        @test all(>(0), optimizer.localization_trial_sweeps)
        @test any(optimizer.localization_trial_accepted)
        if u_acceptance == :armijo
            for index in eachindex(optimizer.localization_trial_accepted)
                optimizer.localization_trial_accepted[index] || continue
                required = optimizer.localization_trial_required_changes[index]
                actual = optimizer.localization_trial_actual_changes[index]
                derivative = optimizer.localization_trial_directional_derivatives[index]
                tolerance = 1.0e-12 + 1.0e-10 * max(abs(required), abs(actual), 1.0)
                @test derivative < 0.0
                @test actual <= required + tolerance
            end
        end
        @test length(optimizer.localization_projector_drift_history) ==
              length(optimizer.localization_objective_history)
        if schedule == :two_stage
            @test length(optimizer.disentanglement_objective_history) == optimizer.z_steps
            @test result.restart_state.fixed_subspace_projectors !== nothing
            @test result.restart_state.fixed_subspace_frames !== nothing
            sealed_projectors = something(result.restart_state.fixed_subspace_projectors)
            @test maximum(
                norm(
                    @view(result.v_matrix[:, :, kpoint]) * @view(result.v_matrix[:, :, kpoint])' -
                    @view(sealed_projectors[:, :, kpoint]),
                ) for kpoint in axes(result.v_matrix, 3)
            ) <= 1.0e-12
            @test isempty(optimizer.localization_projector_drift_history) ||
                  maximum(optimizer.localization_projector_drift_history) <= 1.0e-12
        end
        @test !isempty(basepoint_residuals)
        @test maximum(basepoint_residuals) <= 128eps(Float64)
        @test !isempty(basepoint_frame_residuals)
        @test maximum(basepoint_frame_residuals) == 0.0
    end
    @test length(matrix_status) == 6

    diagnostic_limit = WANNIERIZATION._solve_symmetry_adapted_wannierization(
        modified_wannierization_config(
            fixture.config;
            max_iterations = 3,
            convergence_window = 20,
            acceleration = WANNIERIZATION.WannierizationAccelerationConfig(
                schedule = :two_stage,
                disentanglement_max_steps = 1,
                disentanglement_objective_tolerance = 0.0,
                z_projector_tolerance = 1.0e-30,
                localization_max_steps = 2,
                disentanglement_limit_policy = :diagnostic_continue,
            ),
        ),
        fixture.representation,
        fixture.eig,
        fixture.mmn,
        fixture.plan,
    )
    @test diagnostic_limit.input_summary["z_seal_class"] == "DIAGNOSTIC_NONCONVERGED"
    @test diagnostic_limit.input_summary["qualified_z_seal"] == "false"
    @test diagnostic_limit.input_summary["route_selection_eligible"] == "false"
    @test diagnostic_limit.restart_state.fixed_subspace_projectors !== nothing
    @test length(diagnostic_limit.input_summary["disentanglement_state_sha256"]) == 64
    @test length(diagnostic_limit.input_summary["disentanglement_outer_mask_sha256"]) == 64
    @test length(diagnostic_limit.input_summary["disentanglement_frozen_mask_sha256"]) == 64
    @test diagnostic_limit.input_summary["disentanglement_state_converged"] == "false"
    @test diagnostic_limit.input_summary["localization_qualification"] == "DIAGNOSTIC_ONLY"
    @test diagnostic_limit.input_summary["model_qualification"] == "DIAGNOSTIC_ONLY/Z_NONCONVERGED"
    @test diagnostic_limit.input_summary["standard_tb_export_eligible"] == "false"
    @test diagnostic_limit.restart_state.optimizer_state.u_steps > 0
    @test any(
        diagnostic -> diagnostic.code == :DISENTANGLEMENT_MAX_STEPS_CONTINUED_DIAGNOSTIC,
        diagnostic_limit.diagnostics,
    )

    rank_deficient_continuation = WANNIERIZATION._qualify_nonconverged_disentanglement_state(
        [zeros(ComplexF64, 2, 1), zeros(ComplexF64, 2, 1)],
        [Matrix{ComplexF64}(I, 2, 2), Matrix{ComplexF64}(I, 2, 2)],
        zeros(1, 3),
        zeros(1),
        [[1], [1]],
        fixture.representation,
        fixture.plan,
        1.0e-10,
        1.0e-8,
        true,
    )
    @test !rank_deficient_continuation.qualified
    @test rank_deficient_continuation.failure_code == :RANK_DEFICIENT_DISENTANGLEMENT_PROJECTOR

    strict_limit = WANNIERIZATION._solve_symmetry_adapted_wannierization(
        modified_wannierization_config(
            fixture.config;
            max_iterations = 3,
            convergence_window = 20,
            acceleration = WANNIERIZATION.WannierizationAccelerationConfig(
                schedule = :two_stage,
                disentanglement_max_steps = 1,
                disentanglement_objective_tolerance = 0.0,
                z_projector_tolerance = 1.0e-30,
                localization_max_steps = 2,
                disentanglement_limit_policy = :strict_hold,
            ),
        ),
        fixture.representation,
        fixture.eig,
        fixture.mmn,
        fixture.plan,
    )
    @test strict_limit.input_summary["z_seal_class"] == "DIAGNOSTIC_NONCONVERGED"
    @test strict_limit.input_summary["qualified_z_seal"] == "false"
    @test strict_limit.input_summary["localization_qualification"] == "NOT_RUN"
    @test strict_limit.input_summary["standard_tb_export_eligible"] == "false"
    @test strict_limit.restart_state.fixed_subspace_projectors === nothing
    @test strict_limit.restart_state.optimizer_state.phase == :disentanglement
    @test any(
        diagnostic -> diagnostic.code == :DISENTANGLEMENT_MAX_STEPS_STRICT_HOLD,
        strict_limit.diagnostics,
    )

    joint_no_u = matrix_results[(:joint, :armijo)]
    @test joint_no_u.status in (
        WANNIERIZATION.COMPLETED,
        WANNIERIZATION.COMPLETED_WITH_WARNINGS,
        WANNIERIZATION.MAX_ITERATIONS,
    )
    if joint_no_u.input_summary["qualified_z_seal"] == "true"
        @test joint_no_u.restart_state.optimizer_state.z_stability_count >=
              joint_no_u.restart_state.optimizer_state.u_stability_count
    end

    joint_amn = zeros(ComplexF64, 2, 1, 2)
    joint_amn[1, 1, :] .= 1.0
    joint_from_amn = WANNIERIZATION._solve_symmetry_adapted_wannierization(
        modified_wannierization_config(
            fixture.config;
            algorithm_profile = :custom,
            initialization = :amn,
            max_iterations = 2,
            convergence_window = 20,
            acceleration = WANNIERIZATION.WannierizationAccelerationConfig(
                strategy = :adaptive,
                schedule = :joint,
            ),
        ),
        fixture.representation,
        fixture.eig,
        fixture.mmn,
        fixture.plan;
        amn = joint_amn,
    )
    @test !haskey(joint_from_amn.input_summary, "raw_amn_alignment_minimum_singular_value")
    @test all(
        entry -> entry.diagnostics.joint_transport_minimum_singular_value > 0.0,
        joint_from_amn.history,
    )

    rejected_joint = WANNIERIZATION._solve_symmetry_adapted_wannierization(
        modified_wannierization_config(
            fixture.config;
            algorithm_profile = :custom,
            frozen_min_ev = Inf,
            frozen_max_ev = -Inf,
            max_iterations = 3,
            convergence_window = 20,
            acceleration = WANNIERIZATION.WannierizationAccelerationConfig(
                strategy = :fixed,
                schedule = :joint,
                localization_algorithm = :symmetry_projected_gradient,
                u_acceptance = :armijo,
                u_initial_step = 10.0,
                u_armijo_c1 = 0.5,
                u_backtracking_max_steps = 0,
                u_line_search_max_trials = 1,
                joint_z_backtracking_max_steps = 2,
            ),
        ),
        fixture.representation,
        fixture.eig,
        fixture.mmn,
        fixture.plan,
    )
    @test rejected_joint.status == WANNIERIZATION.LOCALIZATION_FAILED
    @test any(
        diagnostic -> diagnostic.code == :SPREAD_GRADIENT_LINE_SEARCH_FAILED,
        rejected_joint.diagnostics,
    )
    @test rejected_joint.input_summary["last_attempted_iteration"] == "1"
    @test rejected_joint.input_summary["last_accepted_iteration"] == "0"
    @test rejected_joint.restart_state.iteration == 0
    @test rejected_joint.restart_state.z_previous === nothing
    @test rejected_joint.restart_state.optimizer_state.rejected_steps == 2
    @test !isempty(rejected_joint.restart_state.optimizer_state.localization_trial_step_scales)
    @test !any(rejected_joint.restart_state.optimizer_state.localization_trial_accepted)
    @test WANNIERIZATION._candidate_invariant_failure(
        [
            Matrix{ComplexF64}(@view rejected_joint.restart_state.frames[:, :, kpoint]) for
            kpoint in axes(rejected_joint.restart_state.frames, 3)
        ],
        rejected_joint.restart_state.centers_cartesian,
        rejected_joint.restart_state.spreads_angstrom2,
        [Int[], Int[]],
        fixture.representation,
        fixture.plan,
        1.0e-10,
        1.0e-3,
    ) === nothing

    rejected_rcg = WANNIERIZATION._solve_symmetry_adapted_wannierization(
        modified_wannierization_config(
            fixture.config;
            algorithm_profile = :custom,
            frozen_min_ev = Inf,
            frozen_max_ev = -Inf,
            max_iterations = 3,
            convergence_window = 20,
            acceleration = WANNIERIZATION.WannierizationAccelerationConfig(
                strategy = :fixed,
                schedule = :joint,
                localization_algorithm = :riemannian_cg,
                u_acceptance = :armijo,
                u_initial_step = 10.0,
                u_armijo_c1 = 0.5,
                u_backtracking_max_steps = 0,
                u_line_search_max_trials = 1,
            ),
        ),
        fixture.representation,
        fixture.eig,
        fixture.mmn,
        fixture.plan,
    )
    @test rejected_rcg.status == WANNIERIZATION.LOCALIZATION_FAILED
    @test rejected_rcg.restart_state.iteration == 0
    @test isempty(rejected_rcg.restart_state.optimizer_state.previous_u_gradient)
    @test isempty(rejected_rcg.restart_state.optimizer_state.previous_u_direction)
    @test rejected_rcg.restart_state.optimizer_state.u_cg_iteration == 0

    rejected_lbfgs = WANNIERIZATION._solve_symmetry_adapted_wannierization(
        modified_wannierization_config(
            fixture.config;
            algorithm_profile = :custom,
            frozen_min_ev = Inf,
            frozen_max_ev = -Inf,
            max_iterations = 3,
            convergence_window = 20,
            acceleration = WANNIERIZATION.WannierizationAccelerationConfig(
                strategy = :fixed,
                schedule = :joint,
                localization_algorithm = :riemannian_lbfgs,
                u_acceptance = :strong_wolfe,
                u_initial_step = 10.0,
                u_armijo_c1 = 0.5,
                u_line_search_max_trials = 1,
            ),
        ),
        fixture.representation,
        fixture.eig,
        fixture.mmn,
        fixture.plan,
    )
    @test rejected_lbfgs.status == WANNIERIZATION.LOCALIZATION_FAILED
    @test rejected_lbfgs.restart_state.iteration == 0
    @test isempty(rejected_lbfgs.restart_state.optimizer_state.u_lbfgs_s_history)
    @test isempty(rejected_lbfgs.restart_state.optimizer_state.u_lbfgs_y_history)
    @test isempty(rejected_lbfgs.restart_state.optimizer_state.u_lbfgs_rho_history)
    @test !any(rejected_lbfgs.restart_state.optimizer_state.localization_trial_accepted)

    accepted_rcg = WANNIERIZATION._solve_symmetry_adapted_wannierization(
        modified_wannierization_config(
            fixture.config;
            algorithm_profile = :custom,
            frozen_min_ev = Inf,
            frozen_max_ev = -Inf,
            max_iterations = 4,
            convergence_window = 20,
            acceleration = WANNIERIZATION.WannierizationAccelerationConfig(
                strategy = :fixed,
                schedule = :joint,
                localization_algorithm = :riemannian_cg,
                u_acceptance = :armijo,
            ),
        ),
        fixture.representation,
        fixture.eig,
        fixture.mmn,
        fixture.plan,
    )
    @test accepted_rcg.status == WANNIERIZATION.MAX_ITERATIONS
    @test isempty(accepted_rcg.restart_state.optimizer_state.previous_u_gradient)
    @test isempty(accepted_rcg.restart_state.optimizer_state.previous_u_direction)
    @test accepted_rcg.restart_state.optimizer_state.u_cg_iteration == 0
    @test accepted_rcg.restart_state.optimizer_state.last_cg_restart_reason == :JOINT_SUBSPACE_RESET
    @test all(
        entry ->
            entry.diagnostics.cg_restart_reason isa Symbol &&
            entry.diagnostics.maximum_kstar_gradient_index >= 0,
        accepted_rcg.history,
    )

    fixed_reference = matrix_results[(:two_stage, :armijo)]
    fixed_projectors = zeros(ComplexF64, 2, 2, 2)
    for kpoint in 1:2
        frame = @view fixed_reference.v_matrix[:, :, kpoint]
        fixed_projectors[:, :, kpoint] .= frame * frame'
    end
    fixed_mask = BitMatrix([true true; false false])
    fixed_subspace = WANNIERIZATION.WannierizationFixedSubspace(
        fixed_projectors,
        fixed_reference.v_matrix,
        fixture.representation.irreducible_indices,
        fixed_mask,
    )
    for u_acceptance in (:armijo, :monotone, :invariant_only)
        fixed_acceleration = WANNIERIZATION.WannierizationAccelerationConfig(
            schedule = :fixed_subspace,
            u_acceptance = u_acceptance,
            localization_max_steps = 8,
            u_inner_tolerance = 1.0e-8,
            u_gradient_norm_tolerance = 1.0e-8,
        )
        fixed_config = modified_wannierization_config(
            fixture.config;
            algorithm_profile = :custom,
            initialization = :fixed_subspace,
            fixed_subspace_hdf5 = "synthetic-fixed-subspace.h5",
            acceleration = fixed_acceleration,
            max_iterations = 8,
            convergence_window = 1,
        )
        fixed_result = WANNIERIZATION._solve_symmetry_adapted_wannierization(
            fixed_config,
            fixture.representation,
            fixture.eig,
            fixture.mmn,
            fixture.plan;
            fixed_subspace,
        )
        @test fixed_result.status in (
            WANNIERIZATION.COMPLETED,
            WANNIERIZATION.COMPLETED_WITH_WARNINGS,
            WANNIERIZATION.MAX_ITERATIONS,
        )
        @test fixed_result.input_summary["optimizer_schedule"] == "fixed_subspace"
        @test fixed_result.input_summary["u_acceptance"] == String(u_acceptance)
        @test fixed_result.input_summary["fixed_subspace_qualification"] ==
              "NONQUALIFIED_SOURCE_U_ONLY_DIAGNOSTIC"
        @test fixed_result.input_summary["route_selection_eligible"] == "false"
        @test fixed_result.input_summary["standard_tb_export_eligible"] == "false"
        @test fixed_result.restart_state !== nothing
        @test fixed_result.restart_state.optimizer_state.z_steps == 0
        @test !isempty(fixed_result.restart_state.optimizer_state.localization_objective_history)
    end

    fixed_smv_fr_result = WANNIERIZATION._solve_symmetry_adapted_wannierization(
        modified_wannierization_config(
            fixture.config;
            algorithm_profile = :custom,
            initialization = :fixed_subspace,
            fixed_subspace_hdf5 = "synthetic-fixed-subspace.h5",
            acceleration = WANNIERIZATION.WannierizationAccelerationConfig(
                schedule = :fixed_subspace,
                localization_algorithm = :symmetry_projected_smv_fletcher_reeves_two_stage,
                u_acceptance = :strong_wolfe,
                localization_max_steps = 8,
                u_inner_tolerance = 1.0e-8,
                u_gradient_norm_tolerance = 1.0e-8,
            ),
            max_iterations = 8,
            convergence_window = 1,
        ),
        fixture.representation,
        fixture.eig,
        fixture.mmn,
        fixture.plan;
        fixed_subspace,
    )
    @test fixed_smv_fr_result.input_summary["effective_algorithm_profile"] == "custom"
    @test fixed_smv_fr_result.input_summary["localization_algorithm"] ==
          "symmetry_projected_smv_fletcher_reeves_two_stage"
    @test fixed_smv_fr_result.input_summary["symmetry_projected_smv_fr_contract"] ==
          WANNIERIZATION_IMPLEMENTATION.SolverCheckpoint.SYMMETRY_PROJECTED_SMV_FR_CONTRACT
    @test fixed_smv_fr_result.input_summary["fixed_subspace_qualification"] ==
          "NONQUALIFIED_SOURCE_U_ONLY_DIAGNOSTIC"
    @test fixed_smv_fr_result.input_summary["standard_tb_export_eligible"] == "false"
    @test fixed_smv_fr_result.restart_state.optimizer_state.z_steps == 0
    @test !isempty(fixed_smv_fr_result.restart_state.optimizer_state.localization_objective_history)

    fixed_lbfgs_result = WANNIERIZATION._solve_symmetry_adapted_wannierization(
        modified_wannierization_config(
            fixture.config;
            algorithm_profile = :custom,
            initialization = :fixed_subspace,
            fixed_subspace_hdf5 = "synthetic-fixed-subspace.h5",
            acceleration = WANNIERIZATION.WannierizationAccelerationConfig(
                schedule = :fixed_subspace,
                localization_algorithm = :riemannian_lbfgs,
                u_acceptance = :strong_wolfe,
                localization_max_steps = 8,
                u_inner_tolerance = 1.0e-8,
                u_gradient_norm_tolerance = 1.0e-8,
            ),
            max_iterations = 8,
            convergence_window = 1,
        ),
        fixture.representation,
        fixture.eig,
        fixture.mmn,
        fixture.plan;
        fixed_subspace,
    )
    @test fixed_lbfgs_result.status in (
        WANNIERIZATION.COMPLETED,
        WANNIERIZATION.COMPLETED_WITH_WARNINGS,
        WANNIERIZATION.MAX_ITERATIONS,
    )
    @test fixed_lbfgs_result.input_summary["localization_algorithm"] == "riemannian_lbfgs"
    @test fixed_lbfgs_result.input_summary["u_acceptance"] == "strong_wolfe"
    fixed_lbfgs_state = fixed_lbfgs_result.restart_state.optimizer_state
    @test size(fixed_lbfgs_state.u_lbfgs_s_history) == size(fixed_lbfgs_state.u_lbfgs_y_history)
    @test size(fixed_lbfgs_state.u_lbfgs_s_history, 4) ==
          length(fixed_lbfgs_state.u_lbfgs_rho_history)
    @test all(
        index ->
            fixed_lbfgs_state.localization_trial_accepted[index] ?
            fixed_lbfgs_state.localization_trial_actual_changes[index] <= 0.0 : true,
        eachindex(fixed_lbfgs_state.localization_trial_accepted),
    )

    phases = Symbol[]
    acceleration = WANNIERIZATION.WannierizationAccelerationConfig(
        schedule = :two_stage,
        u_acceptance = :armijo,
        z_projector_tolerance = 1.0e-8,
        z_stability_window = 1,
        disentanglement_objective_tolerance = 1.0e-8,
        disentanglement_max_steps = 8,
        localization_max_steps = 20,
        u_inner_tolerance = 1.0e-8,
        u_gradient_norm_tolerance = 1.0e-8,
    )
    config = modified_wannierization_config(
        fixture.config;
        algorithm_profile = :custom,
        acceleration,
        max_iterations = 8,
        convergence_tolerance = 1.0e-8,
        convergence_window = 1,
        u_mix_ratio = 1.0,
    )
    result = WANNIERIZATION._solve_symmetry_adapted_wannierization(
        config,
        fixture.representation,
        fixture.eig,
        fixture.mmn,
        fixture.plan;
        observer = (summary, _, _, _) -> push!(phases, summary.optimizer_phase),
    )
    @test :localization in phases
    @test result.restart_state !== nothing
    @test result.restart_state.optimizer_state.z_steps > 0
    @test !isempty(result.restart_state.optimizer_state.disentanglement_objective_history)
    @test !isempty(result.restart_state.optimizer_state.localization_objective_history)
    @test result.status in (
        WANNIERIZATION.COMPLETED,
        WANNIERIZATION.COMPLETED_WITH_WARNINGS,
        WANNIERIZATION.MAX_ITERATIONS,
    )

    continuation_config =
        modified_wannierization_config(config; max_iterations = 6, convergence_window = 20)
    uninterrupted = WANNIERIZATION._solve_symmetry_adapted_wannierization(
        continuation_config,
        fixture.representation,
        fixture.eig,
        fixture.mmn,
        fixture.plan,
    )
    partial = WANNIERIZATION._solve_symmetry_adapted_wannierization(
        modified_wannierization_config(continuation_config; max_iterations = 3),
        fixture.representation,
        fixture.eig,
        fixture.mmn,
        fixture.plan,
    )
    resumed = WANNIERIZATION._solve_symmetry_adapted_wannierization(
        continuation_config,
        fixture.representation,
        fixture.eig,
        fixture.mmn,
        fixture.plan;
        restart = partial.v_matrix,
        restart_state = partial.restart_state,
        restart_history = partial.history,
    )
    @test resumed.v_matrix == uninterrupted.v_matrix
    @test resumed.wannier_centers_cartesian == uninterrupted.wannier_centers_cartesian
    @test resumed.spreads_angstrom2 == uninterrupted.spreads_angstrom2
    @test resumed.restart_state.optimizer_state.phase ==
          uninterrupted.restart_state.optimizer_state.phase
    @test resumed.restart_state.optimizer_state.z_steps ==
          uninterrupted.restart_state.optimizer_state.z_steps
    @test resumed.restart_state.optimizer_state.u_steps ==
          uninterrupted.restart_state.optimizer_state.u_steps
end

@testset "Canonical representation builder and structural boundaries" begin
    foundation_extension_before = Base.get_extension(WannierNLQG, :WannierNLQGSymmetryFoundationExt)
    wannierization_extension, _ = WANNIERIZATION._load_wannierization_extension!()
    foundation_extension = Base.get_extension(WannierNLQG, :WannierNLQGSymmetryFoundationExt)
    @test foundation_extension === foundation_extension_before
    structure = WannierNLQG.SymmetryFoundation.CrystalStructure(
        2.0 .* Matrix{Float64}(I, 3, 3),
        ["X"],
        zeros(3, 1),
    )
    identity_operation = WannierNLQG.SymmetryFoundation.SymmetryOperation(
        Matrix{Int}(I, 3, 3),
        zeros(3),
        Matrix{Float64}(I, 3, 3),
    )
    coefficients = reshape(ComplexF64[1.0], 1, 1, 1)
    g_vectors = zeros(Int, 1, 3)
    energies = reshape([-1.0], 1, 1)
    wannierization_point = Base.invokelatest(
        WannierNLQG.SymmetryFoundation.PlaneWaveKPoint,
        zeros(3),
        g_vectors,
        coefficients,
        [-1.0],
    )
    wannierization_native = Base.invokelatest(
        WannierNLQG.SymmetryFoundation.NativeWavefunctionData,
        :synthetic,
        structure,
        pi .* Matrix{Float64}(I, 3, 3),
        (1, 1, 1),
        false,
        [wannierization_point],
        Dict("fixture" => repeat("0", 64)),
    )
    symmetrization_point = Base.invokelatest(
        WannierNLQG.SymmetryFoundation.PlaneWaveKPoint,
        zeros(3),
        g_vectors,
        coefficients,
        [-1.0],
    )
    symmetrization_native = Base.invokelatest(
        WannierNLQG.SymmetryFoundation.NativeWavefunctionData,
        :synthetic,
        structure,
        pi .* Matrix{Float64}(I, 3, 3),
        (1, 1, 1),
        false,
        [symmetrization_point],
        Dict("fixture" => repeat("0", 64)),
    )
    from_wannierization = Base.invokelatest(
        wannierization_extension.RepresentationPreparation._build_band_representation,
        wannierization_native,
        energies,
        [identity_operation],
        0.01;
        return_diagnostics = true,
    )
    from_foundation = Base.invokelatest(
        WannierNLQG.SymmetryFoundation.build_canonical_band_representation,
        symmetrization_native,
        energies,
        [identity_operation],
        0.01,
    )
    @test from_wannierization.representation.sewing_matrices ==
          from_foundation.representation.sewing_matrices
    @test from_wannierization.representation.kpoint_map == from_foundation.representation.kpoint_map
    @test from_wannierization.representation.conventions ==
          from_foundation.representation.conventions
    @test from_wannierization.construction_diagnostics == from_foundation.construction_diagnostics

    inversion_operation = WannierNLQG.SymmetryFoundation.SymmetryOperation(
        -Matrix{Int}(I, 3, 3),
        zeros(3),
        -Matrix{Float64}(I, 3, 3),
    )
    truncated_point = Base.invokelatest(
        WannierNLQG.SymmetryFoundation.PlaneWaveKPoint,
        zeros(3),
        [0 0 0; 1 0 0],
        reshape(ComplexF64[1.0, 1.0], 1, 2, 1),
        [-1.0],
    )
    truncated_native = Base.invokelatest(
        WannierNLQG.SymmetryFoundation.NativeWavefunctionData,
        :synthetic,
        structure,
        pi .* Matrix{Float64}(I, 3, 3),
        (1, 1, 1),
        false,
        [truncated_point],
        Dict("fixture" => repeat("4", 64)),
    )
    prepolar = Base.invokelatest(
        wannierization_extension.RepresentationPreparation._build_band_representation,
        truncated_native,
        energies,
        [identity_operation, inversion_operation],
        0.01;
        diagnostic_outer_masks = [trues(1)],
        diagnostic_frozen_masks = [falses(1)],
        return_diagnostics = true,
    )
    raw_full = only(
        filter(
            diagnostic ->
                get(diagnostic, "scope", "") == "full" && diagnostic["operation"] == 2,
            prepolar.construction_diagnostics,
        ),
    )
    @test raw_full["sigma_min"] ≈ 0.5 atol = 1.0e-14 rtol = 0.0
    @test raw_full["left_unitarity_residual"] ≈ 0.75 atol = 1.0e-14 rtol = 0.0
    @test abs(prepolar.representation.sewing_matrices[1, 1, 2, 1]) ≈ 1.0 atol = 1.0e-14 rtol = 0.0
    mktempdir() do directory
        prepolar_file = joinpath(directory, "prepolar-raw.h5")
        Base.invokelatest(
            WannierNLQG.SymmetryFoundation.write_band_representation_hdf5,
            prepolar_file,
            diagnostic_public_band_representation(prepolar.representation);
            overwrite = true,
            qualification_outer_mask = trues(1, 1),
            qualification_frozen_mask = falses(1, 1),
            raw_diagnostics = prepolar.construction_diagnostics,
        )
        HDF5.h5open(prepolar_file, "r") do handle
            raw_group = handle["raw_diagnostics"]
            scopes = read(raw_group["scope_code"])
            values = read(raw_group["real_values"])
            integers = read(raw_group["integer_values"])
            full_index = something(
                findfirst(
                    index -> scopes[index] == 0x01 && integers[1, index] == 2,
                    eachindex(scopes),
                ),
            )
            @test values[2, full_index] ≈ 0.5 atol = 1.0e-14 rtol = 0.0
            @test values[5, full_index] ≈ 0.75 atol = 1.0e-14 rtol = 0.0
        end
    end

    rank_deficient_point = Base.invokelatest(
        WannierNLQG.SymmetryFoundation.PlaneWaveKPoint,
        zeros(3),
        g_vectors,
        reshape(ComplexF64[1.0, 1.0], 2, 1, 1),
        [-1.0, 1.0],
    )
    rank_deficient_native = Base.invokelatest(
        WannierNLQG.SymmetryFoundation.NativeWavefunctionData,
        :synthetic,
        structure,
        pi .* Matrix{Float64}(I, 3, 3),
        (1, 1, 1),
        false,
        [rank_deficient_point],
        Dict("fixture" => repeat("1", 64)),
    )
    rank_error = try
        Base.invokelatest(
            wannierization_extension.RepresentationPreparation._build_band_representation,
            rank_deficient_native,
            reshape([-1.0, 1.0], 2, 1),
            [identity_operation],
            0.01,
        )
        nothing
    catch exception
        exception
    end
    @test rank_error isa ArgumentError
    @test occursin("rank deficient", sprint(showerror, rank_error))

    nonfinite_point = Base.invokelatest(
        WannierNLQG.SymmetryFoundation.PlaneWaveKPoint,
        zeros(3),
        g_vectors,
        reshape(ComplexF64[NaN], 1, 1, 1),
        [-1.0];
        normalize_coefficients = false,
    )
    nonfinite_native = Base.invokelatest(
        WannierNLQG.SymmetryFoundation.NativeWavefunctionData,
        :synthetic,
        structure,
        pi .* Matrix{Float64}(I, 3, 3),
        (1, 1, 1),
        false,
        [nonfinite_point],
        Dict("fixture" => repeat("2", 64)),
    )
    nonfinite_error = try
        Base.invokelatest(
            wannierization_extension.RepresentationPreparation._build_band_representation,
            nonfinite_native,
            energies,
            [identity_operation],
            0.01,
        )
        nothing
    catch exception
        exception
    end
    @test nonfinite_error isa ArgumentError
    @test occursin("NONFINITE_COEFFICIENT_BLOCK", sprint(showerror, nonfinite_error))

    antiunitary_operation = WannierNLQG.SymmetryFoundation.SymmetryOperation(
        Matrix{Int}(I, 3, 3),
        zeros(3),
        Matrix{Float64}(I, 3, 3),
        true,
    )
    off_mesh_point = Base.invokelatest(
        WannierNLQG.SymmetryFoundation.PlaneWaveKPoint,
        [0.25, 0.0, 0.0],
        g_vectors,
        coefficients,
        [-1.0],
    )
    off_mesh_native = Base.invokelatest(
        WannierNLQG.SymmetryFoundation.NativeWavefunctionData,
        :synthetic,
        structure,
        pi .* Matrix{Float64}(I, 3, 3),
        (1, 1, 1),
        false,
        [off_mesh_point],
        Dict("fixture" => repeat("3", 64)),
    )
    action_error = try
        Base.invokelatest(
            wannierization_extension.RepresentationPreparation._build_band_representation,
            off_mesh_native,
            energies,
            [antiunitary_operation],
            0.01,
        )
        nothing
    catch exception
        exception
    end
    @test action_error isa ArgumentError
    @test occursin("INVALID_SYMMETRY_ACTION", sprint(showerror, action_error))

    @test_throws ArgumentError WannierNLQG.SymmetryFoundation.VASPWavefunctionSource(
        "POSCAR",
        "WAVECAR";
        magnetic_moments_cartesian = zeros(2, 1),
    )
    @test_throws ArgumentError WannierNLQG.SymmetryFoundation.VASPWavefunctionSource(
        "POSCAR",
        "WAVECAR";
        magnetic_moments_cartesian = fill(NaN, 3, 1),
    )
    source_moments = reshape([0.0, 0.0, 1.0], 3, 1)
    vasp_config = WannierNLQG.SymmetryFoundation.VASPBandRepresentationConfig(
        poscar_file = "POSCAR",
        wavecar_file = "WAVECAR",
        eig_file = "wannier90.eig",
        output_hdf5_file = "representation.h5",
        magnetic_moments_cartesian = source_moments,
    )
    expected_moment_digest = WannierNLQG.SymmetryFoundation.magnetic_moments_sha256(
        vasp_config.magnetic_moments_cartesian,
    )
    source_moments[3, 1] = 7.0
    @test vasp_config.magnetic_moments_cartesian == reshape([0.0, 0.0, 1.0], 3, 1)
    @test expected_moment_digest ==
          WannierNLQG.SymmetryFoundation.magnetic_moments_sha256(reshape([0.0, 0.0, 1.0], 3, 1))
    @test expected_moment_digest !=
          WannierNLQG.SymmetryFoundation.magnetic_moments_sha256(reshape([0.0, 0.0, -1.0], 3, 1))
    @test_throws ArgumentError WannierNLQG.SymmetryFoundation.VASPBandRepresentationConfig(
        poscar_file = "POSCAR",
        wavecar_file = "WAVECAR",
        eig_file = "wannier90.eig",
        output_hdf5_file = "representation.h5",
        magnetic_moments_cartesian = zeros(2, 1),
    )
    mktempdir() do directory
        consistent_incar = joinpath(directory, "INCAR.consistent")
        conflicting_incar = joinpath(directory, "INCAR.conflicting")
        write(consistent_incar, "LNONCOLLINEAR = T\nLSORBIT = T\nSAXIS = 0 0 1\nMAGMOM = 0 0 1\n")
        write(conflicting_incar, "LNONCOLLINEAR = T\nLSORBIT = T\nSAXIS = 0 0 1\nMAGMOM = 0 0 -1\n")
        consistent_source = WannierNLQG.SymmetryFoundation.VASPWavefunctionSource(
            "POSCAR",
            "WAVECAR";
            incar_file = consistent_incar,
            magnetic_moments_cartesian = vasp_config.magnetic_moments_cartesian,
        )
        conflicting_source = WannierNLQG.SymmetryFoundation.VASPWavefunctionSource(
            "POSCAR",
            "WAVECAR";
            incar_file = conflicting_incar,
            magnetic_moments_cartesian = vasp_config.magnetic_moments_cartesian,
        )
        @test WannierNLQG.SymmetryFoundation.validate_vasp_magnetic_moment_sources(
            consistent_source,
            1,
        ) == :INCAR_CONSISTENT
        conflict = try
            WannierNLQG.SymmetryFoundation.validate_vasp_magnetic_moment_sources(conflicting_source, 1)
            nothing
        catch exception
            exception
        end
        @test conflict isa ArgumentError
        @test occursin("MAGNETIC_MOMENT_SOURCE_CONFLICT", sprint(showerror, conflict))
        @test_throws ArgumentError WannierNLQG.SymmetryFoundation.validate_vasp_magnetic_moment_sources(
            consistent_source,
            2,
        )
    end
    magnetic_structure = WannierNLQG.SymmetryFoundation.CrystalStructure(
        Matrix{Float64}(I, 3, 3),
        ["X"],
        zeros(3, 1);
        magnetic_moments_cartesian = reshape([0.0, 0.0, 1.0], 3, 1),
    )
    inventory = WannierNLQG.SymmetryFoundation.detect_magnetic_symmetry_inventory(
        magnetic_structure;
        include_time_reversal = true,
        symmetry_tolerance = 2.5e-6,
    )
    @test inventory.magnetic
    @test inventory.symmetry_tolerance == 2.5e-6
end

@testset "Wannierization solver statuses and covariance" begin
    fixture = synthetic_wannierization_fixture()
    analytic_report = WANNIERIZATION.validate_band_representation_compatibility(
        fixture.representation,
        fixture.plan;
        tolerance = fixture.config.input.representation_tolerance,
    )
    empirical_report = WANNIERIZATION.RepresentationCompatibilityReport(
        analytic_report.schema_version,
        true,
        true,
        analytic_report.tolerance,
        analytic_report.product_table,
        (1.0e-5, 2.0e-5, 1.5e-5, 1.25e-5),
        analytic_report.maximum_reciprocal_shift_residual,
        analytic_report.theta_squared_residual,
        analytic_report.maximum_kramers_residual,
        analytic_report.representation_sha256,
        WANNIERIZATION.WannierizationDiagnostic[],
        :irrep_paired_oracle,
        WANNIERIZATION.GATE_VALID,
        WANNIERIZATION.REPRESENTATION_COMPATIBLE,
        0.0,
        (0.0, 0.0, 0.0, 0.0),
        repeat("a", 64),
        :empirical,
    )
    @test WANNIERIZATION._projector_covariance_tolerance(fixture.config, analytic_report) ==
          fixture.config.input.representation_tolerance
    @test WANNIERIZATION._projector_covariance_tolerance(fixture.config, empirical_report) == 2.0e-5
    declared_budget_config =
        modified_wannierization_config(fixture.config; empirical_covariance_budget = 1.0e-3)
    @test WANNIERIZATION._projector_covariance_tolerance(
        declared_budget_config,
        empirical_report,
    ) == 1.0e-3
    workflow_extension = Base.get_extension(WannierNLQG, :WannierNLQGWannierizationExt)
    @test workflow_extension !== nothing
    @test Base.invokelatest(
        workflow_extension.WorkflowOrchestration._final_tb_hamiltonian_covariance_threshold,
        declared_budget_config,
    ) == fixture.config.input.representation_tolerance
    nonlocalizing_config = modified_wannierization_config(
        fixture.config;
        algorithm_profile = :custom,
        localize = false,
    )
    result = WANNIERIZATION._solve_symmetry_adapted_wannierization(
        nonlocalizing_config,
        fixture.representation,
        fixture.eig,
        fixture.mmn,
        fixture.plan,
    )
    @test result.status == WANNIERIZATION.COMPLETED
    @test result.wannier_chk !== nothing
    @test length(result.history) == fixture.config.solver.acceleration.z_stability_window + 1
    @test result.restart_state.optimizer_state.phase == :completed
    @test maximum(abs, result.v_matrix[:, :, 1]' * result.v_matrix[:, :, 1] - I) <= 1.0e-14
    frames = [Matrix(@view(result.v_matrix[:, :, kpoint])) for kpoint in 1:2]
    @test WANNIERIZATION._maximum_projector_covariance_error(frames, fixture.representation) <=
          1.0e-14
    reevaluated = WANNIERIZATION.evaluate_full_3d_wannier_spreads(
        result,
        fixture.representation,
        fixture.mmn,
        fixture.plan,
    )
    @test reevaluated.spreads_angstrom2 == result.spreads_angstrom2
    @test abs(sum(reevaluated.omega_directional) - reevaluated.omega_total) <= 1.0e-10
    shifted_center_images = copy(result.wannier_centers_cartesian)
    shifted_center_images[1, :] .+= fixture.representation.real_lattice[1, :]
    shifted_reevaluation = WANNIERIZATION.evaluate_full_3d_wannier_spreads(
        result.v_matrix,
        shifted_center_images,
        fixture.representation,
        fixture.mmn,
        fixture.plan,
    )
    @test shifted_reevaluation.spreads_angstrom2 == reevaluated.spreads_angstrom2
    @test shifted_reevaluation.omega_directional == reevaluated.omega_directional
    @test shifted_reevaluation.centers_cartesian[1, :] ≈ shifted_center_images[1, :] atol = 1.0e-14 rtol =
        0.0

    singular_fixture = synthetic_wannierization_fixture(; mmn_scale = 0.0)
    singular = WANNIERIZATION._solve_symmetry_adapted_wannierization(
        singular_fixture.config,
        singular_fixture.representation,
        singular_fixture.eig,
        singular_fixture.mmn,
        singular_fixture.plan,
    )
    @test singular.status == WANNIERIZATION.SINGULAR_LOCALIZATION
    @test singular.restart_state !== nothing
    @test singular.restart_state.iteration > 0
    @test singular.restart_state.z_previous !== nothing
    @test singular.restart_state.optimizer_state.phase == :localization
    @test all(isfinite, singular.v_matrix)
    @test any(
        diagnostic -> diagnostic.code == :SPREAD_GRADIENT_DIAGONAL_OVERLAP_SINGULAR,
        singular.diagnostics,
    )

    incompatible_representation = deepcopy(fixture.representation)
    incompatible_representation.sewing_matrices[1, 1, 1, 1] = 0.0
    incompatible = WANNIERIZATION._solve_symmetry_adapted_wannierization(
        fixture.config,
        incompatible_representation,
        fixture.eig,
        fixture.mmn,
        fixture.plan,
    )
    @test incompatible.status == WANNIERIZATION.REPRESENTATION_INCOMPATIBLE
    @test isempty(incompatible.history)
    @test incompatible.input_summary["failure_class"] == "REPRESENTATION_A"
    @test any(
        diagnostic -> diagnostic.code == :REQUIRED_BLOCK_UNITARITY_FAILED,
        incompatible.diagnostics,
    )

    wrong_mmn = WANNIER_IO.WannierMMN(
        1,
        2,
        1,
        ones(ComplexF64, 1, 1, 1, 2),
        ones(Int, 1, 2),
        zeros(Int, 3, 1, 2),
    )
    invalid = WANNIERIZATION._solve_symmetry_adapted_wannierization(
        fixture.config,
        fixture.representation,
        fixture.eig,
        wrong_mmn,
        fixture.plan,
    )
    @test invalid.status == WANNIERIZATION.INVALID_INPUT
    @test only(invalid.diagnostics).code == :MMN_DIMENSION_MISMATCH
end

@testset "Wannierization HDF5 and tight-binding boundaries" begin
    fixture = synthetic_wannierization_fixture()
    # Keep the historical projected-gradient fixture for the production/export
    # boundary assertions below.  The new symmetry-projected SMV--FR default
    # has separate state-machine coverage and may legitimately end at a
    # diagnostic nonconverged Z boundary on this eight-step synthetic case.
    nonlocalizing_config = modified_wannierization_config(
        fixture.config;
        localize = false,
        algorithm_profile = :custom,
    )
    result = WANNIERIZATION._solve_symmetry_adapted_wannierization(
        nonlocalizing_config,
        fixture.representation,
        fixture.eig,
        fixture.mmn,
        fixture.plan,
    )
    mktempdir() do directory
        representation_file = joinpath(directory, "representation.h5")
        WannierNLQG.SymmetryFoundation.write_band_representation_hdf5(
            representation_file,
            diagnostic_public_band_representation(fixture.representation),
        )
        restored_representation =
            WannierNLQG.SymmetryFoundation.read_band_representation_hdf5(representation_file)
        @test restored_representation.sewing_matrices == fixture.representation.sewing_matrices
        @test restored_representation.kpoint_map == fixture.representation.kpoint_map
        @test restored_representation.input_sha256 == fixture.representation.input_sha256
        HDF5.h5open(representation_file, "r") do handle
            @test String(read(HDF5.attributes(handle)["schema_version"])) == "1.0"
            @test length(String(read(HDF5.attributes(handle)["preparation_digest"]))) == 64
            @test all(
                name -> haskey(handle, name),
                ("inventory", "qualification_scope", "raw_diagnostics", "compatibility_policy"),
            )
            @test Int(read(HDF5.attributes(handle["raw_diagnostics"])["count"])) == 8
        end
        extension, _ = WANNIERIZATION._load_wannierization_extension!()
        periodic_config = modified_wannierization_config(
            fixture.config;
            localize = false,
            algorithm_profile = :auto,
            checkpoint_interval = 1,
        )
        periodic_source = WANNIERIZATION._solve_symmetry_adapted_wannierization(
            periodic_config,
            fixture.representation,
            fixture.eig,
            fixture.mmn,
            fixture.plan,
        )
        @test periodic_source.restart_state !== nothing
        periodic_snapshot = (
            optimizer_phase = :localization,
            z_seal_class = "DIAGNOSTIC_NONCONVERGED",
            qualified_z_seal = "false",
            disentanglement_convergence = "DIAGNOSTIC_NONCONVERGED",
            route_selection_eligible = "false",
            localization_convergence = "NOT_APPLICABLE",
            localization_qualification = "NOT_APPLICABLE",
            model_qualification = "NOT_AVAILABLE",
            z_steps = 1500,
            u_steps = 10,
        )
        periodic_result = Base.invokelatest(
            extension.OperatorExport._periodic_result,
            periodic_snapshot,
            something(periodic_source.restart_state),
            periodic_source.history,
            periodic_source.diagnostics,
            fixture.representation,
            periodic_config,
        )
        @test periodic_result.input_summary["algorithm_profile"] == "auto"
        @test periodic_result.input_summary["effective_algorithm_profile"] ==
              "symmetry_projected_smv_fletcher_reeves_two_stage"
        @test periodic_result.input_summary["disentanglement_algorithm"] ==
              "symmetry_projected_smv_fletcher_reeves_two_stage"
        @test periodic_result.input_summary["localization_algorithm"] ==
              "symmetry_projected_smv_fletcher_reeves_two_stage"
        @test periodic_result.input_summary["symmetry_projected_smv_fr_contract"] ==
              WANNIERIZATION_IMPLEMENTATION.SolverCheckpoint.SYMMETRY_PROJECTED_SMV_FR_CONTRACT
        @test periodic_result.input_summary["optimizer_phase"] == "localization"
        @test periodic_result.input_summary["disentanglement_steps"] == "1500"
        @test periodic_result.input_summary["localization_steps"] == "10"
        @test periodic_result.input_summary["disentanglement_convergence"] ==
              "DIAGNOSTIC_NONCONVERGED"
        @test periodic_result.input_summary["z_seal_class"] == "DIAGNOSTIC_NONCONVERGED"
        @test periodic_result.input_summary["qualified_z_seal"] == "false"
        @test periodic_result.input_summary["route_selection_eligible"] == "false"
        @test periodic_result.input_summary["localization_convergence"] == "NOT_APPLICABLE"
        @test periodic_result.input_summary["localization_qualification"] == "NOT_APPLICABLE"
        @test periodic_result.input_summary["model_qualification"] == "NOT_AVAILABLE"
        @test periodic_result.input_summary["diagnostic_only"] == "true"
        @test periodic_result.input_summary["diagnostic_tb_export_eligible"] == "false"
        @test periodic_result.input_summary["standard_tb_export_eligible"] == "false"
        @test periodic_result.input_summary["global_production_eligible"] == "false"
        diagnostic_stage_summary = Base.invokelatest(
            extension.OperatorExport._periodic_stage_summary,
            merge(
                periodic_snapshot,
                (
                    localization_convergence = "IN_PROGRESS",
                    localization_qualification = "DIAGNOSTIC_ONLY",
                    model_qualification = "DIAGNOSTIC_ONLY/Z_NONCONVERGED",
                ),
            ),
        )
        @test diagnostic_stage_summary["localization_convergence"] == "IN_PROGRESS"
        @test diagnostic_stage_summary["localization_qualification"] == "DIAGNOSTIC_ONLY"
        @test diagnostic_stage_summary["model_qualification"] == "DIAGNOSTIC_ONLY/Z_NONCONVERGED"
        formal_stage_summary = Base.invokelatest(
            extension.OperatorExport._periodic_stage_summary,
            merge(
                periodic_snapshot,
                (
                    disentanglement_convergence = "CONVERGED",
                    z_seal_class = "CONVERGED",
                    qualified_z_seal = "true",
                    route_selection_eligible = "true",
                    localization_convergence = "IN_PROGRESS",
                    localization_qualification = "FORMAL_CANDIDATE",
                    model_qualification = "FORMAL_CANDIDATE",
                ),
            ),
        )
        @test formal_stage_summary["disentanglement_convergence"] == "CONVERGED"
        @test formal_stage_summary["qualified_z_seal"] == "true"
        @test formal_stage_summary["route_selection_eligible"] == "true"
        @test formal_stage_summary["localization_qualification"] == "FORMAL_CANDIDATE"
        @test formal_stage_summary["model_qualification"] == "FORMAL_CANDIDATE"
        @test formal_stage_summary["diagnostic_only"] == "true"
        @test formal_stage_summary["standard_tb_export_eligible"] == "false"
        structural_failure_stage_summary = Base.invokelatest(
            extension.OperatorExport._periodic_stage_summary,
            merge(
                periodic_snapshot,
                (
                    disentanglement_convergence = "DIAGNOSTIC_NONCONVERGED_STRUCTURAL_GATE_FAILED",
                    localization_convergence = "NOT_RUN",
                    localization_qualification = "NOT_RUN",
                    model_qualification = "NOT_RUN/Z_STRUCTURAL_GATE_FAILED",
                    u_steps = 0,
                ),
            ),
        )
        @test structural_failure_stage_summary["disentanglement_convergence"] ==
              "DIAGNOSTIC_NONCONVERGED_STRUCTURAL_GATE_FAILED"
        @test structural_failure_stage_summary["localization_convergence"] == "NOT_RUN"
        @test structural_failure_stage_summary["localization_qualification"] == "NOT_RUN"
        @test structural_failure_stage_summary["model_qualification"] ==
              "NOT_RUN/Z_STRUCTURAL_GATE_FAILED"
        @test structural_failure_stage_summary["diagnostic_only"] == "true"
        @test structural_failure_stage_summary["localization_steps"] == "0"
        @test structural_failure_stage_summary["diagnostic_tb_export_eligible"] == "false"
        periodic_checkpoint = joinpath(directory, "periodic-profile-checkpoint.h5")
        WANNIERIZATION.write_wannierization_checkpoint_hdf5(periodic_checkpoint, periodic_result)
        restored_periodic = WANNIERIZATION.read_wannierization_checkpoint_hdf5(periodic_checkpoint)
        @test restored_periodic.input_summary["algorithm_profile"] == "auto"
        @test restored_periodic.input_summary["effective_algorithm_profile"] ==
              "symmetry_projected_smv_fletcher_reeves_two_stage"
        @test restored_periodic.input_summary["z_seal_class"] == "DIAGNOSTIC_NONCONVERGED"
        @test restored_periodic.input_summary["qualified_z_seal"] == "false"
        @test restored_periodic.input_summary["route_selection_eligible"] == "false"
        @test restored_periodic.input_summary["diagnostic_only"] == "true"
        @test restored_periodic.input_summary["standard_tb_export_eligible"] == "false"
        @test restored_periodic.input_summary["global_production_eligible"] == "false"
        HDF5.h5open(periodic_checkpoint, "r") do handle
            attributes = HDF5.attributes(handle)
            @test String(read(attributes["algorithm_profile"])) == "auto"
            @test String(read(attributes["effective_algorithm_profile"])) ==
                  "symmetry_projected_smv_fletcher_reeves_two_stage"
            @test String(read(attributes["z_seal_class"])) == "DIAGNOSTIC_NONCONVERGED"
            @test !Bool(read(attributes["qualified_z_seal"]))
            @test !Bool(read(attributes["global_production_eligible"]))
        end
        representation_metadata = Base.invokelatest(
            WannierNLQG.SymmetryFoundation.read_band_representation_preparation_hdf5,
            representation_file,
            restored_representation,
        )
        @test representation_metadata.qualification_scope.diagnostic_status == :AVAILABLE
        @test Set(getfield.(representation_metadata.raw_diagnostics, :scope)) ==
              Set((:full, :outer, :frozen, :outside))
        @test representation_metadata.requested_policy == :strict
        @test representation_metadata.effective_policy == :strict
        @test length(something(representation_metadata.preparation_digest)) == 64

        legacy_representation_file = joinpath(directory, "representation-schema-1.3.h5")
        cp(representation_file, legacy_representation_file)
        HDF5.h5open(legacy_representation_file, "r+") do handle
            HDF5.delete_attribute(handle, "schema_version")
            HDF5.attributes(handle)["schema_version"] = "1.3"
        end
        @test_throws ArgumentError WannierNLQG.SymmetryFoundation.read_band_representation_hdf5(
            legacy_representation_file,
        )
        @test_throws ArgumentError Base.invokelatest(
            WannierNLQG.SymmetryFoundation.read_band_representation_preparation_hdf5,
            legacy_representation_file,
            restored_representation,
        )

        win_file = joinpath(directory, "preparation.win")
        open(win_file, "w") do io
            println(io, "num_wann = 1")
        end
        eig_file = joinpath(directory, "preparation.eig")
        open(eig_file, "w") do io
            for kpoint in 1:fixture.eig.num_kpts, band in 1:fixture.eig.num_bands
                println(io, "$(band) $(kpoint) $(fixture.eig.data[band, kpoint])")
            end
        end
        prepared_file = joinpath(directory, "prepared-representation.h5")
        prepared = WANNIERIZATION.prepare_band_representation(
            WANNIERIZATION.BandRepresentationPreparationConfig(
                construction_policy = :strict,
                wannierization_mode = :symmetry_adapted,
                win_file = win_file,
                eig_file = eig_file,
                projection_basis = fixture.basis,
                band_representation = fixture.representation,
                output_hdf5 = prepared_file,
                outer_min_ev = -2.0,
                outer_max_ev = 2.0,
                frozen_min_ev = -2.0,
                frozen_max_ev = -0.5,
                num_wannier = 1,
                symmetry_tolerance = 2.5e-6,
                compatibility_policy = :off,
            ),
        )
        @test prepared.output_hdf5 == abspath(prepared_file)
        @test prepared.effective_compatibility_policy == :strict
        @test prepared.symmetry_tolerance_status == :NOT_APPLICABLE
        @test Set(getfield.(prepared.raw_diagnostics, :scope)) ==
              Set((:full, :outer, :frozen, :outside))
        @test length(something(prepared.artifact_sha256)) == 64
        HDF5.h5open(prepared_file, "r") do handle
            policy = HDF5.attributes(handle["compatibility_policy"])
            @test String(read(policy["requested"])) == "off"
            @test String(read(policy["effective"])) == "strict"
            @test String(read(policy["symmetry_tolerance_status"])) == "NOT_APPLICABLE"
        end
        nofrozen_prepared_file = joinpath(directory, "prepared-representation-nofrozen.h5")
        @test_throws ArgumentError WANNIERIZATION.prepare_band_representation(
            WANNIERIZATION.BandRepresentationPreparationConfig(
                construction_policy = :strict,
                wannierization_mode = :symmetry_adapted,
                win_file = win_file,
                eig_file = eig_file,
                projection_basis = fixture.basis,
                band_representation_hdf5 = prepared_file,
                output_hdf5 = joinpath(directory, "relabelled-frozen-mask.h5"),
                outer_min_ev = -2.0,
                outer_max_ev = 2.0,
                frozen_min_ev = 0.0,
                frozen_max_ev = 0.0,
                num_wannier = 1,
                compatibility_policy = :strict,
            ),
        )
        nofrozen_prepared = WANNIERIZATION.prepare_band_representation(
            WANNIERIZATION.BandRepresentationPreparationConfig(
                construction_policy = :strict,
                wannierization_mode = :symmetry_adapted,
                win_file = win_file,
                eig_file = eig_file,
                projection_basis = fixture.basis,
                band_representation = fixture.representation,
                output_hdf5 = nofrozen_prepared_file,
                outer_min_ev = -2.0,
                outer_max_ev = 2.0,
                frozen_min_ev = 0.0,
                frozen_max_ev = 0.0,
                num_wannier = 1,
                compatibility_policy = :strict,
            ),
        )
        @test all(
            diagnostic -> diagnostic.status == :EMPTY_SCOPE,
            filter(diagnostic -> diagnostic.scope == :frozen, nofrozen_prepared.raw_diagnostics),
        )
        @test count(diagnostic -> diagnostic.scope == :frozen, nofrozen_prepared.raw_diagnostics) ==
              length(fixture.representation.operations) * fixture.eig.num_kpts

        identity_win_file = joinpath(directory, "identity-preparation.win")
        open(identity_win_file, "w") do io
            println(io, "num_wann = 1")
            println(io, "mp_grid = 2 1 1")
            println(io, "begin unit_cell_cart")
            println(io, "1.0 0.0 0.0")
            println(io, "0.0 1.0 0.0")
            println(io, "0.0 0.0 1.0")
            println(io, "end unit_cell_cart")
            println(io, "begin kpoints")
            println(io, "0.0 0.0 0.0")
            println(io, "0.5 0.0 0.0")
            println(io, "end kpoints")
        end
        identity_artifact = joinpath(directory, "identity-prepared.schema-1.0.h5")
        generated_identity = WANNIERIZATION.prepare_band_representation(
            WANNIERIZATION.BandRepresentationPreparationConfig(
                construction_policy = :strict,
                wannierization_mode = :ordinary,
                win_file = identity_win_file,
                eig_file = eig_file,
                projection_basis = fixture.basis,
                output_hdf5 = identity_artifact,
                outer_min_ev = -2.0,
                outer_max_ev = 2.0,
                frozen_min_ev = -2.0,
                frozen_max_ev = -0.5,
                num_wannier = 1,
                compatibility_policy = :off,
            ),
        )
        shared_identity = WANNIERIZATION.prepare_band_representation(
            WANNIERIZATION.BandRepresentationPreparationConfig(
                construction_policy = :strict,
                wannierization_mode = :ordinary,
                win_file = identity_win_file,
                eig_file = eig_file,
                projection_basis = fixture.basis,
                band_representation_hdf5 = identity_artifact,
                outer_min_ev = -2.0,
                outer_max_ev = 2.0,
                frozen_min_ev = -2.0,
                frozen_max_ev = -0.5,
                num_wannier = 1,
                compatibility_policy = :off,
            ),
        )
        @test shared_identity.representation.sewing_matrices ==
              generated_identity.representation.sewing_matrices
        @test shared_identity.representation.kpoint_map ==
              generated_identity.representation.kpoint_map
        @test shared_identity.effective_compatibility_policy == :off
        @test shared_identity.symmetry_tolerance_status == :NOT_APPLICABLE
        @test shared_identity.output_hdf5 === nothing
        @test Base.invokelatest(
            extension.SolverCheckpoint._validate_no_symmetry_identity_representation,
            shared_identity.representation,
            1.0e-10,
        ) === nothing
        @test_throws ArgumentError Base.invokelatest(
            extension.SolverCheckpoint._validate_no_symmetry_identity_representation,
            fixture.representation,
            1.0e-10,
        )

        fixed_frames = copy(result.v_matrix)
        fixed_projectors = zeros(ComplexF64, 2, 2, 2)
        for kpoint in 1:2
            fixed_projectors[:, :, kpoint] .=
                fixed_frames[:, :, kpoint] * fixed_frames[:, :, kpoint]'
        end
        fixed_mask = BitMatrix([true true; false false])
        fixed = WANNIERIZATION.WannierizationFixedSubspace(
            fixed_projectors,
            fixed_frames,
            [1, 2],
            fixed_mask;
            source_sha256 = Dict("mmn" => repeat("a", 64)),
            invariant_residuals = Dict("isometry" => 1.0e-15),
        )
        fixed_file = joinpath(directory, "fixed-subspace.h5")
        WANNIERIZATION.write_wannierization_fixed_subspace_hdf5(fixed_file, fixed)
        restored_fixed = WANNIERIZATION.read_wannierization_fixed_subspace_hdf5(fixed_file)
        @test restored_fixed.projectors == fixed.projectors
        @test restored_fixed.frames == fixed.frames
        @test restored_fixed.irreducible_indices == fixed.irreducible_indices
        @test restored_fixed.frozen_mask == fixed.frozen_mask
        @test restored_fixed.source_sha256 == fixed.source_sha256
        @test restored_fixed.invariant_residuals == fixed.invariant_residuals

        # Shared representation HDF5 no longer activates the SAWF/EzXML extension.
        extension, _ = WANNIERIZATION._load_wannierization_extension!()
        @test extension !== nothing
        lattice = 2.0 .* Matrix{Float64}(I, 3, 3)
        structure = WannierNLQG.SymmetryFoundation.CrystalStructure(lattice, ["X"], zeros(3, 1))
        plane_wave = Base.invokelatest(
            WannierNLQG.SymmetryFoundation.PlaneWaveKPoint,
            zeros(3),
            zeros(Int, 1, 3),
            reshape(ComplexF64[7.0], 1, 1, 1),
            [-1.0],
        )
        native = Base.invokelatest(
            WannierNLQG.SymmetryFoundation.NativeWavefunctionData,
            :synthetic,
            structure,
            pi .* Matrix{Float64}(I, 3, 3),
            (1, 1, 1),
            false,
            [plane_wave],
            Dict("fixture" => repeat("0", 64)),
        )
        generated_amn = Base.invokelatest(
            extension.RepresentationPreparation._generate_amn,
            native,
            fixture.basis,
        )
        expected_projector =
            WannierNLQG.WannierProjection.projection_orbital_values(
                first(fixture.basis.blocks),
                zeros(3),
            )[1] / sqrt(det(lattice))
        @test generated_amn[1, 1, 1] ≈ expected_projector atol = 1.0e-13 rtol = 0.0
        @test !isapprox(norm(@view(generated_amn[:, 1, 1])), 1.0; atol = 1.0e-6)
        provenance_file = joinpath(directory, "synthetic.amn-provenance.h5")
        synthetic_amn = WANNIER_IO.WannierAMN(1, 1, 1, generated_amn)
        Base.invokelatest(
            extension.RepresentationPreparation._write_amn_provenance_hdf5,
            provenance_file,
            synthetic_amn,
            fixture.basis,
            native;
            amn_sha256 = repeat("0", 64),
        )
        HDF5.h5open(provenance_file, "r") do handle
            radial = handle["radial_transform"]
            attributes = HDF5.attributes(radial)
            @test read(attributes["method"]) == "gauss_laguerre_high_precision"
            @test read(attributes["interpolation"]) == "none"
            @test read(attributes["gauss_laguerre_order"]) == 64
            @test length(read(attributes["implementation_digest"])) == 64
        end
        @test Base.invokelatest(
            extension.WorkflowOrchestration._validate_amn_projection_contract,
            joinpath(directory, "synthetic.amn"),
            fixture.basis,
        ) == provenance_file
        compatibility_basis = WannierNLQG.WannierProjection.WannierProjectionBasis(
            fixture.basis.blocks,
            fixture.basis.num_wannier,
            fixture.basis.spinor,
            WannierNLQG.WannierProjection.ProjectionRadialTransformConfig(;
                method = :wannierberri_compatible,
            ),
        )
        @test_throws ArgumentError Base.invokelatest(
            extension.WorkflowOrchestration._validate_amn_projection_contract,
            joinpath(directory, "synthetic.amn"),
            compatibility_basis,
        )

        theta_operation = WannierNLQG.SymmetryFoundation.SymmetryOperation(
            Matrix{Int}(I, 3, 3),
            zeros(3),
            Matrix{Float64}(I, 3, 3),
            true,
        )
        theta_source = Base.invokelatest(
            WannierNLQG.SymmetryFoundation.PlaneWaveKPoint,
            [0.25, 0.0, 0.0],
            zeros(Int, 1, 3),
            reshape(ComplexF64[1.0], 1, 1, 1),
            [-1.0],
        )
        theta_target = Base.invokelatest(
            WannierNLQG.SymmetryFoundation.PlaneWaveKPoint,
            [0.75, 0.0, 0.0],
            reshape([-1, 0, 0], 1, 3),
            reshape(ComplexF64[1.0], 1, 1, 1),
            [-1.0],
        )
        theta_sewing = Base.invokelatest(
            WannierNLQG.SymmetryFoundation.canonical_plane_wave_sewing_matrix,
            theta_source,
            theta_target,
            theta_operation,
            [-1, 0, 0],
            0.01,
        )
        @test theta_sewing ≈ ones(ComplexF64, 1, 1) atol = 1.0e-14 rtol = 0.0
        @test_throws ArgumentError Base.invokelatest(
            WannierNLQG.SymmetryFoundation.canonical_plane_wave_sewing_matrix,
            theta_source,
            theta_target,
            theta_operation,
            [0, 0, 0],
            0.01,
        )

        checkpoint_file = joinpath(directory, "checkpoint.h5")
        history = [
            WANNIERIZATION.WannierizationIteration(1, 2.0, 3.0, 4.0),
            WANNIERIZATION.WannierizationIteration(2, 1.0, 0.5, 0.25),
        ]
        persisted_result = WANNIERIZATION.WannierizationResult(
            result.status,
            result.v_matrix,
            result.wannier_centers_cartesian,
            result.spreads_angstrom2,
            history,
            result.diagnostics,
            result.input_summary,
            result.wannier_chk,
            nothing,
            result.restart_state,
            WANNIERIZATION.WannierizationArtifacts(),
        )
        written =
            WANNIERIZATION.write_wannierization_checkpoint_hdf5(checkpoint_file, persisted_result)
        @test written == abspath(checkpoint_file)
        restored = WANNIERIZATION.read_wannierization_checkpoint_hdf5(written)
        @test restored.status == result.status
        @test restored.v_matrix == result.v_matrix
        @test getfield.(restored.history, :iteration) == [1, 2]
        @test getfield.(restored.history, :spread_total) == [2.0, 1.0]
        @test getfield.(restored.history, :spread_standard_deviation) == [3.0, 0.5]
        @test getfield.(restored.history, :maximum_covariance_error) == [4.0, 0.25]
        @test restored.wannier_chk !== nothing
        @test restored.restart_state !== nothing
        @test restored.restart_state.frames == result.restart_state.frames
        @test restored.restart_state.optimizer_state.phase ==
              result.restart_state.optimizer_state.phase
        @test restored.restart_state.optimizer_state.gradient_steps ==
              result.restart_state.optimizer_state.gradient_steps
        @test restored.restart_state.optimizer_state.best_polar_frames ==
              result.restart_state.optimizer_state.best_polar_frames
        @test restored.restart_state.optimizer_state.disentanglement_objective_history ==
              result.restart_state.optimizer_state.disentanglement_objective_history
        @test restored.restart_state.optimizer_state.localization_objective_history ==
              result.restart_state.optimizer_state.localization_objective_history
        @test restored.restart_state.optimizer_state.localization_trial_step_scales ==
              result.restart_state.optimizer_state.localization_trial_step_scales
        @test restored.restart_state.optimizer_state.localization_trial_objectives ==
              result.restart_state.optimizer_state.localization_trial_objectives
        @test restored.restart_state.optimizer_state.localization_trial_directional_derivatives ==
              result.restart_state.optimizer_state.localization_trial_directional_derivatives
        @test restored.restart_state.optimizer_state.localization_trial_iterations ==
              result.restart_state.optimizer_state.localization_trial_iterations
        @test restored.restart_state.optimizer_state.localization_trial_sweeps ==
              result.restart_state.optimizer_state.localization_trial_sweeps
        @test restored.restart_state.optimizer_state.localization_trial_accepted ==
              result.restart_state.optimizer_state.localization_trial_accepted
        @test restored.restart_state.optimizer_state.localization_projector_drift_history ==
              result.restart_state.optimizer_state.localization_projector_drift_history
        @test restored.restart_state.fixed_subspace_projectors ==
              result.restart_state.fixed_subspace_projectors
        @test restored.restart_state.fixed_subspace_frames ==
              result.restart_state.fixed_subspace_frames
        HDF5.h5open(checkpoint_file, "r") do handle
            checkpoint_attributes = HDF5.attributes(handle)
            @test length(String(read(checkpoint_attributes["checkpoint_sha256"]))) == 64
            @test length(String(read(checkpoint_attributes["input_sha256"]))) == 64
            @test String(read(checkpoint_attributes["config_sha256"])) ==
                  result.input_summary["restart_config_sha256"]
            @test String(read(checkpoint_attributes["representation_sha256"])) ==
                  result.input_summary["representation_sha256"]
            @test !Bool(read(checkpoint_attributes["production_eligible"]))
        end
        legacy_220_file = joinpath(directory, "checkpoint-schema-2.20-read-only.h5")
        cp(checkpoint_file, legacy_220_file)
        legacy_220_digest = Base.invokelatest(
            extension.SolverCheckpoint._wannierization_checkpoint_sha256_v2_20,
            restored,
        )
        HDF5.h5open(legacy_220_file, "r+") do handle
            HDF5.delete_attribute(handle, "schema_version")
            HDF5.attributes(handle)["schema_version"] = "2.20"
            HDF5.delete_attribute(handle, "checkpoint_sha256")
            HDF5.attributes(handle)["checkpoint_sha256"] = legacy_220_digest
        end
        restored_220 = WANNIERIZATION.read_wannierization_checkpoint_hdf5(legacy_220_file)
        @test restored_220.restart_state === nothing
        @test restored_220.input_summary["restart_continuation_semantics"] ==
              "LEGACY_DIAGNOSTIC_READ_ONLY"
        @test any(
            diagnostic -> diagnostic.code == :RESTART_SEMANTICS_INCOMPATIBLE,
            restored_220.diagnostics,
        )
        legacy_221_file = joinpath(directory, "checkpoint-schema-2.21-read-only.h5")
        cp(checkpoint_file, legacy_221_file)
        persisted_for_221 = Base.invokelatest(
            extension.SolverCheckpoint._checkpoint_persisted_result,
            persisted_result,
        )
        legacy_221_digest = Base.invokelatest(
            extension.SolverCheckpoint._wannierization_checkpoint_sha256_v2_21,
            persisted_for_221,
        )
        HDF5.h5open(legacy_221_file, "r+") do handle
            HDF5.delete_attribute(handle, "schema_version")
            HDF5.attributes(handle)["schema_version"] = "2.21"
            HDF5.delete_attribute(handle, "checkpoint_sha256")
            HDF5.attributes(handle)["checkpoint_sha256"] = legacy_221_digest
        end
        restored_221 = WANNIERIZATION.read_wannierization_checkpoint_hdf5(legacy_221_file)
        @test restored_221.restart_state === nothing
        @test restored_221.input_summary["restart_eligible"] == "false"
        @test restored_221.input_summary["restart_continuation_semantics"] ==
              "LEGACY_DIAGNOSTIC_READ_ONLY"

        sealed_config = modified_wannierization_config(
            fixture.config;
            max_iterations = 4,
            convergence_window = 1,
            acceleration = WANNIERIZATION.WannierizationAccelerationConfig(
                schedule = :two_stage,
                localization_algorithm = :riemannian_cg,
                u_acceptance = :armijo,
                z_stability_window = 1,
                disentanglement_max_steps = 2,
                localization_max_steps = 2,
                u_gradient_norm_tolerance = 1.0e-8,
                u_inner_tolerance = 1.0e-8,
            ),
        )
        sealed_result = WANNIERIZATION._solve_symmetry_adapted_wannierization(
            sealed_config,
            fixture.representation,
            fixture.eig,
            fixture.mmn,
            fixture.plan,
        )
        @test sealed_result.restart_state !== nothing
        @test sealed_result.restart_state.fixed_subspace_projectors !== nothing
        @test sealed_result.restart_state.fixed_subspace_frames !== nothing
        @test sealed_result.restart_state.localization_initial_frames !== nothing
        @test length(sealed_result.input_summary["localization_initial_frame_sha256"]) == 64
        sealed_checkpoint = joinpath(directory, "checkpoint-sealed-two-stage.h5")
        WANNIERIZATION.write_wannierization_checkpoint_hdf5(sealed_checkpoint, sealed_result)
        restored_sealed = WANNIERIZATION.read_wannierization_checkpoint_hdf5(sealed_checkpoint)
        @test restored_sealed.input_summary["checkpoint_schema_version"] == "1.0"
        @test restored_sealed.input_summary["localization_gradient_contract"] ==
              "mv_centered_residual_unwrapped_delta_v2"
        @test restored_sealed.input_summary["checkpoint_localization_gradient_contract"] ==
              "mv_centered_residual_unwrapped_delta_v2"
        @test restored_sealed.input_summary["checkpoint_joint_update_contract"] ==
              "type_iv_block_gauss_seidel_v1"
        @test restored_sealed.input_summary["checkpoint_constraint_operation_scope"] == "full"
        @test restored_sealed.input_summary["constraint_operation_scope_history_reset"] ==
              "NOT_APPLICABLE"
        @test restored_sealed.input_summary["restart_eligible"] == "true"
        @test restored_sealed.restart_state.fixed_subspace_projectors ==
              sealed_result.restart_state.fixed_subspace_projectors
        @test restored_sealed.restart_state.fixed_subspace_frames ==
              sealed_result.restart_state.fixed_subspace_frames
        @test restored_sealed.restart_state.localization_initial_frames ==
              sealed_result.restart_state.localization_initial_frames
        @test restored_sealed.restart_state.optimizer_state.previous_u_gradient ==
              sealed_result.restart_state.optimizer_state.previous_u_gradient
        @test restored_sealed.restart_state.optimizer_state.previous_u_direction ==
              sealed_result.restart_state.optimizer_state.previous_u_direction
        @test restored_sealed.restart_state.optimizer_state.u_cg_iteration ==
              sealed_result.restart_state.optimizer_state.u_cg_iteration
        @test restored_sealed.restart_state.optimizer_state.last_cg_restart_reason ==
              sealed_result.restart_state.optimizer_state.last_cg_restart_reason
        @test restored_sealed.restart_state.optimizer_state.u_phase_contract ==
              "mv_centered_residual_unwrapped_delta_v2"
        @test restored_sealed.restart_state.optimizer_state.u_lbfgs_s_history ==
              sealed_result.restart_state.optimizer_state.u_lbfgs_s_history
        @test restored_sealed.restart_state.optimizer_state.u_lbfgs_y_history ==
              sealed_result.restart_state.optimizer_state.u_lbfgs_y_history
        extension = Base.get_extension(WannierNLQG, :WannierNLQGWannierizationExt)
        @test extension !== nothing
        legacy_phase_summary = Dict{String, String}(restored_sealed.input_summary)
        legacy_phase_summary["localization_gradient_contract"] = "mv_q_unwrapped_center_v1"
        legacy_phase_result = Base.invokelatest(
            extension.WannierizationInternalSupport.updated_wannierization_result,
            restored_sealed;
            input_summary = legacy_phase_summary,
        )
        function set_legacy_phase_contract!(handle)
            root_attributes = HDF5.attributes(handle)
            HDF5.delete_attribute(handle, "localization_gradient_contract")
            root_attributes["localization_gradient_contract"] = "mv_q_unwrapped_center_v1"
            summary_group = handle["input_summary"]
            HDF5.delete_attribute(summary_group, "localization_gradient_contract")
            HDF5.attributes(summary_group)["localization_gradient_contract"] = "mv_q_unwrapped_center_v1"
        end
        schema29_checkpoint = joinpath(directory, "checkpoint-schema-2.9-phase-reset.h5")
        cp(sealed_checkpoint, schema29_checkpoint)
        schema29_digest = Base.invokelatest(
            extension.SolverCheckpoint._wannierization_checkpoint_sha256_v2_9,
            legacy_phase_result,
        )
        HDF5.h5open(schema29_checkpoint, "r+") do handle
            attributes = HDF5.attributes(handle)
            HDF5.delete_attribute(handle, "schema_version")
            attributes["schema_version"] = "2.9"
            set_legacy_phase_contract!(handle)
            HDF5.delete_attribute(handle, "checkpoint_sha256")
            attributes["checkpoint_sha256"] = schema29_digest
        end
        restored_schema29 = WANNIERIZATION.read_wannierization_checkpoint_hdf5(schema29_checkpoint)
        @test restored_schema29.input_summary["optimizer_history_compatibility"] ==
              "LEGACY_U_PHASE_CHART_RESET"
        @test restored_schema29.restart_state.frames == restored_sealed.restart_state.frames
        @test isempty(restored_schema29.restart_state.optimizer_state.previous_u_gradient)
        @test isempty(restored_schema29.restart_state.optimizer_state.u_lbfgs_s_history)
        @test restored_schema29.restart_state.optimizer_state.last_u_optimizer_restart_reason ==
              :LEGACY_U_PHASE_CHART_RESET
        schema28_checkpoint = joinpath(directory, "checkpoint-schema-2.8-default-full.h5")
        cp(sealed_checkpoint, schema28_checkpoint)
        schema28_digest = Base.invokelatest(
            extension.SolverCheckpoint._wannierization_checkpoint_sha256_v2_8,
            legacy_phase_result,
        )
        HDF5.h5open(schema28_checkpoint, "r+") do handle
            attributes = HDF5.attributes(handle)
            HDF5.delete_attribute(handle, "schema_version")
            attributes["schema_version"] = "2.8"
            set_legacy_phase_contract!(handle)
            HDF5.delete_attribute(handle, "checkpoint_sha256")
            attributes["checkpoint_sha256"] = schema28_digest
        end
        restored_schema28 = WANNIERIZATION.read_wannierization_checkpoint_hdf5(schema28_checkpoint)
        @test restored_schema28.input_summary["checkpoint_schema_version"] == "2.8"
        @test restored_schema28.input_summary["constraint_operation_scope"] == "full"
        @test restored_schema28.input_summary["checkpoint_constraint_scope_compatibility"] ==
              "LEGACY_DEFAULT_FULL"
        schema26_checkpoint = joinpath(directory, "checkpoint-schema-2.6-gradient-reset.h5")
        cp(sealed_checkpoint, schema26_checkpoint)
        schema26_digest = Base.invokelatest(
            extension.SolverCheckpoint._wannierization_checkpoint_sha256_v2_6,
            restored_sealed,
        )
        HDF5.h5open(schema26_checkpoint, "r+") do handle
            attributes = HDF5.attributes(handle)
            HDF5.delete_attribute(handle, "schema_version")
            attributes["schema_version"] = "2.6"
            HDF5.delete_attribute(handle, "checkpoint_sha256")
            attributes["checkpoint_sha256"] = schema26_digest
        end
        restored_schema26 = WANNIERIZATION.read_wannierization_checkpoint_hdf5(schema26_checkpoint)
        @test restored_schema26.input_summary["checkpoint_schema_version"] == "2.6"
        @test restored_schema26.input_summary["optimizer_history_compatibility"] ==
              "LEGACY_U_PHASE_CHART_RESET"
        @test restored_schema26.input_summary["restart_continuation_semantics"] ==
              "STATE_PRESERVED_OPTIMIZER_HISTORY_RESET_NOT_BITWISE"
        @test restored_schema26.restart_state.frames == restored_sealed.restart_state.frames
        @test restored_schema26.restart_state.z_previous == restored_sealed.restart_state.z_previous
        @test isempty(restored_schema26.restart_state.optimizer_state.previous_u_gradient)
        @test isempty(restored_schema26.restart_state.optimizer_state.previous_u_direction)
        @test restored_schema26.restart_state.optimizer_state.u_cg_iteration == 0
        @test restored_schema26.restart_state.optimizer_state.last_cg_restart_reason ==
              :LEGACY_U_PHASE_CHART_RESET
        @test any(
            diagnostic -> diagnostic.code == :LEGACY_U_PHASE_CHART_RESET,
            restored_schema26.diagnostics,
        )
        schema25_checkpoint = joinpath(directory, "checkpoint-schema-2.5-compatibility.h5")
        cp(sealed_checkpoint, schema25_checkpoint)
        schema25_digest = Base.invokelatest(
            extension.SolverCheckpoint._wannierization_checkpoint_sha256_v2_5,
            restored_sealed,
        )
        HDF5.h5open(schema25_checkpoint, "r+") do handle
            attributes = HDF5.attributes(handle)
            HDF5.delete_attribute(handle, "schema_version")
            attributes["schema_version"] = "2.5"
            HDF5.delete_attribute(handle, "checkpoint_sha256")
            attributes["checkpoint_sha256"] = schema25_digest
        end
        restored_schema25 = WANNIERIZATION.read_wannierization_checkpoint_hdf5(schema25_checkpoint)
        @test restored_schema25.input_summary["checkpoint_schema_version"] == "2.5"
        @test restored_schema25.input_summary["optimizer_history_compatibility"] ==
              "LEGACY_U_PHASE_CHART_RESET"
        @test isempty(restored_schema25.restart_state.optimizer_state.previous_u_gradient)
        @test isempty(restored_schema25.restart_state.optimizer_state.previous_u_direction)
        @test any(
            diagnostic -> diagnostic.code == :LEGACY_U_PHASE_CHART_RESET,
            restored_schema25.diagnostics,
        )
        legacy_state_source = something(persisted_result.restart_state)
        legacy_config_digest =
            something(WANNIERIZATION._restart_config_sha256_pre_v2_6(nonlocalizing_config))
        legacy_state = WANNIERIZATION.WannierizationRestartState(
            legacy_state_source.iteration,
            legacy_state_source.frames,
            legacy_state_source.z_previous,
            legacy_state_source.centers_cartesian,
            legacy_state_source.spreads_angstrom2,
            legacy_state_source.convergence_values,
            legacy_state_source.included_bands,
            legacy_state_source.elapsed_seconds,
            legacy_config_digest,
            legacy_state_source.representation_sha256,
            legacy_state_source.stencil,
            legacy_state_source.projection_basis_sha256,
            legacy_state_source.amn_sha256,
            legacy_state_source.optimizer_state,
            legacy_state_source.fixed_subspace_projectors,
            legacy_state_source.fixed_subspace_frames,
            legacy_state_source.localization_initial_frames,
        )
        legacy_summary = Dict{String, String}(persisted_result.input_summary)
        legacy_summary["restart_config_sha256"] = legacy_config_digest
        legacy_result = Base.invokelatest(
            extension.WannierizationInternalSupport.updated_wannierization_result,
            persisted_result;
            restart_state = legacy_state,
            input_summary = legacy_summary,
        )
        legacy_checkpoint = joinpath(directory, "checkpoint-real-schema-2.5-config-digest.h5")
        WANNIERIZATION.write_wannierization_checkpoint_hdf5(legacy_checkpoint, legacy_result)
        restored_legacy_current =
            WANNIERIZATION.read_wannierization_checkpoint_hdf5(legacy_checkpoint)
        legacy_checkpoint_digest = Base.invokelatest(
            extension.SolverCheckpoint._wannierization_checkpoint_sha256_v2_5,
            restored_legacy_current,
        )
        HDF5.h5open(legacy_checkpoint, "r+") do handle
            HDF5.delete_attribute(handle, "schema_version")
            HDF5.attributes(handle)["schema_version"] = "2.5"
            HDF5.delete_attribute(handle, "checkpoint_sha256")
            HDF5.attributes(handle)["checkpoint_sha256"] = legacy_checkpoint_digest
        end
        restored_legacy = WANNIERIZATION.read_wannierization_checkpoint_hdf5(legacy_checkpoint)
        resume_config = modified_wannierization_config(
            nonlocalizing_config;
            max_iterations = legacy_state.iteration + 1,
        )
        resumed_legacy = WANNIERIZATION._solve_symmetry_adapted_wannierization(
            resume_config,
            fixture.representation,
            fixture.eig,
            fixture.mmn,
            fixture.plan;
            restart_state = restored_legacy.restart_state,
            restart_history = restored_legacy.history,
        )
        @test resumed_legacy.status != WANNIERIZATION.INVALID_INPUT
        @test resumed_legacy.input_summary["restart_config_compatibility"] ==
              "PRE_V2_6_DEFAULT_RCG_CONTROLS_AND_PRE_V2_7_GRADIENT_RESET"
        @test any(
            diagnostic -> diagnostic.code == :RESTART_CONFIG_PRE_V2_6_COMPATIBILITY,
            resumed_legacy.diagnostics,
        )
        tampered_sealed_checkpoint = joinpath(directory, "checkpoint-sealed-two-stage-tampered.h5")
        cp(sealed_checkpoint, tampered_sealed_checkpoint)
        HDF5.h5open(tampered_sealed_checkpoint, "r+") do handle
            projectors = read(handle["restart_state/fixed_subspace_projectors"])
            projectors[1, 1, 1] += 1.0e-3
            write(handle["restart_state/fixed_subspace_projectors"], projectors)
        end
        @test_throws ArgumentError WANNIERIZATION.read_wannierization_checkpoint_hdf5(
            tampered_sealed_checkpoint,
        )

        schema_2_0_checkpoint = joinpath(directory, "checkpoint-schema-2.0.h5")
        cp(checkpoint_file, schema_2_0_checkpoint)
        schema_2_0_digest = Base.invokelatest(
            extension.SolverCheckpoint._wannierization_checkpoint_sha256_v1_3,
            persisted_result,
        )
        HDF5.h5open(schema_2_0_checkpoint, "r+") do handle
            attrs = HDF5.attributes(handle)
            HDF5.delete_attribute(handle, "schema_version")
            attrs["schema_version"] = "2.0"
            HDF5.delete_attribute(handle, "checkpoint_sha256")
            attrs["checkpoint_sha256"] = schema_2_0_digest
        end
        restored_2_0 = WANNIERIZATION.read_wannierization_checkpoint_hdf5(schema_2_0_checkpoint)
        @test restored_2_0.input_summary["legacy_terminal_semantics"] == "true"
        @test restored_2_0.input_summary["last_attempted_iteration"] == "-1"
        @test parse(Int, restored_2_0.input_summary["last_accepted_iteration"]) ==
              result.restart_state.iteration
        @test restored_2_0.v_matrix == result.restart_state.frames
        for version in ("2.0", "2.1", "2.2", "2.3")
            restored_2_0.input_summary["checkpoint_schema_version"] = version
            restored_2_0.input_summary["restart_eligible"] = "false"
            restart_error = try
                Base.invokelatest(
                    extension.WorkflowOrchestration._validate_restart_schema_for_continuation,
                    restored_2_0,
                )
                nothing
            catch exception
                exception
            end
            @test restart_error isa ArgumentError
            @test occursin("RESTART_SEMANTICS_INCOMPATIBLE", sprint(showerror, restart_error))
        end
        restored_2_0.input_summary["optimizer_schedule"] = "nested"
        nested_restart_error = try
            Base.invokelatest(
                extension.WorkflowOrchestration._validate_restart_schema_for_continuation,
                restored_2_0,
            )
            nothing
        catch exception
            exception
        end
        @test nested_restart_error isa ArgumentError
        @test occursin("UNSUPPORTED_LEGACY_SCHEDULE", sprint(showerror, nested_restart_error))

        failed_trial_values = fill(ComplexF64(NaN), size(result.v_matrix))
        failed_trial = WANNIERIZATION.WannierizationResult(
            WANNIERIZATION.SINGULAR_LOCALIZATION,
            failed_trial_values,
            fill(NaN, size(result.wannier_centers_cartesian)),
            fill(NaN, size(result.spreads_angstrom2)),
            result.history,
            [
                WANNIERIZATION.WannierizationDiagnostic(
                    :FAILED_TRIAL,
                    :error,
                    "non-finite rejected trial",
                ),
            ],
            merge(
                result.input_summary,
                Dict(
                    "last_attempted_iteration" => string(result.restart_state.iteration + 1),
                    "last_accepted_iteration" => string(result.restart_state.iteration),
                ),
            ),
            result.wannier_chk,
            nothing,
            result.restart_state,
            WANNIERIZATION.WannierizationArtifacts(),
        )
        failed_trial_file = joinpath(directory, "failed-trial-terminal.h5")
        WANNIERIZATION.write_wannierization_checkpoint_hdf5(failed_trial_file, failed_trial)
        retained = WANNIERIZATION.read_wannierization_checkpoint_hdf5(failed_trial_file)
        @test retained.status == WANNIERIZATION.SINGULAR_LOCALIZATION
        @test retained.v_matrix == result.restart_state.frames
        @test all(isfinite, retained.v_matrix)
        @test retained.input_summary["last_attempted_iteration"] ==
              string(result.restart_state.iteration + 1)
        @test retained.input_summary["last_accepted_iteration"] ==
              string(result.restart_state.iteration)
        @test retained.input_summary["last_persisted_iteration"] ==
              string(result.restart_state.iteration)
        for terminal_status in (
            WANNIERIZATION.COMPLETED,
            WANNIERIZATION.COMPLETED_WITH_WARNINGS,
            WANNIERIZATION.MAX_ITERATIONS,
            WANNIERIZATION.SINGULAR_LOCALIZATION,
            WANNIERIZATION.LOCALIZATION_FAILED,
            WANNIERIZATION.IO_FAILURE,
            WANNIERIZATION.INVALID_INPUT,
        )
            terminal = WANNIERIZATION.WannierizationResult(
                terminal_status,
                failed_trial.v_matrix,
                failed_trial.wannier_centers_cartesian,
                failed_trial.spreads_angstrom2,
                failed_trial.history,
                failed_trial.diagnostics,
                failed_trial.input_summary,
                failed_trial.wannier_chk,
                nothing,
                failed_trial.restart_state,
                failed_trial.artifacts,
            )
            terminal_file = joinpath(directory, "terminal-$(terminal_status).h5")
            WANNIERIZATION.write_wannierization_checkpoint_hdf5(terminal_file, terminal)
            restored_terminal = WANNIERIZATION.read_wannierization_checkpoint_hdf5(terminal_file)
            @test restored_terminal.status == terminal_status
            @test restored_terminal.v_matrix == result.restart_state.frames
            @test restored_terminal.input_summary["last_persisted_iteration"] ==
                  string(result.restart_state.iteration)
        end

        legacy_checkpoint = joinpath(directory, "checkpoint-schema-1.2.h5")
        cp(checkpoint_file, legacy_checkpoint)
        legacy_digest = Base.invokelatest(
            extension.SolverCheckpoint._wannierization_checkpoint_sha256_v1_2,
            persisted_result,
        )
        HDF5.h5open(legacy_checkpoint, "r+") do handle
            attrs = HDF5.attributes(handle)
            HDF5.delete_attribute(handle, "schema_version")
            attrs["schema_version"] = "1.2"
            HDF5.delete_attribute(handle, "checkpoint_sha256")
            attrs["checkpoint_sha256"] = legacy_digest
        end
        legacy_error = try
            WANNIERIZATION.read_wannierization_checkpoint_hdf5(legacy_checkpoint)
            nothing
        catch exception
            exception
        end
        @test legacy_error isa ArgumentError
        @test occursin("RESTART_SEMANTICS_INCOMPATIBLE", sprint(showerror, legacy_error))

        legacy_checkpoint_1_3 = joinpath(directory, "checkpoint-schema-1.3.h5")
        cp(checkpoint_file, legacy_checkpoint_1_3)
        HDF5.h5open(legacy_checkpoint_1_3, "r+") do handle
            HDF5.delete_attribute(handle, "schema_version")
            HDF5.attributes(handle)["schema_version"] = "1.3"
        end
        legacy_1_3_error = try
            WANNIERIZATION.read_wannierization_checkpoint_hdf5(legacy_checkpoint_1_3)
            nothing
        catch exception
            exception
        end
        @test legacy_1_3_error isa ArgumentError
        @test occursin("RESTART_SEMANTICS_INCOMPATIBLE", sprint(showerror, legacy_1_3_error))

        # The public writer is already 1.0; a same-number legacy-shaped capsule must
        # actually lack a required current-contract field instead of only changing its label.
        incomplete_v1_0_file = joinpath(directory, "checkpoint-incomplete-v1.0.h5")
        cp(checkpoint_file, incomplete_v1_0_file)
        HDF5.h5open(incomplete_v1_0_file, "r+") do handle
            HDF5.delete_attribute(handle, "z_u_stage_semantics")
        end
        incomplete_v1_0_error = try
            WANNIERIZATION.read_wannierization_checkpoint_hdf5(incomplete_v1_0_file)
            nothing
        catch exception
            exception
        end
        @test incomplete_v1_0_error isa ArgumentError
        @test occursin("z_u_stage_semantics", sprint(showerror, incomplete_v1_0_error))

        legacy_v1_1_file = joinpath(directory, "checkpoint-v1.1.h5")
        cp(checkpoint_file, legacy_v1_1_file)
        HDF5.h5open(legacy_v1_1_file, "r+") do handle
            HDF5.delete_attribute(handle, "schema_version")
            HDF5.attributes(handle)["schema_version"] = "1.1"
            HDF5.delete_attribute(handle, "checkpoint_sha256")
            HDF5.attributes(handle)["checkpoint_sha256"] = Base.invokelatest(
                extension.SolverCheckpoint._wannierization_checkpoint_sha256,
                persisted_result,
            )
        end
        @test_throws ArgumentError WANNIERIZATION.read_wannierization_checkpoint_hdf5(
            legacy_v1_1_file,
        )

        future_file = joinpath(directory, "checkpoint-future.h5")
        cp(checkpoint_file, future_file)
        HDF5.h5open(future_file, "r+") do handle
            HDF5.delete_attribute(handle, "schema_version")
            HDF5.attributes(handle)["schema_version"] = "9.9"
        end
        @test_throws ArgumentError WANNIERIZATION.read_wannierization_checkpoint_hdf5(future_file)

        tampered_file = joinpath(directory, "checkpoint-tampered.h5")
        cp(checkpoint_file, tampered_file)
        HDF5.h5open(tampered_file, "r+") do handle
            HDF5.delete_attribute(handle, "config_sha256")
            HDF5.attributes(handle)["config_sha256"] = repeat("f", 64)
        end
        @test_throws ArgumentError WANNIERIZATION.read_wannierization_checkpoint_hdf5(tampered_file)

        optimizer_tampered = joinpath(directory, "checkpoint-optimizer-tampered.h5")
        cp(checkpoint_file, optimizer_tampered)
        HDF5.h5open(optimizer_tampered, "r+") do handle
            optimizer_attributes = HDF5.attributes(handle["restart_state/optimizer"])
            HDF5.delete_attribute(handle["restart_state/optimizer"], "z_mix_ratio")
            optimizer_attributes["z_mix_ratio"] = 0.123
        end
        @test_throws ArgumentError WANNIERIZATION.read_wannierization_checkpoint_hdf5(
            optimizer_tampered,
        )

        failed = WANNIERIZATION.WannierizationResult(
            WANNIERIZATION.MAX_ITERATIONS,
            result.v_matrix,
            result.wannier_centers_cartesian,
            result.spreads_angstrom2,
            result.history,
            [WANNIERIZATION.WannierizationDiagnostic(:TEST_NONCONVERGENCE, :warning, "fixture")],
            result.input_summary,
            result.wannier_chk,
            nothing,
            result.restart_state,
            WANNIERIZATION.WannierizationArtifacts(),
        )
        failed_path = WANNIERIZATION.write_wannierization_checkpoint_hdf5(checkpoint_file, failed)
        @test failed_path == abspath(checkpoint_file)
        @test isfile(checkpoint_file)
        failed_restored = WANNIERIZATION.read_wannierization_checkpoint_hdf5(checkpoint_file)
        @test failed_restored.status == WANNIERIZATION.MAX_ITERATIONS
        @test getfield.(failed_restored.history, :diagnostics) ==
              getfield.(failed.history, :diagnostics)
        HDF5.h5open(checkpoint_file, "r") do handle
            @test String(read(HDF5.attributes(handle)["schema_version"])) == "1.0"
            @test !Bool(read(HDF5.attributes(handle)["converged"]))
            @test Bool(read(HDF5.attributes(handle)["diagnostic_only"]))
            @test Int(read(HDF5.attributes(handle)["last_accepted_iteration"])) ==
                  result.restart_state.iteration
            @test Int(read(HDF5.attributes(handle)["last_persisted_iteration"])) ==
                  result.restart_state.iteration
        end
        exact_reference_state = (
            wannier90_reference_overlaps = ones(ComplexF64, 1, 1, 1, 1),
            wannier90_reference_unitaries = ones(ComplexF64, 1, 1, 1),
            wannier90_reference_omega_i = 0.0,
        )
        ordinary_rcg_state = (
            wannier90_reference_overlaps = zeros(ComplexF64, 0, 0, 0, 0),
            wannier90_reference_unitaries = zeros(ComplexF64, 0, 0, 0),
            wannier90_reference_omega_i = NaN,
        )
        incomplete_reference_state = (
            wannier90_reference_overlaps = ones(ComplexF64, 1, 1, 1, 1),
            wannier90_reference_unitaries = zeros(ComplexF64, 0, 0, 0),
            wannier90_reference_omega_i = 0.0,
        )
        @test Base.invokelatest(
            extension.SolverCheckpoint._checkpoint_cg_iteration_is_valid,
            exact_reference_state,
            0,
        )
        @test !Base.invokelatest(
            extension.SolverCheckpoint._checkpoint_cg_iteration_is_valid,
            ordinary_rcg_state,
            0,
        )
        @test Base.invokelatest(
            extension.SolverCheckpoint._checkpoint_cg_iteration_is_valid,
            ordinary_rcg_state,
            1,
        )
        @test_throws ArgumentError Base.invokelatest(
            extension.SolverCheckpoint._checkpoint_cg_iteration_is_valid,
            incomplete_reference_state,
            0,
        )

        construction_diagnostics = Dict{String, Any}()
        model = WANNIERIZATION.build_wannier_tight_binding_model(
            result,
            fixture.eig,
            fixture.mmn;
            construction_diagnostics,
        )
        @test construction_diagnostics["real_space_replica_policy"] == "minimum_distance"
        @test construction_diagnostics["hamiltonian_fourier_roundtrip_residual"] <= 1.0e-10
        @test construction_diagnostics["position_fourier_roundtrip_residual"] <= 1.0e-10
        incomplete_mmn = WANNIER_IO.WannierMMN(
            fixture.mmn.num_bands,
            fixture.mmn.num_kpts,
            2,
            fixture.mmn.data[:, :, 1:2, :],
            fixture.mmn.neighbors[1:2, :],
            fixture.mmn.reciprocal_shifts[:, 1:2, :],
        )
        @test_throws ArgumentError WANNIERIZATION.build_wannier_tight_binding_model(
            result,
            fixture.eig,
            incomplete_mmn,
        )
        diagnostic_model =
            WANNIERIZATION.build_wannier_tight_binding_model(failed, fixture.eig, fixture.mmn)
        @test diagnostic_model.hamiltonian_r == model.hamiltonian_r
        @test_throws ArgumentError WANNIERIZATION.build_wannier_tight_binding_model(
            restored_221,
            fixture.eig,
            fixture.mmn,
        )
        legacy_diagnostic_model = WANNIERIZATION.build_wannier_tight_binding_model(
            restored_221,
            fixture.eig,
            fixture.mmn;
            allow_legacy_diagnostic_export = true,
        )
        @test legacy_diagnostic_model.hamiltonian_r == model.hamiltonian_r
        @test Base.invokelatest(
            extension.OperatorExport._real_space_hermiticity_error,
            model.position_r,
            model.r_vectors,
        ) <= 1.0e-14
        @test Base.invokelatest(extension.OperatorExport._tb_centers, model) ≈
              result.wannier_centers_cartesian atol = 1.0e-14 rtol = 0.0
        perturbed_mmn_data = copy(fixture.mmn.data)
        perturbed_mmn_data[1, 1, 1, 1] += 0.03 + 0.02im
        perturbed_mmn = WANNIER_IO.WannierMMN(
            fixture.mmn.num_bands,
            fixture.mmn.num_kpts,
            fixture.mmn.num_neighbors,
            perturbed_mmn_data,
            fixture.mmn.neighbors,
            fixture.mmn.reciprocal_shifts,
        )
        perturbed_model =
            WANNIERIZATION.build_wannier_tight_binding_model(result, fixture.eig, perturbed_mmn)
        @test Base.invokelatest(
            extension.OperatorExport._real_space_hermiticity_error,
            perturbed_model.position_r,
            perturbed_model.r_vectors,
        ) <= 1.0e-14
        @test Base.invokelatest(extension.OperatorExport._tb_centers, perturbed_model) ≈
              result.wannier_centers_cartesian atol = 1.0e-14 rtol = 0.0
        output_config = WANNIERIZATION._replace_wannierization_config(
            fixture.config;
            checkpoint = (checkpoint_hdf5 = joinpath(directory, "synthetic.wannierization.h5"),),
            output = (tb_output_formats = (:packed_hdf5, :wannier90_tb), write_wannier90_tb = true),
        )
        paths = Base.invokelatest(
            extension.OperatorExport._wannierization_output_paths,
            output_config.checkpoint.checkpoint_hdf5,
        )
        @test paths.validated == joinpath(directory, "synthetic.wannierization.validated.h5")
        @test paths.log == joinpath(directory, "synthetic.wannierization.out")
        @test paths.packed == joinpath(directory, "synthetic.wannierization-tb.h5")
        @test paths.wannier90 == joinpath(directory, "synthetic_wannierization_tb.dat")
        @test paths.tb_symmetry_json ==
              joinpath(directory, "synthetic.wannierization-tb-symmetry.json")
        @test_throws ArgumentError Base.invokelatest(
            extension.OperatorExport._wannierization_output_paths,
            joinpath(directory, "legacy.sawf.h5"),
        )
        @test_throws ArgumentError WANNIERIZATION.write_wannierization_checkpoint_hdf5(
            joinpath(directory, "legacy.sawf.h5"),
            result,
        )
        diagnostic_packed, diagnostic_exchange, diagnostic_metadata = Base.invokelatest(
            extension.OperatorExport._export_wannierization_tb,
            failed,
            fixture.eig,
            fixture.mmn,
            output_config,
            paths,
            nothing,
        )
        @test isfile(diagnostic_packed)
        @test isfile(diagnostic_exchange)
        @test diagnostic_metadata["diagnostic_classification"] == "MAX_ITERATIONS_DIAGNOSTIC"
        @test parse(Float64, diagnostic_metadata["tb_hamiltonian_fourier_roundtrip_residual"]) <=
              1.0e-10
        @test parse(Float64, diagnostic_metadata["tb_position_fourier_roundtrip_residual"]) <=
              1.0e-10
        diagnostic_manifest = WANNIER_IO.read_real_space_operator_bundle_manifest(diagnostic_packed)
        @test diagnostic_manifest.diagnostic_only
        @test !something(diagnostic_manifest.production_eligible, true)
        hamiltonian_qualification =
            diagnostic_manifest.operator_qualification["operators"]["hamiltonian"]
        authority_contract_sha256 = Base.invokelatest(
            extension.PAWMatrixElements._star_authoritative_hamiltonian_sha256,
            output_config.input.authoritative_hamiltonian,
        )
        raw_authority = Base.invokelatest(
            extension.OperatorExport.authoritative_band_hamiltonian,
            output_config,
            fixture.eig,
        )
        @test !haskey(raw_authority.input_sha256, "AUTHORITATIVE_HAMILTONIAN_SHA256")
        @test raw_authority.digest == diagnostic_manifest.authoritative_hamiltonian_sha256
        @test hamiltonian_qualification["authoritative_hamiltonian_input_sha256"]["AUTHORITATIVE_HAMILTONIAN_SHA256"] ==
              authority_contract_sha256
        @test hamiltonian_qualification["authoritative_hamiltonian_digest"] ==
              diagnostic_manifest.authoritative_hamiltonian_sha256
        @test authority_contract_sha256 != diagnostic_manifest.authoritative_hamiltonian_sha256
        packed, exchange, _ = Base.invokelatest(
            extension.OperatorExport._export_wannierization_tb,
            result,
            fixture.eig,
            fixture.mmn,
            output_config,
            paths,
            nothing,
        )
        manifest = WANNIER_IO.read_real_space_operator_bundle_manifest(packed)
        @test manifest.input_sha256 == result.input_summary["input_sha256"]
        @test something(manifest.solver_validation_ready, false)
        @test !manifest.post_validation_present

        source_digest = bytes2hex(open(SHA.sha256, packed))
        validated = joinpath(directory, "validated.wannierization-tb.h5")
        cp(packed, validated)
        operator_extension = Base.get_extension(WannierNLQG, :WannierNLQGOperatorBundleExt)
        @test operator_extension !== nothing
        validation_values = Dict(
            "source_bundle_sha256" => source_digest,
            "band_validation_summary_sha256" => repeat("1", 64),
            "response_validation_summary_sha256" => repeat("2", 64),
            "final_tb_usability" => "DIAGNOSTIC_MODEL_AVAILABLE",
            "final_physics_qualification" => "PHYSICS_HOLD",
            "final_production_eligible" => false,
        )
        validation_digest =
            Base.invokelatest(operator_extension._post_export_validation_digest, validation_values)
        HDF5.h5open(validated, "r+") do handle
            group = HDF5.create_group(handle, "post_export_validation")
            attrs = HDF5.attributes(group)
            attrs["schema"] = "wanniernlqg.post-export-validation"
            attrs["schema_version"] = "1.0"
            for (name, value) in validation_values
                attrs[name] = value
            end
            attrs["validation_content_sha256"] = validation_digest
        end
        validated_manifest = WANNIER_IO.read_real_space_operator_bundle_manifest(validated)
        @test validated_manifest.post_validation_present
        @test validated_manifest.final_tb_usability == "DIAGNOSTIC_MODEL_AVAILABLE"
        @test validated_manifest.final_physics_qualification == "PHYSICS_HOLD"
        @test validated_manifest.final_production_eligible == false
        @test validated_manifest.post_validation_source_sha256 == source_digest
        @test validated_manifest.post_validation_content_sha256 == validation_digest
        @test validated_manifest.scientific_content_sha256 == manifest.scientific_content_sha256
        @test bytes2hex(open(SHA.sha256, packed)) == source_digest

        tampered = joinpath(directory, "tampered.wannierization-tb.h5")
        cp(validated, tampered)
        HDF5.h5open(tampered, "r+") do handle
            group = handle["post_export_validation"]
            HDF5.delete_attribute(group, "final_tb_usability")
            HDF5.attributes(group)["final_tb_usability"] = "PRODUCTION_ELIGIBLE"
        end
        @test_throws ArgumentError WANNIER_IO.read_real_space_operator_bundle_manifest(tampered)

        converged_packed, converged_exchange = packed, exchange
        eligible_result = WANNIERIZATION.WannierizationResult(
            result.status,
            result.v_matrix,
            result.wannier_centers_cartesian,
            result.spreads_angstrom2,
            result.history,
            result.diagnostics,
            result.input_summary,
            result.wannier_chk,
            checkpoint_file,
            result.restart_state,
            WANNIERIZATION.WannierizationArtifacts(
                checkpoint_hdf5 = checkpoint_file,
                packed_hdf5 = converged_packed,
                wannier90_tb = converged_exchange,
            ),
        )
        WANNIERIZATION.write_wannierization_checkpoint_hdf5(checkpoint_file, eligible_result)
        historical_suffix = joinpath(directory, "historical.sawf.h5")
        cp(checkpoint_file, historical_suffix)
        historical_sha256 = bytes2hex(SHA.sha256(read(historical_suffix)))
        historical_result = WANNIERIZATION.read_wannierization_checkpoint_hdf5(historical_suffix)
        @test historical_result.v_matrix == eligible_result.v_matrix
        @test bytes2hex(SHA.sha256(read(historical_suffix))) == historical_sha256
        HDF5.h5open(checkpoint_file, "r") do handle
            @test !Bool(read(HDF5.attributes(handle)["production_eligible"]))
            @test Bool(read(HDF5.attributes(handle)["diagnostic_only"]))
        end
        band_qualified = Base.invokelatest(
            extension.WannierizationInternalSupport.updated_wannierization_result,
            eligible_result;
            input_summary = merge(
                eligible_result.input_summary,
                Dict(
                    "optimizer_schedule" => "two_stage",
                    "u_acceptance" => "armijo",
                    "representation_compatible" => "true",
                    "physics_qualification" => "QUALIFIED",
                    "band_validation_pass" => "true",
                    "z_seal_class" => "CONVERGED",
                    "qualified_z_seal" => "true",
                    "standard_tb_export_eligible" => "true",
                ),
            ),
            tb_symmetry_qualification = WANNIERIZATION.TBSymmetryQualification(
                "PASS",
                "SYNTHETIC_PRODUCTION_GATE_FIXTURE",
                WANNIERIZATION.TBSymmetryMetric[],
            ),
        )
        @test Base.invokelatest(
            extension.SolverCheckpoint._wannierization_production_eligible,
            band_qualified,
        )
        no_symmetry_qualified = Base.invokelatest(
            extension.WannierizationInternalSupport.updated_wannierization_result,
            band_qualified;
            input_summary = merge(
                band_qualified.input_summary,
                Dict("representation_compatible" => "NOT_APPLICABLE"),
            ),
            tb_symmetry_qualification = Base.invokelatest(
                extension.OperatorExport._tb_symmetry_incomplete,
                "NONTRIVIAL_SYMMETRY_PLAN_NOT_AVAILABLE",
                1.0e-8,
            ),
        )
        @test !Base.invokelatest(
            extension.SolverCheckpoint._wannierization_production_eligible,
            no_symmetry_qualified,
        )
        diagnostic_acceptance = Base.invokelatest(
            extension.WannierizationInternalSupport.updated_wannierization_result,
            band_qualified;
            input_summary = merge(band_qualified.input_summary, Dict("u_acceptance" => "monotone")),
        )
        @test !Base.invokelatest(
            extension.SolverCheckpoint._wannierization_production_eligible,
            diagnostic_acceptance,
        )
        converged_manifest = WANNIER_IO.read_real_space_operator_bundle_manifest(converged_packed)
        @test !converged_manifest.production_eligible
        @test converged_manifest.tb_usability == "DIAGNOSTIC_MODEL_AVAILABLE"
        @test converged_manifest.physics_qualification == "PENDING_DOWNSTREAM_VALIDATION"
        @test model.num_orbitals == 1
        for kpoint in ([0.0, 0.0, 0.0], [0.173, 0.0, 0.0], [0.5, 0.0, 0.0])
            hamiltonian = sum(
                cis(2.0pi * dot(kpoint, model.r_vectors[:, r_index])) *
                model.hamiltonian_r[:, :, r_index] for r_index in 1:model.num_r_vectors
            )
            @test maximum(abs, hamiltonian - hamiltonian') <= 1.0e-12
        end

        report = WANNIERIZATION.validate_band_representation_compatibility(
            fixture.representation,
            fixture.plan;
            tolerance = fixture.config.input.representation_tolerance,
        )
        log_file = joinpath(directory, "synthetic.wannierization.out")
        log_io = Base.invokelatest(
            extension.OperatorExport._open_wannierization_log,
            log_file,
            output_config,
            fixture.representation;
            compatibility = report,
            restart = false,
        )
        snapshot = (
            iteration = 2,
            spread_total = 1.0,
            convergence_metric = 0.5,
            maximum_covariance_error = 0.25,
            little_group_iterations = 3,
            little_group_residual = 0.125,
            elapsed_seconds = 4.0,
            centers = result.wannier_centers_cartesian,
            spreads = result.spreads_angstrom2,
        )
        Base.invokelatest(
            extension.OperatorExport._write_wannierization_progress,
            log_io,
            snapshot,
            checkpoint_file,
            output_config,
        )
        Base.invokelatest(
            extension.OperatorExport._write_wannierization_final,
            log_io,
            failed,
            output_config,
            WANNIERIZATION.WannierizationArtifacts(
                checkpoint_hdf5 = checkpoint_file,
                wannierization_log = log_file,
                packed_hdf5 = packed,
                wannier90_tb = exchange,
            );
            wall_time = 5.0,
            allocated_bytes = 6,
            gc_time = 0.5,
        )
        close(log_io)
        log_text = read(log_file, String)
        @test occursin(r"source_sha256\s+=\s+", log_text)
        @test occursin(r"include_time_reversal\s+=\s+false", log_text)
        @test occursin("WannierNLQG WANNIERIZATION — HUMAN-READABLE OUTPUT", log_text)
        @test occursin(
            Regex("optimization_schedule\\s+=\\s+$(output_config.solver.acceleration.schedule)"),
            log_text,
        )
        @test occursin(
            Regex(
                "disentanglement_max_steps\\s+=\\s+$(output_config.solver.acceleration.disentanglement_max_steps)",
            ),
            log_text,
        )
        @test occursin(
            Regex(
                "localization_max_steps\\s+=\\s+$(output_config.solver.acceleration.localization_max_steps)",
            ),
            log_text,
        )
        @test occursin("convergence_metric              = 0.5", log_text)
        @test occursin("metric_to_tolerance_ratio", log_text)
        @test occursin("Per-Wannier-state spreading", log_text)
        @test occursin("CONSTRUCTION GATE AND DIAGNOSTIC SUMMARY", log_text)
        @test occursin("FINAL SPREADING", log_text)
        @test occursin("FINAL TB SYMMETRY QUALIFICATION (diagnostic model)", log_text)
        @test occursin("FINAL STATUS", log_text)
        @test occursin(r"wannierization_log\s+=\s+", log_text)
        @test !occursin(log_file, log_text)
        @test occursin(basename(log_file), log_text)
        @test isfile(replace(log_file, r"\.out$" => "-diagnostics.jsonl"))

        ordinary_auto = WANNIERIZATION._replace_wannierization_config(
            output_config;
            input = (wannierization_mode = :ordinary, band_representation = nothing),
            output = (final_tb_symmetry_report_enabled = nothing,),
        )
        ordinary_log = joinpath(directory, "ordinary-auto.wannierization.out")
        ordinary_io = open(ordinary_log, "w")
        Base.invokelatest(
            extension.OperatorExport._write_wannierization_final,
            ordinary_io,
            failed,
            ordinary_auto,
            WANNIERIZATION.WannierizationArtifacts(wannierization_log = ordinary_log);
            wall_time = 0.0,
            allocated_bytes = 0,
            gc_time = 0.0,
        )
        close(ordinary_io)
        @test !occursin(
            "FINAL TB SYMMETRY QUALIFICATION (diagnostic model)",
            read(ordinary_log, String),
        )
        ordinary_forced = WANNIERIZATION._replace_wannierization_config(
            ordinary_auto;
            output = (final_tb_symmetry_report_enabled = true,),
        )
        forced_log = joinpath(directory, "ordinary-forced.wannierization.out")
        forced_io = open(forced_log, "w")
        Base.invokelatest(
            extension.OperatorExport._write_wannierization_final,
            forced_io,
            failed,
            ordinary_forced,
            WANNIERIZATION.WannierizationArtifacts(wannierization_log = forced_log);
            wall_time = 0.0,
            allocated_bytes = 0,
            gc_time = 0.0,
        )
        close(forced_io)
        forced_text = read(forced_log, String)
        @test occursin("FINAL TB SYMMETRY QUALIFICATION (diagnostic model)", forced_text)
        @test occursin(r"overall\s+=\s+NOT_RUN", forced_text)
        @test occursin(r"source\s+=\s+qualification_not_run", forced_text)
        @test !occursin("final_exported_and_read_back_tb", forced_text)

        ordinary_qualification = Base.invokelatest(
            extension.OperatorExport.qualify_exported_wannierization_tb,
            diagnostic_packed,
            nothing,
            nothing;
            hamiltonian_covariance_threshold = fixture.config.input.representation_tolerance,
            persist_hdf5 = false,
        )
        @test ordinary_qualification.overall == "INCOMPLETE"
        @test any(metric -> metric.status == "NOT_APPLICABLE", ordinary_qualification.metrics)
        ordinary_incomplete = Base.invokelatest(
            extension.WannierizationInternalSupport.updated_wannierization_result,
            failed;
            tb_symmetry_qualification = ordinary_qualification,
        )
        ordinary_incomplete_log =
            joinpath(directory, "ordinary-forced-incomplete.wannierization.out")
        ordinary_incomplete_io = open(ordinary_incomplete_log, "w")
        ordinary_incomplete_artifacts = WANNIERIZATION.WannierizationArtifacts(
            wannierization_log = ordinary_incomplete_log,
            packed_hdf5 = diagnostic_packed,
        )
        Base.invokelatest(
            extension.OperatorExport._write_wannierization_final,
            ordinary_incomplete_io,
            ordinary_incomplete,
            ordinary_forced,
            ordinary_incomplete_artifacts;
            wall_time = 0.0,
            allocated_bytes = 0,
            gc_time = 0.0,
        )
        close(ordinary_incomplete_io)
        ordinary_incomplete_text = read(ordinary_incomplete_log, String)
        @test occursin(r"overall\s+=\s+INCOMPLETE", ordinary_incomplete_text)
        @test occursin("NOT_APPLICABLE", ordinary_incomplete_text)
        @test occursin(r"source\s+=\s+final_exported_and_read_back_tb", ordinary_incomplete_text)

        symmetry_disabled = WANNIERIZATION._replace_wannierization_config(
            output_config;
            output = (final_tb_symmetry_report_enabled = false,),
        )
        symmetry_disabled_log = joinpath(directory, "symmetry-disabled.wannierization.out")
        symmetry_disabled_io = open(symmetry_disabled_log, "w")
        Base.invokelatest(
            extension.OperatorExport._write_wannierization_final,
            symmetry_disabled_io,
            failed,
            symmetry_disabled,
            WANNIERIZATION.WannierizationArtifacts(wannierization_log = symmetry_disabled_log);
            wall_time = 0.0,
            allocated_bytes = 0,
            gc_time = 0.0,
        )
        close(symmetry_disabled_io)
        @test !occursin(
            "FINAL TB SYMMETRY QUALIFICATION (diagnostic model)",
            read(symmetry_disabled_log, String),
        )

        disabled_config = modified_wannierization_config(
            output_config;
            progress_interval = 0,
            checkpoint_interval = 0,
        )
        disabled_paths = Base.invokelatest(
            extension.OperatorExport._wannierization_output_paths,
            joinpath(directory, "disabled.wannierization.h5"),
        )
        disabled_log = joinpath(directory, "disabled-observer.out")
        disabled_io = open(disabled_log, "w")
        disabled_observer = Base.invokelatest(
            extension.OperatorExport._wannierization_observer,
            disabled_config,
            fixture.representation,
            disabled_paths,
            disabled_io,
        )
        Base.invokelatest(
            disabled_observer,
            snapshot,
            something(result.restart_state),
            result.history,
            result.diagnostics,
        )
        close(disabled_io)
        @test !isfile(disabled_paths.checkpoint)
        @test isempty(read(disabled_log, String))

        in_progress = WANNIERIZATION.WannierizationResult(
            WANNIERIZATION.IN_PROGRESS_CHECKPOINT,
            result.v_matrix,
            result.wannier_centers_cartesian,
            result.spreads_angstrom2,
            result.history,
            result.diagnostics,
            result.input_summary,
            result.wannier_chk,
            nothing,
        )
        @test_throws ArgumentError WANNIERIZATION.build_wannier_tight_binding_model(
            in_progress,
            fixture.eig,
            fixture.mmn,
        )
        missing_chk = WANNIERIZATION.WannierizationResult(
            WANNIERIZATION.MAX_ITERATIONS,
            result.v_matrix,
            result.wannier_centers_cartesian,
            result.spreads_angstrom2,
            result.history,
            result.diagnostics,
            result.input_summary,
            nothing,
            nothing,
        )
        @test_throws ArgumentError WANNIERIZATION.build_wannier_tight_binding_model(
            missing_chk,
            fixture.eig,
            fixture.mmn,
        )
        nonfinite_values = copy(result.v_matrix)
        nonfinite_values[1] = NaN + 0.0im
        nonfinite = WANNIERIZATION.WannierizationResult(
            WANNIERIZATION.MAX_ITERATIONS,
            nonfinite_values,
            result.wannier_centers_cartesian,
            result.spreads_angstrom2,
            result.history,
            result.diagnostics,
            result.input_summary,
            result.wannier_chk,
            nothing,
        )
        @test_throws ArgumentError Base.invokelatest(
            extension.OperatorExport._export_wannierization_tb,
            nonfinite,
            fixture.eig,
            fixture.mmn,
            output_config,
            paths,
            nothing,
        )

        packed_only_config = WANNIERIZATION._replace_wannierization_config(
            fixture.config;
            checkpoint = (checkpoint_hdf5 = joinpath(directory, "packed-only.wannierization.h5"),),
            output = (tb_output_formats = (), write_wannier90_tb = false),
        )
        packed_only_paths = Base.invokelatest(
            extension.OperatorExport._wannierization_output_paths,
            packed_only_config.checkpoint.checkpoint_hdf5,
        )
        packed_only, optional_tb = Base.invokelatest(
            extension.OperatorExport._export_wannierization_tb,
            result,
            fixture.eig,
            fixture.mmn,
            packed_only_config,
            packed_only_paths,
            nothing,
        )
        @test isfile(packed_only)
        @test optional_tb === nothing
        @test !isfile(packed_only_paths.wannier90)
    end
end

@testset "Native wavefunction parsing negative contracts" begin
    extension, _ = WANNIERIZATION._load_wannierization_extension!()
    mktempdir() do directory
        truncated = joinpath(directory, "WAVECAR")
        write(truncated, zeros(UInt8, 8))
        @test_throws ArgumentError open(truncated, "r") do io
            WannierNLQG.SymmetryFoundation.read_values_at(io, Float64, 0, 2)
        end
    end
    @test_throws ArgumentError extension.RepresentationPreparation._qe_record_values(
        UInt8[0x00, 0x01, 0x02],
        Float64,
    )
end

@testset "U-convergence recovery numerical primitives" begin
    rng = MersenneTwister(0x51a7)
    left = Matrix(qr(randn(rng, ComplexF64, 4, 4)).Q)
    right = Matrix(qr(randn(rng, ComplexF64, 4, 4)).Q)
    matrix = left * Diagonal([3.0, 2.0, 1.0, 0.5]) * right'
    polar = WANNIERIZATION._localization_svd_polar(matrix, 1.0e-10, 1.0e10)
    legacy = WANNIERIZATION._orthonormalize_columns(inv(matrix)', 1.0e-10)
    @test polar.success
    @test polar.rank == 4
    @test polar.condition ≈ 6.0
    @test polar.unitary ≈ something(legacy) atol = 1.0e-12

    rank_failure =
        WANNIERIZATION._localization_svd_polar(Diagonal(ComplexF64[1.0, 1.0e-12]), 1.0e-10, 1.0e10)
    @test !rank_failure.success
    @test rank_failure.code == :LOCALIZATION_POLAR_RANK_DEFICIENT
    condition_failure =
        WANNIERIZATION._localization_svd_polar(Diagonal(ComplexF64[1.0, 1.0e-11]), 1.0e-12, 1.0e10)
    @test !condition_failure.success
    @test condition_failure.code == :LOCALIZATION_POLAR_ILL_CONDITIONED

    assignment =
        WANNIERIZATION_IMPLEMENTATION.WannierizationInternalSupport.hungarian_maximum_assignment(
            [0.1 0.9 0.0; 0.8 0.1 0.0; 0.0 0.0 1.0],
        )
    @test assignment == [2, 1, 3]
    old = Matrix{ComplexF64}(I, 2, 2)
    branch = WANNIERIZATION._unitary_geodesic_plan(old, -old, 1.0e-10)
    @test !branch.success
    @test branch.code == :U_GEODESIC_BRANCH_AMBIGUOUS
    full_tangent =
        WANNIERIZATION._target_symmetry_tangent_plan([copy(old)], [false]; tolerance = 1.0e-10)
    @test size(full_tangent.basis, 2) == 8
    projected_probe =
        WANNIERIZATION._project_target_symmetry_tangent(full_tangent, ComplexF64[0 1; -1 0])
    @test projected_probe ≈ ComplexF64[0 1; -1 0] atol = 1.0e-12
    permutation, phases =
        WANNIERIZATION._global_permutation_phase_diagnostic([old], [old * ComplexF64[0 1; 1 0]])
    @test permutation == [2, 1]
    @test phases ≈ zeros(2) atol = 1.0e-14
    diagnostic_old = [copy(old), copy(old)]
    diagnostic_transform = ComplexF64[0 cis(0.3); cis(-0.2) 0]
    diagnostic_new = [frame * diagnostic_transform for frame in diagnostic_old]
    diagnostic_old_copy = deepcopy(diagnostic_old)
    WANNIERIZATION._global_permutation_phase_diagnostic(diagnostic_old, diagnostic_new)
    @test diagnostic_old == diagnostic_old_copy
    @test WANNIERIZATION._backtracking_step_scale(1.0, 0.5, 12) == 2.0^-12
    @test !WANNIERIZATION._localization_objective_accepts(
        :polar_then_gradient,
        :monotone,
        1.0,
        1.01,
        1.0e-12,
        1.0,
        0.0,
        1.0e-4,
    )
    @test WANNIERIZATION._localization_objective_accepts(
        :polar_then_gradient,
        :monotone,
        1.0,
        1.0 - 1.0e-8,
        1.0e-12,
        0.5,
        0.0,
        1.0e-4,
    )
    @test !WANNIERIZATION._localization_objective_accepts(
        :symmetry_projected_gradient,
        :armijo,
        1.0,
        1.0 - 1.0e-8,
        1.0e-12,
        0.5,
        1.0,
        1.0e-4,
    )
    @test WANNIERIZATION._localization_objective_accepts(
        :symmetry_projected_gradient,
        :invariant_only,
        1.0,
        1.25,
        0.0,
        1.0,
        1.0,
        1.0e-4,
    )
    @test !WANNIERIZATION._localization_objective_accepts(
        :symmetry_projected_gradient,
        :armijo,
        1.0,
        1.0 + 1.0e-14,
        1.0e-12,
        1.0e-6,
        -1.0,
        1.0e-4,
    )
    @test WANNIERIZATION._localization_objective_accepts(
        :riemannian_cg,
        :strong_wolfe,
        1.0,
        0.9,
        0.0,
        0.2,
        -1.0,
        1.0e-4;
        trial_directional_derivative = -0.2,
        wolfe_c2 = 0.9,
    )
    @test !WANNIERIZATION._localization_objective_accepts(
        :riemannian_cg,
        :strong_wolfe,
        1.0,
        0.9,
        0.0,
        0.2,
        -1.0,
        1.0e-4;
        trial_directional_derivative = -0.95,
        wolfe_c2 = 0.9,
    )
    restart_candidate = (objective = 0.9, mode = :gradient)
    @test WANNIERIZATION._best_fletcher_reeves_finite_descent(
        nothing,
        restart_candidate,
        :symmetry_projected_smv_fletcher_reeves_two_stage,
        nothing,
        1.0,
    ) === restart_candidate
    @test WANNIERIZATION._best_fletcher_reeves_finite_descent(
        nothing,
        restart_candidate,
        :symmetry_projected_gradient,
        nothing,
        1.0,
    ) === nothing
    @test WANNIERIZATION._best_fletcher_reeves_finite_descent(
        nothing,
        restart_candidate,
        :symmetry_projected_smv_fletcher_reeves_two_stage,
        (:FIXED_SUBSPACE_PROJECTOR_DRIFT, 1.0e-4),
        1.0,
    ) === nothing
    better_restart_candidate = (objective = 0.8, mode = :gradient)
    @test WANNIERIZATION._best_fletcher_reeves_finite_descent(
        restart_candidate,
        better_restart_candidate,
        :symmetry_projected_smv_fletcher_reeves_two_stage,
        nothing,
        1.0,
    ) === better_restart_candidate
    branch_mmn = WANNIER_IO.WannierMMN(
        1,
        1,
        1,
        reshape(ComplexF64[cis(pi - 1.0e-10)], 1, 1, 1, 1),
        ones(Int, 1, 1),
        zeros(Int, 3, 1, 1),
    )
    @test WANNIERIZATION._minimum_diagonal_phase_margin([ones(ComplexF64, 1, 1)], branch_mmn) ≈
          1.0e-10 atol = 1.0e-14 rtol = 0.0

    # The diagonal phase remains safely inside its principal branch while the
    # physical MV combination crosses +pi.  The center contribution must not
    # be folded back by a second `angle` call.
    phase_diagonal = cis(pi - 0.4)
    phase_center = [0.7, 0.0, 0.0]
    phase_neighbor = [1.0, 0.0, 0.0]
    unwrapped_phase =
        WANNIERIZATION._mv_localization_phase(phase_diagonal, phase_center, phase_neighbor)
    doubly_wrapped_phase = angle(phase_diagonal * cis(dot(phase_center, phase_neighbor)))
    @test pi - abs(angle(phase_diagonal)) > 0.3
    @test unwrapped_phase > pi
    @test unwrapped_phase ≈ pi + 0.3 atol = 1.0e-14 rtol = 0.0
    @test doubly_wrapped_phase ≈ unwrapped_phase - 2pi atol = 1.0e-14 rtol = 0.0
    @test WANNIERIZATION_IMPLEMENTATION.SolverCheckpoint.LOCALIZATION_GRADIENT_CONTRACT ==
          "mv_centered_residual_unwrapped_delta_v2"

    one_step = vcat(fill(NaN, 2), ones(48))
    two_step = vcat(fill(NaN, 2), ones(38), fill(1.0e-3, 10))
    aligned = copy(one_step)
    @test WANNIERIZATION.classify_wannierization_u_periodicity(one_step, two_step, aligned) ==
          :PERIOD_2_CONFIRMED
    @test WANNIERIZATION.classify_wannierization_u_periodicity(
        ones(50),
        ones(50),
        vcat(ones(40), fill(1.0e-12, 10)),
    ) == :PERIOD_2_NOT_CONFIRMED
    @test WANNIERIZATION.classify_wannierization_u_periodicity(ones(49), ones(49), ones(49)) ==
          :PERIOD_UNDETERMINED

    fixture = synthetic_wannierization_fixture()
    gradient_frames =
        [Matrix{ComplexF64}(I, 2, 2), ComplexF64[cos(0.3) sin(0.3); -sin(0.3) cos(0.3)]]
    gradient_centers = zeros(2, 3)
    gradient_weights =
        WANNIERIZATION._finite_difference_weights(fixture.representation, fixture.mmn).weights
    gradient = WANNIERIZATION._mv_spread_gradient(
        gradient_frames,
        gradient_centers,
        fixture.representation,
        fixture.mmn,
        gradient_weights,
        1.0e-10,
    )
    @test gradient.success
    @test all(value -> maximum(abs, value + value') <= 1.0e-12, gradient.gradients)
    gradient_plan = WannierNLQG.SymmetryFoundation.WannierSymmetryPlan(
        fixture.representation.operations,
        reshape(Matrix{ComplexF64}(I, 2, 2), 2, 2, 1),
        zeros(Int, 3, 2, 1),
    )
    tangent_plans = WANNIERIZATION._build_target_symmetry_tangent_plans(
        fixture.representation,
        gradient_plan;
        tolerance = 1.0e-10,
    )
    evaluation_config = modified_wannierization_config(
        fixture.config;
        num_wannier = 2,
        frozen_min_ev = Inf,
        frozen_max_ev = -Inf,
        acceleration = WANNIERIZATION.WannierizationAccelerationConfig(
            u_phase_branch_tolerance = 1.0e-8,
        ),
    )
    evaluation_result = WANNIERIZATION._evaluate_mv_localization(
        evaluation_config,
        gradient_frames,
        gradient_centers,
        fixture.representation,
        fixture.mmn,
        gradient_weights,
        gradient_plan,
        tangent_plans,
    )
    @test evaluation_result.success
    evaluation = evaluation_result.evaluation
    @test isempty(evaluation.active_links)
    chart_objective = function (step)
        trial_frames = [
            gradient_frames[kpoint] * exp(step .* evaluation.full_gradients[kpoint]) for
            kpoint in eachindex(gradient_frames)
        ]
        trial_result = WANNIERIZATION._evaluate_mv_localization(
            evaluation_config,
            trial_frames,
            gradient_centers,
            fixture.representation,
            fixture.mmn,
            gradient_weights,
            gradient_plan,
            tangent_plans,
        )
        @test trial_result.success
        return trial_result.evaluation.objective
    end
    chart_analytic =
        WANNIERIZATION._mv_generalized_directional_derivative(evaluation, evaluation.full_gradients)
    for step in (1.0e-6, 3.0e-7, 1.0e-7)
        chart_fd =
            (
                -chart_objective(2step) + 8chart_objective(step) - 8chart_objective(-step) +
                chart_objective(-2step)
            ) / (12step)
        @test abs(chart_fd - chart_analytic) <=
              1.0e-8 + 1.0e-5 * max(abs(chart_fd), abs(chart_analytic))
    end

    scalar_descent = [reshape(ComplexF64[2im], 1, 1)]
    scalar_s = [[reshape(ComplexF64[1im], 1, 1)]]
    scalar_y = [[reshape(ComplexF64[2im], 1, 1)]]
    lbfgs_direction =
        WANNIERIZATION._riemannian_lbfgs_direction(scalar_descent, scalar_s, scalar_y, [0.5], [1])
    @test only(only(lbfgs_direction)) ≈ 1im atol = 1.0e-14 rtol = 0.0
    curve_velocity =
        WANNIERIZATION._polar_retraction_curve_velocity(reshape(ComplexF64[2im], 1, 1), 0.5)
    @test only(curve_velocity) ≈ 1im atol = 1.0e-14 rtol = 0.0
    displacement = WANNIERIZATION._accepted_unitary_displacement(
        ones(ComplexF64, 1, 1),
        reshape(ComplexF64[cis(0.3)], 1, 1),
        1.0e-12,
    )
    @test displacement.success
    @test only(displacement.tangent) ≈ 0.3im atol = 1.0e-14 rtol = 0.0
    clarke = WANNIERIZATION._minimum_norm_clarke_combination(
        [reshape(ComplexF64[1im], 1, 1)],
        [[reshape(ComplexF64[-2im], 1, 1)]],
    )
    @test clarke.success
    @test clarke.kkt_residual <= 1.0e-12
    @test only(clarke.coefficients) ≈ 0.5 atol = 1.0e-14 rtol = 0.0
    @test norm(only(clarke.field)) <= 1.0e-14
    projected_gradient = WANNIERIZATION._symmetry_projected_spread_gradient(
        gradient.gradients,
        fixture.representation,
        gradient_plan,
        tangent_plans,
    )
    objective =
        frames -> sum(
            WANNIERIZATION._evaluate_full_mesh_centers_spreads_and_directions(
                frames,
                gradient_centers,
                fixture.representation,
                fixture.mmn,
                gradient_weights,
            )[2],
        )
    diagnostic_gradient_frames = [frame * diagnostic_transform for frame in gradient_frames]
    @test objective(diagnostic_gradient_frames) ≈ objective(gradient_frames) atol = 1.0e-12 rtol =
        0.0
    finite_difference_step = 1.0e-6
    plus = [
        gradient_frames[kpoint] * exp(finite_difference_step .* gradient.gradients[kpoint]) for
        kpoint in eachindex(gradient_frames)
    ]
    minus = [
        gradient_frames[kpoint] * exp(-finite_difference_step .* gradient.gradients[kpoint]) for
        kpoint in eachindex(gradient_frames)
    ]
    directional_derivative = (objective(plus) - objective(minus)) / (2finite_difference_step)
    gradient_norm_squared = sum(sum(abs2, value) for value in gradient.gradients)
    @test directional_derivative ≈ -gradient_norm_squared rtol = 1.0e-6
    @test objective(plus) <=
          objective(gradient_frames) - 1.0e-4 * finite_difference_step * gradient_norm_squared

    polar_plus = Matrix{ComplexF64}[]
    polar_minus = Matrix{ComplexF64}[]
    for kpoint in eachindex(gradient_frames)
        plus_retraction = WANNIERIZATION._polar_retracted_tangent_step(
            Matrix{ComplexF64}(I, 2, 2),
            gradient.gradients[kpoint],
            finite_difference_step,
            1.0e-10,
            1.0e12,
        )
        minus_retraction = WANNIERIZATION._polar_retracted_tangent_step(
            Matrix{ComplexF64}(I, 2, 2),
            gradient.gradients[kpoint],
            -finite_difference_step,
            1.0e-10,
            1.0e12,
        )
        @test plus_retraction.success
        @test minus_retraction.success
        push!(polar_plus, gradient_frames[kpoint] * plus_retraction.unitary)
        push!(polar_minus, gradient_frames[kpoint] * minus_retraction.unitary)
    end
    polar_finite_difference =
        (objective(polar_plus) - objective(polar_minus)) / (2finite_difference_step)
    analytic_directional_derivative =
        WANNIERIZATION._localization_directional_derivative(gradient.gradients, gradient.gradients)
    directional_tolerance =
        1.0e-7 + 1.0e-5 * max(abs(polar_finite_difference), abs(analytic_directional_derivative))
    @test abs(polar_finite_difference - analytic_directional_derivative) <= directional_tolerance

    projected_plus = [
        gradient_frames[kpoint] *
        exp(finite_difference_step .* projected_gradient.full_gradients[kpoint]) for
        kpoint in eachindex(gradient_frames)
    ]
    projected_minus = [
        gradient_frames[kpoint] *
        exp(-finite_difference_step .* projected_gradient.full_gradients[kpoint]) for
        kpoint in eachindex(gradient_frames)
    ]
    projected_derivative =
        (objective(projected_plus) - objective(projected_minus)) / (2finite_difference_step)
    @test projected_derivative ≈ -projected_gradient.norm_squared rtol = 1.0e-6

    mktempdir() do directory
        diagnostics_file = joinpath(directory, "u-diagnostics.h5")
        record = (
            iteration = 1,
            spread_total = 2.0,
            spreads = [2.0],
            localization_spectra = [[1.0]],
            localization_ranks = [1],
            localization_conditions = [1.0],
            raw_eigenphases = [[0.1]],
            aligned_eigenphases = [[0.0]],
            raw_geodesic_distances = [0.1],
            aligned_geodesic_distances = [0.0],
            block_permutations = [[1]],
            block_phases = [[0.0]],
        )
        WANNIERIZATION.write_wannierization_u_convergence_diagnostics_hdf5(
            diagnostics_file,
            [record],
            [zeros(ComplexF64, 2, 1, 1)],
            [1];
            metadata = Dict("variant" => "fixture"),
        )
        HDF5.h5open(diagnostics_file, "r") do handle
            @test String(read(HDF5.attributes(handle)["schema"])) ==
                  "wanniernlqg.wannierization-u-convergence-diagnostics"
            @test String(read(HDF5.attributes(handle)["schema_version"])) == "1.0"
            @test read(
                handle["iterations/000001/per_kpoint/000001/localization_singular_values"],
            ) == [1.0]
        end
    end
end

@testset "Human report aggregation preserves complete diagnostic audit" begin
    output = WANNIERIZATION_IMPLEMENTATION.OperatorExport
    records = [
        WANNIERIZATION.WannierizationDiagnostic(
            :DIRECTIONAL_SPREAD_UNAVAILABLE,
            :info,
            "Directional spread unavailable";
            context = Dict("iteration" => string(i)),
        ) for i in 1:419
    ]
    push!(
        records,
        WANNIERIZATION.WannierizationDiagnostic(
            :LOCALIZATION_MAX_STEPS,
            :warning,
            "Localization limit",
        ),
    )
    push!(
        records,
        WANNIERIZATION.WannierizationDiagnostic(
            :MAX_ITERATIONS_REACHED,
            :warning,
            "Iteration limit",
        ),
    )
    push!(
        records,
        WANNIERIZATION.WannierizationDiagnostic(
            :STRUCTURAL_GATE,
            :info,
            "Structural failure";
            context = Dict("gate_result" => "FAIL"),
        ),
    )
    stream = IOBuffer()
    output._write_diagnostic_summary(stream, output._diagnostic_groups(records))
    report = String(take!(stream))
    @test occursin("count=419, iterations=1-419", report)
    @test occursin("LOCALIZATION_MAX_STEPS", report)
    @test occursin("MAX_ITERATIONS_REACHED", report)
    @test occursin("gate_result=FAIL", report)
    @test !occursin(".context", report)
    @test count("Directional spread unavailable", report) == 1
    mktempdir() do root
        path = output._write_diagnostic_records(
            joinpath(root, "test.wannierization-diagnostics.jsonl"),
            records,
        )
        restored = JSON3.read.(readlines(path))
        @test length(restored) == length(records)
        @test String(restored[419].context.iteration) == "419"
        @test String(restored[end].context.gate_result) == "FAIL"
        @test output._report_path(joinpath(root, "nested", "artifact.h5"), root) ==
              "nested/artifact.h5"
        @test output._report_path(joinpath(dirname(root), "other.h5"), root) ==
              "<external>/other.h5"
        @test output._report_path(nothing, root) == "NOT_WRITTEN"
    end
    metric = WANNIERIZATION.TBSymmetryMetric(
        "hamiltonian_covariance_relative_max",
        1.0,
        0.0,
        "FAIL",
        "APPLICABLE",
        "ABOVE_THRESHOLD",
        "relative",
    )
    @test output._metric_ratio(metric) === nothing
    @test output._report_number(1.23456789e-9) == "1.23e-09"
    stream = IOBuffer()
    output._write_tb_report(stream, (metrics = [metric], overall = "FAIL"))
    table = String(take!(stream))
    @test occursin("ABOVE_THRESHOLD", table)
    @test occursin("N/A", table)
    @test occursin("does not imply Wannierization convergence", table)
    @test !occursin("hamiltonian_covariance_relative_max", table)
    stream = IOBuffer()
    output._write_tb_scope(
        stream,
        Dict("qualification_scope" => "target_subspace", "global_production_eligible" => "false"),
    )
    scope = String(take!(stream))
    @test occursin("qualification_scope = target_subspace", scope)
    @test occursin("global_production_eligible = false", scope)
    @test occursin("scoped_production_eligible = NOT_RECORDED", scope)
end
