using JSON3
using LinearAlgebra
using MPI
using WannierNLQG

length(ARGS) == 1 || error("usage: per_task_parallel_runner.jl OUTPUT_ROOT")
const PARALLEL_OUTPUT = abspath(only(ARGS))
const PARALLEL_PACKAGE = normpath(joinpath(@__DIR__, "..", ".."))
const PARALLEL_FIXTURE = joinpath(PARALLEL_PACKAGE, "examples", "fixtures", "synthetic_runtime")
BLAS.set_num_threads(1)
const PARALLEL_MPI = get(ENV, "WANNIERNLQG_USE_MPI", "0") == "1"
PARALLEL_MPI && MPI.Init()
const PARALLEL_RANK = PARALLEL_MPI ? MPI.Comm_rank(MPI.COMM_WORLD) : 0

# Keep every numeric row and its column layout while ignoring human-readable headers.
function parallel_numeric_rows(path)
    rows = Vector{Float64}[]
    for line in eachline(path)
        text = strip(line)
        (isempty(text) || startswith(text, "#")) && continue
        values = tryparse.(Float64, split(text))
        any(isnothing, values) && continue
        row = Float64[value for value in values]
        all(isfinite, row) || error("Nonfinite numerical output in $(path)")
        push!(rows, row)
    end
    isempty(rows) && error("No numerical rows in $(path)")
    return rows
end

# One mesh spans more than the fixed 64 deterministic reduction lanes.
function parallel_config(backend, family)
    optical_a = TaskSpec(
        id = "narrow",
        quantity = family == "integral" ? "SC" : "SCK",
        method = "Conventional",
        physics = OpticalParameters(
            photon_energies = family == "integral" ? [0.1, 1.0, 2.0, 3.0] : [1.0],
            fermi_energy = 0.0,
            temperature = 0.0,
        ),
        numerics = OpticalNumerics(broadening = 0.06, denominator_regularization = 0.001),
        observable = family == "integral" ? FullTensor() :
                     KSliceSelection(
            component = TensorComponent(2, 2, 2),
            bands = Transition(conduction = [3, 4], valence = [1, 2]),
        ),
    )
    task_b = if family == "integral"
        TaskSpec(
            id = "wide",
            quantity = "SC",
            method = "Conventional",
            physics = OpticalParameters(
                photon_energies = [0.2, 0.7, 1.4, 2.1, 3.7],
                fermi_energy = 0.2,
                temperature = 150.0,
            ),
            numerics = OpticalNumerics(broadening = 0.11, denominator_regularization = 0.003),
            observable = FullTensor(),
        )
    else
        TaskSpec(
            id = "metric",
            quantity = "QMK",
            method = "Conventional",
            physics = GeometryParameters(),
            numerics = GeometryNumerics(denominator_regularization = 0.003),
            observable = KSliceSelection(
                component = TensorComponent(1, 2),
                bands = Subspace([1, 2]),
            ),
        )
    end
    sampling =
        family == "integral" ? BZMesh(k_mesh = (9, 8), spatial_dimension = 2) :
        KSlice(
            k_mesh = (9, 8),
            spatial_dimension = 2,
            origin = (0.0, 0.0, 0.0),
            vector_1 = (1.0, 0.0, 0.0),
            vector_2 = (0.0, 1.0, 0.0),
        )
    execution =
        backend == "mixed" ?
        ExecutionOptions(fourier_backend = "mixed", NKdiv = (3, 2), NKFFT = (3, 4)) :
        ExecutionOptions(fourier_backend = "direct")
    return TaskConfig(
        model = ModelInput(
            model_file = joinpath(PARALLEL_FIXTURE, "synthetic_tb.dat"),
            real_space_replica_policy = "input",
        ),
        sampling = sampling,
        tasks = [optical_a, task_b],
        execution = execution,
        output = OutputOptions(
            output_root = joinpath(PARALLEL_OUTPUT, backend * "_" * family),
            system_name = "parallel_fixture",
            response_output_digits = 17,
            progress_enabled = false,
        ),
    )
end

try
    records = Dict{String, Any}()
    for backend in ("direct", "mixed"), family in ("integral", "kslice")
        result = WannierNLQG.run(parallel_config(backend, family))
        if PARALLEL_RANK == 0
            length(result.task_ids) == 2 || error("Parallel probe must execute both task instances")
            stats = result.sharing.worker_statistics
            sum(value.spectrum_hits for value in stats) > 0 ||
                error("Joint tasks did not share spectra")
            for (id, task_result) in zip(result.task_ids, result.task_results)
                for path in task_result.outputs
                    endswith(path, ".dat") || continue
                    key = join((backend, family, id, basename(path)), "/")
                    records[key] = parallel_numeric_rows(path)
                end
            end
        end
    end
    if PARALLEL_RANK == 0
        open(joinpath(PARALLEL_OUTPUT, "numerical.json"), "w") do io
            JSON3.write(io, records)
        end
        println(
            "PER_TASK_PARALLEL_PROBE_PASS threads=",
            Threads.nthreads(),
            " ranks=",
            PARALLEL_MPI ? MPI.Comm_size(MPI.COMM_WORLD) : 1,
            " numerical_files=",
            length(records),
        )
    end
finally
    PARALLEL_MPI && !MPI.Finalized() && MPI.Finalize()
end
