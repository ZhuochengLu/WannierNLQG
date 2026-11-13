using Test, LinearAlgebra, TOML
include(
    joinpath(
        @__DIR__,
        "..",
        "ext",
        "WannierNLQGWannierizationExt",
        "PrecompileSupport",
        "TinyWannierWorkflowInputs.jl",
    ),
)

@testset "Normalized TOML actual solve and checkpoint" begin
    w = WannierNLQG.Wannierization
    r = WannierNLQG.Runtime
    mktempdir() do dir
        inputs = tiny_wannier_workflow(dir)
        rm(inputs.solve.input.win_file)
        amn = joinpath(dir, "tiny.amn")
        WannierNLQG.IO.write_wannier_amn(
            amn,
            WannierNLQG.IO.WannierAMN(2, 2, 1, reshape(ComplexF64[1, 0, 1, 0], 2, 1, 2)),
        )
        base = Dict{String, Any}(
            "workflow"=>"wannierization",
            "mode"=>"ordinary",
            "structure"=>Dict(
                "lattice_angstrom"=>[[1.0, 0.0, 0.0], [0.0, 1.0, 0.0], [0.0, 0.0, 1.0]],
                "species"=>["X"],
                "positions_fractional"=>[[0.0, 0.0, 0.0]],
            ),
            "kmesh"=>Dict(
                "dimensions"=>[2, 1, 1],
                "points_fractional"=>[[0.0, 0.0, 0.0], [0.5, 0.0, 0.0]],
            ),
            "basis"=>Dict("projections"=>["X:s"]),
            "matrices"=>Dict(
                "eig_file"=>"tiny.eig",
                "mmn_file"=>"tiny.mmn",
                "amn_file"=>"tiny.amn",
            ),
            "windows"=>Dict("outer_min_ev"=>-2.0, "outer_max_ev"=>2.0),
        )
        results = Dict{Tuple{Int, Int}, Any}()
        for (z, u) in ((2, 2),)
            doc = deepcopy(base)
            doc["solver"] =
                Dict("initialization"=>"amn", "dis_num_iter"=>z, "num_iter"=>u, "conv_window"=>0)
            doc["output"] = Dict(
                "model_file"=>"result_$(z)_$(u).h5",
                "checkpoint_hdf5"=>"result_$(z)_$(u).wannierization.h5",
                "num_print_cycles"=>0,
                "num_dump_cycles"=>0,
            )
            filename = joinpath(dir, "input_$(z)_$(u).toml")
            open(io -> TOML.print(io, doc), filename, "w")
            input = r.read_task_input(filename)
            @test input.config.input.win_file === nothing
            @test input.config.solver.stage_controls.num_iter == u
            @test occursin("NOT_ESTABLISHED", r.explain_task_input(input))
            actual = r.run_task_input(input; record_directory = joinpath(dir, "records_$(z)_$(u)"))
            @test actual.status ∉ (w.INVALID_INPUT, w.IO_FAILURE, w.LOCALIZATION_FAILED)
            @test !isempty(actual.v_matrix)
            @test isfile(input.config.checkpoint.checkpoint_hdf5)
            @test actual.restart_state !== nothing
            effective_path = joinpath(dir, "records_$(z)_$(u)", "effective_config.toml")
            @test isfile(effective_path)
            replay = r.read_task_input(effective_path)
            @test replay.config.input.geometry.kpoints_fractional ==
                  input.config.input.geometry.kpoints_fractional
            @test replay.config.input.eig_file == input.config.input.eig_file
            @test replay.config.solver.stage_controls == input.config.solver.stage_controls
            if actual.restart_state !== nothing
                @test actual.restart_state.optimizer_state.z_steps <= z
                @test actual.restart_state.optimizer_state.u_steps <= u
            end
            if z == 0 && u == 0
                @test isempty(actual.history)
                @test actual.input_summary["disentanglement_convergence"] == "SKIPPED_ZERO_STEPS"
                @test actual.input_summary["localization_convergence"] == "SKIPPED_ZERO_STEPS"
            end
            @test !isfile(inputs.solve.input.win_file)
            results[(z, u)] = actual
        end
        # A partial U run and continuation must reproduce one uninterrupted run,
        # including the accumulated accepted counters (not just the final frames).
        split_doc = deepcopy(base)
        split_doc["solver"] =
            Dict("initialization"=>"amn", "dis_num_iter"=>2, "num_iter"=>1, "conv_window"=>0)
        split_doc["output"] = Dict(
            "model_file"=>"split.h5",
            "checkpoint_hdf5"=>"split.wannierization.h5",
            "num_print_cycles"=>0,
            "num_dump_cycles"=>1,
        )
        partial = r.run_task_input(
            r.resolve_workflow_input(split_doc; base_dir = dir);
            record_directory = joinpath(dir, "split_records"),
        )
        @test partial.status ∉ (w.INVALID_INPUT, w.IO_FAILURE, w.LOCALIZATION_FAILED)
        @test partial.restart_state !== nothing
        @test partial.restart_state.optimizer_state.z_steps == 2
        @test partial.restart_state.optimizer_state.u_steps == 1
        continued_doc = deepcopy(split_doc)
        continued_doc["solver"]["initialization"] = "restart"
        continued_doc["solver"]["num_iter"] = 2
        continued_doc["checkpoint"] = Dict("restart_hdf5"=>"split.wannierization.h5")
        continued_doc["output"]["model_file"] = "continued.h5"
        continued_doc["output"]["checkpoint_hdf5"] = "continued.wannierization.h5"
        continued_doc["output"]["num_dump_cycles"] = 0
        continued = r.run_task_input(
            r.resolve_workflow_input(continued_doc; base_dir = dir);
            record_directory = joinpath(dir, "continued_records"),
        )
        @test continued.status == results[(2, 2)].status
        @test isequal(continued.v_matrix, results[(2, 2)].v_matrix)
        @test isequal(
            continued.wannier_centers_cartesian,
            results[(2, 2)].wannier_centers_cartesian,
        )
        @test isequal(continued.spreads_angstrom2, results[(2, 2)].spreads_angstrom2)
        @test continued.restart_state.optimizer_state.z_steps == 2
        @test continued.restart_state.optimizer_state.u_steps == 2
        @test length(continued.history) == length(results[(2, 2)].history)
        @test continued.restart_state.optimizer_state.disentanglement_objective_history ==
              results[(2, 2)].restart_state.optimizer_state.disentanglement_objective_history
        @test continued.restart_state.optimizer_state.localization_objective_history ==
              results[(2, 2)].restart_state.optimizer_state.localization_objective_history
        # Export-only continuation must retain the accepted trajectory. Changing
        # stopping controls is allowed; changing physical inputs is not.
        resumed_doc = deepcopy(base)
        resumed_doc["solver"] = Dict(
            "initialization"=>"restart",
            "dis_num_iter"=>0,
            "num_iter"=>0,
            "dis_conv_tol"=>1e-8,
            "conv_tol"=>1e-8,
        )
        resumed_doc["checkpoint"] = Dict("restart_hdf5"=>"result_2_2.wannierization.h5")
        resumed_doc["output"] = Dict(
            "model_file"=>"export.h5",
            "checkpoint_hdf5"=>"export.wannierization.h5",
            "num_print_cycles"=>0,
            "num_dump_cycles"=>0,
        )
        resumed_input = r.resolve_workflow_input(resumed_doc; base_dir = dir)
        resumed =
            r.run_task_input(resumed_input; record_directory = joinpath(dir, "resume_records"))
        @test resumed.status ∉ (w.INVALID_INPUT, w.IO_FAILURE, w.LOCALIZATION_FAILED)
        @test isequal(resumed.v_matrix, results[(2, 2)].v_matrix)
        @test length(resumed.history) == length(results[(2, 2)].history)
        @test resumed.restart_state !== nothing
        if resumed.restart_state !== nothing
            @test resumed.restart_state.optimizer_state.z_steps ==
                  results[(2, 2)].restart_state.optimizer_state.z_steps
            @test resumed.restart_state.optimizer_state.u_steps ==
                  results[(2, 2)].restart_state.optimizer_state.u_steps
        end
        @test isfile(joinpath(dir, "export.wannierization.h5"))
        invalid = deepcopy(resumed_doc)
        invalid["structure"]["lattice_angstrom"][1][1] = 2.0
        invalid["output"]["model_file"] = "rejected.h5"
        invalid["output"]["checkpoint_hdf5"] = "rejected.wannierization.h5"
        rejected = r.run_task_input(
            r.resolve_workflow_input(invalid; base_dir = dir);
            record_directory = joinpath(dir, "rejected_records"),
        )
        @test rejected.status == w.INVALID_INPUT
        for change in (
            Dict("schema_version"=>1),
            Dict("solver"=>Dict("max_iterations"=>10)),
            Dict("solver"=>Dict("initialization"=>"fixed_subspace")),
            Dict("mode"=>"symmetry_adapted"),
        )
            doc = merge(deepcopy(base), change)
            @test_throws ArgumentError r.resolve_workflow_input(doc; base_dir = dir)
        end
    end
end
