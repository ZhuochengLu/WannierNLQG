const DOCUMENTED_EXAMPLE_ROOT = joinpath(ROOT, "examples", "tasks")

function load_documented_example(path::AbstractString, index::Int)
    example_module = Module(Symbol("SelfContainedDocumentedExample", index))
    Core.eval(example_module, :(include(path::AbstractString) = Base.include(@__MODULE__, path)))
    Base.include(example_module, path)
    isdefined(example_module, :build_config) || error("$(path) does not define build_config")
    return example_module
end

@testset "documented examples are self-contained" begin
    files = String[]
    for (root, _, names) in walkdir(DOCUMENTED_EXAMPLE_ROOT)
        append!(files, joinpath.(root, filter(name -> endswith(name, ".jl"), names)))
    end
    sort!(files)
    @test length(files) == 38
    for (index, path) in enumerate(files)
        example_module = load_documented_example(path, index)
        build_config = Base.invokelatest(getfield, example_module, :build_config)
        config = if occursin("/band/", path)
            Base.invokelatest(
                build_config;
                output_root = mktempdir(),
                kpoints_per_segment = [3, 3, 3, 3],
                progress_enabled = false,
            )
        else
            Base.invokelatest(
                build_config;
                k_mesh = (2, 2),
                output_root = mktempdir(),
                progress_enabled = false,
            )
        end
        @test config.output.system_name == "synthetic_demo"
        @test isfile(config.model.model_file)
        @test startswith(config.output.output_root, tempdir())
        if !occursin("/band/", path)
            @test isfile(config.model.real_space_operator_bundle_file)
            @test config.model.real_space_replica_policy == "minimum_distance"
            @test isfile(config.model.wsvec_file)
            @test config.model.mp_grid == (2, 1, 1)
        end
    end
end

@testset "independent-parameter bundle example" begin
    path = joinpath(ROOT, "examples", "bundles", "shift_current_broadenings.jl")
    example_module = load_documented_example(path, 9000)
    config = Base.invokelatest(
        getfield(example_module, :build_config);
        k_mesh = (2, 2),
        output_root = mktempdir(),
        progress_enabled = false,
    )
    effective = WannierNLQG.Runtime.compile_task_configs(config)
    @test getproperty.(config.tasks, :id) == ["sc_narrow", "sc_wide"]
    @test getproperty.(effective, :broadening) == [0.04, 0.08]
    @test all(task -> task.physics.temperature == 0.0, config.tasks)
    @test all(item -> item.k_mesh == (2, 2), effective)
end
