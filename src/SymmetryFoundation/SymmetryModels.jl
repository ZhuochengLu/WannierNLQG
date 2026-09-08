"""
Crystal structure in the input-cell convention used by symmetrization.

Lattice vectors are rows in Angstrom, fractional positions are columns of a
`3 x num_atoms` matrix, and magnetic moments are optional Cartesian axial
vectors with the same column ordering as the atoms. The object owns no file
format or symmetry-detection policy.
"""
struct CrystalStructure
    lattice::Matrix{Float64}
    species::Vector{String}
    positions_fractional::Matrix{Float64}
    magnetic_moments_cartesian::Union{Nothing, Matrix{Float64}}

    function CrystalStructure(
        lattice,
        species,
        positions_fractional;
        magnetic_moments_cartesian = nothing,
    )
        lattice_matrix = Matrix{Float64}(lattice)
        atom_species = String.(species)
        positions = Matrix{Float64}(positions_fractional)
        moments = if magnetic_moments_cartesian === nothing
            nothing
        else
            Matrix{Float64}(magnetic_moments_cartesian)
        end

        size(lattice_matrix) == (3, 3) || throw(ArgumentError("lattice must have size (3, 3)"))
        abs(det(lattice_matrix)) > eps(Float64) ||
            throw(ArgumentError("lattice must be nonsingular"))
        size(positions) == (3, length(atom_species)) ||
            throw(ArgumentError("positions_fractional must have size (3, num_atoms)"))
        isempty(atom_species) && throw(ArgumentError("at least one atom is required"))
        all(!isempty, atom_species) ||
            throw(ArgumentError("atomic species labels must not be empty"))
        all(isfinite, lattice_matrix) || throw(ArgumentError("lattice contains non-finite values"))
        all(isfinite, positions) ||
            throw(ArgumentError("positions_fractional contains non-finite values"))
        if moments !== nothing
            size(moments) == size(positions) ||
                throw(ArgumentError("magnetic_moments_cartesian must have size (3, num_atoms)"))
            all(isfinite, moments) ||
                throw(ArgumentError("magnetic_moments_cartesian contains non-finite values"))
        end

        return new(lattice_matrix, atom_species, positions, moments)
    end
end
"""
One unitary or antiunitary space-group operation.

Fractional column coordinates transform as `q' = W*q + translation`. Cartesian
polar vectors transform with `rotation_cartesian`. Complex conjugation is owned
by consumers when `antiunitary` is true.
"""
struct SymmetryOperation
    rotation_fractional::Matrix{Int}
    translation_fractional::Vector{Float64}
    rotation_cartesian::Matrix{Float64}
    antiunitary::Bool

    function SymmetryOperation(
        rotation_fractional,
        translation_fractional,
        rotation_cartesian,
        antiunitary = false,
        ;
        check_cartesian_orthogonality::Bool = true,
    )
        fractional_rotation = Matrix{Int}(rotation_fractional)
        translation = mod.(Vector{Float64}(translation_fractional), 1.0)
        cartesian_rotation = Matrix{Float64}(rotation_cartesian)
        size(fractional_rotation) == (3, 3) ||
            throw(ArgumentError("rotation_fractional must have size (3, 3)"))
        length(translation) == 3 ||
            throw(ArgumentError("translation_fractional must have length three"))
        size(cartesian_rotation) == (3, 3) ||
            throw(ArgumentError("rotation_cartesian must have size (3, 3)"))
        abs(round(Int, det(fractional_rotation))) == 1 ||
            throw(ArgumentError("rotation_fractional must be unimodular"))
        all(isfinite, translation) ||
            throw(ArgumentError("translation_fractional contains non-finite values"))
        all(isfinite, cartesian_rotation) ||
            throw(ArgumentError("rotation_cartesian contains non-finite values"))
        if check_cartesian_orthogonality
            isapprox(
                cartesian_rotation' * cartesian_rotation,
                Matrix{Float64}(I, 3, 3);
                atol = 1.0e-9,
                rtol = 0.0,
            ) || throw(ArgumentError("rotation_cartesian must be orthogonal"))
        end
        return new(fractional_rotation, translation, cartesian_rotation, Bool(antiunitary))
    end
end

"""
Magnetic-space-group inventory returned together with the ordered operations.

`msg_type` follows the magnetic-space-group Types I--IV. `uni_number` is
available only when Spglib classifies an explicitly magnetic structure. The
operation counts refer to the selected inventory after applying
`include_time_reversal`; they are therefore the exact counts consumed by the
band representation and SAWF preflight.
"""
struct MagneticSymmetryInventory
    operations::Vector{SymmetryOperation}
    magnetic::Bool
    msg_type::Int
    uni_number::Union{Nothing, Int}
    hall_number::Int
    unitary_operation_count::Int
    antiunitary_operation_count::Int
    symmetry_tolerance::Float64

    function MagneticSymmetryInventory(
        operations,
        magnetic,
        msg_type,
        uni_number,
        hall_number,
        symmetry_tolerance,
    )
        operation_values = SymmetryOperation[operations...]
        isempty(operation_values) &&
            throw(ArgumentError("magnetic symmetry inventory must contain operations"))
        type_value = Int(msg_type)
        type_value in 1:4 || throw(ArgumentError("msg_type must be in 1:4"))
        tolerance = Float64(symmetry_tolerance)
        isfinite(tolerance) && tolerance > 0.0 ||
            throw(ArgumentError("symmetry_tolerance must be positive and finite"))
        unitary_count = count(operation -> !operation.antiunitary, operation_values)
        antiunitary_count = length(operation_values) - unitary_count
        return new(
            operation_values,
            Bool(magnetic),
            type_value,
            uni_number === nothing ? nothing : Int(uni_number),
            Int(hall_number),
            unitary_count,
            antiunitary_count,
            tolerance,
        )
    end
end

"""
Precomputed Wannier representation and center shifts for group projection.

`representation_matrices[:, :, g]` maps source Wannier coefficients to target
coefficients. `wannier_shifts[:, a, g]` satisfies
`W_g*q_a + tau_g = q_g(a) + T_g,a`. Operations use one-based indices.
"""
struct WannierSymmetryPlan
    operations::Vector{SymmetryOperation}
    representation_matrices::Array{ComplexF64, 3}
    wannier_shifts::Array{Int, 3}
    operation_indices::Vector{Int}
    tolerance::Float64

    function WannierSymmetryPlan(
        operations,
        representation_matrices,
        wannier_shifts;
        operation_indices = nothing,
        tolerance = 1.0e-8,
        construction_policy::Symbol = :strict,
        diagnostics = nothing,
    )
        construction_policy in (:strict, :diagnostic) ||
            throw(ArgumentError("construction_policy must be :strict or :diagnostic"))
        operation_values = SymmetryOperation[operations...]
        representation_matrix_values = Array{ComplexF64, 3}(representation_matrices)
        wannier_shift_values = Array{Int, 3}(wannier_shifts)
        available_operation_count = length(operation_values)
        size(representation_matrix_values, 1) == size(representation_matrix_values, 2) ||
            throw(ArgumentError("representation matrices must be square"))
        size(representation_matrix_values, 3) == available_operation_count ||
            throw(ArgumentError("representation operation axis does not match operations"))
        size(wannier_shift_values) ==
        (3, size(representation_matrix_values, 1), available_operation_count) ||
            throw(ArgumentError("wannier_shifts must have size (3, num_wannier, num_operations)"))
        selected_operation_indices = if operation_indices === nothing
            collect(1:available_operation_count)
        else
            Int.(operation_indices)
        end
        isempty(selected_operation_indices) &&
            throw(ArgumentError("at least one operation must be selected"))
        length(unique(selected_operation_indices)) == length(selected_operation_indices) ||
            throw(ArgumentError("operation_indices contains duplicates"))
        all(index -> 1 <= index <= available_operation_count, selected_operation_indices) ||
            throw(ArgumentError("operation_indices contains an out-of-range index"))
        tolerance_value = Float64(tolerance)
        isfinite(tolerance_value) && tolerance_value > 0.0 ||
            throw(ArgumentError("tolerance must be positive and finite"))
        identity_representation = Matrix{ComplexF64}(
            I,
            size(representation_matrix_values, 1),
            size(representation_matrix_values, 1),
        )
        for operation_index in selected_operation_indices
            representation_matrix = @view representation_matrix_values[:, :, operation_index]
            all(isfinite, representation_matrix) ||
                throw(ArgumentError("Wannier representation contains nonfinite values"))
            singular_values = svdvals(representation_matrix)
            isempty(singular_values) && throw(ArgumentError("Wannier representation is empty"))
            minimum(singular_values) > eps(Float64) * max(1.0, maximum(singular_values)) ||
                throw(ArgumentError("Wannier representation is rank deficient"))
            residual =
                norm(representation_matrix' * representation_matrix - identity_representation)
            threshold = 10tolerance_value
            construction_policy == :diagnostic ||
                residual <= threshold ||
                throw(ArgumentError("Wannier representation $(operation_index) is not unitary"))
            diagnostics === nothing || push!(
                diagnostics,
                (
                    stage = "wannier_symmetry_plan",
                    code = "WANNIER_REPRESENTATION_UNITARITY_RESIDUAL",
                    operation = operation_index,
                    value = residual,
                    threshold = threshold,
                    result = residual <= threshold ? "PASS" : "FAIL",
                    action = residual <= threshold ? "CONTINUE" : "CONTINUE_DIAGNOSTIC",
                ),
            )
        end
        return new(
            operation_values,
            representation_matrix_values,
            wannier_shift_values,
            selected_operation_indices,
            tolerance_value,
        )
    end
end

"""Output of deterministic real-space group projection."""
struct RealSpaceSymmetrizationResult{N}
    operator::RealSpaceOperator{N}
    original_num_r_vectors::Int
    generated_r_vectors::Matrix{Int}
    operation_indices::Vector{Int}
end
