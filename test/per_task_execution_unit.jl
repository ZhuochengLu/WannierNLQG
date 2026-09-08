# Read only numerical rows; task identity and path metadata are deliberately separate.
function task_instance_payload(result)
    return Dict(
        basename(path) => [
            parse(Float64, value) for
            line in eachline(path) if !isempty(strip(line)) && !startswith(strip(line), '#') for
            value in split(line)
        ] for path in result.outputs if endswith(path, ".dat")
    )
end

# Build an isolated public run using only repository-owned synthetic inputs.
function task_instance_config(
    tasks;
    sampling = WannierNLQG.BZMesh(k_mesh = (3, 2), spatial_dimension = 2),
    backend = "direct",
)
    fixture = joinpath(@__DIR__, "..", "examples", "fixtures", "synthetic_runtime")
    return WannierNLQG.TaskConfig(
        model = WannierNLQG.ModelInput(
            model_file = joinpath(fixture, "synthetic_tb.dat"),
            real_space_operator_bundle_file = joinpath(fixture, "synthetic_operators.h5"),
            real_space_replica_policy = "minimum_distance",
            wsvec_file = joinpath(fixture, "synthetic_wsvec.dat"),
            mp_grid = (2, 1, 1),
        ),
        sampling = sampling,
        tasks = tasks,
        execution = backend == "direct" ? WannierNLQG.ExecutionOptions(fourier_backend = backend) :
                    WannierNLQG.ExecutionOptions(fourier_backend = backend, NKdiv = (1, 1)),
        output = WannierNLQG.OutputOptions(
            output_root = mktempdir(),
            system_name = "shared",
            response_output_digits = 17,
            progress_enabled = false,
        ),
    )
end

# Construct independently owned optical parameters and numerical controls.
function task_instance_sc(
    id;
    width = 0.04,
    energies = [0.3, 1.0],
    mu = 0.0,
    temperature = 0.0,
    eta = 0.001,
    window = -1,
)
    return WannierNLQG.TaskSpec(
        id = id,
        quantity = "Shift_Current",
        method = "Conventional",
        physics = WannierNLQG.OpticalParameters(
            photon_energies = energies,
            fermi_energy = mu,
            temperature = temperature,
        ),
        numerics = WannierNLQG.OpticalNumerics(
            broadening = width,
            denominator_regularization = eta,
            band_window_size = window,
        ),
        observable = WannierNLQG.FullTensor(),
    )
end

# Access counters for the current rank without treating task-local work as shared work.
function task_instance_diagonalizations(result)
    return sum(stat.diagonalizations for stat in result.sharing.worker_statistics)
end

@testset "independent task parameters and shared interpolation" begin
    for backend in ("direct", "mixed", "auto")
        a = task_instance_sc("a")
        b = task_instance_sc(
            "b";
            width = 0.08,
            energies = [0.2, 0.5, 1.2],
            mu = 0.1,
            temperature = 125.0,
        )
        single_a = WannierNLQG.run(task_instance_config([a]; backend))
        single_b = WannierNLQG.run(task_instance_config([b]; backend))
        together = WannierNLQG.run(task_instance_config([a, b]; backend))
        reversed = WannierNLQG.run(task_instance_config([b, a]; backend))
        @test together.task_ids == ["a", "b"]
        @test task_instance_payload(single_a) == task_instance_payload(together.task_results[1])
        @test task_instance_payload(single_b) == task_instance_payload(together.task_results[2])
        @test task_instance_payload(single_a) == task_instance_payload(reversed.task_results[2])
        @test task_instance_payload(single_b) == task_instance_payload(reversed.task_results[1])
        @test task_instance_diagonalizations(together) == task_instance_diagonalizations(single_a)
        @test sum(stat.spectrum_hits for stat in together.sharing.worker_statistics) > 0
        @test isfile(together.metadata_path)
        @test all(isfile(result.metadata_path) for result in together.task_results)
    end
    a = task_instance_sc("a")
    variants = [task_instance_sc("changed"; eta = 0.05), task_instance_sc("changed"; window = 2)]
    reference = WannierNLQG.run(task_instance_config([a]))
    withenv("WANNIERNLQG_MIXED_MEMORY_LIMIT_BYTES" => "1") do
        direct_only = WannierNLQG.run(task_instance_config([a, task_instance_sc("b")]))
        @test task_instance_payload(reference) == task_instance_payload(direct_only.task_results[1])
    end
    for b in variants
        standalone = WannierNLQG.run(task_instance_config([b]))
        joined = WannierNLQG.run(task_instance_config([a, b]))
        @test task_instance_payload(reference) == task_instance_payload(joined.task_results[1])
        @test task_instance_payload(standalone) == task_instance_payload(joined.task_results[2])
        @test task_instance_diagonalizations(joined) == task_instance_diagonalizations(reference)
    end
    config = task_instance_config([a])
    WannierNLQG.run(config)
    @test_throws ErrorException WannierNLQG.run(config)
    partial_config = task_instance_config([a])
    partial_dir = joinpath(partial_config.output.output_root, "a")
    mkpath(partial_dir)
    sentinel = joinpath(partial_dir, "incomplete.dat")
    write(sentinel, "preserve incomplete output\n")
    @test_throws ErrorException WannierNLQG.run(partial_config)
    @test read(sentinel, String) == "preserve incomplete output\n"

    progress_config = task_instance_config([a, task_instance_sc("b"; width = 0.07)])
    progress_output = WannierNLQG.OutputOptions(
        output_root = progress_config.output.output_root,
        progress_enabled = true,
    )
    progress_result = WannierNLQG.run(
        WannierNLQG.TaskConfig(
            model = progress_config.model,
            sampling = progress_config.sampling,
            execution = progress_config.execution,
            tasks = progress_config.tasks,
            output = progress_output,
        ),
    )
    @test isfile(progress_result.progress_out_path)
    @test isfile(progress_result.progress_jsonl_path)
    progress_report = read(progress_result.progress_out_path, String)
    @test count(==("K-LOOP"), split(progress_report, '\n')) == 1
    @test count(line -> occursin(r"^\s*\d+/\d+\s+\[", line), split(progress_report, '\n')) ==
          prod(progress_config.sampling.k_mesh)
    @test all(
        occursin(
            WannierNLQG.Runtime.metadata_display_path(
                progress_result.progress_out_path,
                result.run_dir,
            ),
            read(result.metadata_path, String),
        ) for result in progress_result.task_results
    )
    @test all(
        result.progress_out_path == progress_result.progress_out_path for
        result in progress_result.task_results
    )
    @test all(
        result.progress_jsonl_path == progress_result.progress_jsonl_path for
        result in progress_result.task_results
    )
end

@testset "mixed-rank slice task isolation" begin
    w = WannierNLQG
    sampling = w.KSlice(
        k_mesh = (2, 2),
        spatial_dimension = 2,
        origin = (0.0, 0.0, 0.0),
        vector_1 = (1.0, 0.0, 0.0),
        vector_2 = (0.0, 1.0, 0.0),
    )
    a = w.TaskSpec(
        id = "metric",
        quantity = "Quantum_Metric",
        method = "Conventional",
        physics = w.GeometryParameters(),
        observable = w.KSliceSelection(
            component = w.TensorComponent(1, 2),
            bands = w.Subspace([1, 2]),
        ),
    )
    b = w.TaskSpec(
        id = "current",
        quantity = "Shift_Current",
        method = "Conventional",
        physics = w.OpticalParameters(
            photon_energies = [0.5],
            fermi_energy = 0.0,
            temperature = 0.0,
        ),
        observable = w.KSliceSelection(
            component = w.TensorComponent(2, 2, 2),
            bands = w.Transition(conduction = [3, 4], valence = [1, 2]),
        ),
    )
    one = w.run(task_instance_config([a]; sampling))
    two = w.run(task_instance_config([b]; sampling))
    joined = w.run(task_instance_config([a, b]; sampling))
    @test task_instance_payload(one) == task_instance_payload(joined.task_results[1])
    @test task_instance_payload(two) == task_instance_payload(joined.task_results[2])
end

@testset "task-local stencils and finite momentum" begin
    w = WannierNLQG
    for method in ("Projector", "Geometric_Loop", "Wilson_Loop")
        tasks = [
            w.TaskSpec(
                id = id,
                quantity = "Shift_Current",
                method = method,
                physics = w.OpticalParameters(
                    photon_energies = [0.3, 1.0],
                    fermi_energy = 0.0,
                    temperature = 0.0,
                ),
                numerics = w.OpticalNumerics(
                    finite_difference_step = step,
                    degeneracy_threshold = step == 0.0001 ? 0.002 : 0.01,
                ),
                observable = w.FullTensor(),
            ) for (id, step) in (("short", 0.0001), ("long", 0.0002))
        ]
        first_result = w.run(task_instance_config(tasks[1:1]))
        second_result = w.run(task_instance_config(tasks[2:2]))
        joined = w.run(task_instance_config(tasks))
        @test task_instance_payload(first_result) == task_instance_payload(joined.task_results[1])
        @test task_instance_payload(second_result) == task_instance_payload(joined.task_results[2])
        @test task_instance_diagonalizations(joined) <
              task_instance_diagonalizations(first_result) +
              task_instance_diagonalizations(second_result)
    end
    for (quantity, method) in (
        ("Photon_Drag_Shift_Current", "Geometric_Loop"),
        ("Photon_Drag_Injection_Current", "Conventional"),
    )
        tasks = [
            w.TaskSpec(
                id = id,
                quantity = quantity,
                method = method,
                physics = w.FiniteQOpticalParameters(
                    photon_energies = [0.3, 1.0],
                    fermi_energy = 0.0,
                    temperature = 0.0,
                    photon_momentum = q,
                ),
                observable = w.FullTensor(),
            ) for (id, q) in (("qx", (0.01, 0.0, 0.0)), ("qy", (0.0, 0.02, 0.0)))
        ]
        first_result = w.run(task_instance_config(tasks[1:1]))
        second_result = w.run(task_instance_config(tasks[2:2]))
        joined = w.run(task_instance_config(tasks))
        @test task_instance_payload(first_result) == task_instance_payload(joined.task_results[1])
        @test task_instance_payload(second_result) == task_instance_payload(joined.task_results[2])
    end
end
