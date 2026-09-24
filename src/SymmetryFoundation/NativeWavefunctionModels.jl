const NATIVE_WAVECAR_ENERGY_FACTOR = 0.26246582250211
const BOHR_TO_ANGSTROM = 0.529177210903
const HARTREE_TO_EV = 27.211386245988

# Promote raw source coefficients before applying one deterministic Float64 norm.
function normalize_plane_wave_coefficients(coefficients)
    values = Array{ComplexF64, 3}(coefficients)
    for band in axes(values, 1)
        state_norm = norm(@view values[band, :, :])
        state_norm > 1.0e-14 ||
            throw(ArgumentError("cutoff plane-wave state $(band) has zero norm"))
        @views values[band, :, :] ./= state_norm
    end
    return values
end

"""Plane-wave coefficients, energies, and reciprocal indices at one k-point."""
struct PlaneWaveKPoint
    k_fractional::Vector{Float64}
    g_vectors::Matrix{Int}
    coefficients::Array{ComplexF64, 3}
    energies_ev::Vector{Float64}

    function PlaneWaveKPoint(
        k_fractional,
        g_vectors,
        coefficients,
        energies_ev;
        normalize_coefficients::Bool = true,
    )
        kpoint = Vector{Float64}(k_fractional)
        vectors = Matrix{Int}(g_vectors)
        values =
            normalize_coefficients ? normalize_plane_wave_coefficients(coefficients) :
            Array{ComplexF64, 3}(coefficients)
        energies = Float64.(energies_ev)
        length(kpoint) == 3 || throw(ArgumentError("k-point must have length three"))
        size(vectors, 2) == 3 || throw(ArgumentError("G vectors must have three columns"))
        size(values, 2) == size(vectors, 1) ||
            throw(ArgumentError("coefficient and G-vector counts disagree"))
        size(values, 1) == length(energies) ||
            throw(ArgumentError("coefficient and energy band counts disagree"))
        size(values, 3) in (1, 2) ||
            throw(ArgumentError("plane-wave coefficients must be scalar or two-component spinors"))
        # IrRep normalizes every truncated plane-wave state independently.  Do
        # not orthogonalize the complete band set here: doing so mixes states
        # with different eigenvalues and changes the energy-block gauge used
        # to construct the representation.
        return new(kpoint, vectors, values, energies)
    end
end

"""Validate coefficient dimensions in one pass, including disk-backed providers."""
function _native_point_dimensions(points)
    first_point = first(points)
    dimensions = (size(first_point.coefficients, 1), size(first_point.coefficients, 3))
    for index in 2:length(points)
        point = points[index]
        size(point.coefficients, 1) == dimensions[1] ||
            throw(ArgumentError("native k-points do not share one band count"))
        size(point.coefficients, 3) == dimensions[2] ||
            throw(ArgumentError("native k-points do not share one spin convention"))
    end
    return dimensions
end

"""Metadata-indexed source whose decoded blocks are dimension-checked on access.

The reader validates every record header before constructing this provider. Large
coefficient blocks are validated when consumed, without an eager validation scan.
"""
struct IndexedPlaneWavePoints{V <: AbstractVector{PlaneWaveKPoint}} <:
       AbstractVector{PlaneWaveKPoint}
    parent::V
    coordinates::Vector{Vector{Float64}}
    energies::Vector{Vector{Float64}}
    num_bands::Int
    spin_components::Int
end
"""Use linear k-point indexing for the metadata-indexed source."""
Base.IndexStyle(::Type{<:IndexedPlaneWavePoints}) = IndexLinear()
"""Expose the validated source record count without decoding coefficients."""
Base.size(points::IndexedPlaneWavePoints) = size(points.parent)
"""Validate decoded dimensions against the source record metadata."""
function Base.getindex(points::IndexedPlaneWavePoints, index::Int)
    point = points.parent[index]
    size(point.coefficients, 1) == points.num_bands ||
        throw(ArgumentError("native k-points do not share one band count"))
    size(point.coefficients, 3) == points.spin_components ||
        throw(ArgumentError("native k-points do not share one spin convention"))
    return point
end
"""Use already checked record dimensions; block reads retain their own checks."""
_native_point_dimensions(points::IndexedPlaneWavePoints) =
    (points.num_bands, points.spin_components)

"""Native wavefunction data after source-specific parsing and cutoff selection."""
struct NativeWavefunctionData
    source_code::Symbol
    structure::CrystalStructure
    reciprocal_lattice::Matrix{Float64}
    mp_grid::NTuple{3, Int}
    spinor::Bool
    kpoints::AbstractVector{PlaneWaveKPoint}
    input_sha256::Dict{String, String}
    source_metadata::Dict{String, String}

    function NativeWavefunctionData(
        source_code,
        structure,
        reciprocal_lattice,
        mp_grid,
        spinor,
        kpoints,
        input_sha256,
        source_metadata = Dict{String, String}(),
    )
        reciprocal = Matrix{Float64}(reciprocal_lattice)
        mesh = Tuple(Int.(mp_grid))
        points =
            kpoints isa AbstractVector{PlaneWaveKPoint} && !(kpoints isa Vector) ? kpoints :
            PlaneWaveKPoint[kpoints...]
        size(reciprocal) == (3, 3) ||
            throw(ArgumentError("reciprocal lattice must have size (3, 3)"))
        prod(mesh) == length(points) ||
            throw(ArgumentError("native k-point count does not match mp_grid"))
        isempty(points) && throw(ArgumentError("native wavefunction source contains no k-points"))
        band_count, spin_components = _native_point_dimensions(points)
        Bool(spinor) == (spin_components == 2) ||
            throw(ArgumentError("native spinor flag disagrees with coefficient storage"))
        return new(
            Symbol(source_code),
            structure,
            reciprocal,
            (mesh[1], mesh[2], mesh[3]),
            Bool(spinor),
            points,
            Dict{String, String}(input_sha256),
            Dict{String, String}(source_metadata),
        )
    end
end

# Reapply Euclidean per-band coefficient-gauge normalization without claiming a physical metric.
function _normalized_native_wavefunctions(native::NativeWavefunctionData)
    points = [
        PlaneWaveKPoint(
            point.k_fractional,
            point.g_vectors,
            point.coefficients,
            point.energies_ev;
            normalize_coefficients = true,
        ) for point in native.kpoints
    ]
    return NativeWavefunctionData(
        native.source_code,
        native.structure,
        native.reciprocal_lattice,
        native.mp_grid,
        native.spinor,
        points,
        native.input_sha256,
        native.source_metadata,
    )
end

"""Return source metadata without decoding indexed coefficient blocks.

The fallback preserves eager and transformed native datasets. Returned arrays are
borrowed read-only metadata, just like the corresponding PlaneWaveKPoint fields.
"""
function native_point_metadata(native::NativeWavefunctionData, index::Int)
    points = native.kpoints
    checkbounds(points, index)
    if points isa IndexedPlaneWavePoints
        return (;
            k_fractional = points.coordinates[index],
            energies_ev = points.energies[index],
            num_bands = points.num_bands,
            spin_components = points.spin_components,
        )
    end
    point = points[index]
    return (;
        point.k_fractional,
        point.energies_ev,
        num_bands = size(point.coefficients, 1),
        spin_components = size(point.coefficients, 3),
    )
end

"""Verify content again after a metadata-only identity change.

The identity is `(device, inode, size, mtime, ctime)` and the digest is the
previously verified hexadecimal SHA-256. Return an updated identity without
mutating the caller's credential. A changed ctime can reflect filesystem metadata
updates; accept it only after comparing a fresh content digest. Other identity
changes or a content mismatch raise an ArgumentError with `change_error`.

This non-exported integration contract is shared by preparation and operator
attestations; unchanged identities require no content read.
"""
function verified_file_digest_identity(
    path,
    identity,
    digest;
    file_hasher = p -> open(io -> bytes2hex(SHA.sha256(io)), p, "r"),
    change_error = "VERIFIED_INPUT_CHANGED",
)
    current = _digest_file_identity(path)
    current == identity && return current
    current[1:4] == identity[1:4] || throw(ArgumentError("$(change_error): $(path)"))
    observed = file_hasher(path)
    after = _digest_file_identity(path)
    after[1:4] == current[1:4] && observed == digest ||
        throw(ArgumentError("$(change_error): $(path)"))
    # Keep the identity captured immediately before the verified content read.
    # Some filesystems publish a delayed ctime-only refresh after metadata
    # changes.  Returning `after` would then force an unnecessary third hash
    # on the next lookup despite the checked content and stable device/inode,
    # size, and mtime.  A later identity change still re-enters this strict
    # verification path.
    return current
end

"""Compute a streaming SHA-256, reusing a verified execution-scoped credential."""
function sha256_file(filename::AbstractString)
    isfile(filename) || throw(ArgumentError("input file does not exist: $(filename)"))
    registry = get(task_local_storage(), :wannier_verified_file_digests, nothing)
    if registry !== nothing
        path = realpath(filename)
        if haskey(registry, path)
            identity, digest = registry[path]
            current = verified_file_digest_identity(path, identity, digest)
            if current != identity
                refreshed = copy(registry)
                refreshed[path] = (current, digest)
                task_local_storage(:wannier_verified_file_digests, refreshed)
            end
            return digest
        end
    end
    return open(filename, "r") do io
        bytes2hex(SHA.sha256(io))
    end
end

"""Identify changes to an already content-verified input within one execution scope."""
function _digest_file_identity(path::AbstractString)
    information = stat(path)
    return (
        information.device,
        information.inode,
        information.size,
        information.mtime,
        information.ctime,
    )
end

"""Verify declared inputs once and reuse their digests only for the callback lifetime.

The registry is immutable once shared and never serialized. Nested scopes and
metadata refreshes use private copies. A ctime-only change requires a fresh
content match before replacing the task-local credential. Undeclared files retain
streaming hashes.
"""
function with_verified_file_digests(f::F, paths; file_hasher = sha256_file) where {F}
    parent = get(task_local_storage(), :wannier_verified_file_digests, nothing)
    registry = parent === nothing ? Dict{String, Tuple{Tuple, String}}() : copy(parent)
    for filename in paths
        path = realpath(filename)
        if haskey(registry, path)
            identity, digest = registry[path]
            registry[path] = (verified_file_digest_identity(path, identity, digest), digest)
            continue
        end
        before = _digest_file_identity(path)
        digest = file_hasher(path)
        after = verified_file_digest_identity(
            path,
            before,
            digest;
            change_error = "INPUT_CHANGED_DURING_DIGEST",
        )
        registry[path] = (after, digest)
    end
    return task_local_storage(f, :wannier_verified_file_digests, registry)
end

"""
Infer a complete Monkhorst-Pack grid from fractional coordinates modulo one.
"""
function infer_mp_grid(kpoints::Matrix{Float64}; tolerance::Float64 = 1.0e-8)
    counts = Int[]
    for direction in 1:3
        values = mod.(kpoints[:, direction], 1.0)
        values[abs.(values .- 1.0) .<= tolerance] .= 0.0
        values[abs.(values) .<= tolerance] .= 0.0
        sort!(values)
        unique_values = Float64[]
        for value in values
            isempty(unique_values) || abs(value - last(unique_values)) > tolerance || continue
            push!(unique_values, value)
        end
        push!(counts, length(unique_values))
    end
    prod(counts) == size(kpoints, 1) || throw(
        ArgumentError(
            "k-points do not form one complete product mesh; inferred $(Tuple(counts)) " *
            "for $(size(kpoints, 1)) points",
        ),
    )
    return (counts[1], counts[2], counts[3])
end

"""
Return plane-wave kinetic energy in eV for fractional k+G coordinates.
"""
function plane_wave_energy_ev(
    fractional::AbstractVector{<:Real},
    reciprocal_lattice::Matrix{Float64},
)
    cartesian = transpose(reciprocal_lattice) * fractional
    return dot(cartesian, cartesian) / NATIVE_WAVECAR_ENERGY_FACTOR
end

"""
Select a validated one-based band range against an available band count.
"""
function selected_band_range(range::Union{Nothing, UnitRange{Int}}, band_count::Int)
    selected = range === nothing ? (1:band_count) : range
    first(selected) >= 1 && last(selected) <= band_count ||
        throw(ArgumentError("selected band range $(selected) exceeds 1:$(band_count)"))
    return selected
end
