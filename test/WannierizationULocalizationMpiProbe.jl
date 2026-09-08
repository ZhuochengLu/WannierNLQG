using LinearAlgebra
using MPI
using SHA
using WannierNLQG

const W = WannierNLQG.Wannierization
const WSC = first(W._load_wannierization_extension!()).SolverCheckpoint
const S = WannierNLQG.Symmetrization
const IOW = WannierNLQG.IO

function maximum_field_difference(left, right)
    return maximum(maximum(abs, left[kpoint] - right[kpoint]) for kpoint in eachindex(left))
end

MPI.Init()
identity = WannierNLQG.SymmetryFoundation.SymmetryOperation(
    Matrix{Int}(I, 3, 3),
    zeros(3),
    Matrix{Float64}(I, 3, 3),
)
energies = [-1.0 -1.0; 1.0 1.0]
representation = WannierNLQG.SymmetryFoundation.BandRepresentation(
    "1.0",
    :synthetic,
    false,
    Matrix{Float64}(I, 3, 3),
    2.0pi .* Matrix{Float64}(I, 3, 3),
    (2, 1, 1),
    [0.0 0.0 0.0; 0.5 0.0 0.0],
    energies,
    [identity],
    reshape([1, 2], 1, 2),
    zeros(Int, 3, 1, 2),
    reshape(repeat(Matrix{ComplexF64}(I, 2, 2), 1, 1, 2), 2, 2, 1, 2),
    [1 1; 2 2],
    [1, 2],
    [1, 2],
    [1, 1];
    conventions = Dict("fourier" => "H(k)=sum_R exp(+2pi*i*k.R) H(R)"),
    input_sha256 = Dict("fixture" => repeat("0", 64)),
)
projection_block = WannierNLQG.WannierProjection.WannierProjectionBlock(
    "X",
    "s",
    zeros(3, 1),
    reshape([1, 2], 2, 1),
    reshape(Matrix{Float64}(I, 3, 3), 3, 3, 1),
    false,
)
basis = WannierNLQG.WannierProjection.WannierProjectionBasis([projection_block], 2, false)
plan = WannierNLQG.SymmetryFoundation.WannierSymmetryPlan(
    [identity],
    reshape(Matrix{ComplexF64}(I, 2, 2), 2, 2, 1),
    zeros(Int, 3, 2, 1),
)
neighbors = [2 1; 2 1; 1 2; 1 2; 1 2; 1 2]
reciprocal_shifts = zeros(Int, 3, 6, 2)
reciprocal_shifts[1, 2, 1] = -1
reciprocal_shifts[1, 1, 2] = 1
reciprocal_shifts[2, 3, :] .= 1
reciprocal_shifts[2, 4, :] .= -1
reciprocal_shifts[3, 5, :] .= 1
reciprocal_shifts[3, 6, :] .= -1
data = zeros(ComplexF64, 2, 2, 6, 2)
for kpoint in 1:2, neighbor in 1:6
    phase = 0.025 * (neighbor + 2kpoint)
    data[:, :, neighbor, kpoint] .= ComplexF64[
        0.97cis(phase) 0.03cis(-2phase)
        -0.02cis(phase) 0.96cis(-phase)
    ]
end
mmn = IOW.WannierMMN(2, 2, 6, data, neighbors, reciprocal_shifts)
angle_value = 0.17
frames = [
    Matrix{ComplexF64}(I, 2, 2),
    ComplexF64[cos(angle_value) sin(angle_value); -sin(angle_value) cos(angle_value)],
]
weights = fill(1.0 / 6.0, 6)
tangent_plans = Union{Nothing, WSC.TargetSymmetryTangentPlan}[nothing, nothing]
phase_reference = zeros(Float64, 2, 3)

function make_config(parallel)
    acceleration = W.WannierizationAccelerationConfig(
        schedule = :two_stage,
        localization_algorithm = :smv_fletcher_reeves_two_stage,
        localization_max_steps = 1,
        u_inner_sweeps = 1,
        u_line_search_max_trials = 8,
        u_gradient_norm_tolerance = 1.0e-14,
    )
    return W.SymmetryAdaptedWannierizationConfig(
        input = W.WannierizationInputConfig(
            wannierization_mode = :ordinary,
            win_file = "synthetic.win",
            eig_file = "synthetic.eig",
            mmn_file = "synthetic.mmn",
            projection_basis = basis,
            band_representation = representation,
            num_wannier = 2,
            outer_min_ev = -2.0,
            outer_max_ev = 2.0,
            frozen_min_ev = 1.0,
            frozen_max_ev = -1.0,
        ),
        solver = W.WannierizationSolverConfig(
            algorithm_profile = :custom,
            initialization = :random,
            acceleration = acceleration,
            parallel = parallel,
            localize = true,
            symmetrize_z = false,
            random_seed = 0x1234,
        ),
        checkpoint = W.WannierizationCheckpointConfig(),
        runtime = W.WannierizationRuntimeConfig(),
        output = W.WannierizationOutputConfig(),
    )
end

serial_config = make_config(:serial)
mpi_config = make_config(:mpi)
serial_evaluation = WSC._evaluate_mv_localization(
    serial_config,
    frames,
    phase_reference,
    representation,
    mmn,
    weights,
    plan,
    tangent_plans,
)
mpi_evaluation = WSC._evaluate_mv_localization(
    mpi_config,
    frames,
    phase_reference,
    representation,
    mmn,
    weights,
    plan,
    tangent_plans,
)
serial_evaluation.success || error("serial U evaluation failed")
mpi_evaluation.success || error("MPI U evaluation failed")
serial_value = serial_evaluation.evaluation
mpi_value = mpi_evaluation.evaluation
maximum(abs, serial_value.centers - mpi_value.centers) == 0.0 ||
    error("MPI U centers differ from serial")
maximum(abs, serial_value.spreads - mpi_value.spreads) == 0.0 ||
    error("MPI U spreads differ from serial")
maximum_field_difference(serial_value.raw_gradients, mpi_value.raw_gradients) == 0.0 ||
    error("MPI U raw gradient differs from serial")
maximum_field_difference(serial_value.full_gradients, mpi_value.full_gradients) == 0.0 ||
    error("MPI U projected gradient differs from serial")
serial_value.active_orbit_digests == mpi_value.active_orbit_digests ||
    error("MPI U branch orbit inventory differs from serial")

included = [trues(2), trues(2)]
frozen = [Int[], Int[]]
projectors = [frame * frame' for frame in frames]
function localize(config)
    input_subspaces = deepcopy(frames)
    input_frames = deepcopy(frames)
    input_centers = copy(serial_value.centers)
    input_spreads = copy(serial_value.spreads)
    input_projectors = deepcopy(projectors)
    if config.solver.parallel == :mpi && MPI.Comm_rank(MPI.COMM_WORLD) != 0
        # Emulate the last-bit process-local LAPACK gauges observed at the Cr
        # Z-to-U boundary.  Rank-zero canonicalization must erase these
        # differences before any reference line-search branch is evaluated.
        input_subspaces[1][1, 1] += 4eps(Float64)
        input_frames[2][2, 1] -= 2eps(Float64)
        input_centers[1, 1] += 8eps(Float64)
        input_spreads[2] -= 8eps(Float64)
        input_projectors[1][1, 2] += 2eps(Float64) * im
    end
    return WSC._localization_sweeps(
        config,
        representation,
        mmn,
        plan,
        weights,
        included,
        frozen,
        input_subspaces,
        input_frames,
        input_centers,
        input_spreads,
        1.0,
        1.0e-8,
        tangent_plans,
        true,
        :smv_fletcher_reeves_two_stage;
        fixed_projectors = input_projectors,
    )
end
serial_result = localize(serial_config)
mpi_result = localize(mpi_config)
serial_result.success == mpi_result.success || error("MPI U status differs from serial")
serial_result.code == mpi_result.code || error("MPI U result code differs from serial")
maximum_field_difference(serial_result.frames, mpi_result.frames) == 0.0 ||
    error("MPI U accepted frames differ from serial")
maximum(abs, serial_result.centers - mpi_result.centers) == 0.0 ||
    error("MPI U accepted centers differ from serial")
maximum(abs, serial_result.spreads - mpi_result.spreads) == 0.0 ||
    error("MPI U accepted spreads differ from serial")
serial_result.attempted_accepted == mpi_result.attempted_accepted ||
    error("MPI U line-search decisions differ from serial")

buffer = IOBuffer()
for field in (mpi_value.raw_gradients, mpi_value.full_gradients, mpi_result.frames)
    for matrix in field
        write(buffer, reinterpret(UInt8, vec(matrix)))
    end
end
write(buffer, reinterpret(UInt8, vec(mpi_result.spreads)))
digest = bytes2hex(SHA.sha256(take!(buffer)))
if MPI.Comm_rank(MPI.COMM_WORLD) == 0
    println("WANNIERIZATION_U_MPI_PARITY_DIGEST=$(digest)")
    println("WANNIERIZATION_U_MPI_PARITY_MAX_EVAL=0.0")
    println("WANNIERIZATION_U_MPI_PARITY_MAX_SWEEP=0.0")
end
MPI.Barrier(MPI.COMM_WORLD)
MPI.Finalize()
