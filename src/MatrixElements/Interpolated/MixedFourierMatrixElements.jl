const _MIXED_MEMORY_ENV = "WANNIERNLQG_MIXED_MEMORY_LIMIT_BYTES"
const _MIXED_DEFAULT_MEMORY_LIMIT = 1024^3

"""
Store the logical mixed-Fourier mesh and its conjugate integer real-space coordinates.
"""
struct MixedFourierGrid
    mesh::NTuple{3, Int}
    nkdiv::NTuple{3, Int}
    nkfft::NTuple{3, Int}
    factor_source::Symbol
    r_grid::Matrix{Int}
    origin::Vector{Float64}
    directions::Matrix{Float64}
end

"""
Store the capabilities packed lazily for one `MatrixElementPlan`.
"""
struct MixedFourierLayout
    groups::Vector{Symbol}
    channel_count::Int
end

# Map a Fourier operator-group symbol to its matrix capability; reject unknown groups.
@inline function _mixed_group_kind(group::Symbol)
    group === :dH && return HAMILTONIAN_DERIVATIVES
    group === :ddH && return HAMILTONIAN_SECOND_DERIVATIVES
    group === :A && return WANNIER_POSITION
    group === :dA && return INTERNAL_CONNECTION_DERIVATIVES
    group === :SS && return SPIN
    group === :SH && return SPIN_TIMES_HAMILTONIAN
    group === :SR && return SPIN_TIMES_POSITION
    group === :SHR && return SPIN_TIMES_HAMILTONIAN_POSITION
    error("Mixed Fourier group $(group) has no directional MatrixElementKind.")
end

# Return the scalar, active-axis, or active-pair channel count needed to pack one Fourier group.
@inline function _mixed_group_channel_count(plan::MatrixElementPlan, group::Symbol)
    group === :H && return 1
    kind = _mixed_group_kind(group)
    return kind in (
        HAMILTONIAN_SECOND_DERIVATIVES,
        INTERNAL_CONNECTION_DERIVATIVES,
        SPIN_TIMES_POSITION,
        SPIN_TIMES_HAMILTONIAN_POSITION,
    ) ? _pair_channel_count(plan, kind) : _axis_channel_count(plan, kind)
end

"""
One operator/offset FFT buffer, its transform plan and the currently packed block index.

Repacking overwrites the buffer when block ownership changes; the entry does not own the underlying model.
"""
mutable struct MixedFourierCacheEntry
    block::NTuple{3, Int}
    buffer::Array{ComplexF64}
    plan::Any
end

"""
Store reusable per-offset FFT buffers whose dictionary survives block changes.
"""
mutable struct MixedFourierBlockStore
    entries::Dict{Tuple{Symbol, NTuple{3, Float64}}, MixedFourierCacheEntry}
    seen_offsets::Set{NTuple{3, Float64}}
    allocated_bytes::Int
    peak_allocated_bytes::Int
    memory_limit_bytes::Int
    pack_seconds::Float64
    fft_seconds::Float64
    extract_seconds::Float64
    fft_calls::Int
    cache_hits::Int
end

"""
Model, grid decomposition, capability layout and bounded FFT store for one matrix workspace.

Mutable base-point, logical/block indices and FFT indices identify the current extraction position.
"""
mutable struct MixedFourierProvider
    model::TightBindingModel
    grid::MixedFourierGrid
    layout::MixedFourierLayout
    store::MixedFourierBlockStore
    base_kpoint::Vector{Float64}
    logical_index::NTuple{3, Int}
    block::NTuple{3, Int}
    fft_index::NTuple{3, Int}
end

const _MIXED_PROVIDER_LOCK = ReentrantLock()
const _MIXED_PROVIDERS = IdDict{Any, MixedFourierProvider}()
"""
Accumulated direct-Fourier wall time in seconds and call count for one instrumented workspace.
"""
mutable struct FourierTiming
    direct_seconds::Float64
    direct_calls::Int
end
const _FOURIER_TIMINGS = IdDict{Any, FourierTiming}()

"""
Attach a fresh zeroed Fourier timing record to the workspace and return it.

Registration is lock-protected; subsequent direct-transform calls accumulate seconds and counts in this record.
"""
function enable_fourier_timing!(workspace::MatrixElementWorkspace)
    return lock(_MIXED_PROVIDER_LOCK) do
        _FOURIER_TIMINGS[workspace] = FourierTiming(0.0, 0)
    end
end

"""
Remove and return the workspace's Fourier timing record, or return `nothing` when timing was disabled.
"""
function disable_fourier_timing!(workspace::MatrixElementWorkspace)
    return lock(_MIXED_PROVIDER_LOCK) do
        pop!(_FOURIER_TIMINGS, workspace, nothing)
    end
end

# Add elapsed seconds and one call to an enabled workspace timing record; do nothing when instrumentation is absent.
function _record_direct_fourier!(workspace::MatrixElementWorkspace, seconds::Float64)
    timing = lock(_MIXED_PROVIDER_LOCK) do
        get(_FOURIER_TIMINGS, workspace, nothing)
    end
    timing === nothing && return nothing
    timing.direct_seconds += seconds
    timing.direct_calls += 1
    return nothing
end

"""
Return direct-transform seconds/counts and the Mixed-FFT statistics for a workspace.

Missing instrumentation contributes zero direct time and calls; reading statistics does not reset counters.
"""
function fourier_timing_stats(workspace::MatrixElementWorkspace)
    timing = lock(_MIXED_PROVIDER_LOCK) do
        get(_FOURIER_TIMINGS, workspace, nothing)
    end
    provider_stats = mixed_fourier_stats(workspace)
    return (
        direct_seconds = timing === nothing ? 0.0 : timing.direct_seconds,
        direct_calls = timing === nothing ? 0 : timing.direct_calls,
        mixed = provider_stats,
    )
end

# Normalize two mesh counts to a three-tuple with a singleton third axis; reject ranks other than two or three.
function _mixed_mesh_tuple(mesh)
    values = Tuple(Int(x) for x in mesh)
    return length(values) == 2 ? (values[1], values[2], 1) :
           length(values) == 3 ? values :
           error("mixed Fourier mesh must have two or three entries.")
end

# Normalize an optional positive two/three-dimensional decomposition factor, appending a singleton third axis when needed.
function _mixed_factor_tuple(value, label::AbstractString)
    value === nothing && return nothing
    values = Tuple(Int(x) for x in value)
    values =
        length(values) == 2 ? (values[1], values[2], 1) :
        length(values) == 3 ? values : error("$(label) must contain two or three integers.")
    all(>(0), values) || error("$(label) entries must be positive; got $(values).")
    return values
end

"""
Resolve positive `NKdiv` and `NKFFT` factors whose product equals the logical mesh.

At least one factor must be explicit; infer the other by exact division or reject incompatible factors. Return both factors and their provenance symbol.

Resolve mixed fourier factors.
"""
function resolve_mixed_fourier_factors(mesh, r_grid; nkdiv = nothing, nkfft = nothing)
    nkmesh = _mixed_mesh_tuple(mesh)
    requested_nkdiv = _mixed_factor_tuple(nkdiv, "NKdiv")
    requested_nkfft = _mixed_factor_tuple(nkfft, "NKFFT")

    if requested_nkdiv === nothing && requested_nkfft === nothing
        error("Mixed-FFT requires at least one explicit factor: NKdiv or NKFFT.")
    elseif requested_nkdiv === nothing
        all(nkmesh[axis] % requested_nkfft[axis] == 0 for axis in 1:3) ||
            error("NKFFT=$(requested_nkfft) must divide k_mesh=$(nkmesh) exactly.")
        resolved_nkdiv = ntuple(axis -> div(nkmesh[axis], requested_nkfft[axis]), 3)
        return resolved_nkdiv, requested_nkfft, :inferred_nkdiv
    elseif requested_nkfft === nothing
        all(nkmesh[axis] % requested_nkdiv[axis] == 0 for axis in 1:3) ||
            error("NKdiv=$(requested_nkdiv) must divide k_mesh=$(nkmesh) exactly.")
        resolved_nkfft = ntuple(axis -> div(nkmesh[axis], requested_nkdiv[axis]), 3)
        return requested_nkdiv, resolved_nkfft, :inferred_nkfft
    end

    expected = ntuple(axis -> requested_nkdiv[axis] * requested_nkfft[axis], 3)
    expected == nkmesh || error("NKdiv*NKFFT=$(expected) does not equal k_mesh=$(nkmesh).")
    return requested_nkdiv, requested_nkfft, :explicit
end

# Parse the configured per-workspace Mixed-FFT byte limit and reject noninteger or nonpositive values.
function _mixed_memory_limit()
    text = strip(get(ENV, _MIXED_MEMORY_ENV, string(_MIXED_DEFAULT_MEMORY_LIMIT)))
    value = try
        parse(Int, text)
    catch
        error("$(_MIXED_MEMORY_ENV) must be an integer byte count; got $(repr(text)).")
    end
    value > 0 || error("$(_MIXED_MEMORY_ENV) must be positive; got $(value).")
    return value
end

"""
Return the positive Mixed-FFT memory limit in bytes from its environment setting or package default.

Malformed or nonpositive settings raise an error before allocation.
"""
mixed_fourier_memory_limit() = _mixed_memory_limit()

"""
Return the integral Mixed-FFT grid and an empty diagnostic string after resolving explicit mesh factors.

Copy the integer real-space R grid; reject factors that do not multiply exactly to the requested mesh.
"""
function mixed_fourier_grid(model::TightBindingModel, mesh; nkdiv = nothing, nkfft = nothing)
    nkmesh = _mixed_mesh_tuple(mesh)
    r_grid = Matrix{Int}(model.r_vectors)
    resolved_nkdiv, resolved_nkfft, factor_source =
        resolve_mixed_fourier_factors(nkmesh, r_grid; nkdiv = nkdiv, nkfft = nkfft)
    return MixedFourierGrid(
        nkmesh,
        resolved_nkdiv,
        resolved_nkfft,
        factor_source,
        r_grid,
        zeros(Float64, 3),
        Matrix{Float64}(I, 3, 3),
    ),
    ""
end

"""
Return a Mixed-FFT slice grid when all projected R coordinates are integral within `tolerance`.

Geometry is in fractional reciprocal coordinates. Return `(nothing,reason)` for incommensurate projections; reject invalid mesh factors and require two mesh counts.
"""
function mixed_fourier_kslice_grid(
    model::TightBindingModel,
    mesh,
    origin::AbstractVector{<:Real},
    vector_1::AbstractVector{<:Real},
    vector_2::AbstractVector{<:Real};
    nkdiv = nothing,
    nkfft = nothing,
    tolerance::Float64 = 1e-12,
)
    nkmesh2 = Tuple(Int(x) for x in mesh)
    length(nkmesh2) == 2 || error("KSlice mixed Fourier mesh must have two entries.")
    nkmesh = (nkmesh2[1], nkmesh2[2], 1)
    directions = hcat(Float64.(vector_1), Float64.(vector_2), zeros(Float64, 3))
    projections = transpose(model.r_vectors) * directions[:, 1:2]
    rounded = round.(Int, projections)
    residual = maximum(abs, projections .- rounded; init = 0.0)
    if residual > tolerance
        reason = "KSlice R-vector integer residual $(residual) exceeds $(tolerance)"
        return nothing, reason
    end
    r_grid = zeros(Int, 3, model.num_r_vectors)
    r_grid[1:2, :] .= transpose(rounded)
    resolved_nkdiv, resolved_nkfft, factor_source =
        resolve_mixed_fourier_factors(nkmesh, r_grid; nkdiv = nkdiv, nkfft = nkfft)
    return MixedFourierGrid(
        nkmesh,
        resolved_nkdiv,
        resolved_nkfft,
        factor_source,
        r_grid,
        Float64.(origin),
        directions,
    ),
    ""
end

# Select operator groups needed by the matrix plan and retain the plan for compact Cartesian packing.
function MixedFourierLayout(plan::MatrixElementPlan)
    groups = Symbol[:H]
    channels = 1
    if has_capability(plan, HAMILTONIAN_DERIVATIVES)
        push!(groups, :dH)
        channels += _mixed_group_channel_count(plan, :dH)
    end
    if has_capability(plan, HAMILTONIAN_SECOND_DERIVATIVES)
        push!(groups, :ddH)
        channels += _mixed_group_channel_count(plan, :ddH)
    end
    if has_capability(plan, WANNIER_POSITION)
        push!(groups, :A)
        channels += _mixed_group_channel_count(plan, :A)
    end
    if has_capability(plan, INTERNAL_CONNECTION_DERIVATIVES)
        push!(groups, :dA)
        channels += _mixed_group_channel_count(plan, :dA)
    end
    if has_capability(plan, SPIN)
        push!(groups, :SS)
        channels += _mixed_group_channel_count(plan, :SS)
    end
    if has_capability(plan, SPIN_TIMES_HAMILTONIAN)
        push!(groups, :SH)
        channels += _mixed_group_channel_count(plan, :SH)
    end
    if has_capability(plan, SPIN_TIMES_POSITION)
        push!(groups, :SR)
        channels += _mixed_group_channel_count(plan, :SR)
    end
    if has_capability(plan, SPIN_TIMES_HAMILTONIAN_POSITION)
        push!(groups, :SHR)
        channels += _mixed_group_channel_count(plan, :SHR)
    end
    return MixedFourierLayout(groups, channels)
end

# Create an empty operator/offset cache with the configured byte limit and zero allocation, timing and hit counters.
function MixedFourierBlockStore(; memory_limit_bytes::Int = _mixed_memory_limit())
    return MixedFourierBlockStore(
        Dict{Tuple{Symbol, NTuple{3, Float64}}, MixedFourierCacheEntry}(),
        Set{NTuple{3, Float64}}(),
        0,
        0,
        memory_limit_bytes,
        0.0,
        0.0,
        0.0,
        0,
        0,
    )
end

# Compute ComplexF64 FFT-buffer bytes from FFT mesh volume, orbital pairs and active operator channels.
function _mixed_entry_bytes(
    grid::MixedFourierGrid,
    model::TightBindingModel,
    plan::MatrixElementPlan,
    group::Symbol,
)
    channels = _mixed_group_channel_count(plan, group)
    return prod(grid.nkfft) * model.num_orbitals^2 * channels * sizeof(ComplexF64)
end

# Reject a provider if even its largest required single-group FFT buffer exceeds the workspace memory share.
function _mixed_preflight_provider!(
    provider::MixedFourierProvider,
    workspace::MatrixElementWorkspace,
)
    largest_group = :H
    largest_bytes = 0
    for group in provider.layout.groups
        source = _mixed_source(workspace, provider.model, group)
        source === nothing && continue
        bytes = _mixed_entry_bytes(provider.grid, provider.model, workspace.plan, group)
        if bytes > largest_bytes
            largest_group = group
            largest_bytes = bytes
        end
    end
    largest_bytes <= provider.store.memory_limit_bytes && return provider
    reason =
        "minimum mixed buffer group=$(largest_group), bytes=$(largest_bytes) exceeds " *
        "per-workspace share=$(provider.store.memory_limit_bytes)"
    error("Mixed Fourier memory/configuration error: $(reason)")
end

"""
Register a Mixed-FFT provider for this workspace and model, with explicit grid factors and byte limit.

Set FFTW to one thread and preflight the required buffer size; incompatible memory configuration raises an error.
"""
function enable_mixed_fourier!(
    workspace::MatrixElementWorkspace,
    model::TightBindingModel,
    grid::MixedFourierGrid;
    memory_limit_bytes::Int = _mixed_memory_limit(),
)
    FFTW.set_num_threads(1)
    provider = MixedFourierProvider(
        model,
        grid,
        MixedFourierLayout(workspace.plan),
        MixedFourierBlockStore(; memory_limit_bytes = memory_limit_bytes),
        zeros(Float64, 3),
        (0, 0, 0),
        (0, 0, 0),
        (0, 0, 0),
    )
    lock(_MIXED_PROVIDER_LOCK) do
        _MIXED_PROVIDERS[workspace] = provider
    end
    _mixed_preflight_provider!(provider, workspace)
    return provider
end

"""
Detach and return the workspace's Mixed-FFT provider under the registry lock; return `nothing` if absent.
"""
function disable_mixed_fourier!(workspace::MatrixElementWorkspace)
    return lock(_MIXED_PROVIDER_LOCK) do
        pop!(_MIXED_PROVIDERS, workspace, nothing)
    end
end

# Read a workspace's optional Mixed-FFT provider under the shared registry lock.
function _mixed_provider(workspace::MatrixElementWorkspace)
    return lock(_MIXED_PROVIDER_LOCK) do
        get(_MIXED_PROVIDERS, workspace, nothing)
    end
end

"""
Set the provider's base fractional point and derive its block/FFT indices from the logical mesh index.

Return `nothing` when Mixed-FFT is disabled; the optional index bypasses inference from the point coordinates.
"""
function begin_mixed_kpoint!(
    workspace::MatrixElementWorkspace,
    kpoint::AbstractVector{<:Real},
    logical_index::Union{Nothing, NTuple{3, Int}} = nothing,
)
    provider = _mixed_provider(workspace)
    provider === nothing && return nothing
    grid = provider.grid
    logical = if logical_index === nothing
        ntuple(i -> mod(round(Int, kpoint[i] * grid.mesh[i]), grid.mesh[i]), 3)
    else
        logical_index
    end
    provider.base_kpoint .= kpoint
    provider.logical_index = logical
    provider.block = ntuple(i -> mod(logical[i], grid.nkdiv[i]), 3)
    provider.fft_index = ntuple(i -> mod(div(logical[i], grid.nkdiv[i]), grid.nkfft[i]), 3)
    return provider
end

# Round the displacement from the provider's base point to thirteen decimal digits for an offset cache key.
@inline function _mixed_delta_key(provider::MixedFourierProvider, kpoint)
    return ntuple(i -> round(Float64(kpoint[i] - provider.base_kpoint[i]); digits = 13), 3)
end

# Resolve a Fourier group to its prepared model/operator array, retaining the source's existing gauge.
function _mixed_source(workspace::MatrixElementWorkspace, model::TightBindingModel, group::Symbol)
    group === :H && return model.hamiltonian_r
    group === :dH && return workspace.scratch.hamiltonian.gradient_real_space
    group === :ddH && return workspace.scratch.hamiltonian.hessian_real_space
    group === :A && return model.position_r
    group === :dA && return workspace.scratch.position.gradient_real_space
    group === :SS && return workspace.sources.spin.spin_r
    group === :SH && return workspace.sources.spin_velocity.spin_hamiltonian_r
    group === :SR && return workspace.sources.spin_velocity.spin_position_r
    group === :SHR && return workspace.sources.spin_velocity.spin_hamiltonian_position_r
    error("Unsupported mixed Fourier source group $(group).")
end

"""
Estimate resident buffers when every planned group is cached at each offset.
"""
function mixed_fourier_buffer_estimate(
    grid::MixedFourierGrid,
    workspace::MatrixElementWorkspace,
    model::TightBindingModel;
    offset_count::Int = 1,
    safety_factor::Float64 = 1.0,
)
    offset_count > 0 || error("offset_count must be positive; got $(offset_count).")
    safety_factor >= 1.0 || error("safety_factor must be at least 1.0; got $(safety_factor).")
    layout = MixedFourierLayout(workspace.plan)
    group_bytes = NamedTuple[]
    bytes_per_offset = 0
    largest_group = :H
    largest_group_bytes = 0
    for group in layout.groups
        source = _mixed_source(workspace, model, group)
        source === nothing && continue
        bytes = _mixed_entry_bytes(grid, model, workspace.plan, group)
        push!(group_bytes, (group = group, bytes = bytes))
        bytes_per_offset += bytes
        if bytes > largest_group_bytes
            largest_group = group
            largest_group_bytes = bytes
        end
    end
    estimated_bytes = ceil(Int, safety_factor * offset_count * bytes_per_offset)
    return (
        estimated_bytes = estimated_bytes,
        bytes_per_offset = bytes_per_offset,
        largest_group = largest_group,
        largest_group_bytes = largest_group_bytes,
        offset_count = offset_count,
        safety_factor = safety_factor,
        channel_count = layout.channel_count,
        groups = copy(layout.groups),
        group_bytes = group_bytes,
    )
end

# Allocate and register one operator/offset FFT buffer and backward FFT plan, rejecting byte-limit overflow and updating peak usage.
function _mixed_allocate_entry!(
    provider::MixedFourierProvider,
    group::Symbol,
    delta::NTuple{3, Float64},
    plan::MatrixElementPlan,
)
    grid = provider.grid
    channels = _mixed_group_channel_count(plan, group)
    shape = (grid.nkfft..., provider.model.num_orbitals, provider.model.num_orbitals, channels)
    bytes = _mixed_entry_bytes(grid, provider.model, plan, group)
    store = provider.store
    if store.allocated_bytes + bytes > store.memory_limit_bytes
        reason =
            "allocating group=$(group), offset=$(delta), bytes=$(bytes) would exceed " *
            "per-rank limit=$(store.memory_limit_bytes) (already $(store.allocated_bytes))"
        error("Mixed Fourier memory/configuration error: $(reason)")
    end
    store.allocated_bytes + bytes <= store.memory_limit_bytes || error(
        "Internal mixed Fourier memory accounting error: requested $(bytes) bytes with " *
        "$(store.allocated_bytes)/$(store.memory_limit_bytes) bytes already allocated.",
    )
    buffer = zeros(ComplexF64, shape)
    plan = plan_bfft!(buffer, (1, 2, 3); flags = FFTW.ESTIMATE)
    entry = MixedFourierCacheEntry((-1, -1, -1), buffer, plan)
    store.entries[(group, delta)] = entry
    store.allocated_bytes += bytes
    store.peak_allocated_bytes = max(store.peak_allocated_bytes, store.allocated_bytes)
    return entry
end

# Build compact Cartesian source indices, returning nothing when the selected payload already has dense storage order.
function _mixed_source_indices(source, plan::MatrixElementPlan, group::Symbol, num_orbitals::Int)
    group in (:H, :dH, :ddH, :dA) && return nothing
    kind = _mixed_group_kind(group)
    channels = _mixed_group_channel_count(plan, group)
    indices = Vector{Int}(undef, num_orbitals^2 * channels)
    output_index = 0
    if group in (:A, :SS, :SH)
        for channel in 1:channels
            direction = _axis_for_channel(plan, kind, channel)
            for orbital_column in 1:num_orbitals, orbital_row in 1:num_orbitals
                output_index += 1
                indices[output_index] =
                    orbital_row +
                    num_orbitals * (orbital_column - 1 + num_orbitals * (direction - 1))
            end
        end
    else
        first_direction_count = size(source, 3)
        for channel in 1:channels
            first_direction, second_direction = _pair_for_channel(plan, kind, channel)
            for orbital_column in 1:num_orbitals, orbital_row in 1:num_orbitals
                output_index += 1
                indices[output_index] =
                    orbital_row +
                    num_orbitals * (
                        orbital_column - 1 +
                        num_orbitals *
                        (first_direction - 1 + first_direction_count * (second_direction - 1))
                    )
            end
        end
    end
    source_value_count = div(length(source), size(source, ndims(source)))
    length(indices) == source_value_count &&
        all(index == position for (position, index) in pairs(indices)) &&
        return nothing
    return indices
end

# Accumulate R blocks into FFT bins with positive Bloch phase and R-degeneracy weights; optionally gather compact source channels.
function _mixed_pack_values!(
    flattened,
    source_flat,
    grid::MixedFourierGrid,
    model::TightBindingModel,
    phase_point,
    ::Nothing,
)
    for r_index in 1:model.num_r_vectors
        i1 = mod(grid.r_grid[1, r_index], grid.nkfft[1])
        i2 = mod(grid.r_grid[2, r_index], grid.nkfft[2])
        i3 = mod(grid.r_grid[3, r_index], grid.nkfft[3])
        linear = 1 + i1 + grid.nkfft[1] * (i2 + grid.nkfft[2] * i3)
        r1 = model.r_vectors[1, r_index]
        r2 = model.r_vectors[2, r_index]
        r3 = model.r_vectors[3, r_index]
        factor =
            cis(2pi * (r1 * phase_point[1] + r2 * phase_point[2] + r3 * phase_point[3])) /
            model.r_degeneracies[r_index]
        for value_index in axes(source_flat, 1)
            flattened[linear, value_index] += factor * source_flat[value_index, r_index]
        end
    end
    return flattened
end

# Accumulate R blocks into FFT bins with positive Bloch phase and R-degeneracy weights; optionally gather compact source channels.
function _mixed_pack_values!(
    flattened,
    source_flat,
    grid::MixedFourierGrid,
    model::TightBindingModel,
    phase_point,
    source_indices::Vector{Int},
)
    for r_index in 1:model.num_r_vectors
        i1 = mod(grid.r_grid[1, r_index], grid.nkfft[1])
        i2 = mod(grid.r_grid[2, r_index], grid.nkfft[2])
        i3 = mod(grid.r_grid[3, r_index], grid.nkfft[3])
        linear = 1 + i1 + grid.nkfft[1] * (i2 + grid.nkfft[2] * i3)
        r1 = model.r_vectors[1, r_index]
        r2 = model.r_vectors[2, r_index]
        r3 = model.r_vectors[3, r_index]
        factor =
            cis(2pi * (r1 * phase_point[1] + r2 * phase_point[2] + r3 * phase_point[3])) /
            model.r_degeneracies[r_index]
        for value_index in eachindex(source_indices)
            flattened[linear, value_index] +=
                factor * source_flat[source_indices[value_index], r_index]
        end
    end
    return flattened
end

# Clear and repack one cache entry for the current block/offset, execute its backward FFT, and update timings and block identity.
function _mixed_pack_and_fft!(
    entry::MixedFourierCacheEntry,
    provider::MixedFourierProvider,
    source,
    plan::MatrixElementPlan,
    group::Symbol,
    delta::NTuple{3, Float64},
)
    grid = provider.grid
    model = provider.model
    buffer = entry.buffer
    fill!(buffer, COMPLEX_ZERO)
    flattened = reshape(buffer, prod(grid.nkfft), :)
    source_flat = reshape(source, :, model.num_r_vectors)
    source_indices = _mixed_source_indices(source, plan, group, model.num_orbitals)
    phase_origin =
        grid.origin .+
        grid.directions * Float64[
            provider.block[1] / grid.mesh[1],
            provider.block[2] / grid.mesh[2],
            provider.block[3] / grid.mesh[3],
        ]
    phase_point = phase_origin .+ collect(delta)
    pack_t0 = time_ns()
    _mixed_pack_values!(flattened, source_flat, grid, model, phase_point, source_indices)
    provider.store.pack_seconds += (time_ns() - pack_t0) * 1e-9
    fft_t0 = time_ns()
    entry.plan * buffer
    provider.store.fft_seconds += (time_ns() - fft_t0) * 1e-9
    provider.store.fft_calls += 1
    entry.block = provider.block
    return entry
end

# Dispatch a runtime group symbol to the typed Mixed-FFT extraction path; return false when that provider/group is unavailable.
function _mixed_copy!(
    destination,
    workspace::MatrixElementWorkspace,
    model::TightBindingModel,
    group::Symbol,
    kpoint::AbstractVector{<:Real},
)
    return _mixed_copy!(destination, workspace, model, Val(group), kpoint)
end

# Dispatch a runtime group symbol to the typed Mixed-FFT extraction path; return false when that provider/group is unavailable.
#
# Copy one compile-time Mixed-Fourier group into its caller-owned destination.
function _mixed_copy!(
    destination,
    workspace::MatrixElementWorkspace,
    model::TightBindingModel,
    ::Val{G},
    kpoint::AbstractVector{<:Real},
) where {G}
    group = G
    provider = _mixed_provider(workspace)
    provider === nothing && return false
    provider.model === model || error("Mixed Fourier provider/model mismatch.")
    group in provider.layout.groups || return false
    delta = _mixed_delta_key(provider, kpoint)
    source = _mixed_source(workspace, model, group)
    source === nothing && return false
    key = (group, delta)
    entry = get(provider.store.entries, key, nothing)
    if entry === nothing
        push!(provider.store.seen_offsets, delta)
        entry = _mixed_allocate_entry!(provider, group, delta, workspace.plan)
        entry === nothing && return false
    elseif entry.block == provider.block
        provider.store.cache_hits += 1
    end
    entry.block == provider.block ||
        _mixed_pack_and_fft!(entry, provider, source, workspace.plan, group, delta)
    extract_t0 = time_ns()
    m1, m2, m3 = provider.fft_index
    if group === :H
        ndims(destination) == 2 || error("Mixed Fourier H destination must be a matrix.")
        @views destination .= entry.buffer[m1 + 1, m2 + 1, m3 + 1, :, :, 1]
    elseif ndims(destination) == 3
        size(destination, 3) == _mixed_group_channel_count(workspace.plan, group) || error(
            "Mixed Fourier destination channels $(size(destination, 3)) do not match planned $(_mixed_group_channel_count(workspace.plan, group)).",
        )
        @views destination .= entry.buffer[m1 + 1, m2 + 1, m3 + 1, :, :, :]
    elseif ndims(destination) == 4
        kind = _mixed_group_kind(group)
        kind in (
            HAMILTONIAN_SECOND_DERIVATIVES,
            INTERNAL_CONNECTION_DERIVATIVES,
            SPIN_TIMES_POSITION,
            SPIN_TIMES_HAMILTONIAN_POSITION,
        ) || error("Mixed Fourier group $(group) does not have pair-valued channels.")
        second_limit =
            kind in (SPIN_TIMES_POSITION, SPIN_TIMES_HAMILTONIAN_POSITION) ? 3 :
            workspace.plan.spatial_dimension
        size(destination, 3) == workspace.plan.spatial_dimension || error(
            "Mixed Fourier pair destination first-direction size $(size(destination, 3)) does not match spatial dimension $(workspace.plan.spatial_dimension).",
        )
        size(destination, 4) == second_limit || error(
            "Mixed Fourier pair destination second-direction size $(size(destination, 4)) does not match planned $(second_limit).",
        )
        fill!(destination, COMPLEX_ZERO)
        @views source_view = entry.buffer[m1 + 1, m2 + 1, m3 + 1, :, :, :]
        for channel in axes(source_view, 3)
            first_direction, second_direction = _pair_for_channel(workspace.plan, kind, channel)
            @views destination[:, :, first_direction, second_direction] .=
                source_view[:, :, channel]
        end
    else
        error("Mixed Fourier directional destination rank $(ndims(destination)) must be 3 or 4.")
    end
    provider.store.extract_seconds += (time_ns() - extract_t0) * 1e-9
    return true
end

"""
Return a snapshot of provider mesh factors, cache memory, phase timings, FFT calls and hits, or `nothing` when no mixed provider is installed.
"""
function mixed_fourier_stats(workspace::MatrixElementWorkspace)
    provider = _mixed_provider(workspace)
    provider === nothing && return nothing
    store = provider.store
    return (
        allocated_bytes = store.peak_allocated_bytes,
        memory_limit_bytes = store.memory_limit_bytes,
        fft_calls = store.fft_calls,
        cache_hits = store.cache_hits,
        pack_seconds = store.pack_seconds,
        fft_seconds = store.fft_seconds,
        extract_seconds = store.extract_seconds,
        channel_count = provider.layout.channel_count,
        groups = copy(provider.layout.groups),
        cache_entries = length(store.entries),
        offset_count = length(store.seen_offsets),
    )
end

"""
Enumerate the rank-owned logical mesh indices using deterministic Mixed-FFT block ownership.

Rank is zero-based; the returned indices preserve the mesh traversal used by the runtime.
"""
function mixed_fourier_local_k_indices(grid::MixedFourierGrid, rank::Int, size::Int)
    indices = Int[]
    block_linear = 0
    n1, n2, _ = grid.mesh
    for l3 in 0:(grid.nkdiv[3] - 1), l2 in 0:(grid.nkdiv[2] - 1), l1 in 0:(grid.nkdiv[1] - 1)
        block_linear += 1
        mod(block_linear - 1, size) == rank || continue
        for m3 in 0:(grid.nkfft[3] - 1), m2 in 0:(grid.nkfft[2] - 1), m1 in 0:(grid.nkfft[1] - 1)
            i1 = l1 + grid.nkdiv[1] * m1
            i2 = l2 + grid.nkdiv[2] * m2
            i3 = l3 + grid.nkdiv[3] * m3
            push!(indices, 1 + i1 + n1 * (i2 + n2 * i3))
        end
    end
    return indices
end
