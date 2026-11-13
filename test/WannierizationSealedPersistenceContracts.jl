function test_wannierization_sealed_persistence(fixture, directory)
    # This is a fixed-Z U-state codec/tamper test, not a Z-convergence test.
    # Explicitly skip Z and enter the retained internal sealing path before U.
    sealed_config = modified_wannierization_config(
        fixture.config;
        stage_controls = WANNIERIZATION.WannierizationStageControls(
            dis_num_iter = 0,
            num_iter = 2,
            dis_conv_tol = 1e-8,
            dis_conv_window = 1,
        ),
    )
    sealed_result = WANNIERIZATION._solve_symmetry_adapted_wannierization(
        sealed_config,
        fixture.representation,
        fixture.eig,
        fixture.mmn,
        fixture.plan,
    )
    @test sealed_result.restart_state !== nothing
    @test sealed_result.restart_state.fixed_subspace_projectors !== nothing
    @test sealed_result.restart_state.fixed_subspace_frames !== nothing
    @test sealed_result.restart_state.localization_initial_frames !== nothing
    @test !haskey(sealed_result.input_summary, "localization_initial_frame_sha256")
    sealed_checkpoint = joinpath(directory, "checkpoint-sealed-two-stage.h5")
    WANNIERIZATION.write_wannierization_checkpoint_hdf5(sealed_checkpoint, sealed_result)
    restored_sealed = WANNIERIZATION.read_wannierization_checkpoint_hdf5(sealed_checkpoint)
    @test restored_sealed.input_summary["checkpoint_schema_version"] == "3.0"
    @test restored_sealed.input_summary["localization_gradient_contract"] ==
          "mv_centered_residual_unwrapped_delta_v2"
    @test restored_sealed.input_summary["checkpoint_localization_gradient_contract"] ==
          "mv_centered_residual_unwrapped_delta_v2"
    @test restored_sealed.input_summary["checkpoint_joint_update_contract"] ==
          "type_iv_block_gauss_seidel_v1"
    @test restored_sealed.input_summary["checkpoint_constraint_operation_scope"] == "full"
    @test restored_sealed.input_summary["constraint_operation_scope_history_reset"] ==
          "NOT_APPLICABLE"
    @test restored_sealed.input_summary["restart_eligible"] == "true"
    @test restored_sealed.restart_state.fixed_subspace_projectors ==
          sealed_result.restart_state.fixed_subspace_projectors
    @test restored_sealed.restart_state.fixed_subspace_frames ==
          sealed_result.restart_state.fixed_subspace_frames
    @test restored_sealed.restart_state.localization_initial_frames ==
          sealed_result.restart_state.localization_initial_frames
    @test restored_sealed.restart_state.optimizer_state.previous_u_gradient ==
          sealed_result.restart_state.optimizer_state.previous_u_gradient
    @test restored_sealed.restart_state.optimizer_state.previous_u_direction ==
          sealed_result.restart_state.optimizer_state.previous_u_direction
    @test restored_sealed.restart_state.optimizer_state.u_cg_iteration ==
          sealed_result.restart_state.optimizer_state.u_cg_iteration
    @test restored_sealed.restart_state.optimizer_state.last_cg_restart_reason ==
          sealed_result.restart_state.optimizer_state.last_cg_restart_reason
    @test restored_sealed.restart_state.optimizer_state.u_phase_contract ==
          "mv_centered_residual_unwrapped_delta_v2"
    @test !hasfield(WANNIERIZATION.WannierizationOptimizerState, :u_lbfgs_s_history)
    @test !hasfield(WANNIERIZATION.WannierizationOptimizerState, :u_lbfgs_y_history)
    extension = Base.get_extension(WannierNLQG, :WannierNLQGWannierizationExt)
    @test extension !== nothing
    tampered_sealed_checkpoint = joinpath(directory, "checkpoint-sealed-two-stage-tampered.h5")
    cp(sealed_checkpoint, tampered_sealed_checkpoint)
    chmod(tampered_sealed_checkpoint, 0o600)
    WANNIERIZATION.adopt_wannierization_checkpoint_hdf5(tampered_sealed_checkpoint)
    HDF5.h5open(tampered_sealed_checkpoint, "r+") do handle
        projectors = read(handle["restart_state/fixed_subspace_projectors"])
        projectors[1, 1, 1] += 1.0e-3
        write(handle["restart_state/fixed_subspace_projectors"], projectors)
    end
    @test_throws ArgumentError WANNIERIZATION.read_wannierization_checkpoint_hdf5(
        tampered_sealed_checkpoint,
    )
    # Explicit adoption independently reaches fixed-projector validation.
    @test_throws ArgumentError WANNIERIZATION.adopt_wannierization_checkpoint_hdf5(
        tampered_sealed_checkpoint,
    )

    return nothing
end
