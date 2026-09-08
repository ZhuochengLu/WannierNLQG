using JSON3
using LinearAlgebra
using MPI
using WannierNLQG

length(ARGS) == 1 || error("usage: kpath_band_parallel_runner.jl OUTPUT_ROOT")
const KPATH_PARALLEL_OUTPUT = abspath(only(ARGS))
const KPATH_PARALLEL_PACKAGE = normpath(joinpath(@__DIR__, "..", ".."))
const KPATH_PARALLEL_MODEL = joinpath(
    KPATH_PARALLEL_PACKAGE,
    "examples",
    "symmetrization",
    "fixture",
    "inputs",
    "synthetic_tb.dat",
)
BLAS.set_num_threads(1)
const KPATH_PARALLEL_MPI = get(ENV, "WANNIERNLQG_USE_MPI", "0") == "1"
KPATH_PARALLEL_MPI && MPI.Init()
const KPATH_PARALLEL_RANK = KPATH_PARALLEL_MPI ? MPI.Comm_rank(MPI.COMM_WORLD) : 0

# Exercise two Band tasks that share only KPath geometry and differ in energy reference.
function kpath_parallel_config()
    return TaskConfig(
        model = ModelInput(model_file = KPATH_PARALLEL_MODEL),
        sampling = KPath(
            nodes = [("Γ", (0.0, 0.0, 0.0)), ("X", (0.5, 0.0, 0.0)), ("Γ", (0.0, 0.0, 0.0))],
            kpoints_per_segment = [5, 5],
        ),
        tasks = [
            TaskSpec(
                id = "bands_zero",
                quantity = "Band_Structure",
                physics = BandParameters(fermi_energy = 0.0),
            ),
            TaskSpec(
                id = "bands_shifted",
                quantity = "Band",
                physics = BandParameters(fermi_energy = 0.25),
            ),
        ],
        execution = ExecutionOptions(fourier_backend = "direct"),
        output = OutputOptions(
            output_root = KPATH_PARALLEL_OUTPUT,
            system_name = "parallel_kpath",
            progress_enabled = false,
        ),
    )
end

try
    result = WannierNLQG.run(kpath_parallel_config())
    if KPATH_PARALLEL_RANK == 0
        length(result.task_results) == 2 || error("KPath probe must execute both Band tasks")
        records = Dict{String, Any}()
        for (id, task_result) in zip(result.task_ids, result.task_results)
            records[id] = Dict(
                "bands" => read(task_result.outputs[1], String),
                "kpath" => read(task_result.outputs[2], String),
            )
        end
        records["bands_zero"]["kpath"] == records["bands_shifted"]["kpath"] ||
            error("Identical KPath geometry produced task-dependent sidecars")
        open(joinpath(KPATH_PARALLEL_OUTPUT, "parallel_outputs.json"), "w") do io
            JSON3.write(io, records)
        end
        println(
            "KPATH_BAND_PARALLEL_PASS threads=",
            Threads.nthreads(),
            " ranks=",
            KPATH_PARALLEL_MPI ? MPI.Comm_size(MPI.COMM_WORLD) : 1,
        )
    end
finally
    KPATH_PARALLEL_MPI && !MPI.Finalized() && MPI.Finalize()
end
