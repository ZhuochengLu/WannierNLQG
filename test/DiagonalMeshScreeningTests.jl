using Test, LinearAlgebra, WannierNLQG

@testset "Offset-aware diagonal mesh screening" begin
    SF = WannierNLQG.SymmetryFoundation
    R = WannierNLQG.Runtime
    identity = Matrix{Int}(I, 3, 3)
    swap = [0 1 0; 1 0 0; 0 0 1]
    operations = [
        SF.SymmetryOperation(identity, zeros(3), identity),
        SF.SymmetryOperation(identity, zeros(3), identity, true),
        SF.SymmetryOperation(swap, zeros(3), swap),
    ]
    for sizes in ((1, 1, 1), (2, 2, 2), (3, 3, 2), (2, 3, 1)),
        steps in ((0.0, 0.0, 0.0), (0.5, 0.5, 0.0), (0.25, 0.0, 0.0)),
        operation in operations

        offset = ntuple(axis -> steps[axis] / sizes[axis], 3)
        mesh = SF.DiagonalKMesh(sizes, offset)
        algebra = SF.diagonal_mesh_closure(mesh, operation)
        enumeration = SF.enumerate_diagonal_mesh_closure(mesh, operation)
        @test algebra.closed == enumeration.closed
    end
    shifted = SF.DiagonalKMesh((3, 3, 3), (1 / 12, 0.0, 0.0))
    @test SF.diagonal_mesh_closure(shifted, operations[2]).integer_action
    @test !SF.diagonal_mesh_closure(shifted, operations[2]).closed
    @test !SF.diagonal_mesh_closure(SF.DiagonalKMesh((2, 3, 1)), operations[3]).closed
    structure = SF.CrystalStructure(2.0 * Matrix(I, 3, 3), ["Si"], zeros(3, 1))
    result = SF.recommend_diagonal_mesh(
        structure,
        SF.DiagonalKMesh((2, 2, 1)),
        operations;
        density_target = 5.0,
        dimension = 2,
        search_radius = 2,
    )
    @test result.recommended.dimensions == (3, 3, 1)
    @test all(result.density_products[axis] >= 5.0 for axis in 1:2)
    @test result.recommended.offset_fractional[3] == 0.0
    mixed = SF.SymmetryOperation([0 0 1; 0 1 0; 1 0 0], zeros(3), [0 0 1; 0 1 0; 1 0 0])
    @test_throws ArgumentError SF.recommend_diagonal_mesh(
        structure,
        SF.DiagonalKMesh((2, 2, 1)),
        [mixed];
        density_target = 5.0,
        dimension = 2,
        search_radius = 0,
    )
    @test_throws ArgumentError SF.DiagonalKMesh((0, 2, 3))
    @test_throws ArgumentError SF.DiagonalKMesh((true, 2, 3))
    @test_throws ArgumentError SF.DiagonalKMesh((2, 2, 2), (NaN, 0.0, 0.0))

    mktempdir() do directory
        document = Dict{String, Any}(
            "workflow"=>"mesh_screening",
            "structure"=>Dict(
                "lattice_angstrom"=>[[2.0, 0.0, 0.0], [0.0, 2.0, 0.0], [0.0, 0.0, 2.0]],
                "species"=>["Si"],
                "positions_fractional"=>[[0.0, 0.0, 0.0]],
            ),
            "kmesh"=>Dict("dimensions"=>[2, 2, 2], "offset_grid_steps"=>[0.0, 0.0, 0.0]),
            "mesh_screening"=>Dict("density_target"=>5.0, "search_radius"=>1),
            "output"=>Dict("report_json_file"=>"mesh.json"),
        )
        input = R.resolve_task_input(document; base_dir = directory)
        @test input.config.report_json_file == joinpath(directory, "mesh.json")
        @test !input.metadata["data_requirements"]["wavefunction_coefficients"]
        replay = R.resolve_task_input(input.effective; base_dir = "/")
        @test replay.config.report_json_file == input.config.report_json_file
        @test replay.config.mesh.dimensions == input.config.mesh.dimensions
        bad = deepcopy(document);
        bad["schema_version"] = "1"
        @test_throws ArgumentError R.resolve_task_input(bad; base_dir = directory)
        bad = deepcopy(document);
        bad["kmesh"]["offset_fractional"] = [0.0, 0.0, 0.0]
        @test_throws ArgumentError R.resolve_task_input(bad; base_dir = directory)
        bad = deepcopy(document);
        bad["mesh_screening"]["density_target"] = -1
        @test_throws ArgumentError R.resolve_task_input(bad; base_dir = directory)
        report = R.run_task_input(input; record_directory = joinpath(directory, "records"))
        @test report["recommended_dimensions"] == [3, 3, 3]
        @test report["original_closed"]
        @test isfile(joinpath(directory, "mesh.json"))
        @test isfile(joinpath(directory, "records", "effective_config.toml"))
        @test_throws ArgumentError R.run_task_input(
            input;
            record_directory = joinpath(directory, "records2"),
        )
        poscar = joinpath(directory, "POSCAR")
        write(poscar, "Si\n1.0\n2 0 0\n0 2 0\n0 0 2\nSi\n1\nDirect\n0 0 0\n")
        native = deepcopy(document)
        delete!(native, "structure")
        native["source"] = Dict("kind"=>"vasp", "poscar_file"=>"POSCAR")
        native["output"]["report_json_file"] = "vasp-mesh.json"
        input_file = joinpath(directory, "screen.toml")
        WannierNLQG.IO.write_task_input_file(input_file, native)
        @test R.task_input_cli(["check", input_file]) == 0
        @test R.task_input_cli([
            "run",
            input_file,
            "--records",
            joinpath(directory, "native-records"),
        ]) == 0
        @test !isfile(joinpath(directory, "WAVECAR"))
        @test isfile(joinpath(directory, "vasp-mesh.json"))
    end
end
