# Wilson-loop shift-vector response assembled from the shared cache.

"""
Contract the four-link Wilson product from the central valence block to the
shifted valence/conduction blocks and back to the central conduction block. The
two position insertions use directions `(b,c)`. Degenerate-subspace sums are
weighted once by the central valence and conduction group weights; no logarithm,
finite difference, or output normalization is applied at this level.
"""
function wilson_loop_shift_vector_loop(
    central_data::GeometricLoopMatrixData,
    shifted_data::GeometricLoopMatrixData,
    central_to_shifted_overlap::AbstractMatrix{ComplexF64},
    shifted_to_central_overlap::AbstractMatrix{ComplexF64},
    valence_band::Int64,
    conduction_band::Int64,
    second_direction::Int64,
    third_direction::Int64,
)
    valence_start = central_data.degeneracy_group_starts[valence_band]
    valence_stop = central_data.degeneracy_group_stops[valence_band]
    conduction_start = central_data.degeneracy_group_starts[conduction_band]
    conduction_stop = central_data.degeneracy_group_stops[conduction_band]

    total = COMPLEX_ZERO
    @inbounds for m0 in valence_start:valence_stop
        for ms in valence_start:valence_stop
            left_link = central_to_shifted_overlap[m0, ms]
            for ns in conduction_start:conduction_stop
                shifted_r = shifted_data.berry_connection[ms, ns, second_direction]
                left_r = left_link * shifted_r
                for n0 in conduction_start:conduction_stop
                    total +=
                        left_r *
                        shifted_to_central_overlap[ns, n0] *
                        central_data.berry_connection[n0, m0, third_direction]
                end
            end
        end
    end
    return central_data.degeneracy_weights[conduction_band] *
           central_data.degeneracy_weights[valence_band] *
           total
end

"""
Compute the central difference along `a` of the phase of the cached Wilson-loop
product for optical directions `(b,c)`. Forward and backward products reuse the
worker-local overlap cache and are stored at `[n,m,a,b,c]`; the logarithm branch
and zero-loop tolerance remain the established ones. This routine does not alter
band ordering, degeneracy weights, prefactors, or k-point normalization.
"""
function compute_wilson_loop_shift_vector_from_cache!(
    response_kernel::Array{ComplexF64, 5},
    ws::WilsonLoopResponseWorkspace,
    band_start::Int64,
    band_end::Int64,
    finite_difference_step::Float64,
    spatial_dimension::Int64,
    ;
    tensor_indices::Union{Nothing, AbstractVector{<:Integer}} = nothing,
)
    central_data = ws.central_data
    _clear_response_kernel!(response_kernel, tensor_indices)
    derivative_axes = tensor_indices === nothing ? (1:spatial_dimension) : (tensor_indices[1],)
    @inbounds for a in derivative_axes
        if ws.shift_vector_loop_axis != a
            fill!(ws.shift_vector_loop_valid, false)
            ws.shift_vector_loop_axis = a
        end
        forward_data = ws.forward_data[a]
        backward_data = ws.backward_data[a]
        @views begin
            central_to_forward_overlap = ws.central_to_forward_overlap[:, :, a]
            forward_to_central_overlap = ws.forward_to_central_overlap[:, :, a]
            central_to_backward_overlap = ws.central_to_backward_overlap[:, :, a]
            backward_to_central_overlap = ws.backward_to_central_overlap[:, :, a]
            response_pairs =
                tensor_indices === nothing ?
                Iterators.product(1:spatial_dimension, 1:spatial_dimension) :
                ((tensor_indices[2], tensor_indices[3]),)
            for n in band_start:band_end
                for m in band_start:band_end
                    for (b, c) in response_pairs
                        conduction_key = central_data.degeneracy_group_starts[n]
                        valence_key = central_data.degeneracy_group_starts[m]
                        if !ws.shift_vector_loop_valid[conduction_key, valence_key, b, c]
                            ws.shift_vector_forward_loops[conduction_key, valence_key, b, c] =
                                wilson_loop_shift_vector_loop(
                                    central_data,
                                    forward_data,
                                    central_to_forward_overlap,
                                    forward_to_central_overlap,
                                    m,
                                    n,
                                    b,
                                    c,
                                )
                            ws.shift_vector_backward_loops[conduction_key, valence_key, b, c] =
                                wilson_loop_shift_vector_loop(
                                    central_data,
                                    backward_data,
                                    central_to_backward_overlap,
                                    backward_to_central_overlap,
                                    m,
                                    n,
                                    b,
                                    c,
                                )
                            ws.shift_vector_loop_valid[conduction_key, valence_key, b, c] = true
                        end
                        Wp = ws.shift_vector_forward_loops[conduction_key, valence_key, b, c]
                        Wm = ws.shift_vector_backward_loops[conduction_key, valence_key, b, c]
                        response_kernel[n, m, a, b, c] =
                            finite_loop_log_derivative(Wp, Wm, finite_difference_step)
                    end
                end
            end
        end
    end
    return response_kernel
end
