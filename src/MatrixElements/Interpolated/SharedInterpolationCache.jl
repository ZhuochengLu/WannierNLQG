"""
Worker-local raw Fourier and eigensystem cache for one central k-point generation.

Only parameter-independent interpolation data are copied between task workspaces;
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
end

# Construct an empty worker-local cache with cumulative counters initialized to zero.
SharedInterpolationCache(; reuse::Bool = true) =
    SharedInterpolationCache(reuse, Dict{Any, Any}(), 0, 0, 0, 0, 0, 0)

const _SHARED_INTERPOLATION_TLS_KEY = :wanniernlqg_shared_interpolation

"""Clear cached points for a new central-point generation, retaining cumulative counters."""
function begin_shared_interpolation!(cache::SharedInterpolationCache)
    empty!(cache.entries)
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
    return (
        reuse_enabled = cache.reuse,
        generations = cache.generations,
        fourier_evaluations = cache.fourier_evaluations,
        diagonalizations = cache.diagonalizations,
        fourier_hits = cache.fourier_hits,
        spectrum_hits = cache.spectrum_hits,
        entries = length(cache.entries),
        peak_entries = cache.peak_entries,
    )
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
    model::TightBindingModel,
    group::Symbol,
)
    group in (:H, :dH, :ddH) && return objectid(model.hamiltonian_r)
    group in (:A, :dA) && return objectid(model.position_r)
    return objectid(_mixed_source(workspace, model, group))
end

# Encode each group's compact directional channels without response numerical controls.
function _shared_group_key(
    workspace::MatrixElementWorkspace,
    model::TightBindingModel,
    group::Symbol,
    kpoint,
)
    plan = workspace.plan
    directions =
        group === :H ? UInt16(0) :
        _direction_mask(plan.direction_requirements, _mixed_group_kind(group))
    return (
        objectid(model),
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
    model::TightBindingModel,
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
        cache.entries[key] = copy(destination)
        cache.fourier_evaluations += 1
        cache.peak_entries = max(cache.peak_entries, length(cache.entries))
    end
    return destination
end

# Reuse raw cached channels or delegate unchanged to the existing Mixed provider.
function _shared_or_mixed_copy!(
    destination,
    workspace::MatrixElementWorkspace,
    model::TightBindingModel,
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
    model::TightBindingModel,
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
    model::TightBindingModel,
    kpoint,
)
    cache = _shared_interpolation_cache()
    cache === nothing && return workspace.data.spectrum
    if !cache.reuse
        cache.diagonalizations += 1
        return workspace.data.spectrum
    end
    key = (:spectrum, _shared_group_key(workspace, model, :H, kpoint))
    cache.entries[key] = (
        spectrum = deepcopy(workspace.data.spectrum),
        fourier_factors = copy(workspace.data.fourier_factors),
    )
    cache.diagonalizations += 1
    cache.peak_entries = max(cache.peak_entries, length(cache.entries))
    return workspace.data.spectrum
end
