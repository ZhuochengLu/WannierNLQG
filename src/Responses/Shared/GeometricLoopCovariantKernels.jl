# Shared Convention-covariant Geometric-loop transport and derivative kernels.

"""Construct the Convention-covariant central Geometric-loop link in place."""
function compute_geometric_loop_central_overlap!(
    central_overlap::AbstractMatrix{ComplexF64},
    conduction_data::GeometricLoopMatrixData,
    valence_data::GeometricLoopMatrixData,
    frame_connector::ConventionFrameConnector,
    wannier_centers_fractional::AbstractMatrix{<:Real},
    frame_phase_factors::AbstractVector{ComplexF64},
    frame_rotated_eigenvectors::AbstractMatrix{ComplexF64},
)
    return compute_convention_covariant_overlap!(
        central_overlap,
        conduction_data,
        valence_data,
        frame_connector,
        wannier_centers_fractional,
        frame_phase_factors,
        frame_rotated_eigenvectors,
    )
end

"""Construct all six Convention-covariant shifted Geometric-loop links in place."""
function compute_geometric_loop_shifted_overlaps!(
    forward_overlap_1::AbstractMatrix{ComplexF64},
    forward_overlap_2::AbstractMatrix{ComplexF64},
    forward_overlap_3::AbstractMatrix{ComplexF64},
    backward_overlap_1::AbstractMatrix{ComplexF64},
    backward_overlap_2::AbstractMatrix{ComplexF64},
    backward_overlap_3::AbstractMatrix{ComplexF64},
    valence_central_data::GeometricLoopMatrixData,
    conduction_central_data::GeometricLoopMatrixData,
    valence_forward_data::GeometricLoopMatrixData,
    conduction_forward_data::GeometricLoopMatrixData,
    valence_backward_data::GeometricLoopMatrixData,
    conduction_backward_data::GeometricLoopMatrixData,
    frame_connector::ConventionFrameConnector,
    wannier_centers_fractional::AbstractMatrix{<:Real},
    frame_phase_factors::AbstractVector{ComplexF64},
    frame_rotated_eigenvectors::AbstractMatrix{ComplexF64},
)
    compute_convention_covariant_overlap!(
        forward_overlap_1,
        valence_central_data,
        valence_forward_data,
        frame_connector,
        wannier_centers_fractional,
        frame_phase_factors,
        frame_rotated_eigenvectors,
    )
    compute_convention_covariant_overlap!(
        forward_overlap_2,
        valence_forward_data,
        conduction_forward_data,
        frame_connector,
        wannier_centers_fractional,
        frame_phase_factors,
        frame_rotated_eigenvectors,
    )
    compute_convention_covariant_overlap!(
        forward_overlap_3,
        conduction_forward_data,
        conduction_central_data,
        frame_connector,
        wannier_centers_fractional,
        frame_phase_factors,
        frame_rotated_eigenvectors,
    )
    compute_convention_covariant_overlap!(
        backward_overlap_1,
        valence_central_data,
        valence_backward_data,
        frame_connector,
        wannier_centers_fractional,
        frame_phase_factors,
        frame_rotated_eigenvectors,
    )
    compute_convention_covariant_overlap!(
        backward_overlap_2,
        valence_backward_data,
        conduction_backward_data,
        frame_connector,
        wannier_centers_fractional,
        frame_phase_factors,
        frame_rotated_eigenvectors,
    )
    compute_convention_covariant_overlap!(
        backward_overlap_3,
        conduction_backward_data,
        conduction_central_data,
        frame_connector,
        wannier_centers_fractional,
        frame_phase_factors,
        frame_rotated_eigenvectors,
    )
    return nothing
end

# Convention I already uses the common frame selected by the link transport.
function _align_geometric_source_external_connection!(
    output::Array{ComplexF64, 3},
    data::GeometricLoopMatrixData,
    ::IdentityConventionFrameConnector,
    wannier_centers_fractional::Matrix{Float64},
    model::TightBindingModel,
    frame_rotated_eigenvectors::Matrix{ComplexF64},
    frame_generator_band::Matrix{ComplexF64},
    directions,
)
    return output
end

# Remove the center generator already carried by Convention II link transport.
function _align_geometric_source_external_connection!(
    output::Array{ComplexF64, 3},
    data::GeometricLoopMatrixData,
    ::WannierCenterConventionFrameConnector,
    wannier_centers_fractional::Matrix{Float64},
    model::TightBindingModel,
    frame_rotated_eigenvectors::Matrix{ComplexF64},
    frame_generator_band::Matrix{ComplexF64},
    directions,
)
    eigenvectors = data.spectrum.source_eigenvectors
    eigenvectors_adjoint = data.spectrum.source_eigenvectors_adjoint
    num_orbitals = data.num_orbitals
    @inbounds for direction in directions
        for column in 1:num_orbitals, orbital in 1:num_orbitals
            center_cartesian =
                model.lattice[1, direction] * wannier_centers_fractional[1, orbital] +
                model.lattice[2, direction] * wannier_centers_fractional[2, orbital] +
                model.lattice[3, direction] * wannier_centers_fractional[3, orbital]
            frame_rotated_eigenvectors[orbital, column] =
                center_cartesian * eigenvectors[orbital, column]
        end
        mul!(frame_generator_band, eigenvectors_adjoint, frame_rotated_eigenvectors)
        for column in 1:num_orbitals, row in 1:num_orbitals
            output[row, column, direction] -= frame_generator_band[row, column]
        end
    end
    return output
end

"""
Reconstruct and frame-align the external Wannier-basis connection in place.

The reconstructed matrix is `A_source + i*H_source*N`, with the regularized
inverse energy difference already stored in `data`. Convention II subtracts the
band-space center generator because the same contribution is carried by the
frame-corrected links. Only the requested derivative directions are written.
"""
function prepare_geometric_source_external_connection!(
    output::Array{ComplexF64, 3},
    data::GeometricLoopMatrixData,
    frame_connector::ConventionFrameConnector,
    wannier_centers_fractional::Matrix{Float64},
    model::TightBindingModel,
    frame_rotated_eigenvectors::Matrix{ComplexF64},
    frame_generator_band::Matrix{ComplexF64},
    directions,
)
    source_connection = data.source_gauge_berry_connection
    source_hamiltonian_derivatives = data.source_gauge_hamiltonian_derivatives
    inverse_energy_differences = data.inverse_energy_differences
    @inbounds for direction in directions, column in axes(output, 2), row in axes(output, 1)
        output[row, column, direction] =
            source_connection[row, column, direction] +
            1.0im *
            source_hamiltonian_derivatives[row, column, direction] *
            inverse_energy_differences[row, column]
    end
    return _align_geometric_source_external_connection!(
        output,
        data,
        frame_connector,
        wannier_centers_fractional,
        model,
        frame_rotated_eigenvectors,
        frame_generator_band,
        directions,
    )
end

"""Prepare the central links and optical insertions in the common Convention frame."""
function prepare_geometric_loop_covariant_center!(
    ws::GeometricLoopResponseWorkspace,
    wannier_centers_fractional::Matrix{Float64},
    model::TightBindingModel,
    second_directions,
    third_directions,
)
    num_orbitals = ws.valence_central_data.num_orbitals
    size(wannier_centers_fractional) == (3, num_orbitals) || throw(
        DimensionMismatch(
            "Geometric-loop Wannier centers must have size (3, $(num_orbitals)); " *
            "got $(size(wannier_centers_fractional)).",
        ),
    )
    all(isfinite, wannier_centers_fractional) ||
        error("Geometric-loop Wannier centers contain non-finite fractional coordinates.")
    compute_geometric_loop_central_overlap!(
        ws.central_overlap_4,
        ws.conduction_central_data,
        ws.valence_central_data,
        ws.frame_connector,
        wannier_centers_fractional,
        ws.frame_phase_factors,
        ws.frame_rotated_eigenvectors,
    )
    compute_geometric_loop_second_insertions!(
        ws.central_second_insertions,
        ws.valence_central_data,
        ws.conduction_central_data,
        ws.central_overlap_4,
        second_directions,
    )
    compute_geometric_loop_third_insertions!(
        ws.central_third_insertions,
        ws.valence_central_data,
        ws.conduction_central_data,
        adjoint(ws.central_overlap_4),
        third_directions,
    )
    return ws
end

"""Prepare valence and conduction external connections for the derivative axes."""
function prepare_geometric_loop_external_connections!(
    ws::GeometricLoopResponseWorkspace,
    wannier_centers_fractional::Matrix{Float64},
    model::TightBindingModel,
    derivative_axes,
)
    prepare_geometric_source_external_connection!(
        ws.valence_source_external_connection,
        ws.valence_central_data,
        ws.frame_connector,
        wannier_centers_fractional,
        model,
        ws.frame_rotated_eigenvectors,
        ws.frame_generator_band,
        derivative_axes,
    )
    prepare_geometric_source_external_connection!(
        ws.conduction_source_external_connection,
        ws.conduction_central_data,
        ws.frame_connector,
        wannier_centers_fractional,
        model,
        ws.frame_rotated_eigenvectors,
        ws.frame_generator_band,
        derivative_axes,
    )
    return ws
end

"""Prepare one shifted Geometric stencil and its frame-covariant inserted links."""
function prepare_geometric_loop_frame_axis!(
    ws::GeometricLoopResponseWorkspace,
    kpoint::Vector{Float64},
    photon_momentum_fractional::Vector{Float64},
    finite_difference_vectors::Matrix{Float64},
    wannier_centers_fractional::Matrix{Float64},
    denominator_regularization::Float64,
    finite_difference_step::Float64,
    spatial_dimension::Int64,
    model::TightBindingModel,
    derivative_axis::Int,
    insertion_directions,
)
    has_photon_shift = any(!iszero, photon_momentum_fractional)
    valence_photon_step = has_photon_shift ? -1 : 0
    conduction_photon_step = has_photon_shift ? 1 : 0
    forward_offset = ntuple(direction -> direction == derivative_axis ? 1 : 0, 3)
    backward_offset = ntuple(direction -> direction == derivative_axis ? -1 : 0, 3)
    bind_kpoint_offset!(
        ws.valence_forward_data,
        ws.scratch,
        KPointOffset(forward_offset, valence_photon_step),
    )
    bind_kpoint_offset!(
        ws.conduction_forward_data,
        ws.scratch,
        KPointOffset(forward_offset, conduction_photon_step),
    )
    bind_kpoint_offset!(
        ws.valence_backward_data,
        ws.scratch,
        KPointOffset(backward_offset, valence_photon_step),
    )
    bind_kpoint_offset!(
        ws.conduction_backward_data,
        ws.scratch,
        KPointOffset(backward_offset, conduction_photon_step),
    )

    kv_0 = kpoint - 0.5 * photon_momentum_fractional
    kc_0 = kpoint + 0.5 * photon_momentum_fractional
    compute_kpoint!(
        ws.valence_forward_data,
        ws.scratch,
        model,
        kv_0 + finite_difference_vectors[:, derivative_axis];
        denominator_regularization,
        spatial_dimension,
    )
    compute_kpoint!(
        ws.conduction_forward_data,
        ws.scratch,
        model,
        kc_0 + finite_difference_vectors[:, derivative_axis];
        denominator_regularization,
        spatial_dimension,
    )
    compute_kpoint!(
        ws.valence_backward_data,
        ws.scratch,
        model,
        kv_0 - finite_difference_vectors[:, derivative_axis];
        denominator_regularization,
        spatial_dimension,
    )
    compute_kpoint!(
        ws.conduction_backward_data,
        ws.scratch,
        model,
        kc_0 - finite_difference_vectors[:, derivative_axis];
        denominator_regularization,
        spatial_dimension,
    )

    compute_geometric_loop_shifted_overlaps!(
        ws.forward_overlap_1,
        ws.forward_overlap_2,
        ws.forward_overlap_3,
        ws.backward_overlap_1,
        ws.backward_overlap_2,
        ws.backward_overlap_3,
        ws.valence_central_data,
        ws.conduction_central_data,
        ws.valence_forward_data,
        ws.conduction_forward_data,
        ws.valence_backward_data,
        ws.conduction_backward_data,
        ws.frame_connector,
        wannier_centers_fractional,
        ws.frame_phase_factors,
        ws.frame_rotated_eigenvectors,
    )
    compute_geometric_loop_third_insertions!(
        ws.forward_third_insertions,
        ws.valence_forward_data,
        ws.conduction_forward_data,
        ws.forward_overlap_2,
        insertion_directions,
    )
    compute_geometric_loop_third_insertions!(
        ws.backward_third_insertions,
        ws.valence_backward_data,
        ws.conduction_backward_data,
        ws.backward_overlap_2,
        insertion_directions,
    )

    return ws
end

"""
Complete one transported centered difference with the aligned left/right connection.

All arguments are expressed in the central valence/conduction frames. The caller
provides both matrix temporaries so the operation remains allocation-free inside
the response loop.
"""
function compute_geometric_loop_covariant_insertion_derivative!(
    output::AbstractMatrix{ComplexF64},
    forward_transported::AbstractMatrix{ComplexF64},
    backward_transported::AbstractMatrix{ComplexF64},
    central_insertion::AbstractMatrix{ComplexF64},
    valence_external_connection::AbstractMatrix{ComplexF64},
    conduction_external_connection::AbstractMatrix{ComplexF64},
    temporary_left::AbstractMatrix{ComplexF64},
    temporary_right::AbstractMatrix{ComplexF64},
    finite_difference_step::Float64,
)
    isfinite(finite_difference_step) && finite_difference_step > 0.0 ||
        error("Geometric-loop finite_difference_step must be positive and finite.")
    size(output) == size(central_insertion) ||
        throw(DimensionMismatch("Geometric-loop derivative output and insertion shapes differ."))
    size(forward_transported) == size(output) ||
        throw(DimensionMismatch("Forward transported insertion has the wrong shape."))
    size(backward_transported) == size(output) ||
        throw(DimensionMismatch("Backward transported insertion has the wrong shape."))
    mul!(temporary_left, valence_external_connection, central_insertion)
    mul!(temporary_right, central_insertion, conduction_external_connection)
    inverse_two_step = inv(2.0 * finite_difference_step)
    @inbounds for column in axes(output, 2), row in axes(output, 1)
        output[row, column] =
            (forward_transported[row, column] - backward_transported[row, column]) *
            inverse_two_step - 1.0im * temporary_left[row, column] +
            1.0im * temporary_right[row, column]
    end
    return output
end

"""
Transport and differentiate one already projected valence/conduction block.

All link and insertion arguments are endpoint-projected blocks. The two
transport outputs and two temporaries are caller-owned so this expert kernel is
allocation-free and never reads spectator rows or columns.
"""
function compute_geometric_loop_block_covariant_insertion_derivative!(
    output::AbstractMatrix{ComplexF64},
    forward_valence_link::AbstractMatrix{ComplexF64},
    forward_insertion::AbstractMatrix{ComplexF64},
    forward_conduction_link::AbstractMatrix{ComplexF64},
    backward_valence_link::AbstractMatrix{ComplexF64},
    backward_insertion::AbstractMatrix{ComplexF64},
    backward_conduction_link::AbstractMatrix{ComplexF64},
    central_insertion::AbstractMatrix{ComplexF64},
    valence_external_connection::AbstractMatrix{ComplexF64},
    conduction_external_connection::AbstractMatrix{ComplexF64},
    forward_transported::AbstractMatrix{ComplexF64},
    backward_transported::AbstractMatrix{ComplexF64},
    temporary_left::AbstractMatrix{ComplexF64},
    temporary_right::AbstractMatrix{ComplexF64},
    finite_difference_step::Float64,
)
    mul!(temporary_left, forward_valence_link, forward_insertion)
    mul!(forward_transported, temporary_left, forward_conduction_link)
    mul!(temporary_right, backward_valence_link, backward_insertion)
    mul!(backward_transported, temporary_right, backward_conduction_link)
    return compute_geometric_loop_covariant_insertion_derivative!(
        output,
        forward_transported,
        backward_transported,
        central_insertion,
        valence_external_connection,
        conduction_external_connection,
        temporary_left,
        temporary_right,
        finite_difference_step,
    )
end

"""
Prepare one shifted Geometric stencil for block-projected covariant derivatives.

This cold setup computes the complete inserted links before projection and resets
the per-axis block cache. Transport and explicit connection products are deferred
to `prepare_geometric_loop_covariant_derivative_block!`, where they are restricted
to the requested valence/conduction degeneracy blocks.
"""
function prepare_geometric_loop_covariant_axis!(
    ws::GeometricLoopResponseWorkspace,
    kpoint::Vector{Float64},
    photon_momentum_fractional::Vector{Float64},
    finite_difference_vectors::Matrix{Float64},
    wannier_centers_fractional::Matrix{Float64},
    denominator_regularization::Float64,
    finite_difference_step::Float64,
    spatial_dimension::Int64,
    model::TightBindingModel,
    derivative_axis::Int,
    insertion_directions,
)
    prepare_geometric_loop_frame_axis!(
        ws,
        kpoint,
        photon_momentum_fractional,
        finite_difference_vectors,
        wannier_centers_fractional,
        denominator_regularization,
        finite_difference_step,
        spatial_dimension,
        model,
        derivative_axis,
        insertion_directions,
    )
    fill!(ws.covariant_derivative_valid, false)
    ws.covariant_derivative_axis = derivative_axis
    return ws
end

"""
Prepare one block-projected covariant insertion derivative in place.

The shifted subspaces use the same band-index ranges as their central degeneracy
blocks. The full inserted link `J = V*M + M*V` is formed before this kernel; only
its endpoints are projected here. No matrix element outside the selected
valence/conduction ranges participates in transport or connection products.
"""
function prepare_geometric_loop_covariant_derivative_block!(
    ws::GeometricLoopResponseWorkspace,
    derivative_axis::Int,
    valence_band::Int,
    conduction_band::Int,
    insertion_directions,
    finite_difference_step::Float64,
)
    ws.covariant_derivative_axis == derivative_axis ||
        error("Geometric-loop block derivative axis was read before stencil preparation.")
    isfinite(finite_difference_step) && finite_difference_step > 0.0 ||
        error("Geometric-loop finite_difference_step must be positive and finite.")

    valence_data = ws.valence_central_data
    conduction_data = ws.conduction_central_data
    valence_start = valence_data.degeneracy_group_starts[valence_band]
    valence_stop = valence_data.degeneracy_group_stops[valence_band]
    conduction_start = conduction_data.degeneracy_group_starts[conduction_band]
    conduction_stop = conduction_data.degeneracy_group_stops[conduction_band]
    valence_range = valence_start:valence_stop
    conduction_range = conduction_start:conduction_stop

    @views for direction in insertion_directions
        ws.covariant_derivative_valid[valence_start, conduction_start, direction] && continue
        forward_temporary = ws.transport_temporary_1[valence_range, conduction_range]
        backward_temporary = ws.transport_temporary_2[valence_range, conduction_range]
        forward_transported =
            ws.forward_transported_insertions[valence_range, conduction_range, direction]
        backward_transported =
            ws.backward_transported_insertions[valence_range, conduction_range, direction]

        compute_geometric_loop_block_covariant_insertion_derivative!(
            ws.covariant_insertion_derivatives[valence_range, conduction_range, direction],
            ws.forward_overlap_1[valence_range, valence_range],
            ws.forward_third_insertions[valence_range, conduction_range, direction],
            ws.forward_overlap_3[conduction_range, conduction_range],
            ws.backward_overlap_1[valence_range, valence_range],
            ws.backward_third_insertions[valence_range, conduction_range, direction],
            ws.backward_overlap_3[conduction_range, conduction_range],
            ws.central_third_insertions[valence_range, conduction_range, direction],
            ws.valence_source_external_connection[valence_range, valence_range, derivative_axis],
            ws.conduction_source_external_connection[
                conduction_range,
                conduction_range,
                derivative_axis,
            ],
            forward_transported,
            backward_transported,
            forward_temporary,
            backward_temporary,
            finite_difference_step,
        )
        ws.covariant_derivative_valid[valence_start, conduction_start, direction] = true
    end
    return ws
end

"""Contract one covariant inserted derivative with the central reverse insertion."""
function geometric_loop_covariant_block_contraction(
    ws::GeometricLoopResponseWorkspace,
    valence_band::Int,
    conduction_band::Int,
    second_direction::Int,
    third_direction::Int,
)
    valence_data = ws.valence_central_data
    conduction_data = ws.conduction_central_data
    valence_start = valence_data.degeneracy_group_starts[valence_band]
    valence_stop = valence_data.degeneracy_group_stops[valence_band]
    conduction_start = conduction_data.degeneracy_group_starts[conduction_band]
    conduction_stop = conduction_data.degeneracy_group_stops[conduction_band]
    ws.covariant_derivative_valid[valence_start, conduction_start, third_direction] ||
        error("Geometric-loop block derivative was read before preparation.")
    total = COMPLEX_ZERO
    @inbounds for valence_row in valence_start:valence_stop
        for conduction_column in conduction_start:conduction_stop
            total +=
                ws.covariant_insertion_derivatives[
                    valence_row,
                    conduction_column,
                    third_direction,
                ] * ws.central_second_insertions[conduction_column, valence_row, second_direction]
        end
    end
    return conduction_data.degeneracy_weights[conduction_band] *
           valence_data.degeneracy_weights[valence_band] *
           total
end
