using Test

@testset "uHu/sHu/sIu/QE-SPN 1/2/4-thread fresh-process determinism" begin
    probe = joinpath(@__DIR__, "WannierHamiltonianOperatorThreadProbe.jl")
    digests = Dict{Int, String}()
    for threads in (1, 2, 4)
        command = addenv(
            `$(Base.julia_cmd()) --startup-file=no --project=$(dirname(@__DIR__)) $(probe)`,
            "JULIA_NUM_THREADS" => string(threads),
            "OPENBLAS_NUM_THREADS" => "1",
        )
        output = read(command, String)
        matched = match(r"WANNIER_HAMILTONIAN_OPERATOR_DIGEST=([0-9a-f]{64})", output)
        @test matched !== nothing
        digests[threads] = something(matched).captures[1]
    end
    @test digests[1] == digests[2] == digests[4]
end
