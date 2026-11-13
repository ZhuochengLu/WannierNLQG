using Test, WannierNLQG, HDF5, JSON3
include(joinpath(@__DIR__, "OperatorTaskSelectionTestSupport.jl"))
include(joinpath(@__DIR__, "FrozenGramOperatorTestSupport.jl"))
root, permutation = ARGS
mkpath(root)
fixture = frozen_gram_operator_fixture(root; neighbor_permutation = Symbol(permutation))
for kind in (
    OTS_C.REAL_SPACE_DERIVATIVE_OVERLAP_TENSOR,
    OTS_C.REAL_SPACE_HAMILTONIAN_WEIGHTED_AXIAL_DERIVATIVE_OVERLAP,
)
    @test maximum(abs, fixture.operators[kind].data)>1e-8
end
# Source/metadata marker negatives belong to the independent real-source fixture.
# Do not apply them to this numerical oracle or manufacture qualification records.
empty!(ARGS)
append!(ARGS, [fixture.output, joinpath(root, "responses"), fixture.geometry_output])
include(joinpath(@__DIR__, "FrozenGramResponseProbe.jl"))
println("NEIGHBOR_FRESH_CONSTRUCT_WRITE_READ_RESPONSE_PASS")
