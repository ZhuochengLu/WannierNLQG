const RESPONSE_SYMMETRY_QUANTITIES =
    (:shift_current, :injection_current, :shift_spin_current, :injection_spin_current)

"""Return the antiunitary field-index-exchange sign of a final response tensor."""
function response_symmetry_sign(quantity::Symbol)
    quantity == :shift_current && return 1.0
    quantity == :injection_current && return -1.0
    quantity == :shift_spin_current && return -1.0
    quantity == :injection_spin_current && return 1.0
    throw(ArgumentError("response symmetry is not defined for quantity=$(quantity)"))
end

"""
Cartesian tuples follow the historical result-column order: the rightmost
tensor index varies fastest.
"""
function response_component_tuples(quantity::Symbol, spatial_dimension::Integer)
    dimension = Int(spatial_dimension)
    dimension in 1:3 || throw(ArgumentError("spatial_dimension must be in 1:3"))
    quantity in RESPONSE_SYMMETRY_QUANTITIES ||
        throw(ArgumentError("response symmetry is not defined for quantity=$(quantity)"))
    if quantity in (:shift_spin_current, :injection_spin_current)
        return Tuple{Int, Int, Int, Int}[
            (a, s, b, c) for a in 1:dimension for s in 1:3 for b in 1:dimension for c in 1:dimension
        ]
    end
    return Tuple{Int, Int, Int}[
        (a, b, c) for a in 1:dimension for b in 1:dimension for c in 1:dimension
    ]
end

"""
Return compact Cartesian labels in the historical result-column order.
"""
function response_component_labels(quantity::Symbol, spatial_dimension::Integer)
    axes = ("x", "y", "z")
    return [
        join(axes[index] for index in component) for
        component in response_component_tuples(quantity, spatial_dimension)
    ]
end

"""
Construct the real matrix acting on the final optical-conductivity tensor.

Charge responses use `R tensor R tensor R`; spin responses use
`R tensor (det(R)R) tensor R tensor R`.  For antiunitary operations the two
field indices are exchanged and the response-specific sign is applied.  No
additional complex conjugation is part of this response-space rule.
"""
function response_symmetry_action_matrix(
    quantity::Symbol,
    spatial_dimension::Integer,
    rotation_cartesian::AbstractMatrix{<:Real},
    antiunitary::Bool,
    ;
    component_part::Symbol = :real,
)
    component_part in (:real, :imaginary) ||
        throw(ArgumentError("component_part must be :real or :imaginary"))
    dimension = Int(spatial_dimension)
    size(rotation_cartesian) == (3, 3) ||
        throw(ArgumentError("rotation_cartesian must have size (3, 3)"))
    rotation = Matrix{Float64}(rotation_cartesian)
    all(isfinite, rotation) || throw(ArgumentError("rotation_cartesian is non-finite"))
    orthogonality_residual = maximum(abs, rotation' * rotation - Matrix{Float64}(I, 3, 3))
    if orthogonality_residual > 1.0e-8
        @warn "rotation_cartesian orthogonality residual $(orthogonality_residual) " *
              "exceeds warning threshold 1.0e-8; raw rotation retained"
    end
    if dimension < 3
        maximum(abs, rotation[1:dimension, (dimension + 1):3]; init = 0.0) <= 1.0e-10 || throw(
            ArgumentError(
                "point-group operation rotates the active Cartesian subspace out of itself",
            ),
        )
        maximum(abs, rotation[(dimension + 1):3, 1:dimension]; init = 0.0) <= 1.0e-10 || throw(
            ArgumentError(
                "point-group operation rotates the active Cartesian subspace out of itself",
            ),
        )
    end
    components = response_component_tuples(quantity, dimension)
    component_index = Dict(component => index for (index, component) in enumerate(components))
    action = zeros(Float64, length(components), length(components))
    # Re and Im ordered Cartesian slots obey the same antiunitary index
    # exchange.  Their optical TR parity differs after forming the symmetric
    # linear and antisymmetric circular combinations; adding another Im sign
    # here would reverse the required shift/injection channel table.
    anti_sign = antiunitary ? response_symmetry_sign(quantity) : 1.0
    if quantity in (:shift_spin_current, :injection_spin_current)
        axial = det(rotation) .* rotation
        for (row, (a, s, b, c)) in enumerate(components)
            output_b, output_c = antiunitary ? (c, b) : (b, c)
            for A in 1:dimension, S in 1:3, B in 1:dimension, C in 1:dimension
                column = component_index[(A, S, B, C)]
                action[row, column] +=
                    anti_sign *
                    rotation[a, A] *
                    axial[s, S] *
                    rotation[output_b, B] *
                    rotation[output_c, C]
            end
        end
    else
        for (row, (a, b, c)) in enumerate(components)
            output_b, output_c = antiunitary ? (c, b) : (b, c)
            for A in 1:dimension, B in 1:dimension, C in 1:dimension
                column = component_index[(A, B, C)]
                action[row, column] +=
                    anti_sign * rotation[a, A] * rotation[output_b, B] * rotation[output_c, C]
            end
        end
    end
    action[abs.(action) .< 1.0e-15] .= 0.0
    return action
end

"""Average final-tensor action matrices over a validated point group."""
function response_symmetry_projector(
    quantity::Symbol,
    spatial_dimension::Integer,
    operations;
    component_part::Symbol = :real,
)
    isempty(operations) && throw(ArgumentError("at least one point-group operation is required"))
    component_count = length(response_component_tuples(quantity, spatial_dimension))
    projector = zeros(Float64, component_count, component_count)
    for operation in operations
        rotation =
            hasproperty(operation, :rotation_cartesian) ?
            getproperty(operation, :rotation_cartesian) : operation[1]
        antiunitary =
            hasproperty(operation, :antiunitary) ? Bool(getproperty(operation, :antiunitary)) :
            Bool(operation[2])
        projector .+= response_symmetry_action_matrix(
            quantity,
            spatial_dimension,
            rotation,
            antiunitary;
            component_part,
        )
    end
    projector ./= length(operations)
    projector[abs.(projector) .< 1.0e-15] .= 0.0
    return projector
end

"""
Deterministic twice-modified Gram--Schmidt of projected Cartesian columns.
"""
function response_symmetry_basis(projector::AbstractMatrix{<:Real}; tolerance::Real = 1.0e-12)
    rows, columns = size(projector)
    rows == columns || throw(ArgumentError("response projector must be square"))
    threshold = Float64(tolerance)
    threshold > 0.0 || throw(ArgumentError("basis tolerance must be positive"))
    # A mathematically exact group projector has eigenvalues only at zero and
    # one. Repeated Gram--Schmidt on nearly dependent projected coordinate
    # columns can amplify roundoff above a literal 1e-12 and invent an extra
    # basis vector. Use a scale-aware numerical-rank floor while retaining the
    # deterministic projected-column ordering and sign convention.
    rank_threshold = max(threshold, sqrt(eps(Float64)) * max(opnorm(projector), 1.0))
    vectors = Vector{Vector{Float64}}()
    for column in 1:columns
        candidate = Vector{Float64}(@view projector[:, column])
        for _ in 1:2, basis_vector in vectors
            candidate .-= dot(basis_vector, candidate) .* basis_vector
        end
        magnitude = norm(candidate)
        magnitude > rank_threshold || continue
        candidate ./= magnitude
        first_nonzero = findfirst(value -> abs(value) > rank_threshold, candidate)
        first_nonzero === nothing && continue
        candidate[first_nonzero] < 0.0 && (candidate .*= -1.0)
        push!(vectors, candidate)
    end
    basis = isempty(vectors) ? zeros(Float64, rows, 0) : hcat(vectors...)
    basis[abs.(basis) .< 1.0e-15] .= 0.0
    reconstruction_residual = maximum(abs, basis * transpose(basis) - projector)
    reconstruction_residual <= 10rank_threshold || throw(
        ArgumentError(
            "response symmetry basis does not reconstruct its projector; residual=$(reconstruction_residual)",
        ),
    )
    return basis
end

"""Extract exact/simple relations and the full `X = P*X` contract."""
function response_symmetry_relations(
    quantity::Symbol,
    spatial_dimension::Integer,
    projector::AbstractMatrix{<:Real};
    tolerance::Real = 1.0e-10,
)
    labels = response_component_labels(quantity, spatial_dimension)
    size(projector) == (length(labels), length(labels)) ||
        throw(ArgumentError("projector dimension disagrees with response tensor"))
    threshold = Float64(tolerance)
    forbidden = String[]
    equal = Tuple{String, String}[]
    opposite = Tuple{String, String}[]
    for index in eachindex(labels)
        norm(@view projector[index, :]) <= threshold && push!(forbidden, labels[index])
    end
    for left in eachindex(labels), right in (left + 1):length(labels)
        norm(@view(projector[left, :]) .- @view(projector[right, :])) <= threshold &&
            push!(equal, (labels[left], labels[right]))
        norm(@view(projector[left, :]) .+ @view(projector[right, :])) <= threshold &&
            push!(opposite, (labels[left], labels[right]))
    end
    constraint = Matrix{Float64}(I, length(labels), length(labels)) - projector
    constraint[abs.(constraint) .< 1.0e-14] .= 0.0
    return (
        labels = labels,
        forbidden = forbidden,
        equal = equal,
        opposite = opposite,
        constraint_matrix = constraint,
    )
end

"""Project every energy slice through a deterministic invariant basis in place."""
function project_response_symmetry!(
    tensor::Array{ComplexF64},
    quantity::Symbol,
    spatial_dimension::Integer,
    basis::AbstractMatrix{<:Real},
)
    components = response_component_tuples(quantity, spatial_dimension)
    size(basis, 1) == length(components) ||
        throw(ArgumentError("basis row count disagrees with response tensor"))
    expected_axes =
        quantity in (:shift_spin_current, :injection_spin_current) ?
        (Int(spatial_dimension), 3, Int(spatial_dimension), Int(spatial_dimension)) :
        ntuple(_ -> Int(spatial_dimension), 3)
    size(tensor)[2:end] == expected_axes || throw(
        ArgumentError("response tensor axes $(size(tensor)[2:end]) disagree with $(expected_axes)"),
    )
    raw = zeros(ComplexF64, length(components))
    coefficients = zeros(ComplexF64, size(basis, 2))
    projected = similar(raw)
    for energy_index in axes(tensor, 1)
        for (index, component) in enumerate(components)
            raw[index] = tensor[(energy_index, component...)...]
        end
        mul!(coefficients, transpose(basis), raw)
        mul!(projected, basis, coefficients)
        for (index, component) in enumerate(components)
            tensor[(energy_index, component...)...] = projected[index]
        end
    end
    return tensor
end
