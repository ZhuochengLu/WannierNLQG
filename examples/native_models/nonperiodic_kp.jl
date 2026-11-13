include(joinpath(@__DIR__, "NativeExampleSupport.jl"))

"""A nonperiodic two-band polynomial model in Cartesian inverse Angstrom."""
function hamiltonian(k, p)
    dx=p.gap+p.beta*k[1]^2
    dy=p.velocity*k[1]
    dz=p.mass+p.tilt*k[1]
    return [dz dx-im*dy; dx+im*dy -dz]
end

"""Keep the integration cutoff separate from the larger allowed evaluation box."""
function build_model()
    return AnalyticKInput(
        hamiltonian = hamiltonian,
        num_orbitals = 2,
        lattice = Matrix{Float64}(I, 3, 3),
        orbital_positions = zeros(3, 2),
        periodic = false,
        parameters = (gap = 0.4, beta = 0.2, velocity = 0.7, mass = 0.2, tilt = 0.1),
        evaluation_bounds = ((-2.0, -2.0, -2.0), (2.0, 2.0, 2.0)),
        source_file = @__FILE__
    )
end

"""Return a one-dimensional finite-region task; vary mesh and cutoff separately."""
function build_config(;
    smoke = false,
    cutoff = 1.0,
    output_root = joinpath(tempdir(), "analytic-kp-demo"),
)
    box=KRegion(lower = (-cutoff,), upper = (cutoff,), k_mesh = (smoke ? 2 : 201,))
    return shift_config(build_model(), box, output_root)
end

if abspath(PROGRAM_FILE)==abspath(@__FILE__)
    WannierNLQG.run(build_config(smoke = "--smoke" in ARGS))
end
