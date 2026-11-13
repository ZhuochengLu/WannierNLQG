module CurrentScientificValues
using WannierNLQG

# Test-only value witnesses, never an artifact credential or a Runtime path.
# Provider arrays are consumed as arrays; their caches, filenames and closures
# are not a mathematical value and are not recursively inspected.
function plain(value)
    if value isa Union{Number, AbstractString, Symbol, Nothing, Bool}
        return value
    elseif value isa AbstractArray
        return (shape = size(value), values = [plain(x) for x in value])
    elseif value isa AbstractDict
        return [(plain(k), plain(value[k])) for k in sort!(collect(keys(value)); by = repr)]
    elseif value isa Union{Tuple, NamedTuple}
        return map(plain, Tuple(value))
    elseif value isa Function
        error("A provider function is not a scientific comparison value")
    end
    return [
        (String(name), plain(getfield(value, name))) for
        name in fieldnames(typeof(value)) if name != :filename
    ]
end

function value_definition(value)
    buffer = IOBuffer()
    WannierNLQG.IO.write_native_definition_value(buffer, plain(value))
    return bytes2hex(take!(buffer))
end

function payload_values(payload; schema_version = nothing, contract_version = nothing)
    # Wire versions are checked by the actual reader/writer. This witness tests
    # decoded current numerical values, not retired versioned authentication.
    native = payload.native
    values = (
        native = (
            native.mp_grid,
            native.spinor,
            native.reciprocal_lattice,
            [plain(point) for point in native.kpoints],
        ),
        operations = plain(payload.operations),
        topology = (
            payload.kpoint_map,
            payload.reciprocal_shifts,
            payload.representative_for_kpoint,
            payload.canonical_operation_for_kpoint,
            payload.star_representatives,
            payload.extra_bands_per_star,
        ),
        rotations = payload.rotations,
        ranges = (payload.target_band_range, payload.parent_band_range),
        scope = plain(payload.qualification_scope),
        audit = plain(payload.symmetrized_hamiltonian_audit),
        corrections = payload.sealed_completed_frame_corrections,
    )
    return value_definition(values)
end
end
