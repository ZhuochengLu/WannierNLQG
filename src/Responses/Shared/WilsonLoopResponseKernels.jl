# Shared Wilson-loop overlap, transported-derivative, and cache kernels.

"""
Construct a Convention-covariant Wilson link in place.

For Convention I the orbital-frame connector is the identity. For Convention II
the link inserts `D_tau(k_left) * D_tau(k_right)'` between the source-gauge
eigenvectors. The routine uses caller-owned phase and matrix scratch and performs
no polar normalization, physical prefactor, or output normalization.
"""
function wilson_loop_overlap!(
    output::AbstractMatrix{ComplexF64},
    left::GeometricLoopMatrixData,
    right::GeometricLoopMatrixData,
    ::IdentityWilsonFrameConnector,
    wannier_centers_fractional::AbstractMatrix{<:Real},
    frame_phase_factors::AbstractVector{ComplexF64},
    frame_rotated_eigenvectors::AbstractMatrix{ComplexF64},
)
    return compute_convention_covariant_overlap!(
        output,
        left,
        right,
        IdentityConventionFrameConnector(),
        wannier_centers_fractional,
        frame_phase_factors,
        frame_rotated_eigenvectors,
    )
end

# Insert the ordered center-frame connector for Convention II Wilson links.
function wilson_loop_overlap!(
    output::AbstractMatrix{ComplexF64},
    left::GeometricLoopMatrixData,
    right::GeometricLoopMatrixData,
    ::WannierCenterWilsonFrameConnector,
    wannier_centers_fractional::AbstractMatrix{<:Real},
    frame_phase_factors::AbstractVector{ComplexF64},
    frame_rotated_eigenvectors::AbstractMatrix{ComplexF64},
)
    return compute_convention_covariant_overlap!(
        output,
        left,
        right,
        WannierCenterConventionFrameConnector(),
        wannier_centers_fractional,
        frame_phase_factors,
        frame_rotated_eigenvectors,
    )
end

# Keep a Convention-I internal connection unchanged in the common Wilson frame.
function _align_wilson_source_internal_connection!(
    ws::WilsonLoopResponseWorkspace,
    ::IdentityWilsonFrameConnector,
    wannier_centers_fractional::Matrix{Float64},
    model::TightBindingModel,
)
    return ws.source_internal_connection
end

# Transform the Convention-II internal connection into the common Convention-I frame.
function _align_wilson_source_internal_connection!(
    ws::WilsonLoopResponseWorkspace,
    ::WannierCenterWilsonFrameConnector,
    wannier_centers_fractional::Matrix{Float64},
    model::TightBindingModel,
)
    eigenvectors = ws.central_data.spectrum.source_eigenvectors
    eigenvectors_adjoint = ws.central_data.spectrum.source_eigenvectors_adjoint
    rotated = ws.frame_rotated_eigenvectors
    generator_band = ws.frame_generator_band
    output = ws.source_internal_connection
    num_orbitals = ws.central_data.num_orbitals
    @inbounds for direction in axes(output, 3)
        for column in 1:num_orbitals, orbital in 1:num_orbitals
            center_cartesian =
                model.lattice[1, direction] * wannier_centers_fractional[1, orbital] +
                model.lattice[2, direction] * wannier_centers_fractional[2, orbital] +
                model.lattice[3, direction] * wannier_centers_fractional[3, orbital]
            rotated[orbital, column] = center_cartesian * eigenvectors[orbital, column]
        end
        mul!(generator_band, eigenvectors_adjoint, rotated)
        for column in 1:num_orbitals, row in 1:num_orbitals
            output[row, column, direction] -= generator_band[row, column]
        end
    end
    return output
end

# Reconstruct U_source' * A_W * U_source and align it with the Wilson link frame.
function _prepare_wilson_source_internal_connection!(
    ws::WilsonLoopResponseWorkspace,
    wannier_centers_fractional::Matrix{Float64},
    model::TightBindingModel,
)
    data = ws.central_data
    source_connection = data.source_gauge_berry_connection
    source_hamiltonian_derivatives = data.source_gauge_hamiltonian_derivatives
    inverse_energy_differences = data.inverse_energy_differences
    output = ws.source_internal_connection
    @inbounds for direction in axes(output, 3), column in axes(output, 2), row in axes(output, 1)
        output[row, column, direction] =
            source_connection[row, column, direction] +
            1.0im *
            source_hamiltonian_derivatives[row, column, direction] *
            inverse_energy_differences[row, column]
    end
    return _align_wilson_source_internal_connection!(
        ws,
        ws.frame_connector,
        wannier_centers_fractional,
        model,
    )
end

# Add the internal-connection part not already represented by eigenvector transport.
@inline function _wilson_internal_connection_correction(
    central_data::GeometricLoopMatrixData,
    source_internal_connection::AbstractArray{ComplexF64, 3},
    row0::Int,
    col0::Int,
    row_start::Int,
    row_stop::Int,
    col_start::Int,
    col_stop::Int,
    derivative_axis::Int,
    connection_direction::Int,
)
    left_action = COMPLEX_ZERO
    right_action = COMPLEX_ZERO
    @inbounds for row in row_start:row_stop
        left_action +=
            source_internal_connection[row0, row, derivative_axis] *
            central_data.berry_connection[row, col0, connection_direction]
    end
    @inbounds for column in col_start:col_stop
        right_action +=
            central_data.berry_connection[row0, column, connection_direction] *
            source_internal_connection[column, col0, derivative_axis]
    end
    return -1.0im * left_action + 1.0im * right_action
end

"""
Return one connection block element transported through left/right overlap links over specified subspace ranges.

Preserve row/column block order and the requested Cartesian connection direction; no degeneracy or integration weights are added here.
"""
function wilson_loop_transported_connection(
    row0::Int64,
    col0::Int64,
    row_start::Int64,
    row_stop::Int64,
    col_start::Int64,
    col_stop::Int64,
    shifted::GeometricLoopMatrixData,
    central_to_shifted_overlap::AbstractMatrix{ComplexF64},
    shifted_to_central_overlap::AbstractMatrix{ComplexF64},
    direction::Int64,
)
    total = COMPLEX_ZERO
    @inbounds for rows in row_start:row_stop
        left_link = central_to_shifted_overlap[row0, rows]
        for cols in col_start:col_stop
            total +=
                left_link *
                shifted.berry_connection[rows, cols, direction] *
                shifted_to_central_overlap[cols, col0]
        end
    end
    return total
end

"""
This returns the conventional-prefactor-ready covariant derivative product.
The report writes the closed-loop integrand with an explicit 1/i factor; here
the phase convention is kept in the transported connection derivative so the
result can be accumulated with the existing conventional shift-current
prefactor and output layout.
"""
function wilson_loop_derivative_product(
    central_data::GeometricLoopMatrixData,
    forward_data::GeometricLoopMatrixData,
    backward_data::GeometricLoopMatrixData,
    central_to_forward_overlap::AbstractMatrix{ComplexF64},
    forward_to_central_overlap::AbstractMatrix{ComplexF64},
    central_to_backward_overlap::AbstractMatrix{ComplexF64},
    backward_to_central_overlap::AbstractMatrix{ComplexF64},
    row_band::Int64,
    col_band::Int64,
    derivative_axis::Int64,
    connection_dir::Int64,
    multiplier_dir::Int64,
    finite_difference_step::Float64,
    source_internal_connection::AbstractArray{ComplexF64, 3},
)
    row_start = central_data.degeneracy_group_starts[row_band]
    row_stop = central_data.degeneracy_group_stops[row_band]
    col_start = central_data.degeneracy_group_starts[col_band]
    col_stop = central_data.degeneracy_group_stops[col_band]

    total = COMPLEX_ZERO
    @inbounds for row0 in row_start:row_stop
        for col0 in col_start:col_stop
            plus = wilson_loop_transported_connection(
                row0,
                col0,
                row_start,
                row_stop,
                col_start,
                col_stop,
                forward_data,
                central_to_forward_overlap,
                forward_to_central_overlap,
                connection_dir,
            )
            minus = wilson_loop_transported_connection(
                row0,
                col0,
                row_start,
                row_stop,
                col_start,
                col_stop,
                backward_data,
                central_to_backward_overlap,
                backward_to_central_overlap,
                connection_dir,
            )
            derivative =
                (plus - minus) / (2.0 * finite_difference_step) +
                _wilson_internal_connection_correction(
                    central_data,
                    source_internal_connection,
                    row0,
                    col0,
                    row_start,
                    row_stop,
                    col_start,
                    col_stop,
                    derivative_axis,
                    connection_dir,
                )
            total += derivative * central_data.berry_connection[col0, row0, multiplier_dir]
        end
    end
    return central_data.degeneracy_weights[row_band] *
           central_data.degeneracy_weights[col_band] *
           total
end

"""
Fill a selected row/column subspace's transported connection derivative and mark its cached Cartesian directions valid.

Require prepared forward/backward Wilson links and matching step; caller-owned scratch is reused without occupation or integration weights.

Prepare wilson transported derivative block in place.
"""
function prepare_wilson_transported_derivative_block!(
    ws::WilsonLoopResponseWorkspace,
    derivative_axis::Int,
    row_band::Int,
    col_band::Int,
    connection_directions,
    finite_difference_step::Float64,
)
    if ws.transported_derivative_axis != derivative_axis
        fill!(ws.transported_derivative_valid, false)
        ws.transported_derivative_axis = derivative_axis
    end

    central_data = ws.central_data
    row_start = central_data.degeneracy_group_starts[row_band]
    row_stop = central_data.degeneracy_group_stops[row_band]
    col_start = central_data.degeneracy_group_starts[col_band]
    col_stop = central_data.degeneracy_group_stops[col_band]
    forward_data = ws.forward_data[derivative_axis]
    backward_data = ws.backward_data[derivative_axis]
    @views begin
        central_to_forward_overlap = ws.central_to_forward_overlap[:, :, derivative_axis]
        forward_to_central_overlap = ws.forward_to_central_overlap[:, :, derivative_axis]
        central_to_backward_overlap = ws.central_to_backward_overlap[:, :, derivative_axis]
        backward_to_central_overlap = ws.backward_to_central_overlap[:, :, derivative_axis]
        for connection_direction in connection_directions
            ws.transported_derivative_valid[row_start, col_start, connection_direction] && continue
            @inbounds for row0 in row_start:row_stop
                for col0 in col_start:col_stop
                    plus = wilson_loop_transported_connection(
                        row0,
                        col0,
                        row_start,
                        row_stop,
                        col_start,
                        col_stop,
                        forward_data,
                        central_to_forward_overlap,
                        forward_to_central_overlap,
                        connection_direction,
                    )
                    minus = wilson_loop_transported_connection(
                        row0,
                        col0,
                        row_start,
                        row_stop,
                        col_start,
                        col_stop,
                        backward_data,
                        central_to_backward_overlap,
                        backward_to_central_overlap,
                        connection_direction,
                    )
                    ws.transported_connection_derivatives[row0, col0, connection_direction] =
                        (plus - minus) / (2.0 * finite_difference_step) +
                        _wilson_internal_connection_correction(
                            central_data,
                            ws.source_internal_connection,
                            row0,
                            col0,
                            row_start,
                            row_stop,
                            col_start,
                            col_stop,
                            derivative_axis,
                            connection_direction,
                        )
                end
            end
            ws.transported_derivative_valid[row_start, col_start, connection_direction] = true
        end
    end
    return ws
end

"""
Contract a cached transported connection derivative with the central connection over row/column degeneracy blocks.

Apply both stored group weights; the derivative block must have been prepared for the requested axes before this read.
"""
function wilson_loop_derivative_product_from_cache(
    ws::WilsonLoopResponseWorkspace,
    row_band::Int,
    col_band::Int,
    connection_direction::Int,
    multiplier_direction::Int,
)
    central_data = ws.central_data
    row_start = central_data.degeneracy_group_starts[row_band]
    row_stop = central_data.degeneracy_group_stops[row_band]
    col_start = central_data.degeneracy_group_starts[col_band]
    col_stop = central_data.degeneracy_group_stops[col_band]
    ws.transported_derivative_valid[row_start, col_start, connection_direction] ||
        error("Wilson transported derivative was read before preparation.")

    total = COMPLEX_ZERO
    @inbounds for row0 in row_start:row_stop
        for col0 in col_start:col_stop
            total +=
                ws.transported_connection_derivatives[row0, col0, connection_direction] *
                central_data.berry_connection[col0, row0, multiplier_direction]
        end
    end
    return central_data.degeneracy_weights[row_band] *
           central_data.degeneracy_weights[col_band] *
           total
end

"""
Prepare central and requested shifted eigensystems, convention-covariant Wilson links and native internal connection data.

Preserve fractional k/center geometry and configured degeneracy/denominator thresholds; later block derivatives consume these cached buffers.

Prepare wilson loop response cache in place.
"""
function prepare_wilson_loop_response_cache!(
    ws::WilsonLoopResponseWorkspace,
    kpoint::Vector{Float64},
    finite_difference_vectors::Matrix{Float64},
    wannier_centers_fractional::Matrix{Float64},
    model::TightBindingModel,
    spatial_dimension::Int64;
    denominator_regularization::Float64,
    degeneracy_threshold::Float64,
    axes::AbstractVector{<:Integer} = collect(1:spatial_dimension),
)
    central_data = ws.central_data
    bind_kpoint_offset!(central_data, ws.scratch, KPointOffset())
    compute_kpoint!(
        central_data,
        ws.scratch,
        model,
        kpoint;
        denominator_regularization,
        spatial_dimension,
    )
    mark_degenerate_groups!(central_data, degeneracy_threshold)
    all(isfinite, wannier_centers_fractional) ||
        error("Wilson Wannier centers contain non-finite fractional coordinates.")
    size(wannier_centers_fractional) == (3, central_data.num_orbitals) || throw(
        DimensionMismatch(
            "Wilson Wannier centers must have size (3, $(central_data.num_orbitals)); " *
            "got $(size(wannier_centers_fractional)).",
        ),
    )
    _prepare_wilson_source_internal_connection!(ws, wannier_centers_fractional, model)

    @inbounds for a in axes
        k_p = kpoint + finite_difference_vectors[:, a]
        k_m = kpoint - finite_difference_vectors[:, a]
        forward_data = ws.forward_data[a]
        backward_data = ws.backward_data[a]
        bind_kpoint_offset!(
            forward_data,
            ws.scratch,
            KPointOffset(ntuple(direction -> direction == a ? 1 : 0, 3), 0),
        )
        bind_kpoint_offset!(
            backward_data,
            ws.scratch,
            KPointOffset(ntuple(direction -> direction == a ? -1 : 0, 3), 0),
        )
        compute_wilson_shifted!(
            forward_data,
            ws.scratch,
            model,
            k_p;
            denominator_regularization,
            spatial_dimension,
        )
        compute_wilson_shifted!(
            backward_data,
            ws.scratch,
            model,
            k_m;
            denominator_regularization,
            spatial_dimension,
        )

        @views wilson_loop_overlap!(
            ws.central_to_forward_overlap[:, :, a],
            central_data,
            forward_data,
            ws.frame_connector,
            wannier_centers_fractional,
            ws.frame_phase_factors,
            ws.frame_rotated_eigenvectors,
        )
        @views copyto!(
            ws.forward_to_central_overlap[:, :, a],
            adjoint(ws.central_to_forward_overlap[:, :, a]),
        )
        @views wilson_loop_overlap!(
            ws.central_to_backward_overlap[:, :, a],
            central_data,
            backward_data,
            ws.frame_connector,
            wannier_centers_fractional,
            ws.frame_phase_factors,
            ws.frame_rotated_eigenvectors,
        )
        @views copyto!(
            ws.backward_to_central_overlap[:, :, a],
            adjoint(ws.central_to_backward_overlap[:, :, a]),
        )
    end
    ws.transported_derivative_axis = 0
    ws.shift_vector_loop_axis = 0
    return ws
end
