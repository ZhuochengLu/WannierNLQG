"""Fail-closed little-group algebra at one stored mesh point.

Local operation positions index `operation_indices`, whose entries are the
corresponding indices in `BandRepresentation.operations`.  The semilinear
factor system obeys

`D(g) * conj(D(h))^a_g = factor_system[g,h] * D(g*h)`.

No character or trace is assigned to an antiunitary operation.
"""
struct ProjectionLittleGroupAlgebra
    kpoint_index::Int
    operation_indices::Vector{Int}
    unitary_positions::Vector{Int}
    antiunitary_positions::Vector{Int}
    identity_position::Int
    product_positions::Matrix{Int}
    inverse_positions::Vector{Int}
    factor_system::Matrix{ComplexF64}
    maximum_cocycle_residual::Float64
    complete::Bool
    uncertain::Bool
    diagnostics::Vector{String}
end

"""One verified irreducible block of a unitary projective little group."""
struct ProjectionProjectiveIrrep
    label::String
    dimension::Int
    unitary_positions::Vector{Int}
    matrices::Vector{Matrix{ComplexF64}}
    characters::Vector{ComplexF64}
    multiplicity_in_regular::Int
    maximum_group_law_residual::Float64
end

"""Complete or explicitly uncertain enumeration of unitary projective irreps."""
struct ProjectionProjectiveIrrepEnumeration
    irreps::Vector{ProjectionProjectiveIrrep}
    regular_dimension::Int
    dimension_sum_of_squares::Int
    maximum_residual::Float64
    complete::Bool
    uncertain::Bool
    diagnostics::Vector{String}
end

# Return an empty little-group algebra without inventing missing closure data.
function _empty_projection_little_group_algebra(kpoint_index::Int, diagnostics::Vector{String})
    return ProjectionLittleGroupAlgebra(
        kpoint_index,
        Int[],
        Int[],
        Int[],
        0,
        zeros(Int, 0, 0),
        Int[],
        zeros(ComplexF64, 0, 0),
        Inf,
        false,
        true,
        diagnostics,
    )
end

"""
    _build_little_group_algebra(representation, kpoint_index; tolerance=1e-8)

Construct the exact operation closure and the nonsymmorphic/spin projective
factor system at one stored mesh point.  A missing product, inverse, or
semilinear cocycle is reported as an incomplete and uncertain algebra rather
than being repaired by phase fitting.
"""
function _build_little_group_algebra(
    representation::BandRepresentation,
    kpoint_index::Integer;
    tolerance::Real = 1.0e-8,
)
    tolerance_value = Float64(tolerance)
    isfinite(tolerance_value) && tolerance_value > 0.0 ||
        throw(ArgumentError("little-group tolerance must be positive and finite"))
    kpoint = Int(kpoint_index)
    num_kpoints = size(representation.kpoint_map, 2)
    1 <= kpoint <= num_kpoints || throw(BoundsError(1:num_kpoints, kpoint))

    diagnostics = String[]
    product_table = try
        build_representation_product_table(
            representation.operations,
            representation.spinor;
            tolerance = tolerance_value,
        )
    catch error
        push!(diagnostics, "operation product table is invalid: $(sprint(showerror, error))")
        return _empty_projection_little_group_algebra(kpoint, diagnostics)
    end

    operation_indices = findall(
        operation_index -> representation.kpoint_map[operation_index, kpoint] == kpoint,
        eachindex(representation.operations),
    )
    isempty(operation_indices) && begin
        push!(diagnostics, "little group is empty")
        return _empty_projection_little_group_algebra(kpoint, diagnostics)
    end
    global_to_local = Dict(index => position for (position, index) in enumerate(operation_indices))
    identity_position = get(global_to_local, product_table.identity_index, 0)
    identity_position > 0 || push!(diagnostics, "little group does not contain the identity")

    k_fractional = @view representation.kpoints_fractional[kpoint, :]
    for operation_index in operation_indices
        operation = representation.operations[operation_index]
        sign = operation.antiunitary ? -1.0 : 1.0
        transformed = sign .* (transpose(inv(operation.rotation_fractional)) * k_fractional)
        reconstructed =
            k_fractional .+ @view(representation.reciprocal_shifts[:, operation_index, kpoint])
        residual = maximum(abs, transformed - reconstructed)
        residual <= tolerance_value || push!(
            diagnostics,
            "stored reciprocal shift contradicts little-group action $(operation_index); residual=$(residual)",
        )
    end

    order = length(operation_indices)
    product_positions = zeros(Int, order, order)
    factor_system = zeros(ComplexF64, order, order)
    for left_position in 1:order, right_position in 1:order
        left_index = operation_indices[left_position]
        right_index = operation_indices[right_position]
        product_index = product_table.product_indices[left_index, right_index]
        product_position = get(global_to_local, product_index, 0)
        if product_position == 0
            push!(
                diagnostics,
                "little group is not closed under local product $(left_position) o $(right_position)",
            )
            continue
        end
        product_positions[left_position, right_position] = product_position
        lattice_translation =
            @view product_table.translation_differences[:, left_index, right_index]
        factor_system[left_position, right_position] =
            product_table.spinor_factors[left_index, right_index] *
            cis(-2.0 * pi * dot(k_fractional, lattice_translation))
    end

    inverse_positions = zeros(Int, order)
    if identity_position > 0
        for position in 1:order
            matches = findall(1:order) do candidate
                product_positions[position, candidate] == identity_position &&
                    product_positions[candidate, position] == identity_position
            end
            if length(matches) == 1
                inverse_positions[position] = only(matches)
            else
                push!(
                    diagnostics,
                    "little-group operation $(position) has $(length(matches)) two-sided inverses",
                )
            end
        end
    end

    maximum_cocycle_residual = 0.0
    for first_position in 1:order, second_position in 1:order, third_position in 1:order
        first_second = product_positions[first_position, second_position]
        second_third = product_positions[second_position, third_position]
        (first_second == 0 || second_third == 0) && continue
        left_associated = product_positions[first_second, third_position]
        right_associated = product_positions[first_position, second_third]
        if left_associated == 0 || right_associated == 0 || left_associated != right_associated
            push!(diagnostics, "little-group product table is not associative")
            maximum_cocycle_residual = Inf
            break
        end
        first_operation = representation.operations[operation_indices[first_position]]
        left_factor =
            factor_system[first_position, second_position] *
            factor_system[first_second, third_position]
        nested_factor = factor_system[second_position, third_position]
        first_operation.antiunitary && (nested_factor = conj(nested_factor))
        right_factor = nested_factor * factor_system[first_position, second_third]
        maximum_cocycle_residual = max(maximum_cocycle_residual, abs(left_factor - right_factor))
    end
    if !isfinite(maximum_cocycle_residual) || maximum_cocycle_residual > tolerance_value
        push!(
            diagnostics,
            "semilinear factor system fails its cocycle identity; residual=$(maximum_cocycle_residual)",
        )
    end
    if any(abs(abs(value) - 1.0) > tolerance_value for value in factor_system)
        push!(diagnostics, "little-group factor system contains a non-unit-modulus entry")
    end

    unitary_positions = findall(operation_indices) do operation_index
        !representation.operations[operation_index].antiunitary
    end
    antiunitary_positions = setdiff(collect(1:order), unitary_positions)
    complete = isempty(diagnostics) && all(>(0), product_positions) && all(>(0), inverse_positions)
    return ProjectionLittleGroupAlgebra(
        kpoint,
        operation_indices,
        unitary_positions,
        antiunitary_positions,
        identity_position,
        product_positions,
        inverse_positions,
        factor_system,
        maximum_cocycle_residual,
        complete,
        !complete,
        diagnostics,
    )
end

# Build mutually commuting left/right twisted regular actions of the unitary subgroup.
function _projection_twisted_regular_actions(
    algebra::ProjectionLittleGroupAlgebra,
    tolerance::Float64,
)
    unitary_positions = algebra.unitary_positions
    order = length(unitary_positions)
    position_to_unitary =
        Dict(position => index for (index, position) in enumerate(unitary_positions))
    left_actions = Matrix{ComplexF64}[]
    right_actions = Matrix{ComplexF64}[]
    for group_position in unitary_positions
        left = zeros(ComplexF64, order, order)
        right = zeros(ComplexF64, order, order)
        for (basis_index, basis_position) in enumerate(unitary_positions)
            left_product = algebra.product_positions[group_position, basis_position]
            right_product = algebra.product_positions[basis_position, group_position]
            haskey(position_to_unitary, left_product) &&
            haskey(position_to_unitary, right_product) ||
                return nothing, nothing, "unitary subgroup is not closed"
            left[position_to_unitary[left_product], basis_index] =
                algebra.factor_system[group_position, basis_position]
            right[position_to_unitary[right_product], basis_index] =
                algebra.factor_system[basis_position, group_position]
        end
        push!(left_actions, left)
        push!(right_actions, right)
    end
    maximum_commutator = maximum(
        maximum(abs, left * right - right * left) for left in left_actions for
        right in right_actions
    )
    maximum_commutator <= tolerance || return nothing,
    nothing,
    "twisted left/right regular actions do not commute; residual=$(maximum_commutator)"
    return left_actions, right_actions, ""
end

# Canonicalize column phases and column ordering without rotating a subspace.
function _projection_canonicalize_basis(basis::AbstractMatrix, tolerance::Float64)
    value = Matrix{ComplexF64}(basis)
    pivots = Vector{Tuple{Int, Float64, Int}}(undef, size(value, 2))
    for column in axes(value, 2)
        magnitudes = abs.(@view value[:, column])
        pivot = argmax(magnitudes)
        if magnitudes[pivot] > tolerance
            value[:, column] .*= cis(-angle(value[pivot, column]))
            real(value[pivot, column]) < 0.0 && (value[:, column] .*= -1)
        end
        pivots[column] = (pivot, -magnitudes[pivot], column)
    end
    permutation = sortperm(pivots)
    return value[:, permutation]
end

# Split a reducing regular-representation subspace with its compressed right action.
function _projection_regular_splitter(
    subspace::Matrix{ComplexF64},
    right_actions::Vector{Matrix{ComplexF64}},
    tolerance::Float64,
)
    dimension = size(subspace, 2)
    identity_matrix = Matrix{ComplexF64}(I, dimension, dimension)
    candidates = Matrix{ComplexF64}[]
    for action in right_actions
        compressed = subspace' * action * subspace
        push!(candidates, (compressed + compressed') ./ 2)
        push!(candidates, (compressed - compressed') ./ (2.0im))
    end
    for candidate in candidates
        traceless = candidate - (tr(candidate) / dimension) .* identity_matrix
        norm(traceless) > tolerance || continue
        decomposition = eigen(Hermitian((traceless + traceless') ./ 2))
        scale = max(1.0, maximum(abs, decomposition.values))
        clusters = UnitRange{Int}[]
        first_index = 1
        for index in 2:dimension
            if abs(decomposition.values[index] - decomposition.values[index - 1]) >
               tolerance * scale
                push!(clusters, first_index:(index - 1))
                first_index = index
            end
        end
        push!(clusters, first_index:dimension)
        length(clusters) > 1 || continue
        return [
            _projection_canonicalize_basis(subspace * decomposition.vectors[:, cluster], tolerance)
            for cluster in clusters
        ]
    end
    return Matrix{ComplexF64}[]
end

# Recursively split the twisted regular action into verified irreducible copies.
function _projection_split_regular_representation(
    left_actions::Vector{Matrix{ComplexF64}},
    right_actions::Vector{Matrix{ComplexF64}},
    tolerance::Float64,
)
    order = size(first(left_actions), 1)
    pending = [Matrix{ComplexF64}(I, order, order)]
    irreducible_subspaces = Matrix{ComplexF64}[]
    diagnostics = String[]
    while !isempty(pending)
        subspace = popfirst!(pending)
        dimension = size(subspace, 2)
        maximum_leakage = maximum(
            norm(action * subspace - subspace * (subspace' * action * subspace)) for
            action in left_actions
        )
        if maximum_leakage > tolerance
            push!(diagnostics, "regular decomposition lost invariance; residual=$(maximum_leakage)")
            continue
        end
        splits = _projection_regular_splitter(subspace, right_actions, tolerance)
        if isempty(splits)
            push!(irreducible_subspaces, subspace)
        else
            append!(pending, splits)
        end
        length(pending) + length(irreducible_subspaces) <= order || begin
            push!(diagnostics, "regular decomposition produced too many invariant blocks")
            break
        end
    end
    return irreducible_subspaces, diagnostics
end

# Measure the projective group law for one unitary matrix representation.
function _projection_unitary_group_law_residual(
    matrices::Vector{Matrix{ComplexF64}},
    algebra::ProjectionLittleGroupAlgebra,
)
    positions = algebra.unitary_positions
    position_to_unitary = Dict(position => index for (index, position) in enumerate(positions))
    maximum_residual = 0.0
    for (left_index, left_position) in enumerate(positions),
        (right_index, right_position) in enumerate(positions)

        product_position = algebra.product_positions[left_position, right_position]
        product_index = get(position_to_unitary, product_position, 0)
        product_index > 0 || return Inf
        residual = maximum(
            abs,
            matrices[left_index] * matrices[right_index] -
            algebra.factor_system[left_position, right_position] .* matrices[product_index],
        )
        maximum_residual = max(maximum_residual, residual)
    end
    return maximum_residual
end

"""
    _enumerate_projective_irreps(algebra; tolerance=1e-8, max_regular_dimension=96)

Enumerate the unitary-subgroup projective irreps by decomposing its twisted
left regular representation with the commuting twisted right action.  The
enumeration is accepted only when every block is unitary, satisfies the same
factor system, occurs with regular multiplicity equal to its dimension, and
obeys the sum-of-squared-dimensions identity.
"""
function _enumerate_projective_irreps(
    algebra::ProjectionLittleGroupAlgebra;
    tolerance::Real = 1.0e-8,
    max_regular_dimension::Integer = 96,
)
    tolerance_value = Float64(tolerance)
    isfinite(tolerance_value) && tolerance_value > 0.0 ||
        throw(ArgumentError("irrep tolerance must be positive and finite"))
    dimension_limit = Int(max_regular_dimension)
    dimension_limit > 0 || throw(ArgumentError("max_regular_dimension must be positive"))
    diagnostics = copy(algebra.diagnostics)
    order = length(algebra.unitary_positions)
    if !algebra.complete || order == 0
        push!(diagnostics, "projective irrep enumeration requires a complete unitary subgroup")
        return ProjectionProjectiveIrrepEnumeration(
            ProjectionProjectiveIrrep[],
            order,
            0,
            Inf,
            false,
            true,
            diagnostics,
        )
    end
    if order > dimension_limit
        push!(
            diagnostics,
            "unitary little-group order $(order) exceeds verified regular-action limit $(dimension_limit)",
        )
        return ProjectionProjectiveIrrepEnumeration(
            ProjectionProjectiveIrrep[],
            order,
            0,
            Inf,
            false,
            true,
            diagnostics,
        )
    end

    left_actions, right_actions, action_error =
        _projection_twisted_regular_actions(algebra, tolerance_value)
    if left_actions === nothing
        push!(diagnostics, action_error)
        return ProjectionProjectiveIrrepEnumeration(
            ProjectionProjectiveIrrep[],
            order,
            0,
            Inf,
            false,
            true,
            diagnostics,
        )
    end
    subspaces, split_diagnostics = _projection_split_regular_representation(
        something(left_actions),
        something(right_actions),
        tolerance_value,
    )
    append!(diagnostics, split_diagnostics)

    copies = NamedTuple[]
    maximum_residual = 0.0
    for subspace in subspaces
        matrices = [Matrix(subspace' * action * subspace) for action in something(left_actions)]
        dimension = size(subspace, 2)
        identity_matrix = Matrix{ComplexF64}(I, dimension, dimension)
        unitarity_residual =
            maximum(maximum(abs, matrix' * matrix - identity_matrix) for matrix in matrices)
        group_law_residual = _projection_unitary_group_law_residual(matrices, algebra)
        local_residual = max(unitarity_residual, group_law_residual)
        maximum_residual = max(maximum_residual, local_residual)
        if local_residual > tolerance_value
            push!(
                diagnostics,
                "regular irrep block fails unitarity/group law; residual=$(local_residual)",
            )
            continue
        end
        push!(
            copies,
            (;
                dimension,
                matrices,
                characters = ComplexF64[tr(matrix) for matrix in matrices],
                group_law_residual,
            ),
        )
    end

    groups = Vector{Vector{Int}}()
    for copy_index in eachindex(copies)
        matched = findfirst(groups) do group
            representative = copies[first(group)]
            candidate = copies[copy_index]
            representative.dimension == candidate.dimension &&
                maximum(abs, representative.characters - candidate.characters) <= tolerance_value
        end
        if matched === nothing
            push!(groups, [copy_index])
        else
            push!(groups[something(matched)], copy_index)
        end
    end
    sort!(
        groups;
        by = group -> begin
            copy = copies[first(group)]
            character_key = join(
                (
                    "$(round(real(value); digits = 10)),$(round(imag(value); digits = 10))"
                    for value in copy.characters
                ),
                ";",
            )
            (copy.dimension, character_key)
        end,
    )

    irreps = ProjectionProjectiveIrrep[]
    for (irrep_index, group) in enumerate(groups)
        representative_copy = copies[first(group)]
        multiplicity = length(group)
        multiplicity == representative_copy.dimension || push!(
            diagnostics,
            "regular multiplicity $(multiplicity) does not equal irrep dimension $(representative_copy.dimension)",
        )
        push!(
            irreps,
            ProjectionProjectiveIrrep(
                "irrep_$(lpad(irrep_index, 3, '0'))",
                representative_copy.dimension,
                copy(algebra.unitary_positions),
                representative_copy.matrices,
                representative_copy.characters,
                multiplicity,
                representative_copy.group_law_residual,
            ),
        )
    end
    dimension_sum_of_squares = sum(irrep.dimension^2 for irrep in irreps)
    dimension_sum_of_squares == order || push!(
        diagnostics,
        "projective irrep dimensions sum to $(dimension_sum_of_squares), expected $(order)",
    )
    complete = isempty(diagnostics) && maximum_residual <= tolerance_value
    return ProjectionProjectiveIrrepEnumeration(
        irreps,
        order,
        dimension_sum_of_squares,
        maximum_residual,
        complete,
        !complete,
        diagnostics,
    )
end
