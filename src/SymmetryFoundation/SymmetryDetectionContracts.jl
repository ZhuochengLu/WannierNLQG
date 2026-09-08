const DEFAULT_SPGLIB_SYMPREC_ANGSTROM = 1.0e-5
const DEFAULT_MAXIMUM_CARTESIAN_ROTATION_CORRECTION = 1.0e-6
const EFFECTIVE_CARTESIAN_ROTATION_TOLERANCE = 1.0e-12
const RAW_CARTESIAN_ORTHOGONALITY_WARNING_TOLERANCE = 1.0e-8

# Resolve the explicit Angstrom backend tolerance and its legacy same-unit alias.
function resolve_spglib_symprec_angstrom(;
    spglib_symprec_angstrom::Union{Nothing, Real} = nothing,
    symmetry_tolerance::Union{Nothing, Real} = nothing,
)
    explicit = spglib_symprec_angstrom === nothing ? nothing : Float64(spglib_symprec_angstrom)
    legacy = symmetry_tolerance === nothing ? nothing : Float64(symmetry_tolerance)
    for (name, value) in (("spglib_symprec_angstrom", explicit), ("symmetry_tolerance", legacy))
        value === nothing && continue
        isfinite(value) && value > 0.0 ||
            throw(ArgumentError("$(name) must be positive and finite"))
    end
    if explicit !== nothing && legacy !== nothing && explicit != legacy
        throw(
            ArgumentError(
                "spglib_symprec_angstrom=$(explicit) and legacy symmetry_tolerance=$(legacy) " *
                "are both Angstrom values and must agree when both are supplied",
            ),
        )
    end
    return something(explicit, legacy, DEFAULT_SPGLIB_SYMPREC_ANGSTROM)
end

# Convert a fractional-coordinate rotation using the literal input lattice metric.
function _raw_fractional_to_cartesian_rotation(
    rotation_fractional::AbstractMatrix{<:Integer},
    lattice::Matrix{Float64},
)
    lattice_columns = Matrix{Float64}(transpose(lattice))
    return Matrix{Float64}(lattice_columns * rotation_fractional * inv(lattice_columns))
end

# Preserve the historical raw conversion helper for internal compatibility.
function _fractional_to_cartesian_rotation(
    rotation_fractional::AbstractMatrix{<:Integer},
    lattice::Matrix{Float64};
    orthogonality_policy::Symbol = :error,
)
    orthogonality_policy in (:error, :warn) ||
        throw(ArgumentError("orthogonality_policy must be :error or :warn"))
    rotation = _raw_fractional_to_cartesian_rotation(rotation_fractional, lattice)
    residual = maximum(abs, rotation' * rotation - Matrix{Float64}(I, 3, 3))
    if residual > RAW_CARTESIAN_ORTHOGONALITY_WARNING_TOLERANCE
        message =
            "Spglib fractional rotation Cartesian orthogonality residual $(residual) " *
            "exceeds warning threshold $(RAW_CARTESIAN_ORTHOGONALITY_WARNING_TOLERANCE)"
        orthogonality_policy == :error ? throw(ArgumentError(message)) : @warn message
    end
    return rotation
end

# Return the positive symmetric square root of a lattice metric.
function _positive_metric_square_root(metric::AbstractMatrix{<:Real}, context::AbstractString)
    decomposition = eigen(Symmetric(Matrix{Float64}(metric)))
    minimum(decomposition.values) > 0.0 ||
        throw(ArgumentError("$(context) is not positive definite"))
    return decomposition.vectors * Diagonal(sqrt.(decomposition.values)) * decomposition.vectors'
end

# Generate one group-consistent Cartesian representation from invariant metric averaging.
function group_invariant_cartesian_rotation_data(rotations, lattice::Matrix{Float64})
    unique_rotations = Matrix{Int}[]
    seen = Set{Tuple}()
    for rotation in rotations
        value = Matrix{Int}(rotation)
        key = Tuple(vec(value))
        key in seen && continue
        push!(seen, key)
        push!(unique_rotations, value)
    end
    isempty(unique_rotations) && throw(ArgumentError("rotation inventory must not be empty"))

    lattice_columns = Matrix{Float64}(transpose(lattice))
    metric = lattice_columns' * lattice_columns
    symmetrized_metric = zeros(Float64, 3, 3)
    for rotation in unique_rotations
        symmetrized_metric .+= rotation' * metric * rotation
    end
    symmetrized_metric ./= length(unique_rotations)
    symmetrized_metric .= (symmetrized_metric .+ symmetrized_metric') ./ 2

    metric_root = _positive_metric_square_root(metric, "input lattice metric")
    symmetrized_metric_root =
        _positive_metric_square_root(symmetrized_metric, "group-invariant lattice metric")
    cartesian_orientation = lattice_columns * inv(metric_root)
    effective_lattice_columns = cartesian_orientation * symmetrized_metric_root
    inverse_effective_lattice = inv(effective_lattice_columns)

    raw_rotations = Dict{Tuple, Matrix{Float64}}()
    effective_rotations = Dict{Tuple, Matrix{Float64}}()
    maximum_correction = 0.0
    maximum_raw_orthogonality = 0.0
    maximum_effective_orthogonality = 0.0
    identity = Matrix{Float64}(I, 3, 3)
    for rotation in unique_rotations
        key = Tuple(vec(rotation))
        raw = _raw_fractional_to_cartesian_rotation(rotation, lattice)
        effective =
            Matrix{Float64}(effective_lattice_columns * rotation * inverse_effective_lattice)
        raw_rotations[key] = raw
        effective_rotations[key] = effective
        maximum_correction = max(maximum_correction, maximum(abs, effective - raw))
        maximum_raw_orthogonality =
            max(maximum_raw_orthogonality, maximum(abs, raw' * raw - identity))
        maximum_effective_orthogonality =
            max(maximum_effective_orthogonality, maximum(abs, effective' * effective - identity))
    end

    maximum_effective_closure = 0.0
    worst_effective_closure_pair = (0, 0)
    key_to_index =
        Dict(Tuple(vec(rotation)) => index for (index, rotation) in enumerate(unique_rotations))
    for (left_index, left) in enumerate(unique_rotations),
        (right_index, right) in enumerate(unique_rotations)

        product_key = Tuple(vec(left * right))
        haskey(key_to_index, product_key) || throw(
            ArgumentError(
                "fractional rotation set is not closed at $(left_index) * $(right_index)",
            ),
        )
        residual = maximum(
            abs,
            effective_rotations[Tuple(vec(left))] * effective_rotations[Tuple(vec(right))] -
            effective_rotations[product_key],
        )
        if residual > maximum_effective_closure
            maximum_effective_closure = residual
            worst_effective_closure_pair = (left_index, right_index)
        end
    end

    relative_metric_change = norm(symmetrized_metric - metric) / max(norm(metric), eps(Float64))
    return (
        unique_rotations,
        raw_rotations,
        effective_rotations,
        metric,
        symmetrized_metric,
        effective_lattice_rows = Matrix{Float64}(transpose(effective_lattice_columns)),
        relative_metric_change,
        maximum_correction,
        maximum_raw_orthogonality,
        maximum_effective_orthogonality,
        maximum_effective_closure,
        worst_effective_closure_pair,
    )
end

# Resolve the new Cartesian convention and the old orthogonality-policy keyword.
function resolve_cartesian_rotation_policy(
    cartesian_rotation_policy::Union{Nothing, Symbol},
    cartesian_orthogonality_policy::Union{Nothing, Symbol},
)
    legacy = if cartesian_orthogonality_policy === nothing
        nothing
    elseif cartesian_orthogonality_policy == :warn
        :raw_warn
    elseif cartesian_orthogonality_policy == :error
        :raw_error
    else
        throw(ArgumentError("cartesian_orthogonality_policy must be :error or :warn"))
    end
    if cartesian_rotation_policy !== nothing &&
       legacy !== nothing &&
       cartesian_rotation_policy != legacy
        throw(
            ArgumentError(
                "cartesian_rotation_policy and legacy cartesian_orthogonality_policy disagree",
            ),
        )
    end
    policy = something(cartesian_rotation_policy, legacy, :group_invariant_metric)
    policy in (:group_invariant_metric, :raw_warn, :raw_error) || throw(
        ArgumentError(
            "cartesian_rotation_policy must be :group_invariant_metric, :raw_warn, or :raw_error",
        ),
    )
    return policy
end
