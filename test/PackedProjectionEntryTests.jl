using Test, TOML, SHA
@testset "Packed projection inventory preservation" begin
    r=WannierNLQG.Runtime;
    io=WannierNLQG.IO
    doc=TOML.parsefile(joinpath(spec["projection_fixture"], "records", "effective_config.toml"))
    packed=joinpath(spec["projection_fixture"], "owned.h5")
    digest=bytes2hex(sha256(read(packed)))
    delete!(doc["model"], "tb_file");
    doc["model"]["packed_file"]=packed
    doc["output"]=Dict(
        "tb_file"=>joinpath(out, "projected", "model_tb.dat"),
        "packed_file"=>joinpath(out, "projected", "model.h5"),
    )
    mkpath(joinpath(out, "projected"))
    function resolve(d, label)
        path=joinpath(out, label*".toml");
        open(stream->TOML.print(stream, d), path, "w")
        r.read_task_input(path)
    end
    input=resolve(doc, "packed-input")
    @test input.config.tb_file===nothing
    @test input.config.input_operator_bundle_file==packed
    # Positive projection already passed285; consume its saved result.
    original=io.read_real_space_operator_bundle(packed)
    projected=io.read_real_space_operator_bundle(spec["packed_result"])
    @test Set(projected.manifest.inventory)==Set(original.manifest.inventory)
    @test !projected.manifest.production_eligible
    for kind in original.manifest.inventory
        @test isequal(projected.operators[kind].data, original.operators[kind].data)
        @test isequal(projected.operators[kind].r_vectors, original.operators[kind].r_vectors)
    end
    @test bytes2hex(sha256(read(packed)))==digest
    mixed=deepcopy(doc);
    mixed["model"]["tb_file"]=joinpath(spec["projection_fixture"], "input_tb.dat")
    @test_throws ArgumentError resolve(mixed, "mixed")
    unsupported=deepcopy(doc)
    unsupported["model"]["packed_file"]=joinpath(
        spec["source"],
        "test/fixtures/first_use_registered/pauli_bundle.h5",
    )
    unsupported["output"]=Dict(
        "tb_file"=>joinpath(out, "rejected", "model_tb.dat"),
        "packed_file"=>joinpath(out, "rejected", "model.h5"),
    )
    # Explicit caller-owned fixture adoption through the existing test helper;
    # the sealed archived input and the production reader remain unchanged.
    Base.include(Main, joinpath(spec["source"], "test/OperatorBundleTestSupport.jl"))
    fixture_dir=mkpath(joinpath(out, "unsupported-fixture"))
    unsupported["model"]["packed_file"]=Base.invokelatest(
        current_packed_fixture_copy,
        unsupported["model"]["packed_file"],
        fixture_dir,
    )
    inventory=io.read_real_space_operator_bundle(unsupported["model"]["packed_file"]).manifest.inventory
    @test length(inventory)>2
    @test_throws ArgumentError r.run_task_input(
        resolve(unsupported, "unsupported");
        record_directory = joinpath(out, "rejected-records"),
    )
    @test !isfile(unsupported["output"]["packed_file"])
    @test !isfile(unsupported["output"]["tb_file"])
    @test bytes2hex(sha256(read(packed)))==digest
end
