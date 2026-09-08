# Return all Cartesian components of a rank-one operator.
function _all_rank_one_components()
    return NTuple{2, Int8}[(Int8(axis), Int8(0)) for axis in 1:3]
end

# Return all lexicographically ordered components of a rank-two operator.
function _all_rank_two_components()
    return NTuple{2, Int8}[(Int8(first), Int8(second)) for first in 1:3 for second in 1:3]
end

# Select required rank-one components from a compiled matrix-element plan.
function _required_rank_one_components(matrix_plan, kind::MatrixElementKind, integral::Bool)
    integral && return _all_rank_one_components()
    return NTuple{2, Int8}[
        (Int8(axis), Int8(0)) for
        axis in 1:3 if matrix_element_axis_required(matrix_plan, kind, axis)
    ]
end

# Select required rank-two components from a compiled matrix-element plan.
function _required_rank_two_components(matrix_plan, kind::MatrixElementKind, integral::Bool)
    integral && return _all_rank_two_components()
    return NTuple{2, Int8}[
        (Int8(first), Int8(second)) for first in 1:3 for
        second in 1:3 if matrix_element_pair_required(matrix_plan, kind, first, second)
    ]
end

"""Compile the real-space operator dependency closure for one normalized bundle."""
function operator_demand_plan(specs::Vector{NormalizedTaskSpec}, cfg::EffectiveTaskConfig)
    integral = all(spec -> spec.calculation == :integral, specs)
    band_structure = all(
        spec -> begin
            definition = task_definition(spec.quantity, spec.method, spec.calculation)
            definition !== nothing && definition.executor == EXECUTOR_BAND_STRUCTURE
        end,
        specs,
    )
    tensor_indices = if integral || band_structure
        nothing
    else
        _normalized_run_controls(cfg, specs).tensor_indices
    end
    matrix_plan = bundle_matrix_element_plan(specs, cfg, tensor_indices)
    requires_full_projector_geometry = any(specs) do spec
        definition = task_definition(spec.quantity, spec.method, spec.calculation)
        definition !== nothing &&
            definition.matrix_policy in (MATRIX_PROJECTOR_SHIFT_CURRENT, MATRIX_PROJECTOR_QHC)
    end
    required = RealSpaceOperatorKind[REAL_SPACE_HAMILTONIAN, REAL_SPACE_POSITION]
    components = Dict{RealSpaceOperatorKind, Vector{NTuple{2, Int8}}}(
        REAL_SPACE_HAMILTONIAN => [(Int8(0), Int8(0))],
        REAL_SPACE_POSITION => _all_rank_one_components(),
    )
    # Runtime center provenance and Convention I assembly both read the three
    # Cartesian home-cell centers. Packed/MPI inputs must therefore retain every
    # position component even for a one-component K-slice response request.

    if has_capability(matrix_plan, SPIN)
        push!(required, REAL_SPACE_SPIN)
        components[REAL_SPACE_SPIN] = _required_rank_one_components(matrix_plan, SPIN, integral)
    end
    needs_spin_velocity = any(
        kind -> has_capability(matrix_plan, kind),
        (
            SPIN_TIMES_HAMILTONIAN,
            SPIN_TIMES_POSITION,
            SPIN_TIMES_HAMILTONIAN_POSITION,
            SPIN_VELOCITY,
        ),
    )
    if needs_spin_velocity
        for kind in (
            REAL_SPACE_SPIN,
            REAL_SPACE_SPIN_TIMES_HAMILTONIAN,
            REAL_SPACE_SPIN_TIMES_POSITION,
            REAL_SPACE_SPIN_TIMES_HAMILTONIAN_POSITION,
        )
            kind in required || push!(required, kind)
        end
        components[REAL_SPACE_SPIN] = _required_rank_one_components(matrix_plan, SPIN, integral)
        components[REAL_SPACE_SPIN_TIMES_HAMILTONIAN] =
            _required_rank_one_components(matrix_plan, SPIN_TIMES_HAMILTONIAN, integral)
        components[REAL_SPACE_SPIN_TIMES_POSITION] =
            _required_rank_two_components(matrix_plan, SPIN_TIMES_POSITION, integral)
        components[REAL_SPACE_SPIN_TIMES_HAMILTONIAN_POSITION] =
            _required_rank_two_components(matrix_plan, SPIN_TIMES_HAMILTONIAN_POSITION, integral)
    end
    if requires_full_projector_geometry
        push!(required, REAL_SPACE_DERIVATIVE_OVERLAP_TENSOR)
        components[REAL_SPACE_DERIVATIVE_OVERLAP_TENSOR] = if integral || band_structure
            _all_rank_two_components()
        else
            selected = Set{NTuple{2, Int8}}()
            a, b, c = something(tensor_indices)
            for spec in specs
                definition = task_definition(spec.quantity, spec.method, spec.calculation)
                definition === nothing && continue
                pairs =
                    definition.matrix_policy == MATRIX_PROJECTOR_SHIFT_CURRENT ?
                    ((a, b), (b, a), (a, c), (c, a)) :
                    definition.matrix_policy == MATRIX_PROJECTOR_QHC ? ((a, c), (c, a)) : ()
                for (first, second) in pairs
                    push!(selected, (Int8(first), Int8(second)))
                end
            end
            sort!(collect(selected))
        end
    end
    for kind in required
        isempty(get(components, kind, NTuple{2, Int8}[])) && throw(
            ArgumentError(
                "matrix-element plan produced no Cartesian component for $(real_space_operator_name(kind))",
            ),
        )
    end
    return OperatorDemandPlan(
        canonical_operator_inventory(required),
        components,
        requires_full_projector_geometry,
    )
end

"""Validate an operator and component dependency closure against one manifest."""
function validate_operator_demand(manifest::OperatorBundleManifest, demand::OperatorDemandPlan)
    if demand.requires_full_projector_geometry
        manifest.schema_version in ("6.0", "6.1", "6.2", "6.3", "1.0") || throw(
            ArgumentError(
                "PROJECTOR_FULL_DERIVATIVE_OVERLAP_REQUIRED: public schema 1.0 or legacy 6.x exact-uIu provenance is required",
            ),
        )
        manifest.derivative_overlap_completeness == "full_hilbert_space" || throw(
            ArgumentError(
                "PROJECTOR_FULL_DERIVATIVE_OVERLAP_REQUIRED: derivative overlap is " *
                "$(manifest.derivative_overlap_completeness), not full_hilbert_space",
            ),
        )
        manifest.derivative_overlap_source == "wannier90_uIu" || throw(
            ArgumentError(
                "PROJECTOR_FULL_DERIVATIVE_OVERLAP_REQUIRED: source must be wannier90_uIu",
            ),
        )
        manifest.derivative_overlap_source_sha256 === nothing && throw(
            ArgumentError("PROJECTOR_FULL_DERIVATIVE_OVERLAP_REQUIRED: uIu SHA-256 is absent"),
        )
        occursin(r"^[0-9a-f]{64}$", something(manifest.derivative_overlap_source_sha256)) || throw(
            ArgumentError(
                "PROJECTOR_FULL_DERIVATIVE_OVERLAP_REQUIRED: uIu SHA-256 is not lowercase hexadecimal",
            ),
        )
        manifest.derivative_overlap_algorithm_version ==
        FULL_DERIVATIVE_OVERLAP_ALGORITHM_VERSION || throw(
            ArgumentError(
                "PROJECTOR_FULL_DERIVATIVE_OVERLAP_REQUIRED: unsupported derivative-overlap algorithm " *
                manifest.derivative_overlap_algorithm_version,
            ),
        )
    end
    missing = [kind for kind in demand.required_operators if kind ∉ manifest.inventory]
    isempty(missing) || throw(
        ArgumentError(
            "Current task requires: " *
            join(real_space_operator_name.(missing), ", ") *
            ". Current bundle profile: $(manifest.profile). Regenerate the required schema-6 profile from its qualified source files.",
        ),
    )
    stored = Dict{RealSpaceOperatorKind, Set{NTuple{2, Int8}}}()
    for entry in manifest.entries
        push!(get!(() -> Set{NTuple{2, Int8}}(), stored, entry.kind), entry.component_indices)
    end
    for kind in demand.required_operators
        requested = Set(demand.required_components[kind])
        requested ⊆ get(stored, kind, Set{NTuple{2, Int8}}()) || throw(
            ArgumentError(
                "Bundle is missing required Cartesian components for $(real_space_operator_name(kind)).",
            ),
        )
    end
    any(
            kind -> kind in demand.required_operators,
            (
                REAL_SPACE_SPIN_TIMES_HAMILTONIAN,
                REAL_SPACE_SPIN_TIMES_POSITION,
                REAL_SPACE_SPIN_TIMES_HAMILTONIAN_POSITION,
            ),
        ) &&
        manifest.profile != :full &&
        throw(
            ArgumentError(
                "Injection/shift spin current requires a formal schema-6 full bundle. Current bundle profile: $(manifest.profile). Regenerate with qualified SPN/uIu/uHu/sIu/sHu provenance.",
            ),
        )
    return manifest
end

# Build one demanded logical operator from loaded component ranges.
function _packed_operator(loaded, kind::RealSpaceOperatorKind, rank::Int)
    haskey(loaded.components, kind) ||
        throw(ArgumentError("required operator $(real_space_operator_name(kind)) was not loaded"))
    return PackedCartesianOperator(
        rank,
        loaded.components[kind],
        (
            loaded.manifest.num_orbitals,
            loaded.manifest.num_orbitals,
            size(loaded.manifest.r_vectors, 2),
        ),
    )
end

"""Own MPI shared windows and communicators backing runtime component views."""
mutable struct MPISharedOperatorStorage
    windows::Vector{Any}
    node_comm::Any
    leader_comm::Any
    released::Bool
end

const ACTIVE_MPI_SHARED_OPERATOR_STORAGES = MPISharedOperatorStorage[]

# Register shared storage so run-finalization can clean it after an exception.
function _register_mpi_shared_operator_storage!(windows, node_comm, leader_comm)
    owner = MPISharedOperatorStorage(windows, node_comm, leader_comm, false)
    push!(ACTIVE_MPI_SHARED_OPERATOR_STORAGES, owner)
    return owner
end

# Report whether the public shared-window lifecycle used below is available.
function _mpi_shared_window_available()
    return all(
        name -> isdefined(MPI, name),
        (:Win_allocate_shared, :Win_lock, :Win_unlock, :Win_sync, :Win_shared_query),
    )
end

# Open the passive-target epoch required by MPI_Win_sync for shared windows.
function _mpi_lock_shared_window!(window)
    Base.invokelatest(_mpi_binding(:Win_lock), window; rank = 0, type = :shared, nocheck = true)
    return window
end

# Close the passive-target epoch before freeing its shared window.
function _mpi_unlock_shared_window!(window)
    Base.invokelatest(_mpi_binding(:Win_unlock), window; rank = 0)
    return nothing
end

# Allocate one shared window and leave its passive-target epoch open for readers.
function _mpi_allocate_locked_shared_window(array_type, dimensions, node_comm)
    window, local_values =
        Base.invokelatest(_mpi_binding(:Win_allocate_shared), array_type, dimensions, node_comm)
    _mpi_lock_shared_window!(window)
    return window, local_values
end

# Publish local stores before the barrier, then synchronize every reader after it.
function _mpi_publish_shared_window!(window, node_comm)
    Base.invokelatest(_mpi_binding(:Win_sync), window)
    Base.invokelatest(_mpi_binding(:Barrier), node_comm)
    Base.invokelatest(_mpi_binding(:Win_sync), window)
    return nothing
end

# Construct a TB model from selected Hamiltonian and full position components.
function _runtime_component_model(components, lattice, num_orbitals, r_vectors, degeneracies)
    loaded_stub =
        (components = components, manifest = (num_orbitals = num_orbitals, r_vectors = r_vectors))
    return TightBindingModel(
        lattice,
        num_orbitals,
        size(r_vectors, 2),
        degeneracies,
        r_vectors,
        components[REAL_SPACE_HAMILTONIAN][(Int8(0), Int8(0))],
        _packed_operator(loaded_stub, REAL_SPACE_POSITION, 1);
        copy_data = false,
    )
end

# Describe prepared component ranges independently of serialized manifest shapes.
function _runtime_component_entries(components)
    entries = NamedTuple[]
    for kind in sort!(collect(keys(components)); by = Int)
        for component in sort!(collect(keys(components[kind])))
            values = components[kind][component]
            push!(
                entries,
                (
                    kind = kind,
                    component_indices = component,
                    length_elements = length(values),
                    logical_shape = size(values),
                ),
            )
        end
    end
    return entries
end

# Materialize selected HDF5 component ranges before any MPI distribution.
function _prepare_hdf5_component_load(loaded, ctx::RunContext, cfg::EffectiveTaskConfig)
    validate_operator_demand(loaded.manifest, ctx.operator_demand)
    manifest = loaded.manifest
    input_model = _runtime_component_model(
        loaded.components,
        manifest.lattice,
        manifest.num_orbitals,
        manifest.r_vectors,
        manifest.degeneracies,
    )
    prepared = prepare_runtime_components(cfg, ctx, loaded.components, input_model, manifest)
    return merge(
        loaded,
        (
            components = prepared.components,
            runtime_r_vectors = prepared.r_vectors,
            runtime_degeneracies = prepared.degeneracies,
            replica_plan = prepared.plan,
            replica_summary = prepared.summary,
        ),
    )
end

# Read and prepare selected HDF5 ranges on global rank zero and capture failures.
function _mpi_component_load_packet(bundle, demand, rank, ctx::RunContext, cfg::EffectiveTaskConfig)
    rank != 0 && return nothing, nothing
    try
        raw =
            read_operator_bundle_components(bundle, demand.required_components; prefer_mmap = false)
        loaded = _prepare_hdf5_component_load(raw, ctx, cfg)
        return loaded,
        (
            ok = true,
            manifest = loaded.manifest,
            entries = _runtime_component_entries(loaded.components),
            runtime_r_vectors = loaded.runtime_r_vectors,
            runtime_degeneracies = loaded.runtime_degeneracies,
            replica_summary = loaded.replica_summary,
            error = "",
        )
    catch exception
        return nothing,
        (
            ok = false,
            manifest = nothing,
            entries = NamedTuple[],
            runtime_r_vectors = zeros(Int, 3, 0),
            runtime_degeneracies = Int[],
            replica_summary = nothing,
            error = sprint(showerror, exception, catch_backtrace()),
        )
    end
end

# Broadcast selected ranges into one private allocation per MPI rank.
function _mpi_rank_private_components(root_loaded, packet, demand, comm, rank)
    components = Dict{RealSpaceOperatorKind, Dict{NTuple{2, Int8}, AbstractArray{ComplexF64, 3}}}()
    for entry in packet.entries
        values = Vector{ComplexF64}(undef, Int(entry.length_elements))
        if rank == 0
            copyto!(values, vec(root_loaded.components[entry.kind][entry.component_indices]))
        end
        Base.invokelatest(_mpi_binding(:Bcast!), values, 0, comm)
        get!(() -> Dict{NTuple{2, Int8}, AbstractArray{ComplexF64, 3}}(), components, entry.kind)[entry.component_indices] =
            reshape(values, entry.logical_shape)
    end
    runtime_notice(
        "MPI operator distribution read_mode=rank_private_fallback; operator memory scales with ranks",
    )
    return (
        manifest = packet.manifest,
        components = components,
        runtime_r_vectors = packet.runtime_r_vectors,
        runtime_degeneracies = packet.runtime_degeneracies,
        replica_summary = packet.replica_summary,
        read_mode = :mpi_rank_private,
        fallback_reason = "node-shared windows disabled or unavailable",
        payload_owner = nothing,
    )
end

# Distribute root-read bundle ranges into one shared allocation per node.
function _mpi_node_shared_bundle_components(
    bundle,
    demand::OperatorDemandPlan,
    ctx::RunContext,
    cfg::EffectiveTaskConfig,
)
    comm = bundle_mpi_comm_world()
    rank = bundle_mpi_comm_rank(comm)
    root_loaded, root_packet = _mpi_component_load_packet(bundle, demand, rank, ctx, cfg)
    packet = bundle_mpi_bcast(root_packet, 0, comm)
    packet.ok || error("global root HDF5 read failed:\n$(packet.error)")
    validate_operator_demand(packet.manifest, demand)
    shared_disabled =
        mpi_env_truthy("WANNIERNLQG_DISABLE_MPI_SHARED") || !_mpi_shared_window_available()
    shared_disabled && return _mpi_rank_private_components(root_loaded, packet, demand, comm, rank)

    node_comm = Base.invokelatest(
        _mpi_binding(:Comm_split_type),
        comm,
        _mpi_binding(:COMM_TYPE_SHARED),
        rank,
    )
    node_rank = Base.invokelatest(_mpi_binding(:Comm_rank), node_comm)
    leader_comm =
        Base.invokelatest(_mpi_binding(:Comm_split), comm, node_rank == 0 ? 0 : nothing, rank)
    windows = Any[]
    components = Dict{RealSpaceOperatorKind, Dict{NTuple{2, Int8}, AbstractArray{ComplexF64, 3}}}()
    for entry in packet.entries
        local_length = node_rank == 0 ? Int(entry.length_elements) : 0
        win, local_values =
            _mpi_allocate_locked_shared_window(Array{ComplexF64}, local_length, node_comm)
        push!(windows, win)
        if node_rank == 0
            if rank == 0
                copyto!(
                    local_values,
                    vec(root_loaded.components[entry.kind][entry.component_indices]),
                )
            end
            Base.invokelatest(_mpi_binding(:Bcast!), local_values, 0, leader_comm)
        end
        shared_values = if node_rank == 0
            local_values
        else
            Base.invokelatest(
                _mpi_binding(:Win_shared_query),
                Array{ComplexF64},
                (Int(entry.length_elements),),
                win;
                rank = 0,
            )
        end
        _mpi_publish_shared_window!(win, node_comm)
        get!(() -> Dict{NTuple{2, Int8}, AbstractArray{ComplexF64, 3}}(), components, entry.kind)[entry.component_indices] =
            reshape(shared_values, entry.logical_shape)
    end
    owner = _register_mpi_shared_operator_storage!(windows, node_comm, leader_comm)
    runtime_notice("MPI operator distribution read_mode=node_shared global_hdf5_open_count=1")
    return (
        manifest = packet.manifest,
        components = components,
        runtime_r_vectors = packet.runtime_r_vectors,
        runtime_degeneracies = packet.runtime_degeneracies,
        replica_summary = packet.replica_summary,
        read_mode = :mpi_node_shared,
        fallback_reason = nothing,
        payload_owner = owner,
    )
end

"""Release MPI windows and derived communicators after a completed run."""
function release_runtime_storage!(loaded_sources)
    owner = loaded_sources.storage_owner
    owner isa MPISharedOperatorStorage || return nothing
    owner.released && return nothing
    for window in owner.windows
        _mpi_unlock_shared_window!(window)
        Base.invokelatest(_mpi_binding(:free), window)
    end
    Base.invokelatest(_mpi_binding(:free), owner.leader_comm)
    Base.invokelatest(_mpi_binding(:free), owner.node_comm)
    owner.released = true
    filter!(candidate -> candidate !== owner, ACTIVE_MPI_SHARED_OPERATOR_STORAGES)
    return nothing
end

"""Release every registered MPI operator storage before MPI finalization."""
function cleanup_active_runtime_storage!()
    for owner in copy(ACTIVE_MPI_SHARED_OPERATOR_STORAGES)
        release_runtime_storage!((storage_owner = owner,))
    end
    return nothing
end

# Assemble model and optional spin sources from demanded component views.
function _runtime_sources_from_component_load(loaded, ctx::RunContext)
    validate_operator_demand(loaded.manifest, ctx.operator_demand)
    wannierization_status = something(loaded.manifest.wannierization_status, "not_provided")
    stopping_reason = something(loaded.manifest.stopping_reason, "not_provided")
    loaded.manifest.production_eligible || runtime_notice(
        "WARNING: operator bundle is diagnostic-only " *
        "wannier_center_policy=$(loaded.manifest.wannier_center_policy); " *
        "wannierization_status=$(wannierization_status); " *
        "stopping_reason=$(stopping_reason); " *
        "do not use it as a release model",
    )
    if REAL_SPACE_SPIN in ctx.operator_demand.required_operators &&
       !loaded.manifest.spin_family_production_eligible
        runtime_notice(
            "WARNING: requested spin-family operators are DIAGNOSTIC_ONLY; " *
            "qualification=$(loaded.manifest.spin_family_qualification); " *
            "reason=$(loaded.manifest.spin_family_qualification_reason); " *
            "schema=$(loaded.manifest.schema_version). Results may be inspected diagnostically " *
            "but are not production-qualified spin-response input.",
        )
    end
    hamiltonian = loaded.components[REAL_SPACE_HAMILTONIAN][(Int8(0), Int8(0))]
    manifest = loaded.manifest
    runtime_r_vectors = loaded.runtime_r_vectors
    runtime_degeneracies = loaded.runtime_degeneracies
    runtime_stub = (
        components = loaded.components,
        manifest = (num_orbitals = manifest.num_orbitals, r_vectors = runtime_r_vectors),
    )
    model = TightBindingModel(
        manifest.lattice,
        manifest.num_orbitals,
        size(runtime_r_vectors, 2),
        runtime_degeneracies,
        runtime_r_vectors,
        hamiltonian,
        _packed_operator(runtime_stub, REAL_SPACE_POSITION, 1);
        copy_data = false,
    )
    spin = if REAL_SPACE_SPIN in ctx.operator_demand.required_operators
        SpinRealSpaceData(_packed_operator(runtime_stub, REAL_SPACE_SPIN, 1); copy_data = false)
    else
        nothing
    end
    spin_velocity = if REAL_SPACE_SPIN_TIMES_HAMILTONIAN in ctx.operator_demand.required_operators
        SpinVelocityRealSpaceData(
            something(spin),
            _packed_operator(runtime_stub, REAL_SPACE_SPIN_TIMES_HAMILTONIAN, 1),
            _packed_operator(runtime_stub, REAL_SPACE_SPIN_TIMES_POSITION, 2),
            _packed_operator(runtime_stub, REAL_SPACE_SPIN_TIMES_HAMILTONIAN_POSITION, 2),
            SpinVelocityRealSpaceDiagnostics(0.0, 0.0, 0.0, 0.0),
        )
    else
        nothing
    end
    derivative_overlap = if ctx.operator_demand.requires_full_projector_geometry
        DerivativeOverlapRealSpaceData(
            _packed_operator(runtime_stub, REAL_SPACE_DERIVATIVE_OVERLAP_TENSOR, 2);
            copy_data = false,
        )
    else
        nothing
    end
    return (
        model = model,
        spin = spin_velocity === nothing ? spin : nothing,
        spin_velocity = spin_velocity,
        derivative_overlap = derivative_overlap,
        manifest = manifest,
        read_mode = loaded.read_mode,
        fallback_reason = loaded.fallback_reason,
        storage_owner = loaded.payload_owner,
        replica_summary = loaded.replica_summary,
    )
end

# Read Legacy Wannier90 inputs once on global rank zero into component ranges.
function _legacy_root_components(ctx::RunContext, cfg::EffectiveTaskConfig, rank::Int)
    rank != 0 && return nothing, nothing, nothing
    try
        model = read_wannier_tb(ctx.model_file)
        spin = maybe_load_spin_from_config(model, cfg)
        spin_velocity = maybe_load_spin_velocity_from_context(model, ctx, cfg)
        components =
            Dict{RealSpaceOperatorKind, Dict{NTuple{2, Int8}, AbstractArray{ComplexF64, 3}}}(
                REAL_SPACE_HAMILTONIAN => Dict{NTuple{2, Int8}, AbstractArray{ComplexF64, 3}}(
                    (Int8(0), Int8(0)) => model.hamiltonian_r,
                ),
            )
        for (kind, source, rank_value) in (
            (REAL_SPACE_POSITION, model.position_r, 1),
            (
                REAL_SPACE_SPIN,
                spin_velocity === nothing ? (spin === nothing ? nothing : spin.spin_r) :
                spin_velocity.spin.spin_r,
                1,
            ),
            (
                REAL_SPACE_SPIN_TIMES_HAMILTONIAN,
                spin_velocity === nothing ? nothing : spin_velocity.spin_hamiltonian_r,
                1,
            ),
            (
                REAL_SPACE_SPIN_TIMES_POSITION,
                spin_velocity === nothing ? nothing : spin_velocity.spin_position_r,
                2,
            ),
            (
                REAL_SPACE_SPIN_TIMES_HAMILTONIAN_POSITION,
                spin_velocity === nothing ? nothing : spin_velocity.spin_hamiltonian_position_r,
                2,
            ),
        )
            haskey(ctx.operator_demand.required_components, kind) || continue
            source === nothing && throw(
                ArgumentError("legacy inputs did not produce $(real_space_operator_name(kind))"),
            )
            selected = Dict{NTuple{2, Int8}, AbstractArray{ComplexF64, 3}}()
            for component in ctx.operator_demand.required_components[kind]
                selected[component] = if rank_value == 1
                    @view source[:, :, Int(component[1]), :]
                else
                    @view source[:, :, Int(component[1]), Int(component[2]), :]
                end
            end
            components[kind] = selected
        end
        prepared = prepare_runtime_components(cfg, ctx, components, model, nothing)
        components = prepared.components
        entries = _runtime_component_entries(components)
        diagnostics = spin_velocity === nothing ? nothing : spin_velocity.diagnostics
        metadata = (
            lattice = model.lattice,
            num_orbitals = model.num_orbitals,
            r_vectors = prepared.r_vectors,
            degeneracies = prepared.degeneracies,
            has_spin = spin !== nothing || spin_velocity !== nothing,
            has_spin_velocity = spin_velocity !== nothing,
            diagnostics = diagnostics,
        )
        original_sources = (model = model, spin = spin, spin_velocity = spin_velocity)
        return components,
        (
            ok = true,
            metadata = metadata,
            entries = entries,
            replica_summary = prepared.summary,
            error = "",
        ),
        original_sources
    catch exception
        return nothing,
        (
            ok = false,
            metadata = nothing,
            entries = NamedTuple[],
            replica_summary = nothing,
            error = sprint(showerror, exception, catch_backtrace()),
        ),
        nothing
    end
end

# Reconstruct typed Runtime sources from one prepared Legacy component packet.
function _runtime_sources_from_legacy_components(
    components,
    packet;
    read_mode::Symbol,
    fallback_reason,
    storage_owner,
)
    metadata = packet.metadata
    loaded_stub = (
        components = components,
        manifest = (num_orbitals = metadata.num_orbitals, r_vectors = metadata.r_vectors),
    )
    model = _runtime_component_model(
        components,
        metadata.lattice,
        metadata.num_orbitals,
        metadata.r_vectors,
        metadata.degeneracies,
    )
    spin =
        metadata.has_spin ?
        SpinRealSpaceData(_packed_operator(loaded_stub, REAL_SPACE_SPIN, 1); copy_data = false) :
        nothing
    spin_velocity = if metadata.has_spin_velocity
        SpinVelocityRealSpaceData(
            something(spin),
            _packed_operator(loaded_stub, REAL_SPACE_SPIN_TIMES_HAMILTONIAN, 1),
            _packed_operator(loaded_stub, REAL_SPACE_SPIN_TIMES_POSITION, 2),
            _packed_operator(loaded_stub, REAL_SPACE_SPIN_TIMES_HAMILTONIAN_POSITION, 2),
            metadata.diagnostics,
        )
    else
        nothing
    end
    return (
        model = model,
        spin = spin_velocity === nothing ? spin : nothing,
        spin_velocity = spin_velocity,
        derivative_overlap = nothing,
        manifest = nothing,
        read_mode = read_mode,
        fallback_reason = fallback_reason,
        storage_owner = storage_owner,
        replica_summary = packet.replica_summary,
    )
end

# Distribute Legacy Wannier90 components through the shared MPI data layer.
function _mpi_distribute_legacy_components(ctx::RunContext, cfg::EffectiveTaskConfig)
    comm = bundle_mpi_comm_world()
    rank = bundle_mpi_comm_rank(comm)
    root_components, root_packet, _ = _legacy_root_components(ctx, cfg, rank)
    packet = bundle_mpi_bcast(root_packet, 0, comm)
    packet.ok || error("global root legacy input read failed:\n$(packet.error)")
    shared_disabled =
        mpi_env_truthy("WANNIERNLQG_DISABLE_MPI_SHARED") || !_mpi_shared_window_available()
    node_comm =
        shared_disabled ? nothing :
        Base.invokelatest(
            _mpi_binding(:Comm_split_type),
            comm,
            _mpi_binding(:COMM_TYPE_SHARED),
            rank,
        )
    node_rank = shared_disabled ? rank : Base.invokelatest(_mpi_binding(:Comm_rank), node_comm)
    leader_comm =
        shared_disabled ? nothing :
        Base.invokelatest(_mpi_binding(:Comm_split), comm, node_rank == 0 ? 0 : nothing, rank)
    windows = Any[]
    components = Dict{RealSpaceOperatorKind, Dict{NTuple{2, Int8}, AbstractArray{ComplexF64, 3}}}()
    for entry in packet.entries
        if shared_disabled
            values = Vector{ComplexF64}(undef, entry.length_elements)
            rank == 0 && copyto!(values, vec(root_components[entry.kind][entry.component_indices]))
            Base.invokelatest(_mpi_binding(:Bcast!), values, 0, comm)
            shared_values = values
        else
            win, local_values = _mpi_allocate_locked_shared_window(
                Array{ComplexF64},
                node_rank == 0 ? entry.length_elements : 0,
                node_comm,
            )
            push!(windows, win)
            if node_rank == 0
                rank == 0 &&
                    copyto!(local_values, vec(root_components[entry.kind][entry.component_indices]))
                Base.invokelatest(_mpi_binding(:Bcast!), local_values, 0, leader_comm)
            end
            shared_values =
                node_rank == 0 ? local_values :
                Base.invokelatest(
                    _mpi_binding(:Win_shared_query),
                    Array{ComplexF64},
                    (entry.length_elements,),
                    win;
                    rank = 0,
                )
            _mpi_publish_shared_window!(win, node_comm)
        end
        get!(() -> Dict{NTuple{2, Int8}, AbstractArray{ComplexF64, 3}}(), components, entry.kind)[entry.component_indices] =
            reshape(shared_values, entry.logical_shape)
    end
    owner =
        shared_disabled ? nothing :
        _register_mpi_shared_operator_storage!(windows, node_comm, leader_comm)
    mode = shared_disabled ? :mpi_rank_private : :mpi_node_shared
    runtime_notice("MPI legacy operator distribution read_mode=$(mode) global_input_read_count=1")
    return _runtime_sources_from_legacy_components(
        components,
        packet;
        read_mode = mode,
        fallback_reason = shared_disabled ? "node-shared windows disabled or unavailable" : nothing,
        storage_owner = owner,
    )
end

const RuntimeLoadedSources = NamedTuple{
    (
        :model,
        :spin,
        :spin_velocity,
        :derivative_overlap,
        :manifest,
        :read_mode,
        :fallback_reason,
        :storage_owner,
        :replica_summary,
    ),
    <:Tuple{
        TightBindingModel,
        Union{Nothing, SpinRealSpaceData},
        Union{Nothing, SpinVelocityRealSpaceData},
        Union{Nothing, DerivativeOverlapRealSpaceData},
        Any,
        Symbol,
        Union{Nothing, String},
        Any,
        RuntimeReplicaSummary,
    },
}

"""Load the selected Runtime source mode without changing hot-loop summation order."""
function load_runtime_model_and_sources(
    ctx::RunContext,
    cfg::EffectiveTaskConfig,
)::RuntimeLoadedSources
    if ctx.model_input_mode == :legacy
        comm = bundle_mpi_comm_world()
        bundle_mpi_comm_size(comm) > 1 && return _mpi_distribute_legacy_components(ctx, cfg)
        components, packet, original_sources = _legacy_root_components(ctx, cfg, 0)
        packet.ok || error("legacy input read failed:\n$(packet.error)")
        if !packet.replica_summary.transformed_this_run
            sources = something(original_sources)
            return (
                model = sources.model,
                spin = sources.spin_velocity === nothing ? sources.spin : nothing,
                spin_velocity = sources.spin_velocity,
                derivative_overlap = nothing,
                manifest = nothing,
                read_mode = :legacy,
                fallback_reason = nothing,
                storage_owner = nothing,
                replica_summary = packet.replica_summary,
            )
        end
        return _runtime_sources_from_legacy_components(
            components,
            packet;
            read_mode = :legacy,
            fallback_reason = nothing,
            storage_owner = nothing,
        )
    end

    bundle = something(ctx.real_space_operator_bundle_file)
    comm = bundle_mpi_comm_world()
    loaded = if bundle_mpi_comm_size(comm) > 1
        _mpi_node_shared_bundle_components(bundle, ctx.operator_demand, ctx, cfg)
    else
        raw = read_operator_bundle_components(
            bundle,
            ctx.operator_demand.required_components;
            prefer_mmap = true,
        )
        _prepare_hdf5_component_load(raw, ctx, cfg)
    end
    runtime_notice(
        "read Packed HDF5 operator bundle profile=$(loaded.manifest.profile) read_mode=$(loaded.read_mode)" *
        (loaded.fallback_reason === nothing ? "" : " reason=$(loaded.fallback_reason)"),
    )
    return _runtime_sources_from_component_load(loaded, ctx)
end
