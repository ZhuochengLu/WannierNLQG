# Gauge-chain diagnostics are deliberately array based. File identity and
# artifact persistence live in the optional Wannierization extension.

"""Materialize a k-indexed frame vector from the package k-last layout."""
function _wannier_frame_vector(frames::Array{ComplexF64, 3})
    return [Matrix{ComplexF64}(@view frames[:, :, kpoint]) for kpoint in axes(frames, 3)]
end

"""Compare two subspaces using quantities invariant under independent k-local gauges."""
function _compare_wannier_projectors(
    first_frames::Array{ComplexF64, 3},
    second_frames::Array{ComplexF64, 3};
    frozen_mask::Union{Nothing, AbstractMatrix{Bool}} = nothing,
)
    size(first_frames) == size(second_frames) ||
        throw(DimensionMismatch("projector comparison frame dimensions disagree"))
    nb, nw, nk = size(first_frames)
    mask = frozen_mask === nothing ? falses(nb, nk) : BitMatrix(frozen_mask)
    size(mask) == (nb, nk) ||
        throw(DimensionMismatch("frozen mask must have size (num_bands, num_kpoints)"))
    frobenius = zeros(Float64, nk)
    spectral = zeros(Float64, nk)
    maximum_angle = zeros(Float64, nk)
    minimum_cross = zeros(Float64, nk)
    band_weight_difference = zeros(Float64, nb, nk)
    frozen_frobenius = zeros(Float64, nk)
    free_frobenius = zeros(Float64, nk)
    for kpoint in 1:nk
        first_frame = @view first_frames[:, :, kpoint]
        second_frame = @view second_frames[:, :, kpoint]
        first_projector = first_frame * first_frame'
        second_projector = second_frame * second_frame'
        difference = first_projector - second_projector
        frobenius[kpoint] = norm(difference)
        spectral[kpoint] = opnorm(difference)
        singular_values = clamp.(svdvals(first_frame' * second_frame), 0.0, 1.0)
        length(singular_values) == nw ||
            throw(ArgumentError("projector cross-overlap singular-value count is invalid"))
        minimum_cross[kpoint] = minimum(singular_values)
        maximum_angle[kpoint] = acos(minimum_cross[kpoint])
        band_weight_difference[:, kpoint] .= real.(diag(difference))
        frozen = findall(@view mask[:, kpoint])
        free = findall(!, @view mask[:, kpoint])
        frozen_frobenius[kpoint] = isempty(frozen) ? 0.0 : norm(@view difference[frozen, frozen])
        free_frobenius[kpoint] = isempty(free) ? 0.0 : norm(@view difference[free, free])
    end
    all(isfinite, frobenius) &&
    all(isfinite, spectral) &&
    all(isfinite, maximum_angle) &&
    all(isfinite, band_weight_difference) ||
        throw(ArgumentError("projector comparison produced non-finite data"))
    return WannierProjectorComparison(
        frobenius,
        spectral,
        maximum_angle,
        minimum_cross,
        band_weight_difference,
        frozen_frobenius,
        free_frobenius,
    )
end

"""
Measure selected-subspace MMN links and the local contributions to Omega_I.

For edge `(k,b)`, `L=V(k)' M(k,b) V(k+b)`. Its singular values, the defect
`N_w-tr(L L')`, and the weighted contribution are invariant under independent
unitary gauges inside either endpoint subspace.
"""
function _wannier_gauge_link_diagnostics(
    frames::Array{ComplexF64, 3},
    mmn::WannierMMN,
    weights::AbstractVector{<:Real},
)
    nb, nw, nk = size(frames)
    (mmn.num_bands, mmn.num_kpts) == (nb, nk) ||
        throw(DimensionMismatch("MMN dimensions disagree with diagnostic frames"))
    length(weights) == mmn.num_neighbors ||
        throw(DimensionMismatch("finite-difference weight count disagrees with MMN"))
    minimum_singular_values = fill(Inf, mmn.num_neighbors, nk)
    defects = zeros(Float64, mmn.num_neighbors, nk)
    contributions = zeros(Float64, mmn.num_neighbors, nk)
    maximum_defect = -Inf
    worst_source = 0
    worst_neighbor = 0
    worst_target = 0
    for kpoint in 1:nk, neighbor in 1:mmn.num_neighbors
        target = mmn.neighbors[neighbor, kpoint]
        link =
            @view(frames[:, :, kpoint])' *
            @view(mmn.data[:, :, neighbor, kpoint]) *
            @view(frames[:, :, target])
        singular_values = svdvals(link)
        minimum_singular_values[neighbor, kpoint] = minimum(singular_values)
        defect = max(0.0, nw - sum(abs2, link))
        defects[neighbor, kpoint] = defect
        contributions[neighbor, kpoint] = Float64(weights[neighbor]) * defect / nk
        if defect > maximum_defect
            maximum_defect = defect
            worst_source = kpoint
            worst_neighbor = neighbor
            worst_target = target
        end
    end
    omega_i = sum(contributions)
    positive = sort!(max.(vec(contributions), 0.0); rev = true)
    top_count = max(1, ceil(Int, 0.01 * length(positive)))
    positive_total = sum(positive)
    concentration =
        positive_total > eps(Float64) ? sum(@view positive[1:top_count]) / positive_total : 0.0
    all(isfinite, minimum_singular_values) &&
    all(isfinite, defects) &&
    all(isfinite, contributions) &&
    isfinite(omega_i) &&
    isfinite(concentration) ||
        throw(ArgumentError("gauge-link diagnostics produced non-finite data"))
    return WannierGaugeLinkDiagnostics(
        minimum_singular_values,
        defects,
        contributions,
        minimum(minimum_singular_values),
        maximum_defect,
        concentration,
        omega_i,
        worst_source,
        worst_neighbor,
        worst_target,
    )
end

"""Seal scalar local-link observations into a terminal checkpoint summary."""
function _record_wannier_gauge_link_summary!(
    summary::Dict{String, String},
    diagnostics::WannierGaugeLinkDiagnostics,
)
    summary["z_link_minimum_singular_value"] = string(diagnostics.minimum_singular_value)
    summary["z_link_maximum_invariant_defect"] = string(diagnostics.maximum_invariant_defect)
    summary["z_link_top_one_percent_concentration"] =
        string(diagnostics.top_one_percent_concentration)
    summary["z_link_worst_source_kpoint"] = string(diagnostics.worst_source_kpoint)
    summary["z_link_worst_neighbor"] = string(diagnostics.worst_neighbor)
    summary["z_link_worst_target_kpoint"] = string(diagnostics.worst_target_kpoint)
    summary["z_link_omega_i"] = string(diagnostics.omega_i)
    summary["z_link_metric_contract"] = "subspace_mmn_singular_defect_v1"
    return summary
end

"""Apply the campaign's evidence-bounded Z/U/Fourier causal rules."""
function _classify_wannier_gauge_chain_cause(;
    fourier_roundtrip_residual::Real,
    fourier_roundtrip_tolerance::Real = 1.0e-10,
    z_outlier_cell_match::Bool = false,
    cross_u_tail_improvement_fraction::Real = 0.0,
    cross_u_frozen_max_improvement_fraction::Real = 0.0,
    rcg_tail_improvement_fraction::Real = 0.0,
    rcg_frozen_max_improvement_fraction::Real = 0.0,
    ablation_frozen_max_improvement_fraction::Real = 0.0,
    aliasing_reproduced::Bool = false,
)
    residual = Float64(fourier_roundtrip_residual)
    tolerance = Float64(fourier_roundtrip_tolerance)
    residual >= 0.0 && isfinite(residual) ||
        throw(ArgumentError("fourier_roundtrip_residual must be finite and nonnegative"))
    tolerance > 0.0 && isfinite(tolerance) ||
        throw(ArgumentError("fourier_roundtrip_tolerance must be positive and finite"))
    if residual > tolerance
        return Symbol[:FOURIER_IMPLEMENTATION_HOLD]
    end
    cross_tail_improvement = Float64(cross_u_tail_improvement_fraction)
    cross_frozen_improvement = Float64(cross_u_frozen_max_improvement_fraction)
    rcg_tail_improvement = Float64(rcg_tail_improvement_fraction)
    rcg_frozen_improvement = Float64(rcg_frozen_max_improvement_fraction)
    ablation_improvement = Float64(ablation_frozen_max_improvement_fraction)
    all(
        isfinite,
        (
            cross_tail_improvement,
            cross_frozen_improvement,
            rcg_tail_improvement,
            rcg_frozen_improvement,
            ablation_improvement,
        ),
    ) || throw(ArgumentError("causal improvement fractions must be finite"))
    z_dominant =
        z_outlier_cell_match && cross_tail_improvement >= 0.25 && cross_frozen_improvement < 0.10
    u_dominant = rcg_tail_improvement >= 0.25 && rcg_frozen_improvement >= 0.25
    causes = Symbol[]
    if z_dominant && u_dominant
        push!(causes, :MIXED_Z_U)
    else
        z_dominant && push!(causes, :Z_DOMINANT)
        u_dominant && push!(causes, :U_DOMINANT)
    end
    ablation_improvement >= 0.50 && push!(causes, :TYPE_IV_U_LIMIT)
    aliasing_reproduced && push!(causes, :FOURIER_ALIASING)
    isempty(causes) && push!(causes, :INDETERMINATE)
    return causes
end
