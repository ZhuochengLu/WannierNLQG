using Test, WannierNLQG

@testset "Original progress readiness uses the explicitly admitted declared input" begin
    root = realpath(joinpath(@__DIR__, ".."))
    script = joinpath(root, "scripts", "check_progress_output.jl")
    command =
        `$(Base.julia_cmd()) --startup-file=no --compiled-modules=existing --threads=1 --gcthreads=1 --project=$root $script`
    output = read(command, String)
    @test occursin("[progress-check] ok", output)
    location = match(r"(?m)^\[progress-check\] root=(.+)$", output)
    @test location !== nothing
    if location !== nothing
        @test isdir(location.captures[1])
        expected = get(ENV, "WANNIERNLQG_TEST_OUTPUT_ROOT", "")
        isempty(expected) && (expected = tempdir())
        @test realpath(dirname(location.captures[1])) == realpath(expected)
    end
end
