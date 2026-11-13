# Cover normal file-backed Mixed preparation and progress/output serialization.
# Existing serial workloads intentionally use quiet Direct paths; neither their
# cache nor an internal signature list covers this ordinary public call tree.
function _first_use_execution_config(task, model, destination)
    return TaskConfig(
        model = model,
        sampling = BZMesh(k_mesh = (2, 2, 2), spatial_dimension = 3),
        tasks = [
            TaskSpec(
                id = task.id,
                quantity = task.quantity,
                method = task.method,
                physics = task.physics,
                numerics = _first_use_optical_numerics(
                    task.quantity,
                    task.method;
                    broadening_type = "Gaussian",
                ),
                observable = task.observable,
            ),
        ],
        execution = ExecutionOptions(
            fourier_backend = "mixed",
            NKdiv = (1, 1, 1),
            NKFFT = (2, 2, 2),
        ),
        output = OutputOptions(
            output_root = destination,
            system_name = "precompile_execution",
            response_output_digits = 17,
            progress_enabled = true,
            progress_percent_interval = 100,
            progress_verbosity = "quiet",
        ),
    )
end

@setup_workload let
    _first_use_require_serial()
    root = mktempdir()
    try
        model = ModelInput(
            model_file = _first_use_fixture("synthetic_runtime", "synthetic_tb.dat"),
            wannier_center_convention = "Convention_II",
            real_space_replica_policy = "input",
        )
        packed_model = ModelInput(
            model_file = _first_use_fixture("synthetic_runtime", "synthetic_tb.dat"),
            wannier_center_convention = "Convention_II",
            real_space_replica_policy = "minimum_distance",
            wsvec_file = _first_use_fixture("synthetic_runtime", "synthetic_wsvec.dat"),
            mp_grid = (2, 1, 1),
        )
        tasks = filter(_first_use_optical_tasks()) do task
            (task.quantity == "SC" && task.method == "Conventional") ||
                task.quantity in ("PDSC", "PDIC")
        end
        @assert length(tasks) == 3
        @compile_workload begin
            # Construct inside capture: ordinary normalization is part of first use.
            # Separate calls also retain single-task output and scheduler branches.
            # The public replica transformation reaches the packed-position layout
            # also used by MPI distribution, without initializing MPI at cache build.
            for (layout, input) in (("ordinary", model), ("packed", packed_model)), task in tasks
                cfg = _first_use_execution_config(task, input, joinpath(root, layout, task.id))
                result = run(cfg)
                @assert !isempty(result.outputs)
                @assert isfile(result.metadata_path)
                @assert isfile(result.progress_jsonl_path)
            end
            @assert !MPI.Initialized()
            @assert Runtime.ACTIVE_PROGRESS[] === nothing
        end
    finally
        rm(root; recursive = true, force = true)
    end
end
