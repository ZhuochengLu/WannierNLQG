const RESPONSE_SYMMETRY_SUPPORTED_TASKS = Set([
    (:shift_current, :conventional, :integral),
    (:shift_current, :projector, :integral),
    (:shift_current, :geometric_loop, :integral),
    (:shift_current, :wilson_loop, :integral),
    (:injection_current, :conventional, :integral),
    (:shift_spin_current, :conventional, :integral),
    (:injection_spin_current, :conventional, :integral),
    (:shift_current, :conventional, :kslice),
    (:shift_current, :projector, :kslice),
    (:shift_current, :geometric_loop, :kslice),
    (:shift_current, :wilson_loop, :kslice),
    (:injection_current, :conventional, :kslice),
    (:shift_spin_current, :conventional, :kslice),
    (:injection_spin_current, :conventional, :kslice),
])

"""
Immutable tensor projector, basis, relations, and raw-component work plan.
"""
struct ResponseTensorSymmetryPlan
    quantity::Symbol
    component_labels::Vector{String}
    projector::Matrix{Float64}
    imaginary_projector::Matrix{Float64}
    basis::Matrix{Float64}
    imaginary_basis::Matrix{Float64}
    forbidden::Vector{String}
    imaginary_forbidden::Vector{String}
    equal::Vector{Tuple{String, String}}
    imaginary_equal::Vector{Tuple{String, String}}
    opposite::Vector{Tuple{String, String}}
    imaginary_opposite::Vector{Tuple{String, String}}
    constraint_matrix::Matrix{Float64}
    imaginary_constraint_matrix::Matrix{Float64}
    basis_support_indices::Vector{Int}
    raw_component_indices::Vector{Int}
    accumulation_path::Symbol
    projector_idempotence_residual::Float64
    imaginary_projector_idempotence_residual::Float64
end

"""
Preserve the schema-1.0 expert constructor; its single projector is interpreted
identically for both complex parts only for legacy diagnostic fixtures.
"""
function ResponseTensorSymmetryPlan(
    quantity,
    component_labels,
    projector,
    basis,
    forbidden,
    equal,
    opposite,
    constraint_matrix,
    basis_support_indices,
    raw_component_indices,
    accumulation_path,
    projector_idempotence_residual,
)
    return ResponseTensorSymmetryPlan(
        quantity,
        component_labels,
        projector,
        copy(projector),
        basis,
        copy(basis),
        forbidden,
        copy(forbidden),
        equal,
        copy(equal),
        opposite,
        copy(opposite),
        constraint_matrix,
        copy(constraint_matrix),
        basis_support_indices,
        raw_component_indices,
        accumulation_path,
        projector_idempotence_residual,
        projector_idempotence_residual,
    )
end

"""
Immutable orbit and tensor plan broadcast from the MPI root process.
"""
struct ResponseSymmetryExecutionPlan
    artifact_file::String
    artifact_sha256::String
    artifact_schema::String
    artifact_sealed::Bool
    production_eligible::Bool
    model_sha256::String
    structure_sha256::String
    policy::Symbol
    kmesh_mode::Symbol
    explanation_only::Bool
    status::Symbol
    covariance_status::String
    covariance_max_relative_residual::Union{Nothing, Float64}
    covariance_tolerance::Float64
    warnings::Vector{String}
    operations::Vector{ResponseSymmetryOperation}
    representatives::Vector{Int}
    multiplicities::Vector{Int}
    full_kpoint_count::Int
    tensor_plans::Vector{ResponseTensorSymmetryPlan}
    group_report::Dict{String, Any}
end

"""Preserve the pre-group-report execution-plan constructor for expert tests and callers."""
function ResponseSymmetryExecutionPlan(
    artifact_file,
    artifact_sha256,
    artifact_schema,
    artifact_sealed,
    production_eligible,
    model_sha256,
    structure_sha256,
    policy,
    kmesh_mode,
    explanation_only,
    status,
    covariance_status,
    covariance_max_relative_residual,
    covariance_tolerance,
    warnings,
    operations,
    representatives,
    multiplicities,
    full_kpoint_count,
    tensor_plans,
)
    return ResponseSymmetryExecutionPlan(
        artifact_file,
        artifact_sha256,
        artifact_schema,
        artifact_sealed,
        production_eligible,
        model_sha256,
        structure_sha256,
        policy,
        kmesh_mode,
        explanation_only,
        status,
        covariance_status,
        covariance_max_relative_residual,
        covariance_tolerance,
        warnings,
        operations,
        representatives,
        multiplicities,
        full_kpoint_count,
        tensor_plans,
        Dict{String, Any}(),
    )
end

"""
Preserve the schema-1.0 expert constructor as a reduced numerical plan.
"""
function ResponseSymmetryExecutionPlan(
    artifact_file,
    artifact_sha256,
    artifact_schema,
    artifact_sealed,
    production_eligible,
    model_sha256,
    structure_sha256,
    policy,
    status,
    covariance_status,
    covariance_max_relative_residual,
    covariance_tolerance,
    warnings,
    operations,
    representatives,
    multiplicities,
    full_kpoint_count,
    tensor_plans,
)
    return ResponseSymmetryExecutionPlan(
        artifact_file,
        artifact_sha256,
        artifact_schema,
        artifact_sealed,
        production_eligible,
        model_sha256,
        structure_sha256,
        policy,
        :reduced,
        false,
        status,
        covariance_status,
        covariance_max_relative_residual,
        covariance_tolerance,
        warnings,
        operations,
        representatives,
        multiplicities,
        full_kpoint_count,
        tensor_plans,
    )
end

# Normalize the public strict or diagnostic policy value.
function _response_symmetry_policy(value::AbstractString)
    policy = Symbol(_canonical_key(value))
    policy in (:strict, :diagnostic) || error(
        "response_symmetry_policy=$(repr(value)) is invalid; use \"strict\" or \"diagnostic\".",
    )
    return policy
end

"""Normalize the response-symmetry reduced/full k-mesh policy."""
function _response_symmetry_kmesh_mode(value::AbstractString)
    mode = Symbol(_canonical_key(value))
    mode in (:reduced, :full) || error(
        "response_symmetry_kmesh_mode=$(repr(value)) is invalid; use \"reduced\" or \"full\".",
    )
    return mode
end

"""Map each fused K-slice quantity to the ordered component it calculates."""
function _response_symmetry_calculated_components(specs, tensor_indices)
    components = Dict{Symbol, Any}()
    for spec in specs
        components[spec.quantity] = tensor_indices
    end
    return components
end

# Build the exact point-operation key used for group validation.
function _response_symmetry_operation_key(operation::ResponseSymmetryOperation)
    return (Tuple(vec(operation.rotation_fractional)), operation.antiunitary)
end

# Enforce exact fractional group integrity and bound Cartesian closure residuals.
function _validate_response_point_group(
    operations::Vector{ResponseSymmetryOperation};
    cartesian_tolerance::Real = 1.0e-8,
    fail_on_cartesian_residual::Bool = false,
)
    tolerance = Float64(cartesian_tolerance)
    isfinite(tolerance) && tolerance > 0.0 ||
        error("response symmetry Cartesian tolerance must be positive and finite.")
    isempty(operations) && error("response symmetry artifact contains no point-group operations.")
    key_to_index = Dict{Tuple{Tuple, Bool}, Int}()
    for (index, operation) in enumerate(operations)
        key = _response_symmetry_operation_key(operation)
        haskey(key_to_index, key) && error(
            "response symmetry point group contains duplicate operation indices $(key_to_index[key]) and $(index).",
        )
        key_to_index[key] = index
    end
    identity_key = (Tuple(vec(Matrix{Int}(I, 3, 3))), false)
    haskey(key_to_index, identity_key) ||
        error("response symmetry point group does not contain the unitary identity.")
    warning_messages = String[]
    maximum_cartesian_closure_residual = 0.0
    maximum_cartesian_closure_pair = (0, 0)
    for (left_index, left) in enumerate(operations), (right_index, right) in enumerate(operations)
        rotation = left.rotation_fractional * right.rotation_fractional
        antiunitary = xor(left.antiunitary, right.antiunitary)
        key = (Tuple(vec(rotation)), antiunitary)
        haskey(key_to_index, key) || error(
            "response symmetry point group is not closed: operation $(left_index) * $(right_index) is missing.",
        )
        product_index = key_to_index[key]
        expected_cartesian = left.rotation_cartesian * right.rotation_cartesian
        residual = maximum(abs, expected_cartesian - operations[product_index].rotation_cartesian)
        if residual > maximum_cartesian_closure_residual
            maximum_cartesian_closure_residual = residual
            maximum_cartesian_closure_pair = (left_index, right_index)
        end
    end
    for (index, operation) in enumerate(operations)
        inverse_rotation = round.(Int, inv(operation.rotation_fractional))
        key = (Tuple(vec(inverse_rotation)), operation.antiunitary)
        haskey(key_to_index, key) ||
            error("response symmetry point group has no inverse for operation $(index).")
    end
    if maximum_cartesian_closure_residual > tolerance
        message =
            "response symmetry Cartesian closure residual " *
            "$(maximum_cartesian_closure_residual) exceeds tolerance $(tolerance) " *
            "at operations $(maximum_cartesian_closure_pair)"
        if fail_on_cartesian_residual
            error(message)
        else
            @warn message
            push!(warning_messages, message)
        end
    end
    return warning_messages
end

# Require all structural qualifications declared by the artifact writer.
function _validate_response_artifact_declared_checks(artifact::ResponseSymmetryArtifact)
    symmetry = get(artifact.payload, "symmetry", nothing)
    symmetry isa AbstractDict || error("response symmetry artifact has no symmetry object.")
    checks = get(symmetry, "checks", nothing)
    checks isa AbstractDict || error("response symmetry artifact has no symmetry.checks object.")
    for key in ("identity", "inverse", "closure")
        get(checks, key, false) === true ||
            error("response symmetry artifact declared check $(key)=false or missing.")
    end
    if artifact.cartesian_rotation_policy != "legacy_raw_unspecified"
        for group_name in ("space_group", "point_group")
            group_check = get(checks, group_name, nothing)
            group_check isa AbstractDict || error(
                "response symmetry complete-contract artifact has no checks.$(group_name) object.",
            )
            get(group_check, "pass", false) === true ||
                error("response symmetry artifact declared checks.$(group_name).pass=false.")
        end
    end
    atom_mapping = get(checks, "atom_mapping", nothing)
    atom_mapping isa AbstractDict ||
        error("response symmetry artifact has no symmetry.checks.atom_mapping object.")
    haskey(atom_mapping, "pass") ||
        error("response symmetry artifact declared atom_mapping.pass missing.")
    get(atom_mapping, "pass", false) isa Bool ||
        error("response symmetry artifact atom_mapping.pass must be Boolean.")
    warning_messages = String[]
    if artifact.cartesian_rotation_policy != "legacy_raw_unspecified" &&
       get(atom_mapping, "bijection", false) !== true
        error("response symmetry complete-contract atom mapping is not a declared bijection.")
    end
    if get(atom_mapping, "pass", false) !== true
        message = "response symmetry artifact declared atom_mapping.pass=false"
        @warn message
        push!(warning_messages, message)
    end
    cartesian =
        artifact.cartesian_rotation_policy != "legacy_raw_unspecified" ?
        get(checks, "cartesian_rotation", nothing) : get(checks, "cartesian_orthogonality", nothing)
    if artifact.cartesian_rotation_policy != "legacy_raw_unspecified" &&
       !(cartesian isa AbstractDict)
        error("response symmetry complete-contract artifact has no cartesian_rotation check.")
    end
    if cartesian isa AbstractDict &&
       get(cartesian, "production_pass", get(cartesian, "pass", true)) !== true
        residual = get(
            cartesian,
            "maximum_effective_orthogonality_residual",
            get(cartesian, "maximum_residual", "unknown"),
        )
        message =
            "response symmetry artifact declared Cartesian rotation qualification warning; " *
            "maximum_residual=$(residual)"
        @warn message
        push!(warning_messages, message)
    end
    if artifact.cartesian_rotation_policy != "legacy_raw_unspecified"
        stability = get(checks, "tolerance_stability", nothing)
        stability isa AbstractDict ||
            error("response symmetry complete-contract artifact has no tolerance_stability check.")
        if get(stability, "pass", false) !== true
            message = "response symmetry artifact declared tolerance_stability.pass=false"
            @warn message
            push!(warning_messages, message)
        end
    end
    return warning_messages
end

# Read writer-recorded warning strings without requiring them in legacy artifacts.
function _response_artifact_warning_messages(artifact::ResponseSymmetryArtifact)
    qualification = get(artifact.payload, "qualification", nothing)
    qualification isa AbstractDict || return String[]
    raw = get(qualification, "warnings", Any[])
    raw isa AbstractVector || error("response symmetry qualification.warnings must be an array.")
    return String[string(item) for item in raw]
end

# Extend a two-dimensional mesh with its fixed unit third axis.
function _response_symmetry_mesh3(k_mesh::Union{NTuple{2, Int}, NTuple{3, Int}})
    return length(k_mesh) == 2 ? (k_mesh[1], k_mesh[2], 1) : k_mesh
end

# Construct the exact modular reciprocal-grid action of one operation.
function _response_symmetry_integer_action(
    operation::ResponseSymmetryOperation,
    mesh::NTuple{3, Int},
)
    reciprocal_rotation = round.(Int, inv(operation.rotation_fractional)')
    operation.rotation_fractional' * reciprocal_rotation == Matrix{Int}(I, 3, 3) ||
        error("response symmetry fractional rotation has no exact integer reciprocal inverse.")
    operation.antiunitary && (reciprocal_rotation .*= -1)
    action = zeros(Int, 3, 3)
    for output_axis in 1:3, input_axis in 1:3
        numerator = mesh[output_axis] * reciprocal_rotation[output_axis, input_axis]
        denominator = mesh[input_axis]
        numerator % denominator == 0 || error(
            "response symmetry operation does not close k_mesh=$(mesh): " *
            "axis coefficient ($(output_axis),$(input_axis))=$(numerator)/$(denominator) is non-integral.",
        )
        action[output_axis, input_axis] = div(numerator, denominator)
    end
    return action
end

# Decode one linear Gamma-centered mesh index into zero-based coordinates.
function _response_symmetry_decode_index(index::Int, mesh::NTuple{3, Int})
    zero_index = index - 1
    first = zero_index % mesh[1]
    second = (zero_index ÷ mesh[1]) % mesh[2]
    third = zero_index ÷ (mesh[1] * mesh[2])
    return (first, second, third)
end

# Encode zero-based modular mesh coordinates into one linear index.
function _response_symmetry_encode_index(indices::NTuple{3, Int}, mesh::NTuple{3, Int})
    return indices[1] + mesh[1] * indices[2] + mesh[1] * mesh[2] * indices[3] + 1
end

# Verify and return the full mesh permutation induced by one operation.
function _response_symmetry_permutation(operation::ResponseSymmetryOperation, mesh::NTuple{3, Int})
    action = _response_symmetry_integer_action(operation, mesh)
    point_count = prod(mesh)
    permutation = Vector{Int}(undef, point_count)
    seen = falses(point_count)
    for index in 1:point_count
        coordinates = _response_symmetry_decode_index(index, mesh)
        mapped = ntuple(
            axis -> mod(
                sum(action[axis, source] * coordinates[source] for source in 1:3),
                mesh[axis],
            ),
            3,
        )
        mapped_index = _response_symmetry_encode_index(mapped, mesh)
        seen[mapped_index] &&
            error("response symmetry operation is not a permutation of k_mesh=$(mesh).")
        seen[mapped_index] = true
        permutation[index] = mapped_index
    end
    all(seen) || error("response symmetry operation does not cover the complete k mesh.")
    return permutation
end

# Merge two orbit nodes through deterministic union-find representatives.
function _response_symmetry_union!(parent::Vector{Int}, left::Int, right::Int)
    while parent[left] != left
        parent[left] = parent[parent[left]]
        left = parent[left]
    end
    while parent[right] != right
        parent[right] = parent[parent[right]]
        right = parent[right]
    end
    left == right && return nothing
    if left < right
        parent[right] = left
    else
        parent[left] = right
    end
    return nothing
end

"""Build exact Gamma-centred integer orbits and multiplicities."""
function response_symmetry_kmesh_orbits(k_mesh, operations::Vector{ResponseSymmetryOperation})
    mesh = _response_symmetry_mesh3(k_mesh)
    all(>(0), mesh) || error("response symmetry k mesh entries must be positive.")
    permutations = [_response_symmetry_permutation(operation, mesh) for operation in operations]
    point_count = prod(mesh)
    parent = collect(1:point_count)
    for permutation in permutations, index in 1:point_count
        _response_symmetry_union!(parent, index, permutation[index])
    end
    for index in 1:point_count
        root = index
        while parent[root] != root
            root = parent[root]
        end
        parent[index] = root
    end
    groups = Dict{Int, Vector{Int}}()
    for index in 1:point_count
        push!(get!(groups, parent[index], Int[]), index)
    end
    representatives = sort!([minimum(group) for group in values(groups)])
    multiplicity_by_representative =
        Dict(minimum(group) => length(group) for group in values(groups))
    multiplicities = [multiplicity_by_representative[index] for index in representatives]
    sum(multiplicities) == point_count ||
        error("response symmetry orbit multiplicities do not sum to the full k mesh.")
    return (
        representatives = representatives,
        multiplicities = multiplicities,
        permutations = permutations,
        full_kpoint_count = point_count,
    )
end

# Validate and normalize one response-validation SHA-256 string.
function _response_validation_sha256(value, context::AbstractString)
    normalized = lowercase(strip(String(value)))
    length(normalized) == 64 &&
    all(character -> character in ('0':'9') || character in ('a':'f'), normalized) ||
        throw(ArgumentError("$(context) must be a 64-character hexadecimal SHA-256 digest"))
    return normalized
end

"""
Stream a complete response-integrand covariance comparison without a full-grid cache.

The evaluator receives a one-based mesh index and its fractional k point, and
returns a component-by-frequency matrix. Every operation, source k point,
frequency, and tensor component is checked against the final-tensor action. The
antiunitary rule is already part of that real action; no additional complex
conjugation is applied here.
"""
function validate_response_integrand_covariance(
    evaluator,
    k_mesh,
    operations::Vector{ResponseSymmetryOperation};
    quantity::Symbol = :shift_current,
    spatial_dimension::Integer = 3,
    photon_energies,
    absolute_tolerance::Real = 1.0e-10,
    relative_tolerance::Real = 1.0e-8,
    input_sha256::Union{Nothing, AbstractString} = nothing,
)
    mesh = _response_symmetry_mesh3(k_mesh)
    all(>(0), mesh) || error("integrand covariance k-mesh entries must be positive.")
    frequencies = Float64.(collect(photon_energies))
    isempty(frequencies) && error("integrand covariance requires photon energies.")
    all(isfinite, frequencies) || error("integrand covariance photon energies are non-finite.")
    absolute_threshold = Float64(absolute_tolerance)
    relative_threshold = Float64(relative_tolerance)
    isfinite(absolute_threshold) && absolute_threshold > 0.0 ||
        error("integrand covariance absolute tolerance must be positive and finite.")
    isfinite(relative_threshold) && relative_threshold > 0.0 ||
        error("integrand covariance relative tolerance must be positive and finite.")
    normalized_input_sha256 =
        input_sha256 === nothing ? nothing :
        _response_validation_sha256(input_sha256, "integrand covariance input_sha256")

    labels = response_component_labels(quantity, spatial_dimension)
    component_count = length(labels)
    permutations = [_response_symmetry_permutation(operation, mesh) for operation in operations]
    actions = [
        response_symmetry_action_matrix(
            quantity,
            spatial_dimension,
            operation.rotation_cartesian,
            operation.antiunitary,
        ) for operation in operations
    ]
    maximum_absolute = 0.0
    maximum_mixed = 0.0
    squared_difference = 0.0
    squared_reference = 0.0
    nonfinite_count = 0
    worst = (operation = 0, source_kpoint = 0, target_kpoint = 0, frequency = 0, component = 0)
    evaluation_count = 0

    function evaluated(index::Int)
        coordinates = _response_symmetry_decode_index(index, mesh)
        kpoint = ntuple(axis -> coordinates[axis] / mesh[axis], 3)
        values = Matrix(evaluator(index, kpoint))
        size(values) == (component_count, length(frequencies)) || error(
            "integrand evaluator returned size $(size(values)); expected " *
            "($(component_count), $(length(frequencies))).",
        )
        evaluation_count += 1
        return values
    end

    for source in 1:prod(mesh)
        source_values = evaluated(source)
        for operation_index in eachindex(operations)
            target = permutations[operation_index][source]
            target_values = evaluated(target)
            expected_values = actions[operation_index] * source_values
            for frequency in eachindex(frequencies), component in 1:component_count
                actual = target_values[component, frequency]
                expected = expected_values[component, frequency]
                if !isfinite(actual) || !isfinite(expected)
                    nonfinite_count += 1
                    continue
                end
                difference = abs(actual - expected)
                scale = max(abs(actual), abs(expected))
                mixed = difference / (absolute_threshold + relative_threshold * scale)
                squared_difference += abs2(actual - expected)
                squared_reference += abs2(expected)
                if mixed > maximum_mixed ||
                   (mixed == maximum_mixed && difference > maximum_absolute)
                    maximum_mixed = mixed
                    maximum_absolute = difference
                    worst = (
                        operation = operation_index,
                        source_kpoint = source,
                        target_kpoint = target,
                        frequency,
                        component,
                    )
                else
                    maximum_absolute = max(maximum_absolute, difference)
                end
            end
        end
    end
    l2_relative = sqrt(squared_difference / max(squared_reference, eps(Float64)))
    pass = nonfinite_count == 0 && maximum_mixed <= 1.0 && l2_relative <= relative_threshold
    return Dict{String, Any}(
        "status" => pass ? "PASS" : "FAIL",
        "pass" => pass,
        "contract" => "stream_all_operations_kpoints_frequencies_components_no_extra_conjugation",
        "k_mesh" => collect(mesh),
        "operation_count" => length(operations),
        "kpoint_count" => prod(mesh),
        "frequency_count" => length(frequencies),
        "component_count" => component_count,
        "comparison_count" =>
            length(operations) * prod(mesh) * length(frequencies) * component_count,
        "evaluator_call_count" => evaluation_count,
        "absolute_tolerance" => absolute_threshold,
        "relative_tolerance" => relative_threshold,
        "maximum_absolute_residual" => maximum_absolute,
        "maximum_mixed_error" => maximum_mixed,
        "l2_relative" => l2_relative,
        "maximum_relative_residual" => l2_relative,
        "tolerance" => relative_threshold,
        "nonfinite_count" => nonfinite_count,
        "input_sha256" => normalized_input_sha256,
        "worst" => Dict(
            "operation_index" => worst.operation,
            "source_kpoint_index" => worst.source_kpoint,
            "target_kpoint_index" => worst.target_kpoint,
            "photon_energy_index" => worst.frequency,
            "photon_energy" => worst.frequency == 0 ? nothing : frequencies[worst.frequency],
            "component_index" => worst.component,
            "component_label" => worst.component == 0 ? nothing : labels[worst.component],
        ),
    )
end

"""Compare full-grid and reduced-grid response tensors under one mixed gate."""
function validate_response_full_grid_consistency(
    full_values::AbstractArray,
    reduced_values::AbstractArray;
    absolute_tolerance::Real = 1.0e-10,
    relative_tolerance::Real = 1.0e-8,
    nonzero_l2_relative_tolerance::Real = 1.0e-8,
    full_input_sha256::Union{Nothing, AbstractString} = nothing,
    reduced_input_sha256::Union{Nothing, AbstractString} = nothing,
)
    size(full_values) == size(reduced_values) || throw(
        DimensionMismatch(
            "full/reduced response shapes differ: $(size(full_values)) and $(size(reduced_values))",
        ),
    )
    isempty(full_values) && throw(ArgumentError("full-grid consistency arrays must not be empty"))
    absolute_threshold = Float64(absolute_tolerance)
    relative_threshold = Float64(relative_tolerance)
    l2_threshold = Float64(nonzero_l2_relative_tolerance)
    all(
        value -> isfinite(value) && value > 0.0,
        (absolute_threshold, relative_threshold, l2_threshold),
    ) || throw(ArgumentError("full-grid consistency tolerances must be positive and finite"))
    xor(full_input_sha256 === nothing, reduced_input_sha256 === nothing) &&
        throw(ArgumentError("full_input_sha256 and reduced_input_sha256 must be supplied together"))
    normalized_input_sha256 = nothing
    if full_input_sha256 !== nothing
        normalized_full = _response_validation_sha256(full_input_sha256, "full-grid input SHA-256")
        normalized_reduced =
            _response_validation_sha256(reduced_input_sha256, "reduced-grid input SHA-256")
        normalized_full == normalized_reduced ||
            throw(ArgumentError("full/reduced response inputs do not have the same SHA-256 digest"))
        normalized_input_sha256 = normalized_full
    end

    maximum_absolute = 0.0
    maximum_mixed = 0.0
    difference_square_sum = 0.0
    reference_square_sum = 0.0
    nonzero_count = 0
    nonfinite_count = 0
    worst_index = first(CartesianIndices(full_values))
    for index in CartesianIndices(full_values)
        full_value = full_values[index]
        reduced_value = reduced_values[index]
        if !isfinite(full_value) || !isfinite(reduced_value)
            nonfinite_count += 1
            continue
        end
        difference = abs(reduced_value - full_value)
        scale = max(abs(full_value), abs(reduced_value))
        mixed = difference / (absolute_threshold + relative_threshold * scale)
        if mixed > maximum_mixed || (mixed == maximum_mixed && difference > maximum_absolute)
            maximum_mixed = mixed
            maximum_absolute = difference
            worst_index = index
        else
            maximum_absolute = max(maximum_absolute, difference)
        end
        if scale > absolute_threshold
            difference_square_sum += abs2(reduced_value - full_value)
            reference_square_sum += abs2(full_value)
            nonzero_count += 1
        end
    end
    nonzero_l2_relative =
        nonzero_count == 0 ? 0.0 :
        sqrt(difference_square_sum / max(reference_square_sum, eps(Float64)))
    pass = nonfinite_count == 0 && maximum_mixed <= 1.0 && nonzero_l2_relative <= l2_threshold
    return Dict{String, Any}(
        "status" => pass ? "PASS" : "FAIL",
        "pass" => pass,
        "shape" => collect(size(full_values)),
        "element_count" => length(full_values),
        "nonzero_element_count" => nonzero_count,
        "nonfinite_count" => nonfinite_count,
        "absolute_tolerance" => absolute_threshold,
        "relative_tolerance" => relative_threshold,
        "nonzero_l2_relative_tolerance" => l2_threshold,
        "maximum_absolute_residual" => maximum_absolute,
        "maximum_mixed_error" => maximum_mixed,
        "nonzero_l2_relative" => nonzero_l2_relative,
        "worst_cartesian_index" => collect(Tuple(worst_index)),
        "same_input_sha256" => normalized_input_sha256,
    )
end

# Construct the projector basis and selected raw-component plan for one response.
function _response_tensor_symmetry_plan(
    quantity::Symbol,
    spatial_dimension::Int,
    operations::Vector{ResponseSymmetryOperation},
    ;
    numerical_reduction::Bool = true,
)
    projector_raw =
        response_symmetry_projector(quantity, spatial_dimension, operations; component_part = :real)
    imaginary_projector_raw = response_symmetry_projector(
        quantity,
        spatial_dimension,
        operations;
        component_part = :imaginary,
    )
    idempotence_residual = maximum(abs, projector_raw * projector_raw - projector_raw)
    imaginary_idempotence_residual =
        maximum(abs, imaginary_projector_raw * imaginary_projector_raw - imaginary_projector_raw)
    if idempotence_residual > 1.0e-10
        @warn "response symmetry group-average idempotence residual $(idempotence_residual) " *
              "exceeds warning threshold 1.0e-10 for quantity=$(quantity)"
    end
    basis = response_symmetry_basis(projector_raw; tolerance = 1.0e-12)
    imaginary_basis = response_symmetry_basis(imaginary_projector_raw; tolerance = 1.0e-12)
    projector = basis * basis'
    imaginary_projector = imaginary_basis * imaginary_basis'
    relations = response_symmetry_relations(quantity, spatial_dimension, projector)
    imaginary_relations =
        response_symmetry_relations(quantity, spatial_dimension, imaginary_projector)
    basis_support_indices = findall(
        index -> any(abs(value) > 1.0e-12 for value in @view basis[index, :]),
        axes(basis, 1),
    )
    full_component_indices = collect(axes(basis, 1))
    imaginary_basis_support_indices = findall(
        index -> any(abs(value) > 1.0e-12 for value in @view imaginary_basis[index, :]),
        axes(imaginary_basis, 1),
    )
    # Validation-only oracle: execute the same representatives and projector
    # through the dense response kernels without changing the public EffectiveTaskConfig.
    force_dense = lowercase(strip(get(ENV, "WANNIERNLQG_RESPONSE_SYMMETRY_FORCE_DENSE", "0"))) in
    ("1", "true", "yes", "on")
    combined_support = sort!(unique(vcat(basis_support_indices, imaginary_basis_support_indices)))
    use_selected_components =
        numerical_reduction &&
        !force_dense &&
        length(combined_support) < length(full_component_indices)
    raw_component_indices = use_selected_components ? combined_support : full_component_indices
    path =
        !numerical_reduction ? :full_kmesh_explanation_only :
        use_selected_components ? :selected_component_kernel_compact_coefficients :
        :dense_kernel_compact_coefficients
    return ResponseTensorSymmetryPlan(
        quantity,
        relations.labels,
        projector,
        imaginary_projector,
        basis,
        imaginary_basis,
        relations.forbidden,
        imaginary_relations.forbidden,
        relations.equal,
        imaginary_relations.equal,
        relations.opposite,
        imaginary_relations.opposite,
        relations.constraint_matrix,
        imaginary_relations.constraint_matrix,
        basis_support_indices,
        raw_component_indices,
        path,
        idempotence_residual,
        imaginary_idempotence_residual,
    )
end

# Convert a matrix into JSON-compatible row arrays.
function _response_symmetry_matrix_rows(matrix::AbstractMatrix)
    return [[matrix[row, column] for column in axes(matrix, 2)] for row in axes(matrix, 1)]
end

# Serialize nonzero rows of the general linear constraint X equals P X.
function _response_symmetry_linear_equations(tensor_plan::ResponseTensorSymmetryPlan)
    equations = String[]
    for row in axes(tensor_plan.constraint_matrix, 1)
        coefficients = @view tensor_plan.constraint_matrix[row, :]
        first_nonzero = findfirst(value -> abs(value) > 1.0e-12, coefficients)
        first_nonzero === nothing && continue
        scale = coefficients[first_nonzero]
        normalized = coefficients ./ scale
        terms = String[]
        for column in eachindex(normalized)
            abs(normalized[column]) > 1.0e-12 || continue
            push!(
                terms,
                @sprintf("%+.16g*%s", normalized[column], tensor_plan.component_labels[column]),
            )
        end
        push!(equations, join(terms, " ") * " = 0")
    end
    return equations
end

# Assemble the complete machine-readable response symmetry summary.
function _response_symmetry_summary_payload(
    plan::ResponseSymmetryExecutionPlan;
    calculated_components = Dict{Symbol, Any}(),
)
    response_entries = Dict{String, Any}()
    for tensor_plan in plan.tensor_plans
        real_part = _response_part_symmetry_model(tensor_plan, :real)
        imaginary_part = _response_part_symmetry_model(tensor_plan, :imaginary)
        response_entries[string(tensor_plan.quantity)] = Dict(
            "component_labels" => tensor_plan.component_labels,
            "raw_component_count" => length(tensor_plan.raw_component_indices),
            "raw_component_indices" => tensor_plan.raw_component_indices,
            "basis_support_indices" => tensor_plan.basis_support_indices,
            "accumulation_path" => string(tensor_plan.accumulation_path),
            "projector_idempotence_residual" => tensor_plan.projector_idempotence_residual,
            "imaginary_projector_idempotence_residual" =>
                tensor_plan.imaginary_projector_idempotence_residual,
            "real_part" => _response_part_summary_payload(real_part),
            "imaginary_part" => _response_part_summary_payload(imaginary_part),
            "real_imaginary_components" => _response_ordered_slot_report(tensor_plan),
            "time_reversal" => _response_time_reversal_channel_table(tensor_plan.quantity),
            "calculated_component" => _response_calculated_component_report(
                tensor_plan,
                get(calculated_components, tensor_plan.quantity, nothing),
            ),
        )
    end
    return Dict{String, Any}(
        "schema" => "wanniernlqg.response-symmetry-summary/1.0",
        "status" => string(plan.status),
        "policy" => string(plan.policy),
        "kmesh_mode" => string(plan.kmesh_mode),
        "explanation_only" => plan.explanation_only,
        "numerical_tensor_projection_applied" =>
            plan.kmesh_mode == :reduced && !plan.explanation_only,
        "warnings" => plan.warnings,
        "artifact_file" => basename(plan.artifact_file),
        "artifact_sha256" => plan.artifact_sha256,
        "artifact_schema" => plan.artifact_schema,
        "artifact_sealed" => plan.artifact_sealed,
        "production_eligible" => plan.production_eligible,
        "model_sha256" => plan.model_sha256,
        "structure_sha256" => plan.structure_sha256,
        "integrand_covariance" => Dict(
            "status" => plan.covariance_status,
            "maximum_relative_residual" => plan.covariance_max_relative_residual,
            "tolerance" => plan.covariance_tolerance,
        ),
        "k_mesh" => Dict(
            "full_kpoint_count" => plan.full_kpoint_count,
            "representative_count" => length(plan.representatives),
            "representatives_one_based" => plan.representatives,
            "multiplicities" => plan.multiplicities,
            "reduction_factor" => plan.full_kpoint_count / length(plan.representatives),
        ),
        "group_classification" =>
            get(plan.group_report, "group_classification", Dict("status" => "UNRESOLVED")),
        "active_constraint_group" =>
            get(plan.group_report, "active_constraint_group", Dict("status" => "UNRESOLVED")),
        "generators" => get(plan.group_report, "generators", Dict("status" => "UNRESOLVED")),
        "classification_source" =>
            get(plan.group_report, "classification_source", Dict("status" => "NOT_RECORDED")),
        "responses" => response_entries,
    )
end

# Write the projector, basis, orbit, and relation summary beside results.
function _write_response_symmetry_summary(
    plan::ResponseSymmetryExecutionPlan,
    run_dir::AbstractString,
    ;
    calculated_components = Dict{Symbol, Any}(),
)
    path = joinpath(run_dir, "response_symmetry_summary.json")
    open(path, "w") do io
        write(
            io,
            progress_json_value(_response_symmetry_summary_payload(plan; calculated_components)),
            '\n',
        )
    end
    return path
end

# Validate one artifact against a task bundle and build its runtime plan.
function _build_response_symmetry_execution_plan(
    cfg::EffectiveTaskConfig,
    ctx::RunContext,
    specs::Vector{NormalizedTaskSpec},
    artifact_file::String,
)
    artifact = read_response_symmetry_artifact(artifact_file)
    policy = _response_symmetry_policy(cfg.response_symmetry_policy)
    kmesh_mode = _response_symmetry_kmesh_mode(cfg.response_symmetry_kmesh_mode)
    calculation = only(unique(spec.calculation for spec in specs))
    explanation_only = calculation == :kslice || kmesh_mode == :full
    artifact.model_sha256 == lowercase(ctx.model_sha256) || error(
        "response symmetry artifact model SHA-256 $(artifact.model_sha256) does not match runtime model $(ctx.model_sha256).",
    )
    if policy == :strict
        artifact.cartesian_rotation_policy != "legacy_raw_unspecified" || error(
            "response_symmetry_policy=strict rejects legacy artifact schema $(artifact.schema); " *
            "the historical 1.0 field contract is diagnostic-only.",
        )
        artifact.sealed ||
            error("response_symmetry_policy=strict requires a sealed complete-contract artifact.")
        artifact.production_eligible ||
            error("response_symmetry_policy=strict requires production_eligible=true.")
    end
    warning_messages = _response_artifact_warning_messages(artifact)
    if artifact.cartesian_rotation_policy == "legacy_raw_unspecified"
        push!(
            warning_messages,
            "legacy response-symmetry schema $(artifact.schema) is diagnostic-only",
        )
    elseif !artifact.sealed || !artifact.production_eligible
        push!(
            warning_messages,
            "unsealed or non-production complete-contract artifact is diagnostic-only",
        )
    end
    append!(warning_messages, _validate_response_artifact_declared_checks(artifact))
    append!(
        warning_messages,
        _validate_response_point_group(
            artifact.operations;
            cartesian_tolerance = artifact.cartesian_rotation_policy == "group_invariant_metric" ?
                                  1.0e-12 : 1.0e-8,
            fail_on_cartesian_residual = artifact.cartesian_rotation_policy ==
                                         "group_invariant_metric",
        ),
    )
    group_report = try
        response_symmetry_group_report(
            artifact.payload;
            strict = policy == :strict &&
                     artifact.cartesian_rotation_policy != "legacy_raw_unspecified",
        )
    catch exception
        policy == :strict && rethrow()
        message = "response symmetry group classification is unresolved: $(sprint(showerror, exception))"
        @warn message
        push!(warning_messages, message)
        Dict{String, Any}(
            "status" => "UNRESOLVED",
            "warnings" => [message],
            "group_classification" => Dict("status" => "UNRESOLVED"),
            "active_constraint_group" => Dict("status" => "UNRESOLVED"),
            "generators" => Dict("status" => "UNRESOLVED"),
            "classification_source" => Dict("status" => "NOT_RECORDED"),
        )
    end
    append!(warning_messages, String.(get(group_report, "warnings", String[])))
    orbits = if explanation_only
        count = prod(cfg.k_mesh)
        (
            representatives = collect(1:count),
            multiplicities = ones(Int, count),
            full_kpoint_count = count,
        )
    else
        response_symmetry_kmesh_orbits(cfg.k_mesh, artifact.operations)
    end
    if artifact.qualification_status != "PASS"
        message =
            "response symmetry integrand covariance status is " *
            "$(artifact.qualification_status); continuing as DIAGNOSTIC_ONLY"
        @warn message
        push!(warning_messages, message)
    end
    if artifact.covariance_max_relative_residual !== nothing &&
       artifact.covariance_max_relative_residual > artifact.covariance_tolerance
        message =
            "response symmetry integrand covariance residual " *
            "$(artifact.covariance_max_relative_residual) exceeds tolerance " *
            "$(artifact.covariance_tolerance); continuing as DIAGNOSTIC_ONLY"
        @warn message
        push!(warning_messages, message)
    end
    quantities = unique(spec.quantity for spec in specs)
    tensor_plans = ResponseTensorSymmetryPlan[
        _response_tensor_symmetry_plan(
            quantity,
            cfg.spatial_dimension,
            artifact.operations;
            numerical_reduction = !explanation_only,
        ) for quantity in quantities
    ]
    for tensor_plan in tensor_plans
        if tensor_plan.projector_idempotence_residual > 1.0e-10
            push!(
                warning_messages,
                "quantity=$(tensor_plan.quantity) projector idempotence residual " *
                "$(tensor_plan.projector_idempotence_residual) exceeds 1.0e-10",
            )
        end
    end
    unique!(warning_messages)
    status =
        artifact.production_eligible && artifact.sealed && isempty(warning_messages) ? :PASS :
        :DIAGNOSTIC_ONLY
    policy == :strict &&
        status != :PASS &&
        error(
            "response_symmetry_policy=strict encountered diagnostic warnings or incomplete gates: " *
            join(warning_messages, "; "),
        )
    return ResponseSymmetryExecutionPlan(
        artifact.source_path,
        artifact.artifact_sha256,
        artifact.schema,
        artifact.sealed,
        artifact.production_eligible,
        artifact.model_sha256,
        artifact.structure_sha256,
        policy,
        kmesh_mode,
        explanation_only,
        status,
        artifact.qualification_status,
        artifact.covariance_max_relative_residual,
        artifact.covariance_tolerance,
        warning_messages,
        artifact.operations,
        orbits.representatives,
        orbits.multiplicities,
        orbits.full_kpoint_count,
        tensor_plans,
        group_report,
    )
end

"""
Root-read and broadcast an immutable symmetry plan when symmetry is enabled.
"""
function prepare_response_symmetry_execution_plan(
    cfg::EffectiveTaskConfig,
    ctx::RunContext,
    specs::Vector{NormalizedTaskSpec},
    comm = bundle_mpi_comm_world(),
)
    kmesh_mode = _response_symmetry_kmesh_mode(cfg.response_symmetry_kmesh_mode)
    if kmesh_mode == :full && !cfg.response_symmetry_report_enabled
        cfg.response_symmetry_file === nothing || error(
            "response_symmetry_kmesh_mode=\"full\" with " *
            "response_symmetry_report_enabled=false cannot load response_symmetry_file.",
        )
        return nothing
    end
    kmesh_mode == :full &&
        cfg.response_symmetry_file === nothing &&
        error(
            "response_symmetry_kmesh_mode=\"full\" with " *
            "response_symmetry_report_enabled=true requires response_symmetry_file.",
        )
    cfg.response_symmetry_file === nothing && return nothing
    configured = strip(something(cfg.response_symmetry_file))
    isempty(configured) && error("response_symmetry_file must be nothing or a non-empty path.")
    case_root = resolve_case_root(cfg.case_root)
    artifact_file =
        isabspath(configured) ? normpath(configured) : normpath(joinpath(case_root, configured))
    plan = bundle_mpi_root_call(
        () -> _build_response_symmetry_execution_plan(cfg, ctx, specs, artifact_file);
        comm,
    )
    calculated_components = if any(spec -> spec.calculation == :kslice, specs)
        Dict(spec.quantity => cfg.tensor_indices for spec in specs)
    else
        Dict{Symbol, Any}()
    end
    mpi_is_root_process() &&
        _write_response_symmetry_summary(plan, ctx.run_dir; calculated_components)
    return plan
end

# Look up the tensor plan for one normalized response quantity.
function response_tensor_symmetry_plan(plan::ResponseSymmetryExecutionPlan, quantity::Symbol)
    index = findfirst(tensor_plan -> tensor_plan.quantity == quantity, plan.tensor_plans)
    index === nothing && error("missing response tensor symmetry plan for quantity=$(quantity)")
    return plan.tensor_plans[index]
end

# Report the actual raw-component workload used by the task bundle.
function response_symmetry_component_workload(
    plan::ResponseSymmetryExecutionPlan,
    specs::Vector{NormalizedTaskSpec},
    num_photon_energies::Int,
)
    return num_photon_energies * sum(
        length(response_tensor_symmetry_plan(plan, spec.quantity).raw_component_indices) for
        spec in specs
    )
end

# Reconstruct compact coefficients and enforce the final projector on states.
function apply_response_symmetry!(states, plan::ResponseSymmetryExecutionPlan)
    (plan.kmesh_mode == :full || plan.explanation_only) && return nothing
    for state in states
        tensor_plan = response_tensor_symmetry_plan(plan, state.spec.quantity)
        real_tensor = complex.(real.(state.global_data))
        imaginary_tensor = complex.(imag.(state.global_data))
        project_response_symmetry!(
            real_tensor,
            state.spec.quantity,
            length(size(state.global_data)) == 5 ? size(state.global_data, 2) :
            size(state.global_data, 2),
            tensor_plan.basis,
        )
        project_response_symmetry!(
            imaginary_tensor,
            state.spec.quantity,
            length(size(state.global_data)) == 5 ? size(state.global_data, 2) :
            size(state.global_data, 2),
            tensor_plan.imaginary_basis,
        )
        state.global_data .= complex.(real.(real_tensor), real.(imaginary_tensor))
    end
    return nothing
end

# Select the conventional tensor symbol used only in the human-readable report.
function _response_symmetry_tensor_symbol(quantity::Symbol)
    return quantity == :shift_current ? "σ" :
           quantity == :injection_current ? "η" :
           quantity == :shift_spin_current ? "σˢ" : quantity == :injection_spin_current ? "ηˢ" : "T"
end

# Prefix one Cartesian label without changing the machine-readable label contract.
function _response_symmetry_display_component(quantity::Symbol, label::AbstractString)
    return _response_symmetry_tensor_symbol(quantity) * "_" * String(label)
end

# Build signed graph classes while isolating inconsistent components as forbidden.
function _response_symmetry_signed_classes(
    labels::Vector{String},
    projector::AbstractMatrix,
    forbidden_labels::Vector{String},
    equal_pairs::Vector{Tuple{String, String}},
    opposite_pairs::Vector{Tuple{String, String}},
)
    label_to_index = Dict(label => index for (index, label) in pairs(labels))
    forbidden = Set(forbidden_labels)
    active = BitVector(norm(@view(projector[index, :])) > 1.0e-10 for index in eachindex(labels))
    adjacency = [Tuple{Int, Int}[] for _ in labels]
    for (left, right, sign) in ((left, right, 1) for (left, right) in equal_pairs)
        left_index = label_to_index[left]
        right_index = label_to_index[right]
        (left in forbidden || right in forbidden || !active[left_index] || !active[right_index]) &&
            continue
        push!(adjacency[left_index], (right_index, sign))
        push!(adjacency[right_index], (left_index, sign))
    end
    for (left, right) in opposite_pairs
        left_index = label_to_index[left]
        right_index = label_to_index[right]
        (left in forbidden || right in forbidden || !active[left_index] || !active[right_index]) &&
            continue
        push!(adjacency[left_index], (right_index, -1))
        push!(adjacency[right_index], (left_index, -1))
    end
    signs = zeros(Int, length(labels))
    classes = NamedTuple[]
    inconsistent_indices = Int[]
    for root in eachindex(labels)
        (labels[root] in forbidden || !active[root]) && continue
        signs[root] != 0 && continue
        signs[root] = 1
        queue = Int[root]
        members = Int[]
        inconsistent = false
        while !isempty(queue)
            current = popfirst!(queue)
            push!(members, current)
            for (target, edge_sign) in adjacency[current]
                expected = signs[current] * edge_sign
                if signs[target] == 0
                    signs[target] = expected
                    push!(queue, target)
                elseif signs[target] != expected
                    inconsistent = true
                end
            end
        end
        sort!(members)
        if inconsistent
            append!(inconsistent_indices, members)
            continue
        end
        representative_sign = signs[first(members)]
        class_signs = Int[signs[index] * representative_sign for index in members]
        push!(classes, (members = members, signs = class_signs))
    end
    sort!(unique!(inconsistent_indices))
    return (classes = classes, inconsistent_indices = inconsistent_indices)
end

# Verify that graph classes exactly represent the projector, not general constraints.
function _response_symmetry_simple_class_model(
    projector::AbstractMatrix,
    basis::AbstractMatrix,
    classes::Vector{NamedTuple};
    tolerance::Float64 = 1.0e-9,
)
    length(classes) == size(basis, 2) || return false
    ideal = zeros(Float64, size(projector))
    for class in classes
        normalization = length(class.members)
        for (left_position, left) in pairs(class.members),
            (right_position, right) in pairs(class.members)

            ideal[left, right] =
                class.signs[left_position] * class.signs[right_position] / normalization
        end
    end
    active = findall(index -> ideal[index, index] > 0.0, axes(ideal, 1))
    inactive = setdiff(collect(axes(ideal, 1)), active)
    active_residual =
        isempty(active) ? 0.0 :
        maximum(abs, ideal[active, active] - projector[active, active]; init = 0.0)
    inactive_leakage = isempty(inactive) ? 0.0 : maximum(abs, projector[inactive, :]; init = 0.0)
    return active_residual <= tolerance && inactive_leakage <= 1.0e-7
end

# Select the earliest linearly independent basis rows for general constraints.
function _response_symmetry_general_representative_indices(
    basis::AbstractMatrix;
    tolerance::Float64 = 1.0e-12,
)
    dimension = size(basis, 2)
    dimension == 0 && return Int[]
    orthonormal = Vector{Vector{Float64}}()
    selected = Int[]
    for row in axes(basis, 1)
        candidate = Vector{Float64}(@view basis[row, :])
        for direction in orthonormal
            candidate .-= dot(direction, candidate) .* direction
        end
        magnitude = norm(candidate)
        magnitude > tolerance || continue
        push!(orthonormal, candidate ./ magnitude)
        push!(selected, row)
        length(selected) == dimension && break
    end
    length(selected) == dimension || error(
        "could not select $(dimension) independent component rows from response symmetry basis",
    )
    return selected
end

"""Return the fixed q=0 Real-part and Imaginary-part time-reversal parities."""
function _response_time_reversal_channel_table(quantity::Symbol)
    quantity == :shift_current && return (
        real_part = :even,
        imaginary_part = :odd,
        description = "charge shift: Real part even, Imaginary part odd",
    )
    quantity == :injection_current && return (
        real_part = :odd,
        imaginary_part = :even,
        description = "charge injection: Real part odd, Imaginary part even",
    )
    quantity == :shift_spin_current && return (
        real_part = :odd,
        imaginary_part = :even,
        description = "spin shift: Real part odd, Imaginary part even",
    )
    quantity == :injection_spin_current && return (
        real_part = :even,
        imaginary_part = :odd,
        description = "spin injection: Real part even, Imaginary part odd",
    )
    throw(ArgumentError("time-reversal channel table is unavailable for $(quantity)"))
end

"""Report whether a component combination survives a symmetry projector."""
_response_symmetry_allowed(projector, vector) = norm(projector * vector) > 1.0e-10

"""Infer the Cartesian spatial dimension represented by a tensor plan."""
function _response_tensor_dimension(tensor_plan::ResponseTensorSymmetryPlan)
    spin_factor = tensor_plan.quantity in (:shift_spin_current, :injection_spin_current) ? 3 : 1
    dimension = round(Int, cbrt(length(tensor_plan.component_labels) / spin_factor))
    spin_factor * dimension^3 == length(tensor_plan.component_labels) || return nothing
    return dimension
end

"""Build the Real-even and Imaginary-odd field-index exchange projectors."""
function _response_real_imaginary_projectors(tensor_plan::ResponseTensorSymmetryPlan)
    dimension = _response_tensor_dimension(tensor_plan)
    dimension === nothing && error("cannot infer tensor dimension for response-symmetry report")
    components = response_component_tuples(tensor_plan.quantity, dimension)
    component_index = Dict(component => index for (index, component) in pairs(components))
    real_exchange = zeros(Float64, length(components), length(components))
    imaginary_exchange = zeros(Float64, length(components), length(components))
    for (index, component) in pairs(components)
        prefix = Base.front(Base.front(component))
        b, c = component[(end - 1):end]
        exchanged = (prefix..., c, b)
        exchanged_index = component_index[exchanged]
        real_exchange[index, index] += 0.5
        real_exchange[index, exchanged_index] += 0.5
        imaginary_exchange[index, index] += 0.5
        imaginary_exchange[index, exchanged_index] -= 0.5
    end
    real_raw = real_exchange * tensor_plan.projector * real_exchange
    imaginary_raw = imaginary_exchange * tensor_plan.imaginary_projector * imaginary_exchange
    real_basis = response_symmetry_basis(real_raw; tolerance = 1.0e-12)
    imaginary_basis = response_symmetry_basis(imaginary_raw; tolerance = 1.0e-12)
    return (
        real_projector = real_basis * transpose(real_basis),
        real_basis = real_basis,
        imaginary_projector = imaginary_basis * transpose(imaginary_basis),
        imaginary_basis = imaginary_basis,
    )
end

"""List Real/Imaginary allowedness for every Cartesian tensor component."""
function _response_ordered_slot_report(tensor_plan::ResponseTensorSymmetryPlan)
    projections = _response_real_imaginary_projectors(tensor_plan)
    dimension = _response_tensor_dimension(tensor_plan)
    dimension === nothing && error("cannot infer tensor dimension for response-symmetry report")
    components = response_component_tuples(tensor_plan.quantity, dimension)
    return [
        (
            component = _response_symmetry_display_component(tensor_plan.quantity, label),
            slot = label,
            real_part = norm(@view(projections.real_projector[index, :])) > 1.0e-10 ? :allowed :
                        :forbidden,
            imaginary_part = component[end - 1] == component[end] ? :identically_zero :
                             norm(@view(projections.imaginary_projector[index, :])) > 1.0e-10 ?
                             :allowed : :forbidden,
        ) for
        (index, (label, component)) in enumerate(zip(tensor_plan.component_labels, components))
    ]
end

"""Describe the calculated K-slice component after the complete slot inventory."""
function _response_calculated_component_report(tensor_plan, calculated_component)
    calculated_component === nothing && return nothing
    component = Tuple(Int.(collect(calculated_component)))
    components = response_component_tuples(
        tensor_plan.quantity,
        something(_response_tensor_dimension(tensor_plan), 1),
    )
    index = findfirst(==(component), components)
    index === nothing && return (component = join(component), status = :not_a_tensor_slot)
    return _response_ordered_slot_report(tensor_plan)[index]
end

"""Build one filtered Real- or Imaginary-part relation model for reporting."""
function _response_part_symmetry_model(
    tensor_plan::ResponseTensorSymmetryPlan,
    component_part::Symbol,
)
    component_part in (:real, :imaginary) || throw(
        ArgumentError("component_part must be :real or :imaginary; got $(repr(component_part))"),
    )
    projections = _response_real_imaginary_projectors(tensor_plan)
    projector =
        component_part == :real ? projections.real_projector : projections.imaginary_projector
    basis = component_part == :real ? projections.real_basis : projections.imaginary_basis
    dimension = _response_tensor_dimension(tensor_plan)
    dimension === nothing && error("cannot infer tensor dimension for response-symmetry report")
    relations = response_symmetry_relations(tensor_plan.quantity, dimension, projector)
    signed = _response_symmetry_signed_classes(
        tensor_plan.component_labels,
        projector,
        relations.forbidden,
        relations.equal,
        relations.opposite,
    )
    inconsistent_labels = tensor_plan.component_labels[signed.inconsistent_indices]
    forbidden_labels = sort!(
        unique(vcat(relations.forbidden, inconsistent_labels));
        by = label -> findfirst(==(label), tensor_plan.component_labels),
    )
    simple =
        isempty(signed.inconsistent_indices) &&
        _response_symmetry_simple_class_model(projector, basis, signed.classes)
    representative_indices =
        simple ? Int[first(class.members) for class in signed.classes] :
        _response_symmetry_general_representative_indices(basis)
    part_label = component_part == :real ? "Re" : "Im"
    relation_lines = String[]
    equal_pairs = Tuple{String, String}[]
    opposite_pairs = Tuple{String, String}[]
    for class in signed.classes
        for left_position in eachindex(class.members),
            right_position in (left_position + 1):length(class.members)

            left = tensor_plan.component_labels[class.members[left_position]]
            right = tensor_plan.component_labels[class.members[right_position]]
            if class.signs[left_position] == class.signs[right_position]
                push!(equal_pairs, (left, right))
            else
                push!(opposite_pairs, (left, right))
            end
        end
        length(class.members) > 1 || continue
        formatted = String[]
        for (position, index) in pairs(class.members)
            component = _response_symmetry_display_component(
                tensor_plan.quantity,
                tensor_plan.component_labels[index],
            )
            term = "$(part_label) $(component)"
            push!(formatted, class.signs[position] == 1 ? term : "-" * term)
        end
        push!(relation_lines, join(formatted, " = "))
    end
    simple || push!(relation_lines, "general tensor constraints; see JSON")
    return (
        component_part = component_part,
        component_labels = copy(tensor_plan.component_labels),
        projector = projector,
        basis = basis,
        constraint_matrix = Matrix{Float64}(I, size(projector)...) - projector,
        independent_dimension = size(basis, 2),
        representatives = String[
            _response_symmetry_display_component(
                tensor_plan.quantity,
                tensor_plan.component_labels[index],
            ) for index in representative_indices
        ],
        forbidden = forbidden_labels,
        equal = equal_pairs,
        opposite = opposite_pairs,
        relation_lines = relation_lines,
        simple_signed_equivalence_classes = simple,
        inconsistent_sign_components = String[inconsistent_labels...],
    )
end

# Preserve the internal single-argument helper for focused graph diagnostics.
function _response_symmetry_signed_classes(tensor_plan::ResponseTensorSymmetryPlan)
    return _response_symmetry_signed_classes(
        tensor_plan.component_labels,
        tensor_plan.projector,
        tensor_plan.forbidden,
        tensor_plan.equal,
        tensor_plan.opposite,
    )
end

"""Serialize one Real/Imaginary relation model without ambiguous zero-row pairs."""
function _response_part_summary_payload(model)
    labels = size(model.projector, 1)
    equations = String[]
    for row in 1:labels
        coefficients = @view model.constraint_matrix[row, :]
        first_nonzero = findfirst(value -> abs(value) > 1.0e-12, coefficients)
        first_nonzero === nothing && continue
        normalized = coefficients ./ coefficients[first_nonzero]
        terms = String[]
        for column in eachindex(normalized)
            abs(normalized[column]) > 1.0e-12 || continue
            push!(terms, @sprintf("%+.16g*%s", normalized[column], model.component_labels[column]))
        end
        push!(equations, join(terms, " ") * " = 0")
    end
    return Dict{String, Any}(
        "independent_dimension" => model.independent_dimension,
        "independent_representatives" => model.representatives,
        "forbidden" => model.forbidden,
        "equal" => [collect(pair) for pair in model.equal],
        "opposite" => [collect(pair) for pair in model.opposite],
        "symmetry_relations" => model.relation_lines,
        "projector" => _response_symmetry_matrix_rows(model.projector),
        "basis" => _response_symmetry_matrix_rows(model.basis),
        "constraint_matrix_I_minus_P" => _response_symmetry_matrix_rows(model.constraint_matrix),
        "constraint_equations" => equations,
        "simple_signed_equivalence_classes" => model.simple_signed_equivalence_classes,
        "inconsistent_sign_components" => model.inconsistent_sign_components,
    )
end

"""Return one layered, deterministic human-readable tensor symmetry summary."""
function response_symmetry_human_summary(
    tensor_plan::ResponseTensorSymmetryPlan,
    plan::ResponseSymmetryExecutionPlan,
    ;
    calculated_component = nothing,
)
    real_part = _response_part_symmetry_model(tensor_plan, :real)
    imaginary_part = _response_part_symmetry_model(tensor_plan, :imaginary)
    qualification_note =
        plan.status == :PASS && plan.production_eligible ?
        "Tensor constraints are structurally qualified by the sealed artifact." :
        "Tensor constraints are structural diagnostics; physical production eligibility remains blocked."
    return (
        quantity = tensor_plan.quantity,
        title = uppercase(replace(string(tensor_plan.quantity), "_" => "-")) *
                " TENSOR SYMMETRY SUMMARY",
        input_cartesian_components = length(tensor_plan.component_labels),
        candidate_raw_slots = length(tensor_plan.raw_component_indices),
        real_independent_dimension = real_part.independent_dimension,
        imaginary_independent_dimension = imaginary_part.independent_dimension,
        real_independent_representatives = real_part.representatives,
        imaginary_independent_representatives = imaginary_part.representatives,
        real_symmetry_relations = real_part.relation_lines,
        imaginary_symmetry_relations = imaginary_part.relation_lines,
        real_forbidden_components = String[
            _response_symmetry_display_component(tensor_plan.quantity, label) for
            label in real_part.forbidden
        ],
        imaginary_forbidden_components = String[
            _response_symmetry_display_component(tensor_plan.quantity, label) for
            label in imaginary_part.forbidden
        ],
        real_imaginary_components = _response_ordered_slot_report(tensor_plan),
        time_reversal = _response_time_reversal_channel_table(tensor_plan.quantity),
        calculated_component = _response_calculated_component_report(
            tensor_plan,
            calculated_component,
        ),
        real_simple_signed_equivalence_classes = real_part.simple_signed_equivalence_classes,
        imaginary_simple_signed_equivalence_classes = imaginary_part.simple_signed_equivalence_classes,
        qualification = plan.status,
        qualification_note = qualification_note,
        summary_file = "response_symmetry_summary.json",
    )
end

# Return flattened plan metadata for human-readable and JSONL outputs.
function response_symmetry_metadata(
    plan::ResponseSymmetryExecutionPlan;
    calculated_components = Dict{Symbol, Any}(),
)
    part_models = Dict(
        tensor_plan.quantity => (
            real = _response_part_symmetry_model(tensor_plan, :real),
            imaginary = _response_part_symmetry_model(tensor_plan, :imaginary),
        ) for tensor_plan in plan.tensor_plans
    )
    independent = Dict(
        string(quantity) => Dict(
            "real_part" => models.real.independent_dimension,
            "imaginary_part" => models.imaginary.independent_dimension,
        ) for (quantity, models) in part_models
    )
    raw_counts = Dict(
        string(tensor_plan.quantity) => length(tensor_plan.raw_component_indices) for
        tensor_plan in plan.tensor_plans
    )
    support_counts = Dict(
        string(tensor_plan.quantity) => length(tensor_plan.basis_support_indices) for
        tensor_plan in plan.tensor_plans
    )
    paths = Dict(
        string(tensor_plan.quantity) => string(tensor_plan.accumulation_path) for
        tensor_plan in plan.tensor_plans
    )
    forbidden = Dict(
        string(quantity) => Dict(
            "real_part" => models.real.forbidden,
            "imaginary_part" => models.imaginary.forbidden,
        ) for (quantity, models) in part_models
    )
    equal = Dict(
        string(quantity) => Dict(
            "real_part" => [join(pair, "=") for pair in models.real.equal],
            "imaginary_part" => [join(pair, "=") for pair in models.imaginary.equal],
        ) for (quantity, models) in part_models
    )
    opposite = Dict(
        string(quantity) => Dict(
            "real_part" => [join(pair, "=-") for pair in models.real.opposite],
            "imaginary_part" => [join(pair, "=-") for pair in models.imaginary.opposite],
        ) for (quantity, models) in part_models
    )
    human_summaries = [
        response_symmetry_human_summary(
            tensor_plan,
            plan;
            calculated_component = get(calculated_components, tensor_plan.quantity, nothing),
        ) for tensor_plan in plan.tensor_plans
    ]
    return (
        enabled = true,
        status = plan.status,
        policy = plan.policy,
        kmesh_mode = plan.kmesh_mode,
        explanation_only = plan.explanation_only,
        numerical_tensor_projection_applied = plan.kmesh_mode == :reduced && !plan.explanation_only,
        artifact_file = plan.artifact_file,
        artifact_sha256 = plan.artifact_sha256,
        artifact_schema = plan.artifact_schema,
        artifact_sealed = plan.artifact_sealed,
        production_eligible = plan.production_eligible,
        model_sha256 = plan.model_sha256,
        structure_sha256 = plan.structure_sha256,
        full_kpoint_count = plan.full_kpoint_count,
        representative_kpoint_count = length(plan.representatives),
        represented_weight = sum(plan.multiplicities),
        reduction_factor = plan.full_kpoint_count / length(plan.representatives),
        multiplicities = plan.multiplicities,
        independent_dimensions = independent,
        basis_support_component_counts = support_counts,
        raw_component_counts = raw_counts,
        accumulation_paths = paths,
        forbidden_components = forbidden,
        equal_components = equal,
        opposite_components = opposite,
        human_summaries = human_summaries,
        covariance_status = plan.covariance_status,
        covariance_max_relative_residual = plan.covariance_max_relative_residual,
        covariance_tolerance = plan.covariance_tolerance,
        symmetry_warnings = plan.warnings,
        symmetry_warning_count = length(plan.warnings),
        group_classification = get(
            plan.group_report,
            "group_classification",
            Dict("status" => "UNRESOLVED"),
        ),
        active_constraint_group = get(
            plan.group_report,
            "active_constraint_group",
            Dict("status" => "UNRESOLVED"),
        ),
        point_group_generators = get(
            get(plan.group_report, "generators", Dict()),
            "active_point_group",
            Dict("status" => "UNRESOLVED", "generators" => Any[]),
        ),
        summary_file = "response_symmetry_summary.json",
    )
end
