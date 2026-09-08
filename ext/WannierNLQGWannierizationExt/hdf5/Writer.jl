# Store initialization spectra as bounded matrices plus explicit valid lengths;
# this keeps schema-2.2 machine-readable without variable-length string payloads.
function _write_initialization_report(parent, report, num_wannier::Int)
    group = HDF5.create_group(parent, "initialization")
    attributes = HDF5.attributes(group)
    if report === nothing
        attributes["algorithm"] = "UNKNOWN"
        attributes["algorithm_version"] = "NOT_RECORDED"
        attributes["status"] = "NOT_RECORDED"
        attributes["kpoint_count"] = 0
        return nothing
    end
    evidence = something(report)
    attributes["algorithm"] = String(evidence.algorithm)
    attributes["algorithm_version"] = evidence.algorithm_version
    attributes["status"] = String(evidence.status)
    attributes["kpoint_count"] = length(evidence.kpoints)
    num_kpoints = length(evidence.kpoints)
    group["kpoint"] = Int[diagnostic.kpoint for diagnostic in evidence.kpoints]
    spectrum_fields = (
        :full_amn_singular_values,
        :outer_amn_singular_values,
        :frozen_amn_singular_values,
        :projected_free_singular_values,
        :alignment_singular_values,
    )
    spectra = fill(NaN, num_wannier, length(spectrum_fields), num_kpoints)
    lengths = zeros(Int, length(spectrum_fields), num_kpoints)
    for (kpoint_index, diagnostic) in enumerate(evidence.kpoints)
        for (field_index, field) in enumerate(spectrum_fields)
            values = getproperty(diagnostic, field)
            length(values) <= num_wannier ||
                throw(DimensionMismatch("initialization spectrum exceeds num_wannier"))
            lengths[field_index, kpoint_index] = length(values)
            isempty(values) || (spectra[1:length(values), field_index, kpoint_index] .= values)
        end
    end
    group["singular_values"] = spectra
    group["singular_value_lengths"] = lengths
    HDF5.attributes(group["singular_values"])["axis_order"] = "value,field,kpoint"
    HDF5.attributes(group["singular_values"])["field_order"] = join(String.(spectrum_fields), ",")
    group["ranks_and_completions"] = reduce(
        hcat,
        [
            Int[
                diagnostic.full_amn_rank,
                diagnostic.outer_amn_rank,
                diagnostic.frozen_amn_rank,
                diagnostic.projected_free_rank,
                diagnostic.target_completion_count,
                diagnostic.band_completion_count,
            ] for diagnostic in evidence.kpoints
        ],
    )
    HDF5.attributes(group["ranks_and_completions"])["field_order"] =
        "full_amn_rank,outer_amn_rank,frozen_amn_rank,projected_free_rank," *
        "target_completion_count,band_completion_count"
    group["rank_thresholds"] = reduce(
        hcat,
        [
            Float64[
                diagnostic.full_amn_rank_threshold,
                diagnostic.outer_amn_rank_threshold,
                diagnostic.frozen_amn_rank_threshold,
                diagnostic.projected_free_rank_threshold,
            ] for diagnostic in evidence.kpoints
        ],
    )
    HDF5.attributes(group["rank_thresholds"])["field_order"] = "full_amn,outer_amn,frozen_amn,projected_free"
    group["residuals"] = reduce(
        hcat,
        [
            Float64[
                diagnostic.alignment_condition,
                diagnostic.isometry_before,
                diagnostic.isometry_after,
                diagnostic.frozen_residual_before,
                diagnostic.frozen_residual_after,
            ] for diagnostic in evidence.kpoints
        ],
    )
    HDF5.attributes(group["residuals"])["field_order"] =
        "alignment_condition,isometry_before,isometry_after," *
        "frozen_residual_before,frozen_residual_after"
    return nothing
end

# Reconstruct the typed report from schema-2.2 fixed-size diagnostic arrays.
function _read_initialization_report(parent)
    haskey(parent, "initialization") || return nothing
    group = parent["initialization"]
    attributes = HDF5.attributes(group)
    count = Int(required_attribute(group, "kpoint_count"))
    count == 0 && return nothing
    spectrum_values = Array{Float64, 3}(read(group["singular_values"]))
    lengths = Matrix{Int}(read(group["singular_value_lengths"]))
    kpoints = Int.(read(group["kpoint"]))
    ranks = Matrix{Int}(read(group["ranks_and_completions"]))
    thresholds = Matrix{Float64}(read(group["rank_thresholds"]))
    residuals = Matrix{Float64}(read(group["residuals"]))
    diagnostics = WannierInitializationKPointDiagnostic[]
    for index in 1:count
        fields = [
            Vector{Float64}(@view spectrum_values[1:lengths[field, index], field, index]) for
            field in 1:5
        ]
        push!(
            diagnostics,
            WannierInitializationKPointDiagnostic(
                kpoints[index],
                fields[1],
                fields[2],
                fields[3],
                fields[4],
                fields[5],
                ranks[1, index],
                ranks[2, index],
                ranks[3, index],
                ranks[4, index],
                ranks[5, index],
                ranks[6, index],
                thresholds[1, index],
                thresholds[2, index],
                thresholds[3, index],
                thresholds[4, index],
                residuals[1, index],
                residuals[2, index],
                residuals[3, index],
                residuals[4, index],
                residuals[5, index],
            ),
        )
    end
    return WannierInitializationReport(
        Symbol(String(required_attribute(group, "algorithm"))),
        String(required_attribute(group, "algorithm_version")),
        Symbol(String(required_attribute(group, "status"))),
        diagnostics,
    )
end

# Exact-Wannier90 identity is carried by its complete recursive M/U state.
# Periodic checkpoint views intentionally contain only a minimal input summary,
# so algorithm-name strings are not an authoritative discriminator here.
function _checkpoint_exact_wannier90_state_presence(optimizer)
    present = (
        !isempty(optimizer.wannier90_reference_overlaps),
        !isempty(optimizer.wannier90_reference_unitaries),
        isfinite(optimizer.wannier90_reference_omega_i),
    )
    all(present) ||
        !any(present) ||
        throw(ArgumentError("checkpoint exact-Wannier90 recursive state is incomplete"))
    return all(present)
end

# Wannier90 keeps `ncg=0` after the first accepted steepest-descent step and
# increments it only after a Fletcher--Reeves update.  A nonempty exact
# recursive state with `ncg=0` is therefore a valid persisted state; an RCG
# state at the same counter remains invalid.
function _checkpoint_cg_iteration_is_valid(optimizer, iteration::Int)
    iteration > 0 && return true
    return iteration == 0 && _checkpoint_exact_wannier90_state_presence(optimizer)
end

# Validate schema-2.4 fixed-subspace arrays and synchronized trial histories.
function _validate_checkpoint_fixed_subspace(result::WannierizationResult)
    result.restart_state === nothing && return nothing
    state = something(result.restart_state)
    optimizer = state.optimizer_state
    exact_reference = _checkpoint_exact_wannier90_state_presence(optimizer)
    cg_present = (!isempty(optimizer.previous_u_gradient), !isempty(optimizer.previous_u_direction))
    all(cg_present) ||
        !any(cg_present) ||
        throw(ArgumentError("checkpoint Riemannian-CG history is incomplete"))
    if all(cg_present)
        size(optimizer.previous_u_gradient) == size(optimizer.previous_u_direction) ||
            throw(DimensionMismatch("checkpoint Riemannian-CG fields disagree"))
        size(optimizer.previous_u_gradient, 3) == size(state.frames, 3) ||
            throw(DimensionMismatch("checkpoint Riemannian-CG mesh disagrees"))
        all(isfinite, optimizer.previous_u_gradient) &&
        all(isfinite, optimizer.previous_u_direction) ||
            throw(ArgumentError("checkpoint Riemannian-CG state contains NaN or Inf"))
        _checkpoint_cg_iteration_is_valid(optimizer, optimizer.u_cg_iteration) ||
            throw(ArgumentError("checkpoint Riemannian-CG history has no accepted iteration"))
    end
    lbfgs_count = length(optimizer.u_lbfgs_rho_history)
    size(optimizer.u_lbfgs_s_history, 4) == lbfgs_count == size(optimizer.u_lbfgs_y_history, 4) ||
        throw(DimensionMismatch("checkpoint L-BFGS history lengths disagree"))
    if lbfgs_count > 0
        size(optimizer.u_lbfgs_s_history) == size(optimizer.u_lbfgs_y_history) ||
            throw(DimensionMismatch("checkpoint L-BFGS S/Y fields disagree"))
        size(optimizer.u_lbfgs_s_history, 3) == size(state.frames, 3) ||
            throw(DimensionMismatch("checkpoint L-BFGS mesh disagrees"))
        all(isfinite, optimizer.u_lbfgs_s_history) &&
        all(isfinite, optimizer.u_lbfgs_y_history) &&
        all(isfinite, optimizer.u_lbfgs_rho_history) ||
            throw(ArgumentError("checkpoint L-BFGS state contains NaN or Inf"))
        all(>(0.0), optimizer.u_lbfgs_rho_history) ||
            throw(ArgumentError("checkpoint L-BFGS curvature inverse must be positive"))
    end
    optimizer.u_phase_contract == LOCALIZATION_GRADIENT_CONTRACT ||
        throw(ArgumentError("checkpoint U phase contract is incompatible"))
    trial_count = length(optimizer.localization_trial_step_scales)
    all(
        length(values) == trial_count for values in (
            optimizer.localization_trial_objectives,
            optimizer.localization_trial_required_changes,
            optimizer.localization_trial_actual_changes,
            optimizer.localization_trial_directional_derivatives,
            optimizer.localization_trial_iterations,
            optimizer.localization_trial_sweeps,
            optimizer.localization_trial_accepted,
        )
    ) || throw(DimensionMismatch("checkpoint localization-trial history lengths disagree"))
    present = (state.fixed_subspace_projectors !== nothing, state.fixed_subspace_frames !== nothing)
    all(present) ||
        !any(present) ||
        throw(ArgumentError("checkpoint fixed-subspace S/P state is incomplete"))
    if all(present)
        projectors = something(state.fixed_subspace_projectors)
        subspaces = something(state.fixed_subspace_frames)
        size(projectors, 3) == size(state.frames, 3) == size(subspaces, 3) ||
            throw(DimensionMismatch("checkpoint fixed-subspace mesh dimensions disagree"))
        all(isfinite, projectors) && all(isfinite, subspaces) ||
            throw(ArgumentError("checkpoint fixed-subspace state contains NaN or Inf"))
        boundary_residual = maximum(
            norm(
                @view(subspaces[:, :, kpoint]) * @view(subspaces[:, :, kpoint])' -
                @view(projectors[:, :, kpoint]),
            ) for kpoint in axes(subspaces, 3)
        )
        accepted_drift = maximum(
            norm(
                @view(state.frames[:, :, kpoint]) * @view(state.frames[:, :, kpoint])' -
                @view(projectors[:, :, kpoint]),
            ) for kpoint in axes(state.frames, 3)
        )
        fixed_projector_tolerance = exact_reference ? 1.0e-10 : 1.0e-12
        max(boundary_residual, accepted_drift) <= fixed_projector_tolerance || throw(
            ArgumentError(
                "checkpoint fixed-subspace projector gate failed: " *
                "boundary=$(boundary_residual), accepted=$(accepted_drift)",
            ),
        )
    end
    if state.localization_initial_frames !== nothing
        initial = something(state.localization_initial_frames)
        size(initial) == size(state.frames) ||
            throw(DimensionMismatch("checkpoint localization-initial frame dimensions disagree"))
        all(isfinite, initial) ||
            throw(ArgumentError("checkpoint localization-initial frame contains NaN or Inf"))
        dimension = size(initial, 2)
        identity_matrix = Matrix{ComplexF64}(I, dimension, dimension)
        initial_isometry = maximum(
            norm(@view(initial[:, :, kpoint])' * @view(initial[:, :, kpoint]) - identity_matrix) for kpoint in axes(initial, 3)
        )
        initial_isometry <= 1.0e-10 || throw(
            ArgumentError(
                "checkpoint localization-initial frame isometry gate failed: $(initial_isometry)",
            ),
        )
        if all(present)
            projectors = something(state.fixed_subspace_projectors)
            initial_drift = maximum(
                norm(
                    @view(initial[:, :, kpoint]) * @view(initial[:, :, kpoint])' -
                    @view(projectors[:, :, kpoint]),
                ) for kpoint in axes(initial, 3)
            )
            initial_drift <= 1.0e-12 || throw(
                ArgumentError(
                    "checkpoint localization-initial projector gate failed: $(initial_drift)",
                ),
            )
        end
    end
    if exact_reference
        overlaps = optimizer.wannier90_reference_overlaps
        unitaries = optimizer.wannier90_reference_unitaries
        num_wannier = size(state.frames, 2)
        num_kpoints = size(state.frames, 3)
        size(overlaps, 1) == num_wannier == size(overlaps, 2) ||
            throw(DimensionMismatch("checkpoint exact-Wannier90 overlap band dimensions disagree"))
        size(overlaps, 4) == num_kpoints ||
            throw(DimensionMismatch("checkpoint exact-Wannier90 overlap mesh disagrees"))
        size(unitaries) == (num_wannier, num_wannier, num_kpoints) ||
            throw(DimensionMismatch("checkpoint exact-Wannier90 unitary dimensions disagree"))
        all(isfinite, overlaps) && all(isfinite, unitaries) ||
            throw(ArgumentError("checkpoint exact-Wannier90 recursive state contains NaN or Inf"))
    end
    declared_reference =
        get(result.input_summary, "localization_algorithm", "") == "smv_fletcher_reeves_two_stage"
    if declared_reference && optimizer.phase in (:localization, :completed) && optimizer.u_steps > 0
        exact_reference || throw(
            ArgumentError(
                "RESTART_SEMANTICS_INCOMPATIBLE: exact-Wannier90 localization checkpoint lacks recursive overlap/unitary state",
            ),
        )
    end
    return nothing
end

"""Atomically persist one Wannierization result at the exact requested checkpoint path."""
function write_wannierization_checkpoint_hdf5(
    filename::AbstractString,
    result::WannierizationResult,
)
    HDF5.enable_complex_support()
    result = _checkpoint_persisted_result(result)
    validate_persisted_authority_key(
        get(result.input_summary, "authoritative_hamiltonian", "native_dft"),
    )
    get(result.input_summary, "qualification_scope", "full_parent") == "target_subspace" &&
        _validate_persisted_target_subspace_contract(result.input_summary)
    _validate_checkpoint_fixed_subspace(result)
    output_path = abspath(filename)
    endswith(output_path, ".sawf.h5") && throw(
        ArgumentError(
            "new checkpoint output rejects the legacy .sawf.h5 suffix; " *
            "use .wannierization.h5 (legacy files remain readable through restart_hdf5)",
        ),
    )
    return atomic_hdf5_write(output_path) do temporary
        HDF5.h5open(temporary, "w") do handle
            attributes = HDF5.attributes(handle)
            converged = result.status in (COMPLETED, COMPLETED_WITH_WARNINGS)
            iterations_completed = isempty(result.history) ? 0 : last(result.history).iteration
            convergence_metric =
                isempty(result.history) ? Inf : last(result.history).spread_standard_deviation
            convergence_tolerance =
                parse(Float64, get(result.input_summary, "convergence_tolerance", "Inf"))
            production_eligible = _wannierization_scoped_production_eligible(result)
            attributes["schema"] = WANNIERIZATION_CHECKPOINT_SCHEMA
            attributes["schema_version"] = WANNIERIZATION_CHECKPOINT_SCHEMA_VERSION
            attributes["status"] = string(result.status)
            attributes["checkpoint_phase"] =
                result.status == IN_PROGRESS_CHECKPOINT ? "periodic" : "terminal"
            attributes["converged"] = converged
            attributes["production_eligible"] = production_eligible
            attributes["scoped_production_eligible"] = production_eligible
            attributes["global_production_eligible"] = false
            attributes["diagnostic_only"] = !production_eligible
            attributes["stopping_reason"] = _checkpoint_stopping_reason(result)
            attributes["iterations_completed"] = iterations_completed
            attributes["convergence_metric_name"] = "center_spread_window_std_max"
            attributes["convergence_metric"] = convergence_metric
            attributes["convergence_tolerance"] = convergence_tolerance
            attributes["checkpoint_sha256"] = _wannierization_checkpoint_sha256_v1_0(result)
            attributes["algorithm_profile"] =
                get(result.input_summary, "algorithm_profile", "legacy")
            attributes["effective_algorithm_profile"] =
                get(result.input_summary, "effective_algorithm_profile", "legacy")
            attributes["smv_fletcher_reeves_two_stage_protocol"] = get(
                result.input_summary,
                "smv_fletcher_reeves_two_stage_protocol",
                "NOT_APPLICABLE",
            )
            for (key, default_value) in (
                ("smv_fletcher_reeves_two_stage_algorithm_contract_version", "legacy"),
                ("smv_fletcher_reeves_two_stage_default_selection_reason", "legacy"),
                ("smv_fletcher_reeves_two_stage_audit_standard_version", "legacy"),
                ("smv_fletcher_reeves_two_stage_audit_semantic", "legacy"),
                (
                    "smv_fletcher_reeves_two_stage_audit_accepted_step_combination_rule",
                    "NOT_APPLICABLE",
                ),
                (
                    "smv_fletcher_reeves_two_stage_audit_accepted_step_absolute_tolerance",
                    "NOT_APPLICABLE",
                ),
                (
                    "smv_fletcher_reeves_two_stage_audit_accepted_step_relative_tolerance",
                    "NOT_APPLICABLE",
                ),
                ("smv_fletcher_reeves_two_stage_audit_contract_sha256", "NOT_APPLICABLE"),
                ("smv_fletcher_reeves_two_stage_audit_status", "AUDIT_NOT_PROVIDED"),
                ("smv_fletcher_reeves_two_stage_audit_reason", "NOT_AVAILABLE"),
                ("smv_fletcher_reeves_two_stage_audit_manifest_sha256", "NOT_AVAILABLE"),
            )
                attributes[key] = get(result.input_summary, key, default_value)
            end
            attributes["z_u_stage_semantics"] = get(
                result.input_summary,
                "z_u_stage_semantics",
                "disentanglement_localization_decoupled_v1",
            )
            attributes["sewing_backend"] =
                get(result.input_summary, "sewing_backend", "coefficient_mapping")
            attributes["sewing_metric"] =
                get(result.input_summary, "sewing_metric", "pseudo_coefficient_linear_map")
            attributes["strict_sewing_diagnostics_sha256"] =
                get(result.input_summary, "strict_sewing_diagnostics_sha256", "NOT_RECORDED")
            attributes["authoritative_hamiltonian"] =
                get(result.input_summary, "authoritative_hamiltonian", "native_dft")
            attributes["authoritative_hamiltonian_sha256"] =
                get(result.input_summary, "authoritative_hamiltonian_sha256", "LEGACY_NATIVE_DFT")
            attributes["native_fidelity_status"] =
                get(result.input_summary, "native_fidelity_status", "NOT_RECORDED")
            attributes["symmetrized_hamiltonian_status"] =
                get(result.input_summary, "symmetrized_hamiltonian_status", "NOT_APPLICABLE")
            for (key, default_value) in (
                ("energy_shift_qualification", "legacy_energy_shift_hard_gate"),
                ("maximum_energy_shift_audit_reference_ev", "NOT_APPLICABLE"),
                ("rms_energy_shift_audit_reference_ev", "NOT_APPLICABLE"),
                ("target_energy_shift_audit_status", "NOT_APPLICABLE"),
                ("symmetrized_parent_energy_shift_audit_status", "NOT_APPLICABLE"),
                ("residual_gate_phase", "legacy_pre_symmetrization"),
                ("raw_preflight_diagnostic_status", "NOT_APPLICABLE"),
                ("native_difference_qualification", "legacy_hard_gate"),
                ("native_difference_audit_status", "NOT_APPLICABLE"),
                ("qualification_scope", "full_parent"),
                ("target_authority", "NOT_APPLICABLE"),
                ("parent_audit_policy", "legacy_hard_gate"),
                ("disentanglement_outer_mask_sha256", "NOT_SEALED"),
                ("disentanglement_frozen_mask_sha256", "NOT_SEALED"),
                ("target_subspace_contract_sha256", "NOT_RECORDED"),
                ("target_leakage_semantics", "LEGACY_AMPLITUDE_LEAKAGE_CONTRACT"),
                ("target_leakage_formula_sha256", "NOT_RECORDED"),
                ("target_leakage_threshold", "NOT_RECORDED"),
                ("target_anchor", "NOT_APPLICABLE"),
                ("target_complement_completion", "NOT_APPLICABLE"),
                ("target_complement_max_element_ev", "NOT_APPLICABLE"),
                ("auxiliary_parent_qualification", "legacy_hard_gate"),
                ("symmetrized_target_subspace_status", "NOT_APPLICABLE"),
                ("auxiliary_parent_audit_status", "NOT_APPLICABLE"),
                ("target_scope_production_eligible", "false"),
            )
                attributes[key] = get(result.input_summary, key, default_value)
            end
            attributes["wavefunction_gauge_backend"] =
                get(result.input_summary, "wavefunction_gauge_backend", "native_eigenstate")
            attributes["wavefunction_gauge_hdf5_sha256"] =
                get(result.input_summary, "wavefunction_gauge_hdf5_sha256", "NOT_APPLICABLE")
            attributes["block_partition_policy"] =
                get(result.input_summary, "block_partition_policy", "NOT_APPLICABLE")
            attributes["block_partition_policy_sha256"] =
                get(result.input_summary, "block_partition_policy_sha256", "NOT_APPLICABLE")
            attributes["localization_gradient_contract"] =
                result.input_summary["localization_gradient_contract"]
            attributes["joint_update_contract"] = result.input_summary["joint_update_contract"]
            attributes["disentanglement_limit_policy"] =
                result.input_summary["disentanglement_limit_policy"]
            attributes["z_seal_class"] = result.input_summary["z_seal_class"]
            attributes["qualified_z_seal"] = result.input_summary["qualified_z_seal"] == "true"
            attributes["constraint_operation_scope"] =
                result.input_summary["constraint_operation_scope"]
            attributes["constraint_operation_parent_representation_sha256"] =
                result.input_summary["constraint_operation_parent_representation_sha256"]
            attributes["constraint_operation_subgroup_sha256"] =
                result.input_summary["constraint_operation_subgroup_sha256"]
            attributes["input_sha256"] = get(result.input_summary, "input_sha256", "")
            attributes["config_sha256"] = get(result.input_summary, "restart_config_sha256", "")
            attributes["representation_sha256"] =
                get(result.input_summary, "representation_sha256", "")
            attributes["restart_complete"] = result.restart_state !== nothing
            attributes["has_wannier_chk"] = result.wannier_chk !== nothing
            attributes["has_accepted_state"] =
                get(result.input_summary, "has_accepted_state", "false") == "true"
            attributes["legacy_terminal_semantics"] =
                get(result.input_summary, "legacy_terminal_semantics", "false") == "true"
            attributes["last_attempted_iteration"] =
                parse(Int, get(result.input_summary, "last_attempted_iteration", "-1"))
            attributes["last_accepted_iteration"] =
                parse(Int, get(result.input_summary, "last_accepted_iteration", "-1"))
            attributes["last_persisted_iteration"] =
                parse(Int, get(result.input_summary, "last_persisted_iteration", "-1"))
            write_tb_symmetry_qualification_group(handle, result.tb_symmetry_qualification)
            hard_gates = HDF5.create_group(handle, "hard_gate_residuals")
            for key in sort!(
                filter(key -> startswith(key, "hard_gate_"), collect(keys(result.input_summary))),
            )
                HDF5.attributes(hard_gates)[key[11:end]] = parse(Float64, result.input_summary[key])
            end
            solution = HDF5.create_group(handle, "solution")
            solution["v_matrix"] = result.v_matrix
            solution["wannier_centers_cartesian"] = result.wannier_centers_cartesian
            solution["spreads_angstrom2"] = result.spreads_angstrom2
            if result.wannier_chk !== nothing
                chk = result.wannier_chk
                geometry = HDF5.create_group(handle, "geometry")
                geometry["mp_grid"] = collect(chk.mp_grid)
                geometry["kpoints_fractional"] = chk.kpt_red
                geometry["real_lattice"] = chk.real_lattice
                geometry["reciprocal_lattice"] = chk.recip_lattice
            end
            history = HDF5.create_group(handle, "history")
            # Explicitly materialize concrete vectors: broadcasted `getfield`
            # over a heterogeneous field tuple may infer `Vector{Real}`.
            history["iteration"] = Int[entry.iteration for entry in result.history]
            history["spread_total"] = Float64[entry.spread_total for entry in result.history]
            history["spread_standard_deviation"] =
                Float64[entry.spread_standard_deviation for entry in result.history]
            history["maximum_covariance_error"] =
                Float64[entry.maximum_covariance_error for entry in result.history]
            iteration_count = length(result.history)
            directional = fill(NaN, 3, iteration_count)
            diagnostic_values = fill(NaN, 25, iteration_count)
            diagnostic_integers = zeros(Int, 10, iteration_count)
            diagnostic_flags = zeros(UInt8, 3, iteration_count)
            anderson_reasons = fill("NOT_RECORDED", iteration_count)
            cg_restart_reasons = fill("NOT_RECORDED", iteration_count)
            joint_acceptance_reasons = fill("NOT_RECORDED", iteration_count)
            for (index, entry) in enumerate(result.history)
                entry.diagnostics === nothing && continue
                values = something(entry.diagnostics)
                values.omega_directional === nothing ||
                    (directional[:, index] .= collect(something(values.omega_directional)))
                diagnostic_values[:, index] .= (
                    values.omega_total,
                    values.projector_residual,
                    values.z_residual,
                    values.u_residual,
                    values.wcc_step_maximum,
                    values.spread_step_maximum,
                    values.little_group_residual,
                    values.z_boundary_gap,
                    values.z_mix_ratio,
                    values.u_mix_ratio,
                    values.projected_gradient_rms,
                    values.accepted_u_step_scale,
                    values.localization_directional_derivative,
                    values.fixed_projector_drift,
                    values.localization_base_objective,
                    values.localization_required_change,
                    values.localization_actual_change,
                    values.minimum_diagonal_phase_margin,
                    values.cg_beta,
                    values.cg_descent_cosine,
                    values.maximum_kstar_gradient_rms,
                    values.omega_i,
                    values.delta_omega_i,
                    values.joint_transport_minimum_singular_value,
                    values.joint_transport_maximum_condition,
                )
                diagnostic_integers[:, index] .= (
                    values.u_inner_sweeps,
                    values.rejected_steps,
                    values.localization_backtracking_steps,
                    1,
                    values.minimum_phase_kpoint,
                    values.minimum_phase_neighbor,
                    values.minimum_phase_wannier,
                    values.maximum_kstar_gradient_index,
                    values.z_stability_count,
                    values.joint_z_backtracking_steps,
                )
                diagnostic_flags[:, index] .=
                    UInt8.((values.anderson_used, values.anderson_fallback, values.cg_restarted))
                anderson_reasons[index] = String(values.anderson_reason)
                cg_restart_reasons[index] = String(values.cg_restart_reason)
                joint_acceptance_reasons[index] = String(values.joint_acceptance_reason)
            end
            history["omega_directional"] = directional
            history["iteration_diagnostic_values"] = diagnostic_values
            history["iteration_diagnostic_integers"] = diagnostic_integers
            history["iteration_diagnostic_flags"] = diagnostic_flags
            history["anderson_reason"] = anderson_reasons
            history["cg_restart_reason"] = cg_restart_reasons
            history["joint_acceptance_reason"] = joint_acceptance_reasons
            HDF5.attributes(history["omega_directional"])["axis_order"] = "direction,iteration"
            HDF5.attributes(history["iteration_diagnostic_values"])["field_order"] =
                "omega_total,projector_residual,z_residual,u_residual,wcc_step_maximum," *
                "spread_step_maximum,little_group_residual,z_boundary_gap,z_mix_ratio,u_mix_ratio," *
                "projected_gradient_rms,accepted_u_step_scale,localization_directional_derivative," *
                "fixed_projector_drift,localization_base_objective,localization_required_change," *
                "localization_actual_change,minimum_diagonal_phase_margin,cg_beta," *
                "cg_descent_cosine,maximum_kstar_gradient_rms,omega_i,delta_omega_i," *
                "joint_transport_minimum_singular_value,joint_transport_maximum_condition"
            HDF5.attributes(history["iteration_diagnostic_integers"])["field_order"] =
                "u_inner_sweeps,rejected_steps,localization_backtracking_steps,available," *
                "minimum_phase_kpoint,minimum_phase_neighbor,minimum_phase_wannier," *
                "maximum_kstar_gradient_index,z_stability_count,joint_z_backtracking_steps"
            HDF5.attributes(
                history["iteration_diagnostic_flags"],
            )["field_order"] = "anderson_used,anderson_fallback,cg_restarted"
            diagnostics = HDF5.create_group(handle, "diagnostics")
            attributes["diagnostic_count"] = length(result.diagnostics)
            for (index, diagnostic) in enumerate(result.diagnostics)
                group = HDF5.create_group(diagnostics, lpad(string(index), 6, '0'))
                group_attributes = HDF5.attributes(group)
                group_attributes["code"] = String(diagnostic.code)
                group_attributes["severity"] = String(diagnostic.severity)
                group_attributes["message"] = diagnostic.message
                write_string_dictionary(group, diagnostic.context)
            end
            summary = HDF5.create_group(handle, "input_summary")
            checkpoint_summary = Dict{String, String}(result.input_summary)
            checkpoint_summary["checkpoint_schema_version"] =
                WANNIERIZATION_CHECKPOINT_SCHEMA_VERSION
            get!(
                checkpoint_summary,
                "z_u_stage_semantics",
                "disentanglement_localization_decoupled_v1",
            )
            write_string_dictionary(summary, checkpoint_summary)
            _write_initialization_report(
                handle,
                result.initialization_report,
                size(result.v_matrix, 2),
            )
            environment = HDF5.create_group(handle, "environment")
            write_generation_environment(environment)
            if result.restart_state !== nothing
                state = result.restart_state
                if state.stencil !== nothing
                    stencil = something(state.stencil)
                    stencil_group = HDF5.create_group(handle, "finite_difference_stencil")
                    stencil_attributes = HDF5.attributes(stencil_group)
                    stencil_attributes["spread_metric"] = "full_3d"
                    stencil_attributes["digest"] = stencil.digest
                    stencil_attributes["completeness_residual"] = stencil.completeness_residual
                    stencil_group["vectors_cartesian"] = stencil.vectors_cartesian
                    stencil_group["shell_ids"] = stencil.shell_ids
                    stencil_group["weights"] = stencil.weights
                    stencil_group["target_moment"] = stencil.target_moment
                end
                restart_group = HDF5.create_group(handle, "restart_state")
                restart_attributes = HDF5.attributes(restart_group)
                restart_attributes["iteration"] = state.iteration
                restart_attributes["elapsed_seconds"] = state.elapsed_seconds
                restart_attributes["config_sha256"] = state.config_sha256
                restart_attributes["representation_sha256"] = state.representation_sha256
                restart_attributes["projection_basis_sha256"] = state.projection_basis_sha256
                restart_attributes["amn_sha256"] = state.amn_sha256
                restart_group["frames"] = state.frames
                restart_group["has_z_previous"] = state.z_previous !== nothing
                state.z_previous === nothing || (restart_group["z_previous"] = state.z_previous)
                restart_group["has_fixed_subspace"] =
                    state.fixed_subspace_projectors !== nothing &&
                    state.fixed_subspace_frames !== nothing
                state.fixed_subspace_projectors === nothing ||
                    (restart_group["fixed_subspace_projectors"] = state.fixed_subspace_projectors)
                state.fixed_subspace_frames === nothing ||
                    (restart_group["fixed_subspace_frames"] = state.fixed_subspace_frames)
                restart_group["has_localization_initial_frames"] =
                    state.localization_initial_frames !== nothing
                state.localization_initial_frames === nothing || (
                    restart_group["localization_initial_frames"] =
                        state.localization_initial_frames
                )
                restart_group["centers_cartesian"] = state.centers_cartesian
                restart_group["spreads_angstrom2"] = state.spreads_angstrom2
                restart_group["convergence_values"] = state.convergence_values
                restart_group["included_bands"] = Matrix{UInt8}(state.included_bands)
                optimizer = HDF5.create_group(restart_group, "optimizer")
                optimizer_attributes = HDF5.attributes(optimizer)
                optimizer_attributes["strategy"] = String(state.optimizer_state.strategy)
                optimizer_attributes["z_mix_ratio"] = state.optimizer_state.z_mix_ratio
                optimizer_attributes["u_mix_ratio"] = state.optimizer_state.u_mix_ratio
                optimizer_attributes["improvement_streak"] =
                    state.optimizer_state.improvement_streak
                optimizer_attributes["rejected_steps"] = state.optimizer_state.rejected_steps
                optimizer_attributes["previous_merit"] = state.optimizer_state.previous_merit
                optimizer_attributes["phase"] = String(state.optimizer_state.phase)
                optimizer_attributes["z_stability_count"] = state.optimizer_state.z_stability_count
                optimizer_attributes["u_stability_count"] = state.optimizer_state.u_stability_count
                optimizer_attributes["z_steps"] = state.optimizer_state.z_steps
                optimizer_attributes["u_steps"] = state.optimizer_state.u_steps
                optimizer_attributes["disentanglement_steps"] = state.optimizer_state.z_steps
                optimizer_attributes["localization_steps"] = state.optimizer_state.u_steps
                optimizer_attributes["disentanglement_status"] =
                    state.optimizer_state.phase in (:localization, :completed) ? "COMPLETED" :
                    "IN_PROGRESS"
                optimizer_attributes["localization_status"] =
                    state.optimizer_state.phase == :completed ? "COMPLETED" :
                    state.optimizer_state.phase == :localization ? "IN_PROGRESS" : "NOT_STARTED"
                optimizer_attributes["epoch"] = state.optimizer_state.epoch
                optimizer_attributes["last_accepted_u_step_scale"] =
                    state.optimizer_state.last_accepted_u_step_scale
                optimizer_attributes["gradient_fallback_active"] =
                    state.optimizer_state.gradient_fallback_active
                optimizer_attributes["gradient_steps"] = state.optimizer_state.gradient_steps
                optimizer_attributes["u_cg_iteration"] = state.optimizer_state.u_cg_iteration
                optimizer_attributes["u_cg_restart_count"] =
                    state.optimizer_state.u_cg_restart_count
                optimizer_attributes["last_cg_beta"] = state.optimizer_state.last_cg_beta
                optimizer_attributes["last_cg_restart_reason"] =
                    String(state.optimizer_state.last_cg_restart_reason)
                optimizer_attributes["last_anderson_reason"] =
                    String(state.optimizer_state.last_anderson_reason)
                optimizer_attributes["u_phase_contract"] = state.optimizer_state.u_phase_contract
                optimizer_attributes["u_active_orbit_sha256"] =
                    state.optimizer_state.u_active_orbit_sha256
                optimizer_attributes["u_active_orbit_count"] =
                    state.optimizer_state.u_active_orbit_count
                optimizer_attributes["u_generalized_gradient_rms"] =
                    state.optimizer_state.u_generalized_gradient_rms
                optimizer_attributes["u_lbfgs_restart_count"] =
                    state.optimizer_state.u_lbfgs_restart_count
                optimizer_attributes["last_u_optimizer_restart_reason"] =
                    String(state.optimizer_state.last_u_optimizer_restart_reason)
                optimizer_attributes["wannier90_reference_omega_i"] =
                    state.optimizer_state.wannier90_reference_omega_i
                optimizer_attributes["best_polar_objective"] =
                    state.optimizer_state.best_polar_objective
                optimizer["residual_reference"] = collect(state.optimizer_state.residual_reference)
                optimizer["anderson_z_history"] = state.optimizer_state.anderson_z_history
                optimizer["anderson_residual_history"] =
                    state.optimizer_state.anderson_residual_history
                optimizer["previous_u_gradient"] = state.optimizer_state.previous_u_gradient
                optimizer["previous_u_direction"] = state.optimizer_state.previous_u_direction
                optimizer["u_lbfgs_s_history"] = state.optimizer_state.u_lbfgs_s_history
                optimizer["u_lbfgs_y_history"] = state.optimizer_state.u_lbfgs_y_history
                optimizer["u_lbfgs_rho_history"] = state.optimizer_state.u_lbfgs_rho_history
                optimizer["wannier90_reference_overlaps"] =
                    state.optimizer_state.wannier90_reference_overlaps
                optimizer["wannier90_reference_unitaries"] =
                    state.optimizer_state.wannier90_reference_unitaries
                optimizer["best_polar_frames"] = state.optimizer_state.best_polar_frames
                optimizer["best_polar_centers"] = state.optimizer_state.best_polar_centers
                optimizer["best_polar_spreads"] = state.optimizer_state.best_polar_spreads
                optimizer["disentanglement_objective_history"] =
                    state.optimizer_state.disentanglement_objective_history
                optimizer["localization_objective_history"] =
                    state.optimizer_state.localization_objective_history
                optimizer["localization_trial_step_scales"] =
                    state.optimizer_state.localization_trial_step_scales
                optimizer["localization_trial_objectives"] =
                    state.optimizer_state.localization_trial_objectives
                optimizer["localization_trial_required_changes"] =
                    state.optimizer_state.localization_trial_required_changes
                optimizer["localization_trial_actual_changes"] =
                    state.optimizer_state.localization_trial_actual_changes
                optimizer["localization_trial_directional_derivatives"] =
                    state.optimizer_state.localization_trial_directional_derivatives
                optimizer["localization_projector_drift_history"] =
                    state.optimizer_state.localization_projector_drift_history
                optimizer["localization_trial_iterations"] =
                    state.optimizer_state.localization_trial_iterations
                optimizer["localization_trial_sweeps"] =
                    state.optimizer_state.localization_trial_sweeps
                optimizer["localization_trial_accepted"] =
                    state.optimizer_state.localization_trial_accepted
            end
        end
    end
end
