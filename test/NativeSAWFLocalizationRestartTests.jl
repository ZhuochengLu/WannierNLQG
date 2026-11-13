using Test, LinearAlgebra, HDF5, TOML, SHA
include("QEPAWMatrixElementsTestSupport.jl")
using .QEPAWMatrixElementsTestSupport

@testset "Native SAWF accepted U and immutable restart" begin
    w = WannierNLQG.Wannierization
    r = WannierNLQG.Runtime
    let directory = mktempdir(out; prefix = "sawf-stages-", cleanup = false)
        fixture = write_qe_paw_fixture(directory)
        xml = joinpath(fixture.save_directory, "data-file-schema.xml")
        write(
            xml,
            replace(
                read(xml, String),
                "<nbnd>1</nbnd>"=>"<nbnd>3</nbnd>",
                "<eigenvalues>-0.25</eigenvalues>"=>"<eigenvalues>-0.25 -0.15 -0.05</eigenvalues>",
            ),
        )
        write(
            xml,
            replace(
                read(xml, String),
                "<species name=\"X\"><pseudo_file>X.UPF</pseudo_file></species>" => "<species name=\"X\"><pseudo_file>X.UPF</pseudo_file></species><species name=\"Y\"><pseudo_file>Y.UPF</pseudo_file></species>",
                "<atom name=\"X\">0.0 0.0 0.0</atom>" => "<atom name=\"X\">0.0 0.0 0.0</atom><atom name=\"Y\">1.0 1.0 1.0</atom>",
            ),
        )
        write(
            joinpath(fixture.save_directory, "Y.UPF"),
            replace(
                read(joinpath(fixture.save_directory, "X.UPF"), String),
                "element=\"X\""=>"element=\"Y\"",
            ),
        )
        # Three real cubic-invariant packets, with two distinct atomic centers. This is a
        # deterministic NC engineering fixture, not a material or DFT oracle.
        g = hcat([Int[x, y, z] for x in -2:2 for y in -2:2 for z in -2:2]...)
        radius2 = vec(sum(abs2, g; dims = 1))
        first = exp.(-0.5 .* radius2);
        first ./= norm(first)
        second = radius2 .* first
        second .-= dot(first, second) .* first;
        second ./= norm(second)
        third = [isodd(sum(g[:, i])) ? -first[i] : first[i] for i in axes(g, 2)]
        third .-= dot(first, third) .* first .+ dot(second, third) .* second
        third ./= norm(third)
        coefficients = hcat(first, second, third)
        @test isapprox(
            coefficients' * coefficients,
            Matrix{Float64}(I, 3, 3);
            atol = 1e-14,
            rtol = 0,
        )
        HDF5.h5open(joinpath(fixture.save_directory, "wfc1.hdf5"), "w") do h
            a=HDF5.attributes(h);
            a["igwx"]=size(g, 2);
            a["nbnd"]=3;
            a["npol"]=1
            a["xk"]=[0.0, 0.0, 0.0];
            a["scale_factor"]=1.0
            h["MillerIndices"]=g;
            ma=HDF5.attributes(h["MillerIndices"])
            for i in 1:3
                ;
                ma["bg$i"]=Matrix{Float64}(I, 3, 3)[i, :];
            end
            packed=zeros(2size(g, 2), 3);
            packed[1:2:end, :].=coefficients;
            h["evc"]=packed
        end
        rm(fixture.nnkp_file)
        base=Dict{String, Any}(
            "workflow"=>"wannierization",
            "mode"=>"symmetry_adapted",
            "source"=>Dict("kind"=>"qe", "save_directory"=>fixture.save_directory),
            "symmetry"=>Dict("include_time_reversal"=>true, "symmetry_tolerance"=>1e-5),
            "kmesh"=>Dict("dimensions"=>[1, 1, 1]),
            "basis"=>Dict("projections"=>["X:s", "Y:s"]),
            "windows"=>Dict("outer_min_ev"=>-10.0, "outer_max_ev"=>0.0),
        )
        function configured(label; restart = nothing)
            doc=deepcopy(base)
            doc["solver"]=Dict(
                "initialization"=>(restart===nothing ? "amn" : "restart"),
                "dis_num_iter"=>2,
                "dis_conv_tol"=>0.0,
                "dis_conv_window"=>3,
                "num_iter"=>2,
                "conv_window"=>0,
            )
            doc["output"]=Dict(
                "checkpoint_hdf5"=>joinpath(directory, label*".wannierization.h5"),
                "native_matrix_directory"=>joinpath(directory, "native-matrices"),
                "num_print_cycles"=>0,
                "num_dump_cycles"=>1,
            )
            restart===nothing || (doc["checkpoint"]=Dict("restart_hdf5"=>restart))
            path=joinpath(directory, label*".toml");
            open(io->TOML.print(io, doc), path, "w")
            return r.read_task_input(path)
        end
        input=configured("reference")
        partial=joinpath(directory, "accepted-u1.wannierization.h5")
        seen=Tuple{Int, Int}[]
        function observe(snapshot, state, history, diagnostics)
            counts=(state.optimizer_state.z_steps, state.optimizer_state.u_steps)
            push!(seen, counts)
            if counts==(2, 1) && !isfile(partial)
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
        println("SAWF_U_REFERENCE=", reference.status, " callbacks=", seen)
        for d in reference.diagnostics
            ;
            println("SAWF_STAGE_DIAGNOSTIC=", d);
        end
        @test reference.status ∉
              (w.INVALID_INPUT, w.IO_FAILURE, w.LOCALIZATION_FAILED, w.REPRESENTATION_INCOMPATIBLE)
        @test reference.restart_state !== nothing
        @test isfile(partial)
        if reference.restart_state !== nothing && isfile(partial)
            @test reference.restart_state.optimizer_state.z_steps==2
            @test reference.restart_state.optimizer_state.u_steps==2
            @test (2, 1) in seen && (2, 2) in seen
            saved=w.read_wannierization_checkpoint_hdf5(partial)
            @test saved.restart_state.optimizer_state.z_steps==2
            @test saved.restart_state.optimizer_state.u_steps==1
            digest=bytes2hex(sha256(read(partial)))
            resumed=r.run_task_input(
                configured("resumed"; restart = partial);
                record_directory = joinpath(directory, "resumed-records"),
            )
            println("SAWF_U_RESUMED=", resumed.status)
            for d in resumed.diagnostics
                ;
                println("SAWF_RESTART_DIAGNOSTIC=", d);
            end
            @test resumed.status==reference.status
            @test resumed.restart_state !== nothing
            @test isequal(resumed.v_matrix, reference.v_matrix)
            @test isequal(resumed.wannier_centers_cartesian, reference.wannier_centers_cartesian)
            @test isequal(resumed.spreads_angstrom2, reference.spreads_angstrom2)
            if resumed.restart_state !== nothing
                @test resumed.restart_state.optimizer_state.z_steps==2
                @test resumed.restart_state.optimizer_state.u_steps==2
                @test resumed.restart_state.optimizer_state.disentanglement_objective_history ==
                      reference.restart_state.optimizer_state.disentanglement_objective_history
                @test resumed.restart_state.optimizer_state.localization_objective_history ==
                      reference.restart_state.optimizer_state.localization_objective_history
                @test length(resumed.history)==length(reference.history)
            end
            @test bytes2hex(sha256(read(partial)))==digest
            @test !any(d->d.severity==:error, resumed.diagnostics)
            @test resumed.artifacts.packed_hdf5 !== nothing
        end
    end
end
