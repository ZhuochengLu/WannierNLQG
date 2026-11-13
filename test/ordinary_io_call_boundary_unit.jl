module OrdinaryIOCallBoundaryUnit
using Test
@testset "Fresh-process ordinary IO audit boundary" begin
    probe=joinpath(@__DIR__, "OrdinaryIOCallBoundaryProbe.jl")
    compiled_modules = VERSION < v"1.11" ? "--compiled-modules=yes" : "--compiled-modules=existing"
    command=`$(Base.julia_cmd()) $compiled_modules --startup-file=no --threads=1 --project=$(dirname(Base.active_project())) $probe`
    capture=IOBuffer()
    command=addenv(
        command,
        "JULIA_NUM_THREADS"=>"1",
        "OPENBLAS_NUM_THREADS"=>"1",
        "OMP_NUM_THREADS"=>"1",
    )
    process=Base.run(pipeline(ignorestatus(command); stdout = capture, stderr = stderr))
    output=String(take!(capture))
    print(output)
    @test success(process)
    @test occursin("ORDINARY_IO_CALL_BOUNDARY_PASS", output)
end
end
