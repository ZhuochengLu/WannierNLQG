using Test, TOML, SHA

@testset "Saved native zero-step accepted state export repair" begin
    w = WannierNLQG.Wannierization
    r = WannierNLQG.Runtime
    saved = spec["saved_fixture"]
    files = sort!([joinpath(root, name) for (root, _, names) in walkdir(saved) for name in names])
    before = Dict(file => bytes2hex(sha256(read(file))) for file in files)
    old = w.read_wannierization_checkpoint_hdf5(joinpath(saved, "native.wannierization.h5"))
    doc = TOML.parsefile(joinpath(saved, "records", "effective_config.toml"))
    doc["solver"]["initialization"] = "restart"
    doc["checkpoint"] =
        Dict("restart_hdf5" => joinpath(saved, "native.wannierization.h5"), "recovery"=>"export")
    doc["output"]["checkpoint_hdf5"] = joinpath(out, "repaired.wannierization.h5")
    input = r.resolve_workflow_input(doc; base_dir = saved)
    orchestration=Base.get_extension(WannierNLQG, :WannierNLQGWannierizationExt).WorkflowOrchestration
    retry_view=orchestration._explicit_export_recovery_view
    extra=w.WannierizationDiagnostic(:IO_FAILURE, :error, "unrelated failure")
    unrelated=orchestration.updated_wannierization_result(
        old;
        diagnostics = [old.diagnostics; extra],
    )
    @test_throws ArgumentError retry_view(unrelated, input.config)
    invalid_state=deepcopy(old);
    invalid_state.v_matrix[1]=ComplexF64(NaN)
    @test_throws ArgumentError retry_view(invalid_state, input.config)
    @test input.config.input.matrix_elements.topology !== nothing
    @test input.config.input.eig_file ==
          joinpath(saved, "native.wannierization.h5.native", "native_qe_paw.eig")
    result = r.run_task_input(input; record_directory = joinpath(out, "records"))
    println("EXPORT_REPAIR_STATUS=", result.status)
    for diagnostic in result.diagnostics
        ;
        println("EXPORT_REPAIR_DIAGNOSTIC=", diagnostic);
    end
    @test result.status ∉ (w.INVALID_INPUT, w.IO_FAILURE, w.LOCALIZATION_FAILED)
    @test isequal(result.v_matrix, old.v_matrix)
    @test isequal(result.spreads_angstrom2, old.spreads_angstrom2)
    @test isequal(result.wannier_centers_cartesian, old.wannier_centers_cartesian)
    @test isempty(result.history) && isempty(old.history)
    @test !any(d->d.code == :TB_EXPORT_FAILED && d.severity == :error, result.diagnostics)
    @test any(
        d->d.code == :PREVIOUS_TB_EXPORT_FAILED && d.context["original_severity"] == "error",
        result.diagnostics,
    )
    @test get(result.input_summary, "export_recovery_status", "") == "EXPORTED"
    @test result.artifacts.packed_hdf5 !== nothing
    if result.artifacts.packed_hdf5 !== nothing
        @test isfile(result.artifacts.packed_hdf5)
        manifest =
            WannierNLQG.IO.read_real_space_operator_bundle_manifest(result.artifacts.packed_hdf5)
        @test manifest.convergence_metric === nothing
    end
    # Repeating into the same destination must fail before modifying any output.
    if result.artifacts.packed_hdf5 !== nothing
        packed_hash=bytes2hex(sha256(read(result.artifacts.packed_hdf5)))
        @test_throws ArgumentError r.run_task_input(
            input;
            record_directory = joinpath(out, "repeat_records"),
        )
        @test bytes2hex(sha256(read(result.artifacts.packed_hdf5))) == packed_hash
    end
    invalid=deepcopy(doc);
    invalid["solver"]["num_iter"]=1
    @test_throws ArgumentError r.resolve_workflow_input(invalid; base_dir = saved)
    @test all(bytes2hex(sha256(read(file))) == digest for (file, digest) in before)
    @test sort!([joinpath(root, name) for (root, _, names) in walkdir(saved) for name in names]) == files
end
