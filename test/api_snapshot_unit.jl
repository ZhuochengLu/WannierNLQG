using Test
using WannierNLQG

const FROZEN_RESPONSES_API_20260805_GEOMETRIC_BLOCK_COVARIANT = Set([
    :ConventionalQuantumGeometryWorkspace,
    :GeometricLoopResponseWorkspace,
    :PhotonDragInjectionCurrentConventionalWorkspace,
    :ProjectorResponseWorkspace,
    :Responses,
    :SHIFT_VECTOR_LOOP_ABS_TOL,
    :ShiftCurrentConventionalWorkspace,
    :ShiftSpinCurrentConventionalWorkspace,
    :WilsonLoopResponseWorkspace,
    :accumulate_conventional_geometry_qhc_response!,
    :accumulate_conventional_response!,
    :accumulate_geometric_loop_shift_current_response!,
    :accumulate_injection_current_response!,
    :accumulate_injection_spin_current_response!,
    :accumulate_photon_drag_injection_current_response!,
    :accumulate_projector_response_shift_current_response!,
    :accumulate_shift_spin_current_response!,
    :berry_curvature_block_element,
    :berry_curvature_component,
    :berry_curvature_dipole_component!,
    :berry_curvature_group_sum_component,
    :berry_curvature_occupied_sum_component,
    :berry_curvature_quadrupole_component!,
    :compute_conventional_shift_current_kernel!,
    :compute_geometric_loop_block_covariant_insertion_derivative!,
    :compute_geometric_loop_central_overlap!,
    :compute_geometric_loop_quantum_hermitian_connection_kernel!,
    :compute_geometric_loop_second_insertions!,
    :compute_geometric_loop_shift_current_kernel!,
    :compute_geometric_loop_shift_vector_kernel!,
    :compute_geometric_loop_shifted_overlaps!,
    :compute_geometric_loop_third_insertions!,
    :compute_injection_current_kernel!,
    :compute_injection_spin_current_kernel!,
    :compute_photon_drag_injection_current_kernel!,
    :compute_projector_quantum_hermitian_connection_from_cache!,
    :compute_projector_quantum_hermitian_connection_kernel!,
    :compute_projector_response_shift_current_kernel!,
    :compute_shift_spin_current_kernel!,
    :compute_shift_spin_current_vertices!,
    :compute_wilson_loop_quantum_hermitian_connection_from_cache!,
    :compute_wilson_loop_shift_current_from_cache!,
    :compute_wilson_loop_shift_vector_from_cache!,
    :conventional_component_response,
    :conventional_generalized_position_derivative_element,
    :conventional_quantum_hermitian_connection_component,
    :expand_band_window_for_groups,
    :finite_loop_log_derivative,
    :geometric_loop_overlap_block_contraction,
    :geometric_loop_overlap_block_contraction_precomputed,
    :geometric_loop_sck_component,
    :hermitian_curvature_tensor_component,
    :injection_current_component,
    :injection_spin_current_component,
    :interband_berry_curvature_component,
    :interband_quantum_geometry_component,
    :interband_quantum_metric_component,
    :interband_quantum_metric_group_sum_component,
    :make_conventional_quantum_geometry_workspace,
    :make_geometric_loop_response_workspace,
    :make_photon_drag_injection_current_conventional_workspace,
    :make_projector_response_workspace,
    :make_shift_current_conventional_workspace,
    :make_shift_spin_current_conventional_workspace,
    :make_wilson_loop_response_workspace,
    :photon_drag_band_windows,
    :photon_drag_compute_overlaps!,
    :photon_drag_has_active_transition,
    :photon_drag_injection_current_component,
    :prepare_projector_response_cache!,
    :prepare_geometric_loop_covariant_axis!,
    :prepare_geometric_loop_covariant_derivative_block!,
    :prepare_geometric_loop_covariant_center!,
    :prepare_geometric_loop_external_connections!,
    :prepare_geometric_loop_frame_axis!,
    :prepare_wilson_loop_response_cache!,
    :prepare_wilson_transported_derivative_block!,
    :projector_qhc_trace_c_cvabc!,
    :projector_response_axis_pairs,
    :projector_response_sck_component,
    :projector_shift_current_trace_terms!,
    :projector_shift_current_trace_terms_low_rank!,
    :projector_trace_four!,
    :projector_trace_four_low_rank!,
    :projector_trace_three!,
    :projector_trace_three_low_rank!,
    :projector_trace_two,
    :project_response_symmetry!,
    :quantum_christoffel_symbol_component!,
    :quantum_hermitian_connection_component,
    :quantum_metric_band_sum_component,
    :quantum_metric_component,
    :quantum_metric_dipole_component!,
    :quantum_metric_group_sum_component,
    :quantum_metric_quadrupole_component!,
    :shift_spin_current_component,
    :shift_spin_current_energy_weight,
    :shift_vector_component,
    :response_component_labels,
    :response_component_tuples,
    :response_symmetry_action_matrix,
    :response_symmetry_basis,
    :response_symmetry_projector,
    :response_symmetry_relations,
    :response_symmetry_sign,
    :triple_phase_product_component,
    :wilson_loop_derivative_product,
    :wilson_loop_derivative_product_from_cache,
    :wilson_loop_overlap!,
    :wilson_loop_shift_vector_loop,
    :wilson_loop_transported_connection,
    :zeeman_interband_berry_curvature_component,
    :zeeman_interband_quantum_geometry_components,
    :zeeman_interband_quantum_metric_component,
])

const FROZEN_RUNTIME_API_20260718 = Set([
    :ACTIVE_PROGRESS,
    :BUNDLE_HAS_MPI,
    :BUNDLE_MPI_CONTEXT,
    :BundleFamilyCounter,
    :CONVENTIONAL_GEOMETRY_HAS_MPI,
    :CONVENTIONAL_GEOMETRY_MPI_CONTEXT,
    :CONVENTIONAL_SC_HAS_MPI,
    :CONVENTIONAL_SC_MPI_CONTEXT,
    :FOURIER_CAPABILITY_LABELS,
    :FOURIER_MEMORY_SAFETY_FACTOR,
    :FourierExecutionPlan,
    :FourierOffsetSignature,
    :FusedBundleRunResult,
    :GEOMETRIC_LOOP_HAS_MPI,
    :GEOMETRIC_LOOP_MPI_CONTEXT,
    :INJECTION_CURRENT_HAS_MPI,
    :INJECTION_CURRENT_MPI_CONTEXT,
    :IntegralTaskAccumulator,
    :KSliceTaskAccumulator,
    :LEGACY_FOURIER_CONFIGURATION_ENV,
    :MPIExecutionContext,
    :MPI_BUNDLE_ACTIVE,
    :MPI_RANK_ENV_KEYS,
    :MPI_SIZE_ENV_KEYS,
    :NormalizedRunControls,
    :PROJECTOR_HAS_MPI,
    :PROJECTOR_MPI_CONTEXT,
    :PhotonDragTransitionScreenWorkspace,
    :ProgressContext,
    :ResponseComponentPlan,
    :ResponseSymmetryExecutionPlan,
    :ResponseTensorSymmetryPlan,
    :RunContext,
    :RunResult,
    :Runtime,
    :SeedInputPaths,
    :TaskConfig,
    :TaskSpec,
    :TransitionScreenWorkspace,
    :bundle_debug_log,
    :bundle_matrix_element_plan,
    :bundle_matrix_families,
    :bundle_mpi_barrier,
    :bundle_mpi_comm_rank,
    :bundle_mpi_comm_size,
    :bundle_mpi_comm_world,
    :bundle_mpi_finalize,
    :bundle_mpi_initialize,
    :bundle_mpi_reduce_sum,
    :canonical_calculation_name,
    :canonical_method_name,
    :canonical_quantity_name,
    :checksum_file,
    :conventional_debug_log,
    :conventional_geometry_debug_log,
    :conventional_geometry_mpi_comm_rank,
    :conventional_geometry_mpi_comm_size,
    :conventional_geometry_mpi_comm_world,
    :conventional_geometry_mpi_finalize,
    :conventional_geometry_mpi_initialize,
    :conventional_geometry_mpi_reduce_sum,
    :conventional_sc_mpi_comm_rank,
    :conventional_sc_mpi_comm_size,
    :conventional_sc_mpi_comm_world,
    :conventional_sc_mpi_finalize,
    :conventional_sc_mpi_initialize,
    :conventional_sc_mpi_reduce_sum,
    :default_case_root,
    :default_model_file,
    :default_output_root,
    :default_system_name,
    :env_float,
    :env_int,
    :env_value,
    :expected_cidx_rank,
    :format_seconds,
    :build_fourier_execution_plan,
    :fourier_execution_summary,
    :fourier_is_central_offset,
    :fourier_offset_memory_estimate,
    :fourier_offset_string,
    :fourier_push_axis_offsets!,
    :fourier_push_second_offsets!,
    :fourier_rank_load,
    :fourier_reduced_offset_plan,
    :fourier_task_offset_graph,
    :fourier_task_offset_signatures,
    :fourier_task_signature,
    :fourier_timing_enabled,
    :fourier_union_capabilities,
    :fourier_union_offset_summary,
    :geometric_loop_debug_log,
    :geometric_loop_mpi_comm_rank,
    :geometric_loop_mpi_comm_size,
    :geometric_loop_mpi_comm_world,
    :geometric_loop_mpi_finalize,
    :geometric_loop_mpi_initialize,
    :geometric_loop_mpi_reduce_sum,
    :infer_single_supported_method,
    :injection_current_debug_log,
    :injection_current_mpi_comm_rank,
    :injection_current_mpi_comm_size,
    :injection_current_mpi_comm_world,
    :injection_current_mpi_finalize,
    :injection_current_mpi_initialize,
    :injection_current_mpi_reduce_sum,
    :is_band_resolved_real_kslice_quantity,
    :is_interband_quantum_geometry_quantity,
    :is_mixed_rank_integral_current_bundle,
    :is_orbital_interband_quantum_geometry_quantity,
    :is_rank2_real_only_kslice_quantity,
    :is_rank3_target_group_real_kslice_quantity,
    :is_rank4_target_group_real_kslice_quantity,
    :is_real_only_kslice_quantity,
    :is_target_group_real_kslice_quantity,
    :is_zeeman_interband_quantum_geometry_quantity,
    :load_mpi_or_error,
    :load_spin_real_space,
    :load_spin_velocity_real_space,
    :make_mpi_context,
    :make_photon_drag_transition_screen_workspace,
    :make_response_component_plan,
    :make_transition_screen_workspace,
    :maybe_load_spin_from_config,
    :maybe_load_spin_velocity_from_context,
    :metadata_display_path,
    :metadata_numerics_entries,
    :metadata_photon_energy_values,
    :metadata_section,
    :metadata_value,
    :method_list_text,
    :mpi_benchmark_finalize!,
    :mpi_bundle_finish!,
    :mpi_bundle_start!,
    :mpi_context_comm_rank,
    :mpi_context_comm_size,
    :mpi_context_comm_world,
    :mpi_context_debug_log,
    :mpi_context_finalize!,
    :mpi_context_force_finalize!,
    :mpi_context_initialize!,
    :mpi_context_log_rank,
    :mpi_context_reduce_sum,
    :mpi_env_truthy,
    :mpi_is_root_process,
    :mpi_launcher_requested,
    :mpi_log_all_ranks,
    :mpi_process_rank,
    :mpi_process_size,
    :mpi_ranked_debug_log,
    :nonzero_photon_momentum,
    :normalize_calculation,
    :normalize_method,
    :normalize_quantity,
    :normalize_requested_task_tuple,
    :normalize_task_specs,
    :normalized_fourier_backend,
    :parse_bool_env,
    :prepare_run_context,
    :progress_append_text!,
    :progress_bar,
    :progress_clear!,
    :progress_compact_seconds,
    :progress_debug_event,
    :progress_display_path,
    :progress_elapsed,
    :progress_emit_lines!,
    :progress_emit_text!,
    :progress_float_capture,
    :progress_format_number,
    :progress_fourier_backend!,
    :progress_hms,
    :progress_int_capture,
    :progress_json_escape,
    :progress_json_value,
    :progress_k_mesh_label,
    :progress_kloop_end_text,
    :progress_kloop_start_text,
    :progress_kloop_text,
    :progress_kv_line,
    :progress_lattice_line,
    :progress_message_body,
    :progress_notice!,
    :progress_numerics_lines,
    :progress_output_names,
    :progress_photon_energy_summary,
    :progress_reciprocal_lattice,
    :progress_record_debug_message!,
    :progress_response_symmetry!,
    :progress_run_control_lines,
    :progress_run_done!,
    :progress_run_failed!,
    :progress_short_text,
    :progress_should_record_text,
    :progress_spec_family_label,
    :progress_stage_from_message,
    :progress_stage_key,
    :progress_start!,
    :progress_store_stage_seconds!,
    :progress_string_capture,
    :progress_system_lines,
    :progress_system_summary!,
    :progress_task_done!,
    :progress_task_start!,
    :progress_task_table_lines,
    :progress_text_line,
    :progress_timestamp,
    :progress_timing_lines,
    :progress_total_k,
    :progress_verbosity_symbol,
    :progress_write_header!,
    :progress_write_jsonl_event!,
    :prepare_response_symmetry_execution_plan,
    :response_symmetry_kmesh_orbits,
    :validate_response_integrand_covariance,
    :validate_response_full_grid_consistency,
    :projector_debug_log,
    :projector_mpi_comm_rank,
    :projector_mpi_comm_size,
    :projector_mpi_comm_world,
    :projector_mpi_finalize,
    :projector_mpi_initialize,
    :projector_mpi_reduce_sum,
    :resolve_case_root,
    :resolve_path,
    :result_filename,
    :result_method_suffix,
    :result_observable_suffix,
    :result_output_path,
    :run,
    :run_task_bundle_fused!,
    :runtime_notice,
    :select_task,
    :supported_methods,
    :task_label,
    :tensor_axis_limits,
    :unified_root,
    :validate_config,
    :validate_config_cartesian_indices,
    :validate_fourier_configuration,
    :validate_fourier_factor,
    :validate_k_mesh_for_calculation,
    :write_fourier_timing,
    :write_metadata,
])

const FROZEN_SYMMETRIZATION_API_20260802_UNIFIED = Set([
    :FAILED_BAND_REPRESENTATION,
    :FAILED_INPUT_PROVENANCE,
    :FAILED_INPUT_SUBSPACE_NOT_CLOSED,
    :FAILED_PHYSICAL_BAND_PRESERVATION,
    :FAILED_POSITION_VALIDATION,
    :GaugeAwareSymmetrizationConfig,
    :GaugeAwareSymmetrizationResult,
    :GaugeAwareSymmetrizationStatus,
    :GaugeAwareSymmetrizationThresholds,
    :GaugeAwareThresholdEvent,
    :HOLD_POSITION_PENDING,
    :MagneticMomentConfig,
    :MeshScreenConfig,
    :RealSpaceOperator,
    :RealSpaceOperatorKind,
    :RealSpaceOperatorSymmetrySpec,
    :REAL_SPACE_AXIAL_DERIVATIVE_OVERLAP,
    :REAL_SPACE_DERIVATIVE_OVERLAP_TENSOR,
    :REAL_SPACE_HAMILTONIAN,
    :REAL_SPACE_HAMILTONIAN_WEIGHTED_AXIAL_DERIVATIVE_OVERLAP,
    :REAL_SPACE_HAMILTONIAN_WEIGHTED_CONNECTION,
    :REAL_SPACE_POSITION,
    :REAL_SPACE_SPIN,
    :REAL_SPACE_SPIN_TIMES_HAMILTONIAN,
    :REAL_SPACE_SPIN_TIMES_HAMILTONIAN_POSITION,
    :REAL_SPACE_SPIN_TIMES_POSITION,
    :REAL_SPACE_SYMMETRIC_DERIVATIVE_OVERLAP,
    :Symmetrization,
    :SymmetrizationConfig,
    :SymmetrizationResult,
    :qualify_response_symmetry_wannier90,
    :screen_wannier_mesh,
    :symmetrize_existing_wannier_model,
    :symmetrize_wannier_operators,
    :write_response_symmetry_artifact,
    :PASS,
    :PASS_WITH_WARNINGS,
])

const SYMMETRY_FOUNDATION_API_20260901 = Set([
    :AbstractWavefunctionSource,
    :BandRepresentation,
    :BandRepresentationQualificationScope,
    :CrystalStructure,
    :MagneticSymmetryInventory,
    :NativeWavefunctionData,
    :PlaneWaveKPoint,
    :QuantumEspressoWavefunctionSource,
    :RealSpaceProjectionContext,
    :RealSpaceSymmetrizationResult,
    :RepresentationRawDiagnostic,
    :SymmetryFoundation,
    :SymmetryOperation,
    :VASPBandRepresentationConfig,
    :VASPWavefunctionSource,
    :WannierSymmetryPlan,
    :detect_magnetic_symmetry_inventory,
    :detect_symmetry_operations,
    :generate_vasp_band_representation,
    :maximum_real_space_covariance_error,
    :read_band_representation_hdf5,
    :symmetrize_real_space_operator,
    :write_band_representation_hdf5,
])

const WANNIER_PROJECTION_API_20260901 = Set([
    :ProjectionRadialTransformConfig,
    :ProjectionSpec,
    :WannierProjection,
    :WannierProjectionBasis,
    :WannierProjectionBlock,
    :WannierWinData,
    :build_wannier_projection_basis,
    :build_wannier_symmetry_plan,
    :crystal_structure,
    :projection_orbital_values,
    :read_wannier_win,
])

const FROZEN_WANNIERIZATION_API_20260819_Z_U_FOURIER_DIAGNOSTICS = Set([
    :AbstractWannierMatrixElementSource,
    :BandRepresentationPreparationConfig,
    :BandRepresentationPreparationResult,
    :ExternalWannier90Matrices,
    :NativeQEPAWMatrices,
    :NativeVASPPAWMatrices,
    :QEPAWArrayParityMetrics,
    :QEPAWMatrixElementResult,
    :QEPAWParityThresholds,
    :RepresentationAssessmentStatus,
    :RepresentationCompatibilityReport,
    :RepresentationGateDefinitionStatus,
    :RepresentationProductTable,
    :SymmetryAdaptedWannierizationConfig,
    :TBSymmetryMetric,
    :TBSymmetryQualification,
    :TB_SYMMETRY_QUALIFICATION_SCHEMA,
    :TB_SYMMETRY_QUALIFICATION_SCHEMA_VERSION,
    :VASPPAWArrayParityMetrics,
    :VASPPAWMatrixElementResult,
    :VASPPAWParityThresholds,
    :VASPPAWSPNResult,
    :VASPPAWSPNThresholds,
    :read_vasp_paw_spn_provenance,
    :VASPPAWSolverGaugeDiagnostics,
    :Wannierization,
    :WannierizationDiagnostic,
    :WannierizationAccelerationConfig,
    :WannierizationFiniteDifferenceStencil,
    :WannierizationFixedSubspace,
    :WannierGaugeChainDiagnosticConfig,
    :WannierGaugeChainDiagnosticResult,
    :WannierGaugeLinkDiagnostics,
    :WannierizationIteration,
    :WannierizationIterationDiagnostics,
    :WannierInitializationKPointDiagnostic,
    :WannierInitializationReport,
    :WannierizationOptimizerState,
    :WannierizationRestartState,
    :WannierizationArtifacts,
    :WannierizationResult,
    :WannierizationStatus,
    :WannierNNKP,
    :WannierProjectorComparison,
    :build_wannier_tight_binding_model,
    :qualify_exported_wannierization_tb,
    :classify_wannierization_u_periodicity,
    :construct_symmetry_adapted_wannier_functions,
    :diagnose_wannier_gauge_chain,
    :prepare_band_representation,
    :generate_wannier_amn,
    :generate_qe_paw_matrix_elements,
    :generate_vasp_paw_matrix_elements,
    :evaluate_full_3d_wannier_spreads,
    :validate_band_representation_compatibility,
    :read_wannier_nnkp,
    :read_wannierization_checkpoint_hdf5,
    :read_wannierization_fixed_subspace_hdf5,
    :write_wannierization_checkpoint_hdf5,
    :write_wannierization_fixed_subspace_hdf5,
    :write_wannierization_u_convergence_diagnostics_hdf5,
])

const FROZEN_WANNIERIZATION_API_ADDITIONS_20260820_AUGMENTATION_AWARE_SEWING = Set([
    :AbstractWannierInitializationBackend,
    :AbstractBandSewingBackend,
    :AbstractAuthoritativeHamiltonian,
    :AbstractDiscreteHamiltonianCorrection,
    :AbstractPAWBlockPartitionPolicy,
    :AbstractWavefunctionGaugeBackend,
    :AdaptiveEvidencePAWBlockPartition,
    :AMNExactFrozenInitialization,
    :HamiltonianWeightedPAWBlockPartition,
    :AugmentationAwareSewing,
    :ClosureDrivenBandBuffer,
    :ControlledHamiltonianSymmetryThresholds,
    :CoefficientMappingSewing,
    :DisentanglementState,
    :FixedGapPAWBlockPartition,
    :FarBandCovarianceCorrection,
    :FrozenTargetComplementCompletion,
    :NativeEigenstateGauge,
    :NativeDFTHamiltonian,
    :NoDiscreteHamiltonianCorrection,
    :PAWBlockPartitionAuditConfig,
    :PAWBlockPartitionAuditResult,
    :PAWCancellationStabilityThresholds,
    :PAWGaugeThresholds,
    :PAWHamiltonianResidualThresholds,
    :PAWSCDMInitialization,
    :PAWSCDMInputArtifact,
    :PAWSewingThresholds,
    :StarCovariantPAWGauge,
    :SymmetryCompletedQEPAWMatrices,
    :SymmetryCovariantWavefunctionPreparationConfig,
    :SymmetryCovariantWavefunctionPreparationResult,
    :SymmetrizedDFTHamiltonian,
    :TargetSubspaceQualificationContract,
    :ProjectabilityDisentanglementInitialization,
    :WannierizationMultiStartConfig,
    :WannierizationNumericalThresholds,
    :SMVFletcherReevesTwoStageAuditThresholds,
    :smv_fletcher_reeves_two_stage_audit_contract_sha256,
    :smv_fletcher_reeves_two_stage_audit,
    :generate_symmetry_completed_qe_paw_matrix_elements,
    :audit_paw_block_partitions,
    :prepare_symmetry_covariant_wavefunctions,
    :prepare_paw_scdm_input_artifact,
    :read_paw_scdm_input_artifact,
    :generate_vasp_paw_spn,
])

const FROZEN_WANNIERIZATION_API_ADDITIONS_20260825_UIU = Set([
    :ExactWannierOperatorBundleConfig,
    :ExactWannierOperatorBundleResult,
    :WannierUIUGenerationConfig,
    :WannierUIUGenerationResult,
    :WannierUIUGenerationThresholds,
    :WannierUIUParityMetrics,
    :generate_wannier_uiu,
    :prepare_exact_wannier_operator_bundle,
])

const FROZEN_WANNIERIZATION_API_ADDITIONS_20260830_OPERATOR_PROFILES = Set([
    :QEPAWSPNResult,
    :WannierHamiltonianOperatorGenerationConfig,
    :WannierHamiltonianOperatorGenerationResult,
    :WannierOperatorTargetContract,
    :wannier_operator_target_contract_sha256,
    :prepare_wannier_operator_target_contract,
    :generate_qe_paw_spn,
    :generate_wannier_uhu,
    :generate_wannier_shu,
    :generate_wannier_siu,
])

const FROZEN_WANNIERIZATION_API_ADDITIONS_20260830_PROJECTION_REPRESENTATION_SEARCHER = Set([
    :ProjectionCandidateSpec,
    :ProjectionRepresentationCompatibilityInfo,
    :ProjectionRepresentationSearchConfig,
    :ProjectionRepresentationSearchResult,
    :ProjectionRepresentationSearchStatus,
    :ProjectionRepresentationSearchThresholds,
    :ProjectionRepresentationSignature,
    :ProjectionRepresentationSolution,
    :ProjectionRepresentationValidationStatus,
    :materialize_projection_basis,
    :materialize_symmetry_adapted_wannierization_config,
    :read_projection_representation_search_hdf5,
    :search_projection_representations,
    :write_projection_representation_search_hdf5,
])

const WANNIERIZATION_QUALIFIED_CONFIG_API_20260902 = Set([
    :WannierizationInputConfig,
    :WannierizationSolverConfig,
    :WannierizationCheckpointConfig,
    :WannierizationRuntimeConfig,
    :WannierizationOutputConfig,
])

const WANNIERIZATION_FACADE_API_20260901 = Set([
    :Wannierization,
    :SymmetryAdaptedWannierizationConfig,
    :WannierizationResult,
    :construct_symmetry_adapted_wannier_functions,
])

const WANNIERIZATION_QUALIFIED_EXPERT_API_20260901 = union(
    FROZEN_WANNIERIZATION_API_20260819_Z_U_FOURIER_DIAGNOSTICS,
    FROZEN_WANNIERIZATION_API_ADDITIONS_20260820_AUGMENTATION_AWARE_SEWING,
    FROZEN_WANNIERIZATION_API_ADDITIONS_20260825_UIU,
    FROZEN_WANNIERIZATION_API_ADDITIONS_20260830_OPERATOR_PROFILES,
    FROZEN_WANNIERIZATION_API_ADDITIONS_20260830_PROJECTION_REPRESENTATION_SEARCHER,
    WANNIERIZATION_QUALIFIED_CONFIG_API_20260902,
)

const FROZEN_TASK_CONFIG_FIELDS_NATIVE_001 = (
    :tasks,
    :k_mesh,
    :fourier_backend,
    :NKdiv,
    :NKFFT,
    :photon_energies,
    :fermi_energy,
    :temperature,
    :broadening,
    :broadening_type,
    :transition_window_factor,
    :denominator_regularization,
    :spatial_dimension,
    :band_window_size,
    :tensor_indices,
    :band_selection,
    :include_occupied_sum,
    :kslice_origin,
    :kslice_vector_1,
    :kslice_vector_2,
    :kpath_nodes,
    :kpoints_per_segment,
    :real_space_replica_policy,
    :wsvec_file,
    :mp_grid,
    :wigner_seitz_tolerance,
    :wigner_seitz_search_size,
    :band_hermiticity_tolerance,
    :photon_momentum,
    :finite_difference_step,
    :wannier_center_convention,
    :degeneracy_threshold,
    :model_file,
    :real_space_operator_bundle_file,
    :seedname,
    :case_root,
    :system_name,
    :output_root,
    :spin_enabled,
    :spin_file,
    :checkpoint_file,
    :spin_file_formatted,
    :response_symmetry_file,
    :response_symmetry_policy,
    :response_symmetry_kmesh_mode,
    :response_symmetry_report_enabled,
    :response_output_digits,
    :progress_enabled,
    :progress_percent_interval,
    :progress_verbosity,
)

@testset "Geometric block-covariant expert API snapshot 2026-08-05" begin
    @test Set(names(WannierNLQG.Responses; all = false, imported = false)) ==
          FROZEN_RESPONSES_API_20260805_GEOMETRIC_BLOCK_COVARIANT
    @test Set(names(WannierNLQG.Runtime; all = false, imported = false)) == union(
        FROZEN_RUNTIME_API_20260718,
        Set([
            :compile_task_config,
            :compile_task_configs,
            :task_parameter_summary,
            :EffectiveTaskConfig,
            :NormalizedTaskSpec,
            :ModelInput,
            :BZMesh,
            :KSlice,
            :KPath,
            :ExecutionOptions,
            :OutputOptions,
            :OpticalParameters,
            :FiniteQOpticalParameters,
            :GeometryParameters,
            :BandParameters,
            :OpticalNumerics,
            :GeometryNumerics,
            :BandNumerics,
            :BandTargets,
            :Subspace,
            :Subspaces,
            :OccupiedBands,
            :AllBands,
            :Transition,
            :InterbandGroups,
            :TripleGroups,
            :TensorComponent,
            :FullTensor,
            :KSliceSelection,
        ]),
    )
end

@testset "Operator gauge and qualification config fields 2026-08-30" begin
    module_under_test = WannierNLQG.Wannierization
    @test :construction_policy in fieldnames(module_under_test.WannierUIUGenerationConfig)
    @test :authoritative_hamiltonian in fieldnames(module_under_test.WannierUIUGenerationConfig)
    @test :wavefunction_gauge_hdf5 in fieldnames(module_under_test.WannierUIUGenerationConfig)
    @test :spn_provenance_file in
          fieldnames(module_under_test.WannierHamiltonianOperatorGenerationConfig)
    @test :construction_policy in
          fieldnames(module_under_test.WannierHamiltonianOperatorGenerationConfig)
    @test fieldnames(module_under_test.SymmetryAdaptedWannierizationConfig) ==
          (:input, :solver, :checkpoint, :runtime, :output)
    output_fields = fieldnames(module_under_test.WannierizationOutputConfig)
    @test :spn_provenance_file in output_fields
    @test :spin_family_covariance_tolerance in output_fields
    @test :spin_family_idempotence_tolerance in output_fields
end

@testset "v2 operator-bundle API snapshot 2026-08-03" begin
    @test Set(names(WannierNLQG.Symmetrization; all = false, imported = false)) ==
          FROZEN_SYMMETRIZATION_API_20260802_UNIFIED
    for name in (:RealSpaceOperatorKind, :RealSpaceOperatorSymmetrySpec, :RealSpaceOperator)
        @test isdefined(WannierNLQG.Core, name)
    end
    for name in (:CrystalStructure, :SymmetryOperation, :WannierSymmetryPlan)
        @test !isdefined(WannierNLQG.Core, name)
    end
    for name in
        (:WannierWinData, :read_wannier_win, :read_qe_magnetic_moments, :read_vasp_magnetic_moments)
        @test !isdefined(WannierNLQG.IO, name)
    end
    @test isdefined(WannierNLQG.IO, :write_real_space_operator_bundle)
    @test isdefined(WannierNLQG.IO, :read_real_space_operator_bundle_manifest)
    @test isdefined(WannierNLQG.IO, :WannierAMN)
    @test isdefined(WannierNLQG.IO, :read_wannier_amn)
    @test isdefined(WannierNLQG.IO, :write_wannier_amn)
    @test isdefined(WannierNLQG.IO, :write_wannier_spn)
    @test isdefined(WannierNLQG.IO, :WannierNNKP)
    @test isdefined(WannierNLQG.IO, :read_wannier_nnkp)
    @test isdefined(WannierNLQG.MatrixElements, :WannierDerivativeOperatorSet)
    @test isdefined(WannierNLQG.MatrixElements, :construct_wannier_derivative_operators)
    @test !isdefined(WannierNLQG.Symmetrization, :WannierDerivativeOperatorSet)
    @test !isdefined(WannierNLQG.Wannierization, :WannierDerivativeOperatorSet)
end

@testset "dual shared-layer API and breaking migration 2026-09-01" begin
    @test Set(names(WannierNLQG.SymmetryFoundation; all = false, imported = false)) ==
          SYMMETRY_FOUNDATION_API_20260901
    @test Set(names(WannierNLQG.WannierProjection; all = false, imported = false)) ==
          WANNIER_PROJECTION_API_20260901
    migrated_foundation = (
        :AbstractWavefunctionSource,
        :BandRepresentation,
        :BandRepresentationQualificationScope,
        :CrystalStructure,
        :MagneticSymmetryInventory,
        :QuantumEspressoWavefunctionSource,
        :RepresentationRawDiagnostic,
        :SymmetryOperation,
        :VASPBandRepresentationConfig,
        :VASPWavefunctionSource,
        :WannierSymmetryPlan,
        :detect_magnetic_symmetry_inventory,
        :detect_symmetry_operations,
        :generate_vasp_band_representation,
        :maximum_real_space_covariance_error,
        :read_band_representation_hdf5,
        :symmetrize_real_space_operator,
        :write_band_representation_hdf5,
    )
    migrated_projection = (
        :ProjectionRadialTransformConfig,
        :ProjectionSpec,
        :WannierProjectionBasis,
        :WannierProjectionBlock,
        :build_wannier_projection_basis,
        :build_wannier_symmetry_plan,
        :projection_orbital_values,
    )
    for old_module in (WannierNLQG.Symmetrization, WannierNLQG.Wannierization)
        for name in (migrated_foundation..., migrated_projection...)
            @test !isdefined(old_module, name)
        end
    end
end

@testset "Narrow Wannierization facade and qualified expert API 2026-09-01" begin
    actual_wannierization_api =
        Set(names(WannierNLQG.Wannierization; all = false, imported = false))
    @test actual_wannierization_api == WANNIERIZATION_FACADE_API_20260901
    for name in WANNIERIZATION_QUALIFIED_EXPERT_API_20260901
        @test isdefined(WannierNLQG.Wannierization, name)
    end
    @test Set(names(WannierNLQG; all = false, imported = false)) == Set([
        :WannierNLQG,
        :TaskConfig,
        :TaskSpec,
        :RunResult,
        :run,
        :ModelInput,
        :BZMesh,
        :KSlice,
        :KPath,
        :ExecutionOptions,
        :OutputOptions,
        :OpticalParameters,
        :FiniteQOpticalParameters,
        :GeometryParameters,
        :BandParameters,
        :OpticalNumerics,
        :GeometryNumerics,
        :BandNumerics,
        :BandTargets,
        :Subspace,
        :Subspaces,
        :OccupiedBands,
        :AllBands,
        :Transition,
        :InterbandGroups,
        :TripleGroups,
        :TensorComponent,
        :FullTensor,
        :KSliceSelection,
    ])
end

@testset "Ordinary SMV-FR audit public API 2026-08-26" begin
    module_under_test = WannierNLQG.Wannierization
    @test isdefined(module_under_test, :SMVFletcherReevesTwoStageAuditThresholds)
    @test isdefined(module_under_test, :smv_fletcher_reeves_two_stage_audit)
    @test isdefined(module_under_test, :smv_fletcher_reeves_two_stage_audit_contract_sha256)
    removed_threshold_type = Symbol("Wannier", "90ReferenceParityThresholds")
    removed_manifest_name = Symbol("wannier", "90_reference_qualification_manifest")
    @test !isdefined(module_under_test, removed_threshold_type)
    @test !isdefined(module_under_test, removed_manifest_name)
end

@testset "Target-subspace Hamiltonian authority API 2026-08-28" begin
    module_under_test = WannierNLQG.Wannierization
    @test isdefined(module_under_test, :SymmetrizedDFTHamiltonian)
    for removed in (
        Symbol("Symmetrized", "HamiltonianCandidate"),
        Symbol("Symmetrized", "TargetSubspaceCandidate"),
        Symbol("Symmetrized", "Hamiltonian"),
    )
        @test !isdefined(module_under_test, removed)
    end

    authority = module_under_test.SymmetrizedDFTHamiltonian()
    @test module_under_test.authoritative_hamiltonian_key(authority) ==
          "symmetrized_dft_hamiltonian"
    @test authority.qualification_scope == :target_subspace
    @test authority.auxiliary_parent_qualification == :audit_only
    @test authority.residual_gate_phase == :post_symmetrization
    @test authority.native_difference_qualification == :audit_only

    outer = BitMatrix([true true; true true; true false; false true])
    frozen = BitMatrix([true true; false true; false false; false false])
    scope = WannierNLQG.SymmetryFoundation.BandRepresentationQualificationScope(outer, frozen)
    contract = module_under_test.TargetSubspaceQualificationContract(
        scope;
        outer_min_ev = -18.0,
        outer_max_ev = 3.5,
        frozen_min_ev = -18.0,
        frozen_max_ev = 0.5,
        num_wannier = 2,
    )
    @test contract.authority == :outer_window
    @test contract.parent_audit_policy == :audit_only
    @test contract.qualification_scope.outer_mask_sha256 ==
          WannierNLQG.SymmetryFoundation.qualification_mask_sha256(outer)
    @test contract.target_anchor_maximum_drift_ev == 0.0
    @test contract.target_complement_maximum_element_ev == 5.0e-6
    @test contract.scoped_paw_thresholds.target_leakage_weight == 5.0e-6
    @test occursin(r"^[0-9a-f]{64}$", contract.contract_sha256)

    qualification = module_under_test.TBSymmetryQualification(
        "NOT_RUN",
        "TB_NOT_AVAILABLE",
        module_under_test.TBSymmetryMetric[];
        authoritative_hamiltonian = "symmetrized_dft_hamiltonian",
        energy_shift_qualification = "audit_only",
        residual_gate_phase = "post_symmetrization",
        native_difference_qualification = "audit_only",
        qualification_scope = "target_subspace",
        target_anchor = "completed_symmetrized_target",
        auxiliary_parent_qualification = "audit_only",
        target_leakage_semantics = module_under_test.TB_TARGET_LEAKAGE_WEIGHT_SEMANTICS,
        target_leakage_formula_sha256 = module_under_test.TB_TARGET_LEAKAGE_WEIGHT_FORMULA_SHA256,
        target_leakage_threshold = 5.0e-6,
    )
    @test qualification.schema_version == "1.7"
    @test qualification.authoritative_hamiltonian == "symmetrized_dft_hamiltonian"
    @test qualification.target_leakage_threshold == 5.0e-6
    @test length(qualification.payload_sha256) == 64

    for legacy_key in ("symmetrized_hamiltonian_candidate", "symmetrized_target_subspace_candidate")
        error = try
            WannierNLQG.SymmetryFoundation.validate_authoritative_hamiltonian_key(legacy_key)
            nothing
        catch caught
            caught
        end
        @test error isa ArgumentError
        @test occursin("UNSUPPORTED_LEGACY_AUTHORITY", sprint(showerror, error))
    end
end

@testset "Grouped response configuration API 2026-09-07" begin
    @test fieldnames(WannierNLQG.TaskConfig) == (:model, :sampling, :tasks, :execution, :output)
    @test fieldnames(WannierNLQG.TaskSpec) ==
          (:id, :quantity, :method, :physics, :numerics, :observable)
    @test fieldnames(WannierNLQG.Runtime.EffectiveTaskConfig) ==
          FROZEN_TASK_CONFIG_FIELDS_NATIVE_001
    @test :basis_correction_enabled ∉ fieldnames(WannierNLQG.ModelInput)
    @test WannierNLQG.ModelInput().wannier_center_convention == "Convention_II"
    @test !isdefined(WannierNLQG, :EffectiveTaskConfig)
    @test !isdefined(WannierNLQG, :NormalizedTaskSpec)
    @test_throws Exception WannierNLQG.TaskConfig(fourier_backend = "direct")
end
