module UnifiedTextInputChecks
using Test, WannierNLQG, TOML
const R=WannierNLQG.Runtime
const W=WannierNLQG.Wannierization
root=mktempdir()
base=Dict{String, Any}(
    "workflow"=>"wannierization",
    "mode"=>"ordinary",
    "structure"=>Dict(
        "lattice_angstrom"=>[[1.0, 0.0, 0.0], [0.0, 1.0, 0.0], [0.0, 0.0, 1.0]],
        "species"=>["X"],
        "positions_fractional"=>[[0.0, 0.0, 0.0]],
    ),
    "kmesh"=>Dict("dimensions"=>[1, 1, 1], "points_fractional"=>[[0.0, 0.0, 0.0]]),
    "basis"=>Dict("projections"=>["X:s"]),
    "matrices"=>Dict("eig_file"=>"seed.eig", "mmn_file"=>"seed.mmn", "amn_file"=>"seed.amn"),
    "output"=>Dict{String, Any}("checkpoint_hdf5"=>joinpath(root, "seed.wannierization.h5")),
)
@testset "Normalized cold mappings, defaults, errors and replay" begin
    for flag in (nothing, false, true)
        d=deepcopy(base);
        flag===nothing || (d["output"]["final_tb_symmetry_report_enabled"]=flag)
        d["solver"]=Dict(
            "random_seed"=>123,
            "parallel"=>"serial",
            "z_mix_ratio"=>0.75,
            "dis_num_iter"=>0,
            "num_iter"=>0,
            "numerical_thresholds"=>Dict("frame_transport_atol"=>2e-14),
        )
        x=R.resolve_task_input(d; base_dir = root, check_paths = false)
        @test x.config.output.final_tb_symmetry_report_enabled===something(flag, false)
        @test x.config.solver.random_seed==123
        @test x.config.solver.z_mix_ratio==0.75
        @test x.config.solver.numerical_thresholds.frame_transport_atol==2e-14
        y=R.resolve_task_input(x.effective; base_dir = root, check_paths = false)
        @test y.config.output==x.config.output
        @test y.config.solver==x.config.solver
    end
    for bad in (1, "true", [true])
        d=deepcopy(base);
        d["output"]["final_tb_symmetry_report_enabled"]=bad
        @test_throws ArgumentError R.resolve_task_input(d; base_dir = root, check_paths = false)
    end
    for name in ("wannierization", "symmetrization")
        d=Dict("workflow"=>name, name=>Dict("input"=>Dict("win_file"=>"no-input-must-be-opened")))
        e=try
            R.resolve_task_input(d; base_dir = root, check_paths = false);
            nothing
        catch e
            ;
            e
        end
        @test e isa ArgumentError
        @test occursin("removed", sprint(showerror, e))
    end
    d=deepcopy(base);
    d["output"]["operator_tasks"]=Dict("quantity"=>["shift_current"])
    d["output"]["profile"]="hamiltonian_position"
    @test_throws ArgumentError R.resolve_task_input(d; base_dir = root, check_paths = false)
end
@testset "Projection nine fields and effective replay" begin
    d=Dict{String, Any}(
        "workflow"=>"symmetrization",
        "structure"=>deepcopy(base["structure"]),
        "kmesh"=>Dict("dimensions"=>[1, 1, 1]),
        "basis"=>deepcopy(base["basis"]),
        "model"=>Dict(
            "tb_file"=>"seed_tb.dat",
            "wigner_seitz_tolerance"=>2e-5,
            "wigner_seitz_search_size"=>4,
            "wannier_center_tolerance"=>2e-8,
            "cutoff"=>12.0,
        ),
        "output"=>Dict("tb_file"=>"result_tb.dat", "packed_file"=>"result.h5", "overwrite"=>true),
    )
    x=R.resolve_task_input(d; base_dir = root, check_paths = false)
    @test x.config.overwrite
    @test x.config.cutoff==12
    @test x.config.wigner_seitz_search_size==4
    @test x.config.wigner_seitz_tolerance==2e-5
    y=R.resolve_task_input(x.effective; base_dir = root, check_paths = false)
    @test R._workflow_input_effective_value(y.config)==R._workflow_input_effective_value(x.config)
    for fields in (
        Dict("chk_file"=>"seed.chk", "spn_file"=>"seed.spn"),
        Dict("chk_file"=>"seed.chk", "eig_file"=>"seed.eig", "mmn_file"=>"seed.mmn"),
    )
        q=deepcopy(d);
        merge!(q["model"], fields)
        p=R.resolve_task_input(q; base_dir = root, check_paths = false)
        @test p.config.chk_file==joinpath(root, "seed.chk")
    end
    bad=deepcopy(d);
    bad["model"]["chk_file"]="seed.chk"
    @test_throws ArgumentError R.resolve_task_input(bad; base_dir = root, check_paths = false)
end
println("INPUT_CONFIG_TESTS_COMPLETE")

@testset "Existing file magnetic provider remains file based" begin
    d=Dict{String, Any}(
        "workflow"=>"symmetrization",
        "structure"=>deepcopy(base["structure"]),
        "kmesh"=>Dict("dimensions"=>[1, 1, 1]),
        "basis"=>deepcopy(base["basis"]),
        "model"=>Dict("tb_file"=>"seed_tb.dat"),
        "output"=>Dict("tb_file"=>"mag_tb.dat", "packed_file"=>"mag.h5"),
    )
    file=joinpath(root, "INCAR");
    write(file, "ISPIN = 2\nMAGMOM = 1.25\n")
    d["magnetic"]=Dict("source"=>"vasp", "file"=>file, "collinear_axis_cartesian"=>[0.0, 0.0, 1.0])
    x=R.resolve_task_input(d; base_dir = root, check_paths = false)
    @test x.config.structure.magnetic_moments_cartesian[:, 1]==[0.0, 0.0, 1.25]
    write(file, "ISPIN = 2\nMAGMOM = 2.5\n")
    y=R.resolve_task_input(x.effective; base_dir = root, check_paths = false)
    @test y.config.structure.magnetic_moments_cartesian[:, 1]==[0.0, 0.0, 2.5]
end
println("INPUT_CONFIG_ALL_TESTS_COMPLETE")

@testset "Unknown keys, mixed schemas and supported native scratch lifetime" begin
    for (group, key) in (
        ("solver", "unsupported_solver"),
        ("output", "unsupported_output"),
        ("input", "unsupported_input"),
    )
        d=deepcopy(base);
        d[group]=get(d, group, Dict{String, Any}());
        d[group][key]=1
        @test_throws ArgumentError R.resolve_task_input(d; base_dir = root, check_paths = false)
    end
    d=deepcopy(base);
    d["wannierization"]=Dict()
    @test_throws ArgumentError R.resolve_task_input(d; base_dir = root, check_paths = false)
    if isdefined(R, :_with_workflow_native_scratch)
        x=R.resolve_task_input(base; base_dir = root, check_paths = false)
        topology=R._workflow_native_trial_topology(
            x.config.input.geometry,
            x.config.input.projection_basis,
        )
        old=joinpath(root, "retained-matrices")
        provider=W.NativeQEPAWMatrices(topology; artifact_dir = old, require_oracle = false)
        cfg=W._replace_wannierization_config(
            x.config;
            input = (matrix_elements = provider, eig_file = joinpath(old, "native.eig")),
        )
        metadata=copy(x.metadata);
        metadata["transient_native_artifacts"]=true
        y=R.WorkflowInputResolution(
            cfg,
            x.original,
            x.effective,
            x.provenance,
            x.pending,
            x.summaries,
            metadata,
        )
        stored=Ref("")
        R._with_workflow_native_scratch(y) do actual
            stored[]=actual.input.matrix_elements.artifact_dir
            @test isdir(stored[])
            @test dirname(actual.input.eig_file)==stored[]
            @test actual.input.matrix_elements.topology.kpoints_fractional==provider.topology.kpoints_fractional
            write(joinpath(stored[], "temporary"), "fixture")
        end
        @test !isdir(stored[])
        @test !ispath(old)
    end
end

@testset "Explicit provider mappings and provider-owned MMN" begin
    d=deepcopy(base);
    d["matrices"]=Dict{String, Any}(d["matrices"]);
    d["matrices"]["provider"]=Dict(
        "kind"=>"external_overlap_projection",
        "mmn_file"=>"seed.mmn",
        "amn_file"=>"seed.amn",
    )
    x=R.resolve_task_input(d; base_dir = root, check_paths = false)
    @test x.config.input.matrix_elements isa W.ExternalOverlapProjectionMatrices
    @test x.config.input.mmn_file==x.config.input.matrix_elements.mmn_file
    d=deepcopy(base);
    d["matrices"]=Dict{String, Any}(d["matrices"]);
    d["matrices"]["mmn_file"]="provider-owned.mmn";
    delete!(d["matrices"], "amn_file")
    d["matrices"]["provider"]=Dict(
        "kind"=>"native_qe_paw",
        "nnkp_file"=>"seed.nnkp",
        "artifact_dir"=>joinpath(root, "native"),
        "require_oracle"=>false,
    )
    d["source"]=Dict("kind"=>"qe", "save_directory"=>"seed.save")
    d["solver"]=Dict("initialization"=>"random")
    x=R.resolve_task_input(d; base_dir = root, check_paths = false)
    @test x.config.input.mmn_file==joinpath(root, "provider-owned.mmn")
    @test x.config.input.matrix_elements isa W.NativeQEPAWMatrices
    y=R.resolve_task_input(x.effective; base_dir = root, check_paths = false)
    @test R._workflow_input_effective_value(
        y.config.input.matrix_elements,
    )==R._workflow_input_effective_value(x.config.input.matrix_elements)
end

@testset "Native topology retains projection owner orbital and spin ordering" begin
    projection=WannierNLQG.WannierProjection
    @test projection.projection_orbital_labels("p")==("pz", "px", "py")
    @test projection.projection_orbital_labels("eg")==("dx2-y2", "dz2")
    @test projection.projection_orbital_labels("sp3") isa Tuple
    @test_throws KeyError projection.projection_orbital_labels("unsupported_orbital_set")
    for (orbital, expected) in (
            ("s", [(0, 1)]),
            ("p", [(1, 1), (1, 2), (1, 3)]),
            ("pxy", [(1, 2), (1, 3)]),
            ("dxy", [(2, 5)]),
            ("eg", [(2, 4), (2, 1)]),
            ("t2g_dxy_first", [(2, 5), (2, 2), (2, 3)]),
            ("sp3", [(-3, 1), (-3, 2), (-3, 3), (-3, 4)]),
        ),
        spinor in (false, true)

        document=deepcopy(base)
        document["basis"]=Dict{String, Any}(document["basis"])
        document["basis"]["projections"]=["X:"*orbital]
        document["basis"]["spinor"]=spinor
        resolved=R.resolve_task_input(document; base_dir = root, check_paths = false)
        topology=R._workflow_native_trial_topology(
            resolved.config.input.geometry,
            resolved.config.input.projection_basis,
        )
        expected_codes=spinor ? [code for code in expected for _ in 1:2] : expected
        @test [
            (row.angular_code, row.angular_index) for row in topology.projections
        ]==expected_codes
        @test topology.spinor==spinor
        @test [
            row.spin_eigenvalue for row in topology.projections
        ]==(spinor ? [spin for _ in expected for spin in (1, -1)] : fill(nothing, length(expected)))
        @test all(row->row.center_fractional==(0.0, 0.0, 0.0), topology.projections)
    end
end

end
