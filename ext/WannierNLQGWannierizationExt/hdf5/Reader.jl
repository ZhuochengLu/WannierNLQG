"""Read one strict SAWF checkpoint and reconstruct its `WannierCHK` view when present."""
function read_wannierization_checkpoint_hdf5(filename::AbstractString)
    isfile(filename) ||
        throw(ArgumentError("wannierization checkpoint does not exist: $(filename)"))
    HDF5.enable_complex_support()
    return HDF5.h5open(filename, "r") do handle
        String(required_attribute(handle, "schema")) == WANNIERIZATION_CHECKPOINT_SCHEMA ||
            throw(ArgumentError("HDF5 file is not a WannierNLQG wannierization checkpoint"))
        stored_version = String(required_attribute(handle, "schema_version"))
        stored_version in WANNIERIZATION_CHECKPOINT_READABLE_SCHEMA_VERSIONS || throw(
            ArgumentError(
                "RESTART_SEMANTICS_INCOMPATIBLE: checkpoint schema $(stored_version) predates the fixed-subspace U semantics",
            ),
        )
        # Public 1.0 preserves the complete 2.28 layout; stored_version binds its digest.
        contract_version = stored_version == "1.0" ? "2.28" : stored_version
        # Schema 2.21 is a strict semantic extension of the 2.20 payload.  Reuse
        # the mature 2.20 field decoder, then validate the new scientific hash
        # and Z/U contract independently below.
        version =
            contract_version in ("2.21", "2.22", "2.23", "2.24", "2.25", "2.26", "2.27", "2.28") ?
            "2.20" : contract_version
        status = _wannierization_status(String(required_attribute(handle, "status")))
        v_matrix = read(handle["solution/v_matrix"])
        centers = read(handle["solution/wannier_centers_cartesian"])
        spreads = read(handle["solution/spreads_angstrom2"])
        history_group = handle["history"]
        iterations = read(history_group["iteration"])
        spread_totals = read(history_group["spread_total"])
        spread_std = read(history_group["spread_standard_deviation"])
        covariance = read(history_group["maximum_covariance_error"])
        history = WannierizationIteration[]
        has_iteration_diagnostics =
            version in (
                "2.0",
                "2.1",
                "2.2",
                "2.3",
                "2.4",
                "2.5",
                "2.6",
                "2.7",
                "2.8",
                "2.9",
                "2.10",
                "2.11",
                "2.12",
                "2.13",
                "2.14",
                "2.15",
                "2.16",
                "2.17",
                "2.18",
                "2.19",
                "2.20",
            ) && haskey(history_group, "iteration_diagnostic_values")
        diagnostic_values =
            has_iteration_diagnostics ? read(history_group["iteration_diagnostic_values"]) : nothing
        diagnostic_integers =
            has_iteration_diagnostics ? read(history_group["iteration_diagnostic_integers"]) :
            nothing
        diagnostic_flags =
            has_iteration_diagnostics ? read(history_group["iteration_diagnostic_flags"]) : nothing
        directional = has_iteration_diagnostics ? read(history_group["omega_directional"]) : nothing
        anderson_reasons =
            version in (
                "2.6",
                "2.7",
                "2.8",
                "2.9",
                "2.10",
                "2.11",
                "2.12",
                "2.13",
                "2.14",
                "2.15",
                "2.16",
                "2.17",
                "2.18",
                "2.19",
                "2.20",
            ) ? String.(read(history_group["anderson_reason"])) : String[]
        cg_restart_reasons =
            version in (
                "2.6",
                "2.7",
                "2.8",
                "2.9",
                "2.10",
                "2.11",
                "2.12",
                "2.13",
                "2.14",
                "2.15",
                "2.16",
                "2.17",
                "2.18",
                "2.19",
                "2.20",
            ) ? String.(read(history_group["cg_restart_reason"])) : String[]
        joint_acceptance_reasons =
            version in (
                "2.8",
                "2.9",
                "2.10",
                "2.11",
                "2.12",
                "2.13",
                "2.14",
                "2.15",
                "2.16",
                "2.17",
                "2.18",
                "2.19",
                "2.20",
            ) ? String.(read(history_group["joint_acceptance_reason"])) : String[]
        for index in eachindex(iterations)
            iteration_diagnostics =
                if has_iteration_diagnostics &&
                   diagnostic_integers[
                    version in (
                        "2.2",
                        "2.3",
                        "2.4",
                        "2.5",
                        "2.6",
                        "2.7",
                        "2.8",
                        "2.9",
                        "2.10",
                        "2.11",
                        "2.12",
                        "2.13",
                        "2.14",
                        "2.15",
                        "2.16",
                        "2.17",
                        "2.18",
                        "2.19",
                        "2.20",
                    ) ? 4 : 3,
                    index,
                ] == 1
                    direction_values = directional[:, index]
                    omega_directional =
                        all(isfinite, direction_values) ? Tuple(Float64.(direction_values)) :
                        nothing
                    if version in (
                        "2.8",
                        "2.9",
                        "2.10",
                        "2.11",
                        "2.12",
                        "2.13",
                        "2.14",
                        "2.15",
                        "2.16",
                        "2.17",
                        "2.18",
                        "2.19",
                        "2.20",
                    )
                        WannierizationIterationDiagnostics(
                            omega_directional,
                            diagnostic_values[1, index],
                            diagnostic_values[2, index],
                            diagnostic_values[3, index],
                            diagnostic_values[4, index],
                            diagnostic_values[5, index],
                            diagnostic_values[6, index],
                            diagnostic_values[7, index],
                            diagnostic_values[8, index],
                            diagnostic_values[9, index],
                            diagnostic_values[10, index],
                            diagnostic_integers[1, index],
                            Bool(diagnostic_flags[1, index]),
                            Bool(diagnostic_flags[2, index]),
                            diagnostic_integers[2, index],
                            diagnostic_values[11, index],
                            diagnostic_values[12, index],
                            diagnostic_integers[3, index],
                            diagnostic_values[13, index],
                            diagnostic_values[14, index],
                            diagnostic_values[15, index],
                            diagnostic_values[16, index],
                            diagnostic_values[17, index],
                            Symbol(anderson_reasons[index]),
                            diagnostic_values[18, index],
                            diagnostic_integers[5, index],
                            diagnostic_integers[6, index],
                            diagnostic_integers[7, index],
                            diagnostic_values[19, index],
                            Bool(diagnostic_flags[3, index]),
                            Symbol(cg_restart_reasons[index]),
                            diagnostic_values[20, index],
                            diagnostic_values[21, index],
                            diagnostic_integers[8, index],
                            diagnostic_values[22, index],
                            diagnostic_values[23, index],
                            diagnostic_integers[9, index],
                            diagnostic_integers[10, index],
                            diagnostic_values[24, index],
                            diagnostic_values[25, index],
                            Symbol(joint_acceptance_reasons[index]),
                        )
                    elseif version in ("2.6", "2.7")
                        WannierizationIterationDiagnostics(
                            omega_directional,
                            diagnostic_values[1, index],
                            diagnostic_values[2, index],
                            diagnostic_values[3, index],
                            diagnostic_values[4, index],
                            diagnostic_values[5, index],
                            diagnostic_values[6, index],
                            diagnostic_values[7, index],
                            diagnostic_values[8, index],
                            diagnostic_values[9, index],
                            diagnostic_values[10, index],
                            diagnostic_integers[1, index],
                            Bool(diagnostic_flags[1, index]),
                            Bool(diagnostic_flags[2, index]),
                            diagnostic_integers[2, index],
                            diagnostic_values[11, index],
                            diagnostic_values[12, index],
                            diagnostic_integers[3, index],
                            diagnostic_values[13, index],
                            diagnostic_values[14, index],
                            diagnostic_values[15, index],
                            diagnostic_values[16, index],
                            diagnostic_values[17, index],
                            Symbol(anderson_reasons[index]),
                            diagnostic_values[18, index],
                            diagnostic_integers[5, index],
                            diagnostic_integers[6, index],
                            diagnostic_integers[7, index],
                            diagnostic_values[19, index],
                            Bool(diagnostic_flags[3, index]),
                            Symbol(cg_restart_reasons[index]),
                            diagnostic_values[20, index],
                            diagnostic_values[21, index],
                            diagnostic_integers[8, index],
                        )
                    elseif version in ("2.4", "2.5")
                        WannierizationIterationDiagnostics(
                            omega_directional,
                            diagnostic_values[1, index],
                            diagnostic_values[2, index],
                            diagnostic_values[3, index],
                            diagnostic_values[4, index],
                            diagnostic_values[5, index],
                            diagnostic_values[6, index],
                            diagnostic_values[7, index],
                            diagnostic_values[8, index],
                            diagnostic_values[9, index],
                            diagnostic_values[10, index],
                            diagnostic_integers[1, index],
                            Bool(diagnostic_flags[1, index]),
                            Bool(diagnostic_flags[2, index]),
                            diagnostic_integers[2, index],
                            diagnostic_values[11, index],
                            diagnostic_values[12, index],
                            diagnostic_integers[3, index],
                            diagnostic_values[13, index],
                            diagnostic_values[14, index],
                            diagnostic_values[15, index],
                            diagnostic_values[16, index],
                            diagnostic_values[17, index],
                        )
                    elseif version in ("2.2", "2.3")
                        WannierizationIterationDiagnostics(
                            omega_directional,
                            diagnostic_values[1, index],
                            diagnostic_values[2, index],
                            diagnostic_values[3, index],
                            diagnostic_values[4, index],
                            diagnostic_values[5, index],
                            diagnostic_values[6, index],
                            diagnostic_values[7, index],
                            diagnostic_values[8, index],
                            diagnostic_values[9, index],
                            diagnostic_values[10, index],
                            diagnostic_integers[1, index],
                            Bool(diagnostic_flags[1, index]),
                            Bool(diagnostic_flags[2, index]),
                            diagnostic_integers[2, index],
                            diagnostic_values[11, index],
                            diagnostic_values[12, index],
                            diagnostic_integers[3, index],
                        )
                    else
                        WannierizationIterationDiagnostics(
                            omega_directional,
                            diagnostic_values[1, index],
                            diagnostic_values[2, index],
                            diagnostic_values[3, index],
                            diagnostic_values[4, index],
                            diagnostic_values[5, index],
                            diagnostic_values[6, index],
                            diagnostic_values[7, index],
                            diagnostic_values[8, index],
                            diagnostic_values[9, index],
                            diagnostic_values[10, index],
                            diagnostic_integers[1, index],
                            Bool(diagnostic_flags[1, index]),
                            Bool(diagnostic_flags[2, index]),
                            diagnostic_integers[2, index],
                        )
                    end
                else
                    nothing
                end
            push!(
                history,
                WannierizationIteration(
                    iterations[index],
                    spread_totals[index],
                    spread_std[index],
                    covariance[index],
                    iteration_diagnostics,
                ),
            )
        end
        diagnostics = WannierizationDiagnostic[]
        diagnostics_group = handle["diagnostics"]
        for key in sort!(String.(collect(keys(diagnostics_group))))
            group = diagnostics_group[key]
            group_attributes = HDF5.attributes(group)
            code = Symbol(String(read(group_attributes["code"])))
            severity = Symbol(String(read(group_attributes["severity"])))
            message = String(read(group_attributes["message"]))
            context = Dict{String, String}()
            for attribute_name in keys(group_attributes)
                String(attribute_name) in ("code", "severity", "message") && continue
                context[String(attribute_name)] = String(read(group_attributes[attribute_name]))
            end
            push!(diagnostics, WannierizationDiagnostic(code, severity, message; context))
        end
        has_chk = Bool(required_attribute(handle, "has_wannier_chk"))
        chk = if has_chk
            geometry = handle["geometry"]
            WannierCHK(
                size(v_matrix, 1),
                size(v_matrix, 2),
                size(v_matrix, 3),
                Tuple(Int.(read(geometry["mp_grid"]))),
                read(geometry["kpoints_fractional"]),
                read(geometry["real_lattice"]),
                read(geometry["reciprocal_lattice"]),
                centers,
                v_matrix,
            )
        else
            nothing
        end
        restart_state =
            if version in (
                "2.0",
                "2.1",
                "2.2",
                "2.3",
                "2.4",
                "2.5",
                "2.6",
                "2.7",
                "2.8",
                "2.9",
                "2.10",
                "2.11",
                "2.12",
                "2.13",
                "2.14",
                "2.15",
                "2.16",
                "2.17",
                "2.18",
                "2.19",
                "2.20",
            ) && Bool(required_attribute(handle, "restart_complete"))
                restart_group = handle["restart_state"]
                has_z_previous = Bool(read(restart_group["has_z_previous"]))
                stencil_group = handle["finite_difference_stencil"]
                stencil = WannierizationFiniteDifferenceStencil(
                    read(stencil_group["vectors_cartesian"]),
                    read(stencil_group["shell_ids"]),
                    read(stencil_group["weights"]),
                    read(stencil_group["target_moment"]),
                    Float64(required_attribute(stencil_group, "completeness_residual")),
                    String(required_attribute(stencil_group, "digest")),
                )
                optimizer_group = restart_group["optimizer"]
                residual_reference_values = Float64.(read(optimizer_group["residual_reference"]))
                length(residual_reference_values) == 4 ||
                    throw(ArgumentError("optimizer residual reference must have length four"))
                optimizer =
                    if version in (
                        "2.0",
                        "2.1",
                        "2.2",
                        "2.3",
                        "2.4",
                        "2.5",
                        "2.6",
                        "2.7",
                        "2.8",
                        "2.9",
                        "2.10",
                        "2.11",
                        "2.12",
                        "2.13",
                        "2.14",
                        "2.15",
                        "2.16",
                        "2.17",
                        "2.18",
                        "2.19",
                        "2.20",
                    )
                        WannierizationOptimizerState(
                            Symbol(String(required_attribute(optimizer_group, "strategy"))),
                            Float64(required_attribute(optimizer_group, "z_mix_ratio")),
                            Float64(required_attribute(optimizer_group, "u_mix_ratio")),
                            Int(required_attribute(optimizer_group, "improvement_streak")),
                            Int(required_attribute(optimizer_group, "rejected_steps")),
                            Tuple(residual_reference_values),
                            Float64(required_attribute(optimizer_group, "previous_merit")),
                            Matrix{Float64}(read(optimizer_group["anderson_z_history"])),
                            Matrix{Float64}(read(optimizer_group["anderson_residual_history"])),
                            Symbol(String(required_attribute(optimizer_group, "phase"))),
                            Int(required_attribute(optimizer_group, "z_stability_count")),
                            Int(required_attribute(optimizer_group, "u_stability_count")),
                            Int(required_attribute(optimizer_group, "z_steps")),
                            Int(required_attribute(optimizer_group, "u_steps")),
                            Int(required_attribute(optimizer_group, "epoch")),
                            Float64(
                                required_attribute(optimizer_group, "last_accepted_u_step_scale"),
                            ),
                            Bool(required_attribute(optimizer_group, "gradient_fallback_active")),
                            Int(required_attribute(optimizer_group, "gradient_steps")),
                            Array{ComplexF64, 3}(read(optimizer_group["best_polar_frames"])),
                            Matrix{Float64}(read(optimizer_group["best_polar_centers"])),
                            Vector{Float64}(read(optimizer_group["best_polar_spreads"])),
                            Float64(required_attribute(optimizer_group, "best_polar_objective")),
                        )
                    else
                        WannierizationOptimizerState(
                            Symbol(String(required_attribute(optimizer_group, "strategy"))),
                            Float64(required_attribute(optimizer_group, "z_mix_ratio")),
                            Float64(required_attribute(optimizer_group, "u_mix_ratio")),
                            Int(required_attribute(optimizer_group, "improvement_streak")),
                            Int(required_attribute(optimizer_group, "rejected_steps")),
                            Tuple(residual_reference_values),
                            Float64(required_attribute(optimizer_group, "previous_merit")),
                            Matrix{Float64}(read(optimizer_group["anderson_z_history"])),
                            Matrix{Float64}(read(optimizer_group["anderson_residual_history"])),
                        )
                    end
                if version in (
                    "2.3",
                    "2.4",
                    "2.5",
                    "2.6",
                    "2.7",
                    "2.8",
                    "2.9",
                    "2.10",
                    "2.11",
                    "2.12",
                    "2.13",
                    "2.14",
                    "2.15",
                    "2.16",
                    "2.17",
                    "2.18",
                    "2.19",
                    "2.20",
                )
                    legacy_optimizer = optimizer
                    optimizer = WannierizationOptimizerState(
                        legacy_optimizer.strategy,
                        legacy_optimizer.z_mix_ratio,
                        legacy_optimizer.u_mix_ratio,
                        legacy_optimizer.improvement_streak,
                        legacy_optimizer.rejected_steps,
                        legacy_optimizer.residual_reference,
                        legacy_optimizer.previous_merit,
                        legacy_optimizer.anderson_z_history,
                        legacy_optimizer.anderson_residual_history,
                        legacy_optimizer.phase,
                        legacy_optimizer.z_stability_count,
                        legacy_optimizer.u_stability_count,
                        legacy_optimizer.z_steps,
                        legacy_optimizer.u_steps,
                        legacy_optimizer.epoch,
                        legacy_optimizer.last_accepted_u_step_scale,
                        legacy_optimizer.gradient_fallback_active,
                        legacy_optimizer.gradient_steps,
                        legacy_optimizer.best_polar_frames,
                        legacy_optimizer.best_polar_centers,
                        legacy_optimizer.best_polar_spreads,
                        legacy_optimizer.best_polar_objective,
                        Vector{Float64}(read(optimizer_group["disentanglement_objective_history"])),
                        Vector{Float64}(read(optimizer_group["localization_objective_history"])),
                        Vector{Float64}(read(optimizer_group["localization_trial_step_scales"])),
                        Vector{Float64}(read(optimizer_group["localization_trial_objectives"])),
                        Vector{Float64}(
                            read(optimizer_group["localization_trial_required_changes"]),
                        ),
                        Vector{Float64}(read(optimizer_group["localization_trial_actual_changes"])),
                        version in (
                            "2.4",
                            "2.5",
                            "2.6",
                            "2.7",
                            "2.8",
                            "2.9",
                            "2.10",
                            "2.11",
                            "2.12",
                            "2.13",
                            "2.14",
                            "2.15",
                            "2.16",
                            "2.17",
                            "2.18",
                            "2.19",
                            "2.20",
                        ) ?
                        Vector{Float64}(
                            read(optimizer_group["localization_trial_directional_derivatives"]),
                        ) : Float64[],
                        version in (
                            "2.4",
                            "2.5",
                            "2.6",
                            "2.7",
                            "2.8",
                            "2.9",
                            "2.10",
                            "2.11",
                            "2.12",
                            "2.13",
                            "2.14",
                            "2.15",
                            "2.16",
                            "2.17",
                            "2.18",
                            "2.19",
                            "2.20",
                        ) ?
                        Vector{Float64}(
                            read(optimizer_group["localization_projector_drift_history"]),
                        ) : Float64[],
                        version in (
                            "2.4",
                            "2.5",
                            "2.6",
                            "2.7",
                            "2.8",
                            "2.9",
                            "2.10",
                            "2.11",
                            "2.12",
                            "2.13",
                            "2.14",
                            "2.15",
                            "2.16",
                            "2.17",
                            "2.18",
                            "2.19",
                            "2.20",
                        ) && haskey(optimizer_group, "localization_trial_iterations") ?
                        Vector{Int}(read(optimizer_group["localization_trial_iterations"])) :
                        Int[],
                        version in (
                            "2.4",
                            "2.5",
                            "2.6",
                            "2.7",
                            "2.8",
                            "2.9",
                            "2.10",
                            "2.11",
                            "2.12",
                            "2.13",
                            "2.14",
                            "2.15",
                            "2.16",
                            "2.17",
                            "2.18",
                            "2.19",
                            "2.20",
                        ) && haskey(optimizer_group, "localization_trial_sweeps") ?
                        Vector{Int}(read(optimizer_group["localization_trial_sweeps"])) : Int[],
                        version in (
                            "2.4",
                            "2.5",
                            "2.6",
                            "2.7",
                            "2.8",
                            "2.9",
                            "2.10",
                            "2.11",
                            "2.12",
                            "2.13",
                            "2.14",
                            "2.15",
                            "2.16",
                            "2.17",
                            "2.18",
                            "2.19",
                            "2.20",
                        ) && haskey(optimizer_group, "localization_trial_accepted") ?
                        Vector{Bool}(read(optimizer_group["localization_trial_accepted"])) :
                        Bool[],
                    )
                end
                if version in (
                    "2.6",
                    "2.7",
                    "2.8",
                    "2.9",
                    "2.10",
                    "2.11",
                    "2.12",
                    "2.13",
                    "2.14",
                    "2.15",
                    "2.16",
                    "2.17",
                    "2.18",
                    "2.19",
                    "2.20",
                )
                    legacy_optimizer = optimizer
                    optimizer = WannierizationOptimizerState(
                        legacy_optimizer.strategy,
                        legacy_optimizer.z_mix_ratio,
                        legacy_optimizer.u_mix_ratio,
                        legacy_optimizer.improvement_streak,
                        legacy_optimizer.rejected_steps,
                        legacy_optimizer.residual_reference,
                        legacy_optimizer.previous_merit,
                        legacy_optimizer.anderson_z_history,
                        legacy_optimizer.anderson_residual_history,
                        legacy_optimizer.phase,
                        legacy_optimizer.z_stability_count,
                        legacy_optimizer.u_stability_count,
                        legacy_optimizer.z_steps,
                        legacy_optimizer.u_steps,
                        legacy_optimizer.epoch,
                        legacy_optimizer.last_accepted_u_step_scale,
                        legacy_optimizer.gradient_fallback_active,
                        legacy_optimizer.gradient_steps,
                        legacy_optimizer.best_polar_frames,
                        legacy_optimizer.best_polar_centers,
                        legacy_optimizer.best_polar_spreads,
                        legacy_optimizer.best_polar_objective,
                        legacy_optimizer.disentanglement_objective_history,
                        legacy_optimizer.localization_objective_history,
                        legacy_optimizer.localization_trial_step_scales,
                        legacy_optimizer.localization_trial_objectives,
                        legacy_optimizer.localization_trial_required_changes,
                        legacy_optimizer.localization_trial_actual_changes,
                        legacy_optimizer.localization_trial_directional_derivatives,
                        legacy_optimizer.localization_projector_drift_history,
                        legacy_optimizer.localization_trial_iterations,
                        legacy_optimizer.localization_trial_sweeps,
                        legacy_optimizer.localization_trial_accepted,
                        Array{ComplexF64, 3}(read(optimizer_group["previous_u_gradient"])),
                        Array{ComplexF64, 3}(read(optimizer_group["previous_u_direction"])),
                        Int(required_attribute(optimizer_group, "u_cg_iteration")),
                        Int(required_attribute(optimizer_group, "u_cg_restart_count")),
                        Float64(required_attribute(optimizer_group, "last_cg_beta")),
                        Symbol(
                            String(required_attribute(optimizer_group, "last_cg_restart_reason")),
                        ),
                        Symbol(String(required_attribute(optimizer_group, "last_anderson_reason"))),
                    )
                end
                if version in (
                    "2.10",
                    "2.11",
                    "2.12",
                    "2.13",
                    "2.14",
                    "2.15",
                    "2.16",
                    "2.17",
                    "2.18",
                    "2.19",
                    "2.20",
                )
                    legacy_optimizer = optimizer
                    optimizer = WannierizationOptimizerState(
                        legacy_optimizer.strategy,
                        legacy_optimizer.z_mix_ratio,
                        legacy_optimizer.u_mix_ratio,
                        legacy_optimizer.improvement_streak,
                        legacy_optimizer.rejected_steps,
                        legacy_optimizer.residual_reference,
                        legacy_optimizer.previous_merit,
                        legacy_optimizer.anderson_z_history,
                        legacy_optimizer.anderson_residual_history,
                        legacy_optimizer.phase,
                        legacy_optimizer.z_stability_count,
                        legacy_optimizer.u_stability_count,
                        legacy_optimizer.z_steps,
                        legacy_optimizer.u_steps,
                        legacy_optimizer.epoch,
                        legacy_optimizer.last_accepted_u_step_scale,
                        legacy_optimizer.gradient_fallback_active,
                        legacy_optimizer.gradient_steps,
                        legacy_optimizer.best_polar_frames,
                        legacy_optimizer.best_polar_centers,
                        legacy_optimizer.best_polar_spreads,
                        legacy_optimizer.best_polar_objective,
                        legacy_optimizer.disentanglement_objective_history,
                        legacy_optimizer.localization_objective_history,
                        legacy_optimizer.localization_trial_step_scales,
                        legacy_optimizer.localization_trial_objectives,
                        legacy_optimizer.localization_trial_required_changes,
                        legacy_optimizer.localization_trial_actual_changes,
                        legacy_optimizer.localization_trial_directional_derivatives,
                        legacy_optimizer.localization_projector_drift_history,
                        legacy_optimizer.localization_trial_iterations,
                        legacy_optimizer.localization_trial_sweeps,
                        legacy_optimizer.localization_trial_accepted,
                        legacy_optimizer.previous_u_gradient,
                        legacy_optimizer.previous_u_direction,
                        legacy_optimizer.u_cg_iteration,
                        legacy_optimizer.u_cg_restart_count,
                        legacy_optimizer.last_cg_beta,
                        legacy_optimizer.last_cg_restart_reason,
                        legacy_optimizer.last_anderson_reason,
                        String(required_attribute(optimizer_group, "u_phase_contract")),
                        String(required_attribute(optimizer_group, "u_active_orbit_sha256")),
                        Int(required_attribute(optimizer_group, "u_active_orbit_count")),
                        Float64(required_attribute(optimizer_group, "u_generalized_gradient_rms")),
                        Array{ComplexF64, 4}(read(optimizer_group["u_lbfgs_s_history"])),
                        Array{ComplexF64, 4}(read(optimizer_group["u_lbfgs_y_history"])),
                        Vector{Float64}(read(optimizer_group["u_lbfgs_rho_history"])),
                        Int(required_attribute(optimizer_group, "u_lbfgs_restart_count")),
                        Symbol(
                            String(
                                required_attribute(
                                    optimizer_group,
                                    "last_u_optimizer_restart_reason",
                                ),
                            ),
                        ),
                    )
                end
                if contract_version in ("2.22", "2.23", "2.24", "2.25", "2.26", "2.27", "2.28") &&
                   haskey(optimizer_group, "wannier90_reference_overlaps") &&
                   haskey(optimizer_group, "wannier90_reference_unitaries") &&
                   haskey(HDF5.attributes(optimizer_group), "wannier90_reference_omega_i")
                    legacy_fields = ntuple(index -> getfield(optimizer, index), 49)
                    optimizer = WannierizationOptimizerState(
                        legacy_fields...,
                        Array{ComplexF64, 4}(read(optimizer_group["wannier90_reference_overlaps"])),
                        Array{ComplexF64, 3}(
                            read(optimizer_group["wannier90_reference_unitaries"]),
                        ),
                        Float64(required_attribute(optimizer_group, "wannier90_reference_omega_i")),
                    )
                end
                has_fixed_subspace =
                    version in (
                        "2.4",
                        "2.5",
                        "2.6",
                        "2.7",
                        "2.8",
                        "2.9",
                        "2.10",
                        "2.11",
                        "2.12",
                        "2.13",
                        "2.14",
                        "2.15",
                        "2.16",
                        "2.17",
                        "2.18",
                        "2.19",
                        "2.20",
                    ) && Bool(read(restart_group["has_fixed_subspace"]))
                has_localization_initial_frames =
                    version in (
                        "2.4",
                        "2.5",
                        "2.6",
                        "2.7",
                        "2.8",
                        "2.9",
                        "2.10",
                        "2.11",
                        "2.12",
                        "2.13",
                        "2.14",
                        "2.15",
                        "2.16",
                        "2.17",
                        "2.18",
                        "2.19",
                        "2.20",
                    ) && Bool(read(restart_group["has_localization_initial_frames"]))
                WannierizationRestartState(
                    Int(required_attribute(restart_group, "iteration")),
                    Array{ComplexF64, 3}(read(restart_group["frames"])),
                    has_z_previous ? Array{ComplexF64, 3}(read(restart_group["z_previous"])) :
                    nothing,
                    Matrix{Float64}(read(restart_group["centers_cartesian"])),
                    Vector{Float64}(read(restart_group["spreads_angstrom2"])),
                    Matrix{Float64}(read(restart_group["convergence_values"])),
                    BitMatrix(Bool.(read(restart_group["included_bands"]))),
                    Float64(required_attribute(restart_group, "elapsed_seconds")),
                    String(required_attribute(restart_group, "config_sha256")),
                    String(required_attribute(restart_group, "representation_sha256")),
                    stencil,
                    String(required_attribute(restart_group, "projection_basis_sha256")),
                    String(required_attribute(restart_group, "amn_sha256")),
                    optimizer,
                    has_fixed_subspace ?
                    Array{ComplexF64, 3}(read(restart_group["fixed_subspace_projectors"])) :
                    nothing,
                    has_fixed_subspace ?
                    Array{ComplexF64, 3}(read(restart_group["fixed_subspace_frames"])) : nothing,
                    has_localization_initial_frames ?
                    Array{ComplexF64, 3}(read(restart_group["localization_initial_frames"])) :
                    nothing,
                )
            else
                nothing
            end
        input_summary = read_string_dictionary(handle["input_summary"])
        get!(input_summary, "construction_policy", "strict")
        input_summary["construction_policy"] in ("strict", "diagnostic") ||
            throw(ArgumentError("CONSTRUCTION_POLICY_INVALID: unsupported persisted policy"))
        if haskey(input_summary, "construction_policy_contract")
            input_summary["construction_policy_contract"] == "diagnostic_construction_v1" ||
                throw(ArgumentError("CONSTRUCTION_POLICY_CONTRACT_UNSUPPORTED"))
        elseif input_summary["construction_policy"] != "strict"
            throw(
                ArgumentError(
                    "CONSTRUCTION_POLICY_CONTRACT_MISSING: diagnostic policy requires a sealed contract",
                ),
            )
        end
        deleted_tag_present =
            haskey(input_summary, "symmetry_mode") || any(
                value -> value in ("ordinary_no_symmetry", "wannier90_reference"),
                values(input_summary),
            )
        deleted_tag_present && throw(
            ArgumentError(
                "RESTART_SEMANTICS_INCOMPATIBLE: checkpoint contains a removed mode or algorithm tag",
            ),
        )
        if stored_version == "2.25"
            for key in (
                "requested_wannierization_mode",
                "effective_wannierization_mode",
                "representation_source",
                "symmetry_constraints_applied",
                "effective_algorithm_profile",
                "wannier90_reference_algorithm_contract_version",
            )
                haskey(input_summary, key) ||
                    throw(ArgumentError("schema-2.25 checkpoint is missing $(key)"))
            end
        end
        if contract_version in ("2.26", "2.27", "2.28")
            for key in (
                "requested_wannierization_mode",
                "effective_wannierization_mode",
                "representation_source",
                "symmetry_constraints_applied",
                "effective_algorithm_profile",
                "smv_fletcher_reeves_two_stage_algorithm_contract_version",
                "smv_fletcher_reeves_two_stage_default_selection_reason",
            )
                haskey(input_summary, key) ||
                    throw(ArgumentError("schema-$(stored_version) checkpoint is missing $(key)"))
            end
        end
        if stored_version == "2.27" &&
           get(input_summary, "qualification_scope", "full_parent") == "target_subspace"
            throw(
                ArgumentError(
                    "UNSUPPORTED_LEGACY_TARGET_LEAKAGE_SEMANTICS: schema-2.27 target checkpoint uses amplitude leakage gates",
                ),
            )
        end
        if contract_version == "2.28"
            for key in (
                "authoritative_hamiltonian",
                "authoritative_hamiltonian_sha256",
                "qualification_scope",
                "target_authority",
                "parent_audit_policy",
            )
                haskey(input_summary, key) ||
                    throw(ArgumentError("schema-$(stored_version) checkpoint is missing $(key)"))
            end
            if input_summary["qualification_scope"] == "target_subspace"
                for key in (
                    "disentanglement_outer_mask_sha256",
                    "disentanglement_frozen_mask_sha256",
                    "target_subspace_contract_sha256",
                    "target_leakage_semantics",
                    "target_leakage_formula_sha256",
                    "target_leakage_threshold",
                )
                    haskey(input_summary, key) || throw(
                        ArgumentError("schema-$(stored_version) checkpoint is missing $(key)"),
                    )
                end
                _validate_persisted_target_subspace_contract(input_summary)
            else
                validate_persisted_authority_key(input_summary["authoritative_hamiltonian"])
            end
        end
        get!(input_summary, "sewing_backend", "coefficient_mapping")
        get!(input_summary, "sewing_metric", "pseudo_coefficient_linear_map")
        get!(input_summary, "paw_sewing_thresholds", "NOT_APPLICABLE")
        get!(input_summary, "strict_sewing_diagnostics_sha256", "NOT_RECORDED")
        get!(input_summary, "wavefunction_gauge_backend", "native_eigenstate")
        get!(input_summary, "wavefunction_gauge_hdf5_sha256", "NOT_APPLICABLE")
        get!(input_summary, "block_partition_policy", "NOT_APPLICABLE")
        get!(input_summary, "block_partition_policy_sha256", "NOT_APPLICABLE")
        get!(input_summary, "authoritative_hamiltonian", "native_dft")
        validate_persisted_authority_key(input_summary["authoritative_hamiltonian"])
        contract_version != "2.28" &&
            input_summary["authoritative_hamiltonian"] == "symmetrized_dft_hamiltonian" &&
            throw(
                ArgumentError(
                    "UNSUPPORTED_LEGACY_TARGET_LEAKAGE_SEMANTICS: pre-2.28 symmetrized target checkpoints cannot be resumed or upgraded",
                ),
            )
        get!(input_summary, "authoritative_hamiltonian_sha256", "LEGACY_NATIVE_DFT")
        get!(input_summary, "native_fidelity_status", "NOT_RECORDED")
        get!(input_summary, "symmetrized_hamiltonian_status", "NOT_APPLICABLE")
        get!(input_summary, "scoped_production_eligible", "false")
        get!(input_summary, "energy_shift_qualification", "legacy_energy_shift_hard_gate")
        get!(input_summary, "maximum_energy_shift_audit_reference_ev", "NOT_APPLICABLE")
        get!(input_summary, "rms_energy_shift_audit_reference_ev", "NOT_APPLICABLE")
        get!(input_summary, "target_energy_shift_audit_status", "NOT_APPLICABLE")
        get!(input_summary, "symmetrized_parent_energy_shift_audit_status", "NOT_APPLICABLE")
        get!(input_summary, "residual_gate_phase", "legacy_pre_symmetrization")
        get!(input_summary, "raw_preflight_diagnostic_status", "NOT_APPLICABLE")
        get!(input_summary, "native_difference_qualification", "legacy_hard_gate")
        get!(input_summary, "native_difference_audit_status", "NOT_APPLICABLE")
        get!(input_summary, "qualification_scope", "full_parent")
        get!(input_summary, "target_authority", "NOT_APPLICABLE")
        get!(input_summary, "parent_audit_policy", "legacy_hard_gate")
        get!(input_summary, "target_anchor", "NOT_APPLICABLE")
        get!(input_summary, "target_complement_completion", "NOT_APPLICABLE")
        get!(input_summary, "target_complement_max_element_ev", "NOT_APPLICABLE")
        get!(input_summary, "auxiliary_parent_qualification", "legacy_hard_gate")
        get!(input_summary, "symmetrized_target_subspace_status", "NOT_APPLICABLE")
        get!(input_summary, "auxiliary_parent_audit_status", "NOT_APPLICABLE")
        get!(input_summary, "target_scope_production_eligible", "false")
        target_leakage_semantics_default =
            contract_version == "2.28" ? "NOT_APPLICABLE" : "LEGACY_AMPLITUDE_LEAKAGE_CONTRACT"
        target_leakage_threshold_default =
            contract_version == "2.28" ? "NOT_APPLICABLE" : "NOT_RECORDED"
        get!(input_summary, "target_leakage_semantics", target_leakage_semantics_default)
        get!(input_summary, "target_leakage_formula_sha256", "NOT_RECORDED")
        get!(input_summary, "target_leakage_threshold", target_leakage_threshold_default)
        get!(input_summary, "wannier90_reference_algorithm_contract_version", "legacy")
        get!(input_summary, "wannier90_reference_parity_standard_version", "legacy")
        get!(input_summary, "wannier90_reference_parity_semantic", "legacy")
        get!(input_summary, "wannier90_reference_accepted_step_combination_rule", "NOT_APPLICABLE")
        get!(
            input_summary,
            "wannier90_reference_accepted_step_absolute_tolerance",
            "NOT_APPLICABLE",
        )
        get!(
            input_summary,
            "wannier90_reference_accepted_step_relative_tolerance",
            "NOT_APPLICABLE",
        )
        get!(input_summary, "wannier90_reference_parity_contract_sha256", "NOT_APPLICABLE")
        get!(input_summary, "wannier90_reference_default_qualification_status", "NOT_QUALIFIED")
        get!(
            input_summary,
            "wannier90_reference_default_qualification_manifest_sha256",
            "NOT_AVAILABLE",
        )
        get!(input_summary, "smv_fletcher_reeves_two_stage_algorithm_contract_version", "legacy")
        get!(input_summary, "smv_fletcher_reeves_two_stage_default_selection_reason", "legacy")
        get!(input_summary, "smv_fletcher_reeves_two_stage_protocol", "NOT_APPLICABLE")
        get!(input_summary, "smv_fletcher_reeves_two_stage_audit_status", "AUDIT_NOT_PROVIDED")
        get!(input_summary, "smv_fletcher_reeves_two_stage_audit_reason", "NOT_AVAILABLE")
        get!(input_summary, "smv_fletcher_reeves_two_stage_audit_manifest_sha256", "NOT_AVAILABLE")
        # Preserve the legacy/native scientific payload exactly. New
        # symmetrized authorities already persist an explicit false value;
        # only old summaries that lack the field receive the fail-closed default.
        get!(input_summary, "global_production_eligible", "false")
        input_summary["checkpoint_schema_version"] = stored_version
        # Public 1.0 and legacy 2.28 carry the same leakage-weight restart contract.
        input_summary["restart_eligible"] = string(contract_version == "2.28")
        contract_version == "2.28" ||
            (input_summary["restart_rejection_code"] = "RESTART_SEMANTICS_INCOMPATIBLE")
        version in (
            "2.7",
            "2.8",
            "2.9",
            "2.10",
            "2.11",
            "2.12",
            "2.13",
            "2.14",
            "2.15",
            "2.16",
            "2.17",
            "2.18",
            "2.19",
            "2.20",
        ) && (
            input_summary["checkpoint_localization_gradient_contract"] =
                String(required_attribute(handle, "localization_gradient_contract"))
        )
        if version in (
            "2.8",
            "2.9",
            "2.10",
            "2.11",
            "2.12",
            "2.13",
            "2.14",
            "2.15",
            "2.16",
            "2.17",
            "2.18",
            "2.19",
            "2.20",
        )
            input_summary["checkpoint_joint_update_contract"] =
                String(required_attribute(handle, "joint_update_contract"))
            input_summary["checkpoint_z_seal_class"] =
                String(required_attribute(handle, "z_seal_class"))
        end
        if version == "2.8"
            input_summary["constraint_operation_scope"] = "full"
            input_summary["constraint_operation_parent_representation_sha256"] =
                get(input_summary, "representation_sha256", "")
            input_summary["constraint_operation_subgroup_sha256"] =
                get(input_summary, "representation_sha256", "")
            input_summary["constraint_operation_parent_indices"] = "NOT_RECORDED"
            input_summary["symmetry_ablation_classification"] = "NOT_APPLICABLE"
            input_summary["checkpoint_constraint_scope_compatibility"] = "LEGACY_DEFAULT_FULL"
        elseif version in (
            "2.9",
            "2.10",
            "2.11",
            "2.12",
            "2.13",
            "2.14",
            "2.15",
            "2.16",
            "2.17",
            "2.18",
            "2.19",
            "2.20",
        )
            input_summary["checkpoint_constraint_operation_scope"] =
                String(required_attribute(handle, "constraint_operation_scope"))
            input_summary["checkpoint_constraint_operation_parent_representation_sha256"] = String(
                required_attribute(handle, "constraint_operation_parent_representation_sha256"),
            )
            input_summary["checkpoint_constraint_operation_subgroup_sha256"] =
                String(required_attribute(handle, "constraint_operation_subgroup_sha256"))
        end
        if version == "2.0"
            accepted = restart_state === nothing ? -1 : restart_state.iteration
            input_summary["solver_status"] = string(status)
            input_summary["stopping_reason"] = String(required_attribute(handle, "stopping_reason"))
            input_summary["last_attempted_iteration"] = "-1"
            input_summary["last_accepted_iteration"] = string(accepted)
            input_summary["last_persisted_iteration"] = string(accepted)
            input_summary["has_accepted_state"] = string(accepted >= 0)
            input_summary["legacy_terminal_semantics"] = "true"
            input_summary["convergence_metric_name"] = "center_spread_window_std_max"
            input_summary["convergence_metric"] =
                string(Float64(required_attribute(handle, "convergence_metric")))
        end
        if version in ("2.0", "2.1")
            input_summary["initialization_status"] =
                get(input_summary, "initialization_status", "UNKNOWN")
            input_summary["initializer_algorithm_version"] =
                get(input_summary, "initializer_algorithm_version", "NOT_RECORDED")
            input_summary["solver_convergence"] =
                get(input_summary, "solver_convergence", "UNKNOWN")
            input_summary["numerical_quality"] =
                get(input_summary, "numerical_quality", "NOT_RECORDED")
            input_summary["tb_export_status"] =
                get(input_summary, "tb_export_status", "NOT_RECORDED")
        end
        initialization_report =
            version in (
                "2.2",
                "2.3",
                "2.4",
                "2.5",
                "2.6",
                "2.7",
                "2.8",
                "2.9",
                "2.10",
                "2.11",
                "2.12",
                "2.13",
                "2.14",
                "2.15",
                "2.16",
                "2.17",
                "2.18",
                "2.19",
                "2.20",
            ) ? _read_initialization_report(handle) : nothing
        tb_symmetry_qualification =
            version in (
                "2.5",
                "2.6",
                "2.7",
                "2.8",
                "2.9",
                "2.10",
                "2.11",
                "2.12",
                "2.13",
                "2.14",
                "2.15",
                "2.16",
                "2.17",
                "2.18",
                "2.19",
                "2.20",
            ) ? read_tb_symmetry_qualification_group(handle) :
            tb_symmetry_not_run("LEGACY_SCHEMA_FIELD_ABSENT")
        result = WannierizationResult(
            status,
            v_matrix,
            centers,
            spreads,
            history,
            diagnostics,
            input_summary,
            chk,
            abspath(filename),
            restart_state,
            WannierizationArtifacts(checkpoint_hdf5 = abspath(filename)),
            initialization_report,
            tb_symmetry_qualification,
        )
        if version in (
            "2.0",
            "2.1",
            "2.2",
            "2.3",
            "2.4",
            "2.5",
            "2.6",
            "2.7",
            "2.8",
            "2.9",
            "2.10",
            "2.11",
            "2.12",
            "2.13",
            "2.14",
            "2.15",
            "2.16",
            "2.17",
            "2.18",
            "2.19",
            "2.20",
        )
            attributes = HDF5.attributes(handle)
            stored_checkpoint_sha256 = String(required_attribute(handle, "checkpoint_sha256"))
            computed_checkpoint_sha256 = if stored_version == "1.0"
                _wannierization_checkpoint_sha256_v1_0(result)
            elseif stored_version == "2.28"
                _wannierization_checkpoint_sha256_v2_28(result)
            elseif stored_version == "2.27"
                _wannierization_checkpoint_sha256_v2_27(result)
            elseif stored_version == "2.26"
                _wannierization_checkpoint_sha256_v2_26(result)
            elseif stored_version == "2.25"
                _wannierization_checkpoint_sha256_v2_25(result)
            elseif stored_version == "2.24"
                _wannierization_checkpoint_sha256_v2_24(result)
            elseif stored_version == "2.23"
                _wannierization_checkpoint_sha256_v2_23(result)
            elseif stored_version == "2.22"
                _wannierization_checkpoint_sha256_v2_22(result)
            elseif stored_version == "2.21"
                _wannierization_checkpoint_sha256_v2_21(result)
            elseif version == "2.0"
                _wannierization_checkpoint_sha256_v1_3(result)
            elseif version == "2.1"
                _wannierization_checkpoint_sha256_v2_1(result)
            elseif version == "2.2"
                _wannierization_checkpoint_sha256_v2_2(result)
            elseif version == "2.3"
                _wannierization_checkpoint_sha256_v2_3(result)
            elseif version == "2.4"
                _wannierization_checkpoint_sha256_v2_4(result)
            elseif version == "2.5"
                _wannierization_checkpoint_sha256_v2_5(result)
            elseif version == "2.6"
                _wannierization_checkpoint_sha256_v2_6(result)
            elseif version == "2.7"
                _wannierization_checkpoint_sha256_v2_7(result)
            elseif version == "2.8"
                _wannierization_checkpoint_sha256_v2_8(result)
            elseif version == "2.9"
                _wannierization_checkpoint_sha256_v2_9(result)
            elseif version == "2.10"
                _wannierization_checkpoint_sha256_v2_10(result)
            elseif version == "2.11"
                _wannierization_checkpoint_sha256_v2_11(result)
            elseif version == "2.12"
                _wannierization_checkpoint_sha256_v2_12(result)
            elseif version == "2.16"
                _wannierization_checkpoint_sha256_v2_16(result)
            elseif version == "2.17"
                _wannierization_checkpoint_sha256_v2_17(result)
            elseif version == "2.18"
                _wannierization_checkpoint_sha256_v2_18(result)
            elseif version == "2.19"
                _wannierization_checkpoint_sha256_v2_19(result)
            elseif version == "2.20"
                _wannierization_checkpoint_sha256_v2_20(result)
            else
                _wannierization_checkpoint_sha256_v2_13(result)
            end
            if stored_checkpoint_sha256 != computed_checkpoint_sha256
                stored_summary = read_string_dictionary(handle["input_summary"])
                added_keys = sort!(collect(setdiff(keys(input_summary), keys(stored_summary))))
                changed_keys = sort!([
                    key for key in intersect(keys(input_summary), keys(stored_summary)) if
                    input_summary[key] != stored_summary[key]
                ])
                throw(
                    ArgumentError(
                        "wannierization checkpoint scientific SHA-256 mismatch; " *
                        "stored=$(stored_checkpoint_sha256), computed=$(computed_checkpoint_sha256), " *
                        "reader_added=$(join(added_keys, ',')), reader_changed=$(join(changed_keys, ','))",
                    ),
                )
            end
            if contract_version in ("2.21", "2.22", "2.23", "2.24", "2.25", "2.26", "2.27", "2.28")
                String(required_attribute(handle, "z_u_stage_semantics")) ==
                get(result.input_summary, "z_u_stage_semantics", "") || throw(
                    ArgumentError(
                        "RESTART_SEMANTICS_INCOMPATIBLE: checkpoint Z/U stage contract differs",
                    ),
                )
                get(result.input_summary, "z_u_stage_semantics", "") ==
                "disentanglement_localization_decoupled_v1" || throw(
                    ArgumentError(
                        "RESTART_SEMANTICS_INCOMPATIBLE: schema $(stored_version) requires decoupled Z/U semantics",
                    ),
                )
            end
            if stored_version in ("2.22", "2.23", "2.24", "2.25")
                for key in (
                    "algorithm_profile",
                    "effective_algorithm_profile",
                    "wannier90_reference_protocol",
                )
                    String(required_attribute(handle, key)) == input_summary[key] || throw(
                        ArgumentError("RESTART_SEMANTICS_INCOMPATIBLE: checkpoint $(key) differs"),
                    )
                end
            end
            if contract_version in ("2.26", "2.27", "2.28")
                for key in (
                    "algorithm_profile",
                    "effective_algorithm_profile",
                    "smv_fletcher_reeves_two_stage_protocol",
                    "smv_fletcher_reeves_two_stage_algorithm_contract_version",
                    "smv_fletcher_reeves_two_stage_default_selection_reason",
                )
                    String(required_attribute(handle, key)) == input_summary[key] || throw(
                        ArgumentError("RESTART_SEMANTICS_INCOMPATIBLE: checkpoint $(key) differs"),
                    )
                end
            end
            if contract_version == "2.28"
                for key in (
                    "authoritative_hamiltonian",
                    "authoritative_hamiltonian_sha256",
                    "qualification_scope",
                    "target_authority",
                    "parent_audit_policy",
                    "disentanglement_outer_mask_sha256",
                    "disentanglement_frozen_mask_sha256",
                    "target_subspace_contract_sha256",
                    "target_leakage_semantics",
                    "target_leakage_formula_sha256",
                    "target_leakage_threshold",
                )
                    String(required_attribute(handle, key)) == input_summary[key] || throw(
                        ArgumentError(
                            "TARGET_SUBSPACE_CONTRACT_MISMATCH: checkpoint $(key) differs",
                        ),
                    )
                end
                input_summary["qualification_scope"] == "target_subspace" &&
                    _validate_persisted_target_subspace_contract(input_summary)
                if input_summary["authoritative_hamiltonian"] == "symmetrized_dft_hamiltonian"
                    String(required_attribute(handle, "auxiliary_parent_qualification")) ==
                    input_summary["auxiliary_parent_qualification"] || throw(
                        ArgumentError(
                            "TARGET_SUBSPACE_CONTRACT_MISMATCH: checkpoint auxiliary_parent_qualification differs",
                        ),
                    )
                end
            end
            if stored_version in ("2.23", "2.24", "2.25")
                for key in (
                    "wannier90_reference_algorithm_contract_version",
                    "wannier90_reference_parity_standard_version",
                    "wannier90_reference_parity_semantic",
                    "wannier90_reference_accepted_step_combination_rule",
                    "wannier90_reference_accepted_step_absolute_tolerance",
                    "wannier90_reference_accepted_step_relative_tolerance",
                    "wannier90_reference_parity_contract_sha256",
                    "wannier90_reference_default_qualification_status",
                    "wannier90_reference_default_qualification_manifest_sha256",
                )
                    String(required_attribute(handle, key)) == input_summary[key] || throw(
                        ArgumentError("RESTART_SEMANTICS_INCOMPATIBLE: checkpoint $(key) differs"),
                    )
                end
            end
            if version in ("2.16", "2.17", "2.18", "2.19", "2.20")
                attributes = HDF5.attributes(handle)
                for key in (
                    "authoritative_hamiltonian",
                    "authoritative_hamiltonian_sha256",
                    "native_fidelity_status",
                    "symmetrized_hamiltonian_status",
                )
                    String(required_attribute(handle, key)) == input_summary[key] || throw(
                        ArgumentError("HAMILTONIAN_REFERENCE_MISMATCH: checkpoint $(key) differs"),
                    )
                end
                Bool(required_attribute(handle, "global_production_eligible")) == false || throw(
                    ArgumentError(
                        "symmetrized checkpoint cannot assert global production eligibility",
                    ),
                )
                if version in ("2.17", "2.18", "2.19", "2.20")
                    for key in (
                        "energy_shift_qualification",
                        "maximum_energy_shift_audit_reference_ev",
                        "rms_energy_shift_audit_reference_ev",
                        "target_energy_shift_audit_status",
                        "symmetrized_parent_energy_shift_audit_status",
                    )
                        String(required_attribute(handle, key)) == input_summary[key] || throw(
                            ArgumentError(
                                "HAMILTONIAN_REFERENCE_MISMATCH: checkpoint $(key) differs",
                            ),
                        )
                    end
                end
                if version in ("2.18", "2.19", "2.20")
                    for key in ("residual_gate_phase", "raw_preflight_diagnostic_status")
                        String(required_attribute(handle, key)) == input_summary[key] || throw(
                            ArgumentError(
                                "HAMILTONIAN_REFERENCE_MISMATCH: checkpoint $(key) differs",
                            ),
                        )
                    end
                    if version in ("2.19", "2.20")
                        for key in
                            ("native_difference_qualification", "native_difference_audit_status")
                            String(required_attribute(handle, key)) == input_summary[key] || throw(
                                ArgumentError(
                                    "HAMILTONIAN_REFERENCE_MISMATCH: checkpoint $(key) differs",
                                ),
                            )
                        end
                    end
                    if version == "2.20"
                        for key in (
                            "qualification_scope",
                            "target_anchor",
                            "target_complement_completion",
                            "target_complement_max_element_ev",
                            "auxiliary_parent_qualification",
                            "symmetrized_target_subspace_status",
                            "auxiliary_parent_audit_status",
                            "target_scope_production_eligible",
                        )
                            String(required_attribute(handle, key)) == input_summary[key] || throw(
                                ArgumentError(
                                    "HAMILTONIAN_REFERENCE_MISMATCH: checkpoint $(key) differs",
                                ),
                            )
                        end
                    end
                end
            end
            for (attribute_name, summary_name) in (
                ("input_sha256", "input_sha256"),
                ("config_sha256", "restart_config_sha256"),
                ("representation_sha256", "representation_sha256"),
            )
                String(read(attributes[attribute_name])) ==
                get(result.input_summary, summary_name, "") ||
                    throw(ArgumentError("wannierization checkpoint $(attribute_name) mismatch"))
            end
            if result.restart_state !== nothing
                state = something(result.restart_state)
                state.config_sha256 == get(result.input_summary, "restart_config_sha256", "") ||
                    throw(ArgumentError("restart-state config SHA-256 mismatch"))
                state.representation_sha256 ==
                get(result.input_summary, "representation_sha256", "") ||
                    throw(ArgumentError("restart-state representation SHA-256 mismatch"))
                if version in (
                    "2.0",
                    "2.1",
                    "2.2",
                    "2.3",
                    "2.4",
                    "2.5",
                    "2.6",
                    "2.7",
                    "2.8",
                    "2.9",
                    "2.10",
                    "2.11",
                    "2.12",
                    "2.13",
                    "2.14",
                    "2.15",
                    "2.16",
                    "2.17",
                    "2.18",
                    "2.19",
                    "2.20",
                )
                    state.projection_basis_sha256 ==
                    get(result.input_summary, "projection_basis_sha256", "") ||
                        throw(ArgumentError("restart-state projection basis SHA-256 mismatch"))
                    state.amn_sha256 == get(result.input_summary, "amn_sha256", "") ||
                        throw(ArgumentError("restart-state AMN SHA-256 mismatch"))
                    something(state.stencil).digest ==
                    get(result.input_summary, "finite_difference_stencil_sha256", "") ||
                        throw(ArgumentError("restart-state stencil SHA-256 mismatch"))
                end
            end
            if version in (
                "2.7",
                "2.8",
                "2.9",
                "2.10",
                "2.11",
                "2.12",
                "2.13",
                "2.14",
                "2.15",
                "2.16",
                "2.17",
                "2.18",
                "2.19",
                "2.20",
            )
                expected_contract =
                    version in (
                        "2.10",
                        "2.11",
                        "2.12",
                        "2.13",
                        "2.14",
                        "2.15",
                        "2.16",
                        "2.17",
                        "2.18",
                        "2.19",
                        "2.20",
                    ) ? LOCALIZATION_GRADIENT_CONTRACT : "mv_q_unwrapped_center_v1"
                get(result.input_summary, "localization_gradient_contract", "") ==
                expected_contract ||
                    throw(ArgumentError("wannierization checkpoint gradient contract mismatch"))
                String(read(attributes["localization_gradient_contract"])) == expected_contract ||
                    throw(
                        ArgumentError(
                            "wannierization checkpoint gradient-contract attribute mismatch",
                        ),
                    )
            end
            if version in (
                "2.8",
                "2.9",
                "2.10",
                "2.11",
                "2.12",
                "2.13",
                "2.14",
                "2.15",
                "2.16",
                "2.17",
                "2.18",
                "2.19",
                "2.20",
            )
                expected_joint_contract = JOINT_UPDATE_CONTRACT
                get(result.input_summary, "joint_update_contract", "") == expected_joint_contract ||
                    throw(ArgumentError("wannierization checkpoint joint contract mismatch"))
                String(read(attributes["joint_update_contract"])) == expected_joint_contract ||
                    throw(
                        ArgumentError(
                            "wannierization checkpoint joint-contract attribute mismatch",
                        ),
                    )
                String(read(attributes["z_seal_class"])) ==
                get(result.input_summary, "z_seal_class", "") ||
                    throw(ArgumentError("wannierization checkpoint Z-seal attribute mismatch"))
                Bool(read(attributes["qualified_z_seal"])) ==
                (get(result.input_summary, "qualified_z_seal", "false") == "true") ||
                    throw(ArgumentError("wannierization checkpoint qualified-Z attribute mismatch"))
            end
            if version in (
                "2.9",
                "2.10",
                "2.11",
                "2.12",
                "2.13",
                "2.14",
                "2.15",
                "2.16",
                "2.17",
                "2.18",
                "2.19",
                "2.20",
            )
                for (attribute_name, summary_name) in (
                    ("constraint_operation_scope", "constraint_operation_scope"),
                    (
                        "constraint_operation_parent_representation_sha256",
                        "constraint_operation_parent_representation_sha256",
                    ),
                    (
                        "constraint_operation_subgroup_sha256",
                        "constraint_operation_subgroup_sha256",
                    ),
                )
                    String(read(attributes[attribute_name])) ==
                    get(result.input_summary, summary_name, "") ||
                        throw(ArgumentError("wannierization checkpoint $(attribute_name) mismatch"))
                end
            end
            if version in
               ("2.11", "2.12", "2.13", "2.14", "2.15", "2.16", "2.17", "2.18", "2.19", "2.20")
                for (attribute_name, summary_name, default_value) in (
                    ("sewing_backend", "sewing_backend", "coefficient_mapping"),
                    ("sewing_metric", "sewing_metric", "pseudo_coefficient_linear_map"),
                    (
                        "strict_sewing_diagnostics_sha256",
                        "strict_sewing_diagnostics_sha256",
                        "NOT_RECORDED",
                    ),
                )
                    String(read(attributes[attribute_name])) ==
                    get(result.input_summary, summary_name, default_value) ||
                        throw(ArgumentError("wannierization checkpoint $(attribute_name) mismatch"))
                end
            end
            if version in ("2.12", "2.13", "2.14", "2.15", "2.16", "2.17", "2.18", "2.19", "2.20")
                for (attribute_name, summary_name, default_value) in (
                    (
                        "wavefunction_gauge_backend",
                        "wavefunction_gauge_backend",
                        "native_eigenstate",
                    ),
                    (
                        "wavefunction_gauge_hdf5_sha256",
                        "wavefunction_gauge_hdf5_sha256",
                        "NOT_APPLICABLE",
                    ),
                )
                    String(read(attributes[attribute_name])) ==
                    get(result.input_summary, summary_name, default_value) ||
                        throw(ArgumentError("wannierization checkpoint $(attribute_name) mismatch"))
                end
            end
            if version in ("2.13", "2.14", "2.15", "2.16", "2.17", "2.18", "2.19", "2.20")
                for (attribute_name, summary_name) in (
                    ("block_partition_policy", "block_partition_policy"),
                    ("block_partition_policy_sha256", "block_partition_policy_sha256"),
                )
                    String(read(attributes[attribute_name])) ==
                    get(result.input_summary, summary_name, "NOT_APPLICABLE") ||
                        throw(ArgumentError("wannierization checkpoint $(attribute_name) mismatch"))
                end
            end
        end
        if version in ("2.4", "2.5", "2.6", "2.7", "2.8", "2.9")
            reset = _reset_legacy_localization_gradient_history(result, version)
            return version == "2.7" ? _reset_legacy_joint_update_history(reset) : reset
        end
        if stored_version in ("2.20", "2.21", "2.22", "2.23")
            summary = Dict{String, String}(result.input_summary)
            summary["checkpoint_schema_version"] = stored_version
            summary["restart_continuation_semantics"] = "LEGACY_DIAGNOSTIC_READ_ONLY"
            summary["restart_eligible"] = "false"
            summary["restart_rejection_code"] = "RESTART_SEMANTICS_INCOMPATIBLE"
            diagnostics = copy(result.diagnostics)
            push!(
                diagnostics,
                WannierizationDiagnostic(
                    :RESTART_SEMANTICS_INCOMPATIBLE,
                    :info,
                    "RESTART_SEMANTICS_INCOMPATIBLE: schema-$(stored_version) cannot restart the current target leakage-weight state machine";
                    context = Dict("source_schema" => stored_version),
                ),
            )
            return WannierizationResult(
                result.status,
                result.v_matrix,
                result.wannier_centers_cartesian,
                result.spreads_angstrom2,
                result.history,
                diagnostics,
                summary,
                result.wannier_chk,
                result.checkpoint_file,
                nothing,
                result.artifacts,
                result.initialization_report,
                result.tb_symmetry_qualification,
            )
        end
        return result
    end
end
