# Canonical downstream-task operator requirements shared by the Wannierization export
# path and the Runtime consumption path.  This file is the single dependency contract
# for task-derived real-space operator selection: it is audited against the live
# response task registry and matrix-element plan. Runtime resolves its normalized
# requests through this contract; regression tests check live registry coverage.

using SHA

"""One downstream response task used to derive a required real-space operator inventory."""
Base.@kwdef struct OperatorTask
    quantity::Symbol
    method::Symbol = :all
end

"""Identified failure raised while normalizing or resolving task-derived operator selection."""
struct OperatorSelectionError <: Exception
    code::String
    message::String
end

"""Render an operator-selection failure as `CODE: message`."""
function Base.showerror(io::IO, error::OperatorSelectionError)
    return print(io, error.code, ": ", error.message)
end

"""Registry version bound into task-derived operator-selection provenance."""
const OPERATOR_REQUIREMENT_REGISTRY_VERSION = "1.0"

"""Canonical source-file vocabulary for task-derived operator generation, in stable order."""
const OPERATOR_TASK_SOURCE_REGISTRY = (
    :mmn,
    :chk,
    :eig,
    :spn,
    :uiu,
    :uhu,
    :siu,
    :shu,
    :authoritative_hamiltonian,
    :operator_target_contract,
)

"""
Derived matrix-element capabilities reconstructible from persisted operators.

`BERRY_CONNECTION` and its prerequisites are Runtime `MatrixElementKind` capabilities,
not persisted `RealSpaceOperatorKind` values.  Each entry names one derived capability
and the minimal persisted real-space operators that reconstruct it, so a geometry
selection can persist only `hamiltonian` and `position` and still derive
`internal_connection`, `gauge_correction`, and `berry_connection`.  A method whose
dependency closure cannot be reconstructed from these operators must be rejected at
registration instead of being guessed.
"""
const OPERATOR_TASK_DERIVED_CAPABILITIES = (
    internal_connection = (REAL_SPACE_POSITION, REAL_SPACE_HAMILTONIAN),
    gauge_correction = (REAL_SPACE_HAMILTONIAN,),
    berry_connection = (REAL_SPACE_POSITION, REAL_SPACE_HAMILTONIAN),
)

"""
Upstream source closure of one real-space Wannier operator.

Each entry lists every source artifact that must exist before the operator can be
generated in the final Wannier gauge. `:mmn`, `:chk`, and `:eig` are the shared
spectrum inputs; `:authoritative_hamiltonian` is the digest-bound authoritative band
Hamiltonian whose native or symmetrized backend, digest, and input SHA-256 are
resolved at configuration time and recorded in manifest provenance;
`:operator_target_contract` is the qualified-source delivery contract.
"""
const OPERATOR_SOURCE_CLOSURES = Dict{RealSpaceOperatorKind, Tuple}(
    REAL_SPACE_HAMILTONIAN => (:mmn, :chk, :eig, :authoritative_hamiltonian),
    REAL_SPACE_POSITION => (:mmn, :chk, :eig),
    REAL_SPACE_HAMILTONIAN_WEIGHTED_CONNECTION =>
        (:mmn, :chk, :eig, :authoritative_hamiltonian, :operator_target_contract),
    REAL_SPACE_HAMILTONIAN_WEIGHTED_AXIAL_DERIVATIVE_OVERLAP =>
        (:mmn, :chk, :eig, :authoritative_hamiltonian, :uhu, :operator_target_contract),
    REAL_SPACE_DERIVATIVE_OVERLAP_TENSOR => (:mmn, :chk, :eig, :uiu, :operator_target_contract),
    REAL_SPACE_AXIAL_DERIVATIVE_OVERLAP => (:mmn, :chk, :eig, :uiu, :operator_target_contract),
    REAL_SPACE_SYMMETRIC_DERIVATIVE_OVERLAP =>
        (:mmn, :chk, :eig, :uiu, :operator_target_contract),
    REAL_SPACE_SPIN => (:mmn, :chk, :eig, :spn),
    REAL_SPACE_SPIN_TIMES_HAMILTONIAN =>
        (:mmn, :chk, :eig, :spn, :authoritative_hamiltonian, :operator_target_contract),
    REAL_SPACE_SPIN_TIMES_POSITION => (:mmn, :chk, :eig, :spn, :siu, :operator_target_contract),
    REAL_SPACE_SPIN_TIMES_HAMILTONIAN_POSITION =>
        (:mmn, :chk, :eig, :spn, :shu, :authoritative_hamiltonian, :operator_target_contract),
)

"""One registered downstream task and the operator/source inventory it requires."""
struct OperatorTaskRequirement
    quantity::Symbol
    method::Symbol
    required_operators::Tuple
    required_sources::Tuple
end

"""Return an inventory in `REAL_SPACE_OPERATOR_REGISTRY` order after rejecting duplicates."""
function _canonical_requirement_operators(operators)
    kinds = RealSpaceOperatorKind[operators...]
    length(unique(kinds)) == length(kinds) ||
        throw(ArgumentError("operator requirement contains duplicate kinds"))
    requested = Set(kinds)
    return Tuple(kind for kind in REAL_SPACE_OPERATOR_REGISTRY if kind in requested)
end

"""Return a source closure in `OPERATOR_TASK_SOURCE_REGISTRY` order after rejecting unknowns."""
function _canonical_requirement_sources(sources)
    requested = Set{Symbol}(sources)
    for source in requested
        source in OPERATOR_TASK_SOURCE_REGISTRY ||
            throw(ArgumentError("unsupported operator-task source $(source)"))
    end
    return Tuple(source for source in OPERATOR_TASK_SOURCE_REGISTRY if source in requested)
end

# Build one registry row and derive its source closure from the operator source table.
function _operator_task_requirement(quantity::Symbol, method::Symbol, operators)
    canonical = _canonical_requirement_operators(operators)
    isempty(canonical) && throw(ArgumentError("operator requirement must not be empty"))
    sources = Symbol[]
    for kind in canonical, source in OPERATOR_SOURCE_CLOSURES[kind]
        source in sources || push!(sources, source)
    end
    return OperatorTaskRequirement(
        quantity,
        method,
        canonical,
        _canonical_requirement_sources(sources),
    )
end

# Spectrum/geometry-only rows: authoritative Hamiltonian plus Wannier gauge only.
const _OPERATOR_TASK_SPECTRUM_OPERATORS = (REAL_SPACE_HAMILTONIAN, REAL_SPACE_POSITION)

# Full spin-current family: SPN plus the complete spin-velocity chain.
const _OPERATOR_TASK_SPIN_CURRENT_OPERATORS = (
    REAL_SPACE_HAMILTONIAN,
    REAL_SPACE_POSITION,
    REAL_SPACE_SPIN,
    REAL_SPACE_SPIN_TIMES_HAMILTONIAN,
    REAL_SPACE_SPIN_TIMES_POSITION,
    REAL_SPACE_SPIN_TIMES_HAMILTONIAN_POSITION,
)

# Projector geometry rows: the exact full derivative-overlap tensor is required.
const _OPERATOR_TASK_PROJECTOR_GEOMETRY_OPERATORS =
    (REAL_SPACE_HAMILTONIAN, REAL_SPACE_POSITION, REAL_SPACE_DERIVATIVE_OVERLAP_TENSOR)

# Orbital-magnetization rows: the five final Wannier-gauge operators only.
const _OPERATOR_TASK_ORBITAL_MAGNETIZATION_OPERATORS = (
    REAL_SPACE_HAMILTONIAN,
    REAL_SPACE_POSITION,
    REAL_SPACE_HAMILTONIAN_WEIGHTED_CONNECTION,
    REAL_SPACE_DERIVATIVE_OVERLAP_TENSOR,
    REAL_SPACE_HAMILTONIAN_WEIGHTED_AXIAL_DERIVATIVE_OVERLAP,
)

# Zeeman interband geometry: Berry connection plus the spin operator.
const _OPERATOR_TASK_ZEEMAN_OPERATORS =
    (REAL_SPACE_HAMILTONIAN, REAL_SPACE_POSITION, REAL_SPACE_SPIN)

"""
Canonical task-to-operator requirement registry.

Every row is audited against the live response task registry and the compiled
matrix-element plan; the operator inventory is the static superset that a
downstream response actually consumes, including the orbital-magnetization
weighted operators that Runtime adds for the physical (non-`defined_finite_model`)
input semantics.
"""
const OPERATOR_TASK_REQUIREMENTS = (
    _operator_task_requirement(:band_structure, :conventional, _OPERATOR_TASK_SPECTRUM_OPERATORS),
    _operator_task_requirement(:berry_curvature, :conventional, _OPERATOR_TASK_SPECTRUM_OPERATORS),
    _operator_task_requirement(
        :berry_curvature_dipole,
        :conventional,
        _OPERATOR_TASK_SPECTRUM_OPERATORS,
    ),
    _operator_task_requirement(
        :berry_curvature_quadrupole,
        :conventional,
        _OPERATOR_TASK_SPECTRUM_OPERATORS,
    ),
    _operator_task_requirement(
        :hermitian_curvature_tensor,
        :conventional,
        _OPERATOR_TASK_SPECTRUM_OPERATORS,
    ),
    _operator_task_requirement(
        :injection_current,
        :conventional,
        _OPERATOR_TASK_SPECTRUM_OPERATORS,
    ),
    _operator_task_requirement(
        :injection_spin_current,
        :conventional,
        _OPERATOR_TASK_SPIN_CURRENT_OPERATORS,
    ),
    _operator_task_requirement(
        :interband_berry_curvature,
        :conventional,
        _OPERATOR_TASK_SPECTRUM_OPERATORS,
    ),
    _operator_task_requirement(
        :interband_quantum_metric,
        :conventional,
        _OPERATOR_TASK_SPECTRUM_OPERATORS,
    ),
    _operator_task_requirement(
        :linear_optical_response,
        :conventional,
        _OPERATOR_TASK_SPECTRUM_OPERATORS,
    ),
    _operator_task_requirement(
        :linear_optical_response,
        :projector,
        _OPERATOR_TASK_SPECTRUM_OPERATORS,
    ),
    _operator_task_requirement(:linear_transport, :conventional, _OPERATOR_TASK_SPECTRUM_OPERATORS),
    _operator_task_requirement(:linear_transport, :projector, _OPERATOR_TASK_SPECTRUM_OPERATORS),
    _operator_task_requirement(
        :orbital_magnetization,
        :conventional,
        _OPERATOR_TASK_ORBITAL_MAGNETIZATION_OPERATORS,
    ),
    _operator_task_requirement(
        :orbital_magnetization,
        :projector,
        _OPERATOR_TASK_ORBITAL_MAGNETIZATION_OPERATORS,
    ),
    _operator_task_requirement(
        :photon_drag_injection_current,
        :conventional,
        _OPERATOR_TASK_SPECTRUM_OPERATORS,
    ),
    _operator_task_requirement(
        :photon_drag_shift_current,
        :geometric_loop,
        _OPERATOR_TASK_SPECTRUM_OPERATORS,
    ),
    _operator_task_requirement(
        :quantum_christoffel_symbol,
        :conventional,
        _OPERATOR_TASK_SPECTRUM_OPERATORS,
    ),
    _operator_task_requirement(
        :quantum_hermitian_connection,
        :conventional,
        _OPERATOR_TASK_SPECTRUM_OPERATORS,
    ),
    _operator_task_requirement(
        :quantum_hermitian_connection,
        :geometric_loop,
        _OPERATOR_TASK_SPECTRUM_OPERATORS,
    ),
    _operator_task_requirement(
        :quantum_hermitian_connection,
        :projector,
        _OPERATOR_TASK_PROJECTOR_GEOMETRY_OPERATORS,
    ),
    _operator_task_requirement(
        :quantum_hermitian_connection,
        :wilson_loop,
        _OPERATOR_TASK_SPECTRUM_OPERATORS,
    ),
    _operator_task_requirement(:quantum_metric, :conventional, _OPERATOR_TASK_SPECTRUM_OPERATORS),
    _operator_task_requirement(
        :quantum_metric_dipole,
        :conventional,
        _OPERATOR_TASK_SPECTRUM_OPERATORS,
    ),
    _operator_task_requirement(
        :quantum_metric_quadrupole,
        :conventional,
        _OPERATOR_TASK_SPECTRUM_OPERATORS,
    ),
    _operator_task_requirement(
        :second_harmonic_generation,
        :conventional,
        _OPERATOR_TASK_SPECTRUM_OPERATORS,
    ),
    _operator_task_requirement(:shift_current, :conventional, _OPERATOR_TASK_SPECTRUM_OPERATORS),
    _operator_task_requirement(:shift_current, :geometric_loop, _OPERATOR_TASK_SPECTRUM_OPERATORS),
    _operator_task_requirement(
        :shift_current,
        :projector,
        _OPERATOR_TASK_PROJECTOR_GEOMETRY_OPERATORS,
    ),
    _operator_task_requirement(:shift_current, :wilson_loop, _OPERATOR_TASK_SPECTRUM_OPERATORS),
    _operator_task_requirement(
        :shift_spin_current,
        :conventional,
        _OPERATOR_TASK_SPIN_CURRENT_OPERATORS,
    ),
    _operator_task_requirement(:shift_vector, :geometric_loop, _OPERATOR_TASK_SPECTRUM_OPERATORS),
    _operator_task_requirement(:shift_vector, :wilson_loop, _OPERATOR_TASK_SPECTRUM_OPERATORS),
    _operator_task_requirement(
        :triple_phase_product,
        :conventional,
        _OPERATOR_TASK_SPECTRUM_OPERATORS,
    ),
    _operator_task_requirement(
        :zeeman_interband_berry_curvature,
        :conventional,
        _OPERATOR_TASK_ZEEMAN_OPERATORS,
    ),
    _operator_task_requirement(
        :zeeman_interband_quantum_metric,
        :conventional,
        _OPERATOR_TASK_ZEEMAN_OPERATORS,
    ),
)

"""Look up one registered task requirement, or return `nothing` when unregistered."""
function operator_task_requirement(quantity::Symbol, method::Symbol)
    for requirement in OPERATOR_TASK_REQUIREMENTS
        requirement.quantity == quantity && requirement.method == method && return requirement
    end
    return nothing
end

"""Return every registered method symbol for one quantity in registry order."""
function registered_operator_task_methods(quantity::Symbol)
    return Symbol[
        requirement.method for
        requirement in OPERATOR_TASK_REQUIREMENTS if requirement.quantity == quantity
    ]
end

"""Return the distinct registered quantity symbols in registry order."""
function registered_operator_task_quantities()
    quantities = Symbol[]
    for requirement in OPERATOR_TASK_REQUIREMENTS
        requirement.quantity in quantities || push!(quantities, requirement.quantity)
    end
    return quantities
end

"""
Return the derived matrix-element capabilities that one persisted operator inventory
reconstructs.

A capability is reported only when every persisted operator named in
`OPERATOR_TASK_DERIVED_CAPABILITIES` is present, so a geometry selection that persists
only `hamiltonian` and `position` still reports `internal_connection`,
`gauge_correction`, and `berry_connection`.
"""
function derived_operator_capabilities(inventory)
    kinds = Set(RealSpaceOperatorKind[inventory...])
    capabilities = Symbol[]
    for (capability, required) in pairs(OPERATOR_TASK_DERIVED_CAPABILITIES)
        all(kind -> kind in kinds, required) && push!(capabilities, capability)
    end
    return capabilities
end

# Normalize one task entry into a concrete `OperatorTask` and reject malformed input.
function _normalize_operator_task(task::OperatorTask)
    quantity = task.quantity isa Symbol ? task.quantity : Symbol(task.quantity)
    method = task.method isa Symbol ? task.method : Symbol(task.method)
    return OperatorTask(quantity = quantity, method = method)
end

# Expand one normalized task into the concrete registry rows it selects.
function _expand_operator_task(task::OperatorTask)
    available = registered_operator_task_methods(task.quantity)
    isempty(available) && throw(
        OperatorSelectionError(
            "UNSUPPORTED_OPERATOR_TASK",
            "quantity=:$(task.quantity) has no registered task-derived operator requirement",
        ),
    )
    if task.method == :all
        return OperatorTaskRequirement[
            something(operator_task_requirement(task.quantity, method)) for method in available
        ]
    end
    requirement = operator_task_requirement(task.quantity, task.method)
    requirement === nothing && throw(
        OperatorSelectionError(
            "UNSUPPORTED_OPERATOR_TASK_METHOD",
            "method=:$(task.method) is not registered for quantity=:$(task.quantity); " *
            "registered methods: $(join(String.(available), ", "))",
        ),
    )
    return OperatorTaskRequirement[requirement]
end

# Canonical selection digest over normalized tasks, resolved operators, and resolved sources.
function _operator_selection_digest(tasks, required_operators, required_sources)
    buffer = IOBuffer()
    print(buffer, "wanniernlqg.operator-task-selection\n")
    print(buffer, "registry_version\t", OPERATOR_REQUIREMENT_REGISTRY_VERSION, "\n")
    for (quantity, method) in tasks
        print(buffer, "task\t", quantity, "\t", method, "\n")
    end
    print(buffer, "operators\t", join(real_space_operator_name.(required_operators), ","), "\n")
    print(buffer, "sources\t", join(String.(required_sources), ","), "\n")
    return bytes2hex(sha256(take!(buffer)))
end

"""
Resolve one or more downstream tasks into the deterministic union of required
real-space operators and upstream sources.

Normalization accepts `OperatorTask` values, expands
`method=:all` to the union over every registered method of that quantity, unions
operators and sources across tasks, returns both in canonical registry order, and
records the per-task dependency closure. The result and its SHA-256 do not depend
on the order in which tasks were supplied.

Runtime may explicitly select `orbital_input_semantics=:defined_finite_model`.
Only OAM rows then use the closed finite-model H/position reconstruction; all
other tasks retain their registered inputs. Export uses the default and always
requires the five OAM operators.
"""
function resolve_operator_requirements(
    operator_tasks;
    orbital_input_semantics::Symbol = :unspecified,
)
    entries = OperatorTask[_normalize_operator_task(task) for task in operator_tasks]
    isempty(entries) && throw(
        OperatorSelectionError(
            "EMPTY_OPERATOR_TASK_SELECTION",
            "operator_tasks must contain at least one OperatorTask",
        ),
    )
    expanded = Dict{Tuple{Symbol, Symbol}, Vector{OperatorTaskRequirement}}()
    order = Tuple{Symbol, Symbol}[]
    for entry in entries
        key = (entry.quantity, entry.method)
        haskey(expanded, key) && continue
        expanded[key] = _expand_operator_task(entry)
        push!(order, key)
    end
    normalized = sort!(order; by = key -> (String(key[1]), String(key[2])))
    operators = RealSpaceOperatorKind[]
    sources = Symbol[]
    closure = NamedTuple[]
    for (quantity, method) in normalized
        task_operators = RealSpaceOperatorKind[]
        task_sources = Symbol[]
        for requirement in expanded[(quantity, method)]
            required =
                if requirement.quantity == :orbital_magnetization &&
                   orbital_input_semantics == :defined_finite_model
                    _OPERATOR_TASK_SPECTRUM_OPERATORS
                else
                    requirement.required_operators
                end
            for kind in required
                kind in task_operators || push!(task_operators, kind)
                kind in operators || push!(operators, kind)
                for source in OPERATOR_SOURCE_CLOSURES[kind]
                    source in task_sources || push!(task_sources, source)
                    source in sources || push!(sources, source)
                end
            end
        end
        push!(
            closure,
            (
                quantity = quantity,
                method = method,
                expanded_methods = Tuple(
                    requirement.method for requirement in expanded[(quantity, method)]
                ),
                required_operators = _canonical_requirement_operators(task_operators),
                required_sources = _canonical_requirement_sources(task_sources),
            ),
        )
    end
    required_operators = _canonical_requirement_operators(operators)
    required_sources = _canonical_requirement_sources(sources)
    tasks = Tuple(normalized)
    return (
        tasks = tasks,
        closure = Tuple(closure),
        required_operators = required_operators,
        required_sources = required_sources,
        registry_version = OPERATOR_REQUIREMENT_REGISTRY_VERSION,
        selection_sha256 = _operator_selection_digest(tasks, required_operators, required_sources),
    )
end

# Minimal persisted source closure of a geometry/spectrum task: the authoritative
# Hamiltonian plus the shared Wannier gauge.  Berry/internal connection and gauge
# correction are derived from these operators, never persisted separately.
const _OPERATOR_TASK_GEOMETRY_SOURCES = (:mmn, :chk, :eig, :authoritative_hamiltonian)

# Load-time self-check: the orbital-magnetization closure must be exactly five operators
# and must not require SPN or any spin-family source; every registered row must bind the
# authoritative Hamiltonian; and every geometry row must persist only the minimal
# Hamiltonian-plus-position inventory from which the Berry-connection family is derived.
function _validate_operator_task_requirements()
    orbital = resolve_operator_requirements((OperatorTask(quantity = :orbital_magnetization),))
    expected = Tuple(
        kind for kind in REAL_SPACE_OPERATOR_REGISTRY if kind in Set((
            REAL_SPACE_HAMILTONIAN,
            REAL_SPACE_POSITION,
            REAL_SPACE_HAMILTONIAN_WEIGHTED_CONNECTION,
            REAL_SPACE_DERIVATIVE_OVERLAP_TENSOR,
            REAL_SPACE_HAMILTONIAN_WEIGHTED_AXIAL_DERIVATIVE_OVERLAP,
        ),)
    )
    orbital.required_operators == expected || error(
        "operator task registry self-check failed: orbital magnetization must resolve to " *
        "exactly five operators",
    )
    for forbidden in (:spn, :siu, :shu)
        forbidden in orbital.required_sources && error(
            "operator task registry self-check failed: orbital magnetization must not require " *
            "source $(forbidden)",
        )
    end
    for kind in (
        REAL_SPACE_SPIN,
        REAL_SPACE_SPIN_TIMES_HAMILTONIAN,
        REAL_SPACE_SPIN_TIMES_POSITION,
        REAL_SPACE_SPIN_TIMES_HAMILTONIAN_POSITION,
        REAL_SPACE_AXIAL_DERIVATIVE_OVERLAP,
        REAL_SPACE_SYMMETRIC_DERIVATIVE_OVERLAP,
    )
        kind in orbital.required_operators && error(
            "operator task registry self-check failed: orbital magnetization must not require " *
            "$(real_space_operator_name(kind))",
        )
    end
    geometry_sources = _canonical_requirement_sources(_OPERATOR_TASK_GEOMETRY_SOURCES)
    geometry_operators = _canonical_requirement_operators(_OPERATOR_TASK_SPECTRUM_OPERATORS)
    for requirement in OPERATOR_TASK_REQUIREMENTS
        label = "$(requirement.quantity)/$(requirement.method)"
        :authoritative_hamiltonian in requirement.required_sources || error(
            "operator task registry self-check failed: $(label) must bind the " *
            "authoritative Hamiltonian source",
        )
        requirement.required_operators == geometry_operators || continue
        requirement.required_sources == geometry_sources || error(
            "operator task registry self-check failed: geometry task $(label) must persist " *
            "only the minimal hamiltonian/position source closure",
        )
        for forbidden in (:uiu, :uhu, :spn, :siu, :shu, :operator_target_contract)
            forbidden in requirement.required_sources && error(
                "operator task registry self-check failed: geometry task $(label) must not " *
                "require source $(forbidden)",
            )
        end
    end
    return nothing
end

_validate_operator_task_requirements()
