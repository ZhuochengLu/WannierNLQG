@testset "fresh-process prepare solve checkpoint TB readback" begin
    probe = joinpath(@__DIR__, "WannierizationFreshProcessProbe.jl")
    command = `$(Base.julia_cmd()) --startup-file=no --threads=1 --project=$(ROOT) $(probe)`
    output = read(
        addenv(
            command,
            "OMP_NUM_THREADS" => "1",
            "MKL_NUM_THREADS" => "1",
            "OPENBLAS_NUM_THREADS" => "1",
            "VECLIB_MAXIMUM_THREADS" => "1",
        ),
        String,
    )
    @test occursin("WANNIERIZATION_FRESH_PROCESS_PASS", output)
end
