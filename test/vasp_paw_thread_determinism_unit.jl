using Test

@testset "VASP PAW projector/MMN/AMN 1/2/4-thread determinism" begin
    probe = joinpath(@__DIR__, "VASPPawThreadDeterminismProbe.jl")
    digests = Dict{Int, String}()
    for threads in (1, 2, 4)
        command = addenv(
            `$(Base.julia_cmd()) --startup-file=no --project=$(dirname(@__DIR__)) $(probe)`,
            "JULIA_NUM_THREADS" => string(threads),
            "OPENBLAS_NUM_THREADS" => "1",
        )
        digests[threads] = strip(read(command, String))
        @test occursin(r"^[0-9a-f]{64}$", digests[threads])
    end
    @test digests[1] == digests[2] == digests[4]
end
