"""Lazy native-convention coefficients for the existing bounded Fourier store.

Cartesian jets use R_cart + tau_ket - tau_bra before any eigensystem or D_eta.
The remaining orbital-center phase is applied to the extracted source arrays.
No derivative bank or second global cache is allocated.
"""
struct NonorthogonalFourierSource{G, N} <: AbstractArray{ComplexF64, N}
    model::NonorthogonalLocalizedModel
    convention::WannierCenterConvention
end

"""Expose linear indexing of the lazily packed localized Cartesian Fourier coefficients."""
Base.IndexStyle(::Type{<:NonorthogonalFourierSource}) = IndexLinear()
"""Return orbital-pair, Cartesian derivative and translation dimensions for this coefficient group."""
function Base.size(source::NonorthogonalFourierSource{G, N}) where {G, N}
    n, nr = source.model.num_orbitals, source.model.num_r_vectors
    return N == 4 ? (n, n, 3, nr) : (n, n, 3, 3, nr)
end

"""Return the Cartesian translation, including the native Convention I ket-minus-bra center shift."""
@inline function _localized_fourier_displacement(source, row, col, cell, axis)
    model = source.model
    value = sum(model.lattice[c, axis] * model.r_vectors[c, cell] for c in 1:3)
    source.convention == CONVENTION_I && (
        value +=
            model.orbital_centers_cartesian[axis, col] - model.orbital_centers_cartesian[axis, row]
    )
    return value
end

"""Evaluate one native H/S/r coefficient or Cartesian derivative without allocating a derivative bank."""
@inline function Base.getindex(source::NonorthogonalFourierSource{G, N}, index::Int) where {G, N}
    @boundscheck checkbounds(source, index)
    model = source.model;
    n = model.num_orbitals
    pair, channel_cell = mod(index-1, n*n), div(index-1, n*n)
    row, col = mod(pair, n)+1, div(pair, n)+1
    channels = N == 4 ? 3 : 9
    cell, channel = div(channel_cell, channels)+1, mod(channel_cell, channels)
    a, b = mod(channel, 3)+1, div(channel, 3)+1
    if G in (:nao_r, :nao_dr)
        value = model.position_r[row, col, a, cell]
        source.convention == CONVENTION_I &&
            (value -= model.orbital_centers_cartesian[a, row] * model.overlap_r[row, col, cell])
        return G == :nao_r ? value :
               im * _localized_fourier_displacement(source, row, col, cell, b) * value
    end
    value =
        G in (:nao_dH, :nao_ddH) ? model.hamiltonian_r[row, col, cell] :
        model.overlap_r[row, col, cell]
    displacement = _localized_fourier_displacement(source, row, col, cell, a)
    return N == 4 ? im * displacement * value :
           -displacement * _localized_fourier_displacement(source, row, col, cell, b) * value
end

"""Every localized R entry already has its declared weight; spin is counted once."""
_mixed_r_degeneracy(::NonorthogonalLocalizedModel, cell) = 1

"""Only uniform fractional full-BZ axes use this localized provider."""
function _validate_mixed_model_grid(model::NonorthogonalLocalizedModel, grid)
    grid.directions == Matrix{Float64}(I, 3, 3) && grid.r_grid == model.r_vectors || throw(
        ArgumentError(
            "localized FFT/Mixed requires uniform full-BZ fractional axes; arbitrary slices/regions use Direct",
        ),
    )
    all(isfinite, grid.origin) || throw(ArgumentError("nonfinite localized Fourier grid origin"))
    return nothing
end

"""Pack H/S and the native Cartesian operator groups requested by the capability plan."""
function _nonorthogonal_fourier_layout(model, plan)
    groups = Symbol[:H, :S]
    if any(
        kind -> has_capability(plan, kind),
        (
            HAMILTONIAN_DERIVATIVES,
            HAMILTONIAN_SECOND_DERIVATIVES,
            WANNIER_POSITION,
            INTERNAL_CONNECTION,
            INTERNAL_CONNECTION_DERIVATIVES,
            GAUGE_CORRECTION,
            BERRY_CONNECTION,
            VELOCITY_VERTICES,
            WANNIER_CURVATURE,
        ),
    )
        append!(groups, [:nao_dH, :nao_dS, :nao_ddH, :nao_ddS])
        model.position_r === nothing || append!(groups, [:nao_r, :nao_dr])
    end
    return MixedFourierLayout(groups, sum(_mixed_group_channel_count(plan, g) for g in groups))
end
"""Build the localized layout through the public model-aware constructor port."""
MixedFourierLayout(plan::MatrixElementPlan, model::NonorthogonalLocalizedModel) =
    _nonorthogonal_fourier_layout(model, plan)

"""Select localized operator groups for the workspace capability plan."""
_mixed_layout(workspace, model::NonorthogonalLocalizedModel) =
    _nonorthogonal_fourier_layout(model, workspace.plan)

"""Return the native real-space coefficient array or its lazy Cartesian derivative group."""
function _mixed_source(
    workspace::MatrixElementWorkspace,
    model::NonorthogonalLocalizedModel,
    group::Symbol,
)
    group == :H && return model.hamiltonian_r
    group == :S && return model.overlap_r
    group in (:nao_r, :nao_dr) && model.position_r === nothing && return nothing
    group in (:nao_dH, :nao_dS, :nao_ddH, :nao_ddS, :nao_r, :nao_dr) ||
        throw(ArgumentError("unknown localized Fourier source group"))
    dimensions = group in (:nao_dH, :nao_dS, :nao_r) ? 4 : 5
    return NonorthogonalFourierSource{group, dimensions}(
        model,
        workspace.plan.wannier_center_convention,
    )
end

"""Extract native unregularized H/S/r jets; reject off-grid calls before FFT work."""
function _workspace_nonorthogonal_operators(workspace, model, kpoint; full = true)
    provider = _mixed_provider(workspace)
    if provider === nothing
        started=time_ns()
        matrices=nonorthogonal_operator_matrices(
            model,
            kpoint;
            convention = workspace.plan.wannier_center_convention,
        )
        _record_direct_fourier!(workspace, (time_ns()-started)*1e-9)
        return matrices
    end
    provider.model === model || throw(ArgumentError("localized Fourier provider/model mismatch"))
    length(kpoint)==3 && all(isfinite, kpoint) ||
        throw(ArgumentError("invalid localized grid point"))
    coordinates=(kpoint-provider.grid.origin) .* collect(provider.grid.mesh)
    logical=round.(Int, coordinates)
    maximum(abs, coordinates-logical)<=1e-9 ||
        throw(ArgumentError("localized FFT/Mixed point is outside its declared uniform grid"))
    begin_mixed_kpoint!(workspace, kpoint, ntuple(a->mod(logical[a], provider.grid.mesh[a]), 3))
    n=model.num_orbitals
    h=zeros(ComplexF64, n, n);
    s=similar(h)
    function extract!(destination, group)
        _mixed_copy!(destination, workspace, model, group, kpoint) || throw(
            ArgumentError("missing planned localized Fourier group $group; no Direct fallback"),
        )
        if workspace.plan.wannier_center_convention == CONVENTION_I
            kcart=2pi*(model.lattice\kpoint)
            phases=cis.(vec(kcart'*model.orbital_centers_cartesian))
            for cell in CartesianIndices(size(destination)[3:end]), col in 1:n, row in 1:n
                destination[row, col, Tuple(cell)...] *= conj(phases[row])*phases[col]
            end
        end
        return destination
    end
    extract!(h, :H);
    extract!(s, :S)
    full || return (hamiltonian = h, overlap = s)
    :nao_dH in provider.layout.groups || return (hamiltonian = h, overlap = s)
    dh=extract!(zeros(ComplexF64, n, n, 3), :nao_dH)
    ds=extract!(zeros(ComplexF64, n, n, 3), :nao_dS)
    d2h=extract!(zeros(ComplexF64, n, n, 3, 3), :nao_ddH)
    d2s=extract!(zeros(ComplexF64, n, n, 3, 3), :nao_ddS)
    r=model.position_r === nothing ? nothing : extract!(zeros(ComplexF64, n, n, 3), :nao_r)
    dr=r === nothing ? nothing : extract!(zeros(ComplexF64, n, n, 3, 3), :nao_dr)
    return (
        hamiltonian = h,
        overlap = s,
        hamiltonian_derivatives = dh,
        overlap_derivatives = ds,
        hamiltonian_second_derivatives = d2h,
        overlap_second_derivatives = d2s,
        position = r,
        position_derivatives = dr,
    )
end
