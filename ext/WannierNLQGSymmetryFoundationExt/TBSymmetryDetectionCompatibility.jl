module TBSymmetryDetectionCompatibility

using LinearAlgebra
using Spglib
using ..WannierNLQGSymmetryFoundationExt:
    CrystalStructure, MagneticSymmetryInventory, SymmetryOperation

# Assign deterministic integer species types without interpreting label suffixes.
function _species_type_numbers(species::Vector{String})
    type_by_species = Dict{String, Int}()
    return [get!(type_by_species, label, length(type_by_species) + 1) for label in species]
end

# Convert a fractional-coordinate operation to a Cartesian polar operation.
function _fractional_to_cartesian_rotation(
    rotation_fractional::AbstractMatrix{<:Integer},
    lattice::Matrix{Float64},
    ;
    orthogonality_policy::Symbol = :error,
)
    orthogonality_policy in (:error, :warn) ||
        throw(ArgumentError("orthogonality_policy must be :error or :warn"))
    lattice_transpose = transpose(lattice)
    rotation_cartesian =
        Matrix{Float64}(lattice_transpose * rotation_fractional * inv(lattice_transpose))
    rotation_cartesian[abs.(rotation_cartesian) .< 1.0e-12] .= 0.0
    residual = maximum(abs, rotation_cartesian' * rotation_cartesian - Matrix{Float64}(I, 3, 3))
    if residual > 1.0e-8
        message =
            "Spglib fractional rotation Cartesian orthogonality residual $(residual) " *
            "exceeds warning threshold 1.0e-8"
        orthogonality_policy == :error ? throw(ArgumentError(message)) : @warn message
    end
    return rotation_cartesian
end

# Normalize tiny fractional translations for deterministic operation matching.
function _clean_fractional_translation(translation)
    result = mod.(Vector{Float64}(translation), 1.0)
    result[isapprox.(result, 0.0; atol = 1.0e-12, rtol = 0.0)] .= 0.0
    result[isapprox.(result, 1.0; atol = 1.0e-12, rtol = 0.0)] .= 0.0
    return result
end

# Convert Spglib arrays into the project symmetry-operation model.
function _build_symmetry_operations(
    rotations,
    translations,
    antiunitary_flags,
    lattice::Matrix{Float64},
    ;
    orthogonality_policy::Symbol = :error,
)
    length(rotations) == length(translations) == length(antiunitary_flags) ||
        throw(ArgumentError("symmetry operation arrays have inconsistent lengths"))
    operations = SymmetryOperation[]
    for index in eachindex(rotations)
        rotation_fractional = Matrix{Int}(rotations[index])
        push!(
            operations,
            SymmetryOperation(
                rotation_fractional,
                _clean_fractional_translation(translations[index]),
                _fractional_to_cartesian_rotation(
                    rotation_fractional,
                    lattice;
                    orthogonality_policy,
                ),
                antiunitary_flags[index],
                check_cartesian_orthogonality = orthogonality_policy == :error,
            ),
        )
    end
    isempty(operations) && throw(ArgumentError("Spglib returned no symmetry operations"))
    return operations
end

"""
Detect and classify spatial or magnetic symmetry from a WIN-authoritative structure.

Nonmagnetic structures optionally receive a grey-group antiunitary copy of every
spatial operation. Magnetic moments are Cartesian axial vectors passed to
Spglib; antiunitary flags then come from the magnetic dataset. Returned order is
the deterministic backend order and no k mesh participates in detection.
"""
function detect_magnetic_symmetry_inventory(
    structure::CrystalStructure;
    include_time_reversal::Bool = true,
    symmetry_tolerance::Real = 1.0e-5,
    cartesian_orthogonality_policy::Symbol = :error,
)
    tolerance = Float64(symmetry_tolerance)
    isfinite(tolerance) && tolerance > 0.0 ||
        throw(ArgumentError("symmetry_tolerance must be positive and finite"))
    positions =
        [Vector(structure.positions_fractional[:, atom]) for atom in eachindex(structure.species)]
    atom_types = _species_type_numbers(structure.species)
    if structure.magnetic_moments_cartesian === nothing
        cell = Spglib.Cell(transpose(structure.lattice), positions, atom_types)
        dataset = Spglib.get_dataset(cell, tolerance)
        dataset === nothing && throw(ArgumentError("Spglib could not detect the space group"))
        rotations = collect(dataset.rotations)
        translations = collect(dataset.translations)
        antiunitary = falses(length(rotations))
        if include_time_reversal
            rotations = vcat(rotations, rotations)
            translations = vcat(translations, translations)
            antiunitary = vcat(antiunitary, trues(length(antiunitary)))
        end
        operations = _build_symmetry_operations(
            rotations,
            translations,
            antiunitary,
            structure.lattice;
            orthogonality_policy = cartesian_orthogonality_policy,
        )
        return MagneticSymmetryInventory(
            operations,
            false,
            include_time_reversal ? 2 : 1,
            nothing,
            dataset.hall_number,
            tolerance,
        )
    end
    moments = [
        Vector(structure.magnetic_moments_cartesian[:, atom]) for
        atom in eachindex(structure.species)
    ]
    cell = Spglib.Cell(transpose(structure.lattice), positions, atom_types, moments)
    dataset = Spglib.get_magnetic_dataset(cell, tolerance)
    dataset === nothing && throw(ArgumentError("Spglib could not detect the magnetic space group"))
    selected_operation_mask =
        include_time_reversal ? trues(length(dataset.rotations)) : .!dataset.time_reversals
    operations = _build_symmetry_operations(
        collect(dataset.rotations[selected_operation_mask]),
        collect(dataset.translations[selected_operation_mask]),
        collect(dataset.time_reversals[selected_operation_mask]),
        structure.lattice,
        orthogonality_policy = cartesian_orthogonality_policy,
    )
    return MagneticSymmetryInventory(
        operations,
        true,
        dataset.msg_type,
        dataset.uni_number,
        dataset.hall_number,
        tolerance,
    )
end

"""
Return only the ordered operations from the classified symmetry inventory.

This compatibility interface preserves existing callers while ensuring that
operation detection and magnetic classification cannot drift.
"""
function detect_symmetry_operations(arguments...; keywords...)
    return detect_magnetic_symmetry_inventory(arguments...; keywords...).operations
end

end

"""
Detect TB-workflow symmetry operations with the frozen 2026-08-16 semantics.

Response-symmetry and BandRepresentation workflows continue to use the current
public detector; only existing-TB mesh screening and operator symmetrization
call this compatibility boundary.
"""
function detect_tb_compatibility_symmetry_operations(arguments...; keywords...)
    return TBSymmetryDetectionCompatibility.detect_symmetry_operations(arguments...; keywords...)
end
