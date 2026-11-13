# Workload builders use the supported public configuration API. The independent
# path registry specifies acceptance coverage; it is not a list of workloads.
_first_use_fixture(family, name) =
    normpath(joinpath(@__DIR__, "..", "..", "examples", "fixtures", family, name))

# Reject MPI initialization requests during the serial package workload.
function _first_use_require_serial()
    @assert !MPI.Initialized()
    Runtime.mpi_launcher_requested() &&
        error("Representative package precompilation requires a serial launcher environment")
    Runtime.mpi_env_truthy(
        "WANNIERNLQG_USE_MPI",
        "WANNIERNLQG_CONVENTIONAL_USE_MPI",
        "WANNIERNLQG_CONVENTIONAL_GEOMETRY_USE_MPI",
        "WANNIERNLQG_INJECTION_CURRENT_USE_MPI",
        "WANNIERNLQG_PROJECTOR_USE_MPI",
        "WANNIERNLQG_GEOMETRIC_LOOP_USE_MPI",
    ) && error("Representative package precompilation requires MPI requests to be disabled")
    return nothing
end

# Use the public configuration constructor with temporary output and quiet progress.
function _first_use_config(model, sampling, tasks, destination; backend = "direct")
    return TaskConfig(
        model = model,
        sampling = sampling,
        tasks = tasks,
        execution = ExecutionOptions(fourier_backend = backend),
        output = OutputOptions(
            output_root = destination,
            system_name = "precompile_micro",
            progress_enabled = false,
            response_output_digits = 17,
        ),
    )
end

# Explicit ordinary controls have different public Numerics NamedTuple types
# from omitted defaults. Actual cold inference found their configuration merges
# outside the old tiny workload. Cover these input shapes through the same public
# calculations, without adding internal signatures or one workload per path.
function _first_use_optical_numerics(quantity, method; broadening_type = "Lorentzian")
    common = (
        broadening = 0.4,
        broadening_type = broadening_type,
        transition_window_factor = 5.0,
        denominator_regularization = 0.001,
    )
    controls = if method != "Conventional" || quantity in ("PDIC", "PDSC")
        merge(common, (degeneracy_threshold = 0.002, band_window_size = -1))
    else
        merge(common, (band_window_size = -1,))
    end
    if method != "Conventional"
        controls = merge(controls, (finite_difference_step = 0.0001,))
    end
    return Numerics(; controls...)
end

# Group small optical computations with distinct response and finite-q call trees.
function _first_use_optical_tasks()
    optical = OpticalParameters(photon_energies = [2.5], fermi_energy = 0.0, temperature = 0.0)
    tasks = TaskSpec[
        TaskSpec(
            id = "shift_$(method)",
            quantity = "SC",
            method = method,
            physics = optical,
            numerics = _first_use_optical_numerics("SC", method),
            observable = FullTensor(),
        ) for method in ("Conventional", "Geometric_Loop", "Wilson_Loop")
    ]
    push!(
        tasks,
        TaskSpec(
            id = "injection",
            quantity = "IC",
            method = "Conventional",
            physics = optical,
            numerics = _first_use_optical_numerics("IC", "Conventional"),
            observable = FullTensor(),
        ),
    )
    finite_q = FiniteQOpticalParameters(
        photon_energies = [2.5],
        fermi_energy = 0.0,
        temperature = 0.0,
        photon_momentum = (0.01, 0.0, 0.0),
    )
    for (quantity, method) in (("PDIC", "Conventional"), ("PDSC", "Geometric_Loop"))
        push!(
            tasks,
            TaskSpec(
                id = lowercase(quantity),
                quantity = quantity,
                method = method,
                physics = finite_q,
                numerics = _first_use_optical_numerics(quantity, method),
                observable = FullTensor(),
            ),
        )
    end
    for (quantity, physics) in (
        ("SHG", SHGParameters(photon_energies = [2.5], fermi_energy = 0.0, temperature = 0.0)),
        ("JC", JerkParameters(photon_energies = [2.5], fermi_energy = 0.0, temperature = 0.0)),
        ("THG", THGParameters(photon_energies = [2.5], fermi_energy = 0.0, temperature = 0.0)),
    )
        push!(
            tasks,
            TaskSpec(
                id = lowercase(quantity),
                quantity = quantity,
                method = "Conventional",
                physics = physics,
                observable = FullTensor(),
            ),
        )
    end
    return tasks
end

# Exercise spectral drivers at finite temperature with conventional/projector types.
function _first_use_spectral_tasks(; slice = false)
    relaxation = SeparateRelaxation(gamma_intra_ev = 0.04, gamma_inter_ev = 0.05)
    tasks = TaskSpec[]
    for method in ("Conventional", "Projector")
        for (quantity, physics) in (
            (
                "LT",
                LinearTransportParameters(
                    fermi_energies = [0.13],
                    temperature = 300.0,
                    relaxation = relaxation,
                ),
            ),
            (
                "LOR",
                LinearOpticalResponseParameters(
                    photon_energies = [0.2],
                    fermi_energy = 0.13,
                    temperature = 300.0,
                    relaxation = relaxation,
                ),
            ),
            (
                "OM",
                OrbitalMagnetizationParameters(
                    fermi_energies = [0.13],
                    temperature = 300.0,
                    input_semantics = :defined_finite_model,
                ),
            ),
        )
            push!(
                tasks,
                TaskSpec(
                    id = "$(quantity)_$(method)",
                    quantity = slice ? quantity * "K" : quantity,
                    method = method,
                    physics = physics,
                    observable = slice ?
                                 KSliceSelection(
                        component = quantity == "OM" ? TensorComponent(3) : TensorComponent(1, 2),
                        bands = AllBands(),
                    ) : FullTensor(),
                ),
            )
        end
    end
    return tasks
end

# Reuse optical tasks through real slice selectors and their extra output rank.
function _first_use_optical_slice_tasks(tasks)
    return TaskSpec[
        TaskSpec(
            id = task.id,
            quantity = task.quantity * "K",
            method = task.method,
            physics = task.physics,
            numerics = task.numerics,
            observable = KSliceSelection(
                component = task.quantity in ("ISC", "SSC", "JC", "THG") ?
                            TensorComponent(2, 2, 2, 2) : TensorComponent(2, 2, 2),
                bands = task.quantity in ("SHG", "JC", "THG") ? AllBands() :
                        Transition(conduction = [3, 4], valence = [1, 2]),
            ),
        ) for task in tasks
    ]
end

# Cover geometric kernels and selector ranks using a single tiny slice model.
function _first_use_geometry_tasks()
    tasks = TaskSpec[]
    for method in ("Conventional", "Wilson_Loop")
        push!(
            tasks,
            TaskSpec(
                id = "connection_$(method)",
                quantity = "QHCK",
                method = method,
                physics = GeometryParameters(),
                observable = KSliceSelection(
                    component = TensorComponent(1, 1, 1),
                    bands = Transition(conduction = [3, 4], valence = [1, 2]),
                ),
            ),
        )
    end
    # Distinct selector and output ranks; related quantities share these drivers.
    for (quantity, component, bands) in (
        ("HCTK", (2, 2, 1, 2), InterbandGroups(first = [3, 4], second = [1, 2])),
        ("IBCK", (1, 2), InterbandGroups(first = [3, 4], second = [1, 2])),
        ("BCK", (1, 2), Subspace([1, 2])),
        ("BCDK", (1, 2, 1), Subspace([1, 2])),
        ("BCQK", (1, 2, 1, 1), Subspace([1, 2])),
        ("IQMK", (1, 1), InterbandGroups(first = [3, 4], second = [1, 2])),
        ("TPPK", (1, 1, 1), TripleGroups(first = [3], second = [4], third = [1, 2])),
    )
        push!(
            tasks,
            TaskSpec(
                id = lowercase(quantity),
                quantity = quantity,
                method = "Conventional",
                physics = GeometryParameters(),
                numerics = Numerics(denominator_regularization = 0.001),
                observable = KSliceSelection(
                    component = TensorComponent(component...),
                    bands = bands,
                ),
            ),
        )
    end
    # Cold residuals enter different geometric/Wilson shift-vector kernels.
    # They share the existing no-optional-source closure and slice driver.
    for method in ("Geometric_Loop", "Wilson_Loop")
        push!(
            tasks,
            TaskSpec(
                id = "shift_vector_$(method)",
                quantity = "SVK",
                method = method,
                physics = GeometryParameters(),
                numerics = Numerics(
                    denominator_regularization = 0.001,
                    degeneracy_threshold = 0.002,
                    finite_difference_step = 0.0001,
                ),
                observable = KSliceSelection(
                    component = TensorComponent(2, 2, 2),
                    bands = Transition(conduction = [3, 4], valence = [1, 2]),
                ),
            ),
        )
    end
    return tasks
end

# Share tiny fixtures across public task families while keeping source closures distinct.
function _first_use_public_configs(root)
    model = ModelInput(model_file = _first_use_fixture("synthetic_runtime", "synthetic_tb.dat"))
    closed = ModelInput(model_file = _first_use_fixture("spectral_response", "closed_tb.dat"))
    optical = _first_use_config(
        model,
        BZMesh(k_mesh = (2, 2), spatial_dimension = 3),
        _first_use_optical_tasks(),
        joinpath(root, "optical"),
    )
    spectral = _first_use_config(
        closed,
        BZMesh(k_mesh = (2, 2, 2), spatial_dimension = 3),
        _first_use_spectral_tasks(),
        joinpath(root, "spectral"),
    )
    geometry = _first_use_config(
        model,
        KSlice(
            k_mesh = (2, 2),
            spatial_dimension = 2,
            origin = (0.137, 0.079, 0.0),
            vector_1 = (1.0, 0.0, 0.0),
            vector_2 = (0.0, 1.0, 0.0),
        ),
        _first_use_geometry_tasks(),
        joinpath(root, "geometry"),
    )
    band = _first_use_config(
        ModelInput(
            model_file = model.model_file,
            real_space_replica_policy = "auto",
            wsvec_file = _first_use_fixture("synthetic_runtime", "synthetic_wsvec.dat"),
            mp_grid = (2, 1, 1),
            wannier_center_convention = "Convention_II",
        ),
        KPath(
            nodes = [("A", (0.0, 0.0, 0.0)), ("B", (0.23, 0.0, 0.0))],
            kpoints_per_segment = [2],
            spatial_dimension = 2,
        ),
        [TaskSpec(id = "band", quantity = "Band", physics = BandParameters(fermi_energy = 0.0))],
        joinpath(root, "band"),
    )
    spectral_slice = _first_use_config(
        closed,
        KSlice(
            k_mesh = (2, 2),
            spatial_dimension = 3,
            origin = (0.0, 0.0, 0.0),
            vector_1 = (1.0, 0.0, 0.0),
            vector_2 = (0.0, 1.0, 0.0),
        ),
        _first_use_spectral_tasks(; slice = true),
        joinpath(root, "spectral_slice"),
    )
    return (; optical, spectral, geometry, band, spectral_slice)
end

# Data from the independent clean-cache study selects one Mixed slice call tree:
# it adds FFT plans, block scheduling and slice output types absent from Direct.
function _first_use_mixed_slice(root)
    model = ModelInput(model_file = _first_use_fixture("synthetic_runtime", "synthetic_tb.dat"))
    return TaskConfig(;
        model,
        sampling = KSlice(
            k_mesh = (2, 2),
            spatial_dimension = 2,
            origin = (0.125, 0.25, 0.0),
            vector_1 = (1.0, 0.0, 0.0),
            vector_2 = (0.0, 1.0, 0.0),
        ),
        execution = ExecutionOptions(fourier_backend = "mixed", NKdiv = (1, 1), NKFFT = (2, 2)),
        tasks = [
            TaskSpec(
                id = "slice",
                quantity = "SCK",
                method = "Conventional",
                physics = OpticalParameters(
                    photon_energies = [40.0],
                    fermi_energy = 0.0,
                    temperature = 0.0,
                ),
                numerics = Numerics(broadening = 10.0, denominator_regularization = 0.001),
                observable = KSliceSelection(
                    component = TensorComponent(1, 1, 1),
                    bands = Transition(conduction = [3, 4], valence = [1, 2]),
                ),
            ),
        ],
        output = OutputOptions(
            output_root = joinpath(root, "mixed_slice"),
            progress_enabled = false,
            response_output_digits = 17,
        ),
    )
end

# One text-driven real calculation captures parsing, validation, provenance and
# effective-input replay through the same supported API used by the CLI.
function _first_use_text_input(root)
    model_file = _first_use_fixture("synthetic_runtime", "synthetic_tb.dat")
    output = joinpath(root, "text_response")
    path = joinpath(root, "response.toml")
    write(
        path,
        """[model]
source = "wannier"
model_file = $(repr(model_file))
[response]
fermi_energy_ev = 0.0
temperature_k = 0.0
photon_energies_ev = [0.0, 1e-9]
[response.sampling]
kind = "bz_mesh"
k_mesh = [1, 1, 1]
spatial_dimension = 3
[response.execution]
fourier_backend = "direct"
[response.tasks.jerk]
kind = "jerk_current"
[response.tasks.jerk.numerics]
broadening = 0.04
denominator_regularization = 0.001
[output]
output_root = $(repr(output))
progress_enabled = false
response_output_digits = 17
""",
    )
    return path
end

include("RepresentativeOperatorConfigs.jl")

# One zipped public text workload captures row views, bounded endpoint reuse and
# the axis writer/reader for both existing finite-q response families.
function _first_use_paired_photon_input(root)
    path = joinpath(root, "paired_photons.toml")
    write(
        path,
        """[model]
source = "wannier"
model_file = $(repr(_first_use_fixture("synthetic_runtime", "synthetic_tb.dat")))
[response]
fermi_energy_ev = 0.1
temperature_k = 125.0
photon_energies_ev = [2.5, 2.5, 2.5, 2.5]
photon_momenta_A_inverse = [[0.01, 0.0, 0.0], [-0.01, 0.0, -0.0], [0.01, 0.0, 0.0], [0.0, 0.0, 0.0]]
[response.sampling]
kind = "bz_mesh"
k_mesh = [1, 1, 1]
spatial_dimension = 3
[response.execution]
fourier_backend = "direct"
[response.tasks.paired_injection]
kind = "photon_drag_injection_current"
[response.tasks.paired_injection.numerics]
broadening = 0.4
denominator_regularization = 0.001
[response.tasks.paired_shift]
kind = "photon_drag_shift_current"
method = "geometric_loop"
[response.tasks.paired_shift.numerics]
broadening = 0.4
denominator_regularization = 0.001
[output]
output_root = $(repr(joinpath(root, "paired_response")))
progress_enabled = false
response_output_digits = 17
""",
    )
    return path
end

@setup_workload let
    _first_use_require_serial()
    root = mktempdir()
    try
        (; optical, spectral, geometry, band, spectral_slice) = _first_use_public_configs(root)
        operator_configs = _first_use_operator_configs(root)
        mixed_slice = _first_use_mixed_slice(root)
        text_input = _first_use_text_input(root)
        paired_input = _first_use_paired_photon_input(root)
        @compile_workload begin
            # Configuration normalization runs before lazy backend activation.
            # Capture the public String-backed bundle configurations in this
            # owning module's original world; real computations remain below
            # and in the OperatorBundle extension's public workloads.
            for cfg in operator_configs
                for effective in Runtime.compile_task_configs(cfg)
                    Runtime.validate_config(effective)
                end
            end
            # Shared public orchestration plus genuinely different response drivers.
            run(optical)
            run(spectral)
            # Slice selectors/complex outputs and spectrum-only KPath execution.
            run(geometry)
            run(band)
            # Slice spectral outputs have an extra sampling rank, absent from
            # the integral driver and its output methods.
            run(spectral_slice)
            run(mixed_slice)
            run_task_input(
                read_task_input(text_input);
                record_directory = joinpath(root, "text_records"),
            )
            paired_result = run_task_input(
                read_task_input(paired_input);
                record_directory = joinpath(root, "paired_records"),
            )
            axis_paths =
                filter(path -> endswith(path, ".photon_momentum_path.toml"), paired_result.outputs)
            @assert length(axis_paths) == 2
            for path in axis_paths
                @assert length(IO.read_photon_momentum_path_record(path)["rows"]) == 4
            end
            @assert !MPI.Initialized()
            @assert Runtime.ACTIVE_PROGRESS[] === nothing
        end
    finally
        rm(root; recursive = true, force = true)
    end
end
