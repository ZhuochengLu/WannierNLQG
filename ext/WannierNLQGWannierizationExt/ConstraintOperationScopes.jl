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
    row_digest(values) = bytes2hex(SHA.sha256(reinterpret(UInt8, Int64.(collect(values)))))
    rows = Dict{String, Int}()
    for operation in 1:ng
        key = row_digest(@view mapping[operation, :])
        haskey(rows, key) &&
            throw(ArgumentError("CONSTRAINT_SCOPE_SUBGROUP_INVALID: duplicate k-point action"))
        rows[key] = operation
    end
    for left in 1:ng, right in 1:ng
        composition = [mapping[left, mapping[right, kpoint]] for kpoint in 1:nk]
        haskey(rows, row_digest(composition)) || throw(
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
diagnostic representations with independent operation and k-star digests.
"""
function _constraint_scoped_representation(parent::BandRepresentation, scope::Symbol)
    scope in (:full, :unitary, :identity) ||
        throw(ArgumentError("unsupported constraint operation scope $(scope)"))
    parent_sha256 = _representation_static_sha256(parent)
    if scope == :full
        return (
            representation = parent,
            parent_sha256,
            subgroup_sha256 = parent_sha256,
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
    operation_keys = [_canonical_operation_key(parent.operations[index]) for index in selected]
    subgroup_contract = join(
        [
            "parent=$(parent_sha256)",
            "scope=$(scope)",
            "indices=$(join(selected, ','))",
            operation_keys...,
        ],
        '\n',
    )
    subgroup_sha256 = bytes2hex(SHA.sha256(codeunits(subgroup_contract)))
    conventions = merge(
        parent.conventions,
        Dict(
            "constraint_operation_scope" => String(scope),
            "constraint_operation_parent_representation_sha256" => parent_sha256,
            "constraint_operation_subgroup_sha256" => subgroup_sha256,
            "constraint_operation_parent_indices" => join(selected, ','),
            "qualification" => "diagnostic_symmetry_ablation",
        ),
    )
    input_sha256 = merge(
        parent.input_sha256,
        Dict(
            "CONSTRAINT_OPERATION_PARENT_REPRESENTATION" => parent_sha256,
            "CONSTRAINT_OPERATION_SUBGROUP" => subgroup_sha256,
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
        input_sha256,
    )
    return (representation, parent_sha256, subgroup_sha256, parent_operation_indices = selected)
end

"""Retarget a full-BZ fixed-subspace capsule to the effective subgroup IBZ."""
function _constraint_scoped_fixed_subspace(
    fixed::WannierizationFixedSubspace,
    scoped_representation::BandRepresentation,
    parent_sha256::AbstractString,
    subgroup_sha256::AbstractString,
    scope::Symbol,
)
    scope == :full && return fixed
    hashes = merge(
        fixed.source_sha256,
        Dict(
            "constraint_operation_parent_representation_sha256" => String(parent_sha256),
            "constraint_operation_subgroup_sha256" => String(subgroup_sha256),
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
