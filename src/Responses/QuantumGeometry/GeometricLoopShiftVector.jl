# Geometric-loop shift-vector response.

const SHIFT_VECTOR_LOOP_ABS_TOL = 1.0e-14

"""
Return `i*(log(loop_plus)-log(loop_minus))/(2*dk)` using the established complex
logarithm branch. Nonfinite loops and loops no larger than
`SHIFT_VECTOR_LOOP_ABS_TOL` return exact zero. The caller owns band averaging and
all output normalization.
"""
function finite_loop_log_derivative(
    plus::ComplexF64,
    minus::ComplexF64,
    finite_difference_step::Float64,
)
    if !isfinite(real(plus)) ||
       !isfinite(imag(plus)) ||
       !isfinite(real(minus)) ||
       !isfinite(imag(minus))
        return COMPLEX_ZERO
    end
    if abs(plus) <= SHIFT_VECTOR_LOOP_ABS_TOL || abs(minus) <= SHIFT_VECTOR_LOOP_ABS_TOL
        return COMPLEX_ZERO
    end
    return 1.0im * (log(plus) - log(minus)) / (2.0 * finite_difference_step)
end

"""
Every directed edge and velocity-inserted edge uses the common Convention frame.
The observable remains the established four-edge complex-log loop; no explicit
open-block external-connection correction is added. Zero-loop and logarithm
branch behavior are unchanged.
"""
function compute_geometric_loop_shift_vector_kernel!(
    ws::GeometricLoopResponseWorkspace,
    kpoint::Vector{Float64},
    photon_momentum_fractional::Vector{Float64},
    finite_difference_vectors::Matrix{Float64},
    wannier_centers_fractional::Matrix{Float64},
    denominator_regularization::Float64,
    finite_difference_step::Float64,
    spatial_dimension::Int64,
    model::TightBindingModel,
    band_start::Int64,
    band_end::Int64;
    tensor_indices::Union{Nothing, AbstractVector{<:Integer}} = nothing,
)
    _clear_response_kernel!(ws.response_kernel, tensor_indices)
    derivative_axes = tensor_indices === nothing ? (1:spatial_dimension) : (tensor_indices[1],)
    second_directions = tensor_indices === nothing ? (1:spatial_dimension) : (tensor_indices[2],)
    third_directions = tensor_indices === nothing ? (1:spatial_dimension) : (tensor_indices[3],)
    prepare_geometric_loop_covariant_center!(
        ws,
        wannier_centers_fractional,
        model,
        second_directions,
        third_directions,
    )

    @inbounds for a in derivative_axes
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
            a,
            third_directions,
        )
        fill!(ws.forward_loop_links, COMPLEX_ZERO)
        fill!(ws.backward_loop_links, COMPLEX_ZERO)
        fill!(ws.loop_link_valid, false)
        response_pairs =
            tensor_indices === nothing ?
            Iterators.product(1:spatial_dimension, 1:spatial_dimension) :
            ((tensor_indices[2], tensor_indices[3]),)
        for n in band_start:band_end
            for m in band_start:band_end
                conduction_key = ws.conduction_central_data.degeneracy_group_starts[n]
                valence_key = ws.valence_central_data.degeneracy_group_starts[m]
                for (b, c) in response_pairs
                    if !ws.loop_link_valid[conduction_key, valence_key, b, c]
                        ws.forward_loop_links[conduction_key, valence_key, b, c] =
                            geometric_loop_overlap_block_contraction_precomputed(
                                ws.valence_central_data,
                                ws.conduction_central_data,
                                ws.forward_overlap_1,
                                ws.forward_overlap_3,
                                ws.forward_third_insertions,
                                ws.central_second_insertions,
                                m,
                                n,
                                b,
                                c,
                            )
                        ws.backward_loop_links[conduction_key, valence_key, b, c] =
                            geometric_loop_overlap_block_contraction_precomputed(
                                ws.valence_central_data,
                                ws.conduction_central_data,
                                ws.backward_overlap_1,
                                ws.backward_overlap_3,
                                ws.backward_third_insertions,
                                ws.central_second_insertions,
                                m,
                                n,
                                b,
                                c,
                            )
                        ws.loop_link_valid[conduction_key, valence_key, b, c] = true
                    end
                    ws.response_kernel[n, m, a, b, c] = finite_loop_log_derivative(
                        ws.forward_loop_links[conduction_key, valence_key, b, c],
                        ws.backward_loop_links[conduction_key, valence_key, b, c],
                        finite_difference_step,
                    )
                end
            end
        end
    end
    return ws.response_kernel
end

"""
Average the cached finite-loop shift-vector kernel over the selected conduction/valence band pairs.

For Cartesian indices `(a,b,c)`, average `response_kernel[nc,nv,a,b,c]` over both groups; reject an empty pair set. Occupation and integration weights remain with the caller.
"""
function shift_vector_component(
    response_kernel::Array{ComplexF64, 5},
    band_selection::Tuple{Vector{Int}, Vector{Int}},
    tensor_indices::Vector{Int},
)
    a, b, c = tensor_indices
    conduction, valence = band_selection
    total = COMPLEX_ZERO
    count = 0
    @inbounds for nc in conduction
        for nv in valence
            total += response_kernel[nc, nv, a, b, c]
            count += 1
        end
    end
    count > 0 || error(
        "Invalid shift-vector band_selection=$(band_selection); band groups must produce at least one pair.",
    )
    return total / count
end

"""
Construct forward/backward geometric loop products and store their finite-log
derivative along `a` for optical directions `(b,c)`. At finite photon momentum,
the loop connects `k-q/2` valence and `k+q/2` conduction slots; basis correction
uses fractional Wannier centers without changing the source-gauge transport.
Results occupy `[n,m,a,b,c]`, with the existing zero-loop and log-branch policy;
Runtime owns output normalization and deterministic reduction.
"""
function compute_geometric_loop_shift_vector_kernel!(
    response_kernel::Array{ComplexF64, 5},
    forward_loop_links::Array{ComplexF64, 4},
    backward_loop_links::Array{ComplexF64, 4},
    forward_overlap_1::Matrix{ComplexF64},
    forward_overlap_2::Matrix{ComplexF64},
    forward_overlap_3::Matrix{ComplexF64},
    backward_overlap_1::Matrix{ComplexF64},
    backward_overlap_2::Matrix{ComplexF64},
    backward_overlap_3::Matrix{ComplexF64},
    central_overlap_4::Matrix{ComplexF64},
    forward_third_insertions::Array{ComplexF64, 3},
    backward_third_insertions::Array{ComplexF64, 3},
    central_second_insertions::Array{ComplexF64, 3},
    loop_link_valid::BitArray{4},
    valence_central_data::GeometricLoopMatrixData,
    conduction_central_data::GeometricLoopMatrixData,
    valence_forward_data::GeometricLoopMatrixData,
    conduction_forward_data::GeometricLoopMatrixData,
    valence_backward_data::GeometricLoopMatrixData,
    conduction_backward_data::GeometricLoopMatrixData,
    scratch::GeometricLoopMatrixWorkspace,
    kpoint::Vector{Float64},
    photon_momentum_fractional::Vector{Float64},
    finite_difference_vectors::Matrix{Float64},
    denominator_regularization::Float64,
    finite_difference_step::Float64,
    spatial_dimension::Int64,
    model::TightBindingModel,
    num_orbitals::Int64,
    band_start::Int64,
    band_end::Int64,
    ;
    tensor_indices::Union{Nothing, AbstractVector{<:Integer}} = nothing,
)
    _clear_response_kernel!(response_kernel, tensor_indices)
    kv_0P = kpoint - 0.5 * photon_momentum_fractional
    kc_0P = kpoint + 0.5 * photon_momentum_fractional
    has_photon_shift = any(!iszero, photon_momentum_fractional)
    valence_photon_step = has_photon_shift ? -1 : 0
    conduction_photon_step = has_photon_shift ? 1 : 0
    bind_kpoint_offset!(valence_central_data, scratch, KPointOffset((0, 0, 0), valence_photon_step))
    bind_kpoint_offset!(
        conduction_central_data,
        scratch,
        KPointOffset((0, 0, 0), conduction_photon_step),
    )
    compute_geometric_loop_central_overlap!(
        central_overlap_4,
        conduction_central_data,
        valence_central_data,
    )
    second_directions = tensor_indices === nothing ? (1:spatial_dimension) : (tensor_indices[2],)
    third_directions = tensor_indices === nothing ? (1:spatial_dimension) : (tensor_indices[3],)
    compute_geometric_loop_second_insertions!(
        central_second_insertions,
        valence_central_data,
        conduction_central_data,
        central_overlap_4,
        second_directions,
    )

    derivative_axes = tensor_indices === nothing ? (1:spatial_dimension) : (tensor_indices[1],)
    @inbounds for a in derivative_axes
        local kv_pP = kpoint - 0.5 * photon_momentum_fractional + finite_difference_vectors[:, a]
        local forward_offset = ntuple(direction -> direction == a ? 1 : 0, 3)
        local backward_offset = ntuple(direction -> direction == a ? -1 : 0, 3)
        bind_kpoint_offset!(
            valence_forward_data,
            scratch,
            KPointOffset(forward_offset, valence_photon_step),
        )
        compute_kpoint!(
            valence_forward_data,
            scratch,
            model,
            kv_pP;
            denominator_regularization = denominator_regularization,
            spatial_dimension = spatial_dimension,
        )
        local kc_pP = kpoint + 0.5 * photon_momentum_fractional + finite_difference_vectors[:, a]
        bind_kpoint_offset!(
            conduction_forward_data,
            scratch,
            KPointOffset(forward_offset, conduction_photon_step),
        )
        compute_kpoint!(
            conduction_forward_data,
            scratch,
            model,
            kc_pP;
            denominator_regularization = denominator_regularization,
            spatial_dimension = spatial_dimension,
        )
        local kv_mP = kpoint - 0.5 * photon_momentum_fractional - finite_difference_vectors[:, a]
        bind_kpoint_offset!(
            valence_backward_data,
            scratch,
            KPointOffset(backward_offset, valence_photon_step),
        )
        compute_kpoint!(
            valence_backward_data,
            scratch,
            model,
            kv_mP;
            denominator_regularization = denominator_regularization,
            spatial_dimension = spatial_dimension,
        )
        local kc_mP = kpoint + 0.5 * photon_momentum_fractional - finite_difference_vectors[:, a]
        bind_kpoint_offset!(
            conduction_backward_data,
            scratch,
            KPointOffset(backward_offset, conduction_photon_step),
        )
        compute_kpoint!(
            conduction_backward_data,
            scratch,
            model,
            kc_mP;
            denominator_regularization = denominator_regularization,
            spatial_dimension = spatial_dimension,
        )

        compute_geometric_loop_shifted_overlaps!(
            forward_overlap_1,
            forward_overlap_2,
            forward_overlap_3,
            backward_overlap_1,
            backward_overlap_2,
            backward_overlap_3,
            valence_central_data,
            conduction_central_data,
            valence_forward_data,
            conduction_forward_data,
            valence_backward_data,
            conduction_backward_data,
        )
        compute_geometric_loop_third_insertions!(
            forward_third_insertions,
            valence_forward_data,
            conduction_forward_data,
            forward_overlap_2,
            third_directions,
        )
        compute_geometric_loop_third_insertions!(
            backward_third_insertions,
            valence_backward_data,
            conduction_backward_data,
            backward_overlap_2,
            third_directions,
        )

        forward_loop_links .= COMPLEX_ZERO
        backward_loop_links .= COMPLEX_ZERO
        fill!(loop_link_valid, false)
        response_pairs =
            tensor_indices === nothing ?
            Iterators.product(1:spatial_dimension, 1:spatial_dimension) :
            ((tensor_indices[2], tensor_indices[3]),)
        for n in band_start:band_end
            for m in band_start:band_end
                for (b, c) in response_pairs
                    conduction_key = conduction_central_data.degeneracy_group_starts[n]
                    valence_key = valence_central_data.degeneracy_group_starts[m]
                    if !loop_link_valid[conduction_key, valence_key, b, c]
                        forward_loop_links[conduction_key, valence_key, b, c] =
                            geometric_loop_overlap_block_contraction_precomputed(
                                valence_central_data,
                                conduction_central_data,
                                forward_overlap_1,
                                forward_overlap_3,
                                forward_third_insertions,
                                central_second_insertions,
                                m,
                                n,
                                b,
                                c,
                            )
                        backward_loop_links[conduction_key, valence_key, b, c] =
                            geometric_loop_overlap_block_contraction_precomputed(
                                valence_central_data,
                                conduction_central_data,
                                backward_overlap_1,
                                backward_overlap_3,
                                backward_third_insertions,
                                central_second_insertions,
                                m,
                                n,
                                b,
                                c,
                            )
                        loop_link_valid[conduction_key, valence_key, b, c] = true
                    end
                    forward_loop_links[n, m, b, c] =
                        forward_loop_links[conduction_key, valence_key, b, c]
                    backward_loop_links[n, m, b, c] =
                        backward_loop_links[conduction_key, valence_key, b, c]
                    response_kernel[n, m, a, b, c] = finite_loop_log_derivative(
                        forward_loop_links[n, m, b, c],
                        backward_loop_links[n, m, b, c],
                        finite_difference_step,
                    )
                end
            end
        end
    end
    return response_kernel
end
