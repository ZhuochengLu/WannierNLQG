module AcceptedStepReportChecks
using Test, WannierNLQG, JSON3
const W=WannierNLQG.Wannierization
ext=first(W._load_wannierization_extension!());
writer=ext.OperatorExport
root=mktempdir()
cfg=W.WannierizationConfig(
    input = W.WannierizationInputConfig(
        win_file = "fixture.win",
        eig_file = "fixture.eig",
        mmn_file = "fixture.mmn",
        num_wannier = 2,
    ),
    output = W.WannierizationOutputConfig(model_file = joinpath(root, "model.h5")),
    runtime = W.WannierizationRuntimeConfig(num_print_cycles = 1),
    checkpoint = W.WannierizationCheckpointConfig(num_dump_cycles = 0),
)
file=joinpath(root, "model.out");
io=open(file, "w")
paths=(checkpoint = nothing,)
observer=writer.wannierization_observer(cfg, nothing, paths, io)
z=(
    iteration = 1,
    completed_stage = :disentanglement,
    optimizer_phase = :disentanglement,
    z_steps = 1,
    u_steps = 0,
    omega_i = 1.0,
    delta_omega_i = NaN,
    elapsed_seconds = 0.25,
    spread_total = 1.0,
    convergence_metric = 0.1,
)
u=(
    iteration = 2,
    completed_stage = :localization,
    optimizer_phase = :localization,
    z_steps = 1,
    u_steps = 1,
    omega_i = 1.0,
    delta_omega_i = 0.0,
    elapsed_seconds = 0.5,
    spread_total = 1.1,
    convergence_metric = 0.01,
)
@testset "Accepted-row append and flush, phase columns and end snapshot" begin
    observer(z, nothing, W.WannierizationIteration[], W.WannierizationDiagnostic[])
    first=read(file, String)
    @test occursin("[DISENTANGLEMENT]", first)
    @test occursin("Z rel.change", first) && !occursin("U conv.metric", first)
    @test occursin("0.250000", first)
    observer(u, nothing, W.WannierizationIteration[], W.WannierizationDiagnostic[])
    live=read(file, String)
    @test startswith(live, first)
    @test occursin("[LOCALIZATION]", live)
    @test count(line -> occursin("U conv.metric", line), split(live, '\n'))==1
    result=W.WannierizationResult(
        W.MAX_ITERATIONS,
        zeros(ComplexF64, 2, 2, 1),
        [0.25 0 0; 0 0.5 0],
        [0.1, 0.2],
        [W.WannierizationIteration(1, 1.0, 0.1, 0.0), W.WannierizationIteration(2, 1.1, 0.01, 0.0)],
        [
            W.WannierizationDiagnostic(
                :MAX_ITERATIONS_REACHED,
                :warning,
                "Localization reached its maximum accepted-step count without convergence.",
            ),
        ],
        Dict("stopping_reason"=>"MAX_ITERATIONS", "num_wannier"=>"2"),
        nothing,
        nothing,
    )
    artifacts=W.WannierizationArtifacts(wannierization_log = file)
    writer.write_wannierization_final(
        io,
        result,
        cfg,
        artifacts;
        wall_time = 0.5,
        allocated_bytes = 10,
        gc_time = 0.0,
        peak_rss_bytes = 100,
    )
    text=read(file, String);
    data=JSON3.read(read(joinpath(root, "model.json"), String))
    @test startswith(text, live)
    @test !occursin("[FILES]", text)
    @test !occursin("PHYSICS_HOLD", text) && !occursin("DIAGNOSTIC_ONLY", text)
    @test length(data.history)==2
    @test data.final.centers_cartesian_angstrom[1][1]==0.25
    @test data.final.spreads_angstrom2==[0.1, 0.2]
    @test data.validation.tb_symmetry.requested==false
    @test all(isascii, text)
    @test maximum(length, split(text, '\n'))<=104
end
close(io)
println("MODEL_REPORT_TESTS_COMPLETE")

end
