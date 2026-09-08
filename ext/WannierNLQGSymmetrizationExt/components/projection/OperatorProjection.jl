# Convert serialized TB/cache values to the no-degeneracy group-projection convention.
function _normalized_real_space_operator(
    spec::RealSpaceOperatorSymmetrySpec,
    model::TightBindingModel,
    values,
)
    normalized = ComplexF64.(values)
    for r_index in 1:model.num_r_vectors
        selectdim(normalized, ndims(normalized), r_index) ./= model.r_degeneracies[r_index]
    end
    return RealSpaceOperator(spec, model.r_vectors, normalized)
end

# Require identical generated R support across operator results.
function _common_result_r_vectors(results)
    first_vectors = first(results).operator.r_vectors
    for result in Iterators.drop(results, 1)
        result.operator.r_vectors == first_vectors ||
            throw(ArgumentError("symmetrized operators produced inconsistent R support"))
    end
    return first_vectors
end

# Resolve retained input degeneracies and assign one to generated R vectors.
function _output_degeneracies(model::TightBindingModel, r_vectors::Matrix{Int})
    input_degeneracy = Dict(
        r_vector_key(model.r_vectors, index) => model.r_degeneracies[index] for
        index in 1:model.num_r_vectors
    )
    return [
        get(input_degeneracy, r_vector_key(r_vectors, index), 1) for index in axes(r_vectors, 2)
    ]
end

# Convert no-degeneracy projected values back to the package serialized convention.
function _serialized_operator_values(operator::RealSpaceOperator, degeneracies::Vector{Int})
    values = copy(operator.data)
    length(degeneracies) == size(values, ndims(values)) ||
        throw(ArgumentError("degeneracy count does not match operator R support"))
    for r_index in eachindex(degeneracies)
        selectdim(values, ndims(values), r_index) .*= degeneracies[r_index]
    end
    return values
end

# Construct a TB model from synchronized Hamiltonian and position projections.
function _symmetrized_tight_binding_model(
    model::TightBindingModel,
    hamiltonian_result::RealSpaceSymmetrizationResult,
    position_result::RealSpaceSymmetrizationResult,
)
    r_vectors = _common_result_r_vectors((hamiltonian_result, position_result))
    degeneracies = _output_degeneracies(model, r_vectors)
    hamiltonian = _serialized_operator_values(hamiltonian_result.operator, degeneracies)
    position = _serialized_operator_values(position_result.operator, degeneracies)
    return TightBindingModel(
        model.lattice,
        model.num_orbitals,
        size(r_vectors, 2),
        degeneracies,
        r_vectors,
        hamiltonian,
        position,
    )
end

# Remove the affine home-cell center from a normalized position operator.
function _position_operator_without_wannier_centers(
    position::RealSpaceOperator,
    raw_centers_cartesian::Matrix{Float64},
)
    values = copy(position.data)
    home_indices = findall(
        index -> all(iszero, @view(position.r_vectors[:, index])),
        axes(position.r_vectors, 2),
    )
    length(home_indices) == 1 ||
        throw(ArgumentError("position operator must contain exactly one home-cell block"))
    home_index = only(home_indices)
    for wannier_index in axes(raw_centers_cartesian, 1), direction in 1:3
        values[wannier_index, wannier_index, direction, home_index] -=
            raw_centers_cartesian[wannier_index, direction]
    end
    return RealSpaceOperator(position.spec, position.r_vectors, values)
end

# Restore the final affine center to a projected centerless position operator.
function _position_operator_with_wannier_centers(
    position::RealSpaceOperator,
    final_centers_cartesian::Matrix{Float64},
)
    values = copy(position.data)
    home_indices = findall(
        index -> all(iszero, @view(position.r_vectors[:, index])),
        axes(position.r_vectors, 2),
    )
    length(home_indices) == 1 ||
        throw(ArgumentError("projected position operator lost its home-cell block"))
    home_index = only(home_indices)
    for wannier_index in axes(final_centers_cartesian, 1), direction in 1:3
        values[wannier_index, wannier_index, direction, home_index] +=
            final_centers_cartesian[wannier_index, direction]
    end
    return RealSpaceOperator(position.spec, position.r_vectors, values)
end

# Construct a serialized TB model from normalized Hamiltonian and position operators.
function _tight_binding_model_from_normalized_operators(
    lattice::Matrix{Float64},
    operators::Dict{RealSpaceOperatorKind, RealSpaceOperator},
    degeneracies::Vector{Int},
)
    hamiltonian = operators[REAL_SPACE_HAMILTONIAN]
    position = operators[REAL_SPACE_POSITION]
    hamiltonian.r_vectors == position.r_vectors ||
        throw(ArgumentError("Hamiltonian and position R support differs"))
    return TightBindingModel(
        lattice,
        size(hamiltonian.data, 1),
        size(hamiltonian.r_vectors, 2),
        degeneracies,
        hamiltonian.r_vectors,
        _serialized_operator_values(hamiltonian, degeneracies),
        _serialized_operator_values(position, degeneracies),
    )
end

# Return exact maximum difference on a shared real-space sequence.
function _operator_maximum_difference(left::RealSpaceOperator, right::RealSpaceOperator)
    left.r_vectors == right.r_vectors || return Inf
    size(left.data) == size(right.data) || return Inf
    return maximum(abs, left.data .- right.data; init = 0.0)
end

# Run optional covariance and idempotence gates for one projected operator.
function _validate_symmetrized_operator(
    result::RealSpaceSymmetrizationResult,
    projection::RealSpaceProjectionContext,
    config::SymmetrizationConfig,
)
    covariance = maximum_real_space_covariance_error(result.operator, projection)
    storage_name = operator_storage_name(result.operator.spec.kind)
    covariance <= config.covariance_tolerance || throw(
        ArgumentError(
            "$(storage_name) covariance error $(covariance) exceeds $(config.covariance_tolerance)",
        ),
    )
    idempotence = 0.0
    if config.check_idempotence
        repeated = symmetrize_real_space_operator(result.operator, projection)
        idempotence = _operator_maximum_difference(result.operator, repeated.operator)
        idempotence <= config.idempotence_tolerance || throw(
            ArgumentError(
                "$(storage_name) idempotence error $(idempotence) exceeds $(config.idempotence_tolerance)",
            ),
        )
    end
    return (covariance_error = covariance, idempotence_error = idempotence)
end

# Expand one projected operator onto an established common real-space sequence.
function _align_operator_to_r_vectors(operator::RealSpaceOperator, target_r_vectors::Matrix{Int})
    operator_index = Dict(
        r_vector_key(operator.r_vectors, index) => index for index in axes(operator.r_vectors, 2)
    )
    target_index =
        Dict(r_vector_key(target_r_vectors, index) => index for index in axes(target_r_vectors, 2))
    for (r_vector, source_index) in operator_index
        haskey(target_index, r_vector) && continue
        source = selectdim(operator.data, ndims(operator.data), source_index)
        maximum(abs, source; init = 0.0) == 0.0 || throw(
            ArgumentError(
                "operator $(operator_storage_name(operator.spec.kind)) has nonzero R support outside TB output",
            ),
        )
    end
    dimensions = collect(size(operator.data))
    dimensions[end] = size(target_r_vectors, 2)
    output = zeros(ComplexF64, Tuple(dimensions))
    for (r_vector, destination_index) in target_index
        source_index = get(operator_index, r_vector, 0)
        source_index == 0 && continue
        selectdim(output, ndims(output), destination_index) .=
            selectdim(operator.data, ndims(operator.data), source_index)
    end
    return RealSpaceOperator(operator.spec, target_r_vectors, output)
end

# Symmetrize Hamiltonian and position without performing file writes.
function _symmetrize_tight_binding_operators(context, config::SymmetrizationConfig)
    model = context.model
    hamiltonian_input =
        _normalized_real_space_operator(HAMILTONIAN_SYMMETRY_SPEC, model, model.hamiltonian_r)
    position_input =
        _normalized_real_space_operator(POSITION_SYMMETRY_SPEC, model, model.position_r)
    raw_centers_cartesian = _position_wannier_centers_cartesian(position_input)
    center_geometry = _resolve_wannier_center_geometry(
        raw_centers_cartesian,
        model.lattice,
        context.basis,
        context.plan,
        config.wannier_center_policy,
        config.wannier_center_tolerance,
    )
    centerless_position =
        _position_operator_without_wannier_centers(position_input, raw_centers_cartesian)
    hamiltonian_result = symmetrize_real_space_operator(
        hamiltonian_input,
        context.projection;
        cutoff = config.cutoff,
    )
    centerless_position_result = symmetrize_real_space_operator(
        centerless_position,
        context.projection;
        cutoff = config.cutoff,
    )
    position_operator = _position_operator_with_wannier_centers(
        centerless_position_result.operator,
        center_geometry.final_cartesian,
    )
    position_result = RealSpaceSymmetrizationResult(
        position_operator,
        centerless_position_result.original_num_r_vectors,
        centerless_position_result.generated_r_vectors,
        centerless_position_result.operation_indices,
    )
    output_model = _symmetrized_tight_binding_model(model, hamiltonian_result, position_result)
    operators = Dict{RealSpaceOperatorKind, RealSpaceOperator}(
        REAL_SPACE_HAMILTONIAN => hamiltonian_result.operator,
        REAL_SPACE_POSITION => position_result.operator,
    )
    validation = Dict{RealSpaceOperatorKind, OperatorValidationSummary}(
        REAL_SPACE_HAMILTONIAN =>
            _validate_symmetrized_operator(hamiltonian_result, context.projection, config),
        REAL_SPACE_POSITION => _validate_symmetrized_operator(
            centerless_position_result,
            context.projection,
            config,
        ),
    )
    return (
        model = output_model,
        operators = operators,
        validation = validation,
        center_geometry = center_geometry,
        generated_num_r_vectors = size(hamiltonian_result.generated_r_vectors, 2),
    )
end

# Read shared derivative/spin construction inputs once.
function _read_auxiliary_operator_inputs(paths)
    return (
        chk = paths.chk === nothing ? nothing : read_wannier_chk(paths.chk),
        eig = paths.eig === nothing ? nothing : read_wannier_eig(paths.eig),
        mmn = paths.mmn === nothing || isempty(paths.families.derivative) ? nothing :
              read_wannier_mmn(paths.mmn),
        mmn_path = paths.mmn,
        spn = paths.spn === nothing ? nothing : read_wannier_spn(paths.spn),
    )
end

# Construct, project, validate, and align selected Wannier derivative operators.
function _symmetrize_wannier_derivative_operators(
    context,
    tb_result,
    auxiliary,
    transform_plan,
    requested::Vector{RealSpaceOperatorKind},
    config::SymmetrizationConfig,
)
    isempty(requested) && return (
        operators = Dict{RealSpaceOperatorKind, RealSpaceOperator}(),
        validation = Dict{RealSpaceOperatorKind, OperatorValidationSummary}(),
    )
    derivative_set = construct_wannier_derivative_operators(
        context.model,
        auxiliary.chk,
        auxiliary.eig,
        auxiliary.mmn;
        requested = requested,
        support_tolerance = config.support_tolerance,
        wigner_seitz_tolerance = config.wigner_seitz_tolerance,
        search_size = config.wigner_seitz_search_size,
        transform_plan = transform_plan,
        wannier_centers_cartesian = tb_result.center_geometry.final_cartesian,
    )
    projected = Dict{RealSpaceOperatorKind, RealSpaceOperator}()
    validation = Dict{RealSpaceOperatorKind, OperatorValidationSummary}()
    for kind in requested
        input = RealSpaceOperator(
            WANNIER_DERIVATIVE_SYMMETRY_SPECS[kind],
            derivative_set.r_vectors,
            derivative_set.matrices[kind],
        )
        result = symmetrize_real_space_operator(input, context.projection; cutoff = config.cutoff)
        validation[kind] = _validate_symmetrized_operator(result, context.projection, config)
        projected[kind] = _align_operator_to_r_vectors(result.operator, tb_result.model.r_vectors)
    end
    return (operators = projected, validation = validation)
end

# Project one center-aware unit-degeneracy spin-family array.
function _symmetrize_spin_array(
    spec::RealSpaceOperatorSymmetrySpec,
    r_vectors::Matrix{Int},
    values,
    projection::RealSpaceProjectionContext,
    config::SymmetrizationConfig,
)
    input = RealSpaceOperator(spec, r_vectors, values)
    result = symmetrize_real_space_operator(input, projection; cutoff = config.cutoff)
    validation = _validate_symmetrized_operator(result, projection, config)
    return result, validation
end

# Construct and project the explicitly selected spin-family operators.
function _symmetrize_spin_family(
    context,
    tb_result,
    auxiliary,
    transform_plan,
    requested::Vector{RealSpaceOperatorKind},
    config::SymmetrizationConfig,
)
    isempty(requested) && return (
        operators = Dict{RealSpaceOperatorKind, RealSpaceOperator}(),
        validation = Dict{RealSpaceOperatorKind, OperatorValidationSummary}(),
        serialized = Dict{RealSpaceOperatorKind, Array{ComplexF64}}(),
        diagnostics = nothing,
        roundtrip_residuals = Dict{String, Float64}(),
    )
    auxiliary.spn === nothing && error("validated spin input is absent")
    auxiliary.chk === nothing && error("validated checkpoint input is absent")
    transform_plan isa WannierPairWignerSeitzTransformPlan ||
        error("validated pair-dependent transform plan is absent")
    spin_transform = PairWignerSeitzSpinQToRTransform(
        auxiliary.chk,
        transform_plan,
        config.support_tolerance,
        config.roundtrip_tolerance,
        config.check_roundtrip,
    )
    arrays, spin_velocity_diagnostics, roundtrip_residuals = if requested == [REAL_SPACE_SPIN]
        spin_q = spn_to_wannier_gauge_q(auxiliary.spn, auxiliary.chk; hermitize = true)
        spin_result = transform_pair_wigner_seitz_spin_q_to_r(spin_transform, spin_q, "spin")
        (
            Dict{RealSpaceOperatorKind, Array{ComplexF64}}(
                REAL_SPACE_SPIN => spin_result.real_space_values,
            ),
            nothing,
            Dict(
                operator_storage_name(REAL_SPACE_SPIN) =>
                    spin_result.diagnostics.max_roundtrip_error,
            ),
        )
    else
        auxiliary.eig === nothing && error("validated eigenvalue input is absent")
        auxiliary.mmn_path === nothing && error("validated overlap path is absent")
        real_space = if auxiliary.mmn === nothing
            compute_spin_velocity_real_space_streaming_with_transform(
                context.model,
                auxiliary.spn,
                auxiliary.chk,
                auxiliary.eig,
                auxiliary.mmn_path,
                spin_transform,
            )
        else
            compute_spin_velocity_real_space_with_transform(
                context.model,
                auxiliary.spn,
                auxiliary.chk,
                auxiliary.eig,
                auxiliary.mmn,
                spin_transform,
            )
        end
        (
            Dict{RealSpaceOperatorKind, Array{ComplexF64}}(
                REAL_SPACE_SPIN => real_space.spin.spin_r,
                REAL_SPACE_SPIN_TIMES_HAMILTONIAN => real_space.spin_hamiltonian_r,
                REAL_SPACE_SPIN_TIMES_POSITION => real_space.spin_position_r,
                REAL_SPACE_SPIN_TIMES_HAMILTONIAN_POSITION =>
                    real_space.spin_hamiltonian_position_r,
            ),
            real_space.diagnostics,
            Dict(
                operator_storage_name(REAL_SPACE_SPIN) =>
                    real_space.diagnostics.max_spin_roundtrip_error,
                operator_storage_name(REAL_SPACE_SPIN_TIMES_HAMILTONIAN) =>
                    real_space.diagnostics.max_spin_hamiltonian_roundtrip_error,
                operator_storage_name(REAL_SPACE_SPIN_TIMES_POSITION) =>
                    real_space.diagnostics.max_spin_position_roundtrip_error,
                operator_storage_name(REAL_SPACE_SPIN_TIMES_HAMILTONIAN_POSITION) =>
                    real_space.diagnostics.max_spin_hamiltonian_position_roundtrip_error,
            ),
        )
    end
    projected_results = Dict{RealSpaceOperatorKind, RealSpaceSymmetrizationResult}()
    validation = Dict{RealSpaceOperatorKind, OperatorValidationSummary}()
    for kind in requested
        result, diagnostics = _symmetrize_spin_array(
            SPIN_FAMILY_SYMMETRY_SPECS[kind],
            transform_plan.target_r_vectors,
            arrays[kind],
            context.projection,
            config,
        )
        projected_results[kind] = result
        validation[kind] = diagnostics
    end
    r_vectors = _common_result_r_vectors(collect(values(projected_results)))
    r_vectors == tb_result.model.r_vectors ||
        throw(ArgumentError("spin and TB symmetrization produced inconsistent R support"))
    degeneracies = tb_result.model.r_degeneracies
    operators = Dict{RealSpaceOperatorKind, RealSpaceOperator}()
    serialized = Dict{RealSpaceOperatorKind, Array{ComplexF64}}()
    for (kind, result) in projected_results
        operators[kind] = result.operator
        serialized[kind] = _serialized_operator_values(result.operator, degeneracies)
    end
    return (
        operators = operators,
        validation = validation,
        serialized = serialized,
        diagnostics = spin_velocity_diagnostics,
        roundtrip_residuals = roundtrip_residuals,
    )
end
