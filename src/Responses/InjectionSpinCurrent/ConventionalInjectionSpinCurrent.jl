"""
The stored Hamiltonian-gauge factor is
`(J_mm^{a,s}-J_nn^{a,s}) A_nm^c A_mn^b` at `[n,m,a,s,b,c]`, where `a` is the
flow direction and `s` the spin-polarization axis. Compact and dense paths retain
the same transition order. The spin-velocity capability must already be present;
this routine neither constructs operators nor applies occupations, broadening,
physical prefactors, or k-point normalization.
"""
function compute_injection_spin_current_kernel!(
    response_kernel::Array{ComplexF64, 6},
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
                    for s in 1:3
                        spin_velocity_diff =
                            data.spin_velocity.hamiltonian_gauge[m, m, a, s] -
                            data.spin_velocity.hamiltonian_gauge[n, n, a, s]
                        for b in 1:spatial_dimension
                            for c in 1:spatial_dimension
                                response_kernel[n, m, a, s, b, c] =
                                    spin_velocity_diff *
                                    data.berry_connection[n, m, c] *
                                    data.berry_connection[m, n, b]
                            end
                        end
                    end
                end
            end
        else
            a, s, b, c = tensor_indices
            @inbounds for pair_index in 1:pair_count
                n, m = active_pairs_nmajor[pair_index]
                spin_velocity_diff =
                    data.spin_velocity.hamiltonian_gauge[m, m, a, s] -
                    data.spin_velocity.hamiltonian_gauge[n, n, a, s]
                response_kernel[n, m, a, s, b, c] =
                    spin_velocity_diff *
                    data.berry_connection[n, m, c] *
                    data.berry_connection[m, n, b]
            end
        end
        return response_kernel
    end
    if tensor_indices === nothing
        @inbounds for n in band_start:band_end
            for m in band_start:band_end
                active_pair_mask !== nothing && !active_pair_mask[n, m] && continue
                for a in 1:spatial_dimension
                    for s in 1:3
                        spin_velocity_diff =
                            data.spin_velocity.hamiltonian_gauge[m, m, a, s] -
                            data.spin_velocity.hamiltonian_gauge[n, n, a, s]
                        for b in 1:spatial_dimension
                            for c in 1:spatial_dimension
                                response_kernel[n, m, a, s, b, c] =
                                    spin_velocity_diff *
                                    data.berry_connection[n, m, c] *
                                    data.berry_connection[m, n, b]
                            end
                        end
                    end
                end
            end
        end
    else
        a, s, b, c = tensor_indices
        @inbounds for n in band_start:band_end
            for m in band_start:band_end
                active_pair_mask !== nothing && !active_pair_mask[n, m] && continue
                spin_velocity_diff =
                    data.spin_velocity.hamiltonian_gauge[m, m, a, s] -
                    data.spin_velocity.hamiltonian_gauge[n, n, a, s]
                response_kernel[n, m, a, s, b, c] =
                    spin_velocity_diff *
                    data.berry_connection[n, m, c] *
                    data.berry_connection[m, n, b]
            end
        end
    end
    return response_kernel
end

"""
Add occupation- and broadening-weighted injection spin kernels to `local_response[energy,a,spin,b,c]` and return it.

Use ordered `(n,m)` pairs, preserving active-pair order when supplied. The caller supplies the physical prefactor; no lifetime or k-mesh normalization is introduced here.
"""
function accumulate_injection_spin_current_response!(
    local_response::Array{ComplexF64, 5},
    response_kernel::Array{ComplexF64, 6},
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
                        for s in 1:3
                            for a in 1:spatial_dimension
                                kernel = response_kernel[n, m, a, s, b, c]
                                for energy_index in 1:num_photon_energies
                                    weight = frequency_weight_scratch[energy_index]
                                    if weight != 0.0
                                        cweight = prefactor * weight
                                        local_response[energy_index, a, s, b, c] += cweight * kernel
                                    end
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
                    weight == 0.0 && continue
                    cweight = prefactor * weight
                    for c in 1:spatial_dimension
                        for b in 1:spatial_dimension
                            for s in 1:3
                                for a in 1:spatial_dimension
                                    local_response[energy_index, a, s, b, c] +=
                                        cweight * response_kernel[n, m, a, s, b, c]
                                end
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
                weight == 0.0 && continue
                cweight = prefactor * weight
                for c in 1:spatial_dimension
                    for b in 1:spatial_dimension
                        for s in 1:3
                            for a in 1:spatial_dimension
                                local_response[energy_index, a, s, b, c] +=
                                    cweight * response_kernel[n, m, a, s, b, c]
                            end
                        end
                    end
                end
            end
        end
    end
    return local_response
end

"""
Sum one `(a,spin,b,c)` injection-spin component over ordered band pairs at a single photon energy.

Multiply the kernel by the supplied occupation differences, delta weights and prefactor; inputs remain unmodified and no k-point normalization is added.
"""
function injection_spin_current_component(
    response_kernel::Array{ComplexF64, 6},
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
    a, s, b, c = tensor_indices
    value = COMPLEX_ZERO
    if active_pairs_nmajor !== nothing
        pair_count = _compact_injection_pair_count(active_pairs_nmajor, active_pair_count)
        @inbounds for pair_index in 1:pair_count
            n, m = active_pairs_nmajor[pair_index]
            weight = occupation_differences[n, m] * delta[n, m]
            if weight != 0.0
                value += prefactor * weight * response_kernel[n, m, a, s, b, c]
            end
        end
        return value
    end
    @inbounds for n in band_start:band_end
        for m in band_start:band_end
            weight = occupation_differences[n, m] * delta[n, m]
            if weight != 0.0
                value += prefactor * weight * response_kernel[n, m, a, s, b, c]
            end
        end
    end
    return value
end
