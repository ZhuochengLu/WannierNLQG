using Test
using WannierNLQG

const SharedInputRuntime = WannierNLQG.Runtime
const SHARED_INPUT_SEED =
    joinpath(@__DIR__, "..", "examples", "symmetrization", "fixture", "inputs", "synthetic")

function shared_input_task(id, quantity)
    return TaskSpec(
        id = id,
        quantity = quantity,
        method = "Conventional",
        physics = OpticalParameters(
            photon_energies = [0.1, 0.2],
            fermi_energy = 0.0,
            temperature = 0.0,
        ),
        numerics = OpticalNumerics(broadening = 0.04),
        observable = FullTensor(),
    )
end

function shared_input_config(tasks, output_root; model_file = "")
    return TaskConfig(
        model = ModelInput(
            seedname = SHARED_INPUT_SEED,
            model_file = model_file,
            real_space_replica_policy = "input",
        ),
        sampling = BZMesh(k_mesh = (2, 2), spatial_dimension = 2),
        execution = ExecutionOptions(fourier_backend = "direct"),
        output = OutputOptions(
            output_root = output_root,
            system_name = "shared_seed",
            progress_enabled = false,
        ),
        tasks = tasks,
    )
end

function shared_input_context_copy(context; kwargs...)
    fields = (; (name => getfield(context, name) for name in fieldnames(typeof(context)))...)
    return SharedInputRuntime.RunContext(values(merge(fields, (; kwargs...)))...)
end

function shared_input_numeric_payload(result)
    return [
        [line for line in eachline(path) if !isempty(strip(line)) && !startswith(strip(line), '#')]
        for path in result.outputs
    ]
end

@testset "Shared Legacy input contracts are task-order independent" begin
    mktempdir() do directory
        charge = shared_input_task("charge", "SC")
        injection = shared_input_task("injection_spin", "ISC")
        shift = shared_input_task("shift_spin", "SSC")
        cfg = shared_input_config([charge, injection, shift], joinpath(directory, "contexts"))
        effective = SharedInputRuntime.compile_task_configs(cfg)
        @test all(item.model_file == normpath(SHARED_INPUT_SEED * "_tb.dat") for item in effective)
        contexts = [
            SharedInputRuntime.prepare_run_context(item, SharedInputRuntime.validate_config(item)) for item in effective
        ]
        @test contexts[1].seed_inputs === nothing
        @test contexts[2].seed_inputs !== nothing
        @test contexts[3].seed_inputs !== nothing
        merged = SharedInputRuntime.context_with_demand(
            contexts,
            SharedInputRuntime.combined_operator_demand(contexts),
        )
        reversed = reverse(contexts)
        reverse_merged = SharedInputRuntime.context_with_demand(
            reversed,
            SharedInputRuntime.combined_operator_demand(reversed),
        )
        @test merged.seed_inputs !== nothing
        @test merged.seed_inputs.seed_prefix == reverse_merged.seed_inputs.seed_prefix
        @test merged.model_sha256 == reverse_merged.model_sha256
        @test merged.operator_demand.required_operators ==
              reverse_merged.operator_demand.required_operators
        @test merged.operator_demand.required_components ==
              reverse_merged.operator_demand.required_components
        mismatched = shared_input_context_copy(contexts[2]; model_sha256 = repeat("0", 64))
        @test_throws ArgumentError SharedInputRuntime.context_with_demand(
            [contexts[1], mismatched],
            merged.operator_demand,
        )
        other_seed = SharedInputRuntime.SeedInputPaths(
            "other",
            contexts[2].model_file,
            "other.spn",
            "other.chk",
            "other.eig",
            "other.mmn",
        )
        conflicting = shared_input_context_copy(contexts[2]; seed_inputs = other_seed)
        @test_throws ArgumentError SharedInputRuntime.context_with_demand(
            [contexts[2], conflicting],
            merged.operator_demand,
        )
        explicit = SharedInputRuntime.compile_task_configs(
            shared_input_config(
                [charge],
                joinpath(directory, "explicit");
                model_file = contexts[1].model_file,
            ),
        )
        @test only(explicit).model_file == contexts[1].model_file
    end
end

@testset "Legacy charge and spin tasks equal independent execution" begin
    # This one-orbital fixture checks input acquisition and task isolation. Its zero
    # optical payload is not a nonzero-response or material-physics qualification.
    mktempdir() do directory
        charge = shared_input_task("charge", "SC")
        injection = shared_input_task("injection_spin", "ISC")
        shift = shared_input_task("shift_spin", "SSC")
        tasks = [charge, injection, shift]
        independent = Dict(
            task.id => WannierNLQG.run(
                shared_input_config([task], joinpath(directory, "single_" * task.id)),
            ) for task in tasks
        )
        for spin in (injection, shift)
            pair = [charge, spin]
            forward = WannierNLQG.run(
                shared_input_config(pair, joinpath(directory, spin.id * "_forward")),
            )
            backward = WannierNLQG.run(
                shared_input_config(reverse(pair), joinpath(directory, spin.id * "_backward")),
            )
            @test forward.sharing.model_loads == 1
            @test backward.sharing.model_loads == 1
            for result in (forward, backward),
                (id, task_result) in zip(result.task_ids, result.task_results)

                @test shared_input_numeric_payload(task_result) ==
                      shared_input_numeric_payload(only(independent[id].task_results))
                @test all(isfile, task_result.outputs)
            end
        end
    end
end
