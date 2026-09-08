"""Stable outcome of the deterministic integer-search kernel."""
struct ProjectionRepresentationIntegerSearchOutcome{T}
    complete::Bool
    uncertain::Bool
    visited_nodes::Int
    total_solution_count::Int
    retained::Vector{T}
    diagnostics::Vector{String}
end

# Write one length-delimited string into a canonical SHA payload.
function _projection_search_write_string(io::Base.IO, value)
    bytes = codeunits(String(value))
    write(io, Int64(length(bytes)))
    write(io, bytes)
    return nothing
end

# Write one dense isbits array with explicit dimensions into a canonical SHA payload.
function _projection_search_write_array(io::Base.IO, values::AbstractArray{T}) where {T}
    write(io, Int64(ndims(values)))
    write(io, Int64.(collect(size(values))))
    write(io, reinterpret(UInt8, vec(collect(values))))
    return nothing
end

# Hash every material projection declaration while excluding filesystem paths.
function _projection_candidate_sha256(candidate::ProjectionCandidateSpec)
    io = IOBuffer()
    _projection_search_write_string(io, "WannierNLQG.projection_candidate/2.0")
    _projection_search_write_string(io, candidate.id)
    write(
        io,
        Int64(candidate.min_multiplicity),
        Int64(candidate.max_multiplicity),
        Int64(something(candidate.fixed_multiplicity, -1)),
    )
    write(io, Int64(length(candidate.specs)))
    for spec in candidate.specs
        _projection_search_write_string(io, spec.selector)
        write(io, Int64(length(spec.orbital_sets)))
        foreach(label -> _projection_search_write_string(io, label), spec.orbital_sets)
        _projection_search_write_array(io, something(spec.positions_fractional))
        _projection_search_write_array(io, spec.local_bases)
    end
    return bytes2hex(SHA.sha256(take!(io)))
end

# Hash the path-independent, ordered cold-path configuration contract.
function _projection_search_config_sha256(
    config::ProjectionRepresentationSearchConfig,
    representation_sha256::AbstractString,
)
    io = IOBuffer()
    _projection_search_write_string(io, "WannierNLQG.projection_representation_search_config/2.1")
    _projection_search_write_string(io, representation_sha256)
    _projection_search_write_string(io, config.target_subspace_contract.contract_sha256)
    write(
        io,
        UInt8(config.validate_retained_solutions),
        Int64(config.max_results),
        Int64(config.max_search_nodes),
    )
    for value in (
        config.thresholds.position,
        config.thresholds.representation,
        config.thresholds.group_law,
        config.thresholds.integer,
    )
        write(io, Float64(value))
    end
    _projection_search_write_string(io, config.radial_transform.method)
    write(io, Int64(config.radial_transform.gauss_laguerre_order))
    write(io, Int64(length(config.candidates)))
    for candidate in config.candidates
        _projection_search_write_string(io, _projection_candidate_sha256(candidate))
    end
    return bytes2hex(SHA.sha256(take!(io)))
end

# Validate the flattened integer problem before entering branch-and-bound.
function _validate_projection_representation_problem(
    problem::ProjectionRepresentationProblem,
    target_dimension::Int,
)
    target_dimension > 0 || throw(ArgumentError("target_dimension must be positive"))
    candidate_count = length(problem.candidate_ids)
    candidate_count > 0 || throw(ArgumentError("representation problem has no candidates"))
    length(unique(problem.candidate_ids)) == candidate_count ||
        throw(ArgumentError("representation problem candidate ids must be unique"))
    all(
        length(values) == candidate_count for values in
        (problem.candidate_dimensions, problem.min_multiplicities, problem.max_multiplicities)
    ) || throw(DimensionMismatch("representation problem candidate vectors disagree"))
    row_count = length(problem.lower_bounds)
    length(problem.upper_bounds) == row_count ||
        throw(DimensionMismatch("representation problem signature bounds disagree"))
    size(problem.candidate_signatures) == (row_count, candidate_count) ||
        throw(DimensionMismatch("representation problem candidate signature matrix disagrees"))
    all(>(0), problem.candidate_dimensions) ||
        throw(ArgumentError("candidate dimensions must be positive"))
    all(>=(0), problem.candidate_signatures) ||
        throw(ArgumentError("candidate signature multiplicities must be nonnegative"))
    all(>=(0), problem.lower_bounds) ||
        throw(ArgumentError("frozen signature bounds must be nonnegative"))
    all(problem.upper_bounds .>= problem.lower_bounds) ||
        throw(ArgumentError("outer signature bounds must contain frozen bounds"))
    all(problem.min_multiplicities .>= 0) ||
        throw(ArgumentError("minimum candidate multiplicities must be nonnegative"))
    all(problem.max_multiplicities .>= problem.min_multiplicities) ||
        throw(ArgumentError("candidate multiplicity bounds are inconsistent"))
    signature_dimension = sum(length(signature.labels) for signature in problem.signatures)
    signature_dimension == row_count || throw(
        DimensionMismatch(
            "flattened signature row count $(row_count) disagrees with signature metadata $(signature_dimension)",
        ),
    )
    return nothing
end

"""
    _search_projection_integer_combinations(problem, target_dimension; ...)

Exhaust the bounded integer tree in input-candidate and ascending-coefficient
order. One visited node is one entered recursive partial-assignment state,
including the root and exact leaves. The result limit retains only the first
coefficient-lexicographic values and never terminates enumeration.
"""
function _search_projection_integer_combinations(
    problem::ProjectionRepresentationProblem,
    target_dimension::Integer;
    max_results::Integer = 100,
    max_search_nodes::Integer = 1_000_000,
)
    dimension = Int(target_dimension)
    result_limit = Int(max_results)
    node_limit = Int(max_search_nodes)
    result_limit > 0 || throw(ArgumentError("max_results must be positive"))
    node_limit > 0 || throw(ArgumentError("max_search_nodes must be positive"))
    _validate_projection_representation_problem(problem, dimension)

    dimensions = problem.candidate_dimensions
    signatures = problem.candidate_signatures
    minima = problem.min_multiplicities
    declared_maxima = problem.max_multiplicities
    candidate_count = length(problem.candidate_ids)
    row_count = length(problem.lower_bounds)
    maxima = similar(declared_maxima)
    for index in 1:candidate_count
        maxima[index] = min(declared_maxima[index], fld(dimension, dimensions[index]))
    end

    if any(maxima .< minima)
        return ProjectionRepresentationIntegerSearchOutcome(
            true,
            problem.uncertain,
            1,
            0,
            Vector{Vector{Int}}(),
            [problem.diagnostics...; "candidate lower bounds exceed the target-dimension cap"],
        )
    end

    min_remaining_dimension = zeros(Int, candidate_count + 1)
    max_remaining_dimension = zeros(Int, candidate_count + 1)
    min_remaining_signature = zeros(Int, row_count, candidate_count + 1)
    max_remaining_signature = zeros(Int, row_count, candidate_count + 1)
    for index in candidate_count:-1:1
        min_remaining_dimension[index] =
            min_remaining_dimension[index + 1] + minima[index] * dimensions[index]
        max_remaining_dimension[index] =
            max_remaining_dimension[index + 1] + maxima[index] * dimensions[index]
        min_remaining_signature[:, index] .=
            min_remaining_signature[:, index + 1] .+ minima[index] .* signatures[:, index]
        max_remaining_signature[:, index] .=
            max_remaining_signature[:, index + 1] .+ maxima[index] .* signatures[:, index]
    end

    coefficients = zeros(Int, candidate_count)
    current_signature = zeros(Int, row_count)
    retained = Vector{Vector{Int}}()
    visited_nodes = Ref(0)
    total_solutions = Ref(0)
    limited = Ref(false)

    function visit(index::Int, current_dimension::Int)
        if visited_nodes[] >= node_limit
            limited[] = true
            return nothing
        end
        visited_nodes[] += 1

        current_dimension + min_remaining_dimension[index] <=
        dimension <=
        current_dimension + max_remaining_dimension[index] || return nothing
        if row_count > 0
            all(current_signature .+ min_remaining_signature[:, index] .<= problem.upper_bounds) ||
                return nothing
            all(current_signature .+ max_remaining_signature[:, index] .>= problem.lower_bounds) ||
                return nothing
        end

        if index > candidate_count
            current_dimension == dimension || return nothing
            all(problem.lower_bounds .<= current_signature) || return nothing
            all(current_signature .<= problem.upper_bounds) || return nothing
            total_solutions[] += 1
            length(retained) < result_limit && push!(retained, copy(coefficients))
            return nothing
        end

        for coefficient in minima[index]:maxima[index]
            coefficients[index] = coefficient
            coefficient == 0 || (current_signature .+= coefficient .* @view(signatures[:, index]))
            visit(index + 1, current_dimension + coefficient * dimensions[index])
            coefficient == 0 || (current_signature .-= coefficient .* @view(signatures[:, index]))
            limited[] && return nothing
        end
        coefficients[index] = 0
        return nothing
    end

    visit(1, 0)
    return ProjectionRepresentationIntegerSearchOutcome(
        !limited[] && problem.complete,
        problem.uncertain || !problem.complete,
        visited_nodes[],
        total_solutions[],
        retained,
        copy(problem.diagnostics),
    )
end

# Expand selected candidate blocks in canonical candidate-ID/copy/spec order.
function _selected_projection_specs(candidates, coefficients)
    length(candidates) == length(coefficients) ||
        throw(DimensionMismatch("candidate coefficient vector has incompatible length"))
    specs = ProjectionSpec[]
    for candidate_index in sortperm(getfield.(candidates, :id))
        candidate = candidates[candidate_index]
        for _ in 1:Int(coefficients[candidate_index]), spec in candidate.specs
            push!(specs, spec)
        end
    end
    return specs
end

# Build one candidate's closed target action without entering any solver stage.
function _projection_candidate_target_plan(candidate, representation, thresholds)
    basis = build_wannier_projection_basis(
        candidate.specs;
        spinor = representation.spinor,
        tolerance = thresholds.position,
    )
    plan = build_wannier_symmetry_plan(
        basis,
        representation.operations;
        tolerance = thresholds.position,
    )
    return basis, plan
end

# Return target action matrices in one algebra's local operation order.
function _projection_target_actions(plan, representation, algebra)
    return [
        target_representation(
            plan,
            representation,
            operation_index,
            algebra.kpoint_index,
            operation_index,
        ) for operation_index in algebra.operation_indices
    ]
end

# Return a zero frozen signature in the extended corepresentation axis.
function _projection_empty_extended_decomposition(corep_enumeration)
    coreps = corep_enumeration.corepresentations
    return ProjectionRepresentationActionDecomposition(
        getfield.(coreps, :label),
        getfield.(coreps, :dimension),
        getfield.(coreps, :wigner_type),
        zeros(Int, length(coreps)),
        0.0,
        0.0,
        corep_enumeration.complete,
        corep_enumeration.uncertain,
        copy(corep_enumeration.diagnostics),
    )
end

# Require every decomposition at one k point to share one canonical axis.
function _projection_decomposition_axis_matches(reference, candidate)
    return reference.labels == candidate.labels &&
           reference.dimensions == candidate.dimensions &&
           reference.wigner_types == candidate.wigner_types
end

# Decompose one k point through the native-compatibility character contract.
function _projection_native_kpoint_decompositions(
    representation,
    algebra,
    scope,
    kpoint,
    candidate_plans,
    irreps,
)
    outer = _projection_compatibility_decompose_band_subspace(
        representation,
        algebra,
        @view(scope.outer_mask[:, kpoint]),
        irreps,
    )
    frozen = if any(@view scope.frozen_mask[:, kpoint])
        _projection_compatibility_decompose_band_subspace(
            representation,
            algebra,
            @view(scope.frozen_mask[:, kpoint]),
            irreps,
        )
    else
        _projection_compatibility_empty_decomposition(irreps)
    end
    candidates = ProjectionRepresentationActionDecomposition[]
    for plan in candidate_plans
        actions = _projection_target_actions(plan, representation, algebra)
        push!(
            candidates,
            _projection_compatibility_decompose_actions(
                algebra,
                actions,
                irreps;
                source = :candidate,
            ),
        )
    end
    return frozen, outer, candidates
end

# Decompose one k point through the magnetic/spinor corepresentation extension.
function _projection_extended_kpoint_decompositions(
    representation,
    algebra,
    scope,
    kpoint,
    candidate_plans,
    irreps,
    thresholds,
)
    coreps = _enumerate_magnetic_corepresentations(
        algebra,
        irreps;
        tolerance = thresholds.representation,
    )
    outer = _decompose_band_subspace(
        representation,
        algebra,
        @view(scope.outer_mask[:, kpoint]),
        irreps,
        coreps;
        tolerance = thresholds.representation,
    )
    frozen = if any(@view scope.frozen_mask[:, kpoint])
        _decompose_band_subspace(
            representation,
            algebra,
            @view(scope.frozen_mask[:, kpoint]),
            irreps,
            coreps;
            tolerance = thresholds.representation,
        )
    else
        _projection_empty_extended_decomposition(coreps)
    end
    candidates = ProjectionRepresentationActionDecomposition[]
    for plan in candidate_plans
        actions = _projection_target_actions(plan, representation, algebra)
        push!(
            candidates,
            _decompose_representation_actions(
                algebra,
                actions,
                irreps,
                coreps;
                tolerance = thresholds.representation,
            ),
        )
    end
    return frozen, outer, candidates
end

"""
    _build_projection_representation_problem(representation, contract, candidates; thresholds)

Construct the flattened frozen/candidate/outer integer problem from verified
little-group decompositions. Candidate columns always come from their
k-dependent target actions. Spinless-unitary inputs use the pinned character
reducer; spinor or antiunitary inputs use the WannierNLQG extension.
"""
function _build_projection_representation_problem(
    representation::BandRepresentation,
    contract::TargetSubspaceQualificationContract,
    candidates::AbstractVector{ProjectionCandidateSpec};
    thresholds::ProjectionRepresentationSearchThresholds = ProjectionRepresentationSearchThresholds(),
)
    scope = contract.qualification_scope
    size(scope.outer_mask) == size(representation.energies_ev) ||
        throw(DimensionMismatch("target-subspace masks disagree with representation energies"))

    candidate_bases = WannierProjectionBasis[]
    candidate_plans = WannierSymmetryPlan[]
    for candidate in candidates
        basis, plan = _projection_candidate_target_plan(candidate, representation, thresholds)
        push!(candidate_bases, basis)
        push!(candidate_plans, plan)
    end

    compatibility_info = _projection_representation_compatibility_info(representation)
    spinless_unitary_scope = compatibility_info.scope == :spinless_unitary
    algebra_tolerance =
        spinless_unitary_scope ? compatibility_info.little_group_tolerance : thresholds.group_law
    signatures = ProjectionRepresentationSignature[]
    lower_bounds = Int[]
    upper_bounds = Int[]
    candidate_columns = [Int[] for _ in candidates]
    diagnostics = String[]
    decomposition_complete = true
    uncertain = false

    for kpoint in representation.irreducible_indices
        algebra = _build_little_group_algebra(representation, kpoint; tolerance = algebra_tolerance)
        irreps = _enumerate_projective_irreps(
            algebra;
            tolerance = spinless_unitary_scope ? algebra_tolerance : thresholds.representation,
        )
        frozen, outer, candidate_decompositions = if spinless_unitary_scope
            _projection_native_kpoint_decompositions(
                representation,
                algebra,
                scope,
                kpoint,
                candidate_plans,
                irreps,
            )
        else
            _projection_extended_kpoint_decompositions(
                representation,
                algebra,
                scope,
                kpoint,
                candidate_plans,
                irreps,
                thresholds,
            )
        end

        entries = [frozen, outer, candidate_decompositions...]
        axis_matches = all(entry -> _projection_decomposition_axis_matches(outer, entry), entries)
        entry_complete = all(entry -> entry.complete && !entry.uncertain, entries)
        axis_matches || push!(diagnostics, "k=$(kpoint) decomposition axes disagree")
        for entry in entries
            append!(diagnostics, ["k=$(kpoint): $(message)" for message in entry.diagnostics])
        end
        decomposition_complete &= axis_matches && entry_complete
        uncertain |= any(getfield.(entries, :uncertain)) || !axis_matches

        push!(
            signatures,
            ProjectionRepresentationSignature(
                kpoint,
                copy(outer.labels),
                copy(outer.dimensions),
                copy(outer.wigner_types),
                copy(frozen.multiplicities),
                copy(outer.multiplicities),
            ),
        )
        append!(lower_bounds, frozen.multiplicities)
        append!(upper_bounds, outer.multiplicities)
        for (column, decomposition) in zip(candidate_columns, candidate_decompositions)
            append!(column, decomposition.multiplicities)
        end
    end

    row_count = length(lower_bounds)
    candidate_signatures = zeros(Int, row_count, length(candidates))
    for (candidate_index, column) in enumerate(candidate_columns)
        length(column) == row_count || throw(
            DimensionMismatch(
                "candidate $(candidates[candidate_index].id) signature row count disagrees",
            ),
        )
        candidate_signatures[:, candidate_index] .= column
    end

    minima = Int[]
    maxima = Int[]
    for candidate in candidates
        if candidate.fixed_multiplicity === nothing
            push!(minima, candidate.min_multiplicity)
            push!(maxima, candidate.max_multiplicity)
        else
            fixed = something(candidate.fixed_multiplicity)
            push!(minima, fixed)
            push!(maxima, fixed)
        end
    end
    return ProjectionRepresentationProblem(
        signatures,
        getfield.(candidates, :id),
        getfield.(candidate_bases, :num_wannier),
        candidate_signatures,
        lower_bounds,
        upper_bounds,
        minima,
        maxima,
        decomposition_complete && !uncertain,
        uncertain || !decomposition_complete,
        unique(diagnostics),
    )
end

# Restrict sewing actions to one verified little-group band mask.
function _projection_band_actions(representation, algebra, mask)
    indices = findall(mask)
    return [
        Matrix(
            @view representation.sewing_matrices[
                indices,
                indices,
                operation_index,
                algebra.kpoint_index,
            ]
        ) for operation_index in algebra.operation_indices
    ]
end

"""
    _validate_projection_representation_embedding(representation, contract,
                                                  candidates, coefficients; thresholds)

Validate frozen-to-target and target-to-outer full-rank semilinear maps at
every IBZ representative. Search completeness and solution counting never
depend on this independent retained-solution qualification.
"""
function _validate_projection_representation_embedding(
    representation::BandRepresentation,
    contract::TargetSubspaceQualificationContract,
    candidates::AbstractVector{ProjectionCandidateSpec},
    coefficients::AbstractVector{<:Integer};
    thresholds::ProjectionRepresentationSearchThresholds = ProjectionRepresentationSearchThresholds(),
)
    specs = _selected_projection_specs(candidates, coefficients)
    isempty(specs) && return ProjectionRepresentationEmbeddingCertificate(
        floatmax(Float64),
        floatmax(Float64),
        0,
        0,
        0,
        false,
        false,
        ["selected projection combination is empty"],
    )
    basis = build_wannier_projection_basis(
        specs;
        spinor = representation.spinor,
        num_wannier = contract.num_wannier,
        tolerance = thresholds.position,
    )
    plan = build_wannier_symmetry_plan(
        basis,
        representation.operations;
        tolerance = thresholds.position,
    )
    scope = contract.qualification_scope
    maximum_frozen_residual = 0.0
    maximum_outer_residual = 0.0
    maximum_frozen_rank = 0
    minimum_outer_rank = typemax(Int)
    complete = true
    uncertain = false
    diagnostics = String[]
    for kpoint in representation.irreducible_indices
        algebra =
            _build_little_group_algebra(representation, kpoint; tolerance = thresholds.group_law)
        if !algebra.complete || algebra.uncertain
            complete = false
            uncertain = true
            append!(diagnostics, ["k=$(kpoint): $(message)" for message in algebra.diagnostics])
            continue
        end
        target_actions = _projection_target_actions(plan, representation, algebra)
        antiunitary =
            [representation.operations[index].antiunitary for index in algebra.operation_indices]
        frozen_indices = findall(@view scope.frozen_mask[:, kpoint])
        outer_indices = findall(@view scope.outer_mask[:, kpoint])
        outer_actions =
            _projection_band_actions(representation, algebra, @view(scope.outer_mask[:, kpoint]))
        frozen_result = if isempty(frozen_indices)
            ProjectionRepresentationEmbeddingCertificate(
                0.0,
                0.0,
                0,
                0,
                basis.num_wannier,
                true,
                false,
                String[],
            )
        else
            frozen_actions = _projection_band_actions(
                representation,
                algebra,
                @view(scope.frozen_mask[:, kpoint]),
            )
            _certify_representation_embedding(
                target_actions,
                frozen_actions,
                antiunitary;
                tolerance = thresholds.representation,
            )
        end
        outer_result = _certify_representation_embedding(
            outer_actions,
            target_actions,
            antiunitary;
            tolerance = thresholds.representation,
        )
        maximum_frozen_residual = max(maximum_frozen_residual, frozen_result.frozen_residual)
        maximum_outer_residual = max(maximum_outer_residual, outer_result.frozen_residual)
        maximum_frozen_rank = max(maximum_frozen_rank, length(frozen_indices))
        minimum_outer_rank = min(minimum_outer_rank, length(outer_indices))
        complete &= frozen_result.complete && outer_result.complete
        uncertain |= frozen_result.uncertain || outer_result.uncertain
        append!(
            diagnostics,
            ["k=$(kpoint) frozen->target: $(message)" for message in frozen_result.diagnostics],
        )
        append!(
            diagnostics,
            ["k=$(kpoint) target->outer: $(message)" for message in outer_result.diagnostics],
        )
    end
    minimum_outer_rank == typemax(Int) && (minimum_outer_rank = 0)
    return ProjectionRepresentationEmbeddingCertificate(
        maximum_frozen_residual,
        maximum_outer_residual,
        maximum_frozen_rank,
        basis.num_wannier,
        minimum_outer_rank,
        complete && !uncertain,
        uncertain,
        unique(diagnostics),
    )
end

# Normalize unavailable numerical residuals into a persistent finite sentinel.
_projection_finite_residual(value) = isfinite(value) ? Float64(value) : floatmax(Float64)

# Bind one solution's independent validation layer into a canonical digest.
function _projection_solution_validation_sha256(
    candidate_ids,
    coefficients,
    validation_status,
    residuals,
)
    io = IOBuffer()
    _projection_search_write_string(io, "WannierNLQG.projection_solution_validation/2.0")
    write(io, Int64(length(candidate_ids)))
    for (candidate_id, coefficient) in zip(candidate_ids, coefficients)
        _projection_search_write_string(io, candidate_id)
        write(io, Int64(coefficient))
    end
    _projection_search_write_string(io, string(validation_status))
    write(io, Int64(length(residuals)))
    for key in sort!(collect(keys(residuals)))
        _projection_search_write_string(io, key)
        write(io, Float64(residuals[key]))
    end
    return bytes2hex(SHA.sha256(take!(io)))
end

# Map one optional embedding result onto the four-state public qualification.
function _projection_validation_state(validate::Bool, embedding)
    if !validate
        return PROJECTION_VALIDATION_NOT_RUN, Dict{String, Float64}()
    end
    residuals = Dict(
        "frozen_to_target" => _projection_finite_residual(embedding.frozen_residual),
        "target_to_outer" => _projection_finite_residual(embedding.outer_residual),
    )
    status = if embedding.uncertain
        PROJECTION_VALIDATION_NUMERICAL_UNCERTAIN
    elseif embedding.complete
        PROJECTION_VALIDATION_PASSED
    else
        PROJECTION_VALIDATION_FAILED
    end
    return status, residuals
end

# Build one public solution without changing integer-search membership or count.
function _projection_public_solution(problem, coefficients, validation_status, residuals)
    total_dimension = dot(problem.candidate_dimensions, coefficients)
    flattened_signature = problem.candidate_signatures * coefficients
    signature_multiplicities = Vector{Vector{Int}}()
    row = 1
    for signature in problem.signatures
        count = length(signature.labels)
        push!(signature_multiplicities, flattened_signature[row:(row + count - 1)])
        row += count
    end
    candidate_ids = copy(problem.candidate_ids)
    coefficient_values = Int.(coefficients)
    digest = _projection_solution_validation_sha256(
        candidate_ids,
        coefficient_values,
        validation_status,
        residuals,
    )
    return ProjectionRepresentationSolution(
        candidate_ids,
        coefficient_values,
        total_dimension,
        count(!iszero, coefficient_values),
        sum(coefficient_values),
        signature_multiplicities,
        validation_status,
        residuals,
        digest,
    )
end

# Resolve the in-memory representation and preserve its static logical identity.
function _projection_search_representation(config)
    representation = if config.band_representation !== nothing
        something(config.band_representation)
    else
        read_band_representation_hdf5(something(config.band_representation_hdf5))
    end
    return representation, representation_static_sha256(representation)
end

# Rebuild one result with its canonical logical payload digest populated.
function _projection_seal_search_result(result::ProjectionRepresentationSearchResult)
    digest = _projection_search_payload_sha256(result)
    return ProjectionRepresentationSearchResult(
        result.status,
        result.complete,
        result.representation_sha256,
        result.contract_sha256,
        result.compatibility_info,
        result.config_sha256,
        digest,
        result.spinor,
        result.num_wannier,
        result.outer_mask_sha256,
        result.frozen_mask_sha256,
        result.candidates,
        result.radial_transform,
        result.visited_nodes,
        result.total_solution_count,
        result.truncated,
        result.signatures,
        result.solutions,
        result.diagnostics,
    )
end

# Construct and seal one fail-closed result without duplicating status branches.
function _projection_search_result(
    config,
    representation,
    representation_sha256,
    compatibility_info,
    status,
    complete;
    visited_nodes = 0,
    total_solution_count = 0,
    signatures = ProjectionRepresentationSignature[],
    solutions = ProjectionRepresentationSolution[],
    diagnostics = String[],
)
    scope = config.target_subspace_contract.qualification_scope
    provisional = ProjectionRepresentationSearchResult(
        status,
        Bool(complete),
        String(representation_sha256),
        config.target_subspace_contract.contract_sha256,
        compatibility_info,
        _projection_search_config_sha256(config, representation_sha256),
        "",
        representation.spinor,
        config.target_subspace_contract.num_wannier,
        scope.outer_mask_sha256,
        scope.frozen_mask_sha256,
        copy(config.candidates),
        config.radial_transform,
        Int(visited_nodes),
        Int(total_solution_count),
        total_solution_count > length(solutions),
        copy(signatures),
        copy(solutions),
        unique(String.(diagnostics)),
    )
    return _projection_seal_search_result(provisional)
end

# Atomically publish any configured result artifacts after search termination.
function _publish_projection_search_outputs(config, result)
    config.output_hdf5 === nothing ||
        write_projection_representation_search_hdf5(something(config.output_hdf5), result)
    config.output_json === nothing ||
        _write_projection_representation_search_json(something(config.output_json), result)
    return result
end

"""
    search_projection_representations(config)

Construct the representation-signature problem, exhaust the deterministic
bounded integer search, then independently validate only retained solutions.
Validation never changes combination membership, total count, or search
completeness.
"""
function search_projection_representations(config::ProjectionRepresentationSearchConfig)
    representation, representation_sha256 = _projection_search_representation(config)
    compatibility_info = _projection_representation_compatibility_info(representation)
    scope = config.target_subspace_contract.qualification_scope
    if size(scope.outer_mask) != size(representation.energies_ev)
        result = _projection_search_result(
            config,
            representation,
            representation_sha256,
            compatibility_info,
            PROJECTION_SEARCH_INVALID_INPUT,
            false;
            diagnostics = ["target-subspace masks disagree with the band representation"],
        )
        return _publish_projection_search_outputs(config, result)
    end

    problem = try
        _build_projection_representation_problem(
            representation,
            config.target_subspace_contract,
            config.candidates;
            thresholds = config.thresholds,
        )
    catch error
        status =
            error isa Union{ArgumentError, DimensionMismatch, BoundsError} ?
            PROJECTION_SEARCH_INVALID_INPUT : PROJECTION_SEARCH_NUMERICAL_UNCERTAIN
        result = _projection_search_result(
            config,
            representation,
            representation_sha256,
            compatibility_info,
            status,
            false;
            diagnostics = ["representation decomposition failed: $(sprint(showerror, error))"],
        )
        return _publish_projection_search_outputs(config, result)
    end
    if problem.uncertain || !problem.complete
        result = _projection_search_result(
            config,
            representation,
            representation_sha256,
            compatibility_info,
            PROJECTION_SEARCH_NUMERICAL_UNCERTAIN,
            false;
            signatures = problem.signatures,
            diagnostics = problem.diagnostics,
        )
        return _publish_projection_search_outputs(config, result)
    end

    outcome = _search_projection_integer_combinations(
        problem,
        config.target_subspace_contract.num_wannier;
        max_results = config.max_results,
        max_search_nodes = config.max_search_nodes,
    )
    validation_diagnostics = String[]
    solutions = ProjectionRepresentationSolution[]
    for (solution_index, coefficients) in enumerate(outcome.retained)
        embedding = if config.validate_retained_solutions
            _validate_projection_representation_embedding(
                representation,
                config.target_subspace_contract,
                config.candidates,
                coefficients;
                thresholds = config.thresholds,
            )
        else
            nothing
        end
        validation_status, residuals =
            _projection_validation_state(config.validate_retained_solutions, embedding)
        if embedding !== nothing
            append!(
                validation_diagnostics,
                ["solution $(solution_index): $(message)" for message in embedding.diagnostics],
            )
        end
        push!(
            solutions,
            _projection_public_solution(problem, coefficients, validation_status, residuals),
        )
    end

    status = if !outcome.complete
        PROJECTION_SEARCH_LIMIT_REACHED
    elseif outcome.total_solution_count == 0
        PROJECTION_SEARCH_NO_SOLUTION
    else
        PROJECTION_SEARCH_COMPLETE
    end
    result = _projection_search_result(
        config,
        representation,
        representation_sha256,
        compatibility_info,
        status,
        outcome.complete;
        visited_nodes = outcome.visited_nodes,
        total_solution_count = outcome.total_solution_count,
        signatures = problem.signatures,
        solutions,
        diagnostics = [outcome.diagnostics...; validation_diagnostics...],
    )
    return _publish_projection_search_outputs(config, result)
end
