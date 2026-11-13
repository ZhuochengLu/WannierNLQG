# Current files omit obsolete state; explicit legacy conversion accepts only empty
# removed histories. Active removed optimizers cannot be silently resumed as FR.
function _check_removed_optimizer_history(
    group;
    legacy::Bool = false,
    require_complete::Bool = false,
)
    names=(
        "anderson_z_history",
        "anderson_residual_history",
        "u_lbfgs_s_history",
        "u_lbfgs_y_history",
        "u_lbfgs_rho_history",
    )
    attrs=HDF5.attributes(group)
    if legacy
        if require_complete
            all(name->haskey(group, name), names) && haskey(attrs, "u_lbfgs_restart_count") ||
                throw(ArgumentError("LEGACY_OPTIMIZER_HISTORY_INCOMPLETE"))
        end
        String(required_attribute(group, "strategy"))=="fixed" ||
            throw(ArgumentError("REMOVED_OPTIMIZER_MIGRATION_UNSUPPORTED"))
        for name in names
            if haskey(group, name)
                dataset=group[name]
                try
                    isempty(dataset) ||
                        throw(ArgumentError("REMOVED_OPTIMIZER_HISTORY_NOT_EMPTY: $name"))
                finally
                    close(dataset)
                end
            end
        end
        haskey(attrs, "u_lbfgs_restart_count") &&
            Int(read_hdf5_attribute_value(attrs["u_lbfgs_restart_count"], HDF5))!=0 &&
            throw(ArgumentError("REMOVED_OPTIMIZER_HISTORY_NOT_EMPTY: restart count"))
    else
        any(name->haskey(group, name), names) &&
            throw(ArgumentError("OBSOLETE_OPTIMIZER_STATE_IN_CURRENT_WIRE"))
        haskey(attrs, "u_lbfgs_restart_count") &&
            throw(ArgumentError("OBSOLETE_OPTIMIZER_STATE_IN_CURRENT_WIRE"))
    end
    return nothing
end

# A declaration names an immutable artifact; it never proves numerical equality.
function _checkpoint_publication_declaration(
    handle;
    expected_identity = nothing,
    expected_version = nothing,
)
    String(required_attribute(handle, "schema")) == WANNIERIZATION_CHECKPOINT_SCHEMA ||
        throw(ArgumentError("HDF5 file is not a WannierNLQG wannierization checkpoint"))
    version = String(required_attribute(handle, "schema_version"))
    (
        expected_version === nothing ?
        version in (
            WANNIERIZATION_CHECKPOINT_SCHEMA_VERSION,
            WANNIERIZATION_REFERENCED_CHECKPOINT_SCHEMA_VERSION,
        ) : version == expected_version
    ) || throw(
        ArgumentError(
            "CHECKPOINT_SCHEMA_UNSUPPORTED: schema $version is not the current checkpoint format",
        ),
    )
    haskey(HDF5.attributes(handle), "checkpoint_sha256") &&
        throw(ArgumentError("LEGACY_CHECKPOINT_CONTENT_CERTIFICATE_NOT_ALLOWED"))
    if version in (
        WANNIERIZATION_CHECKPOINT_SCHEMA_VERSION,
        WANNIERIZATION_REFERENCED_CHECKPOINT_SCHEMA_VERSION,
    )
        String(required_attribute(handle, "content_authentication")) == "NOT_PERFORMED" ||
            throw(ArgumentError("CHECKPOINT_CONTENT_AUTHENTICATION_POLICY_MISMATCH"))
    end
    identity = String(required_attribute(handle, "publication_identity"))
    !isempty(strip(identity)) && ncodeunits(identity) <= 1024 && !occursin('\0', identity) ||
        throw(ArgumentError("CHECKPOINT_PUBLICATION_DECLARATION_INVALID"))
    expected_identity === nothing ||
        identity == expected_identity ||
        throw(ArgumentError("CHECKPOINT_PUBLICATION_DECLARATION_MISMATCH"))
    return identity
end

# Missing records may not silently adopt old or relocated scientific inputs.
function _checkpoint_receipt_path(source, receipt_path)
    receipt = receipt_path === nothing ? source * ".commit.toml" : abspath(receipt_path)
    if !isfile(receipt)
        HDF5.h5open(source, "r") do handle
            _checkpoint_publication_declaration(handle)
        end
        throw(
            ArgumentError(
                "CHECKPOINT_PUBLICATION_RECORD_REQUIRED: explicitly adopt current-format input",
            ),
        )
    end
    return receipt
end

"""Run a checkpoint reader within both source and publication receipt lifetimes."""
function _with_checkpoint_publication(
    reader,
    filename;
    expected_publication = nothing,
    receipt_path = nothing,
)
    isfile(filename) || throw(ArgumentError("wannierization checkpoint does not exist: $filename"))
    observed =
        with_scientific_source(realpath(filename); expected_record = expected_publication) do source
            receipt = _checkpoint_receipt_path(source, receipt_path)
            wire_version = HDF5.h5open(source, "r") do handle
                _checkpoint_publication_declaration(handle)
                String(required_attribute(handle, "schema_version"))
            end
            with_scientific_file_publication(
                source;
                artifact_schema = WANNIERIZATION_CHECKPOINT_SCHEMA,
                artifact_version = wire_version,
                receipt_path = receipt,
            ) do path, identity
                reader(path, identity)
            end
        end
    return observed.value
end

"""Read current checkpoint data under its complete immutable publication lifetime."""
function read_wannierization_checkpoint_hdf5(
    filename::AbstractString;
    expected_publication = nothing,
    receipt_path = nothing,
    reference_root = nothing,
)
    observed =
        _with_checkpoint_publication(filename; expected_publication, receipt_path) do path, identity
            _read_wannierization_checkpoint_from_source(
                path;
                expected_identity = identity,
                reference_root,
            )
        end
    return observed.value
end

"""Explicitly adopt relocated current-format data; never convert a legacy format.

The complete decoder and its domain checks run before the local receipt is
published. Adoption grants neither prior scientific qualification nor equality
with another file. A private receipt path supports read-only source assets.
"""
function adopt_wannierization_checkpoint_hdf5(
    filename::AbstractString;
    receipt_path = nothing,
    reference_root = nothing,
)
    isfile(filename) || throw(ArgumentError("wannierization checkpoint does not exist: $filename"))
    observed = with_scientific_source(realpath(filename)) do source
        _read_wannierization_checkpoint_from_source(source; reference_root)
    end
    write_scientific_file_publication(
        observed.state.path;
        artifact_schema = WANNIERIZATION_CHECKPOINT_SCHEMA,
        artifact_version = observed.value.input_summary["checkpoint_schema_version"],
        publication_identity = observed.value.input_summary["checkpoint_publication_identity"],
        receipt_path,
        expected_state = observed.state,
    )
    return observed.value
end

"""Read only the current checkpoint reference and existing TB qualification report."""
function read_checkpoint_publication(filename::AbstractString; receipt_path = nothing)
    observed = _with_checkpoint_publication(filename; receipt_path) do source, identity
        HDF5.h5open(source, "r") do handle
            _checkpoint_publication_declaration(handle; expected_identity = identity)
            (; identity, qualification = read_tb_symmetry_qualification_group(handle))
        end
    end
    return observed.value
end

# Explicit older-wire payload reading is not optimizer continuation. Older
# accepted-state-only records retain their original metadata verbatim so the
# archived complete-definition oracle remains meaningful; no digest is promoted
# to an actual input/mask definition or scientific qualification.
function _checkpoint_target_input_keys(summary, wire_version)
    current = (
        "disentanglement_outer_mask_definition",
        "disentanglement_frozen_mask_definition",
        "target_subspace_contract_definition",
        "target_leakage_formula_definition",
    )
    if wire_version in ("1.4", "1.5", "1.6") && !all(key -> haskey(summary, key), current)
        get(summary, "restart_eligible", "")=="false" &&
        get(summary, "restart_input_definition_status", "")=="NOT_RECORDED" || throw(
            ArgumentError(
                "LEGACY_COMPLETE_INPUT_DEFINITIONS_REQUIRED: digest-only checkpoint cannot qualify optimizer continuation",
            ),
        )
        return (
            "disentanglement_outer_mask_sha256",
            "disentanglement_frozen_mask_sha256",
            "target_subspace_contract_sha256",
            "target_leakage_formula_sha256",
        )
    end
    return current
end

# Validate current persisted target-subspace definitions or the explicitly retained legacy declaration mirrors.
function _validate_checkpoint_target_input(summary, keys)
    if first(keys)=="disentanglement_outer_mask_definition"
        return _validate_persisted_target_subspace_contract(summary)
    end
    # Validate the old recorded declaration and mirror consistency only. The
    # actual missing mathematical input definitions are deliberately not filled.
    validate_persisted_authority_key(summary["authoritative_hamiltonian"])
    get(summary, "qualification_scope", "")=="target_subspace" &&
    get(summary, "target_authority", "")=="outer_window" &&
    get(summary, "parent_audit_policy", "")=="audit_only" || throw(
        ArgumentError("TARGET_SUBSPACE_CONTRACT_MISMATCH: invalid archived target declaration"),
    )
    all(key -> occursin(r"^[0-9a-f]{64}$", get(summary, key, "")), keys[1:3]) || throw(
        ArgumentError("TARGET_SUBSPACE_CONTRACT_MISMATCH: malformed archived target metadata"),
    )
    get(summary, "target_leakage_semantics", "")==TARGET_LEAKAGE_WEIGHT_SEMANTICS &&
    get(summary, last(keys), "")==TB_TARGET_LEAKAGE_WEIGHT_FORMULA_SHA256 || throw(
        ArgumentError("UNSUPPORTED_LEGACY_TARGET_LEAKAGE_SEMANTICS: archived formula differs"),
    )
    threshold=tryparse(Float64, get(summary, "target_leakage_threshold", ""))
    threshold !== nothing && isfinite(threshold) && threshold>0 || throw(
        ArgumentError("TARGET_SUBSPACE_CONTRACT_MISMATCH: invalid archived leakage threshold"),
    )
    return nothing
end

# Keep the complete decoder and its numerical/domain checks within one observation.
function _read_wannierization_checkpoint_from_source(
    filename::AbstractString;
    expected_identity = nothing,
    wire_version = nothing,
    reference_root = nothing,
)
    HDF5.enable_complex_support()
    return HDF5.h5open(filename, "r") do handle
        publication_identity = _checkpoint_publication_declaration(
            handle;
            expected_identity,
            expected_version = wire_version,
        )
        wire_version = String(required_attribute(handle, "schema_version"))
        stored_version = wire_version
        wire_version == WANNIERIZATION_REFERENCED_CHECKPOINT_SCHEMA_VERSION &&
            reference_root === nothing &&
            throw(ArgumentError("SCIENTIFIC_REFERENCE_ROOT_REQUIRED"))
        # Wire1.4 preserves the complete2.29 physical decoder; current input
        # references are separate from its historical qualification/audit fields.
        contract_version = "2.29"
        # Schema 2.21 is a strict semantic extension of the 2.20 payload.  Reuse
        # the mature 2.20 field decoder, then validate the new scientific hash
        # and Z/U contract independently below.
        version =
            contract_version in
            ("2.21", "2.22", "2.23", "2.24", "2.25", "2.26", "2.27", "2.28", "2.29") ? "2.20" :
            contract_version
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
        frame_distances = Dict{Int, Float64}()
        if wire_version in (
            WANNIERIZATION_CHECKPOINT_SCHEMA_VERSION,
            WANNIERIZATION_REFERENCED_CHECKPOINT_SCHEMA_VERSION,
        ) && has_iteration_diagnostics
            size(diagnostic_values, 1) == 24 ||
                throw(ArgumentError("CHECKPOINT_DIAGNOSTIC_LAYOUT_INVALID"))
            haskey(history_group, "frame_distances") ==
            haskey(history_group, "frame_distance_iterations") ||
                throw(ArgumentError("CHECKPOINT_FRAME_DISTANCE_INCOMPLETE"))
            if haskey(history_group, "frame_distances")
                indices = Int.(read(history_group["frame_distance_iterations"]))
                distances = Float64.(read(history_group["frame_distances"]))
                length(indices) == length(distances) &&
                length(unique(indices)) == length(indices) &&
                all(i -> 1 <= i <= length(iterations), indices) ||
                    throw(ArgumentError("CHECKPOINT_FRAME_DISTANCE_INDEX_INVALID"))
                for (index, distance) in zip(indices, distances)
                    frame_distances[index] = distance
                end
            end
        end
        diagnostic_value(row, index) =
            wire_version in (
                WANNIERIZATION_CHECKPOINT_SCHEMA_VERSION,
                WANNIERIZATION_REFERENCED_CHECKPOINT_SCHEMA_VERSION,
            ) ?
            (
                row == 4 ? get(frame_distances, index, nothing) :
                diagnostic_values[row > 4 ? row-1 : row, index]
            ) : diagnostic_values[row, index]
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
                            diagnostic_value(1, index),
                            diagnostic_value(2, index),
                            diagnostic_value(3, index),
                            diagnostic_value(4, index),
                            diagnostic_value(5, index),
                            diagnostic_value(6, index),
                            diagnostic_value(7, index),
                            diagnostic_value(8, index),
                            diagnostic_value(9, index),
                            diagnostic_value(10, index),
                            diagnostic_integers[1, index],
                            Bool(diagnostic_flags[1, index]),
                            Bool(diagnostic_flags[2, index]),
                            diagnostic_integers[2, index],
                            diagnostic_value(11, index),
                            diagnostic_value(12, index),
                            diagnostic_integers[3, index],
                            diagnostic_value(13, index),
                            diagnostic_value(14, index),
                            diagnostic_value(15, index),
                            diagnostic_value(16, index),
                            diagnostic_value(17, index),
                            Symbol(anderson_reasons[index]),
                            diagnostic_value(18, index),
                            diagnostic_integers[5, index],
                            diagnostic_integers[6, index],
                            diagnostic_integers[7, index],
                            diagnostic_value(19, index),
                            Bool(diagnostic_flags[3, index]),
                            Symbol(cg_restart_reasons[index]),
                            diagnostic_value(20, index),
                            diagnostic_value(21, index),
                            diagnostic_integers[8, index],
                            diagnostic_value(22, index),
                            diagnostic_value(23, index),
                            diagnostic_integers[9, index],
                            diagnostic_integers[10, index],
                            diagnostic_value(24, index),
                            diagnostic_value(25, index),
                            Symbol(joint_acceptance_reasons[index]),
                        )
                    elseif version in ("2.6", "2.7")
                        WannierizationIterationDiagnostics(
                            omega_directional,
                            diagnostic_value(1, index),
                            diagnostic_value(2, index),
                            diagnostic_value(3, index),
                            diagnostic_value(4, index),
                            diagnostic_value(5, index),
                            diagnostic_value(6, index),
                            diagnostic_value(7, index),
                            diagnostic_value(8, index),
                            diagnostic_value(9, index),
                            diagnostic_value(10, index),
                            diagnostic_integers[1, index],
                            Bool(diagnostic_flags[1, index]),
                            Bool(diagnostic_flags[2, index]),
                            diagnostic_integers[2, index],
                            diagnostic_value(11, index),
                            diagnostic_value(12, index),
                            diagnostic_integers[3, index],
                            diagnostic_value(13, index),
                            diagnostic_value(14, index),
                            diagnostic_value(15, index),
                            diagnostic_value(16, index),
                            diagnostic_value(17, index),
                            Symbol(anderson_reasons[index]),
                            diagnostic_value(18, index),
                            diagnostic_integers[5, index],
                            diagnostic_integers[6, index],
                            diagnostic_integers[7, index],
                            diagnostic_value(19, index),
                            Bool(diagnostic_flags[3, index]),
                            Symbol(cg_restart_reasons[index]),
                            diagnostic_value(20, index),
                            diagnostic_value(21, index),
                            diagnostic_integers[8, index],
                        )
                    elseif version in ("2.4", "2.5")
                        WannierizationIterationDiagnostics(
                            omega_directional,
                            diagnostic_value(1, index),
                            diagnostic_value(2, index),
                            diagnostic_value(3, index),
                            diagnostic_value(4, index),
                            diagnostic_value(5, index),
                            diagnostic_value(6, index),
                            diagnostic_value(7, index),
                            diagnostic_value(8, index),
                            diagnostic_value(9, index),
                            diagnostic_value(10, index),
                            diagnostic_integers[1, index],
                            Bool(diagnostic_flags[1, index]),
                            Bool(diagnostic_flags[2, index]),
                            diagnostic_integers[2, index],
                            diagnostic_value(11, index),
                            diagnostic_value(12, index),
                            diagnostic_integers[3, index],
                            diagnostic_value(13, index),
                            diagnostic_value(14, index),
                            diagnostic_value(15, index),
                            diagnostic_value(16, index),
                            diagnostic_value(17, index),
                        )
                    elseif version in ("2.2", "2.3")
                        WannierizationIterationDiagnostics(
                            omega_directional,
                            diagnostic_value(1, index),
                            diagnostic_value(2, index),
                            diagnostic_value(3, index),
                            diagnostic_value(4, index),
                            diagnostic_value(5, index),
                            diagnostic_value(6, index),
                            diagnostic_value(7, index),
                            diagnostic_value(8, index),
                            diagnostic_value(9, index),
                            diagnostic_value(10, index),
                            diagnostic_integers[1, index],
                            Bool(diagnostic_flags[1, index]),
                            Bool(diagnostic_flags[2, index]),
                            diagnostic_integers[2, index],
                            diagnostic_value(11, index),
                            diagnostic_value(12, index),
                            diagnostic_integers[3, index],
                        )
                    else
                        WannierizationIterationDiagnostics(
                            omega_directional,
                            diagnostic_value(1, index),
                            diagnostic_value(2, index),
                            diagnostic_value(3, index),
                            diagnostic_value(4, index),
                            diagnostic_value(5, index),
                            diagnostic_value(6, index),
                            diagnostic_value(7, index),
                            diagnostic_value(8, index),
                            diagnostic_value(9, index),
                            diagnostic_value(10, index),
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
            code = Symbol(String(read_hdf5_attribute_value(group_attributes["code"], HDF5)))
            severity = Symbol(String(read_hdf5_attribute_value(group_attributes["severity"], HDF5)))
            message = String(read_hdf5_attribute_value(group_attributes["message"], HDF5))
            context = Dict{String, String}()
            for attribute_name in keys(group_attributes)
                String(attribute_name) in ("code", "severity", "message") && continue
                context[String(attribute_name)] =
                    String(read_hdf5_attribute_value(group_attributes[attribute_name], HDF5))
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
                )
                optimizer_group = restart_group["optimizer"]
                _check_removed_optimizer_history(
                    optimizer_group;
                    legacy = wire_version=="1.4",
                    require_complete = wire_version=="1.4",
                )
                residual_reference_values = Float64.(read(optimizer_group["residual_reference"]))
                if wire_version in (
                    WANNIERIZATION_CHECKPOINT_SCHEMA_VERSION,
                    WANNIERIZATION_REFERENCED_CHECKPOINT_SCHEMA_VERSION,
                )
                    fields = String(
                        required_attribute(optimizer_group["residual_reference"], "field_order"),
                    )
                    if fields == "projector,z,spread" && length(residual_reference_values) == 3
                        residual_reference_values = (
                            residual_reference_values[1],
                            residual_reference_values[2],
                            nothing,
                            residual_reference_values[3],
                        )
                    elseif fields != "projector,z,frame_distance,spread" ||
                           length(residual_reference_values) != 4
                        throw(ArgumentError("CHECKPOINT_RESIDUAL_REFERENCE_LAYOUT_INVALID"))
                    end
                else
                    length(residual_reference_values) == 4 ||
                        throw(ArgumentError("optimizer residual reference must have length four"))
                end
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
                        Int(required_attribute(optimizer_group, "u_active_orbit_count")),
                        Float64(required_attribute(optimizer_group, "u_generalized_gradient_rms")),
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
                if contract_version in
                   ("2.22", "2.23", "2.24", "2.25", "2.26", "2.27", "2.28", "2.29") &&
                   haskey(optimizer_group, "recursive_localization_overlaps") &&
                   haskey(optimizer_group, "recursive_localization_unitaries") &&
                   haskey(HDF5.attributes(optimizer_group), "recursive_localization_omega_i")
                    legacy_fields = ntuple(index -> getfield(optimizer, index), 42)
                    optimizer = WannierizationOptimizerState(
                        legacy_fields...,
                        Array{ComplexF64, 4}(
                            read(optimizer_group["recursive_localization_overlaps"]),
                        ),
                        Array{ComplexF64, 3}(
                            read(optimizer_group["recursive_localization_unitaries"]),
                        ),
                        Float64(
                            required_attribute(optimizer_group, "recursive_localization_omega_i"),
                        ),
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
                input_definition=_read_restart_input_definition_hdf5(restart_group; reference_root)
                optimizer=_read_restart_branch_definition_hdf5(
                    optimizer_group,
                    optimizer;
                    qualified = input_definition!==nothing,
                )
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
                    stencil,
                    optimizer,
                    has_fixed_subspace ?
                    Array{ComplexF64, 3}(read(restart_group["fixed_subspace_projectors"])) :
                    nothing,
                    has_fixed_subspace ?
                    Array{ComplexF64, 3}(read(restart_group["fixed_subspace_frames"])) : nothing,
                    has_localization_initial_frames ?
                    Array{ComplexF64, 3}(read(restart_group["localization_initial_frames"])) :
                    nothing,
                    input_definition,
                )
            else
                nothing
            end
        input_summary = read_string_dictionary(handle["input_summary"])
        get(input_summary, "checkpoint_publication_identity", "") == publication_identity &&
        get(input_summary, "checkpoint_schema_version", "") == stored_version ||
            throw(ArgumentError("CHECKPOINT_PUBLICATION_DECLARATION_MISMATCH"))

        get!(input_summary, "construction_policy", "strict")
        input_summary["construction_policy"] in ("strict", "standard") ||
            throw(ArgumentError("CONSTRUCTION_POLICY_INVALID: unsupported persisted policy"))
        if haskey(input_summary, "construction_policy_contract")
            policy_contract = input_summary["construction_policy_contract"]
            policy_contract in ("standard_construction_v1", "ordinary_construction_v2") ||
                throw(ArgumentError("CONSTRUCTION_POLICY_CONTRACT_UNSUPPORTED"))
            if policy_contract == "ordinary_construction_v2"
                input_summary["construction_policy"] == "standard" &&
                get(input_summary, "ordinary_calculation_policy_version", "") == "1.0" ||
                    throw(ArgumentError("ORDINARY_CALCULATION_POLICY_CONTRACT_MISMATCH"))
            end
        elseif input_summary["construction_policy"] != "strict"
            throw(
                ArgumentError(
                    "CONSTRUCTION_POLICY_CONTRACT_MISSING: standard policy requires a sealed contract",
                ),
            )
        end
        deleted_tag_present =
            haskey(input_summary, "symmetry_mode") || any(
                value -> value in ("ordinary_no_symmetry", "recursive_localization"),
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
                "recursive_localization_algorithm_contract_version",
            )
                haskey(input_summary, key) ||
                    throw(ArgumentError("schema-2.25 checkpoint is missing $(key)"))
            end
        end
        if contract_version in ("2.26", "2.27", "2.28", "2.29")
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
        target_input_keys = _checkpoint_target_input_keys(input_summary, wire_version)
        if contract_version in ("2.28", "2.29")
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
                    target_input_keys[1],
                    target_input_keys[2],
                    target_input_keys[3],
                    "target_leakage_semantics",
                    target_input_keys[4],
                    "target_leakage_threshold",
                )
                    haskey(input_summary, key) || throw(
                        ArgumentError("schema-$(stored_version) checkpoint is missing $(key)"),
                    )
                end
                _validate_checkpoint_target_input(input_summary, target_input_keys)
            else
                validate_persisted_authority_key(input_summary["authoritative_hamiltonian"])
            end
        end
        get!(input_summary, "sewing_backend", "coefficient_mapping")
        get!(input_summary, "sewing_metric", "pseudo_coefficient_linear_map")
        get!(input_summary, "paw_sewing_thresholds", "NOT_APPLICABLE")
        get!(input_summary, "strict_sewing_diagnostics_sha256", "NOT_RECORDED")
        get!(input_summary, "wavefunction_gauge_backend", "native_eigenstate")
        get!(input_summary, "wavefunction_gauge_definition", "NOT_APPLICABLE")
        get!(input_summary, "block_partition_policy", "NOT_APPLICABLE")
        get!(input_summary, "block_partition_policy_definition", "NOT_APPLICABLE")
        get!(input_summary, "authoritative_hamiltonian", "native_dft")
        validate_persisted_authority_key(input_summary["authoritative_hamiltonian"])
        !(contract_version in ("2.28", "2.29")) &&
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
            contract_version in ("2.28", "2.29") ? "NOT_APPLICABLE" :
            "LEGACY_AMPLITUDE_LEAKAGE_CONTRACT"
        target_leakage_threshold_default =
            contract_version in ("2.28", "2.29") ? "NOT_APPLICABLE" : "NOT_RECORDED"
        get!(input_summary, "target_leakage_semantics", target_leakage_semantics_default)
        get!(input_summary, "target_leakage_formula_definition", "NOT_RECORDED")
        get!(input_summary, "target_leakage_threshold", target_leakage_threshold_default)
        get!(input_summary, "recursive_localization_algorithm_contract_version", "legacy")
        get!(input_summary, "recursive_localization_validation_standard_version", "legacy")
        get!(input_summary, "recursive_localization_validation_semantic", "legacy")
        get!(
            input_summary,
            "recursive_localization_accepted_step_combination_rule",
            "NOT_APPLICABLE",
        )
        get!(
            input_summary,
            "recursive_localization_accepted_step_absolute_tolerance",
            "NOT_APPLICABLE",
        )
        get!(
            input_summary,
            "recursive_localization_accepted_step_relative_tolerance",
            "NOT_APPLICABLE",
        )
        get!(input_summary, "recursive_localization_validation_contract_sha256", "NOT_APPLICABLE")
        get!(input_summary, "recursive_localization_default_qualification_status", "NOT_QUALIFIED")
        get!(
            input_summary,
            "recursive_localization_default_qualification_manifest_sha256",
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
        definition_status=_restart_input_definition_status(restart_state)
        get(input_summary, "restart_input_definition_status", "")==definition_status ||
            throw(ArgumentError("RESTART_INPUT_DEFINITION_STATUS_MISMATCH"))
        declared_eligible=get(input_summary, "restart_eligible", "")
        declared_eligible in ("true", "false") && (
            declared_eligible=="false" ||
            (contract_version in ("2.28", "2.29") && definition_status=="COMPLETE")
        ) || throw(ArgumentError("RESTART_INPUT_ELIGIBILITY_MISMATCH"))
        contract_version in ("2.28", "2.29") ||
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
            # Current recovery binds the complete representation in the saved
            # input definition. Scope and actual parent indices remain explicit;
            # removed content certificates are neither required nor trusted.
            # Older accepted-state-only wires persisted actual indices in the
            # summary, not a second root mirror. Do not fabricate absent indices.
            if wire_version in ("1.4", "1.5", "1.6") &&
               !haskey(HDF5.attributes(handle), "constraint_operation_parent_indices")
                haskey(input_summary, "constraint_operation_parent_indices") || throw(
                    ArgumentError(
                        "CHECKPOINT_DEFINITION_MISSING: constraint_operation_parent_indices",
                    ),
                )
                # Preserve the old summary verbatim for the archived byte oracle.
            else
                input_summary["checkpoint_constraint_operation_parent_indices"] =
                    String(required_attribute(handle, "constraint_operation_parent_indices"))
            end
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
            ) ?
            read_tb_symmetry_qualification_group(
                handle;
                explicit_legacy_migration = !(
                    wire_version in (
                        WANNIERIZATION_CHECKPOINT_SCHEMA_VERSION,
                        WANNIERIZATION_REFERENCED_CHECKPOINT_SCHEMA_VERSION,
                    )
                ),
            ) : tb_symmetry_not_run("LEGACY_SCHEMA_FIELD_ABSENT")
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
            if stored_version == "1.3"
                # Wire1.3 mirrors the typed eligibility block as root
                # attributes; they must agree with the summary group verbatim.
                for key in WANNIERIZATION_ELIGIBILITY_SUMMARY_KEYS
                    String(required_attribute(handle, key)) == get(result.input_summary, key, "") ||
                        throw(
                            ArgumentError(
                                "wannierization checkpoint eligibility attribute mismatch: $(key)",
                            ),
                        )
                end
            end
            if contract_version in
               ("2.21", "2.22", "2.23", "2.24", "2.25", "2.26", "2.27", "2.28", "2.29")
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
                    "recursive_localization_protocol",
                )
                    String(required_attribute(handle, key)) == input_summary[key] || throw(
                        ArgumentError("RESTART_SEMANTICS_INCOMPATIBLE: checkpoint $(key) differs"),
                    )
                end
            end
            if contract_version in ("2.26", "2.27", "2.28", "2.29")
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
            if contract_version in ("2.28", "2.29")
                for key in (
                    "authoritative_hamiltonian",
                    "authoritative_hamiltonian_sha256",
                    "qualification_scope",
                    "target_authority",
                    "parent_audit_policy",
                    target_input_keys[1],
                    target_input_keys[2],
                    target_input_keys[3],
                    "target_leakage_semantics",
                    target_input_keys[4],
                    "target_leakage_threshold",
                )
                    String(required_attribute(handle, key)) == input_summary[key] || throw(
                        ArgumentError(
                            "TARGET_SUBSPACE_CONTRACT_MISMATCH: checkpoint $(key) differs",
                        ),
                    )
                end
                input_summary["qualification_scope"] == "target_subspace" &&
                    _validate_checkpoint_target_input(input_summary, target_input_keys)
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
                    "recursive_localization_algorithm_contract_version",
                    "recursive_localization_validation_standard_version",
                    "recursive_localization_validation_semantic",
                    "recursive_localization_accepted_step_combination_rule",
                    "recursive_localization_accepted_step_absolute_tolerance",
                    "recursive_localization_accepted_step_relative_tolerance",
                    "recursive_localization_validation_contract_sha256",
                    "recursive_localization_default_qualification_status",
                    "recursive_localization_default_qualification_manifest_sha256",
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
            # Content labels do not authenticate accepted state. Complete input
            # definitions and numerical/domain checks govern current recovery.
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
                String(
                    read_hdf5_attribute_value(attributes["localization_gradient_contract"], HDF5),
                ) == expected_contract || throw(
                    ArgumentError("wannierization checkpoint gradient-contract attribute mismatch"),
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
                String(read_hdf5_attribute_value(attributes["joint_update_contract"], HDF5)) ==
                expected_joint_contract || throw(
                    ArgumentError("wannierization checkpoint joint-contract attribute mismatch"),
                )
                String(read_hdf5_attribute_value(attributes["z_seal_class"], HDF5)) ==
                get(result.input_summary, "z_seal_class", "") ||
                    throw(ArgumentError("wannierization checkpoint Z-seal attribute mismatch"))
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
                    ("constraint_operation_parent_indices", "constraint_operation_parent_indices"),
                )
                    if wire_version in ("1.4", "1.5", "1.6") &&
                       attribute_name=="constraint_operation_parent_indices" &&
                       !haskey(attributes, attribute_name)
                        recorded=get(result.input_summary, summary_name, "")
                        !isempty(recorded) || throw(
                            ArgumentError("CHECKPOINT_DEFINITION_MISSING: archived parent indices"),
                        )
                    else
                        String(read_hdf5_attribute_value(attributes[attribute_name], HDF5)) ==
                        get(result.input_summary, summary_name, "") || throw(
                            ArgumentError("wannierization checkpoint $(attribute_name) mismatch"),
                        )
                    end
                end
            end
            if version in
               ("2.11", "2.12", "2.13", "2.14", "2.15", "2.16", "2.17", "2.18", "2.19", "2.20")
                for (attribute_name, summary_name, default_value) in (
                    ("sewing_backend", "sewing_backend", "coefficient_mapping"),
                    ("sewing_metric", "sewing_metric", "pseudo_coefficient_linear_map"),
                )
                    String(read_hdf5_attribute_value(attributes[attribute_name], HDF5)) ==
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
                        "wavefunction_gauge_definition",
                        "wavefunction_gauge_definition",
                        "NOT_APPLICABLE",
                    ),
                )
                    observed = if haskey(attributes, attribute_name)
                        String(read_hdf5_attribute_value(attributes[attribute_name], HDF5))
                    elseif attribute_name == "wavefunction_gauge_definition" &&
                           String(required_attribute(handle, "wavefunction_gauge_backend")) ==
                           "native_eigenstate" &&
                           get(result.input_summary, summary_name, default_value) ==
                           "NOT_APPLICABLE"
                        # Native eigenstates have no applied gauge transformation.
                        "NOT_APPLICABLE"
                    else
                        throw(ArgumentError("CHECKPOINT_DEFINITION_MISSING: $(attribute_name)"))
                    end
                    observed == get(result.input_summary, summary_name, default_value) ||
                        throw(ArgumentError("wannierization checkpoint $(attribute_name) mismatch"))
                end
            end
            if version in ("2.13", "2.14", "2.15", "2.16", "2.17", "2.18", "2.19", "2.20")
                for (attribute_name, summary_name) in (
                    ("block_partition_policy", "block_partition_policy"),
                    ("block_partition_policy_definition", "block_partition_policy_definition"),
                )
                    observed = if haskey(attributes, attribute_name)
                        String(read_hdf5_attribute_value(attributes[attribute_name], HDF5))
                    elseif attribute_name == "block_partition_policy_definition" &&
                           String(required_attribute(handle, "block_partition_policy")) ==
                           "NOT_APPLICABLE"
                        "NOT_APPLICABLE"
                    else
                        throw(ArgumentError("CHECKPOINT_DEFINITION_MISSING: $(attribute_name)"))
                    end
                    observed == get(result.input_summary, summary_name, "NOT_APPLICABLE") ||
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
            summary["restart_continuation_semantics"] = "EXTERNAL_MIGRATION_REQUIRED"
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
        # The decoder and producer share the same physical continuation checks.
        # Replacing a content seal must not admit an invalid optimizer/subspace.
        _validate_checkpoint_fixed_subspace(result)
        return result
    end
end
