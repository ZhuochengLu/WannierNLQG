# One bounded endpoint cache; borrowed arrays expire on slot reevaluation.
function _bare_position_cache(data::KPointMatrixData)
    cache = data.subspace_position
    if cache === nothing
        cache = SubspacePositionCache(
            data.generation,
            UInt8(0),
            nothing,
            nothing,
            nothing,
            nothing,
            nothing,
            nothing,
            nothing,
            nothing,
        )
        data.subspace_position = cache
    elseif cache.generation != data.generation
        cache.generation = data.generation
        cache.valid_mask = UInt8(0)
    end
    return cache
end

"""Return the lazily filled bare eigenvector correction for the selected prepared frame; the cache owns the returned array."""
function _bare_correction(data::KPointMatrixData, cache, source_gauge::Bool)
    _has_capability(data.computed_mask, HAMILTONIAN_DERIVATIVES) ||
        throw(ArgumentError("BARE_POSITION_DERIVATIVES_NOT_COMPUTED"))
    data.position isa PositionMatrixData ||
        throw(ArgumentError("BARE_POSITION_ORTHOGONAL_PAYLOAD_REQUIRED"))
    derivatives =
        source_gauge ? data.hamiltonian.source_gauge_derivatives : data.hamiltonian.derivatives
    derivatives === nothing && throw(ArgumentError("BARE_POSITION_FRAME_NOT_PREPARED"))
    bit = source_gauge ? _POSITION_SOURCE_D0 : _POSITION_WORKING_D0
    output = source_gauge ? cache.source_gauge_correction : cache.gauge_correction
    if output === nothing
        output = similar(derivatives)
        if source_gauge
            cache.source_gauge_correction = output
        else
            cache.gauge_correction = output
        end
    end
    if iszero(cache.valid_mask & bit)
        size(output) == size(derivatives) || throw(DimensionMismatch("bare position slot shape"))
        eigenvector_corrections!(output, data.spectrum.energies, derivatives, Val(:bare))
        cache.valid_mask |= bit
    end
    return output
end

"""Read cached orthogonal r0=A+i*h*I0 without a spectral-position solve.

Only prepared directions and the selected frame are valid. Source readers require
source-gauge preparation. Aliases expire on slot reevaluation. Regularized
Conventional arrays remain untouched; exact projector derivatives retain the
independent solve_subspace_position! contract.
"""
function subspace_connection(data::KPointMatrixData; source_gauge::Bool = false)
    _has_capability(data.computed_mask, INTERNAL_CONNECTION) ||
        throw(ArgumentError("BARE_POSITION_RAW_CONNECTION_NOT_COMPUTED"))
    data.position isa PositionMatrixData ||
        throw(ArgumentError("BARE_POSITION_ORTHOGONAL_PAYLOAD_REQUIRED"))
    cache = _bare_position_cache(data)
    correction = _bare_correction(data, cache, source_gauge)
    bit = source_gauge ? _POSITION_SOURCE_R0 : _POSITION_WORKING_R0
    output = source_gauge ? cache.source_connection : cache.connection
    if output === nothing
        output = similar(correction)
        if source_gauge
            cache.source_connection = output
        else
            cache.connection = output
        end
    end
    if iszero(cache.valid_mask & bit)
        if source_gauge &&
           cache.source_rotation_scratch === nothing &&
           !all(iszero, data.position.wannier_gauge)
            count = length(data.spectrum.energies)
            cache.source_rotation_scratch = Matrix{ComplexF64}(undef, count, count)
        end
        raw_position_connections!(
            output,
            data;
            source_gauge,
            scratch = cache.source_rotation_scratch,
        )
        position_vertices!(output, output, correction)
        cache.valid_mask |= bit
    end
    return output
end

"""Read the legacy (E_n-E_m) inverse orientation for the explicit bare position role.

No A/D/r is materialized. Independent frequency, metric and projector denominators
retain their own definitions.
"""
function subspace_inverse_energy_differences(data::KPointMatrixData)
    _has_capability(data.computed_mask, SPECTRUM) ||
        throw(ArgumentError("BARE_POSITION_SPECTRUM_NOT_COMPUTED"))
    cache = _bare_position_cache(data)
    output = cache.inverse_energy_differences
    count = length(data.spectrum.energies)
    if output === nothing
        output = Matrix{Float64}(undef, count, count)
        cache.inverse_energy_differences = output
    end
    if iszero(cache.valid_mask & _POSITION_BARE_INVERSE)
        energies = data.spectrum.energies
        for m in eachindex(energies), n in eachindex(energies)
            inverse = bare_energy_inverse(energies[m] - energies[n])
            output[n, m] = iszero(inverse) ? 0.0 : -inverse
        end
        cache.valid_mask |= _POSITION_BARE_INVERSE
    end
    return output
end

"""Read working-frame D0 without materializing r or a source-frame array."""
function subspace_gauge_correction(data::KPointMatrixData)
    return _bare_correction(data, _bare_position_cache(data), false)
end

"""Read optical i(E_n-E_m)r0, distinct from complete physical V including h_nn."""
function subspace_velocity_vertices(data::KPointMatrixData; source_gauge::Bool = false)
    connection = subspace_connection(data; source_gauge)
    cache = _bare_position_cache(data)
    bit = source_gauge ? _POSITION_SOURCE_OPTICAL : _POSITION_WORKING_OPTICAL
    output = source_gauge ? cache.source_velocity_vertices : cache.velocity_vertices
    if output === nothing
        output = similar(connection)
        if source_gauge
            cache.source_velocity_vertices = output
        else
            cache.velocity_vertices = output
        end
    end
    if iszero(cache.valid_mask & bit)
        energies = data.spectrum.energies
        for axis in axes(connection, 3), m in eachindex(energies), n in eachindex(energies)
            output[n, m, axis] = im * (energies[n] - energies[m]) * connection[n, m, axis]
        end
        cache.valid_mask |= bit
    end
    return output
end

"""Copy raw A into an endpoint frame without constructing r or inverse gaps.

Only requested Cartesian slices are overwritten. Source-frame rotation reuses
supplied matrix scratch; working-frame A already uses the endpoint eigensystem.
Ordinary orthogonal payloads are required; this is not a metric adapter.
"""
function raw_position_connections!(
    output,
    data::KPointMatrixData;
    source_gauge::Bool = false,
    directions = axes(output, 3),
    scratch = nothing,
)
    _has_capability(data.computed_mask, INTERNAL_CONNECTION) ||
        throw(ArgumentError("RAW_POSITION_CONNECTION_NOT_COMPUTED"))
    data.position isa PositionMatrixData ||
        throw(ArgumentError("RAW_POSITION_ORTHOGONAL_CONNECTION_REQUIRED"))
    raw = source_gauge ? data.position.wannier_gauge : data.position.internal_connection
    raw === nothing && throw(ArgumentError("RAW_POSITION_CONNECTION_NOT_PREPARED"))
    size(output, 1) == size(output, 2) == length(data.spectrum.energies) ||
        throw(DimensionMismatch("raw position endpoint band axes required"))
    if all(iszero, raw)
        for axis in directions
            fill!(@view(output[:, :, axis]), COMPLEX_ZERO)
        end
    elseif source_gauge
        vectors = data.spectrum.source_eigenvectors
        temporary =
            scratch === nothing ? Matrix{ComplexF64}(undef, size(output, 1), size(output, 2)) :
            scratch
        @views for axis in directions
            mul!(temporary, raw[:, :, axis], vectors)
            mul!(output[:, :, axis], adjoint(vectors), temporary)
        end
    else
        @views for axis in directions
            output[:, :, axis] .= raw[:, :, axis]
        end
    end
    return output
end

"""Return full endpoint physical velocity without requesting r or a gap inverse.

Ordinary orthogonal data must have raw A and first H derivatives prepared. The
source-frame form rotates the raw Wannier connection by source eigenvectors;
working-frame data use the already rotated internal connection. The returned
array is caller-owned except when raw A vanishes identically, when it is a
read-only alias of the prepared derivative array. No metric extension is implied.
"""
function physical_velocity_vertices(data::KPointMatrixData; source_gauge::Bool = false)
    _has_capability(data.computed_mask, HAMILTONIAN_DERIVATIVES) ||
        throw(ArgumentError("PHYSICAL_VELOCITY_DERIVATIVES_NOT_COMPUTED"))
    _has_capability(data.computed_mask, INTERNAL_CONNECTION) ||
        throw(ArgumentError("PHYSICAL_VELOCITY_RAW_CONNECTION_NOT_COMPUTED"))
    data.position isa PositionMatrixData ||
        throw(ArgumentError("PHYSICAL_VELOCITY_ORTHOGONAL_RAW_CONNECTION_REQUIRED"))
    derivatives =
        source_gauge ? data.hamiltonian.source_gauge_derivatives : data.hamiltonian.derivatives
    raw = source_gauge ? data.position.wannier_gauge : data.position.internal_connection
    derivatives === nothing && throw(ArgumentError("PHYSICAL_VELOCITY_DERIVATIVES_NOT_PREPARED"))
    raw === nothing && throw(ArgumentError("PHYSICAL_VELOCITY_RAW_CONNECTION_NOT_PREPARED"))
    all(iszero, raw) && return derivatives
    output = similar(derivatives)
    raw_position_connections!(output, data; source_gauge)
    physical_velocity_vertices!(output, data.spectrum.energies, derivatives, output)
    return output
end

# Validate the public reader's exact axis demand before overwriting any slice.
function _validate_position_reader_axes(output, plan, kind, directions)
    seen = UInt8(0)
    for axis in directions
        checkbounds(output,:,:,axis)
        _axis_required(plan, kind, axis) ||
            throw(ArgumentError("POSITION_READER_DIRECTION_NOT_REQUESTED"))
        bit = UInt8(1) << (Int(axis) - 1)
        iszero(seen & bit) || throw(ArgumentError("POSITION_READER_DUPLICATE_DIRECTION"))
        seen |= bit
    end
    return nothing
end

"""Fill orthogonal D0 or D_eta from a prepared workspace using only E/h.

The caller owns output, and only requested directions are overwritten. The source
frame uses its prepared h array. No A/r/curvature payload is requested or created.
Metric workspaces require their independent tangent prescription and are rejected.
"""
function eigenvector_corrections!(
    output,
    workspace::MatrixElementWorkspace,
    role::Union{Val{:bare}, Val{:regularized}};
    source_gauge::Bool = false,
    denominator_regularization = workspace.plan.denominator_regularization,
    directions = axes(output, 3),
)
    workspace.scratch isa MatrixElementScratch ||
        throw(ArgumentError("ORTHOGONAL_EIGENVECTOR_CORRECTION_REQUIRED"))
    source_gauge &&
        !workspace.plan.source_gauge_required &&
        throw(ArgumentError("EIGENVECTOR_CORRECTION_SOURCE_FRAME_NOT_REQUESTED"))
    data = workspace.data
    _has_capability(data.computed_mask, HAMILTONIAN_DERIVATIVES) ||
        throw(ArgumentError("EIGENVECTOR_CORRECTION_DERIVATIVES_NOT_COMPUTED"))
    derivatives =
        source_gauge ? data.hamiltonian.source_gauge_derivatives : data.hamiltonian.derivatives
    derivatives === nothing && throw(ArgumentError("EIGENVECTOR_CORRECTION_FRAME_NOT_PREPARED"))
    size(output, 1) == size(output, 2) == length(data.spectrum.energies) ||
        throw(DimensionMismatch("eigenvector correction band axes required"))
    if role isa Val{:regularized}
        isfinite(denominator_regularization) && denominator_regularization > 0 ||
            throw(ArgumentError("position regularization must be finite and positive"))
    end
    _validate_position_reader_axes(output, workspace.plan, HAMILTONIAN_DERIVATIVES, directions)
    for axis in directions
        checkbounds(derivatives,:,:,axis)
    end
    @views for axis in directions
        if role isa Val{:bare}
            eigenvector_corrections!(
                output[:, :, axis:axis],
                data.spectrum.energies,
                derivatives[:, :, axis:axis],
                role,
            )
        else
            eigenvector_corrections!(
                output[:, :, axis:axis],
                data.spectrum.energies,
                derivatives[:, :, axis:axis],
                role,
                denominator_regularization,
            )
        end
    end
    return output
end

"""Fill explicit orthogonal r0 or r_eta using caller-owned D scratch.

A and h must already be prepared in the chosen frame; no other capabilities are
created. Output and correction scratch must be distinct. Only requested slices
are overwritten, and all buffers belong to the current execution slot.
"""
function position_vertices!(
    output,
    workspace::MatrixElementWorkspace,
    role::Union{Val{:bare}, Val{:regularized}},
    correction_scratch;
    source_gauge::Bool = false,
    denominator_regularization = workspace.plan.denominator_regularization,
    directions = axes(output, 3),
)
    Base.mightalias(output, correction_scratch) &&
        throw(ArgumentError("position and correction scratch must be distinct"))
    size(output) == size(correction_scratch) ||
        throw(DimensionMismatch("position/correction scratch shapes"))
    _validate_position_reader_axes(output, workspace.plan, INTERNAL_CONNECTION, directions)
    eigenvector_corrections!(
        correction_scratch,
        workspace,
        role;
        source_gauge,
        denominator_regularization,
        directions,
    )
    raw_position_connections!(
        output,
        workspace.data;
        source_gauge,
        directions,
        scratch = workspace.scratch.matrix_temporary,
    )
    @views for axis in directions
        position_vertices!(output[:, :, axis], output[:, :, axis], correction_scratch[:, :, axis])
    end
    return output
end
