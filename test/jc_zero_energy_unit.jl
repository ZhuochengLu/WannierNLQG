module JCZeroEnergyUnit
using Test, WannierNLQG
import MPI, JSON3
const Files = WannierNLQG.IO
const Runtime = WannierNLQG.Runtime
const MODEL_FILE =
    joinpath(@__DIR__, "..", "examples", "fixtures", "synthetic_runtime", "synthetic_tb.dat")

function jc_config(
    directory;
    energies = [0.0, 1e-9],
    backend = "direct",
    slice = false,
    numerics = Numerics(; broadening = 0.04, denominator_regularization = 0.001),
    quantities = (:jerk_current,),
)
    tasks = [
        TaskSpec(;
            id = String(q),
            quantity = String(q),
            method = "Conventional",
            physics = q == :jerk_current ?
                      JerkParameters(;
                photon_energies = Float64.(energies),
                fermi_energy = 0.0,
                temperature = 0.0,
            ) :
                      OpticalParameters(;
                photon_energies = Float64.(energies),
                fermi_energy = 0.0,
                temperature = 0.0,
            ),
            numerics,
            observable = slice ?
                         KSliceSelection(;
                component = TensorComponent(1, 1, 1, 1),
                bands = AllBands(),
            ) : FullTensor(),
        ) for q in quantities
    ]
    return TaskConfig(;
        model = ModelInput(; model_file = MODEL_FILE),
        sampling = slice ?
                   KSlice(;
            k_mesh = (1, 1),
            spatial_dimension = 3,
            origin = (0.0, 0.0, 0.0),
            vector_1 = (1.0, 0.0, 0.0),
            vector_2 = (0.0, 1.0, 0.0),
        ) : BZMesh(; k_mesh = (1, 1, 1), spatial_dimension = 3),
        execution = ExecutionOptions(;
            fourier_backend = backend,
            NKFFT = backend == "mixed" ? (slice ? (1, 1) : (1, 1, 1)) : nothing,
        ),
        tasks,
        output = OutputOptions(; output_root = directory, progress_enabled = false),
    )
end

function jc_document(directory; slice = false)
    sampling =
        slice ?
        Dict{String, Any}(
            "kind" => "k_slice",
            "k_mesh" => [1, 1],
            "spatial_dimension" => 3,
            "origin" => [0.0, 0.0, 0.0],
            "vector_1" => [1.0, 0.0, 0.0],
            "vector_2" => [0.0, 1.0, 0.0],
        ) : Dict{String, Any}("kind" => "bz_mesh", "k_mesh" => [1, 1, 1], "spatial_dimension" => 3)
    task = Dict{String, Any}(
        "kind" => "jerk_current",
        "numerics" => Dict("broadening" => 0.04, "denominator_regularization" => 0.001),
    )
    slice && (task["observable"] = Dict("kind" => "all_bands", "component" => [1, 1, 1, 1]))
    return Dict{String, Any}(
        "model" => Dict("source" => "wannier", "model_file" => MODEL_FILE),
        "response" => Dict(
            "energy_zero" => "synthetic gapped model Hamiltonian reference",
            "fermi_energy_ev" => 0.0,
            "temperature_k" => 0.0,
            "photon_energies_ev" => slice ? [0.0] : [0.0, 1e-9],
            "sampling" => sampling,
            "execution" => Dict("fourier_backend" => "direct"),
            "tasks" => Dict("jerk_current" => task),
        ),
        "output" => Dict("output_root" => directory, "progress_enabled" => false),
    )
end

numeric_files(result) = Dict(basename(p) => p for p in result.outputs if endswith(p, ".dat"))
function table(path)
    rows = [
        parse.(Float64, split(l)) for
        l in eachline(path) if !isempty(strip(l)) && !startswith(strip(l), "#")
    ]
    return permutedims(reduce(hcat, rows))
end
function capture(label, result)
    destination = get(ENV, "WANNIERNLQG_JC_ZERO_EVIDENCE_DIR", "")
    isempty(destination) && return
    root = joinpath(destination, label);
    mkpath(root)
    for p in result.outputs
        cp(p, joinpath(root, basename(p)); force = false)
    end
    for (index, task) in enumerate(result.task_results)
        cp(task.metadata_path, joinpath(root, "metadata_$index.txt"); force = false)
    end
end

# TESTS: real public calls on a gapped finite model. Windowed zero results are
# deliberately not presented as a qualification of metallic Drude/DC transport.
const RESULTS = @testset "JC finite nonnegative public energy contract" begin
    @testset "Invalid JC energies and positive regularization remain guarded" begin
        mktempdir() do directory
            for energies in ([-1e-9], [NaN], [Inf], [-Inf], Float64[])
                @test_throws ArgumentError WannierNLQG.run(
                    jc_config(joinpath(directory, "bad"); energies),
                )
                document = jc_document(joinpath(directory, "bad-text"))
                document["response"]["photon_energies_ev"] = energies
                @test_throws ArgumentError resolve_task_input(document)
            end
            for name in (:denominator_regularization, :broadening), value in (0.0, -1e-9, NaN, Inf)

                numeric = Numerics(; name => value)
                @test_throws ArgumentError WannierNLQG.run(
                    jc_config(
                        joinpath(directory, "bad-numeric");
                        energies = [0.0],
                        numerics = numeric,
                    ),
                )
            end
        end
    end
    @testset "Zero and near-zero JC use unchanged Direct and Mixed public paths" begin
        mktempdir() do directory
            direct = WannierNLQG.run(jc_config(joinpath(directory, "direct")))
            mixed = WannierNLQG.run(jc_config(joinpath(directory, "mixed"); backend = "mixed"))
            left, right = numeric_files(direct), numeric_files(mixed)
            @test Set(keys(left)) == Set(keys(right))
            @test !isempty(left)
            for name in keys(left)
                a, b = table(left[name]), table(right[name])
                @test size(a, 1) == 2
                @test a[:, 1] == [0.0, 1e-9]
                @test all(isfinite, a)
                @test all(iszero, a[:, 2:end]) # gapped model, narrow positive optical window
                @test isequal(a, b)
            end
            capture("zero-direct", direct);
            capture("zero-mixed", mixed)
            quantities = (:jerk_current, :shift_current, :injection_current)
            combined = WannierNLQG.run(
                jc_config(joinpath(directory, "multi"); energies = [0.0], quantities),
            )
            @test length(combined.task_results) == 3
            for (q, actual) in zip(quantities, combined.task_results)
                standalone = WannierNLQG.run(
                    jc_config(joinpath(directory, String(q)); energies = [0.0], quantities = (q,)),
                )
                actual_paths = filter(p -> endswith(p, ".dat"), actual.outputs)
                @test !isempty(actual_paths)
                for p in actual_paths
                    reference = only(filter(x -> basename(x) == basename(p), standalone.outputs))
                    @test isequal(table(p), table(reference))
                    @test all(isfinite, table(p))
                end
            end
            capture("zero-multi", combined)
            positive =
                WannierNLQG.run(jc_config(joinpath(directory, "positive"); energies = [0.73]))
            capture("positive", positive)
            @test all(p -> all(isfinite, table(p)), values(numeric_files(positive)))
        end
    end
    @testset "JC TOML BZ and four-index KSlice replay the same public configuration" begin
        mktempdir() do directory
            for slice in (false, true)
                label = slice ? "slice" : "bz"
                document = jc_document(joinpath(directory, label * "-text"); slice)
                input_path = joinpath(directory, label * ".toml")
                Files.write_task_input_file(input_path, document)
                input = read_task_input(input_path)
                manual = jc_config(
                    joinpath(directory, label * "-julia");
                    slice,
                    energies = slice ? [0.0] : [0.0, 1e-9],
                )
                summary = Runtime.task_parameter_summary(manual, 1)
                for field in (:physics, :numerics, :observable, :quantity, :method, :calculation)
                    @test getfield(only(input.summaries), field) == getfield(summary, field)
                end
                actual = run_task_input(
                    input;
                    record_directory = joinpath(directory, label * "-records"),
                )
                reference = WannierNLQG.run(manual)
                a, b = numeric_files(actual), numeric_files(reference)
                @test Set(keys(a)) == Set(keys(b))
                @test !isempty(a)
                for name in keys(a)
                    @test read(a[name]) == read(b[name])
                end
                replay = read_task_input(
                    joinpath(directory, label * "-records", "effective_config.toml"),
                )
                @test only(replay.summaries).physics == only(input.summaries).physics
                capture(label * "-text", actual);
                capture(label * "-julia", reference)
            end
        end
    end
end
end
