# Convert one real-space column to an immutable lattice-vector key.
function r_vector_key(r_vectors::Matrix{Int}, index::Int)
    return Tuple(r_vectors[:, index])
end

# Apply `R_g = W_g R + T_g,b - T_g,a` for one Wannier pair.
function _map_real_space_vector(
    r_vector::NTuple{3, Int},
    plan::WannierSymmetryPlan,
    operation_index::Int,
    left_wannier::Int,
    right_wannier::Int,
)
    operation = plan.operations[operation_index]
    mapped =
        operation.rotation_fractional * collect(r_vector) .+
        plan.wannier_shifts[:, right_wannier, operation_index] .-
        plan.wannier_shifts[:, left_wannier, operation_index]
    return Tuple(Int.(mapped))
end

# Match one composed Seitz operation inside the selected operation set.
function _operation_is_selected(
    rotation::Matrix{Int},
    translation::Vector{Float64},
    antiunitary::Bool,
    plan::WannierSymmetryPlan,
)
    for index in plan.operation_indices
        operation = plan.operations[index]
        operation.antiunitary == antiunitary || continue
        operation.rotation_fractional == rotation || continue
        residual = operation.translation_fractional .- translation
        residual .-= round.(residual)
        maximum(abs, residual) <= plan.tolerance && return true
    end
    return false
end

# Require a closed selected group with one unitary identity operation.
function _validate_selected_operation_group(plan::WannierSymmetryPlan)
    identity_rotation = Matrix{Int}(I, 3, 3)
    has_identity = any(plan.operation_indices) do index
        operation = plan.operations[index]
        operation.rotation_fractional == identity_rotation &&
            maximum(
                abs,
                operation.translation_fractional .- round.(operation.translation_fractional),
            ) <= plan.tolerance &&
            !operation.antiunitary
    end
    has_identity ||
        throw(ArgumentError("selected symmetry operations must contain the unitary identity"))
    for left_index in plan.operation_indices, right_index in plan.operation_indices
        left = plan.operations[left_index]
        right = plan.operations[right_index]
        rotation = left.rotation_fractional * right.rotation_fractional
        translation = mod.(
            left.rotation_fractional * right.translation_fractional .+ left.translation_fractional,
            1.0,
        )
        antiunitary = xor(left.antiunitary, right.antiunitary)
        _operation_is_selected(rotation, translation, antiunitary, plan) || throw(
            ArgumentError(
                "selected operation set is not closed: product $(left_index)*$(right_index) is absent",
            ),
        )
    end
    return nothing
end

# Return nonzero target-basis support for one source Wannier state.
function _representation_support(
    plan::WannierSymmetryPlan,
    operation_index::Int,
    source_wannier::Int,
)
    matrix = @view plan.representation_matrices[:, source_wannier, operation_index]
    return findall(value -> abs(value) > plan.tolerance, matrix)
end

"""
Cache invariant group validation and representation support for one projection workflow.
"""
struct RealSpaceProjectionContext
    plan::WannierSymmetryPlan
    representation_support::Dict{Tuple{Int, Int}, Vector{Int}}
end

"""
Validate one symmetry plan and cache all nonzero representation support.
"""
function RealSpaceProjectionContext(plan::WannierSymmetryPlan)
    _validate_selected_operation_group(plan)
    num_wannier = size(plan.representation_matrices, 1)
    support = Dict{Tuple{Int, Int}, Vector{Int}}()
    for operation_index in plan.operation_indices, wannier in 1:num_wannier
        support[(operation_index, wannier)] =
            _representation_support(plan, operation_index, wannier)
    end
    return RealSpaceProjectionContext(plan, support)
end

# Read one scalar, vector, or rank-two Cartesian tensor from R-last storage.
function _operator_element(operator::RealSpaceOperator, left::Int, right::Int, r_index::Int)
    rank = operator.spec.cartesian_rank
    rank == 0 && return operator.data[left, right, r_index]
    rank == 1 && return copy(@view operator.data[left, right, :, r_index])
    rank == 2 && return copy(@view operator.data[left, right, :, :, r_index])
    throw(ArgumentError("Cartesian ranks above two are not supported"))
end

# Transform Cartesian tensor components from the target frame to the source frame.
function _transform_cartesian_to_source_frame(
    value,
    operation::SymmetryOperation,
    spec::RealSpaceOperatorSymmetrySpec,
)
    spec.rotate_cartesian || return copy(value)
    rank = spec.cartesian_rank
    rotated = if rank == 0
        value
    elseif rank == 1
        transpose(operation.rotation_cartesian) * value
    elseif rank == 2
        transpose(operation.rotation_cartesian) * value * operation.rotation_cartesian
    else
        throw(ArgumentError("Cartesian ranks above two are not supported"))
    end
    if det(operation.rotation_cartesian) < 0.0
        rotated *= spec.inversion_parity * (-1)^rank
    end
    return rotated
end

# Allocate one zero scalar, vector, or matrix for an operator specification.
function _zero_operator_element(spec::RealSpaceOperatorSymmetrySpec)
    spec.cartesian_rank == 0 && return zero(ComplexF64)
    spec.cartesian_rank == 1 && return zeros(ComplexF64, 3)
    spec.cartesian_rank == 2 && return zeros(ComplexF64, 3, 3)
    throw(ArgumentError("Cartesian ranks above two are not supported"))
end

# Rotate one mapped target element back to a source Wannier pair.
function _transform_operator_element_to_source_frame(
    operator::RealSpaceOperator,
    plan::WannierSymmetryPlan,
    operation_index::Int,
    left_wannier::Int,
    right_wannier::Int,
    mapped_r_index::Int,
    left_support::Vector{Int},
    right_support::Vector{Int},
)
    operation = plan.operations[operation_index]
    result = _zero_operator_element(operator.spec)
    representation = @view plan.representation_matrices[:, :, operation_index]
    for target_left in left_support, target_right in right_support
        coefficient =
            conj(representation[target_left, left_wannier]) *
            representation[target_right, right_wannier]
        value = _operator_element(operator, target_left, target_right, mapped_r_index)
        rotated = _transform_cartesian_to_source_frame(value, operation, operator.spec)
        result += coefficient .* rotated
    end
    if operation.antiunitary
        result = operator.spec.time_reversal_parity .* conj.(result)
    end
    return result
end

# Insert one scalar, vector, or matrix into R-last operator storage.
function _set_operator_element!(
    output,
    value,
    spec::RealSpaceOperatorSymmetrySpec,
    left::Int,
    right::Int,
    r_index::Int,
)
    rank = spec.cartesian_rank
    if rank == 0
        output[left, right, r_index] = value
    elseif rank == 1
        output[left, right, :, r_index] .= value
    elseif rank == 2
        output[left, right, :, :, r_index] .= value
    else
        throw(ArgumentError("Cartesian ranks above two are not supported"))
    end
    return output
end

# Return the maximum absolute value of one scalar or tensor element.
function _maximum_abs_operator_element(value)
    return value isa Number ? abs(value) : maximum(abs, value; init = 0.0)
end

# Build pair-specific and global symmetry-generated real-space support.
function _real_space_closure(operator::RealSpaceOperator, context::RealSpaceProjectionContext)
    plan = context.plan
    num_wannier = size(operator.data, 1)
    original = [r_vector_key(operator.r_vectors, index) for index in axes(operator.r_vectors, 2)]
    pair_support = Dict(
        (left, right) => Set{NTuple{3, Int}}() for left in 1:num_wannier for right in 1:num_wannier
    )
    global_support = Set{NTuple{3, Int}}()
    for source_left in 1:num_wannier, source_right in 1:num_wannier
        for r_vector in original, operation_index in plan.operation_indices
            mapped_r =
                _map_real_space_vector(r_vector, plan, operation_index, source_left, source_right)
            for target_left in context.representation_support[(operation_index, source_left)],
                target_right in context.representation_support[(operation_index, source_right)]

                push!(pair_support[(target_left, target_right)], mapped_r)
                push!(global_support, mapped_r)
            end
        end
    end
    preferred = [r_vector for r_vector in original if r_vector in global_support]
    preferred_set = Set(preferred)
    append!(preferred, sort!(collect(setdiff(global_support, preferred_set))))
    return pair_support, preferred
end

# Allocate output storage with the same Wannier/tensor axes and a new R axis.
function _symmetrized_operator_storage(operator::RealSpaceOperator, num_r_vectors::Int)
    dimensions = collect(size(operator.data))
    dimensions[end] = num_r_vectors
    return zeros(ComplexF64, Tuple(dimensions))
end

# Retain every input R block and only symmetry-generated blocks with nonzero accumulated data.
function _retained_r_indices(
    output,
    ordered_r_vectors::Vector{NTuple{3, Int}},
    original_set::Set{NTuple{3, Int}},
)
    return [
        index for (index, r_vector) in enumerate(ordered_r_vectors) if
        r_vector in original_set || any(!iszero, selectdim(output, ndims(output), index))
    ]
end

"""
Project one R-last real-space Wannier operator onto a selected symmetry group.

The group projector treats absent input R blocks as zero, constructs pairwise
symmetry-generated support deterministically, and applies
`R_g = W_g R + T_g,b - T_g,a`. Unitary/antiunitary basis transformations and
tensor parities come from the plan/spec. No Hermitianization, `-R` completion,
gauge repair, or implicit cutoff is applied; a cutoff must be explicitly
nonnegative. The input is not mutated.
"""
function symmetrize_real_space_operator(
    operator::RealSpaceOperator,
    plan::WannierSymmetryPlan;
    cutoff::Union{Nothing, Real} = nothing,
)
    return symmetrize_real_space_operator(
        operator,
        RealSpaceProjectionContext(plan);
        cutoff = cutoff,
    )
end

# Project with workflow-invariant group validation and representation support already cached.
function symmetrize_real_space_operator(
    operator::RealSpaceOperator,
    context::RealSpaceProjectionContext;
    cutoff::Union{Nothing, Real} = nothing,
)
    plan = context.plan
    size(operator.data, 1) == size(plan.representation_matrices, 1) ||
        throw(ArgumentError("operator and symmetry-plan Wannier dimensions disagree"))
    cutoff_value = cutoff === nothing ? nothing : Float64(cutoff)
    cutoff_value === nothing ||
        (isfinite(cutoff_value) && cutoff_value >= 0.0) ||
        throw(ArgumentError("cutoff must be finite and nonnegative when supplied"))
    pair_support, ordered_r_vectors = _real_space_closure(operator, context)
    input_r_index = Dict(
        r_vector_key(operator.r_vectors, index) => index for index in axes(operator.r_vectors, 2)
    )
    output_r_index = Dict(value => index for (index, value) in enumerate(ordered_r_vectors))
    output = _symmetrized_operator_storage(operator, length(ordered_r_vectors))
    num_wannier = size(operator.data, 1)
    num_selected_operations = length(plan.operation_indices)
    for left in 1:num_wannier, right in 1:num_wannier
        for r_vector in pair_support[(left, right)]
            average = _zero_operator_element(operator.spec)
            for operation_index in plan.operation_indices
                mapped_r = _map_real_space_vector(r_vector, plan, operation_index, left, right)
                mapped_r_index = get(input_r_index, mapped_r, 0)
                mapped_r_index == 0 && continue
                average += _transform_operator_element_to_source_frame(
                    operator,
                    plan,
                    operation_index,
                    left,
                    right,
                    mapped_r_index,
                    context.representation_support[(operation_index, left)],
                    context.representation_support[(operation_index, right)],
                )
            end
            average /= num_selected_operations
            cutoff_value !== nothing &&
                _maximum_abs_operator_element(average) <= cutoff_value &&
                continue
            _set_operator_element!(
                output,
                average,
                operator.spec,
                left,
                right,
                output_r_index[r_vector],
            )
        end
    end
    original_set = Set(keys(input_r_index))
    retained_indices = _retained_r_indices(output, ordered_r_vectors, original_set)
    retained_vectors = ordered_r_vectors[retained_indices]
    retained_output = selectdim(output, ndims(output), retained_indices)
    vectors = reduce(hcat, collect.(retained_vectors))
    generated = [vector for vector in retained_vectors if vector ∉ original_set]
    generated_vectors = isempty(generated) ? zeros(Int, 3, 0) : reduce(hcat, collect.(generated))
    result_operator = RealSpaceOperator(operator.spec, vectors, retained_output)
    return RealSpaceSymmetrizationResult(
        result_operator,
        size(operator.r_vectors, 2),
        generated_vectors,
        copy(plan.operation_indices),
    )
end

"""
Return the maximum selected-operation covariance residual of an operator.

Missing mapped R blocks are zero. The comparison uses the same basis, tensor,
antiunitary, and time-reversal conventions as the group projector and does not
modify or normalize the operator.
"""
function maximum_real_space_covariance_error(operator::RealSpaceOperator, plan::WannierSymmetryPlan)
    return maximum_real_space_covariance_error(operator, RealSpaceProjectionContext(plan))
end

# Evaluate covariance with the same prevalidated projection context as the projector.
function maximum_real_space_covariance_error(
    operator::RealSpaceOperator,
    context::RealSpaceProjectionContext,
)
    plan = context.plan
    input_r_index = Dict(
        r_vector_key(operator.r_vectors, index) => index for index in axes(operator.r_vectors, 2)
    )
    num_wannier = size(operator.data, 1)
    maximum_error = 0.0
    for operation_index in plan.operation_indices,
        left in 1:num_wannier,
        right in 1:num_wannier,
        r_index in axes(operator.r_vectors, 2)

        r_vector = r_vector_key(operator.r_vectors, r_index)
        mapped_r = _map_real_space_vector(r_vector, plan, operation_index, left, right)
        mapped_index = get(input_r_index, mapped_r, 0)
        expected = if mapped_index == 0
            _zero_operator_element(operator.spec)
        else
            _transform_operator_element_to_source_frame(
                operator,
                plan,
                operation_index,
                left,
                right,
                mapped_index,
                context.representation_support[(operation_index, left)],
                context.representation_support[(operation_index, right)],
            )
        end
        source = _operator_element(operator, left, right, r_index)
        maximum_error = max(maximum_error, _maximum_abs_operator_element(source .- expected))
    end
    return maximum_error
end
