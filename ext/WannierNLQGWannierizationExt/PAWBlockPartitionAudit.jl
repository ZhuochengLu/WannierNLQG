const PAW_BLOCK_PARTITION_AUDIT_SCHEMA = "WannierNLQG.paw_block_partition_audit"
const PAW_BLOCK_PARTITION_AUDIT_SCHEMA_VERSION = "1.0"

"""One complex PAW sewing edge retained by the diagnostic audit."""
struct _PAWBlockEvidenceRecord
    star::Int
    representative_kpoint::Int
    source_kpoint::Int
    target_kpoint::Int
    operation_index::Int
    operation_key::String
    antiunitary::Bool
    source_native_band::Int
    target_native_band::Int
    source_cluster::Int
    target_cluster::Int
    source_energy_ev::Float64
    target_energy_ev::Float64
    gap_ev::Float64
    pseudo::ComplexF64
    augmentation::ComplexF64
    paw::ComplexF64
    classification::Symbol
    hamiltonian_residual_ev::ComplexF64
    cancellation_condition::Float64
    high_precision_audited::Bool
    production_absolute_difference::Float64
    reverse_absolute_difference::Float64
    compensated_absolute_difference::Float64
    pseudo_absolute_difference::Float64
    augmentation_absolute_difference::Float64
end

# Assign connected components to frozen native-band pairs independently by k-star.
function _paw_audit_component_labels(records::Vector{_PAWBlockEvidenceRecord})
    labels = zeros(Int, length(records))
    orbit_labels = zeros(Int, length(records))
    orbit_keys = sort!(
        unique(
            (
                record.star,
                min(record.source_native_band, record.target_native_band),
                max(record.source_native_band, record.target_native_band),
            ) for record in records
        ),
    )
    orbit_index = Dict(key => index for (index, key) in enumerate(orbit_keys))
    next_component = 0
    for star in sort!(unique(record.star for record in records))
        indices = findall(index -> records[index].star == star, eachindex(records))
        bands = sort!(
            unique(
                vcat(
                    [records[index].source_native_band for index in indices],
                    [records[index].target_native_band for index in indices],
                ),
            ),
        )
        parent = Dict(band => band for band in bands)
        function find_root(band)
            while parent[band] != band
                parent[band] = parent[parent[band]]
                band = parent[band]
            end
            return band
        end
        function join(left, right)
            left_root = find_root(left)
            right_root = find_root(right)
            left_root == right_root || (parent[right_root] = left_root)
            return nothing
        end
        for index in indices
            record = records[index]
            join(record.source_native_band, record.target_native_band)
        end
        roots = sort!(unique(find_root(band) for band in bands))
        local_labels =
            Dict(root => next_component + ordinal for (ordinal, root) in enumerate(roots))
        next_component += length(roots)
        for index in indices
            record = records[index]
            labels[index] = local_labels[find_root(record.source_native_band)]
            key = (
                record.star,
                min(record.source_native_band, record.target_native_band),
                max(record.source_native_band, record.target_native_band),
            )
            orbit_labels[index] = orbit_index[key]
        end
    end
    return labels, orbit_labels
end

# Return graph-size diagnostics for one fixed gap without granting qualification.
function _paw_audit_fixed_lane(records::Vector{_PAWBlockEvidenceRecord}, cap_ev::Float64)
    admitted = findall(record -> record.gap_ev <= cap_ev, records)
    unresolved = length(records) - length(admitted)
    isempty(admitted) && return (
        cap_ev = cap_ev,
        admitted = 0,
        unresolved = unresolved,
        maximum_component_bands = 1,
        maximum_component_span_ev = 0.0,
        cascade_edge_count = 0,
    )
    subset = records[admitted]
    labels, _ = _paw_audit_component_labels(subset)
    maximum_bands = 1
    maximum_span = 0.0
    cascade_edges = 0
    for label in unique(labels)
        component = subset[findall(==(label), labels)]
        bands = unique(
            vcat(
                [record.source_native_band for record in component],
                [record.target_native_band for record in component],
            ),
        )
        energies = vcat(
            [record.source_energy_ev for record in component],
            [record.target_energy_ev for record in component],
        )
        maximum_bands = max(maximum_bands, length(bands))
        maximum_span = max(maximum_span, maximum(energies) - minimum(energies))
        cascade_edges += max(0, length(bands) - 2)
    end
    return (
        cap_ev = cap_ev,
        admitted = length(admitted),
        unresolved = unresolved,
        maximum_component_bands = maximum_bands,
        maximum_component_span_ev = maximum_span,
        cascade_edge_count = cascade_edges,
    )
end

# Count the fewest weighted components required to cover one cumulative fraction.
function _paw_audit_weight_coverage(weights::Vector{Float64}, fraction::Float64)
    isempty(weights) && return 0
    ordered = sort(weights; rev = true)
    target = fraction * sum(ordered)
    cumulative = 0.0
    for (index, value) in enumerate(ordered)
        cumulative += value
        cumulative + eps(max(target, 1.0)) >= target && return index
    end
    return length(ordered)
end

# Atomically persist columnar complex evidence without converting it through JSON.
function _write_paw_block_partition_audit_hdf5(
    filename::AbstractString,
    records::Vector{_PAWBlockEvidenceRecord},
    component_labels::Vector{Int},
    orbit_labels::Vector{Int},
    lanes,
    summary::AbstractDict,
    input_sha256::AbstractDict,
)
    HDF5.enable_complex_support()
    return atomic_hdf5_write(filename) do temporary
        HDF5.h5open(temporary, "w") do handle
            attributes = HDF5.attributes(handle)
            attributes["schema"] = PAW_BLOCK_PARTITION_AUDIT_SCHEMA
            attributes["schema_version"] = PAW_BLOCK_PARTITION_AUDIT_SCHEMA_VERSION
            attributes["status"] = "DIAGNOSTIC_ONLY"
            attributes["production_eligible"] = false
            for (key, value) in summary
                key in ("status", "production_eligible") && continue
                value isa Union{AbstractString, Real, Bool} || continue
                attributes[string(key)] = value
            end
            evidence = HDF5.create_group(handle, "evidence")
            evidence["star"] = Int[record.star for record in records]
            evidence["representative_kpoint"] =
                Int[record.representative_kpoint for record in records]
            evidence["source_kpoint"] = Int[record.source_kpoint for record in records]
            evidence["target_kpoint"] = Int[record.target_kpoint for record in records]
            evidence["operation_index"] = Int[record.operation_index for record in records]
            evidence["operation_key"] = String[record.operation_key for record in records]
            evidence["antiunitary"] = UInt8[record.antiunitary for record in records]
            evidence["source_native_band"] = Int[record.source_native_band for record in records]
            evidence["target_native_band"] = Int[record.target_native_band for record in records]
            evidence["source_cluster"] = Int[record.source_cluster for record in records]
            evidence["target_cluster"] = Int[record.target_cluster for record in records]
            evidence["source_energy_ev"] = Float64[record.source_energy_ev for record in records]
            evidence["target_energy_ev"] = Float64[record.target_energy_ev for record in records]
            evidence["gap_ev"] = Float64[record.gap_ev for record in records]
            evidence["pseudo"] = ComplexF64[record.pseudo for record in records]
            evidence["augmentation"] = ComplexF64[record.augmentation for record in records]
            evidence["paw"] = ComplexF64[record.paw for record in records]
            evidence["classification"] = String[String(record.classification) for record in records]
            evidence["hamiltonian_residual_ev"] =
                ComplexF64[record.hamiltonian_residual_ev for record in records]
            evidence["cancellation_condition"] =
                Float64[record.cancellation_condition for record in records]
            evidence["high_precision_audited"] =
                UInt8[record.high_precision_audited for record in records]
            evidence["production_absolute_difference"] =
                Float64[record.production_absolute_difference for record in records]
            evidence["reverse_absolute_difference"] =
                Float64[record.reverse_absolute_difference for record in records]
            evidence["compensated_absolute_difference"] =
                Float64[record.compensated_absolute_difference for record in records]
            evidence["pseudo_absolute_difference"] =
                Float64[record.pseudo_absolute_difference for record in records]
            evidence["augmentation_absolute_difference"] =
                Float64[record.augmentation_absolute_difference for record in records]
            evidence["legacy_over_20mev"] = UInt8[record.gap_ev > 0.020 for record in records]
            evidence["component_id"] = component_labels
            evidence["edge_orbit_id"] = orbit_labels
            lane_group = HDF5.create_group(handle, "fixed_gap_scan")
            for name in keys(first(lanes))
                lane_group[string(name)] = getfield.(lanes, name)
            end
            hashes = HDF5.create_group(handle, "input_sha256")
            write_string_dictionary(
                hashes,
                Dict(string(key) => string(value) for (key, value) in input_sha256),
            )
        end
    end
end

# Write the complete flattened evidence table, including complex phase information.
function _write_paw_block_partition_audit_csv(
    filename::AbstractString,
    records::Vector{_PAWBlockEvidenceRecord},
    component_labels::Vector{Int},
    orbit_labels::Vector{Int},
)
    temporary = filename * ".tmp"
    mkpath(dirname(filename))
    open(temporary, "w") do io
        println(
            io,
            "star,representative_kpoint,source_kpoint,target_kpoint,operation_index," *
            "operation_key,antiunitary,source_native_band,target_native_band,source_cluster," *
            "target_cluster,source_energy_ev,target_energy_ev,gap_ev,pseudo_real,pseudo_imag," *
            "pseudo_abs,augmentation_real,augmentation_imag,augmentation_abs,paw_real,paw_imag," *
            "paw_abs,pseudo_augmentation_phase_rad,classification,residual_real_ev,residual_imag_ev," *
            "residual_abs_ev,cancellation_condition,high_precision_audited," *
            "production_absolute_difference," *
            "reverse_absolute_difference,compensated_absolute_difference,pseudo_absolute_difference," *
            "augmentation_absolute_difference,legacy_over_20mev,component_id,edge_orbit_id",
        )
        for (index, record) in enumerate(records)
            phase = angle(record.augmentation) - angle(record.pseudo)
            escaped_key = replace(record.operation_key, '"' => "\"\"")
            println(
                io,
                join(
                    (
                        record.star,
                        record.representative_kpoint,
                        record.source_kpoint,
                        record.target_kpoint,
                        record.operation_index,
                        "\"$(escaped_key)\"",
                        record.antiunitary,
                        record.source_native_band,
                        record.target_native_band,
                        record.source_cluster,
                        record.target_cluster,
                        repr(record.source_energy_ev),
                        repr(record.target_energy_ev),
                        repr(record.gap_ev),
                        repr(real(record.pseudo)),
                        repr(imag(record.pseudo)),
                        repr(abs(record.pseudo)),
                        repr(real(record.augmentation)),
                        repr(imag(record.augmentation)),
                        repr(abs(record.augmentation)),
                        repr(real(record.paw)),
                        repr(imag(record.paw)),
                        repr(abs(record.paw)),
                        repr(phase),
                        String(record.classification),
                        repr(real(record.hamiltonian_residual_ev)),
                        repr(imag(record.hamiltonian_residual_ev)),
                        repr(abs(record.hamiltonian_residual_ev)),
                        repr(record.cancellation_condition),
                        record.high_precision_audited,
                        repr(record.production_absolute_difference),
                        repr(record.reverse_absolute_difference),
                        repr(record.compensated_absolute_difference),
                        repr(record.pseudo_absolute_difference),
                        repr(record.augmentation_absolute_difference),
                        record.gap_ev > 0.020,
                        component_labels[index],
                        orbit_labels[index],
                    ),
                    ',',
                ),
            )
        end
    end
    mv(temporary, filename; force = true)
    return filename
end

"""Inventory physical PAW cross-block evidence without constructing a gauge artifact."""
function audit_paw_block_partitions(config::PAWBlockPartitionAuditConfig)
    source = config.source
    source isa Union{QuantumEspressoWavefunctionSource, VASPWavefunctionSource} ||
        throw(ArgumentError("PAW block audit requires a QE or VASP source"))
    target_range = something(source.band_range)
    target_count = config.target_band_count == 0 ? length(target_range) : config.target_band_count
    target_count == length(target_range) || throw(ArgumentError("PAW audit target rank mismatch"))
    parent_source = _star_source_with_band_range(source, nothing)
    raw_native = _read_augmentation_aware_native_source(parent_source)
    raw_metric, native_norm, native_norm_worst = _strict_sewing_metric(parent_source, raw_native)
    thresholds = PAWGaugeThresholds()
    lowdin = _star_lowdin_native(raw_native, raw_metric, thresholds.paw_s_norm)
    native = lowdin.native
    metric = lowdin.metric
    inventory = detect_magnetic_symmetry_inventory(
        native.structure;
        include_time_reversal = source.include_time_reversal,
        symmetry_tolerance = config.symmetry_tolerance,
    )
    operations = inventory.operations
    kpoints =
        Matrix{Float64}(reduce(vcat, (transpose(point.k_fractional) for point in native.kpoints)))
    kpoint_map, reciprocal_shifts =
        build_canonical_kpoint_action(operations, kpoints; tolerance = 1.0e-8)
    stars = _star_orbits(kpoint_map)
    star_for_kpoint = zeros(Int, length(native.kpoints))
    representative_for_kpoint = zeros(Int, length(native.kpoints))
    for (star_index, star) in enumerate(stars)
        star_for_kpoint[star] .= star_index
        representative_for_kpoint[star] .= first(star)
    end
    selected_kpoints =
        config.kpoint_indices === nothing ? collect(eachindex(native.kpoints)) :
        sort!(unique(something(config.kpoint_indices)))
    all(kpoint -> kpoint in eachindex(native.kpoints), selected_kpoints) ||
        throw(ArgumentError("PAW audit kpoint_indices exceed the native grid"))
    records = _PAWBlockEvidenceRecord[]
    maximum_reconstruction = 0.0
    maximum_target_leakage = 0.0
    maximum_raw_unitarity = 0.0
    maximum_polar_correction = 0.0
    maximum_hamiltonian_covariance = 0.0
    maximum_hamiltonian_operator = 0.0
    maximum_hamiltonian_source_column_l2 = 0.0
    maximum_hamiltonian_normalized_frobenius = 0.0
    maximum_hamiltonian_frobenius = 0.0
    maximum_far_pair_residual = 0.0
    maximum_far_operator_residual = 0.0
    maximum_far_source_column_l2_residual = 0.0
    maximum_far_normalized_frobenius_residual = 0.0
    maximum_far_frobenius_residual = 0.0
    maximum_notable_far_operator_residual = 0.0
    maximum_notable_far_source_column_l2_residual = 0.0
    maximum_notable_far_normalized_frobenius_residual = 0.0
    maximum_notable_far_frobenius_residual = 0.0
    maximum_cancellation_condition = 0.0
    maximum_cancellation_stability_difference = 0.0
    far_residual_count = 0
    tolerated_far_residual_count = 0
    total_far_cross_cluster_count = 0
    weighted_policy = config.block_partition_policy isa HamiltonianWeightedPAWBlockPartition
    hamiltonian_policy =
        weighted_policy ? (config.block_partition_policy::HamiltonianWeightedPAWBlockPartition) :
        HamiltonianWeightedPAWBlockPartition()
    residual_thresholds = hamiltonian_policy.residual_thresholds
    cancellation_thresholds = hamiltonian_policy.cancellation_thresholds
    pair_residual_hold = false
    cumulative_residual_hold = false
    cancellation_stability_hold = false
    buffer_policy = ClosureDrivenBandBuffer()
    for source_kpoint in selected_kpoints
        transports = [
            _star_transport(
                metric,
                native,
                source_kpoint,
                operation_index,
                kpoint_map[operation_index, source_kpoint],
                @view(reciprocal_shifts[:, operation_index, source_kpoint]),
                operations,
            ) for operation_index in eachindex(operations)
        ]
        raw_transports = getfield.(transports, :raw)
        source_energies = native.kpoints[source_kpoint].energies_ev
        workspace, buffer_leakage = _star_select_buffer(
            raw_transports,
            source_energies,
            target_range,
            buffer_policy,
            thresholds.state_leakage_amplitude,
        )
        maximum_target_leakage = max(maximum_target_leakage, buffer_leakage)
        selected_source_energies = source_energies[workspace]
        clusters =
            _star_energy_clusters(selected_source_energies, buffer_policy.cluster_tolerance_ev)
        band_to_cluster = zeros(Int, length(workspace))
        for (cluster_index, cluster) in enumerate(clusters)
            band_to_cluster[cluster] .= cluster_index
        end
        for operation_index in eachindex(operations)
            target_kpoint = kpoint_map[operation_index, source_kpoint]
            transport = transports[operation_index]
            reconstruction = transport.reconstruction
            maximum_reconstruction =
                max(maximum_reconstruction, reconstruction.reconstruction_leakage_amplitude_audit)
            maximum_target_leakage =
                max(maximum_target_leakage, reconstruction.state_leakage_amplitude_audit)
            raw = Matrix(@view(transport.raw[workspace, workspace]))
            pseudo = @view(transport.pseudo[workspace, workspace])
            augmentation = @view(transport.augmentation[workspace, workspace])
            identity_matrix = Matrix{ComplexF64}(I, length(workspace), length(workspace))
            maximum_raw_unitarity = max(
                maximum_raw_unitarity,
                maximum(abs, raw' * raw - identity_matrix),
                maximum(abs, raw * raw' - identity_matrix),
            )
            decomposition = svd(raw)
            polar = decomposition.U * decomposition.Vt
            maximum_polar_correction =
                max(maximum_polar_correction, norm(polar - raw) / sqrt(length(workspace)))
            source_hamiltonian =
                Matrix(@view(lowdin.hamiltonians[source_kpoint][workspace, workspace]))
            source_action =
                operations[operation_index].antiunitary ? conj(source_hamiltonian) :
                source_hamiltonian
            target_hamiltonian =
                Matrix(@view(lowdin.hamiltonians[target_kpoint][workspace, workspace]))
            full_metrics = _star_hamiltonian_residual_metrics(
                raw,
                source_hamiltonian,
                target_hamiltonian,
                operations[operation_index].antiunitary,
            )
            maximum_hamiltonian_covariance =
                max(maximum_hamiltonian_covariance, full_metrics.maximum_element_ev)
            maximum_hamiltonian_operator =
                max(maximum_hamiltonian_operator, full_metrics.operator_ev)
            maximum_hamiltonian_source_column_l2 =
                max(maximum_hamiltonian_source_column_l2, full_metrics.maximum_source_column_l2_ev)
            maximum_hamiltonian_normalized_frobenius =
                max(maximum_hamiltonian_normalized_frobenius, full_metrics.normalized_frobenius_ev)
            maximum_hamiltonian_frobenius =
                max(maximum_hamiltonian_frobenius, full_metrics.frobenius_ev)
            target_energies = native.kpoints[target_kpoint].energies_ev[workspace]
            far_mask = falses(size(raw))
            notable_far_mask = falses(size(raw))
            cancellation_candidates = NamedTuple[]
            if weighted_policy
                for target_band in axes(raw, 1), source_band in axes(raw, 2)
                    band_to_cluster[target_band] == band_to_cluster[source_band] && continue
                    gap = abs(target_energies[target_band] - selected_source_energies[source_band])
                    gap > hamiltonian_policy.near_gap_ev || continue
                    condition =
                        (
                            abs(pseudo[target_band, source_band]) +
                            abs(augmentation[target_band, source_band])
                        ) / max(abs(raw[target_band, source_band]), eps(Float64))
                    push!(
                        cancellation_candidates,
                        (condition = condition, target = target_band, source = source_band),
                    )
                end
                sort!(
                    cancellation_candidates;
                    by = item -> (-item.condition, item.target, item.source),
                )
            end
            high_condition_pairs = Set(
                (item.target, item.source) for
                item in cancellation_candidates[1:min(8, length(cancellation_candidates))]
            )
            for target_band in axes(raw, 1), source_band in axes(raw, 2)
                band_to_cluster[target_band] == band_to_cluster[source_band] && continue
                signed_gap = target_energies[target_band] - selected_source_energies[source_band]
                gap = abs(signed_gap)
                coupling = abs(raw[target_band, source_band])
                is_far = gap > hamiltonian_policy.near_gap_ev
                is_far && (far_mask[target_band, source_band] = true)
                is_far && (total_far_cross_cluster_count += 1)
                pair_residual = signed_gap * raw[target_band, source_band]
                classification = if !is_far
                    coupling > thresholds.nondegenerate_block_leakage ?
                    :MERGE_REQUIRED_NEAR_DEGENERATE : :BELOW_NEAR_COUPLING_THRESHOLD
                elseif abs(pair_residual) <= residual_thresholds.pair_ev
                    :TOLERATED_FAR_BAND_RESIDUAL
                else
                    :FAR_BAND_PAIR_RESIDUAL_HOLD
                end
                if is_far
                    maximum_far_pair_residual = max(maximum_far_pair_residual, abs(pair_residual))
                    coupling > thresholds.nondegenerate_block_leakage && (far_residual_count += 1)
                    coupling > thresholds.nondegenerate_block_leakage &&
                        classification == :TOLERATED_FAR_BAND_RESIDUAL &&
                        (tolerated_far_residual_count += 1)
                    classification == :FAR_BAND_PAIR_RESIDUAL_HOLD && (pair_residual_hold = true)
                end
                notable =
                    coupling > thresholds.nondegenerate_block_leakage ||
                    classification == :FAR_BAND_PAIR_RESIDUAL_HOLD
                is_far && notable && (notable_far_mask[target_band, source_band] = true)
                (weighted_policy || notable) || continue
                high_precision_selected =
                    weighted_policy &&
                    is_far &&
                    (notable || (target_band, source_band) in high_condition_pairs)
                stability = if high_precision_selected
                    _strict_metric_overlap_element_stability(
                        metric,
                        native.kpoints[target_kpoint].coefficients,
                        transport.transformed,
                        metric.projectors[target_kpoint],
                        transport.transformed_projectors,
                        workspace[target_band],
                        workspace[source_band];
                        precision_bits = cancellation_thresholds.bigfloat_precision_bits,
                    )
                else
                    nothing
                end
                production_difference =
                    stability === nothing ? 0.0 :
                    maximum((
                        abs(pseudo[target_band, source_band] - stability.reference_pseudo),
                        abs(
                            augmentation[target_band, source_band] -
                            stability.reference_augmentation,
                        ),
                        abs(raw[target_band, source_band] - stability.reference_total),
                        stability.production_absolute_difference,
                    ))
                reverse_difference =
                    stability === nothing ? 0.0 : stability.reverse_absolute_difference
                compensated_difference =
                    stability === nothing ? 0.0 : stability.compensated_absolute_difference
                pseudo_difference =
                    stability === nothing ? 0.0 :
                    abs(pseudo[target_band, source_band] - stability.reference_pseudo)
                augmentation_difference =
                    stability === nothing ? 0.0 :
                    abs(augmentation[target_band, source_band] - stability.reference_augmentation)
                cancellation_condition =
                    stability === nothing ?
                    (
                        abs(pseudo[target_band, source_band]) +
                        abs(augmentation[target_band, source_band])
                    ) / max(coupling, eps(Float64)) : stability.cancellation_condition
                maximum_cancellation_condition =
                    max(maximum_cancellation_condition, cancellation_condition)
                item_stability = maximum((
                    production_difference,
                    reverse_difference,
                    compensated_difference,
                    pseudo_difference,
                    augmentation_difference,
                ))
                maximum_cancellation_stability_difference =
                    max(maximum_cancellation_stability_difference, item_stability)
                weighted_policy &&
                    is_far &&
                    item_stability > cancellation_thresholds.accumulation_absolute &&
                    (cancellation_stability_hold = true)
                push!(
                    records,
                    _PAWBlockEvidenceRecord(
                        star_for_kpoint[source_kpoint],
                        representative_for_kpoint[source_kpoint],
                        source_kpoint,
                        target_kpoint,
                        operation_index,
                        canonical_band_operation_key(operations[operation_index]),
                        operations[operation_index].antiunitary,
                        first(workspace) + source_band - 1,
                        first(workspace) + target_band - 1,
                        band_to_cluster[source_band],
                        band_to_cluster[target_band],
                        selected_source_energies[source_band],
                        target_energies[target_band],
                        gap,
                        pseudo[target_band, source_band],
                        augmentation[target_band, source_band],
                        raw[target_band, source_band],
                        classification,
                        pair_residual,
                        cancellation_condition,
                        high_precision_selected,
                        production_difference,
                        reverse_difference,
                        compensated_difference,
                        pseudo_difference,
                        augmentation_difference,
                    ),
                )
            end
            if weighted_policy
                far_source_hamiltonian = Diagonal(ComplexF64.(selected_source_energies))
                far_target_hamiltonian = Diagonal(ComplexF64.(target_energies))
                far_metrics = _star_hamiltonian_residual_metrics(
                    raw,
                    far_source_hamiltonian,
                    far_target_hamiltonian,
                    operations[operation_index].antiunitary;
                    mask = far_mask,
                )
                maximum_far_operator_residual =
                    max(maximum_far_operator_residual, far_metrics.operator_ev)
                maximum_far_source_column_l2_residual = max(
                    maximum_far_source_column_l2_residual,
                    far_metrics.maximum_source_column_l2_ev,
                )
                maximum_far_normalized_frobenius_residual = max(
                    maximum_far_normalized_frobenius_residual,
                    far_metrics.normalized_frobenius_ev,
                )
                maximum_far_frobenius_residual =
                    max(maximum_far_frobenius_residual, far_metrics.frobenius_ev)
                notable_far_metrics = _star_hamiltonian_residual_metrics(
                    raw,
                    far_source_hamiltonian,
                    far_target_hamiltonian,
                    operations[operation_index].antiunitary;
                    mask = notable_far_mask,
                )
                maximum_notable_far_operator_residual =
                    max(maximum_notable_far_operator_residual, notable_far_metrics.operator_ev)
                maximum_notable_far_source_column_l2_residual = max(
                    maximum_notable_far_source_column_l2_residual,
                    notable_far_metrics.maximum_source_column_l2_ev,
                )
                maximum_notable_far_normalized_frobenius_residual = max(
                    maximum_notable_far_normalized_frobenius_residual,
                    notable_far_metrics.normalized_frobenius_ev,
                )
                maximum_notable_far_frobenius_residual =
                    max(maximum_notable_far_frobenius_residual, notable_far_metrics.frobenius_ev)
                far_metrics.operator_ev > residual_thresholds.operator_ev &&
                    (cumulative_residual_hold = true)
                far_metrics.maximum_source_column_l2_ev > residual_thresholds.source_column_l2_ev &&
                    (cumulative_residual_hold = true)
                far_metrics.normalized_frobenius_ev > residual_thresholds.normalized_frobenius_ev &&
                    (cumulative_residual_hold = true)
            end
        end
    end
    sort!(
        records;
        by = record -> (
            record.source_kpoint,
            record.operation_index,
            record.target_native_band,
            record.source_native_band,
        ),
    )
    high_precision_records = filter(record -> record.high_precision_audited, records)
    high_precision_unitary_count = count(record -> !record.antiunitary, high_precision_records)
    high_precision_antiunitary_count = count(record -> record.antiunitary, high_precision_records)
    maximum_high_precision_cancellation_condition =
        isempty(high_precision_records) ? 0.0 :
        maximum(record.cancellation_condition for record in high_precision_records)
    product_table = build_representation_product_table(operations, native.spinor)
    inverse_operations = zeros(Int, length(operations))
    for operation_index in eachindex(operations)
        candidates = findall(eachindex(operations)) do candidate
            product_table.product_indices[operation_index, candidate] == product_table.identity_index &&
                product_table.product_indices[candidate, operation_index] ==
                product_table.identity_index
        end
        length(candidates) == 1 ||
            throw(ArgumentError("PAW_CANCELLATION_STABILITY_HOLD: operation inverse is ambiguous"))
        inverse_operations[operation_index] = only(candidates)
    end
    record_lookup = Dict(
        (
            record.source_kpoint,
            record.target_kpoint,
            record.operation_index,
            record.source_native_band,
            record.target_native_band,
        ) => record for record in records
    )
    inverse_differences = Float64[]
    inverse_missing_count = 0
    for record in high_precision_records
        key = (
            record.target_kpoint,
            record.source_kpoint,
            inverse_operations[record.operation_index],
            record.target_native_band,
            record.source_native_band,
        )
        counterpart = get(record_lookup, key, nothing)
        if counterpart === nothing
            inverse_missing_count += 1
        else
            push!(inverse_differences, abs(abs(record.paw) - abs(counterpart.paw)))
        end
    end
    maximum_inverse_operation_absolute_difference =
        isempty(inverse_differences) ? 0.0 : maximum(inverse_differences)
    inverse_missing_count == 0 || (cancellation_stability_hold = true)
    maximum_inverse_operation_absolute_difference > cancellation_thresholds.inverse_absolute &&
        (cancellation_stability_hold = true)
    high_precision_orbits = unique(
        (
            record.star,
            min(record.source_native_band, record.target_native_band),
            max(record.source_native_band, record.target_native_band),
        ) for record in high_precision_records
    )
    maximum_equivalent_orbit_reference_difference = maximum(
        (
            maximum((
                record.production_absolute_difference,
                record.reverse_absolute_difference,
                record.compensated_absolute_difference,
                record.pseudo_absolute_difference,
                record.augmentation_absolute_difference,
            )) for record in high_precision_records
        );
        init = 0.0,
    )
    maximum_equivalent_orbit_reference_difference > cancellation_thresholds.orbit_absolute &&
        (cancellation_stability_hold = true)
    notable_indices =
        findall(record -> abs(record.paw) > thresholds.nondegenerate_block_leakage, records)
    notable_records = records[notable_indices]
    legacy_records = filter(
        record ->
            record.gap_ev > hamiltonian_policy.near_gap_ev &&
            abs(record.paw) > thresholds.nondegenerate_block_leakage,
        records,
    )
    component_labels = zeros(Int, length(records))
    orbit_labels = zeros(Int, length(records))
    notable_component_labels, notable_orbit_labels = _paw_audit_component_labels(notable_records)
    component_labels[notable_indices] .= notable_component_labels
    orbit_labels[notable_indices] .= notable_orbit_labels
    legacy_component_labels, _ = _paw_audit_component_labels(legacy_records)
    component_weights = Float64[]
    component_band_maximum = 0
    component_span_maximum = 0.0
    for label in unique(legacy_component_labels)
        component = legacy_records[findall(==(label), legacy_component_labels)]
        push!(component_weights, sum(abs2(record.paw) for record in component))
        bands = unique(
            vcat(
                [record.source_native_band for record in component],
                [record.target_native_band for record in component],
            ),
        )
        energies = vcat(
            [record.source_energy_ev for record in component],
            [record.target_energy_ev for record in component],
        )
        component_band_maximum = max(component_band_maximum, length(bands))
        component_span_maximum = max(component_span_maximum, maximum(energies) - minimum(energies))
    end
    coverage = Dict(
        "n50" => _paw_audit_weight_coverage(component_weights, 0.50),
        "n90" => _paw_audit_weight_coverage(component_weights, 0.90),
        "n95" => _paw_audit_weight_coverage(component_weights, 0.95),
        "n99" => _paw_audit_weight_coverage(component_weights, 0.99),
    )
    maximum_gap =
        isempty(legacy_records) ? 0.0 : maximum(record.gap_ev for record in legacy_records)
    maximum_coupling =
        isempty(legacy_records) ? 0.0 : maximum(abs(record.paw) for record in legacy_records)
    pattern =
        coverage["n95"] <= 4 &&
        maximum_gap <= 0.100 &&
        component_span_maximum <= 0.100 &&
        component_band_maximum <= 12 ? :LOCALIZED_CLUSTER_PATTERN : :DISTRIBUTED_REMOTE_MIXING
    lanes = [_paw_audit_fixed_lane(notable_records, cap) for cap in config.fixed_gap_scan_ev]
    root_cause = if cancellation_stability_hold
        :PAW_CANCELLATION_STABILITY_HOLD
    elseif pair_residual_hold
        :FAR_BAND_PAIR_RESIDUAL_HOLD
    elseif cumulative_residual_hold &&
           weighted_policy &&
           weighted_partition_policy.pre_gauge_cumulative_mode == :diagnostic
        :PRE_GAUGE_FAR_BAND_CUMULATIVE_DIAGNOSTIC_EXCEEDED
    elseif cumulative_residual_hold
        :FAR_BAND_CUMULATIVE_RESIDUAL_HOLD
    elseif weighted_policy
        :HAMILTONIAN_WEIGHTED_FAR_BAND_ACCEPTANCE_SUPPORTED
    else
        pattern
    end
    input_sha256 = merge(
        raw_native.input_sha256,
        _star_input_audit_hash(config, raw_native.input_sha256, length(operations)),
    )
    summary = Dict{String, Any}(
        "status" => "DIAGNOSTIC_ONLY",
        "production_eligible" => false,
        "source_kpoint_count" => length(selected_kpoints),
        "operation_count" => length(operations),
        "block_partition_policy" =>
            paw_block_partition_policy_key(config.block_partition_policy),
        "pre_gauge_far_cumulative_mode" =>
            weighted_policy ? string(weighted_partition_policy.pre_gauge_cumulative_mode) :
            "not_applicable",
        "pre_gauge_far_cumulative_status" =>
            cumulative_residual_hold ?
            (
                weighted_policy &&
                weighted_partition_policy.pre_gauge_cumulative_mode == :diagnostic ?
                "DIAGNOSTIC_EXCEEDED_CONTINUE_TO_POST_GAUGE" : "HOLD"
            ) : "PASS",
        "record_count" => length(records),
        "evidence_count" => length(notable_records),
        "violation_count" => length(legacy_records),
        "far_residual_count" => far_residual_count,
        "tolerated_far_residual_count" => tolerated_far_residual_count,
        "total_far_cross_cluster_count" => total_far_cross_cluster_count,
        "maximum_pair_hamiltonian_residual_ev" => maximum_far_pair_residual,
        "maximum_far_operator_residual_ev" => maximum_far_operator_residual,
        "maximum_far_source_column_l2_residual_ev" => maximum_far_source_column_l2_residual,
        "maximum_far_normalized_frobenius_residual_ev" =>
            maximum_far_normalized_frobenius_residual,
        "maximum_far_frobenius_residual_ev" => maximum_far_frobenius_residual,
        "diagnostic_notable_far_operator_residual_ev" => maximum_notable_far_operator_residual,
        "diagnostic_notable_far_source_column_l2_residual_ev" =>
            maximum_notable_far_source_column_l2_residual,
        "diagnostic_notable_far_normalized_frobenius_residual_ev" =>
            maximum_notable_far_normalized_frobenius_residual,
        "diagnostic_notable_far_frobenius_residual_ev" =>
            maximum_notable_far_frobenius_residual,
        "maximum_cancellation_condition" => maximum_cancellation_condition,
        "high_precision_audit_count" => length(high_precision_records),
        "high_precision_unitary_count" => high_precision_unitary_count,
        "high_precision_antiunitary_count" => high_precision_antiunitary_count,
        "maximum_high_precision_cancellation_condition" =>
            maximum_high_precision_cancellation_condition,
        "inverse_operation_high_precision_coverage_count" => length(inverse_differences),
        "inverse_operation_missing_count" => inverse_missing_count,
        "maximum_inverse_operation_absolute_difference" =>
            maximum_inverse_operation_absolute_difference,
        "equivalent_edge_orbit_high_precision_coverage_count" => length(high_precision_orbits),
        "maximum_equivalent_orbit_reference_absolute_difference" =>
            maximum_equivalent_orbit_reference_difference,
        "maximum_cancellation_stability_absolute_difference" =>
            maximum_cancellation_stability_difference,
        "far_band_pair_gate_ev" => residual_thresholds.pair_ev,
        "far_band_operator_gate_ev" => residual_thresholds.operator_ev,
        "far_band_source_column_l2_gate_ev" => residual_thresholds.source_column_l2_ev,
        "far_band_normalized_frobenius_gate_ev" => residual_thresholds.normalized_frobenius_ev,
        "cancellation_accumulation_absolute_gate" =>
            cancellation_thresholds.accumulation_absolute,
        "cancellation_reference_precision_bits" =>
            cancellation_thresholds.bigfloat_precision_bits,
        "root_cause" => String(root_cause),
        "maximum_gap_ev" => maximum_gap,
        "maximum_coupling" => maximum_coupling,
        "maximum_component_bands" => component_band_maximum,
        "maximum_component_span_ev" => component_span_maximum,
        "pattern_classification" => String(pattern),
        "n50" => coverage["n50"],
        "n90" => coverage["n90"],
        "n95" => coverage["n95"],
        "n99" => coverage["n99"],
        "native_generalized_norm_residual" => native_norm,
        "native_generalized_norm_worst" => repr(native_norm_worst),
        "lowdin_norm_before" => lowdin.maximum_before,
        "lowdin_norm_after" => lowdin.maximum_after,
        "maximum_reconstruction_leakage_amplitude_audit" => maximum_reconstruction,
        "maximum_state_leakage_amplitude_audit" => maximum_target_leakage,
        "maximum_raw_unitarity" => maximum_raw_unitarity,
        "maximum_normalized_polar_correction" => maximum_polar_correction,
        "maximum_hamiltonian_covariance_before_ev" => maximum_hamiltonian_covariance,
        "maximum_hamiltonian_covariance_before_operator_ev" => maximum_hamiltonian_operator,
        "maximum_hamiltonian_covariance_before_source_column_l2_ev" =>
            maximum_hamiltonian_source_column_l2,
        "maximum_hamiltonian_covariance_before_normalized_frobenius_ev" =>
            maximum_hamiltonian_normalized_frobenius,
        "maximum_hamiltonian_covariance_before_frobenius_ev" => maximum_hamiltonian_frobenius,
        "fixed_gap_physics_metrics_status" => "PARTITION_GRAPH_AND_NATIVE_PREGAUGE_ONLY",
        "sawf_started" => false,
        "z_status" => "NOT_RUN_USER_SCOPED",
        "u_status" => "NOT_RUN_USER_SCOPED",
        "tb_status" => "NOT_RUN_USER_SCOPED",
        "bands_status" => "NOT_RUN_USER_SCOPED",
        "fixed_gap_scan" =>
            [Dict(string(key) => value for (key, value) in pairs(lane)) for lane in lanes],
        "input_sha256" => input_sha256,
    )
    _write_paw_block_partition_audit_hdf5(
        config.output_hdf5,
        records,
        component_labels,
        orbit_labels,
        lanes,
        summary,
        input_sha256,
    )
    _write_paw_block_partition_audit_csv(config.output_csv, records, component_labels, orbit_labels)
    temporary_json = config.output_json * ".tmp"
    mkpath(dirname(config.output_json))
    open(temporary_json, "w") do io
        JSON3.pretty(io, summary)
        write(io, '\n')
    end
    mv(temporary_json, config.output_json; force = true)
    return PAWBlockPartitionAuditResult(
        :DIAGNOSTIC_ONLY,
        root_cause,
        config.output_hdf5,
        config.output_csv,
        config.output_json,
        length(legacy_records),
        maximum_gap,
        maximum_coupling,
        pattern,
        Dict(string(key) => string(value) for (key, value) in input_sha256),
        String[],
        far_residual_count,
        tolerated_far_residual_count,
        maximum_far_pair_residual,
        maximum_far_operator_residual,
        maximum_far_source_column_l2_residual,
        maximum_far_normalized_frobenius_residual,
        maximum_far_frobenius_residual,
        maximum_cancellation_condition,
    )
end
