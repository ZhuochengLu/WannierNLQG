using Test
using LinearAlgebra
using Serialization
isdefined(@__MODULE__, :DiagnosticRecordTestSupport) ||
    include(joinpath(@__DIR__, "DiagnosticRecordTestSupport.jl"))
if !isdefined(@__MODULE__, :WANNIERIZATION_FIXTURE_SUPPORT_LOADED)
    include(joinpath(@__DIR__, "WannierizationFixtureSupport.jl"))
end

@testset "Standard construction preserves finite-difference arithmetic and hard rank" begin
    fixture = synthetic_wannierization_fixture()
    solver = WANNIERIZATION_IMPLEMENTATION.SolverCheckpoint
    strict = solver._finite_difference_weights(fixture.representation, fixture.mmn)
    diagnostic = solver._finite_difference_weights(
        fixture.representation,
        fixture.mmn;
        construction_policy = :standard,
    )
    @test strict.weights == diagnostic.weights
    @test strict.vectors_cartesian == diagnostic.vectors_cartesian
    @test strict.shell_ids == diagnostic.shell_ids
    @test strict.target_moment == diagnostic.target_moment
    @test strict.completeness_residual == diagnostic.completeness_residual
    strict_result = WANNIERIZATION._solve_symmetry_adapted_wannierization(
        fixture.config,
        fixture.representation,
        fixture.eig,
        fixture.mmn,
        fixture.plan,
    )
    diagnostic_result = WANNIERIZATION._solve_symmetry_adapted_wannierization(
        modified_wannierization_config(fixture.config; construction_policy = :standard),
        fixture.representation,
        fixture.eig,
        fixture.mmn,
        fixture.plan,
    )
    @test strict_result.v_matrix == diagnostic_result.v_matrix
    @test strict_result.spreads_angstrom2 == diagnostic_result.spreads_angstrom2
    fixture.representation.reciprocal_lattice[1, 2] += 2.0e-7
    default_warning = solver._finite_difference_weights(fixture.representation, fixture.mmn)
    @test default_warning.completeness_residual > 1.0e-10
    perturbed = solver._finite_difference_weights(
        fixture.representation,
        fixture.mmn;
        construction_policy = :standard,
    )
    @test perturbed.completeness_residual > 1.0e-10
    @test all(isfinite, perturbed.weights)
    fixture.representation.reciprocal_lattice[3, :] .= 0.0
    @test_throws ArgumentError solver._finite_difference_weights(
        fixture.representation,
        fixture.mmn;
        construction_policy = :standard,
    )
end

@testset "Standard quality failures reach accepted state, persist, and export" begin
    fixture = synthetic_wannierization_fixture()
    fixture.representation.reciprocal_lattice[1, 2] += 2.0e-7
    config = modified_wannierization_config(
        fixture.config;
        construction_policy = :standard,
        stage_controls = WANNIERIZATION.WannierizationStageControls(dis_num_iter = 2, num_iter = 2),
        write_model_tb = true,
        tb_output_formats = (:packed_hdf5, :model_tb),
    )
    @test_throws ArgumentError WANNIERIZATION._solve_symmetry_adapted_wannierization(
        modified_wannierization_config(config; construction_policy = :strict),
        fixture.representation,
        fixture.eig,
        fixture.mmn,
        fixture.plan,
    )
    result = WANNIERIZATION._solve_symmetry_adapted_wannierization(
        config,
        fixture.representation,
        fixture.eig,
        fixture.mmn,
        fixture.plan,
    )
    @test result.restart_state !== nothing
    @test result.input_summary["has_accepted_state"] == "true"
    @test result.input_summary["model_qualification"] == "COMPUTATION_READY"
    failures = filter(d -> d.code == :MMN_STENCIL_COMPLETENESS_FAILED, result.diagnostics)
    @test length(failures) == 1
    @test only(failures).severity == :error
    @test only(failures).context["gate_result"] == "FAIL"
    @test only(failures).context["action"] == "CONTINUE_STANDARD"
    exported = WANNIERIZATION_IMPLEMENTATION.OperatorExport
    gate = exported._accepted_state_tb_export_gate(result, config)
    @test gate.allowed
    strict_rejected = exported.updated_wannierization_result(
        result;
        status = WANNIERIZATION.REPRESENTATION_INCOMPATIBLE,
        input_summary = merge(
            result.input_summary,
            Dict("compatibility_admission"=>"REJECTED_STRICT"),
        ),
        diagnostics = vcat(
            result.diagnostics,
            [
                WANNIERIZATION.WannierizationDiagnostic(
                    :ANTIUNITARY_PROJECTOR_COVARIANCE_FAILED,
                    :error,
                    "strict admission rejected";
                    context = Dict(
                        "maximum_error"=>"0.1",
                        "tolerance"=>"1e-8",
                        "compatibility_admission"=>"REJECTED_STRICT",
                    ),
                ),
            ],
        ),
    )
    strict_gate = exported._accepted_state_tb_export_gate(strict_rejected, config)
    @test !strict_gate.allowed
    @test strict_gate.reason == "STRICT_COMPATIBILITY_ADMISSION_REJECTED"
    without_unsealed_summary = exported.updated_wannierization_result(
        strict_rejected;
        input_summary = result.input_summary,
    )
    @test !exported._accepted_state_tb_export_gate(without_unsealed_summary, config).allowed
    @test !WANNIERIZATION_IMPLEMENTATION.WorkflowOrchestration._wannierization_eligibility(
        strict_rejected,
        config,
    ).execution_eligible
    nonfinite = exported.updated_wannierization_result(
        result;
        input_summary = merge(result.input_summary, Dict("hard_gate_covariance"=>"NaN")),
    )
    @test !exported._accepted_state_tb_export_gate(nonfinite, config).allowed
    nonapplicable = exported.updated_wannierization_result(
        result;
        input_summary = merge(
            result.input_summary,
            Dict("hard_gate_target_symmetry"=>"NaN", "symmetry_constraints_applied"=>"false"),
        ),
    )
    @test exported._accepted_state_tb_export_gate(nonapplicable, config).allowed
    @test !WANNIERIZATION_IMPLEMENTATION.SolverCheckpoint.wannierization_production_eligible(result)
    mktempdir() do directory
        strict_checkpoint = joinpath(directory, "strict-rejected.wannierization.h5")
        WANNIERIZATION.write_wannierization_checkpoint_hdf5(strict_checkpoint, strict_rejected)
        strict_restored = WANNIERIZATION.read_wannierization_checkpoint_hdf5(strict_checkpoint)
        @test !exported._accepted_state_tb_export_gate(strict_restored, config).allowed
        @test strict_restored.diagnostics[end].context["compatibility_admission"] ==
              "REJECTED_STRICT"
        HDF5.h5open(strict_checkpoint, "r+") do handle
            group =
                handle["diagnostics/" * lpad(string(length(strict_rejected.diagnostics)), 6, '0')]
            HDF5.delete_attribute(group, "compatibility_admission")
        end
        @test_throws ArgumentError WANNIERIZATION.read_wannierization_checkpoint_hdf5(
            strict_checkpoint,
        )
        checkpoint = joinpath(directory, "diagnostic.wannierization.h5")
        WANNIERIZATION.write_wannierization_checkpoint_hdf5(checkpoint, result)
        restored = WANNIERIZATION.read_wannierization_checkpoint_hdf5(checkpoint)
        @test restored.v_matrix == result.v_matrix
        @test restored.input_summary["construction_policy"] == "standard"
        @test only(filter(d -> d.code == :MMN_STENCIL_COMPLETENESS_FAILED, restored.diagnostics)).context ==
              only(failures).context
        paths = exported._wannierization_output_paths(checkpoint)
        packed, exchange, metadata = exported._export_wannierization_tb(
            result,
            fixture.eig,
            fixture.mmn,
            config,
            paths,
            nothing,
        )
        @test isfile(packed) && isfile(exchange)
        # Mathematical model output carries no administrative quality sidecar.
        # Keep the original measured warning in the result/checkpoint/report domain.
        @test metadata["wannierization_quality_metadata"] == ""
        @test metadata["quality_review_recommended"] == "true"
        @test metadata["construction_quality_failed"] == "true"
        @test only(filter(d -> d.code == :MMN_STENCIL_COMPLETENESS_FAILED, restored.diagnostics)).context ==
              only(failures).context
        @test metadata["model_availability"] == "AVAILABLE_WITH_QUALITY_WARNINGS"
        @test metadata["numerical_quality"] == "NUMERICAL_WARNING"
        @test occursin("CONTINUE_STANDARD", metadata["construction_gate_records_json"])
        @test all(isfinite, WANNIER_IO.read_wannier_tb(exchange).hamiltonian_r)
        @test WANNIER_IO.read_real_space_operator_bundle(packed) !== nothing
    end
    # A valid retained accepted boundary survives a later numerical failure,
    # while identity failure and missing accepted state remain non-exportable.
    failed =
        WANNIERIZATION_IMPLEMENTATION.WannierizationInternalSupport.updated_wannierization_result(
            result;
            status = WANNIERIZATION.SINGULAR_LOCALIZATION,
        )
    @test exported._accepted_state_tb_export_gate(failed, config).allowed
    workflow = WANNIERIZATION_IMPLEMENTATION.WorkflowOrchestration
    @test workflow._wannierization_eligibility(failed, config).qualification_status ==
          "COMPUTATION_READY"
    for status in (WANNIERIZATION.IO_FAILURE, WANNIERIZATION.INVALID_INPUT)
        invalid = exported.updated_wannierization_result(result; status)
        eligibility = workflow._wannierization_eligibility(invalid, config)
        @test !eligibility.execution_eligible
        @test !eligibility.export_eligible
        @test eligibility.qualification_status == "NOT_EVALUATED"
    end
    wrong_iteration = exported.updated_wannierization_result(
        result;
        input_summary = merge(result.input_summary, Dict("last_accepted_iteration"=>"-17")),
    )
    @test !workflow._wannierization_eligibility(wrong_iteration, config).execution_eligible
    support = WANNIERIZATION_IMPLEMENTATION.WannierizationInternalSupport
    missing = support.updated_wannierization_result(result; restart_state = nothing)
    @test !exported._accepted_state_tb_export_gate(missing, config).allowed
    corrupted = support.updated_wannierization_result(
        result;
        diagnostics = vcat(
            result.diagnostics,
            [
                WANNIERIZATION.WannierizationDiagnostic(
                    :CHECKPOINT_SHA256_MISMATCH,
                    :error,
                    "synthetic corrupted source identity",
                ),
            ],
        ),
    )
    @test !exported._accepted_state_tb_export_gate(corrupted, config).allowed
    @test !workflow._wannierization_eligibility(corrupted, config).execution_eligible
end

@testset "Standard Z handoff retains geometry gates" begin
    fixture = synthetic_wannierization_fixture()
    solver = WANNIERIZATION_IMPLEMENTATION.SolverCheckpoint
    frames = [reshape(ComplexF64[1, 0], 2, 1) for _ in 1:2]
    z = [Matrix{ComplexF64}(I, 2, 2) for _ in 1:2]
    qualifier(values; policy = :standard) = solver._qualify_nonconverged_disentanglement_state(
        values,
        z,
        zeros(1, 3),
        zeros(1),
        [[1], [1]],
        fixture.representation,
        fixture.plan,
        1.0e-8,
        1.0e-8,
        true;
        construction_policy = policy,
    )
    @test qualifier(frames).qualified
    fixture.representation.sewing_matrices[:, :, 1, 1] .*= 1.0001
    @test_throws ArgumentError qualifier(frames; policy = :strict)
    @test qualifier(frames).qualified
    @test !qualifier([zero(frame) for frame in frames]).qualified
    @test !qualifier([2frame for frame in frames]).qualified
end

@testset "Failed Z trial uses the shared seal and accepted geometry for U" begin
    fixture = synthetic_wannierization_fixture()
    solver = WANNIERIZATION_IMPLEMENTATION.SolverCheckpoint
    config = modified_wannierization_config(
        fixture.config;
        construction_policy = :standard,
        stage_controls = WANNIERIZATION.WannierizationStageControls(dis_num_iter = 2, num_iter = 2),
        acceleration = WANNIERIZATION.WannierizationAccelerationConfig(
            schedule = :two_stage,
            disentanglement_max_steps = 2,
            localization_max_steps = 2,
        ),
    )
    state = (;
        config,
        representation = fixture.representation,
        eig = fixture.eig,
        mmn = fixture.mmn,
        plan = fixture.plan,
        amn = nothing,
        restart = nothing,
        restart_state = nothing,
        restart_history = WANNIERIZATION.WannierizationIteration[],
        restart_input_summary = Dict{String, String}(),
        fixed_subspace = nothing,
        observer = nothing,
        compatibility_report = nothing,
        initialization_amn_sha256 = "",
        paw_scdm_input = nothing,
    )
    for prepare in (
        solver._prepare_solver_input_summary,
        solver._qualify_solver_inputs,
        solver._validate_solver_restart,
        solver._initialize_solver_frames,
        solver._initialize_solver_optimizer,
    )
        state = prepare(state)
        @test !(state isa WANNIERIZATION.WannierizationResult)
    end
    retained = copy(state.latest_restart_state.frames)
    failed = solver._failure_result(
        WANNIERIZATION.LOCALIZATION_FAILED,
        [
            WANNIERIZATION.WannierizationDiagnostic(
                :SYNTHETIC_Z_TRIAL_FAILED,
                :error,
                "synthetic failed Z proposal",
            ),
        ],
        copy(state.input_summary);
        frames = [zeros(ComplexF64, 2, 1) for _ in 1:2],
        centers = state.centers,
        spreads = state.spreads,
        restart_state = state.latest_restart_state,
        representation = fixture.representation,
    )
    continued = solver._continue_failed_disentanglement(state, failed, 1)
    @test !(continued isa WANNIERIZATION.WannierizationResult)
    @test continued.optimizer_phase == :localization
    @test continued.latest_restart_state.optimizer_state.phase == :localization
    @test state.latest_restart_state.frames == retained
    @test continued.z_steps == state.z_steps == 0
    @test continued.retained_disentanglement_nonconverged
    @test any(d -> d.code == :SYNTHETIC_Z_TRIAL_FAILED, continued.diagnostics)
    @test any(
        d -> d.code == :DISENTANGLEMENT_FAILED_TRIAL_CONTINUED_STANDARD,
        continued.diagnostics,
    )
    terminal = solver._run_solver_iterations(continued)
    result =
        terminal isa WANNIERIZATION.WannierizationResult ? terminal :
        solver._assemble_solver_terminal_result(terminal)
    @test result.restart_state !== nothing
    @test result.restart_state.optimizer_state.u_steps > 0
    @test result.input_summary["z_seal_class"] == "NONCONVERGED_RETAINED"
    @test state.latest_restart_state.frames == retained
    strict_state = merge(
        state,
        (; config = modified_wannierization_config(config; construction_policy = :strict)),
    )
    @test_throws ArgumentError solver._continue_failed_disentanglement(strict_state, failed, 1)
end

@testset "Mask closure separates finite residual from discrete Kramers rank" begin
    solver = WANNIERIZATION_IMPLEMENTATION.SolverCheckpoint
    diagnostic(source_rank, target_rank) = WANNIERIZATION.WannierizationDiagnostic(
        :KRAMERS_BLOCK_NOT_CLOSED,
        :error,
        "mask covariance residual";
        context = Dict(
            "source_rank" => string(source_rank),
            "target_rank" => string(target_rank),
            "source_kpoint" => "1",
            "target_kpoint" => "1",
            "maximum_error" => "0.01",
        ),
    )
    @test solver._construction_compatibility_quality_failure(diagnostic(2, 2))
    @test !solver._construction_compatibility_quality_failure(diagnostic(2, 4))
    @test !solver._construction_compatibility_quality_failure(diagnostic(1, 1))
end

@testset "Saved TB stencil accepts only equal-weight edge permutations" begin
    fixture = synthetic_wannierization_fixture()
    solver = WANNIERIZATION_IMPLEMENTATION.SolverCheckpoint
    output = WANNIERIZATION_IMPLEMENTATION.OperatorExport
    stencil = solver._finite_difference_weights(fixture.representation, fixture.mmn)
    chk = WANNIER_IO.WannierCHK(
        2,
        1,
        2,
        fixture.representation.mp_grid,
        fixture.representation.kpoints_fractional,
        fixture.representation.real_lattice,
        fixture.representation.reciprocal_lattice,
        zeros(1, 3),
        reshape(ComplexF64[1, 0, 1, 0], 2, 1, 2),
    )
    permuted(order) = begin
        mmn = deepcopy(fixture.mmn)
        mmn.neighbors[:, 2] .= fixture.mmn.neighbors[order, 2]
        mmn.reciprocal_shifts[:, :, 2] .= fixture.mmn.reciprocal_shifts[:, order, 2]
        mmn.data[:, :, :, 2] .= fixture.mmn.data[:, :, order, 2]
        mmn
    end
    # At the second k point the opposite x edges exchange their storage order.
    @test output._tight_binding_saved_stencil_weights(
        chk,
        permuted([2, 1, 3, 4, 5, 6]),
        stencil,
    ) === stencil.weights
    @test_throws ArgumentError output._tight_binding_saved_stencil_weights(
        chk,
        permuted([2, 2, 3, 4, 5, 6]),
        stencil,
    )
    @test stencil.weights[1] != stencil.weights[3]
    @test_throws ArgumentError output._tight_binding_saved_stencil_weights(
        chk,
        permuted([3, 2, 1, 4, 5, 6]),
        stencil,
    )
end

@testset "Construction policy preserves requested compatibility assessment" begin
    fixture = synthetic_wannierization_fixture()
    # Only operation metadata is inspected by this routing helper. Disable the
    # independent legacy-origin and magnetic flags to isolate antiunitary routing.
    operation = only(fixture.representation.operations)
    fixture.representation.operations[1] = WannierNLQG.SymmetryFoundation.SymmetryOperation(
        operation.rotation_fractional,
        operation.translation_fractional,
        operation.rotation_cartesian,
        true,
    )
    workflow = WANNIERIZATION_IMPLEMENTATION.WorkflowOrchestration
    for requested in (:strict, :warn, :off)
        @test workflow._effective_compatibility_policy(
            requested,
            fixture.representation,
            (magnetic = false,);
            public_origin_fallback_validated = true,
            construction_policy = :standard,
        ) == requested
        @test_throws ArgumentError workflow._effective_compatibility_policy(
            requested,
            fixture.representation,
            (magnetic = false,);
            public_origin_fallback_validated = true,
            construction_policy = :strict,
        )
    end
end

@testset "Target tangent SVD preserves right nullspace without unused tall U" begin
    solver = WANNIERIZATION_IMPLEMENTATION.SolverCheckpoint
    tall = Float64[1 0 1; 0 1 1; 1 1 2; 2 0 2; 0 2 2; 2 2 4]
    for constraints in (tall, Matrix(transpose(tall)), tall[1:3, :])
        retained = copy(constraints)
        former = svd(constraints; full = true)
        current = solver._target_tangent_constraint_svd(constraints)
        threshold = 1.0e-10 * maximum(former.S)
        former_rank = count(>(threshold), former.S)
        current_rank = count(>(threshold), current.S)
        former_null = former.V[:, (former_rank + 1):end]
        current_null = current.V[:, (current_rank + 1):end]
        rows, columns = size(constraints)
        @test constraints == retained
        @test size(current.U) == (rows, min(rows, columns))
        @test size(current.V) == (columns, columns)
        @test current.S ≈ former.S atol = 1.0e-13 rtol = 1.0e-13
        @test current_null * current_null' ≈ former_null * former_null' atol = 1.0e-12
        @test norm(constraints * current_null) <= 1.0e-12
    end
    identity_matrix = Matrix{ComplexF64}(I, 2, 2)
    @test_throws ArgumentError solver._target_symmetry_tangent_plan(
        [identity_matrix],
        [false];
        construction_policy = :strict,
    )
    reflection = ComplexF64[1 0; 0 -1]
    probe = ComplexF64[2+3im 4+5im; 6+7im 8+9im]
    expected = ComplexF64[2 0; 0 8]
    for policy in (:standard,)
        tangent = solver._target_symmetry_tangent_plan(
            [reflection, identity_matrix],
            [false, true];
            construction_policy = policy,
        )
        @test size(tangent.basis, 2) == 2
        @test tangent.maximum_basis_residual <= 1.0e-12
        @test solver._project_target_symmetry_tangent(tangent, probe) ≈ expected atol = 1.0e-12
    end
end

# Verify durable diagnostic arrays and sealed gate records in a fresh interpreter.
function public_diagnostic_chain_fresh_read(result, expected_code)
    script = """
    using WannierNLQG, HDF5, SHA, Serialization
    include(ARGS[7])
    result = WannierNLQG.Wannierization.read_wannierization_checkpoint_hdf5(ARGS[1])
    result.input_summary["wannierization_eligibility_production_eligible"] == "false" ||
        error("production flag changed")
    bytes2hex(sha256(reinterpret(UInt8, vec(result.v_matrix)))) == ARGS[5] || error("accepted arrays changed")
    bundle = WannierNLQG.IO.read_real_space_operator_bundle(ARGS[2])
    expected_records = open(deserialize, ARGS[6])
    actual_records = DiagnosticRecordTestSupport.require_diagnostic_records(result.diagnostics, ARGS[4])
    actual_records == expected_records || error("complete original diagnostic records differ")
    all(operator -> all(isfinite, operator.data), values(bundle.operators)) || error("model operators are nonfinite")
    tb = WannierNLQG.IO.read_wannier_tb(ARGS[3])
    all(isfinite, tb.hamiltonian_r) || error("TB is nonfinite")
    h5open(ARGS[2], "r") do handle
        !haskey(handle, "construction_evidence") && !haskey(handle, "qualification") ||
            error("model regained retired administrative qualification groups")
    end
    println("PUBLIC_DIAGNOSTIC_CHAIN_FRESH_READ_PASS")
    """
    artifacts = result.artifacts
    digest = bytes2hex(SHA.sha256(reinterpret(UInt8, vec(result.v_matrix))))
    expected_records =
        DiagnosticRecordTestSupport.require_diagnostic_records(result.diagnostics, expected_code)
    support = joinpath(@__DIR__, "DiagnosticRecordTestSupport.jl")
    return mktemp() do reference, stream
        serialize(stream, expected_records)
        flush(stream)
        command =
            `$(Base.julia_cmd()) --startup-file=no --threads=1 --project=$(dirname(@__DIR__)) -e $(script) $(artifacts.checkpoint_hdf5) $(artifacts.packed_hdf5) $(artifacts.model_tb) $(expected_code) $(digest) $(reference) $(support)`
        occursin("PUBLIC_DIAGNOSTIC_CHAIN_FRESH_READ_PASS", read(command, String))
    end
end

@testset "Public standard antiunitary quality chain reaches readable TB" begin
    isdefined(@__MODULE__, :BandPublicSchemaTestSupport) ||
        include(joinpath(@__DIR__, "BandPublicSchemaTestSupport.jl"))
    W = WANNIERIZATION
    S = WannierNLQG.SymmetryFoundation
    WI = WANNIER_IO
    mktempdir() do dir
        f=synthetic_wannierization_fixture()
        r=f.representation
        ops=[
            only(r.operations),
            S.SymmetryOperation(Matrix{Int}(I, 3, 3), zeros(3), Matrix{Float64}(I, 3, 3), true),
        ]
        theta=ComplexF64[0 1; -1 0]
        sewing=zeros(ComplexF64, 4, 4, 2, 2)
        for k in 1:2
            ;
            sewing[:, :, 1, k].=Matrix{ComplexF64}(I, 4, 4);
            sewing[1:2, 1:2, 2, k].=theta;
            sewing[3:4, 3:4, 2, k].=theta;
        end
        sewing[3, 4, 2, 1]*=1+1e-5
        energies=[-1.0 -1.0; -1.0 -1.0; 1.0 1.0; 1.0 1.0]
        basis=BandPublicSchemaTestSupport.single_site_s_basis(spinor = true)
        shifts=zeros(Int, 3, 2, 2);
        shifts[1, 2, 2]=-1
        raw=S.BandRepresentation(
            "1.0",
            :synthetic,
            true,
            r.real_lattice,
            r.reciprocal_lattice,
            r.mp_grid,
            r.kpoints_fractional,
            energies,
            ops,
            repeat(r.kpoint_map, 2, 1),
            shifts,
            sewing,
            [1 1; 1 1; 2 2; 2 2],
            r.irreducible_indices,
            r.full_to_irreducible,
            r.full_to_operation;
            input_sha256 = Dict(
                "synthetic_sewing"=>bytes2hex(sha256(reinterpret(UInt8, vec(sewing)))),
            ),
        )
        win=joinpath(dir, "model.win");
        eig=joinpath(dir, "model.eig");
        mmn=joinpath(dir, "model.mmn")
        write(win, "num_wann = 2\nmp_grid = 2 1 1\nbegin projections\nX:s\nend projections\n")
        open(eig, "w") do io
            for k in 1:2, b in 1:4
                ;
                println(io, b, " ", k, " ", energies[b, k]);
            end
        end
        mmndata=repeat(reshape(Matrix{ComplexF64}(I, 4, 4), 4, 4, 1, 1), 1, 1, 6, 2)
        WI.write_wannier_mmn(
            mmn,
            WI.WannierMMN(4, 2, 6, mmndata, f.mmn.neighbors, f.mmn.reciprocal_shifts),
        )
        prep(
            policy;
            compatibility_policy = :warn,
        )=W.prepare_band_representation(
            W.BandRepresentationPreparationConfig(
                construction_policy = policy,
                wannierization_mode = :symmetry_adapted,
                win_file = win,
                eig_file = eig,
                projection_basis = basis,
                band_representation = raw,
                output_hdf5 = joinpath(
                    dir,
                    string(policy)*"-"*string(compatibility_policy)*"-representation.h5",
                ),
                num_wannier = 2,
                outer_min_ev = -2.0,
                outer_max_ev = 2.0,
                frozen_min_ev = -2.0,
                frozen_max_ev = -0.5,
                compatibility_policy = compatibility_policy,
            ),
        )
        strict=try
            prep(:strict)
        catch err
            ;
            err
        end
        @test strict isa Exception || strict.status==:FAILED
        independent_strict = prep(:standard; compatibility_policy = :strict)
        @test independent_strict.status == :FAILED
        @test !independent_strict.compatibility_report.passed
        @test independent_strict.representation.sewing_matrices == sewing
        prepared=prep(:standard)
        @test prepared.status in (:PASS, :PASS_WITH_WARNINGS)
        representation=S.read_band_representation_hdf5(
            prepared.output_hdf5;
            content_authentication = false,
        )
        @test representation.sewing_matrices==sewing
        cfg=modified_wannierization_config(
            f.config;
            construction_policy = :standard,
            projection_basis = basis,
            num_wannier = 2,
            win_file = win,
            eig_file = eig,
            mmn_file = mmn,
            band_representation = nothing,
            band_representation_hdf5 = prepared.output_hdf5,
            compatibility_policy = :warn,
            stage_controls = WANNIERIZATION.WannierizationStageControls(
                dis_num_iter = 2,
                num_iter = 2,
            ),
            checkpoint_hdf5 = joinpath(dir, "run.wannierization.h5"),
            write_model_tb = true,
            tb_output_formats = (:packed_hdf5, :model_tb),
            acceleration = W.WannierizationAccelerationConfig(
                schedule = :two_stage,
                disentanglement_max_steps = 2,
                localization_max_steps = 2,
            ),
        )
        result=W.construct_wannier_functions(cfg)
        @test result.restart_state!==nothing
        @test result.restart_state.optimizer_state.u_steps>0
        @test result.input_summary["wannierization_eligibility_production_eligible"]=="false"
        @test any(
            d->d.code==:THETA_SQUARED_FAILED && get(d.context, "gate_result", "")=="FAIL",
            result.diagnostics,
        )
        @test public_diagnostic_chain_fresh_read(result, "THETA_SQUARED_FAILED")
    end
end

@testset "QE standard admission retains metric and identity hard gates" begin
    paw = WANNIERIZATION_IMPLEMENTATION.PAWMatrixElements
    metric = ComplexF64[1.001 0; 0 0.999]
    retained = copy(metric)
    @test paw._qe_require_positive_band_metric(metric) === nothing
    @test metric == retained
    for invalid in (
        ComplexF64[1 2; 2 1],
        ComplexF64[1 0; 0 0],
        ComplexF64[1 1; 0 1],
        ComplexF64[NaN 0; 0 1],
        ComplexF64[Inf 0; 0 1],
        zeros(ComplexF64, 2, 1),
    )
        @test_throws ArgumentError paw._qe_require_positive_band_metric(invalid)
    end
end

# Re-read the retained diagnostic solver state without requiring a TB export for this fixture.
function public_diagnostic_checkpoint_fresh_read(result, expected_code)
    digest = bytes2hex(SHA.sha256(reinterpret(UInt8, vec(result.v_matrix))))
    script = """
    using WannierNLQG, SHA
    result = WannierNLQG.Wannierization.read_wannierization_checkpoint_hdf5(ARGS[1])
    bytes2hex(sha256(reinterpret(UInt8, vec(result.v_matrix)))) == ARGS[3] || error("accepted arrays changed")
    result.input_summary["construction_policy"] == "standard" || error("policy changed")
    result.input_summary["wannierization_eligibility_production_eligible"] == "false" ||
        error("production flag changed")
    any(d -> string(d.code) == ARGS[2], result.diagnostics) || error("original diagnostics disappeared")
    println("PUBLIC_DIAGNOSTIC_CHECKPOINT_FRESH_READ_PASS")
    """
    command =
        `$(Base.julia_cmd()) --startup-file=no --threads=1 --project=$(dirname(@__DIR__)) -e $(script) $(result.artifacts.checkpoint_hdf5) $(expected_code) $(digest)`
    return occursin("PUBLIC_DIAGNOSTIC_CHECKPOINT_FRESH_READ_PASS", read(command, String))
end

@testset "Public native QE parity failure reaches standard solve and fresh checkpoint" begin
    isdefined(@__MODULE__, :QEPAWMatrixElementsTestSupport) ||
        include(joinpath(@__DIR__, "QEPAWMatrixElementsTestSupport.jl"))
    W = WANNIERIZATION
    S = WannierNLQG.SymmetryFoundation
    WI = WANNIER_IO
    write_qe_paw_fixture = QEPAWMatrixElementsTestSupport.write_qe_paw_fixture
    mktempdir() do dir
        f=write_qe_paw_fixture(joinpath(dir, "source"); metric_kind = :norm_conserving)
        shifts=[1 -1 0 0 0 0; 0 0 1 -1 0 0; 0 0 0 0 1 -1]
        h5open(joinpath(f.save_directory, "wfc1.hdf5"), "r+") do h
            HDF5.delete_attribute(h, "igwx");
            HDF5.attributes(h)["igwx"]=7
            oldattrs=Dict(
                k=>read(HDF5.attributes(h["MillerIndices"])[k]) for
                k in keys(HDF5.attributes(h["MillerIndices"]))
            )
            HDF5.delete_object(h, "MillerIndices");
            h["MillerIndices"]=hcat(zeros(Int, 3, 1), shifts)
            for (k, v) in oldattrs
                ;
                HDF5.attributes(h["MillerIndices"])[k]=v;
            end
            HDF5.delete_object(h, "evc");
            h["evc"]=reshape(repeat([1/sqrt(7.0), 0.0], 7), :, 1)
        end
        nnkp=read(f.nnkp_file, String)
        rows=join(["1 1 "*join(shifts[:, j], " ") for j in 1:6], "\n")
        write(
            f.nnkp_file,
            replace(nnkp, r"begin nnkpts.*?end nnkpts"s=>"begin nnkpts\n6\n"*rows*"\nend nnkpts"),
        )
        source=S.QuantumEspressoWavefunctionSource(f.save_directory; include_time_reversal = false)
        raw=W.generate_qe_paw_matrix_elements(
            source,
            f.nnkp_file;
            artifact_dir = joinpath(dir, "base"),
            require_oracle = false,
        )
        @test raw.passed
        oracle=QEPAWMatrixElementsTestSupport.copy_qe_paw_oracles(raw, joinpath(dir, "oracle"))
        QEPAWMatrixElementsTestSupport.write_qe_paw_oracle_provenance(joinpath(dir, "oracle"), raw)
        reference=WI.read_wannier_mmn(oracle.mmn);
        reference.data[1, 1, 1, 1]+=1e-3;
        WI.write_wannier_mmn(oracle.mmn, reference)
        win=joinpath(dir, "model.win");
        eig=joinpath(dir, "model.eig")
        a=2*S.BOHR_TO_ANGSTROM
        write(
            win,
            "num_wann=1\nmp_grid=1 1 1\nbegin unit_cell_cart\n$(a) 0 0\n0 $(a) 0\n0 0 $(a)\nend unit_cell_cart\nbegin kpoints\n0 0 0\nend kpoints\nbegin atoms_frac\nX 0 0 0\nend atoms_frac\nbegin projections\nX:s\nend projections\n",
        )
        write(eig, "1 1 $(-.25*S.HARTREE_TO_EV)\n")
        base=synthetic_wannierization_fixture()
        for policy in (:standard,)
            cfg=modified_wannierization_config(
                base.config;
                construction_policy = policy,
                initialization = :amn,
                wannierization_mode = :ordinary,
                band_representation = nothing,
                win_file = win,
                eig_file = eig,
                source = source,
                matrix_elements = W.NativeQEPAWMatrices(
                    f.nnkp_file;
                    artifact_dir = joinpath(dir, string(policy)*"-matrices"),
                    oracle_mmn_file = oracle.mmn,
                    oracle_amn_file = oracle.amn,
                ),
                outer_min_ev = -18.0,
                outer_max_ev = 3.5,
                frozen_min_ev = -18.0,
                frozen_max_ev = 0.5,
                stage_controls = WANNIERIZATION.WannierizationStageControls(
                    dis_num_iter = 1,
                    num_iter = 2,
                ),
                acceleration = W.WannierizationAccelerationConfig(
                    schedule = :two_stage,
                    disentanglement_max_steps = 1,
                    localization_max_steps = 2,
                ),
                checkpoint_hdf5 = joinpath(dir, string(policy)*".wannierization.h5"),
                write_model_tb = true,
                tb_output_formats = (:packed_hdf5, :model_tb),
                final_tb_symmetry_report_enabled = true,
            )
            @test cfg.output.final_tb_symmetry_report_enabled === true
            invalid_policy = W.construct_wannier_functions(
                modified_wannierization_config(cfg; construction_policy = :strict),
            )
            @test invalid_policy.status == W.INVALID_INPUT
            @test invalid_policy.restart_state === nothing
            @test any(
                diagnostic ->
                    diagnostic.code == :INVALID_INPUT &&
                    occursin("construction_policy=:strict", diagnostic.message),
                invalid_policy.diagnostics,
            )
            @test !isdir(joinpath(dir, string(policy) * "-matrices"))
            result=W.construct_wannier_functions(cfg)
            if policy == :standard
                workflow = WANNIERIZATION_IMPLEMENTATION.WorkflowOrchestration
                basis =
                    cfg.input.projection_basis === nothing ?
                    workflow.build_wannier_projection_basis(cfg.input.win_file) :
                    cfg.input.projection_basis
                normalized = workflow._config_with_projection_basis(cfg, basis)
                restored = workflow._resolve_wannier_matrix_elements(
                    normalized,
                    basis;
                    accepted_result = result,
                    generator = (_, _) -> error(
                        "native matrix generator reentered on accepted reference restore",
                    ),
                )
                @test restored.mmn.data == WI.read_wannier_mmn(restored.mmn_file).data
                @test restored.amn == WI.read_wannier_amn(restored.amn_file).data
                @test restored.paw_result !== nothing
                @test !restored.paw_result.passed
                @test haskey(result.input_summary, "native_matrix_acceptance_json")
                accepted = workflow._resolve_wannier_matrix_elements(
                    normalized,
                    basis;
                    accepted_result = result,
                    generator = (_, _) -> error("ACCEPTED_MATRIX_REGENERATION_FORBIDDEN"),
                    implementation_catalog = () ->
                        error("CONSUMER_IMPLEMENTATION_SCAN_FORBIDDEN"),
                )
                @test accepted.mmn.data == restored.mmn.data
                @test accepted.amn == restored.amn
                @test accepted.paw_result.diagnostics == restored.paw_result.diagnostics
                @test !accepted.paw_result.passed
                @test accepted.paw_result.input_sha256 == restored.paw_result.input_sha256
                reference_file = joinpath(dir, "accepted-reference.json")
                write(reference_file, result.input_summary["native_matrix_acceptance_json"])
                # The current reference needs actual config/basis/source files,
                # not a historical input digest. Transport only test context;
                # the fresh process still revalidates all real input/artifact bytes.
                files=collect(
                    values(workflow.native_preparation_source_files(normalized.input.source)),
                )
                for name in fieldnames(typeof(normalized.input.matrix_elements))
                    name==:artifact_dir && continue
                    value=getfield(normalized.input.matrix_elements, name)
                    value isa AbstractString && isfile(value) && push!(files, String(value))
                end
                for file in (
                    normalized.input.eig_file,
                    normalized.input.win_file,
                    normalized.input.band_representation_hdf5,
                    normalized.input.wavefunction_gauge_hdf5,
                )
                    file===nothing || (isfile(file) && push!(files, String(file)))
                end
                context_file=joinpath(dir, "accepted-context.jls")
                open(context_file, "w") do stream
                    serialize(stream, (config = normalized, basis = basis, files = files))
                end
                code = raw"""
using WannierNLQG,HDF5,EzXML,Spglib,JSON3,Serialization
W=WannierNLQG.Wannierization
E=first(W._load_wannierization_extension!()).WorkflowOrchestration
reference=JSON3.read(read(ARGS[1],String),Dict{String,String})
context=open(deserialize,ARGS[2])
result=Base.invokelatest(E._restore_accepted_matrix_reference,reference,context.config,context.basis,context.files)
@assert !result.paw_result.passed
@assert result.mmn.data==WannierNLQG.IO.read_wannier_mmn(result.mmn_file).data
@assert result.amn==WannierNLQG.IO.read_wannier_amn(result.amn_file).data
println("FRESH_ACCEPTED_NATIVE_DIAGNOSTIC_PASS")
"""
                command=`$(Base.julia_cmd()) --startup-file=no --project=$(dirname(@__DIR__)) -e $code $reference_file $context_file`
                @test occursin("FRESH_ACCEPTED_NATIVE_DIAGNOSTIC_PASS", read(command, String))
            end
            @test result.restart_state!==nothing
            @test result.restart_state.optimizer_state.u_steps>0
            @test result.input_summary["wannierization_eligibility_production_eligible"]=="false"
            @test any(
                d->d.code==:NATIVE_QE_PAW_QUALITY_CHECK &&
                   get(d.context, "gate_result", "")=="FAIL",
                result.diagnostics,
            )
            @test !any(d->d.code==:TB_EXPORT_FAILED, result.diagnostics)
            @test !any(d->d.code==:TB_SYMMETRY_QUALIFICATION_FAILED, result.diagnostics)
            # Ordinary solver identity sewing is not the final check's symmetry
            # context: posthoc reconstructs the actual cubic crystal operations.
            @test cfg.input.wannierization_mode == :ordinary
            @test cfg.input.num_wannier == 1
            source_eig = WI.read_wannier_eig(eig)
            @test size(source_eig.data) == (1, 1)
            mesh = WANNIERIZATION_IMPLEMENTATION.SolverCheckpoint.identity_band_representation(
                cfg,
                basis,
                source_eig,
            )
            context = workflow._ordinary_posthoc_qualification_context(cfg, mesh)
            # Independent cubic single-site group: all 48 signed permutations.
            expected_rotations = Set{NTuple{9, Int}}()
            for permutation in ((1, 2, 3), (1, 3, 2), (2, 1, 3), (2, 3, 1), (3, 1, 2), (3, 2, 1)),
                signs in Iterators.product((-1, 1), (-1, 1), (-1, 1))

                rotation = zeros(Int, 3, 3)
                for axis in 1:3
                    rotation[axis, permutation[axis]] = signs[axis]
                end
                push!(expected_rotations, Tuple(vec(rotation)))
            end
            @test Set(Tuple(vec(op.rotation_fractional)) for op in context.plan.operations) ==
                  expected_rotations
            @test all(
                op -> !op.antiunitary && all(iszero, op.translation_fractional),
                context.plan.operations,
            )
            @test Set(context.plan.operation_indices) == Set(eachindex(context.plan.operations))
            @test context.representation.kpoint_map == ones(Int, 48, 1)
            @test context.plan.representation_matrices == ones(ComplexF64, 1, 1, 48)
            @test all(iszero, context.plan.wannier_shifts)
            @test result.input_summary["final_tb_checked_operation_count"] == "48"
            bundle = WI.read_real_space_operator_bundle(result.artifacts.packed_hdf5)
            h = bundle.operators[WannierNLQG.Core.REAL_SPACE_HAMILTONIAN]
            position = bundle.operators[WannierNLQG.Core.REAL_SPACE_POSITION]
            @test h.r_vectors == zeros(Int, 3, 1)
            @test size(h.data) == (1, 1, 1) && !iszero(only(h.data)) && isreal(only(h.data))
            @test all(iszero, position.data)
            # Real scalar H(R=0), zero r and origin s orbital satisfy the full
            # nontrivial cubic group, so these are actual zero residuals.
            expected_metrics = Set((
                "hamiltonian_covariance_relative_max",
                "centerless_position_covariance_relative_max",
                "wcc_symmetry_orbit_residual_angstrom",
                "hamiltonian_hermiticity_max_ev",
                "position_hermiticity_max_angstrom",
                "kstar_spectral_residual_ev",
                "hamiltonian_projection_idempotence_max_ev",
                "centerless_position_projection_idempotence_max_angstrom",
            ))
            @test Set(m.name for m in result.tb_symmetry_qualification.metrics) == expected_metrics
            @test all(
                m -> m.value == 0.0 && m.status == "PASS" && m.applicability == "APPLICABLE",
                result.tb_symmetry_qualification.metrics,
            )
            @test result.tb_symmetry_qualification.overall == "PASS"
            # The native external-reference mismatch remains independently failed.
            @test !restored.paw_result.passed
            @test result.input_summary["wannierization_eligibility_production_eligible"] == "false"
            @test public_diagnostic_checkpoint_fresh_read(result, "NATIVE_QE_PAW_QUALITY_CHECK")
            @test public_diagnostic_chain_fresh_read(result, "NATIVE_QE_PAW_QUALITY_CHECK")
        end
        workflow = WANNIERIZATION_IMPLEMENTATION.WorkflowOrchestration
        failed_parity = W.generate_qe_paw_matrix_elements(
            source,
            f.nnkp_file;
            artifact_dir = joinpath(dir, "parity-check"),
            oracle_mmn_file = oracle.mmn,
            oracle_amn_file = oracle.amn,
        )
        @test !failed_parity.passed && !failed_parity.physical_overlap_available
        @test workflow._require_native_qe_paw_qualification(
            failed_parity;
            construction_policy = :standard,
        ) === nothing
        @test_throws ArgumentError workflow._require_native_qe_paw_qualification(
            failed_parity;
            construction_policy = :standard,
            propagation_identity = true,
        )
        missing_oracle = W.generate_qe_paw_matrix_elements(
            source,
            f.nnkp_file;
            artifact_dir = joinpath(dir, "missing-oracle"),
            require_oracle = true,
        )
        @test_throws ArgumentError workflow._require_native_qe_paw_qualification(
            missing_oracle;
            construction_policy = :standard,
        )
        invalid_amn = WI.WannierAMN(1, 1, 1, zeros(ComplexF64, 1, 1, 1))
        fields = fieldnames(W.QEPAWMatrixElementResult)
        rank_deficient = W.QEPAWMatrixElementResult(
            (name == :amn ? invalid_amn : getfield(failed_parity, name) for name in fields)...,
        )
        @test_throws ArgumentError workflow._require_native_qe_paw_qualification(
            rank_deficient;
            construction_policy = :standard,
        )

        # A genuine diagnostic capsule must also pass the default completed-matrix source into solve.
        completed_source = S.QuantumEspressoWavefunctionSource(
            f.save_directory;
            band_range = 1:1,
            include_time_reversal = false,
        )
        backend =
            W.StarCovariantPAWGauge(buffer_policy = W.ClosureDrivenBandBuffer(max_extra_bands = 0))
        gauge = W.prepare_symmetry_covariant_wavefunctions(
            W.SymmetryCovariantWavefunctionPreparationConfig(
                source = completed_source,
                wavefunction_gauge_backend = backend,
                construction_policy = :standard,
                output_hdf5 = joinpath(dir, "gauge.h5"),
                target_band_count = 1,
            ),
        )
        @test gauge.status == :STANDARD
        gauge_file = something(gauge.output_hdf5)
        original_gauge_sha256 = bytes2hex(SHA.sha256(read(gauge_file)))
        tampered_gauge = joinpath(dir, "gauge-one-ulp-tampered.h5")
        cp(gauge_file, tampered_gauge)
        chmod(tampered_gauge, 0o600)
        h5open(tampered_gauge, "r+") do handle
            dataset = handle["representative_frames/kpoint_000001/coefficients"]
            coefficients = read(dataset)
            original = coefficients[1]
            coefficients[1] = complex(nextfloat(real(original)), imag(original))
            @test 0 < abs(coefficients[1] - original) < 1.0e-14
            write(dataset, coefficients)
        end
        # A one-ULP persisted-frame difference is below the existing replay
        # tolerance; it is not a retired content-hash certificate failure.
        observed =
            WANNIERIZATION_IMPLEMENTATION.PAWMatrixElements._read_star_covariant_paw_gauge_hdf5(
                tampered_gauge;
                construction_policy = :standard,
                source = completed_source,
            )
        original_read =
            WANNIERIZATION_IMPLEMENTATION.PAWMatrixElements._read_star_covariant_paw_gauge_hdf5(
                gauge_file;
                construction_policy = :standard,
                source = completed_source,
            )
        @test observed.payload.native.kpoints[1].coefficients ==
              original_read.payload.native.kpoints[1].coefficients
        # A separate copy must still reject a mathematical replay violation at
        # the unchanged production threshold. Do not compare a hash or loosen it.
        replay_tolerance = h5open(gauge_file, "r") do handle
            parse(Float64, String(HDF5.read_attribute(handle, "band_frame_replay_tolerance")))
        end
        @test isfinite(replay_tolerance) && replay_tolerance > 0
        invalid_replay = joinpath(dir, "gauge-replay-invalid.h5")
        cp(gauge_file, invalid_replay)
        h5open(invalid_replay, "r+") do handle
            dataset = handle["representative_frames/kpoint_000001/coefficients"]
            coefficients = read(dataset)
            coefficients[1] += 10 * replay_tolerance
            write(dataset, coefficients)
        end
        h5open(invalid_replay, "r") do handle
            altered = read(handle["representative_frames/kpoint_000001/coefficients"])[1]
            baseline = h5open(gauge_file, "r") do reference
                read(reference["representative_frames/kpoint_000001/coefficients"])[1]
            end
            @test abs(altered - baseline) > replay_tolerance
        end
        tamper_error = try
            WANNIERIZATION_IMPLEMENTATION.PAWMatrixElements._read_star_covariant_paw_gauge_hdf5(
                invalid_replay;
                construction_policy = :standard,
                source = completed_source,
            )
            nothing
        catch error
            error
        end
        @test tamper_error isa ArgumentError
        if tamper_error isa ArgumentError
            @test occursin(
                "local-source representative replay differs",
                sprint(showerror, tamper_error),
            )
        end
        @test bytes2hex(SHA.sha256(read(gauge_file))) == original_gauge_sha256
        completed_config = modified_wannierization_config(
            base.config;
            construction_policy = :standard,
            initialization = :amn,
            wannierization_mode = :symmetry_adapted,
            band_representation = nothing,
            win_file = win,
            eig_file = splitext(gauge_file)[1] * ".eig",
            source = completed_source,
            sewing_backend = W.AugmentationAwareSewing(),
            wavefunction_gauge_backend = backend,
            wavefunction_gauge_hdf5 = gauge_file,
            matrix_elements = W.SymmetryCompletedQEPAWMatrices(
                f.nnkp_file,
                gauge_file;
                artifact_dir = joinpath(dir, "completed-matrices"),
            ),
            outer_min_ev = -18.0,
            outer_max_ev = 3.5,
            frozen_min_ev = -18.0,
            frozen_max_ev = 0.5,
            stage_controls = WANNIERIZATION.WannierizationStageControls(
                dis_num_iter = 1,
                num_iter = 2,
            ),
            acceleration = W.WannierizationAccelerationConfig(
                schedule = :two_stage,
                disentanglement_max_steps = 1,
                localization_max_steps = 2,
            ),
            checkpoint_hdf5 = joinpath(dir, "completed.wannierization.h5"),
            write_model_tb = true,
            tb_output_formats = (:packed_hdf5, :model_tb),
        )
        completed = W.construct_wannier_functions(completed_config)
        if completed.restart_state === nothing
            @error "Completed diagnostic chain stopped" diagnostics = completed.diagnostics
        end
        @test completed.restart_state !== nothing
        @test completed.restart_state.optimizer_state.u_steps > 0
        @test completed.input_summary["wannierization_eligibility_production_eligible"] == "false"
        @test !haskey(completed.input_summary, "wavefunction_gauge_hdf5_sha256")
        @test completed.input_summary["wavefunction_gauge_definition"] ==
              gauge.input_sha256["BAND_FRAME_CONTRACT_DEFINITION"]
        @test any(d -> d.code == :PAW_SEWING_QUALITY_CHECK, completed.diagnostics)
        @test public_diagnostic_checkpoint_fresh_read(completed, "PAW_SEWING_QUALITY_CHECK")
        @test public_diagnostic_chain_fresh_read(completed, "PAW_SEWING_QUALITY_CHECK")
    end
end

@testset "Same perturbed center reaches public solve and fresh dual TB" begin
    isdefined(@__MODULE__, :BandPublicSchemaTestSupport) ||
        include(joinpath(@__DIR__, "BandPublicSchemaTestSupport.jl"))
    W = WANNIERIZATION
    S = WannierNLQG.SymmetryFoundation
    WI = WANNIER_IO
    mktempdir() do dir
        f=synthetic_wannierization_fixture()
        r=f.representation
        ops=[
            only(r.operations),
            S.SymmetryOperation(-Matrix{Int}(I, 3, 3), zeros(3), -Matrix{Float64}(I, 3, 3), false),
        ]
        theta=Matrix{ComplexF64}(I, 2, 2)
        sewing=zeros(ComplexF64, 4, 4, 2, 2)
        for k in 1:2
            ;
            sewing[:, :, 1, k].=Matrix{ComplexF64}(I, 4, 4);
            sewing[1:2, 1:2, 2, k].=theta;
            sewing[3:4, 3:4, 2, k].=theta;
        end
        energies=[-1.0 -1.0; -1.0 -1.0; 1.0 1.0; 1.0 1.0]
        basis=BandPublicSchemaTestSupport.single_site_s_basis(spinor = true)
        basis.blocks[1].positions_fractional[1, 1] = 1.0e-7
        input_centers = copy(basis.blocks[1].positions_fractional)
        shifts=zeros(Int, 3, 2, 2);
        shifts[1, 2, 2]=-1
        raw=S.BandRepresentation(
            "1.0",
            :synthetic,
            true,
            r.real_lattice,
            r.reciprocal_lattice,
            r.mp_grid,
            r.kpoints_fractional,
            energies,
            ops,
            repeat(r.kpoint_map, 2, 1),
            shifts,
            sewing,
            [1 1; 1 1; 2 2; 2 2],
            r.irreducible_indices,
            r.full_to_irreducible,
            r.full_to_operation;
            input_sha256 = Dict(
                "synthetic_sewing"=>bytes2hex(sha256(reinterpret(UInt8, vec(sewing)))),
            ),
        )
        win=joinpath(dir, "model.win");
        eig=joinpath(dir, "model.eig");
        mmn=joinpath(dir, "model.mmn")
        write(win, "num_wann = 2\nmp_grid = 2 1 1\nbegin projections\nX:s\nend projections\n")
        open(eig, "w") do io
            for k in 1:2, b in 1:4
                ;
                println(io, b, " ", k, " ", energies[b, k]);
            end
        end
        mmndata=repeat(reshape(Matrix{ComplexF64}(I, 4, 4), 4, 4, 1, 1), 1, 1, 6, 2)
        WI.write_wannier_mmn(
            mmn,
            WI.WannierMMN(4, 2, 6, mmndata, f.mmn.neighbors, f.mmn.reciprocal_shifts),
        )
        prep(
            policy,
        )=W.prepare_band_representation(
            W.BandRepresentationPreparationConfig(
                construction_policy = policy,
                wannierization_mode = :symmetry_adapted,
                win_file = win,
                eig_file = eig,
                projection_basis = basis,
                band_representation = raw,
                output_hdf5 = joinpath(dir, string(policy)*"-representation.h5"),
                num_wannier = 2,
                outer_min_ev = -2.0,
                outer_max_ev = 2.0,
                frozen_min_ev = -2.0,
                frozen_max_ev = -0.5,
                compatibility_policy = :strict,
            ),
        )
        strict=try
            prep(:strict)
        catch err
            ;
            err
        end
        @test strict isa Exception || strict.status==:FAILED
        strict_reason =
            strict isa Exception ? sprint(showerror, strict) :
            join((d.message for d in strict.diagnostics), "\n")
        @test occursin("construction_policy=:strict", strict_reason)
        @test basis.blocks[1].positions_fractional == input_centers
        prepared=prep(:standard)
        @test prepared.status in (:PASS, :PASS_WITH_WARNINGS)
        center_failures = filter(d -> d.code == :PROJECTION_CENTER_RESIDUAL, prepared.diagnostics)
        @test !isempty(center_failures)
        @test all(
            d ->
                get(d.context, "gate_result", "") == "FAIL" &&
                get(d.context, "action", "") == "CONTINUE_STANDARD",
            center_failures,
        )
        @test all(
            d ->
                parse(Float64, d.context["value"]) == 2.0e-7 &&
                parse(Float64, d.context["threshold"]) == 1.0e-8,
            center_failures,
        )
        @test basis.blocks[1].positions_fractional == input_centers
        representation=S.read_band_representation_hdf5(
            prepared.output_hdf5;
            content_authentication = false,
        )
        @test representation.sewing_matrices==sewing
        cfg=modified_wannierization_config(
            f.config;
            construction_policy = :standard,
            projection_basis = basis,
            num_wannier = 2,
            win_file = win,
            eig_file = eig,
            mmn_file = mmn,
            band_representation = nothing,
            band_representation_hdf5 = prepared.output_hdf5,
            compatibility_policy = :strict,
            stage_controls = WANNIERIZATION.WannierizationStageControls(
                dis_num_iter = 2,
                num_iter = 2,
            ),
            checkpoint_hdf5 = joinpath(dir, "run.wannierization.h5"),
            write_model_tb = true,
            tb_output_formats = (:packed_hdf5, :model_tb),
            acceleration = W.WannierizationAccelerationConfig(
                schedule = :two_stage,
                disentanglement_max_steps = 2,
                localization_max_steps = 2,
            ),
        )
        result=W.construct_wannier_functions(cfg)
        @test result.restart_state!==nothing
        @test result.restart_state.optimizer_state.u_steps>0
        @test result.input_summary["wannierization_eligibility_production_eligible"]=="false"
        @test any(
            d->d.code==:PROJECTION_CENTER_RESIDUAL && get(d.context, "gate_result", "")=="FAIL",
            result.diagnostics,
        )
        @test public_diagnostic_chain_fresh_read(result, "PROJECTION_CENTER_RESIDUAL")
        @test basis.blocks[1].positions_fractional == input_centers
    end
end

@testset "Public periodic standard checkpoint restarts in a fresh process" begin
    W = WANNIERIZATION
    WI = WANNIER_IO
    mktempdir() do directory
        fixture = synthetic_wannierization_fixture()
        r = fixture.representation
        S = WannierNLQG.SymmetryFoundation
        fixture.basis.blocks[1].positions_fractional[1, 1] = 1.0e-7
        shifts = zeros(Int, 3, 2, 2)
        shifts[1, 2, 2] = -1
        inversion_representation = S.BandRepresentation(
            "1.0",
            :synthetic,
            false,
            r.real_lattice,
            r.reciprocal_lattice,
            r.mp_grid,
            r.kpoints_fractional,
            r.energies_ev,
            [
                only(r.operations),
                S.SymmetryOperation(-Matrix{Int}(I, 3, 3), zeros(3), -Matrix{Float64}(I, 3, 3)),
            ],
            repeat(r.kpoint_map, 2, 1),
            shifts,
            repeat(reshape(Matrix{ComplexF64}(I, 2, 2), 2, 2, 1, 1), 1, 1, 2, 2),
            r.band_block_labels,
            r.irreducible_indices,
            r.full_to_irreducible,
            r.full_to_operation,
        )
        win = joinpath(directory, "model.win")
        eig = joinpath(directory, "model.eig")
        mmn = joinpath(directory, "model.mmn")
        write(win, "num_wann = 1\nmp_grid = 2 1 1\nbegin projections\nX:s\nend projections\n")
        open(eig, "w") do io
            for kpoint in 1:2, band in 1:2
                println(io, band, " ", kpoint, " ", fixture.eig.data[band, kpoint])
            end
        end
        WI.write_wannier_mmn(mmn, fixture.mmn)
        prepared = W.prepare_band_representation(
            W.BandRepresentationPreparationConfig(
                construction_policy = :standard,
                wannierization_mode = :symmetry_adapted,
                win_file = win,
                eig_file = eig,
                projection_basis = fixture.basis,
                band_representation = inversion_representation,
                output_hdf5 = joinpath(directory, "representation.h5"),
                num_wannier = 1,
                outer_min_ev = -2.0,
                outer_max_ev = 2.0,
                frozen_min_ev = -2.0,
                frozen_max_ev = -0.5,
            ),
        )
        @test prepared.status in (:PASS, :PASS_WITH_WARNINGS)
        # The parent and child execute the same explicit public input configuration.
        setup_file = joinpath(directory, "periodic_public_setup.jl")
        write(
            setup_file,
            """
using WannierNLQG, HDF5, EzXML, JSON3, Spglib, LinearAlgebra, SHA
if !isdefined(@__MODULE__, :WANNIERIZATION_FIXTURE_SUPPORT_LOADED)
    include(joinpath(dirname(Base.active_project()), "test/WannierizationFixtureSupport.jl"))
end
function periodic_public_test_config(directory; observer = nothing, restart = false)
    f = synthetic_wannierization_fixture()
    f.basis.blocks[1].positions_fractional[1, 1] = 1.0e-7
    W = WannierNLQG.Wannierization
    acceleration = W.WannierizationAccelerationConfig(schedule = :two_stage,
        disentanglement_max_steps = 2, localization_max_steps = 6,
        disentanglement_limit_policy = :standard_continue)
    config = modified_wannierization_config(f.config; construction_policy = :standard,
        win_file = joinpath(directory, "model.win"), eig_file = joinpath(directory, "model.eig"),
        mmn_file = joinpath(directory, "model.mmn"), band_representation = nothing,
        band_representation_hdf5 = joinpath(directory, "representation.h5"),
        acceleration, stage_controls = W.WannierizationStageControls(
            dis_num_iter = 2, num_iter = 6, dis_conv_window = 20, conv_window = 20),
        parallel = :threads,
        checkpoint_hdf5 = joinpath(directory, restart ? "restart.wannierization.h5" : "full.wannierization.h5"),
        num_dump_cycles = 1, iteration_observer = observer,
        tb_output_formats = (:packed_hdf5, :model_tb), write_model_tb = true)
    return restart ? modified_wannierization_config(config; initialization = :restart,
        restart_hdf5 = joinpath(directory, "periodic.h5")) : config
end
""",
        )
        include(setup_file)
        periodic = joinpath(directory, "periodic.h5")
        capture = function (snapshot, args...)
            snapshot.iteration == 4 && cp(joinpath(directory, "full.wannierization.h5"), periodic)
        end
        config = Base.invokelatest(periodic_public_test_config, directory; observer = capture)
        full = W.construct_wannier_functions(config)
        @test full.restart_state !== nothing
        @test isfile(periodic)
        # A copied checkpoint is a relocated input and needs explicit adoption.
        @test_throws ArgumentError W.read_wannierization_checkpoint_hdf5(periodic)
        W.adopt_wannierization_checkpoint_hdf5(periodic)
        prior = W.read_wannierization_checkpoint_hdf5(periodic)
        @test prior.status == W.IN_PROGRESS_CHECKPOINT
        @test prior.restart_state.iteration == 4
        @test prior.restart_state.optimizer_state.u_steps > 0
        @test prior.input_summary["construction_policy"] == "standard"
        @test prior.input_summary["quality_review_recommended"] == "true"
        @test prior.input_summary["quality_review_status"] == "RECOMMENDED"
        @test prior.input_summary["wannierization_eligibility_production_eligible"] == "false"
        @test prior.input_summary["global_production_eligible"] == "false"
        @test prior.input_summary["model_qualification"] == "COMPUTATION_READY"
        @test prior.input_summary["construction_quality_failed"] == "true"
        @test prior.input_summary["operator_profile_preflight_status"] == "NOT_APPLICABLE"
        @test prior.input_summary["operator_profile_preflight_profile"] == "hamiltonian_position"
        @test full.input_summary["operator_profile_preflight_status"] == "NOT_APPLICABLE"
        @test full.input_summary["operator_profile_preflight_profile"] == "hamiltonian_position"
        center_failures = filter(d -> d.code == :PROJECTION_CENTER_RESIDUAL, prior.diagnostics)
        @test length(center_failures) == 1
        @test only(center_failures).context["value"] == "2.0e-7"
        @test only(center_failures).context["threshold"] == "1.0e-8"
        @test only(center_failures).context["gate_result"] == "FAIL"
        @test count(d -> d.code == :PROJECTION_CENTER_RESIDUAL, full.diagnostics) == 1
        for key in (
            "authoritative_hamiltonian",
            "authoritative_hamiltonian_sha256",
            "qualification_scope",
            "target_authority",
            "parent_audit_policy",
            "target_subspace_contract_definition",
            "disentanglement_outer_mask_definition",
            "disentanglement_frozen_mask_definition",
            "target_leakage_semantics",
            "target_leakage_formula_definition",
            "target_leakage_threshold",
        )
            @test prior.input_summary[key] == full.input_summary[key]
        end
        original_sha = bytes2hex(SHA.sha256(read(periodic)))
        child = """
        using Test
        include(ARGS[1])
        W = WannierNLQG.Wannierization
        prior = W.read_wannierization_checkpoint_hdf5(joinpath(ARGS[2], "periodic.h5"))
        full = W.read_wannierization_checkpoint_hdf5(joinpath(ARGS[2], "full.wannierization.h5"))
        cfg = periodic_public_test_config(ARGS[2]; restart = true)
        recovered = W.construct_wannier_functions(cfg)
        @testset "Fresh public periodic checkpoint tail replay" begin
            @test recovered.restart_state !== nothing
            @test something(recovered.restart_state.input_definition).configuration == something(prior.restart_state.input_definition).configuration
            @test WannierNLQG.IO.validate_scientific_input_definitions_equal(
                something(recovered.restart_state.input_definition).representation,
                something(prior.restart_state.input_definition).representation) === nothing
            for field in fieldnames(W.WannierizationFiniteDifferenceStencil)
                @test isequal(getfield(recovered.restart_state.stencil, field),
                              getfield(prior.restart_state.stencil, field))
            end
            @test recovered.restart_state.optimizer_state.z_steps == full.restart_state.optimizer_state.z_steps
            @test recovered.restart_state.optimizer_state.u_steps == full.restart_state.optimizer_state.u_steps
            @test recovered.restart_state.iteration - prior.restart_state.iteration <= 4
            @test recovered.v_matrix == full.v_matrix
            @test recovered.spreads_angstrom2 == full.spreads_angstrom2
            @test recovered.status == full.status
            @test isequal(recovered.history[1:length(prior.history)], prior.history)
            @test recovered.artifacts.packed_hdf5 !== nothing
            @test recovered.artifacts.model_tb !== nothing
            @test recovered.input_summary["wannierization_eligibility_production_eligible"] == "false"
            prior_center = only(filter(d -> d.code == :PROJECTION_CENTER_RESIDUAL, prior.diagnostics))
            recovered_center = only(filter(d -> d.code == :PROJECTION_CENTER_RESIDUAL, recovered.diagnostics))
            @test recovered_center.context == prior_center.context
            @test recovered.input_summary["construction_quality_failed"] == "true"
            @test bytes2hex(SHA.sha256(read(joinpath(ARGS[2], "periodic.h5")))) == ARGS[3]
        end
        println("FRESH_PUBLIC_PERIODIC_RESTART_PASS")
        """
        command =
            `$(Base.julia_cmd()) --startup-file=no --threads=1 --project=$(dirname(@__DIR__)) -e $(child) $(setup_file) $(directory) $(original_sha)`
        @test occursin("FRESH_PUBLIC_PERIODIC_RESTART_PASS", read(command, String))
        @test bytes2hex(SHA.sha256(read(periodic))) == original_sha
        paths = WANNIERIZATION_IMPLEMENTATION.OperatorExport.wannierization_output_paths
        output = paths(joinpath(directory, "restart.wannierization.h5"))
        fresh_readback = """
        using WannierNLQG, HDF5, SHA
        W = WannierNLQG.Wannierization
        result = W.read_wannierization_checkpoint_hdf5(ARGS[1])
        bytes2hex(SHA.sha256(reinterpret(UInt8, vec(result.v_matrix)))) == ARGS[4] || error("accepted arrays differ")
        bundle = WannierNLQG.IO.read_real_space_operator_bundle(ARGS[2])
        tb = WannierNLQG.IO.read_wannier_tb(ARGS[3])
        result.input_summary["construction_quality_failed"] == "true" || error("measured construction warning disappeared")
        any(d -> d.code == :PROJECTION_CENTER_RESIDUAL && get(d.context, "gate_result", "") == "FAIL",
            result.diagnostics) || error("center warning disappeared from checkpoint")
        all(operator -> all(isfinite, operator.data), values(bundle.operators)) || error("model operators are nonfinite")
        all(isfinite, tb.hamiltonian_r) || error("nonfinite TB")
        println("PERIODIC_RESTART_DUAL_FRESH_READ_PASS")
        """
        digest = bytes2hex(SHA.sha256(reinterpret(UInt8, vec(full.v_matrix))))
        command =
            `$(Base.julia_cmd()) --startup-file=no --threads=1 --project=$(dirname(@__DIR__)) -e $(fresh_readback) $(output.checkpoint) $(output.packed) $(output.wannier) $(digest)`
        @test occursin("PERIODIC_RESTART_DUAL_FRESH_READ_PASS", read(command, String))
    end
end

@testset "Standard export classifies measured quality without masking integrity" begin
    exported = WANNIERIZATION_IMPLEMENTATION.OperatorExport
    function quality(code; context = Dict("value"=>"0.5", "threshold"=>"1e-10"))
        WANNIERIZATION.WannierizationDiagnostic(
            code,
            :error,
            "fixture";
            context = merge(Dict("action"=>"CONTINUE_STANDARD"), context),
        )
    end
    for code in (
        :MMN_STENCIL_COMPLETENESS_FAILED,
        :TARGET_SYMMETRY_TANGENT_RESIDUAL_FAILED,
        :SOLVER_TRIAL_COVARIANCE_FAILED,
        :SOLVER_TRIAL_TARGET_SYMMETRY_FAILED,
    )
        @test exported._standard_construction_quality_error(quality(code))
        @test !exported._standard_construction_quality_error(
            quality(code; context = Dict("value"=>"Inf")),
        )
        @test !exported._standard_construction_quality_error(
            quality(code; context = Dict{String, String}()),
        )
    end
    @test exported._standard_construction_quality_error(
        WANNIERIZATION.WannierizationDiagnostic(
            :THETA_SQUARED_FAILED,
            :error,
            "raw audit";
            context = Dict("maximum_error"=>"0.2", "tolerance"=>"1e-10"),
        ),
    )
    @test !exported._standard_construction_quality_error(
        quality(
            :SEWING_BLOCK_RANK_DEFICIENT;
            context = Dict(
                "maximum_error"=>"1.0",
                "tolerance"=>"1e-8",
                "required_rank"=>"2",
                "numerical_rank"=>"1",
            ),
        ),
    )
    @test !exported._standard_construction_quality_error(quality(:UNKNOWN_ERROR))
    @test !exported._standard_construction_quality_error(quality(:FROZEN_MASK_IDENTITY_MISMATCH))
    @test !exported._standard_construction_quality_error(
        quality(
            :TARGET_REPRESENTATION_GROUP_LAW_FAILED;
            context = Dict("band_count"=>"2", "target_count"=>"1"),
        ),
    )
    for code in (
        :REQUIRED_BLOCK_UNITARITY_FAILED,
        :ANTIUNITARY_GROUP_LAW_FAILED,
        :TARGET_REPRESENTATION_GROUP_LAW_FAILED,
        :THETA_SQUARED_FAILED,
        :ANTIUNITARY_PROJECTOR_COVARIANCE_FAILED,
    )
        @test exported._standard_construction_quality_error(
            quality(code; context = Dict("maximum_error"=>"0.5")),
        )
        @test !exported._standard_construction_quality_error(
            quality(code; context = Dict("maximum_error"=>"NaN")),
        )
    end
    for (source, target, allowed) in ((2, 2, true), (2, 4, false), (3, 3, false), (-2, -2, false))
        diagnostic=quality(
            :KRAMERS_BLOCK_NOT_CLOSED;
            context = Dict(
                "maximum_error"=>"0.2",
                "source_rank"=>string(source),
                "target_rank"=>string(target),
                "source_kpoint"=>"1",
                "target_kpoint"=>"1",
            ),
        )
        @test exported._standard_construction_quality_error(diagnostic)==allowed
    end
end

include("FrozenWindowContainmentChecks.jl")
