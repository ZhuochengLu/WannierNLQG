using Test, WannierNLQG
isdefined(@__MODULE__, :ots_fixture) ||
    include(joinpath(@__DIR__, "OperatorTaskSelectionTestSupport.jl"))

@testset "nonzero neighbor-order fresh construct/write/read/downstream" begin
    let directory = mktempdir(
            get(ENV, "WANNIERNLQG_OPERATOR_TEST_EVIDENCE", tempdir());
            cleanup = !haskey(ENV, "WANNIERNLQG_OPERATOR_TEST_EVIDENCE"),
        )
        println("NONZERO_NEIGHBOR_FIXTURE_DIRECTORY ", directory)
        baseline_operators = nothing
        baseline_tables = nothing
        permuted_tables = nothing
        for (permutation, threads) in ((:identity, 1), (:per_k, 1), (:per_k, 2))
            output=joinpath(directory, string(permutation)*"-"*string(threads))
            log=output*".log"
            probe=joinpath(@__DIR__, "NeighborOrderFreshProbe.jl")
            project=dirname(Base.active_project())
            cmd=`$(Base.julia_cmd()) --startup-file=no --threads=$threads --project=$project $probe $output $(string(permutation))`
            process=open(log, "w") do stream
                Base.run(
                    pipeline(
                        ignorestatus(
                            addenv(
                                fresh_response_command(cmd),
                                "OPENBLAS_NUM_THREADS"=>"1",
                                "OMP_NUM_THREADS"=>"1",
                                "WANNIERNLQG_USE_MPI"=>"0",
                            ),
                        );
                        stdout = stream,
                        stderr = stream,
                    ),
                )
            end
            text=read(log, String)
            print(text)
            @test success(process)
            @test occursin("NEIGHBOR_FRESH_CONSTRUCT_WRITE_READ_RESPONSE_PASS", text)
            success(process) || continue
            bundle=OTS_IO.read_real_space_operator_bundle(joinpath(output, "oam.h5"))
            tables=Dict(
                relpath(joinpath(path, file), output)=>ots_table(joinpath(path, file)) for
                (path, _, files) in walkdir(joinpath(output, "responses")) for
                file in files if endswith(file, ".dat")
            )
            @test !isempty(tables)
            if baseline_operators===nothing
                baseline_operators=bundle.operators
                baseline_tables=tables
            else
                @test Set(keys(bundle.operators))==Set(keys(baseline_operators))
                for kind in keys(bundle.operators)
                    @test isapprox(
                        bundle.operators[kind].data,
                        baseline_operators[kind].data;
                        atol = 2e-12,
                        rtol = 2e-12,
                    )
                end
                @test keys(tables)==keys(baseline_tables)
                for name in keys(tables)
                    @test isapprox(tables[name], baseline_tables[name]; atol = 1e-28, rtol = 2e-11)
                end
            end
            if permutation==:per_k
                if permuted_tables!==nothing
                    @test keys(tables)==keys(permuted_tables)
                    @test all(tables[name]==permuted_tables[name] for name in keys(tables))
                end
                permuted_tables=tables
            end
        end
    end
end
