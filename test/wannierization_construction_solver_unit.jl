using Test
using LinearAlgebra
if !isdefined(@__MODULE__, :WANNIERIZATION_FIXTURE_SUPPORT_LOADED)
    include(joinpath(@__DIR__, "WannierizationFixtureSupport.jl"))
end

@testset "Diagnostic construction preserves finite-difference arithmetic and hard rank" begin
    fixture = synthetic_wannierization_fixture()
    solver = WANNIERIZATION_IMPLEMENTATION.SolverCheckpoint
    strict = solver._finite_difference_weights(fixture.representation, fixture.mmn)
    diagnostic = solver._finite_difference_weights(
        fixture.representation,
        fixture.mmn;
        construction_policy = :diagnostic,
    )
    @test strict.weights == diagnostic.weights
    @test strict.digest == diagnostic.digest
    strict_result = WANNIERIZATION._solve_symmetry_adapted_wannierization(
        fixture.config,
        fixture.representation,
        fixture.eig,
        fixture.mmn,
        fixture.plan,
    )
    diagnostic_result = WANNIERIZATION._solve_symmetry_adapted_wannierization(
        modified_wannierization_config(fixture.config; construction_policy = :diagnostic),
        fixture.representation,
        fixture.eig,
        fixture.mmn,
        fixture.plan,
    )
    @test strict_result.v_matrix == diagnostic_result.v_matrix
    @test strict_result.spreads_angstrom2 == diagnostic_result.spreads_angstrom2
    fixture.representation.reciprocal_lattice[1, 2] += 2.0e-7
    @test_throws ArgumentError solver._finite_difference_weights(
        fixture.representation,
        fixture.mmn,
    )
    perturbed = solver._finite_difference_weights(
        fixture.representation,
        fixture.mmn;
        construction_policy = :diagnostic,
    )
    @test perturbed.completeness_residual > 1.0e-10
    @test all(isfinite, perturbed.weights)
    fixture.representation.reciprocal_lattice[3, :] .= 0.0
    @test_throws ArgumentError solver._finite_difference_weights(
        fixture.representation,
        fixture.mmn;
        construction_policy = :diagnostic,
    )
end

@testset "Diagnostic quality failures reach accepted state, persist, and export" begin
    fixture = synthetic_wannierization_fixture()
    fixture.representation.reciprocal_lattice[1, 2] += 2.0e-7
    config = modified_wannierization_config(
        fixture.config;
        construction_policy = :diagnostic,
        max_iterations = 2,
        write_wannier90_tb = true,
        tb_output_formats = (:packed_hdf5, :wannier90_tb),
    )
    strict = WANNIERIZATION._solve_symmetry_adapted_wannierization(
        modified_wannierization_config(config; construction_policy = :strict),
        fixture.representation,
        fixture.eig,
        fixture.mmn,
        fixture.plan,
    )
    @test strict.status == WANNIERIZATION.INVALID_INPUT
    result = WANNIERIZATION._solve_symmetry_adapted_wannierization(
        config,
        fixture.representation,
        fixture.eig,
        fixture.mmn,
        fixture.plan,
    )
    @test result.restart_state !== nothing
    @test result.input_summary["has_accepted_state"] == "true"
    @test startswith(result.input_summary["model_qualification"], "DIAGNOSTIC_ONLY")
    failures = filter(d -> d.code == :MMN_STENCIL_COMPLETENESS_FAILED, result.diagnostics)
    @test length(failures) == 1
    @test only(failures).severity == :error
    @test only(failures).context["gate_result"] == "FAIL"
    @test only(failures).context["action"] == "CONTINUE_DIAGNOSTIC"
    exported = WANNIERIZATION_IMPLEMENTATION.OperatorExport
    gate = exported._diagnostic_nonconverged_tb_export_gate(result, config)
    @test gate.allowed
    @test !WANNIERIZATION_IMPLEMENTATION.SolverCheckpoint.wannierization_production_eligible(result)
    mktempdir() do directory
        checkpoint = joinpath(directory, "diagnostic.wannierization.h5")
        WANNIERIZATION.write_wannierization_checkpoint_hdf5(checkpoint, result)
        restored = WANNIERIZATION.read_wannierization_checkpoint_hdf5(checkpoint)
        @test restored.v_matrix == result.v_matrix
        @test restored.input_summary["construction_policy"] == "diagnostic"
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
        @test isfile(metadata["wannier90_diagnostic_metadata"])
        sidecar = JSON3.read(read(metadata["wannier90_diagnostic_metadata"], String))
        @test String(sidecar.wannier90_tb_sha256) == bytes2hex(SHA.sha256(read(exchange)))
        @test !sidecar.production_eligible
        @test metadata["diagnostic_classification"] == "DIAGNOSTIC_ONLY_QUALITY_FAILED"
        @test occursin("CONTINUE_DIAGNOSTIC", metadata["construction_gate_records_json"])
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
    @test exported._diagnostic_nonconverged_tb_export_gate(failed, config).allowed
    support = WANNIERIZATION_IMPLEMENTATION.WannierizationInternalSupport
    missing = support.updated_wannierization_result(result; restart_state = nothing)
    @test !exported._diagnostic_nonconverged_tb_export_gate(missing, config).allowed
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
    @test !exported._diagnostic_nonconverged_tb_export_gate(corrupted, config).allowed
end

@testset "Diagnostic Z handoff retains geometry gates" begin
    fixture = synthetic_wannierization_fixture()
    solver = WANNIERIZATION_IMPLEMENTATION.SolverCheckpoint
    frames = [reshape(ComplexF64[1, 0], 2, 1) for _ in 1:2]
    z = [Matrix{ComplexF64}(I, 2, 2) for _ in 1:2]
    qualifier(values; policy = :diagnostic) = solver._qualify_nonconverged_disentanglement_state(
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
    @test !qualifier(frames; policy = :strict).qualified
    @test qualifier(frames).qualified
    @test !qualifier([zero(frame) for frame in frames]).qualified
    @test !qualifier([2frame for frame in frames]).qualified
end

@testset "Failed Z trial uses the shared seal and accepted geometry for U" begin
    fixture = synthetic_wannierization_fixture()
    solver = WANNIERIZATION_IMPLEMENTATION.SolverCheckpoint
    config = modified_wannierization_config(
        fixture.config;
        construction_policy = :diagnostic,
        max_iterations = 3,
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
    @test continued.diagnostic_disentanglement_nonconverged
    @test any(d -> d.code == :SYNTHETIC_Z_TRIAL_FAILED, continued.diagnostics)
    @test any(
        d -> d.code == :DISENTANGLEMENT_FAILED_TRIAL_CONTINUED_DIAGNOSTIC,
        continued.diagnostics,
    )
    terminal = solver._run_solver_iterations(continued)
    result =
        terminal isa WANNIERIZATION.WannierizationResult ? terminal :
        solver._assemble_solver_terminal_result(terminal)
    @test result.restart_state !== nothing
    @test result.restart_state.optimizer_state.u_steps > 0
    @test result.input_summary["qualified_z_seal"] == "false"
    @test state.latest_restart_state.frames == retained
    strict_state = merge(
        state,
        (; config = modified_wannierization_config(config; construction_policy = :strict)),
    )
    @test solver._continue_failed_disentanglement(strict_state, failed, 1) === failed
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
            construction_policy = :diagnostic,
        ) == requested
        @test workflow._effective_compatibility_policy(
            requested,
            fixture.representation,
            (magnetic = false,);
            public_origin_fallback_validated = true,
            construction_policy = :strict,
        ) == :strict
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
    reflection = ComplexF64[1 0; 0 -1]
    probe = ComplexF64[2+3im 4+5im; 6+7im 8+9im]
    expected = ComplexF64[2 0; 0 8]
    for policy in (:strict, :diagnostic)
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
    using WannierNLQG, HDF5, SHA
    result = WannierNLQG.Wannierization.read_wannierization_checkpoint_hdf5(ARGS[1])
    result.input_summary["production_eligible"] == "false" || error("production flag changed")
    bytes2hex(sha256(reinterpret(UInt8, vec(result.v_matrix)))) == ARGS[5] || error("accepted arrays changed")
    bundle = WannierNLQG.IO.read_real_space_operator_bundle(ARGS[2])
    bundle.manifest.diagnostic_only && !bundle.manifest.production_eligible || error("Packed eligibility changed")
    tb = WannierNLQG.IO.read_wannier_tb(ARGS[3])
    all(isfinite, tb.hamiltonian_r) || error("TB is nonfinite")
    h5open(ARGS[2], "r") do handle
        records = String(read(HDF5.attributes(handle["construction_evidence"])["construction_gate_records_json"]))
        occursin(ARGS[4], records) || error("original gate evidence disappeared")
    end
    println("PUBLIC_DIAGNOSTIC_CHAIN_FRESH_READ_PASS")
    """
    artifacts = result.artifacts
    digest = bytes2hex(SHA.sha256(reinterpret(UInt8, vec(result.v_matrix))))
    command =
        `$(Base.julia_cmd()) --startup-file=no --threads=1 --project=$(dirname(@__DIR__)) -e $(script) $(artifacts.checkpoint_hdf5) $(artifacts.packed_hdf5) $(artifacts.wannier90_tb) $(expected_code) $(digest)`
    return occursin("PUBLIC_DIAGNOSTIC_CHAIN_FRESH_READ_PASS", read(command, String))
end

@testset "Public diagnostic antiunitary quality chain reaches readable TB" begin
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
        prepared=prep(:diagnostic)
        @test prepared.status in (:PASS, :PASS_WITH_WARNINGS)
        representation=S.read_band_representation_hdf5(prepared.output_hdf5)
        @test representation.sewing_matrices==sewing
        cfg=modified_wannierization_config(
            f.config;
            construction_policy = :diagnostic,
            projection_basis = basis,
            num_wannier = 2,
            win_file = win,
            eig_file = eig,
            mmn_file = mmn,
            band_representation = nothing,
            band_representation_hdf5 = prepared.output_hdf5,
            compatibility_policy = :strict,
            max_iterations = 3,
            checkpoint_hdf5 = joinpath(dir, "run.wannierization.h5"),
            write_wannier90_tb = true,
            tb_output_formats = (:packed_hdf5, :wannier90_tb),
            acceleration = W.WannierizationAccelerationConfig(
                schedule = :two_stage,
                disentanglement_max_steps = 2,
                localization_max_steps = 2,
            ),
        )
        result=W.construct_symmetry_adapted_wannier_functions(cfg)
        @test result.restart_state!==nothing
        @test result.restart_state.optimizer_state.u_steps>0
        @test result.input_summary["production_eligible"]=="false"
        @test any(
            d->d.code==:THETA_SQUARED_FAILED && get(d.context, "gate_result", "")=="FAIL",
            result.diagnostics,
        )
        @test public_diagnostic_chain_fresh_read(result, "THETA_SQUARED_FAILED")
    end
end

@testset "QE diagnostic admission retains metric and identity hard gates" begin
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
    result.input_summary["construction_policy"] == "diagnostic" || error("policy changed")
    result.input_summary["production_eligible"] == "false" || error("production flag changed")
    any(d -> string(d.code) == ARGS[2], result.diagnostics) || error("original diagnostics disappeared")
    println("PUBLIC_DIAGNOSTIC_CHECKPOINT_FRESH_READ_PASS")
    """
    command =
        `$(Base.julia_cmd()) --startup-file=no --threads=1 --project=$(dirname(@__DIR__)) -e $(script) $(result.artifacts.checkpoint_hdf5) $(expected_code) $(digest)`
    return occursin("PUBLIC_DIAGNOSTIC_CHECKPOINT_FRESH_READ_PASS", read(command, String))
end

@testset "Public native QE parity failure reaches diagnostic solve and fresh checkpoint" begin
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
        QEPAWMatrixElementsTestSupport.write_qe_paw_oracle_provenance(
            joinpath(dir, "oracle"),
            raw.input_sha256,
        )
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
        for policy in (:strict, :diagnostic)
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
                max_iterations = 3,
                acceleration = W.WannierizationAccelerationConfig(
                    schedule = :two_stage,
                    disentanglement_max_steps = 1,
                    localization_max_steps = 2,
                ),
                checkpoint_hdf5 = joinpath(dir, string(policy)*".wannierization.h5"),
                write_wannier90_tb = true,
                tb_output_formats = (:packed_hdf5, :wannier90_tb),
            )
            result=W.construct_symmetry_adapted_wannier_functions(cfg)
            if policy==:strict
                @test result.restart_state===nothing
            else
                @test result.restart_state!==nothing
                @test result.restart_state.optimizer_state.u_steps>0
                @test result.input_summary["production_eligible"]=="false"
                @test any(
                    d->d.code==:NATIVE_QE_PAW_QUALITY_CHECK &&
                       get(d.context, "gate_result", "")=="FAIL",
                    result.diagnostics,
                )
                @test !any(d->d.code==:TB_EXPORT_FAILED, result.diagnostics)
                @test !any(d->d.code==:TB_SYMMETRY_QUALIFICATION_FAILED, result.diagnostics)
                @test result.tb_symmetry_qualification.overall=="INCOMPLETE"
                @test result.tb_symmetry_qualification.reason!="QUALIFICATION_EVALUATION_FAILED"
                @test any(
                    metric->metric.status=="NOT_APPLICABLE",
                    result.tb_symmetry_qualification.metrics,
                )
                @test public_diagnostic_checkpoint_fresh_read(result, "NATIVE_QE_PAW_QUALITY_CHECK")
                @test public_diagnostic_chain_fresh_read(result, "NATIVE_QE_PAW_QUALITY_CHECK")
            end
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
            construction_policy = :diagnostic,
        ) === nothing
        @test_throws ArgumentError workflow._require_native_qe_paw_qualification(
            failed_parity;
            construction_policy = :diagnostic,
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
            construction_policy = :diagnostic,
        )
        invalid_amn = WI.WannierAMN(1, 1, 1, zeros(ComplexF64, 1, 1, 1))
        fields = fieldnames(W.QEPAWMatrixElementResult)
        rank_deficient = W.QEPAWMatrixElementResult(
            (name == :amn ? invalid_amn : getfield(failed_parity, name) for name in fields)...,
        )
        @test_throws ArgumentError workflow._require_native_qe_paw_qualification(
            rank_deficient;
            construction_policy = :diagnostic,
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
                construction_policy = :diagnostic,
                output_hdf5 = joinpath(dir, "gauge.h5"),
                target_band_count = 1,
            ),
        )
        @test gauge.status == :DIAGNOSTIC_ONLY
        gauge_file = something(gauge.output_hdf5)
        original_gauge_sha256 = bytes2hex(SHA.sha256(read(gauge_file)))
        tampered_gauge = joinpath(dir, "gauge-one-ulp-tampered.h5")
        cp(gauge_file, tampered_gauge)
        h5open(tampered_gauge, "r+") do handle
            dataset = handle["representative_frames/kpoint_000001/coefficients"]
            coefficients = read(dataset)
            original = coefficients[1]
            coefficients[1] = complex(nextfloat(real(original)), imag(original))
            @test 0 < abs(coefficients[1] - original) < 1.0e-14
            write(dataset, coefficients)
        end
        tamper_error = try
            WANNIERIZATION_IMPLEMENTATION.PAWMatrixElements._read_star_covariant_paw_gauge_hdf5(
                tampered_gauge;
                construction_policy = :diagnostic,
                source = completed_source,
            )
            nothing
        catch err
            err
        end
        @test tamper_error isa ArgumentError
        @test occursin("logical payload digest differs", sprint(showerror, tamper_error))
        @test bytes2hex(SHA.sha256(read(gauge_file))) == original_gauge_sha256
        completed_config = modified_wannierization_config(
            base.config;
            construction_policy = :diagnostic,
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
            max_iterations = 3,
            acceleration = W.WannierizationAccelerationConfig(
                schedule = :two_stage,
                disentanglement_max_steps = 1,
                localization_max_steps = 2,
            ),
            checkpoint_hdf5 = joinpath(dir, "completed.wannierization.h5"),
            write_wannier90_tb = true,
            tb_output_formats = (:packed_hdf5, :wannier90_tb),
        )
        completed = W.construct_symmetry_adapted_wannier_functions(completed_config)
        if completed.restart_state === nothing
            @error "Completed diagnostic chain stopped" diagnostics = completed.diagnostics
        end
        @test completed.restart_state !== nothing
        @test completed.restart_state.optimizer_state.u_steps > 0
        @test completed.input_summary["production_eligible"] == "false"
        @test completed.input_summary["wavefunction_gauge_hdf5_sha256"] == gauge.artifact_sha256
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
        @test occursin("projection centers do not map uniquely", strict_reason)
        @test basis.blocks[1].positions_fractional == input_centers
        prepared=prep(:diagnostic)
        @test prepared.status in (:PASS, :PASS_WITH_WARNINGS)
        center_failures = filter(d -> d.code == :PROJECTION_CENTER_RESIDUAL, prepared.diagnostics)
        @test !isempty(center_failures)
        @test all(
            d ->
                get(d.context, "gate_result", "") == "FAIL" &&
                get(d.context, "action", "") == "CONTINUE_DIAGNOSTIC",
            center_failures,
        )
        @test all(
            d ->
                parse(Float64, d.context["value"]) == 2.0e-7 &&
                parse(Float64, d.context["threshold"]) == 1.0e-8,
            center_failures,
        )
        @test basis.blocks[1].positions_fractional == input_centers
        representation=S.read_band_representation_hdf5(prepared.output_hdf5)
        @test representation.sewing_matrices==sewing
        cfg=modified_wannierization_config(
            f.config;
            construction_policy = :diagnostic,
            projection_basis = basis,
            num_wannier = 2,
            win_file = win,
            eig_file = eig,
            mmn_file = mmn,
            band_representation = nothing,
            band_representation_hdf5 = prepared.output_hdf5,
            compatibility_policy = :strict,
            max_iterations = 3,
            checkpoint_hdf5 = joinpath(dir, "run.wannierization.h5"),
            write_wannier90_tb = true,
            tb_output_formats = (:packed_hdf5, :wannier90_tb),
            acceleration = W.WannierizationAccelerationConfig(
                schedule = :two_stage,
                disentanglement_max_steps = 2,
                localization_max_steps = 2,
            ),
        )
        result=W.construct_symmetry_adapted_wannier_functions(cfg)
        @test result.restart_state!==nothing
        @test result.restart_state.optimizer_state.u_steps>0
        @test result.input_summary["production_eligible"]=="false"
        @test any(
            d->d.code==:PROJECTION_CENTER_RESIDUAL && get(d.context, "gate_result", "")=="FAIL",
            result.diagnostics,
        )
        @test public_diagnostic_chain_fresh_read(result, "PROJECTION_CENTER_RESIDUAL")
        @test basis.blocks[1].positions_fractional == input_centers
    end
end

@testset "Public periodic diagnostic checkpoint restarts in a fresh process" begin
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
                construction_policy = :diagnostic,
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
        disentanglement_limit_policy = :diagnostic_continue)
    config = modified_wannierization_config(f.config; construction_policy = :diagnostic,
        win_file = joinpath(directory, "model.win"), eig_file = joinpath(directory, "model.eig"),
        mmn_file = joinpath(directory, "model.mmn"), band_representation = nothing,
        band_representation_hdf5 = joinpath(directory, "representation.h5"),
        acceleration, max_iterations = 8, convergence_window = 20, parallel = :threads,
        checkpoint_hdf5 = joinpath(directory, restart ? "restart.wannierization.h5" : "full.wannierization.h5"),
        checkpoint_interval = 1, iteration_observer = observer,
        tb_output_formats = (:packed_hdf5, :wannier90_tb), write_wannier90_tb = true)
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
        full = W.construct_symmetry_adapted_wannier_functions(config)
        @test full.restart_state !== nothing
        @test isfile(periodic)
        prior = W.read_wannierization_checkpoint_hdf5(periodic)
        @test prior.status == W.IN_PROGRESS_CHECKPOINT
        @test prior.restart_state.iteration == 4
        @test prior.restart_state.optimizer_state.u_steps > 0
        @test prior.input_summary["construction_policy"] == "diagnostic"
        @test prior.input_summary["manual_review_required"] == "true"
        @test prior.input_summary["manual_review_status"] == "REQUIRED"
        @test prior.input_summary["production_eligible"] == "false"
        @test prior.input_summary["global_production_eligible"] == "false"
        @test prior.input_summary["model_qualification"] == "DIAGNOSTIC_ONLY"
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
            "target_subspace_contract_sha256",
            "disentanglement_outer_mask_sha256",
            "disentanglement_frozen_mask_sha256",
            "target_leakage_semantics",
            "target_leakage_formula_sha256",
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
        recovered = W.construct_symmetry_adapted_wannier_functions(cfg)
        @testset "Fresh public periodic checkpoint tail replay" begin
            @test recovered.restart_state !== nothing
            @test recovered.restart_state.config_sha256 == prior.restart_state.config_sha256
            @test recovered.restart_state.representation_sha256 == prior.restart_state.representation_sha256
            @test recovered.restart_state.stencil.digest == prior.restart_state.stencil.digest
            @test recovered.restart_state.optimizer_state.z_steps == full.restart_state.optimizer_state.z_steps
            @test recovered.restart_state.optimizer_state.u_steps == full.restart_state.optimizer_state.u_steps
            @test recovered.restart_state.iteration - prior.restart_state.iteration <= 4
            @test recovered.v_matrix == full.v_matrix
            @test recovered.spreads_angstrom2 == full.spreads_angstrom2
            @test recovered.status == full.status
            @test isequal(recovered.history[1:length(prior.history)], prior.history)
            @test recovered.artifacts.packed_hdf5 !== nothing
            @test recovered.artifacts.wannier90_tb !== nothing
            @test recovered.input_summary["production_eligible"] == "false"
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
        bundle.manifest.diagnostic_only && !bundle.manifest.production_eligible || error("qualification differs")
        all(isfinite, tb.hamiltonian_r) || error("nonfinite TB")
        println("PERIODIC_RESTART_DUAL_FRESH_READ_PASS")
        """
        digest = bytes2hex(SHA.sha256(reinterpret(UInt8, vec(full.v_matrix))))
        command =
            `$(Base.julia_cmd()) --startup-file=no --threads=1 --project=$(dirname(@__DIR__)) -e $(fresh_readback) $(output.checkpoint) $(output.packed) $(output.wannier90) $(digest)`
        @test occursin("PERIODIC_RESTART_DUAL_FRESH_READ_PASS", read(command, String))
    end
end
