const EXAMPLE_ROOT = @__DIR__
const EXAMPLES = (
    "mesh.jl",
    "symmetrize_tb.jl",
    "symmetrize_derivatives.jl",
    "symmetrize_spin_only.jl",
    "symmetrize_spin_velocity.jl",
    "symmetrize_combined.jl",
)

for example in EXAMPLES
    command =
        `$(Base.julia_cmd()) --startup-file=no --project=$(normpath(joinpath(EXAMPLE_ROOT, "..", ".."))) $(joinpath(EXAMPLE_ROOT, example))`
    Base.run(command)
end
println("SYMMETRIZATION_EXAMPLES_PASS count=$(length(EXAMPLES))")
