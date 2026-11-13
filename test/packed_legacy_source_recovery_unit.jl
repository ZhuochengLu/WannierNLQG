using Test, WannierNLQG, JSON3, SHA

@testset "Exact retained legacy paired bytes recover without a solver replay" begin
    archive = ENV["WANNIERNLQG_LEGACY_RECOVERY_SOURCE"]
    actor = ENV["WANNIERNLQG_LEGACY_RECOVERY_READER"]
    source = realpath(joinpath(@__DIR__, ".."))
    destination = joinpath(Main.LEGACY_SOURCE_RECOVERY_OUTPUT, "legacy-recovery")
    @test !ispath(destination)
    command =
        `$(Base.julia_cmd()) --startup-file=no --compiled-modules=existing --threads=1 --gcthreads=1 --project=$archive $actor $archive $source $destination`
    @test success(command)
    report = JSON3.read(read(joinpath(destination, "legacy_source_recovery.json"), String))
    @test report.source_root == realpath(archive)
    @test report.input_root == source
    @test !report.mpi_initialized
    @test String.(getproperty.(report.rows, :name)) == ["ordinary", "symmetrized"]
    for row in report.rows
        @test row.archived_complete_manifest_and_all_component_seals_checked
        @test !row.solver_executed
        @test row.error === nothing
        @test row.accepted_bytes_hex !== nothing
        if row.accepted_bytes_hex !== nothing
            bytes = hex2bytes(String(row.accepted_bytes_hex))
            @test bytes2hex(sha256(bytes)) == row.expected_sha256
            mktempdir() do directory
                path = joinpath(directory, "exact-original.dat")
                write(path, bytes)
                model = WannierNLQG.IO.read_wannier_tb(path)
                @test model.num_orbitals > 0 && model.num_r_vectors > 0
                @test all(isfinite, model.hamiltonian_r) && all(isfinite, model.position_r)
            end
        end
    end
end
