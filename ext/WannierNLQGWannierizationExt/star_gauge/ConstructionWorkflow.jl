# Quality evidence is independent of whether a finite completed state can be built.
function _star_construction_quality_gate!(
    config,
    maxima,
    contexts,
    name,
    value,
    threshold;
    context = "NOT_RECORDED",
)
    isfinite(value) && isfinite(threshold) && threshold > 0 ||
        throw(ArgumentError("NONFINITE_STRUCTURAL_HOLD: invalid $(name) value or threshold"))
    passed = value <= threshold
    if value >= get(maxima, "construction_$(name)_value", -Inf)
        maxima["construction_$(name)_value"] = Float64(value)
        contexts["construction_$(name)_value"] = String(context)
    end
    maxima["construction_$(name)_threshold"] = Float64(threshold)
    maxima["construction_$(name)_failed"] =
        max(get(maxima, "construction_$(name)_failed", 0.0), passed ? 0.0 : 1.0)
    action =
        passed ? "CONTINUE" :
        config.construction_policy == :diagnostic ? "CONTINUE_DIAGNOSTIC" : "STOP"
    if !passed || !haskey(contexts, "construction_$(name)_failed")
        contexts["construction_$(name)_failed"] = action
    end
    if !passed
        _star_append_preflight_diagnostic!(config, name, value, threshold, context, action)
        config.construction_policy == :strict &&
            _strict_sewing_gate(String(name), value, threshold; context = String(context))
    end
    return passed
end

"""Persist a failed quality check separately from its continue/stop decision."""
function _star_append_preflight_diagnostic!(config, name, value, threshold, context, action)
    _star_append_preflight_diagnostic(
        config,
        Dict(
            "stage" => "CONSTRUCTION_QUALITY_GATE",
            "code" => String(name),
            "value" => value,
            "threshold" => threshold,
            "result" => "FAIL",
            "action" => action,
            "context" => String(context),
        ),
    )
    return nothing
end

"""Execute and audit one physical Reynolds/rediagonalization partition candidate."""
function _star_partition_candidate_solution(
    blocks::Vector{Vector{Int}},
    context::NamedTuple;
    controlled_eigenpair = nothing,
    controlled_maxima::AbstractDict{String, Float64} = Dict{String, Float64}(),
    controlled_contexts::AbstractDict{String, String} = Dict{String, String}(),
)
    workspace_count = length(context.workspace)
    completion_data = nothing
    completion_maxima = Dict{String, Float64}()
    completion_contexts = Dict{String, String}()
    if context.authoritative_hamiltonian isa SymmetrizedDFTHamiltonian
        controlled_eigenpair === nothing || throw(
            ArgumentError(
                "CONTROLLED_SYMMETRIZATION_HOLD: target authority does not accept a parent controlled eigenpair",
            ),
        )
        target_eigenpair = _star_symmetrized_target_eigenpair(
            context.hamiltonian_average,
            context.target_indices,
            blocks,
            context.gauge.buffer_policy.cluster_tolerance_ev,
        )
        completed_energies = target_eigenpair.values
        selected_vectors = target_eigenpair.vectors
        selected_indices = target_eigenpair.selected_indices
        kramers_pairs, kramers_residual = _star_fix_kramers_pairs!(
            selected_vectors,
            completed_energies,
            context.selected_raw,
            context.transports,
            context.operations,
            context.representative,
            context.gauge.thresholds,
        )
        target_eigensolver_residual = maximum(
            abs,
            context.hamiltonian_average * selected_vectors -
            selected_vectors * Diagonal(completed_energies),
        )
        merge!(completion_maxima, target_eigenpair.maxima)
        completion_maxima["authoritative_target_eigensolver_residual_ev"] =
            target_eigensolver_residual
        target_context = "star=$(context.star_index),rep=$(context.representative),target=complete_outer_block"
        for key in keys(target_eigenpair.maxima)
            completion_contexts[key] = target_context
        end
        completion_data = _star_frozen_target_complement_eigenpair(
            copy(completed_energies),
            copy(selected_vectors),
            context,
            context.authoritative_hamiltonian::SymmetrizedDFTHamiltonian,
        )
        eigenvalues = completion_data.values
        eigenvectors = completion_data.vectors
        completed_energies = completion_data.target_values
        selected_vectors = completion_data.target_vectors
        merge!(completion_maxima, completion_data.maxima)
        merge!(completion_contexts, completion_data.maximum_contexts)
        kramers_residual = max(
            kramers_residual,
            get(completion_data.maxima, "complement_kramers_pair_residual", 0.0),
        )
    else
        if controlled_eigenpair === nothing
            eigenvalues = zeros(Float64, workspace_count)
            eigenvectors = zeros(ComplexF64, workspace_count, workspace_count)
            for block in blocks
                decomposition =
                    eigen(Hermitian(Matrix(@view(context.hamiltonian_average[block, block]))))
                eigenvalues[block] .= decomposition.values
                eigenvectors[block, block] .= decomposition.vectors
            end
        else
            eigenvalues = Vector{Float64}(controlled_eigenpair.values)
            eigenvectors = Matrix{ComplexF64}(controlled_eigenpair.vectors)
            length(eigenvalues) == workspace_count &&
            size(eigenvectors) == (workspace_count, workspace_count) || throw(
                ArgumentError("CONTROLLED_SYMMETRIZATION_HOLD: eigenpair dimensions disagree"),
            )
        end
        _star_canonicalize_eigenvectors!(
            eigenvectors,
            eigenvalues,
            controlled_eigenpair === nothing ? context.gauge.buffer_policy.cluster_tolerance_ev :
            min(context.gauge.buffer_policy.cluster_tolerance_ev, 1.0e-10),
        )
        kramers_pairs, kramers_residual = _star_fix_kramers_pairs!(
            eigenvectors,
            eigenvalues,
            context.selected_raw,
            context.transports,
            context.operations,
            context.representative,
            context.gauge.thresholds,
        )
        completed_energies, selected_vectors, selected_indices = _star_select_target_eigenvectors(
            eigenvalues,
            eigenvectors,
            context.target_projector,
            context.target_count,
            context.gauge.buffer_policy.cluster_tolerance_ev,
        )
    end
    shifts = completed_energies - context.representative_energies[context.target_indices]
    all(isfinite, shifts) ||
        throw(ArgumentError("NONFINITE_STRUCTURAL_HOLD: nonfinite target energy shift"))
    representative_coefficients = _star_rotate_rows(
        context.native.kpoints[context.representative].coefficients[context.workspace, :, :],
        selected_vectors,
    )
    representative_projectors = _star_rotate_rows(
        context.metric.projectors[context.representative][context.workspace, :, :],
        selected_vectors,
    )
    representative_point = PlaneWaveKPoint(
        context.native.kpoints[context.representative].k_fractional,
        context.native.kpoints[context.representative].g_vectors,
        representative_coefficients,
        completed_energies;
        normalize_coefficients = false,
    )
    points = Dict{Int, PlaneWaveKPoint}()
    parent_points = Dict{Int, PlaneWaveKPoint}()
    rotations = Dict{Int, Matrix{ComplexF64}}()
    rotations_lowdin = Dict{Int, Matrix{ComplexF64}}()
    parent_rotations = Dict{Int, Matrix{ComplexF64}}()
    parent_rotations_lowdin = Dict{Int, Matrix{ComplexF64}}()
    parent_assignments = Dict{Int, Vector{Int}}()
    target_principal_angles = Dict{Int, Vector{Float64}}()
    target_projector_operator = Dict{Int, Float64}()
    target_projector_frobenius = Dict{Int, Float64}()
    parent_energy_shifts = Dict{Int, Vector{Float64}}()
    parent_eigenvalues = Dict{Int, Vector{Float64}}()
    canonical_operations = Dict{Int, Int}()
    maxima = Dict{String, Float64}(
        "wfc_rotation_reconstruction" => 0.0,
        "target_reconstruction_leakage_weight" => 0.0,
        "target_state_leakage_weight" => 0.0,
        "target_to_complement_leakage_weight" => 0.0,
        "complement_to_target_leakage_weight" => 0.0,
        "maximum_bidirectional_leakage_weight" => 0.0,
        "state_leakage_amplitude_audit" => 0.0,
        "completed_paw_s_norm" => 0.0,
        "raw_unitarity" => 0.0,
        "normalized_polar_correction" => 0.0,
        "projected_eigen_residual_ev" => 0.0,
        "native_fidelity_projected_eigen_residual_ev" => 0.0,
        "symmetrized_projected_eigen_residual_ev" => 0.0,
        "symmetrized_target_formal_eigen_residual_ev" => 0.0,
        "symmetrized_parent_formal_eigen_residual_ev" => 0.0,
        "target_maximum_principal_angle_rad" => 0.0,
        "target_rms_sine_principal_angle" => 0.0,
        "target_projector_difference_operator" => 0.0,
        "target_projector_difference_frobenius" => 0.0,
        "symmetrized_hamiltonian_correction_operator_ev" => 0.0,
        "symmetrized_hamiltonian_correction_frobenius_ev" => 0.0,
        "symmetrized_hamiltonian_correction_normalized_frobenius_ev" => 0.0,
        "symmetrized_parent_maximum_energy_shift_ev" => 0.0,
        "symmetrized_parent_rms_energy_shift_ev" => 0.0,
        "alternative_path_residual" => 0.0,
        "hamiltonian_covariance_after_ev" => 0.0,
        "hamiltonian_covariance_after_operator_ev" => 0.0,
        "hamiltonian_covariance_after_source_column_l2_ev" => 0.0,
        "hamiltonian_covariance_after_normalized_frobenius_ev" => 0.0,
        "hamiltonian_covariance_after_frobenius_ev" => 0.0,
        "nondegenerate_block_leakage" => 0.0,
        "near_block_leakage" => 0.0,
        "far_band_coupling" => 0.0,
        "far_residual_count" => 0.0,
        "tolerated_far_residual_count" => 0.0,
        "maximum_pair_hamiltonian_residual_ev" => 0.0,
        "maximum_far_operator_residual_ev" => 0.0,
        "maximum_far_source_column_l2_residual_ev" => 0.0,
        "maximum_far_normalized_frobenius_residual_ev" => 0.0,
        "maximum_far_frobenius_residual_ev" => 0.0,
        "pre_gauge_far_cumulative_diagnostic_exceeded" => 0.0,
        "pre_gauge_far_cumulative_maximum_ratio" => 0.0,
        "kramers_pair_residual" => kramers_pairs > 0 ? kramers_residual : 0.0,
        "maximum_energy_shift_ev" => maximum(abs, shifts),
        "rms_energy_shift_ev" => sqrt(sum(abs2, shifts) / length(shifts)),
    )
    target_maximum_index = argmax(abs.(shifts))
    maximum_contexts = Dict{String, String}(
        "maximum_energy_shift_ev" => "star=$(context.star_index),rep=$(context.representative),band=$(context.target_indices[target_maximum_index])",
        "rms_energy_shift_ev" => "star=$(context.star_index),rep=$(context.representative)",
    )
    if kramers_pairs > 0
        maximum_contexts["kramers_pair_residual"] = "star=$(context.star_index),rep=$(context.representative),pairs=$(kramers_pairs)"
    end
    merge!(maxima, controlled_maxima)
    merge!(maximum_contexts, controlled_contexts)
    merge!(maxima, completion_maxima)
    merge!(maximum_contexts, completion_contexts)

    representative_parent_coefficients = _star_rotate_rows(
        context.native.kpoints[context.representative].coefficients[context.workspace, :, :],
        eigenvectors,
    )
    representative_parent_point = PlaneWaveKPoint(
        context.native.kpoints[context.representative].k_fractional,
        context.native.kpoints[context.representative].g_vectors,
        representative_parent_coefficients,
        eigenvalues;
        normalize_coefficients = false,
    )

    for target in context.star
        operation_index = _star_canonical_operation(
            context.operations,
            context.kpoint_map,
            context.representative,
            target,
        )
        item_context = "star=$(context.star_index),rep=$(context.representative),target=$(target),op=$(operation_index)"
        canonical_operations[target] = operation_index
        formal_target_transport =
            if context.authoritative_hamiltonian isa SymmetrizedDFTHamiltonian &&
               target != context.representative
                context.formal_target_actions === nothing && throw(
                    ArgumentError(
                        "FORMAL_TARGET_REPRESENTATION_HOLD: target actions are unavailable",
                    ),
                )
                context.formal_target_indices === nothing && throw(
                    ArgumentError("TARGET_MASK_MAPPING_HOLD: target index field is unavailable"),
                )
                _star_transport_symmetrized_target_eigenpair(
                    selected_vectors,
                    context.target_indices,
                    context.formal_target_indices[target],
                    context.formal_target_actions[(context.representative, operation_index)],
                    context.operations[operation_index].antiunitary,
                    context.symmetrized_hamiltonians[target],
                    completed_energies,
                )
            else
                nothing
            end
        if formal_target_transport !== nothing
            _star_update_maximum!(
                maxima,
                maximum_contexts,
                "formal_target_transport_eigen_residual_ev",
                formal_target_transport.residual_ev,
                item_context,
            )
            _star_update_maximum!(
                maxima,
                maximum_contexts,
                "formal_target_transport_isometry",
                formal_target_transport.isometry,
                item_context,
            )
        end
        point = if target == context.representative
            representative_point
        elseif formal_target_transport !== nothing
            coefficients = _star_rotate_rows(
                context.native.kpoints[target].coefficients[context.workspace, :, :],
                formal_target_transport.vectors,
            )
            PlaneWaveKPoint(
                context.native.kpoints[target].k_fractional,
                context.native.kpoints[target].g_vectors,
                coefficients,
                completed_energies;
                normalize_coefficients = false,
            )
        else
            template = PlaneWaveKPoint(
                context.native.kpoints[target].k_fractional,
                context.native.kpoints[target].g_vectors,
                zeros(
                    ComplexF64,
                    context.target_count,
                    size(context.native.kpoints[target].g_vectors, 1),
                    size(representative_coefficients, 3),
                ),
                completed_energies;
                normalize_coefficients = false,
            )
            coefficients = _strict_transform_plane_wave_coefficients(
                representative_point,
                template,
                context.operations[operation_index],
                @view(context.reciprocal_shifts[:, operation_index, context.representative]),
            )
            PlaneWaveKPoint(
                template.k_fractional,
                template.g_vectors,
                coefficients,
                completed_energies;
                normalize_coefficients = false,
            )
        end
        points[target] = point
        completed_projectors =
            target == context.representative ? representative_projectors :
            formal_target_transport !== nothing ?
            _star_rotate_rows(
                context.metric.projectors[target][context.workspace, :, :],
                formal_target_transport.vectors,
            ) : _strict_transformed_projectors(context.metric, target, point.coefficients)
        rotation, _, _ = _strict_metric_overlap(
            context.metric,
            context.native.kpoints[target].coefficients,
            point.coefficients,
            context.metric.projectors[target],
            completed_projectors,
        )
        rotations[target] = context.lowdin.rotations[target] * rotation
        rotations_lowdin[target] = rotation

        target_parent_completion = if formal_target_transport === nothing
            nothing
        else
            local_context = merge(
                context,
                (
                    representative = target,
                    target_indices = context.formal_target_indices[target],
                    hamiltonian_average = context.symmetrized_hamiltonians[target],
                ),
            )
            _star_frozen_target_complement_eigenpair(
                copy(completed_energies),
                copy(formal_target_transport.vectors),
                local_context,
                context.authoritative_hamiltonian::SymmetrizedDFTHamiltonian;
                fix_complement_kramers = false,
            )
        end
        if target_parent_completion !== nothing
            for (name, value) in target_parent_completion.maxima
                _star_update_maximum!(
                    maxima,
                    maximum_contexts,
                    name,
                    value,
                    item_context * ",local_complement",
                )
            end
        end
        parent_values =
            target_parent_completion === nothing ? eigenvalues : target_parent_completion.values
        parent_point = if target == context.representative
            representative_parent_point
        elseif target_parent_completion !== nothing
            coefficients = _star_rotate_rows(
                context.native.kpoints[target].coefficients[context.workspace, :, :],
                target_parent_completion.vectors,
            )
            PlaneWaveKPoint(
                context.native.kpoints[target].k_fractional,
                context.native.kpoints[target].g_vectors,
                coefficients,
                parent_values;
                normalize_coefficients = false,
            )
        else
            template = PlaneWaveKPoint(
                context.native.kpoints[target].k_fractional,
                context.native.kpoints[target].g_vectors,
                zeros(
                    ComplexF64,
                    workspace_count,
                    size(context.native.kpoints[target].g_vectors, 1),
                    size(representative_parent_coefficients, 3),
                ),
                parent_values;
                normalize_coefficients = false,
            )
            coefficients = _strict_transform_plane_wave_coefficients(
                representative_parent_point,
                template,
                context.operations[operation_index],
                @view(context.reciprocal_shifts[:, operation_index, context.representative]),
            )
            PlaneWaveKPoint(
                template.k_fractional,
                template.g_vectors,
                coefficients,
                parent_values;
                normalize_coefficients = false,
            )
        end
        parent_projectors =
            target == context.representative ?
            _star_rotate_rows(
                context.metric.projectors[context.representative][context.workspace, :, :],
                eigenvectors,
            ) :
            target_parent_completion !== nothing ?
            _star_rotate_rows(
                context.metric.projectors[target][context.workspace, :, :],
                target_parent_completion.vectors,
            ) : _strict_transformed_projectors(context.metric, target, parent_point.coefficients)
        parent_rotation, _, _ = _strict_metric_overlap(
            context.metric,
            context.native.kpoints[target].coefficients[context.workspace, :, :],
            parent_point.coefficients,
            context.metric.projectors[target][context.workspace, :, :],
            parent_projectors,
        )
        parent_rotations_lowdin[target] = parent_rotation
        parent_rotations[target] = context.lowdin.rotations[target] * parent_rotation
        parent_points[target] = parent_point
        parent_eigenvalues[target] = copy(parent_values)
        parent_point.energies_ev == parent_values ||
            throw(ArgumentError("HAMILTONIAN_REFERENCE_MISMATCH: parent point energies differ"))

        target_projector_indices =
            context.authoritative_hamiltonian isa SymmetrizedDFTHamiltonian ?
            context.formal_target_indices[target] : context.target_indices
        target_projector = _star_target_projector(
            context.raw_metric,
            context.native.kpoints[target],
            context.metric.projectors[target],
            context.raw_native.kpoints[target],
            context.raw_metric.projectors[target],
            context.workspace,
            target_projector_indices,
        )
        overlap_eigenvalues = eigvals(Hermitian(rotation' * target_projector * rotation))
        angles = acos.(sqrt.(clamp.(real.(overlap_eigenvalues), 0.0, 1.0)))
        target_principal_angles[target] = angles
        selected_projector = rotation * rotation'
        projector_difference = target_projector - selected_projector
        target_projector_operator[target] = opnorm(projector_difference, 2)
        target_projector_frobenius[target] = norm(projector_difference)
        _star_update_maximum!(
            maxima,
            maximum_contexts,
            "target_maximum_principal_angle_rad",
            maximum(angles; init = 0.0),
            item_context,
        )
        _star_update_maximum!(
            maxima,
            maximum_contexts,
            "target_rms_sine_principal_angle",
            sqrt(sum(abs2, sin.(angles)) / length(angles)),
            item_context,
        )
        _star_update_maximum!(
            maxima,
            maximum_contexts,
            "target_projector_difference_operator",
            target_projector_operator[target],
            item_context,
        )
        _star_update_maximum!(
            maxima,
            maximum_contexts,
            "target_projector_difference_frobenius",
            target_projector_frobenius[target],
            item_context,
        )
        reconstruction = _strict_reconstruction_diagnostics(
            context.metric,
            context.native.kpoints[target].coefficients,
            point.coefficients,
            context.metric.projectors[target],
            completed_projectors,
            rotation,
        )
        _star_update_maximum!(
            maxima,
            maximum_contexts,
            "wfc_rotation_reconstruction",
            reconstruction.reconstruction_leakage_amplitude_audit,
            item_context,
        )
        _star_update_maximum!(
            maxima,
            maximum_contexts,
            context.authoritative_hamiltonian isa NativeDFTHamiltonian &&
                context.target_subspace_contract !== nothing ?
            "parent_output_state_leakage_amplitude_audit" : "target_state_leakage_weight",
            context.authoritative_hamiltonian isa NativeDFTHamiltonian &&
                context.target_subspace_contract !== nothing ?
            reconstruction.state_leakage_amplitude_audit : reconstruction.state_leakage_weight,
            item_context,
        )
        if context.target_subspace_contract !== nothing
            _star_update_maximum!(
                maxima,
                maximum_contexts,
                context.authoritative_hamiltonian isa NativeDFTHamiltonian ?
                "parent_output_reconstruction_leakage_amplitude_audit" :
                "target_reconstruction_leakage_weight",
                context.authoritative_hamiltonian isa NativeDFTHamiltonian ?
                reconstruction.reconstruction_leakage_amplitude_audit :
                reconstruction.reconstruction_leakage_weight,
                item_context,
            )
        end
        completed_norm, _, _ = _strict_metric_overlap(
            context.metric,
            point.coefficients,
            point.coefficients,
            completed_projectors,
            completed_projectors,
        )
        _star_update_maximum!(
            maxima,
            maximum_contexts,
            "completed_paw_s_norm",
            maximum(abs, completed_norm - I),
            item_context,
        )
        scoped_indices = if context.authoritative_hamiltonian isa SymmetrizedDFTHamiltonian
            collect(axes(rotation, 2))
        elseif context.target_subspace_contract === nothing
            collect(axes(rotation, 2))
        else
            findall(
                something(context.target_subspace_contract).qualification_scope.outer_mask[
                    :,
                    target,
                ],
            )
        end
        isempty(scoped_indices) &&
            throw(ArgumentError("TARGET_MASK_RANK_HOLD: empty outer authority at k=$(target)"))
        scoped_rotation = @view rotation[:, scoped_indices]
        native_projected_residual = maximum(
            abs,
            context.lowdin.hamiltonians[target] * scoped_rotation -
            scoped_rotation * Diagonal(completed_energies[scoped_indices]),
        )
        _star_update_maximum!(
            maxima,
            maximum_contexts,
            "native_fidelity_projected_eigen_residual_ev",
            native_projected_residual,
            item_context,
        )
        if context.authoritative_hamiltonian isa NativeDFTHamiltonian &&
           context.target_subspace_contract !== nothing
            parent_projected_residual = maximum(
                abs,
                context.lowdin.hamiltonians[target] * rotation -
                rotation * Diagonal(completed_energies),
            )
            _star_update_maximum!(
                maxima,
                maximum_contexts,
                "parent_projected_eigen_residual_audit_ev",
                parent_projected_residual,
                item_context,
            )
        end
        symmetrized_hamiltonian =
            context.symmetrized_hamiltonians === nothing ? nothing :
            context.symmetrized_hamiltonians[target]
        if context.authoritative_hamiltonian isa SymmetrizedDFTHamiltonian
            target_columns = collect(context.formal_target_indices[target])
            complement_columns = setdiff(collect(axes(parent_rotation, 2)), target_columns)
            target_complement =
                parent_rotation[:, target_columns]' *
                symmetrized_hamiltonian *
                parent_rotation[:, complement_columns]
            _star_update_maximum!(
                maxima,
                maximum_contexts,
                "target_complement_maximum_element_ev",
                maximum(abs, target_complement; init = 0.0),
                item_context * ",completed_target_complement",
            )
        end
        symmetrized_projected_residual = if symmetrized_hamiltonian === nothing
            native_projected_residual
        else
            maximum(abs, symmetrized_hamiltonian * rotation - rotation * Diagonal(completed_energies))
        end
        _star_update_maximum!(
            maxima,
            maximum_contexts,
            "symmetrized_projected_eigen_residual_ev",
            symmetrized_projected_residual,
            item_context,
        )
        _star_update_maximum!(
            maxima,
            maximum_contexts,
            "symmetrized_target_formal_eigen_residual_ev",
            symmetrized_projected_residual,
            item_context,
        )
        authoritative_residual =
            is_symmetrized_authority(context.authoritative_hamiltonian) ?
            symmetrized_projected_residual : native_projected_residual
        _star_update_maximum!(
            maxima,
            maximum_contexts,
            "projected_eigen_residual_ev",
            authoritative_residual,
            item_context,
        )
        if symmetrized_hamiltonian !== nothing
            parent_residual = maximum(
                abs,
                symmetrized_hamiltonian * parent_rotation -
                parent_rotation * Diagonal(parent_values),
            )
            _star_update_maximum!(
                maxima,
                maximum_contexts,
                "symmetrized_projected_eigen_residual_ev",
                parent_residual,
                item_context * ",parent=full",
            )
            _star_update_maximum!(
                maxima,
                maximum_contexts,
                "symmetrized_parent_formal_eigen_residual_ev",
                parent_residual,
                item_context * ",parent=full",
            )
            # The full-parent formal residual is retained as an audit.  Only
            # the ragged outer-window residual is authoritative downstream.
            correction_hamiltonian = symmetrized_hamiltonian - context.lowdin.hamiltonians[target]
            correction_operator = opnorm(correction_hamiltonian, 2)
            correction_frobenius = norm(correction_hamiltonian)
            correction_normalized_frobenius = correction_frobenius / sqrt(workspace_count)
            for (name, value) in (
                ("symmetrized_hamiltonian_correction_operator_ev", correction_operator),
                ("symmetrized_hamiltonian_correction_frobenius_ev", correction_frobenius),
                (
                    "symmetrized_hamiltonian_correction_normalized_frobenius_ev",
                    correction_normalized_frobenius,
                ),
                ("controlled_hamiltonian_correction_operator_ev", correction_operator),
                ("controlled_hamiltonian_correction_frobenius_ev", correction_frobenius),
                (
                    "controlled_hamiltonian_correction_normalized_frobenius_ev",
                    correction_normalized_frobenius,
                ),
            )
                _star_update_maximum!(maxima, maximum_contexts, name, value, item_context)
            end
            assignment = hungarian_maximum_assignment(abs2.(parent_rotation))
            parent_assignments[target] = assignment
            shifts_parent = [
                parent_values[assignment[native_band]] -
                context.native.kpoints[target].energies_ev[context.workspace[native_band]] for
                native_band in 1:workspace_count
            ]
            parent_energy_shifts[target] = shifts_parent
            all(isfinite, shifts_parent) ||
                throw(ArgumentError("NONFINITE_STRUCTURAL_HOLD: nonfinite parent energy shift"))
            _star_update_maximum!(
                maxima,
                maximum_contexts,
                "symmetrized_parent_maximum_energy_shift_ev",
                maximum(abs, shifts_parent),
                item_context * ",band=$(context.workspace[argmax(abs.(shifts_parent))])",
            )
            _star_update_maximum!(
                maxima,
                maximum_contexts,
                "symmetrized_parent_rms_energy_shift_ev",
                sqrt(sum(abs2, shifts_parent) / length(shifts_parent)),
                item_context,
            )
        end
    end

    completed_labels = canonical_band_block_labels(
        reshape(completed_energies, :, 1),
        context.gauge.buffer_policy.cluster_tolerance_ev,
    )[
        :,
        1,
    ]
    for operation_index in eachindex(context.operations)
        target = context.kpoint_map[operation_index, context.representative]
        canonical_point = points[target]
        transformed = _strict_transform_plane_wave_coefficients(
            representative_point,
            canonical_point,
            context.operations[operation_index],
            @view(context.reciprocal_shifts[:, operation_index, context.representative]),
        )
        transformed_projectors = _strict_transformed_projectors(context.metric, target, transformed)
        canonical_projectors =
            _strict_transformed_projectors(context.metric, target, canonical_point.coefficients)
        raw, _, _ = _strict_metric_overlap(
            context.metric,
            canonical_point.coefficients,
            transformed,
            canonical_projectors,
            transformed_projectors,
        )
        full_reconstruction = _strict_reconstruction_diagnostics(
            context.metric,
            canonical_point.coefficients,
            transformed,
            canonical_projectors,
            transformed_projectors,
            raw,
        )
        item_context = "star=$(context.star_index),rep=$(context.representative),target=$(target),op=$(operation_index)"
        source_scope = if context.authoritative_hamiltonian isa SymmetrizedDFTHamiltonian
            collect(axes(raw, 2))
        elseif context.target_subspace_contract === nothing
            collect(axes(raw, 2))
        else
            findall(
                something(context.target_subspace_contract).qualification_scope.outer_mask[
                    :,
                    context.representative,
                ],
            )
        end
        target_scope = if context.authoritative_hamiltonian isa SymmetrizedDFTHamiltonian
            collect(axes(raw, 1))
        elseif context.target_subspace_contract === nothing
            collect(axes(raw, 1))
        else
            findall(
                something(context.target_subspace_contract).qualification_scope.outer_mask[
                    :,
                    target,
                ],
            )
        end
        length(source_scope) == length(target_scope) || throw(
            ArgumentError(
                "TARGET_MASK_MAPPING_HOLD: outer ranks differ for rep=$(context.representative) " *
                "and target=$(target)",
            ),
        )
        scoped_raw = Matrix(@view raw[target_scope, source_scope])
        scoped_reconstruction =
            context.authoritative_hamiltonian isa NativeDFTHamiltonian &&
            context.target_subspace_contract !== nothing ?
            _strict_scoped_reconstruction_diagnostics(
                context.metric,
                canonical_point.coefficients,
                transformed,
                canonical_projectors,
                transformed_projectors,
                raw,
                target_scope,
                source_scope,
            ) : full_reconstruction
        identity_matrix = Matrix{ComplexF64}(I, length(source_scope), length(source_scope))
        raw_unitarity = max(
            maximum(abs, scoped_raw' * scoped_raw - identity_matrix),
            maximum(abs, scoped_raw * scoped_raw' - identity_matrix),
        )
        decomposition = svd(scoped_raw)
        polar = decomposition.U * decomposition.Vt
        polar_correction = norm(polar - scoped_raw) / sqrt(length(source_scope))
        if context.target_subspace_contract !== nothing
            for (name, value) in (
                (
                    "target_reconstruction_leakage_weight",
                    scoped_reconstruction.reconstruction_leakage_weight,
                ),
                ("target_state_leakage_weight", scoped_reconstruction.state_leakage_weight),
            )
                _star_update_maximum!(maxima, maximum_contexts, name, value, item_context)
            end
            contract = something(context.target_subspace_contract)
            source_outer = BitVector(
                contract.qualification_scope.outer_mask[context.workspace, context.representative],
            )
            target_outer =
                BitVector(contract.qualification_scope.outer_mask[context.workspace, target])
            parent_transport = if is_symmetrized_authority(context.authoritative_hamiltonian)
                parent_source_rotation = parent_rotations_lowdin[context.representative]
                parent_target_rotation = parent_rotations_lowdin[target]
                parent_source_action =
                    context.operations[operation_index].antiunitary ?
                    conj(parent_source_rotation) : parent_source_rotation
                parent_target_rotation' *
                context.selected_raw[operation_index] *
                parent_source_action
            else
                raw
            end
            size(parent_transport) == (length(target_outer), length(source_outer)) || throw(
                ArgumentError(
                    "TARGET_MASK_DIMENSION_HOLD: completed parent transport and outer masks disagree",
                ),
            )
            directed = _strict_bidirectional_target_complement_leakage(
                parent_transport,
                target_outer,
                source_outer,
            )
            for (name, value) in (
                (
                    "target_to_complement_leakage_weight",
                    directed.target_to_complement_leakage_weight,
                ),
                (
                    "complement_to_target_leakage_weight",
                    directed.complement_to_target_leakage_weight,
                ),
                ("maximum_bidirectional_leakage_weight", directed.maximum_leakage_weight),
            )
                _star_update_maximum!(maxima, maximum_contexts, name, value, item_context)
            end
        else
            _star_update_maximum!(
                maxima,
                maximum_contexts,
                "state_leakage_amplitude_audit",
                full_reconstruction.state_leakage_amplitude_audit,
                item_context,
            )
        end
        _star_update_maximum!(
            maxima,
            maximum_contexts,
            "raw_unitarity",
            raw_unitarity,
            item_context,
        )
        _star_update_maximum!(
            maxima,
            maximum_contexts,
            "normalized_polar_correction",
            polar_correction,
            item_context,
        )
        _star_update_maximum!(
            maxima,
            maximum_contexts,
            "alternative_path_residual",
            full_reconstruction.reconstruction_leakage_amplitude_audit,
            item_context,
        )
        source_hamiltonian = Diagonal(completed_energies)
        target_hamiltonian = Diagonal(completed_energies)
        if is_symmetrized_authority(context.authoritative_hamiltonian)
            source_rotation = rotations_lowdin[context.representative]
            target_rotation = rotations_lowdin[target]
            source_hamiltonian =
                source_rotation' *
                context.symmetrized_hamiltonians[context.representative] *
                source_rotation
            target_hamiltonian =
                target_rotation' * context.symmetrized_hamiltonians[target] * target_rotation
        end
        parent_covariance_metrics = if is_symmetrized_authority(context.authoritative_hamiltonian)
            parent_source_rotation = parent_rotations_lowdin[context.representative]
            parent_target_rotation = parent_rotations_lowdin[target]
            parent_source_action =
                context.operations[operation_index].antiunitary ? conj(parent_source_rotation) :
                parent_source_rotation
            parent_raw =
                parent_target_rotation' *
                context.selected_raw[operation_index] *
                parent_source_action
            parent_source_hamiltonian =
                parent_source_rotation' *
                context.symmetrized_hamiltonians[context.representative] *
                parent_source_rotation
            parent_target_hamiltonian =
                parent_target_rotation' *
                context.symmetrized_hamiltonians[target] *
                parent_target_rotation
            _star_hamiltonian_residual_metrics(
                parent_raw,
                parent_source_hamiltonian,
                parent_target_hamiltonian,
                context.operations[operation_index].antiunitary,
            )
        else
            _star_hamiltonian_residual_metrics(
                raw,
                source_hamiltonian,
                target_hamiltonian,
                context.operations[operation_index].antiunitary,
            )
        end
        covariance_metrics = _star_hamiltonian_residual_metrics(
            context.authoritative_hamiltonian isa SymmetrizedDFTHamiltonian ? polar : scoped_raw,
            source_hamiltonian[source_scope, source_scope],
            target_hamiltonian[target_scope, target_scope],
            context.operations[operation_index].antiunitary,
        )
        for (name, value) in (
            ("hamiltonian_covariance_after_ev", covariance_metrics.maximum_element_ev),
            ("hamiltonian_covariance_after_operator_ev", covariance_metrics.operator_ev),
            (
                "hamiltonian_covariance_after_source_column_l2_ev",
                covariance_metrics.maximum_source_column_l2_ev,
            ),
            (
                "hamiltonian_covariance_after_normalized_frobenius_ev",
                covariance_metrics.normalized_frobenius_ev,
            ),
            ("hamiltonian_covariance_after_frobenius_ev", covariance_metrics.frobenius_ev),
        )
            _star_update_maximum!(maxima, maximum_contexts, name, value, item_context)
        end
        for (name, value) in (
            (
                "parent_hamiltonian_covariance_after_ev_audit",
                parent_covariance_metrics.maximum_element_ev,
            ),
            (
                "parent_hamiltonian_covariance_after_operator_ev_audit",
                parent_covariance_metrics.operator_ev,
            ),
            (
                "parent_hamiltonian_covariance_after_normalized_frobenius_ev_audit",
                parent_covariance_metrics.normalized_frobenius_ev,
            ),
        )
            _star_update_maximum!(
                maxima,
                maximum_contexts,
                name,
                value,
                item_context * ",parent=full,audit_only",
            )
        end
        block_leakage = 0.0
        near_block_leakage = 0.0
        far_band_coupling = 0.0
        weighted = context.gauge.block_partition_policy isa HamiltonianWeightedPAWBlockPartition
        near_gap =
            weighted ?
            (context.gauge.block_partition_policy::HamiltonianWeightedPAWBlockPartition).near_gap_ev :
            Inf
        for target_band in 1:context.target_count, source_band in 1:context.target_count
            completed_labels[target_band] == completed_labels[source_band] && continue
            coupling = abs(raw[target_band, source_band])
            block_leakage = max(block_leakage, coupling)
            gap = abs(completed_energies[target_band] - completed_energies[source_band])
            if gap <= near_gap
                near_block_leakage = max(near_block_leakage, coupling)
            else
                far_band_coupling = max(far_band_coupling, coupling)
            end
        end
        _star_update_maximum!(
            maxima,
            maximum_contexts,
            "nondegenerate_block_leakage",
            block_leakage,
            item_context,
        )
        _star_update_maximum!(
            maxima,
            maximum_contexts,
            "near_block_leakage",
            near_block_leakage,
            item_context,
        )
        _star_update_maximum!(
            maxima,
            maximum_contexts,
            "far_band_coupling",
            far_band_coupling,
            item_context,
        )
    end
    return (
        completed_energies = completed_energies,
        shifts = shifts,
        points = points,
        parent_points = parent_points,
        rotations = rotations,
        canonical_operations = canonical_operations,
        parent_rotations = parent_rotations,
        parent_rotations_lowdin = parent_rotations_lowdin,
        parent_assignments = parent_assignments,
        target_principal_angles = target_principal_angles,
        target_projector_operator = target_projector_operator,
        target_projector_frobenius = target_projector_frobenius,
        parent_energy_shifts = parent_energy_shifts,
        parent_eigenvalues = parent_eigenvalues,
        selected_indices = selected_indices,
        maxima = maxima,
        maximum_contexts = maximum_contexts,
        workspace_eigenvectors = eigenvectors,
        selected_vectors = selected_vectors,
        target_anchor_sha256 = completion_data === nothing ? nothing :
                               completion_data.target_anchor_sha256,
        complement_basis = completion_data === nothing ? nothing : completion_data.complement_basis,
        complement_rotation = completion_data === nothing ? nothing :
                              completion_data.complement_rotation,
        target_complement_hamiltonian = completion_data === nothing ? nothing :
                                        completion_data.target_complement_hamiltonian,
        complement_hamiltonian = completion_data === nothing ? nothing :
                                 completion_data.complement_hamiltonian,
    )
end

# Construct the minimum first-order far-block rotation in the native-eigenstate
# frame.  The Reynolds-projected Hamiltonian is a real modification of the
# discrete Hamiltonian, not a postprocessed sewing matrix.  Near blocks are
# rediagonalized only after the Sylvester rotation is applied.
function _star_controlled_symmetrization_eigenpair(
    blocks::Vector{Vector{Int}},
    context::NamedTuple,
    correction::FarBandCovarianceCorrection,
)
    dimension = length(context.workspace)
    context.workspace == (1:dimension) || throw(
        ArgumentError("CONTROLLED_SYMMETRIZATION_HOLD: full PAW-S parent workspace is required"),
    )
    source_hamiltonian = Matrix(
        @view(
            context.lowdin.hamiltonians[context.representative][
                context.workspace,
                context.workspace,
            ]
        ),
    )
    source_hamiltonian .= 0.5 .* (source_hamiltonian + source_hamiltonian')
    symmetrized_hamiltonian = Matrix(Hermitian(context.hamiltonian_average))
    correction_hamiltonian = symmetrized_hamiltonian - source_hamiltonian
    native = eigen(Hermitian(source_hamiltonian))
    delta_native = native.vectors' * correction_hamiltonian * native.vectors

    block_id = zeros(Int, dimension)
    for (index, block) in enumerate(blocks)
        block_id[block] .= index
    end
    all(>(0), block_id) ||
        throw(ArgumentError("CONTROLLED_SYMMETRIZATION_HOLD: partition omits parent bands"))
    generator = zeros(ComplexF64, dimension, dimension)
    for left in 1:(dimension - 1), right in (left + 1):dimension
        block_id[left] == block_id[right] && continue
        gap = native.values[left] - native.values[right]
        abs(gap) > 1.0e-10 || throw(
            ArgumentError(
                "CONTROLLED_SYMMETRIZATION_HOLD: unresolved cross-block degeneracy " *
                "bands=$(left),$(right),gap=$(abs(gap)) eV",
            ),
        )
        value = -delta_native[left, right] / gap
        generator[left, right] = value
        generator[right, left] = -conj(value)
    end
    far_rotation_native = exp(generator)
    far_rotation = native.vectors * far_rotation_native
    after_far = Matrix(Hermitian(far_rotation' * symmetrized_hamiltonian * far_rotation))
    near_rotation = zeros(ComplexF64, dimension, dimension)
    values = zeros(Float64, dimension)
    for block in blocks
        decomposition = eigen(Hermitian(Matrix(@view(after_far[block, block]))))
        values[block] .= decomposition.values
        near_rotation[block, block] .= decomposition.vectors
    end
    vectors = far_rotation * near_rotation

    residual = after_far - Diagonal(diag(after_far))
    for block in blocks
        residual[block, block] .= 0.0
    end
    identity_matrix = Matrix{ComplexF64}(I, dimension, dimension)
    far_delta = far_rotation_native - identity_matrix
    total_native_rotation = far_rotation_native * near_rotation
    context_label = "star=$(context.star_index),rep=$(context.representative),parent=1:$(dimension)"
    maxima = Dict{String, Float64}(
        "controlled_hamiltonian_correction_operator_ev" => opnorm(correction_hamiltonian, 2),
        "controlled_hamiltonian_correction_frobenius_ev" => norm(correction_hamiltonian),
        "controlled_hamiltonian_correction_normalized_frobenius_ev" =>
            norm(correction_hamiltonian) / sqrt(dimension),
        "controlled_far_rotation_generator_operator" => opnorm(generator, 2),
        "controlled_far_rotation_operator" => opnorm(far_delta, 2),
        "controlled_far_rotation_normalized_frobenius" => norm(far_delta) / sqrt(dimension),
        "controlled_total_rotation_operator_report_only" =>
            opnorm(total_native_rotation - identity_matrix, 2),
        "controlled_sylvester_offblock_residual_operator_ev" => opnorm(residual, 2),
        "controlled_sylvester_offblock_residual_normalized_frobenius_ev" =>
            norm(residual) / sqrt(dimension),
    )
    contexts = Dict{String, String}(key => context_label for key in keys(maxima))
    return (values = values, vectors = vectors, maxima = maxima, maximum_contexts = contexts)
end

# Construct a deterministic orthonormal complement to a frozen target frame by
# pivoted modified Gram-Schmidt on projected coordinate vectors.  This is a
# rank-revealing QR equivalent whose tie-break is the smallest parent index.
function _star_deterministic_target_complement(
    target::Matrix{ComplexF64};
    rank_tolerance::Float64 = 1.0e-10,
)
    dimension, target_count = size(target)
    complement_count = dimension - target_count
    complement_count >= 0 || throw(ArgumentError("COMPLEMENT_RANK_HOLD: target exceeds parent"))
    target_norm = maximum(abs, target' * target - I)
    target_norm <= rank_tolerance ||
        throw(ArgumentError("COMPLEMENT_RANK_HOLD: frozen target is not orthonormal"))
    projector = Matrix{ComplexF64}(I, dimension, dimension) - target * target'
    basis = zeros(ComplexF64, dimension, complement_count)
    pivots = Int[]
    used = falses(dimension)
    for column in 1:complement_count
        best_index = 0
        best_vector = zeros(ComplexF64, dimension)
        best_norm = -Inf
        for coordinate in 1:dimension
            used[coordinate] && continue
            candidate = copy(@view(projector[:, coordinate]))
            column > 1 && (
                candidate .-=
                    @view(basis[:, 1:(column - 1)]) *
                    (@view(basis[:, 1:(column - 1)])' * candidate)
            )
            candidate_norm = norm(candidate)
            if candidate_norm > best_norm + 8eps(Float64) || (
                abs(candidate_norm - best_norm) <= 8eps(Float64) &&
                (best_index == 0 || coordinate < best_index)
            )
                best_index = coordinate
                best_norm = candidate_norm
                best_vector = candidate
            end
        end
        best_norm > rank_tolerance || throw(
            ArgumentError(
                "COMPLEMENT_RANK_HOLD: projected parent rank $(column - 1) is smaller than $(complement_count)",
            ),
        )
        best_vector ./= best_norm
        pivot = argmax(abs.(best_vector))
        phase = best_vector[pivot]
        abs(phase) > eps(Float64) && (best_vector .*= conj(phase) / abs(phase))
        basis[:, column] .= best_vector
        used[best_index] = true
        push!(pivots, best_index)
    end
    complement_norm = complement_count == 0 ? 0.0 : maximum(abs, basis' * basis - I)
    target_overlap = complement_count == 0 ? 0.0 : maximum(abs, target' * basis)
    projector_residual = maximum(abs, projector - basis * basis')
    maximum((complement_norm, target_overlap, projector_residual)) <= 50rank_tolerance || throw(
        ArgumentError(
            "COMPLEMENT_RANK_HOLD: deterministic complement failed orthogonal reconstruction",
        ),
    )
    return (
        basis = basis,
        pivots = pivots,
        norm_residual = complement_norm,
        target_overlap = target_overlap,
        projector_residual = projector_residual,
    )
end

# Freeze the already completed target eigenpairs and diagonalize only H_CC.
# H_TC is checked before any outer-state rotation; target and complement are
# never mixed by this completion policy.
function _star_frozen_target_complement_eigenpair(
    target_values::Vector{Float64},
    target_vectors::Matrix{ComplexF64},
    context::NamedTuple,
    authority::SymmetrizedDFTHamiltonian,
    ;
    fix_complement_kramers::Bool = true,
)
    dimension = length(context.workspace)
    target_count = length(target_values)
    target_indices = collect(context.target_indices)
    length(target_indices) == target_count ||
        throw(ArgumentError("TARGET_ANCHOR_DRIFT_HOLD: target rank differs from frozen band range"))
    complement_indices = setdiff(collect(1:dimension), target_indices)
    complement = _star_deterministic_target_complement(target_vectors)
    hamiltonian = Matrix(Hermitian(context.hamiltonian_average))
    h_tc = target_vectors' * hamiltonian * complement.basis
    h_tc_maximum = maximum(abs, h_tc; init = 0.0)
    threshold = authority.completion.target_complement_max_element_ev
    get(context, :construction_policy, :strict) == :diagnostic ||
        h_tc_maximum <= threshold ||
        throw(
            ArgumentError(
                "TARGET_COMPLEMENT_COUPLING_HOLD: maximum_abs_H_TC=$(h_tc_maximum) exceeds $(threshold); " *
                "star=$(context.star_index),rep=$(context.representative)",
            ),
        )
    h_cc = Matrix(Hermitian(complement.basis' * hamiltonian * complement.basis))
    outer_values = Float64[]
    outer_vectors = zeros(ComplexF64, dimension, 0)
    kramers_pairs = 0
    kramers_residual = 0.0
    assignment = Int[]
    if !isempty(complement_indices)
        decomposition = eigen(Hermitian(h_cc))
        outer_values = Vector{Float64}(decomposition.values)
        outer_vectors = complement.basis * Matrix{ComplexF64}(decomposition.vectors)
        _star_canonicalize_eigenvectors!(
            outer_vectors,
            outer_values,
            min(context.gauge.buffer_policy.cluster_tolerance_ev, 1.0e-10),
        )
        if fix_complement_kramers
            kramers_pairs, kramers_residual = _star_fix_kramers_pairs!(
                outer_vectors,
                outer_values,
                context.selected_raw,
                context.transports,
                context.operations,
                context.representative,
                context.gauge.thresholds,
            )
        end
        assignment = hungarian_maximum_assignment(abs2.(outer_vectors[complement_indices, :]))
    end
    values = zeros(Float64, dimension)
    vectors = zeros(ComplexF64, dimension, dimension)
    values[target_indices] .= target_values
    vectors[:, target_indices] .= target_vectors
    for (row, parent_index) in enumerate(complement_indices)
        outer_column = assignment[row]
        values[parent_index] = outer_values[outer_column]
        vectors[:, parent_index] .= @view(outer_vectors[:, outer_column])
    end
    target_values_after = copy(values[target_indices])
    target_vectors_after = copy(vectors[:, target_indices])
    target_energy_drift = maximum(abs, target_values_after - target_values; init = 0.0)
    target_vector_drift = maximum(abs, target_vectors_after - target_vectors; init = 0.0)
    anchor_before = bytes2hex(
        SHA.sha256(
            vcat(reinterpret(UInt8, vec(target_values)), reinterpret(UInt8, vec(target_vectors))),
        ),
    )
    anchor_after = bytes2hex(
        SHA.sha256(
            vcat(
                reinterpret(UInt8, vec(target_values_after)),
                reinterpret(UInt8, vec(target_vectors_after)),
            ),
        ),
    )
    target_energy_drift == 0.0 && target_vector_drift == 0.0 && anchor_before == anchor_after ||
        throw(ArgumentError("TARGET_ANCHOR_DRIFT_HOLD: frozen target arrays changed"))
    identity_residual = maximum(abs, vectors' * vectors - I)
    isfinite(identity_residual) ||
        throw(ArgumentError("NONFINITE_STRUCTURAL_HOLD: nonfinite complement completion"))
    h_tc_operator = opnorm(h_tc, 2)
    h_tc_column_l2 = maximum((norm(@view(h_tc[:, column])) for column in axes(h_tc, 2)); init = 0.0)
    h_tc_frobenius = norm(h_tc)
    context_label = "star=$(context.star_index),rep=$(context.representative),target=$(first(context.target_indices)):$(last(context.target_indices))"
    maxima = Dict{String, Float64}(
        "target_anchor_wfc_maximum_drift" => target_vector_drift,
        "target_anchor_energy_maximum_drift_ev" => target_energy_drift,
        "target_anchor_rotation_maximum_drift" => 0.0,
        "target_complement_maximum_element_ev" => h_tc_maximum,
        "target_complement_operator_ev" => h_tc_operator,
        "target_complement_maximum_column_l2_ev" => h_tc_column_l2,
        "target_complement_frobenius_ev" => h_tc_frobenius,
        "target_complement_normalized_frobenius_ev" =>
            h_tc_frobenius / sqrt(max(target_count, 1)),
        "complement_norm_residual" => complement.norm_residual,
        "complement_target_overlap" => complement.target_overlap,
        "complement_projector_residual" => complement.projector_residual,
        "complement_parent_unitarity" => identity_residual,
        "complement_kramers_pair_residual" => kramers_pairs > 0 ? kramers_residual : 0.0,
    )
    contexts = Dict{String, String}(key => context_label for key in keys(maxima))
    return (
        values = values,
        vectors = vectors,
        target_values = target_values,
        target_vectors = target_vectors,
        target_indices = target_indices,
        target_anchor_sha256 = anchor_before,
        complement_basis = complement.basis,
        complement_rotation = complement.basis' * vectors[:, complement_indices],
        target_complement_hamiltonian = h_tc,
        complement_hamiltonian = h_cc,
        maxima = maxima,
        maximum_contexts = contexts,
    )
end

"""Return every local physical-gate violation for a partition candidate."""
function _star_partition_candidate_violations(
    solution,
    thresholds::PAWGaugeThresholds,
    partition_policy::AbstractPAWBlockPartitionPolicy,
    authority::AbstractAuthoritativeHamiltonian,
    target_scope_active::Bool = false,
)
    violations = NamedTuple[]
    gates = [
        ("hamiltonian_covariance_after_ev", thresholds.hamiltonian_covariance_ev),
        ("hamiltonian_covariance_after_operator_ev", thresholds.hamiltonian_covariance_ev),
        ("hamiltonian_covariance_after_source_column_l2_ev", thresholds.hamiltonian_covariance_ev),
        (
            "hamiltonian_covariance_after_normalized_frobenius_ev",
            thresholds.hamiltonian_covariance_ev,
        ),
        ("projected_eigen_residual_ev", thresholds.projected_eigen_residual_ev),
    ]
    if authority isa NativeDFTHamiltonian && !target_scope_active
        append!(
            gates,
            [
                ("wfc_rotation_reconstruction", thresholds.wfc_rotation_reconstruction),
                ("completed_paw_s_norm", thresholds.paw_s_norm),
                ("alternative_path_residual", thresholds.path_independence),
                ("kramers_pair_residual", thresholds.path_independence),
                ("maximum_energy_shift_ev", thresholds.maximum_energy_shift_ev),
                ("rms_energy_shift_ev", thresholds.rms_energy_shift_ev),
                (
                    partition_policy isa HamiltonianWeightedPAWBlockPartition ?
                    "near_block_leakage" : "nondegenerate_block_leakage",
                    thresholds.nondegenerate_block_leakage,
                ),
            ],
        )
    else
        append!(
            gates,
            [
                ("target_reconstruction_leakage_weight", thresholds.target_leakage_weight),
                ("target_state_leakage_weight", thresholds.target_leakage_weight),
                ("target_to_complement_leakage_weight", thresholds.target_leakage_weight),
                ("complement_to_target_leakage_weight", thresholds.target_leakage_weight),
                ("raw_unitarity", thresholds.raw_unitarity),
                ("normalized_polar_correction", thresholds.normalized_polar_correction),
            ],
        )
    end
    if authority isa SymmetrizedDFTHamiltonian
        threshold = authority.completion.target_complement_max_element_ev
        push!(gates, ("target_complement_maximum_element_ev", threshold))
        for name in (
            "target_anchor_wfc_maximum_drift",
            "target_anchor_energy_maximum_drift_ev",
            "target_anchor_rotation_maximum_drift",
        )
            value = solution.maxima[name]
            value == 0.0 || push!(
                violations,
                (
                    name = name,
                    value = value,
                    threshold = 0.0,
                    ratio = Inf,
                    context = get(solution.maximum_contexts, name, "NOT_RECORDED"),
                ),
            )
        end
    end
    if haskey(solution.maxima, "star1_strict_raw_group_law")
        push!(gates, ("star1_strict_raw_group_law", thresholds.group_law))
    end
    if haskey(solution.maxima, "star1_strict_raw_cocycle")
        push!(gates, ("star1_strict_raw_cocycle", thresholds.cocycle))
    end
    for (name, threshold) in gates
        value = solution.maxima[name]
        value <= threshold || push!(
            violations,
            (
                name = name,
                value = value,
                threshold = threshold,
                ratio = value / threshold,
                context = get(solution.maximum_contexts, name, "NOT_RECORDED"),
            ),
        )
    end
    sort!(violations; by = item -> (-item.ratio, item.name))
    return violations
end

# Record controlled H_sym-minus-H_native differences against their frozen
# references.  They remain hard gates for native/legacy authority but are
# audit-only for the explicitly selected symmetrized Hamiltonian.
function _star_controlled_native_difference_evidence!(
    violations,
    solution,
    thresholds::ControlledHamiltonianSymmetryThresholds,
    authority::AbstractAuthoritativeHamiltonian,
    context::AbstractString,
)
    audit_only = is_symmetrized_authority(authority)
    audit_violation_count = 0
    audit_maximum_ratio = 0.0
    audit_worst_context = "WITHIN_AUDIT_REFERENCE"
    for (name, threshold) in (
        ("controlled_far_rotation_operator", thresholds.far_rotation_operator),
        (
            "controlled_far_rotation_normalized_frobenius",
            thresholds.far_rotation_normalized_frobenius,
        ),
        (
            "controlled_hamiltonian_correction_operator_ev",
            thresholds.hamiltonian_correction_operator_ev,
        ),
        (
            "controlled_hamiltonian_correction_normalized_frobenius_ev",
            thresholds.hamiltonian_correction_normalized_frobenius_ev,
        ),
    )
        value = solution.maxima[name]
        ratio = value / threshold
        metric_context = get(solution.maximum_contexts, name, String(context))
        if audit_only
            solution.maxima["$(name)_audit_reference_ratio"] = ratio
            solution.maximum_contexts["$(name)_audit_reference_ratio"] = metric_context
            if ratio > 1.0
                audit_violation_count += 1
                if ratio > audit_maximum_ratio
                    audit_maximum_ratio = ratio
                    audit_worst_context = "metric=$(name); $(metric_context)"
                end
            end
        elseif value > threshold
            push!(
                violations,
                (
                    name = name,
                    value = value,
                    threshold = threshold,
                    ratio = ratio,
                    context = metric_context,
                ),
            )
        end
    end
    if audit_only
        audit_status =
            audit_violation_count > 0 ? "AUDIT_REFERENCE_EXCEEDED" : "WITHIN_AUDIT_REFERENCE"
        solution.maxima["native_difference_audit_reference_exceeded"] =
            audit_violation_count > 0 ? 1.0 : 0.0
        solution.maxima["native_difference_audit_violation_count"] = Float64(audit_violation_count)
        solution.maxima["native_difference_audit_maximum_ratio"] = audit_maximum_ratio
        solution.maximum_contexts["native_difference_audit_reference_exceeded"] = "$(context),$(audit_status)"
        solution.maximum_contexts["native_difference_audit_violation_count"] = "$(context),$(audit_status)"
        solution.maximum_contexts["native_difference_audit_maximum_ratio"] = audit_worst_context
    end
    sort!(violations; by = item -> (-item.ratio, item.name))
    return violations
end

# Classify failures only after a candidate has completed the physical
# Hamiltonian restoration and the completed WFC/projector reconstruction.  In
# particular, the presence of FarBandCovarianceCorrection must not collapse
# every downstream physical failure into CONTROLLED_SYMMETRIZATION_HOLD.
function _star_post_symmetrization_failure_code(name::AbstractString)
    startswith(name, "target_anchor_") && return "TARGET_ANCHOR_DRIFT_HOLD"
    name == "target_complement_maximum_element_ev" && return "TARGET_COMPLEMENT_COUPLING_HOLD"
    name == "wfc_rotation_reconstruction" && return "POST_SYMMETRIZATION_RECONSTRUCTION_HOLD"
    startswith(name, "hamiltonian_covariance_after") && return "HAMILTONIAN_COVARIANCE_HOLD"
    name in ("projected_eigen_residual_ev", "symmetrized_projected_eigen_residual_ev") &&
        return "HAMILTONIAN_COVARIANCE_HOLD"
    name in (
        "completed_paw_s_norm",
        "target_reconstruction_leakage_weight",
        "target_state_leakage_weight",
        "target_to_complement_leakage_weight",
        "complement_to_target_leakage_weight",
        "alternative_path_residual",
        "kramers_pair_residual",
        "raw_unitarity",
        "normalized_polar_correction",
    ) && return "PAW_PROPAGATION_IMPLEMENTATION_HOLD"
    name in ("star1_strict_raw_group_law", "star1_strict_raw_cocycle") && return "PAW_SEWING_HOLD"
    startswith(name, "controlled_") && return "CONTROLLED_SYMMETRIZATION_HOLD"
    name in ("near_block_leakage", "nondegenerate_block_leakage") &&
        return "BLOCK_PARTITION_PHYSICS_HOLD"
    return "BLOCK_PARTITION_PHYSICS_HOLD"
end

"""
Build a completed target-rank wavefunction field from representative k-star frames.

Independent native eigenvectors enter only through a bounded parent workspace.
One PAW-S-orthogonal representative frame is rediagonalized after magnetic
Reynolds averaging; all other star points are generated by exact symmetry.
"""
function _build_star_covariant_paw_payload(config::SymmetryCovariantWavefunctionPreparationConfig)
    gauge = config.wavefunction_gauge_backend::StarCovariantPAWGauge
    target_range = something(config.source.band_range)
    target_count = length(target_range)
    # Every available native band must remain visible while measuring omitted PAW-S
    # weight.  The finite-buffer policy limits the retained workspace, not the audit
    # visibility; reading only target +/- max_extra_bands could manufacture closure by
    # hiding leakage into the remaining native bands.
    parent_source = _star_source_with_band_range(config.source, nothing)
    raw_native = _read_augmentation_aware_native_source(parent_source)
    parent_count = size(first(raw_native.kpoints).coefficients, 1)
    parent_range = 1:parent_count
    if config.target_subspace_contract !== nothing
        contract = something(config.target_subspace_contract)
        scope = contract.qualification_scope
        size(scope.outer_mask) == (parent_count, length(raw_native.kpoints)) || throw(
            ArgumentError(
                "TARGET_MASK_DIMENSION_HOLD: contract mask size $(size(scope.outer_mask)) " *
                "differs from native parent ($(parent_count), $(length(raw_native.kpoints)))",
            ),
        )
    end
    last(target_range) <= parent_count || throw(
        ArgumentError(
            is_symmetrized_authority(config.authoritative_hamiltonian) ?
            "PRE_SYMMETRIZATION_STRUCTURAL_HOLD: target bands exceed the native parent" :
            "FINITE_BUFFER_HOLD: target bands exceed the native parent",
        ),
    )
    output_target_indices = target_range
    inventory = detect_magnetic_symmetry_inventory(
        raw_native.structure;
        include_time_reversal = config.source.include_time_reversal,
        symmetry_tolerance = config.symmetry_tolerance,
    )
    operations = inventory.operations
    kpoints = Matrix{Float64}(
        reduce(vcat, (transpose(point.k_fractional) for point in raw_native.kpoints)),
    )
    kpoint_map, reciprocal_shifts =
        build_canonical_kpoint_action(operations, kpoints; tolerance = 1.0e-8)
    raw_metric, native_norm, native_norm_worst = _strict_sewing_metric(parent_source, raw_native)
    symmetrized_authority = is_symmetrized_authority(config.authoritative_hamiltonian)
    target_scope_active = config.target_subspace_contract !== nothing
    lowdin = _star_lowdin_native(
        raw_native,
        raw_metric,
        gauge.thresholds.paw_s_norm;
        enforce_residual = !target_scope_active,
    )
    native = lowdin.native
    metric = lowdin.metric
    target_lowdin_norm, target_lowdin_norm_worst = if target_scope_active
        _star_scoped_generalized_norm_from_metric(
            metric,
            native,
            something(config.target_subspace_contract).qualification_scope.outer_mask,
        )
    else
        (lowdin.maximum_after, lowdin.worst_context)
    end
    target_lowdin_norm <= gauge.thresholds.paw_s_norm || throw(
        ArgumentError(
            "PAW_PROPAGATION_IMPLEMENTATION_HOLD: target-scoped Lowdin PAW-S norm " *
            "$(target_lowdin_norm) exceeds $(gauge.thresholds.paw_s_norm); " *
            "$(repr(target_lowdin_norm_worst))",
        ),
    )
    stars = _star_orbits(kpoint_map)
    nk = length(native.kpoints)
    final_points = Vector{PlaneWaveKPoint}(undef, nk)
    rotations = zeros(ComplexF64, parent_count, target_count, nk)
    parent_symmetrized_energies = symmetrized_authority ? zeros(Float64, parent_count, nk) : nothing
    parent_symmetrized_rotations =
        symmetrized_authority ? zeros(ComplexF64, parent_count, parent_count, nk) : nothing
    representative_native_hamiltonians =
        symmetrized_authority ? zeros(ComplexF64, parent_count, parent_count, length(stars)) :
        nothing
    representative_symmetrized_hamiltonians =
        symmetrized_authority ? zeros(ComplexF64, parent_count, parent_count, length(stars)) :
        nothing
    representative_raw_transports =
        symmetrized_authority ?
        zeros(ComplexF64, parent_count, parent_count, length(operations), length(stars)) : nothing
    target_principal_angles = symmetrized_authority ? zeros(Float64, target_count, nk) : nothing
    target_projector_operator = symmetrized_authority ? zeros(Float64, nk) : nothing
    target_projector_frobenius = symmetrized_authority ? zeros(Float64, nk) : nothing
    parent_band_assignments = symmetrized_authority ? zeros(Int, parent_count, nk) : nothing
    target_energy_shifts_by_star =
        symmetrized_authority ? zeros(Float64, target_count, length(stars)) : nothing
    parent_energy_shifts_by_kpoint =
        symmetrized_authority ? zeros(Float64, parent_count, nk) : nothing
    symmetrized_target_authority = symmetrized_authority && target_scope_active
    target_anchor_sha256_by_star = symmetrized_target_authority ? fill("", length(stars)) : nothing
    complement_bases =
        symmetrized_target_authority ?
        zeros(ComplexF64, parent_count, parent_count, length(stars)) : nothing
    complement_rotations =
        symmetrized_target_authority ?
        zeros(ComplexF64, parent_count, parent_count, length(stars)) : nothing
    target_complement_hamiltonians =
        symmetrized_target_authority ?
        zeros(ComplexF64, parent_count, parent_count, length(stars)) : nothing
    complement_hamiltonians =
        symmetrized_target_authority ?
        zeros(ComplexF64, parent_count, parent_count, length(stars)) : nothing
    representative_for_kpoint = zeros(Int, nk)
    canonical_operation_for_kpoint = zeros(Int, nk)
    star_representatives = first.(stars)
    extra_bands_per_star = zeros(Int, length(stars))
    maxima = Dict{String, Float64}(
        "native_paw_s_norm_before_lowdin" => lowdin.maximum_before,
        "native_paw_s_norm_after_lowdin" => lowdin.maximum_after,
        "native_generalized_norm_before_lowdin" => native_norm,
        "target_scoped_lowdin_paw_s_norm" => target_lowdin_norm,
        "raw_preflight_diagnostic_exceeded" => 0.0,
        "raw_preflight_diagnostic_maximum_ratio" => 0.0,
        "pre_symmetrization_lowdin_paw_s_norm" => lowdin.maximum_after,
        "pre_symmetrization_reconstruction_leakage_amplitude_audit" => 0.0,
        "pre_symmetrization_target_reconstruction_leakage_weight" => 0.0,
        "pre_symmetrization_target_state_leakage_weight" => 0.0,
        "pre_symmetrization_raw_unitarity" => 0.0,
        "pre_symmetrization_normalized_polar_correction" => 0.0,
        "pre_symmetrization_pseudo_component_maximum" => 0.0,
        "pre_symmetrization_augmentation_component_maximum" => 0.0,
        "pre_symmetrization_total_paw_component_maximum" => 0.0,
        "pre_symmetrization_cancellation_condition_maximum" => 0.0,
        "pre_symmetrization_raw_group_law" => 0.0,
        "pre_symmetrization_raw_cocycle" => 0.0,
        "pre_symmetrization_raw_alternative_path_residual" => 0.0,
        "pre_symmetrization_raw_near_block_leakage" => 0.0,
        "parent_reconstruction_leakage_amplitude_audit" => 0.0,
        "buffer_target_leakage" => 0.0,
        "hamiltonian_covariance_before_ev" => 0.0,
        "hamiltonian_covariance_after_ev" => 0.0,
        "hamiltonian_covariance_after_operator_ev" => 0.0,
        "hamiltonian_covariance_after_source_column_l2_ev" => 0.0,
        "hamiltonian_covariance_after_normalized_frobenius_ev" => 0.0,
        "hamiltonian_covariance_after_frobenius_ev" => 0.0,
        "hamiltonian_reynolds_residual_ev" => 0.0,
        "projected_eigen_residual_ev" => 0.0,
        "native_fidelity_projected_eigen_residual_ev" => 0.0,
        "symmetrized_projected_eigen_residual_ev" => 0.0,
        "target_maximum_principal_angle_rad" => 0.0,
        "target_rms_sine_principal_angle" => 0.0,
        "target_projector_difference_operator" => 0.0,
        "target_projector_difference_frobenius" => 0.0,
        "symmetrized_hamiltonian_correction_operator_ev" => 0.0,
        "symmetrized_hamiltonian_correction_frobenius_ev" => 0.0,
        "symmetrized_hamiltonian_correction_normalized_frobenius_ev" => 0.0,
        "symmetrized_parent_maximum_energy_shift_ev" => 0.0,
        "symmetrized_parent_rms_energy_shift_ev" => 0.0,
        "wfc_rotation_reconstruction" => 0.0,
        "target_reconstruction_leakage_weight" => 0.0,
        "target_state_leakage_weight" => 0.0,
        "target_to_complement_leakage_weight" => 0.0,
        "complement_to_target_leakage_weight" => 0.0,
        "maximum_bidirectional_leakage_weight" => 0.0,
        "state_leakage_amplitude_audit" => 0.0,
        "completed_paw_s_norm" => 0.0,
        "alternative_path_residual" => 0.0,
        "raw_unitarity" => 0.0,
        "normalized_polar_correction" => 0.0,
        "nondegenerate_block_leakage" => 0.0,
        "near_block_leakage" => 0.0,
        "far_band_coupling" => 0.0,
        "far_residual_count" => 0.0,
        "tolerated_far_residual_count" => 0.0,
        "maximum_pair_hamiltonian_residual_ev" => 0.0,
        "maximum_far_operator_residual_ev" => 0.0,
        "maximum_far_source_column_l2_residual_ev" => 0.0,
        "maximum_far_normalized_frobenius_residual_ev" => 0.0,
        "maximum_far_frobenius_residual_ev" => 0.0,
        "block_partition_evidence_count" => 0.0,
        "block_partition_evidence_orbit_count" => 0.0,
        "block_partition_search_states" => 0.0,
        "block_partition_maximum_evidence_gap_ev" => 0.0,
        "block_partition_maximum_evidence_coupling" => 0.0,
        "block_partition_maximum_block_span_ev" => 0.0,
        "block_partition_maximum_block_bands" => 0.0,
        "kramers_pair_residual" => 0.0,
        "maximum_energy_shift_ev" => 0.0,
        "rms_energy_shift_ev" => 0.0,
        "controlled_hamiltonian_correction_operator_ev" => 0.0,
        "controlled_hamiltonian_correction_frobenius_ev" => 0.0,
        "controlled_hamiltonian_correction_normalized_frobenius_ev" => 0.0,
        "controlled_far_rotation_generator_operator" => 0.0,
        "controlled_far_rotation_operator" => 0.0,
        "controlled_far_rotation_normalized_frobenius" => 0.0,
        "controlled_total_rotation_operator_report_only" => 0.0,
        "controlled_sylvester_offblock_residual_operator_ev" => 0.0,
        "controlled_sylvester_offblock_residual_normalized_frobenius_ev" => 0.0,
        "controlled_symmetrization_strict_violation_count" => 0.0,
        "controlled_symmetrization_strict_maximum_ratio" => 0.0,
    )
    contexts = Dict(
        "native_paw_s_norm_before_lowdin" => lowdin.worst_context,
        "native_generalized_norm_before_lowdin" => repr(native_norm_worst),
        "target_scoped_lowdin_paw_s_norm" => repr(target_lowdin_norm_worst),
        "pre_symmetrization_lowdin_paw_s_norm" => lowdin.worst_context,
    )
    if target_scope_active
        _star_record_raw_preflight_diagnostic!(
            maxima,
            contexts,
            "lowdin_paw_s_norm",
            lowdin.maximum_after,
            gauge.thresholds.paw_s_norm,
            lowdin.worst_context,
        )
    end
    energy_shift_values = Float64[]
    parent_energy_shift_values = Float64[]
    limited_scope_reached = false
    completed_star_count = 0
    last_completed_star_index = 0
    selected_star_indices = config.selected_star_indices
    if selected_star_indices !== nothing
        maximum(something(selected_star_indices)) <= length(stars) || throw(
            ArgumentError(
                "PRE_SYMMETRIZATION_STRUCTURAL_HOLD: selected star index exceeds $(length(stars))",
            ),
        )
    end

    for (star_index, star) in enumerate(stars)
        selected_star_indices !== nothing &&
            !(star_index in something(selected_star_indices)) &&
            continue
        representative = first(star)
        authority_indices_by_kpoint = if symmetrized_target_authority
            _star_target_indices_by_kpoint(
                something(config.target_subspace_contract),
                star,
                parent_range,
            )
        else
            Dict(kpoint => collect(output_target_indices) for kpoint in star)
        end
        authority_indices = authority_indices_by_kpoint[representative]
        authority_count = length(authority_indices)
        transports = Vector{NamedTuple}(undef, length(operations))
        raw_transports = Matrix{ComplexF64}[]
        for operation_index in eachindex(operations)
            target = kpoint_map[operation_index, representative]
            transport = _star_transport(
                metric,
                native,
                representative,
                operation_index,
                target,
                @view(reciprocal_shifts[:, operation_index, representative]),
                operations,
            )
            transports[operation_index] = merge(transport, (target_kpoint = target,))
            push!(raw_transports, transport.raw)
            context = "star=$(star_index),rep=$(representative),op=$(operation_index),target=$(target)"
            if symmetrized_authority
                pseudo_maximum = maximum(abs, transport.pseudo; init = 0.0)
                augmentation_maximum = maximum(abs, transport.augmentation; init = 0.0)
                total_maximum = maximum(abs, transport.raw; init = 0.0)
                cancellation_condition = maximum(
                    (abs.(transport.pseudo) .+ abs.(transport.augmentation)) ./
                    max.(abs.(transport.raw), eps(Float64));
                    init = 0.0,
                )
                for (key, value) in (
                    ("pre_symmetrization_pseudo_component_maximum", pseudo_maximum),
                    ("pre_symmetrization_augmentation_component_maximum", augmentation_maximum),
                    ("pre_symmetrization_total_paw_component_maximum", total_maximum),
                    ("pre_symmetrization_cancellation_condition_maximum", cancellation_condition),
                )
                    _star_update_maximum!(maxima, contexts, key, value, context)
                end
                target_authority_indices = authority_indices_by_kpoint[target]
                target_reconstruction = _strict_reconstruction_diagnostics(
                    metric,
                    native.kpoints[target].coefficients[target_authority_indices, :, :],
                    transport.transformed[authority_indices, :, :],
                    metric.projectors[target][target_authority_indices, :, :],
                    transport.transformed_projectors[authority_indices, :, :],
                    transport.raw[target_authority_indices, authority_indices],
                )
                _star_record_raw_preflight_diagnostic!(
                    maxima,
                    contexts,
                    "target_reconstruction_leakage_weight",
                    target_reconstruction.reconstruction_leakage_weight,
                    gauge.thresholds.target_leakage_weight,
                    context * ",target_rank=$(authority_count)",
                )
                _star_record_raw_preflight_diagnostic!(
                    maxima,
                    contexts,
                    "target_state_leakage_weight",
                    target_reconstruction.state_leakage_weight,
                    gauge.thresholds.target_leakage_weight,
                    context * ",target_rank=$(authority_count)",
                )
            end
        end
        target_scope_active && _star_raw_preflight_strict_diagnostics!(
            config,
            parent_source,
            native,
            metric,
            operations,
            star,
            star_index,
            gauge,
            maxima,
            contexts,
        )
        representative_energies = native.kpoints[representative].energies_ev
        controlled = gauge.hamiltonian_correction isa FarBandCovarianceCorrection
        workspace, buffer_leakage = if controlled
            (parent_range, 0.0)
        else
            _star_select_buffer(
                raw_transports,
                representative_energies,
                output_target_indices,
                gauge.buffer_policy,
                gauge.thresholds.state_leakage_amplitude;
                construction_policy = config.construction_policy,
            )
        end
        extra_bands_per_star[star_index] =
            length(workspace) - (symmetrized_target_authority ? authority_count : target_count)
        _star_update_maximum!(
            maxima,
            contexts,
            "buffer_target_leakage",
            buffer_leakage,
            "star=$(star_index),rep=$(representative),workspace=$(first(workspace)):$(last(workspace))",
        )
        for operation_index in eachindex(operations)
            target = transports[operation_index].target_kpoint
            selected_reconstruction = _strict_reconstruction_diagnostics(
                metric,
                native.kpoints[target].coefficients,
                transports[operation_index].transformed[workspace, :, :],
                metric.projectors[target],
                transports[operation_index].transformed_projectors[workspace, :, :],
                transports[operation_index].raw[:, workspace],
            )
            context = "star=$(star_index),rep=$(representative),op=$(operation_index),target=$(target),workspace=$(first(workspace)):$(last(workspace))"
            _star_update_maximum!(
                maxima,
                contexts,
                "parent_reconstruction_leakage_amplitude_audit",
                selected_reconstruction.reconstruction_leakage_amplitude_audit,
                context,
            )
            if target_scope_active
                _star_update_maximum!(
                    maxima,
                    contexts,
                    "parent_state_leakage_amplitude_audit",
                    selected_reconstruction.state_leakage_amplitude_audit,
                    context,
                )
            elseif config.construction_policy == :strict &&
                   selected_reconstruction.reconstruction_leakage_amplitude_audit >
                   gauge.thresholds.wfc_rotation_reconstruction
                ArgumentError(
                    "FINITE_BUFFER_HOLD: selected PAW-S reconstruction " *
                    "$(selected_reconstruction.reconstruction_leakage_amplitude_audit) exceeds " *
                    "$(gauge.thresholds.wfc_rotation_reconstruction); $(context)",
                ) |> throw
            end
        end
        selected_raw = [Matrix(@view(raw[workspace, workspace])) for raw in raw_transports]
        selected_target_energies = [
            native.kpoints[transports[index].target_kpoint].energies_ev[workspace] for
            index in eachindex(transports)
        ]
        workspace_count = length(workspace)
        polar_transports = Matrix{ComplexF64}[]
        target_hamiltonians = Matrix{ComplexF64}[]
        antiunitary_transports = Bool[]
        for operation_index in eachindex(operations)
            target = transports[operation_index].target_kpoint
            raw = selected_raw[operation_index]
            polar = if controlled
                raw
            else
                decomposition = svd(raw)
                decomposition.U * decomposition.Vt
            end
            correction = controlled ? 0.0 : norm(polar - raw) / sqrt(workspace_count)
            context = "star=$(star_index),rep=$(representative),op=$(operation_index),target=$(target)"
            _star_update_maximum!(
                maxima,
                contexts,
                target_scope_active ? "parent_normalized_polar_correction_audit" :
                "normalized_polar_correction",
                correction,
                context,
            )
            identity_matrix = Matrix{ComplexF64}(I, workspace_count, workspace_count)
            unitarity = max(
                maximum(abs, raw' * raw - identity_matrix),
                maximum(abs, raw * raw' - identity_matrix),
            )
            _star_update_maximum!(
                maxima,
                contexts,
                target_scope_active ? "parent_raw_unitarity_audit" : "raw_unitarity",
                unitarity,
                context,
            )
            target_hamiltonian = Matrix(@view(lowdin.hamiltonians[target][workspace, workspace]))
            push!(polar_transports, polar)
            push!(target_hamiltonians, target_hamiltonian)
            push!(antiunitary_transports, operations[operation_index].antiunitary)
            source_hamiltonian =
                Matrix(@view(lowdin.hamiltonians[representative][workspace, workspace]))
            source_action =
                operations[operation_index].antiunitary ? conj(source_hamiltonian) :
                source_hamiltonian
            covariance_before = maximum(abs, target_hamiltonian * raw - raw * source_action)
            _star_update_maximum!(
                maxima,
                contexts,
                "hamiltonian_covariance_before_ev",
                covariance_before,
                context,
            )
            symmetrized_authority && _star_record_raw_preflight_diagnostic!(
                maxima,
                contexts,
                "hamiltonian_covariance_ev",
                covariance_before,
                gauge.thresholds.hamiltonian_covariance_ev,
                context,
            )
        end
        hamiltonian_average = _star_reynolds_hamiltonian(
            controlled ? selected_raw : polar_transports,
            target_hamiltonians,
            antiunitary_transports,
        )
        target_reynolds = if symmetrized_target_authority
            _star_target_reynolds_hamiltonians(
                metric,
                native,
                lowdin,
                star,
                workspace,
                operations,
                kpoint_map,
                reciprocal_shifts,
                something(config.target_subspace_contract),
                gauge.thresholds.hamiltonian_covariance_ev,
                gauge.thresholds.group_law,
                gauge.thresholds.normalized_polar_correction;
                construction_policy = config.construction_policy,
            )
        else
            nothing
        end
        if target_reynolds !== nothing
            formal = something(target_reynolds)
            _star_construction_quality_gate!(
                config,
                maxima,
                contexts,
                "formal_target_raw_unitarity",
                formal.maximum_raw_unitarity,
                gauge.thresholds.raw_unitarity;
                context = formal.raw_unitarity_worst_context,
            )
            _star_construction_quality_gate!(
                config,
                maxima,
                contexts,
                "formal_target_polar_correction",
                formal.maximum_polar_correction,
                gauge.thresholds.normalized_polar_correction;
                context = formal.polar_correction_worst_context,
            )
            if config.construction_policy == :diagnostic
                for (name, value, threshold) in (
                    (
                        "formal_target_initial_group_law",
                        formal.initial_group_law,
                        gauge.thresholds.group_law,
                    ),
                    (
                        "formal_target_group_law",
                        formal.group_law,
                        min(1.0e-12, gauge.thresholds.hamiltonian_covariance_ev * 0.01),
                    ),
                    (
                        "formal_target_action_correction",
                        formal.action_correction,
                        gauge.thresholds.normalized_polar_correction,
                    ),
                    (
                        "formal_target_analytic_group_law",
                        formal.analytic_group_law,
                        min(1.0e-10, gauge.thresholds.hamiltonian_covariance_ev),
                    ),
                    (
                        "formal_target_reynolds_covariance",
                        formal.covariance_residual_ev,
                        min(gauge.thresholds.hamiltonian_covariance_ev * 0.1, 1.0e-10),
                    ),
                    (
                        "formal_target_reynolds_idempotence",
                        formal.idempotence_ev,
                        min(gauge.thresholds.hamiltonian_covariance_ev * 0.1, 1.0e-10),
                    ),
                )
                    _star_construction_quality_gate!(
                        config,
                        maxima,
                        contexts,
                        name,
                        value,
                        threshold;
                        context = "star=$(star_index),rep=$(representative),formal_target",
                    )
                end
            end
            for (name, value, context) in (
                (
                    "formal_target_raw_unitarity",
                    formal.maximum_raw_unitarity,
                    formal.raw_unitarity_worst_context,
                ),
                (
                    "formal_target_normalized_polar_correction",
                    formal.maximum_polar_correction,
                    formal.polar_correction_worst_context,
                ),
                (
                    "formal_target_reynolds_covariance_ev",
                    formal.covariance_residual_ev,
                    formal.covariance_worst_context,
                ),
                (
                    "formal_target_reynolds_idempotence_ev",
                    formal.idempotence_ev,
                    "star=$(star_index),rep=$(representative),finite_group_projection",
                ),
                (
                    "formal_target_initial_group_law",
                    formal.initial_group_law,
                    formal.initial_group_law_context,
                ),
                ("formal_target_group_law", formal.group_law, formal.group_law_context),
                (
                    "formal_target_group_law_uu",
                    formal.group_law_channels[1],
                    formal.group_law_context,
                ),
                (
                    "formal_target_group_law_ua",
                    formal.group_law_channels[2],
                    formal.group_law_context,
                ),
                (
                    "formal_target_group_law_au",
                    formal.group_law_channels[3],
                    formal.group_law_context,
                ),
                (
                    "formal_target_group_law_aa",
                    formal.group_law_channels[4],
                    formal.group_law_context,
                ),
                (
                    "formal_target_corepresentation",
                    formal.corepresentation,
                    formal.group_law_context,
                ),
                ("formal_target_theta_squared", formal.theta_squared, formal.group_law_context),
                ("formal_target_kramers", formal.kramers, formal.group_law_context),
                (
                    "formal_target_action_correction",
                    formal.action_correction,
                    "star=$(star_index),rep=$(representative),raw_polar_to_formal",
                ),
                (
                    "formal_target_action_projection_iterations",
                    Float64(formal.iterations),
                    "star=$(star_index),rep=$(representative)",
                ),
                (
                    "formal_target_analytic_group_law",
                    formal.analytic_group_law,
                    formal.group_law_context,
                ),
                (
                    "formal_target_analytic_group_law_uu",
                    formal.analytic_group_law_channels[1],
                    formal.group_law_context,
                ),
                (
                    "formal_target_analytic_group_law_ua",
                    formal.analytic_group_law_channels[2],
                    formal.group_law_context,
                ),
                (
                    "formal_target_analytic_group_law_au",
                    formal.analytic_group_law_channels[3],
                    formal.group_law_context,
                ),
                (
                    "formal_target_analytic_group_law_aa",
                    formal.analytic_group_law_channels[4],
                    formal.group_law_context,
                ),
                (
                    "formal_target_analytic_reciprocal_shift",
                    formal.analytic_reciprocal_shift,
                    "star=$(star_index),rep=$(representative),analytic_validator",
                ),
                (
                    "formal_target_analytic_theta_squared",
                    formal.analytic_theta_squared,
                    formal.group_law_context,
                ),
                (
                    "formal_target_analytic_kramers",
                    formal.analytic_kramers,
                    formal.group_law_context,
                ),
                (
                    "formal_target_analytic_required_block_unitarity",
                    formal.analytic_required_block_unitarity,
                    "star=$(star_index),rep=$(representative),analytic_validator",
                ),
            )
                _star_update_maximum!(maxima, contexts, name, value, context)
            end
        end
        symmetrized_hamiltonians = if target_reynolds !== nothing
            something(target_reynolds).hamiltonians
        elseif symmetrized_authority
            Dict(
                source_kpoint => _star_independent_reynolds_hamiltonian(
                    metric,
                    native,
                    lowdin,
                    source_kpoint,
                    workspace,
                    operations,
                    kpoint_map,
                    reciprocal_shifts,
                ) for source_kpoint in star
            )
        else
            nothing
        end
        symmetrized_authority && (hamiltonian_average = symmetrized_hamiltonians[representative])
        target_projector = _star_target_projector(
            raw_metric,
            native.kpoints[representative],
            metric.projectors[representative],
            raw_native.kpoints[representative],
            raw_metric.projectors[representative],
            workspace,
            authority_indices,
        )
        partition_candidates, search_truncated = try
            if gauge.block_partition_policy isa AdaptiveEvidencePAWBlockPartition
                _star_adaptive_partition_candidates(
                    selected_raw,
                    representative_energies[workspace],
                    gauge.buffer_policy,
                    gauge.thresholds,
                    gauge.block_partition_policy,
                    selected_target_energies,
                )
            elseif gauge.block_partition_policy isa HamiltonianWeightedPAWBlockPartition
                (
                    [
                        _star_block_partition_decision(
                            selected_raw,
                            representative_energies[workspace],
                            gauge.buffer_policy,
                            gauge.thresholds,
                            gauge.block_partition_policy,
                            selected_target_energies,
                            antiunitary_transports,
                            controlled || config.construction_policy == :diagnostic ?
                            :diagnostic : :fail_stop,
                        ),
                    ],
                    false,
                )
            else
                (
                    [
                        _star_block_partition_decision(
                            selected_raw,
                            representative_energies[workspace],
                            gauge.buffer_policy,
                            gauge.thresholds,
                            gauge.block_partition_policy,
                            selected_target_energies,
                        ),
                    ],
                    false,
                )
            end
        catch error
            message = sprint(showerror, error)
            any(
                code -> occursin(code, message),
                (
                    "BLOCK_PARTITION",
                    "FAR_BAND_PAIR_RESIDUAL_HOLD",
                    "FAR_BAND_CUMULATIVE_RESIDUAL_HOLD",
                    "PAW_CANCELLATION_STABILITY_HOLD",
                ),
            ) || rethrow()
            matched = match(r"transport=(\d+)", message)
            operation_index = matched === nothing ? 0 : parse(Int, only(matched.captures))
            target_kpoint = operation_index == 0 ? 0 : transports[operation_index].target_kpoint
            _star_append_preflight_diagnostic(
                config,
                Dict(
                    "stage" => "PRE_GAUGE_PARTITION_HOLD",
                    "status" => "HOLD",
                    "root_cause" => string(_star_root_cause(error)),
                    "star_index" => star_index,
                    "representative_kpoint" => representative,
                    "operation_index" => operation_index,
                    "target_kpoint" => target_kpoint,
                    "workspace" => [first(workspace), last(workspace)],
                    "error" => message,
                ),
            )
            throw(
                ArgumentError(
                    "star=$(star_index), rep=$(representative), " *
                    "op=$(operation_index), target_k=$(target_kpoint), " *
                    "workspace=$(first(workspace)):$(last(workspace)); $(message)",
                ),
            )
        end
        candidate_context = (
            gauge = gauge,
            construction_policy = config.construction_policy,
            star_index = star_index,
            star = star,
            representative = representative,
            representative_energies = representative_energies,
            target_indices = authority_indices,
            target_count = authority_count,
            workspace = workspace,
            hamiltonian_average = hamiltonian_average,
            symmetrized_hamiltonians = symmetrized_hamiltonians,
            formal_target_actions = target_reynolds === nothing ? nothing :
                                    something(target_reynolds).actions,
            formal_target_indices = target_reynolds === nothing ? nothing :
                                    something(target_reynolds).target_indices,
            authoritative_hamiltonian = config.authoritative_hamiltonian,
            target_subspace_contract = config.target_subspace_contract,
            target_projector = target_projector,
            selected_raw = selected_raw,
            transports = transports,
            operations = operations,
            native = native,
            raw_native = raw_native,
            raw_metric = raw_metric,
            metric = metric,
            lowdin = lowdin,
            kpoint_map = kpoint_map,
            reciprocal_shifts = reciprocal_shifts,
        )
        accepted_decision = nothing
        accepted_solution = nothing
        best_failure = nothing
        best_failure_maxima = Dict{String, Float64}()
        best_failure_contexts = Dict{String, String}()
        best_failure_decision = nothing
        for partition_decision in partition_candidates
            local solution
            try
                if controlled && symmetrized_target_authority
                    native_parent =
                        Matrix(@view(lowdin.hamiltonians[representative][workspace, workspace]))
                    correction_hamiltonian = hamiltonian_average - native_parent
                    controlled_maxima = Dict{String, Float64}(
                        "controlled_far_rotation_operator" => 0.0,
                        "controlled_far_rotation_normalized_frobenius" => 0.0,
                        "controlled_hamiltonian_correction_operator_ev" =>
                            opnorm(correction_hamiltonian, 2),
                        "controlled_hamiltonian_correction_normalized_frobenius_ev" =>
                            norm(correction_hamiltonian) / sqrt(length(workspace)),
                    )
                    controlled_contexts = Dict(
                        key => "star=$(star_index),rep=$(representative),target_only_reynolds"
                        for key in keys(controlled_maxima)
                    )
                    solution = _star_partition_candidate_solution(
                        partition_decision.blocks,
                        candidate_context;
                        controlled_maxima,
                        controlled_contexts,
                    )
                elseif controlled
                    correction = gauge.hamiltonian_correction::FarBandCovarianceCorrection
                    controlled_pair = _star_controlled_symmetrization_eigenpair(
                        partition_decision.blocks,
                        candidate_context,
                        correction,
                    )
                    solution = _star_partition_candidate_solution(
                        partition_decision.blocks,
                        candidate_context;
                        controlled_eigenpair = controlled_pair,
                        controlled_maxima = controlled_pair.maxima,
                        controlled_contexts = controlled_pair.maximum_contexts,
                    )
                else
                    solution = _star_partition_candidate_solution(
                        partition_decision.blocks,
                        candidate_context,
                    )
                end
                _star_first_star_strict_gate!(config, candidate_context, solution)
            catch error
                gauge.block_partition_policy isa AdaptiveEvidencePAWBlockPartition || rethrow()
                message = sprint(showerror, error)
                best_failure === nothing && (
                    best_failure = (
                        name = "candidate_exception",
                        ratio = Inf,
                        message = message,
                        context = "candidate_exception",
                    )
                )
                continue
            end
            violations = _star_partition_candidate_violations(
                solution,
                gauge.thresholds,
                gauge.block_partition_policy,
                config.authoritative_hamiltonian,
                target_scope_active,
            )
            if controlled
                correction = gauge.hamiltonian_correction::FarBandCovarianceCorrection
                controlled_thresholds = correction.thresholds
                _star_controlled_native_difference_evidence!(
                    violations,
                    solution,
                    controlled_thresholds,
                    config.authoritative_hamiltonian,
                    "star=$(star_index),rep=$(representative)",
                )
                solution.maxima["controlled_symmetrization_strict_violation_count"] =
                    length(violations)
                solution.maxima["controlled_symmetrization_strict_maximum_ratio"] =
                    isempty(violations) ? 0.0 : first(violations).ratio
                diagnostic_only = correction.qualification_mode == :diagnostic_only
                if diagnostic_only
                    solution.maximum_contexts["controlled_symmetrization_strict_violation_count"] = "star=$(star_index),rep=$(representative),DIAGNOSTIC_ONLY"
                    solution.maximum_contexts["controlled_symmetrization_strict_maximum_ratio"] =
                        isempty(violations) ? "PASS" : first(violations).context
                    accepted_decision = partition_decision
                    accepted_solution = solution
                    break
                end
            end
            if config.construction_policy == :diagnostic
                for violation in violations
                    _star_construction_quality_gate!(
                        config,
                        solution.maxima,
                        solution.maximum_contexts,
                        violation.name,
                        violation.value,
                        violation.threshold;
                        context = violation.context,
                    )
                end
            end
            if isempty(violations) || config.construction_policy == :diagnostic
                accepted_decision = partition_decision
                accepted_solution = solution
                break
            end
            worst = first(violations)
            if best_failure === nothing || worst.ratio < best_failure.ratio
                best_failure = (
                    name = worst.name,
                    ratio = worst.ratio,
                    message = "$(worst.name)=$(worst.value) exceeds $(worst.threshold)",
                    context = worst.context,
                )
                best_failure_maxima = copy(solution.maxima)
                best_failure_contexts = copy(solution.maximum_contexts)
                best_failure_decision = partition_decision
            end
        end
        if accepted_solution === nothing
            failure_code = if symmetrized_authority && best_failure !== nothing
                _star_post_symmetrization_failure_code(best_failure.name)
            elseif controlled
                "CONTROLLED_SYMMETRIZATION_HOLD"
            elseif search_truncated
                "BLOCK_PARTITION_SEARCH_HOLD"
            elseif best_failure !== nothing && startswith(best_failure.name, "hamiltonian_")
                "HAMILTONIAN_COVARIANCE_HOLD"
            elseif best_failure !== nothing && best_failure.name in (
                "projected_eigen_residual_ev",
                "maximum_energy_shift_ev",
                "rms_energy_shift_ev",
            )
                "HAMILTONIAN_COVARIANCE_HOLD"
            elseif best_failure !== nothing && best_failure.name in (
                "wfc_rotation_reconstruction",
                "completed_paw_s_norm",
                "alternative_path_residual",
                "kramers_pair_residual",
                "raw_unitarity",
                "normalized_polar_correction",
            )
                "PAW_PROPAGATION_IMPLEMENTATION_HOLD"
            else
                "BLOCK_PARTITION_PHYSICS_HOLD"
            end
            attempted = length(partition_candidates)
            detail =
                best_failure === nothing ? "no admissible candidate" :
                "best=$(best_failure.message); $(best_failure.context)"
            _star_append_preflight_diagnostic(
                config,
                Dict(
                    "stage" => "POST_GAUGE_STAR_HOLD",
                    "status" => "HOLD",
                    "root_cause" => failure_code,
                    "star_index" => star_index,
                    "representative_kpoint" => representative,
                    "workspace" => [first(workspace), last(workspace)],
                    "attempted_partition_count" => attempted,
                    "search_truncated" => search_truncated,
                    "worst_failure" => detail,
                    "maxima" => best_failure_maxima,
                    "maximum_contexts" => best_failure_contexts,
                    "raw_preflight_maxima" => Dict(
                        key => value for
                        (key, value) in maxima if startswith(key, "pre_symmetrization_") ||
                            startswith(key, "raw_preflight_") ||
                            startswith(key, "hamiltonian_covariance_before")
                    ),
                    "raw_preflight_maximum_contexts" => Dict(
                        key => value for
                        (key, value) in contexts if startswith(key, "pre_symmetrization_") ||
                            startswith(key, "raw_preflight_") ||
                            startswith(key, "hamiltonian_covariance_before")
                    ),
                    "raw_preflight_diagnostic_status" =>
                        get(maxima, "raw_preflight_diagnostic_exceeded", 0.0) > 0.0 ?
                        "RAW_PREFLIGHT_DIAGNOSTIC_EXCEEDED" : "WITHIN_DIAGNOSTIC_REFERENCE",
                    "pre_gauge_far_cumulative_status" =>
                        best_failure_decision === nothing ? "NOT_AVAILABLE" :
                        string(best_failure_decision.pre_gauge_far_cumulative_status),
                    "pre_gauge_far_cumulative_worst_context" =>
                        best_failure_decision === nothing ? "NOT_AVAILABLE" :
                        best_failure_decision.pre_gauge_far_cumulative_worst_context,
                    "pre_gauge_far_residual_metrics" =>
                        best_failure_decision === nothing ? Dict{String, Any}() :
                        Dict(
                            "count" => best_failure_decision.far_residual_count,
                            "tolerated_count" => best_failure_decision.tolerated_far_residual_count,
                            "maximum_pair_ev" =>
                                best_failure_decision.maximum_pair_hamiltonian_residual_ev,
                            "operator_ev" => best_failure_decision.maximum_far_operator_residual_ev,
                            "source_column_l2_ev" =>
                                best_failure_decision.maximum_far_source_column_l2_residual_ev,
                            "normalized_frobenius_ev" =>
                                best_failure_decision.maximum_far_normalized_frobenius_residual_ev,
                            "frobenius_ev_report_only" =>
                                best_failure_decision.maximum_far_frobenius_residual_ev,
                        ),
                ),
            )
            throw(
                ArgumentError(
                    "$(failure_code): star=$(star_index), rep=$(representative), " *
                    "attempted=$(attempted), search_truncated=$(search_truncated); $(detail)",
                ),
            )
        end
        partition_decision = something(accepted_decision)
        solution = something(accepted_solution)
        partition_context = "star=$(star_index),rep=$(representative),policy=$(partition_decision.policy_key),accepted_state=$(partition_decision.search_states)"
        for (name, value) in (
            ("block_partition_evidence_count", partition_decision.evidence_count),
            ("block_partition_evidence_orbit_count", partition_decision.evidence_orbit_count),
            ("block_partition_search_states", partition_decision.search_states),
            ("block_partition_maximum_evidence_gap_ev", partition_decision.maximum_evidence_gap_ev),
            (
                "block_partition_maximum_evidence_coupling",
                partition_decision.maximum_evidence_coupling,
            ),
            ("block_partition_maximum_block_span_ev", partition_decision.maximum_block_span_ev),
            ("block_partition_maximum_block_bands", partition_decision.maximum_block_bands),
            ("far_residual_count", partition_decision.far_residual_count),
            ("tolerated_far_residual_count", partition_decision.tolerated_far_residual_count),
            (
                "maximum_pair_hamiltonian_residual_ev",
                partition_decision.maximum_pair_hamiltonian_residual_ev,
            ),
            (
                "maximum_far_operator_residual_ev",
                partition_decision.maximum_far_operator_residual_ev,
            ),
            (
                "maximum_far_source_column_l2_residual_ev",
                partition_decision.maximum_far_source_column_l2_residual_ev,
            ),
            (
                "maximum_far_normalized_frobenius_residual_ev",
                partition_decision.maximum_far_normalized_frobenius_residual_ev,
            ),
            (
                "maximum_far_frobenius_residual_ev",
                partition_decision.maximum_far_frobenius_residual_ev,
            ),
            ("far_band_coupling", partition_decision.maximum_far_band_coupling),
        )
            _star_update_maximum!(maxima, contexts, name, Float64(value), partition_context)
        end
        if gauge.block_partition_policy isa HamiltonianWeightedPAWBlockPartition
            weighted_policy = gauge.block_partition_policy::HamiltonianWeightedPAWBlockPartition
            residuals = weighted_policy.residual_thresholds
            ratios = (
                partition_decision.maximum_far_operator_residual_ev / residuals.operator_ev,
                partition_decision.maximum_far_source_column_l2_residual_ev /
                residuals.source_column_l2_ev,
                partition_decision.maximum_far_normalized_frobenius_residual_ev /
                residuals.normalized_frobenius_ev,
            )
            diagnostic_exceeded =
                partition_decision.pre_gauge_far_cumulative_status ==
                :DIAGNOSTIC_EXCEEDED_CONTINUE_TO_POST_GAUGE
            diagnostic_context = "$(partition_context); $(partition_decision.pre_gauge_far_cumulative_worst_context)"
            _star_update_maximum!(
                maxima,
                contexts,
                "pre_gauge_far_cumulative_diagnostic_exceeded",
                diagnostic_exceeded ? 1.0 : 0.0,
                diagnostic_context,
            )
            _star_update_maximum!(
                maxima,
                contexts,
                "pre_gauge_far_cumulative_maximum_ratio",
                maximum(ratios),
                diagnostic_context,
            )
        end
        for (name, value) in solution.maxima
            _star_update_maximum!(
                maxima,
                contexts,
                name,
                value,
                get(solution.maximum_contexts, name, partition_context),
            )
        end
        _star_append_preflight_diagnostic(
            config,
            Dict(
                "stage" =>
                    config.construction_policy == :diagnostic ? "POST_GAUGE_STAR_COMPLETED" :
                    "POST_GAUGE_STAR_PASS",
                "status" => config.construction_policy == :diagnostic ? "DIAGNOSTIC_ONLY" : "PASS",
                "star_index" => star_index,
                "representative_kpoint" => representative,
                "star_kpoints" => star,
                "workspace" => [first(workspace), last(workspace)],
                "operation_count" => length(operations),
                "partition_policy" => partition_decision.policy_key,
                "discrete_hamiltonian_correction" =>
                    discrete_hamiltonian_correction_key(gauge.hamiltonian_correction),
                "controlled_symmetrization_qualification_mode" =>
                    gauge.hamiltonian_correction isa FarBandCovarianceCorrection ?
                    string(
                        (gauge.hamiltonian_correction::FarBandCovarianceCorrection).qualification_mode,
                    ) : "not_applicable",
                "pre_gauge_far_cumulative_status" =>
                    string(partition_decision.pre_gauge_far_cumulative_status),
                "pre_gauge_far_cumulative_worst_context" =>
                    partition_decision.pre_gauge_far_cumulative_worst_context,
                "post_gauge_maxima" => solution.maxima,
                "post_gauge_maximum_contexts" => solution.maximum_contexts,
                "raw_preflight_maxima" => Dict(
                    key => value for
                    (key, value) in maxima if startswith(key, "pre_symmetrization_") ||
                        startswith(key, "raw_preflight_") ||
                        startswith(key, "hamiltonian_covariance_before")
                ),
                "raw_preflight_maximum_contexts" => Dict(
                    key => value for
                    (key, value) in contexts if startswith(key, "pre_symmetrization_") ||
                        startswith(key, "raw_preflight_") ||
                        startswith(key, "hamiltonian_covariance_before")
                ),
                "raw_preflight_diagnostic_status" =>
                    get(maxima, "raw_preflight_diagnostic_exceeded", 0.0) > 0.0 ?
                    "RAW_PREFLIGHT_DIAGNOSTIC_EXCEEDED" : "WITHIN_DIAGNOSTIC_REFERENCE",
            ),
        )
        append!(energy_shift_values, solution.shifts)
        if symmetrized_authority
            target_energy_shifts_by_star[authority_indices, star_index] .= solution.shifts
            representative_native_hamiltonians[:, :, star_index] .=
                lowdin.hamiltonians[representative]
            representative_symmetrized_hamiltonians[:, :, star_index] .=
                symmetrized_hamiltonians[representative]
            for operation_index in eachindex(operations)
                representative_raw_transports[:, :, operation_index, star_index] .=
                    selected_raw[operation_index]
            end
        end
        for target in star
            final_points[target] =
                symmetrized_target_authority ? solution.parent_points[target] :
                solution.points[target]
            rotations[:, :, target] .=
                symmetrized_target_authority ? solution.parent_rotations[target] :
                solution.rotations[target]
            if symmetrized_authority
                parent_symmetrized_energies[:, target] .= solution.parent_eigenvalues[target]
                parent_symmetrized_rotations[:, :, target] .= solution.parent_rotations[target]
                target_principal_angles[authority_indices_by_kpoint[target], target] .=
                    solution.target_principal_angles[target]
                target_projector_operator[target] = solution.target_projector_operator[target]
                target_projector_frobenius[target] = solution.target_projector_frobenius[target]
                parent_band_assignments[:, target] .= solution.parent_assignments[target]
                append!(parent_energy_shift_values, solution.parent_energy_shifts[target])
                parent_energy_shifts_by_kpoint[:, target] .= solution.parent_energy_shifts[target]
                final_points[target].energies_ev == parent_symmetrized_energies[:, target] || throw(
                    ArgumentError(
                        "HAMILTONIAN_REFERENCE_MISMATCH: persisted parent energies differ at k=$(target)",
                    ),
                )
            end
            representative_for_kpoint[target] = representative
            canonical_operation_for_kpoint[target] = solution.canonical_operations[target]
        end
        if symmetrized_target_authority
            complement_indices = setdiff(collect(parent_range), authority_indices)
            target_anchor_sha256_by_star[star_index] = something(solution.target_anchor_sha256)
            complement_bases[:, complement_indices, star_index] .=
                something(solution.complement_basis)
            complement_rotations[complement_indices, complement_indices, star_index] .=
                something(solution.complement_rotation)
            target_complement_hamiltonians[authority_indices, complement_indices, star_index] .=
                something(solution.target_complement_hamiltonian)
            complement_hamiltonians[complement_indices, complement_indices, star_index] .=
                something(solution.complement_hamiltonian)
        end
        completed_star_count += 1
        last_completed_star_index = star_index
        if selected_star_indices !== nothing &&
           count(index -> index <= star_index, something(selected_star_indices)) ==
           length(something(selected_star_indices))
            limited_scope_reached = true
            break
        end
        if config.maximum_star_count !== nothing &&
           completed_star_count == something(config.maximum_star_count) &&
           completed_star_count < length(stars)
            limited_scope_reached = true
            break
        end
    end
    maxima["rms_energy_shift_ev"] =
        sqrt(sum(abs2, energy_shift_values) / length(energy_shift_values))
    contexts["rms_energy_shift_ev"] = "all_stars"
    if symmetrized_authority
        authority = config.authoritative_hamiltonian
        maxima["symmetrized_parent_rms_energy_shift_ev"] =
            sqrt(sum(abs2, parent_energy_shift_values) / length(parent_energy_shift_values))
        contexts["symmetrized_parent_rms_energy_shift_ev"] = "all_parent_states"
        maxima["target_maximum_energy_shift_ev"] = maxima["maximum_energy_shift_ev"]
        maxima["target_rms_energy_shift_ev"] = maxima["rms_energy_shift_ev"]
        contexts["target_maximum_energy_shift_ev"] =
            get(contexts, "maximum_energy_shift_ev", "NOT_RECORDED")
        contexts["target_rms_energy_shift_ev"] = "all_target_star_states"
        maximum_reference = authority.maximum_energy_shift_audit_reference_ev
        rms_reference = authority.rms_energy_shift_audit_reference_ev
        maxima["maximum_energy_shift_audit_reference_ev"] = maximum_reference
        maxima["rms_energy_shift_audit_reference_ev"] = rms_reference
        maxima["target_maximum_energy_shift_audit_ratio"] =
            maxima["target_maximum_energy_shift_ev"] / maximum_reference
        maxima["target_rms_energy_shift_audit_ratio"] =
            maxima["target_rms_energy_shift_ev"] / rms_reference
        maxima["symmetrized_parent_maximum_energy_shift_audit_ratio"] =
            maxima["symmetrized_parent_maximum_energy_shift_ev"] / maximum_reference
        maxima["symmetrized_parent_rms_energy_shift_audit_ratio"] =
            maxima["symmetrized_parent_rms_energy_shift_ev"] / rms_reference
        maxima["target_energy_shift_p50_ev"] = _star_absolute_percentile(energy_shift_values, 0.50)
        maxima["target_energy_shift_p95_ev"] = _star_absolute_percentile(energy_shift_values, 0.95)
        maxima["target_energy_shift_p99_ev"] = _star_absolute_percentile(energy_shift_values, 0.99)
        maxima["symmetrized_parent_energy_shift_p50_ev"] =
            _star_absolute_percentile(parent_energy_shift_values, 0.50)
        maxima["symmetrized_parent_energy_shift_p95_ev"] =
            _star_absolute_percentile(parent_energy_shift_values, 0.95)
        maxima["symmetrized_parent_energy_shift_p99_ev"] =
            _star_absolute_percentile(parent_energy_shift_values, 0.99)
        maxima["target_energy_shift_count_above_maximum_audit_reference"] =
            count(value -> abs(value) > maximum_reference, energy_shift_values)
        maxima["symmetrized_parent_energy_shift_count_above_maximum_audit_reference"] =
            count(value -> abs(value) > maximum_reference, parent_energy_shift_values)
        maxima["native_fidelity_projected_eigen_residual_audit_reference_ev"] =
            gauge.thresholds.projected_eigen_residual_ev
        maxima["native_fidelity_projected_eigen_residual_audit_ratio"] =
            maxima["native_fidelity_projected_eigen_residual_ev"] /
            gauge.thresholds.projected_eigen_residual_ev
        energy_audit_maximum_ratio = maximum((
            maxima["target_maximum_energy_shift_audit_ratio"],
            maxima["target_rms_energy_shift_audit_ratio"],
            maxima["symmetrized_parent_maximum_energy_shift_audit_ratio"],
            maxima["symmetrized_parent_rms_energy_shift_audit_ratio"],
            maxima["native_fidelity_projected_eigen_residual_audit_ratio"],
        ),)
        if energy_audit_maximum_ratio > get(maxima, "native_difference_audit_maximum_ratio", 0.0)
            maxima["native_difference_audit_maximum_ratio"] = energy_audit_maximum_ratio
            contexts["native_difference_audit_maximum_ratio"] = "target/parent energy shift or native projected residual audit"
        end
        energy_audit_maximum_ratio > 1.0 &&
            (maxima["native_difference_audit_reference_exceeded"] = 1.0)
    end
    maxima["hamiltonian_reynolds_residual_ev"] = maxima["hamiltonian_covariance_after_ev"]
    contexts["hamiltonian_reynolds_residual_ev"] =
        get(contexts, "hamiltonian_covariance_after_ev", "NOT_RECORDED")
    thresholds = gauge.thresholds
    weighted_partition = gauge.block_partition_policy isa HamiltonianWeightedPAWBlockPartition
    controlled_correction = gauge.hamiltonian_correction isa FarBandCovarianceCorrection
    diagnostic_controlled =
        controlled_correction &&
        (gauge.hamiltonian_correction::FarBandCovarianceCorrection).qualification_mode ==
        :diagnostic_only
    block_leakage_name = weighted_partition ? "near_block_leakage" : "nondegenerate_block_leakage"
    reconstruction_failure_code =
        symmetrized_authority ? "POST_SYMMETRIZATION_RECONSTRUCTION_HOLD" :
        "PAW_PROPAGATION_IMPLEMENTATION_HOLD"
    final_gates = Any[
        (
            "raw_unitarity",
            maxima["raw_unitarity"],
            thresholds.raw_unitarity,
            "PAW_PROPAGATION_IMPLEMENTATION_HOLD",
        ),
        (
            "normalized_polar_correction",
            maxima["normalized_polar_correction"],
            thresholds.normalized_polar_correction,
            "PAW_PROPAGATION_IMPLEMENTATION_HOLD",
        ),
        (
            "wfc_rotation_reconstruction",
            maxima["wfc_rotation_reconstruction"],
            thresholds.wfc_rotation_reconstruction,
            reconstruction_failure_code,
        ),
        (
            "completed_paw_s_norm",
            maxima["completed_paw_s_norm"],
            thresholds.paw_s_norm,
            "PAW_PROPAGATION_IMPLEMENTATION_HOLD",
        ),
        (
            "target_reconstruction_leakage_weight",
            maxima["target_reconstruction_leakage_weight"],
            thresholds.target_leakage_weight,
            "PAW_PROPAGATION_IMPLEMENTATION_HOLD",
        ),
        (
            "target_state_leakage_weight",
            maxima["target_state_leakage_weight"],
            thresholds.target_leakage_weight,
            "PAW_PROPAGATION_IMPLEMENTATION_HOLD",
        ),
        (
            "target_to_complement_leakage_weight",
            maxima["target_to_complement_leakage_weight"],
            thresholds.target_leakage_weight,
            "PAW_PROPAGATION_IMPLEMENTATION_HOLD",
        ),
        (
            "complement_to_target_leakage_weight",
            maxima["complement_to_target_leakage_weight"],
            thresholds.target_leakage_weight,
            "PAW_PROPAGATION_IMPLEMENTATION_HOLD",
        ),
        (
            "alternative_path_residual",
            maxima["alternative_path_residual"],
            thresholds.path_independence,
            "PAW_PROPAGATION_IMPLEMENTATION_HOLD",
        ),
        (
            "kramers_pair_residual",
            maxima["kramers_pair_residual"],
            thresholds.path_independence,
            "PAW_PROPAGATION_IMPLEMENTATION_HOLD",
        ),
        (
            block_leakage_name,
            maxima[block_leakage_name],
            thresholds.nondegenerate_block_leakage,
            "BLOCK_PARTITION_HOLD",
        ),
        (
            "hamiltonian_covariance_after_ev",
            maxima["hamiltonian_covariance_after_ev"],
            thresholds.hamiltonian_covariance_ev,
            "HAMILTONIAN_COVARIANCE_HOLD",
        ),
        (
            "hamiltonian_covariance_after_operator_ev",
            maxima["hamiltonian_covariance_after_operator_ev"],
            thresholds.hamiltonian_covariance_ev,
            "HAMILTONIAN_COVARIANCE_HOLD",
        ),
        (
            "hamiltonian_covariance_after_source_column_l2_ev",
            maxima["hamiltonian_covariance_after_source_column_l2_ev"],
            thresholds.hamiltonian_covariance_ev,
            "HAMILTONIAN_COVARIANCE_HOLD",
        ),
        (
            "hamiltonian_covariance_after_normalized_frobenius_ev",
            maxima["hamiltonian_covariance_after_normalized_frobenius_ev"],
            thresholds.hamiltonian_covariance_ev,
            "HAMILTONIAN_COVARIANCE_HOLD",
        ),
        (
            "projected_eigen_residual_ev",
            maxima["projected_eigen_residual_ev"],
            thresholds.projected_eigen_residual_ev,
            "HAMILTONIAN_COVARIANCE_HOLD",
        ),
    ]
    if !target_scope_active
        append!(
            final_gates,
            [
                (
                    "parent_reconstruction_leakage_amplitude_audit",
                    maxima["parent_reconstruction_leakage_amplitude_audit"],
                    thresholds.wfc_rotation_reconstruction,
                    "FINITE_BUFFER_HOLD",
                ),
                (
                    "buffer_target_leakage",
                    maxima["buffer_target_leakage"],
                    thresholds.state_leakage_amplitude,
                    "FINITE_BUFFER_HOLD",
                ),
                (
                    "maximum_energy_shift_ev",
                    maxima["maximum_energy_shift_ev"],
                    thresholds.maximum_energy_shift_ev,
                    "HAMILTONIAN_COVARIANCE_HOLD",
                ),
                (
                    "rms_energy_shift_ev",
                    maxima["rms_energy_shift_ev"],
                    thresholds.rms_energy_shift_ev,
                    "HAMILTONIAN_COVARIANCE_HOLD",
                ),
            ],
        )
    end
    if controlled_correction && !target_scope_active
        correction_thresholds =
            (gauge.hamiltonian_correction::FarBandCovarianceCorrection).thresholds
        append!(
            final_gates,
            [
                (
                    "controlled_far_rotation_operator",
                    maxima["controlled_far_rotation_operator"],
                    correction_thresholds.far_rotation_operator,
                    "CONTROLLED_SYMMETRIZATION_HOLD",
                ),
                (
                    "controlled_far_rotation_normalized_frobenius",
                    maxima["controlled_far_rotation_normalized_frobenius"],
                    correction_thresholds.far_rotation_normalized_frobenius,
                    "CONTROLLED_SYMMETRIZATION_HOLD",
                ),
                (
                    "controlled_hamiltonian_correction_operator_ev",
                    maxima["controlled_hamiltonian_correction_operator_ev"],
                    correction_thresholds.hamiltonian_correction_operator_ev,
                    "CONTROLLED_SYMMETRIZATION_HOLD",
                ),
                (
                    "controlled_hamiltonian_correction_normalized_frobenius_ev",
                    maxima["controlled_hamiltonian_correction_normalized_frobenius_ev"],
                    correction_thresholds.hamiltonian_correction_normalized_frobenius_ev,
                    "CONTROLLED_SYMMETRIZATION_HOLD",
                ),
            ],
        )
    end
    if target_scope_active
        target_authoritative_gate_names = Set((
            "raw_unitarity",
            "normalized_polar_correction",
            "target_reconstruction_leakage_weight",
            "target_state_leakage_weight",
            "target_to_complement_leakage_weight",
            "complement_to_target_leakage_weight",
            "hamiltonian_covariance_after_ev",
            "hamiltonian_covariance_after_operator_ev",
            "hamiltonian_covariance_after_source_column_l2_ev",
            "hamiltonian_covariance_after_normalized_frobenius_ev",
            "projected_eigen_residual_ev",
        ))
        filter!(gate -> gate[1] in target_authoritative_gate_names, final_gates)
    end
    for (name, value, threshold, failure_code) in final_gates
        isfinite(value) || throw(ArgumentError("NONFINITE_STRUCTURAL_HOLD: $(name) is nonfinite"))
        if config.construction_policy == :diagnostic
            _star_construction_quality_gate!(
                config,
                maxima,
                contexts,
                name,
                value,
                threshold;
                context = get(contexts, name, "NOT_RECORDED"),
            )
            continue
        end
        value <= threshold && continue
        if diagnostic_controlled
            maxima["controlled_symmetrization_strict_violation_count"] += 1.0
            maxima["controlled_symmetrization_strict_maximum_ratio"] =
                max(maxima["controlled_symmetrization_strict_maximum_ratio"], value / threshold)
            continue
        end
        throw(
            ArgumentError(
                "$(failure_code): $(name)=$(value) exceeds $(threshold); " *
                "$(get(contexts, name, "NOT_RECORDED"))",
            ),
        )
    end
    if limited_scope_reached
        _star_append_preflight_diagnostic(
            config,
            Dict(
                "stage" => "STAR_PREFLIGHT_LIMIT_REACHED_PASS",
                "status" => "PASS_STAR_SCOPE_ONLY",
                "completed_star_count" => completed_star_count,
                "total_star_count" => length(stars),
                "selected_star_indices" =>
                    selected_star_indices === nothing ? Int[] : something(selected_star_indices),
                "representative_kpoint" => star_representatives[last_completed_star_index],
                "maxima" => maxima,
                "maximum_contexts" => contexts,
            ),
        )
        throw(
            ArgumentError(
                selected_star_indices === nothing ?
                "STAR_PREFLIGHT_LIMIT_REACHED_PASS: completed $(completed_star_count) of $(length(stars)) stars" :
                "STAR_SELECTION_REACHED_PASS: completed selected stars $(join(something(selected_star_indices), ',')) of $(length(stars))",
            ),
        )
    end
    block_policy_metadata = _star_block_partition_policy_metadata(gauge.block_partition_policy)
    block_policy_sha256 = _star_block_partition_policy_sha256(block_policy_metadata)
    correction_metadata = _star_hamiltonian_correction_metadata(gauge.hamiltonian_correction)
    correction_sha256 = _star_hamiltonian_correction_sha256(gauge.hamiltonian_correction)
    authority_metadata = _star_authoritative_hamiltonian_metadata(config.authoritative_hamiltonian)
    target_contract_sha256 = if config.target_subspace_contract === nothing
        "NOT_APPLICABLE"
    else
        contract = something(config.target_subspace_contract)
        merge!(authority_metadata, _star_target_subspace_contract_metadata(contract))
        authority_metadata["qualification_scope"] = "target_subspace"
        authority_metadata["auxiliary_parent_qualification"] = "audit_only"
        authority_metadata["target_scope_production_eligible"] =
            config.construction_policy == :diagnostic ? "false" : "true"
        authority_metadata["scoped_production_eligible"] =
            config.construction_policy == :diagnostic ? "false" : "true"
        digest = _star_target_subspace_contract_sha256(contract)
        authority_metadata["target_subspace_contract_sha256"] = digest
        digest
    end
    if symmetrized_authority
        authority = config.authoritative_hamiltonian
        maximum_reference = authority.maximum_energy_shift_audit_reference_ev
        rms_reference = authority.rms_energy_shift_audit_reference_ev
        target_exceeded =
            maxima["target_maximum_energy_shift_ev"] > maximum_reference ||
            maxima["target_rms_energy_shift_ev"] > rms_reference
        parent_exceeded =
            maxima["symmetrized_parent_maximum_energy_shift_ev"] > maximum_reference ||
            maxima["symmetrized_parent_rms_energy_shift_ev"] > rms_reference
        authority_metadata["target_energy_shift_audit_status"] =
            target_exceeded ? "AUDIT_REFERENCE_EXCEEDED" : "WITHIN_AUDIT_REFERENCE"
        authority_metadata["symmetrized_parent_energy_shift_audit_status"] =
            parent_exceeded ? "AUDIT_REFERENCE_EXCEEDED" : "WITHIN_AUDIT_REFERENCE"
        authority_metadata["energy_shift_distribution_storage"] = "target_by_star_and_parent_by_kpoint_band"
        authority_metadata["raw_preflight_diagnostic_status"] =
            get(maxima, "raw_preflight_diagnostic_exceeded", 0.0) > 0.0 ?
            "RAW_PREFLIGHT_DIAGNOSTIC_EXCEEDED" : "WITHIN_DIAGNOSTIC_REFERENCE"
        authority_metadata["native_difference_audit_status"] =
            get(maxima, "native_difference_audit_reference_exceeded", 0.0) > 0.0 ?
            "AUDIT_REFERENCE_EXCEEDED" : "WITHIN_AUDIT_REFERENCE"
        if symmetrized_target_authority
            authority_metadata["symmetrized_target_subspace_status"] = "SYMMETRIZED_DFT_HAMILTONIAN_PASS"
            authority_metadata["auxiliary_parent_audit_status"] =
                maxima["symmetrized_parent_formal_eigen_residual_ev"] >
                gauge.thresholds.projected_eigen_residual_ev ? "AUXILIARY_PARENT_AUDIT_EXCEEDED" :
                "WITHIN_AUDIT_REFERENCE"
            authority_metadata["target_scope_production_eligible"] =
                config.construction_policy == :diagnostic ? "false" : "true"
        end
    end
    authority_sha256 = _star_authoritative_hamiltonian_sha256(config.authoritative_hamiltonian)
    strict_source_hashes = _strict_input_hashes(parent_source, raw_native)
    input_sha256 = merge(
        strict_source_hashes,
        _star_input_audit_hash(config, raw_native.input_sha256, length(operations)),
        Dict(
            "BLOCK_PARTITION_POLICY_SHA256" => block_policy_sha256,
            "DISCRETE_HAMILTONIAN_CORRECTION_SHA256" => correction_sha256,
            "AUTHORITATIVE_HAMILTONIAN_SHA256" => authority_sha256,
            "TARGET_SUBSPACE_CONTRACT_SHA256" => target_contract_sha256,
        ),
    )
    source_replay_metadata = begin
        metadata = _star_source_replay_metadata(config.source)
        metadata["source_replay_resource_manifest_sha256"] =
            _star_input_identity_sha256(strict_source_hashes)
        metadata["source_replay_descriptor_sha256"] =
            _star_source_replay_descriptor_sha256(metadata)
        metadata
    end
    source_metadata = merge(
        native.source_metadata,
        Dict(
            "wavefunction_gauge_backend" => "star_covariant_paw",
            "construction_policy" => String(config.construction_policy),
            "wavefunction_gauge_schema" => STAR_COVARIANT_PAW_GAUGE_SCHEMA_VERSION,
            "parent_band_range" => "$(first(parent_range)):$(last(parent_range))",
            "target_band_range" => "$(first(target_range)):$(last(target_range))",
            "magnetic_operation_count" => string(length(operations)),
            "kstar_count" => string(length(stars)),
            "coefficient_normalization" =>
                get(native.source_metadata, "coefficient_normalization", "qe_raw"),
            "nonrepresentative_frame_storage" =>
                symmetrized_target_authority ? "local_native_source_plus_completed_rotation" :
                "representative_raw_symmetry_transform",
            "pre_gauge_far_cumulative_status" =>
                get(maxima, "pre_gauge_far_cumulative_diagnostic_exceeded", 0.0) > 0.0 ?
                "DIAGNOSTIC_EXCEEDED_CONTINUE_TO_POST_GAUGE" : "PASS",
            source_replay_metadata...,
            block_policy_metadata...,
            correction_metadata...,
            authority_metadata...,
        ),
    )
    completed_native = NativeWavefunctionData(
        native.source_code,
        native.structure,
        native.reciprocal_lattice,
        native.mp_grid,
        native.spinor,
        final_points,
        input_sha256,
        source_metadata,
    )
    completed_metric, completed_norm, completed_norm_worst =
        _strict_sewing_metric(config.source, completed_native)
    completed_scoped_norm, completed_scoped_norm_worst = if target_scope_active
        _star_scoped_generalized_norm_from_metric(
            completed_metric,
            completed_native,
            something(config.target_subspace_contract).qualification_scope.outer_mask,
        )
    else
        (completed_norm, completed_norm_worst)
    end
    maxima["completed_generalized_norm"] = completed_scoped_norm
    contexts["completed_generalized_norm"] = repr(completed_scoped_norm_worst)
    if target_scope_active
        maxima["completed_parent_generalized_norm_audit"] = completed_norm
        contexts["completed_parent_generalized_norm_audit"] = repr(completed_norm_worst)
    end
    completed_scoped_norm <= thresholds.paw_s_norm || throw(
        ArgumentError(
            "PAW_PROPAGATION_IMPLEMENTATION_HOLD: scoped completed generalized norm " *
            "$(completed_scoped_norm)",
        ),
    )
    local_replay = if symmetrized_target_authority
        data = _star_replay_local_completed_frame(
            raw_native,
            raw_metric,
            rotations,
            hcat((point.energies_ev for point in completed_native.kpoints)...);
            reference_native = completed_native,
            reference_metric = completed_metric,
        )
        maxima["local_source_rotation_replay_wfc_reconstruction"] =
            data.maximum_coefficient_reconstruction
        contexts["local_source_rotation_replay_wfc_reconstruction"] =
            data.worst_coefficient_reconstruction
        maxima["local_source_rotation_replay_projector_reconstruction"] =
            data.maximum_projector_reconstruction
        contexts["local_source_rotation_replay_projector_reconstruction"] =
            data.worst_projector_reconstruction
        max(data.maximum_coefficient_reconstruction, data.maximum_projector_reconstruction) <=
        thresholds.wfc_rotation_reconstruction || throw(
            ArgumentError(
                "PAW_GAUGE_ARTIFACT_ROUNDTRIP_HOLD: local-source rotation replay exceeds " *
                "$(thresholds.wfc_rotation_reconstruction)",
            ),
        )
        replay_native = NativeWavefunctionData(
            completed_native.source_code,
            completed_native.structure,
            completed_native.reciprocal_lattice,
            completed_native.mp_grid,
            completed_native.spinor,
            data.points,
            completed_native.input_sha256,
            completed_native.source_metadata,
        )
        replay_parent_norm, replay_parent_norm_worst =
            _strict_generalized_norm_from_metric(data.metric, replay_native)
        replay_norm, replay_norm_worst = _star_scoped_generalized_norm_from_metric(
            data.metric,
            replay_native,
            something(config.target_subspace_contract).qualification_scope.outer_mask,
        )
        maxima["local_source_rotation_replay_paw_s_norm"] = replay_norm
        contexts["local_source_rotation_replay_paw_s_norm"] = repr(replay_norm_worst)
        maxima["local_source_rotation_replay_parent_paw_s_norm_audit"] = replay_parent_norm
        contexts["local_source_rotation_replay_parent_paw_s_norm_audit"] =
            repr(replay_parent_norm_worst)
        replay_norm <= thresholds.paw_s_norm || throw(
            ArgumentError(
                "PAW_GAUGE_ARTIFACT_ROUNDTRIP_HOLD: local-source replay PAW-S norm " *
                "$(replay_norm) exceeds $(thresholds.paw_s_norm)",
            ),
        )
        data
    else
        nothing
    end
    parent_transport_audit = if symmetrized_target_authority
        data = _star_sealed_completed_frame_corrections(
            completed_native,
            completed_metric,
            operations,
            reciprocal_shifts,
            representative_for_kpoint,
            canonical_operation_for_kpoint;
            reconstruction_threshold = thresholds.wfc_rotation_reconstruction,
            enforce_threshold = false,
        )
        maxima["parent_completed_frame_transport_residual_audit"] = data.maximum_reconstruction
        contexts["parent_completed_frame_transport_residual_audit"] = data.worst_reconstruction
        maxima["parent_completed_frame_transport_isometry_audit"] = data.maximum_isometry
        contexts["parent_completed_frame_transport_isometry_audit"] = data.worst_isometry
        maxima["parent_completed_frame_transport_source_minimum_singular_value_audit"] =
            data.minimum_source_metric_singular_value
        contexts["parent_completed_frame_transport_source_minimum_singular_value_audit"] =
            data.worst_reconstruction
        source_metadata["parent_completed_frame_transport_audit_status"] =
            max(data.maximum_reconstruction, data.maximum_isometry) <=
            thresholds.wfc_rotation_reconstruction ? "WITHIN_AUDIT_REFERENCE" :
            "AUDIT_REFERENCE_EXCEEDED"
        data
    else
        nothing
    end
    band_frame_contract = _build_band_frame_transform_contract(
        raw_native,
        raw_metric,
        completed_native,
        completed_metric,
        rotations;
        source_band_gauge = "native_dft_eigenstate",
        target_band_gauge = symmetrized_authority ? "symmetrized_dft_hamiltonian" :
                            "sawf_completed_native_dft",
        source_identity_sha256 = _star_input_identity_sha256(strict_source_hashes),
        physical_isometry_tolerance = target_scope_active ?
                                      something(config.target_subspace_contract).scoped_paw_thresholds.paw_s_norm :
                                      thresholds.paw_s_norm,
        replay_tolerance = target_scope_active ?
                           something(config.target_subspace_contract).scoped_paw_thresholds.wfc_rotation_reconstruction :
                           thresholds.wfc_rotation_reconstruction,
        replay_evidence = local_replay,
    )
    merge!(source_metadata, band_frame_contract_metadata(band_frame_contract))
    input_sha256["BAND_FRAME_TRANSFORM_SHA256"] = band_frame_contract.transform_sha256
    input_sha256["BAND_FRAME_CONTRACT_SHA256"] = band_frame_contract.contract_sha256
    completed_native = NativeWavefunctionData(
        completed_native.source_code,
        completed_native.structure,
        completed_native.reciprocal_lattice,
        completed_native.mp_grid,
        completed_native.spinor,
        completed_native.kpoints,
        input_sha256,
        source_metadata,
    )
    if symmetrized_target_authority
        completed_native = NativeWavefunctionData(
            completed_native.source_code,
            completed_native.structure,
            completed_native.reciprocal_lattice,
            completed_native.mp_grid,
            completed_native.spinor,
            completed_native.kpoints,
            completed_native.input_sha256,
            source_metadata,
        )
    end
    audit_payload = if symmetrized_authority
        _SymmetrizedDFTHamiltonianAuditPayload(
            hcat((point.energies_ev for point in raw_native.kpoints)...),
            parent_symmetrized_energies,
            parent_symmetrized_rotations,
            representative_native_hamiltonians,
            representative_symmetrized_hamiltonians,
            representative_raw_transports,
            target_principal_angles,
            target_projector_operator,
            target_projector_frobenius,
            parent_band_assignments,
            target_energy_shifts_by_star,
            parent_energy_shifts_by_kpoint,
            target_anchor_sha256_by_star,
            complement_bases,
            complement_rotations,
            target_complement_hamiltonians,
            complement_hamiltonians,
        )
    else
        nothing
    end
    return _StarCovariantPAWPayload(
        completed_native,
        completed_metric,
        operations,
        kpoint_map,
        reciprocal_shifts,
        representative_for_kpoint,
        canonical_operation_for_kpoint,
        star_representatives,
        extra_bands_per_star,
        rotations,
        target_range,
        parent_range,
        maxima,
        contexts,
        input_sha256,
        source_metadata,
        config.target_subspace_contract === nothing ? nothing :
        something(config.target_subspace_contract).qualification_scope,
        audit_payload,
        nothing,
    )
end

# Copy strict representation maxima into the standalone gauge audit namespace.
function _star_merge_strict_maxima!(payload::_StarCovariantPAWPayload, representation)
    for (key, value) in representation.conventions
        startswith(key, "strict_") && endswith(key, "_maximum") || continue
        metric = replace(key, r"^strict_" => "", r"_maximum$" => "")
        payload.maxima["strict_$(metric)"] = parse(Float64, value)
        context_key = "strict_$(metric)_worst_context"
        haskey(representation.conventions, context_key) &&
            (payload.maximum_contexts["strict_$(metric)"] = representation.conventions[context_key])
    end
    return nothing
end

"""Prepare, strict-preflight, and seal one star-covariant PAW wavefunction artifact."""
function prepare_symmetry_covariant_wavefunctions(
    config::SymmetryCovariantWavefunctionPreparationConfig,
)
    validate_symmetry_covariant_wavefunction_preparation_config(config)
    payload = _build_star_covariant_paw_payload(config)
    diagnostics = String[]
    gauge = config.wavefunction_gauge_backend::StarCovariantPAWGauge
    diagnostic_only =
        config.construction_policy == :diagnostic || (
            gauge.hamiltonian_correction isa FarBandCovarianceCorrection &&
            (gauge.hamiltonian_correction::FarBandCovarianceCorrection).qualification_mode ==
            :diagnostic_only
        )
    status = diagnostic_only ? :DIAGNOSTIC_ONLY : :PASS
    root_cause = if config.authoritative_hamiltonian isa SymmetrizedDFTHamiltonian
        :SYMMETRIZED_DFT_HAMILTONIAN_PASS
    elseif gauge.hamiltonian_correction isa FarBandCovarianceCorrection
        :CONTROLLED_DISCRETE_HAMILTONIAN_SYMMETRY_RESTORATION_SUPPORTED
    else
        :GAUGE_COVARIANCE_PRIMARY_CAUSE_SUPPORTED
    end
    energies = hcat((point.energies_ev for point in payload.native.kpoints)...)
    try
        diagnostic_outer_masks, diagnostic_frozen_masks =
            _star_target_contract_masks(config, collect(eachindex(payload.native.kpoints)))
        built = build_augmentation_aware_band_representation(
            config.source,
            payload.native,
            energies,
            payload.operations,
            (config.wavefunction_gauge_backend::StarCovariantPAWGauge).buffer_policy.cluster_tolerance_ev,
            config.sewing_backend::AugmentationAwareSewing,
            strict_metric = payload.metric,
            block_partition_policy = (config.wavefunction_gauge_backend::StarCovariantPAWGauge).block_partition_policy,
            enforce_thresholds = !diagnostic_only,
            diagnostic_outer_masks = diagnostic_outer_masks,
            diagnostic_frozen_masks = diagnostic_frozen_masks,
        )
        _star_merge_strict_maxima!(payload, built.representation)
        _star_append_preflight_diagnostic(
            config,
            Dict(
                "stage" => "FULL_STRICT_REPRESENTATION_PASS",
                "status" => diagnostic_only ? "DIAGNOSTIC_ONLY" : "PASS",
                "source_kpoint_count" => length(payload.native.kpoints),
                "operation_count" => length(payload.operations),
                "maxima" => payload.maxima,
                "maximum_contexts" => payload.maximum_contexts,
            ),
        )
    catch error
        status = :PAW_SEWING_HOLD
        message = sprint(showerror, error)
        root_cause =
            if is_symmetrized_authority(config.authoritative_hamiltonian) &&
               occursin("s_reconstruction", message)
                :POST_SYMMETRIZATION_RECONSTRUCTION_HOLD
            else
                _star_root_cause(error)
            end
        push!(diagnostics, message)
        _star_append_preflight_diagnostic(
            config,
            Dict(
                "stage" => "FULL_STRICT_REPRESENTATION_HOLD",
                "status" => "HOLD",
                "root_cause" => string(root_cause),
                "source_kpoint_count" => length(payload.native.kpoints),
                "operation_count" => length(payload.operations),
                "error" => message,
                "maxima" => payload.maxima,
                "maximum_contexts" => payload.maximum_contexts,
            ),
        )
    end
    # Never publish a requested production artifact after strict sewing has
    # failed.  A self-contained HOLD capsule remains available for diagnosis,
    # but its distinct filename prevents downstream reuse as a qualified gauge.
    output_path =
        status == :PASS ? config.output_hdf5 :
        status == :DIAGNOSTIC_ONLY ? splitext(config.output_hdf5)[1] * ".diagnostic-only.h5" :
        splitext(config.output_hdf5)[1] * ".hold.h5"
    output =
        _write_star_covariant_paw_gauge_hdf5(output_path, payload; status, root_cause, diagnostics)
    if status in (:PASS, :DIAGNOSTIC_ONLY)
        eig_path = splitext(output)[1] * ".eig"
        write_wannier_eig(eig_path, WannierEIG(size(energies, 1), size(energies, 2), energies))
    end
    artifact_sha256 = sha256_file(output)
    native_residual = get(
        payload.maxima,
        "native_fidelity_projected_eigen_residual_ev",
        get(payload.maxima, "projected_eigen_residual_ev", Inf),
    )
    native_status =
        native_residual <= gauge.thresholds.projected_eigen_residual_ev ?
        :NATIVE_DFT_FIDELITY_PASS : :NATIVE_DFT_FIDELITY_HOLD
    symmetrized_status =
        is_symmetrized_authority(config.authoritative_hamiltonian) ?
        (
            status == :PASS ? :SYMMETRIZED_DFT_HAMILTONIAN_PASS :
            :SYMMETRIZED_DFT_HAMILTONIAN_PRECHECK_HOLD
        ) : :NOT_SELECTED
    target_status =
        config.authoritative_hamiltonian isa SymmetrizedDFTHamiltonian ?
        (
            status == :PASS ? :SYMMETRIZED_DFT_HAMILTONIAN_PASS :
            :SYMMETRIZED_DFT_HAMILTONIAN_TARGET_PRECHECK_HOLD
        ) : :NOT_SELECTED
    auxiliary_parent_status =
        config.authoritative_hamiltonian isa SymmetrizedDFTHamiltonian ?
        (
            get(payload.maxima, "symmetrized_parent_formal_eigen_residual_ev", Inf) >
            gauge.thresholds.projected_eigen_residual_ev ? :AUXILIARY_PARENT_AUDIT_EXCEEDED :
            :WITHIN_AUDIT_REFERENCE
        ) : :NOT_APPLICABLE
    native_metrics = Dict(
        key => value for (key, value) in payload.maxima if
        startswith(key, "native_") || startswith(key, "target_")
    )
    symmetrized_metrics = Dict(
        key => value for (key, value) in payload.maxima if startswith(key, "symmetrized_") ||
        startswith(key, "hamiltonian_covariance_after_") ||
        startswith(key, "controlled_")
    )
    return SymmetryCovariantWavefunctionPreparationResult(
        status,
        root_cause,
        output,
        artifact_sha256,
        payload.target_band_range,
        payload.parent_band_range,
        payload.star_representatives,
        payload.extra_bands_per_star,
        payload.maxima,
        payload.maximum_contexts,
        payload.input_sha256,
        diagnostics,
        native_status,
        symmetrized_status,
        target_status,
        auxiliary_parent_status,
        authoritative_hamiltonian_key(config.authoritative_hamiltonian),
        config.target_subspace_contract !== nothing && status == :PASS,
        config.target_subspace_contract !== nothing && status == :PASS,
        false,
        native_metrics,
        symmetrized_metrics,
    )
end

# Hash every QE file whose bytes can affect a completed star-gauge payload.
function _star_current_source_hashes(source::QuantumEspressoWavefunctionSource)
    metadata = read_qe_xml(source)
    hashes = Dict("data-file-schema.xml" => sha256_file(metadata.xml_file))
    for label in sort!(collect(keys(metadata.upf_files)))
        filename = metadata.upf_files[label]
        hashes["UPF:$(label):$(basename(filename))"] = sha256_file(filename)
    end
    for kpoint in eachindex(metadata.kpoint_nodes)
        filename = qe_wavefunction_file(source, kpoint)
        hashes[basename(filename)] = sha256_file(filename)
    end
    return hashes
end

# Hash every VASP file whose bytes can affect a completed star-gauge payload.
function _star_current_source_hashes(source::VASPWavefunctionSource)
    hashes = Dict(
        "POSCAR" => sha256_file(source.poscar_file),
        "WAVECAR" => sha256_file(source.wavecar_file),
    )
    source.potcar_file === nothing ||
        (hashes["POTCAR"] = sha256_file(something(source.potcar_file)))
    source.incar_file === nothing || (hashes["INCAR"] = sha256_file(something(source.incar_file)))
    source.outcar_file === nothing ||
        (hashes["OUTCAR"] = sha256_file(something(source.outcar_file)))
    return hashes
end

# Fail closed when the raw source or selected target range differs from the gauge capsule.
function _validate_star_gauge_source_identity(
    source::AbstractWavefunctionSource,
    payload::_StarCovariantPAWPayload,
)
    source.band_range == payload.target_band_range || throw(
        ArgumentError(
            "WAVEFUNCTION_GAUGE_ARTIFACT_MISMATCH: source band range differs from artifact",
        ),
    )
    current = _star_current_source_hashes(source)
    for (key, value) in current
        get(payload.input_sha256, key, "MISSING") == value ||
            throw(ArgumentError("INPUT_PROVENANCE_HOLD: source digest differs for $(key)"))
    end
    return nothing
end
