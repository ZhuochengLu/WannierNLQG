using LinearAlgebra

include(joinpath(@__DIR__, "support", "SyntheticRuntimeFixture.jl"))
using .SyntheticRuntimeFixture

function synthetic_numeric_payload(path)
    rows = [
        parse.(Float64, split(strip(line))) for
        line in eachline(path) if !isempty(strip(line)) && !startswith(strip(line), '#')
    ]
    return isempty(rows) ? Float64[] : reduce(vcat, rows)
end

function synthetic_metrics(candidate, reference; floor = 1.0e-14)
    length(candidate) == length(reference) || error("numeric payload lengths differ")
    difference = candidate .- reference
    return (
        max_abs = maximum(abs, difference; init = 0.0),
        max_rel = maximum(abs.(difference) ./ max.(abs.(reference), floor); init = 0.0),
        relative_l2 = norm(difference) / max(norm(reference), floor),
        nan_inf = count(!isfinite, candidate),
    )
end

@testset "four-orbital synthetic runtime fixture" begin
    SyntheticRuntimeFixture.verify()
    model = WannierNLQG.IO.read_wannier_tb(SyntheticRuntimeFixture.TB_FILE)
    @test model.num_orbitals == 4
    @test model.num_r_vectors == 2
    @test model.r_degeneracies == [2, 4]
    wsvec = WannierNLQG.IO.read_wannier_wsvec(
        SyntheticRuntimeFixture.WSVEC_FILE,
        model.num_orbitals,
        model.r_vectors,
    )
    @test length(wsvec.translations) == 4 * 4 * 2
    @test all(length(wsvec.translations[left, right, 2]) == 2 for left in 1:4 for right in 1:4)
    manifest = WannierNLQG.IO.read_real_space_operator_bundle_manifest(
        SyntheticRuntimeFixture.OPERATOR_BUNDLE_FILE,
    )
    @test manifest.schema_version == "1.0"
    @test manifest.profile == :full
    @test manifest.num_orbitals == 4
    @test manifest.degeneracies == [2, 4]
    @test manifest.minimum_distance_materialized === false
    @test manifest.mp_grid == (2, 1, 1)
    @test Set(manifest.inventory) == Set(WannierNLQG.Core.REAL_SPACE_OPERATOR_REGISTRY)
end

@testset "self-contained Integral and K-slice MDRS" begin
    mktempdir() do directory
        direct_integral = WannierNLQG.run(
            SyntheticRuntimeFixture.response_config(
                joinpath(directory, "integral_direct"),
                ("SC", "Conventional", "Integral"),
            ),
        )
        mixed_integral = WannierNLQG.run(
            SyntheticRuntimeFixture.response_config(
                joinpath(directory, "integral_mixed"),
                ("SC", "Conventional", "Integral");
                backend = "mixed",
            ),
        )
        kslice = WannierNLQG.run(
            SyntheticRuntimeFixture.response_config(
                joinpath(directory, "kslice"),
                ("SCK", "Conventional", "K-slice"),
            ),
        )
        for result in (direct_integral, mixed_integral, kslice)
            @test all(isfile, result.outputs)
            @test isfile(result.metadata_path)
            metadata = read(result.metadata_path, String)
            @test occursin(r"effective_policy\s*= minimum_distance", metadata)
            @test occursin(r"source\s*= wsvec", metadata)
            @test occursin(r"input_num_r_vectors\s*= 2", metadata)
            @test occursin(r"effective_num_r_vectors\s*= 3", metadata)
        end
        direct = synthetic_numeric_payload(first(direct_integral.outputs))
        mixed = synthetic_numeric_payload(first(mixed_integral.outputs))
        metrics = synthetic_metrics(mixed, direct)
        @test metrics.max_abs <= 1.0e-12
        @test metrics.max_rel <= 1.0e-12
        @test metrics.relative_l2 <= 1.0e-12
        @test metrics.nan_inf == 0
        println("synthetic MDRS Direct/Mixed metrics = $(metrics)")
    end
end
