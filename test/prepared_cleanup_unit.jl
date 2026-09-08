using Test
using WannierNLQG

# Build a small public task bundle that registers both Mixed providers and timing records.
function cleanup_probe_config(output_root; family = :kslice, invalid_second = false)
    fixture =
        joinpath(@__DIR__, "..", "examples", "fixtures", "synthetic_runtime", "synthetic_tb.dat")
    optical = TaskSpec(
        id = "optical",
        quantity = family == :integral ? "SC" : "SCK",
        method = "Conventional",
        physics = OpticalParameters(photon_energies = [1.0], fermi_energy = 0.0, temperature = 0.0),
        numerics = OpticalNumerics(broadening = 0.06),
        observable = family == :integral ? FullTensor() :
                     KSliceSelection(
            component = TensorComponent(2, 2, 2),
            bands = Transition(conduction = [3, 4], valence = [1, 2]),
        ),
    )
    tasks = [optical]
    if invalid_second
        push!(
            tasks,
            TaskSpec(
                id = "invalid_metric",
                quantity = "QMK",
                method = "Conventional",
                physics = GeometryParameters(),
                numerics = GeometryNumerics(),
                observable = KSliceSelection(
                    component = TensorComponent(1, 2),
                    bands = Subspace([99]),
                ),
            ),
        )
    end
    sampling =
        family == :integral ? BZMesh(k_mesh = (2, 2), spatial_dimension = 2) :
        KSlice(
            k_mesh = (2, 2),
            spatial_dimension = 2,
            origin = (0.0, 0.0, 0.0),
            vector_1 = (1.0, 0.0, 0.0),
            vector_2 = (0.0, 1.0, 0.0),
        )
    return TaskConfig(
        model = ModelInput(model_file = fixture, real_space_replica_policy = "input"),
        sampling = sampling,
        tasks = tasks,
        execution = ExecutionOptions(fourier_backend = "mixed", NKdiv = (1, 1), NKFFT = (2, 2)),
        output = OutputOptions(
            output_root = output_root,
            system_name = "cleanup_probe",
            progress_enabled = false,
        ),
    )
end

# Snapshot the two registries under their shared synchronization lock.
function cleanup_registry_counts()
    matrix_elements = WannierNLQG.MatrixElements
    return lock(matrix_elements._MIXED_PROVIDER_LOCK) do
        (
            providers = length(matrix_elements._MIXED_PROVIDERS),
            timings = length(matrix_elements._FOURIER_TIMINGS),
        )
    end
end

# Exercise each private driver through its real effective configuration and context.
function prepare_cleanup_probe(config; prepare_only = true, memory_limit = 1024^3)
    runtime = WannierNLQG.Runtime
    effective = only(runtime.compile_task_configs(config))
    specs = runtime.validate_config(effective)
    context = runtime.prepare_run_context(effective, specs)
    plan = runtime.make_bundle_plan(effective, specs)
    prepared = if plan isa runtime.IntegralBundlePlan
        runtime._run_integral_bundle_fused!(
            effective,
            context,
            specs,
            plan.controls;
            prepare_only = prepare_only,
            mixed_memory_limit_bytes = memory_limit,
        )
    else
        runtime._run_kslice_bundle_fused!(
            effective,
            context,
            specs;
            prepare_only = prepare_only,
            mixed_memory_limit_bytes = memory_limit,
        )
    end
    return prepared, context
end

@testset "Prepared response resources close on setup and finish failures" begin
    withenv("WANNIERNLQG_FOURIER_TIMING" => "1") do
        baseline = cleanup_registry_counts()
        mktempdir() do directory
            # The first public task completes setup before the second discovers invalid bands.
            bad = cleanup_probe_config(joinpath(directory, "public_invalid"); invalid_second = true)
            @test_throws Exception WannierNLQG.run(bad)
            @test cleanup_registry_counts() == baseline

            for family in (:integral, :kslice)
                # A rejected Mixed memory budget occurs after timing registration.
                bad_budget = cleanup_probe_config(joinpath(directory, "budget_$(family)"); family)
                @test_throws Exception prepare_cleanup_probe(bad_budget; memory_limit = 1)
                @test cleanup_registry_counts() == baseline

                configuration =
                    cleanup_probe_config(joinpath(directory, "prepared_$(family)"); family)
                prepared, context = prepare_cleanup_probe(configuration)
                registered = cleanup_registry_counts()
                @test registered.providers == baseline.providers + Threads.nthreads()
                @test registered.timings == baseline.timings + Threads.nthreads()
                prepared.cleanup!()
                prepared.cleanup!()
                @test cleanup_registry_counts() == baseline

                # Make the real numeric output path a directory, forcing the writer to fail.
                failed_write = cleanup_probe_config(joinpath(directory, "writer_$(family)"); family)
                prepared, context = prepare_cleanup_probe(failed_write)
                suffix = family == :integral ? "sc_conv.dat" : "sck_r_conv.dat"
                mkpath(joinpath(context.run_dir, "cleanup_probe_" * suffix))
                @test_throws Exception prepared.finish!()
                prepared.cleanup!()
                @test cleanup_registry_counts() == baseline

                # The private effective execution path also cleans up without a public dispatcher.
                private_run = cleanup_probe_config(joinpath(directory, "private_$(family)"); family)
                runtime = WannierNLQG.Runtime
                effective = only(runtime.compile_task_configs(private_run))
                context = runtime.prepare_run_context(effective, runtime.validate_config(effective))
                mkpath(joinpath(context.run_dir, "cleanup_probe_" * suffix))
                @test_throws Exception prepare_cleanup_probe(private_run; prepare_only = false)
                @test cleanup_registry_counts() == baseline
            end
        end
        @test cleanup_registry_counts() == baseline
    end
end
