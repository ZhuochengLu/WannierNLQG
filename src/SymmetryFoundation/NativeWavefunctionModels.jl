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
    source_definition::Union{Nothing, IO.ScientificInputDefinition}

    function NativeWavefunctionData(
        source_code,
        structure,
        reciprocal_lattice,
        mp_grid,
        spinor,
        kpoints,
        input_sha256,
        source_metadata = Dict{String, String}();
        source_definition::Union{Nothing, IO.ScientificInputDefinition} = nothing,
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
        source_definition === nothing ||
            isempty(input_sha256) ||
            throw(ArgumentError("NATIVE_SOURCE_MIXED_AUTHENTICATION_CONTRACT"))
        metadata = Dict{String, String}(source_metadata)
        get(metadata, "content_authentication", "") == "NOT_PERFORMED" &&
            source_definition === nothing &&
            throw(ArgumentError("NATIVE_SOURCE_COMPLETE_DEFINITION_REQUIRED"))
        if source_definition !== nothing
            metadata["content_authentication"] = "NOT_PERFORMED"
            metadata["source_consistency"] = "complete_labelled_source_bytes"
        end
        return new(
            Symbol(source_code),
            structure,
            reciprocal,
            (mesh[1], mesh[2], mesh[3]),
            Bool(spinor),
            points,
            Dict{String, String}(input_sha256),
            metadata,
            source_definition,
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
        native.source_metadata;
        source_definition = native.source_definition,
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

"""Forward preparation credential verification to the shared IO implementation."""
verified_file_digest_identity(args...; kwargs...) =
    IO.verified_file_digest_identity(args...; kwargs...)

"""Forward preparation streaming hashes to IO without caching undeclared outputs."""
sha256_file(filename::AbstractString) = IO.sha256_file(filename)

"""Preserve the preparation identity helper through the shared IO owner."""
_digest_file_identity(path::AbstractString) = IO.file_digest_identity(path)

"""Forward callback-scoped declared-input credentials to the shared IO owner."""
with_verified_file_digests(f::F, paths; kwargs...) where {F} =
    IO.with_verified_file_digests(f, paths; kwargs...)

"""
Infer a complete Monkhorst-Pack grid from fractional coordinates modulo one.
"""
function infer_mp_grid(kpoints::Matrix{Float64}; tolerance::Float64 = 1.0e-8)
    size(kpoints, 2) == 3 && size(kpoints, 1) > 0 && all(isfinite, kpoints) || throw(
        ArgumentError("MP grid inference requires nonempty finite N×3 fractional coordinates"),
    )
    isfinite(tolerance) && 0 < tolerance < 0.5 ||
        throw(ArgumentError("MP grid inference tolerance must lie in (0, 0.5)"))
    counts = Int[]
    offsets = Float64[]
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
        count = length(unique_values)
        offset = first(unique_values)
        all(
            index -> abs(unique_values[index] - offset - (index-1)/count) <= tolerance,
            eachindex(unique_values),
        ) || throw(
            ArgumentError("k-points are not uniformly spaced modulo one along axis $direction"),
        )
        push!(counts, count)
        push!(offsets, offset)
    end
    prod(counts) == size(kpoints, 1) || throw(
        ArgumentError(
            "k-points do not form one complete product mesh; inferred $(Tuple(counts)) " *
            "for $(size(kpoints, 1)) points",
        ),
    )
    dimensions = (counts[1], counts[2], counts[3])
    classified = classify_diagonal_mesh_points(
        DiagonalKMesh(dimensions, Tuple(offsets)),
        permutedims(kpoints);
        tolerance = tolerance * maximum(counts),
    )
    classified.complete || throw(ArgumentError("k-points do not fill the inferred MP grid"))
    return dimensions
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
