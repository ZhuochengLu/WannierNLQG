"""Pinned package name for the projection-combination behavior profile."""
const PROJECTION_COMPATIBILITY_UPSTREAM_PACKAGE = "WannierBerri"

"""Pinned package release for the projection-combination behavior profile."""
const PROJECTION_COMPATIBILITY_UPSTREAM_VERSION = "1.7.0"

"""Pinned source revision for the projection-combination behavior profile."""
const PROJECTION_COMPATIBILITY_UPSTREAM_COMMIT = "50265d5d1cef184f8377f87ed691c8d9a2f6cdbf"

"""SHA-256 of the pinned upstream projection-search source file."""
const PROJECTION_COMPATIBILITY_UPSTREAM_SOURCE_SHA256 = "8552e056b568860c4c7dbd868e997fe4e9e6fb4a0349b182665aee2c8330d5c2"

"""Absolute tolerance applied to upstream-style character reductions."""
const PROJECTION_COMPATIBILITY_CHARACTER_TOLERANCE = 1.0e-3

"""Relative tolerance inherited from the pinned upstream `numpy.allclose` call."""
const PROJECTION_COMPATIBILITY_CHARACTER_RELATIVE_TOLERANCE = 1.0e-5

"""Decimal precision applied before taking the ceiling of band multiplicities."""
const PROJECTION_COMPATIBILITY_CHARACTER_ROUND_DIGITS = 3

"""Tolerance used to verify little-group actions in the spinless-unitary scope."""
const PROJECTION_COMPATIBILITY_LITTLE_GROUP_TOLERANCE = 1.0e-5

# Return whether the representation lies in the nonmagnetic spinless compatibility scope.
function _projection_representation_spinless_unitary_scope(representation::BandRepresentation)
    magnetic_structure =
        lowercase(strip(get(representation.conventions, "magnetic_structure", "false"))) == "true"
    return !representation.spinor &&
           !magnetic_structure &&
           all(operation -> !operation.antiunitary, representation.operations)
end

# Describe the pinned upstream behavior and whether it applies to this representation.
function _projection_representation_compatibility_info(representation::BandRepresentation)
    parity_eligible = _projection_representation_spinless_unitary_scope(representation)
    scope = parity_eligible ? :spinless_unitary : :generalized_symmetry
    return ProjectionRepresentationCompatibilityInfo(
        PROJECTION_COMPATIBILITY_UPSTREAM_PACKAGE,
        PROJECTION_COMPATIBILITY_UPSTREAM_VERSION,
        PROJECTION_COMPATIBILITY_UPSTREAM_COMMIT,
        PROJECTION_COMPATIBILITY_UPSTREAM_SOURCE_SHA256,
        parity_eligible,
        scope,
        PROJECTION_COMPATIBILITY_CHARACTER_TOLERANCE,
        PROJECTION_COMPATIBILITY_CHARACTER_ROUND_DIGITS,
        PROJECTION_COMPATIBILITY_LITTLE_GROUP_TOLERANCE,
    )
end

"""
    _projection_compatibility_reduce_characters(
        action_characters,
        irrep_enumeration;
        source,
    )

Reduce unitary little-group characters in the fixed canonical irrep order.
Band-subspace multiplicities use `ceil(round(real(value); digits=3))` after the
imaginary-part gate. Candidate multiplicities reproduce the pinned source's
`numpy.allclose(round(value), value, atol=1e-3)` call, including its implicit
`rtol=1e-5`. The result carries raw complex multiplicities so callers can audit
every rounding decision.
"""
function _projection_compatibility_reduce_characters(
    action_characters,
    irrep_enumeration::ProjectionProjectiveIrrepEnumeration;
    source::Symbol,
)
    source in (:band_subspace, :candidate) ||
        throw(ArgumentError("character-reduction source must be :band_subspace or :candidate"))
    irreps = irrep_enumeration.irreps
    characters = ComplexF64.(action_characters)
    unitary_order = length(characters)
    unitary_order > 0 || throw(ArgumentError("action character inventory must not be empty"))
    all(isfinite, characters) ||
        throw(ArgumentError("action character inventory contains non-finite values"))
    all(length(irrep.characters) == unitary_order for irrep in irreps) ||
        throw(DimensionMismatch("action and irreducible character inventories disagree"))

    raw_multiplicities =
        ComplexF64[sum(conj.(irrep.characters) .* characters) / unitary_order for irrep in irreps]
    multiplicities = zeros(Int, length(raw_multiplicities))
    diagnostics = String[]
    tolerance = PROJECTION_COMPATIBILITY_CHARACTER_TOLERANCE
    relative_tolerance = PROJECTION_COMPATIBILITY_CHARACTER_RELATIVE_TOLERANCE
    digits = PROJECTION_COMPATIBILITY_CHARACTER_ROUND_DIGITS
    for (index, value) in enumerate(raw_multiplicities)
        irrep = irreps[index]
        if abs(imag(value)) > tolerance
            push!(
                diagnostics,
                "irrep $(irrep.label) has character multiplicity with imaginary part $(imag(value))",
            )
            continue
        end
        multiplicity = if source == :band_subspace
            ceil(Int, round(real(value); digits = digits))
        else
            nearest = round(Int, real(value))
            integer_tolerance = tolerance + relative_tolerance * abs(value)
            if abs(real(value) - nearest) > integer_tolerance
                push!(
                    diagnostics,
                    "irrep $(irrep.label) has noninteger candidate multiplicity $(real(value))",
                )
                continue
            end
            nearest
        end
        if multiplicity < 0
            push!(diagnostics, "irrep $(irrep.label) has negative multiplicity $(multiplicity)")
            continue
        end
        multiplicities[index] = multiplicity
    end
    complete = irrep_enumeration.complete && !irrep_enumeration.uncertain && isempty(diagnostics)
    return (
        multiplicities,
        raw_multiplicities,
        complete,
        uncertain = !complete,
        diagnostics = unique(vcat(irrep_enumeration.diagnostics, diagnostics)),
    )
end

"""
    _projection_compatibility_decompose_actions(algebra, actions, irreps; source)

Validate a spinless unitary little-group action and reduce its characters with
the pinned compatibility rules. This helper returns the existing action
decomposition DTO so native and extended search paths share one downstream
integer-search interface.
"""
function _projection_compatibility_decompose_actions(
    algebra::ProjectionLittleGroupAlgebra,
    actions,
    irrep_enumeration::ProjectionProjectiveIrrepEnumeration;
    source::Symbol,
)
    labels = getfield.(irrep_enumeration.irreps, :label)
    dimensions = getfield.(irrep_enumeration.irreps, :dimension)
    wigner_types = fill(:unitary, length(labels))
    diagnostics = vcat(algebra.diagnostics, irrep_enumeration.diagnostics)
    if !algebra.complete ||
       algebra.uncertain ||
       !irrep_enumeration.complete ||
       irrep_enumeration.uncertain
        push!(diagnostics, "compatibility decomposition requires complete little-group data")
        return ProjectionRepresentationActionDecomposition(
            labels,
            dimensions,
            wigner_types,
            zeros(Int, length(labels)),
            Inf,
            Inf,
            false,
            true,
            unique(diagnostics),
        )
    end
    if !isempty(algebra.antiunitary_positions)
        push!(diagnostics, "compatibility decomposition requires a unitary little group")
        return ProjectionRepresentationActionDecomposition(
            labels,
            dimensions,
            wigner_types,
            zeros(Int, length(labels)),
            Inf,
            Inf,
            false,
            true,
            unique(diagnostics),
        )
    end

    action_values = _projection_normalize_actions(actions, length(algebra.operation_indices))
    maximum_group_law, maximum_unitarity = _projection_action_residuals(algebra, action_values)
    tolerance = PROJECTION_COMPATIBILITY_LITTLE_GROUP_TOLERANCE
    maximum_group_law <= tolerance || push!(
        diagnostics,
        "matrix action fails the unitary group law; residual=$(maximum_group_law)",
    )
    maximum_unitarity <= tolerance ||
        push!(diagnostics, "matrix action is nonunitary; residual=$(maximum_unitarity)")
    action_characters =
        ComplexF64[tr(action_values[position]) for position in algebra.unitary_positions]
    reduction =
        _projection_compatibility_reduce_characters(action_characters, irrep_enumeration; source)
    append!(diagnostics, reduction.diagnostics)

    if source == :candidate
        action_dimension = size(first(action_values), 1)
        reconstructed_dimension = sum(reduction.multiplicities .* dimensions)
        reconstructed_dimension == action_dimension || push!(
            diagnostics,
            "candidate characters reconstruct dimension $(reconstructed_dimension), expected $(action_dimension)",
        )
    end
    complete =
        isempty(diagnostics) &&
        reduction.complete &&
        maximum_group_law <= tolerance &&
        maximum_unitarity <= tolerance
    return ProjectionRepresentationActionDecomposition(
        labels,
        dimensions,
        wigner_types,
        reduction.multiplicities,
        maximum_group_law,
        maximum_unitarity,
        complete,
        !complete,
        unique(diagnostics),
    )
end

"""
    _projection_compatibility_decompose_band_subspace(
        representation,
        algebra,
        mask,
        irreps,
    )

Restrict the stored sewing action to a little-group-invariant band mask and
apply the pinned band-character rounding rule. Leakage outside the mask fails
closed before the multiplicities may qualify a search problem.
"""
function _projection_compatibility_decompose_band_subspace(
    representation::BandRepresentation,
    algebra::ProjectionLittleGroupAlgebra,
    mask,
    irrep_enumeration::ProjectionProjectiveIrrepEnumeration,
)
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
    decomposition = _projection_compatibility_decompose_actions(
        algebra,
        actions,
        irrep_enumeration;
        source = :band_subspace,
    )
    tolerance = PROJECTION_COMPATIBILITY_LITTLE_GROUP_TOLERANCE
    maximum_leakage <= tolerance && return decomposition
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
        unique(diagnostics),
    )
end

# Return the zero frozen signature on the canonical native irrep axis.
function _projection_compatibility_empty_decomposition(
    irrep_enumeration::ProjectionProjectiveIrrepEnumeration,
)
    irreps = irrep_enumeration.irreps
    complete = irrep_enumeration.complete && !irrep_enumeration.uncertain
    return ProjectionRepresentationActionDecomposition(
        getfield.(irreps, :label),
        getfield.(irreps, :dimension),
        fill(:unitary, length(irreps)),
        zeros(Int, length(irreps)),
        0.0,
        0.0,
        complete,
        !complete,
        copy(irrep_enumeration.diagnostics),
    )
end
