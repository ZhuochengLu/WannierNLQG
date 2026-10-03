using PrecompileTools: @compile_workload
import WannierNLQG
import HDF5
const FIRST_USE_HDF5_MPI_PRESENT = Base.get_extension(HDF5, :MPIExt) !== nothing

# Compile expert entry signatures without executing file writes or MPI initialization.
@compile_workload begin
    if WannierizationInternalSupport.WannierNLQG.FIRST_USE_WORKLOAD_ENABLED
        precompile(
            WorkflowOrchestration.construct_symmetry_adapted_wannier_functions,
            (WorkflowOrchestration.SymmetryAdaptedWannierizationConfig,),
        )
        precompile(
            WorkflowOrchestration.prepare_band_representation,
            (WorkflowOrchestration.BandRepresentationPreparationConfig,),
        )
        # First successful expert calls in the frozen two-k-point fixtures:
        # generate_qe_paw_spn and prepare_exact_wannier_operator_bundle.
        # Compile only; neither native operator nor provenance file is written.
        precompile(
            Tuple{
                typeof(Core.kwcall),
                NamedTuple{
                    (:output_spn_file, :provenance_json, :max_cached_wavefunction_kpoints),
                    Tuple{String, String, Int64},
                },
                typeof(WannierNLQG.Wannierization.generate_qe_paw_spn),
                WannierNLQG.SymmetryFoundation.QuantumEspressoWavefunctionSource,
                String,
            },
        )
        precompile(
            Tuple{
                typeof(Core.kwcall),
                NamedTuple{
                    (
                        :output_spn_file,
                        :provenance_json,
                        :oracle_spn_file,
                        :thresholds,
                        :require_oracle,
                        :formatted,
                        :overwrite,
                        :max_cached_wavefunction_kpoints,
                        :execution,
                    ),
                    Tuple{
                        String,
                        String,
                        Nothing,
                        WannierNLQG.Wannierization.VASPPAWSPNThresholds,
                        Bool,
                        Bool,
                        Bool,
                        Int64,
                        WannierNLQG.Wannierization.WavefunctionPreparationExecutionConfig,
                    },
                },
                typeof(PAWMatrixElements.generate_qe_paw_spn),
                WannierNLQG.SymmetryFoundation.QuantumEspressoWavefunctionSource,
                String,
            },
        )
        precompile(
            WannierNLQG.Wannierization.prepare_exact_wannier_operator_bundle,
            (WannierNLQG.Wannierization.ExactWannierOperatorBundleConfig,),
        )
        precompile(
            OperatorExport.prepare_exact_wannier_operator_bundle,
            (WannierNLQG.Wannierization.ExactWannierOperatorBundleConfig,),
        )
    end
end

# Actual first-solve signatures from the frozen fresh-process probe.
# Compile only: captured IOStream types do not create or retain open handles.
@compile_workload begin
    if WannierizationInternalSupport.WannierNLQG.FIRST_USE_WORKLOAD_ENABLED
        precompile(
            Tuple{
                Type{NamedTuple{(:point_provider, :normalize_coefficients), T} where T <: Tuple},
                Tuple{
                    typeof(
                        WannierNLQGWannierizationExt.RepresentationPreparation.native_vasp_point_provider,
                    ),
                    Bool,
                },
            },
        )
        precompile(
            Tuple{
                typeof(
                    WannierNLQGWannierizationExt.WorkflowOrchestration.construct_symmetry_adapted_wannier_functions,
                ),
                WannierNLQG.Wannierization.SymmetryAdaptedWannierizationConfig,
            },
        )
        precompile(
            Tuple{
                typeof(Core.kwcall),
                NamedTuple{(:accepted_result,), Tuple{Nothing}},
                typeof(
                    WannierNLQGWannierizationExt.WorkflowOrchestration._resolve_wannier_matrix_elements,
                ),
                WannierNLQG.Wannierization.SymmetryAdaptedWannierizationConfig,
                WannierNLQG.WannierProjection.WannierProjectionBasis,
            },
        )
        precompile(
            Tuple{
                typeof(
                    WannierNLQGWannierizationExt.WorkflowOrchestration._operator_oracle_mmn_file,
                ),
                NamedTuple{
                    (
                        :mmn,
                        :amn,
                        :mmn_file,
                        :amn_file,
                        :raw_amn_file,
                        :source_kind,
                        :paw_result,
                        :gauge_sha256,
                        :gauge_provenance_file,
                    ),
                    Tuple{
                        WannierNLQG.IO.WannierMMN,
                        Nothing,
                        String,
                        Nothing,
                        Nothing,
                        String,
                        Nothing,
                        String,
                        Nothing,
                    },
                },
            },
        )
        precompile(
            Tuple{
                typeof(
                    WannierNLQGWannierizationExt.WorkflowOrchestration._requalified_stored_raw_diagnostics,
                ),
                NamedTuple{
                    (
                        :inventory,
                        :raw_diagnostics,
                        :qualification_scope,
                        :requested_policy,
                        :effective_policy,
                        :symmetry_tolerance_status,
                        :preparation_digest,
                    ),
                    Tuple{
                        Nothing,
                        Array{WannierNLQG.SymmetryFoundation.RepresentationRawDiagnostic, 1},
                        WannierNLQG.SymmetryFoundation.BandRepresentationQualificationScope,
                        Symbol,
                        Symbol,
                        Symbol,
                        String,
                    },
                },
                WannierNLQG.SymmetryFoundation.BandRepresentationQualificationScope,
                WannierNLQG.SymmetryFoundation.BandRepresentation,
            },
        )
        precompile(
            Tuple{
                typeof(
                    WannierNLQGWannierizationExt.OperatorExport.operator_output_requires_target_contract,
                ),
                WannierNLQG.Wannierization.SymmetryAdaptedWannierizationConfig,
            },
        )
        precompile(
            Tuple{
                typeof(
                    WannierNLQGWannierizationExt.RepresentationPreparation._effective_wannierization_mode,
                ),
                WannierNLQG.Wannierization.SymmetryAdaptedWannierizationConfig,
            },
        )
        precompile(
            Tuple{
                typeof(Core.kwcall),
                NamedTuple{
                    (:compatibility, :restart),
                    Tuple{WannierNLQG.Wannierization.RepresentationCompatibilityReport, Bool},
                },
                typeof(WannierNLQGWannierizationExt.OperatorExport._open_wannierization_log),
                String,
                WannierNLQG.Wannierization.SymmetryAdaptedWannierizationConfig,
                WannierNLQG.SymmetryFoundation.BandRepresentation,
            },
        )
        precompile(
            Tuple{
                typeof(Core.kwcall),
                NamedTuple{
                    (
                        :amn,
                        :restart,
                        :restart_state,
                        :restart_history,
                        :restart_input_summary,
                        :fixed_subspace,
                        :observer,
                        :compatibility_report,
                        :initialization_amn_sha256,
                        :paw_scdm_input,
                    ),
                    Tuple{
                        Nothing,
                        Nothing,
                        Nothing,
                        Array{WannierNLQG.Wannierization.WannierizationIteration, 1},
                        Base.Dict{String, String},
                        Nothing,
                        WannierNLQGWannierizationExt.WorkflowOrchestration.var"#109#115"{
                            Base.RefValue{String},
                            Base.RefValue{String},
                            Base.RefValue{String},
                            WannierNLQGWannierizationExt.OperatorExport.var"#253#254"{
                                WannierNLQG.Wannierization.SymmetryAdaptedWannierizationConfig,
                                WannierNLQG.SymmetryFoundation.BandRepresentation,
                                NamedTuple{
                                    (
                                        :checkpoint,
                                        :validated,
                                        :log,
                                        :packed,
                                        :wannier90,
                                        :tb_symmetry_json,
                                    ),
                                    NTuple{6, String},
                                },
                                Base.IOStream,
                                Base.Dict{String, String},
                            },
                            Array{WannierNLQG.Wannierization.WannierizationDiagnostic, 1},
                        },
                        WannierNLQG.Wannierization.RepresentationCompatibilityReport,
                        String,
                        Nothing,
                    },
                },
                typeof(
                    WannierNLQGWannierizationExt.SolverCheckpoint._solve_symmetry_adapted_wannierization,
                ),
                WannierNLQG.Wannierization.SymmetryAdaptedWannierizationConfig,
                WannierNLQG.SymmetryFoundation.BandRepresentation,
                WannierNLQG.IO.WannierEIG,
                WannierNLQG.IO.WannierMMN,
                WannierNLQG.SymmetryFoundation.WannierSymmetryPlan,
            },
        )
        precompile(
            Tuple{
                typeof(WannierNLQGWannierizationExt.SolverCheckpoint._prepare_solver_input_summary),
                NamedTuple{
                    (
                        :amn,
                        :compatibility_report,
                        :config,
                        :eig,
                        :fixed_subspace,
                        :initialization_amn_sha256,
                        :mmn,
                        :observer,
                        :paw_scdm_input,
                        :plan,
                        :representation,
                        :restart,
                        :restart_history,
                        :restart_input_summary,
                        :restart_state,
                    ),
                    Tuple{
                        Nothing,
                        WannierNLQG.Wannierization.RepresentationCompatibilityReport,
                        WannierNLQG.Wannierization.SymmetryAdaptedWannierizationConfig,
                        WannierNLQG.IO.WannierEIG,
                        Nothing,
                        String,
                        WannierNLQG.IO.WannierMMN,
                        WannierNLQGWannierizationExt.WorkflowOrchestration.var"#109#115"{
                            Base.RefValue{String},
                            Base.RefValue{String},
                            Base.RefValue{String},
                            WannierNLQGWannierizationExt.OperatorExport.var"#253#254"{
                                WannierNLQG.Wannierization.SymmetryAdaptedWannierizationConfig,
                                WannierNLQG.SymmetryFoundation.BandRepresentation,
                                NamedTuple{
                                    (
                                        :checkpoint,
                                        :validated,
                                        :log,
                                        :packed,
                                        :wannier90,
                                        :tb_symmetry_json,
                                    ),
                                    NTuple{6, String},
                                },
                                Base.IOStream,
                                Base.Dict{String, String},
                            },
                            Array{WannierNLQG.Wannierization.WannierizationDiagnostic, 1},
                        },
                        Nothing,
                        WannierNLQG.SymmetryFoundation.WannierSymmetryPlan,
                        WannierNLQG.SymmetryFoundation.BandRepresentation,
                        Nothing,
                        Array{WannierNLQG.Wannierization.WannierizationIteration, 1},
                        Base.Dict{String, String},
                        Nothing,
                    },
                },
            },
        )
        precompile(
            Tuple{
                typeof(WannierNLQGWannierizationExt.SolverCheckpoint._qualify_solver_inputs),
                NamedTuple{
                    (
                        :amn,
                        :amn_sha256,
                        :apply_symmetry,
                        :basis_sha256,
                        :compatibility_report,
                        :config,
                        :diagnostics,
                        :effective_algorithms,
                        :effective_compatibility_policy,
                        :fixed_subspace,
                        :full_constraint_scope,
                        :input_summary,
                        :mmn,
                        :nb,
                        :nk,
                        :observer,
                        :paw_scdm_input,
                        :plan,
                        :representation,
                        :restart,
                        :restart_history,
                        :restart_input_summary,
                        :restart_state,
                        :spectrum_audit,
                        :target_subspace_authority,
                    ),
                    Tuple{
                        Nothing,
                        String,
                        Bool,
                        String,
                        WannierNLQG.Wannierization.RepresentationCompatibilityReport,
                        WannierNLQG.Wannierization.SymmetryAdaptedWannierizationConfig,
                        Array{WannierNLQG.Wannierization.WannierizationDiagnostic, 1},
                        NamedTuple{
                            (:disentanglement, :localization, :profile, :default_selection_reason),
                            Tuple{Symbol, Symbol, Symbol, String},
                        },
                        Symbol,
                        Nothing,
                        Bool,
                        Base.Dict{String, String},
                        WannierNLQG.IO.WannierMMN,
                        Int64,
                        Int64,
                        WannierNLQGWannierizationExt.WorkflowOrchestration.var"#109#115"{
                            Base.RefValue{String},
                            Base.RefValue{String},
                            Base.RefValue{String},
                            WannierNLQGWannierizationExt.OperatorExport.var"#253#254"{
                                WannierNLQG.Wannierization.SymmetryAdaptedWannierizationConfig,
                                WannierNLQG.SymmetryFoundation.BandRepresentation,
                                NamedTuple{
                                    (
                                        :checkpoint,
                                        :validated,
                                        :log,
                                        :packed,
                                        :wannier90,
                                        :tb_symmetry_json,
                                    ),
                                    NTuple{6, String},
                                },
                                Base.IOStream,
                                Base.Dict{String, String},
                            },
                            Array{WannierNLQG.Wannierization.WannierizationDiagnostic, 1},
                        },
                        Nothing,
                        WannierNLQG.SymmetryFoundation.WannierSymmetryPlan,
                        WannierNLQG.SymmetryFoundation.BandRepresentation,
                        Nothing,
                        Array{WannierNLQG.Wannierization.WannierizationIteration, 1},
                        Base.Dict{String, String},
                        Nothing,
                        WannierNLQGWannierizationExt.SolverCheckpoint.HermitianSpectrumAudit,
                        Bool,
                    },
                },
            },
        )
        precompile(
            Tuple{
                typeof(WannierNLQGWannierizationExt.SolverCheckpoint._initialize_solver_frames),
                NamedTuple{
                    (
                        :amn,
                        :amn_sha256,
                        :apply_symmetry,
                        :basis_sha256,
                        :compatibility,
                        :config,
                        :config_sha256,
                        :diagnostics,
                        :effective_algorithms,
                        :effective_compatibility_policy,
                        :fixed_subspace,
                        :frozen_indices,
                        :frozen_masks,
                        :full_constraint_scope,
                        :input_summary,
                        :mmn,
                        :nb,
                        :nk,
                        :num_wannier,
                        :observer,
                        :outer_indices,
                        :outer_masks,
                        :paw_scdm_input,
                        :plan,
                        :projector_covariance_tolerance,
                        :representation,
                        :restart,
                        :restart_history,
                        :restart_state,
                        :spectrum_audit,
                        :stencil,
                        :tangent_plans,
                        :weights,
                    ),
                    Tuple{
                        Nothing,
                        String,
                        Bool,
                        String,
                        WannierNLQG.Wannierization.RepresentationCompatibilityReport,
                        WannierNLQG.Wannierization.SymmetryAdaptedWannierizationConfig,
                        String,
                        Array{WannierNLQG.Wannierization.WannierizationDiagnostic, 1},
                        NamedTuple{
                            (:disentanglement, :localization, :profile, :default_selection_reason),
                            Tuple{Symbol, Symbol, Symbol, String},
                        },
                        Symbol,
                        Nothing,
                        Array{Array{Int64, 1}, 1},
                        Array{Base.BitArray{1}, 1},
                        Bool,
                        Base.Dict{String, String},
                        WannierNLQG.IO.WannierMMN,
                        Int64,
                        Int64,
                        Int64,
                        WannierNLQGWannierizationExt.WorkflowOrchestration.var"#109#115"{
                            Base.RefValue{String},
                            Base.RefValue{String},
                            Base.RefValue{String},
                            WannierNLQGWannierizationExt.OperatorExport.var"#253#254"{
                                WannierNLQG.Wannierization.SymmetryAdaptedWannierizationConfig,
                                WannierNLQG.SymmetryFoundation.BandRepresentation,
                                NamedTuple{
                                    (
                                        :checkpoint,
                                        :validated,
                                        :log,
                                        :packed,
                                        :wannier90,
                                        :tb_symmetry_json,
                                    ),
                                    NTuple{6, String},
                                },
                                Base.IOStream,
                                Base.Dict{String, String},
                            },
                            Array{WannierNLQG.Wannierization.WannierizationDiagnostic, 1},
                        },
                        Array{Array{Int64, 1}, 1},
                        Array{Base.BitArray{1}, 1},
                        Nothing,
                        WannierNLQG.SymmetryFoundation.WannierSymmetryPlan,
                        Float64,
                        WannierNLQG.SymmetryFoundation.BandRepresentation,
                        Nothing,
                        Array{WannierNLQG.Wannierization.WannierizationIteration, 1},
                        Nothing,
                        WannierNLQGWannierizationExt.SolverCheckpoint.HermitianSpectrumAudit,
                        WannierNLQG.Wannierization.WannierizationFiniteDifferenceStencil,
                        Array{
                            Union{
                                Nothing,
                                WannierNLQGWannierizationExt.SolverCheckpoint.TargetSymmetryTangentPlan,
                            },
                            1,
                        },
                        Array{Float64, 1},
                    },
                },
            },
        )
        precompile(
            Tuple{
                typeof(WannierNLQGWannierizationExt.SolverCheckpoint._initialize_solver_optimizer),
                NamedTuple{
                    (
                        :amn_sha256,
                        :apply_symmetry,
                        :basis_sha256,
                        :compatibility,
                        :config,
                        :config_sha256,
                        :diagnostics,
                        :effective_algorithms,
                        :effective_compatibility_policy,
                        :fixed_mode,
                        :fixed_source_qualified,
                        :fixed_subspace,
                        :frames,
                        :frozen_indices,
                        :full_constraint_scope,
                        :included_bands,
                        :initialization_report,
                        :input_summary,
                        :mmn,
                        :nb,
                        :nk,
                        :num_wannier,
                        :observer,
                        :outer_indices,
                        :plan,
                        :projector_covariance_tolerance,
                        :raw_amn_reference_frames,
                        :representation,
                        :restart_history,
                        :restart_state,
                        :spectrum_audit,
                        :stencil,
                        :tangent_plans,
                        :weights,
                        :z_previous,
                    ),
                    Tuple{
                        String,
                        Bool,
                        String,
                        WannierNLQG.Wannierization.RepresentationCompatibilityReport,
                        WannierNLQG.Wannierization.SymmetryAdaptedWannierizationConfig,
                        String,
                        Array{WannierNLQG.Wannierization.WannierizationDiagnostic, 1},
                        NamedTuple{
                            (:disentanglement, :localization, :profile, :default_selection_reason),
                            Tuple{Symbol, Symbol, Symbol, String},
                        },
                        Symbol,
                        Bool,
                        Bool,
                        Nothing,
                        Array{Array{Base.Complex{Float64}, 2}, 1},
                        Array{Array{Int64, 1}, 1},
                        Bool,
                        Array{Base.BitArray{1}, 1},
                        Nothing,
                        Base.Dict{String, String},
                        WannierNLQG.IO.WannierMMN,
                        Int64,
                        Int64,
                        Int64,
                        WannierNLQGWannierizationExt.WorkflowOrchestration.var"#109#115"{
                            Base.RefValue{String},
                            Base.RefValue{String},
                            Base.RefValue{String},
                            WannierNLQGWannierizationExt.OperatorExport.var"#253#254"{
                                WannierNLQG.Wannierization.SymmetryAdaptedWannierizationConfig,
                                WannierNLQG.SymmetryFoundation.BandRepresentation,
                                NamedTuple{
                                    (
                                        :checkpoint,
                                        :validated,
                                        :log,
                                        :packed,
                                        :wannier90,
                                        :tb_symmetry_json,
                                    ),
                                    NTuple{6, String},
                                },
                                Base.IOStream,
                                Base.Dict{String, String},
                            },
                            Array{WannierNLQG.Wannierization.WannierizationDiagnostic, 1},
                        },
                        Array{Array{Int64, 1}, 1},
                        WannierNLQG.SymmetryFoundation.WannierSymmetryPlan,
                        Float64,
                        Nothing,
                        WannierNLQG.SymmetryFoundation.BandRepresentation,
                        Array{WannierNLQG.Wannierization.WannierizationIteration, 1},
                        Nothing,
                        WannierNLQGWannierizationExt.SolverCheckpoint.HermitianSpectrumAudit,
                        WannierNLQG.Wannierization.WannierizationFiniteDifferenceStencil,
                        Array{
                            Union{
                                Nothing,
                                WannierNLQGWannierizationExt.SolverCheckpoint.TargetSymmetryTangentPlan,
                            },
                            1,
                        },
                        Array{Float64, 1},
                        Nothing,
                    },
                },
            },
        )
        precompile(
            Tuple{
                typeof(WannierNLQGWannierizationExt.SolverCheckpoint._run_solver_iterations),
                NamedTuple{
                    (
                        :actual_u_mix_ratio,
                        :actual_z_mix_ratio,
                        :amn_sha256,
                        :anderson_residual_history,
                        :anderson_z_history,
                        :apply_symmetry,
                        :basis_sha256,
                        :best_polar_centers,
                        :best_polar_frames,
                        :best_polar_objective,
                        :best_polar_spreads,
                        :centers,
                        :compatibility,
                        :config,
                        :config_sha256,
                        :convergence_values,
                        :retained_disentanglement_nonconverged,
                        :diagnostics,
                        :disentanglement_objective_history,
                        :effective_algorithms,
                        :effective_compatibility_policy,
                        :epoch,
                        :fixed_complete,
                        :fixed_mode,
                        :fixed_source_qualified,
                        :fixed_stability_count,
                        :fixed_stationary,
                        :fixed_stationary_count,
                        :frames,
                        :frozen_indices,
                        :full_constraint_scope,
                        :gradient_fallback_active,
                        :gradient_steps,
                        :grassmann_actual_decrease_history,
                        :grassmann_gradient_history,
                        :grassmann_predicted_decrease_history,
                        :grassmann_projector_change_history,
                        :grassmann_radius_history,
                        :grassmann_ratio_history,
                        :grassmann_trust_radius,
                        :history,
                        :improvement_streak,
                        :included_bands,
                        :initialization_report,
                        :input_summary,
                        :last_accepted_u_step_scale,
                        :last_anderson_reason,
                        :last_cg_beta,
                        :last_cg_restart_reason,
                        :last_u_optimizer_restart_reason,
                        :latest_restart_state,
                        :localization_initial_frames,
                        :localization_objective_history,
                        :localization_projector_drift_history,
                        :localization_reference_frames,
                        :localization_trial_accepted,
                        :localization_trial_actual_changes,
                        :localization_trial_directional_derivatives,
                        :localization_trial_iterations,
                        :localization_trial_objectives,
                        :localization_trial_required_changes,
                        :localization_trial_step_scales,
                        :localization_trial_sweeps,
                        :minimum_localization_diagonal_phase_margin,
                        :mmn,
                        :nb,
                        :nk,
                        :num_wannier,
                        :observer,
                        :optimizer_phase,
                        :outer_indices,
                        :phase_branch_backtracking_extension_count,
                        :plan,
                        :previous_merit,
                        :previous_u_direction,
                        :previous_u_gradient,
                        :prior_elapsed,
                        :projector_covariance_tolerance,
                        :rejected_steps,
                        :representation,
                        :residual_reference,
                        :sealed_subspace_frames,
                        :sealed_subspace_projectors,
                        :spectrum_audit,
                        :spreads,
                        :stage_stop_reason,
                        :start_iteration,
                        :started_ns,
                        :stencil,
                        :tangent_plans,
                        :trajectory_previous_frames,
                        :trajectory_two_step_frames,
                        :two_stage_complete,
                        :u_active_orbit_count,
                        :u_branch_signature,
                        :u_cg_iteration,
                        :u_cg_restart_count,
                        :u_generalized_gradient_rms,
                        :u_lbfgs_restart_count,
                        :u_lbfgs_rho_history,
                        :u_lbfgs_s_history,
                        :u_lbfgs_y_history,
                        :u_stability_count,
                        :u_steps,
                        :wannier90_reference_omega_i,
                        :wannier90_reference_overlaps,
                        :wannier90_reference_unitaries,
                        :weights,
                        :z_previous,
                        :z_stability_count,
                        :z_steps,
                    ),
                    Tuple{
                        Float64,
                        Float64,
                        String,
                        Array{Float64, 2},
                        Array{Float64, 2},
                        Bool,
                        String,
                        Array{Float64, 2},
                        Array{Array{Base.Complex{Float64}, 2}, 1},
                        Float64,
                        Array{Float64, 1},
                        Array{Float64, 2},
                        WannierNLQG.Wannierization.RepresentationCompatibilityReport,
                        WannierNLQG.Wannierization.SymmetryAdaptedWannierizationConfig,
                        String,
                        Array{Array{Float64, 1}, 1},
                        Bool,
                        Array{WannierNLQG.Wannierization.WannierizationDiagnostic, 1},
                        Array{Float64, 1},
                        NamedTuple{
                            (:disentanglement, :localization, :profile, :default_selection_reason),
                            Tuple{Symbol, Symbol, Symbol, String},
                        },
                        Symbol,
                        Int64,
                        Bool,
                        Bool,
                        Bool,
                        Int64,
                        Bool,
                        Int64,
                        Array{Array{Base.Complex{Float64}, 2}, 1},
                        Array{Array{Int64, 1}, 1},
                        Bool,
                        Bool,
                        Int64,
                        Array{Float64, 1},
                        Array{Float64, 1},
                        Array{Float64, 1},
                        Array{Float64, 1},
                        Array{Float64, 1},
                        Array{Float64, 1},
                        Float64,
                        Array{WannierNLQG.Wannierization.WannierizationIteration, 1},
                        Int64,
                        Array{Base.BitArray{1}, 1},
                        Nothing,
                        Base.Dict{String, String},
                        Float64,
                        Symbol,
                        Float64,
                        Symbol,
                        Symbol,
                        WannierNLQG.Wannierization.WannierizationRestartState,
                        Nothing,
                        Array{Float64, 1},
                        Array{Float64, 1},
                        Array{Array{Base.Complex{Float64}, 2}, 1},
                        Array{Bool, 1},
                        Array{Float64, 1},
                        Array{Float64, 1},
                        Array{Int64, 1},
                        Array{Float64, 1},
                        Array{Float64, 1},
                        Array{Float64, 1},
                        Array{Int64, 1},
                        Float64,
                        WannierNLQG.IO.WannierMMN,
                        Int64,
                        Int64,
                        Int64,
                        WannierNLQGWannierizationExt.WorkflowOrchestration.var"#109#115"{
                            Base.RefValue{String},
                            Base.RefValue{String},
                            Base.RefValue{String},
                            WannierNLQGWannierizationExt.OperatorExport.var"#253#254"{
                                WannierNLQG.Wannierization.SymmetryAdaptedWannierizationConfig,
                                WannierNLQG.SymmetryFoundation.BandRepresentation,
                                NamedTuple{
                                    (
                                        :checkpoint,
                                        :validated,
                                        :log,
                                        :packed,
                                        :wannier90,
                                        :tb_symmetry_json,
                                    ),
                                    NTuple{6, String},
                                },
                                Base.IOStream,
                                Base.Dict{String, String},
                            },
                            Array{WannierNLQG.Wannierization.WannierizationDiagnostic, 1},
                        },
                        Symbol,
                        Array{Array{Int64, 1}, 1},
                        Int64,
                        WannierNLQG.SymmetryFoundation.WannierSymmetryPlan,
                        Float64,
                        Nothing,
                        Nothing,
                        Float64,
                        Float64,
                        Int64,
                        WannierNLQG.SymmetryFoundation.BandRepresentation,
                        NTuple{4, Float64},
                        Nothing,
                        Nothing,
                        WannierNLQGWannierizationExt.SolverCheckpoint.HermitianSpectrumAudit,
                        Array{Float64, 1},
                        Nothing,
                        Int64,
                        UInt64,
                        WannierNLQG.Wannierization.WannierizationFiniteDifferenceStencil,
                        Array{
                            Union{
                                Nothing,
                                WannierNLQGWannierizationExt.SolverCheckpoint.TargetSymmetryTangentPlan,
                            },
                            1,
                        },
                        Nothing,
                        Nothing,
                        Bool,
                        Int64,
                        String,
                        Int64,
                        Int64,
                        Float64,
                        Int64,
                        Array{Float64, 1},
                        Array{Array{Array{Base.Complex{Float64}, 2}, 1}, 1},
                        Array{Array{Array{Base.Complex{Float64}, 2}, 1}, 1},
                        Int64,
                        Int64,
                        Nothing,
                        Nothing,
                        Nothing,
                        Array{Float64, 1},
                        Nothing,
                        Int64,
                        Int64,
                    },
                },
            },
        )
        precompile(
            Tuple{
                typeof(WannierNLQGWannierizationExt.SolverCheckpoint._propose_solver_iteration),
                NamedTuple{
                    (
                        :actual_u_mix_ratio,
                        :actual_z_mix_ratio,
                        :amn_sha256,
                        :anderson_residual_history,
                        :anderson_z_history,
                        :apply_symmetry,
                        :basis_sha256,
                        :best_polar_centers,
                        :best_polar_frames,
                        :best_polar_objective,
                        :best_polar_spreads,
                        :centers,
                        :compatibility,
                        :config,
                        :config_sha256,
                        :convergence_values,
                        :retained_disentanglement_nonconverged,
                        :diagnostics,
                        :disentanglement_objective_history,
                        :effective_algorithms,
                        :effective_compatibility_policy,
                        :epoch,
                        :fixed_complete,
                        :fixed_mode,
                        :fixed_source_qualified,
                        :fixed_stability_count,
                        :fixed_stationary,
                        :fixed_stationary_count,
                        :frames,
                        :frozen_indices,
                        :full_constraint_scope,
                        :gradient_fallback_active,
                        :gradient_steps,
                        :grassmann_actual_decrease_history,
                        :grassmann_gradient_history,
                        :grassmann_predicted_decrease_history,
                        :grassmann_projector_change_history,
                        :grassmann_radius_history,
                        :grassmann_ratio_history,
                        :grassmann_trust_radius,
                        :history,
                        :improvement_streak,
                        :included_bands,
                        :initialization_report,
                        :input_summary,
                        :last_accepted_u_step_scale,
                        :last_anderson_reason,
                        :last_cg_beta,
                        :last_cg_restart_reason,
                        :last_u_optimizer_restart_reason,
                        :latest_restart_state,
                        :localization_initial_frames,
                        :localization_objective_history,
                        :localization_projector_drift_history,
                        :localization_reference_frames,
                        :localization_trial_accepted,
                        :localization_trial_actual_changes,
                        :localization_trial_directional_derivatives,
                        :localization_trial_iterations,
                        :localization_trial_objectives,
                        :localization_trial_required_changes,
                        :localization_trial_step_scales,
                        :localization_trial_sweeps,
                        :minimum_localization_diagonal_phase_margin,
                        :mmn,
                        :nb,
                        :nk,
                        :num_wannier,
                        :observer,
                        :optimizer_phase,
                        :outer_indices,
                        :phase_branch_backtracking_extension_count,
                        :plan,
                        :previous_merit,
                        :previous_u_direction,
                        :previous_u_gradient,
                        :prior_elapsed,
                        :projector_covariance_tolerance,
                        :rejected_steps,
                        :representation,
                        :residual_reference,
                        :sealed_subspace_frames,
                        :sealed_subspace_projectors,
                        :spectrum_audit,
                        :spreads,
                        :stage_stop_reason,
                        :start_iteration,
                        :started_ns,
                        :stencil,
                        :tangent_plans,
                        :trajectory_previous_frames,
                        :trajectory_two_step_frames,
                        :two_stage_complete,
                        :u_active_orbit_count,
                        :u_branch_signature,
                        :u_cg_iteration,
                        :u_cg_restart_count,
                        :u_generalized_gradient_rms,
                        :u_lbfgs_restart_count,
                        :u_lbfgs_rho_history,
                        :u_lbfgs_s_history,
                        :u_lbfgs_y_history,
                        :u_stability_count,
                        :u_steps,
                        :wannier90_reference_omega_i,
                        :wannier90_reference_overlaps,
                        :wannier90_reference_unitaries,
                        :weights,
                        :z_previous,
                        :z_stability_count,
                        :z_steps,
                        :iteration,
                    ),
                    Tuple{
                        Float64,
                        Float64,
                        String,
                        Array{Float64, 2},
                        Array{Float64, 2},
                        Bool,
                        String,
                        Array{Float64, 2},
                        Array{Array{Base.Complex{Float64}, 2}, 1},
                        Float64,
                        Array{Float64, 1},
                        Array{Float64, 2},
                        WannierNLQG.Wannierization.RepresentationCompatibilityReport,
                        WannierNLQG.Wannierization.SymmetryAdaptedWannierizationConfig,
                        String,
                        Array{Array{Float64, 1}, 1},
                        Bool,
                        Array{WannierNLQG.Wannierization.WannierizationDiagnostic, 1},
                        Array{Float64, 1},
                        NamedTuple{
                            (:disentanglement, :localization, :profile, :default_selection_reason),
                            Tuple{Symbol, Symbol, Symbol, String},
                        },
                        Symbol,
                        Int64,
                        Bool,
                        Bool,
                        Bool,
                        Int64,
                        Bool,
                        Int64,
                        Array{Array{Base.Complex{Float64}, 2}, 1},
                        Array{Array{Int64, 1}, 1},
                        Bool,
                        Bool,
                        Int64,
                        Array{Float64, 1},
                        Array{Float64, 1},
                        Array{Float64, 1},
                        Array{Float64, 1},
                        Array{Float64, 1},
                        Array{Float64, 1},
                        Float64,
                        Array{WannierNLQG.Wannierization.WannierizationIteration, 1},
                        Int64,
                        Array{Base.BitArray{1}, 1},
                        Nothing,
                        Base.Dict{String, String},
                        Float64,
                        Symbol,
                        Float64,
                        Symbol,
                        Symbol,
                        WannierNLQG.Wannierization.WannierizationRestartState,
                        Nothing,
                        Array{Float64, 1},
                        Array{Float64, 1},
                        Array{Array{Base.Complex{Float64}, 2}, 1},
                        Array{Bool, 1},
                        Array{Float64, 1},
                        Array{Float64, 1},
                        Array{Int64, 1},
                        Array{Float64, 1},
                        Array{Float64, 1},
                        Array{Float64, 1},
                        Array{Int64, 1},
                        Float64,
                        WannierNLQG.IO.WannierMMN,
                        Int64,
                        Int64,
                        Int64,
                        WannierNLQGWannierizationExt.WorkflowOrchestration.var"#109#115"{
                            Base.RefValue{String},
                            Base.RefValue{String},
                            Base.RefValue{String},
                            WannierNLQGWannierizationExt.OperatorExport.var"#253#254"{
                                WannierNLQG.Wannierization.SymmetryAdaptedWannierizationConfig,
                                WannierNLQG.SymmetryFoundation.BandRepresentation,
                                NamedTuple{
                                    (
                                        :checkpoint,
                                        :validated,
                                        :log,
                                        :packed,
                                        :wannier90,
                                        :tb_symmetry_json,
                                    ),
                                    NTuple{6, String},
                                },
                                Base.IOStream,
                                Base.Dict{String, String},
                            },
                            Array{WannierNLQG.Wannierization.WannierizationDiagnostic, 1},
                        },
                        Symbol,
                        Array{Array{Int64, 1}, 1},
                        Int64,
                        WannierNLQG.SymmetryFoundation.WannierSymmetryPlan,
                        Float64,
                        Nothing,
                        Nothing,
                        Float64,
                        Float64,
                        Int64,
                        WannierNLQG.SymmetryFoundation.BandRepresentation,
                        NTuple{4, Float64},
                        Nothing,
                        Nothing,
                        WannierNLQGWannierizationExt.SolverCheckpoint.HermitianSpectrumAudit,
                        Array{Float64, 1},
                        Nothing,
                        Int64,
                        UInt64,
                        WannierNLQG.Wannierization.WannierizationFiniteDifferenceStencil,
                        Array{
                            Union{
                                Nothing,
                                WannierNLQGWannierizationExt.SolverCheckpoint.TargetSymmetryTangentPlan,
                            },
                            1,
                        },
                        Nothing,
                        Nothing,
                        Bool,
                        Int64,
                        String,
                        Int64,
                        Int64,
                        Float64,
                        Int64,
                        Array{Float64, 1},
                        Array{Array{Array{Base.Complex{Float64}, 2}, 1}, 1},
                        Array{Array{Array{Base.Complex{Float64}, 2}, 1}, 1},
                        Int64,
                        Int64,
                        Nothing,
                        Nothing,
                        Nothing,
                        Array{Float64, 1},
                        Nothing,
                        Int64,
                        Int64,
                        Int64,
                    },
                },
            },
        )
        precompile(
            Tuple{
                WannierNLQGWannierizationExt.SolverCheckpoint.var"#306#310"{
                    Bool,
                    WannierNLQG.IO.WannierMMN,
                    Array{Float64, 1},
                    Array{Array{Int64, 1}, 1},
                    Array{Array{Base.Complex{Float64}, 2}, 1},
                    Nothing,
                    Array{Array{Base.Complex{Float64}, 2}, 1},
                    Symbol,
                },
                Int64,
            },
        )
        precompile(
            Tuple{
                Type{Base.Generator{I, F} where {F} where I},
                WannierNLQGWannierizationExt.SolverCheckpoint.var"#389#395"{
                    Array{Array{Float64, 1}, 1},
                },
                Base.OneTo{Int64},
            },
        )
        precompile(
            Tuple{
                typeof(Base.maximum),
                Base.Generator{
                    Base.OneTo{Int64},
                    WannierNLQGWannierizationExt.SolverCheckpoint.var"#389#395"{
                        Array{Array{Float64, 1}, 1},
                    },
                },
            },
        )
        precompile(
            Tuple{
                typeof(Base.ntuple),
                WannierNLQGWannierizationExt.SolverCheckpoint.var"#391#397"{
                    NTuple{4, Float64},
                    NTuple{4, Float64},
                },
                Int64,
            },
        )
        precompile(
            Tuple{
                Type{Base.Generator{I, F} where {F} where I},
                WannierNLQGWannierizationExt.SolverCheckpoint.var"#392#398"{
                    NTuple{4, Float64},
                    NTuple{4, Float64},
                },
                Base.UnitRange{Int64},
            },
        )
        precompile(
            Tuple{
                typeof(Base.maximum),
                Base.Generator{
                    Base.UnitRange{Int64},
                    WannierNLQGWannierizationExt.SolverCheckpoint.var"#392#398"{
                        NTuple{4, Float64},
                        NTuple{4, Float64},
                    },
                },
            },
        )
        precompile(
            Tuple{
                typeof(WannierNLQGWannierizationExt.SolverCheckpoint._accept_solver_iteration),
                NamedTuple{
                    (
                        :accepted,
                        :accepted_anderson_context,
                        :accepted_anderson_fallback,
                        :accepted_anderson_reason,
                        :accepted_anderson_used,
                        :accepted_joint_reason,
                        :accepted_joint_transport_maximum_condition,
                        :accepted_joint_transport_minimum_singular_value,
                        :accepted_joint_z_backtracking_steps,
                        :accepted_merit,
                        :accepted_reference,
                        :accepted_residual_history,
                        :accepted_z,
                        :accepted_z_history,
                        :actual_u_mix_ratio,
                        :actual_z_mix_ratio,
                        :amn_sha256,
                        :apply_symmetry,
                        :basis_sha256,
                        :best_polar_centers,
                        :best_polar_frames,
                        :best_polar_objective,
                        :best_polar_spreads,
                        :compatibility,
                        :config,
                        :config_sha256,
                        :convergence_values,
                        :retained_disentanglement_nonconverged,
                        :diagnostics,
                        :disentanglement_objective_history,
                        :effective_algorithms,
                        :effective_compatibility_policy,
                        :epoch,
                        :fixed_complete,
                        :fixed_mode,
                        :fixed_source_qualified,
                        :fixed_stability_count,
                        :fixed_stationary,
                        :fixed_stationary_count,
                        :frozen_indices,
                        :full_constraint_scope,
                        :gradient_fallback_active,
                        :gradient_steps,
                        :grassmann_actual_decrease_history,
                        :grassmann_gradient_history,
                        :grassmann_predicted_decrease_history,
                        :grassmann_projector_change_history,
                        :grassmann_radius_history,
                        :grassmann_ratio_history,
                        :grassmann_trust_radius,
                        :history,
                        :improvement_streak,
                        :included_bands,
                        :initialization_report,
                        :input_summary,
                        :irreducible,
                        :iteration,
                        :iteration_phase,
                        :joint_mode,
                        :last_accepted_u_step_scale,
                        :latest_restart_state,
                        :localization_initial_frames,
                        :localization_objective_history,
                        :localization_projector_drift_history,
                        :localization_reference_frames,
                        :localization_trial_accepted,
                        :localization_trial_actual_changes,
                        :localization_trial_directional_derivatives,
                        :localization_trial_iterations,
                        :localization_trial_objectives,
                        :localization_trial_required_changes,
                        :localization_trial_step_scales,
                        :localization_trial_sweeps,
                        :minimum_localization_diagonal_phase_margin,
                        :mmn,
                        :nb,
                        :nk,
                        :num_wannier,
                        :observer,
                        :optimizer_phase,
                        :outer_indices,
                        :phase_branch_backtracking_extension_count,
                        :plan,
                        :prior_elapsed,
                        :projector_covariance_tolerance,
                        :proposal_z_mix_ratio,
                        :rejected_steps,
                        :representation,
                        :sealed_subspace_frames,
                        :sealed_subspace_projectors,
                        :spectrum_audit,
                        :stage_stop_reason,
                        :start_iteration,
                        :started_ns,
                        :stencil,
                        :tangent_plans,
                        :trajectory_previous_frames,
                        :trajectory_two_step_frames,
                        :two_stage_complete,
                        :u_stability_count,
                        :u_steps,
                        :wannier90_reference_omega_i,
                        :wannier90_reference_overlaps,
                        :wannier90_reference_unitaries,
                        :weights,
                        :z_residual,
                        :z_stability_count,
                        :z_steps,
                    ),
                    Tuple{
                        NamedTuple{
                            (
                                :success,
                                :code,
                                :frames,
                                :centers,
                                :spreads,
                                :directional,
                                :u_residual,
                                :gradient_rms,
                                :projection_converged,
                                :projection_iterations,
                                :projection_residual,
                                :completed_sweeps,
                                :accepted_step_scale,
                                :backtracking_steps,
                                :trial_objective,
                                :accepted_objective,
                                :localization_spectra,
                                :localization_ranks,
                                :localization_conditions,
                                :raw_eigenphases,
                                :aligned_eigenphases,
                                :raw_geodesic_distances,
                                :aligned_geodesic_distances,
                                :block_permutations,
                                :block_phases,
                                :polar_fallback_triggered,
                                :active_localization_algorithm,
                                :base_objective,
                                :trial_zero_objective,
                                :trial_zero_frame_residual,
                                :attempted_step_scales,
                                :attempted_objectives,
                                :attempted_required_changes,
                                :attempted_actual_changes,
                                :attempted_directional_derivatives,
                                :attempted_sweeps,
                                :attempted_accepted,
                                :directional_derivative,
                                :fixed_projector_drift,
                                :accepted_required_change,
                                :accepted_actual_change,
                                :minimum_diagonal_phase_margin,
                                :minimum_phase_kpoint,
                                :minimum_phase_neighbor,
                                :minimum_phase_wannier,
                                :minimum_phase_value,
                                :branch_safe_backtracking_triggered,
                                :previous_u_gradient,
                                :previous_u_direction,
                                :u_cg_iteration,
                                :u_cg_restart_count,
                                :cg_beta,
                                :cg_restarted,
                                :cg_restart_reason,
                                :cg_descent_cosine,
                                :kstar_gradient_rms,
                                :maximum_kstar_gradient_rms,
                                :maximum_kstar_gradient_index,
                                :transport_minimum_singular_value,
                                :transport_maximum_condition,
                                :transported_omega_i,
                                :u_phase_contract,
                                :u_active_orbit_sha256,
                                :u_active_orbit_count,
                                :generalized_gradient_rms,
                                :u_lbfgs_s_history,
                                :u_lbfgs_y_history,
                                :u_lbfgs_rho_history,
                                :u_lbfgs_restart_count,
                                :u_optimizer_restart_reason,
                                :subspaces,
                                :raw_amn_alignment_applied,
                                :raw_amn_alignment_minimum_singular_value,
                                :raw_amn_alignment_maximum_condition,
                                :raw_amn_alignment_projector_drift,
                                :raw_amn_alignment_completion_count,
                                :localization_initial_frames,
                                :corepresentation_transport_applied,
                                :corepresentation_transport_minimum_singular_value,
                                :corepresentation_transport_maximum_condition,
                                :corepresentation_transport_projector_drift,
                                :corepresentation_transport_target_symmetry,
                                :spread_total,
                                :spread_std,
                                :covariance_error,
                                :projector_residual,
                                :wcc_step,
                                :spread_step,
                                :z_boundary_gap,
                            ),
                            Tuple{
                                Bool,
                                Symbol,
                                Array{Array{Base.Complex{Float64}, 2}, 1},
                                Array{Float64, 2},
                                Array{Float64, 1},
                                Nothing,
                                Float64,
                                Float64,
                                Bool,
                                Int64,
                                Float64,
                                Int64,
                                Float64,
                                Int64,
                                Float64,
                                Float64,
                                Array{Array{Float64, 1}, 1},
                                Array{Int64, 1},
                                Array{Float64, 1},
                                Array{Array{Float64, 1}, 1},
                                Array{Array{Float64, 1}, 1},
                                Array{Float64, 1},
                                Array{Float64, 1},
                                Array{Array{Int64, 1}, 1},
                                Array{Array{Float64, 1}, 1},
                                Bool,
                                Symbol,
                                Float64,
                                Float64,
                                Float64,
                                Array{Float64, 1},
                                Array{Float64, 1},
                                Array{Float64, 1},
                                Array{Float64, 1},
                                Array{Float64, 1},
                                Array{Int64, 1},
                                Array{Bool, 1},
                                Float64,
                                Float64,
                                Float64,
                                Float64,
                                Float64,
                                Int64,
                                Int64,
                                Int64,
                                Float64,
                                Bool,
                                Nothing,
                                Nothing,
                                Int64,
                                Int64,
                                Float64,
                                Bool,
                                Symbol,
                                Float64,
                                Array{Float64, 1},
                                Float64,
                                Int64,
                                Float64,
                                Float64,
                                Float64,
                                String,
                                String,
                                Int64,
                                Float64,
                                Array{Array{Array{Base.Complex{Float64}, 2}, 1}, 1},
                                Array{Array{Array{Base.Complex{Float64}, 2}, 1}, 1},
                                Array{Float64, 1},
                                Int64,
                                Symbol,
                                Array{Array{Base.Complex{Float64}, 2}, 1},
                                Bool,
                                Float64,
                                Float64,
                                Float64,
                                Int64,
                                Nothing,
                                Bool,
                                Vararg{Float64, 11},
                            },
                        },
                        Base.Dict{String, String},
                        Bool,
                        Symbol,
                        Bool,
                        Symbol,
                        Float64,
                        Float64,
                        Int64,
                        Float64,
                        NTuple{4, Float64},
                        Array{Float64, 2},
                        Array{Array{Base.Complex{Float64}, 2}, 1},
                        Array{Float64, 2},
                        Float64,
                        Float64,
                        String,
                        Bool,
                        String,
                        Array{Float64, 2},
                        Array{Array{Base.Complex{Float64}, 2}, 1},
                        Float64,
                        Array{Float64, 1},
                        WannierNLQG.Wannierization.RepresentationCompatibilityReport,
                        WannierNLQG.Wannierization.SymmetryAdaptedWannierizationConfig,
                        String,
                        Array{Array{Float64, 1}, 1},
                        Bool,
                        Array{WannierNLQG.Wannierization.WannierizationDiagnostic, 1},
                        Array{Float64, 1},
                        NamedTuple{
                            (:disentanglement, :localization, :profile, :default_selection_reason),
                            Tuple{Symbol, Symbol, Symbol, String},
                        },
                        Symbol,
                        Int64,
                        Bool,
                        Bool,
                        Bool,
                        Int64,
                        Bool,
                        Int64,
                        Array{Array{Int64, 1}, 1},
                        Bool,
                        Bool,
                        Int64,
                        Array{Float64, 1},
                        Array{Float64, 1},
                        Array{Float64, 1},
                        Array{Float64, 1},
                        Array{Float64, 1},
                        Array{Float64, 1},
                        Float64,
                        Array{WannierNLQG.Wannierization.WannierizationIteration, 1},
                        Int64,
                        Array{Base.BitArray{1}, 1},
                        Nothing,
                        Base.Dict{String, String},
                        Array{Int64, 1},
                        Int64,
                        Symbol,
                        Bool,
                        Float64,
                        WannierNLQG.Wannierization.WannierizationRestartState,
                        Nothing,
                        Array{Float64, 1},
                        Array{Float64, 1},
                        Array{Array{Base.Complex{Float64}, 2}, 1},
                        Array{Bool, 1},
                        Array{Float64, 1},
                        Array{Float64, 1},
                        Array{Int64, 1},
                        Array{Float64, 1},
                        Array{Float64, 1},
                        Array{Float64, 1},
                        Array{Int64, 1},
                        Float64,
                        WannierNLQG.IO.WannierMMN,
                        Int64,
                        Int64,
                        Int64,
                        WannierNLQGWannierizationExt.WorkflowOrchestration.var"#109#115"{
                            Base.RefValue{String},
                            Base.RefValue{String},
                            Base.RefValue{String},
                            WannierNLQGWannierizationExt.OperatorExport.var"#253#254"{
                                WannierNLQG.Wannierization.SymmetryAdaptedWannierizationConfig,
                                WannierNLQG.SymmetryFoundation.BandRepresentation,
                                NamedTuple{
                                    (
                                        :checkpoint,
                                        :validated,
                                        :log,
                                        :packed,
                                        :wannier90,
                                        :tb_symmetry_json,
                                    ),
                                    NTuple{6, String},
                                },
                                Base.IOStream,
                                Base.Dict{String, String},
                            },
                            Array{WannierNLQG.Wannierization.WannierizationDiagnostic, 1},
                        },
                        Symbol,
                        Array{Array{Int64, 1}, 1},
                        Int64,
                        WannierNLQG.SymmetryFoundation.WannierSymmetryPlan,
                        Float64,
                        Float64,
                        Float64,
                        Int64,
                        WannierNLQG.SymmetryFoundation.BandRepresentation,
                        Nothing,
                        Nothing,
                        WannierNLQGWannierizationExt.SolverCheckpoint.HermitianSpectrumAudit,
                        Nothing,
                        Int64,
                        UInt64,
                        WannierNLQG.Wannierization.WannierizationFiniteDifferenceStencil,
                        Array{
                            Union{
                                Nothing,
                                WannierNLQGWannierizationExt.SolverCheckpoint.TargetSymmetryTangentPlan,
                            },
                            1,
                        },
                        Nothing,
                        Nothing,
                        Bool,
                        Int64,
                        Int64,
                        Nothing,
                        Nothing,
                        Nothing,
                        Array{Float64, 1},
                        Float64,
                        Int64,
                        Int64,
                    },
                },
            },
        )
        precompile(
            Tuple{
                typeof(Core.kwcall),
                NamedTuple{
                    (
                        :fixed_subspace_projectors,
                        :fixed_subspace_frames,
                        :localization_initial_frames,
                    ),
                    Tuple{Nothing, Nothing, Nothing},
                },
                typeof(WannierNLQGWannierizationExt.SolverCheckpoint._restart_state),
                Int64,
                Array{Array{Base.Complex{Float64}, 2}, 1},
                Array{Array{Base.Complex{Float64}, 2}, 1},
                Array{Float64, 2},
                Array{Float64, 1},
                Array{Array{Float64, 1}, 1},
                Array{Base.BitArray{1}, 1},
                Float64,
                String,
                String,
                WannierNLQG.Wannierization.WannierizationFiniteDifferenceStencil,
                String,
                String,
                WannierNLQG.Wannierization.WannierizationOptimizerState,
            },
        )
        precompile(
            Tuple{
                typeof(WannierNLQGWannierizationExt.SolverCheckpoint._finish_solver_iteration),
                NamedTuple{
                    (
                        :actual_u_mix_ratio,
                        :actual_z_mix_ratio,
                        :amn_sha256,
                        :anderson_residual_history,
                        :anderson_z_history,
                        :apply_symmetry,
                        :basis_sha256,
                        :best_polar_centers,
                        :best_polar_frames,
                        :best_polar_objective,
                        :best_polar_spreads,
                        :centers,
                        :compatibility,
                        :config,
                        :config_sha256,
                        :convergence_values,
                        :retained_disentanglement_nonconverged,
                        :diagnostics,
                        :disentanglement_objective_history,
                        :effective_algorithms,
                        :effective_compatibility_policy,
                        :epoch,
                        :fixed_complete,
                        :fixed_mode,
                        :fixed_source_qualified,
                        :fixed_stability_count,
                        :fixed_stationary,
                        :fixed_stationary_count,
                        :frames,
                        :frozen_indices,
                        :full_constraint_scope,
                        :gradient_fallback_active,
                        :gradient_steps,
                        :grassmann_actual_decrease_history,
                        :grassmann_gradient_history,
                        :grassmann_predicted_decrease_history,
                        :grassmann_projector_change_history,
                        :grassmann_radius_history,
                        :grassmann_ratio_history,
                        :grassmann_trust_radius,
                        :history,
                        :improvement_streak,
                        :included_bands,
                        :initialization_report,
                        :input_summary,
                        :iteration,
                        :last_accepted_u_step_scale,
                        :last_anderson_reason,
                        :last_cg_beta,
                        :last_cg_restart_reason,
                        :last_u_optimizer_restart_reason,
                        :latest_restart_state,
                        :localization_initial_frames,
                        :localization_objective_history,
                        :localization_projector_drift_history,
                        :localization_reference_frames,
                        :localization_trial_accepted,
                        :localization_trial_actual_changes,
                        :localization_trial_directional_derivatives,
                        :localization_trial_iterations,
                        :localization_trial_objectives,
                        :localization_trial_required_changes,
                        :localization_trial_step_scales,
                        :localization_trial_sweeps,
                        :minimum_localization_diagonal_phase_margin,
                        :mmn,
                        :nb,
                        :nk,
                        :num_wannier,
                        :observer,
                        :optimizer_phase,
                        :outer_indices,
                        :phase_branch_backtracking_extension_count,
                        :plan,
                        :previous_merit,
                        :previous_u_direction,
                        :previous_u_gradient,
                        :prior_elapsed,
                        :projector_covariance_tolerance,
                        :rejected_steps,
                        :representation,
                        :residual_reference,
                        :result,
                        :sealed_subspace_frames,
                        :sealed_subspace_projectors,
                        :spectrum_audit,
                        :spreads,
                        :stage_stop_reason,
                        :start_iteration,
                        :started_ns,
                        :stencil,
                        :tangent_plans,
                        :total_spread_window_std,
                        :trajectory_previous_frames,
                        :trajectory_two_step_frames,
                        :two_stage_complete,
                        :u_active_orbit_count,
                        :u_branch_signature,
                        :u_cg_iteration,
                        :u_cg_restart_count,
                        :u_generalized_gradient_rms,
                        :u_lbfgs_restart_count,
                        :u_lbfgs_rho_history,
                        :u_lbfgs_s_history,
                        :u_lbfgs_y_history,
                        :u_stability_count,
                        :u_steps,
                        :wannier90_reference_omega_i,
                        :wannier90_reference_overlaps,
                        :wannier90_reference_unitaries,
                        :weights,
                        :z_previous,
                        :z_stability_count,
                        :z_steps,
                    ),
                    Tuple{
                        Float64,
                        Float64,
                        String,
                        Array{Float64, 2},
                        Array{Float64, 2},
                        Bool,
                        String,
                        Array{Float64, 2},
                        Array{Array{Base.Complex{Float64}, 2}, 1},
                        Float64,
                        Array{Float64, 1},
                        Array{Float64, 2},
                        WannierNLQG.Wannierization.RepresentationCompatibilityReport,
                        WannierNLQG.Wannierization.SymmetryAdaptedWannierizationConfig,
                        String,
                        Array{Array{Float64, 1}, 1},
                        Bool,
                        Array{WannierNLQG.Wannierization.WannierizationDiagnostic, 1},
                        Array{Float64, 1},
                        NamedTuple{
                            (:disentanglement, :localization, :profile, :default_selection_reason),
                            Tuple{Symbol, Symbol, Symbol, String},
                        },
                        Symbol,
                        Int64,
                        Bool,
                        Bool,
                        Bool,
                        Int64,
                        Bool,
                        Int64,
                        Array{Array{Base.Complex{Float64}, 2}, 1},
                        Array{Array{Int64, 1}, 1},
                        Bool,
                        Bool,
                        Int64,
                        Array{Float64, 1},
                        Array{Float64, 1},
                        Array{Float64, 1},
                        Array{Float64, 1},
                        Array{Float64, 1},
                        Array{Float64, 1},
                        Float64,
                        Array{WannierNLQG.Wannierization.WannierizationIteration, 1},
                        Int64,
                        Array{Base.BitArray{1}, 1},
                        Nothing,
                        Base.Dict{String, String},
                        Int64,
                        Float64,
                        Symbol,
                        Float64,
                        Symbol,
                        Symbol,
                        WannierNLQG.Wannierization.WannierizationRestartState,
                        Nothing,
                        Array{Float64, 1},
                        Array{Float64, 1},
                        Array{Array{Base.Complex{Float64}, 2}, 1},
                        Array{Bool, 1},
                        Array{Float64, 1},
                        Array{Float64, 1},
                        Array{Int64, 1},
                        Array{Float64, 1},
                        Array{Float64, 1},
                        Array{Float64, 1},
                        Array{Int64, 1},
                        Float64,
                        WannierNLQG.IO.WannierMMN,
                        Int64,
                        Int64,
                        Int64,
                        WannierNLQGWannierizationExt.WorkflowOrchestration.var"#109#115"{
                            Base.RefValue{String},
                            Base.RefValue{String},
                            Base.RefValue{String},
                            WannierNLQGWannierizationExt.OperatorExport.var"#253#254"{
                                WannierNLQG.Wannierization.SymmetryAdaptedWannierizationConfig,
                                WannierNLQG.SymmetryFoundation.BandRepresentation,
                                NamedTuple{
                                    (
                                        :checkpoint,
                                        :validated,
                                        :log,
                                        :packed,
                                        :wannier90,
                                        :tb_symmetry_json,
                                    ),
                                    NTuple{6, String},
                                },
                                Base.IOStream,
                                Base.Dict{String, String},
                            },
                            Array{WannierNLQG.Wannierization.WannierizationDiagnostic, 1},
                        },
                        Symbol,
                        Array{Array{Int64, 1}, 1},
                        Int64,
                        WannierNLQG.SymmetryFoundation.WannierSymmetryPlan,
                        Float64,
                        Nothing,
                        Nothing,
                        Float64,
                        Float64,
                        Int64,
                        WannierNLQG.SymmetryFoundation.BandRepresentation,
                        NTuple{4, Float64},
                        NamedTuple{
                            (
                                :success,
                                :code,
                                :frames,
                                :centers,
                                :spreads,
                                :directional,
                                :u_residual,
                                :gradient_rms,
                                :projection_converged,
                                :projection_iterations,
                                :projection_residual,
                                :completed_sweeps,
                                :accepted_step_scale,
                                :backtracking_steps,
                                :trial_objective,
                                :accepted_objective,
                                :localization_spectra,
                                :localization_ranks,
                                :localization_conditions,
                                :raw_eigenphases,
                                :aligned_eigenphases,
                                :raw_geodesic_distances,
                                :aligned_geodesic_distances,
                                :block_permutations,
                                :block_phases,
                                :polar_fallback_triggered,
                                :active_localization_algorithm,
                                :base_objective,
                                :trial_zero_objective,
                                :trial_zero_frame_residual,
                                :attempted_step_scales,
                                :attempted_objectives,
                                :attempted_required_changes,
                                :attempted_actual_changes,
                                :attempted_directional_derivatives,
                                :attempted_sweeps,
                                :attempted_accepted,
                                :directional_derivative,
                                :fixed_projector_drift,
                                :accepted_required_change,
                                :accepted_actual_change,
                                :minimum_diagonal_phase_margin,
                                :minimum_phase_kpoint,
                                :minimum_phase_neighbor,
                                :minimum_phase_wannier,
                                :minimum_phase_value,
                                :branch_safe_backtracking_triggered,
                                :previous_u_gradient,
                                :previous_u_direction,
                                :u_cg_iteration,
                                :u_cg_restart_count,
                                :cg_beta,
                                :cg_restarted,
                                :cg_restart_reason,
                                :cg_descent_cosine,
                                :kstar_gradient_rms,
                                :maximum_kstar_gradient_rms,
                                :maximum_kstar_gradient_index,
                                :transport_minimum_singular_value,
                                :transport_maximum_condition,
                                :transported_omega_i,
                                :u_phase_contract,
                                :u_active_orbit_sha256,
                                :u_active_orbit_count,
                                :generalized_gradient_rms,
                                :u_lbfgs_s_history,
                                :u_lbfgs_y_history,
                                :u_lbfgs_rho_history,
                                :u_lbfgs_restart_count,
                                :u_optimizer_restart_reason,
                                :subspaces,
                                :raw_amn_alignment_applied,
                                :raw_amn_alignment_minimum_singular_value,
                                :raw_amn_alignment_maximum_condition,
                                :raw_amn_alignment_projector_drift,
                                :raw_amn_alignment_completion_count,
                                :localization_initial_frames,
                                :corepresentation_transport_applied,
                                :corepresentation_transport_minimum_singular_value,
                                :corepresentation_transport_maximum_condition,
                                :corepresentation_transport_projector_drift,
                                :corepresentation_transport_target_symmetry,
                                :spread_total,
                                :spread_std,
                                :covariance_error,
                                :projector_residual,
                                :wcc_step,
                                :spread_step,
                                :z_boundary_gap,
                            ),
                            Tuple{
                                Bool,
                                Symbol,
                                Array{Array{Base.Complex{Float64}, 2}, 1},
                                Array{Float64, 2},
                                Array{Float64, 1},
                                Nothing,
                                Float64,
                                Float64,
                                Bool,
                                Int64,
                                Float64,
                                Int64,
                                Float64,
                                Int64,
                                Float64,
                                Float64,
                                Array{Array{Float64, 1}, 1},
                                Array{Int64, 1},
                                Array{Float64, 1},
                                Array{Array{Float64, 1}, 1},
                                Array{Array{Float64, 1}, 1},
                                Array{Float64, 1},
                                Array{Float64, 1},
                                Array{Array{Int64, 1}, 1},
                                Array{Array{Float64, 1}, 1},
                                Bool,
                                Symbol,
                                Float64,
                                Float64,
                                Float64,
                                Array{Float64, 1},
                                Array{Float64, 1},
                                Array{Float64, 1},
                                Array{Float64, 1},
                                Array{Float64, 1},
                                Array{Int64, 1},
                                Array{Bool, 1},
                                Float64,
                                Float64,
                                Float64,
                                Float64,
                                Float64,
                                Int64,
                                Int64,
                                Int64,
                                Float64,
                                Bool,
                                Nothing,
                                Nothing,
                                Int64,
                                Int64,
                                Float64,
                                Bool,
                                Symbol,
                                Float64,
                                Array{Float64, 1},
                                Float64,
                                Int64,
                                Float64,
                                Float64,
                                Float64,
                                String,
                                String,
                                Int64,
                                Float64,
                                Array{Array{Array{Base.Complex{Float64}, 2}, 1}, 1},
                                Array{Array{Array{Base.Complex{Float64}, 2}, 1}, 1},
                                Array{Float64, 1},
                                Int64,
                                Symbol,
                                Array{Array{Base.Complex{Float64}, 2}, 1},
                                Bool,
                                Float64,
                                Float64,
                                Float64,
                                Int64,
                                Nothing,
                                Bool,
                                Vararg{Float64, 11},
                            },
                        },
                        Nothing,
                        Nothing,
                        WannierNLQGWannierizationExt.SolverCheckpoint.HermitianSpectrumAudit,
                        Array{Float64, 1},
                        Nothing,
                        Int64,
                        UInt64,
                        WannierNLQG.Wannierization.WannierizationFiniteDifferenceStencil,
                        Array{
                            Union{
                                Nothing,
                                WannierNLQGWannierizationExt.SolverCheckpoint.TargetSymmetryTangentPlan,
                            },
                            1,
                        },
                        Float64,
                        Array{Array{Base.Complex{Float64}, 2}, 1},
                        Nothing,
                        Bool,
                        Int64,
                        String,
                        Int64,
                        Int64,
                        Float64,
                        Int64,
                        Array{Float64, 1},
                        Array{Array{Array{Base.Complex{Float64}, 2}, 1}, 1},
                        Array{Array{Array{Base.Complex{Float64}, 2}, 1}, 1},
                        Int64,
                        Int64,
                        Nothing,
                        Nothing,
                        Nothing,
                        Array{Float64, 1},
                        Array{Array{Base.Complex{Float64}, 2}, 1},
                        Int64,
                        Int64,
                    },
                },
            },
        )
        precompile(
            Tuple{
                typeof(WannierNLQGWannierizationExt.SolverCheckpoint._propose_solver_iteration),
                NamedTuple{
                    (
                        :actual_u_mix_ratio,
                        :actual_z_mix_ratio,
                        :amn_sha256,
                        :anderson_residual_history,
                        :anderson_z_history,
                        :apply_symmetry,
                        :basis_sha256,
                        :best_polar_centers,
                        :best_polar_frames,
                        :best_polar_objective,
                        :best_polar_spreads,
                        :centers,
                        :compatibility,
                        :config,
                        :config_sha256,
                        :convergence_values,
                        :retained_disentanglement_nonconverged,
                        :diagnostics,
                        :disentanglement_objective_history,
                        :effective_algorithms,
                        :effective_compatibility_policy,
                        :epoch,
                        :fixed_complete,
                        :fixed_mode,
                        :fixed_source_qualified,
                        :fixed_stability_count,
                        :fixed_stationary,
                        :fixed_stationary_count,
                        :frames,
                        :frozen_indices,
                        :full_constraint_scope,
                        :gradient_fallback_active,
                        :gradient_steps,
                        :grassmann_actual_decrease_history,
                        :grassmann_gradient_history,
                        :grassmann_predicted_decrease_history,
                        :grassmann_projector_change_history,
                        :grassmann_radius_history,
                        :grassmann_ratio_history,
                        :grassmann_trust_radius,
                        :history,
                        :improvement_streak,
                        :included_bands,
                        :initialization_report,
                        :input_summary,
                        :last_accepted_u_step_scale,
                        :last_anderson_reason,
                        :last_cg_beta,
                        :last_cg_restart_reason,
                        :last_u_optimizer_restart_reason,
                        :latest_restart_state,
                        :localization_initial_frames,
                        :localization_objective_history,
                        :localization_projector_drift_history,
                        :localization_reference_frames,
                        :localization_trial_accepted,
                        :localization_trial_actual_changes,
                        :localization_trial_directional_derivatives,
                        :localization_trial_iterations,
                        :localization_trial_objectives,
                        :localization_trial_required_changes,
                        :localization_trial_step_scales,
                        :localization_trial_sweeps,
                        :minimum_localization_diagonal_phase_margin,
                        :mmn,
                        :nb,
                        :nk,
                        :num_wannier,
                        :observer,
                        :optimizer_phase,
                        :outer_indices,
                        :phase_branch_backtracking_extension_count,
                        :plan,
                        :previous_merit,
                        :previous_u_direction,
                        :previous_u_gradient,
                        :prior_elapsed,
                        :projector_covariance_tolerance,
                        :rejected_steps,
                        :representation,
                        :residual_reference,
                        :sealed_subspace_frames,
                        :sealed_subspace_projectors,
                        :spectrum_audit,
                        :spreads,
                        :stage_stop_reason,
                        :start_iteration,
                        :started_ns,
                        :stencil,
                        :tangent_plans,
                        :trajectory_previous_frames,
                        :trajectory_two_step_frames,
                        :two_stage_complete,
                        :u_active_orbit_count,
                        :u_branch_signature,
                        :u_cg_iteration,
                        :u_cg_restart_count,
                        :u_generalized_gradient_rms,
                        :u_lbfgs_restart_count,
                        :u_lbfgs_rho_history,
                        :u_lbfgs_s_history,
                        :u_lbfgs_y_history,
                        :u_stability_count,
                        :u_steps,
                        :wannier90_reference_omega_i,
                        :wannier90_reference_overlaps,
                        :wannier90_reference_unitaries,
                        :weights,
                        :z_previous,
                        :z_stability_count,
                        :z_steps,
                        :iteration,
                    ),
                    Tuple{
                        Float64,
                        Float64,
                        String,
                        Array{Float64, 2},
                        Array{Float64, 2},
                        Bool,
                        String,
                        Array{Float64, 2},
                        Array{Array{Base.Complex{Float64}, 2}, 1},
                        Float64,
                        Array{Float64, 1},
                        Array{Float64, 2},
                        WannierNLQG.Wannierization.RepresentationCompatibilityReport,
                        WannierNLQG.Wannierization.SymmetryAdaptedWannierizationConfig,
                        String,
                        Array{Array{Float64, 1}, 1},
                        Bool,
                        Array{WannierNLQG.Wannierization.WannierizationDiagnostic, 1},
                        Array{Float64, 1},
                        NamedTuple{
                            (:disentanglement, :localization, :profile, :default_selection_reason),
                            Tuple{Symbol, Symbol, Symbol, String},
                        },
                        Symbol,
                        Int64,
                        Bool,
                        Bool,
                        Bool,
                        Int64,
                        Bool,
                        Int64,
                        Array{Array{Base.Complex{Float64}, 2}, 1},
                        Array{Array{Int64, 1}, 1},
                        Bool,
                        Bool,
                        Int64,
                        Array{Float64, 1},
                        Array{Float64, 1},
                        Array{Float64, 1},
                        Array{Float64, 1},
                        Array{Float64, 1},
                        Array{Float64, 1},
                        Float64,
                        Array{WannierNLQG.Wannierization.WannierizationIteration, 1},
                        Int64,
                        Array{Base.BitArray{1}, 1},
                        Nothing,
                        Base.Dict{String, String},
                        Float64,
                        Symbol,
                        Float64,
                        Symbol,
                        Symbol,
                        WannierNLQG.Wannierization.WannierizationRestartState,
                        Nothing,
                        Array{Float64, 1},
                        Array{Float64, 1},
                        Array{Array{Base.Complex{Float64}, 2}, 1},
                        Array{Bool, 1},
                        Array{Float64, 1},
                        Array{Float64, 1},
                        Array{Int64, 1},
                        Array{Float64, 1},
                        Array{Float64, 1},
                        Array{Float64, 1},
                        Array{Int64, 1},
                        Float64,
                        WannierNLQG.IO.WannierMMN,
                        Int64,
                        Int64,
                        Int64,
                        WannierNLQGWannierizationExt.WorkflowOrchestration.var"#109#115"{
                            Base.RefValue{String},
                            Base.RefValue{String},
                            Base.RefValue{String},
                            WannierNLQGWannierizationExt.OperatorExport.var"#253#254"{
                                WannierNLQG.Wannierization.SymmetryAdaptedWannierizationConfig,
                                WannierNLQG.SymmetryFoundation.BandRepresentation,
                                NamedTuple{
                                    (
                                        :checkpoint,
                                        :validated,
                                        :log,
                                        :packed,
                                        :wannier90,
                                        :tb_symmetry_json,
                                    ),
                                    NTuple{6, String},
                                },
                                Base.IOStream,
                                Base.Dict{String, String},
                            },
                            Array{WannierNLQG.Wannierization.WannierizationDiagnostic, 1},
                        },
                        Symbol,
                        Array{Array{Int64, 1}, 1},
                        Int64,
                        WannierNLQG.SymmetryFoundation.WannierSymmetryPlan,
                        Float64,
                        Nothing,
                        Nothing,
                        Float64,
                        Float64,
                        Int64,
                        WannierNLQG.SymmetryFoundation.BandRepresentation,
                        NTuple{4, Float64},
                        Nothing,
                        Nothing,
                        WannierNLQGWannierizationExt.SolverCheckpoint.HermitianSpectrumAudit,
                        Array{Float64, 1},
                        Nothing,
                        Int64,
                        UInt64,
                        WannierNLQG.Wannierization.WannierizationFiniteDifferenceStencil,
                        Array{
                            Union{
                                Nothing,
                                WannierNLQGWannierizationExt.SolverCheckpoint.TargetSymmetryTangentPlan,
                            },
                            1,
                        },
                        Array{Array{Base.Complex{Float64}, 2}, 1},
                        Nothing,
                        Bool,
                        Int64,
                        String,
                        Int64,
                        Int64,
                        Float64,
                        Int64,
                        Array{Float64, 1},
                        Array{Array{Array{Base.Complex{Float64}, 2}, 1}, 1},
                        Array{Array{Array{Base.Complex{Float64}, 2}, 1}, 1},
                        Int64,
                        Int64,
                        Nothing,
                        Nothing,
                        Nothing,
                        Array{Float64, 1},
                        Array{Array{Base.Complex{Float64}, 2}, 1},
                        Int64,
                        Int64,
                        Int64,
                    },
                },
            },
        )
        precompile(
            Tuple{
                Type{Base.Generator{I, F} where {F} where I},
                WannierNLQGWannierizationExt.SolverCheckpoint.var"#387#393"{
                    Array{Array{Base.Complex{Float64}, 2}, 1},
                    Array{Array{Base.Complex{Float64}, 2}, 1},
                },
                Array{Int64, 1},
            },
        )
        precompile(
            Tuple{
                typeof(Base.maximum),
                Base.Generator{
                    Array{Int64, 1},
                    WannierNLQGWannierizationExt.SolverCheckpoint.var"#387#393"{
                        Array{Array{Base.Complex{Float64}, 2}, 1},
                        Array{Array{Base.Complex{Float64}, 2}, 1},
                    },
                },
            },
        )
        precompile(
            Tuple{
                typeof(WannierNLQGWannierizationExt.SolverCheckpoint._accept_solver_iteration),
                NamedTuple{
                    (
                        :accepted,
                        :accepted_anderson_context,
                        :accepted_anderson_fallback,
                        :accepted_anderson_reason,
                        :accepted_anderson_used,
                        :accepted_joint_reason,
                        :accepted_joint_transport_maximum_condition,
                        :accepted_joint_transport_minimum_singular_value,
                        :accepted_joint_z_backtracking_steps,
                        :accepted_merit,
                        :accepted_reference,
                        :accepted_residual_history,
                        :accepted_z,
                        :accepted_z_history,
                        :actual_u_mix_ratio,
                        :actual_z_mix_ratio,
                        :amn_sha256,
                        :apply_symmetry,
                        :basis_sha256,
                        :best_polar_centers,
                        :best_polar_frames,
                        :best_polar_objective,
                        :best_polar_spreads,
                        :compatibility,
                        :config,
                        :config_sha256,
                        :convergence_values,
                        :retained_disentanglement_nonconverged,
                        :diagnostics,
                        :disentanglement_objective_history,
                        :effective_algorithms,
                        :effective_compatibility_policy,
                        :epoch,
                        :fixed_complete,
                        :fixed_mode,
                        :fixed_source_qualified,
                        :fixed_stability_count,
                        :fixed_stationary,
                        :fixed_stationary_count,
                        :frozen_indices,
                        :full_constraint_scope,
                        :gradient_fallback_active,
                        :gradient_steps,
                        :grassmann_actual_decrease_history,
                        :grassmann_gradient_history,
                        :grassmann_predicted_decrease_history,
                        :grassmann_projector_change_history,
                        :grassmann_radius_history,
                        :grassmann_ratio_history,
                        :grassmann_trust_radius,
                        :history,
                        :improvement_streak,
                        :included_bands,
                        :initialization_report,
                        :input_summary,
                        :irreducible,
                        :iteration,
                        :iteration_phase,
                        :joint_mode,
                        :last_accepted_u_step_scale,
                        :latest_restart_state,
                        :localization_initial_frames,
                        :localization_objective_history,
                        :localization_projector_drift_history,
                        :localization_reference_frames,
                        :localization_trial_accepted,
                        :localization_trial_actual_changes,
                        :localization_trial_directional_derivatives,
                        :localization_trial_iterations,
                        :localization_trial_objectives,
                        :localization_trial_required_changes,
                        :localization_trial_step_scales,
                        :localization_trial_sweeps,
                        :minimum_localization_diagonal_phase_margin,
                        :mmn,
                        :nb,
                        :nk,
                        :num_wannier,
                        :observer,
                        :optimizer_phase,
                        :outer_indices,
                        :phase_branch_backtracking_extension_count,
                        :plan,
                        :prior_elapsed,
                        :projector_covariance_tolerance,
                        :proposal_z_mix_ratio,
                        :rejected_steps,
                        :representation,
                        :sealed_subspace_frames,
                        :sealed_subspace_projectors,
                        :spectrum_audit,
                        :stage_stop_reason,
                        :start_iteration,
                        :started_ns,
                        :stencil,
                        :tangent_plans,
                        :trajectory_previous_frames,
                        :trajectory_two_step_frames,
                        :two_stage_complete,
                        :u_stability_count,
                        :u_steps,
                        :wannier90_reference_omega_i,
                        :wannier90_reference_overlaps,
                        :wannier90_reference_unitaries,
                        :weights,
                        :z_residual,
                        :z_stability_count,
                        :z_steps,
                    ),
                    Tuple{
                        NamedTuple{
                            (
                                :success,
                                :code,
                                :frames,
                                :centers,
                                :spreads,
                                :directional,
                                :u_residual,
                                :gradient_rms,
                                :projection_converged,
                                :projection_iterations,
                                :projection_residual,
                                :completed_sweeps,
                                :accepted_step_scale,
                                :backtracking_steps,
                                :trial_objective,
                                :accepted_objective,
                                :localization_spectra,
                                :localization_ranks,
                                :localization_conditions,
                                :raw_eigenphases,
                                :aligned_eigenphases,
                                :raw_geodesic_distances,
                                :aligned_geodesic_distances,
                                :block_permutations,
                                :block_phases,
                                :polar_fallback_triggered,
                                :active_localization_algorithm,
                                :base_objective,
                                :trial_zero_objective,
                                :trial_zero_frame_residual,
                                :attempted_step_scales,
                                :attempted_objectives,
                                :attempted_required_changes,
                                :attempted_actual_changes,
                                :attempted_directional_derivatives,
                                :attempted_sweeps,
                                :attempted_accepted,
                                :directional_derivative,
                                :fixed_projector_drift,
                                :accepted_required_change,
                                :accepted_actual_change,
                                :minimum_diagonal_phase_margin,
                                :minimum_phase_kpoint,
                                :minimum_phase_neighbor,
                                :minimum_phase_wannier,
                                :minimum_phase_value,
                                :branch_safe_backtracking_triggered,
                                :previous_u_gradient,
                                :previous_u_direction,
                                :u_cg_iteration,
                                :u_cg_restart_count,
                                :cg_beta,
                                :cg_restarted,
                                :cg_restart_reason,
                                :cg_descent_cosine,
                                :kstar_gradient_rms,
                                :maximum_kstar_gradient_rms,
                                :maximum_kstar_gradient_index,
                                :transport_minimum_singular_value,
                                :transport_maximum_condition,
                                :transported_omega_i,
                                :u_phase_contract,
                                :u_active_orbit_sha256,
                                :u_active_orbit_count,
                                :generalized_gradient_rms,
                                :u_lbfgs_s_history,
                                :u_lbfgs_y_history,
                                :u_lbfgs_rho_history,
                                :u_lbfgs_restart_count,
                                :u_optimizer_restart_reason,
                                :subspaces,
                                :raw_amn_alignment_applied,
                                :raw_amn_alignment_minimum_singular_value,
                                :raw_amn_alignment_maximum_condition,
                                :raw_amn_alignment_projector_drift,
                                :raw_amn_alignment_completion_count,
                                :localization_initial_frames,
                                :corepresentation_transport_applied,
                                :corepresentation_transport_minimum_singular_value,
                                :corepresentation_transport_maximum_condition,
                                :corepresentation_transport_projector_drift,
                                :corepresentation_transport_target_symmetry,
                                :spread_total,
                                :spread_std,
                                :covariance_error,
                                :projector_residual,
                                :wcc_step,
                                :spread_step,
                                :z_boundary_gap,
                            ),
                            Tuple{
                                Bool,
                                Symbol,
                                Array{Array{Base.Complex{Float64}, 2}, 1},
                                Array{Float64, 2},
                                Array{Float64, 1},
                                Nothing,
                                Float64,
                                Float64,
                                Bool,
                                Int64,
                                Float64,
                                Int64,
                                Float64,
                                Int64,
                                Float64,
                                Float64,
                                Array{Array{Float64, 1}, 1},
                                Array{Int64, 1},
                                Array{Float64, 1},
                                Array{Array{Float64, 1}, 1},
                                Array{Array{Float64, 1}, 1},
                                Array{Float64, 1},
                                Array{Float64, 1},
                                Array{Array{Int64, 1}, 1},
                                Array{Array{Float64, 1}, 1},
                                Bool,
                                Symbol,
                                Float64,
                                Float64,
                                Float64,
                                Array{Float64, 1},
                                Array{Float64, 1},
                                Array{Float64, 1},
                                Array{Float64, 1},
                                Array{Float64, 1},
                                Array{Int64, 1},
                                Array{Bool, 1},
                                Float64,
                                Float64,
                                Float64,
                                Float64,
                                Float64,
                                Int64,
                                Int64,
                                Int64,
                                Float64,
                                Bool,
                                Nothing,
                                Nothing,
                                Int64,
                                Int64,
                                Float64,
                                Bool,
                                Symbol,
                                Float64,
                                Array{Float64, 1},
                                Float64,
                                Int64,
                                Float64,
                                Float64,
                                Float64,
                                String,
                                String,
                                Int64,
                                Float64,
                                Array{Array{Array{Base.Complex{Float64}, 2}, 1}, 1},
                                Array{Array{Array{Base.Complex{Float64}, 2}, 1}, 1},
                                Array{Float64, 1},
                                Int64,
                                Symbol,
                                Array{Array{Base.Complex{Float64}, 2}, 1},
                                Bool,
                                Float64,
                                Float64,
                                Float64,
                                Int64,
                                Nothing,
                                Bool,
                                Vararg{Float64, 11},
                            },
                        },
                        Base.Dict{String, String},
                        Bool,
                        Symbol,
                        Bool,
                        Symbol,
                        Float64,
                        Float64,
                        Int64,
                        Float64,
                        NTuple{4, Float64},
                        Array{Float64, 2},
                        Array{Array{Base.Complex{Float64}, 2}, 1},
                        Array{Float64, 2},
                        Float64,
                        Float64,
                        String,
                        Bool,
                        String,
                        Array{Float64, 2},
                        Array{Array{Base.Complex{Float64}, 2}, 1},
                        Float64,
                        Array{Float64, 1},
                        WannierNLQG.Wannierization.RepresentationCompatibilityReport,
                        WannierNLQG.Wannierization.SymmetryAdaptedWannierizationConfig,
                        String,
                        Array{Array{Float64, 1}, 1},
                        Bool,
                        Array{WannierNLQG.Wannierization.WannierizationDiagnostic, 1},
                        Array{Float64, 1},
                        NamedTuple{
                            (:disentanglement, :localization, :profile, :default_selection_reason),
                            Tuple{Symbol, Symbol, Symbol, String},
                        },
                        Symbol,
                        Int64,
                        Bool,
                        Bool,
                        Bool,
                        Int64,
                        Bool,
                        Int64,
                        Array{Array{Int64, 1}, 1},
                        Bool,
                        Bool,
                        Int64,
                        Array{Float64, 1},
                        Array{Float64, 1},
                        Array{Float64, 1},
                        Array{Float64, 1},
                        Array{Float64, 1},
                        Array{Float64, 1},
                        Float64,
                        Array{WannierNLQG.Wannierization.WannierizationIteration, 1},
                        Int64,
                        Array{Base.BitArray{1}, 1},
                        Nothing,
                        Base.Dict{String, String},
                        Array{Int64, 1},
                        Int64,
                        Symbol,
                        Bool,
                        Float64,
                        WannierNLQG.Wannierization.WannierizationRestartState,
                        Nothing,
                        Array{Float64, 1},
                        Array{Float64, 1},
                        Array{Array{Base.Complex{Float64}, 2}, 1},
                        Array{Bool, 1},
                        Array{Float64, 1},
                        Array{Float64, 1},
                        Array{Int64, 1},
                        Array{Float64, 1},
                        Array{Float64, 1},
                        Array{Float64, 1},
                        Array{Int64, 1},
                        Float64,
                        WannierNLQG.IO.WannierMMN,
                        Int64,
                        Int64,
                        Int64,
                        WannierNLQGWannierizationExt.WorkflowOrchestration.var"#109#115"{
                            Base.RefValue{String},
                            Base.RefValue{String},
                            Base.RefValue{String},
                            WannierNLQGWannierizationExt.OperatorExport.var"#253#254"{
                                WannierNLQG.Wannierization.SymmetryAdaptedWannierizationConfig,
                                WannierNLQG.SymmetryFoundation.BandRepresentation,
                                NamedTuple{
                                    (
                                        :checkpoint,
                                        :validated,
                                        :log,
                                        :packed,
                                        :wannier90,
                                        :tb_symmetry_json,
                                    ),
                                    NTuple{6, String},
                                },
                                Base.IOStream,
                                Base.Dict{String, String},
                            },
                            Array{WannierNLQG.Wannierization.WannierizationDiagnostic, 1},
                        },
                        Symbol,
                        Array{Array{Int64, 1}, 1},
                        Int64,
                        WannierNLQG.SymmetryFoundation.WannierSymmetryPlan,
                        Float64,
                        Float64,
                        Float64,
                        Int64,
                        WannierNLQG.SymmetryFoundation.BandRepresentation,
                        Nothing,
                        Nothing,
                        WannierNLQGWannierizationExt.SolverCheckpoint.HermitianSpectrumAudit,
                        Nothing,
                        Int64,
                        UInt64,
                        WannierNLQG.Wannierization.WannierizationFiniteDifferenceStencil,
                        Array{
                            Union{
                                Nothing,
                                WannierNLQGWannierizationExt.SolverCheckpoint.TargetSymmetryTangentPlan,
                            },
                            1,
                        },
                        Array{Array{Base.Complex{Float64}, 2}, 1},
                        Nothing,
                        Bool,
                        Int64,
                        Int64,
                        Nothing,
                        Nothing,
                        Nothing,
                        Array{Float64, 1},
                        Float64,
                        Int64,
                        Int64,
                    },
                },
            },
        )
        precompile(
            Tuple{
                Type{Base.Generator{I, F} where {F} where I},
                WannierNLQGWannierizationExt.SolverCheckpoint.var"#399#401",
                Array{Array{Base.Complex{Float64}, 2}, 1},
            },
        )
        precompile(
            Tuple{
                typeof(Base.collect),
                Base.Generator{
                    Array{Array{Base.Complex{Float64}, 2}, 1},
                    WannierNLQGWannierizationExt.SolverCheckpoint.var"#399#401",
                },
            },
        )
        precompile(
            Tuple{
                typeof(Core.kwcall),
                NamedTuple{
                    (
                        :fixed_subspace_projectors,
                        :fixed_subspace_frames,
                        :localization_initial_frames,
                    ),
                    Tuple{
                        Array{Array{Base.Complex{Float64}, 2}, 1},
                        Array{Array{Base.Complex{Float64}, 2}, 1},
                        Nothing,
                    },
                },
                typeof(WannierNLQGWannierizationExt.SolverCheckpoint._restart_state),
                Int64,
                Array{Array{Base.Complex{Float64}, 2}, 1},
                Array{Array{Base.Complex{Float64}, 2}, 1},
                Array{Float64, 2},
                Array{Float64, 1},
                Array{Array{Float64, 1}, 1},
                Array{Base.BitArray{1}, 1},
                Float64,
                String,
                String,
                WannierNLQG.Wannierization.WannierizationFiniteDifferenceStencil,
                String,
                String,
                WannierNLQG.Wannierization.WannierizationOptimizerState,
            },
        )
        precompile(
            Tuple{
                typeof(WannierNLQGWannierizationExt.SolverCheckpoint._finish_solver_iteration),
                NamedTuple{
                    (
                        :actual_u_mix_ratio,
                        :actual_z_mix_ratio,
                        :amn_sha256,
                        :anderson_residual_history,
                        :anderson_z_history,
                        :apply_symmetry,
                        :basis_sha256,
                        :best_polar_centers,
                        :best_polar_frames,
                        :best_polar_objective,
                        :best_polar_spreads,
                        :centers,
                        :compatibility,
                        :config,
                        :config_sha256,
                        :convergence_values,
                        :retained_disentanglement_nonconverged,
                        :diagnostics,
                        :disentanglement_objective_history,
                        :effective_algorithms,
                        :effective_compatibility_policy,
                        :epoch,
                        :fixed_complete,
                        :fixed_mode,
                        :fixed_source_qualified,
                        :fixed_stability_count,
                        :fixed_stationary,
                        :fixed_stationary_count,
                        :frames,
                        :frozen_indices,
                        :full_constraint_scope,
                        :gradient_fallback_active,
                        :gradient_steps,
                        :grassmann_actual_decrease_history,
                        :grassmann_gradient_history,
                        :grassmann_predicted_decrease_history,
                        :grassmann_projector_change_history,
                        :grassmann_radius_history,
                        :grassmann_ratio_history,
                        :grassmann_trust_radius,
                        :history,
                        :improvement_streak,
                        :included_bands,
                        :initialization_report,
                        :input_summary,
                        :iteration,
                        :last_accepted_u_step_scale,
                        :last_anderson_reason,
                        :last_cg_beta,
                        :last_cg_restart_reason,
                        :last_u_optimizer_restart_reason,
                        :latest_restart_state,
                        :localization_initial_frames,
                        :localization_objective_history,
                        :localization_projector_drift_history,
                        :localization_reference_frames,
                        :localization_trial_accepted,
                        :localization_trial_actual_changes,
                        :localization_trial_directional_derivatives,
                        :localization_trial_iterations,
                        :localization_trial_objectives,
                        :localization_trial_required_changes,
                        :localization_trial_step_scales,
                        :localization_trial_sweeps,
                        :minimum_localization_diagonal_phase_margin,
                        :mmn,
                        :nb,
                        :nk,
                        :num_wannier,
                        :observer,
                        :optimizer_phase,
                        :outer_indices,
                        :phase_branch_backtracking_extension_count,
                        :plan,
                        :previous_merit,
                        :previous_u_direction,
                        :previous_u_gradient,
                        :prior_elapsed,
                        :projector_covariance_tolerance,
                        :rejected_steps,
                        :representation,
                        :residual_reference,
                        :result,
                        :sealed_subspace_frames,
                        :sealed_subspace_projectors,
                        :spectrum_audit,
                        :spreads,
                        :stage_stop_reason,
                        :start_iteration,
                        :started_ns,
                        :stencil,
                        :tangent_plans,
                        :total_spread_window_std,
                        :trajectory_previous_frames,
                        :trajectory_two_step_frames,
                        :two_stage_complete,
                        :u_active_orbit_count,
                        :u_branch_signature,
                        :u_cg_iteration,
                        :u_cg_restart_count,
                        :u_generalized_gradient_rms,
                        :u_lbfgs_restart_count,
                        :u_lbfgs_rho_history,
                        :u_lbfgs_s_history,
                        :u_lbfgs_y_history,
                        :u_stability_count,
                        :u_steps,
                        :wannier90_reference_omega_i,
                        :wannier90_reference_overlaps,
                        :wannier90_reference_unitaries,
                        :weights,
                        :z_previous,
                        :z_stability_count,
                        :z_steps,
                    ),
                    Tuple{
                        Float64,
                        Float64,
                        String,
                        Array{Float64, 2},
                        Array{Float64, 2},
                        Bool,
                        String,
                        Array{Float64, 2},
                        Array{Array{Base.Complex{Float64}, 2}, 1},
                        Float64,
                        Array{Float64, 1},
                        Array{Float64, 2},
                        WannierNLQG.Wannierization.RepresentationCompatibilityReport,
                        WannierNLQG.Wannierization.SymmetryAdaptedWannierizationConfig,
                        String,
                        Array{Array{Float64, 1}, 1},
                        Bool,
                        Array{WannierNLQG.Wannierization.WannierizationDiagnostic, 1},
                        Array{Float64, 1},
                        NamedTuple{
                            (:disentanglement, :localization, :profile, :default_selection_reason),
                            Tuple{Symbol, Symbol, Symbol, String},
                        },
                        Symbol,
                        Int64,
                        Bool,
                        Bool,
                        Bool,
                        Int64,
                        Bool,
                        Int64,
                        Array{Array{Base.Complex{Float64}, 2}, 1},
                        Array{Array{Int64, 1}, 1},
                        Bool,
                        Bool,
                        Int64,
                        Array{Float64, 1},
                        Array{Float64, 1},
                        Array{Float64, 1},
                        Array{Float64, 1},
                        Array{Float64, 1},
                        Array{Float64, 1},
                        Float64,
                        Array{WannierNLQG.Wannierization.WannierizationIteration, 1},
                        Int64,
                        Array{Base.BitArray{1}, 1},
                        Nothing,
                        Base.Dict{String, String},
                        Int64,
                        Float64,
                        Symbol,
                        Float64,
                        Symbol,
                        Symbol,
                        WannierNLQG.Wannierization.WannierizationRestartState,
                        Nothing,
                        Array{Float64, 1},
                        Array{Float64, 1},
                        Array{Array{Base.Complex{Float64}, 2}, 1},
                        Array{Bool, 1},
                        Array{Float64, 1},
                        Array{Float64, 1},
                        Array{Int64, 1},
                        Array{Float64, 1},
                        Array{Float64, 1},
                        Array{Float64, 1},
                        Array{Int64, 1},
                        Float64,
                        WannierNLQG.IO.WannierMMN,
                        Int64,
                        Int64,
                        Int64,
                        WannierNLQGWannierizationExt.WorkflowOrchestration.var"#109#115"{
                            Base.RefValue{String},
                            Base.RefValue{String},
                            Base.RefValue{String},
                            WannierNLQGWannierizationExt.OperatorExport.var"#253#254"{
                                WannierNLQG.Wannierization.SymmetryAdaptedWannierizationConfig,
                                WannierNLQG.SymmetryFoundation.BandRepresentation,
                                NamedTuple{
                                    (
                                        :checkpoint,
                                        :validated,
                                        :log,
                                        :packed,
                                        :wannier90,
                                        :tb_symmetry_json,
                                    ),
                                    NTuple{6, String},
                                },
                                Base.IOStream,
                                Base.Dict{String, String},
                            },
                            Array{WannierNLQG.Wannierization.WannierizationDiagnostic, 1},
                        },
                        Symbol,
                        Array{Array{Int64, 1}, 1},
                        Int64,
                        WannierNLQG.SymmetryFoundation.WannierSymmetryPlan,
                        Float64,
                        Nothing,
                        Nothing,
                        Float64,
                        Float64,
                        Int64,
                        WannierNLQG.SymmetryFoundation.BandRepresentation,
                        NTuple{4, Float64},
                        NamedTuple{
                            (
                                :success,
                                :code,
                                :frames,
                                :centers,
                                :spreads,
                                :directional,
                                :u_residual,
                                :gradient_rms,
                                :projection_converged,
                                :projection_iterations,
                                :projection_residual,
                                :completed_sweeps,
                                :accepted_step_scale,
                                :backtracking_steps,
                                :trial_objective,
                                :accepted_objective,
                                :localization_spectra,
                                :localization_ranks,
                                :localization_conditions,
                                :raw_eigenphases,
                                :aligned_eigenphases,
                                :raw_geodesic_distances,
                                :aligned_geodesic_distances,
                                :block_permutations,
                                :block_phases,
                                :polar_fallback_triggered,
                                :active_localization_algorithm,
                                :base_objective,
                                :trial_zero_objective,
                                :trial_zero_frame_residual,
                                :attempted_step_scales,
                                :attempted_objectives,
                                :attempted_required_changes,
                                :attempted_actual_changes,
                                :attempted_directional_derivatives,
                                :attempted_sweeps,
                                :attempted_accepted,
                                :directional_derivative,
                                :fixed_projector_drift,
                                :accepted_required_change,
                                :accepted_actual_change,
                                :minimum_diagonal_phase_margin,
                                :minimum_phase_kpoint,
                                :minimum_phase_neighbor,
                                :minimum_phase_wannier,
                                :minimum_phase_value,
                                :branch_safe_backtracking_triggered,
                                :previous_u_gradient,
                                :previous_u_direction,
                                :u_cg_iteration,
                                :u_cg_restart_count,
                                :cg_beta,
                                :cg_restarted,
                                :cg_restart_reason,
                                :cg_descent_cosine,
                                :kstar_gradient_rms,
                                :maximum_kstar_gradient_rms,
                                :maximum_kstar_gradient_index,
                                :transport_minimum_singular_value,
                                :transport_maximum_condition,
                                :transported_omega_i,
                                :u_phase_contract,
                                :u_active_orbit_sha256,
                                :u_active_orbit_count,
                                :generalized_gradient_rms,
                                :u_lbfgs_s_history,
                                :u_lbfgs_y_history,
                                :u_lbfgs_rho_history,
                                :u_lbfgs_restart_count,
                                :u_optimizer_restart_reason,
                                :subspaces,
                                :raw_amn_alignment_applied,
                                :raw_amn_alignment_minimum_singular_value,
                                :raw_amn_alignment_maximum_condition,
                                :raw_amn_alignment_projector_drift,
                                :raw_amn_alignment_completion_count,
                                :localization_initial_frames,
                                :corepresentation_transport_applied,
                                :corepresentation_transport_minimum_singular_value,
                                :corepresentation_transport_maximum_condition,
                                :corepresentation_transport_projector_drift,
                                :corepresentation_transport_target_symmetry,
                                :spread_total,
                                :spread_std,
                                :covariance_error,
                                :projector_residual,
                                :wcc_step,
                                :spread_step,
                                :z_boundary_gap,
                            ),
                            Tuple{
                                Bool,
                                Symbol,
                                Array{Array{Base.Complex{Float64}, 2}, 1},
                                Array{Float64, 2},
                                Array{Float64, 1},
                                Nothing,
                                Float64,
                                Float64,
                                Bool,
                                Int64,
                                Float64,
                                Int64,
                                Float64,
                                Int64,
                                Float64,
                                Float64,
                                Array{Array{Float64, 1}, 1},
                                Array{Int64, 1},
                                Array{Float64, 1},
                                Array{Array{Float64, 1}, 1},
                                Array{Array{Float64, 1}, 1},
                                Array{Float64, 1},
                                Array{Float64, 1},
                                Array{Array{Int64, 1}, 1},
                                Array{Array{Float64, 1}, 1},
                                Bool,
                                Symbol,
                                Float64,
                                Float64,
                                Float64,
                                Array{Float64, 1},
                                Array{Float64, 1},
                                Array{Float64, 1},
                                Array{Float64, 1},
                                Array{Float64, 1},
                                Array{Int64, 1},
                                Array{Bool, 1},
                                Float64,
                                Float64,
                                Float64,
                                Float64,
                                Float64,
                                Int64,
                                Int64,
                                Int64,
                                Float64,
                                Bool,
                                Nothing,
                                Nothing,
                                Int64,
                                Int64,
                                Float64,
                                Bool,
                                Symbol,
                                Float64,
                                Array{Float64, 1},
                                Float64,
                                Int64,
                                Float64,
                                Float64,
                                Float64,
                                String,
                                String,
                                Int64,
                                Float64,
                                Array{Array{Array{Base.Complex{Float64}, 2}, 1}, 1},
                                Array{Array{Array{Base.Complex{Float64}, 2}, 1}, 1},
                                Array{Float64, 1},
                                Int64,
                                Symbol,
                                Array{Array{Base.Complex{Float64}, 2}, 1},
                                Bool,
                                Float64,
                                Float64,
                                Float64,
                                Int64,
                                Nothing,
                                Bool,
                                Vararg{Float64, 11},
                            },
                        },
                        Array{Array{Base.Complex{Float64}, 2}, 1},
                        Array{Array{Base.Complex{Float64}, 2}, 1},
                        WannierNLQGWannierizationExt.SolverCheckpoint.HermitianSpectrumAudit,
                        Array{Float64, 1},
                        Nothing,
                        Int64,
                        UInt64,
                        WannierNLQG.Wannierization.WannierizationFiniteDifferenceStencil,
                        Array{
                            Union{
                                Nothing,
                                WannierNLQGWannierizationExt.SolverCheckpoint.TargetSymmetryTangentPlan,
                            },
                            1,
                        },
                        Float64,
                        Array{Array{Base.Complex{Float64}, 2}, 1},
                        Array{Array{Base.Complex{Float64}, 2}, 1},
                        Bool,
                        Int64,
                        String,
                        Int64,
                        Int64,
                        Float64,
                        Int64,
                        Array{Float64, 1},
                        Array{Array{Array{Base.Complex{Float64}, 2}, 1}, 1},
                        Array{Array{Array{Base.Complex{Float64}, 2}, 1}, 1},
                        Int64,
                        Int64,
                        Nothing,
                        Nothing,
                        Nothing,
                        Array{Float64, 1},
                        Array{Array{Base.Complex{Float64}, 2}, 1},
                        Int64,
                        Int64,
                    },
                },
            },
        )
        precompile(
            Tuple{
                typeof(Core.kwcall),
                NamedTuple{(:operator_target_contract,), Tuple{Nothing}},
                typeof(WannierNLQGWannierizationExt.OperatorExport._export_wannierization_tb),
                WannierNLQG.Wannierization.WannierizationResult,
                WannierNLQG.IO.WannierEIG,
                WannierNLQG.IO.WannierMMN,
                WannierNLQG.Wannierization.SymmetryAdaptedWannierizationConfig,
                NamedTuple{
                    (:checkpoint, :validated, :log, :packed, :wannier90, :tb_symmetry_json),
                    NTuple{6, String},
                },
                WannierNLQG.SymmetryFoundation.WannierSymmetryPlan,
            },
        )
        precompile(
            Tuple{
                typeof(Base.getproperty),
                WannierNLQGWannierizationExt.OperatorExport.AuthoritativeBandHamiltonian,
                Symbol,
            },
        )
        precompile(
            Tuple{
                WannierNLQGWannierizationExt.OperatorExport.var"#120#123"{
                    Float64,
                    Int64,
                    Symbol,
                    Base.Dict{String, Float64},
                    WannierNLQG.IO.WannierCHK,
                },
                Array{Base.Complex{Float64}, 3},
                String,
            },
        )
        precompile(
            Tuple{
                WannierNLQGWannierizationExt.OperatorExport.var"#120#123"{
                    Float64,
                    Int64,
                    Symbol,
                    Base.Dict{String, Float64},
                    WannierNLQG.IO.WannierCHK,
                },
                Array{Base.Complex{Float64}, 4},
                String,
            },
        )
        precompile(
            Tuple{
                typeof(Base.grow_to!),
                Base.Dict{Tuple{Int64, Int64, Int64}, Int64},
                Base.Generator{
                    Base.OneTo{Int64},
                    WannierNLQGWannierizationExt.OperatorExport.var"#258#259"{Array{Int64, 2}},
                },
                Int64,
            },
        )
        precompile(
            Tuple{
                typeof(WannierNLQGWannierizationExt.OperatorExport._authoritative_array_sha256),
                Array{Base.Complex{Float64}, 3},
            },
        )
        precompile(
            Tuple{
                typeof(
                    WannierNLQGWannierizationExt.OperatorExport._profile_qualification_digest_value!,
                ),
                Base.GenericIOBuffer{GenericMemory{:not_atomic, UInt8, Core.AddrSpace{Core}(0x00)}},
                String,
            },
        )
        precompile(
            Tuple{
                typeof(
                    WannierNLQGWannierizationExt.OperatorExport._profile_qualification_digest_value!,
                ),
                Base.GenericIOBuffer{GenericMemory{:not_atomic, UInt8, Core.AddrSpace{Core}(0x00)}},
                Base.Dict{String, String},
            },
        )
        precompile(
            Tuple{
                typeof(
                    WannierNLQGWannierizationExt.OperatorExport._profile_qualification_digest_value!,
                ),
                Base.GenericIOBuffer{GenericMemory{:not_atomic, UInt8, Core.AddrSpace{Core}(0x00)}},
                Float64,
            },
        )
        precompile(
            Tuple{
                typeof(
                    WannierNLQGWannierizationExt.OperatorExport._profile_qualification_digest_value!,
                ),
                Base.GenericIOBuffer{GenericMemory{:not_atomic, UInt8, Core.AddrSpace{Core}(0x00)}},
                Bool,
            },
        )
        precompile(
            Tuple{
                typeof(WannierNLQGWannierizationExt.OperatorExport._authoritative_array_sha256),
                Array{Base.Complex{Float64}, 4},
            },
        )
        precompile(
            Tuple{
                typeof(
                    WannierNLQGWannierizationExt.OperatorExport._profile_export_numerical_checks!,
                ),
                Array{Base.Dict{String, Any}, 1},
                Symbol,
                Base.Dict{String, String},
                String,
            },
        )
        precompile(
            Tuple{
                typeof(
                    WannierNLQGWannierizationExt.OperatorExport._profile_export_numerical_checks!,
                ),
                Array{Base.Dict{String, Any}, 1},
                Symbol,
                Base.Dict{String, Base.Dict{String, Any}},
                String,
            },
        )
        precompile(
            Tuple{
                typeof(
                    WannierNLQGWannierizationExt.OperatorExport._write_construction_metadata_sidecar,
                ),
                String,
                String,
                Base.Dict{String, Any},
            },
        )
        precompile(
            Tuple{
                typeof(Core.kwcall),
                NamedTuple{
                    (:hamiltonian_covariance_threshold, :persist_hdf5),
                    Tuple{Float64, Bool},
                },
                typeof(
                    WannierNLQGWannierizationExt.OperatorExport.qualify_exported_wannierization_tb,
                ),
                String,
                WannierNLQG.SymmetryFoundation.BandRepresentation,
                WannierNLQG.SymmetryFoundation.WannierSymmetryPlan,
            },
        )
        precompile(
            Tuple{
                typeof(WannierNLQGWannierizationExt.OperatorExport._tb_authority_identity),
                WannierNLQG.IO.OperatorBundleManifest,
            },
        )
        precompile(
            Tuple{
                typeof(WannierNLQGWannierizationExt.OperatorExport._normalized_tb_operator),
                WannierNLQG.Core.RealSpaceOperator{3},
                Array{Int64, 1},
            },
        )
        precompile(
            Tuple{
                typeof(WannierNLQGWannierizationExt.OperatorExport._normalized_tb_operator),
                WannierNLQG.Core.RealSpaceOperator{4},
                Array{Int64, 1},
            },
        )
        precompile(
            Tuple{
                typeof(WannierNLQGWannierizationExt.OperatorExport._centerless_tb_position),
                WannierNLQG.Core.RealSpaceOperator{4},
            },
        )
        precompile(
            Tuple{
                typeof(
                    WannierNLQGWannierizationExt.OperatorExport._qualification_hermiticity_metric,
                ),
                String,
                WannierNLQG.Core.RealSpaceOperator{3},
                Float64,
                String,
            },
        )
        precompile(
            Tuple{
                typeof(Base.grow_to!),
                Base.Dict{Tuple{Int64, Int64, Int64}, Int64},
                Base.Generator{
                    Base.OneTo{Int64},
                    WannierNLQGWannierizationExt.OperatorExport.var"#317#318"{
                        WannierNLQG.Core.RealSpaceOperator{3},
                    },
                },
                Int64,
            },
        )
        precompile(
            Tuple{
                typeof(WannierNLQGWannierizationExt.OperatorExport._tb_symmetry_metric),
                String,
                Float64,
                Float64,
                String,
            },
        )
        precompile(
            Tuple{
                typeof(
                    WannierNLQGWannierizationExt.OperatorExport._qualification_hermiticity_metric,
                ),
                String,
                WannierNLQG.Core.RealSpaceOperator{4},
                Float64,
                String,
            },
        )
        precompile(
            Tuple{
                typeof(Base.grow_to!),
                Base.Dict{Tuple{Int64, Int64, Int64}, Int64},
                Base.Generator{
                    Base.OneTo{Int64},
                    WannierNLQGWannierizationExt.OperatorExport.var"#317#318"{
                        WannierNLQG.Core.RealSpaceOperator{4},
                    },
                },
                Int64,
            },
        )
        precompile(
            Tuple{
                typeof(WannierNLQGWannierizationExt.OperatorExport._qualification_kstar_residual),
                WannierNLQG.Core.RealSpaceOperator{3},
                Array{Int64, 1},
                WannierNLQG.SymmetryFoundation.BandRepresentation,
            },
        )
        precompile(
            Tuple{
                HDF5.var"##h5open#16",
                HDF5.HDF5Context,
                Base.Pairs{Symbol, Union{}, Tuple{}, NamedTuple{(), Tuple{}}},
                typeof(HDF5.h5open),
                WannierNLQGWannierizationExt.WorkflowOrchestration.var"#111#117"{
                    WannierNLQG.Wannierization.TBSymmetryQualification,
                },
                String,
                Vararg{String},
            },
        )
        precompile(
            Tuple{
                typeof(Core.kwcall),
                NamedTuple{
                    (:input_summary, :tb_symmetry_qualification),
                    Tuple{
                        Base.Dict{String, String},
                        WannierNLQG.Wannierization.TBSymmetryQualification,
                    },
                },
                typeof(
                    WannierNLQGWannierizationExt.WannierizationInternalSupport.updated_wannierization_result,
                ),
                WannierNLQG.Wannierization.WannierizationResult,
            },
        )
        precompile(
            Tuple{
                typeof(
                    WannierNLQGWannierizationExt.WannierizationInternalSupport.required_attribute,
                ),
                HDF5.Group,
                String,
            },
        )
        precompile(
            Tuple{
                typeof(
                    WannierNLQGWannierizationExt.WannierizationInternalSupport.validate_persisted_authority_key,
                ),
                String,
            },
        )
        precompile(
            Tuple{
                HDF5.var"##h5open#16",
                HDF5.HDF5Context,
                Base.Pairs{Symbol, Union{}, Tuple{}, NamedTuple{(), Tuple{}}},
                typeof(HDF5.h5open),
                WannierNLQGWannierizationExt.OperatorExport.var"#298#300"{String, String},
                String,
                Vararg{String},
            },
        )
        precompile(
            Tuple{
                Type{Base.Iterators.Filter{F, I} where {I} where F},
                WannierNLQGWannierizationExt.OperatorExport.var"#225#230",
                Tuple{Int64},
            },
        )
        precompile(
            Tuple{
                Type{Base.Generator{I, F} where {F} where I},
                typeof(Base.identity),
                Base.Iterators.Filter{
                    WannierNLQGWannierizationExt.OperatorExport.var"#225#230",
                    Tuple{Int64},
                },
            },
        )
        precompile(
            Tuple{
                typeof(Base.grow_to!),
                Array{Int64, 1},
                Base.Iterators.Flatten{
                    Base.Generator{
                        Array{WannierNLQG.Wannierization.WannierizationDiagnostic, 1},
                        WannierNLQGWannierizationExt.OperatorExport.var"#226#229",
                    },
                },
                Tuple{
                    Int64,
                    Base.Generator{
                        Base.Iterators.Filter{
                            WannierNLQGWannierizationExt.OperatorExport.var"#225#230",
                            Tuple{Int64},
                        },
                        typeof(Base.identity),
                    },
                    Int64,
                },
            },
        )
    end
end

# Compile early preparation entries before lazy Spglib activation. No execution.
import LinearAlgebra
# Anchor safe signature compilation before optional symmetry backend activation.
_early_prepare_compile_call(f::F, args::Vararg{Any, N}) where {F, N} = Base.@noinline f(args...)
const EARLY_PREPARE_RESULTS = Tuple{Bool, Bool}[]
# Track direct and bridge coverage without executing solver preparation.
function _record_early_prepare(@nospecialize(signature))
    direct = precompile(signature)
    bridge = precompile(Tuple{typeof(_early_prepare_compile_call), signature.parameters...})
    push!(EARLY_PREPARE_RESULTS, (direct, bridge))
    nothing
end
@compile_workload begin
    if WannierizationInternalSupport.WannierNLQG.FIRST_USE_WORKLOAD_ENABLED
        _record_early_prepare(
            Tuple{
                typeof(WannierNLQG.Wannierization.prepare_band_representation),
                WannierNLQG.Wannierization.BandRepresentationPreparationConfig,
            },
        )
        _record_early_prepare(
            Tuple{typeof(WannierNLQGWannierizationExt.resolve_wannierization_entrypoint), Symbol},
        )
        _record_early_prepare(
            Tuple{
                typeof(Base.collect_to!),
                Array{Union{Nothing, Symbol}, 1},
                Base.Generator{
                    NTuple{24, Symbol},
                    WannierNLQGWannierizationExt.WorkflowOrchestration.var"#83#84"{
                        WannierNLQG.Wannierization.BandRepresentationPreparationConfig,
                    },
                },
                Int64,
                Int64,
            },
        )
        _record_early_prepare(
            Tuple{
                typeof(Base.setindex_widen_up_to),
                Array{Union{Nothing, Symbol}, 1},
                WannierNLQG.Wannierization.CoefficientMappingSewing,
                Int64,
            },
        )
        _record_early_prepare(
            Tuple{
                typeof(Base.collect_to!),
                Array{Any, 1},
                Base.Generator{
                    NTuple{24, Symbol},
                    WannierNLQGWannierizationExt.WorkflowOrchestration.var"#83#84"{
                        WannierNLQG.Wannierization.BandRepresentationPreparationConfig,
                    },
                },
                Int64,
                Int64,
            },
        )
        _record_early_prepare(
            Tuple{
                typeof(Core.kwcall),
                NamedTuple{
                    (
                        :construction_policy,
                        :wannierization_mode,
                        :source,
                        :sewing_backend,
                        :wavefunction_gauge_backend,
                        :authoritative_hamiltonian,
                        :wavefunction_gauge_hdf5,
                        :win_file,
                        :eig_file,
                        :projection_basis,
                        :band_representation,
                        :band_representation_hdf5,
                        :output_hdf5,
                        :outer_min_ev,
                        :outer_max_ev,
                        :frozen_min_ev,
                        :frozen_max_ev,
                        :frozen_states,
                        :num_wannier,
                        :symmetry_tolerance,
                        :degeneracy_tolerance_ev,
                        :representation_tolerance,
                        :target_center_matching_tolerance,
                        :compatibility_policy,
                    ),
                    Tuple{
                        Symbol,
                        Symbol,
                        Nothing,
                        WannierNLQG.Wannierization.CoefficientMappingSewing,
                        WannierNLQG.Wannierization.NativeEigenstateGauge,
                        WannierNLQG.Wannierization.NativeDFTHamiltonian,
                        Nothing,
                        String,
                        String,
                        WannierNLQG.WannierProjection.WannierProjectionBasis,
                        WannierNLQG.SymmetryFoundation.BandRepresentation,
                        Nothing,
                        String,
                        Float64,
                        Float64,
                        Float64,
                        Float64,
                        Array{Tuple{Int64, Int64}, 1},
                        Int64,
                        Float64,
                        Float64,
                        Float64,
                        Float64,
                        Symbol,
                    },
                },
                Type{WannierNLQG.Wannierization.BandRepresentationPreparationConfig},
            },
        )
        _record_early_prepare(
            Tuple{
                typeof(Core.memoryref),
                GenericMemory{
                    :not_atomic,
                    Tuple{Int64, Int64, Float64},
                    Core.AddrSpace{Core}(0x00),
                },
            },
        )
        _record_early_prepare(Tuple{typeof(Base.zeros), Type{Float64}, Int64, Int64, Vararg{Int64}})
        _record_early_prepare(Tuple{typeof(Base.zeros), Type{Float64}, Tuple{Int64, Int64}})
        _record_early_prepare(Tuple{typeof(Base.falses), Int64, Int64, Vararg{Int64}})
        _record_early_prepare(Tuple{typeof(Base.falses), Tuple{Int64, Int64}})
        _record_early_prepare(
            Tuple{
                typeof(Base.getproperty),
                WannierNLQG.SymmetryFoundation.BandRepresentation,
                Symbol,
            },
        )
        _record_early_prepare(
            Tuple{
                typeof(Core.kwcall),
                NamedTuple{(:preserve_public_origin_absence,), Tuple{Bool}},
                typeof(
                    WannierNLQGWannierizationExt.WorkflowOrchestration._representation_with_mode_contract,
                ),
                WannierNLQG.SymmetryFoundation.BandRepresentation,
                WannierNLQG.Wannierization.BandRepresentationPreparationConfig,
            },
        )
        _record_early_prepare(
            Tuple{
                typeof(
                    WannierNLQGWannierizationExt.WorkflowOrchestration._validate_sewing_backend_identity,
                ),
                WannierNLQG.Wannierization.CoefficientMappingSewing,
                WannierNLQG.SymmetryFoundation.BandRepresentation,
            },
        )
        _record_early_prepare(
            Tuple{
                typeof(
                    WannierNLQGWannierizationExt.WorkflowOrchestration._validate_wavefunction_gauge_identity,
                ),
                WannierNLQG.Wannierization.NativeEigenstateGauge,
                Nothing,
                WannierNLQG.SymmetryFoundation.BandRepresentation,
            },
        )
        _record_early_prepare(
            Tuple{
                typeof(
                    WannierNLQGWannierizationExt.WorkflowOrchestration._validate_authoritative_hamiltonian_identity,
                ),
                WannierNLQG.Wannierization.NativeDFTHamiltonian,
                WannierNLQG.SymmetryFoundation.BandRepresentation,
            },
        )
        _record_early_prepare(Tuple{typeof(Base.size), Array{Float64, 2}})
        _record_early_prepare(Tuple{typeof(Base.:(==)), Tuple{Int64, Int64}, Tuple{Int64, Int64}})
        _record_early_prepare(Tuple{typeof(Base.hcat), Array{Float64, 1}})
        _record_early_prepare(Tuple{typeof(Base.:(\)), Array{Float64, 2}, Array{Float64, 2}})
        _record_early_prepare(Tuple{typeof(Base.:(*)), Array{Float64, 2}, Array{Float64, 2}})
        _record_early_prepare(Tuple{typeof(Base.maximum), Function, Array{Float64, 2}})
        _record_early_prepare(
            Tuple{
                typeof(Base._mapreduce_dim),
                Function,
                Function,
                Base._InitialValue,
                Array{Float64, 2},
                Base.Colon,
            },
        )
        _record_early_prepare(
            Tuple{typeof(Base._all), typeof(Base.isfinite), Array{Float64, 2}, Base.Colon},
        )
        _record_early_prepare(Tuple{typeof(Base.minimum), Array{Float64, 1}})
        _record_early_prepare(Tuple{typeof(Base.maximum), Array{Float64, 1}})
        _record_early_prepare(Tuple{typeof(Base.max), Float64, Float64})
        _record_early_prepare(Tuple{typeof(Base.:(>)), Float64, Float64})
        _record_early_prepare(Tuple{typeof(Base.:(<=)), Float64, Float64})
        _record_early_prepare(
            Tuple{typeof(Base.Broadcast.broadcasted), typeof(Base.abs), Array{Float64, 2}},
        )
        _record_early_prepare(
            Tuple{
                typeof(Base.Broadcast.broadcasted),
                typeof(Base.:(<)),
                Base.Broadcast.Broadcasted{
                    Base.Broadcast.DefaultArrayStyle{2},
                    Nothing,
                    typeof(Base.abs),
                    Tuple{Array{Float64, 2}},
                },
                Float64,
            },
        )
        _record_early_prepare(
            Tuple{
                typeof(Base.Broadcast.materialize),
                Base.Broadcast.Broadcasted{
                    Base.Broadcast.DefaultArrayStyle{2},
                    Nothing,
                    typeof(Base.:(<)),
                    Tuple{
                        Base.Broadcast.Broadcasted{
                            Base.Broadcast.DefaultArrayStyle{2},
                            Nothing,
                            typeof(Base.abs),
                            Tuple{Array{Float64, 2}},
                        },
                        Float64,
                    },
                },
            },
        )
        _record_early_prepare(Tuple{typeof(Base.maybeview), Array{Float64, 2}, Base.BitArray{2}})
        _record_early_prepare(
            Tuple{
                typeof(Base.Broadcast.materialize!),
                Base.SubArray{Float64, 1, Array{Float64, 1}, Tuple{Array{Int64, 1}}, false},
                Base.Broadcast.Broadcasted{
                    Base.Broadcast.DefaultArrayStyle{0},
                    Nothing,
                    typeof(Base.identity),
                    Tuple{Float64},
                },
            },
        )
        _record_early_prepare(
            Tuple{
                typeof(Base.Broadcast.broadcasted),
                Type{Base.Complex{Float64}},
                Array{Float64, 2},
            },
        )
        _record_early_prepare(
            Tuple{
                typeof(Base.Broadcast.materialize),
                Base.Broadcast.Broadcasted{
                    Base.Broadcast.DefaultArrayStyle{2},
                    Nothing,
                    Type{Base.Complex{Float64}},
                    Tuple{Array{Float64, 2}},
                },
            },
        )
        _record_early_prepare(
            Tuple{
                typeof(Base.Broadcast.broadcasted),
                typeof(Base.identity),
                Array{Base.Complex{Float64}, 2},
            },
        )
        _record_early_prepare(
            Tuple{
                typeof(Base.Broadcast.materialize!),
                Base.SubArray{
                    Base.Complex{Float64},
                    2,
                    Array{Base.Complex{Float64}, 3},
                    Tuple{Array{Int64, 1}, Array{Int64, 1}, Int64},
                    false,
                },
                Base.Broadcast.Broadcasted{
                    Base.Broadcast.DefaultArrayStyle{2},
                    Nothing,
                    typeof(Base.identity),
                    Tuple{Array{Base.Complex{Float64}, 2}},
                },
            },
        )
        _record_early_prepare(Tuple{typeof(Base.hcat), Base.BitArray{1}, Base.BitArray{1}})
        _record_early_prepare(
            Tuple{
                typeof(Core.kwcall),
                NamedTuple{
                    (
                        :outer_min_ev,
                        :outer_max_ev,
                        :frozen_min_ev,
                        :frozen_max_ev,
                        :num_wannier,
                        :scoped_paw_thresholds,
                        :target_complement_maximum_element_ev,
                    ),
                    Tuple{
                        Float64,
                        Float64,
                        Float64,
                        Float64,
                        Int64,
                        WannierNLQG.Wannierization.PAWGaugeThresholds,
                        Float64,
                    },
                },
                Type{WannierNLQG.Wannierization.TargetSubspaceQualificationContract},
                WannierNLQG.SymmetryFoundation.BandRepresentationQualificationScope,
            },
        )
        _record_early_prepare(
            Tuple{
                typeof(
                    WannierNLQGWannierizationExt.PAWMatrixElements._star_authoritative_hamiltonian_sha256,
                ),
                WannierNLQG.Wannierization.NativeDFTHamiltonian,
            },
        )
        _record_early_prepare(
            Tuple{
                typeof(Base.join),
                Base.GenericIOBuffer{GenericMemory{:not_atomic, UInt8, Core.AddrSpace{Core}(0x00)}},
                Array{Float64, 1},
                Char,
            },
        )
        _record_early_prepare(
            Tuple{
                Type{
                    Base.Broadcast.Broadcasted{
                        Style,
                        Axes,
                        F,
                        Args,
                    } where {
                        Args <: Tuple,
                    } where {
                        F,
                    } where {Axes} where Style <: Union{Nothing, Base.Broadcast.BroadcastStyle},
                },
                Base.Broadcast.Style{Tuple},
                typeof(Base.identity),
                Tuple{NTuple{4, Float64}},
            },
        )
        _record_early_prepare(
            Tuple{
                typeof(Base.Broadcast.materialize!),
                Base.Broadcast.DefaultArrayStyle{1},
                Array{Float64, 1},
                Base.Broadcast.Broadcasted{
                    Base.Broadcast.Style{Tuple},
                    Nothing,
                    typeof(Base.identity),
                    Tuple{NTuple{4, Float64}},
                },
            },
        )
        _record_early_prepare(Tuple{typeof(Base.vec), Array{Float64, 2}})
        _record_early_prepare(
            Tuple{
                typeof(Base.write),
                Base.GenericIOBuffer{GenericMemory{:not_atomic, UInt8, Core.AddrSpace{Core}(0x00)}},
                Array{Float64, 1},
            },
        )
        _record_early_prepare(Tuple{typeof(Base.vec), Array{Int64, 2}})
        _record_early_prepare(
            Tuple{
                typeof(Base.write),
                Base.GenericIOBuffer{GenericMemory{:not_atomic, UInt8, Core.AddrSpace{Core}(0x00)}},
                Array{Int64, 1},
            },
        )
        _record_early_prepare(Tuple{typeof(Base.vec), Array{Int64, 3}})
        _record_early_prepare(Tuple{typeof(Base.vec), Array{Base.Complex{Float64}, 4}})
        _record_early_prepare(
            Tuple{
                typeof(Base.write),
                Base.GenericIOBuffer{GenericMemory{:not_atomic, UInt8, Core.AddrSpace{Core}(0x00)}},
                Array{Base.Complex{Float64}, 1},
            },
        )
        _record_early_prepare(Tuple{typeof(Base.vec), Array{Int64, 1}})
        _record_early_prepare(
            Tuple{
                typeof(Core.kwcall),
                NamedTuple{
                    (:public_origin_fallback_validated, :construction_policy),
                    Tuple{Bool, Symbol},
                },
                typeof(
                    WannierNLQGWannierizationExt.WorkflowOrchestration._effective_compatibility_policy,
                ),
                Symbol,
                WannierNLQG.SymmetryFoundation.BandRepresentation,
                Nothing,
            },
        )
        _record_early_prepare(
            Tuple{typeof(Base.getindex), Type{WannierNLQG.Wannierization.WannierizationDiagnostic}},
        )
        _record_early_prepare(
            Tuple{
                typeof(Core.memoryref),
                GenericMemory{
                    :not_atomic,
                    WannierNLQG.Wannierization.WannierizationDiagnostic,
                    Core.AddrSpace{Core}(0x00),
                },
            },
        )
        _record_early_prepare(Tuple{typeof(Base.haskey), Base.Dict{String, String}, String})
        _record_early_prepare(
            Tuple{
                WannierNLQGWannierizationExt.WorkflowOrchestration.var"#75#79",
                NamedTuple{
                    (:stage, :code, :operation, :orbital_set, :value, :threshold, :result, :action),
                    Tuple{String, String, Int64, String, Float64, Float64, String, String},
                },
            },
        )
        _record_early_prepare(
            Tuple{
                WannierNLQGWannierizationExt.WorkflowOrchestration.var"#75#79",
                NamedTuple{
                    (:stage, :code, :operation, :value, :threshold, :result, :action),
                    Tuple{String, String, Int64, Float64, Float64, String, String},
                },
            },
        )
        _record_early_prepare(Tuple{typeof(Base.get), Base.Dict{String, String}, String, String})
        _record_early_prepare(Tuple{Base.var"##s128#278", Vararg{Any, 5}})
        _record_early_prepare(
            Tuple{
                typeof(Core.kwcall),
                NamedTuple{
                    (
                        :inventory,
                        :raw_diagnostics,
                        :qualification_scope,
                        :requested_policy,
                        :effective_policy,
                        :symmetry_tolerance_status,
                    ),
                    Tuple{
                        Nothing,
                        Array{WannierNLQG.SymmetryFoundation.RepresentationRawDiagnostic, 1},
                        WannierNLQG.SymmetryFoundation.BandRepresentationQualificationScope,
                        Symbol,
                        Symbol,
                        Symbol,
                    },
                },
                typeof(WannierNLQG.SymmetryFoundation.write_band_representation_hdf5),
                String,
                WannierNLQG.SymmetryFoundation.BandRepresentation,
                WannierNLQG.Wannierization.RepresentationCompatibilityReport,
            },
        )
        _record_early_prepare(
            Tuple{
                typeof(Base.getproperty),
                WannierNLQG.Wannierization.RepresentationCompatibilityReport,
                Symbol,
            },
        )
        _record_early_prepare(Tuple{typeof(Base.collect), NTuple{4, Float64}})
        _record_early_prepare(
            Tuple{typeof(Base.Broadcast.broadcasted), Type{Float64}, Array{Float64, 1}},
        )
        _record_early_prepare(
            Tuple{
                typeof(Base.Broadcast.materialize),
                Base.Broadcast.Broadcasted{
                    Base.Broadcast.DefaultArrayStyle{1},
                    Nothing,
                    Type{Float64},
                    Tuple{Array{Float64, 1}},
                },
            },
        )
        _record_early_prepare(Tuple{Type{Tuple}, Array{Float64, 1}})
        _record_early_prepare(Tuple{typeof(Base.repeat), Char, Int64})
        _record_early_prepare(Tuple{typeof(Base.setindex!), HDF5.Attributes, Float64, String})
        _record_early_prepare(Tuple{typeof(Base.setindex!), HDF5.Attributes, String, String})
        _record_early_prepare(Tuple{typeof(Base.setindex!), HDF5.Group, Array{Float64, 1}, String})
        _record_early_prepare(
            Tuple{
                typeof(Base.show),
                Base.GenericIOBuffer{GenericMemory{:not_atomic, UInt8, Core.AddrSpace{Core}(0x00)}},
                Tuple{
                    Symbol,
                    Int64,
                    Int64,
                    Int64,
                    Bool,
                    Int64,
                    Int64,
                    Int64,
                    Int64,
                    Float64,
                    Float64,
                    Float64,
                    Float64,
                    Float64,
                    Float64,
                    Symbol,
                },
            },
        )
        _record_early_prepare(Tuple{typeof(Base.prod), Tuple{Int64}})
        _record_early_prepare(Tuple{Type{Array{Bool, N} where N}, UndefInitializer, Int64})
        _record_early_prepare(Tuple{typeof(Base.getindex), Array{Bool, 1}, Int64})
        _record_early_prepare(
            Tuple{Type{Array{Int64, N} where N}, UndefInitializer, Int64, Int64, Int64},
        )
        _record_early_prepare(
            Tuple{Type{Array{Float64, N} where N}, UndefInitializer, Int64, Int64, Int64},
        )
        _record_early_prepare(
            Tuple{Type{Array{Float64, N} where N}, UndefInitializer, Int64, Int64},
        )
        _record_early_prepare(Tuple{Type{Array{UInt8, N} where N}, UndefInitializer, Int64})
        _record_early_prepare(Tuple{typeof(Base.axes), Array{Int64, 3}, Int64})
        _record_early_prepare(Tuple{typeof(Base.getproperty), HDF5.GroupCreateProperties, Symbol})
        _record_early_prepare(Tuple{typeof(Base.transpose), Array{Float64, 2}})
        _record_early_prepare(
            Tuple{Type{Array{T, 2} where T}, LinearAlgebra.Transpose{Float64, Array{Float64, 2}}},
        )
        _record_early_prepare(Tuple{Type{Array{Int64, N} where N}, UndefInitializer, Int64})
        _record_early_prepare(
            Tuple{typeof(Base.Broadcast.broadcasted), Type{Int64}, Array{Int64, 1}},
        )
        _record_early_prepare(
            Tuple{
                typeof(Base.Broadcast.materialize),
                Base.Broadcast.Broadcasted{
                    Base.Broadcast.DefaultArrayStyle{1},
                    Nothing,
                    Type{Int64},
                    Tuple{Array{Int64, 1}},
                },
            },
        )
        _record_early_prepare(Tuple{Type{Tuple}, Array{Int64, 1}})
        _record_early_prepare(Tuple{Type{Array{Int64, N} where N}, UndefInitializer, Int64, Int64})
        _record_early_prepare(
            Tuple{
                Type{Array{Base.Complex{Float64}, N} where N},
                UndefInitializer,
                NTuple{4, Int64},
            },
        )
        _record_early_prepare(Tuple{typeof(Base.transpose), Array{Int64, 2}})
        _record_early_prepare(Tuple{typeof(Base.:(==)), Array{Int64, 3}, Array{Int64, 3}})
        _record_early_prepare(
            Tuple{
                Type{Array{Base.Complex{Float64}, N} where N},
                UndefInitializer,
                Int64,
                Int64,
                Int64,
            },
        )
        _record_early_prepare(Tuple{typeof(Base.in), String, NTuple{4, String}})
        _record_early_prepare(Tuple{typeof(Base.in), String, Tuple{String, String, String}})
        _record_early_prepare(Tuple{Type{Array{UInt8, N} where N}, UndefInitializer, Int64, Int64})
        _record_early_prepare(Tuple{typeof(Base.size), Base.BitArray{2}})
        _record_early_prepare(
            Tuple{typeof(Base.Broadcast.broadcasted), typeof(Base.:(!)), Base.BitArray{2}},
        )
        _record_early_prepare(
            Tuple{
                typeof(Base.Broadcast.broadcasted),
                typeof(Base.:(|)),
                Base.Broadcast.Broadcasted{
                    Base.Broadcast.DefaultArrayStyle{2},
                    Nothing,
                    typeof(Base.:(!)),
                    Tuple{Base.BitArray{2}},
                },
                Base.BitArray{2},
            },
        )
        _record_early_prepare(
            Tuple{
                typeof(Base.Broadcast.materialize),
                Base.Broadcast.Broadcasted{
                    Base.Broadcast.DefaultArrayStyle{2},
                    Nothing,
                    typeof(Base.:(|)),
                    Tuple{
                        Base.Broadcast.Broadcasted{
                            Base.Broadcast.DefaultArrayStyle{2},
                            Nothing,
                            typeof(Base.:(!)),
                            Tuple{Base.BitArray{2}},
                        },
                        Base.BitArray{2},
                    },
                },
            },
        )
        _record_early_prepare(Tuple{typeof(Base.all), Base.BitArray{2}})
        _record_early_prepare(
            Tuple{typeof(Base.Broadcast.broadcasted), Type{Int64}, Array{Int64, 2}},
        )
        _record_early_prepare(
            Tuple{
                typeof(Base.Broadcast.materialize),
                Base.Broadcast.Broadcasted{
                    Base.Broadcast.DefaultArrayStyle{2},
                    Nothing,
                    Type{Int64},
                    Tuple{Array{Int64, 2}},
                },
            },
        )
        _record_early_prepare(
            Tuple{typeof(Base.Broadcast.broadcasted), Type{Float64}, Array{Float64, 2}},
        )
        _record_early_prepare(Tuple{typeof(Base.size), Array{Int64, 2}})
        _record_early_prepare(Tuple{typeof(Base.length), Array{UInt8, 1}})
        _record_early_prepare(Tuple{typeof(Base.getindex), Array{UInt8, 1}, Int64})
        _record_early_prepare(Tuple{Type{Bool}, Int64})
    end
end

import Printf
# Cold QE NC/USPP/PAW public-entry signatures from independent processes.
@compile_workload begin
    if WannierizationInternalSupport.WannierNLQG.FIRST_USE_WORKLOAD_ENABLED
        false
        _record_early_prepare(
            Tuple{Type{Array{Float64, N} where N}, UndefInitializer, Int64, Int64},
        )
        _record_early_prepare(Tuple{Type{Array{Float64, N} where N}, UndefInitializer, Int64})
        _record_early_prepare(
            Tuple{Type{Array{Int64, 2}}, LinearAlgebra.Transpose{Int64, Array{Int64, 2}}},
        )
        _record_early_prepare(Tuple{Type{Array{Int64, N} where N}, UndefInitializer, Int64, Int64})
        _record_early_prepare(Tuple{Type{Array{Int64, N} where N}, UndefInitializer, Int64})
        _record_early_prepare(Tuple{Type{Base.Dict{String, String}}, Tuple{Pair{String, String}}})
        _record_early_prepare(
            Tuple{
                Type{Base.Generator{I, F} where {F} where I},
                typeof(Base.identity),
                Base.Iterators.Filter{
                    WannierNLQGWannierizationExt.PAWMatrixElements.var"#142#144"{Base.Set{Int64}},
                    Base.UnitRange{Int64},
                },
            },
        )
        _record_early_prepare(
            Tuple{
                Type{Base.Iterators.Filter{F, I} where {I} where F},
                WannierNLQGWannierizationExt.PAWMatrixElements.var"#142#144"{Base.Set{Int64}},
                Base.UnitRange{Int64},
            },
        )
        _record_early_prepare(Tuple{Type{Base.KeyError}, String})
        false
        _record_early_prepare(
            Tuple{Type{NamedTuple{(:atol, :rtol), T} where T <: Tuple}, Tuple{Float64, Float64}},
        )
        _record_early_prepare(
            Tuple{Type{NamedTuple{(:required, :default), T} where T <: Tuple}, Tuple{Bool, String}},
        )
        _record_early_prepare(Tuple{Type{Pair{A, B} where {B} where A}, String, Float64})
        _record_early_prepare(
            Tuple{Type{Pair{A, B} where {B} where A}, Tuple{Int64, Int64, Int64}, Int64},
        )
        _record_early_prepare(
            Tuple{
                Type{Printf.Spec{Base.Val{reinterpret(Char, UInt32(0x67000000))}}},
                Bool,
                Bool,
                Bool,
                Bool,
                Bool,
                Int64,
                Int64,
                Bool,
                Bool,
            },
        )
        false
        _record_early_prepare(
            Tuple{
                Type{WannierNLQG.SymmetryFoundation.NativeWavefunctionData},
                Symbol,
                WannierNLQG.SymmetryFoundation.CrystalStructure,
                Array{Float64, 2},
                Tuple{Int64, Int64, Int64},
                Bool,
                WannierNLQG.IO.PreparationSourceVector{
                    WannierNLQG.SymmetryFoundation.PlaneWaveKPoint,
                    WannierNLQGWannierizationExt.RepresentationPreparation.var"#99#101"{
                        Bool,
                        WannierNLQG.SymmetryFoundation.QuantumEspressoWavefunctionSource,
                        Int64,
                        Nothing,
                        Base.UnitRange{Int64},
                        NamedTuple{
                            (
                                :xml_file,
                                :structure,
                                :reciprocal_lattice,
                                :noncollinear,
                                :spinorbit,
                                :collinear,
                                :num_bands,
                                :cutoff_ev,
                                :kpoint_nodes,
                                :atomic_type_labels,
                                :type_elements,
                                :upf_files,
                                :metric_kinds,
                            ),
                            Tuple{
                                String,
                                WannierNLQG.SymmetryFoundation.CrystalStructure,
                                Array{Float64, 2},
                                Bool,
                                Bool,
                                Bool,
                                Int64,
                                Float64,
                                Array{WannierizationInternalSupport.EzXML.Node, 1},
                                Array{String, 1},
                                Base.Dict{String, String},
                                Base.Dict{String, String},
                                Base.Dict{String, Symbol},
                            },
                        },
                    },
                },
                Base.Dict{String, String},
                Base.Dict{String, String},
            },
        )
        false
        _record_early_prepare(
            Tuple{
                Type{WannierNLQGWannierizationExt.RepresentationPreparation.QEUPFData},
                String,
                Base.SubString{String},
                Symbol,
                Bool,
                Bool,
                Array{Float64, 1},
                Array{Float64, 1},
                Array{Float64, 2},
                Array{Int64, 1},
                Int64,
                Array{Float64, 1},
                Array{Float64, 2},
                Array{Float64, 2},
                Bool,
                Base.Dict{Tuple{Int64, Int64, Int64}, Array{Float64, 1}},
                Array{Float64, 4},
                Array{Float64, 1},
                Int64,
                Int64,
                Float64,
            },
        )
        false
        _record_early_prepare(
            Tuple{
                WannierNLQGWannierizationExt.RepresentationPreparation.var"#64#65",
                Base.RegexMatch{String},
            },
        )
        _record_early_prepare(
            Tuple{
                typeof(Base.:(*)),
                Array{Base.Complex{Float64}, 2},
                Base.SubArray{
                    Base.Complex{Float64},
                    2,
                    Array{Base.Complex{Float64}, 3},
                    Tuple{Base.Slice{Base.OneTo{Int64}}, Base.Slice{Base.OneTo{Int64}}, Int64},
                    true,
                },
            },
        )
        _record_early_prepare(
            Tuple{
                typeof(Base.:(*)),
                LinearAlgebra.Transpose{
                    Base.Complex{Float64},
                    Base.SubArray{
                        Base.Complex{Float64},
                        2,
                        Array{Base.Complex{Float64}, 3},
                        Tuple{Base.Slice{Base.OneTo{Int64}}, Base.Slice{Base.OneTo{Int64}}, Int64},
                        true,
                    },
                },
                Array{Base.Complex{Float64}, 2},
            },
        )
        _record_early_prepare(Tuple{typeof(Base.:(<=)), Float64, Float64})
        _record_early_prepare(Tuple{typeof(Base.:(==)), Char, Char})
        _record_early_prepare(Tuple{typeof(Base.:(==)), Tuple{Int64, Int64}, Tuple{Int64, Int64}})
        _record_early_prepare(Tuple{typeof(Base.:(>)), Float64})
        _record_early_prepare(Tuple{typeof(Base.:(>)), Int64})
        _record_early_prepare(
            Tuple{
                typeof(Base.Broadcast.broadcasted),
                Type{Base.Complex{Float64}},
                Array{Float64, 1},
                Array{Float64, 1},
            },
        )
        _record_early_prepare(
            Tuple{typeof(Base.Broadcast.broadcasted), Type{Float64}, Array{Float64, 1}},
        )
        _record_early_prepare(
            Tuple{
                typeof(Base.Broadcast.broadcasted),
                typeof(Base.:(*)),
                Float64,
                Array{Float64, 1},
            },
        )
        _record_early_prepare(
            Tuple{
                typeof(Base.Broadcast.broadcasted),
                typeof(Base.:(*)),
                Float64,
                Base.Broadcast.Broadcasted{
                    Base.Broadcast.DefaultArrayStyle{1},
                    Nothing,
                    Type{Base.Complex{Float64}},
                    Tuple{Array{Float64, 1}, Array{Float64, 1}},
                },
            },
        )
        _record_early_prepare(
            Tuple{
                typeof(Base.Broadcast.broadcasted),
                typeof(Base.:(+)),
                Array{Base.Complex{Float64}, 2},
                Array{Base.Complex{Float64}, 2},
            },
        )
        _record_early_prepare(
            Tuple{
                typeof(Base.Broadcast.broadcasted),
                typeof(Base.:(+)),
                Array{Float64, 1},
                Array{Int64, 1},
            },
        )
        _record_early_prepare(
            Tuple{
                typeof(Base.Broadcast.broadcasted),
                typeof(Base.:(-)),
                Array{Float64, 1},
                Base.Broadcast.Broadcasted{
                    Base.Broadcast.DefaultArrayStyle{1},
                    Nothing,
                    typeof(Base.round),
                    Tuple{Array{Float64, 1}},
                },
            },
        )
        _record_early_prepare(
            Tuple{
                typeof(Base.Broadcast.broadcasted),
                typeof(Base.:(-)),
                Array{Float64, 1},
                Base.SubArray{
                    Float64,
                    1,
                    Array{Float64, 2},
                    Tuple{Int64, Base.Slice{Base.OneTo{Int64}}},
                    true,
                },
            },
        )
        _record_early_prepare(
            Tuple{
                typeof(Base.Broadcast.broadcasted),
                typeof(Base.:(-)),
                Base.Broadcast.Broadcasted{
                    Base.Broadcast.DefaultArrayStyle{1},
                    Nothing,
                    typeof(Base.:(+)),
                    Tuple{Array{Float64, 1}, Array{Int64, 1}},
                },
                Array{Float64, 1},
            },
        )
        _record_early_prepare(
            Tuple{typeof(Base.Broadcast.broadcasted), typeof(Base.round), Array{Float64, 1}},
        )
        _record_early_prepare(
            Tuple{
                typeof(Base.Broadcast.copyto_nonleaf!),
                Array{WannierizationInternalSupport.EzXML.Node, 1},
                Base.Broadcast.Broadcasted{
                    Base.Broadcast.DefaultArrayStyle{1},
                    Tuple{Base.OneTo{Int64}},
                    typeof(Base.last),
                    Tuple{
                        Base.Broadcast.Extruded{
                            Array{Pair{Int64, Any}, 1},
                            Tuple{Bool},
                            Tuple{Int64},
                        },
                    },
                },
                Base.OneTo{Int64},
                Int64,
                Int64,
            },
        )
        _record_early_prepare(
            Tuple{
                typeof(Base.Broadcast.materialize!),
                Array{Base.Complex{Float64}, 2},
                Base.Broadcast.Broadcasted{
                    Base.Broadcast.DefaultArrayStyle{2},
                    Nothing,
                    typeof(Base.:(+)),
                    Tuple{Array{Base.Complex{Float64}, 2}, Array{Base.Complex{Float64}, 2}},
                },
            },
        )
        _record_early_prepare(
            Tuple{
                typeof(Base.Broadcast.materialize!),
                Array{Float64, 1},
                Base.Broadcast.Broadcasted{
                    Base.Broadcast.DefaultArrayStyle{1},
                    Nothing,
                    typeof(Base.:(-)),
                    Tuple{
                        Array{Float64, 1},
                        Base.Broadcast.Broadcasted{
                            Base.Broadcast.DefaultArrayStyle{1},
                            Nothing,
                            typeof(Base.round),
                            Tuple{Array{Float64, 1}},
                        },
                    },
                },
            },
        )
        _record_early_prepare(
            Tuple{
                typeof(Base.Broadcast.materialize!),
                Base.SubArray{
                    Base.Complex{Float64},
                    2,
                    Array{Base.Complex{Float64}, 3},
                    Tuple{Base.Slice{Base.OneTo{Int64}}, Base.Slice{Base.OneTo{Int64}}, Int64},
                    true,
                },
                Base.Broadcast.Broadcasted{
                    Base.Broadcast.DefaultArrayStyle{2},
                    Nothing,
                    typeof(Base.identity),
                    Tuple{Array{Base.Complex{Float64}, 2}},
                },
            },
        )
        _record_early_prepare(
            Tuple{
                typeof(Base.Broadcast.materialize!),
                Base.SubArray{
                    Base.Complex{Float64},
                    2,
                    Array{Base.Complex{Float64}, 3},
                    Tuple{Int64, Base.Slice{Base.OneTo{Int64}}, Base.Slice{Base.OneTo{Int64}}},
                    true,
                },
                Base.Broadcast.Broadcasted{
                    Base.Broadcast.DefaultArrayStyle{2},
                    Nothing,
                    typeof(Base.identity),
                    Tuple{Array{Base.Complex{Float64}, 2}},
                },
            },
        )
        _record_early_prepare(
            Tuple{
                typeof(Base.Broadcast.materialize!),
                Base.SubArray{
                    Base.Complex{Float64},
                    2,
                    Array{Base.Complex{Float64}, 4},
                    Tuple{
                        Base.Slice{Base.OneTo{Int64}},
                        Base.Slice{Base.OneTo{Int64}},
                        Int64,
                        Int64,
                    },
                    true,
                },
                Base.Broadcast.Broadcasted{
                    Base.Broadcast.DefaultArrayStyle{2},
                    Nothing,
                    typeof(Base.:(+)),
                    Tuple{Array{Base.Complex{Float64}, 2}, Array{Base.Complex{Float64}, 2}},
                },
            },
        )
        _record_early_prepare(
            Tuple{
                typeof(Base.Broadcast.materialize),
                Base.Broadcast.Broadcasted{
                    Base.Broadcast.DefaultArrayStyle{1},
                    Nothing,
                    Type{Float64},
                    Tuple{Array{Float64, 1}},
                },
            },
        )
        _record_early_prepare(
            Tuple{
                typeof(Base.Broadcast.materialize),
                Base.Broadcast.Broadcasted{
                    Base.Broadcast.DefaultArrayStyle{1},
                    Nothing,
                    typeof(Base.:(*)),
                    Tuple{Float64, Array{Float64, 1}},
                },
            },
        )
        _record_early_prepare(
            Tuple{
                typeof(Base.Broadcast.materialize),
                Base.Broadcast.Broadcasted{
                    Base.Broadcast.DefaultArrayStyle{1},
                    Nothing,
                    typeof(Base.:(*)),
                    Tuple{
                        Float64,
                        Base.Broadcast.Broadcasted{
                            Base.Broadcast.DefaultArrayStyle{1},
                            Nothing,
                            Type{Base.Complex{Float64}},
                            Tuple{Array{Float64, 1}, Array{Float64, 1}},
                        },
                    },
                },
            },
        )
        _record_early_prepare(
            Tuple{
                typeof(Base.Broadcast.materialize),
                Base.Broadcast.Broadcasted{
                    Base.Broadcast.DefaultArrayStyle{1},
                    Nothing,
                    typeof(Base.:(-)),
                    Tuple{
                        Array{Float64, 1},
                        Base.SubArray{
                            Float64,
                            1,
                            Array{Float64, 2},
                            Tuple{Int64, Base.Slice{Base.OneTo{Int64}}},
                            true,
                        },
                    },
                },
            },
        )
        _record_early_prepare(
            Tuple{
                typeof(Base.Broadcast.materialize),
                Base.Broadcast.Broadcasted{
                    Base.Broadcast.DefaultArrayStyle{1},
                    Nothing,
                    typeof(Base.:(-)),
                    Tuple{
                        Base.Broadcast.Broadcasted{
                            Base.Broadcast.DefaultArrayStyle{1},
                            Nothing,
                            typeof(Base.:(+)),
                            Tuple{Array{Float64, 1}, Array{Int64, 1}},
                        },
                        Array{Float64, 1},
                    },
                },
            },
        )
        _record_early_prepare(
            Tuple{
                typeof(Base.Iterators.enumerate),
                Array{WannierizationInternalSupport.EzXML.Node, 1},
            },
        )
        _record_early_prepare(
            Tuple{
                typeof(Base.Iterators.enumerate),
                WannierNLQG.IO.PreparationSourceVector{
                    WannierNLQG.SymmetryFoundation.PlaneWaveKPoint,
                    WannierNLQGWannierizationExt.RepresentationPreparation.var"#99#101"{
                        Bool,
                        WannierNLQG.SymmetryFoundation.QuantumEspressoWavefunctionSource,
                        Int64,
                        Nothing,
                        Base.UnitRange{Int64},
                        NamedTuple{
                            (
                                :xml_file,
                                :structure,
                                :reciprocal_lattice,
                                :noncollinear,
                                :spinorbit,
                                :collinear,
                                :num_bands,
                                :cutoff_ev,
                                :kpoint_nodes,
                                :atomic_type_labels,
                                :type_elements,
                                :upf_files,
                                :metric_kinds,
                            ),
                            Tuple{
                                String,
                                WannierNLQG.SymmetryFoundation.CrystalStructure,
                                Array{Float64, 2},
                                Bool,
                                Bool,
                                Bool,
                                Int64,
                                Float64,
                                Array{WannierizationInternalSupport.EzXML.Node, 1},
                                Array{String, 1},
                                Base.Dict{String, String},
                                Base.Dict{String, String},
                                Base.Dict{String, Symbol},
                            },
                        },
                    },
                },
            },
        )
        _record_early_prepare(
            Tuple{
                typeof(Base._all),
                WannierNLQGWannierizationExt.PAWMatrixElements.var"#140#141"{Int64},
                Array{Int64, 1},
                Base.Colon,
            },
        )
        _record_early_prepare(
            Tuple{
                typeof(Base._getindex),
                Base.IndexLinear,
                Array{Int64, 3},
                Base.Slice{Base.OneTo{Int64}},
                Int64,
                Vararg{Int64},
            },
        )
        _record_early_prepare(
            Tuple{
                typeof(Base._mapreduce_dim),
                Function,
                Function,
                Base._InitialValue,
                Array{Float64, 1},
                Base.Colon,
            },
        )
        _record_early_prepare(
            Tuple{
                typeof(Base._maybe_reshape),
                Base.IndexLinear,
                Array{Int64, 3},
                Base.Slice{Base.OneTo{Int64}},
                Vararg{Any},
            },
        )
        _record_early_prepare(
            Tuple{
                typeof(Base._unsafe_getindex),
                Base.IndexLinear,
                Array{Int64, 3},
                Base.Slice{Base.OneTo{Int64}},
                Int64,
                Int64,
            },
        )
        _record_early_prepare(Tuple{typeof(Base.axes), Array{Base.Complex{Float64}, 3}, Int64})
        _record_early_prepare(
            Tuple{
                typeof(Base.checkbounds),
                Array{Int64, 3},
                Base.Slice{Base.OneTo{Int64}},
                Int64,
                Int64,
            },
        )
        _record_early_prepare(
            Tuple{
                typeof(Base.collect),
                Base.Generator{
                    Base.Iterators.Filter{
                        WannierNLQGWannierizationExt.PAWMatrixElements.var"#142#144"{
                            Base.Set{Int64},
                        },
                        Base.UnitRange{Int64},
                    },
                    typeof(Base.identity),
                },
            },
        )
        _record_early_prepare(Tuple{typeof(Base.collect), Base.UnitRange{Int64}})
        _record_early_prepare(
            Tuple{
                typeof(Base.first),
                WannierNLQG.IO.PreparationSourceVector{
                    WannierNLQG.SymmetryFoundation.PlaneWaveKPoint,
                    WannierNLQGWannierizationExt.RepresentationPreparation.var"#99#101"{
                        Bool,
                        WannierNLQG.SymmetryFoundation.QuantumEspressoWavefunctionSource,
                        Int64,
                        Nothing,
                        Base.UnitRange{Int64},
                        NamedTuple{
                            (
                                :xml_file,
                                :structure,
                                :reciprocal_lattice,
                                :noncollinear,
                                :spinorbit,
                                :collinear,
                                :num_bands,
                                :cutoff_ev,
                                :kpoint_nodes,
                                :atomic_type_labels,
                                :type_elements,
                                :upf_files,
                                :metric_kinds,
                            ),
                            Tuple{
                                String,
                                WannierNLQG.SymmetryFoundation.CrystalStructure,
                                Array{Float64, 2},
                                Bool,
                                Bool,
                                Bool,
                                Int64,
                                Float64,
                                Array{WannierizationInternalSupport.EzXML.Node, 1},
                                Array{String, 1},
                                Base.Dict{String, String},
                                Base.Dict{String, String},
                                Base.Dict{String, Symbol},
                            },
                        },
                    },
                },
            },
        )
        _record_early_prepare(
            Tuple{
                typeof(Base.get),
                Base.Dict{Tuple{Int64, Int64, Int64}, Int64},
                Tuple{Int64, Int64, Int64},
                Int64,
            },
        )
        _record_early_prepare(
            Tuple{typeof(Base.getindex), Array{Array{Base.Complex{Float64}, 3}, 1}, Int64},
        )
        _record_early_prepare(
            Tuple{
                typeof(Base.getindex),
                Array{Base.Complex{Float64}, 2},
                Array{Int64, 1},
                Function,
            },
        )
        _record_early_prepare(Tuple{typeof(Base.getindex), Array{Float64, 1}, Int64})
        _record_early_prepare(
            Tuple{typeof(Base.getindex), Array{Int64, 2}, Array{Int64, 1}, Function},
        )
        _record_early_prepare(
            Tuple{
                typeof(Base.getindex),
                Base.SubArray{
                    Float64,
                    1,
                    Array{Float64, 2},
                    Tuple{Base.Slice{Base.OneTo{Int64}}, Int64},
                    true,
                },
                Base.StepRange{Int64, Int64},
            },
        )
        false
        _record_early_prepare(
            Tuple{
                typeof(Base.getindex),
                Type{WannierNLQG.IO.WannierNNKPProjection},
                WannierNLQG.IO.WannierNNKPProjection,
            },
        )
        _record_early_prepare(
            Tuple{
                typeof(Base.getindex),
                WannierNLQG.IO.PreparationSourceVector{
                    WannierNLQG.SymmetryFoundation.PlaneWaveKPoint,
                    WannierNLQGWannierizationExt.RepresentationPreparation.var"#99#101"{
                        Bool,
                        WannierNLQG.SymmetryFoundation.QuantumEspressoWavefunctionSource,
                        Int64,
                        Nothing,
                        Base.UnitRange{Int64},
                        NamedTuple{
                            (
                                :xml_file,
                                :structure,
                                :reciprocal_lattice,
                                :noncollinear,
                                :spinorbit,
                                :collinear,
                                :num_bands,
                                :cutoff_ev,
                                :kpoint_nodes,
                                :atomic_type_labels,
                                :type_elements,
                                :upf_files,
                                :metric_kinds,
                            ),
                            Tuple{
                                String,
                                WannierNLQG.SymmetryFoundation.CrystalStructure,
                                Array{Float64, 2},
                                Bool,
                                Bool,
                                Bool,
                                Int64,
                                Float64,
                                Array{WannierizationInternalSupport.EzXML.Node, 1},
                                Array{String, 1},
                                Base.Dict{String, String},
                                Base.Dict{String, String},
                                Base.Dict{String, Symbol},
                            },
                        },
                    },
                },
                Int64,
            },
        )
        _record_early_prepare(
            Tuple{typeof(Base.getproperty), WannierNLQG.SymmetryFoundation.PlaneWaveKPoint, Symbol},
        )
        _record_early_prepare(
            Tuple{
                typeof(Base.grow_to!),
                Base.Dict{Tuple{Int64, Int64, Int64}, Int64},
                Base.Generator{
                    Base.OneTo{Int64},
                    WannierNLQGWannierizationExt.PAWMatrixElements.var"#71#74"{
                        WannierNLQG.SymmetryFoundation.PlaneWaveKPoint,
                    },
                },
                Int64,
            },
        )
        _record_early_prepare(Tuple{typeof(Base.haskey), Base.Dict{Base.PkgId, Module}, Base.PkgId})
        _record_early_prepare(Tuple{typeof(Base.isfinite), Float64})
        _record_early_prepare(
            Tuple{
                typeof(Base.issorted),
                Array{String, 1},
                Base.Order.ReverseOrdering{Base.Order.ForwardOrdering},
            },
        )
        _record_early_prepare(Tuple{typeof(Base.iszero), Bool})
        _record_early_prepare(Tuple{typeof(Base.iterate), Array{Array{String, 1}, 1}})
        false
        false
        _record_early_prepare(
            Tuple{
                typeof(Base.iterate),
                Base.Iterators.Enumerate{Array{WannierizationInternalSupport.EzXML.Node, 1}},
                Tuple{Int64, Int64},
            },
        )
        _record_early_prepare(
            Tuple{
                typeof(Base.iterate),
                Base.Iterators.Enumerate{Array{WannierizationInternalSupport.EzXML.Node, 1}},
                Tuple{Int64},
            },
        )
        _record_early_prepare(
            Tuple{
                typeof(Base.iterate),
                Base.Iterators.Enumerate{
                    WannierNLQG.IO.PreparationSourceVector{
                        WannierNLQG.SymmetryFoundation.PlaneWaveKPoint,
                        WannierNLQGWannierizationExt.RepresentationPreparation.var"#99#101"{
                            Bool,
                            WannierNLQG.SymmetryFoundation.QuantumEspressoWavefunctionSource,
                            Int64,
                            Nothing,
                            Base.UnitRange{Int64},
                            NamedTuple{
                                (
                                    :xml_file,
                                    :structure,
                                    :reciprocal_lattice,
                                    :noncollinear,
                                    :spinorbit,
                                    :collinear,
                                    :num_bands,
                                    :cutoff_ev,
                                    :kpoint_nodes,
                                    :atomic_type_labels,
                                    :type_elements,
                                    :upf_files,
                                    :metric_kinds,
                                ),
                                Tuple{
                                    String,
                                    WannierNLQG.SymmetryFoundation.CrystalStructure,
                                    Array{Float64, 2},
                                    Bool,
                                    Bool,
                                    Bool,
                                    Int64,
                                    Float64,
                                    Array{WannierizationInternalSupport.EzXML.Node, 1},
                                    Array{String, 1},
                                    Base.Dict{String, String},
                                    Base.Dict{String, String},
                                    Base.Dict{String, Symbol},
                                },
                            },
                        },
                    },
                },
                Tuple{Int64, Tuple{Base.OneTo{Int64}, Int64}},
            },
        )
        _record_early_prepare(
            Tuple{
                typeof(Base.iterate),
                Base.Iterators.Enumerate{
                    WannierNLQG.IO.PreparationSourceVector{
                        WannierNLQG.SymmetryFoundation.PlaneWaveKPoint,
                        WannierNLQGWannierizationExt.RepresentationPreparation.var"#99#101"{
                            Bool,
                            WannierNLQG.SymmetryFoundation.QuantumEspressoWavefunctionSource,
                            Int64,
                            Nothing,
                            Base.UnitRange{Int64},
                            NamedTuple{
                                (
                                    :xml_file,
                                    :structure,
                                    :reciprocal_lattice,
                                    :noncollinear,
                                    :spinorbit,
                                    :collinear,
                                    :num_bands,
                                    :cutoff_ev,
                                    :kpoint_nodes,
                                    :atomic_type_labels,
                                    :type_elements,
                                    :upf_files,
                                    :metric_kinds,
                                ),
                                Tuple{
                                    String,
                                    WannierNLQG.SymmetryFoundation.CrystalStructure,
                                    Array{Float64, 2},
                                    Bool,
                                    Bool,
                                    Bool,
                                    Int64,
                                    Float64,
                                    Array{WannierizationInternalSupport.EzXML.Node, 1},
                                    Array{String, 1},
                                    Base.Dict{String, String},
                                    Base.Dict{String, String},
                                    Base.Dict{String, Symbol},
                                },
                            },
                        },
                    },
                },
                Tuple{Int64},
            },
        )
        _record_early_prepare(Tuple{typeof(Base.join), Array{Int64, 1}, String})
        _record_early_prepare(
            Tuple{
                typeof(Base.join),
                Base.GenericIOBuffer{GenericMemory{:not_atomic, UInt8, Core.AddrSpace{Core}(0x00)}},
                Array{Int64, 1},
                String,
            },
        )
        _record_early_prepare(
            Tuple{
                typeof(Base.lastindex),
                Base.SubArray{
                    Float64,
                    1,
                    Array{Float64, 2},
                    Tuple{Base.Slice{Base.OneTo{Int64}}, Int64},
                    true,
                },
            },
        )
        _record_early_prepare(
            Tuple{typeof(Base.length), Array{WannierizationInternalSupport.EzXML.Node, 1}},
        )
        _record_early_prepare(Tuple{typeof(Base.length), Array{Float64, 1}})
        _record_early_prepare(Tuple{typeof(Base.length), Array{Int64, 1}})
        _record_early_prepare(
            Tuple{
                typeof(Base.length),
                WannierNLQG.IO.PreparationSourceVector{
                    WannierNLQG.SymmetryFoundation.PlaneWaveKPoint,
                    WannierNLQGWannierizationExt.RepresentationPreparation.var"#99#101"{
                        Bool,
                        WannierNLQG.SymmetryFoundation.QuantumEspressoWavefunctionSource,
                        Int64,
                        Nothing,
                        Base.UnitRange{Int64},
                        NamedTuple{
                            (
                                :xml_file,
                                :structure,
                                :reciprocal_lattice,
                                :noncollinear,
                                :spinorbit,
                                :collinear,
                                :num_bands,
                                :cutoff_ev,
                                :kpoint_nodes,
                                :atomic_type_labels,
                                :type_elements,
                                :upf_files,
                                :metric_kinds,
                            ),
                            Tuple{
                                String,
                                WannierNLQG.SymmetryFoundation.CrystalStructure,
                                Array{Float64, 2},
                                Bool,
                                Bool,
                                Bool,
                                Int64,
                                Float64,
                                Array{WannierizationInternalSupport.EzXML.Node, 1},
                                Array{String, 1},
                                Base.Dict{String, String},
                                Base.Dict{String, String},
                                Base.Dict{String, Symbol},
                            },
                        },
                    },
                },
            },
        )
        _record_early_prepare(
            Tuple{typeof(Base.literal_pow), typeof(Base.:(^)), Int64, Base.Val{2}},
        )
        _record_early_prepare(Tuple{typeof(Base.maximum), Array{Int64, 1}})
        _record_early_prepare(Tuple{typeof(Base.maximum), Function, Array{Float64, 1}})
        _record_early_prepare(Tuple{typeof(Base.push!), Array{Int64, 1}, Int64})
        _record_early_prepare(
            Tuple{typeof(Base.reshape), Array{Base.Complex{Float64}, 1}, Int64, Int64},
        )
        _record_early_prepare(
            Tuple{
                typeof(Base.setindex!),
                Array{WannierizationInternalSupport.EzXML.Node, 1},
                WannierizationInternalSupport.EzXML.Node,
                Int64,
            },
        )
        _record_early_prepare(Tuple{typeof(Base.setindex!), Base.EnvDict, String, String})
        _record_early_prepare(
            Tuple{
                typeof(Base.similar),
                Base.Broadcast.Broadcasted{
                    Base.Broadcast.DefaultArrayStyle{1},
                    Tuple{Base.OneTo{Int64}},
                    typeof(Base.last),
                    Tuple{
                        Base.Broadcast.Extruded{
                            Array{Pair{Int64, Any}, 1},
                            Tuple{Bool},
                            Tuple{Int64},
                        },
                    },
                },
                Type{WannierizationInternalSupport.EzXML.Node},
            },
        )
        _record_early_prepare(Tuple{typeof(Base.size), Array{Base.Complex{Float64}, 3}, Int64})
        _record_early_prepare(Tuple{typeof(Base.size), Array{Float64, 2}})
        _record_early_prepare(Tuple{typeof(Base.size), Array{Int64, 2}})
        _record_early_prepare(
            Tuple{typeof(Base.to_indices), Array{Int64, 3}, Tuple{Base.OneTo{Int64}}, Tuple{Int64}},
        )
        _record_early_prepare(Tuple{typeof(Base.transpose), Array{Float64, 1}})
        _record_early_prepare(Tuple{typeof(Base.transpose), Array{Float64, 2}})
        _record_early_prepare(Tuple{typeof(Base.transpose), Array{Int64, 2}})
        _record_early_prepare(
            Tuple{
                typeof(Base.transpose),
                Base.SubArray{
                    Base.Complex{Float64},
                    2,
                    Array{Base.Complex{Float64}, 3},
                    Tuple{Base.Slice{Base.OneTo{Int64}}, Base.Slice{Base.OneTo{Int64}}, Int64},
                    true,
                },
            },
        )
        _record_early_prepare(
            Tuple{
                typeof(Base.vcat),
                Array{Float64, 2},
                LinearAlgebra.Transpose{Float64, Array{Float64, 1}},
            },
        )
        _record_early_prepare(
            Tuple{
                typeof(Base.vcat),
                LinearAlgebra.Transpose{Float64, Array{Float64, 1}},
                LinearAlgebra.Transpose{Float64, Array{Float64, 1}},
            },
        )
        _record_early_prepare(Tuple{typeof(Base.vect), Array{String, 1}, Vararg{Array{String, 1}}})
        _record_early_prepare(
            Tuple{typeof(Base.view), Array{Base.Complex{Float64}, 3}, Function, Function, Int64},
        )
        _record_early_prepare(
            Tuple{
                typeof(Base.view),
                Array{Base.Complex{Float64}, 4},
                Function,
                Function,
                Int64,
                Int64,
            },
        )
        _record_early_prepare(Tuple{typeof(Base.view), Array{Float64, 2}, Function, Int64})
        _record_early_prepare(
            Tuple{typeof(Base.zeros), Type{Base.Complex{Float64}}, Int64, Int64, Vararg{Int64}},
        )
        _record_early_prepare(
            Tuple{typeof(Base.zeros), Type{Base.Complex{Float64}}, Tuple{Int64, Int64}},
        )
        _record_early_prepare(Tuple{typeof(Base.zeros), Type{Float64}, Int64, Int64, Vararg{Int64}})
        _record_early_prepare(Tuple{typeof(Base.zeros), Type{Float64}, Tuple{Int64, Int64}})
        _record_early_prepare(
            Tuple{
                typeof(Core.kwcall),
                NamedTuple{
                    (
                        :artifact_dir,
                        :oracle_mmn_file,
                        :oracle_amn_file,
                        :require_oracle,
                        :thresholds,
                    ),
                    Tuple{
                        String,
                        Nothing,
                        Nothing,
                        Bool,
                        WannierNLQG.Wannierization.QEPAWParityThresholds,
                    },
                },
                typeof(
                    WannierNLQGWannierizationExt.PAWMatrixElements.generate_qe_paw_matrix_elements,
                ),
                WannierNLQG.SymmetryFoundation.QuantumEspressoWavefunctionSource,
                String,
            },
        )
        false
        _record_early_prepare(
            Tuple{
                typeof(Core.kwcall),
                NamedTuple{(:artifact_dir, :require_oracle), Tuple{String, Bool}},
                typeof(WannierNLQG.Wannierization.generate_qe_paw_matrix_elements),
                WannierNLQG.SymmetryFoundation.QuantumEspressoWavefunctionSource,
                String,
            },
        )
        _record_early_prepare(
            Tuple{
                typeof(Core.kwcall),
                NamedTuple{(:default,), Tuple{Int64}},
                typeof(
                    WannierNLQGWannierizationExt.RepresentationPreparation._qe_upf_integer_attribute,
                ),
                WannierizationInternalSupport.EzXML.Node,
                String,
            },
        )
        _record_early_prepare(
            Tuple{
                typeof(Core.kwcall),
                NamedTuple{(:normalize_coefficients,), Tuple{Bool}},
                Type{WannierNLQG.SymmetryFoundation.PlaneWaveKPoint},
                Array{Float64, 1},
                Array{Int64, 2},
                Array{Base.Complex{Float64}, 3},
                Array{Float64, 1},
            },
        )
        _record_early_prepare(
            Tuple{typeof(HDF5.API.try_close_finalizer), HDF5.AttributeAccessProperties},
        )
        _record_early_prepare(
            Tuple{typeof(HDF5.API.try_close_finalizer), HDF5.AttributeCreateProperties},
        )
        _record_early_prepare(
            Tuple{typeof(HDF5.API.try_close_finalizer), HDF5.DatasetAccessProperties},
        )
        _record_early_prepare(
            Tuple{typeof(HDF5.API.try_close_finalizer), HDF5.DatasetTransferProperties},
        )
        _record_early_prepare(
            Tuple{typeof(HDF5.API.try_close_finalizer), HDF5.DatatypeAccessProperties},
        )
        _record_early_prepare(
            Tuple{typeof(HDF5.API.try_close_finalizer), HDF5.DatatypeCreateProperties},
        )
        _record_early_prepare(Tuple{typeof(HDF5.API.try_close_finalizer), HDF5.Datatype})
        _record_early_prepare(
            Tuple{typeof(HDF5.API.try_close_finalizer), HDF5.FileCreateProperties},
        )
        _record_early_prepare(Tuple{typeof(HDF5.API.try_close_finalizer), HDF5.FileMountProperties})
        _record_early_prepare(
            Tuple{typeof(HDF5.API.try_close_finalizer), HDF5.GroupAccessProperties},
        )
        _record_early_prepare(
            Tuple{typeof(HDF5.API.try_close_finalizer), HDF5.GroupCreateProperties},
        )
        _record_early_prepare(
            Tuple{typeof(HDF5.API.try_close_finalizer), HDF5.LinkAccessProperties},
        )
        _record_early_prepare(
            Tuple{typeof(HDF5.API.try_close_finalizer), HDF5.LinkCreateProperties},
        )
        _record_early_prepare(
            Tuple{typeof(HDF5.API.try_close_finalizer), HDF5.ObjectCopyProperties},
        )
        _record_early_prepare(
            Tuple{typeof(HDF5.API.try_close_finalizer), HDF5.ObjectCreateProperties},
        )
        _record_early_prepare(
            Tuple{typeof(HDF5.API.try_close_finalizer), HDF5.StringCreateProperties},
        )
        _record_early_prepare(
            Tuple{
                typeof(LinearAlgebra.dot),
                Tuple{Float64, Float64, Float64},
                Tuple{Float64, Float64, Float64},
            },
        )
        _record_early_prepare(
            Tuple{
                typeof(Printf.computelen),
                Array{Base.UnitRange{Int64}, 1},
                Tuple{
                    Printf.Spec{Base.Val{reinterpret(Char, UInt32(0x64000000))}},
                    Printf.Spec{Base.Val{reinterpret(Char, UInt32(0x64000000))}},
                    Printf.Spec{Base.Val{reinterpret(Char, UInt32(0x64000000))}},
                    Printf.Spec{Base.Val{reinterpret(Char, UInt32(0x67000000))}},
                    Printf.Spec{Base.Val{reinterpret(Char, UInt32(0x67000000))}},
                },
                Tuple{Int64, Int64, Int64, Float64, Float64},
            },
        )
        _record_early_prepare(
            Tuple{
                typeof(Printf.fmt),
                Array{UInt8, 1},
                Int64,
                Float64,
                Printf.Spec{Base.Val{reinterpret(Char, UInt32(0x67000000))}},
            },
        )
        _record_early_prepare(
            Tuple{
                typeof(Printf.fmt),
                Array{UInt8, 1},
                Int64,
                Tuple{Int64, Int64, Int64, Float64, Float64},
                Int64,
                Printf.Spec{Base.Val{reinterpret(Char, UInt32(0x64000000))}},
            },
        )
        _record_early_prepare(
            Tuple{
                typeof(Printf.format),
                Array{UInt8, 1},
                Int64,
                Printf.Format{
                    Base.CodeUnits{UInt8, String},
                    NTuple{5, Printf.Spec{Base.Val{reinterpret(Char, UInt32(0x64000000))}}},
                },
                Int64,
                Vararg{Int64},
            },
        )
        _record_early_prepare(
            Tuple{
                typeof(Printf.format),
                Array{UInt8, 1},
                Int64,
                Printf.Format{
                    Base.CodeUnits{UInt8, String},
                    Tuple{
                        Printf.Spec{Base.Val{reinterpret(Char, UInt32(0x64000000))}},
                        Printf.Spec{Base.Val{reinterpret(Char, UInt32(0x64000000))}},
                        Printf.Spec{Base.Val{reinterpret(Char, UInt32(0x64000000))}},
                        Printf.Spec{Base.Val{reinterpret(Char, UInt32(0x67000000))}},
                        Printf.Spec{Base.Val{reinterpret(Char, UInt32(0x67000000))}},
                    },
                },
                Int64,
                Vararg{Any},
            },
        )
        _record_early_prepare(
            Tuple{
                typeof(Printf.format),
                Array{UInt8, 1},
                Int64,
                Printf.Format{
                    Base.CodeUnits{UInt8, String},
                    Tuple{
                        Printf.Spec{Base.Val{reinterpret(Char, UInt32(0x64000000))}},
                        Printf.Spec{Base.Val{reinterpret(Char, UInt32(0x64000000))}},
                        Printf.Spec{Base.Val{reinterpret(Char, UInt32(0x64000000))}},
                    },
                },
                Int64,
                Vararg{Int64},
            },
        )
        _record_early_prepare(
            Tuple{
                typeof(WannierNLQG.IO.preparation_source_vector),
                WannierNLQGWannierizationExt.RepresentationPreparation.var"#99#101"{
                    Bool,
                    WannierNLQG.SymmetryFoundation.QuantumEspressoWavefunctionSource,
                    Int64,
                    Nothing,
                    Base.UnitRange{Int64},
                    NamedTuple{
                        (
                            :xml_file,
                            :structure,
                            :reciprocal_lattice,
                            :noncollinear,
                            :spinorbit,
                            :collinear,
                            :num_bands,
                            :cutoff_ev,
                            :kpoint_nodes,
                            :atomic_type_labels,
                            :type_elements,
                            :upf_files,
                            :metric_kinds,
                        ),
                        Tuple{
                            String,
                            WannierNLQG.SymmetryFoundation.CrystalStructure,
                            Array{Float64, 2},
                            Bool,
                            Bool,
                            Bool,
                            Int64,
                            Float64,
                            Array{WannierizationInternalSupport.EzXML.Node, 1},
                            Array{String, 1},
                            Base.Dict{String, String},
                            Base.Dict{String, String},
                            Base.Dict{String, Symbol},
                        },
                    },
                },
                Type{WannierNLQG.SymmetryFoundation.PlaneWaveKPoint},
                Int64,
            },
        )
        _record_early_prepare(
            Tuple{
                typeof(WannierNLQGWannierizationExt.PAWMatrixElements._qe_generate_amn),
                WannierNLQG.SymmetryFoundation.NativeWavefunctionData,
                WannierNLQG.IO.WannierNNKP,
                Array{Array{Base.Complex{Float64}, 3}, 1},
                Array{Array{Base.Complex{Float64}, 2}, 1},
                Base.Dict{String, WannierNLQGWannierizationExt.RepresentationPreparation.QEUPFData},
                WannierNLQGWannierizationExt.RepresentationPreparation.QEProjectorPlan,
                Bool,
            },
        )
        _record_early_prepare(
            Tuple{
                typeof(
                    WannierNLQGWannierizationExt.RepresentationPreparation._qe_upf_integer_attribute,
                ),
                WannierizationInternalSupport.EzXML.Node,
                String,
            },
        )
        _record_early_prepare(
            Tuple{
                typeof(
                    WannierNLQGWannierizationExt.RepresentationPreparation._qe_upf_relativistic_j,
                ),
                WannierizationInternalSupport.EzXML.Node,
                Array{WannierizationInternalSupport.EzXML.Node, 1},
                Bool,
            },
        )
        @assert !WannierNLQG.MPI.Initialized()
    end
end

@compile_workload begin
    if WannierizationInternalSupport.WannierNLQG.FIRST_USE_WORKLOAD_ENABLED
        false
    end
end

include("OrdinarySolverFirstUseCoverage.jl")

include("CheckpointReadFirstUseCoverage.jl")

include("QESPnFirstUseCoverage.jl")

include("NativeOperatorFirstUseCoverage.jl")

include("ProjectionSearchFirstUseCoverage.jl")

include("UIUFirstUseCoverage.jl")

include("VASPSPNFirstUseCoverage.jl")

include("VASPMatrixFirstUseCoverage.jl")

# R15: observed cold TB qualification signatures, before optional Spglib activation.
# Compile signatures only; no files, solver calls, runtime handles or MPI initialization.
import JSON3
const COLD_TB_QUALIFICATION_RESULTS = Tuple{Bool, Bool}[]
@compile_workload let
    if WannierNLQG.FIRST_USE_WORKLOAD_ENABLED
        WannierNLQGOperatorBundleExt =
            Base.get_extension(WannierNLQG, :WannierNLQGOperatorBundleExt)
        @assert WannierNLQGOperatorBundleExt !== nothing
        let signature = Tuple{
                typeof(Core.kwcall),
                NamedTuple{
                    (:hamiltonian_covariance_threshold, :persist_hdf5),
                    Tuple{Float64, Bool},
                },
                typeof(WannierNLQG.Wannierization.qualify_exported_wannierization_tb),
                String,
                Vararg{Any},
            }
            push!(COLD_TB_QUALIFICATION_RESULTS, (precompile(signature), false))
        end
        let signature = Tuple{
                WannierNLQG.Wannierization.var"##qualify_exported_wannierization_tb#127",
                Base.Pairs{
                    Symbol,
                    Real,
                    Tuple{Symbol, Symbol},
                    NamedTuple{
                        (:hamiltonian_covariance_threshold, :persist_hdf5),
                        Tuple{Float64, Bool},
                    },
                },
                typeof(WannierNLQG.Wannierization.qualify_exported_wannierization_tb),
                String,
                Vararg{Any},
            }
            push!(COLD_TB_QUALIFICATION_RESULTS, (precompile(signature), false))
        end
        let signature = Tuple{
                typeof(Core.kwcall),
                NamedTuple{
                    (:hamiltonian_covariance_threshold, :persist_hdf5),
                    Tuple{Float64, Bool},
                },
                typeof(WannierNLQG.Wannierization._call_wannierization_extension),
                Symbol,
                String,
                Vararg{Any},
            }
            push!(COLD_TB_QUALIFICATION_RESULTS, (precompile(signature), false))
        end
        let signature = Tuple{
                WannierNLQG.Wannierization.var"##_call_wannierization_extension#112",
                Base.Pairs{
                    Symbol,
                    Real,
                    Tuple{Symbol, Symbol},
                    NamedTuple{
                        (:hamiltonian_covariance_threshold, :persist_hdf5),
                        Tuple{Float64, Bool},
                    },
                },
                typeof(WannierNLQG.Wannierization._call_wannierization_extension),
                Symbol,
                String,
                Vararg{Any},
            }
            push!(COLD_TB_QUALIFICATION_RESULTS, (precompile(signature), false))
        end
        let signature = Tuple{typeof(Base.vect), Array{String, 1}, Vararg{Array{String, 1}}}
            push!(COLD_TB_QUALIFICATION_RESULTS, (precompile(signature), false))
        end
        let signature = Tuple{typeof(Base.iterate), Array{Array{String, 1}, 1}}
            push!(COLD_TB_QUALIFICATION_RESULTS, (precompile(signature), false))
        end
        let signature = Tuple{
                typeof(Base.issorted),
                Array{String, 1},
                Base.Order.ReverseOrdering{Base.Order.ForwardOrdering},
            }
            push!(COLD_TB_QUALIFICATION_RESULTS, (precompile(signature), false))
        end
        let signature = Tuple{typeof(Base.setindex!), Base.EnvDict, String, String}
            push!(COLD_TB_QUALIFICATION_RESULTS, (precompile(signature), false))
        end

        let signature = Tuple{typeof(Base.haskey), Base.Dict{Base.PkgId, Module}, Base.PkgId}
            push!(COLD_TB_QUALIFICATION_RESULTS, (precompile(signature), false))
        end

        let signature = Tuple{
                typeof(Base.getindex),
                Type{Union{Nothing, Array{String, 1}}},
                Nothing,
                Array{String, 1},
            }
            push!(COLD_TB_QUALIFICATION_RESULTS, (false, false))
        end
        let signature = Tuple{typeof(Base.iterate), Array{Union{Nothing, Array{String, 1}}, 1}}
            push!(COLD_TB_QUALIFICATION_RESULTS, (false, false))
        end
        let signature =
                Tuple{typeof(Base.iterate), Array{Union{Nothing, Array{String, 1}}, 1}, Int64}
            push!(COLD_TB_QUALIFICATION_RESULTS, (false, false))
        end
        let signature = Tuple{
                typeof(Core.kwcall),
                NamedTuple{
                    (:hamiltonian_covariance_threshold, :persist_hdf5),
                    Tuple{Float64, Bool},
                },
                typeof(Base.invokelatest),
                Any,
                Any,
                Vararg{Any},
            }
            push!(COLD_TB_QUALIFICATION_RESULTS, (precompile(signature), false))
        end
        let signature = Tuple{
                Base.var"##invokelatest#2",
                Base.Pairs{
                    Symbol,
                    Real,
                    Tuple{Symbol, Symbol},
                    NamedTuple{
                        (:hamiltonian_covariance_threshold, :persist_hdf5),
                        Tuple{Float64, Bool},
                    },
                },
                typeof(Base.invokelatest),
                Any,
                Any,
                Vararg{Any},
            }
            push!(COLD_TB_QUALIFICATION_RESULTS, (precompile(signature), false))
        end
        let signature = Tuple{Type{NamedTuple{(:prefer_mmap,), T} where T <: Tuple}, Tuple{Bool}}
            push!(COLD_TB_QUALIFICATION_RESULTS, (precompile(signature), false))
        end
        let signature = Tuple{typeof(Base.tail), NTuple{16, Symbol}}
            push!(COLD_TB_QUALIFICATION_RESULTS, (precompile(signature), false))
        end
        let signature = Tuple{typeof(Base.tail), NTuple{15, Symbol}}
            push!(COLD_TB_QUALIFICATION_RESULTS, (precompile(signature), false))
        end
        let signature = Tuple{typeof(Base.tail), NTuple{14, Symbol}}
            push!(COLD_TB_QUALIFICATION_RESULTS, (precompile(signature), false))
        end
        let signature = Tuple{typeof(Base.tail), NTuple{13, Symbol}}
            push!(COLD_TB_QUALIFICATION_RESULTS, (precompile(signature), false))
        end
        let signature = Tuple{typeof(Base.tail), NTuple{12, Symbol}}
            push!(COLD_TB_QUALIFICATION_RESULTS, (precompile(signature), false))
        end
        let signature = Tuple{typeof(Base.tail), NTuple{11, Symbol}}
            push!(COLD_TB_QUALIFICATION_RESULTS, (precompile(signature), false))
        end
        let signature = Tuple{typeof(Base.tail), NTuple{10, Symbol}}
            push!(COLD_TB_QUALIFICATION_RESULTS, (precompile(signature), false))
        end
        let signature = Tuple{typeof(Base.tail), NTuple{9, Symbol}}
            push!(COLD_TB_QUALIFICATION_RESULTS, (precompile(signature), false))
        end
        let signature = Tuple{typeof(Base.tail), NTuple{8, Symbol}}
            push!(COLD_TB_QUALIFICATION_RESULTS, (precompile(signature), false))
        end
        let signature = Tuple{typeof(Base.tail), NTuple{7, Symbol}}
            push!(COLD_TB_QUALIFICATION_RESULTS, (precompile(signature), false))
        end
        let signature = Tuple{typeof(Base.tail), NTuple{6, Symbol}}
            push!(COLD_TB_QUALIFICATION_RESULTS, (precompile(signature), false))
        end
        let signature = Tuple{typeof(Base.tail), NTuple{5, Symbol}}
            push!(COLD_TB_QUALIFICATION_RESULTS, (precompile(signature), false))
        end
        let signature = Tuple{typeof(Base.tail), NTuple{4, Symbol}}
            push!(COLD_TB_QUALIFICATION_RESULTS, (precompile(signature), false))
        end
        let signature = Tuple{typeof(Base.in), String, Tuple{String, String, String}}
            push!(COLD_TB_QUALIFICATION_RESULTS, (precompile(signature), false))
        end
        let signature = Tuple{typeof(Base.:(>)), Int64}
            push!(COLD_TB_QUALIFICATION_RESULTS, (precompile(signature), false))
        end
        let signature = Tuple{typeof(Base.in), String, NTuple{11, String}}
            push!(COLD_TB_QUALIFICATION_RESULTS, (precompile(signature), false))
        end
        let signature = Tuple{typeof(Base.in), String, NTuple{8, String}}
            push!(COLD_TB_QUALIFICATION_RESULTS, (precompile(signature), false))
        end
        let signature = Tuple{typeof(Base.in), String, NTuple{6, String}}
            push!(COLD_TB_QUALIFICATION_RESULTS, (precompile(signature), false))
        end
        let signature = Tuple{typeof(Base.in), String, NTuple{5, String}}
            push!(COLD_TB_QUALIFICATION_RESULTS, (precompile(signature), false))
        end
        let signature =
                Tuple{Type{NamedTuple{(:skip_payload_sha256,), T} where T <: Tuple}, Tuple{Bool}}
            push!(COLD_TB_QUALIFICATION_RESULTS, (precompile(signature), false))
        end
        let signature = Tuple{typeof(Base.in), String, Tuple{String, String}}
            push!(COLD_TB_QUALIFICATION_RESULTS, (precompile(signature), false))
        end
        let signature = Tuple{
                typeof(Core.kwcall),
                NamedTuple{(:verify_digests,), Tuple{Bool}},
                typeof(WannierNLQGOperatorBundleExt.read_real_space_operator_bundle),
                String,
            }
            push!(COLD_TB_QUALIFICATION_RESULTS, (precompile(signature), false))
        end
        let signature = Tuple{Type{Array{Int64, N} where N}, UndefInitializer, Int64}
            push!(COLD_TB_QUALIFICATION_RESULTS, (precompile(signature), false))
        end
        let signature = Tuple{typeof(Base.getproperty), HDF5.GroupCreateProperties, Symbol}
            push!(COLD_TB_QUALIFICATION_RESULTS, (precompile(signature), false))
        end
        let signature = Tuple{Type{Array{Float64, N} where N}, UndefInitializer, Int64, Int64}
            push!(COLD_TB_QUALIFICATION_RESULTS, (precompile(signature), false))
        end
        let signature = Tuple{Type{Array{Int64, N} where N}, UndefInitializer, Int64, Int64}
            push!(COLD_TB_QUALIFICATION_RESULTS, (precompile(signature), false))
        end
        let signature = Tuple{Type{Array{Int64, 1}}, Array{Int64, 1}}
            push!(COLD_TB_QUALIFICATION_RESULTS, (precompile(signature), false))
        end
        let signature = Tuple{typeof(Base.size), Array{Float64, 2}}
            push!(COLD_TB_QUALIFICATION_RESULTS, (precompile(signature), false))
        end
        let signature = Tuple{typeof(Base.:(==)), Tuple{Int64, Int64}, Tuple{Int64, Int64}}
            push!(COLD_TB_QUALIFICATION_RESULTS, (precompile(signature), false))
        end
        let signature = Tuple{typeof(Base.size), Array{Int64, 2}, Int64}
            push!(COLD_TB_QUALIFICATION_RESULTS, (precompile(signature), false))
        end
        let signature = Tuple{typeof(Base.length), Array{Int64, 1}}
            push!(COLD_TB_QUALIFICATION_RESULTS, (precompile(signature), false))
        end
        let signature = Tuple{
                typeof(Base._all),
                Base.Fix2{typeof(Base.:(>)), Int64},
                Array{Int64, 1},
                Base.Colon,
            }
            push!(COLD_TB_QUALIFICATION_RESULTS, (precompile(signature), false))
        end
        let signature = Tuple{Type{Array{Bool, N} where N}, UndefInitializer, Int64}
            push!(COLD_TB_QUALIFICATION_RESULTS, (precompile(signature), false))
        end
        let signature = Tuple{typeof(Base.getindex), Array{Bool, 1}, Int64}
            push!(COLD_TB_QUALIFICATION_RESULTS, (precompile(signature), false))
        end
        let signature = Tuple{Type{Array{Float64, N} where N}, UndefInitializer, Int64}
            push!(COLD_TB_QUALIFICATION_RESULTS, (precompile(signature), false))
        end
        let signature = Tuple{typeof(Base.getindex), Array{Float64, 1}, Int64}
            push!(COLD_TB_QUALIFICATION_RESULTS, (precompile(signature), false))
        end
        let signature = Tuple{typeof(Base.:(<=)), Float64, Float64}
            push!(COLD_TB_QUALIFICATION_RESULTS, (precompile(signature), false))
        end
        let signature = Tuple{typeof(Base.:(==)), Bool, Bool}
            push!(COLD_TB_QUALIFICATION_RESULTS, (precompile(signature), false))
        end
        let signature = Tuple{Type{Array{UInt8, N} where N}, UndefInitializer, Int64}
            push!(COLD_TB_QUALIFICATION_RESULTS, (precompile(signature), false))
        end
        let signature = Tuple{Type{Array{Int8, N} where N}, UndefInitializer, Int64, Int64}
            push!(COLD_TB_QUALIFICATION_RESULTS, (precompile(signature), false))
        end
        let signature = Tuple{Type{Array{UInt64, N} where N}, UndefInitializer, Int64}
            push!(COLD_TB_QUALIFICATION_RESULTS, (precompile(signature), false))
        end
        let signature = Tuple{Type{Array{UInt64, N} where N}, UndefInitializer, Int64, Int64}
            push!(COLD_TB_QUALIFICATION_RESULTS, (precompile(signature), false))
        end
        let signature = Tuple{typeof(Base.Broadcast.broadcasted), Type{String}, Array{String, 1}}
            push!(COLD_TB_QUALIFICATION_RESULTS, (precompile(signature), false))
        end
        let signature = Tuple{
                typeof(Base.Broadcast.materialize),
                Base.Broadcast.Broadcasted{
                    Base.Broadcast.DefaultArrayStyle{1},
                    Nothing,
                    Type{String},
                    Tuple{Array{String, 1}},
                },
            }
            push!(COLD_TB_QUALIFICATION_RESULTS, (precompile(signature), false))
        end
        let signature = Tuple{typeof(Base.length), Array{UInt8, 1}}
            push!(COLD_TB_QUALIFICATION_RESULTS, (precompile(signature), false))
        end
        let signature = Tuple{
                typeof(Core.memoryref),
                GenericMemory{
                    :not_atomic,
                    WannierNLQG.IO.OperatorBundleIndexEntry,
                    Core.AddrSpace{Core}(0x00),
                },
            }
            push!(COLD_TB_QUALIFICATION_RESULTS, (precompile(signature), false))
        end
        let signature = Tuple{typeof(Base.getindex), Array{UInt8, 1}, Int64}
            push!(COLD_TB_QUALIFICATION_RESULTS, (precompile(signature), false))
        end
        let signature = Tuple{typeof(Base.getindex), Array{UInt64, 1}, Int64}
            push!(COLD_TB_QUALIFICATION_RESULTS, (precompile(signature), false))
        end
        let signature = Tuple{typeof(Base.:(==)), UInt64, UInt64}
            push!(COLD_TB_QUALIFICATION_RESULTS, (precompile(signature), false))
        end
        let signature =
                Tuple{typeof(Base.:(==)), Tuple{Int64, Int64, Int64}, Tuple{Int64, Int64, Int64}}
            push!(COLD_TB_QUALIFICATION_RESULTS, (precompile(signature), false))
        end
        let signature = Tuple{Type{UInt8}, UInt8}
            push!(COLD_TB_QUALIFICATION_RESULTS, (precompile(signature), false))
        end
        let signature = Tuple{typeof(Base.:(==)), Array{UInt64, 1}, Array{UInt64, 1}}
            push!(COLD_TB_QUALIFICATION_RESULTS, (precompile(signature), false))
        end
        let signature = Tuple{typeof(Base.in), String, NTuple{4, String}}
            push!(COLD_TB_QUALIFICATION_RESULTS, (precompile(signature), false))
        end
        let signature = Tuple{typeof(Base.keys), Base.Dict{String, Any}}
            push!(COLD_TB_QUALIFICATION_RESULTS, (precompile(signature), false))
        end
        let signature = Tuple{typeof(Base.collect), Base.KeySet{String, Base.Dict{String, Any}}}
            push!(COLD_TB_QUALIFICATION_RESULTS, (precompile(signature), false))
        end
        let signature = Tuple{Type{Base.Set{T} where T}, Array{String, 1}}
            push!(COLD_TB_QUALIFICATION_RESULTS, (precompile(signature), false))
        end
        let signature = Tuple{typeof(Base.:(==)), Base.Set{String}, Base.Set{String}}
            push!(COLD_TB_QUALIFICATION_RESULTS, (precompile(signature), false))
        end
        let signature = Tuple{typeof(Base.occursin), Base.Regex, String}
            push!(COLD_TB_QUALIFICATION_RESULTS, (precompile(signature), false))
        end
        let signature = Tuple{Type{Pair{A, B} where {B} where A}, String, Base.Dict{String, Any}}
            push!(COLD_TB_QUALIFICATION_RESULTS, (precompile(signature), false))
        end
        let signature = Tuple{typeof(Base.isempty), Base.Dict{String, Any}}
            push!(COLD_TB_QUALIFICATION_RESULTS, (precompile(signature), false))
        end
        let signature = Tuple{typeof(Base.indexed_iterate), Pair{String, Any}, Int64}
            push!(COLD_TB_QUALIFICATION_RESULTS, (precompile(signature), false))
        end
        let signature = Tuple{typeof(Base.indexed_iterate), Pair{String, Any}, Int64, Int64}
            push!(COLD_TB_QUALIFICATION_RESULTS, (precompile(signature), false))
        end
        let signature = Tuple{typeof(Base.iterate), Base.Dict{String, Any}, Int64}
            push!(COLD_TB_QUALIFICATION_RESULTS, (precompile(signature), false))
        end
        let signature = Tuple{Type{Pair{A, B} where {B} where A}, String, Bool}
            push!(COLD_TB_QUALIFICATION_RESULTS, (precompile(signature), false))
        end
        let signature = Tuple{typeof(JSON3.read), String}
            push!(COLD_TB_QUALIFICATION_RESULTS, (precompile(signature), false))
        end
        let signature = Tuple{
                typeof(Base.iterate),
                JSON3.Array{
                    JSON3.Object{
                        S,
                        TT,
                    } where {TT <: AbstractArray{UInt64, 1}} where S <: AbstractArray{UInt8, 1},
                    Base.CodeUnits{UInt8, String},
                    Array{UInt64, 1},
                },
            }
            push!(COLD_TB_QUALIFICATION_RESULTS, (precompile(signature), false))
        end
        let signature = Tuple{
                typeof(Base._all),
                WannierNLQGOperatorBundleExt.var"#12#14"{
                    JSON3.Object{
                        Base.CodeUnits{UInt8, String},
                        Base.SubArray{
                            UInt64,
                            1,
                            Array{UInt64, 1},
                            Tuple{Base.UnitRange{Int64}},
                            true,
                        },
                    },
                },
                NTuple{4, String},
                Base.Colon,
            }
            push!(COLD_TB_QUALIFICATION_RESULTS, (precompile(signature), false))
        end
        let signature = Tuple{
                typeof(Base._all),
                WannierNLQGOperatorBundleExt.var"#13#15"{
                    JSON3.Object{
                        Base.CodeUnits{UInt8, String},
                        Base.SubArray{
                            UInt64,
                            1,
                            Array{UInt64, 1},
                            Tuple{Base.UnitRange{Int64}},
                            true,
                        },
                    },
                },
                Tuple{String, String, String},
                Base.Colon,
            }
            push!(COLD_TB_QUALIFICATION_RESULTS, (precompile(signature), false))
        end
        let signature = Tuple{
                typeof(Base.getindex),
                JSON3.Object{
                    Base.CodeUnits{UInt8, String},
                    Base.SubArray{UInt64, 1, Array{UInt64, 1}, Tuple{Base.UnitRange{Int64}}, true},
                },
                String,
            }
            push!(COLD_TB_QUALIFICATION_RESULTS, (precompile(signature), false))
        end
        let signature = Tuple{
                typeof(Base.get),
                JSON3.Object{
                    Base.CodeUnits{UInt8, String},
                    Base.SubArray{UInt64, 1, Array{UInt64, 1}, Tuple{Base.UnitRange{Int64}}, true},
                },
                String,
                String,
            }
            push!(COLD_TB_QUALIFICATION_RESULTS, (precompile(signature), false))
        end
        let signature = Tuple{
                typeof(Base.iterate),
                JSON3.Array{
                    JSON3.Object{
                        S,
                        TT,
                    } where {TT <: AbstractArray{UInt64, 1}} where S <: AbstractArray{UInt8, 1},
                    Base.CodeUnits{UInt8, String},
                    Array{UInt64, 1},
                },
                Tuple{Int64, Int64},
            }
            push!(COLD_TB_QUALIFICATION_RESULTS, (precompile(signature), false))
        end
        let signature = Tuple{
                Type{WannierNLQG.IO.OperatorBundleManifest},
                String,
                Symbol,
                Array{WannierNLQG.Core.RealSpaceOperatorKind, 1},
                Int64,
                Array{Float64, 2},
                Array{Int64, 2},
                Array{Int64, 1},
                Array{WannierNLQG.IO.OperatorBundleIndexEntry, 1},
                Int64,
                String,
                String,
                String,
                Array{Float64, 2},
                Array{Float64, 2},
                Array{Float64, 2},
                Array{Float64, 2},
                Symbol,
                Symbol,
                Bool,
                Bool,
                Tuple{Int64, Int64, Int64},
                Float64,
                Int64,
                String,
                String,
                String,
                String,
                String,
                String,
                String,
                String,
                String,
                Bool,
                Bool,
                String,
                String,
                String,
                Int64,
                Int64,
                Int64,
                Int64,
                Float64,
                Float64,
                String,
                String,
                String,
                Nothing,
                String,
                String,
                String,
                Float64,
                Float64,
                Float64,
                Bool,
                Float64,
                Float64,
                Bool,
                Float64,
                Float64,
                Float64,
                Float64,
                Bool,
                Nothing,
                Nothing,
                Nothing,
                Nothing,
                Nothing,
                Bool,
                String,
                String,
                String,
                String,
                String,
                String,
                String,
                String,
                String,
                String,
                String,
                String,
                String,
                String,
                String,
                String,
                String,
                String,
                String,
                String,
                String,
                Bool,
                Bool,
                Bool,
                String,
                String,
                String,
                String,
                String,
                String,
                String,
                Nothing,
                String,
                String,
                Nothing,
                String,
                Base.Dict{String, Any},
                String,
                String,
                String,
                Bool,
                String,
                String,
                Bool,
                String,
                String,
                String,
                String,
                Nothing,
                Nothing,
                Nothing,
                Nothing,
                Nothing,
                Nothing,
                Nothing,
                String,
                Array{String, 1},
                String,
                String,
                String,
                String,
                String,
                Nothing,
                Nothing,
            }
            push!(COLD_TB_QUALIFICATION_RESULTS, (false, false))
        end
        let signature = Tuple{
                typeof(Base.push!),
                Array{Tuple{Int64, Int64, Int64}, 1},
                Tuple{Int64, Int64, Int64},
            }
            push!(COLD_TB_QUALIFICATION_RESULTS, (precompile(signature), false))
        end
        let signature = Tuple{typeof(Base.length), Array{Tuple{Int64, Int64, Int64}, 1}}
            push!(COLD_TB_QUALIFICATION_RESULTS, (precompile(signature), false))
        end
        let signature = Tuple{
                typeof(Base.getproperty),
                NamedTuple{
                    (:manifest, :lattice, :degeneracies, :operators, :read_mode, :fallback_reason),
                    Tuple{
                        WannierNLQG.IO.OperatorBundleManifest,
                        Array{Float64, 2},
                        Array{Int64, 1},
                        Base.Dict{
                            WannierNLQG.Core.RealSpaceOperatorKind,
                            WannierNLQG.Core.RealSpaceOperator{N} where N,
                        },
                        Symbol,
                        Nothing,
                    },
                },
                Symbol,
            }
            push!(COLD_TB_QUALIFICATION_RESULTS, (precompile(signature), false))
        end
        let signature = Tuple{typeof(Base.get), Base.Dict{String, Any}, String, String}
            push!(COLD_TB_QUALIFICATION_RESULTS, (precompile(signature), false))
        end
        let signature = Tuple{Type{Pair{A, B} where {B} where A}, Tuple{Int64, Int64, Int64}, Int64}
            push!(COLD_TB_QUALIFICATION_RESULTS, (precompile(signature), false))
        end
        let signature = Tuple{typeof(Base.setindex!), Array{String, 1}, String, Int64}
            push!(COLD_TB_QUALIFICATION_RESULTS, (precompile(signature), false))
        end
        let signature = Tuple{typeof(Base.unique), Array{String, 1}}
            push!(COLD_TB_QUALIFICATION_RESULTS, (precompile(signature), false))
        end
    end
end

# R15 continuation: actual nontrivial symmetry metrics and nonzero residual paths.
const NONTRIVIAL_TB_QUALIFICATION_RESULTS = Tuple{Bool, Bool}[]
@compile_workload let
    if WannierNLQG.FIRST_USE_WORKLOAD_ENABLED
        WannierNLQGOperatorBundleExt =
            Base.get_extension(WannierNLQG, :WannierNLQGOperatorBundleExt)
        @assert WannierNLQGOperatorBundleExt !== nothing
        let signature = Tuple{
                Type{
                    NamedTuple{
                        (:hamiltonian_covariance_threshold, :persist_hdf5),
                        T,
                    } where T <: Tuple,
                },
                Tuple{Float64, Bool},
            }
            push!(NONTRIVIAL_TB_QUALIFICATION_RESULTS, (false, false))
        end
        let signature = Tuple{typeof(Base.prod), Tuple{Int64}}
            push!(NONTRIVIAL_TB_QUALIFICATION_RESULTS, (precompile(signature), false))
        end
        let signature = Tuple{Type{Pair{A, B} where {B} where A}, String, Float64}
            push!(NONTRIVIAL_TB_QUALIFICATION_RESULTS, (precompile(signature), false))
        end
        let signature = Tuple{Type{UInt8}, Bool}
            push!(NONTRIVIAL_TB_QUALIFICATION_RESULTS, (precompile(signature), false))
        end
        let signature = Tuple{
                typeof(Core.kwcall),
                NamedTuple{(:task_selection,), Tuple{Nothing}},
                typeof(WannierNLQGOperatorBundleExt._scientific_content_digest),
                Symbol,
                Array{WannierNLQG.Core.RealSpaceOperatorKind, 1},
                Array{Float64, 2},
                Array{Int64, 2},
                Array{Int64, 1},
                Array{String, 1},
                Nothing,
                String,
                String,
                String,
                String,
                String,
                String,
                String,
                String,
                String,
                String,
                String,
                String,
                String,
                String,
                String,
                String,
                String,
                String,
                String,
                String,
                Bool,
                String,
                String,
                String,
                String,
                String,
                String,
                Nothing,
                String,
                String,
                String,
                String,
                String,
                String,
                String,
                Nothing,
            }
            push!(NONTRIVIAL_TB_QUALIFICATION_RESULTS, (false, false))
        end
        let signature = Tuple{
                Type{WannierNLQG.IO.OperatorBundleManifest},
                String,
                Symbol,
                Array{WannierNLQG.Core.RealSpaceOperatorKind, 1},
                Int64,
                Array{Float64, 2},
                Array{Int64, 2},
                Array{Int64, 1},
                Array{WannierNLQG.IO.OperatorBundleIndexEntry, 1},
                Int64,
                Nothing,
                String,
                String,
                Array{Float64, 2},
                Array{Float64, 2},
                Array{Float64, 2},
                Array{Float64, 2},
                Symbol,
                Symbol,
                Bool,
                Bool,
                Tuple{Int64, Int64, Int64},
                Float64,
                Int64,
                String,
                String,
                Nothing,
                Nothing,
                Nothing,
                Nothing,
                Nothing,
                Nothing,
                Nothing,
                Bool,
                Bool,
                Nothing,
                Nothing,
                Nothing,
                Nothing,
                Nothing,
                Nothing,
                Nothing,
                Nothing,
                Nothing,
                Nothing,
                Nothing,
                Nothing,
                Nothing,
                Nothing,
                Nothing,
                Nothing,
                Nothing,
                Nothing,
                Nothing,
                Bool,
                Nothing,
                Nothing,
                Bool,
                Nothing,
                Nothing,
                Nothing,
                Nothing,
                Bool,
                Nothing,
                Nothing,
                Nothing,
                Nothing,
                Nothing,
                Bool,
                String,
                String,
                Nothing,
                String,
                String,
                String,
                String,
                String,
                String,
                String,
                String,
                String,
                String,
                String,
                String,
                String,
                String,
                String,
                String,
                String,
                String,
                Bool,
                Bool,
                Bool,
                String,
                String,
                String,
                String,
                String,
                String,
                String,
                Nothing,
                String,
                String,
                Nothing,
                String,
                Base.Dict{String, Any},
                String,
                String,
                String,
                Bool,
                String,
                String,
                Bool,
                String,
                String,
                String,
                String,
                Nothing,
                Nothing,
                Nothing,
                Nothing,
                Nothing,
                Nothing,
                Nothing,
                String,
                Array{String, 1},
                String,
                String,
                String,
                String,
                String,
                Nothing,
                Nothing,
            }
            push!(NONTRIVIAL_TB_QUALIFICATION_RESULTS, (false, false))
        end

        let signature = Tuple{
                typeof(Core.kwcall),
                NamedTuple{(:init,), Tuple{Float64}},
                typeof(Base._maximum),
                Function,
                Array{Base.Complex{Float64}, 3},
                Base.Colon,
            }
            push!(NONTRIVIAL_TB_QUALIFICATION_RESULTS, (false, false))
        end
        let signature = Tuple{
                typeof(Base._mapreduce_dim),
                Function,
                Function,
                Float64,
                Array{Base.Complex{Float64}, 3},
                Base.Colon,
            }
            push!(NONTRIVIAL_TB_QUALIFICATION_RESULTS, (false, false))
        end
        let signature = Tuple{
                typeof(Base.mapfoldl_impl),
                typeof(Base.abs),
                typeof(Base.max),
                Float64,
                Array{Base.Complex{Float64}, 3},
            }
            push!(NONTRIVIAL_TB_QUALIFICATION_RESULTS, (false, false))
        end

        let signature = Tuple{
                typeof(Core.kwcall),
                NamedTuple{(:init,), Tuple{Float64}},
                typeof(Base._maximum),
                Function,
                Array{Base.Complex{Float64}, 4},
                Base.Colon,
            }
            push!(NONTRIVIAL_TB_QUALIFICATION_RESULTS, (false, false))
        end
        let signature = Tuple{
                typeof(Base._mapreduce_dim),
                Function,
                Function,
                Float64,
                Array{Base.Complex{Float64}, 4},
                Base.Colon,
            }
            push!(NONTRIVIAL_TB_QUALIFICATION_RESULTS, (false, false))
        end
        let signature = Tuple{
                typeof(Base.mapfoldl_impl),
                typeof(Base.abs),
                typeof(Base.max),
                Float64,
                Array{Base.Complex{Float64}, 4},
            }
            push!(NONTRIVIAL_TB_QUALIFICATION_RESULTS, (false, false))
        end
        let signature = Tuple{
                typeof(WannierNLQGWannierizationExt.OperatorExport._qualification_wcc_residual),
                Array{Float64, 2},
                Array{Float64, 2},
                WannierNLQG.SymmetryFoundation.WannierSymmetryPlan,
            }
            push!(NONTRIVIAL_TB_QUALIFICATION_RESULTS, (false, false))
        end
        let signature = Tuple{
                typeof(
                    WannierNLQGWannierizationExt.OperatorExport._qualification_projection_idempotence,
                ),
                WannierNLQG.Core.RealSpaceOperator{3},
                WannierNLQG.SymmetryFoundation.WannierSymmetryPlan,
            }
            push!(NONTRIVIAL_TB_QUALIFICATION_RESULTS, (false, false))
        end
        let signature = Tuple{
                typeof(Base._array_for),
                Type{Tuple{Int64, Int64, Int64}},
                Base.HasShape{1},
                Tuple{Base.OneTo{Int64}},
            }
            push!(NONTRIVIAL_TB_QUALIFICATION_RESULTS, (precompile(signature), false))
        end
        let signature = Tuple{typeof(Base.getindex), Array{Tuple{Int64, Int64, Int64}, 1}, Int64}
            push!(NONTRIVIAL_TB_QUALIFICATION_RESULTS, (precompile(signature), false))
        end
        let signature = Tuple{
                typeof(Base.push!),
                Base.Set{Tuple{Int64, Int64, Int64}},
                Tuple{Int64, Int64, Int64},
            }
            push!(NONTRIVIAL_TB_QUALIFICATION_RESULTS, (precompile(signature), false))
        end
        let signature =
                Tuple{typeof(Base.Iterators.enumerate), Array{Tuple{Int64, Int64, Int64}, 1}}
            push!(NONTRIVIAL_TB_QUALIFICATION_RESULTS, (precompile(signature), false))
        end
        let signature = Tuple{typeof(Base.iterate), Base.Set{Tuple{Int64, Int64, Int64}}}
            push!(NONTRIVIAL_TB_QUALIFICATION_RESULTS, (precompile(signature), false))
        end
        let signature = Tuple{
                typeof(Base.getindex),
                Base.Dict{Tuple{Int64, Int64, Int64}, Int64},
                Tuple{Int64, Int64, Int64},
            }
            push!(NONTRIVIAL_TB_QUALIFICATION_RESULTS, (precompile(signature), false))
        end

        let signature = Tuple{typeof(Base.iterate), Base.Set{Tuple{Int64, Int64, Int64}}, Int64}
            push!(NONTRIVIAL_TB_QUALIFICATION_RESULTS, (precompile(signature), false))
        end

        let signature = Tuple{Type{NamedTuple{(:init,), T} where T <: Tuple}, Tuple{Float64}}
            push!(NONTRIVIAL_TB_QUALIFICATION_RESULTS, (precompile(signature), false))
        end
        let signature = Tuple{typeof(HDF5.API.try_close_finalizer), HDF5.Datatype}
            push!(NONTRIVIAL_TB_QUALIFICATION_RESULTS, (precompile(signature), false))
        end
        let signature = Tuple{typeof(HDF5.API.try_close_finalizer), HDF5.AttributeAccessProperties}
            push!(NONTRIVIAL_TB_QUALIFICATION_RESULTS, (precompile(signature), false))
        end
        let signature = Tuple{typeof(HDF5.API.try_close_finalizer), HDF5.LinkAccessProperties}
            push!(NONTRIVIAL_TB_QUALIFICATION_RESULTS, (precompile(signature), false))
        end
        let signature = Tuple{typeof(HDF5.API.try_close_finalizer), HDF5.FileCreateProperties}
            push!(NONTRIVIAL_TB_QUALIFICATION_RESULTS, (precompile(signature), false))
        end
        let signature = Tuple{typeof(HDF5.API.try_close_finalizer), HDF5.StringCreateProperties}
            push!(NONTRIVIAL_TB_QUALIFICATION_RESULTS, (precompile(signature), false))
        end
        let signature = Tuple{typeof(HDF5.API.try_close_finalizer), HDF5.ObjectCreateProperties}
            push!(NONTRIVIAL_TB_QUALIFICATION_RESULTS, (precompile(signature), false))
        end
        let signature = Tuple{typeof(HDF5.API.try_close_finalizer), HDF5.ObjectCopyProperties}
            push!(NONTRIVIAL_TB_QUALIFICATION_RESULTS, (precompile(signature), false))
        end
        let signature = Tuple{typeof(HDF5.API.try_close_finalizer), HDF5.LinkCreateProperties}
            push!(NONTRIVIAL_TB_QUALIFICATION_RESULTS, (precompile(signature), false))
        end
        let signature = Tuple{typeof(HDF5.API.try_close_finalizer), HDF5.GroupCreateProperties}
            push!(NONTRIVIAL_TB_QUALIFICATION_RESULTS, (precompile(signature), false))
        end
        let signature = Tuple{typeof(HDF5.API.try_close_finalizer), HDF5.GroupAccessProperties}
            push!(NONTRIVIAL_TB_QUALIFICATION_RESULTS, (precompile(signature), false))
        end
        let signature = Tuple{typeof(HDF5.API.try_close_finalizer), HDF5.FileMountProperties}
            push!(NONTRIVIAL_TB_QUALIFICATION_RESULTS, (precompile(signature), false))
        end
        let signature = Tuple{typeof(HDF5.API.try_close_finalizer), HDF5.DatatypeCreateProperties}
            push!(NONTRIVIAL_TB_QUALIFICATION_RESULTS, (precompile(signature), false))
        end
        let signature = Tuple{typeof(HDF5.API.try_close_finalizer), HDF5.DatatypeAccessProperties}
            push!(NONTRIVIAL_TB_QUALIFICATION_RESULTS, (precompile(signature), false))
        end
        let signature = Tuple{typeof(HDF5.API.try_close_finalizer), HDF5.DatasetTransferProperties}
            push!(NONTRIVIAL_TB_QUALIFICATION_RESULTS, (precompile(signature), false))
        end
        let signature = Tuple{typeof(HDF5.API.try_close_finalizer), HDF5.DatasetAccessProperties}
            push!(NONTRIVIAL_TB_QUALIFICATION_RESULTS, (precompile(signature), false))
        end
        let signature = Tuple{typeof(HDF5.API.try_close_finalizer), HDF5.AttributeCreateProperties}
            push!(NONTRIVIAL_TB_QUALIFICATION_RESULTS, (precompile(signature), false))
        end
        let signature = Tuple{
                typeof(
                    WannierNLQGWannierizationExt.OperatorExport._qualification_operator_difference,
                ),
                WannierNLQG.Core.RealSpaceOperator{3},
                WannierNLQG.Core.RealSpaceOperator{3},
            }
            push!(NONTRIVIAL_TB_QUALIFICATION_RESULTS, (false, false))
        end
        let signature = Tuple{
                typeof(Base.grow_to!),
                Base.Dict{Tuple{Int64, Int64, Int64}, Int64},
                Base.Generator{
                    Base.OneTo{Int64},
                    WannierNLQGWannierizationExt.OperatorExport.var"#319#321"{
                        WannierNLQG.Core.RealSpaceOperator{3},
                    },
                },
                Int64,
            }
            push!(NONTRIVIAL_TB_QUALIFICATION_RESULTS, (false, false))
        end
        let signature = Tuple{
                typeof(Base.grow_to!),
                Base.Dict{Tuple{Int64, Int64, Int64}, Int64},
                Base.Generator{
                    Base.OneTo{Int64},
                    WannierNLQGWannierizationExt.OperatorExport.var"#320#322"{
                        WannierNLQG.Core.RealSpaceOperator{3},
                    },
                },
                Int64,
            }
            push!(NONTRIVIAL_TB_QUALIFICATION_RESULTS, (false, false))
        end
        let signature = Tuple{
                typeof(Base.union),
                Base.KeySet{
                    Tuple{Int64, Int64, Int64},
                    Base.Dict{Tuple{Int64, Int64, Int64}, Int64},
                },
                Base.KeySet{
                    Tuple{Int64, Int64, Int64},
                    Base.Dict{Tuple{Int64, Int64, Int64}, Int64},
                },
            }
            push!(NONTRIVIAL_TB_QUALIFICATION_RESULTS, (false, false))
        end
        let signature = Tuple{
                typeof(Base.Broadcast.broadcasted),
                typeof(Base.:(-)),
                Base.SubArray{
                    Base.Complex{Float64},
                    2,
                    Array{Base.Complex{Float64}, 3},
                    Tuple{Base.Slice{Base.OneTo{Int64}}, Base.Slice{Base.OneTo{Int64}}, Int64},
                    true,
                },
                Base.SubArray{
                    Base.Complex{Float64},
                    2,
                    Array{Base.Complex{Float64}, 3},
                    Tuple{Base.Slice{Base.OneTo{Int64}}, Base.Slice{Base.OneTo{Int64}}, Int64},
                    true,
                },
            }
            push!(NONTRIVIAL_TB_QUALIFICATION_RESULTS, (false, false))
        end
        let signature = Tuple{
                typeof(Base.Broadcast.materialize),
                Base.Broadcast.Broadcasted{
                    Base.Broadcast.DefaultArrayStyle{2},
                    Nothing,
                    typeof(Base.:(-)),
                    Tuple{
                        Base.SubArray{
                            Base.Complex{Float64},
                            2,
                            Array{Base.Complex{Float64}, 3},
                            Tuple{
                                Base.Slice{Base.OneTo{Int64}},
                                Base.Slice{Base.OneTo{Int64}},
                                Int64,
                            },
                            true,
                        },
                        Base.SubArray{
                            Base.Complex{Float64},
                            2,
                            Array{Base.Complex{Float64}, 3},
                            Tuple{
                                Base.Slice{Base.OneTo{Int64}},
                                Base.Slice{Base.OneTo{Int64}},
                                Int64,
                            },
                            true,
                        },
                    },
                },
            }
            push!(NONTRIVIAL_TB_QUALIFICATION_RESULTS, (false, false))
        end
        let signature = Tuple{
                typeof(
                    WannierNLQGWannierizationExt.OperatorExport._qualification_projection_idempotence,
                ),
                WannierNLQG.Core.RealSpaceOperator{4},
                WannierNLQG.SymmetryFoundation.WannierSymmetryPlan,
            }
            push!(NONTRIVIAL_TB_QUALIFICATION_RESULTS, (false, false))
        end

        let signature = Tuple{
                typeof(
                    WannierNLQGWannierizationExt.OperatorExport._qualification_operator_difference,
                ),
                WannierNLQG.Core.RealSpaceOperator{4},
                WannierNLQG.Core.RealSpaceOperator{4},
            }
            push!(NONTRIVIAL_TB_QUALIFICATION_RESULTS, (false, false))
        end
        let signature = Tuple{
                typeof(Base.grow_to!),
                Base.Dict{Tuple{Int64, Int64, Int64}, Int64},
                Base.Generator{
                    Base.OneTo{Int64},
                    WannierNLQGWannierizationExt.OperatorExport.var"#319#321"{
                        WannierNLQG.Core.RealSpaceOperator{4},
                    },
                },
                Int64,
            }
            push!(NONTRIVIAL_TB_QUALIFICATION_RESULTS, (false, false))
        end
        let signature = Tuple{
                typeof(Base.grow_to!),
                Base.Dict{Tuple{Int64, Int64, Int64}, Int64},
                Base.Generator{
                    Base.OneTo{Int64},
                    WannierNLQGWannierizationExt.OperatorExport.var"#320#322"{
                        WannierNLQG.Core.RealSpaceOperator{4},
                    },
                },
                Int64,
            }
            push!(NONTRIVIAL_TB_QUALIFICATION_RESULTS, (false, false))
        end
        let signature = Tuple{
                typeof(Base.Broadcast.broadcasted),
                typeof(Base.:(-)),
                Base.SubArray{
                    Base.Complex{Float64},
                    3,
                    Array{Base.Complex{Float64}, 4},
                    Tuple{
                        Base.Slice{Base.OneTo{Int64}},
                        Base.Slice{Base.OneTo{Int64}},
                        Base.Slice{Base.OneTo{Int64}},
                        Int64,
                    },
                    true,
                },
                Base.SubArray{
                    Base.Complex{Float64},
                    3,
                    Array{Base.Complex{Float64}, 4},
                    Tuple{
                        Base.Slice{Base.OneTo{Int64}},
                        Base.Slice{Base.OneTo{Int64}},
                        Base.Slice{Base.OneTo{Int64}},
                        Int64,
                    },
                    true,
                },
            }
            push!(NONTRIVIAL_TB_QUALIFICATION_RESULTS, (false, false))
        end
        let signature = Tuple{
                typeof(Base.Broadcast.materialize),
                Base.Broadcast.Broadcasted{
                    Base.Broadcast.DefaultArrayStyle{3},
                    Nothing,
                    typeof(Base.:(-)),
                    Tuple{
                        Base.SubArray{
                            Base.Complex{Float64},
                            3,
                            Array{Base.Complex{Float64}, 4},
                            Tuple{
                                Base.Slice{Base.OneTo{Int64}},
                                Base.Slice{Base.OneTo{Int64}},
                                Base.Slice{Base.OneTo{Int64}},
                                Int64,
                            },
                            true,
                        },
                        Base.SubArray{
                            Base.Complex{Float64},
                            3,
                            Array{Base.Complex{Float64}, 4},
                            Tuple{
                                Base.Slice{Base.OneTo{Int64}},
                                Base.Slice{Base.OneTo{Int64}},
                                Base.Slice{Base.OneTo{Int64}},
                                Int64,
                            },
                            true,
                        },
                    },
                },
            }
            push!(NONTRIVIAL_TB_QUALIFICATION_RESULTS, (false, false))
        end
        let signature = Tuple{
                typeof(Core.kwcall),
                NamedTuple{(:init,), Tuple{Float64}},
                typeof(Base.maximum),
                Function,
                Array{Base.Complex{Float64}, 3},
            }
            push!(NONTRIVIAL_TB_QUALIFICATION_RESULTS, (false, false))
        end
        let signature = Tuple{
                typeof(Core.kwcall),
                NamedTuple{(:task_selection,), Tuple{Nothing}},
                typeof(WannierNLQGOperatorBundleExt._scientific_content_digest),
                Symbol,
                Array{WannierNLQG.Core.RealSpaceOperatorKind, 1},
                Array{Float64, 2},
                Array{Int64, 2},
                Array{Int64, 1},
                Array{String, 1},
                Nothing,
                String,
                String,
                String,
                String,
                String,
                String,
                String,
                String,
                String,
                String,
                String,
                String,
                String,
                String,
                String,
                String,
                String,
                String,
                String,
                String,
                Bool,
                String,
                String,
                String,
                String,
                String,
                String,
                Float64,
                String,
                String,
                String,
                String,
                String,
                String,
                String,
                Nothing,
            }
            push!(NONTRIVIAL_TB_QUALIFICATION_RESULTS, (false, false))
        end
        let signature = Tuple{typeof(Base.isfinite), Float64}
            push!(NONTRIVIAL_TB_QUALIFICATION_RESULTS, (precompile(signature), false))
        end
        let signature = Tuple{
                Type{WannierNLQG.IO.OperatorBundleManifest},
                String,
                Symbol,
                Array{WannierNLQG.Core.RealSpaceOperatorKind, 1},
                Int64,
                Array{Float64, 2},
                Array{Int64, 2},
                Array{Int64, 1},
                Array{WannierNLQG.IO.OperatorBundleIndexEntry, 1},
                Int64,
                Nothing,
                String,
                String,
                Array{Float64, 2},
                Array{Float64, 2},
                Array{Float64, 2},
                Array{Float64, 2},
                Symbol,
                Symbol,
                Bool,
                Bool,
                Tuple{Int64, Int64, Int64},
                Float64,
                Int64,
                String,
                String,
                Nothing,
                Nothing,
                Nothing,
                Nothing,
                Nothing,
                Nothing,
                Nothing,
                Bool,
                Bool,
                Nothing,
                Nothing,
                Nothing,
                Nothing,
                Nothing,
                Nothing,
                Nothing,
                Nothing,
                Nothing,
                Nothing,
                Nothing,
                Nothing,
                Nothing,
                Nothing,
                Nothing,
                Nothing,
                Nothing,
                Nothing,
                Nothing,
                Bool,
                Nothing,
                Nothing,
                Bool,
                Nothing,
                Nothing,
                Nothing,
                Nothing,
                Bool,
                Nothing,
                Nothing,
                Nothing,
                Nothing,
                Nothing,
                Bool,
                String,
                String,
                Nothing,
                String,
                String,
                String,
                String,
                String,
                String,
                String,
                String,
                String,
                String,
                String,
                String,
                String,
                String,
                String,
                String,
                String,
                String,
                Bool,
                Bool,
                Bool,
                String,
                String,
                String,
                String,
                String,
                String,
                String,
                Float64,
                String,
                String,
                Nothing,
                String,
                Base.Dict{String, Any},
                String,
                String,
                String,
                Bool,
                String,
                String,
                Bool,
                String,
                String,
                String,
                String,
                Nothing,
                Nothing,
                Nothing,
                Nothing,
                Nothing,
                Nothing,
                Nothing,
                String,
                Array{String, 1},
                String,
                String,
                String,
                String,
                String,
                Nothing,
                Nothing,
            }
            push!(NONTRIVIAL_TB_QUALIFICATION_RESULTS, (false, false))
        end
        let signature = Tuple{
                typeof(Core.kwcall),
                NamedTuple{
                    (
                        :authoritative_hamiltonian,
                        :authoritative_hamiltonian_sha256,
                        :energy_shift_qualification,
                        :maximum_energy_shift_audit_reference_ev,
                        :rms_energy_shift_audit_reference_ev,
                        :target_energy_shift_audit_status,
                        :symmetrized_parent_energy_shift_audit_status,
                        :residual_gate_phase,
                        :raw_preflight_diagnostic_status,
                        :native_difference_qualification,
                        :native_difference_audit_status,
                        :qualification_scope,
                        :target_anchor,
                        :target_complement_completion,
                        :target_complement_max_element_ev,
                        :auxiliary_parent_qualification,
                        :symmetrized_target_subspace_status,
                        :auxiliary_parent_audit_status,
                        :target_scope_production_eligible,
                        :target_leakage_semantics,
                        :target_leakage_formula_sha256,
                        :target_leakage_threshold,
                        :scoped_production_eligible,
                        :global_production_eligible,
                    ),
                    Tuple{
                        String,
                        String,
                        String,
                        String,
                        String,
                        String,
                        String,
                        String,
                        String,
                        String,
                        String,
                        String,
                        String,
                        String,
                        String,
                        String,
                        String,
                        String,
                        Bool,
                        String,
                        String,
                        Float64,
                        Bool,
                        Bool,
                    },
                },
                Type{WannierNLQG.Wannierization.TBSymmetryQualification},
                String,
                String,
                Array{WannierNLQG.Wannierization.TBSymmetryMetric, 1},
            }
            push!(NONTRIVIAL_TB_QUALIFICATION_RESULTS, (precompile(signature), false))
        end
    end
end

# R16: actual four-band audit signatures; compile only, without audit execution.
import EzXML
const PAW_AUDIT_COVERAGE_RESULTS = Tuple{Bool, Bool}[]
@compile_workload let
    if WannierNLQG.FIRST_USE_WORKLOAD_ENABLED
        StructTypes = JSON3.StructTypes
        let signature = Tuple{
                typeof(WannierNLQG.Wannierization.audit_paw_block_partitions),
                WannierNLQG.Wannierization.PAWBlockPartitionAuditConfig,
            }
            push!(PAW_AUDIT_COVERAGE_RESULTS, (precompile(signature), false))
        end
        let signature = Tuple{typeof(Base.vect), Array{String, 1}, Vararg{Array{String, 1}}}
            push!(PAW_AUDIT_COVERAGE_RESULTS, (precompile(signature), false))
        end
        let signature = Tuple{typeof(Base.iterate), Array{Array{String, 1}, 1}}
            push!(PAW_AUDIT_COVERAGE_RESULTS, (precompile(signature), false))
        end
        let signature = Tuple{
                typeof(Base.issorted),
                Array{String, 1},
                Base.Order.ReverseOrdering{Base.Order.ForwardOrdering},
            }
            push!(PAW_AUDIT_COVERAGE_RESULTS, (precompile(signature), false))
        end
        let signature = Tuple{typeof(Base.setindex!), Base.EnvDict, String, String}
            push!(PAW_AUDIT_COVERAGE_RESULTS, (precompile(signature), false))
        end
        let signature = Tuple{typeof(Base.haskey), Base.Dict{Base.PkgId, Module}, Base.PkgId}
            push!(PAW_AUDIT_COVERAGE_RESULTS, (precompile(signature), false))
        end
        let signature = Tuple{
                typeof(Base.getindex),
                Type{Union{Nothing, Array{String, 1}}},
                Nothing,
                Array{String, 1},
            }
            push!(PAW_AUDIT_COVERAGE_RESULTS, (false, false))
        end
        let signature = Tuple{typeof(Base.iterate), Array{Union{Nothing, Array{String, 1}}, 1}}
            push!(PAW_AUDIT_COVERAGE_RESULTS, (false, false))
        end
        let signature =
                Tuple{typeof(Base.iterate), Array{Union{Nothing, Array{String, 1}}, 1}, Int64}
            push!(PAW_AUDIT_COVERAGE_RESULTS, (false, false))
        end
        let signature = Tuple{typeof(Base.:(==)), Char, Char}
            push!(PAW_AUDIT_COVERAGE_RESULTS, (precompile(signature), false))
        end
        let signature = Tuple{typeof(Base.iszero), Bool}
            push!(PAW_AUDIT_COVERAGE_RESULTS, (precompile(signature), false))
        end
        let signature =
                Tuple{Type{NamedTuple{(:normalize_coefficients,), T} where T <: Tuple}, Tuple{Bool}}
            push!(PAW_AUDIT_COVERAGE_RESULTS, (precompile(signature), false))
        end
        let signature = Tuple{typeof(Base.in), Int64, Base.UnitRange{Int64}}
            push!(PAW_AUDIT_COVERAGE_RESULTS, (precompile(signature), false))
        end
        let signature = Tuple{typeof(Base.indexed_iterate), Pair{String, String}, Int64}
            push!(PAW_AUDIT_COVERAGE_RESULTS, (precompile(signature), false))
        end
        let signature = Tuple{typeof(Base.indexed_iterate), Pair{String, String}, Int64, Int64}
            push!(PAW_AUDIT_COVERAGE_RESULTS, (precompile(signature), false))
        end
        let signature = Tuple{
                typeof(Base.getproperty),
                Base.MappingRF{
                    WannierNLQGWannierizationExt.PAWMatrixElements.var"#809#837",
                    Base.BottomRF{typeof(Base.vcat)},
                },
                Symbol,
            }
            push!(PAW_AUDIT_COVERAGE_RESULTS, (precompile(signature), false))
        end
        let signature = Tuple{Type{NamedTuple{(:tolerance,), T} where T <: Tuple}, Tuple{Float64}}
            push!(PAW_AUDIT_COVERAGE_RESULTS, (precompile(signature), false))
        end
        let signature = Tuple{typeof(Base.convert), Type{Bool}, Bool}
            push!(PAW_AUDIT_COVERAGE_RESULTS, (precompile(signature), false))
        end
        let signature = Tuple{
                typeof(Core.memoryref),
                GenericMemory{
                    :not_atomic,
                    WannierNLQGWannierizationExt.PAWMatrixElements._PAWBlockEvidenceRecord,
                    Core.AddrSpace{Core}(0x00),
                },
            }
            push!(PAW_AUDIT_COVERAGE_RESULTS, (precompile(signature), false))
        end
        let signature = Tuple{
                WannierNLQG.Wannierization.var"#_#7#8",
                Float64,
                Float64,
                Int64,
                Type{WannierNLQG.Wannierization.ClosureDrivenBandBuffer},
            }
            push!(PAW_AUDIT_COVERAGE_RESULTS, (precompile(signature), false))
        end
        let signature = Tuple{
                typeof(Core.memoryref),
                GenericMemory{
                    :not_atomic,
                    NamedTuple{
                        (
                            :raw,
                            :pseudo,
                            :augmentation,
                            :transformed,
                            :transformed_projectors,
                            :reconstruction,
                        ),
                        Tuple{
                            Array{Base.Complex{Float64}, 2},
                            Array{Base.Complex{Float64}, 2},
                            Array{Base.Complex{Float64}, 2},
                            Array{Base.Complex{Float64}, 3},
                            Array{Base.Complex{Float64}, 3},
                            NamedTuple{
                                (
                                    :reconstruction_leakage_weight,
                                    :state_leakage_weight,
                                    :reconstruction_leakage_amplitude_audit,
                                    :state_leakage_amplitude_audit,
                                    :minimum_residual_gram_eigenvalue,
                                ),
                                NTuple{5, Float64},
                            },
                        },
                    },
                    Core.AddrSpace{Core}(0x00),
                },
            }
            push!(PAW_AUDIT_COVERAGE_RESULTS, (precompile(signature), false))
        end
        let signature = Tuple{
                typeof(Base.getproperty),
                Base.MappingRF{typeof(Base.abs2), Base.BottomRF{typeof(Base.add_sum)}},
                Symbol,
            }
            push!(PAW_AUDIT_COVERAGE_RESULTS, (precompile(signature), false))
        end
        let signature = Tuple{
                typeof(Base.getproperty),
                WannierNLQG.Wannierization.ClosureDrivenBandBuffer,
                Symbol,
            }
            push!(PAW_AUDIT_COVERAGE_RESULTS, (precompile(signature), false))
        end
        let signature = Tuple{typeof(Base.:(&)), Bool, Base.Missing}
            push!(PAW_AUDIT_COVERAGE_RESULTS, (precompile(signature), false))
        end
        let signature = Tuple{typeof(Base.isempty), Base.UnitRange{Int64}}
            push!(PAW_AUDIT_COVERAGE_RESULTS, (precompile(signature), false))
        end
        let signature = Tuple{Type{NamedTuple{(:init,), T} where T <: Tuple}, Tuple{Float64}}
            push!(PAW_AUDIT_COVERAGE_RESULTS, (precompile(signature), false))
        end
        let signature = Tuple{
                typeof(Core.memoryref),
                GenericMemory{
                    :not_atomic,
                    NamedTuple{names, T} where {T <: Tuple} where names,
                    Core.AddrSpace{Core}(0x00),
                },
            }
            push!(PAW_AUDIT_COVERAGE_RESULTS, (precompile(signature), false))
        end
        let signature = Tuple{
                typeof(Base.getproperty),
                Base.Order.By{
                    WannierNLQGWannierizationExt.PAWMatrixElements.var"#812#840",
                    Base.Order.ForwardOrdering,
                },
                Symbol,
            }
            push!(PAW_AUDIT_COVERAGE_RESULTS, (precompile(signature), false))
        end
        let signature = Tuple{
                typeof(Base.getproperty),
                Base.Order.Lt{
                    Base.Sort.var"#30#31"{
                        Base.Order.By{
                            WannierNLQGWannierizationExt.PAWMatrixElements.var"#812#840",
                            Base.Order.ForwardOrdering,
                        },
                    },
                },
                Symbol,
            }
            push!(PAW_AUDIT_COVERAGE_RESULTS, (precompile(signature), false))
        end
        let signature = Tuple{Base.var"##s128#278", Vararg{Any, 5}}
            push!(PAW_AUDIT_COVERAGE_RESULTS, (precompile(signature), false))
        end
        let signature = Tuple{typeof(Base.isconcretetype), Any}
            push!(PAW_AUDIT_COVERAGE_RESULTS, (precompile(signature), false))
        end
        let signature = Tuple{typeof(Base.real), Base.Complex{Float64}}
            push!(PAW_AUDIT_COVERAGE_RESULTS, (precompile(signature), false))
        end
        let signature = Tuple{typeof(Base.imag), Base.Complex{Float64}}
            push!(PAW_AUDIT_COVERAGE_RESULTS, (precompile(signature), false))
        end
        let signature = Tuple{typeof(Base.float), Float64}
            push!(PAW_AUDIT_COVERAGE_RESULTS, (precompile(signature), false))
        end
        let signature = Tuple{typeof(Base.abs), Float64}
            push!(PAW_AUDIT_COVERAGE_RESULTS, (precompile(signature), false))
        end
        let signature = Tuple{typeof(Base.isinf), Float64}
            push!(PAW_AUDIT_COVERAGE_RESULTS, (precompile(signature), false))
        end
        let signature = Tuple{typeof(Base.:(>)), Float64, Float64}
            push!(PAW_AUDIT_COVERAGE_RESULTS, (precompile(signature), false))
        end
        let signature = Tuple{typeof(Base.:(/)), Float64, Int64}
            push!(PAW_AUDIT_COVERAGE_RESULTS, (precompile(signature), false))
        end
        let signature = Tuple{typeof(Base.:(*)), Float64, Float64}
            push!(PAW_AUDIT_COVERAGE_RESULTS, (precompile(signature), false))
        end
        let signature = Tuple{typeof(Base.:(<=)), Float64, Float64}
            push!(PAW_AUDIT_COVERAGE_RESULTS, (precompile(signature), false))
        end
        let signature = Tuple{
                typeof(Base.getproperty),
                Base.Order.By{
                    WannierNLQGWannierizationExt.PAWMatrixElements.var"#814#842",
                    Base.Order.ForwardOrdering,
                },
                Symbol,
            }
            push!(PAW_AUDIT_COVERAGE_RESULTS, (precompile(signature), false))
        end
        let signature = Tuple{
                typeof(Base.getproperty),
                Base.Order.Lt{
                    Base.Sort.var"#30#31"{
                        Base.Order.By{
                            WannierNLQGWannierizationExt.PAWMatrixElements.var"#814#842",
                            Base.Order.ForwardOrdering,
                        },
                    },
                },
                Symbol,
            }
            push!(PAW_AUDIT_COVERAGE_RESULTS, (precompile(signature), false))
        end
        let signature = Tuple{
                typeof(Base.getproperty),
                Base.MappingRF{
                    Base.var"#361#362"{
                        WannierNLQGWannierizationExt.PAWMatrixElements.var"#816#844",
                    },
                    Base.BottomRF{typeof(Base.add_sum)},
                },
                Symbol,
            }
            push!(PAW_AUDIT_COVERAGE_RESULTS, (precompile(signature), false))
        end
        let signature = Tuple{
                typeof(Base.getproperty),
                Base.MappingRF{
                    Base.var"#361#362"{
                        WannierNLQGWannierizationExt.PAWMatrixElements.var"#817#845",
                    },
                    Base.BottomRF{typeof(Base.add_sum)},
                },
                Symbol,
            }
            push!(PAW_AUDIT_COVERAGE_RESULTS, (precompile(signature), false))
        end
        let signature = Tuple{
                typeof(Base.getproperty),
                Base.MappingRF{
                    WannierNLQGWannierizationExt.PAWMatrixElements.var"#818#846",
                    Base.BottomRF{typeof(Base.max)},
                },
                Symbol,
            }
            push!(PAW_AUDIT_COVERAGE_RESULTS, (precompile(signature), false))
        end
        let signature = Tuple{
                typeof(Base.getproperty),
                Base.MappingRF{
                    WannierNLQGWannierizationExt.PAWMatrixElements.var"#822#850",
                    Base.BottomRF{typeof(Base.max)},
                },
                Symbol,
            }
            push!(PAW_AUDIT_COVERAGE_RESULTS, (precompile(signature), false))
        end
        let signature = Tuple{typeof(Base.:(&)), Int64, Int64}
            push!(PAW_AUDIT_COVERAGE_RESULTS, (precompile(signature), false))
        end
        let signature = Tuple{
                typeof(Base.getproperty),
                Base.MappingRF{
                    WannierNLQGWannierizationExt.PAWMatrixElements.var"#825#853",
                    Base.BottomRF{typeof(Base.add_sum)},
                },
                Symbol,
            }
            push!(PAW_AUDIT_COVERAGE_RESULTS, (precompile(signature), false))
        end
        let signature = Tuple{typeof(Base.pairs), NamedTuple{(:rev,), Tuple{Bool}}}
            push!(PAW_AUDIT_COVERAGE_RESULTS, (precompile(signature), false))
        end
        let signature = Tuple{
                typeof(Base.getproperty),
                Base.MappingRF{
                    WannierNLQGWannierizationExt.PAWMatrixElements.var"#830#858",
                    Base.BottomRF{typeof(Base.max)},
                },
                Symbol,
            }
            push!(PAW_AUDIT_COVERAGE_RESULTS, (precompile(signature), false))
        end
        let signature = Tuple{
                typeof(Base.getproperty),
                Base.MappingRF{
                    WannierNLQGWannierizationExt.PAWMatrixElements.var"#831#859",
                    Base.BottomRF{typeof(Base.max)},
                },
                Symbol,
            }
            push!(PAW_AUDIT_COVERAGE_RESULTS, (precompile(signature), false))
        end
        let signature = Tuple{Type{Pair{A, B} where {B} where A}, String, Bool}
            push!(PAW_AUDIT_COVERAGE_RESULTS, (precompile(signature), false))
        end
        let signature = Tuple{Type{NamedTuple{(:cleanup,), T} where T <: Tuple}, Tuple{Bool}}
            push!(PAW_AUDIT_COVERAGE_RESULTS, (precompile(signature), false))
        end
        let signature = Tuple{typeof(Base.tail), NTuple{16, Symbol}}
            push!(PAW_AUDIT_COVERAGE_RESULTS, (precompile(signature), false))
        end
        let signature = Tuple{typeof(Base.tail), NTuple{15, Symbol}}
            push!(PAW_AUDIT_COVERAGE_RESULTS, (precompile(signature), false))
        end
        let signature = Tuple{typeof(Base.tail), NTuple{14, Symbol}}
            push!(PAW_AUDIT_COVERAGE_RESULTS, (precompile(signature), false))
        end
        let signature = Tuple{typeof(Base.tail), NTuple{13, Symbol}}
            push!(PAW_AUDIT_COVERAGE_RESULTS, (precompile(signature), false))
        end
        let signature = Tuple{typeof(Base.tail), NTuple{12, Symbol}}
            push!(PAW_AUDIT_COVERAGE_RESULTS, (precompile(signature), false))
        end
        let signature = Tuple{typeof(Base.tail), NTuple{11, Symbol}}
            push!(PAW_AUDIT_COVERAGE_RESULTS, (precompile(signature), false))
        end
        let signature = Tuple{typeof(Base.tail), NTuple{10, Symbol}}
            push!(PAW_AUDIT_COVERAGE_RESULTS, (precompile(signature), false))
        end
        let signature = Tuple{typeof(Base.tail), NTuple{9, Symbol}}
            push!(PAW_AUDIT_COVERAGE_RESULTS, (precompile(signature), false))
        end
        let signature = Tuple{typeof(Base.tail), NTuple{8, Symbol}}
            push!(PAW_AUDIT_COVERAGE_RESULTS, (precompile(signature), false))
        end
        let signature = Tuple{typeof(Base.tail), NTuple{7, Symbol}}
            push!(PAW_AUDIT_COVERAGE_RESULTS, (precompile(signature), false))
        end
        let signature = Tuple{typeof(Base.tail), NTuple{6, Symbol}}
            push!(PAW_AUDIT_COVERAGE_RESULTS, (precompile(signature), false))
        end
        let signature = Tuple{typeof(Base.tail), NTuple{5, Symbol}}
            push!(PAW_AUDIT_COVERAGE_RESULTS, (precompile(signature), false))
        end
        let signature = Tuple{typeof(Base.tail), NTuple{4, Symbol}}
            push!(PAW_AUDIT_COVERAGE_RESULTS, (precompile(signature), false))
        end
        let signature = Tuple{Type{MethodError}, Any, Any}
            push!(PAW_AUDIT_COVERAGE_RESULTS, (precompile(signature), false))
        end
        let signature = Tuple{
                typeof(WannierNLQGWannierizationExt.PAWMatrixElements.audit_paw_block_partitions),
                WannierNLQG.Wannierization.PAWBlockPartitionAuditConfig,
            }
            push!(PAW_AUDIT_COVERAGE_RESULTS, (precompile(signature), false))
        end
        let signature = Tuple{
                typeof(Core.kwcall),
                NamedTuple{
                    (
                        :band_range,
                        :spin_channel,
                        :representation_cutoff_ev,
                        :include_time_reversal,
                        :magnetic_moments_cartesian,
                    ),
                    Tuple{Nothing, Symbol, Nothing, Bool, Nothing},
                },
                Type{WannierNLQG.SymmetryFoundation.QuantumEspressoWavefunctionSource},
                String,
            }
            push!(PAW_AUDIT_COVERAGE_RESULTS, (precompile(signature), false))
        end
        let signature = Tuple{
                WannierNLQGWannierizationExt.RepresentationPreparation.var"##_read_qe_wavefunctions#98",
                Symbol,
                Bool,
                Bool,
                NamedTuple{
                    (
                        :xml_file,
                        :structure,
                        :reciprocal_lattice,
                        :noncollinear,
                        :spinorbit,
                        :collinear,
                        :num_bands,
                        :cutoff_ev,
                        :kpoint_nodes,
                        :atomic_type_labels,
                        :type_elements,
                        :upf_files,
                        :metric_kinds,
                    ),
                    Tuple{
                        String,
                        WannierNLQG.SymmetryFoundation.CrystalStructure,
                        Array{Float64, 2},
                        Bool,
                        Bool,
                        Bool,
                        Int64,
                        Float64,
                        Array{EzXML.Node, 1},
                        Array{String, 1},
                        Base.Dict{String, String},
                        Base.Dict{String, String},
                        Base.Dict{String, Symbol},
                    },
                },
                Bool,
                Array{WannierNLQG.SymmetryFoundation.PlaneWaveKPoint, 1},
                typeof(
                    WannierNLQGWannierizationExt.RepresentationPreparation._read_qe_wavefunctions,
                ),
                WannierNLQG.SymmetryFoundation.QuantumEspressoWavefunctionSource,
            }
            push!(PAW_AUDIT_COVERAGE_RESULTS, (false, false))
        end
        let signature = Tuple{Type{Array{Int64, N} where N}, UndefInitializer, Int64}
            push!(PAW_AUDIT_COVERAGE_RESULTS, (precompile(signature), false))
        end
        let signature = Tuple{Type{Array{Int64, N} where N}, UndefInitializer, Int64, Int64}
            push!(PAW_AUDIT_COVERAGE_RESULTS, (precompile(signature), false))
        end
        let signature = Tuple{typeof(Base.size), Array{Int64, 2}}
            push!(PAW_AUDIT_COVERAGE_RESULTS, (precompile(signature), false))
        end
        let signature = Tuple{typeof(Base.:(==)), Tuple{Int64, Int64}, Tuple{Int64, Int64}}
            push!(PAW_AUDIT_COVERAGE_RESULTS, (precompile(signature), false))
        end
        let signature = Tuple{Type{Array{Float64, N} where N}, UndefInitializer, Int64}
            push!(PAW_AUDIT_COVERAGE_RESULTS, (precompile(signature), false))
        end
        let signature = Tuple{typeof(Base.Broadcast.broadcasted), Type{Float64}, Array{Float64, 1}}
            push!(PAW_AUDIT_COVERAGE_RESULTS, (precompile(signature), false))
        end
        let signature = Tuple{
                typeof(Base.Broadcast.materialize),
                Base.Broadcast.Broadcasted{
                    Base.Broadcast.DefaultArrayStyle{1},
                    Nothing,
                    Type{Float64},
                    Tuple{Array{Float64, 1}},
                },
            }
            push!(PAW_AUDIT_COVERAGE_RESULTS, (precompile(signature), false))
        end
        let signature = Tuple{typeof(Base.transpose), Array{Float64, 1}}
            push!(PAW_AUDIT_COVERAGE_RESULTS, (precompile(signature), false))
        end
        let signature = Tuple{typeof(Base.length), Array{Float64, 1}}
            push!(PAW_AUDIT_COVERAGE_RESULTS, (precompile(signature), false))
        end
        let signature = Tuple{typeof(Base.collect), Base.UnitRange{Int64}}
            push!(PAW_AUDIT_COVERAGE_RESULTS, (precompile(signature), false))
        end
        let signature = Tuple{Type{Array{Float64, N} where N}, UndefInitializer, Int64, Int64}
            push!(PAW_AUDIT_COVERAGE_RESULTS, (precompile(signature), false))
        end
        let signature = Tuple{typeof(Base.size), Array{Float64, 2}}
            push!(PAW_AUDIT_COVERAGE_RESULTS, (precompile(signature), false))
        end
        let signature = Tuple{typeof(Base.getindex), Array{Float64, 1}, Int64}
            push!(PAW_AUDIT_COVERAGE_RESULTS, (precompile(signature), false))
        end
        let signature = Tuple{typeof(Base.isfinite), Float64}
            push!(PAW_AUDIT_COVERAGE_RESULTS, (precompile(signature), false))
        end
        let signature = Tuple{typeof(Base.length), Array{Int64, 1}}
            push!(PAW_AUDIT_COVERAGE_RESULTS, (precompile(signature), false))
        end
        let signature =
                Tuple{typeof(Base.zeros), Type{Base.Complex{Float64}}, Int64, Int64, Vararg{Int64}}
            push!(PAW_AUDIT_COVERAGE_RESULTS, (precompile(signature), false))
        end
        let signature = Tuple{typeof(Base.reshape), Array{Base.Complex{Float64}, 1}, Int64, Int64}
            push!(PAW_AUDIT_COVERAGE_RESULTS, (precompile(signature), false))
        end
        let signature = Tuple{
                typeof(Core.kwcall),
                NamedTuple{(:normalize_coefficients,), Tuple{Bool}},
                Type{WannierNLQG.SymmetryFoundation.PlaneWaveKPoint},
                Array{Float64, 1},
                Array{Int64, 2},
                Array{Base.Complex{Float64}, 3},
                Array{Float64, 1},
            }
            push!(PAW_AUDIT_COVERAGE_RESULTS, (precompile(signature), false))
        end
        let signature = Tuple{
                typeof(Base.getindex),
                Type{WannierNLQG.SymmetryFoundation.PlaneWaveKPoint},
                WannierNLQG.SymmetryFoundation.PlaneWaveKPoint,
            }
            push!(PAW_AUDIT_COVERAGE_RESULTS, (precompile(signature), false))
        end
        let signature = Tuple{Type{Base.KeyError}, String}
            push!(PAW_AUDIT_COVERAGE_RESULTS, (precompile(signature), false))
        end
        let signature = Tuple{typeof(Base.literal_pow), typeof(Base.:(^)), Int64, Base.Val{2}}
            push!(PAW_AUDIT_COVERAGE_RESULTS, (precompile(signature), false))
        end
        let signature = Tuple{typeof(Base.maximum), Array{Int64, 1}}
            push!(PAW_AUDIT_COVERAGE_RESULTS, (precompile(signature), false))
        end
        let signature = Tuple{typeof(Base.zeros), Type{Float64}, Int64, Int64, Vararg{Int64}}
            push!(PAW_AUDIT_COVERAGE_RESULTS, (precompile(signature), false))
        end
        let signature =
                Tuple{typeof(Base.length), Array{WannierNLQG.SymmetryFoundation.PlaneWaveKPoint, 1}}
            push!(PAW_AUDIT_COVERAGE_RESULTS, (precompile(signature), false))
        end
        let signature = Tuple{
                typeof(Base.Iterators.enumerate),
                Array{WannierNLQG.SymmetryFoundation.PlaneWaveKPoint, 1},
            }
            push!(PAW_AUDIT_COVERAGE_RESULTS, (precompile(signature), false))
        end
        let signature = Tuple{
                typeof(Base.iterate),
                Base.Iterators.Enumerate{Array{WannierNLQG.SymmetryFoundation.PlaneWaveKPoint, 1}},
                Tuple{Int64},
            }
            push!(PAW_AUDIT_COVERAGE_RESULTS, (precompile(signature), false))
        end
        let signature = Tuple{
                typeof(Base.iterate),
                Base.Iterators.Enumerate{Array{WannierNLQG.SymmetryFoundation.PlaneWaveKPoint, 1}},
                Tuple{Int64, Int64},
            }
            push!(PAW_AUDIT_COVERAGE_RESULTS, (precompile(signature), false))
        end
        let signature = Tuple{
                typeof(Core.memoryref),
                GenericMemory{
                    :not_atomic,
                    Array{Base.Complex{Float64}, 2},
                    Core.AddrSpace{Core}(0x00),
                },
            }
            push!(PAW_AUDIT_COVERAGE_RESULTS, (precompile(signature), false))
        end
        let signature =
                Tuple{typeof(Base.axes), Array{WannierNLQG.SymmetryFoundation.PlaneWaveKPoint, 1}}
            push!(PAW_AUDIT_COVERAGE_RESULTS, (precompile(signature), false))
        end
        let signature = Tuple{
                typeof(Base.getindex),
                Array{WannierNLQG.SymmetryFoundation.PlaneWaveKPoint, 1},
                Int64,
            }
            push!(PAW_AUDIT_COVERAGE_RESULTS, (precompile(signature), false))
        end
        let signature =
                Tuple{typeof(Base.getindex), Array{Array{Base.Complex{Float64}, 3}, 1}, Int64}
            push!(PAW_AUDIT_COVERAGE_RESULTS, (precompile(signature), false))
        end
        let signature = Tuple{
                typeof(Base.getproperty),
                WannierNLQG.SymmetryFoundation.PlaneWaveKPoint,
                Symbol,
            }
            push!(PAW_AUDIT_COVERAGE_RESULTS, (precompile(signature), false))
        end
        let signature = Tuple{
                Type{LinearAlgebra.Diagonal{T, V} where {V <: AbstractArray{T, 1}} where T},
                Array{Float64, 1},
            }
            push!(PAW_AUDIT_COVERAGE_RESULTS, (precompile(signature), false))
        end
        let signature = Tuple{
                typeof(Base.:(*)),
                LinearAlgebra.Adjoint{Base.Complex{Float64}, Array{Base.Complex{Float64}, 2}},
                LinearAlgebra.Diagonal{Float64, Array{Float64, 1}},
                Array{Base.Complex{Float64}, 2},
            }
            push!(PAW_AUDIT_COVERAGE_RESULTS, (precompile(signature), false))
        end
        let signature = Tuple{
                typeof(Base.push!),
                Array{Array{Base.Complex{Float64}, 2}, 1},
                Array{Base.Complex{Float64}, 2},
            }
            push!(PAW_AUDIT_COVERAGE_RESULTS, (precompile(signature), false))
        end
        let signature = Tuple{typeof(HDF5.API.try_close_finalizer), HDF5.Datatype}
            push!(PAW_AUDIT_COVERAGE_RESULTS, (precompile(signature), false))
        end
        let signature = Tuple{typeof(HDF5.API.try_close_finalizer), HDF5.AttributeAccessProperties}
            push!(PAW_AUDIT_COVERAGE_RESULTS, (precompile(signature), false))
        end
        let signature = Tuple{typeof(HDF5.API.try_close_finalizer), HDF5.LinkAccessProperties}
            push!(PAW_AUDIT_COVERAGE_RESULTS, (precompile(signature), false))
        end
        let signature = Tuple{typeof(HDF5.API.try_close_finalizer), HDF5.DatasetTransferProperties}
            push!(PAW_AUDIT_COVERAGE_RESULTS, (precompile(signature), false))
        end
        let signature = Tuple{typeof(HDF5.API.try_close_finalizer), HDF5.FileCreateProperties}
            push!(PAW_AUDIT_COVERAGE_RESULTS, (precompile(signature), false))
        end
        let signature = Tuple{typeof(HDF5.API.try_close_finalizer), HDF5.StringCreateProperties}
            push!(PAW_AUDIT_COVERAGE_RESULTS, (precompile(signature), false))
        end
        let signature = Tuple{typeof(HDF5.API.try_close_finalizer), HDF5.ObjectCreateProperties}
            push!(PAW_AUDIT_COVERAGE_RESULTS, (precompile(signature), false))
        end
        let signature = Tuple{typeof(HDF5.API.try_close_finalizer), HDF5.ObjectCopyProperties}
            push!(PAW_AUDIT_COVERAGE_RESULTS, (precompile(signature), false))
        end
        let signature = Tuple{typeof(HDF5.API.try_close_finalizer), HDF5.LinkCreateProperties}
            push!(PAW_AUDIT_COVERAGE_RESULTS, (precompile(signature), false))
        end
        let signature = Tuple{typeof(HDF5.API.try_close_finalizer), HDF5.GroupCreateProperties}
            push!(PAW_AUDIT_COVERAGE_RESULTS, (precompile(signature), false))
        end
        let signature = Tuple{typeof(HDF5.API.try_close_finalizer), HDF5.GroupAccessProperties}
            push!(PAW_AUDIT_COVERAGE_RESULTS, (precompile(signature), false))
        end
        let signature = Tuple{typeof(HDF5.API.try_close_finalizer), HDF5.FileMountProperties}
            push!(PAW_AUDIT_COVERAGE_RESULTS, (precompile(signature), false))
        end
        let signature = Tuple{typeof(HDF5.API.try_close_finalizer), HDF5.DatatypeCreateProperties}
            push!(PAW_AUDIT_COVERAGE_RESULTS, (precompile(signature), false))
        end
        let signature = Tuple{typeof(HDF5.API.try_close_finalizer), HDF5.DatatypeAccessProperties}
            push!(PAW_AUDIT_COVERAGE_RESULTS, (precompile(signature), false))
        end
        let signature = Tuple{typeof(HDF5.API.try_close_finalizer), HDF5.DatasetAccessProperties}
            push!(PAW_AUDIT_COVERAGE_RESULTS, (precompile(signature), false))
        end
        let signature = Tuple{typeof(HDF5.API.try_close_finalizer), HDF5.AttributeCreateProperties}
            push!(PAW_AUDIT_COVERAGE_RESULTS, (precompile(signature), false))
        end
        let signature = Tuple{
                typeof(Core.memoryref),
                GenericMemory{:not_atomic, Array{Int64, 2}, Core.AddrSpace{Core}(0x00)},
            }
            push!(PAW_AUDIT_COVERAGE_RESULTS, (precompile(signature), false))
        end
        let signature = Tuple{typeof(Base.hashindex), NTuple{9, Int64}, Int64}
            push!(PAW_AUDIT_COVERAGE_RESULTS, (precompile(signature), false))
        end
        let signature = Tuple{typeof(Base.isequal), NTuple{9, Int64}, NTuple{9, Int64}}
            push!(PAW_AUDIT_COVERAGE_RESULTS, (precompile(signature), false))
        end
        let signature = Tuple{Type{Pair{A, B} where {B} where A}, NTuple{9, Int64}, Int64}
            push!(PAW_AUDIT_COVERAGE_RESULTS, (precompile(signature), false))
        end
        let signature =
                Tuple{typeof(Base.empty), Base.Dict{Any, Any}, Type{NTuple{9, Int64}}, Type{Int64}}
            push!(PAW_AUDIT_COVERAGE_RESULTS, (precompile(signature), false))
        end
        let signature = Tuple{
                typeof(Base.getproperty),
                WannierNLQG.SymmetryFoundation.MagneticSymmetryInventory,
                Symbol,
            }
            push!(PAW_AUDIT_COVERAGE_RESULTS, (precompile(signature), false))
        end
        let signature = Tuple{
                Type{Base.Generator{I, F} where {F} where I},
                WannierNLQGWannierizationExt.PAWMatrixElements.var"#809#837",
                Array{WannierNLQG.SymmetryFoundation.PlaneWaveKPoint, 1},
            }
            push!(PAW_AUDIT_COVERAGE_RESULTS, (precompile(signature), false))
        end
        let signature = Tuple{
                typeof(Base.reduce),
                Function,
                Base.Generator{
                    Array{WannierNLQG.SymmetryFoundation.PlaneWaveKPoint, 1},
                    WannierNLQGWannierizationExt.PAWMatrixElements.var"#809#837",
                },
            }
            push!(PAW_AUDIT_COVERAGE_RESULTS, (precompile(signature), false))
        end
        let signature = Tuple{
                Base.var"##mapfoldl#335",
                Base._InitialValue,
                typeof(Base.mapfoldl),
                Function,
                Function,
                Base.Generator{
                    Array{WannierNLQG.SymmetryFoundation.PlaneWaveKPoint, 1},
                    WannierNLQGWannierizationExt.PAWMatrixElements.var"#809#837",
                },
            }
            push!(PAW_AUDIT_COVERAGE_RESULTS, (precompile(signature), false))
        end
        let signature = Tuple{
                typeof(Base.mapfoldl_impl),
                typeof(Base.identity),
                typeof(Base.vcat),
                Base._InitialValue,
                Base.Generator{
                    Array{WannierNLQG.SymmetryFoundation.PlaneWaveKPoint, 1},
                    WannierNLQGWannierizationExt.PAWMatrixElements.var"#809#837",
                },
            }
            push!(PAW_AUDIT_COVERAGE_RESULTS, (precompile(signature), false))
        end
        let signature =
                Tuple{Type{Array{Float64, 2}}, LinearAlgebra.Transpose{Float64, Array{Float64, 1}}}
            push!(PAW_AUDIT_COVERAGE_RESULTS, (precompile(signature), false))
        end
        let signature = Tuple{typeof(Base.zeros), Type{Int64}, Int64}
            push!(PAW_AUDIT_COVERAGE_RESULTS, (precompile(signature), false))
        end
        let signature = Tuple{typeof(Base.Broadcast.dotview), Array{Int64, 1}, Array{Int64, 1}}
            push!(PAW_AUDIT_COVERAGE_RESULTS, (precompile(signature), false))
        end
        let signature = Tuple{
                typeof(Base.Broadcast.materialize!),
                Base.SubArray{Int64, 1, Array{Int64, 1}, Tuple{Array{Int64, 1}}, false},
                Base.Broadcast.Broadcasted{
                    Base.Broadcast.DefaultArrayStyle{0},
                    Nothing,
                    typeof(Base.identity),
                    Tuple{Int64},
                },
            }
            push!(PAW_AUDIT_COVERAGE_RESULTS, (precompile(signature), false))
        end
        let signature = Tuple{
                typeof(Base._all),
                WannierNLQGWannierizationExt.PAWMatrixElements.var"#810#838"{
                    WannierNLQG.SymmetryFoundation.NativeWavefunctionData,
                },
                Array{Int64, 1},
                Base.Colon,
            }
            push!(PAW_AUDIT_COVERAGE_RESULTS, (precompile(signature), false))
        end
        let signature = Tuple{typeof(Base.in), Int64, Base.OneTo{Int64}}
            push!(PAW_AUDIT_COVERAGE_RESULTS, (precompile(signature), false))
        end
        let signature = Tuple{
                typeof(Base.eachindex),
                Array{WannierNLQG.SymmetryFoundation.SymmetryOperation, 1},
            }
            push!(PAW_AUDIT_COVERAGE_RESULTS, (precompile(signature), false))
        end
        let signature = Tuple{
                Type{Base.Generator{I, F} where {F} where I},
                WannierNLQGWannierizationExt.PAWMatrixElements.var"#811#839"{
                    Array{Int64, 3},
                    Array{Int64, 2},
                    Array{WannierNLQG.SymmetryFoundation.SymmetryOperation, 1},
                    WannierNLQGWannierizationExt.PAWMatrixElements._QEStrictSewingMetric,
                    WannierNLQG.SymmetryFoundation.NativeWavefunctionData,
                    Int64,
                },
                Base.OneTo{Int64},
            }
            push!(PAW_AUDIT_COVERAGE_RESULTS, (precompile(signature), false))
        end
        let signature = Tuple{
                typeof(Base.collect),
                Base.Generator{
                    Base.OneTo{Int64},
                    WannierNLQGWannierizationExt.PAWMatrixElements.var"#811#839"{
                        Array{Int64, 3},
                        Array{Int64, 2},
                        Array{WannierNLQG.SymmetryFoundation.SymmetryOperation, 1},
                        WannierNLQGWannierizationExt.PAWMatrixElements._QEStrictSewingMetric,
                        WannierNLQG.SymmetryFoundation.NativeWavefunctionData,
                        Int64,
                    },
                },
            }
            push!(PAW_AUDIT_COVERAGE_RESULTS, (precompile(signature), false))
        end
        let signature = Tuple{Type{Pair{A, B} where {B} where A}, Tuple{Int64, Int64, Int64}, Int64}
            push!(PAW_AUDIT_COVERAGE_RESULTS, (precompile(signature), false))
        end
        let signature = Tuple{
                typeof(Base.grow_to!),
                Base.Dict{Tuple{Int64, Int64, Int64}, Int64},
                Base.Generator{
                    Base.OneTo{Int64},
                    WannierNLQGWannierizationExt.PAWMatrixElements.var"#385#386"{
                        WannierNLQG.SymmetryFoundation.PlaneWaveKPoint,
                    },
                },
                Int64,
            }
            push!(PAW_AUDIT_COVERAGE_RESULTS, (precompile(signature), false))
        end
        let signature = Tuple{
                typeof(Base.:(*)),
                Base.SubArray{
                    Base.Complex{Float64},
                    2,
                    Array{Base.Complex{Float64}, 3},
                    Tuple{Base.Slice{Base.OneTo{Int64}}, Base.Slice{Base.OneTo{Int64}}, Int64},
                    true,
                },
                Array{Base.Complex{Float64}, 2},
            }
            push!(PAW_AUDIT_COVERAGE_RESULTS, (precompile(signature), false))
        end
        let signature = Tuple{
                typeof(Base.Broadcast.broadcasted),
                typeof(getfield),
                Array{
                    NamedTuple{
                        (
                            :raw,
                            :pseudo,
                            :augmentation,
                            :transformed,
                            :transformed_projectors,
                            :reconstruction,
                        ),
                        Tuple{
                            Array{Base.Complex{Float64}, 2},
                            Array{Base.Complex{Float64}, 2},
                            Array{Base.Complex{Float64}, 2},
                            Array{Base.Complex{Float64}, 3},
                            Array{Base.Complex{Float64}, 3},
                            NamedTuple{
                                (
                                    :reconstruction_leakage_weight,
                                    :state_leakage_weight,
                                    :reconstruction_leakage_amplitude_audit,
                                    :state_leakage_amplitude_audit,
                                    :minimum_residual_gram_eigenvalue,
                                ),
                                NTuple{5, Float64},
                            },
                        },
                    },
                    1,
                },
                Symbol,
            }
            push!(PAW_AUDIT_COVERAGE_RESULTS, (precompile(signature), false))
        end
        let signature = Tuple{
                typeof(Base.Broadcast.materialize),
                Base.Broadcast.Broadcasted{
                    Base.Broadcast.DefaultArrayStyle{1},
                    Nothing,
                    typeof(getfield),
                    Tuple{
                        Array{
                            NamedTuple{
                                (
                                    :raw,
                                    :pseudo,
                                    :augmentation,
                                    :transformed,
                                    :transformed_projectors,
                                    :reconstruction,
                                ),
                                Tuple{
                                    Array{Base.Complex{Float64}, 2},
                                    Array{Base.Complex{Float64}, 2},
                                    Array{Base.Complex{Float64}, 2},
                                    Array{Base.Complex{Float64}, 3},
                                    Array{Base.Complex{Float64}, 3},
                                    NamedTuple{
                                        (
                                            :reconstruction_leakage_weight,
                                            :state_leakage_weight,
                                            :reconstruction_leakage_amplitude_audit,
                                            :state_leakage_amplitude_audit,
                                            :minimum_residual_gram_eigenvalue,
                                        ),
                                        NTuple{5, Float64},
                                    },
                                },
                            },
                            1,
                        },
                        Base.RefValue{Symbol},
                    },
                },
            }
            push!(PAW_AUDIT_COVERAGE_RESULTS, (precompile(signature), false))
        end
        let signature = Tuple{
                typeof(Base.setindex!),
                Array{Array{Base.Complex{Float64}, 2}, 1},
                Array{Base.Complex{Float64}, 2},
                Int64,
            }
            push!(PAW_AUDIT_COVERAGE_RESULTS, (precompile(signature), false))
        end
        let signature = Tuple{
                typeof(Base.checkbounds),
                Type{Bool},
                Array{WannierNLQG.SymmetryFoundation.PlaneWaveKPoint, 1},
                Int64,
            }
            push!(PAW_AUDIT_COVERAGE_RESULTS, (precompile(signature), false))
        end
        let signature = Tuple{typeof(Base.getindex), Array{Float64, 1}, Base.UnitRange{Int64}}
            push!(PAW_AUDIT_COVERAGE_RESULTS, (precompile(signature), false))
        end
        let signature = Tuple{
                typeof(Base.getindex),
                Array{
                    NamedTuple{
                        (
                            :raw,
                            :pseudo,
                            :augmentation,
                            :transformed,
                            :transformed_projectors,
                            :reconstruction,
                        ),
                        Tuple{
                            Array{Base.Complex{Float64}, 2},
                            Array{Base.Complex{Float64}, 2},
                            Array{Base.Complex{Float64}, 2},
                            Array{Base.Complex{Float64}, 3},
                            Array{Base.Complex{Float64}, 3},
                            NamedTuple{
                                (
                                    :reconstruction_leakage_weight,
                                    :state_leakage_weight,
                                    :reconstruction_leakage_amplitude_audit,
                                    :state_leakage_amplitude_audit,
                                    :minimum_residual_gram_eigenvalue,
                                ),
                                NTuple{5, Float64},
                            },
                        },
                    },
                    1,
                },
                Int64,
            }
            push!(PAW_AUDIT_COVERAGE_RESULTS, (precompile(signature), false))
        end
        let signature = Tuple{
                typeof(Base.getproperty),
                NamedTuple{
                    (
                        :raw,
                        :pseudo,
                        :augmentation,
                        :transformed,
                        :transformed_projectors,
                        :reconstruction,
                    ),
                    Tuple{
                        Array{Base.Complex{Float64}, 2},
                        Array{Base.Complex{Float64}, 2},
                        Array{Base.Complex{Float64}, 2},
                        Array{Base.Complex{Float64}, 3},
                        Array{Base.Complex{Float64}, 3},
                        NamedTuple{
                            (
                                :reconstruction_leakage_weight,
                                :state_leakage_weight,
                                :reconstruction_leakage_amplitude_audit,
                                :state_leakage_amplitude_audit,
                                :minimum_residual_gram_eigenvalue,
                            ),
                            NTuple{5, Float64},
                        },
                    },
                },
                Symbol,
            }
            push!(PAW_AUDIT_COVERAGE_RESULTS, (precompile(signature), false))
        end
        let signature = Tuple{
                typeof(Base.getproperty),
                NamedTuple{
                    (
                        :reconstruction_leakage_weight,
                        :state_leakage_weight,
                        :reconstruction_leakage_amplitude_audit,
                        :state_leakage_amplitude_audit,
                        :minimum_residual_gram_eigenvalue,
                    ),
                    NTuple{5, Float64},
                },
                Symbol,
            }
            push!(PAW_AUDIT_COVERAGE_RESULTS, (precompile(signature), false))
        end
        let signature = Tuple{
                typeof(Base.view),
                Array{Base.Complex{Float64}, 2},
                Base.UnitRange{Int64},
                Base.UnitRange{Int64},
            }
            push!(PAW_AUDIT_COVERAGE_RESULTS, (precompile(signature), false))
        end
        let signature = Tuple{
                Type{Array{T, 2} where T},
                Base.SubArray{
                    Base.Complex{Float64},
                    2,
                    Array{Base.Complex{Float64}, 2},
                    Tuple{Base.UnitRange{Int64}, Base.UnitRange{Int64}},
                    false,
                },
            }
            push!(PAW_AUDIT_COVERAGE_RESULTS, (precompile(signature), false))
        end
        let signature = Tuple{typeof(Base.adjoint), Array{Base.Complex{Float64}, 2}}
            push!(PAW_AUDIT_COVERAGE_RESULTS, (precompile(signature), false))
        end
        let signature = Tuple{
                typeof(Base.:(*)),
                LinearAlgebra.Adjoint{Base.Complex{Float64}, Array{Base.Complex{Float64}, 2}},
                Array{Base.Complex{Float64}, 2},
            }
            push!(PAW_AUDIT_COVERAGE_RESULTS, (precompile(signature), false))
        end
        let signature = Tuple{
                typeof(Base.:(*)),
                Array{Base.Complex{Float64}, 2},
                LinearAlgebra.Adjoint{Base.Complex{Float64}, Array{Base.Complex{Float64}, 2}},
            }
            push!(PAW_AUDIT_COVERAGE_RESULTS, (precompile(signature), false))
        end
        let signature = Tuple{typeof(LinearAlgebra.svd), Array{Base.Complex{Float64}, 2}}
            push!(PAW_AUDIT_COVERAGE_RESULTS, (precompile(signature), false))
        end
        let signature = Tuple{
                typeof(Base.getproperty),
                LinearAlgebra.SVD{
                    Base.Complex{Float64},
                    Float64,
                    Array{Base.Complex{Float64}, 2},
                    Array{Float64, 1},
                },
                Symbol,
            }
            push!(PAW_AUDIT_COVERAGE_RESULTS, (precompile(signature), false))
        end
        let signature = Tuple{
                typeof(Base.:(*)),
                Array{Base.Complex{Float64}, 2},
                Array{Base.Complex{Float64}, 2},
            }
            push!(PAW_AUDIT_COVERAGE_RESULTS, (precompile(signature), false))
        end
        let signature = Tuple{
                typeof(Base.getindex),
                Array{WannierNLQG.SymmetryFoundation.SymmetryOperation, 1},
                Int64,
            }
            push!(PAW_AUDIT_COVERAGE_RESULTS, (precompile(signature), false))
        end
        let signature = Tuple{
                typeof(Base.getproperty),
                WannierNLQG.SymmetryFoundation.SymmetryOperation,
                Symbol,
            }
            push!(PAW_AUDIT_COVERAGE_RESULTS, (precompile(signature), false))
        end
        let signature = Tuple{
                typeof(
                    WannierNLQGWannierizationExt.PAWMatrixElements._star_hamiltonian_residual_metrics,
                ),
                Array{Base.Complex{Float64}, 2},
                Array{Base.Complex{Float64}, 2},
                Array{Base.Complex{Float64}, 2},
                Bool,
            }
            push!(PAW_AUDIT_COVERAGE_RESULTS, (precompile(signature), false))
        end
        let signature = Tuple{typeof(Base.size), Array{Base.Complex{Float64}, 2}}
            push!(PAW_AUDIT_COVERAGE_RESULTS, (precompile(signature), false))
        end
        let signature = Tuple{typeof(Base.getindex), Array{Base.Complex{Float64}, 2}, Int64, Int64}
            push!(PAW_AUDIT_COVERAGE_RESULTS, (precompile(signature), false))
        end
        let signature = Tuple{typeof(Base.abs), Base.Complex{Float64}}
            push!(PAW_AUDIT_COVERAGE_RESULTS, (precompile(signature), false))
        end
        let signature = Tuple{typeof(Base.setindex!), Base.BitArray{2}, Bool, Int64, Int64}
            push!(PAW_AUDIT_COVERAGE_RESULTS, (precompile(signature), false))
        end
        let signature = Tuple{typeof(Base.:(*)), Float64, Base.Complex{Float64}}
            push!(PAW_AUDIT_COVERAGE_RESULTS, (precompile(signature), false))
        end
        let signature = Tuple{
                typeof(Base.getindex),
                Base.SubArray{
                    Base.Complex{Float64},
                    2,
                    Array{Base.Complex{Float64}, 2},
                    Tuple{Base.UnitRange{Int64}, Base.UnitRange{Int64}},
                    false,
                },
                Int64,
                Int64,
            }
            push!(PAW_AUDIT_COVERAGE_RESULTS, (precompile(signature), false))
        end
        let signature = Tuple{typeof(Base.maximum), NTuple{5, Float64}}
            push!(PAW_AUDIT_COVERAGE_RESULTS, (precompile(signature), false))
        end
        let signature = Tuple{
                typeof(Base.length),
                Array{WannierNLQG.SymmetryFoundation.SymmetryOperation, 1},
            }
            push!(PAW_AUDIT_COVERAGE_RESULTS, (precompile(signature), false))
        end
        let signature = Tuple{
                typeof(Base.findall),
                WannierNLQGWannierizationExt.PAWMatrixElements.var"#819#847"{
                    WannierNLQG.Wannierization.RepresentationProductTable,
                    Int64,
                },
                Base.OneTo{Int64},
            }
            push!(PAW_AUDIT_COVERAGE_RESULTS, (precompile(signature), false))
        end
        let signature = Tuple{typeof(Base.Iterators.only), Array{Int64, 1}}
            push!(PAW_AUDIT_COVERAGE_RESULTS, (precompile(signature), false))
        end
        let signature = Tuple{Type{Pair{A, B} where {B} where A}, Int64, Int64}
            push!(PAW_AUDIT_COVERAGE_RESULTS, (precompile(signature), false))
        end
        let signature = Tuple{typeof(Base.empty), Base.Dict{Any, Any}, Type{Int64}, Type{Int64}}
            push!(PAW_AUDIT_COVERAGE_RESULTS, (precompile(signature), false))
        end
        let signature = Tuple{
                typeof(Base.grow_to!),
                Base.Dict{Int64, Int64},
                Base.Generator{
                    Base.Iterators.Enumerate{Array{Int64, 1}},
                    WannierNLQGWannierizationExt.PAWMatrixElements.var"#779#790",
                },
                Tuple{Int64, Int64},
            }
            push!(PAW_AUDIT_COVERAGE_RESULTS, (precompile(signature), false))
        end
        let signature = Tuple{
                typeof(Base.show),
                Base.GenericIOBuffer{GenericMemory{:not_atomic, UInt8, Core.AddrSpace{Core}(0x00)}},
                Tuple{Int64, Int64, Int64},
            }
            push!(PAW_AUDIT_COVERAGE_RESULTS, (precompile(signature), false))
        end
        let signature =
                Tuple{typeof(Base.empty), Base.Dict{String, Float64}, Type{String}, Type{Real}}
            push!(PAW_AUDIT_COVERAGE_RESULTS, (precompile(signature), false))
        end
        let signature = Tuple{
                typeof(Base.grow_to!),
                Base.Dict{String, Real},
                Base.Generator{
                    Base.Pairs{
                        Symbol,
                        Real,
                        NTuple{6, Symbol},
                        NamedTuple{
                            (
                                :cap_ev,
                                :admitted,
                                :unresolved,
                                :maximum_component_bands,
                                :maximum_component_span_ev,
                                :cascade_edge_count,
                            ),
                            Tuple{Float64, Int64, Int64, Int64, Float64, Int64},
                        },
                    },
                    WannierNLQGWannierizationExt.PAWMatrixElements.var"#834#862",
                },
                Int64,
            }
            push!(PAW_AUDIT_COVERAGE_RESULTS, (precompile(signature), false))
        end
        let signature = Tuple{
                typeof(Base._array_for),
                Type{Base.Dict{String, Real}},
                Base.HasShape{1},
                Tuple{Base.OneTo{Int64}},
            }
            push!(PAW_AUDIT_COVERAGE_RESULTS, (precompile(signature), false))
        end
        let signature = Tuple{
                typeof(Base.collect_to_with_first!),
                Array{Base.Dict{String, Real}, 1},
                Base.Dict{String, Real},
                Base.Generator{
                    Array{
                        NamedTuple{
                            (
                                :cap_ev,
                                :admitted,
                                :unresolved,
                                :maximum_component_bands,
                                :maximum_component_span_ev,
                                :cascade_edge_count,
                            ),
                            Tuple{Float64, Int64, Int64, Int64, Float64, Int64},
                        },
                        1,
                    },
                    WannierNLQGWannierizationExt.PAWMatrixElements.var"#833#861",
                },
                Int64,
            }
            push!(PAW_AUDIT_COVERAGE_RESULTS, (precompile(signature), false))
        end
        let signature =
                Tuple{Type{Pair{A, B} where {B} where A}, String, Array{Base.Dict{String, Real}, 1}}
            push!(PAW_AUDIT_COVERAGE_RESULTS, (precompile(signature), false))
        end
        let signature = Tuple{typeof(Base.add_sum), Int64, Int64}
            push!(PAW_AUDIT_COVERAGE_RESULTS, (precompile(signature), false))
        end
        let signature = Tuple{typeof(JSON3.defaultminimum), Array{Base.Dict{String, Real}, 1}}
            push!(PAW_AUDIT_COVERAGE_RESULTS, (precompile(signature), false))
        end
        let signature = Tuple{
                Base.MappingRF{
                    JSON3.var"#59#60"{Array{Base.Dict{String, Real}, 1}},
                    Base.MappingRF{
                        typeof(JSON3.defaultminimum),
                        Base.BottomRF{typeof(Base.add_sum)},
                    },
                },
                Base._InitialValue,
                Int64,
            }
            push!(PAW_AUDIT_COVERAGE_RESULTS, (precompile(signature), false))
        end
        let signature = Tuple{
                Base.MappingRF{
                    JSON3.var"#59#60"{Array{Base.Dict{String, Real}, 1}},
                    Base.MappingRF{
                        typeof(JSON3.defaultminimum),
                        Base.BottomRF{typeof(Base.add_sum)},
                    },
                },
                Int64,
                Int64,
            }
            push!(PAW_AUDIT_COVERAGE_RESULTS, (precompile(signature), false))
        end
        let signature = Tuple{typeof(Base.StringVector), Int64}
            push!(PAW_AUDIT_COVERAGE_RESULTS, (precompile(signature), false))
        end
        let signature = Tuple{typeof(Base.setindex!), Array{UInt8, 1}, UInt8, Int64}
            push!(PAW_AUDIT_COVERAGE_RESULTS, (precompile(signature), false))
        end
        let signature = Tuple{
                typeof(JSON3.write),
                StructTypes.ArrayType,
                Array{UInt8, 1},
                Int64,
                Int64,
                Array{Base.Dict{String, Real}, 1},
            }
            push!(PAW_AUDIT_COVERAGE_RESULTS, (precompile(signature), false))
        end
        let signature = Tuple{
                typeof(JSON3.write),
                StructTypes.DictType,
                Array{UInt8, 1},
                Int64,
                Int64,
                Base.Dict{String, Real},
            }
            push!(PAW_AUDIT_COVERAGE_RESULTS, (precompile(signature), false))
        end
        let signature = Tuple{Type{String}, Array{UInt8, 1}}
            push!(PAW_AUDIT_COVERAGE_RESULTS, (precompile(signature), false))
        end
        let signature = Tuple{typeof(Base.add_sum), UInt64, UInt64}
            push!(PAW_AUDIT_COVERAGE_RESULTS, (precompile(signature), false))
        end
        let signature = Tuple{
                typeof(JSON3.write),
                JSON3.Array{
                    JSON3.Object{
                        S,
                        TT,
                    } where {TT <: AbstractArray{UInt64, 1}} where S <: AbstractArray{UInt8, 1},
                    Base.CodeUnits{UInt8, String},
                    Base.SubArray{UInt64, 1, Array{UInt64, 1}, Tuple{Base.UnitRange{Int64}}, true},
                },
            }
            push!(PAW_AUDIT_COVERAGE_RESULTS, (precompile(signature), false))
        end
        let signature = Tuple{
                Base.MappingRF{
                    JSON3.var"#59#60"{
                        JSON3.Array{
                            JSON3.Object{
                                S,
                                TT,
                            } where {
                                TT <: AbstractArray{UInt64, 1},
                            } where S <: AbstractArray{UInt8, 1},
                            Base.CodeUnits{UInt8, String},
                            Base.SubArray{
                                UInt64,
                                1,
                                Array{UInt64, 1},
                                Tuple{Base.UnitRange{Int64}},
                                true,
                            },
                        },
                    },
                    Base.MappingRF{
                        typeof(JSON3.defaultminimum),
                        Base.BottomRF{typeof(Base.add_sum)},
                    },
                },
                Base._InitialValue,
                Int64,
            }
            push!(PAW_AUDIT_COVERAGE_RESULTS, (precompile(signature), false))
        end
        let signature = Tuple{
                Base.MappingRF{
                    JSON3.var"#59#60"{
                        JSON3.Array{
                            JSON3.Object{
                                S,
                                TT,
                            } where {
                                TT <: AbstractArray{UInt64, 1},
                            } where S <: AbstractArray{UInt8, 1},
                            Base.CodeUnits{UInt8, String},
                            Base.SubArray{
                                UInt64,
                                1,
                                Array{UInt64, 1},
                                Tuple{Base.UnitRange{Int64}},
                                true,
                            },
                        },
                    },
                    Base.MappingRF{
                        typeof(JSON3.defaultminimum),
                        Base.BottomRF{typeof(Base.add_sum)},
                    },
                },
                Int64,
                Int64,
            }
            push!(PAW_AUDIT_COVERAGE_RESULTS, (precompile(signature), false))
        end
        let signature = Tuple{
                typeof(Base.length),
                JSON3.Array{
                    JSON3.Object{
                        S,
                        TT,
                    } where {TT <: AbstractArray{UInt64, 1}} where S <: AbstractArray{UInt8, 1},
                    Base.CodeUnits{UInt8, String},
                    Array{UInt64, 1},
                },
            }
            push!(PAW_AUDIT_COVERAGE_RESULTS, (precompile(signature), false))
        end
        let signature = Tuple{
                typeof(Base.Iterators.enumerate),
                JSON3.Array{
                    JSON3.Object{
                        S,
                        TT,
                    } where {TT <: AbstractArray{UInt64, 1}} where S <: AbstractArray{UInt8, 1},
                    Base.CodeUnits{UInt8, String},
                    Array{UInt64, 1},
                },
            }
            push!(PAW_AUDIT_COVERAGE_RESULTS, (precompile(signature), false))
        end
        let signature = Tuple{
                typeof(Base.iterate),
                Base.Iterators.Enumerate{
                    JSON3.Array{
                        JSON3.Object{
                            S,
                            TT,
                        } where {
                            TT <: AbstractArray{UInt64, 1},
                        } where S <: AbstractArray{UInt8, 1},
                        Base.CodeUnits{UInt8, String},
                        Array{UInt64, 1},
                    },
                },
                Tuple{Int64},
            }
            push!(PAW_AUDIT_COVERAGE_RESULTS, (precompile(signature), false))
        end
        let signature = Tuple{
                typeof(Base.iterate),
                Base.Iterators.Enumerate{
                    JSON3.Array{
                        JSON3.Object{
                            S,
                            TT,
                        } where {
                            TT <: AbstractArray{UInt64, 1},
                        } where S <: AbstractArray{UInt8, 1},
                        Base.CodeUnits{UInt8, String},
                        Array{UInt64, 1},
                    },
                },
                Tuple{Int64, Tuple{Int64, Int64}},
            }
            push!(PAW_AUDIT_COVERAGE_RESULTS, (precompile(signature), false))
        end
        let signature =
                Tuple{Type{Array{Int64, 2}}, LinearAlgebra.Transpose{Int64, Array{Int64, 2}}}
            push!(PAW_AUDIT_COVERAGE_RESULTS, (precompile(signature), false))
        end
        let signature = Tuple{
                typeof(Base.Broadcast.materialize!),
                Base.SubArray{
                    Base.Complex{Float64},
                    2,
                    Array{Base.Complex{Float64}, 3},
                    Tuple{Base.Slice{Base.OneTo{Int64}}, Base.Slice{Base.OneTo{Int64}}, Int64},
                    true,
                },
                Base.Broadcast.Broadcasted{
                    Base.Broadcast.DefaultArrayStyle{2},
                    Nothing,
                    typeof(Base.identity),
                    Tuple{Array{Base.Complex{Float64}, 2}},
                },
            }
            push!(PAW_AUDIT_COVERAGE_RESULTS, (precompile(signature), false))
        end
        let signature = Tuple{typeof(Base.setindex!), HDF5.Attributes, Int64, String}
            push!(PAW_AUDIT_COVERAGE_RESULTS, (precompile(signature), false))
        end
        let signature = Tuple{typeof(Base.setindex!), HDF5.Attributes, Bool, String}
            push!(PAW_AUDIT_COVERAGE_RESULTS, (precompile(signature), false))
        end
    end
end

# Observed gauge-chain signatures: compile only, never execute writers.
const GAUGE_CHAIN_COVERAGE_RESULTS = Tuple{Bool, Bool}[]
@compile_workload begin
    if WannierizationInternalSupport.WannierNLQG.FIRST_USE_WORKLOAD_ENABLED
        let signature = Tuple{
                typeof(WannierNLQG.Wannierization.diagnose_wannier_gauge_chain),
                WannierNLQG.Wannierization.WannierGaugeChainDiagnosticConfig,
            }
            push!(GAUGE_CHAIN_COVERAGE_RESULTS, (precompile(signature), false))
        end
        let signature = Tuple{typeof(Base.vect), Array{String, 1}, Vararg{Array{String, 1}}}
            push!(GAUGE_CHAIN_COVERAGE_RESULTS, (precompile(signature), false))
        end
        let signature = Tuple{typeof(Base.iterate), Array{Array{String, 1}, 1}}
            push!(GAUGE_CHAIN_COVERAGE_RESULTS, (precompile(signature), false))
        end
        let signature = Tuple{
                typeof(Base.issorted),
                Array{String, 1},
                Base.Order.ReverseOrdering{Base.Order.ForwardOrdering},
            }
            push!(GAUGE_CHAIN_COVERAGE_RESULTS, (precompile(signature), false))
        end
        let signature = Tuple{typeof(Base.haskey), Base.Dict{Base.PkgId, Module}, Base.PkgId}
            push!(GAUGE_CHAIN_COVERAGE_RESULTS, (precompile(signature), false))
        end
        let signature = Tuple{
                typeof(Base.getindex),
                Type{Union{Nothing, Array{String, 1}}},
                Nothing,
                Array{String, 1},
            }
            push!(GAUGE_CHAIN_COVERAGE_RESULTS, (false, false))
        end
        let signature = Tuple{typeof(Base.iterate), Array{Union{Nothing, Array{String, 1}}, 1}}
            push!(GAUGE_CHAIN_COVERAGE_RESULTS, (false, false))
        end
        let signature =
                Tuple{typeof(Base.iterate), Array{Union{Nothing, Array{String, 1}}, 1}, Int64}
            push!(GAUGE_CHAIN_COVERAGE_RESULTS, (false, false))
        end
        let signature = Tuple{typeof(Base.isempty), Base.UnitRange{Int64}}
            push!(GAUGE_CHAIN_COVERAGE_RESULTS, (precompile(signature), false))
        end
        let signature = Tuple{Type{NamedTuple{(:init,), T} where T <: Tuple}, Tuple{Float64}}
            push!(GAUGE_CHAIN_COVERAGE_RESULTS, (precompile(signature), false))
        end
        let signature = Tuple{typeof(Base.:(==)), Char, Char}
            push!(GAUGE_CHAIN_COVERAGE_RESULTS, (precompile(signature), false))
        end
        let signature = Tuple{typeof(Base.iszero), Bool}
            push!(GAUGE_CHAIN_COVERAGE_RESULTS, (precompile(signature), false))
        end
        let signature = Tuple{typeof(Base.:(&)), Int64, Int64}
            push!(GAUGE_CHAIN_COVERAGE_RESULTS, (precompile(signature), false))
        end
        let signature = Tuple{
                typeof(Base.getproperty),
                Base.MappingRF{typeof(Base.abs), typeof(Base.min)},
                Symbol,
            }
            push!(GAUGE_CHAIN_COVERAGE_RESULTS, (precompile(signature), false))
        end
        let signature = Tuple{
                Type{
                    NamedTuple{(:wigner_seitz_tolerance, :search_size, :label), T} where T <: Tuple,
                },
                Tuple{Float64, Int64, String},
            }
            push!(GAUGE_CHAIN_COVERAGE_RESULTS, (precompile(signature), false))
        end
        let signature = Tuple{
                Type{NamedTuple{(:support_tolerance, :label), T} where T <: Tuple},
                Tuple{Float64, String},
            }
            push!(GAUGE_CHAIN_COVERAGE_RESULTS, (precompile(signature), false))
        end
        let signature = Tuple{typeof(Base.real), Base.Complex{Float64}}
            push!(GAUGE_CHAIN_COVERAGE_RESULTS, (precompile(signature), false))
        end
        let signature = Tuple{typeof(Base.imag), Base.Complex{Float64}}
            push!(GAUGE_CHAIN_COVERAGE_RESULTS, (precompile(signature), false))
        end
        let signature = Tuple{typeof(Base.float), Float64}
            push!(GAUGE_CHAIN_COVERAGE_RESULTS, (precompile(signature), false))
        end
        let signature = Tuple{typeof(Base.abs), Float64}
            push!(GAUGE_CHAIN_COVERAGE_RESULTS, (precompile(signature), false))
        end
        let signature = Tuple{typeof(Base.isinf), Float64}
            push!(GAUGE_CHAIN_COVERAGE_RESULTS, (precompile(signature), false))
        end
        let signature = Tuple{typeof(Base.:(>)), Float64, Float64}
            push!(GAUGE_CHAIN_COVERAGE_RESULTS, (precompile(signature), false))
        end
        let signature = Tuple{typeof(Base.:(/)), Float64, Int64}
            push!(GAUGE_CHAIN_COVERAGE_RESULTS, (precompile(signature), false))
        end
        let signature = Tuple{typeof(Base.:(*)), Float64, Float64}
            push!(GAUGE_CHAIN_COVERAGE_RESULTS, (precompile(signature), false))
        end
        let signature = Tuple{typeof(Base.:(<=)), Float64, Float64}
            push!(GAUGE_CHAIN_COVERAGE_RESULTS, (precompile(signature), false))
        end
        let signature = Tuple{
                typeof(Base.getproperty),
                Base.MappingRF{typeof(LinearAlgebra.norm), Base.BottomRF{typeof(Base.max)}},
                Symbol,
            }
            push!(GAUGE_CHAIN_COVERAGE_RESULTS, (precompile(signature), false))
        end
        let signature = Tuple{
                typeof(Base.getproperty),
                Base.MappingRF{
                    Base.ComposedFunction{typeof(Base.float), typeof(LinearAlgebra.norm)},
                    Base.BottomRF{typeof(Base.:(+))},
                },
                Symbol,
            }
            push!(GAUGE_CHAIN_COVERAGE_RESULTS, (precompile(signature), false))
        end
        let signature = Tuple{typeof(Base.tail), Tuple{Int64, Int64}}
            push!(GAUGE_CHAIN_COVERAGE_RESULTS, (precompile(signature), false))
        end
        let signature = Tuple{
                typeof(Base.getproperty),
                Base.MappingRF{typeof(LinearAlgebra.norm), Base.BottomRF{typeof(Base.min)}},
                Symbol,
            }
            push!(GAUGE_CHAIN_COVERAGE_RESULTS, (precompile(signature), false))
        end
        let signature = Tuple{typeof(Base.indexed_iterate), Pair{String, String}, Int64}
            push!(GAUGE_CHAIN_COVERAGE_RESULTS, (precompile(signature), false))
        end
        let signature = Tuple{typeof(Base.indexed_iterate), Pair{String, String}, Int64, Int64}
            push!(GAUGE_CHAIN_COVERAGE_RESULTS, (precompile(signature), false))
        end
        let signature = Tuple{Type{NamedTuple{(:cleanup,), T} where T <: Tuple}, Tuple{Bool}}
            push!(GAUGE_CHAIN_COVERAGE_RESULTS, (precompile(signature), false))
        end
        let signature = Tuple{typeof(Base.tail), NTuple{16, Symbol}}
            push!(GAUGE_CHAIN_COVERAGE_RESULTS, (precompile(signature), false))
        end
        let signature = Tuple{typeof(Base.tail), NTuple{15, Symbol}}
            push!(GAUGE_CHAIN_COVERAGE_RESULTS, (precompile(signature), false))
        end
        let signature = Tuple{typeof(Base.tail), NTuple{14, Symbol}}
            push!(GAUGE_CHAIN_COVERAGE_RESULTS, (precompile(signature), false))
        end
        let signature = Tuple{typeof(Base.tail), NTuple{13, Symbol}}
            push!(GAUGE_CHAIN_COVERAGE_RESULTS, (precompile(signature), false))
        end
        let signature = Tuple{typeof(Base.tail), NTuple{12, Symbol}}
            push!(GAUGE_CHAIN_COVERAGE_RESULTS, (precompile(signature), false))
        end
        let signature = Tuple{typeof(Base.tail), NTuple{11, Symbol}}
            push!(GAUGE_CHAIN_COVERAGE_RESULTS, (precompile(signature), false))
        end
        let signature = Tuple{typeof(Base.tail), NTuple{10, Symbol}}
            push!(GAUGE_CHAIN_COVERAGE_RESULTS, (precompile(signature), false))
        end
        let signature = Tuple{typeof(Base.tail), NTuple{9, Symbol}}
            push!(GAUGE_CHAIN_COVERAGE_RESULTS, (precompile(signature), false))
        end
        let signature = Tuple{typeof(Base.tail), NTuple{8, Symbol}}
            push!(GAUGE_CHAIN_COVERAGE_RESULTS, (precompile(signature), false))
        end
        let signature = Tuple{typeof(Base.tail), NTuple{7, Symbol}}
            push!(GAUGE_CHAIN_COVERAGE_RESULTS, (precompile(signature), false))
        end
        let signature = Tuple{typeof(Base.tail), NTuple{6, Symbol}}
            push!(GAUGE_CHAIN_COVERAGE_RESULTS, (precompile(signature), false))
        end
        let signature = Tuple{typeof(Base.tail), NTuple{5, Symbol}}
            push!(GAUGE_CHAIN_COVERAGE_RESULTS, (precompile(signature), false))
        end
        let signature = Tuple{typeof(Base.tail), NTuple{4, Symbol}}
            push!(GAUGE_CHAIN_COVERAGE_RESULTS, (precompile(signature), false))
        end
        let signature =
                Tuple{typeof(Base._similar_shape), Base.StepRange{Int64, Int64}, Base.HasShape{1}}
            push!(GAUGE_CHAIN_COVERAGE_RESULTS, (precompile(signature), false))
        end
        let signature = Tuple{
                typeof(WannierNLQGWannierizationExt.OperatorExport.diagnose_wannier_gauge_chain),
                WannierNLQG.Wannierization.WannierGaugeChainDiagnosticConfig,
            }
            push!(GAUGE_CHAIN_COVERAGE_RESULTS, (precompile(signature), false))
        end
        let signature = Tuple{typeof(Base.empty), Base.Dict{Any, Any}, Type{String}, Type{String}}
            push!(GAUGE_CHAIN_COVERAGE_RESULTS, (precompile(signature), false))
        end
        let signature = Tuple{
                typeof(Base.grow_to!),
                Base.Dict{String, String},
                Base.Generator{
                    Base.Dict{String, String},
                    WannierNLQGWannierizationExt.OperatorExport.var"#211#214",
                },
                Int64,
            }
            push!(GAUGE_CHAIN_COVERAGE_RESULTS, (precompile(signature), false))
        end
        let signature = Tuple{typeof(Base.prod), Tuple{Int64}}
            push!(GAUGE_CHAIN_COVERAGE_RESULTS, (precompile(signature), false))
        end
        let signature = Tuple{typeof(Base.in), String, Tuple{String, String}}
            push!(GAUGE_CHAIN_COVERAGE_RESULTS, (precompile(signature), false))
        end
        let signature = Tuple{
                Type{Array{Base.Complex{Float64}, N} where N},
                UndefInitializer,
                Int64,
                Int64,
                Int64,
            }
            push!(GAUGE_CHAIN_COVERAGE_RESULTS, (precompile(signature), false))
        end
        let signature = Tuple{Type{Array{Float64, N} where N}, UndefInitializer, Int64, Int64}
            push!(GAUGE_CHAIN_COVERAGE_RESULTS, (precompile(signature), false))
        end
        let signature = Tuple{Type{Array{Float64, N} where N}, UndefInitializer, Int64}
            push!(GAUGE_CHAIN_COVERAGE_RESULTS, (precompile(signature), false))
        end
        let signature = Tuple{Type{Array{Int64, N} where N}, UndefInitializer, Int64}
            push!(GAUGE_CHAIN_COVERAGE_RESULTS, (precompile(signature), false))
        end
        let signature = Tuple{Type{Array{Int64, N} where N}, UndefInitializer, Int64, Int64}
            push!(GAUGE_CHAIN_COVERAGE_RESULTS, (precompile(signature), false))
        end
        let signature = Tuple{Type{Array{UInt8, N} where N}, UndefInitializer, Int64, Int64}
            push!(GAUGE_CHAIN_COVERAGE_RESULTS, (precompile(signature), false))
        end
        let signature = Tuple{typeof(Base.Broadcast.broadcasted), Type{String}, Array{String, 1}}
            push!(GAUGE_CHAIN_COVERAGE_RESULTS, (precompile(signature), false))
        end
        let signature = Tuple{
                typeof(Base.Broadcast.materialize),
                Base.Broadcast.Broadcasted{
                    Base.Broadcast.DefaultArrayStyle{1},
                    Nothing,
                    Type{String},
                    Tuple{Array{String, 1}},
                },
            }
            push!(GAUGE_CHAIN_COVERAGE_RESULTS, (precompile(signature), false))
        end
        let signature = Tuple{typeof(Base.eachindex), Array{Int64, 1}}
            push!(GAUGE_CHAIN_COVERAGE_RESULTS, (precompile(signature), false))
        end
        let signature = Tuple{Type{Bool}, UInt8}
            push!(GAUGE_CHAIN_COVERAGE_RESULTS, (precompile(signature), false))
        end
        let signature = Tuple{typeof(Base.getindex), Array{Float64, 1}, Int64}
            push!(GAUGE_CHAIN_COVERAGE_RESULTS, (precompile(signature), false))
        end
        let signature = Tuple{typeof(Base.Broadcast.broadcasted), Type{Float64}, Array{Float64, 1}}
            push!(GAUGE_CHAIN_COVERAGE_RESULTS, (precompile(signature), false))
        end
        let signature = Tuple{
                typeof(Base.Broadcast.materialize),
                Base.Broadcast.Broadcasted{
                    Base.Broadcast.DefaultArrayStyle{1},
                    Nothing,
                    Type{Float64},
                    Tuple{Array{Float64, 1}},
                },
            }
            push!(GAUGE_CHAIN_COVERAGE_RESULTS, (precompile(signature), false))
        end
        let signature = Tuple{Type{Tuple}, Array{Float64, 1}}
            push!(GAUGE_CHAIN_COVERAGE_RESULTS, (precompile(signature), false))
        end
        let signature = Tuple{typeof(Base.getproperty), HDF5.GroupCreateProperties, Symbol}
            push!(GAUGE_CHAIN_COVERAGE_RESULTS, (precompile(signature), false))
        end
        let signature = Tuple{Type{Array{Bool, N} where N}, UndefInitializer, Int64}
            push!(GAUGE_CHAIN_COVERAGE_RESULTS, (precompile(signature), false))
        end
        let signature = Tuple{typeof(Base.getindex), Array{Bool, 1}, Int64}
            push!(GAUGE_CHAIN_COVERAGE_RESULTS, (precompile(signature), false))
        end
        let signature = Tuple{typeof(Base.length), Array{Float64, 1}}
            push!(GAUGE_CHAIN_COVERAGE_RESULTS, (precompile(signature), false))
        end
        let signature = Tuple{Type{Array{Float64, 1}}, Array{Float64, 1}}
            push!(GAUGE_CHAIN_COVERAGE_RESULTS, (precompile(signature), false))
        end
        let signature = Tuple{Type{Array{Int64, 1}}, Array{Int64, 1}}
            push!(GAUGE_CHAIN_COVERAGE_RESULTS, (precompile(signature), false))
        end
        let signature = Tuple{typeof(Base.in), String, NTuple{11, String}}
            push!(GAUGE_CHAIN_COVERAGE_RESULTS, (precompile(signature), false))
        end
        let signature = Tuple{
                Type{Array{Base.Complex{Float64}, N} where N},
                UndefInitializer,
                NTuple{4, Int64},
            }
            push!(GAUGE_CHAIN_COVERAGE_RESULTS, (precompile(signature), false))
        end
        let signature = Tuple{typeof(Base.in), String, NTuple{8, String}}
            push!(GAUGE_CHAIN_COVERAGE_RESULTS, (precompile(signature), false))
        end
        let signature = Tuple{
                typeof(Base._array_for),
                Type{Symbol},
                Base.HasShape{1},
                Tuple{Base.OneTo{Int64}},
            }
            push!(GAUGE_CHAIN_COVERAGE_RESULTS, (precompile(signature), false))
        end
        let signature = Tuple{Type{Base.BitArray{2}}, Base.BitArray{2}}
            push!(GAUGE_CHAIN_COVERAGE_RESULTS, (precompile(signature), false))
        end
        let signature = Tuple{
                typeof(HDF5.generic_read),
                HDF5.Attribute,
                HDF5.Datatype,
                Type{HDF5.FixedString{255, 0}},
            }
            push!(GAUGE_CHAIN_COVERAGE_RESULTS, (false, false))
        end
        let signature = Tuple{typeof(Base.in), String, NTuple{4, String}}
            push!(GAUGE_CHAIN_COVERAGE_RESULTS, (precompile(signature), false))
        end
        let signature = Tuple{typeof(Base.:(==)), Bool, Bool}
            push!(GAUGE_CHAIN_COVERAGE_RESULTS, (precompile(signature), false))
        end
        let signature = Tuple{typeof(Base.in), String, NTuple{6, String}}
            push!(GAUGE_CHAIN_COVERAGE_RESULTS, (precompile(signature), false))
        end
        let signature = Tuple{typeof(Base.in), String, NTuple{5, String}}
            push!(GAUGE_CHAIN_COVERAGE_RESULTS, (precompile(signature), false))
        end
        let signature = Tuple{typeof(Base.in), String, Tuple{String, String, String}}
            push!(GAUGE_CHAIN_COVERAGE_RESULTS, (precompile(signature), false))
        end
        let signature = Tuple{typeof(Base.setindex!), Array{String, 1}, String, Int64}
            push!(GAUGE_CHAIN_COVERAGE_RESULTS, (precompile(signature), false))
        end
        let signature = Tuple{typeof(Base.unique), Array{String, 1}}
            push!(GAUGE_CHAIN_COVERAGE_RESULTS, (precompile(signature), false))
        end
        let signature = Tuple{
                typeof(Base.show),
                Base.IOContext{
                    Base.GenericIOBuffer{
                        GenericMemory{:not_atomic, UInt8, Core.AddrSpace{Core}(0x00)},
                    },
                },
                Int64,
            }
            push!(GAUGE_CHAIN_COVERAGE_RESULTS, (precompile(signature), false))
        end
        let signature = Tuple{
                typeof(Base.show),
                Base.IOContext{
                    Base.GenericIOBuffer{
                        GenericMemory{:not_atomic, UInt8, Core.AddrSpace{Core}(0x00)},
                    },
                },
                Array{Float64, 1},
            }
            push!(GAUGE_CHAIN_COVERAGE_RESULTS, (precompile(signature), false))
        end
        let signature = Tuple{
                typeof(Core.memoryref),
                GenericMemory{
                    :not_atomic,
                    Tuple{Int64, Int64, Float64},
                    Core.AddrSpace{Core}(0x00),
                },
            }
            push!(GAUGE_CHAIN_COVERAGE_RESULTS, (precompile(signature), false))
        end
        let signature = Tuple{typeof(Base.zeros), Type{Float64}, Int64, Int64, Vararg{Int64}}
            push!(GAUGE_CHAIN_COVERAGE_RESULTS, (precompile(signature), false))
        end
        let signature = Tuple{typeof(Base.falses), Int64, Int64, Vararg{Int64}}
            push!(GAUGE_CHAIN_COVERAGE_RESULTS, (precompile(signature), false))
        end
        let signature = Tuple{typeof(HDF5.API.try_close_finalizer), HDF5.Datatype}
            push!(GAUGE_CHAIN_COVERAGE_RESULTS, (precompile(signature), false))
        end
        let signature = Tuple{typeof(HDF5.API.try_close_finalizer), HDF5.AttributeAccessProperties}
            push!(GAUGE_CHAIN_COVERAGE_RESULTS, (precompile(signature), false))
        end
        let signature = Tuple{typeof(HDF5.API.try_close_finalizer), HDF5.LinkAccessProperties}
            push!(GAUGE_CHAIN_COVERAGE_RESULTS, (precompile(signature), false))
        end
        let signature = Tuple{typeof(HDF5.API.try_close_finalizer), HDF5.DatasetTransferProperties}
            push!(GAUGE_CHAIN_COVERAGE_RESULTS, (precompile(signature), false))
        end
        let signature = Tuple{typeof(HDF5.API.try_close_finalizer), HDF5.FileCreateProperties}
            push!(GAUGE_CHAIN_COVERAGE_RESULTS, (precompile(signature), false))
        end
        let signature = Tuple{typeof(HDF5.API.try_close_finalizer), HDF5.StringCreateProperties}
            push!(GAUGE_CHAIN_COVERAGE_RESULTS, (precompile(signature), false))
        end
        let signature = Tuple{typeof(HDF5.API.try_close_finalizer), HDF5.ObjectCreateProperties}
            push!(GAUGE_CHAIN_COVERAGE_RESULTS, (precompile(signature), false))
        end
        let signature = Tuple{typeof(HDF5.API.try_close_finalizer), HDF5.ObjectCopyProperties}
            push!(GAUGE_CHAIN_COVERAGE_RESULTS, (precompile(signature), false))
        end
        let signature = Tuple{typeof(HDF5.API.try_close_finalizer), HDF5.LinkCreateProperties}
            push!(GAUGE_CHAIN_COVERAGE_RESULTS, (precompile(signature), false))
        end
        let signature = Tuple{typeof(HDF5.API.try_close_finalizer), HDF5.GroupCreateProperties}
            push!(GAUGE_CHAIN_COVERAGE_RESULTS, (precompile(signature), false))
        end
        let signature = Tuple{typeof(HDF5.API.try_close_finalizer), HDF5.GroupAccessProperties}
            push!(GAUGE_CHAIN_COVERAGE_RESULTS, (precompile(signature), false))
        end
        let signature = Tuple{typeof(HDF5.API.try_close_finalizer), HDF5.FileMountProperties}
            push!(GAUGE_CHAIN_COVERAGE_RESULTS, (precompile(signature), false))
        end
        let signature = Tuple{typeof(HDF5.API.try_close_finalizer), HDF5.DatatypeCreateProperties}
            push!(GAUGE_CHAIN_COVERAGE_RESULTS, (precompile(signature), false))
        end
        let signature = Tuple{typeof(HDF5.API.try_close_finalizer), HDF5.DatatypeAccessProperties}
            push!(GAUGE_CHAIN_COVERAGE_RESULTS, (precompile(signature), false))
        end
        let signature = Tuple{typeof(HDF5.API.try_close_finalizer), HDF5.DatasetAccessProperties}
            push!(GAUGE_CHAIN_COVERAGE_RESULTS, (precompile(signature), false))
        end
        let signature = Tuple{typeof(HDF5.API.try_close_finalizer), HDF5.AttributeCreateProperties}
            push!(GAUGE_CHAIN_COVERAGE_RESULTS, (precompile(signature), false))
        end
        let signature = Tuple{Type{Array{Int64, N} where N}, UndefInitializer, Int64, Int64, Int64}
            push!(GAUGE_CHAIN_COVERAGE_RESULTS, (precompile(signature), false))
        end
        let signature =
                Tuple{Type{Array{Float64, N} where N}, UndefInitializer, Int64, Int64, Int64}
            push!(GAUGE_CHAIN_COVERAGE_RESULTS, (precompile(signature), false))
        end
        let signature = Tuple{Type{Array{UInt8, N} where N}, UndefInitializer, Int64}
            push!(GAUGE_CHAIN_COVERAGE_RESULTS, (precompile(signature), false))
        end
        let signature = Tuple{
                Type{Array{T, 2} where T},
                LinearAlgebra.Transpose{Float64, Array{Float64, 2}},
            }
            push!(GAUGE_CHAIN_COVERAGE_RESULTS, (precompile(signature), false))
        end
        let signature = Tuple{
                typeof(Core.kwcall),
                NamedTuple{
                    (:conventions, :input_sha256),
                    Tuple{Base.Dict{String, String}, Base.Dict{String, String}},
                },
                Type{WannierNLQG.SymmetryFoundation.BandRepresentation},
                String,
                Symbol,
                Bool,
                Array{Float64, 2},
                Array{Float64, 2},
                Tuple{Int64, Int64, Int64},
                Array{Float64, 2},
                Array{Float64, 2},
                Array{WannierNLQG.SymmetryFoundation.SymmetryOperation, 1},
                Array{Int64, 2},
                Array{Int64, 3},
                Array{Base.Complex{Float64}, 4},
                Array{Int64, 2},
                Array{Int64, 1},
                Array{Int64, 1},
                Array{Int64, 1},
            }
            push!(GAUGE_CHAIN_COVERAGE_RESULTS, (precompile(signature), false))
        end
        let signature = Tuple{
                typeof(Base.write),
                Base.GenericIOBuffer{GenericMemory{:not_atomic, UInt8, Core.AddrSpace{Core}(0x00)}},
                Array{Int64, 1},
            }
            push!(GAUGE_CHAIN_COVERAGE_RESULTS, (precompile(signature), false))
        end
        let signature = Tuple{typeof(Base.size), Base.BitArray{2}}
            push!(GAUGE_CHAIN_COVERAGE_RESULTS, (precompile(signature), false))
        end
        let signature = Tuple{typeof(Base.:(==)), Tuple{Int64, Int64}, Tuple{Int64, Int64}}
            push!(GAUGE_CHAIN_COVERAGE_RESULTS, (precompile(signature), false))
        end
        let signature =
                Tuple{typeof(Base.Broadcast.broadcasted), typeof(Base.:(!)), Base.BitArray{2}}
            push!(GAUGE_CHAIN_COVERAGE_RESULTS, (precompile(signature), false))
        end
        let signature = Tuple{
                typeof(Base.Broadcast.broadcasted),
                typeof(Base.:(|)),
                Base.Broadcast.Broadcasted{
                    Base.Broadcast.DefaultArrayStyle{2},
                    Nothing,
                    typeof(Base.:(!)),
                    Tuple{Base.BitArray{2}},
                },
                Base.BitArray{2},
            }
            push!(GAUGE_CHAIN_COVERAGE_RESULTS, (precompile(signature), false))
        end
        let signature = Tuple{
                typeof(Base.Broadcast.materialize),
                Base.Broadcast.Broadcasted{
                    Base.Broadcast.DefaultArrayStyle{2},
                    Nothing,
                    typeof(Base.:(|)),
                    Tuple{
                        Base.Broadcast.Broadcasted{
                            Base.Broadcast.DefaultArrayStyle{2},
                            Nothing,
                            typeof(Base.:(!)),
                            Tuple{Base.BitArray{2}},
                        },
                        Base.BitArray{2},
                    },
                },
            }
            push!(GAUGE_CHAIN_COVERAGE_RESULTS, (precompile(signature), false))
        end
        let signature = Tuple{typeof(Base.size), Array{Int64, 2}}
            push!(GAUGE_CHAIN_COVERAGE_RESULTS, (precompile(signature), false))
        end
        let signature = Tuple{typeof(Base.size), Array{Float64, 2}}
            push!(GAUGE_CHAIN_COVERAGE_RESULTS, (precompile(signature), false))
        end
        let signature = Tuple{typeof(Base.length), Array{UInt8, 1}}
            push!(GAUGE_CHAIN_COVERAGE_RESULTS, (precompile(signature), false))
        end
        let signature = Tuple{typeof(Base.getindex), Array{UInt8, 1}, Int64}
            push!(GAUGE_CHAIN_COVERAGE_RESULTS, (precompile(signature), false))
        end
        let signature = Tuple{Type{Bool}, Int64}
            push!(GAUGE_CHAIN_COVERAGE_RESULTS, (precompile(signature), false))
        end
        let signature =
                Tuple{typeof(Base.:(==)), Tuple{Int64, Int64, Int64}, Tuple{Int64, Int64, Int64}}
            push!(GAUGE_CHAIN_COVERAGE_RESULTS, (precompile(signature), false))
        end
        let signature = Tuple{typeof(Base.get), Base.Dict{String, String}, String, String}
            push!(GAUGE_CHAIN_COVERAGE_RESULTS, (precompile(signature), false))
        end
        let signature = Tuple{
                WannierNLQGWannierizationExt.OperatorExport.var"#119#122"{
                    WannierNLQG.IO.WannierCHK,
                },
                Array{Base.Complex{Float64}, 3},
                String,
            }
            push!(GAUGE_CHAIN_COVERAGE_RESULTS, (precompile(signature), false))
        end
        let signature = Tuple{
                WannierNLQGWannierizationExt.OperatorExport.var"#119#122"{
                    WannierNLQG.IO.WannierCHK,
                },
                Array{Base.Complex{Float64}, 4},
                String,
            }
            push!(GAUGE_CHAIN_COVERAGE_RESULTS, (precompile(signature), false))
        end
        let signature = Tuple{Type{Pair{A, B} where {B} where A}, Tuple{Int64, Int64, Int64}, Int64}
            push!(GAUGE_CHAIN_COVERAGE_RESULTS, (precompile(signature), false))
        end
        let signature = Tuple{
                typeof(Base.join),
                Base.GenericIOBuffer{GenericMemory{:not_atomic, UInt8, Core.AddrSpace{Core}(0x00)}},
                Array{Base.SubString{String}, 1},
                Char,
            }
            push!(GAUGE_CHAIN_COVERAGE_RESULTS, (precompile(signature), false))
        end
        let signature = Tuple{
                typeof(
                    WannierNLQGWannierizationExt.WannierizationInternalSupport.atomic_hdf5_write,
                ),
                WannierNLQGWannierizationExt.OperatorExport.var"#212#215"{
                    Base.Dict{String, String},
                    Symbol,
                    Array{Float64, 3},
                    Array{Float64, 3},
                    WannierNLQG.Core.TightBindingModel{
                        Array{Base.Complex{Float64}, 3},
                        Array{Base.Complex{Float64}, 4},
                    },
                    Array{Base.Complex{Float64}, 3},
                    Array{Int64, 2},
                    WannierNLQG.Core.TightBindingModel{
                        Array{Base.Complex{Float64}, 3},
                        Array{Base.Complex{Float64}, 4},
                    },
                    Array{Base.Complex{Float64}, 3},
                    Array{Int64, 2},
                    Array{Base.Complex{Float64}, 3},
                    Array{Float64, 2},
                    Array{Float64, 2},
                    Array{Float64, 2},
                    WannierNLQG.Wannierization.WannierGaugeLinkDiagnostics,
                    Base.Dict{String, String},
                },
                String,
            }
            push!(GAUGE_CHAIN_COVERAGE_RESULTS, (precompile(signature), false))
        end
        let signature = Tuple{Type{Pair{A, B} where {B} where A}, String, Base.Dict{String, String}}
            push!(GAUGE_CHAIN_COVERAGE_RESULTS, (precompile(signature), false))
        end
        let signature = Tuple{
                Type{Base.Dict{K, V} where {V} where K},
                Tuple{
                    Pair{String, String},
                    Pair{String, String},
                    Pair{String, String},
                    Pair{String, String},
                    Pair{String, Base.Dict{String, String}},
                    Pair{String, Base.Dict{String, String}},
                    Pair{String, String},
                },
            }
            push!(GAUGE_CHAIN_COVERAGE_RESULTS, (precompile(signature), false))
        end
        let signature = Tuple{
                typeof(WannierNLQGWannierizationExt.OperatorExport._atomic_gauge_chain_json),
                String,
                Base.Dict{String, Any},
            }
            push!(GAUGE_CHAIN_COVERAGE_RESULTS, (precompile(signature), false))
        end
        let signature = Tuple{typeof(Base.add_sum), Int64, Int64}
            push!(GAUGE_CHAIN_COVERAGE_RESULTS, (precompile(signature), false))
        end
        let signature = Tuple{typeof(Base.StringVector), Int64}
            push!(GAUGE_CHAIN_COVERAGE_RESULTS, (precompile(signature), false))
        end
        let signature = Tuple{typeof(Base.setindex!), Array{UInt8, 1}, UInt8, Int64}
            push!(GAUGE_CHAIN_COVERAGE_RESULTS, (precompile(signature), false))
        end
        let signature = Tuple{typeof(Base.write), Base.IOStream, Array{UInt8, 1}}
            push!(GAUGE_CHAIN_COVERAGE_RESULTS, (precompile(signature), false))
        end
    end
end

include("MultiStarOwnerFirstUseCoverage.jl")

include("PAWSCDMInputFirstUseCoverage.jl")
