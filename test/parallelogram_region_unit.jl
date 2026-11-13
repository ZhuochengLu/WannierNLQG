module ParallelogramRegionTests
using WannierNLQG, LinearAlgebra, Test, TOML
const C = WannierNLQG.Core
const R = WannierNLQG.Runtime
include(joinpath(@__DIR__, "support", "ParallelogramRegionFixture.jl"))
const Fixture = ParallelogramRegionFixture
const LATTICE = Matrix{Float64}(I, 3, 3)*2

"""Read the grid through the runtime coordinate interface, not the constructor formula."""
function cartesian_nodes(region)
    grid =
        region.parallelogram === nothing ?
        C.CartesianRegionGrid(
            region.lower,
            region.upper,
            region.k_mesh,
            region.spatial_dimension,
            LATTICE,
        ) : C.CartesianParallelogramGrid(region.parallelogram, region.k_mesh[1:2], LATTICE)
    point = zeros(3)
    return [
        begin
            C.integral_kpoint!(point, grid, index)
            transpose(C.reciprocal_lattice(LATTICE))*point
        end for index in 1:length(grid)
    ]
end

"""Integrate with physical area per node; independent of response prefactors."""
function quadrature(region, integrand)
    return region.parallelogram.area * sum(integrand, cartesian_nodes(region))/prod(region.k_mesh)
end

@testset "Parallelogram geometry, weights, dimension and errors" begin
    region = KRegion(;
        origin = (0.3, -0.2),
        vector_1 = (2.0, 0.5),
        vector_2 = (-0.4, 1.5),
        k_mesh = (2, 3),
    )
    @test region.parallelogram.area ≈ 3.2
    @test region.spatial_dimension == 2
    @test length(unique(cartesian_nodes(region))) == 6
    @test quadrature(region, _ -> 1.0) ≈ 3.2
    for (index, k) in enumerate(cartesian_nodes(region))
        uv = [2.0 -0.4; 0.5 1.5] \ (k[1:2] .- [0.3, -0.2])
        @test all(0 .< uv .< 1)
        @test uv ≈ [((index-1)%2 + 0.5)/2, ((index-1)÷2 + 0.5)/3]
        @test k[3] == 0
    end
    embedded = KRegion(;
        origin = (0.3, -0.2, 0.8),
        vector_1 = (2.0, 0.0, 1.0),
        vector_2 = (0.0, 3.0, 0.5),
        k_mesh = (2, 3),
    )
    @test embedded.parallelogram.area ≈ sqrt(46.0)
    effective =
        only(R.compile_task_configs(Fixture.config(embedded, mktempdir(); quantities = ("SC",))))
    @test R.integration_dimension(effective) == 2
    @test effective.spatial_dimension == 3
    @test R.integration_cell_measure(effective, C.AnalyticKModel(Fixture.model()))*1e-30 ≈
          (2pi)^2/sqrt(46.0)*1e-20
    metadata = R.integration_domain_metadata(effective)
    @test metadata.integration_samples == 6
    @test metadata.integration_point_weight_A_inverse_squared ≈ sqrt(46.0)/6
    @test metadata.model_periodic == false
    for (origin, b1, b2) in (
        ((0.0, 0.0), (0.0, 0.0), (0.0, 1.0)),
        ((0.0, 0.0), (1.0, 2.0), (2.0, 4.0)),
        ((Inf, 0.0), (1.0, 0.0), (0.0, 1.0)),
        ((0.0, 0.0), (true, 0.0), (0.0, 1.0)),
    )
        @test_throws ArgumentError KRegion(; origin, vector_1 = b1, vector_2 = b2, k_mesh = (2, 2))
    end
    @test_throws DimensionMismatch KRegion(;
        origin = (0.0, 0.0),
        vector_1 = (1.0, 0.0, 0.0),
        vector_2 = (0.0, 1.0),
        k_mesh = (2, 2),
    )
    for mesh in ((0, 2), (true, 2), (2.0, 2), (2^53, 2))
        @test_throws ArgumentError KRegion(;
            origin = (0.0, 0.0),
            vector_1 = (1.0, 0.0),
            vector_2 = (0.0, 1.0),
            k_mesh = mesh,
        )
    end
    @test_throws ArgumentError KRegion(;
        lower = (0.0, 0.0),
        upper = (1.0, 1.0),
        origin = (0.0, 0.0),
        vector_1 = (1.0, 0.0),
        vector_2 = (0.0, 1.0),
        k_mesh = (2, 2),
    )
    Fixture.evidence(
        "geometry",
        (;
            origin = region.parallelogram.origin,
            vector_1 = region.parallelogram.vector_1,
            vector_2 = region.parallelogram.vector_2,
            counts = region.k_mesh[1:2],
            nodes = cartesian_nodes(region),
            area = region.parallelogram.area,
            constant_integral = quadrature(region, _ -> 1.0),
            embedded_area = embedded.parallelogram.area,
            physical_dimension = R.integration_dimension(effective),
            tensor_dimension = effective.spatial_dimension,
            inverse_density = R.integration_cell_measure(
                effective,
                C.AnalyticKModel(Fixture.model()),
            ),
            metadata,
        ),
    )
end

@testset "Independent polynomial integral, rectangle equivalence and orientation" begin
    for mesh in ((2, 3), (5, 4))
        rectangle = KRegion(; lower = (-0.7, -0.4), upper = (0.9, 0.8), k_mesh = mesh)
        affine = KRegion(;
            origin = (-0.7, -0.4),
            vector_1 = (rectangle.upper[1] - rectangle.lower[1], 0.0),
            vector_2 = (0.0, rectangle.upper[2] - rectangle.lower[2]),
            k_mesh = mesh,
        )
        @test all(
            reinterpret(UInt64, a) == reinterpret(UInt64, b) for
            (a, b) in zip(cartesian_nodes(rectangle), cartesian_nodes(affine))
        )
    end
    exact = 3.2*(0.3^2 + 0.3*(2.0 - 0.4) + (2.0^2 + (-0.4)^2)/3 + 2.0*(-0.4)/2)
    errors = Float64[]
    polynomial_values = Dict{String, Float64}()
    for n in (4, 8, 16)
        region = KRegion(;
            origin = (0.3, -0.2),
            vector_1 = (2.0, 0.5),
            vector_2 = (-0.4, 1.5),
            k_mesh = (n, n),
        )
        reversed = KRegion(;
            origin = (2.3, 0.3),
            vector_1 = (-2.0, -0.5),
            vector_2 = (-0.4, 1.5),
            k_mesh = (n, n),
        )
        @test quadrature(region, k -> k[1]^2) ≈ quadrature(reversed, k -> k[1]^2) atol=1e-13
        polynomial_values[string(n)] = quadrature(region, k -> k[1]^2)
        push!(errors, abs(polynomial_values[string(n)] - exact))
    end
    @test errors[2] ≈ errors[1]/4 atol=1e-13
    @test errors[3] ≈ errors[2]/4 atol=1e-13
    periodic(k) = exp(cos(k[1]) + 0.4sin(k[2]))
    basis(n; shear = false, translate = false) = KRegion(;
        origin = translate ? (2pi, -2pi) : (0.0, 0.0),
        vector_1 = (2pi, 0.0),
        vector_2 = shear ? (2pi, 2pi) : (0.0, 2pi),
        k_mesh = (n, n),
    )
    @test quadrature(basis(7), periodic) ≈ quadrature(basis(7; translate = true), periodic) atol=1e-12
    reference = quadrature(basis(64), periodic)
    e16 = abs(quadrature(basis(16; shear = true), periodic) - reference)
    e32 = abs(quadrature(basis(32; shear = true), periodic) - reference)
    @test e32 <= e16 + 1e-12
    @test e32 < 1e-10
    Fixture.evidence(
        "polynomial",
        (;
            exact,
            values = polynomial_values,
            errors,
            periodic_reference = reference,
            periodic_shear16 = quadrature(basis(16; shear = true), periodic),
            periodic_shear32 = quadrature(basis(32; shear = true), periodic),
        ),
    )
end

@testset "TOML region, finite-q provenance and one-chain effective roundtrip" begin
    mktempdir() do directory
        doc = Dict{String, Any}(
            "model" => Dict("source" => "julia", "identity" => "two-band-continuum-fixture"),
            "response" => Dict{String, Any}(
                "energy_zero" => "Hamiltonian reference",
                "fermi_energy_ev" => 0.0,
                "temperature_k" => 0.0,
                "photon_energies_ev" => [5.8, 6.4],
                "photon_momentum_A_inverse" => collect(Fixture.MOMENTUM),
                "sampling" => Dict(
                    "kind" => "k_region",
                    "spatial_dimension" => 2,
                    "k_mesh" => [2, 2],
                    "origin" => [4.0, 0.2],
                    "vector_1" => [0.4, 0.08],
                    "vector_2" => [0.12, 0.36],
                ),
                "execution" => Dict("fourier_backend" => "direct"),
                "tasks" => Dict{String, Any}(
                    "pdsc" => Dict(
                        "kind" => "PDSC",
                        "method" => "Geometric_Loop",
                        "numerics" => Dict("broadening" => 0.25),
                    ),
                    "pdic" => Dict(
                        "kind" => "PDIC",
                        "method" => "Conventional",
                        "numerics" => Dict("broadening" => 0.25),
                    ),
                ),
            ),
            "output" => Dict(
                "output_root" => directory,
                "system_name" => "two-band-continuum-fixture",
                "progress_enabled" => false,
                "response_output_digits" => 17,
            ),
        )
        resolved = resolve_task_input(doc; model = Fixture.model(), base_dir = directory)
        @test isempty(resolved.pending)
        @test resolved.config.sampling.parallelogram.area ≈ 0.1344
        @test resolved.provenance["response.sampling.domain_measure"]["source"] == "DERIVED"
        @test resolved.provenance["response.sampling.point_weight"]["value"] ≈ 0.1344/4
        @test occursin("Cartesian; unfolded", explain_task_input(resolved))
        @test only(
            unique(cfg.photon_momentum for cfg in R.compile_task_configs(resolved.config)),
        ) == Fixture.MOMENTUM
        path = joinpath(directory, "effective.toml")
        open(io -> TOML.print(io, resolved.effective), path, "w")
        replay = read_task_input(path; model = Fixture.model())
        @test isempty(replay.pending)
        @test replay.config.sampling.parallelogram == resolved.config.sampling.parallelogram
        pending = read_task_input(path)
        @test "model.payload" in pending.pending
        invalid = deepcopy(doc);
        invalid["response"]["sampling"]["spatial_dimension"] = 3
        @test "response.sampling.vector_3" in
              resolve_task_input(invalid; model = Fixture.model()).pending
        invalid = deepcopy(doc);
        invalid["response"]["sampling"]["lower"] = [0.0, 0.0]
        @test_throws ArgumentError resolve_task_input(invalid; model = Fixture.model())
        text_result =
            run_task_input(resolved; record_directory = joinpath(directory, "text-records"))
        julia_result = WannierNLQG.run(
            Fixture.config(
                Fixture.region(2),
                joinpath(directory, "julia");
                quantities = ("PDSC", "PDIC"),
                system_name = "two-band-continuum-fixture",
            ),
        )
        text_tables, julia_tables = Fixture.tensors(text_result), Fixture.tensors(julia_result)
        @test Set(keys(text_tables)) == Set(keys(julia_tables))
        for name in keys(text_tables)
            @test reinterpret(UInt64, vec(text_tables[name])) ==
                  reinterpret(UInt64, vec(julia_tables[name]))
        end
        Fixture.retain_result("TOML", text_result);
        Fixture.retain_result("Julia", julia_result)
        Fixture.evidence(
            "toml",
            (;
                effective = resolved.effective,
                provenance = resolved.provenance,
                replay_pending = replay.pending,
                missing_model_pending = pending.pending,
                text = Fixture.tensor_records(text_tables),
                julia = Fixture.tensor_records(julia_tables),
            ),
        )
    end
end

@testset "Real nonzero optical responses, numerical derivatives and unfolded finite-q legs" begin
    mktempdir() do directory
        tables = Dict{Int, Any}()
        for n in (2, 4, 8)
            Fixture.RECORD_POINTS[] = n == 2
            n == 2 && empty!(Fixture.OBSERVED_CARTESIAN_POINTS)
            result =
                WannierNLQG.run(Fixture.config(Fixture.region(n), joinpath(directory, "mesh$n")))
            tables[n] = Fixture.tensors(result)
            Fixture.retain_result("AD$n", result)
            @test length(tables[n]) == 4
            @test all(maximum(abs, tensor) > 0 for tensor in values(tables[n]))
            if n == 2
                for k in cartesian_nodes(Fixture.region(n)), sign in (-1, 1)
                    shifted = k .+ sign .* collect(Fixture.MOMENTUM) ./ 2
                    @test any(
                        point -> isapprox(collect(point), shifted; atol = 1e-12, rtol = 0),
                        Fixture.OBSERVED_CARTESIAN_POINTS,
                    )
                    @test shifted[1] > pi
                end
            end
        end
        Fixture.RECORD_POINTS[] = false
        fd_result = WannierNLQG.run(
            Fixture.config(
                Fixture.region(4),
                joinpath(directory, "finite-difference");
                derivative_method = :finite_difference,
            ),
        )
        fd = Fixture.tensors(fd_result);
        Fixture.retain_result("FD4", fd_result)
        @test Set(keys(fd)) == Set(keys(tables[4]))
        for name in keys(fd)
            @test fd[name] ≈ tables[4][name] rtol=1e-4 atol=maximum(abs, tables[4][name])*1e-7
            @test norm(tables[8][name] - tables[4][name]) <= norm(tables[4][name] - tables[2][name])
        end
        # Identical nodes in four affine tiles: physical integrals add, so no second area factor.
        tile_sum = Dict(name => zeros(size(table)) for (name, table) in tables[4])
        for u in (0.0, 0.5), v in (0.0, 0.5)
            region = Fixture.region(4).parallelogram
            sampling = KRegion(;
                origin = C.cartesian_parallelogram_point(region, u, v)[1:2],
                vector_1 = (region.vector_1[1]/2, region.vector_1[2]/2),
                vector_2 = (region.vector_2[1]/2, region.vector_2[2]/2),
                k_mesh = (2, 2),
            )
            tile_result =
                WannierNLQG.run(Fixture.config(sampling, joinpath(directory, "tile-$u-$v")))
            data = Fixture.tensors(tile_result);
            Fixture.retain_result("tile-$u-$v", tile_result)
            for name in keys(tile_sum)
                tile_sum[name] .+= data[name]
            end
        end
        for name in keys(tile_sum)
            @test tile_sum[name] ≈ tables[4][name] rtol=1e-10 atol=maximum(
                abs,
                tables[4][name],
            )*1e-12
        end
        rectangle = KRegion(; lower = (4.0, 0.2), upper = (4.4, 0.56), k_mesh = (4, 4))
        affine = KRegion(;
            origin = (4.0, 0.2),
            vector_1 = (rectangle.upper[1] - rectangle.lower[1], 0.0),
            vector_2 = (0.0, rectangle.upper[2] - rectangle.lower[2]),
            k_mesh = (4, 4),
        )
        box_result = WannierNLQG.run(Fixture.config(rectangle, joinpath(directory, "rectangle")))
        affine_result = WannierNLQG.run(Fixture.config(affine, joinpath(directory, "orthogonal")))
        a, b = Fixture.tensors(box_result), Fixture.tensors(affine_result)
        Fixture.retain_result("rectangle", box_result);
        Fixture.retain_result("orthogonal", affine_result)
        for name in keys(a)
            @test reinterpret(UInt64, vec(a[name])) == reinterpret(UInt64, vec(b[name]))
        end
        Fixture.evidence(
            "responses",
            (;
                meshes = Dict(string(n) => Fixture.tensor_records(tables[n]) for n in (2, 4, 8)),
                finite_difference = Fixture.tensor_records(fd),
                tiled_integral = Fixture.tensor_records(tile_sum),
                rectangle = Fixture.tensor_records(a),
                orthogonal = Fixture.tensor_records(b),
                observed_cartesian_points = unique(Fixture.OBSERVED_CARTESIAN_POINTS),
                momentum = Fixture.MOMENTUM,
            ),
        )
    end
end

@testset "Paper first/N nodes on the original affine domain" begin
    mktempdir() do directory
        region = KRegion(
            origin = (0.0, 0.0),
            vector_1 = (0.4, 0.08),
            vector_2 = (0.12, 0.36),
            k_mesh = (200, 200),
        )
        endpoint = UniformIntegration(region_quadrature = :left_endpoint)
        config = Fixture.config(
            region,
            directory;
            quantities = ("PDSC",),
            integration_algorithm = endpoint,
        )
        effective = only(R.compile_task_configs(config))
        model = C.AnalyticKModel(Fixture.model())
        grid = R._integral_k_grid(effective, model)
        @test length(grid) == 40000
        @test grid.region.origin == region.parallelogram.origin == (0.0, 0.0, 0.0)
        nodes = NTuple{3, Float64}[]
        point = zeros(3)
        max_coordinate_error = 0.0
        for index in 1:length(grid)
            C.integral_kpoint!(point, grid, index)
            actual = transpose(C.reciprocal_lattice(model.lattice))*point
            u = ((index-1)%200)/200
            v = ((index-1)÷200)/200
            expected =
                collect(region.parallelogram.origin) +
                u*collect(region.parallelogram.vector_1) +
                v*collect(region.parallelogram.vector_2)
            max_coordinate_error = max(max_coordinate_error, maximum(abs.(actual-expected)))
            push!(nodes, Tuple(actual))
        end
        @test max_coordinate_error <= 8eps(Float64)
        @test length(unique(nodes)) == 40000
        @test first(nodes) == (0.0, 0.0, 0.0)
        @test collect(nodes[200]) ≈ (199/200)*collect(region.parallelogram.vector_1) atol=8eps(
            Float64,
        )
        @test collect(nodes[201]) ≈ (1/200)*collect(region.parallelogram.vector_2) atol=8eps(
            Float64,
        )
        @test collect(last(nodes)) ≈
              (
            199/200
        )*(collect(region.parallelogram.vector_1) + collect(region.parallelogram.vector_2)) atol=8eps(
            Float64,
        )
        metadata = R.integration_domain_metadata(effective)
        @test metadata.integration_region_quadrature == "left_endpoint"
        @test metadata.integration_origin_A_inverse == (0.0, 0.0, 0.0)
        @test metadata.integration_area_A_inverse_squared == region.parallelogram.area
        @test metadata.integration_point_weight_A_inverse_squared*length(grid) ≈
              region.parallelogram.area
        @test !metadata.model_periodic
        @test R.integration_cell_measure(effective, model) == R.integration_cell_measure(
            only(R.compile_task_configs(Fixture.config(region, directory; quantities = ("PDSC",)))),
            model,
        )
        Fixture.evidence(
            "left_endpoint_grid",
            (;
                count = length(grid),
                max_coordinate_error,
                first = nodes[1],
                first_axis_end = nodes[200],
                second_axis_start = nodes[201],
                last = nodes[end],
                metadata,
            ),
        )
        small = Fixture.config(
            Fixture.region(1),
            joinpath(directory, "endpoint-output");
            quantities = ("PDSC",),
            integration_algorithm = endpoint,
        )
        result = WannierNLQG.run(small)
        @test all(path -> occursin("left_endpoint", read(path, String)), result.outputs)
        @test occursin("left_endpoint", read(only(result.task_results).metadata_path, String))
    end
    region3 =
        C.CartesianAffineRegion((1.0, 2.0, 3.0), (2.0, 0.0, 0.0), (0.0, 3.0, 0.0), (0.0, 0.0, 4.0))
    grid3 = C.CartesianAffineGrid(region3, (2, 1, 1), LATTICE, :left_endpoint)
    point = zeros(3)
    C.integral_kpoint!(point, grid3, 1)
    @test transpose(C.reciprocal_lattice(LATTICE))*point ≈ [1.0, 2.0, 3.0]
    C.integral_kpoint!(point, grid3, 2)
    @test transpose(C.reciprocal_lattice(LATTICE))*point ≈ [2.0, 2.0, 3.0]
    @test region3.volume/length(grid3)*length(grid3) == 24.0
end
end
