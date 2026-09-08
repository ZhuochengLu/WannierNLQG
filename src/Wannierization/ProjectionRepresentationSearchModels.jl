"""Terminal state of one fail-closed projection-representation search."""
@enum ProjectionRepresentationSearchStatus::UInt8 begin
    PROJECTION_SEARCH_COMPLETE
    PROJECTION_SEARCH_NO_SOLUTION
    PROJECTION_SEARCH_LIMIT_REACHED
    PROJECTION_SEARCH_INVALID_INPUT
    PROJECTION_SEARCH_NUMERICAL_UNCERTAIN
end

"""Independent qualification state of one retained representation-compatible solution."""
@enum ProjectionRepresentationValidationStatus::UInt8 begin
    PROJECTION_VALIDATION_NOT_RUN
    PROJECTION_VALIDATION_PASSED
    PROJECTION_VALIDATION_FAILED
    PROJECTION_VALIDATION_NUMERICAL_UNCERTAIN
end

"""Fixed numerical gates used by representation decomposition and site matching."""
struct ProjectionRepresentationSearchThresholds
    position::Float64
    representation::Float64
    group_law::Float64
    integer::Float64

    function ProjectionRepresentationSearchThresholds(;
        position::Real = 1.0e-8,
        representation::Real = 1.0e-8,
        group_law::Real = 1.0e-8,
        integer::Real = 1.0e-6,
    )
        values = Float64[position, representation, group_law, integer]
        all(value -> isfinite(value) && value > 0.0, values) ||
            throw(ArgumentError("projection-representation thresholds must be positive and finite"))
        return new(values...)
    end
end

"""
One explicitly positioned projection block offered to the representation search.

Every contained `WannierProjection.ProjectionSpec` must own fractional positions and must leave
`indices` unset. The materializer assigns the final global Wannier numbering in
candidate-ID, multiplicity-copy, and spec order.
"""
struct ProjectionCandidateSpec
    id::String
    specs::Vector{WannierProjection.ProjectionSpec}
    min_multiplicity::Int
    max_multiplicity::Int
    fixed_multiplicity::Union{Nothing, Int}

    function ProjectionCandidateSpec(;
        id,
        specs,
        min_multiplicity::Integer = 0,
        max_multiplicity::Integer = 1,
        fixed_multiplicity::Union{Nothing, Integer} = nothing,
    )
        candidate_id = strip(String(id))
        isempty(candidate_id) && throw(ArgumentError("projection candidate id must not be empty"))
        values = WannierProjection.ProjectionSpec[specs...]
        isempty(values) && throw(ArgumentError("projection candidate specs must not be empty"))
        for (spec_index, spec) in enumerate(values)
            spec.positions_fractional === nothing && throw(
                ArgumentError(
                    "projection candidate spec $(spec_index) requires explicit positions",
                ),
            )
            spec.indices === nothing || throw(
                ArgumentError("projection candidate spec $(spec_index) must leave indices unset"),
            )
        end
        minimum_value = Int(min_multiplicity)
        maximum_value = Int(max_multiplicity)
        minimum_value >= 0 || throw(ArgumentError("min_multiplicity must be nonnegative"))
        maximum_value >= minimum_value ||
            throw(ArgumentError("max_multiplicity must be at least min_multiplicity"))
        fixed_value = fixed_multiplicity === nothing ? nothing : Int(fixed_multiplicity)
        if fixed_value !== nothing
            minimum_value <= fixed_value <= maximum_value || throw(
                ArgumentError(
                    "fixed_multiplicity must lie within the declared multiplicity bounds",
                ),
            )
        end
        return new(candidate_id, values, minimum_value, maximum_value, fixed_value)
    end
end

"""Pinned upstream behavior profile and the scope of one compatibility claim."""
struct ProjectionRepresentationCompatibilityInfo
    upstream_package::String
    upstream_version::String
    upstream_commit::String
    upstream_source_sha256::String
    parity_eligible::Bool
    scope::Symbol
    character_tolerance::Float64
    character_round_digits::Int
    little_group_tolerance::Float64

    function ProjectionRepresentationCompatibilityInfo(
        upstream_package,
        upstream_version,
        upstream_commit,
        upstream_source_sha256,
        parity_eligible,
        scope,
        character_tolerance,
        character_round_digits,
        little_group_tolerance,
    )
        package = strip(String(upstream_package))
        version = strip(String(upstream_version))
        commit = lowercase(strip(String(upstream_commit)))
        source_sha256 = lowercase(strip(String(upstream_source_sha256)))
        isempty(package) && throw(ArgumentError("upstream_package must not be empty"))
        isempty(version) && throw(ArgumentError("upstream_version must not be empty"))
        occursin(r"^[0-9a-f]{40}$", commit) ||
            throw(ArgumentError("upstream_commit must be a full hexadecimal commit"))
        occursin(r"^[0-9a-f]{64}$", source_sha256) ||
            throw(ArgumentError("upstream_source_sha256 must be a hexadecimal SHA-256"))
        scope_value = Symbol(scope)
        scope_value in (:spinless_unitary, :generalized_symmetry) ||
            throw(ArgumentError("unsupported projection compatibility scope $(scope_value)"))
        character_value = Float64(character_tolerance)
        group_value = Float64(little_group_tolerance)
        digits_value = Int(character_round_digits)
        isfinite(character_value) && character_value > 0.0 ||
            throw(ArgumentError("character_tolerance must be positive and finite"))
        isfinite(group_value) && group_value > 0.0 ||
            throw(ArgumentError("little_group_tolerance must be positive and finite"))
        digits_value >= 0 || throw(ArgumentError("character_round_digits must be nonnegative"))
        return new(
            package,
            version,
            commit,
            source_sha256,
            Bool(parity_eligible),
            scope_value,
            character_value,
            digits_value,
            group_value,
        )
    end
end

"""Canonical little-group signature bounds at one irreducible k point."""
struct ProjectionRepresentationSignature
    kpoint_index::Int
    labels::Vector{String}
    dimensions::Vector{Int}
    wigner_types::Vector{Symbol}
    frozen_lower::Vector{Int}
    outer_upper::Vector{Int}
end

"""One representation-compatible integer combination and its independent validation state."""
struct ProjectionRepresentationSolution
    candidate_ids::Vector{String}
    coefficients::Vector{Int}
    total_dimension::Int
    nonzero_candidate_types::Int
    total_block_multiplicity::Int
    signature_multiplicities::Vector{Vector{Int}}
    validation_status::ProjectionRepresentationValidationStatus
    embedding_residuals::Dict{String, Float64}
    validation_sha256::String
end

"""
Immutable request for one projection-representation search.

Exactly one representation source is required. The target-subspace contract is
authoritative for `num_wannier` and frozen/outer masks. `SymmetryFoundation.BandRepresentation.spinor`
is the sole spinor switch.
"""
struct ProjectionRepresentationSearchConfig
    band_representation::Union{Nothing, SymmetryFoundation.BandRepresentation}
    band_representation_hdf5::Union{Nothing, String}
    target_subspace_contract::TargetSubspaceQualificationContract
    candidates::Vector{ProjectionCandidateSpec}
    radial_transform::WannierProjection.ProjectionRadialTransformConfig
    validate_retained_solutions::Bool
    max_results::Int
    max_search_nodes::Int
    thresholds::ProjectionRepresentationSearchThresholds
    output_hdf5::Union{Nothing, String}
    output_json::Union{Nothing, String}

    function ProjectionRepresentationSearchConfig(;
        band_representation::Union{Nothing, SymmetryFoundation.BandRepresentation} = nothing,
        band_representation_hdf5::Union{Nothing, AbstractString} = nothing,
        target_subspace_contract::TargetSubspaceQualificationContract,
        candidates,
        radial_transform::WannierProjection.ProjectionRadialTransformConfig = WannierProjection.ProjectionRadialTransformConfig(),
        validate_retained_solutions::Bool = true,
        max_results::Integer = 100,
        max_search_nodes::Integer = 1_000_000,
        thresholds::ProjectionRepresentationSearchThresholds = ProjectionRepresentationSearchThresholds(),
        output_hdf5::Union{Nothing, AbstractString} = nothing,
        output_json::Union{Nothing, AbstractString} = nothing,
    )
        representation_path =
            band_representation_hdf5 === nothing ? nothing : String(band_representation_hdf5)
        (band_representation === nothing) == (representation_path === nothing) && throw(
            ArgumentError(
                "exactly one of band_representation and band_representation_hdf5 is required",
            ),
        )
        representation_path !== nothing &&
            isempty(strip(representation_path)) &&
            throw(ArgumentError("band_representation_hdf5 must not be empty"))
        candidate_values = ProjectionCandidateSpec[candidates...]
        isempty(candidate_values) &&
            throw(ArgumentError("at least one projection candidate is required"))
        candidate_ids = getfield.(candidate_values, :id)
        length(unique(candidate_ids)) == length(candidate_ids) ||
            throw(ArgumentError("projection candidate ids must be unique"))
        result_limit = Int(max_results)
        node_limit = Int(max_search_nodes)
        result_limit > 0 || throw(ArgumentError("max_results must be positive"))
        node_limit > 0 || throw(ArgumentError("max_search_nodes must be positive"))
        hdf5_path = output_hdf5 === nothing ? nothing : String(output_hdf5)
        json_path = output_json === nothing ? nothing : String(output_json)
        hdf5_path !== nothing &&
            isempty(strip(hdf5_path)) &&
            throw(ArgumentError("output_hdf5 must not be empty"))
        json_path !== nothing &&
            isempty(strip(json_path)) &&
            throw(ArgumentError("output_json must not be empty"))
        return new(
            band_representation,
            representation_path,
            target_subspace_contract,
            candidate_values,
            radial_transform,
            validate_retained_solutions,
            result_limit,
            node_limit,
            thresholds,
            hdf5_path,
            json_path,
        )
    end
end

"""Auditable result of a complete, empty, limited, or uncertain search."""
struct ProjectionRepresentationSearchResult
    status::ProjectionRepresentationSearchStatus
    complete::Bool
    representation_sha256::String
    contract_sha256::String
    compatibility_info::ProjectionRepresentationCompatibilityInfo
    config_sha256::String
    payload_sha256::String
    spinor::Bool
    num_wannier::Int
    outer_mask_sha256::String
    frozen_mask_sha256::String
    candidates::Vector{ProjectionCandidateSpec}
    radial_transform::WannierProjection.ProjectionRadialTransformConfig
    visited_nodes::Int
    total_solution_count::Int
    truncated::Bool
    signatures::Vector{ProjectionRepresentationSignature}
    solutions::Vector{ProjectionRepresentationSolution}
    diagnostics::Vector{String}
end

"""Internal canonical representation-search problem shared by extension work packages."""
struct ProjectionRepresentationProblem
    signatures::Vector{ProjectionRepresentationSignature}
    candidate_ids::Vector{String}
    candidate_dimensions::Vector{Int}
    candidate_signatures::Matrix{Int}
    lower_bounds::Vector{Int}
    upper_bounds::Vector{Int}
    min_multiplicities::Vector{Int}
    max_multiplicities::Vector{Int}
    complete::Bool
    uncertain::Bool
    diagnostics::Vector{String}
end

"""Internal full-rank embedding evidence for one retained search solution."""
struct ProjectionRepresentationEmbeddingCertificate
    frozen_residual::Float64
    outer_residual::Float64
    frozen_rank::Int
    target_rank::Int
    outer_rank::Int
    complete::Bool
    uncertain::Bool
    diagnostics::Vector{String}
end
