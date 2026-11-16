"""Test-only comparison of conventional complex GEMMs with different output widths.

The production panel, write mask, scratch and arithmetic are never changed here.
Use binary64 round-to-nearest, gradual underflow, finite operands/results and
ordinary four-real-multiply complex products, not a three-real-GEMM regrouping.
The classical componentwise gamma bound is described by Higham:
https://nhigham.com/2022/09/13/what-is-fast-matrix-multiplication/

Expand each real/imaginary dot component into 2n real products. Two computed
products differ by at most 2gamma_m times their uncancelled component scale.
For one product use m=2n+2, N=4n+4; for the ordered sum of two products use
m=4n+4, N=8n+8. Here m bounds a rounding-dependency path, while N separately
bounds all scalar multiplication/addition roundings, including initialization
and unit beta accumulation. FMA reduces these counts. With eta the minimum
subnormal, add 2N*eta/(1-m*u) for the two computations. All bound arithmetic is
outward; a zero bound requires a genuinely zero absolute product sum. This is
neither a fixed absolute tolerance nor a promise about arbitrary BLAS algorithms.
"""
module PanelGemmComparisonSupport

export PanelComparisonAudit,
    comparison_report,
    record_comparison!,
    compare_link_panels,
    compare_vertex_panels,
    link_panel_case,
    vertex_panel_case,
    floating_environment

# Keep floating controls observable instead of constant-folding their probes.
@noinline function _probe_product(x::Float64, y::Float64)
    return x * y
end

# Addition probes distinguish nearest-even from directed rounding modes.
@noinline function _probe_add(x::Float64, y::Float64)
    return x + y
end

"""Observe RN and gradual-underflow controls without changing the calling thread."""
function floating_environment()
    one = Ref(1.0)
    unit = Ref(eps(Float64) / 2)
    normal = Ref(floatmin(Float64))
    tiny = Ref(reinterpret(Float64, UInt64(1)))
    nearest =
        _probe_add(one[], unit[]) == 1.0 &&
        _probe_add(-one[], -unit[]) == -1.0 &&
        _probe_add(one[], 3 * unit[]) == nextfloat(nextfloat(1.0)) &&
        _probe_add(-one[], -3 * unit[]) == -nextfloat(nextfloat(1.0))
    ftz = reinterpret(UInt64, _probe_product(normal[], 0.5))
    daz = reinterpret(UInt64, _probe_product(tiny[], 4503599627370496.0))
    return (
        round_to_nearest = nearest,
        gradual_underflow = ftz == 0x0008000000000000 && daz == 0x0010000000000000,
        ftz_probe_bits = string(ftz; base = 16, pad = 16),
        daz_probe_bits = string(daz; base = 16, pad = 16),
    )
end

# A non-IEEE environment is a failed prerequisite, never a larger tolerance.
function _require_environment(environment)
    environment.round_to_nearest && environment.gradual_underflow ||
        throw(ArgumentError("panel comparison requires RN and gradual underflow"))
    return nothing
end

# Directed upper arithmetic; distinguish a true zero factor from underflow.
function _upper_product(x::Float64, y::Float64)
    isfinite(x) && isfinite(y) && x >= 0 && y >= 0 ||
        throw(ArgumentError("invalid nonnegative comparison scale"))
    (iszero(x) || iszero(y)) && return 0.0
    result = nextfloat(x * y)
    isfinite(result) || throw(ArgumentError("panel comparison scale overflow"))
    return result
end

# Positive sums are also rounded outward, without inflating an exact zero.
function _upper_sum(x::Float64, y::Float64)
    iszero(y) && return x
    result = nextfloat(x + y)
    isfinite(result) || throw(ArgumentError("panel comparison scale overflow"))
    return result
end

# Both numerator conversion and division retain an upper bound.
function _roundoff_parameters(n::Int, products::Int)
    products in (1, 2) && 0 < n <= (typemax(Int) - 16) ÷ 8 ||
        throw(ArgumentError("unsupported comparison dimensions"))
    m = 2 * products * n + 2 * products
    rounds = 4 * products * n + 4 * products
    u = eps(Float64) / 2
    mu = _upper_product(nextfloat(Float64(m)), u)
    mu < 1 || throw(ArgumentError("rounding bound requires m*u < 1"))
    denominator = prevfloat(1.0 - mu)
    denominator > 0 || throw(ArgumentError("rounding bound denominator is not positive"))
    gamma = nextfloat(mu / denominator)
    factor = _upper_product(2.0, gamma)
    round_count = _upper_product(2.0, nextfloat(Float64(rounds)))
    underflow = _upper_product(nextfloat(round_count / denominator), nextfloat(0.0))
    isfinite(factor) && isfinite(underflow) || throw(ArgumentError("rounding bound overflow"))
    return (; m, rounds, factor, underflow)
end

# Outward real and imaginary scales include every original intermediate index.
function _component_scales(products, row, column)
    real_scale = 0.0
    imag_scale = 0.0
    for (left, right) in products
        for k in axes(left, 2)
            a, b = left[row, k], right[k, column]
            ar, ai = abs(real(a)), abs(imag(a))
            br, bi = abs(real(b)), abs(imag(b))
            real_scale = _upper_sum(real_scale, _upper_product(ar, br))
            real_scale = _upper_sum(real_scale, _upper_product(ai, bi))
            imag_scale = _upper_sum(imag_scale, _upper_product(ar, bi))
            imag_scale = _upper_sum(imag_scale, _upper_product(ai, br))
        end
    end
    return real_scale, imag_scale
end

# No arbitrary near-zero floor: a true zero scale requires numerical zero error.
function _allowed_error(scale, parameters)
    iszero(scale) && return 0.0
    return _upper_sum(_upper_product(parameters.factor, scale), parameters.underflow)
end

"""Compare selected finite values; unrelated columns remain independently bit-tested."""
function _compare_products(actual, reference, products, indices)
    _require_environment(floating_environment())
    size(actual) == size(reference) || throw(DimensionMismatch("comparison output shape"))
    n = size(first(products)[1], 2)
    for (left, right) in products
        size(left, 2) == size(right, 1) == n &&
        size(left, 1) == size(actual, 1) &&
        size(right, 2) == size(actual, 2) || throw(DimensionMismatch("comparison product shape"))
        all(isfinite, left) && all(isfinite, right) ||
            throw(ArgumentError("nonfinite operands require the original exact comparison"))
    end
    all(j -> 1 <= j <= size(actual, 2), indices) || throw(BoundsError(actual, indices))
    parameters = _roundoff_parameters(n, length(products))
    accepted = true
    components = near_zero = zero_scale = 0
    maximum_absolute = maximum_relative = maximum_scale = maximum_bound = 0.0
    maximum_ratio = near_zero_absolute = 0.0
    for column in indices, row in axes(actual, 1)
        a, b = actual[row, column], reference[row, column]
        isfinite(a) && isfinite(b) ||
            throw(ArgumentError("nonfinite results require the original exact comparison"))
        scales = _component_scales(products, row, column)
        for (x, y, scale) in ((real(a), real(b), scales[1]), (imag(a), imag(b), scales[2]))
            error = abs(x - y)
            isfinite(error) || throw(ArgumentError("nonfinite comparison difference"))
            upper_error = iszero(error) ? 0.0 : nextfloat(error)
            bound = _allowed_error(scale, parameters)
            accepted &= upper_error <= bound
            magnitude = max(abs(x), abs(y))
            relative = iszero(magnitude) ? 0.0 : error / magnitude
            ratio = iszero(bound) ? (iszero(error) ? 0.0 : Inf) : upper_error / bound
            components += 1
            zero_scale += iszero(scale)
            maximum_absolute = max(maximum_absolute, error)
            maximum_relative = max(maximum_relative, relative)
            maximum_scale = max(maximum_scale, scale)
            maximum_bound = max(maximum_bound, bound)
            maximum_ratio = max(maximum_ratio, ratio)
            if abs(y) <= bound
                near_zero += 1
                near_zero_absolute = max(near_zero_absolute, error)
            end
        end
    end
    return (;
        accepted,
        components,
        near_zero,
        zero_scale,
        maximum_absolute,
        maximum_relative,
        maximum_scale,
        maximum_bound,
        maximum_ratio,
        near_zero_absolute,
        path_length = parameters.m,
        rounding_count = parameters.rounds,
    )
end

"""Use the two-computation component bound for one complete-inner-dimension link."""
compare_link_panels(actual, reference, left, right, indices) =
    _compare_products(actual, reference, ((left, right),), indices)

"""Use both products in the original L*O followed by O*R beta-one insertion."""
compare_vertex_panels(actual, reference, left, right, overlap, indices) =
    _compare_products(actual, reference, ((left, overlap), (overlap, right)), indices)

# This describes the frozen fixture's expected branch, never an error-driven switch.
function _panel_storage_case(output, indices, factors...)
    n = size(output, 1)
    n >= 128 &&
    rem(n, 4) == 0 &&
    !isempty(indices) &&
    output isa StridedMatrix{ComplexF64} &&
    size(output) == (n, n) || return false
    previous = 0
    for band in indices
        previous < band <= n || return false
        previous = band
    end
    return all(
        factor ->
            factor isa StridedMatrix{ComplexF64} &&
            size(factor) == (n, n) &&
            !Base.mightalias(output, factor) &&
            all(isfinite, factor),
        factors,
    )
end

# Same-shape fallback comparisons retain the original UInt64 contract.
function link_panel_case(output, left, right, indices)
    _panel_storage_case(output, indices, left, right) || return false
    n = size(output, 1)
    lo = 64 * div(first(indices) - 1, 64) + 1
    hi = min(n, 64 * cld(last(indices), 64))
    return 2 * (hi - lo + 1) <= n
end

# Vertex demand is a union of panels rather than the link's enclosing span.
function vertex_panel_case(output, left, right, overlap, indices)
    _panel_storage_case(output, indices, left, right, overlap) || return false
    n = size(output, 1)
    previous = columns = 0
    for band in indices
        lo = 64 * div(band - 1, 64) + 1
        if lo != previous
            columns += min(64, n - lo + 1)
            previous = lo
        end
    end
    return 2 * columns <= n
end

"""Accumulate test diagnostics; this state never enters a production workspace."""
Base.@kwdef mutable struct PanelComparisonAudit
    comparisons::Int = 0
    components::Int = 0
    failures::Int = 0
    near_zero_components::Int = 0
    zero_scale_components::Int = 0
    maximum_absolute::Float64 = 0.0
    maximum_relative::Float64 = 0.0
    maximum_scale::Float64 = 0.0
    maximum_bound::Float64 = 0.0
    maximum_ratio::Float64 = 0.0
    near_zero_absolute::Float64 = 0.0
end

"""Record absolute/relative errors, uncancelled scales and near-zero observations."""
function record_comparison!(audit::PanelComparisonAudit, result)
    audit.comparisons += 1
    audit.components += result.components
    audit.failures += !result.accepted
    audit.near_zero_components += result.near_zero
    audit.zero_scale_components += result.zero_scale
    for name in (
        :maximum_absolute,
        :maximum_relative,
        :maximum_scale,
        :maximum_bound,
        :maximum_ratio,
        :near_zero_absolute,
    )
        setproperty!(audit, name, max(getproperty(audit, name), getproperty(result, name)))
    end
    return result.accepted
end

"""Return bounded diagnostic metadata without changing the comparison predicate."""
comparison_report(audit::PanelComparisonAudit) = (;
    (name => getfield(audit, name) for name in fieldnames(PanelComparisonAudit))...,
    arithmetic = "binary64 RN gradual-underflow conventional complex GEMM",
    environment = floating_environment(),
)

end
