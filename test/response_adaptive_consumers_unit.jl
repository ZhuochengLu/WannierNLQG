module ResponseAdaptiveConsumersUnit
using Test, WannierNLQG, LinearAlgebra
const R = WannierNLQG.Runtime
const CALLS = Ref(0)
root_owner() = R.mpi_is_root_process()

"""A home-cell-only diagnostic with constant physical point data and local spin.

The two orbital positions each carry an explicit spin pair. Constant H/r/spin
make the selected finite-region integrands independent of the sampled point;
uniform and adaptive quadrature must therefore recover the same density. This
checks consumer normalization and routing, not material or cutoff convergence.
"""
function constant_input()
    h = ComplexF64[
        -1.2 0.1im 0.2 0.15;
        -0.1im -0.9 0.1 -0.1im;
        0.2 0.1 0.7 0.08im;
        0.15 0.1im -0.08im 1.1
    ]
    spin = zeros(ComplexF64, 4, 4, 3)
    for offset in (0, 2)
        spin[(1:2) .+ offset, (1:2) .+ offset, 1] .= [0 1; 1 0]
        spin[(1:2) .+ offset, (1:2) .+ offset, 2] .= [0 -im; im 0]
        spin[(1:2) .+ offset, (1:2) .+ offset, 3] .= [1 0; 0 -1]
    end
    return RealSpaceTBInput(
        lattice = [3.0 0 0; 0.2 3.4 0; 0.1 0.3 4.1],
        r_vectors = zeros(Int, 3, 1),
        hamiltonian_r = reshape(h, 4, 4, 1),
        orbital_positions = [
            0.05 0.05 0.4 0.4;
            0.02 0.02 0.2 0.2;
            0.1 0.1 -0.1 -0.1
        ],
        operators = (; spin),
    )
end

# Read original spectra in their original row/column order.
function tables(result)
    return Dict(
        basename(path) => [
            parse.(Float64, split(line)) for
            line in eachline(path) if !isempty(strip(line)) && !startswith(strip(line), "#")
        ] for path in result.outputs if endswith(path, ".dat")
    )
end

# Retain all existing physics controls while changing only the integration consumer.
function config(input, quantity, method, adaptive)
    physics =
        quantity == "JC" ?
        JerkParameters(photon_energies = [0.73], fermi_energy = 0.0, temperature = 300.0) :
        quantity == "LT" ?
        LinearTransportParameters(
            fermi_energies = [0.0],
            temperature = 300.0,
            relaxation = SeparateRelaxation(gamma_intra_ev = 0.05, gamma_inter_ev = 0.06),
        ) :
        quantity == "LOR" ?
        LinearOpticalResponseParameters(
            photon_energies = [0.73],
            fermi_energy = 0.0,
            temperature = 300.0,
            relaxation = SeparateRelaxation(gamma_intra_ev = 0.05, gamma_inter_ev = 0.06),
        ) :
        quantity == "OM" ?
        OrbitalMagnetizationParameters(
            fermi_energies = [0.0],
            temperature = 300.0,
            input_semantics = :defined_finite_model,
        ) : OpticalParameters(photon_energies = [0.73], fermi_energy = 0.0, temperature = 300.0)
    observable = quantity == "JC" ? TensorComponents(TensorComponent(1, 1, 1, 1)) : FullTensor()
    return TaskConfig(
        model = input,
        sampling = KRegion(lower = (0.1, 0.2, 0.3), upper = (0.2, 0.3, 0.4), k_mesh = (2, 2, 2)),
        tasks = [
            TaskSpec(
                id = "constant",
                quantity = quantity,
                method = method,
                physics = physics,
                observable = observable,
            ),
        ],
        execution = ExecutionOptions(
            fourier_backend = "direct",
            integration_algorithm = adaptive ?
                                    HAdaptiveCubature(
                atol = 0.0,
                rtol = 1e-12,
                max_evaluations = 33,
            ) : UniformIntegration(),
        ),
        output = OutputOptions(
            output_root = mktempdir(),
            progress_enabled = false,
            response_output_digits = 17,
        ),
    )
end

# Count actual public runs for the bounded source-pinned local observer.
function compute(configuration)
    CALLS[] += 1
    return WannierNLQG.run(configuration)
end

@testset "Additional adaptive consumers integrate constant local tensors" begin
    input = constant_input()
    cases = [
        ("SC", "Projector"),
        ("SC", "Geometric_Loop"),
        ("SC", "Wilson_Loop"),
        ("ISC", "Conventional"),
        ("SSC", "Conventional"),
        ("JC", "Conventional"),
        ("LT", "Conventional"),
        ("LT", "Projector"),
        ("LOR", "Conventional"),
        ("LOR", "Projector"),
        ("OM", "Conventional"),
        ("OM", "Projector"),
    ]
    for (quantity, method) in cases
        uniform = compute(config(input, quantity, method, false))
        adaptive = compute(config(input, quantity, method, true))
        if root_owner()
            left, right = tables(uniform), tables(adaptive)
            @test keys(left) == keys(right)
            for name in keys(left)
                @test reduce(hcat, left[name]) ≈ reduce(hcat, right[name]) rtol = 2e-12 atol = 1e-28
            end
            diagnostic =
                only(filter(p -> endswith(p, "integration_diagnostics.txt"), adaptive.outputs))
            fields = Dict(Pair(split(line, '='; limit = 2)...) for line in eachline(diagnostic))
            @test parse(Int, fields["evaluations"]) == 33
            quantity == "LOR" &&
                @test any(row -> any(!iszero, row[2:end]), Iterators.flatten(values(right)))
        end
    end
end
end
