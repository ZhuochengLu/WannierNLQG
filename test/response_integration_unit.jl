module ResponseIntegrationTests
using WannierNLQG, LinearAlgebra, Test
const R=WannierNLQG.Runtime
@testset "Multifrequency complex weighted cubature" begin
    domain=IntegrationDomain2D(lower = (-1.0, 2.0), upper = (3.0, 5.0), coordinates = :cartesian)
    algorithm=HAdaptiveCubature(atol = 1e-11, rtol = 1e-10, max_evaluations = 1000)
    shared=zeros(ComplexF64, 2, 2)
    function evaluator(x)
        shared .= [x[1]^2+im*x[2] 2x[1]*x[2]; 3+0im x[2]]
        return shared
    end
    expected=ComplexF64[28+42im 84; 36 42]
    integral=integrate_response(evaluator, domain, algorithm; normalization = :integral)
    @test integral.value≈expected atol=1e-10
    @test integral.estimate_converged
    @test integral.evaluations==17
    @test integral.domain_measure==12
    @test integral.normalization==:integral
    mean=integrate_response(evaluator, domain, algorithm)
    @test mean.value≈expected/12 atol=1e-10
    fill!(shared, 0)
    @test integral.value≈expected atol=1e-10
    constant=integrate_response(
        _->2+3im,
        domain,
        UniformIntegration();
        normalization = :integral,
        k_mesh = (2, 3),
    )
    @test constant.value==12*(2+3im)
    @test constant.evaluations==6
    @test constant.embedded_estimate===nothing
    @test_throws ArgumentError HAdaptiveCubature(atol = 0, rtol = 0)
    @test_throws ArgumentError HAdaptiveCubature(atol = big"1e-1000", rtol = 0)
    @test_throws ArgumentError HAdaptiveCubature(atol = big"1e1000", rtol = 0)
    @test_throws ArgumentError IntegrationDomain2D(lower = (0.0, 0.0), upper = (1e200, 1e200))
    @test_throws ArgumentError IntegrationDomain2D(lower = (0.0, 0.0), upper = (1e-200, 1e-200))
    @test_throws ArgumentError IntegrationDomain2D(
        lower = (big"1e1000", 0),
        upper = (big"2e1000", 1),
    )
    @test_throws ArgumentError integrate_response(
        _->1,
        IntegrationDomain2D((0.0, 0.0), (1e200, 1e200), :cartesian),
        UniformIntegration(),
    )
    @test_throws ArgumentError integrate_response(
        _->1,
        domain,
        HAdaptiveCubature(max_evaluations = 16),
    )
    @test_throws ArgumentError integrate_response(
        _->1,
        domain,
        HAdaptiveCubature(initial_divisions = 2, max_evaluations = 67),
    )
    @test_throws ArgumentError integrate_response(_->NaN, domain, algorithm)
    counter=Ref(0)
    @test_throws DimensionMismatch integrate_response(domain, algorithm) do _
        counter[]+=1
        zeros(counter[]==1 ? 1 : 2)
    end
    budget=HAdaptiveCubature(atol = 0, rtol = 1e-14, max_evaluations = 17)
    result=@test_logs (:warn, r"Adaptive integral stopped") integrate_response(
        x->exp(3x[1]+x[2]),
        domain,
        budget,
    )
    @test result.termination==:evaluation_budget
    @test !result.estimate_converged
    @test isfinite(result.value)
end
@testset "One to three active axes and complete cubature rules" begin
    @test IntegrationDomain2D===IntegrationDomain{2}
    tiny=IntegrationDomain(lower = (0.0,), upper = (1e-310,))
    @test_throws ArgumentError integrate_response(_->1, tiny, UniformIntegration())
    @test_throws ArgumentError IntegrationDomain(lower = (), upper = ())
    @test_throws ArgumentError IntegrationDomain(lower = (0, 0, 0, 0), upper = (1, 1, 1, 1))
    @test_throws DimensionMismatch IntegrationDomain{2}(lower = (0,), upper = (1,))
    for d in 1:3
        lower=(-1.0, 2.0, -2.0)[1:d];
        upper=(3.0, 5.0, 4.0)[1:d]
        domain=IntegrationDomain(; lower, upper, coordinates = :cartesian)
        midpoint=(lower .+ upper) ./ 2;
        measure=prod(upper .- lower)
        shared=zeros(ComplexF64, 2, 2, 2)
        function evaluator(x)
            shared[:, :, 1] .= [x[1]^2+im*sum(x) 2prod(x); 3+0im x[d]]
            shared[:, :, 2] .= (2-im) .* shared[:, :, 1]
            return shared
        end
        expected=zeros(ComplexF64, 2, 2, 2)
        expected[:, :, 1] .= [7/3+im*sum(midpoint) 2prod(midpoint); 3+0im midpoint[d]]
        expected[:, :, 2] .= (2-im) .* expected[:, :, 1]
        rule=(15, 17, 33)[d]
        for divisions in (1, 2)
            count=rule*divisions^d
            algorithm=HAdaptiveCubature(
                atol = 1e-11,
                rtol = 1e-10,
                max_evaluations = count,
                initial_divisions = divisions,
            )
            mean=integrate_response(evaluator, domain, algorithm)
            @test mean.value≈expected atol=1e-10
            @test mean.evaluations==count
            @test mean.domain_measure==measure
            @test mean.estimate_converged
            integral=integrate_response(evaluator, domain, algorithm; normalization = :integral)
            @test integral.value≈measure .* expected atol=1e-9
            fill!(shared, 0)
            @test mean.value≈expected atol=1e-10
            called=Ref(false)
            @test_throws ArgumentError integrate_response(
                x->(called[] = true; 1),
                domain,
                HAdaptiveCubature(max_evaluations = count-1, initial_divisions = divisions),
            )
            @test !called[]
        end
        uniform=integrate_response(
            evaluator,
            domain,
            UniformIntegration();
            k_mesh = ntuple(_->32, d),
        )
        @test isapprox(uniform.value, expected; rtol = 1e-3, atol = 0)
        limited=@test_logs (:warn, r"Adaptive integral stopped") integrate_response(
            x->exp(10sum(x)),
            domain,
            HAdaptiveCubature(atol = 0, rtol = 1e-14, max_evaluations = rule+1),
        )
        @test limited.evaluations==3rule
        @test limited.termination==:evaluation_budget
        @test !limited.estimate_converged
        @test limited.evaluations-(rule+1)<=2rule-1
        @test isfinite(limited.value)
        point=zeros(3)
        fractional=IntegrationDomain(; lower, upper)
        R.response_integration_kpoint!(
            point,
            midpoint,
            fractional,
            (lattice = Matrix{Float64}(I, 3, 3),),
        )
        @test point[1:d]==collect(midpoint)
        @test all(iszero, point[(d + 1):3])
        R.response_integration_kpoint!(
            point,
            midpoint,
            domain,
            (lattice = 2Matrix{Float64}(I, 3, 3),),
        )
        @test point[1:d]≈collect(midpoint) ./ pi
        @test all(iszero, point[(d + 1):3])
    end
end

@testset "Explicit finite-domain left endpoints preserve the domain and weights" begin
    @test R.integration_algorithm_summary(UniformIntegration()) == (algorithm = "uniform",)
    endpoint = UniformIntegration(region_quadrature = :left_endpoint)
    @test R.integration_algorithm_summary(endpoint).region_quadrature == "left_endpoint"
    for invalid in (:right_endpoint, :trapezoidal, "left_endpoint", true, 0.5)
        @test_throws ArgumentError UniformIntegration(region_quadrature = invalid)
    end
    expected_nodes = [(-1.0, 2.0), (1.0, 2.0), (-1.0, 3.0), (1.0, 3.0), (-1.0, 4.0), (1.0, 4.0)]
    for coordinates in (:cartesian, :fractional)
        domain =
            IntegrationDomain(lower = (-1.0, 2.0), upper = (3.0, 5.0), coordinates = coordinates)
        observed = Tuple{Float64, Float64}[]
        result =
            integrate_response(domain, endpoint; normalization = :integral, k_mesh = (2, 3)) do node
                push!(observed, node)
                node[1]+2node[2]
            end
        @test observed == expected_nodes
        @test result.value == 72.0
        @test result.domain_measure == 12.0
        @test result.evaluations == 6
        @test result.embedded_estimate === nothing
        constant = integrate_response(
            _ -> 2+3im,
            domain,
            endpoint;
            normalization = :integral,
            k_mesh = (2, 3),
        )
        @test constant.value == 12*(2+3im)
        one_node = Tuple{Float64, Float64}[]
        integrate_response(domain, endpoint; k_mesh = (1, 1)) do node
            push!(one_node, node)
            1.0
        end
        @test one_node == [domain.lower]
    end
end

@testset "Batched rules retain the dependency tree and every arithmetic result" begin
    # Positional construction can bypass the public keyword constructor. Retain
    # the dependency's validation before any physical point is evaluated.
    for invalid in (HAdaptiveCubature(0.0, -1.0, 200, 1), HAdaptiveCubature(1e-12, 1e-6, 200, -1))
        visits = Ref(0)
        value = node -> (visits[] += 1; 1.0)
        domain = IntegrationDomain{2}()
        @test_throws ArgumentError integrate_response(value, domain, invalid)
        @test_throws ArgumentError integrate_response(
            value,
            domain,
            invalid;
            batch_evaluator = nodes -> value.(nodes),
        )
        @test visits[] == 0
    end
    for dimension in 1:3,
        divisions in (1, 2),
        normalization in (:integral, :domain_average),
        additional_rules in (0, 8)

        domain = IntegrationDomain{dimension}(
            lower = ntuple(_ -> -0.2, dimension),
            upper = ntuple(_ -> 0.9, dimension),
        )
        rule_nodes = (15, 17, 33)[dimension]
        algorithm = HAdaptiveCubature(
            atol = 0.0,
            rtol = 1e-12,
            max_evaluations = rule_nodes * divisions^dimension +
                              (additional_rules == 0 ? 1 : additional_rules * rule_nodes),
            initial_divisions = divisions,
        )
        serial_nodes = Tuple[]
        batch_nodes = Tuple[]
        value =
            node -> reshape(
                ComplexF64[exp(3sum(node)) + im * cos(5node[1]), 1e-9 * sin(sum(node))],
                2,
                1,
            )
        serial = integrate_response(domain, algorithm; normalization) do node
            push!(serial_nodes, Tuple(node))
            value(node)
        end
        batch = nodes -> [
            begin
                push!(batch_nodes, Tuple(node))
                value(node)
            end for node in nodes
        ]
        actual =
            integrate_response(value, domain, algorithm; normalization, batch_evaluator = batch)
        @test batch_nodes == serial_nodes
        for field in fieldnames(typeof(serial))
            @test getfield(actual, field) == getfield(serial, field)
        end
    end
end

@testset "Owned point collection and coordinate mapping share one worker kernel" begin
    scratch = zeros(ComplexF64, 2)
    point_value! = (worker, point) -> begin
        scratch[1] = worker * point[1] + im * point[2]
        scratch[2] = point[3]
        scratch
    end
    evaluator = R.ResponsePointEvaluator(
        point_value!,
        1,
        (shape = (2,), prefactor = :test_density, arbitrary_k = true),
    )
    points = [[0.1, 0.2, 0.3], [0.4, 0.5, 0.6]]
    collected = R.collect_response_points(evaluator, points)
    @test collected == [ComplexF64[0.1 + 0.2im, 0.3], [0.4 + 0.5im, 0.6]]
    @test collected[1] !== scratch && collected[2] !== scratch
    node = R.ResponseNodeEvaluator(evaluator, IntegrationDomain{3}(), nothing)
    @test node(points[1]) == collected[1]
    fill!(scratch, 0)
    @test collected[1] == ComplexF64[0.1 + 0.2im, 0.3]
end

@testset "Existing adaptive response plans expose arbitrary-k values" begin
    lattice = 3Matrix{Float64}(I, 3, 3)
    translations = [0 1 -1; 0 0 0; 0 0 0]
    hopping = zeros(ComplexF64, 3, 3, 3)
    hopping[:, :, 1] = [-1.4 0.2 0.1im; 0.2 0.3 0.15; -0.1im 0.15 1.6]
    hopping[:, :, 2] = [0.03 0.02im 0.01; 0.01 0.02 0.03im; 0.01im 0.02 0.01]
    hopping[:, :, 3] = hopping[:, :, 2]'
    model = RealSpaceTBInput(
        lattice = lattice,
        r_vectors = translations,
        hamiltonian_r = hopping,
        orbital_positions = [0.0 0.2 0.4; 0.0 0.1 0.2; 0.0 0.3 0.1],
        position_model = :point_orbitals,
    )
    for quantity in ("SC", "IC", "SHG", "THG", "BCDC", "BCQC")
        physics =
            quantity == "SHG" ?
            SHGParameters(photon_energies = [0.73, 1.2], fermi_energy = 0.0, temperature = 300.0) :
            quantity == "THG" ?
            THGParameters(photon_energies = [0.73, 1.2], fermi_energy = 0.0, temperature = 300.0) :
            quantity in ("BCDC", "BCQC") ?
            BerryMultipoleParameters(
                fermi_energies = Float64[0.0],
                temperature = 300.0,
                relaxation_time_fs = 7.0,
                integral_form = :fermi_surface,
            ) :
            OpticalParameters(
                photon_energies = [0.73, 1.2],
                fermi_energy = 0.0,
                temperature = 300.0,
            )
        observable =
            quantity in ("THG", "BCQC") ? TensorComponents(TensorComponent(1, 1, 1, 1)) :
            quantity == "BCDC" ? TensorComponents(TensorComponent(1, 2, 1)) : FullTensor()
        config = TaskConfig(
            model = model,
            sampling = KRegion(
                lower = (0.1, 0.2, 0.3),
                upper = (0.2, 0.3, 0.4),
                k_mesh = (2, 2, 2),
            ),
            tasks = [
                TaskSpec(
                    id = lowercase(quantity),
                    quantity = quantity,
                    method = "Conventional",
                    physics = physics,
                    observable = observable,
                ),
            ],
            execution = ExecutionOptions(
                fourier_backend = "direct",
                integration_algorithm = HAdaptiveCubature(max_evaluations = 33),
            ),
            output = OutputOptions(output_root = mktempdir(), progress_enabled = false),
        )
        effective = R.compile_task_config(config, only(config.tasks))
        specs = R.validate_config(effective)
        context = R.prepare_run_context(effective, specs)
        plan = R.make_bundle_plan(effective, specs)
        prepared = R._run_integral_bundle_fused!(
            effective,
            context,
            specs,
            plan.controls;
            prepare_only = true,
        )
        try
            evaluator = first(prepared.point_evaluators)
            points = [[0.11, 0.22, 0.33], [0.14, 0.25, 0.36]]
            values = R.collect_response_points(evaluator, points)
            @test size(first(values)) == evaluator.value_contract.shape
            @test all(value -> all(isfinite, value), values)
            node = R.ResponseNodeEvaluator(evaluator, IntegrationDomain{3}(), nothing)
            @test node(first(points)) == first(values)
            @test values[1] !== values[2]
        finally
            prepared.cleanup!()
        end
    end
end
end
