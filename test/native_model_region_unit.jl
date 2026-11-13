module NativeModelRegionTests
using WannierNLQG, LinearAlgebra, Test
const C=WannierNLQG.Core
const R=WannierNLQG.Runtime
lat=Matrix{Float64}(I, 3, 3)*2
ham(k, p)=[0.4 1+0.2k[1]-0.1im*k[2]; 1+0.2k[1]+0.1im*k[2] -0.4]
input=AnalyticKInput(
    hamiltonian = ham,
    num_orbitals = 2,
    lattice = lat,
    orbital_positions = zeros(3, 2),
    periodic = false,
    evaluation_bounds = ((-2.0, -2.0, -2.0), (2.0, 2.0, 2.0)),
    source_file = @__FILE__
)
@testset "Region quadrature measure" begin
    for d in 1:3
        box=KRegion(lower = ntuple(_->-1.0, d), upper = ntuple(_->1.0, d), k_mesh = ntuple(_->2, d))
        cfg=TaskConfig(
            model = input,
            sampling = box,
            tasks = [
                TaskSpec(
                    id = "shift",
                    quantity = "SC",
                    method = "Conventional",
                    physics = OpticalParameters(
                        photon_energies = [1.0, 2.0],
                        fermi_energy = 0.0,
                        temperature = 0.0,
                    ),
                    numerics = Numerics(broadening = 0.1),
                    observable = FullTensor(),
                ),
            ],
            execution = ExecutionOptions(fourier_backend = "direct"),
            output = OutputOptions(output_root = mktempdir(), progress_enabled = false),
        )
        effective=only(R.compile_task_configs(cfg));
        model=C.AnalyticKModel(input)
        grid=R._integral_k_grid(effective, model)
        @test length(grid)==2^d
        point=zeros(3)
        for i in 1:length(grid)
            C.integral_kpoint!(point, grid, i)
            k=transpose(C.reciprocal_lattice(lat))*point
            @test all(abs(k[a])≈0.5 for a in 1:d)
            @test all(k[a]==0 for a in (d + 1):3)
        end
        @test R.integration_cell_measure(effective, model)*1e-30≈(2pi)^d/2^d*1e-10^d
        result=WannierNLQG.run(cfg)
        @test !isempty(result.outputs)
    end
end

@testset "Midpoint mesh error and cutoff are separate" begin
    function integrate_square(cutoff, n)
        box=KRegion(lower = (-cutoff,), upper = (cutoff,), k_mesh = (n,))
        grid=C.CartesianRegionGrid(box.lower, box.upper, box.k_mesh, 1, lat)
        point=zeros(3)
        total=0.0
        for i in 1:length(grid)
            C.integral_kpoint!(point, grid, i)
            k=transpose(C.reciprocal_lattice(lat))*point
            total+=k[1]^2
        end
        return total/n*(2cutoff)/(2pi)
    end
    for cutoff in (0.5, 1.0)
        reference=cutoff^3/(3pi)
        errors=[abs(integrate_square(cutoff, n)-reference) for n in (8, 16, 32)]
        @test errors[2] ≈ errors[1]/4 atol=1e-14
        @test errors[3] ≈ errors[2]/4 atol=1e-14
    end
    @test integrate_square(1.0, 32) ≈ 8integrate_square(0.5, 32) atol=1e-14
end

@testset "Native tutorials can be imported and run explicitly" begin
    root=dirname(dirname(pathof(WannierNLQG)))
    for file in ("real_space_tb.jl", "periodic_analytic.jl", "nonperiodic_kp.jl")
        mod=Module(gensym(:NativeTutorial))
        Core.eval(mod, :(include(path)=Base.include(@__MODULE__, path)))
        Base.include(mod, joinpath(root, "examples", "native_models", file))
        destination=joinpath(mktempdir(), "not_created_on_import")
        cfg=Base.invokelatest(mod.build_config; smoke = true, output_root = destination)
        @test !ispath(destination)
        result=Base.invokelatest(WannierNLQG.run, cfg)
        @test !isempty(result.outputs)
    end
end

@testset "Explicit endpoint box and nonregion admission" begin
    endpoint = UniformIntegration(region_quadrature = :left_endpoint)
    task = TaskSpec(
        id = "shift",
        quantity = "SC",
        method = "Conventional",
        physics = OpticalParameters(photon_energies = [1.0], fermi_energy = 0.0, temperature = 0.0),
        numerics = Numerics(broadening = 0.1),
        observable = FullTensor(),
    )
    box = KRegion(lower = (-1.0,), upper = (1.0,), k_mesh = (1,))
    cfg = TaskConfig(
        model = input,
        sampling = box,
        tasks = [task],
        execution = ExecutionOptions(fourier_backend = "direct", integration_algorithm = endpoint),
        output = OutputOptions(output_root = mktempdir(), progress_enabled = false),
    )
    effective = only(R.compile_task_configs(cfg))
    model = C.AnalyticKModel(input)
    grid = R._integral_k_grid(effective, model)
    point = zeros(3)
    C.integral_kpoint!(point, grid, 1)
    @test transpose(C.reciprocal_lattice(lat))*point ≈ [-1.0, 0.0, 0.0]
    @test R.integration_domain_metadata(effective).integration_bounds == (box.lower, box.upper)
    @test R.integration_domain_metadata(effective).integration_region_quadrature == "left_endpoint"
    result = WannierNLQG.run(cfg)
    @test all(path -> occursin("left_endpoint", read(path, String)), result.outputs)
    @test occursin("left_endpoint", read(only(result.task_results).metadata_path, String))
    for sampling in (BZMesh(k_mesh = (2, 2), spatial_dimension = 2),)
        invalid = TaskConfig(
            model = input,
            sampling = sampling,
            tasks = [task],
            execution = cfg.execution,
            output = cfg.output,
        )
        @test_throws ArgumentError R.compile_task_configs(invalid)
    end
    invalid_path = TaskConfig(
        model = input,
        sampling = KPath(
            nodes = [("G", (0.0, 0.0, 0.0)), ("X", (0.5, 0.0, 0.0))],
            kpoints_per_segment = [2],
        ),
        tasks = [
            TaskSpec(id = "band", quantity = "Band", physics = BandParameters(fermi_energy = 0.0)),
        ],
        execution = cfg.execution,
        output = cfg.output,
    )
    @test_throws ArgumentError R.compile_task_configs(invalid_path)
    @test_throws ArgumentError C.CartesianRegionGrid(
        box.lower,
        box.upper,
        box.k_mesh,
        1,
        lat,
        :right_endpoint,
    )
end
end
