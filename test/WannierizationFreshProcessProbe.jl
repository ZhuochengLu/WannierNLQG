using HDF5
using LinearAlgebra
using WannierNLQG

const W = WannierNLQG.Wannierization
const S = WannierNLQG.Symmetrization
const IOW = WannierNLQG.IO

if length(ARGS) == 3 && ARGS[1] == "projection-search-readback"
    projection_result = W.read_projection_representation_search_hdf5(ARGS[2])
    projection_result.payload_sha256 == ARGS[3] ||
        error("projection-search payload identity mismatch")
    projection_result.complete || error("projection-search readback is incomplete")
    length(projection_result.solutions) == 1 ||
        error("projection-search retained solution count mismatch")
    only(projection_result.solutions).validation_status == W.PROJECTION_VALIDATION_PASSED ||
        error("projection-search validation state mismatch")
    println("PROJECTION_SEARCH_FRESH_PROCESS_PASS payload=$(projection_result.payload_sha256)")
    exit()
end

root = mktempdir(; prefix = "wanniernlqg-fresh-process-")
win_file = joinpath(root, "synthetic.win")
eig_file = joinpath(root, "synthetic.eig")
mmn_file = joinpath(root, "synthetic.mmn")
representation_file = joinpath(root, "synthetic.band-representation.h5")
checkpoint_file = joinpath(root, "synthetic.wannierization.h5")

open(win_file, "w") do io
    println(io, "num_wann = 1")
end
energies = [-1.0 -1.0; 1.0 1.0]
open(eig_file, "w") do io
    for kpoint in 1:2, band in 1:2
        println(io, "$(band) $(kpoint) $(energies[band, kpoint])")
    end
end
neighbors = [2 1; 2 1; 1 2; 1 2; 1 2; 1 2]
shifts = zeros(Int, 3, 6, 2)
shifts[1, 2, 1] = -1
shifts[1, 1, 2] = 1
shifts[2, 3, :] .= 1
shifts[2, 4, :] .= -1
shifts[3, 5, :] .= 1
shifts[3, 6, :] .= -1
open(mmn_file, "w") do io
    println(io, "Created by WannierNLQG fresh-process probe")
    println(io, "2 2 6")
    for kpoint in 1:2, neighbor in 1:6
        println(
            io,
            "$(kpoint) $(neighbors[neighbor, kpoint]) " *
            "$(shifts[1, neighbor, kpoint]) $(shifts[2, neighbor, kpoint]) " *
            "$(shifts[3, neighbor, kpoint])",
        )
        for source_band in 1:2, target_band in 1:2
            value = source_band == target_band ? 1.0 : 0.0
            println(io, "$(value) 0.0")
        end
    end
end

identity_operation = WannierNLQG.SymmetryFoundation.SymmetryOperation(
    Matrix{Int}(I, 3, 3),
    zeros(3),
    Matrix{Float64}(I, 3, 3),
)
representation = WannierNLQG.SymmetryFoundation.BandRepresentation(
    "1.4",
    :synthetic,
    false,
    Matrix{Float64}(I, 3, 3),
    2.0pi .* Matrix{Float64}(I, 3, 3),
    (2, 1, 1),
    [0.0 0.0 0.0; 0.5 0.0 0.0],
    energies,
    [identity_operation],
    reshape([1, 2], 1, 2),
    zeros(Int, 3, 1, 2),
    reshape(repeat(Matrix{ComplexF64}(I, 2, 2), 1, 1, 2), 2, 2, 1, 2),
    [1 1; 2 2],
    [1, 2],
    [1, 2],
    [1, 1];
    conventions = Dict("magnetic_structure" => "false"),
    input_sha256 = Dict("fixture" => repeat("0", 64)),
)
block = WannierNLQG.WannierProjection.WannierProjectionBlock(
    "X",
    "s",
    zeros(3, 1),
    reshape([1], 1, 1),
    reshape(Matrix{Float64}(I, 3, 3), 3, 3, 1),
    false,
)
basis = WannierNLQG.WannierProjection.WannierProjectionBasis([block], 1, false)
prepared = W.prepare_band_representation(
    W.BandRepresentationPreparationConfig(
        construction_policy = :strict,
        wannierization_mode = :symmetry_adapted,
        win_file = win_file,
        eig_file = eig_file,
        projection_basis = basis,
        band_representation = representation,
        output_hdf5 = representation_file,
        outer_min_ev = -2.0,
        outer_max_ev = 2.0,
        frozen_min_ev = -2.0,
        frozen_max_ev = -0.5,
        num_wannier = 1,
        compatibility_policy = :strict,
    ),
)
prepared.output_hdf5 == abspath(representation_file) || error("representation was not persisted")
prepared.status in (:PASS, :PASS_WITH_WARNINGS) || error("representation preparation failed")

acceleration = W.WannierizationAccelerationConfig(
    schedule = :two_stage,
    u_acceptance = :armijo,
    z_stability_window = 1,
    disentanglement_objective_tolerance = 1.0e-8,
    z_projector_tolerance = 1.0e-8,
)
result = W.construct_symmetry_adapted_wannier_functions(
    W.SymmetryAdaptedWannierizationConfig(
        input = W.WannierizationInputConfig(
            construction_policy = :strict,
            wannierization_mode = :symmetry_adapted,
            win_file = win_file,
            eig_file = eig_file,
            mmn_file = mmn_file,
            projection_basis = basis,
            band_representation_hdf5 = representation_file,
            outer_min_ev = -2.0,
            outer_max_ev = 2.0,
            frozen_min_ev = -2.0,
            frozen_max_ev = -0.5,
            num_wannier = 1,
            compatibility_policy = :strict,
        ),
        solver = W.WannierizationSolverConfig(
            # This probe freezes the historical synthetic trajectory so it tests
            # persistence and TB readback independently of production :auto
            # profile selection.
            algorithm_profile = :custom,
            initialization = :random,
            localize = false,
            acceleration = acceleration,
            max_iterations = 8,
            convergence_tolerance = 1.0e-8,
            convergence_window = 1,
            random_seed = 0x1234,
        ),
        checkpoint = W.WannierizationCheckpointConfig(
            checkpoint_hdf5 = checkpoint_file,
            checkpoint_interval = 0,
        ),
        runtime = W.WannierizationRuntimeConfig(progress_interval = 0),
        output = W.WannierizationOutputConfig(
            tb_output_formats = (:packed_hdf5, :wannier90_tb),
            write_wannier90_tb = true,
        ),
    ),
)
result.status in (W.COMPLETED, W.COMPLETED_WITH_WARNINGS) || error(
    "fresh-process solver did not converge: $(result.status); diagnostics=" *
    join(("$(item.code):$(item.message)" for item in result.diagnostics), " | "),
)
result.checkpoint_file == abspath(checkpoint_file) || error("checkpoint path mismatch")
restored = W.read_wannierization_checkpoint_hdf5(checkpoint_file)
restored.v_matrix == result.v_matrix || error("checkpoint solution round-trip failed")
restored.restart_state.optimizer_state.disentanglement_objective_history ==
result.restart_state.optimizer_state.disentanglement_objective_history ||
    error("checkpoint stage history round-trip failed")
packed = something(result.artifacts.packed_hdf5)
exchange = something(result.artifacts.wannier90_tb)
isfile(packed) || error("packed TB export is missing")
isfile(exchange) || error("Wannier90 TB export is missing")
bundle = IOW.read_real_space_operator_bundle(packed)
bundle.manifest.num_orbitals == 1 || error("packed TB readback orbital count mismatch")
tb = IOW.read_wannier_tb(exchange)
tb.num_orbitals == 1 || error("Wannier90 TB readback orbital count mismatch")

maximum_checkpoint = joinpath(root, "maximum-iterations.wannierization.h5")
maximum_result = W.construct_symmetry_adapted_wannier_functions(
    W.SymmetryAdaptedWannierizationConfig(
        input = W.WannierizationInputConfig(
            construction_policy = :strict,
            wannierization_mode = :symmetry_adapted,
            win_file = win_file,
            eig_file = eig_file,
            mmn_file = mmn_file,
            projection_basis = basis,
            band_representation_hdf5 = representation_file,
            outer_min_ev = -2.0,
            outer_max_ev = 2.0,
            frozen_min_ev = -2.0,
            frozen_max_ev = -0.5,
            num_wannier = 1,
            compatibility_policy = :strict,
        ),
        solver = W.WannierizationSolverConfig(
            algorithm_profile = :custom,
            initialization = :random,
            localize = false,
            acceleration = W.WannierizationAccelerationConfig(
                schedule = :two_stage,
                u_acceptance = :armijo,
                z_stability_window = 3,
                disentanglement_objective_tolerance = 0.0,
                z_projector_tolerance = 1.0e-16,
            ),
            max_iterations = 1,
            convergence_tolerance = 1.0e-16,
            convergence_window = 3,
            random_seed = 0x5678,
        ),
        checkpoint = W.WannierizationCheckpointConfig(
            checkpoint_hdf5 = maximum_checkpoint,
            checkpoint_interval = 0,
        ),
        runtime = W.WannierizationRuntimeConfig(progress_interval = 0),
        output = W.WannierizationOutputConfig(
            tb_output_formats = (:packed_hdf5, :wannier90_tb),
            write_wannier90_tb = true,
        ),
    ),
)
maximum_result.status == W.MAX_ITERATIONS ||
    error("maximum-iteration probe returned $(maximum_result.status)")
isfile(maximum_checkpoint) || error("maximum-iteration checkpoint is missing")
maximum_result.input_summary["diagnostic_classification"] == "MAX_ITERATIONS_DIAGNOSTIC" ||
    error("maximum-iteration result has the wrong diagnostic classification")
maximum_result.input_summary["tb_export_status"] == "EXPORTED_WITH_WARNING" ||
    error("maximum-iteration result did not record diagnostic TB export")
maximum_packed = something(maximum_result.artifacts.packed_hdf5)
maximum_exchange = something(maximum_result.artifacts.wannier90_tb)
isfile(maximum_packed) || error("maximum-iteration diagnostic packed TB is missing")
isfile(maximum_exchange) || error("maximum-iteration diagnostic Wannier90 TB is missing")
maximum_manifest = IOW.read_real_space_operator_bundle_manifest(maximum_packed)
maximum_manifest.diagnostic_only || error("maximum-iteration TB is not diagnostic-only")
something(maximum_manifest.production_eligible, false) &&
    error("maximum-iteration TB was incorrectly marked production eligible")
println("WANNIERIZATION_FRESH_PROCESS_PASS root=$(root)")
