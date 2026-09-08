"""Cold-path decision for one run-wide real-space replica lifecycle."""
struct RuntimeReplicaPlan
    requested_policy::Symbol
    effective_policy::Symbol
    source::Symbol
    map::Union{Nothing, MatrixElements.RealSpaceReplicaMap}
    mapping_sha256::Union{Nothing, String}
    wsvec_file::Union{Nothing, String}
    wsvec_sha256::Union{Nothing, String}
    mp_grid::Union{Nothing, NTuple{3, Int}}
    wigner_seitz_tolerance::Float64
    wigner_seitz_search_size::Int
    input_materialized::Union{Nothing, Bool}
    transformed_this_run::Bool
end

"""Schema-stable audit summary shared by Band, Integral, and K-slice runs."""
struct RuntimeReplicaSummary
    requested_policy::Symbol
    effective_policy::Symbol
    source::Symbol
    mapping_sha256::String
    mapping_digest_scheme::String
    wsvec_file::Union{Nothing, String}
    wsvec_sha256::Union{Nothing, String}
    mp_grid::Union{Nothing, NTuple{3, Int}}
    wigner_seitz_tolerance::Float64
    wigner_seitz_search_size::Int
    input_materialized::Union{Nothing, Bool}
    output_materialized::Bool
    transformed_this_run::Bool
    input_num_r_vectors::Int
    output_num_r_vectors::Int
    scalar_degeneracy_applied::Bool
    pair_degeneracy_applied::Bool
end

"""Return the machine-readable replica summary used by metadata and progress."""
Base.@noinline function runtime_replica_summary(summary::RuntimeReplicaSummary)
    return (
        schema = "wanniernlqg.runtime-replica-summary",
        requested_policy = summary.requested_policy,
        effective_policy = summary.effective_policy,
        source = summary.source,
        mapping_sha256 = summary.mapping_sha256,
        mapping_digest_scheme = summary.mapping_digest_scheme,
        wsvec_file = summary.wsvec_file,
        wsvec_sha256 = summary.wsvec_sha256,
        mp_grid = summary.mp_grid,
        wigner_seitz_tolerance = summary.wigner_seitz_tolerance,
        wigner_seitz_search_size = summary.wigner_seitz_search_size,
        input_minimum_distance_materialized = summary.input_materialized,
        output_minimum_distance_materialized = summary.output_materialized,
        replica_transformed_this_run = summary.transformed_this_run,
        input_num_r_vectors = summary.input_num_r_vectors,
        effective_num_r_vectors = summary.output_num_r_vectors,
        scalar_degeneracy_applied = summary.scalar_degeneracy_applied,
        pair_degeneracy_applied = summary.pair_degeneracy_applied,
    )
end

# Extract normalized row-wise centers from serialized position matrices.
function _runtime_wannier_centers_fractional(model::TightBindingModel)
    home = findall(index -> all(iszero, @view(model.r_vectors[:, index])), axes(model.r_vectors, 2))
    length(home) == 1 ||
        throw(ArgumentError("replica preparation requires exactly one home-cell R vector"))
    home_index = only(home)
    centers_cartesian = zeros(Float64, model.num_orbitals, 3)
    for orbital in 1:model.num_orbitals, direction in 1:3
        centers_cartesian[orbital, direction] = real(
            model.position_r[orbital, orbital, direction, home_index] /
            model.r_degeneracies[home_index],
        )
    end
    all(isfinite, centers_cartesian) ||
        throw(ArgumentError("Wannier centers contain non-finite values"))
    centers_fractional = centers_cartesian * inv(model.lattice)
    all(isfinite, centers_fractional) ||
        throw(ArgumentError("fractional Wannier centers contain non-finite values"))
    return Matrix{Float64}(centers_fractional)
end

# Resolve an optional public wsvec path only from the explicit EffectiveTaskConfig field.
function _runtime_wsvec_path(cfg::EffectiveTaskConfig, ctx::RunContext)
    cfg.wsvec_file === nothing && return nothing
    configured = strip(something(cfg.wsvec_file))
    isempty(configured) && throw(ArgumentError("wsvec_file must be nothing or a non-empty path"))
    path =
        isabspath(configured) ? normpath(configured) :
        normpath(joinpath(resolve_case_root(cfg.case_root), configured))
    isfile(path) || throw(ArgumentError("Wannier90 wsvec file does not exist: $(path)"))
    return path
end

"""Resolve one fail-closed replica plan from config plus optional Packed metadata."""
function build_runtime_replica_plan(
    cfg::EffectiveTaskConfig,
    ctx::RunContext,
    model::TightBindingModel,
    manifest,
)
    requested = Symbol(_canonical_key(cfg.real_space_replica_policy))
    requested in (:auto, :input, :minimum_distance) ||
        throw(ArgumentError("invalid real-space replica policy $(cfg.real_space_replica_policy)"))
    wsvec_path = _runtime_wsvec_path(cfg, ctx)
    manifest_policy = manifest === nothing ? :input : manifest.real_space_replica_policy
    legacy_schema =
        manifest !== nothing &&
        hasproperty(manifest, :schema_version) &&
        startswith(String(manifest.schema_version), "5.")
    legacy_manifest = manifest !== nothing && (manifest_policy == :legacy || legacy_schema)
    input_materialized = if manifest === nothing
        false
    elseif manifest.minimum_distance_materialized
        true
    elseif legacy_manifest
        nothing
    else
        false
    end
    manifest_grid = manifest === nothing ? nothing : manifest.mp_grid
    cfg.mp_grid !== nothing &&
        manifest_grid !== nothing &&
        cfg.mp_grid != manifest_grid &&
        throw(
            ArgumentError(
                "EffectiveTaskConfig mp_grid=$(cfg.mp_grid) conflicts with bundle mp_grid=$(manifest_grid)",
            ),
        )
    grid = cfg.mp_grid === nothing ? manifest_grid : cfg.mp_grid

    if input_materialized === true
        wsvec_path === nothing || throw(
            ArgumentError(
                "materialized minimum-distance bundles cannot be combined with wsvec_file",
            ),
        )
        requested == :input && throw(
            ArgumentError(
                "cannot recover input R support from a materialized minimum-distance bundle",
            ),
        )
        manifest_policy == :minimum_distance ||
            throw(ArgumentError("bundle materialization flag and replica policy are inconsistent"))
        tolerance = something(manifest.wigner_seitz_tolerance, cfg.wigner_seitz_tolerance)
        search_size = something(manifest.wigner_seitz_search_size, cfg.wigner_seitz_search_size)
        cfg.wigner_seitz_tolerance != 1.0e-5 &&
            cfg.wigner_seitz_tolerance != tolerance &&
            throw(
                ArgumentError(
                    "EffectiveTaskConfig wigner_seitz_tolerance conflicts with materialized bundle metadata",
                ),
            )
        cfg.wigner_seitz_search_size != 3 &&
            cfg.wigner_seitz_search_size != search_size &&
            throw(
                ArgumentError(
                    "EffectiveTaskConfig wigner_seitz_search_size conflicts with materialized bundle metadata",
                ),
            )
        return RuntimeReplicaPlan(
            requested,
            :minimum_distance,
            :materialized_bundle,
            nothing,
            manifest.replica_mapping_sha256,
            nothing,
            nothing,
            grid,
            Float64(tolerance),
            Int(search_size),
            true,
            false,
        )
    end

    if legacy_manifest && (requested == :minimum_distance || wsvec_path !== nothing)
        throw(
            ArgumentError(
                "legacy Packed bundles lack authoritative replica lifecycle metadata and cannot be materialized at runtime",
            ),
        )
    end
    effective = if requested != :auto
        requested
    elseif manifest === nothing
        wsvec_path !== nothing || cfg.mp_grid !== nothing ? :minimum_distance : :input
    elseif legacy_manifest
        :input
    else
        manifest_policy
    end
    if effective == :input
        wsvec_path === nothing || throw(
            ArgumentError("real_space_replica_policy=input cannot be combined with wsvec_file"),
        )
        cfg.mp_grid === nothing ||
            throw(ArgumentError("real_space_replica_policy=input cannot be combined with mp_grid"))
        cfg.wigner_seitz_tolerance == 1.0e-5 || throw(
            ArgumentError(
                "real_space_replica_policy=input requires the default wigner_seitz_tolerance",
            ),
        )
        cfg.wigner_seitz_search_size == 3 || throw(
            ArgumentError(
                "real_space_replica_policy=input requires the default wigner_seitz_search_size",
            ),
        )
        identity_mapping_sha256 = MatrixElements.input_real_space_replica_mapping_sha256(
            model.r_vectors,
            model.r_degeneracies,
            model.num_orbitals,
        )
        return RuntimeReplicaPlan(
            requested,
            :input,
            legacy_manifest ? :legacy_input : :input,
            nothing,
            identity_mapping_sha256,
            nothing,
            nothing,
            grid,
            cfg.wigner_seitz_tolerance,
            cfg.wigner_seitz_search_size,
            input_materialized,
            false,
        )
    end

    parsed_wsvec = wsvec_path === nothing ? nothing : read_wannier_wsvec(wsvec_path, model)
    recomputed_map = if grid === nothing
        nothing
    else
        MatrixElements.minimum_distance_real_space_replica_map(
            model.r_vectors,
            model.r_degeneracies,
            model.lattice,
            something(grid),
            _runtime_wannier_centers_fractional(model);
            tolerance = cfg.wigner_seitz_tolerance,
            search_size = cfg.wigner_seitz_search_size,
        )
    end
    wsvec_map = if parsed_wsvec === nothing
        nothing
    else
        MatrixElements.real_space_replica_map_from_wsvec(
            model.r_vectors,
            model.r_degeneracies,
            parsed_wsvec.translations,
        )
    end
    wsvec_map === nothing &&
        recomputed_map === nothing &&
        throw(
            ArgumentError(
                "minimum_distance requires explicit wsvec_file or mp_grid; adjacent files are never guessed",
            ),
        )
    if wsvec_map !== nothing && recomputed_map !== nothing
        wsvec_map.source_r_vectors == recomputed_map.source_r_vectors &&
        wsvec_map.source_degeneracies == recomputed_map.source_degeneracies &&
        wsvec_map.target_r_vectors == recomputed_map.target_r_vectors &&
        wsvec_map.images == recomputed_map.images ||
            throw(ArgumentError("wsvec_file and mp_grid produce different canonical replica maps"))
        wsvec_map.mapping_sha256 == recomputed_map.mapping_sha256 ||
            error("internal error: equal replica maps produced different canonical digests")
    end
    map = wsvec_map === nothing ? something(recomputed_map) : something(wsvec_map)
    return RuntimeReplicaPlan(
        requested,
        :minimum_distance,
        parsed_wsvec === nothing ? :recomputed : :wsvec,
        map,
        map.mapping_sha256,
        wsvec_path,
        parsed_wsvec === nothing ? nothing : parsed_wsvec.file_sha256,
        grid,
        cfg.wigner_seitz_tolerance,
        cfg.wigner_seitz_search_size,
        false,
        true,
    )
end

# Materialize every demanded component through the same prepared map.
function prepare_runtime_components(
    cfg::EffectiveTaskConfig,
    ctx::RunContext,
    components,
    model::TightBindingModel,
    manifest,
)
    plan = build_runtime_replica_plan(cfg, ctx, model, manifest)
    map = plan.map
    prepared = components
    output_vectors = model.r_vectors
    output_degeneracies = model.r_degeneracies
    if plan.transformed_this_run
        prepared =
            Dict{RealSpaceOperatorKind, Dict{NTuple{2, Int8}, AbstractArray{ComplexF64, 3}}}()
        for (kind, component_views) in components
            selected = Dict{NTuple{2, Int8}, AbstractArray{ComplexF64, 3}}()
            for (component, values) in component_views
                selected[component] = MatrixElements.materialize_replica_component(
                    values,
                    model.r_degeneracies,
                    map,
                    MatrixElements.SerializedWannier90ReplicaValues(),
                )
            end
            prepared[kind] = selected
        end
        output_vectors = map.target_r_vectors
        output_degeneracies = ones(Int, size(output_vectors, 2))
    end
    mapping_sha = plan.mapping_sha256
    if mapping_sha === nothing
        throw(ArgumentError("materialized bundle is missing replica_mapping_sha256"))
    end
    digest_scheme =
        plan.source == :materialized_bundle ? "manifest-provided:operator-bundle-v6" :
        MatrixElements.REAL_SPACE_REPLICA_MAP_DIGEST_SCHEME
    summary = RuntimeReplicaSummary(
        plan.requested_policy,
        plan.effective_policy,
        plan.source,
        mapping_sha,
        digest_scheme,
        plan.wsvec_file,
        plan.wsvec_sha256,
        plan.mp_grid,
        plan.wigner_seitz_tolerance,
        plan.wigner_seitz_search_size,
        plan.input_materialized,
        plan.effective_policy == :minimum_distance,
        plan.transformed_this_run,
        model.num_r_vectors,
        size(output_vectors, 2),
        plan.transformed_this_run,
        plan.transformed_this_run,
    )
    return (
        components = prepared,
        r_vectors = output_vectors,
        degeneracies = output_degeneracies,
        plan = plan,
        summary = summary,
    )
end
