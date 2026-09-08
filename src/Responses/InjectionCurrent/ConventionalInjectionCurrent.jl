# Conventional injection-current response.

"""
The stored Hamiltonian-gauge factor is
`(v_mm^a-v_nn^a) A_nm^c A_mn^b` at `[n,m,a,b,c]`. `a` is the injected-current
direction and `(b,c)` are optical-field directions. Dense and compact-pair paths
use the same n-major pair order. Occupations, delta broadening, charge/time
prefactors, cell volume, and k-point normalization are intentionally applied by
Runtime after this mutation. Runtime reports one ordered-field injection-rate
contribution; the conjugate-frequency outer factor `2` and steady-state `tau`
conversion are external to this kernel.
"""
function compute_injection_current_kernel!(
    response_kernel::Array{ComplexF64, 5},
    data::KPointMatrixData,
    band_start::Int64,
    band_end::Int64,
    spatial_dimension::Int64,
    ;
    active_pair_mask::Union{Nothing, AbstractMatrix{Bool}} = nothing,
    active_pairs_nmajor::Union{Nothing, AbstractVector{NTuple{2, Int}}} = nothing,
    active_pair_count::Int = -1,
    tensor_indices::Union{Nothing, AbstractVector{<:Integer}} = nothing,
)
    _clear_response_kernel!(response_kernel, tensor_indices)
    if active_pairs_nmajor !== nothing
        pair_count = _compact_injection_pair_count(active_pairs_nmajor, active_pair_count)
        if tensor_indices === nothing
            @inbounds for pair_index in 1:pair_count
                n, m = active_pairs_nmajor[pair_index]
                for a in 1:spatial_dimension
                    velocity_diff =
                        data.hamiltonian_derivatives[m, m, a] -
                        data.hamiltonian_derivatives[n, n, a]
                    for b in 1:spatial_dimension
                        for c in 1:spatial_dimension
                            response_kernel[n, m, a, b, c] =
                                velocity_diff *
                                data.berry_connection[n, m, c] *
                                data.berry_connection[m, n, b]
                        end
                    end
                end
            end
        else
            a, b, c = tensor_indices
            @inbounds for pair_index in 1:pair_count
                n, m = active_pairs_nmajor[pair_index]
                velocity_diff =
                    data.hamiltonian_derivatives[m, m, a] - data.hamiltonian_derivatives[n, n, a]
                response_kernel[n, m, a, b, c] =
                    velocity_diff * data.berry_connection[n, m, c] * data.berry_connection[m, n, b]
            end
        end
        return response_kernel
    end
    if tensor_indices === nothing
        @inbounds for n in band_start:band_end
            for m in band_start:band_end
                active_pair_mask !== nothing && !active_pair_mask[n, m] && continue
                for a in 1:spatial_dimension
                    velocity_diff =
                        data.hamiltonian_derivatives[m, m, a] -
                        data.hamiltonian_derivatives[n, n, a]
                    for b in 1:spatial_dimension
                        for c in 1:spatial_dimension
                            response_kernel[n, m, a, b, c] =
                                velocity_diff *
                                data.berry_connection[n, m, c] *
                                data.berry_connection[m, n, b]
                        end
                    end
                end
            end
        end
    else
        a, b, c = tensor_indices
        @inbounds for n in band_start:band_end
            for m in band_start:band_end
                active_pair_mask !== nothing && !active_pair_mask[n, m] && continue
                velocity_diff =
                    data.hamiltonian_derivatives[m, m, a] - data.hamiltonian_derivatives[n, n, a]
                response_kernel[n, m, a, b, c] =
                    velocity_diff * data.berry_connection[n, m, c] * data.berry_connection[m, n, b]
            end
        end
    end
    return response_kernel
end

"""
The passed prefactor produces
one ordered-field injection-rate contribution; it does not include the
conjugate-frequency outer factor `2` or the steady-state `tau`.
"""
function accumulate_injection_current_response!(
    local_response::Array{ComplexF64, 4},
    response_kernel::Array{ComplexF64, 5},
    occupation_differences::Matrix{Float64},
    delta::Array{Float64, 3},
    prefactor,
    band_start::Int64,
    band_end::Int64,
    spatial_dimension::Int64,
    ;
    active_pairs_nmajor::Union{Nothing, AbstractVector{NTuple{2, Int}}} = nothing,
    active_pair_count::Int = -1,
    frequency_weight_scratch::Union{Nothing, AbstractVector{Float64}} = nothing,
    _frequency_contraction_scratch::Union{Nothing, _FrequencyContractionScratch} = nothing,
)
    num_photon_energies = size(delta, 1)
    use_frequency_scratch =
        _use_injection_frequency_scratch(frequency_weight_scratch, num_photon_energies)
    if active_pairs_nmajor !== nothing
        pair_count = _compact_injection_pair_count(active_pairs_nmajor, active_pair_count)
        if use_frequency_scratch
            @inbounds for pair_index in 1:pair_count
                n, m = active_pairs_nmajor[pair_index]
                for energy_index in 1:num_photon_energies
                    frequency_weight_scratch[energy_index] =
                        occupation_differences[n, m] * delta[energy_index, n, m]
                end
                for c in 1:spatial_dimension
                    for b in 1:spatial_dimension
                        for a in 1:spatial_dimension
                            kernel = response_kernel[n, m, a, b, c]
                            for energy_index in 1:num_photon_energies
                                weight = frequency_weight_scratch[energy_index]
                                if weight != 0.0
                                    cweight = prefactor * weight
                                    local_response[energy_index, a, b, c] += cweight * kernel
                                end
                            end
                        end
                    end
                end
            end
        else
            @inbounds for energy_index in 1:num_photon_energies
                for pair_index in 1:pair_count
                    n, m = active_pairs_nmajor[pair_index]
                    weight = occupation_differences[n, m] * delta[energy_index, n, m]
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
    band_count = band_end - band_start + 1
    frequency_contraction_strategy = _select_frequency_contraction_strategy(
        num_photon_energies,
        band_count^2,
        active_pairs_nmajor,
        _frequency_contraction_scratch,
    )
    if frequency_contraction_strategy !== :scalar
        return _accumulate_frequency_contraction_prototype!(
            local_response,
            response_kernel,
            occupation_differences,
            delta,
            prefactor,
            band_start,
            band_end,
            band_start,
            band_end,
            _frequency_contraction_scratch,
            strategy = frequency_contraction_strategy,
            pair_order = :nmajor,
        )
    end
    @inbounds for energy_index in 1:num_photon_energies
        for n in band_start:band_end
            for m in band_start:band_end
                weight = occupation_differences[n, m] * delta[energy_index, n, m]
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
The passed prefactor produces
one ordered-field injection-rate contribution; it does not include the
conjugate-frequency outer factor `2` or the steady-state `tau`.
"""
function injection_current_component(
    response_kernel::Array{ComplexF64, 5},
    occupation_differences::AbstractMatrix{Float64},
    delta::AbstractMatrix{Float64},
    prefactor,
    tensor_indices::Vector{Int},
    band_start::Int64,
    band_end::Int64,
    ;
    active_pairs_nmajor::Union{Nothing, AbstractVector{NTuple{2, Int}}} = nothing,
    active_pair_count::Int = -1,
)
    a, b, c = tensor_indices
    value = COMPLEX_ZERO
    if active_pairs_nmajor !== nothing
        pair_count = _compact_injection_pair_count(active_pairs_nmajor, active_pair_count)
        @inbounds for pair_index in 1:pair_count
            n, m = active_pairs_nmajor[pair_index]
            weight = occupation_differences[n, m] * delta[n, m]
            if weight != 0.0
                value += prefactor * weight * response_kernel[n, m, a, b, c]
            end
        end
        return value
    end
    @inbounds for n in band_start:band_end
        for m in band_start:band_end
            weight = occupation_differences[n, m] * delta[n, m]
            if weight != 0.0
                value += prefactor * weight * response_kernel[n, m, a, b, c]
            end
        end
    end
    return value
end
