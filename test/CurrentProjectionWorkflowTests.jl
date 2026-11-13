using Test, TOML, SHA
@testset "Owned projection TOML to TB and Packed" begin
    r = WannierNLQG.Runtime
    s = WannierNLQG.Symmetrization
    io = WannierNLQG.IO
    lattice = [1.0 0 0; 0.2 1.3 0; 0.1 0.3 1.7]
    model = WannierNLQG.Core.TightBindingModel(
        lattice,
        1,
        1,
        [1],
        zeros(Int, 3, 1),
        reshape(ComplexF64[1.25], 1, 1, 1),
        zeros(ComplexF64, 1, 1, 3, 1),
    )
    input_tb = joinpath(out, "input_tb.dat")
    io.write_wannier_tb(input_tb, model)
    # Portable fixture: original model is generated locally, not a prior campaign output.
    input_sha = bytes2hex(sha256(read(input_tb)))
    doc = Dict{String, Any}(
        "workflow"=>"symmetrization",
        "structure"=>Dict(
            "lattice_angstrom"=>[collect(row) for row in eachrow(lattice)],
            "species"=>["X"],
            "positions_fractional"=>[[0.0, 0.0, 0.0]],
        ),
        "kmesh"=>Dict("dimensions"=>[2, 2, 2]),
        "basis"=>Dict("projections"=>["X:s"], "num_wannier"=>1),
        "model"=>Dict("tb_file"=>input_tb),
        "output"=>Dict(
            "tb_file"=>joinpath(out, "owned_tb.dat"),
            "packed_file"=>joinpath(out, "owned.h5"),
            "report_json_file"=>joinpath(out, "owned.json"),
        ),
    )
    function resolve(document, label)
        path=joinpath(out, label*".toml")
        open(stream->TOML.print(stream, document), path, "w")
        r.read_task_input(path)
    end
    input=resolve(doc, "owned-input")
    @test input.config.win_file===nothing
    @test input.config.mp_grid==(2, 2, 2)
    @test input.config.projection_basis.num_wannier==1
    @test input.effective["mode"]=="projection"
    actual = r.run_task_input(input; record_directory = joinpath(out, "records"))
    # Compare generated production outputs with the independent legacy reference below.
    @test isfile(doc["output"]["tb_file"])
    @test isfile(doc["output"]["packed_file"])
    @test bytes2hex(sha256(read(input_tb)))==input_sha
    @test !any(endswith(".win"), readdir(out))
    bundle=io.read_real_space_operator_bundle(doc["output"]["packed_file"])
    @test Set(keys(bundle.operators))==Set((s.REAL_SPACE_HAMILTONIAN, s.REAL_SPACE_POSITION))
    # The legacy input exists only in this independent reference fixture.
    win=joinpath(out, "reference.win")
    write(
        win,
        """
num_wann = 1
mp_grid = 2 2 2
begin unit_cell_cart
1 0 0
.2 1.3 0
.1 .3 1.7
end unit_cell_cart
begin atoms_frac
X 0 0 0
end atoms_frac
begin projections
X:s
end projections
""",
    )
    mkpath(joinpath(out, "reference"))
    s.symmetrize_wannier_operators(
        s.SymmetrizationConfig(
            win_file = win,
            tb_file = input_tb,
            output_tb_file = joinpath(out, "reference", "model_tb.dat"),
            output_real_space_operator_bundle_file = joinpath(out, "reference", "model.h5"),
        ),
    )
    reference=io.read_real_space_operator_bundle(joinpath(out, "reference", "model.h5"))
    for kind in keys(reference.operators)
        @test isequal(reference.operators[kind].data, bundle.operators[kind].data)
        @test isequal(reference.operators[kind].r_vectors, bundle.operators[kind].r_vectors)
    end
    replay=TOML.parsefile(joinpath(out, "records", "effective_config.toml"))
    replay["output"]=Dict(
        "tb_file"=>joinpath(out, "replay-output", "model_tb.dat"),
        "packed_file"=>joinpath(out, "replay-output", "model.h5"),
    )
    mkpath(joinpath(out, "replay-output"))
    r.run_task_input(resolve(replay, "replay"); record_directory = joinpath(out, "replay-records"))
    again=io.read_real_space_operator_bundle(replay["output"]["packed_file"])
    @test all(
        isequal(bundle.operators[k].data, again.operators[k].data) for k in keys(bundle.operators)
    )
    for (group, key, value) in (
        ("kmesh", "dimensions", [0, 2, 2]),
        ("model", "packed_file", "unhandled.h5"),
        ("basis", "spinor", "false"),
    )
        bad=deepcopy(doc);
        bad[group][key]=value
        @test_throws ArgumentError resolve(bad, "invalid")
    end
    bad=deepcopy(doc);
    bad["mode"]="gauge_aware"
    @test_throws ArgumentError resolve(bad, "invalid-mode")
    bad=deepcopy(doc);
    bad["source"]=Dict("kind"=>"qe")
    @test_throws ArgumentError resolve(bad, "mixed-source")
    @test bytes2hex(sha256(read(input_tb)))==input_sha
end
