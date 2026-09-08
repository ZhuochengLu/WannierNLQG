module SymmetrizationExampleSupport

using WannierNLQG

export example_input, example_output_root, example_summary

const EXAMPLE_ROOT = @__DIR__
const FIXTURE_INPUT_ROOT = joinpath(EXAMPLE_ROOT, "fixture", "inputs")
const DEFAULT_OUTPUT_ROOT = joinpath(tempdir(), "wanniernlqg-symmetrization-examples", "v1.0.0")

example_input(name::AbstractString) = joinpath(FIXTURE_INPUT_ROOT, "synthetic" * name)

function example_output_root(name::AbstractString)
    root =
        normpath(abspath(get(ENV, "WANNIERNLQG_SYMMETRIZATION_OUTPUT_ROOT", DEFAULT_OUTPUT_ROOT)))
    output = joinpath(root, name)
    mkpath(output)
    return output
end

function example_summary(name::AbstractString, result)
    operators = WannierNLQG.Core.real_space_operator_name.(result.operator_inventory)
    println(
        "EXAMPLE_PASS name=$(name) profile=$(result.operator_profile) " *
        "operators=$(join(operators, ',')) output_tb=$(result.output_tb) " *
        "bundle=$(result.real_space_operator_bundle)",
    )
    return nothing
end

end
