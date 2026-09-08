"""
    _common_degeneracy_blocks(candidate_labels, reference_labels; ...)

Return the common coarsening of two contiguous degeneracy partitions. A band
boundary is retained only when both inputs contain it and neither energy list
places a crossing within `energy_tolerance_ev`. Neither input block is split.
"""
function _common_degeneracy_blocks(
    candidate_labels::AbstractVector{<:Integer},
    reference_labels::AbstractVector{<:Integer};
    candidate_energies = nothing,
    reference_energies = nothing,
    energy_tolerance_ev::Real = 0.01,
)
    length(candidate_labels) == length(reference_labels) ||
        throw(ArgumentError("degeneracy partitions have different band counts"))
    band_count = length(candidate_labels)
    band_count > 0 || throw(ArgumentError("degeneracy partition must not be empty"))
    candidate_energies === nothing ||
        length(candidate_energies) == band_count ||
        throw(ArgumentError("candidate energies have an incompatible band count"))
    reference_energies === nothing ||
        length(reference_energies) == band_count ||
        throw(ArgumentError("reference energies have an incompatible band count"))
    tolerance = Float64(energy_tolerance_ev)
    boundaries = Int[]
    for band in 1:(band_count - 1)
        candidate_boundary = candidate_labels[band] != candidate_labels[band + 1]
        reference_boundary = reference_labels[band] != reference_labels[band + 1]
        candidate_boundary && reference_boundary || continue
        candidate_crossing =
            candidate_energies !== nothing &&
            abs(candidate_energies[band + 1] - candidate_energies[band]) <= tolerance
        reference_crossing =
            reference_energies !== nothing &&
            abs(reference_energies[band + 1] - reference_energies[band]) <= tolerance
        candidate_crossing || reference_crossing || push!(boundaries, band)
    end
    starts = vcat(1, boundaries .+ 1)
    stops = vcat(boundaries, band_count)
    return UnitRange{Int}[start:stop for (start, stop) in zip(starts, stops)]
end

"""
    _block_alignment_unitary(overlap; tolerance)

Solve block-wise gauge alignment from an already orthonormal cross-basis
overlap. A
one-dimensional block uses its phase. A multidimensional block uses the polar
factor `X*Y'` of `overlap = X*Sigma*Y'`. The SVD is validation-only and is not
a localization retraction or numerical fallback in the SAWF solver.
"""
function _block_alignment_unitary(overlap::AbstractMatrix{<:Complex}; tolerance::Real = 1.0e-10)
    matrix = Matrix{ComplexF64}(overlap)
    size(matrix, 1) == size(matrix, 2) || throw(ArgumentError("block overlap must be square"))
    dimension = size(matrix, 1)
    dimension > 0 || throw(ArgumentError("block overlap must not be empty"))
    tolerance_value = Float64(tolerance)
    if dimension == 1
        magnitude = abs(matrix[1, 1])
        passed = magnitude > tolerance_value
        unitary = reshape([passed ? matrix[1, 1] / magnitude : 1.0 + 0.0im], 1, 1)
        overlap_unitarity_residual = abs(magnitude - 1.0)
        return (
            unitary = Matrix{ComplexF64}(unitary),
            singular_values = [magnitude],
            overlap_unitarity_residual,
            phase_only = true,
            passed = passed && overlap_unitarity_residual <= tolerance_value,
        )
    end
    decomposition = svd(matrix)
    singular_values = Float64.(decomposition.S)
    minimum_singular_value = minimum(singular_values)
    unitary = Matrix{ComplexF64}(decomposition.U * decomposition.Vt)
    identity_matrix = Matrix{ComplexF64}(I, dimension, dimension)
    overlap_unitarity_residual = max(
        maximum(abs, matrix' * matrix - identity_matrix),
        maximum(abs, matrix * matrix' - identity_matrix),
    )
    return (
        unitary,
        singular_values,
        overlap_unitarity_residual,
        phase_only = false,
        passed = minimum_singular_value > tolerance_value &&
                 overlap_unitarity_residual <= tolerance_value,
    )
end

# Return the polar row frame of a full-row-rank coefficient block. This is a
# validation operation on one degeneracy block and never enters SAWF iteration.
function _orthonormalized_coefficient_rows(coefficients::AbstractMatrix{<:Complex})
    matrix = Matrix{ComplexF64}(coefficients)
    rows, columns = size(matrix)
    0 < rows <= columns || throw(ArgumentError("coefficient block must have 0 < rows <= columns"))
    decomposition = svd(matrix; full = false)
    singular_values = Float64.(decomposition.S)
    rank_tolerance = max(size(matrix)...) * eps(Float64) * maximum(singular_values)
    numerical_rank = count(>(rank_tolerance), singular_values)
    numerical_rank == rows || throw(
        ArgumentError(
            "coefficient block is rank deficient: rank=$(numerical_rank), rows=$(rows), " *
            "rank_tolerance=$(rank_tolerance)",
        ),
    )
    return (
        rows = Matrix{ComplexF64}(decomposition.U * decomposition.Vt),
        singular_values,
        rank_tolerance,
    )
end

# Measure projector element differences without materializing an O(N_G^2) matrix.
function _projector_matrix_max_abs(
    candidate_rows::Matrix{ComplexF64},
    reference_rows::Matrix{ComplexF64};
    chunk_size::Int = 512,
)
    size(candidate_rows) == size(reference_rows) ||
        throw(DimensionMismatch("orthonormal coefficient frames have different sizes"))
    chunk_size > 0 || throw(ArgumentError("projector chunk_size must be positive"))
    maximum_error = 0.0
    columns = size(candidate_rows, 2)
    for first_column in 1:chunk_size:columns
        selected = first_column:min(first_column + chunk_size - 1, columns)
        candidate_chunk = transpose(candidate_rows) * conj(@view(candidate_rows[:, selected]))
        reference_chunk = transpose(reference_rows) * conj(@view(reference_rows[:, selected]))
        maximum_error = max(maximum_error, maximum(abs, candidate_chunk - reference_chunk))
    end
    return maximum_error
end

"""
    _stable_subspace_alignment(candidate, reference; tolerance)

Compare two equal-size coefficient blocks after independently constructing
their full-rank polar row frames in `ComplexF64`. The principal-angle distance
is evaluated from an explicit projection residual, avoiding cancellation in
`sqrt(1-sigma_min^2)`. The returned unitary aligns the original band gauges;
the SVD/polar operations are oracle validation only.
"""
function _stable_subspace_alignment(
    candidate::AbstractMatrix{<:Complex},
    reference::AbstractMatrix{<:Complex};
    tolerance::Real = 1.0e-10,
    projector_chunk_size::Int = 512,
)
    size(candidate) == size(reference) ||
        throw(DimensionMismatch("candidate/reference coefficient blocks have different sizes"))
    tolerance_value = Float64(tolerance)
    isfinite(tolerance_value) && tolerance_value > 0.0 ||
        throw(ArgumentError("subspace tolerance must be positive and finite"))
    candidate_frame = _orthonormalized_coefficient_rows(candidate)
    reference_frame = _orthonormalized_coefficient_rows(reference)
    candidate_rows = candidate_frame.rows
    reference_rows = reference_frame.rows
    overlap = conj(candidate_rows) * transpose(reference_rows)
    alignment = _block_alignment_unitary(overlap; tolerance = tolerance_value)
    projected_candidate = conj(overlap) * reference_rows
    projection_residual = candidate_rows - projected_candidate
    principal_angle_distance = opnorm(projection_residual)
    projector_matrix_max_abs =
        _projector_matrix_max_abs(candidate_rows, reference_rows; chunk_size = projector_chunk_size)
    passed =
        principal_angle_distance <= tolerance_value && projector_matrix_max_abs <= tolerance_value
    return (
        unitary = alignment.unitary,
        singular_values = alignment.singular_values,
        principal_angle_distance,
        projector_matrix_max_abs,
        candidate_rank_tolerance = candidate_frame.rank_tolerance,
        reference_rank_tolerance = reference_frame.rank_tolerance,
        phase_only = alignment.phase_only,
        passed,
    )
end

# Keep empirical absolute residuals separate from the paired-oracle reference metric.
function _paired_matrix_residual_metrics(
    candidate_residual::AbstractMatrix{<:Complex},
    reference_residual::AbstractMatrix{<:Complex},
)
    size(candidate_residual) == size(reference_residual) ||
        throw(DimensionMismatch("candidate/reference residual matrices have different sizes"))
    return (
        candidate_absolute = maximum(abs, candidate_residual),
        reference_absolute = maximum(abs, reference_residual),
        paired_excess = maximum(abs, candidate_residual - reference_residual),
    )
end

"""
    _gauge_transform_sewing(sewing, target_gauge, source_gauge; antiunitary)

Transform a target-row/source-column sewing matrix between independently
chosen Bloch gauges. Antiunitary operations conjugate the source gauge:
`U_target' * B * conj(U_source)`.
"""
function _gauge_transform_sewing(
    sewing::AbstractMatrix{<:Complex},
    target_gauge::AbstractMatrix{<:Complex},
    source_gauge::AbstractMatrix{<:Complex};
    antiunitary::Bool,
)
    size(sewing, 1) == size(target_gauge, 1) ||
        throw(DimensionMismatch("target gauge and sewing dimensions disagree"))
    size(sewing, 2) == size(source_gauge, 1) ||
        throw(DimensionMismatch("source gauge and sewing dimensions disagree"))
    right_gauge = antiunitary ? conj(source_gauge) : source_gauge
    return Matrix{ComplexF64}(target_gauge' * sewing * right_gauge)
end

# Match two operation inventories and retain the relative SU(2) lift signs.
function _match_symmetry_operations(
    candidate_operations::Vector{SymmetryOperation},
    reference_operations::Vector{SymmetryOperation};
    spinor::Bool,
    tolerance::Real = 1.0e-10,
)
    tolerance_value = Float64(tolerance)
    diagnostics = WannierizationDiagnostic[]
    length(candidate_operations) == length(reference_operations) || begin
        push!(
            diagnostics,
            _representation_diagnostic(
                :OPERATION_ORACLE_MISMATCH,
                :error,
                "candidate and reference operation counts differ";
                context = Dict(
                    "candidate_count" => length(candidate_operations),
                    "reference_count" => length(reference_operations),
                ),
            ),
        )
        return (
            candidate_to_reference = zeros(Int, length(candidate_operations)),
            spin_lift_factors = zeros(Int, length(candidate_operations)),
            maximum_translation_residual = Inf,
            maximum_rotation_residual = Inf,
            maximum_spin_residual = Inf,
            diagnostics,
        )
    end
    mapping = zeros(Int, length(candidate_operations))
    lift_factors = zeros(Int, length(candidate_operations))
    used_reference = falses(length(reference_operations))
    maximum_translation_residual = 0.0
    maximum_rotation_residual = 0.0
    maximum_spin_residual = 0.0
    spin_dimension = spinor ? 2 : 1
    for candidate_index in eachindex(candidate_operations)
        candidate = candidate_operations[candidate_index]
        matches = Tuple{Int, Int, Float64, Float64, Float64}[]
        candidate_spin = spin_action_matrix(candidate, spinor)
        for reference_index in eachindex(reference_operations)
            used_reference[reference_index] && continue
            reference = reference_operations[reference_index]
            candidate.antiunitary == reference.antiunitary || continue
            candidate.rotation_fractional == reference.rotation_fractional || continue
            translation_residual = maximum(
                abs,
                _periodic_translation_residual(
                    candidate.translation_fractional,
                    reference.translation_fractional,
                ),
            )
            translation_residual <= tolerance_value || continue
            rotation_residual =
                maximum(abs, candidate.rotation_cartesian - reference.rotation_cartesian)
            rotation_residual <= tolerance_value || continue
            reference_spin = spin_action_matrix(reference, spinor)
            overlap = tr(reference_spin' * candidate_spin) / spin_dimension
            sign = real(overlap) >= 0.0 ? 1 : -1
            spin_residual = maximum(abs, candidate_spin - sign .* reference_spin)
            spin_residual <= tolerance_value || continue
            abs(imag(overlap)) <= 10tolerance_value || continue
            push!(
                matches,
                (reference_index, sign, translation_residual, rotation_residual, spin_residual),
            )
        end
        if length(matches) != 1
            push!(
                diagnostics,
                _representation_diagnostic(
                    :OPERATION_ORACLE_MISMATCH,
                    :error,
                    "operation does not have one unique reference match";
                    context = Dict(
                        "candidate_index" => candidate_index,
                        "candidate_key" => _canonical_operation_key(candidate),
                        "match_count" => length(matches),
                    ),
                ),
            )
            continue
        end
        reference_index, sign, translation_residual, rotation_residual, spin_residual =
            only(matches)
        mapping[candidate_index] = reference_index
        lift_factors[candidate_index] = sign
        used_reference[reference_index] = true
        maximum_translation_residual = max(maximum_translation_residual, translation_residual)
        maximum_rotation_residual = max(maximum_rotation_residual, rotation_residual)
        maximum_spin_residual = max(maximum_spin_residual, spin_residual)
    end
    all(used_reference) || push!(
        diagnostics,
        _representation_diagnostic(
            :OPERATION_ORACLE_MISMATCH,
            :error,
            "one or more reference operations remain unmatched";
            context = Dict("unmatched_reference_indices" => join(findall(.!used_reference), ",")),
        ),
    )
    return (
        candidate_to_reference = mapping,
        spin_lift_factors = lift_factors,
        maximum_translation_residual,
        maximum_rotation_residual,
        maximum_spin_residual,
        diagnostics,
    )
end
