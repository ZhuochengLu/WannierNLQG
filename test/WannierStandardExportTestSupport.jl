using HDF5
using LinearAlgebra
using SHA
using Test

const EXPORT_WANNIERIZATION = WannierNLQG.Wannierization
const EXPORT_SYMMETRIZATION = WannierNLQG.Symmetrization
const EXPORT_IO = WannierNLQG.IO

function standard_export_fixture(; mmn_override = nothing)
    operation = WannierNLQG.SymmetryFoundation.SymmetryOperation(
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
        [operation],
        reshape([1, 2], 1, 2),
        zeros(Int, 3, 1, 2),
        reshape(repeat(Matrix{ComplexF64}(I, 2, 2), 1, 1, 2), 2, 2, 1, 2),
        [1 1; 2 2],
        [1, 2],
        [1, 2],
        [1, 1];
        input_sha256 = Dict("fixture" => repeat("b", 64)),
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
    eig = EXPORT_IO.WannierEIG(2, 2, copy(energies))
    mmn_data = zeros(ComplexF64, 2, 2, 6, 2)
    for kpoint in 1:2, neighbor in 1:6
        mmn_data[:, :, neighbor, kpoint] .= Matrix{ComplexF64}(I, 2, 2)
    end
    neighbors = [2 1; 2 1; 1 2; 1 2; 1 2; 1 2]
    shifts = zeros(Int, 3, 6, 2)
    shifts[1, 2, 1] = -1
    shifts[1, 1, 2] = 1
    shifts[2, 3, :] .= 1
    shifts[2, 4, :] .= -1
    shifts[3, 5, :] .= 1
    shifts[3, 6, :] .= -1
    mmn =
        mmn_override === nothing ? EXPORT_IO.WannierMMN(2, 2, 6, mmn_data, neighbors, shifts) :
        mmn_override
    config = EXPORT_WANNIERIZATION.SymmetryAdaptedWannierizationConfig(
        input = EXPORT_WANNIERIZATION.WannierizationInputConfig(
            construction_policy = :standard,
            wannierization_mode = :ordinary,
            win_file = "synthetic.win",
            eig_file = "synthetic.eig",
            mmn_file = "synthetic.mmn",
            projection_basis = basis,
            num_wannier = 1,
            frozen_states = [(1, 1), (2, 1)],
        ),
        solver = EXPORT_WANNIERIZATION.WannierizationSolverConfig(
            algorithm_profile = :custom,
            initialization = :amn,
        ),
        checkpoint = EXPORT_WANNIERIZATION.WannierizationCheckpointConfig(),
        runtime = EXPORT_WANNIERIZATION.WannierizationRuntimeConfig(),
        output = EXPORT_WANNIERIZATION.WannierizationOutputConfig(
            write_wannier90_tb = true,
            tb_output_formats = (:packed_hdf5, :wannier90_tb),
        ),
    )
    frames = zeros(ComplexF64, 2, 1, 2)
    frames[1, 1, :] .= 1.0
    centers = zeros(Float64, 1, 3)
    spreads = [1.0]
    stencil = EXPORT_WANNIERIZATION._finite_difference_weights(representation, mmn)
    config_sha = EXPORT_WANNIERIZATION._restart_config_sha256(config)
    representation_sha = repeat("c", 64)
    basis_sha = EXPORT_WANNIERIZATION._projection_basis_sha256(basis)
    amn_sha = repeat("d", 64)
    restart_state = EXPORT_WANNIERIZATION.WannierizationRestartState(
        1,
        frames,
        nothing,
        centers,
        spreads,
        reshape([0.0, 0.0, 0.0, 1.0], 4, 1),
        trues(2, 2),
        0.0,
        config_sha,
        representation_sha,
        stencil,
        basis_sha,
        amn_sha,
        EXPORT_WANNIERIZATION.WannierizationOptimizerState(:fixed, 0.5, 1.0),
    )
    chk = EXPORT_IO.WannierCHK(
        2,
        1,
        2,
        representation.mp_grid,
        representation.kpoints_fractional,
        representation.real_lattice,
        representation.reciprocal_lattice,
        centers,
        frames,
    )
    iteration_diagnostics = EXPORT_WANNIERIZATION.WannierizationIterationDiagnostics(
        nothing,
        1.0,
        0.0,
        0.0,
        0.0,
        0.0,
        0.0,
        0.0,
        1.0,
        0.5,
        1.0,
        1,
        false,
        false,
        0,
        2.0e-4,
        0.25,
        3,
    )
    history =
        [EXPORT_WANNIERIZATION.WannierizationIteration(1, 1.0, 1.0e-4, 0.0, iteration_diagnostics)]
    diagnostic = EXPORT_WANNIERIZATION.WannierInitializationKPointDiagnostic(
        1,
        [1.0],
        [1.0],
        [1.0],
        Float64[],
        [1.0],
        1,
        1,
        1,
        0,
        0,
        0,
        1.0e-8,
        1.0e-8,
        1.0e-8,
        0.0,
        1.0,
        0.0,
        0.0,
        0.0,
        0.0,
    )
    report = EXPORT_WANNIERIZATION.WannierInitializationReport(
        :amn_full_bz_exact_frozen_embedding,
        "nosym_exact_frozen_rowspace_v2",
        :COMPLETED,
        [diagnostic],
    )
    summary = Dict(
        "requested_wannierization_mode" => "ordinary",
        "effective_wannierization_mode" => "ordinary",
        "representation_source" => "identity",
        "symmetry_constraints_applied" => "false",
        "effective_algorithm_profile" => "custom",
        "effective_symmetry_operation_count" => "1",
        "effective_antiunitary_operation_count" => "0",
        "requested_initializer" => "amn",
        "effective_initializer" => "amn_full_bz_exact_frozen_embedding",
        "initializer_algorithm_version" => "nosym_exact_frozen_rowspace_v2",
        "initialization_status" => "COMPLETED",
        "solver_status" => "MAX_ITERATIONS",
        "solver_convergence" => "MAX_ITERATIONS",
        "stopping_reason" => "MAX_ITERATIONS_REACHED",
        "last_attempted_iteration" => "1",
        "last_accepted_iteration" => "1",
        "last_persisted_iteration" => "1",
        "has_accepted_state" => "true",
        "legacy_terminal_semantics" => "false",
        "convergence_metric_name" => "center_spread_window_std_max",
        "convergence_metric" => "1.0e-4",
        "convergence_tolerance" => "1.0e-9",
        "hard_gate_isometry" => "0.0",
        "hard_gate_frozen" => "0.01",
        "hard_gate_covariance" => "0.0",
        "input_sha256" => repeat("e", 64),
        "authoritative_hamiltonian" => "native_dft",
        "authoritative_hamiltonian_sha256" => "LEGACY_NATIVE_DFT",
        "qualification_scope" => "full_parent",
        "target_authority" => "NOT_APPLICABLE",
        "parent_audit_policy" => "legacy_hard_gate",
        "disentanglement_outer_mask_sha256" => "NOT_SEALED",
        "disentanglement_frozen_mask_sha256" => "NOT_SEALED",
        "target_subspace_contract_sha256" => "NOT_RECORDED",
        "restart_config_sha256" => config_sha,
        "representation_sha256" => representation_sha,
        "projection_basis_sha256" => basis_sha,
        "amn_sha256" => amn_sha,
        "finite_difference_stencil_sha256" => stencil.digest,
        "spread_metric" => "full_3d",
        "optimizer_strategy" => "fixed",
        "optimizer_schedule" => "two_stage",
        "localization_steps" => "1",
        "projector_covariance_tolerance" => "NOT_APPLICABLE",
        "numerical_quality" => "INVALID_ACCEPTED_STATE",
        "tb_export_status" => "NOT_EXPORTED",
    )
    result = EXPORT_WANNIERIZATION.WannierizationResult(
        EXPORT_WANNIERIZATION.MAX_ITERATIONS,
        frames,
        centers,
        spreads,
        history,
        EXPORT_WANNIERIZATION.WannierizationDiagnostic[],
        summary,
        chk,
        nothing,
        restart_state,
        EXPORT_WANNIERIZATION.WannierizationArtifacts(),
        report,
    )
    return (; representation, basis, eig, mmn, config, result)
end
