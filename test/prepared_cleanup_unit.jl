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
        numerics = Numerics(broadening = 0.06),
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
                numerics = Numerics(),
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

# Worker-slot demand and ownership retain the original cold comprehensions.
function response_worker_reference_current_slots(workers, n, d, f, matrices, data, shift, frequency)
    [
        WannierNLQG.Responses.make_shift_current_conventional_workspace(
            n,
            0,
            d,
            f;
            matrix_elements = matrices[i],
            central_data = data[i],
            shift_current_required = shift,
            frequency_contraction_required = frequency,
        ) for i in 1:workers
    ]
end
function response_worker_reference_shift_spin_slots(workers, n, d, f, matrices, data, frequency)
    [
        WannierNLQG.Responses.make_shift_spin_current_conventional_workspace(
            n,
            0,
            d,
            f;
            matrix_elements = matrices[i],
            central_data = data[i],
            frequency_contraction_required = frequency,
        ) for i in 1:workers
    ]
end
function response_worker_owned_arrays(workspace)
    arrays=Any[]
    function visit(value)
        value===nothing && return
        if value isa AbstractArray
            push!(arrays, value)
        elseif value isa WannierNLQG.Responses._FrequencyContractionScratch ||
               value isa WannierNLQG.Responses._ConventionalGeneralizedDerivativeScratch
            for field in fieldnames(typeof(value))
                ;
                visit(getfield(value, field));
            end
        end
    end
    for field in fieldnames(typeof(workspace))
        field in (:scratch, :data) || visit(getfield(workspace, field))
    end
    arrays
end
function response_worker_workspace_checks(destination)
    R=WannierNLQG.Responses;
    T=WannierNLQG.Runtime;
    costs=Any[]
    @testset "Cold shared allocation preserves response ownership and demand" begin
        for d in (2, 3), f in (1, 2), frequency in (false, true), shift in (false, true)
            n=4;
            matrices=[R.make_shift_current_conventional_workspace(n, 0, d, f).scratch for _ in 1:2];
            data=[x.data for x in matrices]
            actual=T._make_conventional_current_worker_workspaces(
                2,
                n,
                0,
                d,
                f,
                matrices,
                data;
                shift_current_required = shift,
                frequency_contraction_required = frequency,
            )
            expected=response_worker_reference_current_slots(
                2,
                n,
                d,
                f,
                matrices,
                data,
                shift,
                frequency,
            )
            @test typeof(actual)==typeof(expected)
            @test length(actual)==length(expected)==2
            for i in 1:2
                @test actual[i].scratch===expected[i].scratch===matrices[i]
                @test actual[i].data===expected[i].data===data[i]
                @test (actual[i].response_kernel!==nothing)==shift
                @test (actual[i].frequency_contraction_scratch!==nothing)==frequency
                aa=response_worker_owned_arrays(actual[i]);
                bb=response_worker_owned_arrays(expected[i]);
                @test length(aa)==length(bb)
                for (a, b) in zip(aa, bb)
                    @test typeof(a)==typeof(b) && size(a)==size(b) && a==b
                    @test !Base.mightalias(a, b)
                end
            end
            @test all(
                !Base.mightalias(a, b) for a in response_worker_owned_arrays(actual[1]),
                b in response_worker_owned_arrays(actual[2])
            )
            ssc=T._make_conventional_shift_spin_worker_workspaces(
                2,
                n,
                0,
                d,
                f,
                matrices,
                data;
                frequency_contraction_required = frequency,
            )
            reference=response_worker_reference_shift_spin_slots(
                2,
                n,
                d,
                f,
                matrices,
                data,
                frequency,
            )
            @test typeof(ssc)==typeof(reference)
            for i in 1:2
                @test ssc[i].scratch===reference[i].scratch===matrices[i]
                @test ssc[i].data===reference[i].data===data[i]
                @test (ssc[i].frequency_pair_weights!==nothing)==frequency
                @test (ssc[i].frequency_contraction_scratch!==nothing)==frequency
                aa=response_worker_owned_arrays(ssc[i]);
                bb=response_worker_owned_arrays(reference[i]);
                @test length(aa)==length(bb)
                for (a, b) in zip(aa, bb)
                    @test typeof(a)==typeof(b) && size(a)==size(b) && a==b
                    @test !Base.mightalias(a, b)
                end
            end
            @test all(
                !Base.mightalias(a, b) for
                a in response_worker_owned_arrays(ssc[1]), b in response_worker_owned_arrays(ssc[2])
            )
        end
        for d in (2, 3), n in (16, 64), frequency in (false, true), family in (:current, :ssc)
            matrices=[R.make_shift_current_conventional_workspace(n, 0, d, 2).scratch for _ in 1:2];
            data=[x.data for x in matrices]
            before()=family===:current ?
                     response_worker_reference_current_slots(
                2,
                n,
                d,
                2,
                matrices,
                data,
                false,
                frequency,
            ) : response_worker_reference_shift_spin_slots(
                2,
                n,
                d,
                2,
                matrices,
                data,
                frequency,
            )
            after()=family===:current ?
                    T._make_conventional_current_worker_workspaces(
                2,
                n,
                0,
                d,
                2,
                matrices,
                data;
                shift_current_required = false,
                frequency_contraction_required = frequency,
            ) :
                    T._make_conventional_shift_spin_worker_workspaces(
                2,
                n,
                0,
                d,
                2,
                matrices,
                data;
                frequency_contraction_required = frequency,
            )
            before();
            after();
            GC.gc();
            b=@allocated before();
            GC.gc();
            a=@allocated after()
            @test a<=b+1024
            push!(
                costs,
                Dict(
                    "dimension"=>d,
                    "bands"=>n,
                    "workers"=>2,
                    "family"=>String(family),
                    "frequency_storage"=>frequency,
                    "original_comprehension_bytes"=>b,
                    "cold_helper_bytes"=>a,
                    "scope"=>"Direct cold construction; no end-to-end timing claim",
                ),
            )
        end
    end
    destination===nothing ||
        write(joinpath(destination, "worker_workspace_checks.json"), JSON3.write(costs))
    return costs
end

const RESPONSE_WORKER_WORKSPACE_CONSTRUCTION_CHECKS = response_worker_workspace_checks(nothing)
