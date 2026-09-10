using Test

isdefined(Main, :QEPAWMatrixElementsTestSupport) ||
    include(joinpath(@__DIR__, "QEPAWMatrixElementsTestSupport.jl"))
using .QEPAWMatrixElementsTestSupport

@testset "star-gauge cross-process readback and 1/2/4-thread determinism" begin
    mktempdir() do directory
        fixture = write_qe_paw_fixture(
            directory;
            metric_kind = :norm_conserving,
            spinor = false,
            spinorbit = false,
        )
        probe = joinpath(@__DIR__, "StarGaugeThreadProbe.jl")
        policy_digests = Dict{String, Vector{String}}()
        for policy in ("adaptive", "weighted", "target")
            digests = String[]
            for threads in (1, 2, 4)
                output = joinpath(directory, "$(policy)-threads-$(threads)")
                command =
                    `$(Base.julia_cmd()) --startup-file=no --threads=$(threads) --project=$(dirname(@__DIR__)) $(probe) $(fixture.save_directory) $(fixture.nnkp_file) $(output) $(policy)`
                command = addenv(
                    command,
                    "OMP_NUM_THREADS" => "1",
                    "MKL_NUM_THREADS" => "1",
                    "OPENBLAS_NUM_THREADS" => "1",
                    "VECLIB_MAXIMUM_THREADS" => "1",
                )
                text = read(command, String)
                matched = match(r"STAR_GAUGE_THREAD_DIGEST=([0-9a-f]{64})", text)
                @test matched !== nothing
                push!(digests, something(matched).captures[1])
            end
            @test length(unique(digests)) == 1
            policy_digests[policy] = digests
        end

        gauge_hdf5 = joinpath(directory, "weighted-threads-1", "star_gauge.h5")
        wfc_file = joinpath(fixture.save_directory, "wfc1.hdf5")
        held_wfc = wfc_file * ".readback-hold"
        mv(wfc_file, held_wfc)
        try
            readback_probe = joinpath(@__DIR__, "StarGaugeFreshReadProbe.jl")
            command =
                `$(Base.julia_cmd()) --startup-file=no --project=$(dirname(@__DIR__)) $(readback_probe) $(gauge_hdf5)`
            process = redirect_stdout(devnull) do
                redirect_stderr(devnull) do
                    Base.run(ignorestatus(command))
                end
            end
            @test !success(process)
        finally
            mv(held_wfc, wfc_file)
        end
        readback_probe = joinpath(@__DIR__, "StarGaugeFreshReadProbe.jl")
        command =
            `$(Base.julia_cmd()) --startup-file=no --project=$(dirname(@__DIR__)) $(readback_probe) $(gauge_hdf5)`
        text = read(command, String)
        @test occursin(r"STAR_GAUGE_FRESH_READ_DIGEST=[0-9a-f]{64}", text)
    end
end
