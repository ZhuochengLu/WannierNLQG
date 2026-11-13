using Test, TOML, LinearAlgebra
@testset "Native projection geometry without wavefunctions" begin
    r=WannierNLQG.Runtime;
    io=WannierNLQG.IO
    save=mkpath(joinpath(out, "fixture.save"));
    xml=joinpath(save, "data-file-schema.xml")
    content="""<espresso><input><atomic_structure alat="3.0"><cell><a1>3 0 0</a1><a2>0 3 0</a2><a3>0 0 3</a3></cell><atomic_positions><atom name="X">0 0 0</atom></atomic_positions></atomic_structure><k_points_IBZ><monkhorst_pack nk1="1" nk2="1" nk3="1" k1="0" k2="0" k3="0"/></k_points_IBZ></input><output><band_structure><lsda>false</lsda><noncolin>false</noncolin><spinorbit>false</spinorbit><ks_energies><k_point>0 0 0</k_point></ks_energies></band_structure></output></espresso>
    """
    write(xml, content)
    metadata=io.read_qe_geometry_metadata(xml)
    lattice=metadata.lattice_angstrom
    model=WannierNLQG.Core.TightBindingModel(
        lattice,
        1,
        1,
        [1],
        zeros(Int, 3, 1),
        reshape(ComplexF64[1.25], 1, 1, 1),
        zeros(ComplexF64, 1, 1, 3, 1),
    )
    tb=joinpath(out, "input_tb.dat");
    io.write_wannier_tb(tb, model)
    doc=Dict{String, Any}(
        "workflow"=>"symmetrization",
        "source"=>Dict("kind"=>"qe", "save_directory"=>save),
        "basis"=>Dict("projections"=>["X:s"]),
        "model"=>Dict("tb_file"=>tb),
        "output"=>Dict(
            "tb_file"=>joinpath(out, "qe", "model_tb.dat"),
            "packed_file"=>joinpath(out, "qe", "model.h5"),
        ),
    )
    function resolve(d, label)
        path=joinpath(out, label*".toml");
        open(stream->TOML.print(stream, d), path, "w")
        r.read_task_input(path)
    end
    mkpath(joinpath(out, "qe"))
    input=resolve(doc, "qe")
    @test input.config.mp_grid==(1, 1, 1)
    @test input.config.structure.species==["X"]
    @test input.metadata["geometry_files"]==[xml]
    @test input.config.win_file===nothing
    result=r.run_task_input(input; record_directory = joinpath(out, "qe-records"))
    @test isfile(result.real_space_operator_bundle)
    @test readdir(save)==["data-file-schema.xml"]
    @test resolve(
        TOML.parsefile(joinpath(out, "qe-records", "effective_config.toml")),
        "qe-effective",
    ).config.mp_grid==(1, 1, 1)
    conflict=deepcopy(doc);
    conflict["kmesh"]=Dict("dimensions"=>[2, 1, 1])
    @test_throws ArgumentError resolve(conflict, "grid-conflict")
    explicit=Dict(
        "lattice_angstrom"=>[collect(row) for row in eachrow(lattice)],
        "species"=>["X"],
        "positions_fractional"=>[[0.0, 0.0, 0.0]],
    )
    conflict=deepcopy(doc);
    conflict["structure"]=deepcopy(explicit);
    conflict["structure"]["species"]=["Y"]
    @test_throws ArgumentError resolve(conflict, "atom-conflict")
    write(xml, replace(content, "<lsda>false</lsda>"=>"<lsda>true</lsda>"))
    @test_throws ArgumentError r.run_task_input(
        input;
        record_directory = joinpath(out, "stale-records"),
    )
    @test_throws ArgumentError resolve(doc, "missing-moments")
    magnetic=deepcopy(doc);
    magnetic["structure"]=deepcopy(explicit)
    magnetic["structure"]["magnetic_moments_cartesian"]=[[0.0, 0.0, 0.0]]
    @test resolve(magnetic, "explicit-moments").config.structure.magnetic_moments_cartesian==zeros(
        3,
        1,
    )
    poscar=joinpath(out, "POSCAR")
    write(
        poscar,
        "X\n1.0\n"*join((join(row, " ") for row in eachrow(lattice)), "\n")*"\nX\n1\nDirect\n0 0 0\n",
    )
    outcar=joinpath(out, "OUTCAR")
    write(
        outcar,
        "NKPTS = 1\nISPIN = 1\nLNONCOLLINEAR = F\nLSORBIT = F\nk-points in reciprocal lattice and weights:\n0 0 0 1\n",
    )
    vasp=deepcopy(doc);
    vasp["source"]=Dict("kind"=>"vasp", "poscar_file"=>poscar, "outcar_file"=>outcar)
    vasp["kmesh"]=Dict("dimensions"=>[1, 1, 1])
    vasp["output"]=Dict(
        "tb_file"=>joinpath(out, "vasp", "model_tb.dat"),
        "packed_file"=>joinpath(out, "vasp", "model.h5"),
    )
    mkpath(joinpath(out, "vasp"))
    vinput=resolve(vasp, "vasp");
    vresult=r.run_task_input(vinput; record_directory = joinpath(out, "vasp-records"))
    @test vinput.metadata["geometry_files"]==[poscar, outcar]
    a=io.read_real_space_operator_bundle(result.real_space_operator_bundle)
    b=io.read_real_space_operator_bundle(vresult.real_space_operator_bundle)
    @test all(isequal(a.operators[k].data, b.operators[k].data) for k in keys(a.operators))
    @test !isfile(joinpath(out, "WAVECAR"))
    @test !isfile(joinpath(out, "POTCAR"))
    mixed=deepcopy(vasp);
    mixed["source"]["save_directory"]=save
    @test_throws ArgumentError resolve(mixed, "mixed")
end
