# Expert-only operation-scope ablations.  These routines derive a complete,
# internally consistent BandRepresentation instead of leaving excluded magnetic
# operations reachable through the parent's full_to_operation map.

"""Return the unique structural identity operation in one representation."""
function _constraint_identity_operation_index(representation::BandRepresentation)
    identity_rotation = Matrix{Int}(I, 3, 3)
    identity_cartesian = Matrix{Float64}(I, 3, 3)
    nk = size(representation.kpoint_map, 2)
    candidates = Int[]
    for (index, operation) in enumerate(representation.operations)
        operation.antiunitary && continue
        operation.rotation_fractional == identity_rotation || continue
        maximum(abs, operation.translation_fractional; init = 0.0) <= 1.0e-12 || continue
        maximum(abs, operation.rotation_cartesian - identity_cartesian; init = 0.0) <= 1.0e-10 ||
            continue
        all(@view(representation.kpoint_map[index, :]) .== collect(1:nk)) || continue
        push!(candidates, index)
    end
    length(candidates) == 1 || throw(
        ArgumentError(
            "CONSTRAINT_SCOPE_IDENTITY_INVALID: expected one structural identity, found $(length(candidates))",
        ),
    )
    return only(candidates)
end

"""Fail closed unless selected k-point maps form a subgroup action."""
function _validate_constraint_kpoint_subgroup(mapping::Matrix{Int})
    ng, nk = size(mapping)
    ng > 0 && nk > 0 || throw(ArgumentError("constraint subgroup must be nonempty"))
    # Each key privately owns its ordered action and is never mutated. Use
    # ordinary Dict equality rather than a digest; large meshes must not create
    # enormous specialized tuple types merely to validate subgroup membership.
    rows = Dict{Vector{Int}, Int}()
    for operation in 1:ng
        key = collect(@view mapping[operation, :])
        haskey(rows, key) &&
            throw(ArgumentError("CONSTRAINT_SCOPE_SUBGROUP_INVALID: duplicate k-point action"))
        rows[key] = operation
    end
    for left in 1:ng, right in 1:ng
        composition = [mapping[left, mapping[right, kpoint]] for kpoint in 1:nk]
        haskey(rows, composition) || throw(
            ArgumentError(
                "CONSTRAINT_SCOPE_SUBGROUP_INVALID: selected k-point actions are not closed",
            ),
        )
    end
    return nothing
end

"""Rebuild deterministic IBZ representatives and expansion operations."""
function _constraint_subgroup_orbits(mapping::Matrix{Int})
    ng, nk = size(mapping)
    visited = falses(nk)
    irreducible = Int[]
    full_to_irreducible = zeros(Int, nk)
    full_to_operation = zeros(Int, nk)
    for seed in 1:nk
        visited[seed] && continue
        orbit = sort!(unique(Int.(mapping[:, seed])))
        representative = first(orbit)
        orbit_set = Set(orbit)
        for kpoint in orbit
            Set(Int.(mapping[:, kpoint])) == orbit_set || throw(
                ArgumentError(
                    "CONSTRAINT_SCOPE_ORBIT_INVALID: selected operations do not preserve a k-star",
                ),
            )
        end
        push!(irreducible, representative)
        local_index = length(irreducible)
        for kpoint in orbit
            operation = findfirst(==(kpoint), @view mapping[:, representative])
            operation === nothing && throw(
                ArgumentError(
                    "CONSTRAINT_SCOPE_ORBIT_INVALID: no selected operation expands representative $(representative) to k-point $(kpoint)",
                ),
            )
            visited[kpoint] = true
            full_to_irreducible[kpoint] = local_index
            full_to_operation[kpoint] = something(operation)
        end
    end
    all(visited) || throw(ArgumentError("constraint subgroup did not cover the full k mesh"))
    return irreducible, full_to_irreducible, full_to_operation
end

"""
Derive the full, unitary-only, or identity operation representation.

The `:full` branch returns the exact parent object so the default numerical
trajectory remains elementwise unchanged.  The other branches are immutable
diagnostic representations with explicit operation selections and k-star maps.
"""
function _constraint_scoped_representation(parent::BandRepresentation, scope::Symbol)
    scope in (:full, :unitary, :identity) ||
        throw(ArgumentError("unsupported constraint operation scope $(scope)"))
    if scope == :full
        return (
            representation = parent,
            parent_operation_indices = collect(eachindex(parent.operations)),
        )
    end
    selected = if scope == :unitary
        findall(operation -> !operation.antiunitary, parent.operations)
    else
        [_constraint_identity_operation_index(parent)]
    end
    isempty(selected) && throw(
        ArgumentError("CONSTRAINT_SCOPE_SUBGROUP_INVALID: no operations selected for $(scope)"),
    )
    mapping = Matrix{Int}(parent.kpoint_map[selected, :])
    _validate_constraint_kpoint_subgroup(mapping)
    irreducible, full_to_irreducible, full_to_operation = _constraint_subgroup_orbits(mapping)
    conventions = merge(
        parent.conventions,
        Dict(
            "constraint_operation_scope" => String(scope),
            "content_authentication" => "NOT_PERFORMED",
            "constraint_operation_parent_indices" => join(selected, ','),
            "qualification" => "diagnostic_symmetry_ablation",
        ),
    )
    representation = BandRepresentation(
        parent.schema_version,
        parent.source_code,
        parent.spinor,
        parent.real_lattice,
        parent.reciprocal_lattice,
        parent.mp_grid,
        parent.kpoints_fractional,
        parent.energies_ev,
        parent.operations[selected],
        mapping,
        parent.reciprocal_shifts[:, selected, :],
        parent.sewing_matrices[:, :, selected, :],
        parent.band_block_labels,
        irreducible,
        full_to_irreducible,
        full_to_operation;
        conventions,
        input_sha256 = Dict{String, String}(),
        input_definitions = parent.input_definitions,
    )
    return (representation, parent_operation_indices = selected)
end

"""Retarget a full-BZ fixed-subspace capsule to the effective subgroup IBZ."""
function _constraint_scoped_fixed_subspace(
    fixed::WannierizationFixedSubspace,
    scoped_representation::BandRepresentation,
    scope::Symbol,
)
    scope == :full && return fixed
    hashes = merge(
        fixed.source_sha256,
        Dict(
            "constraint_operation_scope" => String(scope),
            "constraint_operation_scope_history_reset" => "LEGACY_CONSTRAINT_SCOPE_RESET",
        ),
    )
    return WannierizationFixedSubspace(
        fixed.projectors,
        fixed.frames,
        scoped_representation.irreducible_indices,
        fixed.frozen_mask;
        source_sha256 = hashes,
        invariant_residuals = fixed.invariant_residuals,
    )
end

"""Select a true Seitz subgroup before native sewing and k-star construction.

Parent classified inventory remains provenance only. We do not pretend that a
selected subgroup inherits the parent's MSG/Hall/UNI classification. Existing
persistence represents unavailable subgroup classification explicitly.
"""
function _select_detected_operations(
    parent::SymmetryFoundation.MagneticSymmetryInventory,
    requested,
)
    requested === nothing && return (
        operations = parent.operations,
        inventory = parent,
        conventions = Dict{String, String}(),
    )
    indices = collect(requested)
    !isempty(indices) &&
    all(i -> i isa Integer && !(i isa Bool) && 1 <= i <= length(parent.operations), indices) ||
        throw(ArgumentError("operation selection indices are outside the detected inventory"))
    length(unique(indices)) == length(indices) ||
        throw(ArgumentError("duplicate operation selection"))
    operations = parent.operations[indices]
    # Validate translations modulo the lattice and antiunitary composition.
    # The helper's sorted return is deliberately not used: user order is bound.
    try
        records = [
            (
                rotation_fractional = op.rotation_fractional,
                translation_fractional = op.translation_fractional,
                antiunitary = op.antiunitary,
                source_index = indices[i],
            ) for (i, op) in enumerate(operations)
        ]
        SymmetryFoundation.finite_symmetry_group_tables(
            records;
            seitz = true,
            tolerance = parent.symmetry_tolerance,
        )
    catch error
        error isa ErrorException || rethrow()
        throw(
            ArgumentError(
                "selected operations do not form a Seitz subgroup: $(sprint(showerror,error))",
            ),
        )
    end
    keys = _canonical_operation_key.(parent.operations)
    conventions = Dict(
        "operation_selection_contract" => "detected-seitz-subgroup/2",
        "operation_selection_parent_indices" => join(indices, ','),
        "content_authentication" => "NOT_PERFORMED",
        "operation_selection_parent_operations" => repr(keys),
        "operation_selection_operations" => repr(keys[indices]),
        "operation_selection_parent_msg_type" => string(parent.msg_type),
        "operation_selection_parent_uni_number" => string(parent.uni_number),
        "operation_selection_parent_hall_number" => string(parent.hall_number),
        "operation_selection_parent_count" => string(length(parent.operations)),
        "operation_selection_unitary_count" => string(count(op -> !op.antiunitary, operations)),
        "operation_selection_antiunitary_count" =>
            string(count(op -> op.antiunitary, operations)),
        "operation_selection_classification" => "unclassified_subgroup",
    )
    return (operations, inventory = nothing, conventions)
end
