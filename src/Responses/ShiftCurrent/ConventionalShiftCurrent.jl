# Unified shift-current integral and k-slice calculations.
# Conventional shift-current conductivity from a Wannier tight-binding model.

using LinearAlgebra
using Printf

const _GENERALIZED_DERIVATIVE_STRATEGIES = (:auto, :scalar, :rectangular_gemm, :full_gemm)
const _GENERALIZED_DERIVATIVE_GEMM_MIN_ORBITALS = 64
const _GENERALIZED_DERIVATIVE_GEMM_MIN_BANDS = 32
const _GENERALIZED_DERIVATIVE_GEMM_MIN_PAIR_DENSITY = 0.70
const _GENERALIZED_DERIVATIVE_FULL_GEMM_MIN_ORBITALS = 64

# Choose scalar, full GEMM or rectangular GEMM from orbital/window size and required-pair density; keep QHC on its scalar path.
function _select_conventional_generalized_derivative_strategy(
    num_orbitals::Int,
    band_count::Int,
    required_pair_count::Int;
    qhc::Bool = false,
)
    num_orbitals > 0 || return :scalar
    band_count > 0 || return :scalar
    required_pair_count > 0 || return :scalar
    # The fixed N=16/32/64/128 calibration showed full GEMM slower than scalar QHC
    # even for the largest disjoint half/half band selection. Keep the prototype as
    # an oracle only; production QHC stays on the exact scalar summation order.
    qhc && return :scalar
    pair_density = required_pair_count / (band_count * band_count)
    if num_orbitals < _GENERALIZED_DERIVATIVE_GEMM_MIN_ORBITALS ||
       band_count < _GENERALIZED_DERIVATIVE_GEMM_MIN_BANDS ||
       pair_density < _GENERALIZED_DERIVATIVE_GEMM_MIN_PAIR_DENSITY
        return :scalar
    end
    if band_count == num_orbitals
        return num_orbitals >= _GENERALIZED_DERIVATIVE_FULL_GEMM_MIN_ORBITALS ? :full_gemm : :scalar
    end
    return :rectangular_gemm
end

# Combine one internal connection derivative with supplied connection/Hamiltonian commutators and the regularized band denominator.
@inline function _conventional_generalized_position_derivative_from_commutators(
    data::KPointMatrixData,
    n::Int,
    m::Int,
    a::Int,
    b::Int,
    connection_commutator::ComplexF64,
    hamiltonian_commutator::ComplexF64,
)
    endpoint_AD =
        data.internal_connection[n, n, a] * data.gauge_correction[n, m, b] -
        data.gauge_correction[n, n, b] * data.internal_connection[n, m, a]
    endpoint_HD =
        data.hamiltonian_derivatives[n, n, a] * data.gauge_correction[n, m, b] -
        data.gauge_correction[n, n, b] * data.hamiltonian_derivatives[n, m, a]
    if m != n
        endpoint_AD +=
            data.internal_connection[n, m, a] * data.gauge_correction[m, m, b] -
            data.gauge_correction[n, m, b] * data.internal_connection[m, m, a]
        endpoint_HD +=
            data.hamiltonian_derivatives[n, m, a] * data.gauge_correction[m, m, b] -
            data.gauge_correction[n, m, b] * data.hamiltonian_derivatives[m, m, a]
    end
    sum_AD = connection_commutator - endpoint_AD
    sum_HD = hamiltonian_commutator - endpoint_HD
    AD_bit =
        (data.internal_connection[n, n, b] - data.internal_connection[m, m, b]) *
        data.gauge_correction[n, m, a] +
        (data.internal_connection[n, n, a] - data.internal_connection[m, m, a]) *
        data.gauge_correction[n, m, b]
    AA_bit =
        (data.internal_connection[n, n, b] - data.internal_connection[m, m, b]) *
        data.internal_connection[n, m, a]
    DV_bit =
        (data.hamiltonian_derivatives[n, n, b] - data.hamiltonian_derivatives[m, m, b]) *
        data.gauge_correction[n, m, a] +
        (data.hamiltonian_derivatives[n, n, a] - data.hamiltonian_derivatives[m, m, a]) *
        data.gauge_correction[n, m, b]
    return data.internal_connection_derivatives[n, m, a, b] + AD_bit - 1.0im * AA_bit +
           sum_AD +
           1.0im *
           (data.hamiltonian_second_derivatives[n, m, a, b] + sum_HD + DV_bit) *
           (-data.inverse_energy_differences[n, m])
end

# Prepare selected connection/Hamiltonian commutators with full or rectangular matrix products in the supplied scratch.
function _prepare_conventional_generalized_derivative_commutators!(
    scratch::_ConventionalGeneralizedDerivativeScratch,
    data::KPointMatrixData,
    a::Int,
    b::Int,
    band_start::Int,
    band_end::Int,
    strategy::Symbol,
)
    if strategy === :full_gemm
        mul!(
            scratch.connection_commutator,
            @view(data.internal_connection[:, :, a]),
            @view(data.gauge_correction[:, :, b]),
        )
        mul!(
            scratch.product_scratch,
            @view(data.gauge_correction[:, :, b]),
            @view(data.internal_connection[:, :, a]),
        )
        @inbounds for column in axes(scratch.connection_commutator, 2)
            for row in axes(scratch.connection_commutator, 1)
                scratch.connection_commutator[row, column] -= scratch.product_scratch[row, column]
            end
        end
        mul!(
            scratch.hamiltonian_commutator,
            @view(data.hamiltonian_derivatives[:, :, a]),
            @view(data.gauge_correction[:, :, b]),
        )
        mul!(
            scratch.product_scratch,
            @view(data.gauge_correction[:, :, b]),
            @view(data.hamiltonian_derivatives[:, :, a]),
        )
        @inbounds for column in axes(scratch.hamiltonian_commutator, 2)
            for row in axes(scratch.hamiltonian_commutator, 1)
                scratch.hamiltonian_commutator[row, column] -= scratch.product_scratch[row, column]
            end
        end
        return scratch
    end
    strategy === :rectangular_gemm || error("Unsupported GEMM strategy=$(strategy).")
    band_range = band_start:band_end
    connection_commutator = @view scratch.connection_commutator[band_range, band_range]
    hamiltonian_commutator = @view scratch.hamiltonian_commutator[band_range, band_range]
    product_scratch = @view scratch.product_scratch[band_range, band_range]
    mul!(
        connection_commutator,
        @view(data.internal_connection[band_range, :, a]),
        @view(data.gauge_correction[:, band_range, b]),
    )
    mul!(
        product_scratch,
        @view(data.gauge_correction[band_range, :, b]),
        @view(data.internal_connection[:, band_range, a]),
    )
    @inbounds for column in axes(connection_commutator, 2)
        for row in axes(connection_commutator, 1)
            connection_commutator[row, column] -= product_scratch[row, column]
        end
    end
    mul!(
        hamiltonian_commutator,
        @view(data.hamiltonian_derivatives[band_range, :, a]),
        @view(data.gauge_correction[:, band_range, b]),
    )
    mul!(
        product_scratch,
        @view(data.gauge_correction[band_range, :, b]),
        @view(data.hamiltonian_derivatives[:, band_range, a]),
    )
    @inbounds for column in axes(hamiltonian_commutator, 2)
        for row in axes(hamiltonian_commutator, 1)
            hamiltonian_commutator[row, column] -= product_scratch[row, column]
        end
    end
    return scratch
end

# Read the prepared GEMM commutator entries and assemble one generalized-position derivative in the original Cartesian index order.
@inline function _conventional_generalized_position_derivative_gemm_element(
    data::KPointMatrixData,
    scratch::_ConventionalGeneralizedDerivativeScratch,
    n::Int,
    m::Int,
    a::Int,
    b::Int,
)
    return _conventional_generalized_position_derivative_from_commutators(
        data,
        n,
        m,
        a,
        b,
        scratch.connection_commutator[n, m],
        scratch.hamiltonian_commutator[n, m],
    )
end

"""
Return a conventional generalized-position derivative between ordered Hamiltonian-gauge bands.

Combine internal derivatives, connection commutators and Hamiltonian terms using the precomputed regularized inverse energy difference; `(a,b)` retain the implementation's derivative/connection order. Inputs must contain all prerequisite capabilities.
"""
@inline function conventional_generalized_position_derivative_element(
    data::KPointMatrixData,
    n::Int,
    m::Int,
    a::Int,
    b::Int,
    num_orbitals::Int,
)
    sum_AD = COMPLEX_ZERO
    sum_HD = COMPLEX_ZERO
    @inbounds for l in 1:num_orbitals
        if l != n && l != m
            sum_AD +=
                data.internal_connection[n, l, a] * data.gauge_correction[l, m, b] -
                data.gauge_correction[n, l, b] * data.internal_connection[l, m, a]
            sum_HD +=
                data.hamiltonian_derivatives[n, l, a] * data.gauge_correction[l, m, b] -
                data.gauge_correction[n, l, b] * data.hamiltonian_derivatives[l, m, a]
        end
    end
    AD_bit =
        (data.internal_connection[n, n, b] - data.internal_connection[m, m, b]) *
        data.gauge_correction[n, m, a] +
        (data.internal_connection[n, n, a] - data.internal_connection[m, m, a]) *
        data.gauge_correction[n, m, b]
    AA_bit =
        (data.internal_connection[n, n, b] - data.internal_connection[m, m, b]) *
        data.internal_connection[n, m, a]
    DV_bit =
        (data.hamiltonian_derivatives[n, n, b] - data.hamiltonian_derivatives[m, m, b]) *
        data.gauge_correction[n, m, a] +
        (data.hamiltonian_derivatives[n, n, a] - data.hamiltonian_derivatives[m, m, a]) *
        data.gauge_correction[n, m, b]
    return data.internal_connection_derivatives[n, m, a, b] + AD_bit - 1.0im * AA_bit +
           sum_AD +
           1.0im *
           (data.hamiltonian_second_derivatives[n, m, a, b] + sum_HD + DV_bit) *
           (-data.inverse_energy_differences[n, m])
end

# Count band pairs required by the current active mask and tensor request before selecting scalar or GEMM evaluation.
function _count_conventional_generalized_derivative_pairs(
    band_start::Int,
    band_end::Int,
    active_pair_mask::Union{Nothing, AbstractMatrix{Bool}},
    tensor_indices,
)
    active_pair_mask === nothing && return (band_end - band_start + 1)^2
    pair_count = 0
    if tensor_indices === nothing
        @inbounds for n in band_start:band_end
            for m in band_start:band_end
                (active_pair_mask[n, m] || active_pair_mask[m, n]) && (pair_count += 1)
            end
        end
    else
        @inbounds for n in band_start:band_end
            for m in band_start:band_end
                active_pair_mask[n, m] && (pair_count += n == m ? 1 : 2)
            end
        end
    end
    return pair_count
end

# Fill requested generalized derivatives from precomputed commutators, preserving active band-pair and Cartesian selections.
function _compute_conventional_generalized_position_derivative_gemm!(
    generalized_position_derivative::Array{ComplexF64, 4},
    data::KPointMatrixData,
    scratch::_ConventionalGeneralizedDerivativeScratch,
    band_start::Int,
    band_end::Int,
    spatial_dimension::Int,
    strategy::Symbol;
    active_pair_mask::Union{Nothing, AbstractMatrix{Bool}} = nothing,
    active_pairs_nmajor::Union{Nothing, AbstractVector{NTuple{2, Int}}} = nothing,
    active_pair_count::Int = -1,
    derivative_required_pairs_nmajor::Union{Nothing, AbstractVector{NTuple{2, Int}}} = nothing,
    derivative_pair_count::Int = -1,
    tensor_indices::Union{Nothing, AbstractVector{<:Integer}} = nothing,
)
    if tensor_indices === nothing
        derivative_pairs =
            derivative_required_pairs_nmajor === nothing ? active_pairs_nmajor :
            derivative_required_pairs_nmajor
        required_pair_count =
            derivative_pairs === nothing ? -1 :
            (derivative_pair_count < 0 ? length(derivative_pairs) : derivative_pair_count)
        @inbounds for a in 1:spatial_dimension
            for b in 1:spatial_dimension
                _prepare_conventional_generalized_derivative_commutators!(
                    scratch,
                    data,
                    a,
                    b,
                    band_start,
                    band_end,
                    strategy,
                )
                if derivative_pairs === nothing
                    for n in band_start:band_end
                        for m in band_start:band_end
                            if active_pair_mask !== nothing &&
                               !active_pair_mask[n, m] &&
                               !active_pair_mask[m, n]
                                continue
                            end
                            generalized_position_derivative[n, m, a, b] =
                                _conventional_generalized_position_derivative_gemm_element(
                                    data,
                                    scratch,
                                    n,
                                    m,
                                    a,
                                    b,
                                )
                        end
                    end
                else
                    for pair_index in 1:required_pair_count
                        n, m = derivative_pairs[pair_index]
                        generalized_position_derivative[n, m, a, b] =
                            _conventional_generalized_position_derivative_gemm_element(
                                data,
                                scratch,
                                n,
                                m,
                                a,
                                b,
                            )
                    end
                end
            end
        end
        return generalized_position_derivative
    end

    a, b, c = tensor_indices
    pair_count =
        active_pairs_nmajor === nothing ? -1 :
        (active_pair_count < 0 ? length(active_pairs_nmajor) : active_pair_count)
    _prepare_conventional_generalized_derivative_commutators!(
        scratch,
        data,
        c,
        a,
        band_start,
        band_end,
        strategy,
    )
    if active_pairs_nmajor === nothing
        @inbounds for n in band_start:band_end
            for m in band_start:band_end
                active_pair_mask !== nothing && !active_pair_mask[n, m] && continue
                generalized_position_derivative[n, m, c, a] =
                    _conventional_generalized_position_derivative_gemm_element(
                        data,
                        scratch,
                        n,
                        m,
                        c,
                        a,
                    )
                if b == c
                    generalized_position_derivative[m, n, b, a] =
                        _conventional_generalized_position_derivative_gemm_element(
                            data,
                            scratch,
                            m,
                            n,
                            b,
                            a,
                        )
                end
            end
        end
    else
        @inbounds for pair_index in 1:pair_count
            n, m = active_pairs_nmajor[pair_index]
            generalized_position_derivative[n, m, c, a] =
                _conventional_generalized_position_derivative_gemm_element(
                    data,
                    scratch,
                    n,
                    m,
                    c,
                    a,
                )
            if b == c
                generalized_position_derivative[m, n, b, a] =
                    _conventional_generalized_position_derivative_gemm_element(
                        data,
                        scratch,
                        m,
                        n,
                        b,
                        a,
                    )
            end
        end
    end
    b == c && return generalized_position_derivative

    _prepare_conventional_generalized_derivative_commutators!(
        scratch,
        data,
        b,
        a,
        band_start,
        band_end,
        strategy,
    )
    if active_pairs_nmajor === nothing
        @inbounds for n in band_start:band_end
            for m in band_start:band_end
                active_pair_mask !== nothing && !active_pair_mask[n, m] && continue
                generalized_position_derivative[m, n, b, a] =
                    _conventional_generalized_position_derivative_gemm_element(
                        data,
                        scratch,
                        m,
                        n,
                        b,
                        a,
                    )
            end
        end
    else
        @inbounds for pair_index in 1:pair_count
            n, m = active_pairs_nmajor[pair_index]
            generalized_position_derivative[m, n, b, a] =
                _conventional_generalized_position_derivative_gemm_element(
                    data,
                    scratch,
                    m,
                    n,
                    b,
                    a,
                )
        end
    end
    return generalized_position_derivative
end

# Fill selected shift-current tensor entries from prepared generalized-position derivatives and Berry connections.
function _assemble_conventional_shift_current_kernel_from_derivative!(
    response_kernel::Array{ComplexF64, 5},
    generalized_position_derivative::Array{ComplexF64, 4},
    data::KPointMatrixData,
    band_start::Int,
    band_end::Int,
    spatial_dimension::Int;
    active_pair_mask::Union{Nothing, AbstractMatrix{Bool}} = nothing,
    active_pairs_nmajor::Union{Nothing, AbstractVector{NTuple{2, Int}}} = nothing,
    active_pair_count::Int = -1,
    tensor_indices::Union{Nothing, AbstractVector{<:Integer}} = nothing,
)
    if active_pairs_nmajor !== nothing
        pair_count = active_pair_count < 0 ? length(active_pairs_nmajor) : active_pair_count
        if tensor_indices === nothing
            @inbounds for pair_index in 1:pair_count
                n, m = active_pairs_nmajor[pair_index]
                for a in 1:spatial_dimension
                    for b in 1:spatial_dimension
                        for c in 1:spatial_dimension
                            response_kernel[n, m, a, b, c] =
                                -1.0im * (
                                    generalized_position_derivative[n, m, c, a] *
                                    data.berry_connection[m, n, b] -
                                    generalized_position_derivative[m, n, b, a] *
                                    data.berry_connection[n, m, c]
                                )
                        end
                    end
                end
            end
        else
            a, b, c = tensor_indices
            @inbounds for pair_index in 1:pair_count
                n, m = active_pairs_nmajor[pair_index]
                response_kernel[n, m, a, b, c] =
                    -1.0im * (
                        generalized_position_derivative[n, m, c, a] *
                        data.berry_connection[m, n, b] -
                        generalized_position_derivative[m, n, b, a] *
                        data.berry_connection[n, m, c]
                    )
            end
        end
        return response_kernel
    end
    if tensor_indices === nothing
        @inbounds for n in band_start:band_end
            for m in band_start:band_end
                active_pair_mask !== nothing && !active_pair_mask[n, m] && continue
                for a in 1:spatial_dimension
                    for b in 1:spatial_dimension
                        for c in 1:spatial_dimension
                            response_kernel[n, m, a, b, c] =
                                -1.0im * (
                                    generalized_position_derivative[n, m, c, a] *
                                    data.berry_connection[m, n, b] -
                                    generalized_position_derivative[m, n, b, a] *
                                    data.berry_connection[n, m, c]
                                )
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
                response_kernel[n, m, a, b, c] =
                    -1.0im * (
                        generalized_position_derivative[n, m, c, a] *
                        data.berry_connection[m, n, b] -
                        generalized_position_derivative[m, n, b, a] *
                        data.berry_connection[n, m, c]
                    )
            end
        end
    end
    return response_kernel
end

"""
For the band pair `(n,m)` and Cartesian indices `(a,b,c)`, this stores the
length-gauge bracket built from the generalized position derivative
`r_nm;c^a` and Hamiltonian-gauge Berry connections. The first two array indices
are ordered exactly as the transition screen; compact pair lists preserve the
dense n-major summation order. This routine applies no occupation, broadening,
charge, cell-volume, or k-point prefactor and mutates only caller-owned kernels.
"""
function compute_conventional_shift_current_kernel!(
    response_kernel::Array{ComplexF64, 5},
    generalized_position_derivative::Array{ComplexF64, 4},
    data::KPointMatrixData,
    band_start::Int64,
    band_end::Int64,
    num_orbitals::Int64,
    spatial_dimension::Int64,
    ;
    active_pair_mask::Union{Nothing, AbstractMatrix{Bool}} = nothing,
    active_pairs_nmajor::Union{Nothing, AbstractVector{NTuple{2, Int}}} = nothing,
    active_pair_count::Int = -1,
    derivative_required_pairs_nmajor::Union{Nothing, AbstractVector{NTuple{2, Int}}} = nothing,
    derivative_pair_count::Int = -1,
    tensor_indices::Union{Nothing, AbstractVector{<:Integer}} = nothing,
    _generalized_derivative_scratch::Union{Nothing, _ConventionalGeneralizedDerivativeScratch} = nothing,
    _generalized_derivative_strategy::Symbol = :auto,
)
    _generalized_derivative_strategy in _GENERALIZED_DERIVATIVE_STRATEGIES || error(
        "Unsupported generalized-derivative strategy=$(_generalized_derivative_strategy); " *
        "expected one of $(_GENERALIZED_DERIVATIVE_STRATEGIES).",
    )
    _clear_response_kernel!(response_kernel, tensor_indices)
    if tensor_indices === nothing
        fill!(generalized_position_derivative, COMPLEX_ZERO)
    else
        a, b, c = tensor_indices
        fill!(@view(generalized_position_derivative[:, :, c, a]), COMPLEX_ZERO)
        b == c || fill!(@view(generalized_position_derivative[:, :, b, a]), COMPLEX_ZERO)
    end

    if _generalized_derivative_scratch !== nothing && _generalized_derivative_strategy !== :scalar
        band_count = band_end - band_start + 1
        required_pair_count =
            if derivative_required_pairs_nmajor !== nothing && tensor_indices === nothing
                derivative_pair_count < 0 ? length(derivative_required_pairs_nmajor) :
                derivative_pair_count
            elseif active_pairs_nmajor !== nothing
                pair_count = active_pair_count < 0 ? length(active_pairs_nmajor) : active_pair_count
                tensor_indices === nothing ? pair_count :
                min(band_count * band_count, 2 * pair_count)
            else
                _count_conventional_generalized_derivative_pairs(
                    band_start,
                    band_end,
                    active_pair_mask,
                    tensor_indices,
                )
            end
        selected_strategy =
            _generalized_derivative_strategy === :auto ?
            _select_conventional_generalized_derivative_strategy(
                num_orbitals,
                band_count,
                required_pair_count,
            ) : _generalized_derivative_strategy
        if selected_strategy !== :scalar
            _compute_conventional_generalized_position_derivative_gemm!(
                generalized_position_derivative,
                data,
                _generalized_derivative_scratch,
                band_start,
                band_end,
                spatial_dimension,
                selected_strategy;
                active_pair_mask = active_pair_mask,
                active_pairs_nmajor = active_pairs_nmajor,
                active_pair_count = active_pair_count,
                derivative_required_pairs_nmajor = derivative_required_pairs_nmajor,
                derivative_pair_count = derivative_pair_count,
                tensor_indices = tensor_indices,
            )
            return _assemble_conventional_shift_current_kernel_from_derivative!(
                response_kernel,
                generalized_position_derivative,
                data,
                band_start,
                band_end,
                spatial_dimension;
                active_pair_mask = active_pair_mask,
                active_pairs_nmajor = active_pairs_nmajor,
                active_pair_count = active_pair_count,
                tensor_indices = tensor_indices,
            )
        end
    end

    if active_pairs_nmajor !== nothing
        pair_count = active_pair_count < 0 ? length(active_pairs_nmajor) : active_pair_count
        derivative_pairs =
            derivative_required_pairs_nmajor === nothing ? active_pairs_nmajor :
            derivative_required_pairs_nmajor
        required_pair_count =
            derivative_pair_count < 0 ? length(derivative_pairs) : derivative_pair_count
        if tensor_indices === nothing
            @inbounds for pair_index in 1:required_pair_count
                n, m = derivative_pairs[pair_index]
                for a in 1:spatial_dimension
                    for b in 1:spatial_dimension
                        generalized_position_derivative[n, m, a, b] =
                            conventional_generalized_position_derivative_element(
                                data,
                                n,
                                m,
                                a,
                                b,
                                num_orbitals,
                            )
                    end
                end
            end
            @inbounds for pair_index in 1:pair_count
                n, m = active_pairs_nmajor[pair_index]
                for a in 1:spatial_dimension
                    for b in 1:spatial_dimension
                        for c in 1:spatial_dimension
                            response_kernel[n, m, a, b, c] =
                                -1.0im * (
                                    generalized_position_derivative[n, m, c, a] *
                                    data.berry_connection[m, n, b] -
                                    generalized_position_derivative[m, n, b, a] *
                                    data.berry_connection[n, m, c]
                                )
                        end
                    end
                end
            end
        else
            a, b, c = tensor_indices
            @inbounds for pair_index in 1:pair_count
                n, m = active_pairs_nmajor[pair_index]
                derivative_nm = conventional_generalized_position_derivative_element(
                    data,
                    n,
                    m,
                    c,
                    a,
                    num_orbitals,
                )
                derivative_mn = conventional_generalized_position_derivative_element(
                    data,
                    m,
                    n,
                    b,
                    a,
                    num_orbitals,
                )
                generalized_position_derivative[n, m, c, a] = derivative_nm
                generalized_position_derivative[m, n, b, a] = derivative_mn
                response_kernel[n, m, a, b, c] =
                    -1.0im * (
                        derivative_nm * data.berry_connection[m, n, b] -
                        derivative_mn * data.berry_connection[n, m, c]
                    )
            end
        end
        return response_kernel
    end

    if tensor_indices === nothing
        @inbounds for n in band_start:band_end
            for m in band_start:band_end
                if active_pair_mask !== nothing &&
                   !active_pair_mask[n, m] &&
                   !active_pair_mask[m, n]
                    continue
                end
                for a in 1:spatial_dimension
                    for b in 1:spatial_dimension
                        generalized_position_derivative[n, m, a, b] =
                            conventional_generalized_position_derivative_element(
                                data,
                                n,
                                m,
                                a,
                                b,
                                num_orbitals,
                            )
                    end
                end
            end
        end

        @inbounds for n in band_start:band_end
            for m in band_start:band_end
                active_pair_mask !== nothing && !active_pair_mask[n, m] && continue
                for a in 1:spatial_dimension
                    for b in 1:spatial_dimension
                        for c in 1:spatial_dimension
                            # Store the manuscript-oriented response_kernel[n,m] with
                            # n=valence and m=conduction:
                            # \mathcal{Q}_{nm}^{abc} =
                            # -i[(D_a r^c_nm)r^b_mn - (D_a r^b_mn)r^c_nm].
                            # The explicit -i belongs to the code array response_kernel here,
                            # so prefactor, occupation_differences, delta, and response_kernel follow the formula
                            # convention directly.
                            response_kernel[n, m, a, b, c] =
                                -1.0im * (
                                    generalized_position_derivative[n, m, c, a] *
                                    data.berry_connection[m, n, b] -
                                    generalized_position_derivative[m, n, b, a] *
                                    data.berry_connection[n, m, c]
                                )
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
                derivative_nm = conventional_generalized_position_derivative_element(
                    data,
                    n,
                    m,
                    c,
                    a,
                    num_orbitals,
                )
                derivative_mn = conventional_generalized_position_derivative_element(
                    data,
                    m,
                    n,
                    b,
                    a,
                    num_orbitals,
                )
                generalized_position_derivative[n, m, c, a] = derivative_nm
                generalized_position_derivative[m, n, b, a] = derivative_mn
                response_kernel[n, m, a, b, c] =
                    -1.0im * (
                        derivative_nm * data.berry_connection[m, n, b] -
                        derivative_mn * data.berry_connection[n, m, c]
                    )
            end
        end
    end
    return response_kernel
end

"""
Add occupation/broadening-weighted conventional kernels into `local_response[energy,a,b,c]`.

Multiply by the supplied prefactor, preserve active-pair traversal when provided, and reuse optional contraction scratch. Return the mutated tensor without k-mesh normalization.
"""
function accumulate_conventional_response!(
    local_response::Array{ComplexF64, 4},
    response_kernel::Array{ComplexF64, 5},
    occupation_differences::Matrix{Float64},
    delta::Array{Float64, 3},
    prefactor,
    band_start::Int64,
    band_end::Int64,
    spatial_dimension::Int64,
    ;
    active_pairs_mmajor::Union{Nothing, AbstractVector{NTuple{2, Int}}} = nothing,
    active_pair_count::Int = -1,
    frequency_weights::Union{Nothing, Vector{Float64}} = nothing,
    _frequency_contraction_scratch::Union{Nothing, _FrequencyContractionScratch} = nothing,
)
    num_photon_energies = size(delta, 1)
    if active_pairs_mmajor !== nothing
        pair_count = active_pair_count < 0 ? length(active_pairs_mmajor) : active_pair_count
        @inbounds for energy_index in 1:num_photon_energies
            for pair_index in 1:pair_count
                n, m = active_pairs_mmajor[pair_index]
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
        return local_response
    end
    band_count = band_end - band_start + 1
    frequency_contraction_strategy = _select_frequency_contraction_strategy(
        num_photon_energies,
        band_count^2,
        active_pairs_mmajor,
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
            pair_order = :mmajor,
        )
    end
    use_pair_tensor_frequency =
        frequency_weights !== nothing &&
        length(frequency_weights) >= num_photon_energies &&
        num_photon_energies >= 200 &&
        band_count >= 32
    if use_pair_tensor_frequency
        @inbounds for m in band_start:band_end
            for n in band_start:band_end
                for energy_index in 1:num_photon_energies
                    frequency_weights[energy_index] =
                        occupation_differences[n, m] * delta[energy_index, n, m]
                end
                for c in 1:spatial_dimension
                    for b in 1:spatial_dimension
                        for a in 1:spatial_dimension
                            kernel = response_kernel[n, m, a, b, c]
                            for energy_index in 1:num_photon_energies
                                weight = frequency_weights[energy_index]
                                weight == 0.0 && continue
                                cweight = prefactor * weight
                                local_response[energy_index, a, b, c] += cweight * kernel
                            end
                        end
                    end
                end
            end
        end
        return local_response
    end
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
Sum one `(a,b,c)` conventional response component over weighted band pairs at a single photon energy.

The caller supplies occupation differences, delta weights and the physical prefactor; preserve selected pair order without mutating the kernel.
"""
function conventional_component_response(
    response_kernel::Array{ComplexF64, 5},
    occupation_differences::AbstractMatrix{Float64},
    delta::AbstractMatrix{Float64},
    prefactor,
    tensor_indices::Vector{Int},
    band_start::Int64,
    band_end::Int64,
    ;
    active_pairs_mmajor::Union{Nothing, AbstractVector{NTuple{2, Int}}} = nothing,
    active_pair_count::Int = -1,
)
    a, b, c = tensor_indices
    value = COMPLEX_ZERO
    if active_pairs_mmajor !== nothing
        pair_count = active_pair_count < 0 ? length(active_pairs_mmajor) : active_pair_count
        0 <= pair_count <= length(active_pairs_mmajor) || throw(
            ArgumentError(
                "active_pair_count=$(active_pair_count) must be between 0 and " *
                "$(length(active_pairs_mmajor)).",
            ),
        )
        @inbounds for pair_index in 1:pair_count
            n, m = active_pairs_mmajor[pair_index]
            weight = occupation_differences[n, m] * delta[n, m]
            if weight != 0.0
                value += prefactor * weight * response_kernel[n, m, a, b, c]
            end
        end
        return value
    end
    @inbounds for m in band_start:band_end
        for n in band_start:band_end
            weight = occupation_differences[n, m] * delta[n, m]
            if weight != 0.0
                value += prefactor * weight * response_kernel[n, m, a, b, c]
            end
        end
    end
    return value
end
