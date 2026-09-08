"""Shared model and real-space operator inputs; response parameters belong to each task."""
Base.@kwdef struct ModelInput
    model_file::String = ""
    real_space_operator_bundle_file::Union{Nothing, String} = nothing
    seedname::String = ""
    case_root::String = ""
    wannier_center_convention::String = "Convention_II"
    real_space_replica_policy::String = "auto"
    wsvec_file::Union{Nothing, String} = nothing
    mp_grid::Union{Nothing, NTuple{3, Int}} = nothing
    wigner_seitz_tolerance::Float64 = 1.0e-5
    wigner_seitz_search_size::Int = 3
    spin_enabled::Bool = false
    spin_file::String = ""
    checkpoint_file::String = ""
    spin_file_formatted::Bool = false
end

"""Common sampling geometry for a response run or a band path."""
abstract type AbstractSampling end

"""Uniform Brillouin-zone mesh shared by all Integral task instances."""
struct BZMesh <: AbstractSampling
    k_mesh::Union{NTuple{2, Int}, NTuple{3, Int}}
    spatial_dimension::Int
end
"""Copy the shared Integral mesh and record the number of physical Cartesian axes."""
BZMesh(; k_mesh, spatial_dimension::Integer = length(k_mesh)) =
    BZMesh(k_mesh, Int(spatial_dimension))

"""A common two-dimensional reciprocal-space slice, expressed in fractional coordinates."""
struct KSlice <: AbstractSampling
    k_mesh::NTuple{2, Int}
    spatial_dimension::Int
    origin::NTuple{3, Float64}
    vector_1::NTuple{3, Float64}
    vector_2::NTuple{3, Float64}
end
"""Copy an explicit fractional slice plane and its two sampling counts."""
KSlice(; k_mesh, spatial_dimension::Integer, origin, vector_1, vector_2) = KSlice(
    k_mesh,
    Int(spatial_dimension),
    Tuple(Float64.(origin)),
    Tuple(Float64.(vector_1)),
    Tuple(Float64.(vector_2)),
)

"""An explicit reciprocal-space path independent of the task evaluated on it."""
struct KPath <: AbstractSampling
    nodes::Vector{Tuple{String, NTuple{3, Float64}}}
    kpoints_per_segment::Vector{Int}
    spatial_dimension::Int
end
"""Normalize path labels and fractional nodes, preserving the supplied segment counts."""
KPath(; nodes, kpoints_per_segment, spatial_dimension::Integer = 3) =
    KPath(normalize_kpath_input(nodes), Int[x for x in kpoints_per_segment], Int(spatial_dimension))

"""Shared execution controls; the Fourier backend must be selected explicitly."""
Base.@kwdef struct ExecutionOptions
    fourier_backend::String
    NKdiv::Union{Nothing, NTuple{2, Int}, NTuple{3, Int}} = nothing
    NKFFT::Union{Nothing, NTuple{2, Int}, NTuple{3, Int}} = nothing
    response_symmetry_file::Union{Nothing, String} = nothing
    response_symmetry_policy::String = "strict"
    response_symmetry_kmesh_mode::String = "reduced"
    response_symmetry_report_enabled::Bool = false
end

"""Common output parent and formatting/progress controls; each task receives its own ID directory."""
Base.@kwdef struct OutputOptions
    output_root::String = ""
    system_name::Union{Nothing, String} = nothing
    response_output_digits::Int = 7
    progress_enabled::Bool = true
    progress_percent_interval::Union{Nothing, Int} = nothing
    progress_verbosity::String = "normal"
end

"""Physical parameters with quantity-specific applicability checked during compilation."""
abstract type AbstractTaskParameters end

"""Optical energy axis in eV, Fermi energy in eV, and temperature in K; all are explicit."""
struct OpticalParameters <: AbstractTaskParameters
    photon_energies::Vector{Float64}
    fermi_energy::Float64
    temperature::Float64
end
"""Copy the explicit optical energy axis and occupation conditions in eV and K."""
OpticalParameters(; photon_energies, fermi_energy::Real, temperature::Real) = OpticalParameters(
    Float64[x for x in photon_energies],
    Float64(fermi_energy),
    Float64(temperature),
)

"""Optical parameters plus an explicit Cartesian finite-q momentum."""
struct FiniteQOpticalParameters <: AbstractTaskParameters
    photon_energies::Vector{Float64}
    fermi_energy::Float64
    temperature::Float64
    photon_momentum::NTuple{3, Float64}
end
"""Copy the optical and occupation inputs together with the required Cartesian momentum."""
FiniteQOpticalParameters(;
    photon_energies,
    fermi_energy::Real,
    temperature::Real,
    photon_momentum,
) = FiniteQOpticalParameters(
    Float64[x for x in photon_energies],
    Float64(fermi_energy),
    Float64(temperature),
    Tuple(Float64.(photon_momentum)),
)

"""Geometric parameters; occupation values are required only for an explicit occupied sum."""
Base.@kwdef struct GeometryParameters <: AbstractTaskParameters
    fermi_energy::Union{Nothing, Float64} = nothing
    temperature::Union{Nothing, Float64} = nothing
    photon_momentum::Union{Nothing, NTuple{3, Float64}} = nothing
end

"""Explicit reference energy in eV for band-spectrum output."""
struct BandParameters <: AbstractTaskParameters
    fermi_energy::Float64
end
"""Store the explicitly supplied band energy reference in eV."""
BandParameters(; fermi_energy::Real) = BandParameters(Float64(fermi_energy))

"""Numerical options owned by one task rather than by the common run."""
abstract type AbstractTaskNumerics end

"""Optical broadening and matrix/finite-difference controls, with explicit-key provenance."""
struct OpticalNumerics <: AbstractTaskNumerics
    values::NamedTuple
    supplied::Tuple
end

"""Geometry matrix/finite-difference controls; optical line-width options are not accepted."""
struct GeometryNumerics <: AbstractTaskNumerics
    values::NamedTuple
    supplied::Tuple
end

"""Fail-closed Hermiticity tolerance for a band-spectrum task."""
Base.@kwdef struct BandNumerics <: AbstractTaskNumerics
    hermiticity_tolerance::Float64 = 1.0e-10
end

# Reject unknown numerical keys, then combine explicit values with the numerical defaults.
function _task_numerics(defaults::NamedTuple, kwargs, name::AbstractString)
    unknown = setdiff(collect(keys(kwargs)), collect(keys(defaults)))
    isempty(unknown) ||
        throw(ArgumentError("$(name) does not accept $(join(string.(unknown), ", "))."))
    return merge(defaults, (; kwargs...)), Tuple(keys(kwargs))
end

"""Store optical numerical defaults and track which options were explicitly supplied."""
function OpticalNumerics(; kwargs...)
    defaults = (
        broadening = 0.040,
        broadening_type = "Gaussian",
        transition_window_factor = 5.0,
        denominator_regularization = 0.001,
        degeneracy_threshold = 0.002,
        finite_difference_step = nothing,
        band_window_size = -1,
    )
    return OpticalNumerics(_task_numerics(defaults, kwargs, "OpticalNumerics")...)
end

"""Store geometry numerical defaults while rejecting optical-only options."""
function GeometryNumerics(; kwargs...)
    defaults = (
        denominator_regularization = 0.001,
        degeneracy_threshold = 0.002,
        finite_difference_step = nothing,
        band_window_size = nothing,
    )
    return GeometryNumerics(_task_numerics(defaults, kwargs, "GeometryNumerics")...)
end

"""Typed band observation; it never substitutes for the internal calculation band window."""
abstract type AbstractBandSelection end

# Copy positive one-based target indices and reject empty or repeated bands.
function _observation_bands(values, name::AbstractString)
    values isa AbstractVector ||
        throw(ArgumentError("$(name) requires a vector of positive band indices."))
    all(x -> x isa Integer && !(x isa Bool) && x > 0, values) ||
        throw(ArgumentError("$(name) requires positive integer band indices."))
    result = Int[x for x in values]
    isempty(result) && throw(ArgumentError("$(name) must not be empty."))
    length(unique(result)) == length(result) ||
        throw(ArgumentError("$(name) must not repeat band indices."))
    return result
end

"""Observe individual bands; an additional occupied sum must be requested explicitly."""
struct BandTargets <: AbstractBandSelection
    bands::Vector{Int}
    include_occupied_sum::Bool
    function BandTargets(bands; include_occupied_sum::Bool = false)
        new(_observation_bands(bands, "BandTargets"), include_occupied_sum)
    end
end

"""Observe a single explicit band subspace, including a one-band subspace."""
struct Subspace <: AbstractBandSelection
    bands::Vector{Int}
    Subspace(bands) = new(_observation_bands(bands, "Subspace"))
end

"""Observe several disjoint explicit subspaces, preserving their supplied order."""
struct Subspaces <: AbstractBandSelection
    groups::Vector{Vector{Int}}
    function Subspaces(groups)
        result = [_observation_bands(group, "Subspaces") for group in groups]
        isempty(result) && throw(ArgumentError("Subspaces must contain at least one group."))
        flat = reduce(vcat, result)
        length(unique(flat)) == length(flat) || throw(ArgumentError("Subspaces must be disjoint."))
        new(result)
    end
end

"""Observe the occupation-weighted sum over all bands."""
struct OccupiedBands <: AbstractBandSelection end

"""Observe every individual band, optionally also its occupation-weighted sum."""
Base.@kwdef struct AllBands <: AbstractBandSelection
    include_occupied_sum::Bool = false
end

"""An explicit conduction/valence band-pair channel."""
struct Transition <: AbstractBandSelection
    conduction::Vector{Int}
    valence::Vector{Int}
    function Transition(; conduction, valence)
        c = _observation_bands(conduction, "Transition conduction")
        v = _observation_bands(valence, "Transition valence")
        isempty(intersect(c, v)) || throw(ArgumentError("Transition band groups must be disjoint."))
        new(c, v)
    end
end

"""Two explicit non-overlapping band groups for interband geometry."""
struct InterbandGroups <: AbstractBandSelection
    first::Vector{Int}
    second::Vector{Int}
    function InterbandGroups(; first, second)
        a = _observation_bands(first, "InterbandGroups first")
        b = _observation_bands(second, "InterbandGroups second")
        isempty(intersect(a, b)) || throw(ArgumentError("InterbandGroups must be disjoint."))
        new(a, b)
    end
end

"""Three explicit, pairwise-disjoint ordered band groups for a triple-phase product."""
struct TripleGroups <: AbstractBandSelection
    first::Vector{Int}
    second::Vector{Int}
    third::Vector{Int}
    function TripleGroups(; first, second, third)
        a = _observation_bands(first, "TripleGroups first")
        b = _observation_bands(second, "TripleGroups second")
        c = _observation_bands(third, "TripleGroups third")
        length(unique(vcat(a, b, c))) == length(a) + length(b) + length(c) ||
            throw(ArgumentError("TripleGroups must be pairwise disjoint."))
        new(a, b, c)
    end
end

"""A single ordered Cartesian tensor component; rank and axis limits are task-specific."""
struct TensorComponent
    indices::Tuple{Vararg{Int}}
    function TensorComponent(indices::Integer...)
        all(x -> !(x isa Bool) && x > 0, indices) ||
            throw(ArgumentError("TensorComponent indices must be positive integers."))
        new(Tuple(Int(x) for x in indices))
    end
end

"""The complete response tensor currently supported for Integral output."""
struct FullTensor end

"""An explicit component and band/subspace target for a K-slice task."""
Base.@kwdef struct KSliceSelection
    component::TensorComponent
    bands::AbstractBandSelection
end

"""A named response instance with its own physical, numerical, and observation parameters."""
struct TaskSpec
    id::String
    quantity::String
    method::Union{Nothing, String}
    physics::AbstractTaskParameters
    numerics::Union{Nothing, AbstractTaskNumerics}
    observable::Union{Nothing, FullTensor, KSliceSelection}
end

"""Copy one named task and reject IDs that could escape its output directory."""
function TaskSpec(;
    id::AbstractString,
    quantity::AbstractString,
    method::Union{Nothing, AbstractString} = nothing,
    physics::AbstractTaskParameters,
    numerics::Union{Nothing, AbstractTaskNumerics} = nothing,
    observable::Union{Nothing, FullTensor, KSliceSelection} = nothing,
)
    occursin(r"^[A-Za-z0-9][A-Za-z0-9_-]*$", id) || throw(
        ArgumentError(
            "Task id must contain only ASCII letters, digits, '-' and '_', and start with a letter or digit.",
        ),
    )
    isempty(strip(quantity)) && throw(ArgumentError("Task quantity must not be empty."))
    return TaskSpec(
        String(id),
        String(quantity),
        method === nothing ? nothing : String(method),
        deepcopy(physics),
        deepcopy(numerics),
        deepcopy(observable),
    )
end

"""Public run configuration: shared model/sampling/execution plus independently named tasks."""
struct TaskConfig
    model::ModelInput
    sampling::AbstractSampling
    tasks::Vector{TaskSpec}
    execution::ExecutionOptions
    output::OutputOptions
end

"""Copy the shared configuration and reject empty or case-colliding task identifiers."""
function TaskConfig(;
    model::Union{Nothing, ModelInput} = nothing,
    sampling::Union{Nothing, AbstractSampling} = nothing,
    tasks = nothing,
    execution::Union{Nothing, ExecutionOptions} = nothing,
    output::OutputOptions = OutputOptions(),
    kwargs...,
)
    if !isempty(kwargs) || (tasks !== nothing && !(tasks isa AbstractVector{TaskSpec}))
        throw(
            ArgumentError(
                "The flat TaskConfig interface has been removed. Use ModelInput, sampling, ExecutionOptions and named TaskSpec objects; see docs/MIGRATION_1.0.0.md. Unsupported keywords: $(join(string.(keys(kwargs)), ", ")).",
            ),
        )
    end
    model !== nothing && sampling !== nothing && execution !== nothing && tasks !== nothing ||
        throw(
            ArgumentError(
                "TaskConfig requires explicit model, sampling, execution and tasks groups; see docs/MIGRATION_1.0.0.md.",
            ),
        )
    isempty(tasks) && throw(ArgumentError("TaskConfig requires at least one TaskSpec."))
    ids = lowercase.([task.id for task in tasks])
    length(unique(ids)) == length(ids) ||
        throw(ArgumentError("Task ids must be unique, including on case-insensitive filesystems."))
    return TaskConfig(
        deepcopy(model),
        deepcopy(sampling),
        deepcopy(collect(tasks)),
        deepcopy(execution),
        deepcopy(output),
    )
end

# Cold-path named-field conversion keeps the effective compiler independent of field order.
_configuration_fields(value) =
    (; (name => getfield(value, name) for name in fieldnames(typeof(value)))...)
# Map the shared BZ mesh to the Integral executor category.
_sampling_calculation(::BZMesh) = :integral
# Map the shared slice geometry to the K-slice executor category.
_sampling_calculation(::KSlice) = :kslice
# Map the shared reciprocal-space path to the K-path calculation domain.
_sampling_calculation(::KPath) = :kpath
# Lower the common BZ mesh to the private execution configuration.
_sampling_fields(sampling::BZMesh) =
    (; k_mesh = sampling.k_mesh, spatial_dimension = sampling.spatial_dimension)
# Lower the explicit slice vectors and counts without altering reciprocal coordinates.
_sampling_fields(sampling::KSlice) = (;
    k_mesh = sampling.k_mesh,
    spatial_dimension = sampling.spatial_dimension,
    kslice_origin = sampling.origin,
    kslice_vector_1 = sampling.vector_1,
    kslice_vector_2 = sampling.vector_2,
)
# Lower path nodes and segment counts; the private mesh placeholder is unused by KPath.
_sampling_fields(sampling::KPath) = (;
    k_mesh = (1, 1, 1),
    spatial_dimension = sampling.spatial_dimension,
    kpath_nodes = sampling.nodes,
    kpoints_per_segment = sampling.kpoints_per_segment,
)

# Band structure is a registry-owned task semantic, not a property of KPath sampling.
_is_band_structure(definition::TaskDefinition) =
    definition.executor == EXECUTOR_BAND_STRUCTURE &&
    definition.output_policy == OUTPUT_BAND_STRUCTURE

# Explicit band and subspace targets do not request an occupation-weighted sum.
_occupied_sum_requested(::AbstractBandSelection) = false
# Recognize the dedicated occupation-weighted-sum observation.
_occupied_sum_requested(::OccupiedBands) = true
# Read the explicit optional sum flag on individual-band observations.
_occupied_sum_requested(selection::Union{BandTargets, AllBands}) = selection.include_occupied_sum
# Lower individual targets to the ordered singleton tuple expected by the numerical kernel.
_effective_band_selection(selection::BandTargets) = Tuple(selection.bands)
# Keep a single subspace grouped even when it contains only one band.
_effective_band_selection(selection::Subspace) = (copy(selection.bands),)
# Preserve each disjoint subspace as its own ordered target group.
_effective_band_selection(selection::Subspaces) = Tuple(copy.(selection.groups))
# Use the private sum-only sentinel for the explicit occupied observation.
_effective_band_selection(::OccupiedBands) = 0
# Use the private all-singletons sentinel while tracking sum output separately.
_effective_band_selection(::AllBands) = -1
# Lower the explicit conduction and valence channel without changing its order.
_effective_band_selection(selection::Transition) =
    (copy(selection.conduction), copy(selection.valence))
# Lower two disjoint geometry groups in their specified order.
_effective_band_selection(selection::InterbandGroups) =
    (copy(selection.first), copy(selection.second))
# Lower the three ordered phase-product groups to independent copied vectors.
_effective_band_selection(selection::TripleGroups) =
    (copy(selection.first), copy(selection.second), copy(selection.third))

# Resolve the task selector against the common sampling category and exact registry row.
function _public_task_identity(task::TaskSpec, sampling::AbstractSampling)
    calculation = _sampling_calculation(sampling)
    quantity = normalize_quantity(task.quantity)
    validate_quantity_short_label_calculation(task.quantity, quantity, calculation)
    method =
        task.method === nothing ? infer_single_supported_method(quantity, calculation) :
        normalize_method(task.method)
    definition = task_definition(quantity, method, calculation)
    definition === nothing && select_task(quantity, method, calculation)
    return quantity, method, calculation, definition
end

# Check the observable against the registered band policy and lower its tensor/band selection.
function _task_observation(task::TaskSpec, definition::TaskDefinition, calculation::Symbol)
    if _is_band_structure(definition)
        task.observable === nothing ||
            throw(ArgumentError("Band tasks do not accept response observables."))
        return (; tensor_indices = (), band_selection = -1, include_occupied_sum = false)
    elseif calculation == :integral
        task.observable isa Union{Nothing, FullTensor} ||
            throw(ArgumentError("Integral tasks support only FullTensor()."))
        return (;
            tensor_indices = ntuple(_ -> 1, Int(definition.tensor_rank)),
            band_selection = -1,
            include_occupied_sum = false,
        )
    end
    observation = task.observable
    observation isa KSliceSelection || throw(
        ArgumentError(
            "K-slice task $(task.id) requires KSliceSelection with an explicit component and band target.",
        ),
    )
    bands = observation.bands
    policy = definition.band_policy
    accepted = if definition.quantity == QUANTITY_HERMITIAN_CURVATURE_TENSOR
        bands isa InterbandGroups
    elseif policy == BAND_PAIR
        bands isa Transition
    elseif policy == BAND_RESOLVED
        bands isa Union{BandTargets, Subspace, Subspaces, AllBands, OccupiedBands}
    elseif policy == BAND_TARGET_GROUP
        bands isa Union{BandTargets, Subspace, Subspaces}
    elseif policy == BAND_INTERBAND_GROUPS
        bands isa InterbandGroups
    elseif policy == BAND_TRIPLE_GROUPS
        bands isa TripleGroups
    else
        false
    end
    accepted ||
        throw(ArgumentError("Band observation $(typeof(bands)) does not apply to task $(task.id)."))
    policy == BAND_RESOLVED ||
        !_occupied_sum_requested(bands) ||
        throw(ArgumentError("Task $(task.id) does not support an occupied sum."))
    return (;
        tensor_indices = observation.component.indices,
        band_selection = _effective_band_selection(bands),
        include_occupied_sum = _occupied_sum_requested(bands),
    )
end

const OPTICAL_TASK_QUANTITIES = (
    :shift_current,
    :injection_current,
    :injection_spin_current,
    :shift_spin_current,
    :photon_drag_shift_current,
    :photon_drag_injection_current,
)
const FINITE_DIFFERENCE_GEOMETRY_QUANTITIES = (
    :berry_curvature_dipole,
    :berry_curvature_quadrupole,
    :quantum_metric_dipole,
    :quantum_metric_quadrupole,
    :quantum_christoffel_symbol,
)

# Require a finite Fermi reference and a finite nonnegative absolute temperature.
function _validate_occupation_values(fermi_energy, temperature)
    isfinite(fermi_energy) || throw(ArgumentError("fermi_energy must be finite (eV)."))
    isfinite(temperature) && temperature >= 0 ||
        throw(ArgumentError("temperature must be finite and nonnegative (K)."))
end

# Require the physical inputs used by this response and reject inapplicable parameter groups.
function _task_physics(
    task::TaskSpec,
    quantity::Symbol,
    method::Symbol,
    definition::TaskDefinition,
    observation,
)
    physics = task.physics
    calculation = calculation_symbol(definition.calculation)
    if _is_band_structure(definition)
        physics isa BandParameters ||
            throw(ArgumentError("Band task $(task.id) requires BandParameters."))
        isfinite(physics.fermi_energy) || throw(ArgumentError("Band fermi_energy must be finite."))
        return (; fermi_energy = physics.fermi_energy, photon_energies = Float64[])
    elseif quantity in OPTICAL_TASK_QUANTITIES
        finite_q = quantity in (:photon_drag_shift_current, :photon_drag_injection_current)
        expected = finite_q ? FiniteQOpticalParameters : OpticalParameters
        physics isa expected || throw(ArgumentError("Task $(task.id) requires $(expected)."))
        _validate_occupation_values(physics.fermi_energy, physics.temperature)
        isempty(physics.photon_energies) &&
            throw(ArgumentError("Optical photon_energies must not be empty."))
        all(isfinite, physics.photon_energies) ||
            throw(ArgumentError("photon_energies must be finite (eV)."))
        calculation == :kslice &&
            length(physics.photon_energies) != 1 &&
            throw(ArgumentError("Optical K-slice requires exactly one photon energy."))
        momentum = finite_q ? physics.photon_momentum : (0.0, 0.0, 0.0)
        all(isfinite, momentum) || throw(ArgumentError("photon_momentum must be finite."))
        return (;
            photon_energies = copy(physics.photon_energies),
            fermi_energy = physics.fermi_energy,
            temperature = physics.temperature,
            photon_momentum = momentum,
        )
    end
    physics isa GeometryParameters || throw(
        ArgumentError(
            "Geometry task $(task.id) requires GeometryParameters, without optical placeholders.",
        ),
    )
    if observation.include_occupied_sum
        physics.fermi_energy !== nothing && physics.temperature !== nothing || throw(
            ArgumentError(
                "Occupied sum task $(task.id) requires explicit fermi_energy and temperature.",
            ),
        )
        _validate_occupation_values(physics.fermi_energy, physics.temperature)
    elseif physics.fermi_energy !== nothing || physics.temperature !== nothing
        throw(
            ArgumentError(
                "Task $(task.id) has no occupied-sum observable; occupation parameters do not apply.",
            ),
        )
    end
    allows_q =
        method == :geometric_loop && quantity in (:shift_vector, :quantum_hermitian_connection)
    physics.photon_momentum === nothing ||
        allows_q ||
        throw(ArgumentError("photon_momentum does not apply to task $(task.id)."))
    momentum = something(physics.photon_momentum, (0.0, 0.0, 0.0))
    all(isfinite, momentum) || throw(ArgumentError("photon_momentum must be finite."))
    return (;
        photon_energies = Float64[],
        fermi_energy = something(physics.fermi_energy, 0.0),
        temperature = something(physics.temperature, 0.0),
        photon_momentum = momentum,
    )
end

# Apply numerical defaults only within the task family and reject unused explicit controls.
function _task_numerical_values(
    task::TaskSpec,
    quantity::Symbol,
    method::Symbol,
    definition::TaskDefinition,
)
    calculation = calculation_symbol(definition.calculation)
    if _is_band_structure(definition)
        numerics = something(task.numerics, BandNumerics())
        numerics isa BandNumerics ||
            throw(ArgumentError("Band task $(task.id) requires BandNumerics."))
        return (; band_hermiticity_tolerance = numerics.hermiticity_tolerance)
    end
    optical = quantity in OPTICAL_TASK_QUANTITIES
    expected = optical ? OpticalNumerics : GeometryNumerics
    numerics = something(task.numerics, expected())
    numerics isa expected || throw(ArgumentError("Task $(task.id) requires $(expected)."))
    values = numerics.values
    uses_degeneracy =
        method != :conventional || definition.requires_spin || definition.requires_finite_q
    !uses_degeneracy &&
        :degeneracy_threshold in numerics.supplied &&
        throw(ArgumentError("degeneracy_threshold does not apply to task $(task.id)."))
    uses_fd = method != :conventional || quantity in FINITE_DIFFERENCE_GEOMETRY_QUANTITIES
    !uses_fd &&
        :finite_difference_step in numerics.supplied &&
        throw(ArgumentError("finite_difference_step does not apply to task $(task.id)."))
    if !optical && :band_window_size in numerics.supplied
        throw(
            ArgumentError(
                "Geometry tasks use explicit band observations; band_window_size does not apply.",
            ),
        )
    end
    fd = something(values.finite_difference_step, 0.0001)
    isfinite(fd) && fd > 0 ||
        throw(ArgumentError("finite_difference_step must be finite and positive."))
    for name in (:denominator_regularization, :degeneracy_threshold)
        value = getfield(values, name)
        value isa Real && isfinite(value) && value >= 0 ||
            throw(ArgumentError("$(name) must be finite and nonnegative."))
    end
    result = (;
        denominator_regularization = Float64(values.denominator_regularization),
        degeneracy_threshold = Float64(values.degeneracy_threshold),
        finite_difference_step = Float64(fd),
        band_window_size = Int(something(values.band_window_size, -1)),
    )
    if optical
        values.broadening isa Real && isfinite(values.broadening) && values.broadening > 0 ||
            throw(ArgumentError("broadening must be finite and positive (eV)."))
        values.broadening_type in ("Gaussian", "Lorentzian") ||
            throw(ArgumentError("broadening_type must be Gaussian or Lorentzian."))
        values.transition_window_factor isa Real && isfinite(values.transition_window_factor) ||
            throw(ArgumentError("transition_window_factor must be finite."))
        return merge(
            result,
            (;
                broadening = Float64(values.broadening),
                broadening_type = String(values.broadening_type),
                transition_window_factor = Float64(values.transition_window_factor),
            ),
        )
    end
    return result
end

"""Compile and validate one named task without reading model files or creating directories."""
function compile_task_config(cfg::TaskConfig, task::TaskSpec)
    occursin(r"^[A-Za-z0-9][A-Za-z0-9_-]*$", task.id) ||
        throw(ArgumentError("Invalid task id $(repr(task.id))."))
    (
        !isempty(strip(cfg.model.model_file)) ||
        !isempty(strip(cfg.model.seedname)) ||
        (
            cfg.model.real_space_operator_bundle_file !== nothing &&
            !isempty(strip(cfg.model.real_space_operator_bundle_file))
        )
    ) || throw(
        ArgumentError(
            "ModelInput requires an explicit model_file, seedname, or real_space_operator_bundle_file.",
        ),
    )
    quantity, method, calculation, definition = _public_task_identity(task, cfg.sampling)
    observation = _task_observation(task, definition, calculation)
    physics = _task_physics(task, quantity, method, definition, observation)
    numerics = _task_numerical_values(task, quantity, method, definition)
    case_root = resolve_case_root(cfg.model.case_root)
    output_parent =
        resolve_path(cfg.output.output_root, default_output_root(case_root); base = case_root)
    model_fields = _configuration_fields(cfg.model)
    bundle_absent =
        cfg.model.real_space_operator_bundle_file === nothing ||
        isempty(strip(cfg.model.real_space_operator_bundle_file))
    if isempty(strip(cfg.model.model_file)) && bundle_absent && !isempty(strip(cfg.model.seedname))
        seed_prefix = resolve_path(cfg.model.seedname, cfg.model.seedname; base = case_root)
        model_fields = merge(model_fields, (; model_file = seed_prefix * "_tb.dat"))
    end
    options = merge(
        model_fields,
        _sampling_fields(cfg.sampling),
        _configuration_fields(cfg.execution),
        _configuration_fields(cfg.output),
        observation,
        physics,
        numerics,
        (;
            tasks = [(
                canonical_quantity_name(quantity),
                canonical_method_name(method),
                canonical_calculation_name(calculation),
            )],
            output_root = joinpath(output_parent, task.id),
        ),
    )
    effective = EffectiveTaskConfig(; options...)
    validate_config(effective)
    return effective
end

"""Compile every task before execution; preserve request order and isolate output paths by ID."""
function compile_task_configs(cfg::TaskConfig)
    isempty(cfg.tasks) && throw(ArgumentError("TaskConfig requires at least one task."))
    ids = lowercase.([task.id for task in cfg.tasks])
    length(unique(ids)) == length(ids) || throw(ArgumentError("Task ids must be unique."))
    return EffectiveTaskConfig[compile_task_config(cfg, task) for task in cfg.tasks]
end

"""Validate the public independent-task configuration and return its normalized task identities."""
validate_config(cfg::TaskConfig) =
    [only(normalize_task_specs(effective)) for effective in compile_task_configs(cfg)]

# Summarize an explicit observation without leaking private band sentinels or dummy tensor indices.
function _task_observation_summary(task::TaskSpec, definition::TaskDefinition)
    calculation = calculation_symbol(definition.calculation)
    _is_band_structure(definition) && return (; kind = "band_spectrum")
    calculation == :integral && return (; kind = "full_tensor")
    observation = task.observable::KSliceSelection
    bands = observation.bands
    band_summary = if bands isa BandTargets
        (;
            kind = "individual_bands",
            bands = copy(bands.bands),
            include_occupied_sum = bands.include_occupied_sum,
        )
    elseif bands isa Subspace
        (; kind = "subspace", bands = copy(bands.bands))
    elseif bands isa Subspaces
        (; kind = "subspaces", groups = deepcopy(bands.groups))
    elseif bands isa OccupiedBands
        (; kind = "occupied_sum")
    elseif bands isa AllBands
        (; kind = "all_individual_bands", include_occupied_sum = bands.include_occupied_sum)
    elseif bands isa Transition
        (; kind = "transition", conduction = copy(bands.conduction), valence = copy(bands.valence))
    elseif bands isa InterbandGroups
        (; kind = "interband_groups", first = copy(bands.first), second = copy(bands.second))
    else
        (;
            kind = "triple_groups",
            first = copy(bands.first),
            second = copy(bands.second),
            third = copy(bands.third),
        )
    end
    return (; kind = "kslice", component = observation.component.indices, bands = band_summary)
end

"""Return the validated effective public parameters, excluding private unused placeholders; perform no IO."""
function task_parameter_summary(cfg::TaskConfig, task::TaskSpec)
    effective = compile_task_config(cfg, task)
    quantity, method, calculation, definition = _public_task_identity(task, cfg.sampling)
    optical = quantity in OPTICAL_TASK_QUANTITIES
    physical = if _is_band_structure(definition)
        (; fermi_energy = effective.fermi_energy)
    elseif optical
        base = (;
            photon_energies = copy(effective.photon_energies),
            fermi_energy = effective.fermi_energy,
            temperature = effective.temperature,
        )
        task.physics isa FiniteQOpticalParameters ?
        merge(base, (; photon_momentum = effective.photon_momentum)) : base
    else
        base =
            effective.include_occupied_sum ?
            (; fermi_energy = effective.fermi_energy, temperature = effective.temperature) :
            NamedTuple()
        method == :geometric_loop &&
            quantity in (:shift_vector, :quantum_hermitian_connection) ?
        merge(base, (; photon_momentum = effective.photon_momentum)) : base
    end
    numerical = if _is_band_structure(definition)
        (; hermiticity_tolerance = effective.band_hermiticity_tolerance)
    else
        base = (; denominator_regularization = effective.denominator_regularization)
        if method != :conventional || definition.requires_spin || definition.requires_finite_q
            base = merge(base, (; degeneracy_threshold = effective.degeneracy_threshold))
        end
        if method != :conventional || quantity in FINITE_DIFFERENCE_GEOMETRY_QUANTITIES
            base = merge(base, (; finite_difference_step = effective.finite_difference_step))
        end
        if optical
            base = merge(
                base,
                (;
                    broadening = effective.broadening,
                    broadening_type = effective.broadening_type,
                    transition_window_factor = effective.transition_window_factor,
                    band_window_size = effective.band_window_size,
                ),
            )
        end
        base
    end
    return (;
        id = task.id,
        quantity = canonical_quantity_name(quantity),
        method = canonical_method_name(method),
        calculation = canonical_calculation_name(calculation),
        physics = physical,
        numerics = numerical,
        observable = _task_observation_summary(task, definition),
        output_root = effective.output_root,
    )
end

"""Return the effective public parameter summary for a task at its original request index."""
task_parameter_summary(cfg::TaskConfig, index::Integer) =
    task_parameter_summary(cfg, cfg.tasks[index])
