module WannierizationRestartInputDefinitionTests
using Test, WannierNLQG, HDF5, JSON3, LinearAlgebra
include(joinpath(@__DIR__, "WannierizationFixtureSupport.jl"))
const W=WANNIERIZATION
const S=WANNIERIZATION_IMPLEMENTATION.SolverCheckpoint

@testset "Current U history uses complete discrete membership" begin
    link=S.MVPhaseBranchLink(1, 2, 3, pi, 1e-10, -2pi)
    continuous=S.MVPhaseBranchLink(1, 2, 3, pi-1e-8, 2e-10, -4pi)
    opposite=S.MVPhaseBranchLink(1, 2, 3, pi, 1e-10, 2pi)
    rows=S._mv_branch_orbit_definition([link])
    @test rows == "1,2,3,-1\n"
    @test S._mv_branch_orbit_definition([continuous]) == rows
    @test S._mv_branch_orbit_definition([opposite]) != rows
    definition=S._u_branch_definition([rows])
    @test occursin(rows, definition)
    @test S._u_branch_definition([rows, "4,5,6,1\n"]) == S._u_branch_definition(["4,5,6,1\n", rows])
    @test definition != S._u_branch_definition([S._mv_branch_orbit_definition([opposite])])
    @test S._validate_u_branch_definition(definition) === nothing
    @test_throws ArgumentError S._validate_u_branch_definition(definition*"extra")
    @test_throws ArgumentError S._validate_u_branch_definition("u-branch-input/1\n1\n100:x")
    base=W.WannierizationOptimizerState(:fixed, 0.25, 0.75)
    optimizer=W.WannierizationOptimizerState(
        (
            name===:u_active_orbit_definition ? definition : getfield(base, name) for
            name in fieldnames(W.WannierizationOptimizerState)
        )...,
    )
    mktempdir() do directory
        file=joinpath(directory, "branch.h5")
        h5open(file, "w") do group
            S._write_restart_branch_definition_hdf5(group, optimizer; qualified = true)
        end
        decoded=h5open(file, "r") do group
            S._read_restart_branch_definition_hdf5(group, optimizer; qualified = true)
        end
        @test decoded.u_active_orbit_definition == definition
        h5open(file, "r+") do group
            HDF5.delete_object(group, "u_active_orbit_definition_utf8")
            group["u_active_orbit_definition_utf8"]=collect(
                codeunits(S._u_branch_definition([S._mv_branch_orbit_definition([opposite])])),
            )
        end
        @test_throws ArgumentError h5open(file, "r") do group
            S._read_restart_branch_definition_hdf5(group, optimizer; qualified = true)
        end
    end
end

@testset "Current W complete inputs preserve accepted state and reject changed sources" begin
    fixture=synthetic_wannierization_fixture()
    result=W._solve_symmetry_adapted_wannierization(
        fixture.config,
        fixture.representation,
        fixture.eig,
        fixture.mmn,
        fixture.plan,
    )
    @test result.status in (W.COMPLETED, W.COMPLETED_WITH_WARNINGS, W.MAX_ITERATIONS)
    @test result.restart_state!==nothing
    result.restart_state===nothing && error("No accepted state: $(result.diagnostics)")
    proof=result.restart_state.input_definition
    @test proof isa W.WannierizationRestartInputDefinition
    @test all(isfinite, result.v_matrix)
    algorithms=S.effective_wannierization_algorithms(fixture.config, fixture.representation)
    symmetry=S.symmetry_constraints_applied(fixture.config, fixture.representation)
    same=() -> S._restart_input_definition(
        fixture.config,
        fixture.representation,
        fixture.mmn,
        nothing,
        algorithms,
        symmetry;
        expected = proof,
        require_expected = true,
    )
    @test same()===proof
    @test S.validate_restart_scientific_inputs(proof, fixture.representation, fixture.mmn) ===
          nothing
    allowed=modified_wannierization_config(
        fixture.config;
        stage_controls = W.WannierizationStageControls(
            dis_num_iter = fixture.config.solver.stage_controls.dis_num_iter + 2,
            num_iter = fixture.config.solver.stage_controls.num_iter + 2,
            dis_conv_tol = fixture.config.solver.stage_controls.dis_conv_tol,
            dis_conv_window = fixture.config.solver.stage_controls.dis_conv_window,
            conv_tol = fixture.config.solver.stage_controls.conv_tol,
            conv_window = fixture.config.solver.stage_controls.conv_window,
        ),
        num_print_cycles = 50,
        num_dump_cycles = 50,
    )
    @test S._restart_input_definition(
        allowed,
        fixture.representation,
        fixture.mmn,
        nothing,
        algorithms,
        symmetry;
        expected = proof,
        require_expected = true,
    )===proof
    wrong_config=modified_wannierization_config(fixture.config; u_mix_ratio = 0.5)
    @test_throws ArgumentError S._restart_input_definition(
        wrong_config,
        fixture.representation,
        fixture.mmn,
        nothing,
        algorithms,
        symmetry;
        expected = proof,
        require_expected = true,
    )
    changed=deepcopy(fixture.representation)
    changed.energies_ev[1]=nextfloat(changed.energies_ev[1])
    @test_throws ArgumentError S.validate_restart_scientific_inputs(proof, changed, fixture.mmn)
    @test_throws ArgumentError S._restart_input_definition(
        fixture.config,
        changed,
        fixture.mmn,
        nothing,
        algorithms,
        symmetry;
        expected = proof,
        require_expected = true,
    )
    overlap=deepcopy(fixture.mmn)
    overlap.data[end]+=1e-12
    @test_throws ArgumentError S.validate_restart_scientific_inputs(
        proof,
        fixture.representation,
        overlap,
    )
    @test_throws ArgumentError S._restart_input_definition(
        fixture.config,
        fixture.representation,
        overlap,
        nothing,
        algorithms,
        symmetry;
        expected = proof,
        require_expected = true,
    )
    @test_throws ArgumentError S._restart_input_definition(
        fixture.config,
        fixture.representation,
        fixture.mmn,
        nothing,
        algorithms,
        symmetry;
        require_expected = true,
    )
    seed=copy(result.v_matrix)
    seeded=S._restart_input_definition(
        fixture.config,
        fixture.representation,
        fixture.mmn,
        seed,
        algorithms,
        symmetry,
    )
    seed[end]+=1e-12
    @test_throws ArgumentError S._restart_input_definition(
        fixture.config,
        fixture.representation,
        fixture.mmn,
        seed,
        algorithms,
        symmetry;
        expected = seeded,
        require_expected = true,
    )
    mktempdir() do directory
        file=joinpath(directory, "current.h5")
        W.write_wannierization_checkpoint_hdf5(file, result)
        @test h5open(f->read(attributes(f)["schema_version"]), file, "r")=="3.0"
        decoded=W.read_wannierization_checkpoint_hdf5(file)
        @test decoded.input_summary["restart_eligible"]=="true"
        @test decoded.restart_state.input_definition!==nothing
        @test decoded.restart_state.frames==result.restart_state.frames
        @test decoded.restart_state.convergence_values==result.restart_state.convergence_values
        @test decoded.restart_state.included_bands==result.restart_state.included_bands
        @test S._restart_input_definition(
            fixture.config,
            fixture.representation,
            fixture.mmn,
            nothing,
            algorithms,
            symmetry;
            expected = decoded.restart_state.input_definition,
            require_expected = true,
        )===decoded.restart_state.input_definition
        bytes=IOBuffer();
        S.write_checkpoint_definition(bytes, decoded)
        @test !occursin(directory, String(take!(bytes)))
        withheld=W.WannierizationResult(
            (
                name===:input_summary ?
                merge(result.input_summary, Dict("restart_eligible"=>"false")) :
                getfield(result, name) for name in fieldnames(W.WannierizationResult)
            )...,
        )
        withheld_path=joinpath(directory, "withheld.h5")
        W.write_wannierization_checkpoint_hdf5(withheld_path, withheld)
        withheld_read=W.read_wannierization_checkpoint_hdf5(withheld_path)
        @test withheld_read.input_summary["restart_eligible"]=="false"
        @test withheld_read.restart_state.input_definition!==nothing
        @test_throws ArgumentError WANNIERIZATION_IMPLEMENTATION.WorkflowOrchestration._validate_restart_schema_for_continuation(
            withheld_read,
        )
        state=result.restart_state
        raw=W.WannierizationRestartState(
            (
                getfield(state, name) for
                name in fieldnames(W.WannierizationRestartState) if name!==:input_definition
            )...,
        )
        @test raw.input_definition===nothing
        raw_result=W.WannierizationResult(
            (
                name===:restart_state ? raw : getfield(result, name) for
                name in fieldnames(W.WannierizationResult)
            )...,
        )
        archival=joinpath(directory, "raw.h5")
        W.write_wannierization_checkpoint_hdf5(archival, raw_result)
        restored=W.read_wannierization_checkpoint_hdf5(archival)
        @test restored.input_summary["restart_eligible"]=="false"
        @test restored.restart_state.frames==state.frames
        @test all(
            isequal(
                getfield(restored.restart_state.optimizer_state, name),
                getfield(state.optimizer_state, name),
            ) for name in fieldnames(W.WannierizationOptimizerState)
        )
        @test_throws ArgumentError WANNIERIZATION_IMPLEMENTATION.WorkflowOrchestration._validate_restart_schema_for_continuation(
            restored,
        )
    end
end
end
