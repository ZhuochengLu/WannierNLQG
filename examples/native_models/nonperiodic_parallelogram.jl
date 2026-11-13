include(joinpath(@__DIR__, "NativeExampleSupport.jl"))

"""A small Cartesian continuum Hamiltonian; it has no assumed reciprocal periodicity."""
function hamiltonian(k, parameters)
    x, y = k[1], k[2]
    scalar = 0.13x + 0.07y
    dx = 0.8 + 0.3x + 0.2y + 0.12x*y
    dy = 0.25y + 0.11x^2
    dz = 0.45 + 0.1x - 0.08y^2
    return [scalar + dz dx - im*dy; dx + im*dy scalar - dz]
end

"""Declare the full evaluation domain separately from the parallelogram integration region."""
function build_model(; derivative_method = :automatic)
    return AnalyticKInput(;
        hamiltonian,
        num_orbitals = 2,
        lattice = Matrix{Float64}(I, 3, 3)*2,
        orbital_positions = zeros(3, 2),
        periodic = false,
        derivative_method,
        finite_difference_step = 1e-3,
        evaluation_bounds = ((-10.0, -10.0, -2.0), (10.0, 10.0, 2.0)),
        source_file = @__FILE__,
    )
end

"""Return finite-q public tasks on a tiny diagnostic region, without running on import."""
function build_config(; smoke = false, output_root = joinpath(tempdir(), "parallelogram-demo"))
    n = smoke ? 2 : 8
    sampling = KRegion(;
        origin = (4.0, 0.2),
        vector_1 = (0.4, 0.08),
        vector_2 = (0.12, 0.36),
        k_mesh = (n, n),
    )
    physics = FiniteQOpticalParameters(;
        photon_energies = [5.8, 6.4],
        fermi_energy = 0.0,
        temperature = 0.0,
        photon_momentum = (0.06, -0.04, 0.0),
    )
    tasks = [
        TaskSpec(;
            id = "pdsc",
            quantity = "PDSC",
            method = "Geometric_Loop",
            physics,
            numerics = Numerics(; broadening = 0.25),
            observable = FullTensor(),
        ),
        TaskSpec(;
            id = "pdic",
            quantity = "PDIC",
            method = "Conventional",
            physics,
            numerics = Numerics(; broadening = 0.25),
            observable = FullTensor(),
        ),
    ]
    return TaskConfig(;
        model = build_model(),
        sampling,
        tasks,
        execution = ExecutionOptions(; fourier_backend = "direct"),
        output = OutputOptions(; output_root, progress_enabled = false),
    )
end

if abspath(PROGRAM_FILE) == abspath(@__FILE__)
    WannierNLQG.run(build_config(; smoke = "--smoke" in ARGS))
end
