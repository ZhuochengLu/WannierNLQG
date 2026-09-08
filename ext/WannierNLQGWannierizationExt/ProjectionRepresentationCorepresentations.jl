"""One Wigner-classified magnetic little-group corepresentation signature."""
struct ProjectionMagneticCorepresentation
    label::String
    dimension::Int
    wigner_type::Symbol
    wigner_indicator::Float64
    constituent_multiplicities::Vector{Int}
end

"""Fail-closed enumeration of magnetic corepresentations from unitary irreps."""
struct ProjectionMagneticCorepresentationEnumeration
    corepresentations::Vector{ProjectionMagneticCorepresentation}
    complete::Bool
    uncertain::Bool
    diagnostics::Vector{String}
end

"""Integer (co)representation content of one verified matrix action."""
struct ProjectionRepresentationActionDecomposition
    labels::Vector{String}
    dimensions::Vector{Int}
    wigner_types::Vector{Symbol}
    multiplicities::Vector{Int}
    maximum_group_law_residual::Float64
    maximum_unitarity_residual::Float64
    complete::Bool
    uncertain::Bool
    diagnostics::Vector{String}
end

# Locate a unitary operation's character position in one irrep record.
function _projection_irrep_character_index(irrep::ProjectionProjectiveIrrep, unitary_position::Int)
    return findfirst(==(unitary_position), irrep.unitary_positions)
end

# Transform one unitary projective character through an antiunitary coset representative.
function _projection_antiunitary_transformed_character(
    algebra::ProjectionLittleGroupAlgebra,
    irrep::ProjectionProjectiveIrrep,
    antiunitary_position::Int,
)
    antiunitary_inverse = algebra.inverse_positions[antiunitary_position]
    antiunitary_inverse > 0 || return nothing, "antiunitary representative has no inverse"
    output = zeros(ComplexF64, length(algebra.unitary_positions))
    for (unitary_index, unitary_position) in enumerate(algebra.unitary_positions)
        left_product = algebra.product_positions[antiunitary_inverse, unitary_position]
        conjugated_position = algebra.product_positions[left_product, antiunitary_position]
        source_character_index = _projection_irrep_character_index(irrep, conjugated_position)
        source_character_index === nothing &&
            return nothing, "antiunitary conjugation leaves the unitary subgroup"
        anti_source = algebra.product_positions[antiunitary_position, conjugated_position]
        beta =
            algebra.factor_system[antiunitary_position, conjugated_position] *
            algebra.factor_system[anti_source, antiunitary_inverse] /
            algebra.factor_system[antiunitary_position, antiunitary_inverse]
        abs(beta) > 0.0 || return nothing, "antiunitary character transform has zero factor"
        output[unitary_index] = conj(irrep.characters[something(source_character_index)]) / beta
    end
    return output, ""
end

# Evaluate the projective Herring-Wigner indicator over the antiunitary coset.
function _projection_wigner_indicator(
    algebra::ProjectionLittleGroupAlgebra,
    irrep::ProjectionProjectiveIrrep,
)
    isempty(algebra.antiunitary_positions) && return 1.0 + 0.0im
    total = 0.0 + 0.0im
    for antiunitary_position in algebra.antiunitary_positions
        square_position = algebra.product_positions[antiunitary_position, antiunitary_position]
        character_index = _projection_irrep_character_index(irrep, square_position)
        character_index === nothing && return ComplexF64(NaN, NaN)
        total +=
            algebra.factor_system[antiunitary_position, antiunitary_position] *
            irrep.characters[something(character_index)]
    end
    return total / length(algebra.unitary_positions)
end

"""
    _enumerate_magnetic_corepresentations(algebra, irrep_enumeration; tolerance=1e-8)

Classify Type-I unitary blocks or Type-II--IV Wigner corepresentations.  For an
antiunitary coset, inequivalent conjugate irreps form type `:c`; a self-paired
irrep uses the projective Herring indicator to distinguish type `:a` from the
Kramers-doubled type `:b`.  Failure to identify a unique partner or an exact
indicator is numerical uncertainty, never a guessed label.
"""
function _enumerate_magnetic_corepresentations(
    algebra::ProjectionLittleGroupAlgebra,
    irrep_enumeration::ProjectionProjectiveIrrepEnumeration;
    tolerance::Real = 1.0e-8,
)
    tolerance_value = Float64(tolerance)
    isfinite(tolerance_value) && tolerance_value > 0.0 ||
        throw(ArgumentError("corepresentation tolerance must be positive and finite"))
    diagnostics = vcat(algebra.diagnostics, irrep_enumeration.diagnostics)
    if !algebra.complete || !irrep_enumeration.complete
        push!(diagnostics, "corepresentation enumeration requires a complete unitary irrep set")
        return ProjectionMagneticCorepresentationEnumeration(
            ProjectionMagneticCorepresentation[],
            false,
            true,
            diagnostics,
        )
    end
    irreps = irrep_enumeration.irreps
    if isempty(algebra.antiunitary_positions)
        corepresentations = [
            ProjectionMagneticCorepresentation(
                "corep_$(lpad(index, 3, '0'))_unitary",
                irrep.dimension,
                :unitary,
                1.0,
                [candidate == index ? 1 : 0 for candidate in eachindex(irreps)],
            ) for (index, irrep) in enumerate(irreps)
        ]
        return ProjectionMagneticCorepresentationEnumeration(
            corepresentations,
            true,
            false,
            String[],
        )
    end
    length(algebra.antiunitary_positions) == length(algebra.unitary_positions) || push!(
        diagnostics,
        "antiunitary inventory is not one complete coset of the unitary subgroup",
    )
    isempty(diagnostics) || return ProjectionMagneticCorepresentationEnumeration(
        ProjectionMagneticCorepresentation[],
        false,
        true,
        diagnostics,
    )

    representative = first(algebra.antiunitary_positions)
    partners = zeros(Int, length(irreps))
    indicators = fill(NaN, length(irreps))
    for (irrep_index, irrep) in enumerate(irreps)
        transformed, transform_error =
            _projection_antiunitary_transformed_character(algebra, irrep, representative)
        if transformed === nothing
            push!(diagnostics, transform_error)
            continue
        end
        matches = findall(eachindex(irreps)) do candidate_index
            candidate = irreps[candidate_index]
            candidate.dimension == irrep.dimension &&
                maximum(abs, candidate.characters - something(transformed)) <= tolerance_value
        end
        if length(matches) == 1
            partners[irrep_index] = only(matches)
        else
            push!(
                diagnostics,
                "irrep $(irrep.label) has $(length(matches)) antiunitary conjugate partners",
            )
        end
        indicator = _projection_wigner_indicator(algebra, irrep)
        if isfinite(real(indicator)) && abs(imag(indicator)) <= tolerance_value
            indicators[irrep_index] = real(indicator)
        else
            push!(diagnostics, "irrep $(irrep.label) has a non-real Wigner indicator")
        end
    end
    for irrep_index in eachindex(irreps)
        partner = partners[irrep_index]
        partner > 0 && partners[partner] == irrep_index || push!(
            diagnostics,
            "antiunitary irrep pairing is not involutive at $(irreps[irrep_index].label)",
        )
    end
    isempty(diagnostics) || return ProjectionMagneticCorepresentationEnumeration(
        ProjectionMagneticCorepresentation[],
        false,
        true,
        diagnostics,
    )

    corepresentations = ProjectionMagneticCorepresentation[]
    consumed = falses(length(irreps))
    for irrep_index in eachindex(irreps)
        consumed[irrep_index] && continue
        irrep = irreps[irrep_index]
        partner = partners[irrep_index]
        constituent_multiplicities = zeros(Int, length(irreps))
        wigner_type = :c
        dimension = 2irrep.dimension
        indicator = indicators[irrep_index]
        if partner != irrep_index
            abs(indicator) <= tolerance_value || push!(
                diagnostics,
                "paired irrep $(irrep.label) has nonzero Wigner indicator $(indicator)",
            )
            constituent_multiplicities[irrep_index] = 1
            constituent_multiplicities[partner] = 1
            consumed[irrep_index] = true
            consumed[partner] = true
        else
            nearest = abs(indicator - 1.0) <= abs(indicator + 1.0) ? 1.0 : -1.0
            abs(indicator - nearest) <= tolerance_value || push!(
                diagnostics,
                "self-paired irrep $(irrep.label) has nonintegral Wigner indicator $(indicator)",
            )
            if nearest > 0.0
                wigner_type = :a
                dimension = irrep.dimension
                constituent_multiplicities[irrep_index] = 1
            else
                wigner_type = :b
                dimension = 2irrep.dimension
                constituent_multiplicities[irrep_index] = 2
            end
            consumed[irrep_index] = true
        end
        push!(
            corepresentations,
            ProjectionMagneticCorepresentation(
                "corep_$(lpad(length(corepresentations) + 1, 3, '0'))_$(wigner_type)",
                dimension,
                wigner_type,
                indicator,
                constituent_multiplicities,
            ),
        )
    end
    complete = isempty(diagnostics) && all(consumed)
    return ProjectionMagneticCorepresentationEnumeration(
        complete ? corepresentations : ProjectionMagneticCorepresentation[],
        complete,
        !complete,
        diagnostics,
    )
end

# Convert a matrix vector or rank-three array to one owned action matrix per operation.
function _projection_normalize_actions(actions, expected_count::Int)
    values = if actions isa AbstractArray && ndims(actions) == 3
        [Matrix{ComplexF64}(@view actions[:, :, index]) for index in axes(actions, 3)]
    else
        [Matrix{ComplexF64}(action) for action in actions]
    end
    length(values) == expected_count ||
        throw(ArgumentError("representation action count disagrees with the little group"))
    isempty(values) && throw(ArgumentError("representation actions must not be empty"))
    dimension = size(first(values), 1)
    dimension > 0 || throw(ArgumentError("representation actions must have positive dimension"))
    all(matrix -> size(matrix) == (dimension, dimension), values) ||
        throw(ArgumentError("representation actions must be square with one common dimension"))
    all(matrix -> all(isfinite, matrix), values) ||
        throw(ArgumentError("representation actions contain non-finite values"))
    return values
end

# Validate unitarity and the same semilinear factor system used by the little group.
function _projection_action_residuals(
    algebra::ProjectionLittleGroupAlgebra,
    actions::Vector{Matrix{ComplexF64}},
)
    dimension = size(first(actions), 1)
    identity_matrix = Matrix{ComplexF64}(I, dimension, dimension)
    maximum_unitarity =
        maximum(maximum(abs, action' * action - identity_matrix) for action in actions)
    maximum_group_law = 0.0
    for left_position in eachindex(actions), right_position in eachindex(actions)
        product_position = algebra.product_positions[left_position, right_position]
        product_position > 0 || return Inf, maximum_unitarity
        right_action = actions[right_position]
        left_operation_antiunitary = left_position in algebra.antiunitary_positions
        left_operation_antiunitary && (right_action = conj(right_action))
        residual = maximum(
            abs,
            actions[left_position] * right_action -
            algebra.factor_system[left_position, right_position] .* actions[product_position],
        )
        maximum_group_law = max(maximum_group_law, residual)
    end
    return maximum_group_law, maximum_unitarity
end

"""
    _decompose_representation_actions(algebra, actions, irreps, coreps; tolerance=1e-8)

Decompose a verified matrix action into the canonical irrep/corep order.  Only
unitary characters enter the multiplicity formula; antiunitary matrices are
used exclusively in the semilinear group-law validation and Wigner inventory.
"""
function _decompose_representation_actions(
    algebra::ProjectionLittleGroupAlgebra,
    actions,
    irrep_enumeration::ProjectionProjectiveIrrepEnumeration,
    corep_enumeration::ProjectionMagneticCorepresentationEnumeration;
    tolerance::Real = 1.0e-8,
)
    tolerance_value = Float64(tolerance)
    isfinite(tolerance_value) && tolerance_value > 0.0 ||
        throw(ArgumentError("decomposition tolerance must be positive and finite"))
    diagnostics =
        vcat(algebra.diagnostics, irrep_enumeration.diagnostics, corep_enumeration.diagnostics)
    if !algebra.complete || !irrep_enumeration.complete || !corep_enumeration.complete
        push!(diagnostics, "action decomposition requires complete algebra and (co)irreps")
        return ProjectionRepresentationActionDecomposition(
            String[],
            Int[],
            Symbol[],
            Int[],
            Inf,
            Inf,
            false,
            true,
            diagnostics,
        )
    end
    action_values = _projection_normalize_actions(actions, length(algebra.operation_indices))
    maximum_group_law, maximum_unitarity = _projection_action_residuals(algebra, action_values)
    if maximum_group_law > tolerance_value
        push!(
            diagnostics,
            "matrix action fails the semilinear group law; residual=$(maximum_group_law)",
        )
    end
    if maximum_unitarity > tolerance_value
        push!(diagnostics, "matrix action is nonunitary; residual=$(maximum_unitarity)")
    end

    unitary_order = length(algebra.unitary_positions)
    irrep_multiplicities = zeros(Int, length(irrep_enumeration.irreps))
    for (irrep_index, irrep) in enumerate(irrep_enumeration.irreps)
        multiplicity =
            sum(eachindex(algebra.unitary_positions)) do unitary_index
                position = algebra.unitary_positions[unitary_index]
                conj(irrep.characters[unitary_index]) * tr(action_values[position])
            end / unitary_order
        nearest = round(Int, real(multiplicity))
        if abs(imag(multiplicity)) > tolerance_value ||
           abs(real(multiplicity) - nearest) > tolerance_value ||
           nearest < 0
            push!(diagnostics, "irrep $(irrep.label) has noninteger multiplicity $(multiplicity)")
        else
            irrep_multiplicities[irrep_index] = nearest
        end
    end

    corepresentations = corep_enumeration.corepresentations
    multiplicities = zeros(Int, length(corepresentations))
    reconstructed_constituents = zeros(Int, length(irrep_multiplicities))
    for (corep_index, corep) in enumerate(corepresentations)
        support = findall(>(0), corep.constituent_multiplicities)
        isempty(support) && begin
            push!(diagnostics, "corepresentation $(corep.label) has empty unitary support")
            continue
        end
        ratios = [
            irrep_multiplicities[index] / corep.constituent_multiplicities[index] for
            index in support
        ]
        nearest = round(Int, first(ratios))
        if nearest < 0 || any(abs(ratio - nearest) > tolerance_value for ratio in ratios)
            push!(
                diagnostics,
                "unitary restriction is inconsistent with corepresentation $(corep.label)",
            )
            continue
        end
        multiplicities[corep_index] = nearest
        reconstructed_constituents .+= nearest .* corep.constituent_multiplicities
    end
    reconstructed_constituents == irrep_multiplicities || push!(
        diagnostics,
        "corepresentation restriction does not reconstruct all unitary multiplicities",
    )
    action_dimension = size(first(action_values), 1)
    reconstructed_dimension = sum(
        multiplicity * corep.dimension for
        (multiplicity, corep) in zip(multiplicities, corepresentations)
    )
    reconstructed_dimension == action_dimension || push!(
        diagnostics,
        "(co)representation dimensions reconstruct $(reconstructed_dimension), expected $(action_dimension)",
    )
    complete =
        isempty(diagnostics) &&
        maximum_group_law <= tolerance_value &&
        maximum_unitarity <= tolerance_value
    return ProjectionRepresentationActionDecomposition(
        getfield.(corepresentations, :label),
        getfield.(corepresentations, :dimension),
        getfield.(corepresentations, :wigner_type),
        multiplicities,
        maximum_group_law,
        maximum_unitarity,
        complete,
        !complete,
        diagnostics,
    )
end

"""
    _decompose_band_subspace(representation, algebra, mask, irreps, coreps; tolerance=1e-8)

Restrict the stored sewing action to one little-group-invariant band mask and
decompose it through `_decompose_representation_actions`.  Leakage between the
selected block and its complement is a hard, fail-closed error.
"""
function _decompose_band_subspace(
    representation::BandRepresentation,
    algebra::ProjectionLittleGroupAlgebra,
    mask,
    irrep_enumeration::ProjectionProjectiveIrrepEnumeration,
    corep_enumeration::ProjectionMagneticCorepresentationEnumeration;
    tolerance::Real = 1.0e-8,
)
    tolerance_value = Float64(tolerance)
    num_bands = size(representation.energies_ev, 1)
    selected_mask = if mask isa AbstractVector{Bool}
        length(mask) == num_bands || throw(ArgumentError("band mask has an incompatible length"))
        BitVector(mask)
    else
        selected = Int.(mask)
        all(index -> 1 <= index <= num_bands, selected) ||
            throw(ArgumentError("band mask contains an out-of-range index"))
        value = falses(num_bands)
        value[selected] .= true
        value
    end
    selected_indices = findall(selected_mask)
    isempty(selected_indices) &&
        throw(ArgumentError("band subspace must contain at least one band"))
    complement_indices = findall(.!selected_mask)
    actions = Matrix{ComplexF64}[]
    maximum_leakage = 0.0
    for operation_index in algebra.operation_indices
        sewing = @view representation.sewing_matrices[:, :, operation_index, algebra.kpoint_index]
        push!(actions, Matrix(sewing[selected_indices, selected_indices]))
        if !isempty(complement_indices)
            maximum_leakage = max(
                maximum_leakage,
                maximum(abs, sewing[complement_indices, selected_indices]),
                maximum(abs, sewing[selected_indices, complement_indices]),
            )
        end
    end
    decomposition = _decompose_representation_actions(
        algebra,
        actions,
        irrep_enumeration,
        corep_enumeration;
        tolerance = tolerance_value,
    )
    maximum_leakage <= tolerance_value && return decomposition
    diagnostics = copy(decomposition.diagnostics)
    push!(diagnostics, "band mask is not little-group invariant; leakage=$(maximum_leakage)")
    return ProjectionRepresentationActionDecomposition(
        decomposition.labels,
        decomposition.dimensions,
        decomposition.wigner_types,
        decomposition.multiplicities,
        decomposition.maximum_group_law_residual,
        decomposition.maximum_unitarity_residual,
        false,
        true,
        diagnostics,
    )
end
