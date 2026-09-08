"""Abstract marker for a native first-principles wavefunction source."""
abstract type AbstractWavefunctionSource end

"""
    VASPWavefunctionSource(poscar_file, wavecar_file; ...)

Describe a read-only VASP `POSCAR`/`WAVECAR` source. The selected band range is
one-based. `representation_cutoff_ev` truncates only the plane-wave basis used
to build the Bloch sewing matrices. `potcar_file` and `outcar_file` remain
optional for ordinary sewing, but native PAW AMN requires both plus the
same-run `incar_file` spin convention.
"""
struct VASPWavefunctionSource <: AbstractWavefunctionSource
    poscar_file::String
    wavecar_file::String
    potcar_file::Union{Nothing, String}
    incar_file::Union{Nothing, String}
    outcar_file::Union{Nothing, String}
    spin_basis_saxis::Union{Nothing, NTuple{3, Float64}}
    band_range::Union{Nothing, UnitRange{Int}}
    spin_channel::Int
    spinor::Union{Nothing, Bool}
    representation_cutoff_ev::Union{Nothing, Float64}
    include_time_reversal::Bool
    magnetic_moments_cartesian::Union{Nothing, Matrix{Float64}}

    function VASPWavefunctionSource(
        poscar_file::AbstractString,
        wavecar_file::AbstractString;
        potcar_file::Union{Nothing, AbstractString} = nothing,
        incar_file::Union{Nothing, AbstractString} = nothing,
        outcar_file::Union{Nothing, AbstractString} = nothing,
        spin_basis_saxis = nothing,
        band_range = nothing,
        spin_channel::Integer = 1,
        spinor::Union{Nothing, Bool} = nothing,
        representation_cutoff_ev::Union{Nothing, Real} = nothing,
        include_time_reversal::Bool = true,
        magnetic_moments_cartesian = nothing,
    )
        selected_bands = band_range === nothing ? nothing : UnitRange{Int}(band_range)
        selected_bands === nothing ||
            (first(selected_bands) > 0 && !isempty(selected_bands)) ||
            throw(ArgumentError("band_range must contain positive one-based indices"))
        spin_channel > 0 || throw(ArgumentError("spin_channel must be positive"))
        cutoff = representation_cutoff_ev === nothing ? nothing : Float64(representation_cutoff_ev)
        cutoff === nothing ||
            (isfinite(cutoff) && cutoff > 0.0) ||
            throw(ArgumentError("representation_cutoff_ev must be positive and finite"))
        moments =
            magnetic_moments_cartesian === nothing ? nothing :
            Matrix{Float64}(magnetic_moments_cartesian)
        moments === nothing ||
            size(moments, 1) == 3 ||
            throw(ArgumentError("magnetic_moments_cartesian must have size (3, num_atoms)"))
        moments === nothing ||
            all(isfinite, moments) ||
            throw(ArgumentError("magnetic_moments_cartesian must contain only finite values"))
        saxis = if spin_basis_saxis === nothing
            nothing
        else
            values = Float64.(collect(spin_basis_saxis))
            length(values) == 3 ||
                throw(ArgumentError("spin_basis_saxis must have length three"))
            all(isfinite, values) && norm(values) > 0.0 ||
                throw(ArgumentError("spin_basis_saxis must be finite and nonzero"))
            Tuple(values ./ norm(values))
        end
        return new(
            String(poscar_file),
            String(wavecar_file),
            potcar_file === nothing ? nothing : String(potcar_file),
            incar_file === nothing ? nothing : String(incar_file),
            outcar_file === nothing ? nothing : String(outcar_file),
            saxis,
            selected_bands,
            Int(spin_channel),
            spinor,
            cutoff,
            include_time_reversal,
            moments,
        )
    end
end

# Hash explicit Cartesian axial moments by dimensions and IEEE-754 bit pattern.
# Text formatting and host byte order therefore cannot change scientific identity.
function magnetic_moments_sha256(magnetic_moments_cartesian)
    moments = Matrix{Float64}(magnetic_moments_cartesian)
    size(moments, 1) == 3 ||
        throw(ArgumentError("magnetic_moments_cartesian must have size (3, num_atoms)"))
    all(isfinite, moments) ||
        throw(ArgumentError("magnetic_moments_cartesian must contain only finite values"))
    buffer = IOBuffer()
    print(buffer, size(moments, 1), 'x', size(moments, 2), '\n')
    for value in moments
        print(buffer, string(reinterpret(UInt64, value); base = 16, pad = 16), '\n')
    end
    return bytes2hex(SHA.sha256(take!(buffer)))
end

# Parse case-insensitive scalar assignments from a VASP INCAR file.
function _vasp_incar_assignments(filename::AbstractString)
    assignments = Dict{String, String}()
    for line in eachline(filename)
        uncommented = first(split(first(split(line, '!'; limit = 2)), '#'; limit = 2))
        for assignment in split(uncommented, ';')
            occursin('=', assignment) || continue
            key, value = split(assignment, '='; limit = 2)
            assignments[uppercase(strip(key))] = strip(value)
        end
    end
    return assignments
end

# Parse one VASP logical value with an input-specific error label.
function _vasp_boolean(value::AbstractString, name::AbstractString)
    normalized = uppercase(strip(value, [' ', '.']))
    normalized in ("T", "TRUE") && return true
    normalized in ("F", "FALSE") && return false
    throw(ArgumentError("$(name) must be a VASP boolean"))
end

# Expand VASP numeric lists, including count*value repetition tokens.
function _vasp_numeric_values(value::AbstractString, name::AbstractString)
    result = Float64[]
    for token in split(replace(value, ',' => ' '))
        if occursin('*', token)
            count_text, scalar_text = split(token, '*'; limit = 2)
            count = parse(Int, count_text)
            count > 0 || throw(ArgumentError("$(name) repeat count must be positive"))
            append!(
                result,
                fill(parse(Float64, replace(scalar_text, 'D' => 'E', 'd' => 'e')), count),
            )
        else
            push!(result, parse(Float64, replace(token, 'D' => 'E', 'd' => 'e')))
        end
    end
    all(isfinite, result) || throw(ArgumentError("$(name) must contain only finite values"))
    return result
end

# Construct the Cartesian axial basis associated with VASP SAXIS.
function _vasp_axial_basis(saxis::AbstractVector{<:Real})
    axis = Float64.(saxis)
    length(axis) == 3 && all(isfinite, axis) && norm(axis) > 0.0 ||
        throw(ArgumentError("SAXIS must contain one finite nonzero Cartesian vector"))
    axis ./= norm(axis)
    theta = acos(clamp(axis[3], -1.0, 1.0))
    phi = atan(axis[2], axis[1])
    first_axis = [cos(theta) * cos(phi), cos(theta) * sin(phi), -sin(theta)]
    second_axis = [-sin(phi), cos(phi), 0.0]
    return hcat(first_axis, second_axis, axis)
end

"""Reject an explicit Cartesian moment matrix that conflicts with INCAR MAGMOM."""
function validate_vasp_magnetic_moment_sources(
    source::VASPWavefunctionSource,
    atom_count::Integer;
    tolerance::Float64 = 1.0e-8,
)
    explicit = source.magnetic_moments_cartesian
    explicit === nothing && return :NOT_APPLICABLE
    size(explicit) == (3, atom_count) ||
        throw(ArgumentError("magnetic_moments_cartesian atom count disagrees with POSCAR"))
    source.incar_file === nothing && return :EXPLICIT_ONLY
    assignments = _vasp_incar_assignments(something(source.incar_file))
    haskey(assignments, "MAGMOM") || return :EXPLICIT_ONLY
    values = _vasp_numeric_values(assignments["MAGMOM"], "MAGMOM")
    noncollinear = _vasp_boolean(get(assignments, "LNONCOLLINEAR", ".FALSE."), "LNONCOLLINEAR")
    spin_orbit = _vasp_boolean(get(assignments, "LSORBIT", ".FALSE."), "LSORBIT")
    incar_moments = if noncollinear || spin_orbit
        length(values) == 3atom_count ||
            throw(ArgumentError("noncollinear VASP MAGMOM must contain 3*num_atoms values"))
        saxis =
            haskey(assignments, "SAXIS") ? _vasp_numeric_values(assignments["SAXIS"], "SAXIS") :
            [0.0, 0.0, 1.0]
        length(saxis) == 3 || throw(ArgumentError("SAXIS must contain three values"))
        _vasp_axial_basis(saxis) * reshape(values, 3, atom_count)
    else
        length(values) == atom_count ||
            throw(ArgumentError("collinear VASP MAGMOM count does not match POSCAR atoms"))
        inferred = zeros(Float64, 3, atom_count)
        nonzero = findfirst(index -> abs(values[index]) > tolerance, eachindex(values))
        if nonzero === nothing
            inferred
        else
            axis = explicit[:, something(nonzero)] ./ values[something(nonzero)]
            isfinite(norm(axis)) && abs(norm(axis) - 1.0) <= tolerance || throw(
                ArgumentError(
                    "MAGNETIC_MOMENT_SOURCE_CONFLICT: explicit Cartesian moments and collinear INCAR MAGMOM disagree",
                ),
            )
            inferred .= axis * transpose(values)
            inferred
        end
    end
    isapprox(explicit, incar_moments; atol = tolerance, rtol = tolerance) || throw(
        ArgumentError(
            "MAGNETIC_MOMENT_SOURCE_CONFLICT: explicit magnetic_moments_cartesian disagrees with INCAR MAGMOM",
        ),
    )
    return :INCAR_CONSISTENT
end

"""
    _conditioned_right_inverse(coefficients; maximum_condition=1e12)

Construct `C†(C C†)^-1` with a Hermitian Cholesky solve after explicit
numerical-rank and condition-number gates. Rank-deficient or ill-conditioned
coefficient blocks are structural representation failures; no pseudoinverse is
used.
"""
function _conditioned_right_inverse(
    coefficients::AbstractMatrix{<:Complex};
    maximum_condition::Real = 1.0e12,
)
    block = Matrix{ComplexF64}(coefficients)
    singular_values = svdvals(block)
    isempty(singular_values) && throw(ArgumentError("sewing coefficient block is empty"))
    maximum_singular = maximum(singular_values)
    rank_tolerance = max(size(block)...) * eps(Float64) * maximum_singular
    numerical_rank = count(>(rank_tolerance), singular_values)
    numerical_rank == size(block, 1) || throw(
        ArgumentError(
            "sewing coefficient block is rank deficient: rank=$(numerical_rank), " *
            "required=$(size(block, 1)), sigma_min=$(minimum(singular_values)), " *
            "rank_tolerance=$(rank_tolerance)",
        ),
    )
    condition_estimate = maximum_singular / minimum(singular_values)
    isfinite(condition_estimate) && condition_estimate <= maximum_condition || throw(
        ArgumentError(
            "sewing coefficient block is ill conditioned: condition_estimate=$(condition_estimate), " *
            "maximum_condition=$(maximum_condition)",
        ),
    )
    gram_factor = cholesky(Hermitian(block * block'); check = true)
    return adjoint(gram_factor \ block)
end

# Parse one explicit SAXIS assignment without accepting VASP's implicit default.
function _read_vasp_saxis(source::VASPWavefunctionSource)
    explicit = source.spin_basis_saxis
    source.incar_file === nothing && return explicit
    isfile(source.incar_file) ||
        throw(ArgumentError("VASP INCAR does not exist: $(source.incar_file)"))
    values = nothing
    for line in eachline(source.incar_file)
        uncommented = first(split(first(split(line, '!'; limit = 2)), '#'; limit = 2))
        matched = match(r"(?i)^\s*SAXIS\s*=\s*(.*)$", uncommented)
        matched === nothing && continue
        tokens = split(strip(matched.captures[1]))
        length(tokens) == 3 || throw(ArgumentError("INCAR SAXIS must contain three values"))
        parsed = parse.(Float64, tokens)
        all(isfinite, parsed) && norm(parsed) > 0.0 ||
            throw(ArgumentError("INCAR SAXIS must be finite and nonzero"))
        values = Tuple(parsed ./ norm(parsed))
    end
    values === nothing && throw(
        ArgumentError(
            "magnetic spinor WAVECAR requires an explicit SAXIS assignment in INCAR or spin_basis_saxis",
        ),
    )
    explicit === nothing ||
        maximum(abs, collect(values) .- collect(explicit)) <= 1.0e-12 ||
        throw(ArgumentError("INCAR SAXIS conflicts with explicit spin_basis_saxis"))
    return values
end

"""
    _vasp_saxis_spin_transform(saxis)

Return the SU(2) basis matrix whose columns are the VASP `SAXIS` up/down
spinors in the fixed Cartesian-z Pauli basis. Multiplying a stored two-component
spinor by this matrix removes the run-local spin-quantization convention.
"""
function _vasp_saxis_spin_transform(saxis::NTuple{3, Float64})
    x, y, z = saxis
    alpha = atan(y, x)
    beta = atan(hypot(x, y), z)
    cosine = cos(beta / 2)
    sine = sin(beta / 2)
    return ComplexF64[
        cosine -exp(-1.0im * alpha) * sine
        exp(1.0im * alpha) * sine cosine
    ]
end

"""Read-only Quantum Espresso wavefunction source retained for SAWF API compatibility."""
struct QuantumEspressoWavefunctionSource <: AbstractWavefunctionSource
    save_directory::String
    band_range::Union{Nothing, UnitRange{Int}}
    spin_channel::Symbol
    representation_cutoff_ev::Union{Nothing, Float64}
    include_time_reversal::Bool
    magnetic_moments_cartesian::Union{Nothing, Matrix{Float64}}

    function QuantumEspressoWavefunctionSource(
        save_directory::AbstractString;
        band_range = nothing,
        spin_channel::Symbol = :none,
        representation_cutoff_ev::Union{Nothing, Real} = nothing,
        include_time_reversal::Bool = true,
        magnetic_moments_cartesian = nothing,
    )
        spin_channel in (:none, :up, :down) ||
            throw(ArgumentError("spin_channel must be :none, :up, or :down"))
        selected_bands = band_range === nothing ? nothing : UnitRange{Int}(band_range)
        selected_bands === nothing ||
            (first(selected_bands) > 0 && !isempty(selected_bands)) ||
            throw(ArgumentError("band_range must contain positive one-based indices"))
        cutoff = representation_cutoff_ev === nothing ? nothing : Float64(representation_cutoff_ev)
        cutoff === nothing ||
            (isfinite(cutoff) && cutoff > 0.0) ||
            throw(ArgumentError("representation_cutoff_ev must be positive and finite"))
        moments =
            magnetic_moments_cartesian === nothing ? nothing :
            Matrix{Float64}(magnetic_moments_cartesian)
        moments === nothing ||
            size(moments, 1) == 3 ||
            throw(ArgumentError("magnetic_moments_cartesian must have size (3, num_atoms)"))
        return new(
            String(save_directory),
            selected_bands,
            spin_channel,
            cutoff,
            include_time_reversal,
            moments,
        )
    end
end

"""
Versioned Bloch-band representation shared by symmetrization and Wannierization.

`sewing_matrices[target_band,source_band,operation,source_kpoint]` maps source
Bloch coefficients to the target k point. Antiunitary complex conjugation is
external to the stored matrix.
"""
struct BandRepresentation
    schema_version::String
    source_code::Symbol
    spinor::Bool
    real_lattice::Matrix{Float64}
    reciprocal_lattice::Matrix{Float64}
    mp_grid::NTuple{3, Int}
    kpoints_fractional::Matrix{Float64}
    energies_ev::Matrix{Float64}
    operations::Vector{SymmetryOperation}
    kpoint_map::Matrix{Int}
    reciprocal_shifts::Array{Int, 3}
    sewing_matrices::Array{ComplexF64, 4}
    band_block_labels::Matrix{Int}
    irreducible_indices::Vector{Int}
    full_to_irreducible::Vector{Int}
    full_to_operation::Vector{Int}
    conventions::Dict{String, String}
    input_sha256::Dict{String, String}

    function BandRepresentation(
        schema_version,
        source_code,
        spinor,
        real_lattice,
        reciprocal_lattice,
        mp_grid,
        kpoints_fractional,
        energies_ev,
        operations,
        kpoint_map,
        reciprocal_shifts,
        sewing_matrices,
        band_block_labels,
        irreducible_indices,
        full_to_irreducible,
        full_to_operation;
        conventions = Dict{String, String}(),
        input_sha256 = Dict{String, String}(),
    )
        lattice = Matrix{Float64}(real_lattice)
        reciprocal = Matrix{Float64}(reciprocal_lattice)
        kpoints = Matrix{Float64}(kpoints_fractional)
        energies = Matrix{Float64}(energies_ev)
        operation_values = SymmetryOperation[operations...]
        mapping = Matrix{Int}(kpoint_map)
        shifts = Array{Int, 3}(reciprocal_shifts)
        sewing = Array{ComplexF64, 4}(sewing_matrices)
        labels = Matrix{Int}(band_block_labels)
        ibz = Int.(irreducible_indices)
        full_ibz = Int.(full_to_irreducible)
        full_operation = Int.(full_to_operation)
        mesh_values = Int.(collect(mp_grid))
        length(mesh_values) == 3 || throw(ArgumentError("mp_grid must have length three"))
        mesh = (mesh_values[1], mesh_values[2], mesh_values[3])
        size(lattice) == (3, 3) || throw(ArgumentError("real_lattice must have size (3, 3)"))
        size(reciprocal) == (3, 3) ||
            throw(ArgumentError("reciprocal_lattice must have size (3, 3)"))
        all(>(0), mesh) || throw(ArgumentError("mp_grid entries must be positive"))
        nk = size(kpoints, 1)
        nb = size(energies, 1)
        ng = length(operation_values)
        size(kpoints, 2) == 3 ||
            throw(ArgumentError("kpoints_fractional must have size (num_kpoints, 3)"))
        prod(mesh) == nk || throw(ArgumentError("mp_grid product must equal num_kpoints"))
        size(energies, 2) == nk || throw(ArgumentError("energy k-point count is inconsistent"))
        size(mapping) == (ng, nk) || throw(ArgumentError("kpoint_map has incompatible size"))
        size(shifts) == (3, ng, nk) ||
            throw(ArgumentError("reciprocal_shifts has incompatible size"))
        size(sewing) == (nb, nb, ng, nk) ||
            throw(ArgumentError("sewing_matrices has incompatible size"))
        size(labels) == size(energies) ||
            throw(ArgumentError("band_block_labels has incompatible size"))
        all(index -> 1 <= index <= nk, mapping) ||
            throw(ArgumentError("kpoint_map contains an out-of-range index"))
        length(full_ibz) == nk && length(full_operation) == nk ||
            throw(ArgumentError("full-BZ expansion vectors have incompatible length"))
        all(index -> 1 <= index <= length(ibz), full_ibz) ||
            throw(ArgumentError("full_to_irreducible contains an out-of-range index"))
        all(index -> 1 <= index <= ng, full_operation) ||
            throw(ArgumentError("full_to_operation contains an out-of-range index"))
        all(isfinite, lattice) &&
        all(isfinite, reciprocal) &&
        all(isfinite, kpoints) &&
        all(isfinite, energies) ||
            throw(ArgumentError("band representation contains non-finite real data"))
        all(isfinite, sewing) ||
            throw(ArgumentError("band representation contains non-finite sewing data"))
        return new(
            String(schema_version),
            Symbol(source_code),
            Bool(spinor),
            lattice,
            reciprocal,
            mesh,
            kpoints,
            energies,
            operation_values,
            mapping,
            shifts,
            sewing,
            labels,
            ibz,
            full_ibz,
            full_operation,
            Dict{String, String}(conventions),
            Dict{String, String}(input_sha256),
        )
    end
end

"""
Configuration for native VASP band-representation generation.

The frozen oracle is validation-only and never supplies production matrices.
"""
Base.@kwdef struct VASPBandRepresentationConfig
    # Store native VASP inputs, qualification evidence, and output paths.
    poscar_file::String
    wavecar_file::String
    incar_file::Union{Nothing, String} = nothing
    spin_basis_saxis::Union{Nothing, NTuple{3, Float64}} = nothing
    eig_file::String
    output_hdf5_file::String
    output_json_file::Union{Nothing, String} = nothing
    oracle_hdf5_file::Union{Nothing, String} = nothing
    band_range::Union{Nothing, UnitRange{Int}} = nothing
    spin_channel::Int = 1
    spinor::Bool = true
    include_time_reversal::Bool = true
    magnetic_moments_cartesian::Union{Nothing, Matrix{Float64}} = nothing
    representation_cutoff_ev::Float64 = 100.0
    degeneracy_tolerance_ev::Float64 = 0.01
    qualification_window_ev::Union{Nothing, NTuple{2, Float64}} = nothing
    symmetry_tolerance::Float64 = 1.0e-5
    require_oracle::Bool = true
    absolute_group_tolerance::Float64 = 1.0e-5
    oracle_excess_tolerance::Float64 = 1.0e-8
    overwrite::Bool = false

    function VASPBandRepresentationConfig(
        poscar_file,
        wavecar_file,
        incar_file,
        spin_basis_saxis,
        eig_file,
        output_hdf5_file,
        output_json_file,
        oracle_hdf5_file,
        band_range,
        spin_channel,
        spinor,
        include_time_reversal,
        magnetic_moments_cartesian,
        representation_cutoff_ev,
        degeneracy_tolerance_ev,
        qualification_window_ev,
        symmetry_tolerance,
        require_oracle,
        absolute_group_tolerance,
        oracle_excess_tolerance,
        overwrite,
    )
        moments =
            magnetic_moments_cartesian === nothing ? nothing :
            Matrix{Float64}(magnetic_moments_cartesian)
        moments === nothing ||
            size(moments, 1) == 3 ||
            throw(ArgumentError("magnetic_moments_cartesian must have size (3, num_atoms)"))
        moments === nothing ||
            all(isfinite, moments) ||
            throw(ArgumentError("magnetic_moments_cartesian must contain only finite values"))
        return new(
            String(poscar_file),
            String(wavecar_file),
            incar_file === nothing ? nothing : String(incar_file),
            spin_basis_saxis,
            String(eig_file),
            String(output_hdf5_file),
            output_json_file === nothing ? nothing : String(output_json_file),
            oracle_hdf5_file === nothing ? nothing : String(oracle_hdf5_file),
            band_range,
            Int(spin_channel),
            Bool(spinor),
            Bool(include_time_reversal),
            moments,
            Float64(representation_cutoff_ev),
            Float64(degeneracy_tolerance_ev),
            qualification_window_ev,
            Float64(symmetry_tolerance),
            Bool(require_oracle),
            Float64(absolute_group_tolerance),
            Float64(oracle_excess_tolerance),
            Bool(overwrite),
        )
    end
end
