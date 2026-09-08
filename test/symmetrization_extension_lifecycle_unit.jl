using Test

const EXTENSION_LIFECYCLE_PROBE = joinpath(@__DIR__, "SymmetryFoundationExtensionLifecycleProbe.jl")

# Run one extension lifecycle case in an isolated Julia process.
function run_extension_lifecycle_probe(mode::AbstractString; threads::Int = 1, arguments = String[])
    loading_options = endswith(mode, "_function_entry") ? ["--compiled-modules=no"] : String[]
    command =
        `$(Base.julia_cmd()) --startup-file=no $(loading_options) --project=$(ROOT) $(EXTENSION_LIFECYCLE_PROBE) $(mode) $(arguments)`
    return mktempdir() do temporary_depot
        depot_separator = Sys.iswindows() ? ';' : ':'
        isolated_depot = join((temporary_depot, Base.DEPOT_PATH...), depot_separator)
        command = addenv(
            command,
            "JULIA_PROJECT" => ROOT,
            "JULIA_LOAD_PATH" => "@:@stdlib",
            "JULIA_DEPOT_PATH" => isolated_depot,
            "JULIA_NUM_THREADS" => string(threads),
            "OMP_NUM_THREADS" => "1",
            "MKL_NUM_THREADS" => "1",
            "OPENBLAS_NUM_THREADS" => "1",
            "VECLIB_MAXIMUM_THREADS" => "1",
        )
        return read(command, String)
    end
end

@testset "symmetry-foundation and symmetrization package-extension lifecycle" begin
    @test occursin("mode=import", run_extension_lifecycle_probe("import"))
    for mode in (
        "operator_bundle_function_entry",
        "foundation_function_entry",
        "symmetrization_function_entry",
        "wannierization_function_entry",
        "response_json_function_entry",
    )
        @test occursin("mode=$(mode)", run_extension_lifecycle_probe(mode))
    end
    for mode in ("operator_bundle_cached_entry", "foundation_cached_entry")
        @test occursin("mode=$(mode)", run_extension_lifecycle_probe(mode))
    end
    for order in ("HDF5,JSON3", "JSON3,HDF5")
        @test occursin(
            "mode=operator_trigger_order",
            run_extension_lifecycle_probe("operator_trigger_order"; arguments = [order]),
        )
    end
    @test occursin("mode=run", run_extension_lifecycle_probe("run"; arguments = [TEST_MODEL_FILE]))
    @test occursin(
        "mode=foundation_concurrent",
        run_extension_lifecycle_probe("foundation_concurrent"; threads = 4),
    )
    @test occursin(
        "mode=symmetrization_concurrent",
        run_extension_lifecycle_probe("symmetrization_concurrent"; threads = 4),
    )
    @test occursin(
        "mode=symmetrization_partial",
        run_extension_lifecycle_probe("symmetrization_partial"),
    )
    @test occursin(
        "mode=wannierization_partial",
        run_extension_lifecycle_probe("wannierization_partial"),
    )
    @test occursin("mode=shared_two_triggers", run_extension_lifecycle_probe("shared_two_triggers"))
    for order in (
        "HDF5,JSON3,EzXML",
        "HDF5,EzXML,JSON3",
        "JSON3,HDF5,EzXML",
        "JSON3,EzXML,HDF5",
        "EzXML,HDF5,JSON3",
        "EzXML,JSON3,HDF5",
    )
        @test occursin(
            "mode=shared_trigger_order",
            run_extension_lifecycle_probe("shared_trigger_order"; arguments = [order]),
        )
    end
    @test occursin("mode=partial_foundation", run_extension_lifecycle_probe("partial_foundation"))
    @test occursin("mode=all", run_extension_lifecycle_probe("all"))
end
