# Shared by the full contract and the incremental tail; all assertions are unchanged.
@noinline Base.@nospecializeinfer function test_wannierization_persistence_report_tail(
    @nospecialize(fixture),
    @nospecialize(result),
    @nospecialize(failed),
    @nospecialize(output_config),
    @nospecialize(ordinary_forced),
    @nospecialize(paths),
    diagnostic_packed,
    @nospecialize(snapshot),
    @nospecialize(no_localization),
    @nospecialize(extension),
    directory::String,
)
    no_u_report=Base.invokelatest(
        extension.OperatorExport._wannier_model_report,
        no_localization,
        output_config;
        wall_time = 0.0,
        allocated_bytes = 0,
        gc_time = 0.0,
        peak_rss_bytes = nothing,
    )
    @test no_u_report["timing"]["process_peak_rss_bytes"] === nothing
    @test no_u_report["final"]["spreads_angstrom2"]==no_localization.spreads_angstrom2
    @test no_u_report["final"]["sum_spreads_angstrom2"]==sum(no_localization.spreads_angstrom2)
    @test no_u_report["final"]["solver_status"]==string(no_localization.status)

    ordinary_qualification = Base.invokelatest(
        extension.OperatorExport.qualify_exported_wannierization_tb,
        diagnostic_packed,
        nothing,
        nothing;
        hamiltonian_covariance_threshold = fixture.config.input.representation_tolerance,
        persist_hdf5 = false,
    )
    @test ordinary_qualification.overall == "INCOMPLETE"
    @test any(metric -> metric.status == "NOT_APPLICABLE", ordinary_qualification.metrics)
    ordinary_incomplete = Base.invokelatest(
        extension.WannierizationInternalSupport.updated_wannierization_result,
        failed;
        tb_symmetry_qualification = ordinary_qualification,
    )
    ordinary_incomplete_log = joinpath(directory, "ordinary-forced-incomplete.wannierization.out")
    ordinary_incomplete_io = open(ordinary_incomplete_log, "w")
    ordinary_incomplete_artifacts = WANNIERIZATION.WannierizationArtifacts(
        wannierization_log = ordinary_incomplete_log,
        packed_hdf5 = diagnostic_packed,
    )
    Base.invokelatest(
        extension.OperatorExport._write_wannierization_final,
        ordinary_incomplete_io,
        ordinary_incomplete,
        ordinary_forced,
        ordinary_incomplete_artifacts;
        wall_time = 0.0,
        allocated_bytes = 0,
        gc_time = 0.0,
    )
    close(ordinary_incomplete_io)
    ordinary_incomplete_text = read(ordinary_incomplete_log, String)
    @test occursin("[TB SYMMETRY]", ordinary_incomplete_text)
    incomplete_json=JSON3.read(read(replace(ordinary_incomplete_log, r"\.out$"=>".json"), String))
    @test incomplete_json.validation.tb_symmetry.requested
    @test !incomplete_json.validation.tb_symmetry.complete
    @test !isempty(String(incomplete_json.validation.tb_symmetry.reason))
    @test length(
        incomplete_json.validation.tb_symmetry.metrics,
    )==length(ordinary_qualification.metrics)

    symmetry_disabled = WANNIERIZATION._replace_wannierization_config(
        output_config;
        output = (final_tb_symmetry_report_enabled = false,),
    )
    symmetry_disabled_log = joinpath(directory, "symmetry-disabled.wannierization.out")
    symmetry_disabled_io = open(symmetry_disabled_log, "w")
    Base.invokelatest(
        extension.OperatorExport._write_wannierization_final,
        symmetry_disabled_io,
        failed,
        symmetry_disabled,
        WANNIERIZATION.WannierizationArtifacts(wannierization_log = symmetry_disabled_log);
        wall_time = 0.0,
        allocated_bytes = 0,
        gc_time = 0.0,
    )
    close(symmetry_disabled_io)
    @test !occursin("[TB SYMMETRY]", read(symmetry_disabled_log, String))

    disabled_config =
        modified_wannierization_config(output_config; num_print_cycles = 0, num_dump_cycles = 0)
    disabled_paths = Base.invokelatest(
        extension.OperatorExport._wannierization_output_paths,
        joinpath(directory, "disabled.wannierization.h5"),
    )
    disabled_log = joinpath(directory, "disabled-observer.out")
    disabled_io = open(disabled_log, "w")
    disabled_observer = Base.invokelatest(
        extension.OperatorExport._wannierization_observer,
        disabled_config,
        fixture.representation,
        disabled_paths,
        disabled_io,
    )
    Base.invokelatest(
        disabled_observer,
        snapshot,
        something(result.restart_state),
        result.history,
        result.diagnostics,
    )
    close(disabled_io)
    @test !isfile(disabled_paths.checkpoint)
    @test isempty(read(disabled_log, String))

    in_progress = WANNIERIZATION.WannierizationResult(
        WANNIERIZATION.IN_PROGRESS_CHECKPOINT,
        result.v_matrix,
        result.wannier_centers_cartesian,
        result.spreads_angstrom2,
        result.history,
        result.diagnostics,
        result.input_summary,
        result.wannier_chk,
        nothing,
    )
    @test_throws ArgumentError WANNIERIZATION.build_wannier_tight_binding_model(
        in_progress,
        fixture.eig,
        fixture.mmn,
    )
    missing_chk = WANNIERIZATION.WannierizationResult(
        WANNIERIZATION.MAX_ITERATIONS,
        result.v_matrix,
        result.wannier_centers_cartesian,
        result.spreads_angstrom2,
        result.history,
        result.diagnostics,
        result.input_summary,
        nothing,
        nothing,
    )
    @test_throws ArgumentError WANNIERIZATION.build_wannier_tight_binding_model(
        missing_chk,
        fixture.eig,
        fixture.mmn,
    )
    nonfinite_values = copy(result.v_matrix)
    nonfinite_values[1] = NaN + 0.0im
    nonfinite = WANNIERIZATION.WannierizationResult(
        WANNIERIZATION.MAX_ITERATIONS,
        nonfinite_values,
        result.wannier_centers_cartesian,
        result.spreads_angstrom2,
        result.history,
        result.diagnostics,
        result.input_summary,
        result.wannier_chk,
        nothing,
    )
    @test_throws ArgumentError Base.invokelatest(
        extension.OperatorExport._export_wannierization_tb,
        nonfinite,
        fixture.eig,
        fixture.mmn,
        output_config,
        paths,
        nothing,
    )

    packed_only_config = WANNIERIZATION._replace_wannierization_config(
        fixture.config;
        checkpoint = (checkpoint_hdf5 = joinpath(directory, "packed-only.wannierization.h5"),),
        output = (tb_output_formats = (), write_model_tb = false),
    )
    packed_only_paths = Base.invokelatest(
        extension.OperatorExport._wannierization_output_paths,
        packed_only_config.checkpoint.checkpoint_hdf5,
    )
    packed_only, optional_tb = Base.invokelatest(
        extension.OperatorExport._export_wannierization_tb,
        result,
        fixture.eig,
        fixture.mmn,
        packed_only_config,
        packed_only_paths,
        nothing,
    )
    @test isfile(packed_only)
    @test optional_tb === nothing
    @test !isfile(packed_only_paths.wannier)
end
