using Test, LinearAlgebra, WannierNLQG

# Parse complex output at its declared precision, without adding an optional dependency.
function third_order_numeric_table(path)
    rows=[
        parse.(Float64, split(line)) for
        line in eachline(path) if !isempty(strip(line)) && !startswith(strip(line), "#")
    ]
    return permutedims(reduce(hcat, rows))
end

@testset "Third-order file runtime and periodic slice closure" begin
    root=dirname(@__DIR__)
    file=joinpath(root, "examples/fixtures/synthetic_runtime/synthetic_tb.dat")
    mktempdir() do temporary
        for (quantity, physics) in (
            ("JC", JerkParameters(photon_energies = [0.73], fermi_energy = 0.0, temperature = 0.0)),
            (
                "THG",
                THGParameters(
                    photon_energies = [0.73],
                    fermi_energy = 0.0,
                    temperature = 300.0,
                    formulation = :both,
                ),
            ),
        )
            function calculate(
                backend,
                slice;
                origin = (0.0, 0.0, 0.0),
                vectors = ((1.0, 0.0, 0.0), (0.0, 1.0, 0.0)),
                tag = "",
                convention = "Convention_II",
            )
                sampling=slice ?
                         KSlice(
                    k_mesh = (2, 2),
                    spatial_dimension = 3,
                    origin = origin,
                    vector_1 = vectors[1],
                    vector_2 = vectors[2],
                ) : BZMesh(k_mesh = (2, 2, 1), spatial_dimension = 3)
                observation=slice ?
                            KSliceSelection(
                    component = TensorComponent(1, 1, 2, 1),
                    bands = BandSelection(),
                ) : TensorComponents(TensorComponent(1, 1, 2, 1))
                cfg=TaskConfig(
                    model = ModelInput(model_file = file, wannier_center_convention = convention),
                    sampling = sampling,
                    tasks = [
                        TaskSpec(
                            id = "third",
                            quantity = slice ? quantity*"K" : quantity,
                            physics = physics,
                            observable = observation,
                        ),
                    ],
                    execution = ExecutionOptions(
                        fourier_backend = backend,
                        NKFFT = backend=="mixed" ? (slice ? (2, 2) : (2, 2, 1)) : nothing,
                    ),
                    output = OutputOptions(
                        output_root = joinpath(temporary, quantity*backend*string(slice)*tag),
                    ),
                )
                return WannierNLQG.run(cfg)
            end
            direct=calculate("direct", false)
            mixed=calculate("mixed", false)
            slice=calculate("direct", true)
            slicemixed=calculate("mixed", true)
            paths=filter(path->endswith(path, ".dat")&&!occursin("residual", path), direct.outputs)
            @test length(paths)==(quantity=="JC" ? 1 : 4)
            for path in paths
                name=basename(path)
                mp=only(filter(p->basename(p)==name, mixed.outputs))
                sp=only(filter(p->basename(p)==name, slice.outputs))
                smp=only(filter(p->basename(p)==name, slicemixed.outputs))
                value=third_order_numeric_table(path)
                mv=third_order_numeric_table(mp)
                sv=third_order_numeric_table(sp)
                smv=third_order_numeric_table(smp)
                @test isapprox(value, mv; atol = 0, rtol = 2e-12)
                @test isapprox(sv, smv; atol = 0, rtol = 2e-12)
                @test isapprox(
                    value[1, 2:end],
                    vec(sum(sv[:, 5:end]; dims = 1))/size(sv, 1);
                    atol = 0,
                    rtol = 2e-12,
                )
                if quantity=="THG"
                    @test isapprox(value[1, 2], sum(value[1, 4:2:end]); atol = 0, rtol = 2e-15)
                    @test isapprox(value[1, 3], sum(value[1, 5:2:end]); atol = 0, rtol = 2e-15)
                end
            end
            conventional=calculate(
                "direct",
                false;
                convention = "Convention_I",
                tag = "conventionI",
            )
            sheared=calculate(
                "mixed",
                true;
                vectors = ((1.0, 1.0, 0.0), (0.0, 1.0, 0.0)),
                tag = "sheared",
            )
            for path in paths
                cp=only(filter(p->basename(p)==basename(path), conventional.outputs))
                hp=only(filter(p->basename(p)==basename(path), sheared.outputs))
                @test isapprox(
                    third_order_numeric_table(path),
                    third_order_numeric_table(cp);
                    atol = 0,
                    rtol = 3e-11,
                )
                @test isapprox(
                    third_order_numeric_table(path)[1, 2:end],
                    vec(sum(third_order_numeric_table(hp)[:, 5:end]; dims = 1))/4;
                    atol = 0,
                    rtol = 3e-11,
                )
            end
            translated=calculate("direct", true; origin = (1.0, -1.0, 0.0), tag = "translated")
            for path in filter(p->endswith(p, ".dat")&&!occursin("residual", p), slice.outputs)
                tp=only(filter(p->basename(p)==basename(path), translated.outputs))
                @test isapprox(
                    third_order_numeric_table(path)[:, 5:end],
                    third_order_numeric_table(tp)[:, 5:end];
                    atol = 0,
                    rtol = 2e-11,
                )
            end
        end
    end
end

@testset "Third-order Mixed resource cleanup on failures" begin
    runtime=WannierNLQG.Runtime;
    matrices=WannierNLQG.MatrixElements
    counts()=lock(matrices._MIXED_PROVIDER_LOCK) do
        (length(matrices._MIXED_PROVIDERS), length(matrices._FOURIER_TIMINGS))
    end
    withenv("WANNIERNLQG_FOURIER_TIMING"=>"1") do
        baseline=counts()
        mktempdir() do temporary
            for q in ("JC", "THG")
                physics=q=="JC" ?
                        JerkParameters(
                    photon_energies = [0.73],
                    fermi_energy = 0.0,
                    temperature = 0.0,
                ) : THGParameters(
                    photon_energies = [0.73],
                    fermi_energy = 0.0,
                    temperature = 300.0,
                )
                cfg=TaskConfig(
                    model = ModelInput(
                        model_file = joinpath(
                            dirname(@__DIR__),
                            "examples/fixtures/synthetic_runtime/synthetic_tb.dat",
                        ),
                    ),
                    sampling = BZMesh(k_mesh = (2, 2, 1)),
                    tasks = [
                        TaskSpec(
                            id = "cleanup",
                            quantity = q,
                            physics = physics,
                            observable = TensorComponents(TensorComponent(1, 1, 1, 1)),
                        ),
                    ],
                    execution = ExecutionOptions(fourier_backend = "mixed", NKFFT = (2, 2, 1)),
                    output = OutputOptions(
                        output_root = joinpath(temporary, q),
                        progress_enabled = false,
                    ),
                )
                effective=only(runtime.compile_task_configs(cfg));
                specs=runtime.validate_config(effective);
                ctx=runtime.prepare_run_context(effective, specs)
                @test_throws Exception runtime.prepare_third_order(
                    effective,
                    ctx,
                    specs;
                    prepare_only = true,
                    mixed_memory_limit_bytes = 1,
                )
                @test counts()==baseline
                prepared=runtime.prepare_third_order(effective, ctx, specs; prepare_only = true)
                @test counts()==(baseline[1]+Threads.nthreads(), baseline[2]+Threads.nthreads())
                prepared.cleanup!();
                prepared.cleanup!()
                @test counts()==baseline
                # A real numeric writer failure must also release registrations.
                filename=q=="JC" ? "jc_G_ordered_xxxx.dat" : "thg_regrouped_sigma_xxxx.dat"
                mkpath(joinpath(ctx.run_dir, filename))
                @test_throws Exception runtime.prepare_third_order(effective, ctx, specs)
                @test counts()==baseline
            end
        end
    end
end

@testset "Third-order retired threshold has no effective or inherited role" begin
    runtime=WannierNLQG.Runtime
    function third_order_threshold_config(task)
        TaskConfig(
            model = ModelInput(
                model_file = joinpath(
                    dirname(@__DIR__),
                    "examples/fixtures/synthetic_runtime/synthetic_tb.dat",
                ),
            ),
            sampling = BZMesh(k_mesh = (2, 2, 2)),
            tasks = [task],
            execution = ExecutionOptions(fourier_backend = "Direct"),
            output = OutputOptions(output_root = mktempdir(), progress_enabled = false),
        )
    end
    for (quantity, physics) in (
        ("JC", JerkParameters(photon_energies = [0.73], fermi_energy = 0.0, temperature = 0.0)),
        ("THG", THGParameters(photon_energies = [0.73], fermi_energy = 0.0, temperature = 300.0)),
    )
        task=TaskSpec(
            id = "retired_"*quantity,
            quantity = quantity,
            method = "Conventional",
            physics = physics,
        )
        cfg=third_order_threshold_config(task)
        @test !haskey(runtime.task_parameter_summary(cfg, task).numerics, :degeneracy_threshold)
        @test length(runtime.compile_task_configs(cfg))==1
        for old in (0.0, 0.002, nothing)
            retired=TaskSpec(
                id = task.id,
                quantity = quantity,
                method = "Conventional",
                physics = physics,
                numerics = Numerics(degeneracy_threshold = old),
            )
            err=try
                ;
                runtime.compile_task_configs(third_order_threshold_config(retired));
                nothing;
            catch e
                ;
                e;
            end
            @test err isa ArgumentError
            @test occursin("does not support degeneracy_threshold", sprint(showerror, err))
            @test !occursin("denominator_regularization", sprint(showerror, err))
        end
        shg=TaskSpec(
            id = "shg_threshold_control",
            quantity = "SHG",
            method = "Conventional",
            physics = SHGParameters(
                photon_energies = [0.73],
                fermi_energy = 0.0,
                temperature = 300.0,
            ),
            numerics = Numerics(degeneracy_threshold = 0.007),
        )
        mixed=TaskConfig(
            model = cfg.model,
            sampling = cfg.sampling,
            tasks = [task, shg],
            execution = cfg.execution,
            output = cfg.output,
        )
        @test length(runtime.compile_task_configs(mixed))==2
        @test runtime.task_parameter_summary(mixed, shg).numerics.degeneracy_threshold==0.007
    end
    elements=WannierNLQG.MatrixElements
    data=(spectrum = (energies = [0.0],),)
    @test_throws MethodError elements.prepare_third_order_band_geometry!(
        elements.JerkCurrentGeometry(1),
        data;
        degeneracy_threshold = 0.002,
    )
    @test_throws MethodError elements.prepare_jerk_current_geometry!(
        elements.JerkCurrentGeometry(1),
        data;
        degeneracy_threshold = 0.002,
    )
    @test_throws MethodError elements.prepare_third_order_geometry!(
        elements.ThirdOrderGeometry(1),
        data;
        degeneracy_threshold = 0.002,
    )
end
