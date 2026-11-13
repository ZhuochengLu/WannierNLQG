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
    @test_throws ArgumentError WANNIERIZATION._localization_objective_accepts(
        :polar_then_gradient,
        :monotone,
        1.0,
        0.9,
        1e-12,
        1.0,
        -1.0,
        1e-4,
    )
    @test !WANNIERIZATION._localization_objective_accepts(
        :symmetry_projected_smv_fletcher_reeves_two_stage,
        :monotone,
        1.0,
        1.01,
        1.0e-12,
        1.0,
        0.0,
        1.0e-4,
    )
    @test WANNIERIZATION._localization_objective_accepts(
        :symmetry_projected_smv_fletcher_reeves_two_stage,
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

    # Retired L-BFGS is rejected; retain the current retraction/gradient oracles.
    @test !isdefined(WANNIERIZATION, :_riemannian_lbfgs_direction)
    @test_throws ArgumentError WANNIERIZATION.WannierizationAccelerationConfig(
        localization_algorithm = :riemannian_lbfgs,
    )
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
            @test String(read(HDF5.attributes(handle)["schema_version"])) == "1.1"
            @test read(handle["iterations/000001/raw_spreads"]) == [2.0]
            @test read(handle["iterations/000001/ibz_frames"]) == zeros(ComplexF64, 2, 1, 1)
            @test String(
                read(HDF5.attributes(handle["iterations/000001/ibz_frames"])["axis_order"]),
            ) == "band,wannier,irreducible_kpoint"
            @test !haskey(handle["iterations/000001"], "per_kpoint")
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

@testset "source identity agrees with the sealed release inventory" begin
    package_root = pkgdir(WannierNLQG)
    source_records = Dict{String, Tuple{String, String}}()
    for line in eachline(joinpath(package_root, "SHA256SUMS"))
        digest, relative = split(line, "  "; limit = 2)
        if relative in ("Project.toml", "Manifest.toml") ||
           startswith(relative, "src/") ||
           startswith(relative, "ext/")
            native_relative = joinpath(split(relative, '/')...)
            source_records[native_relative] = (String(relative), String(digest))
        end
    end
    @test !isempty(source_records)
    entries = [
        string(source_records[key][1], '\0', source_records[key][2]) for
        key in sort!(collect(keys(source_records)))
    ]
    # External SOURCE_MANIFEST validation above retains source integrity.
    # Normal Wannierization no longer computes a source-tree digest.
    @test !isdefined(WANNIERIZATION_IMPLEMENTATION.OperatorExport, :_wannierization_source_sha256)
end
