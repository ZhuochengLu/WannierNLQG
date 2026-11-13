"""Lifetime of one owned scientific payload; the label is not a content certificate.

Owners adopt their input values once. Direct mutation of an adopted payload is
unsupported: invalidate its owner and construct a replacement before reuse.
"""
mutable struct ScientificDataOwner
    generation::String
    live::Bool
end

const SCIENTIFIC_DATA_GENERATION_COUNTER = Threads.Atomic{UInt64}(0)

"""Create a process-local lifetime label without visiting scientific arrays."""
function ScientificDataOwner()
    serial = Threads.atomic_add!(SCIENTIFIC_DATA_GENERATION_COUNTER, UInt64(1))
    return ScientificDataOwner(
        string("wanniernlqg.owned-data/1:", getpid(), ':', time_ns(), ':', serial),
        true,
    )
end

"""Reject use after explicit invalidation, including a retained numerical cache."""
function scientific_data_generation(owner::ScientificDataOwner)
    owner.live || throw(ArgumentError("Scientific data owner has been invalidated"))
    return owner.generation
end

"""Retire an owned payload before replacing it; no cached consumer may revive it."""
function invalidate_scientific_data!(owner::ScientificDataOwner)
    owner.live = false
    return nothing
end
