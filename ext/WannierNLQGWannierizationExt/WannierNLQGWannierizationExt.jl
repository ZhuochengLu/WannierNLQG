module WannierNLQGWannierizationExt

include("components/WannierizationInternalSupport.jl")

include("components/RepresentationPreparation.jl")
include("components/ProjectionSearch.jl")
include("components/PAWMatrixElements.jl")
include("components/SolverCheckpoint.jl")
include("components/OperatorExport.jl")
include("components/WorkflowOrchestration.jl")

const ENTRYPOINT_OWNERS = Dict{Symbol, Module}(
    :audit_paw_block_partitions => PAWMatrixElements,
    :construct_symmetry_adapted_wannier_functions => WorkflowOrchestration,
    :prepare_band_representation => WorkflowOrchestration,
    :prepare_wannier_operator_target_contract => WorkflowOrchestration,
    :prepare_symmetry_covariant_wavefunctions => PAWMatrixElements,
    :prepare_paw_scdm_input_artifact => PAWMatrixElements,
    :read_paw_scdm_input_artifact => PAWMatrixElements,
    :generate_wannier_amn => RepresentationPreparation,
    :generate_vasp_paw_matrix_elements => PAWMatrixElements,
    :generate_vasp_paw_spn => PAWMatrixElements,
    :generate_qe_paw_spn => PAWMatrixElements,
    :read_vasp_paw_spn_provenance => PAWMatrixElements,
    :read_qe_paw_spn_provenance => PAWMatrixElements,
    :generate_qe_paw_matrix_elements => PAWMatrixElements,
    :generate_symmetry_completed_qe_paw_matrix_elements => PAWMatrixElements,
    :generate_wannier_uiu => PAWMatrixElements,
    :prepare_exact_wannier_operator_bundle => OperatorExport,
    :generate_wannier_uhu => OperatorExport,
    :generate_wannier_shu => OperatorExport,
    :generate_wannier_siu => OperatorExport,
    :read_wannierization_checkpoint_hdf5 => SolverCheckpoint,
    :write_wannierization_checkpoint_hdf5 => SolverCheckpoint,
    :read_wannierization_fixed_subspace_hdf5 => SolverCheckpoint,
    :write_wannierization_fixed_subspace_hdf5 => SolverCheckpoint,
    :classify_wannierization_u_periodicity => SolverCheckpoint,
    :evaluate_full_3d_wannier_spreads => SolverCheckpoint,
    :smv_fletcher_reeves_two_stage_audit => SolverCheckpoint,
    :smv_fletcher_reeves_two_stage_audit_contract_sha256 => SolverCheckpoint,
    :write_wannierization_u_convergence_diagnostics_hdf5 => SolverCheckpoint,
    :build_wannier_tight_binding_model => OperatorExport,
    :AuthoritativeBandHamiltonian => OperatorExport,
    :authoritative_band_hamiltonian => OperatorExport,
    :qualify_exported_wannierization_tb => OperatorExport,
    :diagnose_wannier_gauge_chain => OperatorExport,
    :search_projection_representations => ProjectionSearch,
    :read_projection_representation_search_hdf5 => ProjectionSearch,
    :write_projection_representation_search_hdf5 => ProjectionSearch,
    :materialize_projection_basis => ProjectionSearch,
    :materialize_symmetry_adapted_wannierization_config => ProjectionSearch,
    :sha256_file => WannierizationInternalSupport,
    :validate_band_representation_compatibility => RepresentationPreparation,
)

const TEST_ENTRYPOINT_OWNERS = Dict{Symbol, Module}(
    :_complete_window_indices => WannierizationInternalSupport,
    :_hungarian_maximum_assignment => WannierizationInternalSupport,
    :_target_representation => WannierizationInternalSupport,
    :_block_alignment_unitary => RepresentationPreparation,
    :_build_representation_product_table => RepresentationPreparation,
    :_classify_wannier_gauge_chain_cause => RepresentationPreparation,
    :_common_degeneracy_blocks => RepresentationPreparation,
    :_compare_wannier_projectors => RepresentationPreparation,
    :_effective_wannierization_algorithms => RepresentationPreparation,
    :_effective_wannierization_mode => RepresentationPreparation,
    :_gauge_transform_sewing => RepresentationPreparation,
    :_group_law_combination_index => RepresentationPreparation,
    :_match_symmetry_operations => RepresentationPreparation,
    :_paired_matrix_residual_metrics => RepresentationPreparation,
    :_representation_static_sha256 => RepresentationPreparation,
    :_stable_subspace_alignment => RepresentationPreparation,
    :_symmetry_constraints_applied => RepresentationPreparation,
    :_validate_band_representation_preparation_config => RepresentationPreparation,
    :_validate_symmetry_covariant_wavefunction_preparation_config => RepresentationPreparation,
    :_validate_target_operation_inventory => RepresentationPreparation,
    :_validate_wannierization_config => RepresentationPreparation,
    :_wannier_gauge_link_diagnostics => RepresentationPreparation,
    :_acceleration_trial_action => SolverCheckpoint,
    :_accepted_unitary_displacement => SolverCheckpoint,
    :_adaptive_next_mixing => SolverCheckpoint,
    :_amn_target_qualification_metrics => SolverCheckpoint,
    :_anderson_trial_policy => SolverCheckpoint,
    :_anderson_z_proposal => SolverCheckpoint,
    :_backtracking_step_scale => SolverCheckpoint,
    :_best_fletcher_reeves_finite_descent => SolverCheckpoint,
    :_build_target_symmetry_tangent_plans => SolverCheckpoint,
    :_candidate_invariant_failure => SolverCheckpoint,
    :_candidate_invariant_residuals => SolverCheckpoint,
    :_centers_spreads_and_directions => SolverCheckpoint,
    :_complete_selected_subspace_star => SolverCheckpoint,
    :_complex_field_sha256 => SolverCheckpoint,
    :_corepresentation_aware_maximum_subspace_result => SolverCheckpoint,
    :_deterministic_sealed_subspace_perturbation => SolverCheckpoint,
    :_disentanglement_candidate => SolverCheckpoint,
    :_evaluate_full_mesh_centers_spreads_and_directions => SolverCheckpoint,
    :_evaluate_mv_localization => SolverCheckpoint,
    :_expand_ibz_frames => SolverCheckpoint,
    :_expand_ibz_target_tangents => SolverCheckpoint,
    :_finite_difference_weights => SolverCheckpoint,
    :_fixed_subspace_initial_frames => SolverCheckpoint,
    :_fixed_subspace_projector_drift_tolerance => SolverCheckpoint,
    :_frame_geodesic_distance => SolverCheckpoint,
    :_frozen_indices => SolverCheckpoint,
    :_frozen_target_embedding => SolverCheckpoint,
    :_global_permutation_phase_diagnostic => SolverCheckpoint,
    :_initial_frames => SolverCheckpoint,
    :_initial_frames_with_diagnostics => SolverCheckpoint,
    :_initial_wannier_centers => SolverCheckpoint,
    :_is_complete_outer_space => SolverCheckpoint,
    :_legacy_initial_frames => SolverCheckpoint,
    :_localization_backtracking_limit => SolverCheckpoint,
    :_localization_directional_derivative => SolverCheckpoint,
    :_localization_objective_accepts => SolverCheckpoint,
    :_localization_svd_polar => SolverCheckpoint,
    :_localization_sweep_entry_count => SolverCheckpoint,
    :_maximum_projector_covariance_error => SolverCheckpoint,
    :_maximum_projector_drift => SolverCheckpoint,
    :_maximum_projector_step => SolverCheckpoint,
    :_maximum_subspace => SolverCheckpoint,
    :_maximum_subspace_result => SolverCheckpoint,
    :_maximum_target_frame_symmetry_error => SolverCheckpoint,
    :_mesh_neighbor_displacement => SolverCheckpoint,
    :_minimum_diagonal_phase_margin => SolverCheckpoint,
    :_minimum_norm_clarke_combination => SolverCheckpoint,
    :_minimum_z_boundary_gap => SolverCheckpoint,
    :_mix_unitaries => SolverCheckpoint,
    :_mix_z_fields => SolverCheckpoint,
    :_mv_centered_full_mesh_centers_spreads_and_directions => SolverCheckpoint,
    :_mv_centered_gradient_data => SolverCheckpoint,
    :_mv_generalized_directional_derivative => SolverCheckpoint,
    :_mv_localization_phase => SolverCheckpoint,
    :_mv_spread_gradient => SolverCheckpoint,
    :_objective_aware_anderson_decision => SolverCheckpoint,
    :_orthonormalize_columns => SolverCheckpoint,
    :_orthonormalize_columns_result => SolverCheckpoint,
    :_pack_complex_real => SolverCheckpoint,
    :_polar_retracted_tangent_step => SolverCheckpoint,
    :_polar_retraction_curve_velocity => SolverCheckpoint,
    :_project_target_symmetry_tangent => SolverCheckpoint,
    :_projector_covariance_tolerance => SolverCheckpoint,
    :_qualify_nonconverged_disentanglement_state => SolverCheckpoint,
    :_rank_gated_polar_columns => SolverCheckpoint,
    :_rank_gated_svd_polar_columns => SolverCheckpoint,
    :_raw_amn_localization_reference => SolverCheckpoint,
    :_raw_z_field => SolverCheckpoint,
    :_record_terminal_state! => SolverCheckpoint,
    :_reduce_full_star_hermitian_field => SolverCheckpoint,
    :_repair_expanded_frozen_frame => SolverCheckpoint,
    :_representation_target_subspace_contract => SolverCheckpoint,
    :_restart_config_repr => SolverCheckpoint,
    :_restart_config_sha256 => SolverCheckpoint,
    :_restart_config_sha256_pre_v2_11 => SolverCheckpoint,
    :_restart_config_sha256_pre_v2_6 => SolverCheckpoint,
    :_restart_config_sha256_pre_v2_7 => SolverCheckpoint,
    :_restart_matrix_field => SolverCheckpoint,
    :_restore_expanded_frames_to_subspaces => SolverCheckpoint,
    :_riemannian_lbfgs_direction => SolverCheckpoint,
    :_rotate_hermitian_field_entry => SolverCheckpoint,
    :_rotate_localized_overlap_state => SolverCheckpoint,
    :_sealed_amn_polar => SolverCheckpoint,
    :_select_wannierization_multistart => SolverCheckpoint,
    :_shrunken_acceleration_mixing => SolverCheckpoint,
    :_solve_symmetry_adapted_wannierization => SolverCheckpoint,
    :_symmetry_projected_spread_gradient => SolverCheckpoint,
    :_target_symmetry_tangent_plan => SolverCheckpoint,
    :_transport_selected_subspace_corepresentation => SolverCheckpoint,
    :_unitary_geodesic_plan => SolverCheckpoint,
    :_unitary_geodesic_step => SolverCheckpoint,
    :_unpack_complex_real => SolverCheckpoint,
    :_validate_hermitian_eigensystem => SolverCheckpoint,
    :_validated_hermitian_spectrum => SolverCheckpoint,
    :_wannier90_reference_amn_polar => SolverCheckpoint,
    :_wannier90_reference_b_cartesian => SolverCheckpoint,
    :_wannier90_reference_complex_exponential => SolverCheckpoint,
    :_wannier90_reference_dis_project => SolverCheckpoint,
    :_wannier90_reference_edge_b_cartesian => SolverCheckpoint,
    :_wannier90_reference_finite_difference_weights => SolverCheckpoint,
    :_wannier90_reference_gfortran_column_conjugate_product => SolverCheckpoint,
    :_wannier90_reference_gfortran_column_division => SolverCheckpoint,
    :_wannier90_reference_gfortran_complex_product => SolverCheckpoint,
    :_wannier90_reference_gfortran_magnitude_squared => SolverCheckpoint,
    :_wannier90_reference_gfortran_phase_column_product => SolverCheckpoint,
    :_wannier90_reference_gfortran_scalar_magnitude_squared => SolverCheckpoint,
    :_wannier90_reference_gradient_center_accumulate => SolverCheckpoint,
    :_wannier90_reference_invariant_spread => SolverCheckpoint,
    :_wannier90_reference_maximum_subspace_result => SolverCheckpoint,
    :_wannier90_reference_objective_center_accumulate => SolverCheckpoint,
    :_wannier90_reference_omega_d_accumulate => SolverCheckpoint,
    :_wannier90_reference_optimal_step => SolverCheckpoint,
    :_wannier90_reference_phase => SolverCheckpoint,
    :_wannier90_reference_search_direction => SolverCheckpoint,
    :_wannier90_reference_unitary_step => SolverCheckpoint,
    :_wannier90_reference_weight_total => SolverCheckpoint,
    :_wannier90_reference_zdot => SolverCheckpoint,
    :_wannier90_reference_zgemm => SolverCheckpoint,
    :_wannier90_reference_zhpevx => SolverCheckpoint,
)

isempty(intersect(keys(ENTRYPOINT_OWNERS), keys(TEST_ENTRYPOINT_OWNERS))) ||
    error("Wannierization public and test bridge ownership maps overlap")
const BRIDGE_ENTRYPOINT_OWNERS = merge(ENTRYPOINT_OWNERS, TEST_ENTRYPOINT_OWNERS)

for (name, owner) in ENTRYPOINT_OWNERS
    @eval const $name = getfield($owner, $(QuoteNode(name)))
end

# White-box restart-digest tests retain this non-facade binding without making
# component namespaces part of the public expert entrypoint table.
const WannierizationRestartContract = SolverCheckpoint.WannierizationRestartContract

"""Resolve one expert entrypoint to its unique owning component."""
resolve_wannierization_entrypoint(name::Symbol) = getfield(
    get(BRIDGE_ENTRYPOINT_OWNERS, name) do
        throw(ArgumentError("Wannierization entrypoint $(name) has no component owner"))
    end,
    name,
)

export construct_symmetry_adapted_wannier_functions
export prepare_band_representation
export prepare_symmetry_covariant_wavefunctions
export prepare_paw_scdm_input_artifact, read_paw_scdm_input_artifact
export generate_wannier_amn
export generate_vasp_paw_matrix_elements
export generate_vasp_paw_spn
export generate_qe_paw_spn
export read_vasp_paw_spn_provenance
export read_qe_paw_spn_provenance
export generate_qe_paw_matrix_elements
export generate_symmetry_completed_qe_paw_matrix_elements
export generate_wannier_uiu, prepare_exact_wannier_operator_bundle
export generate_wannier_uhu, generate_wannier_shu, generate_wannier_siu
export read_wannierization_checkpoint_hdf5, write_wannierization_checkpoint_hdf5
export read_wannierization_fixed_subspace_hdf5, write_wannierization_fixed_subspace_hdf5
export write_wannierization_u_convergence_diagnostics_hdf5
export build_wannier_tight_binding_model
export AuthoritativeBandHamiltonian, authoritative_band_hamiltonian
export qualify_exported_wannierization_tb
export diagnose_wannier_gauge_chain
export search_projection_representations
export read_projection_representation_search_hdf5
export write_projection_representation_search_hdf5
export materialize_projection_basis
export materialize_symmetry_adapted_wannierization_config

end
