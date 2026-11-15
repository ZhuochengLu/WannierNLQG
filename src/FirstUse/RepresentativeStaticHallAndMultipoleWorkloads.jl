# Capture the shared Integral and conductivity-slice branches on a closed model.
@setup_workload let
    _first_use_require_serial()
    directory = mktempdir()
    model = ModelInput(model_file = _first_use_fixture("spectral_response", "closed_tb.dat"))
    sampling = BZMesh(k_mesh = (2, 2, 2), spatial_dimension = 3)
    try
        @compile_workload begin
            for method in ("Conventional", "Projector")
                task = TaskSpec(
                    id = "integral_intrinsic_ahc_" * lowercase(method),
                    quantity = "intrinsic_ahc",
                    method = method,
                    physics = IntrinsicHallParameters(
                        fermi_energies = Float64[0.13],
                        temperature = 0.0,
                    ),
                    observable = FullTensor(),
                )
                result =
                    run(_first_use_config(model, sampling, [task], joinpath(directory, task.id)))
                @assert !isempty(result.outputs) && isfile(result.metadata_path)
            end
            for quantity in
                ("berry_curvature_dipole_conductivity", "berry_curvature_quadrupole_conductivity")
                task = TaskSpec(
                    id = quantity,
                    quantity = quantity,
                    method = "Conventional",
                    physics = BerryMultipoleParameters(
                        fermi_energies = [0.13],
                        temperature = 300.0,
                        relaxation_time_fs = 7.0,
                        integral_form = :fermi_surface,
                    ),
                    observable = FullTensor(),
                )
                result =
                    run(_first_use_config(model, sampling, [task], joinpath(directory, quantity)))
                @assert !isempty(result.outputs) && isfile(result.metadata_path)
            end
            # These slices have distinct output/selection types from Integral.
            # Reach their ordinary public entry; do not add residual signatures.
            slice_sampling = KSlice(
                k_mesh = (2, 2),
                spatial_dimension = 3,
                origin = (0.0, 0.0, 0.0),
                vector_1 = (1.0, 0.0, 0.0),
                vector_2 = (0.0, 1.0, 0.0),
            )
            for method in ("Conventional", "Projector")
                task = TaskSpec(
                    id = "kslice_intrinsic_ahc_" * lowercase(method),
                    quantity = "intrinsic_ahc",
                    method = method,
                    physics = IntrinsicHallParameters(
                        fermi_energies = Float64[0.13],
                        temperature = 0.0,
                    ),
                    observable = KSliceSelection(
                        component = TensorComponent(1, 2),
                        bands = BandSelection(),
                    ),
                )
                result = run(
                    _first_use_config(model, slice_sampling, [task], joinpath(directory, task.id)),
                )
                @assert !isempty(result.outputs) && isfile(result.metadata_path)
            end
            for quantity in
                ("berry_curvature_dipole_conductivity", "berry_curvature_quadrupole_conductivity")
                component =
                    quantity == "berry_curvature_dipole_conductivity" ? TensorComponent(1, 2, 1) :
                    TensorComponent(1, 2, 1, 1)
                task = TaskSpec(
                    id = "kslice_" * quantity,
                    quantity = quantity,
                    method = "Conventional",
                    physics = BerryMultipoleParameters(
                        fermi_energies = [0.13],
                        temperature = 300.0,
                        relaxation_time_fs = 7.0,
                        integral_form = :fermi_surface,
                    ),
                    observable = KSliceSelection(component = component, bands = BandSelection()),
                )
                result = run(
                    _first_use_config(model, slice_sampling, [task], joinpath(directory, task.id)),
                )
                @assert !isempty(result.outputs) && isfile(result.metadata_path)
            end
            @assert !MPI.Initialized()
            @assert Runtime.ACTIVE_PROGRESS[] === nothing
        end
    finally
        rm(directory; recursive = true, force = true)
    end
end
