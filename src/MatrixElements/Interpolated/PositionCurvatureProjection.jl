"""Whether this internal plan requests curvature without claiming full position jets."""
@inline _uses_position_curl(plan::MatrixElementPlan) =
    has_capability(plan, WANNIER_CURVATURE) &&
    !has_capability(plan, INTERNAL_CONNECTION_DERIVATIVES)

# Canonical unordered derivative pairs required by at least one output orientation.
function _position_curl_pairs(plan::MatrixElementPlan)
    return Tuple{Int, Int}[
        (a, b) for a in 1:plan.spatial_dimension for
        b in (a + 1):plan.spatial_dimension if _pair_required(plan, WANNIER_CURVATURE, a, b) ||
        _pair_required(plan, WANNIER_CURVATURE, b, a)
    ]
end

# Number of compact antisymmetric position-derivative channels, without diagonals.
function _position_curl_channel_count(plan::MatrixElementPlan)
    count = 0
    for a in 1:plan.spatial_dimension, b in (a + 1):plan.spatial_dimension
        count +=
            _pair_required(plan, WANNIER_CURVATURE, a, b) ||
            _pair_required(plan, WANNIER_CURVATURE, b, a)
    end
    return count
end

"""Prepare ∂a A_b−∂b A_a in the plan's existing Wannier-center convention.

Store canonical a<b pairs in owned R-space scratch. Reuse the full-jet source
value and displacement conventions exactly; commutators remain in the common
curvature consumer. This is a derivative representation, not a new physical
operator projection or Hermitianization. Only orthogonal real-space TB is legal.
"""
function prepare_position_curl_real_space!(scratch, model, plan; scratch_workspace)
    model isa TightBindingModel ||
        throw(ArgumentError("position curl requires orthogonal real-space TB"))
    pairs = scratch.curl_pairs
    result = scratch.curl_real_space
    @inbounds for r in 1:model.num_r_vectors
        r_cartesian = _r_vector_cartesian(model, r)
        for (channel, (a, b)) in enumerate(pairs),
            column in 1:model.num_orbitals,
            row in 1:model.num_orbitals

            position_b = _convention_position_value(
                model.position_r[row, column, b, r],
                b,
                row,
                column,
                r,
                scratch_workspace,
                plan,
            )
            position_a = _convention_position_value(
                model.position_r[row, column, a, r],
                a,
                row,
                column,
                r,
                scratch_workspace,
                plan,
            )
            displacement_a = _convention_displacement_component(
                r_cartesian,
                a,
                row,
                column,
                scratch_workspace,
                plan,
            )
            displacement_b = _convention_displacement_component(
                r_cartesian,
                b,
                row,
                column,
                scratch_workspace,
                plan,
            )
            result[row, column, channel, r] =
                1.0im * displacement_a * position_b - 1.0im * displacement_b * position_a
        end
    end
    return scratch
end

"""Fill compact curl scratch at the current k, without marking full jets computed.

Shared/Mixed Fourier owns binning, phases, plans and memory. The Direct path is
an expert/reference fallback, preserving R order and the original center-frame
similarity. The enclosing WANNIER_CURVATURE bit owns point/generation validity.
"""
function _fourier_position_curl!(workspace::MatrixElementWorkspace, model::AbstractResponseModel)
    plan = workspace.plan
    scratch = workspace.scratch.position
    destination = scratch.curl_wannier
    isempty(destination) && return destination
    copied =
        _shared_or_mixed_copy!(destination, workspace, model, Val(:curlA), workspace.data.kpoint)
    if !copied
        t0 = time_ns()
        fill!(destination, COMPLEX_ZERO)
        @inbounds for r in 1:model.num_r_vectors,
            channel in axes(destination, 3),
            column in 1:model.num_orbitals,
            row in 1:model.num_orbitals

            destination[row, column, channel] +=
                workspace.scratch.fourier_factors[r] *
                scratch.curl_real_space[row, column, channel, r]
        end
        _record_direct_fourier!(workspace, (time_ns()-t0)*1e-9)
        _store_shared_fourier!(destination, workspace, model, :curlA, workspace.data.kpoint)
    end
    for channel in axes(destination, 3)
        @views _apply_wannier_center_similarity!(
            destination[:, :, channel],
            workspace.scratch,
            plan,
        )
    end
    return destination
end
