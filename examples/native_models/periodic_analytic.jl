include(joinpath(@__DIR__, "NativeExampleSupport.jl"))

"""Convention-II Rice-Mele matrix; generic arithmetic permits ForwardDiff."""
function hamiltonian(k, p)
    off=p.intra+p.inter*exp(-im*k[1])
    return [p.mass off; conj(off) -p.mass]
end

"""Build a periodic analytic input; derivatives are taken before diagonalization."""
function build_model()
    return AnalyticKInput(
        hamiltonian = hamiltonian,
        num_orbitals = 2,
        lattice = Matrix{Float64}(I, 3, 3),
        orbital_positions = [0.0 0.3; 0.0 0.0; 0.0 0.0],
        parameters = (mass = 0.3, intra = 1.0, inter = 0.7),
        source_file = @__FILE__
    )
end

"""Return a periodic direct-evaluation task without running it."""
function build_config(; smoke = false, output_root = joinpath(tempdir(), "analytic-periodic-demo"))
    return shift_config(
        build_model(),
        BZMesh(k_mesh = (smoke ? 2 : 101, 1), spatial_dimension = 2),
        output_root,
    )
end

if abspath(PROGRAM_FILE)==abspath(@__FILE__)
    WannierNLQG.run(build_config(smoke = "--smoke" in ARGS))
end
