module ParallelepipedRegionFixture
using WannierNLQG, LinearAlgebra
include("ParallelogramRegionFixture.jl")
const Shared = ParallelogramRegionFixture
const MOMENTUM = (0.06, -0.04, 0.02)

"""Add smooth nontrivial third-direction dependence to the shared finite two-band fixture."""
function hamiltonian(k, parameters)
    base = Shared.hamiltonian(k, parameters)
    x, y, z = k
    offdiagonal = 0.04y*z - im*0.12z
    return base + [0.09z + 0.03x*z offdiagonal; conj(offdiagonal) -0.06z]
end
function model(; derivative_method = :automatic)
    return AnalyticKInput(;
        hamiltonian,
        num_orbitals = 2,
        lattice = Matrix{Float64}(I, 3, 3)*2,
        orbital_positions = zeros(3, 2),
        periodic = false,
        derivative_method,
        finite_difference_step = 1e-3,
        evaluation_bounds = ((-10.0, -10.0, -2.0), (10.0, 10.0, 2.0)),
        source_file = @__FILE__
    )
end
region(n) = KRegion(;
    origin = (4.0, 0.2, 0.1),
    vector_1 = (0.4, 0.08, 0.02),
    vector_2 = (0.12, 0.36, -0.01),
    vector_3 = (0.03, 0.02, 0.2),
    k_mesh = (n, n, n),
)
function config(
    sampling,
    destination;
    derivative_method = :automatic,
    quantities = ("SC", "IC", "PDSC", "PDIC"),
    system_name = nothing,
)
    return Shared.config(
        sampling,
        destination;
        quantities,
        system_name,
        derivative_method,
        model_input = model(; derivative_method),
        photon_momentum = MOMENTUM,
    )
end
const tensors = Shared.tensors
const tensor_records = Shared.tensor_records
const evidence = Shared.evidence
const retain_result = Shared.retain_result
end
