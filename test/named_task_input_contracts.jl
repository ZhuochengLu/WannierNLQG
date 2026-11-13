# Included inside TaskInputUnit: use the real public text resolver and an existing
# synthetic input; no substitute numerical kernel or material data is introduced.
@testset "Named task tables are the sole text task identity" begin
    mktempdir() do directory
        document = optical_document(directory)
        template = deepcopy(document["response"]["tasks"]["shift"])
        named = Dict{String, Any}()
        for id in ("shift_2", "shift_1", "shift_10")
            named[id] = deepcopy(template)
        end
        named["shift_2"]["photon_energies_ev"] = [0.7, 0.9]
        document["response"]["tasks"] = named
        original = deepcopy(document)
        resolved = resolve_task_input(document)
        ids = ["shift_1", "shift_10", "shift_2"]
        @test document == original
        @test [task.id for task in resolved.config.tasks] == ids
        @test resolved.metadata["task_ids_in_execution_order"] == ids
        @test resolved.metadata["task_ordering_rule"] == "ASCII_ID_LEXICOGRAPHIC"
        @test resolved.config.tasks[3].physics.photon_energies == [0.7, 0.9]
        @test resolved.config.tasks[1].physics.photon_energies == [0.25, 0.5]
        @test resolved.provenance["response.tasks.shift_2.photon_energies_ev"]["source"] == "USER"
        @test resolved.effective["response"]["tasks"] isa AbstractDict
        @test all(row -> !haskey(row, "id"), values(resolved.effective["response"]["tasks"]))
        path = joinpath(directory, "effective.toml")
        open(io -> TOML.print(io, resolved.effective), path, "w")
        replay = read_task_input(path)
        @test [task.id for task in replay.config.tasks] == ids
        @test [task.physics.photon_energies for task in replay.config.tasks] == [task.physics.photon_energies for task in resolved.config.tasks]
        # A typed public TaskConfig is ordered by its vector, independently of TOML.
        typed = TaskConfig(;
            model = resolved.config.model,
            sampling = resolved.config.sampling,
            tasks = reverse(resolved.config.tasks),
            execution = resolved.config.execution,
            output = resolved.config.output,
        )
        @test [task.id for task in typed.tasks] == reverse(ids)
        for invalid in ("../shift", "bad/name", "has space", "\u975eASCII")
            bad = deepcopy(document)
            bad["response"]["tasks"][invalid] = deepcopy(template)
            @test_throws ArgumentError resolve_task_input(bad)
        end
        bad = deepcopy(document)
        bad["response"]["tasks"]["SHIFT_1"] = deepcopy(template)
        @test_throws ArgumentError resolve_task_input(bad)
        for redundant in ("shift_1", "different")
            bad = deepcopy(document)
            bad["response"]["tasks"]["shift_1"]["id"] = redundant
            @test_throws ArgumentError resolve_task_input(bad)
        end
        bad = deepcopy(document)
        bad["response"]["task_order"] = reverse(ids)
        @test_throws ArgumentError resolve_task_input(bad)
        bad = deepcopy(document)
        bad["response"]["tasks"] = [merge(deepcopy(template), Dict("id"=>"shift"))]
        @test_throws ArgumentError resolve_task_input(bad)
    end
end
