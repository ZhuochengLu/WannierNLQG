using Test, TOML, SHA
@testset "Native QE SAWF public entry" begin
    w=WannierNLQG.Wannierization;
    r=WannierNLQG.Runtime
    saved=spec["saved_fixture"]
    doc=TOML.parsefile(joinpath(saved, "records", "effective_config.toml"))
    doc["mode"]="symmetry_adapted"
    doc["source"]["include_time_reversal"]=true
    doc["symmetry"]=Dict("include_time_reversal"=>true, "symmetry_tolerance"=>1e-5)
    doc["output"]["checkpoint_hdf5"]=joinpath(out, "sawf.wannierization.h5")
    doc["output"]["native_matrix_directory"]=joinpath(out, "native-matrices")
    path=joinpath(out, "sawf.toml");
    open(io->TOML.print(io, doc), path, "w")
    input=r.read_task_input(path)
    @test input.config.input.wannierization_mode == :symmetry_adapted
    @test input.config.input.sewing_backend isa w.AugmentationAwareSewing
    @test input.config.input.source.include_time_reversal
    @test input.config.input.win_file === nothing
    result=r.run_task_input(input; record_directory = joinpath(out, "records"))
    println("NATIVE_SAWF_STATUS=", result.status)
    for d in result.diagnostics
        ;
        println("NATIVE_SAWF_DIAGNOSTIC=", d);
    end
    @test result.status ∉
          (w.INVALID_INPUT, w.IO_FAILURE, w.LOCALIZATION_FAILED, w.REPRESENTATION_INCOMPATIBLE)
    @test !isempty(result.v_matrix)
    @test get(result.input_summary, "effective_wannierization_mode", "") == "symmetry_adapted"
    @test get(result.input_summary, "representation_source", "") == "detected"
    @test get(result.input_summary, "symmetry_constraints_applied", "") == "true"
    @test isfile(input.config.checkpoint.checkpoint_hdf5)
    @test !any(d->d.severity == :error, result.diagnostics)
    @test result.artifacts.packed_hdf5 !== nothing
    if result.artifacts.packed_hdf5 !== nothing
        @test isfile(result.artifacts.packed_hdf5)
        manifest=WannierNLQG.IO.read_real_space_operator_bundle_manifest(
            result.artifacts.packed_hdf5,
        )
        @test manifest.convergence_metric === nothing
    end
    effective=joinpath(out, "records", "effective_config.toml")
    replay=r.read_task_input(effective)
    @test replay.config.input.source.include_time_reversal
    @test replay.config.input.wannierization_mode == :symmetry_adapted
    @test replay.config.input.matrix_elements.topology.source_sha256 ==
          input.config.input.matrix_elements.topology.source_sha256
end
