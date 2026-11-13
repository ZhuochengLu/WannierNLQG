using Test, LinearAlgebra
include(
    joinpath(
        @__DIR__,
        "..",
        "ext",
        "WannierNLQGWannierizationExt",
        "PrecompileSupport",
        "TinyWannierWorkflowInputs.jl",
    ),
)
@testset "No WIN ordinary workflow exact legacy comparison" begin
    w=WannierNLQG.Wannierization
    sf=WannierNLQG.SymmetryFoundation
    mktempdir() do dir
        inputs=tiny_wannier_workflow(dir; localize = true)
        win=inputs.solve.input.win_file
        write(
            win,
            "num_wann=1\nmp_grid=2 1 1\nbegin unit_cell_cart\n1 0 0\n0 1 0\n0 0 1\nend unit_cell_cart\nbegin atoms_frac\nX 0 0 0\nend atoms_frac\nbegin kpoints\n0 0 0\n0.5 0 0\nend kpoints\nbegin projections\nX:s\nend projections\n",
        )
        geometry=w.WannierizationGeometry(
            sf.CrystalStructure(Matrix{Float64}(I, 3, 3), ["X"], zeros(3, 1)),
            (2, 1, 1),
            [0.0 0.0 0.0; 0.5 0.0 0.0],
        )
        baseline=w._replace_wannierization_config(
            inputs.solve;
            input = (
                wannierization_mode = :ordinary,
                band_representation_hdf5 = nothing,
                compatibility_policy = :off,
            ),
            checkpoint = (checkpoint_hdf5 = joinpath(dir, "legacy.wannierization.h5"),),
            output = (final_tb_symmetry_report_enabled = false,),
        )
        old=w.construct_wannier_functions(baseline)
        @test old.status ∉ (w.INVALID_INPUT, w.IO_FAILURE)
        @test !isempty(old.v_matrix)
        rm(win)
        config=w._replace_wannierization_config(
            baseline;
            input = (win_file = nothing, geometry = geometry),
            checkpoint = (checkpoint_hdf5 = joinpath(dir, "normalized.wannierization.h5"),),
        )
        actual=w.construct_wannier_functions(config)
        @test actual.status == old.status
        @test isequal(actual.v_matrix, old.v_matrix)
        @test isequal(actual.wannier_centers_cartesian, old.wannier_centers_cartesian)
        @test isequal(actual.spreads_angstrom2, old.spreads_angstrom2)
        @test length(actual.history)==length(old.history)
        for (a, b) in zip(actual.history, old.history), field in fieldnames(typeof(a))
            value=getfield(a, field)
            if value isa Number || value isa AbstractArray{<:Number}
                # Wall-clock diagnostics are not numerical trajectory invariants.
                occursin(r"time|elapsed|seconds", String(field)) && continue
                @test isequal(value, getfield(b, field))
            end
        end
        @test !isfile(win)
        @test isfile(joinpath(dir, "normalized.wannierization.h5"))
    end
end
