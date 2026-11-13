using Test, LinearAlgebra
@testset "Projection strings canonical expansion" begin
    wp = WannierNLQG.WannierProjection
    sf = WannierNLQG.SymmetryFoundation
    structure = sf.CrystalStructure(
        4.0 .* Matrix{Float64}(I, 3, 3),
        ["X", "Y", "X"],
        [0.0 0.25 0.5; 0.0 0.25 0.5; 0.0 0.25 0.5],
    )
    lines = ["X:s;p", "Y:dxy;dxz;dyz:x=0,1,0:z=0,0,1"]
    for spinor in (false, true)
        specs = wp.ProjectionSpec[]
        for line in lines
            selector, orbital_sets, local_basis = wp.parse_projection_line(line)
            push!(specs, wp.ProjectionSpec(; selector, orbital_sets, local_bases = local_basis))
        end
        actual = wp.build_wannier_projection_basis(lines; structure, spinor)
        reference = wp.build_wannier_projection_basis(specs; structure, spinor)
        @test actual.num_wannier == (spinor ? 22 : 11)
        @test actual.spinor == reference.spinor
        @test length(actual.blocks) == length(reference.blocks)
        for (a, b) in zip(actual.blocks, reference.blocks), field in fieldnames(typeof(a))
            @test isequal(getfield(a, field), getfield(b, field))
        end
        factor = spinor ? 2 : 1
        @test actual.blocks[1].indices == hcat(collect(1:factor), collect((4factor + 1):(5factor)))
        @test actual.blocks[2].indices ==
              hcat(collect((factor + 1):(4factor)), collect((5factor + 1):(8factor)))
        @test actual.blocks[1].positions_fractional == structure.positions_fractional[:, [1, 3]]
        @test_throws ArgumentError wp.build_wannier_projection_basis(
            lines;
            structure,
            spinor,
            num_wannier = 1,
        )
        mktempdir() do dir
            path = joinpath(dir, "legacy.win")
            write(
                path,
                "num_wann=$(actual.num_wannier)\nspinors=$(spinor)\nmp_grid=1 1 1\nbegin unit_cell_cart\n4 0 0\n0 4 0\n0 0 4\nend unit_cell_cart\nbegin atoms_frac\nX 0 0 0\nY .25 .25 .25\nX .5 .5 .5\nend atoms_frac\nbegin kpoints\n0 0 0\nend kpoints\nbegin projections\n" *
                join(lines, "\n") *
                "\nend projections\n",
            )
            legacy = wp.build_wannier_projection_basis(path)
            for (a, b) in zip(actual.blocks, legacy.blocks), field in fieldnames(typeof(a))
                @test isequal(getfield(a, field), getfield(b, field))
            end
            @test legacy.num_wannier == actual.num_wannier
        end
    end
    for lines in (
        String[],
        ["X"],
        ["X:"],
        ["X:unsupported"],
        ["Z:s"],
        ["X:s:radial=1"],
        ["X:s:spin_axis=0,0,1"],
    )
        @test_throws ArgumentError wp.build_wannier_projection_basis(lines; structure)
    end
end
