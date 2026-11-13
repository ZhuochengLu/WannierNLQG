module NonperiodicParallelepipedExample
using WannierNLQG, LinearAlgebra
hamiltonian(k, parameters) = begin
    x, y, z=k
    d1=0.8+0.3x+0.2y+0.12x*y+0.04y*z
    d2=0.25y+0.11x^2+0.12z
    d3=0.45+0.1x-0.08y^2+0.07z
    scalar=0.13x+0.07y+0.015z
    [scalar+d3 d1-im*d2; d1+im*d2 scalar-d3]
end
build_model() = AnalyticKInput(;
    hamiltonian,
    num_orbitals = 2,
    lattice = Matrix{Float64}(I, 3, 3)*2,
    orbital_positions = zeros(3, 2),
    periodic = false,
    derivative_method = :automatic,
    evaluation_bounds = ((-10.0, -10.0, -2.0), (10.0, 10.0, 2.0)),
    source_file = @__FILE__
)
function build_config(output_root)
    region=KRegion(;
        origin = (4.0, 0.2, 0.1),
        vector_1 = (0.4, 0.08, 0.02),
        vector_2 = (0.12, 0.36, -0.01),
        vector_3 = (0.03, 0.02, 0.2),
        k_mesh = (4, 4, 4),
    )
    task=TaskSpec(;
        id = "pdsc",
        quantity = "PDSC",
        method = "Geometric_Loop",
        physics = FiniteQOpticalParameters(;
            photon_energies = [5.8, 6.4],
            fermi_energy = 0.0,
            temperature = 0.0,
            photon_momentum = (0.06, -0.04, 0.02),
        ),
        numerics = Numerics(; broadening = 0.25),
        observable = FullTensor(),
    )
    TaskConfig(;
        model = build_model(),
        sampling = region,
        tasks = [task],
        execution = ExecutionOptions(; fourier_backend = "direct"),
        output = OutputOptions(;
            output_root,
            progress_enabled = false,
            response_output_digits = 17,
        ),
    )
end
end
