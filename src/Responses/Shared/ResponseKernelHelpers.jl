# Shared response-formula helpers used by multiple physical kernels.

using LinearAlgebra

"""
Compute tr(A * B) without allocating the product matrix.
"""
function projector_trace_two(A::AbstractMatrix{ComplexF64}, B::AbstractMatrix{ComplexF64})
    total = COMPLEX_ZERO
    n = size(A, 1)
    @inbounds for col in 1:n
        for row in 1:n
            total += A[row, col] * B[col, row]
        end
    end
    return total
end

"""
Compute tr(A * B * C) with one scratch matrix for A * B.
"""
function projector_trace_three!(
    temporary_ab::Matrix{ComplexF64},
    A::AbstractMatrix{ComplexF64},
    B::AbstractMatrix{ComplexF64},
    C::AbstractMatrix{ComplexF64},
)
    mul!(temporary_ab, A, B)
    return projector_trace_two(temporary_ab, C)
end

"""
Compute tr(A * B * C * D) with two scratch matrices for A * B and C * D.
"""
function projector_trace_four!(
    temporary_ab::Matrix{ComplexF64},
    temporary_cd::Matrix{ComplexF64},
    A::AbstractMatrix{ComplexF64},
    B::AbstractMatrix{ComplexF64},
    C::AbstractMatrix{ComplexF64},
    D::AbstractMatrix{ComplexF64},
)
    mul!(temporary_ab, A, B)
    mul!(temporary_cd, C, D)
    return projector_trace_two(temporary_ab, temporary_cd)
end

"""Compute `tr(A*B*C*D*E)` with three caller-owned scratch matrices."""
function projector_trace_five!(
    temporary_ab::Matrix{ComplexF64},
    temporary_cd::Matrix{ComplexF64},
    temporary_abcd::Matrix{ComplexF64},
    A::AbstractMatrix{ComplexF64},
    B::AbstractMatrix{ComplexF64},
    C::AbstractMatrix{ComplexF64},
    D::AbstractMatrix{ComplexF64},
    E::AbstractMatrix{ComplexF64},
)
    mul!(temporary_ab, A, B)
    mul!(temporary_cd, C, D)
    mul!(temporary_abcd, temporary_ab, temporary_cd)
    return projector_trace_two(temporary_abcd, E)
end

"""
Return a three-factor trace with the projector represented by selected eigenvector columns, reusing multiplication scratch.

Column ranges define the degenerate subspace; preserve factor order and apply no group or Brillouin-zone normalization.
"""
function projector_trace_three_low_rank!(
    temporary_1::Matrix{ComplexF64},
    temporary_2::Matrix{ComplexF64},
    eigenvectors::Matrix{ComplexF64},
    group_start::Int,
    group_stop::Int,
    A::AbstractMatrix{ComplexF64},
    B::AbstractMatrix{ComplexF64},
)
    group_size = group_stop - group_start + 1
    @views begin
        basis = eigenvectors[:, group_start:group_stop]
        work_1 = temporary_1[:, 1:group_size]
        work_2 = temporary_2[:, 1:group_size]
        mul!(work_1, B, basis)
        mul!(work_2, A, work_1)
        total = COMPLEX_ZERO
        @inbounds for group_column in 1:group_size
            for row in axes(eigenvectors, 1)
                total += conj(basis[row, group_column]) * work_2[row, group_column]
            end
        end
        return total
    end
end

"""
Return the ordered four-factor trace using low-rank eigenvector-column projectors and caller-owned scratch.

Retain the supplied subspace column ranges and multiplication order; no response prefactor is included.
"""
function projector_trace_four_low_rank!(
    temporary_1::Matrix{ComplexF64},
    temporary_2::Matrix{ComplexF64},
    temporary_3::Matrix{ComplexF64},
    eigenvectors::Matrix{ComplexF64},
    group_start::Int,
    group_stop::Int,
    A::AbstractMatrix{ComplexF64},
    B::AbstractMatrix{ComplexF64},
    C::AbstractMatrix{ComplexF64},
)
    group_size = group_stop - group_start + 1
    @views begin
        basis = eigenvectors[:, group_start:group_stop]
        work_1 = temporary_1[:, 1:group_size]
        work_2 = temporary_2[:, 1:group_size]
        work_3 = temporary_3[:, 1:group_size]
        mul!(work_1, C, basis)
        mul!(work_2, B, work_1)
        mul!(work_3, A, work_2)
        total = COMPLEX_ZERO
        @inbounds for group_column in 1:group_size
            for row in axes(eigenvectors, 1)
                total += conj(basis[row, group_column]) * work_3[row, group_column]
            end
        end
        return total
    end
end

"""Evaluate `tr(P*A*B*C*D)` with a low-rank outer projector `P`."""
function projector_trace_five_low_rank!(
    temporary_1::Matrix{ComplexF64},
    temporary_2::Matrix{ComplexF64},
    eigenvectors::Matrix{ComplexF64},
    group_start::Int,
    group_stop::Int,
    A::AbstractMatrix{ComplexF64},
    B::AbstractMatrix{ComplexF64},
    C::AbstractMatrix{ComplexF64},
    D::AbstractMatrix{ComplexF64},
)
    group_size = group_stop - group_start + 1
    @views begin
        basis = eigenvectors[:, group_start:group_stop]
        work_1 = temporary_1[:, 1:group_size]
        work_2 = temporary_2[:, 1:group_size]
        mul!(work_1, D, basis)
        mul!(work_2, C, work_1)
        mul!(work_1, B, work_2)
        mul!(work_2, A, work_1)
        total = COMPLEX_ZERO
        @inbounds for group_column in 1:group_size, row in axes(eigenvectors, 1)
            total += conj(basis[row, group_column]) * work_2[row, group_column]
        end
        return total
    end
end

"""
Compute the raw Projector QHC component C_cv^{a;bc}.

The component has the form tr(P_v * d_b P_c * d_ac P_v)
+ tr(P_v * d_b P_c * d_a P_c * d_c P_v).
"""
function projector_qhc_trace_c_cvabc!(
    temporary_1::Matrix{ComplexF64},
    temporary_2::Matrix{ComplexF64},
    temporary_3::Matrix{ComplexF64},
    central_data::ProjectorMatrixData,
    valence_band::Int64,
    conduction_band::Int64,
    a::Int64,
    b::Int64,
    c::Int64,
)
    nv = valence_band
    nc = conduction_band
    @views begin
        return projector_trace_four!(
                   temporary_1,
                   temporary_2,
                   central_data.projectors[nv, :, :],
                   central_data.projector_derivatives[nc, :, :, b],
                   central_data.projectors[nc, :, :],
                   central_data.projector_second_derivatives[nv, :, :, a, c],
               ) +
               projector_trace_five!(
                   temporary_1,
                   temporary_2,
                   temporary_3,
                   central_data.projectors[nv, :, :],
                   central_data.projector_derivatives[nc, :, :, b],
                   central_data.projectors[nc, :, :],
                   central_data.projector_derivatives[nc, :, :, a],
                   central_data.projector_derivatives[nv, :, :, c],
               ) +
               projector_trace_four!(
                   temporary_1,
                   temporary_2,
                   central_data.projectors[nv, :, :],
                   central_data.projector_derivatives[nc, :, :, b],
                   central_data.projectors[nc, :, :],
                   central_data.external_geometry[:, :, a, c],
               )
    end
end

"""
Compute only the two Projector trace components used by shift current.
"""
function projector_shift_current_trace_terms!(
    temporary_1::Matrix{ComplexF64},
    temporary_2::Matrix{ComplexF64},
    temporary_3::Matrix{ComplexF64},
    temporary_4::Matrix{ComplexF64},
    temporary_5::Matrix{ComplexF64},
    temporary_6::Matrix{ComplexF64},
    central_data::ProjectorMatrixData,
    valence_band::Int64,
    conduction_band::Int64,
    a::Int64,
    b::Int64,
    c::Int64,
)
    nv = valence_band
    nc = conduction_band
    @views begin
        C_nm_abc =
            projector_trace_four!(
                temporary_1,
                temporary_2,
                central_data.projectors[nc, :, :],
                central_data.projector_derivatives[nv, :, :, b],
                central_data.projectors[nv, :, :],
                central_data.projector_second_derivatives[nc, :, :, a, c],
            ) +
            projector_trace_five!(
                temporary_1,
                temporary_2,
                temporary_3,
                central_data.projectors[nc, :, :],
                central_data.projector_derivatives[nv, :, :, b],
                central_data.projectors[nv, :, :],
                central_data.projector_derivatives[nv, :, :, a],
                central_data.projector_derivatives[nc, :, :, c],
            ) +
            projector_trace_four!(
                temporary_1,
                temporary_2,
                central_data.projectors[nc, :, :],
                central_data.projector_derivatives[nv, :, :, b],
                central_data.projectors[nv, :, :],
                central_data.external_geometry[:, :, a, c],
            )
        C_mn_acb =
            projector_trace_four!(
                temporary_4,
                temporary_5,
                central_data.projectors[nv, :, :],
                central_data.projector_derivatives[nc, :, :, c],
                central_data.projectors[nc, :, :],
                central_data.projector_second_derivatives[nv, :, :, a, b],
            ) +
            projector_trace_five!(
                temporary_4,
                temporary_5,
                temporary_6,
                central_data.projectors[nv, :, :],
                central_data.projector_derivatives[nc, :, :, c],
                central_data.projectors[nc, :, :],
                central_data.projector_derivatives[nc, :, :, a],
                central_data.projector_derivatives[nv, :, :, b],
            ) +
            projector_trace_four!(
                temporary_4,
                temporary_5,
                central_data.projectors[nv, :, :],
                central_data.projector_derivatives[nc, :, :, c],
                central_data.projectors[nc, :, :],
                central_data.external_geometry[:, :, a, b],
            )
        return C_nm_abc, C_mn_acb
    end
end

"""
Return the two ordered Projector shift-current trace terms using conduction/valence degeneracy-column ranges.

Include second derivatives and external geometry as in the dense trace contract; mutate only supplied scratch and apply no response prefactor.
"""
function projector_shift_current_trace_terms_low_rank!(
    temporary_1::Matrix{ComplexF64},
    temporary_2::Matrix{ComplexF64},
    temporary_3::Matrix{ComplexF64},
    temporary_4::Matrix{ComplexF64},
    temporary_5::Matrix{ComplexF64},
    temporary_6::Matrix{ComplexF64},
    central_data::ProjectorMatrixData,
    valence_band::Int64,
    conduction_band::Int64,
    a::Int64,
    b::Int64,
    c::Int64,
)
    nv = valence_band
    nc = conduction_band
    eigenvectors = central_data.spectrum.eigenvectors
    nv_start = central_data.degeneracy_group_starts[nv]
    nv_stop = central_data.degeneracy_group_stops[nv]
    nc_start = central_data.degeneracy_group_starts[nc]
    nc_stop = central_data.degeneracy_group_stops[nc]
    @views begin
        C_nm_abc =
            projector_trace_four_low_rank!(
                temporary_1,
                temporary_2,
                temporary_3,
                eigenvectors,
                nc_start,
                nc_stop,
                central_data.projector_derivatives[nv, :, :, b],
                central_data.projectors[nv, :, :],
                central_data.projector_second_derivatives[nc, :, :, a, c],
            ) +
            projector_trace_five_low_rank!(
                temporary_1,
                temporary_2,
                eigenvectors,
                nc_start,
                nc_stop,
                central_data.projector_derivatives[nv, :, :, b],
                central_data.projectors[nv, :, :],
                central_data.projector_derivatives[nv, :, :, a],
                central_data.projector_derivatives[nc, :, :, c],
            ) +
            projector_trace_four_low_rank!(
                temporary_1,
                temporary_2,
                temporary_3,
                eigenvectors,
                nc_start,
                nc_stop,
                central_data.projector_derivatives[nv, :, :, b],
                central_data.projectors[nv, :, :],
                central_data.external_geometry[:, :, a, c],
            )
        C_mn_acb =
            projector_trace_four_low_rank!(
                temporary_4,
                temporary_5,
                temporary_6,
                eigenvectors,
                nv_start,
                nv_stop,
                central_data.projector_derivatives[nc, :, :, c],
                central_data.projectors[nc, :, :],
                central_data.projector_second_derivatives[nv, :, :, a, b],
            ) +
            projector_trace_five_low_rank!(
                temporary_4,
                temporary_5,
                eigenvectors,
                nv_start,
                nv_stop,
                central_data.projector_derivatives[nc, :, :, c],
                central_data.projectors[nc, :, :],
                central_data.projector_derivatives[nc, :, :, a],
                central_data.projector_derivatives[nv, :, :, b],
            ) +
            projector_trace_four_low_rank!(
                temporary_4,
                temporary_5,
                temporary_6,
                eigenvectors,
                nv_start,
                nv_stop,
                central_data.projector_derivatives[nc, :, :, c],
                central_data.projectors[nc, :, :],
                central_data.external_geometry[:, :, a, b],
            )
        return C_nm_abc, C_mn_acb
    end
end

"""
Expand band window for groups.
"""
function expand_band_window_for_groups(
    band_start::Int64,
    band_end::Int64,
    group_data::GeometricLoopMatrixData...,
)
    start_band = band_start
    end_band = band_end
    changed = true
    while changed
        old_start = start_band
        old_end = end_band
        for band in old_start:old_end
            for data in group_data
                start_band = min(start_band, data.degeneracy_group_starts[band])
                end_band = max(end_band, data.degeneracy_group_stops[band])
            end
        end
        changed = start_band != old_start || end_band != old_end
    end
    return start_band, end_band
end

"""
Write the dimensionless central source-gauge overlap `U_conduction' * U_valence` into `central_overlap`; return it.

Delegate orbital-count and output-shape checks to the shared loop-overlap implementation.
"""
function compute_geometric_loop_central_overlap!(
    central_overlap::AbstractMatrix{ComplexF64},
    conduction_data::GeometricLoopMatrixData,
    valence_data::GeometricLoopMatrixData,
)
    return MatrixElements.compute_loop_overlap!(central_overlap, conduction_data, valence_data)
end

"""
Fill six source-gauge links for forward/backward valence-central to conduction-central paths.

Each path traverses valence central, valence shifted, conduction shifted, conduction central; outputs are dimensionless caller-owned matrices and the function returns nothing.
"""
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
)
    MatrixElements.compute_loop_overlap!(
        forward_overlap_1,
        valence_central_data,
        valence_forward_data,
    )
    MatrixElements.compute_loop_overlap!(
        forward_overlap_2,
        valence_forward_data,
        conduction_forward_data,
    )
    MatrixElements.compute_loop_overlap!(
        forward_overlap_3,
        conduction_forward_data,
        conduction_central_data,
    )
    MatrixElements.compute_loop_overlap!(
        backward_overlap_1,
        valence_central_data,
        valence_backward_data,
    )
    MatrixElements.compute_loop_overlap!(
        backward_overlap_2,
        valence_backward_data,
        conduction_backward_data,
    )
    MatrixElements.compute_loop_overlap!(
        backward_overlap_3,
        conduction_backward_data,
        conduction_central_data,
    )
    return nothing
end

"""
Fill shifted valence-to-conduction insertions `V_valence * overlap_2 + overlap_2 * V_conduction` for requested Cartesian directions.

Matrices remain in their native source frames; only selected output directions are valid afterward.
"""
function compute_geometric_loop_third_insertions!(
    insertions::Array{ComplexF64, 3},
    valence_shift::GeometricLoopMatrixData,
    conduction_shift::GeometricLoopMatrixData,
    overlap_2::AbstractMatrix{ComplexF64},
    directions,
)
    num_orbitals = valence_shift.num_orbitals
    @inbounds for direction in directions
        for valence_band in 1:num_orbitals
            for conduction_band in 1:num_orbitals
                total = COMPLEX_ZERO
                for orbital in 1:num_orbitals
                    total +=
                        valence_shift.velocity_vertices[valence_band, orbital, direction] *
                        overlap_2[orbital, conduction_band] +
                        overlap_2[valence_band, orbital] *
                        conduction_shift.velocity_vertices[orbital, conduction_band, direction]
                end
                insertions[valence_band, conduction_band, direction] = total
            end
        end
    end
    return insertions
end

"""
Fill central conduction-to-valence insertions `V_conduction * overlap_4 + overlap_4 * V_valence` for requested directions.

Retain source-frame band order and overwrite only selected Cartesian slices of the caller's buffer.
"""
function compute_geometric_loop_second_insertions!(
    insertions::Array{ComplexF64, 3},
    valence_central::GeometricLoopMatrixData,
    conduction_central::GeometricLoopMatrixData,
    overlap_4::AbstractMatrix{ComplexF64},
    directions,
)
    num_orbitals = valence_central.num_orbitals
    @inbounds for direction in directions
        for conduction_band in 1:num_orbitals
            for valence_band in 1:num_orbitals
                total = COMPLEX_ZERO
                for orbital in 1:num_orbitals
                    total +=
                        conduction_central.velocity_vertices[conduction_band, orbital, direction] *
                        overlap_4[orbital, valence_band] +
                        overlap_4[conduction_band, orbital] *
                        valence_central.velocity_vertices[orbital, valence_band, direction]
                end
                insertions[conduction_band, valence_band, direction] = total
            end
        end
    end
    return insertions
end

"""
Contract cached links and velocity insertions over the selected valence/conduction degeneracy blocks.

Multiply by both stored group weights, preserve the closed-path factor order, and return a complex kernel without physical or k-point prefactors.
"""
function geometric_loop_overlap_block_contraction_precomputed(
    valence0::GeometricLoopMatrixData,
    conduction0::GeometricLoopMatrixData,
    overlap_1::AbstractMatrix{ComplexF64},
    overlap_3::AbstractMatrix{ComplexF64},
    third_insertions::Array{ComplexF64, 3},
    second_insertions::Array{ComplexF64, 3},
    valence_band::Int64,
    conduction_band::Int64,
    second_direction::Int64,
    third_direction::Int64,
)
    valence_start = valence0.degeneracy_group_starts[valence_band]
    valence_stop = valence0.degeneracy_group_stops[valence_band]
    conduction_start = conduction0.degeneracy_group_starts[conduction_band]
    conduction_stop = conduction0.degeneracy_group_stops[conduction_band]

    total = COMPLEX_ZERO
    @inbounds for alpha0 in valence_start:valence_stop
        for alphap in valence_start:valence_stop
            left_link = overlap_1[alpha0, alphap]
            for betap in conduction_start:conduction_stop
                left_insertion = left_link * third_insertions[alphap, betap, third_direction]
                for beta0 in conduction_start:conduction_stop
                    total +=
                        left_insertion *
                        overlap_3[betap, beta0] *
                        second_insertions[beta0, alpha0, second_direction]
                end
            end
        end
    end
    return conduction0.degeneracy_weights[conduction_band] *
           valence0.degeneracy_weights[valence_band] *
           total
end

"""
Contract the same closed valence/conduction block path while computing its velocity insertions inside the loops.

Apply both degeneracy weights and retain source-gauge factor order; return a complex integrand without occupation or k-space normalization.
"""
function geometric_loop_overlap_block_contraction(
    valence0::GeometricLoopMatrixData,
    conduction0::GeometricLoopMatrixData,
    valence_shift::GeometricLoopMatrixData,
    conduction_shift::GeometricLoopMatrixData,
    overlap_1::Matrix{ComplexF64},
    overlap_2::Matrix{ComplexF64},
    overlap_3::Matrix{ComplexF64},
    overlap_4::Matrix{ComplexF64},
    valence_band::Int64,
    conduction_band::Int64,
    second_direction::Int64,
    third_direction::Int64,
)
    valence_start = valence0.degeneracy_group_starts[valence_band]
    valence_stop = valence0.degeneracy_group_stops[valence_band]
    conduction_start = conduction0.degeneracy_group_starts[conduction_band]
    conduction_stop = conduction0.degeneracy_group_stops[conduction_band]
    num_orbitals = valence0.num_orbitals

    total = 0.0 + 0.0im
    @inbounds for alpha0 in valence_start:valence_stop
        for alphap in valence_start:valence_stop
            S_A = overlap_1[alpha0, alphap]
            for betap in conduction_start:conduction_stop
                G_c = 0.0 + 0.0im
                for l in 1:num_orbitals
                    G_c += (
                        valence_shift.velocity_vertices[alphap, l, third_direction] *
                        overlap_2[l, betap] +
                        overlap_2[alphap, l] *
                        conduction_shift.velocity_vertices[l, betap, third_direction]
                    )
                end
                S_A_G_c = S_A * G_c
                for beta0 in conduction_start:conduction_stop
                    H_b = 0.0 + 0.0im
                    for s in 1:num_orbitals
                        H_b += (
                            conduction0.velocity_vertices[beta0, s, second_direction] *
                            overlap_4[s, alpha0] +
                            overlap_4[beta0, s] *
                            valence0.velocity_vertices[s, alpha0, second_direction]
                        )
                    end
                    total += S_A_G_c * overlap_3[betap, beta0] * H_b
                end
            end
        end
    end

    return conduction0.degeneracy_weights[conduction_band] *
           valence0.degeneracy_weights[valence_band] *
           total
end
# Zero the selected band-pair/tensor region or compact active-pair entries before kernel reuse; preserve storage outside that declared region.
@inline function _clear_response_kernel!(
    response_kernel::Array{ComplexF64, 5},
    tensor_indices::Nothing,
)
    fill!(response_kernel, COMPLEX_ZERO)
    return response_kernel
end

# Zero the selected band-pair/tensor region or compact active-pair entries before kernel reuse; preserve storage outside that declared region.
@inline function _clear_response_kernel!(
    response_kernel::Array{ComplexF64, 5},
    tensor_indices::AbstractVector{<:Integer},
)
    a, b, c = tensor_indices
    fill!(@view(response_kernel[:, :, a, b, c]), COMPLEX_ZERO)
    return response_kernel
end

# Zero the selected band-pair/tensor region or compact active-pair entries before kernel reuse; preserve storage outside that declared region.
@inline function _clear_response_kernel!(
    response_kernel::Array{ComplexF64, 6},
    tensor_indices::Nothing,
)
    fill!(response_kernel, COMPLEX_ZERO)
    return response_kernel
end

# Zero the selected band-pair/tensor region or compact active-pair entries before kernel reuse; preserve storage outside that declared region.
@inline function _clear_response_kernel!(
    response_kernel::Array{ComplexF64, 6},
    tensor_indices::AbstractVector{<:Integer},
)
    a, s, b, c = tensor_indices
    fill!(@view(response_kernel[:, :, a, s, b, c]), COMPLEX_ZERO)
    return response_kernel
end

# Shared compact-pair and frequency-scratch helpers for injection-current families.

# Resolve the valid prefix length of the compact ordered transition list and reject a count outside its capacity.
@inline function _compact_injection_pair_count(active_pairs, active_pair_count::Int)
    pair_count = active_pair_count < 0 ? length(active_pairs) : active_pair_count
    0 <= pair_count <= length(active_pairs) || throw(
        ArgumentError(
            "active_pair_count=$(active_pair_count) must be between 0 and $(length(active_pairs)).",
        ),
    )
    return pair_count
end

# Select the available frequency-contraction scratch for the injection path without changing pair order.
@inline function _use_injection_frequency_scratch(frequency_weight_scratch, frequency_count::Int)
    frequency_weight_scratch === nothing && return false
    length(frequency_weight_scratch) >= frequency_count || throw(
        ArgumentError(
            "frequency_weight_scratch length=$(length(frequency_weight_scratch)) must be at least $(frequency_count).",
        ),
    )
    return frequency_count >= 200
end
