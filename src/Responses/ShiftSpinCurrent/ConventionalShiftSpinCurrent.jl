# Conventional q=0 shift-spin-current integral and k-slice kernels.

using LinearAlgebra

"""
Construct the Hamiltonian-gauge spin-current vertices and their generalized
derivatives used by the conventional shift-spin-current formula. Tensor index
order is `(a,s,b,c)`: current direction, spin-polarization axis, and two optical
directions. Off-diagonal denominators use the caller's regularization while
Hermitian closure and the established connection symmetrization are preserved.
All arrays are caller-owned; response prefactors and k-point normalization remain
Runtime responsibilities.
"""
function compute_shift_spin_current_vertices!(
    ws::ShiftSpinCurrentConventionalWorkspace,
    denominator_regularization::Real,
    spatial_dimension::Int,
    ;
    tensor_indices::Union{Nothing, AbstractVector{<:Integer}} = nothing,
)
    data = ws.data
    energies = data.spectrum.energies
    h1 = data.hamiltonian_derivatives
    h2 = data.hamiltonian_second_derivatives
    connection = data.internal_connection
    connection_derivative = data.internal_connection_derivatives
    spin = data.spin.hamiltonian_gauge
    spin_current = data.spin_velocity.hamiltonian_gauge
    count = length(energies)
    eta = Float64(denominator_regularization)

    for a in 1:spatial_dimension
        if tensor_indices !== nothing
            response_axis, _, second_axis, third_axis = tensor_indices
            a in (response_axis, second_axis, third_axis) || continue
        end
        @views ws.physical_connection[:, :, a] .=
            0.5 .* (connection[:, :, a] .+ connection[:, :, a]')
        for b in 1:spatial_dimension
            if tensor_indices !== nothing
                response_axis, _, second_axis, third_axis = tensor_indices
                needed =
                    (b == response_axis && a == second_axis) ||
                    (b == second_axis && a == response_axis) ||
                    (b == response_axis && a == third_axis) ||
                    (b == third_axis && a == response_axis)
                needed || continue
            end
            @views ws.physical_connection_derivative[:, :, b, a] .=
                0.5 .* (connection_derivative[:, :, b, a] .+ connection_derivative[:, :, b, a]')
        end
    end

    @inbounds for a in 1:spatial_dimension, n in 1:count, m in 1:count
        if tensor_indices !== nothing
            response_axis, _, second_axis, third_axis = tensor_indices
            a in (response_axis, second_axis, third_axis) || continue
        end
        ws.velocity_vertex[m, n, a] =
            h1[m, n, a] - 1.0im * ws.physical_connection[m, n, a] * (energies[n] - energies[m])
    end
    @inbounds for n in 1:count, m in 1:count
        difference = energies[m] - energies[n]
        ws.regularized_inverse_energy[m, n] = difference / (difference^2 + eta^2)
    end

    for a in 1:spatial_dimension
        A_a = @view ws.physical_connection[:, :, a]
        H_a = @view h1[:, :, a]
        diagonal_needed = true
        if tensor_indices !== nothing
            response_axis, _, second_axis, third_axis = tensor_indices
            diagonal_needed =
                (a == response_axis && a == second_axis) || (a == response_axis && a == third_axis)
        end
        if diagonal_needed
            M_aa = @view ws.effective_mass_vertex[:, :, a, a]
            mul!(ws.matrix_scratch_1, A_a, H_a)
            mul!(ws.matrix_scratch_2, H_a, A_a)
            @. M_aa =
                h2[:, :, a, a] -
                1.0im * ws.physical_connection_derivative[:, :, a, a] * (energies' - energies) -
                1.0im * (ws.matrix_scratch_1 - ws.matrix_scratch_2)
            # Keep the original second subtraction even though the two diagonal
            # commutators have identical operands.
            mul!(ws.matrix_scratch_1, A_a, H_a)
            mul!(ws.matrix_scratch_2, H_a, A_a)
            @. M_aa -= 1.0im * (ws.matrix_scratch_1 - ws.matrix_scratch_2)
            @inbounds for n in 1:count, m in 1:count
                ws.matrix_scratch_3[m, n] = A_a[m, n] * (energies[n] - energies[m])
            end
            mul!(ws.matrix_scratch_1, A_a, ws.matrix_scratch_3)
            mul!(ws.matrix_scratch_2, ws.matrix_scratch_3, A_a)
            @. M_aa -= ws.matrix_scratch_1 - ws.matrix_scratch_2
            M_aa .= 0.5 .* (M_aa .+ M_aa')
        end
        for b in (a + 1):spatial_dimension
            if tensor_indices !== nothing
                response_axis, _, second_axis, third_axis = tensor_indices
                needed =
                    (
                        (a == response_axis && b == second_axis) ||
                        (b == response_axis && a == second_axis)
                    ) || (
                        (a == response_axis && b == third_axis) ||
                        (b == response_axis && a == third_axis)
                    )
                needed || continue
            end
            A_b = @view ws.physical_connection[:, :, b]
            H_b = @view h1[:, :, b]
            M_ab = @view ws.effective_mass_vertex[:, :, a, b]
            M_ba = @view ws.effective_mass_vertex[:, :, b, a]

            mul!(ws.matrix_scratch_1, A_b, H_a)
            mul!(ws.matrix_scratch_2, H_a, A_b)
            @. M_ab =
                h2[:, :, a, b] -
                1.0im * ws.physical_connection_derivative[:, :, b, a] * (energies' - energies) -
                1.0im * (ws.matrix_scratch_1 - ws.matrix_scratch_2)
            @. ws.matrix_scratch_3 = ws.matrix_scratch_1 - ws.matrix_scratch_2

            mul!(ws.matrix_scratch_1, A_a, H_b)
            mul!(ws.matrix_scratch_2, H_b, A_a)
            @. M_ab -= 1.0im * (ws.matrix_scratch_1 - ws.matrix_scratch_2)
            @. M_ba =
                h2[:, :, b, a] -
                1.0im * ws.physical_connection_derivative[:, :, a, b] * (energies' - energies) -
                1.0im * (ws.matrix_scratch_1 - ws.matrix_scratch_2)
            @. M_ba -= 1.0im * ws.matrix_scratch_3

            @inbounds for n in 1:count, m in 1:count
                ws.matrix_scratch_3[m, n] = A_b[m, n] * (energies[n] - energies[m])
            end
            mul!(ws.matrix_scratch_1, A_a, ws.matrix_scratch_3)
            mul!(ws.matrix_scratch_2, ws.matrix_scratch_3, A_a)
            @. M_ab -= ws.matrix_scratch_1 - ws.matrix_scratch_2

            @inbounds for n in 1:count, m in 1:count
                ws.matrix_scratch_3[m, n] = A_a[m, n] * (energies[n] - energies[m])
            end
            mul!(ws.matrix_scratch_1, A_b, ws.matrix_scratch_3)
            mul!(ws.matrix_scratch_2, ws.matrix_scratch_3, A_b)
            @. M_ba -= ws.matrix_scratch_1 - ws.matrix_scratch_2

            ws.matrix_scratch_1 .= 0.25 .* (M_ab .+ M_ba .+ M_ab' .+ M_ba')
            M_ab .= ws.matrix_scratch_1
            M_ba .= ws.matrix_scratch_1
        end
    end

    for a in 1:spatial_dimension, b in a:spatial_dimension, s in 1:3
        needed_ab = true
        needed_ba = a != b
        if tensor_indices !== nothing
            response_axis, spin_axis, second_axis, third_axis = tensor_indices
            s == spin_axis || continue
            needed_ab =
                (a == response_axis && b == second_axis) || (a == response_axis && b == third_axis)
            needed_ba =
                a != b && (
                    (b == response_axis && a == second_axis) ||
                    (b == response_axis && a == third_axis)
                )
            (needed_ab || needed_ba) || continue
        end
        S_s = @view spin[:, :, s]
        if needed_ab
            M_ab = @view ws.effective_mass_vertex[:, :, a, b]
            J2_ab = @view ws.spin_two_photon_vertex[:, :, s, a, b]
            mul!(ws.matrix_scratch_1, S_s, M_ab)
            mul!(ws.matrix_scratch_2, M_ab, S_s)
            @. J2_ab = 0.5 * (ws.matrix_scratch_1 + ws.matrix_scratch_2)
            if needed_ba
                @views ws.spin_two_photon_vertex[:, :, s, b, a] .= J2_ab
            end
        else
            M_ba = @view ws.effective_mass_vertex[:, :, b, a]
            J2_ba = @view ws.spin_two_photon_vertex[:, :, s, b, a]
            mul!(ws.matrix_scratch_1, S_s, M_ba)
            mul!(ws.matrix_scratch_2, M_ba, S_s)
            @. J2_ba = 0.5 * (ws.matrix_scratch_1 + ws.matrix_scratch_2)
        end
    end

    for a in 1:spatial_dimension, b in 1:spatial_dimension, s in 1:3
        if tensor_indices !== nothing
            response_axis, spin_axis, second_axis, third_axis = tensor_indices
            a == response_axis || continue
            s == spin_axis || continue
            b in (second_axis, third_axis) || continue
        end
        J_as = @view spin_current[:, :, a, s]
        V_b = @view ws.velocity_vertex[:, :, b]
        derivative = @view ws.generalized_spin_derivative[:, :, s, b, a]
        J2 = @view ws.spin_two_photon_vertex[:, :, s, a, b]
        @inbounds for n in 1:count, m in 1:count
            ws.matrix_scratch_3[m, n] = J_as[m, n] * ws.regularized_inverse_energy[m, n]
            ws.matrix_scratch_4[m, n] = J_as[m, n] * ws.regularized_inverse_energy[n, m]
        end
        mul!(ws.matrix_scratch_1, ws.matrix_scratch_3, V_b)
        mul!(ws.matrix_scratch_2, V_b, ws.matrix_scratch_4)
        @. derivative = J2 + ws.matrix_scratch_1 + ws.matrix_scratch_2
    end
    return ws
end

"""
The output order is `(n,m,a,s,b,c)`, with
`K[n,m,a,s,b,c] = d[m,n,s,b,a]v[n,m,c] - d[n,m,s,c,a]v[m,n,b]`.
The optical slots `(b,c)` therefore match the release's ordered
`E^b(+omega)E^c(-omega)` contribution without any output-level band or Cartesian
index exchange. Mutating variants write only to caller-owned work arrays; Runtime
owns physical prefactors, occupations, broadening, normalization, and deterministic
k-point reduction.
"""
function compute_shift_spin_current_kernel!(
    ws::ShiftSpinCurrentConventionalWorkspace,
    band_start::Int,
    band_end::Int,
    spatial_dimension::Int,
    ;
    active_pair_mask::Union{Nothing, AbstractMatrix{Bool}} = nothing,
    active_pairs_nmajor::Union{Nothing, AbstractVector{NTuple{2, Int}}} = nothing,
    active_pair_count::Int = -1,
    tensor_indices::Union{Nothing, AbstractVector{<:Integer}} = nothing,
)
    _clear_response_kernel!(ws.response_kernel, tensor_indices)
    derivative = ws.generalized_spin_derivative
    velocity = ws.velocity_vertex
    if active_pairs_nmajor !== nothing
        pair_count = active_pair_count < 0 ? length(active_pairs_nmajor) : active_pair_count
        if tensor_indices === nothing
            @inbounds for pair_index in 1:pair_count
                n, m = active_pairs_nmajor[pair_index]
                for a in 1:spatial_dimension,
                    s in 1:3,
                    b in 1:spatial_dimension,
                    c in 1:spatial_dimension

                    ws.response_kernel[n, m, a, s, b, c] =
                        derivative[m, n, s, b, a] * velocity[n, m, c] -
                        derivative[n, m, s, c, a] * velocity[m, n, b]
                end
            end
        else
            a, s, b, c = tensor_indices
            @inbounds for pair_index in 1:pair_count
                n, m = active_pairs_nmajor[pair_index]
                ws.response_kernel[n, m, a, s, b, c] =
                    derivative[m, n, s, b, a] * velocity[n, m, c] -
                    derivative[n, m, s, c, a] * velocity[m, n, b]
            end
        end
        return ws.response_kernel
    end
    if tensor_indices === nothing
        @inbounds for n in band_start:band_end, m in band_start:band_end
            active_pair_mask !== nothing && !active_pair_mask[n, m] && continue
            for a in 1:spatial_dimension,
                s in 1:3,
                b in 1:spatial_dimension,
                c in 1:spatial_dimension

                ws.response_kernel[n, m, a, s, b, c] =
                    derivative[m, n, s, b, a] * velocity[n, m, c] -
                    derivative[n, m, s, c, a] * velocity[m, n, b]
            end
        end
    else
        a, s, b, c = tensor_indices
        @inbounds for n in band_start:band_end, m in band_start:band_end
            active_pair_mask !== nothing && !active_pair_mask[n, m] && continue
            ws.response_kernel[n, m, a, s, b, c] =
                derivative[m, n, s, b, a] * velocity[n, m, c] -
                derivative[n, m, s, c, a] * velocity[m, n, b]
        end
    end
    return ws.response_kernel
end

"""
Return `DeltaE^2/(DeltaE^2+eta^2)^2` for the shift-spin-current denominator.

`DeltaE` and regularization `eta` use eV; the weight has inverse-square-energy units and performs no additional regularization checks.
"""
@inline function shift_spin_current_energy_weight(
    energy_difference::Real,
    denominator_regularization::Real,
)
    difference_squared = energy_difference^2
    return difference_squared / (difference_squared + denominator_regularization^2)^2
end

"""
Add shift-spin kernels to `local_response[energy,a,spin,b,c]` using occupations, delta weights and regularized transition-energy factors.

Preserve ordered pairs and caller-supplied prefactor; reuse optional frequency scratch and return the mutated tensor without k-point normalization.
"""
function accumulate_shift_spin_current_response!(
    local_response::Array{ComplexF64, 5},
    response_kernel::Array{ComplexF64, 6},
    occupation_differences::Matrix{Float64},
    delta::Array{Float64, 3},
    energy_differences::Matrix{Float64},
    denominator_regularization::Real,
    prefactor,
    band_start::Int,
    band_end::Int,
    spatial_dimension::Int,
    ;
    active_pairs_nmajor::Union{Nothing, AbstractVector{NTuple{2, Int}}} = nothing,
    active_pair_count::Int = -1,
    frequency_weights::Union{Nothing, Vector{Float64}} = nothing,
    frequency_pair_weights::Union{Nothing, Matrix{Float64}} = nothing,
    _frequency_contraction_scratch::Union{Nothing, _FrequencyContractionScratch} = nothing,
)
    if active_pairs_nmajor !== nothing
        pair_count = active_pair_count < 0 ? length(active_pairs_nmajor) : active_pair_count
        @inbounds for energy_index in axes(delta, 1)
            for pair_index in 1:pair_count
                n, m = active_pairs_nmajor[pair_index]
                weight = occupation_differences[n, m] * delta[energy_index, n, m]
                weight == 0.0 && continue
                energy_weight = shift_spin_current_energy_weight(
                    energy_differences[n, m],
                    denominator_regularization,
                )
                energy_weight == 0.0 && continue
                cweight = prefactor * energy_weight * weight
                for c in 1:spatial_dimension,
                    b in 1:spatial_dimension,
                    s in 1:3,
                    a in 1:spatial_dimension

                    local_response[energy_index, a, s, b, c] +=
                        cweight * response_kernel[n, m, a, s, b, c]
                end
            end
        end
        return local_response
    end
    num_photon_energies = size(delta, 1)
    band_count = band_end - band_start + 1
    frequency_contraction_strategy = _select_frequency_contraction_strategy(
        num_photon_energies,
        band_count^2,
        active_pairs_nmajor,
        _frequency_contraction_scratch,
    )
    if frequency_contraction_strategy !== :scalar
        frequency_pair_weights === nothing && throw(
            ArgumentError(
                "Shift Spin Current frequency contraction requires frequency_pair_weights.",
            ),
        )
        @inbounds for n in band_start:band_end, m in band_start:band_end
            frequency_pair_weights[n, m] = shift_spin_current_energy_weight(
                energy_differences[n, m],
                denominator_regularization,
            )
        end
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
            pair_weights = frequency_pair_weights,
        )
    end
    use_pair_tensor_frequency =
        frequency_weights !== nothing &&
        length(frequency_weights) >= num_photon_energies &&
        num_photon_energies >= 200 &&
        band_count >= 16
    if use_pair_tensor_frequency
        @inbounds for n in band_start:band_end, m in band_start:band_end
            energy_weight = shift_spin_current_energy_weight(
                energy_differences[n, m],
                denominator_regularization,
            )
            for energy_index in 1:num_photon_energies
                frequency_weights[energy_index] =
                    occupation_differences[n, m] * delta[energy_index, n, m]
            end
            energy_weight == 0.0 && continue
            for c in 1:spatial_dimension,
                b in 1:spatial_dimension,
                s in 1:3,
                a in 1:spatial_dimension

                kernel = response_kernel[n, m, a, s, b, c]
                for energy_index in 1:num_photon_energies
                    weight = frequency_weights[energy_index]
                    weight == 0.0 && continue
                    cweight = prefactor * energy_weight * weight
                    local_response[energy_index, a, s, b, c] += cweight * kernel
                end
            end
        end
        return local_response
    end
    @inbounds for energy_index in axes(delta, 1)
        for n in band_start:band_end, m in band_start:band_end
            weight = occupation_differences[n, m] * delta[energy_index, n, m]
            weight == 0.0 && continue
            energy_weight = shift_spin_current_energy_weight(
                energy_differences[n, m],
                denominator_regularization,
            )
            energy_weight == 0.0 && continue
            cweight = prefactor * energy_weight * weight
            for c in 1:spatial_dimension,
                b in 1:spatial_dimension,
                s in 1:3,
                a in 1:spatial_dimension

                local_response[energy_index, a, s, b, c] +=
                    cweight * response_kernel[n, m, a, s, b, c]
            end
        end
    end
    return local_response
end

"""
Sum one `(a,spin,b,c)` shift-spin component with occupation, broadening and regularized energy-denominator weights.

Energy differences and regularization use eV; the supplied prefactor fixes physical units and the kernel is not modified.
"""
function shift_spin_current_component(
    response_kernel::Array{ComplexF64, 6},
    occupation_differences::AbstractMatrix{Float64},
    delta::AbstractMatrix{Float64},
    energy_differences::Matrix{Float64},
    denominator_regularization::Real,
    prefactor,
    tensor_indices::Vector{Int},
    band_start::Int,
    band_end::Int,
    ;
    active_pairs_nmajor::Union{Nothing, AbstractVector{NTuple{2, Int}}} = nothing,
    active_pair_count::Int = -1,
)
    a, s, b, c = tensor_indices
    value = COMPLEX_ZERO
    if active_pairs_nmajor !== nothing
        pair_count = active_pair_count < 0 ? length(active_pairs_nmajor) : active_pair_count
        0 <= pair_count <= length(active_pairs_nmajor) || throw(
            ArgumentError(
                "active_pair_count=$(active_pair_count) must be between 0 and " *
                "$(length(active_pairs_nmajor)).",
            ),
        )
        @inbounds for pair_index in 1:pair_count
            n, m = active_pairs_nmajor[pair_index]
            weight = occupation_differences[n, m] * delta[n, m]
            weight == 0.0 && continue
            energy_weight = shift_spin_current_energy_weight(
                energy_differences[n, m],
                denominator_regularization,
            )
            energy_weight == 0.0 && continue
            value += prefactor * energy_weight * weight * response_kernel[n, m, a, s, b, c]
        end
        return value
    end
    @inbounds for n in band_start:band_end, m in band_start:band_end
        weight = occupation_differences[n, m] * delta[n, m]
        weight == 0.0 && continue
        energy_weight =
            shift_spin_current_energy_weight(energy_differences[n, m], denominator_regularization)
        energy_weight == 0.0 && continue
        value += prefactor * energy_weight * weight * response_kernel[n, m, a, s, b, c]
    end
    return value
end
