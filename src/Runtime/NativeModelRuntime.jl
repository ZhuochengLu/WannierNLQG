"""Orbital count is explicit for each admitted native backend."""
_native_orbital_count(input::Union{RealSpaceTBInput, NonorthogonalLocalizedInput}) =
    input.model.num_orbitals
"""Read the declared analytic orbital count without evaluating the model callback."""
_native_orbital_count(input::AnalyticKInput) = input.num_orbitals
"""Retain the analytic input's actual owner, without copying callback data."""
_native_input_owner(input::AnalyticKInput) = input.data_owner

"""Use the owning localized model for either real-space native wrapper."""
_native_input_owner(input::Union{RealSpaceTBInput, NonorthogonalLocalizedInput}) =
    input.model.data_owner

"""Persist the declared backend instead of inferring it from a binary fallback."""
_native_input_mode(::RealSpaceTBInput) = :native_real_space
"""Identify the admitted analytic native input in runtime provenance."""
_native_input_mode(::AnalyticKInput) = :analytic_k
"""Identify a localized metric input without conflating it with an orthogonal model."""
_native_input_mode(::NonorthogonalLocalizedInput) = :nonorthogonal_localized
"""Load the admitted backend without implicitly converting metric models to analytic models."""
_native_runtime_model(input::Union{RealSpaceTBInput, NonorthogonalLocalizedInput}) = input.model
"""Construct the analytic callback model with run-local derivative diagnostics."""
_native_runtime_model(input::AnalyticKInput) =
    AnalyticKModel(input; evaluation_diagnostics = make_analytic_derivative_diagnostics())

"""Admit only the first validated nonorthogonal scalar task scope before output creation."""
function _validate_nonorthogonal_tasks(specs, cfg)
    cfg.include_external && throw(ArgumentError("NONORTHOGONAL_EXTERNAL_METRIC_UNSUPPORTED"))
    for spec in specs
        (spec.quantity == :band_structure && spec.calculation == :kpath) ||
            (
                spec.quantity == :intrinsic_ahc &&
                spec.method == :conventional &&
                spec.calculation in (:integral, :kslice)
            ) ||
            (
                spec.quantity in (
                    :shift_current,
                    :injection_current,
                    :second_harmonic_generation,
                    :linear_optical_response,
                    :linear_transport,
                ) &&
                spec.method == :conventional &&
                spec.calculation in (:integral, :kslice)
            ) ||
            (
                spec.quantity in (
                    :interband_quantum_metric,
                    :interband_berry_curvature,
                    :berry_curvature,
                    :quantum_metric,
                    :quantum_metric_dipole,
                    :quantum_metric_quadrupole,
                    :quantum_christoffel_symbol,
                ) &&
                spec.method == :conventional &&
                spec.calculation == :kslice
            ) ||
            (
                spec.quantity == :orbital_magnetization &&
                spec.method == :conventional &&
                spec.calculation in (:integral, :kslice) &&
                cfg.orbital_input_semantics == :defined_finite_model
            ) ||
            throw(
                ArgumentError(
                    "nonorthogonal input supports intrinsic AHC Conventional Integral or KSlice, Band KPath, Conventional SC/IC/SHG and linear optical/transport Integral or KSlice, and scalar internal/ordinary metric, metric derivatives and interband metric/Berry KSlice and explicitly defined finite-model Conventional orbital Integral or KSlice",
                ),
            )
    end
    backend = lowercase(cfg.fourier_backend)
    backend in ("direct", "mixed", "auto") ||
        throw(ArgumentError("nonorthogonal Fourier backend must be direct, mixed, or auto"))
    if backend == "mixed"
        cfg.integration_bounds === nothing &&
        cfg.integration_algorithm isa UniformIntegration &&
        all(spec -> spec.calculation == :integral, specs) || throw(
            ArgumentError(
                "nonorthogonal FFT/Mixed supports uniform full-BZ Integral only; slices, paths, regions, and adaptive nodes use Direct",
            ),
        )
    end
    cfg.response_symmetry_file === nothing ||
        cfg.integration_algorithm isa HAdaptiveCubature ||
        cfg.integration_bounds !== nothing ||
        throw(
            ArgumentError(
                "nonorthogonal response symmetry requires a future metric-aware contract",
            ),
        )
    return nothing
end

"""Compile a native input using ordinary task semantics and an explicit native payload."""
function compile_native_task_config(cfg::TaskConfig, task::TaskSpec)
    input=cfg.model
    validate_native_physical_sampling(input, cfg.sampling)
    if input isa NonorthogonalLocalizedInput
        if lowercase(cfg.execution.fourier_backend) == "mixed"
            cfg.sampling isa BZMesh && cfg.execution.integration_algorithm isa UniformIntegration ||
                throw(
                    ArgumentError(
                        "nonorthogonal FFT/Mixed requires BZMesh with UniformIntegration; other sampling uses Direct",
                    ),
                )
        end
    end
    if input isa AnalyticKInput
        lowercase(cfg.execution.fourier_backend) in ("direct", "auto") || throw(
            ArgumentError(
                "analytic callbacks have no real-space Fourier coefficients; Direct evaluation is available",
            ),
        )
        input.periodic ||
            cfg.sampling isa KRegion ||
            cfg.sampling isa Union{KSlice, KPath} ||
            throw(ArgumentError("nonperiodic analytic integration requires KRegion"))
    end
    # This marker is never opened: native context and loading dispatch on the payload.
    declared=ModelInput(
        model_file = "native-model",
        wannier_center_convention = input.wannier_center_convention,
        real_space_replica_policy = "input",
    )
    lowered=TaskConfig(
        model = declared,
        sampling = cfg.sampling,
        tasks = cfg.tasks,
        execution = cfg.execution,
        output = cfg.output,
    )
    effective=compile_task_config(lowered, task; native_model_input = input)
    if native_physical_dimension(input) < 3
        d = native_physical_dimension(input)
        all(iszero, effective.photon_momentum[(d + 1):3]) ||
            throw(ArgumentError("photon momentum leaves the direct model's physical axes"))
        path = effective.photon_momentum_path
        path === nothing ||
            all(iszero(group.photon_momentum[a]) for group in path.groups for a in (d + 1):3) ||
            throw(ArgumentError("paired photon momentum leaves the direct model's physical axes"))
    end
    input isa NonorthogonalLocalizedInput &&
        _validate_nonorthogonal_tasks(normalize_task_specs(effective), effective)
    if any(s->s.quantity==:orbital_magnetization, normalize_task_specs(effective))
        effective.orbital_input_semantics==:defined_finite_model || throw(
            ArgumentError(
                "native orbital response requires explicit defined_finite_model semantics",
            ),
        )
    end
    return effective
end

"""Keep new low-dimensional models on their actual physical sampling subspace."""
function validate_native_physical_sampling(input, sampling)
    d = native_physical_dimension(input)
    d == 3 && return nothing
    if sampling isa BZMesh
        length(sampling.k_mesh) == d || throw(
            ArgumentError(
                "direct $d-dimensional model requires $d physical BZ mesh counts; auxiliary directions are not sampled",
            ),
        )
    elseif sampling isa KRegion
        sampling.spatial_dimension == d || throw(
            ArgumentError(
                "KRegion dimension must match the direct model's $d physical momentum axes",
            ),
        )
        region = sampling.affine_region
        region === nothing ||
            all(
                iszero(value[a]) for value in (region.origin, region.vectors...) for a in (d + 1):3
            ) ||
            throw(
                ArgumentError("direct low-dimensional regions must stay on standard physical axes"),
            )
    elseif sampling isa KSlice
        d == 2 || throw(
            ArgumentError(
                "KSlice is a planar consumer; a direct one-dimensional model uses a physical path or Integral sampling",
            ),
        )
        all(
            iszero(value[a]) for value in (sampling.origin, sampling.vector_1, sampling.vector_2)
            for a in (d + 1):3
        ) || throw(ArgumentError("slice leaves the direct model's physical plane"))
    elseif sampling isa KPath
        all(iszero(node[2][a]) for node in sampling.nodes for a in (d + 1):3) ||
            throw(ArgumentError("path leaves the direct model's physical momentum axes"))
    end
    return nothing
end

# Check complete-geometry operator declarations without invoking analytic callbacks.
function validate_native_full_geometry_inputs(input, specs; include_external = true)
    include_external || return nothing
    input isa NonorthogonalLocalizedInput &&
        throw(ArgumentError("NONORTHOGONAL_EXTERNAL_METRIC_UNSUPPORTED"))
    if any(
        spec -> spec.quantity in (
            :quantum_metric,
            :quantum_metric_dipole,
            :quantum_metric_quadrupole,
            :quantum_christoffel_symbol,
        ),
        specs,
    )
        key = input isa RealSpaceTBInput ? :derivative_overlap_r : :derivative_overlap
        haskey(input.operators, key) || throw(
            ArgumentError(
                "QUANTUM_METRIC_FULL_DERIVATIVE_OVERLAP_REQUIRED: native input must explicitly supply $(key)",
            ),
        )
    end
    return nothing
end

const NATIVE_DEFINITION_COMPARISON_CHUNK_BYTES = 65536

"""Agree on complete native definition bytes before any output directory exists.

Each rank streams its owned input once. Metadata readiness, equal byte counts,
all bounded byte chunks, final owner/source lifetime and scratch release are
collective phases. A non-root read error is retained until every rank completes
the same chunk schedule. Local owner labels never decide cross-rank equality.
The root owner generation is returned for descriptive output metadata only,
never as the content-agreement oracle.
"""
function _native_collective_definition_admission(input, admission, comm)
    rank = bundle_mpi_comm_rank(comm)
    ranks = bundle_mpi_comm_size(comm)
    definition = nothing
    try
        packet = try
            definition = native_model_definition_stream(input)
            _validate_native_input_admission(input, admission)
            (;
                ok = true,
                byte_count = definition.byte_count,
                model_generation = admission.model_generation,
                error = "",
            )
        catch exception
            (;
                ok = false,
                byte_count = 0,
                model_generation = nothing,
                error = sprint(showerror, exception),
            )
        end
        byte_count = 0
        binding = ""
        for owner in 0:(ranks - 1)
            received = bundle_mpi_bcast(rank == owner ? packet : nothing, owner, comm)
            received.ok || error(
                "native model definition preparation failed on rank $owner: $(received.error)",
            )
            if owner == 0
                byte_count = received.byte_count
                binding = received.model_generation
            else
                received.byte_count == byte_count ||
                    error("native model identity differs across MPI ranks: definition length")
            end
        end
        matches = true
        local_error = ""
        for offset in 0:NATIVE_DEFINITION_COMPARISON_CHUNK_BYTES:(byte_count - 1)
            count = min(NATIVE_DEFINITION_COMPARISON_CHUNK_BYTES, byte_count - offset)
            bytes = try
                read(definition, count)
            catch exception
                isempty(local_error) && (local_error = sprint(showerror, exception))
                UInt8[]
            end
            packet =
                rank == 0 ?
                (;
                    ok = length(bytes) == count && isempty(local_error),
                    bytes,
                    error = isempty(local_error) ? "incomplete root definition chunk" : local_error,
                ) : nothing
            reference = bundle_mpi_bcast(packet, 0, comm)
            reference.ok || error("native model definition root read failed: $(reference.error)")
            matches &= length(bytes) == count && bytes == reference.bytes
        end
        packet = try
            _validate_native_input_admission(input, admission)
            complete = eof(definition)
            (;
                ok = matches && complete && isempty(local_error),
                error = isempty(local_error) ?
                        "native model identity differs across MPI ranks: definition bytes" :
                        local_error,
            )
        catch exception
            (; ok = false, error = sprint(showerror, exception))
        end
        for owner in 0:(ranks - 1)
            received = bundle_mpi_bcast(rank == owner ? packet : nothing, owner, comm)
            received.ok ||
                error("native model definition agreement failed on rank $owner: $(received.error)")
        end
        packet = try
            close(definition)
            definition = nothing
            (; ok = true, error = "")
        catch exception
            (; ok = false, error = sprint(showerror, exception))
        end
        for owner in 0:(ranks - 1)
            received = bundle_mpi_bcast(rank == owner ? packet : nothing, owner, comm)
            received.ok ||
                error("native model definition release failed on rank $owner: $(received.error)")
        end
        return binding
    finally
        if definition !== nothing
            try
                close(definition; retain = true)
            catch exception
                # Admission has already failed collectively; keep its original error.
                @warn "Failed native definition scratch retained; close failed" path =
                    definition.path exception
            end
        end
    end
end

"""Create output context from a native model without imposing first-principles file provenance."""
function prepare_native_run_context(cfg::EffectiveTaskConfig, specs)
    input=cfg.native_model_input
    count = 0
    demand = nothing
    # Rank-local input failures must enter the same collective before output creation.
    admission = nothing
    preconditions_done = false
    early_exception = nothing
    packet = try
        count = _native_orbital_count(input)
        input isa NonorthogonalLocalizedInput && _validate_nonorthogonal_tasks(specs, cfg)
        demand = operator_demand_plan(specs, cfg)
        validate_native_full_geometry_inputs(input, specs; include_external = cfg.include_external)
        preconditions_done = true
        admission = NativeInputAdmission(
            _native_input_owner(input),
            scientific_data_generation(input),
            native_source_file_identity(input),
        )
        native_matrix_sources(input, demand)
        if input isa AnalyticKInput
            plan=bundle_matrix_element_plan(specs, cfg, collect(cfg.tensor_indices))
            order=has_capability(plan, HAMILTONIAN_SECOND_DERIVATIVES) ? 2 :
                  has_capability(plan, HAMILTONIAN_DERIVATIVES) ? 1 : 0
            validate_analytic_model(input; max_order = order)
        end
        _validate_native_input_admission(input, admission)
        (ok = true, error = "")
    catch exception
        preconditions_done || (early_exception = exception)
        (ok = false, error = sprint(showerror, exception))
    end
    comm = bundle_mpi_comm_world()
    rank = bundle_mpi_comm_rank(comm)
    for source_rank in 0:(bundle_mpi_comm_size(comm) - 1)
        received = bundle_mpi_bcast(rank==source_rank ? packet : nothing, source_rank, comm)
        if !received.ok
            # Preserve the established serial exception for pre-context validation.
            bundle_mpi_comm_size(comm) == 1 && early_exception !== nothing && throw(early_exception)
            error("native model preflight failed on rank $source_rank: $(received.error)")
        end
    end
    model_identity = _native_collective_definition_admission(input, admission, comm)
    run_dir=resolve_path(
        cfg.output_root,
        default_output_root(resolve_case_root(cfg.case_root));
        base = resolve_case_root(cfg.case_root),
    )
    mpi_is_root_process() && mkpath(run_dir)
    progress=cfg.progress_enabled
    return RunContext(
        specs,
        run_dir,
        input.source_file,
        model_identity,
        _native_input_mode(input),
        nothing,
        nothing,
        count,
        demand,
        something(cfg.system_name, "Model"),
        joinpath(run_dir, "metadata.txt"),
        progress ? joinpath(run_dir, "WannierNLQG.out") : "",
        progress ? joinpath(run_dir, "progress.jsonl") : "",
        nothing,
        admission,
    )
end

"""Reject replacement, retirement or changed source after local native admission.

The model and operators are adopted read-only data. Supported replacement retires
that owner and requires a new context. MPI equality remains a separate preflight.
"""
function _validate_native_input_admission(input, admission::Union{Nothing, NativeInputAdmission})
    admission === nothing && throw(ArgumentError("NATIVE_INPUT_ADMISSION_REQUIRED"))
    _native_input_owner(input) === admission.owner ||
        throw(ArgumentError("NATIVE_INPUT_OWNER_CHANGED_AFTER_PREFLIGHT"))
    scientific_data_generation(input) == admission.model_generation ||
        throw(ArgumentError("NATIVE_INPUT_OWNER_CHANGED_AFTER_PREFLIGHT"))
    isequal(native_source_file_identity(input), admission.source_identity) ||
        throw(ArgumentError("NATIVE_INPUT_SOURCE_CHANGED_AFTER_PREFLIGHT"))
    return nothing
end

"""Load admitted owned data; pure callbacks remain rank-local and are never serialized."""
function load_native_runtime_sources(ctx, cfg)
    input=cfg.native_model_input
    _validate_native_input_admission(input, ctx.native_admission)
    model=_native_runtime_model(input)
    sources=native_matrix_sources(input, ctx.operator_demand)
    _validate_native_input_admission(input, ctx.native_admission)
    nr=model.num_r_vectors
    replica=RuntimeReplicaSummary(
        :input,
        :input,
        :native_model,
        nothing,
        nothing,
        nothing,
        nothing,
        nothing,
        cfg.wigner_seitz_tolerance,
        cfg.wigner_seitz_search_size,
        nothing,
        false,
        false,
        nr,
        nr,
        false,
        false,
        (
            schema = "wanniernlqg.native-input-support/1",
            model_generation = scientific_data_generation(input),
            input_mode = _native_input_mode(input),
            num_orbitals = model.num_orbitals,
            num_r_vectors = nr,
        ),
    )
    return (
        model = model,
        spin = sources.spin,
        spin_velocity = sources.spin_velocity,
        orbital = nothing,
        derivative_overlap = sources.derivative_overlap,
        manifest = nothing,
        read_mode = :native_model,
        fallback_reason = nothing,
        storage_owner = nothing,
        replica_summary = replica,
    )
end

"""Native models define a finite Hilbert space; material production qualification is separate."""
function native_response_qualification(cfg, ctx)
    return ResponseQualificationResult(
        true,
        "COMPUTATION_READY",
        false,
        false,
        String[],
        [
            "input.structure",
            "input.required_operators",
            cfg.native_model_input isa NonorthogonalLocalizedInput ?
            "input.nonorthogonal_finite_model" : "input.orthogonal_finite_model",
        ],
        ["material.production_qualification"],
        String[],
        Dict("input_mode"=>String(ctx.model_input_mode), "model_identity"=>ctx.model_identity),
    )
end

"""Model periodicity is independent of the user-selected integration domain."""
integration_model_periodic(
    cfg,
)=!(cfg.native_model_input isa AnalyticKInput) || cfg.native_model_input.periodic

# Old complete3x3 model semantics are untouched; only constructor-derived lowD inputs opt in.
native_direct_low_dimensional(cfg) = native_physical_dimension(cfg.native_model_input) < 3

# Reference-cell normalization and actual periodicity are independent properties.
integration_uses_reference_cell(cfg) =
    integration_model_periodic(cfg) || native_direct_low_dimensional(cfg)

# Fixed bulk output units apply to new direct lowD coefficients, not their integration dimension.
integration_output_dimension(cfg) =
    integration_uses_reference_cell(cfg) ? 3 : integration_dimension(cfg)

"""Expose affine geometry and its physical node weight without changing box metadata."""
function integration_affine_region_metadata(cfg)
    region = cfg.integration_affine_region
    region === nothing && return (;)
    common = (;
        integration_geometry = affine_dimension(region) == 2 ? "Cartesian parallelogram" :
                               "Cartesian parallelepiped",
        integration_origin_A_inverse = region.origin,
        integration_vector_1_A_inverse = region.vector_1,
        integration_vector_2_A_inverse = region.vector_2,
        integration_cartesian_dimension = region.cartesian_dimension,
        integration_grid = cfg.integration_algorithm isa UniformIntegration &&
                           cfg.integration_algorithm.region_quadrature == :left_endpoint ?
                           "uniform parameter left endpoints i/N; first parameter varies fastest; no folding" :
                           "uniform parameter midpoints; first parameter varies fastest; no folding",
        integration_samples = prod(cfg.k_mesh),
    )
    dimensional =
        affine_dimension(region) == 2 ?
        (;
            integration_area_A_inverse_squared = region.measure,
            integration_point_weight_A_inverse_squared = region.measure/prod(cfg.k_mesh),
            integration_bounds_role = "enclosing box only; area comes from vector cross product",
        ) :
        (;
            integration_vector_3_A_inverse = region.vector_3,
            integration_volume_A_inverse_cubed = region.measure,
            integration_point_weight_A_inverse_cubed = region.measure/prod(cfg.k_mesh),
            integration_bounds_role = "enclosing box only; volume comes from absolute basis determinant",
        )
    return merge(common, dimensional)
end

"""Record finite-domain assumptions without changing ordinary execution eligibility."""
function integration_domain_metadata(cfg)
    periodic=integration_model_periodic(cfg)
    return merge(
        (;
            integration_bounds = cfg.integration_bounds,
            integration_dimension = cfg.integration_bounds===nothing ? length(cfg.k_mesh) :
                                    integration_dimension(cfg),
            model_periodic = periodic,
            integration_measure = cfg.integration_bounds===nothing ? "fractional full-BZ average" :
                                  native_direct_low_dimensional(cfg) ?
                                  "physical d^dk/(2pi)^d divided by the one-Angstrom reference transverse measure; no auxiliary integration" :
                                  periodic ?
                                  "Cartesian unfolded region; original BZ fraction with original-cell prefactor" :
                                  "d^dk/(2pi)^d",
            boundary_corrections = "not included for finite-domain formulas derived under periodic-BZ assumptions",
        ),
        integration_affine_region_metadata(cfg),
        cfg.integration_bounds !== nothing &&
        cfg.integration_algorithm isa UniformIntegration &&
        cfg.integration_algorithm.region_quadrature == :left_endpoint ?
        (integration_region_quadrature = "left_endpoint",) : (;),
    )
end

"""Finite regions are ordinary calculations; users assess boundary and truncation contributions."""
function warn_integration_domain(cfg)
    if cfg.integration_bounds!==nothing || !integration_model_periodic(cfg)
        @warn "Finite-domain response: actual domain and model periodicity are recorded. Formulas derived under periodic-BZ/integration-by-parts assumptions include no finite-boundary correction; assess truncation and contributions outside the domain. Cartesian regions are unfolded and may repeat periodic contributions across Brillouin zones." domain=integration_domain_metadata(
            cfg,
        )
    end
    if cfg.response_symmetry_file!==nothing &&
       (cfg.integration_bounds!==nothing || cfg.integration_algorithm isa HAdaptiveCubature)
        @warn "This integration evaluates the full supplied domain; the provided symmetry artifact does not reduce nodes or supply area weights."
    end
    return nothing
end

"""Select the existing periodic grid or explicitly bounded Cartesian quadrature."""
function _integral_k_grid(cfg::EffectiveTaskConfig, model)
    rule =
        cfg.integration_algorithm isa UniformIntegration ?
        cfg.integration_algorithm.region_quadrature : :midpoint
    cfg.integration_affine_region === nothing ||
        return CartesianAffineGrid(cfg.integration_affine_region, cfg.k_mesh, model.lattice, rule)
    cfg.integration_bounds === nothing && return _integral_k_grid(cfg.k_mesh)
    lower, upper=cfg.integration_bounds
    counts=ntuple(axis -> axis <= length(cfg.k_mesh) ? cfg.k_mesh[axis] : 1, 3)
    return CartesianRegionGrid(
        lower,
        upper,
        counts,
        count(a->upper[a]>lower[a], 1:3),
        model.lattice,
        rule,
    )
end

"""
Return the inverse quadrature density in the historical cubic-Angstrom scale.

For a d-dimensional box the SI inverse density is `(2pi)^d / volume_k * 1e-10^d`.
The scale conversion below lets unchanged response prefactors consume this measure.
"""
function integration_cell_measure(cfg::EffectiveTaskConfig, model)
    cfg.integration_bounds === nothing && return det(model.lattice)
    lower, upper=cfg.integration_bounds;
    d=integration_dimension(cfg)
    volume_k=cfg.integration_affine_region === nothing ? prod(upper[a]-lower[a] for a in 1:d) :
             cfg.integration_affine_region.measure
    if integration_uses_reference_cell(cfg)
        reciprocal=reciprocal_lattice(model.lattice)
        bz_measure=d==1 ? norm(reciprocal[1, :]) :
                   d==2 ? norm(cross(reciprocal[1, :], reciprocal[2, :])) : abs(det(reciprocal))
        return abs(det(model.lattice))*bz_measure/volume_k
    end
    return (2pi)^d/volume_k * 10.0^(10*(3-d))
end

"""Number of active Cartesian integration axes, distinct from tensor rank."""
function integration_dimension(cfg::EffectiveTaskConfig)
    cfg.integration_affine_region === nothing ||
        return affine_dimension(cfg.integration_affine_region)
    cfg.integration_bounds === nothing && return native_physical_dimension(cfg.native_model_input)
    lo, hi = cfg.integration_bounds
    return count(a -> hi[a] > lo[a], 1:3)
end

"""Unit of a Cartesian-region observable relative to the historical bulk unit."""
function integration_unit(cfg::EffectiveTaskConfig, bulk::AbstractString)
    d = integration_output_dimension(cfg)
    return d == 3 ? String(bulk) : string("(", bulk, ")*m^", 3-d)
end

"""Collect run-local derivative evidence in rank order; all ranks participate."""
function persist_native_derivative_records(model::AnalyticKModel, run_dir)
    diagnostics=model.evaluation_diagnostics
    local_records=diagnostics === nothing ? Dict{Int, NamedTuple}() :
                  merge_analytic_derivative_diagnostics(diagnostics)
    comm=bundle_mpi_comm_world()
    rank=bundle_mpi_comm_rank(comm)
    records=[
        bundle_mpi_bcast(rank==source ? local_records : nothing, source, comm) for
        source in 0:(bundle_mpi_comm_size(comm) - 1)
    ]
    merged=merge_analytic_derivative_diagnostics(records)
    mpi_is_root_process() &&
        write_native_derivative_records(joinpath(run_dir, "native_derivatives.tsv"), merged)
    return nothing
end
"""File and native hopping models do not use analytic derivative diagnostics."""
persist_native_derivative_records(model, run_dir)=nothing
