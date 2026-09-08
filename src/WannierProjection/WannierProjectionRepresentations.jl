const ORBITAL_LABELS = Dict(
    "s" => ("s",),
    "p" => ("pz", "px", "py"),
    "d" => ("dz2", "dxz", "dyz", "dx2-y2", "dxy"),
    "f" => ("fz3", "fxz2", "fyz2", "fzx2-zy2", "fxyz", "fx3-3xy2", "f3yx2-y3"),
    "sp" => ("sp-1", "sp-2"),
    "p2" => ("pz", "py"),
    "pxy" => ("px", "py"),
    "sp2" => ("sp2-1", "sp2-2", "sp2-3"),
    "pz" => ("pz",),
    "dxz" => ("dxz",),
    "dyz" => ("dyz",),
    "dxy" => ("dxy",),
    "sp3" => ("sp3-1", "sp3-2", "sp3-3", "sp3-4"),
    "sp3d2" => ("sp3d2-1", "sp3d2-2", "sp3d2-3", "sp3d2-4", "sp3d2-5", "sp3d2-6"),
    "t2g" => ("dxz", "dyz", "dxy"),
    "t2g_dxy_first" => ("dxy", "dxz", "dyz"),
    "eg" => ("dx2-y2", "dz2"),
)

const BASE_SHELLS = ("s", "p", "d", "f")

const BASE_ORBITAL_SHELL =
    Dict(label => shell for shell in BASE_SHELLS for label in ORBITAL_LABELS[shell])

const HYBRID_COEFFICIENTS = Dict{String, Dict{String, Float64}}(
    "sp-1" => Dict("s" => inv(sqrt(2.0)), "px" => inv(sqrt(2.0))),
    "sp-2" => Dict("s" => inv(sqrt(2.0)), "px" => -inv(sqrt(2.0))),
    "sp2-1" => Dict("s" => inv(sqrt(3.0)), "px" => -inv(sqrt(6.0)), "py" => inv(sqrt(2.0))),
    "sp2-2" => Dict("s" => inv(sqrt(3.0)), "px" => -inv(sqrt(6.0)), "py" => -inv(sqrt(2.0))),
    "sp2-3" => Dict("s" => inv(sqrt(3.0)), "px" => 2inv(sqrt(6.0))),
    "sp3-1" => Dict("s" => 0.5, "px" => 0.5, "py" => 0.5, "pz" => 0.5),
    "sp3-2" => Dict("s" => 0.5, "px" => 0.5, "py" => -0.5, "pz" => -0.5),
    "sp3-3" => Dict("s" => 0.5, "px" => -0.5, "py" => 0.5, "pz" => -0.5),
    "sp3-4" => Dict("s" => 0.5, "px" => -0.5, "py" => -0.5, "pz" => 0.5),
    "sp3d2-1" => Dict(
        "s" => inv(sqrt(6.0)),
        "px" => -inv(sqrt(2.0)),
        "dz2" => -inv(sqrt(12.0)),
        "dx2-y2" => 0.5,
    ),
    "sp3d2-2" => Dict(
        "s" => inv(sqrt(6.0)),
        "px" => inv(sqrt(2.0)),
        "dz2" => -inv(sqrt(12.0)),
        "dx2-y2" => 0.5,
    ),
    "sp3d2-3" => Dict(
        "s" => inv(sqrt(6.0)),
        "py" => -inv(sqrt(2.0)),
        "dz2" => -inv(sqrt(12.0)),
        "dx2-y2" => -0.5,
    ),
    "sp3d2-4" => Dict(
        "s" => inv(sqrt(6.0)),
        "py" => inv(sqrt(2.0)),
        "dz2" => -inv(sqrt(12.0)),
        "dx2-y2" => -0.5,
    ),
    "sp3d2-5" => Dict("s" => inv(sqrt(6.0)), "pz" => -inv(sqrt(2.0)), "dz2" => inv(sqrt(3.0))),
    "sp3d2-6" => Dict("s" => inv(sqrt(6.0)), "pz" => inv(sqrt(2.0)), "dz2" => inv(sqrt(3.0))),
)

for label in keys(BASE_ORBITAL_SHELL)
    get!(HYBRID_COEFFICIENTS, label, Dict(label => 1.0))
end

const OrbitalExponent = NTuple{3, Int}
const OrbitalPolynomial = Dict{OrbitalExponent, Float64}

# Construct a sparse homogeneous polynomial from coefficient/exponent pairs.
function _orbital_polynomial(terms...)
    polynomial = OrbitalPolynomial()
    for (coefficient, exponent) in terms
        polynomial[exponent] = get(polynomial, exponent, 0.0) + Float64(coefficient)
    end
    return polynomial
end

const BASE_ORBITAL_POLYNOMIALS = Dict{String, OrbitalPolynomial}(
    "s" => _orbital_polynomial((1.0, (0, 0, 0))),
    "px" => _orbital_polynomial((1.0, (1, 0, 0))),
    "py" => _orbital_polynomial((1.0, (0, 1, 0))),
    "pz" => _orbital_polynomial((1.0, (0, 0, 1))),
    "dz2" => _orbital_polynomial(
        (-inv(2sqrt(3.0)), (2, 0, 0)),
        (-inv(2sqrt(3.0)), (0, 2, 0)),
        (inv(sqrt(3.0)), (0, 0, 2)),
    ),
    "dxz" => _orbital_polynomial((1.0, (1, 0, 1))),
    "dyz" => _orbital_polynomial((1.0, (0, 1, 1))),
    "dx2-y2" => _orbital_polynomial((0.5, (2, 0, 0)), (-0.5, (0, 2, 0))),
    "dxy" => _orbital_polynomial((1.0, (1, 1, 0))),
    "fz3" => _orbital_polynomial(
        (-3inv(2sqrt(15.0)), (2, 0, 1)),
        (-3inv(2sqrt(15.0)), (0, 2, 1)),
        (inv(sqrt(15.0)), (0, 0, 3)),
    ),
    "fxz2" => _orbital_polynomial(
        (-inv(2sqrt(10.0)), (3, 0, 0)),
        (-inv(2sqrt(10.0)), (1, 2, 0)),
        (2inv(sqrt(10.0)), (1, 0, 2)),
    ),
    "fyz2" => _orbital_polynomial(
        (-inv(2sqrt(10.0)), (2, 1, 0)),
        (-inv(2sqrt(10.0)), (0, 3, 0)),
        (2inv(sqrt(10.0)), (0, 1, 2)),
    ),
    "fzx2-zy2" => _orbital_polynomial((0.5, (2, 0, 1)), (-0.5, (0, 2, 1))),
    "fxyz" => _orbital_polynomial((1.0, (1, 1, 1))),
    "fx3-3xy2" =>
        _orbital_polynomial((inv(2sqrt(6.0)), (3, 0, 0)), (-3inv(2sqrt(6.0)), (1, 2, 0))),
    "f3yx2-y3" =>
        _orbital_polynomial((3inv(2sqrt(6.0)), (2, 1, 0)), (-inv(2sqrt(6.0)), (0, 3, 0))),
)

# Return the homogeneous monomial ordering for one angular degree.
function _monomial_exponents(degree::Int)
    result = OrbitalExponent[]
    for x_power in degree:-1:0
        remaining = degree - x_power
        for y_power in remaining:-1:0
            push!(result, (x_power, y_power, remaining - y_power))
        end
    end
    return result
end

# Multiply two sparse polynomials.
function _multiply_polynomials(left::OrbitalPolynomial, right::OrbitalPolynomial)
    result = OrbitalPolynomial()
    for (left_exp, left_value) in left, (right_exp, right_value) in right
        exponent = left_exp .+ right_exp
        result[exponent] = get(result, exponent, 0.0) + left_value * right_value
    end
    return result
end

# Raise one linear coordinate form to a nonnegative integer power.
function _linear_form_power(coefficients, power::Int)
    result = _orbital_polynomial((1.0, (0, 0, 0)))
    linear = _orbital_polynomial(
        (coefficients[1], (1, 0, 0)),
        (coefficients[2], (0, 1, 0)),
        (coefficients[3], (0, 0, 1)),
    )
    for _ in 1:power
        result = _multiply_polynomials(result, linear)
    end
    return result
end

# Substitute inverse-rotated coordinates into one orbital polynomial.
function _transform_polynomial(polynomial::OrbitalPolynomial, inverse_rotation)
    result = OrbitalPolynomial()
    for (exponent, coefficient) in polynomial
        transformed = _orbital_polynomial((coefficient, (0, 0, 0)))
        for coordinate in 1:3
            transformed = _multiply_polynomials(
                transformed,
                _linear_form_power(inverse_rotation[coordinate, :], exponent[coordinate]),
            )
        end
        for (transformed_exp, transformed_value) in transformed
            result[transformed_exp] = get(result, transformed_exp, 0.0) + transformed_value
        end
    end
    return result
end

# Convert a sparse polynomial to the declared monomial vector.
function _polynomial_vector(polynomial::OrbitalPolynomial, exponents)
    return [get(polynomial, exponent, 0.0) for exponent in exponents]
end

# Evaluate one sparse real-harmonic polynomial at local Cartesian momentum.
function _evaluate_orbital_polynomial(polynomial::OrbitalPolynomial, local_q)
    x, y, z = local_q
    return sum(
        coefficient * x^exponent[1] * y^exponent[2] * z^exponent[3] for
        (exponent, coefficient) in polynomial
    )
end

const PROJECTION_COMPATIBILITY_BOHR_ANGSTROM = 0.529177210544
const PROJECTION_HIGH_PRECISION_BOHR_ANGSTROM = 0.529177210903
const PROJECTION_RADIAL_SPLINES = Dict{Int, NamedTuple}()
const PROJECTION_RADIAL_SPLINE_LOCK = ReentrantLock()
const PROJECTION_LAGUERRE_RULES = Dict{Int, Tuple{Vector{Float64}, Vector{Float64}}}()
const PROJECTION_LAGUERRE_RULE_LOCK = ReentrantLock()

# Spherical Bessel j_l for the l<=3 projection boundary.
function _projection_spherical_bessel(degree::Int, argument::Float64)
    if abs(argument) < 1.0e-3
        squared = argument^2
        degree == 0 && return 1.0 - squared / 6.0 + squared^2 / 120.0 - squared^3 / 5040.0
        degree == 1 &&
            return argument * (1.0 / 3.0 - squared / 30.0 + squared^2 / 840.0 - squared^3 / 45360.0)
        degree == 2 && return squared * (1.0 / 15.0 - squared / 210.0 + squared^2 / 7560.0)
        return argument^3 * (1.0 / 105.0 - squared / 1890.0 + squared^2 / 83160.0)
    end
    j_previous = sin(argument) / argument
    degree == 0 && return j_previous
    j_current = sin(argument) / argument^2 - cos(argument) / argument
    degree == 1 && return j_current
    for order in 1:(degree - 1)
        j_previous, j_current = j_current, (2order + 1) * j_current / argument - j_previous
    end
    return j_current
end

# Reproduce the public WannierBerri radial-grid contract without a runtime
# dependency.  A linear prefix is followed by exponentially spaced tail points.
function _projection_mixed_grid(
    linear_end::Float64,
    maximum_value::Float64,
    linear_step::Float64,
    logarithmic_step::Float64,
)
    grid = collect(0.0:linear_step:(linear_end - linear_step))
    anchor = last(grid)
    logarithmic_coordinate = logarithmic_step
    while last(grid) < maximum_value
        push!(grid, anchor * exp(logarithmic_coordinate))
        logarithmic_coordinate += logarithmic_step
    end
    return grid
end

# Construct second derivatives for the not-a-knot cubic interpolant used by
# the compatibility baseline.  The first and final interior knots share their
# neighboring cubic polynomial, while every other row is the standard spline
# moment equation.
function _projection_not_a_knot_second_derivatives(knots::Vector{Float64}, values::Vector{Float64})
    count = length(knots)
    count == length(values) || throw(ArgumentError("spline knots and values disagree"))
    count >= 4 || throw(ArgumentError("not-a-knot spline requires at least four knots"))
    intervals = diff(knots)
    system = zeros(Float64, count, count)
    right_hand_side = zeros(Float64, count)
    system[1, 1] = -intervals[2]
    system[1, 2] = intervals[1] + intervals[2]
    system[1, 3] = -intervals[1]
    for index in 2:(count - 1)
        left_interval = intervals[index - 1]
        right_interval = intervals[index]
        system[index, index - 1] = left_interval
        system[index, index] = 2.0 * (left_interval + right_interval)
        system[index, index + 1] = right_interval
        right_hand_side[index] =
            6.0 * (
                (values[index + 1] - values[index]) / right_interval -
                (values[index] - values[index - 1]) / left_interval
            )
    end
    system[count, count - 2] = -intervals[end]
    system[count, count - 1] = intervals[end - 1] + intervals[end]
    system[count, count] = -intervals[end - 1]
    return system \ right_hand_side
end

# Tabulate one radial transform and its compatibility spline coefficients.
function _build_projection_radial_spline(degree::Int)
    degree in 0:3 || throw(ArgumentError("projection degree must lie in 0:3"))
    momentum_grid = _projection_mixed_grid(5.0, 100.0, 0.01, 0.2)
    radial_grid = _projection_mixed_grid(20.0, 200.0, 0.01, 0.1)
    radial_values = @. 2.0 * exp(-radial_grid) * radial_grid^2
    transform = Vector{Float64}(undef, length(momentum_grid))
    integrand = similar(radial_grid)
    for (momentum_index, momentum) in enumerate(momentum_grid)
        if degree > 0 && momentum < 1.0e-3
            transform[momentum_index] = 0.0
            continue
        end
        @inbounds for radial_index in eachindex(radial_grid)
            integrand[radial_index] =
                radial_values[radial_index] *
                _projection_spherical_bessel(degree, momentum * radial_grid[radial_index])
        end
        integral = 0.0
        @inbounds for radial_index in 1:(length(radial_grid) - 1)
            integral +=
                0.5 *
                (integrand[radial_index] + integrand[radial_index + 1]) *
                (radial_grid[radial_index + 1] - radial_grid[radial_index])
        end
        transform[momentum_index] = integral
    end
    second_derivatives = _projection_not_a_knot_second_derivatives(momentum_grid, transform)
    return (knots = momentum_grid, values = transform, second_derivatives = second_derivatives)
end

# Return the lazily constructed, thread-safe radial spline for one shell degree.
function _projection_radial_spline(degree::Int)
    return lock(PROJECTION_RADIAL_SPLINE_LOCK) do
        get!(PROJECTION_RADIAL_SPLINES, degree) do
            _build_projection_radial_spline(degree)
        end
    end
end

# Evaluate one not-a-knot cubic interval without extrapolating past the cutoff.
function _evaluate_projection_radial_spline(spline::NamedTuple, coordinate::Float64)
    knots = spline.knots
    coordinate <= last(knots) || return 0.0
    interval = min(searchsortedlast(knots, coordinate), length(knots) - 1)
    interval = max(interval, 1)
    width = knots[interval + 1] - knots[interval]
    left_weight = (knots[interval + 1] - coordinate) / width
    right_weight = (coordinate - knots[interval]) / width
    return left_weight * spline.values[interval] +
           right_weight * spline.values[interval + 1] +
           (
               (left_weight^3 - left_weight) * spline.second_derivatives[interval] +
               (right_weight^3 - right_weight) * spline.second_derivatives[interval + 1]
           ) * width^2 / 6.0
end

# Compatibility Fourier-Bessel transform of R_1(x)=2exp(-x).
function _projection_compatible_radial_factor(degree::Int, scaled_momentum::Float64)
    scaled_momentum <= 100.0 || return 0.0
    return _evaluate_projection_radial_spline(_projection_radial_spline(degree), scaled_momentum)
end

# Construct and cache one configurable high-precision Gauss-Laguerre rule.
function _projection_laguerre_rule(order::Int)
    return lock(PROJECTION_LAGUERRE_RULE_LOCK) do
        get!(PROJECTION_LAGUERRE_RULES, order) do
            diagonal = Float64[2index - 1 for index in 1:order]
            off_diagonal = Float64[index for index in 1:(order - 1)]
            decomposition = eigen(SymTridiagonal(diagonal, off_diagonal))
            (decomposition.values, abs2.(@view decomposition.vectors[1, :]))
        end
    end
end

# High-precision Fourier-Bessel transform without tabulation or interpolation.
function _projection_gauss_laguerre_radial_factor(degree::Int, scaled_momentum::Float64, order::Int)
    scaled_momentum <= 100.0 || return 0.0
    nodes, weights = _projection_laguerre_rule(order)
    integral = 0.0
    @inbounds for index in eachindex(nodes)
        coordinate = nodes[index]
        integral +=
            weights[index] *
            coordinate^2 *
            _projection_spherical_bessel(degree, scaled_momentum * coordinate)
    end
    return 2.0 * integral
end

# Dispatch the selected radial numerical contract without a global mode switch.
function _projection_radial_factor(
    degree::Int,
    momentum_norm::Float64,
    config::ProjectionRadialTransformConfig,
)
    if config.method == :wannierberri_compatible
        return _projection_compatible_radial_factor(
            degree,
            momentum_norm * PROJECTION_COMPATIBILITY_BOHR_ANGSTROM,
        )
    end
    return _projection_gauss_laguerre_radial_factor(
        degree,
        momentum_norm * PROJECTION_HIGH_PRECISION_BOHR_ANGSTROM,
        config.gauss_laguerre_order,
    )
end

# Normalized real spherical harmonic in the existing real-orbital gauge.
function _projection_spherical_harmonic(label::String, local_q)
    momentum_norm = norm(local_q)
    if label == "s"
        return inv(2sqrt(pi))
    end
    momentum_norm > 1.0e-12 || return 0.0
    shell = BASE_ORBITAL_SHELL[label]
    degree = findfirst(==(shell), BASE_SHELLS) - 1
    degree <= 2 || throw(ArgumentError("native AMN generation does not support f projectors"))
    polynomial = _evaluate_orbital_polynomial(BASE_ORBITAL_POLYNOMIALS[label], local_q)
    normalization = degree == 1 ? sqrt(3.0 / (4.0pi)) : sqrt(15.0 / (4.0pi))
    return normalization * polynomial / momentum_norm^degree
end

# Evaluate one base projector, including the selected radial transform and (-i)^l phase.
function _projection_base_value(
    label::String,
    local_q,
    radial_transform::ProjectionRadialTransformConfig,
)
    shell = BASE_ORBITAL_SHELL[label]
    degree = findfirst(==(shell), BASE_SHELLS) - 1
    radial = _projection_radial_factor(degree, norm(local_q), radial_transform)
    bohr_radius =
        radial_transform.method == :wannierberri_compatible ?
        PROJECTION_COMPATIBILITY_BOHR_ANGSTROM : PROJECTION_HIGH_PRECISION_BOHR_ANGSTROM
    prefactor = 4.0pi * bohr_radius^(3 / 2)
    return prefactor * (-1.0im)^degree * radial * _projection_spherical_harmonic(label, local_q)
end

"""Evaluate the ordered scalar orbital functions for one projection block."""
function projection_orbital_values(
    block::WannierProjectionBlock,
    local_q::AbstractVector{<:Real};
    radial_transform::ProjectionRadialTransformConfig = ProjectionRadialTransformConfig(),
)
    length(local_q) == 3 || throw(ArgumentError("local_q must have length three"))
    labels = ORBITAL_LABELS[block.orbital_set]
    if block.orbital_set in BASE_SHELLS
        return ComplexF64[
            _projection_base_value(label, local_q, radial_transform) for label in labels
        ]
    end
    shells, coefficients = _hybrid_basis_coefficients(block.orbital_set)
    base_values = ComplexF64[]
    for shell in shells, label in ORBITAL_LABELS[shell]
        push!(base_values, _projection_base_value(label, local_q, radial_transform))
    end
    return ComplexF64.(coefficients * base_values)
end

# Build the real-orbital representation of a full s, p, d, or f shell.
function _base_orbital_rotation(
    shell::String,
    rotation::Matrix{Float64};
    construction_policy::Symbol = :strict,
    mapping_diagnostics = nothing,
    operation_index::Int = 0,
)
    construction_policy in (:strict, :diagnostic) ||
        throw(ArgumentError("construction_policy must be :strict or :diagnostic"))
    all(isfinite, rotation) || throw(ArgumentError("orbital rotation contains nonfinite values"))
    degree = findfirst(==(shell), BASE_SHELLS) - 1
    labels = ORBITAL_LABELS[shell]
    exponents = _monomial_exponents(degree)
    basis = hcat(
        (_polynomial_vector(BASE_ORBITAL_POLYNOMIALS[label], exponents) for label in labels)...,
    )
    inverse_rotation = inv(rotation)
    transformed = hcat(
        (
            _polynomial_vector(
                _transform_polynomial(BASE_ORBITAL_POLYNOMIALS[label], inverse_rotation),
                exponents,
            ) for label in labels
        )...,
    )
    representation = basis \ transformed
    residual = maximum(abs, basis * representation - transformed)
    all(isfinite, representation) && isfinite(residual) ||
        throw(ArgumentError("orbital representation contains nonfinite values"))
    singular_values = svdvals(representation)
    minimum(singular_values) > eps(Float64) * max(1.0, maximum(singular_values)) ||
        throw(ArgumentError("orbital representation is rank deficient"))
    construction_policy == :diagnostic ||
        residual <= 1.0e-8 ||
        throw(ArgumentError("rotated $(shell) orbitals leave their harmonic subspace"))
    mapping_diagnostics === nothing || push!(
        mapping_diagnostics,
        (
            stage = "projection_orbital_rotation",
            code = "ORBITAL_HARMONIC_SUBSPACE_RESIDUAL",
            operation = operation_index,
            orbital_set = shell,
            value = residual,
            threshold = 1.0e-8,
            result = residual <= 1.0e-8 ? "PASS" : "FAIL",
            action = residual <= 1.0e-8 ? "CONTINUE" : "CONTINUE_DIAGNOSTIC",
        ),
    )
    representation[abs.(representation) .< 1.0e-12] .= 0.0
    return Matrix{Float64}(representation)
end

# Assemble square matrices on one block diagonal.
function _orbital_block_diagonal(matrices::Vector{Matrix{Float64}})
    dimension = sum(size(matrix, 1) for matrix in matrices)
    result = zeros(Float64, dimension, dimension)
    offset = 0
    for matrix in matrices
        local_dimension = size(matrix, 1)
        result[(offset + 1):(offset + local_dimension), (offset + 1):(offset + local_dimension)] .=
            matrix
        offset += local_dimension
    end
    return result
end

# Build a hybrid/subspace coefficient matrix in its contributing base-shell basis.
function _hybrid_basis_coefficients(orbital_set::String)
    labels = ORBITAL_LABELS[orbital_set]
    shells = sort!(
        unique(
            BASE_ORBITAL_SHELL[label] for output in labels for
            label in keys(HYBRID_COEFFICIENTS[output])
        );
        by = shell -> findfirst(==(shell), BASE_SHELLS),
    )
    offsets = Dict{String, Int}()
    dimension = 0
    for shell in shells
        offsets[shell] = dimension
        dimension += length(ORBITAL_LABELS[shell])
    end
    coefficients = zeros(Float64, length(labels), dimension)
    for (output_index, output) in enumerate(labels)
        for (base_label, coefficient) in HYBRID_COEFFICIENTS[output]
            shell = BASE_ORBITAL_SHELL[base_label]
            base_index = findfirst(==(base_label), ORBITAL_LABELS[shell])
            coefficients[output_index, offsets[shell] + base_index] = coefficient
        end
    end
    isapprox(
        coefficients * coefficients',
        Matrix{Float64}(I, length(labels), length(labels));
        atol = 1.0e-10,
        rtol = 0.0,
    ) || throw(ArgumentError("hybrid coefficients for $(orbital_set) are not orthonormal"))
    return shells, coefficients
end

# Build the orbital matrix between source and target local Cartesian row bases.
function _orbital_rotation(
    orbital_set::String,
    rotation_cartesian::Matrix{Float64},
    source_basis::AbstractMatrix,
    target_basis::AbstractMatrix;
    construction_policy::Symbol = :strict,
    mapping_diagnostics = nothing,
    operation_index::Int = 0,
)
    local_rotation = Matrix{Float64}(target_basis * rotation_cartesian * source_basis')
    if orbital_set in BASE_SHELLS
        return _base_orbital_rotation(
            orbital_set,
            local_rotation;
            construction_policy,
            mapping_diagnostics,
            operation_index,
        )
    end
    haskey(ORBITAL_LABELS, orbital_set) ||
        throw(ArgumentError("unsupported Wannier orbital set $(orbital_set)"))
    shells, coefficients = _hybrid_basis_coefficients(orbital_set)
    base_rotation = _orbital_block_diagonal([
        _base_orbital_rotation(
            shell,
            local_rotation;
            construction_policy,
            mapping_diagnostics,
            operation_index,
        ) for shell in shells
    ])
    result = coefficients * base_rotation * coefficients'
    result[abs.(result) .< 1.0e-12] .= 0.0
    all(isfinite, result) ||
        throw(ArgumentError("orbital representation contains nonfinite values"))
    singular_values = svdvals(result)
    minimum(singular_values) > eps(Float64) * max(1.0, maximum(singular_values)) ||
        throw(ArgumentError("orbital representation is rank deficient"))
    residual = norm(result' * result - Matrix{Float64}(I, size(result, 1), size(result, 1)))
    construction_policy == :diagnostic ||
        residual <= 1.0e-8 ||
        throw(ArgumentError("orbital subspace $(orbital_set) is not closed by this operation"))
    mapping_diagnostics === nothing || push!(
        mapping_diagnostics,
        (
            stage = "projection_orbital_rotation",
            code = "ORBITAL_SUBSPACE_UNITARITY_RESIDUAL",
            operation = operation_index,
            orbital_set = orbital_set,
            value = residual,
            threshold = 1.0e-8,
            result = residual <= 1.0e-8 ? "PASS" : "FAIL",
            action = residual <= 1.0e-8 ? "CONTINUE" : "CONTINUE_DIAGNOSTIC",
        ),
    )
    return result
end

# Parse a local-axis vector from a projection option.
function _parse_projection_vector(value::AbstractString, field::AbstractString)
    tokens = split(value, ',')
    length(tokens) == 3 || throw(ArgumentError("$(field) must contain three values"))
    return parse_wannier_float.(tokens, field)
end

# Construct a right-handed row basis from optional x and z directions.
function _build_local_projection_basis(x_axis, z_axis)
    x_axis === nothing && z_axis === nothing && return Matrix{Float64}(I, 3, 3)
    if z_axis === nothing
        x = x_axis ./ norm(x_axis)
        reference = abs(x[3]) < 0.9 ? [0.0, 0.0, 1.0] : [0.0, 1.0, 0.0]
        z = reference .- dot(reference, x) .* x
        z ./= norm(z)
    else
        z = z_axis ./ norm(z_axis)
        reference =
            x_axis === nothing ? (abs(z[1]) < 0.9 ? [1.0, 0.0, 0.0] : [0.0, 1.0, 0.0]) : x_axis
        x = reference .- dot(reference, z) .* z
        x ./= norm(x)
    end
    y = cross(z, x)
    y ./= norm(y)
    x = cross(y, z)
    x ./= norm(x)
    return Matrix{Float64}(transpose(hcat(x, y, z)))
end

# Select structure centers addressed by one Wannier90 projection selector.
function _projection_centers(
    selector_value::AbstractString,
    input::WannierWinData,
    tolerance::Float64,
)
    selector = String(selector_value)
    if occursin('=', selector)
        prefix, value = split(selector, '='; limit = 2)
        normalized = lowercase(strip(prefix))
        vector = _parse_projection_vector(value, "projection center")
        if normalized in ("f", "frac", "fractional")
            return reshape(mod.(vector, 1.0), 3, 1)
        elseif normalized in ("c", "cart", "cartesian")
            return reshape(mod.(transpose(vector) * inv(input.lattice), 1.0), 3, 1)
        end
        throw(ArgumentError("unknown projection center prefix $(prefix)"))
    end
    matches = findall(==(selector), input.species)
    isempty(matches) && throw(ArgumentError("projection selector $(selector) matches no WIN atom"))
    positions = input.positions_fractional[:, matches]
    if size(positions, 2) > 1
        for left in 1:(size(positions, 2) - 1), right in (left + 1):size(positions, 2)
            residual = positions[:, left] .- positions[:, right]
            residual .-= round.(residual)
            maximum(abs, residual) > tolerance || throw(
                ArgumentError(
                    "projection selector $(selector) contains duplicate periodic centers",
                ),
            )
        end
    end
    return positions
end

# Select projection centers from the public lightweight structure model.
function _projection_centers(
    selector_value::AbstractString,
    structure::CrystalStructure,
    tolerance::Float64,
)
    selector = String(selector_value)
    if occursin('=', selector)
        prefix, value = split(selector, '='; limit = 2)
        normalized = lowercase(strip(prefix))
        vector = _parse_projection_vector(value, "projection center")
        if normalized in ("f", "frac", "fractional")
            return reshape(mod.(vector, 1.0), 3, 1)
        elseif normalized in ("c", "cart", "cartesian")
            return reshape(mod.(transpose(vector) * inv(structure.lattice), 1.0), 3, 1)
        end
        throw(ArgumentError("unknown projection center prefix $(prefix)"))
    end
    matches = findall(==(selector), structure.species)
    isempty(matches) &&
        throw(ArgumentError("projection selector $(selector) matches no structure atom"))
    positions = structure.positions_fractional[:, matches]
    if size(positions, 2) > 1
        for left in 1:(size(positions, 2) - 1), right in (left + 1):size(positions, 2)
            residual = positions[:, left] .- positions[:, right]
            residual .-= round.(residual)
            maximum(abs, residual) > tolerance || throw(
                ArgumentError(
                    "projection selector $(selector) contains duplicate periodic centers",
                ),
            )
        end
    end
    return Matrix{Float64}(positions)
end

# Parse one projection line into selector, orbital sets, and local axes.
function parse_projection_line(line::String)
    parts = strip.(split(line, ':'))
    length(parts) >= 2 || throw(ArgumentError("invalid projection line $(repr(line))"))
    selector = parts[1]
    orbital_sets = [
        get(
            Dict("l=0" => "s", "l=1" => "p", "l=2" => "d", "l=3" => "f"),
            lowercase(strip(value)),
            lowercase(strip(value)),
        ) for value in split(parts[2], ';') if !isempty(strip(value))
    ]
    for start_index in 1:max(length(orbital_sets) - 2, 0)
        orbital_sets[start_index:(start_index + 2)] == ["dxy", "dxz", "dyz"] || continue
        orbital_sets = vcat(
            orbital_sets[1:(start_index - 1)],
            ["t2g_dxy_first"],
            orbital_sets[(start_index + 3):end],
        )
        break
    end
    isempty(orbital_sets) && throw(ArgumentError("projection line has no orbital set"))
    x_axis = nothing
    z_axis = nothing
    for option in parts[3:end]
        key, value = split(option, '='; limit = 2)
        normalized = lowercase(strip(key))
        if normalized in ("x", "xaxis", "x_axis")
            x_axis = _parse_projection_vector(value, "projection x axis")
        elseif normalized in ("z", "zaxis", "z_axis")
            z_axis = _parse_projection_vector(value, "projection z axis")
        else
            throw(ArgumentError("unsupported projection option $(key)"))
        end
    end
    return selector, orbital_sets, _build_local_projection_basis(x_axis, z_axis)
end

# Expand the public ProjectionSpec model through the one canonical numbering path.
function build_wannier_projection_basis(
    specs::AbstractVector{ProjectionSpec};
    structure::Union{Nothing, CrystalStructure} = nothing,
    spinor::Bool = false,
    num_wannier::Union{Nothing, Integer} = nothing,
    tolerance::Real = 1.0e-8,
    radial_transform::ProjectionRadialTransformConfig = ProjectionRadialTransformConfig(),
)
    isempty(specs) && throw(ArgumentError("at least one ProjectionSpec is required"))
    tolerance_value = Float64(tolerance)
    isfinite(tolerance_value) && tolerance_value > 0.0 ||
        throw(ArgumentError("tolerance must be positive and finite"))
    spin_dimension = spinor ? 2 : 1
    blocks = WannierProjectionBlock[]
    next_index = 1
    for (spec_index, spec) in enumerate(specs)
        centers = if spec.positions_fractional === nothing
            structure === nothing && throw(
                ArgumentError(
                    "ProjectionSpec $(spec_index) omits positions, so structure is required",
                ),
            )
            _projection_centers(spec.selector, something(structure), tolerance_value)
        else
            copy(something(spec.positions_fractional))
        end
        center_count = size(centers, 2)
        local_dimensions = Int[]
        for orbital_set in spec.orbital_sets
            haskey(ORBITAL_LABELS, orbital_set) ||
                throw(ArgumentError("unsupported projection orbital set $(orbital_set)"))
            push!(local_dimensions, length(ORBITAL_LABELS[orbital_set]) * spin_dimension)
        end
        center_dimension = sum(local_dimensions)
        canonical_indices = Matrix{Int}(undef, center_dimension, center_count)
        for center in 1:center_count
            first_index = next_index + (center - 1) * center_dimension
            canonical_indices[:, center] .= first_index:(first_index + center_dimension - 1)
        end
        indices = if spec.indices === nothing
            canonical_indices
        else
            values = something(spec.indices)
            size(values) == size(canonical_indices) || throw(
                ArgumentError(
                    "ProjectionSpec $(spec_index) indices have size $(size(values)); " *
                    "expected $(size(canonical_indices))",
                ),
            )
            copy(values)
        end
        local_bases = if ndims(spec.local_bases) == 2
            repeat(reshape(spec.local_bases, 3, 3, 1), 1, 1, center_count)
        else
            size(spec.local_bases, 3) == center_count || throw(
                ArgumentError(
                    "ProjectionSpec $(spec_index) local_bases center count disagrees with positions",
                ),
            )
            Array{Float64, 3}(spec.local_bases)
        end
        row_start = 1
        for (orbital_set, local_dimension) in zip(spec.orbital_sets, local_dimensions)
            rows = row_start:(row_start + local_dimension - 1)
            push!(
                blocks,
                WannierProjectionBlock(
                    spec.selector,
                    orbital_set,
                    centers,
                    indices[rows, :],
                    local_bases,
                    spinor,
                ),
            )
            row_start += local_dimension
        end
        next_index += center_dimension * center_count
    end
    inferred_dimension = next_index - 1
    dimension = num_wannier === nothing ? inferred_dimension : Int(num_wannier)
    dimension == inferred_dimension || throw(
        ArgumentError(
            "expanded projection dimension $(inferred_dimension) disagrees with num_wannier=$(dimension)",
        ),
    )
    return WannierProjectionBasis(blocks, dimension, spinor, radial_transform)
end

"""
Build the ordered Wannier projection basis declared by a WIN input.

Wannier90 projection ordering is preserved exactly. SOC uses interlaced spin
ordering. Supported scalar sets are `s/p/d/f` plus `sp`, `p2`, `pxy`, `sp2`,
`pz`, individual `dxy`/`dxz`/`dyz`, `sp3`, `sp3d2`, `t2g`, the Wannier90
`dxy;dxz;dyz`-ordered t2g subspace, and `eg`; every block must reproduce
`num_wann`.
"""
function build_wannier_projection_basis(
    input::WannierWinData;
    tolerance::Real = 1.0e-8,
    radial_transform::ProjectionRadialTransformConfig = ProjectionRadialTransformConfig(),
)
    specs = ProjectionSpec[]
    for line in input.projection_lines
        selector, orbital_sets, local_basis = parse_projection_line(line)
        push!(specs, ProjectionSpec(; selector, orbital_sets, local_bases = local_basis))
    end
    return build_wannier_projection_basis(
        specs;
        structure = crystal_structure(input),
        spinor = input.spinors,
        num_wannier = input.num_wannier,
        tolerance,
        radial_transform,
    )
end

"""Build the ordered projection basis directly from one read-only WIN path."""
function build_wannier_projection_basis(
    filename::AbstractString;
    tolerance::Real = 1.0e-8,
    radial_transform::ProjectionRadialTransformConfig = ProjectionRadialTransformConfig(),
)
    return build_wannier_projection_basis(read_wannier_win(filename); tolerance, radial_transform)
end

# Map one closed center set and return target indices plus integer lattice shifts.
function _map_projection_centers(
    projection_centers_fractional::Matrix{Float64},
    operations::Vector{SymmetryOperation},
    tolerance::Float64;
    construction_policy::Symbol = :strict,
    mapping_diagnostics = nothing,
)
    construction_policy in (:diagnostic, :strict) ||
        throw(ArgumentError("construction_policy must be :diagnostic or :strict"))
    all(isfinite, projection_centers_fractional) ||
        throw(ArgumentError("projection centers contain nonfinite values"))
    projection_center_count = size(projection_centers_fractional, 2)
    target_center_indices = zeros(Int, projection_center_count, length(operations))
    target_center_lattice_shifts = zeros(Int, 3, projection_center_count, length(operations))
    for (operation_index, operation) in enumerate(operations)
        for source_center_index in 1:projection_center_count
            transformed_position_fractional =
                operation.rotation_fractional *
                projection_centers_fractional[:, source_center_index] .+
                operation.translation_fractional
            matching_target_center_indices = Int[]
            matching_lattice_shifts = Vector{Int}[]
            distances = Float64[]
            candidate_shifts = Vector{Int}[]
            for target_center_candidate_index in 1:projection_center_count
                displacement_fractional =
                    transformed_position_fractional .-
                    projection_centers_fractional[:, target_center_candidate_index]
                lattice_shift = round.(Int, displacement_fractional)
                distance = maximum(abs, displacement_fractional .- lattice_shift)
                push!(distances, distance)
                push!(candidate_shifts, lattice_shift)
                distance <= tolerance || continue
                push!(matching_target_center_indices, target_center_candidate_index)
                push!(matching_lattice_shifts, lattice_shift)
            end
            if construction_policy == :diagnostic
                order = sortperm(distances)
                isempty(order) && throw(ArgumentError("projection center set is empty"))
                nearest = first(order)
                nearest_displacement =
                    transformed_position_fractional - projection_centers_fractional[:, nearest]
                nearest_residual = nearest_displacement - candidate_shifts[nearest]
                any(component -> abs(abs(component) - 0.5) <= 64eps(Float64), nearest_residual) &&
                    throw(
                        ArgumentError(
                            "projection center nearest lattice shift is ambiguous under operation $(operation_index)",
                        ),
                    )
                distance = distances[nearest]
                margin = length(order) == 1 ? Inf : distances[order[2]] - distance
                margin > 64eps(Float64) * max(1.0, distance) || throw(
                    ArgumentError(
                        "projection center nearest match is ambiguous under operation $(operation_index)",
                    ),
                )
                matching_target_center_indices = [nearest]
                matching_lattice_shifts = [candidate_shifts[nearest]]
                mapping_diagnostics === nothing || push!(
                    mapping_diagnostics,
                    (
                        stage = "projection_center_mapping",
                        code = "PROJECTION_CENTER_RESIDUAL",
                        operation = operation_index,
                        center = source_center_index,
                        value = distance,
                        threshold = tolerance,
                        margin = isfinite(margin) ? margin : nothing,
                        result = distance <= tolerance ? "PASS" : "FAIL",
                        action = distance <= tolerance ? "CONTINUE" : "CONTINUE_DIAGNOSTIC",
                    ),
                )
            end
            length(matching_target_center_indices) == 1 || throw(
                ArgumentError(
                    "projection centers do not map uniquely under operation $(operation_index)",
                ),
            )
            target_center_indices[source_center_index, operation_index] =
                only(matching_target_center_indices)
            target_center_lattice_shifts[:, source_center_index, operation_index] .=
                only(matching_lattice_shifts)
        end
        sort(target_center_indices[:, operation_index]) == collect(1:projection_center_count) ||
            throw(ArgumentError("center mapping is not a permutation"))
    end
    if construction_policy == :diagnostic
        _validate_projection_center_group_mapping(
            operations,
            target_center_indices,
            target_center_lattice_shifts,
            tolerance,
        )
    end
    return target_center_indices, target_center_lattice_shifts
end

# A nearest match is usable only when it defines the discrete space-group action.
# For g*h = lattice_translation * product, the center shifts obey the same cocycle.
function _validate_projection_center_group_mapping(operations, indices, shifts, tolerance)
    for (g, left) in enumerate(operations), (h, right) in enumerate(operations)
        rotation = left.rotation_fractional * right.rotation_fractional
        translation =
            left.rotation_fractional * right.translation_fractional + left.translation_fractional
        antiunitary = xor(left.antiunitary, right.antiunitary)
        products = Int[]
        lattice_translations = Vector{Int}[]
        for (p, product) in enumerate(operations)
            product.rotation_fractional == rotation || continue
            product.antiunitary == antiunitary || continue
            displacement = translation - product.translation_fractional
            lattice_translation = round.(Int, displacement)
            maximum(abs, displacement - lattice_translation) <= tolerance || continue
            push!(products, p)
            push!(lattice_translations, lattice_translation)
        end
        length(products) == 1 ||
            throw(ArgumentError("projection operations do not form a unique closed group"))
        product = only(products)
        lattice_translation = only(lattice_translations)
        for center in axes(indices, 1)
            intermediate = indices[center, h]
            indices[intermediate, g] == indices[center, product] ||
                throw(ArgumentError("projection center permutation group law failed"))
            composed_shift =
                left.rotation_fractional * shifts[:, center, h] + shifts[:, intermediate, g]
            composed_shift == shifts[:, center, product] + lattice_translation ||
                throw(ArgumentError("projection center lattice-shift cocycle failed"))
        end
    end
    return nothing
end

"""
Build the global Wannier representation and per-Wannier lattice shifts.

Rows of each representation matrix are target states and columns are source
states. For antiunitary operations the stored matrix is the unitary part and
complex conjugation is applied later by the real-space projector. The function
fails if a center set or orbital subspace is not symmetry closed.
"""
function build_wannier_symmetry_plan(
    basis::WannierProjectionBasis,
    operations::Vector{SymmetryOperation};
    operation_indices = nothing,
    tolerance::Real = 1.0e-8,
    construction_policy::Symbol = :strict,
    mapping_diagnostics = nothing,
)
    tolerance_value = Float64(tolerance)
    available_operation_count = length(operations)
    representation_matrices =
        zeros(ComplexF64, basis.num_wannier, basis.num_wannier, available_operation_count)
    wannier_lattice_shifts = zeros(Int, 3, basis.num_wannier, available_operation_count)
    for block in basis.blocks
        target_center_indices, target_center_lattice_shifts = _map_projection_centers(
            block.positions_fractional,
            operations,
            tolerance_value;
            construction_policy,
            mapping_diagnostics,
        )
        for (operation_index, operation) in enumerate(operations),
            source_center_index in axes(block.positions_fractional, 2)

            target_center_index = target_center_indices[source_center_index, operation_index]
            orbital_matrix = _orbital_rotation(
                block.orbital_set,
                operation.rotation_cartesian,
                @view(block.local_bases[:, :, source_center_index]),
                @view(block.local_bases[:, :, target_center_index]);
                construction_policy,
                mapping_diagnostics,
                operation_index,
            )
            local_matrix =
                block.spinor ? kron(orbital_matrix, spin_action_matrix(operation, true)) :
                ComplexF64.(orbital_matrix)
            source_wannier_indices = block.indices[:, source_center_index]
            target_wannier_indices = block.indices[:, target_center_index]
            representation_matrices[
                target_wannier_indices,
                source_wannier_indices,
                operation_index,
            ] .= local_matrix
            wannier_lattice_shifts[:, source_wannier_indices, operation_index] .=
                target_center_lattice_shifts[:, source_center_index, operation_index]
        end
    end
    return WannierSymmetryPlan(
        operations,
        representation_matrices,
        wannier_lattice_shifts;
        operation_indices = operation_indices,
        tolerance = tolerance_value,
        construction_policy,
        diagnostics = mapping_diagnostics,
    )
end
