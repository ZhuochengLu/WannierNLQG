using Test, LinearAlgebra, TOML, HDF5
include(
    joinpath(
        @__DIR__,
        "..",
        "ext",
        "WannierNLQGWannierizationExt",
        "PrecompileSupport",
        "TinyWannierWorkflowInputs.jl",
    ),
)

@testset "Accepted-stage restart lifecycle" begin
    w = WannierNLQG.Wannierization
    r = WannierNLQG.Runtime
    mktempdir() do dir
        inputs = tiny_wannier_workflow(dir)
        rm(inputs.solve.input.win_file)
        amn = joinpath(dir, "tiny.amn")
        WannierNLQG.IO.write_wannier_amn(
            amn,
            WannierNLQG.IO.WannierAMN(2, 2, 1, reshape(ComplexF64[1, 0, 1, 0], 2, 1, 2)),
        )
        base = Dict{String, Any}(
            "workflow"=>"wannierization",
            "mode"=>"ordinary",
            "structure"=>Dict(
                "lattice_angstrom"=>[[1.0, 0.0, 0.0], [0.0, 1.0, 0.0], [0.0, 0.0, 1.0]],
                "species"=>["X"],
                "positions_fractional"=>[[0.0, 0.0, 0.0]],
            ),
            "kmesh"=>Dict(
                "dimensions"=>[2, 1, 1],
                "points_fractional"=>[[0.0, 0.0, 0.0], [0.5, 0.0, 0.0]],
            ),
            "basis"=>Dict("projections"=>["X:s"]),
            "matrices"=>Dict(
                "eig_file"=>"tiny.eig",
                "mmn_file"=>"tiny.mmn",
                "amn_file"=>"tiny.amn",
            ),
            "windows"=>Dict("outer_min_ev"=>-2.0, "outer_max_ev"=>2.0),
        )

        function configured(name; window = 0, restart = nothing, z = 2, u = 1)
            doc = deepcopy(base)
            doc["solver"] = Dict(
                "initialization"=>(restart === nothing ? "amn" : "restart"),
                "dis_num_iter"=>z,
                "num_iter"=>u,
                "conv_window"=>window,
            )
            doc["output"] = Dict(
                "checkpoint_hdf5"=>name*".wannierization.h5",
                "model_file"=>name*".model.h5",
                "num_print_cycles"=>0,
                "num_dump_cycles"=>1,
            )
            restart === nothing || (doc["checkpoint"] = Dict("restart_hdf5"=>restart))
            return r.resolve_workflow_input(doc; base_dir = dir)
        end
        reference_input = configured("reference")
        z_checkpoint = joinpath(dir, "accepted_z1.wannierization.h5")
        stage_checkpoint = joinpath(dir, "accepted_z2.wannierization.h5")
        function record_stage(snapshot, state, history, diagnostics)
            if state.optimizer_state.z_steps == 1 && state.optimizer_state.u_steps == 0
                w.write_wannierization_checkpoint_hdf5(
                    z_checkpoint,
                    w.read_wannierization_checkpoint_hdf5(
                        reference_input.config.checkpoint.checkpoint_hdf5,
                    ),
                )
            elseif state.optimizer_state.z_steps == 2 && state.optimizer_state.u_steps == 0
                w.write_wannierization_checkpoint_hdf5(
                    stage_checkpoint,
                    w.read_wannierization_checkpoint_hdf5(
                        reference_input.config.checkpoint.checkpoint_hdf5,
                    ),
                )
            end
        end
        cfg = reference_input.config
        runtime = typeof(cfg.runtime)(;
            (
                name =>
                    (name == :iteration_observer ? record_stage : getfield(cfg.runtime, name))
                for name in fieldnames(typeof(cfg.runtime))
            )...,
        )
        observed = typeof(cfg)(;
            (
                name => (name == :runtime ? runtime : getfield(cfg, name)) for
                name in fieldnames(typeof(cfg))
            )...,
        )
        reference = w.construct_wannier_functions(observed)
        @test reference.status ∉ (w.INVALID_INPUT, w.IO_FAILURE, w.LOCALIZATION_FAILED)
        @test reference.restart_state.optimizer_state.z_steps == 2
        @test reference.restart_state.optimizer_state.u_steps == 1
        HDF5.h5open(z_checkpoint, "r") do handle
            @test read(HDF5.attributes(handle)["schema_version"]) == "3.0"
            optimizer=handle["restart_state/optimizer"]
            for name in (
                "anderson_z_history",
                "anderson_residual_history",
                "u_lbfgs_s_history",
                "u_lbfgs_y_history",
                "u_lbfgs_rho_history",
            )
                @test !haskey(optimizer, name)
            end
            @test !haskey(HDF5.attributes(optimizer), "u_lbfgs_restart_count")
        end
        @test isfile(z_checkpoint)
        @test isfile(stage_checkpoint)
        for (label, path) in (("resume_z", z_checkpoint), ("resume_boundary", stage_checkpoint))
            result = r.run_task_input(
                configured(label; restart = path);
                record_directory = joinpath(dir, label),
            )
            println("PERIODIC_RESTART_DIAGNOSTICS ", label, " ", result.status)
            for diagnostic in result.diagnostics
                show(stdout, diagnostic);
                println()
            end
            if result.restart_state === nothing
                @test result.status == reference.status
                continue
            end
            @test result.status == reference.status
            @test isequal(result.v_matrix, reference.v_matrix)
            @test isequal(result.wannier_centers_cartesian, reference.wannier_centers_cartesian)
            @test isequal(result.spreads_angstrom2, reference.spreads_angstrom2)
            @test result.restart_state.optimizer_state.z_steps == 2
            @test result.restart_state.optimizer_state.u_steps == 1
            @test result.restart_state.optimizer_state.disentanglement_objective_history ==
                  reference.restart_state.optimizer_state.disentanglement_objective_history
            @test result.restart_state.optimizer_state.localization_objective_history ==
                  reference.restart_state.optimizer_state.localization_objective_history
            @test length(result.history) == length(reference.history)
        end
    end
end

@testset "Referenced checkpoint complete solver and recovery lifecycle" begin
    w=WannierNLQG.Wannierization
    runtime=WannierNLQG.Runtime
    input_io=WannierNLQG.IO
    fixture_parent=mktempdir(; cleanup = false)
    root=realpath(mktempdir(fixture_parent; cleanup = false))
    # Keep this small owned fixture on failure for diagnosis; never modify assets.
    dir=mktempdir(root; cleanup = false)
    @test_throws ArgumentError input_io.scientific_reference_path(
        root,
        joinpath(dir, "absent.reference"),
    )
    @test_throws ArgumentError input_io.scientific_reference_path(root, dir)
    fixture=tiny_wannier_workflow(dir)
    rm(fixture.solve.input.win_file)
    input_io.write_wannier_amn(
        joinpath(dir, "tiny.amn"),
        input_io.WannierAMN(2, 2, 1, reshape(ComplexF64[1, 0, 1, 0], 2, 1, 2)),
    )
    base=Dict{String, Any}(
        "workflow"=>"wannierization",
        "mode"=>"ordinary",
        "structure"=>Dict(
            "lattice_angstrom"=>[[1.0, 0.0, 0.0], [0.0, 1.0, 0.0], [0.0, 0.0, 1.0]],
            "species"=>["X"],
            "positions_fractional"=>[[0.0, 0.0, 0.0]],
        ),
        "kmesh"=>Dict(
            "dimensions"=>[2, 1, 1],
            "points_fractional"=>[[0.0, 0.0, 0.0], [0.5, 0.0, 0.0]],
        ),
        "basis"=>Dict("projections"=>["X:s"]),
        "matrices"=>Dict("eig_file"=>"tiny.eig", "mmn_file"=>"tiny.mmn", "amn_file"=>"tiny.amn"),
        "windows"=>Dict("outer_min_ev"=>-2.0, "outer_max_ev"=>2.0),
    )
    function light_config(label; storage = :embedded, restart = nothing, observer = nothing)
        doc=deepcopy(base)
        doc["solver"]=Dict(
            "initialization"=>(restart===nothing ? "amn" : "restart"),
            "dis_num_iter"=>2,
            "num_iter"=>1,
            "conv_window"=>0,
        )
        doc["checkpoint"]=Dict{String, Any}("storage"=>String(storage))
        storage==:referenced && (doc["checkpoint"]["reference_root"]=root)
        restart===nothing || (doc["checkpoint"]["restart_hdf5"]=restart)
        doc["output"]=Dict(
            "checkpoint_hdf5"=>label*".wannierization.h5",
            "model_file"=>label*".model.h5",
            "num_print_cycles"=>0,
            "num_dump_cycles"=>1,
            "tb_output_formats"=>["packed_hdf5", "model_tb"],
            "write_model_tb"=>true,
        )
        config=runtime.resolve_workflow_input(doc; base_dir = dir).config
        return observer===nothing ? config :
               w.reconfigure_wannierization(config; runtime = (iteration_observer = observer,))
    end
    results=Dict{Symbol, Any}()
    z_paths=Dict{Symbol, String}()
    for storage in (:embedded, :referenced)
        z_path=joinpath(dir, String(storage)*"-accepted-z1.wannierization.h5")
        z_paths[storage]=z_path
        function capture_z(snapshot, state, history, diagnostics)
            if state.optimizer_state.z_steps==1 && state.optimizer_state.u_steps==0
                current=joinpath(dir, String(storage)*".wannierization.h5")
                source_root=storage==:referenced ? root : nothing
                accepted=w.read_wannierization_checkpoint_hdf5(
                    current;
                    reference_root = source_root,
                )
                w.write_wannierization_checkpoint_hdf5(
                    z_path,
                    accepted;
                    reference_root = source_root,
                )
            end
        end
        result=w.construct_wannier_functions(
            light_config(String(storage); storage, observer = capture_z),
        )
        @test result.status in (w.COMPLETED, w.COMPLETED_WITH_WARNINGS, w.MAX_ITERATIONS)
        result.status in (w.COMPLETED, w.COMPLETED_WITH_WARNINGS, w.MAX_ITERATIONS) ||
            error("Solver/persistence failure: $(result.diagnostics)")
        @test result.restart_state!==nothing
        result.restart_state===nothing &&
            error("Missing accepted checkpoint: $(result.diagnostics)")
        @test result.restart_state.optimizer_state.z_steps==2
        @test result.restart_state.optimizer_state.u_steps==1
        @test isfile(z_path)
        source_root=storage==:referenced ? root : nothing
        restored=w.read_wannierization_checkpoint_hdf5(
            result.artifacts.checkpoint_hdf5;
            reference_root = source_root,
        )
        @test isequal(restored.v_matrix, result.v_matrix)
        @test isequal(restored.spreads_angstrom2, result.spreads_angstrom2)
        @test restored.input_summary["checkpoint_schema_version"]==(
            storage==:embedded ? "3.0" : "3.1"
        )
        results[storage]=result
    end
    embedded=results[:embedded];
    referenced=results[:referenced]
    @test isequal(embedded.v_matrix, referenced.v_matrix)
    @test isequal(embedded.spreads_angstrom2, referenced.spreads_angstrom2)
    @test isequal(embedded.wannier_centers_cartesian, referenced.wannier_centers_cartesian)
    @test embedded.restart_state.optimizer_state.disentanglement_objective_history ==
          referenced.restart_state.optimizer_state.disentanglement_objective_history
    for storage in (:embedded, :referenced)
        resumed=w.construct_wannier_functions(
            light_config("resume-"*String(storage); storage, restart = z_paths[storage]),
        )
        @test resumed.status==results[storage].status
        @test isequal(resumed.v_matrix, results[storage].v_matrix)
        @test isequal(resumed.spreads_angstrom2, results[storage].spreads_angstrom2)
        @test resumed.restart_state.optimizer_state.z_steps==2
        @test resumed.restart_state.optimizer_state.u_steps==1
    end
    for result in values(results)
        bundle=input_io.read_real_space_operator_bundle(result.artifacts.packed_hdf5)
        tb=input_io.read_wannier_tb(result.artifacts.model_tb)
        @test bundle.manifest.r_vectors==tb.r_vectors
        @test bundle.manifest.degeneracies==tb.r_degeneracies
        H=bundle.operators[input_io.REAL_SPACE_HAMILTONIAN].data
        position=bundle.operators[input_io.REAL_SPACE_POSITION].data
        # Reuse the actual %.14e writer roundtrip bound, not a physics tolerance.
        function written_component_equal(x, y)
            isfinite(x) && isfinite(y) || return false
            iszero(x) && return iszero(y)
            return abs(x-y)<=0.51*10.0^(floor(log10(abs(x)))-14)+8*eps(abs(x))
        end
        written_equal(
            x,
            y,
        )=written_component_equal(real(x), real(y)) && written_component_equal(imag(x), imag(y))
        @test size(H)==size(tb.hamiltonian_r) &&
              all(pair->written_equal(pair...), zip(H, tb.hamiltonian_r))
        @test size(position)==size(tb.position_r) &&
              all(pair->written_equal(pair...), zip(position, tb.position_r))
    end
    @test_throws ArgumentError w.read_wannierization_checkpoint_hdf5(
        referenced.artifacts.checkpoint_hdf5,
    )
    archive=joinpath(
        @__DIR__,
        "fixtures",
        "current_checkpoint_workload",
        "synthetic.wannierization.h5",
    )
    archived=w.adopt_wannierization_checkpoint_hdf5(
        archive;
        receipt_path = joinpath(dir, "archive.commit.toml"),
    )
    @test archived.input_summary["checkpoint_schema_version"]=="3.0"
    proof=referenced.restart_state.input_definition
    objects=Dict{String, Any}()
    for definition in (
        proof.representation,
        proof.overlaps,
        proof.initialization,
        values(proof.auxiliary_sources)...,
    )
        layout=input_io.scientific_input_definition_reference_layout(definition)
        @test layout!==nothing
        for object in layout.objects
            objects[object.path]=object
        end
    end
    relocated=mktempdir(dirname(root); cleanup = false)
    for object in values(objects)
        target=joinpath(relocated, relpath(object.path, root));
        mkpath(dirname(target));
        cp(object.path, target)
    end
    moved_checkpoint=joinpath(relocated, "relocated.wannierization.h5")
    cp(referenced.artifacts.checkpoint_hdf5, moved_checkpoint)
    receipt=joinpath(relocated, "relocated.commit.toml")
    adopted=w.adopt_wannierization_checkpoint_hdf5(
        moved_checkpoint;
        reference_root = relocated,
        receipt_path = receipt,
    )
    @test isequal(adopted.v_matrix, referenced.v_matrix)
    changed=joinpath(relocated, relpath(first(values(objects)).path, root))
    prior=read(changed);
    altered=copy(prior);
    altered[1]⊻=0x01;
    write(changed, altered)
    @test_throws ArgumentError w.read_wannierization_checkpoint_hdf5(
        moved_checkpoint;
        reference_root = relocated,
        receipt_path = receipt,
    )
    write(changed, prior)
    mv(changed, changed*".held-missing")
    @test_throws ArgumentError w.read_wannierization_checkpoint_hdf5(
        moved_checkpoint;
        reference_root = relocated,
        receipt_path = receipt,
    )
    # A bad replacement must not damage an existing checkpoint/publication pair.
    old_bytes=read(referenced.artifacts.checkpoint_hdf5)
    old_receipt=read(referenced.artifacts.checkpoint_hdf5*".commit.toml")
    @test_throws ArgumentError w.write_wannierization_checkpoint_hdf5(
        referenced.artifacts.checkpoint_hdf5,
        adopted;
        reference_root = relocated,
    )
    @test read(referenced.artifacts.checkpoint_hdf5)==old_bytes
    @test read(referenced.artifacts.checkpoint_hdf5*".commit.toml")==old_receipt
    @test isequal(
        w.read_wannierization_checkpoint_hdf5(
            referenced.artifacts.checkpoint_hdf5;
            reference_root = root,
        ).v_matrix,
        referenced.v_matrix,
    )
    println(
        "LIGHT_CHECKPOINT_FIXTURE ",
        dir,
        " relocation=",
        relocated,
        " embedded_bytes=",
        filesize(embedded.artifacts.checkpoint_hdf5),
        " referenced_bytes=",
        filesize(referenced.artifacts.checkpoint_hdf5),
    )
end
