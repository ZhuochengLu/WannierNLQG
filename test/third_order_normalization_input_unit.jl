module ThirdOrderNormalizationInputUnit
using Test, WannierNLQG, LinearAlgebra
const R = WannierNLQG.Runtime

# A real old-format input exercises shared and local cold validation, without integration.
function document(quantity)
    return Dict{String, Any}(
        "model" => Dict(
            "source" => "wannier",
            "model_file" =>
                joinpath(@__DIR__, "../examples/fixtures/synthetic_runtime/synthetic_tb.dat"),
        ),
        "response" => Dict{String, Any}(
            "photon_energies_ev" => [0.73],
            "fermi_energy_ev" => 0.0,
            "temperature_k" => 300.0,
            "sampling" =>
                Dict("kind" => "bz_mesh", "k_mesh" => [2, 2, 2], "spatial_dimension" => 3),
            "execution" => Dict("fourier_backend" => "direct"),
            "tasks" => Dict{String, Any}("third" => Dict{String, Any}("kind" => quantity)),
        ),
        "output" => Dict("output_root" => mktempdir(), "progress_enabled" => false),
    )
end

# Require an actionable rejection rather than a silently dropped conversion selector.
function rejected(f, key)
    error = try
        f()
        nothing
    catch caught
        caught
    end
    @test error isa ArgumentError
    message = sprint(showerror, error)
    @test occursin(key, message)
    @test occursin("postprocessing", message)
end

@testset "Removed JC/THG conversion fields reject at every public input boundary" begin
    base = (photon_energies = [0.73], fermi_energy = 0.0, temperature = 300.0)
    for (quantity, constructor) in (("JC", JerkParameters), ("THG", THGParameters))
        input = document(quantity)
        resolved = resolve_task_input(input)
        @test isempty(resolved.pending)
        actual, expected = only(resolved.config.tasks).physics, constructor(; base...)
        @test all(
            name -> getfield(actual, name) == getfield(expected, name),
            fieldnames(constructor),
        )
        for (key, value) in (
            ("response_measure", "bulk"),
            ("response_measure", "sheet"),
            ("response_measure", "effective_bulk"),
            ("sheet_axes", [1, 2]),
            ("effective_thickness_angstrom", 2.0),
        )
            @test Symbol(key) ∉ fieldnames(constructor)
            rejected(() -> constructor(; base..., Symbol(key) => value), key)
            for local_input in (false, true)
                bad = deepcopy(input)
                target = local_input ? bad["response"]["tasks"]["third"] : bad["response"]
                target[key] = value
                rejected(() -> resolve_task_input(bad), key)
            end
        end
        folder = mktempdir()
        write_task_input_resolution(resolved, folder)
        replay = read_task_input(joinpath(folder, "effective_config.toml"))
        @test only(replay.summaries).physics == only(resolved.summaries).physics
        @test !occursin("response_measure", read(joinpath(folder, "effective_config.toml"), String))
        @test !occursin("sheet_axes", read(joinpath(folder, "effective_config.toml"), String))
        @test !occursin(
            "effective_thickness_angstrom",
            read(joinpath(folder, "effective_config.toml"), String),
        )
    end
end

@testset "Periodic third-order factors retain reference volume and domain fraction" begin
    lattice = [3.0 0.2 0.1; 0.0 3.4 0.2; 0.0 0.0 4.1]
    h = reshape(ComplexF64[-1.0 0.1; 0.1 1.0], 2, 2, 1)
    input = RealSpaceTBInput(
        lattice = lattice,
        r_vectors = zeros(Int, 3, 1),
        hamiltonian_r = h,
        orbital_positions = zeros(3, 2),
    )
    model = input.model
    for (quantity, constructor) in (("JC", JerkParameters), ("THG", THGParameters))
        physics = constructor(photon_energies = [0.73], fermi_energy = 0.0, temperature = 300.0)
        configurations = [
            TaskConfig(
                model = input,
                sampling = sampling,
                tasks = [
                    TaskSpec(
                        id = "third",
                        quantity = sampling isa KSlice ? quantity * "K" : quantity,
                        physics = physics,
                    ),
                ],
                execution = ExecutionOptions(fourier_backend = "direct"),
                output = OutputOptions(output_root = mktempdir(), progress_enabled = false),
            ) for sampling in (
                BZMesh(k_mesh = (2, 2, 2), spatial_dimension = 3),
                KSlice(
                    k_mesh = (2, 2),
                    spatial_dimension = 3,
                    origin = (0.0, 0.0, 0.0),
                    vector_1 = (1.0, 0.0, 0.0),
                    vector_2 = (0.0, 1.0, 0.0),
                ),
                KRegion(lower = (0.1, 0.2, 0.3), upper = (0.2, 0.4, 0.6), k_mesh = (2, 2, 2)),
            )
        ]
        # A slice needs its existing one-component observation; the physical factor is independent of it.
        for index in (2,)
            cfg = configurations[index]
            task = only(cfg.tasks)
            configurations[index] = TaskConfig(
                model = cfg.model,
                sampling = cfg.sampling,
                tasks = [
                    TaskSpec(
                        id = task.id,
                        quantity = task.quantity,
                        physics = physics,
                        observable = KSliceSelection(
                            component = TensorComponent(1, 1, 1, 1),
                            bands = BandSelection(),
                        ),
                    ),
                ],
                execution = cfg.execution,
                output = cfg.output,
            )
        end
        effective = [R.compile_native_task_config(cfg, only(cfg.tasks)) for cfg in configurations]
        jerk = quantity == "JC"
        factors = [R.third_order_si_factors(model, jerk, cfg) for cfg in effective]
        @test factors[1] == factors[2] == R.third_order_si_factors(model, jerk)
        fraction = 0.1 * 0.2 * 0.3 / abs(det(WannierNLQG.Core.reciprocal_lattice(lattice)))
        @test collect(factors[3]) ≈ collect(factors[1]) .* fraction rtol = 2e-15 atol = 0
    end
end
end
