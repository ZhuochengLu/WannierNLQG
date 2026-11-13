using Test
import JSON3

@testset "Current Runtime metadata visualization consumer" begin
    python = get(ENV, "WANNIERNLQG_VISUALIZATION_PYTHON", "")
    @test isabspath(python) && isfile(python)
    script = joinpath(@__DIR__, "visualization", "source_identity_unit.py")
    # Honor the explicitly pinned publication prefix while excluding user-site packages.
    process = open(`$python -s -B $script`, "r")
    text = read(process, String)
    wait(process)
    @test success(process)
    result = JSON3.read(text)
    @test result.tests_run == 6 && result.failures == result.errors == 0 && result.passed
    @test realpath(String(result.source_root)) == realpath(dirname(@__DIR__))
    @test realpath(String(result.python)) == realpath(python)
    if haskey(ENV, "WANNIERNLQG_VALIDATION_NUMPY_BINARY")
        @test realpath(String(result.numpy_binary)) ==
              realpath(ENV["WANNIERNLQG_VALIDATION_NUMPY_BINARY"])
        @test result.numpy_version == ENV["WANNIERNLQG_VALIDATION_NUMPY_VERSION"]
    end
end
