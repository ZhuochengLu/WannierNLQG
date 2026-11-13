module ParallelogramRegionFixture
using WannierNLQG, LinearAlgebra, JSON3

const OBSERVED_CARTESIAN_POINTS = NTuple{3, Float64}[]
const OWNED_CARTESIAN_POINTS = NTuple{3, Float64}[]
const PREFLIGHT_CARTESIAN_POINTS = NTuple{3, Float64}[]
const UNKNOWN_CARTESIAN_POINTS = NTuple{3, Float64}[]
const RECORD_POINTS = Ref(false)
const POINT_LOCK = ReentrantLock()
# Cached code can retain its definition paths after package relocation. Match
# the actual loaded boundary owner, rather than a newly reported package root.
const PREFLIGHT_SOURCE_FILE = only(
    unique(
        normpath(string(method.file)) for
        method in methods(WannierNLQG.MatrixElements.validate_analytic_model)
    ),
)
const INTEGRAL_SOURCE_FILE = only(
    unique(
        normpath(string(method.file)) for
        method in methods(WannierNLQG.Runtime._run_integral_bundle_owned!)
    ),
)
const MOMENTUM = (0.06, -0.04, 0.0)

"""A small noncentrosymmetric, dispersive two-band Hamiltonian; recording changes no values."""
function hamiltonian(k, parameters)
    if RECORD_POINTS[] && all(x -> x isa Float64, k)
        # Native model validation runs on every rank before point ownership.
        # Record the actual caller boundary; never infer ownership from k values.
        frames = stacktrace()
        preflight = any(
            frame ->
                string(frame.func) == "validate_analytic_model" &&
                normpath(string(frame.file)) == PREFLIGHT_SOURCE_FILE,
            frames,
        )
        integral = any(
            frame ->
                string(frame.func) == "execute_point!" &&
                normpath(string(frame.file)) == INTEGRAL_SOURCE_FILE,
            frames,
        )
        selected =
            preflight && !integral ? PREFLIGHT_CARTESIAN_POINTS :
            integral && !preflight ? OWNED_CARTESIAN_POINTS : UNKNOWN_CARTESIAN_POINTS
        lock(POINT_LOCK) do
            push!(OBSERVED_CARTESIAN_POINTS, Tuple(k))
            push!(selected, Tuple(k))
        end
    end
    x, y = k[1], k[2]
    scalar = 0.13x + 0.07y
    dx = 0.8 + 0.3x + 0.2y + 0.12x*y
    dy = 0.25y + 0.11x^2
    dz = 0.45 + 0.1x - 0.08y^2
    return [scalar + dz dx - im*dy; dx + im*dy scalar - dz]
end

"""Use the same continuum model for automatic and explicit numerical derivative routes."""
function model(; derivative_method = :automatic)
    return AnalyticKInput(;
        hamiltonian,
        num_orbitals = 2,
        lattice = Matrix{Float64}(I, 3, 3)*2,
        orbital_positions = zeros(3, 2),
        periodic = false,
        derivative_method,
        finite_difference_step = 1e-3,
        evaluation_bounds = ((-10.0, -10.0, -2.0), (10.0, 10.0, 2.0)),
        source_file = @__FILE__,
    )
end

"""Unfolded nonorthogonal region beyond the nominal reciprocal cell in the first direction."""
region(n) =
    KRegion(; origin = (4.0, 0.2), vector_1 = (0.4, 0.08), vector_2 = (0.12, 0.36), k_mesh = (n, n))

"""Real public optical configurations; every family keeps its existing registered kernel."""
function config(
    sampling,
    destination;
    derivative_method = :automatic,
    quantities = ("SC", "IC", "PDSC", "PDIC"),
    model_input = model(; derivative_method),
    photon_momentum = MOMENTUM,
    system_name = nothing,
    integration_algorithm = UniformIntegration(),
)
    tasks = [
        TaskSpec(;
            id = lowercase(quantity),
            quantity,
            method = quantity == "PDSC" ? "Geometric_Loop" : "Conventional",
            physics = quantity in ("PDSC", "PDIC") ?
                      FiniteQOpticalParameters(;
                photon_energies = [5.8, 6.4],
                fermi_energy = 0.0,
                temperature = 0.0,
                photon_momentum,
            ) :
                      OpticalParameters(;
                photon_energies = [5.8, 6.4],
                fermi_energy = 0.0,
                temperature = 0.0,
            ),
            numerics = Numerics(; broadening = 0.25, denominator_regularization = 0.001),
            observable = FullTensor(),
        ) for quantity in quantities
    ]
    return TaskConfig(;
        model = model_input,
        sampling,
        tasks,
        execution = ExecutionOptions(; fourier_backend = "direct", integration_algorithm),
        output = OutputOptions(;
            output_root = destination,
            system_name,
            progress_enabled = false,
            response_output_digits = 17,
        ),
    )
end

"""Retain tensor values and ordering, excluding both the Fermi and photon-energy columns."""
function tensors(result)
    data = Dict{String, Matrix{Float64}}()
    for path in result.outputs
        endswith(path, ".dat") || continue
        rows = [
            parse.(Float64, split(line)) for
            line in eachline(path) if !isempty(strip(line)) && !startswith(strip(line), "#")
        ]
        isempty(rows) && error("No tensor data in $path")
        table = reduce(vcat, permutedims.(rows))
        all(isfinite, table) || error("Nonfinite tensor in $path")
        haskey(data, basename(path)) && error("Duplicate output table")
        data[basename(path)] = table[:, 3:end]
    end
    isempty(data) && error("No response tensors")
    return data
end

"""Persist raw task evidence only when a bounded owner supplied an external directory."""
function evidence(name, payload)
    directory = get(ENV, "WANNIERNLQG_KREGION_EVIDENCE_DIR", "")
    isempty(directory) && return nothing
    mkpath(directory)
    path = joinpath(directory, name * ".json")
    ispath(path) && error("Evidence must be fresh: $path")
    write(path, JSON3.write(payload))
    return path
end

"""Keep raw result bytes and headers before the ordinary test temporary directory is cleaned."""
function retain_result(label, result)
    directory = get(ENV, "WANNIERNLQG_KREGION_EVIDENCE_DIR", "")
    isempty(directory) && return nothing
    destination = joinpath(directory, "raw_outputs", label)
    ispath(destination) && error("Result evidence must be fresh")
    mkpath(destination)
    for path in result.outputs
        cp(path, joinpath(destination, basename(path)))
    end
    for (index, task_result) in enumerate(result.task_results)
        task_directory = joinpath(destination, "task$index")
        mkpath(task_directory)
        for name in ("metadata.txt", "native_derivatives.tsv")
            path = joinpath(task_result.run_dir, name)
            isfile(path) && cp(path, joinpath(task_directory, name))
        end
    end
    return nothing
end

"""Make rows and exact IEEE bits explicit rather than relying on JSON matrix storage order."""
tensor_records(data) = Dict(
    name => (;
        shape = size(table),
        values = [collect(row) for row in eachrow(table)],
        bits = [collect(reinterpret(UInt64, collect(row))) for row in eachrow(table)],
    ) for (name, table) in data
)

end
