"""Physical field-first/current-last conductivity-to-moment contraction.

Only moments actually consumed by requested conductivity components are retained.
No eigensystem, interpolation, occupation, integration or output policy is owned
by this plan. Repeated terms retain their multiplicity in the contraction table.
"""
struct BerryMultipoleTensorPlan{N, K}
    components::Vector{NTuple{N, Int}}
    moment_components::Vector{NTuple{N, Int}}
    moment_indices::Vector{NTuple{K, Int}}
end

# Validate unique rank-three or rank-four Cartesian conductivity components and derive their moment indices.
function BerryMultipoleTensorPlan(components::AbstractVector{NTuple{N, Int}}) where {N}
    N in (3, 4) || throw(ArgumentError("BCD/BCQ conductivity rank must be three or four"))
    !isempty(components) && length(unique(components)) == length(components) ||
        throw(ArgumentError("nonempty unique conductivity components required"))
    all(c -> all(a -> a in 1:3, c), components) ||
        throw(ArgumentError("invalid Cartesian component"))
    moments = NTuple{N, Int}[]
    indices = NTuple{N-1, Int}[]
    for component in components
        keys = if N == 3
            b, c, a = component
            ((a, b, c), (a, c, b))
        else
            b, c, d, a = component
            ((a, b, c, d), (a, c, b, d), (a, d, b, c))
        end
        row = map(keys) do key
            index = findfirst(==(key), moments)
            if index === nothing
                push!(moments, key)
                index = length(moments)
            end
            index
        end
        push!(indices, row)
    end
    return BerryMultipoleTensorPlan{N, N-1}(copy(components), moments, indices)
end

"""Derivative channels consumed by the chosen expression, including once-IBP BCQ FS."""
function berry_multipole_local_components(plan::BerryMultipoleTensorPlan{N}, order::Int) where {N}
    order in 0:2 || throw(ArgumentError("local geometry derivative order must be 0:2"))
    order == 0 && return NTuple{2, Int}[unique((c[1], c[2]) for c in plan.moment_components)...]
    if N == 3
        order == 1 || throw(ArgumentError("BCD moment consumes first derivatives only"))
        return copy(plan.moment_components)
    elseif order == 1
        result = NTuple{3, Int}[]
        for (a, b, c, d) in plan.moment_components, derivative_axis in (c, d)
            key = (a, b, derivative_axis)
            key in result || push!(result, key)
        end
        return result
    end
    return copy(plan.moment_components)
end

"""Constant SI multiplier; moments already include their actual d-dimensional measure."""
function berry_multipole_dc_prefactor(
    parameters::BerryMultipoleDCParameters,
    dimension::Int,
    ::Val{N},
) where {N}
    dimension in (2, 3) || throw(ArgumentError("BCD/BCQ supports sheet 2D or bulk 3D"))
    tau = parameters.relaxation_time_fs * 1e-15
    factor =
        N == 3 ? RESPONSE_CHARGE_C^3 * tau / (2 * RESPONSE_HBAR_JS^2) :
        N == 4 ? -RESPONSE_CHARGE_C^4 * tau^2 / (3 * RESPONSE_HBAR_JS^3) :
        throw(ArgumentError("invalid BCD/BCQ tensor rank"))
    return factor * (1e-10)^(N - dimension)
end

"""Apply the exact two-/three-term symmetrization only to requested components."""
function berry_multipole_dc_components(
    moments::AbstractMatrix{<:Real},
    plan::BerryMultipoleTensorPlan{N},
    parameters::BerryMultipoleDCParameters;
    spatial_dimension::Int,
) where {N}
    size(moments, 2) == length(plan.moment_components) ||
        throw(DimensionMismatch("compact moment channels"))
    all(isfinite, moments) || throw(ArgumentError("nonfinite integrated moment"))
    factor = berry_multipole_dc_prefactor(parameters, spatial_dimension, Val(N))
    result = zeros(Float64, size(moments, 1), length(plan.components))
    for channel in eachindex(plan.components), mu in axes(moments, 1)
        value = 0.0
        for index in plan.moment_indices[channel]
            value += moments[mu, index]
        end
        result[mu, channel] = factor * value
    end
    all(isfinite, result) || throw(ArgumentError("nonfinite BCD/BCQ conductivity"))
    return result
end
