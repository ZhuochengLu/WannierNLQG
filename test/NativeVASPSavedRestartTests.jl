using Test, TOML, SHA
@testset "Saved native VASP random U continuation" begin
    w=WannierNLQG.Wannierization;
    r=WannierNLQG.Runtime
    saved=only(
        filter(
            p->startswith(basename(p), "vasp-operators-"),
            readdir(spec["saved_operators"]; join = true),
        ),
    )
    partial=joinpath(saved, "u1.wannierization.h5")
    reference=w.read_wannierization_checkpoint_hdf5(joinpath(saved, "reference.wannierization.h5"))
    accepted=w.read_wannierization_checkpoint_hdf5(partial)
    @test accepted.restart_state.optimizer_state.u_steps==1
    @test reference.restart_state.optimizer_state.u_steps==2
    original=bytes2hex(sha256(read(partial)))
    doc=TOML.parsefile(joinpath(saved, "resumed.toml"))
    doc["output"]["checkpoint_hdf5"]=joinpath(out, "continued.wannierization.h5")
    path=joinpath(out, "continued.toml");
    open(f->TOML.print(f, doc), path, "w")
    result=r.run_task_input(r.read_task_input(path); record_directory = joinpath(out, "records"))
    println("VASP_RESTART_STATUS=", result.status)
    for d in result.diagnostics
        ;
        println("VASP_RESTART_DIAGNOSTIC=", d);
    end
    @test result.status==reference.status
    @test !any(d->d.severity==:error, result.diagnostics)
    @test isequal(result.v_matrix, reference.v_matrix)
    @test isequal(result.spreads_angstrom2, reference.spreads_angstrom2)
    @test result.restart_state!==nothing
    if result.restart_state!==nothing
        @test result.restart_state.optimizer_state.u_steps==2
        @test result.restart_state.optimizer_state.z_steps==0
    end
    @test result.artifacts.packed_hdf5!==nothing
    @test bytes2hex(sha256(read(partial)))==original
end
