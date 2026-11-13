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
        isdefined(@__MODULE__, :prepare_periodic_symmetrized_inputs) ||
            include(joinpath(@__DIR__, "PeriodicSymmetrizedSourceTestSupport.jl"))
        prepared_inputs = Base.invokelatest(prepare_periodic_symmetrized_inputs, directory)
        @test prepared_inputs.representation.schema_version == "1.0"
        println("PERIODIC_MATHEMATICAL_INPUTS_READY")
        flush(stdout)

        setup_file = joinpath(directory, "symmetrized_periodic_setup.jl")
        write(
            setup_file,
            raw"""
using WannierNLQG, HDF5, EzXML, JSON3, Spglib, LinearAlgebra, SHA
if !isdefined(@__MODULE__, :WANNIERIZATION_FIXTURE_SUPPORT_LOADED)
    include(joinpath(dirname(Base.active_project()), "test/WannierizationFixtureSupport.jl"))
end

isdefined(@__MODULE__, :prepare_periodic_symmetrized_inputs) ||
    include(joinpath(dirname(Base.active_project()), "test/PeriodicSymmetrizedSourceTestSupport.jl"))

function symmetrized_periodic_config(
    directory,
    quality_case::Symbol;
    observer = nothing,
    restart::Bool = false,
)
    W = WannierNLQG.Wannierization
    fixture = synthetic_wannierization_fixture()
    actual_inputs = JSON3.read(read(joinpath(directory, "periodic-inputs.json"), String))
    gauge_file = String(actual_inputs.gauge_file)
    representation_file = String(actual_inputs.representation_file)
    isfile(gauge_file) && isfile(representation_file) || error("PERIODIC_ACTUAL_INPUT_ARTIFACT_MISSING")
    source = periodic_symmetrized_source(directory)
    basis = periodic_symmetrized_basis(; warning = quality_case == :warning)
    correction = W.FarBandCovarianceCorrection()
    gauge_backend = W.StarCovariantPAWGauge(
        buffer_policy = W.ClosureDrivenBandBuffer(max_extra_bands = 0),
        block_partition_policy = W.HamiltonianWeightedPAWBlockPartition(),
        hamiltonian_correction = correction,
    )
    acceleration = W.WannierizationAccelerationConfig(
        schedule = :two_stage,
        disentanglement_max_steps = 20,
        localization_max_steps = 20,
        disentanglement_limit_policy =
            quality_case == :warning ? :standard_continue : :strict_hold,
    )
    checkpoint = joinpath(
        directory,
        restart ? "restart-$(quality_case).wannierization.h5" : "full-$(quality_case).wannierization.h5",
    )
    config = modified_wannierization_config(
        fixture.config;
        source,
        construction_policy = :standard,
        authoritative_hamiltonian = W.SymmetrizedDFTHamiltonian(),
        sewing_backend = W.AugmentationAwareSewing(),
        wavefunction_gauge_backend = gauge_backend,
        wavefunction_gauge_hdf5 = gauge_file,
        projection_basis = basis,
        win_file = joinpath(directory, "model.win"),
        eig_file = joinpath(directory, "model.eig"),
        mmn_file = joinpath(directory, "model.mmn"),
        band_representation = nothing,
        band_representation_hdf5 = representation_file,
        compatibility_policy = :strict,
        # Exercise accepted Z steps rather than the fully-frozen no-op branch.
        frozen_min_ev = -2.0, frozen_max_ev = -1.5,
        acceleration,
        # Twelve accepted Z updates retain the original interval-10 restart
        # checkpoint and two-update suffix; U is not part of this metadata fixture.
        stage_controls = W.WannierizationStageControls(
            dis_num_iter = 12, num_iter = 0,
            dis_conv_tol = 1.0e-10, dis_conv_window = 20,
            conv_tol = 1.0e-10, conv_window = 20,
        ),
        parallel = :threads,
        checkpoint_hdf5 = checkpoint,
        num_dump_cycles = 10,
        num_print_cycles = 0,
        iteration_observer = observer,
        write_model_tb = false,
        tb_output_formats = (),
    )
    return restart ? modified_wannierization_config(
        config;
        initialization = :restart,
        restart_hdf5 = joinpath(directory, "periodic-$(quality_case).h5"),
    ) : config
end
""",
        )
        include(setup_file)

        periodic_hashes = Dict{Symbol, String}()
        for quality_case in (:clean, :warning)
            periodic = joinpath(directory, "periodic-$(quality_case).h5")
            capture = function (snapshot, args...)
                snapshot.iteration == 10 && cp(
                    joinpath(directory, "full-$(quality_case).wannierization.h5"),
                    periodic;
                    force = true,
                )
            end
            config = Base.invokelatest(
                symmetrized_periodic_config,
                directory,
                quality_case;
                observer = capture,
            )
            full = W.construct_wannier_functions(config)
            println("PERIODIC_CASE_STATUS=", quality_case, " ", full.status)
            flush(stdout)
            if full.restart_state === nothing
                println(stderr, "PERIODIC_FIXTURE_STATUS=", full.status)
                for diagnostic in full.diagnostics
                    println(stderr, "PERIODIC_FIXTURE_DIAGNOSTIC=", repr(diagnostic))
                end
            end
            @test full.restart_state !== nothing
            # Do not let a missing fixture produce a second missing-file exception
            # that hides its original solver failure. This assertion still fails.
            full.restart_state === nothing && return
            @test full.status in (W.COMPLETED, W.COMPLETED_WITH_WARNINGS, W.MAX_ITERATIONS)
            @test full.restart_state.optimizer_state.z_steps == 12
            @test full.restart_state.optimizer_state.u_steps == 0
            @test !any(
                diagnostic ->
                    diagnostic.code in (:ITERATION_OBSERVER_PERSISTENCE_FAILED, :TB_EXPORT_FAILED),
                full.diagnostics,
            )
            @test isfile(periodic)
            # A copied checkpoint is a relocated input and needs explicit adoption.
            @test_throws ArgumentError W.read_wannierization_checkpoint_hdf5(periodic)
            W.adopt_wannierization_checkpoint_hdf5(periodic)
            prior = W.read_wannierization_checkpoint_hdf5(periodic)
            @test prior.status == W.IN_PROGRESS_CHECKPOINT
            @test prior.restart_state.iteration == 10
            @test prior.input_summary["construction_policy"] == "standard"
            @test prior.input_summary["authoritative_hamiltonian"] == "symmetrized_dft_hamiltonian"
            @test prior.input_summary["qualification_scope"] == "target_subspace"
            @test prior.input_summary["parent_audit_policy"] == "audit_only"
            @test prior.input_summary["auxiliary_parent_qualification"] == "audit_only"
            @test !isempty(prior.input_summary["disentanglement_outer_mask_definition"])
            @test !isempty(prior.input_summary["disentanglement_frozen_mask_definition"])
            @test !isempty(prior.input_summary["target_subspace_contract_definition"])
            @test prior.input_summary["quality_review_recommended"] ==
                  string(quality_case == :warning)
            if quality_case == :warning
                @test prior.input_summary["construction_quality_failed"] == "true"
                @test any(
                    diagnostic ->
                        diagnostic.code == :PROJECTION_CENTER_RESIDUAL &&
                        get(diagnostic.context, "gate_result", "") == "FAIL",
                    prior.diagnostics,
                )
            else
                @test !any(
                    diagnostic ->
                        diagnostic.code == :PROJECTION_CENTER_RESIDUAL &&
                        get(diagnostic.context, "gate_result", "") == "FAIL",
                    prior.diagnostics,
                )
            end
            periodic_hashes[quality_case] = bytes2hex(SHA.sha256(read(periodic)))
        end

        child = raw"""
using Test
include(ARGS[1])
W = WannierNLQG.Wannierization
@testset "Fresh symmetrized interval-10 periodic readback and resume" begin
    for quality_case in (:clean, :warning)
        prior_path = joinpath(ARGS[2], "periodic-$(quality_case).h5")
        prior = W.read_wannierization_checkpoint_hdf5(prior_path)
        full = W.read_wannierization_checkpoint_hdf5(
            joinpath(ARGS[2], "full-$(quality_case).wannierization.h5"),
        )
        recovered = W.construct_wannier_functions(
            symmetrized_periodic_config(ARGS[2], quality_case; restart = true),
        )
        println("PERIODIC_FRESH_STATUS=", quality_case, " ", recovered.status)
        for diagnostic in recovered.diagnostics
            println("PERIODIC_FRESH_DIAGNOSTIC=", repr(diagnostic))
        end
        flush(stdout)
        @test recovered.restart_state !== nothing
        recovered.restart_state === nothing && continue
        @test recovered.restart_state.optimizer_state.z_steps == 12
        @test recovered.restart_state.optimizer_state.u_steps == 0
        @test something(recovered.restart_state.input_definition).configuration == something(prior.restart_state.input_definition).configuration
        @test WannierNLQG.IO.validate_scientific_input_definitions_equal(
                something(recovered.restart_state.input_definition).representation,
                something(prior.restart_state.input_definition).representation) === nothing
        for field in fieldnames(W.WannierizationFiniteDifferenceStencil)
                @test isequal(getfield(recovered.restart_state.stencil, field),
                              getfield(prior.restart_state.stencil, field))
            end
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
        for (quality_case, digest) in periodic_hashes
            @test bytes2hex(SHA.sha256(read(joinpath(directory, "periodic-$(quality_case).h5")))) ==
                  digest
        end

        warning_periodic = joinpath(directory, "periodic-warning.h5")
        # Test-only publication of deliberately invalid current-format fixtures.
        # Keep the reader's domain rejection assertions below reachable.
        function publish_invalid_checkpoint_fixture(path)
            checkpoint = first(W._load_wannierization_extension!()).SolverCheckpoint
            WannierNLQG.IO.write_scientific_file_publication(
                path;
                artifact_schema = checkpoint.WANNIERIZATION_CHECKPOINT_SCHEMA,
                artifact_version = checkpoint.WANNIERIZATION_CHECKPOINT_SCHEMA_VERSION,
                publication_identity = W.read_wannierization_checkpoint_hdf5(warning_periodic).input_summary["checkpoint_publication_identity"],
            )
        end

        missing_summary = joinpath(directory, "periodic-diagnostic-missing-summary.h5")
        cp(warning_periodic, missing_summary)
        chmod(missing_summary, 0o600)
        HDF5.h5open(missing_summary, "r+") do handle
            @test String(
                read(HDF5.attributes(handle["input_summary"])["auxiliary_parent_qualification"]),
            ) == "audit_only"
            HDF5.delete_attribute(handle["input_summary"], "auxiliary_parent_qualification")
            @test !haskey(
                HDF5.attributes(handle["input_summary"]),
                "auxiliary_parent_qualification",
            )
        end
        publish_invalid_checkpoint_fixture(missing_summary)
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
        cp(warning_periodic, tampered_root)
        chmod(tampered_root, 0o600)
        HDF5.h5open(tampered_root, "r+") do handle
            @test String(read(HDF5.attributes(handle)["auxiliary_parent_qualification"])) ==
                  "audit_only"
            HDF5.delete_attribute(handle, "auxiliary_parent_qualification")
            HDF5.attributes(handle)["auxiliary_parent_qualification"] = "legacy_hard_gate"
        end
        HDF5.h5open(tampered_root, "r") do handle
            @test String(read(HDF5.attributes(handle)["auxiliary_parent_qualification"])) ==
                  "legacy_hard_gate"
        end
        publish_invalid_checkpoint_fixture(tampered_root)
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
