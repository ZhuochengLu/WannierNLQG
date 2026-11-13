"""Marker for a typed Wannier-center Convention frame connector."""
abstract type ConventionFrameConnector end

"""Use the identity orbital-frame connector for Convention I links."""
struct IdentityConventionFrameConnector <: ConventionFrameConnector end

"""Insert the ordered Wannier-center frame connector for Convention II links."""
struct WannierCenterConventionFrameConnector <: ConventionFrameConnector end

"""
Resolve the concrete frame policy once during workspace construction.
"""
function make_convention_frame_connector(convention::WannierCenterConvention)
    convention == CONVENTION_I && return IdentityConventionFrameConnector()
    convention == CONVENTION_II && return WannierCenterConventionFrameConnector()
    error("Unsupported Wannier-center convention $(convention) for subspace transport.")
end

"""Transport a shifted Projector matrix into the central Convention-I frame."""
function transport_projector_matrix_to_reference!(
    output::AbstractMatrix{ComplexF64},
    source::AbstractMatrix{ComplexF64},
    reference::ProjectorMatrixData,
    shifted::ProjectorMatrixData,
    ::IdentityConventionFrameConnector,
    wannier_centers_fractional::AbstractMatrix{<:Real},
    frame_phase_factors::AbstractVector{ComplexF64},
)
    output === source || copyto!(output, source)
    return output
end

"""Transport a shifted Projector matrix through the ordered center connector."""
function transport_projector_matrix_to_reference!(
    output::AbstractMatrix{ComplexF64},
    source::AbstractMatrix{ComplexF64},
    reference::ProjectorMatrixData,
    shifted::ProjectorMatrixData,
    ::WannierCenterConventionFrameConnector,
    wannier_centers_fractional::AbstractMatrix{<:Real},
    frame_phase_factors::AbstractVector{ComplexF64},
)
    count = reference.num_orbitals
    size(wannier_centers_fractional) == (3, count) ||
        throw(DimensionMismatch("Wannier-center array has incompatible shape"))
    delta_k = reference.common.kpoint .- shifted.common.kpoint
    @inbounds for orbital in 1:count
        frame_phase_factors[orbital] = cis(
            2.0 *
            pi *
            sum(delta_k[axis] * wannier_centers_fractional[axis, orbital] for axis in 1:3),
        )
    end
    @inbounds for column in 1:count, row in 1:count
        output[row, column] =
            frame_phase_factors[row] * source[row, column] * conj(frame_phase_factors[column])
    end
    return output
end

"""Transport a Projector matrix using the frame state owned by its workspace."""
function transport_projector_matrix_to_reference!(
    output::AbstractMatrix{ComplexF64},
    source::AbstractMatrix{ComplexF64},
    reference::ProjectorMatrixData,
    shifted::ProjectorMatrixData,
    workspace::ProjectorMatrixWorkspace,
)
    return transport_projector_matrix_to_reference!(
        output,
        source,
        reference,
        shifted,
        workspace.frame_connector,
        workspace.wannier_centers_fractional,
        workspace.frame_phase_factors,
    )
end

# A shifted transport link consumes closed-group output columns only. Use one
# enclosing 64-aligned column span, retaining all rows and intermediate bands.
# This span policy is deliberately conservative for widely separated groups.
# The public/default link remains complete; nonfinite, small, alias and dense-span
# fallbacks use the same original GEMM, and no validity survives this call.
# Shared storage admission only. Each reader retains its own closed-column
# selection, finite-value checks, product order and full-output fallback.
@inline function _dense_column_panel_storage_eligible(
    output,
    indices,
    factors::Vararg{Any, N},
) where {N}
    n = size(output, 1)
    if n < 128 ||
       rem(n, 4) != 0 ||
       isempty(indices) ||
       !(output isa StridedMatrix{ComplexF64}) ||
       size(output) != (n, n)
        return false
    end
    for factor in factors
        if !(factor isa StridedMatrix{ComplexF64}) ||
           size(factor) != (n, n) ||
           Base.mightalias(output, factor)
            return false
        end
    end
    return true
end

"""Overwrite eligible 64-column link panels; otherwise compute the complete ordered product. Unselected columns are invalid on the panel path."""
function _compute_convention_link_columns!(output, left, right, indices)
    indices === nothing && return mul!(output, left, right)
    n = size(output, 1)
    if !_dense_column_panel_storage_eligible(output, indices, left, right)
        return mul!(output, left, right)
    end
    previous = 0
    for band in indices
        previous < band <= n || return mul!(output, left, right)
        previous = band
    end
    first_column = 64 * div(first(indices) - 1, 64) + 1
    last_column = min(n, 64 * cld(last(indices), 64))
    if 2 * (last_column - first_column + 1) > n || !all(isfinite, left) || !all(isfinite, right)
        return mul!(output, left, right)
    end
    columns = first_column:last_column
    @views mul!(output[:, columns], left, right[:, columns])
    return output
end

"""
Construct a Convention-covariant source-gauge subspace link in place.

For Convention I this computes `U_left^dagger * U_right`. For Convention II it
inserts `D_tau(k_left) * D_tau(k_right)'` between the source-gauge eigenvectors.
All scratch storage belongs to the caller; the routine applies no polar
normalization, physical prefactor, or output normalization.
The default writes the complete link. Internal `output_columns` may restrict
valid output columns to a current closed group span; all rows and intermediate
bands remain complete, and all other output columns are then invalid.
"""
function compute_convention_covariant_overlap!(
    output::AbstractMatrix{ComplexF64},
    left::GeometricLoopMatrixData,
    right::GeometricLoopMatrixData,
    ::IdentityConventionFrameConnector,
    wannier_centers_fractional::AbstractMatrix{<:Real},
    frame_phase_factors::AbstractVector{ComplexF64},
    frame_rotated_eigenvectors::AbstractMatrix{ComplexF64},
    ;
    output_columns = nothing,
)
    return _compute_convention_link_columns!(
        output,
        left.spectrum.source_eigenvectors_adjoint,
        right.spectrum.source_eigenvectors,
        output_columns,
    )
end

# Insert the ordered center-frame connector for Convention II links.
function compute_convention_covariant_overlap!(
    output::AbstractMatrix{ComplexF64},
    left::GeometricLoopMatrixData,
    right::GeometricLoopMatrixData,
    ::WannierCenterConventionFrameConnector,
    wannier_centers_fractional::AbstractMatrix{<:Real},
    frame_phase_factors::AbstractVector{ComplexF64},
    frame_rotated_eigenvectors::AbstractMatrix{ComplexF64},
    ;
    output_columns = nothing,
)
    num_orbitals = left.num_orbitals
    right.num_orbitals == num_orbitals || error("Loop overlap orbital counts do not match.")
    size(output) == (num_orbitals, num_orbitals) ||
        throw(DimensionMismatch("Loop overlap output has the wrong shape."))
    size(wannier_centers_fractional) == (3, num_orbitals) || throw(
        DimensionMismatch(
            "wannier_centers_fractional must have size (3, $(num_orbitals)); " *
            "got $(size(wannier_centers_fractional)).",
        ),
    )
    length(frame_phase_factors) == num_orbitals ||
        throw(DimensionMismatch("Convention frame phase buffer has incompatible length."))
    size(frame_rotated_eigenvectors) == (num_orbitals, num_orbitals) ||
        throw(DimensionMismatch("Convention frame eigenvector buffer has incompatible size."))
    delta_k_1 = left.common.kpoint[1] - right.common.kpoint[1]
    delta_k_2 = left.common.kpoint[2] - right.common.kpoint[2]
    delta_k_3 = left.common.kpoint[3] - right.common.kpoint[3]
    @inbounds for orbital in 1:num_orbitals
        phase_argument =
            delta_k_1 * wannier_centers_fractional[1, orbital] +
            delta_k_2 * wannier_centers_fractional[2, orbital] +
            delta_k_3 * wannier_centers_fractional[3, orbital]
        frame_phase_factors[orbital] = cis(2.0 * pi * phase_argument)
    end
    @inbounds for column in 1:num_orbitals, orbital in 1:num_orbitals
        frame_rotated_eigenvectors[orbital, column] =
            frame_phase_factors[orbital] * right.spectrum.source_eigenvectors[orbital, column]
    end
    return _compute_convention_link_columns!(
        output,
        left.spectrum.source_eigenvectors_adjoint,
        frame_rotated_eigenvectors,
        output_columns,
    )
end
