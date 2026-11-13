"""Release only the caller-provided worker set, in its original order.

Repeated calls and unprepared workers retain MatrixElements no-op semantics.
Timing cleanup is explicit; model storage, once-only guards and failure policy
remain owned by each response driver. No global provider scan is performed.
"""
function release_mixed_worker_buffers!(workspaces; timing::Bool = false)
    for workspace in workspaces
        disable_mixed_fourier!(workspace)
        timing && disable_fourier_timing!(workspace)
    end
    return nothing
end

"""Ordered whole-block access shared by response schedulers.

This describes evaluation ownership only. Response lanes and reductions remain
in their drivers. The existing MatrixElements enumerator defines point order.
"""
struct MixedBlockAccess
    indices::Vector{Int}
    block_count::Int
    points_per_block::Int
    rank::Int
    ranks::Int
end

# Validate mesh factorization and assign a deterministic mixed-grid block layout to this rank.
function mixed_block_access(grid, rank::Int, ranks::Int)
    ranks > 0 && 0 <= rank < ranks || throw(ArgumentError("MIXED_BLOCK_ACCESS_OWNER"))
    all(>(0), grid.mesh) && all(>(0), grid.nkdiv) && all(>(0), grid.nkfft) ||
        throw(ArgumentError("MIXED_BLOCK_ACCESS_FACTORS"))
    all(Base.checked_mul(grid.nkdiv[i], grid.nkfft[i]) == grid.mesh[i] for i in 1:3) ||
        throw(DimensionMismatch("MIXED_BLOCK_ACCESS_MESH"))
    blocks = Base.checked_mul(Base.checked_mul(grid.nkdiv[1], grid.nkdiv[2]), grid.nkdiv[3])
    perblock = Base.checked_mul(Base.checked_mul(grid.nkfft[1], grid.nkfft[2]), grid.nkfft[3])
    Base.checked_mul(blocks, perblock)
    indices = mixed_fourier_local_k_indices(grid, rank, ranks)
    expected_blocks = length(rank:ranks:(blocks - 1))
    length(indices) == Base.checked_mul(expected_blocks, perblock) ||
        error("MIXED_BLOCK_ACCESS_INCOMPLETE")
    return MixedBlockAccess(indices, blocks, perblock, rank, ranks)
end

"""Prepare each worker's existing channel-specific provider exactly once.

Workers must own distinct MatrixElementWorkspace objects. Channel selection,
q/shift cache keys, eviction, FFT plans and pack buffers stay in MatrixElements.
Completed-block reuse is enabled only when the caller proves non-revisiting
whole-block traversal. No universal derivative buffer is allocated here.
"""
function prepare_mixed_worker_buffers!(
    workspaces,
    model,
    grid;
    memory_limit_bytes::Int,
    completed_block_reuse::Bool = false,
)
    memory_limit_bytes > 0 || throw(ArgumentError("MIXED_WORKER_MEMORY_LIMIT"))
    # Validate the entire ownership set before mutating any workspace.
    for i in eachindex(workspaces), j in firstindex(workspaces):(i - 1)
        workspaces[i] === workspaces[j] && throw(ArgumentError("MIXED_WORKER_BUFFER_ALIAS"))
    end
    # This helper owns newly prepared providers only; never replace a caller's
    # existing provider or release one during another worker's setup failure.
    for workspace in workspaces
        !MatrixElements.has_mixed_fourier_provider(workspace) ||
            throw(ArgumentError("MIXED_WORKER_ALREADY_PREPARED"))
    end
    initialized = 0
    try
        for workspace in workspaces
            enable_mixed_fourier!(workspace, model, grid; memory_limit_bytes)
            initialized += 1
            completed_block_reuse && MatrixElements.reuse_completed_mixed_blocks!(workspace)
        end
    catch
        release_mixed_worker_buffers!(Iterators.take(workspaces, initialized))
        rethrow()
    end
    return nothing
end

"""Canonical integration lane of a physical point, independent of evaluation ownership."""
function response_point_lane(points::Int, lanes::Int, index::Int)
    points > 0 && 0 < lanes <= points && 1 <= index <= points ||
        throw(ArgumentError("RESPONSE_POINT_LANE_DOMAIN"))
    return fld(Base.checked_mul(index, lanes)-1, points)+1
end

"""Ordered response work units with explicit evaluation policy.

Canonical lanes reproduce the original per-rank traversal exactly. Whole blocks
change evaluation ownership only: the caller must route individual responses back
to canonical lanes before summation. No partial block sum is implied. This helper
allocates no channel, FFT or response buffer and does not select a physical policy.
"""
function response_access_units(
    points::Int,
    rank::Int,
    ranks::Int;
    grid = nothing,
    policy::Symbol = :canonical_lanes,
)
    points > 0 && ranks > 0 && 0 <= rank < ranks || throw(ArgumentError("RESPONSE_ACCESS_DOMAIN"))
    policy in (:canonical_lanes, :whole_blocks) || throw(ArgumentError("RESPONSE_ACCESS_POLICY"))
    lanes = _deterministic_integral_lane_count(points)
    Base.checked_mul(points, lanes)
    if grid !== nothing
        all(>(0), grid.mesh) && all(>(0), grid.nkdiv) && all(>(0), grid.nkfft) ||
            throw(ArgumentError("RESPONSE_ACCESS_FACTORS"))
        all(Base.checked_mul(grid.nkdiv[i], grid.nkfft[i]) == grid.mesh[i] for i in 1:3) ||
            throw(DimensionMismatch("RESPONSE_ACCESS_FACTORS"))
        Base.checked_mul(Base.checked_mul(grid.mesh[1], grid.mesh[2]), grid.mesh[3]) == points ||
            throw(DimensionMismatch("RESPONSE_ACCESS_MESH"))
    end
    if policy === :whole_blocks
        grid === nothing && throw(ArgumentError("RESPONSE_ACCESS_REQUIRES_MIXED"))
        return NTuple{3, Int}[
            (i, i, response_point_lane(points, lanes, i)) for
            i in mixed_block_access(grid, rank, ranks).indices
        ]
    end
    return NTuple{3, Int}[
        (i, i, lane) for lane in _local_deterministic_integral_lanes(lanes, rank, ranks) for
        i in _deterministic_integral_lane_range(points, lanes, lane)
    ]
end

# Construct a response routing plan subject to point ownership, lane width and the configured memory limit.
function response_block_route_plan(
    ::Type{T},
    grid,
    points::Int,
    width::Int,
    rank::Int,
    ranks::Int,
    memory_limit_bytes::Int,
) where {T <: Union{Float64, ComplexF64}}
    points > 0 && width > 0 && ranks > 0 && 0 <= rank < ranks ||
        throw(ArgumentError("SPECTRAL_BLOCK_ROUTE_DOMAIN"))
    all(>(0), grid.mesh) && all(>(0), grid.nkdiv) && all(>(0), grid.nkfft) ||
        throw(ArgumentError("SPECTRAL_BLOCK_ROUTE_FACTORS"))
    lanes=_deterministic_integral_lane_count(points)
    sizes=try
        Base.checked_mul(points, lanes) # inverse original-lane lookup must not overflow
        meshpoints=Base.checked_mul(Base.checked_mul(grid.mesh[1], grid.mesh[2]), grid.mesh[3])
        meshpoints==points || throw(DimensionMismatch("SPECTRAL_BLOCK_ROUTE_MESH"))
        blocks=Base.checked_mul(Base.checked_mul(grid.nkdiv[1], grid.nkdiv[2]), grid.nkdiv[3])
        perblock=Base.checked_mul(Base.checked_mul(grid.nkfft[1], grid.nkfft[2]), grid.nkfft[3])
        Base.checked_mul(blocks, perblock)==points ||
            throw(DimensionMismatch("SPECTRAL_BLOCK_ROUTE_FACTORS"))
        maxsend=min(points, Base.checked_mul(cld(blocks, ranks), perblock))
        maxrecv=min(points, Base.checked_mul(cld(lanes, ranks), cld(points, lanes)))
        max(Base.checked_mul(maxsend, width), Base.checked_mul(maxrecv, width)) <= typemax(Cint) ||
            return nothing
        values=Base.checked_mul(
            sizeof(T),
            Base.checked_mul(width, Base.checked_add(maxsend, maxrecv)),
        )
        # Include dense maps, enumerator and grouping copies, counts, written bits,
        # and conservative existing scheduler point-order storage, before allocating.
        indices=Base.checked_mul(
            8,
            Base.checked_add(
                Base.checked_mul(3, points),
                Base.checked_add(
                    Base.checked_mul(3, maxsend),
                    Base.checked_add(maxrecv, Base.checked_mul(8, ranks)),
                ),
            ),
        )
        overhead=Base.checked_add(Base.checked_mul(65, maxsend), 4096)
        bytes=Base.checked_add(values, Base.checked_add(indices, overhead))
        (bytes = bytes, maxsend = maxsend, maxrecv = maxrecv)
    catch err
        err isa OverflowError || rethrow()
        return nothing
    end
    sizes.bytes <= memory_limit_bytes || return nothing
    owner(i)=mod(response_point_lane(points, lanes, i)-1, ranks)
    orders=[mixed_block_access(grid, s, ranks).indices for s in 0:(ranks - 1)]
    parts=[Int[] for _ in 1:ranks]
    for i in orders[rank + 1]
        push!(parts[owner(i) + 1], i)
    end
    sendpoints=reduce(vcat, parts; init = Int[])
    sendcounts=[Base.checked_mul(length(ids), width) for ids in parts]
    recvpoints=Int[];
    recvcounts=zeros(Int, ranks)
    for src in 1:ranks
        for i in orders[src]
            if owner(i)==rank
                push!(recvpoints, i)
                recvcounts[src]+=width
            end
        end
    end
    sendslots=zeros(Int, points);
    recvslots=zeros(Int, points)
    for (slot, i) in enumerate(sendpoints)
        1 <= i <= points && iszero(sendslots[i]) || error("SPECTRAL_ROUTE_SEND_PARTITION")
        sendslots[i]=slot
    end
    for (slot, i) in enumerate(recvpoints)
        1 <= i <= points && iszero(recvslots[i]) || error("SPECTRAL_ROUTE_RECEIVE_PARTITION")
        recvslots[i]=slot
    end
    local_lanes=_local_deterministic_integral_lanes(lanes, rank, ranks)
    expected=sum(
        length(_deterministic_integral_lane_range(points, lanes, l)) for l in local_lanes;
        init = 0,
    )
    length(recvpoints)==expected || error("SPECTRAL_ROUTE_RECEIVE_COUNT")
    for l in local_lanes, i in _deterministic_integral_lane_range(points, lanes, l)
        recvslots[i]>0 || error("SPECTRAL_ROUTE_RECEIVE_MISSING")
    end
    return (
        local_indices = orders[rank + 1],
        sendpoints = sendpoints,
        recvpoints = recvpoints,
        sendslots = sendslots,
        recvslots = recvslots,
        sendcounts = sendcounts,
        recvcounts = recvcounts,
        sendvalues = Vector{T}(undef, sum(sendcounts)),
        recvvalues = Vector{T}(undef, sum(recvcounts)),
        written = falses(length(sendpoints)),
        width = width,
        reserved_bytes = sizes.bytes,
        local_lanes = local_lanes,
    )
end

"""Store one complete point response without arithmetic or changing element order."""
function response_route_record!(route, index::Int, value::AbstractArray)
    1 <= index <= length(route.sendslots) || throw(BoundsError(route.sendslots, index))
    slot=route.sendslots[index]
    slot>0 && !route.written[slot] || error("RESPONSE_ROUTE_POINT_OWNERSHIP")
    eltype(value) === eltype(route.sendvalues) && length(value)==route.width ||
        throw(DimensionMismatch("RESPONSE_ROUTE_VALUE_LAYOUT"))
    Base.mightalias(value, route.sendvalues) && throw(ArgumentError("RESPONSE_ROUTE_ALIAS"))
    for (ordinal, i) in enumerate(eachindex(value))
        route.sendvalues[(slot - 1) * route.width + ordinal]=value[i]
    end
    route.written[slot]=true
    return nothing
end

"""Exchange complete point values, then replay the original point order in each lane.

Response shape/weights/units remain with the caller. No block partial sums are used.
All ranks, including empty evaluation owners, enter the same collective checks.
"""
function response_route_finish!(route, buffers, points::Int, lanes::Int, comm)
    valid=length(buffers)==lanes && all(route.written)
    valid &= all(eltype(b)===eltype(route.recvvalues) && length(b)==route.width for b in buffers)
    valid &= all(
        !Base.mightalias(b, route.recvvalues) && !Base.mightalias(b, route.sendvalues) for
        b in buffers
    )
    valid &= all(
        !Base.mightalias(buffers[i], buffers[j]) for i in eachindex(buffers) for
        j in firstindex(buffers):(i - 1)
    )
    bundle_mpi_all_true(valid, comm) || throw(ArgumentError("RESPONSE_ROUTE_REPLAY_LAYOUT"))
    bundle_mpi_exchange_responses!(
        route.sendvalues,
        route.sendcounts,
        route.recvvalues,
        route.recvcounts,
        comm,
    )
    bundle_mpi_all_true(all(isfinite, route.recvvalues), comm) || error("RESPONSE_ROUTE_NONFINITE")
    for lane in route.local_lanes
        target=buffers[lane]
        for index in _deterministic_integral_lane_range(points, lanes, lane)
            slot=route.recvslots[index]
            for (ordinal, i) in enumerate(eachindex(target))
                target[i]+=route.recvvalues[(slot - 1) * route.width + ordinal]
            end
        end
    end
    return nothing
end
