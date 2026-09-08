# Convert one real vector into a column-major complex matrix.
function _projection_intertwiner_matrix(
    vector::AbstractVector{<:Real},
    source_dimension::Int,
    target_dimension::Int,
)
    complex_size = source_dimension * target_dimension
    length(vector) == 2complex_size ||
        throw(ArgumentError("real intertwiner vector has an incompatible length"))
    return reshape(
        ComplexF64.(vector[1:complex_size], vector[(complex_size + 1):end]),
        source_dimension,
        target_dimension,
    )
end

# Construct the real-linear Hom constraints, including antiunitary conjugation.
function _projection_intertwiner_constraints(
    source_actions::Vector{Matrix{ComplexF64}},
    target_actions::Vector{Matrix{ComplexF64}},
    antiunitary::AbstractVector{Bool},
)
    source_dimension = size(first(source_actions), 1)
    target_dimension = size(first(target_actions), 1)
    complex_size = source_dimension * target_dimension
    variable_count = 2complex_size
    rows_per_operation = 2complex_size
    constraints = zeros(Float64, rows_per_operation * length(source_actions), variable_count)
    for variable_index in 1:variable_count
        vector = zeros(Float64, variable_count)
        vector[variable_index] = 1.0
        matrix = _projection_intertwiner_matrix(vector, source_dimension, target_dimension)
        for operation_index in eachindex(source_actions)
            transformed_matrix = antiunitary[operation_index] ? conj(matrix) : matrix
            residual =
                source_actions[operation_index] * transformed_matrix -
                matrix * target_actions[operation_index]
            row_start = (operation_index - 1) * rows_per_operation
            constraints[(row_start + 1):(row_start + complex_size), variable_index] .=
                vec(real(residual))
            constraints[
                (row_start + complex_size + 1):(row_start + rows_per_operation),
                variable_index,
            ] .= vec(imag(residual))
        end
    end
    return constraints
end

# Measure the maximum normalized semilinear intertwining residual.
function _projection_intertwiner_residual(
    matrix::AbstractMatrix,
    source_actions::Vector{Matrix{ComplexF64}},
    target_actions::Vector{Matrix{ComplexF64}},
    antiunitary::AbstractVector{Bool},
)
    scale = max(1.0, norm(matrix))
    return maximum(eachindex(source_actions)) do operation_index
        transformed_matrix = antiunitary[operation_index] ? conj(matrix) : matrix
        norm(
            source_actions[operation_index] * transformed_matrix -
            matrix * target_actions[operation_index],
        ) / scale
    end
end

# Return rank and smallest singular value under one fixed scale-aware threshold.
function _projection_embedding_rank(matrix::AbstractMatrix, tolerance::Float64)
    singular_values = svdvals(matrix)
    isempty(singular_values) && return 0, 0.0
    threshold = tolerance * max(1.0, maximum(singular_values))
    return count(>(threshold), singular_values), minimum(singular_values)
end

# Generate deterministic elements of one real Hom space from its orthogonal projector.
function _projection_intertwiner_candidates(null_basis::Matrix{Float64}, maximum_combinations::Int)
    projector = null_basis * transpose(null_basis)
    tolerance = 100eps(Float64) * max(1.0, opnorm(projector))
    spanning = Vector{Vector{Float64}}()
    for column in axes(projector, 2)
        candidate = Vector(@view projector[:, column])
        norm(candidate) > tolerance || continue
        candidate ./= norm(candidate)
        push!(spanning, candidate)
    end
    candidates = copy(spanning)
    basis_count = size(null_basis, 2)
    for attempt in 1:maximum_combinations
        weights = [
            cos(Float64(attempt * index)) + sin(Float64((attempt + 1) * index)) for
            index in 1:basis_count
        ]
        candidate = null_basis * weights
        norm(candidate) > tolerance || continue
        candidate ./= norm(candidate)
        push!(candidates, candidate)
    end
    return candidates
end

"""
    _certify_representation_embedding(source_actions, target_actions, antiunitary;
                                      tolerance=1e-8)

Certify a full-rank linear map `X` from the target corepresentation into the
source corepresentation.  It solves

`S_g * conj(X)^a_g = X * T_g`

as one real-linear null-space problem, so unitary and antiunitary constraints
are enforced simultaneously.  The search over the finite-dimensional Hom
space is deterministic.  If the Hom space is nonzero but the bounded
deterministic combinations do not exhibit a full-rank map, the result is
`uncertain=true`; it is never reported as a proof of non-embedding.
"""
function _certify_representation_embedding(
    source_actions,
    target_actions,
    antiunitary;
    tolerance::Real = 1.0e-8,
    maximum_combinations::Integer = 256,
)
    tolerance_value = Float64(tolerance)
    isfinite(tolerance_value) && tolerance_value > 0.0 ||
        throw(ArgumentError("embedding tolerance must be positive and finite"))
    combination_limit = Int(maximum_combinations)
    combination_limit > 0 || throw(ArgumentError("maximum_combinations must be positive"))
    source_values = [Matrix{ComplexF64}(matrix) for matrix in source_actions]
    target_values = [Matrix{ComplexF64}(matrix) for matrix in target_actions]
    antiunitary_values = Bool.(antiunitary)
    isempty(source_values) && throw(ArgumentError("embedding action list must not be empty"))
    length(source_values) == length(target_values) == length(antiunitary_values) ||
        throw(ArgumentError("source, target, and antiunitary action counts must agree"))
    source_dimension = size(first(source_values), 1)
    target_dimension = size(first(target_values), 1)
    all(matrix -> size(matrix) == (source_dimension, source_dimension), source_values) ||
        throw(ArgumentError("source representation actions have inconsistent dimensions"))
    all(matrix -> size(matrix) == (target_dimension, target_dimension), target_values) ||
        throw(ArgumentError("target representation actions have inconsistent dimensions"))
    all(matrix -> all(isfinite, matrix), source_values) &&
    all(matrix -> all(isfinite, matrix), target_values) ||
        throw(ArgumentError("embedding actions contain non-finite values"))

    diagnostics = String[]
    if source_dimension < target_dimension
        push!(
            diagnostics,
            "source dimension $(source_dimension) is smaller than target dimension $(target_dimension)",
        )
        return ProjectionRepresentationEmbeddingCertificate(
            Inf,
            Inf,
            target_dimension,
            0,
            source_dimension,
            false,
            false,
            diagnostics,
        )
    end

    constraints =
        _projection_intertwiner_constraints(source_values, target_values, antiunitary_values)
    decomposition = svd(constraints; full = false)
    singular_scale = isempty(decomposition.S) ? 1.0 : max(1.0, maximum(decomposition.S))
    null_threshold = max(tolerance_value, max(size(constraints)...) * eps(Float64) * singular_scale)
    numerical_rank = count(>(null_threshold), decomposition.S)
    null_basis = Matrix(decomposition.V[:, (numerical_rank + 1):end])
    if size(null_basis, 2) == 0
        push!(diagnostics, "real-linear intertwiner space is zero-dimensional")
        return ProjectionRepresentationEmbeddingCertificate(
            Inf,
            Inf,
            target_dimension,
            0,
            source_dimension,
            false,
            false,
            diagnostics,
        )
    end

    best_rank = 0
    best_smallest_singular_value = 0.0
    best_residual = Inf
    for vector in _projection_intertwiner_candidates(null_basis, combination_limit)
        matrix = _projection_intertwiner_matrix(vector, source_dimension, target_dimension)
        candidate_rank, smallest_singular_value =
            _projection_embedding_rank(matrix, tolerance_value)
        residual = _projection_intertwiner_residual(
            matrix,
            source_values,
            target_values,
            antiunitary_values,
        )
        if candidate_rank > best_rank ||
           (candidate_rank == best_rank && smallest_singular_value > best_smallest_singular_value)
            best_rank = candidate_rank
            best_smallest_singular_value = smallest_singular_value
            best_residual = residual
        elseif candidate_rank == best_rank &&
               smallest_singular_value == best_smallest_singular_value
            best_residual = min(best_residual, residual)
        end
        best_rank == target_dimension && best_residual <= tolerance_value && break
    end
    complete = best_rank == target_dimension && best_residual <= tolerance_value
    if !complete
        push!(
            diagnostics,
            "nonzero Hom space did not yield a certified full-rank embedding; best_rank=$(best_rank), target_rank=$(target_dimension)",
        )
    end
    return ProjectionRepresentationEmbeddingCertificate(
        best_residual,
        best_residual,
        target_dimension,
        best_rank,
        source_dimension,
        complete,
        !complete,
        diagnostics,
    )
end
