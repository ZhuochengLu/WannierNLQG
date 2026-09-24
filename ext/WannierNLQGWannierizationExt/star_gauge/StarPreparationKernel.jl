"""Compute one independent k-star; all mutable diagnostics and metric caches are local."""
function _compute_preparation_star(common, star_index, star)
    (;
        config,
        gauge,
        target_range,
        target_count,
        parent_count,
        parent_range,
        parent_source,
        output_target_indices,
        raw_native,
        raw_metric,
        native,
        metric,
        lowdin,
        operations,
        kpoint_map,
        reciprocal_shifts,
        symmetrized_authority,
        target_scope_active,
        symmetrized_target_authority,
    ) = common
    maxima = copy(common.initial_maxima)
    contexts = copy(common.initial_contexts)
    raw_metric = _preparation_private_metric(raw_metric)
    metric = _preparation_private_metric(metric)
    representative = first(star)
    authority_indices_by_kpoint = if symmetrized_target_authority
        _star_target_indices_by_kpoint(something(config.target_subspace_contract), star, parent_range)
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
    representative_energies = native_point_metadata(native, representative).energies_ev
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
    extra_bands =
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
        native_point_metadata(native, transports[index].target_kpoint).energies_ev[workspace]
        for index in eachindex(transports)
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
            operations[operation_index].antiunitary ? conj(source_hamiltonian) : source_hamiltonian
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
        if config.construction_policy == :standard
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
            ("formal_target_group_law_uu", formal.group_law_channels[1], formal.group_law_context),
            ("formal_target_group_law_ua", formal.group_law_channels[2], formal.group_law_context),
            ("formal_target_group_law_au", formal.group_law_channels[3], formal.group_law_context),
            ("formal_target_group_law_aa", formal.group_law_channels[4], formal.group_law_context),
            ("formal_target_corepresentation", formal.corepresentation, formal.group_law_context),
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
            ("formal_target_analytic_kramers", formal.analytic_kramers, formal.group_law_context),
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
                        controlled || config.construction_policy == :standard ? :diagnostic :
                        :fail_stop,
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
                    key => "star=$(star_index),rep=$(representative),target_only_reynolds" for
                    key in keys(controlled_maxima)
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
                solution =
                    _star_partition_candidate_solution(partition_decision.blocks, candidate_context)
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
            solution.maxima["controlled_symmetrization_strict_violation_count"] = length(violations)
            solution.maxima["controlled_symmetrization_strict_maximum_ratio"] =
                isempty(violations) ? 0.0 : first(violations).ratio
            standard_route = correction.qualification_mode == :standard
            if standard_route
                solution.maximum_contexts["controlled_symmetrization_strict_violation_count"] = "star=$(star_index),rep=$(representative),STANDARD"
                solution.maximum_contexts["controlled_symmetrization_strict_maximum_ratio"] =
                    isempty(violations) ? "PASS" : first(violations).context
                accepted_decision = partition_decision
                accepted_solution = solution
                break
            end
        end
        if config.construction_policy == :standard
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
        if isempty(violations) || config.construction_policy == :standard
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
        elseif best_failure !== nothing && best_failure.name in
               ("projected_eigen_residual_ev", "maximum_energy_shift_ev", "rms_energy_shift_ev")
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
        ("block_partition_maximum_evidence_coupling", partition_decision.maximum_evidence_coupling),
        ("block_partition_maximum_block_span_ev", partition_decision.maximum_block_span_ev),
        ("block_partition_maximum_block_bands", partition_decision.maximum_block_bands),
        ("far_residual_count", partition_decision.far_residual_count),
        ("tolerated_far_residual_count", partition_decision.tolerated_far_residual_count),
        (
            "maximum_pair_hamiltonian_residual_ev",
            partition_decision.maximum_pair_hamiltonian_residual_ev,
        ),
        ("maximum_far_operator_residual_ev", partition_decision.maximum_far_operator_residual_ev),
        (
            "maximum_far_source_column_l2_residual_ev",
            partition_decision.maximum_far_source_column_l2_residual_ev,
        ),
        (
            "maximum_far_normalized_frobenius_residual_ev",
            partition_decision.maximum_far_normalized_frobenius_residual_ev,
        ),
        ("maximum_far_frobenius_residual_ev", partition_decision.maximum_far_frobenius_residual_ev),
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
                config.construction_policy == :standard ? "POST_GAUGE_STAR_COMPLETED" :
                "POST_GAUGE_STAR_PASS",
            "status" => config.construction_policy == :standard ? "STANDARD" : "PASS",
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
    return (
        solution = solution,
        maxima = maxima,
        contexts = contexts,
        representative = representative,
        authority_indices = authority_indices,
        authority_indices_by_kpoint = authority_indices_by_kpoint,
        symmetrized_hamiltonians = symmetrized_hamiltonians,
        selected_raw = selected_raw,
        extra_bands = extra_bands,
    )
end
