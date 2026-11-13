"""Return [DeltaE/(DeltaE^2+gamma^2)]^2 for a photon-drag transition.

DeltaE=epsilon_m(k+q/2)-epsilon_n(k-q/2), in eV; gamma is the existing
nonnegative denominator regularization in eV. This weight has units eV^-2,
uses neither photon energy nor finite-difference auxiliary spectra, and has no
alternative prescription. A simultaneously zero gap/regularization is undefined;
callers skip exactly zero occupation differences before evaluating it.
"""
@inline function photon_drag_transition_denominator_weight(gap::Float64, gamma::Float64)
    isfinite(gap) && isfinite(gamma) && gamma >= 0 ||
        throw(ArgumentError("finite transition gap and nonnegative gamma required"))
    scale = max(abs(gap), gamma)
    scale > 0 || throw(DomainError((gap, gamma), "zero gap with zero regularization"))
    reduced_gap = gap / scale
    reduced_gamma = gamma / scale
    denominator = reduced_gap^2 + reduced_gamma^2
    amplitude = (reduced_gap / denominator) / scale
    weight = amplitude^2
    isfinite(weight) || throw(DomainError((gap, gamma), "transition weight is not representable"))
    return weight
end

"""Fill signed occupation-times-transition weights outside the geometric FD kernel.

Matrix axes are n (valence), m (conduction). Raw occupations and gap arrays are
not mutated. Exact zero occupations remain zero, including diagonal clean-limit
pairs. Degenerate-group closure and geometric link derivatives remain caller-owned.
"""
function photon_drag_weighted_occupations!(weighted, occupations, gaps, gamma::Float64)
    axes(weighted) == axes(occupations) == axes(gaps) ||
        throw(DimensionMismatch("matching photon-drag pair axes required"))
    isfinite(gamma) && gamma >= 0 || throw(ArgumentError("finite nonnegative gamma required"))
    @inbounds for index in eachindex(weighted, occupations, gaps)
        difference = occupations[index]
        isfinite(difference) || throw(ArgumentError("finite occupation differences required"))
        weighted[index] =
            difference == 0.0 ? 0.0 :
            difference * photon_drag_transition_denominator_weight(gaps[index], gamma)
    end
    return weighted
end
