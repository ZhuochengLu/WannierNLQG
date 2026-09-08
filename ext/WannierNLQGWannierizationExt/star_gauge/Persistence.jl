# Map a fail-closed exception to the declared root-cause taxonomy.
function _star_root_cause(error)
    message = sprint(showerror, error)
    occursin("PRE_SYMMETRIZATION_STRUCTURAL_HOLD", message) &&
        return :PRE_SYMMETRIZATION_STRUCTURAL_HOLD
    occursin("NONFINITE_STRUCTURAL_HOLD", message) && return :NONFINITE_STRUCTURAL_HOLD
    occursin("PAW_GAUGE_METRIC_RANK_HOLD", message) && return :PAW_GAUGE_METRIC_RANK_HOLD
    occursin("PAW_GAUGE_TARGET_RANK_HOLD", message) && return :PAW_GAUGE_TARGET_RANK_HOLD
    occursin("HAMILTONIAN_REFERENCE_MISMATCH", message) && return :HAMILTONIAN_REFERENCE_MISMATCH
    any(
        marker -> occursin(marker, message),
        (
            "PAW_GAUGE_KSTAR_",
            "PAW_GAUGE_KPOINT_",
            "PAW_GAUGE_NONINTEGER_G_ACTION",
            "PAW_GAUGE_REYNOLDS_DIMENSION_MISMATCH",
            "PAW_GAUGE_TARGET_PROJECTOR_DIMENSION_MISMATCH",
        ),
    ) && return :PRE_SYMMETRIZATION_STRUCTURAL_HOLD
    occursin("POST_SYMMETRIZATION_RECONSTRUCTION_HOLD", message) &&
        return :POST_SYMMETRIZATION_RECONSTRUCTION_HOLD
    occursin("CONTROLLED_SYMMETRIZATION_HOLD", message) && return :CONTROLLED_SYMMETRIZATION_HOLD
    occursin("TARGET_COMPLEMENT_COUPLING_HOLD", message) && return :TARGET_COMPLEMENT_COUPLING_HOLD
    occursin("TARGET_ANCHOR_DRIFT_HOLD", message) && return :TARGET_ANCHOR_DRIFT_HOLD
    occursin("COMPLEMENT_RANK_HOLD", message) && return :COMPLEMENT_RANK_HOLD
    occursin("FORMAL_TARGET_REPRESENTATION_HOLD", message) &&
        return :FORMAL_TARGET_REPRESENTATION_HOLD
    occursin("FORMAL_TARGET_RAW_GROUP_LAW_HOLD", message) &&
        return :FORMAL_TARGET_RAW_GROUP_LAW_HOLD
    occursin("FORMAL_TARGET_ACTION_CORRECTION_HOLD", message) &&
        return :FORMAL_TARGET_ACTION_CORRECTION_HOLD
    occursin("STAR_SELECTION_REACHED_PASS", message) && return :STAR_SELECTION_REACHED_PASS
    occursin("STAR_PREFLIGHT_LIMIT_REACHED_PASS", message) &&
        return :STAR_PREFLIGHT_LIMIT_REACHED_PASS
    occursin("FINITE_BUFFER_HOLD", message) && return :FINITE_BUFFER_HOLD
    occursin("FAR_BAND_PAIR_RESIDUAL_HOLD", message) && return :FAR_BAND_PAIR_RESIDUAL_HOLD
    occursin("FAR_BAND_CUMULATIVE_RESIDUAL_HOLD", message) &&
        return :FAR_BAND_CUMULATIVE_RESIDUAL_HOLD
    occursin("PAW_CANCELLATION_STABILITY_HOLD", message) && return :PAW_CANCELLATION_STABILITY_HOLD
    occursin("BLOCK_PARTITION_HARD_LIMIT_HOLD", message) && return :BLOCK_PARTITION_HARD_LIMIT_HOLD
    occursin("BLOCK_PARTITION_SEARCH_HOLD", message) && return :BLOCK_PARTITION_SEARCH_HOLD
    occursin("BLOCK_PARTITION_PHYSICS_HOLD", message) && return :BLOCK_PARTITION_PHYSICS_HOLD
    occursin("BLOCK_PARTITION_HOLD", message) && return :BLOCK_PARTITION_HOLD
    occursin("INPUT_PROVENANCE_HOLD", message) && return :INPUT_SYMMETRY_HOLD
    occursin("HAMILTONIAN_COVARIANCE_HOLD", message) && return :DISCRETE_HAMILTONIAN_COVARIANCE_HOLD
    occursin("PROPAGATION", message) && return :PAW_PROPAGATION_IMPLEMENTATION_HOLD
    return :PAW_PROPAGATION_IMPLEMENTATION_HOLD
end

# Hash one dense Julia array together with element type and dimensions.
function _star_array_sha256(values::AbstractArray)
    buffer = IOBuffer()
    write(buffer, codeunits(string(eltype(values))))
    write(buffer, UInt8(0))
    write(buffer, reinterpret(UInt8, Int64.(collect(size(values)))))
    dense = collect(values)
    if isbitstype(eltype(dense))
        write(buffer, reinterpret(UInt8, vec(dense)))
    else
        write(buffer, codeunits(repr(dense)))
    end
    return bytes2hex(SHA.sha256(take!(buffer)))
end

# Hash the parsed projector/Q contract independently of raw source paths.
function _star_metric_sha256(metric::_QEStrictSewingMetric)
    buffer = IOBuffer()
    write(buffer, "qe\n", metric.metric_kind, '\n')
    for label in sort!(collect(keys(metric.upf_data)))
        dataset = metric.upf_data[label]
        write(buffer, label, '\n', dataset.element, '\n', String(dataset.metric_kind), '\n')
        for values in (
            dataset.radial_grid_bohr,
            dataset.radial_weights_bohr,
            dataset.beta_radial,
            dataset.beta_angular_momenta,
            dataset.beta_total_angular_momenta,
            dataset.dij,
            dataset.q_integrals,
            dataset.qfcoef,
            dataset.rinner_bohr,
        )
            write(buffer, _star_array_sha256(values), '\n')
        end
        for key in sort!(collect(keys(dataset.q_radial_by_multipole)))
            write(
                buffer,
                join(key, ','),
                '=',
                _star_array_sha256(dataset.q_radial_by_multipole[key]),
                '\n',
            )
        end
    end
    for atom in metric.plan.atoms
        write(
            buffer,
            atom.atomic_type_label,
            '|',
            atom.element,
            '|',
            join(atom.position_fractional, ','),
            '|',
            string(first(atom.channel_range)),
            ':',
            string(last(atom.channel_range)),
            '\n',
        )
        for channel in atom.channels
            write(
                buffer,
                string(channel.radial_index),
                ',',
                string(channel.angular_momentum),
                ',',
                string(channel.harmonic_row),
                ';',
            )
        end
        write(buffer, '\n')
    end
    return bytes2hex(SHA.sha256(take!(buffer)))
end

# Hash the VASP q=0 metric needed by the shared in-memory algorithm.
function _star_metric_sha256(metric::_VASPStrictSewingMetric)
    buffer = IOBuffer()
    write(buffer, "vasp\n", string(metric.paw.num_channels), '\n')
    write(buffer, _star_array_sha256(metric.paw.q0_augmentation), '\n')
    for basis in metric.projector_bases
        write(buffer, _star_array_sha256(basis), '\n')
    end
    return bytes2hex(SHA.sha256(take!(buffer)))
end

"""Return whether a payload carries symmetrized-DFT target-subspace authority."""
_star_target_scoped_symmetrized_payload(payload::_StarCovariantPAWPayload) =
    get(payload.source_metadata, "authoritative_hamiltonian", "") ==
    "symmetrized_dft_hamiltonian" &&
    get(payload.source_metadata, "qualification_scope", "") == "target_subspace"

# Compute one logical payload identity that is stable across HDF5 library versions.
function _star_payload_sha256(
    payload::_StarCovariantPAWPayload;
    schema_version::AbstractString = STAR_COVARIANT_PAW_GAUGE_SCHEMA_VERSION,
    contract_version::AbstractString = schema_version == "1.0" ?
                                       STAR_COVARIANT_PAW_GAUGE_CURRENT_CONTRACT_VERSION :
                                       schema_version,
)
    _validate_star_wire_contract(schema_version, contract_version)
    buffer = IOBuffer()
    write(buffer, schema_version, '\n')
    for (key, value) in sort!(collect(payload.input_sha256); by = first)
        write(buffer, key, '=', value, '\n')
    end
    if contract_version in ("1.6", "1.7", "1.8", "1.9", "1.10", "1.11")
        for (key, value) in sort!(collect(payload.source_metadata); by = first)
            write(buffer, "source_metadata:", key, '=', value, '\n')
        end
    end
    for values in (
        payload.kpoint_map,
        payload.reciprocal_shifts,
        payload.representative_for_kpoint,
        payload.canonical_operation_for_kpoint,
        payload.star_representatives,
        payload.extra_bands_per_star,
        payload.rotations,
        reduce(hcat, (point.energies_ev for point in payload.native.kpoints)),
    )
        write(buffer, _star_array_sha256(values), '\n')
    end
    for operation in payload.operations
        write(buffer, canonical_band_operation_key(operation), '\n')
    end
    for representative in payload.star_representatives
        point = payload.native.kpoints[representative]
        write(buffer, string(representative), ':', _star_array_sha256(point.g_vectors), ':')
        write(buffer, _star_array_sha256(point.coefficients), '\n')
    end
    for point in payload.native.kpoints
        write(buffer, _star_array_sha256(point.g_vectors), '\n')
    end
    if contract_version in ("1.4", "1.5", "1.6", "1.7", "1.8", "1.9", "1.10", "1.11")
        audit = payload.symmetrized_hamiltonian_audit
        write(
            buffer,
            audit === nothing ? "NO_SYMMETRIZED_HAMILTONIAN_AUDIT\n" :
            "HAS_SYMMETRIZED_HAMILTONIAN_AUDIT\n",
        )
        if audit !== nothing
            for values in (
                audit.native_energies_ev,
                audit.symmetrized_energies_ev,
                audit.native_to_symmetrized_rotations,
                audit.representative_native_hamiltonians_ev,
                audit.representative_symmetrized_hamiltonians_ev,
                audit.representative_raw_transports,
                audit.target_principal_angles_rad,
                audit.target_projector_difference_operator,
                audit.target_projector_difference_frobenius,
                audit.native_to_symmetrized_band_assignment,
            )
                write(buffer, _star_array_sha256(values), '\n')
            end
            if contract_version in ("1.5", "1.6", "1.7", "1.8", "1.9", "1.10", "1.11")
                write(buffer, _star_array_sha256(audit.target_energy_shifts_by_star_ev), '\n')
                write(buffer, _star_array_sha256(audit.parent_energy_shifts_by_kpoint_ev), '\n')
            end
            if contract_version in ("1.8", "1.9", "1.10", "1.11")
                if audit.target_anchor_sha256_by_star === nothing
                    write(buffer, "NO_TARGET_COMPLEMENT_COMPLETION\n")
                else
                    write(buffer, join(something(audit.target_anchor_sha256_by_star), ','), '\n')
                    for values in (
                        something(audit.complement_bases),
                        something(audit.complement_rotations),
                        something(audit.target_complement_hamiltonians_ev),
                        something(audit.complement_hamiltonians_ev),
                    )
                        write(buffer, _star_array_sha256(values), '\n')
                    end
                end
            end
        end
    end
    for (key, value) in sort!(collect(payload.maxima); by = first)
        write(buffer, key, '=', repr(value), '\n')
    end
    if contract_version in ("1.10", "1.11")
        scope = payload.qualification_scope
        write(
            buffer,
            scope === nothing ? "NO_TARGET_QUALIFICATION_SCOPE\n" :
            "HAS_TARGET_QUALIFICATION_SCOPE\n",
        )
        if scope !== nothing
            write(buffer, scope.outer_mask_sha256, '\n', scope.frozen_mask_sha256, '\n')
            write(buffer, _star_array_sha256(UInt8.(scope.outer_mask)), '\n')
            write(buffer, _star_array_sha256(UInt8.(scope.frozen_mask)), '\n')
        end
        if _star_target_scoped_symmetrized_payload(payload)
            get(payload.source_metadata, "nonrepresentative_frame_storage", "") ==
            "local_native_source_plus_completed_rotation" || throw(
                ArgumentError(
                    "UNSUPPORTED_LEGACY_AUTHORITY: target-scoped symmetrized payload does not use local-source rotation replay",
                ),
            )
            payload.sealed_completed_frame_corrections === nothing || throw(
                ArgumentError(
                    "PAW_GAUGE_ARTIFACT_TAMPERED: local-source replay payload contains obsolete sealed-frame corrections",
                ),
            )
            write(buffer, "LOCAL_NATIVE_SOURCE_PLUS_COMPLETED_ROTATION\n")
        else
            payload.sealed_completed_frame_corrections === nothing || throw(
                ArgumentError(
                    "PAW_GAUGE_ARTIFACT_TAMPERED: sealed-frame corrections appear outside target-scoped symmetrized authority",
                ),
            )
            write(buffer, "NO_SEALED_COMPLETED_FRAME_CORRECTIONS\n")
        end
    end
    write(buffer, _star_metric_sha256(payload.metric), '\n')
    return bytes2hex(SHA.sha256(take!(buffer)))
end

"""Return the canonical persisted metadata for a fixed-gap block policy."""
function _star_block_partition_policy_metadata(policy::FixedGapPAWBlockPartition)
    return Dict(
        "block_partition_policy" => paw_block_partition_policy_key(policy),
        "block_partition_max_gap_ev" => repr(policy.max_gap_ev),
    )
end

"""Return the canonical persisted metadata for an adaptive-evidence block policy."""
function _star_block_partition_policy_metadata(policy::AdaptiveEvidencePAWBlockPartition)
    return Dict(
        "block_partition_policy" => paw_block_partition_policy_key(policy),
        "block_partition_soft_gap_ev" => repr(policy.soft_gap_ev),
        "block_partition_hard_edge_gap_ev" => repr(policy.hard_edge_gap_ev),
        "block_partition_hard_component_span_ev" => repr(policy.hard_component_span_ev),
        "block_partition_max_component_bands" => string(policy.max_component_bands),
        "block_partition_max_search_states" => string(policy.max_search_states),
    )
end

"""Return canonical metadata for a Hamiltonian-weighted far-band policy."""
function _star_block_partition_policy_metadata(policy::HamiltonianWeightedPAWBlockPartition)
    residuals = policy.residual_thresholds
    cancellation = policy.cancellation_thresholds
    return Dict(
        "block_partition_policy" => paw_block_partition_policy_key(policy),
        "block_partition_near_gap_ev" => repr(policy.near_gap_ev),
        "block_partition_hard_component_span_ev" => repr(policy.hard_component_span_ev),
        "block_partition_max_component_bands" => string(policy.max_component_bands),
        "far_pair_hamiltonian_residual_ev" => repr(residuals.pair_ev),
        "far_operator_hamiltonian_residual_ev" => repr(residuals.operator_ev),
        "far_source_column_l2_hamiltonian_residual_ev" => repr(residuals.source_column_l2_ev),
        "far_normalized_frobenius_hamiltonian_residual_ev" =>
            repr(residuals.normalized_frobenius_ev),
        "cancellation_accumulation_absolute" => repr(cancellation.accumulation_absolute),
        "cancellation_inverse_absolute" => repr(cancellation.inverse_absolute),
        "cancellation_orbit_absolute" => repr(cancellation.orbit_absolute),
        "cancellation_bigfloat_precision_bits" => string(cancellation.bigfloat_precision_bits),
        "pre_gauge_far_cumulative_mode" => string(policy.pre_gauge_cumulative_mode),
        "post_gauge_hamiltonian_covariance_policy" => "unmasked_strict",
    )
end

"""Hash canonical block-policy metadata for artifact identity binding."""
function _star_block_partition_policy_sha256(metadata::AbstractDict)
    buffer = IOBuffer()
    for (key, value) in sort!(collect(metadata); by = first)
        write(buffer, string(key), '=', string(value), '\n')
    end
    return bytes2hex(SHA.sha256(take!(buffer)))
end

"""Return canonical metadata for an unchanged native discrete Hamiltonian."""
function _star_hamiltonian_correction_metadata(::NoDiscreteHamiltonianCorrection)
    return Dict(
        "discrete_hamiltonian_correction" => "none",
        "controlled_symmetrization_qualification_mode" => "not_applicable",
    )
end

"""Return canonical metadata for controlled far-band covariance restoration."""
function _star_hamiltonian_correction_metadata(correction::FarBandCovarianceCorrection)
    thresholds = correction.thresholds
    return Dict(
        "discrete_hamiltonian_correction" => discrete_hamiltonian_correction_key(correction),
        "controlled_symmetrization_method" => "full_parent_reynolds_plus_far_block_sylvester_plus_near_block_rediagonalization",
        "controlled_symmetrization_sewing_mutation" => "forbidden",
        "controlled_symmetrization_qualification_mode" => string(correction.qualification_mode),
        "controlled_symmetrization_far_rotation_operator_threshold" =>
            repr(thresholds.far_rotation_operator),
        "controlled_symmetrization_far_rotation_normalized_frobenius_threshold" =>
            repr(thresholds.far_rotation_normalized_frobenius),
        "controlled_symmetrization_hamiltonian_correction_operator_ev_threshold" =>
            repr(thresholds.hamiltonian_correction_operator_ev),
        "controlled_symmetrization_hamiltonian_correction_normalized_frobenius_ev_threshold" =>
            repr(thresholds.hamiltonian_correction_normalized_frobenius_ev),
    )
end

"""Hash the controlled-Hamiltonian correction contract for cross-artifact binding."""
_star_hamiltonian_correction_sha256(correction::AbstractDiscreteHamiltonianCorrection) =
    _star_block_partition_policy_sha256(_star_hamiltonian_correction_metadata(correction))

"""Return canonical metadata for one authoritative-Hamiltonian selection."""
function _star_authoritative_hamiltonian_metadata(authority::AbstractAuthoritativeHamiltonian)
    key = authoritative_hamiltonian_key(authority)
    return Dict(
        "authoritative_hamiltonian" => key,
        "native_fidelity_scope" => "independent_audit",
        "global_production_eligible" => "false",
        "symmetrized_hamiltonian_is_pure_gauge" => "false",
    )
end

"""Return the digest-bound contract for target-scoped symmetrized DFT authority."""
function _star_authoritative_hamiltonian_metadata(authority::SymmetrizedDFTHamiltonian)
    completion = authority.completion
    return Dict(
        "authoritative_hamiltonian" => authoritative_hamiltonian_key(authority),
        "qualification_scope" => string(authority.qualification_scope),
        "target_anchor" => string(authority.target_anchor),
        "target_complement_completion" => "frozen_target_orthogonal_complement",
        "target_complement_max_element_ev" => repr(completion.target_complement_max_element_ev),
        "auxiliary_parent_qualification" => string(authority.auxiliary_parent_qualification),
        "native_difference_qualification" => string(authority.native_difference_qualification),
        "energy_shift_qualification" => "audit_only",
        "maximum_energy_shift_audit_reference_ev" =>
            repr(authority.maximum_energy_shift_audit_reference_ev),
        "rms_energy_shift_audit_reference_ev" =>
            repr(authority.rms_energy_shift_audit_reference_ev),
        "residual_gate_phase" => string(authority.residual_gate_phase),
        "native_fidelity_scope" => "independent_audit",
        "global_production_eligible" => "false",
        "symmetrized_hamiltonian_is_pure_gauge" => "false",
        "target_zero_drift_contract" => "array_max_abs_zero_and_sha256_identity",
        "parent_completion_band_gauge" => "diag_identity_target_complement_unitary",
    )
end

"""Hash the authoritative-Hamiltonian contract for cross-artifact binding."""
_star_authoritative_hamiltonian_sha256(authority::AbstractAuthoritativeHamiltonian) =
    _star_block_partition_policy_sha256(_star_authoritative_hamiltonian_metadata(authority))

"""Return the digest payload for one target-subspace qualification contract."""
function _star_target_subspace_contract_metadata(contract::TargetSubspaceQualificationContract)
    metadata = Dict(
        "target_authority" => string(contract.authority),
        "parent_audit_policy" => string(contract.parent_audit_policy),
        "outer_min_ev" => repr(contract.outer_min_ev),
        "outer_max_ev" => repr(contract.outer_max_ev),
        "frozen_min_ev" => repr(contract.frozen_min_ev),
        "frozen_max_ev" => repr(contract.frozen_max_ev),
        "num_wannier" => string(contract.num_wannier),
        "outer_mask_sha256" => contract.qualification_scope.outer_mask_sha256,
        "frozen_mask_sha256" => contract.qualification_scope.frozen_mask_sha256,
        "target_anchor_maximum_drift_ev" => repr(contract.target_anchor_maximum_drift_ev),
        "target_complement_maximum_element_ev" =>
            repr(contract.target_complement_maximum_element_ev),
        "target_leakage_semantics" => TARGET_LEAKAGE_WEIGHT_SEMANTICS,
        "target_leakage_formula_sha256" => TARGET_LEAKAGE_WEIGHT_FORMULA_SHA256,
        "target_leakage_threshold" =>
            repr(contract.scoped_paw_thresholds.target_leakage_weight),
    )
    for field in fieldnames(PAWGaugeThresholds)
        metadata["scoped_paw_$(field)"] = repr(getfield(contract.scoped_paw_thresholds, field))
    end
    return metadata
end

"""Read one positive finite scoped PAW threshold from digest-bound metadata."""
function _star_scoped_paw_threshold(source_metadata::Dict{String, String}, field::Symbol)
    field in fieldnames(PAWGaugeThresholds) ||
        throw(ArgumentError("unsupported scoped PAW threshold field $(field)"))
    key = "scoped_paw_$(field)"
    haskey(source_metadata, key) ||
        throw(ArgumentError("PAW_GAUGE_ARTIFACT_TAMPERED: target contract omits $(key)"))
    value = tryparse(Float64, source_metadata[key])
    value !== nothing && isfinite(something(value)) && something(value) > 0.0 ||
        throw(ArgumentError("PAW_GAUGE_ARTIFACT_TAMPERED: target contract has invalid $(key)"))
    return something(value)
end

"""Hash the target-subspace qualification contract for artifact binding."""
_star_target_subspace_contract_sha256(contract::TargetSubspaceQualificationContract) =
    contract.contract_sha256

# Persist the complete parsed QE UPF/projector plan used by the gauge stage.
function _star_write_metric(parent, metric::_QEStrictSewingMetric)
    attributes = HDF5.attributes(parent)
    attributes["kind"] = "qe_upf_beta_q0"
    attributes["spinorbit"] = metric.spinorbit
    attributes["metric_kind"] = metric.metric_kind
    attributes["metric_sha256"] = _star_metric_sha256(metric)
    upf_group = HDF5.create_group(parent, "upf")
    for (ordinal, label) in enumerate(sort!(collect(keys(metric.upf_data))))
        dataset = metric.upf_data[label]
        group = HDF5.create_group(upf_group, @sprintf("type_%06d", ordinal))
        group_attributes = HDF5.attributes(group)
        group_attributes["label"] = label
        group_attributes["filename"] = basename(dataset.filename)
        group_attributes["element"] = dataset.element
        group_attributes["metric_kind"] = String(dataset.metric_kind)
        group_attributes["has_so"] = dataset.has_so
        group_attributes["fully_relativistic"] = dataset.fully_relativistic
        group_attributes["beta_integration_cutoff_index"] = dataset.beta_integration_cutoff_index
        group_attributes["q_with_l"] = dataset.q_with_l
        group_attributes["nqlc"] = dataset.nqlc
        group_attributes["augmentation_cutoff_index"] = dataset.augmentation_cutoff_index
        group_attributes["augmentation_cutoff_radius_bohr"] =
            dataset.augmentation_cutoff_radius_bohr
        group["radial_grid_bohr"] = dataset.radial_grid_bohr
        group["radial_weights_bohr"] = dataset.radial_weights_bohr
        group["beta_radial"] = dataset.beta_radial
        group["beta_angular_momenta"] = dataset.beta_angular_momenta
        group["beta_total_angular_momenta"] = dataset.beta_total_angular_momenta
        group["dij"] = dataset.dij
        group["q_integrals"] = dataset.q_integrals
        group["qfcoef"] = dataset.qfcoef
        group["rinner_bohr"] = dataset.rinner_bohr
        radial_group = HDF5.create_group(group, "q_radial_by_multipole")
        for key in sort!(collect(keys(dataset.q_radial_by_multipole)))
            radial_group[join(key, "_")] = dataset.q_radial_by_multipole[key]
        end
    end
    plan_group = HDF5.create_group(parent, "projector_plan")
    HDF5.attributes(plan_group)["num_channels"] = metric.plan.num_channels
    HDF5.attributes(plan_group)["has_augmentation"] = metric.plan.has_augmentation
    HDF5.attributes(plan_group)["fully_relativistic"] = metric.plan.fully_relativistic
    for (atom_index, atom) in enumerate(metric.plan.atoms)
        group = HDF5.create_group(plan_group, @sprintf("atom_%06d", atom_index))
        atom_attributes = HDF5.attributes(group)
        atom_attributes["atomic_type_label"] = atom.atomic_type_label
        atom_attributes["element"] = atom.element
        atom_attributes["channel_start"] = first(atom.channel_range)
        atom_attributes["channel_stop"] = last(atom.channel_range)
        group["position_fractional"] = collect(atom.position_fractional)
        channels = zeros(Int, 3, length(atom.channels))
        for (column, channel) in enumerate(atom.channels)
            channels[:, column] .=
                (channel.radial_index, channel.angular_momentum, channel.harmonic_row)
        end
        group["channels"] = channels
    end
    return nothing
end

# Persist the VASP q=0 metric and every target-k projector basis required for
# self-contained strict-sewing readback.
function _star_write_metric(parent, metric::_VASPStrictSewingMetric)
    attributes = HDF5.attributes(parent)
    attributes["kind"] = "vasp_potcar_projector_q0"
    attributes["metric_sha256"] = _star_metric_sha256(metric)
    attributes["num_channels"] = metric.paw.num_channels
    attributes["cell_volume_angstrom3"] = metric.paw.cell_volume_angstrom3
    parent["q0_augmentation"] = metric.paw.q0_augmentation
    basis_group = HDF5.create_group(parent, "projector_bases")
    for (kpoint, basis) in enumerate(metric.projector_bases)
        basis_group[@sprintf("kpoint_%06d", kpoint)] = basis
    end
    return nothing
end

# Reconstruct the minimal VASP q=0 contract consumed by strict band sewing.
function _star_read_vasp_metric(parent, native::NativeWavefunctionData)
    attributes = HDF5.attributes(parent)
    num_channels = Int(read(attributes["num_channels"]))
    q0 = Float64.(read(parent["q0_augmentation"]))
    size(q0) == (num_channels, num_channels) ||
        throw(ArgumentError("PAW_GAUGE_ARTIFACT_TAMPERED: VASP Q0 dimensions differ"))
    basis_group = parent["projector_bases"]
    names = sort!(String.(collect(keys(basis_group))))
    length(names) == length(native.kpoints) ||
        throw(ArgumentError("PAW_GAUGE_ARTIFACT_TAMPERED: VASP basis count differs"))
    bases = [ComplexF64.(read(basis_group[name])) for name in names]
    projectors = Array{ComplexF64, 3}[]
    for (kpoint, point) in enumerate(native.kpoints)
        basis = bases[kpoint]
        size(basis) == (num_channels, size(point.coefficients, 2)) || throw(
            ArgumentError("PAW_GAUGE_ARTIFACT_TAMPERED: VASP projector basis dimensions differ"),
        )
        values = zeros(
            ComplexF64,
            size(point.coefficients, 1),
            num_channels,
            size(point.coefficients, 3),
        )
        for spin in axes(point.coefficients, 3)
            values[:, :, spin] .= @view(point.coefficients[:, :, spin]) * transpose(basis)
        end
        push!(projectors, values)
    end
    paw = VASPPawSystem(
        Dict{String, VASPPawDataset}(),
        String[],
        VASPPawAtomLayout[],
        num_channels,
        q0,
        Float64(read(attributes["cell_volume_angstrom3"])),
    )
    metric = _VASPStrictSewingMetric(paw, projectors, bases)
    String(read(attributes["metric_sha256"])) == _star_metric_sha256(metric) ||
        throw(ArgumentError("PAW_GAUGE_ARTIFACT_TAMPERED: VASP metric digest differs"))
    return metric
end

# Reconstruct a parsed QE UPF/projector plan from the self-contained artifact.
function _star_read_qe_metric(parent, native::NativeWavefunctionData)
    upf_data = Dict{String, QEUPFData}()
    for name in sort!(String.(collect(keys(parent["upf"]))))
        group = parent["upf"][name]
        attributes = HDF5.attributes(group)
        radial = Dict{NTuple{3, Int}, Vector{Float64}}()
        for radial_name in keys(group["q_radial_by_multipole"])
            key_values = parse.(Int, split(String(radial_name), '_'))
            length(key_values) == 3 || throw(ArgumentError("PAW_GAUGE_ARTIFACT_TAMPERED"))
            radial[Tuple(key_values)] = Float64.(read(group["q_radial_by_multipole"][radial_name]))
        end
        label = String(read(attributes["label"]))
        upf_data[label] = QEUPFData(
            String(read(attributes["filename"])),
            String(read(attributes["element"])),
            Symbol(String(read(attributes["metric_kind"]))),
            Bool(read(attributes["has_so"])),
            Bool(read(attributes["fully_relativistic"])),
            Float64.(read(group["radial_grid_bohr"])),
            Float64.(read(group["radial_weights_bohr"])),
            Float64.(read(group["beta_radial"])),
            Int.(read(group["beta_angular_momenta"])),
            Int(read(attributes["beta_integration_cutoff_index"])),
            Float64.(read(group["beta_total_angular_momenta"])),
            Float64.(read(group["dij"])),
            Float64.(read(group["q_integrals"])),
            Bool(read(attributes["q_with_l"])),
            radial,
            Float64.(read(group["qfcoef"])),
            Float64.(read(group["rinner_bohr"])),
            Int(read(attributes["nqlc"])),
            Int(read(attributes["augmentation_cutoff_index"])),
            Float64(read(attributes["augmentation_cutoff_radius_bohr"])),
        )
    end
    plan_group = parent["projector_plan"]
    atoms = QEProjectorAtomPlan[]
    atom_names =
        sort!(filter(name -> startswith(name, "atom_"), String.(collect(keys(plan_group)))))
    for name in atom_names
        group = plan_group[name]
        attributes = HDF5.attributes(group)
        channel_values = Int.(read(group["channels"]))
        channels = [
            QEProjectorChannel(
                channel_values[1, column],
                channel_values[2, column],
                channel_values[3, column],
            ) for column in axes(channel_values, 2)
        ]
        position = Tuple(Float64.(read(group["position_fractional"])))
        push!(
            atoms,
            QEProjectorAtomPlan(
                String(read(attributes["atomic_type_label"])),
                String(read(attributes["element"])),
                position,
                channels,
                Int(read(attributes["channel_start"])):Int(read(attributes["channel_stop"])),
            ),
        )
    end
    plan = QEProjectorPlan(
        atoms,
        Int(read(HDF5.attributes(plan_group)["num_channels"])),
        Bool(read(HDF5.attributes(plan_group)["has_augmentation"])),
        Bool(read(HDF5.attributes(plan_group)["fully_relativistic"])),
    )
    projectors, bases = _qe_beta_overlaps(native, upf_data, plan)
    metric = _QEStrictSewingMetric(
        upf_data,
        plan,
        projectors,
        bases,
        Bool(read(HDF5.attributes(parent)["spinorbit"])),
        Dict{Tuple{String, NTuple{3, Float64}, Int, Bool}, Array{ComplexF64, 4}}(),
        String(read(HDF5.attributes(parent)["metric_kind"])),
    )
    String(read(HDF5.attributes(parent)["metric_sha256"])) == _star_metric_sha256(metric) ||
        throw(ArgumentError("PAW_GAUGE_ARTIFACT_TAMPERED: parsed PAW metric digest differs"))
    return metric
end

"""Atomically write one self-contained k-star gauge capsule."""
function _write_star_covariant_paw_gauge_hdf5(
    filename::AbstractString,
    payload::_StarCovariantPAWPayload;
    status::Symbol,
    root_cause::Symbol,
    diagnostics::Vector{String} = String[],
    schema_version::AbstractString = STAR_COVARIANT_PAW_GAUGE_SCHEMA_VERSION,
    contract_version::AbstractString = schema_version == "1.0" ?
                                       STAR_COVARIANT_PAW_GAUGE_CURRENT_CONTRACT_VERSION :
                                       schema_version,
)
    _validate_star_wire_contract(schema_version, contract_version)
    HDF5.enable_complex_support()
    schema_version in STAR_COVARIANT_PAW_GAUGE_SUPPORTED_SCHEMA_VERSIONS ||
        throw(ArgumentError("unsupported wavefunction-gauge HDF5 schema version"))
    if !haskey(payload.source_metadata, "block_partition_policy")
        metadata = _star_block_partition_policy_metadata(FixedGapPAWBlockPartition())
        merge!(payload.source_metadata, metadata)
        payload.input_sha256["BLOCK_PARTITION_POLICY_SHA256"] =
            _star_block_partition_policy_sha256(metadata)
    end
    if !haskey(payload.source_metadata, "discrete_hamiltonian_correction")
        correction = NoDiscreteHamiltonianCorrection()
        merge!(payload.source_metadata, _star_hamiltonian_correction_metadata(correction))
        payload.input_sha256["DISCRETE_HAMILTONIAN_CORRECTION_SHA256"] =
            _star_hamiltonian_correction_sha256(correction)
    end
    if !haskey(payload.source_metadata, "authoritative_hamiltonian")
        authority = NativeDFTHamiltonian()
        merge!(payload.source_metadata, _star_authoritative_hamiltonian_metadata(authority))
        payload.input_sha256["AUTHORITATIVE_HAMILTONIAN_SHA256"] =
            _star_authoritative_hamiltonian_sha256(authority)
    end
    band_frame_attribute_keys =
        contract_version == "1.11" ?
        (
            "band_frame_contract_schema",
            "band_frame_contract_schema_version",
            "band_frame_contract_status",
            "band_frame_source_gauge",
            "band_frame_target_gauge",
            "band_frame_transform_sha256",
            "band_frame_contract_sha256",
            "band_frame_metric_kind",
            "band_frame_physical_isometry_maximum",
            "band_frame_physical_isometry_tolerance",
            "band_frame_replay_maximum",
            "band_frame_replay_tolerance",
            "band_frame_euclidean_nonunitarity_maximum",
            "band_frame_minimum_singular_value",
            "band_frame_maximum_condition_number",
        ) : ()
    for key in band_frame_attribute_keys
        haskey(payload.source_metadata, key) ||
            throw(ArgumentError("BAND_FRAME_CONTRACT_REQUIRED: current payload omits $(key)"))
    end
    if contract_version == "1.11"
        get(payload.input_sha256, "BAND_FRAME_TRANSFORM_SHA256", "") ==
        payload.source_metadata["band_frame_transform_sha256"] ||
            throw(ArgumentError("BAND_FRAME_TRANSFORM_DIGEST_MISMATCH"))
        get(payload.input_sha256, "BAND_FRAME_CONTRACT_SHA256", "") ==
        payload.source_metadata["band_frame_contract_sha256"] ||
            throw(ArgumentError("BAND_FRAME_CONTRACT_DIGEST_MISMATCH"))
    end
    logical_digest = _star_payload_sha256(payload; schema_version, contract_version)
    return atomic_hdf5_write(filename) do temporary
        HDF5.h5open(temporary, "w") do handle
            attributes = HDF5.attributes(handle)
            attributes["schema"] = STAR_COVARIANT_PAW_GAUGE_SCHEMA
            attributes["schema_version"] = schema_version
            attributes["status"] = String(status)
            attributes["root_cause"] = String(root_cause)
            attributes["production_eligible"] = status == :PASS
            attributes["diagnostic_only"] = status == :DIAGNOSTIC_ONLY
            attributes["scoped_production_eligible"] = status == :PASS
            attributes["global_production_eligible"] = false
            attributes["wavefunction_gauge_backend"] = "star_covariant_paw"
            attributes["sewing_backend"] = "augmentation_aware_paw_q0"
            attributes["payload_sha256"] = logical_digest
            attributes["target_band_start"] = first(payload.target_band_range)
            attributes["target_band_stop"] = last(payload.target_band_range)
            attributes["parent_band_start"] = first(payload.parent_band_range)
            attributes["parent_band_stop"] = last(payload.parent_band_range)
            attributes["source_code"] = String(payload.native.source_code)
            attributes["spinor"] = payload.native.spinor
            attributes["coefficient_row_convention"] = "C_prime=transpose(U)*C"
            attributes["antiunitary_band_gauge_convention"] = "B_prime=U_gk_dagger*B*conj(U_k)"
            attributes["block_partition_policy"] =
                get(payload.source_metadata, "block_partition_policy", "fixed_gap")
            attributes["block_partition_policy_sha256"] = get(
                payload.input_sha256,
                "BLOCK_PARTITION_POLICY_SHA256",
                "LEGACY_SCHEMA_FIELD_ABSENT",
            )
            attributes["discrete_hamiltonian_correction"] =
                get(payload.source_metadata, "discrete_hamiltonian_correction", "none")
            attributes["discrete_hamiltonian_correction_sha256"] = get(
                payload.input_sha256,
                "DISCRETE_HAMILTONIAN_CORRECTION_SHA256",
                "LEGACY_SCHEMA_FIELD_ABSENT",
            )
            attributes["controlled_symmetrization_qualification_mode"] = get(
                payload.source_metadata,
                "controlled_symmetrization_qualification_mode",
                "not_applicable",
            )
            authority = get(payload.source_metadata, "authoritative_hamiltonian", "native_dft")
            attributes["authoritative_hamiltonian"] = authority
            attributes["authoritative_hamiltonian_sha256"] = get(
                payload.input_sha256,
                "AUTHORITATIVE_HAMILTONIAN_SHA256",
                "LEGACY_SCHEMA_FIELD_ABSENT",
            )
            attributes["energy_shift_qualification"] = get(
                payload.source_metadata,
                "energy_shift_qualification",
                "legacy_energy_shift_hard_gate",
            )
            attributes["maximum_energy_shift_audit_reference_ev"] = get(
                payload.source_metadata,
                "maximum_energy_shift_audit_reference_ev",
                "NOT_APPLICABLE",
            )
            attributes["rms_energy_shift_audit_reference_ev"] = get(
                payload.source_metadata,
                "rms_energy_shift_audit_reference_ev",
                "NOT_APPLICABLE",
            )
            attributes["target_energy_shift_audit_status"] =
                get(payload.source_metadata, "target_energy_shift_audit_status", "NOT_APPLICABLE")
            attributes["symmetrized_parent_energy_shift_audit_status"] = get(
                payload.source_metadata,
                "symmetrized_parent_energy_shift_audit_status",
                "NOT_APPLICABLE",
            )
            attributes["residual_gate_phase"] =
                get(payload.source_metadata, "residual_gate_phase", "legacy_pre_symmetrization")
            attributes["raw_preflight_diagnostic_status"] =
                get(payload.source_metadata, "raw_preflight_diagnostic_status", "NOT_APPLICABLE")
            attributes["native_difference_qualification"] =
                get(payload.source_metadata, "native_difference_qualification", "legacy_hard_gate")
            attributes["native_difference_audit_status"] =
                get(payload.source_metadata, "native_difference_audit_status", "NOT_APPLICABLE")
            for (key, default_value) in (
                ("qualification_scope", "full_parent"),
                ("target_anchor", "NOT_APPLICABLE"),
                ("target_complement_completion", "NOT_APPLICABLE"),
                ("target_complement_max_element_ev", "NOT_APPLICABLE"),
                ("auxiliary_parent_qualification", "legacy_hard_gate"),
            )
                attributes[key] = get(payload.source_metadata, key, default_value)
            end
            native_residual = get(
                payload.maxima,
                "native_fidelity_projected_eigen_residual_ev",
                get(payload.maxima, "projected_eigen_residual_ev", Inf),
            )
            attributes["native_fidelity_status"] =
                native_residual <= 5.0e-6 ? "NATIVE_DFT_FIDELITY_PASS" : "NATIVE_DFT_FIDELITY_HOLD"
            attributes["symmetrized_hamiltonian_status"] =
                authority == "symmetrized_dft_hamiltonian" && status == :PASS ?
                "SYMMETRIZED_DFT_HAMILTONIAN_PASS" : "NOT_SELECTED"
            attributes["symmetrized_target_subspace_status"] =
                authority == "symmetrized_dft_hamiltonian" && status == :PASS ?
                "SYMMETRIZED_DFT_HAMILTONIAN_PASS" : "NOT_SELECTED"
            attributes["auxiliary_parent_audit_status"] =
                get(payload.source_metadata, "auxiliary_parent_audit_status", "NOT_APPLICABLE")
            attributes["target_scope_production_eligible"] =
                payload.qualification_scope !== nothing && status == :PASS
            attributes["target_subspace_contract_sha256"] =
                get(payload.input_sha256, "TARGET_SUBSPACE_CONTRACT_SHA256", "NOT_APPLICABLE")
            attributes["target_leakage_semantics"] =
                get(payload.source_metadata, "target_leakage_semantics", "NOT_APPLICABLE")
            attributes["target_leakage_formula_sha256"] =
                get(payload.source_metadata, "target_leakage_formula_sha256", "NOT_APPLICABLE")
            attributes["target_leakage_threshold"] =
                get(payload.source_metadata, "target_leakage_threshold", "NOT_APPLICABLE")
            for key in band_frame_attribute_keys
                attributes[key] = payload.source_metadata[key]
            end

            if payload.qualification_scope !== nothing
                scope = something(payload.qualification_scope)
                scope_group = HDF5.create_group(handle, "qualification_scope")
                HDF5.attributes(scope_group)["authority"] =
                    get(payload.source_metadata, "target_authority", "outer_window")
                HDF5.attributes(scope_group)["parent_audit_policy"] =
                    get(payload.source_metadata, "parent_audit_policy", "audit_only")
                HDF5.attributes(scope_group)["outer_mask_sha256"] = scope.outer_mask_sha256
                HDF5.attributes(scope_group)["frozen_mask_sha256"] = scope.frozen_mask_sha256
                scope_group["outer_mask"] = UInt8.(scope.outer_mask)
                scope_group["frozen_mask"] = UInt8.(scope.frozen_mask)
            end

            structure = HDF5.create_group(handle, "structure")
            structure["real_lattice"] = payload.native.structure.lattice
            structure["reciprocal_lattice"] = payload.native.reciprocal_lattice
            structure["positions_fractional"] = payload.native.structure.positions_fractional
            structure["species"] = payload.native.structure.species
            structure["mp_grid"] = collect(payload.native.mp_grid)
            moments = payload.native.structure.magnetic_moments_cartesian
            HDF5.attributes(structure)["has_magnetic_moments"] = moments !== nothing
            moments === nothing || (structure["magnetic_moments_cartesian"] = moments)

            nk = length(payload.native.kpoints)
            kpoints = zeros(Float64, nk, 3)
            energies = zeros(Float64, size(first(payload.native.kpoints).coefficients, 1), nk)
            for (index, point) in enumerate(payload.native.kpoints)
                kpoints[index, :] .= point.k_fractional
                energies[:, index] .= point.energies_ev
            end
            handle["kpoints_fractional"] = kpoints
            handle["symmetry_completed_energies_ev"] = energies
            handle["kpoint_map"] = payload.kpoint_map
            handle["reciprocal_shifts"] = payload.reciprocal_shifts
            handle["representative_for_kpoint"] = payload.representative_for_kpoint
            handle["canonical_operation_for_kpoint"] = payload.canonical_operation_for_kpoint
            handle["star_representatives"] = payload.star_representatives
            handle["extra_bands_per_star"] = payload.extra_bands_per_star
            handle["native_to_completed_rotations"] = payload.rotations
            storage_mode = get(
                payload.source_metadata,
                "nonrepresentative_frame_storage",
                "representative_raw_symmetry_transform",
            )
            attributes["nonrepresentative_frame_storage"] = storage_mode
            if payload.sealed_completed_frame_corrections !== nothing
                handle["sealed_completed_frame_corrections"] =
                    something(payload.sealed_completed_frame_corrections)
            end
            audit = payload.symmetrized_hamiltonian_audit
            HDF5.attributes(handle)["has_symmetrized_hamiltonian_audit"] = audit !== nothing
            if audit !== nothing
                group = HDF5.create_group(handle, "symmetrized_hamiltonian_audit")
                group["native_parent_energies_ev"] = audit.native_energies_ev
                group["symmetrized_parent_energies_ev"] = audit.symmetrized_energies_ev
                group["native_to_symmetrized_parent_rotations"] =
                    audit.native_to_symmetrized_rotations
                group["representative_native_hamiltonians_ev"] =
                    audit.representative_native_hamiltonians_ev
                group["representative_symmetrized_hamiltonians_ev"] =
                    audit.representative_symmetrized_hamiltonians_ev
                group["representative_raw_transports"] = audit.representative_raw_transports
                group["target_principal_angles_rad"] = audit.target_principal_angles_rad
                group["target_projector_difference_operator"] =
                    audit.target_projector_difference_operator
                group["target_projector_difference_frobenius"] =
                    audit.target_projector_difference_frobenius
                group["native_to_symmetrized_band_assignment"] =
                    audit.native_to_symmetrized_band_assignment
                group["target_energy_shifts_by_star_ev"] = audit.target_energy_shifts_by_star_ev
                group["parent_energy_shifts_by_kpoint_ev"] = audit.parent_energy_shifts_by_kpoint_ev
                if audit.target_anchor_sha256_by_star !== nothing
                    group["target_anchor_sha256_by_star"] =
                        something(audit.target_anchor_sha256_by_star)
                    group["complement_bases"] = something(audit.complement_bases)
                    group["complement_rotations"] = something(audit.complement_rotations)
                    group["target_complement_hamiltonians_ev"] =
                        something(audit.target_complement_hamiltonians_ev)
                    group["complement_hamiltonians_ev"] =
                        something(audit.complement_hamiltonians_ev)
                end
            end

            operation_group = HDF5.create_group(handle, "operations")
            operation_count = length(payload.operations)
            fractional_rotations = zeros(Int, 3, 3, operation_count)
            cartesian_rotations = zeros(Float64, 3, 3, operation_count)
            translations = zeros(Float64, 3, operation_count)
            antiunitary = zeros(UInt8, operation_count)
            keys = String[]
            for (index, operation) in enumerate(payload.operations)
                fractional_rotations[:, :, index] .= operation.rotation_fractional
                cartesian_rotations[:, :, index] .= operation.rotation_cartesian
                translations[:, index] .= operation.translation_fractional
                antiunitary[index] = operation.antiunitary
                push!(keys, canonical_band_operation_key(operation))
            end
            operation_group["rotation_fractional"] = fractional_rotations
            operation_group["rotation_cartesian"] = cartesian_rotations
            operation_group["translation_fractional"] = translations
            operation_group["antiunitary"] = antiunitary
            operation_group["canonical_keys"] = keys

            representative_group = HDF5.create_group(handle, "representative_frames")
            for representative in payload.star_representatives
                point = payload.native.kpoints[representative]
                group =
                    HDF5.create_group(representative_group, @sprintf("kpoint_%06d", representative))
                HDF5.attributes(group)["full_kpoint_index"] = representative
                group["k_fractional"] = point.k_fractional
                group["g_vectors"] = point.g_vectors
                group["coefficients"] = point.coefficients
                group["energies_ev"] = point.energies_ev
            end
            gvector_group = HDF5.create_group(handle, "g_vectors_by_kpoint")
            for (kpoint, point) in enumerate(payload.native.kpoints)
                gvector_group[@sprintf("kpoint_%06d", kpoint)] = point.g_vectors
            end

            hashes = HDF5.create_group(handle, "input_sha256")
            write_string_dictionary(hashes, payload.input_sha256)
            metadata = HDF5.create_group(handle, "source_metadata")
            write_string_dictionary(metadata, payload.source_metadata)
            maxima = HDF5.create_group(handle, "preflight_maxima")
            for (key, value) in sort!(collect(payload.maxima); by = first)
                HDF5.attributes(maxima)[key] = value
            end
            contexts = HDF5.create_group(handle, "maximum_contexts")
            write_string_dictionary(contexts, payload.maximum_contexts)
            metric_group = HDF5.create_group(handle, "parsed_paw_metric")
            _star_write_metric(metric_group, payload.metric)
            handle["diagnostics"] = diagnostics
        end
    end
end

"""
Read the public 1.0 full-contract capsule or a historical 1.0--1.11 capsule.

Existing band-frame markers select the complete 1.11 field/replay contract before
validation; the literal wire version remains part of the payload digest.

Contract-1.11 frames and target-scoped symmetrized frames are replayed from the
exact local native source and digest-bound per-k rotations. Earlier native
contracts regenerate nonrepresentative wavefunctions by stored magnetic
transport. Physical replay is checked against the sealed representative frames;
the logical digest uses the producer's sealed bytes after that check passes.
"""
function _read_star_covariant_paw_gauge_hdf5(
    filename::AbstractString;
    require_pass::Bool = true,
    construction_policy::Union{Nothing, Symbol} = nothing,
    source::Union{Nothing, AbstractWavefunctionSource} = nothing,
)
    construction_policy === nothing ||
        construction_policy in (:strict, :diagnostic) ||
        throw(ArgumentError("construction_policy must be :strict or :diagnostic"))
    effective_require_pass =
        construction_policy === nothing ? require_pass : construction_policy == :strict
    HDF5.enable_complex_support()
    return HDF5.h5open(filename, "r") do handle
        attributes = HDF5.attributes(handle)
        String(read(attributes["schema"])) == STAR_COVARIANT_PAW_GAUGE_SCHEMA ||
            throw(ArgumentError("unsupported wavefunction-gauge HDF5 schema"))
        schema_version = String(read(attributes["schema_version"]))
        schema_version in STAR_COVARIANT_PAW_GAUGE_SUPPORTED_SCHEMA_VERSIONS ||
            throw(ArgumentError("unsupported wavefunction-gauge HDF5 schema version"))
        status = Symbol(String(read(attributes["status"])))
        construction_policy == :diagnostic &&
            !(status in (:PASS, :DIAGNOSTIC_ONLY)) &&
            throw(
                ArgumentError(
                    "PAW_SEWING_HOLD: gauge artifact has no usable completed state; status=$(status)",
                ),
            )
        effective_require_pass &&
            status != :PASS &&
            throw(ArgumentError("PAW_SEWING_HOLD: gauge artifact status is $(status)"))
        String(read(attributes["wavefunction_gauge_backend"])) == "star_covariant_paw" ||
            throw(ArgumentError("WAVEFUNCTION_GAUGE_BACKEND_MISMATCH"))
        String(read(attributes["sewing_backend"])) == "augmentation_aware_paw_q0" ||
            throw(ArgumentError("SEWING_BACKEND_MISMATCH"))

        structure_group = handle["structure"]
        moments =
            Bool(read(HDF5.attributes(structure_group)["has_magnetic_moments"])) ?
            Float64.(read(structure_group["magnetic_moments_cartesian"])) : nothing
        structure = CrystalStructure(
            Float64.(read(structure_group["real_lattice"])),
            String.(read(structure_group["species"])),
            Float64.(read(structure_group["positions_fractional"]));
            magnetic_moments_cartesian = moments,
        )
        reciprocal_lattice = Float64.(read(structure_group["reciprocal_lattice"]))
        mp_values = Int.(read(structure_group["mp_grid"]))
        mp_grid = (mp_values[1], mp_values[2], mp_values[3])
        kpoints = Float64.(read(handle["kpoints_fractional"]))
        energies = Float64.(read(handle["symmetry_completed_energies_ev"]))
        kpoint_map = Int.(read(handle["kpoint_map"]))
        reciprocal_shifts = Int.(read(handle["reciprocal_shifts"]))
        representative_for_kpoint = Int.(read(handle["representative_for_kpoint"]))
        canonical_operation_for_kpoint = Int.(read(handle["canonical_operation_for_kpoint"]))
        star_representatives = Int.(read(handle["star_representatives"]))
        extra_bands_per_star = Int.(read(handle["extra_bands_per_star"]))
        rotations = ComplexF64.(read(handle["native_to_completed_rotations"]))
        input_sha256 = read_string_dictionary(handle["input_sha256"])
        source_metadata = read_string_dictionary(handle["source_metadata"])
        contract_version =
            _star_gauge_contract_version(schema_version, attributes, source_metadata, input_sha256)
        metadata_authority = get(source_metadata, "authoritative_hamiltonian", "native_dft")
        metadata_scope = get(source_metadata, "qualification_scope", "parent_full_audit")
        if contract_version == "1.9" && metadata_scope == "target_subspace"
            throw(
                ArgumentError(
                    "UNSUPPORTED_LEGACY_TARGET_LEAKAGE_SEMANTICS: schema-1.9 target artifact uses amplitude leakage gates",
                ),
            )
        end
        target_scope_active =
            contract_version in ("1.10", "1.11") && metadata_scope == "target_subspace"
        if target_scope_active
            haskey(attributes, "authoritative_hamiltonian") &&
            String(read(attributes["authoritative_hamiltonian"])) == metadata_authority || throw(
                ArgumentError(
                    "PAW_GAUGE_ARTIFACT_TAMPERED: root Hamiltonian authority differs from digest-bound metadata",
                ),
            )
            haskey(attributes, "qualification_scope") &&
            String(read(attributes["qualification_scope"])) == metadata_scope || throw(
                ArgumentError(
                    "PAW_GAUGE_ARTIFACT_TAMPERED: root qualification scope differs from digest-bound metadata",
                ),
            )
        end
        target_scoped_symmetrized =
            target_scope_active && metadata_authority == "symmetrized_dft_hamiltonian"
        if target_scoped_symmetrized
            haskey(attributes, "nonrepresentative_frame_storage") &&
            String(read(attributes["nonrepresentative_frame_storage"])) ==
            "local_native_source_plus_completed_rotation" || throw(
                ArgumentError(
                    "UNSUPPORTED_LEGACY_AUTHORITY: target-scoped symmetrized artifact does not use local-source rotation replay",
                ),
            )
            get(source_metadata, "nonrepresentative_frame_storage", "") ==
            "local_native_source_plus_completed_rotation" || throw(
                ArgumentError(
                    "PAW_GAUGE_ARTIFACT_TAMPERED: frame storage attribute differs from digest-bound metadata",
                ),
            )
            haskey(handle, "sealed_completed_frame_corrections") && throw(
                ArgumentError(
                    "PAW_GAUGE_ARTIFACT_TAMPERED: local-source replay artifact contains obsolete sealed-frame corrections",
                ),
            )
        else
            haskey(handle, "sealed_completed_frame_corrections") && throw(
                ArgumentError(
                    "PAW_GAUGE_ARTIFACT_TAMPERED: sealed-frame corrections appear outside target-scoped symmetrized authority",
                ),
            )
        end
        sealed_frame_corrections = nothing
        has_symmetrized_audit =
            contract_version in ("1.4", "1.5", "1.6", "1.7", "1.8", "1.9", "1.10", "1.11") &&
            Bool(read(attributes["has_symmetrized_hamiltonian_audit"]))
        symmetrized_audit = if has_symmetrized_audit
            group = handle["symmetrized_hamiltonian_audit"]
            native_energies = Float64.(read(group["native_parent_energies_ev"]))
            symmetrized_energies = Float64.(read(group["symmetrized_parent_energies_ev"]))
            assignment = Int.(read(group["native_to_symmetrized_band_assignment"]))
            parent_shifts =
                if contract_version in ("1.5", "1.6", "1.7", "1.8", "1.9", "1.10", "1.11")
                    Float64.(read(group["parent_energy_shifts_by_kpoint_ev"]))
                else
                    [
                        symmetrized_energies[assignment[native_band, kpoint], kpoint] -
                        native_energies[native_band, kpoint] for
                        native_band in axes(native_energies, 1), kpoint in axes(native_energies, 2)
                    ]
                end
            target_shifts =
                contract_version in ("1.5", "1.6", "1.7", "1.8", "1.9", "1.10", "1.11") ?
                Float64.(read(group["target_energy_shifts_by_star_ev"])) :
                zeros(
                    Float64,
                    length(
                        Int(
                            read(attributes["target_band_start"]),
                        ):Int(read(attributes["target_band_stop"])),
                    ),
                    length(Int.(read(handle["star_representatives"]))),
                )
            _SymmetrizedDFTHamiltonianAuditPayload(
                native_energies,
                symmetrized_energies,
                ComplexF64.(read(group["native_to_symmetrized_parent_rotations"])),
                ComplexF64.(read(group["representative_native_hamiltonians_ev"])),
                ComplexF64.(read(group["representative_symmetrized_hamiltonians_ev"])),
                ComplexF64.(read(group["representative_raw_transports"])),
                Float64.(read(group["target_principal_angles_rad"])),
                Float64.(read(group["target_projector_difference_operator"])),
                Float64.(read(group["target_projector_difference_frobenius"])),
                assignment,
                target_shifts,
                parent_shifts,
                contract_version in ("1.8", "1.9", "1.10", "1.11") &&
                    haskey(group, "target_anchor_sha256_by_star") ?
                String.(read(group["target_anchor_sha256_by_star"])) : nothing,
                contract_version in ("1.8", "1.9", "1.10", "1.11") &&
                    haskey(group, "complement_bases") ?
                ComplexF64.(read(group["complement_bases"])) : nothing,
                contract_version in ("1.8", "1.9", "1.10", "1.11") &&
                    haskey(group, "complement_rotations") ?
                ComplexF64.(read(group["complement_rotations"])) : nothing,
                contract_version in ("1.8", "1.9", "1.10", "1.11") &&
                    haskey(group, "target_complement_hamiltonians_ev") ?
                ComplexF64.(read(group["target_complement_hamiltonians_ev"])) : nothing,
                contract_version in ("1.8", "1.9", "1.10", "1.11") &&
                    haskey(group, "complement_hamiltonians_ev") ?
                ComplexF64.(read(group["complement_hamiltonians_ev"])) : nothing,
            )
        else
            nothing
        end

        operation_group = handle["operations"]
        fractional_rotations = Int.(read(operation_group["rotation_fractional"]))
        cartesian_rotations = Float64.(read(operation_group["rotation_cartesian"]))
        translations = Float64.(read(operation_group["translation_fractional"]))
        antiunitary = Bool.(read(operation_group["antiunitary"]))
        operations = [
            SymmetryOperation(
                fractional_rotations[:, :, index],
                translations[:, index],
                cartesian_rotations[:, :, index],
                antiunitary[index],
            ) for index in eachindex(antiunitary)
        ]
        recorded_keys = String.(read(operation_group["canonical_keys"]))
        recorded_keys == canonical_band_operation_key.(operations) ||
            throw(ArgumentError("PAW_GAUGE_ARTIFACT_TAMPERED: operation keys differ"))

        representative_points = Dict{Int, PlaneWaveKPoint}()
        for name in keys(handle["representative_frames"])
            group = handle["representative_frames"][name]
            index = Int(read(HDF5.attributes(group)["full_kpoint_index"]))
            representative_points[index] = PlaneWaveKPoint(
                Float64.(read(group["k_fractional"])),
                Int.(read(group["g_vectors"])),
                ComplexF64.(read(group["coefficients"])),
                Float64.(read(group["energies_ev"]));
                normalize_coefficients = false,
            )
        end
        sort!(collect(keys(representative_points))) == star_representatives ||
            throw(ArgumentError("PAW_GAUGE_ARTIFACT_TAMPERED: representative inventory differs"))
        replayed_metric = nothing
        replayed_raw_native = nothing
        replayed_raw_metric = nothing
        frame_replay_active = contract_version == "1.11"
        points = if target_scoped_symmetrized || frame_replay_active
            replay_source =
                source === nothing ? _star_source_from_replay_metadata(source_metadata) :
                something(source)
            target_band_range =
                Int(read(attributes["target_band_start"])):Int(read(attributes["target_band_stop"]))
            parent_band_range =
                Int(read(attributes["parent_band_start"])):Int(read(attributes["parent_band_stop"]))
            replay_source.band_range == target_band_range || throw(
                ArgumentError(
                    "WAVEFUNCTION_GAUGE_ARTIFACT_MISMATCH: source band range differs from artifact",
                ),
            )
            for (key, value) in _star_current_source_hashes(replay_source)
                get(input_sha256, key, "MISSING") == value || throw(
                    ArgumentError("INPUT_PROVENANCE_HOLD: source digest differs for $(key)"),
                )
            end
            parent_source = _star_source_with_band_range(replay_source, parent_band_range)
            raw_native = _read_augmentation_aware_native_source(parent_source)
            strict_hashes = _strict_input_hashes(parent_source, raw_native)
            for (key, value) in strict_hashes
                get(input_sha256, key, "MISSING") == value || throw(
                    ArgumentError("INPUT_PROVENANCE_HOLD: strict source digest differs for $(key)"),
                )
            end
            get(source_metadata, "source_replay_resource_manifest_sha256", "") ==
            _star_input_identity_sha256(strict_hashes) || throw(
                ArgumentError("INPUT_PROVENANCE_HOLD: source replay resource manifest differs"),
            )
            raw_native.spinor == Bool(read(attributes["spinor"])) || throw(
                ArgumentError("PAW_GAUGE_ARTIFACT_TAMPERED: source spinor identity differs"),
            )
            raw_native.mp_grid == mp_grid ||
                throw(ArgumentError("PAW_GAUGE_ARTIFACT_TAMPERED: source MP grid differs"))
            length(raw_native.kpoints) == size(kpoints, 1) ||
                throw(ArgumentError("PAW_GAUGE_ARTIFACT_TAMPERED: source k-count differs"))
            raw_metric, _, _ = _strict_sewing_metric(parent_source, raw_native)
            replayed_raw_native = raw_native
            replayed_raw_metric = raw_metric
            replay =
                _star_replay_local_completed_frame(raw_native, raw_metric, rotations, energies)
            replayed_metric = replay.metric
            threshold =
                frame_replay_active ?
                _band_frame_float(source_metadata, "band_frame_replay_tolerance") :
                _star_scoped_paw_threshold(source_metadata, :wfc_rotation_reconstruction)
            for kpoint in eachindex(replay.points)
                point = replay.points[kpoint]
                maximum(abs, point.k_fractional - @view(kpoints[kpoint, :])) <= 1.0e-10 ||
                    throw(ArgumentError("PAW_GAUGE_ARTIFACT_TAMPERED: source k-point differs"))
                persisted_g =
                    Int.(read(handle["g_vectors_by_kpoint"][@sprintf("kpoint_%06d", kpoint)]))
                point.g_vectors == persisted_g || throw(
                    ArgumentError("PAW_GAUGE_ARTIFACT_TAMPERED: source plane-wave basis differs"),
                )
            end
            for representative in star_representatives
                point = replay.points[representative]
                persisted = representative_points[representative]
                maximum(abs, point.coefficients - persisted.coefficients) <= threshold || throw(
                    ArgumentError(
                        "PAW_GAUGE_ARTIFACT_TAMPERED: local-source representative replay differs",
                    ),
                )
                maximum(abs, point.energies_ev - persisted.energies_ev) <= 1.0e-12 || throw(
                    ArgumentError(
                        "HAMILTONIAN_REFERENCE_MISMATCH: representative replay energies differ",
                    ),
                )
            end
            replay.points
        else
            legacy_points = Vector{PlaneWaveKPoint}(undef, size(kpoints, 1))
            for kpoint in axes(kpoints, 1)
                representative = representative_for_kpoint[kpoint]
                representative_point = representative_points[representative]
                if kpoint == representative
                    legacy_points[kpoint] = representative_point
                    continue
                end
                operation_index = canonical_operation_for_kpoint[kpoint]
                target_g_vectors =
                    Int.(read(handle["g_vectors_by_kpoint"][@sprintf("kpoint_%06d", kpoint)]))
                template = PlaneWaveKPoint(
                    @view(kpoints[kpoint, :]),
                    target_g_vectors,
                    zeros(
                        ComplexF64,
                        size(energies, 1),
                        size(target_g_vectors, 1),
                        size(representative_point.coefficients, 3),
                    ),
                    Vector{Float64}(@view(energies[:, kpoint]));
                    normalize_coefficients = false,
                )
                coefficients = _strict_transform_plane_wave_coefficients(
                    representative_point,
                    template,
                    operations[operation_index],
                    @view(reciprocal_shifts[:, operation_index, representative]),
                )
                legacy_points[kpoint] = PlaneWaveKPoint(
                    template.k_fractional,
                    template.g_vectors,
                    coefficients,
                    template.energies_ev;
                    normalize_coefficients = false,
                )
            end
            legacy_points
        end
        native = NativeWavefunctionData(
            Symbol(String(read(attributes["source_code"]))),
            structure,
            reciprocal_lattice,
            mp_grid,
            Bool(read(attributes["spinor"])),
            points,
            input_sha256,
            source_metadata,
        )
        metric_group = handle["parsed_paw_metric"]
        metric_kind = String(read(HDF5.attributes(metric_group)["kind"]))
        persisted_metric = if metric_kind == "qe_upf_beta_q0"
            _star_read_qe_metric(metric_group, native)
        elseif metric_kind == "vasp_potcar_projector_q0"
            _star_read_vasp_metric(metric_group, native)
        else
            throw(ArgumentError("PAW_GAUGE_ARTIFACT_TAMPERED: unknown PAW metric kind"))
        end
        metric = if replayed_metric === nothing
            persisted_metric
        else
            _star_metric_sha256(something(replayed_metric)) == _star_metric_sha256(persisted_metric) || throw(
                ArgumentError("PAW_GAUGE_ARTIFACT_TAMPERED: replayed PAW metric digest differs"),
            )
            threshold =
                frame_replay_active ?
                _band_frame_float(source_metadata, "band_frame_replay_tolerance") :
                _star_scoped_paw_threshold(source_metadata, :wfc_rotation_reconstruction)
            maximum(
                maximum(
                    abs,
                    something(replayed_metric).projectors[kpoint] -
                    persisted_metric.projectors[kpoint],
                ) for kpoint in eachindex(native.kpoints)
            ) <= threshold || throw(
                ArgumentError(
                    "PAW_GAUGE_ARTIFACT_TAMPERED: replayed PAW projectors differ from artifact",
                ),
            )
            replay_norm = if haskey(handle, "qualification_scope")
                replay_outer_mask = Bool.(read(handle["qualification_scope/outer_mask"]))
                first(
                    _star_scoped_generalized_norm_from_metric(
                        something(replayed_metric),
                        native,
                        replay_outer_mask,
                    ),
                )
            else
                first(_strict_generalized_norm_from_metric(something(replayed_metric), native))
            end
            physical_tolerance =
                frame_replay_active ?
                _band_frame_float(source_metadata, "band_frame_physical_isometry_tolerance") :
                _star_scoped_paw_threshold(source_metadata, :paw_s_norm)
            replay_norm <= physical_tolerance || throw(
                ArgumentError(
                    "PAW_GAUGE_ARTIFACT_ROUNDTRIP_HOLD: replayed PAW-S norm exceeds the target contract",
                ),
            )
            something(replayed_metric)
        end
        maxima = Dict{String, Float64}(
            String(key) => Float64(read(HDF5.attributes(handle["preflight_maxima"])[key])) for
            key in keys(HDF5.attributes(handle["preflight_maxima"]))
        )
        contexts = read_string_dictionary(handle["maximum_contexts"])
        qualification_scope =
            if contract_version in ("1.10", "1.11") && haskey(handle, "qualification_scope")
                group = handle["qualification_scope"]
                group_attributes = HDF5.attributes(group)
                String(read(group_attributes["authority"])) == "outer_window" || throw(
                    ArgumentError(
                        "HAMILTONIAN_REFERENCE_MISMATCH: star gauge authority is not outer_window",
                    ),
                )
                String(read(group_attributes["parent_audit_policy"])) == "audit_only" || throw(
                    ArgumentError(
                        "HAMILTONIAN_REFERENCE_MISMATCH: parent audit policy is not audit_only",
                    ),
                )
                BandRepresentationQualificationScope(
                    Bool.(read(group["outer_mask"])),
                    Bool.(read(group["frozen_mask"]));
                    outer_mask_sha256 = String(read(group_attributes["outer_mask_sha256"])),
                    frozen_mask_sha256 = String(read(group_attributes["frozen_mask_sha256"])),
                )
            elseif contract_version in ("1.10", "1.11") &&
                   get(source_metadata, "qualification_scope", "") == "target_subspace"
                throw(
                    ArgumentError(
                        "PAW_GAUGE_ARTIFACT_TAMPERED: symmetrized schema-1.9 omits qualification_scope",
                    ),
                )
            else
                nothing
            end
        payload = _StarCovariantPAWPayload(
            native,
            metric,
            operations,
            kpoint_map,
            reciprocal_shifts,
            representative_for_kpoint,
            canonical_operation_for_kpoint,
            star_representatives,
            extra_bands_per_star,
            rotations,
            Int(read(attributes["target_band_start"])):Int(read(attributes["target_band_stop"])),
            Int(read(attributes["parent_band_start"])):Int(read(attributes["parent_band_stop"])),
            maxima,
            contexts,
            input_sha256,
            source_metadata,
            qualification_scope,
            symmetrized_audit,
            sealed_frame_corrections,
        )
        if contract_version in
           ("1.1", "1.2", "1.3", "1.4", "1.5", "1.6", "1.7", "1.8", "1.9", "1.10", "1.11")
            haskey(attributes, "block_partition_policy") ||
                throw(ArgumentError("modern gauge artifact is missing block_partition_policy"))
            haskey(input_sha256, "BLOCK_PARTITION_POLICY_SHA256") ||
                throw(ArgumentError("modern gauge artifact is missing its block-policy digest"))
            String(read(attributes["block_partition_policy"])) ==
            get(source_metadata, "block_partition_policy", "") ||
                throw(ArgumentError("PAW_GAUGE_ARTIFACT_TAMPERED: block policy metadata differs"))
            String(read(attributes["block_partition_policy_sha256"])) ==
            input_sha256["BLOCK_PARTITION_POLICY_SHA256"] ||
                throw(ArgumentError("PAW_GAUGE_ARTIFACT_TAMPERED: block policy digest differs"))
            if get(source_metadata, "block_partition_policy", "") == "hamiltonian_weighted_far_band"
                contract_version in
                ("1.2", "1.3", "1.4", "1.5", "1.6", "1.7", "1.8", "1.9", "1.10", "1.11") || throw(
                    ArgumentError(
                        "WAVEFUNCTION_GAUGE_BACKEND_MISMATCH: Hamiltonian-weighted policy requires gauge schema 1.2",
                    ),
                )
            end
        else
            get!(source_metadata, "block_partition_policy", "fixed_gap_legacy_20mev")
        end
        if contract_version in ("1.3", "1.4", "1.5", "1.6", "1.7", "1.8", "1.9", "1.10", "1.11")
            for key in (
                "discrete_hamiltonian_correction",
                "discrete_hamiltonian_correction_sha256",
                "controlled_symmetrization_qualification_mode",
                "production_eligible",
                "diagnostic_only",
            )
                haskey(attributes, key) ||
                    throw(ArgumentError("schema-1.3 gauge artifact is missing $(key)"))
            end
            String(read(attributes["discrete_hamiltonian_correction"])) ==
            get(source_metadata, "discrete_hamiltonian_correction", "") || throw(
                ArgumentError(
                    "PAW_GAUGE_ARTIFACT_TAMPERED: Hamiltonian-correction metadata differs",
                ),
            )
            String(read(attributes["discrete_hamiltonian_correction_sha256"])) ==
            get(input_sha256, "DISCRETE_HAMILTONIAN_CORRECTION_SHA256", "") || throw(
                ArgumentError("PAW_GAUGE_ARTIFACT_TAMPERED: Hamiltonian-correction digest differs"),
            )
            status == :PASS &&
                !Bool(read(attributes["production_eligible"])) &&
                throw(
                    ArgumentError(
                        "PAW_GAUGE_ARTIFACT_TAMPERED: PASS artifact is not production eligible",
                    ),
                )
            status == :DIAGNOSTIC_ONLY &&
                (
                    !Bool(read(attributes["diagnostic_only"])) ||
                    Bool(read(attributes["production_eligible"]))
                ) &&
                throw(
                    ArgumentError(
                        "PAW_GAUGE_ARTIFACT_TAMPERED: diagnostic qualification flags disagree",
                    ),
                )
        elseif contract_version in ("1.1", "1.2")
            get!(source_metadata, "discrete_hamiltonian_correction", "none")
        end
        if contract_version in ("1.4", "1.5", "1.6", "1.7", "1.8", "1.9", "1.10", "1.11")
            for key in (
                "authoritative_hamiltonian",
                "authoritative_hamiltonian_sha256",
                "native_fidelity_status",
                "symmetrized_hamiltonian_status",
                "scoped_production_eligible",
                "global_production_eligible",
                "has_symmetrized_hamiltonian_audit",
            )
                haskey(attributes, key) ||
                    throw(ArgumentError("schema-1.4 gauge artifact is missing $(key)"))
            end
            String(read(attributes["authoritative_hamiltonian"])) ==
            get(source_metadata, "authoritative_hamiltonian", "") ||
                throw(ArgumentError("PAW_GAUGE_ARTIFACT_TAMPERED: Hamiltonian authority differs"))
            String(read(attributes["authoritative_hamiltonian_sha256"])) ==
            get(input_sha256, "AUTHORITATIVE_HAMILTONIAN_SHA256", "") || throw(
                ArgumentError("PAW_GAUGE_ARTIFACT_TAMPERED: Hamiltonian authority digest differs"),
            )
            Bool(read(attributes["global_production_eligible"])) && throw(
                ArgumentError("PAW_GAUGE_ARTIFACT_TAMPERED: global production cannot be granted"),
            )
            authority = validate_authoritative_hamiltonian_key(
                String(read(attributes["authoritative_hamiltonian"])),
            )
            authority == "symmetrized_dft_hamiltonian" &&
                symmetrized_audit === nothing &&
                throw(
                    ArgumentError(
                        "PAW_GAUGE_ARTIFACT_TAMPERED: symmetrized authority lacks audit arrays",
                    ),
                )
            if contract_version in ("1.5", "1.6", "1.7", "1.8", "1.9", "1.10", "1.11") &&
               authority == "symmetrized_dft_hamiltonian"
                for key in (
                    "energy_shift_qualification",
                    "maximum_energy_shift_audit_reference_ev",
                    "rms_energy_shift_audit_reference_ev",
                    "target_energy_shift_audit_status",
                    "symmetrized_parent_energy_shift_audit_status",
                )
                    haskey(attributes, key) ||
                        throw(ArgumentError("audit-only gauge artifact is missing $(key)"))
                end
                String(read(attributes["energy_shift_qualification"])) == "audit_only" || throw(
                    ArgumentError(
                        "HAMILTONIAN_REFERENCE_MISMATCH: symmetrized authority requires audit-only energy shifts",
                    ),
                )
                get(source_metadata, "energy_shift_qualification", "") == "audit_only" || throw(
                    ArgumentError(
                        "PAW_GAUGE_ARTIFACT_TAMPERED: energy-shift qualification metadata differs",
                    ),
                )
                for key in (
                    "energy_shift_qualification",
                    "maximum_energy_shift_audit_reference_ev",
                    "rms_energy_shift_audit_reference_ev",
                    "target_energy_shift_audit_status",
                    "symmetrized_parent_energy_shift_audit_status",
                )
                    String(read(attributes[key])) == get(source_metadata, key, "") || throw(
                        ArgumentError(
                            "PAW_GAUGE_ARTIFACT_TAMPERED: $(key) attribute differs from the digest-bound source metadata",
                        ),
                    )
                end
                if contract_version in ("1.6", "1.7", "1.8", "1.9", "1.10", "1.11")
                    for key in ("residual_gate_phase", "raw_preflight_diagnostic_status")
                        haskey(attributes, key) ||
                            throw(ArgumentError("schema-1.6 gauge artifact is missing $(key)"))
                        String(read(attributes[key])) == get(source_metadata, key, "") || throw(
                            ArgumentError(
                                "PAW_GAUGE_ARTIFACT_TAMPERED: $(key) attribute differs from the digest-bound source metadata",
                            ),
                        )
                    end
                    String(read(attributes["residual_gate_phase"])) == "post_symmetrization" ||
                        throw(
                            ArgumentError(
                                "HAMILTONIAN_REFERENCE_MISMATCH: schema-1.6 symmetrized authority requires post-symmetrization residual gates",
                            ),
                        )
                    if contract_version in ("1.7", "1.8", "1.9", "1.10", "1.11")
                        for key in
                            ("native_difference_qualification", "native_difference_audit_status")
                            haskey(attributes, key) ||
                                throw(ArgumentError("schema-1.7 gauge artifact is missing $(key)"))
                            String(read(attributes[key])) == get(source_metadata, key, "") || throw(
                                ArgumentError(
                                    "PAW_GAUGE_ARTIFACT_TAMPERED: $(key) attribute differs from the digest-bound source metadata",
                                ),
                            )
                        end
                        String(read(attributes["native_difference_qualification"])) ==
                        "audit_only" || throw(
                            ArgumentError(
                                "HAMILTONIAN_REFERENCE_MISMATCH: schema-1.7 symmetrized authority requires audit-only native differences",
                            ),
                        )
                    else
                        get!(source_metadata, "native_difference_qualification", "legacy_hard_gate")
                    end
                else
                    get!(source_metadata, "residual_gate_phase", "legacy_pre_symmetrization")
                    get!(source_metadata, "native_difference_qualification", "legacy_hard_gate")
                end
            end
            if contract_version in ("1.10", "1.11") &&
               get(source_metadata, "qualification_scope", "") == "target_subspace"
                haskey(attributes, "target_subspace_contract_sha256") || throw(
                    ArgumentError(
                        "schema-1.10 target-subspace gauge artifact omits its contract digest",
                    ),
                )
                String(read(attributes["target_subspace_contract_sha256"])) ==
                get(input_sha256, "TARGET_SUBSPACE_CONTRACT_SHA256", "") || throw(
                    ArgumentError(
                        "PAW_GAUGE_ARTIFACT_TAMPERED: target-subspace contract digest differs",
                    ),
                )
                qualification_scope === nothing && throw(
                    ArgumentError(
                        "PAW_GAUGE_ARTIFACT_TAMPERED: target-subspace authority lacks qualification masks",
                    ),
                )
                for (key, expected) in (
                    ("target_leakage_semantics", TARGET_LEAKAGE_WEIGHT_SEMANTICS),
                    ("target_leakage_formula_sha256", TARGET_LEAKAGE_WEIGHT_FORMULA_SHA256),
                )
                    haskey(attributes, key) && String(read(attributes[key])) == expected || throw(
                        ArgumentError(
                            "UNSUPPORTED_LEGACY_TARGET_LEAKAGE_SEMANTICS: $(key) is missing or incompatible",
                        ),
                    )
                    get(source_metadata, key, "") == expected || throw(
                        ArgumentError(
                            "PAW_GAUGE_ARTIFACT_TAMPERED: $(key) differs from digest-bound metadata",
                        ),
                    )
                end
                threshold = _star_scoped_paw_threshold(source_metadata, :target_leakage_weight)
                haskey(attributes, "target_leakage_threshold") &&
                String(read(attributes["target_leakage_threshold"])) == repr(threshold) || throw(
                    ArgumentError(
                        "PAW_GAUGE_ARTIFACT_TAMPERED: target leakage threshold differs from its scoped contract",
                    ),
                )
            end
            if contract_version in ("1.10", "1.11") && authority == "symmetrized_dft_hamiltonian"
                for key in (
                    "symmetrized_target_subspace_status",
                    "auxiliary_parent_audit_status",
                    "target_scope_production_eligible",
                )
                    haskey(attributes, key) || throw(
                        ArgumentError(
                            "schema-1.8 target-subspace gauge artifact is missing $(key)",
                        ),
                    )
                end
                get(source_metadata, "qualification_scope", "") == "target_subspace" || throw(
                    ArgumentError("HAMILTONIAN_REFERENCE_MISMATCH: target authority scope differs"),
                )
                symmetrized_audit !== nothing &&
                symmetrized_audit.target_anchor_sha256_by_star !== nothing || throw(
                    ArgumentError(
                        "PAW_GAUGE_ARTIFACT_TAMPERED: target completion audit is missing",
                    ),
                )
                get(source_metadata, "nonrepresentative_frame_storage", "") ==
                "local_native_source_plus_completed_rotation" || throw(
                    ArgumentError(
                        "UNSUPPORTED_LEGACY_AUTHORITY: target completion does not use local-source rotation replay",
                    ),
                )
                something(symmetrized_audit).symmetrized_energies_ev == energies || throw(
                    ArgumentError(
                        "HAMILTONIAN_REFERENCE_MISMATCH: completed point and parent audit energies differ",
                    ),
                )
                sealed_frame_corrections === nothing || throw(
                    ArgumentError(
                        "PAW_GAUGE_ARTIFACT_TAMPERED: obsolete sealed-frame corrections remain",
                    ),
                )
            end
        else
            get!(source_metadata, "authoritative_hamiltonian", "native_dft")
        end
        digest_payload =
            target_scoped_symmetrized || frame_replay_active ?
            _star_payload_with_sealed_representatives(payload, representative_points) : payload
        String(read(attributes["payload_sha256"])) ==
        _star_payload_sha256(digest_payload; schema_version, contract_version) ||
            throw(ArgumentError("PAW_GAUGE_ARTIFACT_TAMPERED: logical payload digest differs"))
        band_frame_contract = if contract_version == "1.11"
            for key in (
                "band_frame_contract_schema",
                "band_frame_contract_schema_version",
                "band_frame_contract_status",
                "band_frame_source_gauge",
                "band_frame_target_gauge",
                "band_frame_transform_sha256",
                "band_frame_contract_sha256",
                "band_frame_metric_kind",
                "band_frame_physical_isometry_maximum",
                "band_frame_physical_isometry_tolerance",
                "band_frame_replay_maximum",
                "band_frame_replay_tolerance",
                "band_frame_euclidean_nonunitarity_maximum",
                "band_frame_minimum_singular_value",
                "band_frame_maximum_condition_number",
            )
                haskey(attributes, key) &&
                String(read(attributes[key])) == get(source_metadata, key, "") || throw(
                    ArgumentError(
                        "PAW_GAUGE_ARTIFACT_TAMPERED: $(key) differs from digest-bound metadata",
                    ),
                )
            end
            replayed_raw_native === nothing &&
                throw(ArgumentError("BAND_FRAME_SOURCE_MISMATCH: raw source was not replayed"))
            replayed_raw_metric === nothing &&
                throw(ArgumentError("BAND_FRAME_SOURCE_MISMATCH: raw metric was not replayed"))
            _restore_band_frame_transform_contract(
                source_metadata,
                input_sha256,
                something(replayed_raw_native),
                something(replayed_raw_metric),
                native,
                metric,
                rotations,
                sha256_file(filename),
            )
        else
            nothing
        end
        return (
            payload = payload,
            status = status,
            root_cause = Symbol(String(read(attributes["root_cause"]))),
            diagnostics = String.(read(handle["diagnostics"])),
            schema_version = schema_version,
            band_frame_contract = band_frame_contract,
        )
    end
end

# Digest the complete native-source identity without embedding thousands of WFC hashes in
# the compact audit manifest.  The hashes themselves remain persisted in the gauge capsule.
function _star_input_identity_sha256(input_sha256::AbstractDict{String, String})
    buffer = IOBuffer()
    for key in sort!(collect(keys(input_sha256)))
        write(buffer, key, '=', input_sha256[key], '\n')
    end
    return bytes2hex(SHA.sha256(take!(buffer)))
end

# Bind the frozen density/onsite audit to the exact WFC/XML/PAW source identity.  A
# manifest is deliberately stricter than accepting an arbitrary JSON document which
# happens not to contain the word "FAIL".
function _star_input_audit_hash(
    config,
    source_input_sha256::AbstractDict{String, String},
    operation_count::Int,
)
    config.input_symmetry_audit_json === nothing && return Dict{String, String}()
    filename = something(config.input_symmetry_audit_json)
    payload = JSON3.read(read(filename, String), Dict{String, Any})
    required = (
        "schema",
        "schema_version",
        "status",
        "operation_count",
        "maximum_residual",
        "qualification_threshold",
        "source_input_sha256",
        "component_audits",
    )
    all(key -> haskey(payload, key), required) ||
        throw(ArgumentError("INPUT_PROVENANCE_HOLD: input-symmetry manifest is incomplete"))
    String(payload["schema"]) == "wanniernlqg.input-symmetry-audit-manifest" ||
        throw(ArgumentError("INPUT_PROVENANCE_HOLD: unsupported input-symmetry audit schema"))
    String(payload["schema_version"]) == "1.0" || throw(
        ArgumentError("INPUT_PROVENANCE_HOLD: unsupported input-symmetry audit schema version"),
    )
    uppercase(String(payload["status"])) == "PASS" ||
        throw(ArgumentError("INPUT_SYMMETRY_HOLD: input-symmetry manifest status is not PASS"))
    Int(payload["operation_count"]) == operation_count ||
        throw(ArgumentError("INPUT_PROVENANCE_HOLD: input-symmetry operation count differs"))
    maximum_residual = Float64(payload["maximum_residual"])
    threshold = Float64(payload["qualification_threshold"])
    isfinite(maximum_residual) && isfinite(threshold) && threshold > 0.0 ||
        throw(ArgumentError("INPUT_PROVENANCE_HOLD: invalid input-symmetry residual contract"))
    maximum_residual <= threshold ||
        throw(ArgumentError("INPUT_SYMMETRY_HOLD: input-symmetry residual exceeds its threshold"))
    expected_source_digest = _star_input_identity_sha256(source_input_sha256)
    String(payload["source_input_sha256"]) == expected_source_digest ||
        throw(ArgumentError("INPUT_PROVENANCE_HOLD: input-symmetry audit source identity differs"))

    component_hashes = Dict{String, String}()
    component_kinds = Set{String}()
    component_records = payload["component_audits"]
    component_records isa AbstractVector && !isempty(component_records) ||
        throw(ArgumentError("INPUT_PROVENANCE_HOLD: component_audits must be a nonempty array"))
    for untyped_record in component_records
        record = Dict{String, Any}(String(key) => value for (key, value) in pairs(untyped_record))
        component_required =
            ("kind", "path", "sha256", "schema", "residual_field", "maximum_residual")
        all(key -> haskey(record, key), component_required) ||
            throw(ArgumentError("INPUT_PROVENANCE_HOLD: component audit record is incomplete"))
        kind = String(record["kind"])
        kind in component_kinds &&
            throw(ArgumentError("INPUT_PROVENANCE_HOLD: duplicate component audit kind $(kind)"))
        push!(component_kinds, kind)
        stored_path = String(record["path"])
        component_path =
            isabspath(stored_path) ? normpath(stored_path) :
            normpath(joinpath(dirname(filename), stored_path))
        isfile(component_path) || throw(
            ArgumentError(
                "INPUT_PROVENANCE_HOLD: component audit does not exist: $(component_path)",
            ),
        )
        digest = sha256_file(component_path)
        digest == String(record["sha256"]) || throw(
            ArgumentError("INPUT_PROVENANCE_HOLD: component audit digest differs for $(kind)"),
        )
        component = JSON3.read(read(component_path, String), Dict{String, Any})
        uppercase(String(get(component, "status", "MISSING"))) == "PASS" ||
            throw(ArgumentError("INPUT_SYMMETRY_HOLD: component audit $(kind) is not PASS"))
        Int(get(component, "operation_count", -1)) == operation_count || throw(
            ArgumentError("INPUT_PROVENANCE_HOLD: component audit $(kind) operation count differs"),
        )
        String(get(component, "schema", "")) == String(record["schema"]) ||
            throw(ArgumentError("INPUT_PROVENANCE_HOLD: component audit $(kind) schema differs"))
        residual_field = String(record["residual_field"])
        haskey(component, residual_field) || throw(
            ArgumentError("INPUT_PROVENANCE_HOLD: component audit $(kind) lacks its residual"),
        )
        component_residual = Float64(component[residual_field])
        recorded_residual = Float64(record["maximum_residual"])
        isfinite(component_residual) && component_residual == recorded_residual ||
            throw(ArgumentError("INPUT_PROVENANCE_HOLD: component audit $(kind) residual differs"))
        component_residual <= threshold ||
            throw(ArgumentError("INPUT_SYMMETRY_HOLD: component audit $(kind) exceeds threshold"))
        component_hashes["INPUT_SYMMETRY_COMPONENT:$(kind)"] = digest
    end
    required_kinds = Set(("smooth_density", "paw_onsite"))
    issubset(required_kinds, component_kinds) || throw(
        ArgumentError("INPUT_PROVENANCE_HOLD: smooth-density and PAW-onsite audits are required"),
    )
    maximum(Float64(record["maximum_residual"]) for record in component_records) ==
    maximum_residual ||
        throw(ArgumentError("INPUT_PROVENANCE_HOLD: manifest maximum residual is inconsistent"))
    component_hashes["INPUT_SYMMETRY_AUDIT_JSON"] = sha256_file(filename)
    component_hashes["INPUT_SYMMETRY_SOURCE_SHA256"] = expected_source_digest
    return component_hashes
end
