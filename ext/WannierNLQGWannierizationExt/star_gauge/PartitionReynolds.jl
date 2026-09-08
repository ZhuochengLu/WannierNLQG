"""Internal evidence and closure summary for one k-star block partition."""
struct _StarBlockPartitionDecision
    blocks::Vector{Vector{Int}}
    policy_key::String
    evidence_count::Int
    evidence_orbit_count::Int
    search_states::Int
    maximum_evidence_gap_ev::Float64
    maximum_evidence_coupling::Float64
    maximum_block_span_ev::Float64
    maximum_block_bands::Int
    far_residual_count::Int
    tolerated_far_residual_count::Int
    maximum_pair_hamiltonian_residual_ev::Float64
    maximum_far_operator_residual_ev::Float64
    maximum_far_source_column_l2_residual_ev::Float64
    maximum_far_normalized_frobenius_residual_ev::Float64
    maximum_far_frobenius_residual_ev::Float64
    maximum_far_band_coupling::Float64
    pre_gauge_far_cumulative_status::Symbol
    pre_gauge_far_cumulative_worst_context::String
end

"""
Return dimension-stable norms of `R = H_target * B - B * H_source_action`.

When `mask` is supplied, only the selected matrix elements contribute. The
unscaled Frobenius norm is retained for audit but is deliberately not a
dimension-stable qualification metric.
"""
function _star_hamiltonian_residual_metrics(
    sewing::AbstractMatrix{<:Complex},
    source_hamiltonian::AbstractMatrix{<:Number},
    target_hamiltonian::AbstractMatrix{<:Number},
    antiunitary::Bool;
    mask::Union{Nothing, AbstractMatrix{Bool}} = nothing,
)
    source_action = antiunitary ? conj(source_hamiltonian) : source_hamiltonian
    residual = Matrix{ComplexF64}(target_hamiltonian * sewing - sewing * source_action)
    if mask !== nothing
        residual .*= mask
    end
    source_column_l2 = sqrt.(vec(sum(abs2, residual; dims = 1)))
    frobenius = norm(residual)
    source_count = size(residual, 2)
    return (
        residual = residual,
        maximum_element_ev = maximum(abs, residual; init = 0.0),
        frobenius_ev = frobenius,
        normalized_frobenius_ev = frobenius / sqrt(source_count),
        operator_ev = opnorm(residual),
        maximum_source_column_l2_ev = maximum(source_column_l2; init = 0.0),
    )
end

# Classify every cross-cluster entry for the Hamiltonian-weighted far-band policy.
function _star_hamiltonian_weighted_partition_data(
    raw_transports::Vector{Matrix{ComplexF64}},
    source_energies::Vector{Float64},
    buffer_policy::ClosureDrivenBandBuffer,
    thresholds::PAWGaugeThresholds,
    partition_policy::HamiltonianWeightedPAWBlockPartition,
    target_energies::Vector{Vector{Float64}},
    antiunitary_transports::AbstractVector{Bool} = falses(length(raw_transports)),
    pair_mode::Symbol = :fail_stop,
)
    pair_mode in (:fail_stop, :diagnostic) ||
        throw(ArgumentError("far-band pair mode must be :fail_stop or :diagnostic"))
    length(target_energies) == length(raw_transports) ||
        throw(ArgumentError("PAW_GAUGE_BLOCK_ENERGY_DIMENSION_MISMATCH"))
    length(antiunitary_transports) == length(raw_transports) ||
        throw(ArgumentError("PAW_GAUGE_BLOCK_ANTIUNITARY_DIMENSION_MISMATCH"))
    clusters = _star_energy_clusters(source_energies, buffer_policy.cluster_tolerance_ev)
    band_to_cluster = zeros(Int, length(source_energies))
    for (cluster_index, cluster) in enumerate(clusters)
        band_to_cluster[cluster] .= cluster_index
    end
    near_evidence = NamedTuple[]
    far_notable = NamedTuple[]
    pair_failures = NamedTuple[]
    maximum_pair = 0.0
    maximum_operator = 0.0
    maximum_source_column_l2 = 0.0
    maximum_normalized_frobenius = 0.0
    maximum_frobenius = 0.0
    maximum_far_coupling = 0.0
    tolerated_far_count = 0
    cumulative_contexts = Dict(
        :operator_ev => "NOT_RECORDED",
        :source_column_l2_ev => "NOT_RECORDED",
        :normalized_frobenius_ev => "NOT_RECORDED",
    )
    residual_thresholds = partition_policy.residual_thresholds
    for (transport_index, raw) in enumerate(raw_transports)
        energies_target = target_energies[transport_index]
        length(energies_target) == length(source_energies) ||
            throw(ArgumentError("PAW_GAUGE_BLOCK_ENERGY_DIMENSION_MISMATCH"))
        far_mask = falses(size(raw))
        for target in axes(raw, 1), source in axes(raw, 2)
            left = band_to_cluster[target]
            right = band_to_cluster[source]
            left == right && continue
            coupling = abs(raw[target, source])
            signed_gap = energies_target[target] - source_energies[source]
            gap = abs(signed_gap)
            if gap <= partition_policy.near_gap_ev
                coupling <= thresholds.nondegenerate_block_leakage && continue
                push!(
                    near_evidence,
                    (
                        coupling = coupling,
                        gap_ev = gap,
                        hamiltonian_residual_ev = abs(signed_gap * raw[target, source]),
                        transport_index = transport_index,
                        target_band = target,
                        source_band = source,
                        left_cluster = left,
                        right_cluster = right,
                        classification = :MERGE_REQUIRED_NEAR_DEGENERATE,
                    ),
                )
            else
                far_mask[target, source] = true
                residual = abs(signed_gap * raw[target, source])
                maximum_pair = max(maximum_pair, residual)
                maximum_far_coupling = max(maximum_far_coupling, coupling)
                if coupling > thresholds.nondegenerate_block_leakage ||
                   residual > residual_thresholds.pair_ev
                    residual <= residual_thresholds.pair_ev && (tolerated_far_count += 1)
                    record = (
                        coupling = coupling,
                        gap_ev = gap,
                        hamiltonian_residual_ev = residual,
                        transport_index = transport_index,
                        target_band = target,
                        source_band = source,
                        left_cluster = left,
                        right_cluster = right,
                        classification = residual <= residual_thresholds.pair_ev ?
                                         :TOLERATED_FAR_BAND_RESIDUAL :
                                         :FAR_BAND_PAIR_RESIDUAL_HOLD,
                    )
                    push!(far_notable, record)
                    residual <= residual_thresholds.pair_ev || push!(pair_failures, record)
                end
            end
        end
        source_hamiltonian = Diagonal(source_energies)
        target_hamiltonian = Diagonal(energies_target)
        metrics = _star_hamiltonian_residual_metrics(
            raw,
            source_hamiltonian,
            target_hamiltonian,
            antiunitary_transports[transport_index];
            mask = far_mask,
        )
        if metrics.operator_ev > maximum_operator
            maximum_operator = metrics.operator_ev
            cumulative_contexts[:operator_ev] = "transport=$(transport_index)"
        end
        if metrics.maximum_source_column_l2_ev > maximum_source_column_l2
            maximum_source_column_l2 = metrics.maximum_source_column_l2_ev
            column_norms = sqrt.(vec(sum(abs2, metrics.residual; dims = 1)))
            source = argmax(column_norms)
            cumulative_contexts[:source_column_l2_ev] = "transport=$(transport_index),source=$(source)"
        end
        if metrics.normalized_frobenius_ev > maximum_normalized_frobenius
            maximum_normalized_frobenius = metrics.normalized_frobenius_ev
            cumulative_contexts[:normalized_frobenius_ev] = "transport=$(transport_index)"
        end
        maximum_frobenius = max(maximum_frobenius, metrics.frobenius_ev)
    end
    pair_mode == :fail_stop &&
        !isempty(pair_failures) &&
        begin
            violation = first(sort(pair_failures; by = item -> -item.hamiltonian_residual_ev))
            throw(
                ArgumentError(
                    "FAR_BAND_PAIR_RESIDUAL_HOLD: residual=$(violation.hamiltonian_residual_ev) " *
                    "eV exceeds $(residual_thresholds.pair_ev) at " *
                    "transport=$(violation.transport_index), target=$(violation.target_band), " *
                    "source=$(violation.source_band), gap=$(violation.gap_ev) eV",
                ),
            )
        end
    aggregate = (
        operator_ev = maximum_operator,
        source_column_l2_ev = maximum_source_column_l2,
        normalized_frobenius_ev = maximum_normalized_frobenius,
    )
    limits = (
        operator_ev = residual_thresholds.operator_ev,
        source_column_l2_ev = residual_thresholds.source_column_l2_ev,
        normalized_frobenius_ev = residual_thresholds.normalized_frobenius_ev,
    )
    cumulative_violations = [
        (
            name = name,
            value = getfield(aggregate, name),
            limit = getfield(limits, name),
            ratio = getfield(aggregate, name) / getfield(limits, name),
            context = cumulative_contexts[name],
        ) for name in keys(aggregate) if getfield(aggregate, name) > getfield(limits, name)
    ]
    sort!(cumulative_violations; by = item -> (-item.ratio, item.name))
    cumulative_status =
        !isempty(pair_failures) ? :DIAGNOSTIC_PAIR_EXCEEDED_CONTINUE_TO_CONTROLLED_SYMMETRIZATION :
        isempty(cumulative_violations) ? :PASS : :DIAGNOSTIC_EXCEEDED_CONTINUE_TO_POST_GAUGE
    cumulative_worst_context = if isempty(cumulative_violations)
        isempty(pair_failures) ? "PASS" :
        begin
            worst = first(sort(pair_failures; by = item -> -item.hamiltonian_residual_ev))
            "pair=$(worst.hamiltonian_residual_ev) eV exceeds $(residual_thresholds.pair_ev); " *
            "transport=$(worst.transport_index),target=$(worst.target_band)," *
            "source=$(worst.source_band),gap=$(worst.gap_ev) eV"
        end
    else
        worst = first(cumulative_violations)
        "$(worst.name)=$(worst.value) eV exceeds $(worst.limit); $(worst.context)"
    end
    if partition_policy.pre_gauge_cumulative_mode == :fail_stop && !isempty(cumulative_violations)
        worst = first(cumulative_violations)
        throw(
            ArgumentError(
                "FAR_BAND_CUMULATIVE_RESIDUAL_HOLD: $(worst.name)=$(worst.value) eV " *
                "exceeds $(worst.limit); $(worst.context)",
            ),
        )
    end
    sort!(
        near_evidence;
        by = item ->
            (-item.coupling, item.gap_ev, item.transport_index, item.target_band, item.source_band),
    )
    sort!(
        far_notable;
        by = item -> (
            -item.hamiltonian_residual_ev,
            -item.coupling,
            item.transport_index,
            item.target_band,
            item.source_band,
        ),
    )
    return (
        clusters = clusters,
        near_evidence = near_evidence,
        far_notable = far_notable,
        tolerated_far_count = tolerated_far_count,
        maximum_pair_hamiltonian_residual_ev = maximum_pair,
        maximum_far_operator_residual_ev = maximum_operator,
        maximum_far_source_column_l2_residual_ev = maximum_source_column_l2,
        maximum_far_normalized_frobenius_residual_ev = maximum_normalized_frobenius,
        maximum_far_frobenius_residual_ev = maximum_frobenius,
        maximum_far_band_coupling = maximum_far_coupling,
        pre_gauge_far_cumulative_status = cumulative_status,
        pre_gauge_far_cumulative_worst_context = cumulative_worst_context,
    )
end

# Build the initial energy clusters and above-threshold cross-cluster evidence.
function _star_block_partition_evidence(
    raw_transports::Vector{Matrix{ComplexF64}},
    source_energies::Vector{Float64},
    policy::ClosureDrivenBandBuffer,
    thresholds::PAWGaugeThresholds,
    target_energies::Vector{Vector{Float64}} = fill(source_energies, length(raw_transports)),
)
    length(target_energies) == length(raw_transports) ||
        throw(ArgumentError("PAW_GAUGE_BLOCK_ENERGY_DIMENSION_MISMATCH"))
    all(length(energies) == length(source_energies) for energies in target_energies) ||
        throw(ArgumentError("PAW_GAUGE_BLOCK_ENERGY_DIMENSION_MISMATCH"))
    clusters = _star_energy_clusters(source_energies, policy.cluster_tolerance_ev)
    band_to_cluster = zeros(Int, length(source_energies))
    for (cluster_index, cluster) in enumerate(clusters)
        band_to_cluster[cluster] .= cluster_index
    end
    evidence = NamedTuple[]
    for (transport_index, raw) in enumerate(raw_transports),
        target in axes(raw, 1),
        source in axes(raw, 2)

        left = band_to_cluster[target]
        right = band_to_cluster[source]
        left == right && continue
        coupling = abs(raw[target, source])
        coupling <= thresholds.nondegenerate_block_leakage && continue
        gap = abs(target_energies[transport_index][target] - source_energies[source])
        push!(
            evidence,
            (
                coupling = coupling,
                gap_ev = gap,
                transport_index = transport_index,
                target_band = target,
                source_band = source,
                left_cluster = left,
                right_cluster = right,
            ),
        )
    end
    sort!(
        evidence;
        by = item ->
            (-item.coupling, item.gap_ev, item.transport_index, item.target_band, item.source_band),
    )
    return clusters, evidence
end

# Convert a cluster union into deterministic band-index blocks and summary limits.
function _star_partition_from_edges(
    clusters::Vector{UnitRange{Int}},
    source_energies::Vector{Float64},
    edges,
)
    parent = collect(1:length(clusters))
    find_root(index) = begin
        while parent[index] != index
            parent[index] = parent[parent[index]]
            index = parent[index]
        end
        index
    end
    function union_roots(left, right)
        left_root = find_root(left)
        right_root = find_root(right)
        left_root == right_root || (parent[right_root] = left_root)
        return nothing
    end
    for edge in edges
        union_roots(edge.left_cluster, edge.right_cluster)
    end
    groups = Dict{Int, Vector{Int}}()
    for (cluster_index, cluster) in enumerate(clusters)
        append!(get!(groups, find_root(cluster_index), Int[]), cluster)
    end
    blocks = sort!(collect(values(groups)); by = first)
    maximum_span =
        maximum(block -> source_energies[last(block)] - source_energies[first(block)], blocks)
    maximum_bands = maximum(length, blocks)
    return blocks, maximum_span, maximum_bands
end

# Preserve the frozen fixed-gap behavior exactly, including its fail-first context.
function _star_block_partition_decision(
    raw_transports::Vector{Matrix{ComplexF64}},
    source_energies::Vector{Float64},
    buffer_policy::ClosureDrivenBandBuffer,
    thresholds::PAWGaugeThresholds,
    partition_policy::FixedGapPAWBlockPartition,
    target_energies::Vector{Vector{Float64}} = fill(source_energies, length(raw_transports)),
)
    clusters, evidence = _star_block_partition_evidence(
        raw_transports,
        source_energies,
        buffer_policy,
        thresholds,
        target_energies,
    )
    admitted = filter(item -> item.gap_ev <= partition_policy.max_gap_ev, evidence)
    rejected = filter(item -> item.gap_ev > partition_policy.max_gap_ev, evidence)
    if !isempty(rejected)
        violation = first(rejected)
        throw(
            ArgumentError(
                "BLOCK_PARTITION_HOLD: coupling=$(violation.coupling) spans " *
                "$(violation.gap_ev) eV at transport=$(violation.transport_index), " *
                "target=$(violation.target_band), source=$(violation.source_band)",
            ),
        )
    end
    blocks, maximum_span, maximum_bands =
        _star_partition_from_edges(clusters, source_energies, admitted)
    orbits = Set(
        (min(item.left_cluster, item.right_cluster), max(item.left_cluster, item.right_cluster)) for item in admitted
    )
    return _StarBlockPartitionDecision(
        blocks,
        paw_block_partition_policy_key(partition_policy),
        length(evidence),
        length(orbits),
        1,
        isempty(evidence) ? 0.0 : maximum(item.gap_ev for item in evidence),
        isempty(evidence) ? 0.0 : maximum(item.coupling for item in evidence),
        maximum_span,
        maximum_bands,
        0,
        0,
        0.0,
        0.0,
        0.0,
        0.0,
        0.0,
        0.0,
        :NOT_APPLICABLE,
        "NOT_APPLICABLE",
    )
end

# Enumerate admissible adaptive partitions in the registered deterministic
# best-first order.  Edges at or below the soft gap are mandatory.  More remote
# edge orbits are optional because a smaller Reynolds rotation can make their
# apparent native-gauge leakage disappear; their necessity is decided only by
# the physical candidate evaluation below.
function _star_adaptive_partition_candidates(
    raw_transports::Vector{Matrix{ComplexF64}},
    source_energies::Vector{Float64},
    buffer_policy::ClosureDrivenBandBuffer,
    thresholds::PAWGaugeThresholds,
    partition_policy::AdaptiveEvidencePAWBlockPartition,
    target_energies::Vector{Vector{Float64}} = fill(source_energies, length(raw_transports)),
)
    clusters, evidence = _star_block_partition_evidence(
        raw_transports,
        source_energies,
        buffer_policy,
        thresholds,
        target_energies,
    )
    hard = filter(item -> item.gap_ev > partition_policy.hard_edge_gap_ev, evidence)
    if !isempty(hard)
        violation = first(hard)
        throw(
            ArgumentError(
                "BLOCK_PARTITION_HARD_LIMIT_HOLD: coupling=$(violation.coupling) spans " *
                "$(violation.gap_ev) eV beyond hard_edge_gap_ev=" *
                "$(partition_policy.hard_edge_gap_ev) at transport=$(violation.transport_index), " *
                "target=$(violation.target_band), source=$(violation.source_band)",
            ),
        )
    end
    orbit_key(item) =
        (min(item.left_cluster, item.right_cluster), max(item.left_cluster, item.right_cluster))
    orbit_keys = sort!(unique(orbit_key(item) for item in evidence))
    orbit_records =
        Dict(key => filter(item -> orbit_key(item) == key, evidence) for key in orbit_keys)
    mandatory = [
        key for key in orbit_keys if
        any(item -> item.gap_ev <= partition_policy.soft_gap_ev, orbit_records[key])
    ]
    optional = setdiff(orbit_keys, mandatory)

    function make_state(selected_optional::Vector{Int})
        selected_keys = sort!(vcat(mandatory, optional[selected_optional]))
        selected = filter(item -> orbit_key(item) in selected_keys, evidence)
        blocks, maximum_span, maximum_bands =
            _star_partition_from_edges(clusters, source_energies, selected)
        strength = sum((abs2(item.coupling) for item in selected); init = 0.0)
        canonical = join(("$(key[1])-$(key[2])" for key in selected_keys), ";")
        priority = (length(selected_optional), maximum_bands, maximum_span, -strength, canonical)
        return (
            selected_optional = selected_optional,
            selected_keys = selected_keys,
            selected = selected,
            blocks = blocks,
            maximum_span = maximum_span,
            maximum_bands = maximum_bands,
            priority = priority,
        )
    end

    base = make_state(Int[])
    if base.maximum_span > partition_policy.hard_component_span_ev ||
       base.maximum_bands > partition_policy.max_component_bands
        throw(
            ArgumentError(
                "BLOCK_PARTITION_HARD_LIMIT_HOLD: mandatory component has span=" *
                "$(base.maximum_span) eV and bands=$(base.maximum_bands)",
            ),
        )
    end
    queue = [base]
    candidates = _StarBlockPartitionDecision[]
    while !isempty(queue) && length(candidates) < partition_policy.max_search_states
        sort!(queue; by = state -> state.priority)
        state = popfirst!(queue)
        ordinal = length(candidates) + 1
        push!(
            candidates,
            _StarBlockPartitionDecision(
                state.blocks,
                paw_block_partition_policy_key(partition_policy),
                length(evidence),
                length(state.selected_keys),
                ordinal,
                isempty(evidence) ? 0.0 : maximum(item.gap_ev for item in evidence),
                isempty(evidence) ? 0.0 : maximum(item.coupling for item in evidence),
                state.maximum_span,
                state.maximum_bands,
                0,
                0,
                0.0,
                0.0,
                0.0,
                0.0,
                0.0,
                0.0,
                :NOT_APPLICABLE,
                "NOT_APPLICABLE",
            ),
        )
        first_new = isempty(state.selected_optional) ? 1 : last(state.selected_optional) + 1
        for optional_index in first_new:length(optional)
            child = make_state(vcat(state.selected_optional, optional_index))
            child.maximum_span <= partition_policy.hard_component_span_ev || continue
            child.maximum_bands <= partition_policy.max_component_bands || continue
            push!(queue, child)
        end
    end
    return candidates, !isempty(queue)
end

# Form the unique minimal closure of all admissible physical-evidence edge orbits.
function _star_block_partition_decision(
    raw_transports::Vector{Matrix{ComplexF64}},
    source_energies::Vector{Float64},
    buffer_policy::ClosureDrivenBandBuffer,
    thresholds::PAWGaugeThresholds,
    partition_policy::AdaptiveEvidencePAWBlockPartition,
    target_energies::Vector{Vector{Float64}} = fill(source_energies, length(raw_transports)),
)
    clusters, evidence = _star_block_partition_evidence(
        raw_transports,
        source_energies,
        buffer_policy,
        thresholds,
        target_energies,
    )
    hard = filter(item -> item.gap_ev > partition_policy.hard_edge_gap_ev, evidence)
    if !isempty(hard)
        violation = first(hard)
        throw(
            ArgumentError(
                "BLOCK_PARTITION_HARD_LIMIT_HOLD: coupling=$(violation.coupling) spans " *
                "$(violation.gap_ev) eV beyond hard_edge_gap_ev=" *
                "$(partition_policy.hard_edge_gap_ev) at transport=$(violation.transport_index), " *
                "target=$(violation.target_band), source=$(violation.source_band)",
            ),
        )
    end
    orbit_keys = sort!(
        unique(
            (
                min(item.left_cluster, item.right_cluster),
                max(item.left_cluster, item.right_cluster),
            ) for item in evidence
        ),
    )
    search_states = length(orbit_keys) + 1
    search_states <= partition_policy.max_search_states || throw(
        ArgumentError(
            "BLOCK_PARTITION_SEARCH_HOLD: $(search_states) evidence-closure states exceed " *
            "max_search_states=$(partition_policy.max_search_states)",
        ),
    )
    blocks, maximum_span, maximum_bands =
        _star_partition_from_edges(clusters, source_energies, evidence)
    if maximum_span > partition_policy.hard_component_span_ev
        throw(
            ArgumentError(
                "BLOCK_PARTITION_HARD_LIMIT_HOLD: component span=$(maximum_span) eV exceeds " *
                "hard_component_span_ev=$(partition_policy.hard_component_span_ev)",
            ),
        )
    end
    if maximum_bands > partition_policy.max_component_bands
        throw(
            ArgumentError(
                "BLOCK_PARTITION_HARD_LIMIT_HOLD: component bands=$(maximum_bands) exceeds " *
                "max_component_bands=$(partition_policy.max_component_bands)",
            ),
        )
    end
    return _StarBlockPartitionDecision(
        blocks,
        paw_block_partition_policy_key(partition_policy),
        length(evidence),
        length(orbit_keys),
        search_states,
        isempty(evidence) ? 0.0 : maximum(item.gap_ev for item in evidence),
        isempty(evidence) ? 0.0 : maximum(item.coupling for item in evidence),
        maximum_span,
        maximum_bands,
        0,
        0,
        0.0,
        0.0,
        0.0,
        0.0,
        0.0,
        0.0,
        :NOT_APPLICABLE,
        "NOT_APPLICABLE",
    )
end

# Merge only near-degenerate evidence and gate remote entries by Hamiltonian scale.
function _star_block_partition_decision(
    raw_transports::Vector{Matrix{ComplexF64}},
    source_energies::Vector{Float64},
    buffer_policy::ClosureDrivenBandBuffer,
    thresholds::PAWGaugeThresholds,
    partition_policy::HamiltonianWeightedPAWBlockPartition,
    target_energies::Vector{Vector{Float64}} = fill(source_energies, length(raw_transports)),
    antiunitary_transports::AbstractVector{Bool} = falses(length(raw_transports)),
    pair_mode::Symbol = :fail_stop,
)
    data = _star_hamiltonian_weighted_partition_data(
        raw_transports,
        source_energies,
        buffer_policy,
        thresholds,
        partition_policy,
        target_energies,
        antiunitary_transports,
        pair_mode,
    )
    blocks, maximum_span, maximum_bands =
        _star_partition_from_edges(data.clusters, source_energies, data.near_evidence)
    maximum_span <= partition_policy.hard_component_span_ev || throw(
        ArgumentError(
            "BLOCK_PARTITION_HARD_LIMIT_HOLD: near-degenerate component span=" *
            "$(maximum_span) eV exceeds $(partition_policy.hard_component_span_ev)",
        ),
    )
    maximum_bands <= partition_policy.max_component_bands || throw(
        ArgumentError(
            "BLOCK_PARTITION_HARD_LIMIT_HOLD: near-degenerate component bands=" *
            "$(maximum_bands) exceeds $(partition_policy.max_component_bands)",
        ),
    )
    orbits = Set(
        (min(item.left_cluster, item.right_cluster), max(item.left_cluster, item.right_cluster)) for item in data.near_evidence
    )
    maximum_gap = maximum(
        vcat(
            [item.gap_ev for item in data.near_evidence],
            [item.gap_ev for item in data.far_notable],
            [0.0],
        ),
    )
    maximum_coupling = maximum(
        vcat(
            [item.coupling for item in data.near_evidence],
            [item.coupling for item in data.far_notable],
            [0.0],
        ),
    )
    return _StarBlockPartitionDecision(
        blocks,
        paw_block_partition_policy_key(partition_policy),
        length(data.near_evidence) + length(data.far_notable),
        length(orbits),
        1,
        maximum_gap,
        maximum_coupling,
        maximum_span,
        maximum_bands,
        length(data.far_notable),
        data.tolerated_far_count,
        data.maximum_pair_hamiltonian_residual_ev,
        data.maximum_far_operator_residual_ev,
        data.maximum_far_source_column_l2_residual_ev,
        data.maximum_far_normalized_frobenius_residual_ev,
        data.maximum_far_frobenius_residual_ev,
        data.maximum_far_band_coupling,
        data.pre_gauge_far_cumulative_status,
        data.pre_gauge_far_cumulative_worst_context,
    )
end

# Compatibility entrypoint used by the frozen fixed-gap tests and local oracle.
function _star_merged_blocks(
    raw_transports::Vector{Matrix{ComplexF64}},
    source_energies::Vector{Float64},
    policy::ClosureDrivenBandBuffer,
    thresholds::PAWGaugeThresholds,
    target_energies::Vector{Vector{Float64}} = fill(source_energies, length(raw_transports)),
)
    partition = FixedGapPAWBlockPartition(max_gap_ev = thresholds.block_merge_max_gap_ev)
    return _star_block_partition_decision(
        raw_transports,
        source_energies,
        policy,
        thresholds,
        partition,
        target_energies,
    ).blocks
end

# Reynolds-average target Hamiltonians after transporting them into one
# representative frame.  For antiunitary operations, the pulled-back matrix is
# complex-conjugated because the source coefficients transform antilinearly.
function _star_reynolds_hamiltonian(
    polar_transports::Vector{Matrix{ComplexF64}},
    target_hamiltonians::Vector{Matrix{ComplexF64}},
    antiunitary::Vector{Bool},
)
    count = length(polar_transports)
    count > 0 || throw(ArgumentError("PAW_GAUGE_EMPTY_REYNOLDS_AVERAGE"))
    length(target_hamiltonians) == count && length(antiunitary) == count ||
        throw(ArgumentError("PAW_GAUGE_REYNOLDS_DIMENSION_MISMATCH"))
    dimension = size(first(polar_transports), 1)
    average = zeros(ComplexF64, dimension, dimension)
    for index in 1:count
        polar = polar_transports[index]
        target = target_hamiltonians[index]
        size(polar) == (dimension, dimension) && size(target) == (dimension, dimension) ||
            throw(ArgumentError("PAW_GAUGE_REYNOLDS_DIMENSION_MISMATCH"))
        pulled = polar' * target * polar
        antiunitary[index] && (pulled = conj(pulled))
        average .+= pulled
    end
    average ./= count
    average .= 0.5 .* (average + average')
    return average
end

# Return the exact outer-window band indices for every point in one complete
# k-star.  The indices remain parent-band indices; the parent workspace is not
# allowed to redefine or pad the target authority.
function _star_target_indices_by_kpoint(
    contract::TargetSubspaceQualificationContract,
    star::AbstractVector{<:Integer},
    workspace::UnitRange{Int},
)
    scope = contract.qualification_scope
    indices = Dict{Int, Vector{Int}}()
    required_rank = 0
    for kpoint in star
        target = findall(@view(scope.outer_mask[:, kpoint]))
        isempty(target) &&
            throw(ArgumentError("TARGET_MASK_RANK_HOLD: empty outer authority at k=$(kpoint)"))
        all(index -> index in workspace, target) || throw(
            ArgumentError(
                "TARGET_MASK_MAPPING_HOLD: outer authority at k=$(kpoint) is outside workspace $(workspace)",
            ),
        )
        if required_rank == 0
            required_rank = length(target)
        elseif length(target) != required_rank
            throw(
                ArgumentError(
                    "TARGET_MASK_MAPPING_HOLD: outer ranks differ inside one k-star " *
                    "($(required_rank) and $(length(target)))",
                ),
            )
        end
        indices[Int(kpoint)] = target
    end
    return indices
end

# Push one Hermitian target Hamiltonian through a unitary or antiunitary band
# action D: source -> target.
function _star_target_hamiltonian_pushforward(
    action::AbstractMatrix{<:Complex},
    source::AbstractMatrix{<:Number},
    antiunitary::Bool,
)
    transformed_source = antiunitary ? conj(source) : source
    pushed = action * transformed_source * action'
    return Matrix{ComplexF64}(Hermitian(0.5 .* (pushed + pushed')))
end

# Pull one Hermitian target Hamiltonian back through a unitary or antiunitary
# band action D: source -> target.
function _star_target_hamiltonian_pullback(
    action::AbstractMatrix{<:Complex},
    target::AbstractMatrix{<:Number},
    antiunitary::Bool,
)
    pulled = action' * target * action
    antiunitary && (pulled = conj(pulled))
    return Matrix{ComplexF64}(Hermitian(0.5 .* (pulled + pulled')))
end

# Return the worst operator-norm covariance residual of one target Hamiltonian
# field under a set of formal unitary/corepresentation actions.
function _star_target_field_covariance_residual(
    field::AbstractDict{Int, <:AbstractMatrix},
    actions::AbstractDict{Tuple{Int, Int}, <:AbstractMatrix},
    operations::Vector{SymmetryOperation},
    kpoint_map::Matrix{Int},
)
    maximum_residual = 0.0
    worst_context = "NOT_RECORDED"
    for source in sort!(collect(keys(field))), operation_index in eachindex(operations)
        target = kpoint_map[operation_index, source]
        haskey(field, target) || continue
        action = actions[(source, operation_index)]
        source_action =
            operations[operation_index].antiunitary ? conj(field[source]) : field[source]
        residual = field[target] * action - action * source_action
        value = opnorm(residual)
        if value > maximum_residual
            maximum_residual = value
            worst_context = "source=$(source),target=$(target),op=$(operation_index)"
        end
    end
    return maximum_residual, worst_context
end

# Return the exact projective/corepresentation factor for one ordered operation
# product at one source k point.
function _star_target_action_group_factor(
    native::NativeWavefunctionData,
    product_table::RepresentationProductTable,
    left_index::Int,
    right_index::Int,
    source::Int,
    kpoint_map::Matrix{Int},
)
    intermediate = kpoint_map[right_index, source]
    product_index = product_table.product_indices[left_index, right_index]
    product_index > 0 || throw(
        ArgumentError(
            "FORMAL_TARGET_REPRESENTATION_HOLD: operation product is absent for " *
            "left=$(left_index),right=$(right_index)",
        ),
    )
    composed_target = kpoint_map[left_index, intermediate]
    product_target = kpoint_map[product_index, source]
    composed_target == product_target || throw(
        ArgumentError(
            "FORMAL_TARGET_REPRESENTATION_HOLD: operation product does not compose on the " *
            "k mesh for source=$(source),left=$(left_index),right=$(right_index)",
        ),
    )
    lattice_translation = @view product_table.translation_differences[:, left_index, right_index]
    product_k = native.kpoints[product_target].k_fractional
    phase = cis(-2.0 * pi * dot(product_k, lattice_translation))
    factor = product_table.spinor_factors[left_index, right_index] * phase
    return factor, intermediate, product_index, product_target
end

# Measure the exact finite-group law of target actions, including projective
# spinor sign, reciprocal phase, and antiunitary conjugation.
function _star_target_action_group_residual(
    actions::AbstractDict{Tuple{Int, Int}, <:AbstractMatrix},
    native::NativeWavefunctionData,
    star::AbstractVector{<:Integer},
    operations::Vector{SymmetryOperation},
    kpoint_map::Matrix{Int},
    product_table::RepresentationProductTable,
)
    channel_residuals = zeros(Float64, 4)
    maximum_residual = 0.0
    maximum_theta_squared = 0.0
    worst_context = "NOT_RECORDED"
    theta_index = product_table.theta_index
    for source in sort!(Int.(collect(star))),
        left_index in eachindex(operations),
        right_index in eachindex(operations)

        factor, intermediate, product_index, _ = _star_target_action_group_factor(
            native,
            product_table,
            left_index,
            right_index,
            source,
            kpoint_map,
        )
        haskey(actions, (intermediate, left_index)) &&
        haskey(actions, (source, right_index)) &&
        haskey(actions, (source, product_index)) || throw(
            ArgumentError(
                "FORMAL_TARGET_REPRESENTATION_HOLD: target action inventory is incomplete",
            ),
        )
        left = actions[(intermediate, left_index)]
        right = actions[(source, right_index)]
        operations[left_index].antiunitary && (right = conj(right))
        product = actions[(source, product_index)]
        residual = maximum(abs, left * right - factor .* product)
        channel = group_law_combination_index(
            operations[left_index].antiunitary,
            operations[right_index].antiunitary,
        )
        channel_residuals[channel] = max(channel_residuals[channel], residual)
        if residual > maximum_residual
            maximum_residual = residual
            worst_context =
                "source=$(source),left=$(left_index),right=$(right_index)," *
                "product=$(product_index)"
        end
        if theta_index !== nothing && left_index == theta_index && right_index == theta_index
            maximum_theta_squared = max(maximum_theta_squared, residual)
        end
    end
    corepresentation_residual = maximum(@view(channel_residuals[2:4]); init = 0.0)
    return (
        maximum = maximum_residual,
        channels = Tuple(channel_residuals),
        corepresentation = corepresentation_residual,
        theta_squared = maximum_theta_squared,
        kramers = maximum_theta_squared,
        context = worst_context,
    )
end

# Synchronize a near-representation by averaging the stable finite-group ratio
# D_g(k) = <f(g,h,x) D_gh(x) C_g(D_h(x))^-1>_h followed by polar retraction.
function _star_project_formal_target_actions(
    raw_actions::AbstractDict{Tuple{Int, Int}, <:AbstractMatrix},
    native::NativeWavefunctionData,
    star::AbstractVector{<:Integer},
    operations::Vector{SymmetryOperation},
    kpoint_map::Matrix{Int};
    raw_group_tolerance::Real,
    formal_tolerance::Real,
    correction_tolerance::Real,
    max_iterations::Int = 16,
    construction_policy::Symbol = :strict,
)
    raw_tolerance = Float64(raw_group_tolerance)
    target_tolerance = Float64(formal_tolerance)
    correction_limit = Float64(correction_tolerance)
    all(
        value -> isfinite(value) && value > 0.0,
        (raw_tolerance, target_tolerance, correction_limit),
    ) || throw(ArgumentError("formal target action tolerances must be positive and finite"))
    max_iterations > 0 ||
        throw(ArgumentError("formal target action iteration cap must be positive"))
    ordered_star = sort!(Int.(collect(star)))
    isempty(ordered_star) && throw(ArgumentError("FORMAL_TARGET_REPRESENTATION_HOLD: empty k-star"))
    product_table = build_representation_product_table(
        operations,
        native.spinor;
        tolerance = min(target_tolerance, 1.0e-10),
    )
    all(matrix -> all(isfinite, matrix), values(raw_actions)) ||
        throw(ArgumentError("NONFINITE_STRUCTURAL_HOLD: formal target action"))
    current = Dict(key => Matrix{ComplexF64}(value) for (key, value) in raw_actions)
    initial = _star_target_action_group_residual(
        current,
        native,
        ordered_star,
        operations,
        kpoint_map,
        product_table,
    )
    isfinite(initial.maximum) ||
        throw(ArgumentError("NONFINITE_STRUCTURAL_HOLD: formal target group residual"))
    construction_policy == :diagnostic ||
        initial.maximum <= raw_tolerance ||
        throw(
            ArgumentError(
                "FORMAL_TARGET_RAW_GROUP_LAW_HOLD: target polar group residual " *
                "$(initial.maximum) exceeds $(raw_tolerance); $(initial.context)",
            ),
        )
    dimension = size(first(values(current)), 1)
    identity_matrix = Matrix{ComplexF64}(I, dimension, dimension)
    for source in ordered_star
        current[(source, product_table.identity_index)] = identity_matrix
    end
    best = initial
    best_actions = copy(current)
    best_correction =
        maximum(norm(current[key] - raw_actions[key]) / sqrt(dimension) for key in keys(current))
    for iteration in 1:max_iterations
        updated = Dict{Tuple{Int, Int}, Matrix{ComplexF64}}()
        for source in ordered_star, left_index in eachindex(operations)
            average = zeros(ComplexF64, dimension, dimension)
            contribution_count = 0
            for right_index in eachindex(operations)
                inverse_sources =
                    filter(candidate -> kpoint_map[right_index, candidate] == source, ordered_star)
                length(inverse_sources) == 1 || throw(
                    ArgumentError(
                        "FORMAL_TARGET_REPRESENTATION_HOLD: operation $(right_index) does not " *
                        "act bijectively inside the k-star",
                    ),
                )
                inverse_source = only(inverse_sources)
                factor, intermediate, product_index, _ = _star_target_action_group_factor(
                    native,
                    product_table,
                    left_index,
                    right_index,
                    inverse_source,
                    kpoint_map,
                )
                intermediate == source || throw(
                    ArgumentError(
                        "FORMAL_TARGET_REPRESENTATION_HOLD: inverse k action is inconsistent",
                    ),
                )
                product = current[(inverse_source, product_index)]
                right = current[(inverse_source, right_index)]
                operations[left_index].antiunitary && (right = conj(right))
                average .+= factor .* (product * right')
                contribution_count += 1
            end
            contribution_count == length(operations) || throw(
                ArgumentError(
                    "FORMAL_TARGET_REPRESENTATION_HOLD: incomplete group synchronization average",
                ),
            )
            average ./= contribution_count
            decomposition = svd(average)
            updated[(source, left_index)] = decomposition.U * decomposition.Vt
        end
        for source in ordered_star
            updated[(source, product_table.identity_index)] = identity_matrix
        end
        residual = _star_target_action_group_residual(
            updated,
            native,
            ordered_star,
            operations,
            kpoint_map,
            product_table,
        )
        correction = maximum(
            norm(updated[key] - raw_actions[key]) / sqrt(dimension) for key in keys(updated)
        )
        if residual.maximum < best.maximum
            best = residual
            best_actions = copy(updated)
            best_correction = correction
        end
        if residual.maximum <= target_tolerance &&
           residual.corepresentation <= target_tolerance &&
           residual.theta_squared <= target_tolerance
            construction_policy == :diagnostic ||
                correction <= correction_limit ||
                throw(
                    ArgumentError(
                        "FORMAL_TARGET_ACTION_CORRECTION_HOLD: normalized formal action correction " *
                        "$(correction) exceeds $(correction_limit); $(residual.context)",
                    ),
                )
            return (
                actions = updated,
                product_table = product_table,
                iterations = iteration,
                initial = initial,
                residual = residual,
                correction = correction,
            )
        end
        current = updated
    end
    if construction_policy == :diagnostic
        # Identity normalization can change the initial fallback; audit the
        # retained action itself, even if no synchronization step improved it.
        best = _star_target_action_group_residual(
            best_actions,
            native,
            ordered_star,
            operations,
            kpoint_map,
            product_table,
        )
        best_correction = maximum(
            norm(best_actions[key] - raw_actions[key]) / sqrt(dimension) for
            key in keys(best_actions)
        )
        return (
            actions = best_actions,
            product_table = product_table,
            iterations = max_iterations,
            initial = initial,
            residual = best,
            correction = best_correction,
        )
    end
    throw(
        ArgumentError(
            "FORMAL_TARGET_REPRESENTATION_HOLD: projected target group residual " *
            "$(best.maximum) exceeds $(target_tolerance) after $(max_iterations) " *
            "synchronization iterations; correction=$(best_correction); $(best.context)",
        ),
    )
end

# Reuse the package's complete analytic representation validator on the formal
# ragged target actions.  The capsule is star-local and carries only the target
# rank; no parent padding or parent energy is admitted to this qualification.
function _star_validate_formal_target_actions_analytic(
    actions::AbstractDict{Tuple{Int, Int}, <:AbstractMatrix},
    native::NativeWavefunctionData,
    star::AbstractVector{<:Integer},
    operations::Vector{SymmetryOperation},
    kpoint_map::Matrix{Int},
    reciprocal_shifts::Array{Int, 3},
    tolerance::Real;
    construction_policy::Symbol = :strict,
)
    tolerance_value = Float64(tolerance)
    ordered_star = sort!(Int.(collect(star)))
    local_index = Dict(kpoint => index for (index, kpoint) in enumerate(ordered_star))
    operation_count = length(operations)
    star_count = length(ordered_star)
    dimension = size(first(values(actions)), 1)
    local_kpoint_map = Matrix{Int}(undef, operation_count, star_count)
    local_reciprocal_shifts = Array{Int, 3}(undef, 3, operation_count, star_count)
    sewing = Array{ComplexF64, 4}(undef, dimension, dimension, operation_count, star_count)
    kpoints = Matrix{Float64}(undef, star_count, 3)
    for (local_source, source) in enumerate(ordered_star)
        kpoints[local_source, :] .= native.kpoints[source].k_fractional
        for operation_index in eachindex(operations)
            target = kpoint_map[operation_index, source]
            haskey(local_index, target) || throw(
                ArgumentError(
                    "FORMAL_TARGET_REPRESENTATION_HOLD: target analytic capsule leaves k-star",
                ),
            )
            local_kpoint_map[operation_index, local_source] = local_index[target]
            local_reciprocal_shifts[:, operation_index, local_source] .=
                @view reciprocal_shifts[:, operation_index, source]
            sewing[:, :, operation_index, local_source] .= actions[(source, operation_index)]
        end
    end
    representative = first(ordered_star)
    full_to_operation = Int[]
    for target in ordered_star
        operation_index =
            findfirst(index -> kpoint_map[index, representative] == target, eachindex(operations))
        operation_index === nothing && throw(
            ArgumentError(
                "FORMAL_TARGET_REPRESENTATION_HOLD: target analytic capsule is not one k-star",
            ),
        )
        push!(full_to_operation, something(operation_index))
    end
    representation = BandRepresentation(
        "1.16",
        :formal_target,
        native.spinor,
        native.structure.lattice,
        native.reciprocal_lattice,
        (star_count, 1, 1),
        kpoints,
        zeros(Float64, dimension, star_count),
        operations,
        local_kpoint_map,
        local_reciprocal_shifts,
        sewing,
        ones(Int, dimension, star_count),
        [1],
        ones(Int, star_count),
        full_to_operation,
    )
    masks = [trues(dimension) for _ in 1:star_count]
    report = validate_band_representation_compatibility(
        representation,
        nothing;
        outer_mask = masks,
        frozen_mask = masks,
        tolerance = tolerance_value,
        metadata_origin = :computed,
        validation_profile = :analytic,
    )
    construction_policy == :diagnostic ||
        report.passed ||
        throw(
            ArgumentError(
                "FORMAL_TARGET_REPRESENTATION_HOLD: analytic target representation validator " *
                "failed: " *
                join((string(diagnostic.code) for diagnostic in report.diagnostics), ","),
            ),
        )
    return (
        maximum_group_law = maximum(report.maximum_group_law_residuals),
        group_law_channels = report.maximum_group_law_residuals,
        reciprocal_shift = report.maximum_reciprocal_shift_residual,
        theta_squared = report.theta_squared_residual,
        kramers = report.maximum_kramers_residual,
        required_block_unitarity = report.maximum_required_block_unitarity_residual,
        representation_sha256 = report.representation_sha256,
    )
end

# Apply the exact finite-group Reynolds average to a complete target
# Hamiltonian field.  Projective scalar phases cancel in Hamiltonian conjugation.
function _star_finite_group_reynolds_field(
    native_field::AbstractDict{Int, <:AbstractMatrix},
    actions::AbstractDict{Tuple{Int, Int}, <:AbstractMatrix},
    operations::Vector{SymmetryOperation},
    kpoint_map::Matrix{Int},
)
    ordered_sources = sort!(Int.(collect(keys(native_field))))
    projected = Dict{Int, Matrix{ComplexF64}}()
    dimension = size(first(values(native_field)), 1)
    for target in ordered_sources
        average = zeros(ComplexF64, dimension, dimension)
        contribution_count = 0
        for operation_index in eachindex(operations)
            sources =
                filter(source -> kpoint_map[operation_index, source] == target, ordered_sources)
            length(sources) == 1 || throw(
                ArgumentError(
                    "FORMAL_TARGET_REPRESENTATION_HOLD: operation $(operation_index) does not " *
                    "act bijectively inside the target field",
                ),
            )
            source = only(sources)
            average .+= _star_target_hamiltonian_pushforward(
                actions[(source, operation_index)],
                native_field[source],
                operations[operation_index].antiunitary,
            )
            contribution_count += 1
        end
        average ./= contribution_count
        projected[target] = Matrix{ComplexF64}(Hermitian(average))
    end
    return projected
end

# Project once with the finite group and verify both covariance and the
# idempotence of applying the same formal Reynolds projector a second time.
function _star_formal_target_reynolds_projection(
    native_field::AbstractDict{Int, <:AbstractMatrix},
    actions::AbstractDict{Tuple{Int, Int}, <:AbstractMatrix},
    operations::Vector{SymmetryOperation},
    kpoint_map::Matrix{Int},
    tolerance_ev::Real;
    construction_policy::Symbol = :strict,
)
    tolerance = Float64(tolerance_ev)
    isfinite(tolerance) && tolerance > 0.0 ||
        throw(ArgumentError("formal target covariance tolerance must be positive and finite"))
    projected = _star_finite_group_reynolds_field(native_field, actions, operations, kpoint_map)
    residual, context =
        _star_target_field_covariance_residual(projected, actions, operations, kpoint_map)
    projected_twice = _star_finite_group_reynolds_field(projected, actions, operations, kpoint_map)
    idempotence =
        maximum(opnorm(projected_twice[kpoint] - projected[kpoint]) for kpoint in keys(projected))
    isfinite(residual) && isfinite(idempotence) ||
        throw(ArgumentError("NONFINITE_STRUCTURAL_HOLD: Reynolds residual"))
    construction_policy == :diagnostic ||
        residual <= tolerance ||
        throw(
            ArgumentError(
                "FORMAL_TARGET_REPRESENTATION_HOLD: finite-group target Reynolds covariance " *
                "$(residual) exceeds $(tolerance); $(context)",
            ),
        )
    construction_policy == :diagnostic ||
        idempotence <= tolerance ||
        throw(
            ArgumentError(
                "FORMAL_TARGET_REPRESENTATION_HOLD: finite-group target Reynolds idempotence " *
                "$(idempotence) exceeds $(tolerance)",
            ),
        )
    return (
        field = projected,
        covariance_residual_ev = residual,
        covariance_worst_context = context,
        idempotence_ev = idempotence,
    )
end

# Preserve the internal focused-test helper surface while using the exact
# finite-group Reynolds projection rather than an iteration-cap algorithm.
function _star_formal_target_reynolds_field(
    native_field::AbstractDict{Int, <:AbstractMatrix},
    actions::AbstractDict{Tuple{Int, Int}, <:AbstractMatrix},
    operations::Vector{SymmetryOperation},
    kpoint_map::Matrix{Int},
    tolerance_ev::Real,
)
    result = _star_formal_target_reynolds_projection(
        native_field,
        actions,
        operations,
        kpoint_map,
        tolerance_ev,
    )
    return result.field, 1, result.covariance_residual_ev, result.covariance_worst_context
end

# Build the authoritative ragged target Hamiltonian field and embed it into the
# complete parent only after formal covariance projection.  Raw PAW sewing is
# retained in the caller's audits; its polar-unitary target block supplies the
# formal action used here.
function _star_target_reynolds_hamiltonians(
    metric::_AbstractStrictSewingMetric,
    native::NativeWavefunctionData,
    lowdin,
    star::Vector{Int},
    workspace::UnitRange{Int},
    operations::Vector{SymmetryOperation},
    kpoint_map::Matrix{Int},
    reciprocal_shifts::Array{Int, 3},
    contract::TargetSubspaceQualificationContract,
    threshold_ev::Float64,
    raw_group_tolerance::Float64,
    action_correction_tolerance::Float64;
    construction_policy::Symbol = :strict,
)
    workspace == (1:length(workspace)) || throw(
        ArgumentError(
            "TARGET_MASK_MAPPING_HOLD: target Reynolds requires a complete parent workspace",
        ),
    )
    target_indices = _star_target_indices_by_kpoint(contract, star, workspace)
    native_target = Dict{Int, Matrix{ComplexF64}}()
    for kpoint in star
        indices = target_indices[kpoint]
        native_target[kpoint] = Matrix(@view(lowdin.hamiltonians[kpoint][indices, indices]))
    end
    actions = Dict{Tuple{Int, Int}, Matrix{ComplexF64}}()
    maximum_raw_unitarity = 0.0
    maximum_polar_correction = 0.0
    worst_raw_context = "NOT_RECORDED"
    worst_polar_context = "NOT_RECORDED"
    for source in star, operation_index in eachindex(operations)
        target = kpoint_map[operation_index, source]
        haskey(target_indices, target) || throw(
            ArgumentError(
                "TARGET_MASK_MAPPING_HOLD: operation $(operation_index) leaves k-star at source $(source)",
            ),
        )
        transport = _star_transport(
            metric,
            native,
            source,
            operation_index,
            target,
            @view(reciprocal_shifts[:, operation_index, source]),
            operations,
        )
        source_indices = target_indices[source]
        target_indices_at_target = target_indices[target]
        raw = Matrix(@view(transport.raw[target_indices_at_target, source_indices]))
        all(isfinite, raw) || throw(ArgumentError("NONFINITE_STRUCTURAL_HOLD: target sewing"))
        decomposition = svd(raw)
        minimum(decomposition.S) > eps(Float64) * max(1.0, maximum(decomposition.S)) ||
            throw(ArgumentError("PAW_GAUGE_TARGET_RANK_HOLD: target sewing is rank deficient"))
        formal = decomposition.U * decomposition.Vt
        identity_matrix = Matrix{ComplexF64}(I, size(raw, 2), size(raw, 2))
        raw_unitarity = max(
            maximum(abs, raw' * raw - identity_matrix),
            maximum(abs, raw * raw' - identity_matrix),
        )
        polar_correction = norm(formal - raw) / sqrt(size(raw, 2))
        context = "source=$(source),target=$(target),op=$(operation_index)"
        if raw_unitarity > maximum_raw_unitarity
            maximum_raw_unitarity = raw_unitarity
            worst_raw_context = context
        end
        if polar_correction > maximum_polar_correction
            maximum_polar_correction = polar_correction
            worst_polar_context = context
        end
        actions[(source, operation_index)] = formal
    end
    formal_actions = _star_project_formal_target_actions(
        actions,
        native,
        star,
        operations,
        kpoint_map;
        raw_group_tolerance,
        formal_tolerance = min(1.0e-12, threshold_ev * 0.01),
        correction_tolerance = action_correction_tolerance,
        construction_policy,
    )
    analytic = _star_validate_formal_target_actions_analytic(
        formal_actions.actions,
        native,
        star,
        operations,
        kpoint_map,
        reciprocal_shifts,
        min(1.0e-10, threshold_ev);
        construction_policy,
    )
    reynolds = _star_formal_target_reynolds_projection(
        native_target,
        formal_actions.actions,
        operations,
        kpoint_map,
        min(threshold_ev * 0.1, 1.0e-10);
        construction_policy,
    )
    full_hamiltonians = Dict{Int, Matrix{ComplexF64}}()
    for kpoint in star
        target = target_indices[kpoint]
        complement = setdiff(collect(workspace), target)
        full = Matrix{ComplexF64}(Hermitian(lowdin.hamiltonians[kpoint][workspace, workspace]))
        full[target, target] .= reynolds.field[kpoint]
        full[target, complement] .= 0.0
        full[complement, target] .= 0.0
        full_hamiltonians[kpoint] = full
    end
    return (
        hamiltonians = full_hamiltonians,
        target_hamiltonians = reynolds.field,
        target_indices = target_indices,
        actions = formal_actions.actions,
        iterations = formal_actions.iterations,
        initial_group_law = formal_actions.initial.maximum,
        initial_group_law_context = formal_actions.initial.context,
        group_law = formal_actions.residual.maximum,
        group_law_channels = formal_actions.residual.channels,
        group_law_context = formal_actions.residual.context,
        corepresentation = formal_actions.residual.corepresentation,
        theta_squared = formal_actions.residual.theta_squared,
        kramers = formal_actions.residual.kramers,
        action_correction = formal_actions.correction,
        analytic_group_law = analytic.maximum_group_law,
        analytic_group_law_channels = analytic.group_law_channels,
        analytic_reciprocal_shift = analytic.reciprocal_shift,
        analytic_theta_squared = analytic.theta_squared,
        analytic_kramers = analytic.kramers,
        analytic_required_block_unitarity = analytic.required_block_unitarity,
        analytic_representation_sha256 = analytic.representation_sha256,
        covariance_residual_ev = reynolds.covariance_residual_ev,
        covariance_worst_context = reynolds.covariance_worst_context,
        idempotence_ev = reynolds.idempotence_ev,
        maximum_raw_unitarity = maximum_raw_unitarity,
        raw_unitarity_worst_context = worst_raw_context,
        maximum_polar_correction = maximum_polar_correction,
        polar_correction_worst_context = worst_polar_context,
    )
end

"""
Reconstruct the Reynolds-projected Hamiltonian for one source k point.

Raw augmentation-aware PAW transports are used without polar repair.  The
result is independent of the completed eigenvectors and therefore provides the
non-tautological Hamiltonian used by the symmetrized-authority residual gates.
"""
function _star_independent_reynolds_hamiltonian(
    metric::_AbstractStrictSewingMetric,
    native::NativeWavefunctionData,
    lowdin,
    source_kpoint::Int,
    workspace::UnitRange{Int},
    operations::Vector{SymmetryOperation},
    kpoint_map::Matrix{Int},
    reciprocal_shifts::Array{Int, 3},
)
    transports = Matrix{ComplexF64}[]
    target_hamiltonians = Matrix{ComplexF64}[]
    antiunitary = Bool[]
    for operation_index in eachindex(operations)
        target = kpoint_map[operation_index, source_kpoint]
        transport = _star_transport(
            metric,
            native,
            source_kpoint,
            operation_index,
            target,
            @view(reciprocal_shifts[:, operation_index, source_kpoint]),
            operations,
        )
        push!(transports, Matrix(@view(transport.raw[workspace, workspace])))
        push!(target_hamiltonians, Matrix(@view(lowdin.hamiltonians[target][workspace, workspace])))
        push!(antiunitary, operations[operation_index].antiunitary)
    end
    return _star_reynolds_hamiltonian(transports, target_hamiltonians, antiunitary)
end

# Canonicalize column phases and deterministic ordering inside numerical degeneracies.
function _star_canonicalize_eigenvectors!(
    vectors::Matrix{ComplexF64},
    values::Vector{Float64},
    tolerance_ev::Float64,
)
    for cluster in _star_energy_clusters(values, tolerance_ev)
        if length(cluster) > 1
            subspace = @view vectors[:, cluster]
            anchor = Hermitian(subspace' * Diagonal(collect(1.0:size(vectors, 1))) * subspace)
            anchor_decomposition = eigen(anchor)
            subspace .= subspace * anchor_decomposition.vectors
        end
        for column in cluster
            pivot = argmax(abs.(@view(vectors[:, column])))
            phase = vectors[pivot, column]
            abs(phase) > eps(Float64) && (vectors[:, column] .*= conj(phase) / abs(phase))
        end
    end
    return vectors
end

# Build the physical projector onto the original target-band span inside one
# PAW-S-orthonormal working frame.
function _star_target_projector(
    metric::_AbstractStrictSewingMetric,
    lowdin_point::PlaneWaveKPoint,
    lowdin_projectors::Array{ComplexF64, 3},
    raw_point::PlaneWaveKPoint,
    raw_projectors::Array{ComplexF64, 3},
    workspace::UnitRange{Int},
    target_indices::AbstractVector{<:Integer},
)
    cross, _, _ = _strict_metric_overlap(
        metric,
        lowdin_point.coefficients[workspace, :, :],
        raw_point.coefficients[target_indices, :, :],
        lowdin_projectors[workspace, :, :],
        raw_projectors[target_indices, :, :],
    )
    target_metric, _, _ = _strict_metric_overlap(
        metric,
        raw_point.coefficients[target_indices, :, :],
        raw_point.coefficients[target_indices, :, :],
        raw_projectors[target_indices, :, :],
        raw_projectors[target_indices, :, :],
    )
    decomposition = eigen(Hermitian(0.5 .* (target_metric + target_metric')))
    minimum(decomposition.values) > 1.0e-10 ||
        throw(ArgumentError("PAW_GAUGE_TARGET_RANK_HOLD: native target metric is rank deficient"))
    inverse_metric =
        decomposition.vectors * Diagonal(inv.(decomposition.values)) * decomposition.vectors'
    projector = cross * inverse_metric * cross'
    return Matrix(Hermitian(0.5 .* (projector + projector')))
end

# Choose deterministic coordinate pairs for one antiunitary block satisfying A*conj(A)=-I.
function _star_kramers_pair_basis(antiunitary::Matrix{ComplexF64}, tolerance::Float64)
    dimension = size(antiunitary, 1)
    size(antiunitary, 2) == dimension && iseven(dimension) ||
        throw(ArgumentError("PAW_GAUGE_KRAMERS_BLOCK_DIMENSION_HOLD"))
    identity_matrix = Matrix{ComplexF64}(I, dimension, dimension)
    maximum(abs, antiunitary * conj(antiunitary) + identity_matrix) <= tolerance ||
        throw(ArgumentError("PAW_GAUGE_KRAMERS_SQUARE_HOLD"))
    basis = zeros(ComplexF64, dimension, dimension)
    occupied = 0
    for _ in 1:div(dimension, 2)
        candidate = zeros(ComplexF64, dimension)
        found = false
        for coordinate in 1:dimension
            candidate .= 0.0
            candidate[coordinate] = 1.0
            occupied > 0 && (
                candidate .-=
                    @view(basis[:, 1:occupied]) * (@view(basis[:, 1:occupied])' * candidate)
            )
            norm(candidate) > tolerance || continue
            candidate ./= norm(candidate)
            pivot = argmax(abs.(candidate))
            candidate .*= conj(candidate[pivot]) / abs(candidate[pivot])
            found = true
            break
        end
        found || throw(ArgumentError("PAW_GAUGE_KRAMERS_PAIR_RANK_HOLD"))
        partner = antiunitary * conj(candidate)
        occupied > 0 &&
            (partner .-= @view(basis[:, 1:occupied]) * (@view(basis[:, 1:occupied])' * partner))
        partner .-= candidate * dot(candidate, partner)
        norm(partner) > tolerance || throw(ArgumentError("PAW_GAUGE_KRAMERS_PAIR_RANK_HOLD"))
        partner ./= norm(partner)
        basis[:, occupied + 1] .= candidate
        basis[:, occupied + 2] .= partner
        occupied += 2
    end
    canonical = zeros(ComplexF64, dimension, dimension)
    for pair in 1:2:dimension
        canonical[pair + 1, pair] = 1.0
        canonical[pair, pair + 1] = -1.0
    end
    residual = maximum(abs, basis' * antiunitary * conj(basis) - canonical)
    residual <= 10.0 * tolerance || throw(ArgumentError("PAW_GAUGE_KRAMERS_PAIR_HOLD"))
    return basis, residual
end

# Fix Kramers-pair gauge only in numerically degenerate eigenspaces where an
# antiunitary little-group action explicitly squares to minus identity.
function _star_fix_kramers_pairs!(
    eigenvectors::Matrix{ComplexF64},
    eigenvalues::Vector{Float64},
    raw_transports::Vector{Matrix{ComplexF64}},
    transports::AbstractVector{<:NamedTuple},
    operations::Vector{SymmetryOperation},
    representative::Int,
    thresholds::PAWGaugeThresholds,
)
    paired = 0
    maximum_residual = 0.0
    energy_tolerance = max(thresholds.hamiltonian_covariance_ev, 1.0e-10)
    for operation_index in eachindex(operations)
        operation = operations[operation_index]
        operation.antiunitary || continue
        transports[operation_index].target_kpoint == representative || continue
        transformed_action = eigenvectors' * raw_transports[operation_index] * conj(eigenvectors)
        for cluster in _star_energy_clusters(eigenvalues, energy_tolerance)
            iseven(length(cluster)) || continue
            block = Matrix(@view(transformed_action[cluster, cluster]))
            identity_matrix = Matrix{ComplexF64}(I, length(cluster), length(cluster))
            square_residual = maximum(abs, block * conj(block) + identity_matrix)
            square_residual <= thresholds.group_law || continue
            pair_basis, residual = _star_kramers_pair_basis(block, thresholds.group_law)
            eigenvectors[:, cluster] .= @view(eigenvectors[:, cluster]) * pair_basis
            paired += div(length(cluster), 2)
            maximum_residual = max(maximum_residual, residual)
        end
        paired > 0 && break
    end
    return paired, maximum_residual
end

# Select the fixed target rank by maximum total overlap with the original target rows.
function _star_select_target_eigenvectors(
    values::Vector{Float64},
    vectors::Matrix{ComplexF64},
    target_projector::AbstractMatrix{<:Number},
    target_count::Int,
    cluster_tolerance_ev::Float64,
)
    size(target_projector) == (size(vectors, 1), size(vectors, 1)) ||
        throw(ArgumentError("PAW_GAUGE_TARGET_PROJECTOR_DIMENSION_MISMATCH"))
    weights = [
        real(dot(@view(vectors[:, column]), target_projector * @view(vectors[:, column]))) for
        column in axes(vectors, 2)
    ]
    selected =
        sort!(sortperm(eachindex(weights); by = index -> (-weights[index], index))[1:target_count])
    excluded = setdiff(collect(eachindex(weights)), selected)
    if !isempty(excluded)
        minimum_gap =
            minimum(abs(values[left] - values[right]) for left in selected, right in excluded)
        minimum_gap <= cluster_tolerance_ev && throw(
            ArgumentError(
                "PAW_GAUGE_TARGET_BOUNDARY_DEGENERACY_HOLD: retained rank cuts a complete cluster",
            ),
        )
    end
    sort!(selected; by = index -> (values[index], index))
    return values[selected], vectors[:, selected], selected
end

# Diagonalize the complete authoritative target block independently of the
# parent PAW partition.  Parent blocks remain useful diagnostics, but dropping
# target matrix elements which cross those blocks would make the completed
# vectors fail H_target * V = V * E even for the identity operation.
function _star_symmetrized_target_eigenpair(
    hamiltonian::AbstractMatrix{<:Number},
    target_indices::AbstractVector{<:Integer},
    parent_blocks::Vector{Vector{Int}},
    cluster_tolerance_ev::Real,
)
    dimension = size(hamiltonian, 1)
    size(hamiltonian, 2) == dimension ||
        throw(ArgumentError("TARGET_EIGENPAIR_DIMENSION_HOLD: Hamiltonian is not square"))
    target = Int.(collect(target_indices))
    isempty(target) && throw(ArgumentError("TARGET_MASK_RANK_HOLD: empty target eigenspace"))
    length(unique(target)) == length(target) && all(index -> 1 <= index <= dimension, target) ||
        throw(ArgumentError("TARGET_MASK_MAPPING_HOLD: invalid target indices"))
    tolerance = Float64(cluster_tolerance_ev)
    isfinite(tolerance) && tolerance > 0.0 ||
        throw(ArgumentError("target eigenpair cluster tolerance must be positive and finite"))

    block_labels = zeros(Int, dimension)
    for (label, block) in enumerate(parent_blocks), index in block
        1 <= index <= dimension || throw(
            ArgumentError("TARGET_MASK_MAPPING_HOLD: parent block index is outside workspace"),
        )
        block_labels[index] == 0 ||
            throw(ArgumentError("TARGET_MASK_MAPPING_HOLD: parent blocks overlap"))
        block_labels[index] = label
    end
    all(index -> block_labels[index] > 0, target) ||
        throw(ArgumentError("TARGET_MASK_MAPPING_HOLD: parent blocks do not cover target indices"))

    target_hamiltonian = Matrix{ComplexF64}(Hermitian(hamiltonian[target, target]))
    decomposition = eigen(Hermitian(target_hamiltonian))
    values = Vector{Float64}(decomposition.values)
    vectors = zeros(ComplexF64, dimension, length(target))
    vectors[target, :] .= Matrix{ComplexF64}(decomposition.vectors)
    # Only rotate exact numerical degeneracies.  The broader PAW buffer cluster
    # tolerance is a partition policy and must not alter an authoritative
    # Hamiltonian eigenpair.
    _star_canonicalize_eigenvectors!(vectors, values, min(tolerance, 1.0e-10))
    eigen_residual =
        maximum(abs, Matrix{ComplexF64}(hamiltonian) * vectors - vectors * Diagonal(values))
    isfinite(eigen_residual) ||
        throw(ArgumentError("NONFINITE_STRUCTURAL_HOLD: nonfinite target eigenpair residual"))

    legacy_offblock = zeros(ComplexF64, length(target), length(target))
    for local_left in eachindex(target), local_right in eachindex(target)
        block_labels[target[local_left]] == block_labels[target[local_right]] && continue
        legacy_offblock[local_left, local_right] = target_hamiltonian[local_left, local_right]
    end
    legacy_frobenius = norm(legacy_offblock)
    return (
        values = values,
        vectors = vectors,
        selected_indices = target,
        maxima = Dict{String, Float64}(
            "authoritative_target_eigensolver_residual_ev" => eigen_residual,
            "legacy_parent_partition_target_offblock_maximum_element_ev" =>
                maximum(abs, legacy_offblock; init = 0.0),
            "legacy_parent_partition_target_offblock_operator_ev" => opnorm(legacy_offblock, 2),
            "legacy_parent_partition_target_offblock_normalized_frobenius_ev" =>
                legacy_frobenius / sqrt(length(target)),
        ),
    )
end

# Transport a frozen authoritative target eigenpair with the exact formal
# target action.  The raw parent plane-wave action is retained for audits, but
# it can contain target--complement leakage and nondegenerate target mixing
# which must not redefine the authoritative target eigenvectors away from the
# representative k point.
function _star_transport_symmetrized_target_eigenpair(
    source_vectors::AbstractMatrix{<:Number},
    source_indices::AbstractVector{<:Integer},
    target_indices::AbstractVector{<:Integer},
    formal_action::AbstractMatrix{<:Number},
    antiunitary::Bool,
    target_hamiltonian::AbstractMatrix{<:Number},
    eigenvalues::AbstractVector{<:Real},
)
    dimension = size(source_vectors, 1)
    size(target_hamiltonian) == (dimension, dimension) || throw(
        ArgumentError("TARGET_EIGENPAIR_DIMENSION_HOLD: transported Hamiltonian dimension differs"),
    )
    source = Int.(collect(source_indices))
    target = Int.(collect(target_indices))
    target_count = length(eigenvalues)
    length(source) == target_count == length(target) ||
        throw(ArgumentError("TARGET_MASK_RANK_HOLD: transported target ranks differ"))
    size(source_vectors, 2) == target_count ||
        throw(ArgumentError("TARGET_EIGENPAIR_DIMENSION_HOLD: source target-vector rank differs"))
    size(formal_action) == (target_count, target_count) ||
        throw(ArgumentError("TARGET_EIGENPAIR_DIMENSION_HOLD: formal target action rank differs"))
    all(index -> 1 <= index <= dimension, source) &&
    all(index -> 1 <= index <= dimension, target) ||
        throw(ArgumentError("TARGET_MASK_MAPPING_HOLD: transported target indices are invalid"))
    length(unique(source)) == target_count && length(unique(target)) == target_count ||
        throw(ArgumentError("TARGET_MASK_MAPPING_HOLD: transported target indices overlap"))

    source_local = Matrix{ComplexF64}(@view(source_vectors[source, :]))
    source_action = antiunitary ? conj(source_local) : source_local
    target_local = Matrix{ComplexF64}(formal_action) * source_action
    vectors = zeros(ComplexF64, dimension, target_count)
    vectors[target, :] .= target_local
    values = Float64.(eigenvalues)
    residual =
        maximum(abs, Matrix{ComplexF64}(target_hamiltonian) * vectors - vectors * Diagonal(values))
    isometry = maximum(abs, vectors' * vectors - I)
    all(isfinite, values) && isfinite(residual) && isfinite(isometry) ||
        throw(ArgumentError("NONFINITE_STRUCTURAL_HOLD: nonfinite transported target eigenpair"))
    return (values = values, vectors = vectors, residual_ev = residual, isometry = isometry)
end

# Generate the target G-vector basis obtained from one exact representative transport.
function _star_transformed_target_template(
    representative::PlaneWaveKPoint,
    target_k_fractional::AbstractVector{<:Real},
    operation::SymmetryOperation,
    reciprocal_shift::AbstractVector{<:Integer},
    energies::Vector{Float64},
)
    sign = operation.antiunitary ? -1 : 1
    reciprocal_action = transpose(inv(operation.rotation_fractional))
    vectors = Matrix{Int}(undef, size(representative.g_vectors))
    for row in axes(representative.g_vectors, 1)
        mapped = sign .* (reciprocal_action * @view(representative.g_vectors[row, :]))
        maximum(abs, mapped .- round.(mapped)) <= 1.0e-8 ||
            throw(ArgumentError("PAW_GAUGE_NONINTEGER_G_ACTION"))
        vectors[row, :] .= Int.(reciprocal_shift) .+ round.(Int, mapped)
    end
    coefficients =
        zeros(ComplexF64, length(energies), size(vectors, 1), size(representative.coefficients, 3))
    return PlaneWaveKPoint(
        target_k_fractional,
        vectors,
        coefficients,
        energies;
        normalize_coefficients = false,
    )
end

# Add or update one scalar maximum and its exact star/k/operation context.
function _star_update_maximum!(maxima, contexts, key::String, value::Real, context)
    numeric = Float64(value)
    if numeric > get(maxima, key, -Inf)
        maxima[key] = numeric
        contexts[key] = String(context)
    end
    return nothing
end

# Preserve a finite pre-symmetrization residual as diagnostic evidence without
# allowing it to stop the symmetrized-Hamiltonian authority before Reynolds
# restoration. Structural failures remain exceptions at their point of origin.
function _star_record_raw_preflight_diagnostic!(
    maxima,
    contexts,
    key::String,
    value::Real,
    threshold::Real,
    context,
)
    numeric = Float64(value)
    reference = Float64(threshold)
    isfinite(numeric) && isfinite(reference) && reference > 0.0 || throw(
        ArgumentError(
            "PRE_SYMMETRIZATION_STRUCTURAL_HOLD: nonfinite raw diagnostic or reference for $(key)",
        ),
    )
    _star_update_maximum!(maxima, contexts, "pre_symmetrization_$(key)", numeric, context)
    ratio = numeric / reference
    if ratio > 1.0
        maxima["raw_preflight_diagnostic_exceeded"] = 1.0
        _star_update_maximum!(
            maxima,
            contexts,
            "raw_preflight_diagnostic_maximum_ratio",
            ratio,
            "metric=$(key); $(context)",
        )
    end
    return nothing
end

# Return an interpolated percentile of absolute audit values without adding a
# Statistics dependency to the extension.
function _star_absolute_percentile(values::AbstractVector{<:Real}, probability::Real)
    isempty(values) && throw(ArgumentError("energy-shift audit values must not be empty"))
    0.0 <= probability <= 1.0 || throw(ArgumentError("percentile probability is outside [0,1]"))
    ordered = sort!(abs.(Float64.(values)))
    all(isfinite, ordered) ||
        throw(ArgumentError("NONFINITE_STRUCTURAL_HOLD: nonfinite energy-shift audit value"))
    position = 1.0 + Float64(probability) * (length(ordered) - 1)
    lower = floor(Int, position)
    upper = ceil(Int, position)
    lower == upper && return ordered[lower]
    fraction = position - lower
    return muladd(fraction, ordered[upper] - ordered[lower], ordered[lower])
end

# Append one restart-independent diagnostic record after a star either passes all
# post-gauge physical gates or reaches a fail-closed boundary.  This sidecar is
# diagnostic only: it is never accepted as a gauge or representation artifact.
function _star_append_preflight_diagnostic(config, record)
    config.preflight_diagnostics_jsonl === nothing && return nothing
    filename = abspath(something(config.preflight_diagnostics_jsonl))
    mkpath(dirname(filename))
    open(filename, "a") do io
        JSON3.write(io, record)
        write(io, '\n')
        flush(io)
    end
    return filename
end

"""Build a QE metric over completed WFC points in one diagnostic k-star."""
function _star_completed_subset_metric(
    metric::_QEStrictSewingMetric,
    global_indices::Vector{Int},
    points::Vector{PlaneWaveKPoint},
)
    projectors = [
        _strict_transformed_projectors(metric, global_index, point.coefficients) for
        (global_index, point) in zip(global_indices, points)
    ]
    return _QEStrictSewingMetric(
        metric.upf_data,
        metric.plan,
        projectors,
        metric.projector_bases[global_indices],
        metric.spinorbit,
        metric.finite_b_cache,
        metric.metric_kind,
    )
end

# Select the exact ragged qualification masks for a complete k-point subset.
function _star_target_contract_masks(config, global_indices::AbstractVector{<:Integer})
    contract = config.target_subspace_contract
    contract === nothing && return (nothing, nothing)
    scope = something(contract).qualification_scope
    maximum(global_indices) <= size(scope.outer_mask, 2) ||
        throw(ArgumentError("TARGET_MASK_DIMENSION_HOLD: k-point index exceeds target contract"))
    outer = [BitVector(scope.outer_mask[:, index]) for index in global_indices]
    frozen = [BitVector(scope.frozen_mask[:, index]) for index in global_indices]
    return outer, frozen
end

"""Build a VASP metric over completed WFC points in one diagnostic k-star."""
function _star_completed_subset_metric(
    metric::_VASPStrictSewingMetric,
    global_indices::Vector{Int},
    points::Vector{PlaneWaveKPoint},
)
    projectors = [
        _strict_transformed_projectors(metric, global_index, point.coefficients) for
        (global_index, point) in zip(global_indices, points)
    ]
    return _VASPStrictSewingMetric(metric.paw, projectors, metric.projector_bases[global_indices])
end

# The first star is an explicit staged gate.  Rebuild its physical strict
# representation from completed WFC and check raw group law/cocycle before the
# full 1000-k-point campaign is allowed to continue.
function _star_first_star_strict_gate!(config, context, solution)
    context.star_index == 1 || return nothing
    global_indices = collect(context.star)
    points = if context.authoritative_hamiltonian isa SymmetrizedDFTHamiltonian
        [solution.parent_points[index] for index in global_indices]
    else
        [solution.points[index] for index in global_indices]
    end
    subset_native = NativeWavefunctionData(
        context.native.source_code,
        context.native.structure,
        context.native.reciprocal_lattice,
        (length(points), 1, 1),
        context.native.spinor,
        points,
        context.native.input_sha256,
        context.native.source_metadata,
    )
    subset_metric = _star_completed_subset_metric(context.metric, global_indices, points)
    energies = hcat((point.energies_ev for point in points)...)
    diagnostic_outer_masks, diagnostic_frozen_masks =
        _star_target_contract_masks(config, global_indices)
    built = build_augmentation_aware_band_representation(
        config.source,
        subset_native,
        energies,
        context.operations,
        context.gauge.buffer_policy.cluster_tolerance_ev,
        config.sewing_backend::AugmentationAwareSewing,
        strict_metric = subset_metric,
        block_partition_policy = context.gauge.block_partition_policy,
        enforce_thresholds = false,
        diagnostic_outer_masks = diagnostic_outer_masks,
        diagnostic_frozen_masks = diagnostic_frozen_masks,
    )
    conventions = built.representation.conventions
    group_values = parse.(Float64, split(conventions["raw_group_law_UU_UA_AU_AA"], ','))
    cocycle_values = parse.(Float64, split(conventions["raw_cocycle_phase_UU_UA_AU_AA"], ','))
    solution.maxima["star1_strict_raw_group_law"] = maximum(group_values)
    solution.maxima["star1_strict_raw_cocycle"] = maximum(cocycle_values)
    solution.maximum_contexts["star1_strict_raw_group_law"] =
        conventions["raw_group_law_worst_cases"]
    solution.maximum_contexts["star1_strict_raw_cocycle"] =
        conventions["raw_projective_group_law_worst_cases"]
    for (key, value) in conventions
        startswith(key, "strict_") && endswith(key, "_maximum") || continue
        solution.maxima["star1_$(key)"] = parse(Float64, value)
        context_key = replace(key, r"_maximum$" => "_worst_context")
        haskey(conventions, context_key) &&
            (solution.maximum_contexts["star1_$(key)"] = conventions[context_key])
    end
    return nothing
end

# Rebuild the raw, PAW-S-Lowdin representation on one complete k-star.  The
# ragged outer-window block is a hard qualification scope for either Hamiltonian
# authority.  Full-parent quantities remain audit evidence and cannot reject a
# target-qualified route.
function _star_raw_target_precontrol_gate(
    authority::AbstractAuthoritativeHamiltonian,
    correction::AbstractDiscreteHamiltonianCorrection,
    metric::AbstractString,
    value::Real,
    threshold::Real;
    context::AbstractString = "NOT_RECORDED",
)
    controlled_symmetrized_target =
        authority isa SymmetrizedDFTHamiltonian && correction isa FarBandCovarianceCorrection
    if controlled_symmetrized_target
        isfinite(value) || _strict_sewing_gate(metric, value, threshold; context)
        return value <= threshold ? :PASS : :CONTROLLED_PRE_SYMMETRIZATION_AUDIT
    end
    _strict_sewing_gate(metric, value, threshold; context)
    return :PASS
end

"""Record raw one-star target diagnostics and enforce the applicable pre-control gates."""
function _star_raw_preflight_strict_diagnostics!(
    config,
    source::AbstractWavefunctionSource,
    native::NativeWavefunctionData,
    metric::_AbstractStrictSewingMetric,
    operations::Vector{SymmetryOperation},
    star::Vector{Int},
    star_index::Int,
    gauge::StarCovariantPAWGauge,
    maxima,
    contexts,
)
    points = native.kpoints[star]
    subset_native = NativeWavefunctionData(
        native.source_code,
        native.structure,
        native.reciprocal_lattice,
        (length(points), 1, 1),
        native.spinor,
        points,
        native.input_sha256,
        native.source_metadata,
    )
    subset_metric = _star_completed_subset_metric(metric, star, points)
    energies = hcat((point.energies_ev for point in points)...)
    diagnostic_outer_masks, diagnostic_frozen_masks = _star_target_contract_masks(config, star)
    built = build_augmentation_aware_band_representation(
        source,
        subset_native,
        energies,
        operations,
        gauge.buffer_policy.cluster_tolerance_ev,
        config.sewing_backend::AugmentationAwareSewing,
        strict_metric = subset_metric,
        block_partition_policy = gauge.block_partition_policy,
        enforce_thresholds = false,
        diagnostic_outer_masks = diagnostic_outer_masks,
        diagnostic_frozen_masks = diagnostic_frozen_masks,
    )
    conventions = built.representation.conventions
    context = "star=$(star_index),raw_lowdin_parent=1:$(size(energies, 1))"
    group_values = parse.(Float64, split(conventions["raw_group_law_UU_UA_AU_AA"], ','))
    cocycle_values = parse.(Float64, split(conventions["raw_cocycle_phase_UU_UA_AU_AA"], ','))
    reciprocal_cocycle = parse(Float64, conventions["raw_reciprocal_cocycle_residual"])
    group_value = maximum(group_values)
    cocycle_value = maximum(cocycle_values)
    _star_record_raw_preflight_diagnostic!(
        maxima,
        contexts,
        "raw_group_law",
        group_value,
        gauge.thresholds.group_law,
        get(conventions, "raw_group_law_worst_cases", context),
    )
    _star_record_raw_preflight_diagnostic!(
        maxima,
        contexts,
        "raw_cocycle",
        cocycle_value,
        gauge.thresholds.cocycle,
        get(conventions, "raw_projective_group_law_worst_cases", context),
    )
    _star_construction_quality_gate!(
        config,
        maxima,
        contexts,
        "target_raw_group_law",
        group_value,
        gauge.thresholds.group_law;
        context = get(conventions, "raw_group_law_worst_cases", context),
    )
    _star_construction_quality_gate!(
        config,
        maxima,
        contexts,
        "target_raw_cocycle",
        cocycle_value,
        gauge.thresholds.cocycle;
        context = get(conventions, "raw_projective_group_law_worst_cases", context),
    )
    _strict_reciprocal_shift_cocycle_gate(
        reciprocal_cocycle,
        gauge.thresholds.group_law;
        root_cause = "PRE_SYMMETRIZATION_STRUCTURAL_HOLD",
        context,
    )
    for (strict_key, diagnostic_key, threshold) in (
        (
            "strict_target_reconstruction_leakage_weight_maximum",
            "raw_target_reconstruction_leakage_weight",
            gauge.thresholds.target_leakage_weight,
        ),
        (
            "strict_target_state_leakage_weight_maximum",
            "raw_target_state_leakage_weight",
            gauge.thresholds.target_leakage_weight,
        ),
        (
            "strict_target_to_complement_leakage_weight_maximum",
            "raw_target_to_complement_leakage_weight",
            gauge.thresholds.target_leakage_weight,
        ),
        (
            "strict_complement_to_target_leakage_weight_maximum",
            "raw_complement_to_target_leakage_weight",
            gauge.thresholds.target_leakage_weight,
        ),
        (
            "strict_target_raw_left_unitarity_residual_maximum",
            "raw_target_left_unitarity",
            gauge.thresholds.raw_unitarity,
        ),
        (
            "strict_target_raw_right_unitarity_residual_maximum",
            "raw_target_right_unitarity",
            gauge.thresholds.raw_unitarity,
        ),
        (
            "strict_frozen_raw_left_unitarity_residual_maximum",
            "raw_frozen_left_unitarity",
            gauge.thresholds.raw_unitarity,
        ),
        (
            "strict_frozen_raw_right_unitarity_residual_maximum",
            "raw_frozen_right_unitarity",
            gauge.thresholds.raw_unitarity,
        ),
        (
            "strict_target_normalized_polar_correction_maximum",
            "raw_target_normalized_polar_correction",
            gauge.thresholds.normalized_polar_correction,
        ),
    )
        haskey(conventions, strict_key) || continue
        value = parse(Float64, conventions[strict_key])
        context_key = replace(strict_key, r"_maximum$" => "_worst_context")
        _star_record_raw_preflight_diagnostic!(
            maxima,
            contexts,
            diagnostic_key,
            value,
            threshold,
            get(conventions, context_key, context),
        )
        gate_context = get(conventions, context_key, context)
        if config.construction_policy == :diagnostic
            _star_construction_quality_gate!(
                config,
                maxima,
                contexts,
                diagnostic_key,
                value,
                threshold;
                context = gate_context,
            )
            continue
        end
        status = _star_raw_target_precontrol_gate(
            config.authoritative_hamiltonian,
            gauge.hamiltonian_correction,
            diagnostic_key,
            value,
            threshold;
            context = gate_context,
        )
        if status == :CONTROLLED_PRE_SYMMETRIZATION_AUDIT
            maxima["controlled_pre_symmetrization_audit_count"] =
                get(maxima, "controlled_pre_symmetrization_audit_count", 0.0) + 1.0
            _star_update_maximum!(
                maxima,
                contexts,
                "$(diagnostic_key)_precontrol_audit_ratio",
                value / threshold,
                gate_context,
            )
        end
    end
    return nothing
end
