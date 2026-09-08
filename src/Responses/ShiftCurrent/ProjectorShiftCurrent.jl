"""
Add Projector shift-current kernels to the frequency-resolved rank-three accumulator with occupation, delta and complex-prefactor weights.

Preserve the kernel's ordered band and Cartesian axes; return caller-owned storage without applying an additional k-mesh normalization.
"""
function accumulate_projector_response_shift_current_response!(
    local_response::Array{ComplexF64, 4},
    response_kernel::Array{ComplexF64, 5},
    occupation_differences::Array{Float64, 3},
    delta::Array{Float64, 3},
    prefactor::ComplexF64,
    num_orbitals::Int64,
    spatial_dimension::Int64,
)
    num_photon_energies = size(delta, 1)
    @inbounds for energy_index in 1:num_photon_energies
        for m in 1:num_orbitals
            for n in 1:num_orbitals
                weight = occupation_differences[1, n, m] * delta[energy_index, n, m]
                if weight == 0.0
                    continue
                end
                cweight = prefactor * weight
                for c in 1:spatial_dimension
                    for b in 1:spatial_dimension
                        for a in 1:spatial_dimension
                            local_response[energy_index, a, b, c] +=
                                cweight * response_kernel[n, m, a, b, c]
                        end
                    end
                end
            end
        end
    end
    return local_response
end

"""
Fill the Projector shift-current kernel from the two ordered trace terms for active band pairs and Cartesian components.

Reuse supplied trace scratch and degeneracy grouping; occupation differences screen inactive transitions while physical prefactors are applied during contraction.
"""
function compute_projector_response_shift_current_kernel!(
    response_kernel::Array{ComplexF64, 5},
    central_data::ProjectorMatrixData,
    occupation_differences::Matrix{Float64},
    band_start::Int64,
    band_end::Int64,
    num_orbitals::Int64,
    spatial_dimension::Int64,
    kernel_tmp1::Matrix{ComplexF64},
    kernel_tmp2::Matrix{ComplexF64},
    kernel_tmp3::Matrix{ComplexF64},
    kernel_tmp4::Matrix{ComplexF64},
    kernel_tmp5::Matrix{ComplexF64},
    kernel_tmp6::Matrix{ComplexF64},
    ;
    active_pair_mask::Union{Nothing, AbstractMatrix{Bool}} = nothing,
    tensor_indices::Union{Nothing, AbstractVector{<:Integer}} = nothing,
)
    _clear_response_kernel!(response_kernel, tensor_indices)
    @inbounds for n in band_start:band_end
        for m in band_start:band_end
            if occupation_differences[n, m] > 0.5 &&
               (active_pair_mask === nothing || active_pair_mask[n, m])
                if tensor_indices === nothing
                    for a in 1:spatial_dimension
                        for b in 1:spatial_dimension
                            for c in 1:spatial_dimension
                                C_nm_abc, C_mn_acb = projector_shift_current_trace_terms_low_rank!(
                                    kernel_tmp1,
                                    kernel_tmp2,
                                    kernel_tmp3,
                                    kernel_tmp4,
                                    kernel_tmp5,
                                    kernel_tmp6,
                                    central_data,
                                    n,
                                    m,
                                    a,
                                    b,
                                    c,
                                )
                                # Projector formula convention:
                                # n is valence, m is conduction, and response_kernel[n,m] is
                                # C^{a;cb}_{mn} - C^{a;bc}_{nm}, exactly the
                                # manuscript bracket multiplied by subspace
                                # averaging weights.
                                response_kernel[n, m, a, b, c] =
                                    (C_mn_acb - C_nm_abc) *
                                    central_data.degeneracy_weights[n] *
                                    central_data.degeneracy_weights[m]
                            end
                        end
                    end
                else
                    a, b, c = tensor_indices
                    C_nm_abc, C_mn_acb = projector_shift_current_trace_terms_low_rank!(
                        kernel_tmp1,
                        kernel_tmp2,
                        kernel_tmp3,
                        kernel_tmp4,
                        kernel_tmp5,
                        kernel_tmp6,
                        central_data,
                        n,
                        m,
                        a,
                        b,
                        c,
                    )
                    response_kernel[n, m, a, b, c] =
                        (C_mn_acb - C_nm_abc) *
                        central_data.degeneracy_weights[n] *
                        central_data.degeneracy_weights[m]
                end
            end
        end
    end
    return response_kernel
end

# Projector shift-current kernels.

"""
Return one `(a,b,c)` Projector shift-current component after summing the supplied band-pair occupation/delta weights and prefactor.

The kernel is read-only and k-point normalization remains with its caller.
"""
function projector_response_sck_component(
    response_kernel::Array{ComplexF64, 5},
    occupation_differences::AbstractMatrix{Float64},
    delta::AbstractMatrix{Float64},
    prefactor::ComplexF64,
    tensor_indices::Vector{Int},
    num_orbitals::Int64,
)
    a, b, c = tensor_indices
    value = 0.0 + 0.0im
    @inbounds for m in 1:num_orbitals
        for n in 1:num_orbitals
            weight = occupation_differences[n, m] * delta[n, m]
            if weight == 0.0
                continue
            end
            value += prefactor * weight * response_kernel[n, m, a, b, c]
        end
    end
    return value
end
