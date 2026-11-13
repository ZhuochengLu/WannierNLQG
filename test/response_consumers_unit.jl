module ResponseConsumersUnit
using Test, LinearAlgebra, WannierNLQG
const C = WannierNLQG.Core
const R = WannierNLQG.Runtime
const M = WannierNLQG.MatrixElements
const SX = ComplexF64[0 1; 1 0]
const SY = ComplexF64[0 -im; im 0]
const SZ = ComplexF64[1 0; 0 -1]
const CASES = Ref(0)
root_owner() = R.bundle_mpi_comm_rank(R.bundle_mpi_comm_world()) == 0
rows(path) = [
    parse.(Float64, split(line)) for
    line in eachline(path) if !isempty(strip(line)) && !startswith(strip(line), "#")
]
function configuration(
    model,
    quantity,
    physics,
    component;
    method = "Conventional",
    backend = "direct",
    numerics = Numerics(),
)
    TaskConfig(
        model = model,
        sampling = KSlice(
            k_mesh = (2, 2),
            spatial_dimension = 3,
            origin = (0.021, 0.032, 0.0),
            vector_1 = (0.017, 0.0, 0.0),
            vector_2 = (0.0, 0.013, 0.0),
        ),
        tasks = [
            TaskSpec(
                id = "slice",
                quantity = quantity,
                method = method,
                physics = physics,
                numerics = numerics,
                observable = KSliceSelection(
                    component = TensorComponent(component...),
                    bands = AllBands(),
                ),
            ),
        ],
        execution = ExecutionOptions(
            fourier_backend = backend,
            NKFFT = lowercase(backend) == "mixed" ? (2, 2) : nothing,
        ),
        output = OutputOptions(
            output_root = mktempdir(),
            progress_enabled = false,
            response_output_digits = 17,
        ),
    )
end
function compute(config)
    CASES[] += 1
    return WannierNLQG.run(config)
end
hall_hamiltonian(k, p) = k[1] * SX + k[2] * SY + 1.7SZ
scalar_hamiltonian(k, p) = reshape([0.1 * (k[1]^2 + k[2]^2)], 1, 1)
function scalar_connection(k, p)
    value = zeros(promote_type(ComplexF64, eltype(k)), 1, 1, 3)
    value[1, 1, 2] = k[1]^3 / 3 + k[1]^2 / 2
    return value
end

@testset "AHC slices retain real zero-T occupation, vector mu and SI density" begin
    input = AnalyticKInput(
        hamiltonian = hall_hamiltonian,
        num_orbitals = 2,
        lattice = Matrix{Float64}(I, 3, 3),
        basis = :fixed_orthonormal,
        periodic = false,
        derivative_method = :automatic,
        source_file = @__FILE__
    )
    for method in ("Conventional", "Projector")
        result = compute(
            configuration(
                input,
                "AHCK",
                IntrinsicHallParameters(fermi_energies = [-3.0, 0.0, 3.0]),
                (1, 2);
                method,
            ),
        )
        if root_owner()
            paths = sort(filter(p -> endswith(p, ".dat"), result.outputs))
            @test length(paths) == 3
            @test length(unique(paths)) == 3
            for (mu_index, path) in enumerate(paths)
                @test occursin("S*m^2 k_integrand", read(path, String))
                @test occursin("T0-real-energy-less-than-or-equal-mu", read(path, String))
                table = rows(path)
                @test length(table) == 4
                for row in table
                    x, y = 2pi .* row[1:2]
                    curvature = mu_index == 2 ? 1.7 / (2 * (x^2 + y^2 + 1.7^2)^(3/2)) : 0.0
                    expected = -1.602176634e-19^2 / 1.054571817e-34 * 1e-20 * curvature
                    @test row[4] ≈ expected rtol = 2e-11 atol = 1e-35
                end
            end
        end
    end
    invalid = configuration(input, "AHCK", IntrinsicHallParameters(fermi_energies = [0.0]), (1, 2))
    @test R.compile_task_config(invalid, only(invalid.tasks)).temperature == 0.0
end

@testset "BCD/BCQ slice expression, component order and local SI units" begin
    input = AnalyticKInput(
        hamiltonian = scalar_hamiltonian,
        num_orbitals = 1,
        lattice = Matrix{Float64}(I, 3, 3),
        basis = :explicit,
        operators = (position = scalar_connection,),
        periodic = false,
        derivative_method = :automatic,
        source_file = @__FILE__
    )
    for quantity in ("BCDCK", "BCQCK"),
        form in (:fermi_surface, :fermi_sea),
        temperature in (0.0, 300.0)

        component = quantity == "BCDCK" ? (2, 1, 1) : (2, 1, 1, 1)
        physics = BerryMultipoleParameters(
            fermi_energies = [0.0, 0.013],
            temperature = temperature,
            relaxation_time_fs = 7.0,
            integral_form = form,
        )
        numerics =
            form == :fermi_surface && temperature == 0 ? Numerics(eta_fs_ev = 0.02) : Numerics()
        result = compute(configuration(input, quantity, physics, component; numerics))
        if root_owner()
            moment_path = only(filter(p -> endswith(p, "_moments.dat"), result.outputs))
            sigma_path = only(filter(p -> endswith(p, "_conductivity.dat"), result.outputs))
            moment_rows, sigma_rows = rows(moment_path), rows(sigma_path)
            @test length(sigma_rows) == 8
            @test occursin(
                quantity == "BCDCK" ? "A*m^3/V^2" : "A*m^4/V^3",
                read(sigma_path, String),
            )
            @test occursin(
                "integration_average_to_measure_factor=not applied",
                read(sigma_path, String),
            )
            for row in moment_rows
                x, y = 2pi .* row[1:2]
                energy, mu = 0.1 * (x^2 + y^2), row[4]
                occupation =
                    temperature > 0 ?
                    1 / (1 + exp((energy - mu) / (8.617333262145e-5 * temperature))) :
                    energy < mu ? 1.0 : energy == mu ? 0.5 : 0.0
                weight =
                    temperature > 0 ?
                    occupation * (1 - occupation) / (8.617333262145e-5 * temperature) :
                    exp(-((energy-mu)/0.02)^2) / (sqrt(pi) * 0.02)
                key = Tuple(Int.(row[7:(end - 1)]))
                a, b, c = key[1:3]
                sign = (a, b) == (1, 2) ? 1.0 : (a, b) == (2, 1) ? -1.0 : 0.0
                curvature = sign * (x^2+x)
                derivative(axis) = axis == 1 ? sign * (2x+1) : 0.0
                velocity(axis) = axis == 1 ? 0.2x : axis == 2 ? 0.2y : 0.0
                expected = if length(key) == 3
                    form == :fermi_sea ? occupation * derivative(c) : weight * curvature * velocity(c)
                else
                    d = key[4]
                    form == :fermi_sea ? occupation * ((c, d) == (1, 1) ? 2sign : 0.0) :
                    weight * (velocity(c) * derivative(d) + velocity(d) * derivative(c)) / 2
                end
                @test last(row) ≈ expected rtol = 2e-10 atol = 1e-15
            end
            for row in sigma_rows
                point, mu = row[1:3], row[4]
                getmoment(key) = last(
                    only(
                        filter(
                            x ->
                                x[1:3] == point && x[4] == mu && Tuple(Int.(x[7:(end - 1)])) == key,
                            moment_rows,
                        ),
                    ),
                )
                tau, e, hbar = 7e-15, 1.602176634e-19, 1.054571817e-34
                expected =
                    quantity == "BCDCK" ?
                    e^3*tau/(2hbar^2) * 1e-30 * (getmoment((1, 2, 1))+getmoment((1, 1, 2))) :
                    -e^4*tau^2/(3hbar^3) *
                    1e-40 *
                    (getmoment((1, 2, 1, 1))+2getmoment((1, 1, 2, 1)))
                @test last(row) ≈ expected rtol = 2e-14 atol = 1e-70
            end
        end
    end
end

@testset "Nonorthogonal finite-model OM slices use the existing physical trace" begin
    base = Main.spectral_test_model()
    path = joinpath(mktempdir(), "orthogonal.dat")
    WannierNLQG.IO.write_wannier_tb(path, base)
    reference = compute(
        configuration(
            ModelInput(model_file = path),
            "OMK",
            OrbitalMagnetizationParameters(
                fermi_energies = [0.13],
                temperature = 300.0,
                input_semantics = :defined_finite_model,
            ),
            (3,),
        ),
    )
    transform = ComplexF64[1.2 0.13; 0 0.8]
    h, p = similar(base.hamiltonian_r), similar(base.position_r)
    overlap = zeros(ComplexF64, size(h))
    for index in 1:base.num_r_vectors
        h[:, :, index] = transform' * base.hamiltonian_r[:, :, index] * transform
        for axis in 1:3
            p[:, :, axis, index] = transform' * base.position_r[:, :, axis, index] * transform
        end
        all(iszero, base.r_vectors[:, index]) && (overlap[:, :, index] = transform' * transform)
    end
    input = C.NonorthogonalLocalizedInput(
        C.NonorthogonalLocalizedModel(
            lattice = base.lattice,
            r_vectors = base.r_vectors,
            hamiltonian_r = h,
            overlap_r = overlap,
            position_r = p,
        ),
    )
    physics = OrbitalMagnetizationParameters(
        fermi_energies = [0.13],
        temperature = 300.0,
        input_semantics = :defined_finite_model,
    )
    config = configuration(input, "OMK", physics, (3,))
    result = compute(config)
    if root_owner()
        expected = Dict(basename(p) => rows(p) for p in reference.outputs if endswith(p, ".dat"))
        actual = Dict(basename(p) => rows(p) for p in result.outputs if endswith(p, ".dat"))
        @test keys(actual) == keys(expected)
        for name in keys(expected)
            @test reduce(hcat, actual[name]) ≈ reduce(hcat, expected[name]) rtol = 2e-10 atol =
                2e-13
        end
        @test !isempty(actual)
    end
    bad = configuration(input, "OMK", physics, (3,); method = "Projector")
    @test_throws ArgumentError R.compile_native_task_config(bad, only(bad.tasks))
end
end
