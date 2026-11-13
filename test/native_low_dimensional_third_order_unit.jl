module NativeLowDimensionalThirdOrderUnit
using Test, WannierNLQG, LinearAlgebra
const C = WannierNLQG.Core
const R = WannierNLQG.Runtime
const CALLS = Ref(0)
root_owner() = R.mpi_is_root_process()
compute(cfg) = (CALLS[] += 1; WannierNLQG.run(cfg))
tables(result) = Dict(
    basename(path) => [
        parse.(Float64, split(line)) for
        line in eachline(path) if !isempty(strip(line)) && !startswith(strip(line), "#")
    ] for path in result.outputs if endswith(path, ".dat")
)

@testset "Direct 2D JC/THG use physical 2D rules and original volume factors" begin
    base = Main.spectral_test_model()
    selected = findall(i -> iszero(base.r_vectors[3, i]), 1:base.num_r_vectors)
    centers = hcat([real.(diag(base.position_r[:, :, a, 1])) for a in 1:2]...)'
    fresh = RealSpaceTBInput(
        lattice = base.lattice[1:2, 1:2],
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
    for quantity in ("JC", "THG"), adaptive in (false, true)
        physics =
            quantity == "JC" ?
            JerkParameters(photon_energies = [4.2], fermi_energy = 0.0, temperature = 300.0) :
            THGParameters(
                photon_energies = [0.73],
                fermi_energy = 0.0,
                temperature = 300.0,
                formulation = :both,
            )
        results = [
            compute(
                TaskConfig(
                    model = model,
                    sampling = BZMesh(k_mesh = (3, 3), spatial_dimension = 3),
                    tasks = [
                        TaskSpec(
                            id = "third",
                            quantity = quantity,
                            method = "Conventional",
                            physics = physics,
                            observable = TensorComponents(TensorComponent(1, 1, 1, 1)),
                        ),
                    ],
                    execution = ExecutionOptions(
                        fourier_backend = "direct",
                        integration_algorithm = adaptive ?
                                                HAdaptiveCubature(
                            atol = 0.0,
                            rtol = 1e-12,
                            max_evaluations = 17,
                        ) : UniformIntegration(),
                    ),
                    output = OutputOptions(
                        output_root = mktempdir(),
                        progress_enabled = false,
                        response_output_digits = 17,
                    ),
                ),
            ) for model in (fresh, legacy)
        ]
        if root_owner()
            a, b = tables.(results)
            @test keys(a) == keys(b)
            for name in keys(a)
                @test reduce(hcat, a[name]) ≈ reduce(hcat, b[name]) rtol = 2e-12 atol = 1e-28
            end
            if adaptive
                diagnostic = only(
                    filter(p -> endswith(p, "integration_diagnostics.txt"), first(results).outputs),
                )
                fields = Dict(Pair(split(line, '='; limit = 2)...) for line in eachline(diagnostic))
                @test parse(Int, fields["evaluations"]) == 17
            end
        end
    end
end

spin_line(k, p) = [one(k[1])+k[1]^2 k[1]; k[1] -one(k[1])+k[1]^2]

@testset "Direct 1D spin keeps all laboratory spin components" begin
    spin = cat(ComplexF64[0 1; 1 0], ComplexF64[0 -im; im 0], ComplexF64[1 0; 0 -1]; dims = 3)
    fresh = AnalyticKInput(
        hamiltonian = spin_line,
        num_orbitals = 2,
        lattice = reshape([2.0], 1, 1),
        orbital_positions = zeros(1, 2),
        operators = (; spin),
        periodic = false,
        source_file = @__FILE__
    )
    legacy = AnalyticKInput(
        hamiltonian = (k, p) -> spin_line(view(k, 1:1), p),
        num_orbitals = 2,
        lattice = fresh.lattice,
        orbital_positions = zeros(3, 2),
        operators = (; spin),
        periodic = false,
        source_file = @__FILE__
    )
    regions = (
        KRegion(lower = (0.1,), upper = (0.2,), k_mesh = (2,)),
        KRegion(lower = (0.1, -0.05, -0.05), upper = (0.2, 0.05, 0.05), k_mesh = (2, 1, 1)),
    )
    results = [
        compute(
            TaskConfig(
                model = model,
                sampling = region,
                tasks = [
                    TaskSpec(
                        id = "spin",
                        quantity = "ISC",
                        method = "Conventional",
                        physics = OpticalParameters(
                            photon_energies = [2.0],
                            fermi_energy = 0.0,
                            temperature = 300.0,
                        ),
                    ),
                ],
                execution = ExecutionOptions(fourier_backend = "direct"),
                output = OutputOptions(
                    output_root = mktempdir(),
                    progress_enabled = false,
                    response_output_digits = 17,
                ),
            ),
        ) for (model, region) in zip((fresh, legacy), regions)
    ]
    if root_owner()
        a, b = tables.(results)
        @test keys(a) == keys(b)
        # The old3D reference integrates a flat transverse box, not inferred auxiliary axes.
        ratio = (2pi)^2 / (0.1 * 0.1)
        for name in keys(a)
            @test [row[1:2] for row in a[name]] == [row[1:2] for row in b[name]]
            @test reduce(hcat, [row[3:end] for row in a[name]]) ≈ reduce(hcat, [row[3:end] for row in b[name]]) .* ratio rtol =
                2e-12 atol = 1e-28
        end
    end
end
end
