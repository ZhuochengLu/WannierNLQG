"""
Compute the geometric-loop quantum Hermitian connection kernel in place.

For each `(a,b,c)` this forms the central-difference derivative along `a` of a
three-link overlap/position loop carrying insertions along `b` and `c`. Valence
and conduction centers are `k-q/2` and `k+q/2`; the q=0 path aliases their central
matrix data exactly. Degenerate blocks are expanded before loop construction and
the returned `[n,m,a,b,c]` kernel retains the established Hamiltonian/source-gauge
transport convention. Runtime applies no formula changes here and remains the
owner of output normalization and reduction.
"""
function compute_geometric_loop_quantum_hermitian_connection_kernel!(
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
    band_selection::Tuple{Vector{Int}, Vector{Int}},
    degeneracy_threshold::Float64,
    ;
    tensor_indices::Union{Nothing, AbstractVector{<:Integer}} = nothing,
)
    _clear_response_kernel!(response_kernel, tensor_indices)

    q_is_zero = all(x -> abs(x) <= eps(Float64), photon_momentum_fractional)
    kv_0P = kpoint .- 0.5 .* photon_momentum_fractional
    kc_0P = kpoint .+ 0.5 .* photon_momentum_fractional
    compute_kpoint!(
        valence_central_data,
        scratch,
        model,
        kv_0P;
        denominator_regularization = denominator_regularization,
        spatial_dimension = spatial_dimension,
    )
    if q_is_zero
        conduction_central_data = valence_central_data
    else
        compute_kpoint!(
            conduction_central_data,
            scratch,
            model,
            kc_0P;
            denominator_regularization = denominator_regularization,
            spatial_dimension = spatial_dimension,
        )
    end
    mark_degenerate_groups!(valence_central_data, degeneracy_threshold)
    if !q_is_zero
        mark_degenerate_groups!(conduction_central_data, degeneracy_threshold)
    end

    band_start, band_end = band_selection_window(band_selection)
    band_start, band_end = expand_band_window_for_groups(
        band_start,
        band_end,
        valence_central_data,
        conduction_central_data,
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
        kv_pP = kpoint .- 0.5 .* photon_momentum_fractional .+ finite_difference_vectors[:, a]
        kc_pP = kpoint .+ 0.5 .* photon_momentum_fractional .+ finite_difference_vectors[:, a]
        kv_mP = kpoint .- 0.5 .* photon_momentum_fractional .- finite_difference_vectors[:, a]
        kc_mP = kpoint .+ 0.5 .* photon_momentum_fractional .- finite_difference_vectors[:, a]

        compute_kpoint!(
            valence_forward_data,
            scratch,
            model,
            kv_pP;
            denominator_regularization = denominator_regularization,
            spatial_dimension = spatial_dimension,
        )
        compute_kpoint!(
            valence_backward_data,
            scratch,
            model,
            kv_mP;
            denominator_regularization = denominator_regularization,
            spatial_dimension = spatial_dimension,
        )
        if q_is_zero
            conduction_forward_data = valence_forward_data
            conduction_backward_data = valence_backward_data
        else
            compute_kpoint!(
                conduction_forward_data,
                scratch,
                model,
                kc_pP;
                denominator_regularization = denominator_regularization,
                spatial_dimension = spatial_dimension,
            )
            compute_kpoint!(
                conduction_backward_data,
                scratch,
                model,
                kc_mP;
                denominator_regularization = denominator_regularization,
                spatial_dimension = spatial_dimension,
            )
        end
        mark_degenerate_groups!(valence_forward_data, degeneracy_threshold)
        mark_degenerate_groups!(valence_backward_data, degeneracy_threshold)
        if !q_is_zero
            mark_degenerate_groups!(conduction_forward_data, degeneracy_threshold)
            mark_degenerate_groups!(conduction_backward_data, degeneracy_threshold)
        end

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

        fill!(forward_loop_links, 0.0 + 0.0im)
        fill!(backward_loop_links, 0.0 + 0.0im)
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
                end
            end
        end

        for n in band_start:band_end
            for m in band_start:band_end
                for (b, c) in response_pairs
                    W_pP = 0.5 * forward_loop_links[n, m, b, c]
                    W_mP = 0.5 * backward_loop_links[n, m, b, c]
                    response_kernel[n, m, a, b, c] =
                        0.25 * 0.25 * (W_pP - W_mP) / (2.0 * finite_difference_step)
                end
            end
        end
    end

    return response_kernel
end

"""
Compute the Convention-covariant Geometric-loop quantum Hermitian connection.

The shifted velocity insertion is transported to the central valence and
conduction frames and completed with the aligned external connection on both
sides. The established QHC factor, band ordering, degenerate-block weights, and
output layout are retained; Runtime remains responsible for output reduction.
"""
function compute_geometric_loop_quantum_hermitian_connection_kernel!(
    ws::GeometricLoopResponseWorkspace,
    kpoint::Vector{Float64},
    photon_momentum_fractional::Vector{Float64},
    finite_difference_vectors::Matrix{Float64},
    wannier_centers_fractional::Matrix{Float64},
    denominator_regularization::Float64,
    finite_difference_step::Float64,
    spatial_dimension::Int64,
    model::TightBindingModel,
    band_selection::Tuple{Vector{Int}, Vector{Int}},
    degeneracy_threshold::Float64;
    tensor_indices::Union{Nothing, AbstractVector{<:Integer}} = nothing,
)
    _clear_response_kernel!(ws.response_kernel, tensor_indices)
    has_photon_shift = any(!iszero, photon_momentum_fractional)
    valence_photon_step = has_photon_shift ? -1 : 0
    conduction_photon_step = has_photon_shift ? 1 : 0
    bind_kpoint_offset!(
        ws.valence_central_data,
        ws.scratch,
        KPointOffset((0, 0, 0), valence_photon_step),
    )
    bind_kpoint_offset!(
        ws.conduction_central_data,
        ws.scratch,
        KPointOffset((0, 0, 0), conduction_photon_step),
    )
    compute_kpoint!(
        ws.valence_central_data,
        ws.scratch,
        model,
        kpoint - 0.5 * photon_momentum_fractional;
        denominator_regularization,
        spatial_dimension,
    )
    compute_kpoint!(
        ws.conduction_central_data,
        ws.scratch,
        model,
        kpoint + 0.5 * photon_momentum_fractional;
        denominator_regularization,
        spatial_dimension,
    )
    mark_degenerate_groups!(ws.valence_central_data, degeneracy_threshold)
    mark_degenerate_groups!(ws.conduction_central_data, degeneracy_threshold)
    band_start, band_end = band_selection_window(band_selection)
    band_start, band_end = expand_band_window_for_groups(
        band_start,
        band_end,
        ws.valence_central_data,
        ws.conduction_central_data,
    )

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
            third_directions,
        )
        fill!(ws.forward_loop_links, COMPLEX_ZERO)
        fill!(ws.loop_link_valid, false)
        response_pairs =
            tensor_indices === nothing ?
            Iterators.product(1:spatial_dimension, 1:spatial_dimension) :
            ((tensor_indices[2], tensor_indices[3]),)
        for n in band_start:band_end
            for m in band_start:band_end
                conduction_key = ws.conduction_central_data.degeneracy_group_starts[n]
                valence_key = ws.valence_central_data.degeneracy_group_starts[m]
                prepare_geometric_loop_covariant_derivative_block!(
                    ws,
                    a,
                    m,
                    n,
                    third_directions,
                    finite_difference_step,
                )
                for (b, c) in response_pairs
                    if !ws.loop_link_valid[conduction_key, valence_key, b, c]
                        ws.forward_loop_links[conduction_key, valence_key, b, c] =
                            geometric_loop_covariant_block_contraction(ws, m, n, b, c)
                        ws.loop_link_valid[conduction_key, valence_key, b, c] = true
                    end
                    ws.response_kernel[n, m, a, b, c] =
                        0.03125 * ws.forward_loop_links[conduction_key, valence_key, b, c]
                end
            end
        end
    end
    return ws.response_kernel
end
