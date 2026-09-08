module ExampleSupport

using WannierNLQG

const PACKAGE_ROOT = normpath(joinpath(@__DIR__, ".."))
const SYNTHETIC_FIXTURE_ROOT = joinpath(@__DIR__, "fixtures", "synthetic_runtime")
const SYNTHETIC_MODEL_FILE = joinpath(SYNTHETIC_FIXTURE_ROOT, "synthetic_tb.dat")
const SYNTHETIC_WSVEC_FILE = joinpath(SYNTHETIC_FIXTURE_ROOT, "synthetic_wsvec.dat")
const SYNTHETIC_OPERATOR_BUNDLE_FILE = joinpath(SYNTHETIC_FIXTURE_ROOT, "synthetic_operators.h5")

"""Return a task-specific output directory without allowing examples to overwrite one another."""
function example_output_root(slug::AbstractString, override)
    override === nothing || return normpath(String(override))
    base = normpath(
        get(
            ENV,
            "WANNIERNLQG_EXAMPLE_OUTPUT_ROOT",
            joinpath(tempdir(), "wanniernlqg-examples", "v1.0.0"),
        ),
    )
    return joinpath(base, String(slug))
end

"""Return the repository-owned four-orbital synthetic TB fixture."""
function synthetic_model_file()
    isfile(SYNTHETIC_MODEL_FILE) || error("Missing synthetic TB fixture: $(SYNTHETIC_MODEL_FILE)")
    return SYNTHETIC_MODEL_FILE
end

"""Return the repository-owned exact operator bundle used by advanced task examples."""
function synthetic_operator_bundle_file()
    isfile(SYNTHETIC_OPERATOR_BUNDLE_FILE) ||
        error("Missing synthetic operator bundle: $(SYNTHETIC_OPERATOR_BUNDLE_FILE)")
    return SYNTHETIC_OPERATOR_BUNDLE_FILE
end

"""Return the explicit pair-dependent minimum-distance mapping fixture."""
function synthetic_wsvec_file()
    isfile(SYNTHETIC_WSVEC_FILE) ||
        error("Missing synthetic wsvec fixture: $(SYNTHETIC_WSVEC_FILE)")
    return SYNTHETIC_WSVEC_FILE
end

"""Run one example and print its auditable output locations on the root process."""
function run_and_report(config)
    result = WannierNLQG.run(config)
    if WannierNLQG.Runtime.mpi_is_root_process()
        println("WannierNLQG example finished: ", join([spec.label for spec in result.specs], ", "))
        println("run_dir = ", result.run_dir)
        foreach(path -> println("output = ", path), result.outputs)
        println("metadata = ", result.metadata_path)
    end
    return result
end

end
