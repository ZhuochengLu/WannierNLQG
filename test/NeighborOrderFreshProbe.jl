using Test, WannierNLQG, HDF5, JSON3
include(joinpath(@__DIR__, "OperatorTaskSelectionTestSupport.jl"))
root, permutation = ARGS
mkpath(root)
fixture = ots_fixture(root; nonzero_neighbors = true, neighbor_permutation = Symbol(permutation))
for kind in (
    OTS_C.REAL_SPACE_DERIVATIVE_OVERLAP_TENSOR,
    OTS_C.REAL_SPACE_HAMILTONIAN_WEIGHTED_AXIAL_DERIVATIVE_OVERLAP,
)
    @test maximum(abs, fixture.operators[kind].data)>1e-8
end
include(joinpath(@__DIR__, "NeighborOrderMarkerTestSupport.jl"))
@testset "neighbor-order persisted correction evidence" begin
    neighbor_order_marker_tests(fixture, root)
end
empty!(ARGS)
append!(ARGS, [fixture.output, joinpath(root, "responses"), fixture.geometry_output])
include(joinpath(@__DIR__, "OperatorTaskSelectionProbe.jl"))
println("NEIGHBOR_FRESH_CONSTRUCT_WRITE_READ_RESPONSE_PASS")
