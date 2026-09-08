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

"""
Construct a Convention-covariant source-gauge subspace link in place.

For Convention I this computes `U_left^dagger * U_right`. For Convention II it
inserts `D_tau(k_left) * D_tau(k_right)'` between the source-gauge eigenvectors.
All scratch storage belongs to the caller; the routine applies no polar
normalization, physical prefactor, or output normalization.
"""
function compute_convention_covariant_overlap!(
    output::AbstractMatrix{ComplexF64},
    left::GeometricLoopMatrixData,
    right::GeometricLoopMatrixData,
    ::IdentityConventionFrameConnector,
    wannier_centers_fractional::AbstractMatrix{<:Real},
    frame_phase_factors::AbstractVector{ComplexF64},
    frame_rotated_eigenvectors::AbstractMatrix{ComplexF64},
)
    return mul!(
        output,
        left.spectrum.source_eigenvectors_adjoint,
        right.spectrum.source_eigenvectors,
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
    return mul!(output, left.spectrum.source_eigenvectors_adjoint, frame_rotated_eigenvectors)
end
