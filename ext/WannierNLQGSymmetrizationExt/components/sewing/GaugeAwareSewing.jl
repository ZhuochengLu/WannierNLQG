# Gauge matching and sewing construction; mechanically extracted without body edits.

# Match two full k meshes modulo reciprocal lattice vectors.
function _match_gauge_aware_kpoints(
    source::Matrix{Float64},
    target::Matrix{Float64};
    tolerance::Float64 = 1.0e-8,
)
    size(source) == size(target) || throw(ArgumentError("k-point mesh sizes disagree"))
    mapping = zeros(Int, size(source, 1))
    used = falses(size(target, 1))
    for source_index in axes(source, 1)
        matches = Int[]
        for target_index in axes(target, 1)
            difference = @view(source[source_index, :]) .- @view(target[target_index, :])
            maximum(abs, difference .- round.(difference)) <= tolerance &&
                push!(matches, target_index)
        end
        length(matches) == 1 ||
            throw(ArgumentError("k-point $(source_index) has $(length(matches)) matches"))
        target_index = only(matches)
        used[target_index] && throw(ArgumentError("k-point matching is not one-to-one"))
        mapping[source_index] = target_index
        used[target_index] = true
    end
    all(used) || throw(ArgumentError("one or more target k-points remain unmatched"))
    return mapping
end

# Reconstruct one R-last field in Convention II on an arbitrary k list.
function _gauge_aware_r_to_q(
    values_r::Array{ComplexF64, N},
    r_vectors::Matrix{Int},
    degeneracies::Vector{Int},
    kpoints::Matrix{Float64},
) where {N}
    size(values_r, N) == size(r_vectors, 2) == length(degeneracies) ||
        throw(ArgumentError("R-space field dimensions disagree"))
    output = zeros(ComplexF64, Base.front(size(values_r))..., size(kpoints, 1))
    output_matrix = reshape(output, :, size(kpoints, 1))
    input_matrix = reshape(values_r, :, size(r_vectors, 2))
    for kpoint in axes(kpoints, 1), r_index in axes(r_vectors, 2)
        phase = cis(2.0pi * dot(@view(kpoints[kpoint, :]), @view(r_vectors[:, r_index])))
        @views output_matrix[:, kpoint] .+=
            phase .* input_matrix[:, r_index] ./ degeneracies[r_index]
    end
    return output
end

# Inverse-transform a q-last field while preserving the exact input replica support.
function _gauge_aware_q_to_input_replicas(
    values_q::Array{ComplexF64, N},
    chk::WannierCHK,
    r_vectors::Matrix{Int},
    degeneracies::Vector{Int};
    weight_tolerance::Float64 = 1.0e-12,
) where {N}
    size(values_q, N) == chk.num_kpts ||
        throw(ArgumentError("q-space field has incompatible k-point count"))
    size(r_vectors, 2) == length(degeneracies) ||
        throw(ArgumentError("R support and degeneracies disagree"))
    groups = Dict{NTuple{3, Int}, Vector{Int}}()
    for r_index in axes(r_vectors, 2)
        residue = ntuple(direction -> mod(r_vectors[direction, r_index], chk.mp_grid[direction]), 3)
        push!(get!(groups, residue, Int[]), r_index)
    end
    length(groups) == chk.num_kpts ||
        throw(ArgumentError("input R support does not cover every MP residue"))
    for (residue, indices) in groups
        weight = sum(inv(degeneracies[index]) for index in indices)
        abs(weight - 1.0) <= weight_tolerance || throw(
            ArgumentError("input replica weight for residue $(residue) is $(weight), not one"),
        )
    end
    output = zeros(ComplexF64, Base.front(size(values_q))..., size(r_vectors, 2))
    output_matrix = reshape(output, :, size(r_vectors, 2))
    input_matrix = reshape(values_q, :, chk.num_kpts)
    for residue in sort!(collect(keys(groups)))
        coefficient = zeros(ComplexF64, size(input_matrix, 1))
        residue_vector = collect(residue)
        for kpoint in 1:chk.num_kpts
            phase = cis(-2.0pi * dot(@view(chk.kpt_red[kpoint, :]), residue_vector))
            @views coefficient .+= phase .* input_matrix[:, kpoint] ./ chk.num_kpts
        end
        for r_index in groups[residue]
            @views output_matrix[:, r_index] .= coefficient
        end
    end
    recovered = _gauge_aware_r_to_q(output, r_vectors, degeneracies, chk.kpt_red)
    return output, maximum(abs, recovered - values_q)
end

# Return maximum Hermiticity residual over one matrix-last field.
function _matrix_field_hermiticity(values::Array{ComplexF64, 3})
    maximum_error = 0.0
    for index in axes(values, 3)
        maximum_error = max(
            maximum_error,
            maximum(abs, @view(values[:, :, index]) - @view(values[:, :, index])'),
        )
    end
    return maximum_error
end

# Build actual CHK-gauge sewing matrices and all closure diagnostics.
function _build_actual_wannier_sewing(
    representation::BandRepresentation,
    chk::WannierCHK,
    representation_to_chk::Vector{Int},
)
    chk_to_representation = invperm(representation_to_chk)
    nw = chk.num_orbitals
    ng = length(representation.operations)
    sewing = Array{ComplexF64, 4}(undef, nw, nw, ng, chk.num_kpts)
    operation_map = Matrix{Int}(undef, ng, chk.num_kpts)
    maximum_semiunitarity = 0.0
    semiunitarity_residuals = zeros(Float64, chk.num_kpts)
    maximum_closure = 0.0
    closure_residuals = zeros(Float64, ng, chk.num_kpts)
    closure_square_sum = 0.0
    closure_entry_count = 0
    maximum_unitarity = 0.0
    unitarity_residuals = zeros(Float64, ng, chk.num_kpts)
    block_residuals = NamedTuple[]
    worst_closure = (operation = 0, source = 0, target = 0)
    worst_unitarity = (operation = 0, source = 0, target = 0)
    identity_matrix = Matrix{ComplexF64}(I, nw, nw)
    for source_chk in 1:chk.num_kpts
        source_representation = chk_to_representation[source_chk]
        source_gauge = Matrix(@view chk.v_matrix[:, :, source_chk])
        semiunitarity_residuals[source_chk] = opnorm(source_gauge' * source_gauge - identity_matrix)
        maximum_semiunitarity = max(maximum_semiunitarity, semiunitarity_residuals[source_chk])
        for operation_index in 1:ng
            target_representation =
                representation.kpoint_map[operation_index, source_representation]
            target_chk = representation_to_chk[target_representation]
            operation_map[operation_index, source_chk] = target_chk
            target_gauge = Matrix(@view chk.v_matrix[:, :, target_chk])
            band_sewing = Matrix(
                @view representation.sewing_matrices[:, :, operation_index, source_representation]
            )
            right_gauge =
                representation.operations[operation_index].antiunitary ? conj(source_gauge) :
                source_gauge
            transformed = band_sewing * right_gauge
            projected = target_gauge * (target_gauge' * transformed)
            closure = transformed - projected
            closure_residuals[operation_index, source_chk] = opnorm(closure)
            target_labels = @view representation.band_block_labels[:, target_representation]
            for block_label in unique(target_labels)
                band_indices = findall(==(block_label), target_labels)
                push!(
                    block_residuals,
                    (
                        operation = operation_index,
                        antiunitary = representation.operations[operation_index].antiunitary,
                        source = source_chk,
                        target = target_chk,
                        block_label,
                        first_band = first(band_indices),
                        last_band = last(band_indices),
                        closure_opnorm = opnorm(@view closure[band_indices, :]),
                    ),
                )
            end
            if closure_residuals[operation_index, source_chk] > maximum_closure
                maximum_closure = closure_residuals[operation_index, source_chk]
                worst_closure =
                    (operation = operation_index, source = source_chk, target = target_chk)
            end
            closure_square_sum += sum(abs2, closure)
            closure_entry_count += length(closure)
            wannier_sewing = target_gauge' * transformed
            sewing[:, :, operation_index, source_chk] .= wannier_sewing
            unitarity_residuals[operation_index, source_chk] = max(
                opnorm(wannier_sewing' * wannier_sewing - identity_matrix),
                opnorm(wannier_sewing * wannier_sewing' - identity_matrix),
            )
            if unitarity_residuals[operation_index, source_chk] > maximum_unitarity
                maximum_unitarity = unitarity_residuals[operation_index, source_chk]
                worst_unitarity =
                    (operation = operation_index, source = source_chk, target = target_chk)
            end
        end
    end
    table = build_band_product_table(representation.operations, representation.spinor)
    maximum_group = zeros(Float64, 4)
    worst_group = [(left = 0, right = 0, source = 0) for _ in 1:4]
    for source_chk in 1:chk.num_kpts, left_index in 1:ng, right_index in 1:ng
        product_index = table.product_indices[left_index, right_index]
        intermediate_chk = operation_map[right_index, source_chk]
        right_sewing = Matrix(@view sewing[:, :, right_index, source_chk])
        representation.operations[left_index].antiunitary && (right_sewing = conj(right_sewing))
        source_representation = chk_to_representation[source_chk]
        product_representation = representation.kpoint_map[product_index, source_representation]
        factor =
            table.spinor_factors[left_index, right_index] * cis(
                -2.0pi * dot(
                    @view(representation.kpoints_fractional[product_representation, :]),
                    @view(table.translation_differences[:, left_index, right_index]),
                ),
            )
        residual =
            @view(sewing[:, :, left_index, intermediate_chk]) * right_sewing -
            factor .* @view(sewing[:, :, product_index, source_chk])
        combination =
            representation.operations[left_index].antiunitary ?
            (representation.operations[right_index].antiunitary ? 4 : 3) :
            (representation.operations[right_index].antiunitary ? 2 : 1)
        residual_value = opnorm(residual)
        if residual_value > maximum_group[combination]
            maximum_group[combination] = residual_value
            worst_group[combination] = (left = left_index, right = right_index, source = source_chk)
        end
    end
    return (
        sewing,
        operation_map,
        maximum_semiunitarity,
        maximum_closure,
        closure_rms = sqrt(closure_square_sum / closure_entry_count),
        maximum_unitarity,
        maximum_group_law_residuals = Tuple(maximum_group),
        semiunitarity_residuals,
        closure_residuals,
        unitarity_residuals,
        block_residuals,
        worst_closure,
        worst_unitarity,
        worst_group,
    )
end
