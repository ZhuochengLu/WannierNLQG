using Test, WannierNLQG, JSON3

@testset "Declared miniature admission preserves lazy TB and read-only source" begin
    root = realpath(joinpath(@__DIR__, ".."))
    probe = joinpath(@__DIR__, "ExampleFixtureInputProbe.jl")
    command =
        `$(Base.julia_cmd()) --startup-file=no --compiled-modules=existing --threads=1 --gcthreads=1 --project=$root $probe $root`
    report = JSON3.read(read(command, String))
    @test report.source_root == root
    @test report.threads == 1
    @test !report.mpi_initialized
    @test report.tb_only_kept_packed_extension_inactive
    @test report.owned_copy_and_private_receipt
    @test report.all_operator_bytes_equal
    @test report.original_source_unchanged
    @test report.scope_restored_after_error
end
