GC.enable(true) || error("FIRSTUSE_GC_WAS_DISABLED")
#!/usr/bin/env julia

length(ARGS) == 2 || error("usage: run_case.jl examples/tasks/<family>/<name>.jl output_dir")
relative, output_dir = ARGS
".." in splitpath(relative) && error("case path must stay inside examples/tasks")
root = dirname(Base.active_project())
output_dir = abspath(output_dir)
startswith(relpath(output_dir, root), "..") || error("output_dir must be outside the source tree")
example = joinpath(root, "examples", "tasks", relative)
isfile(example) || error("missing registered example: $(relative)")
mkpath(output_dir)

import_started = time_ns()
import_timed = @timed Core.eval(Main, :(using WannierNLQG))
import_wall = (time_ns() - import_started) / 1.0e9

initialization_started = time_ns()
initialization_timed = @timed Core.eval(Main, :(using JSON3, LinearAlgebra, MPI, FFTW))
initialization_wall = (time_ns()-initialization_started)/1e9

example_started = time_ns()
example_timed = @timed Core.eval(Main, :(include(example)))
example_wall = (time_ns() - example_started) / 1.0e9

function make_config(destination)
    config = if startswith(relative, "band/")
        build_config(
            output_root = destination,
            kpoints_per_segment = fill(3, 4),
            progress_enabled = false,
        )
    else
        build_config(k_mesh = (4, 4), output_root = destination, progress_enabled = false)
    end
    # Supplemental valid-input fixture: the historical synthetic model has
    # hopping along x only. A y derivative or a repeated antisymmetric optical
    # pair cannot prove expected nonzero coverage. Keep those old results intact.
    components = Dict(
        "BCDK" => (1, 2, 1),
        "BCQK" => (1, 2, 1, 1),
        "ICK" => (1, 1, 2),
        "ISCK" => (1, 1, 1, 2),
        "PDICK" => (1, 1, 2),
        "QCSK" => (1, 1, 1),
        "QMDK" => (1, 1, 1),
        "QMQK" => (1, 1, 1, 1),
        "SVK" => (1, 1, 1),
        "ZIBCK" => (1, 3),
        "ZIQMK" => (1, 2),
    )
    spec = only(config.tasks)
    if haskey(components, spec.quantity)
        selection = WannierNLQG.KSliceSelection(
            component = WannierNLQG.TensorComponent(components[spec.quantity]...),
            bands = spec.observable.bands,
        )
        physics = spec.physics
        numerics = spec.numerics
        if physics isa Union{WannierNLQG.OpticalParameters, WannierNLQG.FiniteQOpticalParameters}
            pnames=fieldnames(typeof(physics))
            pvalues=Tuple(getfield(physics, k) for k in pnames)
            physics=typeof(physics)(;
                merge(NamedTuple{pnames}(pvalues), (photon_energies = Float64[2.5],))...,
            )
            nnames=numerics.supplied
            nvalues=Tuple(getproperty(numerics.values, k) for k in nnames)
            numerics=WannierNLQG.OpticalNumerics(;
                merge(
                    NamedTuple{nnames}(nvalues),
                    (broadening = 0.4, broadening_type = "Lorentzian"),
                )...,
            )
        end
        task=WannierNLQG.TaskSpec(
            id = spec.id,
            quantity = spec.quantity,
            method = spec.method,
            physics = physics,
            numerics = numerics,
            observable = selection,
        )
        sampling=WannierNLQG.KSlice(
            k_mesh = (4, 4),
            spatial_dimension = 2,
            origin = (0.137, 0.079, 0.0),
            vector_1 = (1.0, 0.0, 0.0),
            vector_2 = (0.0, 1.0, 0.0),
        )
        model=config.model
        if spec.quantity in ("ZIBCK", "ZIQMK")
            bundle=get(
                ENV,
                "FIRSTUSE_PAULI_BUNDLE",
                joinpath(root, "test", "fixtures", "first_use_registered", "pauli_bundle.h5"),
            )
            isfile(bundle)||error("missing independent immutable Pauli fixture")
            names=fieldnames(typeof(model));
            values=Tuple(getfield(model, n) for n in names)
            model=WannierNLQG.ModelInput(;
                merge(NamedTuple{names}(values), (real_space_operator_bundle_file = bundle,))...,
            )
        end
        config=WannierNLQG.TaskConfig(
            model = model,
            sampling = sampling,
            tasks = [task],
            execution = config.execution,
            output = config.output,
        )
    end
    fields = fieldnames(typeof(config))
    values = Tuple(getfield(config, name) for name in fields)
    options = config.output
    output_fields = fieldnames(typeof(options))
    output_values = Tuple(getfield(options, name) for name in output_fields)
    precise_output = WannierNLQG.OutputOptions(;
        merge(NamedTuple{output_fields}(output_values), (response_output_digits = 17,))...,
    )
    return WannierNLQG.TaskConfig(;
        merge(NamedTuple{fields}(values), (output = precise_output,))...,
    )
end

config_started = time_ns()
first_destination = joinpath(output_dir, "first")
config_timed = @timed Core.eval(Main, :(make_config(first_destination)))
config = config_timed.value
config_wall = (time_ns() - config_started) / 1.0e9

trace_rank = parse(Int, get(ENV, "OMPI_COMM_WORLD_RANK", "0"))
trace_directory = get(ENV, "WNLQG_TRACE_DIR", "")
trace_path = isempty(trace_directory) ? "" : joinpath(trace_directory, "rank_$(trace_rank).jl")
trace_bytes_before = !isempty(trace_path) && isfile(trace_path) ? filesize(trace_path) : nothing
const FIRST_GC_ON = GC.enable(true)
FIRST_GC_ON || error("FIRSTUSE_GC_WAS_DISABLED")
const FIRST_BACKENDS = Dict(
    string(name)=>Base.get_extension(WannierNLQG, name)!==nothing for name in (
        :WannierNLQGWannierizationPrecompileExt,
        :WannierNLQGWannierizationExt,
        :WannierNLQGOperatorBundleExt,
        :WannierNLQGSymmetryFoundationExt,
        :WannierNLQGSymmetrizationExt,
    )
)
const FIRST_MPI_INITIALIZED = MPI.Initialized()
first_started = time_ns()
# Julia 1.11.2 Base/timing.jl documents that @timed may compile a direct
# top-level call before its counters start. Evaluate the public call only after
# the timer starts; configuration and script loading remain outside this scope.
diagnostic_inference = get(ENV, "FIRSTUSE_COLLECT_INFERENCE", "") == "1"
if diagnostic_inference
    Base.Core.Compiler.Timings.reset_timings()
    Base.Core.Compiler.__set_measure_typeinf(true)
end
first_timed = try
    @timed Core.eval(Main, :(WannierNLQG.run(config)))
finally
    if diagnostic_inference
        Base.Core.Compiler.__set_measure_typeinf(false)
        Base.Core.Compiler.Timings.close_current_timer()
    end
end
first_ended = time_ns()
first_wall = (first_ended - first_started) / 1.0e9
trace_bytes_after = !isempty(trace_path) && isfile(trace_path) ? filesize(trace_path) : nothing
if diagnostic_inference
    Base.include(Main, joinpath(@__DIR__, "NativeInferenceEvidence.jl"))
    NativeInferenceEvidence.persist(joinpath(output_dir, "inference_rank_$(trace_rank)"))
end

rank = parse(Int, get(ENV, "OMPI_COMM_WORLD_RANK", "0"))
launched_by_mpi = haskey(ENV, "OMPI_COMM_WORLD_RANK")
# Runtime owns and finalizes MPI when launched by mpiexec. A second run in that
# process would be invalid; caller-owned MPI warm runs need a separate probe.
repeat_config = launched_by_mpi ? nothing : make_config(joinpath(output_dir, "repeat"))
repeat_started = time_ns()
repeat_timed = launched_by_mpi ? nothing : @timed Core.eval(Main, :(WannierNLQG.run(repeat_config)))
repeat_wall = launched_by_mpi ? nothing : (time_ns() - repeat_started) / 1.0e9

function timed_fields(value, wall)
    return (
        wall = wall,
        time = value.time,
        compile_time = value.compile_time,
        recompile_time = value.recompile_time,
        gc_time = value.gctime,
        allocated_bytes = value.bytes,
    )
end

record = (
    measurement_scope = "timed_eval_public_run",
    gc_on = FIRST_GC_ON,
    extension_state_before = FIRST_BACKENDS,
    mpi_initialized_before = FIRST_MPI_INITIALIZED,
    julia_version = string(VERSION),
    package_root = pkgdir(WannierNLQG),
    mpi_library = MPI.Get_library_version(),
    julia_threads = Threads.nthreads(),
    blas_threads = BLAS.get_num_threads(),
    fftw_threads = FFTW.get_num_threads(),
    first_start_ns = first_started,
    first_end_ns = first_ended,
    workload_enabled = WannierNLQG.FIRST_USE_WORKLOAD_ENABLED,
    first_call_trace_bytes_before = trace_bytes_before,
    first_call_trace_bytes_after = trace_bytes_after,
    path = relative,
    rank = rank,
    import_phase = timed_fields(import_timed, import_wall),
    initialization_phase = timed_fields(initialization_timed, initialization_wall),
    example_load_phase = timed_fields(example_timed, example_wall),
    config_phase = timed_fields(config_timed, config_wall),
    example_load_wall = example_wall,
    config_wall = config_wall,
    first = timed_fields(first_timed, first_wall),
    repeat = launched_by_mpi ? nothing : timed_fields(repeat_timed, repeat_wall),
    first_outputs = first_timed.value.outputs,
    repeat_outputs = launched_by_mpi ? String[] : repeat_timed.value.outputs,
    task_labels = [spec.label for spec in first_timed.value.specs],
)
write(joinpath(output_dir, "rank_$(rank).json"), JSON3.write(record))
println("FIRST_USE_CASE_OK path=$(relative) rank=$(rank)")
