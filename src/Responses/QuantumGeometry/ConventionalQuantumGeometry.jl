# Conventional k-resolved quantum-geometry and quantum-Hermitian-connection kernels.

using LinearAlgebra
using Printf

"""
For `tensor_indices=(a,b,c)`, contract the conventional generalized position
derivative `r_nv,nc;b^a` with the Hamiltonian-gauge connection `A_nc,nv^c` and
average over the Cartesian product of selected conduction and valence groups.
The routine preserves caller band order, applies no physical prefactor, and does
not own Brillouin-zone normalization.
"""
function conventional_quantum_hermitian_connection_component(
    data::KPointMatrixData,
    band_selection::Tuple{Vector{Int}, Vector{Int}},
    tensor_indices::Vector{Int},
    num_orbitals::Int,
)
    a, b, c = tensor_indices
    conduction, valence = band_selection
    total = COMPLEX_ZERO
    @inbounds for nc in conduction
        for nv in valence
            total +=
                conventional_generalized_position_derivative_element(
                    data,
                    nv,
                    nc,
                    b,
                    a,
                    num_orbitals,
                ) * data.berry_connection[nc, nv, c]
        end
    end
    return total / (length(conduction) * length(valence))
end

# Average the generalized-position-derivative/connection product over selected conduction/valence pairs, preparing commutator scratch by GEMM.
function _conventional_quantum_hermitian_connection_component_gemm(
    data::KPointMatrixData,
    scratch::_ConventionalGeneralizedDerivativeScratch,
    band_selection::Tuple{Vector{Int}, Vector{Int}},
    tensor_indices::Vector{Int},
    num_orbitals::Int,
)
    conduction, valence = band_selection
    pair_count = length(conduction) * length(valence)
    a, b, c = tensor_indices
    _prepare_conventional_generalized_derivative_commutators!(
        scratch,
        data,
        b,
        a,
        1,
        num_orbitals,
        :full_gemm,
    )
    total = COMPLEX_ZERO
    @inbounds for nc in conduction
        for nv in valence
            total +=
                _conventional_generalized_position_derivative_gemm_element(
                    data,
                    scratch,
                    nv,
                    nc,
                    b,
                    a,
                ) * data.berry_connection[nc, nv, c]
        end
    end
    return total / pair_count
end

"""
Add `prefactor * occupation_difference * delta * kernel` into the frequency-resolved rank-three tensor and return it.

Kernel axes are `(n,m,a,b,c)`; skip exactly zero weights and preserve the existing energy/m/n reduction order. Integration normalization is caller-owned.
"""
function accumulate_conventional_geometry_qhc_response!(
    local_response::Array{ComplexF64, 4},
    response_kernel::Array{ComplexF64, 5},
    occupation_differences::Matrix{Float64},
    delta::Array{Float64, 3},
    prefactor,
    band_start::Int64,
    band_end::Int64,
    spatial_dimension::Int64,
)
    num_photon_energies = size(delta, 1)
    @inbounds for energy_index in 1:num_photon_energies
        for m in band_start:band_end
            for n in band_start:band_end
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
Return the arithmetic mean of `response_kernel[nc,nv,a,b,c]` over conduction/valence groups.

Require nonempty validated groups and Cartesian indices; no occupations, prefactors or k-space weights are applied.
"""
function quantum_hermitian_connection_component(
    response_kernel::Array{ComplexF64, 5},
    band_selection::Tuple{Vector{Int}, Vector{Int}},
    tensor_indices::Vector{Int},
)
    a, b, c = tensor_indices
    conduction, valence = band_selection
    total = COMPLEX_ZERO
    for nc in conduction
        for nv in valence
            total += response_kernel[nc, nv, a, b, c]
        end
    end
    return total / (length(conduction) * length(valence))
end

"""
Return the real band Berry curvature `Omega_n^{ab}` from the antisymmetric
Hamiltonian-gauge connection product plus the diagonal Wannier-curvature term.
`tensor_indices=(a,b)` follows Cartesian derivative order. The function applies
neither occupations nor Brillouin-zone normalization.
"""
function berry_curvature_component(
    data::KPointMatrixData,
    band::Int,
    tensor_indices::Vector{Int},
    num_orbitals::Int64,
)
    a, b = tensor_indices
    value = 0.0
    @inbounds for m in 1:num_orbitals
        m == band && continue
        value += -imag(data.berry_connection[band, m, a] * data.berry_connection[m, band, b])
    end
    value = 2.0 * value + real(data.hamiltonian_curvature[band, band, a, b])
    return ComplexF64(value, 0.0)
end

"""
Return the real occupation-weighted Berry curvature from diagonal Hamiltonian curvature and `(f_n-f_m)*i*A_nm^a*A_mn^b`.

Require one occupation per orbital; `(a,b)` are Cartesian axes in the Hamiltonian gauge. The output is complex with zero imaginary part and excludes Brillouin-zone normalization.
"""
function berry_curvature_occupied_sum_component(
    data::KPointMatrixData,
    tensor_indices::Vector{Int},
    num_orbitals::Int64,
    occupations::AbstractVector{<:Real},
)
    length(occupations) == num_orbitals || error(
        "Berry_Curvature occupied-sum occupations length must match num_orbitals=$(num_orbitals).",
    )
    a, b = tensor_indices
    value = 0.0 + 0.0im
    @inbounds for n in 1:num_orbitals
        fn = occupations[n]
        value += fn * data.hamiltonian_curvature[n, n, a, b]
        for m in 1:num_orbitals
            m == n && continue
            fm = occupations[m]
            value +=
                (fn - fm) * 1.0im * data.berry_connection[n, m, a] * data.berry_connection[m, n, b]
        end
    end
    return ComplexF64(real(value), 0.0)
end

"""
Return one non-Abelian curvature block element for a chosen band subspace.

Add external-band connection commutators to the Hamiltonian curvature; exclude intermediate bands inside `band_group`. Row/column indices belong to that subspace and `(a,b)` follow Cartesian derivative order.
"""
function berry_curvature_block_element(
    data::KPointMatrixData,
    row_band::Int,
    column_band::Int,
    band_group::Vector{Int},
    tensor_indices,
    num_orbitals::Int64,
)
    a, b = tensor_indices
    value = data.hamiltonian_curvature[row_band, column_band, a, b]
    @inbounds for other_band in 1:num_orbitals
        other_band in band_group && continue
        value +=
            1.0im * (
                data.berry_connection[row_band, other_band, a] *
                data.berry_connection[other_band, column_band, b] -
                data.berry_connection[row_band, other_band, b] *
                data.berry_connection[other_band, column_band, a]
            )
    end
    return value
end

"""
Contract the non-Abelian curvature of the selected initial/final subspaces with
Hamiltonian-gauge Berry connections. `tensor_indices=(b,a,d,c)` preserves the
public rank-4 convention; block curvature excludes states within its own
subspace, so degenerate rotations remain covariant. The returned component is
band-averaged only by its caller and carries no k-point normalization.
"""
function hermitian_curvature_tensor_component(
    data::KPointMatrixData,
    band_selection::Tuple{Vector{Int}, Vector{Int}},
    tensor_indices::Vector{Int},
    num_orbitals::Int64,
)
    b, a, d, c = tensor_indices
    final_group, initial_group = band_selection
    total = COMPLEX_ZERO
    curvature_indices = (d, c)
    @inbounds for initial_row in initial_group
        for final_row in final_group
            transported = COMPLEX_ZERO
            for final_column in final_group
                transported +=
                    berry_curvature_block_element(
                        data,
                        final_row,
                        final_column,
                        final_group,
                        curvature_indices,
                        num_orbitals,
                    ) * data.berry_connection[final_column, initial_row, a]
            end
            for initial_column in initial_group
                transported -=
                    data.berry_connection[final_row, initial_column, a] *
                    berry_curvature_block_element(
                        data,
                        initial_column,
                        initial_row,
                        initial_group,
                        curvature_indices,
                        num_orbitals,
                    )
            end
            total += data.berry_connection[initial_row, final_row, b] * transported
        end
    end
    return -1.0im * total
end

"""
Return `g_n^{ab}=Re sum_{m!=n} A_nm^a A_mn^b` in the established
Hamiltonian gauge. `tensor_indices=(a,b)` follows Cartesian derivative order;
occupations, band sums, units, and Brillouin-zone normalization are caller-owned.
"""
function quantum_metric_component(
    data::KPointMatrixData,
    band::Int,
    tensor_indices::Vector{Int},
    num_orbitals::Int64,
)
    a, b = tensor_indices
    value = 0.0
    @inbounds for m in 1:num_orbitals
        m == band && continue
        value += real(data.berry_connection[band, m, a] * data.berry_connection[m, band, b])
    end
    return ComplexF64(value, 0.0)
end

"""
Return the real metric sum weighted by `(f_n+f_m)/2` over distinct bands.

Require one occupation per orbital; use Hamiltonian-gauge connections and Cartesian `(a,b)` order without k-point normalization.
"""
function quantum_metric_band_sum_component(
    data::KPointMatrixData,
    tensor_indices::Vector{Int},
    num_orbitals::Int64,
    occupations::AbstractVector{<:Real},
)
    length(occupations) == num_orbitals ||
        error("Quantum_Metric band-sum occupations length must match num_orbitals=$(num_orbitals).")
    a, b = tensor_indices
    value = 0.0
    @inbounds for n in 1:num_orbitals
        fn = occupations[n]
        for m in 1:num_orbitals
            m == n && continue
            fm = occupations[m]
            value +=
                0.5 *
                (fn + fm) *
                real(data.berry_connection[n, m, a] * data.berry_connection[m, n, b])
        end
    end
    return ComplexF64(value, 0.0)
end

"""
Average `A_mn^a*A_nm^b` over the ordered Cartesian product of two band groups.

Reject identical-band pairs and empty products; inputs are Hamiltonian-gauge Berry connections, with no occupation or Brillouin-zone factors.
"""
function interband_quantum_geometry_component(
    data::KPointMatrixData,
    band_selection::Tuple{Vector{Int}, Vector{Int}},
    tensor_indices::Vector{Int},
)
    a, b = tensor_indices
    first_group, second_group = band_selection
    total = COMPLEX_ZERO
    count = 0
    @inbounds for m in first_group
        for n in second_group
            m == n && error(
                "Invalid interband band_selection=$(band_selection); interband pairs require distinct band indices.",
            )
            total += data.berry_connection[m, n, a] * data.berry_connection[n, m, b]
            count += 1
        end
    end
    count > 0 || error(
        "Invalid interband band_selection=$(band_selection); band groups must produce at least one pair.",
    )
    return total / count
end

"""
Return `-Im(Q_ab-Q_ba)` for the two selected interband groups, as a real-valued ComplexF64.

Use the validated pair-average geometry convention and Cartesian `(a,b)` ordering; no occupation factors are included.
"""
function interband_berry_curvature_component(
    data::KPointMatrixData,
    band_selection::Tuple{Vector{Int}, Vector{Int}},
    tensor_indices::Vector{Int},
)
    a, b = tensor_indices
    q_ab = interband_quantum_geometry_component(data, band_selection, Int[a, b])
    q_ba = interband_quantum_geometry_component(data, band_selection, Int[b, a])
    return ComplexF64(-imag(q_ab - q_ba), 0.0)
end

"""
Return `Re(Q_ab+Q_ba)/2` for the selected interband groups, as a real-valued ComplexF64.

Preserve the pair-average Hamiltonian-gauge convention and Cartesian `(a,b)` axes; no occupation factors are included.
"""
function interband_quantum_metric_component(
    data::KPointMatrixData,
    band_selection::Tuple{Vector{Int}, Vector{Int}},
    tensor_indices::Vector{Int},
)
    a, b = tensor_indices
    q_ab = interband_quantum_geometry_component(data, band_selection, Int[a, b])
    q_ba = interband_quantum_geometry_component(data, band_selection, Int[b, a])
    return ComplexF64(0.5 * real(q_ab + q_ba), 0.0)
end

"""
Return pair-averaged real Zeeman metric and curvature from mixed Berry-connection/spin matrix products.

Tensor axes are `(orbital Cartesian,spin Cartesian)`; use Hamiltonian-gauge matrices and unchanged upstream spin units. Reject identical-band pairs and empty products.
"""
function zeeman_interband_quantum_geometry_components(
    data::KPointMatrixData,
    band_selection::Tuple{Vector{Int}, Vector{Int}},
    tensor_indices::Vector{Int},
)
    alpha, beta = tensor_indices
    first_group, second_group = band_selection
    quantum_metric = COMPLEX_ZERO
    berry_curvature = COMPLEX_ZERO
    count = 0
    @inbounds for m in first_group
        for n in second_group
            m == n && error(
                "Invalid Zeeman interband band_selection=$(band_selection); interband pairs require distinct band indices.",
            )
            A_nm = data.berry_connection[n, m, alpha] * data.spin.hamiltonian_gauge[m, n, beta]
            B_nm = data.berry_connection[m, n, alpha] * data.spin.hamiltonian_gauge[n, m, beta]
            quantum_metric += 0.5 * (A_nm + B_nm)
            berry_curvature += 1.0im * (A_nm - B_nm)
            count += 1
        end
    end
    count > 0 || error(
        "Invalid Zeeman interband band_selection=$(band_selection); band groups must produce at least one pair.",
    )
    return (
        quantum_metric = ComplexF64(real(quantum_metric) / count, 0.0),
        berry_curvature = ComplexF64(real(berry_curvature) / count, 0.0),
    )
end

"""
Select the Berry-curvature component of the mixed connection/spin pair average.

Retain `(orbital Cartesian,spin Cartesian)` order, Hamiltonian gauge and upstream spin units; use the validation of `zeeman_interband_quantum_geometry_components`.
"""
function zeeman_interband_berry_curvature_component(
    data::KPointMatrixData,
    band_selection::Tuple{Vector{Int}, Vector{Int}},
    tensor_indices::Vector{Int},
)
    return zeeman_interband_quantum_geometry_components(data, band_selection, tensor_indices).berry_curvature
end

"""
Select the quantum-metric component of the mixed connection/spin pair average.

Retain `(orbital Cartesian,spin Cartesian)` order, Hamiltonian gauge and upstream spin units; use the validation of `zeeman_interband_quantum_geometry_components`.
"""
function zeeman_interband_quantum_metric_component(
    data::KPointMatrixData,
    band_selection::Tuple{Vector{Int}, Vector{Int}},
    tensor_indices::Vector{Int},
)
    return zeeman_interband_quantum_geometry_components(data, band_selection, tensor_indices).quantum_metric
end

"""
Sum real connection products from a nonempty target group to bands outside that group.

Reject invalid target bounds, retain Cartesian `(a,b)` order and do not divide by group size; no occupations or k-space weights are applied.
"""
function interband_quantum_metric_group_sum_component(
    data::KPointMatrixData,
    band_group::Vector{Int},
    tensor_indices::Vector{Int},
    num_orbitals::Int64,
)
    isempty(band_group) &&
        error("Invalid target band group=$(band_group); target band group must be non-empty.")
    a, b = tensor_indices
    in_group = falses(num_orbitals)
    for nu in band_group
        (nu < 1 || nu > num_orbitals) && error(
            "Invalid target band group=$(band_group); expected band indices in 1:$(num_orbitals).",
        )
        in_group[nu] = true
    end
    value = 0.0
    @inbounds for nu in band_group
        for mu in 1:num_orbitals
            in_group[mu] && continue
            value += real(data.berry_connection[nu, mu, a] * data.berry_connection[mu, nu, b])
        end
    end
    return ComplexF64(value, 0.0)
end

"""
Return the external-band metric trace of the target subspace in Cartesian `(a,b)` order.

Delegate to the nonempty, bounds-checked interband group sum; no group averaging or occupation weights are introduced.
"""
quantum_metric_group_sum_component(
    data::KPointMatrixData,
    band_group::Vector{Int},
    tensor_indices::Vector{Int},
    num_orbitals::Int64,
) = interband_quantum_metric_group_sum_component(data, band_group, tensor_indices, num_orbitals)

"""
Sum the real diagonal non-Abelian curvature over the target band group, excluding internal-group connection transitions.

Preserve Cartesian `(a,b)` order and Hamiltonian gauge; no occupation or k-point weights are included.
"""
function berry_curvature_group_sum_component(
    data::KPointMatrixData,
    band_group::Vector{Int},
    tensor_indices::Vector{Int},
    num_orbitals::Int64,
)
    isempty(band_group) &&
        error("Invalid target band group=$(band_group); target band group must be non-empty.")
    a, b = tensor_indices
    in_group = falses(num_orbitals)
    for nu in band_group
        (nu < 1 || nu > num_orbitals) && error(
            "Invalid target band group=$(band_group); expected band indices in 1:$(num_orbitals).",
        )
        in_group[nu] = true
    end
    value = 0.0
    @inbounds for nu in band_group
        value += real(data.hamiltonian_curvature[nu, nu, a, b])
        for mu in 1:num_orbitals
            in_group[mu] && continue
            q_ab = data.berry_connection[nu, mu, a] * data.berry_connection[mu, nu, b]
            q_ba = data.berry_connection[nu, mu, b] * data.berry_connection[mu, nu, a]
            value += -imag(q_ab - q_ba)
        end
    end
    return ComplexF64(value, 0.0)
end
