const _FREQUENCY_CONTRACTION_STRATEGIES = (:blocked_scalar, :complex_gemm, :split_real_gemm)
const _FREQUENCY_CONTRACTION_AUTO_MIN_FREQUENCIES = 200
const _FREQUENCY_CONTRACTION_AUTO_MIN_PAIRS = 256

# Choose split-real GEMM only above the frequency/pair thresholds with dense pairs and available scratch; otherwise select scalar contraction.
@inline function _select_frequency_contraction_strategy(
    frequency_count::Int,
    pair_count::Int,
    active_pairs,
    scratch,
)
    return frequency_count >= _FREQUENCY_CONTRACTION_AUTO_MIN_FREQUENCIES &&
           pair_count >= _FREQUENCY_CONTRACTION_AUTO_MIN_PAIRS &&
           active_pairs === nothing &&
           scratch !== nothing ? :split_real_gemm : :scalar
end

"""
Reusable real/complex weight, kernel and output blocks for frequency-by-band-pair tensor contraction.

The constructor rejects nonpositive frequency, tensor or pair-block capacities; only explicitly packed block extents are valid.
"""
mutable struct _FrequencyContractionScratch
    weights::Matrix{Float64}
    complex_weights::Matrix{ComplexF64}
    kernel::Matrix{ComplexF64}
    kernel_real::Matrix{Float64}
    kernel_imag::Matrix{Float64}
    output::Matrix{ComplexF64}
    output_real::Matrix{Float64}
    output_imag::Matrix{Float64}
end

# Reusable real/complex weight, kernel and output blocks for frequency-by-band-pair tensor contraction.
#
# The constructor rejects nonpositive frequency, tensor or pair-block capacities; only explicitly packed block extents are valid.
function _FrequencyContractionScratch(
    frequency_count::Int,
    tensor_count::Int;
    pair_block::Int = 256,
)
    frequency_count > 0 || throw(ArgumentError("frequency_count must be positive."))
    tensor_count > 0 || throw(ArgumentError("tensor_count must be positive."))
    pair_block > 0 || throw(ArgumentError("pair_block must be positive."))
    return _FrequencyContractionScratch(
        zeros(Float64, frequency_count, pair_block),
        zeros(ComplexF64, frequency_count, pair_block),
        zeros(ComplexF64, pair_block, tensor_count),
        zeros(Float64, pair_block, tensor_count),
        zeros(Float64, pair_block, tensor_count),
        zeros(ComplexF64, frequency_count, tensor_count),
        zeros(Float64, frequency_count, tensor_count),
        zeros(Float64, frequency_count, tensor_count),
    )
end

# Decode a linear pair index in n-major or m-major order; reject unsupported order symbols.
@inline function _frequency_contraction_pair(
    pair_index::Int,
    n_start::Int,
    n_count::Int,
    m_start::Int,
    m_count::Int,
    pair_order::Symbol,
)
    offset = pair_index - 1
    if pair_order === :nmajor
        return n_start + fld(offset, m_count), m_start + rem(offset, m_count)
    elseif pair_order === :mmajor
        return n_start + rem(offset, n_count), m_start + fld(offset, n_count)
    end
    throw(ArgumentError("Unsupported pair_order=$(pair_order); expected :nmajor or :mmajor."))
end

# Reject incompatible energy, band, tensor and scratch capacities before blocked frequency contraction; return validated counts.
function _validate_frequency_contraction_dimensions(
    local_response,
    response_kernel,
    occupation_differences,
    delta,
    scratch::_FrequencyContractionScratch,
    n_start::Int,
    n_end::Int,
    m_start::Int,
    m_end::Int,
)
    frequency_count = size(delta, 1)
    size(local_response, 1) == frequency_count ||
        throw(DimensionMismatch("local_response and delta frequency dimensions differ."))
    num_orbitals = size(occupation_differences, 1)
    size(occupation_differences, 2) == num_orbitals ||
        throw(DimensionMismatch("occupation_differences must be square."))
    size(delta, 2) == num_orbitals && size(delta, 3) == num_orbitals ||
        throw(DimensionMismatch("delta band dimensions do not match occupation_differences."))
    size(response_kernel, 1) == num_orbitals && size(response_kernel, 2) == num_orbitals ||
        throw(DimensionMismatch("response_kernel band dimensions do not match."))
    1 <= n_start <= n_end <= num_orbitals || throw(ArgumentError("Invalid n band range."))
    1 <= m_start <= m_end <= num_orbitals || throw(ArgumentError("Invalid m band range."))
    tensor_count = div(length(local_response), frequency_count)
    length(response_kernel) == num_orbitals^2 * tensor_count ||
        throw(DimensionMismatch("response_kernel and local_response tensor dimensions differ."))
    size(scratch.weights, 1) >= frequency_count ||
        throw(DimensionMismatch("frequency scratch has insufficient frequency capacity."))
    size(scratch.kernel, 2) >= tensor_count ||
        throw(DimensionMismatch("frequency scratch has insufficient tensor capacity."))
    return frequency_count, num_orbitals, tensor_count
end

# Pack a bounded band-pair block into real/complex frequency weights and tensor kernels, including optional pair/frequency factors.
function _pack_frequency_contraction_block!(
    scratch::_FrequencyContractionScratch,
    response_kernel,
    occupation_differences,
    delta,
    block_start::Int,
    block_count::Int,
    n_start::Int,
    n_count::Int,
    m_start::Int,
    m_count::Int,
    pair_order::Symbol,
    frequency_count::Int,
    num_orbitals::Int,
    tensor_count::Int,
    pair_weights,
    frequency_weights,
)
    @inbounds for local_pair_index in 1:block_count
        pair_index = block_start + local_pair_index - 1
        n, m =
            _frequency_contraction_pair(pair_index, n_start, n_count, m_start, m_count, pair_order)
        pair_weight = pair_weights === nothing ? 1.0 : pair_weights[n, m]
        for energy_index in 1:frequency_count
            frequency_weight = frequency_weights === nothing ? 1.0 : frequency_weights[energy_index]
            weight =
                occupation_differences[n, m] *
                delta[energy_index, n, m] *
                pair_weight *
                frequency_weight
            scratch.weights[energy_index, local_pair_index] = weight
            scratch.complex_weights[energy_index, local_pair_index] = ComplexF64(weight)
        end
        kernel_pair_index = n + (m - 1) * num_orbitals
        for tensor_index in 1:tensor_count
            kernel_value =
                response_kernel[kernel_pair_index + (tensor_index - 1) * num_orbitals ^ 2]
            scratch.kernel[local_pair_index, tensor_index] = kernel_value
            scratch.kernel_real[local_pair_index, tensor_index] = real(kernel_value)
            scratch.kernel_imag[local_pair_index, tensor_index] = imag(kernel_value)
        end
    end
    pair_capacity = size(scratch.weights, 2)
    @inbounds for local_pair_index in (block_count + 1):pair_capacity
        for energy_index in 1:frequency_count
            scratch.weights[energy_index, local_pair_index] = 0.0
            scratch.complex_weights[energy_index, local_pair_index] = 0.0
        end
        for tensor_index in 1:tensor_count
            scratch.kernel[local_pair_index, tensor_index] = 0.0
            scratch.kernel_real[local_pair_index, tensor_index] = 0.0
            scratch.kernel_imag[local_pair_index, tensor_index] = 0.0
        end
    end
    return nothing
end

# Accumulate frequency contraction prototype into caller-owned storage.
function _accumulate_frequency_contraction_prototype!(
    local_response::Array{ComplexF64},
    response_kernel::Array{ComplexF64},
    occupation_differences::AbstractMatrix{Float64},
    delta::Array{Float64, 3},
    prefactor,
    n_start::Int,
    n_end::Int,
    m_start::Int,
    m_end::Int,
    scratch::_FrequencyContractionScratch;
    strategy::Symbol,
    pair_order::Symbol,
    pair_weights::Union{Nothing, AbstractMatrix{Float64}} = nothing,
    frequency_weights::Union{Nothing, AbstractVector{Float64}} = nothing,
)
    strategy in _FREQUENCY_CONTRACTION_STRATEGIES || throw(
        ArgumentError(
            "Unsupported frequency-contraction strategy=$(strategy); expected one of $(_FREQUENCY_CONTRACTION_STRATEGIES).",
        ),
    )
    frequency_count, num_orbitals, tensor_count = _validate_frequency_contraction_dimensions(
        local_response,
        response_kernel,
        occupation_differences,
        delta,
        scratch,
        n_start,
        n_end,
        m_start,
        m_end,
    )
    pair_weights === nothing ||
        size(pair_weights) == size(occupation_differences) ||
        throw(DimensionMismatch("pair_weights dimensions do not match."))
    frequency_weights === nothing ||
        length(frequency_weights) == frequency_count ||
        throw(DimensionMismatch("frequency_weights length does not match."))
    n_count = n_end - n_start + 1
    m_count = m_end - m_start + 1
    pair_count = n_count * m_count
    pair_capacity = size(scratch.weights, 2)
    fill!(scratch.output, 0.0)
    fill!(scratch.output_real, 0.0)
    fill!(scratch.output_imag, 0.0)
    first_block = true
    for block_start in 1:pair_capacity:pair_count
        block_count = min(pair_capacity, pair_count - block_start + 1)
        _pack_frequency_contraction_block!(
            scratch,
            response_kernel,
            occupation_differences,
            delta,
            block_start,
            block_count,
            n_start,
            n_count,
            m_start,
            m_count,
            pair_order,
            frequency_count,
            num_orbitals,
            tensor_count,
            pair_weights,
            frequency_weights,
        )
        if strategy === :blocked_scalar
            @inbounds for tensor_index in 1:tensor_count
                for energy_index in 1:frequency_count
                    for local_pair_index in 1:block_count
                        weight = scratch.weights[energy_index, local_pair_index]
                        weight == 0.0 && continue
                        scratch.output[energy_index, tensor_index] +=
                            weight * scratch.kernel[local_pair_index, tensor_index]
                    end
                end
            end
        elseif strategy === :complex_gemm
            mul!(
                scratch.output,
                scratch.complex_weights,
                scratch.kernel,
                1.0 + 0.0im,
                first_block ? 0.0 + 0.0im : 1.0 + 0.0im,
            )
        else
            mul!(
                scratch.output_real,
                scratch.weights,
                scratch.kernel_real,
                1.0,
                first_block ? 0.0 : 1.0,
            )
            mul!(
                scratch.output_imag,
                scratch.weights,
                scratch.kernel_imag,
                1.0,
                first_block ? 0.0 : 1.0,
            )
        end
        first_block = false
    end
    @inbounds for tensor_index in 1:tensor_count
        for energy_index in 1:frequency_count
            contraction =
                strategy === :split_real_gemm ?
                ComplexF64(
                    scratch.output_real[energy_index, tensor_index],
                    scratch.output_imag[energy_index, tensor_index],
                ) : scratch.output[energy_index, tensor_index]
            response_index = energy_index + (tensor_index - 1) * frequency_count
            local_response[response_index] += prefactor * contraction
        end
    end
    return local_response
end

# Accumulate frequency contraction scalar oracle into caller-owned storage.
function _accumulate_frequency_contraction_scalar_oracle!(
    local_response::Array{ComplexF64},
    response_kernel::Array{ComplexF64},
    occupation_differences::AbstractMatrix{Float64},
    delta::Array{Float64, 3},
    prefactor,
    n_start::Int,
    n_end::Int,
    m_start::Int,
    m_end::Int;
    pair_order::Symbol,
    pair_weights::Union{Nothing, AbstractMatrix{Float64}} = nothing,
    frequency_weights::Union{Nothing, AbstractVector{Float64}} = nothing,
)
    frequency_count = size(delta, 1)
    num_orbitals = size(occupation_differences, 1)
    tensor_count = div(length(local_response), frequency_count)
    n_count = n_end - n_start + 1
    m_count = m_end - m_start + 1
    pair_count = n_count * m_count
    @inbounds for energy_index in 1:frequency_count
        frequency_weight = frequency_weights === nothing ? 1.0 : frequency_weights[energy_index]
        for pair_index in 1:pair_count
            n, m = _frequency_contraction_pair(
                pair_index,
                n_start,
                n_count,
                m_start,
                m_count,
                pair_order,
            )
            pair_weight = pair_weights === nothing ? 1.0 : pair_weights[n, m]
            weight =
                occupation_differences[n, m] *
                delta[energy_index, n, m] *
                pair_weight *
                frequency_weight
            weight == 0.0 && continue
            cweight = prefactor * weight
            kernel_pair_index = n + (m - 1) * num_orbitals
            for tensor_index in 1:tensor_count
                response_index = energy_index + (tensor_index - 1) * frequency_count
                local_response[response_index] +=
                    cweight *
                    response_kernel[kernel_pair_index + (tensor_index - 1) * num_orbitals ^ 2]
            end
        end
    end
    return local_response
end
