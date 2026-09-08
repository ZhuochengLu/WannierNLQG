const MAGNETIC_POINT_GROUP_OPERATION_DIGEST_CONTRACT = "wanniernlqg.magnetic-point-group-operations/1.0"
const MAGNETIC_POINT_GROUP_SYMBOL_CONVENTION = "wanniernlqg.spglib-canonical/1.0"
const MAGNETIC_POINT_GROUP_BASIS_DEFINITION = "v_input = B * v_canonical; W_input = B * W_canonical * inv(B)"

const _MagneticPointGroupMatrixKey = NTuple{9, Int}

"""Return one integer matrix key in the row-major order required by the digest contract."""
_magnetic_point_group_matrix_key(rotation) =
    Tuple(Int(rotation[row, column]) for row in 1:3 for column in 1:3)

"""Reconstruct a 3x3 integer matrix from a row-major operation key."""
function _magnetic_point_group_key_matrix(key::_MagneticPointGroupMatrixKey)
    return [key[3 * (row - 1) + column] for row in 1:3, column in 1:3]
end

"""Reduce an exact rational basis matrix to one positive common denominator."""
function _magnetic_point_group_basis_payload(basis)
    exact = Rational{Int}.(basis)
    common_denominator = foldl(lcm, denominator.(exact); init = 1)
    numerators = numerator.(exact .* common_denominator)
    common_divisor = foldl(gcd, abs.(numerators); init = common_denominator)
    common_divisor = gcd(common_divisor, common_denominator)
    common_divisor > 1 && begin
        numerators = div.(numerators, common_divisor)
        common_denominator = div(common_denominator, common_divisor)
    end
    return (
        definition = MAGNETIC_POINT_GROUP_BASIS_DEFINITION,
        shape = [3, 3],
        numerator_rows = [[Int(numerators[row, column]) for column in 1:3] for row in 1:3],
        denominator = Int(common_denominator),
    )
end

"""Split a compact ordinary H-M symbol into display slots and its slash position."""
function _magnetic_point_group_parse_hm(symbol::AbstractString)
    tokens = String[]
    slash_after = 0
    index = firstindex(symbol)
    while index <= lastindex(symbol)
        character = symbol[index]
        if character == '/'
            slash_after = length(tokens)
            index = nextind(symbol, index)
        elseif character == '-'
            next_index = nextind(symbol, index)
            next_index <= lastindex(symbol) || error("invalid H-M symbol $(symbol)")
            push!(tokens, symbol[index:next_index])
            index = nextind(symbol, next_index)
        else
            push!(tokens, string(character))
            index = nextind(symbol, index)
        end
    end
    isempty(tokens) && error("empty H-M symbol")
    return tokens, slash_after
end

"""Map one H-M display token to its signed crystallographic operation order."""
_magnetic_point_group_signed_order(token) = token == "m" ? -2 : parse(Int, token)

"""Classify an integer rotation by signed crystallographic order."""
function _magnetic_point_group_rotation_type(rotation)
    determinant = round(Int, det(rotation))
    trace_value = tr(rotation)
    if determinant == 1
        return get(Dict(3 => 1, -1 => 2, 0 => 3, 1 => 4, 2 => 6), trace_value, 0)
    elseif determinant == -1
        return get(Dict(-3 => -1, 1 => -2, 0 => -3, -1 => -4, -2 => -6), trace_value, 0)
    end
    return 0
end

"""Normalize an integer axis to a primitive tuple with deterministic sign."""
function _magnetic_point_group_normalize_axis(axis)
    divisor = gcd(abs(axis[1]), gcd(abs(axis[2]), abs(axis[3])))
    divisor == 0 && return (0, 0, 0)
    primitive = div.(axis, divisor)
    first_nonzero = findfirst(!iszero, primitive)
    primitive[first_nonzero] < 0 && (primitive = -primitive)
    return Tuple(primitive)
end

"""Return the exact axis of a proper rotation or its improper proper-part."""
function _magnetic_point_group_operation_axis(rotation)
    proper = round(Int, det(rotation)) == 1 ? rotation : -rotation
    proper == Matrix{Int}(I, 3, 3) && return (0, 0, 0)
    difference = proper - Matrix{Int}(I, 3, 3)
    candidates = NTuple{3, Int}[]
    for first_row in 1:2, second_row in (first_row + 1):3
        axis = cross(vec(difference[first_row, :]), vec(difference[second_row, :]))
        any(!iszero, axis) && push!(candidates, _magnetic_point_group_normalize_axis(axis))
    end
    unique!(candidates)
    length(candidates) == 1 || error("integer rotation has no unique crystallographic axis")
    return only(candidates)
end

"""Infer the ordinary crystal system from Spglib's compact point-group symbol."""
function _magnetic_point_group_crystal_system(tokens)
    first_order = abs(_magnetic_point_group_signed_order(tokens[1]))
    if length(tokens) >= 2 &&
       abs(_magnetic_point_group_signed_order(tokens[2])) == 3 &&
       first_order != 3
        return :cubic
    elseif first_order == 6
        return :hexagonal
    elseif first_order == 4
        return :tetragonal
    elseif first_order == 3
        return :trigonal
    elseif length(tokens) == 3
        return :orthorhombic
    elseif length(tokens) == 1 && first_order == 1
        return :triclinic
    end
    return :monoclinic
end

"""Map Spglib's ordinary point-group number to its crystal system."""
function _magnetic_point_group_crystal_system(point_group_number::Integer)
    1 <= point_group_number <= 32 ||
        throw(ArgumentError("ordinary point-group number must be in 1:32"))
    point_group_number <= 2 && return :triclinic
    point_group_number <= 5 && return :monoclinic
    point_group_number <= 8 && return :orthorhombic
    point_group_number <= 15 && return :tetragonal
    point_group_number <= 20 && return :trigonal
    point_group_number <= 27 && return :hexagonal
    return :cubic
end

"""Return the documented geometrical family associated with one H-M slot."""
function _magnetic_point_group_slot_family(system, index, slash_after)
    system == :triclinic && return :none
    system == :monoclinic && return :y
    system == :orthorhombic && return (:x, :y, :z)[index]
    system == :cubic && return (:axial, :body, :face)[index]
    principal_slots = slash_after == 1 ? 2 : 1
    index <= principal_slots && return :z
    secondary = index - principal_slots
    system == :trigonal && return :basal
    system == :tetragonal && return (:x, :diagonal)[secondary]
    system == :hexagonal && return (:hex_a, :hex_b)[secondary]
    error("unsupported ordinary crystal system $(system)")
end

"""Test whether an exact operation axis belongs to one conventional H-M slot family."""
function _magnetic_point_group_axis_in_family(axis, family)
    x, y, z = axis
    family == :none && return axis == (0, 0, 0)
    family == :x && return axis == (1, 0, 0)
    family == :y && return axis == (0, 1, 0)
    family == :z && return axis == (0, 0, 1)
    family == :basal && return z == 0 && (x != 0 || y != 0)
    family == :diagonal && return z == 0 && x != 0 && abs(x) == abs(y)
    family == :axial && return count(!iszero, axis) == 1
    family == :face && return count(!iszero, axis) == 2 && sort(abs.([x, y, z])) == [0, 1, 1]
    family == :body && return all(==(1), abs.([x, y, z]))
    hexagonal_norm = x * x + y * y - x * y
    family == :hex_a && return z == 0 && hexagonal_norm == 1
    family == :hex_b && return z == 0 && hexagonal_norm == 3
    return false
end

"""Render H-M slots with one deterministic antiunitary color per slot."""
function _magnetic_point_group_render_slots(colors, ordinary_hm)
    tokens, slash_after = _magnetic_point_group_parse_hm(ordinary_hm)
    system = _magnetic_point_group_crystal_system(tokens)
    bits = Bool[]
    for (index, token) in enumerate(tokens)
        target_type = _magnetic_point_group_signed_order(token)
        family = _magnetic_point_group_slot_family(system, index, slash_after)
        matches = Bool[]
        for (key, parities) in colors
            rotation = _magnetic_point_group_key_matrix(key)
            if _magnetic_point_group_rotation_type(rotation) == target_type &&
               _magnetic_point_group_axis_in_family(
                _magnetic_point_group_operation_axis(rotation),
                family,
            )
                append!(matches, parities)
            end
        end
        isempty(matches) && return nothing
        length(unique(matches)) == 1 ||
            error("conflicting antiunitary colors for H-M slot $(index) of $(ordinary_hm)")
        push!(bits, first(matches))
    end
    output = IOBuffer()
    for index in eachindex(tokens)
        index > 1 && slash_after == index - 1 && print(output, '/')
        print(output, tokens[index])
        bits[index] && print(output, '\'')
    end
    return (symbol = String(take!(output)), bits)
end

"""Return the public convention's structured slot/color ordering key."""
function _magnetic_point_group_symbol_sort_key(rendered, ordinary_hm)
    tokens, _ = _magnetic_point_group_parse_hm(ordinary_hm)
    system = _magnetic_point_group_crystal_system(tokens)
    proper_rotations_only = all(token -> !startswith(token, "-") && token != "m", tokens)
    priority =
        if proper_rotations_only &&
           system in (:orthorhombic, :tetragonal) &&
           length(rendered.bits) == 3
            (1, 3, 2)
        else
            Tuple(eachindex(rendered.bits))
        end
    descending_color_key = Tuple(rendered.bits[index] ? 0 : 1 for index in priority)
    return (descending_color_key, rendered.symbol)
end

"""Conjugate a colored operation dictionary by one exact integer basis candidate."""
function _magnetic_point_group_conjugate_colors(colors, basis)
    inverse_basis = inv(Rational{Int}.(basis))
    transformed = Dict{_MagneticPointGroupMatrixKey, Set{Bool}}()
    for (key, parities) in colors
        exact = inverse_basis * _magnetic_point_group_key_matrix(key) * basis
        all(isinteger, exact) || return nothing
        transformed_key = _magnetic_point_group_matrix_key(Int.(exact))
        union!(get!(transformed, transformed_key, Set{Bool}()), parities)
    end
    return transformed
end

"""Enumerate the finite integer normalizer search defined by convention 1.0."""
function _magnetic_point_group_normalizer_candidates(colors, ordinary_point_group_number)
    vectors = NTuple{3, Int}[(1, 0, 0), (0, 1, 0), (0, 0, 1)]
    for key in keys(colors)
        axis = _magnetic_point_group_operation_axis(_magnetic_point_group_key_matrix(key))
        axis == (0, 0, 0) || push!(vectors, axis)
    end
    sort!(unique!(vectors); by = vector -> (sum(abs2, vector), vector))
    candidates = Matrix{Int}[]
    system = _magnetic_point_group_crystal_system(ordinary_point_group_number)
    if system in (:tetragonal, :trigonal, :hexagonal)
        basal = NTuple{3, Int}[]
        for x in -2:2, y in -2:2
            x == 0 && y == 0 && continue
            push!(basal, _magnetic_point_group_normalize_axis([x, y, 0]))
        end
        unique!(basal)
        for first_axis in basal, second_axis in basal
            basis = hcat(collect(first_axis), collect(second_axis), [0, 0, 1])
            det(basis) == 0 && continue
            push!(candidates, basis)
        end
    else
        for first_axis in vectors, second_axis in vectors, third_axis in vectors
            basis = hcat(collect(first_axis), collect(second_axis), collect(third_axis))
            det(basis) == 0 && continue
            push!(candidates, basis)
        end
    end
    sort!(
        candidates;
        by = basis -> (
            abs(round(Int, det(basis))),
            sum(abs2, basis),
            _magnetic_point_group_matrix_key(basis),
        ),
    )
    unique!(candidates)
    return candidates
end

"""Serialize a colored operation set exactly as operation-digest contract 1.0."""
function _magnetic_point_group_operation_serialization(colors)
    operations = Tuple{Int, _MagneticPointGroupMatrixKey}[]
    for (key, parities) in colors, parity in parities
        push!(operations, (parity ? 1 : 0, key))
    end
    sort!(operations)
    output = IOBuffer()
    println(output, MAGNETIC_POINT_GROUP_OPERATION_DIGEST_CONTRACT)
    for (parity, key) in operations
        println(output, parity, ':', join(key, ','))
    end
    return String(take!(output))
end

"""Validate exact colored-operation reconstruction under the reported input basis."""
function _magnetic_point_group_validate_basis(input_colors, canonical_colors, basis)
    inverse_basis = inv(Rational{Int}.(basis))
    reconstructed = Set{Tuple{_MagneticPointGroupMatrixKey, Bool}}()
    for (key, parities) in canonical_colors, parity in parities
        exact = Rational{Int}.(basis) * _magnetic_point_group_key_matrix(key) * inverse_basis
        all(isinteger, exact) ||
            error("reported canonical basis reconstructs a noninteger rotation")
        reconstructed_key = _magnetic_point_group_matrix_key(Int.(exact))
        push!(reconstructed, (reconstructed_key, parity))
    end
    original = Set{Tuple{_MagneticPointGroupMatrixKey, Bool}}()
    for (key, parities) in input_colors, parity in parities
        push!(original, (key, parity))
    end
    reconstructed == original || error("reported basis does not reconstruct the colored group")
    return true
end

"""
Canonicalize one complete magnetic point-operation set without consulting a symbol table.

`standard_transform` is the exact integer matrix returned by Spglib point-group
standardization and must satisfy `W = inv(P) * R_input * P`. The result's digest
is invariant to operation order and to every basis in the convention 1.0 search.
"""
function _magnetic_point_group_canonical_form(
    rotations,
    antiunitary,
    ordinary_point_group_number::Integer,
    ordinary_hm::AbstractString,
    standard_transform,
    canonical_spatial_keys = nothing,
)
    length(rotations) == length(antiunitary) ||
        throw(ArgumentError("rotation and antiunitary arrays must have equal length"))
    isempty(rotations) && throw(ArgumentError("magnetic point group cannot be empty"))
    input_colors = Dict{_MagneticPointGroupMatrixKey, Set{Bool}}()
    for (rotation, parity) in zip(rotations, antiunitary)
        size(rotation) == (3, 3) || throw(ArgumentError("point rotations must be 3x3"))
        integer_rotation = Matrix{Int}(rotation)
        abs(round(Int, det(integer_rotation))) == 1 ||
            throw(ArgumentError("point rotations must be unimodular"))
        key = _magnetic_point_group_matrix_key(integer_rotation)
        push!(get!(input_colors, key, Set{Bool}()), Bool(parity))
    end
    transform = Matrix{Int}(standard_transform)
    det(transform) != 0 || throw(ArgumentError("Spglib standard transform is singular"))
    standardized = _magnetic_point_group_conjugate_colors(input_colors, transform)
    standardized === nothing && error("Spglib standard transform produced noninteger rotations")
    target_spatial_keys =
        canonical_spatial_keys === nothing ? Set(keys(standardized)) : Set(canonical_spatial_keys)
    length(target_spatial_keys) == length(standardized) ||
        error("ordinary canonical operation count disagrees with standardized group")
    parity_sets = collect(values(standardized))
    mode = if all(==(Set([false])), parity_sets)
        :type_I
    elseif all(==(Set([false, true])), parity_sets)
        :grey
    elseif all(length(parities) == 1 for parities in parity_sets)
        :black_white
    else
        error("colored operation set is partially doubled")
    end

    candidates = NamedTuple[]
    for normalizer in
        _magnetic_point_group_normalizer_candidates(standardized, ordinary_point_group_number)
        transformed = _magnetic_point_group_conjugate_colors(standardized, normalizer)
        transformed === nothing && continue
        Set(keys(transformed)) == target_spatial_keys || continue
        rendered = if mode == :type_I
            (symbol = String(ordinary_hm), bits = Bool[])
        elseif mode == :grey
            (symbol = ordinary_hm == "1" ? "1'" : String(ordinary_hm) * "1'", bits = Bool[])
        else
            _magnetic_point_group_render_slots(transformed, ordinary_hm)
        end
        serialization = _magnetic_point_group_operation_serialization(transformed)
        push!(
            candidates,
            (;
                normalizer,
                transformed,
                rendered,
                serialization,
                basis_to_input = Rational{Int}.(transform) * Rational{Int}.(normalizer),
            ),
        )
    end
    isempty(candidates) && error("no valid integer normalizer basis for $(ordinary_hm)")
    digest_candidate = first(
        sort(
            candidates;
            by = candidate -> (
                candidate.serialization,
                _magnetic_point_group_matrix_key(candidate.normalizer),
            ),
        ),
    )
    display_candidates = filter(candidate -> candidate.rendered !== nothing, candidates)
    isempty(display_candidates) && error("no H-M display basis for $(ordinary_hm)")
    display_candidate = first(
        sort(
            display_candidates;
            by = candidate ->
                _magnetic_point_group_symbol_sort_key(candidate.rendered, ordinary_hm),
        ),
    )
    display_symbols = Set(candidate.rendered.symbol for candidate in display_candidates)
    _magnetic_point_group_validate_basis(
        input_colors,
        digest_candidate.transformed,
        digest_candidate.basis_to_input,
    )
    return (
        operation_digest = bytes2hex(sha256(digest_candidate.serialization)),
        operation_serialization = digest_candidate.serialization,
        hermann_mauguin = display_candidate.rendered.symbol,
        symbol_convention = MAGNETIC_POINT_GROUP_SYMBOL_CONVENTION,
        equivalent_axis_notation = length(display_symbols) > 1,
        basis_transform_to_input = _magnetic_point_group_basis_payload(
            digest_candidate.basis_to_input,
        ),
        ordinary_hermann_mauguin = String(ordinary_hm),
        magnetic_kind = mode,
        colored_operation_count = sum(length, values(standardized)),
        spatial_rotation_count = length(standardized),
    )
end

"""Return the generated class identity of one runtime colored operation set."""
function magnetic_point_group_operation_identity(
    rotations,
    antiunitary,
    ordinary_point_group_number::Integer,
    ordinary_hm::AbstractString,
    standard_transform,
)
    canonical = _magnetic_point_group_canonical_form(
        rotations,
        antiunitary,
        ordinary_point_group_number,
        ordinary_hm,
        standard_transform,
        get(
            MAGNETIC_POINT_GROUP_ORDINARY_CANONICAL_KEYS,
            Int(ordinary_point_group_number),
            nothing,
        ),
    )
    class_number = get(MAGNETIC_POINT_GROUP_DIGEST_TO_NUMBER, canonical.operation_digest, nothing)
    class_number === nothing &&
        error("colored operation digest is absent from the generated 122-class catalog")
    generated_symbol = MAGNETIC_POINT_GROUP_SYMBOLS[class_number]
    return (
        magnetic_point_group_number = class_number,
        operation_digest = canonical.operation_digest,
        operation_digest_contract = MAGNETIC_POINT_GROUP_OPERATION_DIGEST_CONTRACT,
        hermann_mauguin = generated_symbol,
        symbol_convention = MAGNETIC_POINT_GROUP_SYMBOL_CONVENTION,
        equivalent_axis_notation = MAGNETIC_POINT_GROUP_EQUIVALENT_AXIS_NOTATION[class_number],
        basis_transform_to_input = canonical.basis_transform_to_input,
    )
end
