module FiniteDomainRuntimeTests
using WannierNLQG, LinearAlgebra, Test
const R=WannierNLQG.Runtime
const C=WannierNLQG.Core
const lat=2Matrix{Float64}(I, 3, 3)
const h=ComplexF64[-1 0.4; 0.4 1]
const tau=[0.0 0.3; 0.0 0.2; 0.0 0.1]
const tb=RealSpaceTBInput(
    lattice = lat,
    r_vectors = zeros(Int, 3, 1),
    hamiltonian_r = reshape(h, 2, 2, 1),
    orbital_positions = tau,
    position_model = :point_orbitals,
)
const periodic=AnalyticKInput(
    hamiltonian = (k, p)->h,
    num_orbitals = 2,
    lattice = lat,
    orbital_positions = tau,
    source_file = @__FILE__
)
const continuum=AnalyticKInput(
    hamiltonian = (k, p)->h,
    num_orbitals = 2,
    lattice = lat,
    orbital_positions = tau,
    periodic = false,
    source_file = @__FILE__
)
const position=zeros(ComplexF64, 2, 2, 3, 1)
for a in 1:3
    position[:, :, a, 1]=Diagonal(tau[a, :])
end
const nao=C.NonorthogonalLocalizedInput(
    C.NonorthogonalLocalizedModel(
        lattice = lat,
        r_vectors = zeros(Int, 3, 1),
        hamiltonian_r = reshape(h, 2, 2, 1),
        overlap_r = reshape(Matrix{ComplexF64}(I, 2, 2), 2, 2, 1),
        position_r = position,
    ),
)
function config(
    model,
    sampling;
    quantity = "SC",
    algorithm = UniformIntegration(),
    tag = "response",
    backend = "direct",
    fft = nothing,
)
    physics=quantity=="THG" ?
            THGParameters(
        photon_energies = [0.73, 1.2],
        fermi_energy = 0.0,
        temperature = 300.0,
        formulation = :both,
    ) :
            quantity=="JC" ?
            JerkParameters(photon_energies = [0.73, 1.2], fermi_energy = 0.0, temperature = 300.0) :
            OpticalParameters(
        photon_energies = [0.73, 1.2],
        fermi_energy = 0.0,
        temperature = 300.0,
    )
    return TaskConfig(
        model = model,
        sampling = sampling,
        tasks = [
            TaskSpec(
                id = tag,
                quantity = quantity,
                method = "Conventional",
                physics = physics,
                observable = quantity in ("THG", "JC") ?
                             TensorComponents(TensorComponent(1, 1, 1, 1)) : FullTensor(),
                numerics = quantity in ("THG", "JC") ? Numerics() : Numerics(broadening = 0.15),
            ),
        ],
        execution = ExecutionOptions(
            fourier_backend = backend,
            integration_algorithm = algorithm,
            NKFFT = fft,
        ),
        output = OutputOptions(
            output_root = mktempdir(),
            progress_enabled = false,
            response_output_digits = 17,
        ),
    )
end
function table(path)
    rows=[
        parse.(Float64, split(line)) for
        line in eachline(path) if !isempty(strip(line)) && !startswith(strip(line), "#")
    ]
    return permutedims(reduce(hcat, rows))
end
dat(result)=only(filter(p->endswith(p, ".dat") && !occursin("residual", p), result.outputs))
@testset "All public model families retain periodicity under KRegion" begin
    full=KRegion(lower = (0.0, 0.0), upper = (pi, pi), k_mesh = (2, 2))
    for model in (tb, periodic, nao)
        cfg=config(model, full)
        effective=@test_logs (:warn, r"Finite-domain response") only(R.compile_task_configs(cfg))
        @test R.integration_model_periodic(effective)
        runtime=model isa AnalyticKInput ? C.AnalyticKModel(model) : model.model
        @test R.integration_cell_measure(effective, runtime)≈8
        regional=WannierNLQG.run(cfg)
        bz=WannierNLQG.run(config(model, BZMesh(k_mesh = (2, 2))))
        @test table(dat(regional))≈table(dat(bz)) rtol=1e-10 atol=1e-20
        @test occursin("Cartesian unfolded region", read(dat(regional), String))
    end
    file=joinpath(dirname(@__DIR__), "examples/fixtures/synthetic_runtime/synthetic_tb.dat")
    result=WannierNLQG.run(config(ModelInput(model_file = file), full))
    @test !isempty(result.outputs)
    for d in 1:3
        region=KRegion(
            lower = ntuple(_->0.0, d),
            upper = ntuple(_->pi, d),
            k_mesh = ntuple(_->2, d),
        )
        effective=only(R.compile_task_configs(config(tb, region)))
        @test R.integration_cell_measure(effective, tb.model)≈8
    end
end
@testset "Periodic patch partition and continuum dimensions" begin
    full=KRegion(lower = (0.0, 0.0), upper = (pi, pi), k_mesh = (2, 2))
    left=KRegion(lower = (0.0, 0.0), upper = (pi/2, pi), k_mesh = (1, 2))
    right=KRegion(lower = (pi/2, 0.0), upper = (pi, pi), k_mesh = (1, 2))
    for quantity in ("SC", "THG", "JC")
        results=[WannierNLQG.run(config(tb, s; quantity)) for s in (full, left, right)]
        names=basename.(
            filter(p->endswith(p, ".dat")&&!occursin("residual", p), results[1].outputs),
        )
        for name in names
            first_response_column=quantity=="SC" ? 3 : 2
            values=[
                table(only(filter(p->basename(p)==name, r.outputs)))[:, first_response_column:end]
                for r in results
            ]
            @test values[1]≈values[2]+values[3] rtol=1e-11 atol=1e-25
        end
    end
    cfg=config(continuum, full; quantity = "THG")
    effective=@test_logs (:warn, r"Finite-domain response") only(R.compile_task_configs(cfg))
    options=effective.third_order
    factors=R.third_order_si_factors(C.AnalyticKModel(continuum), false, effective)
    @test R.integration_cell_measure(effective, C.AnalyticKModel(continuum))*1e-30≈4e-20
    result=WannierNLQG.run(cfg)
    @test any(p->endswith(p, ".dat")&&occursin("units=A*m^2/V^3", read(p, String)), result.outputs)
    @test any(
        p->endswith(p, ".dat")&&occursin("boundary_corrections", read(p, String)),
        result.outputs,
    )
end
@testset "Adaptive runtime uses the same weighted multifrequency kernels" begin
    algorithm=HAdaptiveCubature(
        atol = 0.0,
        rtol = 1e-9,
        max_evaluations = 200,
        initial_divisions = 1,
    )
    for quantity in ("SC", "THG")
        uniform=WannierNLQG.run(
            config(tb, BZMesh(k_mesh = (2, 2), spatial_dimension = 3); quantity),
        )
        adaptive=WannierNLQG.run(
            config(tb, BZMesh(k_mesh = (2, 2), spatial_dimension = 3); quantity, algorithm),
        )
        for path in filter(p->endswith(p, ".dat")&&!occursin("residual", p), uniform.outputs)
            counterpart=only(filter(p->basename(p)==basename(path), adaptive.outputs))
            @test table(path)≈table(counterpart) rtol=1e-9 atol=1e-25
        end
        diagnostic=read(
            only(filter(p->basename(p)=="integration_diagnostics.txt", adaptive.outputs)),
            String,
        )
        @test occursin("estimate_converged=true", diagnostic)
        @test occursin("normalization=domain_average", diagnostic)
        @test occursin("numerical_estimate_is_strict_bound=false", diagnostic)
    end
    @testset "Variable response, Cartesian adaptive and retained budget output" begin
        rv=Int[0 1 -1 0 0; 0 0 0 1 -1; 0 0 0 0 0]
        hamiltonian=zeros(ComplexF64, 2, 2, 5)
        hamiltonian[:, :, 1]=[-0.7 0.4; 0.4 0.9]
        hamiltonian[:, :, 2]=[0.1 0.17+0.13im; 0.07-0.04im -0.05]
        hamiltonian[:, :, 3]=hamiltonian[:, :, 2]'
        hamiltonian[:, :, 4]=[0.04 -0.03im; 0.06+0.11im -0.09]
        hamiltonian[:, :, 5]=hamiltonian[:, :, 4]'
        variable=RealSpaceTBInput(
            lattice = lat,
            r_vectors = rv,
            hamiltonian_r = hamiltonian,
            orbital_positions = tau,
            position_model = :point_orbitals,
        )
        uniform=WannierNLQG.run(config(variable, BZMesh(k_mesh = (32, 32), spatial_dimension = 3)))
        adaptive=WannierNLQG.run(
            config(
                variable,
                BZMesh(k_mesh = (2, 2), spatial_dimension = 3);
                algorithm = HAdaptiveCubature(atol = 0.0, rtol = 1e-6, max_evaluations = 5000),
            ),
        )
        expected=table(dat(uniform))[:, 3:end]
        actual=table(dat(adaptive))[:, 3:end]
        @test maximum(abs, expected)>0
        @test isapprox(actual, expected; rtol = 2e-4, atol = 0)
        region=KRegion(lower = (0.13, -0.21), upper = (0.13+pi/2, -0.21+pi), k_mesh = (2, 2))
        direct=WannierNLQG.run(config(variable, region))
        automatic=WannierNLQG.run(config(variable, region; backend = "auto", fft = (2, 2)))
        @test table(dat(direct))==table(dat(automatic))
        @test_throws ArgumentError R.compile_task_configs(
            config(variable, region; backend = "mixed", fft = (2, 2)),
        )
        regional_uniform=WannierNLQG.run(
            config(
                variable,
                KRegion(lower = (0.13, -0.21), upper = (0.13+pi/2, -0.21+pi), k_mesh = (32, 32)),
            ),
        )
        regional_adaptive=WannierNLQG.run(
            config(
                variable,
                region;
                algorithm = HAdaptiveCubature(atol = 0.0, rtol = 1e-6, max_evaluations = 5000),
            ),
        )
        @test isapprox(
            table(dat(regional_adaptive))[:, 3:end],
            table(dat(regional_uniform))[:, 3:end];
            rtol = 2e-3,
            atol = 0,
        )
        limited=@test_logs (:warn, r"Adaptive integral stopped") match_mode=:any WannierNLQG.run(
            config(
                variable,
                BZMesh(k_mesh = (2, 2), spatial_dimension = 3);
                algorithm = HAdaptiveCubature(atol = 0.0, rtol = 1e-14, max_evaluations = 17),
            ),
        )
        @test all(isfinite, table(dat(limited)))
        diagnostic=read(
            only(filter(p->basename(p)=="integration_diagnostics.txt", limited.outputs)),
            String,
        )
        @test occursin("estimate_converged=false", diagnostic)
        @test occursin("termination=evaluation_budget", diagnostic)
    end
end
@testset "Direct-only KRegion and 1D–3D adaptive physical measures" begin
    algorithm=HAdaptiveCubature(atol = 0, rtol = 1e-9, max_evaluations = 300)
    for d in 1:3
        region=KRegion(
            lower = ntuple(_->0.0, d),
            upper = ntuple(_->pi, d),
            k_mesh = ntuple(_->2, d),
        )
        for quantity in ("SC", "THG")
            direct=WannierNLQG.run(config(tb, region; quantity))
            adaptive=WannierNLQG.run(config(tb, region; quantity, algorithm, backend = "auto"))
            for path in filter(p->endswith(p, ".dat")&&!occursin("residual", p), direct.outputs)
                counterpart=only(filter(p->basename(p)==basename(path), adaptive.outputs))
                @test table(path)≈table(counterpart) rtol=1e-9 atol=1e-25
            end
            diagnostic=read(
                only(filter(p->basename(p)=="integration_diagnostics.txt", adaptive.outputs)),
                String,
            )
            @test occursin("effective_fourier_backend=direct", diagnostic)
            @test occursin("integration_dimension="*string(d), diagnostic)
            @test_throws ArgumentError R.compile_task_configs(
                config(tb, region; quantity, backend = "mixed"),
            )
        end
        for model in (tb, periodic, nao)
            direct=WannierNLQG.run(config(model, region))
            automatic=WannierNLQG.run(
                config(model, region; backend = "auto", fft = d==1 ? (2, 1, 1) : ntuple(_->2, d)),
            )
            @test table(dat(direct))==table(dat(automatic))
        end
        c=only(R.compile_task_configs(config(continuum, region; quantity = "THG", algorithm)))
        @test R.integration_dimension(c)==d
        @test R.integration_cell_measure(c, C.AnalyticKModel(continuum))≈2.0^d*10.0^(10*(3-d))
        result=WannierNLQG.run(config(continuum, region; quantity = "THG", algorithm))
        expected_units=("A*m^3/V^3", "A*m^2/V^3", "A*m/V^3")[d]
        @test any(
            p->endswith(p, ".dat")&&occursin("units="*expected_units, read(p, String)),
            result.outputs,
        )
    end
    # A complete BZ remains the existing two/three-axis mesh contract.
    for quantity in ("SC", "THG")
        uniform=WannierNLQG.run(
            config(tb, BZMesh(k_mesh = (2, 2, 2), spatial_dimension = 3); quantity),
        )
        adaptive=WannierNLQG.run(
            config(tb, BZMesh(k_mesh = (2, 2, 2), spatial_dimension = 3); quantity, algorithm),
        )
        for path in filter(p->endswith(p, ".dat")&&!occursin("residual", p), uniform.outputs)
            counterpart=only(filter(p->basename(p)==basename(path), adaptive.outputs))
            @test table(path)≈table(counterpart) rtol=1e-9 atol=1e-25
        end
    end
    for constructor in (JerkParameters, THGParameters), measure in (:bulk, :sheet, :effective_bulk)
        @test_throws ArgumentError constructor(
            photon_energies = [0.73],
            fermi_energy = 0.0,
            temperature = 300.0,
            response_measure = measure,
        )
    end
end
end
