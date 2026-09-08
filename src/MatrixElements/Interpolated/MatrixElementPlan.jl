@enum MatrixElementKind::UInt8 begin
    SPECTRUM
    ENERGY_DIFFERENCES
    HAMILTONIAN_DERIVATIVES
    HAMILTONIAN_SECOND_DERIVATIVES
    WANNIER_POSITION
    INTERNAL_CONNECTION
    INTERNAL_CONNECTION_DERIVATIVES
    GAUGE_CORRECTION
    BERRY_CONNECTION
    WANNIER_CURVATURE
    VELOCITY_VERTICES
    SPIN
    SPIN_TIMES_HAMILTONIAN
    SPIN_TIMES_POSITION
    SPIN_TIMES_HAMILTONIAN_POSITION
    SPIN_VELOCITY
end

const _ALL_MATRIX_ELEMENT_KINDS = ntuple(index -> MatrixElementKind(index - 1), 16)

# Encode a zero-based capability enum value as one bit of a UInt64 mask.
@inline _capability_bit(kind::MatrixElementKind) = UInt64(1) << Int(kind)
# Test whether the capability enum's bit is present in the supplied UInt64 mask.
@inline _has_capability(mask::UInt64, kind::MatrixElementKind) =
    !iszero(mask & _capability_bit(kind))

"""
Requested capability bitmask, spatial dimension, and energy-denominator/degeneracy tolerances in eV.

The keyword constructor rejects an empty capability list, dimensions outside `1:3`, and negative tolerances; dependency closure is deferred to `compile_matrix_plan`.
"""
struct MatrixElementRequest
    requested_mask::UInt64
    spatial_dimension::Int
    denominator_regularization::Float64
    degeneracy_threshold::Float64
end

"""
Per-capability Cartesian direction bitmasks for one spatial dimension.

The dimension constructor starts all sixteen masks empty and rejects dimensions outside `1:3`; spin axes retain three components.
"""
struct MatrixElementDirectionRequirements
    spatial_dimension::Int
    masks::NTuple{16, UInt16}
end

# Per-capability Cartesian direction bitmasks for one spatial dimension.
#
# The dimension constructor starts all sixteen masks empty and rejects dimensions outside `1:3`; spin axes retain three components.
function MatrixElementDirectionRequirements(spatial_dimension::Integer)
    dimension = Int(spatial_dimension)
    dimension in 1:3 || throw(ArgumentError("spatial_dimension must be in 1:3, got $(dimension)."))
    return MatrixElementDirectionRequirements(dimension, ntuple(_ -> UInt16(0), 16))
end

# Map a zero-based capability enum to its one-based direction-mask tuple slot.
@inline _direction_index(kind::MatrixElementKind) = Int(kind) + 1
# Read the direction bitmask belonging to one capability without modifying the immutable requirements.
@inline _direction_mask(requirements::MatrixElementDirectionRequirements, kind::MatrixElementKind) =
    requirements.masks[_direction_index(kind)]

# Return new requirements with exactly one capability mask replaced, retaining the other fifteen masks.
@inline function _replace_direction_mask(
    requirements::MatrixElementDirectionRequirements,
    kind::MatrixElementKind,
    mask::UInt16,
)
    index = _direction_index(kind)
    return MatrixElementDirectionRequirements(
        requirements.spatial_dimension,
        ntuple(i -> i == index ? mask : requirements.masks[i], 16),
    )
end

# Add one validated Cartesian axis to a capability mask; spin-only axes permit all three components.
@inline function _require_axis(
    requirements::MatrixElementDirectionRequirements,
    kind::MatrixElementKind,
    axis::Integer,
)
    direction = Int(axis)
    limit = kind in (SPIN, SPIN_TIMES_HAMILTONIAN) ? 3 : requirements.spatial_dimension
    direction in 1:limit || throw(ArgumentError("Invalid direction $(direction) for $(kind)."))
    mask = _direction_mask(requirements, kind) | (UInt16(1) << (direction - 1))
    return _replace_direction_mask(requirements, kind, mask)
end

# Add a validated ordered axis pair to its bitmask, using three spin components for spin-velocity families.
@inline function _require_pair(
    requirements::MatrixElementDirectionRequirements,
    kind::MatrixElementKind,
    first_direction::Integer,
    second_direction::Integer,
)
    first = Int(first_direction)
    second = Int(second_direction)
    first in 1:requirements.spatial_dimension ||
        throw(ArgumentError("Invalid first direction $(first) for $(kind)."))
    second_limit =
        kind in (SPIN_TIMES_POSITION, SPIN_TIMES_HAMILTONIAN_POSITION, SPIN_VELOCITY) ? 3 :
        requirements.spatial_dimension
    second in 1:second_limit ||
        throw(ArgumentError("Invalid second direction $(second) for $(kind)."))
    channel = (first - 1) * second_limit + second
    mask = _direction_mask(requirements, kind) | (UInt16(1) << (channel - 1))
    return _replace_direction_mask(requirements, kind, mask)
end

# Fold individual axis requirements into a new immutable mask set, preserving existing requirements.
function _require_axes(
    requirements::MatrixElementDirectionRequirements,
    kind::MatrixElementKind,
    axes,
)
    result = requirements
    for axis in axes
        result = _require_axis(result, kind, axis)
    end
    return result
end

# Fold ordered axis-pair requirements into a new immutable mask set, validating each pair.
function _require_pairs(
    requirements::MatrixElementDirectionRequirements,
    kind::MatrixElementKind,
    pairs,
)
    result = requirements
    for (first_direction, second_direction) in pairs
        result = _require_pair(result, kind, first_direction, second_direction)
    end
    return result
end

# Test the bit for one Cartesian axis in the plan's capability-specific direction requirements.
@inline function _axis_required(plan, kind::MatrixElementKind, axis::Integer)
    return !iszero(
        _direction_mask(plan.direction_requirements, kind) & (UInt16(1) << (Int(axis) - 1)),
    )
end

# Return the compact one-based storage channel for an active axis, or zero when the axis is unrequested.
@inline function _axis_channel(plan, kind::MatrixElementKind, axis::Integer)
    _axis_required(plan, kind, axis) || return 0
    mask = _direction_mask(plan.direction_requirements, kind)
    preceding = Int(axis) == 1 ? UInt16(0) : (UInt16(1) << (Int(axis) - 1)) - UInt16(1)
    return count_ones(mask & preceding) + 1
end

# Count active axis bits for one capability, giving its compact storage width.
@inline _axis_channel_count(plan, kind::MatrixElementKind) =
    count_ones(_direction_mask(plan.direction_requirements, kind))

# Invert the compact axis mapping; throw BoundsError when no active axis has the requested channel.
function _axis_for_channel(plan, kind::MatrixElementKind, channel::Integer)
    target = Int(channel)
    found = 0
    limit = kind in (SPIN, SPIN_TIMES_HAMILTONIAN) ? 3 : plan.spatial_dimension
    for axis in 1:limit
        _axis_required(plan, kind, axis) || continue
        found += 1
        found == target && return axis
    end
    throw(BoundsError("No logical axis for $(kind) channel $(target)."))
end

# Return the three Cartesian-to-storage channel indices, with zero for inactive or out-of-dimension axes.
@inline _axis_channel_map(plan, kind::MatrixElementKind) =
    ntuple(axis -> axis <= plan.spatial_dimension ? _axis_channel(plan, kind, axis) : 0, Val(3))

# Test whether every spatial axis maps to its identical one-based storage channel.
@inline function _axis_map_is_dense(channel_map, spatial_dimension::Int)
    channel_map[1] == 1 || return false
    spatial_dimension == 1 && return true
    channel_map[2] == 2 || return false
    spatial_dimension == 2 && return true
    return channel_map[3] == 3
end

# Test an ordered axis-pair bit, using the capability's spatial/spin second-axis extent.
@inline function _pair_required(
    plan,
    kind::MatrixElementKind,
    first_direction::Integer,
    second_direction::Integer,
)
    second_limit =
        kind in (SPIN_TIMES_POSITION, SPIN_TIMES_HAMILTONIAN_POSITION, SPIN_VELOCITY) ? 3 :
        plan.spatial_dimension
    channel = (Int(first_direction) - 1) * second_limit + Int(second_direction)
    return !iszero(
        _direction_mask(plan.direction_requirements, kind) & (UInt16(1) << (channel - 1)),
    )
end

# Return the compact ordered-pair channel, or zero if that Cartesian pair is not required.
@inline function _pair_channel(
    plan,
    kind::MatrixElementKind,
    first_direction::Integer,
    second_direction::Integer,
)
    _pair_required(plan, kind, first_direction, second_direction) || return 0
    second_limit =
        kind in (SPIN_TIMES_POSITION, SPIN_TIMES_HAMILTONIAN_POSITION, SPIN_VELOCITY) ? 3 :
        plan.spatial_dimension
    logical_channel = (Int(first_direction) - 1) * second_limit + Int(second_direction)
    mask = _direction_mask(plan.direction_requirements, kind)
    preceding = logical_channel == 1 ? UInt16(0) : (UInt16(1) << (logical_channel - 1)) - UInt16(1)
    return count_ones(mask & preceding) + 1
end

# Count active ordered-pair bits for the capability's compact storage width.
@inline _pair_channel_count(plan, kind::MatrixElementKind) =
    count_ones(_direction_mask(plan.direction_requirements, kind))

# Invert an ordered-pair channel in first-axis-major order; throw BoundsError if the channel is absent.
function _pair_for_channel(plan, kind::MatrixElementKind, channel::Integer)
    target = Int(channel)
    found = 0
    second_limit =
        kind in (SPIN_TIMES_POSITION, SPIN_TIMES_HAMILTONIAN_POSITION, SPIN_VELOCITY) ? 3 :
        plan.spatial_dimension
    for first_direction in 1:plan.spatial_dimension, second_direction in 1:second_limit
        _pair_required(plan, kind, first_direction, second_direction) || continue
        found += 1
        found == target && return (first_direction, second_direction)
    end
    throw(BoundsError("No logical pair for $(kind) channel $(target)."))
end

# Return nine Cartesian-pair storage channels, using zero outside the requested spatial/spin domain.
@inline function _pair_channel_map(plan, kind::MatrixElementKind)
    return ntuple(Val(9)) do linear_index
        first_direction = div(linear_index - 1, 3) + 1
        second_direction = mod(linear_index - 1, 3) + 1
        first_direction <= plan.spatial_dimension || return 0
        second_limit =
            kind in (SPIN_TIMES_POSITION, SPIN_TIMES_HAMILTONIAN_POSITION, SPIN_VELOCITY) ? 3 :
            plan.spatial_dimension
        second_direction <= second_limit || return 0
        return _pair_channel(plan, kind, first_direction, second_direction)
    end
end

# Index the fixed nine-entry Cartesian-pair map with the second direction varying fastest.
@inline _pair_map_channel(channel_map, first_direction::Int, second_direction::Int) =
    channel_map[(first_direction - 1) * 3 + second_direction]

# Require every legal spatial axis/pair and all three spin components for each supported capability.
function _full_direction_requirements(spatial_dimension::Int)
    requirements = MatrixElementDirectionRequirements(spatial_dimension)
    spatial_axis_kinds = (
        HAMILTONIAN_DERIVATIVES,
        WANNIER_POSITION,
        INTERNAL_CONNECTION,
        GAUGE_CORRECTION,
        BERRY_CONNECTION,
        VELOCITY_VERTICES,
    )
    for kind in spatial_axis_kinds
        requirements = _require_axes(requirements, kind, 1:spatial_dimension)
    end
    for kind in (HAMILTONIAN_SECOND_DERIVATIVES, INTERNAL_CONNECTION_DERIVATIVES, WANNIER_CURVATURE)
        requirements = _require_pairs(
            requirements,
            kind,
            Iterators.product(1:spatial_dimension, 1:spatial_dimension),
        )
    end
    for kind in (SPIN, SPIN_TIMES_HAMILTONIAN)
        requirements = _require_axes(requirements, kind, 1:3)
    end
    for kind in (SPIN_TIMES_POSITION, SPIN_TIMES_HAMILTONIAN_POSITION, SPIN_VELOCITY)
        requirements =
            _require_pairs(requirements, kind, Iterators.product(1:spatial_dimension, 1:3))
    end
    return requirements
end

# Requested capability bitmask, spatial dimension, and energy-denominator/degeneracy tolerances in eV.
#
# The keyword constructor rejects an empty capability list, dimensions outside `1:3`, and negative tolerances; dependency closure is deferred to `compile_matrix_plan`.
function MatrixElementRequest(
    kinds::MatrixElementKind...;
    spatial_dimension::Integer = 3,
    denominator_regularization::Real = 1.0e-3,
    degeneracy_threshold::Real = 1.0e-7,
)
    isempty(kinds) && throw(ArgumentError("At least one matrix-element capability is required."))
    dimension = Int(spatial_dimension)
    dimension in 1:3 || throw(ArgumentError("spatial_dimension must be in 1:3, got $(dimension)."))
    regularization = Float64(denominator_regularization)
    regularization >= 0.0 || throw(
        ArgumentError("denominator_regularization must be non-negative, got $(regularization)."),
    )
    threshold = Float64(degeneracy_threshold)
    threshold >= 0.0 ||
        throw(ArgumentError("degeneracy_threshold must be non-negative, got $(threshold)."))
    mask = foldl((value, kind) -> value | _capability_bit(kind), kinds; init = UInt64(0))
    return MatrixElementRequest(mask, dimension, regularization, threshold)
end

"""
Immutable requested/required capability masks, Cartesian channel closure, energy tolerances and Wannier-center convention.

Legacy constructors choose convention II and enable source-gauge data; compilation adds spectrum and transitive prerequisites without changing the explicit request mask.
"""
struct MatrixElementPlan
    requested_mask::UInt64
    required_mask::UInt64
    spatial_dimension::Int
    denominator_regularization::Float64
    degeneracy_threshold::Float64
    wannier_center_convention::WannierCenterConvention
    direction_requirements::MatrixElementDirectionRequirements
    source_gauge_required::Bool
end

# Immutable requested/required capability masks, Cartesian channel closure, energy tolerances and Wannier-center convention.
#
# Legacy constructors choose convention II and enable source-gauge data; compilation adds spectrum and transitive prerequisites without changing the explicit request mask.
function MatrixElementPlan(
    requested_mask::UInt64,
    required_mask::UInt64,
    spatial_dimension::Int,
    denominator_regularization::Float64,
    degeneracy_threshold::Float64,
)
    return MatrixElementPlan(
        requested_mask,
        required_mask,
        spatial_dimension,
        denominator_regularization,
        degeneracy_threshold,
        CONVENTION_II,
        _full_direction_requirements(spatial_dimension),
        true,
    )
end

# Immutable requested/required capability masks, Cartesian channel closure, energy tolerances and Wannier-center convention.
#
# Legacy constructors choose convention II and enable source-gauge data; compilation adds spectrum and transitive prerequisites without changing the explicit request mask.
function MatrixElementPlan(
    requested_mask::UInt64,
    required_mask::UInt64,
    spatial_dimension::Int,
    denominator_regularization::Float64,
    degeneracy_threshold::Float64,
    direction_requirements::MatrixElementDirectionRequirements,
)
    return MatrixElementPlan(
        requested_mask,
        required_mask,
        spatial_dimension,
        denominator_regularization,
        degeneracy_threshold,
        CONVENTION_II,
        direction_requirements,
        true,
    )
end

# Immutable requested/required capability masks, Cartesian channel closure, energy tolerances and Wannier-center convention.
#
# Legacy constructors choose convention II and enable source-gauge data; compilation adds spectrum and transitive prerequisites without changing the explicit request mask.
#
# Preserve the pre-convention constructor for internal and downstream callers.
function MatrixElementPlan(
    requested_mask::UInt64,
    required_mask::UInt64,
    spatial_dimension::Int,
    denominator_regularization::Float64,
    degeneracy_threshold::Float64,
    direction_requirements::MatrixElementDirectionRequirements,
    source_gauge_required::Bool,
)
    return MatrixElementPlan(
        requested_mask,
        required_mask,
        spatial_dimension,
        denominator_regularization,
        degeneracy_threshold,
        CONVENTION_II,
        direction_requirements,
        source_gauge_required,
    )
end

# Union one capability's immediate matrix prerequisites into the required mask.
function _add_dependencies(mask::UInt64, kind::MatrixElementKind)
    if kind == SPECTRUM
        return mask
    elseif kind == ENERGY_DIFFERENCES
        return mask | _capability_bit(SPECTRUM)
    elseif kind == HAMILTONIAN_DERIVATIVES || kind == HAMILTONIAN_SECOND_DERIVATIVES
        return mask | _capability_bit(SPECTRUM)
    elseif kind == WANNIER_POSITION
        return mask | _capability_bit(SPECTRUM)
    elseif kind == INTERNAL_CONNECTION
        return mask | _capability_bit(SPECTRUM) | _capability_bit(WANNIER_POSITION)
    elseif kind == INTERNAL_CONNECTION_DERIVATIVES
        return mask | _capability_bit(SPECTRUM) | _capability_bit(WANNIER_POSITION)
    elseif kind == GAUGE_CORRECTION
        return mask | _capability_bit(SPECTRUM) | _capability_bit(ENERGY_DIFFERENCES) |
               _capability_bit(HAMILTONIAN_DERIVATIVES)
    elseif kind == BERRY_CONNECTION
        return mask | _capability_bit(INTERNAL_CONNECTION) | _capability_bit(GAUGE_CORRECTION)
    elseif kind == WANNIER_CURVATURE
        return mask | _capability_bit(WANNIER_POSITION) |
               _capability_bit(INTERNAL_CONNECTION_DERIVATIVES)
    elseif kind == VELOCITY_VERTICES
        return mask | _capability_bit(ENERGY_DIFFERENCES) | _capability_bit(BERRY_CONNECTION)
    elseif kind == SPIN
        return mask | _capability_bit(SPECTRUM)
    elseif kind == SPIN_TIMES_HAMILTONIAN
        return mask | _capability_bit(SPECTRUM)
    elseif kind == SPIN_TIMES_POSITION
        return mask | _capability_bit(SPECTRUM) | _capability_bit(SPIN)
    elseif kind == SPIN_TIMES_HAMILTONIAN_POSITION
        return mask | _capability_bit(SPECTRUM) | _capability_bit(SPIN_TIMES_HAMILTONIAN)
    elseif kind == SPIN_VELOCITY
        return mask | _capability_bit(SPECTRUM) | _capability_bit(ENERGY_DIFFERENCES) |
               _capability_bit(HAMILTONIAN_DERIVATIVES) | _capability_bit(SPIN) |
               _capability_bit(SPIN_TIMES_HAMILTONIAN) | _capability_bit(SPIN_TIMES_POSITION) |
               _capability_bit(SPIN_TIMES_HAMILTONIAN_POSITION)
    end
    error("Unhandled MatrixElementKind $(kind).")
end

# Iterate Cartesian prerequisite masks to a fixed point for all required capabilities, retaining spin-axis extents.
function _propagate_direction_dependencies(
    requirements::MatrixElementDirectionRequirements,
    required_mask::UInt64,
)
    result = requirements
    dimension = requirements.spatial_dimension
    changed = true
    while changed
        previous = result.masks
        if _has_capability(required_mask, VELOCITY_VERTICES)
            for axis in 1:dimension
                _axis_required((; direction_requirements = result), VELOCITY_VERTICES, axis) ||
                    continue
                result = _require_axis(result, BERRY_CONNECTION, axis)
            end
        end
        if _has_capability(required_mask, BERRY_CONNECTION)
            for axis in 1:dimension
                _axis_required((; direction_requirements = result), BERRY_CONNECTION, axis) ||
                    continue
                result = _require_axis(result, INTERNAL_CONNECTION, axis)
                result = _require_axis(result, GAUGE_CORRECTION, axis)
            end
        end
        if _has_capability(required_mask, INTERNAL_CONNECTION)
            for axis in 1:dimension
                _axis_required((; direction_requirements = result), INTERNAL_CONNECTION, axis) ||
                    continue
                result = _require_axis(result, WANNIER_POSITION, axis)
            end
        end
        if _has_capability(required_mask, GAUGE_CORRECTION)
            for axis in 1:dimension
                _axis_required((; direction_requirements = result), GAUGE_CORRECTION, axis) ||
                    continue
                result = _require_axis(result, HAMILTONIAN_DERIVATIVES, axis)
            end
        end
        if _has_capability(required_mask, INTERNAL_CONNECTION_DERIVATIVES)
            for first_direction in 1:dimension, second_direction in 1:dimension
                _pair_required(
                    (; direction_requirements = result, spatial_dimension = dimension),
                    INTERNAL_CONNECTION_DERIVATIVES,
                    first_direction,
                    second_direction,
                ) || continue
                result = _require_axis(result, WANNIER_POSITION, first_direction)
            end
        end
        if _has_capability(required_mask, WANNIER_CURVATURE)
            for first_direction in 1:dimension, second_direction in 1:dimension
                _pair_required(
                    (; direction_requirements = result, spatial_dimension = dimension),
                    WANNIER_CURVATURE,
                    first_direction,
                    second_direction,
                ) || continue
                result = _require_axis(result, WANNIER_POSITION, first_direction)
                result = _require_axis(result, WANNIER_POSITION, second_direction)
                result = _require_pair(
                    result,
                    INTERNAL_CONNECTION_DERIVATIVES,
                    first_direction,
                    second_direction,
                )
                result = _require_pair(
                    result,
                    INTERNAL_CONNECTION_DERIVATIVES,
                    second_direction,
                    first_direction,
                )
            end
        end
        if _has_capability(required_mask, SPIN_VELOCITY)
            for velocity_direction in 1:dimension, spin_direction in 1:3
                _pair_required(
                    (; direction_requirements = result, spatial_dimension = dimension),
                    SPIN_VELOCITY,
                    velocity_direction,
                    spin_direction,
                ) || continue
                result = _require_axis(result, HAMILTONIAN_DERIVATIVES, velocity_direction)
                result = _require_axis(result, SPIN, spin_direction)
                result = _require_axis(result, SPIN_TIMES_HAMILTONIAN, spin_direction)
                result =
                    _require_pair(result, SPIN_TIMES_POSITION, velocity_direction, spin_direction)
                result = _require_pair(
                    result,
                    SPIN_TIMES_HAMILTONIAN_POSITION,
                    velocity_direction,
                    spin_direction,
                )
            end
        end
        changed = result.masks != previous
    end
    return result
end

"""
Close capability and Cartesian direction dependencies into an immutable execution plan.

Always require the spectrum, preserve explicit request bits and energy tolerances, and reject mismatched spatial dimensions. The convenience overload requests all legal directions.
"""
function compile_matrix_plan(
    request::MatrixElementRequest,
    direction_requirements::MatrixElementDirectionRequirements,
    ;
    source_gauge_required::Bool = true,
    wannier_center_convention::WannierCenterConvention = CONVENTION_II,
)
    direction_requirements.spatial_dimension == request.spatial_dimension ||
        throw(ArgumentError("Direction requirements and request use different spatial dimensions."))
    required = request.requested_mask | _capability_bit(SPECTRUM)
    changed = true
    while changed
        previous = required
        for kind in _ALL_MATRIX_ELEMENT_KINDS
            _has_capability(required, kind) || continue
            required = _add_dependencies(required, kind)
        end
        changed = required != previous
    end
    propagated = _propagate_direction_dependencies(direction_requirements, required)
    return MatrixElementPlan(
        request.requested_mask,
        required,
        request.spatial_dimension,
        request.denominator_regularization,
        request.degeneracy_threshold,
        wannier_center_convention,
        propagated,
        source_gauge_required,
    )
end

# Close capability and Cartesian direction dependencies into an immutable execution plan.
#
# Always require the spectrum, preserve explicit request bits and energy tolerances, and reject mismatched spatial dimensions. The convenience overload requests all legal directions.
compile_matrix_plan(
    request::MatrixElementRequest;
    source_gauge_required::Bool = true,
    wannier_center_convention::WannierCenterConvention = CONVENTION_II,
) = compile_matrix_plan(
    request,
    _full_direction_requirements(request.spatial_dimension);
    source_gauge_required,
    wannier_center_convention,
)

"""
Test whether a capability is available after transitive dependency closure, including automatically added prerequisites.
"""
has_capability(plan::MatrixElementPlan, kind::MatrixElementKind) =
    _has_capability(plan.required_mask, kind)

"""
Test whether the caller explicitly requested a capability, excluding prerequisites added only by compilation.
"""
is_requested(plan::MatrixElementPlan, kind::MatrixElementKind) =
    _has_capability(plan.requested_mask, kind)

"""
Exact integer stencil coefficients and photon half-step count used as a shifted-point cache key.

The default constructor denotes the central point; physical reciprocal displacements are resolved separately.
"""
struct KPointOffset
    finite_difference_coefficients::NTuple{3, Int}
    photon_half_steps::Int
end

# Exact integer stencil coefficients and photon half-step count used as a shifted-point cache key.
#
# The default constructor denotes the central point; physical reciprocal displacements are resolved separately.
KPointOffset() = KPointOffset((0, 0, 0), 0)

"""
Write the central fractional k point plus integer finite-difference steps and photon half-steps into `output`.

Require three-vector inputs and a 3x3 displacement matrix; mismatched shapes raise DimensionMismatch. Return the same output vector.

Resolve kpoint offset.
"""
function resolve_kpoint_offset!(
    output::AbstractVector{Float64},
    central_kpoint::AbstractVector{<:Real},
    offset::KPointOffset,
    finite_difference_vectors::AbstractMatrix{<:Real},
    photon_momentum::AbstractVector{<:Real},
)
    length(output) == 3 || throw(DimensionMismatch("output must have length 3"))
    length(central_kpoint) == 3 || throw(DimensionMismatch("central_kpoint must have length 3"))
    size(finite_difference_vectors) == (3, 3) ||
        throw(DimensionMismatch("finite_difference_vectors must have size (3, 3)"))
    length(photon_momentum) == 3 || throw(DimensionMismatch("photon_momentum must have length 3"))
    photon_coefficient = 0.5 * offset.photon_half_steps
    @inbounds for direction in 1:3
        value = Float64(central_kpoint[direction])
        for axis in 1:3
            value +=
                offset.finite_difference_coefficients[axis] *
                finite_difference_vectors[direction, axis]
        end
        output[direction] = value + photon_coefficient * photon_momentum[direction]
    end
    return output
end
