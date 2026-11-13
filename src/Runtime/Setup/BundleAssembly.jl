# Resolve the workspace band-window size, treating -1 or oversized windows as all orbitals and rejecting other nonpositive sizes.
function _effective_window_band_count(band_window_size::Int, num_orbitals::Int)
    if band_window_size == -1 || 2 * band_window_size > num_orbitals
        return num_orbitals
    elseif band_window_size <= 0
        error(
            "Invalid band_window_size=$(band_window_size); use a positive value or -1 for all bands.",
        )
    end
    return band_window_size
end

# Construct a logical integral grid from one, two, or three counts, fixing inactive coordinates at zero.
function _integral_k_grid(k_mesh::Union{NTuple{1, Int}, NTuple{2, Int}, NTuple{3, Int}})
    if length(k_mesh) == 1
        return IntegralKGrid(k_mesh[1], 1, 1, true)
    end
    if length(k_mesh) == 2
        nk1, nk2 = k_mesh
        return IntegralKGrid(nk1, nk2, 1, true)
    end
    nk1, nk2, nk3 = k_mesh
    return IntegralKGrid(nk1, nk2, nk3, false)
end

# Return one-based cyclic mesh indices owned by a zero-based MPI rank.
function _local_k_indices(num_kpoints::Int, rank::Int, size::Int)
    local_k_indices = Int[]
    for kpoint_index in (rank + 1):size:num_kpoints
        push!(local_k_indices, kpoint_index)
    end
    return local_k_indices
end

const _DETERMINISTIC_INTEGRAL_LANE_LIMIT = 64

# Keep integral accumulation groups independent of Julia thread and MPI rank counts.
_deterministic_integral_lane_count(num_kpoints::Int) =
    min(num_kpoints, _DETERMINISTIC_INTEGRAL_LANE_LIMIT)

# Assign one contiguous, globally stable k-point range to a reduction lane.
function _deterministic_integral_lane_range(num_kpoints::Int, num_lanes::Int, lane_id::Int)
    1 <= lane_id <= num_lanes || throw(BoundsError("deterministic integral lane", lane_id))
    first_index = fld((lane_id - 1) * num_kpoints, num_lanes) + 1
    last_index = fld(lane_id * num_kpoints, num_lanes)
    return first_index:last_index
end

# Give every logical lane to exactly one MPI rank, independent of thread count.
function _local_deterministic_integral_lanes(num_lanes::Int, rank::Int, size::Int)
    return collect((rank + 1):size:num_lanes)
end

"""
Read the explicit Fourier-timing environment opt-in using the shared truth-value parser.
"""
fourier_timing_enabled() = mpi_env_truthy("WANNIERNLQG_FOURIER_TIMING")

"""
Combine the immutable Fourier plan with workspace cache/timing statistics for metadata.

Sum memory and timings across local workspaces; retain explicit factors, offset graph, load estimates and symmetry workload when present.
"""
function fourier_execution_summary(
    cfg::EffectiveTaskConfig,
    plan::FourierExecutionPlan,
    workspaces::AbstractVector{<:MatrixElementWorkspace},
)
    grid = plan.grid
    stats = [mixed_fourier_stats(workspace) for workspace in workspaces]
    active_stats = [stat for stat in stats if stat !== nothing]
    groups =
        isempty(active_stats) ? String[] :
        String[string(group) for group in first(active_stats).groups]
    summary = (
        backend = plan.backend,
        requested_backend = normalized_fourier_backend(cfg),
        effective_backend = plan.backend,
        requested_domain_nodes = prod(cfg.k_mesh),
        computation_grid_nodes = grid===nothing ? nothing : prod(grid.mesh),
        domain_index_mapping = cfg.integration_bounds===nothing ? "original periodic grid" :
                               cfg.integration_algorithm isa UniformIntegration &&
                               cfg.integration_algorithm.region_quadrature == :left_endpoint ?
                               "Cartesian left endpoint evaluated directly" :
                               "Cartesian midpoint evaluated directly",
        NKdiv = grid === nothing ? nothing : grid.nkdiv,
        NKFFT = grid === nothing ? nothing : grid.nkfft,
        factor_source = plan.factor_source,
        estimated_memory_bytes = plan.estimated_memory_bytes,
        memory_limit_bytes = plan.memory_limit_bytes,
        load_imbalance = plan.load_imbalance,
        blocks_per_rank = plan.blocks_per_rank,
        kpoints_per_rank = plan.kpoints_per_rank,
        task_signatures = plan.task_signatures,
        union_capabilities = plan.union_capabilities,
        union_fourier_groups = plan.union_fourier_groups,
        union_offset_signatures = plan.union_offset_signatures,
        union_group_offset_counts = plan.union_group_offset_counts,
        groups = groups,
        offset_count = isempty(active_stats) ? 0 :
                       maximum(stat.offset_count for stat in active_stats),
        cache_entries = isempty(active_stats) ? 0 :
                        maximum(stat.cache_entries for stat in active_stats),
        allocated_bytes = isempty(active_stats) ? 0 :
                          sum(stat.allocated_bytes for stat in active_stats),
        current_allocated_bytes = isempty(active_stats) ? 0 :
                                  sum(stat.current_allocated_bytes for stat in active_stats),
        peak_allocated_bytes = isempty(active_stats) ? 0 :
                               sum(stat.peak_allocated_bytes for stat in active_stats),
        buffer_allocations = isempty(active_stats) ? 0 :
                             sum(stat.buffer_allocations for stat in active_stats),
        plan_builds = isempty(active_stats) ? 0 : sum(stat.plan_builds for stat in active_stats),
        buffer_allocation_seconds = isempty(active_stats) ? 0.0 :
                                    sum(stat.buffer_allocation_seconds for stat in active_stats),
        plan_build_seconds = isempty(active_stats) ? 0.0 :
                             sum(stat.plan_build_seconds for stat in active_stats),
        repack_seconds = isempty(active_stats) ? 0.0 :
                         sum(stat.repack_seconds for stat in active_stats),
        allocated_memory_limit_bytes = isempty(active_stats) ? 0 :
                                       sum(stat.memory_limit_bytes for stat in active_stats),
        pack_seconds = isempty(active_stats) ? 0.0 :
                       sum(stat.pack_seconds for stat in active_stats),
        fft_seconds = isempty(active_stats) ? 0.0 : sum(stat.fft_seconds for stat in active_stats),
        extract_seconds = isempty(active_stats) ? 0.0 :
                          sum(stat.extract_seconds for stat in active_stats),
        fft_calls = isempty(active_stats) ? 0 : sum(stat.fft_calls for stat in active_stats),
        cache_hits = isempty(active_stats) ? 0 : sum(stat.cache_hits for stat in active_stats),
        evictions = isempty(active_stats) ? 0 : sum(stat.evictions for stat in active_stats),
    )
    return plan.symmetry_workload_enabled ?
           merge(
        summary,
        (
            evaluation_kpoint_count = plan.evaluation_kpoint_count,
            response_component_workload = plan.response_component_workload,
            auto_direct_cost_estimate = plan.auto_direct_cost_estimate,
            auto_mixed_cost_estimate = plan.auto_mixed_cost_estimate,
        ),
    ) : summary
end

"""
Write enabled per-workspace direct/Mixed Fourier timing measurements and execution-plan metadata; return the artifact path.
"""
function write_fourier_timing(
    run_dir::AbstractString,
    rank::Int,
    kloop_seconds::Float64,
    workspace::MatrixElementWorkspace,
    execution_plan::FourierExecutionPlan,
)
    fourier_timing_enabled() || return nothing
    stats = fourier_timing_stats(workspace)
    mixed = stats.mixed
    grid = execution_plan.grid
    mkpath(run_dir)
    path = joinpath(run_dir, "fourier_timing_rank_$(rank).csv")
    open(path, "w") do io
        println(
            io,
            "rank,kloop_seconds,direct_seconds,direct_calls,mixed_pack_seconds,mixed_fft_seconds,mixed_extract_seconds,mixed_fft_calls,mixed_cache_hits,mixed_allocated_bytes,mixed_memory_limit_bytes,mpi_size,backend,NKdiv,NKFFT,estimated_memory_bytes",
        )
        println(
            io,
            join(
                (
                    rank,
                    kloop_seconds,
                    stats.direct_seconds,
                    stats.direct_calls,
                    mixed === nothing ? 0.0 : mixed.pack_seconds,
                    mixed === nothing ? 0.0 : mixed.fft_seconds,
                    mixed === nothing ? 0.0 : mixed.extract_seconds,
                    mixed === nothing ? 0 : mixed.fft_calls,
                    mixed === nothing ? 0 : mixed.cache_hits,
                    mixed === nothing ? 0 : mixed.allocated_bytes,
                    mixed === nothing ? 0 : mixed.memory_limit_bytes,
                    mpi_process_size(),
                    execution_plan.backend,
                    replace(repr(grid === nothing ? nothing : grid.nkdiv), ',' => ';'),
                    replace(repr(grid === nothing ? nothing : grid.nkfft), ',' => ';'),
                    execution_plan.estimated_memory_bytes,
                ),
                ',',
            ),
        )
    end
    return path
end

# Allocate one zeroed atomic activity/skipped counter per matrix-family label.
function _family_counter_map(labels::Vector{String})
    counters = Dict{String, BundleFamilyCounter}()
    for label in labels
        counters[label] = BundleFamilyCounter(label)
    end
    return counters
end

# Snapshot atomic activity/skipped counts into named tuples in the caller's requested family order.
function _family_counts(counters::Dict{String, BundleFamilyCounter}, labels::Vector{String})
    return NamedTuple[
        (family = label, active = counters[label].active[], skipped = counters[label].skipped[]) for
        label in labels
    ]
end

# Append a string only if absent, preserving the vector's existing order; return the same vector.
function _push_unique!(items::Vector{String}, item::String)
    item in items || push!(items, item)
    return items
end

"""
Return unique matrix-family labels in first-task occurrence order; reject specs missing from the registry.
"""
function bundle_matrix_families(specs::Vector{NormalizedTaskSpec}, cfg::EffectiveTaskConfig)
    families = String[]
    for spec in specs
        definition = task_definition(spec.quantity, spec.method, spec.calculation)
        definition === nothing && error("Missing TaskDefinition for $(spec.label).")
        _push_unique!(families, matrix_family_label(definition, cfg))
    end
    return families
end

"""
Union task capability and Cartesian requirements into the shared matrix execution plan.

Include native source-gauge storage only when a consuming policy needs it, preserve configured energy tolerances and Wannier-center convention, and reject missing task definitions.
"""
function bundle_matrix_element_plan(
    specs::Vector{NormalizedTaskSpec},
    cfg::EffectiveTaskConfig,
    tensor_indices::Union{Nothing, AbstractVector{<:Integer}} = nothing;
    curvature_curl_only::Bool = false,
)
    capabilities = MatrixElementKind[SPECTRUM]
    push_unique_capability!(kind) = kind in capabilities || push!(capabilities, kind)
    # Intrinsic Hall geometry is Cartesian 3D; integration measure remains independently d-dimensional.
    matrix_dimension =
        any(spec -> spec.quantity == :intrinsic_ahc, specs) ? 3 : cfg.spatial_dimension
    directions = MatrixElementDirectionRequirements(matrix_dimension)
    source_gauge_required = any(specs) do spec
        definition = task_definition(spec.quantity, spec.method, spec.calculation)
        definition === nothing && error("Missing TaskDefinition for $(spec.label).")
        definition.matrix_policy in (
            MATRIX_GEOMETRIC_SHIFT_CURRENT_Q0,
            MATRIX_GEOMETRIC_SHIFT_CURRENT_FINITE_Q,
            MATRIX_GEOMETRIC_QHC,
            MATRIX_GEOMETRIC_SHIFT_VECTOR,
            MATRIX_WILSON_SHIFT_CURRENT,
            MATRIX_WILSON_QHC,
            MATRIX_WILSON_SHIFT_VECTOR,
            MATRIX_PHOTON_DRAG_INJECTION_CURRENT,
        )
    end

    for spec in specs
        definition = task_definition(spec.quantity, spec.method, spec.calculation)
        definition === nothing && error("Missing TaskDefinition for $(spec.label).")
        policy = definition.matrix_policy
        if policy == MATRIX_SPECTRUM
            nothing
        elseif policy == MATRIX_BERRY_MULTIPOLE_DC
            settings = something(cfg.berry_multipole)
            tensor_plan = berry_multipole_tensor_plan(settings)
            for kind in (HAMILTONIAN_DERIVATIVES, BERRY_CONNECTION, WANNIER_CURVATURE)
                push_unique_capability!(kind)
            end
            for component in tensor_plan.moment_components
                a, b = component[1:2]
                directions = require_matrix_element_axes(directions, BERRY_CONNECTION, (a, b))
                directions = require_matrix_element_pairs(directions, WANNIER_CURVATURE, ((a, b),))
                if settings.parameters.integral_form == :fermi_surface
                    directions = require_matrix_element_axes(
                        directions,
                        HAMILTONIAN_DERIVATIVES,
                        component[3:end],
                    )
                end
            end
        elseif policy == MATRIX_INTRINSIC_AHC
            # Raw complete first jets and ambient curvature, not regularized r_eta.
            for kind in (HAMILTONIAN_DERIVATIVES, INTERNAL_CONNECTION, WANNIER_CURVATURE)
                push_unique_capability!(kind)
            end
            for kind in (HAMILTONIAN_DERIVATIVES, INTERNAL_CONNECTION, WANNIER_POSITION)
                directions=require_matrix_element_axes(directions, kind, (1, 2, 3))
            end
            for kind in (WANNIER_CURVATURE, INTERNAL_CONNECTION_DERIVATIVES)
                directions=require_matrix_element_pairs(
                    directions,
                    kind,
                    [(a, b) for a in 1:3 for b in 1:3],
                )
            end
        elseif policy in (
            MATRIX_LINEAR_TRANSPORT,
            MATRIX_LINEAR_OPTICAL_RESPONSE,
            MATRIX_ORBITAL_MAGNETIZATION,
        )
            for kind in
                (HAMILTONIAN_DERIVATIVES, INTERNAL_CONNECTION, BERRY_CONNECTION, WANNIER_CURVATURE)
                push_unique_capability!(kind)
            end
            for kind in
                (HAMILTONIAN_DERIVATIVES, INTERNAL_CONNECTION, WANNIER_POSITION, BERRY_CONNECTION)
                directions=require_matrix_element_axes(directions, kind, (1, 2, 3))
            end
            for kind in (WANNIER_CURVATURE, INTERNAL_CONNECTION_DERIVATIVES)
                directions=require_matrix_element_pairs(
                    directions,
                    kind,
                    [(a, b) for a in 1:3 for b in 1:3],
                )
            end
            # All metric spectral consumers use the prepared physical velocity.
            if cfg.native_model_input isa NonorthogonalLocalizedInput
                for kind in (BERRY_CONNECTION, VELOCITY_VERTICES)
                    push_unique_capability!(kind)
                    directions=require_matrix_element_axes(directions, kind, (1, 2, 3))
                end
            end
        elseif policy in (MATRIX_SECOND_HARMONIC, MATRIX_JERK_CURRENT, MATRIX_THIRD_HARMONIC)
            # Orthogonal nonlinear kernels build their explicit D/r roles from h/A.
            # Metric SHG additionally requests the optional normalized cutoff source jet.
            metric_shg =
                policy == MATRIX_SECOND_HARMONIC &&
                cfg.native_model_input isa NonorthogonalLocalizedInput
            nonlinear_kinds =
                metric_shg ?
                (
                    BERRY_CONNECTION,
                    INTERNAL_CONNECTION_DERIVATIVES,
                    HAMILTONIAN_SECOND_DERIVATIVES,
                ) :
                (
                    HAMILTONIAN_DERIVATIVES,
                    INTERNAL_CONNECTION,
                    INTERNAL_CONNECTION_DERIVATIVES,
                    HAMILTONIAN_SECOND_DERIVATIVES,
                )
            for kind in nonlinear_kinds
                push_unique_capability!(kind)
            end
            vertex_kinds =
                metric_shg ?
                (BERRY_CONNECTION, INTERNAL_CONNECTION, HAMILTONIAN_DERIVATIVES, GAUGE_CORRECTION) :
                (INTERNAL_CONNECTION, HAMILTONIAN_DERIVATIVES)
            for kind in vertex_kinds
                directions = require_matrix_element_axes(directions, kind, (1, 2, 3))
            end
            for kind in (INTERNAL_CONNECTION_DERIVATIVES, HAMILTONIAN_SECOND_DERIVATIVES)
                directions = require_matrix_element_pairs(
                    directions,
                    kind,
                    [(a, b) for a in 1:3 for b in 1:3],
                )
            end
            if policy == MATRIX_SECOND_HARMONIC &&
               cfg.native_model_input isa NonorthogonalLocalizedInput
                for kind in (VELOCITY_VERTICES, WANNIER_CURVATURE, OPTICAL_CUTOFF_VERTICES)
                    push_unique_capability!(kind)
                end
                directions=require_matrix_element_axes(directions, VELOCITY_VERTICES, (1, 2, 3))
                directions=require_matrix_element_pairs(
                    directions,
                    WANNIER_CURVATURE,
                    [(a, b) for a in 1:3 for b in 1:3],
                )
            end
        elseif policy in (MATRIX_CONVENTIONAL_Q0_CURRENT, MATRIX_CONVENTIONAL_QHC)
            push_unique_capability!(BERRY_CONNECTION)
            push_unique_capability!(INTERNAL_CONNECTION_DERIVATIVES)
            push_unique_capability!(HAMILTONIAN_SECOND_DERIVATIVES)
            if tensor_indices !== nothing
                a, b, c = tensor_indices
                if policy == MATRIX_CONVENTIONAL_Q0_CURRENT
                    directions = require_matrix_element_axes(directions, BERRY_CONNECTION, (b, c))
                    directions =
                        require_matrix_element_axes(directions, INTERNAL_CONNECTION, (a, b, c))
                    directions =
                        require_matrix_element_axes(directions, HAMILTONIAN_DERIVATIVES, (a, b, c))
                    directions =
                        require_matrix_element_axes(directions, GAUGE_CORRECTION, (a, b, c))
                    directions = require_matrix_element_pairs(
                        directions,
                        INTERNAL_CONNECTION_DERIVATIVES,
                        ((c, a), (b, a)),
                    )
                    directions = require_matrix_element_pairs(
                        directions,
                        HAMILTONIAN_SECOND_DERIVATIVES,
                        ((c, a), (b, a)),
                    )
                else
                    directions = require_matrix_element_axes(directions, BERRY_CONNECTION, (c,))
                    directions =
                        require_matrix_element_axes(directions, INTERNAL_CONNECTION, (a, b))
                    directions =
                        require_matrix_element_axes(directions, HAMILTONIAN_DERIVATIVES, (a, b))
                    directions = require_matrix_element_axes(directions, GAUGE_CORRECTION, (a, b))
                    directions = require_matrix_element_pairs(
                        directions,
                        INTERNAL_CONNECTION_DERIVATIVES,
                        ((b, a),),
                    )
                    directions = require_matrix_element_pairs(
                        directions,
                        HAMILTONIAN_SECOND_DERIVATIVES,
                        ((b, a),),
                    )
                end
            end
        elseif policy == MATRIX_CONVENTIONAL_INJECTION_CURRENT
            push_unique_capability!(BERRY_CONNECTION)
            push_unique_capability!(HAMILTONIAN_DERIVATIVES)
            if tensor_indices !== nothing
                a, b, c = tensor_indices
                directions = require_matrix_element_axes(directions, BERRY_CONNECTION, (b, c))
                directions = require_matrix_element_axes(directions, HAMILTONIAN_DERIVATIVES, (a,))
            end
        elseif policy == MATRIX_CONVENTIONAL_INJECTION_SPIN_CURRENT
            push_unique_capability!(BERRY_CONNECTION)
            push_unique_capability!(SPIN_VELOCITY)
            if tensor_indices !== nothing
                a, s, b, c = tensor_indices
                directions = require_matrix_element_axes(directions, BERRY_CONNECTION, (b, c))
                directions = require_matrix_element_pairs(directions, SPIN_VELOCITY, ((a, s),))
            end
        elseif policy == MATRIX_CONVENTIONAL_SHIFT_SPIN_CURRENT
            push_unique_capability!(SPIN_VELOCITY)
            push_unique_capability!(INTERNAL_CONNECTION)
            push_unique_capability!(INTERNAL_CONNECTION_DERIVATIVES)
            push_unique_capability!(HAMILTONIAN_SECOND_DERIVATIVES)
            if tensor_indices !== nothing
                a, s, b, c = tensor_indices
                axes = (a, b, c)
                pairs = ((a, b), (b, a), (a, c), (c, a))
                directions = require_matrix_element_axes(directions, INTERNAL_CONNECTION, axes)
                directions = require_matrix_element_axes(directions, HAMILTONIAN_DERIVATIVES, axes)
                directions = require_matrix_element_pairs(directions, SPIN_VELOCITY, ((a, s),))
                directions =
                    require_matrix_element_pairs(directions, INTERNAL_CONNECTION_DERIVATIVES, pairs)
                directions =
                    require_matrix_element_pairs(directions, HAMILTONIAN_SECOND_DERIVATIVES, pairs)
            end
        elseif policy in (
            MATRIX_CONVENTIONAL_BERRY_CURVATURE,
            MATRIX_CONVENTIONAL_BERRY_CURVATURE_DIPOLE,
            MATRIX_CONVENTIONAL_BERRY_CURVATURE_QUADRUPOLE,
            MATRIX_CONVENTIONAL_HCT,
        )
            push_unique_capability!(BERRY_CONNECTION)
            push_unique_capability!(WANNIER_CURVATURE)
            if tensor_indices !== nothing
                if policy == MATRIX_CONVENTIONAL_HCT
                    b, a, d, c = tensor_indices
                    directions =
                        require_matrix_element_axes(directions, BERRY_CONNECTION, (a, b, c, d))
                    directions =
                        require_matrix_element_pairs(directions, WANNIER_CURVATURE, ((d, c),))
                else
                    a, b = tensor_indices[1], tensor_indices[2]
                    directions = require_matrix_element_axes(directions, BERRY_CONNECTION, (a, b))
                    directions =
                        require_matrix_element_pairs(directions, WANNIER_CURVATURE, ((a, b),))
                end
            end
        elseif policy == MATRIX_CONVENTIONAL_ZEEMAN_INTERBAND_GEOMETRY
            push_unique_capability!(BERRY_CONNECTION)
            push_unique_capability!(SPIN)
            if tensor_indices !== nothing
                alpha, beta = tensor_indices
                directions = require_matrix_element_axes(directions, BERRY_CONNECTION, (alpha,))
                directions = require_matrix_element_axes(directions, SPIN, (beta,))
            end
        elseif policy == MATRIX_PHOTON_DRAG_INJECTION_CURRENT
            # Complete V consumes raw A and h for both full and component plans.
            push_unique_capability!(INTERNAL_CONNECTION)
            push_unique_capability!(HAMILTONIAN_DERIVATIVES)
            if tensor_indices === nothing
                directions = require_matrix_element_axes(
                    directions,
                    INTERNAL_CONNECTION,
                    1:cfg.spatial_dimension,
                )
                directions = require_matrix_element_axes(
                    directions,
                    HAMILTONIAN_DERIVATIVES,
                    1:cfg.spatial_dimension,
                )
            end
            if tensor_indices !== nothing
                a, b, c = tensor_indices
                directions = require_matrix_element_axes(directions, INTERNAL_CONNECTION, (b, c))
                directions =
                    require_matrix_element_axes(directions, HAMILTONIAN_DERIVATIVES, (a, b, c))
            end
        elseif policy in (
            MATRIX_CONVENTIONAL_QUANTUM_METRIC,
            MATRIX_CONVENTIONAL_INTERBAND_GEOMETRY,
            MATRIX_CONVENTIONAL_QUANTUM_METRIC_DIPOLE,
            MATRIX_CONVENTIONAL_QUANTUM_METRIC_QUADRUPOLE,
            MATRIX_CONVENTIONAL_QUANTUM_CHRISTOFFEL,
            MATRIX_CONVENTIONAL_TRIPLE_PHASE_PRODUCT,
        )
            push_unique_capability!(BERRY_CONNECTION)
            if tensor_indices !== nothing
                operator_axes =
                    policy in (
                        MATRIX_CONVENTIONAL_QUANTUM_CHRISTOFFEL,
                        MATRIX_CONVENTIONAL_TRIPLE_PHASE_PRODUCT,
                    ) ? unique(tensor_indices) : unique(tensor_indices[1:2])
                directions =
                    require_matrix_element_axes(directions, BERRY_CONNECTION, operator_axes)
            end
        elseif policy in (MATRIX_PROJECTOR_SHIFT_CURRENT, MATRIX_PROJECTOR_QHC)
            push_unique_capability!(WANNIER_POSITION)
            push_unique_capability!(INTERNAL_CONNECTION_DERIVATIVES)
            if tensor_indices !== nothing
                a, b, c = tensor_indices
                directions =
                    require_matrix_element_axes(directions, WANNIER_POSITION, unique((a, b, c)))
                pairs =
                    policy == MATRIX_PROJECTOR_SHIFT_CURRENT ? ((a, b), (b, a), (a, c), (c, a)) :
                    ((a, c), (c, a))
                directions =
                    require_matrix_element_pairs(directions, INTERNAL_CONNECTION_DERIVATIVES, pairs)
            end
        elseif policy == MATRIX_GEOMETRIC_SHIFT_CURRENT_FINITE_Q && tensor_indices === nothing
            # Complete-V finite-q PDSC uses raw external A and first H derivatives.
            # Other Geometric/Wilson formulas retain their own r requirements.
            push_unique_capability!(INTERNAL_CONNECTION)
            push_unique_capability!(HAMILTONIAN_DERIVATIVES)
            directions = require_matrix_element_axes(
                directions,
                INTERNAL_CONNECTION,
                1:cfg.spatial_dimension,
            )
            directions = require_matrix_element_axes(
                directions,
                HAMILTONIAN_DERIVATIVES,
                1:cfg.spatial_dimension,
            )
        elseif policy in (
            MATRIX_GEOMETRIC_SHIFT_CURRENT_Q0,
            MATRIX_GEOMETRIC_SHIFT_CURRENT_FINITE_Q,
            MATRIX_GEOMETRIC_QHC,
            MATRIX_GEOMETRIC_SHIFT_VECTOR,
            MATRIX_WILSON_SHIFT_CURRENT,
            MATRIX_WILSON_QHC,
            MATRIX_WILSON_SHIFT_VECTOR,
        )
            # Bare loop readers construct D0/r0 and their optical velocity on demand.
            # This does not select the complete-V finite-q photon-drag role.
            for kind in (HAMILTONIAN_DERIVATIVES, INTERNAL_CONNECTION)
                push_unique_capability!(kind)
                if tensor_indices !== nothing
                    _, b, c = tensor_indices
                    directions = require_matrix_element_axes(directions, kind, (b, c))
                end
            end
        else
            error("No matrix capability assembly for policy=$(policy).")
        end
    end

    if any(
        spec -> spec.quantity in (:photon_drag_injection_current, :photon_drag_shift_current),
        specs,
    )
        momenta =
            cfg.photon_momentum_path === nothing ? (cfg.photon_momentum,) :
            cfg.photon_momentum_path.photon_momenta
        if tensor_indices !== nothing &&
           any(spec -> spec.quantity == :photon_drag_shift_current, specs)
            # The unchanged p-covariant derivative also consumes raw A along its derivative axis.
            directions =
                require_matrix_element_axes(directions, INTERNAL_CONNECTION, (tensor_indices[1],))
        end
    end
    request = MatrixElementRequest(
        capabilities...;
        spatial_dimension = matrix_dimension,
        denominator_regularization = cfg.denominator_regularization,
        degeneracy_threshold = cfg.degeneracy_threshold,
    )
    # A full response requests the original response-dimensional channel set.
    # Extra raw-A channels for optical q must not enlarge response derivatives.
    tensor_indices === nothing && (directions = compile_matrix_plan(request).direction_requirements)
    if cfg.native_model_input === nothing && any(
        spec -> spec.quantity in (:photon_drag_injection_current, :photon_drag_shift_current),
        specs,
    )
        momenta =
            cfg.photon_momentum_path === nothing ? (cfg.photon_momentum,) :
            cfg.photon_momentum_path.photon_momenta
        q_axes = Tuple(d for d in 1:3 if any(q -> !iszero(q[d]), momenta))
        if !isempty(q_axes)
            directions = MatrixElements.extend_matrix_element_directions(
                directions,
                max(cfg.spatial_dimension, maximum(q_axes)),
            )
            directions = require_matrix_element_axes(directions, INTERNAL_CONNECTION, q_axes)
            push_unique_capability!(INTERNAL_CONNECTION)
        end
    end
    request = MatrixElementRequest(
        capabilities...;
        spatial_dimension = directions.spatial_dimension,
        denominator_regularization = cfg.denominator_regularization,
        degeneracy_threshold = cfg.degeneracy_threshold,
    )
    convention = normalize_wannier_center_convention(cfg.wannier_center_convention)
    return compile_matrix_plan(
        request,
        directions;
        source_gauge_required,
        wannier_center_convention = convention,
        curvature_curl_only,
        orthogonal_geometry_components = any(
            spec -> spec.quantity in BERRY_MULTIPOLE_QUANTITIES,
            specs,
        ) ? berry_multipole_geometry_components(cfg) :
                                         cfg.derivative_backend == :analytic && any(
            spec -> spec.quantity in (:berry_curvature_dipole, :berry_curvature_quadrupole),
            specs,
        ) ? (Tuple(Int.(cfg.tensor_indices)),) : (),
    )
end
