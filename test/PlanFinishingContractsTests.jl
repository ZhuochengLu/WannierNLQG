using Test, TOML
@testset "Canonical grouped controls and four workflow examples" begin
    w=WannierNLQG.Wannierization
    controls=w.WannierizationStageControls()
    cfg=w.WannierizationSolverConfig()
    @test cfg.stage_controls==controls
    @test cfg.acceleration.disentanglement_max_steps==200
    @test cfg.acceleration.localization_max_steps==500
    for removed in (:max_iterations, :convergence_tolerance, :convergence_window, :localize)
        @test removed ∉ fieldnames(w.WannierizationSolverConfig)
        @test_throws MethodError w.WannierizationSolverConfig(; removed=>1)
    end
    @test w.WannierizationCheckpointConfig().num_dump_cycles==100
    @test w.WannierizationRuntimeConfig().num_print_cycles==1
    @test_throws MethodError w.WannierizationCheckpointConfig(checkpoint_interval = 10)
    @test_throws MethodError w.WannierizationRuntimeConfig(progress_interval = 10)
    for source in ("qe", "vasp"), route in ("ordinary", "sawf", "projection", "mesh")
        path=joinpath(spec["source"], "examples/text_input", route*"-"*source*".toml")
        doc=TOML.parsefile(path)
        @test doc["source"]["kind"]==source
        @test !haskey(doc, "wannierization") && !haskey(doc, "schema_version")
        @test !haskey(doc, "matrices")
        @test !occursin("win_file", read(path, String))
        if route in ("projection", "mesh")
            @test !haskey(doc["source"], "wavecar_file")
        else
            settings=WannierNLQG.Runtime._workflow_stage_solver(doc["solver"])
            @test settings.stage_controls.dis_num_iter==200 && settings.stage_controls.num_iter==500
        end
    end
end
