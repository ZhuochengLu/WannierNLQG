module RuntimeInputSourceUnit
using Test, WannierNLQG
const DataIO=WannierNLQG.IO
const RunLayer=WannierNLQG.Runtime

@testset "Ordinary input aliases retain exact data and stable source resolution" begin
    mktempdir() do directory
        original=joinpath(directory, "original.dat")
        cp(
            joinpath(
                @__DIR__,
                "..",
                "examples",
                "fixtures",
                "synthetic_runtime",
                "synthetic_tb.dat",
            ),
            original,
        )
        alias=joinpath(directory, "alias.dat")
        symlink(original, alias)
        state=DataIO.observe_scientific_source(original)
        @test_throws ArgumentError DataIO.observe_scientific_source(alias)
        @test DataIO.read_wannier_tb_num_orbitals(
            alias,
        )==DataIO.read_wannier_tb_num_orbitals(original)
        @test DataIO.read_wannier_tb_lattice(alias)==DataIO.read_wannier_tb_lattice(original)
        @test DataIO._read_wannier_tb_centers(alias)==DataIO._read_wannier_tb_centers(original)
        left, right=DataIO.read_wannier_tb(alias), DataIO.read_wannier_tb(original)
        for field in (
            :lattice,
            :num_orbitals,
            :num_r_vectors,
            :r_degeneracies,
            :r_vectors,
            :hamiltonian_r,
            :position_r,
        )
            @test getfield(left, field)==getfield(right, field)
        end
        cfg=RunLayer.EffectiveTaskConfig(;
            model_file = alias,
            output_root = joinpath(directory, "out"),
            fourier_backend = "direct",
        )
        specs=RunLayer.validate_config(cfg)
        context=RunLayer.prepare_run_context(cfg, specs)
        @test context.model_identity==DataIO.scientific_file_identity(state)
        @test context.model_file==alias
        @test RunLayer.with_runtime_input_sources(()->17, [cfg], [specs])==17
        other=joinpath(directory, "identical-copy.dat")
        cp(original, other)
        @test_throws ErrorException RunLayer.with_runtime_input_sources([cfg], [specs]) do
            rm(alias);
            symlink(other, alias)
        end
        @test DataIO.validate_scientific_source_state(state)===nothing
        @test_throws ArgumentError DataIO.validate_scientific_source_state(
            state;
            declared_path = alias,
        )
        @test_throws ArgumentError DataIO.with_scientific_source(
            alias;
            resolve_links = true,
        ) do filename
            value=read(filename)
            rm(alias);
            symlink(original, alias)
            value
        end
        @test read(original)==read(other)
        @test RunLayer.with_runtime_input_sources(()->19, [cfg], [specs])==19
    end
end
end
