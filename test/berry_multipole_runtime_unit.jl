module BerryMultipoleRuntimeUnit
using Test, LinearAlgebra, ForwardDiff, WannierNLQG
import WannierNLQG.Core.ESKernel
const F=Main.OrthogonalGeometryAnalyticUnit
const G=Main.BerryGeometryBackendRuntimeUnit
const R=WannierNLQG.Runtime
@testset "Runtime uses the maintained planning owner directly" begin
    @test R.WorkspacePlanning === ESKernel.WorkspacePlanning
    @test R.WorkspacePlanning.checked_array_bytes === ESKernel.WorkspacePlanning.checked_array_bytes
    @test R.WorkspacePlanning.checked_sum_bytes === ESKernel.WorkspacePlanning.checked_sum_bytes
end
const P=WannierNLQG.Responses
const K=[0.173, 0.287, 0.319]
single_hamiltonian(k, p)=reshape([0.1*(k[1]^2+k[2]^2)], 1, 1)
function single_connection(k, p)
    connection=zeros(promote_type(ComplexF64, eltype(k)), 1, 1, 3)
    connection[1, 1, 2]=k[1]^2/2
    connection
end

function configuration(
    quantity,
    form;
    sampling = KRegion(lower = Tuple(K .- 0.01), upper = Tuple(K .+ 0.01), k_mesh = (1, 1, 1)),
    numerics = Numerics(),
    temperature = 300.0,
    fermi_energy = -norm(F.dvector(K)),
    algorithm = UniformIntegration(),
)
    component=quantity=="BCDC" ? (2, 1, 1) : (2, 1, 1, 1)
    TaskConfig(
        model = G.input_model(),
        sampling = sampling,
        tasks = [
            TaskSpec(
                id = "dc",
                quantity = quantity,
                method = "Conventional",
                physics = BerryMultipoleParameters(
                    fermi_energies = [fermi_energy],
                    temperature = temperature,
                    relaxation_time_fs = 7.0,
                    integral_form = form,
                ),
                numerics = numerics,
                observable = TensorComponents(TensorComponent(component...)),
            ),
        ],
        execution = ExecutionOptions(fourier_backend = "direct", integration_algorithm = algorithm),
        output = OutputOptions(
            output_root = mktempdir(),
            progress_enabled = false,
            response_output_digits = 16,
        ),
    )
end

function numeric_rows(path)
    [
        parse.(Float64, split(line)) for
        line in eachline(path) if !isempty(strip(line)) && !startswith(strip(line), "#")
    ]
end

# Independent closed two-band curvature and its derivatives; no response moment
# kernel, donor recurrence, eigensystem derivative or numerical k stencil.
function expected_moment(key, form, k, mu; temperature = 300.0, width = nothing)
    a, b, c=key[1:3]
    total=0.0
    for sign in (-1, 1)
        energy=sign*norm(F.dvector(k))
        beta=temperature>0 ? 1/(8.617333262145e-5*temperature) : Inf
        occupation=temperature>0 ? 1/(1+exp(beta*(energy-mu))) :
                   energy<mu ? 1.0 : energy==mu ? 0.5 : 0.0
        weight=temperature>0 ? beta*occupation*(1-occupation) :
               width===nothing ? NaN : exp(-((energy-mu)/width)^2)/(sqrt(pi)*width)
        curvature=x->F.closed_curvature(x, a, b, sign)
        gradient=ForwardDiff.gradient(x->sign*norm(F.dvector(x)), k)
        dipole=ForwardDiff.gradient(curvature, k)
        value=if length(key)==3
            form==:fermi_sea ? occupation*dipole[c] : weight*curvature(k)*gradient[c]
        else
            d=key[4]
            form==:fermi_sea ? occupation*ForwardDiff.hessian(curvature, k)[c, d] :
            weight*(gradient[c]*dipole[d]+gradient[d]*dipole[c])/2
        end
        total+=value
    end
    total
end

@testset "four public geometry consumers and actual DC files" begin
    for quantity in ("BCDC", "BCQC"), form in (:fermi_surface, :fermi_sea)
        cfg=configuration(quantity, form)
        effective=R.compile_task_config(cfg, only(cfg.tasks))
        expected_order=quantity=="BCDC" ? (form==:fermi_surface ? 0 : 1) :
                       (form==:fermi_surface ? 1 : 2)
        @test effective.berry_multipole.local_derivative_order==expected_order
        @test effective.derivative_backend==(expected_order==0 ? :not_applicable : :analytic)
        summary=R.task_parameter_summary(cfg, only(cfg.tasks))
        @test summary.observable.kind=="tensor_components"
        result=Base.invokelatest(WannierNLQG.run, cfg)
        momentfile=only(filter(x->endswith(x, "_moments.dat"), result.outputs))
        sigmafile=only(filter(x->endswith(x, "_conductivity.dat"), result.outputs))
        moments=numeric_rows(momentfile);
        sigmas=numeric_rows(sigmafile)
        @test length(sigmas)==1
        @test all(row->all(isfinite, row), vcat(moments, sigmas))
        @test occursin(
            "\u6709\u9650\u533a\u57df\u79ef\u5206；\u672a\u5305\u542b\u8fb9\u754c\u4fee\u6b63",
            read(momentfile, String),
        )
        @test occursin("spin_counting=one contribution per explicit state", read(sigmafile, String))
        mu=only(cfg.tasks).physics.fermi_energies[1]
        moment(key)=expected_moment(key, form, K, mu)*0.02^3/(2pi)^3
        # Check each independently identified axis tuple, including vanishing
        # diagonal-curvature channels; no assumption that permutations coincide.
        for row in moments
            @test isapprox(
                last(row),
                moment(Tuple(Int.(row[3:(end - 1)])));
                rtol = 2e-8,
                atol = 1e-16,
            )
        end
        e=1.602176634e-19;
        hbar=1.054571817e-34;
        tau=7e-15
        sigma=quantity=="BCDC" ? e^3*tau/(2hbar^2)*(moment((1, 2, 1))+moment((1, 1, 2))) :
              -e^4*tau^2/(3hbar^3)*1e-10*(
            moment((1, 2, 1, 1))+moment((1, 1, 2, 1))+moment((1, 1, 2, 1))
        )
        @test last(only(sigmas)) ≈ sigma rtol=2e-8 atol=1e-30
        @test abs(sigma)>0
    end
    invalid=configuration(
        "BCDC",
        :fermi_surface;
        numerics = Numerics(derivative_backend = :analytic),
    )
    @test_throws ArgumentError R.compile_task_config(invalid, only(invalid.tasks))
end

@testset "true affine sheet measure, zero-temperature and FD transport compatibility" begin
    b1=[0.02, 0.005, 0.0];
    b2=[0.003, 0.017, 0.004]
    sheet=KRegion(
        origin = Tuple(K .- (b1 .+ b2) ./ 2),
        vector_1 = Tuple(b1),
        vector_2 = Tuple(b2),
        k_mesh = (1, 1),
    )
    for quantity in ("BCDC", "BCQC")
        cfg=configuration(quantity, :fermi_surface; sampling = sheet)
        result=Base.invokelatest(WannierNLQG.run, cfg)
        file=only(filter(x->endswith(x, "_moments.dat"), result.outputs))
        @test occursin("physical_integration_dimension=2", read(file, String))
        mu=only(cfg.tasks).physics.fermi_energies[1]
        for row in numeric_rows(file)
            key=Tuple(Int.(row[3:(end - 1)]))
            expected=expected_moment(key, :fermi_surface, K, mu)*norm(cross(b1, b2))/(2pi)^2
            @test last(row) ≈ expected rtol=2e-8 atol=1e-16
        end
        for form in (:fermi_surface, :fermi_sea)
            numerics=form==:fermi_surface ? Numerics(eta_fs_ev = 0.02) : Numerics()
            zero=configuration(quantity, form; numerics, temperature = 0.0, fermi_energy = mu+0.01)
            output=Base.invokelatest(WannierNLQG.run, zero)
            path=only(filter(x->endswith(x, "_moments.dat"), output.outputs))
            for row in numeric_rows(path)
                key=Tuple(Int.(row[3:(end - 1)]))
                expected=expected_moment(
                    key,
                    form,
                    K,
                    mu+0.01;
                    temperature = 0.0,
                    width = 0.02,
                )*0.02^3/(2pi)^3
                @test last(row) ≈ expected rtol=2e-8 atol=1e-16
            end
        end
        fd=configuration(
            quantity,
            :fermi_sea;
            numerics = Numerics(
                derivative_backend = :finite_difference,
                finite_difference_step = 0.001,
                denominator_regularization = 1e-8,
            ),
        )
        output=Base.invokelatest(WannierNLQG.run, fd)
        path=only(filter(x->endswith(x, "_moments.dat"), output.outputs))
        for row in numeric_rows(path)
            key=Tuple(Int.(row[3:(end - 1)]))
            expected=expected_moment(key, :fermi_sea, K, mu)*0.02^3/(2pi)^3
            @test last(row) ≈ expected rtol=2e-4 atol=1e-14
        end
    end
end

@testset "named text input and effective replay retain physical expressions" begin
    directory=mktempdir()
    task(
        quantity,
        component,
        form,
    )=Dict{String, Any}(
        "kind"=>quantity,
        "method"=>"Conventional",
        "integral_form"=>form,
        "relaxation_time_fs"=>7.0,
        "observable"=>Dict("kind"=>"tensor_components", "components"=>[component]),
    )
    document=Dict{String, Any}(
        "model"=>Dict(
            "source"=>"wannier",
            "model_file"=>joinpath(
                @__DIR__,
                "..",
                "examples",
                "fixtures",
                "spectral_response",
                "closed_tb.dat",
            ),
        ),
        "response"=>Dict{String, Any}(
            "fermi_energies_ev"=>[-0.2, 0.13],
            "temperature_k"=>300.0,
            "sampling"=>Dict("kind"=>"bz_mesh", "k_mesh"=>[2, 2], "spatial_dimension"=>3),
            "execution"=>Dict("fourier_backend"=>"direct"),
            "tasks"=>Dict(
                "z_dipole"=>task("BCDC", [2, 1, 1], "fermi_surface"),
                "a_quadrupole"=>task("BCQC", [2, 1, 1, 1], "fermi_sea"),
            ),
        ),
        "output"=>Dict("output_root"=>joinpath(directory, "output"), "progress_enabled"=>false),
    )
    path=joinpath(directory, "input.toml")
    WannierNLQG.IO.write_task_input_file(path, document)
    input=read_task_input(path)
    @test isempty(input.pending)
    @test [t.id for t in input.config.tasks]==["a_quadrupole", "z_dipole"]
    @test [t.physics.integral_form for t in input.config.tasks]==[:fermi_sea, :fermi_surface]
    records=joinpath(directory, "records")
    write_task_input_resolution(input, records)
    replay=read_task_input(joinpath(records, "effective_config.toml"))
    @test isempty(replay.pending)
    @test [t.physics.integral_form for t in replay.config.tasks]==[:fermi_sea, :fermi_surface]
    @test [t.physics.relaxation_time_fs for t in replay.config.tasks]==[7.0, 7.0]
    for (actual, original) in zip(replay.summaries, input.summaries)
        @test actual.physics==original.physics
        @test actual.numerics==original.numerics
        @test actual.observable==original.observable
        @test actual.output_root==original.output_root
        # Effective replay explicitly states resolved defaults; original user
        # provenance correctly retains that those fields had been omitted.
        @test isempty(original.explicit_numerics)
        @test !isempty(actual.explicit_numerics)
    end
end

@testset "adaptive shares the true finite-domain integrand and budget contract" begin
    region=KRegion(lower = (0.172, 0.286), upper = (0.174, 0.288), k_mesh = (2, 2))
    bad=configuration(
        "BCDC",
        :fermi_surface;
        sampling = region,
        algorithm = HAdaptiveCubature(max_evaluations = 16),
    )
    @test_throws ArgumentError R.compile_task_config(bad, only(bad.tasks))
    uniform=configuration("BCDC", :fermi_surface; sampling = region)
    adaptive=configuration(
        "BCDC",
        :fermi_surface;
        sampling = region,
        algorithm = HAdaptiveCubature(atol = 1e-10, rtol = 1e-7, max_evaluations = 1000),
    )
    function moment_values(cfg)
        result=Base.invokelatest(WannierNLQG.run, cfg)
        path=only(filter(x->endswith(x, "_moments.dat"), result.outputs))
        [last(row) for row in numeric_rows(path)]
    end
    @test moment_values(adaptive) ≈ moment_values(uniform) rtol=2e-4 atol=1e-15
end

@testset "single-band nonzero derivative: region additivity and expansion" begin
    input=AnalyticKInput(
        hamiltonian = single_hamiltonian,
        num_orbitals = 1,
        lattice = Matrix{Float64}(I, 3, 3),
        basis = :explicit,
        operators = (position = single_connection,),
        periodic = false,
        derivative_method = :automatic,
        source_file = @__FILE__
    )
    function integrate(lower, upper)
        cfg=TaskConfig(
            model = input,
            sampling = KRegion(; lower, upper, k_mesh = (1, 1)),
            tasks = [
                TaskSpec(
                    id = "constant_dipole",
                    quantity = "BCDC",
                    method = "Conventional",
                    physics = BerryMultipoleParameters(
                        fermi_energies = [10.0],
                        temperature = 0.0,
                        relaxation_time_fs = 7.0,
                        integral_form = :fermi_sea,
                    ),
                    observable = TensorComponents(TensorComponent(2, 1, 1)),
                ),
            ],
            execution = ExecutionOptions(fourier_backend = "direct"),
            output = OutputOptions(
                output_root = mktempdir(),
                progress_enabled = false,
                response_output_digits = 16,
            ),
        )
        result=Base.invokelatest(WannierNLQG.run, cfg)
        path=only(filter(x->endswith(x, "_moments.dat"), result.outputs))
        rows=numeric_rows(path)
        value=last(only(filter(row->row[3:(end - 1)]==[1.0, 2.0, 1.0], rows)))
        expected=(upper[1]-lower[1])*(upper[2]-lower[2])/(2pi)^2
        @test value ≈ expected atol=1e-13 rtol=1e-12
        @test value>0
        value
    end
    full=integrate((-1.0, -1.0), (1.0, 1.0))
    left=integrate((-1.0, -1.0), (0.0, 1.0));
    right=integrate((0.0, -1.0), (1.0, 1.0))
    expanded=integrate((-2.0, -2.0), (2.0, 2.0))
    @test left+right ≈ full atol=1e-13 rtol=1e-12
    @test expanded ≈ 4full atol=1e-13 rtol=1e-12
end

@testset "nonorthogonal scope retains existing geometry admission and BCD rejection" begin
    core=WannierNLQG.Core
    model=core.NonorthogonalLocalizedModel(
        lattice = Matrix{Float64}(I, 3, 3),
        r_vectors = zeros(Int, 3, 1),
        hamiltonian_r = reshape(ComplexF64[-1 0; 0 1], 2, 2, 1),
        overlap_r = reshape(ComplexF64[1 0.1; 0.1 1], 2, 2, 1),
        position_r = zeros(ComplexF64, 2, 2, 3, 1),
    )
    input=core.NonorthogonalLocalizedInput(model; source_file = @__FILE__)
    for backend in (:finite_difference, :analytic)
        original=G.configuration("BCDK"; numerics = Numerics(derivative_backend = backend))
        cfg=TaskConfig(
            model = input,
            sampling = original.sampling,
            tasks = original.tasks,
            execution = original.execution,
            output = original.output,
        )
        # r73 already rejects nonorthogonal BCDK, including its FD route.
        # Preserving FD compatibility does not expand that original scope.
        @test_throws ArgumentError R.compile_task_config(cfg, only(cfg.tasks))
    end
    berry_task=TaskSpec(
        id = "existing_metric_berry",
        quantity = "Berry_Curvature",
        method = "Conventional",
        physics = GeometryParameters(),
        numerics = Numerics(denominator_regularization = 0.001),
        observable = KSliceSelection(component = TensorComponent(1, 2), bands = AllBands()),
    )
    original=G.configuration("BCDK")
    berry_cfg=TaskConfig(
        model = input,
        sampling = original.sampling,
        tasks = [berry_task],
        execution = original.execution,
        output = original.output,
    )
    @test R.compile_task_config(berry_cfg, berry_task).denominator_regularization==0.001
    original=configuration("BCQC", :fermi_surface)
    cfg=TaskConfig(
        model = input,
        sampling = original.sampling,
        tasks = original.tasks,
        execution = original.execution,
        output = original.output,
    )
    @test_throws ArgumentError R.compile_task_config(cfg, only(cfg.tasks))
end
end
