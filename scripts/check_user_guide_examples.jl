using WannierNLQG

const ROOT = normpath(joinpath(@__DIR__, ".."))
const EXAMPLE_ROOT = joinpath(ROOT, "examples", "tasks")
const EXPECTED_TASK_COUNT = 38
const CURRENT_QUANTITIES = Set((
    :shift_current,
    :photon_drag_shift_current,
    :injection_current,
    :injection_spin_current,
    :shift_spin_current,
    :photon_drag_injection_current,
))

"""Fail a guide/example contract with a precise audit diagnostic."""
function audit_check(condition::Bool, message::AbstractString)
    condition || error("User-guide audit failed: $(message)")
    return nothing
end

"""Read the canonical response identity represented by a task registry definition."""
function task_symbols(definition)
    runtime = WannierNLQG.Runtime
    return (
        runtime.quantity_symbol(definition.quantity),
        runtime.method_symbol(definition.method),
        runtime.calculation_symbol(definition.calculation),
    )
end

"""Map each registered task to its unique maintained public example."""
function task_example_relative_path(definition)
    quantity, method, calculation = task_symbols(definition)
    definition.executor == WannierNLQG.Runtime.EXECUTOR_BAND_STRUCTURE &&
        return joinpath("examples", "tasks", "band", "band_structure.jl")
    return joinpath("examples", "tasks", String(calculation), "$(quantity)_$(method).jl")
end

"""Load an example in isolation without triggering its guarded execution entrypoint."""
function include_example(path::AbstractString, index::Int)
    example_module = Module(Symbol("DocumentedTaskExample", index))
    Core.eval(example_module, :(include(path::AbstractString) = Base.include(@__MODULE__, path)))
    Base.include(example_module, path)
    isdefined(example_module, :build_config) || error("$(path) does not define build_config()")
    config = Base.invokelatest(getfield(example_module, :build_config))
    return example_module, config
end

"""Require grouped input documentation and one live link for every task example."""
function audit_guides(definitions)
    text = read(joinpath(ROOT, "USER_GUIDE.md"), String)
    for name in (
        "TaskConfig",
        "TaskSpec",
        "ModelInput",
        "BZMesh",
        "KSlice",
        "KPath",
        "OpticalParameters",
        "FiniteQOpticalParameters",
        "GeometryParameters",
        "BandParameters",
        "OpticalNumerics",
        "GeometryNumerics",
        "BandNumerics",
        "ExecutionOptions",
        "OutputOptions",
        "FullTensor",
        "KSliceSelection",
        "TensorComponent",
        "BandTargets",
        "Subspace",
        "Subspaces",
        "AllBands",
        "OccupiedBands",
        "Transition",
        "InterbandGroups",
        "TripleGroups",
    )
        audit_check(occursin("`$(name)", text), "user guide does not document $(name)")
    end
    for definition in definitions
        relative = task_example_relative_path(definition)
        audit_check(isfile(joinpath(ROOT, relative)), "missing task example $(relative)")
        audit_check(count("]($(relative))", text) == 1, "guide must link $(relative) exactly once")
    end
    audit_check(occursin("2 by 2", text), "guide must distinguish an explicit smoke mesh")
    audit_check(occursin("100 by", text), "guide must describe ordinary demonstration meshes")
    return nothing
end

"""Compile every example and check its registry, physical-input and preset contracts."""
function audit_examples(definitions)
    files = sort([
        joinpath(directory, name) for (directory, _, names) in walkdir(EXAMPLE_ROOT) for
        name in names if endswith(name, ".jl")
    ])
    expected =
        sort([joinpath(ROOT, task_example_relative_path(definition)) for definition in definitions])
    audit_check(files == expected, "examples do not map one-to-one to the task registry")
    audit_check(length(files) == EXPECTED_TASK_COUNT, "unexpected task example count")
    helper = read(joinpath(ROOT, "examples", "ExampleSupport.jl"), String)
    audit_check(!occursin("photon_energies", helper), "helper must not hide physical energy inputs")
    output_roots = String[]
    for (index, definition) in enumerate(definitions)
        path = joinpath(ROOT, task_example_relative_path(definition))
        text = read(path, String)
        _, config = include_example(path, index)
        audit_check(
            config isa WannierNLQG.TaskConfig,
            "example must build the public grouped config",
        )
        effective = only(Base.invokelatest(WannierNLQG.Runtime.compile_task_configs, config))
        spec = only(Base.invokelatest(WannierNLQG.Runtime.validate_config, effective))
        quantity, method, calculation = task_symbols(definition)
        audit_check(
            (spec.quantity, spec.method, spec.calculation) == (quantity, method, calculation),
            "example identity differs from its registry definition",
        )
        task = only(config.tasks)
        audit_check(!isempty(task.id), "example task ID is empty")
        audit_check(config.output.system_name == "synthetic_demo", "example must remain synthetic")
        audit_check(isfile(config.model.model_file), "synthetic TB fixture is missing")
        audit_check(config.execution.fourier_backend == "direct", "example must default to Direct")
        audit_check(
            config.execution.NKdiv === nothing && config.execution.NKFFT === nothing,
            "Direct example must not supply Mixed factors",
        )
        if definition.executor == WannierNLQG.Runtime.EXECUTOR_BAND_STRUCTURE
            audit_check(
                task.physics isa WannierNLQG.BandParameters,
                "Band reference energy must be explicit",
            )
            audit_check(
                all(==(101), config.sampling.kpoints_per_segment),
                "ordinary Band preset changed",
            )
        else
            expected_mesh = calculation == :integral ? (100, 100) : (200, 200)
            audit_check(config.sampling.k_mesh == expected_mesh, "ordinary example mesh changed")
            audit_check(
                isfile(config.model.real_space_operator_bundle_file),
                "operator fixture is missing",
            )
            audit_check(
                config.model.real_space_replica_policy == "minimum_distance" &&
                    isfile(config.model.wsvec_file) &&
                    config.model.mp_grid == (2, 1, 1),
                "example must expose the synthetic MDRS lifecycle",
            )
            if quantity in CURRENT_QUANTITIES
                for field in (:photon_energies, :fermi_energy, :temperature)
                    audit_check(
                        occursin("$(field) =", text),
                        "optical example must expose $(field)",
                    )
                end
                energies = task.physics.photon_energies
                audit_check(
                    length(energies) == (calculation == :integral ? 200 : 1),
                    "optical energy preset length changed",
                )
                audit_check(
                    calculation == :integral ? first(energies) == 0.0 && last(energies) == 4.0 :
                    only(energies) == 1.0,
                    "optical energy preset values changed",
                )
            else
                audit_check(
                    task.physics isa WannierNLQG.GeometryParameters,
                    "geometry physics type mismatch",
                )
                audit_check(
                    !occursin("photon_energies", text) && !occursin("broadening =", text),
                    "geometry examples must not carry optical placeholders",
                )
            end
            audit_check(
                definition.requires_finite_q == any(!iszero, effective.photon_momentum),
                "example momentum disagrees with its registered finite-q contract",
            )
            if calculation == :integral
                audit_check(
                    task.observable isa WannierNLQG.FullTensor,
                    "Integral example must request the full tensor",
                )
            else
                audit_check(
                    task.observable isa WannierNLQG.KSliceSelection,
                    "K-slice selector must be explicit",
                )
                audit_check(
                    length(task.observable.component.indices) == Int(definition.tensor_rank),
                    "example component rank differs from registry",
                )
            end
        end
        push!(output_roots, config.output.output_root)
    end
    audit_check(length(unique(output_roots)) == EXPECTED_TASK_COUNT, "example output roots collide")
    return nothing
end

"""Audit the grouped public guide and every registered synthetic task without running responses."""
function main()
    definitions = collect(WannierNLQG.Runtime.TASK_DEFINITIONS)
    audit_check(length(definitions) == EXPECTED_TASK_COUNT, "task registry count changed")
    audit_guides(definitions)
    audit_examples(definitions)
    println("USER_GUIDE_EXAMPLE_AUDIT_OK tasks=38 integral=9 kslice=28 kpath=1 grouped_api=true")
    return nothing
end

abspath(PROGRAM_FILE) == abspath(@__FILE__) && main()
