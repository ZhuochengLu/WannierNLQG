"""
Cold data demand for a Wannier construction, projection, or mesh workflow.

This record selects readers before payload loading. It does not certify source
consistency, backend projection support, grid completeness, or solver validity.
`operators` is the canonical persisted operator inventory, not a response request.
"""
struct WannierWorkflowDataRequirements{Operators <: Tuple}
    workflow::Symbol
    mode::Symbol
    matrix_route::Symbol
    structure::Bool
    kmesh::Bool
    spin_metadata::Bool
    projection_basis::Bool
    physical_metric::Bool
    wavefunction_coefficients::Bool
    existing_model::Bool
    operators::Operators
end

# Resolve export demand through the existing Core registry, without running responses.
function _wannier_workflow_output_operators(profile, operator_tasks)
    if operator_tasks !== nothing
        profile === nothing ||
            throw(ArgumentError("output.profile and operator_tasks are mutually exclusive"))
        return resolve_operator_requirements(operator_tasks).required_operators
    end
    selected = profile === nothing ? :hamiltonian_position : profile
    selected == :hamiltonian_position && return (REAL_SPACE_HAMILTONIAN, REAL_SPACE_POSITION)
    selected == :full && return REAL_SPACE_OPERATOR_REGISTRY
    throw(ArgumentError("output.profile must be hamiltonian_position or full"))
end

"""
Plan workflow reader requirements without file-existence probes or payload reads.

`source_kind` is `nothing`, `:qe`, or `:vasp`; explicit structure and k-mesh
availability are independent. `external_matrices` denotes the presence of the
external basic EIG/MMN/AMN section, even if its files do not exist. SAWF and
extended exports always require one native source and reject that section.

For projection, `model_operators` must be the input model's actual inventory;
this planner neither drops operators nor claims that every inventory is supported
by the projection backend. Projection requires no k mesh or wavefunctions.
"""
function plan_wannier_workflow_data(
    workflow::Symbol;
    mode::Union{Nothing, Symbol} = nothing,
    source_kind::Union{Nothing, Symbol} = nothing,
    explicit_structure::Bool = false,
    explicit_kmesh::Bool = false,
    external_matrices::Bool = false,
    profile::Union{Nothing, Symbol} = nothing,
    operator_tasks = nothing,
    model_operators::Union{Nothing, Tuple} = nothing,
)
    source_kind in (nothing, :qe, :vasp) || throw(ArgumentError("source.kind must be qe or vasp"))
    native_source = source_kind !== nothing
    native_source ||
        explicit_structure ||
        throw(ArgumentError("workflow requires source metadata or explicit structure"))

    if workflow == :wannierization
        mode in (:ordinary, :symmetry_adapted) ||
            throw(ArgumentError("wannierization.mode must be ordinary or symmetry_adapted"))
        model_operators === nothing ||
            throw(ArgumentError("wannierization does not consume an existing model inventory"))
        operators = _wannier_workflow_output_operators(profile, operator_tasks)
        extended = any(kind -> kind ∉ (REAL_SPACE_HAMILTONIAN, REAL_SPACE_POSITION), operators)
        require_native = mode == :symmetry_adapted || extended || profile == :full
        require_native &&
            external_matrices &&
            throw(
                ArgumentError(
                    "SAWF and extended output forbid external matrices; use one native source",
                ),
            )
        native = require_native || !external_matrices
        native &&
            !native_source &&
            throw(ArgumentError("native Wannierization requires source.kind=qe or vasp"))
        native_source ||
            explicit_kmesh ||
            throw(ArgumentError("external Wannierization requires actual k-point metadata"))
        return WannierWorkflowDataRequirements(
            workflow,
            mode,
            native ? :native : :external_basic,
            true,
            true,
            true,
            true,
            native,
            native,
            false,
            operators,
        )
    elseif workflow == :symmetrization
        mode in (nothing, :projection) ||
            throw(ArgumentError("symmetrization.mode only supports projection"))
        external_matrices &&
            throw(ArgumentError("projection consumes an existing model, not matrices"))
        profile === nothing && operator_tasks === nothing ||
            throw(ArgumentError("projection uses the model's actual operator inventory"))
        model_operators === nothing &&
            throw(ArgumentError("projection requires the actual input model operator inventory"))
        isempty(model_operators) && throw(ArgumentError("input model operator inventory is empty"))
        all(
            kind -> kind isa RealSpaceOperatorKind && kind in REAL_SPACE_OPERATOR_REGISTRY,
            model_operators,
        ) || throw(ArgumentError("input model contains an unknown operator identity"))
        length(unique(model_operators)) == length(model_operators) ||
            throw(ArgumentError("input model operator inventory contains duplicates"))
        operators = Tuple(kind for kind in REAL_SPACE_OPERATOR_REGISTRY if kind in model_operators)
        return WannierWorkflowDataRequirements(
            workflow,
            :projection,
            :existing_model,
            true,
            false,
            true,
            true,
            false,
            false,
            true,
            operators,
        )
    elseif workflow == :mesh_screening
        mode === nothing || throw(ArgumentError("mesh_screening has no mode selector"))
        external_matrices && throw(ArgumentError("mesh_screening does not consume matrices"))
        profile === nothing && operator_tasks === nothing && model_operators === nothing ||
            throw(ArgumentError("mesh_screening does not generate or consume model operators"))
        native_source ||
            explicit_kmesh ||
            throw(
                ArgumentError(
                    "mesh_screening requires actual points or an explicit grid specification",
                ),
            )
        return WannierWorkflowDataRequirements(
            workflow,
            :screening,
            :none,
            true,
            true,
            true,
            false,
            false,
            false,
            false,
            (),
        )
    end
    throw(ArgumentError("unsupported Wannier workflow=$workflow"))
end
