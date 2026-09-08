"""
Convert a Cartesian real-space vector to fractional row-lattice coordinates.

For row-stored lattice vectors, a fractional column `f` maps to Cartesian
coordinates as `transpose(lattice) * f`.
"""
function real_space_cartesian_to_fractional(
    cartesian::AbstractVector{<:Real},
    lattice::AbstractMatrix{<:Real},
)
    return vec(transpose(lattice) \ cartesian)
end

"""Convert a Cartesian reciprocal-space vector to fractional coordinates."""
function reciprocal_cartesian_to_fractional(
    cartesian::AbstractVector{<:Real},
    lattice::AbstractMatrix{<:Real},
)
    return vec(lattice * cartesian) ./ (2.0 * pi)
end

"""Return row-stored reciprocal lattice vectors `2π A⁻ᵀ` in inverse Angstrom."""
function reciprocal_lattice(lattice::AbstractMatrix{<:Real})
    size(lattice) == (3, 3) ||
        throw(ArgumentError("lattice must have size (3, 3), got $(size(lattice))"))
    values = Matrix{Float64}(lattice)
    all(isfinite, values) || throw(ArgumentError("lattice contains non-finite values"))
    abs(det(values)) > eps(Float64) || throw(ArgumentError("lattice is singular"))
    return 2.0 * pi * transpose(inv(values))
end

"""Build Cartesian-axis finite-difference steps in fractional k coordinates."""
function finite_difference_step_matrix(model::TightBindingModel, finite_difference_step::Float64)
    cartesian_steps = finite_difference_step * Matrix{Float64}(I, 3, 3)
    fractional_steps = zeros(Float64, 3, 3)
    for direction in 1:3
        fractional_steps[:, direction] =
            reciprocal_cartesian_to_fractional(cartesian_steps[:, direction], model.lattice)
    end
    return fractional_steps
end
