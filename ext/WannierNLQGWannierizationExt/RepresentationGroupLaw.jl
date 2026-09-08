# Return a translation difference reduced to the nearest lattice vector.
function _periodic_translation_residual(left::AbstractVector, right::AbstractVector)
    difference = Vector{Float64}(left .- right)
    return difference .- round.(difference)
end

# Compare two operations without relying on their list indices.
function _operations_equivalent(
    left::SymmetryOperation,
    right::SymmetryOperation;
    tolerance::Float64,
)
    left.antiunitary == right.antiunitary || return false
    left.rotation_fractional == right.rotation_fractional || return false
    maximum(
        abs,
        _periodic_translation_residual(left.translation_fractional, right.translation_fractional),
    ) <= tolerance || return false
    return maximum(abs, left.rotation_cartesian - right.rotation_cartesian) <= tolerance
end

"""
    _canonical_operation_key(operation; digits=12)

Return a deterministic, index-independent display identity for one operation.
Translations are reduced modulo one; the key is provenance, not a tolerant
replacement for the numerical operation comparison.
"""
function _canonical_operation_key(operation::SymmetryOperation; digits::Int = 12)
    translation = mod.(operation.translation_fractional, 1.0)
    translation[abs.(translation .- 1.0) .< 10.0 ^ (-digits)] .= 0.0
    translation = round.(translation; digits)
    rotation = join(vec(transpose(operation.rotation_fractional)), ",")
    antiunitary = operation.antiunitary ? "A" : "U"
    return "$(antiunitary)|W=$(rotation)|tau=$(join(translation, ','))"
end

# Build an empty table that can accompany a typed closure failure.
function _empty_representation_product_table(operations::Vector{SymmetryOperation}, spinor::Bool)
    operation_count = length(operations)
    spin_dimension = spinor ? 2 : 1
    spin_actions = zeros(ComplexF64, spin_dimension, spin_dimension, operation_count)
    for operation_index in eachindex(operations)
        spin_actions[:, :, operation_index] .=
            spin_action_matrix(operations[operation_index], spinor)
    end
    return RepresentationProductTable(
        0,
        nothing,
        _canonical_operation_key.(operations),
        spin_actions,
        zeros(Int, operation_count, operation_count),
        zeros(Int, 3, operation_count, operation_count),
        zeros(Int, operation_count, operation_count),
    )
end

"""
    _build_representation_product_table(operations, spinor; tolerance)

Construct the antiunitary-aware operation product table. For `p = g o h`,
the translation cocycle is `tau_g + W_g*tau_h - tau_p`, while the spin factor
is determined from `Q_g*conj(Q_h)` when `g` is antiunitary. Products that are
missing, ambiguous, nonintegral, or not related by a double-group sign fail.
"""
function _build_representation_product_table(
    operations::Vector{SymmetryOperation},
    spinor::Bool;
    tolerance::Real = 1.0e-10,
)
    tolerance_value = Float64(tolerance)
    operation_count = length(operations)
    operation_count > 0 || throw(ArgumentError("operation list must not be empty"))
    keys = _canonical_operation_key.(operations)
    length(unique(keys)) == length(keys) ||
        throw(ArgumentError("operation inventory contains duplicate canonical identities"))
    spin_dimension = spinor ? 2 : 1
    spin_actions = Array{ComplexF64, 3}(undef, spin_dimension, spin_dimension, operation_count)
    for operation_index in eachindex(operations)
        spin_actions[:, :, operation_index] .=
            spin_action_matrix(operations[operation_index], spinor)
    end
    identity_candidates = findall(eachindex(operations)) do operation_index
        operation = operations[operation_index]
        !operation.antiunitary &&
            operation.rotation_fractional == Matrix{Int}(I, 3, 3) &&
            maximum(
                abs,
                _periodic_translation_residual(operation.translation_fractional, zeros(3)),
            ) <= tolerance_value
    end
    length(identity_candidates) == 1 ||
        throw(ArgumentError("operation inventory must contain one unique unitary identity"))
    theta_candidates = findall(eachindex(operations)) do operation_index
        operation = operations[operation_index]
        operation.antiunitary &&
            operation.rotation_fractional == Matrix{Int}(I, 3, 3) &&
            maximum(
                abs,
                _periodic_translation_residual(operation.translation_fractional, zeros(3)),
            ) <= tolerance_value
    end
    length(theta_candidates) <= 1 ||
        throw(ArgumentError("operation inventory contains more than one pure time reversal"))
    theta_index = isempty(theta_candidates) ? nothing : only(theta_candidates)
    product_indices = Matrix{Int}(undef, operation_count, operation_count)
    translation_differences = Array{Int, 3}(undef, 3, operation_count, operation_count)
    spinor_factors = Matrix{Int}(undef, operation_count, operation_count)
    for left_index in eachindex(operations), right_index in eachindex(operations)
        left = operations[left_index]
        right = operations[right_index]
        product_rotation = left.rotation_fractional * right.rotation_fractional
        product_translation =
            left.translation_fractional + left.rotation_fractional * right.translation_fractional
        product_antiunitary = xor(left.antiunitary, right.antiunitary)
        matches = Int[]
        for candidate_index in eachindex(operations)
            candidate = operations[candidate_index]
            candidate.antiunitary == product_antiunitary || continue
            candidate.rotation_fractional == product_rotation || continue
            maximum(
                abs,
                _periodic_translation_residual(
                    product_translation,
                    candidate.translation_fractional,
                ),
            ) <= tolerance_value || continue
            push!(matches, candidate_index)
        end
        length(matches) == 1 || throw(
            ArgumentError(
                "operation product $(left_index) o $(right_index) has $(length(matches)) matches",
            ),
        )
        product_index = only(matches)
        product_indices[left_index, right_index] = product_index
        translation_difference =
            product_translation - operations[product_index].translation_fractional
        integer_translation = round.(Int, translation_difference)
        maximum(abs, translation_difference - integer_translation) <= tolerance_value || throw(
            ArgumentError(
                "operation product $(left_index) o $(right_index) has a noninteger translation cocycle",
            ),
        )
        translation_differences[:, left_index, right_index] .= integer_translation
        left_spin = @view spin_actions[:, :, left_index]
        right_spin = @view spin_actions[:, :, right_index]
        product_spin = left_spin * (left.antiunitary ? conj(right_spin) : right_spin)
        canonical_spin = @view spin_actions[:, :, product_index]
        overlap = tr(canonical_spin' * product_spin) / spin_dimension
        sign = real(overlap) >= 0.0 ? 1 : -1
        residual = maximum(abs, product_spin - sign .* canonical_spin)
        residual <= 10tolerance_value || throw(
            ArgumentError(
                "spin action product $(left_index) o $(right_index) is not a double-group sign of operation $(product_index); residual=$(residual)",
            ),
        )
        abs(imag(overlap)) <= 10tolerance_value || throw(
            ArgumentError(
                "spin action product $(left_index) o $(right_index) has a non-real projective phase",
            ),
        )
        spinor_factors[left_index, right_index] = sign
    end
    for first_index in eachindex(operations),
        second_index in eachindex(operations),
        third_index in eachindex(operations)

        first_second = product_indices[first_index, second_index]
        second_third = product_indices[second_index, third_index]
        left_associated = product_indices[first_second, third_index]
        right_associated = product_indices[first_index, second_third]
        left_associated == right_associated ||
            throw(ArgumentError("operation product table is not associative"))
        left_translation =
            @view(translation_differences[:, first_index, second_index]) .+
            @view(translation_differences[:, first_second, third_index])
        right_translation =
            operations[first_index].rotation_fractional *
            @view(translation_differences[:, second_index, third_index]) .+
            @view(translation_differences[:, first_index, second_third])
        left_translation == right_translation ||
            throw(ArgumentError("integer translation cocycle is not associative"))
        left_factor =
            spinor_factors[first_index, second_index] * spinor_factors[first_second, third_index]
        right_factor =
            spinor_factors[second_index, third_index] * spinor_factors[first_index, second_third]
        left_factor == right_factor ||
            throw(ArgumentError("spin double-group factor is not associative"))
    end
    return RepresentationProductTable(
        only(identity_candidates),
        theta_index,
        keys,
        spin_actions,
        product_indices,
        translation_differences,
        spinor_factors,
    )
end

# Serialize only scientific representation content into one deterministic hash.
function _representation_static_sha256(representation::BandRepresentation)
    io = IOBuffer()
    write(io, codeunits(String(representation.source_code)))
    write(io, UInt8(representation.spinor))
    for value in representation.mp_grid
        write(io, Int64(value))
    end
    for array in (
        representation.real_lattice,
        representation.reciprocal_lattice,
        representation.kpoints_fractional,
        representation.energies_ev,
        representation.kpoint_map,
        representation.reciprocal_shifts,
        representation.sewing_matrices,
        representation.band_block_labels,
        representation.irreducible_indices,
        representation.full_to_irreducible,
        representation.full_to_operation,
    )
        for dimension in size(array)
            write(io, Int64(dimension))
        end
        write(io, vec(array))
    end
    for operation in representation.operations
        write(io, vec(operation.rotation_fractional))
        write(io, operation.translation_fractional)
        write(io, vec(operation.rotation_cartesian))
        write(io, UInt8(operation.antiunitary))
    end
    for key in sort!(collect(keys(representation.conventions)))
        write(io, codeunits(key))
        write(io, UInt8(0))
        write(io, codeunits(representation.conventions[key]))
        write(io, UInt8(0))
    end
    return bytes2hex(sha256(take!(io)))
end

# Normalize optional index/bit masks to one BitVector per k-point.
function _normalize_validation_masks(
    masks,
    num_bands::Int,
    num_kpoints::Int;
    default_all::Bool = true,
)
    masks === nothing && return [BitVector(fill(default_all, num_bands)) for _ in 1:num_kpoints]
    length(masks) == num_kpoints ||
        throw(ArgumentError("validation mask count must equal num_kpoints"))
    normalized = Vector{BitVector}(undef, num_kpoints)
    for kpoint in 1:num_kpoints
        mask = masks[kpoint]
        if mask isa AbstractVector{Bool}
            length(mask) == num_bands ||
                throw(ArgumentError("boolean validation mask has an incompatible band count"))
            normalized[kpoint] = BitVector(mask)
        else
            indices = Int.(mask)
            all(index -> 1 <= index <= num_bands, indices) ||
                throw(ArgumentError("validation mask contains an out-of-range band"))
            bitmask = falses(num_bands)
            bitmask[indices] .= true
            normalized[kpoint] = bitmask
        end
    end
    return normalized
end

# Serialize rank and conditioning evidence for one group-law matrix block.
function _group_law_matrix_context(prefix::AbstractString, matrix::AbstractMatrix)
    singular_values = svdvals(matrix)
    tolerance =
        isempty(singular_values) ? 0.0 :
        max(size(matrix)...) * eps(Float64) * maximum(singular_values)
    numerical_rank = count(>(tolerance), singular_values)
    condition_estimate =
        isempty(singular_values) || minimum(singular_values) <= tolerance ? Inf :
        maximum(singular_values) / minimum(singular_values)
    return Dict(
        "$(prefix)_singular_values" => join(singular_values, ","),
        "$(prefix)_rank" => string(numerical_rank),
        "$(prefix)_condition_estimate" => string(condition_estimate),
    )
end

# Capture the complete worst-case evidence for one ordered operation product.
function _group_law_worst_case_context(
    representation::BandRepresentation,
    product_table::RepresentationProductTable,
    left_index::Int,
    right_index::Int,
    product_index::Int,
    source_kpoint::Int,
    intermediate_kpoint::Int,
    target_kpoint::Int,
    left_matrix::AbstractMatrix,
    right_matrix::AbstractMatrix,
    product_matrix::AbstractMatrix,
    phase::Complex,
    factor::Complex,
    residual_matrix::AbstractMatrix,
)
    translation = @view product_table.translation_differences[:, left_index, right_index]
    context = Dict(
        "combination" => GROUP_LAW_COMBINATION_LABELS[_group_law_combination_index(
            representation.operations[left_index].antiunitary,
            representation.operations[right_index].antiunitary,
        )],
        "left_operation" => string(left_index),
        "right_operation" => string(right_index),
        "product_operation" => string(product_index),
        "left_operation_key" => product_table.canonical_keys[left_index],
        "right_operation_key" => product_table.canonical_keys[right_index],
        "product_operation_key" => product_table.canonical_keys[product_index],
        "source_kpoint" => string(source_kpoint),
        "intermediate_kpoint" => string(intermediate_kpoint),
        "target_kpoint" => string(target_kpoint),
        "source_kpoint_fractional" =>
            join(@view(representation.kpoints_fractional[source_kpoint, :]), ","),
        "intermediate_kpoint_fractional" =>
            join(@view(representation.kpoints_fractional[intermediate_kpoint, :]), ","),
        "target_kpoint_fractional" =>
            join(@view(representation.kpoints_fractional[target_kpoint, :]), ","),
        "left_reciprocal_shift" => join(
            @view(representation.reciprocal_shifts[:, left_index, intermediate_kpoint]),
            ",",
        ),
        "right_reciprocal_shift" =>
            join(@view(representation.reciprocal_shifts[:, right_index, source_kpoint]), ","),
        "product_reciprocal_shift" =>
            join(@view(representation.reciprocal_shifts[:, product_index, source_kpoint]), ","),
        "integer_translation_cocycle" => join(translation, ","),
        "translation_phase_real" => string(real(phase)),
        "translation_phase_imag" => string(imag(phase)),
        "translation_phase_argument" => string(angle(phase)),
        "double_group_factor" => string(product_table.spinor_factors[left_index, right_index]),
        "final_factor_real" => string(real(factor)),
        "final_factor_imag" => string(imag(factor)),
        "max_abs_residual" => string(maximum(abs, residual_matrix)),
        "frobenius_residual" => string(norm(residual_matrix)),
    )
    merge!(context, _group_law_matrix_context("left", left_matrix))
    merge!(context, _group_law_matrix_context("right", right_matrix))
    merge!(context, _group_law_matrix_context("product", product_matrix))
    return context
end

"""
Measure the native k-action, reciprocal-shift cocycle, required-block
unitarity, and sewing group law. Stored sewing matrices have target-band rows
and source-band columns. For `p = g o h`, the exact residual is

`B_g(k_h) * conj(B_h(k))^a_g - xi_g,h * exp(-2pi*i*k_p.L_g,h) * B_p(k)`.

The reciprocal identity is
`G_g(k_h) + s_g*W_g^(-T)*G_h(k) - G_p(k) = 0`, with
`s_g = (-1)^a_g`. No operation reordering or matrix-wise phase fitting is
performed by this native validator.
"""
function _validate_band_group_law(
    representation::BandRepresentation,
    product_table::RepresentationProductTable,
    validation_masks::Vector{BitVector},
    tolerance::Float64,
    ;
    enforce_absolute_group_law::Bool = true,
)
    diagnostics = WannierizationDiagnostic[]
    operation_count = length(representation.operations)
    num_kpoints = size(representation.kpoint_map, 2)
    expected_kpoints = collect(1:num_kpoints)
    for operation_index in 1:operation_count
        sort(Vector(@view(representation.kpoint_map[operation_index, :]))) == expected_kpoints ||
            push!(
                diagnostics,
                _representation_diagnostic(
                    :RECIPROCAL_ACTION_INCONSISTENT,
                    :error,
                    "operation does not act as a permutation of the k mesh";
                    context = Dict("operation" => operation_index),
                ),
            )
    end
    maximum_shift_residual = 0.0
    for source_kpoint in 1:num_kpoints, operation_index in 1:operation_count
        operation = representation.operations[operation_index]
        sign = operation.antiunitary ? -1.0 : 1.0
        target_kpoint = representation.kpoint_map[operation_index, source_kpoint]
        transformed =
            sign .* (
                transpose(inv(operation.rotation_fractional)) *
                @view(representation.kpoints_fractional[source_kpoint, :])
            )
        reconstructed =
            @view(representation.kpoints_fractional[target_kpoint, :]) .+
            @view(representation.reciprocal_shifts[:, operation_index, source_kpoint])
        residual = maximum(abs, transformed - reconstructed)
        maximum_shift_residual = max(maximum_shift_residual, residual)
        residual <= tolerance || push!(
            diagnostics,
            _representation_diagnostic(
                :RECIPROCAL_ACTION_INCONSISTENT,
                :error,
                "stored k-map/reciprocal shift contradicts the operation action";
                context = Dict(
                    "operation" => operation_index,
                    "operation_key" => _canonical_operation_key(operation),
                    "source_kpoint" => source_kpoint,
                    "target_kpoint" => target_kpoint,
                    "maximum_error" => residual,
                    "tolerance" => tolerance,
                ),
            ),
        )
    end
    maximum_unitarity_residual = 0.0
    maximum_unitarity_context = Dict{String, String}()
    for source_kpoint in 1:num_kpoints, operation_index in 1:operation_count
        target_kpoint = representation.kpoint_map[operation_index, source_kpoint]
        source_indices = findall(validation_masks[source_kpoint])
        target_indices = findall(validation_masks[target_kpoint])
        if length(source_indices) != length(target_indices)
            maximum_unitarity_residual = Inf
            maximum_unitarity_context = Dict(
                "operation" => string(operation_index),
                "source_kpoint" => string(source_kpoint),
                "target_kpoint" => string(target_kpoint),
                "source_rank" => string(length(source_indices)),
                "target_rank" => string(length(target_indices)),
            )
            break
        end
        isempty(source_indices) && continue
        sewing = Matrix(
            @view representation.sewing_matrices[
                target_indices,
                source_indices,
                operation_index,
                source_kpoint,
            ]
        )
        identity_matrix = Matrix{ComplexF64}(I, length(source_indices), length(source_indices))
        residual = max(
            maximum(abs, sewing' * sewing - identity_matrix),
            maximum(abs, sewing * sewing' - identity_matrix),
        )
        if residual > maximum_unitarity_residual
            maximum_unitarity_residual = residual
            maximum_unitarity_context = Dict(
                "operation" => string(operation_index),
                "operation_key" =>
                    _canonical_operation_key(representation.operations[operation_index]),
                "source_kpoint" => string(source_kpoint),
                "target_kpoint" => string(target_kpoint),
            )
        end
    end
    maximum_unitarity_residual <= tolerance || push!(
        diagnostics,
        _representation_diagnostic(
            :REQUIRED_BLOCK_UNITARITY_FAILED,
            :error,
            "required sewing block is rank deficient or nonunitary";
            context = merge(
                maximum_unitarity_context,
                Dict(
                    "maximum_error" => string(maximum_unitarity_residual),
                    "tolerance" => string(tolerance),
                ),
            ),
        ),
    )
    maximum_group_residuals = zeros(Float64, 4)
    maximum_context = [Dict{String, String}() for _ in 1:4]
    for source_kpoint in 1:num_kpoints,
        left_index in 1:operation_count,
        right_index in 1:operation_count

        product_index = product_table.product_indices[left_index, right_index]
        product_index == 0 && continue
        intermediate_kpoint = representation.kpoint_map[right_index, source_kpoint]
        composed_kpoint = representation.kpoint_map[left_index, intermediate_kpoint]
        product_kpoint = representation.kpoint_map[product_index, source_kpoint]
        if composed_kpoint != product_kpoint
            push!(
                diagnostics,
                _representation_diagnostic(
                    :RECIPROCAL_ACTION_INCONSISTENT,
                    :error,
                    "operation product does not compose on the k mesh";
                    context = Dict(
                        "left_operation" => left_index,
                        "right_operation" => right_index,
                        "source_kpoint" => source_kpoint,
                        "composed_kpoint" => composed_kpoint,
                        "product_kpoint" => product_kpoint,
                    ),
                ),
            )
            continue
        end
        left_operation = representation.operations[left_index]
        sign = left_operation.antiunitary ? -1.0 : 1.0
        left_reciprocal_action = transpose(inv(left_operation.rotation_fractional))
        shift_residual =
            @view(representation.reciprocal_shifts[:, left_index, intermediate_kpoint]) .+
            sign .* (
                left_reciprocal_action *
                @view(representation.reciprocal_shifts[:, right_index, source_kpoint])
            ) .- @view(representation.reciprocal_shifts[:, product_index, source_kpoint])
        local_shift_residual = maximum(abs, shift_residual)
        maximum_shift_residual = max(maximum_shift_residual, local_shift_residual)
        if local_shift_residual > tolerance
            push!(
                diagnostics,
                _representation_diagnostic(
                    :RECIPROCAL_ACTION_INCONSISTENT,
                    :error,
                    "reciprocal-shift cocycle is inconsistent";
                    context = Dict(
                        "left_operation" => left_index,
                        "right_operation" => right_index,
                        "source_kpoint" => source_kpoint,
                        "maximum_error" => local_shift_residual,
                        "tolerance" => tolerance,
                    ),
                ),
            )
            continue
        end
        source_indices = findall(validation_masks[source_kpoint])
        intermediate_indices = findall(validation_masks[intermediate_kpoint])
        target_indices = findall(validation_masks[product_kpoint])
        (isempty(source_indices) || isempty(intermediate_indices) || isempty(target_indices)) &&
            continue
        left_sewing = Matrix(
            @view representation.sewing_matrices[
                target_indices,
                intermediate_indices,
                left_index,
                intermediate_kpoint,
            ]
        )
        right_sewing = Matrix(
            @view representation.sewing_matrices[
                intermediate_indices,
                source_indices,
                right_index,
                source_kpoint,
            ]
        )
        left_operation.antiunitary && (right_sewing = conj(right_sewing))
        product_sewing = Matrix(
            @view representation.sewing_matrices[
                target_indices,
                source_indices,
                product_index,
                source_kpoint,
            ]
        )
        lattice_translation =
            @view product_table.translation_differences[:, left_index, right_index]
        product_k = @view representation.kpoints_fractional[product_kpoint, :]
        phase = cis(-2.0 * pi * dot(product_k, lattice_translation))
        factor = product_table.spinor_factors[left_index, right_index] * phase
        residual_matrix = left_sewing * right_sewing - factor .* product_sewing
        local_group_residual = maximum(abs, residual_matrix)
        combination = _group_law_combination_index(
            left_operation.antiunitary,
            representation.operations[right_index].antiunitary,
        )
        if local_group_residual > maximum_group_residuals[combination]
            maximum_group_residuals[combination] = local_group_residual
            maximum_context[combination] = _group_law_worst_case_context(
                representation,
                product_table,
                left_index,
                right_index,
                product_index,
                source_kpoint,
                intermediate_kpoint,
                product_kpoint,
                left_sewing,
                right_sewing,
                product_sewing,
                phase,
                factor,
                residual_matrix,
            )
        end
    end
    if enforce_absolute_group_law
        for combination in 1:4
            maximum_group_residuals[combination] <= tolerance && continue
            context = merge(
                maximum_context[combination],
                Dict(
                    "maximum_error" => string(maximum_group_residuals[combination]),
                    "tolerance" => string(tolerance),
                ),
            )
            push!(
                diagnostics,
                _representation_diagnostic(
                    :ANTIUNITARY_GROUP_LAW_FAILED,
                    :error,
                    "band sewing matrices fail the antiunitary-aware operation group law";
                    context,
                ),
            )
        end
    end
    return (
        Tuple(maximum_group_residuals),
        maximum_shift_residual,
        maximum_unitarity_residual,
        diagnostics,
        Tuple(maximum_context),
    )
end
