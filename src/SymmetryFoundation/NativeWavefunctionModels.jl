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

"""Native wavefunction data after source-specific parsing and cutoff selection."""
struct NativeWavefunctionData
    source_code::Symbol
    structure::CrystalStructure
    reciprocal_lattice::Matrix{Float64}
    mp_grid::NTuple{3, Int}
    spinor::Bool
    kpoints::Vector{PlaneWaveKPoint}
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
        points = PlaneWaveKPoint[kpoints...]
        size(reciprocal) == (3, 3) ||
            throw(ArgumentError("reciprocal lattice must have size (3, 3)"))
        prod(mesh) == length(points) ||
            throw(ArgumentError("native k-point count does not match mp_grid"))
        isempty(points) && throw(ArgumentError("native wavefunction source contains no k-points"))
        band_count = size(first(points).coefficients, 1)
        spin_components = size(first(points).coefficients, 3)
        all(point -> size(point.coefficients, 1) == band_count, points) ||
            throw(ArgumentError("native k-points do not share one band count"))
        all(point -> size(point.coefficients, 3) == spin_components, points) ||
            throw(ArgumentError("native k-points do not share one spin convention"))
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

"""
Compute one streaming SHA-256 without changing the input file.
"""
function sha256_file(filename::AbstractString)
    isfile(filename) || throw(ArgumentError("input file does not exist: $(filename)"))
    return open(filename, "r") do io
        bytes2hex(SHA.sha256(io))
    end
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
