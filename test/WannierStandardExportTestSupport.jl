isdefined(@__MODULE__, :InternalSolverFixture) ||
    include(joinpath(@__DIR__, "support", "InternalSolverFixture.jl"))
using HDF5
using LinearAlgebra
using SHA
using Test

const EXPORT_WANNIERIZATION = WannierNLQG.Wannierization
const EXPORT_SYMMETRIZATION = WannierNLQG.Symmetrization
const EXPORT_IO = WannierNLQG.IO

function standard_export_fixture(;
    mmn_override = nothing,
    real_lattice_override = nothing,
    centers_override = nothing,
    frames_override = nothing,
)
    real_lattice =
        real_lattice_override === nothing ? Matrix{Float64}(I, 3, 3) :
        Matrix{Float64}(real_lattice_override)
    reciprocal_lattice = 2pi * inv(transpose(real_lattice))
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
        real_lattice,
        reciprocal_lattice,
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
    config = EXPORT_WANNIERIZATION.WannierizationConfig(
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
        solver = InternalSolverFixture.solver_config(initialization = :amn),
        checkpoint = EXPORT_WANNIERIZATION.WannierizationCheckpointConfig(),
        runtime = EXPORT_WANNIERIZATION.WannierizationRuntimeConfig(),
        output = EXPORT_WANNIERIZATION.WannierizationOutputConfig(
            write_model_tb = true,
            tb_output_formats = (:packed_hdf5, :model_tb),
        ),
    )
    frames = zeros(ComplexF64, 2, 1, 2)
    frames[1, 1, :] .= 1.0
    if frames_override !== nothing
        size(frames_override) == size(frames) || error("accepted-state frame shape mismatch")
        frames .= frames_override
        all(isfinite, frames) || error("nonfinite accepted-state fixture frame")
    end
    centers =
        centers_override === nothing ? zeros(Float64, 1, 3) : Matrix{Float64}(centers_override)
    size(centers) == (1, 3) || error("accepted-state fixture center shape mismatch")
    spreads = [1.0]
    stencil = EXPORT_WANNIERIZATION._finite_difference_weights(representation, mmn)
    basis_sha = EXPORT_WANNIERIZATION._projection_basis_definition(basis)
    # Raw synthetic accepted-state fixture: no fabricated restart/input authentication.
    # Continuation tests must supply actual inputs through the current definition port.
    restart_state = EXPORT_WANNIERIZATION.WannierizationRestartState(
        1,
        frames,
        nothing,
        centers,
        spreads,
        reshape([0.0, 0.0, 0.0, 1.0], 4, 1),
        trues(2, 2),
        0.0,
        stencil,
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
        "authoritative_hamiltonian" => "native_dft",
        "qualification_scope" => "full_parent",
        "target_authority" => "NOT_APPLICABLE",
        "parent_audit_policy" => "legacy_hard_gate",
        "projection_basis_definition" => basis_sha,
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

# Codec fixture only: encode the actual selected states of the existing finite
# EIG and explicit frozen-state list. No production input/config is altered.
function standard_export_target_contract(fixture)
    energies = fixture.eig.data
    outer = copy(something(fixture.result.restart_state).included_bands)
    frozen = falses(size(outer))
    for (kpoint, band) in fixture.config.input.frozen_states
        frozen[band, kpoint] = true
    end
    lower, upper = extrema(energies)
    frozen_energies = energies[frozen]
    frozen_lower, frozen_upper = extrema(frozen_energies)
    @assert outer == ((lower .<= energies) .& (energies .<= upper))
    @assert frozen == ((frozen_lower .<= energies) .& (energies .<= frozen_upper))
    scope = WannierNLQG.SymmetryFoundation.BandRepresentationQualificationScope(
        outer,
        frozen;
        content_authentication = false,
    )
    return EXPORT_WANNIERIZATION.TargetSubspaceQualificationContract(
        scope;
        outer_min_ev = lower,
        outer_max_ev = upper,
        frozen_min_ev = frozen_lower,
        frozen_max_ev = frozen_upper,
        num_wannier = fixture.config.input.num_wannier,
    )
end
