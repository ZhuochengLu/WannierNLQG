using Test, WannierNLQG

@testset "OUTCAR metadata and real mesh entry" begin
    R=WannierNLQG.Runtime
    readmeta=WannierNLQG.IO.read_vasp_geometry_metadata
    mktempdir() do dir
        poscar=joinpath(dir, "POSCAR")
        write(poscar, "Si\n1\n1 0 0\n0 1 0\n0 0 1\nSi\n1\nDirect\n0 0 0\n")
        outcar=joinpath(dir, "OUTCAR")
        text=""" NKPTS = 2 k-points in BZ
 ISPIN = 1
 LNONCOLLINEAR = F
 LSORBIT = F
 k-points in reciprocal lattice and weights:

 0.5D0 0 0 0.5
 0 0 0 0.5
"""
        write(outcar, text)
        data=readmeta(outcar)
        @test data.loaded_files == [realpath(outcar)]
        if Sys.isunix()
            alias_outcar = joinpath(dir, "outcar-alias")
            symlink(outcar, alias_outcar)
            @test readmeta(alias_outcar).loaded_files == [realpath(outcar)]
        end
        @test data.kpoints_fractional == [0.5 0.0; 0.0 0.0; 0.0 0.0]
        @test data.original_kpoint_indices == [1, 2]
        @test data.kpoint_weights == [0.5, 0.5]
        @test !data.wavefunctions_loaded && !data.physical_metric_loaded
        @test !data.magnetic_moments_available
        @test data.spin_channels == 1 && data.noncollinear_spin === false
        doc=Dict{String, Any}(
            "workflow"=>"mesh_screening",
            "source"=>Dict("kind"=>"vasp", "poscar_file"=>"POSCAR", "outcar_file"=>"OUTCAR"),
            "kmesh"=>Dict("dimensions"=>[2, 1, 1]),
            "mesh_screening"=>Dict("density_target"=>1.0, "search_radius"=>1),
            "output"=>Dict("report_json_file"=>"mesh.json"),
        )
        input=R.resolve_task_input(doc; base_dir = dir)
        @test input.effective["source"]["outcar_file"] == outcar
        replay=R.resolve_task_input(input.effective; base_dir = "/")
        @test replay.config.vasp_metadata.kpoints_fractional == data.kpoints_fractional
        report=R.run_task_input(input; record_directory = joinpath(dir, "records"))
        @test report["actual_point_inventory"]["slots_in_original_order"] == [2, 1]
        @test report["grid_provenance"] == "ACTUAL_COMPLETE_POINT_SET"
        @test report["loaded_geometry_files"] == [poscar, realpath(outcar)]
        @test !report["wavefunctions_loaded"] && !report["physical_metric_loaded"]
        for bad in (
            replace(text, "NKPTS = 2"=>"NKPTS = 3"),
            replace(text, "0.5D0"=>"NaN"),
            replace(text, "reciprocal lattice"=>"cartesian coordinates"),
            text*"\nISPIN = 2\n",
            replace(text, "0 0 0 0.5"=>"0 0 0 -1"),
        )
            write(outcar, bad)
            @test_throws ArgumentError readmeta(outcar)
        end
        write(outcar, replace(text, "ISPIN = 1"=>"ISPIN = 2"))
        @test_throws ArgumentError R.resolve_task_input(doc; base_dir = dir)
        rm(input.config.report_json_file)
        @test_throws ArgumentError R.run_task_input(
            input;
            record_directory = joinpath(dir, "stale"),
        )
        write(outcar, replace(text, " LSORBIT = F\n"=>""))
        @test_throws ArgumentError R.resolve_task_input(doc; base_dir = dir)
        write(outcar, text)
        missing=deepcopy(doc);
        delete!(missing, "kmesh")
        @test_throws ArgumentError R.resolve_task_input(missing; base_dir = dir)
        bad=deepcopy(doc);
        bad["source"]["save_directory"]="bad"
        @test_throws ArgumentError R.resolve_task_input(bad; base_dir = dir)
    end
end
