"""Evaluate PDSC with complete endpoint velocities and physical optical q links.

The PDSC expert entry has the same default as public Runtime. The bare shared
Geometric q=0 kernel retains its independent contract. A center-only fallback is
not a PDSC mode; the existing keyword accepts true for caller compatibility.
"""
function compute_geometric_loop_photon_drag_shift_current_kernel!(
    ws::GeometricLoopResponseWorkspace,
    kpoint::Vector{Float64},
    photon_momentum_fractional::Vector{Float64},
    finite_difference_vectors::Matrix{Float64},
    wannier_centers_fractional::Matrix{Float64},
    denominator_regularization::Float64,
    finite_difference_step::Float64,
    spatial_dimension::Int64,
    model::AbstractResponseModel,
    band_start::Int64,
    band_end::Int64;
    active_pair_mask::Union{Nothing, AbstractMatrix{Bool}} = nothing,
    tensor_indices::Union{Nothing, AbstractVector{<:Integer}} = nothing,
    use_full_velocity_vertices::Bool = true,
    optical_q_cartesian = nothing,
)
    use_full_velocity_vertices || throw(
        ArgumentError(
            "PDSC_REQUIRES_COMPLETE_OPTICAL_VERTICES: center-only historical construction is not the default Wannier route",
        ),
    )
    return compute_geometric_loop_shift_current_kernel!(
        ws,
        kpoint,
        photon_momentum_fractional,
        finite_difference_vectors,
        wannier_centers_fractional,
        denominator_regularization,
        finite_difference_step,
        spatial_dimension,
        model,
        band_start,
        band_end;
        active_pair_mask,
        tensor_indices,
        use_full_velocity_vertices = true,
        optical_q_cartesian,
    )
end
