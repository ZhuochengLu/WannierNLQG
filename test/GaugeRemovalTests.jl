using Test, LinearAlgebra, TOML
include("GaugeRemovalReference290.jl")
@testset "Removed workflow and retained real response consumer" begin
    s=WannierNLQG.Symmetrization;
    r=WannierNLQG.Runtime;
    io=WannierNLQG.IO
    @test !isdefined(s, :GaugeAwareSymmetrizationConfig)
    @test !isdefined(s, :symmetrize_existing_wannier_model)
    @test_throws ArgumentError r.resolve_workflow_input(
        Dict("workflow"=>"symmetrization", "symmetrization"=>Dict("mode"=>"gauge_aware"));
        check_paths = false,
    )
    @test_throws ArgumentError r.write_workflow_input_template(
        joinpath(out, "removed.toml"),
        "symmetrization",
        "gauge_aware",
    )
    @test !isfile(joinpath(out, "removed.toml"))
    assets=joinpath(@__DIR__, "fixtures/first_use_portable/assets/group_18")
    value=s.qualify_response_symmetry_wannier_frame(
        joinpath(assets, "response_symmetry.json");
        win_file = joinpath(assets, "tiny.win"),
        amn_file = joinpath(assets, "tiny.amn"),
        chk_file = joinpath(assets, "tiny.chk"),
        mmn_file = joinpath(assets, "tiny.mmn"),
        tb_file = joinpath(assets, "tiny_tb.dat"),
        diagnostic_continue = true,
    )
    @test value["dimensions"]["status"]=="PASS"
    @test value["overall_status"] in ("PASS", "PHYSICS_HOLD")
    @test value["formal_gates"]["hamiltonian_covariance"]["maximum_absolute_residual_ev"]==0.0
    ext=Base.get_extension(WannierNLQG, :WannierNLQGSymmetrizationExt)
    chk=io.read_wannier_chk(joinpath(assets, "tiny.chk"));
    mmn=io.read_wannier_mmn(joinpath(assets, "tiny.mmn"))
    payload=JSON3.read(read(joinpath(assets, "response_symmetry.json"), String), Dict{String, Any})
    operations=ext._response_qualification_operations(payload)
    map=ext._response_qualification_kpoint_map(chk.kpt_red, operations; tolerance = 1e-8)
    @test isequal(
        ext._response_qualification_edge_map(chk, mmn, map, operations),
        GaugeRemovalReference290._reference_edge_map(chk, mmn, map, operations),
    )
    for n in (1, 2), nr in (1, 3)
        values=reshape(ComplexF64.(1:(n * n * nr)), n, n, nr)
        R=reshape(collect(0:(3nr - 1)), 3, nr);
        deg=collect(1:nr)
        k=[0.0 0.0 0.0; 0.25 -0.125 0.5]
        @test isequal(
            ext._response_qualification_r_to_q(values, R, deg, k),
            GaugeRemovalReference290._reference_r_to_q(values, R, deg, k),
        )
    end
end
