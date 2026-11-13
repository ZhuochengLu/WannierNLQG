@testset "WIN mp_grid delimiter and rejection contracts" begin
    extension, _ = WANNIERIZATION._load_wannierization_extension!()
    reader = extension.SolverCheckpoint._read_wannierization_win_mesh
    mktempdir() do directory
        path = joinpath(directory, "mesh.win")
        geometry = """
        begin unit_cell_cart
        1 0 0
        0 1 0
        0 0 1
        end unit_cell_cart
        begin kpoints
        0 0 0
        0.5 0 0
        end kpoints
        """
        write(path, "mp_grid = 2 1 1\n" * geometry)
        reference = Base.invokelatest(reader, path)
        for line in (
            "mp_grid = 2 1 1",
            "mp_grid : 2 1 1",
            "mp_grid 2 1 1",
            "MP_GRID:2 1 1",
            "  Mp_GrId\t=\t2, 1, 1 ! trailing comment",
            "mp_grid\t2\t1\t1 # trailing comment",
            "mp_grid : 2 1 1 # ignored ! = :",
        )
            write(path, line * "\n" * geometry)
            @test isequal(Base.invokelatest(reader, path), reference)
        end
        for line in (
            "mp_grid",
            "mp_grid:",
            "mp_grid = 2 1",
            "mp_grid : 2 1 1 1",
            "mp_grid = 2.0 1 1",
            "mp_grid : two 1 1",
            "mp_grid = 0 1 1",
            "mp_grid : -2 1 1",
            "mp_grid == 2 1 1",
            "mp_grid :: 2 1 1",
            "mp_grid := 2 1 1",
            "mp_grid 2 1 1 unexpected",
            "mp_grid_extra = 2 1 1",
            "mp_grid = 2 1 1\nMP_GRID : 2 1 1",
            "mp_grid = 3 1 1",
        )
            write(path, line * "\n" * geometry)
            @test_throws ArgumentError Base.invokelatest(reader, path)
        end
    end
end
