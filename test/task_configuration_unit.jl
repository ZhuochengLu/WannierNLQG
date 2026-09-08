using Test
using WannierNLQG

const TaskConfigurationRuntime = WannierNLQG.Runtime

function independent_test_config(
    tasks;
    sampling = BZMesh(k_mesh = (2, 2)),
    output_root = "/tmp/task_configuration_preflight",
)
    return TaskConfig(
        model = ModelInput(
            model_file = joinpath(
                @__DIR__,
                "..",
                "examples",
                "fixtures",
                "synthetic_runtime",
                "synthetic_tb.dat",
            ),
        ),
        sampling = sampling,
        execution = ExecutionOptions(fourier_backend = "direct"),
        output = OutputOptions(output_root = output_root, progress_enabled = false),
        tasks = tasks,
    )
end

function independent_optical_task(
    id;
    energies = [0.25],
    broadening = 0.06,
    fermi_energy = 0.0,
    temperature = 0.0,
)
    return TaskSpec(
        id = id,
        quantity = "SC",
        method = "Conventional",
        physics = OpticalParameters(
            photon_energies = energies,
            fermi_energy = fermi_energy,
            temperature = temperature,
        ),
        numerics = OpticalNumerics(broadening = broadening),
    )
end

@testset "Public task configuration is layered and explicit" begin
    @test_throws ArgumentError TaskConfig(
        tasks = [("SC", "Conventional", "Integral")],
        fourier_backend = "direct",
    )
    @test_throws UndefKeywordError ExecutionOptions()
    @test_throws UndefKeywordError OpticalParameters(photon_energies = [0.1], fermi_energy = 0.0)
    @test_throws UndefKeywordError TaskSpec(id = "sc", quantity = "SC")
    @test_throws ArgumentError TaskSpec(
        id = "../escape",
        quantity = "SC",
        physics = OpticalParameters(photon_energies = [0.1], fermi_energy = 0, temperature = 0),
    )
    @test_throws ArgumentError independent_test_config([
        independent_optical_task("A"),
        independent_optical_task("a"),
    ])
    @test_throws ArgumentError OpticalNumerics(photon_energies = [0.1])
    @test_throws ArgumentError GeometryNumerics(broadening = 0.1)
    @test :TaskConfig in names(WannierNLQG)
    @test :EffectiveTaskConfig ∉ names(WannierNLQG)
    @test :NormalizedTaskSpec ∉ names(WannierNLQG)
end

@testset "Independent effective configs and task identifiers" begin
    energies = [0.1, 0.3]
    a = independent_optical_task("narrow"; energies = energies)
    b = independent_optical_task("wide"; energies = [0.2], broadening = 0.12, temperature = 150.0)
    cfg = independent_test_config([a, b])
    energies[1] = 5.0
    effective = TaskConfigurationRuntime.compile_task_configs(cfg)
    @test length(effective) == 2
    @test effective[1].photon_energies == [0.1, 0.3]
    @test effective[2].photon_energies == [0.2]
    @test effective[1].broadening == 0.06
    @test effective[2].broadening == 0.12
    @test effective[1].temperature == 0.0
    @test effective[2].temperature == 150.0
    @test basename(effective[1].output_root) == "narrow"
    @test basename(effective[2].output_root) == "wide"
    @test effective[1].tasks == effective[2].tasks
    effective[1].photon_energies[1] = 9.0
    @test cfg.tasks[1].physics.photon_energies == [0.1, 0.3]
    @test length(TaskConfigurationRuntime.validate_config(cfg)) == 2
end

@testset "Explicit band targets and occupied sums" begin
    sampling = KSlice(
        k_mesh = (2, 2),
        spatial_dimension = 2,
        origin = (0, 0, 0),
        vector_1 = (1, 0, 0),
        vector_2 = (0, 1, 0),
    )
    make_geometry(bands, physics = GeometryParameters(); quantity = "BCK", component = (1, 2)) =
        TaskSpec(
            id = "geometry",
            quantity = quantity,
            physics = physics,
            observable = KSliceSelection(component = TensorComponent(component...), bands = bands),
        )
    compile_geometry(task) = only(
        TaskConfigurationRuntime.compile_task_configs(
            independent_test_config([task]; sampling = sampling),
        ),
    )
    one = compile_geometry(make_geometry(Subspace([1])))
    @test one.band_selection == ([1],)
    @test !one.include_occupied_sum
    @test isempty(one.photon_energies)
    individual = compile_geometry(make_geometry(BandTargets([1, 2])))
    @test individual.band_selection == (1, 2)
    @test !individual.include_occupied_sum
    occupied = compile_geometry(
        make_geometry(OccupiedBands(), GeometryParameters(fermi_energy = 0, temperature = 0)),
    )
    @test occupied.band_selection == 0
    @test occupied.include_occupied_sum
    combined = compile_geometry(
        make_geometry(
            BandTargets([1, 2]; include_occupied_sum = true),
            GeometryParameters(fermi_energy = 0, temperature = 0),
        ),
    )
    @test combined.include_occupied_sum
    @test_throws ArgumentError compile_geometry(make_geometry(OccupiedBands()))
    @test_throws ArgumentError compile_geometry(
        make_geometry(Subspace([1, 2]), GeometryParameters(fermi_energy = 0, temperature = 0)),
    )
    @test_throws ArgumentError compile_geometry(
        make_geometry(Transition(conduction = [3], valence = [1])),
    )
    @test_throws ArgumentError Transition(conduction = [1, 2], valence = [2])
    @test_throws ArgumentError Subspaces([[1, 2], [2, 3]])
    @test_throws ArgumentError Subspace([0])
    @test_throws ArgumentError TripleGroups(first = [1], second = [2], third = [1])
    qmk = make_geometry(Subspace([1, 2]); quantity = "QMK", component = (1, 1))
    sc = TaskSpec(
        id = "sc",
        quantity = "SCK",
        method = "Conventional",
        physics = OpticalParameters(photon_energies = [0.2], fermi_energy = 0, temperature = 0),
        observable = KSliceSelection(
            component = TensorComponent(2, 2, 2),
            bands = Transition(conduction = [3, 4], valence = [1, 2]),
        ),
    )
    mixed = TaskConfigurationRuntime.compile_task_configs(
        independent_test_config([qmk, sc]; sampling = sampling),
    )
    @test length(mixed[1].tensor_indices) == 2
    @test length(mixed[2].tensor_indices) == 3
end

@testset "Physical and numerical applicability" begin
    optical = OpticalParameters(photon_energies = [0.1], fermi_energy = 0, temperature = 0)
    finite_q = FiniteQOpticalParameters(
        photon_energies = [0.1],
        fermi_energy = 0,
        temperature = 0,
        photon_momentum = (0.01, 0, 0),
    )
    compile_optical(task) =
        TaskConfigurationRuntime.compile_task_configs(independent_test_config([task]))
    @test_throws ArgumentError compile_optical(
        TaskSpec(id = "wrong", quantity = "SC", method = "Conventional", physics = finite_q),
    )
    @test_throws ArgumentError compile_optical(
        TaskSpec(id = "wrong", quantity = "PDSC", method = "Geometric_Loop", physics = optical),
    )
    @test_throws ArgumentError compile_optical(
        TaskSpec(
            id = "wrong",
            quantity = "SC",
            method = "Conventional",
            physics = optical,
            numerics = OpticalNumerics(finite_difference_step = 0.001),
        ),
    )
    @test_throws ArgumentError compile_optical(
        independent_optical_task("wrong"; temperature = -1.0),
    )
    @test_throws ArgumentError compile_optical(independent_optical_task("wrong"; energies = [NaN]))
    @test_throws ArgumentError compile_optical(independent_optical_task("wrong"; broadening = 0.0))
    pd = only(
        compile_optical(
            TaskSpec(id = "pd", quantity = "PDSC", method = "Geometric_Loop", physics = finite_q),
        ),
    )
    @test pd.photon_momentum == (0.01, 0.0, 0.0)
end

@testset "KPath sampling is independent from Band task semantics" begin
    sampling = KPath(nodes = [("G", (0, 0, 0)), ("X", (0.5, 0, 0))], kpoints_per_segment = [3])
    task = TaskSpec(
        id = "band",
        quantity = "Band_Structure",
        physics = BandParameters(fermi_energy = 0),
    )
    cfg = independent_test_config([task]; sampling = sampling)
    effective = only(TaskConfigurationRuntime.compile_task_configs(cfg))
    @test only(TaskConfigurationRuntime.normalize_task_specs(effective)).calculation == :kpath
    @test effective.kpoints_per_segment == [3]
    second = TaskSpec(
        id = "band2",
        quantity = "Band_Structure",
        physics = BandParameters(fermi_energy = 0),
    )
    configs = TaskConfigurationRuntime.compile_task_configs(
        independent_test_config([task, second]; sampling = sampling),
    )
    @test length(configs) == 2
    @test all(config -> config.kpath_nodes == sampling.nodes, configs)
    unsupported = TaskSpec(
        id = "response",
        quantity = "Shift_Current",
        physics = OpticalParameters(photon_energies = [0.2], fermi_energy = 0.0, temperature = 0.0),
    )
    @test_throws ErrorException TaskConfigurationRuntime.compile_task_configs(
        independent_test_config([unsupported]; sampling = sampling),
    )
    @test !isdefined(WannierNLQG, :BandPath)
end

@testset "Metadata summaries contain only effective public parameters" begin
    cfg = independent_test_config([independent_optical_task("sc")])
    summary = TaskConfigurationRuntime.task_parameter_summary(cfg, 1)
    @test summary.id == "sc"
    @test summary.physics.photon_energies == [0.25]
    @test summary.numerics.broadening == 0.06
    @test !haskey(summary.numerics, :finite_difference_step)
    @test !haskey(summary.numerics, :degeneracy_threshold)
    @test summary.observable.kind == "full_tensor"
    task = TaskSpec(
        id = "metric",
        quantity = "QMK",
        physics = GeometryParameters(),
        observable = KSliceSelection(component = TensorComponent(1, 1), bands = Subspace([1, 2])),
    )
    sampling = KSlice(
        k_mesh = (2, 2),
        spatial_dimension = 2,
        origin = (0, 0, 0),
        vector_1 = (1, 0, 0),
        vector_2 = (0, 1, 0),
    )
    geometry_cfg = independent_test_config([task]; sampling = sampling)
    geometry_summary = TaskConfigurationRuntime.task_parameter_summary(geometry_cfg, task)
    @test isempty(geometry_summary.physics)
    @test keys(geometry_summary.numerics) == (:denominator_regularization,)
    @test geometry_summary.observable.bands.kind == "subspace"
    @test !haskey(geometry_summary.numerics, :broadening)
    @test_throws ArgumentError TaskConfigurationRuntime.compile_task_configs(
        independent_test_config([
            TaskSpec(
                id = "bad",
                quantity = "SC",
                method = "Conventional",
                physics = OpticalParameters(
                    photon_energies = [0.1],
                    fermi_energy = 0,
                    temperature = 0,
                ),
                numerics = OpticalNumerics(degeneracy_threshold = 0.01),
            ),
        ]),
    )
    migration_error = try
        TaskConfig(tasks = [("SC", "Integral")], fourier_backend = "direct")
    catch err
        err
    end
    @test occursin("docs/MIGRATION_1.0.0.md", sprint(showerror, migration_error))
end
