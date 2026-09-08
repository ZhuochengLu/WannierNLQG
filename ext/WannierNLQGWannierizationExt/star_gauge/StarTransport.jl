# Partition a full k mesh into deterministic group orbits.
function _star_orbits(kpoint_map::Matrix{Int})
    nk = size(kpoint_map, 2)
    assigned = falses(nk)
    stars = Vector{Vector{Int}}()
    for seed in 1:nk
        assigned[seed] && continue
        orbit = sort!(unique(Int[kpoint_map[:, seed]...]))
        frontier = copy(orbit)
        while !isempty(frontier)
            point = popfirst!(frontier)
            for target in @view(kpoint_map[:, point])
                target in orbit && continue
                push!(orbit, target)
                push!(frontier, target)
            end
            sort!(orbit)
        end
        any(assigned[orbit]) && throw(ArgumentError("PAW_GAUGE_KSTAR_OVERLAP: k-stars overlap"))
        assigned[orbit] .= true
        push!(stars, orbit)
    end
    all(assigned) || throw(ArgumentError("PAW_GAUGE_KSTAR_INCOMPLETE: full mesh was not covered"))
    return stars
end

# Prefer identity at a representative, then the lexicographically smallest operation key.
function _star_canonical_operation(
    operations::Vector{SymmetryOperation},
    kpoint_map::Matrix{Int},
    representative::Int,
    target::Int,
)
    candidates = findall(==(target), @view(kpoint_map[:, representative]))
    isempty(candidates) && throw(ArgumentError("PAW_GAUGE_KSTAR_PATH_MISSING"))
    identity = findfirst(candidates) do index
        operation = operations[index]
        !operation.antiunitary &&
            operation.rotation_fractional == Matrix{Int}(I, 3, 3) &&
            maximum(abs, operation.translation_fractional) <= 1.0e-12
    end
    target == representative && identity !== nothing && return candidates[something(identity)]
    sort!(candidates; by = index -> (canonical_band_operation_key(operations[index]), index))
    return first(candidates)
end

# Evaluate one augmentation-aware transport and its direct PAW-S reconstruction residual.
function _star_transport(
    metric::_AbstractStrictSewingMetric,
    native::NativeWavefunctionData,
    source_kpoint::Int,
    operation_index::Int,
    target_kpoint::Int,
    reciprocal_shift::AbstractVector{<:Integer},
    operations::Vector{SymmetryOperation},
)
    transformed = _strict_transform_plane_wave_coefficients(
        native.kpoints[source_kpoint],
        native.kpoints[target_kpoint],
        operations[operation_index],
        reciprocal_shift,
    )
    transformed_projectors = _strict_transformed_projectors(metric, target_kpoint, transformed)
    raw, pseudo, augmentation = _strict_metric_overlap(
        metric,
        native.kpoints[target_kpoint].coefficients,
        transformed,
        metric.projectors[target_kpoint],
        transformed_projectors,
    )
    reconstruction = _strict_reconstruction_diagnostics(
        metric,
        native.kpoints[target_kpoint].coefficients,
        transformed,
        metric.projectors[target_kpoint],
        transformed_projectors,
        raw,
    )
    return (; raw, pseudo, augmentation, transformed, transformed_projectors, reconstruction)
end

# Return contiguous complete energy clusters in one ordered native band list.
function _star_energy_clusters(energies::AbstractVector{<:Real}, tolerance_ev::Float64)
    clusters = UnitRange{Int}[]
    start = 1
    for index in 2:length(energies)
        abs(energies[index] - energies[index - 1]) <= tolerance_ev && continue
        push!(clusters, start:(index - 1))
        start = index
    end
    push!(clusters, start:length(energies))
    return clusters
end

# Grow the target workspace through complete adjacent clusters until physical leakage closes.
function _star_select_buffer(
    raw_transports::Vector{Matrix{ComplexF64}},
    representative_energies::Vector{Float64},
    target_indices::UnitRange{Int},
    policy::ClosureDrivenBandBuffer,
    leakage_threshold::Float64;
    construction_policy::Symbol = :strict,
)
    parent_count = length(representative_energies)
    first(target_indices) >= 1 && last(target_indices) <= parent_count ||
        throw(ArgumentError("PAW_GAUGE_TARGET_RANK_MISMATCH"))
    clusters = _star_energy_clusters(representative_energies, policy.cluster_tolerance_ev)
    lower_cluster = findfirst(cluster -> first(target_indices) in cluster, clusters)
    upper_cluster = findfirst(cluster -> last(target_indices) in cluster, clusters)
    lower_cluster === nothing && error("lower target band was not assigned to an energy cluster")
    upper_cluster === nothing && error("upper target band was not assigned to an energy cluster")
    selected_first = first(clusters[something(lower_cluster)])
    selected_last = last(clusters[something(upper_cluster)])

    function validate_candidate(first_band::Int, last_band::Int)
        extra = length(first_band:last_band) - length(target_indices)
        if construction_policy == :diagnostic && extra > policy.max_extra_bands
            return false
        end
        extra <= policy.max_extra_bands || throw(
            ArgumentError(
                "FINITE_BUFFER_HOLD: closure requires more than $(policy.max_extra_bands) bands",
            ),
        )
        lower_distance = max(
            representative_energies[first(target_indices)] - representative_energies[first_band],
            0.0,
        )
        upper_distance = max(
            representative_energies[last_band] - representative_energies[last(target_indices)],
            0.0,
        )
        if construction_policy == :diagnostic &&
           maximum((lower_distance, upper_distance)) > policy.hard_energy_cap_ev
            return false
        end
        maximum((lower_distance, upper_distance)) <= policy.hard_energy_cap_ev || throw(
            ArgumentError(
                "FINITE_BUFFER_HOLD: adjacent cluster exceeds the $(policy.hard_energy_cap_ev) eV hard cap",
            ),
        )
        return true
    end
    if !validate_candidate(selected_first, selected_last)
        selected_first, selected_last = first(target_indices), last(target_indices)
    end

    maximum_leakage = Inf
    while true
        selected = selected_first:selected_last
        outside = [
            collect(1:(selected_first - 1));
            collect((selected_last + 1):parent_count)
        ]
        maximum_leakage = 0.0
        if !isempty(outside)
            for raw in raw_transports, source_band in selected
                maximum_leakage =
                    max(maximum_leakage, sqrt(sum(abs2, @view(raw[outside, source_band]))))
            end
            for raw in raw_transports, target_band in selected
                maximum_leakage =
                    max(maximum_leakage, sqrt(sum(abs2, @view(raw[target_band, outside]))))
            end
        end
        maximum_leakage <= leakage_threshold && break
        lower_candidate =
            something(lower_cluster) > 1 ? clusters[something(lower_cluster) - 1] : nothing
        upper_candidate =
            something(upper_cluster) < length(clusters) ? clusters[something(upper_cluster) + 1] :
            nothing
        lower_candidate === nothing &&
            upper_candidate === nothing &&
            throw(
                ArgumentError(
                    "FINITE_BUFFER_HOLD: parent workspace remains open; leakage=$(maximum_leakage)",
                ),
            )
        function cluster_score(cluster)
            cluster === nothing && return -Inf
            score = 0.0
            for raw in raw_transports, source_band in selected
                score = max(score, sqrt(sum(abs2, @view(raw[cluster, source_band]))))
            end
            for raw in raw_transports, target_band in selected
                score = max(score, sqrt(sum(abs2, @view(raw[target_band, cluster]))))
            end
            return score
        end
        lower_score = cluster_score(lower_candidate)
        upper_score = cluster_score(upper_candidate)
        next_first = lower_score >= upper_score ? first(something(lower_candidate)) : selected_first
        next_last = lower_score >= upper_score ? selected_last : last(something(upper_candidate))
        validate_candidate(next_first, next_last) || break
        if lower_score >= upper_score
            selected_first = first(something(lower_candidate))
            lower_cluster = something(lower_cluster) - 1
        else
            selected_last = last(something(upper_candidate))
            upper_cluster = something(upper_cluster) + 1
        end
        validate_candidate(selected_first, selected_last)
    end
    return selected_first:selected_last, maximum_leakage
end
