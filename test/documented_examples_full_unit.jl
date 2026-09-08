const FULL_EXAMPLE_ROOT = joinpath(ROOT, "examples", "tasks")

@testset "all documented task examples execute" begin
    files = String[]
    for (root, _, names) in walkdir(FULL_EXAMPLE_ROOT)
        append!(files, joinpath.(root, filter(name -> endswith(name, ".jl"), names)))
    end
    sort!(files)
    @test length(files) == 38
    mktempdir() do directory
        for (index, path) in enumerate(files)
            @testset "$(basename(path))" begin
                example_module = load_documented_example(path, 1000 + index)
                output_root = joinpath(directory, string(index))
                config = if occursin("/band/", path)
                    Base.invokelatest(
                        getfield(example_module, :build_config);
                        output_root,
                        kpoints_per_segment = [3, 3, 3, 3],
                        progress_enabled = false,
                    )
                else
                    Base.invokelatest(
                        getfield(example_module, :build_config);
                        k_mesh = (2, 2),
                        output_root,
                        progress_enabled = false,
                    )
                end
                result = WannierNLQG.run(config)
                @test all(isfile, result.outputs)
                @test isfile(result.metadata_path)
            end
        end
    end
end

@testset "documented independent-parameter bundle executes" begin
    path = joinpath(ROOT, "examples", "bundles", "shift_current_broadenings.jl")
    example_module = load_documented_example(path, 9001)
    mktempdir() do directory
        config = Base.invokelatest(
            getfield(example_module, :build_config);
            k_mesh = (2, 2),
            output_root = directory,
            progress_enabled = false,
        )
        result = WannierNLQG.run(config)
        @test result.task_ids == ["sc_narrow", "sc_wide"]
        @test length(result.task_results) == 2
        @test all(isfile, result.outputs)
        @test isfile(result.metadata_path)
        @test all(isdir(joinpath(directory, id)) for id in result.task_ids)
    end
end
