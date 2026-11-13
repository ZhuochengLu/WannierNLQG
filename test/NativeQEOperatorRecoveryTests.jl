using Test, LinearAlgebra, HDF5, TOML, SHA
include("QEPAWMatrixElementsTestSupport.jl")
using .QEPAWMatrixElementsTestSupport
@testset "QE spinor full/task generated once and immutable recovery" begin
    w=WannierNLQG.Wannierization;
    r=WannierNLQG.Runtime
    let directory=mktempdir(spec["output"]; prefix = "qe-spinor-operators-", cleanup = false)
        fixture=write_qe_paw_fixture(directory; spinor = true)
        xml=joinpath(fixture.save_directory, "data-file-schema.xml")
        write(
            xml,
            replace(
                read(xml, String),
                "<nbnd>1</nbnd>"=>"<nbnd>2</nbnd>",
                "<eigenvalues>-0.25</eigenvalues>"=>"<eigenvalues>-0.25 -0.15</eigenvalues>",
            ),
        )
        g=hcat([Int[x, y, z] for x in -2:2 for y in -2:2 for z in -2:2]...)
        c=exp.(-0.5 .* vec(sum(abs2, g; dims = 1)));
        c ./= norm(c)
        HDF5.h5open(joinpath(fixture.save_directory, "wfc1.hdf5"), "w") do h
            attrs=HDF5.attributes(h);
            attrs["igwx"]=length(c);
            attrs["nbnd"]=2;
            attrs["npol"]=2
            attrs["xk"]=[0.0, 0.0, 0.0];
            attrs["scale_factor"]=1.0
            h["MillerIndices"]=g;
            ma=HDF5.attributes(h["MillerIndices"])
            for i in 1:3
                ;
                ma["bg$i"]=Matrix{Float64}(I, 3, 3)[i, :];
            end
            coefficients=zeros(ComplexF64, 2length(c), 2)
            coefficients[1:length(c), 1].=c;
            coefficients[(length(c) + 1):end, 2].=c
            @test coefficients' * coefficients ≈ Matrix{Float64}(I, 2, 2)
            packed=zeros(4length(c), 2);
            packed[1:2:end, :].=real.(coefficients);
            h["evc"]=packed
        end
        rm(fixture.nnkp_file)
        doc=Dict{String, Any}(
            "workflow"=>"wannierization",
            "mode"=>"ordinary",
            "source"=>Dict(
                "kind"=>"qe",
                "save_directory"=>fixture.save_directory,
                "include_time_reversal"=>false,
            ),
            "kmesh"=>Dict("dimensions"=>[1, 1, 1]),
            "basis"=>Dict("projections"=>["X:s"], "spinor"=>true),
            "solver"=>Dict("initialization"=>"amn", "dis_num_iter"=>0, "num_iter"=>0),
            "output"=>Dict{String, Any}("num_print_cycles"=>0, "num_dump_cycles"=>0),
        )
        # Same native source, demanded operator generation and accepted artifact reuse.
        for selection in (:full, :task)
            nextdoc=deepcopy(doc)
            nextdoc["output"]["checkpoint_hdf5"]=string(selection)*".wannierization.h5"
            nextdoc["output"]["native_matrix_directory"]=joinpath(
                directory,
                string(selection)*"-matrices",
            )
            if selection == :full
                nextdoc["output"]["profile"]="full"
            else
                nextdoc["output"]["operator_tasks"]=Dict("quantity"=>["orbital_magnetization"])
            end
            nextinput=r.resolve_workflow_input(nextdoc; base_dir = directory)
            generated=r.run_task_input(
                nextinput;
                record_directory = joinpath(directory, string(selection)*"-records"),
            )
            for diagnostic in generated.diagnostics
                ;
                println("QE_OPERATOR_DIAGNOSTIC ", selection, " ", diagnostic);
            end
            @test generated.status ∉ (w.INVALID_INPUT, w.IO_FAILURE, w.LOCALIZATION_FAILED)
            @test !any(d->d.code==:TB_EXPORT_FAILED, generated.diagnostics)
            paths=w.validate_native_operator_artifact_paths(nextinput.config)
            @test length(paths)==(selection==:full ? 10 : 4)
            @test all(isfile, values(paths))
            all(isfile, values(paths)) ||
                error("QE operator publication missing; inspect persisted diagnostics")
            identities=Dict(path=>bytes2hex(SHA.sha256(read(path))) for path in values(paths))
            nextdoc["solver"]["initialization"]="restart"
            nextdoc["checkpoint"]=Dict("restart_hdf5"=>nextinput.config.checkpoint.checkpoint_hdf5)
            nextdoc["output"]["checkpoint_hdf5"]=string(selection)*"-resumed.wannierization.h5"
            recovered=r.run_task_input(
                r.resolve_workflow_input(nextdoc; base_dir = directory);
                record_directory = joinpath(directory, string(selection)*"-resumed-records"),
            )
            @test recovered.status ∉ (w.INVALID_INPUT, w.IO_FAILURE, w.LOCALIZATION_FAILED)
            @test !any(d->d.code==:TB_EXPORT_FAILED, recovered.diagnostics)
            @test recovered.v_matrix==generated.v_matrix
            @test all(path->bytes2hex(SHA.sha256(read(path)))==identities[path], keys(identities))
        end
    end
end
