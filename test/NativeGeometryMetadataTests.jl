using Test, WannierNLQG

@testset "Lightweight QE geometry and saved mesh metadata" begin
    SF = WannierNLQG.SymmetryFoundation
    R = WannierNLQG.Runtime
    mesh = SF.DiagonalKMesh((2, 1, 1))
    ordered = [0.5 0.0; 0.0 0.0; 0.0 0.0]
    inventory = SF.classify_diagonal_mesh_points(mesh, ordered)
    @test inventory.complete
    @test inventory.slots_in_original_order == [2, 1]
    @test !SF.classify_diagonal_mesh_points(mesh, ordered[:, 1:1]).complete
    @test_throws ArgumentError SF.classify_diagonal_mesh_points(
        mesh,
        hcat(ordered[:, 1], ordered[:, 1]),
    )
    @test_throws ArgumentError SF.classify_diagonal_mesh_points(
        mesh,
        reshape([0.25, 0.0, 0.0], 3, 1),
    )
    mktempdir() do directory
        save = joinpath(directory, "fixture.save");
        mkdir(save)
        xml = joinpath(save, "data-file-schema.xml")
        contents = """
<espresso><input>
<atomic_species><species name="Si1"><pseudo_file>MISSING.UPF</pseudo_file></species></atomic_species>
<atomic_structure alat="3.0"><cell><a1>3 0 0</a1><a2>0 3 0</a2><a3>0 0 3</a3></cell><atomic_positions><atom name="Si1">0 0 0</atom></atomic_positions></atomic_structure>
<k_points_IBZ><monkhorst_pack nk1="2" nk2="1" nk3="1" k1="0" k2="0" k3="0"/></k_points_IBZ>
</input><output><band_structure><lsda>false</lsda><noncolin>false</noncolin><spinorbit>false</spinorbit>
<ks_energies><k_point>0.5 0 0</k_point></ks_energies><ks_energies><k_point>0 0 0</k_point></ks_energies>
</band_structure></output></espresso>
"""
        write(xml, contents)
        data = WannierNLQG.IO.read_qe_geometry_metadata(xml)
        @test data.atomic_labels == ["Si1"]
        @test data.kpoints_fractional == ordered
        @test data.original_kpoint_indices == [1, 2]
        @test data.mesh_dimensions == (2, 1, 1)
        @test data.lattice_angstrom[1, 1] == 3 * 0.529177210903
        @test data.loaded_files == [realpath(xml)]
        if Sys.isunix()
            alias_xml = joinpath(directory, "geometry-alias.xml")
            symlink(xml, alias_xml)
            @test WannierNLQG.IO.read_qe_geometry_metadata(alias_xml).loaded_files ==
                  [realpath(xml)]
        end
        @test !data.wavefunctions_loaded &&
              !data.physical_metric_loaded &&
              !data.chemical_elements_resolved
        @test readdir(save) == ["data-file-schema.xml"]
        document = Dict{String, Any}(
            "workflow"=>"mesh_screening",
            "source"=>Dict("kind"=>"qe", "save_directory"=>"fixture.save"),
            "mesh_screening"=>Dict("density_target"=>1.0, "search_radius"=>1),
            "output"=>Dict("report_json_file"=>"qe.json"),
        )
        input = R.resolve_task_input(document; base_dir = directory)
        @test input.config.mesh.dimensions == (2, 1, 1)
        @test R.resolve_task_input(input.effective; base_dir = "/").config.mesh.dimensions ==
              (2, 1, 1)
        result = R.run_task_input(input; record_directory = joinpath(directory, "records"))
        @test result["grid_provenance"] == "ACTUAL_COMPLETE_POINT_SET"
        @test result["actual_point_inventory"]["slots_in_original_order"] == [2, 1]
        @test result["loaded_geometry_files"] == [realpath(xml)]
        @test !result["wavefunctions_loaded"] && !result["physical_metric_loaded"]
        bad = deepcopy(document);
        bad["kmesh"] = Dict("dimensions"=>[3, 1, 1])
        @test_throws ArgumentError R.resolve_task_input(bad; base_dir = directory)
        bad["kmesh"] = Dict("dimensions"=>[2, 1, 1], "offset_grid_steps"=>[0.5, 0.0, 0.0])
        @test_throws ArgumentError R.resolve_task_input(bad; base_dir = directory)
        template = joinpath(directory, "template.toml")
        @test R.task_input_cli(["init", template, "--workflow", "mesh_screening"]) == 0
        @test occursin("save_directory", read(template, String))
        @test_throws ArgumentError R.task_input_cli([
            "init",
            template,
            "--workflow",
            "mesh_screening",
        ])
        @test_throws ArgumentError R.write_task_input_template(
            joinpath(directory, "invalid.toml");
            workflow = "mesh_screening",
            mode = "ordinary",
        )
        write(xml, replace(contents, "<lsda>false</lsda>"=>"<lsda>true</lsda>"))
        @test_throws ArgumentError R.resolve_task_input(document; base_dir = directory)
        @test_throws ArgumentError R.run_task_input(
            input;
            record_directory = joinpath(directory, "stale"),
        )
        write(xml, replace(contents, r"<k_points_IBZ>.*?</k_points_IBZ>"s=>""))
        @test_throws ArgumentError R.resolve_task_input(document; base_dir = directory)
        write(xml, replace(contents, "<ks_energies><k_point>0 0 0</k_point></ks_energies>"=>""))
        partial = deepcopy(document);
        partial["output"]["report_json_file"]="partial.json"
        result = R.run_task_input(
            R.resolve_task_input(partial; base_dir = directory);
            record_directory = joinpath(directory, "partial"),
        )
        @test result["grid_provenance"] == "CONSTRUCTED_FROM_EXPLICIT_DIAGONAL_SPECIFICATION"
        @test !result["actual_point_inventory"]["complete"]
    end
end
