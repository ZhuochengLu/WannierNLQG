# Shared geometric-loop current kernel used by q=0 and finite-q shift-current responses.

"""
Build the forward/backward overlap loops whose central difference along `a`
represents the covariant derivative of the optical matrix elements in directions
`b` and `c`. The same hot kernel serves q=0 shift current and finite-q
photon-drag shift current; valence/conduction centers remain `k-q/2` and `k+q/2`
and keep their own slot-local Fourier state. Results are stored at
`[n,m,a,b,c]`; occupations, broadening, prefactors, and reduction are external.
"""
function compute_geometric_loop_shift_current_kernel!(
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
    active_pair_mask::Union{Nothing, AbstractMatrix{Bool}} = nothing,
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
    insertion_directions =
        tensor_indices === nothing ? (1:spatial_dimension) :
        tensor_indices[2] == tensor_indices[3] ? (tensor_indices[2],) :
        (tensor_indices[2], tensor_indices[3])
    compute_geometric_loop_second_insertions!(
        central_second_insertions,
        valence_central_data,
        conduction_central_data,
        central_overlap_4,
        insertion_directions,
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
            insertion_directions,
        )
        compute_geometric_loop_third_insertions!(
            backward_third_insertions,
            valence_backward_data,
            conduction_backward_data,
            backward_overlap_2,
            insertion_directions,
        )

        backward_loop_links .= 0.0
        forward_loop_links .= 0.0
        fill!(loop_link_valid, false)
        for n in band_start:band_end
            for m in band_start:band_end
                active_pair_mask !== nothing && !active_pair_mask[n, m] && continue
                polarization_pairs =
                    tensor_indices === nothing ?
                    Iterators.product(1:spatial_dimension, 1:spatial_dimension) :
                    ((tensor_indices[2], tensor_indices[3]), (tensor_indices[3], tensor_indices[2]))
                for (b, c) in polarization_pairs
                    valence_key = valence_central_data.degeneracy_group_starts[n]
                    conduction_key = conduction_central_data.degeneracy_group_starts[m]
                    # Formula convention for shift-current response:
                    # response_kernel[n,m] is stored with n=valence leg and
                    # m=conduction leg.  The overlap contraction takes
                    # (valence_band, conduction_band), so pass (n,m).
                    if !loop_link_valid[valence_key, conduction_key, b, c]
                        forward_loop_links[valence_key, conduction_key, b, c] =
                            geometric_loop_overlap_block_contraction_precomputed(
                                valence_central_data,
                                conduction_central_data,
                                forward_overlap_1,
                                forward_overlap_3,
                                forward_third_insertions,
                                central_second_insertions,
                                n,
                                m,
                                b,
                                c,
                            )
                        backward_loop_links[valence_key, conduction_key, b, c] =
                            geometric_loop_overlap_block_contraction_precomputed(
                                valence_central_data,
                                conduction_central_data,
                                backward_overlap_1,
                                backward_overlap_3,
                                backward_third_insertions,
                                central_second_insertions,
                                n,
                                m,
                                b,
                                c,
                            )
                        loop_link_valid[valence_key, conduction_key, b, c] = true
                    end
                    forward_loop_links[n, m, b, c] =
                        forward_loop_links[valence_key, conduction_key, b, c]
                    backward_loop_links[n, m, b, c] =
                        backward_loop_links[valence_key, conduction_key, b, c]
                end
            end
        end

        for n in band_start:band_end
            for m in band_start:band_end
                active_pair_mask !== nothing && !active_pair_mask[n, m] && continue
                response_pairs =
                    tensor_indices === nothing ?
                    Iterators.product(1:spatial_dimension, 1:spatial_dimension) :
                    ((tensor_indices[2], tensor_indices[3]),)
                for (b, c) in response_pairs
                    W_pP =
                        0.5 *
                        (forward_loop_links[n, m, b, c] - conj(forward_loop_links[n, m, c, b]))
                    W_mP =
                        0.5 *
                        (backward_loop_links[n, m, b, c] - conj(backward_loop_links[n, m, c, b]))
                    # The manuscript geometric-loop derivative is
                    # \hat D_p = i partial_p.  Store that +i directly in
                    # response_kernel[n,m] and use a real velocity-gauge prefactor.
                    response_kernel[n, m, a, b, c] =
                        1.0im * 0.25 * (W_pP - W_mP) / (2.0 * finite_difference_step)
                end
            end
        end
    end
    return response_kernel
end

"""
For each `(a,b,c)`, the shifted velocity insertion is transported into the
central valence/conduction frames, differentiated by a centered stencil, and
completed with the aligned external Wannier-basis connection on both sides.
The established `i*0.25` coefficient, conjugate polarization antisymmetrization,
band order, occupations, broadening, and physical prefactors remain unchanged.
"""
function compute_geometric_loop_shift_current_kernel!(
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
    active_pair_mask::Union{Nothing, AbstractMatrix{Bool}} = nothing,
    tensor_indices::Union{Nothing, AbstractVector{<:Integer}} = nothing,
)
    _clear_response_kernel!(ws.response_kernel, tensor_indices)
    derivative_axes = tensor_indices === nothing ? (1:spatial_dimension) : (tensor_indices[1],)
    insertion_directions =
        tensor_indices === nothing ? (1:spatial_dimension) :
        tensor_indices[2] == tensor_indices[3] ? (tensor_indices[2],) :
        (tensor_indices[2], tensor_indices[3])
    prepare_geometric_loop_covariant_center!(
        ws,
        wannier_centers_fractional,
        model,
        insertion_directions,
        insertion_directions,
    )
    prepare_geometric_loop_external_connections!(
        ws,
        wannier_centers_fractional,
        model,
        derivative_axes,
    )

    @inbounds for a in derivative_axes
        prepare_geometric_loop_covariant_axis!(
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
            insertion_directions,
        )
        fill!(ws.forward_loop_links, COMPLEX_ZERO)
        fill!(ws.loop_link_valid, false)
        for n in band_start:band_end
            for m in band_start:band_end
                active_pair_mask !== nothing && !active_pair_mask[n, m] && continue
                polarization_pairs =
                    tensor_indices === nothing ?
                    Iterators.product(1:spatial_dimension, 1:spatial_dimension) :
                    ((tensor_indices[2], tensor_indices[3]), (tensor_indices[3], tensor_indices[2]))
                valence_key = ws.valence_central_data.degeneracy_group_starts[n]
                conduction_key = ws.conduction_central_data.degeneracy_group_starts[m]
                prepare_geometric_loop_covariant_derivative_block!(
                    ws,
                    a,
                    n,
                    m,
                    insertion_directions,
                    finite_difference_step,
                )
                for (b, c) in polarization_pairs
                    if !ws.loop_link_valid[valence_key, conduction_key, b, c]
                        ws.forward_loop_links[valence_key, conduction_key, b, c] =
                            geometric_loop_covariant_block_contraction(ws, n, m, b, c)
                        ws.loop_link_valid[valence_key, conduction_key, b, c] = true
                    end
                    ws.forward_loop_links[n, m, b, c] =
                        ws.forward_loop_links[valence_key, conduction_key, b, c]
                end
            end
        end

        for n in band_start:band_end
            for m in band_start:band_end
                active_pair_mask !== nothing && !active_pair_mask[n, m] && continue
                response_pairs =
                    tensor_indices === nothing ?
                    Iterators.product(1:spatial_dimension, 1:spatial_dimension) :
                    ((tensor_indices[2], tensor_indices[3]),)
                for (b, c) in response_pairs
                    phi_bc = ws.forward_loop_links[n, m, b, c]
                    phi_cb = ws.forward_loop_links[n, m, c, b]
                    ws.response_kernel[n, m, a, b, c] = 1.0im * 0.25 * 0.5 * (phi_bc - conj(phi_cb))
                end
            end
        end
    end
    return ws.response_kernel
end
