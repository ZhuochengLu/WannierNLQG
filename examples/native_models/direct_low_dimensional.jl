include(joinpath(@__DIR__, "NativeExampleSupport.jl"))

"""A physical one-dimensional band; k contains one Cartesian coordinate in A^-1."""
direct_line_hamiltonian(k, parameters) = reshape([parameters.curvature * k[1]^2], 1, 1)

"""Build a direct 1D model without an auxiliary lattice vector or dimension flag."""
function build_direct_line()
    return AnalyticKInput(
        hamiltonian = direct_line_hamiltonian,
        num_orbitals = 1,
        lattice = reshape([2.0], 1, 1),
        basis = :fixed_orthonormal,
        periodic = false,
        parameters = (curvature = 1.0,),
        evaluation_bounds = ((-0.4,), (0.4,)),
        source_file = @__FILE__
    )
end

"""Return a bounded small-model transport example, not a convergence prescription."""
function build_config(; smoke = false, output_root = joinpath(tempdir(), "direct-line-demo"))
    return TaskConfig(
        model = build_direct_line(),
        sampling = KRegion(lower = (-0.2,), upper = (0.2,), k_mesh = (smoke ? 3 : 101,)),
        tasks = [
            TaskSpec(
                id = "line",
                quantity = "LT",
                method = "Conventional",
                physics = LinearTransportParameters(
                    fermi_energies = [0.01],
                    temperature = 300.0,
                    relaxation = SeparateRelaxation(gamma_intra_ev = 0.05, gamma_inter_ev = 0.06),
                ),
            ),
        ],
        execution = ExecutionOptions(fourier_backend = "direct"),
        output = OutputOptions(output_root = output_root, progress_enabled = false),
    )
end

abspath(PROGRAM_FILE) == abspath(@__FILE__) &&
    WannierNLQG.run(build_config(smoke = "--smoke" in ARGS))
