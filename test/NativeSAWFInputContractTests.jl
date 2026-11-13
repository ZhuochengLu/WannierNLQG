using Test
using WannierNLQG
const runtime = WannierNLQG.Runtime
@testset "Native SAWF symmetry adapter" begin
    source =
        Dict{String, Any}("kind"=>"qe", "save_directory"=>"fixture", "include_time_reversal"=>false)
    original = deepcopy(source)
    document = Dict(
        "symmetry"=>Dict{String, Any}("include_time_reversal"=>false, "symmetry_tolerance"=>1e-5),
    )
    @test runtime._workflow_native_symmetry_source(document, source, :symmetry_adapted) == source
    @test source == original
    @test runtime._workflow_native_symmetry_tolerance(document, :symmetry_adapted) == 1e-5
    @test runtime._workflow_native_symmetry_source(Dict(), source, :ordinary) === source
    for bad in (true, 0, -1, Inf, NaN, "1e-5")
        @test_throws ArgumentError runtime._workflow_native_symmetry_tolerance(
            Dict("symmetry"=>Dict("symmetry_tolerance"=>bad)),
            :symmetry_adapted,
        )
    end
    @test_throws ArgumentError runtime._workflow_native_symmetry_source(
        Dict("symmetry"=>Dict("include_time_reversal"=>true)),
        source,
        :symmetry_adapted,
    )
    @test_throws ArgumentError runtime._workflow_native_symmetry_source(
        Dict("symmetry"=>Dict("include_time_reversal"=>1)),
        source,
        :symmetry_adapted,
    )
    @test_throws ArgumentError runtime._workflow_native_symmetry_source(
        Dict("symmetry"=>Dict("operation_indices"=>[1])),
        source,
        :symmetry_adapted,
    )
end
