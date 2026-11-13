using Test, TOML, SHA, LinearAlgebra
@testset "Native VASP nonzero U, continuation and demanded generation" begin
    w=WannierNLQG.Wannierization;
    r=WannierNLQG.Runtime;
    io=WannierNLQG.IO
    saved=only(
        filter(p->startswith(basename(p), "vasp-entry-"), readdir(spec["saved_vasp"]; join = true)),
    )
    base=TOML.parsefile(joinpath(saved, "records", "effective_config.toml"))
    directory=mktempdir(out; prefix = "vasp-operators-", cleanup = false)
    # Enlarge only the synthetic fixture cutoff so all periodic neighbor overlaps exist.
    fixture=joinpath(directory, "source");
    mkpath(fixture)
    for key in ("poscar_file", "potcar_file", "incar_file", "outcar_file")
        dest=joinpath(fixture, basename(base["source"][key]));
        cp(base["source"][key], dest)
        base["source"][key]=dest
    end
    write(
        base["source"]["outcar_file"],
        replace(read(base["source"]["outcar_file"], String), "ENCUT = 5.000"=>"ENCUT = 30.000"),
    )
    wave=joinpath(fixture, "WAVECAR");
    base["source"]["wavecar_file"]=wave
    sf=WannierNLQG.SymmetryFoundation;
    recip=Matrix{Float64}(I, 3, 3) .* (2pi/5)
    grid=sf._vasp_g_grid(sf._vasp_grid_bounds(recip, 30.0));
    record=4096
    open(wave, "w+") do stream
        write(stream, zeros(UInt8, 8record));
        seek(stream, 0);
        write(stream, Float64[record, 1, 45210])
        seek(stream, record);
        write(stream, Float64[2, 2, 30, 5, 0, 0, 0, 5, 0, 0, 0, 5, 0])
        for k in 1:2
            point=[(k-1)/2, 0.0, 0.0];
            rows=sf._vasp_cutoff_rows(grid, point, recip, 30.0)
            ng=length(rows);
            header=2+(k-1)*3
            seek(stream, record*header);
            write(stream, Float64[2ng, point..., -1, 0, 1, 1, 0, 0])
            for band in 1:2
                coeff=zeros(ComplexF64, 2ng)
                values=ComplexF64[
                    exp(-(0.25+0.13band)*sum(abs2, grid[j, :] .+ point))*cis(0.17band*grid[j, 1])
                    for j in rows
                ]
                values./=norm(values);
                coeff[((band - 1) * ng + 1):(band * ng)].=values
                seek(stream, record*(header+band));
                write(stream, coeff)
            end
        end
    end
    function configured(label; restart = nothing, tasks = false)
        doc=deepcopy(base)
        doc["solver"]=Dict(
            "initialization"=>(restart===nothing ? "random" : "restart"),
            "dis_num_iter"=>0,
            "num_iter"=>2,
            "conv_window"=>0,
        )
        doc["output"]=Dict(
            "checkpoint_hdf5"=>joinpath(directory, label*".wannierization.h5"),
            "native_matrix_directory"=>joinpath(directory, "matrices"),
            "num_print_cycles"=>0,
            "num_dump_cycles"=>1,
        )
        if tasks
            doc["output"]["operator_tasks"]=Dict("quantity"=>["orbital_magnetization"])
        else
            doc["output"]["profile"]="full"
        end
        restart===nothing || (doc["checkpoint"]=Dict("restart_hdf5"=>restart))
        path=joinpath(directory, label*".toml");
        open(f->TOML.print(f, doc), path, "w")
        return r.read_task_input(path)
    end
    input=configured("reference")
    @test length(w.native_operator_artifact_paths(input.config.input, :full, ()))==10
    @test input.config.input.win_file===nothing
    partial=joinpath(directory, "u1.wannierization.h5");
    seen=Tuple{Int, Int}[]
    function observe(snapshot, state, history, diagnostics)
        counts=(state.optimizer_state.z_steps, state.optimizer_state.u_steps);
        push!(seen, counts)
        if counts==(0, 1) && !isfile(partial)
            w.write_wannierization_checkpoint_hdf5(
                partial,
                w.read_wannierization_checkpoint_hdf5(input.config.checkpoint.checkpoint_hdf5),
            )
        end
    end
    cfg=input.config
    runtime=typeof(cfg.runtime)(;
        (
            name=>(name==:iteration_observer ? observe : getfield(cfg.runtime, name)) for
            name in fieldnames(typeof(cfg.runtime))
        )...,
    )
    observed=typeof(cfg)(;
        (
            name=>(name==:runtime ? runtime : getfield(cfg, name)) for
            name in fieldnames(typeof(cfg))
        )...,
    )
    reference=w.construct_wannier_functions(observed)
    println("VASP_NONZERO_STATUS=", reference.status, " callbacks=", seen)
    for d in reference.diagnostics
        ;
        println("VASP_NONZERO_DIAGNOSTIC=", d);
    end
    @test reference.status ∉
          (w.INVALID_INPUT, w.IO_FAILURE, w.LOCALIZATION_FAILED, w.SINGULAR_LOCALIZATION)
    @test !any(d->d.code==:TB_EXPORT_FAILED, reference.diagnostics)
    @test isfile(partial)
    @test reference.artifacts.packed_hdf5!==nothing
    if reference.artifacts.packed_hdf5!==nothing
        manifest=io.read_real_space_operator_bundle_manifest(reference.artifacts.packed_hdf5)
        @test manifest.inventory==collect(io.OPERATOR_PROFILE_INVENTORIES[:full])
    end
    if reference.restart_state!==nothing && isfile(partial)
        @test reference.restart_state.optimizer_state.u_steps==2
        accepted=w.read_wannierization_checkpoint_hdf5(partial)
        @test haskey(accepted.input_summary, "native_matrix_acceptance_json")
        @test haskey(accepted.input_summary, "native_operator_artifacts_json")
        digest=bytes2hex(sha256(read(partial)))
        frozen=Dict(
            path=>bytes2hex(sha256(read(path))) for
            (root, dirs, files) in walkdir(joinpath(directory, "matrices")) for
            path in joinpath.(root, files)
        )
        resumed=r.run_task_input(
            configured("resumed"; restart = partial);
            record_directory = joinpath(directory, "resumed-records"),
        )
        @test resumed.status==reference.status
        @test isequal(resumed.v_matrix, reference.v_matrix)
        @test resumed.restart_state.optimizer_state.u_steps==2
        @test isequal(resumed.spreads_angstrom2, reference.spreads_angstrom2)
        @test bytes2hex(sha256(read(partial)))==digest
        @test all(isfile(path)&&bytes2hex(sha256(read(path)))==sha for (path, sha) in frozen)
    end
    # Task union reuses same-source publications; it does not run a response.
    taskinput=configured("task"; tasks = true)
    @test taskinput.config.output.profile===nothing
    @test !haskey(
        w.native_operator_artifact_paths(
            taskinput.config.input,
            nothing,
            taskinput.config.output.operator_tasks,
        ),
        :spn_file,
    )
    taskresult=r.run_task_input(taskinput; record_directory = joinpath(directory, "task-records"))
    println("VASP_TASK_STATUS=", taskresult.status)
    for d in taskresult.diagnostics
        ;
        println("VASP_TASK_DIAGNOSTIC=", d);
    end
    @test !any(d->d.severity==:error, taskresult.diagnostics)
    @test taskresult.artifacts.packed_hdf5!==nothing
end
