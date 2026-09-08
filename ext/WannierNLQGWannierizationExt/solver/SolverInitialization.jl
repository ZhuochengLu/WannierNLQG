# Construct or restore frames, then qualify frozen-state and projector invariants.
function _initialize_solver_frames(state::NamedTuple)
    (;
        amn,
        amn_sha256,
        apply_symmetry,
        basis_sha256,
        compatibility,
        config,
        config_sha256,
        diagnostics,
        effective_algorithms,
        effective_compatibility_policy,
        fixed_subspace,
        frozen_indices,
        frozen_masks,
        full_constraint_scope,
        input_summary,
        mmn,
        nb,
        nk,
        num_wannier,
        observer,
        outer_indices,
        outer_masks,
        paw_scdm_input,
        plan,
        projector_covariance_tolerance,
        representation,
        restart,
        restart_history,
        restart_state,
        spectrum_audit,
        stencil,
        tangent_plans,
        weights,
    ) = state
    fixed_mode = config.solver.initialization == :fixed_subspace
    fixed_source_qualified = false
    fixed_mode == (fixed_subspace !== nothing) || return _failure_result(
        INVALID_INPUT,
        [
            WannierizationDiagnostic(
                :FIXED_SUBSPACE_INPUT_MISMATCH,
                :error,
                "fixed_subspace input must be supplied exactly for initialization=:fixed_subspace",
            ),
        ],
        input_summary,
    )
    if fixed_mode
        fixed = something(fixed_subspace)
        size(fixed.frames) == (nb, num_wannier, nk) || return _failure_result(
            INVALID_INPUT,
            [
                WannierizationDiagnostic(
                    :FIXED_SUBSPACE_DIMENSION_MISMATCH,
                    :error,
                    "fixed-subspace frame dimensions do not match the current problem",
                ),
            ],
            input_summary,
        )
        size(fixed.projectors) == (nb, nb, nk) || return _failure_result(
            INVALID_INPUT,
            [
                WannierizationDiagnostic(
                    :FIXED_SUBSPACE_DIMENSION_MISMATCH,
                    :error,
                    "fixed-subspace projector dimensions do not match the current problem",
                ),
            ],
            input_summary,
        )
        fixed.irreducible_indices == representation.irreducible_indices || return _failure_result(
            INVALID_INPUT,
            [
                WannierizationDiagnostic(
                    :FIXED_SUBSPACE_IBZ_MISMATCH,
                    :error,
                    "fixed-subspace IBZ indices do not match the representation",
                ),
            ],
            input_summary,
        )
        fixed.frozen_mask == reduce(hcat, frozen_masks) || return _failure_result(
            INVALID_INPUT,
            [
                WannierizationDiagnostic(
                    :FIXED_SUBSPACE_FROZEN_MASK_MISMATCH,
                    :error,
                    "fixed-subspace frozen mask does not match the selected frozen window",
                ),
            ],
            input_summary,
        )
        for (key, value) in fixed.source_sha256
            input_summary["fixed_subspace_source_$(key)"] = value
        end
        fixed_source_qualified = get(fixed.source_sha256, "qualified_z_seal", "false") == "true"
        input_summary["fixed_subspace_source_z_seal_class"] =
            get(fixed.source_sha256, "z_seal_class", "NOT_RECORDED")
        input_summary["fixed_subspace_source_qualified_z_seal"] = string(fixed_source_qualified)
        fixed_formal_screen = fixed_source_qualified && full_constraint_scope
        input_summary["fixed_subspace_qualification"] = if fixed_formal_screen
            "QUALIFIED_SOURCE_U_ONLY_FORMAL_SCREEN"
        elseif fixed_source_qualified
            "QUALIFIED_SOURCE_U_ONLY_DIAGNOSTIC_SYMMETRY_ABLATION"
        else
            "NONQUALIFIED_SOURCE_U_ONLY_DIAGNOSTIC"
        end
        input_summary["disentanglement_convergence"] =
            fixed_source_qualified ? "CONVERGED_INHERITED_SEAL" : "NOT_APPLICABLE"
        input_summary["z_seal_class"] = get(fixed.source_sha256, "z_seal_class", "NOT_RECORDED")
        input_summary["qualified_z_seal"] = string(fixed_source_qualified)
        input_summary["route_selection_eligible"] = string(fixed_formal_screen)
        input_summary["standard_tb_export_eligible"] = "false"
        for (key, value) in fixed.invariant_residuals
            input_summary["fixed_subspace_$(key)"] = string(value)
        end
    end
    initialization_diagnostics = Any[]
    initialization_invariants = nothing
    initialization_report = nothing
    if config.solver.initialization_backend isa ProjectabilityDisentanglementInitialization
        amn === nothing && return _failure_result(
            INVALID_INPUT,
            [
                WannierizationDiagnostic(
                    :PROJECTABILITY_GRAM_PRECONDITION_FAILED,
                    :error,
                    "projectability initialization requires AMN projection matrices",
                ),
            ],
            input_summary,
        )
        gram_residual = 0.0
        amn_values = something(amn)
        for kpoint in axes(amn_values, 3)
            projector = @view amn_values[:, :, kpoint]
            gram_residual = max(gram_residual, opnorm(projector' * projector - I))
        end
        input_summary["projectability_trial_projector_gram_residual"] = string(gram_residual)
        gram_residual <= 1.0e-8 || return _failure_result(
            INVALID_INPUT,
            [
                WannierizationDiagnostic(
                    :PROJECTABILITY_GRAM_PRECONDITION_FAILED,
                    :error,
                    "trial-projector Gram residual exceeds 1e-8";
                    context = Dict("gram_residual" => string(gram_residual)),
                ),
            ],
            input_summary,
        )
    elseif config.solver.initialization_backend isa PAWSCDMInitialization
        paw_scdm_input === nothing && return _failure_result(
            INVALID_INPUT,
            [
                WannierizationDiagnostic(
                    :SCDM_INPUT_PRECONDITION,
                    :error,
                    "PAW-SCDM input artifact was not loaded",
                ),
            ],
            input_summary,
        )
        scdm = something(paw_scdm_input)
        size(scdm.frames) == (nb, num_wannier, nk) || return _failure_result(
            INVALID_INPUT,
            [
                WannierizationDiagnostic(
                    :SCDM_INPUT_PRECONDITION,
                    :error,
                    "PAW-SCDM band/Wannier/k-point dimensions differ",
                ),
            ],
            input_summary,
        )
        scdm.mp_grid == representation.mp_grid && scdm.spinor == representation.spinor ||
            return _failure_result(
                INVALID_INPUT,
                [
                    WannierizationDiagnostic(
                        :SCDM_INPUT_PRECONDITION,
                        :error,
                        "PAW-SCDM MP-grid or spinor identity differs",
                    ),
                ],
                input_summary,
            )
        representation_authority =
            get(representation.conventions, "authoritative_hamiltonian", "native_dft")
        representation_authority_sha256 =
            get(representation.conventions, "authoritative_hamiltonian_sha256", "LEGACY_NATIVE_DFT")
        if apply_symmetry
            scdm.authoritative_hamiltonian == representation_authority &&
            scdm.authoritative_hamiltonian_sha256 == representation_authority_sha256 ||
                return _failure_result(
                    INVALID_INPUT,
                    [
                        WannierizationDiagnostic(
                            :SCDM_INPUT_PRECONDITION,
                            :error,
                            "PAW-SCDM Hamiltonian authority identity differs",
                        ),
                    ],
                    input_summary,
                )
            input_summary["paw_scdm_authority_usage"] = "solver_authority"
        else
            get(scdm.source_identity, "authoritative_hamiltonian", "MISSING") ==
            scdm.authoritative_hamiltonian || return _failure_result(
                INVALID_INPUT,
                [
                    WannierizationDiagnostic(
                        :SCDM_INPUT_PRECONDITION,
                        :error,
                        "PAW-SCDM source authority provenance differs",
                    ),
                ],
                input_summary,
            )
            get(scdm.source_identity, "authoritative_hamiltonian_sha256", "MISSING") ==
            scdm.authoritative_hamiltonian_sha256 || return _failure_result(
                INVALID_INPUT,
                [
                    WannierizationDiagnostic(
                        :SCDM_INPUT_PRECONDITION,
                        :error,
                        "PAW-SCDM source authority digest provenance differs",
                    ),
                ],
                input_summary,
            )
            input_summary["paw_scdm_authority_usage"] = "input_provenance_only"
        end
        maximum(abs, scdm.kpoints_fractional - representation.kpoints_fractional) <= 1.0e-10 ||
            return _failure_result(
                INVALID_INPUT,
                [
                    WannierizationDiagnostic(
                        :SCDM_INPUT_PRECONDITION,
                        :error,
                        "PAW-SCDM k-point identity differs",
                    ),
                ],
                input_summary,
            )
        projector_residual = maximum(
            maximum(
                abs,
                @view(scdm.projectors[:, :, kpoint]) -
                @view(scdm.frames[:, :, kpoint]) * @view(scdm.frames[:, :, kpoint])',
            ) for kpoint in 1:nk
        )
        projector_residual <= 1.0e-10 || return _failure_result(
            INVALID_INPUT,
            [
                WannierizationDiagnostic(
                    :SCDM_INPUT_PRECONDITION,
                    :error,
                    "PAW-SCDM initial projector payload is inconsistent";
                    context = Dict("projector_residual" => string(projector_residual)),
                ),
            ],
            input_summary,
        )
        input_summary["paw_scdm_input_precondition"] = "PASS"
        input_summary["paw_scdm_schema_version"] = scdm.schema_version
        input_summary["paw_scdm_payload_sha256"] = scdm.payload_sha256
        input_summary["paw_scdm_source_gauge_sha256"] = scdm.source_gauge_sha256
        input_summary["paw_scdm_strict_representation_sha256"] = scdm.strict_representation_sha256
        input_summary["paw_scdm_authoritative_hamiltonian"] = scdm.authoritative_hamiltonian
        input_summary["paw_scdm_authoritative_hamiltonian_sha256"] =
            scdm.authoritative_hamiltonian_sha256
        input_summary["paw_scdm_metric_sha256"] = scdm.metric_sha256
        input_summary["paw_scdm_initial_projector_sha256"] =
            bytes2hex(SHA.sha256(reinterpret(UInt8, vec(scdm.projectors))))
        input_summary["paw_scdm_minimum_singular_value"] = string(minimum(scdm.singular_values))
        input_summary["paw_scdm_maximum_condition"] = string(maximum(scdm.conditions))
        input_summary["paw_scdm_minimum_rank"] = string(minimum(scdm.ranks))
        input_summary["paw_scdm_maximum_generalized_norm_residual"] =
            string(maximum(scdm.generalized_norm_residuals))
        input_summary["paw_scdm_maximum_paw_s_orthogonality_residual"] =
            string(maximum(scdm.paw_s_orthogonality_residuals))
        input_summary["paw_scdm_maximum_euclidean_orthogonality_residual"] =
            string(maximum(scdm.euclidean_orthogonality_residuals))
        input_summary["paw_scdm_sampling_contract"] =
            get(scdm.source_identity, "sampling_contract", "MISSING")
        input_summary["paw_scdm_augmentation_source"] =
            get(scdm.source_identity, "augmentation_source", "MISSING")
    end

    frames = if fixed_mode
        _restart_matrix_field(something(fixed_subspace).frames)
    elseif restart_state === nothing
        try
            initialized, initialization_diagnostics, initialization_invariants, initialization_report = _initial_frames_with_diagnostics(
                config,
                representation,
                outer_indices,
                frozen_indices,
                num_wannier,
                amn,
                restart;
                plan = plan,
                spectrum_audit = spectrum_audit,
                paw_scdm_input,
            )
            initialized
        catch exception
            input_summary["initialization_status"] = "FAILED"
            code = if exception isa FrozenCorepresentationInitializationError
                exception.code
            elseif occursin("HERMITIAN_SPECTRAL_DECOMPOSITION_FAILED", sprint(showerror, exception))
                :HERMITIAN_SPECTRAL_DECOMPOSITION_FAILED
            else
                :INITIALIZATION_FAILED
            end
            context =
                exception isa FrozenCorepresentationInitializationError ? exception.context :
                Dict{String, String}()
            push!(
                diagnostics,
                WannierizationDiagnostic(
                    code,
                    :error,
                    sprint(showerror, exception),
                    context = context,
                ),
            )
            _record_hermitian_spectrum_audit!(input_summary, spectrum_audit)
            status =
                code in (
                    :FROZEN_TARGET_COREPRESENTATION_MISMATCH,
                    :FROZEN_FREE_COMPLEMENT_RANK_DEFICIENT,
                ) ? REPRESENTATION_INCOMPATIBLE : INVALID_INPUT
            return _failure_result(status, diagnostics, input_summary)
        end
    else
        size(restart_state.frames) == (nb, num_wannier, nk) || return _failure_result(
            INVALID_INPUT,
            [
                WannierizationDiagnostic(
                    :RESTART_STATE_DIMENSION_MISMATCH,
                    :error,
                    "restart frame dimensions do not match",
                ),
            ],
            input_summary,
        )
        _restart_matrix_field(restart_state.frames)
    end
    raw_amn_reference_frames = nothing
    if amn !== nothing
        reference = _raw_amn_localization_reference(
            something(amn),
            representation,
            plan,
            apply_symmetry,
            outer_indices,
            frozen_indices,
            effective_algorithms.localization == :smv_fletcher_reeves_two_stage,
        )
        if !reference.success
            push!(
                diagnostics,
                WannierizationDiagnostic(
                    reference.code,
                    :error,
                    "raw AMN cannot define a finite localization reference",
                ),
            )
            return _failure_result(INVALID_INPUT, diagnostics, input_summary)
        end
        raw_amn_reference_frames = reference.frames
        input_summary["localization_reference"] = String(reference.algorithm)
    else
        input_summary["localization_reference"] =
            restart_state === nothing ? "initializer_fallback" : "checkpoint_state"
    end
    if fixed_mode
        input_summary["initializer"] = "fixed_subspace_deterministic_frame"
        input_summary["initialization_status"] = "COMPLETED"
    elseif restart_state === nothing && initialization_report !== nothing
        report = something(initialization_report)
        input_summary["initializer"] = String(report.algorithm)
        input_summary["effective_initializer"] = String(report.algorithm)
        input_summary["initializer_algorithm_version"] = report.algorithm_version
        input_summary["initialization_status"] = String(report.status)
        input_summary["initializer_isometry_residual"] =
            string(maximum(diagnostic.isometry_after for diagnostic in report.kpoints))
        input_summary["initializer_frozen_projector_residual"] =
            string(maximum(diagnostic.frozen_residual_after for diagnostic in report.kpoints))
        input_summary["initializer_target_completion_count"] =
            string(sum(diagnostic.target_completion_count for diagnostic in report.kpoints))
        input_summary["initializer_band_completion_count"] =
            string(sum(diagnostic.band_completion_count for diagnostic in report.kpoints))
        report.status == :COMPLETED_WITH_WARNING && push!(
            diagnostics,
            WannierizationDiagnostic(
                :INITIALIZER_DETERMINISTIC_COMPLETION,
                :warning,
                "rank-deficient AMN directions were completed deterministically while preserving the exact frozen subspace";
                context = Dict(
                    "target_completion_count" =>
                        input_summary["initializer_target_completion_count"],
                    "band_completion_count" =>
                        input_summary["initializer_band_completion_count"],
                ),
            ),
        )
    elseif restart_state === nothing && initialization_invariants !== nothing
        invariants = something(initialization_invariants)
        constrained_initializer =
            config.solver.initialization_backend isa PAWSCDMInitialization ?
            "paw_s_scdm_then_type3_frozen_projection" : "amn_then_type3_frozen_projection"
        input_summary["initializer"] = constrained_initializer
        input_summary["effective_initializer"] = constrained_initializer
        input_summary["initialization_status"] = "COMPLETED"
        input_summary["initializer_isometry_residual"] = string(invariants.isometry_residual)
        input_summary["initializer_frozen_projector_residual"] =
            string(invariants.frozen_projector_residual)
        input_summary["initializer_covariance_residual"] = string(invariants.covariance_residual)
        input_summary["initializer_amn_projection_residual"] =
            string(invariants.amn_projection_residual)
        if config.solver.initialization_backend isa PAWSCDMInitialization
            input_summary["initializer_scdm_projection_residual"] =
                string(invariants.amn_projection_residual)
        end
        input_summary["initializer_kpoint_diagnostics"] = join(
            [
                "k=$(entry.kpoint),frozen=$(entry.frozen_rank),free=$(entry.free_rank)," *
                "frozen_singular=$(repr(entry.frozen_singular_values))," *
                "frozen_condition=$(entry.frozen_condition)," *
                "free_singular=$(repr(entry.free_singular_values))," *
                "free_condition=$(entry.free_condition)," *
                "amn_projection_residual=$(entry.amn_projection_residual)" for
                entry in initialization_diagnostics
            ],
            ";",
        )
    else
        input_summary["initializer"] = string(config.solver.initialization)
        input_summary["effective_initializer"] =
            !apply_symmetry &&
            config.solver.initialization == :amn &&
            any(indices -> !isempty(indices), frozen_indices) ?
            "amn_full_bz_exact_frozen_embedding" : string(config.solver.initialization)
        input_summary["initialization_status"] = "COMPLETED"
    end
    if fixed_mode
        fixed = something(fixed_subspace)
        fixed_residuals = _candidate_invariant_residuals(frames, frozen_indices, representation)
        projector_residual = maximum(
            maximum(abs, @view(fixed.projectors[:, :, kpoint]) - frames[kpoint] * frames[kpoint]') for kpoint in 1:nk
        )
        target_symmetry = _maximum_target_frame_symmetry_error(frames, representation, plan)
        input_summary["fixed_subspace_projector_residual"] = string(projector_residual)
        input_summary["fixed_subspace_isometry_residual"] = string(fixed_residuals.isometry)
        input_summary["fixed_subspace_frozen_residual"] = string(fixed_residuals.frozen)
        input_summary["fixed_subspace_covariance_residual"] = string(fixed_residuals.covariance)
        input_summary["fixed_subspace_target_symmetry_residual"] = string(target_symmetry)
        maximum((projector_residual, fixed_residuals.isometry, fixed_residuals.frozen)) <=
        config.input.representation_tolerance || return _failure_result(
            REPRESENTATION_INCOMPATIBLE,
            [
                WannierizationDiagnostic(
                    :FIXED_SUBSPACE_INVARIANT_FAILED,
                    :error,
                    "fixed-subspace projector/frame hard gate failed",
                ),
            ],
            input_summary;
            frames,
        )
        (
            isfinite(fixed_residuals.covariance) && (
                config.input.construction_policy == :diagnostic ||
                fixed_residuals.covariance <= projector_covariance_tolerance
            )
        ) || return _failure_result(
            REPRESENTATION_INCOMPATIBLE,
            [
                WannierizationDiagnostic(
                    :FIXED_SUBSPACE_COVARIANCE_FAILED,
                    :error,
                    "fixed-subspace covariance exceeds the qualified empirical budget",
                ),
            ],
            input_summary;
            frames,
        )
        (
            isfinite(target_symmetry) && (
                config.input.construction_policy == :diagnostic ||
                target_symmetry <= projector_covariance_tolerance
            )
        ) || return _failure_result(
            REPRESENTATION_INCOMPATIBLE,
            [
                WannierizationDiagnostic(
                    :FIXED_SUBSPACE_TARGET_SYMMETRY_FAILED,
                    :error,
                    "fixed-subspace target-frame covariance exceeds the empirical budget",
                ),
            ],
            input_summary;
            frames,
        )
    end
    complete_outer_space = _is_complete_outer_space(outer_indices, nb, num_wannier)
    input_summary["complete_outer_space"] = string(complete_outer_space)
    included_bands, representation_diagnostics = if !apply_symmetry
        (deepcopy(outer_masks), WannierizationDiagnostic[])
    elseif fixed_mode
        (deepcopy(outer_masks), WannierizationDiagnostic[])
    elseif restart_state === nothing
        complete_outer_space ?
        (
            deepcopy(outer_masks),
            [
                WannierizationDiagnostic(
                    :FULL_SPACE_REPRESENTATION_CLOSURE,
                    :info,
                    "square outer window uses the exact full-space representation closure",
                ),
            ],
        ) : _representation_inclusion_masks(frames, representation, plan, config)
    else
        size(restart_state.included_bands) == (nb, nk) || return _failure_result(
            INVALID_INPUT,
            [
                WannierizationDiagnostic(
                    :RESTART_STATE_DIMENSION_MISMATCH,
                    :error,
                    "restart inclusion-mask dimensions do not match",
                ),
            ],
            input_summary,
        )
        (
            [BitVector(@view restart_state.included_bands[:, kpoint]) for kpoint in 1:nk],
            WannierizationDiagnostic[],
        )
    end
    append!(diagnostics, representation_diagnostics)
    for representative in representation.irreducible_indices
        count(included_bands[representative]) >= num_wannier || begin
            push!(
                diagnostics,
                WannierizationDiagnostic(
                    :REPRESENTATION_BLOCK_RANK_INSUFFICIENT,
                    :error,
                    "included band blocks cannot support num_wannier";
                    context = Dict("kpoint" => string(representative)),
                ),
            )
            return _failure_result(REPRESENTATION_INCOMPATIBLE, diagnostics, input_summary)
        end
    end
    frames, converged_projection, singular_projection, projection_iterations, _ =
        !apply_symmetry || fixed_mode ? (frames, true, false, 0, 0.0) :
        restart_state === nothing ?
        _symmetrize_frame(frames, representation, plan, config, included_bands) :
        (frames, true, false, 0, 0.0)
    singular_projection && begin
        push!(
            diagnostics,
            WannierizationDiagnostic(
                :SINGULAR_SYMMETRY_PROJECTION,
                :error,
                "symmetry-projected initial frame lost rank",
            ),
        )
        return _failure_result(SINGULAR_LOCALIZATION, diagnostics, input_summary; frames)
    end
    converged_projection || push!(
        diagnostics,
        WannierizationDiagnostic(
            :LITTLE_GROUP_PROJECTION_NOT_CONVERGED,
            :warning,
            "initial symmetry projection reached its iteration limit";
            context = Dict("iterations" => string(projection_iterations)),
        ),
    )
    initial_projector_diagnostic =
        apply_symmetry ?
        _selected_projector_compatibility_diagnostic(
            frames,
            representation,
            projector_covariance_tolerance,
            effective_compatibility_policy,
            "initial",
            compatibility.product_table.theta_index,
        ) : nothing
    if initial_projector_diagnostic !== nothing
        quality_continuation =
            config.input.construction_policy == :diagnostic &&
            initial_projector_diagnostic.code == :ANTIUNITARY_PROJECTOR_COVARIANCE_FAILED
        push!(
            diagnostics,
            quality_continuation ?
            _construction_quality_diagnostic(initial_projector_diagnostic, "initial_projector") :
            initial_projector_diagnostic,
        )
        quality_continuation || return _failure_result(
            REPRESENTATION_INCOMPATIBLE,
            diagnostics,
            merge(input_summary, Dict("failure_class" => "REPRESENTATION_A"));
            frames,
        )
    end
    apply_symmetry && _record_construction_symmetry_quality!(
        diagnostics,
        input_summary,
        frames,
        frozen_indices,
        representation,
        plan,
        config,
        projector_covariance_tolerance,
        "initial_frame",
    )
    z_previous = if fixed_mode
        _restart_matrix_field(something(fixed_subspace).projectors)
    elseif restart_state === nothing || restart_state.z_previous === nothing
        nothing
    else
        _restart_matrix_field(something(restart_state.z_previous))
    end
    return (;
        amn_sha256,
        apply_symmetry,
        basis_sha256,
        compatibility,
        config,
        config_sha256,
        diagnostics,
        effective_algorithms,
        effective_compatibility_policy,
        fixed_mode,
        fixed_source_qualified,
        fixed_subspace,
        frames,
        frozen_indices,
        full_constraint_scope,
        included_bands,
        initialization_report,
        input_summary,
        mmn,
        nb,
        nk,
        num_wannier,
        observer,
        outer_indices,
        plan,
        projector_covariance_tolerance,
        raw_amn_reference_frames,
        representation,
        restart_history,
        restart_state,
        spectrum_audit,
        stencil,
        tangent_plans,
        weights,
        z_previous,
    )
end

# Restore optimizer histories and initialize owned convergence and trajectory state.
function _initialize_solver_optimizer(state::NamedTuple)
    (;
        amn_sha256,
        apply_symmetry,
        basis_sha256,
        compatibility,
        config,
        config_sha256,
        diagnostics,
        effective_algorithms,
        effective_compatibility_policy,
        fixed_mode,
        fixed_source_qualified,
        fixed_subspace,
        frames,
        frozen_indices,
        full_constraint_scope,
        included_bands,
        initialization_report,
        input_summary,
        mmn,
        nb,
        nk,
        num_wannier,
        observer,
        outer_indices,
        plan,
        projector_covariance_tolerance,
        raw_amn_reference_frames,
        representation,
        restart_history,
        restart_state,
        spectrum_audit,
        stencil,
        tangent_plans,
        weights,
        z_previous,
    ) = state
    history = WannierizationIteration[restart_history...]
    centers =
        restart_state === nothing ? _initial_wannier_centers(config, representation) :
        copy(restart_state.centers_cartesian)
    spreads =
        restart_state === nothing ? zeros(Float64, num_wannier) :
        copy(restart_state.spreads_angstrom2)
    if fixed_mode || (!apply_symmetry && restart_state === nothing)
        centers, spreads, _ = _solver_centers_spreads_and_directions(
            config,
            frames,
            centers,
            representation,
            mmn,
            weights,
            plan,
        )
    end
    convergence_values =
        restart_state === nothing ? Vector{Vector{Float64}}() :
        [
            Vector{Float64}(@view restart_state.convergence_values[:, index]) for
            index in axes(restart_state.convergence_values, 2)
        ]
    start_iteration = restart_state === nothing ? 1 : restart_state.iteration + 1
    started_ns = time_ns()
    prior_elapsed = restart_state === nothing ? 0.0 : restart_state.elapsed_seconds
    latest_restart_state = restart_state
    optimizer_state = if restart_state === nothing
        legacy = WannierizationOptimizerState(
            config.solver.acceleration.strategy,
            config.solver.z_mix_ratio,
            config.solver.u_mix_ratio,
        )
        WannierizationOptimizerState(
            legacy.strategy,
            legacy.z_mix_ratio,
            legacy.u_mix_ratio,
            legacy.improvement_streak,
            legacy.rejected_steps,
            legacy.residual_reference,
            legacy.previous_merit,
            legacy.anderson_z_history,
            legacy.anderson_residual_history,
            config.solver.acceleration.schedule == :two_stage ? :disentanglement :
            config.solver.acceleration.schedule == :fixed_subspace ? :localization : :joint,
            0,
            0,
            0,
            0,
            1,
            1.0,
            false,
            0,
            cat(frames...; dims = 3),
            copy(centers),
            copy(spreads),
            sum(spreads),
        )
    else
        restart_state.optimizer_state
    end
    actual_z_mix_ratio = optimizer_state.z_mix_ratio
    actual_u_mix_ratio = optimizer_state.u_mix_ratio
    improvement_streak = optimizer_state.improvement_streak
    rejected_steps = optimizer_state.rejected_steps
    residual_reference = optimizer_state.residual_reference
    previous_merit = optimizer_state.previous_merit
    anderson_z_history = optimizer_state.anderson_z_history
    anderson_residual_history = optimizer_state.anderson_residual_history
    optimizer_phase = optimizer_state.phase
    z_stability_count = optimizer_state.z_stability_count
    u_stability_count = optimizer_state.u_stability_count
    z_steps = optimizer_state.z_steps
    u_steps = optimizer_state.u_steps
    epoch = optimizer_state.epoch
    last_accepted_u_step_scale = optimizer_state.last_accepted_u_step_scale
    gradient_fallback_active = optimizer_state.gradient_fallback_active
    gradient_steps = optimizer_state.gradient_steps
    best_polar_frames =
        isempty(optimizer_state.best_polar_frames) ? deepcopy(frames) :
        _restart_matrix_field(optimizer_state.best_polar_frames)
    best_polar_centers =
        isempty(optimizer_state.best_polar_centers) ? copy(centers) :
        copy(optimizer_state.best_polar_centers)
    best_polar_spreads =
        isempty(optimizer_state.best_polar_spreads) ? copy(spreads) :
        copy(optimizer_state.best_polar_spreads)
    best_polar_objective =
        isfinite(optimizer_state.best_polar_objective) ? optimizer_state.best_polar_objective :
        sum(spreads)
    disentanglement_objective_history = copy(optimizer_state.disentanglement_objective_history)
    localization_objective_history = copy(optimizer_state.localization_objective_history)
    localization_trial_step_scales = copy(optimizer_state.localization_trial_step_scales)
    localization_trial_objectives = copy(optimizer_state.localization_trial_objectives)
    localization_trial_required_changes = copy(optimizer_state.localization_trial_required_changes)
    localization_trial_actual_changes = copy(optimizer_state.localization_trial_actual_changes)
    localization_trial_directional_derivatives =
        copy(optimizer_state.localization_trial_directional_derivatives)
    localization_projector_drift_history =
        copy(optimizer_state.localization_projector_drift_history)
    localization_trial_iterations = copy(optimizer_state.localization_trial_iterations)
    localization_trial_sweeps = copy(optimizer_state.localization_trial_sweeps)
    localization_trial_accepted = copy(optimizer_state.localization_trial_accepted)
    previous_u_gradient =
        isempty(optimizer_state.previous_u_gradient) ? nothing :
        _restart_matrix_field(optimizer_state.previous_u_gradient)
    previous_u_direction =
        isempty(optimizer_state.previous_u_direction) ? nothing :
        _restart_matrix_field(optimizer_state.previous_u_direction)
    u_cg_iteration = optimizer_state.u_cg_iteration
    u_cg_restart_count = optimizer_state.u_cg_restart_count
    last_cg_beta = optimizer_state.last_cg_beta
    last_cg_restart_reason = optimizer_state.last_cg_restart_reason
    last_anderson_reason = optimizer_state.last_anderson_reason
    u_lbfgs_s_history =
        restart_state === nothing ? Vector{Vector{Matrix{ComplexF64}}}() :
        _unpack_u_tangent_history(optimizer_state.u_lbfgs_s_history)
    u_lbfgs_y_history =
        restart_state === nothing ? Vector{Vector{Matrix{ComplexF64}}}() :
        _unpack_u_tangent_history(optimizer_state.u_lbfgs_y_history)
    u_lbfgs_rho_history =
        restart_state === nothing ? Float64[] : copy(optimizer_state.u_lbfgs_rho_history)
    u_lbfgs_restart_count = restart_state === nothing ? 0 : optimizer_state.u_lbfgs_restart_count
    u_branch_signature = restart_state === nothing ? "" : optimizer_state.u_active_orbit_sha256
    u_active_orbit_count = restart_state === nothing ? 0 : optimizer_state.u_active_orbit_count
    u_generalized_gradient_rms =
        restart_state === nothing ? NaN : optimizer_state.u_generalized_gradient_rms
    last_u_optimizer_restart_reason =
        restart_state === nothing ? :NOT_STARTED : optimizer_state.last_u_optimizer_restart_reason
    # The exact Wannier90 path carries its localized M and U matrices
    # recursively. Schema 2.22 persists this state so a fresh-process restart
    # cannot silently reconstruct a numerically different trajectory.
    wannier90_reference_overlaps =
        !isempty(optimizer_state.wannier90_reference_overlaps) ?
        copy(optimizer_state.wannier90_reference_overlaps) : nothing
    wannier90_reference_omega_i =
        isfinite(optimizer_state.wannier90_reference_omega_i) ?
        optimizer_state.wannier90_reference_omega_i :
        wannier90_reference_overlaps === nothing ? nothing :
        _wannier90_reference_invariant_spread(something(wannier90_reference_overlaps), weights)
    wannier90_reference_unitaries =
        !isempty(optimizer_state.wannier90_reference_unitaries) ?
        _restart_matrix_field(optimizer_state.wannier90_reference_unitaries) : nothing
    sealed_subspace_projectors = if fixed_mode
        _restart_matrix_field(something(fixed_subspace).projectors)
    elseif restart_state !== nothing && restart_state.fixed_subspace_projectors !== nothing
        _restart_matrix_field(something(restart_state.fixed_subspace_projectors))
    else
        nothing
    end
    sealed_subspace_frames = if fixed_mode
        _restart_matrix_field(something(fixed_subspace).frames)
    elseif restart_state !== nothing && restart_state.fixed_subspace_frames !== nothing
        _restart_matrix_field(something(restart_state.fixed_subspace_frames))
    else
        nothing
    end
    localization_initial_frames =
        restart_state !== nothing && restart_state.localization_initial_frames !== nothing ?
        _restart_matrix_field(something(restart_state.localization_initial_frames)) : nothing
    if config.solver.acceleration.schedule == :two_stage &&
       optimizer_phase == :localization &&
       (sealed_subspace_projectors === nothing || sealed_subspace_frames === nothing)
        push!(
            diagnostics,
            WannierizationDiagnostic(
                :RESTART_SEMANTICS_INCOMPATIBLE,
                :error,
                "two-stage localization restart lacks the schema-2.4 sealed S/P boundary",
            ),
        )
        return _failure_result(INVALID_INPUT, diagnostics, input_summary)
    end
    if sealed_subspace_projectors !== nothing
        input_summary["fixed_subspace_projector_sha256"] =
            _complex_field_sha256(something(sealed_subspace_projectors))
        input_summary["fixed_subspace_frame_sha256"] =
            _complex_field_sha256(something(sealed_subspace_frames))
    end
    if localization_initial_frames !== nothing
        input_summary["localization_initial_frame_sha256"] =
            _complex_field_sha256(something(localization_initial_frames))
    end
    if latest_restart_state === nothing
        latest_restart_state = _restart_state(
            0,
            frames,
            z_previous,
            centers,
            spreads,
            [vcat(vec(centers), spreads)],
            included_bands,
            0.0,
            config_sha256,
            compatibility.representation_sha256,
            stencil,
            basis_sha256,
            amn_sha256,
            optimizer_state,
            fixed_subspace_projectors = sealed_subspace_projectors,
            fixed_subspace_frames = sealed_subspace_frames,
            localization_initial_frames = localization_initial_frames,
        )
    end
    stage_stop_reason = nothing
    two_stage_complete = false
    fixed_stability_count = 0
    fixed_stationary_count = 0
    fixed_complete = false
    fixed_stationary = false
    phase_branch_backtracking_extension_count = 0
    minimum_localization_diagonal_phase_margin = Inf
    localization_reference_frames =
        raw_amn_reference_frames === nothing ? deepcopy(best_polar_frames) :
        something(raw_amn_reference_frames)
    if effective_algorithms.localization == :smv_fletcher_reeves_two_stage
        _mpi_root_canonical_matrix_field!(localization_reference_frames, config.solver.parallel)
    end
    diagnostic_disentanglement_nonconverged =
        config.solver.acceleration.schedule == :two_stage &&
        optimizer_phase != :disentanglement &&
        z_steps >= config.solver.acceleration.disentanglement_max_steps &&
        z_stability_count < config.solver.acceleration.z_stability_window
    if diagnostic_disentanglement_nonconverged
        input_summary["disentanglement_convergence"] = "DIAGNOSTIC_NONCONVERGED"
        input_summary["z_seal_class"] = "DIAGNOSTIC_NONCONVERGED"
        input_summary["qualified_z_seal"] = "false"
        input_summary["route_selection_eligible"] = "false"
        input_summary["standard_tb_export_eligible"] = "false"
        input_summary["localization_convergence"] = "IN_PROGRESS"
        input_summary["localization_qualification"] = "DIAGNOSTIC_ONLY"
        input_summary["model_qualification"] = "DIAGNOSTIC_ONLY/Z_NONCONVERGED"
    end
    trajectory_previous_frames = nothing
    trajectory_two_step_frames = nothing
    grassmann_trust_radius = config.solver.acceleration.trust_radius_initial
    grassmann_predicted_decrease_history = Float64[]
    grassmann_actual_decrease_history = Float64[]
    grassmann_ratio_history = Float64[]
    grassmann_radius_history = Float64[]
    grassmann_gradient_history = Float64[]
    grassmann_projector_change_history = Float64[]
    return (;
        actual_u_mix_ratio,
        actual_z_mix_ratio,
        amn_sha256,
        anderson_residual_history,
        anderson_z_history,
        apply_symmetry,
        basis_sha256,
        best_polar_centers,
        best_polar_frames,
        best_polar_objective,
        best_polar_spreads,
        centers,
        compatibility,
        config,
        config_sha256,
        convergence_values,
        diagnostic_disentanglement_nonconverged,
        diagnostics,
        disentanglement_objective_history,
        effective_algorithms,
        effective_compatibility_policy,
        epoch,
        fixed_complete,
        fixed_mode,
        fixed_source_qualified,
        fixed_stability_count,
        fixed_stationary,
        fixed_stationary_count,
        frames,
        frozen_indices,
        full_constraint_scope,
        gradient_fallback_active,
        gradient_steps,
        grassmann_actual_decrease_history,
        grassmann_gradient_history,
        grassmann_predicted_decrease_history,
        grassmann_projector_change_history,
        grassmann_radius_history,
        grassmann_ratio_history,
        grassmann_trust_radius,
        history,
        improvement_streak,
        included_bands,
        initialization_report,
        input_summary,
        last_accepted_u_step_scale,
        last_anderson_reason,
        last_cg_beta,
        last_cg_restart_reason,
        last_u_optimizer_restart_reason,
        latest_restart_state,
        localization_initial_frames,
        localization_objective_history,
        localization_projector_drift_history,
        localization_reference_frames,
        localization_trial_accepted,
        localization_trial_actual_changes,
        localization_trial_directional_derivatives,
        localization_trial_iterations,
        localization_trial_objectives,
        localization_trial_required_changes,
        localization_trial_step_scales,
        localization_trial_sweeps,
        minimum_localization_diagonal_phase_margin,
        mmn,
        nb,
        nk,
        num_wannier,
        observer,
        optimizer_phase,
        outer_indices,
        phase_branch_backtracking_extension_count,
        plan,
        previous_merit,
        previous_u_direction,
        previous_u_gradient,
        prior_elapsed,
        projector_covariance_tolerance,
        rejected_steps,
        representation,
        residual_reference,
        sealed_subspace_frames,
        sealed_subspace_projectors,
        spectrum_audit,
        spreads,
        stage_stop_reason,
        start_iteration,
        started_ns,
        stencil,
        tangent_plans,
        trajectory_previous_frames,
        trajectory_two_step_frames,
        two_stage_complete,
        u_active_orbit_count,
        u_branch_signature,
        u_cg_iteration,
        u_cg_restart_count,
        u_generalized_gradient_rms,
        u_lbfgs_restart_count,
        u_lbfgs_rho_history,
        u_lbfgs_s_history,
        u_lbfgs_y_history,
        u_stability_count,
        u_steps,
        wannier90_reference_omega_i,
        wannier90_reference_overlaps,
        wannier90_reference_unitaries,
        weights,
        z_previous,
        z_stability_count,
        z_steps,
    )
end
