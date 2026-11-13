using Test, WannierNLQG

@testset "Unified explicit numerical requests" begin
    retired = (
        :OpticalNumerics,
        :GeometryNumerics,
        :SHGNumerics,
        :BandNumerics,
        :LinearResponseNumerics,
        :OrbitalNumerics,
        :FermiSurfaceBroadening,
    )
    for name in retired
        @test !isdefined(WannierNLQG, name)
        @test !isdefined(WannierNLQG.Runtime, name)
        @test_throws UndefVarError Core.eval(WannierNLQG, Expr(:call, name))
        @test_throws UndefVarError Core.eval(WannierNLQG.Runtime, Expr(:call, name))
    end
    @test isempty(Numerics().supplied)
    @test Numerics(finite_difference_step = nothing).supplied == (:finite_difference_step,)
    @test_throws ArgumentError Numerics(eta = 0.01)
    @test_throws ArgumentError Numerics(fermi_surface = nothing)
    root=dirname(@__DIR__)
    model=ModelInput(
        model_file = joinpath(root, "examples/fixtures/synthetic_runtime/synthetic_tb.dat"),
    )
    make(
        n;
        q = "IC",
        physics = OpticalParameters(photon_energies = [0.5], fermi_energy = 0.0, temperature = 0.0),
    ) = TaskConfig(
        model = model,
        sampling = BZMesh(k_mesh = (2, 2, 2), spatial_dimension = 3),
        execution = ExecutionOptions(fourier_backend = "direct"),
        tasks = [TaskSpec(id = "numeric_test", quantity = q, physics = physics, numerics = n)],
    )
    lower(cfg)=WannierNLQG.Runtime.compile_task_config(cfg, only(cfg.tasks))
    defaults=lower(make(Numerics()))
    @test defaults.broadening == 0.040
    @test defaults.denominator_regularization == 0.001
    @test lower(make(nothing)).broadening == defaults.broadening
    explicit=Numerics(broadening = 0.071, denominator_regularization = 0.003)
    effective=lower(make(explicit))
    @test effective.broadening == 0.071
    @test effective.denominator_regularization == 0.003
    @test explicit.supplied == (:broadening, :denominator_regularization)
    for n in (
        Numerics(low_frequency_broadening = 0.01),
        Numerics(gap_tolerance = 1e-8),
        Numerics(broadening = NaN),
        Numerics(broadening = nothing),
        Numerics(broadening = -1),
        Numerics(finite_difference_step = 1e-4),
        Numerics(degeneracy_threshold = 0.002),
    )
        @test_throws ArgumentError lower(make(n))
    end
    shg=lower(
        make(
            Numerics();
            q = "SHG",
            physics = SHGParameters(photon_energies = [0.5], fermi_energy = 0, temperature = 0),
        ),
    )
    @test (
        shg.broadening,
        shg.shg_low_frequency_broadening,
        shg.denominator_regularization,
    )==(0.025, 0.025, 0.001)
    @test shg.shg_intermediate_regularization == 0.001
    shg_explicit=lower(
        make(
            Numerics(intermediate_regularization = 0.04);
            q = "SHG",
            physics = SHGParameters(photon_energies = [0.5], fermi_energy = 0, temperature = 0),
        ),
    )
    @test (
        shg_explicit.broadening,
        shg_explicit.shg_low_frequency_broadening,
        shg_explicit.shg_intermediate_regularization,
        shg_explicit.denominator_regularization,
    )==(0.025, 0.025, 0.04, 0.04)
    @test_throws ArgumentError lower(
        make(
            Numerics(denominator_regularization = 0.001);
            q = "SHG",
            physics = SHGParameters(photon_energies = [0.5], fermi_energy = 0, temperature = 0),
        ),
    )
    @test_throws ArgumentError lower(
        make(
            Numerics(eta_correction = 0);
            q = "SHG",
            physics = SHGParameters(photon_energies = [0.5], fermi_energy = 0, temperature = 0),
        ),
    )
end

@testset "Numerics errors name explicit parameters before IO" begin
    root=dirname(@__DIR__)
    make(
        n,
    )=TaskConfig(
        model = ModelInput(model_file = "unread_missing_model.dat"),
        sampling = BZMesh(k_mesh = (2, 2, 2), spatial_dimension = 3),
        tasks = [
            TaskSpec(
                id = "before_io",
                quantity = "SHG",
                physics = SHGParameters(
                    photon_energies = [0.5],
                    fermi_energy = 0.0,
                    temperature = 0.0,
                ),
                numerics = n,
            ),
        ],
        execution = ExecutionOptions(fourier_backend = "direct"),
    )
    for (key, value) in (
        (:broadening, "bad"),
        (:broadening, nothing),
        (:broadening, true),
        (:intermediate_regularization, NaN),
        (:broadening, big"1e-10000"),
        (:low_frequency_broadening, big"1e-10000"),
        (:intermediate_regularization, big"1e-10000"),
    )
        error=try
            WannierNLQG.Runtime.compile_task_config(
                make(Numerics(; key=>value)),
                only(make(Numerics(; key=>value)).tasks),
            )
            nothing
        catch exception
            exception
        end
        @test error isa ArgumentError
        @test occursin("before_io", sprint(showerror, error))
        @test occursin("second_harmonic_generation", sprint(showerror, error))
        @test occursin(string(key), sprint(showerror, error))
    end
    for name in (
        :OpticalNumerics,
        :GeometryNumerics,
        :SHGNumerics,
        :BandNumerics,
        :LinearResponseNumerics,
        :OrbitalNumerics,
        :FermiSurfaceBroadening,
    )
        module_under_test=Module(gensym(:RemovedImport))
        # Julia versions either warn or throw for an explicit missing import.
        # An error is acceptable only for this exact retired name; the binding
        # must remain absent and calling it must still fail below.
        import_error = try
            Core.eval(module_under_test, Meta.parse("using WannierNLQG: "*string(name)))
            nothing
        catch exception
            exception
        end
        @test import_error === nothing ||
              (import_error isa UndefVarError && import_error.var == name)
        @test !isdefined(module_under_test, name)
        @test_throws UndefVarError Core.eval(module_under_test, Expr(:call, name))
        @test_throws UndefVarError Core.eval(@__MODULE__, :(WannierNLQG.Runtime.$name()))
    end
    cfg=make(Numerics(broadening = 1))
    @test WannierNLQG.Runtime.compile_task_config(cfg, only(cfg.tasks)).broadening==1.0
end

@testset "Optical band window errors retain parameter identity" begin
    for value in (1.5, "2", 0, -2, big(2)^80, true)
        task=TaskSpec(
            id = "invalid_window",
            quantity = "IC",
            physics = OpticalParameters(
                photon_energies = [0.5],
                fermi_energy = 0.0,
                temperature = 0.0,
            ),
            numerics = Numerics(band_window_size = value),
        )
        cfg=TaskConfig(
            model = ModelInput(model_file = "not_read.dat"),
            sampling = BZMesh(k_mesh = (2, 2, 2)),
            tasks = [task],
            execution = ExecutionOptions(fourier_backend = "direct"),
        )
        exception=try
            WannierNLQG.Runtime.compile_task_config(cfg, task);
            nothing
        catch err
            err
        end
        @test exception isa ArgumentError
        @test occursin("invalid_window", sprint(showerror, exception))
        @test occursin("injection_current", sprint(showerror, exception))
        @test occursin("band_window_size", sprint(showerror, exception))
    end
end
