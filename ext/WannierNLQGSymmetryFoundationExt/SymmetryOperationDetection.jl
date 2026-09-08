# Assign deterministic integer species types without interpreting label suffixes.
function _species_type_numbers(species::Vector{String})
    type_by_species = Dict{String, Int}()
    return [get!(type_by_species, label, length(type_by_species) + 1) for label in species]
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
    lattice::Matrix{Float64};
    cartesian_rotation_policy::Union{Nothing, Symbol} = nothing,
    cartesian_orthogonality_policy::Union{Nothing, Symbol} = nothing,
    maximum_cartesian_rotation_correction::Real = DEFAULT_MAXIMUM_CARTESIAN_ROTATION_CORRECTION,
)
    length(rotations) == length(translations) == length(antiunitary_flags) ||
        throw(ArgumentError("symmetry operation arrays have inconsistent lengths"))
    policy =
        resolve_cartesian_rotation_policy(cartesian_rotation_policy, cartesian_orthogonality_policy)
    correction_limit = Float64(maximum_cartesian_rotation_correction)
    isfinite(correction_limit) && correction_limit > 0.0 ||
        throw(ArgumentError("maximum_cartesian_rotation_correction must be positive and finite"))
    rotation_data = group_invariant_cartesian_rotation_data(rotations, lattice)
    if policy == :group_invariant_metric
        rotation_data.maximum_correction <= correction_limit || throw(
            ArgumentError(
                "group-invariant Cartesian rotation correction " *
                "$(rotation_data.maximum_correction) exceeds limit $(correction_limit)",
            ),
        )
        rotation_data.maximum_effective_orthogonality <= EFFECTIVE_CARTESIAN_ROTATION_TOLERANCE ||
            throw(
                ArgumentError(
                    "effective Cartesian orthogonality residual " *
                    "$(rotation_data.maximum_effective_orthogonality) exceeds " *
                    "$(EFFECTIVE_CARTESIAN_ROTATION_TOLERANCE)",
                ),
            )
        rotation_data.maximum_effective_closure <= EFFECTIVE_CARTESIAN_ROTATION_TOLERANCE || throw(
            ArgumentError(
                "effective Cartesian closure residual " *
                "$(rotation_data.maximum_effective_closure) exceeds " *
                "$(EFFECTIVE_CARTESIAN_ROTATION_TOLERANCE)",
            ),
        )
    elseif rotation_data.maximum_raw_orthogonality > RAW_CARTESIAN_ORTHOGONALITY_WARNING_TOLERANCE
        message =
            "raw Cartesian orthogonality residual " *
            "$(rotation_data.maximum_raw_orthogonality) exceeds warning threshold " *
            "$(RAW_CARTESIAN_ORTHOGONALITY_WARNING_TOLERANCE)"
        policy == :raw_error ? throw(ArgumentError(message)) : @warn message
    end

    operations = SymmetryOperation[]
    for index in eachindex(rotations)
        rotation_fractional = Matrix{Int}(rotations[index])
        key = Tuple(vec(rotation_fractional))
        rotation_cartesian =
            policy == :group_invariant_metric ? rotation_data.effective_rotations[key] :
            rotation_data.raw_rotations[key]
        push!(
            operations,
            SymmetryOperation(
                rotation_fractional,
                _clean_fractional_translation(translations[index]),
                rotation_cartesian,
                antiunitary_flags[index];
                check_cartesian_orthogonality = policy == :group_invariant_metric,
            ),
        )
    end
    isempty(operations) && throw(ArgumentError("Spglib returned no symmetry operations"))
    return operations
end

"""
Detect and classify spatial or magnetic symmetry from a WIN-authoritative structure.

`spglib_symprec_angstrom` is the explicit backend distance tolerance. The legacy
`symmetry_tolerance` keyword is a same-unit Angstrom alias; unequal simultaneous
values are rejected. Magnetic moments are Cartesian axial vectors passed to
Spglib. The default Cartesian action is rebuilt from one group-invariant lattice
metric, while `:raw_warn` is retained only for diagnostic reproduction.
"""
function detect_magnetic_symmetry_inventory(
    structure::CrystalStructure;
    include_time_reversal::Bool = true,
    spglib_symprec_angstrom::Union{Nothing, Real} = nothing,
    symmetry_tolerance::Union{Nothing, Real} = nothing,
    cartesian_rotation_policy::Union{Nothing, Symbol} = nothing,
    cartesian_orthogonality_policy::Union{Nothing, Symbol} = nothing,
    maximum_cartesian_rotation_correction::Real = DEFAULT_MAXIMUM_CARTESIAN_ROTATION_CORRECTION,
)
    tolerance = resolve_spglib_symprec_angstrom(; spglib_symprec_angstrom, symmetry_tolerance)
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
            cartesian_rotation_policy,
            cartesian_orthogonality_policy,
            maximum_cartesian_rotation_correction,
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
        structure.lattice;
        cartesian_rotation_policy,
        cartesian_orthogonality_policy,
        maximum_cartesian_rotation_correction,
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

"""Return the loaded symmetry-detection backend identity for artifact provenance."""
function symmetry_detection_backend_provenance()
    return (package = "Spglib", version = string(Base.pkgversion(Spglib)))
end
