# Geometric-loop shift-current contraction and accumulation.

"""
Contract one geometric-loop shift-current component with occupation, delta and frequency-denominator weights.

Cartesian order is `(a,b,c)` and band windows refer to the cached loop legs; the supplied prefactor sets physical units and no k-point normalization is added.
"""
function geometric_loop_sck_component(
    response_kernel::Array{ComplexF64, 5},
    occupation_differences::AbstractMatrix{Float64},
    delta::AbstractMatrix{Float64},
    frequency_denominator_weight::Float64,
    prefactor::Number,
    tensor_indices::Vector{Int},
    num_orbitals::Int64,
)
    a, b, c = tensor_indices
    value = 0.0 + 0.0im
    @inbounds for m in 1:num_orbitals
        for n in 1:num_orbitals
            # Formula convention: n labels the valence leg, m the conduction leg.
            weight = occupation_differences[n, m] * delta[n, m] * frequency_denominator_weight
            if weight == 0.0
                continue
            end
            value += prefactor * weight * response_kernel[n, m, a, b, c]
        end
    end
    return value
end

"""
Add geometric-loop current kernels to the frequency-resolved rank-three tensor using the supplied occupation, delta and denominator weights.

Preserve band/tensor traversal and return the mutated accumulator; physical prefactors and k-mesh normalization are caller-specified.
"""
function accumulate_geometric_loop_shift_current_response!(
    local_response::Array{ComplexF64, 4},
    response_kernel::Array{ComplexF64, 5},
    occupation_differences::Array{Float64, 3},
    delta::Array{Float64, 3},
    frequency_denominator_weights::Vector{Float64},
    prefactor::Number,
    num_orbitals::Int64,
    spatial_dimension::Int64,
)
    num_photon_energies = size(delta, 1)
    @inbounds for energy_index in 1:num_photon_energies
        frequency_denominator_weight = frequency_denominator_weights[energy_index]
        # Formula convention: n labels the valence leg, m the conduction leg.
        for m in 1:num_orbitals
            for n in 1:num_orbitals
                weight =
                    occupation_differences[1, n, m] *
                    delta[energy_index, n, m] *
                    frequency_denominator_weight
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
