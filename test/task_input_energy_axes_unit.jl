module TaskInputEnergyAxesUnit
using Test, WannierNLQG
const R=WannierNLQG.Runtime
@testset "Energy range independent references and failure bounds" begin
    generated=R._task_input_energy_range(0.0, 4.0, 0.02, nothing, "test")
    @test length(generated)==201
    @test all(
        isapprox(a, b; atol = 1e-15, rtol = 0) for
        (a, b) in zip(generated, Float64.([i//50 for i in 0:200]))
    )
    @test R._task_input_energy_range(0.0, 1.0, 0.3, nothing, "test") ≈ [0.0, 0.3, 0.6, 0.9] atol=2e-16 rtol=0
    @test R._task_input_energy_range(0.0, 0.3, 0.1, nothing, "test") == [0.0, 0.1, 0.2, 0.3]
    @test R._task_input_energy_range(-0.2, 0.2, nothing, 41, "test") ≈
          Float64.([i//100 for i in -20:20]) atol=1e-16 rtol=0
    @test R._task_input_energy_range(2.0, 2.0, 0.1, nothing, "test")==[2.0]
    @test R._task_input_energy_range(2.0, 2.0, nothing, 1, "test")==[2.0]
    for args in [
        (0.0, 1.0, nothing, true),
        (0.0, 1.0, nothing, 1),
        (1.0, 1.0, nothing, 2),
        (0.0, 1.0, 0.0, nothing),
        (0.0, 1.0, -1.0, nothing),
        (0.0, Inf, 0.1, nothing),
        (false, 1.0, 0.1, nothing),
        (1e16, 1e16+4.0, 1.0, nothing),
        (0.0, 1.0, 1e-12, nothing),
        (0.0, 1.0, nothing, 10^10),
        (2^53, 2^53+1, nothing, 1),
        (2^53, 2^53+1, nothing, 2),
    ]
        @test_throws ArgumentError R._task_input_energy_range(args..., "invalid")
    end
    provenance=Dict{String, Dict{String, Any}}()
    doc=Dict{String, Any}(
        "photon_energy_min_ev"=>0.0,
        "photon_energy_max_ev"=>0.3,
        "photon_energy_step_ev"=>0.1,
    )
    R._task_input_user_leaves!(provenance, doc, "response")
    R._task_input_expand_axes!(doc, "response", provenance)
    @test doc["photon_energies_ev"]==[0.0, 0.1, 0.2, 0.3]
    @test provenance["response.photon_energies_ev"]["source"]=="DERIVED"
    @test provenance["response.photon_energy_step_ev"]["source"]=="USER"
    explicit=Dict{String, Any}("fermi_energies_ev"=>[0.2, -0.1, -0.1])
    R._task_input_expand_axes!(explicit, "response", provenance)
    @test explicit["fermi_energies_ev"]==[0.2, -0.1, -0.1]
    for malformed in [
        Dict("photon_energy_max_ev"=>1.0),
        Dict(
            "photon_energy_min_ev"=>0.0,
            "photon_energy_max_ev"=>1.0,
            "photon_energy_step_ev"=>0.1,
            "photon_energy_num_points"=>11,
        ),
        Dict(
            "fermi_energies_ev"=>[0.0],
            "fermi_energy_min_ev"=>0.0,
            "fermi_energy_max_ev"=>1.0,
            "fermi_energy_num_points"=>2,
        ),
    ]
        @test_throws ArgumentError R._task_input_expand_axes!(malformed, "response", provenance)
    end
end
end
