module NativeLowDimensionalUnit
using Test, LinearAlgebra, WannierNLQG
const C = WannierNLQG.Core
const M = WannierNLQG.MatrixElements
const R = WannierNLQG.Runtime
const CALLS = Ref(0)
root_owner() = R.mpi_is_root_process()

# A physical polynomial, with no user auxiliary coordinate or derivative axis.
function polynomial(k, p)
    @assert length(k) == p
    return reshape([k[1]^3 + (p == 2 ? 2k[2]^2 : zero(k[1]))], 1, 1)
end

# The explicit jets independently specify every physical derivative index.
function polynomial_jet(k, d, order)
    out = zeros(Float64, 1, 1, ntuple(_ -> d, order)...)
    order == 1 && (out[1, 1, 1] = 3k[1]^2)
    order == 1 && d == 2 && (out[1, 1, 2] = 4k[2])
    order == 2 && (out[1, 1, 1, 1] = 6k[1])
    order == 2 && d == 2 && (out[1, 1, 2, 2] = 4)
    order == 3 && (out[1, 1, 1, 1, 1] = 6)
    return out
end

@testset "Direct physical inputs, exact auxiliary convention and Cartesian jets" begin
    for d in (1, 2), method in (:automatic, :explicit, :finite_difference)
        physical = d == 1 ? reshape([2.0], 1, 1) : [2.0 0.2; 0.0 3.0]
        callbacks =
            method == :explicit ? Tuple((k, p) -> polynomial_jet(k, p, order) for order in 1:3) :
            (nothing, nothing, nothing)
        input = AnalyticKInput(
            hamiltonian = polynomial,
            num_orbitals = 1,
            lattice = physical,
            basis = :fixed_orthonormal,
            periodic = false,
            parameters = d,
            derivatives = callbacks,
            derivative_method = method,
            finite_difference_step = 1e-4,
            evaluation_bounds = (ntuple(_ -> -0.2, d), ntuple(_ -> 0.2, d)),
            source_file = @__FILE__
        )
        @test C.native_physical_dimension(input) == d
        @test input.lattice[1:d, 1:d] == physical
        @test input.lattice[(d + 1):3, (d + 1):3] == Matrix{Float64}(I, 3-d, 3-d)
        @test input.periodic === false
        @test size(M.analytic_hamiltonian(input, zeros(3))) == (1, 1)
        @test_throws DomainError M.analytic_hamiltonian(input, [0.3, 0.0, 0.0])
        for order in 1:3
            actual = M.analytic_hamiltonian_derivative(input, zeros(3), order)
            expected = zeros(ComplexF64, 1, 1, ntuple(_ -> 3, order)...)
            view(expected,:,:,(ntuple(_ -> 1:d, order)...)) .= polynomial_jet(zeros(d), d, order)
            @test actual ≈ expected rtol = method == :finite_difference ? 1e-5 : 2e-12 atol = 1e-8
        end
        definition = sprint(io -> WannierNLQG.IO.write_native_model_definition(io, input))
        @test startswith(definition, "wanniernlqg-native-axis-aligned-lowD-v1")
    end
    legacy_h(k, p) = (@assert length(k) == 3; reshape([k[1]^2], 1, 1))
    legacy = AnalyticKInput(
        hamiltonian = legacy_h,
        num_orbitals = 1,
        lattice = Matrix{Float64}(I, 3, 3),
        basis = :fixed_orthonormal,
        periodic = false,
        source_file = @__FILE__
    )
    @test legacy.hamiltonian === legacy_h
    @test C.native_physical_dimension(legacy) == 3
    @test startswith(
        sprint(io -> WannierNLQG.IO.write_native_model_definition(io, legacy)),
        "wanniernlqg-native-model-v3-stable-types",
    )
    @test_throws ArgumentError AnalyticKInput(
        hamiltonian = legacy_h,
        num_orbitals = 1,
        lattice = ones(2, 3),
        basis = :fixed_orthonormal,
        source_file = @__FILE__
    )
    spin = cat(ComplexF64[0 1; 1 0], ComplexF64[0 -im; im 0], ComplexF64[1 0; 0 -1]; dims = 3)
    spinful = AnalyticKInput(
        hamiltonian = (k, p) -> [1.0 k[1]; k[1] -1.0],
        num_orbitals = 2,
        lattice = reshape([2.0], 1, 1),
        orbital_positions = zeros(1, 2),
        operators = (; spin),
        periodic = false,
        source_file = @__FILE__
    )
    @test size(spinful.operators.spin) == (2, 2, 3)
    @test spinful.operators.spin == spin
    unresolved = AnalyticKInput(
        hamiltonian = polynomial,
        num_orbitals = 1,
        lattice = reshape([2.0], 1, 1),
        basis = :fixed_orthonormal,
        parameters = 1,
        periodic = false,
        derivative_method = :finite_difference,
        source_file = @__FILE__
    )
    @test_throws ArgumentError M.analytic_hamiltonian_derivative(unresolved, zeros(3), 1)
end

line_h(k, p) = reshape([k[1]^2], 1, 1)
plane_h(k, p) = [one(k[1]) k[1]-im*k[2]; k[1]+im*k[2] -one(k[1])]

# Preserve the complete old3x3 callback path for a finite-domain numerical reference.
function analytic_input(d; legacy = false)
    h = d == 1 ? line_h : plane_h
    physical = d == 1 ? reshape([2.0], 1, 1) : [2.0 0.2; 0.0 3.0]
    lattice = legacy ? first(C.complete_native_reference_lattice(physical)) : physical
    callback = legacy ? ((k, p) -> h(view(k, 1:d), p)) : h
    return AnalyticKInput(
        hamiltonian = callback,
        num_orbitals = d == 1 ? 1 : 2,
        lattice = lattice,
        basis = :fixed_orthonormal,
        periodic = false,
        source_file = @__FILE__
    )
end

# Use the same retained physical parameters and outputs for every consumer.
function configuration(input, quantity, sampling; adaptive = false, backend = "direct")
    physics =
        quantity == "LT" ?
        LinearTransportParameters(
            fermi_energies = [0.01],
            temperature = 300.0,
            relaxation = SeparateRelaxation(gamma_intra_ev = 0.05, gamma_inter_ev = 0.06),
        ) :
        quantity == "AHC" ? IntrinsicHallParameters(fermi_energies = [0.0]) :
        quantity == "OM" ?
        OrbitalMagnetizationParameters(
            fermi_energies = [-0.8],
            temperature = 300.0,
            input_semantics = :defined_finite_model,
        ) :
        quantity in ("BCDC", "BCQC") ?
        BerryMultipoleParameters(
            fermi_energies = [-0.8],
            temperature = 300.0,
            relaxation_time_fs = 7.0,
            integral_form = :fermi_sea,
        ) : THGParameters(photon_energies = [0.73], fermi_energy = 0.0, temperature = 300.0)
    component =
        quantity in ("LT", "AHC") ? (1, quantity == "AHC" ? 2 : 1) :
        quantity == "OM" ? (3,) : quantity == "BCDC" ? (2, 3, 1) : (2, 3, 3, 1)
    observable =
        sampling isa KSlice ?
        KSliceSelection(component = TensorComponent(component...), bands = BandSelection()) :
        quantity in ("BCDC", "BCQC") ? TensorComponents(TensorComponent(component...)) :
        quantity == "THG" ? TensorComponents(TensorComponent(1, 1, 1, 1)) : FullTensor()
    d = sampling isa KRegion ? sampling.spatial_dimension : length(sampling.k_mesh)
    algorithm =
        adaptive ? HAdaptiveCubature(atol = 0.0, rtol = 1e-12, max_evaluations = d == 1 ? 15 : 17) :
        UniformIntegration()
    return TaskConfig(
        model = input,
        sampling = sampling,
        tasks = [
            TaskSpec(
                id = "physical",
                quantity = R.canonical_quantity_name(R.normalize_quantity(quantity)),
                method = "Conventional",
                physics = physics,
                observable = observable,
            ),
        ],
        execution = ExecutionOptions(
            fourier_backend = backend,
            integration_algorithm = algorithm,
            NKFFT = backend == "mixed" ? sampling.k_mesh : nothing,
        ),
        output = OutputOptions(
            output_root = mktempdir(),
            progress_enabled = false,
            response_output_digits = 17,
        ),
    )
end
compute(cfg) = (CALLS[] += 1; WannierNLQG.run(cfg))
rows(path) = [
    parse.(Float64, split(line)) for
    line in eachline(path) if !isempty(strip(line)) && !startswith(strip(line), "#")
]
total_path(result, quantity) = only(
    filter(
        p -> endswith(p, quantity in ("BCDC", "BCQC") ? "_conductivity.dat" : "_total.dat"),
        result.outputs,
    ),
)

@testset "New continuum bulk convention versus unchanged intrinsic legacy path" begin
    plane_reference = Ref{Any}(nothing)
    for d in (1, 2), adaptive in (false, true)
        region = KRegion(
            lower = ntuple(_ -> -0.1, d),
            upper = ntuple(_ -> 0.1, d),
            k_mesh = ntuple(_ -> 2, d),
        )
        fresh = compute(configuration(analytic_input(d), "LT", region; adaptive))
        d == 2 && !adaptive && (plane_reference[] = fresh)
        old = compute(configuration(analytic_input(d; legacy = true), "LT", region; adaptive))
        if root_owner()
            a, b = rows(total_path(fresh, "LT")), rows(total_path(old, "LT"))
            @test first(a)[1] == first(b)[1]
            @test first(a)[2:end] ≈ first(b)[2:end] ./ 1e-10^(3-d) rtol = 2e-12 atol = 0
            @test any(!iszero, first(a)[2:end])
            @test !occursin("*m^", read(total_path(fresh, "LT"), String))
            @test occursin(
                "[NativePhysicalGeometry]",
                read(only(fresh.task_results).metadata_path, String),
            )
        end
    end
    model = analytic_input(2)
    origin = C.reciprocal_cartesian_to_fractional([-0.05, -0.05, 0.0], model.lattice)
    first_vector = C.reciprocal_cartesian_to_fractional([0.2, 0.0, 0.0], model.lattice)
    second_vector = C.reciprocal_cartesian_to_fractional([0.0, 0.2, 0.0], model.lattice)
    sampled = compute(
        configuration(
            model,
            "LT",
            KSlice(
                k_mesh = (2, 2),
                spatial_dimension = 2,
                origin = origin[1:2],
                vector_1 = first_vector[1:2],
                vector_2 = second_vector[1:2],
            ),
        ),
    )
    if root_owner()
        density = sum(row[4] + im*row[5] for row in rows(total_path(sampled, "LT"))) / 4
        integrated = only(rows(total_path(plane_reference[], "LT")))
        @test density * (0.2 * 0.2) / (2pi)^2 * 1e30 ≈ integrated[2] + im*integrated[3] rtol = 2e-12 atol =
            1e-28
    end
end

@testset "Physical 2D native slices retain Hall and normal orbital components" begin
    base = Main.spectral_test_model()
    selected = findall(i -> iszero(base.r_vectors[3, i]), 1:base.num_r_vectors)
    lattice = base.lattice[1:2, 1:2]
    centers = hcat([real.(diag(base.position_r[:, :, a, 1])) for a in 1:2]...)'
    fresh = RealSpaceTBInput(
        lattice = lattice,
        r_vectors = base.r_vectors[1:2, selected],
        hamiltonian_r = base.hamiltonian_r[:, :, selected],
        orbital_positions = centers,
    )
    legacy = RealSpaceTBInput(
        lattice = fresh.model.lattice,
        r_vectors = fresh.model.r_vectors,
        hamiltonian_r = fresh.model.hamiltonian_r,
        orbital_positions = vcat(centers, zeros(1, 2)),
    )
    @test fresh.physical_dimension == 2
    @test_throws ArgumentError R.write_native_response_symmetry(tempname(), fresh, [])
    off_plane = TaskConfig(
        model = fresh,
        sampling = BZMesh(k_mesh = (2, 2)),
        tasks = [
            TaskSpec(
                id = "off_plane",
                quantity = "PDSC",
                method = "Geometric_Loop",
                physics = FiniteQOpticalParameters(
                    photon_energies = [1.0],
                    fermi_energy = 0.0,
                    temperature = 300.0,
                    photon_momentum = (0.0, 0.0, 0.1),
                ),
            ),
        ],
        execution = ExecutionOptions(fourier_backend = "direct"),
        output = OutputOptions(output_root = mktempdir(), progress_enabled = false),
    )
    @test_throws ArgumentError R.compile_task_configs(off_plane)
    plane(mesh) = KSlice(
        k_mesh = mesh,
        spatial_dimension = 2,
        origin = (0.0, 0.0),
        vector_1 = (1.0, 0.0),
        vector_2 = (0.0, 1.0),
    )
    hall_rows = Ref{Any}(nothing)
    for quantity in ("OM", "AHC", "BCDC", "BCQC")
        a = compute(configuration(fresh, quantity, BZMesh(k_mesh = (3, 3))))
        oldmesh = quantity in ("BCDC", "BCQC") ? (3, 3) : (3, 3, 1)
        b = compute(
            configuration(legacy, quantity, BZMesh(k_mesh = oldmesh, spatial_dimension = 3)),
        )
        sampled = compute(configuration(fresh, quantity, plane((3, 3))))
        if root_owner()
            quantity == "AHC" && (hall_rows[] = rows(total_path(sampled, quantity)))
            ar, br = only(rows(total_path(a, quantity))), only(rows(total_path(b, quantity)))
            if quantity in ("BCDC", "BCQC")
                @test last(ar) ≈ last(br) / 1e-10 rtol = 2e-12 atol = 0
                local_values = last.(rows(total_path(sampled, quantity)))
                @test sum(local_values) / 9 / (det(fresh.model.lattice)*1e-30) ≈ last(ar) rtol =
                    2e-12 atol = 1e-28
            else
                @test ar ≈ br rtol = 2e-12 atol = 0
                sr = rows(total_path(sampled, quantity))
                local_value = sum(row[4] + im*row[5] for row in sr) / 9
                expected = quantity == "OM" ? ar[6] + im*ar[7] : ar[4] + im*ar[5]
                @test local_value / (quantity == "OM" ? 1.0 : det(fresh.model.lattice)*1e-30) ≈
                      expected rtol = 2e-12 atol = 1e-28
            end
        end
    end
    mixed = compute(configuration(fresh, "AHC", plane((3, 3)); backend = "mixed"))
    root_owner() &&
        @test reduce(hcat, rows(total_path(mixed, "AHC"))) ≈ reduce(hcat, hall_rows[]) rtol = 2e-12 atol =
            1e-28
end

# An explicit connection tests component axes independently of derivative order.
function connection_jet(k, p, order)
    out = zeros(promote_type(ComplexF64, eltype(k)), 1, 1, ntuple(_ -> 2, order + 1)...)
    coefficient = (1, 3, 6, 6)[order + 1]
    out[1, 1, 2, ntuple(_ -> 1, order)...] = coefficient * k[1]^(3-order)
    return out
end

@testset "Low-dimensional operator axes and Julia-payload text resolution" begin
    ops = (
        position = (k, p) -> connection_jet(k, p, 0),
        position_derivative = (k, p) -> connection_jet(k, p, 1),
        position_second_derivative = (k, p) -> connection_jet(k, p, 2),
        position_third_derivative = (k, p) -> connection_jet(k, p, 3),
    )
    input = AnalyticKInput(
        hamiltonian = (k, p) -> reshape([k[1]^2+k[2]^2], 1, 1),
        num_orbitals = 1,
        lattice = Matrix{Float64}(I, 2, 2),
        periodic = false,
        basis = :explicit,
        operators = ops,
        source_file = @__FILE__
    )
    for (order, name) in enumerate(keys(ops))
        value = getproperty(input.operators, name)([0.1, 0.2, 0.0], NamedTuple())
        @test size(value) == (1, 1, ntuple(_ -> 3, order)...)
        @test view(value,:,:,(ntuple(_ -> 1:2, order)...)) ==
              connection_jet([0.1, 0.2], nothing, order - 1)
        @test all(iszero, selectdim(value, 3, 3))
    end
    model = analytic_input(1)
    document = Dict(
        "model" => Dict("source" => "julia", "identity" => "direct-line-unit"),
        "response" => Dict(
            "fermi_energies_ev" => [0.01],
            "temperature_k" => 300.0,
            "relaxation" => Dict("gamma_intra_ev" => 0.05, "gamma_inter_ev" => 0.06),
            "sampling" => Dict(
                "kind" => "k_region",
                "lower" => [-0.1],
                "upper" => [0.1],
                "k_mesh" => [2],
                "spatial_dimension" => 1,
            ),
            "execution" => Dict("fourier_backend" => "direct"),
            "tasks" => Dict("line" => Dict("kind" => "LT", "method" => "Conventional")),
        ),
        "output" => Dict("output_root" => mktempdir(), "progress_enabled" => false),
    )
    resolved = resolve_task_input(document; model)
    @test isempty(resolved.pending)
    @test resolved.metadata["model_replay"] == "REQUIRES_JULIA_MODEL_ENTRY_NOT_FILE_REPLAYABLE"
    @test resolved.metadata["native_physical_geometry"]["physical_dimension"] == 1
    effective = only(R.compile_task_configs(resolved.config))
    @test R.integration_dimension(effective) == 1
    @test R.integration_output_dimension(effective) == 3
    @test_throws ArgumentError configuration(model, "LT", BZMesh(k_mesh = (2,))) |>
                               R.compile_task_configs
end
end
