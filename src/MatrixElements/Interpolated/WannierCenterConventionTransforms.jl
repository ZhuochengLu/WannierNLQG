"""Locate and validate the home-cell block that owns the TB Wannier centers."""
function _home_cell_r_index(model::TightBindingModel)
    found = 0
    @inbounds for r_index in 1:model.num_r_vectors
        all(iszero, @view(model.r_vectors[:, r_index])) || continue
        iszero(found) || error("TB model contains more than one R=(0,0,0) block.")
        found = r_index
    end
    iszero(found) && error("Convention_I requires one R=(0,0,0) position block in the TB model.")
    return found
end

"""Cache ordered TB centers and their fractional coordinates before hot execution."""
function _initialize_wannier_center_scratch!(
    scratch::MatrixElementScratch,
    model::TightBindingModel,
    plan::MatrixElementPlan,
)
    scratch.centers_initialized && return scratch
    if plan.wannier_center_convention == CONVENTION_II
        fill!(scratch.wannier_centers_cartesian, 0.0)
        fill!(scratch.wannier_centers_fractional, 0.0)
        fill!(scratch.center_phase_factors, 1.0 + 0.0im)
        scratch.center_home_r_index = 0
        scratch.centers_initialized = true
        return scratch
    end

    home = _home_cell_r_index(model)
    @inbounds for orbital in 1:model.num_orbitals, direction in 1:3
        value = model.position_r[orbital, orbital, direction, home]
        isfinite(real(value)) && isfinite(imag(value)) || error(
            "Convention_I Wannier center is non-finite at orbital=$(orbital), direction=$(direction).",
        )
        abs(imag(value)) <= 1.0e-10 || error(
            "Convention_I Wannier center has imaginary part $(imag(value)) at " *
            "orbital=$(orbital), direction=$(direction).",
        )
        scratch.wannier_centers_cartesian[direction, orbital] = real(value)
    end
    @inbounds for orbital in 1:model.num_orbitals
        scratch.wannier_centers_fractional[:, orbital] .= real_space_cartesian_to_fractional(
            @view(scratch.wannier_centers_cartesian[:, orbital]),
            model.lattice,
        )
    end
    all(isfinite, scratch.wannier_centers_fractional) ||
        error("Convention_I fractional Wannier centers contain non-finite values.")
    scratch.center_home_r_index = home
    scratch.centers_initialized = true
    return scratch
end

"""Prepare the diagonal phase D_tau(k) for the active k point."""
function _prepare_wannier_center_phases!(
    scratch::MatrixElementScratch,
    model::TightBindingModel,
    plan::MatrixElementPlan,
    kpoint::AbstractVector{<:Real},
)
    _initialize_wannier_center_scratch!(scratch, model, plan)
    plan.wannier_center_convention == CONVENTION_II && return scratch.center_phase_factors
    @inbounds for orbital in 1:model.num_orbitals
        scratch.center_phase_factors[orbital] =
            cis(2.0 * pi * dot(kpoint, @view(scratch.wannier_centers_fractional[:, orbital])))
    end
    return scratch.center_phase_factors
end

"""Apply D_tau(k)' * X(k) * D_tau(k) to one Wannier-gauge matrix in place."""
function _apply_wannier_center_similarity!(
    matrix::AbstractMatrix{ComplexF64},
    scratch::MatrixElementScratch,
    plan::MatrixElementPlan,
)
    plan.wannier_center_convention == CONVENTION_II && return matrix
    phases = scratch.center_phase_factors
    @inbounds for column in axes(matrix, 2), row in axes(matrix, 1)
        matrix[row, column] *= conj(phases[row]) * phases[column]
    end
    return matrix
end

"""Return one Cartesian component of R + tau_right - tau_left."""
@inline function _convention_displacement_component(
    r_cartesian,
    direction::Int,
    orbital_row::Int,
    orbital_column::Int,
    scratch::MatrixElementScratch,
    plan::MatrixElementPlan,
)
    plan.wannier_center_convention == CONVENTION_II && return r_cartesian[direction]
    return r_cartesian[direction] + scratch.wannier_centers_cartesian[direction, orbital_column] -
           scratch.wannier_centers_cartesian[direction, orbital_row]
end

"""Convert one Convention-II position coefficient to its centered connection coefficient."""
@inline function _convention_position_value(
    value::ComplexF64,
    position_direction::Int,
    orbital_row::Int,
    orbital_column::Int,
    r_vector_index::Int,
    scratch::MatrixElementScratch,
    plan::MatrixElementPlan,
)
    plan.wannier_center_convention == CONVENTION_II && return value
    if r_vector_index == scratch.center_home_r_index && orbital_row == orbital_column
        return value - scratch.wannier_centers_cartesian[position_direction, orbital_row]
    end
    return value
end

"""Apply the affine O*r -> O*(r-T) rule to a position-inserted operator."""
function _apply_right_position_affine!(
    position_operator::AbstractMatrix{ComplexF64},
    source_operator::AbstractMatrix{ComplexF64},
    position_direction::Int,
    scratch::MatrixElementScratch,
    plan::MatrixElementPlan,
)
    plan.wannier_center_convention == CONVENTION_II && return position_operator
    @inbounds for column in axes(position_operator, 2), row in axes(position_operator, 1)
        position_operator[row, column] -=
            source_operator[row, column] *
            scratch.wannier_centers_cartesian[position_direction, column]
    end
    return position_operator
end
