using HDF5
using SHA
using Test
using WannierNLQG

if !isdefined(@__MODULE__, :WANNIERIZATION_FIXTURE_SUPPORT_LOADED)
    include(joinpath(@__DIR__, "WannierizationFixtureSupport.jl"))
end

@testset "Symmetrized DFT interval-10 periodic checkpoint metadata" begin
    W = WANNIERIZATION
    WI = WANNIER_IO
    mktempdir() do directory
        fixture = synthetic_wannierization_fixture()
        win = joinpath(directory, "model.win")
        eig = joinpath(directory, "model.eig")
        mmn = joinpath(directory, "model.mmn")
        write(win, "num_wann = 1\nmp_grid = 2 1 1\nbegin projections\nX:s\nend projections\n")
        open(eig, "w") do io
            for kpoint in 1:2, band in 1:2
                println(io, band, " ", kpoint, " ", fixture.eig.data[band, kpoint])
            end
        end
        WI.write_wannier_mmn(mmn, fixture.mmn)

        setup_file = joinpath(directory, "symmetrized_periodic_setup.jl")
        write(
            setup_file,
            raw"""
using WannierNLQG, HDF5, EzXML, JSON3, Spglib, LinearAlgebra, SHA
if !isdefined(@__MODULE__, :WANNIERIZATION_FIXTURE_SUPPORT_LOADED)
    include(joinpath(dirname(Base.active_project()), "test/WannierizationFixtureSupport.jl"))
end

function symmetrized_periodic_representation(fixture, policy::Symbol, gauge_sha256::String)
    r = fixture.representation
    shifts = zeros(Int, 3, 2, 2)
    shifts[1, 2, 2] = -1
    conventions = merge(
        r.conventions,
        Dict(
            "authoritative_hamiltonian" => "symmetrized_dft_hamiltonian",
            "auxiliary_parent_qualification" => "audit_only",
            "sewing_backend" => "augmentation_aware_paw_q0",
            "wavefunction_gauge_backend" => "star_covariant_paw",
            "wavefunction_gauge_hdf5_sha256" => gauge_sha256,
            "discrete_hamiltonian_correction" => "far_band_covariance_correction",
        ),
    )
    policy == :diagnostic &&
        (fixture.basis.blocks[1].positions_fractional[1, 1] = 1.0e-7)
    representation = WannierNLQG.SymmetryFoundation.BandRepresentation(
        r.schema_version,
        r.source_code,
        r.spinor,
        r.real_lattice,
        r.reciprocal_lattice,
        r.mp_grid,
        r.kpoints_fractional,
        r.energies_ev,
        [
            only(r.operations),
            WannierNLQG.SymmetryFoundation.SymmetryOperation(
                -Matrix{Int}(I, 3, 3),
                zeros(3),
                -Matrix{Float64}(I, 3, 3),
            ),
        ],
        repeat(r.kpoint_map, 2, 1),
        shifts,
        repeat(reshape(Matrix{ComplexF64}(I, 2, 2), 2, 2, 1, 1), 1, 1, 2, 2),
        r.band_block_labels,
        r.irreducible_indices,
        r.full_to_irreducible,
        r.full_to_operation;
        conventions,
        input_sha256 = r.input_sha256,
    )
    return (; fixture, representation)
end

function symmetrized_periodic_config(
    directory,
    policy::Symbol;
    observer = nothing,
    restart::Bool = false,
)
    W = WannierNLQG.Wannierization
    # This checkpoint-only fixture needs a stable gauge identity, not a serialized
    # PAW payload.  Keep the sentinel opaque and disable all terminal TB exporters.
    gauge_file = joinpath(directory, "synthetic-star-gauge.identity")
    isfile(gauge_file) || write(gauge_file, "synthetic sealed-gauge identity fixture\n")
    prepared = symmetrized_periodic_representation(
        synthetic_wannierization_fixture(),
        policy,
        bytes2hex(SHA.sha256(read(gauge_file))),
    )
    correction = W.FarBandCovarianceCorrection()
    gauge_backend = W.StarCovariantPAWGauge(
        block_partition_policy = W.HamiltonianWeightedPAWBlockPartition(),
        hamiltonian_correction = correction,
    )
    acceleration = W.WannierizationAccelerationConfig(
        schedule = :two_stage,
        disentanglement_max_steps = 20,
        localization_max_steps = 20,
        disentanglement_limit_policy =
            policy == :diagnostic ? :diagnostic_continue : :strict_hold,
    )
    checkpoint = joinpath(
        directory,
        restart ? "restart-$(policy).wannierization.h5" : "full-$(policy).wannierization.h5",
    )
    config = modified_wannierization_config(
        prepared.fixture.config;
        construction_policy = policy,
        authoritative_hamiltonian = W.SymmetrizedDFTHamiltonian(),
        sewing_backend = W.AugmentationAwareSewing(),
        wavefunction_gauge_backend = gauge_backend,
        wavefunction_gauge_hdf5 = gauge_file,
        projection_basis = prepared.fixture.basis,
        win_file = joinpath(directory, "model.win"),
        eig_file = joinpath(directory, "model.eig"),
        mmn_file = joinpath(directory, "model.mmn"),
        band_representation = prepared.representation,
        band_representation_hdf5 = nothing,
        compatibility_policy = :strict,
        acceleration,
        max_iterations = 12,
        convergence_window = 20,
        parallel = :threads,
        checkpoint_hdf5 = checkpoint,
        checkpoint_interval = 10,
        progress_interval = 0,
        iteration_observer = observer,
        write_wannier90_tb = false,
        tb_output_formats = (),
    )
    return restart ? modified_wannierization_config(
        config;
        initialization = :restart,
        restart_hdf5 = joinpath(directory, "periodic-$(policy).h5"),
    ) : config
end
""",
        )
        include(setup_file)

        periodic_hashes = Dict{Symbol, String}()
        for policy in (:strict, :diagnostic)
            periodic = joinpath(directory, "periodic-$(policy).h5")
            capture = function (snapshot, args...)
                snapshot.iteration == 10 && cp(
                    joinpath(directory, "full-$(policy).wannierization.h5"),
                    periodic;
                    force = true,
                )
            end
            config = Base.invokelatest(
                symmetrized_periodic_config,
                directory,
                policy;
                observer = capture,
            )
            full = W.construct_symmetry_adapted_wannier_functions(config)
            @test full.restart_state !== nothing
            @test !any(
                diagnostic ->
                    diagnostic.code in (:ITERATION_OBSERVER_PERSISTENCE_FAILED, :TB_EXPORT_FAILED),
                full.diagnostics,
            )
            @test isfile(periodic)
            prior = W.read_wannierization_checkpoint_hdf5(periodic)
            @test prior.status == W.IN_PROGRESS_CHECKPOINT
            @test prior.restart_state.iteration == 10
            @test prior.input_summary["construction_policy"] == String(policy)
            @test prior.input_summary["authoritative_hamiltonian"] == "symmetrized_dft_hamiltonian"
            @test prior.input_summary["qualification_scope"] == "target_subspace"
            @test prior.input_summary["parent_audit_policy"] == "audit_only"
            @test prior.input_summary["auxiliary_parent_qualification"] == "audit_only"
            @test prior.input_summary["production_eligible"] == "false"
            @test prior.input_summary["global_production_eligible"] == "false"
            @test prior.input_summary["manual_review_required"] == string(policy == :diagnostic)
            if policy == :diagnostic
                @test prior.input_summary["construction_quality_failed"] == "true"
                @test any(
                    diagnostic ->
                        diagnostic.code == :PROJECTION_CENTER_RESIDUAL &&
                        get(diagnostic.context, "gate_result", "") == "FAIL",
                    prior.diagnostics,
                )
            else
                @test !haskey(prior.input_summary, "construction_quality_failed")
            end
            periodic_hashes[policy] = bytes2hex(SHA.sha256(read(periodic)))
        end

        child = raw"""
using Test
include(ARGS[1])
W = WannierNLQG.Wannierization
@testset "Fresh symmetrized interval-10 periodic readback and resume" begin
    for policy in (:strict, :diagnostic)
        prior_path = joinpath(ARGS[2], "periodic-$(policy).h5")
        prior = W.read_wannierization_checkpoint_hdf5(prior_path)
        full = W.read_wannierization_checkpoint_hdf5(
            joinpath(ARGS[2], "full-$(policy).wannierization.h5"),
        )
        recovered = W.construct_symmetry_adapted_wannier_functions(
            symmetrized_periodic_config(ARGS[2], policy; restart = true),
        )
        @test recovered.restart_state !== nothing
        @test recovered.restart_state.config_sha256 == prior.restart_state.config_sha256
        @test recovered.restart_state.representation_sha256 ==
              prior.restart_state.representation_sha256
        @test recovered.restart_state.stencil.digest == prior.restart_state.stencil.digest
        @test recovered.restart_state.iteration - prior.restart_state.iteration <= 2
        @test recovered.v_matrix == full.v_matrix
        @test recovered.spreads_angstrom2 == full.spreads_angstrom2
        @test recovered.status == full.status
            @test isequal(recovered.history[1:length(prior.history)], prior.history)
            @test recovered.input_summary["auxiliary_parent_qualification"] == "audit_only"
        end
end
println("FRESH_SYMMETRIZED_INTERVAL10_PERIODIC_RESTART_PASS")
"""
        command =
            `$(Base.julia_cmd()) --startup-file=no --threads=1 --project=$(dirname(@__DIR__)) -e $(child) $(setup_file) $(directory)`
        child_output = read(ignorestatus(command), String)
        @test occursin("FRESH_SYMMETRIZED_INTERVAL10_PERIODIC_RESTART_PASS", child_output)
        for (policy, digest) in periodic_hashes
            @test bytes2hex(SHA.sha256(read(joinpath(directory, "periodic-$(policy).h5")))) ==
                  digest
        end

        diagnostic_periodic = joinpath(directory, "periodic-diagnostic.h5")
        missing_summary = joinpath(directory, "periodic-diagnostic-missing-summary.h5")
        cp(diagnostic_periodic, missing_summary)
        HDF5.h5open(missing_summary, "r+") do handle
            HDF5.delete_attribute(handle["input_summary"], "auxiliary_parent_qualification")
        end
        missing_error = try
            W.read_wannierization_checkpoint_hdf5(missing_summary)
            nothing
        catch exception
            sprint(showerror, exception)
        end
        @test occursin(
            "TARGET_SUBSPACE_CONTRACT_MISMATCH: symmetrized authority requires audit-only auxiliary parent",
            something(missing_error, ""),
        )

        tampered_root = joinpath(directory, "periodic-diagnostic-tampered-root.h5")
        cp(diagnostic_periodic, tampered_root)
        HDF5.h5open(tampered_root, "r+") do handle
            HDF5.delete_attribute(handle, "auxiliary_parent_qualification")
            HDF5.attributes(handle)["auxiliary_parent_qualification"] = "legacy_hard_gate"
        end
        tampered_error = try
            W.read_wannierization_checkpoint_hdf5(tampered_root)
            nothing
        catch exception
            sprint(showerror, exception)
        end
        @test occursin(
            "TARGET_SUBSPACE_CONTRACT_MISMATCH: checkpoint auxiliary_parent_qualification differs",
            something(tampered_error, ""),
        )
    end
end
