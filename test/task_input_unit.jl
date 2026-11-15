module TaskInputUnit
using Test, LinearAlgebra, WannierNLQG
import JSON3, MPI, TOML
include(joinpath(@__DIR__, "..", "examples", "ExampleSupport.jl"))
const R = WannierNLQG.Runtime
const Files = WannierNLQG.IO

@testset "Scientific input read lifetime and adopted parsed values" begin
    mktempdir() do directory
        path = joinpath(directory, "input with spaces.toml")
        write(path, "value = [1.0, 2.0]\n")
        parsed = Files.read_task_input_file(path)
        @test parsed.document["value"] == [1.0, 2.0]
        @test parsed.identity == Files.scientific_file_identity(path)
        @test !hasproperty(parsed, :sha256)
        write(path, "value = [3.0]\n")
        @test parsed.document["value"] == [1.0, 2.0]
        @test parsed.identity != Files.scientific_file_identity(path)
        @test_throws ArgumentError Files.read_scientific_source(
            path;
            reader = file -> begin
                bytes = read(file)
                write(file, "value = [4.0, 5.0, 6.0]\n")
                bytes
            end,
        )
        @test_throws ArgumentError Files.read_scientific_source(path; reader = file -> UInt8[])
        link = joinpath(directory, "linked.toml")
        symlink(path, link)
        @test_throws ArgumentError Files.read_task_input_file(link)
        @test_throws ArgumentError Files.read_task_input_file(joinpath(directory, "missing.toml"))
    end
end

# A focused owned runner may request retained raw evidence outside the payload.
# Normal package tests keep their ordinary temporary cleanup.
function capture_text_input_evidence(label, document)
    destination = get(ENV, "WANNIERNLQG_TEXT_INPUT_EVIDENCE_DIR", "")
    isempty(destination) && return nothing
    mkpath(destination)
    open(joinpath(destination, label * ".json"), "w") do stream
        write(stream, JSON3.write(document))
    end
    return destination
end

function optical_document(directory)
    return Dict{String, Any}(
        "model" => Dict{String, Any}(
            "source" => "wannier",
            "model_file" => joinpath(
                @__DIR__,
                "..",
                "examples",
                "fixtures",
                "synthetic_runtime",
                "synthetic_tb.dat",
            ),
        ),
        "response" => Dict{String, Any}(
            "energy_zero" => "synthetic model Hamiltonian reference",
            "fermi_energy_ev" => 0.0,
            "temperature_k" => 0.0,
            "photon_energies_ev" => [0.25, 0.5],
            "sampling" =>
                Dict("kind" => "bz_mesh", "k_mesh" => [1, 1], "spatial_dimension" => 2),
            "execution" => Dict{String, Any}("fourier_backend" => "direct"),
            "tasks" => Dict{String, Any}(
                "shift" => Dict(
                    "kind" => "shift_current",
                    "method" => "Conventional",
                    "numerics" => Dict{String, Any}("broadening" => 0.06),
                ),
            ),
        ),
        "output" =>
            Dict("output_root" => directory, "progress_enabled" => false, "system_name" => "GeS"),
    )
end

function julia_configuration(document; quantity = "shift_current", id = "shift")
    response = document["response"]
    return TaskConfig(
        model = ModelInput(; model_file = document["model"]["model_file"], case_root = pwd()),
        sampling = BZMesh(; k_mesh = (1, 1), spatial_dimension = 2),
        execution = ExecutionOptions(; fourier_backend = "direct"),
        output = OutputOptions(;
            output_root = document["output"]["output_root"],
            progress_enabled = false,
        ),
        tasks = [
            TaskSpec(;
                id,
                quantity,
                method = "Conventional",
                physics = OpticalParameters(;
                    photon_energies = response["photon_energies_ev"],
                    fermi_energy = response["fermi_energy_ev"],
                    temperature = response["temperature_k"],
                ),
                numerics = Numerics(; broadening = 0.06),
            ),
        ],
    )
end

@testset "Omitted energy metadata does not block or invent a description" begin
    mktempdir() do directory
        explicit = optical_document(joinpath(directory, "results"))
        reference = resolve_task_input(explicit)
        document = deepcopy(explicit)
        delete!(document["response"], "energy_zero")
        input_file = joinpath(directory, "input.toml")
        Files.write_task_input_file(input_file, document)
        input = read_task_input(input_file)
        @test input.config isa TaskConfig
        @test isempty(input.pending)
        @test !haskey(input.provenance, "response.energy_zero")
        @test !haskey(input.effective["response"], "energy_zero")
        @test !occursin("energy_zero", explain_task_input(input; verbose = true))
        @test only(input.summaries).physics == only(reference.summaries).physics
        @test only(input.summaries).numerics == only(reference.summaries).numerics
        @test input.config.sampling == reference.config.sampling
        @test input.config.execution.fourier_backend == reference.config.execution.fourier_backend
        @test reference.effective["response"]["energy_zero"] == explicit["response"]["energy_zero"]
        @test reference.provenance["response.energy_zero"]["source"] == "USER"

        records = joinpath(directory, "records")
        write_task_input_resolution(input, records)
        for name in ("effective_config.toml", "config_resolution.toml", "config_explanation.md")
            @test !occursin("energy_zero", read(joinpath(records, name), String))
        end
        replay = read_task_input(joinpath(records, "effective_config.toml"))
        @test replay.config isa TaskConfig
        @test !haskey(replay.provenance, "response.energy_zero")
        @test only(replay.summaries).physics == only(input.summaries).physics

        inherited = Dict(
            "energy_zero" => Dict(
                "state" => "PENDING",
                "unit" => "eV reference",
                "origin" => "unused upstream label",
            ),
        )
        without_description = resolve_task_input(document; inherited)
        @test isempty(without_description.pending)
        @test !haskey(without_description.provenance, "response.energy_zero")
        @test !haskey(without_description.effective["response"], "energy_zero")

        for invalid in ("", "   ", 0.0)
            malformed = deepcopy(explicit)
            malformed["response"]["energy_zero"] = invalid
            @test_throws ArgumentError resolve_task_input(malformed)
        end
        for field in ("fermi_energy_ev", "temperature_k", "photon_energies_ev")
            missing = deepcopy(document)
            delete!(missing["response"], field)
            unresolved = resolve_task_input(missing)
            @test unresolved.config === nothing
            @test "response.tasks.shift.$field" in unresolved.pending
            @test !("response.energy_zero" in unresolved.pending)
        end
        template = joinpath(directory, "template.toml")
        write_task_input_template(template)
        @test !occursin("energy_zero", read(template, String))
        @test !("response.energy_zero" in read_task_input(template).pending)
    end
end

@testset "Text defaults preserve the current schema and registered method" begin
    mktempdir() do directory
        document = optical_document(joinpath(directory, "results"))
        delete!(document["response"]["tasks"]["shift"], "method")
        input = resolve_task_input(document)
        @test input.config isa TaskConfig
        @test !haskey(input.effective, "schema_version")
        @test !haskey(input.provenance, "schema_version")
        @test input.provenance["response.tasks.shift.method"]["source"] == "DEFAULT"
        @test only(input.summaries).method == "conventional"
        @test !haskey(input.original, "schema_version")
        malformed = deepcopy(document)
        malformed["schema_version"] = "unsupported"
        @test_throws ArgumentError resolve_task_input(malformed)
        explicit = deepcopy(document)
        explicit["response"]["tasks"]["shift"]["method"] = "Projector"
        explicit["model"]["real_space_operator_bundle_file"] =
            ExampleSupport.synthetic_operator_bundle_file()
        selected = resolve_task_input(explicit)
        @test only(selected.summaries).method == "projector"
        @test selected.provenance["response.tasks.shift.method"]["source"] == "USER"
    end
end

# Serialize the existing public examples, preserving all explicitly supplied controls.
function task_input_example_document(config)
    model = Dict{String, Any}("source" => "wannier")
    for field in fieldnames(ModelInput)
        value = getfield(config.model, field)
        value === nothing || (model[string(field)] = Files.task_input_toml_value(value))
    end
    sampling = config.sampling
    kind = sampling isa BZMesh ? "bz_mesh" : sampling isa KSlice ? "k_slice" : "k_path"
    sample = Dict{String, Any}("kind" => kind)
    if sampling isa KPath
        sample["nodes"] = Dict(
            "label"=>[node[1] for node in sampling.nodes],
            "fractional_coordinates"=>[collect(node[2]) for node in sampling.nodes],
        )
        sample["kpoints_per_segment"] = sampling.kpoints_per_segment
        sample["spatial_dimension"] = sampling.spatial_dimension
    else
        for field in fieldnames(typeof(sampling))
            sample[string(field)] = Files.task_input_toml_value(getfield(sampling, field))
        end
    end
    rows = Dict{String, Any}()
    physical_names = Dict(
        :photon_energies => "photon_energies_ev",
        :fermi_energy => "fermi_energy_ev",
        :temperature => "temperature_k",
        :fermi_energies => "fermi_energies_ev",
        :photon_momentum => "photon_momentum_A_inverse",
        :photon_momenta => "photon_momenta_A_inverse",
    )
    for task in config.tasks
        row = Dict{String, Any}("kind" => string(task.quantity))
        task.method === nothing || (row["method"] = task.method)
        for field in fieldnames(typeof(task.physics))
            field == :include_external &&
                !(R.normalize_quantity(task.quantity) in R.EXTERNAL_METRIC_QUANTITIES) &&
                continue
            value = getfield(task.physics, field)
            value === nothing && continue
            row[get(physical_names, field, string(field))] =
                value isa SeparateRelaxation ?
                Dict(
                    string(key) => getfield(value, key) for key in fieldnames(SeparateRelaxation)
                ) : Files.task_input_toml_value(value)
        end
        task.numerics === nothing ||
            (row["numerics"] = Files.task_input_toml_value(task.numerics.values))
        if task.observable isa KSliceSelection
            bands = task.observable.bands
            observation = Dict{String, Any}(
                "kind" => "kslice",
                "component" => collect(task.observable.component.indices),
                "occupied_sum" => String(bands.occupied_sum),
            )
            bands.groups === nothing || (observation["groups"] = deepcopy(bands.groups))
            row["observable"] = observation
        end
        rows[task.id] = row
    end
    return Dict{String, Any}(
        "model" => model,
        "response" => Dict{String, Any}(
            "sampling" => sample,
            "execution" => Dict("fourier_backend" => config.execution.fourier_backend),
            "tasks" => rows,
        ),
        "output" => Dict("output_root" => config.output.output_root, "progress_enabled" => false),
    )
end

@testset "All 63 registered public configurations are text reachable" begin
    root = dirname(@__DIR__)
    paths = sort!([
        joinpath(directory, name) for
        (directory, _, names) in walkdir(joinpath(root, "examples", "tasks")) for
        name in names if endswith(name, ".jl")
    ])
    @test length(paths) == 63
    mktempdir() do directory
        combinations = Set{Tuple{String, String, String}}()
        for (index, path) in enumerate(paths)
            @testset "$(basename(path))" begin
                example = Module(Symbol("TaskInputPublicExample", index))
                Core.eval(
                    example,
                    :(include(path::AbstractString) = Base.include(@__MODULE__, path)),
                )
                Base.include(example, path)
                config = if occursin("/band/", path)
                    Base.invokelatest(
                        getfield(example, :build_config);
                        output_root = joinpath(directory, string(index)),
                        kpoints_per_segment = [3, 3, 3, 3],
                        progress_enabled = false,
                    )
                else
                    spectral = any(
                        startswith(basename(path), family) for family in (
                            "linear_transport_",
                            "linear_optical_response_",
                            "orbital_magnetization_",
                            "intrinsic_ahc_",
                            "berry_curvature_dipole_conductivity_",
                            "berry_curvature_quadrupole_conductivity_",
                        )
                    )
                    mesh = spectral && occursin("/integral/", path) ? (2, 2, 2) : (2, 2)
                    Base.invokelatest(
                        getfield(example, :build_config);
                        k_mesh = mesh,
                        output_root = joinpath(directory, string(index)),
                        progress_enabled = false,
                    )
                end
                document = task_input_example_document(config)
                file = joinpath(directory, "input-$index.toml")
                Files.write_task_input_file(file, document)
                actual = read_task_input(file)
                expected = R.task_parameter_summary(config, 1)
                @test actual.config isa TaskConfig
                @test isempty(actual.pending)
                if !occursin("/band/", path)
                    @test actual.config.sampling.k_mesh == config.sampling.k_mesh
                    @test actual.config.sampling.spatial_dimension ==
                          config.sampling.spatial_dimension
                end
                for field in (:quantity, :method, :calculation, :physics, :numerics, :observable)
                    @test getfield(only(actual.summaries), field) == getfield(expected, field)
                end
                records = joinpath(directory, "resolved-$index")
                write_task_input_resolution(actual, records)
                replay = read_task_input(joinpath(records, "effective_config.toml"))
                if !occursin("/band/", path)
                    @test replay.config.sampling.k_mesh == config.sampling.k_mesh
                    @test replay.config.sampling.spatial_dimension ==
                          config.sampling.spatial_dimension
                end
                for field in (:quantity, :method, :calculation, :physics, :numerics, :observable)
                    @test getfield(only(replay.summaries), field) == getfield(expected, field)
                end
                push!(combinations, (expected.quantity, expected.method, expected.calculation))
            end
        end
        @test length(combinations) == 63
    end
end

@testset "Enhancement and strict CSV use the existing paired path" begin
    mktempdir() do directory
        document = optical_document(directory)
        row = document["response"]["tasks"]["shift"]
        row["kind"] = "photon_drag_injection_current"
        delete!(row, "method")
        row["photon_momentum_enhancement"] = 3.0
        row["photon_momentum_direction"] = [0.0, -2.0, 0.0]
        input = resolve_task_input(document; base_dir = directory)
        @test input.config.tasks[1].physics.photon_momenta ==
              [(0.0, -3 * energy/1973.269804, 0.0) for energy in [0.25, 0.5]]
        @test input.metadata["photon_momentum_sources"]["response.tasks.shift"]["mode"] ==
              "enhancement"
        file = joinpath(directory, "q.csv")
        write(file, "energy_ev,q_A_inverse\n0.25,0.001\n0.5,0.003\n")
        delete!(row, "photon_momentum_enhancement")
        row["photon_momentum_table_file"] = "q.csv"
        document["response"]["photon_energies_ev"] = [0.5, 0.375, 0.25, 0.375]
        table = resolve_task_input(document; base_dir = directory)
        @test table.config.tasks[1].physics.photon_momenta ==
              [(0.0, -q, 0.0) for q in [0.003, 0.002, 0.001, 0.002]]
        @test table.metadata["photon_momentum_sources"]["response.tasks.shift"]["file"] ==
              realpath(file)
        @test startswith(
            table.metadata["photon_momentum_sources"]["response.tasks.shift"]["identity"],
            "wanniernlqg.file-state/1:",
        )
        for bad in (
            "energy_ev,q_A_inverse\n0.5,0.1\n0.25,0.2\n",
            "energy_ev,q_A_inverse\n0.25,0.1\n0.25,0.2\n",
            "energy_ev,q_A_inverse\n0.25,NaN\n",
            "energy,q\n0.25,0.1\n",
        )
            write(file, bad)
            @test_throws ArgumentError resolve_task_input(document; base_dir = directory)
        end
        write(file, "energy_ev,q_A_inverse\n0.25,0.001\n0.5,0.003\n")
        document["response"]["photon_energies_ev"] = [0.1]
        @test_throws ArgumentError resolve_task_input(document; base_dir = directory)
        document["response"]["photon_energies_ev"] = [0.25]
        row["photon_momentum_A_inverse"] = [0.0, 0.0, 0.0]
        @test_throws ArgumentError resolve_task_input(document; base_dir = directory)
        delete!(row, "photon_momentum_A_inverse")
        delete!(row, "photon_momentum_table_file")
        for invalid in (-1.0, true, Inf, "3")
            row["photon_momentum_enhancement"] = invalid
            @test_throws ArgumentError resolve_task_input(document)
        end
        row["photon_momentum_enhancement"] = 0
        @test resolve_task_input(document).config.tasks[1].physics.photon_momenta ==
              [(0.0, -0.0, 0.0)]
        row["photon_momentum_direction"] = [0.0, 0.0, 0.0]
        @test_throws ArgumentError resolve_task_input(document)
    end
end

@testset "Adaptive and third-order components preserve typed admission" begin
    mktempdir() do directory
        document = optical_document(directory)
        document["response"]["temperature_k"] = 300.0
        document["response"]["execution"]["integration_algorithm"] = Dict{String, Any}(
            "kind" => "h_adaptive_cubature",
            "atol" => 1e-8,
            "rtol" => 1e-5,
            "max_evaluations" => 1000,
            "initial_divisions" => 1,
        )
        input = resolve_task_input(document)
        @test input.config.execution.integration_algorithm isa HAdaptiveCubature
        @test input.config.execution.integration_algorithm.max_evaluations == 1000
        for invalid in (true, 2.5, 0)
            bad = deepcopy(document)
            bad["response"]["execution"]["integration_algorithm"]["max_evaluations"] = invalid
            @test_throws ArgumentError resolve_task_input(bad)
        end
        bad = deepcopy(document)
        bad["response"]["temperature_k"] = 0.0
        @test_throws ArgumentError resolve_task_input(bad)
        document["response"]["execution"]["integration_algorithm"] = "uniform"
        row = document["response"]["tasks"]["shift"]
        document["response"]["sampling"]["k_mesh"] = [1, 1, 1]
        document["response"]["sampling"]["spatial_dimension"] = 3
        row["kind"] = "third_harmonic_generation"
        row["numerics"] = Dict{String, Any}(
            "prescription" => "distribution_broadening",
            "occupation_derivative_mode" => "shg_gaussian",
        )
        row["observable"] =
            Dict("kind" => "tensor_components", "components" => [[1, 2, 2, 1], [2, 1, 1, 2]])
        selected = resolve_task_input(document)
        @test selected.config.tasks[1].physics isa THGParameters
        @test selected.config.tasks[1].observable isa TensorComponents
        @test selected.config.tasks[1].numerics.values.prescription == :distribution_broadening
        compiled_thg=R.compile_task_config(selected.config, only(selected.config.tasks))
        @test compiled_thg.denominator_regularization==0.001
        records=joinpath(directory, "thg-current-effective")
        write_task_input_resolution(selected, records)
        replay=read_task_input(joinpath(records, "effective_config.toml"))
        @test only(replay.summaries).numerics==only(selected.summaries).numerics
        for removed in ("causal", "shg_compatible")
            obsolete=deepcopy(document)
            obsolete["response"]["tasks"]["shift"]["numerics"]["prescription"]=removed
            @test_throws ArgumentError resolve_task_input(obsolete)
        end
        for invalid in (0.0, -0.001, Inf, NaN)
            malformed=deepcopy(document)
            malformed["response"]["tasks"]["shift"]["numerics"]["intermediate_regularization"]=invalid
            @test_throws ArgumentError resolve_task_input(malformed)
        end
        row["kind"] = "shift_current"
        @test_throws ArgumentError resolve_task_input(document)
    end
end

@testset "Full geometry remains qualified and explicit malformed values remain errors" begin
    mktempdir() do directory
        document = optical_document(directory)
        delete!(document["response"], "fermi_energy_ev")
        document["response"]["tasks"]["shift"]["numerics"]["broadening"] = true
        @test_throws ArgumentError resolve_task_input(document)
        document = optical_document(directory)
        row = document["response"]["tasks"]["shift"]
        row["method"] = "Projector"
        @test_throws ArgumentError resolve_task_input(document)
        row["method"] = "Conventional"
        row["kind"] = "quantum_metric"
        delete!(row, "numerics")
        row["observable"] = Dict("kind" => "kslice", "component" => [2, 3], "groups" => [[1]])
        document["response"]["sampling"] = Dict(
            "kind" => "k_slice",
            "k_mesh" => [1, 1],
            "origin" => [0.0, 0.0, 0.0],
            "vector_1" => [1.0, 0.0, 0.0],
            "vector_2" => [0.0, 1.0, 0.0],
        )
        @test_throws ArgumentError resolve_task_input(document)
        native = AnalyticKInput(
            hamiltonian = (k, p) -> diagm([-1.0, 1.0]),
            num_orbitals = 2,
            lattice = Matrix{Float64}(I, 3, 3),
            orbital_positions = zeros(3, 2),
        )
        document["model"] = Dict("source" => "julia", "identity" => "explicit native payload")
        @test_throws ArgumentError resolve_task_input(document; model = native)
        row["kind"] = "berry_curvature"
        row["observable"]["kind"] = "kslice"
        @test_throws ArgumentError resolve_task_input(document; model = native)
        for key in ("photon_energies_ev", "fermi_energy_ev", "temperature_k")
            delete!(document["response"], key)
        end
        valid = resolve_task_input(document; model = native)
        @test valid.config.sampling.spatial_dimension == 3
        @test valid.config.tasks[1].observable.component.indices == (2, 3)
        delete!(document["response"]["execution"], "fourier_backend")
        auto = resolve_task_input(document; model = native)
        @test auto.config.execution.fourier_backend == "auto"
        for value in (1.5, true, 0)
            row["observable"]["groups"] = [[value]]
            @test_throws ArgumentError resolve_task_input(document; model = native)
        end
    end
end

@testset "Defaults reflect actual model and supported task capabilities" begin
    mktempdir() do directory
        document = optical_document(directory)
        delete!(document["output"], "system_name")
        delete!(document["response"]["execution"], "fourier_backend")
        delete!(document["response"]["sampling"], "kind")
        input = resolve_task_input(document)
        @test input.config.output.system_name == "synthetic"
        @test input.provenance["output.system_name"]["source"] == "DERIVED"
        @test input.config.execution.fourier_backend == "auto"
        @test input.provenance["response.execution.fourier_backend"]["state"] == "PENDING"
        @test input.config.sampling isa BZMesh
        @test input.provenance["response.sampling.kind"]["source"] == "DEFAULT"
        document["output"]["system_name"] = "explicit_name"
        @test resolve_task_input(document).config.output.system_name == "explicit_name"
        row = document["response"]["tasks"]["shift"]
        row["kind"] = "photon_drag_shift_current"
        delete!(row, "method")
        row["photon_momentum_enhancement"] = 1.0
        row["photon_momentum_direction"] = [0.0, 1.0, 0.0]
        paired = resolve_task_input(document)
        @test paired.config.tasks[1].method == "geometric_loop"
        @test paired.config.execution.fourier_backend == "direct"
        @test paired.provenance["response.execution.fourier_backend"]["source"] == "DERIVED"
        document["response"]["execution"]["nkdiv"] = [1, 1]
        document["response"]["execution"]["nkfft"] = [1, 1]
        @test_throws ErrorException resolve_task_input(document)
        document = optical_document(directory)
        row = document["response"]["tasks"]["shift"]
        row["kind"] = "linear_transport"
        delete!(row, "numerics")
        row["fermi_energies_ev"] = [0.0]
        row["relaxation"] = Dict("gamma_intra_ev" => 0.1, "gamma_inter_ev" => true)
        document["response"]["sampling"]["spatial_dimension"] = 3
        @test_throws ArgumentError resolve_task_input(document)
        delete!(document["response"], "temperature_k")
        @test_throws ArgumentError resolve_task_input(document)
    end
end

@testset "Real CLI check and explain use the same input boundary" begin
    cli = Module(:TaskInputCommandLineExample)
    Base.include(cli, joinpath(@__DIR__, "..", "scripts", "wanniernlqg.jl"))
    mktempdir() do directory
        document = optical_document(directory)
        file = joinpath(directory, "cli.toml")
        Files.write_task_input_file(file, document)
        log = joinpath(directory, "cli.stdout")
        code = open(log, "w") do stream
            redirect_stdout(stream) do
                Base.invokelatest(getfield(cli, :task_input_cli), ["check", file])
            end
        end
        @test code == 0
        @test occursin("CONFIG_VALIDATED", read(log, String))
        @test !MPI.Initialized()
        delete!(document["response"], "fermi_energy_ev")
        Files.write_task_input_file(file, document)
        code = open(log, "w") do stream
            redirect_stdout(stream) do
                Base.invokelatest(getfield(cli, :task_input_cli), ["check", file])
            end
        end
        @test code == 2
        @test occursin("PENDING_REQUIRED_INPUT", read(log, String))
        code = open(log, "w") do stream
            redirect_stdout(stream) do
                Base.invokelatest(getfield(cli, :task_input_cli), ["explain", file, "--verbose"])
            end
        end
        @test code == 0
        @test occursin("fermi_energy_ev", read(log, String))
        document["response"]["temperature_k"] = true
        Files.write_task_input_file(file, document)
        @test_throws ArgumentError Base.invokelatest(
            getfield(cli, :task_input_cli),
            ["check", file],
        )
        @test !MPI.Initialized()
    end
end

@testset "Shared photon path belongs only to its applicable task" begin
    mktempdir() do directory
        document = optical_document(directory)
        document["response"]["photon_momenta_A_inverse"] = [[0.0, 0.1, 0.0], [0.0, -0.1, 0.0]]
        drag = deepcopy(document["response"]["tasks"]["shift"])
        drag["kind"] = "photon_drag_injection_current"
        document["response"]["tasks"]["drag"] = drag
        input = resolve_task_input(document)
        by_id = Dict(task.id => task for task in input.config.tasks)
        @test [task.id for task in input.config.tasks] == ["drag", "shift"]
        @test by_id["shift"].physics isa OpticalParameters
        @test by_id["drag"].physics isa FiniteQOpticalParameters
        @test length(by_id["drag"].physics.photon_momenta) == 2
        delete!(document["response"]["tasks"], "drag")
        @test_throws ArgumentError resolve_task_input(document)
    end
end

@testset "TOML mapping uses the existing public configuration" begin
    mktempdir() do directory
        document = optical_document(joinpath(directory, "results"))
        input_file = joinpath(directory, "input.toml")
        Files.write_task_input_file(input_file, document)
        input = read_task_input(input_file)
        expected = julia_configuration(document)
        # Text paths intentionally use the input directory; Julia case_root keeps
        # its normal expert meaning. Compare task physics, numerics and sampling.
        summary = R.task_parameter_summary(expected, 1)
        actual = only(input.summaries)
        @test input.config isa TaskConfig
        @test actual.physics == summary.physics
        @test actual.numerics == summary.numerics
        @test actual.observable == summary.observable
        @test actual.quantity == summary.quantity
        @test actual.method == summary.method
        @test input.config.sampling == expected.sampling
        @test input.provenance["response.tasks.shift.fermi_energy_ev"]["source"] == "USER"
        @test input.provenance["response.tasks.shift.numerics.broadening"]["source"] == "USER"
        @test input.provenance["response.tasks.shift.numerics.denominator_regularization"]["source"] ==
              "DEFAULT"
        @test input.provenance["output.progress_enabled"]["source"] == "USER"
        @test occursin("Explicit shared", explain_task_input(input; verbose = true))

        records = joinpath(directory, "records")
        write_task_input_resolution(input, records)
        reread = read_task_input(joinpath(records, "effective_config.toml"))
        # An effective file spells out resolved defaults. Its reader truthfully
        # sees explicit values; the original provenance remains a separate record.
        for field in
            (:id, :quantity, :method, :calculation, :physics, :numerics, :observable, :output_root)
            @test getfield(only(reread.summaries), field) == getfield(only(input.summaries), field)
        end
        saved_resolution =
            Files.read_task_input_file(joinpath(records, "config_resolution.toml")).document
        @test saved_resolution["parameters"]["response.tasks.shift.numerics.denominator_regularization"]["source"] ==
              "DEFAULT"
        @test reread.provenance["response.tasks.shift.numerics.denominator_regularization"]["source"] ==
              "USER"
        @test reread.config.model.model_file == input.config.model.model_file

        explicit_default = deepcopy(document)
        explicit_default["response"]["tasks"]["shift"]["numerics"]["denominator_regularization"] =
            actual.numerics.denominator_regularization
        same = resolve_task_input(explicit_default)
        @test only(same.summaries).numerics == actual.numerics
        @test same.provenance["response.tasks.shift.numerics.denominator_regularization"]["source"] ==
              "USER"
    end
end

@testset "Required physical values remain pending and inherited units are checked" begin
    mktempdir() do directory
        document = optical_document(joinpath(directory, "results"))
        delete!(document["response"], "fermi_energy_ev")
        pending = resolve_task_input(document)
        @test pending.config === nothing
        @test "response.tasks.shift.fermi_energy_ev" in pending.pending
        @test !haskey(pending.provenance["response.tasks.shift.fermi_energy_ev"], "value")
        @test_throws ArgumentError run_task_input(
            pending;
            record_directory = joinpath(directory, "never-run"),
        )
        inherited = Dict(
            "fermi_energy_ev" =>
                Dict("value" => -0.1, "unit" => "eV", "origin" => "trusted fixture filling"),
        )
        inherited_input = resolve_task_input(document; inherited)
        @test only(inherited_input.summaries).physics.fermi_energy == -0.1
        @test inherited_input.provenance["response.tasks.shift.fermi_energy_ev"]["source"] ==
              "INHERITED"
        inherited["fermi_energy_ev"]["unit"] = "Ha"
        @test_throws ArgumentError resolve_task_input(document; inherited)
        template = joinpath(directory, "template.toml")
        write_task_input_template(template)
        draft = read_task_input(template)
        @test draft.metadata["status"] == "PENDING_REQUIRED_INPUT"
        write_task_input_resolution(draft, joinpath(directory, "pending-records"))
        @test !isfile(joinpath(directory, "pending-records", "effective_config.toml"))
    end
end

@testset "Strict keys, registry, dimensions and real malformed inputs" begin
    mktempdir() do directory
        original = optical_document(joinpath(directory, "results"))
        for (expected_error, mutate) in (
            (ArgumentError, d -> (d["unknown"] = true)),
            (ArgumentError, d -> (d["model"]["fake_capability"] = true)),
            (ArgumentError, d -> (d["response"]["tasks"]["shift"]["sampling"] = Dict())),
            (ArgumentError, d -> (d["response"]["execution"]["NKdiv"] = [1, 1])),
            (ErrorException, d -> (d["response"]["tasks"]["shift"]["method"] = "unsupported")),
            (ArgumentError, d -> (d["response"]["sampling"]["k_mesh"] = Any[true, 1])),
            (ArgumentError, d -> (d["response"]["temperature_k"] = NaN)),
            (
                ArgumentError,
                d -> (d["response"]["tasks"]["shift"]["numerics"]["photon_energies"] = [1.0]),
            ),
        )
            document = deepcopy(original)
            mutate(document)
            malformed_file = joinpath(directory, "malformed.toml")
            Files.write_task_input_file(malformed_file, document)
            @test_throws expected_error read_task_input(malformed_file)
        end
        missing_file = deepcopy(original)
        missing_file["model"]["model_file"] = joinpath(directory, "does-not-exist")
        @test_throws ArgumentError resolve_task_input(missing_file)
        aliases = deepcopy(original)
        aliases["response"]["execution"]["fourier_backend"] = "mixed"
        aliases["response"]["execution"]["nkdiv"] = [1, 1]
        aliases["response"]["execution"]["nkfft"] = [1, 1]
        mapped = resolve_task_input(aliases)
        @test mapped.config.execution.NKdiv == (1, 1)
        @test mapped.config.execution.NKFFT == (1, 1)
        aliases["response"]["execution"]["fourier_backend"] = "direct"
        @test_throws ErrorException resolve_task_input(aliases)
    end
end

@testset "Actual Julia and text public runs produce identical response artifacts" begin
    for family in ("shift", "injection", "berry")
        mktempdir() do directory
            document = optical_document(joinpath(directory, "julia"))
            if family == "injection"
                document["response"]["tasks"]["shift"]["kind"] = "injection_current"
                document["response"]["tasks"]["injection"] =
                    pop!(document["response"]["tasks"], "shift")
                expected =
                    julia_configuration(document; quantity = "injection_current", id = "injection")
            elseif family == "berry"
                for key in ("photon_energies_ev", "fermi_energy_ev", "temperature_k")
                    delete!(document["response"], key)
                end
                document["response"]["sampling"] = Dict(
                    "kind" => "k_slice",
                    "k_mesh" => [1, 1],
                    "spatial_dimension" => 2,
                    "origin" => [0.0, 0.0, 0.0],
                    "vector_1" => [1.0, 0.0, 0.0],
                    "vector_2" => [0.0, 1.0, 0.0],
                )
                document["response"]["tasks"] = Dict(
                    "berry" => Dict(
                        "kind" => "berry_curvature",
                        "method" => "Conventional",
                        "observable" => Dict(
                            "kind" => "kslice",
                            "component" => [1, 2],
                            "groups" => [[1]],
                        ),
                    ),
                )
                expected = TaskConfig(
                    model = ModelInput(; model_file = document["model"]["model_file"]),
                    sampling = KSlice(;
                        k_mesh = (1, 1),
                        spatial_dimension = 2,
                        origin = (0.0, 0.0, 0.0),
                        vector_1 = (1.0, 0.0, 0.0),
                        vector_2 = (0.0, 1.0, 0.0),
                    ),
                    execution = ExecutionOptions(; fourier_backend = "direct"),
                    output = OutputOptions(;
                        output_root = document["output"]["output_root"],
                        progress_enabled = false,
                    ),
                    tasks = [
                        TaskSpec(;
                            id = "berry",
                            quantity = "BCK",
                            method = "Conventional",
                            physics = GeometryParameters(),
                            observable = KSliceSelection(;
                                component = TensorComponent(1, 2),
                                bands = BandSelection(groups = [[1]]),
                            ),
                        ),
                    ],
                )
            else
                expected = julia_configuration(document)
            end
            reference = WannierNLQG.run(expected)
            document["output"]["output_root"] = joinpath(directory, "text")
            text = resolve_task_input(document)
            records = joinpath(directory, "actual-records")
            actual = run_task_input(text; record_directory = records)
            @test length(reference.outputs) == length(actual.outputs)
            for (left, right) in zip(reference.outputs, actual.outputs)
                @test read(left) == read(right) # dimensions, order, IEEE spelling and format
            end
            evidence = get(ENV, "WANNIERNLQG_TEXT_INPUT_EVIDENCE_DIR", "")
            if !isempty(evidence)
                pair_root = joinpath(evidence, "pair_" * family)
                mkpath(pair_root)
                pairs = Any[]
                for (index, (left, right)) in enumerate(zip(reference.outputs, actual.outputs))
                    lhs, rhs = "julia_$index.dat", "toml_$index.dat"
                    cp(left, joinpath(pair_root, lhs))
                    cp(right, joinpath(pair_root, rhs))
                    push!(
                        pairs,
                        Dict(
                            "julia" => "pair_" * family * "/" * lhs,
                            "toml" => "pair_" * family * "/" * rhs,
                        ),
                    )
                end
                capture_text_input_evidence(
                    "pair_" * family,
                    Dict(
                        "pairs" => pairs,
                        "source" => "actual_existing_public_run_both",
                        "quantity" => only(text.summaries).quantity,
                    ),
                )
            end
            provenance =
                Files.read_task_input_file(joinpath(records, "run_provenance.toml")).document
            @test provenance["actual"]["qualification_status"] ==
                  actual.qualification.qualification_status
            @test provenance["actual"]["warnings"] == actual.qualification.reasons
            @test provenance["actual"]["execution_eligible"] ==
                  actual.qualification.execution_eligible
            @test provenance["actual"]["output_files"][1]["identity"] ==
                  Files.scientific_file_identity(first(actual.outputs))
        end
    end
end

@testset "Native capability restrictions and finite reporting warnings are retained" begin
    mktempdir() do directory
        C = WannierNLQG.Core
        model = C.NonorthogonalLocalizedModel(
            lattice = Matrix{Float64}(I, 3, 3),
            r_vectors = zeros(Int, 3, 1),
            hamiltonian_r = reshape(ComplexF64[-1 1e-6; 0 1], 2, 2, 1),
            overlap_r = reshape(Matrix{ComplexF64}(I, 2, 2), 2, 2, 1),
            position_r = zeros(ComplexF64, 2, 2, 3, 1),
        )
        @test model.representation_diagnostics.exceeds_reporting_tolerance
        payload = C.NonorthogonalLocalizedInput(model)
        document = optical_document(joinpath(directory, "native"))
        document["model"] =
            Dict("source" => "julia", "identity" => "finite synthetic two-band entry")
        native = resolve_task_input(document; model = payload)
        @test native.metadata["native_representation"]["reporting_warning"]
        @test native.metadata["model_replay"] == "REQUIRES_JULIA_MODEL_ENTRY_NOT_FILE_REPLAYABLE"
        blocked = deepcopy(document)
        blocked["response"]["tasks"]["shift"]["method"] = "Projector"
        @test_throws ArgumentError resolve_task_input(blocked; model = payload)
        missing_position = C.NonorthogonalLocalizedModel(
            lattice = Matrix{Float64}(I, 3, 3),
            r_vectors = zeros(Int, 3, 1),
            hamiltonian_r = model.raw_hamiltonian_r,
            overlap_r = model.raw_overlap_r,
            position_r = nothing,
        )
        @test_throws ArgumentError resolve_task_input(
            document;
            model = C.NonorthogonalLocalizedInput(missing_position),
        )
        # Compare against copies captured before execution; comparing two aliases
        # of the supplied model would not detect an accidental mutation.
        raw_before = (
            hamiltonian = copy(model.raw_hamiltonian_r),
            overlap = copy(model.raw_overlap_r),
            position = copy(model.raw_position_r),
        )
        records = joinpath(directory, "native-records")
        result = run_task_input(native; record_directory = records)
        @test result.qualification.execution_eligible
        @test !isfile(joinpath(records, "effective_config.toml"))
        saved = Files.read_task_input_file(joinpath(records, "run_provenance.toml")).document
        @test saved["actual"]["model_reporting_diagnostics"]["reporting_warning"]
        @test !saved["actual"]["model_reporting_diagnostics"]["raw_file_modified"]
        @test native.config.model.model.raw_hamiltonian_r == raw_before.hamiltonian
        @test native.config.model.model.raw_overlap_r == raw_before.overlap
        @test native.config.model.model.raw_position_r == raw_before.position
        capture_text_input_evidence(
            "native_warning",
            Dict(
                "existing_ordinary_run_completed" => result.qualification.execution_eligible,
                "reporting_warning" =>
                    saved["actual"]["model_reporting_diagnostics"]["reporting_warning"],
                "raw_file_modified" =>
                    saved["actual"]["model_reporting_diagnostics"]["raw_file_modified"],
                "raw_arrays_unchanged" =>
                    native.config.model.model.raw_hamiltonian_r == raw_before.hamiltonian &&
                    native.config.model.model.raw_overlap_r == raw_before.overlap &&
                    native.config.model.model.raw_position_r == raw_before.position,
                "raw_baseline" => "independent copies captured before actual public run",
                "callback_file_replay_claimed" =>
                    isfile(joinpath(records, "effective_config.toml")),
            ),
        )
    end
end

@testset "Actual user CLI check, explain and init do not initialize MPI" begin
    include(joinpath(@__DIR__, "..", "scripts", "wanniernlqg.jl"))
    mktempdir() do directory
        before = MPI.Initialized()
        file = joinpath(directory, "request.toml")
        @test task_input_cli(["init", file]) == 0
        @test task_input_cli(["check", file]) == 2
        @test task_input_cli(["explain", file, "--verbose"]) == 0
        @test_throws ArgumentError task_input_cli(["init", file])
        @test_throws ArgumentError task_input_cli(["check", file, "--unknown"])
        @test MPI.Initialized() == before
        capture_text_input_evidence(
            "CLI",
            Dict(
                "actual_check_explain_init" => true,
                "MPI_initialized_before" => before,
                "MPI_initialized_after" => MPI.Initialized(),
            ),
        )
    end
end

@testset "Runtime Fourier records reject malformed evidence without evaluating it" begin
    mktempdir() do directory
        path = joinpath(directory, "metadata.txt")
        record =
            "[Fourier]\nrequested_backend = auto\neffective_backend = mixed\n" *
            "NKdiv = (1, 2, 1)\nNKFFT = (2, 1, 1)\nfactor_source = auto_explicit\n"
        write(path, record)
        parsed = Files._read_task_input_fourier_record(path)
        @test parsed.backend == "mixed"
        @test parsed.nkdiv == (1, 2, 1)
        @test parsed.nkfft == (2, 1, 1)
        @test parsed.identity == Files.scientific_file_identity(path)
        for invalid in (
            replace(record, "(1, 2, 1)" => "(0, 2, 1)"),
            replace(record, "(1, 2, 1)" => "(true, 2, 1)"),
            replace(record, "(1, 2, 1)" => "(999999999999999999999999, 2, 1)"),
            replace(record, "(1, 2, 1)" => "begin error(\"must not evaluate\") end"),
            replace(record, "effective_backend = mixed" => "effective_backend = auto"),
            replace(record, "NKFFT = (2, 1, 1)\n" => ""),
            record * "requested_backend = auto\n",
            record * "[Fourier]\n",
        )
            write(path, invalid)
            @test_throws ArgumentError Files._read_task_input_fourier_record(path)
        end
    end
end

@testset "Relative input paths follow the file and unresolved records preserve old files" begin
    mktempdir() do directory
        # Resolve the fixture parent once so macOS temporary-directory aliases do
        # not change the expected physical base of file-relative paths.
        request_root = joinpath(realpath(directory), "requests")
        mkpath(request_root)
        model_path = joinpath(request_root, "model_tb.dat")
        source_model = optical_document(directory)["model"]["model_file"]
        cp(source_model, model_path)
        document = optical_document("results")
        document["model"]["model_file"] = "model_tb.dat"
        file = joinpath(request_root, "input.toml")
        Files.write_task_input_file(file, document)
        input = cd(directory) do
            read_task_input(file)
        end
        @test input.config.model.model_file == model_path
        @test only(input.summaries).output_root == joinpath(request_root, "results", "shift")
        @test input.metadata["input_identity"] == Files.scientific_file_identity(file)
        @test input.metadata["input_identity_kind"] == "OBSERVED_FILE_STATE"
        @test input.metadata["provenance_schema"] == "wanniernlqg.task-input-provenance/3.0"
        @test !haskey(input.metadata, "input_sha256")
        @test occursin("<unset optional value>", explain_task_input(input; verbose = true))
        records = joinpath(directory, "records")
        write_task_input_resolution(input, records)
        saved = Dict(
            name => read(joinpath(records, name)) for
            name in ("effective_config.toml", "config_resolution.toml", "config_explanation.md")
        )
        document["response"]["execution"]["fourier_backend"] = "auto"
        Files.write_task_input_file(file, document)
        pending = read_task_input(file)
        @test pending.provenance["response.execution.fourier_backend"]["state"] == "PENDING"
        @test occursin("Pending runtime decisions:", explain_task_input(pending))
        @test_throws ArgumentError write_task_input_resolution(pending, records)
        for (name, bytes) in saved
            @test read(joinpath(records, name)) == bytes
        end
        write_task_input_resolution(pending, joinpath(directory, "fresh-records"))
        @test !isfile(joinpath(directory, "fresh-records", "effective_config.toml"))
    end
end

@testset "Completed auto public runs bind actual backend and preserve request origins" begin
    for backend in ("direct", "mixed")
        mktempdir() do directory
            document = optical_document(joinpath(directory, "text"))
            document["response"]["execution"]["fourier_backend"] = "auto"
            if backend == "mixed"
                document["response"]["execution"]["nkdiv"] = [1, 1]
                document["response"]["execution"]["nkfft"] = [1, 1]
            end
            input = resolve_task_input(document)
            records = joinpath(directory, "records")
            write_task_input_resolution(input, records)
            @test !isfile(joinpath(records, "effective_config.toml"))
            actual = run_task_input(input; record_directory = records)
            # This independent entry constructs the existing public TaskConfig;
            # both sides execute the real response and use different output paths.
            reference_config = TaskConfig(
                model = input.config.model,
                sampling = input.config.sampling,
                tasks = input.config.tasks,
                execution = ExecutionOptions(;
                    fourier_backend = backend,
                    NKdiv = backend == "mixed" ? (1, 1) : nothing,
                    NKFFT = backend == "mixed" ? (1, 1) : nothing,
                ),
                output = OutputOptions(;
                    output_root = joinpath(directory, "julia"),
                    progress_enabled = false,
                ),
            )
            reference = WannierNLQG.run(reference_config)
            @test length(actual.outputs) == length(reference.outputs)
            for (left, right) in zip(reference.outputs, actual.outputs)
                @test read(left) == read(right)
            end
            saved = Files.read_task_input_file(joinpath(records, "config_resolution.toml")).document
            parameter = saved["parameters"]["response.execution.fourier_backend"]
            @test saved["metadata"]["actual_state"] == "COMPLETED"
            @test isempty(saved["metadata"]["runtime_pending"])
            @test parameter["source"] == "DERIVED"
            @test parameter["value"] == backend
            @test parameter["overrides"]["source"] == "USER"
            @test parameter["overrides"]["value"] == "auto"
            @test parameter["overrides"]["state"] == "PENDING"
            @test input.provenance["response.execution.fourier_backend"]["state"] == "PENDING"
            runtime = saved["actual"]["runtime_execution"]
            @test runtime["status"] == "ACTUAL_RUNTIME_RESOLVED"
            @test only(runtime["tasks"])["metadata_identity"] ==
                  Files.scientific_file_identity(only(actual.task_results).metadata_path)
            effective = read_task_input(joinpath(records, "effective_config.toml"))
            @test effective.config.execution.fourier_backend == backend
            @test only(effective.summaries).physics == only(input.summaries).physics
            @test only(effective.summaries).numerics == only(input.summaries).numerics
            if backend == "mixed"
                @test effective.config.execution.NKdiv == (1, 1, 1)
                @test effective.config.execution.NKFFT == (1, 1, 1)
            else
                @test effective.config.execution.NKdiv === nothing
                @test effective.config.execution.NKFFT === nothing
            end
            evidence = get(ENV, "WANNIERNLQG_TEXT_INPUT_EVIDENCE_DIR", "")
            if !isempty(evidence)
                label = "pair_auto_" * backend
                pair_root = joinpath(evidence, label)
                mkpath(pair_root)
                pairs = Any[]
                for (index, (left, right)) in enumerate(zip(reference.outputs, actual.outputs))
                    lhs, rhs = "julia_$index.dat", "toml_$index.dat"
                    cp(left, joinpath(pair_root, lhs))
                    cp(right, joinpath(pair_root, rhs))
                    push!(pairs, Dict("julia" => label * "/" * lhs, "toml" => label * "/" * rhs))
                end
                cp(
                    only(actual.task_results).metadata_path,
                    joinpath(pair_root, "actual_metadata.txt"),
                )
                for name in
                    ("effective_config.toml", "config_resolution.toml", "run_provenance.toml")
                    cp(joinpath(records, name), joinpath(pair_root, name))
                end
                capture_text_input_evidence(
                    label,
                    Dict(
                        "pairs" => pairs,
                        "source" => "actual_existing_public_run_both",
                        "realized_backend" => backend,
                        "metadata_identity" => only(runtime["tasks"])["metadata_identity"],
                        "original_boundary_still_pending" =>
                            input.provenance["response.execution.fourier_backend"]["state"] ==
                            "PENDING",
                    ),
                )
            end
        end
    end
end

@testset "Central TOML atomic replacement preserves existing destinations on failure" begin
    mktempdir() do directory
        path = joinpath(directory, "record.toml")
        Files.write_task_input_file(path, Dict("value" => 1))
        before = read(path)
        state = Files.scientific_file_state(path)
        @test_throws Base.IOError Files.atomic_file_replace(joinpath(directory, "absent"), path)
        @test read(path) == before
        @test Files.scientific_file_state(path) == state
        Files.write_task_input_file(path, Dict("value" => 2))
        @test Files.read_task_input_file(path).document["value"] == 2
        target_directory = joinpath(directory, "existing-directory")
        mkdir(target_directory)
        sentinel = joinpath(target_directory, "keep.txt")
        write(sentinel, "owned existing directory must survive")
        @test_throws Base.IOError Files.write_task_input_file(target_directory, Dict("value" => 3))
        @test isdir(target_directory) && readdir(target_directory) == ["keep.txt"]
        @test read(sentinel, String) == "owned existing directory must survive"
        temporary = joinpath(directory, "prepared.toml")
        write(temporary, "value = 4\n")
        @test_throws Base.IOError Files.atomic_file_replace(temporary, target_directory)
        @test read(temporary, String) == "value = 4\n"
        @test read(sentinel, String) == "owned existing directory must survive"
        other = joinpath(directory, "other")
        mkdir(other)
        @test_throws ArgumentError Files.atomic_file_replace(
            temporary,
            joinpath(other, "record.toml"),
        )
        @test isfile(temporary)
    end
end

@testset "Explicit uniform region rule records and roundtrips" begin
    mktempdir() do directory
        document = optical_document(directory)
        document["response"]["sampling"] = Dict{String, Any}(
            "kind" => "k_region",
            "lower" => [-0.5, -0.5],
            "upper" => [0.5, 0.5],
            "k_mesh" => [2, 3],
            "spatial_dimension" => 2,
        )
        document["response"]["execution"]["integration_algorithm"] = "uniform"
        default = resolve_task_input(document)
        @test default.config.execution.integration_algorithm.region_quadrature == :midpoint
        @test default.effective["response"]["execution"]["integration_algorithm"] == "uniform"
        document["response"]["execution"]["integration_algorithm"] =
            Dict{String, Any}("kind" => "uniform", "region_quadrature" => "left_endpoint")
        selected = resolve_task_input(document)
        @test selected.config.execution.integration_algorithm.region_quadrature == :left_endpoint
        @test selected.provenance["response.execution.integration_algorithm.region_quadrature"]["source"] ==
              "USER"
        @test selected.effective["response"]["execution"]["integration_algorithm"]["region_quadrature"] ==
              "left_endpoint"
        path = joinpath(directory, "endpoint-effective.toml")
        open(io -> TOML.print(io, selected.effective), path, "w")
        replay = read_task_input(path)
        @test replay.config.execution.integration_algorithm.region_quadrature == :left_endpoint
        @test replay.config.sampling.lower == selected.config.sampling.lower
        for invalid in (true, 0.5, "right_endpoint", "trapezoidal")
            bad = deepcopy(document)
            bad["response"]["execution"]["integration_algorithm"]["region_quadrature"] = invalid
            @test_throws ArgumentError resolve_task_input(bad)
        end
        bad = deepcopy(document)
        bad["response"]["execution"]["integration_algorithm"]["offset"] = 0.0
        @test_throws ArgumentError resolve_task_input(bad)
        bad = deepcopy(document)
        bad["response"]["sampling"] =
            Dict{String, Any}("kind" => "bz_mesh", "k_mesh" => [2, 3], "spatial_dimension" => 2)
        @test_throws ArgumentError resolve_task_input(bad)
    end
end
include("named_task_input_contracts.jl")

end
