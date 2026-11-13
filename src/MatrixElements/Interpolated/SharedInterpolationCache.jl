"""
Worker-local interpolation, spectrum and optional complete-capability cache for one central point.

Parameter-independent interpolation and fully keyed complete capabilities are copied;
response masks, regularized denominators and band groups remain task-owned.
Set `reuse=false` for counters only, without cache keys or array copies.
Call `begin_shared_interpolation!` before each central point to bound storage by
that point's requested offsets and capabilities, independently of mesh size.
"""
mutable struct SharedInterpolationCache
    reuse::Bool
    entries::Dict{Any, Any}
    generations::Int
    fourier_evaluations::Int
    diagonalizations::Int
    fourier_hits::Int
    spectrum_hits::Int
    peak_entries::Int
    max_entries::Int
    max_bytes::Int
    retained_bytes::Int
    peak_retained_bytes::Int
    evictions::Int
    measure_timings::Bool
    matrix_seconds::Float64
    eigensystem_seconds::Float64
    capability_hits::Int
end

# Construct an empty worker-local cache with cumulative counters initialized to zero.
function SharedInterpolationCache(;
    reuse::Bool = true,
    max_entries::Int = typemax(Int),
    max_bytes::Int = typemax(Int),
    measure_timings::Bool = false,
)
    max_entries >= 0 && max_bytes >= 0 || throw(ArgumentError("cache limits must be nonnegative"))
    return SharedInterpolationCache(
        reuse && max_entries > 0 && max_bytes > 0,
        Dict{Any, Any}(),
        0,
        0,
        0,
        0,
        0,
        0,
        max_entries,
        max_bytes,
        0,
        0,
        0,
        measure_timings,
        0.0,
        0.0,
        0,
    )
end

const _SHARED_INTERPOLATION_TLS_KEY = :wanniernlqg_shared_interpolation

"""Clear cached points for a new central-point generation, retaining cumulative counters."""
function begin_shared_interpolation!(cache::SharedInterpolationCache)
    empty!(cache.entries)
    cache.retained_bytes = 0
    cache.generations += 1
    return cache
end

"""
Evaluate `f()` with the worker cache bound only to the current Julia task.

Restore any outer binding even on failure; callers must not concurrently bind
one mutable cache to multiple tasks.
"""
function with_shared_interpolation(f::F, cache::SharedInterpolationCache) where {F}
    return task_local_storage(f, _SHARED_INTERPOLATION_TLS_KEY, cache)
end

"""
Return cumulative raw-group evaluations, actual diagonalizations, hits and cache occupancy.

`fourier_evaluations` counts newly obtained operator-group outputs, including
extraction from an existing Mixed block; actual FFT calls remain provider-owned.
"""
function shared_interpolation_stats(cache::SharedInterpolationCache)
    legacy = (
        reuse_enabled = cache.reuse,
        generations = cache.generations,
        fourier_evaluations = cache.fourier_evaluations,
        diagonalizations = cache.diagonalizations,
        fourier_hits = cache.fourier_hits,
        spectrum_hits = cache.spectrum_hits,
        entries = length(cache.entries),
        peak_entries = cache.peak_entries,
    )
    # Fixed-momentum tasks retain the original metadata fields and their meaning.
    cache.max_entries == typemax(Int) &&
        cache.max_bytes == typemax(Int) &&
        !cache.measure_timings &&
        return legacy
    return merge(
        legacy,
        (
            max_entries = cache.max_entries,
            max_bytes = cache.max_bytes,
            retained_bytes = cache.retained_bytes,
            peak_retained_bytes = cache.peak_retained_bytes,
            evictions = cache.evictions,
            matrix_seconds = cache.matrix_seconds,
            eigensystem_seconds = cache.eigensystem_seconds,
            capability_hits = cache.capability_hits,
        ),
    )
end

# Count the same payload/key overhead before or after copying primitive dense buffers.
_shared_entry_bytes(key, value) = Base.summarysize(key) + Base.summarysize(value) + 256

# Numeric dense arrays and spectra have constant-size object graphs; reject without copying.
function _shared_entry_fits(cache::SharedInterpolationCache, key, value)
    cache.max_bytes == typemax(Int) && return true
    return _shared_entry_bytes(key, value) <= cache.max_bytes
end

# Retain owned snapshots; optional completed states yield before original raw/spectrum eviction.
function _save_shared_entry!(cache::SharedInterpolationCache, key, value)
    if cache.max_entries == typemax(Int) && cache.max_bytes == typemax(Int)
        cache.entries[key] = value
        cache.peak_entries = max(cache.peak_entries, length(cache.entries))
        return true
    end
    bytes = _shared_entry_bytes(key, value)
    bytes > cache.max_bytes && return false
    if length(cache.entries) >= cache.max_entries || bytes > cache.max_bytes - cache.retained_bytes
        _discard_complete_snapshots!(cache)
    end
    if length(cache.entries) >= cache.max_entries || bytes > cache.max_bytes - cache.retained_bytes
        cache.evictions += length(cache.entries)
        empty!(cache.entries)
        cache.retained_bytes = 0
    end
    cache.entries[key] = value
    cache.retained_bytes += bytes
    cache.peak_entries = max(cache.peak_entries, length(cache.entries))
    cache.peak_retained_bytes = max(cache.peak_retained_bytes, cache.retained_bytes)
    return true
end

# Read the task-local binding without installing global mutable workspace state.
_shared_interpolation_cache() = get(task_local_storage(), _SHARED_INTERPOLATION_TLS_KEY, nothing)

# Preserve the exact backend decomposition and extraction arithmetic in each key.
function _shared_backend_key(workspace::MatrixElementWorkspace)
    provider = _mixed_provider(workspace)
    provider === nothing && return (:direct,)
    grid = provider.grid
    return (
        :mixed,
        grid.mesh,
        grid.nkdiv,
        grid.nkfft,
        Tuple(grid.r_grid),
        Tuple(grid.origin),
        Tuple(grid.directions),
        Tuple(provider.base_kpoint),
        provider.logical_index,
        provider.block,
        provider.fft_index,
    )
end

# Key raw derivatives by their model source, never by task-owned prepared scratch.
function _shared_source_identity(
    workspace::MatrixElementWorkspace,
    model::AbstractResponseModel,
    group::Symbol,
)
    group in (:H, :dH, :ddH) && return objectid(model.hamiltonian_r)
    group in (:A, :dA, :curlA) && return objectid(model.position_r)
    return objectid(_mixed_source(workspace, model, group))
end

# Encode each group's compact directional channels without response numerical controls.
function _shared_group_key(
    workspace::MatrixElementWorkspace,
    model::AbstractResponseModel,
    group::Symbol,
    kpoint,
)
    plan = workspace.plan
    directions =
        group === :H ? UInt16(0) :
        _direction_mask(plan.direction_requirements, _mixed_group_kind(group))
    return (
        objectid(model),
        scientific_data_generation(model),
        _shared_source_identity(workspace, model, group),
        group,
        Tuple(Float64.(kpoint)),
        plan.wannier_center_convention,
        group === :H ? 0 : plan.spatial_dimension,
        directions,
        _shared_backend_key(workspace),
    )
end

# Record an immutable-to-consumers copy before any convention or gauge transformation.
function _store_shared_fourier!(
    destination,
    workspace::MatrixElementWorkspace,
    model::AbstractResponseModel,
    group::Symbol,
    kpoint,
)
    cache = _shared_interpolation_cache()
    cache === nothing && return destination
    if !cache.reuse
        cache.fourier_evaluations += 1
        return destination
    end
    key = (:fourier, _shared_group_key(workspace, model, group, kpoint), size(destination))
    if !haskey(cache.entries, key)
        # Views keep the existing copy-and-admit path: summarysize(view) includes its parent.
        if !(destination isa Array) || _shared_entry_fits(cache, key, destination)
            _save_shared_entry!(cache, key, copy(destination))
        end
        cache.fourier_evaluations += 1
    end
    return destination
end

# Reuse raw cached channels or delegate unchanged to the existing Mixed provider.
function _shared_or_mixed_copy!(
    destination,
    workspace::MatrixElementWorkspace,
    model::AbstractResponseModel,
    ::Val{G},
    kpoint,
) where {G}
    cache = _shared_interpolation_cache()
    cache !== nothing &&
        !cache.reuse &&
        return _mixed_copy!(destination, workspace, model, Val(G), kpoint)
    if cache !== nothing
        key = (:fourier, _shared_group_key(workspace, model, G, kpoint), size(destination))
        saved = get(cache.entries, key, nothing)
        if saved !== nothing
            copyto!(destination, saved)
            cache.fourier_hits += 1
            return true
        end
    end
    copied = _mixed_copy!(destination, workspace, model, Val(G), kpoint)
    copied && _store_shared_fourier!(destination, workspace, model, G, kpoint)
    return copied
end

# Restore only the raw eigensystem and Fourier factors; derived masks stay clear.
function _restore_shared_spectrum!(
    workspace::MatrixElementWorkspace,
    model::AbstractResponseModel,
    kpoint,
)
    cache = _shared_interpolation_cache()
    (cache === nothing || !cache.reuse) && return false
    key = (:spectrum, _shared_group_key(workspace, model, :H, kpoint))
    saved = get(cache.entries, key, nothing)
    saved === nothing && return false
    spectrum = workspace.data.spectrum
    for field in fieldnames(KPointSpectrum)
        copyto!(getfield(spectrum, field), getfield(saved.spectrum, field))
    end
    copyto!(workspace.data.fourier_factors, saved.fourier_factors)
    workspace.data.computed_mask = _capability_bit(SPECTRUM)
    workspace.counts.capability_computations[SPECTRUM] += 1
    cache.spectrum_hits += 1
    return true
end

# Save a completed spectrum without exposing its buffers to another workspace.
function _store_shared_spectrum!(
    workspace::MatrixElementWorkspace,
    model::AbstractResponseModel,
    kpoint,
)
    cache = _shared_interpolation_cache()
    cache === nothing && return workspace.data.spectrum
    if !cache.reuse
        cache.diagonalizations += 1
        return workspace.data.spectrum
    end
    key = (:spectrum, _shared_group_key(workspace, model, :H, kpoint))
    borrowed =
        (spectrum = workspace.data.spectrum, fourier_factors = workspace.data.fourier_factors)
    if _shared_entry_fits(cache, key, borrowed)
        saved = (
            spectrum = deepcopy(workspace.data.spectrum),
            fourier_factors = copy(workspace.data.fourier_factors),
        )
        _save_shared_entry!(cache, key, saved)
    end
    cache.diagonalizations += 1
    return workspace.data.spectrum
end

# Optional completed states never force an original raw matrix or spectrum out of the cache.
function _discard_complete_snapshots!(cache::SharedInterpolationCache)
    for key in collect(keys(cache.entries))
        key isa Tuple && !isempty(key) && first(key) === :complete_capabilities || continue
        cache.retained_bytes -= _shared_entry_bytes(key, cache.entries[key])
        delete!(cache.entries, key)
        cache.evictions += 1
    end
    return nothing
end

# This exact old capability set has no denominators, band groups, spin or metric state.
_complete_capability_mask() =
    _capability_bit(SPECTRUM) | _capability_bit(HAMILTONIAN_DERIVATIVES) |
    _capability_bit(WANNIER_POSITION) | _capability_bit(INTERNAL_CONNECTION)

# Restrict the experiment to complete dense two-dimensional fixed-basis endpoint data.
function _complete_snapshot_enabled(workspace, model, cache)
    cache isa SharedInterpolationCache && cache.reuse && cache.measure_timings || return false
    cache.max_bytes != typemax(Int) || return false
    model isa AnalyticKModel && model.input.basis === :fixed_orthonormal || return false
    plan = workspace.plan
    plan.required_mask == _complete_capability_mask() && plan.source_gauge_required || return false
    plan.spatial_dimension == 2 && _mixed_provider(workspace) === nothing || return false
    data = workspace.data
    data.hamiltonian isa HamiltonianMatrixData && data.position isa PositionMatrixData ||
        return false
    data.hamiltonian.energy_differences === nothing &&
    data.hamiltonian.second_derivatives === nothing || return false
    for name in fieldnames(typeof(data.position))
        name in (:wannier_gauge, :internal_connection) && continue
        getfield(data.position, name) === nothing || return false
    end
    (data.computed_mask & ~_complete_capability_mask()) == 0 || return false
    data.spin === nothing && data.spin_velocity === nothing && data.subspace_position === nothing ||
        return false
    data.metric_external === nothing && !data.metric_completion_required || return false
    for axis in 1:2
        iszero(_axis_channel(plan, HAMILTONIAN_DERIVATIVES, axis)) && return false
        iszero(_axis_channel(plan, WANNIER_POSITION, axis)) && return false
    end
    arrays = (
        data.hamiltonian.derivatives,
        data.hamiltonian.source_gauge_derivatives,
        data.position.wannier_gauge,
        data.position.internal_connection,
    )
    all(
        a -> a isa Array{ComplexF64, 3} && size(a) == (model.num_orbitals, model.num_orbitals, 2),
        arrays,
    ) || return false
    any(Base.mightalias(arrays[i], arrays[j]) for i in 1:4 for j in (i + 1):4) && return false
    return true
end

# A private immutable-to-consumers spectrum entry supplies the frame token, never a caller's address.
function _complete_snapshot_binding(workspace, model, cache)
    data = workspace.data
    spectrum_key = (:spectrum, _shared_group_key(workspace, model, :H, data.kpoint))
    frame = get(cache.entries, spectrum_key, nothing)
    frame === nothing && return nothing
    key = (
        :complete_capabilities,
        spectrum_key,
        _shared_group_key(workspace, model, :dH, data.kpoint),
        _shared_group_key(workspace, model, :A, data.kpoint),
        objectid(frame.spectrum),
        workspace.plan.required_mask,
        workspace.plan.denominator_regularization,
        workspace.plan.degeneracy_threshold,
        data.spectral_gap_tolerance,
        size(data.hamiltonian.derivatives),
    )
    return key, frame.spectrum
end

# Exact source and canonical frames are required even for user-supplied or already-computed spectra.
_complete_frame_matches(current, saved) =
    all(isequal(getfield(current, f), getfield(saved, f)) for f in fieldnames(KPointSpectrum))

"""
Restore all old endpoint capabilities from owned buffers in the identical saved frame.
Only the original spectrum/derivative/raw-A/internal-A mask is supported. Both
canonical and source H derivatives are copied, including all diagonal and block
entries. Slot generation and spectrum remain untouched; no partial-ready state
or new public capability is introduced. Missing or foreign frames use the old path.
"""
function _restore_complete_capabilities!(workspace, model)
    cache = _shared_interpolation_cache()
    _complete_snapshot_enabled(workspace, model, cache) || return false
    data = workspace.data
    required = _complete_capability_mask()
    (data.computed_mask & required) == required && return false
    (data.computed_mask & _capability_bit(SPECTRUM)) != 0 || return false
    binding = _complete_snapshot_binding(workspace, model, cache)
    binding === nothing && return false
    key, frame = binding
    saved = get(cache.entries, key, nothing)
    saved === nothing && return false
    saved.frame === frame || return false
    _complete_frame_matches(data.spectrum, frame) || return false
    missing = required & ~data.computed_mask
    copyto!(data.hamiltonian.derivatives, saved.canonical)
    copyto!(data.hamiltonian.source_gauge_derivatives, saved.source)
    copyto!(data.position.wannier_gauge, saved.raw_connection)
    copyto!(data.position.internal_connection, saved.internal_connection)
    data.position_regularization_ev = saved.position_regularization_ev
    data.spin_degeneracy_threshold_ev = saved.spin_degeneracy_threshold_ev
    data.computed_mask |= required
    for capability in (HAMILTONIAN_DERIVATIVES, WANNIER_POSITION, INTERNAL_CONNECTION)
        (missing & _capability_bit(capability)) == 0 && continue
        workspace.counts.capability_computations[capability] += 1
    end
    cache.capability_hits += 1
    return true
end

"""
Save the complete old endpoint payload only when two such entries fit the free budget.
Snapshots own all four arrays and numerical stamps. They never replace an existing
raw/spectrum block: subsequent original stores discard these optional entries first.
Ineligible, nonfinite, small-budget or unproven-frame data continue unchanged.
"""
function _store_complete_capabilities!(workspace, model)
    cache = _shared_interpolation_cache()
    _complete_snapshot_enabled(workspace, model, cache) || return nothing
    data = workspace.data
    data.computed_mask == _complete_capability_mask() || return nothing
    binding = _complete_snapshot_binding(workspace, model, cache)
    binding === nothing && return nothing
    key, frame = binding
    haskey(cache.entries, key) && return nothing
    borrowed = (
        canonical = data.hamiltonian.derivatives,
        source = data.hamiltonian.source_gauge_derivatives,
        raw_connection = data.position.wannier_gauge,
        internal_connection = data.position.internal_connection,
        position_regularization_ev = data.position_regularization_ev,
        spin_degeneracy_threshold_ev = data.spin_degeneracy_threshold_ev,
    )
    # Keep the private frame alive; its shared buffers are conservatively charged again.
    bytes = _shared_entry_bytes(key, merge(borrowed, (frame = frame,)))
    bytes <= div(cache.max_bytes - cache.retained_bytes, 2) || return nothing
    length(cache.entries) + 2 <= cache.max_entries || return nothing
    _complete_frame_matches(data.spectrum, frame) || return nothing
    all(
        all(isfinite, a) for a in
        (borrowed.canonical, borrowed.source, borrowed.raw_connection, borrowed.internal_connection)
    ) || return nothing
    saved = merge(deepcopy(borrowed), (frame = frame,))
    _save_shared_entry!(cache, key, saved)
    return nothing
end
