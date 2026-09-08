"""
Projector quantum Hermitian connection kernel.
"""
function projector_response_axis_pairs(spatial_dimension::Int64)
    pairs = Tuple{Int64, Int64}[]
    for a in 1:(spatial_dimension - 1)
        for b in (a + 1):spatial_dimension
            push!(pairs, (a, b))
        end
    end
    return pairs
end

"""
Populate central/shifted projector data and requested first/second derivatives using matched Cartesian stencils.

Respect active/required bands and degeneracy closure; mutate reusable workspace slots without occupations, physical prefactors or k-point integration.

Prepare projector response cache in place.
"""
function prepare_projector_response_cache!(
    ws::ProjectorResponseWorkspace,
    kpoint::Vector{Float64},
    finite_difference_vectors::Matrix{Float64},
    model::TightBindingModel,
    num_orbitals::Int64,
    spatial_dimension::Int64;
    denominator_regularization::Float64,
    degeneracy_threshold::Float64,
    finite_difference_step::Float64,
    axes::AbstractVector{<:Integer} = collect(1:spatial_dimension),
    axis_pairs::AbstractVector{<:Tuple{Int64, Int64}} = projector_response_axis_pairs(
        spatial_dimension,
    ),
    active_bands::Union{Nothing, AbstractVector{Bool}} = nothing,
    required_bands::Union{Nothing, AbstractVector{Bool}} = nothing,
)
    scratch = ws.scratch
    central_data = ws.central_data
    bind_kpoint_offset!(central_data, scratch, KPointOffset())
    compute_kpoint!(
        central_data,
        scratch,
        model,
        kpoint;
        denominator_regularization,
        spatial_dimension,
    )
    prepare_projector_covariant_geometry!(central_data, scratch, model)
    mark_degenerate_groups!(central_data, degeneracy_threshold)
    if active_bands === nothing && required_bands === nothing
        fill!(ws.active_bands, true)
    else
        fill!(ws.active_bands, false)
        if active_bands !== nothing
            @inbounds for band in 1:num_orbitals
                ws.active_bands[band] |= active_bands[band]
            end
        end
        if required_bands !== nothing
            @inbounds for band in 1:num_orbitals
                ws.active_bands[band] |= required_bands[band]
            end
        end
        @inbounds for band in 1:num_orbitals
            ws.active_bands[band] || continue
            group_start = central_data.degeneracy_group_starts[band]
            group_stop = central_data.degeneracy_group_stops[band]
            for group_band in group_start:group_stop
                ws.active_bands[group_band] = true
            end
        end
    end
    projector_fill_projectors_from_groups!(
        central_data,
        num_orbitals;
        active_bands = ws.active_bands,
    )

    for axis in axes
        k_pP = kpoint + finite_difference_vectors[:, axis]
        bind_kpoint_offset!(
            ws.forward_data,
            scratch,
            KPointOffset(ntuple(direction -> direction == axis ? 1 : 0, 3), 0),
        )
        compute_projector_spectrum!(
            ws.forward_data,
            scratch,
            model,
            k_pP;
            denominator_regularization,
            spatial_dimension,
        )
        projector_projectors!(
            ws.forward_data,
            num_orbitals,
            central_data.degeneracy_weights,
            central_data.degeneracy_group_starts,
            central_data.degeneracy_group_stops,
            active_bands = ws.active_bands,
        )
        @inbounds for band in 1:num_orbitals
            ws.active_bands[band] || continue
            @views transport_projector_matrix_to_reference!(
                ws.forward_projectors[band, :, :, axis],
                ws.forward_data.projectors[band, :, :],
                central_data,
                ws.forward_data,
                scratch,
            )
        end

        k_mP = kpoint - finite_difference_vectors[:, axis]
        bind_kpoint_offset!(
            ws.backward_data,
            scratch,
            KPointOffset(ntuple(direction -> direction == axis ? -1 : 0, 3), 0),
        )
        compute_projector_spectrum!(
            ws.backward_data,
            scratch,
            model,
            k_mP;
            denominator_regularization,
            spatial_dimension,
        )
        projector_projectors!(
            ws.backward_data,
            num_orbitals,
            central_data.degeneracy_weights,
            central_data.degeneracy_group_starts,
            central_data.degeneracy_group_stops,
            active_bands = ws.active_bands,
        )
        @inbounds for band in 1:num_orbitals
            ws.active_bands[band] || continue
            @views transport_projector_matrix_to_reference!(
                ws.backward_projectors[band, :, :, axis],
                ws.backward_data.projectors[band, :, :],
                central_data,
                ws.backward_data,
                scratch,
            )
        end

        projector_diff_projectors!(
            central_data,
            @view(ws.forward_projectors[:, :, :, axis]),
            @view(ws.backward_projectors[:, :, :, axis]),
            finite_difference_step,
            num_orbitals,
            axis,
            active_bands = ws.active_bands,
        )
        projector_pure_diff_projectors!(
            @view(ws.forward_projectors[:, :, :, axis]),
            @view(ws.backward_projectors[:, :, :, axis]),
            finite_difference_step,
            num_orbitals,
            axis,
            ws.pure_projector_derivatives,
            active_bands = ws.active_bands,
        )
    end

    for (axis1, axis2) in axis_pairs
        axis1 == axis2 && continue
        k_ppP = kpoint + finite_difference_vectors[:, axis1] + finite_difference_vectors[:, axis2]
        bind_kpoint_offset!(
            ws.second_forward_data,
            scratch,
            KPointOffset(
                ntuple(direction -> direction == axis1 || direction == axis2 ? 1 : 0, 3),
                0,
            ),
        )
        compute_projector_spectrum!(
            ws.second_forward_data,
            scratch,
            model,
            k_ppP;
            denominator_regularization,
            spatial_dimension,
        )
        projector_projectors!(
            ws.second_forward_data,
            num_orbitals,
            central_data.degeneracy_weights,
            central_data.degeneracy_group_starts,
            central_data.degeneracy_group_stops,
            active_bands = ws.active_bands,
        )
        @inbounds for band in 1:num_orbitals
            ws.active_bands[band] || continue
            @views transport_projector_matrix_to_reference!(
                ws.second_forward_data.projectors[band, :, :],
                ws.second_forward_data.projectors[band, :, :],
                central_data,
                ws.second_forward_data,
                scratch,
            )
        end

        k_mmP = kpoint - finite_difference_vectors[:, axis1] - finite_difference_vectors[:, axis2]
        bind_kpoint_offset!(
            ws.second_backward_data,
            scratch,
            KPointOffset(
                ntuple(direction -> direction == axis1 || direction == axis2 ? -1 : 0, 3),
                0,
            ),
        )
        compute_projector_spectrum!(
            ws.second_backward_data,
            scratch,
            model,
            k_mmP;
            denominator_regularization,
            spatial_dimension,
        )
        projector_projectors!(
            ws.second_backward_data,
            num_orbitals,
            central_data.degeneracy_weights,
            central_data.degeneracy_group_starts,
            central_data.degeneracy_group_stops,
            active_bands = ws.active_bands,
        )
        @inbounds for band in 1:num_orbitals
            ws.active_bands[band] || continue
            @views transport_projector_matrix_to_reference!(
                ws.second_backward_data.projectors[band, :, :],
                ws.second_backward_data.projectors[band, :, :],
                central_data,
                ws.second_backward_data,
                scratch,
            )
        end

        projector_second_diff_projectors!(
            central_data,
            ws.forward_projectors,
            ws.backward_projectors,
            ws.second_forward_data.projectors,
            ws.second_backward_data.projectors,
            finite_difference_step,
            num_orbitals,
            axis1,
            axis2,
            ws.pure_projector_derivatives,
            active_bands = ws.active_bands,
        )
    end
    return ws
end

"""
Using already prepared covariant projector derivatives, store the trace
`C_cv^{a;bc}` at `[conduction,valence,a,b,c]`. The result is multiplied by the
central degeneracy weights of both subspaces. This path deliberately performs no
band-index exchange and no `(b,c)` symmetrization. Scratch matrices are
caller-owned; gauge, finite-difference order, output normalization, and reduction
are unchanged.
"""
function compute_projector_quantum_hermitian_connection_from_cache!(
    response_kernel::Array{ComplexF64, 5},
    central_data::ProjectorMatrixData,
    band_selection::Tuple{Vector{Int}, Vector{Int}},
    tensor_indices::Vector{Int},
    kernel_tmp1::Matrix{ComplexF64},
    kernel_tmp2::Matrix{ComplexF64},
    kernel_tmp3::Matrix{ComplexF64},
    kernel_tmp4::Matrix{ComplexF64},
    kernel_tmp5::Matrix{ComplexF64},
    kernel_tmp6::Matrix{ComplexF64},
)
    _clear_response_kernel!(response_kernel, tensor_indices)
    a, b, c = tensor_indices
    conduction, valence = band_selection
    for nc in conduction
        for nv in valence
            deg_weight = central_data.degeneracy_weights[nv] * central_data.degeneracy_weights[nc]
            C_cvabc = projector_qhc_trace_c_cvabc!(
                kernel_tmp1,
                kernel_tmp2,
                kernel_tmp3,
                central_data,
                nv,
                nc,
                a,
                b,
                c,
            )

            # Projector QHC convention for this implementation:
            # store only C_cv^{a;bc} at response_kernel[conduction,valence,a,b,c].
            # No band-index exchange or b/c tensor-index symmetrization is
            # performed in the Projector QHC path.
            response_kernel[nc, nv, a, b, c] = deg_weight * C_cvabc
        end
    end
    return response_kernel
end

"""
Prepare the central, axis-shifted, and mixed-axis projector stencils needed for
`C_cv^{a;bc}`, then delegate to the cache contraction. `tensor_indices=(a,b,c)`
fixes derivative and insertion directions; `band_selection=(conduction,valence)`
is expanded only at degeneracy boundaries. The routine preserves the central
difference stencil, Hamiltonian gauge, native convention connection, workspace
ownership, and caller-controlled normalization.
"""
function compute_projector_quantum_hermitian_connection_kernel!(
    response_kernel::Array{ComplexF64, 5},
    scratch::ProjectorMatrixWorkspace,
    central_data::ProjectorMatrixData,
    forward_data::ProjectorMatrixData,
    backward_data::ProjectorMatrixData,
    second_forward_data::ProjectorMatrixData,
    second_backward_data::ProjectorMatrixData,
    forward_projectors::Array{ComplexF64, 4},
    backward_projectors::Array{ComplexF64, 4},
    pure_projector_derivatives::Array{ComplexF64, 4},
    kernel_tmp1::Matrix{ComplexF64},
    kernel_tmp2::Matrix{ComplexF64},
    kernel_tmp3::Matrix{ComplexF64},
    kernel_tmp4::Matrix{ComplexF64},
    kernel_tmp5::Matrix{ComplexF64},
    kernel_tmp6::Matrix{ComplexF64},
    kpoint::Vector{Float64},
    finite_difference_vectors::Array{Float64, 2},
    tensor_indices::Vector{Int},
    band_selection::Tuple{Vector{Int}, Vector{Int}},
    finite_difference_step::Float64,
    denominator_regularization::Float64,
    spatial_dimension::Int64,
    model::TightBindingModel,
    num_orbitals::Int64,
    degeneracy_threshold::Float64,
)
    compute_kpoint!(
        central_data,
        scratch,
        model,
        kpoint;
        denominator_regularization = denominator_regularization,
        spatial_dimension = spatial_dimension,
    )
    projector_reference_projectors!(central_data, num_orbitals, degeneracy_threshold)
    _clear_response_kernel!(response_kernel, tensor_indices)

    a, b, c = tensor_indices
    needed_axes = unique(tensor_indices)
    for axis in needed_axes
        local k_pP = kpoint + finite_difference_vectors[:, axis]
        compute_projector_spectrum!(
            forward_data,
            scratch,
            model,
            k_pP;
            denominator_regularization = denominator_regularization,
            spatial_dimension = spatial_dimension,
        )
        projector_projectors!(
            forward_data,
            num_orbitals,
            central_data.degeneracy_weights,
            central_data.degeneracy_group_starts,
            central_data.degeneracy_group_stops,
        )
        forward_projectors[:, :, :, axis] .= forward_data.projectors

        local k_mP = kpoint - finite_difference_vectors[:, axis]
        compute_projector_spectrum!(
            backward_data,
            scratch,
            model,
            k_mP;
            denominator_regularization = denominator_regularization,
            spatial_dimension = spatial_dimension,
        )
        projector_projectors!(
            backward_data,
            num_orbitals,
            central_data.degeneracy_weights,
            central_data.degeneracy_group_starts,
            central_data.degeneracy_group_stops,
        )
        backward_projectors[:, :, :, axis] .= backward_data.projectors

        projector_diff_projectors!(
            central_data,
            forward_data.projectors,
            backward_data.projectors,
            finite_difference_step,
            num_orbitals,
            axis,
        )
        projector_pure_diff_projectors!(
            forward_data.projectors,
            backward_data.projectors,
            finite_difference_step,
            num_orbitals,
            axis,
            pure_projector_derivatives,
        )
    end

    needed_pairs = Tuple{Int64, Int64}[]
    for (axis1, axis2) in ((a, c), (a, b))
        if axis1 != axis2
            pair = axis1 < axis2 ? (axis1, axis2) : (axis2, axis1)
            if !(pair in needed_pairs)
                push!(needed_pairs, pair)
            end
        end
    end
    for (axis1, axis2) in needed_pairs
        local k_ppP =
            kpoint + finite_difference_vectors[:, axis1] + finite_difference_vectors[:, axis2]
        compute_projector_spectrum!(
            second_forward_data,
            scratch,
            model,
            k_ppP;
            denominator_regularization = denominator_regularization,
            spatial_dimension = spatial_dimension,
        )
        projector_projectors!(
            second_forward_data,
            num_orbitals,
            central_data.degeneracy_weights,
            central_data.degeneracy_group_starts,
            central_data.degeneracy_group_stops,
        )

        local k_mmP =
            kpoint - finite_difference_vectors[:, axis1] - finite_difference_vectors[:, axis2]
        compute_projector_spectrum!(
            second_backward_data,
            scratch,
            model,
            k_mmP;
            denominator_regularization = denominator_regularization,
            spatial_dimension = spatial_dimension,
        )
        projector_projectors!(
            second_backward_data,
            num_orbitals,
            central_data.degeneracy_weights,
            central_data.degeneracy_group_starts,
            central_data.degeneracy_group_stops,
        )

        projector_second_diff_projectors!(
            central_data,
            forward_projectors,
            backward_projectors,
            second_forward_data.projectors,
            second_backward_data.projectors,
            finite_difference_step,
            num_orbitals,
            axis1,
            axis2,
            pure_projector_derivatives,
        )
    end

    return compute_projector_quantum_hermitian_connection_from_cache!(
        response_kernel,
        central_data,
        band_selection,
        tensor_indices,
        kernel_tmp1,
        kernel_tmp2,
        kernel_tmp3,
        kernel_tmp4,
        kernel_tmp5,
        kernel_tmp6,
    )
end
