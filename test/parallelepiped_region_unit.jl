module ParallelepipedRegionTests
using WannierNLQG, LinearAlgebra, Test, TOML
const C = WannierNLQG.Core
const R = WannierNLQG.Runtime
include(joinpath(@__DIR__, "support", "ParallelepipedRegionFixture.jl"))
const Fixture = ParallelepipedRegionFixture
const LATTICE = Matrix{Float64}(I, 3, 3)*2
function cartesian_nodes(region)
    grid =
        region.affine_region === nothing ?
        C.CartesianRegionGrid(
            region.lower,
            region.upper,
            region.k_mesh,
            region.spatial_dimension,
            LATTICE,
        ) : C.CartesianAffineGrid(region.affine_region, region.k_mesh, LATTICE)
    point = zeros(3)
    return [
        begin
            C.integral_kpoint!(point, grid, index)
            transpose(C.reciprocal_lattice(LATTICE))*point
        end for index in 1:length(grid)
    ]
end
quadrature(region, f) =
    region.affine_region.measure*sum(f, cartesian_nodes(region))/prod(region.k_mesh)
geometry(mesh = (2, 3, 2)) = KRegion(;
    origin = (0.3, -0.2, 0.1),
    vector_1 = (2.0, 0.5, 0.3),
    vector_2 = (-0.4, 1.5, 0.2),
    vector_3 = (0.2, -0.1, 0.8),
    k_mesh = mesh,
)

@testset "Three-dimensional affine volume, coordinates, dimensions and validation" begin
    region = geometry();
    nodes = cartesian_nodes(region)
    # Analytic determinant of the decimal fixture is exactly 1271/500.
    @test region.affine_region.volume ≈ 2.542
    @test region.spatial_dimension == 3
    @test length(unique(nodes)) == 12
    @test quadrature(region, _ -> 1.0) ≈ 2.542
    for (index, point) in enumerate(nodes)
        i, j, l = (index-1)%2, ((index-1)÷2)%3, (index-1)÷6
        expected =
            [0.3, -0.2, 0.1] +
            ((i+0.5)/2)*[2.0, 0.5, 0.3] +
            ((j+0.5)/3)*[-0.4, 1.5, 0.2] +
            ((l+0.5)/2)*[0.2, -0.1, 0.8]
        @test point ≈ expected atol=2e-15
        @test all(0 .< ([2.0 -0.4 0.2; 0.5 1.5 -0.1; 0.3 0.2 0.8]\(point-[0.3, -0.2, 0.1])) .< 1)
    end
    reversed = KRegion(;
        origin = (2.3, 0.3, 0.4),
        vector_1 = (-2.0, -0.5, -0.3),
        vector_2 = (-0.4, 1.5, 0.2),
        vector_3 = (0.2, -0.1, 0.8),
        k_mesh = (2, 3, 2),
    )
    @test quadrature(reversed, _ -> 1.0) ≈ quadrature(region, _ -> 1.0)
    @test all(
        isapprox(collect(a), collect(b); atol = 2e-15) for
        (a, b) in zip(sort(Tuple.(cartesian_nodes(reversed))), sort(Tuple.(nodes)))
    )
    box = KRegion(; lower = (0.0, 0.0, 0.0), upper = (2.0, 3.0, 4.0), k_mesh = (2, 3, 4))
    affine = KRegion(;
        origin = (0.0, 0.0, 0.0),
        vector_1 = (2.0, 0.0, 0.0),
        vector_2 = (0.0, 3.0, 0.0),
        vector_3 = (0.0, 0.0, 4.0),
        k_mesh = (2, 3, 4),
    )
    @test reinterpret(UInt64, reduce(vcat, cartesian_nodes(box))) ==
          reinterpret(UInt64, reduce(vcat, cartesian_nodes(affine)))
    mktempdir() do directory
        cfg = only(R.compile_task_configs(Fixture.config(region, directory; quantities = ("SC",))))
        @test R.integration_dimension(cfg) == 3
        @test cfg.spatial_dimension == 3
        @test R.integration_cell_measure(cfg, C.AnalyticKModel(Fixture.model())) ≈ (2pi)^3/2.542
        meta = R.integration_domain_metadata(cfg)
        @test meta.integration_volume_A_inverse_cubed ≈ 2.542
        @test meta.integration_point_weight_A_inverse_cubed ≈ 2.542/12
        @test meta.integration_dimension == 3 && !meta.model_periodic
        Fixture.evidence(
            "volume_geometry",
            (;
                origin = region.affine_region.origin,
                vectors = region.affine_region.vectors,
                volume = region.affine_region.measure,
                counts = region.k_mesh,
                nodes,
                constant_integral = quadrature(region, _ -> 1.0),
                metadata = meta,
            ),
        )
    end
    @test_throws DimensionMismatch KRegion(;
        origin = (0.0, 0.0),
        vector_1 = (1.0, 0.0),
        vector_2 = (0.0, 1.0),
        vector_3 = (0.0, 0.0, 1.0),
        k_mesh = (2, 2, 2),
    )
    @test_throws DimensionMismatch KRegion(;
        origin = (0.0, 0.0, 0.0),
        vector_1 = (1.0, 0.0, 0.0),
        vector_2 = (0.0, 1.0, 0.0),
        vector_3 = (0.0, 0.0, 1.0),
        k_mesh = (2, 2),
    )
    @test_throws ArgumentError KRegion(;
        origin = (0.0, 0.0, 0.0),
        vector_1 = (1.0, 0.0, 0.0),
        vector_2 = (0.0, 1.0, 0.0),
        vector_3 = (1.0, 1.0, 0.0),
        k_mesh = (2, 2, 2),
    )
    @test_throws ArgumentError KRegion(;
        origin = (0.0, 0.0, 0.0),
        vector_1 = (1.0, 0.0, 0.0),
        vector_2 = (0.0, 1.0, 0.0),
        vector_3 = (0.0, 0.0, 0.0),
        k_mesh = (2, 2, 2),
    )
    @test_throws ArgumentError KRegion(;
        origin = (Inf, 0.0, 0.0),
        vector_1 = (1.0, 0.0, 0.0),
        vector_2 = (0.0, 1.0, 0.0),
        vector_3 = (0.0, 0.0, 1.0),
        k_mesh = (2, 2, 2),
    )
    @test_throws ArgumentError KRegion(;
        origin = (0.0, 0.0, 0.0),
        vector_1 = (1.0, 0.0, 0.0),
        vector_2 = (0.0, 1.0, 0.0),
        vector_3 = (0.0, 0.0, NaN),
        k_mesh = (2, 2, 2),
    )
    @test_throws ArgumentError KRegion(;
        origin = (0.0, 0.0, 0.0),
        vector_1 = (1.0, 0.0, 0.0),
        vector_2 = (0.0, 1.0, 0.0),
        vector_3 = (0.0, 0.0, 1.0),
        k_mesh = (2, true, 2),
    )
    @test_throws ArgumentError KRegion(;
        lower = (0.0, 0.0, 0.0),
        upper = (1.0, 1.0, 1.0),
        origin = (0.0, 0.0, 0.0),
        vector_1 = (1.0, 0.0, 0.0),
        vector_2 = (0.0, 1.0, 0.0),
        vector_3 = (0.0, 0.0, 1.0),
        k_mesh = (2, 2, 2),
    )
end

@testset "Independent three-dimensional polynomial integral" begin
    exact = 2.542*((0.3+(2-0.4+0.2)/2)^2 + (2^2+0.4^2+0.2^2)/12)
    values = Dict(string(n) => quadrature(geometry((n, n, n)), k -> k[1]^2) for n in (2, 4, 8))
    for n in (2, 4, 8)
        @test values[string(n)] ≈ exact-2.542*(2^2+0.4^2+0.2^2)/(12*n^2) atol=1e-13
    end
    @test abs(values["8"]-exact) ≈ abs(values["4"]-exact)/4 atol=1e-13
    Fixture.evidence("volume_polynomial", (; exact, values))
end

@testset "Volume TOML, effective replay, provenance and actual public tasks" begin
    mktempdir() do directory
        doc = Dict{String, Any}(
            "model"=>Dict("source"=>"julia", "identity"=>"two-band-3D-fixture"),
            "response"=>Dict{String, Any}(
                "energy_zero"=>"Hamiltonian reference",
                "fermi_energy_ev"=>0.0,
                "temperature_k"=>0.0,
                "photon_energies_ev"=>[5.8, 6.4],
                "photon_momentum_A_inverse"=>collect(Fixture.MOMENTUM),
                "sampling"=>Dict(
                    "kind"=>"k_region",
                    "spatial_dimension"=>3,
                    "k_mesh"=>[2, 2, 2],
                    "origin"=>[4.0, 0.2, 0.1],
                    "vector_1"=>[0.4, 0.08, 0.02],
                    "vector_2"=>[0.12, 0.36, -0.01],
                    "vector_3"=>[0.03, 0.02, 0.2],
                ),
                "execution"=>Dict("fourier_backend"=>"direct"),
                "tasks" => Dict{String, Any}(
                    "pdsc" => Dict(
                        "kind"=>"PDSC",
                        "method"=>"Geometric_Loop",
                        "numerics"=>Dict("broadening"=>0.25),
                    ),
                    "pdic" => Dict(
                        "kind"=>"PDIC",
                        "method"=>"Conventional",
                        "numerics"=>Dict("broadening"=>0.25),
                    ),
                ),
            ),
            "output"=>Dict(
                "output_root"=>directory,
                "progress_enabled"=>false,
                "response_output_digits"=>17,
            ),
        )
        resolved = resolve_task_input(doc; model = Fixture.model(), base_dir = directory)
        @test isempty(resolved.pending)
        @test resolved.config.sampling.affine_region == Fixture.region(2).affine_region
        @test resolved.provenance["response.sampling.vector_3"]["source"] == "USER"
        @test resolved.provenance["response.sampling.domain_measure"]["unit"] == "A^-3"
        @test resolved.provenance["response.sampling.point_weight"]["value"] ≈
              Fixture.region(2).affine_region.measure/8
        @test occursin("vector_3", explain_task_input(resolved))
        path=joinpath(directory, "effective.toml");
        open(io -> TOML.print(io, resolved.effective), path, "w")
        replay=read_task_input(path; model = Fixture.model());
        @test isempty(replay.pending)
        @test replay.config.sampling.affine_region == resolved.config.sampling.affine_region
        @test "model.payload" in read_task_input(path).pending
        invalid=deepcopy(doc);
        delete!(invalid["response"]["sampling"], "vector_3")
        @test "response.sampling.vector_3" in
              resolve_task_input(invalid; model = Fixture.model()).pending
        invalid=deepcopy(doc);
        invalid["response"]["sampling"]["spatial_dimension"]=2
        @test_throws ArgumentError resolve_task_input(invalid; model = Fixture.model())
        text=run_task_input(resolved; record_directory = joinpath(directory, "text-records"))
        julia_result=WannierNLQG.run(
            Fixture.config(
                Fixture.region(2),
                joinpath(directory, "julia");
                quantities = ("PDSC", "PDIC"),
                system_name = "two-band-3D-fixture",
            ),
        )
        a, b=Fixture.tensors(text), Fixture.tensors(julia_result);
        @test Set(keys(a))==Set(keys(b))
        for name in keys(a)
            ;
            @test reinterpret(UInt64, vec(a[name]))==reinterpret(UInt64, vec(b[name]));
        end
        Fixture.retain_result("volume_TOML", text);
        Fixture.retain_result("volume_Julia", julia_result)
        Fixture.evidence(
            "volume_toml",
            (;
                effective = resolved.effective,
                provenance = resolved.provenance,
                replay_pending = replay.pending,
                text = Fixture.tensor_records(a),
                julia = Fixture.tensor_records(b),
            ),
        )
    end
end

@testset "3D nonzero AD/FD responses, volume once, cuboid and unwrapped finite-q" begin
    mktempdir() do directory
        tables=Dict{Int, Any}()
        for n in (2, 4, 8)
            Fixture.Shared.RECORD_POINTS[]=n==2;
            n==2 && empty!(Fixture.Shared.OBSERVED_CARTESIAN_POINTS)
            result=WannierNLQG.run(Fixture.config(Fixture.region(n), joinpath(directory, "mesh$n")))
            tables[n]=Fixture.tensors(result);
            Fixture.retain_result("volume_AD$n", result)
            @test length(tables[n])==4
            @test all(maximum(abs, t)>0 for t in values(tables[n]))
            if n==2
                for k in cartesian_nodes(Fixture.region(2)), sign in (-1, 1)
                    shifted=k+sign*collect(Fixture.MOMENTUM)/2
                    @test any(
                        p -> isapprox(collect(p), shifted; atol = 1e-12, rtol = 0),
                        Fixture.Shared.OBSERVED_CARTESIAN_POINTS,
                    )
                    @test shifted[1]>pi
                end
            end
        end
        Fixture.Shared.RECORD_POINTS[]=false
        result=WannierNLQG.run(
            Fixture.config(
                Fixture.region(4),
                joinpath(directory, "fd");
                derivative_method = :finite_difference,
            ),
        )
        fd=Fixture.tensors(result);
        Fixture.retain_result("volume_FD4", result)
        @test Set(keys(fd))==Set(keys(tables[4]))
        for name in keys(fd)
            @test fd[name] ≈ tables[4][name] rtol=1e-4 atol=maximum(abs, tables[4][name])*1e-7
            @test norm(tables[8][name]-tables[4][name])<=norm(tables[4][name]-tables[2][name])
        end
        summed=Dict(name=>zeros(size(t)) for (name, t) in tables[4])
        affine=Fixture.region(4).affine_region
        for u in (0.0, 0.5)
            sample=KRegion(;
                origin = C.cartesian_affine_point(affine, u, 0.0, 0.0),
                vector_1 = affine.vector_1 ./ 2,
                vector_2 = affine.vector_2,
                vector_3 = affine.vector_3,
                k_mesh = (2, 4, 4),
            )
            result=WannierNLQG.run(Fixture.config(sample, joinpath(directory, "tile$u")))
            for (name, t) in Fixture.tensors(result)
                ;
                summed[name].+=t;
            end
        end
        for name in keys(summed)
            ;
            @test summed[name] ≈ tables[4][name] rtol=1e-10 atol=maximum(abs, tables[4][name])*1e-12;
        end
        box=KRegion(; lower = (4.0, 0.2, 0.1), upper = (4.4, 0.56, 0.3), k_mesh = (2, 2, 2))
        orthogonal=KRegion(;
            origin = box.lower,
            vector_1 = (box.upper[1]-box.lower[1], 0.0, 0.0),
            vector_2 = (0.0, box.upper[2]-box.lower[2], 0.0),
            vector_3 = (0.0, 0.0, box.upper[3]-box.lower[3]),
            k_mesh = (2, 2, 2),
        )
        box_result=WannierNLQG.run(Fixture.config(box, joinpath(directory, "box")))
        orth_result=WannierNLQG.run(Fixture.config(orthogonal, joinpath(directory, "orth")))
        a, b=Fixture.tensors(box_result), Fixture.tensors(orth_result)
        for name in keys(a)
            ;
            @test reinterpret(UInt64, vec(a[name]))==reinterpret(UInt64, vec(b[name]));
        end
        Fixture.retain_result("volume_box", box_result);
        Fixture.retain_result("volume_orthogonal", orth_result)
        Fixture.evidence(
            "volume_responses",
            (;
                meshes = Dict(string(n)=>Fixture.tensor_records(t) for (n, t) in tables),
                finite_difference = Fixture.tensor_records(fd),
                tiled_integral = Fixture.tensor_records(summed),
                cuboid = Fixture.tensor_records(a),
                orthogonal = Fixture.tensor_records(b),
                momentum = Fixture.MOMENTUM,
                observed_cartesian_points = unique(Fixture.Shared.OBSERVED_CARTESIAN_POINTS),
            ),
        )
    end
end
end
