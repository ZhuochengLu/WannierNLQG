# Build public bundle configurations for spin, projector, full-geometry and Zeeman closures.
function _first_use_operator_configs(root; operator_bundle_files = nothing)
    W = @__MODULE__
    fixture = normpath(joinpath(@__DIR__, "..", "..", "examples", "fixtures", "synthetic_runtime"))
    model = W.ModelInput(
        model_file = joinpath(fixture, "synthetic_tb.dat"),
        real_space_operator_bundle_file = operator_bundle_files === nothing ?
                                          joinpath(fixture, "synthetic_operators.h5") :
                                          operator_bundle_files.ordinary,
        real_space_replica_policy = "minimum_distance",
        wsvec_file = joinpath(fixture, "synthetic_wsvec.dat"),
        mp_grid = (2, 1, 1),
        wannier_center_convention = "Convention_II",
    )
    optical = W._first_use_optical_tasks()
    physics = W.OpticalParameters(photon_energies = [2.5], fermi_energy = 0.0, temperature = 0.0)
    spin = W.TaskSpec[
        W.TaskSpec(
            id = lowercase(q),
            quantity = q,
            method = "Conventional",
            physics = physics,
            numerics = W._first_use_optical_numerics(q, "Conventional"),
            observable = W.FullTensor(),
        ) for q in ("ISC", "SSC")
    ]
    projector = [
        W.TaskSpec(
            id = "shift_Projector",
            quantity = "SC",
            method = "Projector",
            physics = physics,
            numerics = W._first_use_optical_numerics("SC", "Projector"),
            observable = W.FullTensor(),
        ),
    ]
    geometry = W._first_use_geometry_tasks()
    full_geometry = W.TaskSpec[
        W.TaskSpec(
            id = lowercase(q),
            quantity = q,
            method = "Conventional",
            physics = W.GeometryParameters(),
            observable = W.KSliceSelection(
                component = W.TensorComponent(component...),
                bands = W.Subspace([1, 2]),
            ),
        ) for (q, component) in
        (("QMK", (1, 1)), ("QMDK", (1, 1, 1)), ("QMQK", (1, 1, 1, 1)), ("QCSK", (1, 1, 1)))
    ]
    push!(
        full_geometry,
        W.TaskSpec(
            id = "connection_Projector",
            quantity = "QHCK",
            method = "Projector",
            physics = W.GeometryParameters(),
            observable = W.KSliceSelection(
                component = W.TensorComponent(1, 1, 1),
                bands = W.Transition(conduction = [3, 4], valence = [1, 2]),
            ),
        ),
    )
    zeeman = W.TaskSpec[
        W.TaskSpec(
            id = lowercase(q),
            quantity = q,
            method = "Conventional",
            physics = W.GeometryParameters(),
            numerics = W.Numerics(denominator_regularization = 0.001, degeneracy_threshold = 0.002),
            observable = W.KSliceSelection(
                component = W.TensorComponent(component...),
                bands = W.InterbandGroups(first = [3, 4], second = [1, 2]),
            ),
        ) for (q, component) in (("ZIBCK", (1, 3)), ("ZIQMK", (1, 2)))
    ]
    slice = W.KSlice(
        k_mesh = (2, 2),
        spatial_dimension = 2,
        origin = (0.137, 0.079, 0.0),
        vector_1 = (1.0, 0.0, 0.0),
        vector_2 = (0.0, 1.0, 0.0),
    )
    mesh = W.BZMesh(k_mesh = (2, 2), spatial_dimension = 2)
    optical_slice = W.KSlice(
        k_mesh = (2, 2),
        spatial_dimension = 3,
        origin = (0.137, 0.079, 0.0),
        vector_1 = (1.0, 0.0, 0.0),
        vector_2 = (0.0, 1.0, 0.0),
    )
    pauli = normpath(
        joinpath(
            @__DIR__,
            "..",
            "..",
            "test",
            "fixtures",
            "first_use_registered",
            "pauli_bundle.h5",
        ),
    )
    zeeman_model = W.ModelInput(
        model_file = joinpath(fixture, "synthetic_tb.dat"),
        real_space_operator_bundle_file = operator_bundle_files === nothing ? pauli :
                                          operator_bundle_files.zeeman,
        real_space_replica_policy = "minimum_distance",
        wsvec_file = joinpath(fixture, "synthetic_wsvec.dat"),
        mp_grid = (2, 1, 1),
        wannier_center_convention = "Convention_II",
    )
    make(name, sampling, tasks) = W._first_use_config(model, sampling, tasks, joinpath(root, name))
    # Actual same-path cold profiling found a shared ~2.4s residual for paired
    # Packed HDF5 models. The bare-TB parent workload has different source types;
    # fixed-q operator tasks do not enter the grouped row-view/cache/axis tree.
    # Keep each finite-q family independent so its source-demand closure matches
    # an ordinary single-task public run, rather than the optical bundle batch.
    paired_physics = W.FiniteQOpticalParameters(
        photon_energies = [2.5, 2.5, 2.5, 2.5],
        photon_momenta = [(0.01, 0.0, 0.0), (-0.01, 0.0, -0.0), (0.01, 0.0, 0.0), (0.0, 0.0, 0.0)],
        fermi_energy = 0.1,
        temperature = 125.0,
    )
    paired_config(quantity, method) = make(
        "paired_" * lowercase(quantity),
        W.BZMesh(k_mesh = (1, 1), spatial_dimension = 2),
        [
            W.TaskSpec(
                id = "paired_" * lowercase(quantity),
                quantity = quantity,
                method = method,
                physics = paired_physics,
                numerics = W.Numerics(broadening = 0.4, denominator_regularization = 0.001),
                observable = W.FullTensor(),
            ),
        ],
    )
    # Shared loading merges every task's operator demand. Keep the four source
    # closures separate: no optional sources, spin velocity, full uIu, and spin.
    # Otherwise a combined workload compiles different concrete sources from an
    # ordinary single-family public run. Tasks within each closure still share a
    # workload; the acceptance path registry remains independent.
    return (
        paired_injection = paired_config("PDIC", "Conventional"),
        paired_shift = paired_config("PDSC", "Geometric_Loop"),
        optical = make("optical", W.BZMesh(k_mesh = (2, 2), spatial_dimension = 3), optical),
        spin = make("spin", mesh, spin),
        projector = make("projector", mesh, projector),
        optical_slice = make(
            "optical_slice",
            optical_slice,
            W._first_use_optical_slice_tasks(optical),
        ),
        spin_slice = make("spin_slice", slice, W._first_use_optical_slice_tasks(spin)),
        projector_slice = make(
            "projector_slice",
            slice,
            W._first_use_optical_slice_tasks(projector),
        ),
        geometry = make("geometry", slice, geometry),
        full_geometry = make("full_geometry", slice, full_geometry),
        zeeman = W._first_use_config(zeeman_model, slice, zeeman, joinpath(root, "zeeman")),
    )
end
