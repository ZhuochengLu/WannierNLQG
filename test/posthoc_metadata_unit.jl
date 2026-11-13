using Test
source = read(
    joinpath(@__DIR__, "..", "ext", "WannierNLQGWannierizationExt", "WannierizationWorkflow.jl"),
    String,
)
start = first(findfirst("function _posthoc_nonroot_profile_summary", source))
expr, _ = Meta.parse(source, start)
eval(expr)

@testset "posthoc peer metadata" begin
    large = repeat("a", 1024 * 1024)
    root = Dict(
        "status" => "PASS",
        "profile" => "full",
        "band_frame_contract_definition" => large,
        "authoritative_hamiltonian_definition" => large,
        "operator_target_contract_definition" => large,
        "spn_content_authentication" => "NOT_PERFORMED",
    )
    peer = _posthoc_nonroot_profile_summary(root)
    @test peer["status"] == "PASS" && peer["profile"] == "full"
    @test peer["spn_content_authentication"] == "NOT_PERFORMED"
    @test peer["nonroot_metadata_scope"] == "COMPLETE_DEFINITIONS_ON_PUBLISHING_RANK"
    @test !haskey(peer, "band_frame_contract_definition")
    @test !haskey(peer, "authoritative_hamiltonian_definition")
    @test !haskey(peer, "operator_target_contract_definition")
    @test root["operator_target_contract_definition"] == large
end
