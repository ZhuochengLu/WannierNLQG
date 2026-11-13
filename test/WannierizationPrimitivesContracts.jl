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

@testset "Wannier-reference DGESVD backend" begin
    matrix = Float64[4 0; 0 3; 0 0]
    decomposition =
        WANNIERIZATION_IMPLEMENTATION.SolverCheckpoint._recursive_localization_dgesvd(matrix)
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
    @test fixture.config.runtime.num_print_cycles == 1
    @test fixture.config.checkpoint.num_dump_cycles == 100
    @test fixture.config.input.target_center_matching_tolerance == 1.0e-8
    @test fixture.config.output.tb_output_formats == (:packed_hdf5,)
    @test fixture.config.solver.acceleration == WANNIERIZATION.WannierizationAccelerationConfig(
        disentanglement_max_steps = fixture.config.solver.stage_controls.dis_num_iter,
        localization_max_steps = fixture.config.solver.stage_controls.num_iter,
        disentanglement_objective_tolerance = fixture.config.solver.stage_controls.dis_conv_tol,
        z_stability_window = fixture.config.solver.stage_controls.dis_conv_window,
    )
    no_symmetry_auto = modified_wannierization_config(
        fixture.config;
        wannierization_mode = :ordinary,
        band_representation = nothing,
        band_representation_hdf5 = "identity.schema-1.4.h5",
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
    @test_throws ArgumentError WANNIERIZATION.smv_fletcher_reeves_two_stage_audit_contract_sha256(
        thresholds,
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
            "parity_contract_sha256" => repeat("d", 64),
            "solver_source_sha256" => repeat("e", 64),
            "models_source_sha256" => repeat("f", 64),
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
        @test !audit.passed
        @test audit.status == "AUDIT_COMPLETE_EVIDENCE_REQUIRED"
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
        @test mismatched.status == "AUDIT_COMPLETE_EVIDENCE_REQUIRED"
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
    # Algorithm selection was removed by the approved Plan. The current solver
    # is unconditional SMV/FR; former selectors must fail at construction.
    @test_throws ArgumentError modified_wannierization_config(
        no_symmetry_auto;
        algorithm_profile = :custom,
    )
    for selector in (:smv_fletcher_reeves_two_stage, :unsupported_localization_profile)
        @test_throws ArgumentError WANNIERIZATION.WannierizationAccelerationConfig(
            localization_algorithm = selector,
        )
    end
    symmetry_auto = WANNIERIZATION._effective_wannierization_algorithms(fixture.config)
    @test symmetry_auto.profile == :symmetry_projected_smv_fletcher_reeves_two_stage
    @test symmetry_auto.disentanglement == :symmetry_projected_smv_fletcher_reeves_two_stage
    @test symmetry_auto.localization == :symmetry_projected_smv_fletcher_reeves_two_stage
    @test symmetry_auto.default_selection_reason == "UNCONDITIONAL_SYMMETRY_PROJECTED_DEFAULT"
    @test WANNIERIZATION._validate_wannierization_config(fixture.config) === nothing
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
            num_print_cycles = 0,
            num_dump_cycles = 0,
            tb_output_formats = (),
        ),
    ) === nothing
    @test_throws ArgumentError WANNIERIZATION._validate_wannierization_config(
        modified_wannierization_config(fixture.config; num_print_cycles = -1),
    )
    @test_throws ArgumentError WANNIERIZATION._validate_wannierization_config(
        modified_wannierization_config(fixture.config; num_dump_cycles = -1),
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
    @test_throws ArgumentError WANNIERIZATION.WannierizationConfig(
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
    @test_throws ArgumentError WANNIERIZATION.WannierizationConfig(
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
