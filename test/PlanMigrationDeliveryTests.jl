using Test, TOML, SHA
function migration_same_record(a, b)
    typeof(a)==typeof(b) || return false
    if a isa AbstractArray
        return size(a)==size(b) && all(migration_same_record(x, y) for (x, y) in zip(a, b))
    elseif a isa Number || a isa AbstractString || a isa Symbol || a===nothing || a isa Bool
        return isequal(a, b)
    elseif a isa AbstractDict
        return keys(a)==keys(b) && all(migration_same_record(a[k], b[k]) for k in keys(a))
    end
    return all(migration_same_record(getfield(a, k), getfield(b, k)) for k in fieldnames(typeof(a)))
end
@testset "Plan delivery alignment and saved migration state" begin
    r=WannierNLQG.Runtime;
    w=WannierNLQG.Wannierization
    template=joinpath(out, "projection.toml")
    r.write_workflow_input_template(template, "symmetrization", "projection")
    document=TOML.parsefile(template)
    @test document["workflow"]=="symmetrization"
    @test document["mode"]=="projection"
    @test haskey(document, "source") && haskey(document, "basis") && haskey(document, "model")
    @test !occursin("win_file", read(template, String))
    @test_throws ArgumentError r.write_workflow_input_template(
        joinpath(out, "removed.toml"),
        "symmetrization",
        "gauge_aware",
    )
    @test !isdefined(WannierNLQG.Symmetrization, :GaugeAwareSymmetrizationConfig)
    solver=first(w._load_wannierization_extension!()).SolverCheckpoint
    for file in ("checkpoint_2_28.h5", "restart_checkpoint_2_28.h5", "checkpoint_1_1.h5")
        source=joinpath(@__DIR__, "fixtures/schema_compatibility", file)
        original=solver._read_legacy_checkpoint_029(source)
        saved=joinpath(spec["saved_migrations"], file*"-migration", "converted.wannierization.h5")
        digest=bytes2hex(sha256(read(saved)))
        current=w.read_wannierization_checkpoint_hdf5(saved)
        @test migration_same_record(current.history, original.history)
        @test migration_same_record(current.restart_state, original.restart_state)
        @test migration_same_record(current.wannier_chk, original.wannier_chk)
        @test current.status==original.status
        @test bytes2hex(sha256(read(saved)))==digest
    end
end
