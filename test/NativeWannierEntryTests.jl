using Test, LinearAlgebra, HDF5, TOML
include("QEPAWMatrixElementsTestSupport.jl")
using .QEPAWMatrixElementsTestSupport

@testset "Native QE normalized TOML to solve/save without external matrix files" begin
    w=WannierNLQG.Wannierization;
    r=WannierNLQG.Runtime
    let directory=mktempdir(spec["output"]; prefix = "native-entry-", cleanup = false)
        fixture=write_qe_paw_fixture(directory)
        # A finite normalized plane-wave packet gives nonzero shifted overlaps.
        # Engineering fixture only, not a QE material or an independent physics oracle.
        g=hcat([Int[x, y, z] for x in -2:2 for y in -2:2 for z in -2:2]...)
        c=exp.(-0.5 .* vec(sum(abs2, g; dims = 1)));
        c ./= norm(c)
        file=joinpath(fixture.save_directory, "wfc1.hdf5")
        HDF5.h5open(file, "w") do h
            a=HDF5.attributes(h);
            a["igwx"]=length(c);
            a["nbnd"]=1;
            a["npol"]=1
            a["xk"]=[0.0, 0.0, 0.0];
            a["scale_factor"]=1.0
            h["MillerIndices"]=g;
            ma=HDF5.attributes(h["MillerIndices"])
            for i in 1:3
                ;
                ma["bg$i"]=Matrix{Float64}(I, 3, 3)[i, :];
            end
            packed=zeros(2length(c), 1);
            packed[1:2:end, 1].=c;
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
            "kmesh"=>Dict{String, Any}("dimensions"=>[1, 1, 1]),
            "basis"=>Dict{String, Any}("projections"=>["X:s"]),
            "solver"=>Dict("initialization"=>"amn", "dis_num_iter"=>0, "num_iter"=>0),
            "output"=>Dict(
                "checkpoint_hdf5"=>"native.wannierization.h5",
                "num_print_cycles"=>0,
                "num_dump_cycles"=>0,
            ),
        )
        path=joinpath(directory, "native.toml");
        open(io->TOML.print(io, doc), path, "w")
        input=r.read_task_input(path)
        @test input.config.input.win_file === nothing
        @test input.config.input.matrix_elements.nnkp_file === nothing
        @test !isfile(input.config.input.eig_file)
        @test input.config.input.geometry.kpoints_fractional == zeros(1, 3)
        @test input.config.input.geometry.structure.species == ["X"]
        @test input.config.input.matrix_elements.topology.neighbors == ones(Int, 6, 1)
        result=r.run_task_input(input; record_directory = joinpath(directory, "records"))
        println("NATIVE_ENTRY_STATUS=", result.status)
        for diagnostic in result.diagnostics
            ;
            println("NATIVE_ENTRY_DIAGNOSTIC=", diagnostic);
        end
        @test result.status ∉ (w.INVALID_INPUT, w.IO_FAILURE, w.LOCALIZATION_FAILED)
        @test !isempty(result.v_matrix)
        @test isfile(input.config.checkpoint.checkpoint_hdf5)
        @test isfile(input.config.input.eig_file)
        @test !isfile(fixture.nnkp_file)
        @test isempty(filter(f->endswith(f, ".win"), readdir(directory)))
        effective=joinpath(directory, "records", "effective_config.toml")
        replay=r.read_task_input(effective)
        @test replay.config.input.matrix_elements.topology.source_sha256 ==
              input.config.input.matrix_elements.topology.source_sha256
        @test replay.config.input.eig_file == input.config.input.eig_file
        @test !haskey(TOML.parsefile(effective), "matrices")
        # External/native mixing and coordinate drift are errors, not fallback.
        @test_throws ArgumentError r.resolve_workflow_input(
            merge(deepcopy(doc), Dict("matrices"=>Dict("eig_file"=>"fake")));
            base_dir = directory,
        )
        wrong=deepcopy(doc);
        wrong["kmesh"]["points_fractional"]=[[0.25, 0.0, 0.0]]
        @test_throws ArgumentError r.resolve_workflow_input(wrong; base_dir = directory)
        spin=deepcopy(doc);
        spin["basis"]["spinor"]=true
        @test_throws ArgumentError r.resolve_workflow_input(spin; base_dir = directory)
        # The old provider remains explicitly file-based and oracle-required.
        old=w.NativeQEPAWMatrices("old.nnkp"; artifact_dir = joinpath(directory, "old"))
        @test old.topology === nothing && old.nnkp_file == "old.nnkp" && old.require_oracle
        @test !any(d->d.code == :TB_EXPORT_FAILED, result.diagnostics)
    end
end
