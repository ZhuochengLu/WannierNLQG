const OPERATOR_BUNDLE_SCHEMA = "wanniernlqg.real-space-operators"
const OPERATOR_BUNDLE_SCHEMA_VERSION = "1.1"
const FULL_DERIVATIVE_OVERLAP_ALGORITHM_VERSION = "wannier90-get_FF_R-v1"
const OPERATOR_BUNDLE_EXTENSION_NAME = :WannierNLQGOperatorBundleExt
const OPERATOR_BUNDLE_EXTENSION_LOCK = ReentrantLock()

const OPERATOR_PROFILE_INVENTORIES = Dict{Symbol, Tuple}(
    :hamiltonian_position => (REAL_SPACE_HAMILTONIAN, REAL_SPACE_POSITION),
    :hamiltonian_position_spin =>
        (REAL_SPACE_HAMILTONIAN, REAL_SPACE_POSITION, REAL_SPACE_SPIN),
    :derivative => (
        REAL_SPACE_HAMILTONIAN,
        REAL_SPACE_POSITION,
        REAL_SPACE_HAMILTONIAN_WEIGHTED_CONNECTION,
        REAL_SPACE_HAMILTONIAN_WEIGHTED_AXIAL_DERIVATIVE_OVERLAP,
        REAL_SPACE_DERIVATIVE_OVERLAP_TENSOR,
        REAL_SPACE_AXIAL_DERIVATIVE_OVERLAP,
        REAL_SPACE_SYMMETRIC_DERIVATIVE_OVERLAP,
    ),
    :full => REAL_SPACE_OPERATOR_REGISTRY,
)

"""One zero-based row of the packed operator-component index."""
struct OperatorBundleIndexEntry
    kind::RealSpaceOperatorKind
    component_rank::UInt8
    component_indices::NTuple{2, Int8}
    offset_elements::UInt64
    length_elements::UInt64
    logical_shape::NTuple{3, Int}
    component_sha256::String
end

"""Validated small metadata needed before loading a packed operator payload."""
struct OperatorBundleManifest
    path::String
    profile::Symbol
    inventory::Vector{RealSpaceOperatorKind}
    num_orbitals::Int
    lattice::Matrix{Float64}
    r_vectors::Matrix{Int}
    degeneracies::Vector{Int}
    entries::Vector{OperatorBundleIndexEntry}
    payload_length::Int
    paired_tb_sha256::Union{Nothing, String}
    scientific_content_sha256::String
    schema_version::String
    wannier_centers_cartesian::Union{Nothing, Matrix{Float64}}
    wannier_centers_fractional::Union{Nothing, Matrix{Float64}}
    raw_wannier_centers_cartesian::Union{Nothing, Matrix{Float64}}
    raw_wannier_centers_fractional::Union{Nothing, Matrix{Float64}}
    wannier_center_policy::Symbol
    real_space_replica_policy::Symbol
    production_eligible::Bool
    minimum_distance_materialized::Bool
    mp_grid::Union{Nothing, NTuple{3, Int}}
    wigner_seitz_tolerance::Union{Nothing, Float64}
    wigner_seitz_search_size::Union{Nothing, Int}
    replica_mapping_sha256::Union{Nothing, String}
    geometry_content_sha256::Union{Nothing, String}
    wannierization_status::Union{Nothing, String}
    solver_status::Union{Nothing, String}
    solver_convergence::Union{Nothing, String}
    initialization_status::Union{Nothing, String}
    initializer_algorithm_version::Union{Nothing, String}
    numerical_quality::Union{Nothing, String}
    tb_export_status::Union{Nothing, String}
    converged::Union{Nothing, Bool}
    quality_review_recommended::Bool
    physics_qualification::Union{Nothing, String}
    tb_usability::Union{Nothing, String}
    stopping_reason::Union{Nothing, String}
    iterations_completed::Union{Nothing, Int}
    last_attempted_iteration::Union{Nothing, Int}
    last_accepted_iteration::Union{Nothing, Int}
    last_persisted_iteration::Union{Nothing, Int}
    convergence_metric::Union{Nothing, Float64}
    convergence_tolerance::Union{Nothing, Float64}
    checkpoint_sha256::Union{Nothing, String}
    input_sha256::Union{Nothing, String}
    spread_metric::Union{Nothing, String}
    amn_sha256::Union{Nothing, String}
    projection_basis_sha256::Union{Nothing, String}
    finite_difference_stencil_sha256::Union{Nothing, String}
    optimizer_strategy::Union{Nothing, String}
    projector_residual::Union{Nothing, Float64}
    z_residual::Union{Nothing, Float64}
    u_residual::Union{Nothing, Float64}
    solver_validation_ready::Union{Nothing, Bool}
    isometry_before_export::Union{Nothing, Float64}
    isometry_after_export::Union{Nothing, Float64}
    polar_repaired_for_export::Union{Nothing, Bool}
    frozen_residual::Union{Nothing, Float64}
    hamiltonian_hermiticity_residual::Union{Nothing, Float64}
    position_hermiticity_residual::Union{Nothing, Float64}
    roundtrip_tolerance::Union{Nothing, Float64}
    post_validation_present::Bool
    final_tb_usability::Union{Nothing, String}
    final_physics_qualification::Union{Nothing, String}
    final_production_eligible::Union{Nothing, Bool}
    post_validation_source_sha256::Union{Nothing, String}
    post_validation_content_sha256::Union{Nothing, String}
    tb_symmetry_qualification_present::Bool
    tb_symmetry_qualification_overall::String
    tb_symmetry_qualification_reason::String
    tb_symmetry_qualification_sha256::Union{Nothing, String}
    authoritative_hamiltonian::String
    authoritative_hamiltonian_sha256::String
    energy_shift_qualification::String
    maximum_energy_shift_audit_reference_ev::String
    rms_energy_shift_audit_reference_ev::String
    target_energy_shift_audit_status::String
    symmetrized_parent_energy_shift_audit_status::String
    residual_gate_phase::String
    raw_preflight_diagnostic_status::String
    native_difference_qualification::String
    native_difference_audit_status::String
    qualification_scope::String
    target_anchor::String
    target_complement_completion::String
    target_complement_max_element_ev::String
    auxiliary_parent_qualification::String
    symmetrized_target_subspace_status::String
    auxiliary_parent_audit_status::String
    target_scope_production_eligible::Bool
    scoped_production_eligible::Bool
    global_production_eligible::Bool
    parent_audit_policy::String
    target_authority::String
    outer_mask_sha256::String
    frozen_mask_sha256::String
    target_subspace_contract_sha256::String
    target_leakage_semantics::String
    target_leakage_formula_sha256::String
    target_leakage_threshold::Union{Nothing, Float64}
    derivative_overlap_source::String
    derivative_overlap_completeness::String
    derivative_overlap_source_sha256::Union{Nothing, String}
    derivative_overlap_algorithm_version::String
    operator_qualification::Dict{String, Any}
    operator_qualification_sha256::String
    spin_family_qualification::String
    spin_family_qualification_reason::String
    spin_family_production_eligible::Bool
    finite_band_galerkin_qualification::String
    finite_band_galerkin_qualification_reason::String
    finite_band_galerkin_production_eligible::Bool
    band_frame_contract_status::String
    band_frame_transform_sha256::String
    band_frame_contract_sha256::String
    band_frame_metric_kind::String
    band_frame_physical_isometry_maximum::Union{Nothing, Float64}
    band_frame_physical_isometry_tolerance::Union{Nothing, Float64}
    band_frame_replay_maximum::Union{Nothing, Float64}
    band_frame_replay_tolerance::Union{Nothing, Float64}
    band_frame_euclidean_nonunitarity_maximum::Union{Nothing, Float64}
    band_frame_minimum_singular_value::Union{Nothing, Float64}
    band_frame_maximum_condition_number::Union{Nothing, Float64}
    operator_selection_mode::String
    requested_tasks::Vector{String}
    normalized_tasks::String
    task_dependency_closure::String
    resolved_operator_inventory::String
    resolved_source_inventory::String
    operator_requirement_registry_version::String
    operator_selection_sha256::Union{Nothing, String}
    operator_target_contract_sha256::Union{Nothing, String}
end

"""
Read-only logical R-last Cartesian operator backed by independently packed
component matrices. Missing components are represented in the inventory but
raise on access, so K-slice demand plans can avoid touching unrelated payload.
"""
struct PackedCartesianOperator{R, N, C <: AbstractArray{ComplexF64, 3}} <:
       AbstractArray{ComplexF64, N}
    components::Vector{C}
    available::BitVector
    dimensions::NTuple{N, Int}
end

# Use Cartesian indexing for logical packed operator views.
Base.IndexStyle(::Type{<:PackedCartesianOperator}) = IndexCartesian()
# Return the complete logical operator dimensions.
Base.size(operator::PackedCartesianOperator) = operator.dimensions

# Build a packed rank-one or rank-two logical operator from selected components.
function PackedCartesianOperator(rank::Int, component_views::AbstractDict, logical_shape)
    rank in (1, 2) || throw(ArgumentError("packed Cartesian operator rank must be one or two"))
    isempty(component_views) && throw(ArgumentError("at least one packed component is required"))
    first_component = first(values(component_views))
    first_component isa AbstractArray{ComplexF64, 3} ||
        throw(ArgumentError("packed components must be rank-three ComplexF64 arrays"))
    component_count = 3^rank
    components = fill(first_component, component_count)
    available = falses(component_count)
    for (indices, component) in pairs(component_views)
        component isa typeof(first_component) ||
            throw(ArgumentError("packed components must share one storage type"))
        linear = rank == 1 ? Int(indices[1]) : (Int(indices[1]) - 1) * 3 + Int(indices[2])
        linear in 1:component_count || throw(ArgumentError("invalid Cartesian component index"))
        size(component) == Tuple(logical_shape) ||
            throw(ArgumentError("packed component logical shape mismatch"))
        components[linear] = component
        available[linear] = true
    end
    dimensions =
        rank == 1 ? (Int(logical_shape[1]), Int(logical_shape[2]), 3, Int(logical_shape[3])) :
        (Int(logical_shape[1]), Int(logical_shape[2]), 3, 3, Int(logical_shape[3]))
    return PackedCartesianOperator{rank, length(dimensions), typeof(first_component)}(
        components,
        available,
        dimensions,
    )
end

# Return one loaded component and reject demand-plan omissions.
@inline function _packed_component(operator::PackedCartesianOperator, linear::Int)
    operator.available[linear] ||
        throw(ArgumentError("requested Cartesian component was not loaded by the demand plan"))
    return operator.components[linear]
end

# Index a rank-one packed operator without materializing the complete array.
@inline function Base.getindex(
    operator::PackedCartesianOperator{1, 4},
    left::Int,
    right::Int,
    component::Int,
    r_index::Int,
)
    return _packed_component(operator, component)[left, right, r_index]
end

# Index a rank-two packed operator without materializing the complete array.
@inline function Base.getindex(
    operator::PackedCartesianOperator{2, 5},
    left::Int,
    right::Int,
    first_component::Int,
    second_component::Int,
    r_index::Int,
)
    linear = (first_component - 1) * 3 + second_component
    return _packed_component(operator, linear)[left, right, r_index]
end

# Return one rank-one component view.
function Base.view(
    operator::PackedCartesianOperator{1, 4},
    ::Colon,
    ::Colon,
    component::Integer,
    ::Colon,
)
    return _packed_component(operator, Int(component))
end

# Return one rank-two component view.
function Base.view(
    operator::PackedCartesianOperator{2, 5},
    ::Colon,
    ::Colon,
    first_component::Integer,
    second_component::Integer,
    ::Colon,
)
    return _packed_component(operator, (Int(first_component) - 1) * 3 + Int(second_component))
end

"""Return the stable HDF5 inventory name for a registered real-space operator kind."""
operator_storage_name(kind::RealSpaceOperatorKind) = real_space_operator_name(kind)

"""Resolve a canonical HDF5 inventory name; throw `ArgumentError` for unknown names."""
function operator_kind_from_storage_name(name::AbstractString)
    target = String(name)
    for kind in REAL_SPACE_OPERATOR_REGISTRY
        real_space_operator_name(kind) == target && return kind
    end
    throw(ArgumentError("unsupported real-space operator $(target)"))
end

"""Return an inventory in schema registry order after rejecting duplicates."""
function canonical_operator_inventory(inventory)
    kinds = RealSpaceOperatorKind[inventory...]
    length(unique(kinds)) == length(kinds) ||
        throw(ArgumentError("operator inventory contains duplicates"))
    kind_set = Set(kinds)
    return RealSpaceOperatorKind[kind for kind in REAL_SPACE_OPERATOR_REGISTRY if kind in kind_set]
end

"""Infer the only valid profile for an exact operator inventory."""
function infer_operator_profile(inventory)
    canonical = canonical_operator_inventory(inventory)
    for profile in (:hamiltonian_position, :hamiltonian_position_spin, :derivative, :full)
        canonical == collect(OPERATOR_PROFILE_INVENTORIES[profile]) && return profile
    end
    throw(
        ArgumentError(
            "operator inventory does not match a supported complete profile: " *
            join(real_space_operator_name.(canonical), ", "),
        ),
    )
end

"""Validate that a profile name and exact inventory describe the same capability."""
function validate_operator_profile(profile::Symbol, inventory)
    profile == :spin && throw(
        ArgumentError(
            "operator profile :spin was removed; migrate to :hamiltonian_position_spin and regenerate as schema 1.0",
        ),
    )
    haskey(OPERATOR_PROFILE_INVENTORIES, profile) ||
        throw(ArgumentError("unsupported operator profile $(profile)"))
    inferred = infer_operator_profile(inventory)
    inferred == profile ||
        throw(ArgumentError("operator profile $(profile) disagrees with inventory $(inferred)"))
    return canonical_operator_inventory(inventory)
end

"""Return semantic matrix capabilities provided by an exact inventory."""
function available_matrix_capabilities(inventory)
    kinds = Set(canonical_operator_inventory(inventory))
    capabilities = String["hamiltonian", "position"]
    REAL_SPACE_SPIN in kinds && push!(capabilities, "spin")
    all(kind -> kind in kinds, OPERATOR_PROFILE_INVENTORIES[:derivative][3:end]) &&
        push!(capabilities, "derivative")
    all(
        kind -> kind in kinds,
        (
            REAL_SPACE_SPIN_TIMES_HAMILTONIAN,
            REAL_SPACE_SPIN_TIMES_POSITION,
            REAL_SPACE_SPIN_TIMES_HAMILTONIAN_POSITION,
        ),
    ) && push!(capabilities, "spin_velocity")
    return capabilities
end

"""Fixed operator profiles accepted by the public Wannierization output selection."""
const OPERATOR_SELECTION_PROFILES = (:hamiltonian_position, :full)

"""Resolved operator selection shared by the Wannierization export and Runtime paths."""
struct OperatorSelection
    mode::Symbol
    profile::Symbol
    inventory::Vector{RealSpaceOperatorKind}
    sources::Vector{Symbol}
    requested_tasks::Tuple
    normalized_tasks::Tuple
    closure::Tuple
    registry_version::String
    selection_sha256::Union{Nothing, String}
end

"""Return `:profile` or `:tasks` for one resolved operator selection."""
operator_selection_mode(selection::OperatorSelection) = selection.mode

"""Return the stored profile label of one resolved operator selection."""
resolved_operator_profile(selection::OperatorSelection) = selection.profile

"""Return the resolved real-space operator inventory in canonical registry order."""
resolved_operator_inventory(selection::OperatorSelection) = selection.inventory

"""Return the resolved upstream source closure in canonical source-registry order."""
resolved_source_inventory(selection::OperatorSelection) = selection.sources

"""Return the per-task dependency closure recorded for one resolved selection."""
resolved_task_closure(selection::OperatorSelection) = selection.closure

"""Return the operator-requirement registry version bound into one selection."""
operator_selection_registry_version(selection::OperatorSelection) = selection.registry_version

"""Return the stable selection digest, or `nothing` for a fixed profile."""
operator_selection_sha256(selection::OperatorSelection) = selection.selection_sha256

"""
Return the union of upstream source closures of one complete operator inventory.

The result follows the canonical `OPERATOR_TASK_SOURCE_REGISTRY` order so that a
profile selection and an equivalent task-derived selection bind the same sources.
"""
function operator_inventory_source_closure(inventory)
    canonical = canonical_operator_inventory(inventory)
    requested = Set{Symbol}()
    for kind in canonical, source in OPERATOR_SOURCE_CLOSURES[kind]
        push!(requested, source)
    end
    return Symbol[source for source in OPERATOR_TASK_SOURCE_REGISTRY if source in requested]
end

"""Encode one requested operator task as a stable `quantity:method` token."""
operator_task_token(task::OperatorTask) = string(task.quantity, ":", task.method)

"""Decode one `quantity:method` token back into an `OperatorTask`."""
function operator_task_from_token(token::AbstractString)
    parts = split(String(token), ':')
    length(parts) == 2 || throw(ArgumentError("malformed operator task token $(token)"))
    return OperatorTask(quantity = Symbol(parts[1]), method = Symbol(parts[2]))
end

"""
Decode a persisted vector of `quantity:method` tokens back into requested tasks.

The fresh reader must re-derive one task-derived closure from the recorded
`requested_tasks` tokens, not from their already-normalized expansion: the requested
tokens carry the caller's original `method=:all` form that the selection digest binds.
"""
function operator_tasks_from_tokens(tokens)
    return OperatorTask[operator_task_from_token(token) for token in tokens]
end

"""
Resolve one mutually exclusive operator selection into its canonical inventory,
source closure, and per-task dependency closure.

`profile` selects a fixed complete inventory; `operator_tasks` selects a
task-derived inventory.  Exactly one must be supplied.  Task-derived selections are
re-derived from the shared `Core` requirement registry, so the Wannierization
generation path and the Runtime consumption path cannot disagree about a task.
"""
function resolve_operator_selection(profile::Union{Nothing, Symbol}, operator_tasks = ())
    tasks = Tuple(operator_tasks)
    if profile !== nothing
        isempty(tasks) || throw(
            OperatorSelectionError(
                "AMBIGUOUS_OPERATOR_SELECTION",
                "profile=$(profile) and $(length(tasks)) operator_tasks were both supplied; " *
                "select exactly one of a fixed profile or operator_tasks",
            ),
        )
        profile == :spin && throw(
            OperatorSelectionError(
                "UNSUPPORTED_OPERATOR_PROFILE",
                "operator profile :spin was removed; select operator_tasks or profile=:full",
            ),
        )
        profile in OPERATOR_SELECTION_PROFILES || throw(
            OperatorSelectionError(
                "UNSUPPORTED_OPERATOR_PROFILE",
                "profile=$(profile) is not a supported fixed operator profile; supported " *
                "profiles: $(join(String.(OPERATOR_SELECTION_PROFILES), ", "))",
            ),
        )
        inventory = collect(OPERATOR_PROFILE_INVENTORIES[profile])
        return OperatorSelection(
            :profile,
            profile,
            inventory,
            operator_inventory_source_closure(inventory),
            (),
            (),
            (),
            OPERATOR_REQUIREMENT_REGISTRY_VERSION,
            nothing,
        )
    end
    isempty(tasks) && throw(
        OperatorSelectionError(
            "EMPTY_OPERATOR_TASK_SELECTION",
            "profile=nothing requires at least one OperatorTask",
        ),
    )
    resolution = resolve_operator_requirements(tasks)
    inventory = collect(resolution.required_operators)
    # A task-derived selection always stores the `:task_derived` label, even when its
    # inventory happens to coincide with a fixed profile.  The persisted profile is a
    # provenance identity, not an inferred inventory class: relabelling a task selection
    # as a fixed profile would silently upgrade an artifact that never passed the fixed
    # profile qualification path.
    stored = :task_derived
    return OperatorSelection(
        :tasks,
        stored,
        inventory,
        collect(resolution.required_sources),
        tasks,
        resolution.tasks,
        resolution.closure,
        resolution.registry_version,
        resolution.selection_sha256,
    )
end

"""
Re-derive one stored task-derived selection and reject any tampering with the
requested tasks, the resolved inventory or source closure, their canonical order,
the registry version, or the selection digest.
"""
function validate_task_derived_operator_selection(
    requested_tasks,
    inventory,
    sources,
    selection_sha256,
    registry_version,
)
    tokens = String[String(token) for token in requested_tasks]
    isempty(tokens) && throw(
        ArgumentError("TASK_DERIVED_OPERATOR_SELECTION_INVALID: requested_tasks must not be empty"),
    )
    String(registry_version) == OPERATOR_REQUIREMENT_REGISTRY_VERSION || throw(
        ArgumentError(
            "TASK_DERIVED_OPERATOR_SELECTION_INVALID: unsupported operator requirement " *
            "registry version $(registry_version)",
        ),
    )
    resolution = try
        resolve_operator_requirements(operator_tasks_from_tokens(tokens))
    catch error
        error isa Union{OperatorSelectionError, ArgumentError} || rethrow()
        throw(ArgumentError("TASK_DERIVED_OPERATOR_SELECTION_INVALID: $(sprint(showerror, error))"))
    end
    expected_inventory = canonical_operator_inventory(resolution.required_operators)
    stored_inventory = canonical_operator_inventory(inventory)
    RealSpaceOperatorKind[inventory...] == stored_inventory || throw(
        ArgumentError(
            "TASK_DERIVED_OPERATOR_SELECTION_INVALID: stored operator inventory is not in " *
            "canonical registry order",
        ),
    )
    stored_inventory == expected_inventory || throw(
        ArgumentError(
            "TASK_DERIVED_OPERATOR_SELECTION_INVALID: stored operator inventory " *
            "$(join(real_space_operator_name.(stored_inventory), ", ")) disagrees with the " *
            "re-derived inventory $(join(real_space_operator_name.(expected_inventory), ", "))",
        ),
    )
    stored_sources = Symbol[Symbol(source) for source in sources]
    expected_sources = collect(resolution.required_sources)
    stored_sources == expected_sources || throw(
        ArgumentError(
            "TASK_DERIVED_OPERATOR_SELECTION_INVALID: stored source inventory " *
            "$(join(String.(stored_sources), ", ")) disagrees with the re-derived source " *
            "inventory $(join(String.(expected_sources), ", "))",
        ),
    )
    String(selection_sha256) == resolution.selection_sha256 || throw(
        ArgumentError(
            "TASK_DERIVED_OPERATOR_SELECTION_INVALID: stored operator selection SHA-256 " *
            "differs from the re-derived digest",
        ),
    )
    return resolution
end

# Return the active HDF5-only model-package extension, if loaded.
function _active_operator_bundle_extension()
    return Base.get_extension(parentmodule(@__MODULE__), OPERATOR_BUNDLE_EXTENSION_NAME)
end

# Load the HDF5-only model-package extension on first expert I/O use.
function _load_operator_bundle_extension!()
    extension = _active_operator_bundle_extension()
    extension === nothing || return extension, false
    lock(OPERATOR_BUNDLE_EXTENSION_LOCK)
    try
        extension = _active_operator_bundle_extension()
        if extension === nothing
            Base.eval(@__MODULE__, :(import HDF5))
            Base.eval(@__MODULE__, :(import JSON3))
            extension = _active_operator_bundle_extension()
            extension === nothing && error(
                "WannierNLQG operator-bundle extension did not activate after loading HDF5 and JSON3",
            )
        end
        return extension, true
    finally
        unlock(OPERATOR_BUNDLE_EXTENSION_LOCK)
    end
end

# Dispatch an I/O facade call across the extension world-age boundary.
function _call_operator_bundle_extension(function_name::Symbol, arguments...; keywords...)
    extension, _ = _load_operator_bundle_extension!()
    implementation = Base.invokelatest(getproperty, extension, function_name)
    return Base.invokelatest(implementation, arguments...; keywords...)
end

"""
Write one strict Packed HDF5 model bundle with explicit provenance.

`profile` selects a fixed complete inventory. Pass `profile = nothing` together with a
non-empty `operator_tasks` tuple to persist a task-derived selection whose resolved
inventory, source closure, per-task closure, and selection digest are re-derived on read.
"""
function write_real_space_operator_bundle(
    filename::AbstractString,
    lattice,
    degeneracies,
    operators::AbstractDict;
    profile = infer_operator_profile(keys(operators)),
    operator_tasks = (),
    overwrite::Bool = false,
    paired_tb_sha256::Union{Nothing, AbstractString} = nothing,
    provenance = Dict{String, Any}(),
    symmetry = Dict{String, Any}(),
    geometry,
    diagnostics = Dict{String, Any}(),
    eligibility = Dict{String, Any}(),
)
    return _call_operator_bundle_extension(
        :write_real_space_operator_bundle,
        filename,
        lattice,
        degeneracies,
        operators;
        profile = profile === nothing ? nothing : Symbol(profile),
        operator_tasks,
        overwrite,
        paired_tb_sha256,
        provenance,
        symmetry,
        geometry,
        diagnostics,
        eligibility,
    )
end

"""
Read and strictly validate bundle metadata without loading the large payload.

When present, the versioned construction-evidence contract and all duplicated
policy, original gate records and qualification flags are always verified.
Supported historical files without this contract retain their original digest
rules; their free diagnostic metadata receives no new integrity guarantee.
"""
function read_real_space_operator_bundle_manifest(filename::AbstractString)
    return _call_operator_bundle_extension(:read_real_space_operator_bundle_manifest, filename)
end

"""
Read and reconstruct every operator in a compatible Packed HDF5 bundle.

`verify_digests=false` skips numerical component hashes only. Scientific metadata
and any construction-evidence seal remain mandatory checks.
"""
function read_real_space_operator_bundle(filename::AbstractString; verify_digests::Bool = true)
    return _call_operator_bundle_extension(
        :read_real_space_operator_bundle,
        filename;
        verify_digests,
    )
end

"""Map the sole packed payload when compatible, otherwise return a buffered copy."""
function read_operator_bundle_payload(filename::AbstractString; prefer_mmap::Bool = true)
    return _call_operator_bundle_extension(:read_operator_bundle_payload, filename; prefer_mmap)
end

"""Load only requested component ranges, preserving component-contiguous views."""
function read_operator_bundle_components(
    filename::AbstractString,
    requested_components::AbstractDict;
    prefer_mmap::Bool = true,
)
    return _call_operator_bundle_extension(
        :read_operator_bundle_components,
        filename,
        requested_components;
        prefer_mmap,
    )
end
