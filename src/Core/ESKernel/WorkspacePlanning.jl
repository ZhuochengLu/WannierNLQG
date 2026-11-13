module WorkspacePlanning

export checked_array_bytes, checked_sum_bytes, workspace_envelope, batch_capacity
export contiguous_range, cyclic_range, partition_count

# Validate explicit dimension and byte counts without accepting Bool controls.
function nonnegative_count(value::Integer)
    !(value isa Bool) && value>=0 || throw(ArgumentError("Nonnegative integer count required"))
    Int(value)
end

"""Compute array storage bytes with overflow rejection, including empty arrays.

Only the supplied element storage and dimensions are counted. Object headers,
native resources, replicas and simultaneously live scratch remain explicit
caller-provided budget items; this estimate is not an RSS admission guard.
"""
function checked_array_bytes(::Type{T}, dimensions::Tuple) where {T}
    isbitstype(T) || throw(ArgumentError("Concrete isbits element storage required"))
    count = 1
    for dimension in dimensions
        dimension isa Integer || throw(ArgumentError("Integer array dimensions required"))
        count = Base.checked_mul(count, nonnegative_count(dimension))
    end
    Base.checked_mul(count, sizeof(T))
end

"""Sum simultaneously live storage items with overflow and negative-count rejection."""
function checked_sum_bytes(items)
    total = 0
    for item in items
        item isa Integer || throw(ArgumentError("Integer storage bytes required"))
        total = Base.checked_add(total, nonnegative_count(item))
    end
    total
end

"""Check retained plus scratch storage against an explicit byte limit.

Returns a descriptive estimate only, not a process reservation. Unknown native
storage is recorded explicitly and must still be covered by the caller's RSS
guard. Inputs are not mutated and no allocation or host probe is performed here.
"""
function workspace_envelope(
    retained,
    scratch;
    limit_bytes::Integer,
    native_bytes_known::Bool = false,
)
    retained_bytes = checked_sum_bytes(retained)
    scratch_bytes = checked_sum_bytes(scratch)
    total_bytes = checked_sum_bytes((retained_bytes, scratch_bytes))
    total_bytes<=nonnegative_count(limit_bytes) ||
        throw(ArgumentError("Simultaneously live workspace exceeds explicit byte limit"))
    (; retained_bytes, scratch_bytes, total_bytes, native_bytes_known)
end

"""Return bounded item capacity after explicit fixed overhead and per-item storage.

No physical shape or batching policy is inferred. A zero capacity requests the
caller's existing fallback; it never authorizes a different numerical algorithm.
"""
function batch_capacity(
    items::Integer,
    per_item_bytes::Integer,
    overhead_bytes::Integer,
    limit_bytes::Integer,
)
    n=nonnegative_count(items);
    cost=nonnegative_count(per_item_bytes)
    overhead=nonnegative_count(overhead_bytes);
    limit=nonnegative_count(limit_bytes)
    min(n, max(0, limit-overhead)÷max(1, cost))
end

# Validate the caller's zero-based owner coordinate without querying MPI.
function partition_arguments(count::Integer, rank::Integer, ranks::Integer)
    n=nonnegative_count(count)
    !(rank isa Bool) && !(ranks isa Bool) && ranks>0 && 0<=rank<ranks ||
        throw(ArgumentError("Valid zero-based rank and positive rank count required"))
    n, Int(rank), Int(ranks)
end

"""Return the exact floor-boundary contiguous partition, including empty owners.

Global IDs are one based; rank is zero based. The boundaries are
floor(n*rank/ranks)+1 : floor(n*(rank+1)/ranks), preserving the original LO
ownership rather than assigning the remainder to the earliest ranks.
"""
function contiguous_range(count::Integer, rank::Integer, ranks::Integer)
    n, r, p=partition_arguments(count, rank, ranks)
    (fld(Base.checked_mul(n, r), p) + 1):fld(Base.checked_mul(n, r + 1), p)
end

"""Return deterministic cyclic one-based IDs for one zero-based owner."""
function cyclic_range(count::Integer, rank::Integer, ranks::Integer)
    n, r, p=partition_arguments(count, rank, ranks)
    (r + 1):p:n
end

"""Count the exact original floor-boundary contiguous ownership without allocation."""
function partition_count(count::Integer, rank::Integer, ranks::Integer)
    n, r, p=partition_arguments(count, rank, ranks)
    fld(Base.checked_mul(n, r+1), p)-fld(Base.checked_mul(n, r), p)
end

end
