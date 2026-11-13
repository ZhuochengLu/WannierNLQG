using Test, LinearAlgebra

@testset "Explicit TOML geometry preserves matrix row authority" begin
    runtime = WannierNLQG.Runtime
    structure = Dict(
        "lattice_angstrom"=>[[1.0, 0.0, 0.0], [0.0, 1.0, 0.0], [0.0, 0.0, 1.0]],
        "species"=>["X"],
        "positions_fractional"=>[[0.0, 0.0, 0.0]],
    )
    mesh = Dict("dimensions"=>[2, 1, 1], "points_fractional"=>[[0.5, 0.0, 0.0], [0.0, 0.0, 0.0]])
    geometry = runtime._workflow_explicit_wannier_geometry(structure, mesh)
    @test geometry.kpoints_fractional == [0.5 0.0 0.0; 0.0 0.0 0.0]
    @test geometry.mp_grid == (2, 1, 1)
    mesh["points_fractional"][1][1] = 0.25
    @test geometry.kpoints_fractional[1, 1] == 0.5
    @test_throws ArgumentError runtime._workflow_explicit_wannier_geometry(structure, mesh)
    @test_throws ArgumentError runtime._workflow_explicit_wannier_geometry(
        structure,
        Dict("dimensions"=>[2, 1, 1]),
    )
    @test_throws ArgumentError runtime._workflow_explicit_wannier_geometry(
        structure,
        Dict("dimensions"=>[2, 1, 1], "points_fractional"=>[[0.0, 0.0, 0.0], [0.0, 0.0, 0.0]]),
    )
    @test_throws ArgumentError runtime._workflow_explicit_wannier_geometry(
        structure,
        Dict(
            "dimensions"=>[2, 1, 1],
            "points_fractional"=>[[0.5, 0.0, 0.0], [0.0, 0.0, 0.0]],
            "win_file"=>"unused.win",
        ),
    )
    mesh["points_fractional"][1][1] = 0.5
    matrices = Dict("eig_file"=>"test.eig", "mmn_file"=>"test.mmn", "amn_file"=>"test.amn")
    basis = Dict("projections"=>["X:s"], "spinor"=>false)
    mktempdir() do directory
        input = runtime._workflow_external_wannier_input(
            structure,
            mesh,
            basis,
            matrices,
            Dict();
            base_dir = directory,
        )
        @test input.win_file === nothing
        @test input.source === nothing
        @test input.num_wannier == 1
        @test input.eig_file == joinpath(directory, "test.eig")
        @test input.mmn_file == joinpath(directory, "test.mmn")
        @test input.amn_file == joinpath(directory, "test.amn")
        @test isempty(readdir(directory))
        @test_throws ArgumentError runtime._workflow_external_wannier_input(
            structure,
            mesh,
            basis,
            Dict("eig_file"=>"test.eig"),
            Dict();
            base_dir = directory,
        )
        @test_throws ArgumentError runtime._workflow_external_wannier_input(
            structure,
            mesh,
            merge(basis, Dict("spinor"=>1)),
            matrices,
            Dict();
            base_dir = directory,
        )
        @test_throws ArgumentError runtime._workflow_external_wannier_input(
            structure,
            mesh,
            basis,
            matrices,
            Dict("unknown"=>0);
            base_dir = directory,
        )
    end
end
