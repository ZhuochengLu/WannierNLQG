using Test
@testset "gauge-aware workflow removed by Plan" begin
    s=WannierNLQG.Symmetrization
    @test !isdefined(s, :GaugeAwareSymmetrizationConfig)
    @test !isdefined(s, :symmetrize_existing_wannier_model)
    @test_throws ArgumentError WannierNLQG.Runtime.resolve_workflow_input(
        Dict("workflow"=>"symmetrization", "symmetrization"=>Dict("mode"=>"gauge_aware"));
        check_paths = false,
    )
end
